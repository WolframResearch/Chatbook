# Formatting & Output Settings

## `"AutoFormat"`

Whether to auto-format LLM output by parsing Markdown syntax and converting it to structured notebook cells.

### Behavior

When `True` (default), the LLM response is processed to convert Markdown elements into properly formatted Wolfram notebook cells:

- Code blocks (with language detection)
- Headings
- Bold/italic text
- Inline code
- LaTeX math
- Images
- Bullet lists
- Block quotes
- Tables

Also includes the `"Formatting"` base prompt component in the system prompt, which instructs the LLM that its output will be parsed as Markdown.

When `False`, output is displayed as plain text.

Works in conjunction with `"DynamicAutoFormat"` to control whether formatting is applied during streaming.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook for output formatting).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Exposed in the preferences UI as a checkbox.

## `"DynamicAutoFormat"`

Whether to apply formatting during streaming, providing live-formatted output as the LLM response streams in.

### Accepted Values

- **`True`** — streaming content is processed by the formatting function in real-time, converting Markdown to formatted notebook expressions as they arrive
- **`False`** — streaming content is displayed as raw text (via `RawBoxes @ Cell @ TextData`) without live formatting
- **`Automatic`** (default) — resolves to `TrueQ` of the `"AutoFormat"` setting, so dynamic formatting is enabled whenever auto-formatting is enabled

### Resolution

Resolution is handled by `dynamicAutoFormatQ` in `SendChat.wl`, which first checks for an explicit `True`/`False` value, then falls back to `"AutoFormat"`. The resolved value is captured as the `reformat` variable in `activeAIAssistantCell` and passed to `dynamicTextDisplay`, which dispatches between formatted and raw text display.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies` (but depends on `"AutoFormat"` at resolution time).
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook for streaming display).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI; controlled indirectly via the `"AutoFormat"` checkbox.

## `"StreamingOutputMethod"`

Controls whether streaming content is progressively split into static (already-written) and dynamic (still-updating) portions during LLM response streaming. When `Automatic` (the setting default), resolves to `"PartialDynamic"` via `resolveAutoSetting0` (`Settings.wl`).

### Accepted Values

Six valid string values in two groups:

| Value | Dynamic Splitting |
| ----- | ----------------- |
| `"PartialDynamic"` | Enabled |
| `"Automatic"` | Enabled |
| `"Inherited"` | Enabled |
| `"FullDynamic"` | Disabled |
| `"Dynamic"` | Disabled |
| `"None"` | Disabled |

When `Automatic` (the setting default), resolves to `"PartialDynamic"` via `resolveAutoSetting0` (`Settings.wl`). Invalid values trigger an `"InvalidStreamingOutputMethod"` warning (`Common.wl`) and default to enabled.

### Resolution

The setting is evaluated by the `dynamicSplitQ` function (`Settings.wl`), which determines the `$dynamicSplit` flag used in `chatHandlers` (`SendChat.wl`). Symbol values are converted to their string names.

### Behavior

When dynamic splitting is enabled (`$dynamicSplit` is `True`), the `splitDynamicContent` function (`SendChat.wl`) is called on each `"BodyChunkReceived"` event: it splits the accumulated dynamic content string using `$dynamicSplitRules` (`Formatting.wl`) — a set of string patterns defining safe split points (e.g., after complete code blocks, headings, paragraphs) — then writes the completed static portions as final formatted notebook cells and keeps only the remaining dynamic portion updating live. This reduces the amount of content being dynamically re-rendered, improving performance for long responses.

When disabled, all streaming content remains in a single dynamic cell until the response completes.

Dynamic splitting is also disabled in headless mode (`$headlessChat`), inline chat (`$InlineChat`), cloud notebooks (`$cloudNotebooks`), and when the Wolfram Engine version is insufficient (`insufficientVersionQ["DynamicSplit"]`).

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook for streaming display optimization).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"NotebookWriteMethod"`

Controls whether FrontEnd task batching is used for notebook write operations during chat.

### Accepted Values

- **`"PreemptiveLink"`** — enables FrontEnd task optimization, where notebook write operations (e.g., `NotebookWrite`, formatting toggles, error cell placement) are queued via `createFETask` (`FrontEnd.wl`) into the `$feTasks` list and executed in batches via `runFETasks`, reducing MathLink roundtrips between the kernel and FrontEnd for better responsiveness during streaming
- **`"ServiceLink"`** — disables this optimization by locally redefining `createFETask` to be the identity function (`#1 &`), causing all notebook writes to execute inline immediately
- **`Automatic`** (default) — resolves to `"PreemptiveLink"` via `resolveAutoSetting0` (`Settings.wl`)

Invalid values trigger an `"InvalidWriteMethod"` warning (`Common.wl`) and fall back to enabled.

### Implementation

The setting is evaluated by the `feTaskQ` function (`SendChat.wl`), which returns `True` for `"PreemptiveLink"` (or unspecified values) and `False` for `"ServiceLink"`. The `feTaskQ` result is passed to `withFETasks` (`SendChat.wl`), which wraps both the `"BodyChunkReceived"` and `"TaskFinished"` handler functions in `chatHandlers`: when `True`, handlers execute normally with `createFETask` queueing enabled; when `False`, handlers execute inside `Block[{createFETask = #1 &}, ...]`, disabling task queueing.

In headless mode (`$headlessChat`), `feTaskQ` always returns `False` regardless of the setting value. In cloud notebooks (`$cloudNotebooks`), `createFETask` evaluates operations immediately rather than queueing them.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook for notebook write optimization).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"TabbedOutput"`

Whether to use paged (tabbed) output for multi-turn chat responses, so that each new LLM response replaces the previous one in the same output cell rather than creating a separate cell.

### Behavior

When `True` (default), consecutive responses to the same chat input are organized as pages within a single output cell. Each time `createNewChatOutput` (`SendChat.wl`) is called with an existing target `CellObject`, `prepareChatOutputPage` serializes the previous response content (via `BinarySerialize` and `BaseEncode`) and stores it in a `"PageData"` association in the cell's `TaggingRules`, with keys `"Pages"` (an association mapping page numbers to base64-encoded content), `"PageCount"`, and `"CurrentPage"`. The new response is then printed as the cell content.

When `False`, `createNewChatOutput` bypasses paging and always creates a new cell via `cellPrint`, so each response appears in its own separate output cell.

### Page Navigation

When a cell has more than one page (`PageCount > 1`), the cell dingbat uses an `"AssistantIconTabbed"` template wrapper (instead of the standard persona icon), which provides tab-style navigation UI. Users can navigate between pages via `rotateTabPage` (`Actions.wl`), which reads `"PageData"` from `TaggingRules`, computes the target page with `Mod`, deserializes the page content from the stored base64, and writes it to the cell via `writePageContent`.

### Reformatting and Empty Responses

When reformatting the final output (`writeReformattedCell` and `reformatCell` in `SendChat.wl`), if `PageData` exists, the page metadata is carried forward via `makeReformattedCellTaggingRules`, which appends the current page's encoded content to the `"Pages"` association and increments the page count. If a response is empty (`None` string), `restoreLastPage` restores the previous page's content instead of deleting the cell.

### Chat Mode Overrides

Overridden to `False` in workspace chat (`$workspaceDefaultSettings` in `StylesheetBuilder.wl`), notebook assistance workspace settings (`$notebookAssistanceWorkspaceSettings`), and sidebar chat settings (`$notebookAssistanceSidebarSettings`) in `ShowNotebookAssistance.wl`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook for output cell management).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"ShowMinimized"`

Whether LLM response output cells are displayed in a minimized (collapsed) state.

### Accepted Values

- **`True`** — the output cell is created with `$closedChatCellOptions` (`CellMargins -> -2`, `CellOpen -> False`, `CellFrame -> 0`, `ShowCellBracket -> False`) and an `attachMinimizedIcon` initialization that attaches a small clickable icon to the previous cell bracket, allowing the user to expand the response on demand
- **`False`** — the output cell is displayed normally in an expanded state
- **`Automatic`** (default) — behavior depends on context (see Resolution)

### Resolution

- In cloud notebooks (`$cloudNotebooks`), resolves to `False` (always expanded, since `$closedChatCellOptions` produces no options in cloud mode).
- In desktop notebooks, `Automatic` is treated equivalently to `True` for the minimization check (via `MatchQ[minimized, True|Automatic]` in `activeAIAssistantCell`, `SendChat.wl`), but only when `$AutomaticAssistance` is `True` — meaning the response was triggered by the automatic assistance system (e.g., `WidgetSend` or `autoAssistQ`-qualified evaluations) rather than a direct user chat input. For direct chat inputs (where `$AutomaticAssistance` is `False`), the minimization options are never applied regardless of this setting's value.

### Effect on `$alwaysOpen`

The setting also influences `$alwaysOpen` via `alwaysOpenQ` (`Actions.wl`):

- When `True`: `$alwaysOpen` is set to `False`
- When `False`: `$alwaysOpen` is set to `True`
- When `Automatic`: `$alwaysOpen` depends on whether the input cell style matches `$$chatInputStyle` or whether the `BasePrompt` contains a severity tag

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook for output cell rendering).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"ShowProgressText"`

Whether to show progress text (e.g., status labels with an ellipsis indicator) in the progress panel while the LLM is generating a response.

### Behavior

When `True` (or when the resolved value is truthy), the `$showProgressText` flag (`CommonSymbols.wl`) is set to `True` during `resolveAutoSettings` (`Settings.wl`), which causes `basicProgressTextRow` (`Utils.wl`) to render a styled `"ProgressTitle"` row in the progress panel showing the current operation label (e.g., "Sending request", "Waiting for response") with a `ProgressIndicator[Appearance -> "Ellipsis"]` appended.

When `False`, `basicProgressTextRow` returns `Nothing`, hiding the text row entirely so only the progress bar (if enabled via `$showProgressBar`) is shown.

### Special Behaviors

- The `$showProgressText` flag is forced to `True` when `"ForceSynchronous"` is truthy, regardless of this setting's value.
- The global default for `$showProgressText` is `False` (`Utils.wl`), so progress text is hidden unless explicitly enabled by this setting or by `ForceSynchronous`.
- The `ContentSuggestions` chat mode (`ChatModes/ContentSuggestions.wl`) locally sets `$showProgressText = True` regardless of this setting.

### Resolution

When `Automatic`, resolves to `True` via the model default in `$modelAutoSettings[Automatic, Automatic]`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: Global default `True` in `$modelAutoSettings[Automatic, Automatic]`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook for progress UI rendering).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"OpenToolCallBoxes"`

Whether tool call display boxes are initially expanded (open) when rendered in the notebook.

### Resolution

When `Automatic`, resolved by `openToolCallBoxesQ` (`Settings.wl`): returns `True` if `SendToolResponse` is `False` (meaning the user will not see further LLM processing of the tool result, so the tool output should be visible directly); otherwise returns `Automatic` (which evaluates to `False` via `TrueQ`, keeping boxes collapsed).

The resolved value is stored in the `$openToolCallBoxes` global variable (`CommonSymbols.wl`).

### Usage

Used in two places:

1. **Tool call box rendering**: in `parseFullToolCallString` (`Formatting.wl`), the parsed tool call data includes `"Open" -> TrueQ @ $openToolCallBoxes`, which is then passed to `makeToolCallBoxLabel` where it controls whether the `openerView` displaying the tool call details (raw and interpreted views) starts in the open or closed state.

2. **Markdown output handling**: in `checkMarkdownOutput` (`SendChat.wl`), when `$openToolCallBoxes` is truthy, tool output containing markdown images is passed through unchanged; when falsy, `$useMarkdownMessage` is appended to the tool response, which tells the LLM: *"The user does not see the output of this tool call. You must use this output in your response for them to see it."* — prompting the LLM to include image links and other formatted content in its visible response text.

### Integration Points

- **Dependencies**: Depends on `"SendToolResponse"` (declared in `$autoSettingKeyDependencies`).
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook for UI rendering and tool response handling).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"TrackScrollingWhenPlaced"`

Whether to auto-scroll the notebook to follow new output as it is placed during and after LLM response streaming.

### Accepted Values

- **`True`** — the output cell includes `PrivateCellOptions -> {"TrackScrollingWhenPlaced" -> True}`, enabling auto-scroll during streaming; after the final reformatted cell is written, `scrollOutput` calls `SelectionMove` with `AutoScroll -> True` to scroll to the completed output
- **`False`** — auto-scrolling is disabled entirely
- **`Automatic`** (default) — resolves based on Wolfram Engine version (see Resolution)

### Resolution

Resolved via `scrollOutputQ` (`SendChat.wl`), which checks whether the Wolfram Engine version meets the minimum requirement of 14.0 (defined in `$versionRequirements` in `Common.wl` via `sufficientVersionQ["TrackScrollingWhenPlaced"]`); if the version is sufficient, auto-scrolling is enabled, otherwise it is disabled.

Note: `scrollOutputQ` has a two-argument form `scrollOutputQ[settings, cell]` that always returns `False` — this is used when computing the `"ScrollOutput"` key for the `reformatCell` path, meaning the post-write `SelectionMove`-based scrolling does not occur for reformatted cells (the `PrivateCellOptions`-based scrolling during streaming is sufficient).

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **Model-specific overrides**: None in `$modelAutoSettings`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook for notebook scroll behavior).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.

## `"AppendCitations"`

Whether to automatically append formatted source citations to the LLM response.

### Behavior

When enabled, citations are generated from sources gathered by prompt generators (e.g., documentation, web searches, WolframAlpha results) and appended as a markdown section. When disabled, the WolframAlpha prompt generator instead includes a hint asking the LLM to cite sources inline.

### Model-Specific Overrides

Global default: `False` (in `$modelAutoSettings[Automatic, Automatic]`).

### Persona Overrides

- **WolframAlpha**: Overrides to `True`.

### Integration Points

- **Dependencies**: None in `$autoSettingKeyDependencies`.
- **LLM passthrough**: Not in `$llmConfigPassedKeys` (used internally by Chatbook for citation handling).
- **Persona inheritance**: Not listed in `$nonInheritedPersonaValues`, so it is inherited from persona configurations.

### Preferences UI

Not exposed in the preferences UI.
