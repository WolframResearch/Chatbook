# Notebook Tools

The notebook tools let the AI Assistant (the Notebook Assistant window and the sidebar) read and edit the user's notebooks. They are 12 default tools:

| File | What it holds |
|---|---|
| `Source/Chatbook/Tools/NotebookTools.wl` | The implementation, in its own context ``Wolfram`Chatbook`Tools`NotebookTools` ``, so that its private names don't collide with those of the other tool files. It exports `$notebookToolSpecs` (the tools' specifications) and `notebookToolsSupportedQ` (the gate). |
| `Source/Chatbook/Tools/DefaultToolDefinitions/NotebookTools.wl` | Registers the specifications as default tools and adds Chatbook's keys: machine names, short names, icons, `"Enabled"`, `"Hidden"`. |
| `Assets/CellDiff/` | CellDiff's notebook comparison, which ShowChanges uses. |
| `Source/Chatbook/Sandbox.wl` | `sandboxCheckCells` (the code check) and `sandboxTeXBoxes` (reading LaTeX), both run in the sandbox kernel. |

## The Tools

| Tool | Short name | Parameters (optional in italics) | What it does |
|---|---|---|---|
| ListNotebooks | `nb_list` | none | Lists the open notebooks, front to back, and the open snapshots, as JSON |
| OpenNotebook | `nb_open` | *`notebook`* | Opens a snapshot of a listed notebook (its id, exact window title or file), of a `.nb` file, or of a new empty notebook without `notebook`. Gives the handle (`s1`, `s2`, ...), the editing guide and the notation, and then the cells, or an outline of the headings if they don't fit into the read budget |
| GetOutline | `nb_outline` | `notebook`, *`preview`*, *`offset`*, *`limit`* | Each cell's marker line and the start of its content |
| ReadCells | `nb_cells` | `notebook`, *`cells`*, *`full`* | Cells as marker lines and their exact content |
| SearchNotebook | `nb_find` | `notebook`, `query`, *`regex`*, *`cells`*, *`styles`*, *`limit`* | One line per match: `#id (Style) line:column: the line` |
| GetSelection | `nb_selection` | `notebook` | The user's selection in the notebook the snapshot was made from, in the snapshot's ids |
| EditInCell | `nb_edit` | `notebook`, `cell`, `edits`, *`evaluate`* | Exact text replacements in one cell (`edits`: `[{oldText, newText, count}]`) |
| SetCells | `nb_set` | `notebook`, `cells`, *`delete`*, *`evaluate`* | Replaces the content, style or tags of cells (`cells`: `[{cell, text, style, tags}]`) |
| InsertCells | `nb_insert` | `notebook`, `newCells`, *`cell`*, *`position`*, *`evaluate`* | Inserts cells (`newCells`: `[{style, text, tags}]`) after or before a cell, or at the end |
| DeleteCells | `nb_delete` | `notebook`, `cells` | Deletes cells |
| ShowChanges | `nb_show` | `notebook` | Shows the user their notebook as a comparison against the snapshot, then closes the snapshot |
| CloseNotebook | `nb_close` | `notebook` | Closes a snapshot and discards its edits |

The short names are the commands of the Simple tool method; none of them starts with the command of another tool. EditInCell's machine name is set to `edit_in_cell`, since `toMachineToolName` gives `edit_incell`, which `getToolByName` would not find.

The workflow is in OpenNotebook's description. The editing guide (`$notebookEditingGuide`) and the cell text notation (`$notebookNotation`) are in OpenNotebook's result instead of the descriptions, since the descriptions are sent with every request of an AI Assistant chat that has the tools.

A tool's function takes the arguments as an Association and gives a string, or `<|"Result" -> Failure["NotebookToolError", ...], "String" -> text|>`, whose `"String"` Chatbook sends to the model. For an internal failure, the model only learns that the tool failed.

## Where They Are Enabled

- `$notebookAssistanceBaseSettings` (`ChatModes/ShowNotebookAssistance.wl`) lists the tools in `"Tools"`, next to NotebookReader, so they reach the window and the sidebar. No persona lists them.
- `"Enabled" :> TrueQ[$WorkspaceChat || $SidebarChat] && notebookToolsSupportedQ[]`: only in AI Assistant chats, and only where the front end supports them (below).
- `"Hidden" -> True`, as for NotebookReader: they are not in the tool manager, since they are enabled only in AI Assistant chats.
- They read the user's notebooks, so `selectTools` (`Tools/Common.wl`) drops them with NotebookReader when `"AllowSelectionContext"` is not `True` (the user turned notebook content off, e.g. with the sidebar's "Ignore notebook content", which is checked by default). They are dropped before the `"Enabled"` checks.
- One edit takes several calls (open, read, edit, fix, show), so `resolveTools` raises `"MaxToolResponses"` to at least `$notebookToolResponses` (20) when any of them is selected; a larger value is kept.

### The Gate

`notebookToolsSupportedQ[]` is `True` outside the cloud, on 16.0 or later, with a front end whose agent notebook packets exist: `` FrontEnd`NotebookSnapshot ``, `` FrontEnd`NotebookCellText ``, `` FrontEnd`NotebookCellTextEdit `` and `` FrontEnd`NotebookSelectionText ``. The kernel's version alone is not enough, since the stock 16.0.0 front end lacks the packets.

`frontEndPacketsQ` probes the front end once per session, the first time the tools' `"Enabled"` is checked (never while the MX is built): a front end with the packets answers `$Failed` to `` FrontEnd`NotebookCellText[] `` without arguments, and one without them answers `Null`. The front end without the packet also reports the unknown packet in its Messages window, which pops up, so the probe turns off console messages for the front end session while it runs and sets them back to `Inherited` afterwards (an edge case: a session-level `"ConsoleMessageAction"` set by someone else is not kept). The probe is three front end calls.

On 16.0 the probe normally runs in the assistant's warm-up (`initializeWorkspaceChat`, when the window or the sidebar opens and the user is signed in), since the warm-up resolves the workspace settings, whose `"AllowSelectionContext"` is `True`, whatever the sidebar's own setting is. Otherwise it runs with the first chat that has the tools. Under `UsingFrontEnd` with a stock 16.0.0 front end, the first probe took about 0.25 s, mostly the first session-level option write; later set and reset pairs take a few milliseconds.

## Snapshots

The model never edits the user's notebooks:

1. OpenNotebook has the front end make a hidden snapshot (`` FrontEnd`NotebookSnapshot[source] ``) of a listed notebook (unsaved changes included), of a `.nb` file, or a new empty notebook. `$snapshots` records it under a handle. Its cells are numbered `c1`, `c2`, ... in document order, and new cells get the next numbers, so an id stays with its cell for the life of the snapshot. At most `$maxSnapshots` (10) are open at a time.
2. The reads and edits go to the snapshot. Each edit tool sends its edit as one `` FrontEnd`NotebookCellTextEdit `` packet, which the front end applies all or none (with `evaluate`, the new outputs are a second one).
3. ShowChanges saves the snapshot and calls CellDiff's `` CellDiffNotebookDiff`ShowNotebookDiff[source, snapshot, "Lines", editedCells] ``, which shows the user's notebook as a comparison against the snapshot, in the notebook itself (a file that is not open is opened, and a new notebook is just shown). The user accepts or rejects each change there. Then the snapshot is closed, and the front end deletes its file. If the comparison fails, the snapshot stays open.

A snapshot belongs to the chat that opened it (its `"ConversationUUID"`, read from `$ChatHandlerData`; `None` outside such a chat). A chat can end without ShowChanges or CloseNotebook (the user stops it, it runs out of tool calls, the model forgets), and the user may change the notebook afterwards, so a snapshot left open by an earlier chat is stale for a later one: the tools only see the running chat's snapshots (`chatSnapshots`), OpenNotebook discards a stale snapshot of the same notebook and makes a new one, and when `$maxSnapshots` are open, the oldest snapshot of another chat is closed to make room.

Only the notebooks that ListNotebooks lists can be opened, and `.nb` files. They are the `"Included"` notebooks of `SourceNotebookObjectInformation[]`, without help pages, the Messages window and deployed notebooks: palettes, dialogs, chat windows and notebooks excluded from AI are not listed. A listed notebook's id is the start of its UUID.

Every front end operation goes through `notebookFrontEnd`, so that tests can replace it with a made-up front end. Without a front end, ListNotebooks lists no notebooks and the other tools give an error.

Known edge case: snapshots are hidden notebooks in the front end, which outlive a kernel restart, but `$snapshots` does not. They stay open, unused, until the front end quits.

### CellDiff

`Assets/CellDiff` (`CellDiffNotebookDiff.wl` and the `CellDiffControlStyles.wl` that it loads) is a copy of the FE repository's `docs/CellDiff`, declared as the `"CellDiff"` asset in `PacletInfo.wl`, until the front end ships the comparison. Keep it in sync with the FE repository. It is loaded once per session, at the first ShowChanges, with its contexts kept off `$ContextPath` (`notebookDiffFunction`).

## Cell Text

The front end reads and writes one cell's content in the agent text form (the FE repository's `docs/NotebookMCP/AgentTextForm.md`). The tools show a cell as a marker line `(* ::Style:: #id *)` followed by its content, and convert no content but LaTeX formulas: math is read and written as LaTeX (`〔tex:...〕`, `〔display-tex:...〕`), which the front end doesn't read. `texFormulas` turns the model's LaTeX into boxes with the kernel's TeX import, and `texReadTexts` shows the front end's formulas as LaTeX where that LaTeX reads back to the same boxes. The import runs in the sandbox kernel (`sandboxTeXBoxes`), since it evaluates parts of what it reads.

Nothing the model writes may run code when it is shown in the user's notebook or read by the kernel: `requireInertText` refuses linear syntax and, inside box wrappers, dynamic boxes and options that hold code. Box wrappers may hold only boxes and plain data (`requireDataWrappers`): each is parsed held, never evaluated, and accepted only if every symbol in it is a ``System` `` one (or `` FE`ElidedBox ``) and every head a box, a list, a rule, an association, a color, `URL`, `Cell`, `BoxData` or `TextData`, as for the front end's formulas (`frontEndFormulaBoxes`). Control characters are refused too: they come from a model's broken JSON escapes.

A LaTeX formula with a tab, a carriage return, or a line break followed by a letter is refused with a hint: it is a LaTeX command whose backslash a JSON string took as an escape (`\theta` as a tab and `heta`).

The notation in OpenNotebook's result also tells the model that cell text is not chat Markdown (no backticks, `**` or `$...$`): the AI Assistant's own prompt asks for double backticks around inline code, which models otherwise carry into cells.

## Code Check and Evaluation

When SetCells, EditInCell or InsertCells change or insert an Input or Code cell, their result ends with a code check (`codeCheck`): `sandboxCheckCells` evaluates the snapshot's Input and Code cells in order in the sandbox kernel (the WolframLanguageEvaluator's kernel, never Chatbook's kernel), in a fresh context with only ``System` `` on `$ContextPath`, at most `$cellCheckSeconds` (10) per cell, starting no cell after `$codeCheckSeconds` (30). The result shows what each cell gives (InputForm, at most 100 characters) and its messages. Known gap: changes the code makes to ``System` `` symbols stay in the sandbox kernel.

Output cells are never written by hand. With `evaluate: true`, the Input cells the call writes and every Input or Code cell after the first of them get new outputs: their Output, Print, Message and Echo cells are replaced by Output cells (also styled `"EvaluationUnmatched"`) with the boxes the sandbox kernel gives, checked like the model's text. A cell whose result is aborted, too large, or would run code when shown keeps its old outputs.

## Limits

- `$readBudget` (40000): characters in one result that shows cells (at least one cell is shown).
- `$maxSnapshots` (10): snapshots open at a time.
- `$codeCheckSeconds` (30) and `$cellCheckSeconds` (10): the code check.
- `$outlineLimit` (300) and `$searchLimit` (50): the defaults of GetOutline's `limit` and SearchNotebook's `limit`.

## Tool Methods

The tools are default tools, so `chooseToolMethod` can resolve `"ToolMethod"` to `"Simple"`, whose parameters are text. EditInCell's `edits`, SetCells' `cells` and InsertCells' `newCells` take lists of objects (`RepeatingElement @ CompoundElement[...]`), so with the Simple method:

- The tool listing marks them `(JSON)`, and `readJSONParameters` (`Tools/Common.wl`) reads their values as JSON before the tool's interpreter gets them. A value that isn't a JSON array or object stays a string, and the interpreter reports it.
- With the hybrid tool method, `toolRequestToString` (`LLMUtilities.wl`) writes a native call as a Simple call: lists and associations as compact JSON (`simpleParameterValue`), and for a tool with more than one parameter, every value with its name, since a native call can leave out optional parameters or give them in any order.

The first `CompoundElement` interpretation in a session takes about 0.5 to 1 s. It comes with the first edit call, after the first token.

## Cost

Where the tools are enabled, every request of an AI Assistant chat carries them (measured 2026-11-23):

- Simple tool listing (system prompt): about 8,600 characters, 2,900 tokens.
- Native descriptions and JSON schemas: about 11,700 characters, 3,700 tokens.
- The hybrid tool method (the default gpt-5.4) sends both, about 6,500 tokens; before the notebook tools, NotebookReader's listing was about 280 tokens.
- Time to first token, headless AI Assistant chats through OpenAI's gpt-5.4 with ChatCompletions (the LLM Kit route), 4 fresh kernels per arm, alternated: warm median 1.53 s without the tools, 1.59 s with them (12 chats each); the cold first chat (about 37 s in a script kernel, mostly kernel start-up) differed by less than its noise.
- Building the tool listing: about 6 ms more CPU per request.

The descriptions can't be deferred, since the model needs them to know the tools exist; the notation and the editing guide are in OpenNotebook's result for that reason, and provider prompt caching covers the static prefix in later requests.

## Tests

- `Tests/NotebookTools.wlt` tests the tools on a made-up front end (`notebookFrontEnd` replaced).
- `Tests/Sandbox.wlt`: `TeXBoxes` and `CheckCells-*`.
- `Tests/ServiceToolCalls.wlt`: the "Structured Parameters" tests of the Simple method.
- `Tests/ToolAvailability.wlt`: the "Notebook Tools" tests of the selection, the `"AllowSelectionContext"` rule and `"MaxToolResponses"`.
