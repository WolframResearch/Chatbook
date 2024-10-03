(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`FrontEnd`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)

(* cSpell: ignore Rasterizer *)
$cloudRasterizerLocation = "/Chatbook/API/RasterizerService";

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

createFETask[ eval_ ] :=
    With[ { inline = $InlineChat, state = $inlineChatState, id = $chatEvaluationID, t = $chatStartTime },
        If[ $feTaskDebug, Internal`StuffBag[ $feTaskLog, <| "Task" -> Hold @ eval, "Created" -> AbsoluteTime[ ] |> ] ];
        (* FIXME: This Block is a bit of a hack: *)
        AppendTo[
            $feTasks,
            Hold @ Block[
                {
                    $InlineChat       = inline,
                    $inlineChatState  = state,
                    $chatEvaluationID = id,
                    $chatStartTime    = t
                },
                eval
            ]
        ];
        ++$feTaskCreationCount;
        ++$feTaskTrigger
    ];

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
(*$evaluationCell*)
$evaluationCell :=
    With[ { cell = EvaluationCell[ ] },
        If[ TrueQ[ $chatState && MatchQ[ cell, _CellObject ] ],
            $evaluationCell = cell,
            cell
        ]
    ];

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


rootEvaluationCell[ cell_CellObject, None ] := None;

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

cellInformation[ nbo_NotebookObject, a___ ] :=
    cellInformation[ Cells @ nbo, a ];

cellInformation[ cells: { ___CellObject } ] := Select[
    Map[
        Association,
        Transpose @ {
            Developer`CellInformation @ cells,
            Thread[ "CellObject"           -> cells ],
            Thread[ "CellAutoOverwrite"    -> CurrentValue[ cells, CellAutoOverwrite ] ],
            Thread[ "ChatNotebookSettings" -> AbsoluteCurrentValue[ cells, { TaggingRules, "ChatNotebookSettings" } ] ]
        }
    ],
    AssociationQ
];

cellInformation[ cell_CellObject ] :=
    With[ { info = Association @ Developer`CellInformation @ cell },
        If[ AssociationQ @ info,
            Association[
                info,
                "CellObject"           -> cell,
                "CellAutoOverwrite"    -> CurrentValue[ cell, CellAutoOverwrite ],
                "ChatNotebookSettings" -> AbsoluteCurrentValue[ cell, { TaggingRules, "ChatNotebookSettings" } ]
            ],
            Missing[ "NotAvailable" ]
        ]
    ];

cellInformation[ cells: { ___CellObject }, key_String ] :=
    Replace[
        cellInformation @ cells,
        as: KeyValuePattern @ { } :> Lookup[ as, key, Missing[ "NotAvailable" ] ],
        { 1 }
    ];

cellInformation[ cell_CellObject, key_String ] :=
    Replace[
        cellInformation @ cell,
        as: KeyValuePattern @ { } :> Lookup[ as, key, Missing[ "NotAvailable" ] ]
    ];

cellInformation[ cells: { ___CellObject }, keys: { ___String } ] :=
    Replace[
        cellInformation @ cells,
        as: KeyValuePattern @ { } :> KeyTake[ as, keys ],
        { 1 }
    ];

cellInformation[ cell_CellObject, keys: { ___String } ] :=
    Replace[
        cellInformation @ cell,
        as: KeyValuePattern @ { } :> KeyTake[ as, keys ]
    ];

cellInformation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookInformation*)
notebookInformation // beginDefinition;

notebookInformation[ ] :=
    notebookInformation @ Notebooks[ ];

notebookInformation[ All ] :=
    notebookInformation @ Notebooks[ ];

notebookInformation[ nbo_NotebookObject ] := Enclose[
    Catch @ Module[ { throwIfClosed, info, visible, windowClickSelect, selected, input, settings },

        throwIfClosed = Replace[ Missing[ "NotebookClosed", ___ ] | $Failed :> Throw @ missingNotebook @ nbo ];

        info = ConfirmMatch[ throwIfClosed @ notebookInformation0 @ nbo, _? AssociationQ, "Info" ];

        visible = ConfirmMatch[
            throwIfClosed @ AbsoluteCurrentValue[ nbo, Visible ],
            True|False|Inherited,
            "Visible"
        ];

        windowClickSelect = ConfirmMatch[
            throwIfClosed @ AbsoluteCurrentValue[ nbo, WindowClickSelect ],
            True|False|Inherited,
            "WindowClickSelect"
        ];

        selected = SelectedNotebook[ ] === nbo;
        input    = InputNotebook[ ]    === nbo;

        settings = ConfirmBy[
            throwIfClosed @ Association @ Replace[
                AbsoluteCurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings" } ],
                Inherited :> AbsoluteCurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ]
            ],
            AssociationQ,
            "Settings"
        ];

        ConfirmBy[
            KeySort @ DeleteMissing @ <|
                "ChatNotebookSettings" -> settings,
                "ID"                   -> tinyHash @ nbo,
                "InputNotebook"        -> TrueQ @ input,
                "NotebookObject"       -> nbo,
                "SelectedNotebook"     -> TrueQ @ selected,
                "Visible"              -> TrueQ @ visible,
                "WindowClickSelect"    -> TrueQ @ windowClickSelect,
                info
            |>,
            AssociationQ,
            "Result"
        ]
    ],
    throwInternalFailure
];

(* Definition that's optimized for listable FE calls: *)
notebookInformation[ notebooks_List ] :=
    notebooksInformation @ notebooks;

notebookInformation // endDefinition;


notebookInformation0 // beginDefinition;

notebookInformation0[ nbo_NotebookObject ] := Enclose[
    Catch @ Module[ { info, as },
        info = NotebookInformation @ nbo;
        If[ FailureQ @ info, Throw @ Missing[ "NotebookClosed", nbo ] ];
        as = ConfirmBy[ Association @ info, AssociationQ, "Association" ];
        ConfirmBy[ AssociationMap[ formatNotebookInformation, as ], AssociationQ, "Formatted" ]
    ],
    throwInternalFailure
];

notebookInformation0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebooksInformation*)
notebooksInformation // beginDefinition;

notebooksInformation[ { } ] := { };

notebooksInformation[ notebooks: { __NotebookObject } ] := Enclose[
    Module[
        { nbObjects, visible, windowClickSelect, selected, input, id, settings, feSettings, info, transposed, result },

        nbObjects         = Thread[ "NotebookObject"    -> notebooks ];
        visible           = Thread[ "Visible"           -> AbsoluteCurrentValue[ notebooks, Visible ] ];
        windowClickSelect = Thread[ "WindowClickSelect" -> AbsoluteCurrentValue[ notebooks, WindowClickSelect ] ];
        selected          = Thread[ "SelectedNotebook"  -> Map[ SameAs @ SelectedNotebook[ ], notebooks ] ];
        input             = Thread[ "InputNotebook"     -> Map[ SameAs @ InputNotebook[ ], notebooks ] ];
        id                = Thread[ "ID"                -> tinyHash /@ notebooks ];

        settings = Thread[
            "ChatNotebookSettings" -> AbsoluteCurrentValue[ notebooks, { TaggingRules, "ChatNotebookSettings" } ]
        ];

        If[ MemberQ[ settings, "ChatNotebookSettings" -> Inherited ],
            feSettings = AbsoluteCurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
            settings = Replace[ settings, Inherited -> feSettings, { 2 } ]
        ];

        info = notebookInformation0 /@ notebooks;

        transposed = ConfirmBy[
            Transpose @ { info, nbObjects, visible, windowClickSelect, selected, input, id, settings },
            ListQ,
            "Transpose"
        ];

        result = ConfirmMatch[
            combineNotebookInfo /@ transposed,
            { (_? AssociationQ | Missing[ "NotebookClosed", _NotebookObject ])... },
            "Result"
        ];

        ConfirmAssert[ Length @ result === Length @ notebooks, "LengthCheck" ];

        result
    ],
    throwInternalFailure
];

notebooksInformation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*combineNotebookInfo*)
combineNotebookInfo // beginDefinition;
combineNotebookInfo[ a: { $Failed | Missing[ "NotebookClosed", ___ ], ___ } ] := missingNotebook @ a;
combineNotebookInfo[ a_List ] := With[ { as = Association @ a }, KeySort @ DeleteMissing @ as /; notebookInfoQ @ as ];
combineNotebookInfo[ a_List ] := missingNotebook @ a;
combineNotebookInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*missingNotebook*)
missingNotebook // beginDefinition;
missingNotebook[ { _, "NotebookObject" -> nbo_NotebookObject, ___ } ] := missingNotebook @ nbo;
missingNotebook[ nbo_NotebookObject ] := Missing[ "NotebookClosed", nbo ];
missingNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookInfoQ*)
notebookInfoQ // beginDefinition;
notebookInfoQ[ as_Association? AssociationQ ] := FreeQ[ as, _FrontEnd`AbsoluteCurrentValue|$Failed, { 1 } ];
notebookInfoQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatNotebookInformation*)
formatNotebookInformation // beginDefinition;
formatNotebookInformation[ (Rule|RuleDelayed)[ key_, value_ ] ] := formatNotebookInformation[ key, value ];
formatNotebookInformation[ "Uri", value_ ] := formatNotebookInformation[ "FileName", value ];
formatNotebookInformation[ key_, value_ ] := ToString @ key -> formatNotebookInformation0[ key, value ];
formatNotebookInformation // endDefinition;

formatNotebookInformation0 // beginDefinition;
formatNotebookInformation0[ "FileName", file_ ] := toFileName @ file;
formatNotebookInformation0[ "FileModificationTime", t_Real ] := formatNotebookInformation0[ "Timestamp", t ];
formatNotebookInformation0[ "MemoryModificationTime", t_Real ] := formatNotebookInformation0[ "Timestamp", t ];
formatNotebookInformation0[ "Timestamp", t_Real ] := TimeZoneConvert @ DateObject[ t, TimeZone -> 0 ];
formatNotebookInformation0[ key_String, value_ ] := value;
formatNotebookInformation0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toFileName*)
toFileName // beginDefinition;
toFileName[ file_ ] := toFileName[ file ] = toFileName0 @ file;
toFileName // endDefinition;

toFileName0 // beginDefinition;
toFileName0[ file0_FrontEnd`FileName ] := With[ { file = ToFileName @ file0 }, toFileName0 @ file /; StringQ @ file ];
toFileName0[ file_String ] := StringReplace[ file, "\\" -> "/" ];
toFileName0[ file_ ] := file;
toFileName0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fromFETimestamp*)
(* TODO: use this when passing notebook info to the LLM *)
fromFETimestamp // beginDefinition;

fromFETimestamp[ t_Real ] := Enclose[
    Module[ { date, string, relative },
        date     = ConfirmBy[ TimeZoneConvert @ DateObject[ t, TimeZone -> 0 ], DateObjectQ, "Date" ];
        string   = ConfirmBy[ DateString[ date, { "ISODateTime", ".", "Millisecond" } ], StringQ, "String" ];
        relative = ConfirmBy[ relativeTimeString @ date, StringQ, "Relative" ];
        string<>" ("<>relative<>")"
    ],
    throwInternalFailure
];

fromFETimestamp // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*parentCell*)
parentCell // beginDefinition;
parentCell[ obj: _CellObject|_BoxObject ] /; $cloudNotebooks := cloudParentCell @ obj;
parentCell[ obj: _CellObject|_BoxObject ] := ParentCell @ obj;
parentCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*nextCell*)
nextCell // beginDefinition;
nextCell // Options = { CellStyle -> Automatic };

nextCell[ cell_CellObject, opts: OptionsPattern[ ] ] :=
    If[ TrueQ @ $cloudNotebooks,
        cloudNextCell[ cell, OptionValue[ CellStyle ] ],
        NextCell[ cell, opts ]
    ];

nextCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudNextCell*)
cloudNextCell // beginDefinition;

cloudNextCell[ cell_CellObject, style_ ] :=
    cloudNextCell[ cell, parentNotebook @ cell, style ];

cloudNextCell[ cell_CellObject, nbo_NotebookObject, style_ ] :=
    cloudNextCell[ cell, Cells @ nbo, style ];

cloudNextCell[ cell_, { ___, cell_, next_CellObject, ___ }, Automatic ] :=
    next;

cloudNextCell[ cell_, { ___, cell_, after__CellObject }, style_ ] :=
    SelectFirst[ { after }, MemberQ[ cellStyles @ #, style ] &, None ];

cloudNextCell[ _CellObject, _, _ ] :=
    None;

cloudNextCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*previousCell*)
previousCell // beginDefinition;
previousCell[ cell_CellObject ] /; $cloudNotebooks := previousCell[ cell, parentNotebook @ cell ];
previousCell[ cell_CellObject ] := PreviousCell @ cell;
previousCell[ cell_CellObject, nbo_NotebookObject ] := previousCell[ cell, Cells @ nbo ];
previousCell[ cell_, { ___, previous_CellObject, cell_, ___ } ] := previous;
previousCell[ _CellObject, ___ ] := None;
previousCell // endDefinition;

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
cellPrint[ cell_Cell ] /; $cloudNotebooks := contextBlock @ cloudCellPrint @ cell;
cellPrint[ cell_Cell ] := contextBlock @ MathLink`CallFrontEnd @ FrontEnd`CellPrintReturnObject @ cell;
cellPrint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudCellPrint*)
cloudCellPrint // beginDefinition;

cloudCellPrint[ cell_Cell ] :=
    With[ { obj = MathLink`CallFrontEnd @ FrontEnd`CellPrintReturnObject @ cell },
        obj /; MatchQ[ obj, _CellObject ]
    ];

cloudCellPrint[ Cell[ a__, CellTags -> tags0_, b___ ] ] := Enclose[
    Module[ { uuid, tags, cell, obj },
        uuid = ConfirmBy[ CreateUUID[ ], StringQ, "UUID" ];
        tags = Select[ Flatten @ { tags0, uuid }, StringQ ];
        cell = Cell[ a, CellTags -> tags, b ];
        CellPrint @ cell;
        obj = First @ ConfirmMatch[ Cells[ CellTags -> uuid ], { _CellObject }, "Cells" ];
        SetOptions[ obj, CellTags -> Replace[ tags, { uuid } -> Inherited ] ];
        obj
    ],
    throwInternalFailure
];

cloudCellPrint[ Cell[ a___ ] ] :=
    cloudCellPrint @ Cell[ a, CellTags -> { } ];

cloudCellPrint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellPrintAfter*)
cellPrintAfter[ target_ ][ cell_ ] := cellPrintAfter[ target, cell ];

cellPrintAfter[ target_CellObject, cell: Cell[ __, ExpressionUUID -> uuid_, ___ ] ] := (
    SelectionMove[ target, After, Cell, AutoScroll -> False ];
    contextBlock @ NotebookWrite[ parentNotebook @ target, cell ];
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
fixCloudCell[ content: _BoxData|_TextData|_String ] := applyCloudCellFixes @ content;
fixCloudCell[ cells_List ] := fixCloudCell /@ cells;
fixCloudCell[ cell_ ] := cell;
fixCloudCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyCloudCellFixes*)
applyCloudCellFixes // beginDefinition;
applyCloudCellFixes[ text_TextData ] := ReplaceRepeated[ text, $cloudCellFixes ];
applyCloudCellFixes[ boxes_ ] := boxes;
applyCloudCellFixes // endDefinition;

$cloudCellFixes := $cloudCellFixes = Dispatch @ {
    TextData[ { a___, b_String, "|", c_String, d___ } ]  :> TextData @ { a, b<>"|"<>c, d },
    TextData[ { a___String } ]                           :> StringJoin @ a,
    TextData[ { a___, RowBox[ { b___String } ], c___ } ] :> TextData @ { a, StringJoin @ b, c },
    StyleBox[ a_ ]                                       :> a
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellReference*)
cellReference // beginDefinition;
cellReference[ cell_CellObject ] := Lookup[ $cellReferences, cell, createCellReference @ cell ];
cellReference[ ref_String      ] := Lookup[ $cellReferences, ref , findCellReference @ ref    ];
cellReference // endDefinition;

$cellReferences = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createCellReference*)
createCellReference // beginDefinition;

createCellReference[ cell_CellObject ] :=
    With[ { ref = tinyHash @ cell },
        $cellReferences[ cell ] = ref;
        $cellReferences[ ref ] = cell;
        ref
    ];

createCellReference // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*findCellReference*)
findCellReference // beginDefinition;
findCellReference[ ref_String ] /; StringLength @ ref > $tinyHashLength := findCellReferenceInString @ ref;
findCellReference[ ref_String ] := Catch[ findNotebookCell[ ref ] /@ Notebooks[ ]; Missing[ "NotFound" ], $ref ];
findCellReference // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*findCellReferenceInString*)
findCellReferenceInString // beginDefinition;
findCellReferenceInString[ s_String ] := findCellReferenceInString[ s, Select[ Keys @ $cellReferences, StringQ ] ];
findCellReferenceInString[ s_String, refs: { ___String } ] := First[ StringCases[ s, refs, 1 ], Missing[ "NotFound" ] ];
findCellReferenceInString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*findNotebookCell*)
findNotebookCell // beginDefinition;
findNotebookCell[ ref_ ] := findNotebookCell[ ref, # ] &;
findNotebookCell[ ref_, nbo_ ] := checkCellReference[ ref ] /@ Cells @ nbo;
findNotebookCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*checkCellReference*)
checkCellReference // beginDefinition;
checkCellReference[ ref_ ] := checkCellReference[ ref, # ] &;
checkCellReference[ ref_, cell_CellObject ] := With[ { r = cellReference @ cell }, Throw[ cell, $ref ] /; ref === r ];
checkCellReference[ _, _ ] := Null;
checkCellReference // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebooks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$evaluationNotebook*)
$evaluationNotebook :=
    With[ { nbo = evaluationNotebook[ ] },
        If[ TrueQ[ $chatState && MatchQ[ nbo, _NotebookObject ] ],
            $evaluationNotebook = nbo,
            nbo
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*evaluationNotebook*)
evaluationNotebook // beginDefinition;
evaluationNotebook[ ] := evaluationNotebook @ $evaluationCell;
evaluationNotebook[ cell_CellObject ] := With[ { nbo = parentNotebook @ cell }, nbo /; MatchQ[ nbo, _NotebookObject ] ];
evaluationNotebook[ _ ] := EvaluationNotebook[ ];
evaluationNotebook // endDefinition;

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
parentNotebook[ obj: _CellObject|_BoxObject ] := parentNotebook[ obj, Notebooks @ obj ];
parentNotebook[ obj_, nbo_NotebookObject ] := nbo;
parentNotebook[ obj_CellObject, _? FailureQ ] := tryInlineChatParent @ obj;
parentNotebook[ _, fail_ ] := fail;
parentNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tryInlineChatParent*)
tryInlineChatParent // beginDefinition;
tryInlineChatParent[ obj_CellObject ] := tryInlineChatParent[ obj, currentChatSettings[ obj, "InlineChatRootCell" ] ];
tryInlineChatParent[ obj_, cell_CellObject ] := Notebooks @ cell;
tryInlineChatParent[ _, _ ] := $Failed;
tryInlineChatParent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookRead*)
notebookRead // beginDefinition;
notebookRead[ cells_ ] /; $cloudNotebooks := cloudNotebookRead @ cells;
notebookRead[ cells_ ] := notebookReadWithCellObjects @ cells;
notebookRead // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudNotebookRead*)
cloudNotebookRead // beginDefinition;
cloudNotebookRead[ cells: { ___CellObject } ] := notebookReadWithCellObjects /@ cells;
cloudNotebookRead[ cell_ ] := notebookReadWithCellObjects @ cell;
cloudNotebookRead // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookReadWithCellObjects*)
notebookReadWithCellObjects // beginDefinition;
notebookReadWithCellObjects[ cell_CellObject ] := appendCellObject[ NotebookRead @ cell, cell ];
notebookReadWithCellObjects[ cells: { ___CellObject } ] := appendCellObject[ NotebookRead @ cells, cells ];
notebookReadWithCellObjects[ other_ ] := NotebookRead @ other;
notebookReadWithCellObjects // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*appendCellObject*)
appendCellObject // beginDefinition;
appendCellObject[ Cell[ a___ ], obj_CellObject ] := Cell[ a, CellObject -> obj ];
appendCellObject[ cells: { ___Cell }, objs: { ___CellObject } ] := MapThread[ appendCellObject, { cells, objs } ];
appendCellObject // endDefinition;

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
    MathLink`CallFrontEnd @ FrontEnd`BoxReferenceBoxObject @ FE`BoxReference[
        nbo,
        { { uuid } },
        FE`SearchStart -> "StartFromBeginning",
        FE`SearchStop  -> "StopAtEnd"
    ];

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
openerView[ args___ ] := Verbatim[ openerView[ args ] ] = openerView0[ args ];

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
    compressUntilViewed[ Unevaluated @ expr, False ];

compressUntilViewed[ expr_, False ] :=
    With[ { b64 = BaseEncode @ BinarySerialize[ Unevaluated @ expr, PerformanceGoal -> "Size" ] },
        Dynamic[ BinaryDeserialize @ BaseDecode @ b64, SingleEvaluation -> True, DestroyAfterEvaluation -> True ]
    ];

compressUntilViewed[ expr_, True ] :=
    With[ { b64 = BaseEncode @ BinarySerialize[ Unevaluated @ expr, PerformanceGoal -> "Size" ] },
        DynamicModule[
            { display },
            Dynamic[ Replace[ display, _Symbol :> ProgressIndicator[ Appearance -> "Percolate" ] ] ],
            Initialization            :> (display = BinaryDeserialize @ BaseDecode @ b64),
            SynchronousInitialization -> False,
            UnsavedVariables          :> { display }
        ]
    ];

compressUntilViewed // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$statelessProgressIndicator*)

(* TODO: move this to the stylesheet *)
$statelessProgressIndicator =
    With[ { clock := Clock[ 10, 1.5 ] },
        RawBoxes @ GraphicsBox[
            {
                GrayLevel[ 0.75 ],
                {
                    {
                        PointSize @ Dynamic @ FEPrivate`Which[
                            FEPrivate`Less[ clock, 0 ],
                            0.08,
                            FEPrivate`Less[ clock, 2 ],
                            0.08 + 0.05 * clock,
                            FEPrivate`Less[ clock, 4 ],
                            0.28 - (0.05 * clock),
                            True,
                            0.08
                        ],
                        PointBox @ { 0, 0 }
                    },
                    {
                        PointSize @ Dynamic @ FEPrivate`Which[
                            FEPrivate`Less[ clock, 1 ],
                            0.08,
                            FEPrivate`Less[ clock, 3 ],
                            0.03 + 0.05 * clock,
                            FEPrivate`Less[ clock, 5 ],
                            0.33 - (0.05 * clock),
                            True,
                            0.08
                        ],
                        PointBox @ { 1, 0 }
                    },
                    {
                        PointSize @ Dynamic @ FEPrivate`Which[
                            FEPrivate`Less[ clock, 2 ],
                            0.08,
                            FEPrivate`Less[ clock, 4 ],
                            -0.02 + 0.05 * clock,
                            FEPrivate`Less[ clock, 6 ],
                            0.38 - (0.05 * clock),
                            True,
                            0.08
                        ],
                        PointBox @ { 2, 0 }
                    },
                    {
                        PointSize @ Dynamic @ FEPrivate`Which[
                            FEPrivate`Less[ clock, 3 ],
                            0.08,
                            FEPrivate`Less[ clock, 5 ],
                            -0.07 + 0.05 * clock,
                            FEPrivate`Less[ clock, 7 ],
                            0.43 - (0.05 * clock),
                            True,
                            0.08
                        ],
                        PointBox @ { 3, 0 }
                    },
                    {
                        PointSize @ Dynamic @ FEPrivate`Which[
                            FEPrivate`Less[ clock, 4 ],
                            0.08,
                            FEPrivate`Less[ clock, 6 ],
                            -0.12 + 0.05 * clock,
                            FEPrivate`Less[ clock, 8 ],
                            0.48 - (0.05 * clock),
                            True,
                            0.08
                        ],
                        PointBox @ { 4, 0 }
                    }
                }
            },
            AspectRatio -> Full,
            ImageSize   -> { 50, 12 },
            PlotRange   -> { { -1, 5 }, { -1, 1 } }
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Misc*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*usingFrontEnd*)
usingFrontEnd // beginDefinition;
usingFrontEnd // Attributes = { HoldFirst };

usingFrontEnd[ eval_ ] :=
    Block[ { usingFrontEnd = # &, $usingFE = True },
        If[ TrueQ @ $CloudEvaluation,
            PreemptProtect @ UsingFrontEnd @ eval,
            UsingFrontEnd @ eval
        ]
    ];

usingFrontEnd // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*rasterizeBlock*)
(* Ensures that any Rasterize calls that occur in `eval` will get wrapped in `PreemptProtect` when in cloud. *)
rasterizeBlock // beginDefinition;
rasterizeBlock // Attributes = { HoldFirst };

rasterizeBlock[ eval_ ] := Block[ { rasterizeBlock = # & },
    Internal`InheritedBlock[ { Rasterize },

        Unprotect @ Rasterize;

        PrependTo[
            DownValues @ Rasterize,
            HoldPattern @ Rasterize[ a___ ] /; ! TrueQ @ $usingFE :>
                usingFrontEnd @ Rasterize @ a
        ];

        Protect @ Rasterize;

        eval
    ]
];

rasterizeBlock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*rasterize*)
rasterize // beginDefinition;
rasterize[ expr_, opts___ ] := usingFrontEnd @ Rasterize[ Unevaluated @ expr, opts ];
rasterize // endDefinition;

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
addToMXInitialization[
    $feTaskDebug = False;
    $cloudCellFixes;
];

End[ ];
EndPackage[ ];
