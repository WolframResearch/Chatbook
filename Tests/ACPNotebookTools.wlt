(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`ACP`Common`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-LoadACPContext"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
(* :!CodeAnalysis::Disable::NoSurroundingCatch:: *)
(* :!CodeAnalysis::Disable::UnrecognizedLongName:: *)

(* Tests for the notebook tools of the agent (ACP/NotebookTools.wl; see docs/acp-window.md, "Notebook tools"): the
   LLMTools and their schemas, the pure parts (ids, resolution, arguments, the check of agent text), every tool on a
   made-up front end (the tools make every front end call through notebookFrontEnd, which the tests replace: the
   front end's snapshot and cell text packets don't exist yet), the loader of CellDiff's ShowNotebookDiff, and the
   markdown of attached notebooks (Attachments.wl). The tools are called through their LLMTools, as AgentTools'
   tools/call does. The tests of ListNotebooks, of the notebooks that can be opened and of attachments need a front
   end: they run under UsingFrontEnd (which starts one if the test kernel has none; CI runs the tests under
   UsingFrontEnd anyway) and give Missing["TestSkipped"] if no front end can be started. Every notebook they create is
   closed at the end. The notebooks of a kernel that runs in a desktop front end are listed as well, so the tests only
   look at their own notebooks. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    (* CI runs every test file in one kernel and one context: these helpers are only defined here *)
    ClearAll[
        fakeCell, fakeFE, fakeFE0, fakePosition, nbtCall, nbtCellIDs, nbtCells, nbtID, nbtJSON, nbtListed, nbtMarkdown,
        nbtNotebook, nbtOpen, nbtResult, nbtText, nbtWithFE, withFakeFE
    ];

    $acpLogStart  = AbsoluteTime[ ]; (* see ACPNotebookTools-DebugLog *)
    $nbtTag       = IntegerString[ RandomInteger[ { 10^5, 10^6 - 1 } ] ];
    $nbtNotebooks = { };
    $nbtFiles     = { };
    $nbtTools     = Association[ #[ "Name" ] -> # & /@ acpNotebookTools[ ] ];
    $nbtFrontEndQ = TrueQ @ Quiet @ MatchQ[ UsingFrontEnd @ $FrontEnd, _FrontEndObject ];

    (* A tool called like AgentTools' tools/call does: the LLMTool applied to the arguments *)
    nbtCall[ name_String, args_Association ] := $nbtTools[ name ][ args ];

    (* The text an agent gets: a result, or the error text of a Failure *)
    nbtText[ failure_Failure ] := failure[ "String" ];
    nbtText[ other_ ] := other;

    nbtJSON[ json_String ] := Developer`ReadRawJSONString @ json;
    nbtJSON[ other_ ] := other;

    (* The value of a pure part, or the text of the tool error it ends with *)
    nbtResult // Attributes = { HoldFirst };
    nbtResult[ eval_ ] := Catch[ eval, Wolfram`Chatbook`ACP`NotebookTools`Private`$toolErrorTag, #1 & ];

    nbtWithFE // Attributes = { HoldFirst };
    nbtWithFE[ eval_ ] := If[ TrueQ @ $nbtFrontEndQ, UsingFrontEnd @ eval, Missing[ "TestSkipped" ] ];

    nbtNotebook[ cells_List, opts___ ] := With[ { nbo = NotebookPut @ Notebook[ cells, opts ] },
        AppendTo[ $nbtNotebooks, nbo ];
        nbo
    ];

    (* A notebook's entry in ListNotebooks and its id *)
    nbtListed[ nbo_NotebookObject ] := SelectFirst[
        nbtJSON[ nbtCall[ "ListNotebooks", <| |> ] ][ "notebooks" ],
        StringStartsQ[ First @ nbo, #[ "id" ] ] &,
        Missing[ "NotListed" ]
    ];

    nbtID[ nbo_NotebookObject ] := Lookup[ nbtListed @ nbo, "id" ];

    (* The markdown of a cell for a prompt's attachment *)
    nbtMarkdown[ cell_ ] := Wolfram`Chatbook`ACP`NotebookTools`Private`cellMarkdown[
        cell,
        "id",
        Wolfram`Chatbook`ACP`NotebookTools`Private`$promptCellOptions
    ];

    (* Made-up notebook entries for the pure tests *)
    $nbtEntries = {
        <| "Key" -> "abcdef11-0000-4000-8000-000000000001", "ID" -> "abcdef11", "Title" -> "One", "File" -> "/tmp/one.nb" |>,
        <| "Key" -> "abcdef22-0000-4000-8000-000000000002", "ID" -> "abcdef22", "Title" -> "Two", "File" -> None |>,
        <| "Key" -> "12345678-0000-4000-8000-000000000003", "ID" -> "12345678", "Title" -> "Two", "File" -> None |>
    };

    (* A made-up front end. Its notebooks are lists of cell records as the cell text packet gives them; a snapshot copies
       the cells of its source ($fakeSources, none for others) with new CellObjects; the edit packet's operations are
       applied in order, all or nothing, with the front end's failures (a cell whose content holds "PARSEERROR" does
       not parse). Every call is recorded in $fakeCalls. *)
    fakeCell[ id_String, style_String, text_String, depth_Integer, open_: True ] :=
        <| "Cell" -> CellObject[ id ], "Style" -> style, "Text" -> text, "GroupDepth" -> depth, "Open" -> open |>;

    $fakeSourceCells = {
        fakeCell[ "src-1", "Title", "(*Hamiltonian Mechanics*)", 0 ],
        fakeCell[ "src-2", "Section", "(*The simple pendulum*)", 1 ],
        fakeCell[ "src-3", "Text", "(*The Hamiltonian of a pendulum of length l and mass m:*)", 2 ],
        fakeCell[ "src-4", "Input", "H = p\:02c42/(2 m l\:02c42) - m g l Cos[\[Theta]]", 2 ],
        fakeCell[ "src-5", "Output", "\:2e22FE`ElidedBox[1, \"GraphicsBox\", 48213]\:2e23", 2 ],
        fakeCell[ "src-6", "Section", "(*Equations of motion*)", 1, False ],
        fakeCell[ "src-7", "Input", "eqs = {q'[t] == D[H, p], p'[t] == -D[H, q]};\nsol = NDSolve[eqs, {q, p}, {t, 0, 10}]", 2 ]
    };

    $fakeListed = {
        <|
            "NotebookObject" -> NotebookObject[ "fake-source-1" ],
            "Key"            -> "abcdef11-0000-4000-8000-000000000001",
            "ID"             -> "abcdef11",
            "Title"          -> "Hamiltonian Mechanics",
            "File"           -> "/tmp/HamiltonianMechanics.nb",
            "Modified"       -> True
        |>,
        <|
            "NotebookObject" -> NotebookObject[ "fake-source-2" ],
            "Key"            -> "12345678-0000-4000-8000-000000000002",
            "ID"             -> "12345678",
            "Title"          -> "Other",
            "File"           -> None,
            "Modified"       -> False
        |>
    };

    $fakeSources = <| NotebookObject[ "fake-source-1" ] -> $fakeSourceCells |>;

    fakeFE[ op_String, args___ ] := (AppendTo[ $fakeCalls, { op, args } ]; fakeFE0[ op, args ]);

    fakeFE0[ "Snapshot", "fail" ] := $Failed;

    fakeFE0[ "Snapshot", source_ ] := With[ { n = ++$fakeCount }, With[ { nbo = NotebookObject[ "fake-snapshot-" <> ToString @ n ] },
        $fakeNotebooks[ nbo ] = <|
            "Cells" -> MapIndexed[
                <| #1, "Cell" -> CellObject[ "fake-" <> ToString @ n <> "-" <> ToString @ First @ #2 ] |> &,
                Lookup[ $fakeSources, Key @ source, { } ]
            ],
            "File" -> "/tmp/fake-snapshot-" <> ToString @ n <> ".nb"
        |>;
        nbo
    ] ];

    fakeFE0[ "FileName", nbo_ ] := Lookup[ Lookup[ $fakeNotebooks, nbo, <| |> ], "File", $Failed ];

    fakeFE0[ "CellText", nbo_, cells_, preview_, _ ] := Module[ { all, picked },
        all    = $fakeNotebooks[ nbo, "Cells" ];
        picked = If[ cells === All, all, DeleteMissing[ SelectFirst[ all, Function[ c, c[ "Cell" ] === # ], Missing[ ] ] & /@ cells ] ];
        If[ IntegerQ @ preview, <| #, "Text" -> StringTake[ #[ "Text" ], UpTo @ preview ] |> & /@ picked, picked ]
    ];

    fakeFE0[ "Edit", nbo_, ops_List ] := Catch[
        Module[ { cells, changed = { }, inserted = { }, deleted = 0 },
            If[ ! KeyExistsQ[ $fakeNotebooks, nbo ],
                Throw[ Failure[ "NotASnapshot", <| "MessageTemplate" -> "The notebook is not a snapshot.", "Operation" -> 1 |> ], $fakeTag ]
            ];
            cells = $fakeNotebooks[ nbo, "Cells" ];
            Do[
                With[ { op = ops[[ i ]] },
                    Switch[ First @ op,
                        "Edit",
                            Module[ { pos = fakePosition[ cells, op[[ 2 ]], i ], text },
                                text = cells[[ pos, "Text" ]];
                                Do[
                                    Switch[ StringCount[ text, e[[ 1 ]] ],
                                        0,
                                            Throw[ Failure[ "NoMatch", <| "MessageTemplate" -> "\"`1`\" does not occur in the cell.", "MessageParameters" -> { e[[ 1 ]] }, "Operation" -> i |> ], $fakeTag ],
                                        e[[ 3 ]],
                                            text = StringReplace[ text, e[[ 1 ]] -> e[[ 2 ]] ],
                                        _,
                                            Throw[ Failure[ "AmbiguousMatch", <| "MessageTemplate" -> "\"`1`\" occurs `2` times in the cell.", "MessageParameters" -> { e[[ 1 ]], StringCount[ text, e[[ 1 ]] ] }, "Operation" -> i |> ], $fakeTag ]
                                    ],
                                    { e, op[[ 3 ]] }
                                ];
                                If[ StringContainsQ[ text, "PARSEERROR" ],
                                    Throw[ Failure[ "ParseError", <| "MessageTemplate" -> "The new content of the cell does not parse.", "Operation" -> i |> ], $fakeTag ]
                                ];
                                cells[[ pos, "Text" ]] = text;
                                AppendTo[ changed, op[[ 2 ]] ]
                            ],
                        "Set",
                            With[ { pos = fakePosition[ cells, op[[ 2 ]], i ] },
                                cells[[ pos, "Text" ]] = op[[ 4 ]];
                                If[ op[[ 3 ]] =!= Automatic, cells[[ pos, "Style" ]] = op[[ 3 ]] ];
                                AppendTo[ changed, op[[ 2 ]] ]
                            ],
                        "Insert",
                            Module[ { at, new },
                                at = Which[
                                    op[[ 2 ]] === None && op[[ 3 ]] === "Before", 1,
                                    op[[ 2 ]] === None                           , Length @ cells + 1,
                                    op[[ 3 ]] === "Before"                       , fakePosition[ cells, op[[ 2 ]], i ],
                                    True                                         , fakePosition[ cells, op[[ 2 ]], i ] + 1
                                ];
                                new = fakeCell[ "fake-new-" <> ToString[ ++$fakeCount ], #[[ 1 ]], #[[ 2 ]], 2 ] & /@ op[[ 4 ]];
                                cells = Join[ Take[ cells, at - 1 ], new, Drop[ cells, at - 1 ] ];
                                inserted = Join[ inserted, Lookup[ new, "Cell" ] ]
                            ],
                        "Delete",
                            With[ { positions = fakePosition[ cells, #, i ] & /@ op[[ 2 ]] },
                                cells = Delete[ cells, List /@ positions ];
                                deleted += Length @ positions
                            ]
                    ]
                ],
                { i, Length @ ops }
            ];
            $fakeNotebooks[ nbo, "Cells" ] = cells;
            <| "Changed" -> DeleteDuplicates @ changed, "Inserted" -> inserted, "Deleted" -> deleted |>
        ],
        $fakeTag
    ];

    fakeFE0[ "Save", _ ] := If[ TrueQ @ $fakeSaveFails, $Failed, Null ];
    fakeFE0[ "Close", nbo_ ] := (KeyDropFrom[ $fakeNotebooks, nbo ]; Null);
    fakeFE0[ "ShowDiff", _, _ ] := $fakeDiffResult;

    fakePosition[ cells_List, cell_, i_Integer ] := Replace[
        FirstPosition[ Lookup[ cells, "Cell" ], cell, None, { 1 } ],
        {
            { p_Integer } :> p,
            _ :> Throw[ Failure[ "CellNotFound", <| "MessageTemplate" -> "The cell does not exist.", "Operation" -> i |> ], $fakeTag ]
        }
    ];

    $fakeTag = "acp-notebook-tools-fake-front-end";

    (* The tools on the made-up front end, with their own snapshots and made-up listed notebooks *)
    withFakeFE // Attributes = { HoldFirst };
    withFakeFE[ eval_ ] := Block[
        {
            Wolfram`Chatbook`ACP`NotebookTools`Private`notebookFrontEnd = fakeFE,
            Wolfram`Chatbook`ACP`NotebookTools`Private`listedNotebooks  = $fakeListed &,
            Wolfram`Chatbook`ACP`NotebookTools`Private`cellCount        = 7 &,
            Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshots       = <| |>,
            Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshotCount   = 0,
            $fakeNotebooks  = <| |>,
            $fakeCalls      = { },
            $fakeCount      = 0,
            $fakeSaveFails  = False,
            $fakeDiffResult = Null
        },
        eval
    ];

    (* OpenNotebook on the real listed notebooks, with a made-up snapshot (no front end has the snapshot packet yet):
       the agent's text *)
    nbtOpen[ spec_ ] := Block[
        {
            Wolfram`Chatbook`ACP`NotebookTools`Private`notebookFrontEnd = fakeFE,
            Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshots       = <| |>,
            Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshotCount   = 0,
            $fakeNotebooks = <| |>,
            $fakeCalls     = { },
            $fakeCount     = 0
        },
        nbtText @ nbtCall[ "OpenNotebook", <| "notebook" -> spec |> ]
    ];
    Null,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tools*)
VerificationTest[
    { Keys @ $nbtTools, AllTrue[ $nbtTools, MatchQ[ _LLMTool ] ] },
    {
        {
            "ListNotebooks", "OpenNotebook", "GetOutline", "ReadCells", "SearchNotebook", "EditInCell", "SetCell",
            "InsertCells", "DeleteCells", "SaveNotebook", "ShowChanges", "CloseNotebook"
        },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-Names"
]

VerificationTest[
    Map[ #[ "Data" ][ "DisplayName" ] &, Values @ $nbtTools ],
    {
        "List Notebooks", "Open Notebook", "Get Outline", "Read Cells", "Search Notebook", "Edit In Cell", "Set Cell",
        "Insert Cells", "Delete Cells", "Save Notebook", "Show Changes", "Close Notebook"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-DisplayNames"
]

(* AgentTools makes the MCP input schemas from the tools' JSON schemas; edits and new cells are arrays of objects *)
VerificationTest[
    {
        Map[ { #[ "type" ], Keys @ #[ "properties" ], #[ "required" ] } &, #[ "JSONSchema" ] & /@ $nbtTools ],
        $nbtTools[ "EditInCell" ][ "JSONSchema" ][ "properties", "edits" ][ "items" ],
        $nbtTools[ "InsertCells" ][ "JSONSchema" ][ "properties", "newCells" ][ "items", "properties" ] // Keys,
        $nbtTools[ "SearchNotebook" ][ "JSONSchema" ][ "properties", "regex", "type" ]
    },
    {
        <|
            "ListNotebooks"  -> { "object", { }, { } },
            "OpenNotebook"   -> { "object", { "notebook" }, { } },
            "GetOutline"     -> { "object", { "notebook", "preview", "offset", "limit" }, { "notebook" } },
            "ReadCells"      -> { "object", { "notebook", "cells", "full" }, { "notebook" } },
            "SearchNotebook" -> { "object", { "notebook", "query", "regex", "cells", "styles", "limit" }, { "notebook", "query" } },
            "EditInCell"     -> { "object", { "notebook", "cell", "edits" }, { "notebook", "cell", "edits" } },
            "SetCell"        -> { "object", { "notebook", "cell", "text", "style" }, { "notebook", "cell", "text" } },
            "InsertCells"    -> { "object", { "notebook", "newCells", "cell", "position" }, { "notebook", "newCells" } },
            "DeleteCells"    -> { "object", { "notebook", "cells" }, { "notebook", "cells" } },
            "SaveNotebook"   -> { "object", { "notebook" }, { "notebook" } },
            "ShowChanges"    -> { "object", { "notebook" }, { "notebook" } },
            "CloseNotebook"  -> { "object", { "notebook" }, { "notebook" } }
        |>,
        KeyValuePattern @ {
            "type"       -> "object",
            "properties" -> KeyValuePattern @ {
                "oldText" -> KeyValuePattern[ "type" -> "string" ],
                "newText" -> KeyValuePattern[ "type" -> "string" ],
                "count"   -> KeyValuePattern[ "type" -> "integer" ]
            }
        },
        { "style", "text" },
        "boolean"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-Schemas"
]

(* The workflow is in OpenNotebook's description and the notation in ReadCells' (the server's instructions have both);
   no description has private-use characters (AgentTools would rewrite them) *)
VerificationTest[
    {
        StringContainsQ[ $nbtTools[ "OpenNotebook" ][ "Description" ], $acpNotebookWorkflow ],
        StringContainsQ[ $nbtTools[ "ReadCells" ][ "Description" ], $acpNotebookNotation ],
        StringContainsQ[ $acpNotebookWorkflow, "OpenNotebook" ~~ __ ~~ "ReadCells" ~~ __ ~~ "ShowChanges" ],
        StringContainsQ[ $acpNotebookNotation, "(* ::Style:: #id *)" ] && StringContainsQ[ $acpNotebookNotation, "\\[Name]" ],
        AllTrue[ $nbtTools, StringFreeQ[ #[ "Description" ], RegularExpression[ "[\\x{E000}-\\x{F8FF}]" ] ] & ]
    },
    { True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-Descriptions"
]

(* Only ShowChanges changes a notebook the user has open (edits go to snapshots) *)
VerificationTest[
    { $acpNotebookEditTools, SubsetQ[ Keys @ $nbtTools, $acpNotebookEditTools ] },
    { { "ShowChanges" }, True },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-EditTools"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Identifiers*)
(*Identifiers*)
VerificationTest[
    Wolfram`Chatbook`ACP`NotebookTools`Private`uniqueIDs[
        { "abcdef0123456789", "abcdef0199999999", "12345678zzzz", "abc", "same-key-1", "same-key-1" }
    ],
    { "abcdef012", "abcdef019", "12345678", "abc", "same-key-1", "same-key-1" },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-UniqueIDs"
]

VerificationTest[
    Wolfram`Chatbook`ACP`NotebookTools`Private`uniqueIDs[ { } ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-UniqueIDs-Empty"
]

(* Objects that share a UUID get their instance UUID too *)
VerificationTest[
    Wolfram`Chatbook`ACP`NotebookTools`Private`objectKeys @ {
        CellObject[ "ABCDEF01-1", "Inst-1" ],
        CellObject[ "abcdef01-1", "inst-2" ],
        CellObject[ "abcdef01-2", "inst-3" ],
        NotebookObject[ "FEDCBA98-0", "inst-4" ]
    },
    { "abcdef01-1.inst-1", "abcdef01-1.inst-2", "abcdef01-2", "fedcba98-0" },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ObjectKeys"
]

(* Help pages and the Messages window are not listed (deployed notebooks are left out separately, see
   ACPNotebookTools-ListNotebooks-Excluded) *)
VerificationTest[
    Wolfram`Chatbook`ACP`NotebookTools`Private`listedNotebookQ[ #, NotebookObject[ "messages", "1" ] ] & /@ {
        <| "Included" -> True , "DocumentType" -> "Notebook", "NotebookObject" -> NotebookObject[ "a", "1" ] |>,
        <| "Included" -> False, "DocumentType" -> "Notebook", "NotebookObject" -> NotebookObject[ "b", "1" ] |>,
        <| "Included" -> True , "DocumentType" -> "Help"    , "NotebookObject" -> NotebookObject[ "c", "1" ] |>,
        <| "Included" -> True , "DocumentType" -> "Notebook", "NotebookObject" -> NotebookObject[ "messages", "1" ] |>
    },
    { True, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ListedNotebookQ"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Resolution*)

(* By id, a start of at least 6 characters, the whole UUID (any case, with quotes), the exact window title or the file *)
VerificationTest[
    nbtResult[ Wolfram`Chatbook`ACP`NotebookTools`Private`resolveNotebook[ $nbtEntries, # ][ "ID" ] ] & /@ {
        "abcdef11",
        "abcdef1",
        "  'ABCDEF11-0000-4000-8000-000000000001' ",
        "123456",
        "One",
        "/tmp/one.nb"
    },
    { "abcdef11", "abcdef11", "abcdef11", "12345678", "abcdef11", "abcdef11" },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ResolveNotebook"
]

VerificationTest[
    nbtResult[ Wolfram`Chatbook`ACP`NotebookTools`Private`resolveNotebook[ $nbtEntries, # ][ "ID" ] ] & /@ {
        "abcdef",
        "Two",
        "12345",
        "one",
        "",
        Missing[ "NoInput" ]
    },
    {
        "\"abcdef\" matches more than one notebook: abcdef11 (\"One\"), abcdef22 (\"Two\"). Use the notebook's id.",
        "\"Two\" matches more than one notebook: abcdef22 (\"Two\"), 12345678 (\"Two\"). Use the notebook's id.",
        "No open notebook or .nb file matches \"12345\". Call ListNotebooks for the notebooks that are open.",
        "No open notebook or .nb file matches \"one\". Call ListNotebooks for the notebooks that are open.",
        "The parameter notebook is missing or empty.",
        "The parameter notebook is missing or empty."
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ResolveNotebook-Errors"
]

(* Snapshot handles in any case, with quotes; an unknown handle names the open snapshots *)
VerificationTest[
    withFakeFE @ Module[ { none, open },
        none = nbtResult @ Wolfram`Chatbook`ACP`NotebookTools`Private`resolveSnapshot[ "s1" ];
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        open = nbtResult @ Wolfram`Chatbook`ACP`NotebookTools`Private`resolveSnapshot @ # & /@ { "s1", " 'S1' ", "s2", "abcdef11", "" };
        { none, open }
    ],
    {
        "\"s1\" is not an open snapshot. Open the notebook with OpenNotebook first; the other tools take the handle it gives.",
        {
            "s1",
            "s1",
            "\"s2\" is not an open snapshot. The open snapshots are s1 (\"Hamiltonian Mechanics\"); OpenNotebook opens another one.",
            "\"abcdef11\" is not an open snapshot. The open snapshots are s1 (\"Hamiltonian Mechanics\"); OpenNotebook opens another one.",
            "The parameter notebook is missing or empty."
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ResolveSnapshot"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Arguments*)
VerificationTest[
    nbtResult @ Wolfram`Chatbook`ACP`NotebookTools`Private`cellIDsArgument[ #, "cells" ] & /@ {
        "c1, c2;c3  c4",
        "[\"c1\", 'c2']",
        "c1,c1",
        { "c1, c2", "c3" },
        Missing[ "NoInput" ],
        " , ",
        Failure[ "InterpretationFailure", <| |> ]
    },
    {
        { "c1", "c2", "c3", "c4" },
        { "c1", "c2" },
        { "c1" },
        { "c1", "c2", "c3" },
        None,
        "The parameter cells is missing or empty.",
        "The parameter cells must be a string of cell ids separated by commas, e.g. \"c3, c4\"."
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-CellIDsArgument"
]

VerificationTest[
    nbtResult @ Wolfram`Chatbook`ACP`NotebookTools`Private`countArgument[ #, "offset", 1 ] & /@ {
        Missing[ "NoInput" ], 3, " 4 ", 2.0, 0, -1, 1.5, "x"
    },
    {
        1, 3, 4, 2,
        "The parameter offset must be a positive whole number, not \"0\".",
        "The parameter offset must be a positive whole number, not \"-1\".",
        "The parameter offset must be a positive whole number, not \"1.5\".",
        "The parameter offset must be a positive whole number, not \"x\"."
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-CountArgument"
]

VerificationTest[
    nbtResult @ Wolfram`Chatbook`ACP`NotebookTools`Private`positionArgument @ # & /@ {
        Missing[ "NoInput" ], "", " BEFORE ", "after", "middle"
    },
    { "After", "After", "Before", "After", "The parameter position must be \"after\" or \"before\", not \"middle\"." },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-PositionArgument"
]

VerificationTest[
    {
        nbtResult @ Wolfram`Chatbook`ACP`NotebookTools`Private`booleanArgument[ #, "regex", False ] & /@ {
            Missing[ "NoInput" ], True, False, "true", " FALSE ", "yes", 1
        },
        Wolfram`Chatbook`ACP`NotebookTools`Private`stylesArgument /@ { Missing[ "NoInput" ], "", "Input, Text", "[\"Input\"]" },
        Wolfram`Chatbook`ACP`NotebookTools`Private`styleArgument[ #, "style" ] & /@ { Missing[ "NoInput" ], " ", " Text " },
        Wolfram`Chatbook`ACP`NotebookTools`Private`cellID /@ { "c3", "#c3", " C3 ", "3", "'#c12'" }
    },
    {
        {
            False, True, False, True, False,
            "The parameter regex must be true or false, not \"yes\".",
            "The parameter regex must be true or false, not \"1\"."
        },
        { None, None, { "Input", "Text" }, { "Input" } },
        { Automatic, Automatic, "Text" },
        { "c3", "c3", "c3", "c3", "c12" }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-OtherArguments"
]

(* Every edit needs oldText (not empty) and newText; count is 1 if it is not given; no marker lines; nothing that runs
   code in newText *)
VerificationTest[
    nbtResult @ Wolfram`Chatbook`ACP`NotebookTools`Private`editsArgument @ # & /@ {
        { <| "oldText" -> "a", "newText" -> "b", "count" -> Missing[ "NoInput" ] |>, <| "oldText" -> "c", "newText" -> "", "count" -> 2 |> },
        { <| "oldText" -> "a", "newText" -> Missing[ "NoInput" ] |> },
        { <| "oldText" -> "a", "newText" -> "b" |>, <| "newText" -> "b" |> },
        { <| "oldText" -> "", "newText" -> "b" |> },
        { <| "oldText" -> "a", "newText" -> "b", "count" -> 0 |> },
        { <| "oldText" -> "x\n(* ::Input:: #c4 *)\ny", "newText" -> "z" |> },
        { <| "oldText" -> "a", "newText" -> "\:2e22DynamicBox[ToBoxes[CreateFile[\"x\"]]]\:2e23" |> },
        { },
        Missing[ "NoInput" ],
        Failure[ "InterpretationFailure", <| |> ]
    },
    {
        { { "a", "b", 1 }, { "c", "", 2 } },
        "Edit 1 has no newText (use \"\" to delete oldText).",
        "Edit 2 has no oldText.",
        "Edit 1 has an empty oldText. To insert text, put the text next to the insertion point in oldText and that text with the addition in newText.",
        "The count of edit 1 must be a positive whole number, not \"0\".",
        "Edit 1 includes a marker line (* ::Style:: #id *): an edit works on the content of one cell.",
        "The newText of edit 1 has content that would run code when it is shown (DynamicBox), which the notebook tools never write.",
        "The parameter edits is missing or empty.",
        "The parameter edits is missing or empty.",
        "The parameter edits must be a list of edits {oldText, newText, count}, e.g. [{\"oldText\": \"a\", \"newText\": \"b\"}]."
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-EditsArgument"
]

VerificationTest[
    nbtResult @ Wolfram`Chatbook`ACP`NotebookTools`Private`newCellsArgument @ # & /@ {
        { <| "style" -> " Input ", "text" -> "x = 1" |>, <| "style" -> "Text", "text" -> "(*Some text*)" |> },
        { <| "style" -> "Input" |> },
        { <| "text" -> "x" |> },
        { <| "style" -> "Input", "text" -> "(* ::Input:: *)\nx = 1" |> },
        { }
    },
    {
        { { "Input", "x = 1" }, { "Text", "(*Some text*)" } },
        "New cell 1 has no text.",
        "New cell 1 has no style.",
        "The text of new cell 1 includes a marker line (* ::Style:: #id *): give the content of one cell, without its marker line.",
        "The parameter newCells is missing or empty."
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-NewCellsArgument"
]

(* Agent text that would run code when it is shown is refused: linear syntax (its characters, their escapes, \! and \*
   that are not themselves escaped) anywhere, dynamic boxes and code options inside a box wrapper. Code typed in a code
   cell, names in strings, placeholders and escaped backslashes are fine. *)
VerificationTest[
    {
        nbtResult[ Wolfram`Chatbook`ACP`NotebookTools`Private`requireInertText[ #, "The text" ]; "OK" ] & /@ {
            "Dynamic[x] + DynamicModule[{a}, a]",
            "\:2e22FE`ElidedBox[1, \"DynamicBox\", 120]\:2e23",
            "\:2e22StyleBox[\"Dynamic[x] and Initialization :> f\", FontSlant -> \"Italic\"]\:2e23",
            "StringReplace[s, \"\\\\!\" -> \"\"]",
            "x\:02c42 + \:2e22SqrtBox[\"a\"]\:2e23 \\[Rule] b",
            "(*see \\\\! here*)"
        },
        nbtResult[ Wolfram`Chatbook`ACP`NotebookTools`Private`requireInertText[ #, "The text" ]; "OK" ] & /@ {
            "a" <> FromCharacterCode[ 63425 ] <> "b",
            "\"\\!\\(\\*RowBox[{CreateFile[\\\"x\\\"]}]\\)\"",
            "a \\:f7c1 b",
            "\:2e22DynamicModuleBox[{}, \"x\"]\:2e23",
            "\:2e22ButtonBox[\"x\", ButtonFunction :> CreateFile[\"x\"]]\:2e23",
            "\:2e22Cell[\"x\", \"Text\", CellDynamicExpression \\[RuleDelayed] f]\:2e23",
            "\:2e22TemplateBox[{\"x\"}, \"T\", InterpretationFunction -> (f &)]\:2e23"
        }
    },
    {
        { "OK", "OK", "OK", "OK", "OK", "OK" },
        {
            "The text has linear syntax (\"\\:f7c1\"), which would run code when it is shown; the notebook tools never write it.",
            "The text has linear syntax (\"\\!\"), which would run code when it is shown; the notebook tools never write it.",
            "The text has linear syntax (\"\\:f7c1\"), which would run code when it is shown; the notebook tools never write it.",
            "The text has content that would run code when it is shown (DynamicModuleBox), which the notebook tools never write.",
            "The text has content that would run code when it is shown (ButtonFunction), which the notebook tools never write.",
            "The text has content that would run code when it is shown (CellDynamicExpression), which the notebook tools never write.",
            "The text has content that would run code when it is shown (InterpretationFunction), which the notebook tools never write."
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-InertText"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Snapshots*)

(* OpenNotebook snapshots a listed notebook (by id, title or file), numbers its cells (a cheap read) and records it;
   a notebook that has an open snapshot gives that one again *)
VerificationTest[
    withFakeFE @ Module[ { first, again, record },
        first  = nbtJSON @ nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        again  = nbtJSON @ nbtCall[ "OpenNotebook", <| "notebook" -> "Hamiltonian Mechanics" |> ];
        record = Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshots[ "s1" ];
        {
            first,
            again,
            Keys @ Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshots,
            KeyDrop[ record, "IDs" ],
            Values @ record[ "IDs" ],
            $fakeCalls[[ 1 ;; 3 ]]
        }
    ],
    {
        <| "notebook" -> "s1", "title" -> "Hamiltonian Mechanics", "source" -> "abcdef11", "cells" -> 7 |>,
        <|
            "notebook" -> "s1", "title" -> "Hamiltonian Mechanics", "source" -> "abcdef11", "cells" -> 7,
            "note" -> "This notebook already had an open snapshot; its edits so far are kept."
        |>,
        { "s1" },
        <|
            "Handle"   -> "s1",
            "Notebook" -> NotebookObject[ "fake-snapshot-1" ],
            "File"     -> "/tmp/fake-snapshot-1.nb",
            "Source"   -> NotebookObject[ "fake-source-1" ],
            "SourceID" -> "abcdef11",
            "Title"    -> "Hamiltonian Mechanics",
            "NextID"   -> 8,
            "Edited"   -> False,
            "Unsaved"  -> False
        |>,
        { "c1", "c2", "c3", "c4", "c5", "c6", "c7" },
        {
            { "Snapshot", NotebookObject[ "fake-source-1" ] },
            { "FileName", NotebookObject[ "fake-snapshot-1" ] },
            { "CellText", NotebookObject[ "fake-snapshot-1" ], All, 1, True }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-OpenNotebook"
]

(* A .nb file that is not open, a new empty notebook (no notebook, or an empty one), and what can't be opened *)
VerificationTest[
    withFakeFE @ Module[ { file, other, results },
        file  = FileNameJoin @ { $TemporaryDirectory, "nbt-" <> $nbtTag <> " File.nb" };
        other = FileNameJoin @ { $TemporaryDirectory, "nbt-" <> $nbtTag <> ".txt" };
        Put[ Notebook @ { }, file ];
        Put[ "x", other ];
        AppendTo[ $nbtFiles, file ];
        AppendTo[ $nbtFiles, other ];
        results = {
            nbtJSON @ nbtCall[ "OpenNotebook", <| "notebook" -> " \"" <> file <> "\" " |> ],
            nbtJSON @ nbtCall[ "OpenNotebook", <| |> ],
            nbtJSON @ nbtCall[ "OpenNotebook", <| "notebook" -> "" |> ],
            nbtText @ nbtCall[ "OpenNotebook", <| "notebook" -> other |> ],
            nbtText @ nbtCall[ "OpenNotebook", <| "notebook" -> "fail" |> ],
            Cases[ $fakeCalls, { "Snapshot", s_ } :> s ]
        };
        results
    ],
    {
        <| "notebook" -> "s1", "title" -> "nbt-" <> $nbtTag <> " File.nb", "source" -> _String? (StringEndsQ[ " File.nb" ]), "cells" -> 0 |>,
        <| "notebook" -> "s2", "title" -> "Untitled", "source" -> Null, "cells" -> 0 |>,
        <| "notebook" -> "s3", "title" -> "Untitled", "source" -> Null, "cells" -> 0 |>,
        _String? (StringStartsQ[ "No open notebook or .nb file matches \"" ]),
        "No open notebook or .nb file matches \"fail\". Call ListNotebooks for the notebooks that are open.",
        { _String? (StringEndsQ[ " File.nb" ]), None, None }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-OpenNotebook-FileAndNew"
]

(* A snapshot that the front end can't make is not recorded *)
VerificationTest[
    withFakeFE @ Block[ { $fakeListed = { <| First @ $fakeListed, "NotebookObject" -> "fail" |> } },
        {
            nbtText @ nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ],
            Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshots
        }
    ],
    { "The front end could not make a snapshot of \"Hamiltonian Mechanics\".", <| |> },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-OpenNotebook-Failed"
]

(* The user's notebooks, front to back, with the handle of an open snapshot, and the snapshots *)
VerificationTest[
    withFakeFE @ Module[ { before },
        before = nbtJSON @ nbtCall[ "ListNotebooks", <| |> ];
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        nbtCall[ "OpenNotebook", <| |> ];
        nbtCall[ "EditInCell", <| "notebook" -> "s1", "cell" -> "c4", "edits" -> { <| "oldText" -> "Cos", "newText" -> "Sin" |> } |> ];
        { before[ "snapshots" ], nbtJSON @ nbtCall[ "ListNotebooks", <| |> ] }
    ],
    {
        { },
        <|
            "notebooks" -> {
                <| "id" -> "abcdef11", "title" -> "Hamiltonian Mechanics", "file" -> "/tmp/HamiltonianMechanics.nb", "modified" -> True, "cells" -> 7, "selected" -> True, "snapshot" -> "s1" |>,
                <| "id" -> "12345678", "title" -> "Other", "file" -> Null, "modified" -> False, "cells" -> 7, "selected" -> False, "snapshot" -> Null |>
            },
            "snapshots" -> {
                <| "notebook" -> "s1", "title" -> "Hamiltonian Mechanics", "source" -> "abcdef11", "edited" -> True, "unsaved" -> True |>,
                <| "notebook" -> "s2", "title" -> "Untitled", "source" -> Null, "edited" -> False, "unsaved" -> False |>
            }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ListNotebooks-Snapshots"
]

(* The outline: each cell's marker (::Closed for a closed group) and the start of its content on one line, indented by
   group depth; in parts with offset and limit *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            nbtCall[ "GetOutline", <| "notebook" -> "s1", "preview" -> 24 |> ],
            nbtCall[ "GetOutline", <| "notebook" -> "s1", "offset" -> 6, "limit" -> 1 |> ],
            nbtText @ nbtCall[ "GetOutline", <| "notebook" -> "s1", "offset" -> 9 |> ],
            Cases[ $fakeCalls, { "CellText", _, All, preview_, elide_ } :> { preview, elide } ]
        }
    ),
    {
        StringRiffle[
            {
                "Outline of s1 (\"Hamiltonian Mechanics\"): 7 cells, each as its marker line and the start of its content, indented by cell group depth.",
                "(* ::Title:: #c1 *)",
                "(*Hamiltonian Mechanics*\[Ellipsis]",
                "  (* ::Section:: #c2 *)",
                "  (*The simple pendulum*)",
                "    (* ::Text:: #c3 *)",
                "    (*The Hamiltonian of a p\[Ellipsis]",
                "    (* ::Input:: #c4 *)",
                "    H = p\:02c42/(2 m l\:02c42) - m g \[Ellipsis]",
                "    (* ::Output:: #c5 *)",
                "    \:2e22FE`ElidedBox[1, \"Graphi\[Ellipsis]",
                "  (* ::Section::Closed:: #c6 *)",
                "  (*Equations of motion*)",
                "    (* ::Input:: #c7 *)",
                "    eqs = {q'[t] == D[H, p],\[Ellipsis]"
            },
            "\n"
        ],
        StringRiffle[
            {
                "Outline of s1 (\"Hamiltonian Mechanics\"): 7 cells, each as its marker line and the start of its content, indented by cell group depth.",
                "  (* ::Section::Closed:: #c6 *)",
                "  (*Equations of motion*)",
                "[Cells 6-6 of 7; call again with offset 7 for more.]"
            },
            "\n"
        ],
        "The offset 9 is past the last cell: s1 has 7 cells.",
        { { 1, True }, { 24, True }, { 80, True }, { 80, True } }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-GetOutline"
]

(* Cells as marker lines and their exact content: the whole notebook, or the cells with the given ids in their order
   (any id form); full shows elided boxes; a long result is cut after a cell, with a note *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            nbtCall[ "ReadCells", <| "notebook" -> "s1", "cells" -> "#c4, C3" |> ],
            StringCount[ nbtCall[ "ReadCells", <| "notebook" -> "s1" |> ], "(* ::" ],
            nbtCall[ "ReadCells", <| "notebook" -> "s1", "cells" -> "7", "full" -> True |> ],
            Block[ { Wolfram`Chatbook`ACP`NotebookTools`Private`$readBudget = 100 },
                nbtCall[ "ReadCells", <| "notebook" -> "s1" |> ]
            ],
            nbtText @ nbtCall[ "ReadCells", <| "notebook" -> "s1", "cells" -> "c3, c99" |> ],
            Cases[ $fakeCalls, { "CellText", _, cells_, All, elide_ } :> { Length @ Replace[ cells, All -> { } ], elide } ]
        }
    ),
    {
        "(* ::Input:: #c4 *)\nH = p\:02c42/(2 m l\:02c42) - m g l Cos[\[Theta]]\n(* ::Text:: #c3 *)\n(*The Hamiltonian of a pendulum of length l and mass m:*)",
        7,
        "(* ::Input:: #c7 *)\neqs = {q'[t] == D[H, p], p'[t] == -D[H, q]};\nsol = NDSolve[eqs, {q, p}, {t, 0, 10}]",
        "(* ::Title:: #c1 *)\n(*Hamiltonian Mechanics*)\n(* ::Section:: #c2 *)\n(*The simple pendulum*)\n[Not shown: #c3 and the 4 cells after it (a result has at most 100 characters). Read them with cells.]",
        "s1 has no cell \"c99\". Cell ids come from GetOutline, ReadCells and SearchNotebook.",
        { { 2, True }, { 0, True }, { 1, False }, { 0, True } }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ReadCells"
]

(* A literal or a regular expression in the cells' content (as ReadCells shows it), with line:column and the line;
   cells and styles narrow the search; a limit; no matches; a bad regular expression or no query *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            nbtCall[ "SearchNotebook", <| "notebook" -> "s1", "query" -> "H" |> ],
            nbtCall[ "SearchNotebook", <| "notebook" -> "s1", "query" -> "D\\[H, (\\w)\\]", "regex" -> True |> ],
            nbtCall[ "SearchNotebook", <| "notebook" -> "s1", "query" -> "H", "styles" -> "Input", "cells" -> "c3, c4", "limit" -> 1 |> ],
            nbtCall[ "SearchNotebook", <| "notebook" -> "s1", "query" -> "Lagrangian" |> ],
            nbtText @ nbtCall[ "SearchNotebook", <| "notebook" -> "s1", "query" -> "(", "regex" -> "true" |> ],
            nbtText @ nbtCall[ "SearchNotebook", <| "notebook" -> "s1", "query" -> "" |> ]
        }
    ),
    {
        StringRiffle[
            {
                "5 matches for \"H\" in s1 (\"Hamiltonian Mechanics\") (line:column in the cell's content):",
                "#c1 (Title) 1:3: (*Hamiltonian Mechanics*)",
                "#c3 (Text) 1:7: (*The Hamiltonian of a pendulum of length l and mass m:*)",
                "#c4 (Input) 1:1: H = p\:02c42/(2 m l\:02c42) - m g l Cos[\[Theta]]",
                "#c7 (Input) 1:19: eqs = {q'[t] == D[H, p], p'[t] == -D[H, q]};",
                "#c7 (Input) 1:38: eqs = {q'[t] == D[H, p], p'[t] == -D[H, q]};"
            },
            "\n"
        ],
        "2 matches for \"D\\[H, (\\w)\\]\" in s1 (\"Hamiltonian Mechanics\") (line:column in the cell's content):\n#c7 (Input) 1:17: eqs = {q'[t] == D[H, p], p'[t] == -D[H, q]};\n#c7 (Input) 1:36: eqs = {q'[t] == D[H, p], p'[t] == -D[H, q]};",
        "1 match for \"H\" in s1 (\"Hamiltonian Mechanics\") (line:column in the cell's content):\n#c4 (Input) 1:1: H = p\:02c42/(2 m l\:02c42) - m g l Cos[\[Theta]]",
        "No matches for \"Lagrangian\" in s1 (\"Hamiltonian Mechanics\").",
        "\"(\" is not a valid regular expression.",
        "The parameter query is missing or empty."
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-SearchNotebook"
]

(* Search details: matches on later lines of a cell, long lines shortened around the match, more matches than the
   limit *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            nbtCall[ "SearchNotebook", <| "notebook" -> "s1", "query" -> "NDSolve" |> ],
            nbtCall[ "SearchNotebook", <| "notebook" -> "s1", "query" -> "e", "limit" -> 2 |> ],
            Block[ { Wolfram`Chatbook`ACP`NotebookTools`Private`$snippetLength = 12 },
                nbtCall[ "SearchNotebook", <| "notebook" -> "s1", "query" -> "pendulum", "cells" -> "c3" |> ]
            ]
        }
    ),
    {
        "1 match for \"NDSolve\" in s1 (\"Hamiltonian Mechanics\") (line:column in the cell's content):\n#c7 (Input) 2:7: sol = NDSolve[eqs, {q, p}, {t, 0, 10}]",
        _String? (StringMatchQ[ StringExpression[
            DigitCharacter.., " matches for \"e\" in s1", __, "\n#c1 (Title) 1:", __, "\n#c2 (Section) 1:", __,
            "\n[Showing the first 2; narrow the search with cells or styles, or raise limit.]"
        ] ]),
        "1 match for \"pendulum\" in s1 (\"Hamiltonian Mechanics\") (line:column in the cell's content):\n#c3 (Text) 1:24: \[Ellipsis]f a pendulum of leng\[Ellipsis]"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-SearchNotebook-Lines"
]

(* EditInCell: the edits go to the front end as one "Edit" operation, in order, and the result shows the cell's new
   content; the snapshot is then edited and unsaved *)
VerificationTest[
    withFakeFE @ Module[ { result },
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        result = nbtCall[
            "EditInCell",
            <|
                "notebook" -> "s1",
                "cell"     -> "#c4",
                "edits"    -> {
                    <| "oldText" -> "H = p\:02c42/(2 m l\:02c42)", "newText" -> "L = m l\:02c42 \:2e22SuperscriptBox[OverscriptBox[\"\[Theta]\", \".\"], \"2\"]\:2e23/2" |>,
                    <| "oldText" -> "- m g l Cos", "newText" -> "+ m g l Cos" |>
                }
            |>
        ];
        {
            result,
            SelectFirst[ $fakeCalls, First @ # === "Edit" & ],
            KeyTake[ Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshots[ "s1" ], { "Edited", "Unsaved" } ]
        }
    ],
    {
        "Edited #c4 of s1 (2 edits). It now reads:\n(* ::Input:: #c4 *)\nL = m l\:02c42 \:2e22SuperscriptBox[OverscriptBox[\"\[Theta]\", \".\"], \"2\"]\:2e23/2 + m g l Cos[\[Theta]]",
        {
            "Edit",
            NotebookObject[ "fake-snapshot-1" ],
            {
                {
                    "Edit",
                    CellObject[ "fake-1-4" ],
                    {
                        { "H = p\:02c42/(2 m l\:02c42)", "L = m l\:02c42 \:2e22SuperscriptBox[OverscriptBox[\"\[Theta]\", \".\"], \"2\"]\:2e23/2", 1 },
                        { "- m g l Cos", "+ m g l Cos", 1 }
                    }
                }
            }
        },
        <| "Edited" -> True, "Unsaved" -> True |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-EditInCell"
]

(* The front end's failures reach the agent with their tag, message and a hint; nothing was changed, and the snapshot
   is not marked as edited. Arguments are checked before the front end is called. *)
VerificationTest[
    withFakeFE @ Module[ { edit, results },
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        edit[ cell_, edits__ ] := nbtText @ nbtCall[ "EditInCell", <| "notebook" -> "s1", "cell" -> cell, "edits" -> { edits } |> ];
        results = {
            edit[ "c4", <| "oldText" -> "Cos", "newText" -> "Sin" |>, <| "oldText" -> "+ V[q]", "newText" -> "- V[q]" |> ],
            edit[ "c4", <| "oldText" -> "l", "newText" -> "L" |> ],
            edit[ "c4", <| "oldText" -> "Cos", "newText" -> "PARSEERROR" |> ],
            edit[ "c4", <| "oldText" -> "Cos" |> ],
            edit[ "c99", <| "oldText" -> "Cos", "newText" -> "Sin" |> ],
            $fakeNotebooks[ NotebookObject[ "fake-snapshot-1" ], "Cells" ] = Delete[ $fakeNotebooks[ NotebookObject[ "fake-snapshot-1" ], "Cells" ], 3 ];
            edit[ "c3", <| "oldText" -> "The", "newText" -> "A" |> ]
        };
        {
            results,
            Count[ $fakeCalls, { "Edit", ___ } ],
            $fakeNotebooks[ NotebookObject[ "fake-snapshot-1" ], "Cells" ][[ 3, "Text" ]],
            Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshots[ "s1", "Edited" ]
        }
    ],
    {
        {
            "NoMatch: \"+ V[q]\" does not occur in the cell. Nothing was changed. Copy oldText exactly from the cell's current content (ReadCells), with its spaces, \:2e22 \:2e23 wrappers and \\[Name] characters.",
            "AmbiguousMatch: \"l\" occurs 2 times in the cell. Nothing was changed. Make oldText longer, so that it occurs as often as count says, or give count.",
            "ParseError: The new content of the cell does not parse. Nothing was changed. The cell's new content must parse: check brackets, quotes and \:2e22 \:2e23 wrappers.",
            "Edit 1 has no newText (use \"\" to delete oldText).",
            "s1 has no cell \"c99\". Cell ids come from GetOutline, ReadCells and SearchNotebook.",
            "CellNotFound: The cell does not exist. Nothing was changed. Call GetOutline for the current cell ids."
        },
        4,
        "H = p\:02c42/(2 m l\:02c42) - m g l Cos[\[Theta]]",
        False
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-EditInCell-Failures"
]

(* A changed cell that the front end gives as another CellObject keeps its id *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            Wolfram`Chatbook`ACP`NotebookTools`Private`changedCell[ "s1", CellObject[ "fake-1-4" ], <| "Changed" -> { CellObject[ "fake-1-4" ] } |> ],
            Wolfram`Chatbook`ACP`NotebookTools`Private`changedCell[ "s1", CellObject[ "fake-1-4" ], <| "Changed" -> { CellObject[ "other" ] } |> ],
            Lookup[ Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshots[ "s1", "IDs" ], { CellObject[ "other" ], CellObject[ "fake-1-4" ] } ]
        }
    ),
    { CellObject[ "fake-1-4" ], CellObject[ "other" ], { "c4", Missing[ "KeyAbsent", CellObject[ "fake-1-4" ] ] } },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ChangedCell"
]

(* SetCell replaces a cell's content, and its style if one is given *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            nbtCall[ "SetCell", <| "notebook" -> "s1", "cell" -> "c3", "text" -> "(*The Lagrangian:*)" |> ],
            nbtCall[ "SetCell", <| "notebook" -> "s1", "cell" -> "c3", "text" -> "(*Lagrangian*)", "style" -> "Subsection" |> ],
            nbtText @ nbtCall[ "SetCell", <| "notebook" -> "s1", "cell" -> "c3", "text" -> "(* ::Text:: #c3 *)\n(*x*)" |> ],
            nbtCall[ "SetCell", <| "notebook" -> "s1", "cell" -> "c3" |> ],
            Cases[ $fakeCalls, { "Edit", _, { op_ } } :> op ]
        }
    ),
    {
        "Set #c3 of s1. It now reads:\n(* ::Text:: #c3 *)\n(*The Lagrangian:*)",
        "Set #c3 of s1. It now reads:\n(* ::Subsection:: #c3 *)\n(*Lagrangian*)",
        "The text includes a marker line (* ::Style:: #id *): give the content of one cell, without its marker line.",
        _Failure, (* LLMTool refuses a call without a required parameter *)
        {
            { "Set", CellObject[ "fake-1-3" ], Automatic, "(*The Lagrangian:*)" },
            { "Set", CellObject[ "fake-1-3" ], "Subsection", "(*Lagrangian*)" }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-SetCell"
]

(* InsertCells after or before a cell, or at the end; the new cells get the next ids and are shown *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            nbtCall[ "InsertCells", <| "notebook" -> "s1", "cell" -> "c4", "newCells" -> { <| "style" -> "Text", "text" -> "(*The Lagrangian:*)" |>, <| "style" -> "Input", "text" -> "L = T - V" |> } |> ],
            nbtCall[ "InsertCells", <| "notebook" -> "s1", "cell" -> "c1", "position" -> "before", "newCells" -> { <| "style" -> "Text", "text" -> "(*First*)" |> } |> ],
            nbtCall[ "InsertCells", <| "notebook" -> "s1", "cell" -> " ", "newCells" -> { <| "style" -> "Text", "text" -> "(*Last*)" |> } |> ],
            nbtText @ nbtCall[ "InsertCells", <| "notebook" -> "s1", "newCells" -> "x" |> ],
            StringCount[ nbtCall[ "ReadCells", <| "notebook" -> "s1" |> ], "(* ::" ],
            StringCases[ nbtCall[ "GetOutline", <| "notebook" -> "s1" |> ], "#c" ~~ DigitCharacter.. ],
            Cases[ $fakeCalls, { "Edit", _, { { "Insert", anchor_, position_, cells_ } } } :> { anchor, position, Length @ cells } ]
        }
    ),
    {
        "Inserted 2 cells after #c4 of s1:\n(* ::Text:: #c8 *)\n(*The Lagrangian:*)\n(* ::Input:: #c9 *)\nL = T - V",
        "Inserted 1 cell before #c1 of s1:\n(* ::Text:: #c10 *)\n(*First*)",
        "Inserted 1 cell at the end of s1:\n(* ::Text:: #c11 *)\n(*Last*)",
        "The parameter newCells must be a list of cells {style, text}, e.g. [{\"style\": \"Input\", \"text\": \"x = 1\"}].",
        11,
        { "#c10", "#c1", "#c2", "#c3", "#c4", "#c8", "#c9", "#c5", "#c6", "#c7", "#c11" },
        { { CellObject[ "fake-1-4" ], "After", 2 }, { CellObject[ "fake-1-1" ], "Before", 1 }, { None, "After", 1 } }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-InsertCells"
]

(* DeleteCells deletes cells and forgets their ids *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            nbtCall[ "DeleteCells", <| "notebook" -> "s1", "cells" -> "c5, c4" |> ],
            nbtText @ nbtCall[ "ReadCells", <| "notebook" -> "s1", "cells" -> "c4" |> ],
            nbtCall[ "DeleteCells", <| "notebook" -> "s1" |> ],
            Values @ Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshots[ "s1", "IDs" ],
            Length @ $fakeNotebooks[ NotebookObject[ "fake-snapshot-1" ], "Cells" ]
        }
    ),
    {
        "Deleted 2 cells (#c5, #c4) from s1.",
        "s1 has no cell \"c4\". Cell ids come from GetOutline, ReadCells and SearchNotebook.",
        _Failure, (* LLMTool refuses a call without a required parameter *)
        { "c1", "c2", "c3", "c6", "c7" },
        5
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-DeleteCells"
]

(* SaveNotebook saves the snapshot (never the source) *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        nbtCall[ "DeleteCells", <| "notebook" -> "s1", "cells" -> "c7" |> ];
        {
            nbtCall[ "SaveNotebook", <| "notebook" -> "s1" |> ],
            KeyTake[ Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshots[ "s1" ], { "Edited", "Unsaved" } ],
            Block[ { $fakeSaveFails = True }, nbtText @ nbtCall[ "SaveNotebook", <| "notebook" -> "s1" |> ] ],
            Cases[ $fakeCalls, { "Save", nbo_ } :> nbo ]
        }
    ),
    {
        "Saved s1. When the work on it is done, call ShowChanges to show the user the changes.",
        <| "Edited" -> True, "Unsaved" -> False |>,
        "The front end could not save s1 (\"Hamiltonian Mechanics\").",
        { NotebookObject[ "fake-snapshot-1" ], NotebookObject[ "fake-snapshot-1" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-SaveNotebook"
]

(* ShowChanges: nothing to show without edits; unsaved edits are saved first; CellDiff gets the source (the notebook,
   the file or None) and the snapshot's NotebookObject; the snapshot is closed. If the diff fails, the snapshot stays
   open. *)
VerificationTest[
    withFakeFE @ Module[ { unedited, failed, shown, newOne },
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        unedited = nbtCall[ "ShowChanges", <| "notebook" -> "s1" |> ];
        nbtCall[ "DeleteCells", <| "notebook" -> "s1", "cells" -> "c7" |> ];
        failed = Block[ { $fakeDiffResult = Failure[ "Test", <| "MessageTemplate" -> "The comparison could not be made." |> ] },
            nbtText @ nbtCall[ "ShowChanges", <| "notebook" -> "s1" |> ]
        ];
        shown = nbtCall[ "ShowChanges", <| "notebook" -> "s1" |> ];
        nbtCall[ "OpenNotebook", <| |> ];
        nbtCall[ "InsertCells", <| "notebook" -> "s2", "newCells" -> { <| "style" -> "Title", "text" -> "(*New*)" |> } |> ];
        newOne = nbtCall[ "ShowChanges", <| "notebook" -> "s2" |> ];
        {
            unedited,
            failed,
            shown,
            newOne,
            Cases[ $fakeCalls, { op: "Save" | "ShowDiff" | "Close", args___ } :> { op, args } ],
            Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshots,
            $fakeNotebooks
        }
    ],
    {
        "There are no changes to show: s1 was not edited. Close it with CloseNotebook.",
        "The changes of s1 (\"Hamiltonian Mechanics\") could not be shown: The comparison could not be made.",
        "The user now sees \"Hamiltonian Mechanics\" as a diff against your edits, and accepts or rejects each change there. s1 is closed.",
        "The user now sees \"Untitled\" as a diff against your edits, and accepts or rejects each change there. s2 is closed.",
        {
            { "Save", NotebookObject[ "fake-snapshot-1" ] },
            { "ShowDiff", NotebookObject[ "fake-source-1" ], NotebookObject[ "fake-snapshot-1" ] },
            { "ShowDiff", NotebookObject[ "fake-source-1" ], NotebookObject[ "fake-snapshot-1" ] },
            { "Close", NotebookObject[ "fake-snapshot-1" ] },
            { "Save", NotebookObject[ "fake-snapshot-2" ] },
            { "ShowDiff", None, NotebookObject[ "fake-snapshot-2" ] },
            { "Close", NotebookObject[ "fake-snapshot-2" ] }
        },
        <| |>,
        <| |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ShowChanges"
]

(* CloseNotebook discards a snapshot; its handle is then unknown *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        nbtCall[ "OpenNotebook", <| "notebook" -> "12345678" |> ];
        {
            nbtCall[ "CloseNotebook", <| "notebook" -> "s1" |> ],
            nbtText @ nbtCall[ "GetOutline", <| "notebook" -> "s1" |> ],
            Keys @ Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshots,
            Keys @ $fakeNotebooks
        }
    ),
    {
        "Closed s1; its edits were discarded.",
        "\"s1\" is not an open snapshot. The open snapshots are s2 (\"Other\"); OpenNotebook opens another one.",
        { "s2" },
        { NotebookObject[ "fake-snapshot-2" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-CloseNotebook"
]

(* A cell text packet that fails, and an edit packet that gives no result *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        Block[ { fakeFE0 = $Failed & },
            {
                nbtText @ nbtCall[ "ReadCells", <| "notebook" -> "s1" |> ],
                nbtText @ nbtCall[ "DeleteCells", <| "notebook" -> "s1", "cells" -> "c1" |> ]
            }
        ]
    ),
    {
        "The front end could not read the cells of s1 (\"Hamiltonian Mechanics\").",
        "The front end could not edit s1 (\"Hamiltonian Mechanics\"). Nothing was changed."
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-FrontEndFailures"
]

(* The permission panel's titles: snapshot handles, then listed notebooks *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            acpNotebookTitles @ { "s1", "abcdef11", "nope" },
            acpNotebookTitles @ { "S1" }
        }
    ),
    {
        <| "s1" -> <| "ID" -> "s1", "Title" -> "Hamiltonian Mechanics" |>, "abcdef11" -> <| "ID" -> "abcdef11", "Title" -> "Hamiltonian Mechanics" |> |>,
        <| "S1" -> <| "ID" -> "s1", "Title" -> "Hamiltonian Mechanics" |> |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-NotebookTitles"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ShowNotebookDiff*)

(* CellDiff's ShowNotebookDiff is loaded from CELLDIFF_NOTEBOOKDIFF_FILE (every time), off $ContextPath, and called with
   the source and the snapshot's NotebookObject; a missing file gives an error *)
VerificationTest[
    Module[ { dir, good, saved, results },
        dir   = CreateDirectory[ ];
        good  = FileNameJoin @ { dir, "Good.wl" };
        Export[ good, "BeginPackage[\"CellDiffNotebookDiff`\"];\nShowNotebookDiff::usage = \"test\";\nBegin[\"`Private`\"];\nShowNotebookDiff[source_, snapshot_NotebookObject] := {\"Shown\", source, snapshot};\nEnd[];\nEndPackage[];\n", "Text" ];
        saved = Environment[ "CELLDIFF_NOTEBOOKDIFF_FILE" ];
        results = Internal`InheritedBlock[ { $ContextPath },
            Table[
                SetEnvironment[ "CELLDIFF_NOTEBOOKDIFF_FILE" -> file ];
                nbtResult @ Wolfram`Chatbook`ACP`NotebookTools`Private`showNotebookDiff[ NotebookObject[ "src" ], NotebookObject[ "snap" ] ],
                { file, { good, FileNameJoin @ { dir, "Missing.wl" } } }
            ]
        ];
        SetEnvironment[ "CELLDIFF_NOTEBOOKDIFF_FILE" -> Replace[ saved, Except[ _String ] -> None ] ];
        DeleteDirectory[ dir, DeleteContents -> True ];
        {
            results,
            MemberQ[ $ContextPath, "CellDiffNotebookDiff`" ],
            Wolfram`Chatbook`ACP`NotebookTools`Private`notebookDiffFile[ ] === Replace[ saved, Except[ _String ] -> Wolfram`Chatbook`ACP`NotebookTools`Private`$defaultNotebookDiffFile ]
        }
    ],
    {
        {
            { "Shown", NotebookObject[ "src" ], NotebookObject[ "snap" ] },
            _String? (StringMatchQ[ "ShowChanges is not available: the notebook comparison " ~~ __ ~~ "Missing.wl was not found." ])
        },
        False,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ShowNotebookDiff"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Attached Notebooks*)
(* Cells with too many boxes are read as a note (once graphics are replaced, so a large plot is still [graphics]) *)
VerificationTest[
    Block[ { Wolfram`Chatbook`ACP`NotebookTools`Private`$promptCellBytes = 10000 },
        nbtMarkdown /@ {
            Cell[ BoxData @ ToBoxes @ Range[ 5000 ], "Output" ],
            Cell[ BoxData @ ToBoxes @ Plot[ Sin[ x ], { x, 0, 10 } ], "Output" ],
            Cell[ BoxData @ RowBox @ { "1", "+", "1" }, "Input" ]
        }
    ],
    { "[this cell is too large to read: 1 MB]", "```wl\n[graphics]\n```", "```wl\n1 + 1\n```" },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-LargeCells"
]

(* The attachments' conversion runs nothing in a crafted notebook: the cells go through acpDefusedCells before
   CellToString, so an inline WL code template, a video or audio box (also one with an
   inline InterpretationFunction), a crafted box with an inline InterpretationFunction, a string with linear syntax and
   a raw data cell no longer run code or import content. A normal box (no inline InterpretationFunction) is unchanged. *)
VerificationTest[
    Module[ { dir, path, q, cells, md, normal, files },
        dir  = CreateDirectory[ ];
        path = FileNameJoin @ { dir, "ran-" <> ToString @ # } &;
        q    = ToString[ path @ #, InputForm ] &;
        cells = {
            Cell[ BoxData @ TemplateBox[ <| "input" -> RowBox @ { "CreateFile", "[", q[ 1 ], "]" } |>, "ChatbookWLTemplate" ], "Text" ],
            Cell[ BoxData @ TemplateBox[ { "1" }, "VideoBox1", InterpretationFunction -> Function[ CreateFile[ path[ 2 ] ]; 1 ] ], "Output" ],
            Cell[ BoxData @ TemplateBox[ { "1" }, "AudioBox1", InterpretationFunction -> Function[ CreateFile[ path[ 3 ] ]; 1 ] ], "Output" ],
            Cell[ BoxData @ TemplateBox[ { "1", "\"m\"", "meters", "\"Meters\"" }, "Quantity", InterpretationFunction -> Function[ CreateFile[ path[ 4 ] ]; 1 ] ], "Output" ],
            Cell[ BoxData @ RowBox @ { ToString[ "\"a\\!\\(\\*RowBox[{CreateFile[" <> q[ 5 ] <> "]}]\\)\"", InputForm ] }, "Input" ],
            Cell[ RawData[ "Cell[BoxData[RowBox[{CreateFile[" <> q[ 6 ] <> "]}]], \"Input\"]" ], "Text" ]
        };
        md    = nbtMarkdown[ # ] & /@ Wolfram`Chatbook`ACP`Common`acpDefusedCells @ cells;
        (* a normal Quantity output (no inline InterpretationFunction) is converted the same with or without defusing *)
        normal = With[ { c = Cell[ BoxData @ ToBoxes @ Quantity[ 3, "Meters" ], "Output" ] },
            nbtMarkdown[ c ] ===
                nbtMarkdown[ First @ Wolfram`Chatbook`ACP`Common`acpDefusedCells @ { c } ]
        ];
        files = FileNames[ "*", dir ];
        DeleteDirectory[ dir, DeleteContents -> True ];
        {
            files,
            StringContainsQ[ md[[ 1 ]], "CreateFile" ], (* the template's input is shown as text, not run *)
            md[[ 2 ]],
            md[[ 3 ]],
            StringMatchQ[ md[[ 4 ]], "```wl\nQuantity[1, \"Meters\"]\n```" ], (* inline InterpretationFunction dropped *)
            normal
        }
    ],
    { { }, True, "```wl\n[video]\n```", "```wl\n[audio]\n```", True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ReadDefusesCode"
]

(* Nested constructs are defused too (the rules are applied until nothing changes): a template whose input is a template,
   a template in the arguments of a box with an inline InterpretationFunction, a box with an InterpretationFunction in
   the arguments of another, a video box in a template's input; both for cells from the front end and for a notebook's
   text (notebookTextCells) *)
VerificationTest[
    Module[ { dir, path, q, cf, wl, cells, md, attached, attachedMarkdown, files },
        dir  = CreateDirectory[ ];
        path = FileNameJoin @ { dir, "ran-" <> ToString @ # } &;
        q    = ToString[ path @ #, InputForm ] &;
        cf   = RowBox @ { "CreateFile", "[", q[ # ], "]" } &;
        wl   = TemplateBox[ <| "input" -> # |>, "ChatbookWLTemplate" ] &;
        cells = {
            Cell[ BoxData @ wl @ wl @ cf[ 1 ], "Text" ],
            Cell[ BoxData @ TemplateBox[ { wl @ cf[ 2 ] }, "Foo", InterpretationFunction -> (1 &) ], "Output" ],
            Cell[
                BoxData @ TemplateBox[
                    { TemplateBox[ { "1", "\"m\"", "meters", "\"Meters\"" }, "Quantity", InterpretationFunction -> Function[ CreateFile[ path[ 3 ] ]; 1 ] ] },
                    "Bar",
                    InterpretationFunction -> (2 &),
                    DisplayFunction -> (#1 &)
                ],
                "Output"
            ],
            Cell[ BoxData @ wl @ TemplateBox[ { "1" }, "VideoBox1", InterpretationFunction -> Function[ CreateFile[ path[ 4 ] ]; 1 ] ], "Text" ]
        };
        md = Quiet[ nbtMarkdown[ # ] & /@ Wolfram`Chatbook`ACP`Common`acpDefusedCells @ cells ];
        attached = Quiet @ Wolfram`Chatbook`ACP`Attachments`Private`notebookTextCells @ ToString[
            Notebook @ { Cell[ BoxData @ wl @ wl @ cf[ 5 ], "Text" ], Cell[ BoxData @ TemplateBox[ { wl @ cf[ 6 ] }, "Foo", InterpretationFunction -> (1 &) ], "Output" ] },
            InputForm
        ];
        attachedMarkdown = If[ ListQ @ attached, Quiet[ Wolfram`Chatbook`CellToString /@ attached ], attached ];
        files = FileNameTake /@ FileNames[ "*", dir ];
        DeleteDirectory[ dir, DeleteContents -> True ];
        { files, AllTrue[ md, StringQ ], ListQ @ attached, AllTrue[ Flatten @ { attachedMarkdown }, StringQ ] }
    ],
    { { }, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ReadDefusesNested"
]

(* The markdown of a notebook for a prompt's attachment (acpNotebookMarkdown): without labels, no cut per cell, output cells cut at 5000 characters, graphics as the caller says; a total cap
   leaves the last cells out (or cuts a first cell with text that is too long) with a note, both notes when both
   happen; a cancelled conversion stops *)
VerificationTest[
    Module[ { long, cells, md, output, capped, cut, cancelled },
        long  = StringRepeat[ "word ", 2400 ];
        cells = {
            Cell[ "Spec", "Title" ],
            Cell[ long, "Text" ],
            Cell[ BoxData @ RowBox @ { "1", "+", "1" }, "Input", CellLabel -> "In[1]:=" ],
            Cell[ BoxData @ ToBoxes @ Range[ 3000 ], "Output", CellLabel -> "Out[1]=" ],
            Cell[ BoxData @ ToBoxes @ Plot[ Sin[ x ], { x, 0, 1 } ], "Output" ]
        };
        md        = acpNotebookMarkdown[ cells, <| "Graphics" -> ("[image 7]" &) |> ];
        output    = acpNotebookMarkdown[ { cells[[ 4 ]] } ][ "Markdown" ];
        capped    = acpNotebookMarkdown[ cells, <| "MaxCharacters" -> 12100 |> ];
        cut       = acpNotebookMarkdown[ { Cell[ long, "Text" ], Cell[ "x", "Text" ] }, <| "MaxCharacters" -> 100 |> ];
        cancelled = acpNotebookMarkdown[ cells, <| "ActiveQ" -> (False &) |> ];
        {
            Lookup[ md, { "Cells", "Shown", "Truncated" } ],
            StringStartsQ[ md[ "Markdown" ], "# Spec\n\n" <> StringTrim @ long <> "\n\n```wl\n1 + 1\n```\n\n" ],
            StringFreeQ[ md[ "Markdown" ], "<cell" | "In[1]" | "Out[1]" | "[graphics]" ],
            StringEndsQ[ md[ "Markdown" ], "[image 7]\n```" ],
            4000 < StringLength @ output <= 5100,
            Lookup[ capped, { "Shown", "Truncated" } ],
            StringEndsQ[ capped[ "Markdown" ], "\n\n[The last 2 cells of this notebook are left out: the notebook is too large to attach whole.]" ],
            StringTake[ cut[ "Markdown" ], 100 ] === StringTake[ long, 100 ],
            StringEndsQ[ cut[ "Markdown" ], "[The last cell of this notebook is left out: the notebook is too large to attach whole.]" ],
            StringEndsQ[ acpNotebookMarkdown[ { Cell[ long, "Text" ] }, <| "MaxCharacters" -> 100 |> ][ "Markdown" ], "[The rest of this cell is left out: the notebook is too large to attach whole.]" ],
            StringEndsQ[
                acpNotebookMarkdown[ { Cell[ long, "Text" ], Cell[ "x", "Text" ], Cell[ "y", "Text" ] }, <| "MaxCharacters" -> 100 |> ][ "Markdown" ],
                "\n\n[The rest of this cell is left out: the notebook is too large to attach whole.]\n\n[The last 2 cells of this notebook are left out: the notebook is too large to attach whole.]"
            ],
            StringTake[ acpNotebookMarkdown[ { Cell[ "", "Text" ], Cell[ long, "Text" ] }, <| "MaxCharacters" -> 100 |> ][ "Markdown" ], 100 ] === StringTake[ long, 100 ],
            cancelled
        }
    ],
    { { 5, 5, False }, True, True, True, True, { 3, True }, True, True, True, True, True, True, Failure[ "Cancelled", <| |> ] },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-PromptMarkdown"
]

(* Notebooks that are attached are read without evaluating anything in them (Attachments.wl's notebookTextCells, which
   also reads open notebooks from the front end's text of them): code in boxes, interpretation functions, dynamic
   content, inline code templates (their code is text), videos, strings with linear syntax (also typed), raw data cells
   and arithmetic run nothing; what is not inert in the cells is inertSymbol[name]. Text with linear syntax outside its
   strings, or without one Notebook expression, is refused; a front end's file (comments, a cache, cell groups, many
   comments in strings) is read; the symbols of the parse are removed. *)
VerificationTest[
    Block[ { $acpDebugLog = Internal`Bag[ ] },
        Module[ { dir, path, q, texts, cells, md, result },
            dir   = CreateDirectory[ ];
            path  = FileNameJoin @ { dir, "ran-" <> ToString @ # } &;
            q     = ToString[ path @ #, InputForm ] &;
            texts = <|
                "Boxes"     -> "Notebook[{Cell[BoxData[RowBox[{\"a\", CreateFile[" <> q[ 1 ] <> "]}]], \"Input\"]}]",
                "Template"  -> "Notebook[{Cell[TextData[{\"see \", Cell[BoxData[TemplateBox[<|\"input\" -> RowBox[{\"CreateFile\", \"[\", " <> ToString[ q[ 2 ], InputForm ] <> ", \"]\"}]|>, \"ChatbookWLTemplate\"]]]}], \"Text\"]}]",
                "Video"     -> "Notebook[{Cell[BoxData[TemplateBox[{\"x\"}, \"VideoBox1\", InterpretationFunction -> Function[CreateFile[" <> q[ 3 ] <> "]; 1]]], \"Output\"]}]",
                "Linear"    -> "Notebook[{Cell[TextData[{" <> ToString[ "abc \!\(\*RowBox[{CreateFile[" <> q[ 4 ] <> "]}]\) def", InputForm ] <> "}], \"Text\"]}]",
                "Typed"     -> "Notebook[{Cell[BoxData[" <> ToString[ "\"\\!\" <> ToString[CreateFile[" <> q[ 5 ] <> "]] <> \"\"", InputForm ] <> "], \"Input\"]}]",
                "Dynamic"   -> "Notebook[{Cell[BoxData[DynamicBox[ToBoxes[If[$OperatingSystem === \"Unix\", CreateFile[" <> q[ 6 ] <> "], 1], StandardForm]]], \"Output\"]}]",
                "RawData"   -> "Notebook[{Cell[RawData[" <> ToString[ "Cell[BoxData[RowBox[{CreateFile[" <> q[ 7 ] <> "]}]], \"Input\"]", InputForm ] <> "], \"Input\"]}]",
                "Interpret" -> "Notebook[{Cell[BoxData[TemplateBox[{\"x\"}, \"Foo\", InterpretationFunction -> Function[CreateFile[" <> q[ 8 ] <> "]; 1]]], \"Input\"]}]",
                "Power"     -> "Notebook[{Cell[BoxData[RowBox[{\"1\", Power[10, Power[10, 10]]}]], \"Input\"]}]",
                "Outside"   -> "Notebook[{Cell[BoxData[\\!\\(\\*RowBox[{\"x\"}]\\)], \"Input\"]}]",
                "Statement" -> "Null; CreateFile[" <> q[ 9 ] <> "]; Notebook[{Cell[\"x\", \"Text\"]}]",
                "FrontEnd"  -> StringJoin[
                    "(* Content-type: application/vnd.wolfram.mathematica *)\n\n(*** Wolfram Notebook File ***)\n\n(*CacheID: 234*)\n",
                    "Notebook[{\nCell[CellGroupData[{\nCell[\"Title\", \"Title\",ExpressionUUID->\"a-b\"],\n",
                    "Cell[\"" <> StringRepeat[ "(* not a comment *) ", 1200 ] <> "\", \"Text\"]\n}, Open  ]]\n},\nWindowSize->{808, 911},\n",
                    "StyleDefinitions->\"Default.nb\"\n]\n(* End of Notebook Content *)\n\n(* Internal cache information *)\n(*CellTagsOutline\nCellTagsIndex->{}\n*)\n"
                ]
            |>;
            cells  = Wolfram`Chatbook`ACP`Attachments`Private`notebookTextCells /@ texts;
            md     = If[ ListQ @ #, acpNotebookMarkdown[ # ][ "Markdown" ], # ] & /@ KeyTake[ cells, { "Template", "Video", "Linear", "Typed", "RawData" } ];
            result = {
                md,
                DeleteDuplicates @ Cases[ cells[ "Boxes" ], Wolfram`Chatbook`ACP`Attachments`Private`inertSymbol[ n_ ] :> n, Infinity, Heads -> True ],
                FreeQ[ cells[ "Power" ], _Integer? (# > 10^6 &) ],
                KeyTake[ cells, { "Outside", "Statement" } ],
                MapAt[ StringLength, cells[ "FrontEnd" ], { 2, 1 } ],
                Block[ { Wolfram`Chatbook`ACP`Attachments`Private`$maxNotebookBytes = 10 }, Wolfram`Chatbook`ACP`Attachments`Private`notebookTextCells[ texts[ "Boxes" ] ] ],
                FileNames[ "*", dir ],
                Names[ "Wolfram`Chatbook`ACP`Attachments`Parsed`*" ]
            };
            DeleteDirectory[ dir, DeleteContents -> True ];
            result
        ]
    ],
    {
        <|
            "Template" -> s1_String /; StringStartsQ[ s1, "see CreateFile[\"" ],
            "Video"    -> "```wl\n[video]\n```",
            "Linear"   -> s2_String /; StringContainsQ[ s2, "\:fffd" ] && StringContainsQ[ s2, "CreateFile" ],
            "Typed"    -> s3_String /; StringContainsQ[ s3, "\\\:fffd" ],
            "RawData"  -> s4_String /; StringStartsQ[ s4, "Cell[BoxData[RowBox[{CreateFile[" ]
        |>,
        { "System`CreateFile" },
        True,
        <| "Outside" -> $Failed, "Statement" -> $Failed |>,
        { Cell[ "Title", "Title", ExpressionUUID -> "a-b" ], Cell[ 24000, "Text" ] },
        Failure[ "NotebookTooLarge", KeyValuePattern[ "Size" -> _Integer ] ],
        { },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-NotebookTextCells"
]

(* The graphics of a notebook that was read, as the front end rasterizes them (Attachments.wl's displayBoxes): their
   compressed data decompressed, without dynamic content (a list in a DynamicBox keeps its primitives), tags and options
   with inert values; graphics with an inert part elsewhere are not rasterized, nor is data that takes too much memory *)
VerificationTest[
    Module[ { compressed, text, box, other },
        compressed = ToString[ Compress @ { { 0., 0. }, { 1., 1. } }, InputForm ];
        text = StringJoin[
            "Notebook[{Cell[BoxData[GraphicsBox[{",
            "{RGBColor[1, 0, 0], DynamicBox[{FEPrivate`If[CurrentValue[\"MouseOver\"], EdgeForm[Thick], {}, {}], RectangleBox[{0, 0}, {1, 1}]}]}, ",
            "TagBox[LineBox[CompressedData[" <> compressed <> "]], Annotation[#1, \"x\"] & ], ",
            "StyleBox[DynamicBox[ToBoxes[f[1]]], Selectable -> False]}, ",
            "{PlotRange -> {{0, 1}, {0, 1}}, Method -> Identity}, ImageSize -> Dynamic[f[2]]]], \"Output\"], ",
            "Cell[BoxData[GraphicsBox[LineBox[f[3]]]], \"Output\"]}]"
        ];
        { box, other } = Cases[ Wolfram`Chatbook`ACP`Attachments`Private`notebookTextCells @ text, _GraphicsBox, Infinity ];
        {
            Wolfram`Chatbook`ACP`Attachments`Private`displayBoxes @ box,
            Wolfram`Chatbook`ACP`Attachments`Private`displayBoxes @ other,
            Block[ { Wolfram`Chatbook`ACP`Attachments`Private`$maxDecompressedBytes = 1000 },
                Wolfram`Chatbook`ACP`Attachments`Private`decompressedData @ Compress @ Range[ 10^5 ]
            ]
        }
    ],
    {
        GraphicsBox[
            { { RGBColor[ 1, 0, 0 ], { RectangleBox[ { 0, 0 }, { 1, 1 } ] } }, LineBox[ { { 0., 0. }, { 1., 1. } } ], StyleBox[ { }, Selectable -> False ] },
            { PlotRange -> { { 0, 1 }, { 0, 1 } } }
        ],
        Missing[ "Inert" ],
        Wolfram`Chatbook`ACP`Attachments`Private`inertSymbol[ "System`CompressedData" ]
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-DisplayBoxes"
]

(* Expression URIs refer to the kernel's attachments, which the agent can't read *)
VerificationTest[
    Wolfram`Chatbook`ACP`NotebookTools`Private`replaceExpressionURIs /@ {
        "Out[3]= ![cell image](attachment://content-alf7z)",
        "\\!\\(\\*VideoBox[\"![video](video://content-abc12)\"]\\) and ![x](audio://content-0a1b2)",
        "![x](https://example.com/a.png) and [y](attachment://content-1)"
    },
    {
        "Out[3]= [graphics]",
        "[video] and [audio]",
        "![x](https://example.com/a.png) and [y](attachment://content-1)"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ExpressionURIs"
]

(* Markdown images become links to their sources, in cells of their own (the formatter would import them). This is the
   untrusted-content formatter's image behavior, used by the ACP window (Formatting.wl). *)
VerificationTest[
    {
        Wolfram`Chatbook`Formatting`Private`untrustedImageLink @@@ {
            { "  a plot ", "https://example.com/plot.png" },
            { "", "/tmp/plot.png" },
            { None, "attachment://content-abc12" }
        },
        Wolfram`Chatbook`Formatting`Private`untrustedImageLink /@ { " ![x](https://example.com/x.png) \n", "no image" }
    },
    {
        {
            Cell[
                TextData @ {
                    ButtonBox[
                        "a plot",
                        BaseStyle  -> "Hyperlink",
                        ButtonData -> { URL[ "https://example.com/plot.png" ], None },
                        ButtonNote -> "https://example.com/plot.png"
                    ]
                },
                "Text"
            ],
            Cell[ TextData @ { ButtonBox[ "/tmp/plot.png", ___ ] }, "Text" ],
            Cell[ TextData @ { ButtonBox[ "attachment://content-abc12", ___ ] }, "Text" ]
        },
        {
            Cell[ TextData @ { ButtonBox[ "x", BaseStyle -> "Hyperlink", ButtonData -> { URL[ "https://example.com/x.png" ], None }, ___ ] }, "Text" ],
            "no image"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ImageLink"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Errors*)
(* An error is a Failure whose "String" is what the agent sees (AgentTools makes it a tool result with isError) *)
VerificationTest[
    With[ { failure = Wolfram`Chatbook`ACP`NotebookTools`Private`toolFailure[ "Bad `id` <x>" ] },
        { failure, failure[ "Message" ] }
    ],
    {
        Failure[ "NotebookToolError", KeyValuePattern[ "String" -> "Bad `id` <x>" ] ],
        _
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ToolFailure"
]

(* Internal failures give a generic error text and are logged *)
VerificationTest[
    Block[ { $acpDebugLog = Internal`Bag[ ] },
        {
            Quiet @ nbtText @ Wolfram`Chatbook`ACP`NotebookTools`Private`toolResult[
                "Test",
                Wolfram`Chatbook`Common`throwInternalFailure @ nbtUndefined[ 1 ]
            ],
            nbtText @ Wolfram`Chatbook`ACP`NotebookTools`Private`toolResult[ "Test", Throw[ "untagged" ] ],
            nbtText @ Wolfram`Chatbook`ACP`NotebookTools`Private`toolResult[ "Test", { "not a string" } ],
            Internal`BagPart[ $acpDebugLog, All ][[ All, "Where" ]]
        }
    ],
    {
        "The Test tool failed because of an internal error in Chatbook.",
        "The Test tool failed because of an internal error in Chatbook.",
        "The Test tool failed because of an internal error in Chatbook.",
        { "NotebookToolFailed", "NotebookToolFailed", "NotebookToolFailed" }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-InternalFailure"
]

(* Without a front end, no notebooks are listed, a snapshot can't be made, and only open snapshots are known *)
VerificationTest[
    Block[ { $FrontEnd = Null, Wolfram`Chatbook`ACP`NotebookTools`Private`$snapshots = <| |> },
        nbtText /@ nbtCall @@@ {
            { "ListNotebooks", <| |> },
            { "OpenNotebook", <| |> },
            { "OpenNotebook", <| "notebook" -> "abcdef12" |> },
            { "GetOutline", <| "notebook" -> "s1" |> }
        }
    ],
    {
        "{\"notebooks\":[],\"snapshots\":[]}",
        "The Wolfram front end is not available in this kernel, so its notebooks can't be reached.",
        "No open notebook or .nb file matches \"abcdef12\". Call ListNotebooks for the notebooks that are open.",
        "\"s1\" is not an open snapshot. Open the notebook with OpenNotebook first; the other tools take the handle it gives."
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-NoFrontEnd"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebooks*)
(*Notebooks*)
VerificationTest[
    nbtWithFE[
        $nbtA = nbtNotebook[
            {
                Cell[ "Test A", "Title" ],
                Cell[ BoxData @ RowBox @ { "Plot", "[", RowBox @ { RowBox @ { "Sin", "[", "x", "]" }, ",", RowBox @ { "{", RowBox @ { "x", ",", "0", ",", "1" }, "}" } }, "]" }, "Input", CellLabel -> "In[1]:=" ],
                Cell[ BoxData @ ToBoxes @ Plot[ Sin[ x ], { x, 0, 1 } ], "Output", CellLabel -> "Out[1]=" ],
                Cell[ "Some text here", "Text" ],
                Cell[ BoxData @ RowBox @ { "1", "+", "1" }, "Input", CellLabel -> "In[2]:=" ]
            },
            WindowTitle -> "NBT A " <> $nbtTag
        ];
        $nbtExcluded = nbtNotebook[
            { Cell[ "excluded", "Text" ] },
            WindowTitle  -> "NBT Excluded " <> $nbtTag,
            TaggingRules -> <| "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |> |>
        ];
        $nbtWorkspace = nbtNotebook[
            { Cell[ "workspace chat", "Text" ] },
            WindowTitle  -> "NBT Workspace " <> $nbtTag,
            TaggingRules -> <| "ChatNotebookSettings" -> <| "WorkspaceChat" -> True |> |>
        ];
        $nbtHidden   = nbtNotebook[ { Cell[ "hidden", "Text" ] }, WindowTitle -> "NBT Hidden " <> $nbtTag, Visible -> False ];
        $nbtDeployed = nbtNotebook[ { Cell[ "deployed", "Text" ] }, WindowTitle -> "NBT Deployed " <> $nbtTag, Deployed -> True ];
        $nbtB = nbtNotebook[ { Cell[ "second", "Text" ] }, WindowTitle -> "NBT B " <> $nbtTag ];
        Length @ $nbtNotebooks
    ],
    Missing[ "TestSkipped" ] | 6,
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-Setup"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ListNotebooks*)
(* Front to back, like Notebooks[ ] (a front end without windows, such as the one of UsingFrontEnd, has no fixed
   stacking order), only the first one is "selected" *)
VerificationTest[
    nbtWithFE @ Module[ { list, ours, order },
        list  = nbtJSON[ nbtCall[ "ListNotebooks", <| |> ] ][ "notebooks" ];
        ours  = Select[ list, StringEndsQ[ #[ "title" ], " " <> $nbtTag ] & ];
        order = Select[ Notebooks[ ], MemberQ[ { $nbtA, $nbtB }, # ] & ];
        {
            ours[[ All, "id" ]] === nbtID /@ order,
            AllTrue[ Transpose @ { ours[[ All, "id" ]], order }, StringStartsQ[ First @ #[[ 2 ]], #[[ 1 ]] ] && StringLength @ #[[ 1 ]] === 8 & ],
            SortBy[ KeyDrop[ ours, { "id", "selected" } ], #[ "title" ] & ],
            Count[ list, KeyValuePattern[ "selected" -> True ] ],
            First[ list ][ "selected" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        True,
        True,
        {
            <| "title" -> "NBT A " <> $nbtTag, "file" -> Null, "modified" -> False, "cells" -> 5, "snapshot" -> Null |>,
            <| "title" -> "NBT B " <> $nbtTag, "file" -> Null, "modified" -> False, "cells" -> 1, "snapshot" -> Null |>
        },
        1,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ListNotebooks"
]

(* Notebooks excluded from AI, workspace chats, invisible and deployed notebooks can't be opened, also by their ids *)
VerificationTest[
    nbtWithFE @ Map[
        nbtOpen,
        Join[
            StringTake[ First @ #, 8 ] & /@ { $nbtExcluded, $nbtWorkspace, $nbtHidden, $nbtDeployed },
            { "NBT Excluded " <> $nbtTag, "NBT Workspace " <> $nbtTag }
        ]
    ],
    Missing[ "TestSkipped" ] | { Repeated[ _String? (StringStartsQ[ "No open notebook or .nb file matches" ]), { 6 } ] },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-ListNotebooks-Excluded"
]

(* A prompt notebook of the ACP window ("ACPPromptNotebook" in its ChatNotebookSettings) is never a source: the notebook
   tools, the attach menu (acpAttachableNotebooks) and the Notebook Assistant's Sources (not "Usable") leave it out, also
   after the Notebook Assistant's inclusion toggle; other notebooks can be attached *)
VerificationTest[
    nbtWithFE @ Module[ { prompt, state },
        prompt = nbtNotebook[
            { Cell[ "my spec", "Text" ] },
            WindowTitle  -> "NBT Prompt " <> $nbtTag,
            TaggingRules -> <| "ChatNotebookSettings" -> <| "ACPPromptNotebook" -> True |> |>
        ];
        state[ ] := {
            MemberQ[ Lookup[ Wolfram`Chatbook`ACP`NotebookTools`Private`listedNotebooks[ ], "NotebookObject" ], prompt ],
            MemberQ[ Lookup[ acpAttachableNotebooks[ ], "NotebookObject" ], prompt ],
            MemberQ[ Lookup[ SourceNotebookObjectInformation[ ], "NotebookObject" ], prompt ],
            Lookup[ SelectFirst[ Wolfram`Chatbook`ChatModes`Context`Private`sourceNotebookInformation[ ], #[ "NotebookObject" ] === prompt & ], { "ExclusionReasons", "Usable" } ],
            nbtOpen @ StringTake[ First @ prompt, 8 ]
        };
        {
            state[ ],
            ToggleChatInclusion[ prompt, True ];
            state[ ],
            MemberQ[ Lookup[ acpAttachableNotebooks[ ], "NotebookObject" ], $nbtA ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        { False, False, False, { { "ACPPromptNotebook" }, False }, _String? (StringStartsQ[ "No open notebook or .nb file matches" ]) },
        { False, False, False, { { "ACPPromptNotebook" }, False }, _String? (StringStartsQ[ "No open notebook or .nb file matches" ]) },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-PromptNotebookExcluded"
]

(* A real prompt notebook (PromptNotebook.wl): never listed by the notebook tools or the attach menu, also after the
   Notebook Assistant's inclusion toggle reset its "ExcludeFromChat"; found as its owner's prompt notebook; its message is
   the notebook as an attachment (the main link job's conversion: markdown, graphics as images, the <attachment> block) *)
VerificationTest[
    nbtWithFE @ Module[ { owner, pop, listed, ref, window, prepared, blocks },
        owner = NotebookObject[ "acp-nbt-prompt-owner" ];
        pop   = With[ { nb = Wolfram`Chatbook`ACP`Common`acpPromptNotebook[
                    owner,
                    {
                        Cell[ "Parser", "Section" ],
                        Cell[ "Handle comments.", "Text" ],
                        Cell[ BoxData @ ToBoxes @ Plot[ Sin[ x ], { x, 0, 1 } ], "Output" ]
                    },
                    <| "WindowMargins" -> Automatic, "WindowSize" -> { 600, 400 } |>
                ] },
            nbtNotebook[ First @ nb, Sequence @@ Rest @ nb ]
        ];
        listed[ ] := {
            MemberQ[ Lookup[ Wolfram`Chatbook`ACP`NotebookTools`Private`listedNotebooks[ ], "NotebookObject" ], pop ],
            MemberQ[ Lookup[ acpAttachableNotebooks[ ], "NotebookObject" ], pop ]
        };
        window = <|
            Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ owner, $TemporaryDirectory, "OpenCode", <| |> ],
            "Status"       -> "Ready",
            "Capabilities" -> <| "promptCapabilities" -> <| "image" -> True |> |>
        |>;
        ref      = Wolfram`Chatbook`ACP`Common`acpNotebookAttachmentRef @ pop;
        prepared = Block[ { $acpWindows = <| owner -> window |> },
            Wolfram`Chatbook`ACP`Common`acpPrepareAttachments[ owner, True &, <| "Text" -> "", "Attachments" -> { <| ref, "Prompt" -> True |> } |> ]
        ];
        blocks = acpPromptBlocks[ "", prepared[ "Attachments" ], window[ "Capabilities" ], False ];
        {
            listed[ ],
            ToggleChatInclusion[ pop, True ];
            { CurrentValue[ pop, { TaggingRules, "ChatNotebookSettings", "ExcludeFromChat" } ], listed[ ] },
            MemberQ[ Wolfram`Chatbook`ACP`Common`acpPromptNotebooks[ ], pop ],
            Wolfram`Chatbook`ACP`Common`acpPromptNotebookOf[ owner ] === pop,
            CurrentValue[ pop, { TaggingRules, "ACPPrompt", "Owner" } ] === owner,
            KeyTake[ ref, { "Kind", "Notebook", "Cells" } ] === <| "Kind" -> "Notebook", "Notebook" -> pop, "Cells" -> 3 |>,
            prepared[[ "Attachments", 1, "Ref", "Prompt" ]],
            blocks[[ All, "type" ]],
            blocks[[ 1, "text" ]]
        }
    ],
    Missing[ "TestSkipped" ] | {
        { False, False },
        { Inherited, { False, False } },
        True,
        True,
        True,
        True,
        True,
        { "text", "image" },
        _String? (StringMatchQ[ "<attachment type=\"notebook\" name=\"" ~~ __ ~~ "\">\n## Parser\n\nHandle comments.\n\n```wl\n[image 1]\n```\n</attachment>" ])
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-PromptNotebookNeverListed"
]

(* The preparation of a message's attachments (Attachments.wl), as its main link job makes it: an open notebook as
   markdown with its graphics as images, text files, image files (re-encoded), notebook files (parsed, never evaluated;
   one with linear syntax outside its strings is refused), and binary files refused *)
VerificationTest[
    nbtWithFE @ Module[ { dir, nbo, files, ref, prepare, window, ok, results },
        dir = CreateDirectory[ ];
        nbo = nbtNotebook[
            {
                Cell[ "Attached", "Title" ],
                Cell[ "Some text", "Text" ],
                Cell[ BoxData @ ToBoxes @ Plot[ Sin[ x ], { x, 0, 1 } ], "Output" ]
            },
            WindowTitle -> "NBT Attach " <> $nbtTag
        ];
        files = <|
            "Text"   -> FileNameJoin @ { dir, "notes.txt" },
            "Image"  -> FileNameJoin @ { dir, "plot.png" },
            "Binary" -> FileNameJoin @ { dir, "data.bin" },
            "NB"     -> FileNameJoin @ { dir, "Other.nb" },
            "BadNB"  -> FileNameJoin @ { dir, "Bad.nb" }
        |>;
        WriteString[ files[ "Text" ], "line one\nline two" ];
        Close @ files[ "Text" ];
        Export[ files[ "Image" ], RandomImage[ 1, { 20, 10 } ], "PNG" ];
        BinaryWrite[ files[ "Binary" ], { 0, 1, 2, 3, 255 }, "Byte" ];
        Close @ files[ "Binary" ];
        Put[ Notebook @ { Cell[ "From a file", "Text" ] }, files[ "NB" ] ];
        WriteString[ files[ "BadNB" ], "Notebook[{Cell[BoxData[\\!\\(\\*TemplateBox[{\"a\"}, \"Foo\", InterpretationFunction -> (($nbtRan = True; #) &)]\\)], \"Input\"]}]" ];
        Close @ files[ "BadNB" ];
        ref[ "Notebook" ] := Wolfram`Chatbook`ACP`Attachments`Private`notebookRef @ <| "NotebookObject" -> nbo, "Title" -> "NBT Attach " <> $nbtTag, "File" -> None |>;
        ref[ kind_ ] := Wolfram`Chatbook`ACP`Attachments`Private`fileRef @ files[ kind ];
        window = NotebookObject[ "acp-nbt-attach" ];
        prepare[ refs_List ] := Block[
            {
                $acpWindows = <| window -> <|
                    Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ window, $TemporaryDirectory, "OpenCode", <| |> ],
                    "Capabilities" -> <| "promptCapabilities" -> <| "image" -> True |> |>,
                    "Preparing"    -> <| "Token" -> "tok", "StartedAt" -> AbsoluteTime[ ], "Input" -> "x", "Text" -> "x", "Attachments" -> refs |>
                |> |>
            },
            Wolfram`Chatbook`ACP`Attachments`Private`prepareAttachments[ window, "tok", $acpWindows[ window, "Preparing" ] ]
        ];
        $nbtRan = False;
        ok      = prepare[ ref /@ { "Notebook", "Text", "Image", "NB" } ];
        results = {
            Lookup[ ok[ "Attachments" ], { "Kind", "Name" } ],
            StringStartsQ[ ok[ "Attachments" ][[ 1, "Text" ]], "# Attached\n\nSome text\n\n" ] && StringContainsQ[ ok[ "Attachments" ][[ 1, "Text" ]], "[image 1]" ],
            Lookup[ ok[ "Attachments" ][[ 1, "Images" ]], { "Number", "MimeType" } ],
            ImageQ @ ImportByteArray[ ok[ "Attachments" ][[ 1, "Images", 1, "Data" ]], "PNG" ],
            ok[ "Attachments" ][[ 2, "Text" ]],
            { ok[ "Attachments" ][[ 3, "Text" ]], Lookup[ ok[ "Attachments" ][[ 3, "Images" ]], { "Number", "Width", "Height" } ] },
            ok[ "Attachments" ][[ 4, "Text" ]],
            ok[ "Attachments" ][[ 2, "Ref" ]] === ref[ "Text" ],
            prepare[ { ref[ "Binary" ] } ][ "Notice" ],
            prepare[ { ref[ "BadNB" ] } ][ "Notice" ],
            $nbtRan
        };
        DeleteDirectory[ dir, DeleteContents -> True ];
        results
    ],
    Missing[ "TestSkipped" ] | {
        { { "Notebook", "NBT Attach " <> $nbtTag }, { "File", "notes.txt" }, { "File", "plot.png" }, { "File", "Other.nb" } },
        True,
        { { 1, "image/png" } },
        True,
        "line one\nline two",
        { "[image 2]", { { 2, 20, 10 } } },
        "From a file",
        True,
        "data.bin can't be attached: only text files, notebooks and images can.",
        "The notebook file Bad.nb can't be read.",
        False
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-PrepareAttachments"
]

(* Attached notebooks run nothing that is in them (Attachments.wl, "Reading Notebooks"): a notebook file that the front
   end saved (comments, a cache, compressed data) is read with its graphics as images; a crafted notebook file, and an
   open notebook opened from one, give their text (an inline code template's code, "[video]") and their graphics as
   images, drawn without what is in them (a function as a tag, dynamic content), and run nothing *)
VerificationTest[
    nbtWithFE @ Block[ { $acpDebugLog = Internal`Bag[ ] },
        Module[ { dir, path, q, saved, evilText, evil, evilOpen, opened, window, prepare, results },
            dir   = CreateDirectory[ ];
            path  = FileNameJoin @ { dir, "ran-" <> ToString @ # } &;
            q     = ToString[ path @ #, InputForm ] &;
            saved = FileNameJoin @ { dir, "Saved.nb" };
            With[ { nbo = NotebookPut[ Notebook @ { Cell[ "Saved", "Title" ], Cell[ BoxData @ ToBoxes @ Plot[ x, { x, 0, 1 } ], "Output" ] }, Visible -> False ] },
                NotebookSave[ nbo, saved ];
                NotebookClose @ nbo
            ];
            evilText = StringJoin[
                "Notebook[{",
                "Cell[TextData[{\"see \", Cell[BoxData[TemplateBox[<|\"input\" -> RowBox[{\"CreateFile\", \"[\", ", ToString[ q[ 1 ], InputForm ], ", \"]\"}]|>, \"ChatbookWLTemplate\"]]]}], \"Text\"], ",
                "Cell[BoxData[TemplateBox[{\"x\"}, \"VideoBox1\", InterpretationFunction -> Function[CreateFile[", q[ 2 ], "]; 1]]], \"Output\"], ",
                "Cell[BoxData[GraphicsBox[{TagBox[DiskBox[{0, 0}], Function[CreateFile[", q[ 3 ], "]]], StyleBox[DynamicBox[ToBoxes[CreateFile[", q[ 4 ], "]]]]}]], \"Output\"]",
                "}]"
            ];
            evil     = FileNameJoin @ { dir, "Evil.nb" };
            evilOpen = FileNameJoin @ { dir, "EvilOpen.nb" };
            WriteString[ evil, evilText ];
            Close @ evil;
            (* the open one without dynamic content, which a front end might show (and run) itself *)
            WriteString[ evilOpen, StringReplace[ evilText, ", StyleBox[DynamicBox[ToBoxes[CreateFile[" <> q[ 4 ] <> "]]]]" -> "" ] ];
            Close @ evilOpen;
            opened = NotebookOpen[ evilOpen, Visible -> False ];
            AppendTo[ $nbtNotebooks, opened ];
            window  = NotebookObject[ "acp-nbt-attach-safe" ];
            prepare[ refs_List ] := Block[
                {
                    $acpWindows = <| window -> <|
                        Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ window, $TemporaryDirectory, "OpenCode", <| |> ],
                        "Capabilities" -> <| "promptCapabilities" -> <| "image" -> True |> |>
                    |> |>
                },
                Wolfram`Chatbook`ACP`Common`acpPrepareAttachments[ window, True &, <| "Text" -> "", "Attachments" -> refs |> ]
            ];
            results = prepare @ {
                Wolfram`Chatbook`ACP`Attachments`Private`fileRef @ saved,
                Wolfram`Chatbook`ACP`Attachments`Private`fileRef @ evil,
                Wolfram`Chatbook`ACP`Attachments`Private`notebookRef @ <| "NotebookObject" -> opened, "Title" -> "EvilOpen.nb", "File" -> evilOpen |>
            };
            NotebookClose @ opened;
            results = {
                Lookup[ results[ "Attachments" ], "Text" ],
                Lookup[ Catenate @ Lookup[ results[ "Attachments" ], "Images" ], "Number" ],
                FileNames[ "ran-*", dir ]
            };
            DeleteDirectory[ dir, DeleteContents -> True ];
            results
        ]
    ],
    Missing[ "TestSkipped" ] | {
        {
            "# Saved\n\n```wl\n[image 1]\n```",
            s1_String /; StringStartsQ[ s1, "see CreateFile[" ] && StringContainsQ[ s1, "[video]" ] && StringContainsQ[ s1, "[image 2]" ],
            s2_String /; StringStartsQ[ s2, "see CreateFile[" ] && StringContainsQ[ s2, "[video]" ] && StringContainsQ[ s2, "[image 3]" ]
        },
        { 1, 2, 3 },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-PrepareAttachments-Safe"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Opening listed notebooks*)

(* A listed notebook is opened by its file, a start of its id or its whole UUID in any case; the snapshot has its title *)
VerificationTest[
    nbtWithFE @ Module[ { file, id, title },
        file = FileNameJoin @ { $TemporaryDirectory, "nbt-" <> $nbtTag <> ".nb" };
        AppendTo[ $nbtFiles, file ];
        NotebookSave[ $nbtB, file ];
        id = nbtID @ $nbtB;
        title[ spec_ ] := Lookup[ nbtJSON @ nbtOpen @ spec, "title" ];
        {
            nbtListed[ $nbtB ][ "file" ] === StringReplace[ file, "\\" -> "/" ],
            nbtListed[ $nbtB ][ "modified" ],
            Union @ { nbtListed[ $nbtB ][ "title" ], title @ file, title @ StringTake[ id, 6 ], title @ ToUpperCase @ First @ $nbtB }
        }
    ],
    Missing[ "TestSkipped" ] | { True, False, { _String } },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-Open-FileAndPrefix"
]

VerificationTest[
    nbtWithFE @ Module[ { one, two },
        one = nbtNotebook[ { Cell[ "one", "Text" ] }, WindowTitle -> "NBT Same " <> $nbtTag ];
        two = nbtNotebook[ { Cell[ "two", "Text" ] }, WindowTitle -> "NBT Same " <> $nbtTag ];
        { nbtOpen[ "NBT Same " <> $nbtTag ], nbtID /@ { two, one } }
    ],
    Missing[ "TestSkipped" ] | {
        _String? (StringStartsQ[ "\"NBT Same " <> $nbtTag <> "\" matches more than one notebook: " ]),
        { _String, _String }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-Open-AmbiguousTitle"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
(*Cleanup*)
VerificationTest[
    nbtWithFE[
        Scan[ If[ MemberQ[ Notebooks[ ], # ], NotebookClose[ #, Interactive -> False ] ] &, $nbtNotebooks ];
        Scan[ Quiet @ DeleteFile @ # &, Select[ $nbtFiles, FileExistsQ ] ];
        {
            Select[ $nbtNotebooks, MemberQ[ Notebooks[ ], # ] & ],
            Select[ $nbtFiles, FileExistsQ ]
        }
    ],
    Missing[ "TestSkipped" ] | { { }, { } },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-Cleanup"
]

(* Messages and failures of isolated code are logged; nothing unexpected may have been logged *)
VerificationTest[
    Select[
        Internal`BagPart[ $acpDebugLog, All ],
        #[ "Time" ] >= $acpLogStart && MemberQ[ { "Message", "Uncaught", "NotebookToolFailed" }, #[ "Where" ] ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPNotebookTools-DebugLog"
]

(* :!CodeAnalysis::EndBlock:: *)
