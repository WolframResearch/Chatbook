(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    If[ ! TrueQ @ Wolfram`ChatbookTests`$TestDefinitionsLoaded,
        Get @ FileNameJoin @ { DirectoryName[ Echo @ $TestFileName ], "Common.wl" }
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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*How can I find cats in this picture?*)

(* Create a user notebook with an image: *)
VerificationTest[
    image = FreeformEvaluate[ "picture of a cat" ],
    _Image? ImageQ,
    SameTest -> MatchQ,
    TestID   -> "EvaluateImage@@Tests/ShowNotebookAssistance.wlt:36,1-41,2"
]

VerificationTest[
    userNotebook = CreateDocument @ ExpressionCell[ image, "Input" ],
    _NotebookObject,
    SameTest -> MatchQ,
    TestID   -> "CreateUserNotebook@@Tests/ShowNotebookAssistance.wlt:43,1-48,2"
]

(* Show notebook assistance window and evaluate a query concerning the selection: *)
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
    SameTest       -> MatchQ,
    TestID         -> "ShowNotebookAssistance@@Tests/ShowNotebookAssistance.wlt:51,1-71,2",
    TimeConstraint -> 30
]

(* ImageCases should appear somewhere in the response: *)
VerificationTest[
    output = CellToString[
        NotebookRead @ Last @ Cells[ chatWindow, CellStyle -> "ChatOutput" ],
        "ContentTypes" -> { "Image", "Text" }
    ],
    _String? (StringContainsQ[ "ImageCases" ]),
    SameTest -> MatchQ,
    TestID   -> "ChatOutput@@Tests/ShowNotebookAssistance.wlt:74,1-82,2"
]

(* Ensure that the LLM used the image inline in their response: *)
VerificationTest[
    GetExpressionURIs @ output,
    { ___, image, ___ },
    SameTest -> MatchQ,
    TestID   -> "GetExpressionURIs@@Tests/ShowNotebookAssistance.wlt:85,1-90,2"
]

(* Ensure there are no pink boxes in the chat window: *)
VerificationTest[
    CurrentValue[ chatWindow, Selectable ] = True;
    SelectionMove[ chatWindow, All, Notebook ];
    MathLink`CallFrontEnd @ FrontEnd`GetErrorsInSelectionPacket @ chatWindow,
    { },
    SameTest -> MatchQ,
    TestID   -> "NoPinkBoxes@@Tests/ShowNotebookAssistance.wlt:93,1-100,2"
]

(* Ensure no unexpected cells appeared in chat window: *)
VerificationTest[
    CurrentValue[ Cells @ chatWindow, "CellStyleName" ],
    { "ChatInput", "ChatOutput" },
    SameTest -> MatchQ,
    TestID   -> "NoErrorMessages@@Tests/ShowNotebookAssistance.wlt:103,1-108,2"
]

(* Cleanup: *)
VerificationTest[
    NotebookClose /@ { userNotebook, chatWindow },
    { Null, Null },
    SameTest -> MatchQ,
    TestID   -> "Cleanup@@Tests/ShowNotebookAssistance.wlt:111,1-116,2"
]