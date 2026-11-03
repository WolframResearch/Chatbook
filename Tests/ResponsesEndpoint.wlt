(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ResponsesEndpoint.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ResponsesEndpoint.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* Coverage for the OpenAI Responses endpoint transition: the request-method decision, the reasoning
   effort clamp, the summary request, and the mapping of structured reasoning onto the <think>
   envelope.

   Everything here is deliberately network-free *and* gate-free. The compatibility gate
   ($responsesAPIAvailable, LLMFunctions 2.4.0+ and LLMConnections 1.1.0+) is False wherever the
   installed paclets predate those versions, which includes CI, and LLMServices`Response is not
   defined there. A test that needs the gate sets it with Block inside the test, passes fully
   resolved model specs ("ResolvedModel" -> True) so that resolveFullModelSpec does not consult the
   live model list, and compares request methods as the strings "Responses" and "ChatCompletions"
   rather than naming LLMServices symbols. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*chooseRequestMethod*)

VerificationTest[
    endpointTestModel[ service_String, family_String ] := <|
        "ResolvedModel" -> True,
        "Service"       -> service,
        "Name"          -> "a-model",
        "BaseID"        -> "a-model",
        "Family"        -> family
    |>,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ChooseRequestMethod-Definitions@@Tests/ResponsesEndpoint.wlt:37,1-48,2"
]
VerificationTest[
    TrueQ @ Wolfram`Chatbook`Common`autoModelSetting[ endpointTestModel[ "OpenAI", # ], "EnableResponses" ] & /@ {
        "GPT5", "GPT51", "GPT52", "GPT53", "GPT54Plus", "GPT56Plus", "GPT4Omni", "GPT41", "O3"
    },
    { True, True, True, True, True, True, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "ChooseRequestMethod-OptInIsModelData@@Tests/ResponsesEndpoint.wlt:49,1-56,2"
]
VerificationTest[
    Function[ { gate, settings },
        Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = gate },
            Wolfram`Chatbook`Settings`Private`chooseRequestMethod @ settings
        ]
    ] @@@ {
        { True , <| "Model" -> endpointTestModel[ "OpenAI", "GPT5"      ] |> },
        { True , <| "Model" -> endpointTestModel[ "OpenAI", "GPT54Plus" ] |> },
        { True , <| "Model" -> endpointTestModel[ "OpenAI", "GPT56Plus" ] |> },
        { True , <| "Model" -> endpointTestModel[ "OpenAI", "GPT4Omni"  ] |> },
        { True , <| "Model" -> endpointTestModel[ "Groq"  , "GPT54Plus" ] |> },
        { True , <| "Model" -> endpointTestModel[ "OpenAI", "GPT56Plus" ], "Authentication" -> "LLMKit" |> },
        { False, <| "Model" -> endpointTestModel[ "OpenAI", "GPT56Plus" ] |> },
        { False, <| "Model" -> endpointTestModel[ "OpenAI", "GPT5"      ] |> }
    },
    {
        "Responses", "Responses", "Responses", "ChatCompletions", "ChatCompletions", "ChatCompletions",
        "ChatCompletions", "ChatCompletions"
    },
    SameTest -> MatchQ,
    TestID   -> "ChooseRequestMethod-DecisionTable@@Tests/ResponsesEndpoint.wlt:57,1-78,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*requestMethod*)

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True },
        Wolfram`Chatbook`Common`requestMethod /@ {
            <| "RequestMethod" -> "Responses"       |>,
            <| "RequestMethod" -> "ChatCompletions" |>,
            <| "RequestMethod" -> Automatic         |>,
            <| |>
        }
    ],
    { "Responses", "ChatCompletions", "ChatCompletions", "ChatCompletions" },
    SameTest -> MatchQ,
    TestID   -> "RequestMethod-ResolvedValues@@Tests/ResponsesEndpoint.wlt:84,1-96,2"
]
VerificationTest[
    SymbolName /@ {
        Wolfram`Chatbook`SendChat`Private`chatFunction[ "ChatCompletions" ],
        Wolfram`Chatbook`SendChat`Private`chatFunction[ "Responses" ],
        Wolfram`Chatbook`SendChat`Private`chatSubmitFunction[ "ChatCompletions" ],
        Wolfram`Chatbook`SendChat`Private`chatSubmitFunction[ "Responses" ]
    },
    { "Chat", "Response", "ChatSubmit", "ResponseSubmit" },
    SameTest -> MatchQ,
    TestID   -> "RequestMethod-EndpointFunctions@@Tests/ResponsesEndpoint.wlt:97,1-107,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*resolveReasoningEffort*)

(* Tested through the two-argument form, which takes the family's declared levels directly, so no
   model resolution and no $modelAutoSettings lookup is involved. *)

(* A family that declares no levels is left exactly as it was -- this is every service other than
   the GPT-5 families, including xAI Grok3's "Reasoning" -> False: *)
VerificationTest[
    Wolfram`Chatbook`Common`resolveReasoningEffort[ #, Missing[ "NotFound" ] ] & /@ {
        "None", "Medium", "XHigh", False, None, Automatic, Missing[ "NotSupported" ]
    },
    { "None", "Medium", "XHigh", False, None, Automatic, Missing[ "NotSupported" ] },
    SameTest -> MatchQ,
    TestID   -> "ResolveReasoningEffort-NoDeclaredLevels@@Tests/ResponsesEndpoint.wlt:118,1-125,2"
]

(* A level the family accepts is used as-is, and the family's own spelling is returned: *)
VerificationTest[
    Wolfram`Chatbook`Common`resolveReasoningEffort[ #, { "None", "Low", "Medium", "High" } ] & /@ {
        "None", "Low", "medium", "HIGH"
    },
    { "None", "Low", "Medium", "High" },
    SameTest -> MatchQ,
    TestID   -> "ResolveReasoningEffort-AcceptedLevels@@Tests/ResponsesEndpoint.wlt:128,1-135,2"
]

(* Off, however it is spelled, on a family that has no "None": clamped to the weakest level rather
   than dropped, because dropping the parameter means the vendor default, which for GPT-5.x is
   medium -- that would invert a request to turn reasoning off: *)
VerificationTest[
    Wolfram`Chatbook`Common`resolveReasoningEffort[ #, { "Low", "Medium", "High" } ] & /@ {
        "None", "none", "Off", "off", False, None
    },
    { "Low", "Low", "Low", "Low", "Low", "Low" },
    SameTest -> MatchQ,
    TestID   -> "ResolveReasoningEffort-ClampOffToWeakest@@Tests/ResponsesEndpoint.wlt:140,1-147,2"
]

(* An unsupported level clamps to the nearest declared one, and a tie resolves upward so that
   "Minimal" never becomes "None": *)
VerificationTest[
    {
        Wolfram`Chatbook`Common`resolveReasoningEffort[ "XHigh"  , { "None", "Low", "Medium", "High" } ],
        Wolfram`Chatbook`Common`resolveReasoningEffort[ "Minimal", { "None", "Low", "Medium", "High" } ],
        Wolfram`Chatbook`Common`resolveReasoningEffort[ "Minimal", { "Low", "Medium", "High" } ],
        Wolfram`Chatbook`Common`resolveReasoningEffort[ "None"   , { "Minimal", "Low", "Medium", "High" } ]
    },
    { "High", "Low", "Low", "Minimal" },
    SameTest -> MatchQ,
    TestID   -> "ResolveReasoningEffort-ClampNearest@@Tests/ResponsesEndpoint.wlt:151,1-161,2"
]

(* A spelling that is not on the scale at all is passed through, so a typo still reaches the service
   and still reports an error rather than silently becoming the default: *)
VerificationTest[
    Wolfram`Chatbook`Common`resolveReasoningEffort[ #, { "None", "Low", "Medium", "High" } ] & /@ {
        "Higgh", "ultra", ""
    },
    { "Higgh", "ultra", "" },
    SameTest -> MatchQ,
    TestID   -> "ResolveReasoningEffort-UnknownSpellingPassesThrough@@Tests/ResponsesEndpoint.wlt:165,1-172,2"
]

(* Non-string values other than the off spellings are never clamped: *)
VerificationTest[
    Wolfram`Chatbook`Common`resolveReasoningEffort[ #, { "None", "Low", "Medium", "High" } ] & /@ {
        Automatic,
        Inherited,
        Missing[ "NotSupported" ],
        Missing[ "KeyAbsent", "Reasoning" ],
        <| "effort" -> "none" |>,
        Quantity[ 1024, "Tokens" ]
    },
    {
        Automatic,
        Inherited,
        Missing[ "NotSupported" ],
        Missing[ "KeyAbsent", "Reasoning" ],
        <| "effort" -> "none" |>,
        Quantity[ 1024, "Tokens" ]
    },
    SameTest -> MatchQ,
    TestID   -> "ResolveReasoningEffort-NonStringValues@@Tests/ResponsesEndpoint.wlt:175,1-194,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*requestReasoningSummaries*)

VerificationTest[
    summarySettings[ method_, family_, reasoning_ ] := <|
        "RequestMethod" -> method,
        "Reasoning"     -> reasoning,
        "Model"         -> endpointTestModel[ "OpenAI", family ]
    |>,
    Null,
    SameTest -> MatchQ,
    TestID   -> "RequestReasoningSummaries-Definitions@@Tests/ResponsesEndpoint.wlt:200,1-209,2"
]
VerificationTest[
    Wolfram`Chatbook`SendChat`Private`requestReasoningSummaries[ summarySettings[ "Responses", #1, #2 ] ][ "Reasoning" ] & @@@ {
        { "GPT54Plus", "Medium"  },
        { "GPT54Plus", "high"    },
        { "GPT5"     , "Minimal" }
    },
    {
        <| "effort" -> "medium" , "summary" -> "auto" |>,
        <| "effort" -> "high"   , "summary" -> "auto" |>,
        <| "effort" -> "minimal", "summary" -> "auto" |>
    },
    SameTest -> MatchQ,
    TestID   -> "RequestReasoningSummaries-EffortBecomesAssociation@@Tests/ResponsesEndpoint.wlt:210,1-223,2"
]
VerificationTest[
    Wolfram`Chatbook`SendChat`Private`requestReasoningSummaries[ summarySettings[ "Responses", "GPT54Plus", # ] ][ "Reasoning" ] & /@
        { "None", "none", "NONE" },
    { "None", "None", "None" },
    SameTest -> MatchQ,
    TestID   -> "RequestReasoningSummaries-OffIsNotExpanded@@Tests/ResponsesEndpoint.wlt:224,1-230,2"
]
VerificationTest[
    {
        Wolfram`Chatbook`SendChat`Private`requestReasoningSummaries[ summarySettings[ "Responses", "GPT54Plus", # ] ][ "Reasoning" ] & /@ {
            <| "effort" -> "high" |>,
            <| "effort" -> "high", "summary" -> "detailed" |>,
            Automatic,
            Missing[ "NotSupported" ],
            Quantity[ 1024, "Tokens" ]
        },
        Wolfram`Chatbook`SendChat`Private`requestReasoningSummaries[ summarySettings[ "ChatCompletions", "GPT54Plus", "Max" ] ][ "Reasoning" ],
        Wolfram`Chatbook`SendChat`Private`requestReasoningSummaries[ <| "RequestMethod" -> "Responses", "Reasoning" -> "High" |> ][ "Reasoning" ]
    },
    {
        {
            <| "effort" -> "high" |>,
            <| "effort" -> "high", "summary" -> "detailed" |>,
            Automatic,
            Missing[ "NotSupported" ],
            Quantity[ 1024, "Tokens" ]
        },
        "Max",
        <| "effort" -> "high", "summary" -> "auto" |>
    },
    SameTest -> MatchQ,
    TestID   -> "RequestReasoningSummaries-PassThrough@@Tests/ResponsesEndpoint.wlt:231,1-256,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Reasoning to <think>*)

(* A synchronous response arrives whole, so its envelope needs no state: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$reasoningOpen = False },
        StringJoin @ Cases[
            Wolfram`Chatbook`Common`extractBodyChunks @ <|
                "ContentChunk" -> {
                    <| "Type" -> "Reasoning", "Data" -> "weighing the options" |>,
                    <| "Type" -> "Text"     , "Data" -> "the answer"           |>
                }
            |>,
            _String
        ]
    ],
    "<think>weighing the options</think>the answer",
    SameTest -> MatchQ,
    TestID   -> "ReasoningEnvelope-SynchronousPart@@Tests/ResponsesEndpoint.wlt:263,1-278,2"
]

(* A reasoning part with no readable summary must not produce an empty envelope: an unterminated or
   empty <think> matches neither format rule and would leak its markers as visible text. This is
   what the endpoint actually returns when no summary was requested, and on tool-call turns even
   when one was: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$reasoningOpen = False },
        StringJoin @ Cases[
            Wolfram`Chatbook`Common`extractBodyChunks @ <|
                "ContentChunk" -> {
                    <| "Type" -> "Reasoning", "Data" -> "" |>,
                    <| "Type" -> "Reasoning", "Signature" -> "sig" |>,
                    <| "Type" -> "Text"     , "Data" -> "the answer" |>
                }
            |>,
            _String
        ]
    ],
    "the answer",
    SameTest -> MatchQ,
    TestID   -> "ReasoningEnvelope-NoSummaryNoEnvelope@@Tests/ResponsesEndpoint.wlt:284,1-300,2"
]

(* Streaming delivers one delta per call, so a latch opens the envelope on the first reasoning delta
   and closes it on the first item that is not reasoning: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$reasoningOpen = False },
        StringJoin @ Flatten[
            Cases[ Wolfram`Chatbook`Common`extractBodyChunks @ #, _String ] & /@ {
                <| "ReasoningChunk" -> "first "  |>,
                <| "ReasoningChunk" -> "second " |>,
                <| "ContentChunk"   -> "answer"  |>
            }
        ]
    ],
    "<think>first second </think>answer",
    SameTest -> MatchQ,
    TestID   -> "ReasoningEnvelope-StreamingLatch@@Tests/ResponsesEndpoint.wlt:304,1-317,2"
]

(* Nothing else closes the envelope if a response ends while reasoning is still open. Without this,
   Formatting.wl matches an unterminated <think> only at EndOfString and the cell would show a live
   "Thinking..." indicator forever: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$reasoningOpen = False },
        StringJoin @ Flatten[
            Cases[ Wolfram`Chatbook`Common`extractBodyChunks @ #, _String ] & /@ {
                <| "ReasoningChunk" -> "thinking" |>,
                <| "FinishReason"   -> "stop"     |>
            }
        ]
    ],
    "<think>thinking</think>",
    SameTest -> MatchQ,
    TestID   -> "ReasoningEnvelope-FinishReasonCloses@@Tests/ResponsesEndpoint.wlt:322,1-334,2"
]

(* A response with no reasoning at all is untouched, which is every provider that does not send it: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$reasoningOpen = False },
        StringJoin @ Cases[
            Wolfram`Chatbook`Common`extractBodyChunks @ <| "ContentChunk" -> "plain answer" |>,
            _String
        ]
    ],
    "plain answer",
    SameTest -> MatchQ,
    TestID   -> "ReasoningEnvelope-NoReasoningUnchanged@@Tests/ResponsesEndpoint.wlt:337,1-347,2"
]

(* :!CodeAnalysis::EndBlock:: *)
