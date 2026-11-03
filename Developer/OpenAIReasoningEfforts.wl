(* ::**************************************************************************************************************:: *)
(* # OpenAIReasoningEfforts.wl

   Reasoning-effort facts for OpenAI's GPT-5 and GPT-6 models, by request method, next to what Chatbook does with
   them.

   * Data only: nothing in `Source/` reads this file.
   * `Get[ "Developer/OpenAIReasoningEfforts.wl" ]` returns the `Association` below.

   ## Provenance

   * OpenAI's side was probed on 2026-10-25 by `Scripts/CheckReasoningEfforts.wls`.
   * Chatbook's side was resolved by `Scripts/ResolvedReasoningDefault.wl` at commit `68500b15`.
     * `Source/` had no uncommitted changes.
     * LLMFunctions 2.4.0 and LLMConnections 1.1.0 were loaded, so the Responses gate
       (`$responsesAPIAvailable`) was open.

   ## Keys of each entry under `"Models"`

   * `"Snapshot"`: the dated model the alias resolved to at probe time.
   * `"OpenAI"`: what the API reported, per request method.
     * `"Responses"` is `/v1/responses`, and `"ChatCompletions"` is `/v1/chat/completions`: the same names as
       Chatbook's `"RequestMethod"` values.
     * `"ReasoningEfforts"`: the levels the model accepts, in Chatbook's spellings, weakest first.
     * `"DefaultReasoning"`: the level used when a request names none.
       * The Responses endpoint reports it.
       * Chat completions never reports it. `"None"` is inferred only when three requests without an effort all
         use no reasoning tokens and three at the weakest other level all use some; otherwise it is
         `Missing[ "NotReported" ]`.
   * `"Chatbook"`: what Chatbook declares and resolves for the model (`Source/Chatbook/Settings.wl`), evaluated with
     Chatbook's own functions.
     * `"Family"` and `"BaseID"`: from `resolveFullModelSpec`. Per-model settings are keyed by `"BaseID"`.
     * `"EnableResponses"`: whether the model opts in to the Responses endpoint.
     * `"RequestMethod"`: what `chooseRequestMethod` picks with the gate open.
     * Per request method:
       * `"ReasoningEfforts"`: the declared levels Chatbook clamps `"Reasoning"` to.
         * `requestMethodReasoningEfforts` drops `"Max"` on chat completions.
       * `"Reasoning"`: the value `"Reasoning" -> Automatic` resolves to.
         * On the Responses endpoint the `"ResponsesReasoning"` model setting comes first, then the `"Reasoning"`
           model setting.
       * `"Sent"`: what `makeLLMConfiguration` sends for that value, that is
         `resolveReasoningEffort @ requestReasoningSummaries @ settings`.
   * `"Differences"`: where OpenAI and Chatbook disagree, per request method.
     * `"NotServed"`: OpenAI does not serve the model on that request method.
       * `"ChosenByChatbook"`: it is the request method Chatbook chooses.
       * `"GateShutFallback"`: it is chat completions, Chatbook's fallback when the gate is shut.
     * `"DeclaredNotAccepted"`: levels Chatbook declares that OpenAI rejects.
     * `"AcceptedNotDeclared"`: levels OpenAI accepts that Chatbook does not declare.
     * `"DefaultNotAccepted"`: the effort Chatbook sends by default, which OpenAI rejects.
     * `"NoReasoningEffort"`: `True` when OpenAI accepts no effort for the model but Chatbook sends one.

   ## Missing statuses

   A request method the probe could not check is given as just its status:

   * `Missing[ "NoAccess" ]`: the API key cannot use the model.
   * `Missing[ "Deprecated" ]`: the model is deprecated.
   * `Missing[ "NotOnEndpoint" ]`: that request method does not serve the model.
   * `Missing[ "NoReasoningEffort" ]`: the model takes no effort parameter.

   ## Refreshing

   * These are provider facts, and they go stale when OpenAI ships or retires a model.
   * To probe again and rewrite this file, run from the Chatbook directory:
     * `wolframscript -f Scripts/CheckReasoningEfforts.wls all developer=Developer/OpenAIReasoningEfforts.wl`
     * Add `out=<file>` to keep the raw results too.
   * To rewrite it from saved results without API calls, for example after a change to Chatbook:
     * `wolframscript -f Scripts/CheckReasoningEfforts.wls from=<file> developer=Developer/OpenAIReasoningEfforts.wl`
     * `<file>` is an earlier run's `out=<file>`.
   * This header comes from `Scripts/Resources/OpenAIReasoningEffortsHeader.wl`.
*)
<|
    "ProbeDate"              -> "2026-10-25",
    "ChatbookCommit"         -> "68500b159d08ecc7657d34562e40649e33d07a0f",
    "ChatbookSourceModified" -> False,
    "Paclets"                -> <| "LLMFunctions" -> "2.4.0", "LLMConnections" -> "1.1.0" |>,
    "ResponsesGate"          -> True,
    "ReasoningEffortScale"   -> { "None", "Minimal", "Low", "Medium", "High", "XHigh", "Max" },
    "Models"                 -> <|
        "gpt-5"               -> <|
            "Snapshot"    -> "gpt-5-2025-08-07",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "DefaultReasoning" -> "Medium"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "DefaultReasoning" -> Missing[ "NotReported" ]
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT5",
                "BaseID"          -> "GPT5",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "Reasoning"        -> "Minimal",
                    "Sent"             -> <| "effort" -> "minimal", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "Reasoning"        -> "Minimal",
                    "Sent"             -> "Minimal"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5-mini"          -> <|
            "Snapshot"    -> "gpt-5-mini-2025-08-07",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "DefaultReasoning" -> "Medium"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "DefaultReasoning" -> Missing[ "NotReported" ]
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT5",
                "BaseID"          -> "GPT5Mini",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "Reasoning"        -> "Minimal",
                    "Sent"             -> <| "effort" -> "minimal", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "Reasoning"        -> "Minimal",
                    "Sent"             -> "Minimal"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5-nano"          -> <|
            "Snapshot"    -> "gpt-5-nano-2025-08-07",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "DefaultReasoning" -> "Medium"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "DefaultReasoning" -> Missing[ "NotReported" ]
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT5",
                "BaseID"          -> "GPT5Nano",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "Reasoning"        -> "Minimal",
                    "Sent"             -> <| "effort" -> "minimal", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "Reasoning"        -> "Minimal",
                    "Sent"             -> "Minimal"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5-pro"           -> <|
            "Snapshot"    -> "gpt-5-pro-2025-10-06",
            "OpenAI"      -> <|
                "Responses"       -> <| "ReasoningEfforts" -> { "High" }, "DefaultReasoning" -> "High" |>,
                "ChatCompletions" -> Missing[ "NotOnEndpoint" ]
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT5",
                "BaseID"          -> "GPT5Pro",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "Reasoning"        -> <| "summary" -> "auto" |>,
                    "Sent"             -> <| "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "Reasoning"        -> <| "summary" -> "auto" |>,
                    "Sent"             -> <| "summary" -> "auto" |>
                |>
            |>,
            "Differences" -> <|
                "Responses"       -> <| "DeclaredNotAccepted" -> { "Minimal", "Low", "Medium" } |>,
                "ChatCompletions" -> <| "NotServed" -> "GateShutFallback" |>
            |>
        |>,
        "gpt-5.1"             -> <|
            "Snapshot"    -> "gpt-5.1-2025-11-13",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High" },
                    "DefaultReasoning" -> "None"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High" },
                    "DefaultReasoning" -> "None"
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT51",
                "BaseID"          -> "GPT51",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.2"             -> <|
            "Snapshot"    -> "gpt-5.2-2025-12-11",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> "None"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> "None"
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT52",
                "BaseID"          -> "GPT52",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.2-pro"         -> <|
            "Snapshot"    -> "gpt-5.2-pro-2025-12-11",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> "Medium"
                |>,
                "ChatCompletions" -> Missing[ "NotOnEndpoint" ]
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT52",
                "BaseID"          -> "GPT52Pro",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> <| "summary" -> "auto" |>,
                    "Sent"             -> <| "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> <| "summary" -> "auto" |>,
                    "Sent"             -> <| "summary" -> "auto" |>
                |>
            |>,
            "Differences" -> <|
                "Responses"       -> <| "DeclaredNotAccepted" -> { "None", "Low" } |>,
                "ChatCompletions" -> <| "NotServed" -> "GateShutFallback" |>
            |>
        |>,
        "gpt-5.3-codex"       -> <|
            "Snapshot"    -> "gpt-5.3-codex",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> "None"
                |>,
                "ChatCompletions" -> Missing[ "NotOnEndpoint" ]
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT53",
                "BaseID"          -> "GPT53Codex",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <|
                "ChatCompletions" -> <| "NotServed" -> "GateShutFallback" |>
            |>
        |>,
        "gpt-5.4"             -> <|
            "Snapshot"    -> "gpt-5.4-2026-03-05",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> "None"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> "None"
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT54Plus",
                "BaseID"          -> "GPT54",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> <| "effort" -> "medium", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.4-mini"        -> <|
            "Snapshot"    -> "gpt-5.4-mini-2026-03-17",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> "None"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> "None"
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT54Plus",
                "BaseID"          -> "GPT54Mini",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> <| "effort" -> "medium", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.4-nano"        -> <|
            "Snapshot"    -> "gpt-5.4-nano-2026-03-17",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> "None"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> "None"
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT54Plus",
                "BaseID"          -> "GPT54Nano",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> <| "effort" -> "medium", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.4-pro"         -> <|
            "Snapshot"    -> "gpt-5.4-pro-2026-03-05",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> "Medium"
                |>,
                "ChatCompletions" -> Missing[ "NotOnEndpoint" ]
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT54Plus",
                "BaseID"          -> "GPT54Pro",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> <| "summary" -> "auto" |>,
                    "Sent"             -> <| "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> <| "summary" -> "auto" |>,
                    "Sent"             -> <| "summary" -> "auto" |>
                |>
            |>,
            "Differences" -> <|
                "Responses"       -> <| "DeclaredNotAccepted" -> { "None", "Low" } |>,
                "ChatCompletions" -> <| "NotServed" -> "GateShutFallback" |>
            |>
        |>,
        "gpt-5.5"             -> <|
            "Snapshot"    -> "gpt-5.5-2026-04-23",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> "Medium"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> Missing[ "NotReported" ]
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT54Plus",
                "BaseID"          -> "GPT55",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> <| "effort" -> "medium", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.5-pro"         -> <|
            "Snapshot"    -> "gpt-5.5-pro-2026-04-23",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> "High"
                |>,
                "ChatCompletions" -> Missing[ "NotOnEndpoint" ]
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT54Plus",
                "BaseID"          -> "GPT55Pro",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> <| "summary" -> "auto" |>,
                    "Sent"             -> <| "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> <| "summary" -> "auto" |>,
                    "Sent"             -> <| "summary" -> "auto" |>
                |>
            |>,
            "Differences" -> <|
                "Responses"       -> <| "DeclaredNotAccepted" -> { "None", "Low" } |>,
                "ChatCompletions" -> <| "NotServed" -> "GateShutFallback" |>
            |>
        |>,
        "gpt-5.6"             -> <|
            "Snapshot"    -> "gpt-5.6-sol",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "DefaultReasoning" -> "Medium"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> Missing[ "NotReported" ]
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT56Plus",
                "BaseID"          -> "GPT56",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> <| "effort" -> "medium", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.6-sol"         -> <|
            "Snapshot"    -> "gpt-5.6-sol",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "DefaultReasoning" -> "Medium"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> Missing[ "NotReported" ]
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT56Plus",
                "BaseID"          -> "GPT56Sol",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> <| "effort" -> "medium", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.6-terra"       -> <|
            "Snapshot"    -> "gpt-5.6-terra",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "DefaultReasoning" -> "Medium"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> Missing[ "NotReported" ]
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT56Plus",
                "BaseID"          -> "GPT56Terra",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> <| "effort" -> "medium", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.6-luna"        -> <|
            "Snapshot"    -> "gpt-5.6-luna",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "DefaultReasoning" -> "Medium"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> Missing[ "NotReported" ]
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT56Plus",
                "BaseID"          -> "GPT56Luna",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> <| "effort" -> "medium", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.6-cyber"       -> <|
            "Snapshot"    -> Missing[ "NotAvailable" ],
            "OpenAI"      -> <| "Responses" -> Missing[ "NoAccess" ], "ChatCompletions" -> Missing[ "NoAccess" ] |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT56Plus",
                "BaseID"          -> "GPT56Cyber",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> <| "effort" -> "medium", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-6-astra"         -> <|
            "Snapshot"    -> "gpt-6-astra",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Low", "Medium", "High", "XHigh", "Max" },
                    "DefaultReasoning" -> "Medium"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> Missing[ "NotReported" ]
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT56Plus",
                "BaseID"          -> "GPT6Astra",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> <| "effort" -> "medium", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <|
                "Responses"       -> <| "DeclaredNotAccepted" -> { "None" } |>,
                "ChatCompletions" -> <| "DeclaredNotAccepted" -> { "None" }, "DefaultNotAccepted" -> "None" |>
            |>
        |>,
        "gpt-6-sol"           -> <|
            "Snapshot"    -> "gpt-6-sol",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "DefaultReasoning" -> "Medium"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> Missing[ "NotReported" ]
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT56Plus",
                "BaseID"          -> "GPT6Sol",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> <| "effort" -> "medium", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-6-luna"          -> <|
            "Snapshot"    -> "gpt-6-luna",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "DefaultReasoning" -> "Medium"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> Missing[ "NotReported" ]
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT56Plus",
                "BaseID"          -> "GPT6Luna",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> <| "effort" -> "medium", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.1-chat-latest" -> <|
            "Snapshot"    -> Missing[ "NotAvailable" ],
            "OpenAI"      -> <| "Responses" -> Missing[ "NoAccess" ], "ChatCompletions" -> Missing[ "Deprecated" ] |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT51",
                "BaseID"          -> "GPT51Chat",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.1-codex"       -> <|
            "Snapshot"    -> Missing[ "NotAvailable" ],
            "OpenAI"      -> <| "Responses" -> Missing[ "NoAccess" ], "ChatCompletions" -> Missing[ "Deprecated" ] |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT51",
                "BaseID"          -> "GPT51Codex",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.1-codex-max"   -> <|
            "Snapshot"    -> Missing[ "NotAvailable" ],
            "OpenAI"      -> <| "Responses" -> Missing[ "NoAccess" ], "ChatCompletions" -> Missing[ "Deprecated" ] |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT51",
                "BaseID"          -> "GPT51CodexMax",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.1-codex-mini"  -> <|
            "Snapshot"    -> Missing[ "NotAvailable" ],
            "OpenAI"      -> <| "Responses" -> Missing[ "NoAccess" ], "ChatCompletions" -> Missing[ "Deprecated" ] |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT51",
                "BaseID"          -> "GPT51CodexMini",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.2-chat-latest" -> <|
            "Snapshot"    -> Missing[ "NotAvailable" ],
            "OpenAI"      -> <| "Responses" -> Missing[ "NoAccess" ], "ChatCompletions" -> Missing[ "Deprecated" ] |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT52",
                "BaseID"          -> "GPT52Chat",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.2-codex"       -> <|
            "Snapshot"    -> Missing[ "NotAvailable" ],
            "OpenAI"      -> <| "Responses" -> Missing[ "NoAccess" ], "ChatCompletions" -> Missing[ "Deprecated" ] |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT52",
                "BaseID"          -> "GPT52Codex",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5.3-chat-latest" -> <|
            "Snapshot"    -> Missing[ "NotAvailable" ],
            "OpenAI"      -> <| "Responses" -> Missing[ "NoAccess" ], "ChatCompletions" -> Missing[ "Deprecated" ] |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT53Chat",
                "BaseID"          -> "GPT53Chat",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Low", "Medium", "High" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> <| "effort" -> "medium", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "Low", "Medium", "High" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> "Medium"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5-chat-latest"   -> <|
            "Snapshot"    -> Missing[ "NotAvailable" ],
            "OpenAI"      -> <| "Responses" -> Missing[ "NoAccess" ], "ChatCompletions" -> Missing[ "Deprecated" ] |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT5",
                "BaseID"          -> "GPT5Chat",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "Reasoning"        -> "Minimal",
                    "Sent"             -> <| "effort" -> "minimal", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "Reasoning"        -> "Minimal",
                    "Sent"             -> "Minimal"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5-codex"         -> <|
            "Snapshot"    -> Missing[ "NotAvailable" ],
            "OpenAI"      -> <| "Responses" -> Missing[ "NoAccess" ], "ChatCompletions" -> Missing[ "Deprecated" ] |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT5",
                "BaseID"          -> "GPT5Codex",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "Reasoning"        -> "Minimal",
                    "Sent"             -> <| "effort" -> "minimal", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "Reasoning"        -> "Minimal",
                    "Sent"             -> "Minimal"
                |>
            |>,
            "Differences" -> <| |>
        |>,
        "gpt-5-search-api"    -> <|
            "Snapshot"    -> Missing[ "NotAvailable" ],
            "OpenAI"      -> <|
                "Responses"       -> Missing[ "NotOnEndpoint" ],
                "ChatCompletions" -> Missing[ "NoReasoningEffort" ]
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT5",
                "BaseID"          -> "GPT5SearchApi",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "Reasoning"        -> "Minimal",
                    "Sent"             -> <| "effort" -> "minimal", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "Minimal", "Low", "Medium", "High" },
                    "Reasoning"        -> "Minimal",
                    "Sent"             -> "Minimal"
                |>
            |>,
            "Differences" -> <|
                "Responses"       -> <| "NotServed" -> "ChosenByChatbook" |>,
                "ChatCompletions" -> <| "NoReasoningEffort" -> True |>
            |>
        |>,
        "gpt-6.1-sol"         -> <|
            "Snapshot"    -> "gpt-6.1-sol",
            "OpenAI"      -> <|
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "Low", "Medium", "High", "XHigh", "Max" },
                    "DefaultReasoning" -> "Medium"
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "Low", "Medium", "High", "XHigh" },
                    "DefaultReasoning" -> Missing[ "NotReported" ]
                |>
            |>,
            "Chatbook"    -> <|
                "Family"          -> "GPT56Plus",
                "BaseID"          -> "GPT61Sol",
                "EnableResponses" -> True,
                "RequestMethod"   -> "Responses",
                "Responses"       -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh", "Max" },
                    "Reasoning"        -> "Medium",
                    "Sent"             -> <| "effort" -> "medium", "summary" -> "auto" |>
                |>,
                "ChatCompletions" -> <|
                    "ReasoningEfforts" -> { "None", "Low", "Medium", "High", "XHigh" },
                    "Reasoning"        -> "None",
                    "Sent"             -> "None"
                |>
            |>,
            "Differences" -> <|
                "Responses"       -> <| "DeclaredNotAccepted" -> { "None" } |>,
                "ChatCompletions" -> <| "DeclaredNotAccepted" -> { "None" }, "DefaultNotAccepted" -> "None" |>
            |>
        |>
    |>
|>
