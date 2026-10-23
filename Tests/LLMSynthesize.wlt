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

(* These tests replace llmSynthesizeSubmit with a mock that responds after a delay, so they don't make any requests. *)
VerificationTest[
    $invalidResponse = Failure[
        "InvalidResponse",
        <|
            "MessageTemplate"   -> "The server returned an invalid response. Please try again later.",
            "MessageParameters" -> { }
        |>
    ];

    $authFailure = Failure[ "TestLLMKitFailure", <| "MessageTemplate" -> "Test failure", "MessageParameters" -> { } |> ];

    (* A mock llmSynthesizeSubmit that calls the callback with the given response after a delay: *)
    mockSubmit[ delay_, response_ ] := Function[
        { prompt, evaluator, callback },
        submitCount++;
        $lastMockTask = SessionSubmit @ ScheduledTask[ firedCount++; callback[ response, <| |> ], { delay } ]
    ];

    (* Process any pending asynchronous tasks for the given number of seconds: *)
    yieldFor[ seconds_ ] := TimeConstrained[ While[ True, Internal`YieldAsynchronousTask[ ]; Pause[ 0.01 ] ], seconds ];

    $query = "What's the 123456789th prime?";
    $unfilteredHeader = Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$relatedDocsStringUnfilteredHeader;
    $filteredHeader = Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$relatedDocsStringFilteredHeader;
    $snippetDelimiter = "\n\n======\n\n";
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesize-Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*llmSynthesize*)
VerificationTest[
    Options @ Wolfram`Chatbook`Common`llmSynthesize,
    { TimeConstraint -> Infinity, "MaxAttempts" -> 4, "ReturnFailures" -> False },
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesize-DefaultOptions"
]

VerificationTest[
    Block[
        { submitCount = 0, firedCount = 0, Wolfram`Chatbook`Common`llmSynthesizeSubmit = mockSubmit[ 0.01, "Hello" ] },
        {
            Wolfram`Chatbook`Common`llmSynthesize[ "Hi" ],
            Wolfram`Chatbook`Common`llmSynthesize[
                "Hi",
                <| |>,
                TimeConstraint   -> 5,
                "MaxAttempts"    -> 2,
                "ReturnFailures" -> True
            ],
            submitCount
        }
    ],
    { "Hello", "Hello", 2 },
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesize-Success"
]

(* Callers that don't specify options should keep the original retry behavior: *)
VerificationTest[
    Block[
        {
            submitCount = 0,
            firedCount  = 0,
            pauses      = { },
            Pause       = AppendTo[ pauses, # ] &,
            Wolfram`Chatbook`Common`llmSynthesizeSubmit = mockSubmit[ 0.01, $invalidResponse ]
        },
        {
            Wolfram`Chatbook`Common`catchAlways[ Wolfram`Chatbook`Common`llmSynthesize[ "Hi" ]; "NotThrown" ],
            submitCount,
            (* Exclude the short pauses used by taskWaitYield: *)
            Select[ pauses, GreaterEqualThan[ 1 ] ]
        }
    ],
    { $invalidResponse, 4, { 1, E, E^2 } },
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesize-DefaultRetries"
]

VerificationTest[
    Block[
        { submitCount = 0, firedCount = 0, Wolfram`Chatbook`Common`llmSynthesizeSubmit = mockSubmit[ 2, "Late" ] },
        Module[ { time, result },
            { time, result } = AbsoluteTiming @ Wolfram`Chatbook`Common`llmSynthesize[
                "Hi",
                <| |>,
                TimeConstraint   -> 0.25,
                "ReturnFailures" -> True
            ];
            (* The task should have been removed, so the callback should never be called: *)
            yieldFor[ 2.5 ];
            { result, time, submitCount, firedCount }
        ]
    ],
    { Failure[ "TimedOut", _ ], _? (Between[ { 0.25, 1.5 } ]), 1, 0 },
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesize-TimeConstraint"
]

VerificationTest[
    Block[
        {
            submitCount = 0,
            firedCount  = 0,
            Wolfram`Chatbook`Common`llmSynthesizeSubmit = mockSubmit[ 0.01, $invalidResponse ]
        },
        Module[ { time, result },
            { time, result } = AbsoluteTiming @ Wolfram`Chatbook`Common`llmSynthesize[
                "Hi",
                <| |>,
                TimeConstraint   -> 5,
                "MaxAttempts"    -> 2,
                "ReturnFailures" -> True
            ];
            { result, time, submitCount }
        ]
    ],
    { $invalidResponse, _? (Between[ { 1, 3 } ]), 2 },
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesize-MaxAttempts"
]

(* Don't retry if the pause before the next attempt would go past the deadline: *)
VerificationTest[
    Block[
        {
            submitCount = 0,
            firedCount  = 0,
            Wolfram`Chatbook`Common`llmSynthesizeSubmit = mockSubmit[ 0.01, $invalidResponse ]
        },
        Module[ { time, result },
            { time, result } = AbsoluteTiming @ Wolfram`Chatbook`Common`llmSynthesize[
                "Hi",
                <| |>,
                TimeConstraint   -> 0.5,
                "MaxAttempts"    -> 2,
                "ReturnFailures" -> True
            ];
            { result, time, submitCount }
        ]
    ],
    { $invalidResponse, _? (LessThan[ 0.5 ]), 1 },
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesize-MaxAttempts-Deadline"
]

(* LLMKit subscription failures should still be written to the chat output, since the main request would also fail: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`LLMUtilities`Private`$llmSynthesizeAuthentication = "LLMKit",
            Wolfram`Chatbook`Common`llmKitCheck = Function[ Wolfram`Chatbook`Common`throwFailureToChatOutput @ $authFailure ]
        },
        Wolfram`Chatbook`Common`catchAlways[
            Wolfram`Chatbook`Common`llmSynthesize[
                "Hi",
                <| |>,
                TimeConstraint   -> 1,
                "MaxAttempts"    -> 1,
                "ReturnFailures" -> True
            ];
            "NotThrown"
        ]
    ],
    $authFailure,
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesize-LLMKitCheckFailure"
]

VerificationTest[
    Block[
        { submitCount = 0, firedCount = 0, Wolfram`Chatbook`Common`llmSynthesizeSubmit = mockSubmit[ 5, "Late" ] },
        Module[ { abortTask, result },
            abortTask = SessionSubmit @ ScheduledTask[ Abort[ ], { 0.25 } ];
            result = AbsoluteTiming @ CheckAbort[
                Wolfram`Chatbook`Common`llmSynthesize[ "Hi", <| |>, TimeConstraint -> 3, "ReturnFailures" -> True ],
                "Aborted"
            ];
            Quiet @ TaskRemove @ { abortTask, $lastMockTask };
            result
        ]
    ],
    { _? (LessThan[ 1.5 ]), "Aborted" },
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesize-Abort"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FilterSnippets Fallback*)
VerificationTest[
    unfiltered = RelatedDocumentation[ $query, "Prompt", "FilterResults" -> False, "MaxItems" -> 5 ],
    _String? (StringStartsQ[ $unfilteredHeader ]),
    SameTest -> MatchQ,
    TestID   -> "FilterSnippets-Unfiltered"
]

(* When filtering times out, the result should be the same as if filtering was disabled: *)
VerificationTest[
    Block[
        {
            submitCount = 0,
            firedCount  = 0,
            Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$filterSnippetsTimeConstraint = 0.25,
            Wolfram`Chatbook`Common`llmSynthesizeSubmit = mockSubmit[ 10, "Late" ]
        },
        Unset @ $ChatTimingData;
        Module[ { time, result },
            { time, result } = AbsoluteTiming @ RelatedDocumentation[
                $query,
                "Prompt",
                "FilterResults" -> True,
                "MaxItems"      -> 5,
                "FilteredCount" -> 5
            ];
            {
                result === unfiltered,
                time,
                submitCount,
                MemberQ[ Lookup[ $ChatTimingData, "Tag" ], "FilterSnippetsFallback:TimedOut" ]
            }
        ]
    ],
    { True, _? (LessThan[ 5 ]), 1, True },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippets-Fallback-TimedOut"
]

VerificationTest[
    Block[
        {
            submitCount = 0,
            firedCount  = 0,
            Wolfram`Chatbook`Common`llmSynthesizeSubmit = mockSubmit[ 0.01, $invalidResponse ]
        },
        {
            RelatedDocumentation[ $query, "Prompt", "FilterResults" -> True, "MaxItems" -> 5, "FilteredCount" -> 5 ],
            submitCount
        }
    ],
    { unfiltered, 2 },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippets-Fallback-InvalidResponse"
]

(* The fallback should only include the top FilteredCount unfiltered results: *)
VerificationTest[
    Module[ { unfiltered20, fallback, split },
        unfiltered20 = RelatedDocumentation[ $query, "Prompt", "FilterResults" -> False, "MaxItems" -> 20 ];
        fallback = Block[
            {
                submitCount = 0,
                firedCount  = 0,
                Wolfram`Chatbook`Common`llmSynthesizeSubmit = mockSubmit[ 0.01, $invalidResponse ]
            },
            RelatedDocumentation[ $query, "Prompt", "FilterResults" -> True, "MaxItems" -> 20, "FilteredCount" -> 3 ]
        ];
        split = StringTrim @ StringSplit[ StringDelete[ #, StartOfString ~~ $unfilteredHeader ], $snippetDelimiter ] &;
        {
            StringStartsQ[ fallback, $unfilteredHeader ],
            Length @ split @ fallback,
            split @ fallback === Take[ split @ unfiltered20, 3 ]
        }
    ],
    { True, 3, True },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippets-Fallback-FilteredCount"
]

(* A successful filter response should still be used: *)
VerificationTest[
    Module[ { uri, id, result },
        uri = First @ RelatedDocumentation[ $query, "Values", 5 ];
        id = Wolfram`Chatbook`Common`uriToSnippetID @ uri;
        result = Block[
            {
                submitCount = 0,
                firedCount  = 0,
                Wolfram`Chatbook`Common`llmSynthesizeSubmit = mockSubmit[ 0.01, "Computational\n5 " <> id ]
            },
            RelatedDocumentation[ $query, "Prompt", "FilterResults" -> True, "MaxItems" -> 5, "FilteredCount" -> 5 ]
        ];
        { StringStartsQ[ result, $filteredHeader ], StringContainsQ[ result, uri ], result === unfiltered }
    ],
    { True, True, False },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippets-Success"
]

(* LLMKit subscription failures should not fall back to unfiltered results: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`LLMUtilities`Private`$llmSynthesizeAuthentication = "LLMKit",
            Wolfram`Chatbook`Common`llmKitCheck = Function[ Wolfram`Chatbook`Common`throwFailureToChatOutput @ $authFailure ]
        },
        RelatedDocumentation[ $query, "Prompt", "FilterResults" -> True, "MaxItems" -> 5, "FilteredCount" -> 5 ]
    ],
    $authFailure,
    SameTest -> MatchQ,
    TestID   -> "FilterSnippets-LLMKitCheckFailure"
]

(* :!CodeAnalysis::EndBlock:: *)
