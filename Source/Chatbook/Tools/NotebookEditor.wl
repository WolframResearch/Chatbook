(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$notebookEditorEnabled := TrueQ @ $WorkspaceChat || TrueQ @ $InlineChat;

$cancelledNotebookEdit = Missing[ "Edit was cancelled by the user" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Metadata*)

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
Do not surround code you write with triple backticks and don't include cell labels. \
The target 'selected' refers to the entire cell or cells.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookEdit*)
notebookEdit // beginDefinition;

notebookEdit[ as_Association ] := notebookEdit[ as[ "action" ], as[ "target" ], as[ "content" ] ];

notebookEdit[ "delete" , target_, content_ ] := notebookEditDelete[ target, content ];
notebookEdit[ "write"  , target_, content_ ] := notebookEditWrite[ target, content ];
notebookEdit[ "append" , target_, content_ ] := notebookEditAppend[ target, content ];
notebookEdit[ "prepend", target_, content_ ] := notebookEditPrepend[ target, content ];

notebookEdit // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookEditDelete*)
notebookEditDelete // beginDefinition;

notebookEditDelete[ target_, _ ] := notebookEditDelete @ notebookEditTarget @ target;

notebookEditDelete[ nbo_NotebookObject ] :=
    If[ TrueQ @ ChoiceDialog[ Row @ { "Delete current selection in ", nbo, "?" } ],
        NotebookDelete @ nbo;
        Abort[ ],
        $cancelledNotebookEdit
    ];

notebookEditDelete[ cell_CellObject ] :=
    If[ TrueQ @ ChoiceDialog[ Row @ { "Delete cell ", cell, "?" } ],
        NotebookDelete @ cell;
        Abort[ ],
        $cancelledNotebookEdit
    ];

notebookEditDelete[ cells: { __CellObject } ] :=
    If[ TrueQ @ ChoiceDialog[ Row @ { "Delete the following cells? ", cells } ],
        NotebookDelete @ cells;
        Abort[ ],
        $cancelledNotebookEdit
    ];

notebookEditDelete[ _Missing ] :=
    Missing[ "TargetNotFound" ];

notebookEditDelete // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookEditWrite*)
notebookEditWrite // beginDefinition;
notebookEditWrite[ target_, content_ ] := notebookEditWrite0[ notebookEditTarget @ target, content ];
notebookEditWrite // endDefinition;

notebookEditWrite0 // beginDefinition;

notebookEditWrite0[ nbo_NotebookObject, content_String ] :=
    If[ TrueQ @ ChoiceDialog[
            Column @ { Row @ { "Overwrite the current selection in ", nbo, " with the following?" }, content }
        ],
        NotebookWrite[ nbo, content ];
        Abort[ ],
        $cancelledNotebookEdit
    ];

notebookEditWrite0[ cell_CellObject, content_String ] :=
    If[ TrueQ @ ChoiceDialog[ Column @ { Row @ { "Overwrite ", cell, " with the following?" }, content } ],
        NotebookWrite[ cell, content ];
        Abort[ ],
        $cancelledNotebookEdit
    ];

notebookEditWrite0[ { first_CellObject, rest___CellObject }, content_String ] :=
    If[ TrueQ @ ChoiceDialog[ Column @ { Row @ { "Overwrite the following cells? ", { first, rest } }, content } ],
        NotebookDelete @ { rest };
        SelectionMove[ first, All, CellContents ];
        NotebookWrite[ parentNotebook @ first, content ];
        Abort[ ],
        $cancelledNotebookEdit
    ];

notebookEditWrite0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookEditAppend*)
notebookEditAppend // beginDefinition;
(* TODO *)
notebookEditAppend // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookEditPrepend*)
notebookEditPrepend // beginDefinition;
(* TODO *)
notebookEditPrepend // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookEditTarget*)
notebookEditTarget // beginDefinition;
notebookEditTarget[ "selected" ] /; $WorkspaceChat := getUserNotebook[ ];
notebookEditTarget[ "selected" ] /; $InlineChat := ensureValidWriteTarget @ $inlineChatState[ "ParentCell" ];
notebookEditTarget[ "selected" ] /; True := $evaluationNotebook;
notebookEditTarget[ target_String ] := notebookEditTarget @ StringSplit[ target, "," ];
notebookEditTarget[ { target_String } ] := cellReference @ target;
notebookEditTarget[ targets: { ___String } ] := notebookEditTarget[ cellReference /@ targets ];
notebookEditTarget[ targets: { __CellObject } ] := targets;
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
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
