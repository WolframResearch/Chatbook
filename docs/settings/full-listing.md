# Settings Listing

## Overview

Chatbook settings control LLM behavior, prompt construction, tool usage, formatting, and UI behavior. Settings are stored in notebook tagging rules under `"ChatNotebookSettings"` and follow a hierarchical inheritance model.

### Accessing Settings

Use `CurrentChatSettings` to read and write settings:

```wl
(* Read global settings *)
CurrentChatSettings[]
CurrentChatSettings["Temperature"]

(* Read settings scoped to a notebook or cell *)
CurrentChatSettings[notebookObj]
CurrentChatSettings[cellObj, "Model"]

(* Write settings *)
CurrentChatSettings[$FrontEnd, "Temperature"] = 0.5
CurrentChatSettings[notebookObj, "AutoFormat"] = False

(* Reset to inherited value *)
CurrentChatSettings[notebookObj, "Temperature"] =.
```

### Inheritance Model

Settings resolve through a hierarchy, with more specific scopes overriding broader ones:

| Scope              | Description                      |
| ------------------ | -------------------------------- |
| `CellObject`       | Per-cell override                |
| `NotebookObject`   | Per-notebook settings            |
| `$FrontEndSession` | Session-wide (non-persistent)    |
| `$FrontEnd`        | Global persistent settings       |

If a setting is not defined at a given scope, it inherits from the next broader scope. A value of `Inherited` explicitly defers to the parent scope.

### Automatic Values

Many settings default to `Automatic`, meaning they are resolved at runtime based on the current model, service, and other settings. The resolution pipeline is defined in `Settings.wl` via `resolveAutoSettings`, which evaluates `Automatic` values in topologically sorted dependency order. Model-specific defaults are looked up from `$modelAutoSettings`.

---

## Model & Service

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"Model"` | `$DefaultModel` | The LLM model specification. For Wolfram Engine 14.1+, defaults to `<\|"Service" -> "LLMKit", "Name" -> Automatic\|>`. For older versions, defaults to `<\|"Service" -> "OpenAI", "Name" -> "gpt-4o"\|>`. Can be an `Association` with `"Service"` and `"Name"` keys. |
| `"Authentication"` | `Automatic` | Authentication method for the LLM service. When `Automatic`, resolves based on the model: `"LLMKit"` for LLMKit service models, otherwise `Automatic` (uses the service's default authentication). |
| `"EnableLLMServices"` | `Automatic` | Whether LLM services are enabled. Resolves to the internal `$useLLMServices` flag. |
| `"Multimodal"` | `Automatic` | Whether multimodal (image) input is supported. Resolved per model (e.g., `True` for Claude 4, GPT-4.1, Gemini 2+; `False` for O1-Mini, O3-Mini). |
| `"Reasoning"` | `Automatic` | Whether model reasoning/chain-of-thought is enabled. Model-specific; only supported by certain models (e.g., O-series, GPT-5). Models that don't support it return `Missing["NotSupported"]`. |

## LLM Parameters

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"Temperature"` | `Automatic` | Sampling temperature for the LLM. Higher values increase randomness. Model default: `0.7`. Some models (e.g., O4-Mini, GPT-5) return `Missing["NotSupported"]`. |
| `"FrequencyPenalty"` | `0.1` | Penalty applied to tokens based on their frequency in the text so far. Reduces repetition. |
| `"PresencePenalty"` | `Automatic` | Penalty applied to tokens based on whether they have appeared in the text so far. Model default: `0.1`. Some models (e.g., Google Gemini, O4-Mini, GPT-5) return `Missing["NotSupported"]`. |
| `"TopP"` | `1` | Top-p (nucleus) sampling parameter. A value of `1` considers all tokens. |
| `"MaxTokens"` | `Automatic` | Maximum number of tokens in the LLM response. Resolved per model. |
| `"MaxContextTokens"` | `Automatic` | Maximum token capacity of the context window. Model-specific (e.g., 200,000 for Claude 3/4, 128,000 for GPT-4o, 1,047,576 for Gemini 2+/GPT-4.1). |
| `"StopTokens"` | `Automatic` | Stop sequences that signal the LLM to stop generating. Some models return `Missing["NotSupported"]`. The resolved stop tokens include the `"EndToken"` value when applicable. |
| `"TokenBudgetMultiplier"` | `Automatic` | Multiplier for the token budget calculation. Default: `1`. |

## Chat Behavior

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"IncludeHistory"` | `Automatic` | Whether to include chat history in the context. When `Automatic`, history inclusion is determined by the chat mode. |
| `"ChatHistoryLength"` | `1000` | Maximum number of tokens of chat history to include in the context. |
| `"MergeMessages"` | `True` | Whether to merge consecutive messages with the same role into a single message. |
| `"MaxCellStringLength"` | `Automatic` | Maximum string length for input cell content included in the context. Resolved based on model and `MaxContextTokens`. |
| `"MaxOutputCellStringLength"` | `Automatic` | Maximum string length for output cell content included in the context. Resolved based on `MaxCellStringLength`. |
| `"ForceSynchronous"` | `Automatic` | Whether to force synchronous (non-streaming) chat requests. Some models require this (e.g., O1, O3, O4-Mini). Resolved per model. |
| `"TimeConstraint"` | `Automatic` | Time limit (in seconds) for chat evaluation. |
| `"ConvertSystemRoleToUser"` | `Automatic` | Whether to convert system-role messages to user-role messages. Model default: `False`. Required for some models (e.g., O1-Mini). |
| `"ReplaceUnicodeCharacters"` | `Automatic` | Whether to replace Unicode characters with ASCII equivalents before sending to the LLM. Model default: `False`. Enabled for Anthropic models and some OpenAI models (e.g., GPT-5.2). |
| `"BypassResponseChecking"` | `Automatic` | Whether to bypass response checking after receiving a response. Resolves to `True` when `ForceSynchronous` is `True`. |
| `"Assistance"` | `Automatic` | Whether automatic assistance mode is enabled. Default: `False`. |

## Prompting

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"BasePrompt"` | `Automatic` | [TODO] Base system prompt configuration. Behavior defined in `Prompting.wl` and `ChatMessages.wl`. |
| `"ExcludedBasePrompts"` | `Automatic` | List of base prompt names to exclude. Model default: `{ParentList}` (inherits from parent model settings). Some models add `"EscapedCharacters"` to the exclusion list. |
| `"ChatContextPreprompt"` | `Automatic` | [TODO] Preprompt text added to provide chat context. |
| `"UserInstructions"` | `Automatic` | User-provided instructions to include in the system prompt. |
| `"Prompts"` | `{}` | Additional prompt messages to include in the conversation. |
| `"PromptGenerators"` | `Automatic` | [TODO] List of prompt generators to use for augmenting prompts with additional context (e.g., related documentation, Wolfram Alpha results). Behavior defined in the `PromptGenerators/` directory. Default when `Automatic`: `{}`. |
| `"PromptGeneratorsEnabled"` | `Automatic` | [TODO] Which prompt generators are enabled. Behavior defined in the `PromptGenerators/` directory. |
| `"PromptGeneratorMessagePosition"` | `2` | Position in the message list where prompt generator messages are inserted. |
| `"PromptGeneratorMessageRole"` | `"System"` | Message role used for prompt generator messages. |
| `"DiscourageExtraToolCalls"` | `Automatic` | Whether to include a prompt discouraging unnecessary tool calls. Model-specific (e.g., enabled for Claude 3.7 Sonnet). |

## Tools

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"Tools"` | `Automatic` | [TODO] Tool definitions available to the LLM. Behavior defined in the `Tools/` directory. When `Automatic`, tools are resolved based on the persona and `ToolsEnabled` setting. |
| `"ToolsEnabled"` | `Automatic` | Whether tools are enabled for the current chat. Resolved per model (e.g., disabled for Gemini Pro/Pro Vision). |
| `"ToolMethod"` | `Automatic` | Method for tool calling. `"Service"` uses the LLM service's native tool calling API. Other values use prompt-based tool calling. Model-specific defaults. |
| `"HybridToolMethod"` | `Automatic` | Whether to use hybrid tool calling, combining service-level and prompt-based tool calling. Only available for OpenAI, AzureOpenAI, and LLMKit services. Resolved based on model, `ToolsEnabled`, and `ToolMethod`. |
| `"ToolOptions"` | `$DefaultToolOptions` | Per-tool option overrides. Default provides options for `"WolframAlpha"`, `"WolframLanguageEvaluator"`, `"WebFetcher"`, `"WebSearcher"`, and `"WebImageSearcher"`. See `Tools/Common.wl` for the full default. |
| `"ToolSelectionType"` | `<\|\|>` | Tool selection configuration. An empty association by default. |
| `"ToolCallFrequency"` | `Automatic` | How often the LLM is allowed to make tool calls. Default: `Automatic`. |
| `"ToolCallRetryMessage"` | `Automatic` | Whether to send retry messages when a tool call fails. Resolves to `True` for LLMKit-authenticated sessions, `False` for some models (e.g., GPT-4.1, GPT-5). |
| `"ToolExamplePrompt"` | `Automatic` | Tool example prompt specification included in the system prompt to guide tool usage. Resolved per model (e.g., `None` for Claude 3). |
| `"ToolCallExamplePromptStyle"` | `Automatic` | Style of tool call example prompts (`"Basic"` or `Automatic`). Model-specific. |
| `"ToolResponseRole"` | `Automatic` | Message role used for tool response messages. Model default: `"System"`. Some models use `"User"` (e.g., Claude 2, MistralAI, DeepSeek Reasoner, local models like Qwen/Nemotron/Mistral). |
| `"ToolResponseStyle"` | `Automatic` | Style used for formatting tool responses. MistralAI uses `"SystemTags"`. |
| `"SplitToolResponseMessages"` | `Automatic` | Whether to split tool responses into separate messages. Model default: `False`. Enabled for Anthropic models as a workaround. |
| `"MaxToolResponses"` | `5` | Maximum number of tool responses per chat turn. Some models use lower values (e.g., `3` for O1, O3, O4-Mini). |
| `"SendToolResponse"` | `Automatic` | Whether to send tool responses back to the LLM for further processing. |
| `"EndToken"` | `Automatic` | End-of-response token that signals the LLM has finished its response after tool calls. Model default: `"/end"`. Some models use `None` (e.g., GPT-4.1). |

## Formatting & Output

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"AutoFormat"` | `True` | Whether to auto-format LLM output by converting Markdown to structured notebook cells. |
| `"DynamicAutoFormat"` | `Automatic` | Whether to use dynamic formatting during streaming, providing live-formatted output as the response streams in. |
| `"StreamingOutputMethod"` | `Automatic` | Method for streaming output display. Default: `"PartialDynamic"`. |
| `"NotebookWriteMethod"` | `Automatic` | Method for writing content to the notebook. Default: `"PreemptiveLink"`. |
| `"TabbedOutput"` | `True` | Whether to use tabbed output for organizing long or multi-part responses. |
| `"ShowMinimized"` | `Automatic` | Whether to show output in a minimized/collapsed state. |
| `"ShowProgressText"` | `Automatic` | Whether to show progress text while the LLM is generating a response. Model default: `True`. |
| `"OpenToolCallBoxes"` | `Automatic` | Whether tool call display boxes are open by default. Resolves to `True` when `SendToolResponse` is `False`, otherwise `Automatic`. |
| `"TrackScrollingWhenPlaced"` | `Automatic` | Whether to auto-scroll the notebook to follow new output as it is placed. |
| `"AppendCitations"` | `Automatic` | Whether to automatically append formatted source citations to the LLM response. When enabled, citations are generated from sources gathered by prompt generators (e.g., documentation, web searches, WolframAlpha results) and appended as a markdown section. When disabled, the WolframAlpha prompt generator instead includes a hint asking the LLM to cite sources inline. Model default: `False`. The WolframAlpha persona overrides this to `True`. |

## Personas & UI

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"LLMEvaluator"` | `"CodeAssistant"` | The persona (LLM evaluator) to use. Determines the system prompt, available tools, and other settings. See the `LLMConfiguration/Personas/` directory for built-in personas. |
| `"VisiblePersonas"` | `$corePersonaNames` | List of persona names visible in the persona selector UI. |
| `"ChatDrivenNotebook"` | `False` | Whether the entire notebook operates in chat-driven mode. This is a non-inherited persona value. |
| `"InitialChatCell"` | `True` | Whether to create an initial chat input cell when opening a chat notebook. This is a non-inherited persona value. |
| `"ChatInputIndicator"` | `Automatic` | Character or expression used as the chat input indicator. Default: `"\|01f4ac"` (speech balloon emoji). |
| `"SetCellDingbat"` | `True` | Whether to set cell dingbats (icons) on chat cells. |
| `"EnableChatGroupSettings"` | `False` | Whether chat group-level settings are enabled. |
| `"AllowSelectionContext"` | `Automatic` | Whether to allow the current selection to be used as context. Resolves to `True` when using workspace chat, inline chat, or sidebar chat. |

## Storage & Conversations

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"ConversationUUID"` | `None` | UUID identifying the current conversation. `None` means no conversation tracking. |
| `"AutoSaveConversations"` | `Automatic` | Whether to automatically save conversations. Resolved based on `AppName` and `ConversationUUID`. |
| `"AppName"` | `Automatic` | Application name used to namespace saved conversations, search indexes, and chat history listings. When `Automatic`, resolves to `$defaultAppName` (`"Default"`). When set to a non-default string value, also establishes a service caller context via `setServiceCaller`. Chat modes may override this (e.g., NotebookAssistance uses `"NotebookAssistance"`). The `AutoSaveConversations` setting depends on `AppName` being a valid string. |
| `"MinimumResponsesToSave"` | `1` | Minimum number of assistant responses required before a conversation is saved. |
| `"TargetCloudObject"` | `Automatic` | Target cloud object for cloud-based conversation storage. |

## Advanced / Internal

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"Tokenizer"` | `Automatic` | Tokenizer used for token counting. Resolved based on the model's tokenizer name. |
| `"HandlerFunctions"` | `$DefaultChatHandlerFunctions` | [TODO] Callback functions invoked at various stages of chat processing (e.g., `"ChatPre"`, `"ChatPost"`, `"ChatAbort"`, `"ToolRequestReceived"`, `"ToolResponseGenerated"`, `"PromptGeneratorStart"`, `"PromptGeneratorEnd"`, `"AppendCitationsStart"`, `"AppendCitationsEnd"`). Spans multiple files. |
| `"HandlerFunctionsKeys"` | `Automatic` | Keys to include in handler function arguments. Resolved based on `EnableLLMServices`. |
| `"ProcessingFunctions"` | `$DefaultChatProcessingFunctions` | [TODO] Functions that control the chat processing pipeline (e.g., `"CellToChatMessage"`, `"ChatMessages"`, `"ChatSubmit"`, `"FormatChatOutput"`, `"FormatToolCall"`, `"WriteChatOutputCell"`). Spans multiple files. |
| `"ConversionRules"` | `None` | [TODO] Rules for converting between notebook content and chat message formats. Behavior defined in `Serialization.wl`. |
| `"ExperimentalFeatures"` | `Automatic` | [TODO] List of enabled experimental features. Composite setting resolved from other settings (e.g., `"WolframAlphaCAGEnabled"`, `"WebSearchRAGMethod"`, `"PromptGenerators"`). Behavior spread across codebase. |
| `"OpenAIKey"` | `Automatic` | OpenAI API key. Legacy setting for direct OpenAI API authentication. |
| `"OpenAIAPICompletionURL"` | `"https://api.openai.com/v1/chat/completions"` | OpenAI API completion endpoint URL. Legacy setting for direct OpenAI API access. |

---

## Model-Specific Auto Settings

When a setting has a value of `Automatic`, the resolution pipeline checks `$modelAutoSettings` for a model-specific default. Settings are looked up in order of specificity:

1. Service + model name (e.g., `$modelAutoSettings["Anthropic", "Claude4"]`)
2. Service + model ID
3. Service + model family
4. Any service + model name (e.g., `$modelAutoSettings[Automatic, "GPT4Omni"]`)
5. Any service + model ID
6. Any service + model family
7. Service-level default (e.g., `$modelAutoSettings["Anthropic", Automatic]`)
8. Global default (`$modelAutoSettings[Automatic, Automatic]`)

The first match wins. For details on how to add support for new models, see [TODO: How to Add Support for New Models].

### Global Auto Setting Defaults

These are the fallback values from `$modelAutoSettings[Automatic, Automatic]` when no model-specific override exists:

| Setting | Default |
| ------- | ------- |
| `"AppendCitations"` | `False` |
| `"ConvertSystemRoleToUser"` | `False` |
| `"EndToken"` | `"/end"` |
| `"ExcludedBasePrompts"` | `{ParentList}` |
| `"PresencePenalty"` | `0.1` |
| `"ReplaceUnicodeCharacters"` | `False` |
| `"ShowProgressText"` | `True` |
| `"SplitToolResponseMessages"` | `False` |
| `"Temperature"` | `0.7` |
| `"ToolResponseRole"` | `"System"` |

### Non-Inherited Persona Values

The following settings are not inherited from the persona configuration when resolving settings. They retain their value from the notebook/cell scope:

- `"ChatDrivenNotebook"`
- `"CurrentPreferencesTab"`
- `"EnableLLMServices"`
- `"Icon"`
- `"InheritanceTest"`
- `"InitialChatCell"`
- `"LLMEvaluator"`
- `"PersonaFavorites"`
- `"ServiceDefaultModel"`
