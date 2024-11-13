(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    If[ ! TrueQ @ Wolfram`ChatbookTests`$TestDefinitionsLoaded,
        Get @ FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" }
    ],
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
    Context @ ShowNotebookAssistance,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistanceContext"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ShowNotebookAssistance*)
VerificationTest[
    userNotebook = CreateDocument @ ExpressionCell[ FreeformEvaluate[ "picture of a cat" ], "Input" ],
    _NotebookObject,
    SameTest -> MatchQ,
    TestID   -> "CreateUserNotebook"
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
    TestID   -> "ShowNotebookAssistance"
]

VerificationTest[
    output = CellToString @ NotebookRead @ Last @ Cells[ chatWindow, CellStyle -> "ChatOutput" ],
    _String? (StringContainsQ[ "ImageCases" ]),
    SameTest -> MatchQ,
    TestID   -> "ChatOutput"
]

VerificationTest[
    NotebookClose /@ { userNotebook, chatWindow },
    { Null, Null },
    SameTest -> MatchQ,
    TestID   -> "CloseNotebooks"
]