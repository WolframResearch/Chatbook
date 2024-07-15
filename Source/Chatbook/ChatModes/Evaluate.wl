(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`Evaluate`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Evaluate Alternate Chat Inputs*)

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
(* ::Subsection::Closed:: *)
(*evaluateInlineChat*)
evaluateInlineChat // beginDefinition;

evaluateInlineChat[ cell_CellObject, root_CellObject, Dynamic[ input_ ], Dynamic[ messageCells_ ] ] := Enclose[
    Catch @ Module[ { text },
        If[ ! validInputStringQ @ input, input = ""; Throw @ Null ];
        text = input;
        input = "";

        ConfirmMatch[
            AppendTo[ messageCells, Cell[ text, "ChatInput", Background -> White ] ],
            { __Cell },
            "MessageCells"
        ];

        Block[
            {
                $InlineChat = True,
                $inlineChatState = <|
                    "CurrentInput"   -> text,
                    "InlineChatCell" -> cell,
                    "MessageCells"   -> Dynamic @ messageCells
                |>
            },
            ConfirmMatch[ ChatCellEvaluate @ root, _ChatObject|Null, "ChatCellEvaluate" ]
        ]
    ],
    throwInternalFailure
];

evaluateInlineChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Overrides*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createNewInlineOutput*)
createNewInlineOutput // beginDefinition;
createNewInlineOutput[ settings_, target_, cell_ ] := createNewInlineOutput0[ settings, cell, $inlineChatState ];
createNewInlineOutput // endDefinition;


createNewInlineOutput0 // beginDefinition;

createNewInlineOutput0[
    settings_,
    cell_Cell,
    KeyValuePattern @ {
        "InlineChatCell" -> chatCell_,
        "MessageCells"   -> Dynamic[ messageCells_ ]
    }
] := Enclose[
    ConfirmMatch[ AppendTo[ messageCells, cell ], { __Cell }, "MessageCells" ];
    chatCell,
    throwInternalFailure
];

createNewInlineOutput0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeInlineChatOutputCell*)
writeInlineChatOutputCell // beginDefinition;
writeInlineChatOutputCell[ cell_, new_Cell, settings_ ] := Null; (* FIXME: Do the thing *)
writeInlineChatOutputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Misc Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
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
