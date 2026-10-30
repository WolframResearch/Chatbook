(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/WorkspaceChatInitialization.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/WorkspaceChatInitialization.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* Initialization never downloads anything, so make sure the resources it loads are installed: *)
VerificationTest[
    InstallVectorDatabases[ ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallVectorDatabases@@Tests/WorkspaceChatInitialization.wlt:22,1-27,2"
]

$expectedVectorDBNames = {
    "SourceSelector",
    "DocumentationURIs",
    "EntityValues",
    "FunctionRepositoryURIs",
    "DataRepositoryURIs",
    "NeuralNetRepositoryURIs",
    "PacletRepositoryURIs"
};

memoizedQ[ f_Symbol, arg_String ] :=
    MemberQ[ DownValues @ f, _[ Verbatim[ HoldPattern ][ HoldPattern @ f @ arg ], _ ] ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*initializeWorkspaceChat*)
VerificationTest[
    Wolfram`Chatbook`ChatModes`UI`Private`initializeWorkspaceChat[ ],
    True,
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChat@@Tests/WorkspaceChatInitialization.wlt:45,1-50,2"
]

VerificationTest[
    Wolfram`Chatbook`ChatModes`UI`Private`$workspaceChatInitialized,
    True,
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChat-Initialized@@Tests/WorkspaceChatInitialization.wlt:52,1-57,2"
]

VerificationTest[
    NumericArrayQ @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$embeddingCache[ "Hello" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChat-Embeddings@@Tests/WorkspaceChatInitialization.wlt:59,1-64,2"
]

VerificationTest[
    KeyExistsQ[ Wolfram`Chatbook`Common`$cachedTokenizers, "gpt-4o-text" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChat-Tokenizer@@Tests/WorkspaceChatInitialization.wlt:66,1-71,2"
]

(* getVectorDB keeps the loaded databases in $loadedVectorDBs (together with the index fingerprint that it checks): *)
VerificationTest[
    AllTrue[
        $expectedVectorDBNames,
        KeyExistsQ[ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$loadedVectorDBs, # ] &
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChat-VectorDatabases@@Tests/WorkspaceChatInitialization.wlt:74,1-82,2"
]

VerificationTest[
    AllTrue[
        $expectedVectorDBNames,
        memoizedQ[ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`loadVectorDBValues, # ] &
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChat-VectorDatabaseValues@@Tests/WorkspaceChatInitialization.wlt:84,1-92,2"
]

VerificationTest[
    AllTrue[
        { "Documentation", "ResourceSystem" },
        AssociationQ @ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetIndexCache[
            #,
            "Index"
        ] &
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChat-SnippetIndexes@@Tests/WorkspaceChatInitialization.wlt:94,1-105,2"
]

(* A failure in one step should not stop the others or produce messages: *)
VerificationTest[
    Internal`InheritedBlock[ { Wolfram`Chatbook`Common`getEmbeddings },
        Wolfram`Chatbook`Common`getEmbeddings[ { "Hello" } ] :=
            Wolfram`Chatbook`Common`throwInternalFailure @ Wolfram`Chatbook`Common`getEmbeddings @ { "Hello" };
        Wolfram`Chatbook`ChatModes`UI`Private`initializeWorkspaceChat[ ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChat-FailureIsolation@@Tests/WorkspaceChatInitialization.wlt:108,1-117,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*initializationStep*)
VerificationTest[
    Wolfram`Chatbook`ChatModes`UI`Private`initializationStep[
        Wolfram`Chatbook`Common`throwInternalFailure @ Wolfram`Chatbook`ChatModes`UI`Private`initializationStep[ ],
        "Test"
    ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "InitializationStep-Failure@@Tests/WorkspaceChatInitialization.wlt:122,1-130,2"
]

(* Steps do not change the chat state, since asynchronous handlers of a chat that is streaming at the same time run
   during the step and need to see and update their own state: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$lastTask       = "Task",
            Wolfram`Chatbook`Common`$lastCellObject = "Cell",
            Wolfram`Chatbook`$ChatHandlerData       = <| "Key" -> "Value" |>
        },
        {
            Wolfram`Chatbook`ChatModes`UI`Private`initializationStep[
                Wolfram`Chatbook`Common`$lastTask = "NewTask";
                { Wolfram`Chatbook`Common`$lastCellObject, Wolfram`Chatbook`$ChatHandlerData },
                "Test"
            ],
            Wolfram`Chatbook`Common`$lastTask
        }
    ],
    { { "Cell", <| "Key" -> "Value" |> }, "NewTask" },
    SameTest -> MatchQ,
    TestID   -> "InitializationStep-ChatState@@Tests/WorkspaceChatInitialization.wlt:134,1-153,2"
]

VerificationTest[
    Module[ { seen = None },
        Block[ { Wolfram`Chatbook`Common`$lastTask = "Task" },
            SessionSubmit @ ScheduledTask[ seen = Wolfram`Chatbook`Common`$lastTask, { 0.1 } ];
            Wolfram`Chatbook`ChatModes`UI`Private`initializationStep[
                TimeConstrained[ While[ seen === None, Pause[ 0.01 ] ], 10 ],
                "Test"
            ];
            seen
        ]
    ],
    "Task",
    SameTest -> MatchQ,
    TestID   -> "InitializationStep-AsynchronousChatState@@Tests/WorkspaceChatInitialization.wlt:155,1-169,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withIsolatedChatState*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$lastTask       = "Task",
            Wolfram`Chatbook`Common`$lastCellObject = "Cell",
            Wolfram`Chatbook`$ChatHandlerData       = <| "Key" -> "Value" |>
        },
        {
            Wolfram`Chatbook`ChatModes`UI`Private`withIsolatedChatState[
                Wolfram`Chatbook`Common`addHandlerArguments[ "Key" -> "Changed" ];
                { Wolfram`Chatbook`Common`$lastTask, Wolfram`Chatbook`Common`$lastCellObject }
            ],
            Wolfram`Chatbook`Common`$lastTask,
            Wolfram`Chatbook`Common`$lastCellObject,
            Wolfram`Chatbook`$ChatHandlerData
        }
    ],
    { { None, None }, "Task", "Cell", <| "Key" -> "Value" |> },
    SameTest -> MatchQ,
    TestID   -> "WithIsolatedChatState-RestoresChatState@@Tests/WorkspaceChatInitialization.wlt:174,1-194,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*initializeWorkspaceChatSettings*)
VerificationTest[
    Wolfram`Chatbook`ChatModes`UI`Private`initializeWorkspaceChatSettings[ ],
    If[ $CloudUserID === None,
        Missing[ "NotAuthenticated" ],
        KeyValuePattern @ {
            "PromptGenerators"     -> { __LLMPromptGenerator },
            "ResolvedAutoSettings" -> True,
            "WorkspaceChat"        -> True
        }
    ],
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChatSettings@@Tests/WorkspaceChatInitialization.wlt:199,1-211,2"
]

VerificationTest[
    Block[ { $CloudUserID = None },
        Wolfram`Chatbook`ChatModes`UI`Private`initializeWorkspaceChatSettings[ ]
    ],
    Missing[ "NotAuthenticated" ],
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChatSettings-NotAuthenticated@@Tests/WorkspaceChatInitialization.wlt:213,1-220,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*initializeRelatedDocumentation*)
VerificationTest[
    Wolfram`Chatbook`Common`initializeRelatedDocumentation[ None ],
    <|
        "VectorDatabases" -> $expectedVectorDBNames,
        "SnippetIndexes"  -> <| "Documentation" -> _Integer? Positive, "ResourceSystem" -> _Integer? Positive |>
    |>,
    SameTest -> MatchQ,
    TestID   -> "InitializeRelatedDocumentation@@Tests/WorkspaceChatInitialization.wlt:225,1-233,2"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`initializationVectorDBNames[ None ],
    $expectedVectorDBNames,
    SameTest -> MatchQ,
    TestID   -> "InitializationVectorDBNames@@Tests/WorkspaceChatInitialization.wlt:235,1-240,2"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`initializationVectorDBNames @
        Wolfram`Chatbook`Common`resolvePromptGenerators @ <|
            "ExperimentalFeatures" -> { },
            "PromptGenerators"     -> { "RelatedDocumentation", "RelatedWolframAlphaResults" }
        |>,
    Append[ $expectedVectorDBNames, "WolframAlphaQueries" ],
    SameTest -> MatchQ,
    TestID   -> "InitializationVectorDBNames-WolframAlpha@@Tests/WorkspaceChatInitialization.wlt:242,1-251,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Downloads*)

(* Initialization should never start a download when resources are not installed: *)
noDownloads // Attributes = { HoldFirst };
noDownloads[ eval_ ] := Catch[
    Block[
        {
            URLDownload       = Throw[ "DownloadStarted", noDownloads ] &,
            URLDownloadSubmit = Throw[ "DownloadStarted", noDownloads ] &
        },
        eval
    ],
    noDownloads
];

VerificationTest[
    Module[ { dir, result },
        dir = CreateDirectory[ ];
        result = Internal`InheritedBlock[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`loadVectorDBValues
            },
            (* Remove cached values, since nothing would be cached if the databases were not installed: *)
            Scan[
                Function[
                    sym,
                    DownValues[ sym ] = DeleteCases[ DownValues @ sym, _[ Verbatim[ HoldPattern ][ _[ _String ] ], _ ] ]
                ],
                {
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`loadVectorDBValues
                }
            ];
            Block[
                {
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$loadedVectorDBs = <| |>,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDirectory :=
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDBDirectory[ ],
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$pacletVectorDBDirectory = dir,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$localVectorDBDirectory   = dir
                },
                noDownloads @ Wolfram`Chatbook`PromptGenerators`Common`initializeVectorDatabases @ { "SourceSelector" }
            ]
        ];
        { result, FileNames[ All, dir, Infinity ], DeleteDirectory[ dir, DeleteContents -> True ] }
    ],
    { Missing[ "DownloadDisabled" ], { }, Null },
    SameTest -> MatchQ,
    TestID   -> "InitializeVectorDatabases-NoDownload@@Tests/WorkspaceChatInitialization.wlt:270,1-305,2"
]

VerificationTest[
    Module[ { dir, result },
        dir = CreateDirectory[ ];
        result = Block[
            {
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetIndexCache = <| |>,
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$streamableSnippetsDir :=
                    Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`getStreamableSnippetsDir[ ],
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$pacletStreamableSnippetsDirectory = dir,
                Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$localStreamableSnippetsDirectory  = dir
            },
            noDownloads @ Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`initializeStreamableSnippets[ ]
        ];
        { result, FileNames[ All, dir, Infinity ], DeleteDirectory[ dir, DeleteContents -> True ] }
    ],
    { Missing[ "DownloadDisabled" ], { }, Null },
    SameTest -> MatchQ,
    TestID   -> "InitializeStreamableSnippets-NoDownload@@Tests/WorkspaceChatInitialization.wlt:307,1-325,2"
]

(* :!CodeAnalysis::EndBlock:: *)
