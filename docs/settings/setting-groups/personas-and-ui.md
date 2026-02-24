# Personas & UI Settings

## `"LLMEvaluator"`

The persona (LLM evaluator) to use. Determines the system prompt, available tools, and other settings.

### Accepted Values

- **String** — a persona name (e.g., `"CodeAssistant"`, `"PlainChat"`, `"RawModel"`)
- **`Association`** — a full persona specification with keys like `"Prompts"`, `"Tools"`, `"Icon"`, `"BasePrompt"`, etc.

Built-in personas are defined in `LLMConfiguration/Personas/`.

### Resolution

During `resolveAutoSettings` (`Settings.wl`), the string value is resolved via `getLLMEvaluator`, which calls `getNamedLLMEvaluator` to look up persona data from `GetCachedPersonaData`. If the name is not found as a built-in persona, `tryPromptRepositoryPersona` attempts to load it from the Wolfram Prompt Repository via `ResourceObject["Prompt" -> name]`.

The resolved persona `Association` is merged with the current settings via `mergeChatSettings`, with `$nonInheritedPersonaValues` keys (including `"LLMEvaluator"` itself) dropped from the persona data before merging, preventing circular inheritance. After resolution, the `"LLMEvaluator"` key in the settings is replaced with the full persona `Association` (or the original string/`None` if unresolvable).

When writing settings back to notebook `TaggingRules`, `toSmallSettings` in `SendChat.wl` converts the resolved `Association` back to just the persona name string (via the `"LLMEvaluatorName"` key) to save space.

### What the Persona Determines

- **System prompt**: via `"Prompts"`, `"Pre"`, `"PromptTemplate"`, and `"BasePrompt"` keys
- **Available tools**: the `"Tools"` setting depends on `"LLMEvaluator"` and `"ToolsEnabled"` in `$autoSettingKeyDependencies`; `selectTools` in `Tools/Common.wl` uses the persona name to look up per-persona tool selections
- **Output cell dingbat icon**: `makeOutputDingbat` and `makeActiveOutputDingbat` in `SendChat.wl` extract the persona's `"PersonaIcon"` or `"Icon"` key

### Special Behaviors

- When `"RawOutput"` is enabled during chat evaluation, the persona is overridden with `GetCachedPersonaData["RawModel"]` in `sendChat` (`SendChat.wl`).
- `CreateChatDrivenNotebook` defaults this to `"PlainChat"`.
- Each persona appears as a selectable menu item in the chat action menu (`UI.wl`) that writes to `{TaggingRules, "ChatNotebookSettings", "LLMEvaluator"}`, with a "Reset" option that sets the value to `Inherited`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies` (but `"Tools"` depends on it).
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service).
- **Persona inheritance**: Listed in `$nonInheritedPersonaValues`, so it retains its value from the notebook/cell scope rather than inheriting from persona configurations.

### Preferences UI

Exposed in the notebook preferences UI as a persona `PopupMenu` selector under the "Notebooks" section (`PreferencesContent.wl`).

## `"PersonaFavorites"`

List of persona name strings marked as favorites, controlling which personas appear at the top of the persona selector menu.

### Default Value

Not included in `$defaultChatSettings` — the setting is lazily initialized at `$FrontEnd` scope. When first accessed, if the value does not match `{___String}`, `filterPersonas` (`UI.wl`) initializes it to `{"CodeAssistant", "CodeWriter", "PlainChat"}`; `CreatePersonaManagerPanel` (`PersonaManager.wl`) similarly falls back to `$corePersonaNames` (`{"CodeAssistant", "CodeWriter", "PlainChat", "RawModel"}`).

Always read from and written to `$FrontEnd` scope (global persistent setting).

### Usage

1. **Persona selector menu ordering** (`filterPersonas` in `UI.wl`): favorites are placed first in their stored order via `KeyTake[personas, favorites]`, followed by the remaining visible personas in alphabetical order via `KeySort @ KeyTake[personas, Complement[Keys[personas], favorites]]`.

2. **Persona Manager dialog** (`CreatePersonaManagerPanel` in `PersonaManager.wl`): the `favorites` variable is initialized from this setting on panel creation, favorites are listed before non-favorites in the management grid with a visual divider, and the updated favorites list is saved back to `CurrentChatSettings[$FrontEnd, "PersonaFavorites"]` on panel deinitialization.

When the "Personas" preferences are reset (`resetChatPreferences["Personas"]` in `PreferencesContent.wl`), the value is set to `$corePersonaNames`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service).
- **Persona inheritance**: Listed in `$nonInheritedPersonaValues`, so it retains its value from notebook/cell scope rather than inheriting from persona configurations.
- Excluded from debug/diagnostic data (listed in `$droppedSettingsKeys` in `Common.wl`).

### Preferences UI

Exposed indirectly via the Persona Manager panel.

## `"VisiblePersonas"`

List of persona name strings controlling which personas appear in the persona selector UI.

### Default Value

`$corePersonaNames`, defined in `Personas.wl` as `{"CodeAssistant", "CodeWriter", "PlainChat", "RawModel"}`.

Always read from and written to `$FrontEnd` scope (global persistent setting).

### Behavior

Used primarily in `filterPersonas` (`UI.wl`): when building the persona selector menu, `KeyTake[personas, CurrentChatSettings[$FrontEnd, "VisiblePersonas"]]` filters the full persona data to only include personas in this list. The persona selector then orders visible personas by `PersonaFavorites` (favorites first, then remaining visible personas alphabetically).

### Lazy Initialization

In `filterPersonas` (`UI.wl`): if the value does not match `{___String}`, it is set to `DeleteCases[Keys[personas], Alternatives["Birdnardo", "RawModel", "Wolfie"]]`, excluding certain personas from the default visible set. `CreatePersonaManagerPanel` (`PersonaManager.wl`) sanitizes this setting on initialization by intersecting it with the keys of `$CachedPersonaData` to remove any stale persona names.

### Persona Manager Interaction

Each persona row in the Persona Manager dialog includes a checkbox (`addRemovePersonaListingCheckbox`) that toggles membership in this list: checking adds the persona name via `Union`, unchecking removes it via `Complement`. When a new persona is installed from the Prompt Repository (`ResourceInstaller.wl`), `addToVisiblePersonas` automatically appends the new persona name via `Union @ Append[...]`.

When the "Personas" preferences are reset (`resetChatPreferences["Personas"]` in `PreferencesContent.wl`), the value is reset to `$corePersonaNames`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`.
- Excluded from debug/diagnostic data (listed in `$droppedSettingsKeys` in `Common.wl`).
- Not listed in `$popOutSettings`.

### Preferences UI

Exposed via the Persona Manager panel checkboxes.

## `"ChatDrivenNotebook"`

**Deprecated.** Whether the entire notebook operates in "chat-driven" mode rather than the default "chat-enabled" mode.

### Behavior

When `True`:
- New cells default to `"ChatInput"` style.
- The persona selector prioritizes PlainChat/RawModel/CodeWriter/CodeAssistant at the top of the list (`UI.wl` `filterPersonas`).
- The cloud toolbar displays "Chat-Driven Notebook" instead of "Chat Notebook" (`CloudToolbar.wl`).

Used by `CreateChatDrivenNotebook[]`, which wraps `CreateChatNotebook` with `"ChatDrivenNotebook" -> True`, `"LLMEvaluator" -> "PlainChat"`, and `DefaultNewCellStyle -> "ChatInput"`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service).
- **Persona inheritance**: Listed in `$nonInheritedPersonaValues`, so it retains its value from notebook/cell scope rather than inheriting from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"InitialChatCell"`

Whether to create an initial empty chat input cell when opening a new chat notebook.

### Behavior

When `True` (default), `CreateChatNotebook` inserts an empty `"ChatInput"` cell (via `initialChatCells` in `CreateChatNotebook.wl`); for cloud notebooks (`$cloudNotebooks`), an additional selection-mover cell is appended to position the cursor. When `False`, the notebook is created with no initial cells. The value is evaluated via `TrueQ`, so only an explicit `True` creates the cell; `Automatic` or other non-boolean values behave as `False`.

### Special Properties

This is an **unsaved setting** (listed in `$unsavedSettings` in `CreateChatNotebook.wl`): it is used only at notebook creation time and is explicitly dropped from the notebook's `TaggingRules` by `makeChatNotebookSettings`, so it does not persist in the saved notebook.

When creating a notebook from a `ChatObject`, `initialChatCells` is locally overridden to return the converted message cells instead.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service).
- **Persona inheritance**: Listed in `$nonInheritedPersonaValues`, so it retains its value from notebook/cell scope rather than inheriting from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"ChatInputIndicator"`

Text prefix prepended to `"ChatInput"` cells when serializing notebook content for the LLM.

### Accepted Values

- **`Automatic`** (default) — resolves to `"\|01f4ac"` (speech balloon emoji)
- **String** — e.g., `"[USER]"`
- **`None` or `""`** — disables the indicator

### Behavior

The indicator is only applied when the content is mixed (i.e., when `mixedContentQ` returns `True` in `ChatMessages.wl`, indicating the conversation includes both chat input cells and other cell types). When the indicator is used, the `"ChatInputIndicator"` base prompt component (`Prompting.wl`) is automatically included in the system prompt to explain the indicator's meaning to the LLM: it tells the model that cells prefixed with this symbol are actual user messages, while other cells are context.

The indicator text is distinct from cell dingbats controlled by `"SetCellDingbat"`, which are visual notebook icons. The indicator symbol is set per chat evaluation via `chatIndicatorSymbol` in `SendChat.wl` and stored in the global `$chatIndicatorSymbol` variable (`Common.wl`).

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally for message serialization).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"SetCellDingbat"`

Whether to set cell dingbats (icons) on chat cells.

### Behavior

When `True` (default):
- Chat input cells receive dingbat icons (e.g., `"ChatInputCellDingbat"` / `"ChatInputActiveCellDingbat"` template boxes).
- Assistant output cells receive persona-based dingbat icons (via `makeActiveOutputDingbat` during streaming and `makeOutputDingbat` after completion in `SendChat.wl`).
- The input cell dingbat logic replaces `"ChatInputActiveCellDingbat"` with `"ChatInputCellDingbat"` once evaluation begins.
- For output cells, the active dingbat includes a `"ChatOutputStopButtonWrapper"` that provides a stop button during streaming; after completion, the dingbat is replaced with a static persona icon.
- For tabbed output (`"TabbedOutput"`), an `"AssistantIconTabbed"` wrapper is used instead.

When `False`, no `CellDingbat` option is set on generated cells.

Dingbats are never set in cloud notebooks regardless of this setting (`! TrueQ @ $cloudNotebooks` guard).

### Chat Mode Overrides

Overridden to `False` in:
- Workspace chat (`$workspaceDefaultSettings` in `StylesheetBuilder.wl` and `WorkspaceChat.nb` stylesheet)
- Notebook assistance workspace settings (`$notebookAssistanceWorkspaceSettings`)
- Sidebar chat settings (`$notebookAssistanceSidebarSettings`) in `ShowNotebookAssistance.wl`

### Notebook Conversion

Also used in `ConvertChatNotebook.wl`: `updateCellDingbats` applies `$evaluatedChatInputDingbat` to input cells and a persona-derived dingbat to output cells when converting messages to notebook format.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"EnableChatGroupSettings"`

Whether chat group-level settings are enabled, allowing parent group header cells to contribute prompts.

### Behavior

When `True`, during chat evaluation (`SendChat.wl`), `getChatGroupSettings` is called on the evaluation cell to retrieve prompt text from parent group header cells. The feature walks backward through notebook cells to find parent group headers using cell grouping rules (`"TitleGrouping"` and `"SectionGrouping"`) and collects `"Prompt"` values stored in their `TaggingRules` at the path `"ChatNotebookSettings"` -> `"ChatGroupSettings"` -> `"Prompt"`. Multiple prompts from different grouping levels are joined with `"\n\n"`.

The collected group prompt is stored in the settings as `"ChatGroupSettings"` and incorporated into the system prompt via `buildSystemPrompt` in `ChatMessages.wl`, where it appears as the `"Group"` section in the prompt template (between `"Pre"` and `"Base"` sections).

When `False` (default), no group settings are resolved and the `"Group"` section of the system prompt is omitted.

Implementation is in `ChatGroups.wl`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally for prompt construction).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"AllowSelectionContext"`

Whether to allow the current notebook selection to be used as additional context sent to the LLM.

### Resolution

When `Automatic` (default), resolves to `True` when using workspace chat, inline chat, or sidebar chat; `False` otherwise.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally for context construction).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"CurrentPreferencesTab"`

Persists the user's last-selected tab in the Chatbook preferences dialog.

### Behavior

When the preferences dialog opens, the tab is initialized from this setting (defaulting to `"Services"` if unset); when the dialog closes, the current tab selection is saved back. The `openPreferencesPage` function in `PreferencesContent.wl` also writes to this setting at `$FrontEnd` scope to navigate directly to a specific preferences page.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service).
- **Persona inheritance**: Listed in `$nonInheritedPersonaValues`, so it retains its value from notebook/cell scope rather than inheriting from persona configurations.
- Excluded from debug/diagnostic data (listed in `$droppedSettingsKeys` in `Common.wl`).
- Not included in `$defaultChatSettings`.

### Preferences UI

Not directly exposed; controls internal preferences dialog navigation.
