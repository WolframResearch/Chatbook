(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
(* $notebookEditorEnabled := TrueQ @ $WorkspaceChat || TrueQ @ $InlineChat; *)
$notebookEditorEnabled = False;

$cancelledNotebookEdit = Failure[ "Cancelled", <| "Message" -> "Proposed change was rejected by the user" |> ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Icon*)
$nbEditIcon = RawBoxes[
    DynamicBox @ FEPrivate`FrontEndResource[ "FEBitmaps", "NotebookIcon" ][
        GrayLevel[ 0.651 ],
        RGBColor[ 0.86667, 0.066667, 0. ]
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Description*)
$nbEditDescription = "\
Modify notebook cells. \
Use this if the user asks you to write code for them, fix issues, etc. \
The user will be presented with a diff view of your changes and can accept or reject them, \
so you do not need to ask for permission. \
If the user asks you to fix code, edit only the relevant input cells and let them reevaluate as needed. \
Do not include cell labels like `In[...]:=` in the content you write. These will be automatically generated for you. \
Do not try to write output cells. Instead, just write inputs so that the user can reevaluate them. \
Write content as Markdown and the tool will automatically convert it to the right format.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Spec*)
$defaultChatTools0[ "NotebookEditor" ] = <|
    toolDefaultData[ "NotebookEditor" ],
    "ShortName"          -> "nb_edit",
    "Icon"               -> $nbEditIcon,
    "Description"        -> $nbEditDescription,
    "Enabled"            :> $notebookEditorEnabled,
    "Function"           -> notebookEdit,
    "FormattingFunction" -> toolAutoFormatter,
    "Hidden"             -> True, (* TODO: hide this from UI *)
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "action" -> <|
            "Interpreter" -> "String",
            "Help"        -> "Action to execute. Valid values are 'delete', 'write', 'append', 'prepend'.",
            "Required"    -> True
        |>,
        "target" -> <|
            "Interpreter" -> "String",
            "Help"        -> "Target of action. Can be a cell ID or 'selected' (default).",
            "Required"    -> False
        |>,
        "content" -> <|
            "Interpreter" -> "String",
            "Help"        -> "Content to write, append, or prepend.",
            "Required"    -> False
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookEdit*)
notebookEdit // beginDefinition;

notebookEdit[ as_Association ] := Catch[
    notebookEdit[
        as[ "action" ],
        notebookEditTarget @ as[ "target" ],
        notebookEditContent @ as[ "content" ]
    ],
    $notebookEditTag
];

notebookEdit[ "delete" , target_, content_ ] := notebookEditDelete[ target, content ];
notebookEdit[ "write"  , target_, content_ ] := notebookEditWrite[ target, content ];
notebookEdit[ "append" , target_, content_ ] := notebookEditAppend[ target, content ];
notebookEdit[ "prepend", target_, content_ ] := notebookEditPrepend[ target, content ];

notebookEdit // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookEditDelete*)
notebookEditDelete // beginDefinition;

notebookEditDelete[ target_, _ ] :=
    notebookEditDelete @ target;

notebookEditDelete[ nbo_NotebookObject ] :=
    If[ TrueQ @ ChoiceDialog[ Row @ { "Delete current selection in ", nbo, "?" } ],
        NotebookDelete @ nbo;
        Success[ "NotebookDelete", <| "Content" -> "Selection" |> ],
        $cancelledNotebookEdit
    ];

notebookEditDelete[ cell_CellObject ] :=
    If[ TrueQ @ ChoiceDialog[ Row @ { "Delete cell ", cell, "?" } ],
        NotebookDelete @ cell;
        Success[ "NotebookDelete", <| "Content" -> cell |> ],
        $cancelledNotebookEdit
    ];

notebookEditDelete[ cells: { __CellObject } ] :=
    If[ TrueQ @ ChoiceDialog[ Row @ { "Delete the following cells? ", cells } ],
        NotebookDelete @ cells;
        Success[ "NotebookDelete", <| "Content" -> cells |> ],
        $cancelledNotebookEdit
    ];

notebookEditDelete[ _Missing ] :=
    Missing[ "TargetNotFound" ];

notebookEditDelete // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookEditWrite*)
notebookEditWrite // beginDefinition;
notebookEditWrite[ target_, content_ ] := notebookEditWrite0[ target, content ];
notebookEditWrite // endDefinition;

notebookEditWrite0 // beginDefinition;

notebookEditWrite0[ nbo_NotebookObject, content: { __Cell } ] :=
    If[ TrueQ @ ChoiceDialog[
            Column @ { Row @ { "Overwrite the current selection in ", nbo, " with the following?" }, content }
        ],
        NotebookWrite[ nbo, content ];
        Success[ "NotebookWrite", <| "Content" -> content |> ],
        $cancelledNotebookEdit
    ];

notebookEditWrite0[ cell_CellObject, content: { __Cell } ] :=
    If[ TrueQ @ ChoiceDialog[ Column @ { Row @ { "Overwrite ", cell, " with the following?" }, content } ],
        NotebookWrite[ cell, content ];
        Success[ "NotebookWrite", <| "Content" -> content |> ],
        $cancelledNotebookEdit
    ];

notebookEditWrite0[ { first_CellObject, rest___CellObject }, content: { __Cell } ] :=
    If[ TrueQ @ ChoiceDialog[ Column @ { Row @ { "Overwrite the following cells? ", { first, rest } }, content } ],
        NotebookDelete @ { rest };
        SelectionMove[ first, All, CellContents ];
        NotebookWrite[ parentNotebook @ first, content ];
        Success[ "NotebookWrite", <| "Content" -> content |> ],
        $cancelledNotebookEdit
    ];

notebookEditWrite0[ _Missing, _ ] :=
    Missing[ "TargetNotFound" ];

notebookEditWrite0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookEditAppend*)
notebookEditAppend // beginDefinition;
notebookEditAppend[ target_, content_ ] := notebookEditAppend0[ target, content ];
notebookEditAppend // endDefinition;

notebookEditAppend0 // beginDefinition;

notebookEditAppend0[ nbo_NotebookObject, content: { __Cell } ] := (
    SelectionMove[ nbo, After, Cell ];
    NotebookWrite[ nbo, content, After ];
    Success[ "NotebookWrite", <| "Content" -> content |> ]
);

notebookEditAppend0[ cell_CellObject, content: { __Cell } ] := (
    SelectionMove[ cell, After, Cell ];
    NotebookWrite[ parentNotebook @ cell, content, After ];
    Success[ "NotebookWrite", <| "Content" -> content |> ]
);

notebookEditAppend0[ { ___, last_CellObject }, content: { __Cell } ] :=
    notebookEditAppend0[ last, content ];

notebookEditAppend0[ _Missing, _ ] :=
    Missing[ "TargetNotFound" ];

notebookEditAppend0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookEditPrepend*)
notebookEditPrepend // beginDefinition;
notebookEditPrepend[ target_, content_ ] := notebookEditPrepend0[ target, content ];
notebookEditPrepend // endDefinition;

notebookEditPrepend0 // beginDefinition;

notebookEditPrepend0[ nbo_NotebookObject, content: { __Cell } ] := (
    SelectionMove[ nbo, Before, Cell ];
    NotebookWrite[ nbo, content, Before ];
    Success[ "NotebookWrite", <| "Content" -> content |> ]
);

notebookEditPrepend0[ cell_CellObject, content: { __Cell } ] := (
    SelectionMove[ cell, Before, Cell ];
    NotebookWrite[ parentNotebook @ cell, content, Before ];
    Success[ "NotebookWrite", <| "Content" -> content |> ]
);

notebookEditPrepend0[ { first_CellObject, ___ }, content: { __Cell } ] :=
    notebookEditPrepend0[ first, content ];

notebookEditPrepend0[ _Missing, _ ] :=
    Missing[ "TargetNotFound" ];

notebookEditPrepend0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookEditTarget*)
notebookEditTarget // beginDefinition;
notebookEditTarget[ "selected" ] /; $WorkspaceChat := getUserNotebook[ ];
notebookEditTarget[ "selected" ] /; $InlineChat := ensureValidWriteTarget @ $inlineChatState[ "ParentCell" ];
notebookEditTarget[ "selected" ] /; True := $evaluationNotebook;
notebookEditTarget[ _Missing | "" ] := notebookEditTarget[ "selected" ];
notebookEditTarget[ target_String ] := notebookEditTarget @ StringSplit[ target, "," ];
notebookEditTarget[ { target_String } ] := cellReference @ target;
notebookEditTarget[ targets: { ___String } ] := notebookEditTarget[ cellReference /@ targets ];
notebookEditTarget[ targets: { __CellObject } ] := targets;
notebookEditTarget[ s_String ] /; StringContainsQ[ s, "selected"|"selection" ] := notebookEditTarget[ "selected" ];
notebookEditTarget[ _ ] := Missing[ "TargetNotFound" ];
notebookEditTarget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ensureValidWriteTarget*)
ensureValidWriteTarget // beginDefinition;

ensureValidWriteTarget[ cell_CellObject ] :=
    With[ { valid = ensureValidWriteTarget[ cell, CurrentValue[ cell, GeneratedCell ] ] },
        If[ MatchQ[ valid, _CellObject ],
            valid,
            cell
        ]
    ];

ensureValidWriteTarget[ cell_CellObject, False ] :=
    cell;

ensureValidWriteTarget[ cell_, True ] :=
    With[ { prev = previousCell @ cell },
        If[ MatchQ[ prev, Except[ cell, _CellObject ] ],
            ensureValidWriteTarget @ prev,
            $Failed
        ]
    ];

ensureValidWriteTarget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookEditContent*)
notebookEditContent // beginDefinition;

notebookEditContent[ content_String ] := Enclose[
    Module[ { cells },
        cells = ConfirmMatch[ toCellExpressions @ content, { ___Cell } | _String, "Cells" ];
        cells
    ],
    throwInternalFailure
];

notebookEditContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toCellExpressions*)
toCellExpressions // beginDefinition;

toCellExpressions[ "" ] :=
    Missing[ "NoContent" ];

toCellExpressions[ content_String ] /; StringContainsQ[ content, "Cell["~~___~~"]" ] && SyntaxQ @ content :=
    toCellExpressions[ content, Quiet @ ToExpression[ content, InputForm, HoldComplete ] ];

toCellExpressions[ content_String ] :=
    toCellExpressions[ content, FormatChatOutput @ content ];

toCellExpressions[ content_, RawBoxes[ boxes_ ] ] :=
    toCellExpressions[ content, boxes ];

toCellExpressions[ content_, boxes_Cell ] :=
    With[ { exploded = catchAlways @ ExplodeCell @ boxes },
        If[ MatchQ[ exploded, { ___Cell } ],
            exploded,
            content
        ]
    ];

toCellExpressions[ content_, HoldComplete[ cell_Cell ] ] :=
    { cell };

toCellExpressions[ content_, HoldComplete[ cells: { ___Cell } ] ] :=
    cells;

toCellExpressions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
