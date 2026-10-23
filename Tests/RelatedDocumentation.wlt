(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/RelatedDocumentation.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/RelatedDocumentation.wlt:11,1-16,2"
]

VerificationTest[
    Context @ RelatedDocumentation,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentationContext@@Tests/RelatedDocumentation.wlt:18,1-23,2"
]

$defaultTestOptions =
    If[ StringQ @ Environment[ "GITHUB_ACTIONS" ],
        LLMEvaluator -> <| "Model" -> { "OpenAI", "gpt-4o-mini" }, Authentication -> Automatic |>,
        Sequence @@ { }
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedDocumentation*)
VerificationTest[
    urls = RelatedDocumentation[ "What's the biggest pokemon?" ],
    { URL[ _String ].. },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs@@Tests/RelatedDocumentation.wlt:34,1-39,2"
]

VerificationTest[
    FileNames[ All, ChatbookFilesDirectory[ "VectorDatabases" ], Infinity ],
    { Repeated[ _String, { 40, Infinity } ] },
    SameTest -> MatchQ,
    TestID   -> "VectorDatabase-Files@@Tests/RelatedDocumentation.wlt:41,1-46,2"
]

VerificationTest[
    Length @ Select[
        First /@ urls,
        StringStartsQ @ StringExpression[
            "paclet:ref/",
            "interpreter"|"entity"|"textcontent",
            "/",
            "Pokemon"|"ComputedPokemon",
            "#"
        ]
    ],
    _Integer? (GreaterThan[ 5 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs-Count@@Tests/RelatedDocumentation.wlt:48,1-62,2"
]

VerificationTest[
    snippets = RelatedDocumentation[ "What's the biggest pokemon?", "Snippets" ],
    { __String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets@@Tests/RelatedDocumentation.wlt:64,1-69,2"
]

VerificationTest[
    Total @ StringCount[ snippets, "Entity[\"Pokemon\"," ],
    _Integer? (GreaterThan[ 5 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets-Count@@Tests/RelatedDocumentation.wlt:71,1-76,2"
]

VerificationTest[
    urls = RelatedDocumentation[ "What's the biggest pokemon?", Automatic, 3, "Sources" -> { "Documentation" } ],
    { URL[ _String ], URL[ _String ], URL[ _String ] },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs-Count@@Tests/RelatedDocumentation.wlt:78,1-83,2"
]

VerificationTest[
    AllTrue[ First /@ urls, StringStartsQ[ "paclet:ref/" ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs-Match@@Tests/RelatedDocumentation.wlt:85,1-90,2"
]

VerificationTest[
    RelatedDocumentation[ "What's the biggest pokemon?", "Snippets", 3 ],
    { _String, _String, _String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets-Count@@Tests/RelatedDocumentation.wlt:92,1-97,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Prompt*)
VerificationTest[
    prompt = RelatedDocumentation[
        "What's the 123456789th prime?",
        "Prompt",
        "FilterResults" -> False,
        "MaxItems"      -> 20
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt@@Tests/RelatedDocumentation.wlt:102,1-112,2"
]

VerificationTest[
    StringCount[ prompt, "paclet:ref/Prime#" ],
    _Integer? Positive,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt-Count@@Tests/RelatedDocumentation.wlt:114,1-119,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Message Input*)
VerificationTest[
    prompt = RelatedDocumentation[
        {
            <| "Role" -> "User"     , "Content" -> "What's the 123456789th prime?"  |>,
            <| "Role" -> "Assistant", "Content" -> "```wl\nPrime[123456789]\n```"   |>,
            <| "Role" -> "User"     , "Content" -> "What about the one after that?" |>
        },
        "Prompt",
        "FilterResults" -> False,
        "MaxItems"      -> 20
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt-Messages@@Tests/RelatedDocumentation.wlt:124,1-138,2"
]

VerificationTest[
    StringCount[ prompt, { "paclet:ref/Prime#", "paclet:ref/NextPrime#" } ],
    _Integer? (GreaterEqualThan[ 5 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt-Messages-Count@@Tests/RelatedDocumentation.wlt:140,1-145,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Selection Prompt*)
VerificationTest[
    prompt = Block[
        { Wolfram`Chatbook`Common`$contextPrompt = "```wl\nIn[1]:= Prime[123456789]\nOut[1]= 2543568463\n```" },
        RelatedDocumentation[
            { <| "Role" -> "User", "Content" -> "What does this do?" |> },
            "Prompt",
            "FilterResults" -> False,
            "MaxItems"      -> 20
        ]
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt-Selection@@Tests/RelatedDocumentation.wlt:150,1-163,2"
]

VerificationTest[
    StringCount[ prompt, "paclet:ref/Prime#" ],
    _Integer? (GreaterEqualThan[ 2 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt-Selection-Count@@Tests/RelatedDocumentation.wlt:165,1-170,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Regression Tests*)
VerificationTest[
    Take[ RelatedDocumentation[ { <| "Role" -> "User", "Content" -> "Hello" |> } ], UpTo[ 30 ] ][[ All, 1 ]],
    { __String? (StringFreeQ[ "$Username" ]) },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Regression-UserPrefix@@Tests/RelatedDocumentation.wlt:175,1-180,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Vector Database Tests*)

(* These ensure the source selector and each component vector database is working properly. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DataRepositoryURIs*)
VerificationTest[
    RelatedDocumentation[ "Show me a map of meteorite impacts", "URIs", 5 ],
    {
        ___,
        URL[ _String? (StringStartsQ[ "https://datarepository.wolframcloud.com/resources/Meteorite-Landings#" ]) ],
        ___
    },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-DataRepositoryURIs-1@@Tests/RelatedDocumentation.wlt:191,1-200,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DocumentationURIs*)
VerificationTest[
    RelatedDocumentation[ "What's the 123456789th prime?", "URIs", 5 ],
    { ___, URL[ _String? (StringStartsQ[ "paclet:ref/Prime#" ]) ], ___ },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-DocumentationURIs-1@@Tests/RelatedDocumentation.wlt:205,1-210,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*EntityValues*)
VerificationTest[
    SelectFirst[
        RelatedDocumentation[ "What are the biggest craters from asteroid strikes?", "Snippets", 5 ],
        StringContainsQ @ StringExpression[
            "EntityClass[\"EarthImpact\", {EntityProperty[\"EarthImpact\", \"Diameter\"] -> TakeLargest[",
            DigitCharacter..,
            "]}]"
        ]
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-EntityValues-1@@Tests/RelatedDocumentation.wlt:215,1-227,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FunctionRepositoryURIs*)
VerificationTest[
    RelatedDocumentation[ "What's the resistance of a red green blue resistor?", "URIs", 5 ],
    {
        ___,
        URL[ _String? (StringContainsQ[ "/FromResistorColorCode#" ]) ],
        ___
    },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-FunctionRepositoryURIs-1@@Tests/RelatedDocumentation.wlt:232,1-241,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*NeuralNetRepositoryURIs*)
VerificationTest[
    SelectFirst[
        RelatedDocumentation[
            "I want to run some text generation experiments with GPT2. Can you tell me how I can get started?",
            "Snippets",
            5
        ],
        StringContainsQ[ "GPT2 Transformer Trained on WebText Data" ]
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-NeuralNetRepositoryURIs-1@@Tests/RelatedDocumentation.wlt:246,1-258,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*PacletRepositoryURIs*)
VerificationTest[
    SelectFirst[
        RelatedDocumentation[
            "How can I automatically run tests when I open a PR for my paclet on GitHub?",
            "Snippets",
            5
        ],
        StringContainsQ[ "Wolfram`PacletCICD`CheckPaclet" ]
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-PacletRepositoryURIs-1@@Tests/RelatedDocumentation.wlt:263,1-275,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Regression Tests*)
(* Ensure that asynchronous tasks spawned by RelatedDocumentation work in an asynchronous environment. *)
VerificationTest[
    TaskWait @ SessionSubmit[
        res = RelatedDocumentation[ "What's the 123456789th prime?", "Prompt", $defaultTestOptions ]
    ];
    res,
    _String? (StringContainsQ[ "Prime" ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-SessionSubmit@@Tests/RelatedDocumentation.wlt:281,1-289,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DocumentationLookup*)
VerificationTest[
    $DefaultTools[ "DocumentationLookup" ][ <| "ids" -> "AstroGraphics" |> ],
    _String? (StringContainsQ[ "# AstroGraphics\n\nAstroGraphics[" ]),
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-Markdown@@Tests/RelatedDocumentation.wlt:294,1-299,2"
]

VerificationTest[
    StringSplit[
        $DefaultTools[ "DocumentationLookup" ][ <| "ids" -> { "Plot", "paclet:ref/ListPlot" } |> ],
        "\n\n======\n\n"
    ],
    { _String? (StringStartsQ[ "# Plot\n" ]), _String? (StringStartsQ[ "# ListPlot\n" ]) },
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-Markdown-Multiple@@Tests/RelatedDocumentation.wlt:301,1-309,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FilterSnippets Response Cache*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* The LLM is mocked in these tests, and LLMKit is disabled so that no network requests are made for filtering: *)
cachedFilterResponse[ args___ ] :=
    Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`cachedFilterSnippetsResponse[ args ];

$filterCalls = 0;

$mockFilterLLM = Function[ { prompt, config }, "Computational\n5 Mock-" <> ToString[ ++$filterCalls ] ];

(* Selects the first two snippet IDs that are listed in the instructions: *)
$mockSelectionLLM = Function[ { prompt, config },
    $filterCalls++;
    StringJoin[
        "Computational\n",
        StringRiffle[
            "5 " <> # & /@ Take[
                StringSplit[ Last @ StringSplit[ prompt, "These are the available snippet IDs:\n" ], "\n" ],
                UpTo[ 2 ]
            ],
            "\n"
        ]
    ]
];

withMockFilterLLM // Attributes = { HoldFirst };

withMockFilterLLM[ eval_ ] := withMockFilterLLM[ eval, $mockFilterLLM ];

withMockFilterLLM[ eval_, mock_ ] := Block[
    {
        Wolfram`Chatbook`Common`llmSynthesize = mock,
        Wolfram`Chatbook`Common`$llmKit = False,
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$filterSnippetsResponseCache = <| |>,
        $filterCalls = 0
    },
    eval
];

filterCacheHits[ log_Internal`Bag ] :=
    Length @ Cases[ Internal`BagPart[ log, All ], KeyValuePattern[ "Tag" -> "FilterSnippetsCacheHit" ], Infinity ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cachedFilterSnippetsResponse*)
VerificationTest[
    withMockFilterLLM @ {
        cachedFilterResponse[ "instructions 1", <| |> ],
        cachedFilterResponse[ "instructions 1", <| |> ],
        $filterCalls
    },
    { "Computational\n5 Mock-1", "Computational\n5 Mock-1", 1 },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-Repeat"
]

VerificationTest[
    withMockFilterLLM @ Block[ { Wolfram`Chatbook`Common`$timingLog = Internal`Bag[ ] },
        cachedFilterResponse[ "instructions 1", <| |> ];
        cachedFilterResponse[ "instructions 1", <| |> ];
        filterCacheHits @ Wolfram`Chatbook`Common`$timingLog
    ],
    1,
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-Repeat-Timing"
]

VerificationTest[
    withMockFilterLLM @ {
        cachedFilterResponse[ "instructions 1", <| |> ],
        cachedFilterResponse[ "instructions 2", <| |> ],
        cachedFilterResponse[ "instructions 2", <| |> ],
        $filterCalls
    },
    { "Computational\n5 Mock-1", "Computational\n5 Mock-2", "Computational\n5 Mock-2", 2 },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-DifferentInstructions"
]

VerificationTest[
    withMockFilterLLM @ {
        cachedFilterResponse[ "instructions 1", <| |> ],
        cachedFilterResponse[ "instructions 1", <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o-mini" |> |> ],
        cachedFilterResponse[ "instructions 1", <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o-mini" |> |> ],
        $filterCalls
    },
    { "Computational\n5 Mock-1", "Computational\n5 Mock-2", "Computational\n5 Mock-2", 2 },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-DifferentModel"
]

VerificationTest[
    withMockFilterLLM[
        {
            Catch[ cachedFilterResponse[ "instructions 1", <| |> ], "MockFailure" ],
            cachedFilterResponse[ "instructions 1", <| |> ],
            cachedFilterResponse[ "instructions 1", <| |> ],
            $filterCalls
        },
        Function[ { prompt, config },
            If[ ++$filterCalls === 1, Throw[ "Failed", "MockFailure" ], "Computational\n5 Mock-" <> ToString @ $filterCalls ]
        ]
    ],
    { "Failed", "Computational\n5 Mock-2", "Computational\n5 Mock-2", 2 },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-FailureNotCached"
]

VerificationTest[
    withMockFilterLLM[
        {
            cachedFilterResponse[ "instructions 1", <| |> ],
            cachedFilterResponse[ "instructions 1", <| |> ],
            cachedFilterResponse[ "instructions 1", <| |> ],
            $filterCalls
        },
        Function[ { prompt, config },
            If[ ++$filterCalls === 1, $Failed, "Computational\n5 Mock-" <> ToString @ $filterCalls ]
        ]
    ],
    { $Failed, "Computational\n5 Mock-2", "Computational\n5 Mock-2", 2 },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-NonStringNotCached"
]

VerificationTest[
    withMockFilterLLM @ Module[ { cache, first },
        Do[ cachedFilterResponse[ "instructions " <> ToString @ i, <| |> ], { i, 70 } ];
        cache = Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$filterSnippetsResponseCache;
        first = cachedFilterResponse[ "instructions 1", <| |> ];
        { Length @ cache, cachedFilterResponse[ "instructions 70", <| |> ], first, $filterCalls }
    ],
    { 64, "Computational\n5 Mock-70", "Computational\n5 Mock-71", 71 },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-Bounded"
]

VerificationTest[
    withMockFilterLLM @ Block[
        { Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$filterSnippetsCacheSize = 0 },
        cachedFilterResponse[ "instructions 1", <| |> ];
        cachedFilterResponse[ "instructions 1", <| |> ];
        $filterCalls
    ],
    2,
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-Disabled"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmSynthesizeCacheKey*)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$llmKit = False },
        {
            Wolfram`Chatbook`Common`llmSynthesizeCacheKey[ "instructions", <| |> ],
            Wolfram`Chatbook`Common`llmSynthesizeCacheKey[ "instructions", <| |> ]
        }
    ],
    { key_Integer, key_Integer },
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesizeCacheKey-Stable"
]

(* The same model through a different authentication path is a different request: *)
VerificationTest[
    SameQ[
        Block[ { Wolfram`Chatbook`Common`$llmKit = True, Wolfram`Chatbook`Common`$llmKitService = "OpenAI" },
            Wolfram`Chatbook`Common`llmSynthesizeCacheKey[ "instructions", <| |> ]
        ],
        Block[ { Wolfram`Chatbook`Common`$llmKit = False },
            Wolfram`Chatbook`Common`llmSynthesizeCacheKey[ "instructions", <| |> ]
        ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesizeCacheKey-Authentication"
]

VerificationTest[
    SameQ[
        Block[ { Wolfram`Chatbook`Common`$llmKit = True, Wolfram`Chatbook`Common`$llmKitService = "LLMKitOpenAI" },
            Wolfram`Chatbook`Common`llmSynthesizeCacheKey[ "instructions", <| |> ]
        ],
        Block[ { Wolfram`Chatbook`Common`$llmKit = True, Wolfram`Chatbook`Common`$llmKitService = "LLMKitAnthropic" },
            Wolfram`Chatbook`Common`llmSynthesizeCacheKey[ "instructions", <| |> ]
        ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesizeCacheKey-Service"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*RelatedDocumentation*)
VerificationTest[
    withMockFilterLLM[
        Module[ { messages, prompt1, data1, calls1, prompt2, data2, hits },
            messages = { <| "Role" -> "User", "Content" -> "How do I make a 3D plot of a surface?" |> };
            prompt1  = RelatedDocumentation[ messages, "Prompt", "FilterResults" -> True, "MaxItems" -> 20 ];
            data1    = $ChatHandlerData[ "RelatedDocumentation" ];
            calls1   = $filterCalls;
            Block[ { Wolfram`Chatbook`Common`$timingLog = Internal`Bag[ ] },
                prompt2 = RelatedDocumentation[ messages, "Prompt", "FilterResults" -> True, "MaxItems" -> 20 ];
                hits    = filterCacheHits @ Wolfram`Chatbook`Common`$timingLog
            ];
            data2 = $ChatHandlerData[ "RelatedDocumentation" ];
            { calls1, $filterCalls, hits, prompt1 === prompt2, data1 === data2, prompt1, data1[ "Filtered" ] }
        ],
        $mockSelectionLLM
    ],
    { 1, 1, 1, True, True, _String? (StringStartsQ[ "IMPORTANT: " ]), { __String } },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-RelatedDocumentation-Repeat"
]

VerificationTest[
    withMockFilterLLM[
        Module[ { prompt1, prompt2 },
            prompt1 = RelatedDocumentation[
                { <| "Role" -> "User", "Content" -> "How do I make a 3D plot of a surface?" |> },
                "Prompt",
                "FilterResults" -> True,
                "MaxItems"      -> 20
            ];
            prompt2 = RelatedDocumentation[
                {
                    <| "Role" -> "User"     , "Content" -> "How do I make a 3D plot of a surface?"         |>,
                    <| "Role" -> "Assistant", "Content" -> "Use Plot3D[Sin[x y], {x, -2, 2}, {y, -2, 2}]." |>,
                    <| "Role" -> "User"     , "Content" -> "Can I color it by height?"                     |>
                },
                "Prompt",
                "FilterResults" -> True,
                "MaxItems"      -> 20
            ];
            { $filterCalls, prompt1, prompt2 }
        ],
        $mockSelectionLLM
    ],
    { 2, _String, _String },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-RelatedDocumentation-DifferentTranscript"
]

(* :!CodeAnalysis::EndBlock:: *)
