# LLM Parameter Settings

## `"Temperature"`

Higher values produce more varied output; lower values produce more deterministic output.

### Resolution

When `Automatic`, resolved via `$modelAutoSettings` lookup (no custom `resolveAutoSetting0` handler exists). The global auto default is `0.7` (`$modelAutoSettings[Automatic, Automatic]`).

### Model-Specific Overrides

- **`Missing["NotSupported"]`**: GPT-5 (family-level via `$modelAutoSettings[Automatic, "GPT5"]`, inherited by GPT-5.1/GPT-5.2), O4-Mini
- All other models inherit the global default of `0.7`.

### Accepted Values

Numeric values in the range `0` to `2` (declared as `Restricted["Number", {0, 2}]` in `ChatPreferences.wl`).

### Implementation

**LLMServices path:** Included in `$llmConfigPassedKeys` (`SendChat.wl`), so it is passed through `LLMConfiguration` to the LLM service. When `Automatic`, the resolved value (either `0.7` or `Missing["NotSupported"]`) is what gets passed. `Missing` values are stripped by `DeleteMissing` in `makeLLMConfiguration`, and unsupported parameters are dropped by `dropModelUnsupportedParameters` (which checks `autoModelSetting` for `Missing["NotSupported"]`).

**Legacy path:** In `makeHTTPRequest` (`SendChat.wl`), the value is looked up via `Lookup[settings, "Temperature", 0.7]` and passed to the OpenAI API as the `"temperature"` field. Values of `Automatic` or `Missing` are stripped via `DeleteCases`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- **Notebook conversion**: Not listed in `$popOutSettings`.

### Preferences UI

Exposed in two places:

- `makeTemperatureInput` (`PreferencesContent.wl`): numeric input field under the "Notebooks" section.
- `makeTemperatureSlider` (`UI.wl`): slider (range `0` to `2`, step `0.01`) with a "Choose automatically" checkbox in the advanced settings UI. When auto is selected, the value is set to `Inherited`.

## `"FrequencyPenalty"`

Reduces repetition. Default is a fixed numeric value (`0.1`), not `Automatic`.

### Implementation

Only used in the legacy (non-LLMServices) HTTP request path: in `makeHTTPRequest` (`SendChat.wl`), the value is looked up via `Lookup[settings, "FrequencyPenalty", 0.1]` and passed to the OpenAI API as the `"frequency_penalty"` field. Values of `Automatic` or `Missing` are stripped via `DeleteCases`.

Not included in `$llmConfigPassedKeys`, so it is **not** passed through `LLMConfiguration` when using the LLMServices framework.

### Integration Points

- **Model-specific overrides**: None in `$modelAutoSettings`.
- **Dependencies**: None.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"PresencePenalty"`

Encourages the model to introduce new topics by penalizing tokens that have already appeared.

### Resolution

When `Automatic`, resolved via `$modelAutoSettings` lookup (no custom `resolveAutoSetting0` handler exists). The global auto default is `0.1` (`$modelAutoSettings[Automatic, Automatic]`).

### Model-Specific Overrides

- **`Missing["NotSupported"]`**: Google Gemini (service-level default via `$modelAutoSettings["GoogleGemini", Automatic]`), GPT-5 (family-level via `$modelAutoSettings[Automatic, "GPT5"]`), O4-Mini
- All other models inherit the global default of `0.1`.

### Implementation

**LLMServices path:** Included in `$llmConfigPassedKeys` (`SendChat.wl`), so it is passed through `LLMConfiguration` to the LLM service. When `Automatic`, the resolved value (either `0.1` or `Missing["NotSupported"]`) is what gets passed. `Missing` values are stripped by `DeleteCases` in `makeLLMConfiguration`.

**Legacy path:** In `makeHTTPRequest` (`SendChat.wl`), the value is looked up via `Lookup[settings, "PresencePenalty", 0.1]` and passed to the OpenAI API as the `"presence_penalty"` field. Values of `Automatic` or `Missing` are stripped via `DeleteCases`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- **Notebook conversion**: Not listed in `$popOutSettings`.

### Preferences UI

Not exposed in the preferences UI.

## `"TopP"`

A value of `1` considers all tokens; lower values restrict sampling to the smallest set of tokens whose cumulative probability exceeds the threshold, reducing diversity. Default is a fixed numeric value (`1`), not `Automatic`.

### Implementation

Only used in the legacy (non-LLMServices) HTTP request path: in `makeHTTPRequest` (`SendChat.wl`), the value is looked up via `Lookup[settings, "TopP", 1]` and passed to the OpenAI API as the `"top_p"` field. Values of `Automatic` or `Missing` are stripped via `DeleteCases`.

Not included in `$llmConfigPassedKeys`, so it is **not** passed through `LLMConfiguration` when using the LLMServices framework.

### Integration Points

- **Model-specific overrides**: None in `$modelAutoSettings`.
- **Dependencies**: None.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- **Notebook conversion**: Not listed in `$popOutSettings`.

### Preferences UI

Not exposed in the preferences UI or the ChatPreferences tool.

## `"MaxTokens"`

Controls the maximum number of tokens the LLM may generate in its response (output token limit). Distinct from `"MaxContextTokens"`, which controls the input context window size.

### Resolution

When `Automatic`, resolved by `autoMaxTokens` (`Settings.wl`), which looks up the model name in `$maxTokensTable`. Only two legacy models have explicit entries: `"gpt-4-vision-preview"` and `"gpt-4-1106-preview"` (both `4096`). All other models resolve to `Automatic`, deferring to the LLM service's own default output limit.

### Implementation

**LLMServices path:** The resolved value is passed through `LLMConfiguration` via `$llmConfigPassedKeys` (`SendChat.wl`). When `Automatic`, the underlying `LLMConfiguration`/service determines the appropriate limit.

**Legacy path:** In `makeHTTPRequest` (`SendChat.wl`), the value is placed in the JSON request body as `"max_tokens"`. If `Automatic`, it is stripped by `DeleteCases[..., Automatic|_Missing]`, allowing the API's own default to apply.

### Integration Points

- **Dependencies**: Depends on `"Model"` (declared in `$autoSettingKeyDependencies`).
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations. No persona-level overrides exist.

### Preferences UI

Not exposed in the preferences UI.

## `"MaxContextTokens"`

Maximum token capacity of the context window, used internally for token budgeting and context management. Not passed to the LLM service.

### Resolution

When `Automatic`, resolved by `autoMaxContextTokens` (`Settings.wl`), which dispatches based on the model's service and name:

- **Ollama**: Context length is queried dynamically via `ServiceExecute[service, "ModelContextLength", ...]` and cached.
- **LLMKit**: Value is capped at `2^16` (65,536).
- **Other services**: Resolution first checks `$modelAutoSettings` for an exact model match, then falls back to `autoMaxContextTokens0`, which pattern-matches against tokenized model name components (e.g., `{"claude", "3", ...}` -> `200000`, `{"gpt", "4o", ...}` -> `131072`, `{"gemini", ..., "pro", ...}` -> `30720`).
- **Fallback**: Unrecognized models default to `2^12` (4,096).

### Model-Specific Overrides

| Model | Value |
| ----- | ----- |
| Claude 3/4 | `200000` |
| GPT-4o | `128000` |
| Gemini 2+, GPT-4.1 | `1047576` |
| GPT-5 | `400000` |
| O1-Mini | `64000` (halved for reasoning token headroom) |
| O1, O3, O3-Mini, O4-Mini | `100000` |

### Token Budgeting

The resolved value is used to initialize the token budget in `makeTokenBudget` (`ChatMessages.wl`), which multiplies it by `TokenBudgetMultiplier` to produce the working budget. During message construction:

- Token pressure is tracked as `1.0 - ($tokenBudget / MaxContextTokens)`.
- The cell string budget (`$cellStringBudget`) is dynamically reduced as pressure increases, dropping to `0` when fewer than `$reservedTokens` (500) remain.

### Dependent Settings

- `MaxCellStringLength` depends on `MaxContextTokens`: `chooseMaxCellStringLength` (`Settings.wl`) scales the character limit proportionally via `Min[Ceiling[$defaultMaxCellStringLength * tokens / 2^14], 2^14]`.
- `MaxOutputCellStringLength` in turn depends on the resolved `MaxCellStringLength`.

### Chat Mode Overrides

- **Context mode**: Scales to 25% via `$notebookContextLimitScale` (`ChatModes/Context.wl`).
- **NotebookAssistance mode**: Fixed at `2^15` (32,768).
- **ContentSuggestions mode**: Per content type (`2^12` for WL/Text, `2^15` for Notebook).

Also used by `modelContextStringLimit` (`LLMUtilities.wl`), which converts to a character limit via `tokens * 2` (with fallback to 8,000).

### Integration Points

- **Dependencies**: Depends on `"Authentication"` and `"Model"` (declared in `$autoSettingKeyDependencies`).
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook for context management).
- **Notebook conversion**: Listed in `$popOutSettings` (`ConvertChatNotebook.wl`) as one of four settings shown during chat notebook conversion.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"Reasoning"`

Controls the reasoning/thinking effort level for models that support extended thinking.

### Resolution

When `Automatic`, resolved via `$modelAutoSettings` lookup (no custom `resolveAutoSetting0` handler exists). No global auto default exists in `$modelAutoSettings[Automatic, Automatic]`, so for most models `Automatic` is left as-is and stripped by `DeleteMissing` in `makeLLMConfiguration`.

### Model-Specific Overrides

- **GPT-5**: Resolves to `"Minimal"` if `$gpt5Reasoning` is `True` (i.e., `Wolfram/LLMFunctions` paclet is newer than version `2.2.4`), otherwise `Missing["NotSupported"]`.
- **GPT-5.1**: Resolves to `"None"` under the same paclet version condition, otherwise `Missing["NotSupported"]`.
- No other model families define a `"Reasoning"` override.

### Implementation

Included in `$llmConfigPassedKeys` (`SendChat.wl`), so it is passed through `LLMConfiguration` to the LLM service. `Missing` values are stripped by `DeleteMissing` in `makeLLMConfiguration`, and unsupported parameters are dropped by `dropModelUnsupportedParameters`. Not used in the legacy HTTP request path.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- **Notebook conversion**: Not listed in `$popOutSettings`.

### Preferences UI

Not exposed in the preferences UI.

## `"StopTokens"`

Stop sequences that signal the LLM to stop generating.

### Resolution

When `Automatic`, resolved by `autoStopTokens` (`Settings.wl`), which computes the stop token list based on `"ToolMethod"`, `"ToolCallExamplePromptStyle"`, and `$AutomaticAssistance`. Resolution has three branches:

1. If already set to `Missing["NotSupported"]` (from model-specific settings), returns `Missing["NotSupported"]`.
2. If `"ToolsEnabled"` is `False`, returns `{ "[INFO]" }` when `$AutomaticAssistance` is `True`, otherwise `None`.
3. Otherwise, combines results from `methodStopTokens` and `styleStopTokens`, plus `"[INFO]"` if `$AutomaticAssistance` is enabled, deduplicating and returning `None` if empty.

**`methodStopTokens`** dispatches on `"ToolMethod"`:

| ToolMethod | Stop Tokens |
| ---------- | ----------- |
| `"Simple"` | `{ "\n/exec", <EndToken> }` |
| `"Service"` | `{ <EndToken> }` |
| `"Textual"` / `"JSON"` | `{ "ENDTOOLCALL", <EndToken> }` |
| Other | `{ "ENDTOOLCALL", "\n/exec", <EndToken> }` |

Non-string values like `None` are filtered out via `Select[..., StringQ]`.

**`styleStopTokens`** dispatches on `"ToolCallExamplePromptStyle"`:

| Style | Stop Tokens |
| ----- | ----------- |
| `"Phi"` | `{ "<\|user\|>", "<\|assistant\|>" }` |
| `"Llama"` | `{ "<\|start_header_id\|>" }` |
| `"Gemma"` | `{ "<start_of_turn>" }` |
| `"Nemotron"` | `{ "<extra_id_0>", "<extra_id_1>" }` |
| `"DeepSeekCoder"` | `{ "<\:ff5cbegin\:2581of\:2581sentence\:ff5c>" }` |
| Other / `None` | `{ }` |

### Model-Specific Overrides

- **`Missing["NotSupported"]`**: GPT-5/GPT-5.1/GPT-5.2 (family-level), O3, O4-Mini

### Accepted Values

`Automatic`, `None`, `{ }`, `{ __String }` (list of strings), or `_Missing`.

### Implementation

**LLMServices path:** `makeStopTokens` is called explicitly and passed as `"StopTokens"` in the `LLMConfiguration`. `Missing` values are removed by `DeleteMissing`. Note: `"StopTokens"` is **not** in `$llmConfigPassedKeys` — it is handled separately via explicit `makeStopTokens` calls in both `makeLLMConfiguration` branches.

**Legacy path:** In `makeHTTPRequest` (`SendChat.wl`), `makeStopTokens` converts the resolved value to an API-ready format: `None|{ }|_Missing` -> `Missing[]` (stripped from request), `{ __String }` -> passed as-is to the `"stop"` field.

**Post-response cleanup:** `trimStopTokens` (`SendChat.wl`) removes any stop token found at the end of the response text from both `"FullContent"` and `"DynamicContent"` via `StringDelete[..., stop ~~ EndOfString]`.

### Integration Points

- **Dependencies**: Not in `$autoSettingKeyDependencies`, but implicitly depends on `"ToolMethod"`, `"ToolCallExamplePromptStyle"`, `"ToolsEnabled"`, and `"EndToken"` (resolved after `"ToolMethod"` in `resolveAutoSettings0`).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- **Notebook conversion**: Not listed in `$popOutSettings`.

### Preferences UI

Not exposed in the preferences UI.

## `"TokenBudgetMultiplier"`

Multiplier applied to `MaxContextTokens` to produce the working token budget for chat message construction.

### Resolution

When `Automatic`, resolved by `resolveAutoSetting0` (`Settings.wl`) to `1` (no scaling).

### Accepted Values

Any non-negative numeric value (`$$size` pattern: non-negative `_Integer` or `_Real`, or `Infinity`), as well as `Automatic`.

- Values less than `1` (e.g., `0.8`) restrict the effective context to a fraction of the model's full window.
- Values greater than `1` allow exceeding the nominal context limit.

### Implementation

The token budget is computed by `makeTokenBudget` (`ChatMessages.wl`): `Ceiling[MaxContextTokens * TokenBudgetMultiplier]`. When set to an unspecified value (`Missing`, `Automatic`, or `Inherited`), the token budget equals `MaxContextTokens` unchanged.

This budget is assigned to `$tokenBudget` in `makeChatMessages` (`ChatMessages.wl`) and is decremented as each message is added to the context. When a message's token count exceeds the remaining budget, it is truncated via `cutMessageContent`. Token pressure is tracked as `1.0 - ($tokenBudget / MaxContextTokens)`, and the cell string budget (`$cellStringBudget`) dynamically decreases as pressure rises, dropping to `0` when fewer than `$reservedTokens` (500) tokens remain.

### Integration Points

- **Model-specific overrides**: None in `$modelAutoSettings`.
- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook for token budget management).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- **Notebook conversion**: Not listed in `$popOutSettings`.

### Preferences UI

Not exposed in the preferences UI.
