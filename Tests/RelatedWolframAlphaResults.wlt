(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
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

VerificationTest[
    Context @ RelatedWolframAlphaResults,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResultsContext"
]

$defaultTestOptions = Sequence @@ {
    "CacheResults" -> True,
    "Debug"        -> True,
    If[ StringQ @ Environment[ "GITHUB_ACTIONS" ],
        LLMEvaluator -> <| "Model" -> { "OpenAI", "gpt-4o-mini" }, Authentication -> Automatic |>,
        Nothing
    ]
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedWolframAlphaResults*)
VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", $defaultTestOptions ],
    _String? (StringContainsQ @ ToString @ Prime[ 123456789 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults"
]

VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", "Prompt", $defaultTestOptions ],
    _String? (StringContainsQ @ ToString @ Prime[ 123456789 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-Prompt"
]

VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", "Content", $defaultTestOptions ],
    { __Association },
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-Content"
]

VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", "FullData", $defaultTestOptions ],
    KeyValuePattern @ { "Content" -> { __Association }, "SampleQueries" -> { ___, "is 73 prime?", ___ } },
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-FullData"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Options*)
VerificationTest[
    RelatedWolframAlphaResults[
        "What's the 123456789th prime?",
        "SampleQueryCount" -> All,
        $defaultTestOptions
    ],
    _String? (StringContainsQ[ "is 73 prime?" ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-SampleQueryCount-All"
]

VerificationTest[
    RelatedWolframAlphaResults[
        "What's the 123456789th prime?",
        "SampleQueryCount" -> None,
        $defaultTestOptions
    ],
    _String? (StringFreeQ[ "is 73 prime?" ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-SampleQueryCount-None"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DocumentationProvided*)
VerificationTest[
    Lookup[ Options @ RelatedWolframAlphaResults, "DocumentationProvided" ],
    False,
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-DocumentationProvided-Default"
]

(* Prompts better answered by documentation should not generate any Wolfram Alpha queries: *)
VerificationTest[
    RelatedWolframAlphaResults[
        "How do I deploy a web form to the cloud?",
        "DocumentationProvided" -> True,
        $defaultTestOptions
    ],
    "",
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-DocumentationProvided-DefersToDocs"
]

(* Computational prompts still give results, which now include equivalent Wolfram Language code: *)
VerificationTest[
    RelatedWolframAlphaResults[
        "What is the 1000th prime number?",
        "DocumentationProvided" -> True,
        $defaultTestOptions
    ],
    _String? (StringContainsQ[ #, ToString @ Prime[ 1000 ] ] && StringContainsQ[ #, "```wl" ] &),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-DocumentationProvided-IncludesWLResults"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* The DocumentationProvided option forces usingDocumentationQ to give True regardless of chat settings: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`RelatedWolframAlphaResults`Private`$docsProvided = True },
        Wolfram`Chatbook`PromptGenerators`RelatedWolframAlphaResults`Private`usingDocumentationQ[ ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-DocumentationProvided-UsingDocumentationQ"
]

VerificationTest[
    Wolfram`Chatbook`PromptGenerators`RelatedWolframAlphaResults`Private`usingDocumentationQ[ ],
    False,
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-DocumentationProvided-UsingDocumentationQ-Default"
]

(* Both documentation prompt generators provide documentation: *)
VerificationTest[
    Wolfram`Chatbook`PromptGenerators`RelatedWolframAlphaResults`Private`usingDocumentationQ /@ {
        { Wolfram`Chatbook`Common`$defaultPromptGenerators[ "RelatedDocumentation" ] },
        { Wolfram`Chatbook`Common`$defaultPromptGenerators[ "RelatedDocumentationList" ] },
        { Wolfram`Chatbook`Common`$defaultPromptGenerators[ "WebSearch" ] }
    },
    { True, True, False },
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-UsingDocumentationQ-Generators"
]

(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Handler Data*)
VerificationTest[
    $ChatHandlerData = <| |>;
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", "Prompt", $defaultTestOptions ];
    $ChatHandlerData[ "RelatedWolframAlphaResults" ],
    KeyValuePattern @ {
        "Messages"      -> { __Association },
        "Queries"       -> { __String },
        "Response"      -> KeyValuePattern[ "Content" -> _String ],
        "SampleQueries" -> { ___String }
    },
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-HandlerData"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Handling*)

(* Specify an invalid model name to ensure LLMServices failures are returned to top-level: *)
VerificationTest[
    RelatedWolframAlphaResults[
        "What's the 123456789th prime?",
        "Prompt",
        "CacheResults" -> True,
        "Debug"        -> True,
        LLMEvaluator   -> <| "Model" -> { "OpenAI", "invalid-model-name" }, Authentication -> Verbatim[ Automatic ] |>
    ],
    _Failure,
    { },
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-ErrorHandling-LLMServices"
]