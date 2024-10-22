(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`Evaluate`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$$inlineChatInput   = Cell[ __, "ChatInput" , ___ ];
$$inlineChatOutput  = Cell[ __, "ChatOutput", ___ ];
$$inlineMessage     = $$inlineChatInput|$$inlineChatOutput;
$$inlineMessages    = { $$inlineMessage.. };
$$inlineMessagesIn  = { $$inlineMessage..., $$inlineChatInput  };
$$inlineMessagesOut = { $$inlineMessage..., $$inlineChatOutput };

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

        cell = Cell[
            BoxData @ TemplateBox[
                { Cell[ text, Background -> None, Selectable -> True, Editable -> True ] },
                "UserMessageBox"
            ],
            "ChatInput",
            CellTags -> uuid
        ];

        input = "";
        SelectionMove[ nbo, After, Notebook, AutoScroll -> True ];
        NotebookWrite[ nbo, cell ];
        moveChatInputToBottom @ nbo;
        cellObject = ConfirmMatch[ First[ Cells[ nbo, CellTags -> uuid ], $Failed ], _CellObject, "CellObject" ];
        CurrentValue[ cellObject, CellTags ] = { };
        ConfirmMatch[ ChatCellEvaluate[ cellObject, nbo ], _ChatObject|Null, "ChatCellEvaluate" ]
    ],
    throwInternalFailure
];

evaluateWorkspaceChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*moveChatInputToBottom*)
moveChatInputToBottom // beginDefinition;

moveChatInputToBottom[ nbo_NotebookObject ] :=
    Catch @ Module[ { attached },
        attached = Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField", CellTags -> "Top" ];
        If[ attached === { }, Throw @ Null ];
        NotebookDelete @ attached;
        ChatbookAction[ "AttachWorkspaceChatInput", nbo, Bottom ]
    ];

moveChatInputToBottom // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateInlineChat*)
evaluateInlineChat // beginDefinition;

evaluateInlineChat[
    cell_CellObject,
    root_CellObject,
    selectionInfo_,
    Dynamic[ input_ ],
    Dynamic[ messageCells_ ]
] := Enclose[
    Catch @ Module[ { text, nbo, result },

        If[ ! validInputStringQ @ input, input = ""; Throw @ Null ];
        text = input;
        input = "";

        ConfirmMatch[ AppendTo[ messageCells, formatInlineChatInput @ text ], { __Cell }, "MessageCells" ];

        nbo = ConfirmMatch[ parentNotebook @ root, _NotebookObject, "ParentNotebook" ];

        Block[
            {
                $InlineChat = True,
                $inlineChatState = <|
                    "CurrentInput"   -> text,
                    "ParentCell"     -> root,
                    "ParentNotebook" -> nbo,
                    "InlineChatCell" -> cell,
                    "SelectionInfo"  -> selectionInfo,
                    "MessageCells"   -> Dynamic @ messageCells
                |>
            },
            result = ConfirmMatch[
                Internal`InheritedBlock[ { currentChatSettings },
                    currentChatSettings[ root ] := currentChatSettings[ cell ];
                    ChatCellEvaluate @ root
                ],
                _ChatObject|Null,
                "ChatCellEvaluate"
            ]
        ];

        SessionSubmit @ moveToInlineChatInputField[ ];

        result
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
    If[ Length @ messageCells > 2, scrollInlineChat[ ] ];
    ConfirmMatch[ AppendTo[ messageCells, cell ], { __Cell }, "MessageCells" ];
    chatCell,
    throwInternalFailure
];

createNewInlineOutput0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeInlineChatOutputCell*)
writeInlineChatOutputCell // beginDefinition;
writeInlineChatOutputCell[ cell_, new_Cell, settings_ ] := replaceLastInlineMessage[ settings, new ];
writeInlineChatOutputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*replaceLastInlineMessage*)
replaceLastInlineMessage // beginDefinition;

replaceLastInlineMessage[ settings_, new_ ] :=
    replaceLastInlineMessage[ settings, new, $inlineChatState[ "MessageCells" ] ];

replaceLastInlineMessage[ settings_, cell_, Dynamic[ messageList_ ] ] := Enclose[
    Module[ { messages, keep, new },
        messages = ConfirmMatch[ messageList, $$inlineMessagesOut, "CurrentMessages" ];
        keep = Most @ messages;
        new = ConfirmMatch[ formatStaticInlineOutput[ settings, cell ], $$inlineChatOutput, "NewCell" ];
        messageList = ConfirmMatch[ Append[ keep, new ], $$inlineMessagesOut, "MessageList" ];
        messageList
    ],
    throwInternalFailure
];

replaceLastInlineMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatStaticInlineOutput*)
formatStaticInlineOutput // beginDefinition;

formatStaticInlineOutput[ settings_, Cell[ text_, "ChatOutput", opts___ ] ] :=
    addInlineChatTaggingRules @ Cell[
        TextData @ {
            Cell[
                BoxData @ assistantMessageBox @ Cell[ inlineTemplateBoxes @ text, Background -> None ],
                Background -> None
            ]
        },
        "ChatOutput",
        CellFrame          -> 0,
        Editable           -> True,
        Initialization     -> None,
        PrivateCellOptions -> { "ContentsOpacity" -> 1 },
        Selectable         -> True,
        opts
    ];

formatStaticInlineOutput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addInlineChatTaggingRules*)
addInlineChatTaggingRules // beginDefinition;

addInlineChatTaggingRules[ Cell[ a__, TaggingRules -> tags_, b___ ] ] :=
    Cell[ a, TaggingRules -> addInlineChatTaggingRules0 @ tags, b ];

addInlineChatTaggingRules[ Cell[ a___ ] ] :=
    Cell[ a, TaggingRules -> addInlineChatTaggingRules0 @ <| |> ];

addInlineChatTaggingRules // endDefinition;


addInlineChatTaggingRules0 // beginDefinition;

addInlineChatTaggingRules0[ tags: KeyValuePattern[ "ChatNotebookSettings" -> as: KeyValuePattern @ { } ] ] :=
    <| tags, "ChatNotebookSettings" -> <| as, $inlineChatTaggingRules |> |>;

addInlineChatTaggingRules0[ tags: KeyValuePattern @ { } ] :=
    <| tags, "ChatNotebookSettings" -> $inlineChatTaggingRules |>;

addInlineChatTaggingRules0 // endDefinition;


$inlineChatTaggingRules := <| "InlineChat" -> True, "InlineChatRootCell" -> $inlineChatState[ "ParentCell" ] |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatInlineChatInput*)
formatInlineChatInput // beginDefinition;

formatInlineChatInput[ text_String ] :=
    Block[ { $InlineChat = True },
        Cell[
            BoxData @ userMessageBox @ Cell @ TextData @ text,
            "ChatInput",
            CellFrame          -> 0,
            PrivateCellOptions -> { "ContentsOpacity" -> 1 }
        ]
    ];

formatInlineChatInput // endDefinition;

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
