(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/NotebookAssistanceWindow.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/NotebookAssistanceWindow.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    $testNotebook = NotebookObject[ "test-notebook", "test-notebook" ];

    (* The toolbar docked cell of the notebook assistance window, generated without a front end: *)
    $dockedCell = Block[ { EvaluationNotebook = $testNotebook & }, Wolfram`Chatbook`Common`makeWorkspaceChatDockedCell[ ] ];

    (* The (held) initialization of the docked cell: *)
    $dockedCellInitialization = Cases[ $dockedCell, HoldPattern[ Initialization :> init_ ] :> HoldComplete @ init, Infinity ];

    (* Evaluates the docked cell initialization with front end operations and chat initialization replaced by a log: *)
    runDockedCellInitialization // Attributes = { HoldRest };
    runDockedCellInitialization[ { inputCellQ_, chatCellsQ_, initializedQ_ }, warmUp_: Null ] :=
        Module[ { log = { }, result },
            Block[
                {
                    Wolfram`Chatbook`ChatModes`UI`Private`$workspaceChatInitialized = initializedQ,
                    Cells = Function[
                        Null,
                        Replace[
                            { ## },
                            {
                                { _, AttachedCell -> True, CellStyle -> "ChatInputField" } :>
                                    If[ inputCellQ, { CellObject[ "input" ] }, { } ],
                                { _, DockedCell -> True, CellStyle -> "NotebookAssistant`TopStripe" } :>
                                    { CellObject[ "stripe" ] },
                                { _NotebookObject } :>
                                    If[ chatCellsQ, { CellObject[ "chat" ] }, { } ],
                                ___ :>
                                    { }
                            }
                        ]
                    ],
                    NotebookDelete = Function[ AppendTo[ log, { "NotebookDelete", #1 } ] ],
                    FrontEnd`MoveCursorToInputField = Function[ AppendTo[ log, { "MoveCursorToInputField", #3 } ] ],
                    Wolfram`Chatbook`ChatbookAction = Function[ AppendTo[ log, { ## } ]; CellObject[ "input" ] ],
                    Wolfram`Chatbook`ChatModes`UI`Private`attachOverlayMenu = Function[
                        AppendTo[ log, "AttachOverlay" ];
                        CellObject[ "overlay" ]
                    ],
                    Wolfram`Chatbook`ChatModes`UI`Private`restoreVerticalScrollbar = Function[
                        AppendTo[ log, "RestoreScrollbar" ]
                    ],
                    Wolfram`Chatbook`Common`setCurrentValue = Function[ AppendTo[ log, { "setCurrentValue", ## } ] ],
                    Wolfram`Chatbook`ChatModes`UI`Private`initializeWorkspaceChat = Function[
                        AppendTo[ log, "InitializeWorkspaceChat" ];
                        warmUp;
                        Wolfram`Chatbook`ChatModes`UI`Private`$workspaceChatInitialized = True
                    ]
                },
                result = Catch[
                    CheckAbort[ ReleaseHold @ First @ $dockedCellInitialization; "Done", "Aborted" ],
                    _,
                    "Thrown" &
                ];
                <|
                    "Result"      -> result,
                    "Log"         -> log,
                    "Initialized" -> Wolfram`Chatbook`ChatModes`UI`Private`$workspaceChatInitialized
                |>
            ]
        ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions@@Tests/NotebookAssistanceWindow.wlt:25,1-90,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Docked Cell Initialization*)

(* The initialization is asynchronous (a queued evaluation), so queued submits wait for it to finish: *)
VerificationTest[
    {
        Length @ $dockedCellInitialization,
        Cases[ $dockedCell, HoldPattern[ (Rule|RuleDelayed)[ SynchronousInitialization, value_ ] ] :> value, Infinity ]
    },
    { 1, { False } },
    SameTest -> MatchQ,
    TestID   -> "DockedCell-AsynchronousInitialization@@Tests/NotebookAssistanceWindow.wlt:97,1-105,2"
]

(* First window open in a kernel session: the cursor is placed in the chat input field and the loading overlay is
   removed before chat initialization starts, which shows progress in the top stripe instead: *)
VerificationTest[
    runDockedCellInitialization[ { False, False, False } ],
    <|
        "Result" -> "Done",
        "Log" -> {
            "AttachOverlay",
            { "AttachWorkspaceChatInput", $testNotebook, Top },
            { "MoveCursorToInputField", CellObject[ "input" ] },
            { "NotebookDelete", CellObject[ "overlay" ] },
            "RestoreScrollbar",
            { "setCurrentValue", CellObject[ "stripe" ], { TaggingRules, "ProgressIndicator" }, True },
            "InitializeWorkspaceChat",
            { "setCurrentValue", CellObject[ "stripe" ], { TaggingRules, "ProgressIndicator" }, False }
        },
        "Initialized" -> True
    |>,
    SameTest -> MatchQ,
    TestID   -> "DockedCell-ColdOpen@@Tests/NotebookAssistanceWindow.wlt:109,1-127,2"
]

(* Chat is already initialized in this kernel session, so only the chat input field is attached: *)
VerificationTest[
    runDockedCellInitialization[ { False, False, True } ],
    <|
        "Result" -> "Done",
        "Log" -> {
            "AttachOverlay",
            { "AttachWorkspaceChatInput", $testNotebook, Top },
            { "MoveCursorToInputField", CellObject[ "input" ] },
            { "NotebookDelete", CellObject[ "overlay" ] },
            "RestoreScrollbar"
        },
        "Initialized" -> True
    |>,
    SameTest -> MatchQ,
    TestID   -> "DockedCell-WarmOpen@@Tests/NotebookAssistanceWindow.wlt:130,1-145,2"
]

(* Nothing to do if the chat input field exists and chat is already initialized: *)
VerificationTest[
    runDockedCellInitialization[ { True, True, True } ],
    <| "Result" -> "Done", "Log" -> { }, "Initialized" -> True |>,
    SameTest -> MatchQ,
    TestID   -> "DockedCell-AlreadyInitialized@@Tests/NotebookAssistanceWindow.wlt:148,1-153,2"
]

(* After the kernel was quit, the existing window initializes chat again: *)
VerificationTest[
    runDockedCellInitialization[ { True, True, False } ],
    <|
        "Result" -> "Done",
        "Log" -> {
            "AttachOverlay",
            { "AttachWorkspaceChatInput", $testNotebook, Bottom },
            { "MoveCursorToInputField", CellObject[ "input" ] },
            { "NotebookDelete", CellObject[ "overlay" ] },
            "RestoreScrollbar",
            { "setCurrentValue", CellObject[ "stripe" ], { TaggingRules, "ProgressIndicator" }, True },
            "InitializeWorkspaceChat",
            { "setCurrentValue", CellObject[ "stripe" ], { TaggingRules, "ProgressIndicator" }, False }
        },
        "Initialized" -> True
    |>,
    SameTest -> MatchQ,
    TestID   -> "DockedCell-KernelRestart@@Tests/NotebookAssistanceWindow.wlt:156,1-174,2"
]

(* The top stripe progress indicator is reset if chat initialization is aborted: *)
VerificationTest[
    runDockedCellInitialization[ { False, False, False }, Abort[ ] ],
    <|
        "Result" -> "Aborted",
        "Log" -> {
            "AttachOverlay",
            { "AttachWorkspaceChatInput", $testNotebook, Top },
            { "MoveCursorToInputField", CellObject[ "input" ] },
            { "NotebookDelete", CellObject[ "overlay" ] },
            "RestoreScrollbar",
            { "setCurrentValue", CellObject[ "stripe" ], { TaggingRules, "ProgressIndicator" }, True },
            "InitializeWorkspaceChat",
            { "setCurrentValue", CellObject[ "stripe" ], { TaggingRules, "ProgressIndicator" }, False }
        },
        "Initialized" -> False
    |>,
    SameTest -> MatchQ,
    TestID   -> "DockedCell-WarmUpAborted@@Tests/NotebookAssistanceWindow.wlt:177,1-195,2"
]

(* The top stripe progress indicator is reset if chat initialization fails: *)
VerificationTest[
    runDockedCellInitialization[ { False, False, False }, Throw[ $Failed, "WarmUpFailed" ] ],
    <|
        "Result" -> "Thrown",
        "Log" -> {
            "AttachOverlay",
            { "AttachWorkspaceChatInput", $testNotebook, Top },
            { "MoveCursorToInputField", CellObject[ "input" ] },
            { "NotebookDelete", CellObject[ "overlay" ] },
            "RestoreScrollbar",
            { "setCurrentValue", CellObject[ "stripe" ], { TaggingRules, "ProgressIndicator" }, True },
            "InitializeWorkspaceChat",
            { "setCurrentValue", CellObject[ "stripe" ], { TaggingRules, "ProgressIndicator" }, False }
        },
        "Initialized" -> False
    |>,
    SameTest -> MatchQ,
    TestID   -> "DockedCell-WarmUpFailed@@Tests/NotebookAssistanceWindow.wlt:198,1-216,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Input Field*)

(* Submitting with the Enter key or the send button is queued, so it runs after an unfinished chat initialization: *)
VerificationTest[
    With[ { cell = Wolfram`Chatbook`ChatModes`UI`Private`attachedWorkspaceChatInputCell[ "Bottom" ] },
        {
            Cases[
                cell,
                EventHandlerTag[ opts: { ___, "ReturnKeyDown" :> _, ___ } ] :> Cases[ opts, (Method -> method_) :> method ],
                Infinity
            ],
            Cases[
                cell,
                button: ButtonBox[ ___, BoxID -> "NASendChatButton", ___ ] :> Cases[ button, (Method -> method_) :> method ],
                Infinity
            ]
        }
    ],
    { { { "Queued" } }, { { "Queued" } } },
    SameTest -> MatchQ,
    TestID   -> "ChatInput-QueuedSubmit@@Tests/NotebookAssistanceWindow.wlt:223,1-241,2"
]

(* :!CodeAnalysis::EndBlock:: *)
