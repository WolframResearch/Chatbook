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
(*evaluateFloatingChat*)
evaluateFloatingChat // beginDefinition;

evaluateFloatingChat[ nbo_NotebookObject, Dynamic[ input_Symbol ] ] := Enclose[
    Catch @ Module[ { text, uuid, cellObject },
        If[ ! validInputStringQ @ input, input = ""; Throw @ Null ];
        text = input;
        uuid = ConfirmBy[ CreateUUID[ ], StringQ, "UUID" ];
        input = "";
        SelectionMove[ nbo, After, Notebook, AutoScroll -> True ];
        NotebookWrite[ nbo, Cell[ text, "ChatInput", CellTags -> uuid ] ];
        cellObject = ConfirmMatch[ First[ Cells[ nbo, CellTags -> uuid ], $Failed ], _CellObject, "CellObject" ];
        CurrentValue[ cellObject, CellTags ] = { };
        ConfirmMatch[ ChatCellEvaluate[ cellObject, nbo ], _ChatObject|Null, "ChatCellEvaluate" ]
    ],
    throwInternalFailure
];

evaluateFloatingChat // endDefinition;

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
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

End[ ];
EndPackage[ ];
