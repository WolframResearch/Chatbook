(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatMessageToCell`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$chatOutputOptions = Sequence[ GeneratedCell -> True, CellAutoOverwrite -> True ];
$selectableOptions = Sequence[ Background -> None, Selectable -> True, Editable -> True ];

$$chatCellFormat = None | Automatic | "Default" | "Inline" | "Sidebar" | "Workspace";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatMessageToCell*)
ChatMessageToCell // beginDefinition;

ChatMessageToCell[ messages_ ] := ChatMessageToCell[ messages, "Default" ];

ChatMessageToCell[ message: $$chatMessage, format: $$chatCellFormat ] := catchMine @ Enclose[
    First @ ConfirmMatch[ chatMessagesToCells[ { message }, format ], { _Cell }, "Cell" ],
    throwInternalFailure
];

ChatMessageToCell[ messages: $$chatMessages, format: $$chatCellFormat ] := catchMine @ Enclose[
    ConfirmMatch[ chatMessagesToCells[ messages, format ], { ___Cell }, "Cells" ],
    throwInternalFailure
];

ChatMessageToCell // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatMessagesToCells*)
chatMessagesToCells // beginDefinition;

chatMessagesToCells[ messages_, None|Automatic ] :=
    chatMessagesToCells[ messages, "Default" ];

chatMessagesToCells[ messages_, format_ ] :=
    chatMessageToCell[ #, format ] & /@ revertMultimodalContent @ mergeToolCallMessages @ messages;

chatMessagesToCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatMessageToCell*)
chatMessageToCell // beginDefinition;

chatMessageToCell[ _? toolMessageQ     , _ ] := Nothing;
chatMessageToCell[ _? temporaryMessageQ, _ ] := Nothing;

chatMessageToCell[ message_Association, format_ ] :=
    chatMessageToCell[ message[ "Role" ], message[ "Content" ], format ];

chatMessageToCell[ role_String, content_, format_ ] := Enclose[
    Module[ { formatted },
        formatted = ConfirmMatch[ getFormattedTextData @ content, _TextData, "TextData" ];
        ConfirmMatch[ wrapCellContent[ formatted, role, format ], _Cell | Nothing, "Result" ]
    ],
    throwInternalFailure
];

chatMessageToCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeToolCallMessages*)
mergeToolCallMessages // beginDefinition;

mergeToolCallMessages[ messages_List ] := SequenceReplace[
    DeleteCases[ messages, _? temporaryMessageQ ],
    {
        {
            KeyValuePattern[ "ToolRequest"  -> True ],
            _,
            msg: KeyValuePattern[ "Role" -> "Assistant" ]
        } :> msg,

        {
            KeyValuePattern[ "Metadata" -> KeyValuePattern[ "ToolRequest"  -> True ] ],
            _,
            msg: KeyValuePattern[ "Role" -> "Assistant" ]
        } :> msg
    }
];

mergeToolCallMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*wrapCellContent*)
wrapCellContent // beginDefinition;

wrapCellContent[ text_, "Assistant", "Default" ] := Cell[ text, "ChatOutput", $chatOutputOptions ];
wrapCellContent[ text_, "System"   , "Default" ] := Cell[ text, "ChatSystemInput" ];
wrapCellContent[ text_, "User"     , "Default" ] := Cell[ text, "ChatInput" ];

wrapCellContent[ text_, "Assistant", "Sidebar" ] := 
ReplaceRepeated[
    Cell[
        BoxData @ TemplateBox[ { Cell[ text, $selectableOptions ] }, "NotebookAssistant`Sidebar`AssistantMessageBox" ],
        "NotebookAssistant`Sidebar`ChatOutput",
        $chatOutputOptions,
        CellTags -> "SidebarTopCell"
    ],
    {(* So far there's only one TemplateBox that is redefined in the Sidebar compared with ChatOuput within the notebook *)
        TemplateBox[a_, b : Alternatives[ "ChatCodeBlockTemplate" ], c___] :> RuleCondition[ TemplateBox[a, "NotebookAssistant`Sidebar`" <> b, c], True ]
    }
];
wrapCellContent[ text_, "System"   , "Sidebar" ] := Nothing; (* System inputs shouldn't appear in sidebar chat *)
wrapCellContent[ text_, "User"     , "Sidebar" ] :=
Cell[
    BoxData @ TemplateBox[ { Cell[ simplerTextData @ text, $selectableOptions ] }, "NotebookAssistant`Sidebar`UserMessageBox" ],
    "NotebookAssistant`Sidebar`ChatInput",
    CellTags -> "SidebarTopCell"
];

wrapCellContent[ text_, "Assistant", "Workspace" ] := workspaceOutput @ text;
wrapCellContent[ text_, "System"   , "Workspace" ] := Nothing; (* System inputs shouldn't appear in workspace chat *)
wrapCellContent[ text_, "User"     , "Workspace" ] := workspaceInput @ text;

wrapCellContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*workspaceInput*)
simplerTextData // beginDefinition;
simplerTextData[ TextData[ { text_String } ] ] := text;
simplerTextData[ TextData[ text_String ] ] := text;
simplerTextData[ text_TextData ] := text;
simplerTextData[ text_String ] := text;
simplerTextData[ text_ ] := Cell @ text;
simplerTextData // endDefinition;


workspaceInput // beginDefinition;

workspaceInput[ stuff_ ] := Cell[
    BoxData @ TemplateBox[ { Cell[ simplerTextData @ stuff, $selectableOptions ] }, "UserMessageBox" ],
    "ChatInput"
];

workspaceInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*workspaceOutput*)
workspaceOutput // beginDefinition;

workspaceOutput[ text_TextData ] :=
    wrapCellContent[
        BoxData @ TemplateBox[ { Cell[ text, $selectableOptions ] }, "AssistantMessageBox" ],
        "Assistant",
        "Default"
    ];

workspaceOutput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getFormattedTextData*)
getFormattedTextData // beginDefinition;
getFormattedTextData[ content_String ] := getFormattedTextData[ content, FormatChatOutput @ content ];
getFormattedTextData[ content_, (Cell|RawBoxes)[ boxes_ ] ] := getFormattedTextData[ content, boxes ];
getFormattedTextData[ content_, TextData[ text: $$textDataList ] ] := TextData @ text;
getFormattedTextData[ content_, string_String ] := TextData @ { string };
getFormattedTextData[ content_String, boxes_ ] := TextData @ { content };
getFormattedTextData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
