(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* Initialization never downloads anything, so make sure the resources it loads are installed: *)
VerificationTest[
    InstallVectorDatabases[ ],
    _Success,
    SameTest -> MatchQ,
    TestID   -> "InstallVectorDatabases"
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
    TestID   -> "InitializeWorkspaceChat"
]

VerificationTest[
    Wolfram`Chatbook`ChatModes`UI`Private`$workspaceChatInitialized,
    True,
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChat-Initialized"
]

VerificationTest[
    NumericArrayQ @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$embeddingCache[ "Hello" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChat-Embeddings"
]

(* Token counts are estimated, so the tokenizer (which takes about a second to load) is not needed. Tests that ran earlier
   in the same kernel may have loaded it, so it is removed from the cache while initializing again: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$cachedTokenizers =
                KeyDrop[ Wolfram`Chatbook`Common`$cachedTokenizers, "gpt-4o-text" ]
        },
        Wolfram`Chatbook`ChatModes`UI`Private`initializeWorkspaceChat[ ];
        KeyExistsQ[ Wolfram`Chatbook`Common`$cachedTokenizers, "gpt-4o-text" ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChat-Tokenizer"
]

(* getVectorDB keeps the loaded databases in $loadedVectorDBs (together with the index fingerprint that it checks): *)
VerificationTest[
    AllTrue[
        $expectedVectorDBNames,
        KeyExistsQ[ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$loadedVectorDBs, # ] &
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChat-VectorDatabases"
]

VerificationTest[
    AllTrue[
        $expectedVectorDBNames,
        memoizedQ[ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`loadVectorDBValues, # ] &
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChat-VectorDatabaseValues"
]

(* The first search of a chat needs the index handle of each database it searches, already checked against
   VectorDatabaseSearch: *)
VerificationTest[
    AllTrue[
        $expectedVectorDBNames,
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexVerifiedQ @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache[ # ] &
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChat-VectorDatabaseIndexHandles"
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
    TestID   -> "InitializeWorkspaceChat-SnippetIndexes"
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
    TestID   -> "InitializeWorkspaceChat-FailureIsolation"
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
    TestID   -> "InitializationStep-Failure"
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
    TestID   -> "InitializationStep-ChatState"
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
    TestID   -> "InitializationStep-AsynchronousChatState"
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
    TestID   -> "WithIsolatedChatState-RestoresChatState"
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
    TestID   -> "InitializeWorkspaceChatSettings"
]

VerificationTest[
    Block[ { $CloudUserID = None },
        Wolfram`Chatbook`ChatModes`UI`Private`initializeWorkspaceChatSettings[ ]
    ],
    Missing[ "NotAuthenticated" ],
    SameTest -> MatchQ,
    TestID   -> "InitializeWorkspaceChatSettings-NotAuthenticated"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*initializeRelatedDocumentation*)
VerificationTest[
    Wolfram`Chatbook`Common`initializeRelatedDocumentation[ None ],
    <|
        "VectorDatabases" -> $expectedVectorDBNames,
        "SnippetIndexes"  -> <|
            "Documentation"  -> _Integer? Positive,
            "ResourceSystem" -> _Integer? Positive,
            "Descriptions"   -> _Integer? Positive
        |>
    |>,
    SameTest -> MatchQ,
    TestID   -> "InitializeRelatedDocumentation"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`initializationVectorDBNames[ None ],
    $expectedVectorDBNames,
    SameTest -> MatchQ,
    TestID   -> "InitializationVectorDBNames"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`initializationVectorDBNames @
        Wolfram`Chatbook`Common`resolvePromptGenerators @ <|
            "ExperimentalFeatures" -> { },
            "PromptGenerators"     -> { "RelatedDocumentation", "RelatedWolframAlphaResults" }
        |>,
    Append[ $expectedVectorDBNames, "WolframAlphaQueries" ],
    SameTest -> MatchQ,
    TestID   -> "InitializationVectorDBNames-WolframAlpha"
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
    TestID   -> "InitializeVectorDatabases-NoDownload"
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
    TestID   -> "InitializeStreamableSnippets-NoDownload"
]

(* :!CodeAnalysis::EndBlock:: *)
