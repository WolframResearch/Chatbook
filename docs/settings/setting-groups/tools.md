# Tools Settings

## `"Tools"`

Tool definitions available to the LLM, resolved as a list of `LLMTool` objects during chat processing.

### Accepted Values

- **`Automatic`** (default) — resolve from persona and defaults
- **`None`** — no tools
- **`All`** — all available tools
- **`Inherited`** — inherit from parent scope
- **List of strings** — e.g., `{"WolframLanguageEvaluator", "WebSearcher"}`
- **List of `LLMTool` objects**
- **Mixed list** — strings, `LLMTool` objects, rules (`name -> tool`), and `ParentList`

After resolution, the value is always a flat list of `LLMTool` objects (`{ ___LLMTool }`).

### Resolution

Resolution only occurs when `ToolsEnabled` is `True`; otherwise the setting remains unchanged. The process works as follows:

1. `initTools` initializes the tool system.
2. `selectTools` determines which tools are active based on three inputs:
   - Tool names from `getToolNames`
   - Per-persona tool selections from `getToolSelections` (stored in `"ToolSelections"`)
   - Per-tool selection types from `getToolSelectionTypes` (stored in `"ToolSelectionType"`)
3. The resolved `$selectedTools` association (filtered by `toolEnabledQ`, which checks each tool's `"Enabled"` key) is stored as `Values @ $selectedTools` (a list of `LLMTool` objects) back into the `"Tools"` key of the settings.

The `getToolNames` function (`Tools/Common.wl`) determines the initial tool name list through a two-level dispatch:

- If the persona declares tools (via `LLMEvaluator["Tools"]`), persona tools and setting-level tools are combined.
- If the persona sets `None`, no tools are used.
- If the persona uses `Automatic`, `Inherited`, or `ParentList`, default tools are used.
- `ParentList` within a persona's tool list causes the parent scope's tools to be spliced in at that position.

### LLM Configuration

Consumed in two places:

1. **`makeLLMConfiguration`** (`SendChat.wl`) — when `ToolMethod` is `"Service"` or `HybridToolMethod` is `True`, tools are passed to `LLMConfiguration` as `"Tools" -> Cases[Flatten @ {as["Tools"]}, _LLMTool]`, enabling the LLM service's native tool calling API. When neither condition holds, tools are omitted from `LLMConfiguration` and tool calling is handled entirely through prompt-based instructions.
2. **`constructLLMConfiguration`** (`LLMUtilities.wl`) — tools are read from `settings["Tools"]`, each processed by `addToolPostProcessing`, validated with `ConfirmMatch[..., { ___LLMTool }]`, and passed to the `LLMConfiguration`.

If `WolframLanguageEvaluator` is among the selected tools, `resolveTools` triggers the `"WolframLanguageEvaluatorTool"` base prompt component via `needsBasePrompt`.

### Persona Overrides

- **CodeAssistant / AgentOne / AgentOneCoder**: `{"WolframLanguageEvaluator", "DocumentationSearcher", "WolframAlpha", ParentList}`
- **WolframAlpha**: `{"WolframAlpha", ParentList}`
- **PlainChat**: `{"WebSearcher", "WebImageSearcher", "WebFetcher", ParentList}`
- **CodeWriter**: `{ParentList}`
- **RawModel**: `None` (no tools)
- **Wolfie / Birdnardo / NotebookAssistant**: custom tool lists with `ParentList`

### Integration Points

- **Dependencies**: Depends on `"LLMEvaluator"` and `"ToolsEnabled"` (declared in `$autoSettingKeyDependencies`).
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed directly; conditionally included by `makeLLMConfiguration` as described above).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations. Not listed in `$modelInheritedLists`.
- **ChatPreferences tool**: Listed in `$usableChatSettingsKeys` with an `interpretTools` validator that checks tool names against `$AvailableTools`.
- **Dynamic tracking**: Changes trigger `$toolsTrigger` (`Dynamics.wl`), updating tool-dependent UI elements.

### Preferences UI

Exposed indirectly via the "Tools" tab (`PreferencesContent.wl`), which renders the `toolSettingsPanel` (`ToolManager.wl`) providing a grid interface to install, enable/disable, and configure tools per persona.

## `"ToolsEnabled"`

Whether tools are enabled for the current chat.

### Accepted Values

`Automatic`, `True`, or `False`.

### Resolution

When `Automatic`, resolved per model via `toolsEnabledQ` (`Settings.wl`):

1. If explicitly set to `True` or `False`, that value is used directly.
2. If `ToolCallFrequency` is non-positive (`0` or negative), returns `False`.
3. If the model has a model-specific override in `$modelAutoSettings`, that value is used.
4. The model name is checked against `$$disabledToolsModel` — models matching `"chat-bison-001"`, `"gemini-1.0-pro"` (and variants), `"gemini-pro-vision"`, or `"gemini-pro"` (case-insensitive) return `False`.
5. All other models return `True`.

### Model-Specific Overrides

- **`False`**: GoogleGemini GeminiPro, GoogleGemini GeminiProVision, O1Mini
- **`True`**: GoogleGemini Gemini2, GoogleGemini Gemini3

### Downstream Effects

- **Tool resolution**: `resolveTools` (`Tools/Common.wl`) only initializes and selects tools when `ToolsEnabled` is `True`; otherwise the `"Tools"` setting remains unchanged.
- **Tool prompt**: `getToolPrompt` (`ChatMessages.wl`) returns `""` when `False`, suppressing tool instructions in the system prompt.
- **Discourage extra tool calls**: `discourageExtraToolCallsQ` returns `False` when `ToolsEnabled` is `False`.
- **Response handling**: `checkResponse` (`SendChat.wl`) has a special pattern for `ToolsEnabled -> False` that either writes the result directly or defers it based on `$AutomaticAssistance`.
- **Stop tokens**: `autoStopTokens` returns `{ "[INFO]" }` when `$AutomaticAssistance` is `True` and `ToolsEnabled` is `False`, otherwise `None`.
- **Hybrid tool method**: `hybridToolMethodQ` returns `False` when `ToolsEnabled` is `False`.
- **Tool example prompt style**: `chooseToolExamplePromptStyle` returns `None` when `ToolsEnabled` is `False`.
- **Tool Manager warning**: `toolModelWarning` (`ToolManager.wl`) displays `$toolsDisabledWarning` when `False`.

### Integration Points

- **Dependencies**: Depends on `"Model"` and `"ToolCallFrequency"` (declared in `$autoSettingKeyDependencies`). Is a dependency for `"HybridToolMethod"`, `"ToolCallExamplePromptStyle"`, and `"Tools"`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook to gate tool-related features).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- Not listed in `$usableChatSettingsKeys`, `$popOutSettings`, or `$modelInheritedLists`.

### Preferences UI

Exposed via `makeToolsEnabledMenu` (`PreferencesContent.wl`) as a `PopupMenu` with three choices: "Enabled by Model" (`Automatic`), "Enabled Always" (`True`), and "Enabled Never" (`False`), in the Features content section.

## `"ToolMethod"`

Controls the mechanism by which the LLM invokes tools.

### Accepted Values

- **`"Service"`** — uses the LLM service's native tool calling API
- **`"Simple"`** — uses slash-command format with `/exec` markers
- **`"Textual"` / `"JSON"`** — uses `ENDTOOLCALL`-based prompt format
- **`Automatic`** — resolved dynamically

### Resolution

When `Automatic`, resolved by `chooseToolMethod` (`Settings.wl`): if all resolved tools are "simple tools" (members of `$DefaultTools`), resolves to `"Simple"`; otherwise remains `Automatic` (treated as a generic prompt-based method using `ENDTOOLCALL` markers). Automatic resolution happens in `resolveAutoSettings0` after `Tools` has been resolved.

### Effects by Method

**LLM Configuration:**
- `"Service"`: `makeLLMConfiguration` passes `"ToolMethod" -> "Service"` and `LLMTool` definitions to `LLMConfiguration`.
- Non-`"Service"`: Tool definitions are omitted from `LLMConfiguration`; tool calling is handled through prompt-based instructions.

**Tool Prompts** (`makeToolPrompt` in `Tools/Common.wl`):
- `"Service"`: Returns `Nothing` (no prompt injection).
- `"Simple"`: Uses `$simpleToolPre`/`$simpleToolListing`/`$simpleToolPost`.
- Other methods: Uses `$toolPre`/`$toolListing`/`$toolPost`.

**Message Preparation:**
- `"Service"`: `prepareMessagesForLLM0` rewrites messages via `rewriteServiceToolCalls`.
- Other methods: `"ToolRequests"` and `"ToolResponses"` keys are dropped from messages.

**Tool Call Parsing:**
- `"Simple"`: Uses `simpleToolRequestParser`.
- Other methods: Uses `toolRequestParser`.

**Tool Response Formatting:**
- `"Service"`: Tool response role is forced to `"Tool"` regardless of `ToolResponseRole`.
- Other methods: Uses the `ToolResponseRole` value.

**Stop Tokens:**

| Method | Stop Tokens |
| ------ | ----------- |
| `"Simple"` | `"\n/exec"` |
| `"Service"` | (only `$endToken`) |
| `"Textual"` / `"JSON"` | `"ENDTOOLCALL"` |
| Other/fallback | both `"ENDTOOLCALL"` and `"\n/exec"` |

When `"Service"`, also triggers the `"ServiceToolCallRetry"` base prompt component.

### Model-Specific Overrides

- **`"Service"`**: Anthropic (general), AzureOpenAI, DeepSeek Chat, OpenAI (general), GPT-3.5, GPT-5, O1, O3, O4-Mini
- **`Verbatim @ Automatic`** (keeps prompt-based tools, often paired with `HybridToolMethod -> True`): Claude 2, GPT-4o, GPT-4.1, O3-Mini

### Integration Points

- **Dependencies**: Not in `$autoSettingKeyDependencies` (no dependencies on other settings), but is a dependency of `HybridToolMethod`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys`; `"ToolMethod" -> "Service"` is conditionally added by `makeLLMConfiguration`.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- The global variable `$simpleToolMethod` (`CommonSymbols.wl`, set in `Formatting.wl`) tracks whether the current method is `"Simple"`.

### Preferences UI

Not exposed in the preferences UI.

## `"HybridToolMethod"`

Whether to use hybrid tool calling, combining service-level and prompt-based tool calling.

### Resolution

When `Automatic`, resolved by `hybridToolMethodQ` (`Settings.wl`):

1. Returns `False` if `ToolsEnabled` is `False`.
2. Returns `False` if `ToolMethod` is `"Service"` (hybrid is unnecessary when service-level calling is already in use).
3. Returns `True` if the model matches `$$hybridToolModel` (service is `"OpenAI"`, `"AzureOpenAI"`, or `"LLMKit"`, or the model is a plain string).
4. Returns `False` for all other models.

### Behavior

When `True`, `makeLLMConfiguration` builds the `LLMConfiguration` with `"ToolMethod" -> "Service"` and includes `LLMTool` definitions, enabling the LLM service's native tool calling API *alongside* Chatbook's prompt-based tool calling. The model receives both prompt-based tool instructions and service-level tool definitions.

When `False`, the `LLMConfiguration` omits tool definitions and relies solely on the prompt-based tool method.

### Model-Specific Overrides

- **`True`**: GPT-4o, GPT-4.1, O3-Mini (which use `ToolMethod -> Verbatim @ Automatic` to keep prompt-based tools alongside service tools)
- **`False`**: DeepSeek Reasoner, GPT-5, O1, O3, O4-Mini (which use pure `"Service"` tool method or have limited tool support)

### Integration Points

- **Dependencies**: Depends on `"Model"`, `"ToolsEnabled"`, and `"ToolMethod"` (declared in `$autoSettingKeyDependencies`).
- **LLM passthrough**: Not in `$llmConfigPassedKeys`, but indirectly controls whether `LLMConfiguration` includes `"ToolMethod" -> "Service"` and `"Tools"`.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"ToolOptions"`

Per-tool option overrides as a nested `Association` mapping tool names to their option associations.

### Default Value

The default `$DefaultToolOptions` (`Tools/Common.wl`) provides options for five tools:

| Tool | Options |
| ---- | ------- |
| `"WolframAlpha"` | `"DefaultPods" -> False`, `"FoldPods" -> False`, `"MaxPodByteCount" -> 1000000` |
| `"WolframLanguageEvaluator"` | `"AllowedExecutePaths" -> Automatic`, `"AllowedReadPaths" -> All`, `"AllowedWritePaths" -> Automatic`, `"AppendURIPrompt" -> False`, `"EvaluationTimeConstraint" -> 60`, `"Method" -> Automatic`, `"PingTimeConstraint" -> 30` |
| `"WebFetcher"` | `"MaxContentLength" -> 12000` |
| `"WebSearcher"` | `"AllowAdultContent" -> Inherited`, `"Language" -> Inherited`, `"MaxItems" -> 5`, `"Method" -> "Google"` |
| `"WebImageSearcher"` | (same keys as `"WebSearcher"`) |

The default is defined with delayed evaluation (`:>`) in `$defaultChatSettings`, so it evaluates `$DefaultToolOptions` fresh each time.

### Implementation

During chat processing, `resolveTools` (`Tools/Common.wl`) assigns the resolved value to the `$toolOptions` global variable. Individual tool option values are accessed at runtime through `toolOptionValue[toolName, key]` (`Tools/ToolOptions.wl`), which checks `$toolOptions` first and falls back to `$DefaultToolOptions`.

Tool implementations use this to read their configuration: e.g., `Sandbox.wl` reads `"EvaluationTimeConstraint"`, `"Method"`, `"AllowedReadPaths"`, `"AllowedWritePaths"`, `"AllowedExecutePaths"`, `"AppendURIPrompt"`, and `"PingTimeConstraint"` for `"WolframLanguageEvaluator"`; `WolframAlpha.wl` reads `"DefaultPods"`, `"FoldPods"`, and `"MaxPodByteCount"`; `WebFetcher.wl` reads `"MaxContentLength"`.

### Programmatic Access

Users can modify tool options via `SetToolOptions` (exported in `Main.wl`):

```wl
(* Global override *)
SetToolOptions["WolframLanguageEvaluator", "EvaluationTimeConstraint" -> 120]

(* Notebook-scoped override *)
SetToolOptions[notebookObj, "WebSearcher", "MaxItems" -> 10]

(* Reset to defaults *)
SetToolOptions["WolframAlpha", Inherited]
```

Options are stored in `{TaggingRules, "ChatNotebookSettings", "ToolOptions", toolName, optionKey}`.

### Chat Mode Overrides

NotebookAssistance mode (`ShowNotebookAssistance.wl`) sets `"WolframLanguageEvaluator" -> <|"AppendURIPrompt" -> True, "Method" -> "Session"|>`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook to configure tool behavior).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- Not listed in `$usableChatSettingsKeys` or the `ChatPreferences` tool definition.

### Preferences UI

Not exposed in the preferences UI.

## `"ToolSelectionType"`

Per-tool override that controls whether a tool is enabled globally (for all personas), disabled globally, or left to per-persona selection.

### Accepted Values

The value is an `Association` mapping tool canonical names (strings) to one of three values:

- **`All`** — tool is always enabled regardless of persona
- **`None`** — tool is never enabled regardless of persona
- **`Inherited`** — tool enablement is determined per-persona via the `"ToolSelections"` setting

When a tool's canonical name is absent from the association, it behaves as `Inherited`. The default empty association (`<||>`) means all tools default to per-persona selection behavior.

### Implementation

Used by `selectTools` (`Tools/Common.wl`) during tool resolution: `getToolSelectionTypes` retrieves this setting and filters it to keys present in `$AvailableTools`. Tools with selection type `All` are added to the selected tool set unconditionally (unioned with per-persona selections), while tools with selection type `None` are removed unconditionally (even if selected by the persona).

When a per-persona checkbox is toggled manually in the Tool Manager, the `ToolSelectionType` for that tool is automatically unset (reverting to `Inherited`), since explicit per-persona selections supersede the global override.

Used by `enableTool` (`ResourceInstaller.wl`) to set a newly installed tool's selection type to `All`, making it immediately available. Used by `deleteTool` (`ToolManager.wl`) to clean up the selection type when a tool is uninstalled.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally to determine the active tool set).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- Not listed in `$usableChatSettingsKeys`, `$popOutSettings`, or `$modelInheritedLists`.

### Preferences UI

Exposed via the Tool Manager (`ToolManager.wl`) as a `PopupMenu` per tool row with three options: "Enabled by persona" (`Inherited`), "Never" (`None`), and "Always" (`All`). The Tool Manager also provides a clear/reset button that unsets both `"ToolSelections"` and `"ToolSelectionType"` for a given tool. In the cloud UI, `cloudToolEnablePopup` (`PreferencesContent.wl`) provides a similar popup.

## `"ToolCallFrequency"`

Controls how often the LLM should use tools.

### Accepted Values

`Automatic` or a number between `0` and `1`.

### Resolution

When `Automatic`, no tool frequency preference prompt is injected into the system message.

When set to a numeric value, `makeToolPreferencePrompt` (`Tools/Common.wl`) injects a "User Tool Call Preferences" section into the system prompt. The frequency value is scaled to a percentage and mapped to one of six explanation levels:

| Level | Frequency | Instruction |
| ----- | --------- | ----------- |
| 0 | 0% | "Only use a tool if explicitly instructed" |
| 1 | ~20% | "Avoid using tools unless necessary" |
| 2 | ~40% | "Only use tools if it will significantly improve quality" |
| 3 | ~60% | "Use tools whenever appropriate" |
| 4 | ~80% | "Use tools whenever there's even a slight chance of improvement" |
| 5 | 100% | "ALWAYS make a tool call in EVERY response" |

Setting this to a non-positive value (`0` or negative) causes `ToolsEnabled` to resolve to `False`, effectively disabling all tools.

### Integration Points

- **Dependencies**: The `ToolsEnabled` setting declares a dependency on `ToolCallFrequency` in `$autoSettingKeyDependencies`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally to generate the preference prompt).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- **ChatPreferences tool**: Listed as a `Restricted["Number", {0, 1}]` parameter, allowing the LLM itself to adjust this setting.

### Preferences UI

Exposed in the preferences UI (`PreferencesContent.wl`) as a popup menu (Automatic/Custom) with a slider from "Rare" to "Often" when "Custom" is selected; selecting "Custom" defaults the frequency to `0.5`. Also exposed in the advanced chat UI (`UI.wl`) as a slider with an option to reset to `Inherited`.

## `"ToolCallRetryMessage"`

Whether to append a retry-guidance system message after each tool response.

### Resolution

When `Automatic`, resolved by `toolCallRetryMessageQ` (`Settings.wl`), which delegates to `llmKitQ`: returns `True` if the session uses LLMKit authentication (i.e., `Authentication` is `"LLMKit"`, or the model's `"Service"` or `"Authentication"` is `"LLMKit"`), `False` otherwise.

### Behavior

When `True`, `makeToolResponseMessage` (`SendChat.wl`) appends `$toolCallRetryMessage` — a system message with `"HoldTemporary" -> True` containing: *"IMPORTANT: If a tool call does not give the expected output, ask the user before retrying unless you are ABSOLUTELY SURE you know how to fix the issue."* The `"HoldTemporary"` flag means this message is included in the current request but not persisted in the conversation history.

### Model-Specific Overrides

- **`False`**: GPT-4.1, GPT-5 (and GPT-5.1/GPT-5.2 via inheritance)

### Integration Points

- **Dependencies**: Depends on `"Authentication"` and `"Model"` (declared in `$autoSettingKeyDependencies`).
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally to control tool response message construction).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"ToolExamplePrompt"`

Specifies the tool example prompt included in the system prompt to demonstrate tool usage patterns to the LLM.

### Accepted Values

- **`Automatic`** — generates examples from `$fullExamples` (`Tools/Examples.wl`) using the `ToolCallExamplePromptStyle`
- **`None`** — no example prompt is included
- **Custom template** — any value matching `$$template` (`_String`, `_TemplateObject`, `_TemplateExpression`, `_TemplateSequence`) is used directly

### Resolution

When `Automatic`, resolved by `chooseToolExamplePromptSpec` (`Settings.wl`), which delegates to `autoToolExamplePromptSpec` based on the model's service — currently returns `Automatic` for all services. The example prompt is generated by `getToolExamplePrompt` (`Tools/Common.wl`) as part of `makeToolPrompt`, which assembles the full tool prompt from five components: tool pre-prompt, tool listing, tool example prompt, tool post-prompt, and tool preference prompt.

If `ToolCallExamplePromptStyle` is `None`, the example prompt is also omitted.

### Model-Specific Overrides

- **`None`**: Claude 3 (Anthropic Claude3 family)
- **`Automatic`**: Claude 3.7 Sonnet (overriding the inherited `None` from Claude 3)

### Persona Overrides

Personas can provide a `ToolExamplePrompt` file (`.md`, `.txt`, `.wl`, `.m`, or `.wxf`) in their LLM configuration directory, loaded by the persona system (`Personas.wl`).

### Integration Points

- **Dependencies**: Depends on `"Model"` (declared in `$autoSettingKeyDependencies`).
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally for tool system prompt construction).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"ToolCallExamplePromptStyle"`

Style of chat message templates used for tool call example prompts in the system prompt.

### Accepted Values

`"Basic"`, `"ChatML"`, `"XML"`, `"Instruct"`, `"Phi"`, `"Llama"`, `"Gemma"`, `"Nemotron"`, `"DeepSeekCoder"`, `"Zephyr"`, `"Boxed"`, `None`, or `Automatic`.

### Resolution

When `Automatic`, resolved based on service and model family (e.g., OpenAI/AzureOpenAI -> `"ChatML"`, Anthropic -> `"XML"`, local models use family-specific templates). `None` when tools are disabled.

Also determines style-specific stop tokens (see `"StopTokens"` in [LLM Parameter Settings](llm-parameters.md)).

### Integration Points

- **Dependencies**: Depends on `"Model"` and `"ToolsEnabled"` (declared in `$autoSettingKeyDependencies`).
- **Implementation**: Defined in `Tools/Examples.wl`; used by `getToolExamplePrompt` in `Tools/Common.wl`.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"ToolResponseRole"`

The message role assigned to tool response messages sent back to the LLM.

### Accepted Values

`Automatic`, `"System"`, `"User"`, or `"Tool"`.

### Resolution

When `Automatic`, resolved to `"System"` via the persona default in `$modelAutoSettings[Automatic, Automatic]`. When `ToolMethod` is `"Service"`, the role is forced to `"Tool"` regardless of this setting's value.

### Implementation

Used by `makeToolResponseMessage` (`SendChat.wl`) to set the `"Role"` key. The role also affects message formatting:

- `"User"`: Content is wrapped in `<tool_response>...</tool_response>` tags.
- `"SystemTags"` style active (via `ToolResponseStyle`): Content is wrapped in `<system>...</system>` tags.
- Otherwise: Response content is used as-is.

### Model-Specific Overrides

- **`"User"`**: Anthropic Claude 2, DeepSeek Reasoner, all MistralAI models, TogetherAI Reasoner, local models (Qwen, Nemotron, Mistral)

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: As listed above.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally for tool response message construction).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"ToolResponseStyle"`

Controls how tool response content is wrapped/formatted before being sent back to the LLM.

### Accepted Values

`Automatic`, `"SystemTags"`, or other style strings.

### Implementation

Used by `makeToolResponseMessage0` (`SendChat.wl`):

- **`"SystemTags"`**: Content is wrapped in `<system>...</system>` tags; role defaults to `"System"`.
- **`ToolResponseRole` is `"User"`**: Content is wrapped in `<tool_response>...</tool_response>` tags.
- **`Automatic` / other**: Response content is used as-is.

Note: `"SystemTags"` takes priority over `"User"` role — if both apply, the `"SystemTags"` pattern matches first.

### Model-Specific Overrides

- **`"SystemTags"`**: MistralAI (paired with `ToolResponseRole` -> `"User"`)
- No global default in `$modelAutoSettings[Automatic, Automatic]`, so `Automatic` is the effective default for most models.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally for tool response formatting).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"SplitToolResponseMessages"`

Whether to split tool responses into separate messages.

### Resolution

When `Automatic`, resolved to `False` (model default). Enabled for Anthropic models as a workaround.

### Integration Points

- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"MaxToolResponses"`

Maximum number of tool responses allowed per chat turn before the tool-calling loop is stopped.

### Default Value

`5` (fixed numeric value, not `Automatic`).

### Implementation

During each chat turn, the `$toolCallCount` global variable (`CommonSymbols.wl`) is incremented each time the LLM makes a tool call (`SendChat.wl`), initialized to `0` via `ChatState.wl`. The `sendToolResponseQ` function (`SendChat.wl`) checks whether to continue the tool-calling loop: if `$toolCallCount > n` (where `n` is the `MaxToolResponses` value), it returns `False`, stopping the chat via `throwTop @ StopChat @ cell`.

Note: the comparison uses `>` (not `>=`), so the LLM can make up to `n + 1` tool calls before being stopped.

### Model-Specific Overrides

- **`3`**: O1, O3, O4-Mini (OpenAI reasoning models)

### Chat Mode Overrides

NotebookAssistance mode explicitly sets this to `5` in `$notebookAssistanceBaseSettings`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally to control the tool-calling loop).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- **Notebook conversion**: Listed in `$popOutSettings` (`ConvertChatNotebook.wl`).

### Preferences UI

Not exposed in the preferences UI.

## `"SendToolResponse"`

Whether to send tool responses back to the LLM for further processing.

### Behavior by Value

- **`False`**: The tool still executes and its output is displayed, but the result is not sent back to the LLM for a follow-up response. The `sendToolResponseQ` function returns `False`, ending the chat turn via `throwTop @ StopChat @ cell`.
- **`Automatic`** (default): Tool responses are sent back unless the tool itself signals that it is terminal — individual tools can include `"SendToolResponse" -> False` in their output data, and the `terminalToolResponseQ`/`terminalQ` functions (`SendChat.wl`) detect this to stop the loop for that specific tool call.

### Dependent Settings

Affects `OpenToolCallBoxes` via `$autoSettingKeyDependencies`: when `SendToolResponse` is `False`, `openToolCallBoxesQ` returns `True`, causing tool call boxes to be expanded so the user can see the tool output directly (since it won't be summarized by the LLM).

### Integration Points

- **Dependencies**: None for this setting, but `"OpenToolCallBoxes"` depends on it.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally to control the tool-calling loop).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"EndToken"`

End-of-turn token that signals the LLM has finished its response.

### Default Value

Model default: `"/end"`. Some models use `None` (e.g., GPT-4.1). The resolved value is stored in the `$endToken` global variable (`CommonSymbols.wl`).

### Implementation

Used in three ways:

1. **Base prompt instruction**: The `"EndTurnToken"` base prompt component (`Prompting.wl`) adds `"* Always end your turn by writing /end."` to the system prompt when `$endToken` is a non-empty string. The related `"EndTurnToolCall"` component adds `"* If you are going to make a tool call, you must do so BEFORE ending your turn."`.

2. **Stop tokens**: `$endToken` is included in stop sequences via `methodStopTokens` (`Settings.wl`):
   - `"Textual"` / `"JSON"`: `{"ENDTOOLCALL", $endToken}`
   - `"Service"`: `{$endToken}`
   - `"Simple"`: `{"\n/exec", $endToken}`

3. **Tool call example templates**: `Tools/Examples.wl` uses `$endTokenString` (which prepends `"\n"` to `$endToken`) in assistant message templates across all example styles to show the LLM how to end its turn.

When `None` or empty, the end token is omitted from prompts, stop sequences, and example templates. After receiving a response, `trimStopTokens` in `SendChat.wl` removes stop tokens (including the end token) from the output.

### Model-Specific Overrides

- **`None`**: GPT-4.1
- All other models use the default `"/end"`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.
