(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`NotebookTools`" ];

HoldComplete[
    `$notebookToolSpecs,
    `notebookToolsSupportedQ
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* The notebook editing tools of the AI Assistant (window and sidebar), which docs/notebook-tools.md describes.
   $notebookToolSpecs gives their specifications, which Tools/DefaultToolDefinitions/NotebookTools.wl registers as
   default tools. This file has its own context for its helpers. A name that CommonSymbols.wl declares is the shared
   symbol here too (cellStyles, chatExcludedQ), so no helper has such a name: beginDefinition would clear the shared
   function.

   * The model never edits the user's notebooks. The tools read an open notebook as it is. For the first edit the
     front end makes a hidden snapshot of it, which the tools then read and write, and ShowChanges shows the user their
     notebook as a comparison against it (CellDiff).
   * Cells are text in the cell syntax of docs/cell-syntax.md, which the kernel reads and writes: CellToString with
     "IncludeXML" and "PreserveBoxes", and cellsFromString. The front end only gives and takes cell expressions.
   * What is done with a notebook goes through notebookFrontEnd. Which notebooks there are comes from listedNotebooks,
     userNotebook and excludedFileQ. Tests replace the first three with a made-up front end.
   * A cell has one id in a chat, in the notebook context and in the tools (withNotebookCellSyntax).
   * A tool's function takes the arguments as an Association and gives a String, or <| "Result" -> Failure[
     "NotebookToolError", ... ], "String" -> an error text for the model |>. For an internal failure the model only
     learns that the tool failed. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$idLength         = 8;     (* characters of a notebook id *)
$minPrefixLength  = 6;     (* the shortest start of a notebook id that is accepted *)
$previewLength    = 80;    (* characters of a cell in an outline *)
$outlineLimit     = 300;   (* cells in one outline by default *)
$maxOutlineLimit  = 2000;  (* at most *)
$readBudget       = 40000; (* characters of cells in one result (at least one cell is shown) *)
$cellLength       = 10000; (* characters of the body of one cell in a result, unless the whole cell is asked for *)
$searchLimit      = 50;    (* matches that SearchNotebook shows by default *)
$maxSearchLimit   = 500;   (* at most *)
$searchTimeLimit  = 10;    (* seconds that one search may take *)
$snippetLength    = 160;   (* characters of the line of a match that SearchNotebook shows *)
$maxQuotedLength  = 80;    (* characters of an argument that an error message repeats *)
$maxPlaces        = 12;    (* places of a text in a cell that an error message lists *)
$outputLength     = 500;   (* characters of what the evaluator printed for one cell that a result shows *)
$maxSnapshots     = 10;    (* snapshots open at a time (they are hidden notebooks in the front end) *)
$maxCellTables    = 20;    (* tables of cell ids that are kept: one for each chat and notebook *)

(* Whether the names of files are compared without regard to letter case, as the file systems of Windows and macOS
   compare them. Not a value of its own: the MX is built on another system. *)
$ignoreFileCase := $OperatingSystem =!= "Unix";

(* The function of CellDiff's notebook comparison (Assets/CellDiff/CellDiffNotebookDiff.wl, see notebookDiffFunction),
   and the cell tag that it gives every cell that shows a change *)
$notebookDiffFunction = "CellDiffNotebookDiff`ShowNotebookDiff";
$diffTag              = "NotebookDiff";

$toolErrorTag = "Wolfram`Chatbook`Tools`NotebookTools`ToolError";
$writeTag     = "Wolfram`Chatbook`Tools`NotebookTools`Write";

(* The attributes of a cell tag that are WriteCells' own: cellsFromString gives them back as it finds them *)
$writeAttributes = { "after", "before", "delete" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*State*)

(* Not reset if this file is loaded again. In the MX build they start out empty.
     $snapshots      handle -> the record of a snapshot (notebookRecord); at most $maxSnapshots
     $snapshotCount  the number of the last handle
     $cellTables     { chat, notebook } -> <| "IDs" -> <| ExpressionUUID -> "c1", ... |>, "Next" -> the next number,
                     "Originals" -> what reading recorded for each id ($cellOriginals), "Seen" -> the ids of the cells
                     whose whole body the model was given (seeCells) |>; the one used last is the last one, and at
                     most $maxCellTables are kept
   Known edge case: the snapshots are hidden notebooks in the front end, which outlive a kernel restart (this state
   does not); they stay open, unused, until the front end quits, which deletes their files. *)
If[ ! AssociationQ @ $snapshots, $snapshots = <| |> ];
If[ ! IntegerQ @ $snapshotCount, $snapshotCount = 0 ];
If[ ! AssociationQ @ $cellTables, $cellTables = <| |> ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tools*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookToolsSupportedQ*)

(* Whether the notebook tools can work in this session: in a desktop kernel of 16.0+ whose front end makes snapshots
   (FrontEnd`NotebookSnapshot). The kernel's version alone is not enough: the stock 16.0.0 front end lacks the packet.
   Checked whenever tools are selected (the tools' "Enabled"), so the front end is probed only once per session. Not
   memoized as a whole: the MX is built on 15.0 without a front end. *)
notebookToolsSupportedQ // beginDefinition;

notebookToolsSupportedQ[ ] := And[
    ! TrueQ @ $CloudEvaluation,
    sufficientVersionQ[ 16.0 ],
    $FrontEnd =!= Null,
    snapshotPacketQ[ ]
];

notebookToolsSupportedQ // endDefinition;


(* Probed once per session, at run time only (never while the MX is built, so that no value is saved in it) *)
snapshotPacketQ // beginDefinition;

snapshotPacketQ[ ] :=
    If[ TrueQ @ Wolfram`ChatbookInternal`$BuildingMX,
        False,
        snapshotPacketQ[ ] = snapshotPacketProbe[ ]
    ];

snapshotPacketQ // endDefinition;


(* A front end with the packet answers $Failed to a NotebookSnapshot call without its argument; one without it answers
   Null and reports the unknown packet in its Messages window, which pops up, so console messages are turned off for
   this front end session while it is probed (three front end calls, once per session). The session's own setting is
   Inherited afterwards (an edge case: a session-level ConsoleMessageAction someone set is not kept). *)
snapshotPacketProbe // beginDefinition;

snapshotPacketProbe[ ] := Internal`WithLocalSettings[
    CurrentValue[ $FrontEndSession, { MessageOptions, "ConsoleMessageAction" } ] = { },
    Quiet @ MathLink`CallFrontEnd @ FrontEnd`NotebookSnapshot[ ] === $Failed,
    CurrentValue[ $FrontEndSession, { MessageOptions, "ConsoleMessageAction" } ] = Inherited
];

snapshotPacketProbe // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Descriptions*)

(* Every request of a chat that has the tools carries these texts and the help of the parameters, so they are short.
   How to read the cell syntax is a base prompt component ("CellSyntax" in Prompting.wl), and how to write it is in
   WriteCells' description. NotebookReader's description is also sent to chats without these tools, so what tells the
   two readers apart is said in ReadCells' description. *)
$listNotebooksDescription = "\
Lists the user's open notebooks, front to back, and this chat's snapshots, as JSON {notebooks: [{id, title, file, \
modified, cells, current, snapshot}], snapshots: [{notebook, title, source, edited}]}. current marks the notebook the \
user is working in.";

$openNotebookDescription = "\
Reads a notebook other than the user's: an open notebook or a .nb file, or without notebook a new, empty one. Gives \
its cells (an outline if they are many) and its name for the other tools: the id of an open notebook, or the handle \
(s1, s2, ...) of the hidden snapshot that a file or a new notebook is opened as.";

$getOutlineDescription = "\
Gives one line for each cell of a notebook: its id, its style and the start of its content. A long notebook comes in \
parts (offset, limit).";

$readCellsDescription = "\
Reads cells of a notebook in the cell syntax: the given ones, or all. A long cell is cut (truncated='true') unless \
full is true. Cells that the notebook context or NotebookReader showed have the same ids and text here and need not \
be read again. NotebookReader shows where the user's selection is now; ReadCells reads given cells, in any notebook.";

$searchNotebookDescription = "\
Finds text in the cells of a notebook: a literal string, or with regex true a regular expression (PCRE), in each \
cell's content as ReadCells shows it. Gives one line per match: id (style) line:column: the line.";

$editInCellDescription = "\
Edits the content of one cell by exact text replacement: each edit replaces oldText, which must occur exactly count \
times (default 1) in the cell's content, with newText. The cell's id and text can be taken directly from the \
notebook context, NotebookReader or ReadCells. The edits apply in order, all or none, in a hidden snapshot (see \
ShowChanges). Gives the cell as it now reads.";

$writeCellsDescription = "\
Writes cells of a notebook, in a hidden snapshot (see ShowChanges). cells is cell tags in the cell syntax and \
nothing else, with the cell ids of the notebook context, NotebookReader and ReadCells. \
<cell id='c3'>new content</cell> replaces the content of c3: keep its <RawBoxes> and links as they are, and read a \
cell that you have not seen whole first. <cell id='c3' CellTags=''/> changes attributes only: those you leave out \
keep their values, and an empty one is removed. <cell style='Text' after='c5'>...</cell> is a new cell after c5 (or \
before='c1'; these are attributes of the tag, not parameters). Without them it comes after the cell before it in \
cells, or at the end. <cell id='c5'/> changes nothing: it marks a place, or names a cell for evaluate. \
<cell id='c7' before='c2'/> moves c7 as it is: never delete and rewrite a cell to move it. \
<cell id='c9' delete='true'/> deletes it. In a text cell, math is $$...$$ (in a code cell it is code; a displayed \
formula is <cell style='DisplayFormula'>$$...$$</cell>), <MakeBoxes>expr</MakeBoxes> typesets an expression in place \
without evaluating it and <ToBoxes>expr</ToBoxes> evaluates it first. Outputs are never written by hand: \
evaluate: true evaluates the code cells this call writes or names and replaces their outputs. All of it applies or \
nothing does. Gives the ids of the cells it wrote and where the new ones are.";

$showChangesDescription = "\
Shows the user the edits of this chat: their notebook as a diff against the hidden snapshot that the edits went to, \
where they accept or reject each change. Closes the snapshot. Always call it once when your edits are done, before \
your final reply. It needs no permission from the user, who sees none of your edits until it is called.";

$closeNotebookDescription = "Closes a snapshot and discards its edits, without showing them to the user.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Parameters*)
parameter // beginDefinition;

parameter[ name_String, interpreter_, help_String ] := parameter[ name, interpreter, help, False ];

parameter[ name_String, interpreter_, help_String, required_ ] :=
    name -> <| "Interpreter" -> interpreter, "Help" -> help, "Required" -> required |>;

parameter // endDefinition;

(* What the reading and editing tools take as notebook, and what ShowChanges and CloseNotebook take *)
$notebookParameter = parameter[
    "notebook",
    "String",
    "A notebook id or snapshot handle, e.g. s1 (default: the open snapshot, else the user's notebook)"
];

$snapshotParameter = parameter[ "notebook", "String", "A snapshot handle, e.g. s1 (default: the open snapshot)" ];

$cellsParameter = parameter[ "cells", "String", "Cell ids and ranges, e.g. \"c3, c10-c20\" (default: all cells)" ];

$evaluateParameter = parameter[
    "evaluate",
    "Boolean",
    "Evaluate the code cells this call writes and replace their outputs (default false)"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Specifications*)

(* The function of a tool: LLMTool gives it the arguments as an Association *)
toolFunction // beginDefinition;
toolFunction[ name_String, function_ ] := toolResult[ name, function @ toolArguments @ # ] &;
toolFunction // endDefinition;

(* The tools' specifications, in the order the tools are listed (Tools/DefaultToolDefinitions/NotebookTools.wl adds
   Chatbook's keys). Required parameters come first: the Simple tool method reads values without names in this order.
   It splits a value of several lines where a line starts with the name of a parameter, which is why WriteCells has
   few parameters. LLMTool interprets EditInCell's edits with Interpreter, whose first CompoundElement interpretation
   in a session takes about 0.5-1 s: that comes with the first such call, after the first token. *)
$notebookToolSpecs = <|
    "ListNotebooks" -> <|
        "DisplayName" -> "List Notebooks",
        "Description" -> $listNotebooksDescription,
        "Function"    -> toolFunction[ "ListNotebooks", listNotebooks ],
        "Parameters"  -> { }
    |>,
    "OpenNotebook" -> <|
        "DisplayName" -> "Open Notebook",
        "Description" -> $openNotebookDescription,
        "Function"    -> toolFunction[ "OpenNotebook", openNotebook ],
        "Parameters"  -> {
            parameter[
                "notebook",
                "String",
                "An open notebook (its id, window title or file) or the path of a .nb file (default: a new notebook)"
            ]
        }
    |>,
    "GetOutline" -> <|
        "DisplayName" -> "Get Outline",
        "Description" -> $getOutlineDescription,
        "Function"    -> toolFunction[ "GetOutline", getOutline ],
        "Parameters"  -> {
            $notebookParameter,
            parameter[ "offset", "Integer", "The number of the first cell (default 1)" ],
            parameter[ "limit", "Integer", "The largest number of cells (default 300)" ]
        }
    |>,
    "ReadCells" -> <|
        "DisplayName" -> "Read Cells",
        "Description" -> $readCellsDescription,
        "Function"    -> toolFunction[ "ReadCells", readCells ],
        "Parameters"  -> {
            $notebookParameter,
            $cellsParameter,
            parameter[ "full", "Boolean", "Show long cells whole (default false)" ]
        }
    |>,
    "SearchNotebook" -> <|
        "DisplayName" -> "Search Notebook",
        "Description" -> $searchNotebookDescription,
        "Function"    -> toolFunction[ "SearchNotebook", searchNotebook ],
        "Parameters"  -> {
            parameter[ "query", "String", "The text to find, or a regular expression with regex true", True ],
            $notebookParameter,
            parameter[ "regex", "Boolean", "Whether query is a regular expression (default false)" ],
            $cellsParameter,
            parameter[ "styles", "String", "Cell styles to search, e.g. \"Input, Text\" (default: all styles)" ],
            parameter[ "limit", "Integer", "The largest number of matches to show (default 50)" ]
        }
    |>,
    "EditInCell" -> <|
        "DisplayName" -> "Edit In Cell",
        "Description" -> $editInCellDescription,
        "Function"    -> toolFunction[ "EditInCell", editInCell ],
        "Parameters"  -> {
            parameter[ "cell", "String", "The id of the cell, e.g. c3", True ],
            parameter[
                "edits",
                RepeatingElement @ CompoundElement @ <| "oldText" -> "String", "newText" -> "String", "count" -> "Integer" |>,
                "A JSON array of {oldText, newText, count}, e.g. [{\"oldText\": \"x^2\", \"newText\": \"x^3\"}]",
                True
            ],
            $notebookParameter,
            $evaluateParameter
        }
    |>,
    "WriteCells" -> <|
        "DisplayName" -> "Write Cells",
        "Description" -> $writeCellsDescription,
        "Function"    -> toolFunction[ "WriteCells", writeCells ],
        "Parameters"  -> {
            parameter[ "cells", "String", "The cells, as cell tags in the cell syntax", True ],
            $notebookParameter,
            $evaluateParameter
        }
    |>,
    "ShowChanges" -> <|
        "DisplayName" -> "Show Changes",
        "Description" -> $showChangesDescription,
        "Function"    -> toolFunction[ "ShowChanges", showChanges ],
        "Parameters"  -> { $snapshotParameter }
    |>,
    "CloseNotebook" -> <|
        "DisplayName" -> "Close Notebook",
        "Description" -> $closeNotebookDescription,
        "Function"    -> toolFunction[ "CloseNotebook", closeNotebook ],
        "Parameters"  -> { $snapshotParameter }
    |>
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Results and Errors*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolResult*)

(* The result of a tool: the text that eval gives, or an error result (toolFailure) for an error text thrown by
   toolError or for an internal failure (Chatbook's failures are caught by catchAlways). Aborts are not caught: the
   caller decides what an aborted tool call gives. *)
toolResult // beginDefinition;
toolResult // Attributes = { HoldRest };

toolResult[ name_String, eval_ ] := Replace[
    Catch[ catchAlways @ eval, $toolErrorTag, toolFailure @ #1 & ],
    {
        text_String            :> text,
        failure: $$toolFailure :> failure,
        _                      :> toolFailure[ "The " <> name <> " tool failed because of an internal error in Chatbook." ]
    }
];

toolResult // endDefinition;

$$toolFailure = KeyValuePattern @ { "Result" -> Failure[ "NotebookToolError", _Association ], "String" -> _String };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolFailure*)

(* An error result: Chatbook gives the model the "String" (as for FileReader's errors); the message template of the
   Failure only shows the text as it is *)
toolFailure // beginDefinition;

toolFailure[ message_String ] := <|
    "Result" -> Failure[ "NotebookToolError", <| "MessageTemplate" -> "`1`", "MessageParameters" -> { message } |> ],
    "String" -> message
|>;

toolFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolError*)

(* Ends the tool with an error text for the model; template slots `1`, `2`, ... are filled with the arguments *)
toolError // beginDefinition;
toolError[ message_String ] := Throw[ message, $toolErrorTag ];
toolError[ template_String, args__ ] := toolError @ TemplateApply[ StringTemplate @ template, { args } ];
toolError // endDefinition;


(* An argument of the model in an error message: quoted, and shortened if it is long *)
quoted // beginDefinition;
quoted[ s_String ] := StringJoin[
    "\"",
    If[ StringLength @ s > $maxQuotedLength, StringTake[ s, $maxQuotedLength ] <> "...", s ],
    "\""
];
quoted[ other_ ] := quoted @ ToString[ other, InputForm ];
quoted // endDefinition;


requireFrontEnd // beginDefinition;

requireFrontEnd[ ] := If[ $FrontEnd === Null,
    toolError[ "The Wolfram front end is not available in this kernel, so its notebooks can't be reached." ]
];

requireFrontEnd // endDefinition;


(* The message of a Failure as plain text: its template with its parameters (Failure's own "Message" formats them as
   boxes). The first parameter of a failure of evaluateToBoxes is what it is about: name is put in its place. *)
failureMessage // beginDefinition;

failureMessage[ Failure[ tag_, data: KeyValuePattern[ "MessageParameters" -> { _, rest___ } ] ], name_String ] :=
    failureMessage @ Failure[ tag, <| data, "MessageParameters" -> { name, rest } |> ];

failureMessage[ failure_, _ ] := failureMessage @ failure;

failureMessage[ Failure[ _, KeyValuePattern @ { "MessageTemplate" -> template_String, "MessageParameters" -> parameters: { __ } } ] ] :=
    Replace[ Quiet @ TemplateApply[ StringTemplate @ template, parameters ], Except[ _String ] -> template ];

failureMessage[ Failure[ _, KeyValuePattern[ "MessageTemplate" -> template_String ] ] ] := template;
failureMessage[ _ ] := "";

failureMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Arguments*)

(* LLMTool interprets the values. The Simple tool method gives "" for the optional parameters a call leaves out, and
   LLMTool Missing["NoInput"]: those are left out here (no parameter takes "" as a value). *)
toolArguments // beginDefinition;
toolArguments[ args_Association ] := Select[ args, ! MissingQ @ # && (! StringQ @ # || StringTrim @ # =!= "") & ];
toolArguments // endDefinition;


missingArgument // beginDefinition;
missingArgument[ name_String ] := toolError[ "The parameter `1` is missing or empty.", name ];
missingArgument // endDefinition;


(* A required string argument, trimmed *)
stringArgument // beginDefinition;
stringArgument[ s_String, _String ] := StringTrim @ s;
stringArgument[ _, name_String ] := missingArgument @ name;
stringArgument // endDefinition;


(* A positive whole number, or the default if it is not given *)
countArgument // beginDefinition;
countArgument[ _Missing, _String, default_Integer ] := default;
countArgument[ n_Integer? Positive, _String, _ ] := n;
countArgument[ other_, name_String, _ ] :=
    toolError[ "The parameter `1` must be a positive whole number, not `2`.", name, quoted @ other ];
countArgument // endDefinition;


booleanArgument // beginDefinition;
booleanArgument[ _Missing, _String ] := False;
booleanArgument[ b: True | False, _String ] := b;
booleanArgument // endDefinition;


(* The items of a list argument (cell ids, styles): separated by commas or semicolons (for cell ids also white space);
   brackets and quotes (a JSON array given as a string) are ignored. LLMTool lets a list of strings through for a
   string (the JSON array of a native call), which is the same items. *)
listArgument // beginDefinition;

listArgument[ s_String, separators_ ] := DeleteDuplicates @ Select[
    StringTrim @ StringSplit[ s, (separators | "[" | "]" | "\"" | "'" | "`").. ],
    # =!= "" &
];

listArgument[ items: { ___String }, separators_ ] := listArgument[ StringRiffle[ items, "," ], separators ];

listArgument // endDefinition;


(* EditInCell's edits as { { oldText, newText, count }, ... }. The notebook context shows the markers of a selection in
   a body. No body has them as it is read, so they are taken out of oldText. What a marker in newText is, the writer
   decides (docs/cell-syntax.md). *)
editsArgument // beginDefinition;

editsArgument[ edits: { __Association } ] := MapIndexed[ editArgument[ #1, First @ #2 ] &, edits ];

editsArgument[ _ ] :=
    toolError[ "The parameter edits must be a list of edits {oldText, newText, count}, e.g. [{\"oldText\": \"a\", \"newText\": \"b\"}]." ];

editsArgument // endDefinition;


editArgument // beginDefinition;

editArgument[ edit_Association, i_Integer ] := With[
    {
        old = Replace[ edit[ "oldText" ], s_String :> StringDelete[ s, $leftSelectionIndicator | $rightSelectionIndicator ] ],
        new = edit[ "newText" ]
    },
    If[ ! StringQ @ old || old === "",
        toolError[ "Edit `1` has no oldText. To insert text, give the text next to it as oldText and both as newText.", i ]
    ];
    If[ ! StringQ @ new, toolError[ "Edit `1` has no newText (\"\" deletes oldText).", i ] ];
    { old, new, countArgument[ Lookup[ edit, "count", Missing[ ] ], "count", 1 ] }
];

editArgument // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Front End*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookFrontEnd*)

(* What the tools do with a notebook in the front end (tests replace this function with a made-up front end):
     notebookFrontEnd[ "Snapshot", source ]                   the hidden snapshot's NotebookObject, or $Failed; source: a
                                                              NotebookObject, a file or None. Its cells have the
                                                              ExpressionUUIDs of the source's.
     notebookFrontEnd[ "Excluded", nb ]                       whether the notebook's own settings exclude it from chats
                                                              (a snapshot of a file has the settings of the file)
     notebookFrontEnd[ "Cells", nb ]                          its cells in order: { CellObject[ uuid, ... ], ... }
     notebookFrontEnd[ "Cells", nb, style ]                   those of them that have the style
     notebookFrontEnd[ "Read", nb, { cell, ... } ]            their Cell expressions
     notebookFrontEnd[ "Locks", nb, { cell, ... } ]           { Editable, Deletable } of each cell, as the front end
                                                              resolves them
     notebookFrontEnd[ "Write", nb, { write, ... } ]          applies the writes in order; $Failed if one can't be applied.
                                                              Cells are named by their ExpressionUUIDs:
                                                                { "Replace", uuid, Cell[ ... ] }
                                                                { "Insert", uuid | None, "After" | "Before", { Cell[ ... ], ... } }
                                                                { "Delete", { uuid, ... } }
                                                              A cell that is written has its ExpressionUUID as an option,
                                                              which the front end keeps (a move is a "Delete" and an
                                                              "Insert" of the cell). None stands for an empty notebook.
     notebookFrontEnd[ "Close", nb ]                          closes the snapshot; the front end deletes its file
     notebookFrontEnd[ "DiffCells", nb ]                      the cells of a notebook that show a change of a comparison
                                                              that the user has not resolved ({ } for none)
     notebookFrontEnd[ "ShowDiff", source, snapshot, edited ] shows the source as a comparison against the snapshot,
                                                              of which only the cells that changed are read. Gives the
                                                              number of cells that then show a change, or
                                                              Failure[ "InvalidSnapshot", ... ] if the comparison takes
                                                              all of the snapshot's cells (showNotebookDiff).
     notebookFrontEnd[ "ShowDiff", source, notebook ]         the same against a Notebook expression. A source None is
                                                              a new notebook, which is shown as it is.
   The writes of one call are applied one after another, so a failure of the front end in one of them leaves the ones
   before it applied. The model's text is converted and checked before the first write, which leaves little to fail.
   NotebookGet is not used on a snapshot: for a hidden notebook it leaves out the cells after a cell that NotebookWrite
   wrote inside a cell group (a front end defect, also of 16.0.0). *)
notebookFrontEnd // beginDefinition;

notebookFrontEnd[ "Snapshot", source_ ] :=
    Quiet @ MathLink`CallFrontEnd @ FrontEnd`NotebookSnapshot @ source;

notebookFrontEnd[ "Excluded", nb_NotebookObject ] :=
    chatExcludedQ @ Quiet @ AbsoluteCurrentValue[ nb, { TaggingRules, "ChatNotebookSettings" } ];

notebookFrontEnd[ "Cells", nb_NotebookObject ] := Quiet @ Cells @ nb;
notebookFrontEnd[ "Cells", nb_NotebookObject, style_ ] := Quiet @ Cells[ nb, CellStyle -> style ];
notebookFrontEnd[ "Read", _NotebookObject, cells: { __CellObject } ] := Quiet @ NotebookRead @ cells;

notebookFrontEnd[ "Locks", _NotebookObject, cells: { __CellObject } ] :=
    Quiet @ Transpose @ { AbsoluteCurrentValue[ cells, Editable ], AbsoluteCurrentValue[ cells, Deletable ] };

notebookFrontEnd[ "Write", nb_NotebookObject, writes_List ] :=
    Quiet @ Catch[ Scan[ frontEndWrite[ nb, # ] &, writes ], $writeTag ];

notebookFrontEnd[ "Close", nb_NotebookObject ] := Quiet @ NotebookClose @ nb;
notebookFrontEnd[ "DiffCells", nb_NotebookObject ] := Quiet @ Cells[ nb, CellTags -> $diffTag ];
notebookFrontEnd[ "ShowDiff", source_, snapshot_NotebookObject, edited_List ] := showNotebookDiff[ source, snapshot, edited ];
notebookFrontEnd[ "ShowDiff", source_, notebook_Notebook ] := showNotebookDiff[ source, notebook ];

notebookFrontEnd // endDefinition;


frontEndWrite // beginDefinition;

frontEndWrite[ nb_, { "Replace", uuid_String, cell_Cell } ] := NotebookWrite[ uuidCell[ nb, uuid ], cell ];
frontEndWrite[ nb_, { "Delete", uuids: { __String } } ] := NotebookDelete[ uuidCell[ nb, # ] & /@ uuids ];

frontEndWrite[ nb_, { "Insert", anchor_, position: "After" | "Before", cells: { __Cell } } ] := (
    If[ StringQ @ anchor,
        SelectionMove[ uuidCell[ nb, anchor ], Symbol @ position, Cell ],
        SelectionMove[ nb, After, Notebook ]
    ];
    NotebookWrite[ nb, cells ]
);

frontEndWrite // endDefinition;


(* A write gives a cell another CellObject, so the cell of an ExpressionUUID is looked up for each write *)
uuidCell // beginDefinition;
uuidCell[ nb_NotebookObject, uuid_String ] := FirstCase[ Cells @ nb, CellObject[ uuid, ___ ], Throw[ $Failed, $writeTag ] ];
uuidCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*showNotebookDiff*)

(* Shows a source (an open notebook, or a file) as a comparison, in the notebook itself.
   - CellDiff's ShowNotebookDiff[ source, snapshot, "Lines", edited ] reads only the cells that changed: the edited
     ones, and those that only one of the two notebooks has (it knows them by their ExpressionUUIDs). That takes the
     same time for a small notebook and for one with a gigabyte of graphics. If the cells do not line up (cells moved,
     or most cells changed), it compares the whole notebooks instead and would NotebookGet the snapshot, which gives a
     wrong notebook (see notebookFrontEnd). NotebookGet is kept from giving the snapshot, so CellDiff then gives
     Failure[ "InvalidSnapshot", ... ], before it has written anything.
   - ShowNotebookDiff[ source, notebook, "Lines" ] compares the whole source against a Notebook expression, whose
     cells it pairs with the source's by their ExpressionUUIDs. It hashes every cell of both: 1.8 s for 790 cells, and
     33 s for a notebook of 57 MB.
   A new notebook has nothing to compare with: its content is shown as a notebook. *)
showNotebookDiff // beginDefinition;

showNotebookDiff[ source_, snapshot_NotebookObject, edited_List ] := shownDiff[
    source,
    Function[ notebook,
        Internal`InheritedBlock[ { NotebookGet },
            Unprotect @ NotebookGet;
            PrependTo[ DownValues @ NotebookGet, HoldPattern @ NotebookGet[ snapshot, ___ ] :> $Failed ];
            Protect @ NotebookGet;
            notebookDiffFunction[ ][ notebook, snapshot, "Lines", edited ]
        ]
    ]
];

showNotebookDiff[ None, notebook_Notebook ] := NotebookPut @ notebook;
showNotebookDiff[ source_, notebook_Notebook ] := shownDiff[ source, notebookDiffFunction[ ][ #, notebook, "Lines" ] & ];

showNotebookDiff // endDefinition;


(* What show gives for the notebook of a source, if that is a Failure, and else the number of cells that show a change
   afterwards. A file is opened here, so that the options of its notebook are known before the comparison.
   CellDiff marks no cell if the edits only changed cell tags, which it applies as they are, or cell labels, which
   it does not compare, or if the notebook already had the changes. There is then no toolbar that would give the
   notebook its stylesheet and its dynamic expression back, as Accept All and Reject All do, so that is done here. *)
shownDiff // beginDefinition;

shownDiff[ source_, show_ ] := Module[ { notebook, options, result, marked },
    notebook = Replace[ source, file_String /; FileExistsQ @ file :> NotebookOpen @ file ];
    options  = If[ MatchQ[ notebook, _NotebookObject ], Options[ notebook, { StyleDefinitions, NotebookDynamicExpression } ], { } ];
    result   = show @ notebook;
    If[ ! MatchQ[ result, _NotebookObject ], Return[ result, Module ] ];
    marked = Length @ Cells[ result, CellTags -> $diffTag ];
    If[ marked === 0, SetOptions[ result, options ] ];
    marked
];

shownDiff // endDefinition;


(* The files in Assets/CellDiff (CellDiffNotebookDiff.wl, which loads CellDiffControlStyles.wl from its own directory)
   are copied from the FE repository's docs/CellDiff (as of its commit cb4e2cdb163) until the front end ships
   the comparison; keep them in sync. They are loaded once per session, at the first ShowChanges, with their contexts
   kept off $ContextPath; the function is kept only once it is defined. *)
notebookDiffFunction // beginDefinition;

notebookDiffFunction[ ] := Module[ { file },
    file = FileNameJoin @ { $thisPaclet[ "AssetLocation", "CellDiff" ], "CellDiffNotebookDiff.wl" };
    If[ ! FileExistsQ @ file, toolError[ "ShowChanges is not available: the notebook comparison was not found." ] ];
    Quiet @ Block[ { $ContextPath = $ContextPath }, Get @ file ];
    If[ Names @ $notebookDiffFunction === { },
        toolError[ "ShowChanges is not available: the notebook comparison could not be loaded." ]
    ];
    notebookDiffFunction[ ] = Symbol @ $notebookDiffFunction
];

notebookDiffFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebooks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Notebook ids*)

(* The id of a notebook: the start of its UUID. Known edge case: notebooks with the same id (a notebook file that is
   open twice) can only be opened by their titles or files. *)
notebookID // beginDefinition;
notebookID[ NotebookObject[ uuid_String, ___ ] ] := ToLowerCase @ StringTake[ uuid, UpTo @ $idLength ];
notebookID[ nbo_NotebookObject ] := IntegerString[ Hash @ nbo, 16 ];
notebookID // endDefinition;


(* A name as the model may give it: without white space and quotes around it *)
cleanName // beginDefinition;
cleanName[ s_String ] := StringTrim[ s, (WhitespaceCharacter | "\"" | "'" | "`").. ];
cleanName // endDefinition;


(* An id as the model may give it: a clean name in lower case (UUIDs are) *)
cleanID // beginDefinition;
cleanID[ s_String ] := ToLowerCase @ cleanName @ s;
cleanID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*listedNotebooks*)

(* The notebooks that the tools can reach, front to back, each as <| "NotebookObject", "ID", "Title", "File",
   "Modified" |> ("Title" and "File" are None if not known): the "Included" notebooks of
   SourceNotebookObjectInformation[ ], without help pages, the Messages window and deployed notebooks. A notebook that
   the user excluded from chats is not "Included". *)
listedNotebooks // beginDefinition;

listedNotebooks[ ] := If[ $FrontEnd === Null, { }, Enclose[
    Module[ { messages, info, deployed },
        messages = MessagesNotebook[ ];
        info = Select[
            ConfirmMatch[ SourceNotebookObjectInformation[ ], { ___Association }, "Information" ],
            TrueQ @ #[ "Included" ] && #[ "DocumentType" ] =!= "Help" && #[ "NotebookObject" ] =!= messages &
        ];
        deployed = If[ info === { }, { }, AbsoluteCurrentValue[ Lookup[ info, "NotebookObject" ], Deployed ] ];
        ConfirmAssert[ ListQ @ deployed && Length @ deployed === Length @ info, "Deployed" ];
        notebookEntry /@ Pick[ info, TrueQ /@ deployed, False ]
    ],
    throwInternalFailure
] ];

listedNotebooks // endDefinition;


notebookEntry // beginDefinition;

notebookEntry[ info_Association ] := <|
    "NotebookObject" -> info[ "NotebookObject" ],
    "ID"             -> notebookID @ info[ "NotebookObject" ],
    "Title"          -> Replace[ Lookup[ info, "WindowTitle", None ], Except[ _String ] -> None ],
    "File"           -> Replace[ Lookup[ info, "FileName", None ], Except[ _String ] -> None ],
    "Modified"       -> TrueQ @ Lookup[ info, "ModifiedInMemory", False ]
|>;

notebookEntry // endDefinition;


(* Whether a file is open in a notebook that the user excluded from chats: one that
   SourceNotebookObjectInformation[ ] gives without "Included", which that setting alone does. It is not listed, so
   without this test its file would be opened as any other file. *)
excludedFileQ // beginDefinition;

excludedFileQ[ file_String ] := AnyTrue[
    SourceNotebookObjectInformation[ ],
    ! TrueQ @ #[ "Included" ] && sameFileQ[ Lookup[ #, "FileName", None ], file ] &
];

excludedFileQ // endDefinition;

$excludedNotebookText = "`1` is a notebook that the user excluded from AI chats, so it is not read or edited.";


(* The notebook that the chat's notebook context is taken from (what NotebookReader reads), or None *)
userNotebook // beginDefinition;

userNotebook[ ] := Replace[
    Quiet @ catchAlways @ contextNotebook @ Replace[ $ChatHandlerData[ "ChatNotebookSettings" ], Except[ _Association ] -> <| |> ],
    { { nbo_NotebookObject, _ } :> nbo, _ -> None }
];

userNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*openSource*)

(* What a snapshot is made of: <| "Source" -> a listed NotebookObject, a .nb file or None, "SourceID", "Title" |>, or
   None if nothing has the name (a clean one, see resolveNotebook). A listed notebook is named by its id (or a start of
   it, or its whole UUID), else by its window title, else by its file. Only a name that is none of these is looked
   for on the disk. *)
openSource // beginDefinition;

openSource[ _Missing ] := <| "Source" -> None, "SourceID" -> None, "Title" -> "Untitled" |>;

openSource[ spec_String ] := Module[ { entries, id, matches, file },
    entries = listedNotebooks[ ];
    id      = ToLowerCase @ spec;
    matches = If[ StringLength @ id >= $minPrefixLength,
        Select[ entries, StringStartsQ[ #[ "ID" ], id ] || StringStartsQ[ id, #[ "ID" ] ] & ],
        { }
    ];
    If[ matches === { }, matches = Select[ entries, #[ "Title" ] === spec & ] ];
    If[ matches === { }, matches = Select[ entries, sameFileQ[ #[ "File" ], spec ] & ] ];
    file = If[ matches === { }, notebookFile @ spec, None ];
    Which[
        Length @ matches === 1,
            entrySource @ First @ matches,
        Length @ matches > 1,
            toolError[
                "`1` matches more than one notebook: `2`. Give its id, its title or its file.",
                quoted @ spec,
                StringRiffle[ #[ "ID" ] <> " (" <> quoted @ inlineText @ Replace[ #[ "Title" ], None -> "Untitled" ] <> ")" & /@ matches, ", " ]
            ],
        StringQ @ file && excludedFileQ @ file,
            toolError[ $excludedNotebookText, quoted @ spec ],
        StringQ @ file,
            <| "Source" -> file, "SourceID" -> None, "Title" -> FileNameTake @ file |>,
        True,
            None
    ]
];

openSource // endDefinition;


entrySource // beginDefinition;

entrySource[ entry_Association ] := <|
    "Source"   -> entry[ "NotebookObject" ],
    "SourceID" -> entry[ "ID" ],
    "Title"    -> Replace[ entry[ "Title" ], None :> Replace[ entry[ "File" ], { f_String :> FileNameTake @ f, _ -> "Untitled" } ] ]
|>;

entrySource // endDefinition;


(* A .nb file that exists, as the expanded name that it was given by, or None. That name is what a snapshot is made
   from and what ShowChanges opens. *)
notebookFile // beginDefinition;

notebookFile[ spec_String ] := With[ { file = Quiet @ ExpandFileName @ spec },
    If[ StringQ @ file && ToLowerCase @ FileExtension @ file === "nb" && FileExistsQ @ file && ! DirectoryQ @ file,
        file,
        None
    ]
];

notebookFile // endDefinition;


(* Whether two names are one file, as far as their text says (normalFileName). This is a best effort and no boundary:
   another name that the file system resolves to the file is another file here (a short name, a junction or a link,
   a UNC name, another drive letter, a \\?\ prefix, a hard link), so a notebook that the user excluded from chats can
   be opened as a file by such a name. Known edge case: on a macOS volume that tells letter cases apart, two files
   whose names only differ in case are taken for one. *)
sameFileQ // beginDefinition;
sameFileQ[ file_String, spec_String ] := MatchQ[ normalFileName /@ { file, spec }, { name_String, name_String } ];
sameFileQ[ _, _ ] := False;
sameFileQ // endDefinition;


(* The name that a file is compared by, or None: expanded, with forward slashes, and in lower case where the file
   system has no letter case ($ignoreFileCase). This is text only: nothing is asked of the disk or the network, so a
   name on a share that can't be reached costs nothing. *)
normalFileName // beginDefinition;

normalFileName[ file_String ] := Replace[
    Quiet @ ExpandFileName @ file,
    { name_String :> If[ TrueQ @ $ignoreFileCase, ToLowerCase, Identity ][ StringReplace[ name, "\\" -> "/" ] ], _ -> None }
];

normalFileName // endDefinition;


(* A title or file name in a result or an error: on one line *)
inlineText // beginDefinition;
inlineText[ text_String ] := StringReplace[ text, ("\r\n"|"\n"|"\r") -> " " ];
inlineText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Snapshots*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookRecord*)

(* What a tool works with: a notebook that is read or written under a name.
     "Name"      the handle of a snapshot (s1, s2, ...), which $snapshots has the record under, or the id of an open
                 notebook that is read as it is
     "Notebook"  the NotebookObject that is read and written: the snapshot, or the open notebook itself
     "Source", "SourceID", "Title"  what it was made of (openSource)
     "Table"     the notebook whose table has the ids of its cells
     "Edits"     None, or once a snapshot is edited the ExpressionUUIDs of the cells that a call changed (the other
                 cells of the source are compared as the source has them, see comparedNotebook)
     "Deleted"   the ids of the cells that WriteCells calls deleted from a snapshot
     "Chat"      the ConversationUUID of the chat that made it, or None *)
notebookRecord // beginDefinition;

notebookRecord[ name_String, nbo_NotebookObject, source_Association ] := <|
    "Name"     -> name,
    "Notebook" -> nbo,
    source,
    "Table"    -> Replace[ source[ "Source" ], Except[ _NotebookObject ] -> nbo ],
    "Edits"    -> None,
    "Deleted"  -> { },
    "Chat"     -> currentChat[ ]
|>;

notebookRecord // endDefinition;


(* What a result or an error calls the notebook of a record: its name and its title *)
notebookLabel // beginDefinition;
notebookLabel[ record_Association ] := record[ "Name" ] <> " (" <> quoted @ inlineText @ record[ "Title" ] <> ")";
notebookLabel // endDefinition;


snapshotLabels // beginDefinition;
snapshotLabels[ snapshots_Association ] := StringRiffle[ notebookLabel /@ Values @ snapshots, ", " ];
snapshotLabels // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatSnapshots*)

(* A snapshot belongs to the chat that opened it (its ConversationUUID; None outside such a chat): a snapshot that an
   earlier chat left open (stopped, out of tool calls, or never shown) is stale for a later one, since the user may
   have changed the notebook since. The tools only see the snapshots of the running chat; newSnapshot discards a
   stale snapshot of the same notebook, and one of another chat when too many are open.
   A snapshot of an open notebook is only kept while it has edits (withSnapshot), so nothing is read from a snapshot
   that could as well be read from the notebook.
   Known limitation: a snapshot whose edits were not shown (no ShowChanges) is read and edited again in later turns
   as it is, also when the user changed the notebook since. *)
chatSnapshots // beginDefinition;
chatSnapshots[ ] := With[ { chat = currentChat[ ] }, Select[ $snapshots, #[ "Chat" ] === chat & ] ];
chatSnapshots // endDefinition;


(* The running chat's settings are in $ChatHandlerData during a tool call ($currentChatSettings is not: catchTop resets
   it when the tool function is called outside of the chat's own evaluation) *)
currentChat // beginDefinition;

currentChat[ ] := Replace[
    $ChatHandlerData,
    { KeyValuePattern[ "ChatNotebookSettings" -> KeyValuePattern[ "ConversationUUID" -> id_String ] ] :> id, _ -> None }
];

currentChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveNotebook*)

(* What a tool works on: the handle of one of the chat's snapshots, or (if any is True) the source of a notebook that
   the chat has no snapshot of, as openSource gives it. Without the notebook argument it is the chat's only snapshot,
   and in a chat without snapshots the notebook the user is working in. A handle that is not open in a chat without
   snapshots is taken the same way: models guess s1. Anything else that is not a handle is a notebook as OpenNotebook
   takes it. The argument is cleaned once (cleanName), so that it is one name for handles, ids, titles and files: a
   listed notebook that is named by its file in quotes is that notebook, and not the file on the disk. *)
resolveNotebook // beginDefinition;

resolveNotebook[ argument_, any: True | False ] := Module[ { spec, snapshots, name, user, source },
    requireFrontEnd[ ];
    spec      = Replace[ argument, s_String :> cleanName @ s ];
    snapshots = chatSnapshots[ ];
    name      = If[ StringQ @ spec, ToLowerCase @ spec, None ];
    Which[
        KeyExistsQ[ snapshots, name ],
            name,
        name === None && Length @ snapshots > 1,
            toolError[ "Several snapshots are open: `1`. Give one of them as notebook.", snapshotLabels @ snapshots ],
        name === None && Length @ snapshots === 1,
            First @ Keys @ snapshots,
        ! any && snapshots === <| |>,
            toolError[ "No snapshot is open." ],
        ! any,
            toolError[ "`1`.", notOpenText[ spec, snapshots ] ],
        True,
            source = If[ name === None || (snapshots === <| |> && StringMatchQ[ name, "s" ~~ DigitCharacter.. ]),
                user = userNotebook[ ];
                Replace[
                    SelectFirst[ listedNotebooks[ ], #[ "NotebookObject" ] === user &, None ],
                    {
                        entry_Association :> entrySource @ entry,
                        _ :> toolError[ "The notebook the user is working in was not found. OpenNotebook opens a notebook that ListNotebooks lists." ]
                    }
                ],
                Replace[
                    openSource @ spec,
                    None :> toolError[ "`1`, and no open notebook or .nb file matches it.", notOpenText[ spec, snapshots ] ]
                ]
            ];
            First[ Keys @ Select[ snapshots, sameSourceQ[ #[ "Source" ], source[ "Source" ] ] & ], source ]
    ]
];

resolveNotebook // endDefinition;


notOpenText // beginDefinition;

notOpenText[ spec_, snapshots_Association ] := StringJoin[
    quoted @ spec, " is not an open snapshot",
    If[ snapshots === <| |>, "", " (open: " <> snapshotLabels @ snapshots <> ")" ]
];

notOpenText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*newSnapshot*)
sameSourceQ // beginDefinition;
sameSourceQ[ a_NotebookObject, b_NotebookObject ] := a === b;
sameSourceQ[ a_String, b_String ] := sameFileQ[ a, b ];
sameSourceQ[ _, _ ] := False;
sameSourceQ // endDefinition;


(* Has the front end make a snapshot of a source that the chat has none of, and gives its record, which $snapshots
   has under a new handle; at most $maxSnapshots are open. A snapshot of the same notebook that an earlier chat left
   open is stale (chatSnapshots): it is discarded. The ids of the snapshot's cells are those of its source, whose
   cells have the same ExpressionUUIDs (withCellTable). *)
newSnapshot // beginDefinition;

newSnapshot[ source_Association ] := Module[ { stale, nbo, handle },
    Scan[ closeSnapshot, Keys @ Select[ $snapshots, sameSourceQ[ #[ "Source" ], source[ "Source" ] ] & ] ];
    If[ Length @ $snapshots >= $maxSnapshots,
        (* the oldest snapshot of an earlier chat makes room (chatSnapshots), else this chat has too many open *)
        stale = First[ Keys @ Select[ $snapshots, #[ "Chat" ] =!= currentChat[ ] & ], None ];
        If[ StringQ @ stale,
            closeSnapshot @ stale,
            toolError[
                "`1` snapshots are open already, the most there can be: `2`. Show the changes of one with ShowChanges, \
or close one with CloseNotebook, before opening another.",
                Length @ $snapshots,
                snapshotLabels @ $snapshots
            ]
        ]
    ];
    nbo = notebookFrontEnd[ "Snapshot", source[ "Source" ] ];
    If[ ! MatchQ[ nbo, _NotebookObject ],
        toolError[ "The front end could not make a snapshot of `1`.", quoted @ source[ "Title" ] ]
    ];
    (* A file that is not open can say itself that it is excluded from chats: *)
    If[ StringQ @ source[ "Source" ] && TrueQ @ notebookFrontEnd[ "Excluded", nbo ],
        notebookFrontEnd[ "Close", nbo ];
        toolError[ $excludedNotebookText, quoted @ source[ "Title" ] ]
    ];
    handle = "s" <> ToString[ ++$snapshotCount ];
    $snapshots[ handle ] = notebookRecord[ handle, nbo, source ]
];

newSnapshot // endDefinition;


closeSnapshot // beginDefinition;

closeSnapshot[ handle_String ] := (
    notebookFrontEnd[ "Close", $snapshots[ handle, "Notebook" ] ];
    KeyDropFrom[ $snapshots, handle ];
);

closeSnapshot // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withNotebook*)

(* The text that a reading tool gives for its notebook argument: what function gives for the record of what is read.
   That is the chat's snapshot of the notebook if it has one, which has the chat's edits. An open notebook without a
   snapshot is read as it is, under its id. A file that is not open has to be opened as a snapshot, which the result
   says. *)
withNotebook // beginDefinition;

withNotebook[ spec_, function_ ] := With[ { target = resolveNotebook[ spec, True ] },
    Which[
        StringQ @ target,
            withRecord[ $snapshots @ target, function ],
        MatchQ[ target[ "Source" ], _NotebookObject ],
            withRecord[ notebookRecord[ target[ "SourceID" ], target[ "Source" ], target ], function ],
        True,
            With[ { opened = newSnapshot @ target },
                $openedText[ notebookLabel @ opened ] <> withRecord[ opened, function ]
            ]
    ]
];

withNotebook // endDefinition;

$openedText = StringTemplate[ "Opened `1`, a snapshot of the notebook.\n\n" ];


(* What function gives for a record, with the ids and the originals of its cells in place *)
withRecord // beginDefinition;

withRecord[ record_Association, function_ ] :=
    withCellTable[ { record[ "Table" ], record[ "Notebook" ] }, function @ record ];

withRecord // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withSnapshot*)

(* The text that an editing tool gives for its notebook argument: what function gives for the record of the snapshot
   that it edits. That is the chat's snapshot of the notebook if it has one. Else a snapshot is made now, so that it
   is the notebook as the user has it at the first edit, and the result says that it was opened. If the call then
   edits nothing (it fails, or it changes nothing), the snapshot is closed again and its handle is free: the next
   edit starts from the notebook as it is then.
   A failed edit costs a snapshot this way. Converting the text before the snapshot is made would avoid that. *)
withSnapshot // beginDefinition;

withSnapshot[ spec_, function_ ] := With[ { target = resolveNotebook[ spec, True ] },
    If[ StringQ @ target,
        withRecord[ $snapshots @ target, function ],
        (* A notebook that shows changes holds the cells of the comparison: the user resolves them first *)
        If[ MatchQ[ target[ "Source" ], _NotebookObject ] && notebookFrontEnd[ "DiffCells", target[ "Source" ] ] =!= { },
            toolError[ $diffShownText, quoted @ inlineText @ target[ "Title" ] ]
        ];
        With[ { opened = newSnapshot @ target },
            With[ { handle = opened[ "Name" ] },
                WithCleanup[
                    With[ { text = withRecord[ opened, function ] },
                        If[ $snapshots[ handle, "Edits" ] === None, text, $openedText[ notebookLabel @ opened ] <> text ]
                    ],
                    If[ $snapshots[ handle, "Edits" ] === None, closeSnapshot @ handle; $snapshotCount-- ]
                ]
            ]
        ]
    ]
];

withSnapshot // endDefinition;

$diffShownText = "\
`1` still shows the changes of an earlier ShowChanges, which the user has not all accepted or rejected. It can't be \
edited until they have: tell the user to accept or reject the changes that are shown (the toolbar has Accept All and \
Reject All), and make this edit after that. Nothing was written.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cells*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withNotebookCellSyntax*)

(* Evaluates eval so that CellToString writes the cells of a notebook in the cell syntax as the tools read them in the
   running chat: with the ids of the notebook's table, and with what it records for them kept there. The notebook
   context calls this for the user's notebook, so that a cell has the same id and reads the same there and in a
   snapshot of the notebook. *)
withNotebookCellSyntax // beginDefinition;
withNotebookCellSyntax // Attributes = { HoldRest };
withNotebookCellSyntax[ nbo_NotebookObject, eval_ ] :=
    withCellTable[ { nbo, nbo }, Block[ { $includeCellXML = True, $preserveCellBoxes = Automatic }, eval ] ];

withNotebookCellSyntax // endDefinition;


(* Evaluates eval with the ids and the originals of a table. table is the notebook that the table belongs to. If the
   chat has not seen it yet, the cells of nb (the notebook, or a snapshot of it) are numbered c1, c2, ... in their
   order. A cell that is seen later gets the next number, so an id stays with its cell (its ExpressionUUID) for the
   life of the table. The tools give CellToString its options themselves, so that the cell syntax is not on for what
   else they call (the evaluator, the chat formatter). What eval gives is what the model gets (the notebook context, a
   result of NotebookReader or of a tool): the cells that it shows whole are recorded as seen. *)
withCellTable // beginDefinition;
withCellTable // Attributes = { HoldRest };

withCellTable[ { table_NotebookObject, nb_NotebookObject }, eval_ ] := With[ { key = { currentChat[ ], table } },
    If[ ! KeyExistsQ[ $cellTables, key ], newCellTable[ key, nb ] ];
    Block[ { $tableKey = key, $cellIDFunction = cellID[ key, # ] &, $cellOriginals = $cellTables[ key, "Originals" ] },
        WithCleanup[
            With[ { result = eval }, seeCells @ wholeCells @ result; result ],
            $cellTables = Append[ KeyDrop[ $cellTables, Key @ key ], key -> <| $cellTables @ key, "Originals" -> $cellOriginals |> ]
        ]
    ]
];

withCellTable // endDefinition;


(* The ids of the cells whose whole body a result gives the model: those of its cell tags that do not say truncated
   (an outline line and a search line are no tags). Known gap: the notebook context that is only made for the prompts
   of searches (notebookContextTurnMessages0) counts too, though it is not sent. *)
wholeCells // beginDefinition;
wholeCells[ text_String ] := StringCases[ text, $$wholeCellTag :> "$1" ];
wholeCells[ { text_String, ___ } ] := wholeCells @ text;
wholeCells[ _ ] := { };
wholeCells // endDefinition;

$$wholeCellTag = RegularExpression[ "(?m)^<cell id='(c\\d+)'(?:(?! truncated='true'>$)[^\\n])*>$" ];


(* Records ids of the table in use as seen: WriteCells replaces the content of a cell only if the model has seen all
   of it *)
seeCells // beginDefinition;
seeCells[ { } ] := Null;
seeCells[ ids: { __String } ] := $cellTables[[ Key @ $tableKey, "Seen" ]] = Union[ $cellTables[ $tableKey, "Seen" ], ids ];
seeCells // endDefinition;


(* The oldest tables are dropped for a new one *)
newCellTable // beginDefinition;

newCellTable[ key_List, nb_NotebookObject ] := With[
    { uuids = DeleteDuplicates @ Cases[ notebookFrontEnd[ "Cells", nb ], CellObject[ uuid_String, ___ ] :> uuid ] },
    $cellTables = Append[
        Take[ $cellTables, -Min[ Length @ $cellTables, $maxCellTables - 1 ] ],
        key -> <|
            "IDs"       -> AssociationThread[ uuids -> Map[ "c" <> ToString @ # &, Range @ Length @ uuids ] ],
            "Next"      -> Length @ uuids + 1,
            "Originals" -> <| |>,
            "Seen"      -> { }
        |>
    ]
];

newCellTable // endDefinition;


(* The id of a cell in a table (a new one for a cell that has none), or None for a cell without an ExpressionUUID *)
cellID // beginDefinition;

cellID[ key_List, uuid_String ] := Lookup[
    $cellTables[ key, "IDs" ],
    uuid,
    With[ { table = $cellTables @ key, id = "c" <> ToString @ $cellTables[ key, "Next" ] },
        $cellTables[ key ] = <| table, "IDs" -> Append[ table[ "IDs" ], uuid -> id ], "Next" -> table[ "Next" ] + 1 |>;
        id
    ]
];

cellID[ key_List, cell_ ] := Replace[ cellUUID @ cell, { uuid_String :> cellID[ key, uuid ], _ -> None } ];

cellID // endDefinition;


(* A cell that Chatbook reads has its CellObject as an option (notebookRead), and one that the tools write its
   ExpressionUUID *)
cellUUID // beginDefinition;
cellUUID[ CellObject[ uuid_String, ___ ] ] := uuid;
cellUUID[ Cell[ ___, CellObject -> CellObject[ uuid_String, ___ ], ___ ] ] := uuid;
cellUUID[ Cell[ ___, ExpressionUUID -> uuid_String, ___ ] ] := uuid;
cellUUID[ _ ] := None;
cellUUID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookCells*)

(* The cells of the notebook of a record in their order, each as <| "ID", "UUID", "Object" |>: all of them, or the ones
   that have a style *)
notebookCells // beginDefinition;

notebookCells[ record_Association, style___ ] := With[ { objects = notebookFrontEnd[ "Cells", record[ "Notebook" ], style ] },
    If[ ! MatchQ[ objects, { CellObject[ _String, ___ ]... } ],
        toolError[ "The front end could not list the cells of `1`.", notebookLabel @ record ]
    ];
    <| "ID" -> $cellIDFunction @ #, "UUID" -> First @ #, "Object" -> # |> & /@ objects
];

notebookCells // endDefinition;


(* The position of the cell that the model names: "c3", "#c3", "C3" or "3". A cell that an earlier call of the chat
   deleted from the snapshot has its own message: a model that deletes a cell to write it again elsewhere otherwise
   takes the cell for moved. *)
cellPosition // beginDefinition;

cellPosition[ record_Association, cells_List, spec_String ] := With[
    { id = Replace[ StringDelete[ cleanID @ spec, StartOfString ~~ "#" ], n_ /; StringMatchQ[ n, DigitCharacter.. ] :> "c" <> n ] },
    First @ FirstPosition[
        cells[[ All, "ID" ]],
        id,
        If[ MemberQ[ record[ "Deleted" ], id ],
            toolError[ $deletedCellText, id, record[ "Name" ] ],
            toolError[ "`1` has no cell `2`. GetOutline gives the ids of its cells.", record[ "Name" ], quoted @ spec ]
        ],
        { 1 }
    ]
];

cellPosition // endDefinition;

$deletedCellText = "\
`1` is not in `2` any more: an earlier call of this chat deleted it, with its content. If the cell is still needed, \
write it as a new cell (<cell style='...'>...</cell>, with after= or before= for its place). To move a cell, do not \
delete it: <cell id='c7' before='c2'/> moves it as it is.";


(* The cells that an argument names, in their order in the notebook: ids, and ranges such as c10-c20 (the cells from
   c10 to c20 in the notebook). All cells if it is not given, or "all". *)
cellsArgument // beginDefinition;

cellsArgument[ _Association, cells_List, _Missing ] := cells;

cellsArgument[ record_Association, cells_List, spec: _String | { ___String } ] := With[
    {
        items = listArgument[
            StringReplace[ spec, WhitespaceCharacter... ~~ ("-" | "\[Dash]") ~~ WhitespaceCharacter... -> "-" ],
            WhitespaceCharacter | "," | ";"
        ]
    },
    Which[
        ToLowerCase @ items === { "all" }, cells,
        items === { }, toolError[ $cellsText, quoted @ spec ],
        True, cells[[ Union @@ (cellRange[ record, cells, # ] & /@ items) ]]
    ]
];

cellsArgument // endDefinition;

$cellsText = "The parameter cells names no cell (`1`): give ids and ranges, e.g. \"c3, c10-c20\", or leave it out for all cells.";


(* The positions that one item of cells names: a cell, or the cells from one to another *)
cellRange // beginDefinition;

cellRange[ record_Association, cells_List, item_String ] := Replace[
    cellPosition[ record, cells, # ] & /@ StringSplit[ item, "-" ],
    {
        { position_ } :> { position },
        { from_, to_ } :> Range @@ Sort @ { from, to },
        _ :> toolError[ "`1` in the parameter cells is not a cell id or a range of two ids such as c10-c20.", quoted @ item ]
    }
];

cellRange // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readEntries*)

(* Cells (of notebookCells) with their expressions ("Cell", with the CellObject as Chatbook's option) *)
cellEntries // beginDefinition;

cellEntries[ _Association, { } ] := { };

cellEntries[ record_Association, cells: { __Association } ] := With[
    { read = notebookFrontEnd[ "Read", record[ "Notebook" ], cells[[ All, "Object" ]] ] },
    If[ ! MatchQ[ read, { __Cell } ] || Length @ read =!= Length @ cells,
        toolError[ "The front end could not read the cells of `1`.", notebookLabel @ record ]
    ];
    MapThread[ <| #1, "Cell" -> Append[ #2, CellObject -> #1[ "Object" ] ] |> &, { cells, read } ]
];

cellEntries // endDefinition;


(* Cells as the model gets them: each with its text in the cell syntax ("Text", whose body is cut at limit characters)
   and the body alone ("Body"). The cells that the user excluded from chats (chatExcludedQ, the test of the notebook
   context) are left out: no tool shows, finds or changes them, and a result says how many it left out
   (excludedNote). *)
readEntries // beginDefinition;

readEntries[ record_Association, cells_List, limit_ ] := Map[
    With[ { text = cellText[ #[ "Cell" ], limit ] }, <| #, "Text" -> text, "Body" -> cellBody @ text |> ] &,
    Select[ cellEntries[ record, cells ], ! chatExcludedQ @ #[ "Cell" ] & ]
];

readEntries // endDefinition;


(* A line of a result about the cells that it leaves out *)
excludedNote // beginDefinition;
excludedNote[ 0 ] := { };
excludedNote[ 1 ] := "[1 cell that the user excluded from AI chats is left out.]";
excludedNote[ n_Integer ] := "[" <> ToString @ n <> " cells that the user excluded from AI chats are left out.]";
excludedNote // endDefinition;


(* The entry of the cell that the model names, with its whole text *)
namedEntry // beginDefinition;

namedEntry[ record_Association, cells_List, spec_String ] := With[ { cell = cells[[ cellPosition[ record, cells, spec ] ]] },
    First[
        readEntries[ record, { cell }, Infinity ],
        toolError[ "`1` is a cell that the user excluded from AI chats, so it is not read or changed. Nothing was written.", cell[ "ID" ] ]
    ]
];

namedEntry // endDefinition;


(* A cell in the cell syntax. The body of a generated cell is not exact, and a graphic in it is a link, as it is in
   the other cells (a multimodal chat gets the images of the first links of a result). *)
cellText // beginDefinition;

cellText[ cell_Cell, limit_ ] := With[
    {
        text = CellToString[
            cell,
            "IncludeXML"          -> True,
            "PreserveBoxes"       -> Automatic,
            "MaxCellStringLength" -> limit,
            Sequence @@ If[ limit === Infinity, { "MaxOutputCellStringLength" -> Infinity }, { } ]
        ]
    },
    If[ StringQ @ text, text, throwInternalFailure @ cellText[ cell, limit ] ]
];

cellText // endDefinition;


(* The body of a cell in the cell syntax: the lines between its tags *)
cellBody // beginDefinition;

cellBody[ text_String ] := First[
    StringCases[ text, RegularExpression[ "(?s)\\A<cell[^\\n]*\\n(.*)\\n</cell>\\z" ] :> "$1", 1 ],
    throwInternalFailure @ cellBody @ text
];

cellBody // endDefinition;


(* Cells that an evaluation makes are not written as text *)
generatedCellQ // beginDefinition;
generatedCellQ[ cell_Cell ] := MatchQ[ cell, Cell[ __, $$generatedCellStyle, ___ ] ];
generatedCellQ // endDefinition;

$generatedCellText = "\
`1` is a generated cell (an output, a message, a print): its content is not written as text. Write its Input cell \
with evaluate: true, which replaces its outputs. A tag without content moves a generated cell as it is \
(<cell id='c48' after='c47'/>) or deletes it (<cell id='c48' delete='true'/>). Nothing was written.";


(* Ends the tool if one of the cells (entries) is locked in the notebook: it is not deletable, or not editable, as the
   front end resolves the two options (the cell's own, or those of its notebook or stylesheet). The front end does
   not delete a cell that is not deletable, so a write to one would leave the old cell next to the new one. *)
requireUnlocked // beginDefinition;

requireUnlocked[ record_Association, entries_List ] := Replace[
    lockedEntries[ record, entries ],
    locked: { __ } :> toolError[
        "Locked in the notebook: `1`. A cell that the user or the author of the notebook made not editable or not \
deletable is not changed, moved or deleted. Nothing was written.",
        StringRiffle[ DeleteDuplicates @ locked[[ All, "ID" ]], ", " ]
    ]
];

requireUnlocked // endDefinition;


(* Those of the entries that are locked. Some generated cells are not editable by their style (a Message), and none is
   edited by hand: a generated cell is only locked if it is not deletable. *)
lockedEntries // beginDefinition;

lockedEntries[ _Association, { } ] := { };

lockedEntries[ record_Association, entries: { __Association } ] := With[
    { locks = notebookFrontEnd[ "Locks", record[ "Notebook" ], entries[[ All, "Object" ]] ] },
    Pick[
        entries,
        MapThread[
            Function[ { entry, lock }, Last @ lock === False || (First @ lock === False && ! generatedCellQ @ entry[ "Cell" ]) ],
            { entries, locks }
        ]
    ]
];

lockedEntries // endDefinition;


(* Cells in the cell syntax, as many as fit into $readBudget (at least one), with a note on the ones that do not, and
   one on excluded cells that were left out *)
shownCells // beginDefinition;

shownCells[ entries_List, excluded_Integer ] := With[
    { shown = Min[ Length @ entries, Max[ 1, LengthWhile[ Accumulate[ StringLength @ entries[[ All, "Text" ]] + 2 ], LessEqualThan @ $readBudget ] ] ] },
    StringRiffle[
        Flatten @ {
            entries[[ ;; shown, "Text" ]],
            If[ shown < Length @ entries,
                StringJoin[
                    "[Not shown: ", entries[[ shown + 1, "ID" ]], " and the ", ToString[ Length @ entries - shown - 1 ],
                    " cells after it. Read them with ReadCells, cells \"", entries[[ shown + 1, "ID" ]], "-", entries[[ -1, "ID" ]], "\".]"
                ],
                { }
            ],
            excludedNote @ excluded
        },
        "\n\n"
    ]
];

shownCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ListNotebooks*)
listNotebooks // beginDefinition;

listNotebooks[ _Association ] := Module[ { user, snapshots },
    user      = userNotebook[ ];
    snapshots = chatSnapshots[ ];
    Developer`WriteRawJSONString[
        <|
            "notebooks" -> Map[
                Function[ entry, <|
                    "id"       -> entry[ "ID" ],
                    "title"    -> Replace[ entry[ "Title" ], None -> Null ],
                    "file"     -> Replace[ entry[ "File" ], None -> Null ],
                    "modified" -> entry[ "Modified" ],
                    "cells"    -> Count[ notebookFrontEnd[ "Cells", entry[ "NotebookObject" ] ], _CellObject ],
                    "current"  -> entry[ "NotebookObject" ] === user,
                    "snapshot" -> First[ Keys @ Select[ snapshots, #[ "Source" ] === entry[ "NotebookObject" ] & ], Null ]
                |> ],
                listedNotebooks[ ]
            ],
            "snapshots" -> KeyValueMap[
                <|
                    "notebook" -> #1,
                    "title"    -> #2[ "Title" ],
                    "source"   -> Replace[ #2[ "Source" ], { _NotebookObject :> #2[ "SourceID" ], None -> Null } ],
                    "edited"   -> ListQ @ #2[ "Edits" ]
                |> &,
                snapshots
            ]
        |>,
        "Compact" -> True
    ]
];

listNotebooks // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*OpenNotebook*)

(* A new notebook is opened as a snapshot. Any other notebook is read as the reading tools read it: an open notebook as
   it is, and a file that is not open as a snapshot. *)
openNotebook // beginDefinition;

openNotebook[ args_Association ] := If[ MissingQ @ args[ "notebook" ],
    requireFrontEnd[ ];
    withRecord[ newSnapshot @ openSource @ args[ "notebook" ], openedNotebook ],
    withNotebook[ args[ "notebook" ], openedNotebook ]
];

openNotebook // endDefinition;


(* A line about the notebook of a record, and then its cells as ReadCells shows them, so that no ReadCells call is
   needed, or an outline if they do not fit into one result *)
openedNotebook // beginDefinition;

openedNotebook[ record_Association ] := Module[ { cells, entries, page },
    cells   = notebookCells @ record;
    entries = readEntries[ record, cells, $cellLength ];
    page    = Take[ cells, UpTo @ $outlineLimit ];
    StringJoin[
        notebookLabel @ record, ": ",
        Replace[
            record[ "Source" ],
            {
                record[ "Notebook" ] :> "an open notebook",
                _NotebookObject      :> "a snapshot of the notebook " <> record[ "SourceID" ],
                None                 :> "a snapshot of a new notebook",
                file_                :> "a snapshot of " <> inlineText @ file
            }
        ],
        If[ ListQ @ record[ "Edits" ], " with your edits", "" ],
        ", ", ToString @ Length @ cells, " cells.",
        Which[
            cells === { },
                "",
            Total[ StringLength @ entries[[ All, "Text" ]] + 2 ] <= $readBudget,
                "\n\n" <> shownCells[ entries, Length @ cells - Length @ entries ],
            True,
                " They do not fit into one result, so this is an outline (id, style, start of content):\n" <>
                    outlinePage[ Select[ entries, MemberQ[ page[[ All, "UUID" ]], #[ "UUID" ] ] & ], 1, Length @ page, Length @ cells ]
        ]
    ]
];

openedNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GetOutline*)
getOutline // beginDefinition;

getOutline[ args_Association ] := withNotebook[ args[ "notebook" ], Function[ record,
    Module[ { cells, offset, limit, page },
        cells  = notebookCells @ record;
        offset = countArgument[ args[ "offset" ], "offset", 1 ];
        limit  = Min[ countArgument[ args[ "limit" ], "limit", $outlineLimit ], $maxOutlineLimit ];
        Which[
            cells === { },
                notebookLabel @ record <> " has no cells.",
            offset > Length @ cells,
                toolError[ "The offset `1` is past the last cell: `2` has `3` cells.", offset, record[ "Name" ], Length @ cells ],
            True,
                page = Take[ cells, { offset, Min[ Length @ cells, offset + limit - 1 ] } ];
                StringJoin[
                    notebookLabel @ record, ", ", ToString @ Length @ cells, " cells (id, style, start of content):\n",
                    outlinePage[ readEntries[ record, page, $cellLength ], offset, Length @ page, Length @ cells ]
                ]
        ]
    ]
] ];

getOutline // endDefinition;


(* One line per cell (its id, its style and the start of its content) for the entries of count cells that start at
   the offset-th of total cells, with a note on excluded cells among them, and one if they end before the last cell *)
outlinePage // beginDefinition;

outlinePage[ entries_List, offset_Integer, count_Integer, total_Integer ] := With[ { last = offset + count - 1 },
    StringRiffle[
        Flatten @ {
            StringJoin[ #[ "ID" ], " (", StringRiffle[ cellStyles @ #[ "Cell" ], ", " ], ") ", preview @ #[ "Body" ] ] & /@ entries,
            excludedNote[ count - Length @ entries ],
            If[ last < total,
                StringTemplate[ "[Cells `1`-`2` of `3`. GetOutline with offset `4` gives the next ones.]" ][ offset, last, total, last + 1 ],
                { }
            ]
        },
        "\n"
    ]
];

outlinePage // endDefinition;


preview // beginDefinition;

preview[ body_String ] := With[ { line = StringTrim @ StringReplace[ body, ("\r\n" | "\n" | "\r").. -> " " ] },
    If[ StringLength @ line > $previewLength, StringTake[ line, $previewLength ] <> "\[Ellipsis]", line ]
];

preview // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ReadCells*)
readCells // beginDefinition;

readCells[ args_Association ] := withNotebook[ args[ "notebook" ], Function[ record,
    With[ { cells = cellsArgument[ record, notebookCells @ record, args[ "cells" ] ] },
        If[ cells === { },
            notebookLabel @ record <> " has no cells.",
            With[ { entries = readEntries[ record, cells, If[ booleanArgument[ args[ "full" ], "full" ], Infinity, $cellLength ] ] },
                shownCells[ entries, Length @ cells - Length @ entries ]
            ]
        ]
    ]
] ];

readCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SearchNotebook*)
searchNotebook // beginDefinition;

searchNotebook[ args_Association ] := withNotebook[ args[ "notebook" ], Function[ record,
    Module[ { query, pattern, styles, limit, entries, matches },
        query   = Replace[ args[ "query" ], Except[ _String ] :> missingArgument[ "query" ] ];
        pattern = If[ booleanArgument[ args[ "regex" ], "regex" ], regexPattern @ query, query ];
        styles  = Replace[ args[ "styles" ], s: Except[ _Missing ] :> ToLowerCase @ listArgument[ s, "," | ";" ] ];
        limit   = Min[ countArgument[ args[ "limit" ], "limit", $searchLimit ], $maxSearchLimit ];
        entries = readEntries[ record, cellsArgument[ record, notebookCells @ record, args[ "cells" ] ], Infinity ];
        If[ ListQ @ styles, entries = Select[ entries, IntersectingQ[ styles, ToLowerCase @ cellStyles @ #[ "Cell" ] ] & ] ];
        matches = TimeConstrained[ Catenate[ cellMatches[ #, pattern ] & /@ entries ], $searchTimeLimit, $TimedOut ];
        Which[
            matches === $TimedOut,
                toolError[ "The search took longer than `1` seconds. Use a simpler regular expression.", $searchTimeLimit ],
            matches === { },
                "No matches for " <> quoted @ query <> " in " <> notebookLabel @ record <> ".",
            True,
                StringJoin[
                    ToString @ Length @ matches, If[ Length @ matches === 1, " match", " matches" ], " for ", quoted @ query,
                    " in ", notebookLabel @ record, " (id (style) line:column: the line):\n",
                    StringRiffle[ Take[ matches, UpTo @ limit ], "\n" ],
                    If[ Length @ matches > limit, "\n" <> moreMatchesNote[ Drop[ matches, limit ], limit ], "" ]
                ]
        ]
    ]
] ];

searchNotebook // endDefinition;


(* The note on the matches that a result does not show (lines of cellMatches, which start with the id of their cell):
   it names their cells, since a model otherwise takes the cells that it was shown for all that have a match *)
moreMatchesNote // beginDefinition;

moreMatchesNote[ matches: { __String }, limit_Integer ] := With[
    { ids = DeleteDuplicates[ First @ StringSplit[ #, " ", 2 ] & /@ matches ] },
    StringJoin[
        "[These are the first ", ToString @ limit, ". The other ", ToString @ Length @ matches, " are in ",
        StringRiffle[ Take[ ids, UpTo @ $maxPlaces ], ", " ], If[ Length @ ids > $maxPlaces, ", ...", "" ],
        ": limit shows more, and cells and styles narrow a search.]"
    ]
];

moreMatchesNote // endDefinition;


regexPattern // beginDefinition;

regexPattern[ query_String ] := With[ { pattern = RegularExpression @ query },
    If[ ListQ @ Quiet @ Check[ StringPosition[ "", pattern ], $Failed ],
        pattern,
        toolError[ "`1` is not a valid regular expression.", quoted @ query ]
    ]
];

regexPattern // endDefinition;


(* The matches of the pattern in the body of a cell, each as "id (style) line:column: the line of the match" (a long
   line is shortened around the match) *)
cellMatches // beginDefinition;

cellMatches[ entry_Association, pattern_ ] := Module[ { body, lines },
    body  = entry[ "Body" ];
    lines = lineStarts @ body;
    Function[ { start, end },
        Module[ { line, lineStart, lineEnd, from, to },
            line      = LengthWhile[ lines, LessEqualThan @ start ];
            lineStart = lines[[ line ]];
            lineEnd   = If[ line < Length @ lines, lines[[ line + 1 ]] - 2, StringLength @ body ];
            { from, to } = If[ lineEnd - lineStart < $snippetLength,
                { lineStart, lineEnd },
                { Max[ lineStart, start - Quotient[ $snippetLength, 3 ] ], Min[ lineEnd, Max[ end, start + $snippetLength ] ] }
            ];
            StringJoin[
                entry[ "ID" ], " (", StringRiffle[ cellStyles @ entry[ "Cell" ], ", " ], ") ",
                ToString @ line, ":", ToString[ start - lineStart + 1 ], ": ",
                If[ from > lineStart, "\[Ellipsis]", "" ], StringTake[ body, { from, to } ], If[ to < lineEnd, "\[Ellipsis]", "" ]
            ]
        ]
    ] @@@ StringPosition[ body, pattern, Overlaps -> False ]
];

cellMatches // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*EditInCell*)

(* The body of the cell as ReadCells shows it, the replacements, and then cellsFromString with the cell as the
   existing one, so that what the edits leave alone is written back as it was *)
editInCell // beginDefinition;

editInCell[ args_Association ] := withSnapshot[ args[ "notebook" ], Function[ record,
    Module[ { evaluate, entry, id, uuid, body, cell },
        evaluate = booleanArgument[ args[ "evaluate" ], "evaluate" ];
        entry    = namedEntry[ record, notebookCells @ record, stringArgument[ args[ "cell" ], "cell" ] ];
        id       = entry[ "ID" ];
        uuid     = entry[ "UUID" ];
        If[ generatedCellQ @ entry[ "Cell" ], toolError[ $generatedCellText, id ] ];
        requireUnlocked[ record, { entry } ];
        body     = Fold[ editedText[ id, ## ] &, entry[ "Body" ], editsArgument @ args[ "edits" ] ];
        (* No body has a cell tag as it is read, so one that is there now is the model's: *)
        If[ StringContainsQ[ body, "</cell>" | ("<cell" ~~ (WhitespaceCharacter | ">" | "/")) ],
            toolError[ "The edits put a cell tag into `1`, which is one cell. Write a < that is text as &lt;. Nothing was written.", id ]
        ];
        cell     = First[ convertCells[ "<cell id='" <> id <> "'>\n" <> body <> "\n</cell>", <| id -> entry[ "Cell" ] |> ] ][ "Cell" ];
        applyWrites[ record, { { "Replace", uuid, withUUID[ cell, uuid ] } }, { uuid } ];
        StringJoin[
            "Edited ", id, " of ", record[ "Name" ], ". It now reads:\n",
            StringRiffle[ readEntries[ record, Select[ notebookCells @ record, #[ "UUID" ] === uuid & ], $cellLength ][[ All, "Text" ]], "\n\n" ],
            If[ evaluate, "\n\n" <> evaluationText @ evaluateCells[ record, { uuid } ], "" ],
            $notShownText
        ]
    ]
] ];

editInCell // endDefinition;

$notShownText = "\n\nThe user does not see this yet: call ShowChanges when your edits are done, before you reply.";


(* Text with an edit { oldText, newText, count } applied *)
editedText // beginDefinition;

editedText[ id_String, text_String, { old_String, new_String, count_Integer } ] := With[ { n = StringCount[ text, old ] },
    Which[
        n === 0,
            toolError[
                "The oldText `1` does not occur in the content of `2`. Copy it exactly from ReadCells. Nothing was written.",
                quoted @ old, id
            ],
        n =!= count,
            toolError[
                "The oldText `1` occurs `2` times in the content of `3`, not `4`. It also matches inside longer names: \
make it longer to change only some of them, or give count `2` to change all. Nothing was written. The places \
(line:column and the text there): `5`",
                quoted @ old, n, id, count, matchPlaces[ text, old ]
            ],
        True,
            StringReplace[ text, old -> new ]
    ]
];

editedText // endDefinition;


(* Where a text occurs in a body, for a message: the line and column of each place (the first $maxPlaces) with the
   text around it *)
matchPlaces // beginDefinition;

matchPlaces[ body_String, text_String ] := With[
    { starts = StringPosition[ body, text, Overlaps -> False ][[ All, 1 ]], lines = lineStarts @ body },
    StringRiffle[
        Append[
            Function[ start,
                With[ { line = LengthWhile[ lines, LessEqualThan @ start ] },
                    StringJoin[
                        ToString @ line, ":", ToString[ start - lines[[ line ]] + 1 ], " ",
                        inlineText @ StringTake[ body, { Max[ 1, start - 8 ], Min[ StringLength @ body, start + StringLength @ text + 7 ] } ]
                    ]
                ]
            ] /@ Take[ starts, UpTo @ $maxPlaces ],
            If[ Length @ starts > $maxPlaces, "...", Nothing ]
        ],
        " | "
    ]
];

matchPlaces // endDefinition;


(* The positions at which the lines of a text start *)
lineStarts // beginDefinition;
lineStarts[ text_String ] := Prepend[ StringPosition[ text, "\n" ][[ All, 1 ]] + 1, 1 ];
lineStarts // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertCells*)

(* What cellsFromString makes of text, with what reading recorded for the cells: a record for each cell tag. cells
   gives the existing cell of an id: an association, or a function that is asked for each tag with an id. A text that
   cellsFromString refuses ends the tool with its message, which names the cell (a new one by the number of its tag). *)
convertCells // beginDefinition;

convertCells[ text_String, cells_ ] := Replace[
    cellsFromString[ text, "Cells" -> cells, "Originals" -> $cellOriginals, "ExtraAttributes" -> $writeAttributes ],
    {
        records: { KeyValuePattern[ "Cell" -> _ ]... } :> records,
        failure: Failure[ "CellSyntax", _Association ] :> toolError[ "`1` Nothing was written.", failureMessage @ failure ],
        other_ :> throwInternalFailure @ convertCells[ text, cells, other ]
    }
];

convertCells // endDefinition;


(* A cell as the tools write it: with its ExpressionUUID, which the front end gives the cell that it writes *)
withUUID // beginDefinition;
withUUID[ cell_Cell, uuid_String ] := Append[ DeleteCases[ cell, (ExpressionUUID | CellObject) -> _ ], ExpressionUUID -> uuid ];
withUUID // endDefinition;


(* Applies writes to a snapshot. edited are the ExpressionUUIDs of the cells that were replaced. *)
applyWrites // beginDefinition;

applyWrites[ _Association, { }, _List ] := Null;

applyWrites[ record_Association, writes_List, edited_List ] := With[ { handle = record[ "Name" ] },
    If[ notebookFrontEnd[ "Write", record[ "Notebook" ], writes ] === $Failed,
        toolError[ "The front end could not write all of it to `1`. ReadCells shows what it holds now.", notebookLabel @ record ]
    ];
    $snapshots[[ handle, "Edits" ]] = Union[ Replace[ $snapshots[ handle, "Edits" ], None -> { } ], edited ];
];

applyWrites // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WriteCells*)
writeCells // beginDefinition;

writeCells[ args_Association ] := withSnapshot[ args[ "notebook" ], Function[ record,
    Module[ { evaluate, plan, parts, evaluated },
        evaluate  = booleanArgument[ args[ "evaluate" ], "evaluate" ];
        plan      = writePlan[ record, notebookCells @ record, Replace[ args[ "cells" ], Except[ _String ] :> missingArgument[ "cells" ] ] ];
        requireUnlocked[ record, plan[ "Touched" ] ];
        applyWrites[ record, plan[ "Writes" ], plan[ "Edited" ] ];
        If[ plan[ "Deleted" ] =!= { },
            $snapshots[[ record[ "Name" ], "Deleted" ]] = Join[ $snapshots[ record[ "Name" ], "Deleted" ], plan[ "Deleted" ] ]
        ];
        (* what was done, with the new cells by their places: "changed c5; new c7 (Text) after c5; deleted c4" *)
        parts     = Cases[
            Flatten @ { "changed" -> plan[ "Changed" ], "new" -> { # } & /@ newCellPlaces @ plan, "moved" -> plan[ "Moved" ], "deleted" -> plan[ "Deleted" ] },
            (name_ -> ids: { __ }) :> name <> " " <> StringRiffle[ ids, ", " ]
        ];
        evaluated = If[ evaluate, evaluateCells[ record, plan[ "Written" ] ], None ];
        StringJoin[
            StringRiffle[
                {
                    Which[
                        parts =!= { }, "Wrote to " <> record[ "Name" ] <> ": " <> StringRiffle[ parts, "; " ] <> ".",
                        (* cells that were only named to be evaluated: *)
                        MatchQ[ evaluated, { __ } ], Nothing,
                        True, $nothingChangedText
                    ],
                    If[ evaluate, evaluationText @ evaluated, Nothing ]
                },
                "\n\n"
            ],
            If[ $snapshots[ record[ "Name" ], "Edits" ] === None, "", $notShownText ]
        ]
    ]
] ];

writeCells // endDefinition;

$nothingChangedText = "\
Nothing was changed: the cells read as before. Attributes that a tag leaves out keep their values: to remove one, \
give it empty, e.g. <cell id='c3' CellTags=''/>.";


(* The new cells of a plan for the result, a text for each run of them in the notebook that says where the run is:
   "c7 (Text), c8 (Text) after c5" *)
newCellPlaces // beginDefinition;

newCellPlaces[ plan_Association ] := With[ { order = plan[ "Order" ], new = plan[ "New" ] },
    Function[ run,
        StringJoin[
            StringRiffle[ Lookup[ new, order[[ run ]] ], ", " ],
            Which[
                Last @ run === Length @ order, " at the end",
                First @ run === 1, " at the start",
                True, " after " <> $cellIDFunction @ order[[ First @ run - 1 ]]
            ]
        ]
    ] /@ Split[ Flatten @ Position[ order, _? (KeyExistsQ[ new, # ] &), { 1 }, Heads -> False ], #2 === #1 + 1 & ]
];

newCellPlaces // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writePlan*)

(* What a WriteCells call does to a snapshot whose cells are given:
     "Writes"   the writes for the front end
     "Edited"   the ExpressionUUIDs of the cells that read differently afterwards
     "Written"  those of the cells that the text names or makes, which evaluate evaluates
     "Touched"  the entries of the cells that the writes replace, move or delete, which must not be locked
     "Changed", "Moved", "Deleted"  their ids, for the result
     "New"      ExpressionUUID -> "id (styles)" of the new cells, for the result
     "Order"    the ExpressionUUIDs of the notebook's cells as the writes so far leave them
     "Place"    the number of cells that the next new cell comes after (the end of the notebook at first)
     "Anchor"   the ExpressionUUID of the cell of the notebook that the place is after (planAfter), or None
     "Placed"   the cells that the writes put somewhere: ExpressionUUID -> the anchor that the place was after
   cellsFromString reads the whole text and gives a record for each cell tag, with the attributes after, before and
   delete as the tag has them. It asks for the cell of each id, which is read then (old has the entries by their ids).
   Everything is converted before anything is written, so a text that is refused ends the tool with nothing
   written. *)
writePlan // beginDefinition;

writePlan[ record_Association, cells_List, text_String ] := Module[ { old = <| |>, tags },
    tags = convertCells[ text, Function[ id, (old[ id ] = namedEntry[ record, cells, id ])[ "Cell" ] ] ];
    Fold[
        planTag[ record, cells, #1, #2, Lookup[ old, #2[ "ID" ], None ] ] &,
        <|
            "Writes" -> { }, "Edited" -> { }, "Written" -> { }, "Touched" -> { }, "Changed" -> { }, "New" -> <| |>, "Moved" -> { },
            "Deleted" -> { }, "Order" -> cells[[ All, "UUID" ]], "Place" -> Length @ cells, "Anchor" -> None, "Placed" -> <| |>
        |>,
        tags
    ]
];

writePlan // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*planTag*)

(* The plan with what one cell tag does. tag is its record of cellsFromString, and entry the cell that its id names
   (None for a tag without an id). *)
planTag // beginDefinition;

(* A new cell *)
planTag[ record_Association, cells_List, plan_Association, tag_Association, None ] :=
    With[ { name = "Cell tag " <> ToString @ tag[ "Tag" ] <> " (a new cell)" },
        Which[
            KeyExistsQ[ tag[ "Extra" ], "delete" ],
                toolError[ "`1` has delete, which needs the id of a cell. Nothing was written.", name ],
            generatedStyleQ @ tag,
                toolError[ $generatedCellText, name ],
            True,
                planNew[ planPlace[ record, cells, plan, tag[ "Extra" ], None ], tag[ "Cell" ] ]
        ]
    ];

(* A cell of the notebook. A tag without a body gives the styles and options of the cell, which keeps its content.
   A cell that reads as it did is left as it is, so that it stays the user's own cell (it is read without a record of
   it, since it is not the cell of the notebook). *)
planTag[ record_Association, cells_List, plan_Association, tag_Association, entry_Association ] :=
    Module[ { id, uuid, extra, body, cell, edited, moved },
        id    = entry[ "ID" ];
        uuid  = entry[ "UUID" ];
        extra = tag[ "Extra" ];
        body  = MatchQ[ tag[ "Cell" ], _Cell ];
        (* What an evaluation makes is not written as text: *)
        If[ body && (generatedCellQ @ entry[ "Cell" ] || generatedStyleQ @ tag), toolError[ $generatedCellText, id ] ];
        (* A body replaces all of a cell, so the model has to have seen all of it (seeCells): *)
        If[ body && ! MemberQ[ $cellTables[ $tableKey, "Seen" ], id ], toolError[ $notSeenText, id ] ];
        Which[
            ! MemberQ[ plan[ "Order" ], uuid ],
                toolError[
                    "`1` is written after this call deleted it. To move a cell, do not delete it: \
<cell id='`1`' before='c5'/> (or after=) moves it with its content. Nothing was written.",
                    id
                ],

            MatchQ[ ToLowerCase @ Lookup[ extra, "delete", "false" ], "true" | "yes" | "1" ],
                <| planRemove[ plan, uuid ], "Deleted" -> Append[ plan[ "Deleted" ], id ], "Touched" -> Append[ plan[ "Touched" ], entry ] |>,

            True,
                cell = withUUID[
                    Replace[
                        tag[ "Cell" ],
                        _Missing :> Cell[ First @ entry[ "Cell" ], Sequence @@ tag[ "Attributes", "Styles" ], Sequence @@ tag[ "Attributes", "Options" ] ]
                    ],
                    uuid
                ];
                (* a cell that is only moved is no edit *)
                edited = Block[ { $cellOriginals = None }, cellText[ cell, Infinity ] ] =!= entry[ "Text" ];
                (* the plan with the cell at the place that the tag names; a cell that is there already is not moved *)
                moved  = If[ IntersectingQ[ Keys @ extra, { "after", "before" } ],
                    planInsert[ planPlace[ record, cells, planRemove[ plan, uuid ], extra, entry ], { cell } ],
                    plan
                ];
                Which[
                    moved[ "Order" ] =!= plan[ "Order" ],
                        <|
                            moved,
                            "Edited"  -> Join[ plan[ "Edited" ], If[ edited, { uuid }, { } ] ],
                            "Changed" -> Join[ plan[ "Changed" ], If[ edited, { id }, { } ] ],
                            "Moved"   -> Append[ plan[ "Moved" ], id ],
                            "Touched" -> Append[ plan[ "Touched" ], entry ]
                        |>,
                    edited,
                        planAfter[
                            record,
                            cells,
                            <|
                                plan,
                                "Writes"  -> Append[ plan[ "Writes" ], { "Replace", uuid, cell } ],
                                "Edited"  -> Append[ plan[ "Edited" ], uuid ],
                                "Changed" -> Append[ plan[ "Changed" ], id ],
                                "Touched" -> Append[ plan[ "Touched" ], entry ],
                                "Written" -> Append[ plan[ "Written" ], uuid ]
                            |>,
                            entry,
                            True
                        ],
                    True,
                        planAfter[ record, cells, <| plan, "Written" -> Append[ plan[ "Written" ], uuid ] |>, entry, True ]
                ]
        ]
    ];

planTag // endDefinition;

$notSeenText = "\
`1` has not been shown whole in this chat (only cut, or as a line of an outline or a search), so its content is not \
replaced: read it with ReadCells first (full: true shows a long cell whole), or change a part of it with EditInCell. \
Nothing was written.";


(* Whether a tag gives its cell the style of a generated cell *)
generatedStyleQ // beginDefinition;
generatedStyleQ[ tag_Association ] := AnyTrue[ tag[ "Attributes", "Styles" ], MatchQ[ $$generatedCellStyle ] ];
generatedStyleQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Plan steps*)

(* A new cell at the place of the plan. It gets its ExpressionUUID here, so that its id is known at once. *)
planNew // beginDefinition;

planNew[ plan_Association, cell_Cell ] := With[ { new = withUUID[ cell, CreateUUID[ ] ] },
    (* the model wrote the cell, so it has seen all of it *)
    seeCells @ { $cellIDFunction @ new };
    <|
        planInsert[ plan, { new } ],
        "New" -> <| plan[ "New" ], cellUUID @ new -> $cellIDFunction @ new <> " (" <> StringRiffle[ cellStyles @ new, ", " ] <> ")" |>
    |>
];

planNew // endDefinition;


planInsert // beginDefinition;

planInsert[ plan_Association, new: { __Cell } ] := With[
    { order = plan[ "Order" ], place = plan[ "Place" ], uuids = cellUUID /@ new },
    <|
        plan,
        "Writes"  -> Append[
            plan[ "Writes" ],
            { "Insert", Sequence @@ If[ place === 0, { First[ order, None ], "Before" }, { order[[ place ]], "After" } ], new }
        ],
        "Order"   -> Join[ Take[ order, place ], uuids, Drop[ order, place ] ],
        "Place"   -> place + Length @ new,
        "Placed"  -> <| plan[ "Placed" ], Thread[ uuids -> plan[ "Anchor" ] ] |>,
        "Written" -> Join[ plan[ "Written" ], uuids ]
    |>
];

planInsert // endDefinition;


planRemove // beginDefinition;

planRemove[ plan_Association, uuid_String ] := With[ { position = First @ FirstPosition[ plan[ "Order" ], uuid ] },
    <|
        plan,
        "Writes" -> Append[ plan[ "Writes" ], { "Delete", { uuid } } ],
        "Order"  -> Delete[ plan[ "Order" ], position ],
        "Place"  -> plan[ "Place" ] - Boole[ position <= plan[ "Place" ] ]
    |>
];

planRemove // endDefinition;


(* The plan with the place that the attributes after and before of a tag name, if it has one of them. entry is the
   cell of the notebook that is placed (None for a new cell), which is taken out of the plan before. *)
planPlace // beginDefinition;

planPlace[ record_Association, cells_List, plan_Association, extra_Association, entry_ ] := Fold[
    Function[ { p, name },
        With[ { anchor = cells[[ cellPosition[ record, cells, extra @ name ] ]] },
            Which[
                entry =!= None && anchor[ "UUID" ] === entry[ "UUID" ],
                    toolError[
                        "`1` names itself as its place (`2`='`1`'). To change a cell where it is, leave `2` out; to \
move it, name another cell. Nothing was written.",
                        entry[ "ID" ], name
                    ],
                ! MemberQ[ p[ "Order" ], anchor[ "UUID" ] ],
                    toolError[
                        "`1` is not in the notebook where `2` names it: this call deletes or moves it. Nothing was written.",
                        extra @ name, name
                    ],
                name === "before",
                    <| p, "Place" -> First @ FirstPosition[ p[ "Order" ], anchor[ "UUID" ] ] - 1, "Anchor" -> None |>,
                True,
                    planAfter[ record, cells, p, anchor, entry === None || ! generatedCellQ @ entry[ "Cell" ] ]
            ]
        ]
    ],
    plan,
    Intersection[ Keys @ extra, { "after", "before" } ]
];

planPlace // endDefinition;


(* The plan with its place after a cell of the notebook: after the cell and what follows it there already, which is
   - its outputs (the generated cells right after it), so that a cell is not put between a cell and its outputs
     (outputs is False for a generated cell that is placed, which belongs right after the cell), and
   - the cells that this call has already placed after it, so that cells that name the same place keep the order of
     the text. *)
planAfter // beginDefinition;

planAfter[ record_Association, cells_List, plan_Association, cell_Association, outputs: True | False ] := With[
    {
        uuid     = cell[ "UUID" ],
        position = First @ FirstPosition[ plan[ "Order" ], cell[ "UUID" ] ],
        skipped  = If[ outputs, outputEntries[ record, cell, cells ][[ All, "UUID" ]], { } ]
    },
    <|
        plan,
        "Place"  -> position + LengthWhile[ Drop[ plan[ "Order" ], position ], MemberQ[ skipped, # ] || plan[ "Placed", # ] === uuid & ],
        "Anchor" -> uuid
    |>
];

planAfter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Evaluation*)

(* evaluate: true evaluates the Input and Code cells among the cells that a call wrote or named, in their order in the
   notebook, in the kernel of the evaluator tool, and replaces their outputs. Gives the text about each of them for
   the result. *)
evaluateCells // beginDefinition;

evaluateCells[ record_Association, uuids_List ] := With[
    { entries = Select[ readEntries[ record, Select[ notebookCells @ record, MemberQ[ uuids, #[ "UUID" ] ] & ], Infinity ], codeEntryQ ] },
    Which[
        entries === { },
            { },
        ! toolSelectedQ[ "WolframLanguageEvaluator" ],
            { "Nothing was evaluated: evaluate needs the Wolfram Language evaluator tool, which this chat does not have." },
        True,
            evaluateCell[ record, # ] & /@ entries
    ]
];

evaluateCells // endDefinition;


(* True for the entry of a code cell that is not excluded from chats *)
codeEntryQ // beginDefinition;
codeEntryQ[ entry_Association ] := MatchQ[ entry[ "Cell" ], Cell[ __, "Input" | "Code", ___ ] ] && ! chatExcludedQ @ entry[ "Cell" ];
codeEntryQ // endDefinition;


evaluationText // beginDefinition;
evaluationText[ { } ] := "Nothing was evaluated: the call wrote no Input or Code cell.";
evaluationText[ texts: { __String } ] := StringRiffle[ texts, "\n\n" ];
evaluationText // endDefinition;


(* The names of the symbols that code assigns at the top level of its statements: x in x = 1, x := 1, x[i_] := i and
   {x, y} = {1, 2}, also where several statements are separated by semicolons. CodeParser reads the code, so no
   symbol is made and nothing is evaluated.
   Not found: an assignment inside of another expression (Module, If, Do), a definition with a condition on its left
   side or by a function (SetAttributes, Options[f] = ...), up-values (f /: ..., ^=), and what is written in typeset
   boxes, which are read as a number here. *)
assignedSymbols // beginDefinition;

assignedSymbols[ code_String ] := Module[ { left },
    Needs[ "CodeParser`" -> None ];
    Select[
        Cases[
            (* left stands for the left side of an assignment while the symbols of it are found *)
            Flatten @ ReplaceRepeated[
                Replace[
                    CodeParser`CodeParse @ StringReplace[ code, RegularExpression[ "(?s)" <> $rawBoxesTag ] -> "0" ],
                    { _[ _, statements_List, ___ ] :> statements, _ -> { } }
                ],
                {
                    CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "CompoundExpression", _ ], statements_List, _ ] :> statements,
                    CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "Set" | "SetDelayed", _ ], { side_, _ }, _ ] :> left @ side,
                    left[ CodeParser`CallNode[ CodeParser`LeafNode[ Symbol, "List", _ ], items_List, _ ] ] :> left /@ items,
                    left[ CodeParser`CallNode[ head_, _, _ ] ] :> left @ head,
                    left[ CodeParser`LeafNode[ Symbol, name_String, _ ] ] :> name
                }
            ],
            _String
        ],
        StringMatchQ[ (LetterCharacter | DigitCharacter | "$" | "`").. ]
    ]
];

assignedSymbols // endDefinition;


(* Those of the names that are symbols without a value in the kernel although a code cell of the notebook assigns
   them: <| name -> the id of the cell that defines it |>. The names are what the statements of the cell of entry
   gave back: results that still hold such a symbol were made without the definitions of the notebook.
   - A symbol of the system counts as defined, and so does any symbol with a value or a definition of some kind. No
     symbol is made to tell, and nothing is evaluated.
   - The notebook is only read if a name has nothing in the kernel: its other code cells, of which only those are
     read as text that have such a name as a token and an assignment.
   - The cell that defines a symbol is the nearest cell above that assigns it, else the first one below.
   Not seen: a symbol that the results do not show (a plot of a function without a definition is an empty plot).
   Known gap: a symbol that a result is meant to hold as it is (the variable of Solve) is taken for missing too if
   another cell assigns it and the kernel has no value for it. *)
undefinedSymbols // beginDefinition;

undefinedSymbols[ record_Association, entry_Association, names: { ___String } ] := Module[ { missing, cells, above, code },
    missing = Select[
        DeleteDuplicates @ Select[ names, StringMatchQ[ $$symbolName ] ],
        ! NameQ @ # || ! ToExpression[
            #,
            InputForm,
            Function[ symbol, Context @ symbol === "System`" || ValueQ[ symbol, Method -> "SymbolDefinitionsPresent" ], HoldAllComplete ]
        ] &
    ];
    If[ missing === { }, Return[ <| |>, Module ] ];
    cells = notebookCells[ record, "Input" | "Code" ];
    above = TakeWhile[ cells, #[ "UUID" ] =!= entry[ "UUID" ] & ];
    code  = Select[
        cellEntries[ record, Join[ Reverse @ above, Drop[ cells, UpTo[ Length @ above + 1 ] ] ] ],
        Function[ cell,
            codeEntryQ @ cell && With[ { tokens = Cases[ cell[ "Cell" ], _String, Infinity ] },
                MatchQ[ cell[ "Cell" ], Cell[ _String, ___ ] ] || IntersectingQ[ tokens, missing ] && IntersectingQ[ tokens, { "=", ":=" } ]
            ]
        ]
    ];
    KeyTake[
        Association @ Reverse @ Flatten[ Thread[ assignedSymbols @ cellBody @ cellText[ #[ "Cell" ], Infinity ] -> #[ "ID" ] ] & /@ code ],
        missing
    ]
];

undefinedSymbols // endDefinition;

$$symbolName = (LetterCharacter | "$") ~~ (LetterCharacter | DigitCharacter | "$" | "`")...;


(* What the result says about the symbols of undefinedSymbols for the cell with the id: which they are, the cells
   that define them, and how those are evaluated first. A call evaluates its cells in the order of the notebook
   (evaluateCells), so a defining cell that is below the cell is evaluated after it, which the text says. *)
undefinedText // beginDefinition;

undefinedText[ _String, <| |> ] := "";

undefinedText[ id_String, missing_Association ] := StringJoin[
    " Its result still has symbols that the kernel has no value for: ",
    StringRiffle[ KeyValueMap[ #1 <> " (" <> #2 <> " defines it)" &, missing ], ", " ],
    ". To evaluate those cells first, name them with this one in one call: ",
    "<cell id='" <> # <> "'/>" & /@ Append[ DeleteDuplicates @ Values @ missing, id ],
    ". Cells are evaluated in the order of the notebook, whatever the order of the tags is: a defining cell that is ",
    "below this one only counts for the next call."
];

undefinedText // endDefinition;


(* Evaluates a cell statement by statement, as the front end does. Its outputs (outputEntries) are replaced by an
   Output cell for each statement that gives something, whatever that is: also a statement that is its own result
   (Sin[x], a list of numbers). Unless the evaluator is the user's session, the new cells also have the style
   "EvaluationUnmatched", the front end's graying of an output that its input did not give in that session. A new
   output has the label of the output that it replaces if the cell has as many outputs as before.
   The outputs stay as they are
   - if a statement gives no boxes (it ran out of time, or its boxes would run code outside of the sandbox),
   - if the evaluator is the user's session, which only has the definitions that the user has evaluated, and what
     the statements gave still holds a symbol that a cell of the notebook defines and the kernel has no value for
     (undefinedSymbols). The text then says once for the cell which cells to evaluate first. A sandboxed evaluator
     never has the notebook's definitions, and what it gives is written.
   Known gap: the statements have no In and Out line, so % is not the output before. *)
evaluateCell // beginDefinition;

evaluateCell[ record_Association, entry_Association ] := Module[
    { id, outputs, results, failure, printed, missing, boxes, labels, new },
    id      = entry[ "ID" ];
    outputs = outputEntries[ record, entry ];
    If[ lockedEntries[ record, outputs ] =!= { },
        Return[ id <> " was not evaluated: an output of it is locked in the notebook (not deletable), so it can't be replaced.", Module ]
    ];
    results = { };
    failure = None;
    Do[
        Replace[
            evaluateToBoxes[ statement, "StandardForm", "ToBoxes" ],
            {
                result: KeyValuePattern[ "Boxes" -> _ ] :> AppendTo[ results, result ],
                other_ :> (failure = other; Break[ ])
            }
        ],
        { statement, sandboxStatements @ cellCode @ entry }
    ];
    printed = StringTrim @ StringRiffle[ printedOutput /@ Lookup[ results, "Output", { } ], "\n" ];
    If[ StringLength @ printed > $outputLength, printed = StringTake[ printed, $outputLength ] <> "\[Ellipsis]" ];
    boxes   = Lookup[ results, "Boxes", { } ];
    missing = If[ useSessionQ[ ], undefinedSymbols[ record, entry, Cases[ boxes, _String, Infinity ] ], <| |> ];
    If[ failure =!= None || missing =!= <| |>,
        Return[
            StringJoin[
                id,
                If[ failure === None,
                    " was evaluated, but its outputs are as they were.",
                    " was not evaluated to its end, and its outputs are as they were. " <>
                        Replace[ failureMessage[ failure, "Cell " <> id ], "" -> "The evaluator gave no result." ]
                ],
                undefinedText[ id, missing ],
                If[ printed === "", "", If[ failure === None, "\nIt printed:\n", "\nBefore that it printed:\n" ] <> printed ]
            ],
            Module
        ]
    ];
    boxes  = DeleteCases[ boxes, "Null" ];
    labels = Cases[ #, HoldPattern[ CellLabel -> _String ] ] & /@ Cases[ outputs[[ All, "Cell" ]], Cell[ __, "Output", ___ ] ];
    new    = MapThread[
        Cell[ BoxData @ #1, "Output", Sequence @@ If[ useSessionQ[ ], { }, { "EvaluationUnmatched" } ], Sequence @@ #2, ExpressionUUID -> CreateUUID[ ] ] &,
        { boxes, If[ Length @ labels === Length @ boxes, labels, ConstantArray[ { }, Length @ boxes ] ] }
    ];
    applyWrites[
        record,
        Join[
            If[ outputs === { }, { }, { { "Delete", outputs[[ All, "UUID" ]] } } ],
            If[ new === { }, { }, { { "Insert", entry[ "UUID" ], "After", new } } ]
        ],
        { }
    ];
    StringJoin[
        "Evaluated ", id,
        If[ new === { },
            ": it gives no output.",
            ". Its output:\n" <> StringRiffle[
                readEntries[ record, Select[ notebookCells @ record, MemberQ[ cellUUID /@ new, #[ "UUID" ] ] & ], $cellLength ][[ All, "Text" ]],
                "\n\n"
            ]
        ],
        If[ printed === "", "", "\nIt printed:\n" <> printed ]
    ]
];

evaluateCell // endDefinition;


(* The outputs of a cell: the generated cells right after it among the cells of the notebook, which are read one at a
   time. A cell that the user excluded from chats is not replaced, so the outputs end before it. *)
outputEntries // beginDefinition;

outputEntries[ record_Association, entry_Association ] := outputEntries[ record, entry, notebookCells @ record ];

outputEntries[ record_Association, entry_Association, cells_List ] := Module[ { outputs, next },
    outputs = { };
    Do[
        next = First @ cellEntries[ record, { cell } ];
        If[ generatedCellQ @ next[ "Cell" ] && ! chatExcludedQ @ next[ "Cell" ], AppendTo[ outputs, next ], Break[ ] ],
        { cell, Drop[ cells, First @ FirstPosition[ cells[[ All, "UUID" ]], entry[ "UUID" ] ] ] }
    ];
    outputs
];

outputEntries // endDefinition;


(* The code of a cell as the evaluator takes it: the body of the cell, with each box that it holds as an expression
   URI of the box, which the evaluator reads as the expression that the box stands for. Known gap: a box that reading
   did not record stays a tag, which is no code. *)
cellCode // beginDefinition;

cellCode[ entry_Association ] := StringReplace[
    entry[ "Body" ],
    RegularExpression[ "(?s)" <> $rawBoxesTag ] :> Replace[
        Lookup[ Lookup[ $cellOriginals, entry[ "ID" ], <| |> ], "$1", None ],
        { None :> "$0", boxes_ :> MakeExpressionURI[ "expression", "boxes", RawBoxes @ boxes ] }
    ]
];

cellCode // endDefinition;


(* What the evaluator printed for a statement: its output text is that, a blank line and the result *)
printedOutput // beginDefinition;

printedOutput[ output_String ] :=
    Replace[ StringSplit[ output, "\n\n" ], { { printed__, _ } :> StringRiffle[ { printed }, "\n\n" ], _ -> "" } ];

printedOutput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ShowChanges*)

(* Shows the source as a comparison against the snapshot (in the source notebook itself; a source file is opened; a
   new notebook is shown as it is), then closes the snapshot (the front end deletes its file). If the comparison can't
   be shown, the snapshot stays open. The comparison applies the edits to the notebook, and the cells that then show a
   change are what the user accepts or rejects: if there is none, the result says that. *)
showChanges // beginDefinition;

showChanges[ args_Association ] := Module[ { handle, record, source, title, result },
    handle = resolveNotebook[ args[ "notebook" ], False ];
    record = $snapshots @ handle;
    source = record[ "Source" ];
    title  = quoted @ inlineText @ record[ "Title" ];
    If[ record[ "Edits" ] === None,
        Return[ handle <> " has no edits to show. CloseNotebook closes it.", Module ]
    ];
    (* The user may have excluded the notebook from chats since the snapshot was made: *)
    If[ Replace[ source, { nb_NotebookObject :> TrueQ @ notebookFrontEnd[ "Excluded", nb ], file_String :> excludedFileQ @ file, _ -> False } ],
        toolError[ $excludedNotebookText <> " `2` is still open: close it with CloseNotebook.", title, handle ]
    ];
    (* A new notebook is shown whole, and so is a snapshot of which the changed cells alone do not do: *)
    result = Replace[
        If[ source === None, None, notebookFrontEnd[ "ShowDiff", source, record[ "Notebook" ], record[ "Edits" ] ] ],
        None | Failure[ "InvalidSnapshot", _ ] :> notebookFrontEnd[ "ShowDiff", source, withRecord[ record, comparedNotebook ] ]
    ];
    If[ FailureQ @ result,
        toolError[
            "The changes of `1` could not be shown: `2` It is still open.",
            notebookLabel @ record,
            Replace[ failureMessage @ result, "" -> "the comparison failed." ]
        ]
    ];
    closeSnapshot @ handle;
    StringJoin[
        Which[
            source === None,
                "The user now sees the new notebook.",
            result === 0,
                title <> " shows no diff, since no cell differs in content, style or options. A change of cell tags is \
applied as it is, a change of a cell label alone is not applied, and any other change the notebook already had. The \
user has nothing to accept or reject.",
            True,
                "The user now sees " <> title <> " as a diff against your edits, and accepts or rejects each change there."
        ],
        " ", handle, " is closed."
    ]
];

showChanges // endDefinition;


(* What the source of a snapshot is compared against: the cells of the snapshot in their order, as a Notebook
   expression whose cells have their ExpressionUUIDs. A cell of an open source that no call changed is read from the
   source, so that it compares as unchanged: the snapshot's copy of it was saved and opened again, which can group the
   boxes of code differently.
   CellDiff does not mark a cell that only moved, and its Reject All leaves such a cell where it is. So a moved cell is
   given to it as another cell (movedCell), which it shows as a cell deleted at the old place and one inserted at the
   new place. The moved cells are those outside of the longest run of cells that both notebooks have in the same order.
   Known gaps: the cells of a file that is not open are all the snapshot's. The expression has no cell groups, so a
   comparison that rewrites the whole notebook (CellDiff does that for moved cells, or if most cells changed) leaves
   closed groups open. *)
comparedNotebook // beginDefinition;

comparedNotebook[ record_Association ] := Module[ { cells, uuids, source, own, kept, read, order, moved },
    cells  = notebookCells @ record;
    uuids  = cells[[ All, "UUID" ]];
    (* own: the cells of an open source that the snapshot has too, in the order of the source; kept: those of them that
       no call changed, read from the source *)
    { own, kept } = If[ MatchQ[ record[ "Source" ], _NotebookObject ],
        source = <| record, "Notebook" -> record[ "Source" ] |>;
        With[ { entries = Select[ notebookCells @ source, MemberQ[ uuids, #[ "UUID" ] ] & ] },
            { entries[[ All, "UUID" ]], cellEntries[ source, Select[ entries, ! MemberQ[ record[ "Edits" ], #[ "UUID" ] ] & ] ] }
        ],
        { { }, { } }
    ];
    read  = cellEntries[ record, Select[ cells, ! MemberQ[ kept[[ All, "UUID" ]], #[ "UUID" ] ] & ] ];
    order = DeleteMissing @ Lookup[ AssociationThread[ own -> Range @ Length @ own ], uuids ];
    moved = own[[ Complement[ order, LongestOrderedSequence @ order ] ]];
    Notebook[
        If[ MemberQ[ moved, #[ "UUID" ] ], movedCell @ #[ "Cell" ], withUUID[ #[ "Cell" ], #[ "UUID" ] ] ] & /@
            Lookup[ Association[ #[ "UUID" ] -> # & /@ Join[ kept, read ] ], uuids ]
    ]
];

comparedNotebook // endDefinition;


(* A moved cell as CellDiff gets it: with another ExpressionUUID, so that it is not paired with the cell at the old
   place by its identity, and with CellDiff's tag of a cell that shows a change, so that it is not paired with it by
   its content either (the tags of a cell are part of what CellDiff aligns cells by). CellDiff gives an inserted cell
   that tag anyway, and takes it off when the user resolves the change. *)
movedCell // beginDefinition;

movedCell[ cell_Cell ] := Join[
    DeleteCases[ cell, (ExpressionUUID | CellObject | CellTags) -> _ ],
    Cell[ CellTags -> Flatten @ { Cases[ cell, (CellTags -> tags_) :> tags ], $diffTag }, ExpressionUUID -> CreateUUID[ ] ]
];

movedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CloseNotebook*)
closeNotebook // beginDefinition;

closeNotebook[ args_Association ] := With[ { handle = resolveNotebook[ args[ "notebook" ], False ] },
    closeSnapshot @ handle;
    "Closed " <> handle <> "; its edits were discarded."
];

closeNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
