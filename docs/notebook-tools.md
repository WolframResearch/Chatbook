# Notebook Tools

Nine default tools let the AI Assistant (the Notebook Assistant window and the sidebar) read and edit the user's notebooks: ListNotebooks, OpenNotebook, GetOutline, ReadCells, SearchNotebook, EditInCell, WriteCells, ShowChanges and CloseNotebook. The model never edits a notebook of the user: edits go to a hidden snapshot, and the user accepts or rejects them in a diff.

| File | What it holds |
|---|---|
| `Source/Chatbook/Tools/NotebookTools.wl` | The tools, in their own context. It exports `$notebookToolSpecs`, `notebookToolsSupportedQ` (the gate) and the Common symbol `withNotebookCellSyntax`. |
| `Source/Chatbook/Tools/DefaultToolDefinitions/NotebookTools.wl` | Registers them as default tools: machine names, short names, icons, `"Enabled"`, `"Hidden"`. |
| `Source/Chatbook/Serialization.wl`, `CellSyntax/` | The [cell syntax](cell-syntax.md): cells to text (`CellToString` with `"IncludeXML"` and `"PreserveBoxes"`) and text to cells (`cellsFromString`). |
| `Assets/CellDiff/` | CellDiff's notebook comparison, which ShowChanges uses. |

- Cells are text in the cell syntax, which the kernel reads and writes. The front end only makes snapshots and gives and takes cell expressions.

## The Tools

| Tool | Short name | Parameters (optional in italics) | What it does |
|---|---|---|---|
| ListNotebooks | `nb_list` | none | The open notebooks, front to back, and the chat's snapshots, as JSON |
| OpenNotebook | `nb_open` | *`notebook`* | Reads a listed notebook (its id, window title or file) as it is, or opens a snapshot of a `.nb` file that is not open, or of a new notebook. Gives a line about it and its cells, or an outline if they don't fit into the read budget |
| GetOutline | `nb_outline` | *`notebook`*, *`offset`*, *`limit`* | A line per cell: `c12 (Input) the start of its content` |
| ReadCells | `nb_cells` | *`notebook`*, *`cells`*, *`full`* | Cells in the cell syntax (`cells`: ids, ranges such as `c10-c20`, or `all`) |
| SearchNotebook | `nb_find` | `query`, *`notebook`*, *`regex`*, *`cells`*, *`styles`*, *`limit`* | A line per match in the bodies: `c12 (Input) 3:14: the line` |
| ShowChanges | `nb_show` | *`notebook`* | Shows the diff and closes the snapshot. Its description says that it needs no permission and is called before the final reply |
| CloseNotebook | `nb_close` | *`notebook`* | Closes a snapshot and discards its edits |

- A tool's function takes the arguments as an Association and gives a string, or `<|"Result" -> Failure["NotebookToolError", ...], "String" -> text|>`, whose `"String"` Chatbook sends to the model. For an internal failure the model only learns that the tool failed.
- The short names are the commands of the Simple tool method; none starts with the command of another tool. Required parameters come first, since that method reads values without names in that order. It splits a value of several lines where a line starts with the name of a parameter, which is why `after`, `before` and `delete` are attributes of a cell tag and no parameters.
- **The `notebook` parameter** (`resolveNotebook`). Without it a tool works on the chat's snapshot if it has one (it names them if there are several), else on the notebook that the notebook context is taken from. A value is cleaned once, of the white space, quotes and backticks around it (`cleanName`), and is then one name for handles, ids, titles and files. A value that is no open handle is a notebook as OpenNotebook takes it; a handle that is not open in a chat without snapshots is the user's notebook, since models guess `s1`. The reading tools read the chat's snapshot of that notebook if there is one, else the notebook as it is, under its id (`withNotebook`); a `.nb` file that is not open is opened as a snapshot. The editing tools make the snapshot if there is none (`withSnapshot`). A function of a tool gets a record of what it works on (`notebookRecord`): the name, the NotebookObject, the source, the edits and the ids of deleted cells.
- **File names** are compared as text (`sameFileQ`): the expanded name, with one kind of separator, and without regard to letter case on Windows and macOS (`$ignoreFileCase`). Nothing is asked of the disk or the network for that. This is a best effort and no boundary (the evaluator tool can read any file): another name that the file system resolves to the same file is another file here. That is a short name (`EXCLUD~1.NB`), a name through a junction or a link (also `Documents and Settings`), a UNC name, a mapped or `subst` drive, a name with the prefix `\\?\` or `\\.\`, and a hard link. By such a name a listed notebook is not found as the open notebook, and an excluded one is only refused if its saved file says that it is excluded: otherwise the saved file is opened as a snapshot, without what is unsaved. A snapshot of a file is made from the name that the model gave, expanded (`notebookFile`), and ShowChanges opens that name: for a listed notebook (by a mapped drive or a UNC name) a second window with the diff, not the user's window.
- **Excluded from AI.** A notebook that the user excluded from chats is not listed and is not opened by its file (`excludedFileQ` for an open notebook, as far as file names tell; the settings of the snapshot for a file that is not open). Titles and ids only name listed notebooks. ShowChanges also refuses if the notebook is excluded when it is called, since the user may exclude it after the snapshot was made. A cell that the user excluded (`chatExcludedQ` on the cell, as in the notebook context) is left out by `readEntries`, which every tool reads cells with: it is not shown or found, the result says how many cells were left out, and a call that edits, moves or deletes it is refused.

## WriteCells and Evaluation

`writePlan` gives the text to `cellsFromString` once, with `after`, `before` and `delete` as the tools' own attributes and a function that reads the cell of an id when it is asked for. The plan is made from the records.

| Text | Effect |
|---|---|
| `<cell id='c3'>new content</cell>` | Replaces the content of c3. Attributes that are left out keep their values |
| `<cell id='c3' CellTags='x'/>` | Changes attributes only |
| `<cell style='Text'>...</cell>` | A new cell: after the cell before it in the text, or where `after='c5'` or `before='c1'` says, or at the end. After a cell is after its outputs, and after the cells that the call already placed there (`planAfter`) |
| `<cell id='c7' after='c2'/>` | Moves c7 as it is (with a body, it also replaces its content) |
| `<cell id='c9' delete='true'/>` | Deletes c9 |

- Everything is converted before anything is written. A text that is refused writes nothing, and the message names the cell (a new one by the number of its tag).
- **Places.** A cell that is placed after a cell of the notebook (by `after`, or by following its tag in the text) comes after that cell's outputs, the generated cells right after it, and not between the two. The cells that follow such a cell are read for that, up to the first one that is not generated. Cells that name the same place in the same way keep the order of the text: each comes after the ones that the call placed there before it. A generated cell that is moved with `after` is not put after the outputs: it goes right after the cell that `after` names, or after what the call already placed there ([Known Gaps](#known-gaps)).
- A cell that reads the same after the write is not written, so it stays the user's cell and is no change in the diff.
- The content of a generated cell (`$$generatedCellStyle`) is not written as text. The message says how to move or delete one, since a model otherwise deletes and retypes it.
- The result lists what was done and where each run of new cells is: `Wrote to s1: changed c5; new c7 (Text), c8 (Input) after c5; moved c6; deleted c4.` A cell that a tag rewrites and places is changed and moved. One that is at that place already is not moved: it is written where it is, or not at all if it also reads as before.
- A cell that an earlier WriteCells call of the chat deleted from the snapshot (`"Deleted"` of the record) has its own message, which says so and how a cell is moved: a model that deletes a cell to write it again elsewhere otherwise takes the cell for moved.
- EditInCell is the body of the cell, the replacements, and `cellsFromString` with the cell as the existing one. A count that does not fit lists the places of `oldText`. Selection markers are taken out of `oldText`.

## Snapshots, the Front End and CellDiff

- A snapshot is `` FrontEnd`NotebookSnapshot[source] ``: a hidden notebook whose cells have the ExpressionUUIDs of the source's. `$snapshots` has its record under a handle; at most `$maxSnapshots` (10) are open.
- A snapshot of an open notebook only exists while it has edits. An editing call that writes nothing closes the snapshot that it made.
- A snapshot belongs to the chat that opened it (`"ConversationUUID"`). A stale one of the same notebook is closed when another chat edits the notebook.
- A notebook that still shows a diff is not edited: the call says that the user has to resolve the changes first.
- A write names cells by their ExpressionUUIDs: `{"Replace", uuid, cell}`, `{"Insert", uuid | None, "After" | "Before", cells}`, `{"Delete", uuids}`. A written cell has its ExpressionUUID as an option, which the front end keeps, so a replaced cell keeps its id and a move is a delete and an insert.
- **A front end defect.** `NotebookGet` of a hidden notebook leaves out the cells after a cell that `NotebookWrite` wrote inside a cell group (also in the stock 16.0.0 front end). The tools never use it on a snapshot: they list cells with `Cells` and read them with `NotebookRead`.
- **CellDiff** (`Assets/CellDiff`, a copy of the FE repository's `docs/CellDiff`; do not edit it here) is loaded at the first ShowChanges. `showNotebookDiff` uses two of its forms:
  1. `ShowNotebookDiff[source, snapshot, "Lines", edited]` with the ExpressionUUIDs of the edited cells reads only the cells that changed (0.33 s for 790 cells, 0.26 s for a notebook of 57 MB).
  2. If the cells do not line up (a move, or most cells changed), CellDiff would `NotebookGet` the snapshot. That call is kept from giving the snapshot, so CellDiff fails before it writes, and ShowChanges gives it a `Notebook` expression instead (`comparedNotebook`): the snapshot's cells with their ExpressionUUIDs, the unchanged ones read from the source. A moved cell gets another ExpressionUUID and CellDiff's tag, so that it shows as deleted at the old place and inserted at the new one, and Reject All puts it back. This form hashes every cell: 1.9 s for 790 cells, 33 s for 57 MB.
- If no cell is marked afterwards, the result says that there is nothing to accept, and the notebook gets back the stylesheet and the dynamic expression that CellDiff replaced (`shownDiff`). That happens if the edits only changed cell tags, which CellDiff applies as they are, or cell labels, which it does not compare (the label stays as it was), or if the notebook already had the changes.

## Cell Ids

- `withNotebookCellSyntax[notebook, eval]` evaluates `eval` with the ids and the records of that table. It must not be nested.
- The `$maxCellTables` (20) tables that were used last are kept, for the kernel session.

## Where They Are Enabled

- `$notebookAssistanceBaseSettings` lists the tools next to NotebookReader. `"Enabled"` is `TrueQ[$WorkspaceChat || $SidebarChat] && notebookToolsSupportedQ[]`, and they are `"Hidden"`.
- `selectTools` drops them with NotebookReader when `"AllowSelectionContext"` is not `True`. `resolveTools` raises `"MaxToolResponses"` to at least 20 when one is selected.
- **The gate.** `notebookToolsSupportedQ[]` is `True` outside the cloud, on 16.0 or later, with a front end that has `` FrontEnd`NotebookSnapshot ``. The stock 16.0.0 front end lacks it. `snapshotPacketQ` probes once per session (three front end calls, about 0.25 s, normally in the assistant's warm-up) with console messages off, since a front end without the packet reports it in its Messages window.
- **Tool methods.** With the Simple method EditInCell's `edits` is marked `(JSON)` and read by `readJSONParameters`. With the hybrid method `toolRequestToString` writes a native call as a Simple call.

## Limits and Cost

| What | Value |
|---|---|
| Cells in one result (`$readBudget`) | 40,000 characters; at least one cell |
| Body of one cell (`$cellLength`) | 10,000 characters unless `full` is true |
| Outline, search (`$outlineLimit`, `$searchLimit`) | 300 cells, 50 matches by default |
| Images of one tool result (`$maxToolResponseImages`) | 5 |
| First EditInCell of a session | 0.5 to 1 s for the `CompoundElement` interpreter |
| A cell tag of WriteCells with an `id` or with `after` | One or two more reads of a cell, for the outputs of the cell that it names |

## Known Gaps

- **Stop does not stop a running tool call.** The call runs to its end, and its edits stay in the snapshot, which the next request writes to.
- **Only ShowChanges shows the edits.** If the model ends its turn without calling it, they stay in the snapshot and the user sees none of them.
- **A snapshot with edits that were not shown goes stale** if the user changes the notebook: later turns read and edit it as it is.
- **The tool acts on the notebook that is in front when it runs,** which may not be the one that the context was read from.
- **Ids are renumbered** after a kernel restart, and for the cells that a comparison writes without their ExpressionUUID: the changed cells of form 1, cells that only show a deletion, moved cells, and a cell whose tags changed.
- **The sidebar's default "Ignore notebook content" hides the tools,** and the assistant then says that it can't edit the notebook.
- **Places.** New cells for one gap that is named both with `before` and with `after` (`before='c16'` and `after='c15'`) do not keep the order of the text: the ones with `after` come first. An output that is moved with `after` lands after a cell that the same call placed there, and not right after the cell that `after` names.
- **A notebook is only known by the text of its file name** (see "File names" under [The Tools](#the-tools)).
- **A notebook that the user excludes after the chat has a snapshot of it** is still read from the snapshot and edited there. Only ShowChanges refuses.
- **A whole comparison** (form 2) has no cell groups, so closed groups are open afterwards. For a `.nb` file that is not open, moves are not marked.
- **Snapshots outlive a kernel restart** until the front end quits.
- **The diff view** (CellDiff and the front end): a tall changed cell can show no diff at all; a notebook outside the trusted directories shows "potentially unsafe dynamic content"; the toolbar, the stylesheet and the dynamic expression stay after the last change is resolved with the controls of a cell; the view jumps to the top; 2D code overlaps; a re-evaluated output is a deletion and an insertion.

## Tests

- `Tests/NotebookTools.wlt`: the tools on a made-up front end, and the real front end operations on a hidden copy (`NotebookTools-FrontEnd-*`: CellDiff after a move, an edit that marks nothing, locked and excluded cells and notebooks, an excluded notebook by its file in another letter case). The three of them that show a comparison (`-Tools`, `-Move`, `-NothingMarked`) are skipped before 16.0, where the tools are never enabled, so CI (15.0) does not run them.
