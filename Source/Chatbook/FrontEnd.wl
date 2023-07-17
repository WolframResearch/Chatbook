(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`FrontEnd`" ];

`$defaultChatSettings;
`$inEpilog;
`$suppressButtonAppearance;
`cellInformation;
`cellObjectQ;
`cellOpenQ;
`cellPrint;
`cellPrintAfter;
`cellStyles;
`checkEvaluationCell;
`currentChatSettings;
`fixCloudCell;
`getBoxObjectFromBoxID;
`notebookRead;
`parentCell;
`parentNotebook;
`rootEvaluationCell;
`rootEvaluationCell;
`selectionEvaluateCreateCell;
`toCompressedBoxes;
`topLevelCellQ;
`topParentCell;
`withNoRenderUpdates;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$checkEvaluationCell := $VersionNumber <= 13.2; (* Flag that determines whether to use workarounds for #187 *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CurrentValue Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*currentChatSettings*)
currentChatSettings // beginDefinition;

currentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession ] :=
    currentChatSettings0 @ obj;

currentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] :=
    currentChatSettings0[ obj, key ];

currentChatSettings[ cell0_CellObject ] := Catch @ Enclose[
    Module[ { cell, styles, nbo, cells, before, info, delimiter, settings },

        cell   = cell0;
        styles = cellStyles @ cell;

        If[ MemberQ[ styles, $$nestedCellStyle ],
            cell   = ConfirmMatch[ topParentCell @ cell, _CellObject, "ParentCell" ];
            styles = cellStyles @ cell;
        ];

        If[ MemberQ[ styles, $$chatDelimiterStyle ], Throw @ currentChatSettings0 @ cell ];

        nbo = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "ParentNotebook" ];

        cells = ConfirmMatch[
            Cells[ nbo, CellStyle -> Union[ $chatDelimiterStyles, styles ] ],
            { __CellObject },
            "ChatCells"
        ];

        before = ConfirmMatch[
            Replace[ cells, { { a___, cell, ___ } :> { a }, ___ :> $Failed } ],
            { ___CellObject },
            "BeforeCells"
        ];

        info = ConfirmMatch[
            cellInformation @ before,
            { KeyValuePattern[ "CellObject" -> _CellObject ]... },
            "CellInformation"
        ];

        delimiter = FirstCase[
            Reverse @ info,
            KeyValuePattern @ { "Style" -> $$chatDelimiterStyle, "CellObject" -> c_ } :> c,
            Nothing
        ];

        settings = Select[
            Map[ Association,
                 AbsoluteCurrentValue[ DeleteMissing @ { delimiter, cell }, { TaggingRules, "ChatNotebookSettings" } ]
            ],
            AssociationQ
        ];

        ConfirmBy[ Association[ $defaultChatSettings, settings ], AssociationQ, "CombinedSettings" ]
    ],
    throwInternalFailure[ currentChatSettings @ cell0, ## ] &
];

currentChatSettings[ cell0_CellObject, key_String ] := Catch @ Enclose[
    Module[ { cell, styles, nbo, cells, before, info, delimiter, values },

        cell   = cell0;
        styles = cellStyles @ cell;

        If[ MemberQ[ styles, $$nestedCellStyle ],
            cell   = ConfirmMatch[ topParentCell @ cell, _CellObject, "ParentCell" ];
            styles = cellStyles @ cell;
        ];

        If[ MemberQ[ styles, $$chatDelimiterStyle ], Throw @ currentChatSettings0[ cell, key ] ];

        nbo = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "ParentNotebook" ];

        cells = ConfirmMatch[
            Cells[ nbo, CellStyle -> Union[ $chatDelimiterStyles, styles ] ],
            { __CellObject },
            "ChatCells"
        ];

        before = ConfirmMatch[
            Replace[ cells, { { a___, cell, ___ } :> { a }, ___ :> $Failed } ],
            { ___CellObject },
            "BeforeCells"
        ];

        info = ConfirmMatch[
            cellInformation @ before,
            { KeyValuePattern[ "CellObject" -> _CellObject ]... },
            "CellInformation"
        ];

        delimiter = FirstCase[
            Reverse @ info,
            KeyValuePattern @ { "Style" -> $$chatDelimiterStyle, "CellObject" -> c_ } :> c,
            Nothing
        ];

        values = AbsoluteCurrentValue[
            DeleteMissing @ { delimiter, cell },
            { TaggingRules, "ChatNotebookSettings", key }
        ];

        FirstCase[ values, Except[ Inherited ], Lookup[ $defaultChatSettings, key, Inherited ] ]
    ],
    throwInternalFailure[ currentChatSettings[ cell0, key ], ## ] &
];

currentChatSettings // endDefinition;


currentChatSettings0 // beginDefinition;

currentChatSettings0[ obj: _CellObject|_NotebookObject|_FrontEndObject|$FrontEndSession ] :=
    Association[
        $defaultChatSettings,
        Replace[
            Association @ AbsoluteCurrentValue[ obj, { TaggingRules, "ChatNotebookSettings" } ],
            Except[ _? AssociationQ ] :> <| |>
        ]
    ];

currentChatSettings0[ obj: _CellObject|_NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] := Replace[
    AbsoluteCurrentValue[ obj, { TaggingRules, "ChatNotebookSettings", key } ],
    Inherited :> Lookup[ $defaultChatSettings, key, Inherited ]
];

currentChatSettings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$defaultChatSettings*)
$defaultChatSettings := Association @ Options @ CreateChatNotebook;

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
rootEvaluationCell[ ] := rootEvaluationCell @ EvaluationCell[ ];

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
        throwInternalFailure[ rootEvaluationCell[ source, cells ], ## ] &
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
        Thread[ "CellObject" -> cells ],
        Developer`CellInformation @ cells,
        Thread[ "CellAutoOverwrite" -> CurrentValue[ cells, CellAutoOverwrite ] ]
    }
];

cellInformation[ cell_CellObject ] := Association[
    "CellObject" -> cell,
    Developer`CellInformation @ cell,
    "CellAutoOverwrite" -> CurrentValue[ cell, CellAutoOverwrite ]
];

cellInformation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parentCell*)
parentCell // beginDefinition;
parentCell[ cell_CellObject ] /; $cloudNotebooks := cell;
parentCell[ obj: _CellObject|_BoxObject ] := ParentCell @ obj;
parentCell // endDefinition;

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
topParentCell[ cell_CellObject ] := With[ { p = parentCell @ cell }, topParentCell @ p /; MatchQ[ p, _CellObject ] ];
topParentCell[ cell_CellObject ] := cell;
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
parentNotebook[ cell_CellObject ] /; $cloudNotebooks := Notebooks @ cell;
parentNotebook[ cell_CellObject ] := ParentNotebook @ cell;
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
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    $cloudCellFixes;
];

End[ ];
EndPackage[ ];
