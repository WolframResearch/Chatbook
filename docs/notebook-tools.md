# Notebook Tools

Nine default tools let the AI Assistant (the Notebook Assistant window and the sidebar) read and edit the user's notebooks: ListNotebooks, OpenNotebook, GetOutline, ReadCells, SearchNotebook, EditInCell, WriteCells, ShowChanges and CloseNotebook. The model never edits a notebook of the user: edits go to a hidden snapshot, and the user accepts or rejects them in a diff.

| File | What it holds |
|---|---|
| `Source/Chatbook/Tools/NotebookTools.wl` | The tools, in their own context. It exports `$notebookToolSpecs`, `notebookToolsSupportedQ` (the gate) and the Common symbol `withNotebookCellSyntax`. |
| `Source/Chatbook/Tools/DefaultToolDefinitions/NotebookTools.wl` | Registers them as default tools: machine names, short names, icons, `"Enabled"`, `"Hidden"`. |
| `Source/Chatbook/Serialization.wl`, `CellSyntax/` | The [cell syntax](cell-syntax.md): cells to text (`CellToString` with `"IncludeXML"` and `"PreserveBoxes"`) and text to cells (`cellsFromString`). |
| `Source/Chatbook/ChatModes/Context.wl` | The notebook context and NotebookReader, in the cell syntax for a chat that has the tools. |
| `Source/Chatbook/Prompting.wl` | The base prompt component `"CellSyntax"`. |
| `Assets/CellDiff/` | CellDiff's notebook comparison, which ShowChanges uses. |

- Cells are text in the cell syntax, which the kernel reads and writes. The front end only makes snapshots and gives and takes cell expressions.
- Reading needs no snapshot and no OpenNotebook call: the notebook context has the cells with the ids and the text that the tools use, so an edit can be one call and ShowChanges.

## One Edit

1. **Context.** The chat's first request has the user's notebook in the cell syntax (`withContextCellSyntax`). `$cellTables` now has the table of the chat and the notebook: the id of each cell by its ExpressionUUID, what reading recorded for each id (`$cellOriginals`), and the ids of the cells that were shown whole (`"Seen"`).
2. **Edit.** The model calls EditInCell or WriteCells with an id and text from the context. `withSnapshot` has the front end make a hidden snapshot of the notebook as it is now (`$snapshots`: `s1`), and the call writes to it. The result says `Opened s1 ...`, what was written, and that the user does not see it yet.
3. **More calls** of the chat read and write the snapshot, whose cells have the same ids.
4. **ShowChanges** has CellDiff show the user's notebook as a comparison against the snapshot, in the notebook itself, and closes the snapshot. The user accepts or rejects each change with the controls of the cells or the toolbar.

## The Tools

| Tool | Short name | Parameters (optional in italics) | What it does |
|---|---|---|---|
| ListNotebooks | `nb_list` | none | The open notebooks, front to back, and the chat's snapshots, as JSON |
| OpenNotebook | `nb_open` | *`notebook`* | Reads a listed notebook (its id, window title or file) as it is, or opens a snapshot of a `.nb` file that is not open, or of a new notebook. Gives a line about it and its cells, or an outline if they don't fit into the read budget |
| GetOutline | `nb_outline` | *`notebook`*, *`offset`*, *`limit`* | A line per cell: `c12 (Input) the start of its content` |
| ReadCells | `nb_cells` | *`notebook`*, *`cells`*, *`full`* | Cells in the cell syntax (`cells`: ids, ranges such as `c10-c20`, or `all`) |
| SearchNotebook | `nb_find` | `query`, *`notebook`*, *`regex`*, *`cells`*, *`styles`*, *`limit`* | A line per match in the bodies: `c12 (Input) 3:14: the line` |
| EditInCell | `nb_edit` | `cell`, `edits`, *`notebook`*, *`evaluate`* | Exact text replacements in the body of one cell (`edits`: `[{oldText, newText, count}]`), all or none, in a snapshot |
| WriteCells | `nb_write` | `cells`, *`notebook`*, *`evaluate`* | Replaces, adds, moves and deletes cells, all or none, in a snapshot. `cells` is cell tags in the cell syntax |
| ShowChanges | `nb_show` | *`notebook`* | Shows the diff and closes the snapshot. Its description says that it needs no permission and is called before the final reply |
| CloseNotebook | `nb_close` | *`notebook`* | Closes a snapshot and discards its edits |

- A tool's function takes the arguments as an Association and gives a string, or `<|"Result" -> Failure["NotebookToolError", ...], "String" -> text|>`, whose `"String"` Chatbook sends to the model. For an internal failure the model only learns that the tool failed.
- The short names are the commands of the Simple tool method; none starts with the command of another tool. Required parameters come first, since that method reads values without names in that order. It splits a value of several lines where a line starts with the name of a parameter, which is why `after`, `before` and `delete` are attributes of a cell tag and no parameters.
- What the model needs to write cells is in WriteCells' description, and what it needs to read them is `"CellSyntax"`. The tools do not replace NotebookReader: its scope `selection` is the only way to see where the user is now.
- **The `notebook` parameter** (`resolveNotebook`). Without it a tool works on the chat's snapshot if it has one (it names them if there are several), else on the notebook that the notebook context is taken from. A value is cleaned once, of the white space, quotes and backticks around it (`cleanName`), and is then one name for handles, ids, titles and files. A value that is no open handle is a notebook as OpenNotebook takes it; a handle that is not open in a chat without snapshots is the user's notebook, since models guess `s1`. The reading tools read the chat's snapshot of that notebook if there is one, else the notebook as it is, under its id (`withNotebook`); a `.nb` file that is not open is opened as a snapshot. The editing tools make the snapshot if there is none (`withSnapshot`). A function of a tool gets a record of what it works on (`notebookRecord`): the name, the NotebookObject, the source, the edits and the ids of deleted cells.
- **File names** are compared as text (`sameFileQ`): the expanded name, with one kind of separator, and without regard to letter case on Windows and macOS (`$ignoreFileCase`). Nothing is asked of the disk or the network for that. This is a best effort and no boundary (the evaluator tool can read any file): another name that the file system resolves to the same file is another file here. That is a short name (`EXCLUD~1.NB`), a name through a junction or a link (also `Documents and Settings`), a UNC name, a mapped or `subst` drive, a name with the prefix `\\?\` or `\\.\`, and a hard link. By such a name a listed notebook is not found as the open notebook, and an excluded one is only refused if its saved file says that it is excluded: otherwise the saved file is opened as a snapshot, without what is unsaved. A snapshot of a file is made from the name that the model gave, expanded (`notebookFile`), and ShowChanges opens that name: for a listed notebook (by a mapped drive or a UNC name) a second window with the diff, not the user's window.
- **Excluded from AI.** A notebook that the user excluded from chats is not listed and is not opened by its file (`excludedFileQ` for an open notebook, as far as file names tell; the settings of the snapshot for a file that is not open). Titles and ids only name listed notebooks. ShowChanges also refuses if the notebook is excluded when it is called, since the user may exclude it after the snapshot was made. A cell that the user excluded (`chatExcludedQ` on the cell, as in the notebook context) is left out by `readEntries`, which every tool reads cells with: it is not shown or found, the result says how many cells were left out, and a call that edits, moves or deletes it is refused.
- **Locked cells.** A cell that the front end resolves as not deletable or not editable is not changed, moved or deleted, and the outputs of a cell are not replaced if one is not deletable (`requireUnlocked`, before anything is written). The front end does not delete a cell with `Deletable -> False`, so a write to one would leave both cells, and a delete would do nothing. A generated cell only counts if it is not deletable: the stylesheet makes messages not editable.

## WriteCells and Evaluation

`writePlan` gives the text to `cellsFromString` once, with `after`, `before` and `delete` as the tools' own attributes and a function that reads the cell of an id when it is asked for. The plan is made from the records.

| Text | Effect |
|---|---|
| `<cell id='c3'>new content</cell>` | Replaces the content of c3. Attributes that are left out keep their values |
| `<cell id='c3' CellTags='x'/>` | Changes attributes only |
| `<cell style='Text'>...</cell>` | A new cell: after the cell before it in the text, or where `after='c5'` or `before='c1'` says, or at the end. After a cell is after its outputs, and after the cells that the call already placed there (`planAfter`) |
| `<cell id='c5'/>` | Changes nothing. Marks the place for the new cells after it, and names the cell for `evaluate` |
| `<cell id='c7' after='c2'/>` | Moves c7 as it is (with a body, it also replaces its content) |
| `<cell id='c9' delete='true'/>` | Deletes c9 |

- Everything is converted before anything is written. A text that is refused writes nothing, and the message names the cell (a new one by the number of its tag).
- **Places.** A cell that is placed after a cell of the notebook (by `after`, or by following its tag in the text) comes after that cell's outputs, the generated cells right after it, and not between the two. The cells that follow such a cell are read for that, up to the first one that is not generated. Cells that name the same place in the same way keep the order of the text: each comes after the ones that the call placed there before it. A generated cell that is moved with `after` is not put after the outputs: it goes right after the cell that `after` names, or after what the call already placed there ([Known Gaps](#known-gaps)).
- **Seen cells.** A body replaces all of a cell, so it is only taken for a cell that the chat was given whole: in the context, by NotebookReader, ReadCells or OpenNotebook, or in the result of an edit. A cut body (`truncated='true'`) and a line of an outline or a search do not count.
- A cell that reads the same after the write is not written, so it stays the user's cell and is no change in the diff.
- The content of a generated cell (`$$generatedCellStyle`) is not written as text. The message says how to move or delete one, since a model otherwise deletes and retypes it.
- The result lists what was done and where each run of new cells is: `Wrote to s1: changed c5; new c7 (Text), c8 (Input) after c5; moved c6; deleted c4.` A cell that a tag rewrites and places is changed and moved. One that is at that place already is not moved: it is written where it is, or not at all if it also reads as before.
- A cell that an earlier WriteCells call of the chat deleted from the snapshot (`"Deleted"` of the record) has its own message, which says so and how a cell is moved: a model that deletes a cell to write it again elsewhere otherwise takes the cell for moved.
- EditInCell is the body of the cell, the replacements, and `cellsFromString` with the cell as the existing one. A count that does not fit lists the places of `oldText`. Selection markers are taken out of `oldText`.
- **`evaluate: true`** evaluates the Input and Code cells that the call wrote or named, in the order of the notebook, statement by statement (`sandboxStatements`, `evaluateToBoxes`), in the kernel of the WolframLanguageEvaluator tool. In the AI Assistant that is the user's kernel. A box in the code is given as an expression URI.
  - The generated cells right after the cell are replaced by an Output cell for each statement that gives something (with the style `"EvaluationUnmatched"` unless the evaluator is the user's session). A new output has the label of the output at its position if the cell has as many outputs as before, whatever its form (`Out[12]//MatrixForm=` stays on a plain `-2`).
  - If a statement gives no boxes, the outputs stay as they were. Otherwise what the statements give is written, also one that is its own result (`Sin[x]`, `{1, 2, 3}`), unless the check of the result keeps the outputs.
  - **The check of the result.** The user's session only has the definitions that the user has evaluated. With it as the evaluator a cell is evaluated whatever it uses, and then the symbol names among the string tokens of its results' boxes are checked (`undefinedSymbols`). If one of them is a symbol that another code cell of the notebook assigns and that has no value and no definition in the kernel, the outputs stay as they were, also for a cell without outputs. The result then says once for the cell which symbols those are, which cell defines each, and that those cells are evaluated first by naming them with the cell in one call (`<cell id='c14'/><cell id='c24'/>`). Its gaps: [Known Gaps](#known-gaps).
    - The symbols that a cell assigns are those of a `Set` or `SetDelayed` at the top level of its statements, read with CodeParser (`assignedSymbols`): no assignment inside another expression, no up-value. The cell that defines a symbol is the nearest cell above that assigns it, else the first one below. A cell below is evaluated after the cell whatever the order of the tags is, so it only counts for the next call.
    - Nothing is evaluated to tell, and no symbol is made. The notebook is only read if a name has nothing in the kernel: its other code cells, of which those with such a name and an assignment are read as text.
    - A name that the cell binds itself (a pattern variable, an iterator, the left side of a rule, a local) is not in its result, so it does not count.
    - A sandboxed evaluator never has the notebook's definitions: what it gives is written.
  - Without the evaluator tool nothing is evaluated, and the result says that `evaluate` needs it.

## Snapshots, the Front End and CellDiff

- A snapshot is `` FrontEnd`NotebookSnapshot[source] ``: a hidden notebook whose cells have the ExpressionUUIDs of the source's. `$snapshots` has its record under a handle; at most `$maxSnapshots` (10) are open.
- A snapshot of an open notebook only exists while it has edits. An editing call that writes nothing closes the snapshot that it made.
- A snapshot belongs to the chat that opened it (`"ConversationUUID"`). A stale one of the same notebook is closed when another chat edits the notebook.
- A notebook that still shows a diff is not edited: the call says that the user has to resolve the changes first.
- **`notebookFrontEnd`** is what the tools do with a notebook, and what tests replace: `"Snapshot"`, `"Excluded"`, `"Cells"` (all, or those of a style), `"Read"`, `"Locks"`, `"Write"`, `"Close"`, `"DiffCells"` and `"ShowDiff"`. Which notebooks there are comes from `listedNotebooks`, `userNotebook` and `excludedFileQ`, and the gate probes the front end itself.
- A write names cells by their ExpressionUUIDs: `{"Replace", uuid, cell}`, `{"Insert", uuid | None, "After" | "Before", cells}`, `{"Delete", uuids}`. A written cell has its ExpressionUUID as an option, which the front end keeps, so a replaced cell keeps its id and a move is a delete and an insert.
- **A front end defect.** `NotebookGet` of a hidden notebook leaves out the cells after a cell that `NotebookWrite` wrote inside a cell group (also in the stock 16.0.0 front end). The tools never use it on a snapshot: they list cells with `Cells` and read them with `NotebookRead`.
- **CellDiff** (`Assets/CellDiff`, a copy of the FE repository's `docs/CellDiff`; do not edit it here) is loaded at the first ShowChanges. `showNotebookDiff` uses two of its forms:
  1. `ShowNotebookDiff[source, snapshot, "Lines", edited]` with the ExpressionUUIDs of the edited cells reads only the cells that changed (0.33 s for 790 cells, 0.26 s for a notebook of 57 MB).
  2. If the cells do not line up (a move, or most cells changed), CellDiff would `NotebookGet` the snapshot. That call is kept from giving the snapshot, so CellDiff fails before it writes, and ShowChanges gives it a `Notebook` expression instead (`comparedNotebook`): the snapshot's cells with their ExpressionUUIDs, the unchanged ones read from the source. A moved cell gets another ExpressionUUID and CellDiff's tag, so that it shows as deleted at the old place and inserted at the new one, and Reject All puts it back. This form hashes every cell: 1.9 s for 790 cells, 33 s for 57 MB.
- If no cell is marked afterwards, the result says that there is nothing to accept, and the notebook gets back the stylesheet and the dynamic expression that CellDiff replaced (`shownDiff`). That happens if the edits only changed cell tags, which CellDiff applies as they are, or cell labels, which it does not compare (the label stays as it was), or if the notebook already had the changes.

## Cell Ids

- A cell has one id in a chat, in the context and in the tools: `c1`, `c2`, ... in the order of the notebook when the chat first sees it, and the next number for a cell that is seen later.
- `withNotebookCellSyntax[notebook, eval]` evaluates `eval` with the ids and the records of that table. It must not be nested.
- The `$maxCellTables` (20) tables that were used last are kept, for the kernel session.

## The Context and the Prompt

- A chat that has any of the tools (`notebookToolsSelectedQ`) gets the notebook in the cell syntax wherever Chatbook serializes it: the notebook context and both scopes of NotebookReader. Other chats get the Markdown that they always got.
- The selection is marked as [the cell syntax](cell-syntax.md#the-cell-tag) says (`placeSelectionMarkers`). The reminder and the prompts for searches are without cell tags, the latter also without `<RawBoxes>`.
- A cell that a limit cuts says `truncated='true'` and keeps its tags (`cutCellString` for the token budget).
- If the context does not show every cell, its last line names the others as ranges for ReadCells and says that cells that the user excluded stay hidden (`addCellsNotShown`, one `Cells` call).
- A graphic is an image link in its cell. A multimodal chat gets the images of the first links (`$maxContextImages`).
- `"CellSyntax"` says what a cell tag is, that `<RawBoxes>` and links are copied as they are, that the tags are never written in replies, and that a change is made with the tools and shown with ShowChanges in the same turn. It is empty for other chats.

## Where They Are Enabled

- `$notebookAssistanceBaseSettings` lists the tools next to NotebookReader. `"Enabled"` is `TrueQ[$WorkspaceChat || $SidebarChat] && notebookToolsSupportedQ[]`, and they are `"Hidden"`.
- `selectTools` drops them with NotebookReader when `"AllowSelectionContext"` is not `True`. `resolveTools` raises `"MaxToolResponses"` to at least 20 when one is selected.
- **The gate.** `notebookToolsSupportedQ[]` is `True` outside the cloud, on 16.0 or later, with a front end that has `` FrontEnd`NotebookSnapshot ``. The stock 16.0.0 front end lacks it. `snapshotPacketQ` probes once per session (three front end calls, about 0.25 s, normally in the assistant's warm-up) with console messages off, since a front end without the packet reports it in its Messages window.
- The warm-up also reads one cell of code (`initializeCellSyntax`), which loads CodeParser: about 0.8 s, after the input field is usable.
- **Tool methods.** With the Simple method EditInCell's `edits` is marked `(JSON)` and read by `readJSONParameters`. With the hybrid method `toolRequestToString` writes a native call as a Simple call.

## Limits and Cost

| What | Value |
|---|---|
| Cells in one result (`$readBudget`) | 40,000 characters; at least one cell |
| Body of one cell (`$cellLength`) | 10,000 characters unless `full` is true |
| Outline, search (`$outlineLimit`, `$searchLimit`) | 300 cells, 50 matches by default |
| Images of one tool result (`$maxToolResponseImages`) | 5 |
| One `<MakeBoxes>`, `<ToBoxes>` or statement | 30 s |
| Simple tool listing, every request | 5,736 characters |
| Native descriptions and schemas, every request | 6,795 characters (the hybrid method sends both) |
| `"CellSyntax"` | 853 characters |
| Notebook context | 0.96 to 1.5 times the Markdown form for the same cells; the same time to build, and 2 s where the Markdown form takes 16 s for a notebook of 57 MB |
| First EditInCell of a session | 0.5 to 1 s for the `CompoundElement` interpreter |
| A cell tag of WriteCells with an `id` or with `after` | One or two more reads of a cell, for the outputs of the cell that it names |
| `evaluate: true` with the user's session as the evaluator | Nothing measurable for a cell whose results hold no symbol without a value; 0.12 s for each cell whose results do, for which the other code cells of the notebook are read (400 of 800 cells) |

`NotebookTools-PromptSize` bounds the descriptions and the help of the parameters (4,896 characters) at 4,900.

## What Changes for Chats Without the Tools

A chat has none of the tools outside of the sidebar and the Notebook Assistant window, and in those two where the tools are not supported or notebook content is off. Such a chat sends, gets and shows what it did before the tools were added, with the exceptions of this list. Its notebook context and the formatting of its replies are what they were, and `CellToString` without the new options gives what it gave (0 differences in 29,600 cells, see [cell-syntax.md](cell-syntax.md#guarantees-and-known-gaps)).

1. **The NotebookEditor tool is gone** (`Tools/DefaultToolDefinitions/NotebookEditor.wl`), with `$notebookEditorEnabled` and the cell references that it named cells by (`cellReference` in `FrontEnd.wl`). It has been disabled since September 2024, so no chat had it. A `"Tools"` setting that still names it gets the `ToolNotFound` message of an unknown tool.
2. **The nine tools are default tools** (`$DefaultTools`), hidden from the tool manager, and `$notebookAssistanceBaseSettings` lists them. Whether they are supported is asked when a sidebar or Notebook Assistant chat with notebook content selects its tools, and in the assistant's warm-up. On 16.0 or later outside the cloud that probes the front end once per session (three front end calls, about 0.25 s, see [the gate](#where-they-are-enabled)), also where the answer is no, and leaves the session's `ConsoleMessageAction` as `Inherited`. On earlier versions and in the cloud nothing is asked of the front end.
3. **A tool result attaches at most 5 images** in a multimodal chat, the first ones (`$maxToolResponseImages`, `expandMultimodalString[string, max]`). Its other image links stay text. Before, all of them were attached.
4. **The evaluator** reads each of several image links in code as its own (`preprocessSandboxString`). For a URI whose value is boxes it gives code the expression that the boxes stand for, read in its own kernel (`makeSegmentProgram`). Boxes that stand for nothing stay `RawBoxes`, which all of them were before.
5. **The options of `CellToString`**: `"PreserveBoxes"` is new (`False` by default), `"IncludeXML"` writes the cell tag of the cell syntax, and `"XMLCellAttributes"` is gone. No code in Chatbook turned the last two on.
6. **`ExplodeCell`** keeps all of the content of a list item.
7. **The Simple tool method** (`Tools/Common.wl`) takes a tool without parameters. A parameter whose interpreter takes a list or an object (`RepeatingElement`, `CompoundElement`, `AnySubset`) is listed with the type `JSON`, and its value is read as JSON (`readJSONParameters`). A value that is no JSON array or object stays a string.
8. **The hybrid tool method** (`toolRequestToString` in `LLMUtilities.wl`) writes a native call with the name of each value, unless the tool has only one parameter (before, values without line breaks were written without names). It writes lists and objects as JSON on one line, and leaves out a parameter that the tool does not have.
9. **The base prompt** has the component `"CellSyntax"`, which is empty for these chats.

## Known Gaps

- **Stop does not stop a running tool call.** The call runs to its end, and its edits stay in the snapshot, which the next request writes to.
- **Only ShowChanges shows the edits.** If the model ends its turn without calling it, they stay in the snapshot and the user sees none of them.
- **A snapshot with edits that were not shown goes stale** if the user changes the notebook: later turns read and edit it as it is.
- **The tool acts on the notebook that is in front when it runs,** which may not be the one that the context was read from.
- **Ids are renumbered** after a kernel restart, and for the cells that a comparison writes without their ExpressionUUID: the changed cells of form 1, cells that only show a deletion, moved cells, and a cell whose tags changed.
- **The sidebar's default "Ignore notebook content" hides the tools,** and the assistant then says that it can't edit the notebook.
- **The last line of the context can name a cell that is excluded from chats** (it does not check, and says that such cells stay hidden): ReadCells then says that the cell is left out.
- **`evaluate`** has no `In` and `Out` lines, and a re-evaluated output has no label if the cell has more or fewer outputs than before.
- **The check of the result does not catch** a result that does not show the missing symbol, which is written: `UnitaryMatrixQ[U1[...]]` gives `False` when `U1` has no definition, and the plot of such a function is empty. And a cell that lacks definitions has run in the user's kernel when the check answers: what it assigned stays (`psit = U.psi0` with `U` and `psi0` as symbols) until the cells are evaluated in order.
- **The check wrongly keeps the outputs** if a result is meant to hold a symbol that another cell assigns and the kernel has no value for: `Solve[x^2 == 9, x]` after `x = 3` and `Clear[x]`, or a `Plot` whose `AxesLabel` names such a symbol. Following the text evaluates that other cell in the user's kernel, where `x = 3` stays, and writes another result. The model has no way to have such a result written.
- **Places.** New cells for one gap that is named both with `before` and with `after` (`before='c16'` and `after='c15'`) do not keep the order of the text: the ones with `after` come first. An output that is moved with `after` lands after a cell that the same call placed there, and not right after the cell that `after` names.
- **A notebook is only known by the text of its file name** (see "File names" under [The Tools](#the-tools)).
- **A notebook that the user excludes after the chat has a snapshot of it** is still read from the snapshot and edited there. Only ShowChanges refuses.
- **A whole comparison** (form 2) has no cell groups, so closed groups are open afterwards. For a `.nb` file that is not open, moves are not marked.
- **Snapshots outlive a kernel restart** until the front end quits.
- **The diff view** (CellDiff and the front end): a tall changed cell can show no diff at all; a notebook outside the trusted directories shows "potentially unsafe dynamic content"; the toolbar, the stylesheet and the dynamic expression stay after the last change is resolved with the controls of a cell; the view jumps to the top; 2D code overlaps; a re-evaluated output is a deletion and an insertion.

## Tests

- `Tests/NotebookTools.wlt`: the tools on a made-up front end, and the real front end operations on a hidden copy (`NotebookTools-FrontEnd-*`: CellDiff after a move, an edit that marks nothing, locked and excluded cells and notebooks, an excluded notebook by its file in another letter case).
- `Tests/Context.wlt` ("Cell Syntax") and `Tests/NotebookReader.wlt` (`CellSyntax-SharedCellIDs`): the context of a chat that has the tools.
- `Tests/CellSyntax.wlt`: the syntax. `Tests/Sandbox.wlt`, `Tests/ServiceToolCalls.wlt`, `Tests/ToolAvailability.wlt`, `Tests/Prompting.wlt`, `Tests/PromptCache.wlt`: the evaluator, tool calls, the selection of the tools and the prompt.
