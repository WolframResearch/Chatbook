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

$$chatCellFormat = None | Automatic | "Default" | "Inline" | "Workspace";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatMessageToCell*)
ChatMessageToCell // beginDefinition;

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
chatMessagesToCells[ messages_, None|Automatic ] := chatMessagesToCells[ messages, "Default" ];
chatMessagesToCells[ messages_, format_ ] := chatMessageToCell[ #, format ] & /@ revertMultimodalContent @ messages;
chatMessagesToCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatMessageToCell*)
chatMessageToCell // beginDefinition;

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
(*wrapCellContent*)
wrapCellContent // beginDefinition;

wrapCellContent[ text_, "Assistant", "Default" ] := Cell[ text, "ChatOutput", $chatOutputOptions ];
wrapCellContent[ text_, "System"   , "Default" ] := Cell[ text, "ChatSystemInput" ];
wrapCellContent[ text_, "User"     , "Default" ] := Cell[ text, "ChatInput" ];

wrapCellContent[ text_, "Assistant", "Workspace" ] := workspaceOutput @ text;
wrapCellContent[ text_, "System"   , "Workspace" ] := Nothing; (* System inputs shouldn't appear in workspace chat *)
wrapCellContent[ text_, "User"     , "Workspace" ] := workspaceInput @ text;

wrapCellContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*workspaceInput*)
workspaceInput // beginDefinition;
workspaceInput[ TextData[ { text_String } ] ] := workspaceInput @ text;
workspaceInput[ TextData[ text_String ] ] := workspaceInput @ text;
workspaceInput[ text_String ] := workspaceInput0 @ text;
workspaceInput[ text_ ] := workspaceInput0 @ Cell @ text;
workspaceInput // endDefinition;


workspaceInput0 // beginDefinition;

workspaceInput0[ stuff_ ] := Cell[
    BoxData @ TemplateBox[ { Cell[ stuff, $selectableOptions ] }, "UserMessageBox" ],
    "ChatInput"
];

workspaceInput0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*workspaceOutput*)
workspaceOutput // beginDefinition;

workspaceOutput[ text_TextData ] :=
    wrapCellContent[
        TextData @ Cell[
            BoxData @ TemplateBox[ { Cell[ text, $selectableOptions ] }, "AssistantMessageBox" ],
            Background -> None
        ],
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
