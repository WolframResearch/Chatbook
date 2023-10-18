(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`FrontEnd`" ];

Wolfram`Chatbook`CurrentChatSettings;

`$defaultChatSettings;
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
`currentChatSettings;
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

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$checkEvaluationCell := $VersionNumber <= 13.2; (* Flag that determines whether to use workarounds for #187 *)

$$feObj = _FrontEndObject | $FrontEndSession | _NotebookObject | _CellObject | _BoxObject;

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
(* ::Section::Closed:: *)
(*CurrentChatSettings*)
GeneralUtilities`SetUsage[ CurrentChatSettings, "\
CurrentChatSettings[obj$, \"key$\"] gives the current chat settings for the CellObject or NotebookObject obj$ for the specified key.
CurrentChatSettings[obj$] gives all current chat settings for obj$.
CurrentChatSettings[] is equivalent to CurrentChatSettings[EvaluationCell[]].
CurrentChatSettings[\"key$\"] is equivalent to CurrentChatSettings[EvaluationCell[], \"key$\"].\
" ];

CurrentChatSettings[ ] := catchMine @
    If[ TrueQ @ $Notebooks,
        CurrentChatSettings @ $currentEvaluationObject,
        $defaultChatSettings
    ];

CurrentChatSettings[ key_String ] := catchMine @
    If[ TrueQ @ $Notebooks,
        CurrentChatSettings[ $currentEvaluationObject, key ],
        Lookup[ $defaultChatSettings, key, Inherited ]
    ];

CurrentChatSettings[ cell_CellObject ] := catchMine @
    With[ { parent = Quiet @ parentCell @ cell },
        If[ MatchQ[ parent, Except[ cell, _CellObject ] ],
            CurrentChatSettings @ parent,
            $defaultChatSettings
        ]
    ];

CurrentChatSettings[ cell_CellObject, key_String ] := catchMine @
    With[ { parent = Quiet @ parentCell @ cell },
        If[ MatchQ[ parent, Except[ cell, _CellObject ] ],
            CurrentChatSettings[ parent, key ],
            Lookup[ $defaultChatSettings, key, Inherited ]
        ]
    ];

CurrentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession ] := catchMine @
    If[ TrueQ @ $Notebooks,
        currentChatSettings @ obj,
        $defaultChatSettings
    ];

CurrentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] := catchMine @
    If[ TrueQ @ $Notebooks,
        currentChatSettings[ obj, key ],
        Lookup[ $defaultChatSettings, key, Inherited ]
    ];

CurrentChatSettings[ args___ ] :=
    catchMine @ throwFailure[ "InvalidArguments", CurrentChatSettings, HoldForm @ CurrentChatSettings @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$currentEvaluationObject*)

(* During asynchronous tasks, EvaluationCell[ ] will return $Failed, so we instead use this to take the first FE object
   in ascending order of inheritance that we can read settings from. *)
$currentEvaluationObject := FirstCase[
    Unevaluated @ {
        EvaluationCell[ ],
        EvaluationNotebook[ ],
        $FrontEndSession
    },
    obj_ :> With[ { res = obj }, res /; MatchQ[ res, $$feObj ] ],
    throwInternalFailure @ $currentEvaluationObject
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*verifyInheritance*)
verifyInheritance // beginDefinition;
verifyInheritance[ obj: $$feObj ] /; $cloudNotebooks := True;
verifyInheritance[ obj: $$feObj? inheritingQ ] := True;
verifyInheritance[ obj: $$feObj ] := With[ { verified = verifyInheritance0 @ obj }, True /; inheritingQ @ obj ];
verifyInheritance // endDefinition;


verifyInheritance0 // beginDefinition;

(* Repair tagging rules at top-level and set the inheritance flag: *)
verifyInheritance0[ fe_FrontEndObject ] := Enclose[
    Module[ { tags },

        tags = ConfirmMatch[
            trToAssociations @ CurrentValue[ fe, TaggingRules ],
            _? AssociationQ | Inherited,
            "Tags"
        ];

        CurrentValue[ fe, TaggingRules ] = tags;
        CurrentValue[ fe, { TaggingRules, "ChatNotebookSettings", "InheritanceTest" } ] = True;

        ConfirmBy[ CurrentValue[ fe, TaggingRules ], AssociationQ, "Verify" ]
    ],
    throwInternalFailure[ verifyInheritance0 @ fe, ## ] &
];

(* Otherwise, recurse upwards repairing tagging rules: *)
verifyInheritance0[ obj: Except[ _FrontEndObject, $$feObj ] ] :=
    Module[ { parent, tags },
        parent = feParentObject @ obj;
        tags   = verifyInheritance0 @ parent;
        repairTaggingRules[ obj, tags ]
    ];

verifyInheritance0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inheritingQ*)
inheritingQ // beginDefinition;

inheritingQ[ obj: $$feObj ] :=
    TrueQ @ AbsoluteCurrentValue[ obj, { TaggingRules, "ChatNotebookSettings", "InheritanceTest" } ];

inheritingQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*repairTaggingRules*)
repairTaggingRules // beginDefinition;

repairTaggingRules[ box_BoxObject, parentTags_Association? AssociationQ ] := parentTags;

repairTaggingRules[ obj: $$feObj, parentTags_Association? AssociationQ ] := Enclose[
    Module[ { tags, keep },

        tags = ConfirmMatch[
            trToAssociations @ CurrentValue[ obj, TaggingRules ],
            _? AssociationQ | Inherited,
            "Tags"
        ];

        keep = ConfirmMatch[
            associationComplement[ tags, parentTags ],
            _? AssociationQ | Inherited,
            "Complement"
        ];

        If[ keep[ "ChatNotebookSettings", "InheritanceTest" ],
            keep[ "ChatNotebookSettings", "InheritanceTest" ] =.
        ];

        If[ keep === <| |>,
            CurrentValue[ obj, TaggingRules ] = Inherited,
            CurrentValue[ obj, TaggingRules ] = keep
        ]
    ],
    throwInternalFailure[ repairTaggingRules[ obj, parentTags ], ## ] &
];

repairTaggingRules // endDefinition;

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
(* ::Subsubsection::Closed:: *)
(*trToAssociations*)
trToAssociations // beginDefinition;
trToAssociations[ expr_ ] := Replace[ trToAssociations0 @ expr, { } | <| |> -> Inherited ];
trToAssociations // endDefinition;

trToAssociations0 // beginDefinition;

trToAssociations0[ as_Association? AssociationQ ] :=
    Replace[
        DeleteCases[ trToAssociations /@ as /. HoldPattern @ trToAssociations[ expr_ ] :> expr, <| |> | Inherited ],
        <| |> -> Inherited
    ];

trToAssociations0[ { rules: (Rule|RuleDelayed)[ _, _ ].. } ] :=
    trToAssociations0 @ Association @ rules;

trToAssociations0[ expr_ ] :=
    expr;

trToAssociations0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*associationComplement*)
associationComplement // beginDefinition;

associationComplement[ as1_? AssociationQ, as2_? AssociationQ ] :=
    Module[ { complement, common },
        complement = Complement[ as1, as2 ];
        common     = Intersection[ Keys @ complement, Keys @ as2 ];
        Scan[ Function[ complement[ # ] = associationComplement[ as1[ # ], as2[ # ] ] ], common ];
        complement
    ];

associationComplement[ as1: { (Rule|RuleDelayed)[ _, _ ]... }, as2_ ] :=
    associationComplement[ Association @ as1, as2 ];

associationComplement[ as1_, as2: { (Rule|RuleDelayed)[ _, _ ]... } ] :=
    associationComplement[ as1, Association @ as2 ];

associationComplement[ as_, _ ] := as;

associationComplement // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*currentChatSettings*)
currentChatSettings // beginDefinition;

currentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession ] := (
    verifyInheritance @ obj;
    currentChatSettings0 @ obj
);

currentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] := (
    verifyInheritance @ obj;
    currentChatSettings0[ obj, key ]
);

currentChatSettings[ cell0_CellObject ] := Catch @ Enclose[
    Module[ { cell, cellInfo, styles, nbo, delimiter, settings },

        verifyInheritance @ cell0;

        cell     = cell0;
        cellInfo = ConfirmBy[ cellInformation @ cell, AssociationQ, "CellInformation" ];
        styles   = ConfirmMatch[ Flatten @ List @ Lookup[ cellInfo, "Style" ], { ___String } ];

        If[ MemberQ[ styles, $$nestedCellStyle ],
            cell   = ConfirmMatch[ topParentCell @ cell, _CellObject, "ParentCell" ];
            styles = cellStyles @ cell;
        ];

        If[ cellInfo[ "ChatNotebookSettings", "ChatDelimiter" ], Throw @ currentChatSettings0 @ cell ];

        nbo = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "ParentNotebook" ];

        delimiter = ConfirmMatch[ getPrecedingDelimiter[ cell, nbo ], _CellObject|_Missing, "Delimiter" ];

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
    Module[ { cell, cellInfo, styles, nbo, cells, delimiter, values },

        verifyInheritance @ cell0;

        cell     = cell0;
        cellInfo = ConfirmBy[ cellInformation @ cell, AssociationQ, "CellInformation" ];
        styles   = ConfirmMatch[ Flatten @ List @ Lookup[ cellInfo, "Style" ], { ___String } ];

        If[ MemberQ[ styles, $$nestedCellStyle ],
            cell   = ConfirmMatch[ topParentCell @ cell, _CellObject, "ParentCell" ];
            styles = cellStyles @ cell;
        ];

        If[ cellInfo[ "ChatNotebookSettings", "ChatDelimiter" ], Throw @ currentChatSettings0[ cell, key ] ];

        nbo   = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "ParentNotebook" ];
        cells = ConfirmMatch[ Cells @ nbo, { __CellObject }, "ChatCells" ];

        (* There are apparently temporary mystery cells that get created that aren't in the root cell list which are
           then immediately removed. These inherit the style specified by `DefaultNewCellStyle`. In chat-driven
           notebooks, this is set to "ChatInput", which has a dynamic cell dingbat that needs to resolve
           `currentChatSettings`. In this case, we have special behavior here to prevent a failure. Since that new
           temporary cell doesn't get displayed anyway, we don't need to actually resolve the chat settings for it,
           so we just return a default value instead. Yes, this is an ugly hack.
        *)
        If[ And[ MemberQ[ styles, $$chatInputStyle ], (*It's a "ChatInput" cell*)
                 ! MemberQ[ cells, cell ], (*It's not in the list of cells*)
                 MatchQ[ CurrentValue[ nbo, DefaultNewCellStyle ], $$chatInputStyle ] (*Due to DefaultNewCellStyle*)
            ],
            Throw @ Lookup[ $defaultChatSettings, key, Inherited ]
        ];

        delimiter = ConfirmMatch[ getPrecedingDelimiter[ cell, nbo, cells ], _CellObject|_Missing, "Delimiter" ];

        values = AbsoluteCurrentValue[
            DeleteMissing @ { cell, delimiter },
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
(*getPrecedingDelimiter*)
getPrecedingDelimiter // beginDefinition;

getPrecedingDelimiter[ cell_CellObject ] :=
    getPrecedingDelimiter[ cell, parentNotebook @ cell ];

getPrecedingDelimiter[ cell_CellObject, nbo_NotebookObject ] :=
    getPrecedingDelimiter[ cell, nbo, Cells @ nbo ];

getPrecedingDelimiter[ cell_CellObject, nbo_, { before0___CellObject, cell_, ___ } ] :=
    Module[ { before, delimiterTest, pos },
        before = Reverse @ { before0 };
        delimiterTest = AbsoluteCurrentValue[ before, { TaggingRules, "ChatNotebookSettings", "ChatDelimiter" } ];
        pos = FirstPosition[ delimiterTest, True ];
        If[ MissingQ @ pos, Missing[ "NotAvailable" ], Extract[ before, pos ] ]
    ];

getPrecedingDelimiter // endDefinition;

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


openerView1[ args___ ] :=
    RawBoxes @ ReplaceAll[
        Replace[ ToBoxes @ OpenerView @ args, TagBox[ boxes_, ___ ] :> boxes ],
        InterpretationBox[ boxes_, _OpenerView, ___ ] :> boxes
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

replaceCellContext[ expr_ ] := ReplaceAll[
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
