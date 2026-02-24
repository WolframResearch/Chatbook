# Storage & Conversations Settings

## `"ConversationUUID"`

UUID identifying the current conversation, used as the primary key for persistent storage, search indexing, and chat history listings.

### Accepted Values

- **`None`** (default) — no conversation tracking
- **String (UUID)** — a valid UUID string generated via `CreateUUID[]`

### Behavior

When a conversation is saved (via `SaveChat`), `ensureConversationUUID` in `Storage.wl` checks whether the current setting is a valid string; if not, it generates a new UUID via `CreateUUID[]` and writes it back to the notebook or cell's `CurrentChatSettings`.

The UUID is used as the primary key in three subsystems:
1. **Persistent conversation storage** (`Storage.wl`)
2. **Chat search indexing** (`Search.wl`)
3. **Chat history listings** (`ChatModes/UI.wl`)

The `AutoSaveConversations` setting depends on `ConversationUUID` being a valid string (along with `AppName`).

### Chat Mode Overrides

- **Workspace chat and sidebar chat**: automatically generate a new UUID when starting a new conversation (`ChatModes/UI.wl`) or when initialized via NotebookAssistance settings (`ChatModes/ShowNotebookAssistance.wl`).
- **Inline chat**: does not set a UUID (falls back to `None`).

When loading a saved conversation, the stored UUID is restored to `CurrentChatSettings` for the target notebook or cell.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for conversation storage).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"AutoSaveConversations"`

Whether to automatically save conversations to persistent storage after chat evaluations.

### Accepted Values

- **`True`** — conversations are saved after each chat evaluation, subject to the `"MinimumResponsesToSave"` threshold
- **`False`** — auto-saving is disabled
- **`Automatic`** (default) — resolves to `True` if both `"AppName"` and `"ConversationUUID"` are valid strings; otherwise resolves to `False`

### Resolution

When `Automatic`, the resolved value depends on two other settings:
- `"AppName"` must be a valid string
- `"ConversationUUID"` must be a valid string

If both conditions are met, auto-saving is enabled; otherwise it is disabled.

### Behavior

When `True`, conversations are saved after each chat evaluation. The `autoSaveQ` function in `Storage.wl` gates this by also checking the `"MinimumResponsesToSave"` threshold — auto-saving only proceeds if the number of assistant responses meets or exceeds that minimum.

### Chat Mode Overrides

- **Workspace chat and sidebar chat**: set to `True` (with a new `ConversationUUID`).
- **Inline chat**: set to `False`.

### Integration Points

- **Dependencies**: Depends on `"AppName"` and `"ConversationUUID"` (declared in `$autoSettingKeyDependencies`).
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for conversation storage).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"AppName"`

Application name used to namespace saved conversations, search indexes, and chat history listings.

### Accepted Values

- **`Automatic`** (default) — resolves to `$defaultAppName` (`"Default"`)
- **String** — a custom application name (e.g., `"NotebookAssistance"`)

### Behavior

When set to a non-default string value, also establishes a service caller context via `setServiceCaller`.

The `AutoSaveConversations` setting depends on `AppName` being a valid string.

### Chat Mode Overrides

- **NotebookAssistance**: uses `"NotebookAssistance"` as the app name.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies` (but `"AutoSaveConversations"` depends on it).
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for conversation storage namespacing).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"MinimumResponsesToSave"`

Minimum number of assistant responses required before a conversation is automatically saved.

### Accepted Values

- **Positive integer** — the minimum response count threshold
- Default: `1` (auto-saving occurs as soon as the first assistant response is present)

The value must be a positive integer (`_Integer? Positive`); invalid values trigger a `"MinResponses"` confirmation failure.

### Behavior

Used by `autoSaveQ` in `Storage.wl` to gate auto-saving: after each chat evaluation, the function counts messages with `"Role" -> "Assistant"` in the conversation and only proceeds with saving if the count is greater than or equal to this value.

This setting only takes effect when `"AutoSaveConversations"` resolves to `True` (which itself requires valid `"AppName"` and `"ConversationUUID"` values).

### Chat Mode Overrides

- **`"GettingStarted"` alias** (`ShowNotebookAssistance.wl`): sets this to `2`, requiring at least two assistant responses before saving (preventing the initial getting-started prompt from being saved as a conversation).

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for conversation storage).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"TargetCloudObject"`

Target `CloudObject` location for deploying cloud-based chat notebooks via `CreateChatNotebook`.

### Accepted Values

- **`Automatic`** (default) — `CloudDeploy` is called without a target location, allowing the Wolfram Cloud to assign a default URL
- **`CloudObject[...]`** — the notebook is deployed to the specified cloud location

### Behavior

Used exclusively in the cloud notebook creation path (`createCloudChatNotebook` in `CreateChatNotebook.wl`): the value is read via `OptionValue[CreateChatNotebook, validOpts, "TargetCloudObject"]` and passed to `deployCloudNotebook`, which calls `CloudDeploy[nb, obj, CloudObjectURLType -> "Environment"]` if the value matches `$$cloudObject` (`HoldPattern[_CloudObject]`), or `CloudDeploy[nb, CloudObjectURLType -> "Environment"]` otherwise.

Cloud notebook creation is triggered when `$cloudNotebooks` is `True`.

### Special Properties

This is an **unsaved setting** (listed in `$unsavedSettings` in `CreateChatNotebook.wl`): it is used only at notebook creation time and is explicitly dropped from the notebook's `TaggingRules` by `makeChatNotebookSettings`, so it does not persist in the saved notebook.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.
