# Notebook Tools

| File | What it holds |
|---|---|
| `Source/Chatbook/Tools/NotebookTools.wl` | The tools, in their own context. It exports `$notebookToolSpecs`, `notebookToolsSupportedQ` (the gate) and the Common symbol `withNotebookCellSyntax`. |
| `Source/Chatbook/Tools/DefaultToolDefinitions/NotebookTools.wl` | Registers them as default tools: machine names, short names, icons, `"Enabled"`, `"Hidden"`. |
| `Source/Chatbook/Serialization.wl`, `CellSyntax/` | The [cell syntax](cell-syntax.md): cells to text (`CellToString` with `"IncludeXML"` and `"PreserveBoxes"`) and text to cells (`cellsFromString`). |

## The Tools

| Tool | Short name | Parameters (optional in italics) | What it does |
|---|---|---|---|
| ListNotebooks | `nb_list` | none | The open notebooks, front to back, and the chat's snapshots, as JSON |
| OpenNotebook | `nb_open` | *`notebook`* | Reads a listed notebook (its id, window title or file) as it is, or opens a snapshot of a `.nb` file that is not open, or of a new notebook. Gives a line about it and its cells, or an outline if they don't fit into the read budget |
| GetOutline | `nb_outline` | *`notebook`*, *`offset`*, *`limit`* | A line per cell: `c12 (Input) the start of its content` |
| ReadCells | `nb_cells` | *`notebook`*, *`cells`*, *`full`* | Cells in the cell syntax (`cells`: ids, ranges such as `c10-c20`, or `all`) |
| SearchNotebook | `nb_find` | `query`, *`notebook`*, *`regex`*, *`cells`*, *`styles`*, *`limit`* | A line per match in the bodies: `c12 (Input) 3:14: the line` |
| CloseNotebook | `nb_close` | *`notebook`* | Closes a snapshot and discards its edits |

- A tool's function takes the arguments as an Association and gives a string, or `<|"Result" -> Failure["NotebookToolError", ...], "String" -> text|>`, whose `"String"` Chatbook sends to the model. For an internal failure the model only learns that the tool failed.

## Snapshots, the Front End and CellDiff

- A snapshot is `` FrontEnd`NotebookSnapshot[source] ``: a hidden notebook whose cells have the ExpressionUUIDs of the source's. `$snapshots` has its record under a handle; at most `$maxSnapshots` (10) are open.

## Cell Ids

- `withNotebookCellSyntax[notebook, eval]` evaluates `eval` with the ids and the records of that table. It must not be nested.
- The `$maxCellTables` (20) tables that were used last are kept, for the kernel session.

## Where They Are Enabled

- `$notebookAssistanceBaseSettings` lists the tools next to NotebookReader. `"Enabled"` is `TrueQ[$WorkspaceChat || $SidebarChat] && notebookToolsSupportedQ[]`, and they are `"Hidden"`.
- `selectTools` drops them with NotebookReader when `"AllowSelectionContext"` is not `True`. `resolveTools` raises `"MaxToolResponses"` to at least 20 when one is selected.
- **The gate.** `notebookToolsSupportedQ[]` is `True` outside the cloud, on 16.0 or later, with a front end that has `` FrontEnd`NotebookSnapshot ``. The stock 16.0.0 front end lacks it. `snapshotPacketQ` probes once per session (three front end calls, about 0.25 s, normally in the assistant's warm-up) with console messages off, since a front end without the packet reports it in its Messages window.

## Limits and Cost

| What | Value |
|---|---|
| Cells in one result (`$readBudget`) | 40,000 characters; at least one cell |
| Body of one cell (`$cellLength`) | 10,000 characters unless `full` is true |
| Outline, search (`$outlineLimit`, `$searchLimit`) | 300 cells, 50 matches by default |
| Images of one tool result (`$maxToolResponseImages`) | 5 |

## Known Gaps

- **The tool acts on the notebook that is in front when it runs,** which may not be the one that the context was read from.
- **Snapshots outlive a kernel restart** until the front end quits.
