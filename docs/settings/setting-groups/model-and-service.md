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

The `$modelAutoSettings` table (`Settings.wl`) does not contain overrides for the Model setting itself — the resolved model's service and name/family are used as lookup keys to resolve other settings. For a guide on adding entries to this table for new models, see [Adding Model Support](../../adding-model-support.md).

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

## `"Endpoint"`

Selects which API endpoint chat requests use: OpenAI's Responses endpoint or the legacy chat completions endpoint.

### Default Value

`Automatic`.

### Behavior by Value

- **`Automatic`**: the Responses endpoint is used only when the service supports it *and* the model's family opts in; otherwise chat completions. See Resolution below.
- **`"Responses"`**: forces the Responses endpoint. This skips the model-family opt-in but not the support checks, so a service or an installed `Wolfram/LLMFunctions` that cannot provide the endpoint still falls back to chat completions.
- **`"ChatCompletions"`**: always uses the legacy endpoint. This is the rollback switch.

Any unrecognized value behaves as `"ChatCompletions"`. The value is not validated: the pattern `$$endpointSetting` in `Settings.wl` describes the three accepted values but nothing currently checks the setting against it.

### Resolution

`responsesEndpointQ` (`SendChat.wl`) makes the decision, and `resolveChatEndpoint` maps it onto a pair of endpoint symbols:

| Decision | Synchronous | Streaming |
| -------- | ----------- | --------- |
| Responses | `LLMServices`Response` | `LLMServices`ResponseSubmit` |
| Chat completions | `LLMServices`Chat` | `LLMServices`ChatSubmit` |

Under `Automatic`, a request goes to the Responses endpoint only when **all** of the following hold. Any failure falls back to chat completions silently; none of them is an error condition:

1. **The installed LLMFunctions provides the endpoint.** `$responsesEndpointAvailable` (`Settings.wl`) requires `Wolfram/LLMFunctions` version `2.4` or newer *and* separately checks that `Response` and `ResponseSubmit` appear in `LLMServices`$LLMServicesEndpoints`. Both checks are needed because version `2.3.2` exists both with and without the endpoint, which makes the version alone ambiguous.
2. **The endpoint is registered for the model's service.** `LLMServices`RegisteredServiceQ` must report it for both `Response` and `ResponseSubmit` (`responsesServiceQ` in `SendChat.wl`).
3. **The model family opts in.** `$responsesEndpointFamilies` (`SendChat.wl`) currently holds `<| "OpenAI" -> { "GPT54Plus" } |>`, which covers every `GPT 5.<digit>` model.

A model specification that has not been resolved to a full spec carrying both `"Service"` and `"Family"` also falls back.

The decision is made once per request and drives both the synchronous and the streaming path, so a single chat never mixes endpoints.

### Parameter Consequences

The two endpoints accept different parameter sets, so the resolved endpoint changes what is sent. `"Reasoning"` is the current case: on the Responses path it goes out as an association carrying the effort level and a summary request, such as `<| "effort" -> "medium", "summary" -> "auto" |>`, and on the completions path as a plain effort string. The completions path does not accept the association form.

Because that association form only ever appears on the Responses path, it doubles as a check of which endpoint a chat actually used. After a chat, in the same kernel:

```wl
Wolfram`Chatbook`SendChat`Private`$lastLLMConfiguration["Reasoning"]
```

An association means the Responses endpoint; a plain string means chat completions. A Responses result association also carries `"ResponseID"` and `"PreviousResponseID"`, which a completions result does not.

### Rollback

Setting `"ChatCompletions"` restores the previous behavior without a code change, and can be scoped per chat, per notebook, or globally.

One caveat applies to GPT-5.4 and newer. Those models request reasoning by default, and OpenAI rejects reasoning together with function tools on the completions endpoint. Rolling such a chat back to `"ChatCompletions"` while tools are enabled therefore fails with a service error rather than degrading quietly:

```
Function tools with reasoning_effort are not supported for gpt-5.6 in /v1/chat/completions.
To use function tools, use /v1/responses or set reasoning_effort to 'none'.
```

To roll one of those models back, also set `"Reasoning"` to `"None"`, or disable tools.

### Integration Points

- **LLM passthrough**: Not in `$llmConfigPassedKeys`. Chatbook uses it to choose the endpoint and never sends it to the provider.
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.
- **Notebook conversion**: Not listed in `$popOutSettings`.

### Preferences UI

Not exposed in the preferences UI.

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

### Allowed Roles

`"Multimodal"` decides *whether* images are included at all. A separate rule decides *which message
roles* may carry one, because providers restrict this and reject a request that gets it wrong.
`allowedMultimodalRoles` (`ChatMessages.wl`) answers that question, and both callers — the per-cell
message builder and the tool response path in `toolEvaluation` — consult it before expanding an image
into typed content parts.

It resolves in two steps:

1. **The Responses endpoint permits an image only inside a user item**, whatever the model, so a
   request that resolves to it is restricted to `{ "User" }`. See [`"Endpoint"`](#endpoint).
2. Otherwise the `"MultimodalRoles"` entry in `$modelAutoSettings` applies. This is a model auto
   setting only — it is not a chat setting, so it cannot be set through `CurrentChatSettings` — and it
   can be declared per family or, as OpenAI does, once for the whole service. Anything undeclared
   means unrestricted.

OpenAI declares `{ "User" }` at the service level (`$modelAutoSettings["OpenAI", Automatic]`) because
both of its endpoints enforce it, and say so explicitly:

```
chat completions:  Invalid 'messages[0]'. Image URLs are only allowed for messages with role
                   'user', but this message with role 'system' contains an image URL.
responses:         Invalid value: 'input_image'. Supported values are: 'input_text'.
```

Declaring it for the service rather than per model matters in practice: the rule is a property of the
API rather than of any one model, so every current and future variant — `gpt-4o`, `gpt-4o-mini`,
dated snapshots, `chatgpt-4o-latest`, the GPT-5 families, the o-series — is covered without anyone
having to notice a new name.

Other providers are unrestricted. Anthropic was verified to accept an image in a system message.

The visible consequence, where a restriction applies, is that a tool result carrying an image is sent
to the model as text: the image is dropped from the request rather than the request failing. The
image is still displayed in the notebook, which does not depend on what was sent.

### Chat Mode Overrides

- **ContentSuggestions** mode sets its own `$wlSuggestionsMultimodal`, `$textSuggestionsMultimodal`, and `$notebookSuggestionsMultimodal` flags (all `False`).
- **ChatTitle** (`ChatTitle.wl`) uses `$multimodalTitleContext = False` for title generation.

### Integration Points

- **LLM passthrough**: Not in `$llmConfigPassedKeys` (not passed to the LLM service; used internally by Chatbook for message content processing).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Exposed in `PreferencesContent.wl` under the "Features" section as a PopupMenu with three options: `Automatic` ("Enabled by Model"), `True` ("Enabled Always"), and `False` ("Enabled Never"), reading and writing `CurrentChatSettings[$preferencesScope, "Multimodal"]`.
