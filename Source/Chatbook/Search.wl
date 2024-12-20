(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Search`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$rootStorageName    = "Search";
$chatSearchIndex    = None;
$searchIndexVersion = 1;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SearchChats*)
SearchChats // beginDefinition;
SearchChats // Options = { "CacheEmbeddings" -> False, MaxItems -> 10 };

SearchChats[ app: _String|All, query_String, opts: OptionsPattern[ ] ] :=
    catchMine @ LogChatTiming @ searchChats[
        app,
        query,
        OptionValue[ MaxItems ],
        OptionValue[ "CacheEmbeddings" ]
    ];

SearchChats[ query_String, opts: OptionsPattern[ ] ] :=
    catchMine @ SearchChats[ All, query, opts ];

SearchChats // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*searchChats*)
searchChats // beginDefinition;

searchChats[ appName_String, query_String, max_? Positive, cache_ ] := Enclose[
    Catch @ Module[ { index, flat, values, vectors, embedding, idx, results },

        If[ query === "", Throw @ { } ];
        index = Values @ ConfirmBy[ loadChatSearchIndex @ appName, AssociationQ, "Load" ];

        flat = ConfirmMatch[
            Flatten[ Thread @ { KeyDrop[ #, "Vectors" ], #Vectors } & /@ index, 1 ],
            { { _Association, _NumericArray }... },
            "Flat"
        ];

        If[ flat === { }, Throw @ { } ];

        { values, vectors } = ConfirmMatch[ Transpose @ flat, { _, _ }, "Transpose" ];

        embedding = ConfirmBy[
            getEmbedding[ query, "CacheEmbeddings" -> TrueQ @ cache ],
            NumericArrayQ,
            "Embedding"
        ];

        idx = ConfirmMatch[
            Nearest[ Normal @ vectors -> "Index", Normal @ embedding, Floor[ 2*max+1 ] ],
            { ___Integer },
            "Nearest"
        ];

        results = ConfirmMatch[ values[[ idx ]], { ___Association }, "Results" ];

        Take[ DeleteDuplicatesBy[ results, Lookup[ "ConversationUUID" ] ], UpTo @ Floor @ max ]
    ],
    throwInternalFailure
];

searchChats // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AddChatToSearchIndex*)
AddChatToSearchIndex // beginDefinition;

AddChatToSearchIndex[ as: KeyValuePattern[ "ConversationUUID" -> _String ] ] :=
    catchMine @ LogChatTiming @ addChatToSearchIndex @ as;

AddChatToSearchIndex[ uuid_String ] :=
    catchMine @ LogChatTiming @ addChatToSearchIndex @ uuid;

AddChatToSearchIndex[ app_String, uuid_String ] :=
    catchMine @ LogChatTiming @ addChatToSearchIndex @ <| "AppName" -> app, "ConversationUUID" -> uuid |>;

AddChatToSearchIndex // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*addChatToSearchIndex*)
addChatToSearchIndex // beginDefinition;

addChatToSearchIndex[ spec_ ] := Enclose[
    Catch @ Module[ { data, appName, uuid, vectors, metadata },
        If[ $noSemanticSearch, Throw @ Missing[ "NoSemanticSearch" ] ];
        data = ConfirmMatch[ getChatConversationData @ spec, _Association|_Missing, "Data" ];
        If[ MissingQ @ data, Throw @ Missing[ "NoVectors" ] ]; (* TODO: auto-save here? *)
        appName = ConfirmBy[ data[ "AppName" ], StringQ, "AppName" ];
        uuid = ConfirmBy[ data[ "ConversationUUID" ], StringQ, "ConversationUUID" ];
        vectors = ConfirmMatch[ data[ "Vectors" ], { ___NumericArray }, "Vectors" ];
        If[ vectors === { }, Throw @ Missing[ "NoVectors" ] ];

        ConfirmBy[ loadChatSearchIndex @ appName, AssociationQ, "Load" ];
        ConfirmAssert[ AssociationQ @ $chatSearchIndex[ appName ], "CheckIndex" ];

        metadata = ConfirmBy[ getChatMetadata @ data, AssociationQ, "Metadata" ];
        $chatSearchIndex[ appName, uuid ] = <| metadata, "Vectors" -> vectors |>;
        ConfirmBy[ saveChatIndex @ appName, FileExistsQ, "Save" ];

        Success[ "AddedChatToSearchIndex", <| "AppName" -> appName, "ConversationUUID" -> uuid |> ]
    ],
    throwInternalFailure
];

addChatToSearchIndex // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RemoveChatFromSearchIndex*)
RemoveChatFromSearchIndex // beginDefinition;

RemoveChatFromSearchIndex[ as: KeyValuePattern[ "ConversationUUID" -> uuid_String ] ] :=
    catchMine @ LogChatTiming @ removeChatFromSearchIndex[ Lookup[ as, "AppName", All ], uuid ];

RemoveChatFromSearchIndex[ uuid_String ] :=
    catchMine @ LogChatTiming @ removeChatFromSearchIndex[ All, uuid ];

RemoveChatFromSearchIndex[ app_String, uuid_String ] :=
    catchMine @ LogChatTiming @ removeChatFromSearchIndex[ app, uuid ];

RemoveChatFromSearchIndex // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeChatFromSearchIndex*)
removeChatFromSearchIndex // beginDefinition;

removeChatFromSearchIndex[ All, uuid_String ] := Enclose[
    Catch @ Module[ { appNames },
        ConfirmBy[ loadChatSearchIndex[ All ], AssociationQ, "Load" ];
        appNames = ConfirmMatch[ Keys @ DeleteMissing @ $chatSearchIndex[[ All, uuid ]], { ___String }, "Names" ];
        removeChatFromSearchIndex[ #, uuid ] & /@ appNames
    ],
    throwInternalFailure
];

removeChatFromSearchIndex[ app_String, uuid_String ] := Enclose[
    ConfirmBy[ loadChatSearchIndex @ app, AssociationQ, "Load" ];
    ConfirmAssert[ AssociationQ @ $chatSearchIndex[ app ], "CheckIndex" ];
    KeyDropFrom[ $chatSearchIndex[ app ], uuid ];
    ConfirmBy[ saveChatIndex @ app, FileExistsQ, "Save" ];
    Success[ "RemovedChatFromSearchIndex", <| "AppName" -> app, "ConversationUUID" -> uuid |> ],
    throwInternalFailure
];

removeChatFromSearchIndex // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RebuildChatSearchIndex*)
RebuildChatSearchIndex // beginDefinition;
RebuildChatSearchIndex[ appName_String ] := catchMine @ LogChatTiming @ rebuildChatSearchIndex @ appName;
RebuildChatSearchIndex[ All ] := catchMine @ LogChatTiming @ rebuildChatSearchIndex @ All;
RebuildChatSearchIndex[ ] := catchMine @ LogChatTiming @ rebuildChatSearchIndex @ All;
RebuildChatSearchIndex // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*rebuildChatSearchIndex*)
rebuildChatSearchIndex // beginDefinition;

rebuildChatSearchIndex[ appName_String ] := Enclose[
    Module[ { root, chats },

        root = ConfirmBy[
            ChatbookFilesDirectory[ { $rootStorageName, appName }, "EnsureDirectory" -> False ],
            StringQ,
            "Root"
        ];

        If[ DirectoryQ @ root, ConfirmMatch[ DeleteDirectory[ root, DeleteContents -> True ], Null, "Delete" ] ];

        If[ ! AssociationQ @ $chatSearchIndex, $chatSearchIndex = <| |> ];
        chats = ConfirmMatch[ ListSavedChats @ appName, { ___Association }, "Chats" ];
        ConfirmMatch[ addChatToSearchIndex /@ chats, { (_Success|Missing[ "NoVectors" ])... }, "AddChatToSearchIndex" ];
        ConfirmBy[ saveChatIndex @ appName, FileExistsQ, "Save" ];
        ConfirmBy[ $chatSearchIndex[ appName ], AssociationQ, "Result" ]
    ],
    throwInternalFailure
];

rebuildChatSearchIndex[ All ] := Enclose[
    Module[ { root, chats },

        root = ConfirmBy[
            ChatbookFilesDirectory[ $rootStorageName, "EnsureDirectory" -> False ],
            StringQ,
            "Root"
        ];

        If[ DirectoryQ @ root, ConfirmMatch[ DeleteDirectory[ root, DeleteContents -> True ], Null, "Delete" ] ];

        $chatSearchIndex = <| |>;
        chats = ConfirmMatch[ ListSavedChats[ ], { ___Association }, "Chats" ];
        ConfirmMatch[ addChatToSearchIndex /@ chats, { (_Success|Missing[ "NoVectors" ])... }, "AddChatToSearchIndex" ];
        ConfirmMatch[ saveChatIndex[ ], { ___? FileExistsQ }, "Save" ];
        $chatSearchIndex
    ],
    throwInternalFailure
];

rebuildChatSearchIndex // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Loading/Saving*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadChatSearchIndex*)
loadChatSearchIndex // beginDefinition;

loadChatSearchIndex[ appName_String ] := Enclose[
    Catch @ Module[ { root, file, data, index },

        If[ ! AssociationQ @ $chatSearchIndex, $chatSearchIndex = <| |> ];

        If[ AssociationQ @ $chatSearchIndex[ appName ],
            Throw @ $chatSearchIndex[ appName ],
            $chatSearchIndex[ appName ] = <| |>
        ];

        root = ConfirmBy[
            ChatbookFilesDirectory[ { $rootStorageName, appName }, "EnsureDirectory" -> False ],
            StringQ,
            "Root"
        ];

        file = FileNameJoin @ { root, "index.wxf" };
        If[ ! FileExistsQ @ file, Throw @ rebuildChatSearchIndex @ appName ];

        data = Quiet @ Developer`ReadWXFFile @ file;
        If[ ! AssociationQ @ data, Throw @ rebuildChatSearchIndex @ appName ];

        index = ConfirmBy[ data[ "Index" ], AssociationQ, "Index" ];
        $chatSearchIndex[ appName ] = index
    ],
    throwInternalFailure
];

loadChatSearchIndex[ All ] := Enclose[
    Catch @ Module[ { root, files, names },
        If[ ! AssociationQ @ $chatSearchIndex, $chatSearchIndex = <| |> ];

        root = ConfirmBy[
            ChatbookFilesDirectory[ $rootStorageName, "EnsureDirectory" -> False ],
            StringQ,
            "Root"
        ];

        If[ ! DirectoryQ @ root, Throw @ $chatSearchIndex ];

        files = ConfirmMatch[ FileNames[ "index.wxf", root, { 2 } ], { ___String }, "Files" ];
        If[ files === { }, Throw @ $chatSearchIndex ];

        names = ConfirmMatch[ FileBaseName @* DirectoryName /@ files, { __String }, "Names" ];
        ConfirmMatch[ loadChatSearchIndex /@ names, { ___Association }, "Load" ];

        $chatSearchIndex
    ],
    throwInternalFailure
];

loadChatSearchIndex // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*saveChatIndex*)
saveChatIndex // beginDefinition;

saveChatIndex[ appName_String ] := Enclose[
    Module[ { index, root, file, data },
        index = ConfirmBy[ $chatSearchIndex[ appName ], AssociationQ, "Data" ];

        root = ConfirmBy[
            ChatbookFilesDirectory[ { $rootStorageName, appName }, "EnsureDirectory" -> True ],
            StringQ,
            "Root"
        ];

        file = FileNameJoin @ { root, "index.wxf" };
        data = <| "Index" -> index, "Version" -> $searchIndexVersion |>;

        ConfirmBy[ Developer`WriteWXFFile[ file, data, PerformanceGoal -> "Size" ], FileExistsQ, "Result" ]
    ],
    throwInternalFailure
];

saveChatIndex[ ] :=
    saveChatIndex /@ Keys @ $chatSearchIndex;

saveChatIndex // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
