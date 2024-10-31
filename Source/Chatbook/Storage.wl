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
$maxTitleGenerationMessages = 10; (* 5 input/output pairs *)
$savedChatDataVersion       = 2;
$rootStorageName            = "SavedChats";
$defaultConversationTitle   = "Untitled Chat";
$maxChatItems               = Infinity;
$timestampPrefixLength      = 7; (* good for about 1000 years *)
$$timestampPrefix           = Repeated[ LetterCharacter|DigitCharacter, { $timestampPrefixLength } ];

$metaKeys = { "AppName", "ConversationTitle", "ConversationUUID", "Date", "Version" };

(* TODO: these patterns might need to move to Common.wl *)
$$conversationData = KeyValuePattern @ {
    "AppName"           -> _String,
    "ConversationTitle" -> _String,
    "ConversationUUID"  -> _String,
    "Date"              -> _Real,
    "Version"           -> $savedChatDataVersion
};

$$conversationFullData = KeyValuePattern @ {
    "AppName"           -> _String,
    "ConversationTitle" -> _String,
    "ConversationUUID"  -> _String,
    "Date"              -> _Real,
    "Messages"          -> _List,
    "Version"           -> $savedChatDataVersion
};

$$legacyData = KeyValuePattern[ "Version" -> _? (LessThan @ $savedChatDataVersion ) ];

$$appSpec = $$string | All | _NotebookObject;

$generatedTitleCache = <| |>;

$savingNotebook = None;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ListSavedChats*)
ListSavedChats // beginDefinition;
ListSavedChats // Options = { MaxItems -> $maxChatItems };

ListSavedChats[ opts: OptionsPattern[ ] ] :=
    catchMine @ ListSavedChats[ All, opts ];

ListSavedChats[ appSpec: $$appSpec, opts: OptionsPattern[ ] ] :=
    catchMine @ LogChatTiming @ listSavedChats[ appSpec, OptionValue[ MaxItems ] ];

ListSavedChats // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*listSavedChats*)
listSavedChats // beginDefinition;

listSavedChats[ appSpec: $$appSpec, maxItems_? Positive ] := Enclose[
    Catch @ Module[ { appName, dirName, root, depth, files, sorted, take },

        appName = ConfirmMatch[ determineAppName @ appSpec, $$string | All, "Name" ];
        dirName = If[ StringQ @ appName, appName, Nothing ];

        root = ConfirmBy[
            ChatbookFilesDirectory[ { $rootStorageName, dirName }, "EnsureDirectory" -> False ],
            StringQ,
            "Root"
        ];

        depth = If[ StringQ @ appName, 2, 3 ];

        files = FileNames[ "metadata.wxf", root, { depth } ];
        If[ files === { }, Throw @ { } ];

        (* show most recent first *)
        sorted = If[ StringQ @ appName, Reverse @ files, ReverseSortBy[ files, FileNameTake[ #, { -2 } ] & ] ];
        take = ConfirmMatch[ Take[ sorted, UpTo @ Floor @ maxItems ], { ___String }, "Take" ];

        ConfirmMatch[ readChatMetaFile /@ take, { ___Association }, "Metadata" ]
    ],
    throwInternalFailure
];

listSavedChats // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*determineAppName*)
determineAppName // beginDefinition;
determineAppName[ All ] := All;
determineAppName[ name_String ] := name;
determineAppName[ nbo_NotebookObject ] := notebookAppName @ nbo;
determineAppName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*notebookAppName*)
notebookAppName // beginDefinition;
notebookAppName[ nbo_NotebookObject ] := notebookAppName[ nbo, CurrentChatSettings[ nbo, "AppName" ] ];
notebookAppName[ nbo_, name_String ] := name;
notebookAppName[ nbo_, $$unspecified ] := $defaultAppName;
notebookAppName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*readChatMetaFile*)
readChatMetaFile // beginDefinition;
readChatMetaFile[ file_String ] := readChatMetaFile[ file, Quiet @ Developer`ReadWXFFile @ file ];
readChatMetaFile[ file_String, as_Association ] := checkChatDataVersion @ as;
readChatMetaFile[ file_String, _? FailureQ ] := Nothing; (* corrupt WXF file (should we auto-remove it?) *)
readChatMetaFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*LoadChat*)
(* TODO: LoadChat[NotebookObject[...], spec]*)
LoadChat // beginDefinition;
LoadChat[ as: KeyValuePattern[ "ConversationUUID" -> _String ] ] := catchMine @ LogChatTiming @ loadChat @ as;
LoadChat[ uuid_String ] := catchMine @ LoadChat @ <| "ConversationUUID" -> uuid |>;
LoadChat[ app_String, uuid_String ] := catchMine @ LoadChat @ <| "AppName" -> app, "ConversationUUID" -> uuid |>;
LoadChat // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadChat*)
loadChat // beginDefinition;

loadChat[ as_Association ] := Enclose[
    Catch @ Module[ { data },
        data = ConfirmMatch[ getChatConversationData @ as, $$conversationFullData|_Missing, "Data" ];
        If[ MissingQ @ data, RemoveChatFromSearchIndex @ as; Throw @ data ];
        ConfirmBy[ restoreAttachments @ data, AssociationQ, "RestoreAttachments" ];
        data
    ],
    throwInternalFailure
];

loadChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getChatConversationData*)
getChatConversationData // beginDefinition;

getChatConversationData[ data: $$conversationFullData ] :=
    data;

getChatConversationData[ KeyValuePattern @ { "AppName" -> appName_String, "ConversationUUID" -> uuid_String } ] :=
    getChatConversationData[ appName, uuid ];

getChatConversationData[ KeyValuePattern[ "ConversationUUID" -> uuid_String ] ] :=
    getChatConversationData @ uuid;

getChatConversationData[ uuid_String ] := Enclose[
    Catch @ Module[ { root, dir },
        root = ConfirmBy[ storageDirectory[ ], StringQ, "Root" ];
        dir = First[ conversationFileNames[ uuid, root, { 2 } ], Throw @ Missing[ "NotFound" ] ];
        ConfirmMatch[ getChatConversationData0 @ dir, $$conversationFullData|_Missing, "Data" ]
    ],
    throwInternalFailure
];

getChatConversationData[ appName_String, uuid_String ] := Enclose[
    Catch @ Module[ { root, dir },
        root = ConfirmBy[ storageDirectory @ appName, StringQ, "Root" ];
        dir = First[ conversationFileNames[ uuid, root ], Throw @ Missing[ "NotFound" ] ];
        ConfirmMatch[ getChatConversationData0 @ dir, $$conversationFullData|_Missing, "Data" ]
    ],
    throwInternalFailure
];

getChatConversationData // endDefinition;


getChatConversationData0 // beginDefinition;

getChatConversationData0[ dir_String ] := Enclose[
    Catch @ Module[ { fail, file, data },
        fail = Function[ Quiet @ DeleteDirectory[ dir, DeleteContents -> True ]; Throw @ Missing[ "NotFound" ] ];

        file = FileNameJoin @ { dir, "data.wxf" };
        If[ ! FileExistsQ @ file, fail[ ] ];

        data = Quiet @ Developer`ReadWXFFile @ file;
        If[ ! AssociationQ @ data, fail[ ] ];

        checkChatDataVersion @ data
    ],
    throwInternalFailure
];

getChatConversationData0[ missing_Missing ] :=
    missing;

getChatConversationData0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*restoreAttachments*)
restoreAttachments // beginDefinition;

restoreAttachments[ KeyValuePattern[ "Attachments" -> attachments_Association ] ] :=
    Association @ KeyValueMap[ # -> restoreAttachments @ ## &, attachments ];

restoreAttachments[ "Expressions", expressions_Association ] := Enclose[
    $attachments = ConfirmBy[ <| $attachments, expressions |>, AssociationQ, "Attachments" ],
    throwInternalFailure
];

restoreAttachments[ "ToolCalls", toolCalls_Association ] := Enclose[
    $toolEvaluationResults = ConfirmBy[ <| $toolEvaluationResults, toolCalls |>, AssociationQ, "ToolCalls" ],
    throwInternalFailure
];

restoreAttachments[ key_, value_ ] :=
    value;

restoreAttachments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DeleteChat*)
DeleteChat // beginDefinition;
DeleteChat[ as_Association ] := catchMine @ DeleteChat[ as[ "AppName" ], as[ "ConversationUUID" ] ];
DeleteChat[ uuid_String ] := catchMine @ LogChatTiming @ deleteChat[ $defaultAppName, uuid ];
DeleteChat[ appName_String, uuid_String ] := catchMine @ LogChatTiming @ deleteChat[ appName, uuid ];
DeleteChat // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deleteChat*)
deleteChat // beginDefinition;

deleteChat[ appName_String, uuid_String ] := Enclose[
    Catch @ Module[ { root, dirs, dir },
        RemoveChatFromSearchIndex[ appName, uuid ];
        root = ConfirmBy[ storageDirectory @ appName, StringQ, "Root" ];
        dirs = ConfirmMatch[ conversationFileNames[ uuid, root ], { ___String }, "Directories" ];
        If[ dirs === { }, Throw @ Missing[ "NotFound" ] ];
        dir = ConfirmBy[ First[ dirs, $Failed ], StringQ, "Directory" ];
        ConfirmMatch[ DeleteDirectory[ dir, DeleteContents -> True ], Null, "DeleteDirectory" ];
        ConfirmAssert[ ! DirectoryQ @ dir, "DirectoryCheck" ];
        updateDynamics[ "SavedChats" ];
        dir
    ],
    throwInternalFailure
];

deleteChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SaveChat*)
SaveChat // beginDefinition;
SaveChat // Options = { "AutoGenerateTitle" -> True, "AutoSaveOnly" -> False };

SaveChat[ messages_, settings_Association, opts: OptionsPattern[ ] ] :=
    With[ { autoOnly = OptionValue[ "AutoSaveOnly" ], auto = TrueQ @ settings[ "AutoSaveConversations" ] },
        Missing[ "Skipped" ] /; autoOnly && ! auto
    ];

SaveChat[ messages: $$chatMessages, settings_Association, opts: OptionsPattern[ ] ] :=
    catchMine @ LogChatTiming @ saveChat[
        messages,
        settings,
        OptionValue[ "AutoGenerateTitle" ],
        OptionValue[ "AutoSaveOnly" ]
    ];

(* Save from a notebook: *)
SaveChat[ nbo_NotebookObject, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[ { $savingNotebook = nbo },
        LogChatTiming @ saveChat[
            chat,
            ensureConversationUUID @ nbo,
            OptionValue[ "AutoGenerateTitle" ],
            OptionValue[ "AutoSaveOnly" ]
        ]
    ];

(* Save from a notebook with custom settings: *)
SaveChat[ nbo_NotebookObject, settings_Association, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[ { $savingNotebook = nbo },
        LogChatTiming @ saveChat[
            nbo,
            ensureConversationUUID[ nbo, settings ],
            OptionValue[ "AutoGenerateTitle" ],
            OptionValue[ "AutoSaveOnly" ]
        ]
    ];

(* Called at the end of chat evaluations if AutoSaveConversations is true and ensures notebook has a UUID: *)
SaveChat[ nbo_NotebookObject, messages_, settings_Association, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[ { $savingNotebook = nbo },
        SaveChat[ messages, ensureConversationUUID[ nbo, settings ], opts ]
    ];

(* Alternate chat representations: *)
SaveChat[ chat: HoldPattern[ _ChatObject ], settings_Association, opts: OptionsPattern[ ] ] :=
    catchMine @ SaveChat[ chat[ "Messages" ], settings, opts ];

SaveChat[ chat_Dataset, settings_Association, opts: OptionsPattern[ ] ] :=
    catchMine @ SaveChat[ Normal @ chat, settings, opts ];

SaveChat // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensureConversationUUID*)
ensureConversationUUID // beginDefinition;

ensureConversationUUID[ nbo_NotebookObject ] :=
    ensureConversationUUID[ nbo, <| |> ];

ensureConversationUUID[ nbo_NotebookObject, settings0_Association ] := Enclose[
    Module[ { settings, uuid },
        settings = ConfirmBy[ <| AbsoluteCurrentChatSettings @ nbo, settings0 |>, AssociationQ, "Settings" ];
        uuid = settings[ "ConversationUUID" ];
        If[ ! StringQ @ uuid,
            uuid = ConfirmBy[ CreateUUID[ ], StringQ, "UUID" ];
            settings[ "ConversationUUID" ] = uuid;
            ConfirmBy[ CurrentChatSettings[ nbo, "ConversationUUID" ] = uuid, StringQ, "SetUUID" ];
        ];
        settings
    ],
    throwInternalFailure
];

ensureConversationUUID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*saveChat*)
saveChat // beginDefinition;

saveChat[ nbo_NotebookObject, settings_, autoTitle_, auto_ ] := Enclose[
    Catch @ Module[ { cellObjects, cells, messages },
        cellObjects = ConfirmMatch[ Cells @ nbo, { ___CellObject }, "CellObjects" ];
        If[ cellObjects === { }, Throw @ Missing[ "NoCells" ] ];
        cells = ConfirmMatch[ notebookRead @ cellObjects, { ___Cell }, "Cells" ];
        messages = ConfirmMatch[ CellToChatMessage[ #, settings ] & /@ cells, $$chatMessages, "Messages" ];
        ConfirmMatch[ saveChat[ messages, settings, autoTitle, auto ], _Success | Missing[ "Skipped" ], "SaveChat" ]
    ],
    throwInternalFailure
];

saveChat[ messages_, settings_, autoTitle_, True ] :=
    If[ TrueQ @ autoSaveQ[ messages, settings ],
        saveChat0[ messages, settings, autoTitle ],
        Missing[ "Skipped" ]
    ];

saveChat[ messages_, settings_, autoTitle_, auto_ ] :=
    saveChat0[ messages, settings, autoTitle ];

saveChat // endDefinition;



saveChat0 // beginDefinition;

saveChat0[ messages0: $$chatMessages, settings0_, autoTitle_ ] := Enclose[
    Module[ { settings, messages, appName, metadata, vectors, directory, attachments, smallSettings, as },

        settings = If[ TrueQ @ autoTitle, <| settings0, "AutoGenerateTitle" -> True |>, settings0 ];
        messages = ConfirmMatch[ prepareMessagesForSaving[ messages0, settings ], $$chatMessages, "Messages" ];

        appName = ConfirmBy[
            Replace[ Lookup[ settings, "AppName" ], $$unspecified :> $defaultAppName ],
            StringQ,
            "AppName"
        ];

        metadata = ConfirmMatch[ getChatMetadata[ appName, messages, settings ], $$conversationData, "Metadata" ];
        vectors = ConfirmMatch[ createMessageVectors[ metadata, messages, settings ], { ___NumericArray }, "Vectors" ];
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
                    "Settings"    -> smallSettings,
                    "Vectors"     -> vectors
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

        ConfirmMatch[ AddChatToSearchIndex @ as, _Success | Missing[ "NoSemanticSearch" ], "AddToSearchIndex" ];

        setChatDisplayTitle[ $savingNotebook, metadata ];

        updateDynamics[ "SavedChats" ];

        Success[ "Saved", as ]
    ],
    throwInternalFailure
];

saveChat0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*autoSaveQ*)
autoSaveQ // beginDefinition;

autoSaveQ[ messages: $$chatMessages, settings_Association ] := Enclose[
    Catch @ Module[ { minResponses, responses },
        If[ settings[ "AutoSaveConversations" ] =!= True, Throw @ False ];
        minResponses = ConfirmMatch[
            Lookup[ settings, "MinimumResponsesToSave", 1 ],
            _Integer? Positive,
            "MinResponses"
        ];
        responses = Count[ messages, KeyValuePattern[ "Role" -> "Assistant" ] ];
        responses >= minResponses
    ],
    throwInternalFailure
];

autoSaveQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setChatDisplayTitle*)
setChatDisplayTitle // beginDefinition;

setChatDisplayTitle[ nbo_NotebookObject, KeyValuePattern[ "ConversationTitle" -> title_String ] ] :=
    If[ title =!= $defaultConversationTitle,
        CurrentValue[ nbo, { TaggingRules, "ConversationTitle" } ] = title
    ];

setChatDisplayTitle[ None, _ ] :=
    Null;

setChatDisplayTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createMessageVectors*)
createMessageVectors // beginDefinition;

createMessageVectors[ metadata_, messages: $$chatMessages, settings_ ] := Enclose[
    Catch @ Module[ { partitioned, strings, rVectors, iVectors, title, titleVector },
        If[ $noSemanticSearch, Throw @ { } ];
        ConfirmAssert[ Length @ messages >= 2, "LengthCheck" ];
        partitioned = ConfirmBy[ Partition[ messages, UpTo[ 2 ] ], ListQ, "Pairs" ];
        strings = ConfirmMatch[ messagesToString /@ partitioned, { __String }, "Strings" ];
        rVectors = ConfirmMatch[ getEmbeddings @ strings, { __NumericArray }, "Embeddings" ];
        iVectors = ConfirmMatch[ toInt8Vector /@ rVectors, { __NumericArray }, "Int8Vectors" ];
        title = metadata[ "ConversationTitle" ];
        If[ StringQ @ title,
            titleVector = ConfirmMatch[ toInt8Vector @ getEmbedding @ title, _NumericArray, "TitleVector" ];
            Prepend[ iVectors, titleVector ],
            iVectors
        ]
    ],
    throwInternalFailure
];

createMessageVectors // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toInt8Vector*)
toInt8Vector // beginDefinition;
toInt8Vector[ arr_NumericArray ] := NumericArray[ arr, "Integer8", "ClipAndRound" ];
toInt8Vector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getAppName*)
getAppName // beginDefinition;
getAppName[ settings_Association ] := getAppName @ settings[ "AppName" ];
getAppName[ app_String ] := app;
getAppName[ _ ] := $defaultAppName;
getAppName // endDefinition;

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
        root = ConfirmBy[ storageDirectory @ app, StringQ, "Root" ];
        dirs = ConfirmMatch[ conversationFileNames[ All, root ], { ___String }, "Directories" ];
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

saveChatFile[ "metadata", data_Association, directory_, opts: OptionsPattern[ ] ] :=
    saveChatFile0[ "metadata", KeyTake[ data, $metaKeys ], directory, opts ];

saveChatFile[ type_String, data_Association, directory_, opts: OptionsPattern[ ] ] :=
    saveChatFile0[ type, data, directory, opts ];

saveChatFile // endDefinition;


saveChatFile0 // beginDefinition;

saveChatFile0[ type_String, data_, directory_, opts: OptionsPattern[ ] ] := Enclose[
    Module[ { file },
        file = ConfirmBy[ FileNameJoin @ { directory, type <> ".wxf" }, StringQ, "File" ];
        ConfirmBy[ Developer`WriteWXFFile[ file, data, opts ], FileExistsQ, "Export" ]
    ],
    throwInternalFailure
];

saveChatFile0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getChatMetadata*)
getChatMetadata // beginDefinition;

getChatMetadata[ data: $$conversationData ] :=
    KeyTake[ data, $metaKeys ];

getChatMetadata[ appName_, messages_, settings_Association ] := Enclose[
    Module[ { uuid, title, date, version },

        uuid    = ConfirmBy[ getChatUUID @ settings, StringQ, "ConversationUUID" ];
        title   = ConfirmBy[ getChatTitle[ messages, settings ], StringQ, "ConversationTitle" ];
        date    = ConfirmMatch[ AbsoluteTime[ TimeZone -> 0 ], _Real, "Date" ];
        version = ConfirmBy[ $savedChatDataVersion, IntegerQ, "Version" ];

        <|
            "AppName"           -> appName,
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
getChatTitle[ messages_, settings_Association ] := defaultConversationTitle[ messages, settings ];
getChatTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*defaultConversationTitle*)
defaultConversationTitle // beginDefinition;

defaultConversationTitle[ messages_, settings_ ] :=
    If[ TrueQ @ settings[ "AutoGenerateTitle" ],
        generateTitleCached @ messages,
        $defaultConversationTitle
    ];

defaultConversationTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*generateTitleCached*)
generateTitleCached // beginDefinition;
generateTitleCached[ messages_List ] := generateTitleCached0 @ Take[ messages, UpTo @ $maxTitleGenerationMessages ];
generateTitleCached // endDefinition;


generateTitleCached0 // beginDefinition;

generateTitleCached0[ messages_List ] :=
    generateTitleCached0[ Hash @ messages, messages ];

generateTitleCached0[ hash_Integer, messages_ ] :=
    With[ { cached = $generatedTitleCache[ hash ] },
        cached /; StringQ @ cached
    ];

generateTitleCached0[ hash_Integer, messages_ ] := Enclose[
    Module[ { title },
        title = ConfirmMatch[ GenerateChatTitle @ messages, _String|_Failure, "Title" ];

        $lastGeneratedTitle = title;
        $lastRegeneratedTitle = None;

        (* retry once if first attempt failed using higher temperature: *)
        If[ FailureQ @ title,
            title = ConfirmBy[ GenerateChatTitle[ messages, "Temperature" -> 1.0 ], StringQ, "Retry" ];
            $lastRegeneratedTitle = title
        ];

        $generatedTitleCache[ hash ] = title
    ],
    throwInternalFailure
];

generateTitleCached0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Upgrade Data*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkChatDataVersion*)
checkChatDataVersion // beginDefinition;
checkChatDataVersion[ as: $$conversationData ] := as;
checkChatDataVersion[ as: $$legacyData ] := upgradeChatData @ as;
checkChatDataVersion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*upgradeChatData*)
upgradeChatData // beginDefinition;

upgradeChatData[ as: KeyValuePattern[ "Version" -> oldVersion_Integer ] ] := Enclose[
    Module[ { upgraded, newVersion },
        ConfirmAssert[ oldVersion < $savedChatDataVersion, "OldVersionCheck" ];
        upgraded = ConfirmBy[ upgradeChatData0[ oldVersion, as ], AssociationQ, "Upgraded" ];
        newVersion = ConfirmMatch[ upgraded[ "Version" ], _Integer, "NewVersion" ];
        ConfirmAssert[ oldVersion < newVersion <= $savedChatDataVersion, "NewVersionCheck" ];
        If[ newVersion === $savedChatDataVersion,
            upgraded,
            upgradeChatData @ upgraded
        ]
    ],
    throwInternalFailure
];

upgradeChatData // endDefinition;


upgradeChatData0 // beginDefinition;
upgradeChatData0[ 1, as_Association ] := upgradeChatData1 @ as;
upgradeChatData0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Update from version 1*)

(* Adds vectors to the saved data: *)
upgradeChatData1 // beginDefinition;

upgradeChatData1[ metadata_Association ] := Enclose[
    Module[ { appName, directory, file, data, messages, settings, vectors, newData, newMeta },

        appName   = ConfirmBy[ metadata[ "AppName" ], StringQ, "AppName" ];
        directory = ConfirmBy[ targetDirectory[ appName, metadata ], DirectoryQ, "Directory" ];
        file      = ConfirmBy[ FileNameJoin @ { directory, "data.wxf" }, FileExistsQ, "File" ];
        data      = ConfirmBy[ Developer`ReadWXFFile @ file, AssociationQ, "Data" ];
        messages  = ConfirmMatch[ data[ "Messages" ], $$chatMessages, "Messages" ];
        settings  = ConfirmBy[ data[ "Settings" ], AssociationQ, "Settings" ];
        vectors   = ConfirmMatch[ createMessageVectors[ metadata, messages, settings ], { ___NumericArray }, "Vectors" ];
        newData   = <| data, "Vectors" -> vectors, "Version" -> 2 |>;
        newMeta   = ConfirmBy[ <| metadata, "Version" -> 2 |>, AssociationQ, "Metadata" ];

        ConfirmBy[
            saveChatFile[ "metadata", newMeta, directory ],
            FileExistsQ,
            "SaveMetadata"
        ];

        ConfirmBy[
            saveChatFile[ "data", newData, directory, PerformanceGoal -> "Size" ],
            FileExistsQ,
            "SaveMessages"
        ];

        If[ KeyExistsQ[ metadata, "Messages" ],
            newData,
            newMeta
        ]
    ],
    throwInternalFailure
];

upgradeChatData1 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*File Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*storageDirectory*)
storageDirectory // beginDefinition;
storageDirectory[ ] := ChatbookFilesDirectory[ $rootStorageName, "EnsureDirectory" -> False ];
storageDirectory[ name_String ] := ChatbookFilesDirectory[ { $rootStorageName, name }, "EnsureDirectory" -> False ];
storageDirectory[ All ] := storageDirectory[ ];
storageDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*conversationFileNames*)
conversationFileNames // beginDefinition;

conversationFileNames[ All, args__ ] :=
    conversationFileNames[ __, args ];

conversationFileNames[ pattern_, args__ ] := Enclose[
    Sort @ ConfirmMatch[ FileNames[ conversationFilePattern @ pattern, args ], { ___String }, "FileNames" ],
    throwInternalFailure
];

conversationFileNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*conversationFilePattern*)
conversationFilePattern // beginDefinition;
conversationFilePattern[ pattern_ ] := $$timestampPrefix ~~ "_" ~~ pattern;
conversationFilePattern // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
