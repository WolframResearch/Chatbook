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
    LLMEvaluator -> <| "Model" -> { "OpenAI", "gpt-4o-mini" }, Authentication -> Automatic |>
];

GeneralUtilities`$DebugMode = True;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedWolframAlphaResults*)
VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", $defaultTestOptions ],
    _String? (StringContainsQ @ ToString @ Prime[ 123456789 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults@@Tests/RelatedWolframAlphaResults.wlt:38,1-43,2"
]

VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", "Prompt", $defaultTestOptions ],
    _String? (StringContainsQ @ ToString @ Prime[ 123456789 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-Prompt@@Tests/RelatedWolframAlphaResults.wlt:45,1-50,2"
]

VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", "Content", $defaultTestOptions ],
    { __Association },
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-Content@@Tests/RelatedWolframAlphaResults.wlt:52,1-57,2"
]

VerificationTest[
    RelatedWolframAlphaResults[ "What's the 123456789th prime?", "FullData", $defaultTestOptions ],
    KeyValuePattern @ { "Content" -> { __Association }, "SampleQueries" -> { ___, "is 73 prime?", ___ } },
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-FullData@@Tests/RelatedWolframAlphaResults.wlt:59,1-64,2"
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
    TestID   -> "RelatedWolframAlphaResults-SampleQueryCount-All@@Tests/RelatedWolframAlphaResults.wlt:69,1-78,2"
]

VerificationTest[
    RelatedWolframAlphaResults[
        "What's the 123456789th prime?",
        "SampleQueryCount" -> None,
        $defaultTestOptions
    ],
    _String? (StringFreeQ[ "is 73 prime?" ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-SampleQueryCount-None@@Tests/RelatedWolframAlphaResults.wlt:80,1-89,2"
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
    TestID   -> "RelatedWolframAlphaResults-HandlerData@@Tests/RelatedWolframAlphaResults.wlt:94,1-106,2"
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
    { ServiceExecute::apierr },
    SameTest -> MatchQ,
    TestID   -> "RelatedWolframAlphaResults-ErrorHandling-LLMServices@@Tests/RelatedWolframAlphaResults.wlt:113,1-125,2"
]

GeneralUtilities`$DebugMode = False;