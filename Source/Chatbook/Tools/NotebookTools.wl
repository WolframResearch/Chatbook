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
$maxSnapshots     = 10;    (* snapshots open at a time (they are hidden notebooks in the front end) *)
$maxCellTables    = 20;    (* tables of cell ids that are kept: one for each chat and notebook *)

(* Whether the names of files are compared without regard to letter case, as the file systems of Windows and macOS
   compare them. Not a value of its own: the MX is built on another system. *)
$ignoreFileCase := $OperatingSystem =!= "Unix";

$toolErrorTag = "Wolfram`Chatbook`Tools`NotebookTools`ToolError";

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
     notebookFrontEnd[ "Read", nb, { cell, ... } ]            their Cell expressions
     notebookFrontEnd[ "Close", nb ]                          closes the snapshot; the front end deletes its file *)
notebookFrontEnd // beginDefinition;

notebookFrontEnd[ "Snapshot", source_ ] :=
    Quiet @ MathLink`CallFrontEnd @ FrontEnd`NotebookSnapshot @ source;

notebookFrontEnd[ "Excluded", nb_NotebookObject ] :=
    chatExcludedQ @ Quiet @ AbsoluteCurrentValue[ nb, { TaggingRules, "ChatNotebookSettings" } ];

notebookFrontEnd[ "Cells", nb_NotebookObject ] := Quiet @ Cells @ nb;
notebookFrontEnd[ "Read", _NotebookObject, cells: { __CellObject } ] := Quiet @ NotebookRead @ cells;
notebookFrontEnd[ "Close", nb_NotebookObject ] := Quiet @ NotebookClose @ nb;

notebookFrontEnd // endDefinition;

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


(* The positions at which the lines of a text start *)
lineStarts // beginDefinition;
lineStarts[ text_String ] := Prepend[ StringPosition[ text, "\n" ][[ All, 1 ]] + 1, 1 ];
lineStarts // endDefinition;

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
