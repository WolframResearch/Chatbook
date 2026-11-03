(* ::**************************************************************************************************************:: *)
(* # OpenAIReasoningEfforts.wl

   Reasoning-effort facts for OpenAI's GPT-5 and GPT-6 models, by request method, next to what Chatbook does with
   them.

   * Data only: nothing in `Source/` reads this file.
   * `Get[ "Developer/OpenAIReasoningEfforts.wl" ]` returns the `Association` below.

   ## Provenance

   * OpenAI's side was probed on {date} by `Scripts/CheckReasoningEfforts.wls`.
   * Chatbook's side was resolved by `Scripts/ResolvedReasoningDefault.wl` at commit `{commit}`.
     * {sourcestate}
     * LLMFunctions {llmfunctions} and LLMConnections {llmconnections} were loaded, so the Responses gate
       (`$responsesAPIAvailable`) was {gate}.

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
