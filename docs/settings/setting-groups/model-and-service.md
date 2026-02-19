# Model and Service Settings

## `"Model"`

### Default Value

The default is defined via `RuleDelayed` (`:>`) in `$defaultChatSettings` (`Settings.wl`), so `$DefaultModel` is evaluated lazily each time the setting is accessed:

- **Wolfram Engine 14.1+**: `<|"Service" -> "LLMKit", "Name" -> Automatic|>`
- **Older versions**: `<|"Service" -> "OpenAI", "Name" -> "gpt-4o"|>`

### Accepted Formats

The value can be specified in three ways:

1. **Association** with `"Service"` and `"Name"` keys (canonical form)
2. **Plain string** — interpreted as an OpenAI model name by `serviceName` (`Models.wl`) and converted to `{"OpenAI", model}` by `makeLLMConfiguration` (`SendChat.wl`)
3. **`{service, name}` list** — converted to an Association by `resolveFullModelSpec`

### Resolution Pipeline

Model is resolved **first** in the topological sort order (`$autoSettingKeyPriority` explicitly prepends `"Model"`). During `resolveAutoSettings` (`Settings.wl`), the model is resolved via `resolveFullModelSpec` (`Models.wl`):

1. Already-resolved models (with `"ResolvedModel" -> True`) are returned unchanged.
2. `{service, name}` lists and plain strings are converted to Associations.
3. **LLMKit service** with unspecified name: substitutes the actual backing service and model from `$defaultLLMKitService`/`$defaultLLMKitModelName` and sets `"Authentication" -> "LLMKit"`.
4. **Other services** with `"Name" -> Automatic`: calls `chooseDefaultModelName` (`Models.wl`), which tries in order:
   - The `$DefaultModel` name if the service matches
   - The service's registered `"DefaultModel"` property
   - The first model from the cached model list
   - `Automatic` as fallback
   - If no string name can be resolved, queries `getServiceModelList` and throws `$Canceled` if not connected

### Model Standardization

The resolved model is passed through `standardizeModelData` (`Models.wl`), which enriches the Association with computed metadata:

`"BaseID"`, `"BaseName"`, `"Family"` (from `modelNameData`), `"Date"`, `"DisplayName"`, `"FineTuned"`, `"Icon"`, `"Multimodal"`, `"Name"` (normalized via `toModelName`), `"Snapshot"`, and `"ResolvedModel" -> True`.

The `toModelName` function normalizes model name strings (e.g., CamelCase to lowercase with hyphens, `"ChatGPT"` to `"gpt-3.5-turbo"`).

### Dependent Settings

Many settings depend on the resolved Model via `$autoSettingKeyDependencies`:

`"Authentication"`, `"ForceSynchronous"`, `"HybridToolMethod"`, `"MaxCellStringLength"`, `"MaxContextTokens"`, `"MaxTokens"`, `"Multimodal"`, `"TokenizerName"`, `"ToolCallExamplePromptStyle"`, `"ToolCallRetryMessage"`, `"ToolExamplePrompt"`, `"ToolsEnabled"`

The `$modelAutoSettings` table (`Settings.wl`) does not contain overrides for the Model setting itself — the resolved model's service and name/family are used as lookup keys to resolve other settings.

### Service Name Extraction

The service name is extracted from the model via `serviceName` (`Models.wl`), which checks for a `"Service"` key in the model Association. Plain strings default to `"OpenAI"`.

### Integration Points

- **LLM passthrough**: In `$llmConfigPassedKeys` (`SendChat.wl`), so it is passed through `LLMConfiguration` to the LLM service.
- **Notebook conversion**: Listed in `$popOutSettings` (`ConvertChatNotebook.wl`) as one of four settings shown during chat notebook conversion.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- **Programmatic access**: `SetModel` (`Models.wl`) accepts a string model name or Association and writes to the notebook's `TaggingRules`, optionally updating `` System`$LLMEvaluator `` via `LLMConfiguration`.

### Preferences UI

Exposed in `PreferencesContent.wl` in both the "Notebooks" tab and the "Services" tab via `makeModelSelector`, which provides a service selector popup menu and a model name selector popup menu (or text input). The UI reads and writes `CurrentChatSettings[$preferencesScope, "Model"]` as an Association. The `"ServiceDefaultModel"` setting remembers the last-selected model per service across service switches.

## `"Authentication"`

When `Automatic`, resolves based on the model specification: if the model has an explicit `"Authentication"` field, that value is used; if the model's `"Service"` is `"LLMKit"`, resolves to `"LLMKit"`; otherwise remains `Automatic` (uses the service's default authentication). Depends on `"Model"`. Passed directly to `LLMServices`Chat` and `LLMServices`ChatSubmit` (not via `LLMConfiguration`).

## `"EnableLLMServices"`

Controls whether Chatbook uses `LLMServices` for chat requests or falls back to direct API calls.

### Resolution

When `Automatic`, resolves to the internal `$useLLMServices` flag, which evaluates to `True` only if `$enableLLMServices` is `Automatic` or `True` AND the `Wolfram/LLMFunctions` paclet (version 1.2.2+) is installed (`Services.wl`).

### Behavior by Value

- **`True`**: Chat requests are routed through `LLMServices`Chat`/`LLMServices`ChatSubmit`, the OpenAI completion URL input is hidden from the preferences UI (`PreferencesContent.wl`), and available services are discovered dynamically.
- **`False`**: Chatbook falls back to direct API calls using legacy service configuration with `$fallBackServices`, and the OpenAI completion URL input is shown in the preferences UI.

### Implementation

The setting value is read from `CurrentChatSettings` and assigned to the `$enableLLMServices` variable in `Actions.wl` before each `sendChat` call. The `sendChat` function in `SendChat.wl` has a condition `/; $useLLMServices` that gates the primary chat execution path.

### Dependencies

Other settings depend on this:

- `HandlerFunctionsKeys` depends on `EnableLLMServices` for resolution order.
- `Multimodal` depends on both `EnableLLMServices` and `Model`. When LLM Services are disabled but the model supports multimodal, multimodal is enabled directly. When enabled, it additionally checks for multimodal paclet availability.

### Inheritance and Overrides

This is a non-inherited persona value (listed in `$nonInheritedPersonaValues` in `Settings.wl`), meaning it retains its value from the notebook/cell scope rather than inheriting from the persona. No model-specific overrides exist.

### Preferences UI

Not exposed directly in the preferences UI.

## `"Multimodal"`

Controls whether Chatbook includes image data in messages sent to the LLM.

### Resolution

When `Automatic`, resolved by `multimodalQ` (`Settings.wl`), which evaluates three factors:

1. Whether the model supports multimodal input (via `multimodalModelQ` in `Models.wl`)
2. Whether LLMServices is enabled (`EnableLLMServices`)
3. Whether required paclets are available

The resolution logic:

- If the model does not support multimodal, returns `False`.
- If the model supports multimodal and `EnableLLMServices` is `False`, returns `True` (the direct API path needs no extra paclets).
- If the model supports multimodal and `EnableLLMServices` is `True`, returns `multimodalPacletsAvailable[]`, which checks that `Wolfram/LLMFunctions` version 1.2.4+ and `ServiceConnection_OpenAI` version 13.3.18+ (with multimodal support) are installed.

### Model Detection

The `multimodalModelQ` function (`Models.wl`) determines model capability by:

- Checking for an explicit `"Multimodal"` key in the resolved model Association (set during `standardizeModelData`, which adds `"Multimodal" -> multimodalModelQ @ model` to every resolved model)
- Matching known model name patterns (Claude 3+, GPT-4o/GPT-4o-mini/ChatGPT-4o, GPT-4-turbo with date suffix)
- Detecting "vision" in the normalized model name

Model-specific overrides in `$modelAutoSettings`:

- **`True`**: Claude 4, Gemini 2, Gemini 3, GPT-4.1, GPT-5, O1, O3, O4-Mini
- **`False`**: O1-Mini, O3-Mini

### Dependencies

Depends on `"EnableLLMServices"` and `"Model"` (declared in `$autoSettingKeyDependencies`).

### Implementation

The resolved value is stored in the `$multimodalMessages` global variable (`CommonSymbols.wl`) at three points in `SendChat.wl` (lines 90, 176, 298) and in `makeChatMessages` (`ChatMessages.wl`), and is preserved across handler evaluation via `ChatState.wl`.

When `True`, `makeMessageContent` (`ChatMessages.wl`) processes cell content through `expandMultimodalString`, which:

1. Splits strings on expression URI patterns
2. Calls `inferMultimodalTypes` to classify content as `"Text"` or `"Image"`
3. Produces multimodal message content (with image data)

**Image constraints:**

- `allowedMultimodalRoles` (`ChatMessages.wl`) restricts multimodal content to `"User"` role messages for GPT-4o models and allows `All` roles for other models.
- Images are resized via `resizeMultimodalImage` (`ChatMessages.wl`) to fit within `$maxMMImageSize` dimensions before encoding.

**Serialization:** In `Serialization.wl`, the related `$multimodalImages` variable (derived from `$contentTypes`) controls whether graphics boxes are encoded as image URIs (`toMarkdownImageBox`) or replaced with `"[GRAPHIC]"` placeholders, and whether `"Picture"` style cells are serialized as image URIs. Graphics exceeding `$maxBoxSizeForImages` bytes fall back to non-multimodal serialization.

### Chat Mode Overrides

- **ContentSuggestions** mode sets its own `$wlSuggestionsMultimodal`, `$textSuggestionsMultimodal`, and `$notebookSuggestionsMultimodal` flags (all `False`).
- **ChatTitle** (`ChatTitle.wl`) uses `$multimodalTitleContext = False` for title generation.

### Integration Points

- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for message content processing).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Exposed in `PreferencesContent.wl` under the "Features" section as a PopupMenu with three options: `Automatic` ("Enabled by Model"), `True` ("Enabled Always"), and `False` ("Enabled Never"), reading and writing `CurrentChatSettings[$preferencesScope, "Multimodal"]`.
