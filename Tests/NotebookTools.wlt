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

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
(* :!CodeAnalysis::Disable::NoSurroundingCatch:: *)
(* :!CodeAnalysis::Disable::UnrecognizedLongName:: *)

(* Tests for the notebook editing tools (Tools/NotebookTools.wl, registered in Tools/DefaultToolDefinitions/NotebookTools.wl):
   their registration and gating, the pure parts (ids, resolution, arguments, the check of model text), every tool on a
   made-up front end (the tools make every front end call through notebookFrontEnd, which the tests replace: no released
   front end has the snapshot and cell text packets yet), the vendored CellDiff comparison, and a tool call through the
   Simple tool method. The tools are called through their LLMTools. The tools' functions don't check the kernel version
   (only "Enabled" does), so these tests also run on 15.0. The tests of ListNotebooks, of the notebooks that can be opened
   and of the front end probe need a front end: they run under UsingFrontEnd (which starts one if the test kernel has
   none; CI runs the tests under UsingFrontEnd anyway) and give Missing["TestSkipped"] if no front end can be started.
   Every notebook they create is closed at the end. The notebooks of a kernel that runs in a desktop front end are listed
   as well, so the tests only look at their own notebooks. The tool state ($snapshots, ...) is Blocked in every test that
   changes it, so that nothing is left for other test files (CI runs them all in one kernel). *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    (* CI runs every test file in one kernel and one context: these helpers are only defined here *)
    ClearAll[
        fakeCell, fakeFE, fakeFE0, fakePosition, nbtCall, nbtID, nbtJSON, nbtListed, nbtNotebook, nbtOpen, nbtResult,
        nbtText, nbtWithFE, withFakeFE
    ];

    $nbtTag       = IntegerString[ RandomInteger[ { 10^5, 10^6 - 1 } ] ];
    $nbtNotebooks = { };
    $nbtFiles     = { };
    $nbtNames     = {
        "ListNotebooks", "OpenNotebook", "GetOutline", "ReadCells", "SearchNotebook", "GetSelection", "EditInCell",
        "SetCells", "InsertCells", "DeleteCells", "ShowChanges", "CloseNotebook"
    };
    $nbtTools     = AssociationMap[ Wolfram`Chatbook`$DefaultTools, $nbtNames ];
    $nbtFrontEndQ = TrueQ @ Quiet @ MatchQ[ UsingFrontEnd @ $FrontEnd, _FrontEndObject ];

    (* A tool called with its arguments: the LLMTool applied to them *)
    nbtCall[ name_String, args_Association ] := $nbtTools[ name ][ args ];

    (* The text the model gets: a result, or the "String" of an error result *)
    nbtText[ KeyValuePattern[ "String" -> text_String ] ] := text;
    nbtText[ other_ ] := other;

    (* The JSON at the start of a result (OpenNotebook's result has more after it) *)
    nbtJSON[ text_String ] := Developer`ReadRawJSONString @ First @ StringSplit[ text, "\n\n", 2 ];
    nbtJSON[ other_ ] := other;

    (* The value of a pure part, or the text of the tool error it ends with *)
    nbtResult // Attributes = { HoldFirst };
    nbtResult[ eval_ ] := Catch[ eval, Wolfram`Chatbook`Tools`NotebookTools`Private`$toolErrorTag, #1 & ];

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

    (* Made-up notebook entries for the pure tests *)
    $nbtEntries = {
        <| "Key" -> "abcdef11-0000-4000-8000-000000000001", "ID" -> "abcdef11", "Title" -> "One", "File" -> "/tmp/one.nb" |>,
        <| "Key" -> "abcdef22-0000-4000-8000-000000000002", "ID" -> "abcdef22", "Title" -> "Two", "File" -> None |>,
        <| "Key" -> "12345678-0000-4000-8000-000000000003", "ID" -> "12345678", "Title" -> "Two", "File" -> None |>
    };

    (* Cell text that a model sends through the Simple tool method as JSON: backslashes (an escaped one in a text cell,
       a named character), quotes and characters that are not ASCII *)
    $nbtE2EText     = "(*A backslash \\\\ and \\[Rule] in \"quotes\": \[Alpha] \:00e9t\:00e9 \:65e5\:672c*)";
    $nbtE2ECodeText = "StringJoin[\"\\\\\", \"\\[Alpha]\", \"\:00e9\"]";

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
        fakeCell[ "src-5", "Output", "\:3014FE`ElidedBox[1, \"GraphicsBox\", 48213]\:3015", 2 ],
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
                                If[ StringContainsQ[ op[[ 4 ]], "PARSEERROR" ],
                                    Throw[ Failure[ "ParseError", <|
                                        "MessageTemplate" -> "The short form at character `1` has no simple token before it.",
                                        "MessageParameters" -> { First @ First @ StringPosition[ op[[ 4 ]], "PARSEERROR" ] },
                                        "Operation" -> i
                                    |> ], $fakeTag ]
                                ];
                                cells[[ pos, "Text" ]] = op[[ 4 ]];
                                If[ op[[ 3 ]] =!= Automatic, cells[[ pos, "Style" ]] = op[[ 3 ]] ];
                                AppendTo[ changed, op[[ 2 ]] ]
                            ],
                        "Insert",
                            Module[ { at, new },
                                If[ AnyTrue[ op[[ 4 ]], StringContainsQ[ #[[ 2 ]], "PARSEERROR" ] & ],
                                    Throw[ Failure[ "ParseError", <| "MessageTemplate" -> "Wrapper 1 is not one box expression in FullForm.", "Operation" -> i |> ], $fakeTag ]
                                ];
                                at = Which[
                                    op[[ 2 ]] === None && op[[ 3 ]] === "Before", 1,
                                    op[[ 2 ]] === None                           , Length @ cells + 1,
                                    op[[ 3 ]] === "Before"                       , fakePosition[ cells, op[[ 2 ]], i ],
                                    True                                         , fakePosition[ cells, op[[ 2 ]], i ] + 1
                                ];
                                new = Append[
                                    fakeCell[ "fake-new-" <> ToString[ ++$fakeCount ], First @ Flatten @ { #[[ 1 ]] }, #[[ 2 ]], 2 ],
                                    "Tags" -> If[ Length @ # === 3, #[[ 3 ]], { } ]
                                ] & /@ op[[ 4 ]];
                                cells = Join[ Take[ cells, at - 1 ], new, Drop[ cells, at - 1 ] ];
                                inserted = Join[ inserted, Lookup[ new, "Cell" ] ]
                            ],
                        "Tags",
                            With[ { pos = fakePosition[ cells, op[[ 2 ]], i ] },
                                cells[[ pos ]] = Append[ cells[[ pos ]], "Tags" -> op[[ 3 ]] ];
                                AppendTo[ changed, op[[ 2 ]] ]
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

    (* the code cells only for the tests of the code check, so that the other edits are not checked *)
    fakeFE0[ "CodeCells", nbo_ ] /; TrueQ @ $fakeCodeCells :=
        <| "Cell" -> #[ "Cell" ], "Boxes" -> #[ "Text" ] |> & /@ Select[ $fakeNotebooks[ nbo, "Cells" ], MemberQ[ { "Input", "Code" }, #[ "Style" ] ] & ];

    fakeFE0[ "Save", _ ] := If[ TrueQ @ $fakeSaveFails, $Failed, Null ];
    fakeFE0[ "Close", nbo_ ] := (KeyDropFrom[ $fakeNotebooks, nbo ]; Null);
    fakeFE0[ "ShowDiff", __ ] := $fakeDiffResult;
    fakeFE0[ "Selection", _NotebookObject, _NotebookObject ] := $fakeSelection;

    fakePosition[ cells_List, cell_, i_Integer ] := Replace[
        FirstPosition[ Lookup[ cells, "Cell" ], cell, None, { 1 } ],
        {
            { p_Integer } :> p,
            _ :> Throw[ Failure[ "CellNotFound", <| "MessageTemplate" -> "The cell does not exist.", "Operation" -> i |> ], $fakeTag ]
        }
    ];

    $fakeTag = "notebook-tools-fake-front-end";

    (* The tools on the made-up front end, with their own snapshots and made-up listed notebooks *)
    withFakeFE // Attributes = { HoldFirst };
    withFakeFE[ eval_ ] := Block[
        {
            Wolfram`Chatbook`Tools`NotebookTools`Private`notebookFrontEnd = fakeFE,
            Wolfram`Chatbook`Tools`NotebookTools`Private`listedNotebooks  = $fakeListed &,
            Wolfram`Chatbook`Tools`NotebookTools`Private`cellCount        = 7 &,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots       = <| |>,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshotCount   = 0,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$texReads        = <| |>,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$texOriginals    = <| |>,
            (* no chat: the snapshots belong to None (chatSnapshots) *)
            Wolfram`Chatbook`$ChatHandlerData                               = <| |>,
            $fakeNotebooks  = <| |>,
            $fakeCalls      = { },
            $fakeCount      = 0,
            $fakeSaveFails  = False,
            $fakeDiffResult = Null,
            $fakeSelection  = <| "Type" -> "None", "Cells" -> { } |>
        },
        eval
    ];

    (* OpenNotebook on the real listed notebooks, with a made-up snapshot (no front end has the snapshot packet yet):
       the model's text *)
    nbtOpen[ spec_ ] := Block[
        {
            Wolfram`Chatbook`Tools`NotebookTools`Private`notebookFrontEnd = fakeFE,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots       = <| |>,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshotCount   = 0,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$texReads        = <| |>,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$texOriginals    = <| |>,
            $fakeNotebooks = <| |>,
            $fakeCalls     = { },
            $fakeCount     = 0
        },
        nbtText @ nbtCall[ "OpenNotebook", <| "notebook" -> spec |> ]
    ];
    Null,
    Null,
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Registration*)

(* The twelve tools are default tools, in order, hidden from the tool manager and built in; SaveNotebook is not a tool
   (ShowChanges saves). Each is found by the machine name a model calls it by (EditInCell's canonical name from
   "edit_incell" would be "EditIncell", so its "Name" is "edit_in_cell"). *)
VerificationTest[
    {
        Keys @ Wolfram`Chatbook`Tools`NotebookTools`$notebookToolSpecs,
        Select[ Keys @ Wolfram`Chatbook`$DefaultTools, MemberQ[ $nbtNames, # ] & ],
        AllTrue[ $nbtTools, MatchQ[ _LLMTool ] ],
        Union[ #[ "Data" ][ "Hidden" ] & /@ Values @ $nbtTools ],
        Union[ #[ "Data" ][ "Origin" ] & /@ Values @ $nbtTools ],
        KeyExistsQ[ Wolfram`Chatbook`$DefaultTools, "SaveNotebook" ],
        #[ "Name" ] & /@ Values @ $nbtTools,
        Wolfram`Chatbook`Common`toolShortName /@ Values @ $nbtTools,
        (Wolfram`Chatbook`Common`getToolByName[ #[ "Name" ] ] === #) & /@ Values @ $nbtTools
    },
    {
        $nbtNames,
        $nbtNames,
        True,
        { True },
        { "BuiltIn" },
        False,
        {
            "list_notebooks", "open_notebook", "get_outline", "read_cells", "search_notebook", "get_selection",
            "edit_in_cell", "set_cells", "insert_cells", "delete_cells", "show_changes", "close_notebook"
        },
        {
            "nb_list", "nb_open", "nb_outline", "nb_cells", "nb_find", "nb_selection", "nb_edit", "nb_set", "nb_insert",
            "nb_delete", "nb_show", "nb_close"
        },
        ConstantArray[ True, 12 ]
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Registration"
]

(* The Simple tool method matches a command after "/" without a word boundary, so no default tool's command may start
   with another one's (or be the same) *)
VerificationTest[
    Select[
        Permutations[ Wolfram`Chatbook`Common`toolShortName /@ Values @ Wolfram`Chatbook`$DefaultTools, { 2 } ],
        StringStartsQ[ #[[ 1 ]], #[[ 2 ]] ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ShortNames"
]

VerificationTest[
    Map[ #[ "Data" ][ "DisplayName" ] &, Values @ $nbtTools ],
    {
        "List Notebooks", "Open Notebook", "Get Outline", "Read Cells", "Search Notebook", "Get Selection", "Edit In Cell",
        "Set Cells", "Insert Cells", "Delete Cells", "Show Changes", "Close Notebook"
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-DisplayNames"
]

(* The services get the tools' JSON schemas; edits and new cells are arrays of objects *)
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
            "GetSelection"   -> { "object", { "notebook" }, { "notebook" } },
            "EditInCell"     -> { "object", { "notebook", "cell", "edits", "evaluate" }, { "notebook", "cell", "edits" } },
            "SetCells"       -> { "object", { "notebook", "cells", "delete", "evaluate" }, { "notebook", "cells" } },
            "InsertCells"    -> { "object", { "notebook", "newCells", "cell", "position", "evaluate" }, { "notebook", "newCells" } },
            "DeleteCells"    -> { "object", { "notebook", "cells" }, { "notebook", "cells" } },
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
        { "style", "text", "tags" },
        "boolean"
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Schemas"
]

(* The workflow is in OpenNotebook's description; no description has private-use characters *)
VerificationTest[
    {
        StringContainsQ[ $nbtTools[ "OpenNotebook" ][ "Description" ], Wolfram`Chatbook`Tools`NotebookTools`Private`$notebookWorkflow ],
        StringContainsQ[ Wolfram`Chatbook`Tools`NotebookTools`Private`$notebookWorkflow, "OpenNotebook" ~~ __ ~~ "SetCells" ~~ __ ~~ "ShowChanges" ],
        StringContainsQ[ Wolfram`Chatbook`Tools`NotebookTools`Private`$notebookNotation, "(* ::Style:: #id *)" ],
        StringContainsQ[ Wolfram`Chatbook`Tools`NotebookTools`Private`$notebookNotation, "\\[Name]" ],
        AllTrue[ $nbtTools, StringFreeQ[ #[ "Description" ], RegularExpression[ "[\\x{E000}-\\x{F8FF}]" ] ] & ]
    },
    { True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Descriptions"
]

(* Every request of a sidebar or Notebook Assistant chat carries the tools' descriptions and parameter help (see the
   performance rules in AGENTS.md): their total size stays bounded (about 7490 characters when this test was written:
   4867 of descriptions and 2620 of parameter help), and the texts the model needs only once it edits a notebook (the
   cell text notation and the editing guide) are in OpenNotebook's result instead *)
VerificationTest[
    Module[ { descriptions, help },
        descriptions = #[ "Description" ] & /@ Values @ $nbtTools;
        help = Cases[ #[ "Data" ][ "Parameters" ] & /@ Values @ $nbtTools, KeyValuePattern[ "Help" -> h_String ] :> h, Infinity ];
        {
            Total @ StringLength @ descriptions + Total @ StringLength @ help,
            Select[
                descriptions,
                StringContainsQ[ #, "Cell text notation" | "Math is typeset" | Wolfram`Chatbook`Tools`NotebookTools`Private`$notebookEditingGuide ] &
            ]
        }
    ],
    { _Integer? (LessEqualThan[ 7800 ]), { } },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-PromptSize"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Gating*)

(* Not supported without a front end, even where everything else would be (a kernel of 16.0+ outside the cloud, made up
   here), and then no front end is probed *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Tools`NotebookTools`Private`frontEndPacketsQ,
            $nbtProbes = 0,
            $FrontEnd = Null,
            $CloudEvaluation = False,
            Wolfram`Chatbook`Common`sufficientVersionQ = (16.0 >= # &)
        },
        Wolfram`Chatbook`Tools`NotebookTools`Private`frontEndPacketsQ[ ] := ($nbtProbes++; True);
        { Wolfram`Chatbook`Tools`NotebookTools`notebookToolsSupportedQ[ ], $nbtProbes }
    ],
    { False, 0 },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Gating-NoFrontEnd"
]

(* With a front end (UsingFrontEnd's; $FrontEnd can only be a real one): supported in a kernel of 16.0+ (made up here)
   outside the cloud where the front end has the packets (made up here, so the front end is never called); the packets
   are not probed when an earlier condition fails. On this kernel, it depends on the kernel's version. *)
VerificationTest[
    nbtWithFE @ Block[ { Wolfram`Chatbook`Tools`NotebookTools`Private`frontEndPacketsQ, $nbtProbes = 0 },
        Wolfram`Chatbook`Tools`NotebookTools`Private`frontEndPacketsQ[ ] := ($nbtProbes++; $nbtPackets);
        Module[ { supported, all, noPackets, inCloud, version15, probes },
            supported[ cloud_, version_, packets_ ] := Block[
                {
                    $CloudEvaluation = cloud,
                    Wolfram`Chatbook`Common`sufficientVersionQ = (version >= # &),
                    $nbtPackets = packets
                },
                Wolfram`Chatbook`Tools`NotebookTools`notebookToolsSupportedQ[ ]
            ];
            all       = supported[ False, 16.0, True ];
            noPackets = supported[ False, 16.0, False ];
            probes    = $nbtProbes;
            inCloud   = supported[ True, 16.0, True ];
            version15 = supported[ False, 15.0, True ];
            {
                MatchQ[ $FrontEnd, _FrontEndObject ],
                all,
                noPackets,
                probes,
                { inCloud, version15 },
                $nbtProbes,
                Block[ { $CloudEvaluation = False, $nbtPackets = True }, Wolfram`Chatbook`Tools`NotebookTools`notebookToolsSupportedQ[ ] ] ===
                    TrueQ[ $VersionNumber >= 16 ]
            }
        ]
    ],
    Missing[ "TestSkipped" ] | { True, True, False, 2, { False, False }, 2, True },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Gating-SupportedQ"
]

(* The tools are enabled only in the sidebar and the Notebook Assistant window, and only where they are supported;
   in other chats the support isn't checked at all (that would call the front end) *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Tools`NotebookTools`notebookToolsSupportedQ },
        Wolfram`Chatbook`Tools`NotebookTools`notebookToolsSupportedQ[ ] := ($nbtChecks++; $nbtSupported);
        Module[ { enabled },
            enabled[ workspace_, sidebar_, supported_ ] := Block[
                {
                    Wolfram`Chatbook`$WorkspaceChat = workspace,
                    Wolfram`Chatbook`$SidebarChat   = sidebar,
                    $nbtSupported                   = supported,
                    $nbtChecks                      = 0
                },
                { Union[ #[ "Data" ][ "Enabled" ] & /@ Values @ $nbtTools ], $nbtChecks }
            ];
            {
                enabled[ True, False, True ],
                enabled[ False, True, True ],
                enabled[ True, True, True ],
                enabled[ False, False, True ],
                enabled[ False, True, False ]
            }
        ]
    ],
    { { { True }, 12 }, { { True }, 12 }, { { True }, 12 }, { { False }, 0 }, { { False }, 12 } },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Gating-Enabled"
]

(* The front end is probed once per session, and never while the MX file is built (whose saved value it would be) *)
VerificationTest[
    Internal`InheritedBlock[ { Wolfram`Chatbook`Tools`NotebookTools`Private`frontEndPacketsQ },
        Block[ { Wolfram`Chatbook`Tools`NotebookTools`Private`frontEndPacketsProbe, $nbtProbes = 0 },
            Wolfram`Chatbook`Tools`NotebookTools`Private`frontEndPacketsProbe[ ] := ($nbtProbes++; True);
            If[ FreeQ[ DownValues @ Wolfram`Chatbook`Tools`NotebookTools`Private`frontEndPacketsQ, Wolfram`Chatbook`Tools`NotebookTools`Private`frontEndPacketsProbe ],
                (* already probed in this session *)
                Missing[ "TestSkipped" ],
                {
                    Block[ { Wolfram`ChatbookInternal`$BuildingMX = True }, Wolfram`Chatbook`Tools`NotebookTools`Private`frontEndPacketsQ[ ] ],
                    $nbtProbes,
                    Wolfram`Chatbook`Tools`NotebookTools`Private`frontEndPacketsQ[ ],
                    Wolfram`Chatbook`Tools`NotebookTools`Private`frontEndPacketsQ[ ],
                    $nbtProbes
                }
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | { False, 0, True, True, 1 },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Gating-ProbeOnce"
]

(* A front end without the packets (the stock front ends of 15.0 and 16.0) answers the probe with Null: False; a front
   end with them gives True. Either way, without a message in the Messages window and with the session's console
   message setting as it was *)
VerificationTest[
    nbtWithFE @ Module[ { cells, action, result },
        cells  = Length @ Cells @ MessagesNotebook[ ];
        action = CurrentValue[ $FrontEndSession, { MessageOptions, "ConsoleMessageAction" } ];
        result = Wolfram`Chatbook`Tools`NotebookTools`Private`frontEndPacketsProbe[ ];
        {
            result,
            Length @ Cells @ MessagesNotebook[ ] - cells,
            CurrentValue[ $FrontEndSession, { MessageOptions, "ConsoleMessageAction" } ] === action
        }
    ],
    Missing[ "TestSkipped" ] | { True | False, 0, True },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Gating-FrontEndProbe"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Identifiers*)
VerificationTest[
    Wolfram`Chatbook`Tools`NotebookTools`Private`uniqueIDs[
        { "abcdef0123456789", "abcdef0199999999", "12345678zzzz", "abc", "same-key-1", "same-key-1" }
    ],
    { "abcdef012", "abcdef019", "12345678", "abc", "same-key-1", "same-key-1" },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-UniqueIDs"
]

VerificationTest[
    Wolfram`Chatbook`Tools`NotebookTools`Private`uniqueIDs[ { } ],
    { },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-UniqueIDs-Empty"
]

(* Objects that share a UUID get their instance UUID too *)
VerificationTest[
    Wolfram`Chatbook`Tools`NotebookTools`Private`objectKeys @ {
        CellObject[ "ABCDEF01-1", "Inst-1" ],
        CellObject[ "abcdef01-1", "inst-2" ],
        CellObject[ "abcdef01-2", "inst-3" ],
        NotebookObject[ "FEDCBA98-0", "inst-4" ]
    },
    { "abcdef01-1.inst-1", "abcdef01-1.inst-2", "abcdef01-2", "fedcba98-0" },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ObjectKeys"
]

(* Help pages and the Messages window are not listed (deployed notebooks are left out separately, see
   NotebookTools-ListNotebooks-Excluded) *)
VerificationTest[
    Wolfram`Chatbook`Tools`NotebookTools`Private`listedNotebookQ[ #, NotebookObject[ "messages", "1" ] ] & /@ {
        <| "Included" -> True , "DocumentType" -> "Notebook", "NotebookObject" -> NotebookObject[ "a", "1" ] |>,
        <| "Included" -> False, "DocumentType" -> "Notebook", "NotebookObject" -> NotebookObject[ "b", "1" ] |>,
        <| "Included" -> True , "DocumentType" -> "Help"    , "NotebookObject" -> NotebookObject[ "c", "1" ] |>,
        <| "Included" -> True , "DocumentType" -> "Notebook", "NotebookObject" -> NotebookObject[ "messages", "1" ] |>
    },
    { True, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ListedNotebookQ"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Resolution*)

(* By id, a start of at least 6 characters, the whole UUID (any case, with quotes), the exact window title or the file *)
VerificationTest[
    nbtResult[ Wolfram`Chatbook`Tools`NotebookTools`Private`resolveNotebook[ $nbtEntries, # ][ "ID" ] ] & /@ {
        "abcdef11",
        "abcdef1",
        "  'ABCDEF11-0000-4000-8000-000000000001' ",
        "123456",
        "One",
        "/tmp/one.nb"
    },
    { "abcdef11", "abcdef11", "abcdef11", "12345678", "abcdef11", "abcdef11" },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ResolveNotebook"
]

VerificationTest[
    nbtResult[ Wolfram`Chatbook`Tools`NotebookTools`Private`resolveNotebook[ $nbtEntries, # ][ "ID" ] ] & /@ {
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
    TestID   -> "NotebookTools-ResolveNotebook-Errors"
]

(* Snapshot handles in any case, with quotes; an unknown handle names the open snapshots *)
VerificationTest[
    withFakeFE @ Module[ { none, open },
        none = nbtResult @ Wolfram`Chatbook`Tools`NotebookTools`Private`resolveSnapshot[ "s1" ];
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        open = nbtResult @ Wolfram`Chatbook`Tools`NotebookTools`Private`resolveSnapshot @ # & /@ { "s1", " 'S1' ", "s2", "abcdef11", "" };
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
    TestID   -> "NotebookTools-ResolveSnapshot"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Arguments*)
VerificationTest[
    nbtResult @ Wolfram`Chatbook`Tools`NotebookTools`Private`cellIDsArgument[ #, "cells" ] & /@ {
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
    TestID   -> "NotebookTools-CellIDsArgument"
]

VerificationTest[
    nbtResult @ Wolfram`Chatbook`Tools`NotebookTools`Private`countArgument[ #, "offset", 1 ] & /@ {
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
    TestID   -> "NotebookTools-CountArgument"
]

VerificationTest[
    nbtResult @ Wolfram`Chatbook`Tools`NotebookTools`Private`positionArgument @ # & /@ {
        Missing[ "NoInput" ], "", " BEFORE ", "after", "middle"
    },
    { "After", "After", "Before", "After", "The parameter position must be \"after\" or \"before\", not \"middle\"." },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-PositionArgument"
]

VerificationTest[
    {
        nbtResult @ Wolfram`Chatbook`Tools`NotebookTools`Private`booleanArgument[ #, "regex", False ] & /@ {
            Missing[ "NoInput" ], True, False, "true", " FALSE ", "yes", 1
        },
        Wolfram`Chatbook`Tools`NotebookTools`Private`stylesArgument /@ { Missing[ "NoInput" ], "", "Input, Text", "[\"Input\"]" },
        Wolfram`Chatbook`Tools`NotebookTools`Private`styleArgument[ #, "style" ] & /@ { Missing[ "NoInput" ], " ", " Text " },
        Wolfram`Chatbook`Tools`NotebookTools`Private`cellID /@ { "c3", "#c3", " C3 ", "3", "'#c12'" }
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
    TestID   -> "NotebookTools-OtherArguments"
]

(* Every edit needs oldText (not empty) and newText; count is 1 if it is not given; no marker lines; nothing that runs
   code in newText *)
VerificationTest[
    nbtResult @ Wolfram`Chatbook`Tools`NotebookTools`Private`editsArgument @ # & /@ {
        { <| "oldText" -> "a", "newText" -> "b", "count" -> Missing[ "NoInput" ] |>, <| "oldText" -> "c", "newText" -> "", "count" -> 2 |> },
        { <| "oldText" -> "a", "newText" -> Missing[ "NoInput" ] |> },
        { <| "oldText" -> "a", "newText" -> "b" |>, <| "newText" -> "b" |> },
        { <| "oldText" -> "", "newText" -> "b" |> },
        { <| "oldText" -> "a", "newText" -> "b", "count" -> 0 |> },
        { <| "oldText" -> "x\n(* ::Input:: #c4 *)\ny", "newText" -> "z" |> },
        { <| "oldText" -> "a", "newText" -> "\:3014DynamicBox[ToBoxes[CreateFile[\"x\"]]]\:3015" |> },
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
    TestID   -> "NotebookTools-EditsArgument"
]

VerificationTest[
    nbtResult @ Wolfram`Chatbook`Tools`NotebookTools`Private`newCellsArgument @ # & /@ {
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
    TestID   -> "NotebookTools-NewCellsArgument"
]

(* Model text that would run code when it is shown is refused: linear syntax (its characters, their escapes, \! and \*
   that are not themselves escaped) anywhere, dynamic boxes and code options inside a box wrapper, an inline formula's
   \:3014$boxes\:3015 included. Code typed in a code cell, names in strings, placeholders and escaped backslashes are
   fine. *)
VerificationTest[
    {
        nbtResult[ Wolfram`Chatbook`Tools`NotebookTools`Private`requireInertText[ #, "The text" ]; "OK" ] & /@ {
            "Dynamic[x] + DynamicModule[{a}, a]",
            "\:3014FE`ElidedBox[1, \"DynamicBox\", 120]\:3015",
            "\:3014StyleBox[\"Dynamic[x] and Initialization :> f\", FontSlant -> \"Italic\"]\:3015",
            "StringReplace[s, \"\\\\!\" -> \"\"]",
            "x\:02c42 + \:3014SqrtBox[\"a\"]\:3015 \\[Rule] b",
            "(*see \\\\! here*)",
            "(*the momentum \:3014$\"p\"\:3015 and \:3014$SuperscriptBox[\"q\", \"2\"]\:3015*)",
            "\:3014StyleBox[\"x\", Rule[FontSlant, \"Italic\"]]\:3015"
        },
        nbtResult[ Wolfram`Chatbook`Tools`NotebookTools`Private`requireInertText[ #, "The text" ]; "OK" ] & /@ {
            "a" <> FromCharacterCode[ 63425 ] <> "b",
            "\"\\!\\(\\*RowBox[{CreateFile[\\\"x\\\"]}]\\)\"",
            "a \\:f7c1 b",
            "\:3014DynamicModuleBox[{}, \"x\"]\:3015",
            "\:3014ButtonBox[\"x\", ButtonFunction :> CreateFile[\"x\"]]\:3015",
            "\:3014Cell[\"x\", \"Text\", CellDynamicExpression \\[RuleDelayed] f]\:3015",
            "\:3014TemplateBox[{\"x\"}, \"T\", InterpretationFunction -> (f &)]\:3015",
            "(*an inline formula \:3014$DynamicBox[CreateFile[\"x\"]]\:3015*)",
            "\:3014ButtonBox[\"x\", RuleDelayed[ButtonFunction, CreateFile[\"x\"]]]\:3015",
            "\:3014Cell[\"x\", \"Text\", Rule[ CellProlog , f]]\:3015"
        }
    },
    {
        { "OK", "OK", "OK", "OK", "OK", "OK", "OK", "OK" },
        {
            "The text has linear syntax (\"\\:f7c1\"), which would run code when it is shown; the notebook tools never write it.",
            "The text has linear syntax (\"\\!\"), which would run code when it is shown; the notebook tools never write it.",
            "The text has linear syntax (\"\\:f7c1\"), which would run code when it is shown; the notebook tools never write it.",
            "The text has content that would run code when it is shown (DynamicModuleBox), which the notebook tools never write.",
            "The text has content that would run code when it is shown (ButtonFunction), which the notebook tools never write.",
            "The text has content that would run code when it is shown (CellDynamicExpression), which the notebook tools never write.",
            "The text has content that would run code when it is shown (InterpretationFunction), which the notebook tools never write.",
            "The text has content that would run code when it is shown (DynamicBox), which the notebook tools never write.",
            "The text has content that would run code when it is shown (ButtonFunction), which the notebook tools never write.",
            "The text has content that would run code when it is shown (CellProlog), which the notebook tools never write."
        }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-InertText"
]

(* Box wrappers hold boxes and plain data only (requireDataWrappers): option values with other heads or symbols are
   refused, also inside nested wrappers; hyperlinks, styles, templates, colors, inline cells, placeholders and literal
   strings are fine. The check makes no symbols. *)
VerificationTest[
    Module[ { names, ok, refused },
        names = Names[ "Wolfram`Chatbook`Tools`NotebookTools`Data`*" ];
        ok = nbtResult[ Wolfram`Chatbook`Tools`NotebookTools`Private`requireInertText[ #, "The text" ]; "OK" ] & /@ {
            "(*see \:3014ButtonBox[\"the docs\", BaseStyle->\"Hyperlink\", ButtonData->{URL[\"https://example.com\"], None}]\:3015*)",
            "(*\:3014ButtonBox[\"above\", BaseStyle->\"Hyperlink\", ButtonData->\"laguerre\"]\:3015*)",
            "(*\:3014StyleBox[\"bold\", FontWeight->\"Bold\", FontColor->RGBColor[1, 0, 0], TaggingRules-><|\"a\"->1|>]\:3015*)",
            "(*\:3014StyleBox[\"code\", \"InlineCode\"]\:3015 and \:3014\"*)\"\:3015*)",
            "\:3014FormBox[TemplateBox[{\"n\", \"x\"}, \"BesselJ\"], TraditionalForm]\:3015",
            "\:3014FE`ElidedBox[1, \"GraphicsBox\", 120]\:3015",
            "(*\:3014$GridBox[{{Cell[TextData[{\" \", Cell[BoxData[\"a\"], \"InlineFormula\"]}]]}}]\:3015*)"
        };
        refused = nbtResult[ Wolfram`Chatbook`Tools`NotebookTools`Private`requireInertText[ #, "The text" ]; "OK" ] & /@ {
            "x = \:3014StyleBox[\"1\", TaggingRules->{CreateFile[\"x\"]}]\:3015",
            "(*\:3014ButtonBox[\"here\", BaseStyle->\"Hyperlink\", ButtonData->{CreateFile[\"x\"], None}]\:3015*)",
            "\:3014TemplateBox[{\"x\"}, \"T\", DisplayFunction->(RowBox[{#1}]&)]\:3015",
            "\:3014InterpretationBox[\"1\", CreateFile[\"x\"]]\:3015",
            "\:3014StyleBox[\"x\", TaggingRules->{myValue}]\:3015",
            "(*\:3014StyleBox[\"a\", \:3014StyleBox[\"b\", TaggingRules->{CreateFile[\"x\"]}]\:3015]\:3015*)",
            "\:3014RowBox[{\"x\", \"+\"\:3015"
        };
        {
            ok,
            StringStartsQ[ #, "The text has a box wrapper that is not boxes and plain data" ] & /@ refused,
            Names[ "Wolfram`Chatbook`Tools`NotebookTools`Data`*" ] === names
        }
    ],
    { ConstantArray[ "OK", 7 ], ConstantArray[ True, 7 ], True },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-InertText-DataWrappers"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Snapshots*)

(* OpenNotebook snapshots a listed notebook (by id, title or file), records it, and gives the JSON, then how to edit
   and write cell text, then its cells as ReadCells shows them, from the read that numbers them; a notebook that has an
   open snapshot gives that one again *)
VerificationTest[
    withFakeFE @ Module[ { first, again, record },
        first  = nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        again  = nbtJSON @ nbtCall[ "OpenNotebook", <| "notebook" -> "Hamiltonian Mechanics" |> ];
        record = Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots[ "s1" ];
        {
            nbtJSON @ first,
            first === StringJoin[
                First @ StringSplit[ first, "\n\n", 2 ],
                "\n\n", Wolfram`Chatbook`Tools`NotebookTools`Private`$notebookEditingGuide,
                "\n\n", Wolfram`Chatbook`Tools`NotebookTools`Private`$notebookNotation,
                "\n\nIts cells, as ReadCells shows them:\n", nbtCall[ "ReadCells", <| "notebook" -> "s1" |> ]
            ],
            again,
            Keys @ Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots,
            KeyDrop[ record, "IDs" ],
            Values @ record[ "IDs" ],
            $fakeCalls[[ 1 ;; 3 ]]
        }
    ],
    {
        <| "notebook" -> "s1", "title" -> "Hamiltonian Mechanics", "source" -> "abcdef11", "cells" -> 7 |>,
        True,
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
            "Unsaved"  -> False,
            "Chat"     -> None
        |>,
        { "c1", "c2", "c3", "c4", "c5", "c6", "c7" },
        {
            { "Snapshot", NotebookObject[ "fake-source-1" ] },
            { "FileName", NotebookObject[ "fake-snapshot-1" ] },
            { "CellText", NotebookObject[ "fake-snapshot-1" ], All, All, True }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-OpenNotebook"
]

(* The editing guide and the cell text notation come once in every OpenNotebook result, after the JSON (a reopened
   snapshot, a new empty notebook, a notebook too long to show whole), and in no other tool's result *)
VerificationTest[
    withFakeFE @ Block[
        {
            $fakeSources = <|
                $fakeSources,
                NotebookObject[ "fake-source-2" ] -> Prepend[
                    Table[ fakeCell[ "long-" <> ToString @ i, "Text", "(*" <> StringRepeat[ "x", 100 ] <> "*)", 1 ], { i, 499 } ],
                    fakeCell[ "long-0", "Section", "(*Long*)", 0 ]
                ]
            |>
        },
        Module[ { results, once },
            results = {
                nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ],
                nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ],
                nbtCall[ "OpenNotebook", <| |> ],
                nbtCall[ "OpenNotebook", <| "notebook" -> "12345678" |> ]
            };
            once[ text_String ] := {
                StringCount[ text, Wolfram`Chatbook`Tools`NotebookTools`Private`$notebookEditingGuide ],
                StringCount[ text, Wolfram`Chatbook`Tools`NotebookTools`Private`$notebookNotation ],
                StringStartsQ[
                    StringDrop[ text, StringLength @ First @ StringSplit[ text, "\n\n", 2 ] ],
                    "\n\n" <> Wolfram`Chatbook`Tools`NotebookTools`Private`$notebookEditingGuide <> "\n\n" <> Wolfram`Chatbook`Tools`NotebookTools`Private`$notebookNotation
                ]
            };
            {
                once /@ results,
                StringContainsQ[ results[[ 4 ]], "It is too long to show whole (500 cells)" ],
                StringFreeQ[
                    StringJoin[
                        nbtCall[ "ReadCells", <| "notebook" -> "s1" |> ],
                        nbtCall[ "GetOutline", <| "notebook" -> "s1" |> ],
                        nbtCall[ "ListNotebooks", <| |> ]
                    ],
                    "Cell text notation"
                ]
            }
        ]
    ],
    { ConstantArray[ { 1, 1, True }, 4 ], True, True },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-OpenNotebook-Instructions"
]

(* A notebook too long to show whole that has no heading cells still opens: its outline is one range, from the first
   cell, whose content is cut to $previewLength characters however long it is *)
VerificationTest[
    withFakeFE @ Block[
        {
            $fakeSources = <|
                NotebookObject[ "fake-source-2" ] -> Prepend[
                    Table[ fakeCell[ "long-" <> ToString @ i, "Input", "x" <> ToString @ i <> " = " <> StringRepeat[ "1", 100 ], 0 ], { i, 499 } ],
                    fakeCell[ "long-0", "Input", "data = {" <> StringRepeat[ "1, ", 30000 ] <> "1}", 0 ]
                ]
            |>
        },
        Module[ { text },
            text = nbtText @ nbtCall[ "OpenNotebook", <| "notebook" -> "12345678" |> ];
            {
                StringContainsQ[ text, "It is too long to show whole (500 cells)" ],
                StringContainsQ[ text, "#c1-#c500 (Input) data = {1, 1, " ],
                StringLength @ text < 10000
            }
        ]
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-OpenNotebook-OutlineWithoutHeadings"
]

(* A .nb file that is not open, a new empty notebook (no notebook, or an empty one), and what can't be opened *)
VerificationTest[
    withFakeFE @ Module[ { file, other, results },
        file  = FileNameJoin @ { $TemporaryDirectory, "nbt-" <> $nbtTag <> " File.nb" };
        other = FileNameJoin @ { $TemporaryDirectory, "nbt-" <> $nbtTag <> ".txt" };
        Put[ Notebook @ { }, file ];
        Put[ "x", other ];
        results = {
            nbtJSON @ nbtCall[ "OpenNotebook", <| "notebook" -> " \"" <> file <> "\" " |> ],
            nbtJSON @ nbtCall[ "OpenNotebook", <| |> ],
            nbtJSON @ nbtCall[ "OpenNotebook", <| "notebook" -> "" |> ],
            nbtText @ nbtCall[ "OpenNotebook", <| "notebook" -> other |> ],
            nbtText @ nbtCall[ "OpenNotebook", <| "notebook" -> "fail" |> ],
            Cases[ $fakeCalls, { "Snapshot", s_ } :> s ]
        };
        Quiet[ DeleteFile /@ { file, other } ];
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
    TestID   -> "NotebookTools-OpenNotebook-FileAndNew"
]

(* A snapshot that the front end can't make is not recorded *)
VerificationTest[
    withFakeFE @ Block[ { $fakeListed = { <| First @ $fakeListed, "NotebookObject" -> "fail" |> } },
        {
            nbtText @ nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ],
            Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots
        }
    ],
    { "The front end could not make a snapshot of \"Hamiltonian Mechanics\".", <| |> },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-OpenNotebook-Failed"
]

(* At most ten snapshots are open: the eleventh is refused before the front end makes it, a notebook with an open
   snapshot still gives that one, and closing one makes room *)
VerificationTest[
    withFakeFE @ Module[ { capped, snapshotsMade, again, reopened },
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        Do[ nbtCall[ "OpenNotebook", <| |> ], 9 ];
        capped        = nbtText @ nbtCall[ "OpenNotebook", <| "notebook" -> "12345678" |> ];
        snapshotsMade = Count[ $fakeCalls, { "Snapshot", _ } ];
        again         = nbtJSON @ nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        nbtCall[ "CloseNotebook", <| "notebook" -> "s2" |> ];
        reopened = nbtJSON @ nbtCall[ "OpenNotebook", <| "notebook" -> "12345678" |> ];
        {
            capped,
            snapshotsMade,
            Lookup[ again, { "notebook", "note" } ],
            reopened[ "notebook" ],
            Length @ Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots
        }
    ],
    {
        StringJoin[
            "10 snapshots are open already, the most there can be: s1 (\"Hamiltonian Mechanics\"), ",
            StringRiffle[ Table[ "s" <> ToString @ i <> " (\"Untitled\")", { i, 2, 10 } ], ", " ],
            ". Show the changes of one with ShowChanges, or close one with CloseNotebook, before opening another."
        ],
        10,
        { "s1", _String },
        "s11",
        10
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-SnapshotCap"
]

(* A snapshot belongs to the chat that opened it: a later chat doesn't see it, OpenNotebook of the same notebook there
   discards it and makes a new one, and when too many are open, the oldest snapshot of an earlier chat makes room *)
VerificationTest[
    withFakeFE @ Module[ { inChat, first, seenLater, reopened, capped },
        inChat[ id_, eval_ ] := Block[ { Wolfram`Chatbook`$ChatHandlerData = <| "ChatNotebookSettings" -> <| "ConversationUUID" -> id |> |> }, eval ];
        inChat // Attributes = { HoldRest };
        first = inChat[ "chat-a",
            nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
            nbtCall[ "EditInCell", <| "notebook" -> "s1", "cell" -> "c4", "edits" -> { <| "oldText" -> "Cos", "newText" -> "Sin" |> } |> ]
        ];
        seenLater = inChat[ "chat-b",
            {
                nbtText @ nbtCall[ "ReadCells", <| "notebook" -> "s1" |> ],
                nbtJSON[ nbtCall[ "ListNotebooks", <| |> ] ][ "snapshots" ]
            }
        ];
        reopened = inChat[ "chat-b", nbtJSON @ nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ] ];
        inChat[ "chat-c", Do[ nbtCall[ "OpenNotebook", <| |> ], 9 ] ];
        capped = inChat[ "chat-d", nbtJSON @ nbtCall[ "OpenNotebook", <| "notebook" -> "12345678" |> ] ];
        {
            StringQ @ first,
            seenLater,
            Lookup[ reopened, { "notebook", "note" } ],
            Keys @ Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots[[ { 1, -1 } ]],
            capped[ "notebook" ],
            Length @ Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots,
            KeyExistsQ[ Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots, "s2" ]
        }
    ],
    {
        True,
        { _String? (StringStartsQ[ "\"s1\" is not an open snapshot. Open the notebook with OpenNotebook first" ]), { } },
        { "s2", Missing[ "KeyAbsent", "note" ] },
        { "s3", "s12" },
        "s12",
        10,
        False
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ChatSnapshots"
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
    TestID   -> "NotebookTools-ListNotebooks-Snapshots"
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
                "    \:3014FE`ElidedBox[1, \"Graphi\[Ellipsis]",
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
        { { All, True }, { 24, True }, { 80, True }, { 80, True } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-GetOutline"
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
            Block[ { Wolfram`Chatbook`Tools`NotebookTools`Private`$readBudget = 100 },
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
        "(* ::Title:: #c1 *)\n(*Hamiltonian Mechanics*)\n(* ::Section:: #c2 *)\n(*The simple pendulum*)\n[Not shown: #c3 and the 4 cells after it (a result has at most 100 characters). Read them with ReadCells and cells.]",
        "s1 has no cell \"c99\". Cell ids come from OpenNotebook, GetOutline, ReadCells and SearchNotebook.",
        { { 0, True }, { 2, True }, { 0, True }, { 1, False }, { 0, True } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ReadCells"
]

(* A notebook too long to show whole: OpenNotebook gives an outline of its headings with the range of cells under each,
   from the same read *)
VerificationTest[
    withFakeFE @ Block[ { Wolfram`Chatbook`Tools`NotebookTools`Private`$readBudget = 60 },
        {
            nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ],
            Cases[ $fakeCalls, { "CellText", __ } ]
        }
    ],
    {
        StringJoin[
            "{\"notebook\":\"s1\",\"title\":\"Hamiltonian Mechanics\",\"source\":\"abcdef11\",\"cells\":7}",
            "\n\n", Wolfram`Chatbook`Tools`NotebookTools`Private`$notebookEditingGuide,
            "\n\n", Wolfram`Chatbook`Tools`NotebookTools`Private`$notebookNotation,
            "\n\nIt is too long to show whole (7 cells). Its headings, each with the range of cells under it:\n#c1 \
(Title) Hamiltonian Mechanics\n#c2-#c5 (Section) The simple pendulum\n#c6-#c7 (Section) Equations of motion\nRead the \
sections you change with ReadCells, giving their ranges (e.g. cells \"c12-c40, c90-c120\"), or find cells with \
SearchNotebook."
        ],
        { { "CellText", NotebookObject[ "fake-snapshot-1" ], All, All, True } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-OpenNotebook-Outline"
]

(* Ranges of cell ids, as the outline gives them: the cells numbered so, in the order of their numbers; spaces around
   the dash are fine *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            StringCases[ nbtCall[ "ReadCells", <| "notebook" -> "s1", "cells" -> "c5 - c7, 2" |> ], "#c" ~~ DigitCharacter.. ],
            StringCases[ nbtCall[ "ReadCells", <| "notebook" -> "s1", "cells" -> "#c3-#c4" |> ], "#c" ~~ DigitCharacter.. ],
            nbtText @ nbtCall[ "ReadCells", <| "notebook" -> "s1", "cells" -> "c20-c30" |> ],
            nbtCall[ "DeleteCells", <| "notebook" -> "s1", "cells" -> "c6-c7" |> ]
        }
    ),
    {
        { "#c5", "#c6", "#c7", "#c2" },
        { "#c3", "#c4" },
        "s1 has no cells numbered 20 to 30.",
        "Deleted 2 cells (#c6, #c7) from s1."
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-CellRanges"
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
    TestID   -> "NotebookTools-SearchNotebook"
]

(* Search details: matches on later lines of a cell, long lines shortened around the match, more matches than the
   limit *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            nbtCall[ "SearchNotebook", <| "notebook" -> "s1", "query" -> "NDSolve" |> ],
            nbtCall[ "SearchNotebook", <| "notebook" -> "s1", "query" -> "e", "limit" -> 2 |> ],
            Block[ { Wolfram`Chatbook`Tools`NotebookTools`Private`$snippetLength = 12 },
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
    TestID   -> "NotebookTools-SearchNotebook-Lines"
]

(* The user's selection in the snapshot's ids: none; cells, consecutive ones as ranges, and one the snapshot doesn't
   have; an insertion point; text and a cursor in a cell, marked in its text with its marker line, and a note when the
   snapshot's copy of the cell has changed; a front end that can't read it; a new notebook, which has no selection *)
VerificationTest[
    withFakeFE @ Module[ { selection },
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        selection[ spec_ ] := Block[ { $fakeSelection = spec }, nbtText @ nbtCall[ "GetSelection", <| "notebook" -> "s1" |> ] ];
        {
            selection @ <| "Type" -> "None", "Cells" -> { } |>,
            selection @ <| "Type" -> "Cells", "Cells" -> { CellObject[ "fake-1-2" ], CellObject[ "fake-1-3" ], CellObject[ "fake-1-4" ], CellObject[ "fake-1-6" ] } |>,
            selection @ <| "Type" -> "Cells", "Cells" -> { CellObject[ "fake-1-3" ], None } |>,
            selection @ <| "Type" -> "InsertionPoint", "Cells" -> { CellObject[ "fake-1-4" ] }, "Position" -> "After" |>,
            selection @ <|
                "Type"  -> "Text",
                "Cells" -> { CellObject[ "fake-1-3" ] },
                "Text"  -> { "(*The Hamiltonian of a ", "pendulum", " of length l and mass m:*)" }
            |>,
            selection @ <| "Type" -> "Text", "Cells" -> { CellObject[ "fake-1-3" ] }, "Text" -> { "(*The ", "", "Hamiltonian of a pendulum of length l and mass m:*)" } |>,
            nbtCall[ "EditInCell", <| "notebook" -> "s1", "cell" -> "c3", "edits" -> { <| "oldText" -> "pendulum", "newText" -> "swing" |> } |> ];
            selection @ <|
                "Type"  -> "Text",
                "Cells" -> { CellObject[ "fake-1-3" ] },
                "Text"  -> { "(*The Hamiltonian of a ", "pendulum", " of length l and mass m:*)" }
            |>,
            selection @ $Failed,
            nbtCall[ "OpenNotebook", <| |> ];
            nbtText @ nbtCall[ "GetSelection", <| "notebook" -> "s2" |> ]
        }
    ],
    {
        "Nothing is selected in the user's notebook.",
        "The selection is 4 cells: #c2-#c4, #c6.",
        "The selection is 2 cells: #c3, a cell that s1 does not have (added after it was opened).",
        "The selection is an insertion point between cells, after #c4; InsertCells with that cell and position inserts there.",
        "The selection is text in #c3, marked <selection>...</selection> (the marks are not part of the cell):\n(* ::Text:: #c3 *)\n(*The Hamiltonian of a <selection>pendulum</selection> of length l and mass m:*)",
        "The selection is a cursor in #c3, marked <cursor/> (the marks are not part of the cell):\n(* ::Text:: #c3 *)\n(*The <cursor/>Hamiltonian of a pendulum of length l and mass m:*)",
        "The selection is text in #c3, marked <selection>...</selection> (the marks are not part of the cell):\n(* ::Text:: #c3 *)\n(*The Hamiltonian of a <selection>pendulum</selection> of length l and mass m:*)\n(This is the cell in the user's notebook; it has changed in s1, where ReadCells shows it.)",
        "The front end could not read the selection in the notebook of s1 (\"Hamiltonian Mechanics\"); it may have been closed.",
        _String? (StringContainsQ[ "was not made from a notebook that is open in the front end, so it has no selection." ])
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-GetSelection"
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
                    <| "oldText" -> "H = p\:02c42/(2 m l\:02c42)", "newText" -> "L = m l\:02c42 \:3014SuperscriptBox[OverscriptBox[\"\[Theta]\", \".\"], \"2\"]\:3015/2" |>,
                    <| "oldText" -> "- m g l Cos", "newText" -> "+ m g l Cos" |>
                }
            |>
        ];
        {
            result,
            SelectFirst[ $fakeCalls, First @ # === "Edit" & ],
            KeyTake[ Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots[ "s1" ], { "Edited", "Unsaved" } ]
        }
    ],
    {
        "Edited #c4 of s1 (2 edits). It now reads:\n(* ::Input:: #c4 *)\nL = m l\:02c42 \:3014SuperscriptBox[OverscriptBox[\"\[Theta]\", \".\"], \"2\"]\:3015/2 + m g l Cos[\[Theta]]",
        {
            "Edit",
            NotebookObject[ "fake-snapshot-1" ],
            {
                {
                    "Edit",
                    CellObject[ "fake-1-4" ],
                    {
                        { "H = p\:02c42/(2 m l\:02c42)", "L = m l\:02c42 \:3014SuperscriptBox[OverscriptBox[\"\[Theta]\", \".\"], \"2\"]\:3015/2", 1 },
                        { "- m g l Cos", "+ m g l Cos", 1 }
                    }
                }
            }
        },
        <| "Edited" -> True, "Unsaved" -> True |>
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-EditInCell"
]

(* The front end's failures reach the model with their tag, message and a hint; nothing was changed, and the snapshot
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
            Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots[ "s1", "Edited" ]
        }
    ],
    {
        {
            "NoMatch: In #c4: \"+ V[q]\" does not occur in the cell. Nothing was changed. Copy oldText exactly from the cell's current content (ReadCells), with its spaces, \:3014 \:3015 wrappers and \\[Name] characters.",
            "AmbiguousMatch: In #c4: \"l\" occurs 2 times in the cell. Nothing was changed. Make oldText longer, so that it occurs as often as count says, or give count.",
            "ParseError: In #c4: The new content of the cell does not parse. Nothing was changed. The cell's new content must parse: check brackets, quotes and \:3014 \:3015 wrappers.",
            "Edit 1 has no newText (use \"\" to delete oldText).",
            "s1 has no cell \"c99\". Cell ids come from OpenNotebook, GetOutline, ReadCells and SearchNotebook.",
            "CellNotFound: In #c3: The cell does not exist. Nothing was changed. Call GetOutline for the current cell ids."
        },
        4,
        "H = p\:02c42/(2 m l\:02c42) - m g l Cos[\[Theta]]",
        False
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-EditInCell-Failures"
]

(* A changed cell that the front end gives as another CellObject keeps its id: matched by its uuid (the packet gives
   the changed cells in document order, not in the order of the operations), or as the only one *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            Wolfram`Chatbook`Tools`NotebookTools`Private`changedCells[ "s1", { CellObject[ "fake-1-4" ] }, <| "Changed" -> { CellObject[ "fake-1-4" ] } |> ],
            Wolfram`Chatbook`Tools`NotebookTools`Private`changedCells[ "s1", { CellObject[ "fake-1-5" ], CellObject[ "fake-1-3" ] }, <| "Changed" -> { CellObject[ "fake-1-3", 2 ], CellObject[ "fake-1-5", 2 ] } |> ],
            Wolfram`Chatbook`Tools`NotebookTools`Private`changedCells[ "s1", { CellObject[ "fake-1-4" ] }, <| "Changed" -> { CellObject[ "other" ] } |> ],
            Lookup[
                Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots[ "s1", "IDs" ],
                { CellObject[ "fake-1-5", 2 ], CellObject[ "fake-1-3", 2 ], CellObject[ "other" ], CellObject[ "fake-1-4" ] }
            ]
        }
    ),
    {
        { CellObject[ "fake-1-4" ] },
        { CellObject[ "fake-1-5", 2 ], CellObject[ "fake-1-3", 2 ] },
        { CellObject[ "other" ] },
        { "c5", "c3", "c4", Missing[ "KeyAbsent", CellObject[ "fake-1-4" ] ] }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ChangedCell"
]

(* SetCells replaces the content of cells, and their styles where given, and deletes the cells of delete, in one edit
   packet; a bad item changes nothing, and a parse error names the cell and the text near it *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c4", "text" -> "L = T - V" |>, <| "cell" -> "c3", "text" -> "(*The Lagrangian:*)" |> } |> ],
            nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c3", "text" -> "(*Lagrangian*)", "style" -> "Subsection" |> } |> ],
            nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c4", "text" -> "L = T - V" |> }, "delete" -> "c5, c7" |> ],
            nbtText @ nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c3", "text" -> "(*Text*)" |>, <| "cell" -> "c4", "text" -> "Lcentral = r'[t]PARSEERROR + V[r]" |> } |> ],
            nbtCall[ "ReadCells", <| "notebook" -> "s1", "cells" -> "c3, c4" |> ],
            nbtText @ nbtCall[ "ReadCells", <| "notebook" -> "s1", "cells" -> "c5" |> ],
            nbtText @ nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c3", "text" -> "(*x*)" |>, <| "cell" -> "c4", "text" -> "(* ::Text:: #c4 *)\n(*x*)" |> } |> ],
            nbtText @ nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c3" |> } |> ],
            nbtText @ nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c99", "text" -> "(*x*)" |> } |> ],
            nbtText @ nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> "x" |> ],
            nbtCall[ "SetCells", <| "notebook" -> "s1" |> ],
            Cases[ $fakeCalls, { "Edit", _, ops_ } :> ops ]
        }
    ),
    {
        "Set 2 cells of s1: #c4, #c3. ReadCells shows their new content.",
        "Set 1 cell of s1: #c3. ReadCells shows their new content.",
        "Set 1 cell of s1: #c4; deleted #c5, #c7. ReadCells shows their new content.",
        "ParseError: In #c4 near \"central = r'[t]PARSEERROR + V[r\": The short form at character 17 has no simple token before it. Nothing was changed. The cell's new content must parse: check brackets, quotes and \:3014 \:3015 wrappers.",
        "(* ::Subsection:: #c3 *)\n(*Lagrangian*)\n(* ::Input:: #c4 *)\nL = T - V",
        "s1 has no cell \"c5\". Cell ids come from OpenNotebook, GetOutline, ReadCells and SearchNotebook.",
        "The text of item 2 includes a marker line (* ::Style:: #id *): give the content of one cell, without its marker line.",
        "Item 1 of cells has no text.",
        "s1 has no cell \"c99\". Cell ids come from OpenNotebook, GetOutline, ReadCells and SearchNotebook.",
        (* 16.0's LLMTool refuses a value of the wrong type before the tool runs, so there is no text: *)
        "The parameter cells must be a list of cells {cell, text, style, tags}, e.g. [{\"cell\": \"c3\", \"text\": \"(*New words*)\"}]." | _Missing | Failure[ "InvalidLLMToolParameter", _ ],
        _Failure, (* LLMTool refuses a call without a required parameter *)
        {
            { { "Set", CellObject[ "fake-1-4" ], Automatic, "L = T - V" }, { "Set", CellObject[ "fake-1-3" ], Automatic, "(*The Lagrangian:*)" } },
            { { "Set", CellObject[ "fake-1-3" ], "Subsection", "(*Lagrangian*)" } },
            { { "Set", CellObject[ "fake-1-4" ], Automatic, "L = T - V" }, { "Delete", { CellObject[ "fake-1-5" ], CellObject[ "fake-1-7" ] } } },
            { { "Set", CellObject[ "fake-1-3" ], Automatic, "(*Text*)" }, { "Set", CellObject[ "fake-1-4" ], Automatic, "Lcentral = r'[t]PARSEERROR + V[r]" } }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-SetCells"
]

(* LaTeX formulas in what the model writes become the boxes that the front end reads: \:3014$boxes\:3015 inline,
   \:3014FormBox[...]\:3015 for a DisplayFormula cell. The sandbox kernel reads them (made up here), each formula once
   per text, and only for texts that have formulas; the boxes are checked like the rest of the text. *)
VerificationTest[
    withFakeFE @ Block[
        {
            $texRead  = { },
            $texBoxes = <|
                "\\omega"     -> "\"\\[Omega]\"",
                "L=T-V"       -> "RowBox[{\"L\", \"=\", \"T\", \"-\", \"V\"}]",
                "\\frac{1}{2" -> None,
                "\\dot x"     -> "DynamicBox[x]"
            |>,
            Wolfram`Chatbook`Common`sandboxTeXBoxes = Function[ { texs, seconds },
                AppendTo[ $texRead, texs ];
                If[ texs === { "\\fail" }, Failure[ "TimedOut", <| |> ], Lookup[ $texBoxes, texs ] ]
            ]
        },
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> {
                <| "cell" -> "c3", "text" -> "(*the frequency \:3014tex:\\omega\:3015, again \:3014tex:\\omega\:3015*)" |>,
                <| "cell" -> "c4", "text" -> "\:3014display-tex:L=T-V\:3015", "style" -> "DisplayFormula" |>
            } |> ],
            nbtCall[ "InsertCells", <| "notebook" -> "s1", "newCells" -> { <| "style" -> "Text", "text" -> "(*no formulas*)" |> } |> ],
            nbtText @ nbtCall[ "EditInCell", <| "notebook" -> "s1", "cell" -> "c3", "edits" -> {
                <| "oldText" -> "again", "newText" -> "\:3014tex:\\frac{1}{2\:3015" |>
            } |> ],
            nbtText @ nbtCall[ "InsertCells", <| "notebook" -> "s1", "newCells" -> { <| "style" -> "Text", "text" -> "(*\:3014tex:\\dot x\:3015*)" |> } |> ],
            nbtText @ nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c3", "text" -> "(*\:3014tex:\\fail\:3015*)" |> } |> ],
            Cases[ $fakeCalls, { "Edit", _, ops_ } :> ops ],
            $texRead
        }
    ],
    {
        "Set 2 cells of s1: #c3, #c4. ReadCells shows their new content.",
        _String,
        "The newText of edit 1 has a formula that is not LaTeX math the tools can read: \"\\frac{1}{2\".",
        "The text of new cell 1 has content that would run code when it is shown (DynamicBox), which the notebook tools never write.",
        "The text of item 1 has LaTeX formulas that could not be read now (TimedOut). Write them as boxes instead.",
        {
            {
                { "Set", CellObject[ "fake-1-3" ], Automatic, "(*the frequency \:3014$\"\\[Omega]\"\:3015, again \:3014$\"\\[Omega]\"\:3015*)" },
                { "Set", CellObject[ "fake-1-4" ], "DisplayFormula", "\:3014FormBox[RowBox[{\"L\", \"=\", \"T\", \"-\", \"V\"}], TraditionalForm]\:3015" }
            },
            { { "Insert", ___, { { "Text", "(*no formulas*)" } } } }
        },
        { { "\\omega" }, { "L=T-V" }, { "\\frac{1}{2" }, { "\\dot x" }, { "\\fail" } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-TeXFormulas"
]

VerificationTest[
    withFakeFE @ Block[
        {
            $texRead = { },
            Wolfram`Chatbook`Common`sandboxTeXBoxes = Function[ { texs, seconds }, AppendTo[ $texRead, texs ]; ConstantArray[ "\"x\"", Length @ texs ] ]
        },
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> {
                <| "cell" -> "c3", "text" -> "(*\:3014tex:L=\\tfrac12 m v^2-\\dfrac{1}{2}\:3015 and \:3014tex:\[Theta]\[PartialD]x\:3015*)" |>,
                <| "cell" -> "c4", "text" -> "display-tex:L=T-V", "style" -> "DisplayFormula" |>
            } |> ],
            nbtText @ nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c3", "text" -> "(*\:3014tex:90\[Degree]\:3015*)" |> } |> ],
            Cases[ $fakeCalls, { "Edit", _, ops_ } :> ops ],
            $texRead
        }
    ],
    {
        "Set 2 cells of s1: #c3, #c4. ReadCells shows their new content.",
        "The text of item 1 has a LaTeX formula with characters to write as LaTeX commands instead: \[Degree].",
        {
            {
                { "Set", CellObject[ "fake-1-3" ], Automatic, "(*\:3014$\"x\"\:3015 and \:3014$\"x\"\:3015*)" },
                { "Set", CellObject[ "fake-1-4" ], "DisplayFormula", "\:3014FormBox[\"x\", TraditionalForm]\:3015" }
            }
        },
        { { "L=\\frac12 m v^2-\\frac{1}{2}", "\\theta \\partial x" }, { "L=T-V" } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-TeXSource"
]

(* LaTeX commands whose backslash a JSON string took as an escape (\theta as a tab, \rho as a carriage return, \nu as a
   line break) are refused before anything is read, with a hint; a line break that is not followed by a letter is fine *)
VerificationTest[
    withFakeFE @ Block[
        {
            $texRead = { },
            Wolfram`Chatbook`Common`sandboxTeXBoxes = Function[ { texs, seconds }, AppendTo[ $texRead, texs ]; ConstantArray[ "\"x\"", Length @ texs ] ]
        },
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            nbtText @ nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c3", "text" -> "(*Angle \:3014tex:" <> # <> "\:3015*)" |> } |> ] & /@
                { "\theta", "\rho", "\nu" },
            nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c3", "text" -> "(*\:3014tex:a\n+b\:3015*)" |> } |> ],
            $texRead
        }
    ],
    {
        {
            _String? (StringStartsQ[ "The text of item 1 has a formula with a tab or a line break where a LaTeX command lost its backslash" ]),
            _String? (StringContainsQ[ "lost its backslash" ]),
            _String? (StringContainsQ[ "write each backslash of the LaTeX as \\\\, e.g. \\\\theta" ])
        },
        "Set 1 cell of s1: #c3. ReadCells shows their new content.",
        { { "a\n+b" } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-TeXLostBackslash"
]

(* A structure LaTeX has no form for is an island of boxes \:3014Head[...]\:3015 in the LaTeX, whose box arguments are
   LaTeX in their own \:3014 \:3015. The sandbox kernel reads all of a text's LaTeX in one call, an island as
   \text{ZqnqZ}, whose string in the boxes the island's text replaces. An unreadable argument is named, and so are an
   island that is not boxes and LaTeX in an island's quoted string. *)
VerificationTest[
    Block[
        {
            $texRead = { },
            Wolfram`Chatbook`Tools`NotebookTools`Private`$texOriginals = <| |>,
            Wolfram`Chatbook`Common`sandboxTeXBoxes = Function[ { texs, seconds },
                AppendTo[ $texRead, texs ];
                Lookup[
                    <|
                        "\\int x\\, \\text{Zq1qZ} \\,dx" -> "RowBox[{\"\\[Integral]\", \"x\", \" \", \"Zq1qZ\", \"\\[DifferentialD]\", \"x\"}]",
                        "\\alpha x" -> "RowBox[{\"\\[Alpha]\", \"x\"}]",
                        "y"         -> "\"y\""
                    |>,
                    texs,
                    None
                ]
            ]
        },
        {
            {
                nbtResult @ Wolfram`Chatbook`Tools`NotebookTools`Private`texFormulas[
                    "(*\:3014tex:\\int x\\,\:3014TemplateBox[{\"n\",\:3014\\alpha x\:3015},\"BesselJ\"]\:3015\\,dx\:3015 and \:3014tex:y\:3015*)",
                    "T"
                ],
                nbtResult @ Wolfram`Chatbook`Tools`NotebookTools`Private`texFormulas[
                    "display-tex:\\int x\\,\:3014TemplateBox[{\"n\",\:3014\\frac{1}{2\:3015},\"BesselJ\"]\:3015\\,dx",
                    "T"
                ],
                nbtResult @ Wolfram`Chatbook`Tools`NotebookTools`Private`texFormulas[ "(*\:3014tex:x\:3014y\:3015\:3015*)", "T" ],
                nbtResult @ Wolfram`Chatbook`Tools`NotebookTools`Private`texFormulas[
                    "(*\:3014tex:\:3014TemplateBox[{\"\\nu\",\"x\"},\"BesselJ\"]\:3015\:3015*)",
                    "T"
                ]
            },
            $texRead
        }
    ],
    {
        {
            "(*\:3014$RowBox[{\"\\[Integral]\", \"x\", \" \", TemplateBox[{\"n\",RowBox[{\"\\[Alpha]\", \"x\"}]},\"BesselJ\"], \"\\[DifferentialD]\", \"x\"}]\:3015 and \:3014$\"y\"\:3015*)",
            "T has a formula that is not LaTeX math the tools can read: \"\\frac{1}{2\".",
            "T has \:3014y\:3015 inside a LaTeX formula, where \:3014 \:3015 holds an island of boxes such as \:3014TemplateBox[...]\:3015.",
            "T has LaTeX in a quoted string of an island, \"\\nu\": a quoted string is plain text, and a box argument in LaTeX goes in its own \:3014 \:3015, e.g. \:3014\\nu\:3015."
        },
        { { "\\int x\\, \\text{Zq1qZ} \\,dx", "\\alpha x", "y" }, { "\\int x\\, \\text{Zq1qZ} \\,dx", "\\frac{1}{2" } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-TeXIslands"
]

(* The model reads a formula as LaTeX with islands when that LaTeX reads back to the same boxes, else as boxes (and
   always as boxes when parsing it could evaluate something). A formula written back unchanged gets the front end's
   text back exactly. EditInCell applies edits to the text the model reads when a formula of the cell reads as LaTeX,
   with the front end's failures, and sets the cell; other cells get the front end's own edit. *)
VerificationTest[
    Block[
        {
            $fakeSources = <| NotebookObject[ "fake-source-1" ] -> {
                fakeCell[ "src-1", "Text", "(*the energy \:3014$SuperscriptBox[\"q\", \"2\"]\:3015 of \:3014$TemplateBox[{\"n\", \"x\"}, \"BesselJ\"]\:3015*)", 0 ],
                fakeCell[ "src-2", "Input", "f[q_] := q\:02c42", 0 ],
                fakeCell[ "src-3", "Text", "(*unsafe \:3014$RowBox[{\"a\", Print[1]}]\:3015*)", 0 ]
            } |>,
            Wolfram`Chatbook`Common`sandboxTeXBoxes = Function[ { texs, seconds },
                Lookup[
                    <|
                        "q^{2}"           -> "SuperscriptBox[\"q\", \"2\"]",
                        "r^{2}"           -> "SuperscriptBox[\"r\", \"2\"]",
                        " \\text{Zq1qZ} " -> "\"Zq1qZ\""
                    |>,
                    texs,
                    None
                ]
            ]
        },
        withFakeFE @ Module[ { open, read, edit },
            open = nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
            read = "(*the energy \:3014tex:q^{2}\:3015 of \:3014tex:\:3014TemplateBox[{\"n\",\"x\"},\"BesselJ\"]\:3015\:3015*)";
            edit[ cell_, old_, new_ ] := nbtText @ nbtCall[ "EditInCell", <| "notebook" -> "s1", "cell" -> cell,
                "edits" -> { <| "oldText" -> old, "newText" -> new |> } |> ];
            {
                StringContainsQ[ open, read ],
                StringContainsQ[ open, "(*unsafe \:3014$RowBox[{\"a\", Print[1]}]\:3015*)" ],
                nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c1", "text" -> read |> } |> ],
                StringContainsQ[ edit[ "c1", "q^{2}", "r^{2}" ], "\:3014tex:r^{2}\:3015" ],
                edit[ "c1", "zzz", "y" ],
                edit[ "c2", "q\:02c42", "q\:02c43" ],
                Cases[ $fakeCalls, { "Edit", _, ops_ } :> ops ]
            }
        ]
    ],
    {
        True,
        True,
        "Set 1 cell of s1: #c1. ReadCells shows their new content.",
        True,
        "NoMatch: The text \"zzz\" does not occur in the cell. Nothing was changed. Copy oldText exactly from the cell's current content (ReadCells), with its spaces, \:3014 \:3015 wrappers and \\[Name] characters.",
        _String,
        {
            { { "Set", CellObject[ "fake-1-1" ], Automatic, "(*the energy \:3014$SuperscriptBox[\"q\", \"2\"]\:3015 of \:3014$TemplateBox[{\"n\", \"x\"}, \"BesselJ\"]\:3015*)" } },
            { { "Set", CellObject[ "fake-1-1" ], Automatic, "(*the energy \:3014$SuperscriptBox[\"r\", \"2\"]\:3015 of \:3014$TemplateBox[{\"n\", \"x\"}, \"BesselJ\"]\:3015*)" } },
            { { "Edit", CellObject[ "fake-1-2" ], { { "q\:02c42", "q\:02c43", 1 } } } }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-TeXReads"
]

(* A = and a \[LongEqual] read as the same LaTeX: written back, that LaTeX restores neither formula but is converted,
   and LaTeX = becomes the import's \[LongEqual] (an equation in TraditionalForm) *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Tools`NotebookTools`Private`$texReads     = <| |>,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$texOriginals = <| |>,
            Wolfram`Chatbook`Common`sandboxTeXBoxes = Function[ { texs, seconds },
                ConstantArray[ "RowBox[{\"L\", \"\\[LongEqual]\", \"T\"}]", Length @ texs ]
            ]
        },
        Module[ { read },
            read = Wolfram`Chatbook`Tools`NotebookTools`Private`texReadTexts @ {
                "\:3014$RowBox[{\"L\", \"\\[LongEqual]\", \"T\"}]\:3015",
                "\:3014$RowBox[{\"L\", \"=\", \"T\"}]\:3015",
                "\:3014$RowBox[{\"V\", \"=\", \"T\"}]\:3015"
            };
            {
                read,
                Wolfram`Chatbook`Tools`NotebookTools`Private`texFormulas[ #, "T" ] & /@ read
            }
        ]
    ],
    {
        { "\:3014tex:L = T\:3015", "\:3014tex:L = T\:3015", "\:3014$RowBox[{\"V\", \"=\", \"T\"}]\:3015" },
        {
            "\:3014$RowBox[{\"L\", \"\\[LongEqual]\", \"T\"}]\:3015",
            "\:3014$RowBox[{\"L\", \"\\[LongEqual]\", \"T\"}]\:3015",
            "\:3014$RowBox[{\"V\", \"=\", \"T\"}]\:3015"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-TeXReadsAmbiguous"
]

(* The formulas read so far are forgotten when the last snapshot closes, by CloseNotebook or by ShowChanges *)
VerificationTest[
    withFakeFE @ Module[ { setFormulas, state },
        setFormulas[ ] := (
            Wolfram`Chatbook`Tools`NotebookTools`Private`$texReads     = <| "$\"x\"" -> "tex:x" |>;
            Wolfram`Chatbook`Tools`NotebookTools`Private`$texOriginals = <| "tex:x" -> "$\"x\"" |>
        );
        state[ ] := Length /@ {
            Wolfram`Chatbook`Tools`NotebookTools`Private`$texReads,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$texOriginals
        };
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        nbtCall[ "OpenNotebook", <| |> ];
        setFormulas[ ];
        {
            nbtCall[ "CloseNotebook", <| "notebook" -> "s1" |> ]; state[ ],
            nbtCall[ "CloseNotebook", <| "notebook" -> "s2" |> ]; state[ ],
            nbtCall[ "OpenNotebook", <| |> ];
            setFormulas[ ];
            nbtCall[ "InsertCells", <| "notebook" -> "s3", "newCells" -> { <| "style" -> "Text", "text" -> "(*x*)" |> } |> ];
            nbtCall[ "ShowChanges", <| "notebook" -> "s3" |> ];
            state[ ]
        }
    ],
    { { 1, 1 }, { 0, 0 }, { 0, 0 } },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-TeXStateCleared"
]

(* The cells that SetCells and EditInCell change are recorded by their uuids, for ShowChanges *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c4", "text" -> "L = T - V" |> } |> ];
        nbtCall[ "EditInCell", <| "notebook" -> "s1", "cell" -> "c3", "edits" -> { <| "oldText" -> "Hamiltonian", "newText" -> "Lagrangian" |> } |> ];
        nbtCall[ "InsertCells", <| "notebook" -> "s1", "newCells" -> { <| "style" -> "Text", "text" -> "(*x*)" |> } |> ];
        Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots[ "s1", "EditedCells" ]
    ),
    { "fake-1-3", "fake-1-4" },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-EditedCells"
]

(* Tags: the marker lines and the outline show a cell's tags; SetCells sets them with or without the text, and new cells
   may have them, for links to the cells (Hyperlink ButtonBoxes whose ButtonData is a tag) *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c2", "tags" -> "pendulum, start" |>, <| "cell" -> "c6", "tags" -> "[\"motion\"]" |> } |> ],
            nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c3", "text" -> "(*See \:3014ButtonBox[\"Equations of motion\", BaseStyle->\"Hyperlink\", ButtonData->\"motion\"]\:3015.*)", "tags" -> "" |> } |> ],
            nbtCall[ "InsertCells", <| "notebook" -> "s1", "newCells" -> { <| "style" -> "Section", "text" -> "(*Waves*)", "tags" -> "waves" |>, <| "style" -> "Text", "text" -> "(*x*)" |> } |> ],
            nbtCall[ "ReadCells", <| "notebook" -> "s1", "cells" -> "c2, c6" |> ],
            StringCases[ nbtCall[ "GetOutline", <| "notebook" -> "s1" |> ], "(* ::Section" ~~ Except[ "\n" ].. ],
            nbtText @ nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c2", "style" -> "Text", "tags" -> "x" |> } |> ],
            nbtText @ nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c2", "text" -> "(* ::Section:: #c2 tags: x *)\n(*x*)" |> } |> ],
            Cases[ $fakeCalls, { "Edit", _, ops_ } :> ops ]
        }
    ),
    {
        "Set 2 cells of s1: #c2, #c6. ReadCells shows their new content.",
        "Set 1 cell of s1: #c3. ReadCells shows their new content.",
        "Inserted 2 cells at the end of s1:\n(* ::Section:: #c8 tags: waves *)\n(*Waves*)\n(* ::Text:: #c9 *)\n(*x*)",
        "(* ::Section:: #c2 tags: pendulum, start *)\n(*The simple pendulum*)\n(* ::Section::Closed:: #c6 tags: motion *)\n(*Equations of motion*)",
        { "(* ::Section:: #c2 tags: pendulum, start *)", "(* ::Section::Closed:: #c6 tags: motion *)", "(* ::Section:: #c8 tags: waves *)" },
        "Item 1 of cells changes the style without the text: give its text too.",
        "The text of item 1 includes a marker line (* ::Style:: #id *): give the content of one cell, without its marker line.",
        {
            { { "Tags", CellObject[ "fake-1-2" ], { "pendulum", "start" } }, { "Tags", CellObject[ "fake-1-6" ], { "motion" } } },
            { { "Set", CellObject[ "fake-1-3" ], Automatic, _String }, { "Tags", CellObject[ "fake-1-3" ], { } } },
            { { "Insert", None, "After", { { "Section", "(*Waves*)", { "waves" } }, { "Text", "(*x*)" } } } }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Tags"
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
        (* 16.0's LLMTool refuses a value of the wrong type before the tool runs, so there is no text: *)
        "The parameter newCells must be a list of cells {style, text}, e.g. [{\"style\": \"Input\", \"text\": \"x = 1\"}]." | _Missing | Failure[ "InvalidLLMToolParameter", _ ],
        11,
        { "#c10", "#c1", "#c2", "#c3", "#c4", "#c8", "#c9", "#c5", "#c6", "#c7", "#c11" },
        { { CellObject[ "fake-1-4" ], "After", 2 }, { CellObject[ "fake-1-1" ], "Before", 1 }, { None, "After", 1 } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-InsertCells"
]

(* DeleteCells deletes cells and forgets their ids *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        {
            nbtCall[ "DeleteCells", <| "notebook" -> "s1", "cells" -> "c5, c4" |> ],
            nbtText @ nbtCall[ "ReadCells", <| "notebook" -> "s1", "cells" -> "c4" |> ],
            nbtCall[ "DeleteCells", <| "notebook" -> "s1" |> ],
            Values @ Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots[ "s1", "IDs" ],
            Length @ $fakeNotebooks[ NotebookObject[ "fake-snapshot-1" ], "Cells" ]
        }
    ),
    {
        "Deleted 2 cells (#c5, #c4) from s1.",
        "s1 has no cell \"c4\". Cell ids come from OpenNotebook, GetOutline, ReadCells and SearchNotebook.",
        _Failure, (* LLMTool refuses a call without a required parameter *)
        { "c1", "c2", "c3", "c6", "c7" },
        5
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-DeleteCells"
]

(* ShowChanges: nothing to show without edits; unsaved edits are saved first (the snapshot, never the source); CellDiff
   gets the source (the notebook, the file or None) and the snapshot's NotebookObject; the snapshot is closed. If the
   diff fails, the snapshot stays open. *)
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
            Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots,
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
            { "ShowDiff", NotebookObject[ "fake-source-1" ], NotebookObject[ "fake-snapshot-1" ], { } },
            { "ShowDiff", NotebookObject[ "fake-source-1" ], NotebookObject[ "fake-snapshot-1" ], { } },
            { "Close", NotebookObject[ "fake-snapshot-1" ] },
            { "Save", NotebookObject[ "fake-snapshot-2" ] },
            { "ShowDiff", None, NotebookObject[ "fake-snapshot-2" ], { } },
            { "Close", NotebookObject[ "fake-snapshot-2" ] }
        },
        <| |>,
        <| |>
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ShowChanges"
]

(* A snapshot that can't be saved is not shown and stays open with its unsaved edits *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        nbtCall[ "DeleteCells", <| "notebook" -> "s1", "cells" -> "c7" |> ];
        {
            Block[ { $fakeSaveFails = True }, nbtText @ nbtCall[ "ShowChanges", <| "notebook" -> "s1" |> ] ],
            KeyTake[ Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots[ "s1" ], { "Edited", "Unsaved" } ],
            Cases[ $fakeCalls, { op: "Save" | "ShowDiff" | "Close", args___ } :> { op, args } ]
        }
    ),
    {
        "The front end could not save s1 (\"Hamiltonian Mechanics\").",
        <| "Edited" -> True, "Unsaved" -> True |>,
        { { "Save", NotebookObject[ "fake-snapshot-1" ] } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ShowChanges-SaveFails"
]

(* CloseNotebook discards a snapshot; its handle is then unknown *)
VerificationTest[
    withFakeFE @ (
        nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
        nbtCall[ "OpenNotebook", <| "notebook" -> "12345678" |> ];
        {
            nbtCall[ "CloseNotebook", <| "notebook" -> "s1" |> ],
            nbtText @ nbtCall[ "GetOutline", <| "notebook" -> "s1" |> ],
            Keys @ Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots,
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
    TestID   -> "NotebookTools-CloseNotebook"
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
    TestID   -> "NotebookTools-FrontEndFailures"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CellDiff*)

(* ShowChanges uses the CellDiff comparison in Assets/CellDiff, loaded without a front end at the first call, off
   $ContextPath, and only once per session *)
VerificationTest[
    Internal`InheritedBlock[ { Wolfram`Chatbook`Tools`NotebookTools`Private`notebookDiffFunction },
        Module[ { dir, path, first, second },
            dir    = Wolfram`Chatbook`Common`$thisPaclet[ "AssetLocation", "CellDiff" ];
            path   = $ContextPath;
            first  = nbtResult @ Wolfram`Chatbook`Tools`NotebookTools`Private`notebookDiffFunction[ ];
            (* a second load would not find the files now *)
            second = Block[ { Wolfram`Chatbook`Common`$thisPaclet = FileNameJoin @ { $TemporaryDirectory, "nbt-" <> $nbtTag <> "-missing" } & },
                nbtResult @ Wolfram`Chatbook`Tools`NotebookTools`Private`notebookDiffFunction[ ]
            ];
            {
                Sort[ FileNameTake /@ FileNames[ "*.wl", dir ] ],
                Head @ first,
                Context @ Evaluate @ first,
                SymbolName @ first,
                $ContextPath === path,
                second === first
            }
        ]
    ],
    { { "CellDiffControlStyles.wl", "CellDiffNotebookDiff.wl" }, Symbol, "CellDiffNotebookDiff`", "ShowNotebookDiff", True, True },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-CellDiff"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Code Check*)

(* An edit that changes or inserts an Input cell ends with the code check of the snapshot's Input cells (evaluated by
   the sandbox kernel, made up here); an edit of other cells has none *)
VerificationTest[
    withFakeFE @ Block[
        {
            $fakeCodeCells = True,
            $checked       = { },
            $checkResults  = { },
            Wolfram`Chatbook`Common`sandboxCheckCells = Function[ { boxes, cellSeconds, seconds }, AppendTo[ $checked, boxes ]; $checkResults ]
        },
        Module[ { check, text, edited, stopped, failed, inserted },
            check[ r_String ] := Replace[ StringPosition[ r, "\n\nCode check:" ], { { { start_, _ }, ___ } :> StringDrop[ r, start + 1 ], _ -> None } ];
            nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
            text = nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c3", "text" -> "(*New words*)" |> } |> ];
            $checkResults = {
                <| "Result" -> "", "Messages" -> { }, "Aborted" -> False |>,
                <| "Result" -> "{q -> InterpolatingFunction[...]}", "Messages" -> { "NDSolve::ndsz" }, "Aborted" -> False |>
            };
            edited = nbtCall[ "EditInCell", <| "notebook" -> "s1", "cell" -> "c4", "edits" -> { <| "oldText" -> "Cos", "newText" -> "Sin" |> } |> ];
            $checkResults = { <| "Result" -> "", "Messages" -> { }, "Aborted" -> True |> };
            stopped = nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c7", "text" -> "sol = 1" |> } |> ];
            $checkResults = Failure[ "TimedOut", <| |> ];
            failed = nbtCall[ "EditInCell", <| "notebook" -> "s1", "cell" -> "c4", "edits" -> { <| "oldText" -> "Sin", "newText" -> "Cos" |> } |> ];
            $checkResults = ConstantArray[ <| "Result" -> "", "Messages" -> { }, "Aborted" -> False |>, 3 ];
            inserted = nbtCall[ "InsertCells", <| "notebook" -> "s1", "cell" -> "c7", "newCells" -> { <| "style" -> "Input", "text" -> "x = 1" |> } |> ];
            { check /@ { text, edited, stopped, failed, inserted }, Length /@ $checked, StringContainsQ[ $checked[[ 1, 1 ]], "Sin" ] }
        ]
    ],
    {
        {
            None,
            "Code check: the snapshot's 2 Input cells, evaluated in order in a fresh context of a separate kernel, give messages in 1 cell:\n#c7: {q -> InterpolatingFunction[...]}; messages NDSolve::ndsz",
            "Code check: the snapshot's 2 Input cells, evaluated in order in a fresh context of a separate kernel, give no messages:\n#c4: aborted after 10 s\nThe check stopped after 30 s: #c7 and later cells were not checked.",
            "Code check: the code could not be checked (the separate kernel did not answer in time).",
            "Code check: the snapshot's 3 Input cells, evaluated in order in a fresh context of a separate kernel, give no messages."
        },
        { 2, 2, 2, 3 },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-CodeCheck"
]

(* With evaluate, the Input cells an edit writes and the Input cells after the first of them are evaluated with the
   code check, and their outputs replaced by the results' boxes from the sandbox kernel (made up here): the Output cells
   after each are deleted and one for each of its statements' results inserted; boxes that would run code when shown
   are not written (a legend's InterpretationFunction would not), and the old outputs stay; the new cells are named, not
   read. Output cells are never written by hand. *)
VerificationTest[
    withFakeFE @ Block[
        {
            $fakeCodeCells = True,
            $checkArgs     = { },
            $checkResults  = { },
            Wolfram`Chatbook`Common`sandboxCheckCells = (AppendTo[ $checkArgs, { ## } ]; $checkResults) &
        },
        Module[ { edited, dynamic, ops },
            nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
            $checkResults = {
                <| "Result" -> "p + q", "Messages" -> { }, "Aborted" -> False, "Boxes" -> { "RowBox[{\"p\", \"+\", \"q\"}]", "\"2\"", "GraphicsBox[{}]" } |>,
                <| "Result" -> "", "Messages" -> { }, "Aborted" -> False |>
            };
            edited = nbtCall[ "EditInCell", <| "notebook" -> "s1", "cell" -> "c4", "edits" -> { <| "oldText" -> "Cos", "newText" -> "Sin" |> }, "evaluate" -> True |> ];
            $checkResults = {
                <| "Result" -> "", "Messages" -> { }, "Aborted" -> False |>,
                <| "Result" -> "x", "Messages" -> { }, "Aborted" -> False, "Boxes" -> { "TemplateBox[{}, \"Legend\", InterpretationFunction :> (x &)]", "DynamicBox[x]" } |>
            };
            dynamic = nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c7", "text" -> "sol = 1" |> }, "evaluate" -> True |> ];
            ops = Cases[ $fakeCalls, { "Edit", _, o_ } :> o ];
            {
                StringContainsQ[ edited, "Evaluated #c4, #c7: new Output cells #c8 and #c9 and #c10 after #c4 (their results are in the code check)." ],
                StringContainsQ[ dynamic, "Evaluated #c7: no new outputs.\nNot written, so the old outputs are kept: #c7 (it would run code when shown)." ],
                ops,
                $checkArgs[[ All, 4 ]],
                nbtText @ nbtCall[ "SetCells", <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c8", "text" -> "2" |> } |> ],
                nbtText @ nbtCall[ "InsertCells", <| "notebook" -> "s1", "newCells" -> { <| "style" -> "Output", "text" -> "2" |> } |> ],
                nbtText @ nbtCall[ "EditInCell", <| "notebook" -> "s1", "cell" -> "c8", "edits" -> { <| "oldText" -> "p", "newText" -> "r" |> } |> ]
            }
        ]
    ],
    {
        True,
        True,
        {
            { { "Edit", CellObject[ "fake-1-4" ], { { "Cos", "Sin", 1 } } } },
            { { "Delete", { CellObject[ "fake-1-5" ] } }, { "Insert", CellObject[ "fake-1-4" ], "After", { { { "Output", "EvaluationUnmatched" }, "\:3014RowBox[{\"p\", \"+\", \"q\"}]\:3015" }, { { "Output", "EvaluationUnmatched" }, "\:3014\"2\"\:3015" }, { { "Output", "EvaluationUnmatched" }, "\:3014GraphicsBox[{}]\:3015" } } } },
            { { "Set", CellObject[ "fake-1-7" ], Automatic, "sol = 1" } }
        },
        { { 1, 2 }, { 2 } },
        $outputText,
        $outputText,
        $outputText
    } /. $outputText -> "Output cells are never written by hand: they hold the real results. Give evaluate: true with the edit of the Input cell, which replaces its outputs and those of the Input cells after it with their results, or delete outputs that become stale.",
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-EvaluateOutputs"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Calls*)

(* A SetCells call written by a model with the Simple tool method: its cells are JSON (with escaped backslashes and
   quotes, and characters that are not ASCII), read before the tool's interpreter gets them, and the edit reaches the
   snapshot unchanged. (The parameters a call leaves out are "" with this method: see
   NotebookTools-SimpleToolMethod-RequiredParameters.) *)
VerificationTest[
    withFakeFE @ Internal`InheritedBlock[ { Wolfram`Chatbook`Tools`Private`$toolBox },
        Block[ { Wolfram`Chatbook`Common`$selectedTools = $nbtTools },
            Module[ { request },
                nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
                request = Last @ Wolfram`Chatbook`Common`simpleToolRequestParser[
                    "I'll fix the text.\n/nb_set\nnotebook: s1\ncells: [{\"cell\":\"c3\",\"text\":\"(*A backslash \\\\\\\\ and \\\\[Rule] in \\\"quotes\\\": \[Alpha] \:00e9t\:00e9 \:65e5\:672c*)\"}]\ndelete: c5"
                ];
                {
                    request[ "Name" ],
                    Association @ request[ "ParameterValues" ],
                    Wolfram`Chatbook`SendChat`Private`toolResponseString @ GenerateLLMToolResponse[
                        LLMConfiguration @ <| "Tools" -> Values @ $nbtTools |>,
                        request
                    ],
                    $fakeNotebooks[ NotebookObject[ "fake-snapshot-1" ], "Cells" ][[ 3, "Text" ]],
                    Cases[ $fakeCalls, { "Edit", _, ops_ } :> ops ]
                }
            ]
        ]
    ],
    {
        "set_cells",
        <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c3", "text" -> $nbtE2EText |> }, "delete" -> "c5", "evaluate" -> "" |>,
        "Set 1 cell of s1: #c3; deleted #c5. ReadCells shows their new content.",
        $nbtE2EText,
        { { { "Set", CellObject[ "fake-1-3" ], Automatic, $nbtE2EText }, { "Delete", { CellObject[ "fake-1-5" ] } } } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-SimpleToolCall"
]

(* A native SetCells call written as a Simple tool call (the hybrid tool method): its list of cells becomes JSON on one
   line, which is read back as the same list, and the edit reaches the snapshot unchanged *)
VerificationTest[
    withFakeFE @ Internal`InheritedBlock[ { Wolfram`Chatbook`Tools`Private`$toolBox },
        Block[ { Wolfram`Chatbook`Common`$selectedTools = $nbtTools },
            Module[ { native, text, request },
                nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
                native = LLMToolRequest[
                    "set_cells",
                    <|
                        "notebook" -> "s1",
                        "cells"    -> { <| "cell" -> "c4", "text" -> $nbtE2ECodeText |>, <| "cell" -> "c3", "text" -> $nbtE2EText |> },
                        "delete"   -> "c5"
                    |>
                ];
                text = Block[
                    {
                        Wolfram`Chatbook`$ChatHandlerData         = <| "ChatNotebookSettings" -> <| "ToolMethod" -> "Simple" |> |>,
                        Wolfram`Chatbook`Common`$receivedToolCall = False
                    },
                    Wolfram`Chatbook`LLMUtilities`Private`toolRequestToString @ native
                ];
                request = Last @ Wolfram`Chatbook`Common`simpleToolRequestParser @ text;
                {
                    StringStartsQ[ text, "\n/nb_set\nnotebook: s1\ncells: [" ],
                    KeyTake[ Association @ request[ "ParameterValues" ], { "notebook", "cells", "delete" } ] === Association @ native[ "ParameterValues" ],
                    Wolfram`Chatbook`SendChat`Private`toolResponseString @ GenerateLLMToolResponse[
                        LLMConfiguration @ <| "Tools" -> Values @ $nbtTools |>,
                        request
                    ],
                    $fakeNotebooks[ NotebookObject[ "fake-snapshot-1" ], "Cells" ][[ { 3, 4 }, "Text" ]]
                }
            ]
        ]
    ],
    {
        True,
        True,
        "Set 2 cells of s1: #c4, #c3; deleted #c5. ReadCells shows their new content.",
        { $nbtE2EText, $nbtE2ECodeText }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-HybridToolCall"
]

(* With the Simple tool method, the optional parameters a call leaves out are "" (Missing["NoInput"] for a native call):
   every tool called that way with only its required parameters gives what it gives when they are not given at all.
   The names of the tools that differ: *)
VerificationTest[
    Internal`InheritedBlock[ { Wolfram`Chatbook`Tools`Private`$toolBox },
        Block[ { Wolfram`Chatbook`Common`$selectedTools = $nbtTools },
            Module[ { calls, viaSimple, direct },
                calls = {
                    { "ListNotebooks", "/nb_list", <| |> },
                    { "OpenNotebook", "/nb_open\nnotebook: 12345678", <| "notebook" -> "12345678" |> },
                    { "GetOutline", "/nb_outline\nnotebook: s1", <| "notebook" -> "s1" |> },
                    { "ReadCells", "/nb_cells\nnotebook: s1", <| "notebook" -> "s1" |> },
                    { "SearchNotebook", "/nb_find\nnotebook: s1\nquery: pendulum", <| "notebook" -> "s1", "query" -> "pendulum" |> },
                    { "GetSelection", "/nb_selection\nnotebook: s1", <| "notebook" -> "s1" |> },
                    {
                        "EditInCell",
                        "/nb_edit\nnotebook: s1\ncell: c3\nedits: [{\"oldText\": \"pendulum\", \"newText\": \"swing\"}]",
                        <| "notebook" -> "s1", "cell" -> "c3", "edits" -> { <| "oldText" -> "pendulum", "newText" -> "swing" |> } |>
                    },
                    {
                        "SetCells",
                        "/nb_set\nnotebook: s1\ncells: [{\"cell\": \"c3\", \"text\": \"(*New*)\"}]",
                        <| "notebook" -> "s1", "cells" -> { <| "cell" -> "c3", "text" -> "(*New*)" |> } |>
                    },
                    {
                        "InsertCells",
                        "/nb_insert\nnotebook: s1\nnewCells: [{\"style\": \"Text\", \"text\": \"(*New*)\"}]",
                        <| "notebook" -> "s1", "newCells" -> { <| "style" -> "Text", "text" -> "(*New*)" |> } |>
                    },
                    { "DeleteCells", "/nb_delete\nnotebook: s1\ncells: c3", <| "notebook" -> "s1", "cells" -> "c3" |> },
                    { "ShowChanges", "/nb_show\nnotebook: s1", <| "notebook" -> "s1" |> },
                    { "CloseNotebook", "/nb_close\nnotebook: s1", <| "notebook" -> "s1" |> }
                };
                viaSimple[ text_String ] := withFakeFE[
                    nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
                    Wolfram`Chatbook`SendChat`Private`toolResponseString @ GenerateLLMToolResponse[
                        LLMConfiguration @ <| "Tools" -> Values @ $nbtTools |>,
                        Last @ Wolfram`Chatbook`Common`simpleToolRequestParser @ text
                    ]
                ];
                direct[ name_String, args_Association ] := withFakeFE[
                    nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
                    nbtText @ nbtCall[ name, args ]
                ];
                Select[ calls, viaSimple[ #[[ 2 ]] ] =!= direct[ #[[ 1 ]], #[[ 3 ]] ] & ][[ All, 1 ]]
            ]
        ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-SimpleToolMethod-RequiredParameters"
]

(* Through the same path, a tool without parameters works, and an error reaches the model as its text *)
VerificationTest[
    withFakeFE @ Internal`InheritedBlock[ { Wolfram`Chatbook`Tools`Private`$toolBox },
        Block[ { Wolfram`Chatbook`Common`$selectedTools = $nbtTools },
            Module[ { respond },
                respond[ text_String ] := Wolfram`Chatbook`SendChat`Private`toolResponseString @ GenerateLLMToolResponse[
                    LLMConfiguration @ <| "Tools" -> Values @ $nbtTools |>,
                    Last @ Wolfram`Chatbook`Common`simpleToolRequestParser @ text
                ];
                nbtCall[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ];
                {
                    nbtJSON[ respond[ "/nb_list" ] ][ "snapshots" ][[ All, "notebook" ]],
                    respond[ "/nb_edit\nnotebook: s1\ncell: c99\nedits: [{\"oldText\": \"a\", \"newText\": \"b\"}]" ]
                }
            ]
        ]
    ],
    {
        { "s1" },
        "s1 has no cell \"c99\". Cell ids come from OpenNotebook, GetOutline, ReadCells and SearchNotebook."
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ToolCallErrors"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Errors*)

(* An error result has the text for the model as its "String" (as for FileReader's errors), and its Failure's template
   shows the text as it is (template slots in it are not filled) *)
VerificationTest[
    Wolfram`Chatbook`Tools`NotebookTools`Private`toolFailure[ "Bad `id` <x>" ],
    <|
        "Result" -> Failure[ "NotebookToolError", <| "MessageTemplate" -> "`1`", "MessageParameters" -> { "Bad `id` <x>" } |> ],
        "String" -> "Bad `id` <x>"
    |>,
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ToolFailure"
]

(* Internal failures give a generic error text; Chatbook keeps their details *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`Private`$lastInternalFailure = None },
        {
            Quiet @ nbtText @ Wolfram`Chatbook`Tools`NotebookTools`Private`toolResult[
                "Test",
                Wolfram`Chatbook`Common`throwInternalFailure @ nbtUndefined[ 1 ]
            ],
            Lookup[ Wolfram`Chatbook`Common`Private`$lastInternalFailure, "Evaluation" ],
            nbtText @ Wolfram`Chatbook`Tools`NotebookTools`Private`toolResult[ "Test", { "not a string" } ],
            Wolfram`Chatbook`Tools`NotebookTools`Private`toolResult[ "Test", "fine" ]
        }
    ],
    {
        "The Test tool failed because of an internal error in Chatbook.",
        HoldPattern @ nbtUndefined[ 1 ],
        "The Test tool failed because of an internal error in Chatbook.",
        "fine"
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-InternalFailure"
]

(* Without a front end, no notebooks are listed, a snapshot can't be made, and only open snapshots are known *)
VerificationTest[
    Block[
        {
            $FrontEnd = Null,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots     = <| |>,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshotCount = 0
        },
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
    TestID   -> "NotebookTools-NoFrontEnd"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
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
    TestID   -> "NotebookTools-Setup"
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
    TestID   -> "NotebookTools-ListNotebooks"
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
    TestID   -> "NotebookTools-ListNotebooks-Excluded"
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
    TestID   -> "NotebookTools-Open-FileAndPrefix"
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
    TestID   -> "NotebookTools-Open-AmbiguousTitle"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    If[ TrueQ @ $nbtFrontEndQ,
        UsingFrontEnd @ Scan[ If[ MemberQ[ Notebooks[ ], # ], NotebookClose[ #, Interactive -> False ] ] &, $nbtNotebooks ]
    ];
    Scan[ Quiet @ DeleteFile @ # &, Select[ $nbtFiles, FileExistsQ ] ];
    {
        If[ TrueQ @ $nbtFrontEndQ, UsingFrontEnd @ Select[ $nbtNotebooks, MemberQ[ Notebooks[ ], # ] & ], { } ],
        Select[ $nbtFiles, FileExistsQ ]
    },
    { { }, { } },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Cleanup"
]

(* :!CodeAnalysis::EndBlock:: *)
