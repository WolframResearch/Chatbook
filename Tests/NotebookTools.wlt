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

(* Tests for the notebook editing tools (Tools/NotebookTools.wl, registered in Tools/DefaultToolDefinitions/NotebookTools.wl).
   The tools are called through their LLMTools, on a made-up front end: what the tools do with a notebook goes through
   notebookFrontEnd, which the tests replace. Cells are converted for real, and writing code needs a front end to
   tokenize it, so the tests run under UsingFrontEnd. The tests at the end run the real front end operations on a
   hidden copy of a notebook (no released front end makes snapshots yet); the ones that show a comparison are skipped
   before 16.0 (nbtShowsDiffQ). The tools' state and the stores that reading writes to are Blocked in every test that
   changes them, so that nothing is left for other test files (CI runs them all in one kernel). *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    (* CI runs every test file in one kernel and one context: these helpers are only defined here *)
    ClearAll[
        nbt, nbtFE, nbtList, nbtWrite, nbtWithFE, nbtCells, nbtStyles, nbtChat, nbtEvaluator, nbtRespond, nbtEdit,
        nbtWriteCells, nbtEditCell, nbtRealFE, nbtShowsDiffQ
    ];

    $nbtNames = {
        "ListNotebooks", "OpenNotebook", "GetOutline", "ReadCells", "SearchNotebook", "EditInCell", "WriteCells",
        "ShowChanges", "CloseNotebook"
    };
    $nbtTools = AssociationMap[ Wolfram`Chatbook`$DefaultTools, $nbtNames ];

    (* What a tool gives the model: its result, or the text of its error *)
    nbt[ name_String, args_Association ] := Replace[ $nbtTools[ name ][ args ], KeyValuePattern[ "String" -> text_String ] :> text ];
    nbt[ name_String ] := nbt[ name, <| |> ];

    (* The result of an editing tool without what all of them have: the line about the snapshot that the first edit of
       a notebook opens, and the last line about ShowChanges (NotebookTools-SnapshotAtFirstEdit has the two) *)
    nbtEdit[ name_String, args_Association ] := StringDelete[
        nbt[ name, args ],
        { StartOfString ~~ "Opened s" ~~ DigitCharacter.. ~~ " (" ~~ Shortest[ __ ] ~~ "), a snapshot of the notebook.\n\n", $nbtNotShown ~~ EndOfString }
    ];
    nbtWriteCells[ cells_String, more___Rule ] := nbtEdit[ "WriteCells", <| "cells" -> cells, more |> ];
    nbtEditCell[ cell_String, edits_, more___Rule ] := nbtEdit[
        "EditInCell",
        <| "cell" -> cell, "edits" -> (<| "oldText" -> First @ #, "newText" -> Last @ # |> & /@ Flatten @ { edits }), more |>
    ];

    (* The user's notebook: cells with the ExpressionUUIDs u1, u2, ... *)
    $nbtSource = NotebookObject[ "abcdef11-0000-4000-8000-000000000001" ];
    $nbtOther  = NotebookObject[ "12345678-0000-4000-8000-000000000002" ];
    $nbtBold   = StyleBox[ "simple", FontWeight -> "Bold" ];
    $nbtLink   = ButtonBox[ "the docs", BaseStyle -> "Hyperlink", ButtonData -> { URL[ "https://www.wolfram.com" ], None } ];
    $nbtCode   = RowBox @ { "H", "=", RowBox @ { FractionBox[ SuperscriptBox[ "p", "2" ], RowBox @ { "2", " ", "m" } ], "-", "g" } };

    $nbtSourceCells = {
        { "u1", Cell[ "Hamiltonian Mechanics", "Title" ] },
        { "u2", Cell[ TextData @ { "The ", $nbtBold, " pendulum, see ", $nbtLink, "." }, "Text", CellTags -> "intro" ] },
        { "u3", Cell[ BoxData @ $nbtCode, "Input", CellLabel -> "In[1]:=" ] },
        { "u4", Cell[ BoxData @ "42", "Output", CellLabel -> "Out[1]=" ] },
        { "u5", Cell[ "Equations of motion", "Section" ] },
        { "u6", Cell[ BoxData @ RowBox @ { "f", "[", "x", "]" }, "Input" ] }
    };

    $nbtListed = {
        <| "NotebookObject" -> $nbtSource, "ID" -> "abcdef11", "Title" -> "Hamiltonian Mechanics", "File" -> "/tmp/Hamiltonian.nb", "Modified" -> True |>,
        <| "NotebookObject" -> $nbtOther, "ID" -> "12345678", "Title" -> "Other", "File" -> None, "Modified" -> False |>
    };

    (* A made-up front end. A notebook is a list of { uuid, cell }: the user's notebooks are in $nbtSources, and the
       snapshots in $nbtNotebooks. A snapshot has the cells that its source has when it is made, with the same uuids.
       A cell that is written has its ExpressionUUID as an option. A cell is locked by its own options. *)
    nbtFE[ "Snapshot", "fail" ] := $Failed;
    nbtFE[ "Snapshot", source_ ] := With[ { nb = NotebookObject[ "snapshot-" <> ToString[ ++$nbtCount ] ] },
        $nbtNotebooks[ nb ] = Lookup[ $nbtSources, Key @ source, { } ];
        nb
    ];
    nbtFE[ "Excluded", _ ] := $nbtExcluded;
    nbtList[ nb_ ] := Lookup[ $nbtNotebooks, nb, Lookup[ $nbtSources, nb, { } ] ];
    nbtFE[ "Cells", nb_ ] := CellObject[ #, "instance" ] & /@ nbtList[ nb ][[ All, 1 ]];
    nbtFE[ "Cells", nb_, style_ ] := CellObject[ First @ #, "instance" ] & /@ Select[ nbtList @ nb, MatchQ[ Last @ #, Cell[ __, style, ___ ] ] & ];
    nbtFE[ "Read", nb_, cells_List ] := Lookup[ Association[ Rule @@@ nbtList @ nb ], First /@ cells ];
    nbtFE[ "Locks", nb_, cells_List ] := { FreeQ[ #, Editable -> False ], FreeQ[ #, Deletable -> False ] } & /@ nbtFE[ "Read", nb, cells ];
    nbtFE[ "Write", nb_, writes_List ] := If[ TrueQ @ $nbtWriteFails, $Failed, AppendTo[ $nbtWrites, writes ]; Scan[ nbtWrite[ nb, # ] &, writes ] ];
    nbtFE[ "Close", nb_ ] := (AppendTo[ $nbtClosed, nb ]; KeyDropFrom[ $nbtNotebooks, nb ];);
    nbtFE[ "DiffCells", nb_ ] := Lookup[ $nbtDiffCells, nb, { } ];
    (* the comparison against a snapshot gives $nbtDiffResult, and the one against a Notebook expression marks 1 cell *)
    nbtFE[ "ShowDiff", source_, snapshot_NotebookObject, edited_ ] := (AppendTo[ $nbtShown, { source, snapshot, edited } ]; $nbtDiffResult);
    nbtFE[ "ShowDiff", source_, notebook_Notebook ] := (AppendTo[ $nbtShown, { source, notebook } ]; 1);

    nbtWrite[ nb_, { "Replace", uuid_, cell_ } ] :=
        $nbtNotebooks[ nb ] = Replace[ $nbtNotebooks @ nb, { uuid, _ } :> { uuid, DeleteCases[ cell, ExpressionUUID -> uuid ] }, { 1 } ];
    nbtWrite[ nb_, { "Delete", uuids_ } ] := $nbtNotebooks[ nb ] = DeleteCases[ $nbtNotebooks @ nb, { Alternatives @@ uuids, _ } ];
    nbtWrite[ nb_, { "Insert", anchor_, position_, cells_ } ] := With[
        {
            list = $nbtNotebooks @ nb,
            new  = { FirstCase[ #, (ExpressionUUID -> uuid_) :> uuid ], DeleteCases[ #, ExpressionUUID -> _ ] } & /@ cells
        },
        With[ { at = If[ anchor === None, 0, First @ FirstPosition[ list[[ All, 1 ]], anchor ] - Boole[ position === "Before" ] ] },
            $nbtNotebooks[ nb ] = Join[ Take[ list, at ], new, Drop[ list, at ] ]
        ]
    ];

    (* Evaluates with the tools on the made-up front end, where the user is working in $nbtSource, and with nothing
       left of the tools' state afterwards *)
    nbtWithFE // Attributes = { HoldFirst };
    nbtWithFE[ eval_ ] := UsingFrontEnd @ Block[
        {
            Wolfram`Chatbook`Tools`NotebookTools`Private`notebookFrontEnd = nbtFE,
            Wolfram`Chatbook`Tools`NotebookTools`Private`listedNotebooks  = $nbtListed &,
            Wolfram`Chatbook`Tools`NotebookTools`Private`userNotebook     = $nbtUser &,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots       = <| |>,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshotCount   = 0,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$cellTables      = <| |>,
            (* what reading a graphic stores, and the keys that reading made *)
            Wolfram`Chatbook`Common`$attachments                          = <| |>,
            Wolfram`Chatbook`Common`$notebookAttachments                  = <| |>,
            (* no chat: the snapshots and the tables of ids belong to None *)
            Wolfram`Chatbook`$ChatHandlerData                             = <| |>,
            $nbtUser       = $nbtSource,
            $nbtSources    = <| $nbtSource -> $nbtSourceCells, $nbtOther -> { { "o1", Cell[ "Another notebook", "Text" ] } } |>,
            $nbtNotebooks  = <| |>,
            $nbtCount      = 0,
            $nbtWrites     = { },
            $nbtClosed     = { },
            $nbtShown      = { },
            $nbtDiffResult = 1,
            $nbtDiffCells  = <| |>,
            $nbtExcluded   = False,
            $nbtWriteFails = False
        },
        eval
    ];

    (* The cells of the n-th snapshot, and their styles *)
    nbtCells[ n_Integer ] := $nbtNotebooks[ NotebookObject[ "snapshot-" <> ToString @ n ] ][[ All, 2 ]];
    nbtCells[ ] := nbtCells[ 1 ];
    nbtStyles[ n___ ] := Cases[ nbtCells @ n, Cell[ _, arguments___ ] :> Cases[ { arguments }, _String ] ];

    (* Evaluates as a tool call of the chat with this ConversationUUID *)
    nbtChat // Attributes = { HoldRest };
    nbtChat[ id_String, eval_ ] :=
        Block[ { Wolfram`Chatbook`$ChatHandlerData = <| "ChatNotebookSettings" -> <| "ConversationUUID" -> id |> |> }, eval ];

    (* Evaluates with a made-up evaluator as the evaluator tool of the chat: evaluateToBoxes gives what results has for
       a statement (the boxes "Null" if it has nothing), and the code is kept. Its other arguments are the form and
       the tag. *)
    nbtEvaluator // Attributes = { HoldRest };
    nbtEvaluator[ results_Association, eval_ ] := Block[
        {
            $nbtEvaluated = { },
            Wolfram`Chatbook`Common`$selectedTools  = <| "WolframLanguageEvaluator" -> True |>,
            Wolfram`Chatbook`Common`evaluateToBoxes = Function[ { code },
                AppendTo[ $nbtEvaluated, code ];
                Lookup[ results, code, <| "Boxes" -> "Null", "Output" -> "\"Null\"" |> ]
            ]
        },
        eval
    ];

    (* What Chatbook gives the model for a tool call that is written with the Simple tool method *)
    nbtRespond[ text_String ] := Wolfram`Chatbook`SendChat`Private`toolResponseString @ GenerateLLMToolResponse[
        LLMConfiguration @ <| "Tools" -> Values @ $nbtTools |>,
        Last @ Wolfram`Chatbook`Common`simpleToolRequestParser @ text
    ];

    (* The real front end with a hidden copy of the notebook as its snapshot. copies is a symbol that gets the copies,
       which the test closes. *)
    nbtRealFE // Attributes = { HoldAll };
    nbtRealFE[ copies_Symbol, eval_ ] := UsingFrontEnd @ Block[
        {
            Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots     = <| |>,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshotCount = 0,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$cellTables    = <| |>,
            Wolfram`Chatbook`$ChatHandlerData                           = <| |>
        },
        Internal`InheritedBlock[ { Wolfram`Chatbook`Tools`NotebookTools`Private`notebookFrontEnd },
            PrependTo[
                DownValues @ Wolfram`Chatbook`Tools`NotebookTools`Private`notebookFrontEnd,
                HoldPattern @ Wolfram`Chatbook`Tools`NotebookTools`Private`notebookFrontEnd[ "Snapshot", source_ ] :> Last @ AppendTo[
                    copies,
                    NotebookPut[
                        Replace[ source, { None :> Notebook @ { }, file_String :> Get @ file, nb_ :> NotebookGet[ nb, "IncludeUUIDs" -> True ] } ],
                        Visible -> False
                    ]
                ]
            ];
            eval
        ]
    ];

    (* Whether a test can show a comparison in a real notebook: its cells have ExpressionUUIDs, and the front end is
       one of 16.0+, the only ones that the tools are enabled for (notebookToolsSupportedQ). A comparison gives the
       notebook a private stylesheet, and the front end of 15.0 on Linux crashes or hangs at a later change of a
       global option once notebooks that were given one have been closed. *)
    nbtShowsDiffQ[ source_NotebookObject ] :=
        Wolfram`Chatbook`Common`sufficientVersionQ[ 16.0 ] && MatchQ[ Cells @ source, { CellObject[ _String, ___ ].. } ];

    (* How a result that leaves edits in a snapshot ends, and what WriteCells gives if it changes nothing *)
    $nbtNotShown = "\n\nThe user does not see this yet: call ShowChanges when your edits are done, before you reply.";
    $nbtNothing  = "Nothing was changed: the cells read as before. Attributes that a tag leaves out keep their values: to remove one, give it empty, e.g. <cell id='c3' CellTags=''/>.";

    $nbtNew   = "<cell style='Text'>\nNew text\n</cell>";
    $nbtText2 = "<cell id='c2' style='Text' CellTags='intro'>\nThe **simple** pendulum, see [the docs](https://www.wolfram.com).\n</cell>";
    $nbtBody3 = "H = <RawBoxes>FractionBox[SuperscriptBox[\"p\", \"2\"], RowBox[{\"2\", \" \", \"m\"}]]</RawBoxes> - g";
    $nbtText3 = "<cell id='c3' style='Input' CellLabel='In[1]:='>\n" <> $nbtBody3 <> "\n</cell>";
    Null,
    Null,
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Registration*)

(* The nine tools are default tools, in order, hidden from the tool manager. Each is found by the machine name a model
   calls it by (EditInCell's canonical name from "edit_incell" would be "EditIncell", so its "Name" is "edit_in_cell"). *)
VerificationTest[
    {
        Keys @ Wolfram`Chatbook`Tools`NotebookTools`$notebookToolSpecs,
        Select[ Keys @ Wolfram`Chatbook`$DefaultTools, MemberQ[ $nbtNames, # ] & ],
        Union[ #[ "Data" ][ "Hidden" ] & /@ Values @ $nbtTools ],
        #[ "Name" ] & /@ Values @ $nbtTools,
        Wolfram`Chatbook`Common`toolShortName /@ Values @ $nbtTools,
        AllTrue[ Values @ $nbtTools, Wolfram`Chatbook`Common`getToolByName[ #[ "Name" ] ] === # & ]
    },
    {
        $nbtNames,
        $nbtNames,
        { True },
        {
            "list_notebooks", "open_notebook", "get_outline", "read_cells", "search_notebook", "edit_in_cell",
            "write_cells", "show_changes", "close_notebook"
        },
        { "nb_list", "nb_open", "nb_outline", "nb_cells", "nb_find", "nb_edit", "nb_write", "nb_show", "nb_close" },
        True
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

(* The parameters in order, and the required ones, which come first: the Simple tool method reads values without
   names in this order. No tool needs the notebook parameter. *)
VerificationTest[
    Map[ { Keys @ #[ "properties" ], #[ "required" ] } &, #[ "JSONSchema" ] & /@ $nbtTools ],
    <|
        "ListNotebooks"  -> { { }, { } },
        "OpenNotebook"   -> { { "notebook" }, { } },
        "GetOutline"     -> { { "notebook", "offset", "limit" }, { } },
        "ReadCells"      -> { { "notebook", "cells", "full" }, { } },
        "SearchNotebook" -> { { "query", "notebook", "regex", "cells", "styles", "limit" }, { "query" } },
        "EditInCell"     -> { { "cell", "edits", "notebook", "evaluate" }, { "cell", "edits" } },
        "WriteCells"     -> { { "cells", "notebook", "evaluate" }, { "cells" } },
        "ShowChanges"    -> { { "notebook" }, { } },
        "CloseNotebook"  -> { { "notebook" }, { } }
    |>,
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Parameters"
]

(* Every request of a sidebar or Notebook Assistant chat carries the tools' descriptions and parameter help (see the
   performance rules in AGENTS.md): their size stays bounded (4896 characters when this test was written) *)
VerificationTest[
    Total @ StringLength @ Flatten @ {
        #[ "Description" ] & /@ Values @ $nbtTools,
        Cases[ #[ "Data" ][ "Parameters" ] & /@ Values @ $nbtTools, KeyValuePattern[ "Help" -> help_String ] :> help, Infinity ]
    },
    _Integer? (LessEqualThan[ 4900 ]),
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-PromptSize"
]

(* The tools' file has its own context, but a name that Common declares is the shared symbol there too: a helper
   that was defined under the name cellStyles cleared the function that the rest of Chatbook calls with a CellObject
   (sending a chat in a chat notebook). No symbol of another context has a definition from the tools' file, but for
   the ones it is there to define. *)
VerificationTest[
    UsingFrontEnd @ Module[ { nb },
        WithCleanup[
            nb = NotebookPut[ Notebook @ { Cell[ "A title", "Title" ], Cell[ "x", "Input", "Extra" ] }, Visible -> False ];
            {
                Wolfram`Chatbook`Common`cellStyles /@ Cells @ nb,
                Complement[
                    Select[
                        StringCases[
                            ReadString @ FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "Source", "Chatbook", "Tools", "NotebookTools.wl" },
                            StartOfLine ~~ name: (WordCharacter | "$").. ~~ " // beginDefinition" :> name
                        ],
                        Names[ "Wolfram`Chatbook`Tools`NotebookTools`Private`" <> # ] === { } &
                    ],
                    { "notebookToolsSupportedQ", "withNotebookCellSyntax" }
                ]
            },
            NotebookClose @ nb
        ]
    ],
    { { { "Title" }, { "Input", "Extra" } }, { } },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-SharedNames"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Gating*)

(* Supported in a kernel of 16.0+ outside the cloud whose front end makes snapshots (all made up here). The front end
   is not probed when an earlier condition fails. *)
VerificationTest[
    UsingFrontEnd @ Block[ { Wolfram`Chatbook`Tools`NotebookTools`Private`snapshotPacketQ, $nbtProbes = 0 },
        Wolfram`Chatbook`Tools`NotebookTools`Private`snapshotPacketQ[ ] := ($nbtProbes++; $nbtPacket);
        Module[ { supported },
            supported[ cloud_, version_, packet_ ] := Block[
                { $CloudEvaluation = cloud, Wolfram`Chatbook`Common`sufficientVersionQ = (version >= # &), $nbtPacket = packet },
                Wolfram`Chatbook`Tools`NotebookTools`notebookToolsSupportedQ[ ]
            ];
            {
                supported[ False, 16.0, True ],
                supported[ False, 16.0, False ],
                $nbtProbes,
                supported[ True, 16.0, True ],
                supported[ False, 15.0, True ],
                $nbtProbes
            }
        ]
    ],
    { True, False, 2, False, False, 2 },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Gating-SupportedQ"
]

(* A front end that makes no snapshots (the stock front ends of 15.0 and 16.0) answers the probe with Null: False; one
   that does gives True. Either way, without a message in the Messages window and with the session's console message
   setting as it was *)
VerificationTest[
    UsingFrontEnd @ Module[ { cells, action, result },
        cells  = Length @ Cells @ MessagesNotebook[ ];
        action = CurrentValue[ $FrontEndSession, { MessageOptions, "ConsoleMessageAction" } ];
        result = Wolfram`Chatbook`Tools`NotebookTools`Private`snapshotPacketProbe[ ];
        {
            result,
            Length @ Cells @ MessagesNotebook[ ] - cells,
            CurrentValue[ $FrontEndSession, { MessageOptions, "ConsoleMessageAction" } ] === action
        }
    ],
    { True | False, 0, True },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Gating-Probe"
]

(* The tools are enabled only in the sidebar and the Notebook Assistant window, and only where they are supported; in
   other chats the support isn't checked at all (that would call the front end) *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Tools`NotebookTools`notebookToolsSupportedQ, $nbtChecks = 0 },
        Wolfram`Chatbook`Tools`NotebookTools`notebookToolsSupportedQ[ ] := ($nbtChecks++; $nbtSupported);
        {
            Table[
                Block[ { Wolfram`Chatbook`$WorkspaceChat = workspace, Wolfram`Chatbook`$SidebarChat = sidebar, $nbtSupported = supported },
                    Union[ #[ "Data" ][ "Enabled" ] & /@ Values @ $nbtTools ]
                ],
                { supported, { True, False } },
                { workspace, { True, False } },
                { sidebar, { True, False } }
            ],
            $nbtChecks = 0;
            Block[ { Wolfram`Chatbook`$WorkspaceChat = False, Wolfram`Chatbook`$SidebarChat = False },
                #[ "Data" ][ "Enabled" ] & /@ Values @ $nbtTools
            ],
            $nbtChecks
        }
    ],
    {
        { { { { True }, { True } }, { { True }, { False } } }, { { { False }, { False } }, { { False }, { False } } } },
        { False.. },
        0
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Enabled"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Snapshots*)

(* The reading tools read the notebook the user is working in as it is, under its id, and make no snapshot. What the
   user changes in the notebook is in the next result. *)
VerificationTest[
    nbtWithFE @ {
        StringStartsQ[ nbt[ "GetOutline" ], "abcdef11 (\"Hamiltonian Mechanics\"), 6 cells" ],
        StringStartsQ[ nbt[ "ReadCells" ], "<cell id='c1' style='Title'>\nHamiltonian Mechanics\n</cell>" ],
        StringStartsQ[ nbt[ "SearchNotebook", <| "query" -> "Mechanics" |> ], "1 match for \"Mechanics\" in abcdef11 (\"Hamiltonian Mechanics\")" ],
        $nbtSources[ $nbtSource ] = ReplacePart[ $nbtSourceCells, { 1, 2 } -> Cell[ "Lagrangian Mechanics", "Title" ] ];
        StringStartsQ[ nbt[ "ReadCells" ], "<cell id='c1' style='Title'>\nLagrangian Mechanics\n</cell>" ],
        { $nbtCount, Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots },
        Developer`ReadRawJSONString[ nbt[ "ListNotebooks" ] ]
    },
    {
        True,
        True,
        True,
        True,
        { 0, <| |> },
        <|
            "notebooks" -> {
                <| "id" -> "abcdef11", "title" -> "Hamiltonian Mechanics", "file" -> "/tmp/Hamiltonian.nb", "modified" -> True, "cells" -> 6, "current" -> True, "snapshot" -> Null |>,
                <| "id" -> "12345678", "title" -> "Other", "file" -> Null, "modified" -> False, "cells" -> 1, "current" -> False, "snapshot" -> Null |>
            },
            "snapshots" -> { }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-DefaultNotebook"
]

(* The first edit makes the snapshot, of the notebook as the user has it then, and says so, and that the user does not
   see the edit yet. After it the reading tools read the snapshot, which has the edit, also when they name the
   notebook. *)
VerificationTest[
    nbtWithFE @ {
        nbt[ "ReadCells", <| "cells" -> "c5" |> ],
        $nbtSources[ $nbtSource ] = ReplacePart[ $nbtSourceCells, { 1, 2 } -> Cell[ "Lagrangian Mechanics", "Title" ] ];
        nbt[ "EditInCell", <| "cell" -> "c5", "edits" -> { <| "oldText" -> "motion", "newText" -> "rest" |> } |> ],
        $nbtCount,
        nbtCells[ ][[ 1 ]],
        nbt[ "ReadCells", <| "cells" -> "c5" |> ],
        nbt[ "ReadCells", <| "notebook" -> "abcdef11", "cells" -> "c5" |> ],
        Developer`ReadRawJSONString[ nbt[ "ListNotebooks" ] ][ "snapshots" ],
        $nbtSources[ $nbtSource ][[ 5, 2 ]]
    },
    {
        "<cell id='c5' style='Section'>\nEquations of motion\n</cell>",
        "Opened s1 (\"Hamiltonian Mechanics\"), a snapshot of the notebook.\n\nEdited c5 of s1. It now reads:\n<cell id='c5' style='Section'>\nEquations of rest\n</cell>" <> $nbtNotShown,
        1,
        Cell[ "Lagrangian Mechanics", "Title" ],
        "<cell id='c5' style='Section'>\nEquations of rest\n</cell>",
        "<cell id='c5' style='Section'>\nEquations of rest\n</cell>",
        { <| "notebook" -> "s1", "title" -> "Hamiltonian Mechanics", "source" -> "abcdef11", "edited" -> True |> },
        Cell[ "Equations of motion", "Section" ]
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-SnapshotAtFirstEdit"
]

(* An edit that fails, and one that changes nothing, leave no snapshot, and the next one is s1 again *)
VerificationTest[
    nbtWithFE @ {
        nbtEditCell[ "c2", "Pendulum" -> "x" ],
        nbt[ "ReadCells", <| "cells" -> "c2" |> ]; nbt[ "WriteCells", <| "cells" -> $nbtText2 |> ],
        { $nbtCount, $nbtClosed, Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots },
        nbt[ "ShowChanges" ],
        nbtWriteCells @ $nbtNew
    },
    {
        "The oldText \"Pendulum\" does not occur in the content of c2. Copy it exactly from ReadCells. Nothing was written.",
        $nbtNothing,
        { 2, { NotebookObject[ "snapshot-1" ], NotebookObject[ "snapshot-2" ] }, <| |> },
        "No snapshot is open.",
        "Wrote to s1: new c7 (Text) at the end."
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-NoSnapshotWithoutEdits"
]

(* Models guess a handle: one that is not open in a chat without snapshots is the user's notebook too. Another open
   notebook is named by its id, its title or its file, and is read as it is. Once the chat has a snapshot of a notebook,
   that is what is read. With several snapshots the tool says which there are, and a name that is nothing, or more
   than one notebook, is an error. *)
VerificationTest[
    nbtWithFE @ {
        StringStartsQ[ nbt[ "GetOutline", <| "notebook" -> "s1" |> ], "abcdef11 (\"Hamiltonian Mechanics\"), 6 cells" ],
        StringStartsQ[ nbt[ "GetOutline", <| "notebook" -> "12345678" |> ], "12345678 (\"Other\"), 1 cells" ],
        StringStartsQ[ nbt[ "GetOutline", <| "notebook" -> " Other " |> ], "12345678 (\"Other\"), 1 cells" ],
        nbt[ "GetOutline", <| "notebook" -> "nothing" |> ],
        Block[ { $nbtListed = Append[ $nbtListed, <| First @ $nbtListed, "ID" -> "abcdef22" |> ] }, nbt[ "GetOutline", <| "notebook" -> "Hamiltonian Mechanics" |> ] ],
        $nbtCount,
        nbtWriteCells @ $nbtNew; nbtWriteCells[ $nbtNew, "notebook" -> "12345678" ]; nbt[ "GetOutline" ],
        StringStartsQ[ nbt[ "GetOutline", <| "notebook" -> "12345678" |> ], "s2 (\"Other\"), 2 cells" ],
        nbt[ "GetOutline", <| "notebook" -> "s7" |> ],
        nbt[ "ShowChanges", <| "notebook" -> "s7" |> ],
        $nbtCount
    },
    {
        True,
        True,
        True,
        "\"nothing\" is not an open snapshot, and no open notebook or .nb file matches it.",
        "\"Hamiltonian Mechanics\" matches more than one notebook: abcdef11 (\"Hamiltonian Mechanics\"), abcdef22 (\"Hamiltonian Mechanics\"). Give its id, its title or its file.",
        0,
        "Several snapshots are open: s1 (\"Hamiltonian Mechanics\"), s2 (\"Other\"). Give one of them as notebook.",
        True,
        "\"s7\" is not an open snapshot (open: s1 (\"Hamiltonian Mechanics\"), s2 (\"Other\")), and no open notebook or .nb file matches it.",
        "\"s7\" is not an open snapshot (open: s1 (\"Hamiltonian Mechanics\"), s2 (\"Other\")).",
        2
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-NotebookArgument"
]

(* Without a notebook that the user is working in, the tools say what to do, and ShowChanges and CloseNotebook open
   nothing *)
VerificationTest[
    nbtWithFE @ Block[ { $nbtUser = None },
        { nbt[ "ReadCells" ], nbt[ "ShowChanges" ], nbt[ "CloseNotebook" ], $nbtCount }
    ],
    {
        "The notebook the user is working in was not found. OpenNotebook opens a notebook that ListNotebooks lists.",
        "No snapshot is open.",
        "No snapshot is open.",
        0
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-NoUserNotebook"
]

(* OpenNotebook reads a listed notebook, named by its id (or a start of it, or its whole UUID), its title or its file,
   as it is: it gives a line about the notebook and its cells, and makes no snapshot. Once the chat has edited the
   notebook, it gives the snapshot. The name is taken without the quotes and the white space that a model puts around
   it: a file, a title and a handle in quotes are the same notebooks (the file is not read from the disk). *)
VerificationTest[
    nbtWithFE @ {
        nbt[ "OpenNotebook", <| "notebook" -> "12345678" |> ],
        nbt[ "OpenNotebook", <| "notebook" -> " Other " |> ],
        StringStartsQ[ nbt[ "OpenNotebook", <| "notebook" -> "ABCDEF" |> ], "abcdef11 (\"Hamiltonian Mechanics\"): an open notebook, 6 cells.\n\n<cell id='c1' style='Title'>\nHamiltonian Mechanics\n</cell>\n\n" ],
        StringStartsQ[ nbt[ "OpenNotebook", <| "notebook" -> "abcdef11-0000-4000-8000-000000000001" |> ], "abcdef11 (\"Hamiltonian Mechanics\"): an open notebook, 6 cells." ],
        StringStartsQ[ nbt[ "OpenNotebook", <| "notebook" -> "/tmp/Hamiltonian.nb" |> ], "abcdef11 " ],
        StringStartsQ[ nbt[ "OpenNotebook", <| "notebook" -> " \"/tmp/Hamiltonian.nb\"" |> ], "abcdef11 (\"Hamiltonian Mechanics\"): an open notebook, 6 cells." ],
        StringStartsQ[ nbt[ "ReadCells", <| "notebook" -> "'Other'" |> ], "<cell id='c1' style='Text'>\nAnother notebook\n</cell>" ],
        nbt[ "OpenNotebook", <| "notebook" -> "abc" |> ],
        $nbtCount,
        nbtWriteCells[ $nbtNew, "notebook" -> "12345678" ]; nbt[ "OpenNotebook", <| "notebook" -> "12345678" |> ],
        StringStartsQ[ nbt[ "OpenNotebook", <| "notebook" -> "\"s1\"" |> ], "s1 (\"Other\"): a snapshot of the notebook 12345678 with your edits, 2 cells." ]
    },
    {
        "12345678 (\"Other\"): an open notebook, 1 cells.\n\n<cell id='c1' style='Text'>\nAnother notebook\n</cell>",
        "12345678 (\"Other\"): an open notebook, 1 cells.\n\n<cell id='c1' style='Text'>\nAnother notebook\n</cell>",
        True,
        True,
        True,
        True,
        True,
        "\"abc\" is not an open snapshot, and no open notebook or .nb file matches it.",
        0,
        "s1 (\"Other\"): a snapshot of the notebook 12345678 with your edits, 2 cells.\n\n<cell id='c1' style='Text'>\nAnother notebook\n</cell>\n\n<cell id='c2' style='Text'>\nNew text\n</cell>",
        True
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-OpenNotebook"
]

(* The names of files are compared as text: expanded, with one kind of separator, and without regard to letter case
   where the file system has none. A listed notebook is found by its file in any such spelling and read as it is.
   Nothing is asked of the disk or the network: where letter case counts, the name of a file that exists in another
   case is another file, whatever the file system takes it for, and a name on an address that does not answer takes
   no time. *)
VerificationTest[
    nbtWithFE @ Module[ { same = Wolfram`Chatbook`Tools`NotebookTools`Private`sameFileQ, file },
        file = FileNameJoin @ { $TemporaryDirectory, "nbt-" <> CreateUUID[ ] <> ".nb" };
        WithCleanup[
            Put[ Notebook[ { } ], file ];
            {
                Block[ { Wolfram`Chatbook`Tools`NotebookTools`Private`$ignoreFileCase = True },
                    {
                        StringStartsQ[ nbt[ "OpenNotebook", <| "notebook" -> "/TMP/sub/../HAMILTONIAN.NB" |> ], "abcdef11 (\"Hamiltonian Mechanics\"): an open notebook, 6 cells." ],
                        same[ file, ToUpperCase @ file ]
                    }
                ],
                Block[ { Wolfram`Chatbook`Tools`NotebookTools`Private`$ignoreFileCase = False },
                    {
                        nbt[ "OpenNotebook", <| "notebook" -> "/TMP/HAMILTONIAN.NB" |> ],
                        same[ file, ToUpperCase @ file ],
                        same[ "/tmp/sub/../Hamiltonian.nb", "/tmp/./Hamiltonian.nb" ]
                    }
                ],
                First @ AbsoluteTiming[ same[ "\\\\192.0.2.1\\share\\x.nb", file ] ] < 1,
                $nbtCount
            },
            DeleteFile @ file
        ]
    ],
    {
        { True, True },
        { "\"/TMP/HAMILTONIAN.NB\" is not an open snapshot, and no open notebook or .nb file matches it.", False, True },
        True,
        0
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-FileNames"
]

(* A .nb file that is not open is opened as a snapshot, which the result says, and is then read from it. Without its
   argument OpenNotebook makes a new notebook. Cells that do not fit into one result are an outline. A file whose
   notebook says that it is excluded from chats is not opened: its snapshot is closed again. *)
VerificationTest[
    nbtWithFE @ Module[ { file, name },
        file = FileNameJoin @ { $TemporaryDirectory, "nbt-" <> CreateUUID[ ] <> ".nb" };
        WithCleanup[
            Put[ Notebook[ { } ], file ];
            (* what the tools open is the name that they were given, expanded: here in another spelling *)
            name = ExpandFileName @ file;
            file = StringReplace[ name, $PathnameSeparator -> "/" ];
            $nbtSources[ name ] = $nbtSourceCells;
            {
                StringStartsQ[
                    nbt[ "OpenNotebook", <| "notebook" -> file |> ],
                    "Opened s1 (\"" <> FileNameTake @ file <> "\"), a snapshot of the notebook.\n\ns1 (\"" <> FileNameTake @ file <> "\"): a snapshot of " <> name <> ", 6 cells.\n\n<cell id='c1'"
                ],
                nbt[ "ReadCells", <| "notebook" -> file, "cells" -> "c5" |> ],
                nbt[ "OpenNotebook" ],
                Block[ { Wolfram`Chatbook`Tools`NotebookTools`Private`$readBudget = 100, Wolfram`Chatbook`Tools`NotebookTools`Private`$outlineLimit = 2 },
                    nbt[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ]
                ],
                Developer`ReadRawJSONString[ nbt[ "ListNotebooks" ] ][ "snapshots" ][[ All, "source" ]] === { name, Null },
                $nbtCount,
                nbt[ "CloseNotebook", <| "notebook" -> "s1" |> ];
                Block[ { $nbtExcluded = True }, nbt[ "ReadCells", <| "notebook" -> file |> ] ] === "\"" <> FileNameTake @ file <> "\" is a notebook that the user excluded from AI chats, so it is not read or edited.",
                { $nbtCount, Last @ $nbtClosed, Keys @ Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots }
            },
            DeleteFile @ file
        ]
    ],
    {
        True,
        "<cell id='c5' style='Section'>\nEquations of motion\n</cell>",
        "s2 (\"Untitled\"): a snapshot of a new notebook, 0 cells.",
        "abcdef11 (\"Hamiltonian Mechanics\"): an open notebook, 6 cells. They do not fit into one result, so this is an outline (id, style, start of content):\nc1 (Title) Hamiltonian Mechanics\nc2 (Text) The **simple** pendulum, see [the docs](https://www.wolfram.com).\n[Cells 1-2 of 6. GetOutline with offset 3 gives the next ones.]",
        True,
        2,
        True,
        { 3, NotebookObject[ "snapshot-3" ], { "s2" } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-OpenNotebook-FileAndNew"
]

(* A snapshot belongs to the chat that opened it: another chat does not see it and reads the notebook, and when that
   chat edits the same notebook the stale snapshot is closed. At most $maxSnapshots are open, and a snapshot of an
   earlier chat makes room. *)
VerificationTest[
    nbtWithFE @ Block[ { Wolfram`Chatbook`Tools`NotebookTools`Private`$maxSnapshots = 3 },
        {
            nbtChat[ "chat-1", nbtWriteCells @ $nbtNew; nbt[ "OpenNotebook" ]; nbt[ "OpenNotebook" ]; nbt[ "OpenNotebook" ] ],
            nbtChat[ "chat-1", nbt[ "CloseNotebook", <| "notebook" -> "s3" |> ] ],
            nbtChat[ "chat-2", nbt[ "CloseNotebook" ] ],
            nbtChat[ "chat-2", StringStartsQ[ nbt[ "GetOutline" ], "abcdef11 (\"Hamiltonian Mechanics\"), 6 cells" ] ],
            (* two snapshots are open, so there is room: s1 is closed because it is of the same notebook *)
            nbtChat[ "chat-2", StringStartsQ[ nbt[ "WriteCells", <| "cells" -> $nbtNew |> ], "Opened s4 " ] ],
            $nbtClosed,
            (* the second one is the fourth snapshot: s2 of chat-1 makes room *)
            nbtChat[ "chat-2", nbt[ "OpenNotebook" ]; StringStartsQ[ nbt[ "OpenNotebook" ], "s6 " ] ],
            $nbtClosed,
            nbtChat[ "chat-1", nbt[ "CloseNotebook" ] ]
        }
    ],
    {
        "3 snapshots are open already, the most there can be: s1 (\"Hamiltonian Mechanics\"), s2 (\"Untitled\"), s3 (\"Untitled\"). Show the changes of one with ShowChanges, or close one with CloseNotebook, before opening another.",
        "Closed s3; its edits were discarded.",
        "No snapshot is open.",
        True,
        True,
        { NotebookObject[ "snapshot-3" ], NotebookObject[ "snapshot-1" ] },
        True,
        { NotebookObject[ "snapshot-3" ], NotebookObject[ "snapshot-1" ], NotebookObject[ "snapshot-2" ] },
        "No snapshot is open."
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ChatSnapshots"
]

(* CloseNotebook closes the snapshot and discards its edits: the user's notebook is as it was. A snapshot that the
   front end can't make is an error. *)
VerificationTest[
    nbtWithFE @ {
        nbtWriteCells @ $nbtNew; nbt[ "CloseNotebook" ],
        $nbtClosed,
        Developer`ReadRawJSONString[ nbt[ "ListNotebooks" ] ][ "snapshots" ],
        $nbtSources[ $nbtSource ] === $nbtSourceCells,
        Block[ { $nbtListed = { <| "NotebookObject" -> "fail", "ID" -> "ffffffff", "Title" -> "Broken", "File" -> None, "Modified" -> False |> } },
            nbtWriteCells[ $nbtNew, "notebook" -> "ffffffff" ]
        ]
    },
    {
        "Closed s1; its edits were discarded.",
        { NotebookObject[ "snapshot-1" ] },
        { },
        True,
        "The front end could not make a snapshot of \"Broken\"."
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-CloseNotebook"
]

(* An error is a failure whose text Chatbook gives the model *)
VerificationTest[
    nbtWithFE @ $nbtTools[ "CloseNotebook" ][ <| |> ],
    KeyValuePattern @ { "Result" -> Failure[ "NotebookToolError", _ ], "String" -> "No snapshot is open." },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ErrorResult"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Reading*)

(* ReadCells gives the cells in the cell syntax: ids, styles, labels and tags in the tag, text as Markdown, code as
   typed with its boxes in <RawBoxes>, and a generated cell as the Markdown that it always was *)
VerificationTest[
    nbtWithFE @ nbt[ "ReadCells", <| "notebook" -> "abcdef11" |> ],
    StringRiffle[
        {
            "<cell id='c1' style='Title'>\nHamiltonian Mechanics\n</cell>",
            $nbtText2,
            $nbtText3,
            "<cell id='c4' style='Output' CellLabel='Out[1]='>\n42\n</cell>",
            "<cell id='c5' style='Section'>\nEquations of motion\n</cell>",
            "<cell id='c6' style='Input'>\nf[x]\n</cell>"
        },
        "\n\n"
    ],
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ReadCells"
]

(* cells takes ids as models write them and ranges, which are the cells from one to the other in the notebook, and
   "all", as text or as a list (a JSON array of a native call). The cells come in the order of the notebook. What
   names no cell or is no range is an error that says what cells takes. *)
VerificationTest[
    nbtWithFE @ Module[ { ids },
        ids[ cells_ ] := StringCases[ nbt[ "ReadCells", <| "cells" -> cells |> ], "<cell id='" ~~ id: WordCharacter.. :> id ];
        {
            ids[ "c5, #C2 - c3; 1" ],
            ids[ "[\"c6\", \"c4\"]" ],
            ids[ { "c6", "c2-c1" } ],
            nbt[ "ReadCells", <| "cells" -> "c2, c9" |> ],
            nbt[ "ReadCells", <| "cells" -> " All " |> ] === nbt[ "ReadCells" ],
            StringStartsQ[ nbt[ "SearchNotebook", <| "query" -> "i", "cells" -> "all" |> ], "8 matches " ],
            nbt[ "ReadCells", <| "cells" -> "c1, -" |> ],
            nbt[ "ReadCells", <| "cells" -> "c1-c2-c3" |> ],
            nbt[ "SearchNotebook", <| "query" -> "i", "cells" -> "[]" |> ]
        }
    ],
    {
        { "c1", "c2", "c3", "c5" },
        { "c4", "c6" },
        { "c1", "c2", "c6" },
        "abcdef11 has no cell \"c9\". GetOutline gives the ids of its cells.",
        True,
        True,
        "\"-\" in the parameter cells is not a cell id or a range of two ids such as c10-c20.",
        "\"c1-c2-c3\" in the parameter cells is not a cell id or a range of two ids such as c10-c20.",
        "The parameter cells names no cell (\"[]\"): give ids and ranges, e.g. \"c3, c10-c20\", or leave it out for all cells."
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ReadCells-Cells"
]

(* A result shows the cells that fit into $readBudget (at least one), and says where the rest starts. The body of a
   long cell is cut, and the tag says so, unless full is true. *)
VerificationTest[
    nbtWithFE @ Block[ { Wolfram`Chatbook`Tools`NotebookTools`Private`$readBudget = 60, Wolfram`Chatbook`Tools`NotebookTools`Private`$cellLength = 30 },
        {
            nbt[ "ReadCells" ],
            nbt[ "ReadCells", <| "cells" -> "c2" |> ],
            nbt[ "ReadCells", <| "cells" -> "c2", "full" -> True |> ]
        }
    ],
    {
        "<cell id='c1' style='Title'>\nHamiltonian Mechanics\n</cell>\n\n[Not shown: c2 and the 4 cells after it. Read them with ReadCells, cells \"c2-c6\".]",
        _String? (StringStartsQ[ #, "<cell id='c2' style='Text' CellTags='intro' truncated='true'>\nThe **simple" ] && StringLength @ # < StringLength @ $nbtText2 &),
        $nbtText2
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ReadCells-Limits"
]

(* GetOutline gives a line for each cell, and long notebooks in parts *)
VerificationTest[
    nbtWithFE @ { nbt[ "GetOutline" ], nbt[ "GetOutline", <| "offset" -> 4, "limit" -> 2 |> ], nbt[ "GetOutline", <| "offset" -> 7 |> ] },
    {
        "abcdef11 (\"Hamiltonian Mechanics\"), 6 cells (id, style, start of content):\nc1 (Title) Hamiltonian Mechanics\nc2 (Text) The **simple** pendulum, see [the docs](https://www.wolfram.com).\nc3 (Input) H = <RawBoxes>FractionBox[SuperscriptBox[\"p\", \"2\"], RowBox[{\"2\", \" \", \"m\"}]]</Ra\[Ellipsis]\nc4 (Output) 42\nc5 (Section) Equations of motion\nc6 (Input) f[x]",
        "abcdef11 (\"Hamiltonian Mechanics\"), 6 cells (id, style, start of content):\nc4 (Output) 42\nc5 (Section) Equations of motion\n[Cells 4-5 of 6. GetOutline with offset 6 gives the next ones.]",
        "The offset 7 is past the last cell: abcdef11 has 6 cells."
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-GetOutline"
]

(* SearchNotebook finds text in the bodies as ReadCells shows them: a literal string or a regular expression, in all
   cells or in some. The note on the matches beyond the limit names the cells that have them. *)
VerificationTest[
    nbtWithFE @ {
        nbt[ "SearchNotebook", <| "query" -> "pendulum" |> ],
        nbt[ "SearchNotebook", <| "query" -> "^[a-z]\\[", "regex" -> True |> ],
        nbt[ "SearchNotebook", <| "query" -> "i", "styles" -> "section, Title", "limit" -> 2 |> ],
        nbt[ "SearchNotebook", <| "query" -> "i", "cells" -> "c5-c6", "styles" -> { "Section" } |> ],
        nbt[ "SearchNotebook", <| "query" -> "^[a-z]\\[" |> ],
        nbt[ "SearchNotebook", <| "query" -> "(", "regex" -> True |> ],
        nbt[ "SearchNotebook", <| "query" -> "" |> ]
    },
    {
        "1 match for \"pendulum\" in abcdef11 (\"Hamiltonian Mechanics\") (id (style) line:column: the line):\nc2 (Text) 1:16: The **simple** pendulum, see [the docs](https://www.wolfram.com).",
        "1 match for \"^[a-z]\\[\" in abcdef11 (\"Hamiltonian Mechanics\") (id (style) line:column: the line):\nc6 (Input) 1:1: f[x]",
        "5 matches for \"i\" in abcdef11 (\"Hamiltonian Mechanics\") (id (style) line:column: the line):\nc1 (Title) 1:4: Hamiltonian Mechanics\nc1 (Title) 1:9: Hamiltonian Mechanics\n[These are the first 2. The other 3 are in c1, c5: limit shows more, and cells and styles narrow a search.]",
        "2 matches for \"i\" in abcdef11 (\"Hamiltonian Mechanics\") (id (style) line:column: the line):\nc5 (Section) 1:6: Equations of motion\nc5 (Section) 1:17: Equations of motion",
        "No matches for \"^[a-z]\\[\" in abcdef11 (\"Hamiltonian Mechanics\").",
        "\"(\" is not a valid regular expression.",
        "The parameter query is missing or empty."
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-SearchNotebook"
]

(* A cell that the user excluded from chats (by its settings or its style, as in the notebook context) is not shown,
   and the result says how many were left out. A search does not find it, and it is not edited, moved or deleted. A
   new cell can still be placed next to it. *)
VerificationTest[
    nbtWithFE @ Block[ { $nbtSources = <| $nbtSource -> {
            { "u1", Cell[ "A title", "Title" ] },
            { "u2", Cell[ "A private note", "Text", TaggingRules -> <| "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |> |> ] },
            { "u3", Cell[ "Another private note", "Text", "ChatExcluded" ] },
            { "u4", Cell[ "Some text", "Text" ] }
        } |> },
        {
            nbt[ "ReadCells" ],
            nbt[ "ReadCells", <| "cells" -> "c2" |> ],
            nbt[ "GetOutline" ],
            nbt[ "OpenNotebook", <| "notebook" -> "abcdef11" |> ] === "abcdef11 (\"Hamiltonian Mechanics\"): an open notebook, 4 cells.\n\n" <> nbt[ "ReadCells" ],
            nbt[ "SearchNotebook", <| "query" -> "private" |> ],
            nbtEditCell[ "c2", "private" -> "public" ],
            nbtWriteCells[ "<cell id='c3'>\nA public note\n</cell>" ] === nbtWriteCells[ "<cell id='c3' before='c1'/>" ] === nbtWriteCells[ "<cell id='c3' delete='true'/>" ],
            nbtWriteCells[ "<cell id='c3' delete='true'/>" ],
            { $nbtWrites, Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots },
            nbtWriteCells[ "<cell style='Text' after='c2'>\nNew text\n</cell>" ],
            First /@ nbtCells @ $nbtCount
        }
    ],
    {
        "<cell id='c1' style='Title'>\nA title\n</cell>\n\n<cell id='c4' style='Text'>\nSome text\n</cell>\n\n[2 cells that the user excluded from AI chats are left out.]",
        "[1 cell that the user excluded from AI chats is left out.]",
        "abcdef11 (\"Hamiltonian Mechanics\"), 4 cells (id, style, start of content):\nc1 (Title) A title\nc4 (Text) Some text\n[2 cells that the user excluded from AI chats are left out.]",
        True,
        "No matches for \"private\" in abcdef11 (\"Hamiltonian Mechanics\").",
        "c2 is a cell that the user excluded from AI chats, so it is not read or changed. Nothing was written.",
        True,
        "c3 is a cell that the user excluded from AI chats, so it is not read or changed. Nothing was written.",
        { { }, <| |> },
        "Wrote to s1: new c5 (Text) after c2.",
        { "A title", "A private note", "New text", "Another private note", "Some text" }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ExcludedCells"
]

(* A cell has one id in a chat: the notebook context (withNotebookCellSyntax on the user's notebook) and the tools (on
   a snapshot of it) give the same id to the same cell, and a cell that either sees later gets the next number *)
VerificationTest[
    nbtWithFE @ Module[ { context },
        context[ uuid_String ] := Wolfram`Chatbook`Common`withNotebookCellSyntax[
            $nbtSource,
            CellToString @ Cell[ "Some text", "Text", CellObject -> CellObject[ uuid, "another instance" ] ]
        ];
        {
            context[ "u5" ],
            context[ "new-in-the-notebook" ],
            nbtWriteCells @ $nbtNew,
            context[ "another-new-one" ],
            StringCases[ nbt[ "GetOutline" ], StartOfLine ~~ id: ("c" ~~ DigitCharacter..) ~~ " " :> id ]
        }
    ],
    {
        "<cell id='c5' style='Text'>\nSome text\n</cell>",
        "<cell id='c7' style='Text'>\nSome text\n</cell>",
        "Wrote to s1: new c8 (Text) at the end.",
        "<cell id='c9' style='Text'>\nSome text\n</cell>",
        { "c1", "c2", "c3", "c4", "c5", "c6", "c8" }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-SharedCellIDs"
]

(* The ids of a notebook are kept for each chat, for the $maxCellTables pairs of chat and notebook that were used
   last *)
VerificationTest[
    nbtWithFE @ Block[ { Wolfram`Chatbook`Tools`NotebookTools`Private`$maxCellTables = 2 },
        Module[ { id },
            id[ chat_String, uuid_String ] := nbtChat[
                chat,
                Wolfram`Chatbook`Common`withNotebookCellSyntax[ $nbtSource, Wolfram`Chatbook`Common`$cellIDFunction @ CellObject[ uuid, "i" ] ]
            ];
            {
                id[ "chat-1", "x" ], id[ "chat-1", "y" ], id[ "chat-2", "u2" ], id[ "chat-1", "y" ], id[ "chat-3", "z" ],
                (* chat-1 was used after chat-2, so its ids are kept, and those of chat-2 are not: *)
                id[ "chat-1", "y" ], id[ "chat-2", "y" ],
                Length @ Wolfram`Chatbook`Tools`NotebookTools`Private`$cellTables
            }
        ]
    ],
    { "c7", "c8", "c2", "c8", "c7", "c8", "c7", 2 },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-CellTables"
]

(* A notebook that shows the changes of a comparison has CellDiff's tags and options on the cells that show a change.
   They are not the user's: the tag of a cell does not have them. *)
VerificationTest[
    nbtWithFE @ Block[ { $nbtSources = <| $nbtSource -> {
            { "u1", Cell[ "Changed text", "Text", CellTags -> { "intro", "NotebookDiff" }, CellDiffOptions -> { "ViewMode" -> "Lines" }, CellDiff -> FE`CellDiffData[ 1, Cell[ "Old", "Text" ] ] ] },
            { "u2", Cell[ "", "Text", CellTags -> { "NotebookDiff", "NotebookDiffDeleted" }, CellDiff -> FE`CellDiffData[ 1, Cell[ "Deleted", "Text" ] ] ] },
            { "u3", Cell[ "Inserted", "Text", CellTags -> { "NotebookDiff", "NotebookDiffInserted" }, Background -> Red ] },
            { "u4", Cell[ "Tagged", "Text", CellTags -> { "a", "b" } ] }
        } |> },
        nbt[ "ReadCells" ]
    ],
    "<cell id='c1' style='Text' CellTags='intro'>\nChanged text\n</cell>\n\n<cell id='c2' style='Text'>\n\n</cell>\n\n<cell id='c3' style='Text' options='Background -> RGBColor[1, 0, 0]'>\nInserted\n</cell>\n\n<cell id='c4' style='Text' CellTags='a,b'>\nTagged\n</cell>",
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ReadCells-DiffOptions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*EditInCell*)

(* EditInCell replaces text in the body of a cell and gives the cell as it now reads. The cell is replaced as a
   whole, with its ExpressionUUID, so it keeps its id, and what the edit leaves alone is the boxes that it was. *)
VerificationTest[
    nbtWithFE @ {
        nbtEditCell[ "c2", "pendulum" -> "*ideal* pendulum" ],
        nbtCells[ ][[ 2 ]],
        $nbtWrites
    },
    {
        "Edited c2 of s1. It now reads:\n<cell id='c2' style='Text' CellTags='intro'>\nThe **simple** *ideal* pendulum, see [the docs](https://www.wolfram.com).\n</cell>",
        Cell[ TextData @ { "The ", $nbtBold, " ", StyleBox[ "ideal", FontSlant -> Italic ], " pendulum, see ", $nbtLink, "." }, "Text", CellTags -> "intro" ],
        { { { "Replace", "u2", Cell[ _TextData, "Text", CellTags -> "intro", ExpressionUUID -> "u2" ] } } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-EditInCell"
]

(* Code is tokenized again, and a box that the edit leaves alone stays the box that it was. Several edits apply in
   order, each as often as its count says. *)
VerificationTest[
    nbtWithFE[
        nbt[ "EditInCell", <| "cell" -> "c3", "edits" -> { <| "oldText" -> " - g", "newText" -> " + z + z" |>, <| "oldText" -> "z", "newText" -> "V[q]", "count" -> 2 |> } |> ];
        nbtCells[ ][[ 3 ]]
    ],
    Cell[
        BoxData @ RowBox @ { "H", "=", RowBox @ { FractionBox[ SuperscriptBox[ "p", "2" ], RowBox @ { "2", " ", "m" } ], "+", RowBox @ { "V", "[", "q", "]" }, "+", RowBox @ { "V", "[", "q", "]" } } },
        "Input",
        CellLabel -> "In[1]:="
    ],
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-EditInCell-Code"
]

(* The edits apply all or none: text that does not occur, or not as often as count says, leaves the cell as it was.
   The content of a generated cell is not edited: the message says what to do with one. *)
VerificationTest[
    nbtWithFE[
        {
            nbtEditCell[ "c2", { "simple" -> "easy", "Pendulum" -> "x" } ],
            nbtEditCell[ "c2", "e" -> "E" ],
            nbtEditCell[ "c2", "" -> "x" ],
            nbtEditCell[ "c9", "a" -> "b" ],
            nbt[ "EditInCell", <| "cell" -> "c2", "edits" -> { } |> ],
            nbtEditCell[ "c4", "42" -> "43" ],
            nbtEditCell[ "c2", "a\n</cell>\n<cell style='Text'>\nb" -> "x" ],
            $nbtWrites
        }
    ],
    {
        "The oldText \"Pendulum\" does not occur in the content of c2. Copy it exactly from ReadCells. Nothing was written.",
        "The oldText \"e\" occurs 6 times in the content of c2, not 1. It also matches inside longer names: make it longer to change only some of them, or give count 6 to change all. Nothing was written. The places (line:column and the text there): 1:3 The **simpl | 1:12  **simple** pendu | 1:17 mple** pendulum,  | 1:27 dulum, see [the d | 1:28 ulum, see [the do | 1:33  see [the docs](h",
        "Edit 1 has no oldText. To insert text, give the text next to it as oldText and both as newText.",
        "s1 has no cell \"c9\". GetOutline gives the ids of its cells.",
        "The parameter edits must be a list of edits {oldText, newText, count}, e.g. [{\"oldText\": \"a\", \"newText\": \"b\"}].",
        "c4 is a generated cell (an output, a message, a print): its content is not written as text. Write its Input cell with evaluate: true, which replaces its outputs. A tag without content moves a generated cell as it is (<cell id='c48' after='c47'/>) or deletes it (<cell id='c48' delete='true'/>). Nothing was written.",
        "The oldText \"a\n</cell>\n<cell style='Text'>\nb\" does not occur in the content of c2. Copy it exactly from ReadCells. Nothing was written.",
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-EditInCell-Errors"
]

(* An edit can't make two cells of one, and what cellsFromString refuses is not written *)
VerificationTest[
    nbtWithFE[
        {
            nbtEditCell[ "c1", "Hamiltonian" -> "A\n</cell>\nB" ],
            nbtEditCell[ "c1", "Hamiltonian" -> "<RawBoxes>DynamicBox[ToBoxes[1]]</RawBoxes>" ],
            $nbtWrites
        }
    ],
    {
        "The edits put a cell tag into c1, which is one cell. Write a < that is text as &lt;. Nothing was written.",
        _String? (StringStartsQ[ #, "Cell c1 has <RawBoxes> that " ] && StringEndsQ[ #, " Nothing was written." ] &),
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-EditInCell-Refused"
]

(* The notebook context shows the markers of a selection in a body. They are not content: an oldText that has them is
   matched without them, and the writer takes them out of new text. In a string of code that the model writes a
   marker is content, which is written. *)
VerificationTest[
    nbtWithFE[
        nbt[ "ReadCells" ];
        {
            nbtEditCell[ "c5", "<selection>Equations</selection> of" -> "Laws of<selection></selection>" ],
            nbtWriteCells[ "<cell id='c6'>\ns = \"<selection>\";<selection></selection>\n</cell>" ]; nbtCells[ ][[ 6 ]],
            nbtEditCell[ "c3", " - g" -> " - \"</selection>\"" ]; nbtCells[ ][[ 3, 1 ]]
        }
    ],
    {
        "Edited c5 of s1. It now reads:\n<cell id='c5' style='Section'>\nLaws of motion\n</cell>",
        Cell[ BoxData @ RowBox @ { RowBox @ { "s", "=", "\"<selection>\"" }, ";" }, "Input" ],
        BoxData @ RowBox @ { "H", "=", RowBox @ { FractionBox[ SuperscriptBox[ "p", "2" ], RowBox @ { "2", " ", "m" } ], "-", "\"</selection>\"" } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-SelectionMarkers"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WriteCells*)

(* One call replaces content, changes attributes, makes new cells (after the cell before them in the text, where after
   or before says, or at the end), moves and deletes cells. An id is read as models write it. The result says where
   each run of new cells is. Only the cells that read differently afterwards are edits: a cell that is only moved is
   not. *)
VerificationTest[
    nbtWithFE @ {
        nbt[ "ReadCells", <| "cells" -> "c5" |> ];
        nbtWriteCells[ "
<cell id='c5'>
Equations of **motion**
</cell>
<cell style='Text'>
After the section.
</cell>

<cell id=\"C1\" style='Chapter' CellTags='top'/>
<cell id='#2' CellTags=''/>
<cell id='c4' delete='true'/>
<cell style='Item' before='c2'>
First
</cell>
<cell id='c6' after='c1'/>
<cell style='Text' after='c6'>
Right after the moved cell.
</cell>
<cell style='Input'>
1 + 1
</cell>
" ],
        nbtCells[ ],
        Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots[ "s1", "Edits" ]
    },
    {
        "Wrote to s1: changed c5, c1, c2; new c9 (Text), c10 (Input), c8 (Item) after c6; new c7 (Text) at the end; moved c6; deleted c4.",
        {
            Cell[ "Hamiltonian Mechanics", "Chapter", CellTags -> "top" ],
            Cell[ BoxData @ RowBox @ { "f", "[", "x", "]" }, "Input" ],
            Cell[ "Right after the moved cell.", "Text" ],
            Cell[ BoxData @ RowBox @ { "1", "+", "1" }, "Input" ],
            Cell[ "First", "Item" ],
            Cell[ TextData @ { "The ", $nbtBold, " pendulum, see ", $nbtLink, "." }, "Text" ],
            Cell[ BoxData @ $nbtCode, "Input", CellLabel -> "In[1]:=" ],
            Cell[ TextData @ { "Equations of ", StyleBox[ "motion", FontWeight -> Bold ] }, "Section" ],
            Cell[ "After the section.", "Text" ]
        },
        { "u1", "u2", "u5" }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-WriteCells"
]

(* Cells that name the same place keep the order of the text: new cells and moved ones, with the new cells without a
   place of their own that follow them. A cell placed after a cell with outputs comes after the outputs, also where
   the cell is only named, and a generated cell that is moved goes right after the cell. A cell that names itself as
   its place is told so. *)
VerificationTest[
    {
        nbtWithFE @ {
            nbtWriteCells[ "<cell style='Section' after='c1'>\nA\n</cell><cell style='Text' after='c1'>\nB\n</cell>\n<cell style='Text'>\nB2\n</cell>\n<cell id='c6' after='c1'/>\n<cell style='Item' after='c1'>\nC\n</cell>" ],
            nbtWriteCells[ "<cell style='Text' after='c3'>\nAfter the output\n</cell>\n<cell id='c3'/>\n<cell style='Text'>\nAlso after it\n</cell>" ],
            First /@ nbtCells[ ],
            nbtWriteCells[ "<cell id='c5' after='c5'/>" ]
        },
        nbtWithFE @ Block[ { $nbtSources = <| $nbtSource -> {
                { "u1", Cell[ BoxData @ "x", "Input" ] },
                { "u2", Cell[ "printed", "Print" ] },
                { "u3", Cell[ BoxData @ "1", "Output" ] },
                { "u4", Cell[ "Some text", "Text" ] }
            } |> },
            nbtWriteCells[ "<cell id='c3' after='c1'/>\n<cell style='Text' after='c1'>\nNote\n</cell>" ];
            First /@ nbtCells[ ]
        ]
    },
    {
        {
            "Wrote to s1: new c7 (Section), c8 (Text), c9 (Text) after c1; new c10 (Item) after c6; moved c6.",
            "Wrote to s1: new c11 (Text), c12 (Text) after c4.",
            {
                "Hamiltonian Mechanics", "A", "B", "B2", BoxData @ RowBox @ { "f", "[", "x", "]" }, "C", _TextData, BoxData @ $nbtCode,
                BoxData[ "42" ], "After the output", "Also after it", "Equations of motion"
            },
            "c5 names itself as its place (after='c5'). To change a cell where it is, leave after out; to move it, name another cell. Nothing was written."
        },
        { BoxData[ "x" ], BoxData[ "1" ], "printed", "Note", "Some text" }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-WriteCells-Places"
]

(* What the result calls a cell that a tag rewrites and places: changed and moved if it gets another place, and only
   changed if it is at that place already, which then takes one write and no move. A cell that is named at the place
   that it has is not moved, and nothing is written. A cell that an earlier call deleted is told apart from an id
   that the notebook never had: a model that deletes a cell and writes it again elsewhere is told what to do instead.
   WriteCells' description says where math is $$...$$. *)
VerificationTest[
    nbtWithFE[
        nbt[ "ReadCells" ];
        {
            nbtWriteCells[ "<cell id='c1' delete='true'/>\n<cell id='c5' after='c4'>ONE</cell>" ],
            $nbtWrites,
            nbtWriteCells[ "<cell id='c6' before='c2'>\ng[x]\n</cell>" ],
            First /@ nbtCells[ ],
            nbtWriteCells[ "<cell id='c5' after='c4'/><cell id='c2' before='c3'/>" ],
            Length @ $nbtWrites,
            nbtWriteCells[ "<cell id='c1' style='Title' before='c2'>\nHamiltonian Mechanics\n</cell>" ],
            nbt[ "ReadCells", <| "cells" -> "c1, c2" |> ],
            nbtWriteCells[ "<cell id='c9'/>" ],
            StringContainsQ[ $nbtTools[ "WriteCells" ][ "Description" ], "In a text cell, math is $$...$$ (in a code cell it is code;" ]
        }
    ],
    {
        "Wrote to s1: changed c5; deleted c1.",
        { { { "Delete", { "u1" } }, { "Replace", "u5", Cell[ "ONE", "Section", ExpressionUUID -> "u5" ] } } },
        "Wrote to s1: changed c6; moved c6.",
        { BoxData @ RowBox @ { "g", "[", "x", "]" }, _TextData, BoxData @ $nbtCode, BoxData[ "42" ], "ONE" },
        $nbtNothing,
        2,
        "c1 is not in s1 any more: an earlier call of this chat deleted it, with its content. If the cell is still needed, write it as a new cell (<cell style='...'>...</cell>, with after= or before= for its place). To move a cell, do not delete it: <cell id='c7' before='c2'/> moves it as it is.",
        "c1 is not in s1 any more: an earlier call of this chat deleted it, with its content. If the cell is still needed, write it as a new cell (<cell style='...'>...</cell>, with after= or before= for its place). To move a cell, do not delete it: <cell id='c7' before='c2'/> moves it as it is.",
        "s1 has no cell \"c9\". GetOutline gives the ids of its cells.",
        True
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-WriteCells-ChangedMovedDeleted"
]

(* New cells have ids at once, and are read and written like the others *)
VerificationTest[
    nbtWithFE[
        nbt[ "WriteCells", <| "cells" -> "<cell style='Input'>\nx = 1\n</cell>" |> ];
        {
            nbt[ "ReadCells", <| "cells" -> "c7" |> ],
            nbtEditCell[ "c7", "1" -> "2" ];
            Last @ nbtCells[ ],
            Last[ $nbtWrites ][[ 1, 2 ]] === First[ $nbtWrites ][[ 1, 4, 1, -1, 2 ]]
        }
    ],
    {
        "<cell id='c7' style='Input'>\nx = 1\n</cell>",
        Cell[ BoxData @ RowBox @ { "x", "=", "2" }, "Input" ],
        True
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-WriteCells-NewCellIDs"
]

(* Everything is converted before anything is written: one tag that is refused, and nothing is written. The message
   names the cell, and a new cell by the number of its tag in the text. Text outside of cell tags is refused too. *)
VerificationTest[
    nbtWithFE[
        nbt[ "ReadCells" ];
        {
            nbtWriteCells[ "<cell id='c1'>\nNew title\n</cell>\n<cell style='Text' color='red'>\nx\n</cell>" ],
            nbtWriteCells[ "<cell id='c1'>\nNew title\n</cell>\n<cell id='c2'>\nA \\!\\(\\*DynamicBox[1]\\)\n</cell>" ],
            nbtWriteCells[ "<cell id='c1'>\nNew title\n</cell>\n<cell id='c9'>\nx\n</cell>" ],
            nbtWriteCells[ "<cell id='c1' delete='true'/>\n<cell id='c1'>\nNew title\n</cell>" ],
            nbtWriteCells[ "<cell id='c1' delete='true'/>\n<cell style='Text' after='c1'>\nx\n</cell>" ],
            nbtWriteCells[ "<cell style='Text' delete='true'>\nx\n</cell>" ],
            nbtWriteCells[ "<cell id='c1'>\nNew title\n</cell>\n<cell style=Text>\nx\n</cell>" ],
            nbtWriteCells[ "<cell id='c1'>\nNew title\n</cell>\n\nSome text." ],
            nbtWriteCells[ " " ],
            $nbtWrites,
            Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots
        }
    ],
    {
        "Cell tag 2 (a new cell) has the attribute color, which is not one of id, style, CellLabel, CellTags, options, after, before and delete. Nothing was written.",
        _String? (StringStartsQ[ #, "Cell c2 has linear syntax" ] && StringEndsQ[ #, " Nothing was written." ] &),
        "s1 has no cell \"c9\". GetOutline gives the ids of its cells.",
        "c1 is written after this call deleted it. To move a cell, do not delete it: <cell id='c1' before='c5'/> (or after=) moves it with its content. Nothing was written.",
        "c1 is not in the notebook where after names it: this call deletes or moves it. Nothing was written.",
        "Cell tag 1 (a new cell) has delete, which needs the id of a cell. Nothing was written.",
        _String? (StringStartsQ[ #, "The text outside of cell tags has a cell tag that could not be read." ] && StringEndsQ[ #, " Nothing was written." ] &),
        _String? (StringStartsQ[ #, "The text outside of cell tags is not read (Some text.). Write each new cell as its own <cell style='...'> block" ] && StringEndsQ[ #, " Nothing was written." ] &),
        "The parameter cells is missing or empty.",
        { },
        <| |>
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-WriteCells-AllOrNothing"
]

(* The content of a generated cell is not written as text, also not that of a new one or of a cell that the tag makes
   one. It can be moved, deleted and given tags. *)
VerificationTest[
    nbtWithFE[
        {
            StringStartsQ[ nbtWriteCells[ "<cell id='c4'>\n43\n</cell>" ], "c4 is a generated cell (an output, a message, a print): its content is not written as text." ],
            StringStartsQ[ nbtWriteCells[ "<cell style='Output'>\n43\n</cell>" ], "Cell tag 1 (a new cell) is a generated cell " ],
            nbt[ "ReadCells" ]; StringStartsQ[ nbtWriteCells[ "<cell id='c5' style='Print, Extra'>\nprinted\n</cell>" ], "c5 is a generated cell " ],
            $nbtWrites,
            nbtWriteCells[ "<cell id='c4' CellTags='result' after='c6'/>" ],
            Last @ nbtCells @ $nbtCount
        }
    ],
    {
        True,
        True,
        True,
        { },
        "Wrote to s1: changed c4; moved c4.",
        Cell[ BoxData @ "42", "Output", CellLabel -> "Out[1]=", CellTags -> "result" ]
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-WriteCells-GeneratedCells"
]

(* A cell that is written as it reads is left alone: it is not written, and it is not an edit that the user is shown.
   The text can be taken from a reading tool as it is. *)
VerificationTest[
    nbtWithFE @ {
        nbt[ "WriteCells", <| "cells" -> nbt[ "ReadCells", <| "cells" -> "c2, c3" |> ] <> "\n<cell id='c5'/>" |> ],
        $nbtWrites,
        nbt[ "ShowChanges" ]
    },
    { $nbtNothing, { }, "No snapshot is open." },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-WriteCells-Unchanged"
]

(* What reading recorded is kept for each cell: two cells whose text reads the same and is different boxes are both
   written back as the boxes that they were *)
VerificationTest[
    nbtWithFE @ Block[ { $nbtSources = <| $nbtSource -> {
            { "u1", Cell[ TextData @ { "A ", StyleBox[ "word", FontWeight -> "Bold" ], " here" }, "Text" ] },
            { "u2", Cell[ TextData @ { "A ", StyleBox[ "word", FontWeight -> Bold ], " there" }, "Text" ] }
        } |> },
        nbt[ "ReadCells" ];
        nbt[ "WriteCells", <| "cells" -> "<cell id='c1'>\nA **word** here.\n</cell>\n<cell id='c2'>\nA **word** there.\n</cell>" |> ];
        nbtCells[ ]
    ],
    {
        Cell[ TextData @ { "A ", StyleBox[ "word", FontWeight -> "Bold" ], " here." }, "Text" ],
        Cell[ TextData @ { "A ", StyleBox[ "word", FontWeight -> Bold ], " there." }, "Text" ]
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-WriteCells-OriginalsPerCell"
]

(* The content of a cell is replaced only if the chat has been given all of it: by ReadCells, by the result of an
   edit, or by the notebook context, but not by a body that was cut, an outline or a search. A tag without a body
   needs nothing, and a cell that the chat wrote is known to it. *)
VerificationTest[
    nbtWithFE @ Block[ { Wolfram`Chatbook`Tools`NotebookTools`Private`$cellLength = 30 },
        Module[ { write },
            write[ id_String ] := nbtWriteCells[ "<cell id='" <> id <> "'>\nNew content\n</cell>" ];
            {
                nbt[ "GetOutline" ]; nbt[ "SearchNotebook", <| "query" -> "Equations" |> ]; write[ "c5" ],
                { StringContainsQ[ nbt[ "ReadCells", <| "cells" -> "c2" |> ], "truncated='true'" ], StringStartsQ[ write[ "c2" ], "c2 has not been shown whole" ] },
                nbt[ "ReadCells", <| "cells" -> "c2", "full" -> True |> ]; write[ "c2" ],
                nbtWriteCells[ "<cell id='c1' CellTags='t'/>\n<cell id='c6' before='c1'/>\n<cell id='c4' delete='true'/>\n" <> $nbtNew ],
                nbtEditCell[ "c5", "motion" -> "rest" ]; write[ "c5" ],
                write[ "c7" ],
                (* what the notebook context gives: c3 whole, and c1 cut *)
                Wolfram`Chatbook`Common`withNotebookCellSyntax[ $nbtSource, "<notebook>\n<cell id='c3' style='Input'>\nx\n</cell>\n\n<cell id='c1' style='Title' truncated='true'>\nHam\n</cell>\n</notebook>" ];
                { write[ "c3" ], StringStartsQ[ write[ "c1" ], "c1 has not been shown whole" ] }
            }
        ]
    ],
    {
        "c5 has not been shown whole in this chat (only cut, or as a line of an outline or a search), so its content is not replaced: read it with ReadCells first (full: true shows a long cell whole), or change a part of it with EditInCell. Nothing was written.",
        { True, True },
        "Wrote to s1: changed c2.",
        "Wrote to s1: changed c1; new c7 (Text) after c6; moved c6; deleted c4.",
        "Wrote to s1: changed c5.",
        "Wrote to s1: changed c7.",
        { "Wrote to s1: changed c3.", True }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-WriteCells-SeenCells"
]

(* A cell that is locked in the notebook (not deletable, or not editable) is not edited, changed in its attributes,
   moved or deleted: nothing of the call is written, and the message names the cells. A generated cell that is not
   editable by its style (a message) is no locked cell. A tag that only names a locked cell is fine. *)
VerificationTest[
    nbtWithFE @ Block[ { $nbtSources = <| $nbtSource -> {
            { "u1", Cell[ "A function", "Title" ] },
            { "u2", Cell[ "Documentation", "Section", Deletable -> False ] },
            { "u3", Cell[ "Locked text", "Text", Editable -> False ] },
            { "u4", Cell[ BoxData @ "\"A message\"", "Message", "MSG", Editable -> False ] },
            { "u5", Cell[ "Some text", "Text" ] }
        } |> },
        nbt[ "ReadCells" ];
        {
            nbtEditCell[ "c2", "Documentation" -> "Docs" ],
            nbtWriteCells[ "<cell id='c5'>\nOther text\n</cell>\n<cell id='c3' CellTags='t'/>\n<cell id='c2' after='c5'/>" ],
            StringStartsQ[ nbtWriteCells[ "<cell id='c2' delete='true'/>" ], "Locked in the notebook: c2. " ],
            { $nbtWrites, Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots },
            nbtWriteCells[ "<cell id='c4' delete='true'/>\n<cell id='c2'/>\n" <> $nbtNew ]
        }
    ],
    {
        "Locked in the notebook: c2. A cell that the user or the author of the notebook made not editable or not deletable is not changed, moved or deleted. Nothing was written.",
        "Locked in the notebook: c3, c2. A cell that the user or the author of the notebook made not editable or not deletable is not changed, moved or deleted. Nothing was written.",
        True,
        { { }, <| |> },
        "Wrote to s1: new c6 (Text) after c2; deleted c4."
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-WriteCells-LockedCells"
]

(* A write that the front end can't apply is an error *)
VerificationTest[
    nbtWithFE @ Block[ { $nbtWriteFails = True }, nbtWriteCells @ $nbtNew ],
    "The front end could not write all of it to s1 (\"Hamiltonian Mechanics\"). ReadCells shows what it holds now.",
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-WriteCells-FrontEndFailure"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Evaluation*)

(* evaluate: true evaluates the Input and Code cells that the call wrote, and only those, statement by statement. The
   generated cells right after such a cell are replaced by an Output cell for each statement that gives something.
   The result shows the outputs and what the evaluator printed. *)
VerificationTest[
    nbtWithFE @ nbtEvaluator[
        <|
            "f[x] + 1" -> <| "Boxes" -> RowBox @ { "1", "+", RowBox @ { "f", "[", "x", "]" } }, "Output" -> "f::argx: bad\n\nRowBox[{\"1\", \"+\", RowBox[{\"f\", \"[\", \"x\", \"]\"}]}]" |>,
            "y" -> <| "Boxes" -> "5", "Output" -> "\"5\"" |>
        |>,
        {
            nbt[ "ReadCells" ];
            nbtWriteCells[ "<cell id='c1'>\nA title\n</cell>\n<cell style='Text'>\nText\n</cell>\n<cell id='c3'>\nf[x] + 1\ny = 5;\ny\n</cell>", "evaluate" -> True ],
            $nbtEvaluated,
            nbtStyles[ ],
            nbtCells[ ][[ { 5, 6 }, 1 ]]
        }
    ],
    {
        "Wrote to s1: changed c1, c3; new c7 (Text) after c1.\n\nEvaluated c3. Its output:\n<cell id='c8' style='Output, EvaluationUnmatched'>\n1 + f[x]\n</cell>\n\n<cell id='c9' style='Output, EvaluationUnmatched'>\n5\n</cell>\nIt printed:\nf::argx: bad",
        { "f[x] + 1", "y = 5;", "y" },
        { { "Title" }, { "Text" }, { "Text" }, { "Input" }, { "Output", "EvaluationUnmatched" }, { "Output", "EvaluationUnmatched" }, { "Section" }, { "Input" } },
        { BoxData @ RowBox @ { "1", "+", RowBox @ { "f", "[", "x", "]" } }, BoxData[ "5" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Evaluate"
]

(* A cell is evaluated without being changed by naming it: the result then does not say that nothing was changed. A
   cell that gives nothing loses its outputs. EditInCell evaluates the cell that it edits. *)
VerificationTest[
    nbtWithFE @ nbtEvaluator[
        <| "g[x]" -> <| "Boxes" -> "7", "Output" -> "\"7\"" |> |>,
        {
            nbtWriteCells[ "<cell id='c3'/>", "evaluate" -> True ],
            $nbtWrites,
            nbtStyles[ ],
            nbtWriteCells[ "<cell id='c5'/>", "evaluate" -> True ],
            nbtEditCell[ "c6", "f" -> "g", "evaluate" -> True ]
        }
    ],
    {
        "Evaluated c3: it gives no output.",
        { { { "Delete", { "u4" } } } },
        { { "Title" }, { "Text" }, { "Input" }, { "Section" }, { "Input" } },
        $nbtNothing <> "\n\nNothing was evaluated: the call wrote no Input or Code cell.",
        "Edited c6 of s1. It now reads:\n<cell id='c6' style='Input'>\ng[x]\n</cell>\n\nEvaluated c6. Its output:\n<cell id='c7' style='Output, EvaluationUnmatched'>\n7\n</cell>"
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Evaluate-Unchanged"
]

(* A statement that gives no boxes ends the evaluation of its cell, whose outputs stay as they were. So does an output
   that is locked in the notebook: the cell is then not evaluated at all. *)
VerificationTest[
    nbtWithFE @ nbtEvaluator[
        <|
            "1" -> <| "Boxes" -> "1", "Output" -> "printed\n\n\"1\"" |>,
            "Pause[100]" -> Failure[ "CellSyntax", <| "MessageTemplate" -> "`1` gave no boxes: `2`", "MessageParameters" -> { "The code", "it ran out of time" } |> ]
        |>,
        {
            nbtEditCell[ "c3", $nbtBody3 -> "1\nPause[100]\n2", "evaluate" -> True ],
            $nbtEvaluated,
            nbtStyles[ ],
            $nbtNotebooks[[ Key @ NotebookObject[ "snapshot-1" ], 4, 2 ]] = Cell[ BoxData @ "42", "Output", Deletable -> False ];
            nbtWriteCells[ "<cell id='c3'/>", "evaluate" -> True ],
            Length @ $nbtEvaluated
        }
    ],
    {
        "Edited c3 of s1. It now reads:\n<cell id='c3' style='Input' CellLabel='In[1]:='>\n1\nPause[100]\n2\n</cell>\n\nc3 was not evaluated to its end, and its outputs are as they were. Cell c3 gave no boxes: it ran out of time\nBefore that it printed:\nprinted",
        { "1", "Pause[100]" },
        { { "Title" }, { "Text" }, { "Input" }, { "Output" }, { "Section" }, { "Input" } },
        "c3 was not evaluated: an output of it is locked in the notebook (not deletable), so it can't be replaced.",
        2
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Evaluate-Failure"
]

(* What a statement gives is written whatever it is: a cell with an output whose code is edited to something that
   evaluates to itself gets that as its output, with the label of the old one. The evaluator is the user's session,
   so the statement runs in this kernel. *)
VerificationTest[
    nbtWithFE @ Block[
        {
            Wolfram`Chatbook`Common`$selectedTools = <| "WolframLanguageEvaluator" -> True |>,
            Wolfram`Chatbook`Common`$toolOptions   = <| "WolframLanguageEvaluator" -> <| $DefaultToolOptions[ "WolframLanguageEvaluator" ], "Method" -> "Session" |> |>
        },
        {
            nbtEditCell[ "c3", $nbtBody3 -> "{1, 2, 3}", "evaluate" -> True ],
            nbtCells[ ][[ 4 ]]
        }
    ],
    {
        "Edited c3 of s1. It now reads:\n<cell id='c3' style='Input' CellLabel='In[1]:='>\n{1, 2, 3}\n</cell>\n\nEvaluated c3. Its output:\n<cell id='c7' style='Output' CellLabel='Out[1]='>\n{1, 2, 3}\n</cell>",
        Cell[ BoxData @ RowBox @ { "{", RowBox @ { "1", ",", "2", ",", "3" }, "}" }, "Output", CellLabel -> "Out[1]=" ]
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Evaluate-OwnResult"
]

(* With the user's session as the evaluator, the kernel only has the definitions that the user has evaluated. A cell
   is evaluated whatever it uses, and its result is looked at: if that still holds a symbol that a cell of the
   notebook assigns and the kernel has no value for, the outputs stay, and the result says once which symbols those
   are, which cells define them (the nearest one above the cell) and how to evaluate them first. Following that
   replaces the output. A name that the cell binds itself (a pattern variable, an iterator, a rule, a local) and
   that another cell assigns is not held by the result, and the cell is evaluated. A statement that comes back as it
   is (MatrixForm of the symbol) holds the symbol, so its outputs stay too. *)
VerificationTest[
    nbtWithFE @ Block[
        {
            $nbtSources = <| $nbtSource -> {
                { "u1", Cell[ "nbtProj = {1, 0}", "Input" ] },
                { "u2", Cell[ BoxData @ "\"old\"", "Output" ] },
                { "u3", Cell[ "nbtProj.nbtProj + 1", "Input" ] },
                { "u4", Cell[ BoxData @ "2", "Output" ] },
                { "u5", Cell[ "nbtF[nbtProj_] := 2 nbtProj\n{nbtF[2], Table[nbtProj^2, {nbtProj, 3}], 1 + 2 nbtProj /. nbtProj -> 3, Module[{nbtProj = 2}, nbtProj + 1]}", "Input" ] },
                { "u6", Cell[ BoxData @ "\"old\"", "Output" ] },
                { "u7", Cell[ "nbtProj = {0, 1};", "Input" ] },
                { "u8", Cell[ "MatrixForm[nbtProj]", "Input" ] },
                { "u9", Cell[ BoxData @ "\"old\"", "Output" ] }
            } |>,
            Wolfram`Chatbook`Common`$selectedTools = <| "WolframLanguageEvaluator" -> True |>,
            Wolfram`Chatbook`Common`$toolOptions   = <| "WolframLanguageEvaluator" -> <| $DefaultToolOptions[ "WolframLanguageEvaluator" ], "Method" -> "Session" |> |>
        },
        WithCleanup[
            {
                nbtEditCell[ "c3", "+ 1" -> "+ 2", "evaluate" -> True ],
                nbtCells[ ][[ 4 ]],
                nbtWriteCells[ "<cell id='c5'/><cell id='c8'/>", "evaluate" -> True ],
                nbtCells[ ][[ { 6, 9 } ]],
                nbtWriteCells[ "<cell id='c1'/><cell id='c3'/>", "evaluate" -> True ],
                nbtCells[ ][[ { 2, 4 } ]]
            },
            Quiet @ Remove[ "*`nbtProj", "*`nbtF" ]
        ]
    ],
    {
        "Edited c3 of s1. It now reads:\n<cell id='c3' style='Input'>\nnbtProj.nbtProj + 2\n</cell>\n\nc3 was evaluated, but its outputs are as they were. Its result still has symbols that the kernel has no value for: nbtProj (c1 defines it). To evaluate those cells first, name them with this one in one call: <cell id='c1'/><cell id='c3'/>. Cells are evaluated in the order of the notebook, whatever the order of the tags is: a defining cell that is below this one only counts for the next call.",
        Cell[ BoxData @ "2", "Output" ],
        "Evaluated c5. Its output:\n<cell id='c10' style='Output'>\n{4, {1, 4, 9}, 7, 3}\n</cell>\n\nc8 was evaluated, but its outputs are as they were. Its result still has symbols that the kernel has no value for: nbtProj (c7 defines it). To evaluate those cells first, name them with this one in one call: <cell id='c7'/><cell id='c8'/>. Cells are evaluated in the order of the notebook, whatever the order of the tags is: a defining cell that is below this one only counts for the next call.",
        { Cell[ BoxData @ RowBox @ { "{", RowBox @ { "4", ",", _RowBox, ",", "7", ",", "3" }, "}" }, "Output" ], Cell[ BoxData @ "\"old\"", "Output" ] },
        "Evaluated c1. Its output:\n<cell id='c11' style='Output'>\n{1, 0}\n</cell>\n\nEvaluated c3. Its output:\n<cell id='c12' style='Output'>\n3\n</cell>",
        { Cell[ BoxData @ RowBox @ { "{", RowBox @ { "1", ",", "0" }, "}" }, "Output" ], Cell[ BoxData @ "3", "Output" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Evaluate-Definitions"
]

(* A sandboxed evaluator never has the definitions of the notebook: what it gives is written, also with a symbol that
   a cell of the notebook assigns. Without the evaluator tool the edit is made, and the result says what evaluate
   needs. *)
VerificationTest[
    nbtWithFE @ Block[
        {
            $nbtSources = <| $nbtSource -> {
                { "u1", Cell[ "nbtProj = {1, 0}", "Input" ] },
                { "u2", Cell[ "nbtProj.nbtProj + 1", "Input" ] },
                { "u3", Cell[ BoxData @ "2", "Output" ] }
            } |>
        },
        {
            nbtEvaluator[
                <| "nbtProj.nbtProj + 2" -> <| "Boxes" -> RowBox @ { "2", "+", RowBox @ { "nbtProj", ".", "nbtProj" } }, "Output" -> "\"x\"" |> |>,
                nbtEditCell[ "c2", "+ 1" -> "+ 2", "evaluate" -> True ]
            ],
            Block[ { Wolfram`Chatbook`Common`$selectedTools = <| |> }, nbtEditCell[ "c2", "+ 2" -> "+ 3", "evaluate" -> True ] ],
            nbtCells[ ][[ 2, 1 ]]
        }
    ],
    {
        "Edited c2 of s1. It now reads:\n<cell id='c2' style='Input'>\nnbtProj.nbtProj + 2\n</cell>\n\nEvaluated c2. Its output:\n<cell id='c4' style='Output, EvaluationUnmatched'>\n2 + nbtProj.nbtProj\n</cell>",
        "Edited c2 of s1. It now reads:\n<cell id='c2' style='Input'>\nnbtProj.nbtProj + 3\n</cell>\n\nNothing was evaluated: evaluate needs the Wolfram Language evaluator tool, which this chat does not have.",
        "nbtProj.nbtProj + 3"
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Evaluate-Sandboxed"
]

(* An output that an evaluation replaces keeps the label of the output that it replaces if the cell has as many
   outputs as before (what it printed does not count). Other new outputs have no label. *)
VerificationTest[
    nbtWithFE @ Block[
        {
            $nbtSources = <| $nbtSource -> {
                { "u1", Cell[ "a\nb", "Input", CellLabel -> "In[12]:=" ] },
                { "u2", Cell[ BoxData @ "1", "Output", CellLabel -> "Out[12]//MatrixForm=" ] },
                { "u3", Cell[ "printed", "Print" ] },
                { "u4", Cell[ BoxData @ "2", "Output", CellLabel -> "Out[13]=" ] }
            } |>
        },
        {
            nbtEvaluator[
                <| "a" -> <| "Boxes" -> "10", "Output" -> "\"10\"" |>, "b" -> <| "Boxes" -> "20", "Output" -> "\"20\"" |> |>,
                nbtWriteCells[ "<cell id='c1'/>", "evaluate" -> True ]
            ],
            nbtCells[ ],
            nbtEvaluator[ <| "a" -> <| "Boxes" -> "10", "Output" -> "\"10\"" |> |>, nbtWriteCells[ "<cell id='c1'/>", "evaluate" -> True ] ],
            Rest @ nbtCells[ ]
        }
    ],
    {
        "Evaluated c1. Its output:\n<cell id='c5' style='Output, EvaluationUnmatched' CellLabel='Out[12]//MatrixForm='>\n10\n</cell>\n\n<cell id='c6' style='Output, EvaluationUnmatched' CellLabel='Out[13]='>\n20\n</cell>",
        {
            Cell[ "a\nb", "Input", CellLabel -> "In[12]:=" ],
            Cell[ BoxData @ "10", "Output", "EvaluationUnmatched", CellLabel -> "Out[12]//MatrixForm=" ],
            Cell[ BoxData @ "20", "Output", "EvaluationUnmatched", CellLabel -> "Out[13]=" ]
        },
        "Evaluated c1. Its output:\n<cell id='c7' style='Output, EvaluationUnmatched'>\n10\n</cell>",
        { Cell[ BoxData @ "10", "Output", "EvaluationUnmatched" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Evaluate-Labels"
]

(* A box in the code reaches the evaluator as an expression URI of the box, which the evaluator reads as the
   expression that the box stands for *)
VerificationTest[
    nbtWithFE @ nbtEvaluator[
        <| |>,
        nbt[ "WriteCells", <| "cells" -> "<cell id='c3'/>", "evaluate" -> True |> ];
        Replace[
            DeleteDuplicates @ StringCases[ First @ $nbtEvaluated, "InlinedExpression[\"" ~~ uri: Except[ "\"" ].. ~~ "\"]" :> uri ],
            { uri_String } :> {
                First @ $nbtEvaluated === "H = InlinedExpression[\"" <> uri <> "\"] - g",
                Wolfram`Chatbook`GetExpressionURI[ uri, HoldComplete ]
            }
        ]
    ],
    { True, HoldComplete[ RawBoxes[ FractionBox[ SuperscriptBox[ "p", "2" ], RowBox @ { "2", " ", "m" } ] ] ] },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Evaluate-Boxes"
]

(* With the evaluator tool, the statements run in its kernel, one after another (the last one leaves nothing of the
   test in the kernel). The evaluator is the user's session here, as in the AI Assistant, so the output is a plain
   Output cell. A statement that comes back as it is (its function is not defined, and no cell of the notebook
   assigns it) is the output of its cell. *)
VerificationTest[
    nbtWithFE @ Block[
        {
            Wolfram`Chatbook`Common`$selectedTools = <| "WolframLanguageEvaluator" -> True |>,
            Wolfram`Chatbook`Common`$toolOptions   = <| "WolframLanguageEvaluator" -> <| $DefaultToolOptions[ "WolframLanguageEvaluator" ], "Method" -> "Session" |> |>
        },
        {
            nbtWriteCells[ "<cell style='Input'>\nnbtValue = 20 + 1;\nPrint[\"twice\"]; 2 nbtValue\nClear[nbtValue]\n</cell>", "evaluate" -> True ],
            Last @ nbtCells[ ],
            nbtEditCell[ "c6", "f[x]" -> "nbtNotDefined[3, x]", "evaluate" -> True ]
        }
    ],
    {
        "Wrote to s1: new c7 (Input) at the end.\n\nEvaluated c7. Its output:\n<cell id='c8' style='Output'>\n42\n</cell>\nIt printed:\ntwice",
        Cell[ BoxData[ "42" ], "Output" ],
        "Edited c6 of s1. It now reads:\n<cell id='c6' style='Input'>\nnbtNotDefined[3, x]\n</cell>\n\nEvaluated c6. Its output:\n<cell id='c9' style='Output'>\nnbtNotDefined[3, x]\n</cell>"
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-Evaluate-Evaluator"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ShowChanges*)

(* ShowChanges shows the user their notebook as a comparison against the snapshot, of which CellDiff reads only the
   changed cells (it is given the ExpressionUUIDs of the edited ones), and closes the snapshot. If it can't be shown,
   the snapshot stays open. *)
VerificationTest[
    nbtWithFE[
        nbtEditCell[ "c1", "Mechanics" -> "Dynamics" ];
        nbtWriteCells @ $nbtNew;
        {
            Block[ { $nbtDiffResult = Failure[ "DiffShown", <| "MessageTemplate" -> "`1` already shows a notebook diff.", "MessageParameters" -> { "It" } |> ] },
                nbt[ "ShowChanges" ]
            ],
            $nbtClosed,
            nbt[ "ShowChanges" ],
            $nbtShown,
            $nbtClosed,
            nbt[ "ShowChanges" ]
        }
    ],
    {
        "The changes of s1 (\"Hamiltonian Mechanics\") could not be shown: It already shows a notebook diff. It is still open.",
        { },
        "The user now sees \"Hamiltonian Mechanics\" as a diff against your edits, and accepts or rejects each change there. s1 is closed.",
        { { $nbtSource, NotebookObject[ "snapshot-1" ], { "u1" } }, { $nbtSource, NotebookObject[ "snapshot-1" ], { "u1" } } },
        { NotebookObject[ "snapshot-1" ] },
        "No snapshot is open."
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ShowChanges"
]

(* A notebook that the user excluded from chats after the snapshot was made is not shown the edits: nothing is
   written to it, and the snapshot stays open *)
VerificationTest[
    nbtWithFE[
        nbtEditCell[ "c1", "Mechanics" -> "Dynamics" ];
        {
            Block[ { $nbtExcluded = True }, nbt[ "ShowChanges" ] ],
            { $nbtShown, $nbtClosed },
            StringEndsQ[ nbt[ "ShowChanges" ], " s1 is closed." ]
        }
    ],
    {
        "\"Hamiltonian Mechanics\" is a notebook that the user excluded from AI chats, so it is not read or edited. s1 is still open: close it with CloseNotebook.",
        { { }, { } },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ShowChanges-ExcludedSince"
]

(* If the comparison marks no cell (the edits only changed cell tags, or the notebook already had them), the result
   says what became of the edits and that there is nothing to accept *)
VerificationTest[
    nbtWithFE @ Block[ { $nbtDiffResult = 0 },
        nbtWriteCells[ "<cell id='c2' CellTags=''/>" ];
        { nbt[ "ShowChanges" ], $nbtClosed }
    ],
    {
        "\"Hamiltonian Mechanics\" shows no diff, since no cell differs in content, style or options. A change of cell tags is applied as it is, a change of a cell label alone is not applied, and any other change the notebook already had. The user has nothing to accept or reject. s1 is closed.",
        { NotebookObject[ "snapshot-1" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ShowChanges-NothingMarked"
]

(* If the changed cells alone do not do (CellDiff then asks for the whole snapshot, which NotebookGet does not give
   right), the source is compared against a Notebook expression that the tools make: the cells of the snapshot in
   their order, each with its ExpressionUUID. A cell that no call changed is the source's own, as the user has it now.
   A moved cell has another ExpressionUUID and CellDiff's tag, so that it is shown as deleted at the old place and
   inserted at the new one. *)
VerificationTest[
    nbtWithFE @ Block[ { $nbtDiffResult = Failure[ "InvalidSnapshot", <| |> ] },
        nbtEditCell[ "c1", "Mechanics" -> "Dynamics" ];
        nbtWriteCells[ "<cell id='c5' before='c2'/>\n" <> $nbtNew <> "\n<cell id='c4' delete='true'/>" ];
        $nbtSources[ $nbtSource ] = ReplacePart[ $nbtSources @ $nbtSource, { 6, 2 } -> Cell[ BoxData @ RowBox @ { "g", "[", "x", "]" }, "Input" ] ];
        { StringEndsQ[ nbt[ "ShowChanges" ], " s1 is closed." ], Most /@ $nbtShown, Last @ Last @ $nbtShown, $nbtClosed }
    ],
    {
        True,
        { { $nbtSource, NotebookObject[ "snapshot-1" ] }, { $nbtSource } },
        Notebook @ {
            Cell[ "Hamiltonian Dynamics", "Title", ExpressionUUID -> "u1" ],
            Cell[ "Equations of motion", "Section", CellTags -> { "NotebookDiff" }, ExpressionUUID -> Except[ "u5", _String ] ],
            Cell[ "New text", "Text", ExpressionUUID -> _String ],
            Cell[ TextData @ { "The ", $nbtBold, " pendulum, see ", $nbtLink, "." }, "Text", CellTags -> "intro", ExpressionUUID -> "u2" ],
            Cell[ BoxData @ $nbtCode, "Input", CellLabel -> "In[1]:=", ExpressionUUID -> "u3" ],
            Cell[ BoxData @ RowBox @ { "g", "[", "x", "]" }, "Input", ExpressionUUID -> "u6" ]
        },
        { NotebookObject[ "snapshot-1" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ShowChanges-WholeNotebook"
]

(* The moved cells are those outside of the longest run of cells that the notebook and the snapshot have in the same
   order: nine cells that are moved before one are shown as that one cell moved *)
VerificationTest[
    nbtWithFE @ Block[
        {
            $nbtDiffResult = Failure[ "InvalidSnapshot", <| |> ],
            $nbtSources    = <| $nbtSource -> Table[ { "u" <> ToString @ i, Cell[ "Cell " <> ToString @ i, "Text" ] }, { i, 12 } ] |>
        },
        nbt[ "WriteCells", <| "cells" -> StringRiffle[ "<cell id='c" <> ToString @ # <> "' before='c2'/>" & /@ Range[ 3, 11 ], "\n" ] |> ];
        nbt[ "ShowChanges" ];
        Cases[ Last @ Last @ $nbtShown, Cell[ text_, ___, ExpressionUUID -> uuid_ ] :> { text, StringStartsQ[ uuid, "u" ] }, { 2 } ]
    ],
    Join[
        { { "Cell 1", True } },
        Table[ { "Cell " <> ToString @ i, True }, { i, 3, 11 } ],
        { { "Cell 2", False }, { "Cell 12", True } }
    ],
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ShowChanges-MovedCells"
]

(* A new notebook has no source to compare with: it is shown as it is, as a Notebook expression of its cells *)
VerificationTest[
    nbtWithFE[
        nbt[ "OpenNotebook" ];
        { nbtWriteCells[ "<cell style='Title'>\nA title\n</cell>\n" <> $nbtNew ], nbtCells[ ], nbt[ "ShowChanges" ], $nbtShown }
    ],
    {
        "Wrote to s1: new c1 (Title), c2 (Text) at the end.",
        { Cell[ "A title", "Title" ], Cell[ "New text", "Text" ] },
        "The user now sees the new notebook. s1 is closed.",
        { { None, Notebook @ { Cell[ "A title", "Title", ExpressionUUID -> _String ], Cell[ "New text", "Text", ExpressionUUID -> _String ] } } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-ShowChanges-NewNotebook"
]

(* A notebook that still shows the changes of a comparison is not edited: the first edit makes no snapshot, and says
   what the user has to do first. Reading it, and editing another notebook, is as always. *)
VerificationTest[
    nbtWithFE @ Block[ { $nbtDiffCells = <| $nbtSource -> { CellObject[ "u2", "instance" ] } |> },
        {
            nbtEditCell[ "c5", "motion" -> "rest" ],
            nbtWriteCells @ $nbtNew === nbtEditCell[ "c5", "motion" -> "rest" ],
            { $nbtCount, $nbtWrites },
            nbt[ "ReadCells", <| "cells" -> "c5" |> ],
            nbtWriteCells[ $nbtNew, "notebook" -> "12345678" ]
        }
    ],
    {
        "\"Hamiltonian Mechanics\" still shows the changes of an earlier ShowChanges, which the user has not all accepted or rejected. It can't be edited until they have: tell the user to accept or reject the changes that are shown (the toolbar has Accept All and Reject All), and make this edit after that. Nothing was written.",
        True,
        { 0, { } },
        "<cell id='c5' style='Section'>\nEquations of motion\n</cell>",
        "Wrote to s1: new c2 (Text) at the end."
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-UnresolvedDiff"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Calls*)

(* A WriteCells call written by a model with the Simple tool method: cells is text of several lines, and the
   parameters that the call leaves out are "" *)
VerificationTest[
    nbtWithFE @ Internal`InheritedBlock[ { Wolfram`Chatbook`Tools`Private`$toolBox },
        Block[ { Wolfram`Chatbook`Common`$selectedTools = $nbtTools },
            {
                nbtRespond[ "I'll add a cell.\n/nb_write\ncells: <cell id='c5'/>\n<cell style='Text'>\nA backslash \\\\ and \[Alpha]: done.\n</cell>\nevaluate: false" ],
                nbtCells[ ][[ 6 ]],
                nbtRespond[ "/nb_edit\nc6\n[{\"oldText\": \"f[x]\", \"newText\": \"g[\\\"y\\\"]\"}]" ],
                Developer`ReadRawJSONString[ nbtRespond[ "/nb_list" ] ][ "snapshots" ][[ All, "edited" ]],
                nbtRespond[ "/nb_show" ]
            }
        ]
    ],
    {
        "Opened s1 (\"Hamiltonian Mechanics\"), a snapshot of the notebook.\n\nWrote to s1: new c7 (Text) after c5." <> $nbtNotShown,
        Cell[ "A backslash \\ and \[Alpha]: done.", "Text" ],
        "Edited c6 of s1. It now reads:\n<cell id='c6' style='Input'>\ng[\"y\"]\n</cell>" <> $nbtNotShown,
        { True },
        "The user now sees \"Hamiltonian Mechanics\" as a diff against your edits, and accepts or rejects each change there. s1 is closed."
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-SimpleToolCalls"
]

(* A native WriteCells call written as a Simple tool call (the hybrid tool method) is read back as the same call. A
   parameter that the tool does not have (models give after as one) is left out, and is no text of the cells. *)
VerificationTest[
    Internal`InheritedBlock[ { Wolfram`Chatbook`Tools`Private`$toolBox },
        Block[ { Wolfram`Chatbook`Common`$selectedTools = $nbtTools },
            With[ { native = LLMToolRequest[ "write_cells", <| "cells" -> "<cell id='c5'/>\n<cell style='Input'>\nx = 1;\nx + 1\n</cell>", "after" -> "c26", "evaluate" -> True |> ] },
                KeyTake[
                    Association @ Last[
                        Wolfram`Chatbook`Common`simpleToolRequestParser @ Block[
                            {
                                Wolfram`Chatbook`$ChatHandlerData         = <| "ChatNotebookSettings" -> <| "ToolMethod" -> "Simple" |> |>,
                                Wolfram`Chatbook`Common`$receivedToolCall = False
                            },
                            Wolfram`Chatbook`LLMUtilities`Private`toolRequestToString @ native
                        ]
                    ][ "ParameterValues" ],
                    { "cells", "notebook", "evaluate", "after" }
                ]
            ]
        ]
    ],
    <| "cells" -> "<cell id='c5'/>\n<cell style='Input'>\nx = 1;\nx + 1\n</cell>", "notebook" -> "", "evaluate" -> "True" |>,
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-HybridToolCall"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Front End*)

(* The real operations on a hidden copy of a notebook (a stand-in for a snapshot: it has the ExpressionUUIDs of its
   source): a cell that is replaced keeps its ExpressionUUID, new cells get the ones they are written with, and a cell
   that is moved keeps its own. A write that names a cell that is not there fails. Needs CellObjects with
   ExpressionUUIDs. *)
VerificationTest[
    UsingFrontEnd @ Module[ { source, copy, fe, uuids, u, a, b, result },
        fe = Wolfram`Chatbook`Tools`NotebookTools`Private`notebookFrontEnd;
        WithCleanup[
            source = NotebookPut @ Notebook @ {
                Cell[ "A title", "Title" ], Cell[ "A section", "Section" ], Cell[ "Some text", "Text" ],
                Cell[ BoxData @ RowBox @ { "1", "+", "1" }, "Input" ], Cell[ BoxData @ "2", "Output" ]
            };
            copy = NotebookPut[ NotebookGet[ source, "IncludeUUIDs" -> True ], Visible -> False ];
            uuids[ ] := Replace[ fe[ "Cells", copy ], CellObject[ uuid_, ___ ] :> uuid, { 1 } ];
            u = uuids[ ];
            If[ ! MatchQ[ u, { __String } ],
                Missing[ "TestSkipped" ],
                { a, b } = { CreateUUID[ ], CreateUUID[ ] };
                result = fe[ "Write", copy, {
                    { "Replace", u[[ 3 ]], Cell[ "Other text", "Text", ExpressionUUID -> u[[ 3 ]] ] },
                    { "Insert", u[[ 2 ]], "After", { Cell[ "new", "Text", ExpressionUUID -> a ] } },
                    { "Insert", u[[ 1 ]], "Before", { Cell[ "first", "Text", ExpressionUUID -> b ] } },
                    { "Delete", { u[[ 5 ]] } },
                    { "Delete", { u[[ 4 ]] } },
                    { "Insert", u[[ 1 ]], "After", { Cell[ BoxData @ RowBox @ { "1", "+", "1" }, "Input", ExpressionUUID -> u[[ 4 ]] ] } }
                } ];
                {
                    u === Replace[ Cells @ source, CellObject[ uuid_, ___ ] :> uuid, { 1 } ],
                    result,
                    uuids[ ] === { b, u[[ 1 ]], u[[ 4 ]], u[[ 2 ]], a, u[[ 3 ]] },
                    fe[ "Read", copy, fe[ "Cells", copy ] ],
                    fe[ "Write", copy, { { "Replace", "not-there", Cell[ "x", "Text" ] } } ]
                }
            ],
            NotebookClose /@ { source, copy }
        ]
    ],
    Missing[ "TestSkipped" ] | {
        True,
        Null,
        True,
        {
            Cell[ "first", "Text", ___ ], Cell[ "A title", "Title", ___ ], Cell[ BoxData @ RowBox @ { "1", "+", "1" }, "Input", ___ ],
            Cell[ "A section", "Section", ___ ], Cell[ "new", "Text", ___ ], Cell[ "Other text", "Text", ___ ]
        },
        $Failed
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-FrontEnd-Writes"
]

(* The tools on a real notebook, with only the snapshot made up (a hidden copy): the notebook is read as it is, an
   edit and new cells end up in the snapshot, and ShowChanges has CellDiff show the source as a comparison, which marks
   the two changes. While the notebook shows them, it is not edited. A new notebook is shown as a notebook that is
   visible. *)
VerificationTest[
    Module[ { source, copies = { }, listed, id },
        nbtRealFE[ copies,
            WithCleanup[
                source = NotebookPut @ Notebook @ { Cell[ "A title", "Title" ], Cell[ "Some text", "Text" ] };
                If[ ! nbtShowsDiffQ @ source,
                    Missing[ "TestSkipped" ],
                    listed = SelectFirst[ Developer`ReadRawJSONString[ nbt[ "ListNotebooks" ] ][ "notebooks" ], StringStartsQ[ First @ source, #[ "id" ] ] & ];
                    id     = listed[ "id" ];
                    {
                        KeyDrop[ listed, { "id", "title" } ],
                        nbt[ "OpenNotebook", <| "notebook" -> id |> ],
                        nbtEditCell[ "c2", "Some" -> "More", "notebook" -> id ],
                        nbtWriteCells[ "<cell style='Text' before='c1'>\nA preface\n</cell>" ],
                        First /@ NotebookRead @ Cells @ First @ copies,
                        nbt[ "ShowChanges" ],
                        { ! FreeQ[ NotebookGet @ source, "More text" ], Length @ Cells[ source, CellTags -> "NotebookDiff" ] },
                        nbtWriteCells[ $nbtNew, "notebook" -> id ],
                        nbt[ "OpenNotebook" ]; nbtWriteCells @ $nbtNew,
                        With[ { before = Notebooks[ ] },
                            {
                                nbt[ "ShowChanges" ],
                                With[ { new = Complement[ Notebooks[ ], before ] },
                                    copies = Join[ copies, new ];
                                    { First /@ NotebookRead @ Cells @ First @ new, AbsoluteCurrentValue[ First @ new, Visible ] }
                                ]
                            }
                        ]
                    }
                ],
                NotebookClose /@ Append[ copies, source ]
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | {
        <| "file" -> Null, "modified" -> _, "cells" -> 2, "current" -> False, "snapshot" -> Null |>,
        _String? (StringEndsQ[ ": an open notebook, 2 cells.\n\n<cell id='c1' style='Title'>\nA title\n</cell>\n\n<cell id='c2' style='Text'>\nSome text\n</cell>" ]),
        "Edited c2 of s1. It now reads:\n<cell id='c2' style='Text'>\nMore text\n</cell>",
        "Wrote to s1: new c3 (Text) at the start.",
        { "A preface", "A title", "More text" },
        _String? (StringEndsQ[ " as a diff against your edits, and accepts or rejects each change there. s1 is closed." ]),
        { True, 2 },
        _String? (StringContainsQ[ " still shows the changes of an earlier ShowChanges" ]),
        "Wrote to s2: new c1 (Text) at the end.",
        { "The user now sees the new notebook. s2 is closed.", { { "New text" }, True } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-FrontEnd-Tools"
]

(* A move and an edit on a real notebook with cell groups. NotebookGet of a hidden notebook leaves out the cells after
   a cell that was written inside a cell group, so CellDiff is kept from reading the snapshot that way, and gets the
   cells from the tools. The comparison marks the moved cell as deleted at the old place and inserted at the new one,
   and the changed cell: nothing else. *)
VerificationTest[
    Module[ { source, copies = { }, id },
        nbtRealFE[ copies,
            WithCleanup[
                source = NotebookPut @ Notebook @ {
                    Cell[ "A title", "Title" ], Cell[ "First section", "Section" ], Cell[ "one", "Text" ], Cell[ "two", "Text" ],
                    Cell[ "three", "Text" ], Cell[ "Second section", "Section" ], Cell[ "four", "Text" ], Cell[ "five", "Text" ]
                };
                If[ ! nbtShowsDiffQ @ source,
                    Missing[ "TestSkipped" ],
                    id = ToLowerCase @ StringTake[ First @ source, 8 ];
                    {
                        nbt[ "OpenNotebook", <| "notebook" -> id |> ];
                        nbtEditCell[ "c7", "four" -> "FOUR", "notebook" -> id ];
                        nbtWriteCells[ "<cell id='c5' before='c3'/>" ],
                        StringEndsQ[ nbt[ "ShowChanges" ], " as a diff against your edits, and accepts or rejects each change there. s1 is closed." ],
                        Length @ Cells @ source,
                        Length /@ { Cells[ source, CellTags -> "NotebookDiff" ], Cells[ source, CellTags -> "NotebookDiffDeleted" ], Cells[ source, CellTags -> "NotebookDiffInserted" ] },
                        First /@ NotebookRead @ Cells[ source, CellTags -> "NotebookDiffInserted" ],
                        Attributes @ NotebookGet
                    }
                ],
                NotebookClose /@ Append[ copies, source ]
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | {
        "Wrote to s1: moved c5.",
        True,
        9,
        { 3, 1, 1 },
        { "three" },
        { Protected, ReadProtected }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-FrontEnd-Move"
]

(* An edit that only changes cell tags is applied by the comparison as it is: no cell is marked, the result says that
   there is nothing to accept, and the notebook has the stylesheet and the dynamic expression that it had (the
   comparison sets its own). An edit of the content of a cell marks it, and the comparison's options stay until the
   user resolves it. *)
VerificationTest[
    Module[ { source, copies = { }, id, options },
        nbtRealFE[ copies,
            WithCleanup[
                source  = NotebookPut @ Notebook @ { Cell[ "A title", "Title" ], Cell[ "Some text", "Text", CellTags -> "old" ] };
                options = Options[ source, { StyleDefinitions, NotebookDynamicExpression } ];
                If[ ! nbtShowsDiffQ @ source,
                    Missing[ "TestSkipped" ],
                    id = ToLowerCase @ StringTake[ First @ source, 8 ];
                    {
                        nbtWriteCells[ "<cell id='c2' CellTags='new'/>", "notebook" -> id ],
                        StringContainsQ[ nbt[ "ShowChanges" ], " shows no diff, since no cell differs" ],
                        Rest @ NotebookRead[ Cells[ source ][[ 2 ]] ],
                        Options[ source, { StyleDefinitions, NotebookDynamicExpression } ] === options,
                        nbtWriteCells[ "<cell id='c1' style='Chapter'/>", "notebook" -> id ];
                        StringContainsQ[ nbt[ "ShowChanges" ], " as a diff against your edits" ],
                        Options[ source, { StyleDefinitions, NotebookDynamicExpression } ] === options
                    }
                ],
                NotebookClose /@ Append[ copies, source ]
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | { "Wrote to s1: changed c2.", True, Cell[ "Text", CellTags -> "new" ], True, True, False },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-FrontEnd-NothingMarked"
]

(* The locks and the exclusions of real notebooks: a cell that is not deletable is not edited, and a message cell,
   which the stylesheet makes not editable, is deleted. A cell that the user excludes from chats is left out. The file
   of an open notebook that the user excluded from chats is not opened, also not by its name in another letter case
   where the file system takes that for the file, and neither is a file that is not open and says itself that it is
   excluded. *)
VerificationTest[
    Module[ { source, copies = { }, id, file, excluded },
        nbtRealFE[ copies,
            WithCleanup[
                source = NotebookPut @ Notebook @ {
                    Cell[ "A function", "Title" ], Cell[ "Documentation", "Section", Deletable -> False ],
                    Cell[ BoxData @ "\"A message\"", "Message", "MSG" ], Cell[ "Private", "Text" ], Cell[ "Last", "Text" ]
                };
                file = FileNameJoin @ { $TemporaryDirectory, "nbt-" <> CreateUUID[ ] <> ".nb" };
                Export[ file, Notebook @ { Cell[ "Secret", "Text" ] }, "NB" ];
                excluded = NotebookOpen[ file, Visible -> False ];
                If[ ! MatchQ[ Cells @ source, { CellObject[ _String, ___ ].. } ],
                    Missing[ "TestSkipped" ],
                    id = ToLowerCase @ StringTake[ First @ source, 8 ];
                    CurrentChatSettings[ Cells[ source ][[ 4 ]], "ExcludeFromChat" ] = True;
                    {
                        nbtEditCell[ "c2", "Documentation" -> "Docs", "notebook" -> id ],
                        copies,
                        StringCases[ nbt[ "ReadCells", <| "notebook" -> id |> ], "<cell id='" ~~ i: WordCharacter.. :> i ],
                        nbtWriteCells[ "<cell id='c3' delete='true'/>", "notebook" -> id ],
                        First /@ NotebookRead @ Cells @ Last @ copies,
                        nbt[ "CloseNotebook" ],
                        SetOptions[ excluded, Visible -> True ];
                        CurrentChatSettings[ excluded, "ExcludeFromChat" ] = True;
                        StringEndsQ[ nbt[ "ReadCells", <| "notebook" -> file |> ], " is a notebook that the user excluded from AI chats, so it is not read or edited." ],
                        With[ { result = nbt[ "ReadCells", <| "notebook" -> ToUpperCase @ file |> ] },
                            {
                                StringFreeQ[ result, "Secret" ],
                                FileExistsQ @ ToUpperCase @ file === StringEndsQ[ result, " is a notebook that the user excluded from AI chats, so it is not read or edited." ]
                            }
                        ],
                        NotebookSave @ excluded;
                        NotebookClose @ excluded;
                        StringEndsQ[ nbt[ "OpenNotebook", <| "notebook" -> file |> ], " is a notebook that the user excluded from AI chats, so it is not read or edited." ],
                        Keys @ Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots
                    }
                ],
                NotebookClose /@ Join[ copies, { source, excluded } ];
                DeleteFile @ file
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | {
        "Locked in the notebook: c2. A cell that the user or the author of the notebook made not editable or not deletable is not changed, moved or deleted. Nothing was written.",
        { _NotebookObject },
        { "c1", "c2", "c3", "c5" },
        "Wrote to s1: deleted c3.",
        { "A function", "Documentation", "Private", "Last" },
        "Closed s1; its edits were discarded.",
        True,
        { True, True },
        True,
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookTools-FrontEnd-LockedAndExcluded"
]

(* :!CodeAnalysis::EndBlock:: *)
