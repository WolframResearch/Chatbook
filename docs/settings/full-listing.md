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
| `"Reasoning"` | `Automatic` | Whether model reasoning/chain-of-thought is enabled. |

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
| `"Tokenizer"` | `Automatic` | Tokenizer function used for token counting throughout the chat pipeline. When `Automatic`, resolved via `getTokenizer` (`ChatMessages.wl`) using a three-step fallback: (1) if an explicit non-`Automatic` tokenizer function is already set, it is used directly; (2) if `"TokenizerName"` is a string, the corresponding cached tokenizer is looked up via `cachedTokenizer`; (3) otherwise, the tokenizer is derived from the `"Model"` setting by extracting the model name and matching it to a known tokenizer. Pre-cached tokenizer functions exist for `"chat-bison"` (UTF-8 byte encoding via `ToCharacterCode`), `"gpt-4-vision"` and `"gpt-4o"` (with special image token counting for `Graphics` content), `"claude-3"` (with Claude-specific image token counting), and `"generic"` (GPT-2 fallback). Additional tokenizers are loaded on demand from `.wxf` files in the `Assets/Tokenizers/` directory, or discovered via `Wolfram`LLMFunctions`Utilities`Tokenization`FindTokenizer`; if no model-specific tokenizer is found, the generic GPT-2 tokenizer is used as a fallback. The resolved tokenizer is applied via `applyTokenizer` in `tokenCount` (`ChatMessages.wl`), which tokenizes message content and returns the token list length. The `"Tokenizer"` value can also be set to a custom function (any expression other than `Automatic`/`$$unspecified`), in which case that function is used directly; if the custom value is a string, it is treated as a tokenizer name and the `"TokenizerName"` key is set to the resolved name while `"Tokenizer"` is reset to `Automatic` during `resolveAutoSettings` (`Settings.wl`). Explicitly dropped from saved notebook settings via `toSmallSettings` (`SendChat.wl`, `KeyDrop[as, {"OpenAIKey", "Tokenizer"}]`) because tokenizer functions cannot be serialized. Serialized to a name-based reference (`<| "_Object" -> "Tokenizer", "Data" -> name |>`) in `Feedback.wl` for diagnostic reporting. Depends on `"TokenizerName"` in `$autoSettingKeyDependencies`, which in turn depends on `"Model"`. No model-specific overrides exist in `$modelAutoSettings`. Not in `$llmConfigPassedKeys` (not passed to the LLM service via `LLMConfiguration`; used internally by Chatbook for token counting). Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations. Not in `$popOutSettings`. Not exposed in the preferences UI. |
| `"HandlerFunctions"` | `$DefaultChatHandlerFunctions` | Callback functions invoked at various stages of chat processing. The value is an `Association` mapping event name strings to handler functions (or `None` to skip). The default value `$DefaultChatHandlerFunctions` (`Settings.wl`) defines 9 event keys, all defaulting to `None`: `"AppendCitationsStart"`, `"AppendCitationsEnd"`, `"ChatAbort"`, `"ChatPost"`, `"ChatPre"`, `"PromptGeneratorEnd"`, `"PromptGeneratorStart"`, `"ToolRequestReceived"`, and `"ToolResponseGenerated"`. The `"ChatAbort"`, `"ChatPost"`, and `"ChatPre"` entries use `RuleDelayed` (`:>`) pointing to global variables `$ChatAbort`, `$ChatPost`, and `$ChatPre` (all initially `None`), allowing runtime reassignment without modifying the association. A 10th event, `"ToolResponseReceived"`, is also dispatched via `applyHandlerFunction` (`SendChat.wl`) but is not included in the default association (falls back to `None` via `getHandlerFunction`). Custom handler values are merged with defaults during resolution: `resolveHandlers` in `Handlers.wl` creates a new association with `$DefaultChatHandlerFunctions` as the base, overlaid with user-provided handlers (after `replaceCellContext` processing), plus a `"Resolved" -> True` marker to prevent re-resolution. Resolution occurs during `resolveAutoSettings` (`Settings.wl`), where `getHandlerFunctions` is called on the settings and the result replaces the `"HandlerFunctions"` key. Each handler function is invoked via `applyHandlerFunction` (`Handlers.wl`), which constructs an argument association containing: `"EventName"` (the event type string), `"ChatNotebookSettings"` (current settings with `"Data"` and `"OpenAIKey"` keys dropped), and event-specific data. This argument association is accumulated in the `$ChatHandlerData` global variable (publicly exported) via `addHandlerArguments`, which merges new data with existing handler state (supporting nested association merging). The handler receives `$ChatHandlerData` with `"DefaultProcessingFunction"` dropped. Event dispatch locations: `"ChatPre"` is called in `sendChat` (`SendChat.wl`) before chat submission, with `"EvaluationCell"` and `"Messages"` in the arguments; `"ChatPost"` and `"ChatAbort"` are called in `applyChatPost` (`Actions.wl`) after chat completion or abort, with `"ChatObject"` and `"NotebookObject"` in the arguments; `"ToolRequestReceived"` is called after parsing a tool call (`SendChat.wl`), with `"ToolRequest"` in the arguments; `"ToolResponseGenerated"` is called after generating a tool response (`SendChat.wl`), with `"ToolResponse"` and `"ToolResponseString"` in the arguments; `"ToolResponseReceived"` is called after the tool response is formatted and ready to send back (`SendChat.wl`), with `"ToolResponse"` in the arguments; `"PromptGeneratorStart"` and `"PromptGeneratorEnd"` are called in `DefaultPromptGenerators.wl` around each prompt generator execution, with `"PromptGenerator"` in the arguments (and `"PromptGeneratorResult"` added for the end event); `"AppendCitationsStart"` and `"AppendCitationsEnd"` are called in `Citations.wl` around citation generation, with `"Sources"` and `"CitationString"` respectively. In the streaming chat submission path (`chatHandlers` in `SendChat.wl`), the resolved handlers are passed to `LLMServices`ChatSubmit` via the `HandlerFunctions` parameter, but `"ChatPost"`, `"ChatPre"`, and `"Resolved"` keys are dropped (listed in `$chatSubmitDroppedHandlers`). The `chatHandlers` function also wraps custom `"BodyChunkReceived"` and `"TaskFinished"` handlers (if provided) inside Chatbook's own streaming logic, calling the user's handler before Chatbook's processing for each body chunk and after task completion. Not passed through `LLMConfiguration` (not in `$llmConfigPassedKeys`). Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations. No dependencies in `$autoSettingKeyDependencies`. No model-specific overrides exist in `$modelAutoSettings`. Not exposed in the preferences UI. |
| `"HandlerFunctionsKeys"` | `Automatic` | Keys to include in the handler functions callback data passed to `LLMServices`ChatSubmit` and `URLSubmit`. Controls which fields from the streaming response are available to handler functions. When `Automatic` or unspecified, resolves to `$defaultHandlerKeys` (`SendChat.wl`): `{"Body", "BodyChunk", "BodyChunkProcessed", "StatusCode", "TaskStatus", "EventName"}`. When a list of strings, the user-provided keys are merged with `$defaultHandlerKeys` via `Union` (so the default keys are always included). When a single string, it is treated as a one-element list. Invalid values trigger an `"InvalidHandlerKeys"` warning (`Common.wl`) and fall back to `$defaultHandlerKeys`. Resolution is performed by `chatHandlerFunctionsKeys` (`SendChat.wl`), which is called from `resolveAutoSetting0` (`Settings.wl`). The resolved value is passed directly as the `HandlerFunctionsKeys` parameter to `LLMServices`ChatSubmit` (for LLMServices-based chat) and `URLSubmit` (for legacy HTTP-based chat) in `chatSubmit0` (`SendChat.wl`). Also used in other `URLSubmit` calls outside of chat: `VectorDatabases.wl` uses `{"ByteCountDownloaded", "StatusCode"}` for vector database downloads, and `RelatedWolframAlphaResults.wl` uses `{"StatusCode", "BodyByteArray"}` for Wolfram Alpha result fetching. Not passed through `LLMConfiguration` (not in `$llmConfigPassedKeys`). Depends on `"EnableLLMServices"` for resolution ordering in `$autoSettingKeyDependencies`. Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations. No model-specific overrides exist in `$modelAutoSettings`. Not exposed in the preferences UI. |
| `"InheritanceTest"` | N/A | Internal diagnostic flag used by the settings inheritance verification system. Not a user-configurable setting and not included in `$defaultChatSettings`. During `verifyInheritance0` (`Settings.wl`), this flag is set to `True` at the `$FrontEnd` scope via `setCurrentValue[fe, {TaggingRules, "ChatNotebookSettings", "InheritanceTest"}, True]` to mark that the inheritance chain for tagging rules has been properly initialized. Subsequent calls to `verifyInheritance` check this flag via `inheritingQ`, which reads `AbsoluteCurrentValue[obj, {TaggingRules, "ChatNotebookSettings", "InheritanceTest"}]` — if `True` (or if the read fails), the object is considered to have valid inheritance and initialization is skipped. During `repairTaggingRules`, the flag is explicitly removed from child objects (notebooks, cells) so that it only persists at the top-level `FrontEndObject`, preventing it from appearing as an explicit override in child scopes. The `verifyInheritance` function is called by `currentChatSettings0` before reading or writing settings, ensuring the inheritance chain is intact. Listed in `$nonInheritedPersonaValues`, so it retains its value from notebook/cell scope rather than inheriting from persona configurations. No model-specific overrides exist. Not exposed in the preferences UI. |
| `"ProcessingFunctions"` | `$DefaultChatProcessingFunctions` | An `Association` of callback functions that control the chat processing pipeline, allowing complete customization of how cells are converted to messages, how messages are post-processed, how chat requests are submitted, how output is formatted, and how output cells are written. The default value `$DefaultChatProcessingFunctions` (`Settings.wl`) is defined using `RuleDelayed` (`:>`) in `$defaultChatSettings` so it is evaluated lazily. It contains six keys: `"CellToChatMessage" -> CellToChatMessage` (converts individual notebook `Cell` expressions to message Associations with `"Role"` and `"Content"` keys; retrieved via `getCellMessageFunction` in `ChatMessages.wl` and wrapped by `checkedMessageFunction`, which validates that custom functions return valid message results — plain strings are auto-wrapped with the cell's role, and invalid results fall back to the default `CellToChatMessage`); `"ChatMessages" -> (#1 &)` (identity function that post-processes the combined message list after construction and prompt generator augmentation; called via `applyProcessingFunction[settings, "ChatMessages", HoldComplete[combined, $ChatHandlerData]]` in `augmentChatMessages` (`ChatMessages.wl`); the result is validated against `$$validMessageResults` and if invalid, an `"InvalidMessages"` warning is printed and the original messages are used instead); `"ChatSubmit" -> Automatic` (submits the prepared messages to the LLM service; when `Automatic`, resolves to `LLMServices``ChatSubmit` in the modern LLMServices path or `URLSubmit` in the legacy HTTP path, selected via the `"DefaultSubmitFunction"` parameter passed to `applyProcessingFunction`; called in `chatSubmit0` (`SendChat.wl`) with the standardized messages, `LLMConfiguration`, authentication, handler functions, and handler function keys as arguments); `"FormatChatOutput" -> FormatChatOutput` (formats the LLM response text for notebook display; retrieved via `getFormattingFunction` in `SendChat.wl`, which wraps it to set `$ChatHandlerData["EventName"]` to `"FormatChatOutput"` before calling; `FormatChatOutput` (`Formatting.wl`) dispatches on a status Association with a `"Status"` key — `"Streaming"` for live-formatted output during streaming, `"Finished"` for final formatting, `"Waiting"` for a progress indicator — and converts Markdown to formatted notebook expressions via `reformatTextData`); `"FormatToolCall" -> FormatToolCall` (formats tool call data for display in the notebook; retrieved both via `getToolFormatter` in `SendChat.wl` (which wraps it similarly to set `$ChatHandlerData["EventName"]`) and directly from `$ChatHandlerData["ChatNotebookSettings", "ProcessingFunctions", "FormatToolCall"]` in `inlineToolCall` (`Formatting.wl`) for inline tool call rendering; `FormatToolCall` (`Formatting.wl`) takes a raw tool call string and parsed data Association, with an optional info Association containing `"Status"`); `"WriteChatOutputCell" -> WriteChatOutputCell` (writes the formatted output cell to the notebook; called via `applyProcessingFunction[settings, "WriteChatOutputCell", HoldComplete[cell, new, info]]` inside `createTask` in `writeReformattedCell` (`SendChat.wl`); `WriteChatOutputCell` (`SendChat.wl`) has two main definitions: for inline chat (`$InlineChat`), it delegates to `writeInlineChatOutputCell`; for regular chat, it uses `NotebookWrite` to insert the cell, sets cell tags from the `"ExpressionUUID"` in the info Association, attaches the chat output menu via `attachChatOutputMenu`, and handles scrolling via `scrollOutput` based on the `"ScrollOutput"` info key). During `resolveAutoSettings` (`Settings.wl`), the value is resolved via `getProcessingFunctions` (`Handlers.wl`), which calls `resolveFunctions`: this merges user-provided overrides on top of `$DefaultChatProcessingFunctions`, applies `replaceCellContext` to convert `$CellContext` symbols to the global context, and marks the result with `"Resolved" -> True` to prevent re-resolution. Invalid values trigger an `"InvalidFunctions"` warning (`Common.wl`) and fall back to defaults. Each processing function is invoked via `applyProcessingFunction` (`Handlers.wl`), which retrieves the function via `getProcessingFunction` (falling back through the resolved association, then `$DefaultChatProcessingFunctions`), merges parameters with `$ChatHandlerData` (adding `"ChatNotebookSettings"` and `"DefaultProcessingFunction"` to the handler data), applies the function to its held arguments, and logs timing via `LogChatTiming`. The `$DefaultChatProcessingFunctions` variable is publicly exported (`Main.wl`). No dependencies in `$autoSettingKeyDependencies`. No model-specific overrides exist in `$modelAutoSettings`. Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for pipeline customization). Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations. Not listed in `$popOutSettings`. Not listed in `$droppedSettingsKeys`. Not exposed in the preferences UI. |
| `"ConversionRules"` | `None` | Custom transformation rules applied to notebook cells before they are serialized to chat message strings. When `None` (default), cells are passed through unmodified. When set to a list of replacement rules, the rules are compiled into a `Dispatch` table (cached for reuse) and applied to each cell via `ReplaceRepeated` inside `CellToString` (`Serialization.wl`) before string conversion occurs. This enables custom box-level or expression-level transformations of cell content prior to sending it to the LLM. The setting value is read from `CurrentChatSettings` in `makeChatMessages` (`ChatMessages.wl`) and stored in the dynamic variable `$conversionRules`, which `CellToString` picks up as its default `"ConversionRules"` option. Invalid values (neither a rule list nor a valid `Dispatch` table) trigger an `"InvalidConversionRules"` warning and fall back to `None`. |
| `"ExperimentalFeatures"` | `Automatic` | List of enabled experimental feature names, resolved dynamically from other settings. When `Automatic`, the `autoExperimentalFeatures` function (`Settings.wl`) builds a list based on two conditions: `"RelatedWolframAlphaResults"` is included if `"WolframAlphaCAGEnabled"` is `True` or `"RelatedWolframAlphaResults"` is in the `"PromptGenerators"` list; `"RelatedWebSearchResults"` is included if `"WebSearchRAGMethod"` is `"Tavily"` or `"WebSearch"` is in the `"PromptGenerators"` list. The resolved list is stored in the `$experimentalFeatures` global variable (`Settings.wl`) and preserved across handler evaluation via `ChatState.wl`. Individual features are checked at runtime via `featureEnabledQ` (`Settings.wl`), which tests membership in the resolved list. The primary consumer is `resolvePromptGenerators` in `PromptGenerators/Common.wl`, which appends `"RelatedWolframAlphaResults"` and/or `"WebSearch"` to the active prompt generators list based on feature flags. Depends on `"WolframAlphaCAGEnabled"`, `"WebSearchRAGMethod"`, and `"PromptGenerators"` (declared in `$autoSettingKeyDependencies`). No model-specific overrides exist. Not exposed in the preferences UI. |
| `"OpenAIKey"` | `Automatic` | **Deprecated.** OpenAI API key used for direct OpenAI API authentication in the legacy (non-LLMServices) HTTP request path. Only used when `EnableLLMServices` resolves to `False` (i.e., the `Wolfram/LLMFunctions` paclet is not installed or `EnableLLMServices` is explicitly `False`). When `Automatic`, the key is resolved at chat time by `toAPIKey` (`Actions.wl`), which checks in order: (1) `SystemCredential["OPENAI_API_KEY"]`, (2) `Environment["OPENAI_API_KEY"]`, (3) an interactive API key dialog (`apiKeyDialog`); if none produces a valid string, throws a `"NoAPIKey"` failure. If already a string, the value is used directly. The resolved key is assigned back into the settings association (`settings["OpenAIKey"] = key`) in the legacy `sendChat` overload (`SendChat.wl`), then used by `makeHTTPRequest` (`SendChat.wl`) to construct the `"Authorization"` header (`"Bearer " <> key`) for the `HTTPRequest` sent to `OpenAIAPICompletionURL`. The entire legacy `sendChat` overload and `toAPIKey` function are marked with TODO comments indicating they are obsolete once LLMServices is widely available. In the modern code path (`$useLLMServices` is `True`), this setting is completely unused — the `LLMServices` framework handles authentication internally via the `Authentication` setting and service-specific credential management. **Security handling**: the `maskOpenAIKey` function (`Common.wl`) replaces actual key values with `"**********"` in all diagnostic, debug, and error output. The key is explicitly dropped from: saved notebook settings via `toSmallSettings` (`SendChat.wl`, `KeyDrop[as, {"OpenAIKey", "Tokenizer"}]`), handler function callback data via `$settingsDroppedKeys` (`Handlers.wl`), and notebook settings diagnostic output (`Common.wl`). Not resolved during `resolveAutoSettings` — there is no `resolveAutoSetting0` case for `"OpenAIKey"`, so `Automatic` persists until `toAPIKey` is called at chat time. No dependencies in `$autoSettingKeyDependencies`. No model-specific overrides exist in `$modelAutoSettings`. Not in `$llmConfigPassedKeys` (not passed through `LLMConfiguration`). Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations. Not in `$popOutSettings`. Not exposed in the preferences UI. |
| `"OpenAIAPICompletionURL"` | `"https://api.openai.com/v1/chat/completions"` | **Deprecated.** OpenAI API completion endpoint URL, used only in the legacy (non-LLMServices) HTTP request path. The default value is a fixed string (`"https://api.openai.com/v1/chat/completions"`), not `Automatic`. Only used when `$useLLMServices` is `False` (i.e., when the `EnableLLMServices` setting resolves to `False` or the required `Wolfram/LLMFunctions` paclet is not installed). In this legacy path, `makeHTTPRequest` (`SendChat.wl`) reads the value from settings via `Lookup[settings, "OpenAIAPICompletionURL"]`, confirms it is a string, and uses it as the URL for the `HTTPRequest` sent to the OpenAI chat completions API, with the `"OpenAIKey"` setting providing the `"Authorization"` header. The entire `sendChat` overload that uses this setting is marked with a TODO comment: `"this definition is obsolete once LLMServices is widely available"`. When `$useLLMServices` is `True` (the primary/modern code path), this setting is completely unused — the LLMServices framework handles endpoint routing internally. Not included in `$llmConfigPassedKeys` (`SendChat.wl`), so it is NOT passed through `LLMConfiguration` when using the LLMServices framework. No model-specific overrides exist in `$modelAutoSettings`. No dependencies in `$autoSettingKeyDependencies`. Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations. Not listed in `$popOutSettings`. Conditionally exposed in the preferences UI (`PreferencesContent.wl`): the `makeOpenAICompletionURLInput` function returns `Nothing` when `$useLLMServices` is `True` (hiding the control entirely) and renders a string input field in the "Notebooks" tab via `highlightControl` when `$useLLMServices` is `False`, reading and writing `CurrentChatSettings[$preferencesScope, "OpenAIAPICompletionURL"]`. |

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
