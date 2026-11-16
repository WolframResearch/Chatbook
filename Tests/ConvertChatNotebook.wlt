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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    $outputTags = <|
        "CellToStringData" -> "OK",
        "MessageTag"       -> "",
        "ChatData"         -> "compressed",
        "HasChatData"      -> True
    |>;

    workspaceInput[ content_ ] := Cell[
        BoxData @ TemplateBox[
            { Cell[ content, Background -> None, Selectable -> True, Editable -> True ] },
            "UserMessageBox"
        ],
        "ChatInput"
    ];

    workspaceOutput[ text_ ] := Cell[
        BoxData @ TemplateBox[
            { Cell[ text, Background -> None, Editable -> True, Selectable -> True ] },
            "AssistantMessageBox"
        ],
        "ChatOutput",
        GeneratedCell     -> True,
        CellAutoOverwrite -> True,
        CellTags          -> { "some-uuid" },
        TaggingRules      -> $outputTags
    ];

    sidebarInput[ content_ ] := Cell[
        BoxData @ TemplateBox[
            { Cell[ content, Background -> None, Selectable -> True, Editable -> True ] },
            "NotebookAssistant`Sidebar`UserMessageBox"
        ],
        "NotebookAssistant`Sidebar`ChatInput"
    ];

    sidebarOutput[ text_ ] := Cell[
        BoxData @ TemplateBox[
            { Cell[ text, Background -> None, Editable -> True, Selectable -> True ] },
            "NotebookAssistant`Sidebar`AssistantMessageBox"
        ],
        "NotebookAssistant`Sidebar`ChatOutput",
        GeneratedCell     -> True,
        CellAutoOverwrite -> True,
        TaggingRules      -> $outputTags
    ];

    convertCells[ cells_ ] := First @ Wolfram`Chatbook`Common`cellsToChatNB[ cells, <| "Model" -> "test" |> ];

    $$keptOutput = Cell[
        TextData[ "OK" | { "OK" } ],
        "ChatOutput",
        OrderlessPatternSequence[
            TaggingRules      -> KeyValuePattern @ { "CellToStringData" -> "OK", "ChatData" -> "compressed" },
            GeneratedCell     -> True,
            CellAutoOverwrite -> True,
            CellDingbat       -> _
        ]
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Workspace Chat*)
VerificationTest[
    convertCells @ { workspaceInput[ "Say OK" ], workspaceOutput[ "OK" ] },
    {
        Cell[ "Say OK", "ChatInput", CellDingbat -> _ ],
        $$keptOutput
    },
    SameTest -> MatchQ,
    TestID   -> "WorkspaceStringInput"
]

VerificationTest[
    convertCells @ {
        workspaceInput @ TextData @ { "Say ", StyleBox[ "OK", FontWeight -> Bold ] },
        workspaceOutput[ "OK" ]
    },
    {
        Cell[ TextData @ { "Say ", StyleBox[ "OK", FontWeight -> Bold ] }, "ChatInput", CellDingbat -> _ ],
        $$keptOutput
    },
    SameTest -> MatchQ,
    TestID   -> "WorkspaceTextDataInput"
]

VerificationTest[
    convertCells @ {
        Cell[ BoxData @ TemplateBox[ { "Say OK" }, "UserMessageBox" ], "ChatInput" ]
    },
    { Cell[ "Say OK", "ChatInput", CellDingbat -> _ ] },
    SameTest -> MatchQ,
    TestID   -> "WorkspaceLegacyRawStringInput"
]

VerificationTest[
    convertCells @ { workspaceInput @ Cell @ BoxData @ GraphicsBox @ DiskBox @ { 0, 0 } },
    { Cell[ TextData[ Cell[ BoxData @ GraphicsBox @ DiskBox @ { 0, 0 } ] ], "ChatInput", CellDingbat -> _ ] },
    SameTest -> MatchQ,
    TestID   -> "WorkspaceBoxInput"
]

VerificationTest[
    FreeQ[
        Cases[
            convertCells @ { workspaceInput[ "Say OK" ], workspaceInput @ TextData @ { "Again" } },
            Cell[ content_, "ChatInput", ___ ] :> content
        ],
        _Cell
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WorkspaceInputNoNestedCell"
]

VerificationTest[
    convertCells @ { workspaceOutput[ "OK" ] },
    { Cell[ _, "ChatOutput", Except[ CellTags -> _ ]... ] },
    SameTest -> MatchQ,
    TestID   -> "WorkspaceOutputDropsCellTags"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sidebar Chat*)
VerificationTest[
    convertCells @ { sidebarInput[ "Say OK" ], sidebarOutput[ "OK" ] },
    {
        Cell[ "Say OK", "ChatInput", CellDingbat -> _ ],
        $$keptOutput
    },
    SameTest -> MatchQ,
    TestID   -> "SidebarStringInput"
]

VerificationTest[
    convertCells @ { sidebarInput @ TextData @ { "Say ", "OK" }, sidebarOutput[ "OK" ] },
    {
        Cell[ TextData @ { "Say ", "OK" }, "ChatInput", CellDingbat -> _ ],
        $$keptOutput
    },
    SameTest -> MatchQ,
    TestID   -> "SidebarTextDataInput"
]

(* :!CodeAnalysis::EndBlock:: *)
