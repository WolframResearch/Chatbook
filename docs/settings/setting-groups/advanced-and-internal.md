# Advanced / Internal Settings

## `"Tokenizer"`

Tokenizer function used for token counting throughout the chat pipeline.

### Accepted Values

- **`Automatic`** (default) — resolved via a multi-step fallback based on model and tokenizer name
- **Custom function** — any expression other than `Automatic` / `$$unspecified` is used directly
- **String** — treated as a tokenizer name; the `"TokenizerName"` key is set to the resolved name and `"Tokenizer"` is reset to `Automatic` during `resolveAutoSettings`

### Resolution

When `Automatic`, resolved via `getTokenizer` (`ChatMessages.wl`) using a three-step fallback:

1. If an explicit non-`Automatic` tokenizer function is already set, it is used directly.
2. If `"TokenizerName"` is a string, the corresponding cached tokenizer is looked up via `cachedTokenizer`.
3. Otherwise, the tokenizer is derived from the `"Model"` setting by extracting the model name and matching it to a known tokenizer.

Pre-cached tokenizer functions exist for:

| Tokenizer | Notes |
| --------- | ----- |
| `"chat-bison"` | UTF-8 byte encoding via `ToCharacterCode` |
| `"gpt-4-vision"` / `"gpt-4o"` | Estimated count for text, special image token counting for `Graphics` content |
| `"claude-3"` | Estimated count for text, Claude-specific image token counting |
| `"generic"` | Estimated count for text; the fallback for models without a tokenizer of their own |

These four are what most current models resolve to (GPT, Gemini and most other models resolve to `"gpt-4o"` or `"generic"`, Claude 3 models to `"claude-3"`), and they don't tokenize text: they estimate its token count from character statistics (`estimateTokenCount` in `ChatMessages.wl`). An exact count needs a `NetEncoder` whose first use takes about a second in each session, and the tokenizers in `Assets/Tokenizers/` are not the ones of current models anyway. Newer Claude models (e.g. `"claude-sonnet-4-5"`) have `"claude"` but not `"claude-3"` in their names, so they resolve to the exact `"claude"` tokenizer.

The estimate is fitted to rarely fall below the larger of the gpt-4o and claude tokenizer counts. Compared to the gpt-4o count, it is about 1.1-1.3 times as high for English text and code, 1.4-1.8 times for German, French, Spanish, Chinese, Japanese and Korean, and 4.5-6 times for Greek, Cyrillic and Arabic text (for which the claude tokenizer gives three to five times as many tokens as gpt-4o). Short strings are overcounted more. A single English text or piece of code of a few thousand characters is rarely below the gpt-4o count (by at most about 12% in the texts it was checked on). Long runs of lowercase letters that aren't words, such as DNA sequences, are an exception: they can be counted two to three times too low. Since counts are only used to keep requests within `"MaxContextTokens"`, overcounting only means that long conversations are trimmed earlier.

Exact counts are still available by naming a tokenizer that is not in the table, e.g. `"Tokenizer" -> "gpt-4o-text"` (text only), or by giving a tokenizer function. (A `"TokenizerName"` setting doesn't do this: it is always resolved from `"Model"` or `"Tokenizer"`.) The internal flag `$estimateTokenCounts` (default `True`) switches the four tokenizers above back to exact counting.

Other tokenizers are loaded on demand from `.wxf` files in the `Assets/Tokenizers/` directory, or discovered via `` Wolfram`LLMFunctions`Utilities`Tokenization`FindTokenizer` ``; if no model-specific tokenizer is found, the `"generic"` tokenizer is used as a fallback.

The resolved tokenizer is applied via `applyTokenizer` in `tokenCount` (`ChatMessages.wl`), which tokenizes message content and returns the token list length.

Counts for text content are memoized for the session in `$tokenCountCache`, keyed by `{tokenizerName, $estimateTokenCounts, Hash[content]}`. A count is only memoized when `"TokenizerName"` names a registered tokenizer in `$cachedTokenizers` that is the same as the tokenizer being applied, so custom tokenizer functions and image content are always counted directly. When the cache reaches `$maxTokenCountCacheSize` (5000) entries, the oldest half is discarded.

### Serialization

Explicitly dropped from saved notebook settings via `toSmallSettings` (`SendChat.wl`, `KeyDrop[as, {"OpenAIKey", "Tokenizer"}]`) because tokenizer functions cannot be serialized. Serialized to a name-based reference (`<| "_Object" -> "Tokenizer", "Data" -> name |>`) in `Feedback.wl` for diagnostic reporting.

### Integration Points

- **Dependencies**: Depends on `"TokenizerName"` in `$autoSettingKeyDependencies`, which in turn depends on `"Model"`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for token counting).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- Not in `$popOutSettings`.

### Preferences UI

Not exposed in the preferences UI.

## `"HandlerFunctions"`

Callback functions invoked at various stages of chat processing.

### Accepted Values

- **`$DefaultChatHandlerFunctions`** (default) — an `Association` mapping event name strings to handler functions (or `None` to skip)

### Default Events

The default value `$DefaultChatHandlerFunctions` (`Settings.wl`) defines 9 event keys, all defaulting to `None`:

| Event | Dispatch Location | Arguments |
| ----- | ----------------- | --------- |
| `"ChatPre"` | `sendChat` (`SendChat.wl`), before chat submission | `"EvaluationCell"`, `"Messages"` |
| `"ChatPost"` | `applyChatPost` (`Actions.wl`), after chat completion | `"ChatObject"`, `"NotebookObject"` |
| `"ChatAbort"` | `applyChatPost` (`Actions.wl`), after chat abort | `"ChatObject"`, `"NotebookObject"` |
| `"ToolRequestReceived"` | After parsing a tool call (`SendChat.wl`) | `"ToolRequest"` |
| `"ToolResponseGenerated"` | After generating a tool response (`SendChat.wl`) | `"ToolResponse"`, `"ToolResponseString"` |
| `"PromptGeneratorStart"` | `DefaultPromptGenerators.wl`, before each prompt generator | `"PromptGenerator"` |
| `"PromptGeneratorEnd"` | `DefaultPromptGenerators.wl`, after each prompt generator | `"PromptGenerator"`, `"PromptGeneratorResult"` |
| `"AppendCitationsStart"` | `Citations.wl`, before citation generation | `"Sources"` |
| `"AppendCitationsEnd"` | `Citations.wl`, after citation generation | `"CitationString"` |

The `"ChatAbort"`, `"ChatPost"`, and `"ChatPre"` entries use `RuleDelayed` (`:>`) pointing to global variables `$ChatAbort`, `$ChatPost`, and `$ChatPre` (all initially `None`), allowing runtime reassignment without modifying the association.

For a chat evaluated from a chat input (in a chat notebook, the sidebar, or the Notebook Assistant window), a chat that's stopped with a stop button ends like one that completed: `"ChatPost"` is called (`"ChatAbort"` is only called after an abort), with `"ChatObject" -> None` if no response text was received, for example when the chat was stopped before its request was submitted. A chat stopped before `"ChatPre"` doesn't call it, and a chat stopped after `"ChatPre"` doesn't submit its request.

### Resolution

Custom handler values are merged with defaults during resolution: `resolveHandlers` in `Handlers.wl` creates a new association with `$DefaultChatHandlerFunctions` as the base, overlaid with user-provided handlers (after `replaceCellContext` processing), plus a `"Resolved" -> True` marker to prevent re-resolution. Resolution occurs during `resolveAutoSettings` (`Settings.wl`), where `getHandlerFunctions` is called on the settings and the result replaces the `"HandlerFunctions"` key.

### Handler Invocation

Each handler function is invoked via `applyHandlerFunction` (`Handlers.wl`), which constructs an argument association containing:

- `"EventName"` — the event type string
- `"ChatNotebookSettings"` — current settings with `"Data"` and `"OpenAIKey"` keys dropped
- Event-specific data (see table above)

This argument association is accumulated in the `$ChatHandlerData` global variable (publicly exported) via `addHandlerArguments`, which merges new data with existing handler state (supporting nested association merging). The handler receives `$ChatHandlerData` with `"DefaultProcessingFunction"` dropped.

### Streaming Integration

In the streaming chat submission path (`chatHandlers` in `SendChat.wl`), the resolved handlers are passed to `` LLMServices`ChatSubmit `` via the `HandlerFunctions` parameter, but `"ChatPost"`, `"ChatPre"`, and `"Resolved"` keys are dropped (listed in `$chatSubmitDroppedHandlers`). The `chatHandlers` function also wraps custom `"BodyChunkReceived"` and `"TaskFinished"` handlers (if provided) inside Chatbook's own streaming logic, calling the user's handler before Chatbook's processing for each body chunk and after task completion.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys`.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"HandlerFunctionsKeys"`

Keys to include in the handler functions callback data passed to `` LLMServices`ChatSubmit `` and `URLSubmit`.

### Accepted Values

- **`Automatic`** (default) — resolves to `$defaultHandlerKeys`
- **List of strings** — merged with `$defaultHandlerKeys` via `Union` (default keys are always included)
- **Single string** — treated as a one-element list

Invalid values trigger an `"InvalidHandlerKeys"` warning (`Common.wl`) and fall back to `$defaultHandlerKeys`.

### Default Keys

`$defaultHandlerKeys` (`SendChat.wl`): `{"Body", "BodyChunk", "BodyChunkProcessed", "StatusCode", "TaskStatus", "EventName"}`.

### Resolution

Resolution is performed by `chatHandlerFunctionsKeys` (`SendChat.wl`), called from `resolveAutoSetting0` (`Settings.wl`). The resolved value is passed directly as the `HandlerFunctionsKeys` parameter to `` LLMServices`ChatSubmit `` (for LLMServices-based chat) and `URLSubmit` (for legacy HTTP-based chat) in `chatSubmit0` (`SendChat.wl`).

Also used in other `URLSubmit` calls outside of chat:
- `VectorDatabases.wl` uses `{"ByteCountDownloaded", "StatusCode"}` for vector database downloads
- `RelatedWolframAlphaResults.wl` uses `{"StatusCode", "BodyByteArray"}` for Wolfram Alpha result fetching

### Integration Points

- **Dependencies**: Depends on `"EnableLLMServices"` for resolution ordering in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys`.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"InheritanceTest"`

Internal diagnostic flag used by the settings inheritance verification system. Not a user-configurable setting and not included in `$defaultChatSettings`.

### Behavior

During `verifyInheritance0` (`Settings.wl`), this flag is set to `True` at the `$FrontEnd` scope via `setCurrentValue[fe, {TaggingRules, "ChatNotebookSettings", "InheritanceTest"}, True]` to mark that the inheritance chain for tagging rules has been properly initialized.

Subsequent calls to `verifyInheritance` check this flag via `inheritingQ`, which reads `AbsoluteCurrentValue[obj, {TaggingRules, "ChatNotebookSettings", "InheritanceTest"}]` — if `True` (or if the read fails), the object is considered to have valid inheritance and initialization is skipped.

During `repairTaggingRules`, the flag is explicitly removed from child objects (notebooks, cells) so that it only persists at the top-level `FrontEndObject`, preventing it from appearing as an explicit override in child scopes.

The `verifyInheritance` function is called by `currentChatSettings0` before reading or writing settings, ensuring the inheritance chain is intact.

### Integration Points

- **Dependencies**: None.
- **Model-specific overrides**: None.
- **Persona inheritance**: Listed in `$nonInheritedPersonaValues`, so it retains its value from notebook/cell scope rather than inheriting from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"ProcessingFunctions"`

An `Association` of callback functions that control the chat processing pipeline, allowing customization of how cells are converted to messages, how chat requests are submitted, how output is formatted, and how output cells are written.

### Default Value

The default `$DefaultChatProcessingFunctions` (`Settings.wl`) is defined using `RuleDelayed` (`:>`) in `$defaultChatSettings` so it is evaluated lazily. It contains six keys:

| Key | Default | Description |
| --- | ------- | ----------- |
| `"CellToChatMessage"` | `CellToChatMessage` | Converts notebook `Cell` expressions to message associations with `"Role"` and `"Content"` keys. Retrieved via `getCellMessageFunction` (`ChatMessages.wl`) and wrapped by `checkedMessageFunction`, which validates results. |
| `"ChatMessages"` | `(#1 &)` | Identity function that post-processes the combined message list after construction and prompt generator augmentation. Invalid results trigger an `"InvalidMessages"` warning. |
| `"ChatSubmit"` | `Automatic` | Submits prepared messages to the LLM service. When `Automatic`, resolves to `` LLMServices`ChatSubmit `` or `URLSubmit` depending on the code path. |
| `"FormatChatOutput"` | `FormatChatOutput` | Formats LLM response text for notebook display. Dispatches on a `"Status"` key (`"Streaming"`, `"Finished"`, `"Waiting"`) and converts Markdown to formatted notebook expressions via `reformatTextData`. |
| `"FormatToolCall"` | `FormatToolCall` | Formats tool call data for display in the notebook. Takes a raw tool call string and parsed data association. |
| `"WriteChatOutputCell"` | `WriteChatOutputCell` | Writes the formatted output cell to the notebook using `NotebookWrite`. |

### Resolution

During `resolveAutoSettings` (`Settings.wl`), the value is resolved via `getProcessingFunctions` (`Handlers.wl`), which calls `resolveFunctions`: this merges user-provided overrides on top of `$DefaultChatProcessingFunctions`, applies `replaceCellContext` to convert `$CellContext` symbols to the global context, and marks the result with `"Resolved" -> True` to prevent re-resolution. Invalid values trigger an `"InvalidFunctions"` warning (`Common.wl`) and fall back to defaults.

### Function Invocation

Each processing function is invoked via `applyProcessingFunction` (`Handlers.wl`), which:

1. Retrieves the function via `getProcessingFunction` (falling back through the resolved association, then `$DefaultChatProcessingFunctions`)
2. Merges parameters with `$ChatHandlerData` (adding `"ChatNotebookSettings"` and `"DefaultProcessingFunction"` to the handler data)
3. Applies the function to its held arguments
4. Logs timing via `LogChatTiming`

The `$DefaultChatProcessingFunctions` variable is publicly exported (`Main.wl`).

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook for pipeline customization).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- Not in `$popOutSettings` or `$droppedSettingsKeys`.

### Preferences UI

Not exposed in the preferences UI.

## `"ConversionRules"`

Custom transformation rules applied to notebook cells before they are serialized to chat message strings.

### Accepted Values

- **`None`** (default) — cells are passed through unmodified
- **List of replacement rules** — compiled into a `Dispatch` table and applied to each cell via `ReplaceRepeated`

Invalid values (neither a rule list nor a valid `Dispatch` table) trigger an `"InvalidConversionRules"` warning and fall back to `None`.

### Behavior

When set to a list of replacement rules, the rules are compiled into a `Dispatch` table (cached for reuse) and applied to each cell via `ReplaceRepeated` inside `CellToString` (`Serialization.wl`) before string conversion occurs. This enables custom box-level or expression-level transformations of cell content prior to sending it to the LLM.

The setting value is read from `CurrentChatSettings` in `makeChatMessages` (`ChatMessages.wl`) and stored in the dynamic variable `$conversionRules`, which `CellToString` picks up as its default `"ConversionRules"` option.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys`.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"ExperimentalFeatures"`

List of enabled experimental feature names, resolved dynamically from other settings.

### Accepted Values

- **`Automatic`** (default) — resolved dynamically
- **List of strings** — explicit feature names

### Resolution

When `Automatic`, the `autoExperimentalFeatures` function (`Settings.wl`) builds a list based on two conditions:

- `"RelatedWolframAlphaResults"` is included if `"WolframAlphaCAGEnabled"` is `True` or `"RelatedWolframAlphaResults"` is in the `"PromptGenerators"` list.
- `"RelatedWebSearchResults"` is included if `"WebSearchRAGMethod"` is `"Tavily"` or `"WebSearch"` is in the `"PromptGenerators"` list.

The resolved list is stored in the `$experimentalFeatures` global variable (`Settings.wl`) and preserved across handler evaluation via `ChatState.wl`. Individual features are checked at runtime via `featureEnabledQ` (`Settings.wl`), which tests membership in the resolved list.

### Downstream Effects

The primary consumer is `resolvePromptGenerators` in `PromptGenerators/Common.wl`, which appends `"RelatedWolframAlphaResults"` and/or `"WebSearch"` to the active prompt generators list based on feature flags.

### Integration Points

- **Dependencies**: Depends on `"WolframAlphaCAGEnabled"`, `"WebSearchRAGMethod"`, and `"PromptGenerators"` (declared in `$autoSettingKeyDependencies`).
- **Model-specific overrides**: None.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"OpenAIKey"`

**Deprecated.** OpenAI API key used for direct OpenAI API authentication in the legacy (non-LLMServices) HTTP request path.

### Accepted Values

- **`Automatic`** (default) — resolved at chat time via `toAPIKey`
- **String** — used directly as the API key

### Resolution

Only used when `EnableLLMServices` resolves to `False` (i.e., the `Wolfram/LLMFunctions` paclet is not installed or `EnableLLMServices` is explicitly `False`).

When `Automatic`, the key is resolved at chat time by `toAPIKey` (`Actions.wl`), which checks in order:

1. `SystemCredential["OPENAI_API_KEY"]`
2. `Environment["OPENAI_API_KEY"]`
3. An interactive API key dialog (`apiKeyDialog`)

If none produces a valid string, throws a `"NoAPIKey"` failure. The resolved key is used by `makeHTTPRequest` (`SendChat.wl`) to construct the `"Authorization"` header for the `HTTPRequest` sent to the OpenAI completions endpoint.

In the modern code path (`$useLLMServices` is `True`), this setting is completely unused — the `LLMServices` framework handles authentication internally.

### Security Handling

- `maskOpenAIKey` (`Common.wl`) replaces actual key values with `"**********"` in all diagnostic, debug, and error output.
- Dropped from saved notebook settings via `toSmallSettings` (`SendChat.wl`).
- Dropped from handler function callback data via `$settingsDroppedKeys` (`Handlers.wl`).
- Dropped from notebook settings diagnostic output (`Common.wl`).

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`. Not resolved during `resolveAutoSettings`; `Automatic` persists until `toAPIKey` is called at chat time.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys`.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- Not in `$popOutSettings`.

### Preferences UI

Not exposed in the preferences UI.

## `"OpenAIAPICompletionURL"`

**Deprecated.** OpenAI API completion endpoint URL, used only in the legacy (non-LLMServices) HTTP request path.

### Default Value

`"https://api.openai.com/v1/chat/completions"` (a fixed string, not `Automatic`).

### Behavior

Only used when `$useLLMServices` is `False`. In this legacy path, `makeHTTPRequest` (`SendChat.wl`) reads the value from settings and uses it as the URL for the `HTTPRequest` sent to the OpenAI chat completions API, with `"OpenAIKey"` providing the `"Authorization"` header.

When `$useLLMServices` is `True` (the primary/modern code path), this setting is completely unused — the LLMServices framework handles endpoint routing internally.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys`.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- Not in `$popOutSettings`.

### Preferences UI

Conditionally exposed in the preferences UI (`PreferencesContent.wl`): the `makeOpenAICompletionURLInput` function returns `Nothing` when `$useLLMServices` is `True` (hiding the control entirely) and renders a string input field in the "Notebooks" tab when `$useLLMServices` is `False`.

## `"PreloadNotebookAssistant"`

**Experimental.** Whether to initialize the notebook assistant in the background after the kernel starts, instead of when the assistant is opened.

### Usage

Off unless set to `True` at `$FrontEnd` scope, which persists across sessions:

```wl
CurrentChatSettings[ $FrontEnd, "PreloadNotebookAssistant" ] = True   (* turn on *)
CurrentChatSettings[ $FrontEnd, "PreloadNotebookAssistant" ] =.       (* turn off *)
```

The setting is read once per kernel session, a few seconds after Chatbook is loaded, so a change takes effect in the next session. It is not read from notebooks, cells or personas, and it is not in `$defaultChatSettings`.

### Behavior

Chat initialization (`initializeWorkspaceChat` in `ChatModes/UI.wl`) loads the embedding model, the vector databases, the LLM Kit connection and the other things that the first chat needs. It normally starts when the notebook assistant window or sidebar is opened, and a chat that is sent before it has finished waits for it, which takes several seconds in a new kernel.

With this setting, `scheduleChatPreload` (called when Chatbook is loaded) runs the same work ahead of time, as the steps of `$chatPreloadSteps`:

- Each step is evaluated by a scheduled task, with a short pause between steps.
- The first task reads the setting with a plain front end read (`chatPreloadSettingQ`), not with `CurrentChatSettings`, which would load `ServiceFramework` in a new kernel. If the setting is off, nothing else is scheduled.
- A step only runs while the kernel is idle (`kernelIdleQ`). A scheduled task can fire inside another evaluation, so a step is postponed when it does.
- While a step runs (usually 1-2 seconds, but about 7 seconds once after the vector database caches have been rebuilt), evaluations wait for it, and so do dynamic updates: unlike a main link evaluation, a scheduled task does not let preemptive evaluations through.
- The first step sends the LLM Kit info request (`startLLMKitInfoRequest`). Its response is received between steps, and `initializeWorkspaceChat` uses it.
- If the notebook assistant is opened before the steps are done, it runs the rest of the initialization itself, and the remaining steps are skipped.
- Loading Chatbook again (e.g. a newer version) replaces the pending task, so only one chain of steps runs.
- Nothing is done in the cloud, in kernels without a front end, or in the kernels that Chatbook starts for evaluating code.

It is opt-in because every session then spends several seconds of kernel time and a few hundred MB of memory on it, also sessions that never use the notebook assistant.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys`.
- Timing entries for the steps are logged with the tags `"ChatPreload:<step>"` (see `$ChatTimingData`).

### Preferences UI

Not exposed.
