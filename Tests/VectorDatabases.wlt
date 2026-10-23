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

(* These tests check that the persistent USearch index handles used by vectorDatabaseSearch give exactly the same
   results as VectorDatabaseSearch, and that the fast path falls back to VectorDatabaseSearch when anything goes wrong. *)

$vectorDatabaseNames = {
    "SourceSelector",
    "DocumentationURIs",
    "FunctionRepositoryURIs",
    "EntityValues",
    "DataRepositoryURIs",
    "NeuralNetRepositoryURIs",
    "PacletRepositoryURIs",
    "WolframAlphaQueries"
};

$vectorSearchQueries = {
    "How do I make a 3D plot of a surface?",
    "What is the population of France?",
    "Show me a map of meteorite impacts",
    "Is there a neural net that can classify images?",
    "How do I use PacletSymbol with a paclet from the paclet repository?",
    "Which function repository function can parse a date range?",
    "x"
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Fast Vector Search*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Feature Detection*)
VerificationTest[
    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchFunctions,
    KeyValuePattern @ {
        "deserializeIndex"     -> _Symbol,
        "IndexGetVectors"      -> _Symbol,
        "IndexSearch"          -> _Symbol,
        "RetrieveFromDatabase" -> _Symbol,
        "ToNumericArray"       -> _Symbol
    },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-Functions"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Same Results as VectorDatabaseSearch*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>
        },
        Module[ { vectors, results },
            vectors = Wolfram`Chatbook`Common`getEmbeddings @ $vectorSearchQueries;
            results = AssociationMap[
                Function[ name,
                    With[
                        {
                            db = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB[ name ][
                                "VectorDatabaseObject"
                            ]
                        },
                        (* The first search with each database verifies the index handle: *)
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                            name,
                            db,
                            First @ vectors,
                            250
                        ];
                        Union @ Flatten @ Table[
                            SameQ[
                                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                                    name,
                                    db,
                                    vector,
                                    n
                                ],
                                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`standardVectorDatabaseSearch[
                                    db,
                                    vector,
                                    n
                                ]
                            ],
                            { n, { 250, 100, 20 } },
                            { vector, vectors }
                        ]
                    ]
                ],
                $vectorDatabaseNames
            ];
            <|
                "Results"  -> results,
                "Handles"  -> Sort @ Keys @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache,
                "Verified" -> AllTrue[
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexVerifiedQ
                ],
                "Failures" -> Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures
            |>
        ]
    ],
    <|
        "Results"  -> AssociationMap[ { True } &, $vectorDatabaseNames ],
        "Handles"  -> Sort @ $vectorDatabaseNames,
        "Verified" -> True,
        "Failures" -> <| |>
    |>,
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-MatchesVectorDatabaseSearch"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>
        },
        Module[ { prompts, results, fast1, fast2, standard },
            prompts = {
                "How do I make a 3D plot of a surface?",
                "Show me a map of meteorite impacts",
                {
                    <| "Role" -> "User"     , "Content" -> "What's the 123456789th prime?"  |>,
                    <| "Role" -> "Assistant", "Content" -> "```wl\nPrime[123456789]\n```"   |>,
                    <| "Role" -> "User"     , "Content" -> "What about the one after that?" |>
                }
            };

            results = Function[ fast,
                Block[
                    {
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$cacheUSearchIndexes = fast,
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBSearchCache = <| |>
                    },
                    Join[
                        RelatedDocumentation[ #, "Results", 50 ] & /@ prompts,
                        (* Conversation, last message, and selection strings: *)
                        Block[
                            {
                                Wolfram`Chatbook`Common`$contextPrompt   = "```wl\nIn[1]:= Prime[123456789]\n```",
                                Wolfram`Chatbook`Common`$selectionPrompt = "Prime[123456789]"
                            },
                            {
                                RelatedDocumentation[
                                    {
                                        <| "Role" -> "User"     , "Content" -> "How do I plot a sine wave?" |>,
                                        <| "Role" -> "Assistant", "Content" -> "Use `Plot`."                |>,
                                        <| "Role" -> "User"     , "Content" -> "What does this do?"         |>
                                    },
                                    "Results",
                                    50
                                ]
                            }
                        ]
                    ]
                ]
            ];

            (* The first run verifies each index handle, so the second one uses the fast path: *)
            fast1    = results[ True  ];
            fast2    = results[ True  ];
            standard = results[ False ];

            <|
                "Identical" -> fast1 === fast2 === standard,
                "Lengths"   -> Length /@ standard,
                "Verified"  -> AllTrue[
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexVerifiedQ
                ],
                "Handles"   -> Length @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache,
                "Failures"  -> Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures
            |>
        ]
    ],
    <|
        "Identical" -> True,
        "Lengths"   -> { 50, 50, 50, 50 },
        "Verified"  -> True,
        "Handles"   -> _Integer? (GreaterEqualThan[ 2 ]),
        "Failures"  -> <| |>
    |>,
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-RelatedDocumentation-Results"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fallback*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>,
            (* Simulate a fast search that disagrees with VectorDatabaseSearch: *)
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexSearch =
                Function[ { <| "Index" -> 1, "Distance" -> 0.0 |> } ]
        },
        With[
            {
                db     = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB[ "NeuralNetRepositoryURIs" ][
                    "VectorDatabaseObject"
                ],
                vector = Wolfram`Chatbook`Common`getEmbedding[ "Is there a neural net that can classify images?" ]
            },
            {
                SameQ[
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                        "NeuralNetRepositoryURIs",
                        db,
                        vector,
                        250
                    ],
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`standardVectorDatabaseSearch[
                        db,
                        vector,
                        250
                    ]
                ],
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache,
                SameQ[
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                        "NeuralNetRepositoryURIs",
                        db,
                        vector,
                        100
                    ],
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`standardVectorDatabaseSearch[
                        db,
                        vector,
                        100
                    ]
                ],
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache
            }
        ]
    ],
    {
        True,
        <| "NeuralNetRepositoryURIs" -> Failure[ "USearchIndexMismatch", _ ] |>,
        <| |>,
        True,
        <| |>
    },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-MismatchFallback"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>
        },
        With[
            {
                db     = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB[ "NeuralNetRepositoryURIs" ][
                    "VectorDatabaseObject"
                ],
                vector = Wolfram`Chatbook`Common`getEmbedding[ "Is there a neural net that can classify images?" ]
            },
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                "NeuralNetRepositoryURIs",
                db,
                vector,
                250
            ];
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexVerifiedQ[
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache[
                        "NeuralNetRepositoryURIs"
                    ]
                ],
                (* An error from a verified index handle: *)
                Block[
                    {
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexSearch =
                            Function[ Failure[ "Test", <| |> ] ]
                    },
                    SameQ[
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                            "NeuralNetRepositoryURIs",
                            db,
                            vector,
                            100
                        ],
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`standardVectorDatabaseSearch[
                            db,
                            vector,
                            100
                        ]
                    ]
                ],
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache
            }
        ]
    ],
    { True, True, <| "NeuralNetRepositoryURIs" -> Failure[ "Test", _ ] |>, <| |> },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-ErrorFallback"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>,
            (* Simulate a SemanticSearch version without the internal functions that the fast path relies on: *)
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchFunctions = Missing[ "NotAvailable" ]
        },
        With[
            {
                db     = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB[ "NeuralNetRepositoryURIs" ][
                    "VectorDatabaseObject"
                ],
                vector = Wolfram`Chatbook`Common`getEmbedding[ "Is there a neural net that can classify images?" ]
            },
            {
                SameQ[
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                        "NeuralNetRepositoryURIs",
                        db,
                        vector,
                        250
                    ],
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`standardVectorDatabaseSearch[
                        db,
                        vector,
                        250
                    ]
                ],
                Keys @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache
            }
        ]
    ],
    { True, { "NeuralNetRepositoryURIs" }, <| |> },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-FeatureDetectionFallback"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>
        },
        With[
            {
                db     = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB[ "NeuralNetRepositoryURIs" ][
                    "VectorDatabaseObject"
                ],
                vector = Wolfram`Chatbook`Common`getEmbedding[ "Is there a neural net that can classify images?" ]
            },
            {
                Block[ { Wolfram`Chatbook`Common`$mxFlag = True },
                    SameQ[
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                            "NeuralNetRepositoryURIs",
                            db,
                            vector,
                            250
                        ],
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`standardVectorDatabaseSearch[
                            db,
                            vector,
                            250
                        ]
                    ]
                ],
                Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$cacheUSearchIndexes = False },
                    SameQ[
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                            "NeuralNetRepositoryURIs",
                            db,
                            vector,
                            250
                        ],
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`standardVectorDatabaseSearch[
                            db,
                            vector,
                            250
                        ]
                    ]
                ],
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures
            }
        ]
    ],
    { True, True, <| |>, <| |> },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-Disabled"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>
        },
        Module[ { evaluated = False, handle },
            handle = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getUSearchIndex[
                "NeuralNetRepositoryURIs",
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB[ "NeuralNetRepositoryURIs" ][
                    "VectorDatabaseObject"
                ]
            ][ "Handle" ];
            (* Failure reasons must not keep index handles, and held code in them must not be evaluated: *)
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`disableUSearchIndex[
                "NeuralNetRepositoryURIs",
                Failure[ "Test", <| "Handle" -> handle, "HeldTest" -> Hold[ evaluated = True ] |> ]
            ];
            {
                ManagedLibraryExpressionQ @ handle,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache,
                evaluated
            }
        ]
    ],
    {
        True,
        <|
            "NeuralNetRepositoryURIs" -> Failure[
                "Test",
                <| "Handle" -> Missing[ "Released" ], "HeldTest" -> Hold[ _Set ] |>
            ]
        |>,
        <| |>,
        False
    },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-DisableReason"
]

VerificationTest[
    {
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`catchUSearch[
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchFunctions[ "ToNumericArray" ][
                { "a", "b" },
                "Integer8"
            ]
        ],
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`catchUSearch[
            Throw[ "test", "SemanticSearchException" ]
        ]
    },
    {
        _Failure,
        Failure[ "USearchException", KeyValuePattern @ { "Value" -> "test", "Tag" -> "SemanticSearchException" } ]
    },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-CatchUSearch"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Index Handles*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>
        },
        Module[ { db, index, stale, new },
            db = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB[ "NeuralNetRepositoryURIs" ][
                "VectorDatabaseObject"
            ];
            index = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getUSearchIndex[
                "NeuralNetRepositoryURIs",
                db
            ];
            (* Simulate a database file that was replaced after the handle was created: *)
            stale = <| index, "FileDate" -> DateObject[ { 2000, 1, 1, 0, 0, 0 } ] |>;
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache[ "NeuralNetRepositoryURIs" ] = stale;
            new = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getUSearchIndex[
                "NeuralNetRepositoryURIs",
                db
            ];
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexValidQ[ index, db ],
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexValidQ[ stale, db ],
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexValidQ[ index, None ],
                new[ "FileDate" ] === FileDate @ index[ "File" ],
                new[ "Handle" ] =!= index[ "Handle" ]
            }
        ]
    ],
    { True, False, False, True, True },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-Invalidation"
]

(* Handles must be released before unpacking, since memory-mapped files cannot be replaced on Windows: *)
VerificationTest[
    Module[ { name, db, functions, root, dir, file, zip, result },
        name      = "NeuralNetRepositoryURIs";
        db        = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB[ name ][ "VectorDatabaseObject" ];
        functions = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchFunctions;
        root      = CreateDirectory[ ];
        dir       = CreateDirectory @ FileNameJoin @ { root, name };

        Scan[
            CopyFile[ #, FileNameJoin @ { dir, FileNameTake @ # } ] &,
            FileNames[
                "*",
                FileNameJoin @ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDirectory, name }
            ]
        ];

        file = FileNameJoin @ { dir, name <> "-vectors.usearch" };
        zip  = CreateArchive[ FileNames[ "*", dir ], FileNameJoin @ { root, name <> ".zip" } ];

        result = Block[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>,
                (* Open the index from the temporary copy instead of the installed database: *)
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchFunctions = <|
                    functions,
                    "RetrieveFromDatabase" -> Function[
                        <| functions[ "RetrieveFromDatabase" ][ ##1 ], "VectorDatabase" -> File @ file |>
                    ]
                |>
            },
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getUSearchIndex[ name, db ][ "File" ] === file,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`unpackVectorDatabase @ zip,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures,
                FileExistsQ @ zip
            }
        ];

        { result, DeleteDirectory[ root, DeleteContents -> True ] }
    ],
    { { True, { __String }, <| |>, <| |>, False }, Null },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-ReleaseBeforeUnpack"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Idle Release*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache       = <| "Test" -> <| |> |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexLastUsed    = 0,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexReleaseTask = None,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexIdleTime    = 300
        },
        Module[ { scheduled, recent, idle },

            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`touchUSearchIndex[ <| |> ];
            scheduled = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexReleaseTask;
            TaskRemove @ scheduled;

            (* Used recently, so the handles are kept and the check is rescheduled: *)
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`releaseIdleUSearchIndexes[ ];
            recent = {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexReleaseTask
            };
            TaskRemove @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexReleaseTask;

            (* Not used for longer than $usearchIndexIdleTime, so the handles are released: *)
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexLastUsed = AbsoluteTime[ ] - 301;
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`releaseIdleUSearchIndexes[ ];
            idle = {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexReleaseTask
            };

            { scheduled, recent, idle }
        ]
    ],
    { _TaskObject, { <| "Test" -> <| |> |>, _TaskObject }, { <| |>, None } },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-IdleRelease"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache       = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexLastUsed    = 0,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexReleaseTask = None,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexIdleTime    = 0.25
        },
        With[
            {
                db     = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB[ "NeuralNetRepositoryURIs" ][
                    "VectorDatabaseObject"
                ],
                vector = Wolfram`Chatbook`Common`getEmbedding[ "Is there a neural net that can classify images?" ]
            },
            Module[ { search, before, after, again },
                search = Function[
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                        "NeuralNetRepositoryURIs",
                        db,
                        vector,
                        250
                    ]
                ];
                search[ ];
                before = Keys @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache;
                (* Scheduled tasks run while the kernel is paused: *)
                Pause[ 2 ];
                after = Keys @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache;
                (* A released handle is reopened on the next search and does not need to be verified again: *)
                again = {
                    search[ ] === Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`standardVectorDatabaseSearch[
                        db,
                        vector,
                        250
                    ],
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexVerifiedQ[
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache[
                            "NeuralNetRepositoryURIs"
                        ]
                    ]
                };
                Quiet @ TaskRemove @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexReleaseTask;
                {
                    before,
                    after,
                    again,
                    Length @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures
                }
            ]
        ]
    ],
    { { "NeuralNetRepositoryURIs" }, { }, { True, True }, 1, <| |> },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-IdleRelease-Task"
]

(* :!CodeAnalysis::EndBlock:: *)
