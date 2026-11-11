# Prompting Settings

## `"BasePrompt"`

Specifies which base prompt components to include in the system prompt.

### Accepted Values

- **`Automatic`** — inherited from persona/model settings
- **`None`** — disables all base prompting (used by the RawModel persona)
- **Single string** — a component name
- **List of names** — can include `ParentList` to inherit from the parent scope while adding additional components (e.g., `{ParentList, "Notebooks", "WolframLanguageStyle"}`)

### Available Components

Components are defined in `Prompting.wl` via `$basePromptComponents` and `$basePromptOrder`:

- **Individual components**: `"Markdown"`, `"CodeBlocks"`, `"MathExpressions"`, `"EscapedCharacters"`, `"WolframLanguageStyle"`, `"EndTurnToken"`, etc.
- **Class names** (expand to groups): `"Notebooks"`, `"WolframLanguage"`, `"Math"`, `"Formatting"`, `"All"`

Dependencies between components are automatically resolved via `$basePromptDependencies`.

### Inheritance

Part of `$modelInheritedLists`, which enables special list-merging behavior with `ParentList`. Interacts with `ExcludedBasePrompts`, which removes specified components from the resolved list.

### Persona Overrides

Personas typically set this to include `ParentList` plus persona-specific components (e.g., CodeAssistant uses `{ParentList, "Notebooks", "WolframLanguageStyle"}`).

## `"ExcludedBasePrompts"`

List of base prompt component names to exclude from the system prompt.

### Resolution

When `Automatic`, resolves to `{ParentList}` via the global model auto default, meaning it inherits exclusions from the parent model settings. Can be a list containing strings (component names or class names) and/or `ParentList` for inheritance. Valid values must match `{ (_String|ParentList)... }`; invalid values trigger an `"InvalidExcludedBasePrompts"` failure.

### Implementation

Applied after the `"BasePrompt"` list is resolved: in `augmentChatMessages` (`ChatMessages.wl`), the resolved `BasePrompt` list is filtered via `DeleteCases` to remove any components matching the exclusion list. Additionally, the excluded components are removed from the collected prompt components via `removeBasePrompt` in `Prompting.wl`, which drops matching keys from `$collectedPromptComponents` and strips the corresponding text from the system message content. The resolved value (with `ParentList` entries removed) is stored in the `$excludedBasePrompts` global variable (`Settings.wl`), which is also checked by `needsBasePrompt` (`Prompting.wl`) to prevent excluded components from being collected during prompt construction.

### Inheritance

Part of `$modelInheritedLists` (along with `"BasePrompt"`), which enables special list-merging behavior in `inheritModelSettings`: when the value contains `ParentList`, it is merged with the model-specific default via `mergeChatSettings`, allowing syntax like `{ParentList, "EscapedCharacters"}` to mean "inherit parent exclusions and also exclude EscapedCharacters."

### Model-Specific Overrides

- **GPT-5.2**: `{ParentList, "EscapedCharacters"}` (because it has improved Unicode handling)
- The `$defaultConfigSettings` in `LLMUtilities.wl` sets this to `{"Notebooks", "NotebooksPreamble", "CodeFolding"}` for LLM configuration generation (not the regular chat notebook flow).

### Automatic Exclusions

`"CodeFolding"` (the instructions for folding code with `IconizedObject`, a dependency of `"WolframLanguageStyle"`) is added to `$excludedBasePrompts` in `resolveAutoSettings` when the response is not formatted in a notebook: for headless chats such as `AgentEvaluate`, and when `"AutoFormat"` is `False`. Folded code relies on the notebook formatting to be displayed as an icon and to be evaluated like the code inside.

### Integration Points

- **Dependencies**: No explicit dependencies in `$autoSettingKeyDependencies`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"ChatContextPreprompt"`

**Deprecated.** Legacy preprompt text used as the "Pre" section of the system prompt sent to the LLM. Superseded by persona-based prompting via `"LLMEvaluator"` and the `"BasePrompt"` component system.

### Resolution

Resolved via `getPrePrompt` in `ChatMessages.wl`, which checks the following in priority order: persona-level `"ChatContextPreprompt"`, persona-level `"Pre"` / `"PromptTemplate"` / `"Prompts"`, then global `"ChatContextPreprompt"`, then global `"Pre"` / `"PromptTemplate"` / `"Prompts"`. The value must be a `String`, `TemplateObject`, or list thereof. Automatic value resolution is not implemented (noted as TODO in `Settings.wl`).

### Preferences UI

Exposed in the chat context settings dialog (`Actions.wl`) as a text input field with a default of `"You are a helpful Wolfram Language programming assistant. Your job is to offer Wolfram Language code suggestions based on previous inputs and offer code suggestions to fix errors."`.

## `"UserInstructions"`

User-provided instructions to include in the system prompt.

### Accepted Values

The value must be a `String` or `None`. When `Automatic`, it resolves to `$$unspecified` (treated identically to `None`, i.e., no instructions are added). There is no explicit `resolveAutoSetting0` rule for this setting.

### Implementation

When the resolved value is a non-empty string, it is formatted by `addUserInstructions` (`ChatMessages.wl`) using `$customInstructionsTemplate`, which wraps the text in a structured template: a `"# User Instructions"` heading, a precedence directive (`"IMPORTANT: The following user instructions take precedence over ALL other instructions."`), and XML-style `<user-instructions>` tags around the user's text.

The formatted instructions are then appended to the assembled custom prompt (from the `"Prompts"` setting) within `assembleCustomPrompt` (`ChatMessages.wl`): if `"Prompts"` produced a string, the user instructions are appended with a `"\n\n"` separator; if `"Prompts"` produced `None`, the user instructions template is used alone. The combined result flows into `addPrompts` (`ChatMessages.wl`), where it is joined with workspace and sidebar chat context prompts via `StringRiffle` (with `"\n\n"` separators), wrapped in `<added-prompts>` tags, and appended to the existing system message's `"Content"` (or used to create a new system message if none exists). If the system message already has an `<added-prompts>` section (for example, when messages are rebuilt for a tool response), that section is replaced rather than appended to, so the prompts appear once per request. The tags are retained in internal message data so the tool-call loop can find the section, then removed centrally by `prepareMessagesForLLM` before role rewriting and submission. The tags are still present when the `"ChatMessages"` processing function and prompt generators run, so a custom processing function that rewrites the system message should keep the `<added-prompts>` section intact.

### Persona Overrides

The RawModel persona explicitly sets `"UserInstructions" -> None` (`LLMConfiguration/Personas/RawModel/LLMConfiguration.wl`), which suppresses user instructions even if set globally in preferences. No other built-in persona sets this value.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed directly to the LLM service; used internally by Chatbook for system prompt construction).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- Not in `$usableChatSettingsKeys` (not settable via the ChatPreferences LLM tool).
- Not in `$modelInheritedLists`, `$popOutSettings`.

### Preferences UI

Exposed in the preferences UI (`PreferencesContent.wl`) via `makeInstructionsContent` as a multi-line text input field under the "Instructions" subsection, with the description "Instructions specified here will be applied to all conversations with Notebook Assistant and other chats" and a hint placeholder (e.g., "Before making any tool calls, briefly explain what you are doing and why."). The save action writes the value via `CurrentChatSettings[$preferencesScope, "UserInstructions"]`; if the text is empty or not a string, it is set to `Inherited`. Localization strings for the preferences UI exist in all supported languages (`FrontEnd/TextResources/`).

## `"Prompts"`

A list of custom prompt strings to append to the system prompt.

### Accepted Values

A single string, a list of strings, or a list containing `TemplateObject` elements (resolved via `applyPromptTemplate`). Each result is validated by `checkPromptComponent` (which accepts strings or lists of strings, and throws `"InvalidPromptComponent"` for anything else).

### Implementation

When non-empty, the prompt strings are assembled by `assembleCustomPrompt0` (`ChatMessages.wl`) and appended to the system message content via `addPrompts`. A single string is used directly; a list of strings is joined with `"\n\n"` separators via `StringRiffle`. After assembly, the custom prompt is combined with `"UserInstructions"` via `addUserInstructions`, then with workspace and sidebar chat context prompts, and the combined result is added to the system message by `addPrompts`, replacing any earlier `<added-prompts>` section (see `"UserInstructions"` above).

Additionally, `"Prompts"` appears in the `getPrePrompt` fallback chain (`ChatMessages.wl`), which constructs the `"Pre"` section of the system prompt template used by `buildSystemPrompt`. The fallback priority is: persona-level `"ChatContextPreprompt"` > persona `"Pre"` > persona `"PromptTemplate"` > persona `"Prompts"` > settings-level `"ChatContextPreprompt"` > settings `"Pre"` > settings `"PromptTemplate"` > settings `"Prompts"`. Values in this chain must match `_String | _TemplateObject | { (_String|_TemplateObject)... }`.

In `tryPromptRepositoryPersona` (`Settings.wl`), when loading personas from the Wolfram Prompt Repository, the `"Prompts"` field from the `LLMConfiguration` data is extracted and normalized: if it matches `_List | _String | _TemplateObject | _LLMPromptGenerator`, it is wrapped with `Flatten @ { prompts }` to ensure a flat list. There is a TODO comment in `Settings.wl` (line 1925) noting that special merging/inheritance logic for `"Prompts"` is planned but not yet implemented; currently, standard association merging rules apply via `mergeChatSettings0`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed directly to the LLM service; used internally by Chatbook for system prompt construction).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations. No built-in personas set this value.
- Not in `$modelInheritedLists`, `$popOutSettings`.

### Preferences UI

Exposed in the ChatPreferences tool (`ChatPreferences.wl`) as a settable key with type `[string]` (list of strings), described as "A list of instructions to append to the system prompt," and validated via `Interpreter[RepeatingElement["String"]]`. Listed in `$usableChatSettingsKeys`.

## `"PromptGenerators"`

List of prompt generators used to augment the conversation with additional context (e.g., related documentation, Wolfram Alpha results, web search results) before sending messages to the LLM.

### Accepted Values

When `Automatic`, resolves to `{}` (no generators) via `resolveAutoSetting0` (`Settings.wl`). The value can be a list containing: string names of built-in generators, `LLMPromptGenerator` objects directly, or `ParentList` for inheriting from the parent scope.

### Built-in Generators

Four built-in generators are registered in `$defaultPromptGenerators` (`DefaultPromptGenerators.wl`):

- **`"RelatedDocumentation"`** — searches documentation via vector databases and inserts the relevant snippets; uses `RelatedDocumentation[messages, "Prompt", ...]` from `RelatedDocumentation.wl`. In workspace, sidebar and LLMKit chats, a small LLM picks up to 10 of about 50 search results; otherwise the top 5 results are used without filtering.
- **`"RelatedDocumentationList"`** — the same search, but inserts only a catalog: one `<URI> - <short description>` line per result (`RelatedDocumentation[messages, "CatalogPrompt", MaxItems -> 50]`), with instructions to retrieve the snippets that help with the `"DocumentationLookup"` tool, all in one call. There is no LLM filter. Resource URIs are shortened in the catalog (e.g. `resource:function/FITImport#334957977`), and results without a description (from the `"Descriptions"` snippet store) are left out. When the `"DocumentationLookup"` tool is not selected (e.g. tools are disabled, or the persona doesn't have it), it does exactly what `"RelatedDocumentation"` does. The catalog's full URIs are in the handler data as `"RelatedDocumentationCatalog" -> <|"Results" -> uris|>`.
- **`"RelatedWolframAlphaResults"`** — queries Wolfram Alpha for relevant results via `RelatedWolframAlphaResults` from `RelatedWolframAlphaResults.wl`
- **`"WebSearch"`** — performs web searches using the Tavily API, requiring a `TAVILY_API_KEY` system credential

### Resolution

Resolution occurs in two stages:

1. **Settings resolution** (`resolveAutoSettings0` in `Settings.wl`, line 692): `resolvePromptGenerators` (`Common.wl`) reads the `"PromptGenerators"` list, conditionally appends `"RelatedWolframAlphaResults"` if `featureEnabledQ["RelatedWolframAlphaResults", settings]` is `True` (triggered by `"WolframAlphaCAGEnabled" -> True`), conditionally appends `"WebSearch"` if `featureEnabledQ["RelatedWebSearchResults", settings]` is `True` (triggered by `"WebSearchRAGMethod" -> "Tavily"`), then resolves each string name to an `LLMPromptGenerator` object via `resolvePromptGenerator` (which looks up the name in `$defaultPromptGenerators`; invalid names throw `"InvalidPromptGenerator"` failure). `ParentList` and `$$unspecified` entries are removed via `Nothing`. The resolved list is deduplicated and stored back as `{ ___LLMPromptGenerator }`.

2. **Message construction** (`augmentChatMessages` in `ChatMessages.wl`, line 276): `applyPromptGenerators` (`DefaultPromptGenerators.wl`) converts each generator to an `LLMPromptGenerator` via `toPromptGenerator`, creates generator data via `makePromptGeneratorData` (which extracts `"Input"` from the last message's content and `"Messages"` from the full message list), then applies each generator. Each invocation triggers `"PromptGeneratorStart"` and `"PromptGeneratorEnd"` handler function events. Generator results are processed by `formatGeneratedPrompt` and the non-empty results are wrapped as message Associations with `"Role"` set to `PromptGeneratorMessageRole`, `"Content"` set to the generated text, `"Temporary" -> True` and `"PromptGenerated" -> True`, inserted at the position specified by `PromptGeneratorMessagePosition`.

Generators run once per chat request, not again for the requests that follow tool calls: `toolEvaluation` (`SendChat.wl`) passes the messages of the first request back to `constructMessages` (`ChatMessages.wl`), which reuses the messages marked `"PromptGenerated" -> True` instead of calling `applyPromptGenerators` again. If the first request had no generated prompts, the generators run again after a tool call.

### ExperimentalFeatures Interaction

Interacts with `"ExperimentalFeatures"` bidirectionally: `ExperimentalFeatures` depends on `PromptGenerators` in `$autoSettingKeyDependencies` — `autoExperimentalFeatures` (`Settings.wl`) checks if `"RelatedWolframAlphaResults"` or `"WebSearch"` are in the PromptGenerators list and adds the corresponding experimental feature flags; conversely, setting `"WolframAlphaCAGEnabled" -> True` or `"WebSearchRAGMethod" -> "Tavily"` causes `resolvePromptGenerators` to auto-append the corresponding generator.

### Persona Overrides

- **AgentOne**: `{"RelatedDocumentationList", "RelatedWolframAlphaResults"}`
- **AgentOneCoder**: `{"RelatedDocumentationList"}`
- **CodeAssistant/CodeWriter/Wolfie/Birdnardo/NotebookAssistant/WolframAIAssistant**: `{"RelatedDocumentationList", ParentList}`
- **WolframAlpha**: `{"RelatedWolframAlphaResults", ParentList}`
- **RawModel**: `{}` (no generators)
- **PlainChat**: does not set this (inherits default)

`ParentList` in persona values enables merging with the parent scope's generators via `mergeChatSettings`.

The personas with tools also list the `"DocumentationLookup"` tool, so they get the catalog of `"RelatedDocumentationList"`. CodeWriter has no tools, so its generator gives full snippets. Custom personas that name `"RelatedDocumentation"` keep getting full snippets.

### Chat Mode Overrides

NotebookAssistance mode (`ShowNotebookAssistance.wl`) overrides to `{"RelatedDocumentationList"}` in `$notebookAssistanceBaseSettings`. Its persona (WolframAIAssistant) merges its own list with this one through `ParentList`, so both must name the same documentation generator, or both generators run.

### Integration Points

- **Dependencies**: None declared for PromptGenerators itself in `$autoSettingKeyDependencies` (but `ExperimentalFeatures` depends on it).
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for message augmentation).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- Not listed in `$modelInheritedLists` (but `ParentList` merging is handled generically by `mergeChatSettings0` for all list values).
- Not listed in `$popOutSettings`.

### Preferences UI

Not exposed in the preferences UI.

## `"PromptCacheOptimization"`

Controls whether requests are built so that LLM providers can reuse cached prompt prefixes. Providers such as OpenAI cache the longest prefix of a request that matches an earlier request, which reduces latency and cost, but any change to an earlier message invalidates the cache from that point on.

### Accepted Values

- **`Automatic`** (default) — resolves via `$modelAutoSettings` (`Settings.wl`): `True` by default, `False` for the Anthropic service (LLMConnections moves every system message into the top-level system prompt, so turn messages would collect there), for the MistralAI service (its API rejects requests that end with a system message) and for models that need user role tool responses (DeepSeek reasoner and Flash, Qwen, Nemotron, Mistral), since turn messages are system messages after the user's message
- **`True`** — use the prompt-cache-friendly behavior described below
- **`False`** — legacy behavior

### Behavior

When `True`, messages that are added to a chat turn without being part of its cells are appended after the user's message and kept for later requests instead of being regenerated:

- **Prompt generator results** are appended after the user message instead of being inserted at `"PromptGeneratorMessagePosition"`, and requests that follow a tool call send them unchanged. Prompt generators run once per turn, even if they give no results.
- **Turn records**: these messages are stored in an in-memory record (`PromptCache.wl`), and the chat output cell of the turn gets a small `"PromptCacheID"` tagging rule that refers to the record. When the cell appears in the history of a later request, the record's messages are inserted before the cell's message, so they are sent the same way in every later request (if they no longer fit in the token budget, they are left out). Records are not saved with the notebook: after restarting the kernel, history is rebuilt from cells only, and the next request misses the cache once. The number of records kept in memory is bounded (`$maxPromptCacheRecords`), and is shared by all conversations.

- **System prompt**: only includes the base prompt components that are determined by the settings (persona and settings `"BasePrompt"`, the tools, `"AutoFormat"`, etc.; see `withStaticBasePrompts` in `Prompting.wl`), so it is the same for every request of a conversation, and for other conversations with the same settings.
- **Base prompt hints**: components that become needed because of the content of the conversation (e.g. `"MarkdownImageBox"` when the notebook context contains images, or `"SpecialURIAudio"` after a tool returns audio) are sent once per conversation in a `<system-hint>` turn message instead. Components that are only meant for one response (`"AutoAssistant"` and the notebook assistance instructions, `$perTurnBasePrompts` in `PromptCache.wl`) are sent in each turn that needs them, worded as instructions for that response. Hints that are needed after a tool call are added to the turn messages of the current turn, before the response; this misses the cache once for the earlier tool calls of that turn. Tool calls made for automatic assistance don't get base prompt hints, since they don't run in a chat state (they do get the "disable" hints below).
- **Disabled instructions**: instructions that are removed from the system prompt after a tool call in legacy mode (`"AutoAssistant"` and the `"ToolCallFrequency"` preference) are disabled with a hint for the rest of the response instead.
- **Tool call retry**: when `"ToolCallRetryMessage"` is `True`, its instructions are a base prompt component (`"ToolCallRetry"`) instead of a temporary message after each tool response. Like the other base prompt components, they are left out with `"BasePrompt" -> None`.
- **History length limits**: older messages in the chat history are shortened to `"MaxCellStringLength"` instead of a limit that shrinks as the conversation grows (token pressure), so they are sent the same way in every request. A history message that doesn't fit in the token budget is left out with all older ones instead of being shortened, and so is a turn message that doesn't fit. The left-out cells are rounded up to blocks counted from the start of the conversation (`blockTrimmedHistory` in `ChatMessages.wl`; one cell for each `2^13` tokens of `"MaxContextTokens"`, but at least 8), so the oldest message that is sent, and the number of excised cells, stay the same for several requests instead of changing with every new message. This only applies to chat history: cells that are serialized for something else (the notebook context, `NotebookReader` pages, content suggestions) are shortened as before.
- **Notebook context** (sidebar and workspace chats with `"AllowSelectionContext"`): the content of the user's notebook is sent once per conversation, as a turn message of the first input, instead of being added to the system prompt of every request. Images from the notebook context are sent in a separate user message after it. Later inputs get a short `<system-hint>` notice when the user switched notebooks, moved their selection, or the notebook changed since the last notebook context or notice in the conversation, based on a cheap fingerprint (selected cells and the front end's content hash, which also changes with some notebook options, such as the window size or position, the magnification, opened or closed cell groups, and tagging rules; see `notebookContextTurnMessages` in `ChatModes/Context.wl`). With the `NotebookReader` tool, the AI can read the current content when the user's message refers to the notebook. Without it, the full context is sent again instead of the notice. Turning `"AllowSelectionContext"` off leaves the notebook content that was sent out of later requests (this misses the cache once). Other notebook content that was sent, e.g. cells that were excluded later or a notebook the user switched away from, stays in the conversation; starting a new chat clears it. In the sidebar, `"AllowSelectionContext"` is `False` until the user turns notebook content on.

The messages in turn records are still marked as `"Temporary"`, so they are not displayed, saved with conversations, or used for chat titles and search context. The chat data written to an output cell (`"ChatData"`) only includes the turn messages of its own turn, since earlier turns' are in their records.

When `False`, prompt generator results are inserted at `"PromptGeneratorMessagePosition"` for each request and regenerated for each turn, the system prompt includes every base prompt component that is needed for the current request, and the notebook context of sidebar and workspace chats is added to the system prompt for every request.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: Global default `True` in `$modelAutoSettings[Automatic, Automatic]`; `False` for the Anthropic and MistralAI services and the models listed above.
- **LLM passthrough**: Not in `$llmConfigPassedKeys`.

## `"PromptGeneratorsEnabled"`

**Not yet implemented.** Registered in `$defaultChatSettings` (`Settings.wl`) with a default value of `Automatic` and a `(* TODO *)` comment, but not referenced or used anywhere in the codebase. The intended purpose appears to be controlling which prompt generators are enabled, but the actual mechanism is currently handled by other settings: `"PromptGenerators"` directly specifies which generators to use, and `"ExperimentalFeatures"` can conditionally enable additional generators. Since this setting is not read by any code, changing its value has no effect.

## `"PromptGeneratorMessagePosition"`

Position in the message list where prompt generator messages are inserted.

### Default Value

The default is a fixed numeric value (`2`), not `Automatic`. When `Automatic`, resolves to `2` via `resolveAutoSetting0` (`Settings.wl`).

### Implementation

Used in `augmentChatMessages` (`ChatMessages.wl`): after chat messages are constructed and optionally merged (via `MergeMessages`), prompt generators produce additional context strings. These strings are wrapped as message Associations with `"Role"` set to the `PromptGeneratorMessageRole` value, `"Content"` set to the generated text, `"Temporary" -> True` (marking them for exclusion in subsequent chat turns), and `"PromptGenerated" -> True` (so that the requests after tool calls in the same turn reuse them). The messages are then inserted via `Insert[merged, generatedMessages, genPos]`, where `genPos` is this setting's resolved value. A position of `2` places the generated messages after the first message in the list (typically the system prompt), ensuring they appear early in the context before user/assistant conversation history.

If the position is invalid (e.g., out of bounds for the message list), `throwFailure["InvalidPromptGeneratorPosition", genPos]` is called. The value can be any valid `Insert` position specification (positive or negative integer).

This setting is ignored when `"PromptCacheOptimization"` is `True`: generated messages are then appended after the user message (see [`"PromptCacheOptimization"`](#promptcacheoptimization)).

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for message list construction).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI or the ChatPreferences tool.

## `"PromptGeneratorMessageRole"`

Message role assigned to prompt generator messages when they are inserted into the conversation.

### Default Value

The default is a fixed string value (`"System"`), not `Automatic`. When `Automatic`, resolves to `"System"` via `resolveAutoSetting0` (`Settings.wl`).

### Accepted Values

Validated immediately after being read from settings: `"System"`, `"Assistant"`, or `"User"`. Invalid values trigger an `"InvalidPromptGeneratorRole"` failure.

The three valid values determine how the LLM interprets the generated context: `"System"` (default) frames the context as system-level instructions, `"User"` frames it as user-provided input, and `"Assistant"` frames it as prior assistant output.

### Implementation

Used in `augmentChatMessages` (`ChatMessages.wl`): each generated prompt string is wrapped as a message Association with `"Role"` set to this setting's resolved value, `"Content"` set to the generated text, `"Temporary" -> True` and `"PromptGenerated" -> True`. The generated messages are then inserted into the merged message list at the position specified by `PromptGeneratorMessagePosition`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for message list construction).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI or the ChatPreferences tool.

## `"DiscourageExtraToolCalls"`

Whether to include a base prompt component discouraging unnecessary tool calls.

### Implementation

When enabled, adds the `"DiscourageExtraToolCalls"` base prompt component to the system prompt, which appends the text: `"Don't make more tool calls than is needed. Tool calls cost tokens, so be efficient!"`. The setting is evaluated via `discourageExtraToolCallsQ` in `ChatMessages.wl`, which returns `False` if `ToolsEnabled` is `False` or `Tools` is empty (i.e., the prompt is only included when tools are actually available). Has no dependencies on other base prompt components.

### Model-Specific Overrides

Currently only enabled (`True`) for Anthropic Claude 3.7 Sonnet via `$modelAutoSettings`. No global auto default exists, so `Automatic` effectively resolves to `False` for all other models.

### Preferences UI

Not exposed in the preferences UI.
