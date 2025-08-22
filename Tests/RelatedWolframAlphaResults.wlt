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
    TestID   -> "RelatedWolframAlphaResults@@Tests/RelatedWolframAlphaResults.wlt:39,1-44,2"
]

VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", "Prompt", $defaultTestOptions ],
    _String? (StringContainsQ @ ToString @ Prime[ 123456789 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-Prompt@@Tests/RelatedWolframAlphaResults.wlt:46,1-51,2"
]

VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", "Content", $defaultTestOptions ],
    { __Association },
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-Content@@Tests/RelatedWolframAlphaResults.wlt:53,1-58,2"
]

VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", "FullData", $defaultTestOptions ],
    KeyValuePattern @ { "Content" -> { __Association }, "SampleQueries" -> { ___, "is 73 prime?", ___ } },
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-FullData@@Tests/RelatedWolframAlphaResults.wlt:60,1-65,2"
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
    TestID   -> "RelatedWolframAlphaResults-SampleQueryCount-All@@Tests/RelatedWolframAlphaResults.wlt:70,1-79,2"
]

VerificationTest[
    RelatedWolframAlphaResults[
        "What's the 123456789th prime?",
        "SampleQueryCount" -> None,
        $defaultTestOptions
    ],
    _String? (StringFreeQ[ "is 73 prime?" ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-SampleQueryCount-None@@Tests/RelatedWolframAlphaResults.wlt:81,1-90,2"
]

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
    TestID   -> "RelatedWolframAlphaResults-HandlerData@@Tests/RelatedWolframAlphaResults.wlt:95,1-107,2"
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
    If[ $VersionNumber >= 14.3, { }, { ServiceExecute::apierr } ],
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-ErrorHandling-LLMServices@@Tests/RelatedWolframAlphaResults.wlt:114,1-126,2"
]