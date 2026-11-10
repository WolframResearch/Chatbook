(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/VectorDatabases.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/VectorDatabases.wlt:11,1-16,2"
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

(* The loaded database that searches are given, and its VectorDatabaseObject (which searches only create when they
   need VectorDatabaseSearch): *)
vectorDBInfo[ name_String ] :=
    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getVectorDB @ name;

vectorDBObject[ name_String ] :=
    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseObject[ name, vectorDBInfo @ name ];

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
    TestID   -> "FastVectorSearch-Functions@@Tests/VectorDatabases.wlt:60,1-71,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Same Results as VectorDatabaseSearch*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$saveUSearchVerifications = False,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>
        },
        Module[ { vectors, results },
            vectors = Wolfram`Chatbook`Common`getEmbeddings @ $vectorSearchQueries;
            results = AssociationMap[
                Function[ name,
                    With[
                        {
                            db = vectorDBObject @ name
                        },
                        (* The first search with each database verifies the index handle: *)
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                            name,
                            vectorDBInfo @ name,
                            First @ vectors,
                            250
                        ];
                        Union @ Flatten @ Table[
                            SameQ[
                                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                                    name,
                                    vectorDBInfo @ name,
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
    TestID   -> "FastVectorSearch-MatchesVectorDatabaseSearch@@Tests/VectorDatabases.wlt:76,1-139,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$saveUSearchVerifications = False,
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
    TestID   -> "FastVectorSearch-RelatedDocumentation-Results@@Tests/VectorDatabases.wlt:141,1-216,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fallback*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$saveUSearchVerifications = False,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>,
            (* Simulate a fast search that disagrees with VectorDatabaseSearch: *)
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexSearch =
                Function[ { <| "Index" -> 1, "Distance" -> 0.0 |> } ]
        },
        With[
            {
                db     = vectorDBObject @ "NeuralNetRepositoryURIs",
                vector = Wolfram`Chatbook`Common`getEmbedding[ "Is there a neural net that can classify images?" ]
            },
            {
                SameQ[
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                        "NeuralNetRepositoryURIs",
                        vectorDBInfo @ "NeuralNetRepositoryURIs",
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
                        vectorDBInfo @ "NeuralNetRepositoryURIs",
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
    TestID   -> "FastVectorSearch-MismatchFallback@@Tests/VectorDatabases.wlt:221,1-279,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$saveUSearchVerifications = False,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>
        },
        With[
            {
                db     = vectorDBObject @ "NeuralNetRepositoryURIs",
                vector = Wolfram`Chatbook`Common`getEmbedding[ "Is there a neural net that can classify images?" ]
            },
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                "NeuralNetRepositoryURIs",
                vectorDBInfo @ "NeuralNetRepositoryURIs",
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
                            vectorDBInfo @ "NeuralNetRepositoryURIs",
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
    TestID   -> "FastVectorSearch-ErrorFallback@@Tests/VectorDatabases.wlt:281,1-334,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$saveUSearchVerifications = False,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>,
            (* Simulate a SemanticSearch version without the internal functions that the fast path relies on: *)
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchFunctions = Missing[ "NotAvailable" ]
        },
        With[
            {
                db     = vectorDBObject @ "NeuralNetRepositoryURIs",
                vector = Wolfram`Chatbook`Common`getEmbedding[ "Is there a neural net that can classify images?" ]
            },
            {
                SameQ[
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                        "NeuralNetRepositoryURIs",
                        vectorDBInfo @ "NeuralNetRepositoryURIs",
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
    TestID   -> "FastVectorSearch-FeatureDetectionFallback@@Tests/VectorDatabases.wlt:336,1-373,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$saveUSearchVerifications = False,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>
        },
        With[
            {
                db     = vectorDBObject @ "NeuralNetRepositoryURIs",
                vector = Wolfram`Chatbook`Common`getEmbedding[ "Is there a neural net that can classify images?" ]
            },
            {
                Block[ { Wolfram`Chatbook`Common`$mxFlag = True },
                    SameQ[
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                            "NeuralNetRepositoryURIs",
                            vectorDBInfo @ "NeuralNetRepositoryURIs",
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
                            vectorDBInfo @ "NeuralNetRepositoryURIs",
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
    TestID   -> "FastVectorSearch-Disabled@@Tests/VectorDatabases.wlt:375,1-427,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$saveUSearchVerifications = False,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>
        },
        Module[ { evaluated = False, handle },
            handle = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getUSearchIndex[
                "NeuralNetRepositoryURIs",
                vectorDBInfo @ "NeuralNetRepositoryURIs"
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
    TestID   -> "FastVectorSearch-DisableReason@@Tests/VectorDatabases.wlt:429,1-468,2"
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
    TestID   -> "FastVectorSearch-CatchUSearch@@Tests/VectorDatabases.wlt:470,1-488,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Index Handles*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$saveUSearchVerifications = False,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>
        },
        Module[ { db, index, stale, new },
            db = vectorDBObject @ "NeuralNetRepositoryURIs";
            index = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getUSearchIndex[
                "NeuralNetRepositoryURIs",
                vectorDBInfo @ "NeuralNetRepositoryURIs"
            ];
            (* Simulate a database file that was replaced after the handle was created: *)
            stale = <| index, "FileDate" -> DateObject[ { 2000, 1, 1, 0, 0, 0 } ] |>;
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache[ "NeuralNetRepositoryURIs" ] = stale;
            new = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getUSearchIndex[
                "NeuralNetRepositoryURIs",
                vectorDBInfo @ "NeuralNetRepositoryURIs"
            ];
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexValidQ[ index, vectorDBInfo @ "NeuralNetRepositoryURIs" ],
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexValidQ[ stale, vectorDBInfo @ "NeuralNetRepositoryURIs" ],
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexValidQ[ index, None ],
                new[ "FileDate" ] === FileDate @ index[ "File" ],
                new[ "Handle" ] =!= index[ "Handle" ]
            }
        ]
    ],
    { True, False, False, True, True },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-Invalidation@@Tests/VectorDatabases.wlt:493,1-526,2"
]

(* Handles must be released before unpacking, since memory-mapped files cannot be replaced on Windows: *)
VerificationTest[
    Module[ { name, info, root, dir, file, zip, result },
        name = "NeuralNetRepositoryURIs";
        info = vectorDBInfo @ name;
        root = CreateDirectory[ ];
        dir  = CreateDirectory @ FileNameJoin @ { root, name };

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
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$saveUSearchVerifications = False,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures = <| |>
            },
            {
                (* Open the index from the temporary copy instead of the installed database: *)
                SameQ[
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getUSearchIndex[
                        name,
                        <| info, "Metadata" -> <| info[ "Metadata" ], "VectorDatabase" -> File @ file |> |>
                    ][ "File" ],
                    file
                ],
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`unpackVectorDatabase @ zip,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures,
                FileExistsQ @ zip
            }
        ];

        { result, DeleteDirectory[ root, DeleteContents -> True ] }
    ],
    (* unpackVectorDatabase gives the installed directory since it swaps in a validated staging directory: *)
    { { True, _String, <| |>, <| |>, False }, Null },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-ReleaseBeforeUnpack@@Tests/VectorDatabases.wlt:529,1-576,2"
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
    TestID   -> "FastVectorSearch-IdleRelease@@Tests/VectorDatabases.wlt:581,1-617,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache       = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$saveUSearchVerifications = False,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures    = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexLastUsed    = 0,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexReleaseTask = None,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexIdleTime    = 0.25
        },
        With[
            {
                db     = vectorDBObject @ "NeuralNetRepositoryURIs",
                vector = Wolfram`Chatbook`Common`getEmbedding[ "Is there a neural net that can classify images?" ]
            },
            Module[ { search, before, after, again },
                search = Function[
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[
                        "NeuralNetRepositoryURIs",
                        vectorDBInfo @ "NeuralNetRepositoryURIs",
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
    TestID   -> "FastVectorSearch-IdleRelease-Task@@Tests/VectorDatabases.wlt:619,1-676,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Saved Verifications*)

(* An index file that was verified in an earlier session is searched without VectorDatabaseSearch, and without creating
   the VectorDatabaseObject. Each `session` starts without index handles, verified indexes and database objects. *)
VerificationTest[
    Module[ { name, dir, vector, standardSearches, session, first, later, otherVersion },
        name   = "NeuralNetRepositoryURIs";
        dir    = CreateDirectory[ ];
        vector = Wolfram`Chatbook`Common`getEmbedding[ "Is there a neural net that can classify images?" ];

        standardSearches = 0;

        session = Function[
            Block[
                {
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache         = <| |>,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified      = <| |>,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures      = <| |>,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDatabaseObjects     = <| |>,
                    Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$savedUSearchVerifications = None
                },
                <|
                    "Result"   -> Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[ name, vectorDBInfo @ name, vector, 250 ],
                    "Searches" -> standardSearches,
                    "Objects"  -> Keys @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDatabaseObjects,
                    "Saved"    -> Length @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`savedUSearchVerifications[ ],
                    "Failures" -> Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures
                |>
            ]
        ];

        Block[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$saveUSearchVerifications = True,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchVerificationsFile = FileNameJoin @ { dir, "VerifiedIndexes.wxf" }
            },
            Internal`InheritedBlock[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`standardVectorDatabaseSearch },
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`standardVectorDatabaseSearch[ db_, v_, n_ ] /; ! TrueQ @ $inStandardSearch :=
                    Block[ { $inStandardSearch = True },
                        standardSearches++;
                        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`standardVectorDatabaseSearch[ db, v, n ]
                    ];

                first = session[ ];
                later = session[ ];

                (* Saved verifications are only valid for the same version of SemanticSearch: *)
                otherVersion = Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$semanticSearchVersion = "0.0.0" }, session[ ] ];
            ]
        ];

        DeleteDirectory[ dir, DeleteContents -> True ];

        {
            KeyDrop[ first, "Result" ],
            KeyDrop[ later, "Result" ],
            KeyDrop[ otherVersion, "Result" ],
            MatchQ[ first[ "Result" ], { __Association } ],
            first[ "Result" ] === later[ "Result" ] === otherVersion[ "Result" ]
        }
    ],
    {
        <| "Searches" -> 1, "Objects" -> { "NeuralNetRepositoryURIs" }, "Saved" -> 1, "Failures" -> <| |> |>,
        <| "Searches" -> 1, "Objects" -> { }, "Saved" -> 1, "Failures" -> <| |> |>,
        <| "Searches" -> 2, "Objects" -> { "NeuralNetRepositoryURIs" }, "Saved" -> 2, "Failures" -> <| |> |>,
        True,
        True
    },
    TestID -> "FastVectorSearch-SavedVerification@@Tests/VectorDatabases.wlt:684,1-749,2"
]

(* A search that disagrees with VectorDatabaseSearch is not saved as verified: *)
VerificationTest[
    Module[ { name, dir, vector, result },
        name   = "NeuralNetRepositoryURIs";
        dir    = CreateDirectory[ ];
        vector = Wolfram`Chatbook`Common`getEmbedding[ "Is there a neural net that can classify images?" ];

        result = Block[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache         = <| |>,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified      = <| |>,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures      = <| |>,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$savedUSearchVerifications = None,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$saveUSearchVerifications  = True,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchVerificationsFile  = FileNameJoin @ { dir, "VerifiedIndexes.wxf" },
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchIndexSearch         = Function[ { <| "Index" -> 1, "Distance" -> 0.0 |> } ]
            },
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[ name, vectorDBInfo @ name, vector, 250 ];
            { Keys @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`savedUSearchVerifications[ ], FileNames[ All, dir ] }
        ];

        DeleteDirectory[ dir, DeleteContents -> True ];
        result
    ],
    { { "NeuralNetRepositoryURIs" }, { }, { } },
    TestID -> "FastVectorSearch-SavedVerification-Mismatch@@Tests/VectorDatabases.wlt:752,1-777,2"
]

(* Only the newest saved verifications are kept: *)
VerificationTest[
    Module[ { dir, saved },
        dir = CreateDirectory[ ];
        saved = Block[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$saveUSearchVerifications     = True,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$maxSavedUSearchVerifications = 3,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$savedUSearchVerifications    = None,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchVerificationsFile     = FileNameJoin @ { dir, "VerifiedIndexes.wxf" },
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchVerificationHash       = Function[ #[ "Hash" ] ]
            },
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`saveUSearchVerification[ <| "Hash" -> # |> ] & /@ Range[ 5 ];
            { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`savedUSearchVerifications[ ], Developer`ReadWXFFile @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchVerificationsFile }
        ];
        DeleteDirectory[ dir, DeleteContents -> True ];
        saved
    ],
    { { 5, 4, 3 }, { 5, 4, 3 } },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-SavedVerification-NewestKept@@Tests/VectorDatabases.wlt:780,1-800,2"
]

(* Saved verifications don't depend on the time zone of the session (which changes with daylight saving time): *)
VerificationTest[
    Module[ { file, date, hash, result },
        file   = Export[ FileNameJoin @ { $TemporaryDirectory, CreateUUID[ ] <> ".txt" }, "test", "String" ];
        date   = FileDate @ file;
        hash   = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`usearchVerificationHash @ <| "File" -> file, "FileDate" -> TimeZoneConvert[ date, # ] |> &;
        result = hash[ -5 ] === hash[ -4 ];
        DeleteFile @ file;
        result
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-SavedVerification-TimeZone@@Tests/VectorDatabases.wlt:803,1-815,2"
]

(* A database whose VectorDatabaseObject can't be created when a search needs it is skipped like one that can't be loaded,
   instead of failing the chat. The warm-up leaves this to the next search, which shows the message: *)
VerificationTest[
    Module[ { name, vector },
        name   = "NeuralNetRepositoryURIs";
        vector = Wolfram`Chatbook`Common`getEmbedding[ "Is there a neural net that can classify images?" ];
        Block[
            {
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexCache        = <| |>,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexVerified     = <| |>,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$usearchIndexFailures     = <| |>,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDatabaseObjects    = <| |>,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBLoadFailures     = { },
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$saveUSearchVerifications = False,
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`loadVectorDatabase        = Function[
                    Enclose[ ConfirmMatch[ $Failed, _VectorDatabaseObject, "Database" ], Wolfram`Chatbook`Common`throwInternalFailure ]
                ]
            },
            {
                Block[ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$allowDownload = False }, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[ name, vectorDBInfo @ name, vector, 250 ] ],
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBLoadFailures,
                Wolfram`Chatbook`Common`catchTop @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDatabaseSearch[ name, vectorDBInfo @ name, vector, 250 ],
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBLoadFailures,
                vectorDBInfo @ name
            }
        ]
    ],
    { { }, { }, { }, { "NeuralNetRepositoryURIs" }, Missing[ "LoadFailed", "NeuralNetRepositoryURIs" ] },
    { Chatbook::VectorDatabaseLoadFailed },
    SameTest -> MatchQ,
    TestID   -> "FastVectorSearch-DatabaseObjectFailed@@Tests/VectorDatabases.wlt:819,1-848,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Value Stores*)
VerificationTest[
    Module[ { values, store },
        values = { "paclet:ref/Plot#1", "", "\[Alpha]\[Beta] \[LongRightArrow] x", "a", "", "https://example.com/#2" };
        store  = Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`makeValueStore @ values;
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBValuesList @ store === values,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBValueCount @ store,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBValuesPart[ store, { 3, 1, 6, 2, 3 } ] === values[[ { 3, 1, 6, 2, 3 } ]],
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBValuesPart[ store, { } ],
            (* Lists of values (e.g. of registered databases) work the same way: *)
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBValuesPart[ values, { 4, 1 } ],
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBValueCount @ values,
            (* The offsets of a new store are packed (like the ones read from a saved store): *)
            Developer`PackedArrayQ @ store[ "Offsets" ]
        }
    ],
    { True, 6, True, { }, { "a", "paclet:ref/Plot#1" }, 6, True },
    TestID -> "ValueStore-SameValues@@Tests/VectorDatabases.wlt:853,1-871,2"
]

(* The value store of an installed database gives the values of its Values.wxf: *)
VerificationTest[
    Module[ { name, file, store, indices },
        name    = "NeuralNetRepositoryURIs";
        file    = FileNameJoin @ { Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDirectory, name, "Values.wxf" };
        store   = vectorDBInfo[ name ][ "Values" ];
        indices = { 1, 10, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBValueCount @ store };
        {
            ! Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`localVectorDBDirectoryQ @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBDirectory || MatchQ[ store, KeyValuePattern[ "String" -> _String ] ],
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBValuesPart[ store, indices ] === Developer`ReadWXFFile[ file ][[ indices ]],
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBValuesList @ store === Developer`ReadWXFFile @ file
        }
    ],
    { True, True, True },
    TestID -> "ValueStore-InstalledDatabase@@Tests/VectorDatabases.wlt:874,1-888,2"
]

(* The saved value store is used while Values.wxf is unchanged, and ignored otherwise: *)
VerificationTest[
    Module[ { dir, file, cache, write, load, first, saved, cached, changed, damaged },
        dir   = CreateDirectory[ ];
        file  = FileNameJoin @ { dir, "Values.wxf" };
        cache = FileNameJoin @ { dir, "ValueStore.wxf" };
        write = Function[ Developer`WriteWXFFile[ file, # ] ];
        load  = Function[ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBValuesList @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`loadValueStore @ file ];

        write @ { "a", "bb", "ccc" };
        first = load[ ];
        saved = FileExistsQ @ cache;

        (* Values that could only come from the saved value store: *)
        Developer`WriteWXFFile[ cache, <| Developer`ReadWXFFile @ cache, "String" -> "xyyzzz" |> ];
        cached = load[ ];

        (* Values.wxf was replaced: *)
        write @ { "dddd", "e" };
        changed = { load[ ], Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`vectorDBValuesList @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`readValueStore @ file };

        (* The saved value store can't be read: *)
        BinaryWrite[ cache, { 1, 2, 3 } ]; Close @ cache;
        damaged = load[ ];

        DeleteDirectory[ dir, DeleteContents -> True ];
        { first, saved, cached, changed, damaged }
    ],
    {
        { "a", "bb", "ccc" },
        True,
        { "x", "yy", "zzz" },
        { { "dddd", "e" }, { "dddd", "e" } },
        { "dddd", "e" }
    },
    TestID -> "ValueStore-SavedFile@@Tests/VectorDatabases.wlt:891,1-926,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*All Values*)
(* The full list of values of a database (e.g. for RelatedWolframAlphaQueries[ All ]): *)
VerificationTest[
    Wolfram`Chatbook`PromptGenerators`Common`vectorDBSearch[ "NeuralNetRepositoryURIs", All, "Values" ],
    { __String },
    SameTest -> MatchQ,
    TestID   -> "VectorDBSearch-AllValues-GH#1612@@Tests/VectorDatabases.wlt:932,1-937,2"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`Common`vectorDBSearch[
        { "NeuralNetRepositoryURIs", "PacletRepositoryURIs" },
        All,
        "Values"
    ],
    { __String },
    SameTest -> MatchQ,
    TestID   -> "VectorDBSearch-AllValues-Multiple-GH#1612@@Tests/VectorDatabases.wlt:939,1-948,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SentenceBERT Tokenizer*)
(* ResourceSystemClient does not cache the tokenizer that SentenceBERTEmbedding uses, so embeddings would download it
   again in every session. Computing an embedding caches it (see cacheSentenceBERTTokenizer): *)
VerificationTest[
    Wolfram`Chatbook`Common`getEmbeddings[ { "Hello" } ];
    NeuralNetworks`LocalNetModel[ "MiniLM V2 Reranker Trained on MS MARCO Data", "Tokenizer" ],
    _NetEncoder,
    SameTest -> MatchQ,
    TestID   -> "SentenceBERTTokenizerCached@@Tests/VectorDatabases.wlt:955,1-961,2"
]

(* :!CodeAnalysis::EndBlock:: *)
