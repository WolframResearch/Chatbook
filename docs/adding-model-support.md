# How to Add Support for a New Model

Adding model support to Chatbook ranges from minimal (2 files, ~20 lines) to substantial (6+ files, 150+ lines) depending on how the model differs from existing defaults.

The core idea: Chatbook classifies models into **families** and resolves their capabilities through a **hierarchical settings table**. Adding support means (a) teaching Chatbook to recognize the model and (b) telling it how the model behaves.

For a real-world example of a simple addition, see [PR #1355](https://github.com/WolframResearch/Chatbook/pull/1355) (Gemini 2/3 support, 2 files, 21 lines). For a complex addition requiring structural changes, see [PR #1120](https://github.com/WolframResearch/Chatbook/pull/1120) (Claude 3.7 Sonnet improvements, 7 files, 151 lines). For a detailed walkthrough covering new settings, on-demand prompts, formatting fixes, and pipeline reordering, see [Case Study: Adding GPT 5.4 Support](model-support-examples/gpt-5-4.md).

---

## Key Concepts

### Model Families

A model **family** is a string identifier (e.g., `"GPT5"`, `"Claude4"`, `"Gemini2"`) that groups related model variants. Families are the primary key for looking up model-specific settings.

Families are defined in `Source/Chatbook/Models.wl` via `chooseModelFamily0` rules:

```wl
chooseModelFamily0[ wordsPattern[ { "GPT", "5.1", ___ } ] ] := "GPT51";
chooseModelFamily0[ wordsPattern[ { "GPT", "5", ___ } ] ]   := "GPT5";

chooseModelFamily0[ wordsPattern[ { "Claude", "3", ___ } ] ]                        := "Claude3";
chooseModelFamily0[ wordsPattern[ { "Claude", "Haiku"|"Sonnet"|"Opus", "4", ___ } ] ] := "Claude4";

chooseModelFamily0[ wordsPattern[ { "Gemini", "2", ___ } ] ] := "Gemini2";
chooseModelFamily0[ wordsPattern[ { "Gemini", "3", ___ } ] ] := "Gemini3";
```

The `wordsPattern` helper (`Common.wl`) performs a **case-insensitive word boundary match**. The list form `{ "Gemini", "2", ___ }` matches model names like `"gemini-2-flash"`, `"Gemini 2 Pro"`, etc., because `containsWordsQ` (`Utils.wl`) joins list elements with non-word-character gaps and checks for a case-insensitive match. The `___` at the end allows trailing words (variant names, dates, etc.).

**Ordering matters**: more specific patterns must appear before less specific ones. For example, `"GPT51"` must be defined before `"GPT5"`, otherwise all GPT-5.x models would match the broader `"GPT5"` pattern.

When no `chooseModelFamily0` rule matches, the fallback definition returns `None`:

```wl
chooseModelFamily0[ _String ] := None;
```

In this case, `chooseModelFamily` falls back to stripping common suffixes (Mini, Nano, Turbo, Pro, etc.) from the model's `BaseID` to derive an approximate family name.

### Settings Resolution Hierarchy

Model-specific settings are stored in `$modelAutoSettings` (`Settings.wl`) and resolved by `autoModelSetting` through an **8-level lookup**, from most specific to least specific:

```
1. $modelAutoSettings[ service,   modelName,   key ]    (* e.g., "Anthropic", "claude-3.7-sonnet" *)
2. $modelAutoSettings[ service,   modelID,     key ]    (* e.g., "Anthropic", "Claude37Sonnet"    *)
3. $modelAutoSettings[ service,   modelFamily, key ]    (* e.g., "Anthropic", "Claude3"           *)
4. $modelAutoSettings[ Automatic, modelName,   key ]    (* service-agnostic, by name              *)
5. $modelAutoSettings[ Automatic, modelID,     key ]    (* service-agnostic, by ID                *)
6. $modelAutoSettings[ Automatic, modelFamily, key ]    (* service-agnostic, by family            *)
7. $modelAutoSettings[ service,   Automatic,   key ]    (* service-level default                  *)
8. $modelAutoSettings[ Automatic, Automatic,   key ]    (* global default                         *)
```

The first match wins. This means you only need to define overrides for settings that differ from the defaults. Settings not explicitly overridden will cascade through to the global defaults.

**Service name normalization**: The `toBaseServiceName` function (`Settings.wl`) strips `"LLMKit"`, `"WolframAI"`, and `"AITutor"` prefixes, so settings defined for `"Anthropic"` also apply when the model is accessed through LLMKit or similar wrappers.

**`Verbatim @ Automatic`**: Use this when you explicitly want a setting to remain `Automatic` rather than being resolved from a less-specific level. Without `Verbatim`, `Automatic` would not count as a match and the lookup would continue down the hierarchy.

### Available Settings Properties

Settings that model configurations commonly override, organized by category. See [settings/full-listing.md](settings/full-listing.md) for the complete reference.

**Core capabilities:**

| Setting | Type | Description |
|---------|------|-------------|
| `"MaxContextTokens"` | Integer | Context window size in tokens |
| `"Multimodal"` | Boolean | Whether the model accepts image inputs |
| `"ToolsEnabled"` | Boolean | Whether the model supports tool/function calling |
| `"ForceSynchronous"` | Boolean | Force non-streaming (synchronous) API calls |
| `"Reasoning"` | `"Minimal"` / `"None"` / `Missing["NotSupported"]` | Extended thinking/reasoning mode |

**Tool configuration:**

| Setting | Type | Description |
|---------|------|-------------|
| `"ToolMethod"` | `"Service"` / `Verbatim @ Automatic` | `"Service"` for native API tool calling, `Verbatim @ Automatic` for prompt-based |
| `"HybridToolMethod"` | Boolean | Combine service-level and prompt-based tool calling |
| `"ToolResponseRole"` | `"System"` / `"User"` | Message role for tool response messages |
| `"ToolCallExamplePromptStyle"` | `"Basic"` / `Automatic` | Style of tool usage examples in system prompt |
| `"ToolExamplePrompt"` | `Automatic` / `None` | Whether to include tool usage examples |
| `"ToolCallRetryMessage"` | Boolean | Append retry guidance after tool responses |
| `"SplitToolResponseMessages"` | Boolean | Split mixed content+tool-request messages |
| `"MaxToolResponses"` | Integer | Maximum tool calls per turn |
| `"DiscourageExtraToolCalls"` | Boolean | Add prompt text discouraging excessive tool calls |

**Parameter support:**

| Setting | Type | Description |
|---------|------|-------------|
| `"Temperature"` | Number / `Missing["NotSupported"]` | Sampling temperature |
| `"PresencePenalty"` | Number / `Missing["NotSupported"]` | Presence penalty parameter |
| `"StopTokens"` | List / `Missing["NotSupported"]` | Stop sequences |
| `"EndToken"` | String / `None` | End-of-turn token for response parsing |

**Text processing:**

| Setting | Type | Description |
|---------|------|-------------|
| `"ReplaceUnicodeCharacters"` | Boolean | Replace Wolfram Language special characters with ASCII equivalents |
| `"ConvertSystemRoleToUser"` | Boolean | Convert system role messages to user role |
| `"TokenizerName"` | String | Which tokenizer to use for token counting (e.g., `"gpt-4o"`) |
| `"ExcludedBasePrompts"` | List | Base prompt components to skip for this model |

Settings whose value is `Missing["NotSupported"]` receive special treatment throughout the system. See [Unsupported Parameters (`Missing["NotSupported"]`)](#unsupported-parameters-missingnotsupported) for details.

---

## Simple Model Addition

For models that work within existing infrastructure and just need capability declarations. Reference: [PR #1355](https://github.com/WolframResearch/Chatbook/pull/1355).

### Step 1: Define the model family (`Models.wl`)

Add a `chooseModelFamily0` rule in `Source/Chatbook/Models.wl`, near related families:

```wl
(* In the chooseModelFamily0 definitions, near other Gemini entries *)
chooseModelFamily0[ wordsPattern[ { "Gemini", "2", ___ } ] ] := "Gemini2";
chooseModelFamily0[ wordsPattern[ { "Gemini", "3", ___ } ] ] := "Gemini3";
```

Place more specific patterns before less specific ones within the same model group.

### Step 2: Define model settings (`Settings.wl`)

Add `$modelAutoSettings` entries in `Source/Chatbook/Settings.wl`, under the appropriate service section:

```wl
(* Under the GoogleGemini service section *)
$modelAutoSettings[ "GoogleGemini", "Gemini2" ] = <|
    "ForceSynchronous" -> False,
    "MaxContextTokens" -> 1047576,
    "Multimodal"       -> True,
    "ToolsEnabled"     -> True
|>;

$modelAutoSettings[ "GoogleGemini", "Gemini3" ] = <|
    "ForceSynchronous" -> False,
    "MaxContextTokens" -> 1047576,
    "Multimodal"       -> True,
    "ToolsEnabled"     -> True
|>;
```

Only override settings that differ from the service-level default (`$modelAutoSettings["GoogleGemini", Automatic]`) or the global default (`$modelAutoSettings[Automatic, Automatic]`).

### Step 3: Add service-level defaults (if needed)

If the model's service has behaviors that apply to all its models, add a service-level default:

```wl
$modelAutoSettings[ "GoogleGemini", Automatic ] = <|
    "PresencePenalty" -> Missing[ "NotSupported" ]
|>;
```

### Step 4: Verify

1. Delete the MX cache if it exists: `Source/Chatbook/64Bit/Chatbook.mx`
2. Load the paclet:
   ```wl
   PacletDirectoryLoad["path/to/Chatbook"];
   Get["Wolfram`Chatbook`"]
   ```
3. Verify family classification:
   ```wl
   Wolfram`Chatbook`Models`Private`chooseModelFamily["gemini-2-flash"]
   (* Should return "Gemini2" *)
   ```
4. Run the test suite:
   ```bash
   wolframscript -f Scripts/TestPaclet.wls
   ```

### Files changed summary

| File | Change |
|------|--------|
| `Source/Chatbook/Models.wl` | Add `chooseModelFamily0` rule(s) |
| `Source/Chatbook/Settings.wl` | Add `$modelAutoSettings` entry/entries |

---

## Complex Model Addition

When a model has unique behaviors that require more than just settings configuration. Reference: [PR #1120](https://github.com/WolframResearch/Chatbook/pull/1120).

### When is a complex addition needed?

- The model needs **custom prompt components** (new instructions injected into the system prompt)
- The model requires **message pipeline workarounds** (e.g., splitting messages, rewriting roles)
- The model introduces a **new setting** that doesn't exist yet
- The model's API has **behavioral differences** that affect tool calling, response parsing, or code evaluation

### Adding new settings

When a model needs a setting that doesn't yet exist, follow this pattern (using `"DiscourageExtraToolCalls"` from PR #1120 as an example):

**1. Declare the symbol** in `Source/Chatbook/CommonSymbols.wl` (alphabetically):

```wl
`discourageExtraToolCallsQ;
```

**2. Add the default value** in `$defaultChatSettings` in `Source/Chatbook/Settings.wl`:

```wl
"DiscourageExtraToolCalls" -> Automatic,
```

**3. Assign model-specific values** in `$modelAutoSettings`:

```wl
$modelAutoSettings[ "Anthropic", "Claude37Sonnet" ] = <|
    "DiscourageExtraToolCalls" -> True,
    "ToolExamplePrompt"        -> Automatic
|>;
```

**4. Add the consumer logic** where the setting is used (e.g., `Source/Chatbook/ChatMessages.wl`):

```wl
discourageExtraToolCallsQ // beginDefinition;
discourageExtraToolCallsQ[ KeyValuePattern[ "ToolsEnabled" -> False ] ] := False;
discourageExtraToolCallsQ[ KeyValuePattern[ "Tools" -> { } ] ] := False;
discourageExtraToolCallsQ[ settings_Association ] := TrueQ @ settings[ "DiscourageExtraToolCalls" ];
discourageExtraToolCallsQ // endDefinition;
```

### Adding base prompt components

When a model needs custom text injected into the system prompt, add a base prompt component in `Source/Chatbook/Prompting.wl` in three steps:

**1. Add to `$basePromptOrder`** (determines position in the system prompt):

```wl
$basePromptOrder = {
    (* ... existing entries ... *)
    "EndTurnToolCall",
    "DiscourageExtraToolCalls",   (* <-- new entry *)
    "WolframLanguageEvaluatorToolTrouble",
    (* ... *)
};
```

**2. Add to `$basePromptDependencies`** (declares which other components this one requires):

```wl
$basePromptDependencies = Append[ "GeneralInstructionsHeader" ] /@ <|
    (* ... existing entries ... *)
    "DiscourageExtraToolCalls" -> { },   (* no dependencies beyond the auto-appended header *)
    (* ... *)
|>;
```

Note: The `Append["GeneralInstructionsHeader"]` wrapper means `"GeneralInstructionsHeader"` is automatically added as a dependency for every entry. Specify additional dependencies in the list.

**3. Define the prompt text** in `$basePromptComponents`:

```wl
$basePromptComponents[ "DiscourageExtraToolCalls" ] = "\
* Don't make more tool calls than is needed. Tool calls cost tokens, so be efficient!";
```

**4. Conditionally include it** based on the model setting (in `Source/Chatbook/ChatMessages.wl`):

```wl
If[ discourageExtraToolCallsQ @ settings, needsBasePrompt[ "DiscourageExtraToolCalls" ] ];
```

The `needsBasePrompt` function adds the named component (and its dependencies) to the prompt that will be assembled for the LLM.

### Modifying the message pipeline

The message preparation pipeline in `Source/Chatbook/SendChat.wl` processes messages through a series of stages:

```
messages -> prepareMessagesForLLM0 -> rewriteMessageRoles -> replaceUnicodeCharacters
         -> splitToolResponses -> makeStringResults -> removeSources -> removeBasePromptTags
```

To add a new pipeline stage, guard it behind a model-specific setting so it only activates for models that need the behavior:

```wl
(* Definition *)
splitToolResponses // beginDefinition;

splitToolResponses[ settings_Association, messages_ ] :=
    If[ TrueQ @ settings[ "SplitToolResponseMessages" ],
        Flatten[ splitToolResponse /@ messages ],
        messages
    ];

splitToolResponses // endDefinition;

(* Individual message handler *)
splitToolResponse // beginDefinition;

splitToolResponse[ msg: HoldPattern @ KeyValuePattern @ {
    "Role"         -> "Assistant",
    "Content"      -> content: Except[ "", _String ],
    "ToolRequests" -> { __LLMToolRequest }
} ] := { KeyDrop[ msg, "ToolRequests" ], <| msg, "Content" -> "" |> };

splitToolResponse[ msg_ ] := msg;

splitToolResponse // endDefinition;
```

Then add the stage to the pipeline:

```wl
split = ConfirmMatch[ splitToolResponses[ settings, replaced ], { ___Association }, "Split" ];
```

### Setting inheritance for model variants

When a model family has sub-variants with incremental differences, use association splatting to inherit settings from a parent:

```wl
(* Base GPT-5 settings *)
$modelAutoSettings[ Automatic, "GPT5" ] = <|
    "HybridToolMethod"           -> False,
    "MaxContextTokens"           -> 400000,
    "Multimodal"                 -> True,
    "PresencePenalty"            -> Missing[ "NotSupported" ],
    "ToolMethod"                 -> "Service"
|>;

(* GPT-5.1 inherits from GPT-5, overrides one setting *)
$modelAutoSettings[ Automatic, "GPT51" ] = <|
    $modelAutoSettings[ Automatic, "GPT5" ],
    "Reasoning" :> If[ TrueQ @ $gpt5Reasoning, "None", Missing[ "NotSupported" ] ]
|>;

(* GPT-5.2 inherits from GPT-5.1, adds more overrides *)
$modelAutoSettings[ Automatic, "GPT52" ] = <|
    $modelAutoSettings[ Automatic, "GPT51" ],
    "ExcludedBasePrompts"      -> { ParentList, "EscapedCharacters" },
    "ReplaceUnicodeCharacters" -> True
|>;

(* GPT-5.3 is identical to GPT-5.2 *)
$modelAutoSettings[ Automatic, "GPT53" ] =
    $modelAutoSettings[ Automatic, "GPT52" ];

(* GPT-5.3-Chat inherits from GPT-5.3 with a different context window *)
$modelAutoSettings[ Automatic, "GPT53Chat" ] = <|
    $modelAutoSettings[ Automatic, "GPT53" ],
    "MaxContextTokens" -> 128000
|>;
```

By splatting the parent association (`$modelAutoSettings[Automatic, "GPT5"]`) as the first element, all parent keys are inherited and later keys override them. This is a standard Wolfram Language pattern where later keys in an association replace earlier ones.

### Unsupported Parameters (`Missing["NotSupported"]`)

When a model's API does not accept certain parameters (e.g., `Temperature`, `PresencePenalty`), mark them with `Missing["NotSupported"]` in the model's auto settings:

```wl
$modelAutoSettings[ Automatic, "O4Mini" ] = <|
    "PresencePenalty" -> Missing[ "NotSupported" ],
    "StopTokens"     -> Missing[ "NotSupported" ],
    "Temperature"    -> Missing[ "NotSupported" ]
|>;
```

This is not just a marker -- it has specific effects at multiple stages of the pipeline:

#### 1. Settings resolution is short-circuited

When `resolveAutoSetting0` (`Settings.wl`) resolves a setting with an `Automatic` value, it first checks `autoModelSetting`. If the result is `Missing["NotSupported"]`, that value is accepted immediately -- the normal default resolution logic (custom resolvers like `autoStopTokens`, `forceSynchronousQ`, etc.) is bypassed entirely:

```wl
(* From Settings.wl — this check runs before any setting-specific resolver *)
resolveAutoSetting0[ as_, name_String ] :=
    With[ { s = autoModelSetting[ as, name ] },
        s /; MatchQ[ s, Missing[ "NotSupported" ] | Except[ $$unspecified ] ]
    ];
```

This means `Missing["NotSupported"]` propagates through the resolved settings as-is. For example, `autoStopTokens` checks for it explicitly and preserves it rather than computing stop tokens:

```wl
autoStopTokens[ KeyValuePattern[ "StopTokens" -> Missing[ "NotSupported" ] ] ] :=
    Missing[ "NotSupported" ];
```

#### 2. Parameters are stripped before reaching the API

Before sending the LLM configuration to the API, unsupported parameters are removed through two independent mechanisms in `makeLLMConfiguration` (`SendChat.wl`):

**`DeleteMissing`** removes any keys with `Missing[...]` values from the config association. This catches settings that resolved to `Missing["NotSupported"]` and flowed into the LLM config:

```wl
(* From SendChat.wl *)
DeleteMissing @ Association[
    KeyTake[ as, $llmConfigPassedKeys ],
    "StopTokens" -> makeStopTokens @ as,
    "ToolMethod" -> "Service"
] // dropModelUnsupportedParameters[ as ]
```

**`dropModelUnsupportedParameters`** (`Settings.wl`) provides a second layer of protection. It independently queries `autoModelSetting` for each key in the config and drops any whose model auto-setting is `Missing["NotSupported"]`:

```wl
(* From Settings.wl *)
dropModelUnsupportedParameters[ model_Association, config_Association ] := Enclose[
    Module[ { drop },
        drop = ConfirmMatch[ modelUnsupportedParameters[ model, config ], { ___String }, "Drop" ];
        KeyDrop[ config, drop ]
    ],
    throwInternalFailure
];

modelUnsupportedParameters[ as_, keys: { ___String } ] :=
    Select[ keys, autoModelSetting[ as, # ] === Missing[ "NotSupported" ] & ];
```

This catches cases where a parameter has a concrete value in the settings (e.g., from `$defaultChatSettings` defaults) but the model's auto-setting declares it unsupported. The parameter is dropped regardless of its current value.

The legacy (non-LLMServices) API path in `makeHTTPRequest` (`SendChat.wl`) has its own removal via `DeleteCases[..., Automatic|_Missing]`, which also strips `Missing["NotSupported"]` values from the HTTP request body.

#### 3. Which settings are affected

The settings passed through to the LLM API are defined in `$llmConfigPassedKeys` (`SendChat.wl`):

```wl
$llmConfigPassedKeys = {
    "MaxTokens",
    "Model",
    "PresencePenalty",
    "Reasoning",
    "Temperature"
};
```

`StopTokens` is handled separately (via `makeStopTokens`) but follows the same `DeleteMissing` removal path. These are the settings where `Missing["NotSupported"]` is most commonly used, since they correspond directly to API parameters that vary across models.

#### Summary

The lifecycle of `Missing["NotSupported"]` is:

1. **Declared** in `$modelAutoSettings` for the model family
2. **Resolved** as the setting value, short-circuiting normal `Automatic` resolution
3. **Preserved** by setting-specific resolvers that check for it explicitly
4. **Removed** from the LLM config by `DeleteMissing` and `dropModelUnsupportedParameters` before the API call

### Service-level vs. family-level vs. service-agnostic settings

Choose the right scope for your settings:

- **Service-level** (`$modelAutoSettings["GoogleGemini", Automatic]`): Applies to *all* models from this service. Use for service-wide API behaviors like unsupported parameters.
- **Service + family** (`$modelAutoSettings["Anthropic", "Claude3"]`): Applies only to a specific family on a specific service. Use when the behavior is unique to this service's implementation of the model.
- **Service-agnostic family** (`$modelAutoSettings[Automatic, "GPT5"]`): Applies to a model family regardless of which service provides it. Use when the same model is available through multiple services (e.g., GPT models through OpenAI, AzureOpenAI, and LLMKit).

### Files changed summary

| File | Change | When needed |
|------|--------|-------------|
| `Source/Chatbook/Models.wl` | `chooseModelFamily0` rules | Always |
| `Source/Chatbook/Settings.wl` | `$modelAutoSettings` entries and new setting defaults | Always |
| `Source/Chatbook/Prompting.wl` | New base prompt components | When adding model-specific prompts |
| `Source/Chatbook/CommonSymbols.wl` | Symbol declarations | When adding new settings or predicates |
| `Source/Chatbook/SendChat.wl` | Message pipeline modifications | When fixing message-level API quirks |
| `Source/Chatbook/ChatMessages.wl` | Message construction and prompt logic | When adding conditional prompt inclusion |
| `Source/Chatbook/Sandbox.wl` | Code parsing changes | When fixing code evaluation quirks |

---

## Common Patterns and Recipes

### Model with native tool calling

```wl
$modelAutoSettings[ "ServiceName", "ModelFamily" ] = <|
    "ToolMethod" -> "Service"
|>;
```

### Model with hybrid (prompt + service) tool calling

```wl
$modelAutoSettings[ "ServiceName", "ModelFamily" ] = <|
    "HybridToolMethod" -> True,
    "ToolMethod"        -> Verbatim @ Automatic
|>;
```

### Model with unsupported parameters

```wl
$modelAutoSettings[ Automatic, "ModelFamily" ] = <|
    "Temperature"     -> Missing[ "NotSupported" ],
    "PresencePenalty" -> Missing[ "NotSupported" ],
    "StopTokens"     -> Missing[ "NotSupported" ]
|>;
```

### Reasoning model

```wl
$modelAutoSettings[ Automatic, "ModelFamily" ] = <|
    "ForceSynchronous"        -> True,
    "ConvertSystemRoleToUser" -> True,
    "MaxContextTokens"        -> 100000,
    "Reasoning"               -> "Minimal",
    "ToolMethod"              -> "Service"
|>;
```

### Large context window model

```wl
$modelAutoSettings[ "ServiceName", "ModelFamily" ] = <|
    "MaxContextTokens" -> 1000000,
    "Multimodal"       -> True,
    "ToolsEnabled"     -> True
|>;
```

### Model that requires system-to-user role conversion

```wl
$modelAutoSettings[ Automatic, "ModelFamily" ] = <|
    "ConvertSystemRoleToUser" -> True,
    "ToolResponseRole"        -> "User"
|>;
```

---

## Testing

1. **Delete the MX cache** at `Source/Chatbook/64Bit/Chatbook.mx` (if it exists)
2. **Load the paclet** and verify:
   ```wl
   PacletDirectoryLoad["path/to/Chatbook"];
   Get["Wolfram`Chatbook`"]

   (* Verify family classification *)
   Wolfram`Chatbook`Models`Private`chooseModelFamily["your-model-name"]

   (* Verify a specific setting *)
   Wolfram`Chatbook`Common`autoModelSetting[
       <|"Service" -> "ServiceName", "Name" -> "your-model-name"|>,
       "MaxContextTokens"
   ]
   ```
3. **Run the test suite**:
   ```bash
   wolframscript -f Scripts/TestPaclet.wls
   ```
4. **Run the code inspector**:
   ```bash
   wolframscript -f Scripts/CheckPaclet.wls
   ```

---

## PR Checklist

- [ ] Model family defined in `Models.wl` (`chooseModelFamily0` rule)
- [ ] More specific patterns ordered before less specific ones
- [ ] Model settings defined in `Settings.wl` (`$modelAutoSettings`)
- [ ] Only overrides for settings that differ from defaults
- [ ] `Missing["NotSupported"]` used for unsupported API parameters
- [ ] New settings have default values in `$defaultChatSettings` (if applicable)
- [ ] New symbols declared in `CommonSymbols.wl` (if applicable)
- [ ] New base prompt components added to all three structures in `Prompting.wl` (if applicable)
- [ ] MX cache deleted before testing
- [ ] Family classification verified manually
- [ ] Settings resolution verified manually
- [ ] Test suite passes (`Scripts/TestPaclet.wls`)
- [ ] Code check passes (`Scripts/CheckPaclet.wls`)

---

## Reference: Current Model Families

All model families currently defined in `chooseModelFamily0` (`Models.wl`):

| Family | Pattern | Service Settings |
|--------|---------|-----------------|
| `"GPT5"` | `{ "GPT", "5", ___ }` | `Automatic` |
| `"GPT51"` | `{ "GPT", "5.1", ___ }` | `Automatic` (inherits from GPT5) |
| `"GPT52"` | `{ "GPT", "5.2", ___ }` | `Automatic` (inherits from GPT51) |
| `"GPT53"` | `{ "GPT", "5.3", ___ }` | `Automatic` (inherits from GPT52) |
| `"GPT53Chat"` | `{ "GPT", "5.3", "Chat", ___ }` | `Automatic` (inherits from GPT53) |
| `"GPT54"` | `{ "GPT", "5.4", ___ }` | `Automatic` (inherits from GPT53) |
| `"Claude2"` | `{ "Claude", "2.0"\|"2.1" }` | `Anthropic` |
| `"Claude3"` | `{ "Claude", "3", ___ }` | `Anthropic` |
| `"Claude4"` | `{ "Claude", "Haiku"\|"Sonnet"\|"Opus", "4", ___ }` | `Anthropic` |
| `"Gemini2"` | `{ "Gemini", "2", ___ }` | `GoogleGemini` |
| `"Gemini3"` | `{ "Gemini", "3", ___ }` | `GoogleGemini` |
| `"DeepSeekChat"` | `{ "DeepSeek", ___, "Chat"\|"V3", ... }` | `DeepSeek` |
| `"DeepSeekReasoner"` | `{ "DeepSeek", ___, "Reasoner"\|"R1", ... }` | `DeepSeek`, `TogetherAI` |
| `"DeepSeekCoder"` | `{ "DeepSeek", ___, "Coder", ... }` | &mdash; |
| `"Phi"` | `"Phi" ~~ version` | &mdash; |
| `"Gemma"` | `"Gemma"\|"CodeGemma" ~~ version` | &mdash; |
| `"Qwen"` | `"Qwen" ~~ version` | `Automatic` |
| `"Nemotron"` | `"Nemotron" ~~ version` | `Automatic` |
| `"Mistral"` | `"Mistral"\|"Mixtral" ~~ version` | `Automatic`, `MistralAI` |
| `"GPT4Omni"` | (via BaseID fallback) | `Automatic` |
| `"GPT41"` | (via BaseID fallback) | `Automatic` |
| `"O1Mini"` | (via BaseID fallback) | `Automatic` |
| `"O1"` | (via BaseID fallback) | `Automatic` |
| `"O3Mini"` | (via BaseID fallback) | `Automatic` |
| `"O3"` | (via BaseID fallback) | `Automatic` |
| `"O4Mini"` | (via BaseID fallback) | `Automatic` |
