(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`NotebookTools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ACP`Common`" ];

(* The notebook tools of the agent (see docs/acp-window.md, "Notebook tools"): acpNotebookTools[] gives the LLMTools
   ListNotebooks, ReadNotebook, CreateNotebook, InsertCells, ReplaceCells and DeleteCells, which work on the notebooks
   that are open in the user's front end, for the MCP server that the ACP window offers to the agent. A tool's function
   takes the arguments as an Association and gives a String (JSON for the tools that list or change things, markdown
   for ReadNotebook), or a Failure whose "String" is an error text for the agent (AgentTools turns it into a tool result
   with isError).

   Rules:
   * Every tool makes front end calls, which a SocketListen or reader handler must never make (R2), and reading a long
     notebook can take a while, which in the pump would block the front end's Dynamics for as long: the tools run on
     the kernel's main link (a queued evaluation). Without a front end ($FrontEnd === Null), ListNotebooks lists
     nothing and the other tools give an error.
   * Only the notebooks that ListNotebooks lists can be reached: SourceNotebookObjectInformation's "Included" notebooks
     (not excluded from AI, visible, normal windows, no workspace chats such as the ACP window or the Notebook
     Assistant), without the Messages window, help pages and deployed notebooks, front to back.
   * Ids: a notebook's id is the start of its UUID (First @ nbo), a cell's the start of its UUID (First @ cell), at
     least $idLength characters, longer where that is needed to tell it from the other listed notebooks or the
     notebook's other cells (objects that share a UUID, e.g. a notebook file opened twice, also get their instance
     UUID). Any prefix of at least $minPrefixLength characters that matches one notebook or cell is accepted, and for
     notebooks also the exact window title or the file of the notebook. The agent never sees NotebookObject[...]
     expressions, and nothing it sends is ever ToExpression'd.
   * Markdown only: new cells are made by Chatbook's formatter (FormatChatOutput, ExplodeCell, InlineTemplateBoxes),
     never from Cell expressions. The front end's linear syntax characters are neutralized first, and cells with content
     that runs code (dynamic content, button functions, initializations, ...) are refused, so nothing the agent writes
     can evaluate anything when it is shown. The formatter itself loads and evaluates nothing for the agent
     (withUntrustedContent, in Formatting.wl): images become links, code is kept as it is written, and HTML entities are
     not decoded.
   * A read never lets the text of a notebook pass for the read's structure: tags in the text of cells and in the title
     are made inert (inertTags), and the write tools reverse that escaping exactly (uninertTags), so text read from a
     cell can be written back unchanged. It finds the user's selection without asking the front end about every cell,
     and it is limited in cells, characters and time, so that it does not hold up the user's evaluations for long.
   * Edits never move the user's selection (NotebookWrite to a NotebookLocationSpecifier with None) and never open
     dialogs; whether the agent may edit is decided by the agent's own permissions ($acpNotebookEditTools).
   * Errors are texts for the agent; internal failures are logged as "NotebookToolFailed" (acpLog) and the agent only
     learns that the tool failed.
   * The tools never change the state of a chat (withoutChatState): CellToString's base prompt bookkeeping
     (needsBasePrompt) is turned off, and the expression URIs of graphics and other content are made in a temporary
     store ($attachments) and replaced by placeholders such as "[graphics]". *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$idLength          = 8;       (* characters of a notebook or cell id (more where they are needed to make it unique) *)
$minPrefixLength   = 6;       (* the shortest start of an id that is accepted *)
$defaultReadLimit  = 100;     (* cells read by ReadNotebook by default *)
$maxReadLimit      = 1000;    (* cells read by ReadNotebook at most (a larger limit is lowered) *)
$readBudget        = 60000;   (* characters of cells in one ReadNotebook result (at least one cell is shown) *)
$readTimeBudget    = 5;       (* seconds after which ReadNotebook reads no more cells (at least one cell is shown) *)
$readChunk         = 50;      (* cells read from the front end at once *)
$cursorScan        = 1000;    (* cells before and after the cells read where a cursor between cells is looked for *)
$maxInlineDepth    = 10;      (* inline cells in inline cells followed to their cell (see topLevelCell) *)
$maxCellLength     = 8000;   (* characters of a cell (CellToString's "MaxCellStringLength") *)
$maxOutputLength   = 1000;    (* characters of an output cell ("MaxOutputCellStringLength") *)
$maxCellBytes      = 2^20;    (* larger cells are not converted (about a second per megabyte of boxes) *)
$maxMarkdownLength = 20000;   (* characters of markdown that the tools convert to cells (see markdownCells) *)
$markdownTimeLimit = 10;      (* seconds that converting the markdown of one tool call to cells may take *)
$maxQuotedLength   = 80;      (* characters of an argument that an error message repeats *)
$maxListedCells    = 10;      (* cell ids named in the selection summary of ReadNotebook *)

(* The tools that change notebooks the user already has open: the agent should ask before it runs them (CreateNotebook
   only opens a new window) *)
$acpNotebookEditTools = { "InsertCells", "ReplaceCells", "DeleteCells" };

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

(* Content of cells made from markdown that would run code when it is shown or clicked. The only dynamic content that
   the formatter itself makes is the front end resource of Chatbook's missing-image placeholder, which runs nothing in
   the kernel. *)
$$codeBox = Alternatives[
    _DynamicBox, _DynamicModuleBox, _DynamicWrapperBox, _Dynamic, _DynamicModule, _DynamicWrapper,
    _ActionMenuBox, _EventHandlerTag
];

$$codeOptionName = Alternatives[
    ButtonFunction, CellDynamicExpression, CellEpilog, CellEvaluationFunction, CellEventActions, CellProlog,
    Deinitialization, Initialization, NotebookDynamicExpression, NotebookEventActions
];

$$codeOption = (Rule|RuleDelayed)[ $$codeOptionName, _ ];

$$frontEndResource = DynamicBox[ _FEPrivate`FrontEndResource | _FEPrivate`FrontEndResource[ ___ ], ___ ];

$toolErrorTag = "Wolfram`Chatbook`ACP`NotebookTools`ToolError";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tools*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpNotebookTools*)

(* The notebook tools as LLMTools, in this order: ListNotebooks, ReadNotebook, CreateNotebook, InsertCells,
   ReplaceCells, DeleteCells *)
acpNotebookTools // beginDefinition;
acpNotebookTools[ ] := KeyValueMap[ LLMTool @ <| "Name" -> #1, #2, "Options" -> { } |> &, $toolSpecs ];
acpNotebookTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Descriptions*)

(* What the tools have in common, for the agent: they work on the live notebooks, not on files *)
$frontEndNote = "\
It works on the notebooks as they are open in the user's Wolfram front end (desktop app), unsaved changes included. \
For .nb files that are not open, use file tools instead.";

$markdownNote = "\
The markdown is converted like a Wolfram chat answer: # headings become Title, ## Section, ### Subsection and \
#### Subsubsection cells, ```wl code blocks become Input cells (they are not evaluated), other code blocks become code \
cells of their language, and paragraphs, lists, tables and math ($...$) become text, item and table cells. Images are \
not loaded: an image becomes a link to its URL or file. Write at most 20000 characters of markdown per call; write \
longer content in several calls.";

$listNotebooksDescription = "\
Lists the notebooks that are open in the user's Wolfram front end, most recently used first, as a JSON array of \
{id, title, file, modified, cells, selected}: the notebook's id (for the other notebook tools), its window title, its \
file (null if it was never saved), whether it has unsaved changes, its number of cells, and whether it is the \
notebook the user is working in (always the first one). When the user talks about \"this notebook\" or \"my \
notebook\", they usually mean the first one. Palettes, dialogs, help pages, chat windows and notebooks that the user \
excluded from AI are not listed. " <> $frontEndNote;

$readNotebookDescription = "\
Reads a notebook that is open in the user's Wolfram front end as markdown. Each cell is shown as \
<cell id='...' style='...' label='...'>...</cell> with its content as markdown (Wolfram Language code in ```wl \
blocks), and the user's selection is marked with <selection>...</selection>. Long notebooks are read in parts: the \
result says how to continue with offset. Use the cell ids with InsertCells, ReplaceCells and DeleteCells. " <>
    $frontEndNote;

$createNotebookDescription = "\
Creates a new notebook from markdown and opens it in the user's Wolfram front end (it is not saved to a file). " <>
    $markdownNote <> " Returns JSON {id, title, cells} with the new notebook's id, its window title and the ids of \
its cells. To write a .nb file instead, use a file tool.";

$insertCellsDescription = "\
Inserts new cells, written as markdown, into a notebook that is open in the user's Wolfram front end, after or before \
the cell with the given id, or at the end of the notebook. The user's selection does not move. " <> $markdownNote <>
    " Returns JSON {notebook, cells} with the ids of the new cells. " <> $frontEndNote;

$replaceCellsDescription = "\
Replaces cells of a notebook that is open in the user's Wolfram front end with new cells written as markdown: the new \
cells go where the first of the given cells is, and the given cells are deleted. Read the notebook first for the cell \
ids. " <> $markdownNote <> " Returns JSON {notebook, cells, replaced} with the ids of the new cells and the number of \
cells replaced. " <> $frontEndNote;

$deleteCellsDescription = "\
Deletes cells from a notebook that is open in the user's Wolfram front end. Read the notebook first for the cell ids. \
Returns JSON {notebook, deleted} with the number of cells deleted. " <> $frontEndNote;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Parameters*)
requiredString // beginDefinition;
requiredString[ name_String, help_String ] :=
    name -> <| "Interpreter" -> "String", "Help" -> help, "Required" -> True |>;
requiredString // endDefinition;

$notebookParameter = requiredString[
    "notebook",
    "\
The notebook: its id from ListNotebooks (or the start of it, at least 6 characters), its exact window title, or the \
full path of its file"
];

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
    "ReadNotebook" -> <|
        "DisplayName" -> "Read Notebook",
        "Description" -> $readNotebookDescription,
        "Function"    -> readNotebookTool,
        "Parameters"  -> {
            $notebookParameter,
            "offset" -> <|
                "Interpreter" -> "Integer",
                "Help"        -> "The number of the first cell to read (1 is the first cell; the default is 1)",
                "Required"    -> False
            |>,
            "limit" -> <|
                "Interpreter" -> "Integer",
                "Help"        -> "\
The largest number of cells to read (the default is 100, at most 1000); fewer are read if the cells are long",
                "Required"    -> False
            |>
        }
    |>,
    "CreateNotebook" -> <|
        "DisplayName" -> "Create Notebook",
        "Description" -> $createNotebookDescription,
        "Function"    -> createNotebookTool,
        "Parameters"  -> { requiredString[ "markdown", "The content of the new notebook as markdown" ] }
    |>,
    "InsertCells" -> <|
        "DisplayName" -> "Insert Cells",
        "Description" -> $insertCellsDescription,
        "Function"    -> insertCellsTool,
        "Parameters"  -> {
            $notebookParameter,
            requiredString[ "markdown", "The new cells as markdown" ],
            "cell" -> <|
                "Interpreter" -> "String",
                "Help"        -> "\
The id of the cell to insert after or before (from ReadNotebook); without it, the cells are inserted at the end of the \
notebook (or at its beginning with position \"before\")",
                "Required"    -> False
            |>,
            "position" -> <|
                "Interpreter" -> "String",
                "Help"        -> "\"after\" (the default) or \"before\" the cell",
                "Required"    -> False
            |>
        }
    |>,
    "ReplaceCells" -> <|
        "DisplayName" -> "Replace Cells",
        "Description" -> $replaceCellsDescription,
        "Function"    -> replaceCellsTool,
        "Parameters"  -> {
            $notebookParameter,
            requiredString[ "cells", "The ids of the cells to replace (from ReadNotebook), separated by commas" ],
            requiredString[ "markdown", "The new cells as markdown" ]
        }
    |>,
    "DeleteCells" -> <|
        "DisplayName" -> "Delete Cells",
        "Description" -> $deleteCellsDescription,
        "Function"    -> deleteCellsTool,
        "Parameters"  -> {
            $notebookParameter,
            requiredString[ "cells", "The ids of the cells to delete (from ReadNotebook), separated by commas" ]
        }
    |>
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool functions*)

(* The functions of the LLMTools: they take the arguments (an Association; LLMTool gives Missing["NoInput"] for
   optional parameters that were not given) and can also be called directly *)
listNotebooksTool // beginDefinition;
listNotebooksTool[ _ ] := toolResult[ "ListNotebooks", listNotebooks[ ] ];
listNotebooksTool // endDefinition;

readNotebookTool // beginDefinition;
readNotebookTool[ args_ ] := toolResult[ "ReadNotebook", readNotebook @ toolArguments @ args ];
readNotebookTool // endDefinition;

createNotebookTool // beginDefinition;
createNotebookTool[ args_ ] := toolResult[ "CreateNotebook", createNotebook @ toolArguments @ args ];
createNotebookTool // endDefinition;

insertCellsTool // beginDefinition;
insertCellsTool[ args_ ] := toolResult[ "InsertCells", insertCells @ toolArguments @ args ];
insertCellsTool // endDefinition;

replaceCellsTool // beginDefinition;
replaceCellsTool[ args_ ] := toolResult[ "ReplaceCells", replaceCells @ toolArguments @ args ];
replaceCellsTool // endDefinition;

deleteCellsTool // beginDefinition;
deleteCellsTool[ args_ ] := toolResult[ "DeleteCells", deleteCells @ toolArguments @ args ];
deleteCellsTool // endDefinition;


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
(*cellIDArguments*)

(* The cell ids in an argument: separated by commas, semicolons or white space; brackets and quotes (e.g. a JSON array
   given as a string) are ignored *)
cellIDArguments // beginDefinition;

cellIDArguments[ spec_, name_String ] := Replace[
    cellIDArguments0 @ spec,
    { } :> missingArgument @ name
];

cellIDArguments // endDefinition;


cellIDArguments0 // beginDefinition;

cellIDArguments0[ s_String ] :=
    DeleteDuplicates @ StringSplit[ s, (WhitespaceCharacter | "," | ";" | "[" | "]" | "\"" | "'" | "`").. ];

cellIDArguments0[ list: { ___String } ] := DeleteDuplicates @ Flatten[ cellIDArguments0 /@ list ];
cellIDArguments0[ _ ] := { };

cellIDArguments0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*anchorArgument*)

(* The cell id that InsertCells' parameter cell gives, or None if it is not given *)
anchorArgument // beginDefinition;

anchorArgument[ Missing[ ___ ] | Null ] := None;
anchorArgument[ s_String ] /; StringTrim @ s === "" := None;

anchorArgument[ spec_ ] := Replace[
    cellIDArguments[ spec, "cell" ],
    { { id_String } :> id, _ :> toolError[ "The parameter cell takes one cell id, not `1`.", quoted @ spec ] }
];

anchorArgument // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cleanID*)

(* An id as the agent may give it: without white space and quotes around it, in lower case (UUIDs are) *)
cleanID // beginDefinition;
cleanID[ s_String ] := ToLowerCase @ StringTrim[ s, (WhitespaceCharacter | "\"" | "'" | "`").. ];
cleanID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Identifiers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*objectKeys*)

(* The key of each notebook or cell: its UUID, in lower case. Objects that share a UUID (a copy of a notebook file that
   is open twice, cells written with the same ExpressionUUID) get their instance UUID too, so that the keys are
   unique. *)
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

(* The entries (notebooks or cells, each with a "Key") that an id of the agent stands for: the one whose key it is, else
   those whose keys start with it (if it has at least $minPrefixLength characters) *)
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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveNotebook*)

(* The listed notebook that the agent means: by id (or a start of it), else by exact window title, else by file *)
resolveNotebook // beginDefinition;

resolveNotebook[ spec_ ] := (
    requireFrontEnd[ ];
    resolveNotebook[ listedNotebooks[ ], spec ]
);

resolveNotebook[ entries_List, spec0_ ] := Module[ { spec, matches },
    spec = stringArgument[ spec0, "notebook" ];
    matches = idMatches[ entries, cleanID @ spec ];
    If[ matches === { }, matches = Select[ entries, #[ "Title" ] === spec & ] ];
    If[ matches === { }, matches = Select[ entries, sameFileQ[ #[ "File" ], spec ] & ] ];
    Switch[ Length @ matches,
        1, First @ matches,
        0, toolError[
            "No open notebook matches `1`. Call ListNotebooks for the ids of the notebooks that are open.",
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
(* ::Subsection::Closed:: *)
(*requireEditable*)
requireEditable // beginDefinition;

requireEditable[ entry_Association ] :=
    If[ AbsoluteCurrentValue[ entry[ "NotebookObject" ], Editable ] === False,
        toolError[ "The notebook `1` is not editable.", notebookLabel @ entry ]
    ];

requireEditable // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cells*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookCells*)

(* The cells of a notebook, in order, as <| "CellObject", "Key", "ID", "Index" |> *)
notebookCells // beginDefinition;

notebookCells[ entry_Association ] := Module[ { cells, keys },
    cells = Quiet @ Cells @ entry[ "NotebookObject" ];
    If[ ! MatchQ[ cells, { ___CellObject } ], notebookClosed @ entry ];
    keys = objectKeys @ cells;
    MapThread[
        <| "CellObject" -> #1, "Key" -> #2, "ID" -> #3, "Index" -> #4 |> &,
        { cells, keys, uniqueIDs @ keys, Range @ Length @ cells }
    ]
];

notebookCells // endDefinition;


notebookClosed // beginDefinition;
notebookClosed[ entry_Association ] := toolError[ "The notebook `1` was closed.", notebookLabel @ entry ];
notebookClosed // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellProperty*)

(* A property of each cell from Developer`CellInformation (e.g. "CursorPosition", "Evaluating"), default if unknown *)
cellProperty // beginDefinition;

cellProperty[ { }, _String, _ ] := { };

cellProperty[ cells: { __Association }, key_String, default_ ] := Module[ { info },
    info = Quiet @ Developer`CellInformation @ Lookup[ cells, "CellObject" ];
    If[ ListQ @ info && Length @ info === Length @ cells,
        Replace[ info, { rules: { ___Rule } :> Lookup[ rules, key, default ], _ :> default }, { 1 } ],
        ConstantArray[ default, Length @ cells ]
    ]
];

cellProperty // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveCells*)

(* The cells of a notebook that the agent's ids stand for (each id must match exactly one cell), in document order *)
resolveCells // beginDefinition;

resolveCells[ cells_List, ids: { __String }, entry_Association ] :=
    SortBy[ DeleteDuplicates[ resolveCell[ cells, #, entry ] & /@ ids ], #[ "Index" ] & ];

resolveCells // endDefinition;


resolveCell // beginDefinition;

resolveCell[ cells_List, id_String, entry_Association ] := With[ { matches = idMatches[ cells, cleanID @ id ] },
    Switch[ Length @ matches,
        1, First @ matches,
        0, toolError[
            "The notebook `1` has no cell with the id `2`. Read the notebook again for the ids of its cells.",
            notebookLabel @ entry,
            quoted @ id
        ],
        _, toolError[
            "`1` matches more than one cell of the notebook `2`: `3`. Use the whole cell id.",
            quoted @ id,
            notebookLabel @ entry,
            StringRiffle[ Lookup[ matches, "ID" ], ", " ]
        ]
    ]
];

resolveCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*requireDeletable*)

(* Cells that are being evaluated or that are not deletable are never deleted (or replaced) *)
requireDeletable // beginDefinition;

requireDeletable[ entry_Association, cells: { __Association } ] := Module[ { evaluating, deletable, locked },
    evaluating = Pick[ cells, cellProperty[ cells, "Evaluating", False ], True ];
    If[ evaluating =!= { },
        toolError[
            "The cell `1` of the notebook `2` is being evaluated. Wait until it is finished.",
            First[ evaluating ][ "ID" ],
            notebookLabel @ entry
        ]
    ];
    deletable = AbsoluteCurrentValue[ Lookup[ cells, "CellObject" ], Deletable ];
    locked = If[ ListQ @ deletable && Length @ deletable === Length @ cells, Pick[ cells, deletable, False ], { } ];
    If[ locked =!= { },
        toolError[
            "The cell `1` of the notebook `2` can't be deleted: the notebook does not allow it.",
            First[ locked ][ "ID" ],
            notebookLabel @ entry
        ]
    ]
];

requireDeletable // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ListNotebooks*)
listNotebooks // beginDefinition;

listNotebooks[ ] := toJSON @ MapIndexed[
    <|
        "id"       -> #1[ "ID" ],
        "title"    -> Replace[ #1[ "Title" ], None -> Null ],
        "file"     -> Replace[ #1[ "File" ], None -> Null ],
        "modified" -> #1[ "Modified" ],
        "cells"    -> cellCount @ #1[ "NotebookObject" ],
        "selected" -> #2 === { 1 }
    |> &,
    listedNotebooks[ ]
];

listNotebooks // endDefinition;


cellCount // beginDefinition;
cellCount[ nbo_NotebookObject ] := Replace[ Quiet @ Cells @ nbo, { cells_List :> Length @ cells, _ -> 0 } ];
cellCount // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ReadNotebook*)
readNotebook // beginDefinition;

readNotebook[ args_Association ] := Module[ { entry, offset, limit, cells, n, last, selection, body, shown },
    entry  = resolveNotebook @ args[ "notebook" ];
    offset = countArgument[ args[ "offset" ], "offset", 1 ];
    limit  = Min[ countArgument[ args[ "limit" ], "limit", $defaultReadLimit ], $maxReadLimit ];
    cells  = notebookCells @ entry;
    n      = Length @ cells;
    If[ n > 0 && offset > n,
        toolError[ "The offset `1` is past the last cell: the notebook has `2` cells.", offset, n ]
    ];
    last = Min[ n, offset + limit - 1 ];
    selection = selectionCursors[ entry, cells, offset, last ];
    { body, shown } = readCells[ entry, cells, selection[ "Cursors" ], offset, last ];
    StringJoin[ readHeader[ entry, cells, selection ], body, readFooter[ offset, shown, n ] ]
];

readNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readHeader*)
readHeader // beginDefinition;

readHeader[ entry_Association, cells_List, selection_Association ] := StringJoin[
    "# Notebook ", quoted @ inlineText @ Replace[ entry[ "Title" ], None -> "Untitled" ], "\n\n",
    "- id: ", entry[ "ID" ], "\n",
    "- file: ", Replace[ entry[ "File" ], { file_String :> inlineText @ file, None -> "none (never saved)" } ], "\n",
    "- unsaved changes: ", If[ TrueQ @ entry[ "Modified" ], "yes", "no" ], "\n",
    "- cells: ", ToString @ Length @ cells, "\n",
    "- selection: ", selectionSummary[ cells, selection[ "Cursors" ], selection[ "Range" ] ], "\n\n",
    $readLegend, "\n\n"
];

readHeader // endDefinition;


$readLegend = "\
Each cell is shown as <cell id='...' style='...' label='...'>...</cell> with its content as markdown; the label is \
the cell's In/Out label, if it has one. <selection>...</selection> marks the user's selection and \
<selection></selection> the position of the cursor. In the text of cells, the \"<\" of anything that looks like these \
tags is written as \"&lt;\", and the \"&\" of text that already looks like such an escape (\"&lt;cell\", \"&amp;lt;cell\", \
...) as \"&amp;\"; the write tools undo this exactly, so text read from a cell can be written back unchanged. \" ... \" \
marks text left out of a long cell, and [graphics] stands for graphics and images.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inlineText*)

(* A title or file name in the result of a read or an error: on one line, with inert tags *)
inlineText // beginDefinition;
inlineText[ text_String ] := inertTags @ StringReplace[ text, ("\r\n"|"\n"|"\r") -> " " ];
inlineText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inertTags*)

(* Text from a notebook with the tags of a read (<cell ...>, </cell>, <selection>, </selection>, in any case) made
   inert by writing their "<" as "&lt;", so that the text of a cell can't pass for cells or for the user's selection.
   Other text, such as code with "<", is kept as it is. Text that already looks like such an escape ("&lt;cell",
   "&amp;lt;cell", "&amp;amp;lt;cell", ..., in any case) gets one more "amp;" (its "&" is written as "&amp;"), so that
   it stays distinct from an escaped tag. Every escape is then undone by removing one "amp;" (or the "&lt;" of a tag),
   so the write tools reverse this exactly (uninertTags), and a read-then-write round trip leaves the text unchanged.
   Both rules run in one pass, so nothing that one of them writes is escaped again. *)
inertTags // beginDefinition;

inertTags[ text_String ] := StringReplace[
    text,
    {
        "&" ~~ escape: ("amp;"... ~~ "lt;" ~~ $$readTag) :> "&amp;" <> escape,
        "<" ~~ tag: $$readTag :> "&lt;" <> tag
    },
    IgnoreCase -> True
];

inertTags // endDefinition;

(* The name of a tag of a read, after its "<" *)
$$readTag = ("/"|"") ~~ ("cell"|"selection");

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*selectionCursors*)

(* The user's selection as the "CursorPosition" of each cell (as Developer`CellInformation gives it, None for the cells
   without it, "InlineCell" -> position for a selection in an inline cell, see selectedCursor), and the range of cells
   in which a cursor between cells was looked for. Developer`CellInformation for all the cells of a long notebook takes
   long (2.7 s for 10,000 cells), so only the selected cells are asked (SelectedCells, which also gives the cell, or the
   inline cell, with the cursor or selected text; see topLevelCell), or, if there are none (the cursor is between
   cells), the cells from $cursorScan before the cells read to $cursorScan after them, $readChunk at a time, until the
   cursor is found, and if it is not there, the first and the last cell (cursorAtEnds). *)
selectionCursors // beginDefinition;

selectionCursors[ entry_Association, cells_List, first_Integer, last_Integer ] := Module[
    { n, index, selected, range, rules },
    n        = Length @ cells;
    index    = AssociationThread[ Lookup[ cells, "CellObject", { } ], Range @ n ];
    selected = DeleteMissing[ topLevelCell[ index, # ] & /@ selectedCells @ entry[ "NotebookObject" ] ];
    selected = SortBy[ DeleteDuplicatesBy[ selected, First ], First ];
    range    = { 1, n };
    rules    = Which[
        Length @ selected === 1,
            { selectedCursor[ cells, First @ selected ] },
        selected =!= { },
            (* several cells can only be selected as cells *)
            Thread[ selected[[ All, 1 ]] -> "CellBracket" ],
        True,
            range = { Max[ 1, first - $cursorScan ], Min[ n, last + $cursorScan ] };
            Replace[ cursorBetweenCells[ cells, Range @@ range ], { } :> cursorAtEnds[ cells, range ] ]
    ];
    <| "Cursors" -> ReplacePart[ ConstantArray[ None, n ], rules ], "Range" -> range |>
];

selectionCursors // endDefinition;


selectedCells // beginDefinition;
selectedCells[ nbo_NotebookObject ] := Replace[ Quiet @ SelectedCells @ nbo, Except[ { ___CellObject } ] -> { } ];
selectedCells // endDefinition;


(* The "CursorPosition" of the only selected cell j: the front end's, or, for a selection in an inline cell of cell j,
   the whole inline cell: the front end gives the "CursorPosition" only of the inline cell, not of the cell that has it
   (None). The inline cell counts as one character of the cell's text, at position k (see topLevelCell), so it is marked
   like the front end gives it when the inline cell itself is selected in the cell: "InlineCell" -> { k - 1, k }. *)
selectedCursor // beginDefinition;

selectedCursor[ cells_List, { j_Integer, None } ] :=
    j -> First @ cellProperty[ cells[[ { j } ]], "CursorPosition", "CellBracket" ];

selectedCursor[ _List, { j_Integer, k_Integer } ] := j -> ("InlineCell" -> { k - 1, k });

selectedCursor // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*topLevelCell*)

(* A cell from SelectedCells as { j, None } if it is cell j of the notebook, or { j, k } if it is an inline cell of cell
   j whose outermost inline cell is at position k of cell j's text. SelectedCells gives the innermost cell with the
   cursor or selected text, an inline cell (such as a formula in a text cell) if it is in one, and Cells does not list
   inline cells. Their "InlineCellPosition" is the position of each inline cell in the one that has it, from 1, the
   innermost first ({7, 8} for an inline cell at 7 in an inline cell at 8 of a cell), and ParentCell leads from each to
   the one that has it, so as many ParentCell steps as there are positions (at most $maxInlineDepth) lead to the cell of
   the notebook. ParentCell also leads from an attached cell (such as a menu or an input field attached to a cell) to
   the cell it is attached to, but its position is -1 ({-1}, or {3, -1} for an inline cell in it): such a cell is not
   part of the notebook's content and gives Missing, as does anything else that does not lead to a cell of the
   notebook, so that the cursor is then looked for between cells. *)
topLevelCell // beginDefinition;

topLevelCell[ index_Association, cell_CellObject ] /; KeyExistsQ[ index, cell ] := { index @ cell, None };

topLevelCell[ index_Association, cell_CellObject ] := Module[ { positions, top },
    positions = First @ cellProperty[ { <| "CellObject" -> cell |> }, "InlineCellPosition", None ];
    top = If[ MatchQ[ positions, { Repeated[ _Integer? Positive, $maxInlineDepth ] } ],
              Nest[ Quiet @ ParentCell @ # &, cell, Length @ positions ],
              None
          ];
    If[ KeyExistsQ[ index, top ], { index @ top, Last @ positions }, Missing[ "NotInNotebook" ] ]
];

topLevelCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cursorBetweenCells*)

(* The cursor between two cells, looked for in the given cells (their numbers), $readChunk at a time: rules for the
   "CursorPosition" of the cell above it ("BelowCell") and of the cell below it ("AboveCell"), like the front end gives
   them, or { } if it isn't there *)
cursorBetweenCells // beginDefinition;

cursorBetweenCells[ cells_List, indices: { ___Integer } ] := Catch[
    Do[
        Module[ { found },
            found = FirstCase[
                Transpose @ { chunk, cellProperty[ cells[[ chunk ]], "CursorPosition", None ] },
                { j_, cursor: "AboveCell"|"BelowCell" } :> betweenCells[ Length @ cells, j, cursor ]
            ];
            If[ ListQ @ found, Throw[ found, $cursorTag ] ]
        ],
        { chunk, Partition[ indices, UpTo @ $readChunk ] }
    ];
    { },
    $cursorTag
];

cursorBetweenCells // endDefinition;


(* The cursor next to the first or the last cell, where it was not looked for yet (range): before the first and after
   the last cell are the most common places of a cursor far from the cells read (in a new notebook, or once the user
   evaluated the last cell of a long one). Both cells are asked in one Developer`CellInformation call. *)
cursorAtEnds // beginDefinition;

cursorAtEnds[ { }, _ ] := { };

cursorAtEnds[ cells_List, { first_Integer, last_Integer } ] :=
    cursorBetweenCells[ cells, Complement[ { 1, Length @ cells }, Range[ first, last ] ] ];

cursorAtEnds // endDefinition;

$cursorTag = "Wolfram`Chatbook`ACP`NotebookTools`Cursor";


(* Both cells next to the cursor, from the one that was found *)
betweenCells // beginDefinition;

betweenCells[ _Integer, j_Integer, "AboveCell" ] :=
    Append[ If[ j > 1, { j - 1 -> "BelowCell" }, { } ], j -> "AboveCell" ];

betweenCells[ n_Integer, j_Integer, "BelowCell" ] :=
    Prepend[ If[ j < n, { j + 1 -> "AboveCell" }, { } ], j -> "BelowCell" ];

betweenCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*selectionSummary*)

(* Where the user's selection is in the notebook, from the "CursorPosition" of each cell (selectionCursors), and the
   cells in which a cursor between cells was looked for if that was not all of them *)
selectionSummary // beginDefinition;

selectionSummary[ cells_List, cursors_List, { first_Integer, last_Integer } ] :=
    With[ { summary = selectionSummary[ cells, cursors ] },
        If[ summary === "none" && { first, last } =!= { 1, Length @ cells },
            "none in cells " <> ToString @ first <> "-" <> ToString @ last,
            summary
        ]
    ];

selectionSummary[ cells_List, cursors_List ] := Module[ { inCell, inline, selected, above, below, n },
    n        = Length @ cells;
    inCell   = FirstPosition[ cursors, { _Integer, _Integer }, None, { 1 }, Heads -> False ];
    inline   = FirstPosition[ cursors, "InlineCell" -> _, None, { 1 }, Heads -> False ];
    selected = Flatten @ Position[ cursors, "CellBracket", { 1 }, Heads -> False ];
    above    = FirstPosition[ cursors, "AboveCell", None, { 1 }, Heads -> False ];
    below    = FirstPosition[ cursors, "BelowCell", None, { 1 }, Heads -> False ];
    Which[
        inCell =!= None,
            With[ { j = First @ inCell },
                If[ SameQ @@ cursors[[ j ]],
                    "the cursor is in cell " <> cellRef[ cells, j ],
                    "text in cell " <> cellRef[ cells, j ] <> " is selected"
                ]
            ],
        inline =!= None,
            "the cursor or selected text is in an inline cell (such as a formula) of cell " <>
                cellRef[ cells, First @ inline ],
        Length @ selected === 1,
            "cell " <> cellRef[ cells, First @ selected ] <> " is selected",
        selected =!= { },
            StringJoin[
                "cells ",
                StringRiffle[ cellRef[ cells, # ] & /@ Take[ selected, UpTo @ $maxListedCells ], ", " ],
                If[ Length @ selected > $maxListedCells,
                    " and " <> ToString[ Length @ selected - $maxListedCells ] <> " more",
                    ""
                ],
                " are selected"
            ],
        above === { 1 },
            "the cursor is before the first cell",
        above =!= None,
            "the cursor is between cells " <> cellRef[ cells, First @ above - 1 ] <> " and " <>
                cellRef[ cells, First @ above ],
        below === { n },
            "the cursor is after the last cell",
        below =!= None,
            "the cursor is between cells " <> cellRef[ cells, First @ below ] <> " and " <>
                cellRef[ cells, First @ below + 1 ],
        True,
            "none"
    ]
];

selectionSummary // endDefinition;


cellRef // beginDefinition;
cellRef[ cells_List, j_Integer ] := ToString @ j <> " (id " <> cells[[ j, "ID" ]] <> ")";
cellRef // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readFooter*)
readFooter // beginDefinition;

readFooter[ first_Integer, last_Integer, n_Integer ] := Which[
    n === 0,
        "The notebook has no cells.",
    last < n,
        StringTemplate[ "\n\nShowing cells `1`-`2` of `3`; call again with offset=`4` to read more." ][
            first, last, n, last + 1
        ],
    first > 1,
        StringTemplate[ "\n\nShowing cells `1`-`2` of `3`." ][ first, last, n ],
    True,
        ""
];

readFooter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readCells*)

(* The text of the cells first to last, as far as $readBudget allows (but at least one cell), and the number of the
   last cell read. The cells are read from the front end $readChunk at a time, so a long notebook is not read beyond
   the budget. Converting a cell can take up to about a second (see cellMarkdown), so no more cells are read once
   $readTimeBudget seconds have passed. *)
readCells // beginDefinition;

readCells[ _, _List, _List, first_Integer, last_Integer ] /; last < first := { "", first - 1 };

readCells[ entry_Association, cells_List, cursors_List, first_Integer, last_Integer ] := Module[
    { total = 0, shown = first - 1, deadline = AbsoluteTime[ ] + $readTimeBudget, texts },
    texts = Reap[
        Catch[
            Do[
                Module[ { chunk, read },
                    chunk = Range[ i, Min[ i + $readChunk - 1, last ] ];
                    read = notebookRead @ cells[[ chunk, "CellObject" ]];
                    If[ ! MatchQ[ read, { ___Cell } ] || Length @ read =!= Length @ chunk, notebookClosed @ entry ];
                    (* The notebook may be anything the user has open: defuse what CellToString would evaluate before
                       converting it, the same way an attached notebook is defused (acpDefusedCells). *)
                    read = acpDefusedCells @ read;
                    Do[
                        With[ { j = chunk[[ k ]] },
                            If[ j > first && AbsoluteTime[ ] > deadline, Throw[ Null, $budgetTag ] ];
                            With[ { text = cellBlock[ read[[ k ]], cells, cursors, j ] },
                                If[ j > first && total + StringLength @ text > $readBudget, Throw[ Null, $budgetTag ] ];
                                Sow @ text;
                                total += StringLength @ text;
                                shown = j
                            ]
                        ],
                        { k, Length @ chunk }
                    ]
                ],
                { i, first, last, $readChunk }
            ],
            $budgetTag
        ]
    ][[ 2 ]];
    { StringRiffle[ Flatten @ texts, "\n\n" ], shown }
];

readCells // endDefinition;

$budgetTag = "Wolfram`Chatbook`ACP`NotebookTools`ReadBudget";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellBlock*)

(* Cell j as <cell id='...' style='...' label='...'>markdown</cell>, with the marker of a cursor between cells before
   or after it ("AboveCell", or "BelowCell" if the next cell does not have "AboveCell") *)
cellBlock // beginDefinition;

cellBlock[ cell_Cell, cells_List, cursors_List, j_Integer ] := Module[ { label, plain, content },
    label   = FirstCase[ cell, (CellLabel -> l_String) :> l, None, { 1 } ];
    plain   = DeleteCases[ cell, (CellLabel|CellObject) -> _ ];
    content = cellContent[ plain, cursors[[ j ]], cells[[ j, "ID" ]] ];
    StringJoin[
        If[ cursors[[ j ]] === "AboveCell", $cursorMarker <> "\n\n", "" ],
        "<cell id='", cells[[ j, "ID" ]], "'",
        xmlAttribute[ "style", cellStyleName @ plain ],
        xmlAttribute[ "label", label ],
        ">",
        If[ content === "", "", "\n" <> content <> "\n" ],
        "</cell>",
        If[ cursors[[ j ]] === "BelowCell" && ( j === Length @ cursors || cursors[[ j + 1 ]] =!= "AboveCell" ),
            "\n\n" <> $cursorMarker,
            ""
        ]
    ]
];

cellBlock // endDefinition;

$cursorMarker := $cursorMarker = $leftSelectionIndicator <> $rightSelectionIndicator;


cellStyleName // beginDefinition;
cellStyleName[ Cell[ _, style_String, ___ ] ] := style;
cellStyleName[ _ ] := None;
cellStyleName // endDefinition;


xmlAttribute // beginDefinition;
xmlAttribute[ _String, None ] := "";

xmlAttribute[ name_String, value_String ] := StringJoin[
    " ", name, "='",
    StringReplace[ value, { "&" -> "&amp;", "'" -> "&apos;", "<" -> "&lt;", ">" -> "&gt;", "\n" -> " " } ],
    "'"
];

xmlAttribute // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellContent*)

(* A cell's markdown with the user's selection in it marked by <selection> tags. The cell's own text can have such
   tags (or <cell> tags), so the selection is first marked with markers that can't be in the cell (selectionMarkers),
   the tags in the cell's text are made inert, and then the markers become tags. A selection in an inline cell marks
   the whole inline cell (see selectedCursor). *)
cellContent // beginDefinition;

cellContent[ cell_Cell, "InlineCell" -> cursor_, id_String ] := cellContent[ cell, cursor, id ];

cellContent[ cell_Cell, cursor: { _Integer, _Integer } | "CellBracket", id_String ] :=
    With[ { markers = selectionMarkers[ ] },
        StringReplace[
            inertTags @ cellMarkdown[ markSelection[ cell, cursor, markers ], id ],
            Thread[ markers -> { $leftSelectionIndicator, $rightSelectionIndicator } ]
        ]
    ];

cellContent[ cell_Cell, _, id_String ] := inertTags @ cellMarkdown[ cell, id ];

cellContent // endDefinition;


(* Markers of the start and the end of a selection that the text of a notebook can't have: letters and a random UUID,
   which CellToString keeps as they are *)
selectionMarkers // beginDefinition;

selectionMarkers[ ] := With[ { uuid = StringDelete[ CreateUUID[ ], "-" ] },
    { "selectionstart" <> uuid, "selectionend" <> uuid }
];

selectionMarkers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*markSelection*)

(* The user's selection in a cell, marked like the Notebook Assistant marks it, but with the given markers: text or the
   cursor inside the cell ({start, end}), or the whole cell ("CellBracket"). The Notebook Assistant's
   insertSelectionMarkers (ChatModes/Context.wl, not shared) handles the cell contents that are checked here. It
   leaves out the marker of a position right before an inline cell that starts the cell's text, so a cell is only
   marked if it got both markers (else it is not marked at all, rather than with half a selection). *)
markSelection // beginDefinition;

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
markSelection[
    cell: Cell[ _String | _BoxData | _TextData | _RawData, ___ ],
    cursor: { _Integer, _Integer } | "CellBracket",
    { left_String, right_String }
] :=
    Block[ { $leftSelectionIndicator = left, $rightSelectionIndicator = right },
        Replace[
            acpCatchAll @ Wolfram`Chatbook`ChatModes`Context`Private`insertSelectionMarkers[ cell, cursor ],
            {
                marked_Cell /; ! FreeQ[ marked, _String? (StringContainsQ @ left) ] &&
                    ! FreeQ[ marked, _String? (StringContainsQ @ right) ] :> marked,
                _ -> cell
            }
        ]
    ];
(* :!CodeAnalysis::EndBlock:: *)

markSelection[ cell_Cell, _, { _String, _String } ] := cell;

markSelection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellMarkdown*)

(* A cell's content as markdown (CellToString), with placeholders for graphics and expression URIs. CellToString takes
   time in proportion to the size of the boxes, also of the parts it leaves out, so a cell with more than "MaxCellBytes"
   of boxes (once its graphics are replaced) is read as a note, like a cell that can't be converted (which is also
   logged): neither delays or fails the whole read. The options are ReadNotebook's limits ($readCellOptions) or those of
   a prompt's attachments (acpNotebookMarkdown): "MaxCellLength" and "MaxOutputLength" (CellToString's
   "MaxCellStringLength" and "MaxOutputCellStringLength"), "MaxCellBytes", "Graphics" (Automatic: "[graphics]", or a
   function that gives the text for a GraphicsBox or Graphics3DBox) and "Tool" (for the log). *)
cellMarkdown // beginDefinition;

cellMarkdown[ cell_Cell, id_String ] := cellMarkdown[ cell, id, $readCellOptions ];

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

(* ReadNotebook's limits *)
$readCellOptions := <|
    "MaxCellLength"   -> $maxCellLength,
    "MaxOutputLength" -> $maxOutputLength,
    "MaxCellBytes"    -> $maxCellBytes,
    "Graphics"        -> Automatic,
    "Tool"            -> "ReadNotebook"
|>;


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
   characters, and so on. An open or attached notebook may come from anywhere, so both the ReadNotebook tool
   (NotebookTools.wl, open notebooks) and the message attachments (Attachments.wl, open notebooks and files) run the
   cells through this before CellToString. An inline WL template becomes its input boxes (shown as code, not run), a
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

(* The markdown of a notebook's cells for a prompt (Attachments.wl): the content of each cell as ReadNotebook gives it
   (cellMarkdown), without <cell> blocks, ids, labels or selection markers, and with other limits: no cut per cell, output
   cells cut at $promptOutputLength characters, cells with more than $promptCellBytes of boxes left out with a note. opts:
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

(* CellToString and the markdown formatter run without touching the state of chats: they would add components to the
   base prompt that a chat they interrupted is collecting (needsBasePrompt), and expression URIs to the kernel's
   $attachments, where markdown from the agent could also show attachments of the user's chats. *)
withoutChatState // beginDefinition;
withoutChatState // Attributes = { HoldFirst };
withoutChatState[ eval_ ] := Block[ { needsBasePrompt = Null &, $attachments = <| |> }, eval ];
withoutChatState // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Writing Cells*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*markdownCells*)

(* Cells from the agent's markdown, made like the cells of Chatbook's own CreateNotebook tool (FormatChatOutput,
   ExplodeCell), with Chatbook's templates inlined (InlineTemplateBoxes) so that they look the same in any notebook.
   The formatter is made for chat answers: it takes a few milliseconds for each piece of inline markup (about 7 ms for
   an emphasized word, 14 ms for a link), and ExplodeCell fails beyond about 4000 pieces. So the markdown of a call is
   at most $maxMarkdownLength characters, and its conversion, which blocks the user's evaluations, is stopped after
   $markdownTimeLimit seconds. *)
markdownCells // beginDefinition;

markdownCells[ markdown0_ ] := Module[ { markdown, cells },
    markdown = markdownArgument @ markdown0;
    cells = TimeConstrained[
        withoutChatState @ withUntrustedContent @ InlineTemplateBoxes @ ExplodeCell @ FormatChatOutput[
            markdown,
            <| "Status" -> "Finished" |>
        ],
        $markdownTimeLimit,
        $TimedOut
    ];
    If[ cells === $TimedOut,
        toolError[
            "Converting the markdown took longer than `1` seconds, so nothing was written. Write the content in \
smaller parts, for example a few sections per call.",
            $markdownTimeLimit
        ]
    ];
    If[ ! MatchQ[ cells, { __Cell } ], toolError[ "The markdown could not be converted to cells." ] ];
    inertCells @ cells
];

markdownCells // endDefinition;

(* Markdown from the agent, prepared for the formatter. The private-use characters of the front end's linear syntax are
   removed (acpNeutralizeLinearSyntax): in a string of a cell they would make the front end show boxes that the agent
   chose, such as dynamic content that evaluates code. The escaping that ReadNotebook applies to a cell's text
   (inertTags) is reversed exactly (uninertTags), so that a read-then-write round trip leaves the text unchanged. The
   cells are built with the untrusted-content formatter (withUntrustedContent, in markdownCells), which decodes no HTML
   entities, so every other "&...;" is kept verbatim as well. *)
markdownArgument // beginDefinition;

markdownArgument[ markdown_String ] := Which[
    StringTrim @ markdown === "",
        missingArgument[ "markdown" ],
    StringLength @ markdown > $maxMarkdownLength,
        toolError[
            "The markdown is too long: `1` characters (at most `2`). Write the content in several parts.",
            StringLength @ markdown,
            $maxMarkdownLength
        ],
    True,
        acpNeutralizeLinearSyntax @ uninertTags @ markdown
];

markdownArgument[ _ ] := missingArgument[ "markdown" ];

markdownArgument // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*uninertTags*)

(* The exact, case-preserving inverse of inertTags (see inertTags and $readLegend): a "&lt;" that precedes a tag name
   is the escaped "<" of a read's tag and becomes "<" again, and an escape with one or more "amp;" ("&amp;lt;cell",
   "&amp;amp;lt;cell", ...) is the user's own text (escaped by the read so it stays distinct) and loses one "amp;". Both
   are undone in one pass, so the "&lt;" that the first rule restores is not turned into "<". Any other "&...;" is left
   as it is. *)
uninertTags // beginDefinition;

uninertTags[ text_String ] := StringReplace[
    text,
    {
        "&amp;" ~~ escape: ("amp;"... ~~ "lt;" ~~ $$readTag) :> "&" <> escape,
        "&lt;" ~~ tag: $$readTag :> "<" <> tag
    },
    IgnoreCase -> True
];

uninertTags // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inertCells*)

(* Cells made from markdown never run code when they are shown or clicked: they are refused if they have any *)
inertCells // beginDefinition;

inertCells[ cells: { __Cell } ] := Module[ { found },
    found = FirstCase[ cells /. $$frontEndResource -> Null, $$codeBox | $$codeOption, None, Infinity, Heads -> True ];
    If[ found === None,
        cells,
        toolError[
            "\
The markdown gave content that can run code (`1`), which the notebook tools never write. Use plain markdown.",
            Replace[ found, { (Rule|RuleDelayed)[ name_, _ ] :> ToString @ name, other_ :> ToString @ Head @ other } ]
        ]
    ]
];

inertCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*writeCells*)

(* Writes new cells after or before a cell of a notebook, or at its end ("After") or beginning ("Before") if there is no
   such cell, without moving the user's selection. Gives the ids of the new cells: the cells that are not in current,
   the notebook's cells as the caller found them. Converting the markdown can take seconds (markdownCells), during which
   the user can change the notebook, so the callers convert it first and then look at the notebook's cells, check them
   and write back to back: a cell that the user adds during the conversion is not taken for a new one, and a cell that
   the user starts to evaluate meanwhile is not replaced. *)
writeCells // beginDefinition;

writeCells[ entry_Association, current_List, cells: { __Cell }, anchor_, position: "After"|"Before" ] := Module[
    { nbo, known, new },
    nbo = entry[ "NotebookObject" ];
    Which[
        AssociationQ @ anchor,
            NotebookWrite[ NotebookLocationSpecifier[ anchor[ "CellObject" ], position ], cells, None ],
        current === { },
            (* The selection of an empty notebook has nowhere else to be *)
            SelectionMove[ nbo, Before, Notebook ];
            NotebookWrite[ nbo, cells, None ],
        position === "Before",
            NotebookWrite[ NotebookLocationSpecifier[ First[ current ][ "CellObject" ], "Before" ], cells, None ],
        True,
            NotebookWrite[ NotebookLocationSpecifier[ Last[ current ][ "CellObject" ], "After" ], cells, None ]
    ];
    known = AssociationMap[ True &, Lookup[ current, "CellObject", { } ] ];
    new = Select[ notebookCells @ entry, ! KeyExistsQ[ known, #[ "CellObject" ] ] & ];
    If[ new === { }, toolError[ "The cells could not be written to the notebook `1`.", notebookLabel @ entry ] ];
    Lookup[ new, "ID" ]
];

writeCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeCells*)

(* Deletes cells of a notebook and gives their number *)
removeCells // beginDefinition;

removeCells[ entry_Association, cells: { __Association } ] := Module[ { objects, left },
    objects = Lookup[ cells, "CellObject" ];
    NotebookDelete @ objects;
    left = Intersection[ objects, Lookup[ notebookCells @ entry, "CellObject", { } ] ];
    If[ left =!= { },
        toolError[
            "`1` of the cells could not be deleted from the notebook `2`.",
            Length @ left,
            notebookLabel @ entry
        ]
    ];
    Length @ objects
];

removeCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateNotebook*)
createNotebook // beginDefinition;

createNotebook[ args_Association ] := Module[ { cells, nbo, entry },
    requireFrontEnd[ ];
    cells = markdownCells @ args[ "markdown" ];
    nbo = NotebookPut @ Notebook @ cells;
    If[ ! MatchQ[ nbo, _NotebookObject ], toolError[ "The notebook could not be created." ] ];
    entry = SelectFirst[ listedNotebooks[ ], #[ "NotebookObject" ] === nbo &, unlistedEntry @ nbo ];
    toJSON @ <|
        "id"    -> entry[ "ID" ],
        "title" -> Replace[ entry[ "Title" ], None -> Null ],
        "cells" -> Lookup[ notebookCells @ entry, "ID", { } ]
    |>
];

createNotebook // endDefinition;


(* A new notebook that is not listed (e.g. hidden by the front end's settings): its id is not shortened *)
unlistedEntry // beginDefinition;

unlistedEntry[ nbo_NotebookObject ] := With[ { key = First @ objectKeys @ { nbo } },
    <| "NotebookObject" -> nbo, "Key" -> key, "ID" -> key, "Title" -> None, "File" -> None, "Modified" -> False |>
];

unlistedEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*InsertCells*)
insertCells // beginDefinition;

insertCells[ args_Association ] := Module[ { entry, position, id, cells, current, anchor },
    entry = resolveNotebook @ args[ "notebook" ];
    requireEditable @ entry;
    position = positionArgument @ args[ "position" ];
    id = anchorArgument @ args[ "cell" ];
    (* The markdown is converted before the notebook's cells are looked at: see writeCells *)
    cells = markdownCells @ args[ "markdown" ];
    current = notebookCells @ entry;
    anchor = If[ id === None, None, First @ resolveCells[ current, { id }, entry ] ];
    toJSON @ <| "notebook" -> entry[ "ID" ], "cells" -> writeCells[ entry, current, cells, anchor, position ] |>
];

insertCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ReplaceCells*)
replaceCells // beginDefinition;

replaceCells[ args_Association ] := Module[ { entry, ids, cells, current, targets, new },
    entry = resolveNotebook @ args[ "notebook" ];
    requireEditable @ entry;
    ids = cellIDArguments[ args[ "cells" ], "cells" ];
    (* The markdown is converted before the notebook's cells are looked at and checked: see writeCells *)
    cells = markdownCells @ args[ "markdown" ];
    current = notebookCells @ entry;
    targets = resolveCells[ current, ids, entry ];
    requireDeletable[ entry, targets ];
    new = writeCells[ entry, current, cells, First @ targets, "Before" ];
    toJSON @ <| "notebook" -> entry[ "ID" ], "cells" -> new, "replaced" -> removeCells[ entry, targets ] |>
];

replaceCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DeleteCells*)
deleteCells // beginDefinition;

deleteCells[ args_Association ] := Module[ { entry, targets },
    entry = resolveNotebook @ args[ "notebook" ];
    requireEditable @ entry;
    targets = resolveCells[ notebookCells @ entry, cellIDArguments[ args[ "cells" ], "cells" ], entry ];
    requireDeletable[ entry, targets ];
    toJSON @ <| "notebook" -> entry[ "ID" ], "deleted" -> removeCells[ entry, targets ] |>
];

deleteCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*acpNotebookTitles*)

(* The notebooks that the tools would act on for notebook arguments of the agent (ids, titles or files, as a call gives
   them), for the permission panel: <| spec -> <| "ID" -> id, "Title" -> window title |> |> for each argument that
   names exactly one of the listed notebooks, resolved as the tools resolve it (resolveNotebook); others are left out.
   It makes front end calls, so it is never called in a handler: the pump calls it when a permission request arrives
   (see Connection.wl, resolvePermissionNotebooks). Never throws; <| |> without a front end. *)
acpNotebookTitles // beginDefinition;

acpNotebookTitles[ { } ] := <| |>;

acpNotebookTitles[ specs: { __String } ] := Replace[
    acpCatchAll[ catchAlways @ notebookTitles @ specs, <| |> & ],
    Except[ _Association ] -> <| |>
];

acpNotebookTitles // endDefinition;


notebookTitles // beginDefinition;

notebookTitles[ specs_List ] := If[ $FrontEnd === Null,
    <| |>,
    With[ { entries = listedNotebooks[ ] }, DeleteMissing @ AssociationMap[ notebookTitle[ entries, # ] &, specs ] ]
];

notebookTitles // endDefinition;


notebookTitle // beginDefinition;

notebookTitle[ entries_List, spec_String ] := Replace[
    Catch[ resolveNotebook[ entries, spec ], $toolErrorTag ],
    {
        KeyValuePattern @ { "ID" -> id_String, "Title" -> title_String } :> <| "ID" -> id, "Title" -> title |>,
        _ -> Missing[ "NotFound" ]
    }
];

notebookTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
