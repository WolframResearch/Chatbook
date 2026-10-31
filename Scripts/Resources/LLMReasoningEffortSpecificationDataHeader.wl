(* ::**************************************************************************************************************:: *)
(* # LLMReasoningEffortSpecificationData.wl

   Reasoning-effort data for LLM models, read by LLMConnections (`LLMConnections`Defaults`$Specifications`) and,
   through it, by Chatbook. `CloudGet` of the cloud object that holds this file returns the `Association` below.

   ## Provenance

   * OpenAI's side was probed on {date} by `Scripts/CheckReasoningEfforts.wls`.
   * `"ChatbookDefault"` was resolved by `Scripts/ResolvedReasoningDefault.wl` at Chatbook commit `{commit}`, with the
     Responses gate (`$responsesAPIAvailable`) {gate}.

   ## Keys

   * `"SchemaVersion"`: the format version of this data.
   * `"Updated"`: the date this file was written.
   * `"ProbeDate"`, `"ChatbookCommit"`: the provenance above.
   * `"Scale"`: every known effort level, weakest first, in the spellings used below.
   * One key per service (`"OpenAI"`), mapping API model names to their data per request method:
     * `"Responses"` (`/v1/responses`) and `"ChatCompletions"` (`/v1/chat/completions`), each an `Association` of:
       * `"ReasoningEfforts"`: the levels the model accepts, weakest first.
       * `"ProviderDefault"`: the level the provider uses when a request names none, or `Missing[ "NotReported" ]`
         where the provider does not say.
       * `"ChatbookDefault"`: what Chatbook sends when `"Reasoning"` is `Automatic`: a level, or an `Association`
         that is sent as it is.
     * A request method with no data is a `Missing[ ... ]` status instead:
       * `Missing[ "NotOnEndpoint" ]`: that request method does not serve the model.
       * `Missing[ "NoReasoningEffort" ]`: the model takes no effort parameter.
       * `Missing[ "NoAccess" ]`, `Missing[ "Deprecated" ]`, `Missing[ "ProbeFailed" ]`: the probe could not check
         it.
     * A model key matches the model name itself or the name followed by `-`; the longest matching key wins. So
       `"gpt-5.4"` covers `gpt-5.4-2026-03-05` and `gpt-5.4-mini`, while `"gpt-5.4-pro"` has an entry of its own.
     * Models the probe could not check are kept, with their statuses, so that they do not match a shorter key:
       without its own entry, `gpt-5.6-cyber` would get the data of `"gpt-5.6"`.

   ## Refreshing

   * Run from the Chatbook directory:
     * `wolframscript -f Scripts/CheckReasoningEfforts.wls all cloud=<file>` to probe the API again.
     * `wolframscript -f Scripts/CheckReasoningEfforts.wls from=<file> cloud=<file>` to rebuild from an earlier run's
       `out=<file>` without API calls, for example after changing Chatbook's defaults.
   * The script only writes the local file. Upload it by copying it to the cloud object, keeping its read permissions.
   * This header comes from `Scripts/Resources/LLMReasoningEffortSpecificationDataHeader.wl`.
*)
