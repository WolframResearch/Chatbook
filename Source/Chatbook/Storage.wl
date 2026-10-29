(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Storage`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* TODO:
    * Save attachments separately by their hash ID (requires maintaining ref counts)
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$maxTitleGenerationMessages = 10; (* 5 input/output pairs *)
$savedChatDataVersion       = 3;
$rootStorageName            = "SavedChats";
$defaultConversationTitle   = "Untitled Chat";
$maxChatItems               = Infinity;
$timestampPrefixLength      = 7; (* good for about 1000 years *)
$$timestampPrefix           = Repeated[ LetterCharacter|DigitCharacter, { $timestampPrefixLength } ];
$backgroundTitles           = Automatic; (* auto-saves don't wait for new titles (Automatic: see backgroundTitleQ) *)

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

$$legacyData       = KeyValuePattern[ "Version" -> _? (LessThan @ $savedChatDataVersion ) ];
$$incompatibleData = KeyValuePattern[ "Version" -> _? (GreaterThan @ $savedChatDataVersion ) ];

$$appSpec = $$string | All | _NotebookObject;

$generatedTitleCache = <| |>;
$titleTasks          = <| |>; (* title generation tasks running in the background by message hash *)
$titleTargets        = <| |>; (* saved chats that are waiting for a title by conversation UUID *)
$deferredTitles      = <| |>; (* titles that were generated while an auto-save was in progress *)
$autoSaving          = False;

$appContainer = "Workspace";
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

        ConfirmMatch[
            DeleteCases[ readChatMetaFile /@ take, Missing[ "IncompatibleData" ] ],
            { ___Association },
            "Metadata"
        ]
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
        If[ data === Missing[ "NotFound" ], RemoveChatFromSearchIndex @ as ];
        If[ MissingQ @ data, Throw @ data ];
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
    Catch @ Module[ { file, data },
        file = FileNameJoin @ { dir, "data.wxf" };

        If[ ! FileExistsQ @ file,
            Quiet @ DeleteDirectory[ dir, DeleteContents -> True ];
            Throw @ Missing[ "NotFound" ]
        ];

        (* An unreadable file might be locked or only temporarily unavailable, so the chat is kept: *)
        data = Quiet @ Developer`ReadWXFFile @ file;
        If[ ! AssociationQ @ data, Throw @ Missing[ "Corrupt" ] ];

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

restoreAttachments[ type: "Expressions"|"ToolCalls"|"Reasoning", as_Association ] := Enclose[
    ConfirmBy[ LoadAttachments[ type, as ], AssociationQ, "LoadAttachments" ],
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
    catchMine @ Block[ { $savingNotebook = nbo, $appContainer = resolveAppContainer[ $evaluationCell, nbo ] },
        LogChatTiming @ saveChat[
            nbo,
            ensureConversationUUID @ nbo,
            OptionValue[ "AutoGenerateTitle" ],
            OptionValue[ "AutoSaveOnly" ]
        ]
    ];

(* Save from a notebook with custom settings: *)
SaveChat[ nbo_NotebookObject, settings_Association, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[ { $savingNotebook = nbo, $appContainer = resolveAppContainer[ $evaluationCell, nbo ] },
        LogChatTiming @ saveChat[
            nbo,
            ensureConversationUUID[ nbo, settings ],
            OptionValue[ "AutoGenerateTitle" ],
            OptionValue[ "AutoSaveOnly" ]
        ]
    ];

(* Called at the end of chat evaluations if AutoSaveConversations is true and ensures notebook has a UUID: *)
SaveChat[ nbo_NotebookObject, messages_, settings_Association, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[ { $savingNotebook = nbo, $appContainer = resolveAppContainer[ $evaluationCell, nbo ] },
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
    Module[ { settings, uuid, appContainer },
        appContainer = If[ MatchQ[ $appContainer, _CellObject ] && cellTaggedQ[ $appContainer, "NotebookAssistantSidebarCell" ], $appContainer, nbo ];
        settings = ConfirmBy[ <| AbsoluteCurrentChatSettings @ appContainer, settings0 |>, AssociationQ, "Settings" ];
        uuid = settings[ "ConversationUUID" ];
        If[ ! StringQ @ uuid,
            uuid = ConfirmBy[ createUUID[ ], StringQ, "UUID" ];
            settings[ "ConversationUUID" ] = uuid;
            ConfirmBy[ CurrentChatSettings[ appContainer, "ConversationUUID" ] = uuid, StringQ, "SetUUID" ];
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
    Catch @ Module[ { cellObjects, cells, messages, cellsContainer },
        If[ MatchQ[ $appContainer, _CellObject ] && cellTaggedQ[ $appContainer, "NotebookAssistantSidebarCell" ],
            cellsContainer = First[ Cells[ $appContainer, CellTags -> "SidebarScrollingContentCell" ], Throw @ Missing[ "NoCells" ] ]
            ,
            cellsContainer = nbo ];
        cellObjects = ConfirmMatch[ Cells @ cellsContainer, { ___CellObject }, "CellObjects" ];
        If[ cellObjects === { }, Throw @ Missing[ "NoCells" ] ];
        cells = ConfirmMatch[ notebookRead @ cellObjects, { ___Cell }, "Cells" ];
        messages = ConfirmMatch[ CellToChatMessage[ #, settings ] & /@ cells, $$chatMessages, "Messages" ];
        ConfirmMatch[ saveChat[ messages, settings, autoTitle, auto ], _Success | Missing[ "Skipped" ], "SaveChat" ]
    ],
    throwInternalFailure
];

saveChat[ messages_, settings_, autoTitle_, True ] :=
    If[ TrueQ @ autoSaveQ[ messages, settings ],
        WithCleanup[
            Block[ { $autoSaving = True }, saveChat0[ messages, settings, autoTitle ] ],
            (* Save any titles that were generated in the background while this chat was being saved: *)
            If[ $deferredTitles =!= <| |>, Quiet @ catchAlways @ applyDeferredTitles[ ] ]
        ],
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

        (* don't add the title cell in the sidebar during regular chat, only if loading a saved chat *)
        If[ ! MatchQ[ $appContainer, _CellObject ], setChatDisplayTitle[ $savingNotebook, $appContainer, metadata ] ];

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

(* 15.0: side bar chat is a single CellObject *)
setChatDisplayTitle[ nbo_NotebookObject, c_CellObject, KeyValuePattern[ "ConversationTitle" -> title_String ] ] :=
    If[ title =!= $defaultConversationTitle,
        setCurrentValue[ c, { TaggingRules, "ConversationTitle" }, title ];
        writeSidebarChatTitleCell[ nbo, c, WindowTitle ]
    ];

setChatDisplayTitle[ nbo_NotebookObject, _, KeyValuePattern[ "ConversationTitle" -> title_String ] ] :=
    If[ title =!= $defaultConversationTitle,
        setCurrentValue[ nbo, { TaggingRules, "ConversationTitle" }, title ];
        writeWorkspaceChatTitleDockedCell[ nbo, WindowTitle ]
    ];

setChatDisplayTitle[ None, _, _ ] :=
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
dropTemporaryMessages[ messages_List ] := DeleteCases[ messages, _? temporaryMessageQ ];
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
getChatUUID[ _Association ] := createUUID[ ];
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
        generateTitleCached[ messages, settings ],
        $defaultConversationTitle
    ];

defaultConversationTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*generateTitleCached*)
generateTitleCached // beginDefinition;

(* Auto-saves don't wait for new titles to be generated: *)
generateTitleCached[ messages_List, settings_ ] /; backgroundTitleQ @ settings :=
    generateTitleInBackground[ Take[ messages, UpTo @ $maxTitleGenerationMessages ], settings ];

generateTitleCached[ messages_List, _ ] :=
    generateTitleCached0 @ Take[ messages, UpTo @ $maxTitleGenerationMessages ];

generateTitleCached // endDefinition;


generateTitleCached0 // beginDefinition;

generateTitleCached0[ messages_List ] :=
    generateTitleCached0[ Hash @ messages, messages ];

generateTitleCached0[ hash_Integer, messages_ ] :=
    With[ { cached = $generatedTitleCache[ hash ] },
        cached /; StringQ @ cached
    ];

generateTitleCached0[ hash_Integer, messages_ ] := Enclose[
    Catch @ Module[ { title },
        title = ConfirmMatch[ GenerateChatTitle @ messages, _String|_Failure, "Title" ];

        $lastGeneratedTitle = title;
        $lastRegeneratedTitle = None;

        (* retry once if first attempt failed using higher temperature and relaxed length constraint: *)
        If[ FailureQ @ title,
            title = ConfirmMatch[
                GenerateChatTitle[ messages, "MaxLength" -> 60, "Temperature" -> 1.0 ],
                _String|_Failure,
                "Retry"
            ];
            $lastRegeneratedTitle = title
        ];

        (* if it's still failing, just return a default title *)
        If[ FailureQ @ title, Throw[ "Untitled Chat" ] ];

        $generatedTitleCache[ hash ] = title
    ],
    throwInternalFailure
];

generateTitleCached0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*backgroundTitleQ*)
(* Only auto-saves of chats with a ConversationUUID generate titles in the background, since the UUID identifies the
   saved chat to update later. The callback also has to be able to run after the save returns, so with the default
   $backgroundTitles (Automatic), this requires a front end and is not done in the cloud: *)
backgroundTitleQ // beginDefinition;

backgroundTitleQ[ KeyValuePattern[ "ConversationUUID" -> _String ] ] :=
    TrueQ @ $autoSaving && TrueQ @ Replace[ $backgroundTitles, Automatic :> $Notebooks && ! $CloudEvaluation ];

backgroundTitleQ[ _ ] :=
    False;

backgroundTitleQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*generateTitleInBackground*)
(* Returns the cached title if available. Otherwise, starts generating a new title (unless a request for the same
   messages is still running) and returns the previously saved title for this chat, which gets replaced in the saved
   files once the new title is ready. Only the latest save of each chat gets the title (see applyBackgroundTitle). *)
generateTitleInBackground // beginDefinition;

generateTitleInBackground[ messages_List, settings_Association ] := Enclose[
    Module[ { hash, cached, appName, uuid, title },

        hash    = Hash @ messages;
        cached  = $generatedTitleCache[ hash ];
        appName = ConfirmBy[ getAppName @ settings, StringQ, "AppName" ];
        uuid    = ConfirmBy[ settings[ "ConversationUUID" ], StringQ, "ConversationUUID" ];
        title   = If[ StringQ @ cached, cached, ConfirmBy[ savedChatTitle[ appName, uuid ], StringQ, "SavedTitle" ] ];

        $titleTargets[ uuid ] = <|
            "AppName"          -> appName,
            "ConversationUUID" -> uuid,
            "Hash"             -> hash,
            "Title"            -> title,
            "Notebook"         -> $savingNotebook,
            "Container"        -> $appContainer
        |>;

        If[ ! StringQ @ cached && ! MatchQ[ Quiet @ $titleTasks[ hash, "Task" ][ "TaskStatus" ], "Running"|"Waiting" ],
            submitBackgroundTitle[ hash, messages, 1, None ]
        ];

        title
    ],
    throwInternalFailure
];

generateTitleInBackground // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*savedChatTitle*)
savedChatTitle // beginDefinition;

savedChatTitle[ appName_String, uuid_String ] := Enclose[
    Catch @ Module[ { root, dir, metadata },
        root     = ConfirmBy[ storageDirectory @ appName, StringQ, "Root" ];
        dir      = Last[ conversationFileNames[ uuid, root ], Throw @ $defaultConversationTitle ];
        metadata = Quiet @ Developer`ReadWXFFile @ FileNameJoin @ { dir, "metadata.wxf" };
        Replace[
            metadata,
            { KeyValuePattern[ "ConversationTitle" -> title_String ] :> title, _ :> $defaultConversationTitle }
        ]
    ],
    throwInternalFailure
];

savedChatTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*submitBackgroundTitle*)
submitBackgroundTitle // beginDefinition;

submitBackgroundTitle[ hash_Integer, messages_List, attempt_Integer, llmKitSettings_ ] :=
    Module[ { callback, opts, task },

        callback = backgroundTitleCallback[ hash, messages, attempt ];
        opts     = If[ attempt === 1, { }, { "MaxLength" -> 60, "Temperature" -> 1.0 } ];

        task = withLLMKitSettings[
            llmKitSettings,
            LogChatTiming @ generateChatTitleInBackground[ messages, callback, Sequence @@ opts ]
        ];

        If[ MatchQ[ task, _TaskObject ],
            (* A retry is submitted from the callback, which can run outside of this chat, so remember the settings: *)
            $titleTasks[ hash ] = <|
                "Task"           -> task,
                "LLMKitSettings" -> withLLMKitSettings[
                    llmKitSettings,
                    <| "LLMKit" -> $llmKit, "LLMKitService" -> If[ TrueQ @ $llmKit, $llmKitService, None ] |>
                ]
            |>,
            (* GenerateChatTitleAsynchronous only returns a failure when it's not called within catchTop. Here (in the
               auto-save or the callback), a request that can't be submitted is thrown to that catchTop instead, which
               fails the auto-save, or keeps the saved title if it was the retry. This handles a returned failure like
               a failed response: *)
            callback @ task
        ]
    ];

submitBackgroundTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*withLLMKitSettings*)
withLLMKitSettings // beginDefinition;
withLLMKitSettings // Attributes = { HoldRest };

withLLMKitSettings[ KeyValuePattern @ { "LLMKit" -> llmKit_, "LLMKitService" -> service_ }, eval_ ] :=
    Block[ { $llmKit = llmKit, $llmKitService = service }, eval ];

withLLMKitSettings[ _, eval_ ] :=
    eval;

withLLMKitSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*backgroundTitleCallback*)
(* The callback can run in the middle of any other evaluation (e.g. the next chat), so it needs to be isolated: *)
backgroundTitleCallback // beginDefinition;

backgroundTitleCallback[ hash_, messages_, attempt_ ] :=
    Function[
        Quiet @ catchAlways @ Block[ { $lastTask = None, $lastCellObject = None },
            receiveBackgroundTitle[ hash, messages, attempt, # ]
        ]
    ];

backgroundTitleCallback // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*receiveBackgroundTitle*)
(* This follows the same steps as generateTitleCached0: *)
receiveBackgroundTitle // beginDefinition;

receiveBackgroundTitle[ hash_, _, 1, title_String ] := (
    $lastGeneratedTitle   = title;
    $lastRegeneratedTitle = None;
    finishBackgroundTitle[ hash, title, True ]
);

(* retry once if first attempt failed using higher temperature and relaxed length constraint: *)
receiveBackgroundTitle[ hash_, messages_, 1, failure_ ] := (
    $lastGeneratedTitle   = failure;
    $lastRegeneratedTitle = None;
    submitBackgroundTitle[ hash, messages, 2, $titleTasks[ hash, "LLMKitSettings" ] ]
);

receiveBackgroundTitle[ hash_, _, 2, title_String ] := (
    $lastRegeneratedTitle = title;
    finishBackgroundTitle[ hash, title, True ]
);

(* if it's still failing, just use a default title (which is not cached) *)
receiveBackgroundTitle[ hash_, _, 2, failure_ ] := (
    $lastRegeneratedTitle = failure;
    finishBackgroundTitle[ hash, $defaultConversationTitle, False ]
);

receiveBackgroundTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*finishBackgroundTitle*)
finishBackgroundTitle // beginDefinition;

finishBackgroundTitle[ hash_Integer, title_String, cache: True|False ] := (
    KeyDropFrom[ $titleTasks, hash ];
    If[ cache, $generatedTitleCache[ hash ] = title ];
    (* An auto-save in progress might still write the previous title, so wait until it's done: *)
    If[ TrueQ @ $autoSaving,
        $deferredTitles[ hash ] = title,
        applyBackgroundTitle[ hash, title ]
    ]
);

finishBackgroundTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyDeferredTitles*)
applyDeferredTitles // beginDefinition;

applyDeferredTitles[ ] :=
    With[ { deferred = $deferredTitles },
        $deferredTitles = <| |>;
        KeyValueMap[ applyBackgroundTitle, deferred ]
    ];

applyDeferredTitles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyBackgroundTitle*)
applyBackgroundTitle // beginDefinition;

applyBackgroundTitle[ hash_Integer, title_String ] :=
    KeyValueMap[
        Function[
            KeyDropFrom[ $titleTargets, #1 ];
            LogChatTiming @ updateSavedChatTitle[ #2, title ]
        ],
        Select[ $titleTargets, #[ "Hash" ] === hash & ]
    ];

applyBackgroundTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*updateSavedChatTitle*)
(* Replaces only the title of a saved chat, since newer messages might have been saved in the meantime: *)
updateSavedChatTitle // beginDefinition;

updateSavedChatTitle[ KeyValuePattern[ "Title" -> title_String ], title_String ] :=
    Null;

updateSavedChatTitle[ target_Association, title_String ] := Enclose[
    Catch @ Module[ { appName, uuid, saved, root, dir, metadata, data, vectors, newData },

        appName = ConfirmBy[ target[ "AppName"          ], StringQ, "AppName"          ];
        uuid    = ConfirmBy[ target[ "ConversationUUID" ], StringQ, "ConversationUUID" ];
        saved   = ConfirmBy[ target[ "Title"            ], StringQ, "Title"            ];
        root    = ConfirmBy[ storageDirectory @ appName, StringQ, "Root" ];

        (* The chat might have been deleted in the meantime: *)
        dir = Last[ conversationFileNames[ uuid, root ], Throw @ Missing[ "NotFound" ] ];

        (* Leave the title alone if the chat has been saved with a different title in the meantime: *)
        metadata = Quiet @ Developer`ReadWXFFile @ FileNameJoin @ { dir, "metadata.wxf" };
        If[ ! MatchQ[ metadata, KeyValuePattern[ "ConversationTitle" -> saved ] ], Throw @ Missing[ "TitleChanged" ] ];

        data = Quiet @ Developer`ReadWXFFile @ FileNameJoin @ { dir, "data.wxf" };
        If[ ! MatchQ[ data, $$conversationFullData ] || data[ "ConversationTitle" ] =!= saved,
            Throw @ Missing[ "TitleChanged" ]
        ];

        (* The first vector is the embedding of the title (see createMessageVectors): *)
        vectors = ConfirmMatch[ Lookup[ data, "Vectors", { } ], { ___NumericArray }, "Vectors" ];
        If[ vectors =!= { } && ! TrueQ @ $noSemanticSearch,
            vectors = ReplacePart[
                vectors,
                1 -> ConfirmMatch[ toInt8Vector @ getEmbedding @ title, _NumericArray, "TitleVector" ]
            ]
        ];

        newData = <| data, "ConversationTitle" -> title, "Vectors" -> vectors |>;

        ConfirmBy[ saveChatFile[ "data", newData, dir, PerformanceGoal -> "Size" ], FileExistsQ, "SaveMessages" ];
        ConfirmBy[ saveChatFile[ "metadata", newData, dir ], FileExistsQ, "SaveMetadata" ];

        ConfirmMatch[
            AddChatToSearchIndex @ newData,
            _Success | Missing[ "NoSemanticSearch"|"NoVectors" ],
            "AddToSearchIndex"
        ];

        If[ currentConversationQ[ target[ "Notebook" ], target[ "Container" ], uuid ],
            setChatDisplayTitle[ target[ "Notebook" ], target[ "Container" ], newData ]
        ];

        updateDynamics[ "SavedChats" ];

        title
    ],
    throwInternalFailure
];

updateSavedChatTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*currentConversationQ*)
(* Checks if the notebook still shows the chat (e.g. it wasn't closed and "New Chat" wasn't clicked): *)
currentConversationQ // beginDefinition;

(* don't add the title cell in the sidebar during regular chat (see saveChat0) *)
currentConversationQ[ _, _CellObject, _ ] :=
    False;

currentConversationQ[ nbo_NotebookObject, _, uuid_String ] :=
    TrueQ @ notebookObjectQ @ nbo && CurrentChatSettings[ nbo, "ConversationUUID" ] === uuid;

currentConversationQ[ _, _, _ ] :=
    False;

currentConversationQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Upgrade Data*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkChatDataVersion*)
checkChatDataVersion // beginDefinition;
checkChatDataVersion[ as: $$conversationData ] := as;
checkChatDataVersion[ as: $$legacyData ] := upgradeChatData @ as;
checkChatDataVersion[ as: $$incompatibleData ] := Missing[ "IncompatibleData" ];
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
            AddChatToSearchIndex @ upgraded;
            upgraded,
            upgradeChatData @ upgraded
        ]
    ],
    throwInternalFailure
];

upgradeChatData // endDefinition;


upgradeChatData0 // beginDefinition;
upgradeChatData0[ 1, as_Association ] := upgradeChatData1 @ as;
upgradeChatData0[ 2, as_Association ] := upgradeChatData2 @ as;
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
(* ::Subsubsection::Closed:: *)
(*Update from version 2*)

(* Renames "CodeAssistance" to "NotebookAssistance": *)
upgradeChatData2 // beginDefinition;

upgradeChatData2[ metadata_Association ] := Enclose[
    Catch @ Module[ { appName, dir1, dir2, file, data, newData, newMeta },

        appName = ConfirmBy[
            Replace[ metadata[ "AppName" ], "CodeAssistance" -> "NotebookAssistance" ],
            StringQ,
            "AppName"
        ];

        dir1 = ConfirmBy[ targetDirectory[ metadata[ "AppName" ], metadata ], DirectoryQ, "Directory" ];
        dir2 = ConfirmBy[ targetDirectory[ appName, metadata ], DirectoryQ, "NewDirectory" ];

        file = ConfirmBy[
            SelectFirst[ { FileNameJoin @ { dir1, "data.wxf" }, FileNameJoin @ { dir2, "data.wxf" } }, FileExistsQ ],
            FileExistsQ,
            "File"
        ];

        data    = ConfirmBy[ Developer`ReadWXFFile @ file, AssociationQ, "Data" ];
        newData = ConfirmBy[ <| data, "AppName" -> appName, "Version" -> 3 |>, AssociationQ, "NewData" ];
        newMeta = ConfirmBy[ <| metadata, "AppName" -> appName, "Version" -> 3 |>, AssociationQ, "NewMetadata" ];

        ConfirmBy[
            saveChatFile[ "metadata", newMeta, dir2 ],
            FileExistsQ,
            "SaveMetadata"
        ];

        ConfirmBy[
            saveChatFile[ "data", newData, dir2, PerformanceGoal -> "Size" ],
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

upgradeChatData2 // endDefinition;

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
