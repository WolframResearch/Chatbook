(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    If[ ! TrueQ @ Wolfram`ChatbookTests`$TestDefinitionsLoaded,
        Get @ FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" }
    ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ShowNotebookAssistance.wlt:4,1-11,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ShowNotebookAssistance.wlt:13,1-18,2"
]

VerificationTest[
    Context @ ShowNotebookAssistance,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistanceContext@@Tests/ShowNotebookAssistance.wlt:20,1-25,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ShowNotebookAssistance*)
VerificationTest[
    userNotebook = CreateDocument @ ExpressionCell[ FreeformEvaluate[ "picture of a cat" ], "Input" ],
    _NotebookObject,
    SameTest -> MatchQ,
    TestID   -> "CreateUserNotebook@@Tests/ShowNotebookAssistance.wlt:30,1-35,2"
]

VerificationTest[
    SelectionMove[ First @ Cells @ userNotebook, All, Cell ];
    SetSelectedNotebook @ userNotebook;
    chatWindow = ShowNotebookAssistance[
        userNotebook,
        "Window",
        "Input"         -> "How can I find cats in this picture?",
        "EvaluateInput" -> True,
        "NewChat"       -> True,
        "ChatNotebookSettings" -> <|
            "AutoSaveConversations" -> False,
            "Temperature"           -> 0.0,
            "Model"                 -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>,
            "Authentication"        -> Automatic
        |>
    ],
    _NotebookObject,
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance@@Tests/ShowNotebookAssistance.wlt:37,1-56,2"
]

VerificationTest[
    output = CellToString @ NotebookRead @ Last @ Cells[ chatWindow, CellStyle -> "ChatOutput" ],
    _String? (StringContainsQ[ "ImageCases" ]),
    SameTest -> MatchQ,
    TestID   -> "ChatOutput@@Tests/ShowNotebookAssistance.wlt:58,1-63,2"
]

VerificationTest[
    NotebookClose /@ { userNotebook, chatWindow },
    { Null, Null },
    SameTest -> MatchQ,
    TestID   -> "CloseNotebooks@@Tests/ShowNotebookAssistance.wlt:65,1-70,2"
]