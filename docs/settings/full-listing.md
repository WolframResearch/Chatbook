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
| `"Model"` | `$DefaultModel` | The LLM model specification. |
| `"Authentication"` | `Automatic` | Authentication method for the LLM service. |
| `"EnableLLMServices"` | `Automatic` | Whether Chatbook uses the `LLMServices` framework for LLM communication. |
| `"Multimodal"` | `Automatic` | Whether multimodal (image) input is supported, controlling whether graphics and images in notebook cells are encoded and included in messages sent to the LLM. |

See additional details in [Model and Service Settings](setting-groups/model-and-service.md).

## LLM Parameters

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"Temperature"` | `Automatic` | Sampling temperature for the LLM, controlling randomness in token selection. |
| `"FrequencyPenalty"` | `0.1` | Penalty applied to tokens based on their frequency in the text so far. |
| `"PresencePenalty"` | `Automatic` | Penalty applied to tokens based on whether they have appeared in the text so far, encouraging the model to introduce new topics. |
| `"TopP"` | `1` | Top-p (nucleus) sampling parameter, controlling the cumulative probability threshold for token selection. |
| `"MaxTokens"` | `Automatic` | Maximum number of tokens the LLM may generate in its response (output token limit). |
| `"MaxContextTokens"` | `Automatic` | Maximum token capacity of the context window, used internally for token budgeting and context management. |
| `"Reasoning"` | `Automatic` | Controls the reasoning/thinking effort level for models that support extended thinking. |
| `"StopTokens"` | `Automatic` | Stop sequences that signal the LLM to stop generating. |
| `"TokenBudgetMultiplier"` | `Automatic` | Multiplier applied to `MaxContextTokens` to produce the working token budget for chat message construction. |

See additional details in [LLM Parameter Settings](setting-groups/llm-parameters.md).

## Chat Behavior

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"IncludeHistory"` | `Automatic` | Whether to include chat history (preceding cells) in the context sent to the LLM. |
| `"ChatHistoryLength"` | `1000` | Maximum number of chat cells to include in the context. |
| `"MergeMessages"` | `True` | Whether to merge consecutive messages with the same role into a single message. |
| `"MaxCellStringLength"` | `Automatic` | Maximum string length for cell content included in the LLM context. |
| `"MaxOutputCellStringLength"` | `Automatic` | Maximum string length for output cell content included in the LLM context. |
| `"ForceSynchronous"` | `Automatic` | Whether to force synchronous (non-streaming) chat requests. |
| `"TimeConstraint"` | `Automatic` | Time limit (in seconds) for the overall chat task evaluation. |
| `"ConvertSystemRoleToUser"` | `Automatic` | Whether to convert system-role messages to user-role messages. |
| `"ReplaceUnicodeCharacters"` | `Automatic` | Whether to replace Wolfram Language special characters (Unicode private use area codepoints such as `\[FreeformPrompt]`) with ASCII equivalents before sending messages to the LLM. |
| `"BypassResponseChecking"` | `Automatic` | Whether to bypass response validation after receiving an LLM response. |
| `"Assistance"` | `Automatic` | Whether automatic assistance mode is enabled. |

See additional details in [Chat Behavior Settings](setting-groups/chat-behavior.md).

## Prompting

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"BasePrompt"` | `Automatic` | Specifies which base prompt components to include in the system prompt. |
| `"ExcludedBasePrompts"` | `Automatic` | List of base prompt component names to exclude from the system prompt. |
| `"ChatContextPreprompt"` | `Automatic` | **Deprecated.** Legacy preprompt text used as the "Pre" section of the system prompt. |
| `"UserInstructions"` | `Automatic` | User-provided instructions to include in the system prompt. |
| `"Prompts"` | `{}` | A list of custom prompt strings to append to the system prompt. |
| `"PromptGenerators"` | `Automatic` | List of prompt generators used to augment the conversation with additional context before sending messages to the LLM. |
| `"PromptGeneratorsEnabled"` | `Automatic` | **Not yet implemented.** Intended to control which prompt generators are enabled. |
| `"PromptGeneratorMessagePosition"` | `2` | Position in the message list where prompt generator messages are inserted. |
| `"PromptGeneratorMessageRole"` | `"System"` | Message role assigned to prompt generator messages when they are inserted into the conversation. |
| `"DiscourageExtraToolCalls"` | `Automatic` | Whether to include a base prompt component discouraging unnecessary tool calls. |

See additional details in [Prompting Settings](setting-groups/prompting.md).

## Tools

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"Tools"` | `Automatic` | Tool definitions available to the LLM, resolved as a list of `LLMTool` objects. |
| `"ToolsEnabled"` | `Automatic` | Whether tools are enabled for the current chat. |
| `"ToolMethod"` | `Automatic` | Mechanism for tool calling (`"Service"`, `"Simple"`, `"Textual"`, `"JSON"`, or `Automatic`). |
| `"HybridToolMethod"` | `Automatic` | Whether to combine service-level and prompt-based tool calling. |
| `"ToolOptions"` | `$DefaultToolOptions` | Per-tool option overrides mapping tool names to option associations. |
| `"ToolSelectionType"` | `<\|\|>` | Per-tool global override: `All` (always enabled), `None` (always disabled), or `Inherited` (per-persona). |
| `"ToolCallFrequency"` | `Automatic` | How often the LLM should use tools (`Automatic` or a number between `0` and `1`). |
| `"ToolCallRetryMessage"` | `Automatic` | Whether to append a retry-guidance system message after each tool response. |
| `"ToolExamplePrompt"` | `Automatic` | Tool example prompt included in the system prompt to demonstrate tool usage patterns. |
| `"ToolCallExamplePromptStyle"` | `Automatic` | Template style for tool call examples in the system prompt. |
| `"ToolResponseRole"` | `Automatic` | Message role assigned to tool response messages sent back to the LLM. |
| `"ToolResponseStyle"` | `Automatic` | How tool response content is wrapped/formatted before being sent back to the LLM. |
| `"SplitToolResponseMessages"` | `Automatic` | Whether to split tool responses into separate messages. |
| `"MaxToolResponses"` | `5` | Maximum number of tool responses allowed per chat turn. |
| `"SendToolResponse"` | `Automatic` | Whether to send tool responses back to the LLM for further processing. |
| `"EndToken"` | `Automatic` | End-of-turn token that signals the LLM has finished its response. |

See additional details in [Tools Settings](setting-groups/tools.md).

## Formatting & Output

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"AutoFormat"` | `True` | Whether to auto-format LLM output by parsing Markdown syntax and converting it to structured notebook cells. |
| `"DynamicAutoFormat"` | `Automatic` | Whether to apply formatting during streaming, providing live-formatted output as the LLM response streams in. |
| `"StreamingOutputMethod"` | `Automatic` | Controls the method used for streaming output display, specifically whether the streaming content is progressively split into static (already-written) and dynamic (still-updating) portions during LLM response streaming. |
| `"NotebookWriteMethod"` | `Automatic` | Method for writing content to the notebook, controlling whether FrontEnd task batching is used for notebook write operations during chat. |
| `"TabbedOutput"` | `True` | Whether to use paged (tabbed) output for multi-turn chat responses, so that each new LLM response replaces the previous one in the same output cell rather than creating a separate cell. |
| `"ShowMinimized"` | `Automatic` | Whether LLM response output cells are displayed in a minimized (collapsed) state. |
| `"ShowProgressText"` | `Automatic` | Whether to show progress text (e.g., status labels with an ellipsis indicator) in the progress panel while the LLM is generating a response. |
| `"OpenToolCallBoxes"` | `Automatic` | Whether tool call display boxes are initially expanded (open) when rendered in the notebook. |
| `"TrackScrollingWhenPlaced"` | `Automatic` | Whether to auto-scroll the notebook to follow new output as it is placed during and after LLM response streaming. |
| `"AppendCitations"` | `Automatic` | Whether to automatically append formatted source citations to the LLM response. |

See additional details in [Formatting & Output Settings](setting-groups/formatting-and-output.md).

## Personas & UI

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"LLMEvaluator"` | `"CodeAssistant"` | The persona (LLM evaluator) to use, determining the system prompt, available tools, and other settings. |
| `"PersonaFavorites"` | N/A | List of persona names marked as favorites, controlling persona selector menu ordering. |
| `"VisiblePersonas"` | `$corePersonaNames` | List of persona names controlling which personas appear in the persona selector UI. |
| `"ChatDrivenNotebook"` | `False` | **Deprecated.** Whether the notebook operates in "chat-driven" mode. |
| `"InitialChatCell"` | `True` | Whether to create an initial empty chat input cell when opening a new chat notebook. |
| `"ChatInputIndicator"` | `Automatic` | Text prefix prepended to `"ChatInput"` cells when serializing notebook content for the LLM. |
| `"SetCellDingbat"` | `True` | Whether to set cell dingbats (icons) on chat cells. |
| `"EnableChatGroupSettings"` | `False` | Whether chat group-level settings are enabled, allowing parent group headers to contribute prompts. |
| `"AllowSelectionContext"` | `Automatic` | Whether to allow the current notebook selection to be used as context. |
| `"CurrentPreferencesTab"` | `"Services"` | Persists the user's last-selected tab in the Chatbook preferences dialog. |

See additional details in [Personas & UI Settings](setting-groups/personas-and-ui.md).

## Storage & Conversations

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"ConversationUUID"` | `None` | UUID identifying the current conversation, used as the primary key for persistent storage, search indexing, and chat history listings. |
| `"AutoSaveConversations"` | `Automatic` | Whether to automatically save conversations to persistent storage after chat evaluations. |
| `"AppName"` | `Automatic` | Application name used to namespace saved conversations, search indexes, and chat history listings. |
| `"MinimumResponsesToSave"` | `1` | Minimum number of assistant responses required before a conversation is automatically saved. |
| `"TargetCloudObject"` | `Automatic` | Target `CloudObject` location for deploying cloud-based chat notebooks via `CreateChatNotebook`. |

See additional details in [Storage & Conversations Settings](setting-groups/storage-and-conversations.md).

## Advanced / Internal

| Setting | Default | Description |
| ------- | ------- | ----------- |
| `"Tokenizer"` | `Automatic` | Tokenizer function used for token counting throughout the chat pipeline. |
| `"HandlerFunctions"` | `$DefaultChatHandlerFunctions` | Callback functions invoked at various stages of chat processing (e.g., `"ChatPre"`, `"ChatPost"`, `"ToolRequestReceived"`). |
| `"HandlerFunctionsKeys"` | `Automatic` | Keys to include in the handler functions callback data passed to `ChatSubmit` and `URLSubmit`. |
| `"InheritanceTest"` | N/A | Internal diagnostic flag used by the settings inheritance verification system. Not user-configurable. |
| `"ProcessingFunctions"` | `$DefaultChatProcessingFunctions` | Callback functions that control the chat processing pipeline (cell conversion, message post-processing, chat submission, output formatting, and cell writing). |
| `"ConversionRules"` | `None` | Custom transformation rules applied to notebook cells before serialization to chat message strings. |
| `"ExperimentalFeatures"` | `Automatic` | List of enabled experimental feature names, resolved dynamically from other settings. |
| `"OpenAIKey"` | `Automatic` | **Deprecated.** OpenAI API key for the legacy (non-LLMServices) HTTP request path. |
| `"OpenAIAPICompletionURL"` | `"https://api.openai.com/v1/chat/completions"` | **Deprecated.** OpenAI API completion endpoint URL for the legacy (non-LLMServices) HTTP request path. |

See additional details in [Advanced / Internal Settings](setting-groups/advanced-and-internal.md).

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

The first match wins. For details on how to add support for new models, see [TODO: How to Add Support for New Models]().

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
