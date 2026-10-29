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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Moved To History Notice*)
VerificationTest[
    (* The tags of the docked cells below the top stripe (the chat's title or the "moved to History" notice): *)
    subDockedCellTags[ nbo_NotebookObject ] :=
        Cases[ AbsoluteCurrentValue[ nbo, DockedCells ], Cell[ ___, CellTags -> tag_String, ___ ] :> tag ];

    writeTestExchange[ nbo_NotebookObject ] := (
        SelectionMove[ nbo, After, Notebook ];
        NotebookWrite[ nbo, { Cell[ "PREVIOUS-CHAT", "ChatInput" ], Cell[ "PREVIOUS-CHAT reply", "ChatOutput" ] } ]
    );

    (* Saves the test exchange like an auto-save at the end of a chat evaluation: *)
    saveTestExchange[ uuid_String ] := SaveChat[
        {
            <| "Role" -> "User"     , "Content" -> "PREVIOUS-CHAT"       |>,
            <| "Role" -> "Assistant", "Content" -> "PREVIOUS-CHAT reply" |>
        },
        <| "AppName" -> "NotebookAssistance", "ConversationUUID" -> uuid, "AutoSaveConversations" -> True |>,
        "AutoGenerateTitle" -> False,
        "AutoSaveOnly"      -> True
    ];

    (* Opens an assistant window with an exchange, optionally saves it, then replaces it like the toolbar's
       "Open as a window" button. Returns the new window, the UUID of the previous chat and the windows that got the
       notice (a headless front end only gives docked cells to the first window with the WorkspaceChat stylesheet, so
       the calls are logged instead of read from the window): *)
    replaceAssistantWindow[ source_NotebookObject, save_ ] := Module[ { old, uuid, new, log = { } },
        old = ShowNotebookAssistance[
            source,
            "Window",
            "NewChat"              -> True,
            "ChatNotebookSettings" -> <| "AutoSaveConversations" -> save |>
        ];
        writeTestExchange @ old;
        uuid = CurrentChatSettings[ old, "ConversationUUID" ];
        If[ save, saveTestExchange @ uuid ];
        Block[ { Wolfram`Chatbook`Common`writeWorkspaceChatMovedToHistoryDockedCell = AppendTo[ log, #1 ] & },
            new = ShowNotebookAssistance[ source, "NotebookToolbarWindow" ]
        ];
        { new, uuid, log }
    ];

    (* A stand-in for an assistant window, with the docked cells that the WorkspaceChat stylesheet gives it: *)
    dockedCellsTestWindow[ ] := CreateDocument[
        { },
        Visible     -> False,
        DockedCells -> { Cell[ "", "NotebookAssistant`TopStripe" ], Cell[ "TOOLBAR" ] }
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "MovedNotice-Definitions@@Tests/NotebookAssistanceWindow.wlt:246,1-297,2"
]

(* Only a chat that is in History counts as moved there: *)
VerificationTest[
    UsingFrontEnd @ Module[ { nbo, uuid, results },
        uuid = CreateUUID[ ];
        nbo = CreateDocument[ { }, Visible -> False ];
        CurrentChatSettings[ nbo, "AppName" ] = "NotebookAssistance";
        CurrentChatSettings[ nbo, "ConversationUUID" ] = uuid;
        WithCleanup[
            results = {
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`previousChatSavedQ @ nbo,
                writeTestExchange @ nbo;
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`previousChatSavedQ @ nbo,
                saveTestExchange @ uuid;
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`previousChatSavedQ @ nbo,
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`previousChatSavedQ @ Missing[ "NotFound" ],
                (* without a ConversationUUID or AppName: *)
                CurrentChatSettings[ nbo, "ConversationUUID" ] = Inherited;
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`previousChatSavedQ @ nbo,
                Wolfram`Chatbook`Common`savedChatQ[ Automatic, CreateUUID[ ] ]
            },
            Quiet @ DeleteChat[ "NotebookAssistance", uuid ];
            NotebookClose @ nbo
        ];
        results
    ],
    { False, False, True, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "MovedNotice-SavedChatOnly@@Tests/NotebookAssistanceWindow.wlt:300,1-327,2"
]

(* A chat that wasn't saved (AutoSaveConversations is False) gets no notice: *)
VerificationTest[
    UsingFrontEnd @ Module[ { source, new, uuid, log, before, results },
        source = CreateDocument[ { }, Visible -> False ];
        before = Length @ ListSavedChats[ "NotebookAssistance" ];
        WithCleanup[
            { new, uuid, log } = replaceAssistantWindow[ source, False ];
            results = {
                log,
                Cells[ new, AttachedCell -> True, CellStyle -> "AttachedOverlayMenu" ],
                Length @ ListSavedChats[ "NotebookAssistance" ] === before
            },
            Quiet @ NotebookClose @ new;
            NotebookClose @ source
        ];
        results
    ],
    { { }, { }, True },
    SameTest -> MatchQ,
    TestID   -> "MovedNotice-NotSaved@@Tests/NotebookAssistanceWindow.wlt:330,1-349,2"
]

(* A saved chat gets the notice in the new window: *)
VerificationTest[
    UsingFrontEnd @ Module[ { source, new, uuid, log, results },
        source = CreateDocument[ { }, Visible -> False ];
        WithCleanup[
            { new, uuid, log } = replaceAssistantWindow[ source, True ];
            results = { log === { new }, Cells[ new, AttachedCell -> True, CellStyle -> "AttachedOverlayMenu" ] },
            Quiet @ DeleteChat[ "NotebookAssistance", uuid ];
            Quiet @ NotebookClose @ new;
            NotebookClose @ source
        ];
        results
    ],
    { True, { } },
    SameTest -> MatchQ,
    TestID   -> "MovedNotice-Saved@@Tests/NotebookAssistanceWindow.wlt:352,1-367,2"
]

(* The notice is a docked cell, so the loading overlay of the window's initialization doesn't remove it: *)
VerificationTest[
    UsingFrontEnd @ Module[ { nbo, results },
        nbo = dockedCellsTestWindow[ ];
        WithCleanup[
            Wolfram`Chatbook`Common`writeWorkspaceChatMovedToHistoryDockedCell @ nbo;
            results = {
                subDockedCellTags @ nbo,
                Wolfram`Chatbook`ChatModes`UI`Private`withLoadingOverlay[ { nbo, None }, Null ];
                subDockedCellTags @ nbo,
                Cells[ nbo, AttachedCell -> True, CellStyle -> "AttachedOverlayMenu" ]
            },
            NotebookClose @ nbo
        ];
        results
    ],
    { { "WorkspaceChatMovedToHistoryDockedCell" }, { "WorkspaceChatMovedToHistoryDockedCell" }, { } },
    SameTest -> MatchQ,
    TestID   -> "MovedNotice-SurvivesLoadingOverlay@@Tests/NotebookAssistanceWindow.wlt:370,1-388,2"
]

(* The notice and the chat's title share the place below the top stripe, so there is at most one of them and the
   toolbar stays last: *)
VerificationTest[
    UsingFrontEnd @ Module[ { nbo, styles, results },
        nbo = dockedCellsTestWindow[ ];
        styles = Function[ Cases[ AbsoluteCurrentValue[ nbo, DockedCells ], Cell[ _, s_String, ___ ] :> s ] ];
        WithCleanup[
            Wolfram`Chatbook`Common`setCurrentValue[ nbo, { TaggingRules, "ConversationTitle" }, "Test Title" ];
            results = {
                Wolfram`Chatbook`Common`writeWorkspaceChatMovedToHistoryDockedCell @ nbo;
                Wolfram`Chatbook`Common`writeWorkspaceChatMovedToHistoryDockedCell @ nbo;
                subDockedCellTags @ nbo,
                Wolfram`Chatbook`Common`writeWorkspaceChatTitleDockedCell[ nbo, WindowTitle ];
                subDockedCellTags @ nbo,
                Wolfram`Chatbook`Common`writeWorkspaceChatTitleDockedCell[ nbo, WindowTitle ];
                subDockedCellTags @ nbo,
                Length @ AbsoluteCurrentValue[ nbo, DockedCells ],
                First @ styles[ ],
                Last @ AbsoluteCurrentValue[ nbo, DockedCells ]
            },
            NotebookClose @ nbo
        ];
        results
    ],
    {
        { "WorkspaceChatMovedToHistoryDockedCell" },
        { "WorkspaceChatTitleDockedCell" },
        { "WorkspaceChatTitleDockedCell" },
        3,
        "NotebookAssistant`TopStripe",
        Cell[ "TOOLBAR" ]
    },
    SameTest -> MatchQ,
    TestID   -> "MovedNotice-SharesTitlePlace@@Tests/NotebookAssistanceWindow.wlt:392,1-424,2"
]

(* :!CodeAnalysis::EndBlock:: *)
