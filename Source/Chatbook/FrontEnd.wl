(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`FrontEnd`" ];

`$dialogInputAllowed;
`$feTaskWidgetCell;
`$inEpilog;
`$suppressButtonAppearance;
`cellInformation;
`cellObjectQ;
`cellOpenQ;
`cellPrint;
`cellPrintAfter;
`cellStyles;
`checkEvaluationCell;
`compressUntilViewed;
`createFETask;
`feParentObject;
`fixCloudCell;
`flushFETasks;
`getBoxObjectFromBoxID;
`initFETaskWidget;
`notebookRead;
`openerView;
`parentCell;
`parentNotebook;
`replaceCellContext;
`rootEvaluationCell;
`selectionEvaluateCreateCell;
`toCompressedBoxes;
`topLevelCellQ;
`topParentCell;
`withNoRenderUpdates;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`Settings`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$checkEvaluationCell := $VersionNumber <= 13.2; (* Flag that determines whether to use workarounds for #187 *)

(* Used to determine whether or not interactive input (e.g. ChoiceDialog, DialogInput) can be used: *)
$dialogInputAllowed := ! Or[
    TrueQ @ $SynchronousEvaluation,
    MathLink`IsPreemptive[ ],
    MathLink`PreemptionEnabledQ[ ] === False
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tasks*)

$feTaskDebug           = False;
$feTasks               = { };
$feTaskTrigger         = 0;
$feTaskLog             = Internal`Bag[ ];
$feTaskCreationCount   = 0;
$feTaskEvaluationCount = 0;
$allTaskWidgetsCleared = False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*initFETaskWidget*)
initFETaskWidget // beginDefinition;

initFETaskWidget[ nbo_NotebookObject ] /; $cloudNotebooks :=
    Null;

initFETaskWidget[ nbo_NotebookObject ] := (
    (* Clear the existing task widget first, since there may be more than one chat notebook visible.
       We don't want to duplicate task execution due to dynamics firing for both. *)
    clearExistingFETaskWidget[ ];
    $feTaskWidgetCell = AttachCell[
        nbo,
        $feTaskWidgetContent,
        { Left, Bottom },
        0,
        { Left, Bottom },
        RemovalConditions -> { "EvaluatorQuit" }
    ]
);

initFETaskWidget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*clearExistingFETaskWidget*)
clearExistingFETaskWidget // beginDefinition;

clearExistingFETaskWidget[ ] :=
    If[ ! TrueQ @ $allTaskWidgetsCleared
        ,
        Scan[
            NotebookDelete @ Cells[ #, AttachedCell -> True, CellStyle -> "FETaskWidget" ] &,
            Notebooks[ ]
        ];
        $allTaskWidgetsCleared = True
        ,
        Quiet @ NotebookDelete @ $feTaskWidgetCell
    ];

clearExistingFETaskWidget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$feTaskWidgetContent*)
$feTaskWidgetContent = Cell[
    BoxData @ ToBoxes @ Dynamic[
        catchAlways[
            $feTaskTrigger;
            runFETasks[ ];
            If[ TrueQ @ $feTaskDebug,
                $feTaskDebugPanel,
                Pane[ "", ImageSize -> { 0, 0 } ]
            ]
        ]
        ,
        TrackedSymbols :> { $feTaskTrigger }
    ],
    "FETaskWidget"
];

$feTaskDebugPanel := Framed[
    Grid[
        {
            {
                Row @ { "Created: "  , $feTaskCreationCount   },
                Row @ { "Pending: "  , Length @ $feTasks      },
                Row @ { "Evaluated: ", $feTaskEvaluationCount }
            }
        },
        BaseStyle  -> { "Text", FontSize -> 12 },
        Dividers   -> Center,
        FrameStyle -> GrayLevel[ 0.75 ],
        Spacings   -> 1
    ],
    Background   -> GrayLevel[ 0.98 ],
    FrameMargins -> { { 5, 5 }, { 0, 0 } },
    FrameStyle   -> None
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createFETask*)
createFETask // beginDefinition;
createFETask // Attributes = { HoldFirst };

createFETask[ eval_ ] /; $cloudNotebooks :=
    eval;

createFETask[ eval_ ] := (
    If[ $feTaskDebug, Internal`StuffBag[ $feTaskLog, <| "Task" -> Hold @ eval, "Created" -> AbsoluteTime[ ] |> ] ];
    AppendTo[ $feTasks, Hold @ eval ];
    ++$feTaskCreationCount;
    ++$feTaskTrigger
);

createFETask // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*runFETasks*)
runFETasks // beginDefinition;

runFETasks[ ] := runFETasks @ $feTasks;
runFETasks[ { } ] := $feTaskTrigger;

runFETasks[ { t_, ts___ } ] :=
    Block[ { createFETask = # & },
        $feTasks = { ts };
        runFETasks @ t;
        ++$feTaskTrigger
    ];

runFETasks[ Hold[ eval_ ] ] := (
    If[ $feTaskDebug, Internal`StuffBag[ $feTaskLog, <| "Task" -> Hold @ eval, "Evaluated" -> AbsoluteTime[ ] |> ] ];
    ++$feTaskEvaluationCount;
    eval
);

runFETasks // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*feParentObject*)
feParentObject // beginDefinition;

feParentObject[ box_BoxObject ] :=
    With[ { parent = ParentBox @ box },
        If[ MatchQ[ parent, _BoxObject ] && parent =!= box,
            parent,
            parentCell @ box
        ]
    ];

feParentObject[ cell_CellObject ] :=
    With[ { parent = parentCell @ cell },
        If[ MatchQ[ parent, _CellObject ] && parent =!= cell,
            parent,
            parentNotebook @ cell
        ]
    ];

feParentObject[ nbo_NotebookObject ] := $FrontEndSession;

feParentObject[ $FrontEndSession ] := $FrontEnd;

feParentObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cells*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellObjectQ*)
cellObjectQ[ cell_CellObject ] := MatchQ[ Developer`CellInformation @ cell, KeyValuePattern @ { } ];
cellObjectQ[ ___             ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkEvaluationCell*)
checkEvaluationCell // beginDefinition;
checkEvaluationCell[ cell_ ] /; $checkEvaluationCell := rootEvaluationCell @ cell;
checkEvaluationCell[ $Failed ] := rootEvaluationCell @ $Failed;
checkEvaluationCell[ cell_CellObject ] := cell;
checkEvaluationCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*rootEvaluationCell*)
(*
    A utility function that can be used in some places to help mitigate issue #187.
    This isn't bullet-proof and relies on heuristics, so it should only be used as a fallback when
    `EvaluationCell[]` has given something unexpected.
*)
rootEvaluationCell // beginDefinition;

(* Try `EvaluationCell[]` first by default: *)
rootEvaluationCell[ ] := rootEvaluationCell @ (FinishDynamic[ ]; EvaluationCell[ ]);

(* If `EvaluationCell[ ]` returned `$Failed` try one more time: *)
rootEvaluationCell[ $Failed ] :=
    With[ { cell = EvaluationCell[ ] },
        If[ MatchQ[ cell, _CellObject ],
            (* Success, proceed normally: *)
            rootEvaluationCell @ cell,
            (* Failure, jump to heuristic method: *)
            rootEvaluationCell[ cell, Cells[ ] ]
        ]
    ];

(* Get the list of top-level cells from the current notebook: *)
rootEvaluationCell[ cell_CellObject ] := rootEvaluationCell[ cell, parentNotebook @ cell ];
rootEvaluationCell[ cell_CellObject, nbo_NotebookObject ] := rootEvaluationCell[ cell, Cells @ nbo ];

(* The cell given by `EvaluationCell[]` is a top-level cell that's currently evaluating: *)
rootEvaluationCell[ cell_CellObject, cells: { __CellObject } ] /;
    TrueQ @ And[ MemberQ[ cells, cell ], cellEvaluatingQ @ cell ] :=
        cell;

(*
    This looks for the first cell that's currently evaluating according to `cellInformation`.
    This is a simple heuristic for guessing the current evaluation cell when other methods have failed.
    If there are multiple cells queued for evaluation, this can return the wrong cell if the evaluations were
    queued out of order, so this is only meant to be used as a last resort.
*)
rootEvaluationCell[ source_, cells: { __CellObject } ] :=
    FirstCase[
        cellInformation @ cells,
        KeyValuePattern @ { "Evaluating" -> True, "CellObject" -> cell_CellObject } :> cell,
        throwInternalFailure @ rootEvaluationCell[ source, cells ]
    ];

rootEvaluationCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellEvaluatingQ*)
cellEvaluatingQ // beginDefinition;
cellEvaluatingQ[ cell_CellObject ] /; $inEpilog := TrueQ @ CurrentValue[ cell, Evaluatable ];
cellEvaluatingQ[ cell_CellObject ] := MatchQ[ cellInformation @ cell, KeyValuePattern[ "Evaluating" -> True ] ];
cellEvaluatingQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellInformation*)
cellInformation // beginDefinition;

cellInformation[ nbo_NotebookObject ] := cellInformation @ Cells @ nbo;

cellInformation[ cells: { ___CellObject } ] := Map[
    Association,
    Transpose @ {
        Developer`CellInformation @ cells,
        Thread[ "CellObject"           -> cells ],
        Thread[ "CellAutoOverwrite"    -> CurrentValue[ cells, CellAutoOverwrite ] ],
        Thread[ "ChatNotebookSettings" -> AbsoluteCurrentValue[ cells, { TaggingRules, "ChatNotebookSettings" } ] ]
    }
];

cellInformation[ cell_CellObject ] := Association[
    Developer`CellInformation @ cell,
    "CellObject"           -> cell,
    "CellAutoOverwrite"    -> CurrentValue[ cell, CellAutoOverwrite ],
    "ChatNotebookSettings" -> AbsoluteCurrentValue[ cell, { TaggingRules, "ChatNotebookSettings" } ]
];

cellInformation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parentCell*)
parentCell // beginDefinition;
parentCell[ obj: _CellObject|_BoxObject ] /; $cloudNotebooks := cloudParentCell @ obj;
parentCell[ obj: _CellObject|_BoxObject ] := ParentCell @ obj;
parentCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudParentCell*)
cloudParentCell // beginDefinition;
cloudParentCell[ obj_ ] := cloudParentCell[ obj, ParentCell @ obj ];
cloudParentCell[ obj_, cell_CellObject ] := cell;
cloudParentCell[ box_BoxObject, _ ] := cloudBoxParent @ box;
cloudParentCell[ cell_CellObject, _ ] := cell;
cloudParentCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudBoxParent*)
cloudBoxParent // beginDefinition;
cloudBoxParent[ BoxObject[ path_String ] ] := cloudBoxParent @ StringSplit[ path, "/" ];
cloudBoxParent[ { nb_String, cell_String, __ } ] := CellObject[ cell, nb ];
cloudBoxParent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*topLevelCellQ*)
topLevelCellQ // beginDefinition;
topLevelCellQ[ cell_CellObject ] := topLevelCellQ[ cell, parentNotebook @ cell ];
topLevelCellQ[ cell_CellObject, nbo_NotebookObject ] := topLevelCellQ[ cell, Cells @ nbo ];
topLevelCellQ[ cell_CellObject, cells: { ___CellObject } ] := MemberQ[ cells, cell ];
topLevelCellQ[ _ ] := False;
topLevelCellQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*topParentCell*)
topParentCell // beginDefinition;
topParentCell[ cell_CellObject ] := topParentCell[ cell, parentCell @ cell ];
topParentCell[ cell_CellObject, cell_CellObject ] := cell; (* Already top (in cloud) *)
topParentCell[ cell_CellObject, parent_CellObject ] := topParentCell @ parent; (* Recurse upwards *)
topParentCell[ cell_CellObject, _ ] := cell; (* No parent cell *)
topParentCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellPrint*)
cellPrint // beginDefinition;
cellPrint[ cell_Cell ] /; $cloudNotebooks := cloudCellPrint @ cell;
cellPrint[ cell_Cell ] := MathLink`CallFrontEnd @ FrontEnd`CellPrintReturnObject @ cell;
cellPrint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudCellPrint*)
cloudCellPrint // beginDefinition;

cloudCellPrint[ cell0_Cell ] :=
    Enclose @ Module[ { cellUUID, nbUUID, cell },
        cellUUID = CreateUUID[ ];
        nbUUID   = ConfirmBy[ cloudNotebookUUID[ ], StringQ ];
        cell     = Append[ DeleteCases[ cell0, ExpressionUUID -> _ ], ExpressionUUID -> cellUUID ];
        CellPrint @ cell;
        CellObject[ cellUUID, nbUUID ]
    ];

cloudCellPrint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudNotebookUUID*)
cloudNotebookUUID // beginDefinition;
cloudNotebookUUID[ ] := cloudNotebookUUID[ EvaluationNotebook[ ] ];
cloudNotebookUUID[ NotebookObject[ _, uuid_String ] ] := uuid;
cloudNotebookUUID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellPrintAfter*)
cellPrintAfter[ target_ ][ cell_ ] := cellPrintAfter[ target, cell ];

cellPrintAfter[ target_CellObject, cell: Cell[ __, ExpressionUUID -> uuid_, ___ ] ] := (
    SelectionMove[ target, After, Cell, AutoScroll -> False ];
    NotebookWrite[ parentNotebook @ target, cell ];
    CellObject @ uuid
);

cellPrintAfter[ target_CellObject, cell_Cell ] :=
    cellPrintAfter[ target, Append[ cell, ExpressionUUID -> CreateUUID[ ] ] ];

cellPrintAfter[ a_, b__ ] := throwInternalFailure @ cellPrintAfter[ a, b ];
cellPrintAfter[ a_ ][ b___ ] := throwInternalFailure @ cellPrintAfter[ a ][ b ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellOpenQ*)
cellOpenQ // beginDefinition;
cellOpenQ[ cell_CellObject ] /; $cloudNotebooks := Lookup[ Options[ cell, CellOpen ], CellOpen, True ];
cellOpenQ[ cell_CellObject ] := CurrentValue[ cell, CellOpen ];
cellOpenQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellStyles*)
cellStyles // beginDefinition;
cellStyles[ cells_ ] /; $cloudNotebooks := cloudCellStyles @ cells;
cellStyles[ cells_ ] := CurrentValue[ cells, CellStyle ];
cellStyles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudCellStyles*)
cloudCellStyles // beginDefinition;
cloudCellStyles[ cells_ ] := Cases[ notebookRead @ cells, Cell[ _, style___String, OptionsPattern[ ] ] :> { style } ];
cloudCellStyles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*selectionEvaluateCreateCell*)
selectionEvaluateCreateCell // beginDefinition;
selectionEvaluateCreateCell[ nbo_NotebookObject ] /; $cloudNotebooks := FrontEndTokenExecute[ nbo, "EvaluateCells" ];
selectionEvaluateCreateCell[ nbo_NotebookObject ] := SelectionEvaluateCreateCell @ nbo;
selectionEvaluateCreateCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*fixCloudCell*)

(*
    Repairs text cells created in cloud notebooks.
    In the cloud, typing plain text like "Hello #Translated|French" into ChatInput cells can result in boxes like:
    ```
    Cell[TextData[{"Hello", StyleBox[RowBox[{" ", "#"}]], "Translated", "|", "French"}], "ChatInput"]
    ```
    This function repairs this kind mess so we can make sense of the cell contents.
*)

fixCloudCell // beginDefinition;
fixCloudCell[ cell_ ] /; ! TrueQ @ $cloudNotebooks := cell;
fixCloudCell[ Cell[ CellGroupData[ cells_, a___ ] ] ] := Cell[ CellGroupData[ fixCloudCell @ cells, a ] ];
fixCloudCell[ Cell[ text_, args___ ] ] := Cell[ applyCloudCellFixes @ text, args ];
fixCloudCell[ cells_List ] := fixCloudCell /@ cells;
fixCloudCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyCloudCellFixes*)
applyCloudCellFixes // beginDefinition;
applyCloudCellFixes[ text_String ] := text;
applyCloudCellFixes[ boxes_BoxData ] := boxes;
applyCloudCellFixes[ text_TextData ] := ReplaceRepeated[ text, $cloudCellFixes ];
applyCloudCellFixes // endDefinition;

$cloudCellFixes := $cloudCellFixes = Dispatch @ {
    TextData[ { a___, b_String, "|", c_String, d___ } ]  :> TextData @ { a, b<>"|"<>c, d },
    TextData[ { a___String } ]                           :> StringJoin @ a,
    TextData[ { a___, RowBox[ { b___String } ], c___ } ] :> TextData @ { a, StringJoin @ b, c },
    StyleBox[ a_ ]                                       :> a
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebooks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withNoRenderUpdates*)
withNoRenderUpdates // beginDefinition;
withNoRenderUpdates // Attributes = { HoldRest };

withNoRenderUpdates[ nbo_NotebookObject, evaluation_ ] :=
    WithCleanup[
        FrontEndExecute @ FrontEnd`NotebookSuspendScreenUpdates @ nbo,
        evaluation,
        FrontEndExecute @ FrontEnd`NotebookResumeScreenUpdates @ nbo
    ];

withNoRenderUpdates // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parentNotebook*)
parentNotebook // beginDefinition;
parentNotebook[ obj: _CellObject|_BoxObject ] := Notebooks @ obj;
parentNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookRead*)
notebookRead // beginDefinition;
notebookRead[ cells_ ] /; $cloudNotebooks := cloudNotebookRead @ cells;
notebookRead[ cells_ ] := NotebookRead @ cells;
notebookRead // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudNotebookRead*)
cloudNotebookRead // beginDefinition;
cloudNotebookRead[ cells: { ___CellObject } ] := NotebookRead /@ cells;
cloudNotebookRead[ cell_ ] := NotebookRead @ cell;
cloudNotebookRead // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Boxes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getBoxObjectFromBoxID*)
getBoxObjectFromBoxID // beginDefinition;

getBoxObjectFromBoxID[ obj_, None ] :=
    None;

getBoxObjectFromBoxID[ cell_CellObject, uuid_ ] :=
    Module[ { nbo },
        nbo = parentNotebook @ cell;
        If[ MatchQ[ nbo, _NotebookObject ],
            getBoxObjectFromBoxID[ nbo, uuid ],
            (* Getting the parent notebook can fail if the cell has been deleted: *)
            If[ ! TrueQ @ cellObjectQ @ cell,
                (* The cell is actually gone so return an appropriate `Missing` object: *)
                Missing[ "CellRemoved", cell ],
                (* The cell still exists, so something happened. Time to panic: *)
                throwInternalFailure @ getBoxObjectFromBoxID[ cell, uuid ]
            ]
        ]
    ];

getBoxObjectFromBoxID[ nbo_NotebookObject, uuid_String ] :=
    MathLink`CallFrontEnd @ FrontEnd`BoxReferenceBoxObject @ FE`BoxReference[ nbo, { { uuid } } ];

getBoxObjectFromBoxID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$suppressButtonAppearance*)
$suppressButtonAppearance = Dynamic @ FEPrivate`FrontEndResource[
    "FEExpressions",
    "SuppressMouseDownNinePatchAppearance"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toCompressedBoxes*)
toCompressedBoxes // beginDefinition;
toCompressedBoxes[ expr_ ] := compressRasterBoxes @ MakeBoxes @ expr;
toCompressedBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*compressRasterBoxes*)
compressRasterBoxes // beginDefinition;

compressRasterBoxes[ boxes_ ] :=
    ReplaceAll[
        boxes,
        {
            GraphicsBox[ TagBox[ RasterBox[ a: Except[ _String ], b___ ], c___ ], d___ ] :>
                With[ { compressed = Compress @ Unevaluated @ a },
                    GraphicsBox[ TagBox[ RasterBox[ CompressedData @ compressed, b ], c ], d ] /; True
                ],
            GraphicsBox[ RasterBox[ a: Except[ _String ], b___ ], c___ ] :>
                With[ { compressed = Compress @ Unevaluated @ a },
                    GraphicsBox[ RasterBox[ CompressedData @ compressed, b ], c ] /; True
                ]
        }
    ];

compressRasterBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*openerView*)
(* Effectively equivalent to OpenerView, except strips out the unnecessary interpretation information, and compresses
   the hidden part if it's very large.
*)
openerView[ args___ ] := openerView[ args ] = openerView0[ args ];

openerView0 // beginDefinition;
openerView0[ { a_, b_ }, args___ ] /; ByteCount @ b > 50000 := openerView1[ { a, compressUntilViewed @ b }, args ];
openerView0[ { a_, b_ }, args___ ] := openerView1[ { a, b }, args ];
openerView0 // endDefinition;

(*cspell: ignore patv *)
openerView1[ args___ ] := Quiet[
    RawBoxes @ ReplaceAll[
        Replace[ ToBoxes @ OpenerView @ args, TagBox[ boxes_, ___ ] :> boxes ],
        InterpretationBox[ boxes_, _OpenerView, ___ ] :> boxes
    ],
    Pattern::patv
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*compressUntilViewed*)
compressUntilViewed // beginDefinition;

compressUntilViewed[ expr_ ] :=
    With[ { b64 = BaseEncode @ BinarySerialize[ Unevaluated @ expr, PerformanceGoal -> "Size" ] },
        If[ ByteCount @ b64 < ByteCount @ expr,
            Dynamic[ BinaryDeserialize @ BaseDecode @ b64, SingleEvaluation -> True, DestroyAfterEvaluation -> True ],
            expr
        ]
    ];

compressUntilViewed // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Misc*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*replaceCellContext*)
replaceCellContext // beginDefinition;

replaceCellContext[ expr_ ] := replaceCellContext[ expr ] = ReplaceAll[
    expr,
    s_Symbol /; AtomQ @ Unevaluated @ s && Context @ Unevaluated @ s === "$CellContext`" :>
        With[ { new = ToExpression[ $Context <> SymbolName @ Unevaluated @ s, InputForm, $ConditionHold ] },
            RuleCondition[ new, True ]
        ]
];

replaceCellContext // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    $feTaskDebug = False;
    $cloudCellFixes;
];

End[ ];
EndPackage[ ];
