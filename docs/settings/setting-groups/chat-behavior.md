# Chat Behavior Settings

## `"IncludeHistory"`

Controls whether preceding chat cells are included in the context sent to the LLM, or only the current evaluation cell.

### Resolution

When `Automatic`, resolves to `Automatic` (no further resolution via `resolveAutoSetting0`). In practice, `Automatic` behaves the same as `True`: the `If[ ! settings["IncludeHistory"], cells = { evalCell } ]` check in `sendChat` (`SendChat.wl`) does not trigger because `! Automatic` evaluates to `Not[Automatic]` (not `True`), so the full cell list is passed to `constructMessages`. When explicitly `True`, the same behavior applies. When `False`, only the evaluation cell itself is included — no preceding chat history.

### Implementation

The `selectChatCells` function (`SendChat.wl`) first selects candidate cells (up to `ChatHistoryLength` cells, bounded by chat delimiter cells), and then the `IncludeHistory` check decides whether to keep those cells or replace them with just the current cell. In `ChatHistory.wl`, `selectChatHistoryCells` dispatches on the setting value: `False` returns only the current cell; any other value (including `Automatic`) applies the `ChatHistoryLength` limit to the full cell list.

### Cell Style Overrides

Cells with the `"SideChat"` style automatically set `IncludeHistory` to `False` via `addCellStyleSettings` in `Actions.wl`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service).
- **Persona inheritance**: Not in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Exposed in the notebook preferences UI as an "Include chat history" checkbox under the "Chat Notebook Cells" section (`PreferencesContent.wl`), where both `True` and `Automatic` display as checked.

## `"ChatHistoryLength"`

When sending a chat message, the system selects cells starting from the current cell and looking backwards, limited to this count. Note: this is a cell count limit, not a token limit; token budgeting is handled separately by `"MaxContextTokens"` and `"TokenBudgetMultiplier"`.

### Implementation

Used in two paths: `selectChatCells` in `SendChat.wl` (which sets `$maxChatCells` from this value and applies `Take[..., UpTo @ $maxChatCells]` on the filtered cell list) and `selectChatHistoryCells` in `ChatHistory.wl` (which applies the same kind of limit on cell information entries). When the value is not a positive integer, falls back to the default `$maxChatCells`.

### Preferences UI

Exposed in the notebook preferences UI as a numeric input field under the "Notebooks" section.

## `"MergeMessages"`

When `True`, consecutive non-system messages with the same role are merged into a single message. When `False`, `Automatic`, or any other value, messages are left unmerged.

### Implementation

The `mergeMessageData` function in `ChatMessages.wl` groups consecutive non-system messages by role (via `SplitBy[messages, Lookup["Role"]]`) and concatenates their text content into a single message per group. System messages at the start of the message list are always kept separate (not merged). The merge process also applies `mergeCodeBlocks`, which combines adjacent code blocks of the same language (e.g., two consecutive `` ```wl `` blocks) into a single code block, preventing fragmentation when multiple cells are combined. The check uses `TrueQ`, so only an explicit `True` triggers merging. Merging is applied in `augmentChatMessages` (`ChatMessages.wl`) after message construction but before prompt generator augmentation.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for message preprocessing).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Exposed in the notebook preferences UI as a "Merge chat messages" checkbox under the "Notebooks" section (`PreferencesContent.wl`), with tooltip: "If enabled, adjacent cells with the same author will be merged into a single chat message." Also exposed via the ChatPreferences tool as a boolean parameter.

## `"MaxCellStringLength"`

Maximum string length for cell content included in the LLM context, scaling proportionally to the model's context window.

### Resolution

When `Automatic`, resolved by `chooseMaxCellStringLength` (`Settings.wl`): if `MaxContextTokens` is `Infinity`, returns `Infinity`; otherwise computes `Min[Ceiling[$defaultMaxCellStringLength * tokens / 2^14], 2^14]`, where `$defaultMaxCellStringLength` is `10000` (`Serialization.wl`) and `tokens` is the resolved `MaxContextTokens` value. This scales the character limit proportionally to the model's context window, capping at 16,384 characters.

### Implementation

The resolved value is used as the initial `$cellStringBudget` in `makeChatMessages` (`ChatMessages.wl`), which dynamically decreases the budget as messages are added based on token pressure: `$cellStringBudget = Ceiling[(1 - $tokenPressure) * $initialCellStringBudget]`, dropping to `0` when the remaining token budget falls below `$reservedTokens` (500). Each cell is serialized via `CellToString` with `"MaxCellStringLength" -> $cellStringBudget` (`ChatMessages.wl`), which truncates cell content exceeding this limit.

### Dependent Settings

`"MaxOutputCellStringLength"` depends on the resolved `MaxCellStringLength` value.

### Chat Mode Overrides

- **Context mode**: Listed in `$downScaledSettings` (scaled down for context queries).
- **ContentSuggestions mode**: Overrides to `1000`.

### Integration Points

- **Dependencies**: Depends on `"Model"` and `"MaxContextTokens"` (declared in `$autoSettingKeyDependencies`).
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI. Exposed in the ChatPreferences tool as an integer parameter (where `0` means determine automatically).

## `"MaxOutputCellStringLength"`

Controls how aggressively output cells (styles matching `"Output"`, `"Print"`, `"Echo"`) are truncated when serialized via `CellToString` (`Serialization.wl`).

### Resolution

When `Automatic`, resolved by `chooseMaxOutputCellStringLength` (`Settings.wl`): computes `Min[Ceiling[MaxCellStringLength / 10], 1000]`, producing a value that is one-tenth of the resolved `MaxCellStringLength`, capped at 1,000 characters. The fallback constant `$defaultMaxOutputCellStringLength` (`Serialization.wl`) is `500`, used when the option value is `Automatic` at the `CellToString` level.

### Implementation

The resolved value flows through to `CellToString` as the `"MaxOutputCellStringLength"` option; within `CellToString`, it is assigned to the `$maxOutputCellStringLength` dynamic variable (`Serialization.wl`), which controls two behaviors:

1. **Output cell truncation**: cells matching `$$outputStyle` (`"Output"`, `"Print"`, `"Echo"`) are wrapped through `truncateString` after serialization, which calls `stringTrimMiddle[str, $maxOutputCellStringLength]` to trim strings exceeding the limit by replacing the middle with an elision marker.
2. **Graphics serialization threshold**: for graphics boxes, `ByteCount @ box < $maxOutputCellStringLength` determines whether a small graphics expression is serialized as an `InputForm` string (below threshold) or replaced with a placeholder like `"[GRAPHIC]"` (above threshold).

Additionally, `truncateString` is used throughout `Serialization.wl` for other content (e.g., `InputForm` strings, compressed data, export packets), always defaulting to `$maxOutputCellStringLength` when no explicit size is given.

### Local Overrides

Special local overrides within `Serialization.wl`:

- `GridBox` table rendering temporarily sets `$maxOutputCellStringLength = 2*$cellPageWidth` for table cell content.
- `getExamplesString` (documentation example extraction) temporarily sets it to `100` for compact example summaries.
- Cells matching `$$noTruncateStyle` (`"AlphabeticalListing"`) temporarily set it to `Infinity` to disable truncation entirely.

### Chat Mode Overrides

- **Context mode**: Scales to 25% via `$notebookContextLimitScale` (applied by `downScaledSettings` in `Context.wl`).
- **ContentSuggestions mode**: Fixed at `200` via `$contentSuggestionsOverrides`.
- **NotebookChunking**: Uses its own independent variable `$maxChunkOutputCellStringLength = 500` (passed directly to `CellToString` as the `"MaxOutputCellStringLength"` option in `NotebookChunking.wl`).

### Integration Points

- **Dependencies**: Depends on `"MaxCellStringLength"` (declared in `$autoSettingKeyDependencies`).
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for serialization).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"ForceSynchronous"`

Controls whether chat requests use synchronous (non-streaming) communication with the LLM.

### Resolution

When `Automatic`, resolves via `forceSynchronousQ` (`Settings.wl`), which returns `True` if the model's service is `"GoogleGemini"` (since Google Gemini uses a non-streaming API by default) and `False` otherwise.

### Model-Specific Overrides

- **`True`**: O1, O3, O4-Mini (OpenAI reasoning models that do not support streaming)
- **`False`**: O1-Mini, Gemini 2, Gemini 3 (which do support streaming, overriding the service-level default for Gemini)

### Implementation

When `True`, `chatSubmit0` in `SendChat.wl` uses the synchronous `LLMServices`Chat` function instead of the streaming `LLMServices`ChatSubmit`, waits for the complete response before writing output, sets progress display to `"WaitingForResponse"`, and returns `None` instead of a `TaskObject`. Additionally, when `ForceSynchronous` is `True`, `$showProgressText` is forced to `True` in `resolveAutoSettings` (`Settings.wl`) regardless of the `ShowProgressText` setting.

### Dependent Settings

`"BypassResponseChecking"` depends on this: when `ForceSynchronous` is `True`, `BypassResponseChecking` also resolves to `True`, skipping HTTP status code validation, empty response detection, and JSON error parsing.

### Integration Points

- **Dependencies**: Depends on `"Model"`.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"TimeConstraint"`

Time limit (in seconds) for the overall chat task evaluation. Note: this controls the overall chat task timeout, not individual tool evaluation timeouts (those are controlled separately by tool-specific options such as `"EvaluationTimeConstraint"` and `"PingTimeConstraint"` in `Tools/Common.wl`).

### Accepted Values

Only explicitly positive numeric values (e.g., `30`, `60`, `120`) activate the constraint. The check uses `TrueQ @ Positive @ timeConstraint`, so `Automatic`, `Infinity`, `False`, and other non-positive values all result in no time limit.

### Implementation

When a positive numeric value is given, `waitForLastTask` in `Actions.wl` wraps the task-waiting step in `TimeConstrained[waitForLastTask[$lastTask], timeConstraint, StopChat[]]`, so if the chat task exceeds the specified number of seconds, `StopChat[]` is called to abort the evaluation. When `Automatic` (or any non-positive value), no time constraint is applied and the chat task runs until completion.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for task management).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the notebook preferences UI or the ChatPreferences tool.

## `"ConvertSystemRoleToUser"`

Whether to convert system-role messages to user-role messages. Model default: `False`. Required for some models (e.g., O1-Mini).

## `"ReplaceUnicodeCharacters"`

Whether to replace Wolfram Language special characters (Unicode private use area codepoints) with ASCII equivalents before sending messages to the LLM.

### Resolution

When `Automatic`, resolves via `autoModelSetting` to the model-specific default.

### Model-Specific Overrides

- **`True`**: All Anthropic models (service-level default in `$modelAutoSettings["Anthropic", Automatic]`), GPT-5.2
- **`False`**: Global default (from `$modelAutoSettings[Automatic, Automatic]`)

### Implementation

When `True`, the `replaceUnicodeCharacters` function in `SendChat.wl` performs string replacements on all message content, including strings inside `LLMTool`, `LLMToolRequest`, and `LLMToolResponse` expressions. The replacement is applied in the message preparation pipeline (after role rewriting, before tool response splitting). The check uses `TrueQ`, so only an explicit `True` triggers replacement; `False`, `Automatic`, or any other value leaves messages unchanged.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook for message preprocessing, not passed to the LLM service).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"BypassResponseChecking"`

Whether to bypass response validation after receiving an LLM response.

### Resolution

Resolves to `True` when `ForceSynchronous` is `True`, `False` otherwise.

### Behavior by Value

- **`True`**: The response is immediately written as a formatted output cell without validating the HTTP status code, checking for empty responses, or extracting error data from the response body.
- **`False`**: The response goes through full validation: the debug log is processed to extract body chunks, status codes are checked (non-200 responses trigger error cells), empty responses are detected, and JSON error data is parsed before writing output.

### Integration Points

- **Dependencies**: Depends on `"ForceSynchronous"`.

## `"Assistance"`

Whether automatic assistance mode is enabled.

### Resolution

When `Automatic`, resolves to `False`.

### Behavior by Value

When `True`, LLM responses are processed immediately rather than being queued for user approval, output cells use `"AssistantOutput"` styles instead of `"ChatOutput"`, and certain tools are disabled (WolframLanguageEvaluator, CreateNotebook, WolframAlpha).

### Preferences UI

Exposed in the notebook preferences UI as "Enable automatic assistance".
