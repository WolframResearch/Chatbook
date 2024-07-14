(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`WorkspaceChat`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Evaluate Chat Inputs*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateWorkspaceChat*)
evaluateWorkspaceChat // beginDefinition;

evaluateWorkspaceChat[ nbo_NotebookObject, Dynamic[ input: _Symbol|_CurrentValue ] ] := Enclose[
    Catch @ Module[ { text, uuid, cell, cellObject },
        If[ ! validInputStringQ @ input, input = ""; Throw @ Null ];
        text = input;
        uuid = ConfirmBy[ CreateUUID[ ], StringQ, "UUID" ];
        cell = Cell[ BoxData @ TemplateBox[ { text }, "UserMessageBox" ], "ChatInput", CellTags -> uuid ];
        input = "";
        SelectionMove[ nbo, After, Notebook, AutoScroll -> True ];
        NotebookWrite[ nbo, cell ];
        cellObject = ConfirmMatch[ First[ Cells[ nbo, CellTags -> uuid ], $Failed ], _CellObject, "CellObject" ];
        CurrentValue[ cellObject, CellTags ] = { };
        ConfirmMatch[ ChatCellEvaluate[ cellObject, nbo ], _ChatObject|Null, "ChatCellEvaluate" ]
    ],
    throwInternalFailure
];

evaluateWorkspaceChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validInputStringQ*)
validInputStringQ // beginDefinition;
validInputStringQ[ input_String? StringQ ] := ! StringMatchQ[ input, WhitespaceCharacter... ];
validInputStringQ[ _ ] := False
validInputStringQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
