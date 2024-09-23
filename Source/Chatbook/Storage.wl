(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Storage`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* TODO:
    * Save chat as a callback to GenerateChatTitleAsynchronous?
    * Save attachments separately by their hash ID (requires maintaining ref counts)
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$savedChatDataVersion     = 1;
$rootStorageName          = "SavedChats";
$defaultAppName           = "Default";
$defaultConversationTitle = "Untitled Chat";
$timestampPrefixLength    = 7; (* enough for about 1000 years *)
$$timestampPrefix         = Repeated[ LetterCharacter|DigitCharacter, { $timestampPrefixLength } ];

$$chatMetadata = KeyValuePattern @ {
    "ConversationTitle" -> _String,
    "ConversationUUID"  -> _String,
    "Date"              -> _Real,
    "Version"           -> _Integer
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ListSavedChats*)
ListSavedChats // beginDefinition;
ListSavedChats[ ] := catchMine @ ListSavedChats @ $defaultAppName;
ListSavedChats[ appName_String ] := catchMine @ LogChatTiming @ listSavedChats @ appName;
ListSavedChats // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*listSavedChats*)
listSavedChats // beginDefinition;

listSavedChats[ appName_String ] := Enclose[
    Catch @ Module[ { root, files },

        root = ConfirmBy[
            ChatbookFilesDirectory[ { $rootStorageName, appName }, "EnsureDirectory" -> False ],
            StringQ,
            "Root"
        ];

        (* most recent appear first *)
        files = Reverse @ FileNames[ "metadata.wxf", root, { 2 } ];
        If[ files === { }, Throw @ { } ];

        ConfirmMatch[ readChatMetaFile /@ files, { ___Association }, "Metadata" ]
    ],
    throwInternalFailure
];

listSavedChats // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*readChatMetaFile*)
readChatMetaFile // beginDefinition;
readChatMetaFile[ file_String ] := readChatMetaFile[ file, Quiet @ Developer`ReadWXFFile @ file ];
readChatMetaFile[ file_String, as: $$chatMetadata ] := <| as, "Path" -> File @ DirectoryName @ file |>;
readChatMetaFile[ file_String, _? FailureQ ] := Nothing; (* corrupt WXF file (should we auto-remove it?) *)
readChatMetaFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SaveChat*)
SaveChat // beginDefinition;

SaveChat[ messages: $$chatMessages, settings_Association ] :=
    catchMine @ LogChatTiming @ saveChat[ messages, settings ];

SaveChat // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*saveChat*)
saveChat // beginDefinition;

saveChat[ messages0_, settings_ ] := Enclose[
    Module[ { messages, appName, metadata, directory, attachments, smallSettings, as },

        messages = ConfirmMatch[ prepareMessagesForSaving[ messages0, settings ], $$chatMessages, "Messages" ];
        appName = ConfirmBy[ Lookup[ settings, "AppName", $defaultAppName ], StringQ, "AppName" ];
        metadata = ConfirmMatch[ getChatMetadata[ messages, settings ], $$chatMetadata, "Metadata" ];
        directory = ConfirmBy[ targetDirectory[ appName, metadata ], DirectoryQ, "Directory" ];
        attachments = ConfirmBy[ GetAttachments[ messages, All ], AssociationQ, "Attachments" ];
        smallSettings = ConfirmBy[ toSmallSettings @ settings, AssociationQ, "Settings" ];

        (* Save metadata file for quick loading of minimal information: *)
        ConfirmBy[
            saveChatFile[ "metadata", metadata, directory ],
            FileExistsQ,
            "SaveMetadata"
        ];

        (* Save messages and attachments (if any): *)
        ConfirmBy[
            saveChatFile[
                "data",
                <|
                    metadata,
                    "Attachments" -> attachments,
                    "Messages"    -> messages,
                    "Settings"    -> smallSettings
                |>,
                directory,
                PerformanceGoal -> "Size"
            ],
            FileExistsQ,
            "SaveMessages"
        ];

        as = ConfirmBy[
            <|
                "Path" -> Flatten @ File @ directory,
                KeyTake[ metadata, { "ConversationTitle", "ConversationUUID" } ],
                metadata
            |>,
            AssociationQ,
            "ResultData"
        ];

        ConfirmMatch[ cleanupStaleChats @ appName, { ___String }, "Cleanup" ];

        Success[ "Saved", as ]
    ],
    throwInternalFailure
];

saveChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*targetDirectory*)
targetDirectory // beginDefinition;

targetDirectory[ app_String, meta_Association ] := Enclose[
    Module[ { uuid, date, root, prefix },
        uuid = ConfirmBy[ meta[ "ConversationUUID" ], StringQ, "UUID" ];
        date = ConfirmMatch[ meta[ "Date" ], _Real, "Date" ];
        root = ConfirmBy[ $rootStorageName, StringQ, "RootName" ];
        prefix = ConfirmBy[ timestampPrefixString @ date, StringQ, "Prefix" ];
        ConfirmBy[ ChatbookFilesDirectory @ { root, app, prefix<>"_"<>uuid }, DirectoryQ, "Result" ]
    ],
    throwInternalFailure
];

targetDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*timestampPrefixString*)
timestampPrefixString // beginDefinition;
timestampPrefixString[ date_Real ] := IntegerString[ Round @ date, 36, $timestampPrefixLength ];
timestampPrefixString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cleanupStaleChats*)
cleanupStaleChats // beginDefinition;

cleanupStaleChats[ app_String ] := Enclose[
    Module[ { root, dirs, grouped, delete },
        root = ConfirmBy[
            ChatbookFilesDirectory[ { $rootStorageName, app }, "EnsureDirectory" -> False ],
            StringQ,
            "Root"
        ];

        dirs = ConfirmMatch[ Sort @ FileNames[ $$timestampPrefix ~~ "_" ~~ __, root ], { ___String }, "Directories" ];
        grouped = GatherBy[ dirs, StringDrop[ FileNameTake @ #, $timestampPrefixLength ] & ];
        delete = ConfirmMatch[ Flatten[ Most /@ grouped ], { ___String }, "Delete" ];

        ConfirmAssert[ Length @ delete < Length @ dirs, "LengthCheck" ];

        ConfirmMatch[ (DeleteDirectory[ #, DeleteContents -> True ]; #) & /@ delete, { ___String }, "Result" ]
    ],
    throwInternalFailure
];

cleanupStaleChats // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getAttachmentsForSaving*)
getAttachmentsForSaving // beginDefinition;
getAttachmentsForSaving[ messages_ ] := getAttachmentsForSaving[ messages, GetAttachments[ messages, All ] ];
getAttachmentsForSaving[ messages_, as_Association ] := If[ AllTrue[ as, SameAs @ <| |> ], None, as ];
getAttachmentsForSaving // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prepareMessagesForSaving*)
prepareMessagesForSaving // beginDefinition;

prepareMessagesForSaving[ messages_, settings_ ] :=
    revertMultimodalContent @
        If[ TrueQ @ settings[ "SaveSystemMessage" ],
            messages,
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
(*saveChatFile*)
saveChatFile // beginDefinition;

saveChatFile[ type_String, data_, directory_, opts: OptionsPattern[ ] ] := Enclose[
    Module[ { file },
        file = ConfirmBy[ FileNameJoin @ { directory, type <> ".wxf" }, StringQ, "File" ];
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
    Module[ { uuid, title, date, version },

        uuid    = ConfirmBy[ getChatUUID @ settings, StringQ, "ConversationUUID" ];
        title   = ConfirmBy[ getChatTitle[ messages, settings ], StringQ, "ConversationTitle" ];
        date    = ConfirmMatch[ AbsoluteTime[ TimeZone -> 0 ], _Real, "Date" ];
        version = ConfirmBy[ $savedChatDataVersion, IntegerQ, "Version" ];

        <|
            "ConversationUUID"  -> uuid,
            "ConversationTitle" -> title,
            "Date"              -> date,
            "Version"           -> version
        |>
    ],
    throwInternalFailure
];

getChatMetadata // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getChatUUID*)
getChatUUID // beginDefinition;
getChatUUID[ KeyValuePattern[ "ConversationUUID" -> id_String ] ] := id;
getChatUUID[ _Association ] := CreateUUID[ ];
getChatUUID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getChatTitle*)
getChatTitle // beginDefinition;
getChatTitle[ messages_, KeyValuePattern[ "ConversationTitle" -> title_String ] ] := title;
getChatTitle[ messages_, _Association ] := defaultConversationTitle @ messages;
getChatTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*defaultConversationTitle*)
defaultConversationTitle // beginDefinition;
defaultConversationTitle[ messages_ ] := $defaultConversationTitle; (* This could maybe use GenerateChatTitle here *)
defaultConversationTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
