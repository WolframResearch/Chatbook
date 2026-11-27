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
   hidden copy of a notebook (no released front end makes snapshots yet). The tools' state and the stores that reading
   writes to are Blocked in every test that changes them, so that nothing is left for other test files (CI runs them
   all in one kernel). *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    (* CI runs every test file in one kernel and one context: these helpers are only defined here *)
    ClearAll[
        nbt, nbtFE, nbtList, nbtWrite, nbtWithFE, nbtCells, nbtStyles, nbtChat, nbtEvaluator, nbtRespond, nbtEdit,
        nbtWriteCells, nbtEditCell, nbtRealFE
    ];

    $nbtNames = { "ListNotebooks", "OpenNotebook", "GetOutline", "ReadCells", "SearchNotebook", "CloseNotebook" };
    $nbtTools = AssociationMap[ Wolfram`Chatbook`$DefaultTools, $nbtNames ];

    (* What a tool gives the model: its result, or the text of its error *)
    nbt[ name_String, args_Association ] := Replace[ $nbtTools[ name ][ args ], KeyValuePattern[ "String" -> text_String ] :> text ];
    nbt[ name_String ] := nbt[ name, <| |> ];

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
    nbtFE[ "Snapshot", source_ ] := With[ { nb = NotebookObject[ "snapshot-" <> ToString[ ++$nbtCount ] ] },
        $nbtNotebooks[ nb ] = Lookup[ $nbtSources, Key @ source, { } ];
        nb
    ];
    nbtFE[ "Excluded", _ ] := $nbtExcluded;
    nbtList[ nb_ ] := Lookup[ $nbtNotebooks, nb, Lookup[ $nbtSources, nb, { } ] ];
    nbtFE[ "Cells", nb_ ] := CellObject[ #, "instance" ] & /@ nbtList[ nb ][[ All, 1 ]];
    nbtFE[ "Read", nb_, cells_List ] := Lookup[ Association[ Rule @@@ nbtList @ nb ], First /@ cells ];
    nbtFE[ "Close", nb_ ] := (AppendTo[ $nbtClosed, nb ]; KeyDropFrom[ $nbtNotebooks, nb ];);

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
            $nbtClosed     = { },
            $nbtExcluded   = False
        },
        eval
    ];

    (* Evaluates as a tool call of the chat with this ConversationUUID *)
    nbtChat // Attributes = { HoldRest };
    nbtChat[ id_String, eval_ ] :=
        Block[ { Wolfram`Chatbook`$ChatHandlerData = <| "ChatNotebookSettings" -> <| "ConversationUUID" -> id |> |> }, eval ];

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

(* The six tools are default tools, in order, hidden from the tool manager. Each is found by the machine name a model
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
        { "list_notebooks", "open_notebook", "get_outline", "read_cells", "search_notebook", "close_notebook" },
        { "nb_list", "nb_open", "nb_outline", "nb_cells", "nb_find", "nb_close" },
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

(* :!CodeAnalysis::EndBlock:: *)
