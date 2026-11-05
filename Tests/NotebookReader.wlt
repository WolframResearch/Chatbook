(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/NotebookReader.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/NotebookReader.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* Calls the NotebookReader tool function as it would be called in a Notebook Assistant window chat that is focused on
   nb, with the given settings and tool parameters: *)
VerificationTest[
    workspaceNotebookReader // ClearAll;
    workspaceNotebookReader[ nb_NotebookObject, settings_Association, params_Association ] :=
        Block[
            {
                Wolfram`Chatbook`$WorkspaceChat   = True,
                Wolfram`Chatbook`$SidebarChat     = False,
                Wolfram`Chatbook`$ChatHandlerData = <|
                    "ChatNotebookSettings" -> <|
                        AbsoluteCurrentChatSettings @ nb,
                        "AllowSelectionContext" -> True,
                        "FocusedNotebook"       -> nb,
                        settings
                    |>
                |>
            },
            Wolfram`Chatbook`Tools`Private`notebookReader @ params
        ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "WorkspaceNotebookReader-Definition@@Tests/NotebookReader.wlt:27,1-48,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Selection Scope*)

(* The default scope gives the same view as the automatic notebook context: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$contextPrompt   = "chat context",
            Wolfram`Chatbook`Common`$selectionPrompt = "chat selection",
            Wolfram`Chatbook`Common`$contextImages   = { "chat images" }
        },
        UsingFrontEnd @ Module[ { nb, cells, result, chatState, expected },
            WithCleanup[
                nb = CreateDocument @ {
                    Cell[ "Reader Test", "Title" ],
                    Cell[ "BEFORE-111 text before the selection", "Text" ],
                    Cell[ "SELECTED-222", "Text" ],
                    Cell[ "AFTER-333 text after the selection", "Text" ]
                };
                cells = Cells @ nb;
                SelectionMove[ cells[[ 3 ]], All, Cell ];
                result = workspaceNotebookReader[ nb, <| |>, <| |> ];
                (* The chat's own notebook context should be unchanged by the tool: *)
                chatState = {
                    Wolfram`Chatbook`Common`$contextPrompt,
                    Wolfram`Chatbook`Common`$selectionPrompt,
                    Wolfram`Chatbook`Common`$contextImages
                };
                expected = Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[
                    None,
                    nb,
                    <| AbsoluteCurrentChatSettings @ nb, "AllowSelectionContext" -> True |>
                ];
                {
                    result === expected,
                    StringContainsQ[ result, "<notebook>" ~~ __ ~~ "<metadata>" ~~ __ ~~ "</notebook>" ],
                    StringContainsQ[ result, "BEFORE-111" ~~ __ ~~ "<selection>" ~~ __ ~~ "SELECTED-222" ],
                    StringContainsQ[ result, "SELECTED-222" ~~ __ ~~ "</selection>" ~~ __ ~~ "AFTER-333" ],
                    chatState
                },
                NotebookClose @ nb
            ]
        ]
    ],
    { True, True, True, True, { "chat context", "chat selection", { "chat images" } } },
    SameTest -> MatchQ,
    TestID   -> "SelectionScope-Workspace@@Tests/NotebookReader.wlt:55,1-98,2"
]

(* Tool results stay in the conversation, so they should not include relative times that go stale: *)
VerificationTest[
    UsingFrontEnd @ Module[ { nb, result },
        WithCleanup[
            nb = CreateDocument @ { Cell[ "Some text", "Text" ] };
            SelectionMove[ nb, After, Notebook ];
            NotebookWrite[ nb, Cell[ "MODIFIED-444", "Text" ] ];
            result = workspaceNotebookReader[ nb, <| |>, <| |> ];
            {
                StringContainsQ[ result, "MODIFIED-444" ],
                StringContainsQ[ result, "MemoryModificationTime: " ],
                StringFreeQ[ result, "MemoryModificationTime: " ~~ Except[ "\n" ]... ~~ "(" ]
            },
            NotebookClose @ nb
        ]
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "SelectionScope-NoRelativeTimes@@Tests/NotebookReader.wlt:101,1-119,2"
]

(* In the sidebar, the notebook is the one that contains the sidebar: *)
VerificationTest[
    UsingFrontEnd @ Module[ { nb, cells, sidebarCell, result },
        WithCleanup[
            nb = CreateDocument @ {
                Cell[ "SIDEBAR-NB-555", "Text" ],
                Cell[ "SIDEBAR-NB-666", "Text" ],
                Cell[ "sidebar", "Text" ]
            };
            cells = Cells @ nb;
            sidebarCell = Last @ cells;
            Internal`InheritedBlock[ { Wolfram`Chatbook`ChatModes`Common`sidebarCellObject },
                Wolfram`Chatbook`ChatModes`Common`sidebarCellObject[ _NotebookObject ] := sidebarCell;
                Block[
                    {
                        Wolfram`Chatbook`$WorkspaceChat                  = False,
                        Wolfram`Chatbook`$SidebarChat                    = True,
                        Wolfram`Chatbook`Common`$chatState               = True,
                        Wolfram`Chatbook`Common`$evaluationNotebook      = nb,
                        Wolfram`Chatbook`Common`$sidebarSelectionContext = None,
                        Wolfram`Chatbook`$ChatHandlerData                = <|
                            "ChatNotebookSettings" -> <|
                                AbsoluteCurrentChatSettings @ nb,
                                "AllowSelectionContext" -> True
                            |>
                        |>
                    },
                    result = Wolfram`Chatbook`Tools`Private`notebookReader @ <| |>
                ]
            ];
            {
                StringContainsQ[ result, "<notebook>" ],
                StringContainsQ[ result, "SIDEBAR-NB-555" ~~ __ ~~ "SIDEBAR-NB-666" ]
            },
            NotebookClose @ nb
        ]
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "SelectionScope-Sidebar@@Tests/NotebookReader.wlt:122,1-161,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*All Scope*)
VerificationTest[
    UsingFrontEnd @ Module[ { nb, page1, page2, tooFar },
        WithCleanup[
            nb = CreateDocument @ {
                Cell[ "CELL-1", "Text" ],
                Cell[ "CELL-2", "Text" ],
                Cell[ "EXCLUDED-CELL", { "Text", "ChatExcluded" } ],
                Cell[ "CELL-3", "Text" ],
                Cell[ "CELL-4", "Text" ],
                Cell[ "CELL-5", "Text" ]
            };
            SelectionMove[ First @ Cells @ nb, All, Cell ];
            Block[ { Wolfram`Chatbook`ChatModes`Context`Private`$notebookReaderPageSize = 3 },
                page1  = workspaceNotebookReader[ nb, <| |>, <| "scope" -> "all" |> ];
                page2  = workspaceNotebookReader[ nb, <| |>, <| "scope" -> "all", "offset" -> 4 |> ];
                tooFar = workspaceNotebookReader[ nb, <| |>, <| "scope" -> "all", "offset" -> 6 |> ]
            ];
            {
                StringContainsQ[ page1, "cells 1 to 3 of 5" ],
                StringContainsQ[ page1, "<metadata>" ~~ __ ~~ "CELL-1" ~~ __ ~~ "CELL-2" ~~ __ ~~ "CELL-3" ],
                StringFreeQ[ page1, "CELL-4" | "EXCLUDED-CELL" | "<selection>" ],
                StringContainsQ[ page1, "offset 4" ],
                StringContainsQ[ page2, "cells 4 to 5 of 5" ],
                StringContainsQ[ page2, "CELL-4" ~~ __ ~~ "CELL-5" ],
                StringFreeQ[ page2, "CELL-3" ],
                StringContainsQ[ page2, "end of the notebook" ],
                StringContainsQ[ tooFar, "has 5 cells" ]
            },
            NotebookClose @ nb
        ]
    ],
    { True, True, True, True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "AllScope-Paging@@Tests/NotebookReader.wlt:166,1-200,2"
]

(* Invalid parameters fall back to the defaults: *)
VerificationTest[
    {
        Wolfram`Chatbook`Tools`Private`notebookReaderScope /@ { "all", " All ", "selection", "other", "", Missing[ ] },
        Wolfram`Chatbook`Tools`Private`notebookReaderOffset /@ { 3, 0, -1, "", Missing[ ] }
    },
    {
        { "all", "all", "selection", "selection", "selection", "selection" },
        { 3, 1, 1, 1, 1 }
    },
    SameTest -> MatchQ,
    TestID   -> "Parameters-Defaults@@Tests/NotebookReader.wlt:203,1-214,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Unavailable Notebooks*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`$WorkspaceChat             = False,
            Wolfram`Chatbook`$SidebarChat               = True,
            Wolfram`Chatbook`Common`$evaluationNotebook = None,
            Wolfram`Chatbook`$ChatHandlerData           = <|
                "ChatNotebookSettings" -> <| "AllowSelectionContext" -> True |>
            |>
        },
        Wolfram`Chatbook`Tools`Private`notebookReader @ <| |>
    ],
    _String? (StringContainsQ[ "no notebook to read" ]),
    SameTest -> MatchQ,
    TestID   -> "NoNotebook@@Tests/NotebookReader.wlt:219,1-234,2"
]

VerificationTest[
    UsingFrontEnd @ Module[ { nb, result },
        WithCleanup[
            nb = CreateDocument @ { Cell[ "HIDDEN-777", "Text" ] };
            result = workspaceNotebookReader[ nb, <| "AllowSelectionContext" -> False |>, <| "scope" -> "all" |> ];
            { StringFreeQ[ result, "HIDDEN-777" ], StringContainsQ[ result, "turned off notebook content" ] },
            NotebookClose @ nb
        ]
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "SelectionContextDisabled@@Tests/NotebookReader.wlt:236,1-248,2"
]

(* :!CodeAnalysis::EndBlock:: *)
