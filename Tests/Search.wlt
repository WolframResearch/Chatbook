(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Search.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Search.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Test Definitions*)
VerificationTest[
    $testApps = { "ChatbookSearchCacheTest", "ChatbookSearchCacheTest2" };
    $testApp  = First @ $testApps;

    (* Remove everything the tests write to disk or to the in-memory index: *)
    cleanupSearchTests // ClearAll;
    cleanupSearchTests[ ] := (
        Scan[
            Function[
                Quiet @ DeleteDirectory[
                    ChatbookFilesDirectory[ #, "EnsureDirectory" -> False ],
                    DeleteContents -> True
                ]
            ],
            Join[ { "Search", # } & /@ $testApps, { "SavedChats", # } & /@ $testApps ]
        ];
        If[ AssociationQ @ Wolfram`Chatbook`Search`Private`$chatSearchIndex,
            KeyDropFrom[ Wolfram`Chatbook`Search`Private`$chatSearchIndex, $testApps ]
        ];
        Wolfram`Chatbook`Search`Private`$chatSearchData = <| |>;
        KeyDropFrom[ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$embeddingCache, $queries ];
    );

    SeedRandom[ 12345 ];

    randomVector // ClearAll;
    randomVector[ ] := NumericArray[ RandomInteger[ { -127, 127 }, 384 ], "Integer8" ];

    toQueryVector // ClearAll;
    toQueryVector[ vector_NumericArray ] := NumericArray[ Normal @ vector, "Real16" ];

    (* Shared vectors produce exact ties in the nearest neighbor search: *)
    $sharedVector = randomVector[ ];

    testChat // ClearAll;
    testChat[ app_String, uuid_String, vectors_List ] := <|
        "AppName"           -> app,
        "ConversationTitle" -> "Title " <> uuid,
        "ConversationUUID"  -> uuid,
        "Date"              -> RandomReal[ { 3.9*^9, 4.0*^9 } ],
        "Messages"          -> { },
        "Version"           -> 3,
        "Vectors"           -> vectors
    |>;

    testChat[ app_String, i_Integer ] := testChat[
        app,
        "test-chat-" <> ToString @ i,
        Join[
            { If[ Divisible[ i, 5 ], $sharedVector, randomVector[ ] ] },
            Table[ randomVector[ ], RandomInteger @ { 1, 6 } ]
        ]
    ];

    addTestChats // ClearAll;
    addTestChats[ chats_List ] :=
        Block[ { Wolfram`Chatbook`Common`$noSemanticSearch = False }, AddChatToSearchIndex /@ chats ];

    (* Query embeddings are injected into the embedding cache so that tests do not depend on the embedding model: *)
    $queries = Table[ "search cache test query " <> ToString @ i, { i, 30 } ];

    setQueryVectors // ClearAll;
    setQueryVectors[ vectors_List ] := MapThread[
        (Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$embeddingCache[ #1 ] = #2) &,
        { Take[ $queries, Length @ vectors ], vectors }
    ];

    (* The uncached search implementation that SearchChats must match exactly: *)
    referenceSearch // ClearAll;
    referenceSearch[ app_String, query_String, max_ ] := Catch @ Module[ { index, flat, values, vectors, embedding, idx },
        If[ query === "", Throw @ { } ];
        index = Values @ Wolfram`Chatbook`Search`Private`$chatSearchIndex[ app ];
        flat = Flatten[ Thread @ { KeyDrop[ #, "Vectors" ], #Vectors } & /@ index, 1 ];
        If[ flat === { }, Throw @ { } ];
        { values, vectors } = Transpose @ flat;
        embedding = Wolfram`Chatbook`Common`getEmbedding[ query, "CacheEmbeddings" -> False ];
        idx = Nearest[ Normal @ vectors -> "Index", Normal @ embedding, Floor[ 2*max+1 ] ];
        Take[ DeleteDuplicatesBy[ values[[ idx ]], Lookup[ "ConversationUUID" ] ], UpTo @ Floor @ max ]
    ];

    (* Returns the query and MaxItems value for every result that differs from the reference: *)
    searchMismatches // ClearAll;
    searchMismatches[ app_String ] := Select[
        Flatten[ Table[ { query, max }, { query, $queries }, { max, { 1, 3, 10, 25, Infinity } } ], 1 ],
        Function[
            Module[ { results },
                results = SearchChats[ app, #[[ 1 ]], MaxItems -> #[[ 2 ]] ];
                ! ListQ @ results || results =!= referenceSearch[ app, #[[ 1 ]], #[[ 2 ]] ]
            ]
        ]
    ];

    (* Marks the cached values so tests can tell whether a search used the cache: *)
    markCache // ClearAll;
    markCache[ app_String ] :=
        Wolfram`Chatbook`Search`Private`$chatSearchData[ app, "Data" ] = MapAt[
            Map[ Append[ "FromCache" -> True ] ],
            Wolfram`Chatbook`Search`Private`$chatSearchData[ app, "Data" ],
            1
        ];

    usedCacheQ // ClearAll;
    usedCacheQ[ results_List ] := AnyTrue[ results, KeyExistsQ[ "FromCache" ] ];

    cleanupSearchTests[ ];
    (* Return True rather than the query vectors: CI saves test results as WXF, which can't hold "Real16" arrays *)
    MatchQ[ setQueryVectors @ Table[ toQueryVector @ randomVector[ ], Length @ $queries ], { __NumericArray } ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SearchCache-Definitions@@Tests/Search.wlt:24,1-134,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SearchChats*)
VerificationTest[
    addTestChats @ Table[ testChat[ $testApp, i ], { i, 60 } ],
    { Repeated[ _Success, { 60 } ] },
    SameTest -> MatchQ,
    TestID   -> "SearchCache-AddChats@@Tests/Search.wlt:139,1-144,2"
]

VerificationTest[
    (* Exact duplicates of existing chats under new IDs: *)
    addTestChats @ Table[
        <| testChat[ $testApp, i ], "ConversationUUID" -> "test-chat-copy-" <> ToString @ i |>,
        { i, 1, 30, 7 }
    ],
    { __Success },
    SameTest -> MatchQ,
    TestID   -> "SearchCache-AddDuplicateChats@@Tests/Search.wlt:146,1-155,2"
]

VerificationTest[
    (* Some queries exactly match stored vectors, including the shared one: *)
    MatchQ[
        setQueryVectors @ Join[
            { toQueryVector @ $sharedVector },
            toQueryVector /@ RandomSample[
                Flatten @ Values @ Wolfram`Chatbook`Search`Private`$chatSearchIndex[ $testApp ][[ All, "Vectors" ]],
                5
            ]
        ],
        { Repeated[ _NumericArray, { 6 } ] }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SearchCache-ExactMatchQueries@@Tests/Search.wlt:157,1-172,2"
]

VerificationTest[
    SearchChats[ $testApp, "" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "SearchCache-EmptyQuery@@Tests/Search.wlt:174,1-179,2"
]

VerificationTest[
    SearchChats[ $testApp, First @ $queries ],
    { Repeated[ KeyValuePattern @ { "AppName" -> $testApp, "ConversationUUID" -> _String }, { 1, 10 } ] },
    SameTest -> MatchQ,
    TestID   -> "SearchCache-ResultShape@@Tests/Search.wlt:181,1-186,2"
]

VerificationTest[
    searchMismatches @ $testApp,
    { },
    SameTest -> MatchQ,
    TestID   -> "SearchCache-MatchesReference@@Tests/Search.wlt:188,1-193,2"
]

VerificationTest[
    Wolfram`Chatbook`Search`Private`$chatSearchData[ $testApp, "Index" ] === Wolfram`Chatbook`Search`Private`$chatSearchIndex[ $testApp ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SearchCache-CachedIndex@@Tests/Search.wlt:195,1-200,2"
]

VerificationTest[
    markCache @ $testApp;
    usedCacheQ @ SearchChats[ $testApp, First @ $queries ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SearchCache-ReusedWhileIndexUnchanged@@Tests/Search.wlt:202,1-208,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Invalidation*)
VerificationTest[
    markCache @ $testApp;
    addTestChats @ Table[ testChat[ $testApp, i ], { i, 61, 70 } ];
    { usedCacheQ @ SearchChats[ $testApp, First @ $queries ], searchMismatches @ $testApp },
    { False, { } },
    SameTest -> MatchQ,
    TestID   -> "SearchCache-InvalidatedByAdd@@Tests/Search.wlt:213,1-220,2"
]

VerificationTest[
    Module[ { vector },
        markCache @ $testApp;
        vector = randomVector[ ];
        (* Replace the vectors of an existing chat: *)
        addTestChats @ { testChat[ $testApp, "test-chat-3", { vector } ] };
        setQueryVectors @ { toQueryVector @ vector };
        {
            usedCacheQ @ SearchChats[ $testApp, First @ $queries ],
            SearchChats[ $testApp, First @ $queries ][[ 1, "ConversationUUID" ]],
            searchMismatches @ $testApp
        }
    ],
    { False, "test-chat-3", { } },
    SameTest -> MatchQ,
    TestID   -> "SearchCache-InvalidatedByUpdate@@Tests/Search.wlt:222,1-238,2"
]

VerificationTest[
    markCache @ $testApp;
    RemoveChatFromSearchIndex[ $testApp, "test-chat-3" ];
    {
        usedCacheQ @ SearchChats[ $testApp, First @ $queries ],
        MemberQ[ Lookup[ SearchChats[ $testApp, First @ $queries, MaxItems -> Infinity ], "ConversationUUID" ], "test-chat-3" ],
        searchMismatches @ $testApp
    },
    { False, False, { } },
    SameTest -> MatchQ,
    TestID   -> "SearchCache-InvalidatedByRemove@@Tests/Search.wlt:240,1-251,2"
]

VerificationTest[
    Module[ { file, index },
        markCache @ $testApp;
        (* Write a different index to disk and drop the in-memory one, as if in a new session: *)
        file  = FileNameJoin @ { ChatbookFilesDirectory[ { "Search", $testApp }, "EnsureDirectory" -> False ], "index.wxf" };
        index = KeyDrop[ Wolfram`Chatbook`Search`Private`$chatSearchIndex[ $testApp ], { "test-chat-1", "test-chat-2" } ];
        Developer`WriteWXFFile[ file, <| "Index" -> index, "Version" -> 1 |> ];
        KeyDropFrom[ Wolfram`Chatbook`Search`Private`$chatSearchIndex, $testApp ];
        {
            usedCacheQ @ SearchChats[ $testApp, First @ $queries ],
            Wolfram`Chatbook`Search`Private`$chatSearchIndex[ $testApp ] === index,
            searchMismatches @ $testApp
        }
    ],
    { False, True, { } },
    SameTest -> MatchQ,
    TestID   -> "SearchCache-InvalidatedByLoad@@Tests/Search.wlt:253,1-270,2"
]

VerificationTest[
    (* There are no saved chats for the test app, so rebuilding from scratch gives an empty index: *)
    markCache @ $testApp;
    KeyDropFrom[ Wolfram`Chatbook`Search`Private`$chatSearchIndex, $testApp ];
    DeleteDirectory[ ChatbookFilesDirectory[ { "Search", $testApp }, "EnsureDirectory" -> False ], DeleteContents -> True ];
    {
        SearchChats[ $testApp, First @ $queries ],
        Wolfram`Chatbook`Search`Private`$chatSearchIndex[ $testApp ],
        searchMismatches @ $testApp
    },
    { { }, <| |>, { } },
    SameTest -> MatchQ,
    TestID   -> "SearchCache-InvalidatedByRebuild@@Tests/Search.wlt:272,1-285,2"
]

VerificationTest[
    Module[ { first, second },
        addTestChats @ Table[ testChat[ $testApp, i ], { i, 20 } ];
        addTestChats @ Table[ testChat[ Last @ $testApps, i ], { i, 20 } ];
        first  = SearchChats[ $testApp, First @ $queries ];
        second = SearchChats[ Last @ $testApps, First @ $queries ];
        {
            Keys @ Wolfram`Chatbook`Search`Private`$chatSearchData,
            Union @ Lookup[ first, "AppName" ],
            Union @ Lookup[ second, "AppName" ],
            searchMismatches @ $testApp,
            searchMismatches @ Last @ $testApps
        }
    ],
    { { Last @ $testApps }, { First @ $testApps }, { Last @ $testApps }, { }, { } },
    SameTest -> MatchQ,
    TestID   -> "SearchCache-MultipleApps@@Tests/Search.wlt:287,1-304,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*History Search Results*)

(* The results update asynchronously, so that searching does not block typing in the search field: *)
VerificationTest[
    Wolfram`Chatbook`ChatModes`UI`Private`makeHistorySearchResults[
        NotebookObject[ "search-test" ],
        None,
        $testApp,
        Dynamic @ $historySearchTestQuery
    ],
    Dynamic[
        _Wolfram`Chatbook`ChatModes`UI`Private`showSearchResults,
        OrderlessPatternSequence[ SynchronousUpdating -> False, TrackedSymbols :> { $historySearchTestQuery } ]
    ],
    SameTest -> MatchQ,
    TestID   -> "HistorySearch-AsynchronousResults@@Tests/Search.wlt:311,1-324,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    cleanupSearchTests[ ];
    DirectoryQ @ ChatbookFilesDirectory[ { "Search", # }, "EnsureDirectory" -> False ] & /@ $testApps,
    { False, False },
    SameTest -> MatchQ,
    TestID   -> "SearchCache-Cleanup@@Tests/Search.wlt:329,1-335,2"
]

(* :!CodeAnalysis::EndBlock:: *)
