(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`Storage`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

(* TODO:
    * Need to also save/restore tool call results
    * Save chat as a callback to GenerateChatTitleAsynchronous?
    * Does this belong in the ChatModes context?
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$rootStorageName = "SavedChats";

$$chatMetadata = KeyValuePattern @ { "UUID" -> _String, "Title" -> _String, "Date" -> _Real };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SaveChat*)
SaveChat // beginDefinition;
SaveChat[ messages: $$chatMessages, settings_Association ] := catchMine @ saveChat[ messages, settings ];
SaveChat // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*saveChat*)
saveChat // beginDefinition;

saveChat[ messages0_, settings_ ] := Enclose[
    Module[ { messages, appName, directory, metadata, uuid, attachments, data, savedMeta, savedData },
        messages = ConfirmMatch[ prepareMessagesForSaving[ messages0, settings ], $$chatMessages, "Messages" ];
        appName = ConfirmBy[ settings[ "AppName" ], StringQ, "AppName" ];
        directory = ConfirmBy[ ChatbookFilesDirectory @ { $rootStorageName, appName }, DirectoryQ, "Directory" ];
        metadata = ConfirmMatch[ getChatMetadata[ messages, settings ], $$chatMetadata, "Metadata" ];
        uuid = ConfirmBy[ metadata[ "UUID" ], StringQ, "UUID" ];
        attachments = ConfirmMatch[ getAttachments @ messages, None | _Association, "Attachments" ];
        data = <| "UUID" -> uuid, "Messages" -> messages, "Attachments" -> attachments |>;
        savedMeta = ConfirmBy[ saveChatMetadata[ metadata, uuid, directory ], FileExistsQ, "SaveMetadata" ];
        savedData = ConfirmBy[ saveChatData[ data, uuid, directory ], FileExistsQ, "SaveData" ];
        <| "Metadata" -> metadata, "SavedMetadata" -> savedMeta, "SavedData" -> savedData |>
    ],
    throwInternalFailure
];

saveChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareMessagesForSaving*)
prepareMessagesForSaving // beginDefinition;

prepareMessagesForSaving[ messages_, settings_ ] :=
    If[ TrueQ @ settings[ "SaveSystemMessage" ],
        dropTemporaryMessages @ messages,
        dropSystemMessage @ dropTemporaryMessages @ messages
    ];

prepareMessagesForSaving // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*dropTemporaryMessages*)
dropTemporaryMessages // beginDefinition;
dropTemporaryMessages[ messages_List ] := DeleteCases[ messages, KeyValuePattern[ "Temporary" -> True ] ];
dropTemporaryMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*dropSystemMessage*)
dropSystemMessage // beginDefinition;
dropSystemMessage[ { KeyValuePattern[ "Role" -> "System" ], messages___ } ] := dropSystemMessage @ { messages };
dropSystemMessage[ messages_List ] := messages;
dropSystemMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*saveChatMetadata*)
saveChatMetadata // beginDefinition;

saveChatMetadata[ metadata_Association, uuid_, directory_ ] :=
    saveChatFile[ metadata, "metadata", uuid, directory ];

saveChatMetadata // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*saveChatData*)
saveChatData // beginDefinition;

saveChatData[ data_Association, uuid_, directory_ ] :=
    saveChatFile[ data, "data", uuid, directory, PerformanceGoal -> "Size" ];

saveChatData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*saveChatFile*)
saveChatFile // beginDefinition;

saveChatFile[ data_, type_String, uuid_String, directory_, opts: OptionsPattern[ ] ] := Enclose[
    Module[ { file },
        file = ConfirmBy[ FileNameJoin @ { directory, uuid <> "_" <> type <> ".wxf" }, StringQ, "File" ];
        ConfirmBy[ Developer`WriteWXFFile[ file, data, opts ], FileExistsQ, "Export" ]
    ],
    throwInternalFailure
];

saveChatFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getChatMetadata*)
getChatMetadata // beginDefinition;

getChatMetadata[ messages_, settings_Association ] := Enclose[
    Module[ { uuid, title, date },
        uuid = ConfirmBy[ getChatUUID @ settings, StringQ, "UUID" ];
        title = ConfirmBy[ getChatTitle[ messages, settings ], StringQ, "Title" ];
        date = ConfirmMatch[ AbsoluteTime[ TimeZone -> 0 ], _Real, "Date" ];
        <| "UUID" -> uuid, "Title" -> title, "Date" -> date |>
    ],
    throwInternalFailure
];

getChatMetadata // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getChatUUID*)
getChatUUID // beginDefinition;
getChatUUID[ KeyValuePattern[ "ChatUUID" -> id_String ] ] := id;
getChatUUID[ _Association ] := CreateUUID[ ];
getChatUUID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getChatTitle*)
getChatTitle // beginDefinition;
getChatTitle[ messages_, KeyValuePattern[ "ChatTitle" -> title_String ] ] := title;
getChatTitle[ messages_, _Association ] := GenerateChatTitle @ messages;
getChatTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getAttachments*)
getAttachments // beginDefinition;

getAttachments[ messages_ ] := Enclose[
    Catch @ Module[ { allKeys, usedKeys },
        allKeys = ConfirmMatch[ Keys @ $attachments, { ___String }, "Keys" ];
        If[ allKeys === { }, Throw @ None ];
        usedKeys = Union @ Flatten @ Cases[ messages, s_String :> StringCases[ s, allKeys ], 4 ];
        If[ usedKeys === { }, Throw @ None ];
        KeyTake[ $attachments, usedKeys ]
    ],
    throwInternalFailure
];

getAttachments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
