(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    If[ ! TrueQ @ Wolfram`ChatbookTests`$TestDefinitionsLoaded,
        Get @ FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" }
    ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/RelatedWolframAlphaResults.wlt:4,1-11,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/RelatedWolframAlphaResults.wlt:13,1-18,2"
]

VerificationTest[
    Context @ RelatedWolframAlphaResults,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResultsContext@@Tests/RelatedWolframAlphaResults.wlt:20,1-25,2"
]

$defaultTestOptions = Sequence[
    "CacheResults" -> True,
    "Debug"        -> True,
    LLMEvaluator -> <| "Model" -> { "OpenAI", "gpt-4o-mini" }, Authentication -> Verbatim[ Automatic ] |>
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedWolframAlphaResults*)
VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", $defaultTestOptions ],
    _String? (StringContainsQ @ ToString @ Prime[ 123456789 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults@@Tests/RelatedWolframAlphaResults.wlt:36,1-41,2"
]

VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", "Prompt", $defaultTestOptions ],
    _String? (StringContainsQ @ ToString @ Prime[ 123456789 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-Prompt@@Tests/RelatedWolframAlphaResults.wlt:43,1-48,2"
]

VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", "Content", $defaultTestOptions ],
    { __Association },
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-Content@@Tests/RelatedWolframAlphaResults.wlt:50,1-55,2"
]

VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", "FullData", $defaultTestOptions ],
    KeyValuePattern @ { "Content" -> { __Association }, "SampleQueries" -> { ___, "is 73 prime?", ___ } },
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-FullData@@Tests/RelatedWolframAlphaResults.wlt:57,1-62,2"
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
    TestID   -> "RelatedWolframAlphaResults-SampleQueryCount-All@@Tests/RelatedWolframAlphaResults.wlt:67,1-76,2"
]

VerificationTest[
    RelatedWolframAlphaResults[
        "What's the 123456789th prime?",
        "SampleQueryCount" -> None,
        $defaultTestOptions
    ],
    _String? (StringFreeQ[ "is 73 prime?" ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-SampleQueryCount-None@@Tests/RelatedWolframAlphaResults.wlt:78,1-87,2"
]