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

(* Coverage for the OpenAI Responses endpoint transition: the endpoint resolver's decision table, the
   reasoning effort clamp, the summary request, and the mapping of structured reasoning onto the
   <think> envelope.

   Everything here is deliberately network-free *and* gate-free. The compatibility gate
   ($responsesEndpointAvailable) is False wherever the installed LLMFunctions predates 2.4, which
   includes CI, and LLMServices`RegisteredServiceQ fails there too, so forcing the flag is not
   enough. The service check is therefore stubbed at responsesServiceQ, and everything else is
   exercised through arguments rather than through resolved settings. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*responsesEndpointQ*)

(* The rollback switch wins before any support check runs, so this needs no stub: *)
VerificationTest[
    Wolfram`Chatbook`Common`responsesEndpointQ[ "ChatCompletions", "OpenAI", "GPT54Plus" ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ResponsesEndpointQ-RollbackWins@@Tests/ResponsesEndpoint.wlt:36,1-41,2"
]

(* Anything short of a fully resolved model spec falls back, whatever the setting says: *)
VerificationTest[
    Wolfram`Chatbook`Common`responsesEndpointQ[ #, "gpt-5.6" ] & /@ {
        Automatic,
        "Responses",
        "ChatCompletions"
    },
    { False, False, False },
    SameTest -> MatchQ,
    TestID   -> "ResponsesEndpointQ-UnresolvedModelSpec@@Tests/ResponsesEndpoint.wlt:44,1-53,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`responsesEndpointQ[
        Automatic,
        (* no "Family" key, so not a resolved spec: *)
        <| "Service" -> "OpenAI", "Name" -> "gpt-5.6" |>
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ResponsesEndpointQ-ModelSpecMissingFamily@@Tests/ResponsesEndpoint.wlt:55,1-64,2"
]

(* The full decision table, with the service check stubbed so it does not depend on the installed
   LLMFunctions. "OpenAI" stands for a service that provides the endpoint; "Groq" for one that
   does not. *)
VerificationTest[
    Block[
        { Wolfram`Chatbook`SendChat`Private`responsesServiceQ = Function[ # === "OpenAI" ] },
        Wolfram`Chatbook`Common`responsesEndpointQ @@@ {
            (* Automatic: needs both a supporting service and an opted-in family. Both families
               are pinned here so that a new family forgotten in $responsesEndpointFamilies fails
               the suite instead of silently falling back to chat completions. *)
            { Automatic, "OpenAI", "GPT54Plus" },
            { Automatic, "OpenAI", "GPT56Plus" },
            { Automatic, "OpenAI", "GPT5"      },
            { Automatic, "Groq"  , "GPT54Plus" },

            (* Forcing skips the family opt-in but not the service check *)
            { "Responses", "OpenAI", "GPT54Plus" },
            { "Responses", "OpenAI", "GPT5"      },
            { "Responses", "Groq"  , "GPT54Plus" },

            (* The rollback switch always wins *)
            { "ChatCompletions", "OpenAI", "GPT54Plus" },

            (* An unrecognized value is not validated anywhere, and falls back *)
            { "responses", "OpenAI", "GPT54Plus" },
            { None       , "OpenAI", "GPT54Plus" }
        }
    ],
    {
        True , True , False, False,
        True , True , False,
        False,
        False, False
    },
    SameTest -> MatchQ,
    TestID   -> "ResponsesEndpointQ-DecisionTable@@Tests/ResponsesEndpoint.wlt:69,1-102,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*resolveChatEndpoint*)

(* The decision maps onto one pair of endpoint symbols, and the same pair serves the synchronous and
   the streaming path, so a chat cannot mix endpoints. Compared against the endpoint associations
   themselves rather than against LLMServices symbol names, since naming them here would autoload
   the paclet. *)
VerificationTest[
    Block[
        { Wolfram`Chatbook`SendChat`Private`responsesServiceQ = Function[ # === "OpenAI" ] },
        Wolfram`Chatbook`SendChat`Private`resolveChatEndpoint /@ {
            <| "Endpoint" -> Automatic         , "Model" -> <| "Service" -> "OpenAI", "Family" -> "GPT54Plus" |> |>,
            <| "Endpoint" -> "ChatCompletions" , "Model" -> <| "Service" -> "OpenAI", "Family" -> "GPT54Plus" |> |>
        }
    ],
    {
        Wolfram`Chatbook`SendChat`Private`$responsesEndpoint,
        Wolfram`Chatbook`SendChat`Private`$completionsEndpoint
    },
    SameTest -> MatchQ,
    TestID   -> "ResolveChatEndpoint-BothPairs@@Tests/ResponsesEndpoint.wlt:112,1-126,2"
]

VerificationTest[
    Keys /@ {
        Wolfram`Chatbook`SendChat`Private`$responsesEndpoint,
        Wolfram`Chatbook`SendChat`Private`$completionsEndpoint
    },
    { { "Synchronous", "Streaming" }, { "Synchronous", "Streaming" } },
    SameTest -> MatchQ,
    TestID   -> "ResolveChatEndpoint-PairShape@@Tests/ResponsesEndpoint.wlt:128,1-136,2"
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
    TestID   -> "ResolveReasoningEffort-NoDeclaredLevels@@Tests/ResponsesEndpoint.wlt:147,1-154,2"
]

(* A level the family accepts is used as-is, and the family's own spelling is returned: *)
VerificationTest[
    Wolfram`Chatbook`Common`resolveReasoningEffort[ #, { "None", "Low", "Medium", "High" } ] & /@ {
        "None", "Low", "medium", "HIGH"
    },
    { "None", "Low", "Medium", "High" },
    SameTest -> MatchQ,
    TestID   -> "ResolveReasoningEffort-AcceptedLevels@@Tests/ResponsesEndpoint.wlt:157,1-164,2"
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
    TestID   -> "ResolveReasoningEffort-ClampOffToWeakest@@Tests/ResponsesEndpoint.wlt:169,1-176,2"
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
    TestID   -> "ResolveReasoningEffort-ClampNearest@@Tests/ResponsesEndpoint.wlt:180,1-190,2"
]

(* A spelling that is not on the scale at all is passed through, so a typo still reaches the service
   and still reports an error rather than silently becoming the default: *)
VerificationTest[
    Wolfram`Chatbook`Common`resolveReasoningEffort[ #, { "None", "Low", "Medium", "High" } ] & /@ {
        "Higgh", "ultra", ""
    },
    { "Higgh", "ultra", "" },
    SameTest -> MatchQ,
    TestID   -> "ResolveReasoningEffort-UnknownSpellingPassesThrough@@Tests/ResponsesEndpoint.wlt:194,1-201,2"
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
    TestID   -> "ResolveReasoningEffort-NonStringValues@@Tests/ResponsesEndpoint.wlt:204,1-223,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ReasoningEfforts declaration*)

(* The levels each model actually accepts, through the pure five-argument form so that no model spec
   has to be resolved. Verified against the OpenAI model pages: gpt-5.4 and gpt-5.5 accept none, low,
   medium, high and xhigh, declared on GPT54Plus; the 5.6 generation accepts max as well, declared
   once on GPT56Plus so that every snapshot of the generation inherits it. A delta that belongs to
   one model rather than a generation stays on its BaseID -- see GPT56Cyber's window in Settings.wl. *)
VerificationTest[
    Wolfram`Chatbook`Common`autoModelSetting[ ##, "ReasoningEfforts" ] & @@@ {
        { "OpenAI", "gpt-5.4"      , "GPT54"     , "GPT54Plus" },
        { "OpenAI", "gpt-5.5"      , "GPT55"     , "GPT54Plus" },
        { "OpenAI", "gpt-5.6"      , "GPT56"     , "GPT56Plus" },
        { "OpenAI", "gpt-5.6-sol"  , "GPT56Sol"  , "GPT56Plus" },
        { "OpenAI", "gpt-5.6-terra", "GPT56Terra", "GPT56Plus" },
        { "OpenAI", "gpt-5.6-luna" , "GPT56Luna" , "GPT56Plus" },
        { "OpenAI", "gpt-5.6-cyber", "GPT56Cyber", "GPT56Plus" }
    },
    {
        { "None", "Low", "Medium", "High", "XHigh" },
        { "None", "Low", "Medium", "High", "XHigh" },
        { "None", "Low", "Medium", "High", "XHigh", "Max" },
        { "None", "Low", "Medium", "High", "XHigh", "Max" },
        { "None", "Low", "Medium", "High", "XHigh", "Max" },
        { "None", "Low", "Medium", "High", "XHigh", "Max" },
        { "None", "Low", "Medium", "High", "XHigh", "Max" }
    },
    SameTest -> MatchQ,
    TestID   -> "ReasoningEfforts-DeclaredPerModel@@Tests/ResponsesEndpoint.wlt:234,1-255,2"
]

(* The classifier pins gpt-5.4 and gpt-5.5 to GPT54Plus, gives the 5.6 line its own family, and aims
   the forward catch-all at that latest generation, so an unreleased gpt-5.x inherits the newest
   known levels -- including "Max" -- and the endpoint opt-in, rather than a conservative subset.
   A future generation that ships with less would need an explicit family of its own: *)
VerificationTest[
    Lookup[
        Wolfram`Chatbook`Common`resolveFullModelSpec @ <| "Service" -> "OpenAI", "Name" -> # |>,
        "Family"
    ] & /@ { "gpt-5.4", "gpt-5.5", "gpt-5.6", "gpt-5.6-sol", "gpt-5.7" },
    { "GPT54Plus", "GPT54Plus", "GPT56Plus", "GPT56Plus", "GPT56Plus" },
    SameTest -> MatchQ,
    TestID   -> "ModelFamilies-GenerationClasses@@Tests/ResponsesEndpoint.wlt:261,1-269,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`autoModelSetting[ ##, "ReasoningEfforts" ] & @@@ {
        { "OpenAI", "gpt-5.7", "GPT57", "GPT56Plus" }
    },
    {
        { "None", "Low", "Medium", "High", "XHigh", "Max" }
    },
    SameTest -> MatchQ,
    TestID   -> "ReasoningEfforts-FutureModelsInheritTheLatestGeneration@@Tests/ResponsesEndpoint.wlt:271,1-280,2"
]

(* The regression this section guards: "XHigh" used to clamp down to "High" on every gpt-5.x because
   no family declared it, and "Max" was not on the scale at all, so it reached the service verbatim
   and was rejected. Now xhigh survives on 5.6, and max clamps to the strongest level 5.5 has: *)
VerificationTest[
    {
        Wolfram`Chatbook`Common`resolveReasoningEffort[ "xhigh", { "None", "Low", "Medium", "High", "XHigh", "Max" } ],
        Wolfram`Chatbook`Common`resolveReasoningEffort[ "max"  , { "None", "Low", "Medium", "High", "XHigh", "Max" } ],
        Wolfram`Chatbook`Common`resolveReasoningEffort[ "max"  , { "None", "Low", "Medium", "High", "XHigh" } ],
        Wolfram`Chatbook`Common`resolveReasoningEffort[ "Max"  , { "Low", "Medium", "High" } ]
    },
    { "XHigh", "Max", "XHigh", "High" },
    SameTest -> MatchQ,
    TestID   -> "ReasoningEfforts-XHighAndMaxResolve@@Tests/ResponsesEndpoint.wlt:285,1-295,2"
]

(* The invariant that keeps the two lists from drifting apart: a level a family declares but the
   scale does not know cannot be reached by clamping, because clampReasoningEffort only considers
   levels that have an index. Any new level must be added to $reasoningEffortScale as well: *)
VerificationTest[
    Complement[
        Union @ Flatten @ Cases[
            Wolfram`Chatbook`Settings`Private`$modelAutoSettings,
            KeyValuePattern[ "ReasoningEfforts" -> levels_List ] :> levels,
            Infinity
        ],
        Wolfram`Chatbook`Settings`Private`$reasoningEffortScale
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ReasoningEfforts-ScaleCoversEveryDeclaredLevel@@Tests/ResponsesEndpoint.wlt:300,1-312,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*requestReasoningSummary*)

(* The Responses endpoint returns an encrypted reasoning blob and no readable summary unless one is
   requested, so an effort level becomes an association carrying the summary request: *)
VerificationTest[
    Wolfram`Chatbook`SendChat`Private`requestReasoningSummary /@ { "Medium", "high", "Minimal" },
    {
        <| "effort" -> "medium" , "summary" -> "auto" |>,
        <| "effort" -> "high"   , "summary" -> "auto" |>,
        <| "effort" -> "minimal", "summary" -> "auto" |>
    },
    SameTest -> MatchQ,
    TestID   -> "RequestReasoningSummary-EffortBecomesAssociation@@Tests/ResponsesEndpoint.wlt:320,1-329,2"
]

(* Reasoning is off, so there is nothing to summarize: *)
VerificationTest[
    Wolfram`Chatbook`SendChat`Private`requestReasoningSummary /@ { "None", "none", "NONE" },
    { "None", "none", "NONE" },
    SameTest -> MatchQ,
    TestID   -> "RequestReasoningSummary-OffIsUntouched@@Tests/ResponsesEndpoint.wlt:332,1-337,2"
]

(* An association the caller supplied keeps whatever it already specifies. "Summary" and "summary"
   are the same key on the wire, since the endpoint lowercases parameter keys, so the check has to
   be case-insensitive or the key would be double-specified: *)
VerificationTest[
    Wolfram`Chatbook`SendChat`Private`requestReasoningSummary /@ {
        <| "effort" -> "high", "summary" -> "detailed" |>,
        <| "effort" -> "high", "Summary" -> "detailed" |>,
        <| "effort" -> "none" |>,
        <| "Effort" -> "None" |>,
        <| "enabled" -> False |>
    },
    {
        <| "effort" -> "high", "summary" -> "detailed" |>,
        <| "effort" -> "high", "Summary" -> "detailed" |>,
        <| "effort" -> "none" |>,
        <| "Effort" -> "None" |>,
        <| "enabled" -> False |>
    },
    SameTest -> MatchQ,
    TestID   -> "RequestReasoningSummary-CallerOwnedAssociations@@Tests/ResponsesEndpoint.wlt:342,1-359,2"
]

(* An association with reasoning on and no summary of its own gets the request merged in: *)
VerificationTest[
    Wolfram`Chatbook`SendChat`Private`requestReasoningSummary @ <| "effort" -> "high" |>,
    <| "effort" -> "high", "summary" -> "auto" |>,
    SameTest -> MatchQ,
    TestID   -> "RequestReasoningSummary-MergesIntoAssociation@@Tests/ResponsesEndpoint.wlt:362,1-367,2"
]

(* Everything else is passed through, including the absent-key Missing that DeleteMissing drops in
   makeLLMConfiguration -- that is what preserves today's behaviour for models with no reasoning: *)
VerificationTest[
    Wolfram`Chatbook`SendChat`Private`requestReasoningSummary /@ {
        Automatic,
        Inherited,
        None,
        False,
        Missing[ "NotSupported" ],
        Missing[ "KeyAbsent", "Reasoning" ],
        Quantity[ 1024, "Tokens" ]
    },
    {
        Automatic,
        Inherited,
        None,
        False,
        Missing[ "NotSupported" ],
        Missing[ "KeyAbsent", "Reasoning" ],
        Quantity[ 1024, "Tokens" ]
    },
    SameTest -> MatchQ,
    TestID   -> "RequestReasoningSummary-PassThrough@@Tests/ResponsesEndpoint.wlt:371,1-392,2"
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
    TestID   -> "ReasoningEnvelope-SynchronousPart@@Tests/ResponsesEndpoint.wlt:399,1-414,2"
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
    TestID   -> "ReasoningEnvelope-NoSummaryNoEnvelope@@Tests/ResponsesEndpoint.wlt:420,1-436,2"
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
    TestID   -> "ReasoningEnvelope-StreamingLatch@@Tests/ResponsesEndpoint.wlt:440,1-453,2"
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
    TestID   -> "ReasoningEnvelope-FinishReasonCloses@@Tests/ResponsesEndpoint.wlt:458,1-470,2"
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
    TestID   -> "ReasoningEnvelope-NoReasoningUnchanged@@Tests/ResponsesEndpoint.wlt:473,1-483,2"
]

(* :!CodeAnalysis::EndBlock:: *)
