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
(* :!CodeAnalysis::Disable::KeyExistsQNestedKeyPath:: *)

(* Session caches and logs must stay bounded without changing any results. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*mergeChatSettings*)
VerificationTest[
    Module[ { inputs, uncached },
        uncached = Function[
            Wolfram`Chatbook`Settings`Private`mergeChatSettings0 @ # //.
                Wolfram`Chatbook`Settings`Private`$mergeSettingsDispatch
        ];
        inputs = {
            { },
            { <| "a" -> 1 |> },
            { <| "a" -> 1, "b" -> <| "x" -> 1 |> |>, <| "b" -> <| "y" -> 2 |> |> },
            { <| "a" -> 1 |>, Inherited, <| "a" -> 2 |> },
            { <| "Tools" -> { "A" } |>, <| "Tools" -> { ParentList, "B" } |> },
            { Wolfram`Chatbook`Common`$defaultChatSettings, <| "ConversationUUID" -> CreateUUID[ ] |> }
        };
        Table[
            {
                Wolfram`Chatbook`Common`mergeChatSettings @ in,
                Wolfram`Chatbook`Common`mergeChatSettings @ in (* cached *)
            } === { uncached @ in, uncached @ in },
            { in, inputs }
        ]
    ],
    { True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "MergeChatSettings-Results"
]

VerificationTest[
    Wolfram`Chatbook`Common`mergeChatSettings @ { <| "Tools" -> { "A" } |>, <| "Tools" -> { ParentList, "B" } |> },
    <| "Tools" -> { "A", "B" } |>,
    SameTest -> MatchQ,
    TestID   -> "MergeChatSettings-ParentList"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Settings`Private`cachedMergedChatSettings,
            Wolfram`Chatbook`Settings`Private`$mergedChatSettingsCacheSize    = 0,
            Wolfram`Chatbook`Settings`Private`$maxMergedChatSettingsCacheSize = 10
        },
        Module[ { results },
            results = Table[
                Wolfram`Chatbook`Common`mergeChatSettings @ { <| "a" -> i, "b" -> 0 |>, <| "b" -> i |> },
                { i, 25 }
            ];
            {
                results === Table[ <| "a" -> i, "b" -> i |>, { i, 25 } ],
                Length @ DownValues @ Wolfram`Chatbook`Settings`Private`cachedMergedChatSettings <= 10,
                (* The most recent result is kept: *)
                Wolfram`Chatbook`Settings`Private`cachedMergedChatSettings @ { <| "a" -> 25, "b" -> 0 |>, <| "b" -> 25 |> },
                (* The oldest result is dropped: *)
                MatchQ[
                    Wolfram`Chatbook`Settings`Private`cachedMergedChatSettings @ { <| "a" -> 1, "b" -> 0 |>, <| "b" -> 1 |> },
                    _Wolfram`Chatbook`Settings`Private`cachedMergedChatSettings
                ],
                (* Dropped inputs give the same result as before: *)
                Wolfram`Chatbook`Common`mergeChatSettings @ { <| "a" -> 1, "b" -> 0 |>, <| "b" -> 1 |> }
            }
        ]
    ],
    { True, True, <| "a" -> 25, "b" -> 25 |>, True, <| "a" -> 1, "b" -> 1 |> },
    SameTest -> MatchQ,
    TestID   -> "MergeChatSettings-Bounded"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Settings`Private`cachedMergedChatSettings,
            Wolfram`Chatbook`Settings`Private`$mergedChatSettingsCacheSize = 0
        },
        Wolfram`Chatbook`Common`mergeChatSettings @ { };
        Wolfram`Chatbook`Common`mergeChatSettings @ { <| "a" -> 1 |>, <| "b" -> 2 |> };
        Wolfram`Chatbook`Common`mergeChatSettings @ { <| "a" -> 1 |>, <| "b" -> 2 |> };
        {
            Length @ DownValues @ Wolfram`Chatbook`Settings`Private`cachedMergedChatSettings,
            Wolfram`Chatbook`Settings`Private`$mergedChatSettingsCacheSize,
            Wolfram`Chatbook`Settings`Private`cachedMergedChatSettings @ { },
            Wolfram`Chatbook`Settings`Private`cachedMergedChatSettings @ { <| "a" -> 1 |>, <| "b" -> 2 |> }
        }
    ],
    { 2, 2, Missing[ ], <| "a" -> 1, "b" -> 2 |> },
    SameTest -> MatchQ,
    TestID   -> "MergeChatSettings-CacheEntries"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*LogChatTiming*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$timingLog          = Internal`Bag[ ],
            Wolfram`Chatbook`Utils`Private`$maxTimingLogSize = 10
        },
        Module[ { results, log },
            results = Table[
                LogChatTiming[ LogChatTiming[ i, "Inner" ], "Outer" <> ToString @ i ],
                { i, 25 }
            ];
            log = Internal`BagPart[ Wolfram`Chatbook`Common`$timingLog, All ];
            {
                results,
                Length @ log <= 10,
                Last[ log ][ "Tag" ],
                Union[ Length /@ log[[ All, "ChildTimings" ]] ],
                Union @ Flatten @ log[[ All, "ChildTimings", All, "Tag" ]],
                (* Entries are kept in order and the most recent ones are kept: *)
                log[[ All, "Tag" ]] === Table[ "Outer" <> ToString @ i, { i, 26 - Length @ log, 25 } ]
            }
        ]
    ],
    { Range[ 25 ], True, "Outer25", { 1 }, { "Inner" }, True },
    SameTest -> MatchQ,
    TestID   -> "LogChatTiming-Bounded"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$timingLog          = Internal`Bag[ ],
            Wolfram`Chatbook`Utils`Private`$maxTimingLogSize = 5
        },
        LogChatTiming[ Do[ LogChatTiming[ i, "Inner" ], { i, 20 } ], "Outer" ];
        (* Nested timings are not trimmed, since they are needed for the parent's "UsedTiming": *)
        Length /@ Internal`BagPart[ Wolfram`Chatbook`Common`$timingLog, All ][[ All, "ChildTimings" ]]
    ],
    { 20 },
    SameTest -> MatchQ,
    TestID   -> "LogChatTiming-NestedNotTrimmed"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$timingLog          = Internal`Bag[ ],
            Wolfram`Chatbook`Utils`Private`$maxTimingLogSize = 4
        },
        Module[ { data },
            Do[ LogChatTiming[ LogChatTiming[ i, "Inner" ], "Outer" ], { i, 10 } ];
            data = $ChatTimingData;
            Unset @ $ChatTimingData;
            {
                MatchQ[ data, { KeyValuePattern[ { "Tag" -> _String, "FullTiming" -> _Real } ].. } ],
                Length @ data <= 8,
                Union @ Lookup[ data, "Tag" ],
                $ChatTimingData
            }
        ]
    ],
    { True, True, { "Inner", "Outer" }, { } },
    SameTest -> MatchQ,
    TestID   -> "ChatTimingData-Bounded"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$chunkDebug*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`SendChat`Private`$chunkDebug        = Internal`Bag[ ],
            Wolfram`Chatbook`SendChat`Private`$maxChunkDebugSize = 10
        },
        Do[
            Wolfram`Chatbook`SendChat`Private`writeChunk0[ Dynamic @ container, None, "chunk" <> ToString @ i, <| "i" -> i |> ],
            { i, 25 }
        ];
        Module[ { log = Internal`BagPart[ Wolfram`Chatbook`SendChat`Private`$chunkDebug, All ] },
            { Length @ log <= 10, Last @ log }
        ]
    ],
    { True, <| "chunk" -> "chunk25", "other" -> <| "i" -> 25 |> |> },
    SameTest -> MatchQ,
    TestID   -> "ChunkDebug-Bounded"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Vector Database Caches*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$vectorDBSearchCache*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBSearchCache        = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$maxVectorDBSearchCacheSize = 10
        },
        Do[
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`cacheVectorDBResult[
                db,
                "prompt " <> ToString @ i,
                <| "Values" -> { db, i } |>
            ],
            { i, 25 },
            { db, { "DocumentationURIs", "FunctionRepositoryURIs" } }
        ];
        {
            Length @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBSearchCache <= 10,
            (* Recent results are returned from the cache: *)
            Wolfram`Chatbook`PromptGenerators`Common`vectorDBSearch[ "DocumentationURIs", "prompt 25", All ],
            Wolfram`Chatbook`PromptGenerators`Common`vectorDBSearch[ "FunctionRepositoryURIs", "prompt 25", "Values" ],
            KeyExistsQ[
                Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$vectorDBSearchCache,
                { "DocumentationURIs", "prompt 1" }
            ]
        }
    ],
    { True, <| "Values" -> { "DocumentationURIs", 25 } |>, { "FunctionRepositoryURIs", 25 }, False },
    SameTest -> MatchQ,
    TestID   -> "VectorDBSearchCache-Bounded"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$embeddingCache*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$embeddingCache        = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$maxEmbeddingCacheSize = 10,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$cacheEmbeddings       = True,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getAndCacheEmbeddings,
            vector, expected, computed = { }
        },
        (* Use a deterministic stand-in for the embedding model: *)
        vector = Function[ s, N @ Join[ { StringLength @ s, Mod[ Hash @ s, 101 ] }, ConstantArray[ 1, 382 ] ] ];
        expected = Function[ s, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`toTinyVector @ vector @ s ];
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getAndCacheEmbeddings[ strings_List ] := (
            computed = Join[ computed, strings ];
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`cacheEmbedding[ #, vector @ # ] & /@ strings
        );
        Module[ { batches, results, single },
            batches = Partition[ Table[ "string " <> ToString @ i, { i, 24 } ], 3 ];
            results = Wolfram`Chatbook`Common`getEmbeddings /@ batches;
            (* A call with more strings than the cache size still gives every embedding: *)
            single = Wolfram`Chatbook`Common`getEmbeddings @ Table[ "long " <> ToString @ i, { i, 15 } ];
            {
                results === Map[ expected, batches, { 2 } ],
                single === expected /@ Table[ "long " <> ToString @ i, { i, 15 } ],
                Length @ computed,
                (* Cached embeddings are not recomputed: *)
                Wolfram`Chatbook`Common`getEmbeddings @ { "long 15", "long 14" } === expected /@ { "long 15", "long 14" },
                Length @ computed,
                Length @ Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$embeddingCache <= 10 + 15
            }
        ]
    ],
    { True, True, 39, True, 39, True },
    SameTest -> MatchQ,
    TestID   -> "EmbeddingCache-Bounded"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$embeddingCache        = <| |>,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$maxEmbeddingCacheSize = 10,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$cacheEmbeddings       = True,
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getAndCacheEmbeddings,
            vector, expected, strings
        },
        vector = Function[ s, N @ Join[ { StringLength @ s, Mod[ Hash @ s, 101 ] }, ConstantArray[ 1, 382 ] ] ];
        expected = Function[ s, Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`toTinyVector @ vector @ s ];
        Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`getAndCacheEmbeddings[ new_List ] := (
            (* Simulate a preemptive evaluation that trims the cache while embeddings are being computed: *)
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$embeddingCache = <| |>;
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`cacheEmbedding[ #, vector @ # ] & /@ new
        );
        strings = Table[ "string " <> ToString @ i, { i, 8 } ];
        Wolfram`Chatbook`Common`getEmbeddings @ Take[ strings, 5 ];
        (* Cached embeddings that are evicted in the middle of the call are still returned: *)
        Wolfram`Chatbook`Common`getEmbeddings @ strings === expected /@ strings
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "EmbeddingCache-PreemptiveTrim"
]

(* :!CodeAnalysis::EndBlock:: *)
