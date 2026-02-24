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
- The `$defaultConfigSettings` in `LLMUtilities.wl` sets this to `{"Notebooks", "NotebooksPreamble"}` for LLM configuration generation (not the regular chat notebook flow).

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

The formatted instructions are then appended to the assembled custom prompt (from the `"Prompts"` setting) within `assembleCustomPrompt` (`ChatMessages.wl`): if `"Prompts"` produced a string, the user instructions are appended with a `"\n\n"` separator; if `"Prompts"` produced `None`, the user instructions template is used alone. The combined result flows into `addPrompts` (`ChatMessages.wl`), where it is joined with workspace and inline chat context prompts via `StringRiffle` (with `"\n\n"` separators), then appended to the existing system message's `"Content"` (or used to create a new system message if none exists).

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

When non-empty, the prompt strings are assembled by `assembleCustomPrompt0` (`ChatMessages.wl`) and appended to the system message content via `addPrompts`. A single string is used directly; a list of strings is joined with `"\n\n"` separators via `StringRiffle`. After assembly, the custom prompt is combined with `"UserInstructions"` via `addUserInstructions`, then with workspace and inline chat context prompts, and the combined result is appended to the existing system message's `"Content"` (or creates a new system message if none exists).

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

Three built-in generators are registered in `$defaultPromptGenerators` (`DefaultPromptGenerators.wl`):

- **`"RelatedDocumentation"`** — searches documentation via vector databases, returning formatted markdown with citations; uses `RelatedDocumentation` from `RelatedDocumentation.wl`
- **`"RelatedWolframAlphaResults"`** — queries Wolfram Alpha for relevant results via `RelatedWolframAlphaResults` from `RelatedWolframAlphaResults.wl`
- **`"WebSearch"`** — performs web searches using the Tavily API, requiring a `TAVILY_API_KEY` system credential

Requires Wolfram Engine 14.1+ (`LLMPromptGenerator` support); on older versions, `toPromptGenerator` returns `Nothing` for all generators.

### Resolution

Resolution occurs in two stages:

1. **Settings resolution** (`resolveAutoSettings0` in `Settings.wl`, line 692): `resolvePromptGenerators` (`Common.wl`) reads the `"PromptGenerators"` list, conditionally appends `"RelatedWolframAlphaResults"` if `featureEnabledQ["RelatedWolframAlphaResults", settings]` is `True` (triggered by `"WolframAlphaCAGEnabled" -> True`), conditionally appends `"WebSearch"` if `featureEnabledQ["RelatedWebSearchResults", settings]` is `True` (triggered by `"WebSearchRAGMethod" -> "Tavily"`), then resolves each string name to an `LLMPromptGenerator` object via `resolvePromptGenerator` (which looks up the name in `$defaultPromptGenerators`; invalid names throw `"InvalidPromptGenerator"` failure). `ParentList` and `$$unspecified` entries are removed via `Nothing`. The resolved list is deduplicated and stored back as `{ ___LLMPromptGenerator }`.

2. **Message construction** (`augmentChatMessages` in `ChatMessages.wl`, line 276): `applyPromptGenerators` (`DefaultPromptGenerators.wl`) converts each generator to an `LLMPromptGenerator` via `toPromptGenerator`, creates generator data via `makePromptGeneratorData` (which extracts `"Input"` from the last message's content and `"Messages"` from the full message list), then applies each generator. Each invocation triggers `"PromptGeneratorStart"` and `"PromptGeneratorEnd"` handler function events. Generator results are processed by `formatGeneratedPrompt` and the non-empty results are wrapped as message Associations with `"Role"` set to `PromptGeneratorMessageRole`, `"Content"` set to the generated text, and `"Temporary" -> True`, inserted at the position specified by `PromptGeneratorMessagePosition`.

### ExperimentalFeatures Interaction

Interacts with `"ExperimentalFeatures"` bidirectionally: `ExperimentalFeatures` depends on `PromptGenerators` in `$autoSettingKeyDependencies` — `autoExperimentalFeatures` (`Settings.wl`) checks if `"RelatedWolframAlphaResults"` or `"WebSearch"` are in the PromptGenerators list and adds the corresponding experimental feature flags; conversely, setting `"WolframAlphaCAGEnabled" -> True` or `"WebSearchRAGMethod" -> "Tavily"` causes `resolvePromptGenerators` to auto-append the corresponding generator.

### Persona Overrides

- **AgentOne**: `{"RelatedDocumentation", "RelatedWolframAlphaResults"}`
- **AgentOneCoder**: `{"RelatedDocumentation"}`
- **CodeAssistant/CodeWriter/Wolfie/Birdnardo/NotebookAssistant**: `{"RelatedDocumentation", ParentList}`
- **WolframAlpha**: `{"RelatedWolframAlphaResults", ParentList}`
- **RawModel**: `{}` (no generators)
- **PlainChat**: does not set this (inherits default)

`ParentList` in persona values enables merging with the parent scope's generators via `mergeChatSettings`.

### Chat Mode Overrides

NotebookAssistance mode (`ShowNotebookAssistance.wl`) overrides to `{"RelatedDocumentation"}` in `$notebookAssistanceBaseSettings`.

### Integration Points

- **Dependencies**: None declared for PromptGenerators itself in `$autoSettingKeyDependencies` (but `ExperimentalFeatures` depends on it).
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for message augmentation).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- Not listed in `$modelInheritedLists` (but `ParentList` merging is handled generically by `mergeChatSettings0` for all list values).
- Not listed in `$popOutSettings`.

### Preferences UI

Not exposed in the preferences UI.

## `"PromptGeneratorsEnabled"`

**Not yet implemented.** Registered in `$defaultChatSettings` (`Settings.wl`) with a default value of `Automatic` and a `(* TODO *)` comment, but not referenced or used anywhere in the codebase. The intended purpose appears to be controlling which prompt generators are enabled, but the actual mechanism is currently handled by other settings: `"PromptGenerators"` directly specifies which generators to use, and `"ExperimentalFeatures"` can conditionally enable additional generators. Since this setting is not read by any code, changing its value has no effect.

## `"PromptGeneratorMessagePosition"`

Position in the message list where prompt generator messages are inserted.

### Default Value

The default is a fixed numeric value (`2`), not `Automatic`. When `Automatic`, resolves to `2` via `resolveAutoSetting0` (`Settings.wl`).

### Implementation

Used in `augmentChatMessages` (`ChatMessages.wl`): after chat messages are constructed and optionally merged (via `MergeMessages`), prompt generators produce additional context strings. These strings are wrapped as message Associations with `"Role"` set to the `PromptGeneratorMessageRole` value, `"Content"` set to the generated text, and `"Temporary" -> True` (marking them for exclusion in subsequent chat turns). The messages are then inserted via `Insert[merged, generatedMessages, genPos]`, where `genPos` is this setting's resolved value. A position of `2` places the generated messages after the first message in the list (typically the system prompt), ensuring they appear early in the context before user/assistant conversation history.

If the position is invalid (e.g., out of bounds for the message list), `throwFailure["InvalidPromptGeneratorPosition", genPos]` is called. The value can be any valid `Insert` position specification (positive or negative integer).

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

Used in `augmentChatMessages` (`ChatMessages.wl`): each generated prompt string is wrapped as a message Association with `"Role"` set to this setting's resolved value, `"Content"` set to the generated text, and `"Temporary" -> True`. The generated messages are then inserted into the merged message list at the position specified by `PromptGeneratorMessagePosition`.

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
