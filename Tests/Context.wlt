(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Context.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Context.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Excluded Cells*)
VerificationTest[
    UsingFrontEnd @ Module[ { nb, cells, settings, selectedContext, unselectedContext },
        WithCleanup[
            nb = CreateDocument @ {
                Cell[ "QA1", "Title" ],
                Cell[ "1 + 1", "Input" ],
                Cell[ "PUBLIC-111 visible text", "Text" ],
                Cell[ "SECRET-222 excluded text", { "Text", "ChatExcluded" } ]
            };
            cells = Cells @ nb;
            settings = AbsoluteCurrentChatSettings @ nb;

            SelectionMove[ cells[[ 4 ]], All, Cell ];
            selectedContext = Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, nb, settings ];

            SelectionMove[ cells[[ 2 ]], After, Cell ];
            unselectedContext = Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, nb, settings ];

            {
                StringContainsQ[ selectedContext, "PUBLIC-111" ],
                StringFreeQ[ selectedContext, "SECRET-222" ],
                StringContainsQ[ unselectedContext, "PUBLIC-111" ],
                StringFreeQ[ unselectedContext, "SECRET-222" ]
            },
            NotebookClose @ nb
        ]
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "GetContextFromSelection-ExcludesSelectedAndUnselectedCells@@Tests/Context.wlt:24,1-54,2"
]

VerificationTest[
    Module[ { cell1, cell2, cell3, info },
        cell1 = CellObject[ "included-before-limit" ];
        cell2 = CellObject[ "excluded" ];
        cell3 = CellObject[ "selected" ];
        info = <|
            "Before" -> {
                <| "CellObject" -> cell1 |>,
                <| "CellObject" -> cell2, "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |> |>
            },
            "Selected" -> { <| "CellObject" -> cell3 |> },
            "After" -> { }
        |>;
        Block[ { Wolfram`Chatbook`ChatModes`Context`Private`$maxCellsBeforeSelection = 1 },
            Wolfram`Chatbook`ChatModes`Context`Private`selectContextCells0 @ info
        ]
    ],
    <| "Before" -> { CellObject[ "included-before-limit" ] }, "Selected" -> { CellObject[ "selected" ] }, "After" -> { } |>,
    SameTest -> MatchQ,
    TestID   -> "SelectContextCells-FiltersBeforeApplyingLimits@@Tests/Context.wlt:56,1-76,2"
]

VerificationTest[
    Wolfram`Chatbook`ChatModes`Context`Private`selectContextCells @ {
        <| "CellObject" -> CellObject[ "first" ], "CursorPosition" -> "AboveCell" |>,
        <| "CellObject" -> CellObject[ "second" ], "CursorPosition" -> None |>
    },
    <| "Before" -> { }, "Selected" -> { }, "After" -> { CellObject[ "first" ], CellObject[ "second" ] } |>,
    SameTest -> MatchQ,
    TestID   -> "SelectContextCells-AboveCellIncludesFirstCell@@Tests/Context.wlt:78,1-86,2"
]

VerificationTest[
    UsingFrontEnd @ Module[ { nb1, nb2, settings, context1, context2 },
        WithCleanup[
            nb1 = NotebookPut @ Notebook @ { Cell[ "Project codename: SILVERFISH", "Text" ] };
            nb2 = NotebookPut @ Notebook @ {
                Cell[ "Project codename: GOLDFISH", "Text" ],
                Cell[ "Second cell CATFISH", "Text" ]
            };
            settings = AbsoluteCurrentChatSettings @ nb1;
            context1 = Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, nb1, settings ];
            context2 = Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, nb2, settings ];
            {
                StringQ @ context1 && StringContainsQ[ context1, "SILVERFISH" ],
                StringQ @ context2 && StringContainsQ[ context2, "GOLDFISH" ],
                StringQ @ context2 && StringContainsQ[ context2, "CATFISH" ]
            },
            NotebookClose /@ { nb1, nb2 }
        ]
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "GetContextFromSelection-AboveFirstCell@@Tests/Context.wlt:88,1-110,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`chatExcludedQ @ Cell[ "Text", "Text", TaggingRules -> "unexpected" ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ChatExcludedQ-ToleratesNonKeyValueTaggingRules@@Tests/Context.wlt:112,1-117,2"
]

(* :!CodeAnalysis::EndBlock:: *)
