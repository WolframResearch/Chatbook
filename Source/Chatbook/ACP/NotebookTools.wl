(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`NotebookTools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ACP`Common`" ];

(* The notebook tools of the agent (see docs/acp-window.md, "Notebook tools"): acpNotebookTools[] gives the LLMTools of
   the MCP server (MCP.wl). The agent never edits the user's notebooks: OpenNotebook has the front end make a hidden
   snapshot of a notebook (or of a .nb file, or a new empty one), the reads and edits go to the snapshot, and ShowChanges
   shows the user their notebook as a CellDiff comparison against the edited snapshot, where they accept or reject the
   changes. A tool's function takes the arguments as an Association and gives a String (JSON for ListNotebooks, JSON
   and then the cells for OpenNotebook, text otherwise), or a Failure whose "String" is an error text for the agent
   (AgentTools turns it into a tool result with isError).

   Rules:
   * The front end does the work: every front end operation goes through notebookFrontEnd (the snapshot, cell text and
     cell text edit packets, NotebookFileName, NotebookSave, NotebookClose, and CellDiff's ShowNotebookDiff), so that
     tests can replace it with a made-up front end. The front end reads and writes cells in the agent text form
     (FrontEnd docs/NotebookMCP/AgentTextForm.md); the tools add the marker line (* ::Style:: #id *) in front of each
     cell's content and never parse or convert content themselves.
   * Front end calls must not run in a SocketListen or reader handler (R2): the tools run in MCP.wl's drain (the main
     link, or the pump for clients that are not ACP windows). Without a front end ($FrontEnd === Null), ListNotebooks
     lists no notebooks and the other tools give an error.
   * Snapshots: $snapshots holds each open snapshot by its handle ("s1", "s2", ...): its NotebookObject, its file, its
     source (a listed NotebookObject, a .nb file or None) and its cell ids. Edits only go to snapshots. Only the
     notebooks that ListNotebooks lists, and .nb files, can be snapshot.
   * Ids: a notebook's id is the start of its UUID, as before (uniqueIDs; prefixes of at least $minPrefixLength
     characters, exact window titles and files are accepted). A snapshot's cells are numbered "c1", "c2", ... in document
     order when the snapshot is opened, and new cells get the next numbers: an id stays with its cell for the life of the
     snapshot. The agent never sees NotebookObject[...] or CellObject[...] expressions, and nothing it sends is ever
     ToExpression'd.
   * Nothing the agent writes may run code when it is shown (ShowChanges shows it in the user's notebook):
     requireInertText refuses linear syntax escapes and, inside box wrappers, dynamic boxes and options that hold code.
   * Errors are texts for the agent; internal failures are logged as "NotebookToolFailed" (acpLog) and the agent only
     learns that the tool failed. A Failure of the front end's edit packet is shown with its tag and message.
   * The markdown of attached notebooks (acpNotebookMarkdown, acpDefusedCells, for Attachments.wl) is also defined
     here: it is not used by the tools. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$idLength          = 8;     (* characters of a notebook id (more where they are needed to make it unique) *)
$minPrefixLength   = 6;     (* the shortest start of a notebook id that is accepted *)
$previewLength     = 80;    (* characters of each cell in GetOutline by default *)
$maxPreviewLength  = 2000;  (* at most *)
$outlineLimit      = 300;   (* cells in one GetOutline result by default *)
$maxOutlineLimit   = 2000;  (* at most *)
$outlineHeadings   = "Title" | "Subtitle" | "Chapter" | "Section" | "Subsection" | "Subsubsection";
$readBudget        = 40000; (* characters in one result that shows cells (at least one is shown); opencode cuts a tool
                               result at about 50 KB and tells the model to use sub-agents on the rest *)
$searchLimit       = 50;    (* matches that SearchNotebook shows by default *)
$maxSearchLimit    = 500;   (* at most *)
$searchTimeLimit   = 10;    (* seconds that one search may take *)
$snippetLength     = 160;   (* characters of the line of a match that SearchNotebook shows *)
$maxQuotedLength   = 80;    (* characters of an argument that an error message repeats *)

(* The tools that change notebooks the user has open: ShowChanges shows the diff in the user's notebook (or opens the
   source file visibly). The edit tools only change snapshots. OpenCode asks before these (MCP.wl's
   acpMCPToolPermissions), and the permission panel shows them first. *)
$acpNotebookEditTools = { "ShowChanges" };

(* The notebook comparison of CellDiff (FrontEnd docs/CellDiff/CellDiffNotebookDiff.wl), which defines
   CellDiffNotebookDiff`ShowNotebookDiff; the environment variable CELLDIFF_NOTEBOOKDIFF_FILE names another copy. It
   loads CellDiffControlStyles.wl from its own directory. A development path until the comparison is part of a
   release. *)
$defaultNotebookDiffFile = "/System/Volumes/Data/Development/WRI/FE_diff2/FrontEnd_diff2/docs/CellDiff/CellDiffNotebookDiff.wl";
$notebookDiffFunction    = "CellDiffNotebookDiff`ShowNotebookDiff";

(* The marker line of a cell, with or without an id: an edit or a cell's text never holds one *)
$$markerLine = RegularExpression[ "(?m)^[ \\t]*\\(\\* ::[^\\n]*::[ \\t]*(?:#\\S+[ \\t]*)?\\*\\)[ \\t]*$" ];

(* Agent text that would run code when the front end shows it. Linear syntax: its characters, their escapes, and the
   \! and \* escapes (a backslash that is not itself escaped); \* is the box constructor, which evaluates boxes. *)
$$linearSyntaxText = RegularExpression[
    "[\\x{f7c0}-\\x{f7cd}]|(?<!\\\\)(?:\\\\\\\\)*\\\\(?:[!*]|:[fF]7[cC][0-9a-dA-D]|\\|00[fF]7[cC][0-9a-dA-D])"
];

(* Inside a box wrapper (strings left out): boxes that run code when shown, and options that hold code *)
$$codeInWrapper = RegularExpression[ StringJoin[
    "(?<![\\w`$])(?:",
    "(?:DynamicBox|DynamicModuleBox|DynamicWrapperBox|ActionMenuBox|EventHandlerTag|Dynamic|DynamicModule|DynamicWrapper)",
    "\\s*\\[",
    "|",
    "(?:ButtonFunction|CellDynamicExpression|CellEpilog|CellEvaluationFunction|CellEventActions|CellProlog|",
    "Deinitialization|Initialization|InterpretationFunction|NotebookDynamicExpression|NotebookEventActions)",
    "\\s*(?:->|:>|\\\\\\[Rule\\]|\\\\\\[RuleDelayed\\])",
    ")"
] ];

$$wrapper = "\:2e22" ~~ Except[ "\:2e23" ]... ~~ "\:2e23";

$toolErrorTag = "Wolfram`Chatbook`ACP`NotebookTools`ToolError";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*State*)

(* Not reset if this file is reloaded during development. In the MX build they start out empty.
     $snapshots      handle -> <| "Handle", "Notebook" -> the snapshot's NotebookObject, "File" -> its file (or None),
                     "Source" -> NotebookObject | file | None, "SourceID" -> the source's notebook id (or None),
                     "Title", "IDs" -> <| CellObject -> "c1", ... |>, "NextID", "Edited" (edited since it was opened),
                     "Unsaved" (edited since it was last saved) |>
     $snapshotCount  the number of the last handle *)
If[ ! AssociationQ @ $snapshots, $snapshots = <| |> ];
If[ ! IntegerQ @ $snapshotCount, $snapshotCount = 0 ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tools*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpNotebookTools*)

(* The notebook tools as LLMTools, in the order of $toolSpecs. LLMTool interprets the lists of objects (SetCells'
   cells, EditInCell's edits, InsertCells' newCells) with Interpreter, whose first CompoundElement in a front end's
   kernel takes about 0.5 s: one is interpreted here, when the server starts, instead of in the agent's first edit. *)
acpNotebookTools // beginDefinition;

acpNotebookTools[ ] := (
    Interpreter[ RepeatingElement @ CompoundElement @ <| "cell" -> "String", "text" -> "String" |> ][
        { <| "cell" -> "c1", "text" -> "" |> }
    ];
    KeyValueMap[ LLMTool @ <| "Name" -> #1, #2, "Options" -> { } |> &, $toolSpecs ]
);

acpNotebookTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Instructions*)

(* The agent text form, for the server's instructions (MCP.wl) and ReadCells' description. The strings hold the text
   \[Name] (an escaped backslash), which the code inspector takes for an unknown long name. *)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::UnrecognizedLongName:: *)
$acpNotebookNotation = "\
Cell text notation: a cell is a marker line (* ::Style:: #id *) followed by its content. #id (e.g. #c3) names the \
cell in the other tools; marker lines are not content, and no edit includes one. Code cells hold Wolfram Language \
input as typed. x\:02c42 is a superscript, a\:02c51 a subscript and 1\:20442 a fraction (only between single tokens); \
any other 2D box is written as its FullForm in \:2e22 \:2e23, e.g. \:2e22SqrtBox[\"x\"]\:2e23 or \
\:2e22SubscriptBox[\"a\", RowBox[{\"i\", \"+\", \"1\"}]]\:2e23, with no short forms or other \:2e22 \:2e23 inside. \
\:2e22FE`ElidedBox[n, \"Head\", size]\:2e23 stands for graphics or a large box: keep it unchanged. Text cells are \
wrapped in (* *); inside them \\ is written \\\\, a literal *) is \:2e22\"*)\"\:2e23, and styled text is \
\:2e22StyleBox[...]\:2e23. Wolfram's named characters are written \\[Name] (e.g. \\[DifferentialD], \\[Rule]): always \
write them that way, never as raw characters. Other Unicode characters (Greek letters, \:2192) are written as they \
are. Content that would run code when shown (dynamic boxes, button functions) is refused. Math is typeset: in a text \
cell a formula is an inline formula cell, written \:2e22$boxes\:2e23, which is short for \:2e22Cell[BoxData[FormBox[\
boxes, TraditionalForm]], \"InlineFormula\"]\:2e23 (boxes in FullForm), e.g. \:2e22$FractionBox[RowBox[{\
\"\[PartialD]\", \"L\"}], RowBox[{\"\[PartialD]\", OverscriptBox[\"q\", \".\"]}]]\:2e23, and a DisplayFormula cell holds \
\:2e22FormBox[..., TraditionalForm]\:2e23. Keep a notebook's typesetting when you rewrite it: write new math as such \
boxes, never as plain text such as dq/dt, and keep displayed equations in DisplayFormula cells.";
(* :!CodeAnalysis::EndBlock:: *)

$acpNotebookWorkflow = "\
These tools edit Wolfram notebooks through the user's Wolfram front end (desktop app); nothing is evaluated. Use them \
instead of editing .nb files. Your edits never change the user's notebook directly: OpenNotebook makes a hidden \
snapshot of a notebook (unsaved changes included) and gives its handle (s1, s2, ...), which the other tools take. \
Workflow: OpenNotebook (by its file when the user names one; otherwise ListNotebooks first), which gives the \
notebook's cells too (for a long notebook, an outline of its headings: then read the sections you change with \
ReadCells, as ranges of cells) -> EditInCell, SetCells, InsertCells, DeleteCells -> ShowChanges, which saves the snapshot and \
shows the user their notebook as a diff against it, to accept or reject change by change. CloseNotebook discards a \
snapshot instead. Work quickly: each of your turns takes seconds, and an edit's time is mostly the text you write. Edit \
independent cells in one turn: one SetCells call for all the cells you rewrite (its delete deletes the outputs they \
make stale in the same call), parallel calls for the rest. For a \
cell that changes only in part, use EditInCell with short oldText and newText instead of rewriting the cell. A \
notebook edit needs no todo list. If you have \
WolframLanguageEvaluator, check code with it directly; WolframLanguageContext is not needed for notebook edits.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Descriptions*)
$listNotebooksDescription = "\
Lists the notebooks open in the user's Wolfram front end, front to back (the first one is the notebook the user is \
working in, \"this notebook\"), and the open snapshots, as JSON {notebooks: [{id, title, file, modified, cells, \
selected, snapshot}], snapshots: [{notebook, title, source, edited, unsaved}]}. Palettes, dialogs, help pages, chat \
windows and notebooks the user excluded from AI are not listed.";

$openNotebookDescription = "\
Opens a hidden snapshot of a notebook to edit: a notebook open in the front end (its id from ListNotebooks, its exact \
window title, or its file; unsaved changes included) or a .nb file that is not open. Without notebook, it starts a \
new, empty notebook. Returns JSON {notebook, title, source, cells}, where notebook is the snapshot's handle for the \
other tools, and then the cells as ReadCells shows them, so that no ReadCells call is needed, or, for a notebook too \
long to show whole, an outline of its headings with the range of cells under each. A notebook with an open snapshot \
gives that snapshot again. " <> $acpNotebookWorkflow;

$getOutlineDescription = "\
Gives a map of a snapshot: for each cell, its marker line (* ::Style:: #id *) and the start of its content (preview \
characters, default 80, on one line), indented by the depth of its cell group; ::Closed marks a closed group. Long \
notebooks come in parts (offset, limit).";

$readCellsDescription = "\
Reads cells of a snapshot: each cell as its marker line and its content, exactly as EditInCell matches it. Without \
cells, it reads the whole notebook (up to 40000 characters); cells also takes ranges such as c10-c20. Graphics and \
large boxes are placeholders unless full is true. " <> $acpNotebookNotation;

$searchNotebookDescription = "\
Finds text in the cells of a snapshot: a literal string, or with regex true a regular expression (PCRE), in each \
cell's content as ReadCells shows it, so a match can be copied into EditInCell's oldText. cells and styles limit the \
search. Gives one line per match: #id (Style) line:column: the line of the match.";

$editInCellDescription = "\
Edits the content of one cell of a snapshot by exact text replacement, like a file edit tool: each edit replaces \
oldText, which must occur exactly count times (default 1) in the cell's content, with newText. The edits are applied \
in order and the cell is parsed once after all of them; either all of them apply or none. To delete text, use an \
empty newText; to insert, put the text next to the insertion point in oldText and that text with the addition in \
newText. Copy oldText exactly from ReadCells or SearchNotebook; it never includes a marker line. Gives the cell's new \
content.";

$setCellsDescription = "\
Replaces the whole content of cells of a snapshot, and optionally their styles, in one call: each item is {cell, \
text, style}, text in the cell text notation without the marker line (text cells wrapped in (* *)). The items are \
applied in order, all or none. Use one SetCells call for all the cells you rewrite, with delete for the cells to \
delete with them (such as outputs that the new cells make stale). Rewriting a whole cell is slow: for a cell that \
changes only in part, EditInCell is much faster. Gives the ids of the cells it set and deleted.";

$insertCellsDescription = "\
Inserts new cells into a snapshot, after or before the cell with the given id, or without one at the end (with \
position \"before\": at the beginning). Each new cell is {style, text}, its text in the cell text notation without a \
marker line (text cells wrapped in (* *)). Gives the new cells with their ids.";

$deleteCellsDescription = "Deletes cells from a snapshot.";

$saveNotebookDescription = "\
Saves the edits of a snapshot (to the snapshot, never to the user's notebook). ShowChanges saves first, so this is \
only needed to keep a snapshot's edits without showing them.";

$showChangesDescription = "\
Shows the user their notebook as a diff against the snapshot (unsaved edits are saved first), where they accept or \
reject each change, and closes the snapshot. Call it once, when the work on the notebook is done; a file that is not \
open is opened.";

$closeNotebookDescription = "Closes a snapshot and discards its edits, without showing them to the user.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Parameters*)
parameter // beginDefinition;

parameter[ name_String, interpreter_, help_String, required_ ] :=
    name -> <| "Interpreter" -> interpreter, "Help" -> help, "Required" -> required |>;

parameter // endDefinition;

$snapshotParameter = parameter[ "notebook", "String", "The snapshot's handle from OpenNotebook, e.g. s1", True ];
$cellParameter     = parameter[ "cell", "String", "The id of the cell, e.g. c3", True ];

cellsParameter // beginDefinition;

cellsParameter[ required_, help_String ] :=
    parameter[ "cells", "String", "The ids of the cells, separated by commas, and ranges of ids, e.g. \"c3, c4, c10-c20\"" <> help, required ];

cellsParameter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Specifications*)
$toolSpecs = <|
    "ListNotebooks" -> <|
        "DisplayName" -> "List Notebooks",
        "Description" -> $listNotebooksDescription,
        "Function"    -> listNotebooksTool,
        "Parameters"  -> { }
    |>,
    "OpenNotebook" -> <|
        "DisplayName" -> "Open Notebook",
        "Description" -> $openNotebookDescription,
        "Function"    -> openNotebookTool,
        "Parameters"  -> {
            parameter[
                "notebook",
                "String",
                "\
An open notebook (its id from ListNotebooks, its exact window title or its file) or the full path of a .nb file; \
omit it for a new, empty notebook",
                False
            ]
        }
    |>,
    "GetOutline" -> <|
        "DisplayName" -> "Get Outline",
        "Description" -> $getOutlineDescription,
        "Function"    -> getOutlineTool,
        "Parameters"  -> {
            $snapshotParameter,
            parameter[ "preview", "Integer", "Characters of each cell's content to show (default 80)", False ],
            parameter[ "offset", "Integer", "The number of the first cell (default 1)", False ],
            parameter[ "limit", "Integer", "The largest number of cells (default 300)", False ]
        }
    |>,
    "ReadCells" -> <|
        "DisplayName" -> "Read Cells",
        "Description" -> $readCellsDescription,
        "Function"    -> readCellsTool,
        "Parameters"  -> {
            $snapshotParameter,
            cellsParameter[ False, "; omit it to read the whole notebook" ],
            parameter[ "full", "Boolean", "Show graphics and large boxes in full instead of placeholders", False ]
        }
    |>,
    "SearchNotebook" -> <|
        "DisplayName" -> "Search Notebook",
        "Description" -> $searchNotebookDescription,
        "Function"    -> searchNotebookTool,
        "Parameters"  -> {
            $snapshotParameter,
            parameter[ "query", "String", "The text to find, or a regular expression with regex true", True ],
            parameter[ "regex", "Boolean", "Whether query is a regular expression (default false)", False ],
            cellsParameter[ False, "; omit it to search every cell" ],
            parameter[ "styles", "String", "Cell styles to search, separated by commas, e.g. \"Input, Text\"", False ],
            parameter[ "limit", "Integer", "The largest number of matches to show (default 50)", False ]
        }
    |>,
    "EditInCell" -> <|
        "DisplayName" -> "Edit In Cell",
        "Description" -> $editInCellDescription,
        "Function"    -> editInCellTool,
        "Parameters"  -> {
            $snapshotParameter,
            $cellParameter,
            parameter[
                "edits",
                RepeatingElement @ CompoundElement @ <| "oldText" -> "String", "newText" -> "String", "count" -> "Integer" |>,
                "\
The edits, applied in order: {oldText, newText, count}; oldText must occur exactly count times (default 1)",
                True
            ]
        }
    |>,
    "SetCells" -> <|
        "DisplayName" -> "Set Cells",
        "Description" -> $setCellsDescription,
        "Function"    -> setCellsTool,
        "Parameters"  -> {
            $snapshotParameter,
            parameter[
                "cells",
                RepeatingElement @ CompoundElement @ <| "cell" -> "String", "text" -> "String", "style" -> "String" |>,
                "\
The cells, in order: {cell, text, style}, e.g. {cell: \"c3\", text: \"(*New words*)\"}; omit style to keep the style",
                True
            ],
            parameter[
                "delete",
                "String",
                "The ids of cells to delete in the same edit, separated by commas, such as outputs that the new cells make stale",
                False
            ]
        }
    |>,
    "InsertCells" -> <|
        "DisplayName" -> "Insert Cells",
        "Description" -> $insertCellsDescription,
        "Function"    -> insertCellsTool,
        "Parameters"  -> {
            $snapshotParameter,
            parameter[
                "newCells",
                RepeatingElement @ CompoundElement @ <| "style" -> "String", "text" -> "String" |>,
                "The new cells, in order: {style, text}, e.g. {style: \"Input\", text: \"x = 1\"}",
                True
            ],
            parameter[ "cell", "String", "The id of the cell to insert after or before; omit it for the end", False ],
            parameter[ "position", "String", "\"after\" (the default) or \"before\" the cell", False ]
        }
    |>,
    "DeleteCells" -> <|
        "DisplayName" -> "Delete Cells",
        "Description" -> $deleteCellsDescription,
        "Function"    -> deleteCellsTool,
        "Parameters"  -> { $snapshotParameter, cellsParameter[ True, "" ] }
    |>,
    "SaveNotebook" -> <|
        "DisplayName" -> "Save Notebook",
        "Description" -> $saveNotebookDescription,
        "Function"    -> saveNotebookTool,
        "Parameters"  -> { $snapshotParameter }
    |>,
    "ShowChanges" -> <|
        "DisplayName" -> "Show Changes",
        "Description" -> $showChangesDescription,
        "Function"    -> showChangesTool,
        "Parameters"  -> { $snapshotParameter }
    |>,
    "CloseNotebook" -> <|
        "DisplayName" -> "Close Notebook",
        "Description" -> $closeNotebookDescription,
        "Function"    -> closeNotebookTool,
        "Parameters"  -> { $snapshotParameter }
    |>
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool functions*)

(* The functions of the LLMTools: they take the arguments (an Association; LLMTool gives Missing["NoInput"] for
   optional parameters that were not given, and a Failure for a value its interpreter refused) and can also be called
   directly *)
listNotebooksTool  // beginDefinition;
listNotebooksTool[ _ ] := toolResult[ "ListNotebooks", listNotebooks[ ] ];
listNotebooksTool  // endDefinition;

openNotebookTool   // beginDefinition;
openNotebookTool[ args_ ] := toolResult[ "OpenNotebook", openNotebook @ toolArguments @ args ];
openNotebookTool   // endDefinition;

getOutlineTool     // beginDefinition;
getOutlineTool[ args_ ] := toolResult[ "GetOutline", getOutline @ toolArguments @ args ];
getOutlineTool     // endDefinition;

readCellsTool      // beginDefinition;
readCellsTool[ args_ ] := toolResult[ "ReadCells", readCells @ toolArguments @ args ];
readCellsTool      // endDefinition;

searchNotebookTool // beginDefinition;
searchNotebookTool[ args_ ] := toolResult[ "SearchNotebook", searchNotebook @ toolArguments @ args ];
searchNotebookTool // endDefinition;

editInCellTool     // beginDefinition;
editInCellTool[ args_ ] := toolResult[ "EditInCell", editInCell @ toolArguments @ args ];
editInCellTool     // endDefinition;

setCellsTool       // beginDefinition;
setCellsTool[ args_ ] := toolResult[ "SetCells", setCells @ toolArguments @ args ];
setCellsTool       // endDefinition;

insertCellsTool    // beginDefinition;
insertCellsTool[ args_ ] := toolResult[ "InsertCells", insertCells @ toolArguments @ args ];
insertCellsTool    // endDefinition;

deleteCellsTool    // beginDefinition;
deleteCellsTool[ args_ ] := toolResult[ "DeleteCells", deleteCells @ toolArguments @ args ];
deleteCellsTool    // endDefinition;

saveNotebookTool   // beginDefinition;
saveNotebookTool[ args_ ] := toolResult[ "SaveNotebook", saveNotebook @ toolArguments @ args ];
saveNotebookTool   // endDefinition;

showChangesTool    // beginDefinition;
showChangesTool[ args_ ] := toolResult[ "ShowChanges", showChanges @ toolArguments @ args ];
showChangesTool    // endDefinition;

closeNotebookTool  // beginDefinition;
closeNotebookTool[ args_ ] := toolResult[ "CloseNotebook", closeNotebook @ toolArguments @ args ];
closeNotebookTool  // endDefinition;


toolArguments // beginDefinition;
toolArguments[ args_Association ] := args;
toolArguments[ _ ] := <| |>;
toolArguments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Results and Errors*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolResult*)

(* The result of a tool: the text that eval gives, or a Failure with an error text, thrown by toolError or given for an
   internal failure (Chatbook's failures are caught by catchAlways, anything else thrown by acpCatchAll). Aborts are
   not caught: the caller decides what an aborted tool call gives. *)
toolResult // beginDefinition;
toolResult // Attributes = { HoldRest };

toolResult[ name_String, eval_ ] := Replace[
    acpCatchAll[ catchAlways @ eval, thrownResult[ name, #1, #2 ] & ],
    {
        text_String            :> text,
        failure: $$toolFailure :> failure,
        other_                 :> internalToolFailure[ name, other ]
    }
];

toolResult // endDefinition;

$$toolFailure = Failure[ "NotebookToolError", _Association ];


thrownResult // beginDefinition;
thrownResult[ _String, message_String, tag_ ] /; tag === $toolErrorTag := toolFailure @ message;
thrownResult[ name_String, value_, tag_ ] := internalToolFailure[ name, <| "Value" -> value, "Tag" -> tag |> ];
thrownResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolFailure*)

(* The "String" is what the agent sees (AgentTools' tool result); the message template only shows it as it is *)
toolFailure // beginDefinition;

toolFailure[ message_String ] := Failure[ "NotebookToolError", <|
    "MessageTemplate"   -> "`1`",
    "MessageParameters" -> { message },
    "String"            -> message
|> ];

toolFailure // endDefinition;


internalToolFailure // beginDefinition;

internalToolFailure[ name_String, value_ ] := (
    acpLog[ "NotebookToolFailed", <| "Tool" -> name, "Value" -> value |> ];
    toolFailure[ "The " <> name <> " tool failed because of an internal error in Chatbook." ]
);

internalToolFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolError*)

(* Ends the tool with an error text for the agent; template slots `1`, `2`, ... are filled with the arguments *)
toolError // beginDefinition;
toolError[ message_String ] := Throw[ message, $toolErrorTag ];
toolError[ template_String, args__ ] := toolError @ TemplateApply[ StringTemplate @ template, { args } ];
toolError // endDefinition;


(* An argument of the agent in an error message: quoted, and shortened if it is long *)
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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toJSON*)
toJSON // beginDefinition;

toJSON[ expr_ ] := With[ { json = Developer`WriteRawJSONString[ expr, "Compact" -> True ] },
    If[ StringQ @ json, json, throwInternalFailure @ toJSON @ expr ]
];

toJSON // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Arguments*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stringArgument*)

(* A required string argument, trimmed *)
stringArgument // beginDefinition;

stringArgument[ s_String, name_String ] := With[ { trimmed = StringTrim @ s },
    If[ trimmed === "", missingArgument @ name, trimmed ]
];

stringArgument[ _, name_String ] := missingArgument @ name;

stringArgument // endDefinition;


missingArgument // beginDefinition;
missingArgument[ name_String ] := toolError[ "The parameter `1` is missing or empty.", name ];
missingArgument // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*textArgument*)

(* A required string argument as it is (cell content: white space matters; may be empty) *)
textArgument // beginDefinition;
textArgument[ s_String, _String ] := s;
textArgument[ _, name_String ] := missingArgument @ name;
textArgument // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*countArgument*)

(* A positive whole number, or the default if it is not given *)
countArgument // beginDefinition;

countArgument[ Missing[ ___ ] | Null | "", _String, default_Integer ] := default;
countArgument[ n_Integer? Positive, _String, _ ] := n;
countArgument[ x_Real /; x >= 1 && x == Round @ x, _String, _ ] := Round @ x;

countArgument[ s_String /; StringMatchQ[ StringTrim @ s, DigitCharacter.. ], name_String, default_Integer ] :=
    countArgument[ FromDigits @ StringTrim @ s, name, default ];

countArgument[ other_, name_String, _ ] :=
    toolError[ "The parameter `1` must be a positive whole number, not `2`.", name, quoted @ other ];

countArgument // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*booleanArgument*)
booleanArgument // beginDefinition;

booleanArgument[ Missing[ ___ ] | Null | "", _String, default_ ] := default;
booleanArgument[ b: True | False, _String, _ ] := b;

booleanArgument[ s_String, name_String, _ ] := Replace[
    ToLowerCase @ StringTrim @ s,
    { "true" -> True, "false" -> False, _ :> toolError[ "The parameter `1` must be true or false, not `2`.", name, quoted @ s ] }
];

booleanArgument[ other_, name_String, _ ] :=
    toolError[ "The parameter `1` must be true or false, not `2`.", name, quoted @ other ];

booleanArgument // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*positionArgument*)
positionArgument // beginDefinition;

positionArgument[ Missing[ ___ ] | Null ] := "After";

positionArgument[ s_String ] := Replace[
    ToLowerCase @ StringTrim @ s,
    {
        "after" | "" -> "After",
        "before"     -> "Before",
        _            :> toolError[ "The parameter position must be \"after\" or \"before\", not `1`.", quoted @ s ]
    }
];

positionArgument[ other_ ] := positionArgument @ ToString @ other;

positionArgument // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*listArgument*)

(* The items of a list argument (cell ids, styles): separated by commas, semicolons (and for cell ids white space);
   brackets and quotes (e.g. a JSON array given as a string) are ignored *)
listArgument // beginDefinition;

listArgument[ s_String, separators_ ] := DeleteDuplicates @ Select[
    StringTrim @ StringSplit[ s, (separators | "[" | "]" | "\"" | "'" | "`").. ],
    # =!= "" &
];

listArgument[ list: { ___String }, separators_ ] := DeleteDuplicates @ Flatten[ listArgument[ #, separators ] & /@ list ];
listArgument[ _, _ ] := { };

listArgument // endDefinition;


(* The cell ids of an argument; None if it is not given *)
cellIDsArgument // beginDefinition;
cellIDsArgument[ Missing[ ___ ] | Null, _String ] := None;

(* "c10 - c20" is one range, "c10-c20" *)
cellIDsArgument[ spec: _String | { ___String }, name_String ] := Replace[
    listArgument[
        StringReplace[ spec, RegularExpression[ "(\\d)\\s*[-\\x{2013}]\\s*(?=#?[cC]?\\d)" ] -> "$1-" ],
        WhitespaceCharacter | "," | ";"
    ],
    { } :> missingArgument @ name
];

cellIDsArgument[ _, name_String ] :=
    toolError[ "The parameter `1` must be a string of cell ids separated by commas, e.g. \"c3, c4\".", name ];
cellIDsArgument // endDefinition;


(* The cell styles of SearchNotebook's styles; None if it is not given *)
stylesArgument // beginDefinition;
stylesArgument[ Missing[ ___ ] | Null | "" ] := None;
stylesArgument[ spec_ ] := Replace[ listArgument[ spec, "," | ";" ], { } -> None ];
stylesArgument // endDefinition;


(* A cell style (a set cell's style, a new cell's style), or Automatic if it is not given *)
styleArgument // beginDefinition;
styleArgument[ Missing[ ___ ] | Null, _String ] := Automatic;
styleArgument[ s_String, _String ] := If[ StringTrim @ s === "", Automatic, StringTrim @ s ];
styleArgument[ other_, name_String ] := toolError[ "The parameter `1` must be a style name, not `2`.", name, quoted @ other ];
styleArgument // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*editsArgument*)

(* EditInCell's edits as { { old, new, count }, ... }: every edit needs oldText (not empty) and newText; count is 1 if it
   is not given. Neither may hold a marker line, and newText nothing that runs code. *)
editsArgument // beginDefinition;

editsArgument[ edits: { __Association } ] := MapIndexed[ editArgument[ #1, First @ #2 ] &, edits ];
editsArgument[ { } | Missing[ ___ ] | Null ] := missingArgument[ "edits" ];

editsArgument[ _ ] :=
    toolError[ "The parameter edits must be a list of edits {oldText, newText, count}, e.g. [{\"oldText\": \"a\", \"newText\": \"b\"}]." ];

editsArgument // endDefinition;


editArgument // beginDefinition;

editArgument[ edit_Association, i_Integer ] := Module[ { old, new, count },
    old   = Lookup[ edit, "oldText", Missing[ "NoInput" ] ];
    new   = Lookup[ edit, "newText", Missing[ "NoInput" ] ];
    count = Lookup[ edit, "count", Missing[ "NoInput" ] ];
    If[ ! StringQ @ old, toolError[ "Edit `1` has no oldText.", i ] ];
    If[ old === "",
        toolError[ "\
Edit `1` has an empty oldText. To insert text, put the text next to the insertion point in oldText and that text with \
the addition in newText.", i ]
    ];
    If[ ! StringQ @ new, toolError[ "Edit `1` has no newText (use \"\" to delete oldText).", i ] ];
    count = Replace[ count, {
        Missing[ ___ ] | Null -> 1,
        n_Integer? Positive   :> n,
        other_                :> toolError[ "The count of edit `1` must be a positive whole number, not `2`.", i, quoted @ other ]
    } ];
    If[ markerQ @ old || markerQ @ new,
        toolError[ "Edit `1` includes a marker line (* ::Style:: #id *): an edit works on the content of one cell.", i ]
    ];
    requireInertText[ new, "The newText of edit " <> ToString @ i ];
    { old, new, count }
];

editArgument // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*newCellsArgument*)

(* InsertCells' new cells as { { style, text }, ... } *)
newCellsArgument // beginDefinition;

newCellsArgument[ cells: { __Association } ] := MapIndexed[ newCellArgument[ #1, First @ #2 ] &, cells ];
newCellsArgument[ { } | Missing[ ___ ] | Null ] := missingArgument[ "newCells" ];

newCellsArgument[ _ ] :=
    toolError[ "The parameter newCells must be a list of cells {style, text}, e.g. [{\"style\": \"Input\", \"text\": \"x = 1\"}]." ];

newCellsArgument // endDefinition;


newCellArgument // beginDefinition;

newCellArgument[ cell_Association, i_Integer ] := Module[ { style, text },
    style = Lookup[ cell, "style", Missing[ "NoInput" ] ];
    text  = Lookup[ cell, "text", Missing[ "NoInput" ] ];
    If[ ! StringQ @ style || StringTrim @ style === "", toolError[ "New cell `1` has no style.", i ] ];
    If[ ! StringQ @ text, toolError[ "New cell `1` has no text.", i ] ];
    requireCellText[ text, "The text of new cell " <> ToString @ i ];
    { StringTrim @ style, text }
];

newCellArgument // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*setCellsArgument*)

(* SetCells' cells as "Set" operations of the edit packet: { { "Set", cell, style, text }, ... } *)
setCellsArgument // beginDefinition;

setCellsArgument[ handle_String, cells: { __Association } ] := MapIndexed[ setCellArgument[ handle, #1, First @ #2 ] &, cells ];
setCellsArgument[ _String, { } | Missing[ ___ ] | Null ] := missingArgument[ "cells" ];

setCellsArgument[ _String, _ ] :=
    toolError[ "The parameter cells must be a list of cells {cell, text, style}, e.g. [{\"cell\": \"c3\", \"text\": \"(*New words*)\"}]." ];

setCellsArgument // endDefinition;


setCellArgument // beginDefinition;

setCellArgument[ handle_String, item_Association, i_Integer ] := Module[ { cell, text },
    cell = cellArgument[ handle, Lookup[ item, "cell", Missing[ "NoInput" ] ] ];
    text = Lookup[ item, "text", Missing[ "NoInput" ] ];
    If[ ! StringQ @ text, toolError[ "Item `1` of cells has no text.", i ] ];
    requireCellText[ text, "The text of item " <> ToString @ i ];
    { "Set", cell, styleArgument[ Lookup[ item, "style", Missing[ "NoInput" ] ], "style" ], text }
];

setCellArgument // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*requireCellText*)

(* The content of one cell from the agent: no marker line, nothing that runs code *)
requireCellText // beginDefinition;

requireCellText[ text_String, what_String ] := (
    If[ markerQ @ text,
        toolError[ "`1` includes a marker line (* ::Style:: #id *): give the content of one cell, without its marker line.", what ]
    ];
    requireInertText[ text, what ]
);

requireCellText // endDefinition;


markerQ // beginDefinition;
markerQ[ text_String ] := StringContainsQ[ text, $$markerLine ];
markerQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*requireInertText*)

(* Agent text never makes the front end run code when it shows the cell (ShowChanges shows it in the user's notebook):
   linear syntax (its characters, their escapes, the escapes \! and \* ) is refused anywhere, and so are dynamic boxes
   and options that hold code inside a box wrapper (strings in it are left out: they are only text). Code that is typed
   in a code cell is not run by showing it, so it is allowed. *)
requireInertText // beginDefinition;

requireInertText[ text_String, what_String ] := Module[ { found },
    found = First[ StringCases[ text, $$linearSyntaxText, 1 ], None ];
    If[ StringQ @ found,
        toolError[
            "`1` has linear syntax (`2`), which would run code when it is shown; the notebook tools never write it.",
            what,
            (* a linear syntax character is named by its escape, not repeated *)
            quoted @ StringReplace[
                found,
                c: RegularExpression[ "[\\x{f7c0}-\\x{f7cd}]" ] :> "\\:" <> IntegerString[ First @ ToCharacterCode @ c, 16, 4 ]
            ]
        ]
    ];
    found = First[
        (* an inline formula's wrapper, \:2e22$boxes\:2e23, holds its boxes after the $ *)
        Flatten @ StringCases[
            withoutStrings @ StringReplace[ #, StartOfString ~~ "\:2e22$" -> "\:2e22" ] & /@ StringCases[ text, $$wrapper ],
            $$codeInWrapper,
            1
        ],
        None
    ];
    If[ StringQ @ found,
        toolError[
            "`1` has content that would run code when it is shown (`2`), which the notebook tools never write.",
            what,
            StringTrim @ StringDelete[ found, "[" | "->" | ":>" | "\\[Rule]" | "\\[RuleDelayed]" ]
        ]
    ]
];

requireInertText // endDefinition;


withoutStrings // beginDefinition;
withoutStrings[ text_String ] := StringReplace[ text, RegularExpression[ "\"(?:[^\"\\\\]|\\\\.)*\"" ] -> "\"\"" ];
withoutStrings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Front End*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookFrontEnd*)

(* Every front end operation of the tools (tests replace this function with a made-up front end):
     notebookFrontEnd[ "Snapshot", source ]                      the hidden snapshot's NotebookObject, or $Failed;
                                                                 source: a NotebookObject, a file or None
     notebookFrontEnd[ "CellText", nb, cells, preview, elide ]   { <| "Cell", "Style", "Text", "GroupDepth", "Open" |>,
                                                                 ... } or $Failed; cells: All or { CellObject, ... },
                                                                 preview: n or All, elide: True or False
     notebookFrontEnd[ "Edit", nb, ops ]                         <| "Changed", "Inserted", "Deleted" |> or a Failure
     notebookFrontEnd[ "FileName", nb ]                          the snapshot's file, or $Failed
     notebookFrontEnd[ "Save", nb ]                              Null, or $Failed
     notebookFrontEnd[ "Close", nb ]                             closes the snapshot; the front end deletes its file
     notebookFrontEnd[ "ShowDiff", source, snapshot ]            CellDiff's ShowNotebookDiff[ source, snapshot ]
   The packets are the front end's (FrontEnd docs/NotebookMCP/Plan.md, "FE packets"). *)
notebookFrontEnd // beginDefinition;

notebookFrontEnd[ op_String, args___ ] := (
    requireFrontEnd[ ];
    frontEndOperation[ op, args ]
);

notebookFrontEnd // endDefinition;


frontEndOperation // beginDefinition;

frontEndOperation[ "Snapshot", source_ ] :=
    Quiet @ MathLink`CallFrontEnd @ FrontEnd`NotebookSnapshot @ source;

frontEndOperation[ "CellText", nb_NotebookObject, cells_, preview_, elide_ ] :=
    Quiet @ MathLink`CallFrontEnd @ FrontEnd`NotebookCellText[ nb, cells, "Preview" -> preview, "Elide" -> elide ];

frontEndOperation[ "Edit", nb_NotebookObject, ops_List ] :=
    Quiet @ MathLink`CallFrontEnd @ FrontEnd`NotebookCellTextEdit[ nb, ops ];

frontEndOperation[ "FileName", nb_NotebookObject ] := Quiet @ NotebookFileName @ nb;
frontEndOperation[ "Save", nb_NotebookObject ] := Quiet @ NotebookSave @ nb;
frontEndOperation[ "Close", nb_NotebookObject ] := Quiet @ NotebookClose @ nb;
frontEndOperation[ "ShowDiff", source_, snapshot_NotebookObject ] := showNotebookDiff[ source, snapshot ];

frontEndOperation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*showNotebookDiff*)

(* CellDiff's ShowNotebookDiff[ source, snapshot ]: loaded from its file every time, since it is a development file whose
   definitions are pure (its Get also loads CellDiffControlStyles.wl from the same directory); its contexts are kept off
   $ContextPath *)
showNotebookDiff // beginDefinition;

showNotebookDiff[ source_, snapshot_NotebookObject ] := Module[ { diffFile, result },
    diffFile = notebookDiffFile[ ];
    If[ ! FileExistsQ @ diffFile,
        toolError[ "ShowChanges is not available: the notebook comparison `1` was not found.", diffFile ]
    ];
    Quiet @ Block[ { $ContextPath = $ContextPath }, Get @ diffFile ];
    If[ Names @ $notebookDiffFunction === { },
        toolError[ "ShowChanges is not available: `1` does not define ShowNotebookDiff.", diffFile ]
    ];
    result = Symbol[ $notebookDiffFunction ][ source, snapshot ];
    If[ MatchQ[ result, _Symbol[ ___ ] ] && SymbolName @ Head @ result === "ShowNotebookDiff",
        toolError[ "ShowChanges is not available: `1` does not define ShowNotebookDiff.", diffFile ]
    ];
    result
];

showNotebookDiff // endDefinition;


notebookDiffFile // beginDefinition;

notebookDiffFile[ ] := With[ { file = Environment[ "CELLDIFF_NOTEBOOKDIFF_FILE" ] },
    If[ StringQ @ file && StringTrim @ file =!= "", file, $defaultNotebookDiffFile ]
];

notebookDiffFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Identifiers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*objectKeys*)

(* The key of each notebook: its UUID, in lower case. Objects that share a UUID (a copy of a notebook file that is open
   twice) get their instance UUID too, so that the keys are unique. *)
objectKeys // beginDefinition;

objectKeys[ objects_List ] := Module[ { uuids, shared },
    uuids  = objectUUID /@ objects;
    shared = Select[ Counts @ uuids, GreaterThan[ 1 ] ];
    MapThread[
        If[ KeyExistsQ[ shared, #2 ], #2 <> "." <> objectInstance @ #1, #2 ] &,
        { objects, uuids }
    ]
];

objectKeys // endDefinition;


objectUUID // beginDefinition;
objectUUID[ (NotebookObject|CellObject)[ uuid_String, ___ ] ] := ToLowerCase @ uuid;
objectUUID[ object_ ] := IntegerString[ Hash @ object, 16 ];
objectUUID // endDefinition;


objectInstance // beginDefinition;
objectInstance[ (NotebookObject|CellObject)[ _String, instance_String, ___ ] ] := ToLowerCase @ instance;
objectInstance[ object_ ] := IntegerString[ Hash @ object, 16 ];
objectInstance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*uniqueIDs*)

(* The id of each key: its shortest start of at least $idLength characters that no other key starts with (the whole key
   if there is none, which only happens for equal keys) *)
uniqueIDs // beginDefinition;

uniqueIDs[ keys: { ___String } ] := Module[ { ids, pending, length, counts, done },
    ids     = keys;
    pending = Range @ Length @ keys;
    length  = $idLength;
    While[ pending =!= { },
        counts = Counts @ StringTake[ keys, UpTo @ length ];
        done = Select[
            pending,
            StringLength @ keys[[ # ]] <= length || counts @ StringTake[ keys[[ # ]], length ] === 1 &
        ];
        ids[[ done ]] = StringTake[ keys[[ done ]], UpTo @ length ];
        pending = Complement[ pending, done ];
        length++
    ];
    ids
];

uniqueIDs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*idMatches*)

(* The entries (notebooks, each with a "Key") that an id of the agent stands for: the one whose key it is, else those
   whose keys start with it (if it has at least $minPrefixLength characters) *)
idMatches // beginDefinition;

idMatches[ entries_List, id_String ] := Module[ { exact },
    exact = Select[ entries, #[ "Key" ] === id & ];
    Which[
        exact =!= { }                       , exact,
        StringLength @ id >= $minPrefixLength, Select[ entries, StringStartsQ[ #[ "Key" ], id ] & ],
        True                                , { }
    ]
];

idMatches // endDefinition;


(* An id as the agent may give it: without white space and quotes around it, in lower case (UUIDs are) *)
cleanID // beginDefinition;
cleanID[ s_String ] := ToLowerCase @ StringTrim[ s, (WhitespaceCharacter | "\"" | "'" | "`").. ];
cleanID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebooks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*listedNotebooks*)

(* The notebooks that the tools can reach, front to back (the first one is the notebook the user is working in), each
   as <| "NotebookObject", "Key", "ID", "Title", "File", "Modified" |> ("Title" and "File" are None if not known) *)
listedNotebooks // beginDefinition;
listedNotebooks[ ] := If[ $FrontEnd === Null, { }, listedNotebooks0[ ] ];
listedNotebooks // endDefinition;


listedNotebooks0 // beginDefinition;

listedNotebooks0[ ] := Enclose[
    Module[ { messages, info, deployed, keys },
        messages = MessagesNotebook[ ];
        info = Select[
            ConfirmMatch[ SourceNotebookObjectInformation[ ], { ___Association }, "Information" ],
            listedNotebookQ[ #, messages ] &
        ];
        deployed = If[ info === { }, { }, AbsoluteCurrentValue[ Lookup[ info, "NotebookObject" ], Deployed ] ];
        ConfirmAssert[ ListQ @ deployed && Length @ deployed === Length @ info, "Deployed" ];
        info = Pick[ info, TrueQ /@ deployed, False ];
        keys = objectKeys @ Lookup[ info, "NotebookObject", { } ];
        MapThread[ notebookEntry, { info, keys, uniqueIDs @ keys } ]
    ],
    throwInternalFailure
];

listedNotebooks0 // endDefinition;


(* The notebooks that the user can attach to a prompt (Attachments.wl's attach menu): the ones the tools can reach, front
   to back, as listedNotebooks gives them. Makes front end calls; { } without a front end. *)
acpAttachableNotebooks // beginDefinition;
acpAttachableNotebooks[ ] := listedNotebooks[ ];
acpAttachableNotebooks // endDefinition;


(* Whether a notebook of SourceNotebookObjectInformation[ ] can be listed (deployed ones are left out separately) *)
listedNotebookQ // beginDefinition;

listedNotebookQ[ info_Association, messages_ ] := And[
    TrueQ @ info[ "Included" ],
    info[ "DocumentType" ] =!= "Help",
    info[ "NotebookObject" ] =!= messages
];

listedNotebookQ // endDefinition;


notebookEntry // beginDefinition;

notebookEntry[ info_Association, key_String, id_String ] := <|
    "NotebookObject" -> info[ "NotebookObject" ],
    "Key"            -> key,
    "ID"             -> id,
    "Title"          -> Replace[ Lookup[ info, "WindowTitle", None ], Except[ _String ] -> None ],
    "File"           -> Replace[ Lookup[ info, "FileName", None ], Except[ _String ] -> None ],
    "Modified"       -> TrueQ @ Lookup[ info, "ModifiedInMemory", False ]
|>;

notebookEntry // endDefinition;


(* A notebook's title for messages *)
notebookLabel // beginDefinition;
notebookLabel[ entry_Association ] :=
    entry[ "ID" ] <> " (" <> quoted @ inlineText @ Replace[ entry[ "Title" ], None -> "Untitled" ] <> ")";
notebookLabel // endDefinition;


(* A title or file name in a result or an error: on one line *)
inlineText // beginDefinition;
inlineText[ text_String ] := StringReplace[ text, ("\r\n"|"\n"|"\r") -> " " ];
inlineText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveNotebook*)

(* The listed notebook that the agent means: by id (or a start of it), else by exact window title, else by file *)
resolveNotebook // beginDefinition;

resolveNotebook[ entries_List, spec0_ ] := Module[ { spec, matches },
    spec = stringArgument[ spec0, "notebook" ];
    matches = idMatches[ entries, cleanID @ spec ];
    If[ matches === { }, matches = Select[ entries, #[ "Title" ] === spec & ] ];
    If[ matches === { }, matches = Select[ entries, sameFileQ[ #[ "File" ], spec ] & ] ];
    Switch[ Length @ matches,
        1, First @ matches,
        0, toolError[
            "No open notebook or .nb file matches `1`. Call ListNotebooks for the notebooks that are open.",
            quoted @ spec
        ],
        _, toolError[
            "`1` matches more than one notebook: `2`. Use the notebook's id.",
            quoted @ spec,
            StringRiffle[ notebookLabel /@ matches, ", " ]
        ]
    ]
];

resolveNotebook // endDefinition;


sameFileQ // beginDefinition;
sameFileQ[ file_String, spec_String ] := normalFileName @ file === normalFileName @ spec;
sameFileQ[ _, _ ] := False;
sameFileQ // endDefinition;


normalFileName // beginDefinition;

normalFileName[ file_String ] := Replace[
    Quiet @ ExpandFileName @ file,
    { expanded_String :> StringReplace[ expanded, "\\" -> "/" ], _ -> None }
];

normalFileName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Snapshots*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveSnapshot*)

(* The handle of the open snapshot that the agent's notebook argument names *)
resolveSnapshot // beginDefinition;

resolveSnapshot[ spec0_ ] := Module[ { spec, handle },
    spec   = stringArgument[ spec0, "notebook" ];
    handle = cleanID @ spec;
    If[ KeyExistsQ[ $snapshots, handle ],
        handle,
        toolError[
            "`1` is not an open snapshot. `2`",
            quoted @ spec,
            If[ $snapshots === <| |>,
                "Open the notebook with OpenNotebook first; the other tools take the handle it gives.",
                "The open snapshots are " <> StringRiffle[ snapshotLabel /@ Keys @ $snapshots, ", " ] <>
                    "; OpenNotebook opens another one."
            ]
        ]
    ]
];

resolveSnapshot // endDefinition;


snapshotLabel // beginDefinition;
snapshotLabel[ handle_String ] := handle <> " (" <> quoted @ inlineText @ $snapshots[ handle, "Title" ] <> ")";
snapshotLabel // endDefinition;


(* Whether the agent's notebook argument names an open snapshot (for the permission panel); never throws *)
snapshotHandle // beginDefinition;
snapshotHandle[ spec_String ] := With[ { handle = cleanID @ spec }, If[ KeyExistsQ[ $snapshots, handle ], handle, None ] ];
snapshotHandle[ _ ] := None;
snapshotHandle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cell ids*)

(* The ids of a snapshot's cells: cells that have none yet get the next numbers, in the given order *)
numberCells // beginDefinition;

numberCells[ handle_String, cells: { ___CellObject } ] := Module[ { ids, next },
    ids  = $snapshots[ handle, "IDs" ];
    next = $snapshots[ handle, "NextID" ];
    Scan[ If[ ! KeyExistsQ[ ids, # ], ids[ # ] = "c" <> ToString[ next++ ] ] &, cells ];
    $snapshots[ handle ] = <| $snapshots[ handle ], "IDs" -> ids, "NextID" -> next |>;
    Lookup[ ids, cells ]
];

numberCells // endDefinition;


(* The cells that the agent's ids name, in the given order *)
resolveCells // beginDefinition;
resolveCells[ handle_String, ids: { __String } ] := DeleteDuplicates @ Flatten[ resolveCellOrRange[ handle, # ] & /@ ids ];
resolveCells // endDefinition;


(* An id, or a range of ids such as "c10-c20": the snapshot's cells numbered 10 to 20, in the order of their numbers *)
resolveCellOrRange // beginDefinition;

resolveCellOrRange[ handle_String, spec_String ] := Replace[
    StringCases[ spec, RegularExpression[ "^#?[cC]?(\\d+)-#?[cC]?(\\d+)$" ] :> FromDigits /@ { "$1", "$2" } ],
    {
        { { from_, to_ } } :> Replace[
            SortBy[
                Select[ Normal @ $snapshots[ handle, "IDs" ], Between[ cellNumber @ Last[ # ], { from, to } ] & ],
                cellNumber @* Last
            ][[ All, 1 ]],
            { } :> toolError[ "`1` has no cells numbered `2` to `3`.", handle, from, to ]
        ],
        _ :> resolveCell[ handle, spec ]
    }
];

resolveCellOrRange // endDefinition;


cellNumber // beginDefinition;
cellNumber[ id_String ] := Replace[ StringDrop[ id, 1 ], { n_ /; StringMatchQ[ n, DigitCharacter.. ] :> FromDigits @ n, _ -> 0 } ];
cellNumber // endDefinition;


resolveCell // beginDefinition;

resolveCell[ handle_String, spec_String ] := Module[ { id, cell },
    id   = cellID @ spec;
    cell = First[ Keys @ Select[ $snapshots[ handle, "IDs" ], # === id & ], None ];
    If[ MatchQ[ cell, _CellObject ],
        cell,
        toolError[
            "`1` has no cell `2`. Cell ids come from OpenNotebook, GetOutline, ReadCells and SearchNotebook.",
            handle,
            quoted @ spec
        ]
    ]
];

resolveCell[ _String, other_ ] := toolError[ "`1` is not a cell id.", quoted @ other ];

resolveCell // endDefinition;


(* A cell id as the agent may give it: "c3", "#c3", "C3" or "3" *)
cellID // beginDefinition;

cellID[ spec_String ] := With[ { id = ToLowerCase @ StringTrim[ spec, (WhitespaceCharacter | "\"" | "'" | "`" | "#").. ] },
    If[ StringMatchQ[ id, DigitCharacter.. ], "c" <> id, id ]
];

cellID // endDefinition;


(* The cell argument of EditInCell and SetCells, InsertCells' anchor *)
cellArgument // beginDefinition;
cellArgument[ handle_String, spec_ ] := resolveCell[ handle, stringArgument[ spec, "cell" ] ];
cellArgument // endDefinition;


(* InsertCells' anchor: a cell, or None if the parameter is not given *)
anchorArgument // beginDefinition;
anchorArgument[ _String, Missing[ ___ ] | Null ] := None;
anchorArgument[ _String, s_String ] /; StringTrim @ s === "" := None;
anchorArgument[ handle_String, spec_ ] := cellArgument[ handle, spec ];
anchorArgument // endDefinition;


forgetCells // beginDefinition;
forgetCells[ handle_String, cells_List ] := ($snapshots[[ handle, "IDs" ]] = KeyDrop[ $snapshots[[ handle, "IDs" ]], cells ]);
forgetCells // endDefinition;


(* The cells that "Edit" or "Set" operations changed: the front end replaces each such cell by a new one, which keeps
   the cell's ExpressionUUID (CellObject[uuid, instance]) but not its CellObject, so the new CellObject takes over the
   id. The packet gives the changed cells in document order: a replacement is matched to its cell by the uuid, or, if
   CellObjects have no uuid (the legacy object format), when there is only one. *)
changedCells // beginDefinition;

changedCells[ handle_String, cells: { __CellObject }, result_Association ] := Module[ { changed, new, lost, pairs },
    changed = Cases[ Lookup[ result, "Changed", { } ], _CellObject ];
    new     = Select[ changed, ! KeyExistsQ[ $snapshots[ handle, "IDs" ], # ] & ];
    lost    = Select[ cells, ! MemberQ[ changed, # ] & ];
    pairs   = DeleteMissing @ AssociationMap[ Function[ old, SelectFirst[ new, sameCellQ[ old, # ] &, Missing[ ] ] ], lost ];
    If[ pairs === <| |> && Length @ new === 1 && Length @ lost === 1, pairs = <| First @ lost -> First @ new |> ];
    $snapshots[[ handle, "IDs" ]] = Join[
        KeyDrop[ $snapshots[ handle, "IDs" ], Keys @ pairs ],
        AssociationThread[ Values @ pairs, Lookup[ $snapshots[ handle, "IDs" ], Keys @ pairs ] ]
    ];
    Replace[ cells, Normal @ pairs, { 1 } ]
];

changedCells // endDefinition;


(* Whether two CellObjects name the same cell: the same uuid, another instance *)
sameCellQ // beginDefinition;
sameCellQ[ CellObject[ uuid_String, ___ ], CellObject[ uuid_String, ___ ] ] := True;
sameCellQ[ _CellObject, _CellObject ] := False;
sameCellQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellTexts*)

(* The text of a snapshot's cells (All, or a list of CellObjects) from the front end, each with its id ("ID"); cells
   without an id get one *)
cellTexts // beginDefinition;

cellTexts[ handle_String, cells_, preview_, elide_ ] := Module[ { result, ids },
    result = notebookFrontEnd[ "CellText", $snapshots[ handle, "Notebook" ], cells, preview, elide ];
    If[ ! MatchQ[ result, { KeyValuePattern[ "Cell" -> _CellObject ]... } ],
        toolError[ "The front end could not read the cells of `1`.", snapshotLabel @ handle ]
    ];
    ids = numberCells[ handle, Lookup[ result, "Cell", { } ] ];
    MapThread[ <| #1, "ID" -> #2 |> &, { result, ids } ]
];

cellTexts // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellBlock*)

(* A cell as its marker line and its content *)
cellBlock // beginDefinition;
cellBlock[ entry_Association ] := cellMarker @ entry <> "\n" <> cellContent @ entry;
cellBlock // endDefinition;


cellMarker // beginDefinition;

cellMarker[ entry_Association ] := StringJoin[
    "(* ::",
    styleName @ Lookup[ entry, "Style", "" ],
    If[ Lookup[ entry, "Open", True ] === False, "::Closed", "" ],
    ":: #",
    entry[ "ID" ],
    " *)"
];

cellMarker // endDefinition;


styleName // beginDefinition;
styleName[ style_String ] := style;
styleName[ other_ ] := ToString[ other, InputForm ];
styleName // endDefinition;


cellContent // beginDefinition;
cellContent[ entry_Association ] := Replace[ Lookup[ entry, "Text", "" ], Except[ _String ] -> "" ];
cellContent // endDefinition;


(* The cells after an edit, as the front end now gives them *)
cellBlocks // beginDefinition;
cellBlocks[ _String, { } ] := "";
cellBlocks[ handle_String, cells: { __CellObject } ] := StringRiffle[ cellBlock /@ cellTexts[ handle, cells, All, True ], "\n" ];
cellBlocks // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*applyEdit*)

(* Applies operations of the edit packet to a snapshot and gives the packet's result. A Failure of the packet (the
   batch is atomic: nothing changed) ends the tool with its tag and message, and a hint for the agent. *)
applyEdit // beginDefinition;

applyEdit[ handle_String, ops: { __List } ] := Module[ { result },
    result = notebookFrontEnd[ "Edit", $snapshots[ handle, "Notebook" ], ops ];
    Which[
        FailureQ @ result && result =!= $Failed,
            toolError @ editFailureText[ handle, result ],
        ! AssociationQ @ result,
            toolError[ "The front end could not edit `1`. Nothing was changed.", snapshotLabel @ handle ]
    ];
    $snapshots[ handle ] = <| $snapshots[ handle ], "Edited" -> True, "Unsaved" -> True |>;
    result
];

applyEdit // endDefinition;


editFailureText // beginDefinition;

editFailureText[ _String, failure: Failure[ tag_, _Association ] ] := StringJoin[
    ToString @ tag, ": ",
    failureMessage @ failure,
    " Nothing was changed.",
    Replace[ Lookup[ $editFailureHints, tag, None ], { hint_String :> " " <> hint, _ -> "" } ]
];

editFailureText[ handle_String, _ ] := "The front end could not edit " <> snapshotLabel @ handle <> ". Nothing was changed.";

editFailureText // endDefinition;


failureMessage // beginDefinition;

(* The message of a Failure as plain text: its template with its parameters (Failure's own "Message" formats them as
   boxes) *)
failureMessage[ Failure[ _, data_Association ] ] := With[
    { template = Lookup[ data, "MessageTemplate", "" ], parameters = Lookup[ data, "MessageParameters", { } ] },
    Which[
        ! StringQ @ template,
            "",
        MatchQ[ parameters, _List | _Association ] && parameters =!= { },
            Replace[ Quiet @ TemplateApply[ StringTemplate @ template, parameters ], Except[ _String ] -> template ],
        True,
            template
    ]
];

failureMessage // endDefinition;


(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::UnrecognizedLongName:: *)
$editFailureHints = <|
    "CellNotFound"    -> "Call GetOutline for the current cell ids.",
    "NoMatch"         -> "Copy oldText exactly from the cell's current content (ReadCells), with its spaces, \:2e22 \:2e23 wrappers and \\[Name] characters.",
    "AmbiguousMatch"  -> "Make oldText longer, so that it occurs as often as count says, or give count.",
    "ParseError"      -> "The cell's new content must parse: check brackets, quotes and \:2e22 \:2e23 wrappers.",
    "CellNotEditable" -> "This cell can't be changed.",
    "NotASnapshot"    -> "Open the notebook with OpenNotebook and edit its snapshot."
|>;
(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ListNotebooks*)
listNotebooks // beginDefinition;

listNotebooks[ ] := Module[ { entries },
    entries = listedNotebooks[ ];
    toJSON @ <|
        "notebooks" -> MapIndexed[
            <|
                "id"       -> #1[ "ID" ],
                "title"    -> Replace[ #1[ "Title" ], None -> Null ],
                "file"     -> Replace[ #1[ "File" ], None -> Null ],
                "modified" -> #1[ "Modified" ],
                "cells"    -> cellCount @ #1[ "NotebookObject" ],
                "selected" -> #2 === { 1 },
                "snapshot" -> Replace[ sourceSnapshot @ #1[ "NotebookObject" ], None -> Null ]
            |> &,
            entries
        ],
        "snapshots" -> KeyValueMap[
            <|
                "notebook" -> #1,
                "title"    -> #2[ "Title" ],
                "source"   -> sourceReference @ #2,
                "edited"   -> #2[ "Edited" ],
                "unsaved"  -> #2[ "Unsaved" ]
            |> &,
            $snapshots
        ]
    |>
];

listNotebooks // endDefinition;


cellCount // beginDefinition;
cellCount[ nbo_NotebookObject ] := Replace[ Quiet @ Cells @ nbo, { cells_List :> Length @ cells, _ -> 0 } ];
cellCount // endDefinition;


(* The handle of the open snapshot of a source (a NotebookObject or a file), or None *)
sourceSnapshot // beginDefinition;

sourceSnapshot[ source_ ] := First[
    Keys @ Select[ $snapshots, sameSourceQ[ #[ "Source" ], source ] & ],
    None
];

sourceSnapshot // endDefinition;


sameSourceQ // beginDefinition;
sameSourceQ[ a_NotebookObject, b_NotebookObject ] := a === b;
sameSourceQ[ a_String, b_String ] := sameFileQ[ a, b ];
sameSourceQ[ _, _ ] := False;
sameSourceQ // endDefinition;


(* A snapshot's source for the agent: the notebook's id, the file, or null for a new notebook *)
sourceReference // beginDefinition;
sourceReference[ KeyValuePattern[ "SourceID" -> id_String ] ] := id;
sourceReference[ KeyValuePattern[ "Source" -> file_String ] ] := file;
sourceReference[ _ ] := Null;
sourceReference // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*OpenNotebook*)
openNotebook // beginDefinition;

(* The snapshot as JSON, then its cells as ReadCells shows them, so that the agent needs no ReadCells call, or, if
   they do not all fit into $readBudget, an outline of its headings with the range of cells under each, from which the
   agent reads the sections it changes *)
openNotebook[ args_Association ] := Module[ { source, handle, reopened, entries, blocks },
    source   = openSource @ args[ "notebook" ];
    handle   = sourceSnapshot @ source[ "Source" ];
    reopened = StringQ @ handle;
    If[ ! reopened, handle = newSnapshot @ source ];
    entries = cellTexts[ handle, All, All, True ];
    blocks  = cellBlock /@ entries;
    StringJoin[
        toJSON @ <|
            "notebook" -> handle,
            "title"    -> $snapshots[ handle, "Title" ],
            "source"   -> sourceReference @ $snapshots @ handle,
            "cells"    -> Length @ entries,
            If[ reopened, "note" -> "This notebook already had an open snapshot; its edits so far are kept.", Nothing ]
        |>,
        Which[
            blocks === { }, "",
            budgetCount[ StringLength /@ blocks, $readBudget ] === Length @ blocks,
                "\n\nIts cells, as ReadCells shows them:\n" <> StringRiffle[ blocks, "\n" ],
            True,
                "\n\n" <> notebookOutline @ entries
        ]
    ]
];

openNotebook // endDefinition;


(* The headings of a notebook too long to show whole, each with the range of cells up to the next heading *)
notebookOutline // beginDefinition;

notebookOutline[ entries_List ] := Module[ { positions, ends },
    positions = Flatten @ Position[ Lookup[ entries, "Style", "" ], $outlineHeadings, { 1 } ];
    ends      = Append[ Rest @ positions - 1, Length @ entries ];
    StringJoin[
        "It is too long to show whole (", ToString @ Length @ entries, " cells). Its headings, each with the range of ",
        "cells under it:\n",
        StringRiffle[ MapThread[ outlineHeading, { entries[[ positions ]], entries[[ ends, "ID" ]] } ], "\n" ],
        "\nRead the sections you change with ReadCells, giving their ranges (e.g. cells \"c12-c40, c90-c120\"), or find ",
        "cells with SearchNotebook."
    ]
];

notebookOutline // endDefinition;


outlineHeading // beginDefinition;

outlineHeading[ entry_Association, last_String ] := StringJoin[
    StringRepeat[ "  ", Max[ 0, Replace[ Lookup[ entry, "GroupDepth", 0 ], Except[ _Integer ] -> 0 ] - 1 ] ],
    "#", entry[ "ID" ], If[ last =!= entry[ "ID" ], "-#" <> last, "" ], " (", styleName @ entry[ "Style" ], ") ",
    StringTrim @ StringReplace[ cellContent @ entry, { "(*" -> "", "*)" -> "", ("\r\n" | "\n" | "\r") -> " " } ]
];

outlineHeading // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*openSource*)

(* What OpenNotebook snapshots: <| "Source" -> a listed NotebookObject, a .nb file or None, "SourceID", "Title" |> *)
openSource // beginDefinition;

openSource[ Missing[ ___ ] | Null | None ] := <| "Source" -> None, "SourceID" -> None, "Title" -> "Untitled" |>;
openSource[ s_String ] /; StringTrim @ s === "" := openSource @ None;

openSource[ spec_ ] := Module[ { found, file },
    found = Catch[ resolveNotebook[ listedNotebooks[ ], spec ], $toolErrorTag ];
    If[ AssociationQ @ found,
        Return[
            <|
                "Source"   -> found[ "NotebookObject" ],
                "SourceID" -> found[ "ID" ],
                "Title"    -> Replace[ found[ "Title" ], None :> Replace[ found[ "File" ], { f_String :> FileNameTake @ f, _ -> "Untitled" } ] ]
            |>,
            Module
        ]
    ];
    file = notebookFile @ spec;
    If[ StringQ @ file,
        <| "Source" -> file, "SourceID" -> None, "Title" -> FileNameTake @ file |>,
        toolError @ found
    ]
];

openSource // endDefinition;


(* A .nb file that exists, as its full path, or None *)
notebookFile // beginDefinition;

notebookFile[ spec_String ] := With[
    { file = normalFileName @ StringTrim[ spec, (WhitespaceCharacter | "\"" | "'" | "`").. ] },
    If[ StringQ @ file && ToLowerCase @ FileExtension @ file === "nb" && FileExistsQ @ file && ! DirectoryQ @ file,
        file,
        None
    ]
];

notebookFile[ _ ] := None;

notebookFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*newSnapshot*)

(* Has the front end make the snapshot and records it under a new handle *)
newSnapshot // beginDefinition;

newSnapshot[ source_Association ] := Module[ { nbo, file, handle },
    nbo = notebookFrontEnd[ "Snapshot", source[ "Source" ] ];
    If[ ! MatchQ[ nbo, _NotebookObject ],
        toolError[ "The front end could not make a snapshot of `1`.", quoted @ source[ "Title" ] ]
    ];
    file   = Replace[ notebookFrontEnd[ "FileName", nbo ], Except[ _String ] -> None ];
    handle = "s" <> ToString[ ++$snapshotCount ];
    $snapshots[ handle ] = <|
        "Handle"   -> handle,
        "Notebook" -> nbo,
        "File"     -> file,
        source,
        "IDs"      -> <| |>,
        "NextID"   -> 1,
        "Edited"   -> False,
        "Unsaved"  -> False
    |>;
    handle
];

newSnapshot // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GetOutline*)
getOutline // beginDefinition;

getOutline[ args_Association ] := Module[ { handle, preview, offset, limit, entries, n, last, shown, depth },
    handle  = resolveSnapshot @ args[ "notebook" ];
    preview = Min[ countArgument[ args[ "preview" ], "preview", $previewLength ], $maxPreviewLength ];
    offset  = countArgument[ args[ "offset" ], "offset", 1 ];
    limit   = Min[ countArgument[ args[ "limit" ], "limit", $outlineLimit ], $maxOutlineLimit ];
    entries = cellTexts[ handle, All, preview, True ];
    n       = Length @ entries;
    If[ n === 0, Return[ snapshotLabel @ handle <> " has no cells.", Module ] ];
    If[ offset > n, toolError[ "The offset `1` is past the last cell: `2` has `3` cells.", offset, handle, n ] ];
    last  = Min[ n, offset + limit - 1 ];
    shown = entries[[ offset ;; last ]];
    depth = Min @ Replace[ Lookup[ entries, "GroupDepth", 0 ], Except[ _Integer ] -> 0, { 1 } ];
    StringJoin[
        "Outline of ", snapshotLabel @ handle, ": ", ToString @ n, " cells, each as its marker line and the start of its \
content, indented by cell group depth.\n",
        StringRiffle[ outlineBlock[ #, preview, depth ] & /@ shown, "\n" ],
        If[ last < n,
            StringTemplate[ "\n[Cells `1`-`2` of `3`; call again with offset `4` for more.]" ][ offset, last, n, last + 1 ],
            ""
        ]
    ]
];

getOutline // endDefinition;


outlineBlock // beginDefinition;

outlineBlock[ entry_Association, preview_Integer, depth0_Integer ] := Module[ { indent, text },
    indent = StringRepeat[ "  ", Max[ 0, Replace[ Lookup[ entry, "GroupDepth", 0 ], Except[ _Integer ] -> 0 ] - depth0 ] ];
    text   = cellContent @ entry;
    StringJoin[
        indent, cellMarker @ entry, "\n",
        indent, StringReplace[ text, ("\r\n" | "\n" | "\r") -> " " ], If[ StringLength @ text >= preview, "\[Ellipsis]", "" ]
    ]
];

outlineBlock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ReadCells*)
readCells // beginDefinition;

readCells[ args_Association ] := Module[ { handle, ids, full, entries },
    handle  = resolveSnapshot @ args[ "notebook" ];
    ids     = cellIDsArgument[ args[ "cells" ], "cells" ];
    full    = booleanArgument[ args[ "full" ], "full", False ];
    entries = cellTexts[ handle, If[ ids === None, All, resolveCells[ handle, ids ] ], All, ! full ];
    If[ entries === { }, snapshotLabel @ handle <> " has no cells.", budgetedBlocks @ entries ]
];

readCells // endDefinition;


(* Cells as marker lines and content, as many as fit into $readBudget, with a note on the ones that do not *)
budgetedBlocks // beginDefinition;

budgetedBlocks[ entries: { __Association } ] := Module[ { blocks, shown },
    blocks = cellBlock /@ entries;
    shown  = budgetCount[ StringLength /@ blocks, $readBudget ];
    StringJoin[
        StringRiffle[ Take[ blocks, shown ], "\n" ],
        If[ shown < Length @ blocks,
            StringJoin[
                "\n[Not shown: #", entries[[ shown + 1, "ID" ]], " and the ", ToString[ Length @ blocks - shown - 1 ],
                " cells after it (a result has at most ", ToString @ $readBudget, " characters). Read them with ReadCells \
and cells.]"
            ],
            ""
        ]
    ]
];

budgetedBlocks // endDefinition;


(* How many of the lengths fit into the budget (at least one) *)
budgetCount // beginDefinition;
budgetCount[ { }, _ ] := 0;
budgetCount[ lengths_List, budget_ ] := Max[ 1, LengthWhile[ Accumulate[ lengths + 1 ], LessEqualThan @ budget ] ];
budgetCount // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SearchNotebook*)
searchNotebook // beginDefinition;

searchNotebook[ args_Association ] := Module[ { handle, query, regex, ids, styles, limit, pattern, entries, matches, total },
    handle = resolveSnapshot @ args[ "notebook" ];
    query  = textArgument[ args[ "query" ], "query" ];
    If[ query === "", missingArgument[ "query" ] ];
    regex   = booleanArgument[ args[ "regex" ], "regex", False ];
    ids     = cellIDsArgument[ args[ "cells" ], "cells" ];
    styles  = stylesArgument @ args[ "styles" ];
    limit   = Min[ countArgument[ args[ "limit" ], "limit", $searchLimit ], $maxSearchLimit ];
    pattern = If[ regex, regexPattern @ query, query ];
    entries = cellTexts[ handle, If[ ids === None, All, resolveCells[ handle, ids ] ], All, True ];
    If[ ListQ @ styles,
        entries = Select[ entries, MemberQ[ ToLowerCase @ styles, ToLowerCase @ styleName @ Lookup[ #, "Style", "" ] ] & ]
    ];
    matches = TimeConstrained[ Catenate[ cellMatches[ #, pattern ] & /@ entries ], $searchTimeLimit, $TimedOut ];
    If[ matches === $TimedOut,
        toolError[ "The search took longer than `1` seconds. Use a simpler regular expression.", $searchTimeLimit ]
    ];
    total = Length @ matches;
    Which[
        total === 0,
            "No matches for " <> quoted @ query <> " in " <> snapshotLabel @ handle <> ".",
        True,
            StringJoin[
                ToString @ total, If[ total === 1, " match", " matches" ], " for ", quoted @ query, " in ",
                snapshotLabel @ handle, " (line:column in the cell's content):\n",
                StringRiffle[ Take[ matches, UpTo @ limit ], "\n" ],
                If[ total > limit,
                    "\n[Showing the first " <> ToString @ limit <> "; narrow the search with cells or styles, or raise limit.]",
                    ""
                ]
            ]
    ]
];

searchNotebook // endDefinition;


regexPattern // beginDefinition;

regexPattern[ query_String ] := With[ { pattern = RegularExpression @ query },
    If[ ListQ @ Quiet @ Check[ StringPosition[ "", pattern ], $Failed ],
        pattern,
        toolError[ "`1` is not a valid regular expression.", quoted @ query ]
    ]
];

regexPattern // endDefinition;


(* The matches of the pattern in a cell's content, each as "#id (Style) line:column: the line of the match" *)
cellMatches // beginDefinition;

cellMatches[ entry_Association, pattern_ ] := Module[ { text, spans, lineStarts },
    text  = cellContent @ entry;
    spans = StringPosition[ text, pattern, Overlaps -> False ];
    If[ spans === { }, Return[ { }, Module ] ];
    lineStarts = Prepend[ StringPosition[ text, "\n" ][[ All, 1 ]] + 1, 1 ];
    matchLine[ entry, text, lineStarts, # ] & /@ spans
];

cellMatches // endDefinition;


matchLine // beginDefinition;

matchLine[ entry_Association, text_String, lineStarts_List, { start_Integer, end_Integer } ] := Module[
    { line, lineStart, lineEnd, column },
    line      = LengthWhile[ lineStarts, LessEqualThan @ start ];
    lineStart = lineStarts[[ line ]];
    lineEnd   = If[ line < Length @ lineStarts, lineStarts[[ line + 1 ]] - 2, StringLength @ text ];
    column    = start - lineStart + 1;
    StringJoin[
        "#", entry[ "ID" ], " (", styleName @ Lookup[ entry, "Style", "" ], ") ",
        ToString @ line, ":", ToString @ column, ": ",
        snippet[ text, lineStart, lineEnd, start, end ]
    ]
];

matchLine // endDefinition;


(* The line of a match, shortened around the match if it is long *)
snippet // beginDefinition;

snippet[ text_String, lineStart_Integer, lineEnd_Integer, start_Integer, end_Integer ] := Module[ { from, to },
    If[ lineEnd - lineStart + 1 <= $snippetLength, Return[ StringTake[ text, { lineStart, lineEnd } ], Module ] ];
    from = Max[ lineStart, start - Quotient[ $snippetLength, 3 ] ];
    to   = Min[ lineEnd, Max[ end, start ] + $snippetLength - (start - from) ];
    StringJoin[
        If[ from > lineStart, "\[Ellipsis]", "" ],
        StringTake[ text, { from, to } ],
        If[ to < lineEnd, "\[Ellipsis]", "" ]
    ]
];

snippet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*EditInCell*)
editInCell // beginDefinition;

editInCell[ args_Association ] := Module[ { handle, cell, edits, result },
    handle = resolveSnapshot @ args[ "notebook" ];
    cell   = cellArgument[ handle, args[ "cell" ] ];
    edits  = editsArgument @ args[ "edits" ];
    result = applyEdit[ handle, { { "Edit", cell, edits } } ];
    cell   = First @ changedCells[ handle, { cell }, result ];
    StringJoin[
        "Edited #", $snapshots[ handle, "IDs", cell ], " of ", handle,
        " (", ToString @ Length @ edits, If[ Length @ edits === 1, " edit", " edits" ], "). It now reads:\n",
        cellBlocks[ handle, { cell } ]
    ]
];

editInCell // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SetCells*)

(* All the cells, and the cells to delete with them, in one edit packet; the result names them only (their content is
   what the agent just wrote) *)
setCells // beginDefinition;

setCells[ args_Association ] := Module[ { handle, ops, deleted, deletedIDs, cells },
    handle     = resolveSnapshot @ args[ "notebook" ];
    ops        = setCellsArgument[ handle, args[ "cells" ] ];
    deleted    = Replace[ cellIDsArgument[ args[ "delete" ], "delete" ], { None -> { }, ids_ :> resolveCells[ handle, ids ] } ];
    deletedIDs = Lookup[ $snapshots[ handle, "IDs" ], deleted ];
    cells      = changedCells[
        handle,
        Select[ DeleteDuplicates @ ops[[ All, 2 ]], ! MemberQ[ deleted, # ] & ],
        applyEdit[ handle, If[ deleted === { }, ops, Append[ ops, { "Delete", deleted } ] ] ]
    ];
    forgetCells[ handle, deleted ];
    StringJoin[
        "Set ", ToString @ Length @ cells, If[ Length @ cells === 1, " cell", " cells" ], " of ", handle, ": ",
        StringRiffle[ "#" <> $snapshots[ handle, "IDs", # ] & /@ cells, ", " ],
        If[ deleted === { }, "", "; deleted " <> StringRiffle[ "#" <> # & /@ deletedIDs, ", " ] ],
        ". ReadCells shows their new content."
    ]
];

setCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*InsertCells*)
insertCells // beginDefinition;

insertCells[ args_Association ] := Module[ { handle, cells, anchor, position, result, inserted, where },
    handle   = resolveSnapshot @ args[ "notebook" ];
    cells    = newCellsArgument @ args[ "newCells" ];
    anchor   = anchorArgument[ handle, args[ "cell" ] ];
    position = positionArgument @ args[ "position" ];
    result   = applyEdit[ handle, { { "Insert", anchor, position, cells } } ];
    inserted = Cases[ Lookup[ result, "Inserted", { } ], _CellObject ];
    numberCells[ handle, inserted ];
    where = Which[
        MatchQ[ anchor, _CellObject ], ToLowerCase @ position <> " #" <> $snapshots[ handle, "IDs", anchor ],
        position === "Before"        , "at the beginning",
        True                         , "at the end"
    ];
    StringJoin[
        "Inserted ", ToString @ Length @ inserted, If[ Length @ inserted === 1, " cell ", " cells " ], where, " of ", handle,
        ":\n",
        cellBlocks[ handle, inserted ]
    ]
];

insertCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DeleteCells*)
deleteCells // beginDefinition;

deleteCells[ args_Association ] := Module[ { handle, cells, ids, result },
    handle = resolveSnapshot @ args[ "notebook" ];
    cells  = resolveCells[ handle, Replace[ cellIDsArgument[ args[ "cells" ], "cells" ], None :> missingArgument[ "cells" ] ] ];
    ids    = Lookup[ $snapshots[ handle, "IDs" ], cells ];
    result = applyEdit[ handle, { { "Delete", cells } } ];
    forgetCells[ handle, cells ];
    StringJoin[
        "Deleted ", ToString @ Replace[ Lookup[ result, "Deleted", Length @ cells ], Except[ _Integer ] -> Length @ cells ],
        If[ Length @ cells === 1, " cell (", " cells (" ], StringRiffle[ "#" <> # & /@ ids, ", " ], ") from ", handle, "."
    ]
];

deleteCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SaveNotebook*)
saveNotebook // beginDefinition;

saveNotebook[ args_Association ] := Module[ { handle },
    handle = resolveSnapshot @ args[ "notebook" ];
    saveSnapshot @ handle;
    "Saved " <> handle <> ". When the work on it is done, call ShowChanges to show the user the changes."
];

saveNotebook // endDefinition;


saveSnapshot // beginDefinition;

saveSnapshot[ handle_String ] := (
    If[ notebookFrontEnd[ "Save", $snapshots[ handle, "Notebook" ] ] === $Failed,
        toolError[ "The front end could not save `1`.", snapshotLabel @ handle ]
    ];
    $snapshots[[ handle, "Unsaved" ]] = False
);

saveSnapshot // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ShowChanges*)

(* Saves the snapshot if it has unsaved edits, has CellDiff show the source as a diff against the snapshot (in the
   source notebook itself; a source file is opened; a new notebook is simply shown), then closes the snapshot (the front
   end deletes its file). CellDiff reads the still open snapshot with NotebookGet rather than its file, which would have
   to be evaluated. If the diff can't be shown, the snapshot stays open. *)
showChanges // beginDefinition;

showChanges[ args_Association ] := Module[ { handle, record, result },
    handle = resolveSnapshot @ args[ "notebook" ];
    record = $snapshots @ handle;
    If[ ! TrueQ @ record[ "Edited" ],
        Return[ "There are no changes to show: " <> handle <> " was not edited. Close it with CloseNotebook.", Module ]
    ];
    If[ TrueQ @ record[ "Unsaved" ], saveSnapshot @ handle ];
    result = notebookFrontEnd[ "ShowDiff", record[ "Source" ], record[ "Notebook" ] ];
    If[ FailureQ @ result,
        toolError[ "The changes of `1` could not be shown: `2`", snapshotLabel @ handle, diffFailureText @ result ]
    ];
    closeSnapshot @ handle;
    StringJoin[
        "The user now sees ", quoted @ inlineText @ record[ "Title" ], " as a diff against your edits, and accepts or \
rejects each change there. ", handle, " is closed."
    ]
];

showChanges // endDefinition;


diffFailureText // beginDefinition;
diffFailureText[ failure: Failure[ _, _Association ] ] := failureMessage @ failure;
diffFailureText[ _ ] := "the comparison failed.";
diffFailureText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CloseNotebook*)
closeNotebook // beginDefinition;

closeNotebook[ args_Association ] := Module[ { handle },
    handle = resolveSnapshot @ args[ "notebook" ];
    closeSnapshot @ handle;
    "Closed " <> handle <> "; its edits were discarded."
];

closeNotebook // endDefinition;


closeSnapshot // beginDefinition;

closeSnapshot[ handle_String ] := (
    notebookFrontEnd[ "Close", $snapshots[ handle, "Notebook" ] ];
    KeyDropFrom[ $snapshots, handle ];
);

closeSnapshot // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*acpNotebookTitles*)

(* The notebooks that the tools would act on for notebook arguments of the agent (snapshot handles, or ids, titles or
   files of listed notebooks, as a call gives them), for the permission panel: <| spec -> <| "ID" -> id, "Title" -> title
   |> |> for each argument that names exactly one open snapshot or listed notebook; others are left out. It makes front
   end calls, so it is never called in a handler: the pump calls it when a permission request arrives (see
   Connection.wl, resolvePermissionNotebooks). Never throws; without a front end, only snapshots are resolved. *)
acpNotebookTitles // beginDefinition;

acpNotebookTitles[ { } ] := <| |>;

acpNotebookTitles[ specs: { __String } ] := Replace[
    acpCatchAll[ catchAlways @ notebookTitles @ specs, <| |> & ],
    Except[ _Association ] -> <| |>
];

acpNotebookTitles // endDefinition;


notebookTitles // beginDefinition;

notebookTitles[ specs_List ] := With[ { entries = listedNotebooks[ ] },
    DeleteMissing @ AssociationMap[ notebookTitle[ entries, # ] &, specs ]
];

notebookTitles // endDefinition;


notebookTitle // beginDefinition;

notebookTitle[ entries_List, spec_String ] := With[ { handle = snapshotHandle @ spec },
    If[ StringQ @ handle,
        <| "ID" -> handle, "Title" -> $snapshots[ handle, "Title" ] |>,
        Replace[
            Catch[ resolveNotebook[ entries, spec ], $toolErrorTag ],
            {
                KeyValuePattern @ { "ID" -> id_String, "Title" -> title_String } :> <| "ID" -> id, "Title" -> title |>,
                _ -> Missing[ "NotFound" ]
            }
        ]
    ]
];

notebookTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Attached Notebooks*)

(* The markdown of notebooks attached to a prompt (Attachments.wl). Not used by the tools. *)
(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellMarkdown*)

(* A cell's content as markdown (CellToString), with placeholders for graphics and expression URIs. CellToString takes
   time in proportion to the size of the boxes, also of the parts it leaves out, so a cell with more than "MaxCellBytes"
   of boxes (once its graphics are replaced) is read as a note, like a cell that can't be converted (which is also
   logged): neither delays or fails the whole conversion. The options are those of a prompt's attachments
   ($promptCellOptions, acpNotebookMarkdown): "MaxCellLength" and "MaxOutputLength" (CellToString's
   "MaxCellStringLength" and "MaxOutputCellStringLength"), "MaxCellBytes", "Graphics" (Automatic: "[graphics]", or a
   function that gives the text for a GraphicsBox or Graphics3DBox) and "Tool" (for the log). *)
cellMarkdown // beginDefinition;

cellMarkdown[ cell_Cell, id_String, opts_Association ] :=
    With[ { plain = graphicsReplaced[ cell, opts[ "Graphics" ] ] }, cellMarkdown[ plain, ByteCount @ plain, id, opts ] ];

cellMarkdown[ _Cell, bytes_Integer, _String, opts_Association ] /; bytes > opts[ "MaxCellBytes" ] :=
    "[this cell is too large to read: " <> ToString @ Ceiling[ bytes / 10^6 ] <> " MB]";

cellMarkdown[ cell_Cell, _Integer, id_String, opts_Association ] := Replace[
    withoutChatState @ catchAlways @ CellToString[
        cell,
        "ContentTypes"              -> { "Text" },
        "MaxCellStringLength"       -> opts[ "MaxCellLength" ],
        "MaxOutputCellStringLength" -> opts[ "MaxOutputLength" ]
    ],
    {
        text_String :> replaceExpressionURIs @ text,
        other_      :> (
            acpLog[ "NotebookToolFailed", <| "Tool" -> opts[ "Tool" ], "Cell" -> id, "Value" -> other |> ];
            "[this cell could not be read]"
        )
    }
];

cellMarkdown // endDefinition;

(* Graphics and images are not useful as box text: they are read as a placeholder *)
$graphicsRules = { (GraphicsBox|Graphics3DBox)[ ___ ] :> "[graphics]" };

(* The placeholders of the expression URIs that CellToString makes for content it can't show as text *)
$uriPlaceholders = <|
    "attachment" -> "[graphics]",
    "audio"      -> "[audio]",
    "dynamic"    -> "[dynamic content]",
    "expression" -> "[expression]",
    "video"      -> "[video]"
|>;

$$uriScheme = Alternatives @@ Keys @ $uriPlaceholders;


graphicsReplaced // beginDefinition;
graphicsReplaced[ cell_Cell, Automatic ] := cell /. $graphicsRules;
(* RuleCondition: the text is made also in boxes that hold their arguments (e.g. an InterpretationBox) *)
graphicsReplaced[ cell_Cell, f_ ] := cell /. box: (GraphicsBox|Graphics3DBox)[ ___ ] :> RuleCondition @ f @ box;
graphicsReplaced // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpDefusedCells*)

(* Cells (as the front end gives them, or as a notebook's text is parsed and made inert) without what CellToString
   would parse and evaluate: it evaluates an inline WL code template's input (ChatbookWLTemplate), imports a video or
   audio box, parses a raw data cell, interprets a box with an inline InterpretationFunction (makeExpressionString's
   ToExpression, e.g. a crafted Quantity or Tabular box), parses a string with linear syntax or with "\!" as two
   characters, and so on. An attached notebook may come from anywhere, so the message attachments (Attachments.wl,
   open notebooks and files) run the cells through this before CellToString. An inline WL template becomes its input boxes (shown as code, not run), a
   video or audio a placeholder, a raw data cell its text, an inline InterpretationFunction/DisplayFunction is dropped
   (a normal kernel box carries neither, so its output is unchanged; a crafted one can no longer run code when the box
   is interpreted), and strings with linear syntax are neutralized. *)
acpDefusedCells // beginDefinition;

(* some boxes hold their arguments: RuleCondition evaluates the replacements in them; the rules are applied until
   nothing changes, since what one returns can hold more (a template whose input is a template, a video box in a
   template's input, a box with an InterpretationFunction in the arguments of another) *)
acpDefusedCells[ cells_List ] := ReplaceAll[
    cells //. {
        TemplateBox[ args_, "ChatbookWLTemplate", ___ ] :> RuleCondition @ Replace[ args, { KeyValuePattern[ "input" -> input_ ] :> input, _ -> "" } ],
        TemplateBox[ _, "VideoBox1" | "VideoBox2", ___ ] -> "[video]",
        TemplateBox[ _, "AudioBox1", ___ ] -> "[audio]",
        Cell[ RawData[ s_String ], rest___ ] :> Cell[ s, rest ],
        TemplateBox[ args_, name_String, opts___ ] /; ! FreeQ[ { opts }, InterpretationFunction | DisplayFunction ] :>
            RuleCondition @ TemplateBox[ args, name, Sequence @@ FilterRules[ { opts }, Except[ InterpretationFunction | DisplayFunction ] ] ]
    },
    s_String /; StringContainsQ[ s, $$unsafeInString ] :> RuleCondition @ defusedString @ s
];

acpDefusedCells // endDefinition;


defusedString // beginDefinition;
defusedString[ s_String ] := StringReplace[ acpNeutralizeLinearSyntax @ s, "\\!" -> "\\\:fffd" ];
defusedString // endDefinition;

$$unsafeInString = RegularExpression[ "\\\\!|[\\x{f7c0}-\\x{f7cd}]" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpNotebookMarkdown*)

(* The markdown of a notebook's cells for a prompt (Attachments.wl): the content of each cell (cellMarkdown), without
   labels, and with these limits: no cut per cell, output cells cut at $promptOutputLength characters, cells with more
   than $promptCellBytes of boxes left out with a note. opts:
     "MaxCharacters" -> the most characters of the result (Infinity): the cells after that are left out, with a note
                        (a first cell with text that is longer is cut, with a note too);
     "Graphics"      -> Automatic ("[graphics]") or a function that gives the text for a GraphicsBox or Graphics3DBox
                        (Attachments.wl rasterizes them as images and gives "[image n]");
     "ActiveQ"       -> a function checked before each cell: once it gives False, the conversion stops.
   Gives <| "Markdown", "Cells" (in the notebook), "Shown" (converted), "Truncated" |> or Failure["Cancelled", ...].
   Makes front end calls (CellToString takes about a second per megabyte of boxes), so it runs on the kernel's main
   link. *)
acpNotebookMarkdown // beginDefinition;

acpNotebookMarkdown[ cells_List ] := acpNotebookMarkdown[ cells, <| |> ];

acpNotebookMarkdown[ cells_List, opts_Association ] := Catch[
    notebookMarkdown[
        Cases[ cells, _Cell ],
        <| $promptCellOptions, KeyTake[ opts, { "Graphics" } ] |>,
        Replace[ Lookup[ opts, "MaxCharacters", Infinity ], Except[ _Integer? Positive ] -> Infinity ],
        Lookup[ opts, "ActiveQ", True & ]
    ],
    $promptCancelTag
];

acpNotebookMarkdown // endDefinition;


notebookMarkdown // beginDefinition;

notebookMarkdown[ cells_List, opts_Association, max_, active_ ] := Module[ { parts, total, shown, cut, note },
    parts = Internal`Bag[ ];
    total = 0;
    shown = 0;
    cut   = False;
    Catch[
        Do[
            If[ ! TrueQ @ active[ ], Throw[ Failure[ "Cancelled", <| |> ], $promptCancelTag ] ];
            With[ { text = StringTrim @ cellMarkdown[ DeleteCases[ cell, (CellLabel|CellObject) -> _ ], "prompt", opts ] },
                Which[
                    text === "",
                        shown++,
                    total + StringLength @ text <= max,
                        Internal`StuffBag[ parts, text ];
                        total += StringLength @ text + 2;
                        shown++,
                    total === 0,
                        (* a first cell (with text) that alone is too long is cut *)
                        Internal`StuffBag[ parts, StringTake[ text, max ] ];
                        cut = True;
                        shown++;
                        Throw[ Null, $promptBudgetTag ],
                    True,
                        Throw[ Null, $promptBudgetTag ]
                ]
            ],
            { cell, cells }
        ],
        $promptBudgetTag
    ];
    (* a cut cell, then the cells that are left out *)
    note = StringJoin[
        If[ cut, "\n\n" <> $promptCellCut, "" ],
        Which[
            shown === Length @ cells - 1, "\n\n" <> $promptCellLeftOut,
            shown < Length @ cells      , "\n\n" <> TemplateApply[ $promptCellsLeftOut, { Length @ cells - shown } ],
            True                        , ""
        ]
    ];
    <|
        "Markdown"  -> StringRiffle[ Internal`BagPart[ parts, All ], "\n\n" ] <> note,
        "Cells"     -> Length @ cells,
        "Shown"     -> shown,
        "Truncated" -> note =!= ""
    |>
];

notebookMarkdown // endDefinition;

$promptOutputLength = 5000;   (* characters of an output cell in a prompt's attachment *)
$promptCellBytes    = 4 * 2^20; (* larger cells (boxes, graphics replaced) are not converted for a prompt *)

$promptCellOptions := <|
    "MaxCellLength"   -> Infinity,
    "MaxOutputLength" -> $promptOutputLength,
    "MaxCellBytes"    -> $promptCellBytes,
    "Graphics"        -> Automatic,
    "Tool"            -> "Attachments"
|>;

(* Notes for the agent (texts for the agent, not for the user, like the tools' descriptions) *)
$promptCellsLeftOut = "[The last `1` cells of this notebook are left out: the notebook is too large to attach whole.]";
$promptCellLeftOut  = "[The last cell of this notebook is left out: the notebook is too large to attach whole.]";
$promptCellCut      = "[The rest of this cell is left out: the notebook is too large to attach whole.]";

$promptBudgetTag = "Wolfram`Chatbook`ACP`NotebookTools`PromptBudget";
$promptCancelTag = "Wolfram`Chatbook`ACP`NotebookTools`PromptCancelled";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*replaceExpressionURIs*)

(* Expression URIs (![label](scheme://content-...)) refer to the kernel's $attachments, which the agent can't read. They
   are replaced by placeholders, also inside the linear syntax of video and audio boxes. *)
replaceExpressionURIs // beginDefinition;

replaceExpressionURIs[ text_String ] := StringReplace[
    text,
    {
        "\\!\\(\\*" ~~ ("VideoBox"|"AudioBox") ~~ "[\"![" ~~ Except[ "]" ]... ~~ "](" ~~ scheme: $$uriScheme ~~
            "://content-" ~~ (LetterCharacter|DigitCharacter).. ~~ ")\"]\\)" :> $uriPlaceholders @ scheme,
        "![" ~~ Except[ "]" ]... ~~ "](" ~~ scheme: $$uriScheme ~~ "://content-" ~~
            (LetterCharacter|DigitCharacter).. ~~ ")" :> $uriPlaceholders @ scheme
    }
];

replaceExpressionURIs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withoutChatState*)

(* CellToString runs without touching the state of chats: it would add components to the base prompt that a chat it
   interrupted is collecting (needsBasePrompt), and expression URIs to the kernel's $attachments. *)
withoutChatState // beginDefinition;
withoutChatState // Attributes = { HoldFirst };
withoutChatState[ eval_ ] := Block[ { needsBasePrompt = Null &, $attachments = <| |> }, eval ];
withoutChatState // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
