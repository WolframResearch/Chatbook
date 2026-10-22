(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ACPWindow.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ACPWindow.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    (* CI runs every test file in one kernel and one context: helpers that other test files define too are cleared
       first, so that none of their definitions is used here *)
    ClearAll[ calls, withLocalPathTrap ];

    $acpTestDataDirectory = FileNameJoin @ { DirectoryName @ $TestFileName, "Data", "ACPWindow" };
    $testNB   = NotebookObject[ "acp-test-notebook" ];
    $testNB2  = NotebookObject[ "acp-test-notebook-2" ];
    $userCell = CellObject[ "acp-test-user-cell" ];
    $outCell  = CellObject[ "acp-test-output-cell" ];

    (* Raw ACP configOptions as sent by OpenCode (trimmed) *)
    $testConfigOptions = {
        <|
            "id" -> "model", "name" -> "Model", "category" -> "model", "type" -> "select",
            "currentValue" -> "openai/gpt-6.1-sol",
            "options" -> {
                <| "value" -> "openai/gpt-6.1-sol", "name" -> "openai/GPT-6.1 Sol" |>,
                <| "value" -> "openai/gpt-6-luna" , "name" -> "openai/GPT-6 Luna"  |>,
                <| "value" -> "opencode/big-pickle", "name" -> "opencode/Big Pickle" |>
            }
        |>,
        <|
            "id" -> "effort", "name" -> "Effort", "description" -> "Available effort levels for this model",
            "category" -> "thought_level", "type" -> "select", "currentValue" -> "default",
            "options" -> { <| "value" -> "high", "name" -> "High" |>, <| "value" -> "default", "name" -> "Default" |> }
        |>,
        <|
            "id" -> "mode", "name" -> "Session Mode", "category" -> "mode", "type" -> "select", "currentValue" -> "build",
            "options" -> {
                <| "value" -> "build", "name" -> "Build", "description" -> "The default agent." |>,
                <| "value" -> "plan" , "name" -> "Plan" , "description" -> "Read-only agent." |>
            }
        |>
    };

    (* English strings without a front end (acpLabel is defined in Rendering.wl) *)
    mockLabel // ClearAll;
    mockLabel[ key_String ] := Lookup[ Wolfram`Chatbook`ACP`Common`$acpUIStrings, key, key ];
    mockLabel[ key_String, params_Association ] := TemplateApply[ StringTemplate @ mockLabel @ key, params ];

    (* Call log for mocked functions *)
    $callLog = { };
    logCall // ClearAll;
    logCall[ name_String, args___ ] := (AppendTo[ $callLog, { name, args } ]; Null);

    (* Front end flags of the test windows ({TaggingRules, "ACP", key}) *)
    $feFlags = <| |>;
    feGet // ClearAll;
    feGet[ nbo_, key_String ] := Lookup[ $feFlags, Key @ { nbo, key }, Missing[ "NotSet" ] ];
    feGet[ nbo_, key_String, default_ ] := Lookup[ $feFlags, Key @ { nbo, key }, default ];
    feSet // ClearAll;
    feSet[ nbo_, key_String, value_ ] := ($feFlags[ { nbo, key } ] = value);

    mockSchedule // ClearAll;
    mockSchedule // Attributes = { HoldFirst };
    mockSchedule[ eval_, delay___ ] := logCall[ "Schedule", HoldForm @ eval, delay ];

    (* The front end shows a frozen live view at once (a second before the write checks for it, so the write is not
       delayed); the tests of the wait itself replace this *)
    mockFreezeLiveView // ClearAll;
    mockFreezeLiveView[ id_String ] := (
        logCall[ "FreezeLiveView", id ];
        Wolfram`Chatbook`ACP`Common`acpTurnUpdate[ id, <| "Turn" -> <| #, "FrozenViewShownAt" -> AbsoluteTime[ ] - 1 |>, "Changed" -> { }, "Layout" -> False |> & ];
        Null
    );

    mockNewTurn // ClearAll;
    mockNewTurn[ init_Association ] := <| "Status" -> "Running", "Order" -> { }, "Entities" -> <| |>, "EndTime" -> None, init |>;

    mockApplyTurnEnd // ClearAll;
    mockApplyTurnEnd[ turn_Association, end_Association, time_ ] := <| turn, end, "EndTime" -> time |>;

    testWindow // ClearAll;
    testWindow[ nbo_, rules___ ] := <|
        Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, $TemporaryDirectory, "OpenCode", <| |> ],
        "Status"        -> "Ready",
        "ConfigOptions" -> $testConfigOptions,
        rules
    |>;

    (* Isolates ACP state and replaces everything that would need a front end, an agent, or other ACP files *)
    withACPMocks // ClearAll;
    withACPMocks // Attributes = { HoldFirst };
    withACPMocks[ eval_ ] := withACPMocks[ eval, <| |> ];
    withACPMocks[ eval_, init_Association ] := Block[
        {
            Wolfram`Chatbook`ACP`Common`$acpWindows           = Lookup[ init, "Windows", <| |> ],
            Wolfram`Chatbook`ACP`Common`$acpTurns             = Lookup[ init, "Turns", <| |> ],
            Wolfram`Chatbook`ACP`Common`$acpOpen              = <| |>,
            Wolfram`Chatbook`ACP`State`Private`$symbols       = <| |>,
            Wolfram`Chatbook`ACP`State`Private`$dirty         = <| |>,
            Wolfram`Chatbook`ACP`State`Private`$frozenTurns   = <| |>,
            Wolfram`Chatbook`ACP`UI`Private`$derivedSignatures = <| |>,
            Wolfram`Chatbook`ACP`UI`Private`$windowTitles     = <| |>,
            Wolfram`Chatbook`ACP`UI`Private`acpPreference     = Missing[ "NotSet" ] &,
            Wolfram`Chatbook`ACP`UI`Private`acpSetPreference  = logCall[ "SetPreference", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpEnsurePublisher    = Null &,
            Wolfram`Chatbook`ACP`Common`acpCheckSession       = True &,
            Wolfram`Chatbook`ACP`Common`acpFE                 = feGet,
            Wolfram`Chatbook`ACP`Common`acpFESet              = feSet,
            Wolfram`Chatbook`ACP`Common`acpSchedule           = mockSchedule,
            Wolfram`Chatbook`ACP`Common`acpSendPrompt         = logCall[ "SendPrompt", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpEnsureConnected    = logCall[ "EnsureConnected", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpStop               = logCall[ "Stop", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpNewSession         = logCall[ "NewSession", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpDisconnect         = logCall[ "Disconnect", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpSetConfigOption    = logCall[ "SetConfigOption", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpSetProjectDirectory = logCall[ "SetProjectDirectory", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpAnswerPermission   = logCall[ "AnswerPermission", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpReconnect          = logCall[ "Reconnect", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpMainLinkRun        = Function[ { n, job, label }, logCall[ "MainLinkRun", n, HoldForm @ job, label ], HoldRest ],
            Wolfram`Chatbook`ACP`Common`acpBillingLabel       = Replace[ #, { s_String /; StringStartsQ[ s, "openai/" ] :> "OpenAI (your account)", _ :> "OpenCode (free)" } ] &,
            Wolfram`Chatbook`ACP`Common`acpNewTurn            = mockNewTurn,
            Wolfram`Chatbook`ACP`Common`acpApplyTurnEnd       = mockApplyTurnEnd,
            Wolfram`Chatbook`ACP`Common`acpLiveView           = (Dynamic @ liveView[ # ] &),
            Wolfram`Chatbook`ACP`Common`acpFreezeLiveView     = mockFreezeLiveView,
            Wolfram`Chatbook`ACP`Common`acpFinalCell          = (Cell[ "final:" <> #, "ChatOutput" ] &),
            Wolfram`Chatbook`ACP`Common`acpTurnToMarkdown     = ("markdown" &),
            Wolfram`Chatbook`ACP`Common`acpPermissionPanel    = (permissionPanel[ # ] &),
            Wolfram`Chatbook`ACP`Common`acpToolbarStatusView  = (statusView[ # ] &),
            Wolfram`Chatbook`ACP`Common`acpUsageMeterView     = (usageMeter[ # ] &),
            Wolfram`Chatbook`ACP`Common`acpLabel              = mockLabel,
            Wolfram`Chatbook`Common`writeWorkspaceChatInputCell = (logCall[ "WriteUserCell", ## ]; $userCell) &,
            NotebookWrite  = logCall[ "NotebookWrite", ## ] &,
            NotebookDelete = logCall[ "NotebookDelete", ## ] &,
            SetOptions     = logCall[ "SetOptions", ## ] &,
            Cells          = Replace[ { ## }, { { _, CellTags -> id_String } :> { $outCell }, _ :> { } } ] &,
            ParentNotebook = $testNB &,
            Notebooks      = { $testNB, $testNB2 } &,
            $feFlags       = Lookup[ init, "FE", <| |> ],
            $callLog       = { }
        },
        eval
    ];

    (* Debug log: tests that make isolated code log on purpose run inside withExpectedLog; everything else that is
       logged as a message or failure is unexpected (Window-DebugLog at the end) *)
    $acpLogStart = AbsoluteTime[ ];
    $acpExpectedLogWindows = { };
    withExpectedLog // ClearAll;
    withExpectedLog // Attributes = { HoldFirst };
    withExpectedLog[ eval_ ] := Module[ { t0 = AbsoluteTime[ ], result },
        result = eval;
        AppendTo[ $acpExpectedLogWindows, { t0, AbsoluteTime[ ] } ];
        result
    ];

    calledQ // ClearAll;
    calledQ[ name_String ] := MemberQ[ $callLog, { name, ___ } ];
    calls // ClearAll;
    calls[ name_String ] := Cases[ $callLog, { name, args___ } :> { args } ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions@@Tests/ACPWindow.wlt:25,1-181,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook Assistant Input Cell (unchanged)*)

(* The notebook assistance window's input cell must be unchanged by the ACP integration. *)
VerificationTest[
    $goldenInputCells = Import[ FileNameJoin @ { $acpTestDataDirectory, "AttachedWorkspaceChatInputCell.wxf" }, "WXF" ];
    Keys @ $goldenInputCells[ "Cells" ],
    { "Top", "Bottom" },
    SameTest -> MatchQ,
    TestID   -> "NAInputCell-GoldenData@@Tests/ACPWindow.wlt:188,1-194,2"
]

(* Exact comparison with the boxes generated by the original code (only for the version the data was created with,
   since ToBoxes output could change between versions) *)
VerificationTest[
    If[ { $VersionNumber, $ReleaseNumber } === Lookup[ $goldenInputCells, { "VersionNumber", "ReleaseNumber" } ],
        Block[ { $SessionID = 0 },
            Wolfram`Chatbook`ChatModes`UI`Private`attachedWorkspaceChatInputCell /@ { "Top", "Bottom" }
        ] === Values @ $goldenInputCells[ "Cells" ],
        Missing[ "TestSkipped" ]
    ],
    True | Missing[ "TestSkipped" ],
    SameTest -> MatchQ,
    TestID   -> "NAInputCell-Golden@@Tests/ACPWindow.wlt:198,1-208,2"
]

(* Comparison with the original code (Tests/Data/ACPWindow/ReferenceWorkspaceCode.wl) evaluated in this kernel *)
VerificationTest[
    Block[
        {
            $ContextPath = {
                "Wolfram`Chatbook`ChatModes`Common`",
                "Wolfram`Chatbook`Common`",
                "Wolfram`Chatbook`",
                "System`"
            }
        },
        Get @ FileNameJoin @ { $acpTestDataDirectory, "ReferenceWorkspaceCode.wl" }
    ];
    {
        DownValues @ Wolfram`Chatbook`ChatModes`UI`Private`referenceAttachedWorkspaceChatInputCell,
        DownValues @ Wolfram`Chatbook`ChatModes`Evaluate`Private`referenceEvaluateWorkspaceChat
    },
    { { _RuleDelayed }, { _RuleDelayed } },
    SameTest -> MatchQ,
    TestID   -> "NAInputCell-LoadReference@@Tests/ACPWindow.wlt:211,1-230,2"
]

VerificationTest[
    Block[ { $SessionID = 12345 },
        {
            Wolfram`Chatbook`ChatModes`UI`Private`attachedWorkspaceChatInputCell[ "Top" ] ===
                Wolfram`Chatbook`ChatModes`UI`Private`referenceAttachedWorkspaceChatInputCell[ "Top" ],
            Wolfram`Chatbook`ChatModes`UI`Private`attachedWorkspaceChatInputCell[ "Bottom" ] ===
                Wolfram`Chatbook`ChatModes`UI`Private`referenceAttachedWorkspaceChatInputCell[ "Bottom" ]
        }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "NAInputCell-Reference@@Tests/ACPWindow.wlt:232,1-244,2"
]

(* attachWorkspaceChatInput dispatches on the window's AppName *)
VerificationTest[
    Block[ { $SessionID = 0 },
        Wolfram`Chatbook`ChatModes`UI`Private`workspaceChatInputCell[ $testNB, "Top", "NotebookAssistance" ] ===
            Wolfram`Chatbook`ChatModes`UI`Private`attachedWorkspaceChatInputCell[ "Top" ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WorkspaceChatInputCell-Dispatch-NA@@Tests/ACPWindow.wlt:247,1-255,2"
]

VerificationTest[
    withACPMocks @ Wolfram`Chatbook`ChatModes`UI`Private`workspaceChatInputCell[ $testNB, "Bottom", "ACP" ],
    Cell[ _BoxData, "ChatInputField", ___, CellTags -> "Bottom", ___ ],
    SameTest -> MatchQ,
    TestID   -> "WorkspaceChatInputCell-Dispatch-ACP@@Tests/ACPWindow.wlt:257,1-262,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*writeWorkspaceChatInputCell*)

(* evaluateWorkspaceChat (now using writeWorkspaceChatInputCell) makes exactly the same front end calls as the
   original code. *)
VerificationTest[
    nbEquivalence // ClearAll;
    nbEquivalence[ evaluate_, input0_ ] := Module[ { input = input0, result },
        Block[
            {
                $callLog = { },
                SelectionMove                                       = logCall[ "SelectionMove", ## ] &,
                NotebookWrite                                       = logCall[ "NotebookWrite", ## ] &,
                Cells                                               = (logCall[ "Cells", ## ]; { $userCell }) &,
                Wolfram`Chatbook`ChatModes`Common`moveChatInputToBottom = logCall[ "MoveInputToBottom", ## ] &,
                Wolfram`Chatbook`Common`setCurrentValue             = logCall[ "SetCurrentValue", ## ] &,
                Wolfram`Chatbook`Common`createUUID                  = "test-uuid" &,
                Wolfram`Chatbook`ChatCellEvaluate                   = (logCall[ "ChatCellEvaluate", ## ]; Null) &
            },
            result = evaluate[ $testNB, Dynamic @ input ];
            { result, input, $callLog }
        ]
    ];
    {
        nbEquivalence[ Wolfram`Chatbook`Common`evaluateWorkspaceChat, "Hello" ],
        nbEquivalence[ Wolfram`Chatbook`Common`evaluateWorkspaceChat, "Hello" ] ===
            nbEquivalence[ Wolfram`Chatbook`ChatModes`Evaluate`Private`referenceEvaluateWorkspaceChat, "Hello" ]
    },
    {
        {
            Null,
            "",
            {
                { "SelectionMove", $testNB, After, Notebook, AutoScroll -> True },
                { "NotebookWrite", $testNB, Cell[ BoxData @ TemplateBox[ { Cell[ "Hello", ___ ] }, "UserMessageBox" ], "ChatInput", CellTags -> "test-uuid" ] },
                { "MoveInputToBottom", $testNB },
                { "Cells", $testNB, CellTags -> "test-uuid" },
                { "SetCurrentValue", $userCell, CellTags, { } },
                { "ChatCellEvaluate", $userCell, $testNB }
            }
        },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "EvaluateWorkspaceChat-Equivalence-String@@Tests/ACPWindow.wlt:270,1-310,2"
]

VerificationTest[
    nbEquivalence[ Wolfram`Chatbook`Common`evaluateWorkspaceChat, RowBox @ { "x", "+", SuperscriptBox[ "y", "2" ] } ] ===
        nbEquivalence[ Wolfram`Chatbook`ChatModes`Evaluate`Private`referenceEvaluateWorkspaceChat, RowBox @ { "x", "+", SuperscriptBox[ "y", "2" ] } ],
    True,
    SameTest -> MatchQ,
    TestID   -> "EvaluateWorkspaceChat-Equivalence-Boxes@@Tests/ACPWindow.wlt:312,1-318,2"
]

VerificationTest[
    {
        nbEquivalence[ Wolfram`Chatbook`Common`evaluateWorkspaceChat, "   " ],
        nbEquivalence[ Wolfram`Chatbook`Common`evaluateWorkspaceChat, "   " ] ===
            nbEquivalence[ Wolfram`Chatbook`ChatModes`Evaluate`Private`referenceEvaluateWorkspaceChat, "   " ]
    },
    { { Null, "", { } }, True },
    SameTest -> MatchQ,
    TestID   -> "EvaluateWorkspaceChat-Equivalence-NoInput@@Tests/ACPWindow.wlt:320,1-329,2"
]

VerificationTest[
    Module[ { input = "Hi", result },
        Block[
            {
                $callLog = { },
                SelectionMove                                       = logCall[ "SelectionMove", ## ] &,
                NotebookWrite                                       = logCall[ "NotebookWrite", ## ] &,
                Cells                                               = { $userCell } &,
                Wolfram`Chatbook`ChatModes`Common`moveChatInputToBottom = logCall[ "MoveInputToBottom", ## ] &,
                Wolfram`Chatbook`Common`setCurrentValue             = logCall[ "SetCurrentValue", ## ] &
            },
            result = Wolfram`Chatbook`Common`writeWorkspaceChatInputCell[ $testNB, Dynamic @ input ];
            { result, input, calledQ /@ { "NotebookWrite", "MoveInputToBottom" } }
        ]
    ],
    { $userCell, "", { True, True } },
    SameTest -> MatchQ,
    TestID   -> "WriteWorkspaceChatInputCell-Result@@Tests/ACPWindow.wlt:331,1-349,2"
]

VerificationTest[
    Module[ { input = "\n  " },
        Block[ { $callLog = { }, NotebookWrite = logCall[ "NotebookWrite", ## ] & },
            { Wolfram`Chatbook`Common`writeWorkspaceChatInputCell[ $testNB, Dynamic @ input ], input, $callLog }
        ]
    ],
    { Missing[ "NoInput" ], "", { } },
    SameTest -> MatchQ,
    TestID   -> "WriteWorkspaceChatInputCell-NoInput@@Tests/ACPWindow.wlt:351,1-360,2"
]

(* The input can be stored in notebook TaggingRules (agent windows) *)
VerificationTest[
    Block[
        {
            CurrentValue,
            $callLog = { },
            SelectionMove                                       = Null &,
            NotebookWrite                                       = logCall[ "NotebookWrite", ## ] &,
            Cells                                               = { $userCell } &,
            Wolfram`Chatbook`ChatModes`Common`moveChatInputToBottom = Null &,
            Wolfram`Chatbook`Common`setCurrentValue             = Null &
        },
        CurrentValue[ $testNB, { TaggingRules, "ACP", "Input" } ] = "From tagging rules";
        {
            Wolfram`Chatbook`Common`writeWorkspaceChatInputCell[ $testNB, Dynamic @ CurrentValue[ $testNB, { TaggingRules, "ACP", "Input" } ] ],
            CurrentValue[ $testNB, { TaggingRules, "ACP", "Input" } ],
            calls[ "NotebookWrite" ]
        }
    ],
    {
        $userCell,
        "",
        { { $testNB, Cell[ BoxData @ TemplateBox[ { Cell[ "From tagging rules", ___ ] }, "UserMessageBox" ], "ChatInput", ___ ] } }
    },
    SameTest -> MatchQ,
    TestID   -> "WriteWorkspaceChatInputCell-CurrentValue@@Tests/ACPWindow.wlt:363,1-388,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ShowNotebookAssistance "ACPWindow"*)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[
            None,
            "ACPWindow",
            "Input"                -> "Hello",
            "EvaluateInput"        -> True,
            "NewChat"              -> "Toggle",
            "ChatNotebookSettings" -> <| "ProjectDirectory" -> "/tmp/project", "ACPModel" -> "openai/gpt-6.1-sol" |>
        ]
    ],
    { None, "Hello", True, True, <| "ProjectDirectory" -> "/tmp/project", "ACPModel" -> "openai/gpt-6.1-sol" |> },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-Arguments@@Tests/ACPWindow.wlt:393,1-407,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ $testNB, "ACPWindow" ]
    ],
    { $testNB, "", False, False, <| |> },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-Defaults@@Tests/ACPWindow.wlt:409,1-416,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`showACPWindow   = ({ ## } &),
            Wolfram`Chatbook`Common`getUserNotebook = ($testNB2 &)
        },
        ShowNotebookAssistance[ "ACPWindow", "ChatNotebookSettings" -> { "ProjectDirectory" -> File[ "/tmp/project" ] } ]
    ],
    { $testNB2, "", False, False, <| "ProjectDirectory" -> File[ "/tmp/project" ] |> },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-UserNotebook@@Tests/ACPWindow.wlt:418,1-429,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`showACPWindow = ({ ## } &),
            Wolfram`Chatbook`Common`parentNotebook = ($testNB &)
        },
        ShowNotebookAssistance[ $userCell, "ACPWindow", "NewChat" -> True ]
    ],
    { $testNB, "", False, True, <| |> },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-CellObject@@Tests/ACPWindow.wlt:431,1-442,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ProjectDirectory" -> 42 |> ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidDirectory@@Tests/ACPWindow.wlt:444,1-452,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPAgent" -> "SomethingElse" |> ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidAgent@@Tests/ACPWindow.wlt:454,1-462,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> "/tmp/project" ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidSettings@@Tests/ACPWindow.wlt:464,1-472,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPModel" -> None |> ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidModel@@Tests/ACPWindow.wlt:474,1-482,2"
]

(* "ACPMCPServer": True, False or Automatic *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        {
            Last @ ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPMCPServer" -> # |> ] & /@ { True, False, Automatic },
            Quiet[ FailureQ @ ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPMCPServer" -> # |> ] & /@ { "Yes", 1, None } ]
        }
    ],
    { { <| "ACPMCPServer" -> True |>, <| "ACPMCPServer" -> False |>, <| "ACPMCPServer" -> Automatic |> }, { True, True, True } },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-MCPServer@@Tests/ACPWindow.wlt:485,1-495,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPMCPServer" -> "off" |> ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidMCPServer@@Tests/ACPWindow.wlt:497,1-505,2"
]

(* "ACPAgentCommandLine": a program (string or File) or a command line { program, args... }, as in RunProcess *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        {
            ! FailureQ @ ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPAgentCommandLine" -> # |> ] & /@ {
                Automatic,
                "/opt/opencode/bin/opencode",
                File[ "/opt/opencode/bin/opencode" ],
                "opencode",
                { "ssh", "host", "~/.opencode/bin/opencode", "acp" },
                { File[ "/opt/opencode/bin/opencode" ], "acp" }
            },
            Quiet[ FailureQ @ ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPAgentCommandLine" -> # |> ] & /@ {
                { },
                { "ssh", 22 },
                42,
                None
            } ]
        }
    ],
    { { True, True, True, True, True, True }, { True, True, True, True } },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-CommandLine@@Tests/ACPWindow.wlt:508,1-530,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPAgentCommandLine" -> { "ssh", 22 } |> ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidCommandLine@@Tests/ACPWindow.wlt:532,1-540,2"
]

(* "SSHSettings": passed on in canonical form; an invalid value is refused with its reason *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        {
            Last @ ShowNotebookAssistance[
                None,
                "ACPWindow",
                "ChatNotebookSettings" -> <|
                    "SSHSettings" -> <|
                        "Username"    -> "ubuntu",
                        "MachineName" -> "ec2-203-0-113-100.compute-1.amazonaws.com",
                        "Arguments"   -> { "-i", "C:/Users/rhennigan/keys/aws_key.pem" }
                    |>
                |>
            ],
            Last @ ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> { "SSHSettings" -> "me@devbox", "ACPModel" -> "m" } ],
            Last @ ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "SSHSettings" -> None |> ],
            Last @ ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "SSHSettings" -> Automatic, "ProjectDirectory" -> "C:\\local" |> ],
            Replace[
                Quiet[ ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "SSHSettings" -> # |> ] & /@ {
                    <| "MachineName" -> "-oProxyCommand=x" |>,
                    <| "MachineName" -> "h", "Arguments" -> { "-N" } |>,
                    <| "MachineName" -> "h", "Arguments" -> { "-o", "StrictHostKeyChecking=no" } |>,
                    <| "MachineName" -> "h", "Port" -> 22 |>,
                    42
                } ],
                Failure[ tag_, as_Association ] :> { tag, Lookup[ as, "MessageParameters" ] },
                { 1 }
            ]
        }
    ],
    {
        <|
            "SSHSettings" -> <|
                "MachineName" -> "ec2-203-0-113-100.compute-1.amazonaws.com",
                "Username"    -> "ubuntu",
                "Arguments"   -> { "-i", "C:/Users/rhennigan/keys/aws_key.pem" },
                "Executable"  -> Automatic
            |>
        |>,
        <|
            "SSHSettings" -> <| "MachineName" -> "devbox", "Username" -> "me", "Arguments" -> { }, "Executable" -> Automatic |>,
            "ACPModel"    -> "m"
        |>,
        <| "SSHSettings" -> None |>,
        <| "SSHSettings" -> None, "ProjectDirectory" -> "C:\\local" |>,
        {
            { "ShowNotebookAssistance::InvalidACPSSHSettings", { _String? (StringContainsQ[ "\"MachineName\"" ]) } },
            { "ShowNotebookAssistance::InvalidACPSSHSettings", { _String? (StringContainsQ[ "-N can't be used" ]) } },
            { "ShowNotebookAssistance::InvalidACPSSHSettings", { _String? (StringContainsQ[ "StrictHostKeyChecking" ]) } },
            { "ShowNotebookAssistance::InvalidACPSSHSettings", { _String? (StringContainsQ[ "unknown key \"Port\"" ]) } },
            { "ShowNotebookAssistance::InvalidACPSSHSettings", { _String } }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-SSHSettings@@Tests/ACPWindow.wlt:543,1-598,2"
]

(* With "SSHSettings" in the same call, the folder must be a remote path and the command line must be sendable *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        With[ { show = ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "SSHSettings" -> "u@h", ## |> ] & },
            {
                ! FailureQ @ show[ "ProjectDirectory" -> # ] & /@ { "~/proj", " /srv/app ", File[ "~" ], "/", None, Automatic },
                Quiet[ FailureQ @ show[ "ProjectDirectory" -> # ] & /@ { "C:\\proj", "proj", "~bob/x", "/a\nb", File[ "rel" ] } ],
                ! FailureQ @ show[ "ACPAgentCommandLine" -> # ] & /@ {
                    Automatic, "opencode", "~/.opencode/bin/opencode", { "/opt/oc/bin/opencode", "acp" }, File[ "/opt/oc" ]
                },
                Quiet[ FailureQ @ show[ "ACPAgentCommandLine" -> # ] & /@ { "~bob/oc", { "-x" }, { "oc", "a\nb" }, "oc\nx" } ],
                (* without SSH the same folder and command line are local ones *)
                ! FailureQ @ ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ProjectDirectory" -> "proj", "ACPAgentCommandLine" -> "~bob/oc" |> ]
            }
        ]
    ],
    {
        { True, True, True, True, True, True },
        { True, True, True, True, True },
        { True, True, True, True, True },
        { True, True, True, True },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-SSHPair@@Tests/ACPWindow.wlt:601,1-625,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Actions*)

(* Every action name is dispatched to its handler with the given arguments *)
VerificationTest[
    Sort @ Flatten @ Replace[
        Cases[
            DownValues @ Wolfram`Chatbook`ACP`UI`Private`acpAction0,
            HoldPattern[ Verbatim[ HoldPattern ][ Wolfram`Chatbook`ACP`UI`Private`acpAction0[ name_, ___ ] ] :> _ ] :> name
        ],
        {
            name_String :> name,
            Verbatim[ Pattern ][ _, Verbatim[ Alternatives ][ names__String ] ] :> { names },
            _ :> Nothing
        },
        { 1 }
    ],
    Sort @ Wolfram`Chatbook`ACP`UI`Private`$acpActionNames,
    SameTest -> MatchQ,
    TestID   -> "ACPAction-Names@@Tests/ACPWindow.wlt:632,1-648,2"
]

VerificationTest[
    $acpActionDispatch = {
        { { "Send"               , $testNB                     }, Wolfram`Chatbook`ACP`Common`evaluateACPChat                      , { $testNB } },
        { { "Stop"               , $testNB                     }, Wolfram`Chatbook`ACP`UI`Private`acpStopAction                , { $testNB } },
        { { "NewChat"            , $testNB                     }, Wolfram`Chatbook`ACP`Common`acpNewChat                       , { $testNB } },
        { { "ToggleOpen"         , "turn-1", { "Tool", "t1" }, True }, Wolfram`Chatbook`ACP`Common`acpToggleOpen               , { "turn-1", { "Tool", "t1" }, True } },
        { { "PermissionResponse" , $testNB, "req-1", "once"    }, Wolfram`Chatbook`ACP`UI`Private`acpPermissionResponseAction  , { $testNB, "req-1", "once" } },
        { { "PermissionDetails"  , $testNB, "k0"               }, Wolfram`Chatbook`ACP`Common`acpPermissionDetails             , { $testNB, "k0" } },
        { { "SetConfigOption"    , $testNB, "model", "a/b"     }, Wolfram`Chatbook`ACP`UI`Private`acpSetConfigOptionAction     , { $testNB, "model", "a/b" } },
        { { "SetProjectDirectory", $testNB, "/tmp"             }, Wolfram`Chatbook`ACP`UI`Private`acpSetProjectDirectoryAction , { $testNB, "/tmp" } },
        { { "Reconnect"          , $testNB                     }, Wolfram`Chatbook`ACP`UI`Private`acpReconnectAction           , { $testNB } },
        { { "ErrorAction"        , $testNB, "Reconnect"        }, Wolfram`Chatbook`ACP`UI`Private`acpErrorAction               , { $testNB, "Reconnect" } },
        { { "WindowClosed"       , $testNB                     }, Wolfram`Chatbook`ACP`UI`Private`acpWindowClosed              , { $testNB } },
        { { "InitializeWindow"   , $testNB                     }, Wolfram`Chatbook`ACP`UI`Private`acpInitializeWindowAction    , { $testNB } },
        { { "DismissNotice"      , $testNB                     }, Wolfram`Chatbook`ACP`Common`acpSetNotice                     , { $testNB, None } },
        { { "CancelQueuedPrompt" , $testNB                     }, Wolfram`Chatbook`ACP`UI`Private`acpCancelQueuedPrompt        , { $testNB } },
        { { "SetAgentExecutable" , $testNB, "/opt/opencode"    }, Wolfram`Chatbook`ACP`UI`Private`acpSetAgentExecutableAction  , { $testNB, "/opt/opencode" } },
        { { "ChooseModel"        , $testNB                     }, Wolfram`Chatbook`ACP`UI`Private`acpErrorAction               , { $testNB, "ChooseModel" } },
        { { "SignIn"             , $testNB                     }, Wolfram`Chatbook`ACP`UI`Private`acpErrorAction               , { $testNB, "SignIn" } },
        { { "LocateAgent"        , $testNB                     }, Wolfram`Chatbook`ACP`UI`Private`acpErrorAction               , { $testNB, "LocateAgent" } },
        { { "ChooseDirectory"    , $testNB                     }, Wolfram`Chatbook`ACP`UI`Private`acpErrorAction               , { $testNB, "ChooseDirectory" } },
        { { "ToggleErrorDetail"  , $testNB                     }, Wolfram`Chatbook`ACP`UI`Private`acpToggleErrorDetail         , { $testNB } },
        { { "CopyErrorDetail"    , $testNB                     }, Wolfram`Chatbook`ACP`UI`Private`acpCopyErrorDetail           , { $testNB } },
        { { "CopyNoticeCommand"  , $testNB                     }, Wolfram`Chatbook`ACP`UI`Private`acpCopyNoticeCommand         , { $testNB } },
        { { "ReviewChanges"      , $testNB                     }, Wolfram`Chatbook`ACP`Common`acpReviewChanges                 , { $testNB } },
        { { "ReviewRefresh"      , $testNB2                    }, Wolfram`Chatbook`ACP`Common`acpReviewRefresh                 , { $testNB2 } },
        { { "ReviewOpenFile"     , "/project/a.txt"            }, Wolfram`Chatbook`ACP`Common`acpReviewOpenFile                , { "/project/a.txt" } },
        { { "ReviewDiffView"     , <| "Path" -> "a.txt" |>     }, Wolfram`Chatbook`ACP`Common`acpReviewDiffView                , { <| "Path" -> "a.txt" |> } },
        { { "RestoreSession"     , $testNB, "ses-1", "/project" }, Wolfram`Chatbook`ACP`Common`acpRestoreSessionAction        , { $testNB, "ses-1", "/project" } },
        { { "NewSessionIn"       , $testNB, "/project"         }, Wolfram`Chatbook`ACP`Common`acpNewSessionInAction          , { $testNB, "/project" } },
        { { "DeleteSession"      , $testNB, "ses-1"            }, Wolfram`Chatbook`ACP`Common`acpDeleteSessionAction         , { $testNB, "ses-1" } },
        { { "SessionsRefresh"    , $testNB                     }, Wolfram`Chatbook`ACP`Common`acpSessionsRefresh             , { $testNB } },
        { { "SessionsClosed"     , $testNB                     }, Wolfram`Chatbook`ACP`Common`acpSessionsClosed              , { $testNB } },
        { { "ToggleSessions"     , $testNB                     }, Wolfram`Chatbook`ACP`Common`acpToggleSessions              , { $testNB } },
        { { "SessionsOpen"          , $testNB, "k1"            }, Wolfram`Chatbook`ACP`Common`acpSessionsWindowAction, { "SessionsOpen", $testNB, "k1" } },
        { { "SessionsNew"           , $testNB, "k2"            }, Wolfram`Chatbook`ACP`Common`acpSessionsWindowAction, { "SessionsNew", $testNB, "k2" } },
        { { "SessionsOpenFolder"    , $testNB, "k2"            }, Wolfram`Chatbook`ACP`Common`acpSessionsWindowAction, { "SessionsOpenFolder", $testNB, "k2" } },
        { { "SessionsToggleProject" , $testNB, "k2", True      }, Wolfram`Chatbook`ACP`Common`acpSessionsWindowAction, { "SessionsToggleProject", $testNB, "k2", True } },
        { { "SessionsConfirmDelete" , $testNB, "k1"            }, Wolfram`Chatbook`ACP`Common`acpSessionsWindowAction, { "SessionsConfirmDelete", $testNB, "k1" } },
        { { "SessionsDelete"        , $testNB, "k1"            }, Wolfram`Chatbook`ACP`Common`acpSessionsWindowAction, { "SessionsDelete", $testNB, "k1" } },
        { { "SessionsCancelDelete"  , $testNB                  }, Wolfram`Chatbook`ACP`Common`acpSessionsWindowAction, { "SessionsCancelDelete", $testNB } },
        { { "SessionsDismissNotice" , $testNB                  }, Wolfram`Chatbook`ACP`Common`acpSessionsWindowAction, { "SessionsDismissNotice", $testNB } },
        { { "SessionsShowMore"      , $testNB, "k2"            }, Wolfram`Chatbook`ACP`Common`acpSessionsWindowAction, { "SessionsShowMore", $testNB, "k2" } },
        { { "FolderPickerEnter"       , $testNB, "k3"          }, Wolfram`Chatbook`ACP`Common`acpFolderPickerAction, { "FolderPickerEnter", $testNB, "k3" } },
        { { "FolderPickerUp"          , $testNB                }, Wolfram`Chatbook`ACP`Common`acpFolderPickerAction, { "FolderPickerUp", $testNB } },
        { { "FolderPickerHome"        , $testNB                }, Wolfram`Chatbook`ACP`Common`acpFolderPickerAction, { "FolderPickerHome", $testNB } },
        { { "FolderPickerGo"          , $testNB, $testNB2      }, Wolfram`Chatbook`ACP`Common`acpFolderPickerAction, { "FolderPickerGo", $testNB, $testNB2 } },
        { { "FolderPickerRefresh"     , $testNB                }, Wolfram`Chatbook`ACP`Common`acpFolderPickerAction, { "FolderPickerRefresh", $testNB } },
        { { "FolderPickerToggleHidden", $testNB                }, Wolfram`Chatbook`ACP`Common`acpFolderPickerAction, { "FolderPickerToggleHidden", $testNB } },
        { { "FolderPickerShowMore"    , $testNB                }, Wolfram`Chatbook`ACP`Common`acpFolderPickerAction, { "FolderPickerShowMore", $testNB } },
        { { "FolderPickerChoose"      , $testNB                }, Wolfram`Chatbook`ACP`Common`acpFolderPickerAction, { "FolderPickerChoose", $testNB } },
        { { "FolderPickerCancel"      , $testNB                }, Wolfram`Chatbook`ACP`Common`acpFolderPickerAction, { "FolderPickerCancel", $testNB } },
        { { "FolderPickerCopyError"   , $testNB                }, Wolfram`Chatbook`ACP`Common`acpFolderPickerAction, { "FolderPickerCopyError", $testNB } },
        { { "FolderPickerCopyCommand" , $testNB                }, Wolfram`Chatbook`ACP`Common`acpFolderPickerAction, { "FolderPickerCopyCommand", $testNB } },
        { { "FolderPickerClosed"      , $testNB                }, Wolfram`Chatbook`ACP`Common`acpFolderPickerAction, { "FolderPickerClosed", $testNB } },
        { { "AttachMenu"              , $testNB                }, Wolfram`Chatbook`ACP`Common`acpAttachmentsAction, { "AttachMenu", $testNB } },
        { { "AttachNotebook"          , $testNB, "nb-k"        }, Wolfram`Chatbook`ACP`Common`acpAttachmentsAction, { "AttachNotebook", $testNB, "nb-k" } },
        { { "AttachFiles"             , $testNB, { "/tmp/a" }  }, Wolfram`Chatbook`ACP`Common`acpAttachmentsAction, { "AttachFiles", $testNB, { "/tmp/a" } } },
        { { "RemoveAttachment"        , $testNB, "file-k"      }, Wolfram`Chatbook`ACP`Common`acpAttachmentsAction, { "RemoveAttachment", $testNB, "file-k" } },
        { { "ShowAttachment"          , $testNB, "nb-k"        }, Wolfram`Chatbook`ACP`Common`acpAttachmentsAction, { "ShowAttachment", $testNB, "nb-k" } },
        { { "OpenPromptNotebook"      , $testNB                }, Wolfram`Chatbook`ACP`Common`acpPromptNotebookAction, { "OpenPromptNotebook", $testNB } },
        { { "PromptNotebookSend"      , $testNB2               }, Wolfram`Chatbook`ACP`Common`acpPromptNotebookAction, { "PromptNotebookSend", $testNB2 } },
        { { "PromptNotebookCancel"    , $testNB2               }, Wolfram`Chatbook`ACP`Common`acpPromptNotebookAction, { "PromptNotebookCancel", $testNB2 } },
        { { "PromptNotebookOpenWindow", $testNB2               }, Wolfram`Chatbook`ACP`Common`acpPromptNotebookAction, { "PromptNotebookOpenWindow", $testNB2 } }
    };
    Sort[ #[[ 1, 1 ]] & /@ $acpActionDispatch ] === Sort @ Wolfram`Chatbook`ACP`UI`Private`$acpActionNames,
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPAction-DispatchTable@@Tests/ACPWindow.wlt:650,1-719,2"
]

VerificationTest[
    Function[
        { args, handler, expected },
        Block[ { handler = (logCall[ "Handler", ## ]; "handled") & },
            Block[ { $callLog = { } },
                { Wolfram`Chatbook`Common`acpAction @@ args, calls[ "Handler" ] } === { "handled", { expected } }
            ]
        ],
        HoldAll
    ] @@@ $acpActionDispatch,
    { True .. },
    SameTest -> MatchQ,
    TestID   -> "ACPAction-Dispatch@@Tests/ACPWindow.wlt:721,1-734,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`ACP`Common`acpSetNotice = logCall[ "Notice", ## ] & },
        Block[ { $callLog = { } },
            ChatbookAction[ "ACP", "DismissNotice", $testNB ];
            $callLog
        ]
    ],
    { { "Notice", $testNB, None } },
    SameTest -> MatchQ,
    TestID   -> "ACPAction-ChatbookAction@@Tests/ACPWindow.wlt:736,1-746,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`acpAction[ "NotAnAction", 1, 2 ],
    Missing[ "UnknownAction", "NotAnAction" ],
    SameTest -> MatchQ,
    TestID   -> "ACPAction-Unknown@@Tests/ACPWindow.wlt:748,1-753,2"
]

(* Failures in actions never escape (they may run preemptively inside a Notebook Assistant chat) *)
VerificationTest[
    withExpectedLog @ Block[ { Wolfram`Chatbook`ACP`Common`evaluateACPChat = Throw[ "escaped", "SomeTag" ] & },
        Catch[ Wolfram`Chatbook`Common`acpAction[ "Send", $testNB ], _, "escaped" & ]
    ],
    Failure[ "ACPInternal", _ ],
    SameTest -> MatchQ,
    TestID   -> "ACPAction-Isolated-Throw@@Tests/ACPWindow.wlt:756,1-763,2"
]

VerificationTest[
    withExpectedLog @ Block[ { Wolfram`Chatbook`ACP`Common`evaluateACPChat = Wolfram`Chatbook`Common`throwInternalFailure[ "test" ] & },
        Catch[
            Block[ { Wolfram`Chatbook`Common`$catching = True }, Wolfram`Chatbook`Common`acpAction[ "Send", $testNB ] ],
            _,
            "escaped" &
        ]
    ],
    Failure[ "ACPInternal", _ ],
    SameTest -> MatchQ,
    TestID   -> "ACPAction-Isolated-InternalFailure@@Tests/ACPWindow.wlt:765,1-776,2"
]

VerificationTest[
    withExpectedLog @ Block[ { Wolfram`Chatbook`ACP`Common`evaluateACPChat = (Message[ General::argx, "x", 1 ]; 1/0) & },
        Wolfram`Chatbook`Common`acpAction[ "Send", $testNB ]
    ],
    ComplexInfinity,
    SameTest -> MatchQ,
    TestID   -> "ACPAction-Isolated-Messages@@Tests/ACPWindow.wlt:778,1-785,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sending*)
VerificationTest[
    withACPMocks[
        Module[ { turnID, window },
            turnID = Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB;
            window = Wolfram`Chatbook`ACP`Common`acpWindowGet @ $testNB;
            {
                StringQ @ turnID,
                window[ "Status" ],
                window[ "CurrentTurn" ] === turnID,
                window[ "QueuedTurn" ],
                $feFlags[ { $testNB, "Busy" } ],
                calls[ "SendPrompt" ] === { { $testNB, turnID } },
                calledQ[ "EnsureConnected" ],
                calls[ "NotebookWrite" ],
                Lookup[ Wolfram`Chatbook`ACP`Common`acpTurnGet @ turnID, { "Prompt", "InputCell", "OutputCell", "Notebook" } ]
            }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow @ $testNB |>,
            "FE"      -> <| { $testNB, "Input" } -> "Fix the bug" |>
        |>
    ],
    {
        True,
        "Running",
        True,
        None,
        True,
        True,
        False,
        {
            {
                System`NotebookLocationSpecifier[ $userCell, "After" ],
                Cell[
                    BoxData @ TemplateBox[ { Cell[ BoxData @ StyleBox[ DynamicBox[ _ ], "Text" ], ___ ] }, "AssistantMessageBoxActive" ],
                    "ChatOutput",
                    ___,
                    CellTags -> { "ACPActiveTurn", _String },
                    ___
                ],
                None,
                AutoScroll -> False
            }
        },
        { "Fix the bug", $userCell, $outCell, $testNB }
    },
    SameTest -> MatchQ,
    TestID   -> "EvaluateACPChat-Ready@@Tests/ACPWindow.wlt:790,1-838,2"
]

VerificationTest[
    withACPMocks[
        Module[ { turnID, window },
            turnID = Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB;
            window = Wolfram`Chatbook`ACP`Common`acpWindowGet @ $testNB;
            { window[ "Status" ], window[ "QueuedTurn" ] === turnID, calledQ[ "SendPrompt" ], calledQ[ "EnsureConnected" ] }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Connecting" ] |>,
            "FE"      -> <| { $testNB, "Input" } -> "Hello" |>
        |>
    ],
    { "Connecting", True, False, False },
    SameTest -> MatchQ,
    TestID   -> "EvaluateACPChat-Connecting@@Tests/ACPWindow.wlt:840,1-855,2"
]

VerificationTest[
    withACPMocks[
        Module[ { turnID, window },
            turnID = Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB;
            window = Wolfram`Chatbook`ACP`Common`acpWindowGet @ $testNB;
            { window[ "QueuedTurn" ] === turnID, calls[ "EnsureConnected" ] }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Disconnected" ] |>,
            "FE"      -> <| { $testNB, "Input" } -> "Hello" |>
        |>
    ],
    { True, { { $testNB } } },
    SameTest -> MatchQ,
    TestID   -> "EvaluateACPChat-Disconnected@@Tests/ACPWindow.wlt:857,1-872,2"
]

VerificationTest[
    withACPMocks[
        {
            Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB,
            Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Notice" ],
            Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "CurrentTurn" ],
            calledQ[ "WriteUserCell" ],
            $feFlags[ { $testNB, "Input" } ]
        },
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "NoDirectory" ] |>,
            "FE"      -> <| { $testNB, "Input" } -> "Hello" |>
        |>
    ],
    { Null, _String, None, False, "Hello" },
    SameTest -> MatchQ,
    TestID   -> "EvaluateACPChat-NoDirectory@@Tests/ACPWindow.wlt:874,1-891,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB;
        Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB;
        {
            Wolfram`Chatbook`ACP`Common`acpQueuedPromptOf @ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedPrompt" ],
            $feFlags[ { $testNB, "Input" } ],
            Length @ calls[ "WriteUserCell" ]
        },
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-0" ] |>,
            "FE"      -> <| { $testNB, "Input" } -> "Also do this" |>
        |>
    ],
    { <| "Text" -> "Also do this", "Attachments" -> { } |>, "", 0 },
    SameTest -> MatchQ,
    TestID   -> "EvaluateACPChat-QueuePrompt@@Tests/ACPWindow.wlt:893,1-910,2"
]

VerificationTest[
    withACPMocks[
        { Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB, $callLog },
        <|
            "Windows" -> <| $testNB -> testWindow @ $testNB |>,
            "FE"      -> <| { $testNB, "Input" } -> "  \n " |>
        |>
    ],
    { Null, { } },
    SameTest -> MatchQ,
    TestID   -> "EvaluateACPChat-NoInput@@Tests/ACPWindow.wlt:912,1-923,2"
]

(* A turn waiting for the connection is sent by housekeeping when the window becomes ready *)
VerificationTest[
    withACPMocks[
        Module[ { turnID },
            turnID = Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB;
            Wolfram`Chatbook`ACP`Common`acpWindowSet[ $testNB, <| "Status" -> "Ready", "SessionID" -> "ses_1" |> ];
            Wolfram`Chatbook`ACP`UI`Private`acpUIHousekeeping[ ];
            {
                calls[ "SendPrompt" ] === { { $testNB, turnID } },
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Status" ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedTurn" ],
                Wolfram`Chatbook`ACP`Common`acpTurnGet[ turnID, "SessionID" ]
            }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Connecting" ] |>,
            "FE"      -> <| { $testNB, "Input" } -> "Hello" |>
        |>
    ],
    { True, "Running", None, "ses_1" },
    SameTest -> MatchQ,
    TestID   -> "QueuedTurn-SentWhenReady@@Tests/ACPWindow.wlt:926,1-947,2"
]

VerificationTest[
    withACPMocks[
        Module[ { turnID },
            turnID = Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB;
            Wolfram`Chatbook`ACP`Common`acpWindowSet[ $testNB, "Status", "Error" ];
            Wolfram`Chatbook`ACP`UI`Private`acpUIHousekeeping[ ];
            {
                calledQ[ "SendPrompt" ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedTurn" ],
                Wolfram`Chatbook`ACP`Common`acpTurnGet[ turnID, "Error" ],
                calls[ "Schedule" ]
            }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Connecting" ] |>,
            "FE"      -> <| { $testNB, "Input" } -> "Hello" |>
        |>
    ],
    { False, None, KeyValuePattern[ "Code" -> "NotConnected" ], { { HoldForm[ _Wolfram`Chatbook`ACP`Common`acpFinalizeTurn ] } } },
    SameTest -> MatchQ,
    TestID   -> "QueuedTurn-FailsOnError@@Tests/ACPWindow.wlt:949,1-970,2"
]

VerificationTest[
    withACPMocks[
        Module[ { turnID },
            turnID = Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB;
            Wolfram`Chatbook`Common`acpAction[ "Stop", $testNB ];
            {
                calledQ[ "Stop" ],
                Wolfram`Chatbook`ACP`Common`acpTurnGet[ turnID, { "ClientCancel", "StopReason" } ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedTurn" ]
            }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Connecting" ] |>,
            "FE"      -> <| { $testNB, "Input" } -> "Hello" |>
        |>
    ],
    { False, { "Stop", "cancelled" }, None },
    SameTest -> MatchQ,
    TestID   -> "QueuedTurn-StopLocally@@Tests/ACPWindow.wlt:972,1-991,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`Common`acpAction[ "Stop", $testNB ];
        { calls[ "Stop" ], $feFlags[ { $testNB, "Busy" } ] },
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |>,
            "Turns"   -> <| "turn-1" -> <| "ID" -> "turn-1", "Notebook" -> $testNB |> |>,
            "FE"      -> <| { $testNB, "Busy" } -> True |>
        |>
    ],
    { { { $testNB } }, True },
    SameTest -> MatchQ,
    TestID   -> "Stop-Running@@Tests/ACPWindow.wlt:993,1-1006,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`Common`acpAction[ "Stop", $testNB ];
        { calledQ[ "Stop" ], $feFlags[ { $testNB, "Busy" } ] },
        <|
            "Windows" -> <| $testNB -> testWindow @ $testNB |>,
            "FE"      -> <| { $testNB, "Busy" } -> True |>
        |>
    ],
    { False, False },
    SameTest -> MatchQ,
    TestID   -> "Stop-NothingRunning@@Tests/ACPWindow.wlt:1008,1-1020,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Attachments*)

(* Messages with attachments (Attachments.wl): Send takes the draft and the input, and a main link job prepares the
   attachments (mocked: acpMainLinkRun only logs); its result starts or queues the turn, or gives the draft back *)
VerificationTest[
    $nbRef   = <| "Kind" -> "Notebook", "Key" -> "nb-1", "Notebook" -> $testNB2, "Name" -> "Spec.nb", "Cells" -> 3 |>;
    $fileRef = <| "Kind" -> "File", "Key" -> "file-1", "Path" -> "/tmp/data.csv", "Name" -> "data.csv", "Size" -> 12 |>;
    $preparedAttachments = {
        <| "Kind" -> "Notebook", "Name" -> "Spec.nb", "Path" -> None, "Ref" -> $nbRef, "Text" -> "# Spec", "Images" -> { }, "Cells" -> 3 |>,
        <| "Kind" -> "File", "Name" -> "data.csv", "Path" -> "/tmp/data.csv", "Ref" -> $fileRef, "Text" -> "a,b", "Images" -> { }, "Size" -> 12 |>
    };
    preparingWindow // ClearAll;
    preparingWindow[ token_String, input_, rules___ ] := testWindow[
        $testNB,
        "Preparing" -> <| "Token" -> token, "StartedAt" -> AbsoluteTime[ ], "Input" -> input, "Text" -> input, "Attachments" -> { $nbRef, $fileRef } |>,
        rules
    ];
    (* the cell writes of a turn's start: the window has a cell to write after *)
    withCellMocks // ClearAll;
    withCellMocks // Attributes = { HoldFirst };
    withCellMocks[ eval_ ] := Block[
        {
            Cells = Replace[ { ## }, { { _, CellTags -> _String } :> { $outCell }, { _ } :> { $userCell }, _ :> { } } ] &,
            SelectionMove = logCall[ "SelectionMove", ## ] &,
            Wolfram`Chatbook`Common`setCurrentValue = logCall[ "SetCurrentValue", ## ] &,
            Wolfram`Chatbook`ChatModes`Common`moveChatInputToBottom = logCall[ "MoveInputToBottom", ## ] &
        },
        eval
    ];
    $attachmentsChipsCell = Cell[
        BoxData @ TagBox[ _, "ACPAttachments", TaggingRules -> KeyValuePattern[ "CellToStringData" -> "[Attached notebook: Spec.nb]\n[Attached file: data.csv]" ] ],
        "Text",
        ___
    ],
    _,
    SameTest -> MatchQ,
    TestID   -> "Attachments-Definitions@@Tests/ACPWindow.wlt:1028,1-1061,2"
]

VerificationTest[
    withACPMocks[
        Module[ { result, window },
            result = Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB;
            window = Wolfram`Chatbook`ACP`Common`acpWindowGet @ $testNB;
            {
                result,
                KeyTake[ window[ "Preparing" ], { "Input", "Text", "Attachments" } ],
                StringQ @ window[ "Preparing", "Token" ],
                window[ "Attachments" ],
                Lookup[ $feFlags, { { $testNB, "Input" }, { $testNB, "Attachments" }, { $testNB, "Busy" }, { $testNB, "PreparingPrompt" } } ],
                With[ { nb = $testNB, token = window[ "Preparing", "Token" ] },
                    calls[ "MainLinkRun" ] === { { nb, HoldForm @ Wolfram`Chatbook`ACP`Common`acpPrepareAttachmentsJob[ nb, token ], "Attachments" } }
                ],
                calledQ /@ { "WriteUserCell", "SendPrompt", "NotebookWrite" }
            }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Attachments" -> { $nbRef, $fileRef } ] |>,
            "FE"      -> <| { $testNB, "Input" } -> "Review this" |>
        |>
    ],
    {
        Null,
        <| "Input" -> "Review this", "Text" -> "Review this", "Attachments" -> { $nbRef, $fileRef } |>,
        True,
        { },
        { "", { }, True, <| "Input" -> "Review this", "Text" -> "Review this", "Attachments" -> { $nbRef, $fileRef } |> },
        True,
        { False, False, False }
    },
    SameTest -> MatchQ,
    TestID   -> "Attachments-SendPrepares@@Tests/ACPWindow.wlt:1063,1-1096,2"
]

(* Send works with attachments and no typed text; while a message is prepared, another Send keeps its text *)
VerificationTest[
    {
        withACPMocks[
            Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB;
            { KeyTake[ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Preparing" ], { "Input", "Text" } ], Length @ calls[ "MainLinkRun" ] },
            <|
                "Windows" -> <| $testNB -> testWindow[ $testNB, "Attachments" -> { $fileRef } ] |>,
                "FE"      -> <| { $testNB, "Input" } -> "  " |>
            |>
        ],
        withACPMocks[
            Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB;
            {
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Notice" ],
                $feFlags[ { $testNB, "Input" } ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Preparing" ][ "Token" ],
                calledQ /@ { "MainLinkRun", "WriteUserCell" }
            },
            <|
                "Windows" -> <| $testNB -> preparingWindow[ "t0", "First", "Attachments" -> { $fileRef } ] |>,
                "FE"      -> <| { $testNB, "Input" } -> "More" |>
            |>
        ]
    },
    {
        { <| "Input" -> "", "Text" -> "" |>, 1 },
        { "The attachments of the last message are still being prepared.", "More", "t0", { False, False } }
    },
    SameTest -> MatchQ,
    TestID   -> "Attachments-SendWithoutTextAndWhilePreparing@@Tests/ACPWindow.wlt:1099,1-1129,2"
]

(* The prepared message starts its turn: the user cell shows the typed text and the chips (addressed write after the last
   cell), the turn has the attachments (acpSendPrompt sends them) *)
VerificationTest[
    withACPMocks[
        withCellMocks @ Module[ { turnID, window },
            turnID = Wolfram`Chatbook`ACP`Common`acpPreparedPrompt[ $testNB, "t1", <| "Attachments" -> $preparedAttachments |> ];
            window = Wolfram`Chatbook`ACP`Common`acpWindowGet @ $testNB;
            {
                StringQ @ turnID,
                window[ "Preparing" ],
                window[ "CurrentTurn" ] === turnID,
                Wolfram`Chatbook`ACP`Common`acpTurnGet[ turnID, "Attachments" ] === $preparedAttachments,
                Wolfram`Chatbook`ACP`Common`acpTurnGet[ turnID, "Prompt" ],
                calls[ "SendPrompt" ] === { { $testNB, turnID } },
                First @ calls[ "NotebookWrite" ],
                Lookup[ $feFlags, { { $testNB, "PreparingPrompt" }, { $testNB, "Busy" } } ],
                calls[ "SelectionMove" ]
            }
        ],
        <| "Windows" -> <| $testNB -> preparingWindow[ "t1", "Review this" ] |> |>
    ],
    {
        True,
        None,
        True,
        True,
        "Review this",
        True,
        {
            System`NotebookLocationSpecifier[ $userCell, "After" ],
            Cell[ BoxData[ TemplateBox[ { Cell[ TextData[ { "Review this", "\n", $attachmentsChipsCell } ], ___ ] }, "UserMessageBox" ] ], "ChatInput", CellTags -> _String ],
            None,
            AutoScroll -> False
        },
        { None, True },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "Attachments-PreparedStartsTurn@@Tests/ACPWindow.wlt:1133,1-1170,2"
]

(* While a turn runs, the prepared message is queued (merged with a queued one); the TaggingRules keep its text and the
   references of its attachments, never their content *)
VerificationTest[
    withACPMocks[
        Module[ { first, merged },
            Wolfram`Chatbook`ACP`Common`acpPreparedPrompt[ $testNB, "t1", <| "Attachments" -> $preparedAttachments |> ];
            first = { Wolfram`Chatbook`ACP`Common`acpQueuedPromptOf @ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedPrompt" ], $feFlags[ { $testNB, "QueuedPrompt" } ] };
            Wolfram`Chatbook`ACP`UI`Private`acpQueuePrompt[ $testNB, "And this", Take[ $preparedAttachments, 1 ] ];
            merged = Wolfram`Chatbook`ACP`Common`acpQueuedPromptOf @ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedPrompt" ];
            {
                first,
                merged[ "Text" ],
                Length @ merged[ "Attachments" ],
                $feFlags[ { $testNB, "QueuedPrompt" } ],
                Wolfram`Chatbook`ACP`UI`Private`acpQueuedPromptView[ $testNB, merged, False ],
                calledQ /@ { "WriteUserCell", "NotebookWrite", "SendPrompt" }
            }
        ],
        <| "Windows" -> <| $testNB -> preparingWindow[ "t1", "Review this", "Status" -> "Running", "CurrentTurn" -> "turn-0" ] |> |>
    ],
    {
        {
            <| "Text" -> "Review this", "Attachments" -> $preparedAttachments |>,
            <| "Text" -> "Review this", "Attachments" -> { $nbRef, $fileRef } |>
        },
        "Review this\n\nAnd this",
        3,
        <| "Text" -> "Review this\n\nAnd this", "Attachments" -> { $nbRef, $fileRef } |>,
        _? (! FreeQ[ #, s_String /; StringContainsQ[ s, "Review this And this +3 attachments" ] ] &),
        { False, False, False }
    },
    SameTest -> MatchQ,
    TestID   -> "Attachments-PreparedQueues@@Tests/ACPWindow.wlt:1174,1-1205,2"
]

(* A failed preparation gives the message back: its text before what was typed since, its attachments into the draft,
   with the failure's notice; a result for another preparation (cancelled) is ignored *)
VerificationTest[
    {
        withACPMocks[
            Wolfram`Chatbook`ACP`Common`acpPreparedPrompt[
                $testNB,
                "t1",
                Failure[ "AttachmentError", <| "Notice" -> "data.csv is too large to attach." |> ]
            ];
            {
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "Preparing", "Attachments", "Notice", "CurrentTurn" } ],
                Lookup[ $feFlags, { { $testNB, "Input" }, { $testNB, "Attachments" }, { $testNB, "Busy" }, { $testNB, "PreparingPrompt" } } ],
                calledQ /@ { "WriteUserCell", "SendPrompt" }
            },
            <|
                "Windows" -> <| $testNB -> preparingWindow[ "t1", "Review this" ] |>,
                "FE"      -> <| { $testNB, "Input" } -> "typed since", { $testNB, "Busy" } -> True |>
            |>
        ],
        withACPMocks[
            {
                Wolfram`Chatbook`ACP`Common`acpPreparedPrompt[ $testNB, "t-old", <| "Attachments" -> $preparedAttachments |> ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Preparing" ][ "Token" ],
                $callLog
            },
            <| "Windows" -> <| $testNB -> preparingWindow[ "t2", "Review this" ] |> |>
        ]
    },
    {
        {
            { None, { $nbRef, $fileRef }, "data.csv is too large to attach.", None },
            { "Review this\n\ntyped since", { $nbRef, $fileRef }, False, None },
            { False, False }
        },
        { Null, "t2", { } }
    },
    SameTest -> MatchQ,
    TestID   -> "Attachments-PreparedFailure@@Tests/ACPWindow.wlt:1209,1-1246,2"
]

(* Stop (no turn runs), New and housekeeping's timeout cancel a preparation: the message goes back to the input field *)
VerificationTest[
    {
        withACPMocks[
            Wolfram`Chatbook`Common`acpAction[ "Stop", $testNB ];
            {
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "Preparing", "Attachments" } ],
                Lookup[ $feFlags, { { $testNB, "Input" }, { $testNB, "Busy" } } ],
                calledQ[ "Stop" ]
            },
            <| "Windows" -> <| $testNB -> preparingWindow[ "t1", "Review this" ] |>, "FE" -> <| { $testNB, "Busy" } -> True |> |>
        ],
        withACPMocks[
            Block[ { CurrentValue, Wolfram`Chatbook`ChatModes`Common`moveChatInputToTop = Null & },
                Wolfram`Chatbook`Common`acpAction[ "NewChat", $testNB ];
                { Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "Preparing", "Attachments" } ], $feFlags[ { $testNB, "Input" } ] }
            ],
            <| "Windows" -> <| $testNB -> preparingWindow[ "t1", "Review this" ] |> |>
        ],
        withACPMocks[
            Wolfram`Chatbook`ACP`UI`Private`acpUIHousekeeping[ ];
            {
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "Preparing", "Attachments", "Notice" } ],
                $feFlags[ { $testNB, "Input" } ]
            },
            <| "Windows" -> <| $testNB -> preparingWindow[ "t1", "Review this", "Preparing" -> <| "Token" -> "t1", "StartedAt" -> AbsoluteTime[ ] - 1000, "Input" -> "Review this", "Text" -> "Review this", "Attachments" -> { $nbRef } |> ] |> |>
        ]
    },
    {
        { { None, { $nbRef, $fileRef } }, { "Review this", False }, False },
        { { None, { $nbRef, $fileRef } }, "Review this" },
        { { None, { $nbRef }, "Preparing the attachments took too long, so the message was not sent." }, "Review this" }
    },
    SameTest -> MatchQ,
    TestID   -> "Attachments-Cancel@@Tests/ACPWindow.wlt:1249,1-1283,2"
]

(* A turn that ends while the attachments of a message are prepared leaves the window busy: Stop, which cancels the
   preparation and gives the message back, stays *)
VerificationTest[
    Function[ preparing,
        withACPMocks[
            Wolfram`Chatbook`ACP`UI`Private`acpFinishTurnState[ "turn-1", $testNB ];
            { $feFlags[ { $testNB, "Busy" } ], Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "CurrentTurn" ] },
            <|
                "Windows" -> <| $testNB -> If[ preparing,
                    preparingWindow[ "t1", "Review this", "Status" -> "Running", "CurrentTurn" -> "turn-1" ],
                    testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ]
                ] |>,
                "Turns"   -> <| "turn-1" -> <| "ID" -> "turn-1", "Notebook" -> $testNB, "Status" -> "Running" |> |>,
                "FE"      -> <| { $testNB, "Busy" } -> True |>
            |>
        ]
    ] /@ { True, False },
    { { True, None }, { False, None } },
    SameTest -> MatchQ,
    TestID   -> "Attachments-StopWhilePreparing@@Tests/ACPWindow.wlt:1287,1-1305,2"
]

(* Cancelling a queued message gives its text and attachments back; a queued message with attachments is sent with them
   after the turn (its user cell has the chips) *)
VerificationTest[
    {
        withACPMocks[
            Wolfram`Chatbook`Common`acpAction[ "CancelQueuedPrompt", $testNB ];
            {
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "QueuedPrompt", "Attachments" } ],
                Lookup[ $feFlags, { { $testNB, "Input" }, { $testNB, "QueuedPrompt" } } ]
            },
            <|
                "Windows" -> <| $testNB -> testWindow[ $testNB, "QueuedPrompt" -> <| "Text" -> "Later", "Attachments" -> $preparedAttachments |> ] |>,
                "FE"      -> <| { $testNB, "Input" } -> "now" |>
            |>
        ],
        withACPMocks[
            withCellMocks[
                Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
                {
                    Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "QueuedPrompt", "Status" } ],
                    Wolfram`Chatbook`ACP`Common`acpTurnGet[ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "CurrentTurn" ], "Attachments" ] === $preparedAttachments,
                    calls[ "NotebookWrite" ][[ 2 ]],
                    $feFlags[ { $testNB, "QueuedPrompt" } ]
                }
            ],
            <|
                "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1", "QueuedPrompt" -> <| "Text" -> "Next", "Attachments" -> $preparedAttachments |> ] |>,
                "Turns"   -> <| "turn-1" -> <|
                    "ID"         -> "turn-1",
                    "Notebook"   -> $testNB,
                    "OutputCell" -> $outCell,
                    "Status"     -> "Running",
                    "StopReason" -> "end_turn",
                    "EndTime"    -> AbsoluteTime[ ] - 5,
                    "Entities"   -> <| |>
                |> |>
            |>
        ]
    },
    {
        { { None, { $nbRef, $fileRef } }, { "Later\n\nnow", None } },
        {
            { None, "Running" },
            True,
            {
                System`NotebookLocationSpecifier[ $outCell, "After" ],
                Cell[ BoxData[ TemplateBox[ { Cell[ TextData[ { "Next", "\n", $attachmentsChipsCell } ], ___ ] }, "UserMessageBox" ] ], "ChatInput", CellTags -> _String ],
                None,
                AutoScroll -> False
            },
            None
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Attachments-QueuedPrompt@@Tests/ACPWindow.wlt:1309,1-1362,2"
]

(* The draft: references only (no duplicates, nothing else), in the window record and the TaggingRules; the actions of
   the chips and of the menu's file dialog *)
VerificationTest[
    Module[ { file = CreateFile[ ], dir = CreateDirectory[ ], result },
        result = withACPMocks[
            {
                Wolfram`Chatbook`ACP`Common`acpSetDraftAttachments[ $testNB, { $nbRef, $fileRef, $nbRef, <| "Kind" -> "Other" |>, "x" } ],
                $feFlags[ { $testNB, "Attachments" } ],
                Wolfram`Chatbook`Common`acpAction[ "RemoveAttachment", $testNB, "nb-1" ];
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Attachments" ],
                Wolfram`Chatbook`Common`acpAction[ "AttachFiles", $testNB, { file, dir, "/does/not/exist" } ];
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Attachments" ],
                Wolfram`Chatbook`Common`acpAction[ "AttachFiles", $testNB, file ];
                Length @ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Attachments" ]
            },
            <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
        ];
        DeleteFile @ file;
        DeleteDirectory @ dir;
        { result, file }
    ],
    {
        {
            { $nbRef, $fileRef },
            { $nbRef, $fileRef },
            { $fileRef },
            { $fileRef, KeyValuePattern @ { "Kind" -> "File", "Key" -> _String, "Path" -> f_String, "Name" -> _String, "Size" -> 0 } },
            2
        },
        f_String
    },
    SameTest -> MatchQ,
    TestID   -> "Attachments-Draft@@Tests/ACPWindow.wlt:1366,1-1397,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Prompt Notebook*)

(* The prompt notebook (PromptNotebook.wl): its TaggingRules ({"ACPPrompt", key}) are mocked like the window's flags *)
VerificationTest[
    $promptNB  = NotebookObject[ "acp-test-prompt-notebook" ];
    $promptRef = <| "Kind" -> "Notebook", "Key" -> "nb-p", "Notebook" -> $promptNB, "Name" -> "Untitled-3", "Cells" -> 2, "Prompt" -> True |>;
    $promptPrepared = {
        <| "Kind" -> "Notebook", "Name" -> "Untitled-3", "Path" -> None, "Ref" -> $promptRef, "Text" -> "# Spec\n\nDo it.", "Images" -> { }, "Cells" -> 2 |>
    };
    $promptSSH = <| "MachineName" -> "devbox", "Username" -> "u", "Arguments" -> { }, "Executable" -> Automatic |>;
    $promptTR  = <| |>;
    promptTRGet // ClearAll;
    promptTRGet[ nbo_, key_String, default_ ] := Lookup[ $promptTR, Key @ { nbo, key }, default ];
    promptTRSet // ClearAll;
    promptTRSet[ nbo_, key_String, value_ ] := ($promptTR[ { nbo, key } ] = value);
    promptStatus // ClearAll;
    promptStatus[ nbo_ ] := Lookup[ $promptTR, { Key @ { nbo, "State" }, Key @ { nbo, "StatusText" } }, None ];
    (* withACPMocks, and: init "Prompt" (the prompt notebooks' TaggingRules), "Jobs", "PromptNotebooks" (the open ones),
       "Open" (the open ACP windows, acpWindowQ; default $testNB) and "Current" (findCurrentWorkspaceChat["ACP"]) *)
    withPromptMocks // ClearAll;
    withPromptMocks // Attributes = { HoldFirst };
    withPromptMocks[ eval_, init_Association ] := withACPMocks[
        Block[
            {
                Wolfram`Chatbook`ACP`PromptNotebook`Private`promptGet      = promptTRGet,
                Wolfram`Chatbook`ACP`PromptNotebook`Private`promptSet      = promptTRSet,
                Wolfram`Chatbook`ACP`PromptNotebook`Private`$promptJobs    = Lookup[ init, "Jobs", <| |> ],
                Wolfram`Chatbook`ACP`PromptNotebook`Private`$promptTargets = <| |>,
                Wolfram`Chatbook`ACP`Common`acpPromptNotebooks             = Lookup[ init, "PromptNotebooks", { } ] &,
                Wolfram`Chatbook`Common`acpWindowQ                         = MemberQ[ Lookup[ init, "Open", { $testNB } ], # ] &,
                Wolfram`Chatbook`ChatModes`Common`findCurrentWorkspaceChat = Lookup[ init, "Current", Missing[ "NotFound" ] ] &,
                $promptTR = Lookup[ init, "Prompt", <| |> ]
            },
            eval
        ],
        init
    ];
    (* the target that the docked cell shows for the test window (a job remembers it) *)
    $promptTarget := Wolfram`Chatbook`ACP`Common`acpPromptTargetLabel @ testWindow @ $testNB;
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-Definitions@@Tests/ACPWindow.wlt:1404,1-1444,2"
]

(* The notebook (pure): the cells, a regular notebook (new cells "Text", the default stylesheet) with the ACP window's
   kernel, its owner and status in its TaggingRules, never a source notebook; the docked cell is self-contained (only
   System`, FrontEnd` and FEPrivate` symbols: built-in boxes, front-end-only Dynamics of the notebook's and its owner's
   TaggingRules), and its buttons are registered actions whose notebook is the EvaluationNotebook[ ] of the click *)
VerificationTest[
    Module[ { nb, opts, docked, actions },
        nb      = Block[ { Wolfram`Chatbook`ACP`Common`acpLabel = mockLabel }, Wolfram`Chatbook`ACP`Common`acpPromptNotebook[ $testNB, { Cell[ "Spec", "Text" ] }, <| "WindowMargins" -> { { 482, Automatic }, { Automatic, 0 } }, "WindowSize" -> { 720, 900 } |> ] ];
        opts    = Association @ Cases[ List @@ Rest @ nb, _Rule ];
        docked  = opts[ DockedCells ];
        actions = Cases[ docked, HoldPattern[ _[ "ACP", name_String, EvaluationNotebook[ ] ] ] :> name, Infinity ];
        {
            First @ nb,
            Lookup[ opts, { TaggingRules, Evaluator, StyleDefinitions, DefaultNewCellStyle, WindowSize, WindowMargins } ],
            Sort @ actions,
            SubsetQ[ Wolfram`Chatbook`ACP`UI`Private`$acpActionNames, actions ],
            Complement[
                Union @ Cases[ docked, s_Symbol /; AtomQ @ Unevaluated @ s :> Context @ Unevaluated @ s, { 0, Infinity }, Heads -> True ],
                { "System`", "FrontEnd`", "FEPrivate`" }
            ],
            ! FreeQ[ docked, HoldPattern @ CurrentValue[ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACPPrompt", "Owner" } ], { TaggingRules, "ACP", "PromptTarget" } ] ],
            ! FreeQ[ docked, HoldPattern @ CurrentValue[ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACPPrompt", "Owner" } ], { TaggingRules, "ACP", "Busy" } ] ],
            ! FreeQ[ docked, HoldPattern @ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACPPrompt", "StatusText" } ] ],
            Cases[ docked, (BoxID -> id_String) :> id, Infinity ]
        }
    ],
    {
        { Cell[ "Spec", "Text" ] },
        {
            <|
                "ACPPrompt"            -> <| "Owner" -> $testNB, "State" -> None, "StatusText" -> _String |>,
                "ChatNotebookSettings" -> <| "ACPPromptNotebook" -> True, "ExcludeFromChat" -> True |>
            |>,
            "Local",
            "Default.nb",
            "Text",
            { 720, 900 },
            { { 482, Automatic }, { Automatic, 0 } }
        },
        { "PromptNotebookCancel", "PromptNotebookOpenWindow", "PromptNotebookSend" },
        True,
        { },
        True,
        True,
        True,
        { OrderlessPatternSequence[ "ACPPromptNotebookSend", "ACPPromptNotebookOpenWindow", "ACPPromptNotebookCancel" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-Notebook@@Tests/ACPWindow.wlt:1450,1-1494,2"
]

(* The input field's text as the notebook's cells: paragraphs as "Text" cells, typed boxes as one "Text" cell like the
   user cell's; placement beside the ACP window (pure) *)
VerificationTest[
    {
        Wolfram`Chatbook`ACP`Common`acpPromptNotebookCells[ "First line\nsecond line\n\n \n\nSecond\r\n\r\nThird\n" ],
        Wolfram`Chatbook`ACP`Common`acpPromptNotebookCells[ RowBox @ { "See ", GraphicsBox[ { Disk[ ] } ] } ],
        Wolfram`Chatbook`ACP`Common`acpPromptNotebookCells[ "  " ],
        Wolfram`Chatbook`ACP`Common`acpPromptNotebookCells[ "" ],
        Wolfram`Chatbook`ACP`Common`acpPromptNotebookPlacement[ <| "Left" -> 0, "Width" -> 480, "Bottom" -> 0, "Top" -> 20, "Height" -> 900, "Frame" -> 2 |>, { 0, 1920 }, 720 ],
        Wolfram`Chatbook`ACP`Common`acpPromptNotebookPlacement[ <| "Left" -> 0, "Width" -> 480, "Bottom" -> 0, "Top" -> 20, "Height" -> 900, "Frame" -> 2 |>, { 0, 1000 }, 720 ],
        Wolfram`Chatbook`ACP`Common`acpPromptNotebookPlacement[ <| "Left" -> 600, "Width" -> 480, "Bottom" -> 0, "Top" -> 20, "Height" -> 900, "Frame" -> 2 |>, { 0, 1200 }, 720 ],
        Wolfram`Chatbook`ACP`Common`acpPromptNotebookPlacement[ <| "Left" -> 0, "Width" -> 480, "Bottom" -> 0, "Top" -> 20, "Height" -> 900, "Frame" -> 2 |>, { 0, 700 }, 720 ],
        Wolfram`Chatbook`ACP`Common`acpPromptNotebookPlacement[ <| "Left" -> 0, "Width" -> 480, "Bottom" -> 5, "Top" -> 20, "Height" -> None, "Frame" -> 0 |>, { 0, 1920 }, 720 ]
    },
    {
        { Cell[ "First line\nsecond line", "Text" ], Cell[ "Second", "Text" ], Cell[ "Third", "Text" ] },
        { Cell[ TextData @ { "See ", Cell @ BoxData @ GraphicsBox[ { Disk[ ] } ] }, "Text" ] },
        { },
        { },
        <| "Placement" -> "Right", "WindowMargins" -> { { 482, Automatic }, { Automatic, 20 } }, "WindowSize" -> { 720, 900 } |>,
        <| "Placement" -> "Right", "WindowMargins" -> { { 482, Automatic }, { Automatic, 20 } }, "WindowSize" -> { 516, 900 } |>,
        <| "Placement" -> "Left", "WindowMargins" -> { { 0, Automatic }, { Automatic, 20 } }, "WindowSize" -> { 598, 900 } |>,
        <| "Placement" -> "Default", "WindowMargins" -> Automatic, "WindowSize" -> { 720, 900 } |>,
        <| "Placement" -> "Right", "WindowMargins" -> { { 480, Automatic }, { 5, 20 } }, "WindowSize" -> { 720, Automatic } |>
    },
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-CellsAndPlacement@@Tests/ACPWindow.wlt:1498,1-1523,2"
]

(* The target that the docked cell shows (display-safe, the folder's end kept): local, no folder, remote; the window keeps
   it in its TaggingRules ({"ACP", "PromptTarget"}) when its title is updated, written only when it changed *)
VerificationTest[
    withPromptMocks[
        Module[ { home, labels, first },
            home   = FileNameJoin @ { $HomeDirectory, "projects", "app" };
            labels = Wolfram`Chatbook`ACP`Common`acpPromptTargetLabel /@ {
                testWindow[ $testNB, "ProjectDirectory" -> home ],
                testWindow[ $testNB, "ProjectDirectory" -> None ],
                testWindow[ $testNB, "ProjectDirectory" -> "/home/u/projects/app", "Settings" -> <| "SSHSettings" -> $promptSSH |>, "RemoteHome" -> "/home/u" ],
                testWindow[ $testNB, "ProjectDirectory" -> "/tmp/a\:202eb" ],
                testWindow[ $testNB, "ProjectDirectory" -> "/tmp/" <> StringRepeat[ "x", 100 ] ]
            };
            Wolfram`Chatbook`ACP`Common`acpUpdateWindowTitle @ $testNB;
            first = $feFlags[ { $testNB, "PromptTarget" } ];
            $feFlags[ { $testNB, "PromptTarget" } ] = "unchanged";
            Wolfram`Chatbook`ACP`Common`acpUpdateWindowTitle @ $testNB;
            {
                labels[[ 1 ]] === "OpenCode \[CenterDot] " <> Wolfram`Chatbook`ACP`Common`acpAbbreviatePath[ home, 60 ],
                labels[[ 2 ;; 4 ]],
                StringLength @ labels[[ 5 ]] <= 72 && StringEndsQ[ labels[[ 5 ]], "xxxx" ],
                first,
                $feFlags[ { $testNB, "PromptTarget" } ]
            }
        ],
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "ProjectDirectory" -> "/tmp/proj" ] |> |>
    ],
    {
        True,
        {
            "OpenCode \[CenterDot] no project folder",
            "OpenCode \[CenterDot] devbox:~/projects/app",
            "OpenCode \[CenterDot] /tmp/a\:27e6U+202E\:27e7b"
        },
        True,
        "OpenCode \[CenterDot] /tmp/proj",
        "unchanged"
    },
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-TargetLabel@@Tests/ACPWindow.wlt:1527,1-1565,2"
]

(* The button opens a prompt notebook beside the window with the input field's text, which leaves the input field (the
   draft's attachments stay); with one open, it raises that one and moves nothing *)
VerificationTest[
    {
        withPromptMocks[
            Block[
                {
                    NotebookPut         = (logCall[ "NotebookPut", # ]; $promptNB) &,
                    SetSelectedNotebook = logCall[ "Select", ## ] &,
                    Wolfram`Chatbook`ACP`Common`sessionsMoveToActiveDesktop = Null &
                },
                Module[ { result, nb },
                    result = Wolfram`Chatbook`Common`acpAction[ "OpenPromptNotebook", $testNB ];
                    nb     = calls[ "NotebookPut" ][[ 1, 1 ]];
                    {
                        result,
                        First @ nb,
                        Lookup[ Association @ Cases[ List @@ Rest @ nb, _Rule ], TaggingRules ][ "ACPPrompt", "Owner" ],
                        Lookup[ $feFlags, { { $testNB, "Input" }, { $testNB, "Attachments" } } ],
                        calls[ "Select" ]
                    }
                ]
            ],
            <|
                "Windows" -> <| $testNB -> testWindow[ $testNB, "Attachments" -> { $fileRef } ] |>,
                "FE"      -> <| { $testNB, "Input" } -> "Spec\n\nMore", { $testNB, "Attachments" } -> { $fileRef } |>
            |>
        ],
        withPromptMocks[
            Block[ { NotebookPut = (logCall[ "NotebookPut", # ]; $promptNB) &, SetSelectedNotebook = logCall[ "Select", ## ] & },
                { Wolfram`Chatbook`Common`acpAction[ "OpenPromptNotebook", $testNB ], calledQ[ "NotebookPut" ], calls[ "Select" ], $feFlags[ { $testNB, "Input" } ] }
            ],
            <|
                "Windows"         -> <| $testNB -> testWindow @ $testNB |>,
                "FE"              -> <| { $testNB, "Input" } -> "typed" |>,
                "PromptNotebooks" -> { $promptNB },
                "Prompt"          -> <| { $promptNB, "Owner" } -> $testNB |>
            |>
        ]
    },
    {
        {
            $promptNB,
            { Cell[ "Spec", "Text" ], Cell[ "More", "Text" ] },
            $testNB,
            { "", { $fileRef } },
            { { $promptNB } }
        },
        { $promptNB, False, { { $promptNB } }, "typed" }
    },
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-Open@@Tests/ACPWindow.wlt:1569,1-1619,2"
]

(* Send (the docked cell's button, with the prompt notebook as its EvaluationNotebook[ ]): a main link job converts the
   notebook (one message at a time); a window without a project folder sends nothing; a notebook whose owner is gone is
   linked to the open ACP window and sends at the next click; without an ACP window nothing is sent *)
VerificationTest[
    {
        withPromptMocks[
            Module[ { token },
                token = Wolfram`Chatbook`Common`acpAction[ "PromptNotebookSend", $promptNB ];
                Wolfram`Chatbook`Common`acpAction[ "PromptNotebookSend", $promptNB ];
                {
                    StringQ @ token,
                    With[ { t = token, p = $promptNB, o = $testNB }, calls[ "MainLinkRun" ] === { { o, HoldForm @ Wolfram`Chatbook`ACP`PromptNotebook`Private`acpPromptNotebookJob[ p, o, t ], "PromptNotebook" } } ],
                    promptStatus @ $promptNB,
                    Keys @ Wolfram`Chatbook`ACP`PromptNotebook`Private`$promptJobs,
                    Lookup[ Values @ Wolfram`Chatbook`ACP`PromptNotebook`Private`$promptJobs, "Target" ] === { $promptTarget },
                    Lookup[ $feFlags, { { $testNB, "Input" }, { $testNB, "Busy" } }, Missing[ ] ]
                }
            ],
            <| "Windows" -> <| $testNB -> testWindow @ $testNB |>, "FE" -> <| { $testNB, "Input" } -> "typed" |>, "Prompt" -> <| { $promptNB, "Owner" } -> $testNB |> |>
        ],
        withPromptMocks[
            Wolfram`Chatbook`Common`acpAction[ "PromptNotebookSend", $promptNB ];
            { promptStatus @ $promptNB, calledQ[ "MainLinkRun" ] },
            <| "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "NoDirectory" ] |>, "Prompt" -> <| { $promptNB, "Owner" } -> $testNB |> |>
        ],
        withPromptMocks[
            Wolfram`Chatbook`Common`acpAction[ "PromptNotebookSend", $promptNB ];
            { $promptTR[ { $promptNB, "Owner" } ], promptStatus @ $promptNB, calledQ[ "MainLinkRun" ] },
            <|
                "Windows" -> <| $testNB -> testWindow[ $testNB, "ProjectDirectory" -> "/tmp/proj" ] |>,
                "Prompt"  -> <| { $promptNB, "Owner" } -> $testNB2 |>,
                "Current" -> $testNB
            |>
        ],
        withPromptMocks[
            Wolfram`Chatbook`Common`acpAction[ "PromptNotebookSend", $promptNB ];
            { $promptTR[ { $promptNB, "Owner" } ], promptStatus @ $promptNB, calledQ[ "MainLinkRun" ] },
            <| "Prompt" -> <| { $promptNB, "Owner" } -> $testNB2 |>, "Open" -> { } |>
        ]
    },
    {
        { True, True, { "Preparing", "Preparing the message\[Ellipsis]" }, { $promptNB }, True, { "typed", Missing[ ] } },
        { { "NotSent", "Not sent. Choose a project folder first." }, False },
        { $testNB, { "Retargeted", "This notebook now goes to OpenCode \[CenterDot] /tmp/proj. Click Send again to send it there." }, False },
        { $testNB2, { "NotSent", "Not sent. No agent window is open." }, False }
    },
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-Send@@Tests/ACPWindow.wlt:1624,1-1669,2"
]

(* The job's result (in the pump): the message starts its turn (the user cell with the notebook's chip is an addressed
   write after the last cell; the input field, where the next message may be typed, is not touched), or is queued while a
   turn runs; a result of a cancelled job is ignored; an empty notebook, a failure and a closed window send nothing *)
VerificationTest[
    {
        withPromptMocks[
            withCellMocks @ Module[ { result, window },
                result = Wolfram`Chatbook`ACP`PromptNotebook`Private`acpPromptNotebookPrepared[ $promptNB, $testNB, "t1", <| "Attachments" -> $promptPrepared |> ];
                window = Wolfram`Chatbook`ACP`Common`acpWindowGet @ $testNB;
                {
                    result,
                    Lookup[ Wolfram`Chatbook`ACP`Common`acpTurnGet @ window[ "CurrentTurn" ], { "Prompt", "Attachments" } ] === { "", $promptPrepared },
                    calls[ "SendPrompt" ] === { { $testNB, window[ "CurrentTurn" ] } },
                    First @ calls[ "NotebookWrite" ],
                    calledQ[ "WriteUserCell" ],
                    Lookup[ $feFlags, { { $testNB, "Input" }, { $testNB, "Busy" } } ],
                    promptStatus @ $promptNB,
                    Wolfram`Chatbook`ACP`PromptNotebook`Private`$promptJobs
                }
            ],
            <|
                "Windows" -> <| $testNB -> testWindow @ $testNB |>,
                "FE"      -> <| { $testNB, "Input" } -> "typing" |>,
                "Jobs"    -> <| $promptNB -> <| "Token" -> "t1", "Owner" -> $testNB, "Target" -> $promptTarget |> |>
            |>
        ],
        withPromptMocks[
            {
                Wolfram`Chatbook`ACP`PromptNotebook`Private`acpPromptNotebookPrepared[ $promptNB, $testNB, "t1", <| "Attachments" -> $promptPrepared |> ],
                Wolfram`Chatbook`ACP`Common`acpQueuedPromptOf @ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedPrompt" ],
                Lookup[ $feFlags, { { $testNB, "QueuedPrompt" }, { $testNB, "Input" } } ],
                promptStatus @ $promptNB,
                calledQ /@ { "WriteUserCell", "NotebookWrite", "SendPrompt" }
            },
            <|
                "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-0" ] |>,
                "FE"      -> <| { $testNB, "Input" } -> "typing" |>,
                "Jobs"    -> <| $promptNB -> <| "Token" -> "t1", "Owner" -> $testNB, "Target" -> $promptTarget |> |>
            |>
        ],
        withPromptMocks[
            {
                Wolfram`Chatbook`ACP`PromptNotebook`Private`acpPromptNotebookPrepared[ $promptNB, $testNB, "t1", <| "Attachments" -> $promptPrepared |> ],
                $promptTR,
                $callLog
            },
            <| "Windows" -> <| $testNB -> testWindow @ $testNB |>, "Jobs" -> <| $promptNB -> <| "Token" -> "t2", "Owner" -> $testNB, "Target" -> $promptTarget |> |> |>
        ],
        Function[ { result, open },
            withPromptMocks[
                Wolfram`Chatbook`ACP`PromptNotebook`Private`acpPromptNotebookPrepared[ $promptNB, $testNB, "t1", result ];
                { promptStatus @ $promptNB, calledQ[ "SendPrompt" ] },
                <| "Windows" -> <| $testNB -> testWindow @ $testNB |>, "Jobs" -> <| $promptNB -> <| "Token" -> "t1", "Owner" -> $testNB, "Target" -> $promptTarget |> |>, "Open" -> open |>
            ]
        ] @@@ {
            { <| "Attachments" -> { <| First @ $promptPrepared, "Text" -> " \n " |> } |>, { $testNB } },
            { Failure[ "AttachmentError", <| "Notice" -> "The attachments are too large to send in one message (9 MB; at most 8 MB)." |> ], { $testNB } },
            { <| "Attachments" -> $promptPrepared |>, { } }
        }
    },
    {
        {
            "Sent",
            True,
            True,
            {
                System`NotebookLocationSpecifier[ $userCell, "After" ],
                Cell[ BoxData[ TemplateBox[ { Cell[ TextData[ { Cell[ BoxData[ TagBox[ _, "ACPAttachments", ___ ] ], "Text", ___ ] } ], ___ ] }, "UserMessageBox" ] ], "ChatInput", CellTags -> _String ],
                None,
                AutoScroll -> False
            },
            False,
            { "typing", True },
            { "Sent", _String? (StringMatchQ[ "Sent at " ~~ DigitCharacter.. ~~ ":" ~~ DigitCharacter.. ~~ "." ]) },
            <| |>
        },
        {
            "Queued",
            <| "Text" -> "", "Attachments" -> $promptPrepared |>,
            { <| "Text" -> "", "Attachments" -> { $promptRef } |>, "typing" },
            { "Queued", "Queued: sent when OpenCode is done." },
            { False, False, False }
        },
        { Null, <| |>, { } },
        {
            { { "NotSent", "Not sent. The notebook is empty." }, False },
            { { "NotSent", "Not sent. The attachments are too large to send in one message (9 MB; at most 8 MB)." }, False },
            { { "NotSent", "Not sent. No agent window is open." }, False }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-Prepared@@Tests/ACPWindow.wlt:1674,1-1763,2"
]

(* A prompt notebook's message that is dropped stays in its notebook (never in the draft), whose status says why:
   the queued message was removed (Cancel), a new chat (New), the kernel was restarted (rebuilt record, no notice without anything
   given back; the window's recovery for a message that was prepared), the window was closed; Cancel of a preparation *)
VerificationTest[
    {
        withPromptMocks[
            Wolfram`Chatbook`Common`acpAction[ "CancelQueuedPrompt", $testNB ];
            {
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "QueuedPrompt", "Attachments" } ],
                $feFlags[ { $testNB, "Input" } ],
                promptStatus @ $promptNB
            },
            <| "Windows" -> <| $testNB -> testWindow[ $testNB, "QueuedPrompt" -> <| "Text" -> "also this", "Attachments" -> $promptPrepared |> ] |> |>
        ],
        withPromptMocks[
            Block[ { CurrentValue, Wolfram`Chatbook`ChatModes`Common`moveChatInputToTop = Null & },
                Wolfram`Chatbook`Common`acpAction[ "NewChat", $testNB ];
                { Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedPrompt" ], promptStatus @ $promptNB }
            ],
            <| "Windows" -> <| $testNB -> testWindow[ $testNB, "QueuedPrompt" -> <| "Text" -> "", "Attachments" -> $promptPrepared |> ] |> |>
        ],
        withPromptMocks[
            {
                Lookup[ Wolfram`Chatbook`ACP`Common`acpEnsureWindowRecord @ $testNB, { "Attachments", "Notice" } ],
                Lookup[ $feFlags, { { $testNB, "Input" }, { $testNB, "QueuedPrompt" } } ],
                promptStatus @ $promptNB
            },
            <| "FE" -> <|
                { $testNB, "ProjectDirectory" } -> $TemporaryDirectory,
                { $testNB, "QueuedPrompt" }     -> <| "Text" -> "", "Attachments" -> { $promptRef } |>
            |> |>
        ],
        withPromptMocks[
            Wolfram`Chatbook`ACP`Common`acpPromptNotebookRecover @ $testNB;
            { promptStatus @ $promptNB, promptStatus @ $testNB2 },
            <|
                "Windows"         -> <| $testNB -> testWindow @ $testNB |>,
                "PromptNotebooks" -> { $promptNB, $testNB2 },
                "Jobs"            -> <| $testNB2 -> <| "Token" -> "t2", "Owner" -> $testNB |> |>,
                "Prompt"          -> <|
                    { $promptNB, "Owner" } -> $testNB, { $promptNB, "State" } -> "Preparing", { $promptNB, "StatusText" } -> "Preparing",
                    { $testNB2, "Owner" } -> $testNB, { $testNB2, "State" } -> "Preparing", { $testNB2, "StatusText" } -> "Preparing"
                |>
            |>
        ],
        withPromptMocks[
            Wolfram`Chatbook`ACP`Common`acpPromptNotebooksOwnerClosed @ $testNB;
            { promptStatus @ $promptNB, Wolfram`Chatbook`ACP`PromptNotebook`Private`$promptJobs },
            <|
                "PromptNotebooks" -> { $promptNB },
                "Jobs"            -> <| $promptNB -> <| "Token" -> "t1", "Owner" -> $testNB |> |>,
                "Prompt"          -> <| { $promptNB, "Owner" } -> $testNB, { $promptNB, "State" } -> "Queued" |>
            |>
        ],
        withPromptMocks[
            Wolfram`Chatbook`Common`acpAction[ "PromptNotebookCancel", $promptNB ];
            { promptStatus @ $promptNB, Wolfram`Chatbook`ACP`PromptNotebook`Private`$promptJobs },
            <| "Jobs" -> <| $promptNB -> <| "Token" -> "t1", "Owner" -> $testNB |> |> |>
        ]
    },
    {
        { { None, { } }, "also this", { "NotSent", "Not sent. The queued message was removed." } },
        { None, { "NotSent", "Not sent. The agent window switched to another chat." } },
        { { { }, None }, { _Missing, None }, { "NotSent", "Not sent. The kernel was restarted." } },
        { { "NotSent", "Not sent. The kernel was restarted." }, { "Preparing", "Preparing" } },
        { { "NotSent", "Not sent. The agent window was closed." }, <| |> },
        { { "NotSent", "Not sent." }, <| |> }
    },
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-NotSent@@Tests/ACPWindow.wlt:1768,1-1835,2"
]

(* Closing the owner unlinks all of its prompt notebooks, an idle one too ("Owner" None), so that their docked cells (whose
   front-end-only Dynamics read the owner's TaggingRules, which nothing updates when the owner closes) say at once that
   they are not linked and drop the owner's busy note; a notebook of another window stays linked. Send then links an
   unlinked notebook to the open window and asks for another click. *)
VerificationTest[
    Module[ { other = NotebookObject[ "acp-test-other-window" ], closed, retargeted },
        closed = withPromptMocks[
            Wolfram`Chatbook`ACP`Common`acpPromptNotebooksOwnerClosed @ $testNB;
            {
                promptTRGet[ $promptNB, "Owner", "unset" ],
                promptStatus @ $promptNB,
                promptTRGet[ $testNB2, "Owner", "unset" ],
                promptStatus @ $testNB2
            },
            <|
                "PromptNotebooks" -> { $promptNB, $testNB2 },
                "Prompt"          -> <| { $promptNB, "Owner" } -> $testNB, { $testNB2, "Owner" } -> other, { $testNB2, "State" } -> "Queued" |>
            |>
        ];
        retargeted = withPromptMocks[
            Wolfram`Chatbook`Common`acpAction[ "PromptNotebookSend", $promptNB ];
            { promptTRGet[ $promptNB, "Owner", "unset" ], First @ promptStatus @ $promptNB },
            <|
                "Windows" -> <| $testNB -> testWindow @ $testNB |>,
                "Prompt"  -> <| { $promptNB, "Owner" } -> None |>,
                "Current" -> $testNB
            |>
        ];
        { closed, retargeted }
    ],
    {
        { None, { None, None }, NotebookObject[ "acp-test-other-window" ], { "Queued", None } },
        { $testNB, "Retargeted" }
    },
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-OwnerClosedUnlinks@@Tests/ACPWindow.wlt:1841,1-1873,2"
]

(* "Open agent window", the button of a notebook that is not linked (e.g. a saved one opened when no kernel runs), is a
   queued button: a preemptive click then only started the kernel. Send and Cancel stay preemptive. *)
VerificationTest[
    Module[ { docked, methods },
        docked  = Association[ Cases[ List @@ Rest @ Block[ { Wolfram`Chatbook`ACP`Common`acpLabel = mockLabel }, Wolfram`Chatbook`ACP`Common`acpPromptNotebook[ $testNB, { }, <| |> ] ], _Rule ] ][ DockedCells ];
        methods = Cases[
            docked,
            b_ButtonBox :> {
                FirstCase[ b, HoldPattern[ _[ "ACP", name_String, ___ ] ] :> name, None, Infinity ],
                FirstCase[ List @@ b, HoldPattern[ Method -> m_ ] :> m, None ]
            },
            Infinity
        ];
        Sort @ methods
    ],
    {
        { "PromptNotebookCancel", "Preemptive" },
        { "PromptNotebookOpenWindow", "Queued" },
        { "PromptNotebookSend", "Preemptive" }
    },
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-OpenWindowQueued@@Tests/ACPWindow.wlt:1877,1-1897,2"
]

(* A new chat (New, a folder change, a host switch) is not where a prompt notebook's message that is being prepared goes:
   New cancels its job, and the result of a job for a target that is not the window's any more (the job remembers the
   target that the docked cell showed) is not sent. Cancel of a new version while the old one is queued leaves that one
   queued; housekeeping ends a job that takes too long. *)
VerificationTest[
    {
        withPromptMocks[
            Block[ { CurrentValue, Wolfram`Chatbook`ChatModes`Common`moveChatInputToTop = Null & },
                Wolfram`Chatbook`Common`acpAction[ "NewChat", $testNB ];
                { promptStatus @ $promptNB, Wolfram`Chatbook`ACP`PromptNotebook`Private`$promptJobs }
            ],
            <|
                "Windows" -> <| $testNB -> testWindow @ $testNB |>,
                "Jobs"    -> <| $promptNB -> <| "Token" -> "t1", "Owner" -> $testNB, "Target" -> $promptTarget |> |>
            |>
        ],
        withPromptMocks[
            {
                Wolfram`Chatbook`ACP`PromptNotebook`Private`acpPromptNotebookPrepared[ $promptNB, $testNB, "t1", <| "Attachments" -> $promptPrepared |> ],
                promptStatus @ $promptNB,
                calledQ /@ { "SendPrompt", "NotebookWrite" },
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedPrompt" ]
            },
            <|
                "Windows" -> <| $testNB -> testWindow[ $testNB, "ProjectDirectory" -> "/tmp/other" ] |>,
                "Jobs"    -> <| $promptNB -> <| "Token" -> "t1", "Owner" -> $testNB, "Target" -> $promptTarget |> |>
            |>
        ],
        withPromptMocks[
            Wolfram`Chatbook`Common`acpAction[ "PromptNotebookCancel", $promptNB ];
            promptStatus @ $promptNB,
            <|
                "Windows" -> <| $testNB -> testWindow[
                    $testNB,
                    "Status"       -> "Running",
                    "CurrentTurn"  -> "turn-0",
                    "QueuedPrompt" -> <| "Text" -> "", "Attachments" -> $promptPrepared |>
                ] |>,
                "Jobs"    -> <| $promptNB -> <| "Token" -> "t1", "Owner" -> $testNB, "Target" -> $promptTarget |> |>
            |>
        ],
        withPromptMocks[
            Wolfram`Chatbook`ACP`UI`Private`acpUIHousekeeping[ ];
            { promptStatus @ $promptNB, Wolfram`Chatbook`ACP`PromptNotebook`Private`$promptJobs },
            <|
                "Windows" -> <| $testNB -> testWindow @ $testNB |>,
                "Jobs"    -> <| $promptNB -> <| "Token" -> "t1", "Owner" -> $testNB, "Target" -> $promptTarget, "StartedAt" -> AbsoluteTime[ ] - 1000 |> |>
            |>
        ]
    },
    {
        { { "NotSent", "Not sent. The agent window switched to another chat." }, <| |> },
        { Null, { "NotSent", "Not sent. The agent window switched to another chat." }, { False, False }, None },
        { "Queued", "Queued: sent when OpenCode is done." },
        { { "NotSent", "Not sent. Preparing the message took too long." }, <| |> }
    },
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-NewChat@@Tests/ACPWindow.wlt:1903,1-1957,2"
]

(* A folder change (and a host switch) starts a new chat: the queued message and the one whose attachments are being
   prepared go back to the input field (the queued one first, before what was typed since) and their attachments into
   the draft, with a notice; prompt notebooks' messages, queued or being prepared, are not sent and say why *)
VerificationTest[
    withPromptMocks[
        Block[
            {
                Wolfram`Chatbook`ACP`Common`acpSetProjectDirectory = Function[ { nbo, dir },
                    Wolfram`Chatbook`ACP`Common`acpWindowUpdate[ nbo, <| #, "ProjectDirectory" -> dir, "QueuedPrompt" -> None |> & ];
                    dir
                ]
            },
            {
                Wolfram`Chatbook`ACP`Common`acpChangeProjectDirectory[ $testNB, "/tmp/other" ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "QueuedPrompt", "Preparing", "Notice" } ],
                $feFlags[ { $testNB, "Input" } ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Attachments" ],
                promptStatus @ $promptNB,
                promptStatus @ $testNB2,
                Wolfram`Chatbook`ACP`PromptNotebook`Private`$promptJobs
            }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[
                $testNB,
                "QueuedPrompt" -> <| "Text" -> "queued", "Attachments" -> Join[ $preparedAttachments, $promptPrepared ] |>,
                "Preparing"    -> <| "Token" -> "t0", "StartedAt" -> AbsoluteTime[ ], "Input" -> "prepared", "Text" -> "prepared", "Attachments" -> { $fileRef } |>
            ] |>,
            "FE"      -> <| { $testNB, "Input" } -> "typed" |>,
            "Jobs"    -> <| $testNB2 -> <| "Token" -> "t2", "Owner" -> $testNB, "Target" -> $promptTarget |> |>
        |>
    ],
    {
        "/tmp/other",
        { None, None, "The chat changed, so the message that was waiting to be sent is back in the input field." },
        "queued\n\nprepared\n\ntyped",
        { $fileRef, $nbRef },
        { "NotSent", "Not sent. The agent window switched to another chat." },
        { "NotSent", "Not sent. The agent window switched to another chat." },
        <| |>
    },
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-FolderChange@@Tests/ACPWindow.wlt:1962,1-2002,2"
]

(* Send again while a prompt notebook's message is queued queues its new version instead of a second copy; the images
   of the merged messages are numbered again, in order *)
VerificationTest[
    withPromptMocks[
        Module[ { image, withImages, newVersion, queued },
            image      = <| "MimeType" -> "image/png", "Data" -> ByteArray[ { 1, 2, 3 } ] |>;
            withImages = { <| First @ $preparedAttachments, "Text" -> "# Spec\n\n[image 1] [image 2]", "Images" -> { <| image, "Number" -> 1 |>, <| image, "Number" -> 2 |> } |> };
            newVersion = { <| First @ $promptPrepared, "Text" -> "# Spec v2\n\n[image 1]", "Images" -> { <| image, "Number" -> 1 |> } |> };
            Wolfram`Chatbook`ACP`UI`Private`acpQueuePrompt[ $testNB, "typed", withImages ];
            Wolfram`Chatbook`ACP`UI`Private`acpQueuePrompt[ $testNB, "", $promptPrepared ];
            Wolfram`Chatbook`ACP`UI`Private`acpQueuePrompt[ $testNB, "", newVersion ];
            (* the turn that is sent: the merged messages, their images numbered again *)
            queued = First @ Wolfram`Chatbook`ACP`UI`Private`queuedBatch[
                Wolfram`Chatbook`ACP`Common`acpWindowGet @ $testNB,
                Wolfram`Chatbook`ACP`UI`Private`acpQueuedMessages @ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedPrompt" ]
            ];
            {
                queued[ "Text" ],
                queued[[ "Attachments", All, "Text" ]],
                Lookup[ Catenate @ queued[[ "Attachments", All, "Images" ]], "Number" ],
                promptStatus @ $promptNB
            }
        ],
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-0" ] |> |>
    ],
    {
        "typed",
        { "# Spec\n\n[image 1] [image 2]", "# Spec v2\n\n[image 3]" },
        { 1, 2, 3 },
        { "Queued", "Queued: sent when OpenCode is done." }
    },
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-QueuedAgain@@Tests/ACPWindow.wlt:2006,1-2037,2"
]

(* While a prompt notebook's new message is being prepared (Send again while its message was queued), the status of the
   message from before does not replace "Preparing" (and Cancel): the message from before goes out after the turn (case 1;
   if the new one then fails, the status says that the one from before was sent), or its Cancel in the ACP window removes
   it (case 2: the new one is then queued, or not sent with its own reason) *)
VerificationTest[
    Module[ { preparing, job, failure },
        preparing = <| { $promptNB, "State" } -> "Preparing", { $promptNB, "StatusText" } -> "Preparing the message\[Ellipsis]" |>;
        job       = <| $promptNB -> <| "Token" -> "t2", "Owner" -> $testNB, "Target" -> $promptTarget, "StartedAt" -> AbsoluteTime[ ] |> |>;
        failure   = Failure[ "PromptNotebookError", <| "Notice" -> "Broken." |> ];
        {
            withPromptMocks[
                withCellMocks @ Module[ { during },
                    Wolfram`Chatbook`ACP`Common`acpSendQueuedPrompt @ $testNB;
                    during = {
                        promptStatus @ $promptNB,
                        Wolfram`Chatbook`ACP`PromptNotebook`Private`$promptJobs[ $promptNB, "Earlier", "State" ],
                        StringQ @ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "CurrentTurn" ]
                    };
                    Wolfram`Chatbook`ACP`PromptNotebook`Private`acpPromptNotebookPrepared[ $promptNB, $testNB, "t2", failure ];
                    { during, promptStatus @ $promptNB }
                ],
                <|
                    "Windows" -> <| $testNB -> testWindow[ $testNB, "QueuedPrompt" -> <| "Text" -> "", "Attachments" -> $promptPrepared |> ] |>,
                    "Jobs"    -> job,
                    "Prompt"  -> preparing
                |>
            ],
            Function[ result,
                withPromptMocks[
                    Module[ { during },
                        Wolfram`Chatbook`Common`acpAction[ "CancelQueuedPrompt", $testNB ];
                        during = promptStatus @ $promptNB;
                        Wolfram`Chatbook`ACP`PromptNotebook`Private`acpPromptNotebookPrepared[ $promptNB, $testNB, "t2", result ];
                        {
                            during,
                            promptStatus @ $promptNB,
                            Wolfram`Chatbook`ACP`Common`acpQueuedPromptOf @ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedPrompt" ]
                        }
                    ],
                    <|
                        "Windows" -> <| $testNB -> testWindow[
                            $testNB,
                            "Status"       -> "Running",
                            "CurrentTurn"  -> "turn-0",
                            "QueuedPrompt" -> <| "Text" -> "", "Attachments" -> $promptPrepared |>
                        ] |>,
                        "Jobs"    -> job,
                        "Prompt"  -> preparing
                    |>
                ]
            ] /@ { <| "Attachments" -> $promptPrepared |>, failure }
        }
    ],
    {
        {
            { { "Preparing", "Preparing the message\[Ellipsis]" }, "Sent", True },
            { "Sent", _String? (StringMatchQ[ "Sent at " ~~ DigitCharacter.. ~~ ":" ~~ DigitCharacter.. ~~ "." ]) }
        },
        {
            {
                { "Preparing", "Preparing the message\[Ellipsis]" },
                { "Queued", "Queued: sent when OpenCode is done." },
                <| "Text" -> "", "Attachments" -> $promptPrepared |>
            },
            { { "Preparing", "Preparing the message\[Ellipsis]" }, { "NotSent", "Not sent. Broken." }, None }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-StatusWhilePreparing@@Tests/ACPWindow.wlt:2043,1-2108,2"
]

(* The messages of a window go in the order of their Send clicks, also when their preparations finish in the other
   order. Reverse: the input field's message (sent first) is still being prepared when the prompt notebook's (sent
   second) is prepared: that one is queued and waits (also for housekeeping's send of the queue), the input field's
   message starts its turn, and the prompt notebook's follows after it. In order: the prompt notebook's message (sent
   first) starts its turn although the input field's is still being prepared, which is then queued. *)
VerificationTest[
    Module[ { t0 = AbsoluteTime[ ], preparing },
        preparing[ t_ ] := testWindow[
            $testNB,
            "Preparing" -> <| "Token" -> "t1", "StartedAt" -> t, "Input" -> "Review this", "Text" -> "Review this", "Attachments" -> { $nbRef, $fileRef } |>
        ];
        {
            withPromptMocks[
                withCellMocks @ Module[ { promptQueued, waiting, inputTurn, after },
                    Wolfram`Chatbook`ACP`PromptNotebook`Private`acpPromptNotebookPrepared[ $promptNB, $testNB, "p1", <| "Attachments" -> $promptPrepared |> ];
                    promptQueued = {
                        promptStatus[ $promptNB ][[ 1 ]],
                        Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "CurrentTurn" ],
                        calledQ[ "SendPrompt" ]
                    };
                    Wolfram`Chatbook`ACP`Common`acpSendQueuedPrompt @ $testNB;
                    waiting = { Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "CurrentTurn" ], Length @ calls[ "SendPrompt" ] };
                    inputTurn = Wolfram`Chatbook`ACP`Common`acpPreparedPrompt[ $testNB, "t1", <| "Attachments" -> $preparedAttachments |> ];
                    after = {
                        Wolfram`Chatbook`ACP`Common`acpTurnGet[ inputTurn, "Prompt" ],
                        Length @ calls[ "SendPrompt" ],
                        Wolfram`Chatbook`ACP`Common`acpQueuedPromptOf @ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedPrompt" ]
                    };
                    (* the turn ends: the queue is sent *)
                    Wolfram`Chatbook`ACP`Common`acpWindowUpdate[ $testNB, <| #, "Status" -> "Ready", "CurrentTurn" -> None |> & ];
                    Wolfram`Chatbook`ACP`Common`acpSendQueuedPrompt @ $testNB;
                    {
                        promptQueued,
                        waiting,
                        after,
                        Wolfram`Chatbook`ACP`Common`acpTurnGet[ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "CurrentTurn" ], "Attachments" ] === $promptPrepared,
                        Length @ calls[ "SendPrompt" ],
                        promptStatus[ $promptNB ][[ 1 ]]
                    }
                ],
                <|
                    "Windows" -> <| $testNB -> preparing[ t0 - 10 ] |>,
                    "Jobs"    -> <| $promptNB -> <| "Token" -> "p1", "Owner" -> $testNB, "Target" -> $promptTarget, "StartedAt" -> t0 - 5 |> |>
                |>
            ],
            withPromptMocks[
                withCellMocks @ Module[ { promptTurn },
                    Wolfram`Chatbook`ACP`PromptNotebook`Private`acpPromptNotebookPrepared[ $promptNB, $testNB, "p1", <| "Attachments" -> $promptPrepared |> ];
                    promptTurn = Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "CurrentTurn" ];
                    Wolfram`Chatbook`ACP`Common`acpPreparedPrompt[ $testNB, "t1", <| "Attachments" -> $preparedAttachments |> ];
                    {
                        Wolfram`Chatbook`ACP`Common`acpTurnGet[ promptTurn, "Attachments" ] === $promptPrepared,
                        promptStatus[ $promptNB ][[ 1 ]],
                        Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "CurrentTurn" ] === promptTurn,
                        Lookup[ Wolfram`Chatbook`ACP`Common`acpQueuedPromptOf @ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedPrompt" ], "Text" ]
                    }
                ],
                <|
                    "Windows" -> <| $testNB -> preparing[ t0 - 5 ] |>,
                    "Jobs"    -> <| $promptNB -> <| "Token" -> "p1", "Owner" -> $testNB, "Target" -> $promptTarget, "StartedAt" -> t0 - 10 |> |>
                |>
            ]
        }
    ],
    {
        {
            { "Queued", None, False },
            { None, 0 },
            { "Review this", 1, <| "Text" -> "", "Attachments" -> $promptPrepared |> },
            True,
            2,
            "Sent"
        },
        { True, "Sent", True, "Review this" }
    },
    SameTest -> MatchQ,
    TestID   -> "PromptNotebook-ClickOrder@@Tests/ACPWindow.wlt:2115,1-2187,2"
]

(* A message whose preparation ended after the window was closed (its record forgotten) creates no record for it, and
   makes no front end calls (housekeeping would make them for good) *)
VerificationTest[
    withACPMocks[
        Module[ { closed = NotebookObject[ "acp-test-closed-window" ] },
            {
                Wolfram`Chatbook`ACP`Common`acpPreparedPrompt[ closed, "t1", Failure[ "Cancelled", <| |> ] ],
                Wolfram`Chatbook`ACP`Common`acpPreparedPrompt[ closed, "t1", <| "Attachments" -> $preparedAttachments |> ],
                Wolfram`Chatbook`ACP`UI`Private`acpCancelPreparation[ closed, None ],
                Keys @ Wolfram`Chatbook`ACP`Common`$acpWindows,
                $feFlags,
                $callLog
            }
        ],
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    { Null, Null, False, { $testNB }, <| |>, { } },
    SameTest -> MatchQ,
    TestID   -> "Attachments-PreparedClosedWindow@@Tests/ACPWindow.wlt:2191,1-2208,2"
]

(* Queued messages are merged into one turn only as far as they stay within the caps of one message (bytes, images,
   characters of the attachments' text); the others are sent as the next turns, in order (caps made small here) *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`ACP`Common`$acpAttachmentLimits = <|
                "Local"  -> <| "MessageBytes" -> 100, "Characters" -> 1000, "FileBytes" -> 100, "Images" -> 2, "ImageBytes" -> 50 |>,
                "Remote" -> <| "MessageBytes" -> 100, "Characters" -> 1000, "FileBytes" -> 100, "Images" -> 2, "ImageBytes" -> 50 |>
            |>
        },
        Module[ { text, image, withImage, batches },
            text[ i_ ] := { <| "Kind" -> "File", "Name" -> "f" <> ToString @ i, "Path" -> None, "Text" -> StringRepeat[ "x", 40 ], "Images" -> { } |> };
            image      = <| "MimeType" -> "image/png", "Data" -> ByteArray[ { 1, 2, 3 } ], "Number" -> 1 |>;
            withImage[ i_ ] := { <| "Kind" -> "File", "Name" -> "i" <> ToString @ i, "Path" -> None, "Text" -> "[image 1]", "Images" -> { image } |> };
            (* the turns that the queue is sent as *)
            batches[ messages_ ] := withACPMocks[
                withCellMocks @ Module[ { turns = { }, queued },
                    Scan[ Wolfram`Chatbook`ACP`UI`Private`acpQueuePrompt[ $testNB, #[[ 1 ]], #[[ 2 ]] ] &, messages ];
                    queued = $feFlags[ { $testNB, "QueuedPrompt" }, "Text" ];
                    While[ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedPrompt" ] =!= None && Length @ turns < 10,
                        Wolfram`Chatbook`ACP`Common`acpWindowUpdate[ $testNB, <| #, "Status" -> "Ready", "CurrentTurn" -> None |> & ];
                        Wolfram`Chatbook`ACP`Common`acpSendQueuedPrompt @ $testNB;
                        With[ { turn = Wolfram`Chatbook`ACP`Common`acpTurnGet @ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "CurrentTurn" ] },
                            AppendTo[ turns, {
                                turn[ "Prompt" ],
                                #[ "Name" ] & /@ turn[ "Attachments" ],
                                Cases[ turn[ "Attachments" ], KeyValuePattern[ "Number" -> n_ ] :> n, Infinity ],
                                $feFlags[ { $testNB, "QueuedPrompt" } ] /. a_Association :> a[ "Text" ]
                            } ]
                        ]
                    ];
                    { queued, turns }
                ],
                <| "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-0" ] |> |>
            ];
            {
                batches @ Table[ { "m" <> ToString @ i, text @ i }, { i, 4 } ],
                batches @ Table[ { "m" <> ToString @ i, withImage @ i }, { i, 3 } ],
                batches @ { { "small", { } }, { StringRepeat[ "y", 150 ], { } }, { "last", { } } }
            }
        ]
    ],
    {
        {
            "m1\n\nm2\n\nm3\n\nm4",
            {
                { "m1\n\nm2", { "f1", "f2" }, { }, "m3\n\nm4" },
                { "m3\n\nm4", { "f3", "f4" }, { }, None }
            }
        },
        {
            "m1\n\nm2\n\nm3",
            {
                { "m1\n\nm2", { "i1", "i2" }, { 1, 2 }, "m3" },
                { "m3", { "i3" }, { 1 }, None }
            }
        },
        {
            _String,
            {
                { "small", { }, { }, _String },
                { _String? (StringLength[ # ] === 150 &), { }, { }, "last" },
                { "last", { }, { }, None }
            }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "QueuedPrompt-MessageCaps@@Tests/ACPWindow.wlt:2212,1-2278,2"
]

(* Typed text goes behind messages that wait in the queue (the connection was lost after they were queued): it is queued
   too, and the window connects again (the queue is sent when it is ready) *)
VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB;
        {
            Wolfram`Chatbook`ACP`Common`acpQueuedPromptOf @ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedPrompt" ],
            Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "CurrentTurn" ],
            calls[ "EnsureConnected" ],
            calledQ[ "WriteUserCell" ]
        },
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Disconnected", "QueuedPrompt" -> <| "Text" -> "first", "Attachments" -> { } |> ] |>,
            "FE"      -> <| { $testNB, "Input" } -> "second" |>
        |>
    ],
    { <| "Text" -> "first\n\nsecond", "Attachments" -> { } |>, None, { { $testNB } }, False },
    SameTest -> MatchQ,
    TestID   -> "EvaluateACPChat-QueueBehindWaiting@@Tests/ACPWindow.wlt:2282,1-2299,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Finalization*)
VerificationTest[
    $endedTurn = <|
        "ID"         -> "turn-1",
        "Notebook"   -> $testNB,
        "OutputCell" -> $outCell,
        "Status"     -> "Running",
        "StopReason" -> "end_turn",
        "EndTime"    -> AbsoluteTime[ ] - 5,
        "Entities"   -> <| { "Message", "m1" } -> <| "Type" -> "Message", "Text" -> "Done." |> |>
    |>;
    withACPMocks[
        {
            Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ],
            calls[ "NotebookWrite" ],
            Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "Status", "CurrentTurn" } ],
            $feFlags[ { $testNB, "Busy" } ],
            KeyExistsQ[ Wolfram`Chatbook`ACP`Common`$acpTurns, "turn-1" ],
            Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
            Length @ calls[ "NotebookWrite" ]
        },
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |>,
            "Turns"   -> <| "turn-1" -> $endedTurn |>,
            "FE"      -> <| { $testNB, "Busy" } -> True |>
        |>
    ],
    {
        Null,
        { { $outCell, Cell[ "final:turn-1", "ChatOutput" ], None, AutoScroll -> False } },
        { "Ready", None },
        False,
        False,
        1
    },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn@@Tests/ACPWindow.wlt:2304,1-2340,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
        { calledQ[ "NotebookWrite" ], calls[ "Schedule" ], Wolfram`Chatbook`ACP`Common`acpTurnGet[ "turn-1", "FinalizeClaimed" ] },
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |>,
            "Turns"   -> <| "turn-1" -> <| $endedTurn, "EndTime" -> AbsoluteTime[ ] + 0.1 |> |>
        |>
    ],
    { False, { { HoldForm[ _Wolfram`Chatbook`ACP`Common`acpFinalizeTurn ], Quantity[ _, "Milliseconds" ] } }, _Missing },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn-Debounce@@Tests/ACPWindow.wlt:2342,1-2354,2"
]

VerificationTest[
    withACPMocks[
        Block[ { ParentNotebook = $Failed & },
            Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
            {
                calledQ[ "NotebookWrite" ],
                KeyExistsQ[ Wolfram`Chatbook`ACP`Common`$acpTurns, "turn-1" ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "CurrentTurn" ],
                calledQ[ "FreezeLiveView" ]
            }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |>,
            "Turns"   -> <| "turn-1" -> $endedTurn |>
        |>
    ],
    { False, False, None, False },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn-CellGone@@Tests/ACPWindow.wlt:2356,1-2375,2"
]

VerificationTest[
    withExpectedLog @ withACPMocks[
        Block[ { Wolfram`Chatbook`ACP`Common`acpFinalCell = Wolfram`Chatbook`Common`throwInternalFailure[ "test" ] & },
            Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
            calls[ "NotebookWrite" ]
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |>,
            "Turns"   -> <| "turn-1" -> $endedTurn |>
        |>
    ],
    {
        {
            $outCell,
            Cell[
                BoxData @ TemplateBox[ { Cell[ TextData[ { "markdown" } ], ___ ] }, "AssistantMessageBox" ],
                "ChatOutput",
                ___,
                TaggingRules -> KeyValuePattern[ "ChatNotebookSettings" -> <| "ACPWindow" -> True |> ]
            ],
            None,
            AutoScroll -> False
        }
    },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn-Fallback@@Tests/ACPWindow.wlt:2377,1-2403,2"
]

(* The live view is frozen before the final cell replaces it (a cell that is replaced while the front end evaluates one
   of its Dynamics made the front end fail an assertion and crash): finalizing claims the turn and freezes the view, and
   the write waits (scheduled again every 50 ms) until the front end has rendered the frozen view and that has settled;
   then it writes once and finishes the turn. Later calls do nothing. *)
VerificationTest[
    withACPMocks[
        Block[ { Wolfram`Chatbook`ACP`Common`acpFreezeLiveView = logCall[ "FreezeLiveView", ## ] & },
            Module[ { shown, step1, step2, step3 },
                shown = Function[ t, Wolfram`Chatbook`ACP`Common`acpTurnUpdate[ "turn-1", <| #, "FrozenViewShownAt" -> t |> & ] ];
                Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
                step1 = {
                    calls[ "FreezeLiveView" ],
                    calledQ[ "NotebookWrite" ],
                    calls[ "Schedule" ],
                    Wolfram`Chatbook`ACP`Common`acpTurnGet[ "turn-1", { "Status", "FinalizeClaimed" } ],
                    NumberQ @ Wolfram`Chatbook`ACP`Common`acpTurnGet[ "turn-1", "FrozenAt" ],
                    Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Status" ]
                };
                (* the front end has just rendered the frozen view: not settled yet *)
                shown @ AbsoluteTime[ ];
                Wolfram`Chatbook`ACP`UI`Private`acpWriteFinalCell[ "turn-1" ];
                step2 = { calledQ[ "NotebookWrite" ], Length @ calls[ "Schedule" ] };
                shown[ AbsoluteTime[ ] - 1 ];
                Wolfram`Chatbook`ACP`UI`Private`acpWriteFinalCell[ "turn-1" ];
                step3 = {
                    calls[ "NotebookWrite" ],
                    KeyExistsQ[ Wolfram`Chatbook`ACP`Common`$acpTurns, "turn-1" ],
                    Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "Status", "CurrentTurn" } ]
                };
                Wolfram`Chatbook`ACP`UI`Private`acpWriteFinalCell[ "turn-1" ];
                Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
                { step1, step2, step3, Length @ calls[ "NotebookWrite" ] }
            ]
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |>,
            "Turns"   -> <| "turn-1" -> $endedTurn |>
        |>
    ],
    {
        {
            { { "turn-1" } },
            False,
            { { HoldForm[ Wolfram`Chatbook`ACP`UI`Private`acpWriteFinalCell[ "turn-1" ] ], Quantity[ 50, "Milliseconds" ] } },
            { "Finalizing", True },
            True,
            "Running"
        },
        { False, 2 },
        { { { $outCell, Cell[ "final:turn-1", "ChatOutput" ], None, AutoScroll -> False } }, False, { "Ready", None } },
        1
    },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn-FreezeThenWrite@@Tests/ACPWindow.wlt:2409,1-2459,2"
]

(* A frozen view that the front end never renders (a cell scrolled out of view, whose Dynamics it does not evaluate):
   after $acpFreezeTimeout the final cell is rendered in one call and written in a later one; if the front end renders
   the frozen view meanwhile (scrolled into view while the kernel was busy rendering), the write waits for it to settle,
   and the rendered cell is written (not rendered again) *)
VerificationTest[
    withACPMocks[
        Block[ { Wolfram`Chatbook`ACP`Common`acpFreezeLiveView = logCall[ "FreezeLiveView", ## ] & },
            Module[ { step1, step2 },
                Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
                Wolfram`Chatbook`ACP`Common`acpTurnUpdate[ "turn-1", <| #, "FrozenAt" -> AbsoluteTime[ ] - 6 |> & ];
                Wolfram`Chatbook`ACP`UI`Private`acpWriteFinalCell[ "turn-1" ];
                step1 = { calledQ[ "NotebookWrite" ], Wolfram`Chatbook`ACP`Common`acpTurnGet[ "turn-1", "FinalCell" ], Last @ calls[ "Schedule" ] };
                Wolfram`Chatbook`ACP`Common`acpTurnUpdate[ "turn-1", <| #, "FrozenViewShownAt" -> AbsoluteTime[ ] |> & ];
                Wolfram`Chatbook`ACP`UI`Private`acpWriteFinalCell[ "turn-1" ];
                step2 = calledQ[ "NotebookWrite" ];
                Wolfram`Chatbook`ACP`Common`acpTurnUpdate[ "turn-1", <| #, "FrozenViewShownAt" -> AbsoluteTime[ ] - 1 |> & ];
                Block[ { Wolfram`Chatbook`ACP`Common`acpFinalCell = (Cell[ "rendered again", "ChatOutput" ] &) },
                    Wolfram`Chatbook`ACP`UI`Private`acpWriteFinalCell[ "turn-1" ]
                ];
                { step1, step2, calls[ "NotebookWrite" ], KeyExistsQ[ Wolfram`Chatbook`ACP`Common`$acpTurns, "turn-1" ] }
            ]
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |>,
            "Turns"   -> <| "turn-1" -> $endedTurn |>
        |>
    ],
    {
        { False, Cell[ "final:turn-1", "ChatOutput" ], { HoldForm[ Wolfram`Chatbook`ACP`UI`Private`acpWriteFinalCell[ "turn-1" ] ], Quantity[ 50, "Milliseconds" ] } },
        False,
        { { $outCell, Cell[ "final:turn-1", "ChatOutput" ], None, AutoScroll -> False } },
        False
    },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn-FrozenViewNotShown@@Tests/ACPWindow.wlt:2465,1-2496,2"
]

(* When the write waits: not frozen (no live view to freeze) never; not rendered yet, until $acpFreezeTimeout (5 s);
   rendered, until that is $acpFreezeSettle (0.15 s) ago, but at most twice the timeout after the freeze *)
VerificationTest[
    With[ { now = 1000.0, pending = Wolfram`Chatbook`ACP`UI`Private`acpFrozenViewPendingQ },
        {
            pending[ <| |>, now ],
            pending[ <| "FrozenAt" -> now - 1 |>, now ],
            pending[ <| "FrozenAt" -> now - 6 |>, now ],
            pending[ <| "FrozenAt" -> now - 1, "FrozenViewShownAt" -> now - 0.05 |>, now ],
            pending[ <| "FrozenAt" -> now - 1, "FrozenViewShownAt" -> now - 0.2 |>, now ],
            pending[ <| "FrozenAt" -> now - 7, "FrozenViewShownAt" -> now - 0.05 |>, now ],
            pending[ <| "FrozenAt" -> now - 11, "FrozenViewShownAt" -> now - 0.05 |>, now ]
        }
    ],
    { False, True, False, True, False, True, False },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn-FrozenViewPendingQ@@Tests/ACPWindow.wlt:2500,1-2515,2"
]

(* A freeze that fails does not delay the final cell *)
VerificationTest[
    withACPMocks[
        Block[ { Wolfram`Chatbook`ACP`Common`acpFreezeLiveView = Throw[ "freeze failed" ] & },
            Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
            { calls[ "NotebookWrite" ], KeyExistsQ[ Wolfram`Chatbook`ACP`Common`$acpTurns, "turn-1" ] }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |>,
            "Turns"   -> <| "turn-1" -> $endedTurn |>
        |>
    ],
    { { { $outCell, Cell[ "final:turn-1", "ChatOutput" ], None, AutoScroll -> False } }, False },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn-FreezeFails@@Tests/ACPWindow.wlt:2518,1-2532,2"
]

(* A prompt queued while the turn was running is sent after finalization. This runs in a scheduled task while the user
   may be typing or selecting text, so the user cell is written after the finalized output cell with an addressed write:
   no SelectionMove and no selection-based NotebookWrite. *)
VerificationTest[
    withACPMocks[
        Block[
            {
                SelectionMove = logCall[ "SelectionMove", ## ] &,
                Wolfram`Chatbook`Common`setCurrentValue = logCall[ "SetCurrentValue", ## ] &,
                Wolfram`Chatbook`ChatModes`Common`moveChatInputToBottom = logCall[ "MoveInputToBottom", ## ] &
            },
            Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
            {
                calls[ "WriteUserCell" ],
                calls[ "SelectionMove" ],
                calls[ "NotebookWrite" ],
                calls[ "MoveInputToBottom" ],
                Length @ calls[ "SendPrompt" ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "QueuedPrompt", "Status" } ]
            }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1", "QueuedPrompt" -> "Next" ] |>,
            "Turns"   -> <| "turn-1" -> $endedTurn |>
        |>
    ],
    {
        { },
        { },
        {
            { $outCell, Cell[ "final:turn-1", "ChatOutput" ], None, AutoScroll -> False },
            {
                System`NotebookLocationSpecifier[ $outCell, "After" ],
                Cell[ BoxData[ TemplateBox[ { Cell[ "Next", ___ ] }, "UserMessageBox" ] ], "ChatInput", CellTags -> _String ],
                None,
                AutoScroll -> False
            },
            { System`NotebookLocationSpecifier[ $outCell, "After" ], Cell[ _, "ChatOutput", ___ ], None, AutoScroll -> False }
        },
        { { $testNB } },
        1,
        { None, "Running" }
    },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn-SendsQueuedPrompt@@Tests/ACPWindow.wlt:2537,1-2579,2"
]

(* The user cell for the queued prompt cannot be written: the prompt goes back to the input field (not lost) *)
VerificationTest[
    withExpectedLog @ withACPMocks[
        Block[
            {
                NotebookWrite = If[ MatchQ[ #2, Cell[ _, "ChatInput", ___ ] ], Throw[ "write failed" ], logCall[ "NotebookWrite", ## ] ] &,
                Wolfram`Chatbook`Common`$catching = True
            },
            Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
            {
                Length @ calls[ "SendPrompt" ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "QueuedPrompt", "CurrentTurn", "Status" } ],
                $feFlags[ { $testNB, "Input" } ]
            }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1", "QueuedPrompt" -> "Next" ] |>,
            "Turns"   -> <| "turn-1" -> $endedTurn |>,
            "FE"      -> <| { $testNB, "Input" } -> "typed" |>
        |>
    ],
    { 0, { None, None, "Ready" }, "Next\n\ntyped" },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn-QueuedPromptWriteFails@@Tests/ACPWindow.wlt:2582,1-2605,2"
]

(* Once claimed, a turn always finishes, even if rendering and writing throw (untagged): otherwise the window would stay
   "Running" forever *)
VerificationTest[
    withExpectedLog @ withACPMocks[
        Block[ { Wolfram`Chatbook`ACP`Common`acpFinalCell = Throw[ "boom" ] & },
            Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
            {
                calls[ "NotebookWrite" ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "Status", "CurrentTurn" } ],
                KeyExistsQ[ Wolfram`Chatbook`ACP`Common`$acpTurns, "turn-1" ],
                $feFlags[ { $testNB, "Busy" } ]
            }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |>,
            "Turns"   -> <| "turn-1" -> $endedTurn |>,
            "FE"      -> <| { $testNB, "Busy" } -> True |>
        |>
    ],
    {
        { { $outCell, Cell[ BoxData @ TemplateBox[ { Cell[ TextData[ { "markdown" } ], ___ ] }, "AssistantMessageBox" ], "ChatOutput", ___ ], None, AutoScroll -> False } },
        { "Ready", None },
        False,
        False
    },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn-UntaggedThrow@@Tests/ACPWindow.wlt:2609,1-2634,2"
]

VerificationTest[
    withExpectedLog @ withACPMocks[
        Block[
            {
                Wolfram`Chatbook`ACP`Common`acpFinalCell      = Throw[ "boom" ] &,
                Wolfram`Chatbook`ACP`Common`acpTurnToMarkdown = Throw[ "boom2" ] &,
                NotebookWrite = Throw[ "write failed" ] &
            },
            {
                Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "Status", "CurrentTurn" } ],
                KeyExistsQ[ Wolfram`Chatbook`ACP`Common`$acpTurns, "turn-1" ],
                $feFlags[ { $testNB, "Busy" } ]
            }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |>,
            "Turns"   -> <| "turn-1" -> $endedTurn |>,
            "FE"      -> <| { $testNB, "Busy" } -> True |>
        |>
    ],
    { Null, { "Ready", None }, False, False },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn-EverythingThrows@@Tests/ACPWindow.wlt:2636,1-2660,2"
]

(* The front end can miss the reset of the busy flag (the Stop button stays): a scheduled second change, False -> None,
   makes it redraw; a flag that is set again, or a window with a new turn, is left alone *)
VerificationTest[
    withACPMocks[
        Module[ { settle, scheduled, idle, busy, running },
            Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
            scheduled = calls[ "Schedule" ];
            settle = Wolfram`Chatbook`ACP`UI`Private`settleBusyFlag;
            settle @ $testNB;
            idle = $feFlags[ { $testNB, "Busy" } ];
            $feFlags[ { $testNB, "Busy" } ] = True;
            settle @ $testNB;
            busy = $feFlags[ { $testNB, "Busy" } ];
            $feFlags[ { $testNB, "Busy" } ] = False;
            Wolfram`Chatbook`ACP`Common`acpWindowSet[ $testNB, "CurrentTurn", "turn-2" ];
            settle @ $testNB;
            running = $feFlags[ { $testNB, "Busy" } ];
            { scheduled, idle, busy, running }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |>,
            "Turns"   -> <| "turn-1" -> $endedTurn |>,
            "FE"      -> <| { $testNB, "Busy" } -> True |>
        |>
    ],
    {
        { { HoldForm[ Wolfram`Chatbook`ACP`UI`Private`settleBusyFlag[ NotebookObject[ "acp-test-notebook" ] ] ], Quantity[ 500, "Milliseconds" ] } },
        None,
        True,
        False
    },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn-SettleBusyFlag@@Tests/ACPWindow.wlt:2664,1-2695,2"
]

(* Permission requests of the finished turn that are still pending (e.g. one that arrived after Stop) are answered
   "cancelled" and removed from the window; requests of other turns stay *)
VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
        {
            calls[ "AnswerPermission" ],
            Keys @ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "PendingPermissions" ],
            Cases[ calls[ "SetOptions" ], { $testNB, WindowTitle -> t_ } :> t ]
        },
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1",
                "PendingPermissions" -> <| 7 -> <| "TurnID" -> "turn-1" |>, 8 -> <| "TurnID" -> "turn-0" |> |> ] |>,
            "Turns"   -> <| "turn-1" -> $endedTurn |>
        |>
    ],
    { { { $testNB, 7, None } }, { 8 }, { _String? (StringStartsQ[ "Approval needed" ]) } },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn-CancelsPendingPermissions@@Tests/ACPWindow.wlt:2699,1-2716,2"
]

(* Housekeeping finalizes turns that ended but were not finalized *)
VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`UI`Private`acpUIHousekeeping[ ];
        { calledQ[ "NotebookWrite" ], KeyExistsQ[ Wolfram`Chatbook`ACP`Common`$acpTurns, "turn-1" ] },
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |>,
            "Turns"   -> <| "turn-1" -> $endedTurn |>
        |>
    ],
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "Housekeeping-FinalizeFallback@@Tests/ACPWindow.wlt:2719,1-2731,2"
]

(* ... and finishes turns whose finalization was claimed but never completed (after $acpFinalizeTimeout seconds) *)
VerificationTest[
    withACPMocks[
        Module[ { stuck = <| $endedTurn, "FinalizeClaimed" -> True, "Status" -> "Finalizing" |> },
            Wolfram`Chatbook`ACP`Common`acpTurnCreate @ <| stuck, "ID" -> "turn-2", "FinalizeClaimedAt" -> AbsoluteTime[ ] - 5 |>;
            Wolfram`Chatbook`ACP`Common`acpTurnCreate @ <| stuck, "FinalizeClaimedAt" -> AbsoluteTime[ ] - 60 |>;
            Wolfram`Chatbook`ACP`UI`Private`acpUIHousekeeping[ ];
            {
                calls[ "NotebookWrite" ],
                KeyExistsQ[ Wolfram`Chatbook`ACP`Common`$acpTurns, "turn-1" ],
                KeyExistsQ[ Wolfram`Chatbook`ACP`Common`$acpTurns, "turn-2" ], (* claimed recently: still finalizing *)
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "Status", "CurrentTurn" } ],
                $feFlags[ { $testNB, "Busy" } ]
            }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |>,
            "FE"      -> <| { $testNB, "Busy" } -> True |>
        |>
    ],
    {
        { { $outCell, Cell[ BoxData @ TemplateBox[ { Cell[ TextData[ { "markdown" } ], ___ ] }, "AssistantMessageBox" ], "ChatOutput", ___ ], None, AutoScroll -> False } },
        False,
        True,
        { "Ready", None },
        False
    },
    SameTest -> MatchQ,
    TestID   -> "Housekeeping-FinalizeTimeout@@Tests/ACPWindow.wlt:2734,1-2762,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Toolbar*)
VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`UI`Private`acpConfigOptionValues @ <|
            "options" -> {
                <| "value" -> "a", "name" -> "A" |>,
                <| "group" -> "g", "name" -> "Group", "options" -> { <| "value" -> "b", "name" -> "B" |> } |>,
                "junk"
            }
        |>
    ],
    { <| "value" -> "a", "name" -> "A" |>, <| "value" -> "b", "name" -> "B" |> },
    SameTest -> MatchQ,
    TestID   -> "ConfigOptionValues@@Tests/ACPWindow.wlt:2767,1-2780,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`UI`Private`acpConfigMenusView[ $testNB, testWindow @ $testNB ]
    ],
    Row[
        {
            Tooltip[ ActionMenu[ _, { _Rule, _Rule }, ___, BoxID -> "ACPModelMenu", ___, Enabled -> True, ___ ], "Model (OpenAI (your account))" ],
            Tooltip[ ActionMenu[ _, { _RuleDelayed, _RuleDelayed }, ___, BoxID -> "ACPModeMenu", ___ ], "The default agent." ],
            Tooltip[ ActionMenu[ _, { _RuleDelayed, _RuleDelayed }, ___, BoxID -> "ACPEffortMenu", ___ ], "Available effort levels for this model" ]
        },
        _
    ],
    SameTest -> MatchQ,
    TestID   -> "ConfigMenus-Structure@@Tests/ACPWindow.wlt:2782,1-2796,2"
]

VerificationTest[
    withACPMocks @ Module[ { menu, items },
        menu = Wolfram`Chatbook`ACP`UI`Private`acpModelMenu[ $testNB, testWindow @ $testNB, True ];
        items = Flatten @ Cases[ menu, ActionMenu[ _, items_List, ___ ] :> items, Infinity ];
        {
            Cases[ items, (lbl_ -> _List) :> lbl, { 1 } ],
            Cases[
                items,
                (_ -> sub_List) :> Cases[ sub, HoldPattern[ Row @ { Style[ _, ShowContents -> checked_ ], " ", Style[ name_, ___ ] } :> code_ ] :> { name, checked, Hold @ code } ],
                { 1 }
            ]
        }
    ],
    With[ { nb = $testNB }, {
        { "OpenAI (your account)", "OpenCode (free)" },
        {
            {
                { "GPT-6.1 Sol", True , Hold[ _; _[ "ACP", "SetConfigOption", nb, "model", "openai/gpt-6.1-sol" ] ] },
                { "GPT-6 Luna" , False, Hold[ _; _[ "ACP", "SetConfigOption", nb, "model", "openai/gpt-6-luna" ] ] }
            },
            {
                { "Big Pickle" , False, Hold[ _; _[ "ACP", "SetConfigOption", nb, "model", "opencode/big-pickle" ] ] }
            }
        }
    } ],
    SameTest -> MatchQ,
    TestID   -> "ConfigMenus-ModelItems@@Tests/ACPWindow.wlt:2798,1-2825,2"
]

VerificationTest[
    withACPMocks[
        Cases[
            Wolfram`Chatbook`ACP`UI`Private`acpConfigMenusView[ $testNB, testWindow[ $testNB, "CurrentTurn" -> "turn-1" ] ],
            ActionMenu[ ___, Enabled -> e_, ___ ] :> e,
            Infinity
        ]
    ],
    { False, False, False },
    SameTest -> MatchQ,
    TestID   -> "ConfigMenus-DisabledWhileRunning@@Tests/ACPWindow.wlt:2827,1-2838,2"
]

VerificationTest[
    withACPMocks[
        Cases[
            Wolfram`Chatbook`ACP`UI`Private`acpConfigMenusView[
                $testNB,
                testWindow[ $testNB, "ConfigOptions" -> ReplacePart[ $testConfigOptions, { 2, "options" } -> { <| "value" -> "default", "name" -> "Default" |> } ] ]
            ],
            ActionMenu[ ___, BoxID -> id_, ___ ] :> id,
            Infinity
        ]
    ],
    { "ACPModelMenu", "ACPModeMenu" },
    SameTest -> MatchQ,
    TestID   -> "ConfigMenus-EffortHidden@@Tests/ACPWindow.wlt:2840,1-2854,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`UI`Private`acpConfigMenusView[ $testNB, testWindow[ $testNB, "ConfigOptions" -> { } ] ]
    ],
    Spacer[ 0 ],
    SameTest -> MatchQ,
    TestID   -> "ConfigMenus-NoOptions@@Tests/ACPWindow.wlt:2856,1-2863,2"
]

(* The main row can't shrink: the model's name takes one line, cut at its end by the front end to the room that New,
   Sessions and the other menus leave (their labels are measured in the front end, with the reserves of three menus);
   the tooltip of a name that was cut has the name and the menu's tooltip. Without a width (acpModelMenu's three
   arguments) the name is whole. *)
VerificationTest[
    withACPMocks @ Module[ { boxes, args, width },
        boxes = ToBoxes @ Wolfram`Chatbook`ACP`UI`Private`acpConfigMenusView[ $testNB, testWindow @ $testNB ];
        (* held: the width is a front end expression (Part of FEPrivate`StringWidth must not be evaluated) *)
        args  = Cases[ boxes, DynamicBox[ Function[ _ ][ a__ ], ___ ] :> HoldComplete[ a ], Infinity ];
        width = Extract[ First @ args, { 1 }, HoldComplete ];
        {
            (* the label's default, hover and pressed copies *)
            Length @ args,
            DeleteDuplicates[ Cases[ Extract[ #, { 6 } ] /. (_Rule | _RuleDelayed) -> Nothing, s_String :> StringTrim[ s, "\"" ], { 0, Infinity } ] & /@ args ],
            DeleteDuplicates @ Cases[ boxes, HoldPattern[ FEPrivate`Take ][ _, n_ ] :> MatchQ[ Unevaluated @ n, _Times ], Infinity ],
            Sort @ DeleteDuplicates @ Cases[ width, HoldPattern[ FEPrivate`StringWidth ][ s_String, ___ ] :> s, Infinity ],
            (* the row's screen points (not scaled) and its reserves at magnification 1, without and with the buttons' labels *)
            And[
                ! FreeQ[ width, N[ Wolfram`Chatbook`ACP`UI`Private`$toolbarScreenReserve + Wolfram`Chatbook`ACP`Rendering`Private`$fitSafetyMargin ] ],
                ! FreeQ[ width, N[ Wolfram`Chatbook`ACP`UI`Private`$mainRowReserve + 3 * Wolfram`Chatbook`ACP`UI`Private`$menuReserve ] ],
                ! FreeQ[ width, N[ Wolfram`Chatbook`ACP`UI`Private`$mainRowReserve + 3 * Wolfram`Chatbook`ACP`UI`Private`$menuReserve + 2 * Wolfram`Chatbook`ACP`UI`Private`$buttonLabelReserve ] ]
            ],
            ! FreeQ[ Extract[ First @ args, { 7 }, HoldComplete ], TooltipBox[ _, t_ /; ! FreeQ[ t, "\"GPT-6.1 Sol\"" ] && ! FreeQ[ t, "\"Model (OpenAI (your account))\"" ], ___ ] ],
            FreeQ[ Wolfram`Chatbook`ACP`UI`Private`acpModelMenu[ $testNB, testWindow @ $testNB, True ], _Pane ]
        }
    ],
    { 3, { { "GPT-6.1 Sol" } }, { False }, { "Build", "Default", "New", "Sessions" }, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ConfigMenus-ModelLabelFits@@Tests/ACPWindow.wlt:2869,1-2894,2"
]

(* Inside an ActionMenu a pane's Full width is a fixed width (about 376 points times the magnification, measured in a
   real front end) whatever the room in the row, so a model name cut to a wider room lost its ellipsis there: the model
   label's clipping panes have a number of points as their largest width ("MaxWidth" of acpFitText); other cut texts
   keep Full *)
VerificationTest[
    withACPMocks @ Module[ { boxes, label, maxWidths },
        boxes     = ToBoxes @ Wolfram`Chatbook`ACP`UI`Private`acpConfigMenusView[ $testNB, testWindow @ $testNB ];
        label     = Cases[ boxes, ActionMenuBox[ l_, ___, BoxID -> "ACPModelMenu", ___ ] :> l, Infinity ];
        maxWidths = Cases[ #, PaneBox[ _, ___, ImageSize -> { { 0, w_ }, Automatic }, ___ ] :> w, Infinity ] &;
        {
            Length @ label,
            Union @ maxWidths @ label,
            Union @ maxWidths @ ToBoxes @ Wolfram`Chatbook`ACP`Common`acpFitText @ <| "Object" -> "a long text", "Width" -> Wolfram`Chatbook`ACP`Common`acpFitWidth[ 10 ] |>
        }
    ],
    { 1, { Wolfram`Chatbook`ACP`UI`Private`$menuLabelMaxWidth }, { Full } },
    SameTest -> MatchQ,
    TestID   -> "ConfigMenus-ModelLabelMaxWidth@@Tests/ACPWindow.wlt:2900,1-2914,2"
]

(* The labels of the other menus that the model's name leaves room for: None for a menu that is not shown *)
VerificationTest[
    withACPMocks @ With[ { label = Wolfram`Chatbook`ACP`UI`Private`acpConfigMenuLabel },
        {
            label[ testWindow @ $testNB, "mode" ],
            label[ testWindow @ $testNB, "thought_level" ],
            label[ testWindow[ $testNB, "ConfigOptions" -> ReplacePart[ $testConfigOptions, { 2, "options" } -> { <| "value" -> "default", "name" -> "Default" |> } ] ], "thought_level" ],
            label[ testWindow[ $testNB, "ConfigOptions" -> { } ], "mode" ],
            label[ testWindow[ $testNB, "PendingConfig" -> <| "mode" -> "plan" |> ], "mode" ]
        }
    ],
    { "Build", "Default", None, None, "Plan" },
    SameTest -> MatchQ,
    TestID   -> "ConfigMenus-OtherLabels@@Tests/ACPWindow.wlt:2917,1-2930,2"
]

(* In a narrow or magnified window New and Sessions show only their icons, and the model's name gets the room of their
   labels: the buttons' labels and the model's width choose in the front end on the same test, the room for the model's
   name that the row leaves with the buttons' labels and menus of a typical width ($menuLabelsAllowance) *)
VerificationTest[
    withACPMocks @ Module[ { switches, new, sessions, menus, modelTests },
        switches   = Cases[ #, DynamicBox[ FEPrivate`If[ t_, narrow_, wide_ ], ___ ] :> { HoldComplete @ t, narrow, wide }, Infinity ] &;
        new        = ToBoxes @ Wolfram`Chatbook`ACP`UI`Private`acpNewChatButton[ $testNB, testWindow @ $testNB ];
        sessions   = ToBoxes @ Wolfram`Chatbook`ACP`Common`acpSessionsButton @ $testNB;
        menus      = ToBoxes @ Wolfram`Chatbook`ACP`UI`Private`acpConfigMenusView[ $testNB, testWindow @ $testNB ];
        (* the test of the model's width (unevaluated: the first argument of its fitting DynamicBox's function) *)
        modelTests = Cases[ menus, DynamicBox[ Function[ _ ][ FEPrivate`If[ t_, _, _ ], ___ ], ___ ] :> HoldComplete[ t ], Infinity ];
        {
            Length @ DeleteDuplicates @ Join[ First /@ switches @ new, First /@ switches @ sessions, modelTests ],
            Length @ modelTests,
            And[
                ! FreeQ[
                    First @ modelTests,
                    N[
                        Wolfram`Chatbook`ACP`UI`Private`$mainRowReserve + 3 * Wolfram`Chatbook`ACP`UI`Private`$menuReserve +
                            2 * Wolfram`Chatbook`ACP`UI`Private`$buttonLabelReserve + Wolfram`Chatbook`ACP`UI`Private`$menuLabelsAllowance
                    ]
                ],
                ! FreeQ[ First @ modelTests, N[ Wolfram`Chatbook`ACP`UI`Private`$toolbarScreenReserve + Wolfram`Chatbook`ACP`Rendering`Private`$fitSafetyMargin ] ]
            ],
            ! FreeQ[ First @ modelTests, N @ Wolfram`Chatbook`ACP`UI`Private`$minModelLabelWidth ],
            Sort @ DeleteDuplicates @ Cases[ First @ modelTests, HoldPattern[ FEPrivate`StringWidth ][ s_String, ___ ] :> s, Infinity ],
            (* narrow: the icon alone; wide: the icon and the label *)
            DeleteDuplicates[ { FreeQ[ #[[ 2 ]], "\"New\"" ], ! FreeQ[ #[[ 3 ]], "\"New\"" ], ! FreeQ[ #[[ 2 ]], "WorkspaceToolbarIconNew" ] } & /@ switches @ new ]
        }
    ],
    { 1, 3, True, True, { "New", "Sessions" }, { { True, True, True } } },
    SameTest -> MatchQ,
    TestID   -> "ConfigMenus-NarrowRow@@Tests/ACPWindow.wlt:2935,1-2965,2"
]

(* The selected model is remembered *)
VerificationTest[
    withACPMocks[
        Block[ { Wolfram`Chatbook`ACP`UI`Private`$recentModels = <| "OpenCode" -> { } |> },
            Wolfram`Chatbook`Common`acpAction[ "SetConfigOption", $testNB, "model", "opencode/big-pickle" ];
            { calls[ "SetConfigOption" ], Wolfram`Chatbook`ACP`UI`Private`$recentModels[ "OpenCode" ] }
        ],
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    { { { $testNB, "model", "opencode/big-pickle" } }, { "opencode/big-pickle" } },
    SameTest -> MatchQ,
    TestID   -> "SetConfigOption-RecentModels@@Tests/ACPWindow.wlt:2968,1-2979,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`Common`acpAction[ "SetConfigOption", $testNB, "model", "opencode/big-pickle" ];
        calledQ[ "SetConfigOption" ],
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "CurrentTurn" -> "turn-1" ] |> |>
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "SetConfigOption-IgnoredWhileRunning@@Tests/ACPWindow.wlt:2981,1-2990,2"
]

VerificationTest[
    {
        Wolfram`Chatbook`ACP`UI`Private`acpModelShortName[ "openai/gpt-6.1-sol", $testConfigOptions[[ 1, "options" ]] ],
        Wolfram`Chatbook`ACP`UI`Private`acpModelShortName[ "x/unknown", $testConfigOptions[[ 1, "options" ]] ],
        Wolfram`Chatbook`ACP`UI`Private`acpModelProvider[ "opencode/big-pickle" ],
        Wolfram`Chatbook`ACP`UI`Private`acpModelProvider[ "plain" ]
    },
    { "GPT-6.1 Sol", "unknown", "opencode", "" },
    SameTest -> MatchQ,
    TestID   -> "ModelNames@@Tests/ACPWindow.wlt:2992,1-3002,2"
]

(* Provider submenu labels: the billing label once (not "openai  openai"), or the provider's name if its models are
   billed differently *)
VerificationTest[
    withACPMocks @ {
        Wolfram`Chatbook`ACP`UI`Private`acpProviderLabel[ "openai", { <| "value" -> "openai/gpt-6.1-sol" |>, <| "value" -> "openai/gpt-6-luna" |> } ],
        Wolfram`Chatbook`ACP`UI`Private`acpProviderLabel[ "opencode", { <| "value" -> "opencode/big-pickle" |> } ],
        Block[ { Wolfram`Chatbook`ACP`Common`acpBillingLabel = Replace[ #, { "opencode/big-pickle" -> "OpenCode (free)", _ -> "OpenCode Zen" } ] & },
            Wolfram`Chatbook`ACP`UI`Private`acpProviderLabel[ "opencode", { <| "value" -> "opencode/big-pickle" |>, <| "value" -> "opencode/zen-model" |> } ]
        ],
        Block[ { Wolfram`Chatbook`ACP`Common`acpBillingLabel = ("" &) },
            {
                Wolfram`Chatbook`ACP`UI`Private`acpProviderLabel[ "mistral", { <| "value" -> "mistral/large" |> } ],
                Wolfram`Chatbook`ACP`UI`Private`acpProviderLabel[ "", { <| "value" -> "plain" |> } ]
            }
        ]
    },
    { "OpenAI (your account)", "OpenCode (free)", "OpenCode", { "mistral", "Other" } },
    SameTest -> MatchQ,
    TestID   -> "ModelMenu-ProviderLabels@@Tests/ACPWindow.wlt:3006,1-3023,2"
]

(* The config menus (model, mode, effort) show agent-provided option names, provider names and descriptions, so their
   linear syntax is neutralized: the private-use characters (U+F7C0-U+F7CD) become U+FFFD in every label and tooltip, in
   the menu items and the button label. The menu items' actions (SetConfigOption) carry the real option value, which
   stays as the agent sent it (it is data passed back to the agent, never rendered as boxes), so the private-use check
   strips the actions first. *)
VerificationTest[
    withACPMocks @ Module[ { evil, pua, strip, hasPUA, hasFFFD, options, win, menus },
        evil    = FromCharacterCode[ { 63425, 63433, 63432 } ] <> "DynamicBox[Print[1]]" <> FromCharacterCode[ 63424 ];
        pua     = Characters @ FromCharacterCode @ Range[ 63424, 63437 ];
        (* drop each menu item's action (the RHS of :>), which legitimately carries the unneutralized option value *)
        strip   = # /. Verbatim[ RuleDelayed ][ l_, _ ] :> RuleDelayed[ l, Null ] &;
        hasPUA  = ! FreeQ[ ToBoxes @ strip @ #, s_String /; StringContainsQ[ s, Alternatives @@ pua ] ] &;
        hasFFFD = ! FreeQ[ ToBoxes @ strip @ #, s_String /; StringContainsQ[ s, "\:fffd" ] ] &;
        options = {
            <| "id" -> "model", "name" -> "Model", "category" -> "model", "type" -> "select", "currentValue" -> "openai/" <> evil,
               "options" -> { <| "value" -> "openai/" <> evil, "name" -> "openai/" <> evil |>, <| "value" -> "openai/other", "name" -> "openai/Other" |> } |>,
            <| "id" -> "effort", "name" -> "Effort", "description" -> "d " <> evil, "category" -> "thought_level", "type" -> "select", "currentValue" -> "high",
               "options" -> { <| "value" -> "high", "name" -> "H " <> evil |>, <| "value" -> "low", "name" -> "Low" |> } |>,
            <| "id" -> "mode", "name" -> "Mode", "category" -> "mode", "type" -> "select", "currentValue" -> "build",
               "options" -> { <| "value" -> "build", "name" -> "B " <> evil, "description" -> "bd " <> evil |>, <| "value" -> "plan", "name" -> "Plan", "description" -> "Read-only." |> } |>
        };
        win   = testWindow[ $testNB, "ConfigOptions" -> options ];
        menus = {
            Wolfram`Chatbook`ACP`UI`Private`acpModelMenu[ $testNB, win, True ],
            Wolfram`Chatbook`ACP`UI`Private`acpModeMenu[ $testNB, win, True ],
            Wolfram`Chatbook`ACP`UI`Private`acpEffortMenu[ $testNB, win, True ]
        };
        {
            (* no private-use characters survive in any menu *)
            hasPUA /@ menus,
            (* the neutralized text is still shown (U+FFFD), not dropped *)
            hasFFFD /@ menus,
            (* the name producers neutralize their agent strings *)
            { hasPUA @ #, hasFFFD @ # } & @ Wolfram`Chatbook`ACP`UI`Private`acpModelShortName[ "openai/" <> evil, options[[ 1, "options" ]] ],
            { hasPUA @ #, hasFFFD @ # } & @ Wolfram`Chatbook`ACP`UI`Private`acpOptionName[ "build", options[[ 3, "options" ]] ],
            Block[ { Wolfram`Chatbook`ACP`UI`Private`acpBillingText = ("" &) },
                { hasPUA @ #, hasFFFD @ # } & @ Wolfram`Chatbook`ACP`UI`Private`acpProviderLabel[ "prov" <> evil, { <| "value" -> "prov" <> evil <> "/m" |> } ]
            ]
        }
    ],
    {
        { False, False, False },
        { True, True, True },
        { False, True },
        { False, True },
        { False, True }
    },
    SameTest -> MatchQ,
    TestID   -> "ConfigMenus-AgentTextNeutralized@@Tests/ACPWindow.wlt:3030,1-3074,2"
]

VerificationTest[
    withACPMocks @ {
        Wolfram`Chatbook`ACP`Common`acpAbbreviatePath @ FileNameJoin @ { $HomeDirectory, "TestProject" },
        StringLength @ Wolfram`Chatbook`ACP`Common`acpAbbreviatePath @ FileNameJoin @ Prepend[ ConstantArray[ "abcdefghij", 10 ], "/" ],
        (* only the home folder and paths in it; no length limit with None *)
        Wolfram`Chatbook`ACP`Common`acpAbbreviatePath @ $HomeDirectory,
        Wolfram`Chatbook`ACP`Common`acpAbbreviatePath[ $HomeDirectory <> "2" <> $PathnameSeparator <> "proj", None ] === $HomeDirectory <> "2" <> $PathnameSeparator <> "proj",
        StringLength @ Wolfram`Chatbook`ACP`Common`acpAbbreviatePath[ FileNameJoin @ Prepend[ ConstantArray[ "abcdefghij", 10 ], "/" ], None ],
        Wolfram`Chatbook`ACP`UI`Private`acpDirectoryWarning @ $HomeDirectory,
        Wolfram`Chatbook`ACP`UI`Private`acpDirectoryWarning @ FileNameJoin @ { $TemporaryDirectory, CreateUUID[ ] },
        Wolfram`Chatbook`ACP`UI`Private`acpDirectoryWarning @ $TemporaryDirectory,
        Wolfram`Chatbook`ACP`UI`Private`acpDirectoryWarning @ None
    },
    {
        "~" <> $PathnameSeparator <> "TestProject",
        42,
        "~",
        True,
        110,
        "This is your home folder: the agent can read and change everything in it.",
        "This folder does not exist.",
        None,
        None
    },
    SameTest -> MatchQ,
    TestID   -> "ProjectDirectoryHelpers@@Tests/ACPWindow.wlt:3076,1-3102,2"
]

VerificationTest[
    withACPMocks @ {
        Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString[ "/home/user/TestProject", "OpenCode", False ],
        Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString[ "/home/user/TestProject", "OpenCode", True ],
        Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString[ None, "OpenCode", False ]
    },
    { "TestProject \[LongDash] OpenCode", "Approval needed \[LongDash] TestProject", "OpenCode" },
    SameTest -> MatchQ,
    TestID   -> "WindowTitle@@Tests/ACPWindow.wlt:3104,1-3113,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`Common`acpUpdateWindowTitle @ $testNB;
        Wolfram`Chatbook`ACP`Common`acpUpdateWindowTitle @ $testNB;
        calls[ "SetOptions" ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "PendingPermissions" -> <| "1" -> <| |> |> ] |>
        |>
    ],
    { { $testNB, WindowTitle -> _String? (StringStartsQ[ "Approval needed" ]) } },
    SameTest -> MatchQ,
    TestID   -> "WindowTitle-Update@@Tests/ACPWindow.wlt:3115,1-3127,2"
]

VerificationTest[
    withACPMocks[
        ToBoxes @ Wolfram`Chatbook`Common`makeACPChatDockedCell @ $testNB,
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    (* the New button is a derived view (disabled while a session is restored); the Sessions button toggles the
       Sessions window *)
    _? (And[
        ! FreeQ[ #, Wolfram`Chatbook`ACP`UI`Private`acpNewChatButton ],
        ! FreeQ[ #, "InitializeWindow" ],
        ! FreeQ[ #, "ACPSessionsButton" ],
        ! FreeQ[ #, "ToggleSessions" ],
        FreeQ[ #, _Failure ]
    ] &),
    SameTest -> MatchQ,
    TestID   -> "ToolbarStructure@@Tests/ACPWindow.wlt:3129,1-3145,2"
]

(* The toolbar is built by a preemptive front end evaluation that may interrupt a Notebook Assistant chat (inside its
   catchTop): a failure must not escape; a minimal toolbar still initializes the window *)
VerificationTest[
    withExpectedLog @ withACPMocks[
        Block[
            {
                Wolfram`Chatbook`ACP`UI`Private`acpToolbarMainRow = Wolfram`Chatbook`Common`throwInternalFailure[ "test" ] &,
                EvaluationNotebook = $testNB &
            },
            Catch[
                Block[ { Wolfram`Chatbook`Common`catchTop = # &, Wolfram`Chatbook`Common`$catching = True },
                    ChatbookAction[ "MakeACPChatDockedCell" ]
                ],
                _,
                "escaped" &
            ]
        ],
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    _DynamicModule? (! FreeQ[ #, "InitializeWindow" ] &),
    SameTest -> MatchQ,
    TestID   -> "ToolbarIsolated@@Tests/ACPWindow.wlt:3149,1-3169,2"
]

VerificationTest[
    (* The arguments of the function of the fitting DynamicBoxes in a view, held (see acpFitText: the width expression, the
       widths of the fixed text, the object and the ellipsis, the font, the boxes when everything fits, the function of
       the cut text; Part of the front end's FEPrivate`StringWidth must not be evaluated); the folder labels: the boxes when everything fits, as the strings they hold (without quotes), one
       list per label; whether the front end cuts at the start (a negative count of FEPrivate`Take) *)
    folderLabelArguments[ expr_ ] := Cases[ ToBoxes @ expr, DynamicBox[ Function[ _ ][ args__ ], ___ ] :> HoldComplete[ args ], Infinity ];
    folderBoxTexts[ boxes_ ] := StringTrim[ #, "\"" ] & /@ Cases[ boxes /. (_Rule | _RuleDelayed) -> Nothing, _String, { 0, Infinity } ];
    folderLabelTexts[ expr_ ] := folderBoxTexts @ Extract[ #, { 6 } ] & /@ folderLabelArguments @ expr;
    folderLabelCutsStartQ[ expr_ ] := ! FreeQ[ ToBoxes @ expr, HoldPattern[ FEPrivate`Take ][ _, _Times ] ];
    (* strings in a view, without the quotes of strings in boxes (not the strings of its font options, e.g.
       "OperatorSubstitution") *)
    viewTexts[ expr_ ] := StringTrim[ #, "\"" ] & /@ Cases[ expr /. HoldPattern[ PrivateFontOptions -> _ ] -> Nothing, _String, Infinity ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "FolderLabel-Definitions@@Tests/ACPWindow.wlt:3171,1-3187,2"
]

(* The folder is the control: a local window's label is the Appearance of the front end's directory dialog (a
   FileNameSetter at its natural width, whose setter runs "SetProjectDirectory"), with the toolbar buttons' hover look
   (three copies of the label: default, hover and pressed, the last two in the buttons' blue); there is no separate
   "Change..." button. The path takes one line, cut at its start by the front end. *)
VerificationTest[
    withACPMocks @ Module[ { view, dir },
        dir  = FileNameJoin @ { $TemporaryDirectory, "acp-folder-row" };
        view = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ $testNB, testWindow[ $testNB, "ProjectDirectory" -> dir ] ];
        {
            Cases[ view, FileNameSetter[ _Dynamic, "Directory", ___, Enabled -> e_, ___ ] :> e, Infinity ],
            Cases[ view, FileNameSetter[ ___, ImageSize -> s_, ___ ] :> s, Infinity ],
            ! FreeQ[ view, "SetProjectDirectory" ],
            FreeQ[ view, s_String /; StringContainsQ[ s, "Change" ] ],
            DeleteDuplicates @ folderLabelTexts @ Cases[ view, FileNameSetter[ ___, HoldPattern[ Appearance -> a_ ], ___ ] :> a, Infinity ],
            Length @ folderLabelTexts @ view,
            folderLabelCutsStartQ @ view,
            Count[ view, HoldPattern[ FontColor -> Wolfram`Chatbook`Common`color[ "NA_BlueHueButtonIcon" ] ] | HoldPattern[ FontColor -> _LightDarkSwitched ], Infinity ] >= 2
        }
    ],
    { { True }, { Automatic }, True, True, { { s_String } } /; StringEndsQ[ s, "acp-folder-row" ], 3, True, True },
    SameTest -> MatchQ,
    TestID   -> "DirectoryRow@@Tests/ACPWindow.wlt:3193,1-3211,2"
]

(* The tooltip is outside the control (it also shows while the control is disabled): the folder's path and "Click to
   choose another folder", or why the folder can't be changed now; disabled, the label has no hover look (one copy) *)
VerificationTest[
    withACPMocks @ Module[ { tooltip, ready, running, restoring },
        tooltip = Cases[ #, Tooltip[ _FileNameSetter | _Button, t_ ] :> viewTexts @ t, Infinity ] &;
        ready     = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ $testNB, testWindow[ $testNB, "ProjectDirectory" -> "/srv/app" ] ];
        running   = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ $testNB, testWindow[ $testNB, "ProjectDirectory" -> "/srv/app", "CurrentTurn" -> "t1", "Status" -> "Running" ] ];
        restoring = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ $testNB, testWindow[ $testNB, "ProjectDirectory" -> "/srv/app", "Status" -> "Restoring" ] ];
        {
            tooltip @ ready,
            tooltip @ running,
            tooltip @ restoring,
            Cases[ running, FileNameSetter[ ___, Enabled -> e_, ___ ] :> e, Infinity ],
            Length @ folderLabelTexts @ running,
            (* the busy reason is part of the row's signature *)
            Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowSignature[ testWindow[ $testNB, "Status" -> "Restoring" ] ][[ 2 ]]
        }
    ],
    {
        { { "Project folder: /srv/app", "Click to choose another folder" } },
        { { "Project folder: /srv/app", "The project folder can't be changed while the agent is working." } },
        { { "Project folder: /srv/app", "The project folder can't be changed while a session is loading." } },
        { False },
        1,
        "NoticeDirectoryWhileRestoring"
    },
    SameTest -> MatchQ,
    TestID   -> "DirectoryRow-Tooltip@@Tests/ACPWindow.wlt:3215,1-3241,2"
]

(* Without a folder, the control reads "Choose folder..." (the tooltip says that there is no folder): a local window's
   is the directory dialog, a remote window's opens the folder picker *)
VerificationTest[
    withACPMocks @ Module[ { local },
        local = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ $testNB, testWindow[ $testNB, "ProjectDirectory" -> None ] ];
        {
            Cases[ local, FileNameSetter[ ___, HoldPattern[ Appearance -> a_ ], ___ ] :> MemberQ[ viewTexts @ a, "Choose folder\[Ellipsis]" ], Infinity ],
            Cases[ local, Tooltip[ _FileNameSetter, t_ ] :> viewTexts @ t, Infinity ],
            folderLabelTexts @ local
        }
    ],
    { { True }, { { "No project folder" } }, { } },
    SameTest -> MatchQ,
    TestID   -> "DirectoryRow-NoFolder@@Tests/ACPWindow.wlt:3245,1-3257,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`UI`Private`acpSetProjectDirectoryAction[ $testNB, File @ FileNameJoin @ { $TemporaryDirectory, "." } ];
        calls[ "SetProjectDirectory" ],
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "ProjectDirectory" -> "/nonexistent" ] |> |>
    ],
    { { $testNB, ExpandFileName @ $TemporaryDirectory } },
    SameTest -> MatchQ,
    TestID   -> "SetProjectDirectory@@Tests/ACPWindow.wlt:3259,1-3268,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`UI`Private`acpSetProjectDirectoryAction[ $testNB, $HomeDirectory ];
        { calledQ[ "SetProjectDirectory" ], Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Notice" ] },
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "CurrentTurn" -> "turn-1" ] |> |>
    ],
    { False, "The project folder can't be changed while the agent is working." },
    SameTest -> MatchQ,
    TestID   -> "SetProjectDirectory-WhileRunning@@Tests/ACPWindow.wlt:3270,1-3279,2"
]

(* An existing window is reused; an explicit different project directory is applied unless the agent is busy *)
VerificationTest[
    withACPMocks[
        Block[
            {
                Wolfram`Chatbook`ChatModes`Common`attachToLeft = (logCall[ "AttachToLeft", ## ]; #2) &,
                Wolfram`Chatbook`Common`moveToChatInputField = logCall[ "MoveToInput", ## ] &,
                SetSelectedNotebook = logCall[ "Select", ## ] &
            },
            {
                Wolfram`Chatbook`ACP`UI`Private`acpReuseWindow[ $testNB2, $testNB, <| "ProjectDirectory" -> $HomeDirectory |> ],
                calls[ "SetProjectDirectory" ],
                calls[ "AttachToLeft" ],
                calledQ[ "EnsureConnected" ]
            }
        ],
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    (* attachToLeft with the ACP window's width *)
    { $testNB, { { $testNB, _String } }, { { $testNB2, $testNB, Wolfram`Chatbook`ACP`UI`Private`$acpWindowWidth } }, True },
    SameTest -> MatchQ,
    TestID   -> "ReuseWindow-ChangeDirectory@@Tests/ACPWindow.wlt:3282,1-3303,2"
]

(* The window's width (pure): wider than the Notebook Assistant's, the base width scaled by the magnification, capped so
   that the window fits on its display (less 32 points for the frame and a gap at each edge), at least 240 points; an
   unknown display does not cap it *)
VerificationTest[
    With[ { width = Wolfram`Chatbook`ChatModes`Common`attachedWindowWidth },
        {
            Wolfram`Chatbook`ACP`UI`Private`$acpWindowWidth,
            width[ 480, 1, { 0, 1920 } ],
            width[ 480, 1.25, { 0, 1920 } ],
            width[ 600, 1, { -1440, 0 } ],
            width[ 480, 2, { 0, 800 } ],
            width[ 480, 1, { 0, 400 } ],
            width[ 480, 1, { 0, 100 } ],
            width[ 480, 1.5, None ],
            width[ 480, 1, { 0, 0 } ]
        }
    ],
    { If[ $OperatingSystem === "MacOSX", 600, 480 ], 480, 600, 600, 768, 368, 240, 720, 480 },
    SameTest -> MatchQ,
    TestID   -> "WindowWidth-Pure@@Tests/ACPWindow.wlt:3308,1-3325,2"
]

(* attachToLeft: the two-argument form (the Notebook Assistant's) keeps $workspaceChatWidth, not capped; a width that is
   given (the ACP window's) is scaled with the source notebook's magnification and capped to its display; the window
   stays on the display *)
VerificationTest[
    withACPMocks @ Block[
        {
            AbsoluteCurrentValue = Replace[ { ## }, { { _, Magnification } -> 1.25, _ -> None } ] &,
            CurrentValue = Replace[ { ## }, { { "ConnectedDisplays" } :> { { "FullRegion" -> { { 0, 1000 }, { 0, 800 } } } }, _ -> None } ] &,
            NotebookTools`NotebookDisplayIndex = 1 &,
            Internal`CachedSystemInformation = None &,
            Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`windowMargins = { { 900, Automatic }, { 50, 60 } } &,
            Wolfram`Chatbook`Common`moveToChatInputField = Null &,
            SetSelectedNotebook = Null &
        },
        {
            Wolfram`Chatbook`ChatModes`Common`attachToLeft[ $testNB2, $testNB ],
            Wolfram`Chatbook`ChatModes`Common`attachToLeft[ $testNB2, $testNB, 480 ],
            Wolfram`Chatbook`ChatModes`Common`attachToLeft[ $testNB2, $testNB, 800 ],
            calls[ "SetOptions" ]
        }
    ],
    With[ { na = Ceiling[ Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`$workspaceChatWidth * 1.25 ], m = _? (Abs[ # - 0.85 * 1.25 ] < 10^-6 &) },
        {
            $testNB,
            $testNB,
            $testNB,
            {
                { $testNB, Magnification -> m, WindowMargins -> { { 900 - na, Automatic }, { 50, 60 } }, WindowSize -> { na, Automatic } },
                { $testNB, Magnification -> m, WindowMargins -> { { 300, Automatic }, { 50, 60 } }, WindowSize -> { 600, Automatic } },
                { $testNB, Magnification -> m, WindowMargins -> { { 0, Automatic }, { 50, 60 } }, WindowSize -> { 968, Automatic } }
            }
        }
    ],
    SameTest -> MatchQ,
    TestID   -> "WindowWidth-AttachToLeft@@Tests/ACPWindow.wlt:3330,1-3362,2"
]

VerificationTest[
    withACPMocks[
        Block[
            {
                Wolfram`Chatbook`Common`moveToChatInputField = logCall[ "MoveToInput", ## ] &,
                SetSelectedNotebook = logCall[ "Select", ## ] &
            },
            {
                Wolfram`Chatbook`ACP`UI`Private`acpReuseWindow[ None, $testNB, <| "ProjectDirectory" -> $HomeDirectory |> ],
                calledQ[ "SetProjectDirectory" ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Notice" ],
                calls[ "Select" ]
            }
        ],
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "CurrentTurn" -> "turn-1" ] |> |>
    ],
    { $testNB, False, _String, { { $testNB } } },
    SameTest -> MatchQ,
    TestID   -> "ReuseWindow-Running@@Tests/ACPWindow.wlt:3364,1-3383,2"
]

VerificationTest[
    withACPMocks[
        Block[
            {
                Wolfram`Chatbook`Common`moveToChatInputField = Null &,
                SetSelectedNotebook = Null &
            },
            Wolfram`Chatbook`ACP`UI`Private`acpReuseWindow[ None, $testNB, <| "ACPModel" -> "x/y" |> ];
            calledQ[ "SetProjectDirectory" ]
        ],
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ReuseWindow-SameDirectory@@Tests/ACPWindow.wlt:3385,1-3400,2"
]

(* Explicit agent settings apply to an open window: a window in "Error" (e.g. OpenCode not found) gets the executable
   and reconnects; the settings are also kept in the notebook's TaggingRules (for kernel restarts) *)
VerificationTest[
    withACPMocks[
        Block[ { Wolfram`Chatbook`Common`moveToChatInputField = Null &, SetSelectedNotebook = Null & },
            Wolfram`Chatbook`ACP`UI`Private`acpReuseWindow[
                None,
                $testNB,
                <| "ACPAgentCommandLine" -> "/opt/opencode/bin/opencode", "ACPModel" -> "openai/gpt-6-luna" |>
            ];
            {
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Settings" ],
                $feFlags[ { $testNB, "Settings" } ],
                calls[ "Reconnect" ],
                calledQ[ "EnsureConnected" ]
            }
        ],
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Error", "Error" -> <| "Code" -> "AgentNotFound" |> ] |> |>
    ],
    {
        <| "ACPAgentCommandLine" -> "/opt/opencode/bin/opencode", "ACPModel" -> "openai/gpt-6-luna" |>,
        <| "ACPAgentCommandLine" -> "/opt/opencode/bin/opencode", "ACPModel" -> "openai/gpt-6-luna" |>,
        { { $testNB } },
        False
    },
    SameTest -> MatchQ,
    TestID   -> "ReuseWindow-Settings-ErrorReconnects@@Tests/ACPWindow.wlt:3404,1-3429,2"
]

(* A new model is selected in the current session (and replaces a model chosen in the menu for the next connection) *)
VerificationTest[
    withACPMocks[
        Block[ { Wolfram`Chatbook`Common`moveToChatInputField = Null &, SetSelectedNotebook = Null & },
            Wolfram`Chatbook`ACP`UI`Private`acpReuseWindow[ None, $testNB, <| "ACPModel" -> "openai/gpt-6-luna" |> ];
            {
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "Settings", "UserModel" } ],
                calls[ "SetConfigOption" ],
                calledQ[ "Reconnect" ],
                calledQ[ "EnsureConnected" ]
            }
        ],
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "UserModel" -> "opencode/big-pickle" ] |> |>
    ],
    { { <| "ACPModel" -> "openai/gpt-6-luna" |>, None }, { { $testNB, "model", "openai/gpt-6-luna" } }, False, True },
    SameTest -> MatchQ,
    TestID   -> "ReuseWindow-Settings-Model@@Tests/ACPWindow.wlt:3432,1-3448,2"
]

(* "ACPMCPServer" applies to an open window: the MCP servers are only offered when a session starts, so a change
   reconnects a local window; True, False and Automatic are three values (Automatic offers the server only to the
   agent's own program), and an unchanged value does nothing but make sure the window is connected. A remote window
   never offers the server, so a change only keeps the value (for a later switch to this computer). The setting is
   kept in the TaggingRules. *)
VerificationTest[
    withACPMocks[
        Block[ { Wolfram`Chatbook`Common`moveToChatInputField = Null &, SetSelectedNotebook = Null & },
            Module[ { reconnects },
                reconnects = Function[ { nbo, settings },
                    $callLog = { };
                    Wolfram`Chatbook`ACP`UI`Private`acpReuseWindow[ None, nbo, settings ];
                    { calledQ[ "Reconnect" ], calledQ[ "EnsureConnected" ] }
                ];
                {
                    reconnects[ $testNB, <| "ACPMCPServer" -> True |> ],
                    reconnects[ $testNB, <| "ACPMCPServer" -> False |> ],
                    Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Settings" ],
                    $feFlags[ { $testNB, "Settings" } ],
                    reconnects[ $testNB, <| "ACPMCPServer" -> False |> ],
                    reconnects[ $testNB, <| "ACPMCPServer" -> Automatic |> ],
                    reconnects[ $testNB, <| "ACPMCPServer" -> Automatic |> ],
                    Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Settings" ],
                    reconnects[ $testNB2, <| "ACPMCPServer" -> False |> ],
                    Lookup[ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB2, "Settings" ], "ACPMCPServer" ],
                    $feFlags[ { $testNB2, "Settings" } ][ "ACPMCPServer" ]
                }
            ]
        ],
        <|
            "Windows" -> <|
                $testNB  -> testWindow @ $testNB,
                $testNB2 -> testWindow[
                    $testNB2,
                    "Settings"         -> <| "SSHSettings" -> <| "MachineName" -> "devbox", "Username" -> "u", "Arguments" -> { }, "Executable" -> Automatic |> |>,
                    "ProjectDirectory" -> "/home/u/p",
                    "RemoteHome"       -> "/home/u"
                ]
            |>
        |>
    ],
    {
        { True, False },
        { True, False },
        <| "ACPMCPServer" -> False |>,
        <| "ACPMCPServer" -> False |>,
        { False, True },
        { True, False },
        { False, True },
        <| "ACPMCPServer" -> Automatic |>,
        { False, True },
        False,
        False
    },
    SameTest -> MatchQ,
    TestID   -> "ReuseWindow-Settings-MCPServer@@Tests/ACPWindow.wlt:3455,1-3506,2"
]

(* While a turn runs, a new executable is applied after the turn (housekeeping reconnects) *)
VerificationTest[
    withACPMocks[
        Block[ { Wolfram`Chatbook`Common`moveToChatInputField = Null &, SetSelectedNotebook = Null & },
            Module[ { during },
                Wolfram`Chatbook`ACP`UI`Private`acpReuseWindow[ None, $testNB, <| "ACPAgentCommandLine" -> "/opt/oc" |> ];
                during = { calledQ[ "Reconnect" ], Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "ReconnectRequested", "Notice" } ] };
                Wolfram`Chatbook`ACP`UI`Private`acpUIHousekeeping[ ];
                Wolfram`Chatbook`ACP`Common`acpWindowSet[ $testNB, <| "CurrentTurn" -> None, "Status" -> "Ready" |> ];
                Wolfram`Chatbook`ACP`UI`Private`acpUIHousekeeping[ ];
                { during, calls[ "Reconnect" ], Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "ReconnectRequested" ] }
            ]
        ],
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |> |>
    ],
    { { False, { True, _String } }, { { $testNB } }, False },
    SameTest -> MatchQ,
    TestID   -> "ReuseWindow-Settings-WhileRunning@@Tests/ACPWindow.wlt:3509,1-3526,2"
]

(* "Locate OpenCode..." (file chooser): the chosen file becomes the window's executable and the window reconnects *)
VerificationTest[
    withACPMocks[
        Module[ { file = Export[ FileNameJoin @ { $TemporaryDirectory, "acp-test-opencode-" <> CreateUUID[ ] }, "#!/bin/sh\n", "Text" ], result },
            result = {
                Wolfram`Chatbook`Common`acpAction[ "SetAgentExecutable", $testNB, FileNameJoin @ { $TemporaryDirectory, "acp-no-such-file" } ],
                StringQ @ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Notice" ],
                calledQ[ "Reconnect" ],
                Wolfram`Chatbook`Common`acpAction[ "SetAgentExecutable", $testNB, File @ file ] === file,
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "Settings", "Notice" } ] === { <| "ACPAgentCommandLine" -> file |>, None },
                $feFlags[ { $testNB, "Settings" } ] === <| "ACPAgentCommandLine" -> file |>,
                calls[ "Reconnect" ]
            };
            DeleteFile @ file;
            result
        ],
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Error" ] |> |>
    ],
    { Null, True, False, True, True, True, { { $testNB } } },
    SameTest -> MatchQ,
    TestID   -> "SetAgentExecutable@@Tests/ACPWindow.wlt:3529,1-3549,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Remote windows*)
VerificationTest[
    (* Canonical "SSHSettings" (as ShowNotebookAssistance passes them on) and a remote window record *)
    $acpTestSSH = <| "MachineName" -> "devbox", "Username" -> "u", "Arguments" -> { }, "Executable" -> Automatic |>;
    remoteWindow // ClearAll;
    remoteWindow[ nbo_, rules___ ] := testWindow[
        nbo,
        "Settings"         -> <| "SSHSettings" -> $acpTestSSH |>,
        "ProjectDirectory" -> "/home/u/p",
        "RemoteHome"       -> "/home/u",
        rules
    ];
    (* Evaluates eval with any DirectoryQ or ExpandFileName of a path starting with one of prefixes recorded in
       $localPathCalls (and not done) *)
    withLocalPathTrap // ClearAll;
    withLocalPathTrap // Attributes = { HoldRest };
    withLocalPathTrap[ prefixes_, eval_ ] := Internal`InheritedBlock[ { DirectoryQ, ExpandFileName },
        Unprotect[ DirectoryQ, ExpandFileName ];
        DirectoryQ[ p_String ] /; StringStartsQ[ p, prefixes ] := (AppendTo[ $localPathCalls, { "DirectoryQ", p } ]; False);
        ExpandFileName[ p_String ] /; StringStartsQ[ p, prefixes ] := (AppendTo[ $localPathCalls, { "ExpandFileName", p } ]; p);
        eval
    ];
    $localPathCalls = { };
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-RemoteDefinitions@@Tests/ACPWindow.wlt:3554,1-3580,2"
]

(* "SSHSettings" is kept in the TaggingRules: a window rebuilt after a kernel restart is remote again, with its folder
   checked as a remote path only (never on this computer); a ~ folder stays one (the launch resolves it), and
   "RemoteHome" comes from the host's persisted home. $FrontEnd = Null: the persisted settings are the headless ones
   also when the tests run under a front end (CI). *)
VerificationTest[
    $localPathCalls = { };
    {
        Wolfram`Chatbook`ACP`UI`Private`$acpPersistedSettingNames,
        withLocalPathTrap[
            "~" | "/home/u",
            Function[ home,
                Block[ { $FrontEnd = Null, Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings = home },
                    KeyTake[
                        withACPMocks[
                            Wolfram`Chatbook`ACP`Common`acpEnsureWindowRecord @ $testNB,
                            <| "FE" -> <|
                                { $testNB, "ProjectDirectory" } -> "~/x",
                                { $testNB, "Settings" } -> <| "SSHSettings" -> $acpTestSSH, "ACPModel" -> "a/b", "Other" -> 1 |>
                            |> |>
                        ],
                        { "Status", "ProjectDirectory", "Settings", "RemoteHome", "RemoteVerified" }
                    ]
                ]
            ] /@ { <| |>, <| { "SSH", "u@devbox", "Home" } -> "/home/u" |> }
        ],
        $localPathCalls
    },
    {
        { "ACPAgent", "ACPAgentCommandLine", "ACPMCPServer", "ACPModel", "SSHSettings" },
        {
            <|
                "Status"           -> "Disconnected",
                "ProjectDirectory" -> "~/x",
                "Settings"         -> <| "ACPModel" -> "a/b", "SSHSettings" -> $acpTestSSH |>,
                "RemoteHome"       -> None,
                "RemoteVerified"   -> False
            |>,
            <|
                "Status"           -> "Disconnected",
                "ProjectDirectory" -> "~/x",
                "Settings"         -> <| "ACPModel" -> "a/b", "SSHSettings" -> $acpTestSSH |>,
                "RemoteHome"       -> "/home/u",
                "RemoteVerified"   -> False
            |>
        },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-PersistedSettingNames@@Tests/ACPWindow.wlt:3586,1-3631,2"
]

(* A remote folder stored in the TaggingRules was normalized when it was set: the rebuilt record keeps it exactly (a
   folder name may end in a space, e.g. one chosen in the folder picker), apart from a trailing "/"; a local folder is
   normalized as before *)
VerificationTest[
    $localPathCalls = { };
    {
        withLocalPathTrap[
            "~" | "/srv" | "/home/u",
            Block[ { $FrontEnd = Null, Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings = <| { "SSH", "u@devbox", "Home" } -> "/home/u" |> },
                Function[ dir,
                    Lookup[
                        withACPMocks[
                            Wolfram`Chatbook`ACP`Common`acpEnsureWindowRecord @ $testNB,
                            <| "FE" -> <|
                                { $testNB, "ProjectDirectory" } -> dir,
                                { $testNB, "Settings" } -> <| "SSHSettings" -> $acpTestSSH |>
                            |> |>
                        ],
                        { "ProjectDirectory", "Status" }
                    ]
                ] /@ { "/srv/data ", "/srv/data/", File[ "/srv/f " ], "~/x " }
            ]
        ],
        $localPathCalls,
        Lookup[
            withACPMocks[
                Wolfram`Chatbook`ACP`Common`acpEnsureWindowRecord @ $testNB,
                <| "FE" -> <| { $testNB, "ProjectDirectory" } -> " " <> $TemporaryDirectory <> " " |> |>
            ],
            "ProjectDirectory"
        ] === ExpandFileName @ $TemporaryDirectory
    },
    {
        {
            { "/srv/data ", "Disconnected" },
            { "/srv/data", "Disconnected" },
            { "/srv/f ", "Disconnected" },
            { "~/x ", "Disconnected" }
        },
        { },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-RebuildRemoteFolderRaw@@Tests/ACPWindow.wlt:3636,1-3677,2"
]

(* Settings are compared in their normal form: "u@devbox", rules and the canonical form are the same; None is the same
   as no "SSHSettings"; the canonical form is stored (record and TaggingRules) *)
VerificationTest[
    withACPMocks[
        {
            Wolfram`Chatbook`ACP`UI`Private`acpMergeWindowSettings[ $testNB, <| "SSHSettings" -> "u@devbox" |> ],
            Wolfram`Chatbook`ACP`UI`Private`acpMergeWindowSettings[ $testNB, <| "SSHSettings" -> { "MachineName" -> "devbox", "Username" -> "u" } |> ],
            Wolfram`Chatbook`ACP`UI`Private`acpMergeWindowSettings[ $testNB2, <| "SSHSettings" -> None |> ],
            Wolfram`Chatbook`ACP`UI`Private`acpMergeWindowSettings[ $testNB, <| "SSHSettings" -> " u@devbox ", "ACPModel" -> "x/y" |> ],
            Wolfram`Chatbook`ACP`UI`Private`acpMergeWindowSettings[ $testNB, <| "SSHSettings" -> <| "MachineName" -> "devbox", "Username" -> "u", "Arguments" -> { "-p", "2222" } |> |> ],
            Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Settings" ],
            $feFlags[ { $testNB, "Settings" } ]
        },
        <| "Windows" -> <| $testNB -> remoteWindow @ $testNB, $testNB2 -> testWindow @ $testNB2 |> |>
    ],
    {
        { },
        { },
        { },
        { "ACPModel" },
        { "SSHSettings" },
        <| "SSHSettings" -> <| $acpTestSSH, "Arguments" -> { "-p", "2222" } |>, "ACPModel" -> "x/y" |>,
        <| "ACPModel" -> "x/y", "SSHSettings" -> <| $acpTestSSH, "Arguments" -> { "-p", "2222" } |> |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-MergeNormalForm@@Tests/ACPWindow.wlt:3681,1-3705,2"
]

(* Another host is refused while the agent works or a session loads: "SSHSettings", "ProjectDirectory" and
   "ACPAgentCommandLine" of the call are dropped, with a notice *)
VerificationTest[
    withACPMocks[
        Block[ { Wolfram`Chatbook`Common`moveToChatInputField = Null &, SetSelectedNotebook = Null & },
            Module[ { settings },
                settings = <|
                    "SSHSettings"         -> <| "MachineName" -> "otherbox", "Username" -> Automatic, "Arguments" -> { }, "Executable" -> Automatic |>,
                    "ProjectDirectory"    -> "/srv/p",
                    "ACPAgentCommandLine" -> "/opt/oc"
                |>;
                Wolfram`Chatbook`ACP`UI`Private`acpReuseWindow[ None, #, settings ] & /@ { $testNB, $testNB2 };
                {
                    Wolfram`Chatbook`ACP`Common`acpWindowGet[ #, { "Settings", "ProjectDirectory", "Notice" } ] & /@ { $testNB, $testNB2 },
                    calledQ /@ { "SetProjectDirectory", "Disconnect", "Reconnect" }
                }
            ]
        ],
        <| "Windows" -> <|
            $testNB  -> remoteWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ],
            $testNB2 -> remoteWindow[ $testNB2, "Status" -> "Restoring", "Restore" -> <| "Stage" -> "Loading" |> ]
        |> |>
    ],
    {
        {
            { <| "SSHSettings" -> $acpTestSSH |>, "/home/u/p", "The SSH settings can't be changed while the agent is working." },
            { <| "SSHSettings" -> $acpTestSSH |>, "/home/u/p", "The SSH settings can't be changed while a session is loading." }
        },
        { False, False, False }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-ReuseHostSwitchRefusedWhileRunning@@Tests/ACPWindow.wlt:3709,1-3739,2"
]

(* An explicit folder that can't be used is ignored with a notice (both modes): a local folder that doesn't exist, a
   remote one that is not an absolute or ~/ path; remote folders are normalized for the host (~ with its home) *)
VerificationTest[
    $localPathCalls = { };
    withACPMocks[
        Block[ { Wolfram`Chatbook`Common`moveToChatInputField = Null &, SetSelectedNotebook = Null & },
            Module[ { missing },
                missing = FileNameJoin @ { $TemporaryDirectory, "acp-no-such-folder-" <> CreateUUID[ ] };
                Wolfram`Chatbook`ACP`UI`Private`acpReuseWindow[ None, $testNB, <| "ProjectDirectory" -> missing |> ];
                {
                    calledQ[ "SetProjectDirectory" ],
                    StringStartsQ[ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Notice" ], "The folder " ] &&
                        StringEndsQ[ Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Notice" ], " doesn't exist." ],
                    withLocalPathTrap[
                        "~" | "/home/u" | "/srv" | "C:",
                        KeyTake[
                            Wolfram`Chatbook`ACP`UI`Private`acpReusePlan[ None, remoteWindow @ $testNB2, <| "ProjectDirectory" -> # |> ],
                            { "Switch", "Directory", "Notices" }
                        ] & /@ { "C:\\x", "~/y", "/srv/z/", File[ " /srv/w " ] }
                    ],
                    $localPathCalls
                }
            ]
        ],
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    {
        False,
        True,
        {
            <| "Switch" -> False, "Directory" -> None, "Notices" -> { "C:\\x is not a folder path on u@devbox: it must start with / or ~/." } |>,
            <| "Switch" -> False, "Directory" -> "/home/u/y", "Notices" -> { } |>,
            <| "Switch" -> False, "Directory" -> "/srv/z", "Notices" -> { } |>,
            <| "Switch" -> False, "Directory" -> "/srv/w", "Notices" -> { } |>
        },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-ExplicitFolderMissing@@Tests/ACPWindow.wlt:3743,1-3780,2"
]

(* Host switches: the new host's last folder (or none); an explicit ~ folder is kept as given (the launch resolves it:
   the home persisted for the host may be another machine's); the folder of a host that was never reached is kept; a
   command line is reset (with a notice) unless the call gives one. $FrontEnd = Null: the persisted settings are the
   headless ones also when the tests run under a front end (CI). *)
VerificationTest[
    Block[
        {
            $FrontEnd = Null,
            Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings = <|
                { "SSH", "u@devbox", "LastProjectDirectory" } -> "/home/u/last",
                { "SSH", "u@devbox", "Home" }                 -> "/home/u"
            |>
        },
        withACPMocks[
            KeyTake[ #, { "Switch", "Directory", "Notices", "Settings" } ] & /@ {
                (* local -> remote *)
                Wolfram`Chatbook`ACP`UI`Private`acpReusePlan[
                    None,
                    testWindow[ $testNB, "Settings" -> <| "ACPAgentCommandLine" -> "/opt/oc" |> ],
                    <| "SSHSettings" -> $acpTestSSH |>
                ],
                (* local -> remote with a folder and a command line *)
                Wolfram`Chatbook`ACP`UI`Private`acpReusePlan[
                    None,
                    testWindow @ $testNB,
                    <| "SSHSettings" -> "u@devbox", "ProjectDirectory" -> "~/q", "ACPAgentCommandLine" -> { "~/oc", "acp" } |>
                ],
                (* remote, never reached -> another host: the folder is kept *)
                Wolfram`Chatbook`ACP`UI`Private`acpReusePlan[
                    None,
                    remoteWindow[ $testNB, "Settings" -> <| "SSHSettings" -> <| $acpTestSSH, "MachineName" -> "devbx" |> |> ],
                    <| "SSHSettings" -> $acpTestSSH |>
                ],
                (* remote, reached -> another host without a persisted folder *)
                Wolfram`Chatbook`ACP`UI`Private`acpReusePlan[
                    None,
                    remoteWindow[ $testNB, "RemoteVerified" -> True ],
                    <| "SSHSettings" -> "otherbox" |>
                ],
                (* the same host with other Arguments is no switch *)
                Wolfram`Chatbook`ACP`UI`Private`acpReusePlan[
                    None,
                    remoteWindow @ $testNB,
                    <| "SSHSettings" -> <| $acpTestSSH, "Arguments" -> { "-i", "k.pem" } |> |>
                ]
            }
        ]
    ],
    {
        <|
            "Switch"    -> True,
            "Directory" -> "/home/u/last",
            "Notices"   -> { "The \"ACPAgentCommandLine\" setting was for another computer, so it is no longer used." },
            "Settings"  -> <| "SSHSettings" -> $acpTestSSH, "ACPAgentCommandLine" -> Automatic |>
        |>,
        <|
            "Switch"    -> True,
            "Directory" -> "~/q",
            "Notices"   -> { },
            "Settings"  -> <| "SSHSettings" -> "u@devbox", "ProjectDirectory" -> "~/q", "ACPAgentCommandLine" -> { "~/oc", "acp" } |>
        |>,
        <| "Switch" -> True, "Directory" -> "/home/u/p", "Notices" -> { }, "Settings" -> <| "SSHSettings" -> $acpTestSSH, "ACPAgentCommandLine" -> Automatic |> |>,
        <| "Switch" -> True, "Directory" -> None, "Notices" -> { }, "Settings" -> <| "SSHSettings" -> "otherbox", "ACPAgentCommandLine" -> Automatic |> |>,
        <| "Switch" -> False, "Directory" -> None, "Notices" -> { }, "Settings" -> <| "SSHSettings" -> <| $acpTestSSH, "Arguments" -> { "-i", "k.pem" } |> |> |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-ReusePlan-HostSwitch@@Tests/ACPWindow.wlt:3786,1-3849,2"
]

(* The explicit folder of a new remote window: a ~ folder is kept as given, also when a home is persisted for the host
   (it may be another machine's: an alias moved to a new machine); the record's "RemoteHome" is the persisted one, only
   for display, until a launch reports the real one (Connection.wl) *)
VerificationTest[
    $localPathCalls = { };
    {
        withLocalPathTrap[
            "~" | "/home/u" | "/srv",
            Block[
                { $FrontEnd = Null, Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings = <| { "SSH", "u@devbox", "Home" } -> "/home/stale" |> },
                {
                    Wolfram`Chatbook`ACP`UI`Private`acpDefaultProjectDirectory[ None, <| "SSHSettings" -> $acpTestSSH, "ProjectDirectory" -> # |> ] & /@ {
                        "~/proj", "~", " ~/a b/ ", File[ "/srv/x/" ]
                    },
                    Lookup[
                        Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ $testNB, "~/proj", "OpenCode", <| "SSHSettings" -> $acpTestSSH |> ],
                        { "ProjectDirectory", "RemoteHome", "Status" }
                    ]
                }
            ]
        ],
        $localPathCalls
    },
    { { { "~/proj", "~", "~/a b", "/srv/x" }, { "~/proj", "/home/stale", "Connecting" } }, { } },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-RemoteDefaultFolderKeepsTilde@@Tests/ACPWindow.wlt:3854,1-3877,2"
]

(* The same host: a ~ folder is expanded with the window's own home only (never with the persisted one), and the
   window's folder in its other form (~/p for /home/u/p, or the other way round) is no change, so no reconnect *)
VerificationTest[
    $localPathCalls = { };
    {
        withLocalPathTrap[
            "~" | "/home/u",
            Block[
                { $FrontEnd = Null, Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings = <| { "SSH", "u@devbox", "Home" } -> "/home/stale" |> },
                {
                    Lookup[
                        Wolfram`Chatbook`ACP`UI`Private`acpReusePlan[ None, remoteWindow[ $testNB, "ProjectDirectory" -> "~/p" ], <| "ProjectDirectory" -> # |> ],
                        { "Switch", "Directory" }
                    ] & /@ { "~/p", "/home/u/p", "~/p/", "~/q" },
                    Lookup[
                        Wolfram`Chatbook`ACP`UI`Private`acpReusePlan[ None, remoteWindow @ $testNB, <| "ProjectDirectory" -> # |> ],
                        "Directory"
                    ] & /@ { "~/p", "~" },
                    (* a window without a known home: ~ folders stay as given *)
                    Lookup[
                        Wolfram`Chatbook`ACP`UI`Private`acpReusePlan[
                            None,
                            remoteWindow[ $testNB, "ProjectDirectory" -> "~/p", "RemoteHome" -> None ],
                            <| "ProjectDirectory" -> # |>
                        ],
                        "Directory"
                    ] & /@ { "~/p", "~/q", "/home/u/p" }
                }
            ]
        ],
        $localPathCalls,
        (* the same folder given again does not change (reconnect) the window *)
        withACPMocks[
            Block[ { Wolfram`Chatbook`Common`moveToChatInputField = Null &, SetSelectedNotebook = Null & },
                Wolfram`Chatbook`ACP`UI`Private`acpReuseWindow[ None, $testNB, <| "ProjectDirectory" -> "/home/u/p" |> ];
                { calledQ[ "SetProjectDirectory" ], Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "ProjectDirectory" ] }
            ],
            <| "Windows" -> <| $testNB -> remoteWindow[ $testNB, "ProjectDirectory" -> "~/p" ] |> |>
        ]
    },
    {
        {
            { { False, "~/p" }, { False, "~/p" }, { False, "~/p" }, { False, "/home/u/q" } },
            { "/home/u/p", "/home/u" },
            { "~/p", "~/q", "/home/u/p" }
        },
        { },
        { False, "~/p" }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-ReusePlan-TildeFolder@@Tests/ACPWindow.wlt:3881,1-3930,2"
]

(* "Locate OpenCode..." has nothing to locate for a remote window: a notice says what to do on the host instead *)
VerificationTest[
    withACPMocks[
        Module[ { file = Export[ FileNameJoin @ { $TemporaryDirectory, "acp-test-opencode-" <> CreateUUID[ ] }, "#!/bin/sh\n", "Text" ], result },
            result = {
                Wolfram`Chatbook`ACP`UI`Private`acpErrorAction[ $testNB, "LocateAgent" ];
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Notice" ],
                Wolfram`Chatbook`Common`acpAction[ "SetAgentExecutable", $testNB, File @ file ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Settings" ],
                calledQ[ "Reconnect" ],
                Wolfram`Chatbook`ACP`UI`Private`acpErrorAction[ $testNB2, "LocateAgent" ];
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB2, "Notice" ]
            };
            DeleteFile @ file;
            result
        ],
        <| "Windows" -> <| $testNB -> remoteWindow[ $testNB, "Status" -> "Error" ], $testNB2 -> testWindow[ $testNB2, "Status" -> "Error" ] |> |>
    ],
    {
        "Install OpenCode on u@devbox (https://opencode.ai), or give its command line on u@devbox with the \"ACPAgentCommandLine\" setting, then reconnect.",
        Null,
        <| "SSHSettings" -> $acpTestSSH |>,
        False,
        "Install OpenCode (https://opencode.ai) or give its command line with the \"ACPAgentCommandLine\" setting, then reconnect."
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-LocateAgentRemote@@Tests/ACPWindow.wlt:3933,1-3959,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Remote windows: views*)
VerificationTest[
    (* Box strings and the ACP actions (ChatbookAction[ "ACP", action, $testNB ]) of rendered boxes; the toolbar status
       view rendered with the real labels *)
    boxTexts // ClearAll;
    boxTexts[ boxes_ ] := Select[ Cases[ boxes, s_String :> StringTrim[ s, "\"" ], Infinity ], StringLength[ # ] > 2 & ];
    boxActions // ClearAll;
    boxActions[ boxes_ ] := With[ { nb = $testNB }, Cases[ boxes, HoldPattern @ ChatbookAction[ "ACP", a_String, nb ] :> a, Infinity ] ];
    statusBoxes // ClearAll;
    statusBoxes[ w_ ] := Block[
        { Wolfram`Chatbook`ACP`Common`$acpWindows = <| $testNB -> w |>, Wolfram`Chatbook`ACP`Transcript`Private`$acpNoFrontEndLabels = True },
        First @ Wolfram`Chatbook`ACP`Rendering`Private`statusContent @ $testNB
    ];
    $acpTestRemoteError = <|
        "Code"    -> "SSHConnectionLost",
        "Message" -> "The connection to u@devbox was lost.",
        "Hint"    -> None,
        "Output"  -> "Timeout, server devbox not responding.",
        "Detail"  -> "Timeout, server devbox not responding.",
        "Actions" -> { "Reconnect" }
    |>;
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-RemoteViewDefinitions@@Tests/ACPWindow.wlt:3964,1-3988,2"
]

(* The toolbar status line of a remote window names the host; "Disconnected" after an error shows the error with one
   "Reconnect"; no "Locate OpenCode..." for a remote window; the status view's signature has the host key and the open
   state of the error details *)
VerificationTest[
    Module[ { info, remote, local, texts, signature },
        info   = "AgentInfo" -> <| "Name" -> "OpenCode", "Version" -> "1.2.3" |>;
        remote = remoteWindow[ $testNB, info ];
        local  = testWindow[ $testNB, info ];
        texts  = boxTexts @* statusBoxes;
        signature[ w_ ] := Block[ { Wolfram`Chatbook`ACP`Common`$acpWindows = <| $testNB -> w |> }, Wolfram`Chatbook`ACP`Rendering`Private`statusSignature @ $testNB ];
        {
            MemberQ[ texts @ <| remote, "Status" -> "Connecting" |>, "Connecting to OpenCode on devbox\[Ellipsis]" ],
            MemberQ[ texts @ <| remote, "Status" -> "Ready" |>, "OpenCode 1.2.3 on devbox" ],
            MemberQ[ texts @ <| remote, "Status" -> "Running" |>, "OpenCode 1.2.3 on devbox" ],
            MemberQ[ texts @ <| remote, "Status" -> "Ready", "AgentInfo" -> <| "Name" -> "OpenCode" |> |>, "OpenCode on devbox" ],
            MemberQ[ texts @ <| local, "Status" -> "Ready" |>, "OpenCode 1.2.3" ],
            MemberQ[ texts @ <| local, "Status" -> "Connecting" |>, "Connecting to OpenCode\[Ellipsis]" ],
            (* disconnected by an error: the error and "Reconnect" (once), not just "Disconnected" *)
            With[ { b = statusBoxes @ <| remote, "Status" -> "Disconnected", "Error" -> $acpTestRemoteError |> },
                {
                    MemberQ[ boxTexts @ b, "The connection to u@devbox was lost." ],
                    MemberQ[ boxTexts @ b, "Timeout, server devbox not responding." ],
                    MemberQ[ boxTexts @ b, "Disconnected" ],
                    boxActions @ b
                }
            ],
            boxActions @ statusBoxes @ <| remote, "Status" -> "Disconnected", "Error" -> <| "Code" -> "AgentExited", "Message" -> "Stopped.", "Actions" -> { } |> |>,
            With[ { b = statusBoxes @ <| remote, "Status" -> "Disconnected" |> }, { MemberQ[ boxTexts @ b, "Disconnected" ], boxActions @ b } ],
            (* "Locate OpenCode..." (a file chooser that runs SetAgentExecutable) only for local windows *)
            Function[ w,
                AnyTrue[
                    Cases[
                        statusBoxes @ <| w, "Status" -> "Error", "Error" -> <| "Code" -> "AgentNotFound", "Message" -> "Not found.", "Actions" -> { "LocateAgent", "Reconnect" } |> |>,
                        s_String :> s,
                        Infinity
                    ],
                    StringContainsQ[ "SetAgentExecutable" ]
                ]
            ] /@ { local, remote },
            (* the signature: the host, and the open state of the details *)
            signature @ <| remote, "Status" -> "Ready" |> =!= signature @ <| local, "Status" -> "Ready" |>,
            signature @ <| remote, "Status" -> "Error", "Error" -> $acpTestRemoteError |> =!=
                signature @ <| remote, "Status" -> "Error", "Error" -> $acpTestRemoteError, "ErrorDetailOpen" -> Wolfram`Chatbook`ACP`Common`acpErrorKey @ $acpTestRemoteError |>,
            (* a turn update (only the window's turn state changes) does not change it *)
            signature @ <| remote, "Status" -> "Running" |> === signature @ <| remote, "Status" -> "Running", "CurrentTurn" -> "t1", "LastActivity" -> 1 |>
        }
    ],
    {
        True, True, True, True, True, True,
        { True, True, False, { "Reconnect" } },
        { "Reconnect" },
        { True, { "Reconnect" } },
        { True, False },
        True, True, True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-StatusView-Remote@@Tests/ACPWindow.wlt:3993,1-4047,2"
]

(* "Details" opens the hint and the output of the window's error (the window's "ErrorDetailOpen" is its key), again
   closes them; a new error starts closed; "Copy" copies what the details show; a window without an error has nothing to
   open *)
VerificationTest[
    $acpTestDetailError = <| $acpTestRemoteError, "Hint" -> "Check the network.", "Detail" -> "Check the network.\n\nTimeout, server devbox not responding." |>;
    Module[ { results, copied, records, current },
        (* the actions, with the window records after each step (rendered below with the real labels) *)
        { results, copied, records } = withACPMocks[
            Module[ { log = { }, out, recs = { } },
                current := Wolfram`Chatbook`ACP`Common`acpWindowGet @ $testNB;
                Block[ { CopyToClipboard = (AppendTo[ log, # ]; Null) & },
                    out = {
                        Wolfram`Chatbook`Common`acpAction[ "ToggleErrorDetail", $testNB ] === Wolfram`Chatbook`ACP`Common`acpErrorKey @ $acpTestDetailError,
                        Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "ErrorDetailOpen" ] === Wolfram`Chatbook`ACP`Common`acpErrorKey @ $acpTestDetailError,
                        AppendTo[ recs, current ];
                        Wolfram`Chatbook`Common`acpAction[ "CopyErrorDetail", $testNB ],
                        Wolfram`Chatbook`Common`acpAction[ "ToggleErrorDetail", $testNB ],
                        AppendTo[ recs, current ];
                        (* open, then another error: closed *)
                        Wolfram`Chatbook`Common`acpAction[ "ToggleErrorDetail", $testNB ];
                        Wolfram`Chatbook`ACP`Common`acpWindowSet[ $testNB, "Error", <| $acpTestDetailError, "Output" -> "Connection reset." |> ];
                        AppendTo[ recs, current ];
                        (* no error: nothing to open or copy *)
                        Wolfram`Chatbook`Common`acpAction[ "ToggleErrorDetail", $testNB2 ],
                        Wolfram`Chatbook`Common`acpAction[ "CopyErrorDetail", $testNB2 ]
                    }
                ];
                { out, log, recs }
            ],
            <| "Windows" -> <|
                $testNB  -> remoteWindow[ $testNB, "Status" -> "Error", "Error" -> $acpTestDetailError ],
                $testNB2 -> testWindow[ $testNB2 ]
            |> |>
        ];
        {
            results,
            copied,
            (* open: the hint, "Copy" and "Hide details"; closed: the last line and "Details"; a new error: closed *)
            With[ { b = statusBoxes @ records[[ 1 ]] },
                { AnyTrue[ boxTexts @ b, StringContainsQ[ "Check the network." ] ], boxActions @ b, MemberQ[ boxTexts @ b, "Hide details" ] }
            ],
            With[ { b = statusBoxes @ records[[ 2 ]] },
                {
                    MemberQ[ boxTexts @ b, "Timeout, server devbox not responding." ],
                    AnyTrue[ boxTexts @ b, StringContainsQ[ "Check the network." ] ],
                    boxActions @ b,
                    MemberQ[ boxTexts @ b, "Details" ]
                }
            ],
            boxActions @ statusBoxes @ records[[ 3 ]]
        }
    ],
    {
        { True, True, "Check the network.\n\nTimeout, server devbox not responding.", None, None, None },
        { "Check the network.\n\nTimeout, server devbox not responding." },
        { True, { "CopyErrorDetail", "Reconnect", "ToggleErrorDetail" }, True },
        { True, False, { "Reconnect", "ToggleErrorDetail" }, True },
        { "Reconnect", "ToggleErrorDetail" }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-ErrorDetailToggle@@Tests/ACPWindow.wlt:4052,1-4110,2"
]

(* "Choose folder..." of a remote window opens the remote folder picker (FolderPicker.wl) and clears the host's failure
   latch (a user action); a local window gets a notice. The new actions are in the action table. *)
VerificationTest[
    withACPMocks[
        Module[ { results },
            Block[
                {
                    Wolfram`Chatbook`ACP`Common`acpFolderPickerOpen = (logCall[ "PickerOpen", ## ]; "Opened") &,
                    Wolfram`Chatbook`ACP`Common`$acpRemoteHostErrors = <| "u@devbox" -> <| "Error" -> <| "Code" -> "SSHAuthFailed" |>, "At" -> 0 |> |>
                },
                results = {
                    Wolfram`Chatbook`Common`acpAction[ "ChooseDirectory", $testNB ],
                    Wolfram`Chatbook`ACP`Common`$acpRemoteHostErrors,
                    Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Notice" ],
                    Wolfram`Chatbook`Common`acpAction[ "ErrorAction", $testNB, "ChooseDirectory" ],
                    Wolfram`Chatbook`Common`acpAction[ "ChooseDirectory", $testNB2 ],
                    Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB2, "Notice" ],
                    calls[ "PickerOpen" ]
                }
            ];
            results
        ],
        <| "Windows" -> <| $testNB -> remoteWindow[ $testNB, "Status" -> "Error" ], $testNB2 -> testWindow[ $testNB2, "Status" -> "NoDirectory" ] |> |>
    ],
    {
        "Opened",
        <| |>,
        None,
        "Opened",
        Null,
        "Choose a project folder first.",
        { { $testNB }, { $testNB } }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-Actions@@Tests/ACPWindow.wlt:4114,1-4147,2"
]

VerificationTest[
    SubsetQ[
        Wolfram`Chatbook`ACP`UI`Private`$acpActionNames,
        { "ChooseDirectory", "CopyErrorDetail", "CopyNoticeCommand", "FolderPickerCopyCommand", "FolderPickerCopyError", "ToggleErrorDetail" }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-Actions-Names@@Tests/ACPWindow.wlt:4149,1-4157,2"
]

(* The folder row of a remote window: host:path with the remote home abbreviated (the whole path and the host in the
   tooltip), the folder runs "ChooseDirectory" (the remote picker) instead of the front end's directory dialog,
   warnings for the remote home, the root and a missing folder; nothing looked at on this computer *)
VerificationTest[
    withACPMocks[
        Module[ { row, sig, texts, results },
            row   = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ $testNB, # ] &;
            sig   = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowSignature;
            texts = viewTexts;
            $localPathCalls = { };
            results = withLocalPathTrap[ { "/home/u", "/srv" }, {
                With[ { v = row @ remoteWindow[ $testNB ] },
                    {
                        MemberQ[ texts @ v, "devbox:" ],
                        MemberQ[ texts @ v, "~/p" ],
                        MemberQ[ texts @ v, "Project folder on u@devbox: /home/u/p" ],
                        Length @ Cases[ v, _FileNameSetter, Infinity ],
                        ! FreeQ[ v, HoldPattern[ _[ "ACP", "ChooseDirectory", _NotebookObject ] ] ],
                        MemberQ[ Cases[ v, HoldPattern[ BoxID -> id_ ] :> id, Infinity ], "ACPChooseDirectory" ],
                        FreeQ[ v, Wolfram`Chatbook`ACP`UI`Private`$acpWarningIcon ],
                        (* the label is the button (at its natural width), with the tooltip outside it *)
                        DeleteDuplicates @ folderLabelTexts @ Cases[ v, Button[ a_, ___ ] :> a, Infinity ],
                        Cases[ v, Button[ ___, ImageSize -> s_, ___ ] :> s, Infinity ],
                        Cases[ v, Tooltip[ _Button, t_ ] :> Last @ viewTexts @ t, Infinity ]
                    }
                ],
                (* disabled while the agent works *)
                MemberQ[ Cases[ row @ remoteWindow[ $testNB, "CurrentTurn" -> "t1", "Status" -> "Running" ], HoldPattern[ Enabled -> e_ ] :> e, Infinity ], False ],
                (* warnings: the remote home, the root, a missing folder (from the launch's error) *)
                Wolfram`Chatbook`ACP`UI`Private`acpDirectoryWarning[ "/home/u", remoteWindow[ $testNB ] ],
                Wolfram`Chatbook`ACP`UI`Private`acpDirectoryWarning[ "/home/u/", remoteWindow[ $testNB ] ],
                Wolfram`Chatbook`ACP`UI`Private`acpDirectoryWarning[ "/", remoteWindow[ $testNB ] ],
                Wolfram`Chatbook`ACP`UI`Private`acpDirectoryWarning[ "/srv/gone", remoteWindow[ $testNB, "Error" -> <| "Code" -> "RemoteFolderMissing" |> ] ],
                Wolfram`Chatbook`ACP`UI`Private`acpDirectoryWarning[ "/srv/app", remoteWindow[ $testNB ] ],
                (* no folder *)
                MemberQ[ texts @ row @ remoteWindow[ $testNB, "ProjectDirectory" -> None ], "No project folder on devbox" ],
                (* invalid stored settings: host "?" and no way to choose a folder *)
                With[ { v = row @ remoteWindow[ $testNB, "Settings" -> <| "SSHSettings" -> <| "MachineName" -> "-bad" |> |> ] },
                    { MemberQ[ texts @ v, "?:" ], FreeQ[ v, _FileNameSetter | HoldPattern[ _[ "ACP", "ChooseDirectory", _ ] ] ] }
                ],
                (* the signature follows the host, the remote home and the error *)
                Length @ DeleteDuplicates[ sig /@ {
                    remoteWindow[ $testNB ],
                    remoteWindow[ $testNB, "RemoteHome" -> "/home/v" ],
                    remoteWindow[ $testNB, "Settings" -> <| "SSHSettings" -> <| $acpTestSSH, "MachineName" -> "other" |> |> ],
                    remoteWindow[ $testNB, "Error" -> <| "Code" -> "RemoteFolderMissing" |> ]
                } ]
            } ];
            (* a local window keeps the front end's directory dialog (and is looked at on this computer) *)
            Join[ results, { $localPathCalls, Length @ Cases[ row @ testWindow[ $testNB ], _FileNameSetter, Infinity ] } ]
        ],
        <| "Windows" -> <| |> |>
    ],
    {
        { True, True, True, 0, True, True, True, { { "devbox:", "~/p" } }, { Automatic }, { "Click to choose another folder" } },
        True,
        "This is your home folder on devbox: the agent can read and change everything in it.",
        "This is your home folder on devbox: the agent can read and change everything in it.",
        "This is the root folder of devbox: the agent can read and change everything on it.",
        "This folder doesn't exist on devbox.",
        None,
        True,
        { True, True },
        4,
        { },
        1
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-FolderRow-Remote@@Tests/ACPWindow.wlt:4162,1-4228,2"
]

(* The window title of a remote window: the folder's name (a POSIX name, whatever this computer's system) on the host *)
VerificationTest[
    Block[ { Wolfram`Chatbook`ACP`Transcript`Private`$acpNoFrontEndLabels = True },
        {
            Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString @ remoteWindow[ $testNB ],
            Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString @ remoteWindow[ $testNB, "PendingPermissions" -> <| 1 -> <| |> |> ],
            Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString @ remoteWindow[ $testNB, "ProjectDirectory" -> "/" ],
            Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString @ remoteWindow[ $testNB, "ProjectDirectory" -> None ],
            Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString @ remoteWindow[ $testNB, "Settings" -> <| "SSHSettings" -> <| "MachineName" -> "-bad" |> |> ],
            Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString @ remoteWindow[ $testNB, "ProjectDirectory" -> "/srv/a\:202eb" ],
            Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString[ "/home/user/TestProject", "OpenCode", False ],
            Lookup[ { Wolfram`Chatbook`ACP`UI`Private`acpNotebookOptions[ "/home/u/p", "OpenCode", <| "SSHSettings" -> $acpTestSSH |> ] }, WindowTitle ]
        }
    ],
    {
        "p on devbox \[LongDash] OpenCode",
        "Approval needed \[LongDash] p on devbox",
        "/ on devbox \[LongDash] OpenCode",
        "OpenCode",
        "p on ? \[LongDash] OpenCode",
        "a\:27e6U+202E\:27e7b on devbox \[LongDash] OpenCode",
        "TestProject \[LongDash] OpenCode",
        "p on devbox \[LongDash] OpenCode"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-WindowTitle-Remote@@Tests/ACPWindow.wlt:4231,1-4256,2"
]

(* "Sign in..." of a remote window: the sign-in runs on the host, so the notice says so and gives the terminal command
   that connects there (shown as typed in the code font, with "Copy command", whose button carries no text); a local
   window keeps the local instruction. "Copy command" gives the command of the window's notice (without a front end
   nothing is copied), and nothing for a notice without one. *)
VerificationTest[
    withACPMocks[
        Module[ { remote, local, view, copied },
            Wolfram`Chatbook`Common`acpAction[ "SignIn", $testNB ];
            remote = Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Notice" ];
            Wolfram`Chatbook`Common`acpAction[ "SignIn", $testNB2 ];
            local  = Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB2, "Notice" ];
            view   = Wolfram`Chatbook`ACP`UI`Private`acpInputAreaView[ $testNB, Wolfram`Chatbook`ACP`Common`acpWindowGet @ $testNB ];
            copied = Block[ { $FrontEnd = Null }, Wolfram`Chatbook`Common`acpAction[ "CopyNoticeCommand", $testNB ] ];
            {
                remote,
                local,
                Cases[ view, Style[ s_String, ___, FontFamily -> "Source Code Pro", ___ ] :> s, Infinity ],
                Sort @ Cases[ view, HoldPattern[ _[ "ACP", a_String, ___ ] ] :> a, Infinity ],
                FreeQ[ Cases[ view, HoldPattern @ Button[ _, code_, ___ ] :> HoldComplete @ code, Infinity ], _String? (StringContainsQ[ "devbox" ]) ],
                copied,
                Block[ { $FrontEnd = Null }, Wolfram`Chatbook`Common`acpAction[ "CopyNoticeCommand", $testNB2 ] ]
            }
        ],
        <| "Windows" -> <| $testNB -> remoteWindow[ $testNB, "Status" -> "Error" ], $testNB2 -> testWindow[ $testNB2, "Status" -> "Error" ] |> |>
    ],
    {
        <|
            "Text"    -> "The sign-in runs on u@devbox: connect with this command in a terminal, run \"opencode auth login\" there, then reconnect.",
            "Command" -> "ssh -l u devbox"
        |>,
        "Run \"opencode auth login\" in a terminal to sign in, then reconnect.",
        { "ssh -l u devbox" },
        { "CopyNoticeCommand", "DismissNotice" },
        True,
        "ssh -l u devbox",
        Missing[ "NoCommand" ]
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-SignIn-Remote@@Tests/ACPWindow.wlt:4262,1-4297,2"
]

(* Notices show commands and paths as typed: no operator substitution, which draws "-" as a long minus sign (the
   "Can't send the message" notice quotes the error message, which can hold an ssh command or a path) *)
VerificationTest[
    withACPMocks[
        Union @ Cases[
            Wolfram`Chatbook`ACP`UI`Private`acpNoticeView[ $testNB, "Can't send the message: run ssh -l u -F /a-b/c devbox." ],
            Style[ _String, ___, HoldPattern[ PrivateFontOptions -> o_ ], ___ ] :> o,
            Infinity
        ],
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    { { "OperatorSubstitution" -> False } },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-Notice-TextStyle@@Tests/ACPWindow.wlt:4301,1-4313,2"
]

(* FE-only: with the notice's text style, "-" and "->" are drawn as typed, not as the wider minus sign and arrow
   (rasterized: narrower than with the default operator substitution; skipped without a front end) *)
VerificationTest[
    If[ $FrontEnd === Null,
        Missing[ "TestSkipped" ],
        Module[ { opts, width },
            opts  = First @ Cases[
                withACPMocks[ Wolfram`Chatbook`ACP`UI`Private`acpNoticeView[ $testNB, "x" ], <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |> ],
                Style[ "x", o___ ] :> { o },
                Infinity
            ];
            width = First @ ImageDimensions @ Rasterize[ Style[ "ssh -l u -F /a-b-c-d -> x", Sequence @@ # ], ImageResolution -> 144 ] &;
            width[ opts ] < width @ DeleteCases[ opts, HoldPattern[ PrivateFontOptions -> _ ] ]
        ]
    ],
    Missing[ "TestSkipped" ] | True,
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-Notice-TextStyle-FEOnly@@Tests/ACPWindow.wlt:4317,1-4333,2"
]

(* The folder row keeps the end of the path (the folder's own name): the front end cuts it at its start to the room
   that the row leaves (the kernel gives it whole, and the host whole before it), in a Fit column whose pane draws a
   still too wide folder smaller, so "Review" always stays in the window; a warning (here: the folder is missing) has
   its own column before the folder, out of that pane, so a narrow window never hides it; paths are drawn as typed *)
VerificationTest[
    withACPMocks[
        Module[ { long, row, missing, fit },
            long    = "/srv/build-00001/-home-ubuntu-Projects/00000000-1111-2222-3333-444444444444/scratchpad/remoteproj";
            row     = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ $testNB, remoteWindow[ $testNB, "ProjectDirectory" -> long ] ];
            missing = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[
                $testNB,
                remoteWindow[ $testNB, "ProjectDirectory" -> long, "Error" -> <| "Code" -> "RemoteFolderMissing" |> ]
            ];
            (* the pane takes at most the column's room ({0, Full}: a pane of Full width pushed "Review" out of a narrow,
               magnified window) *)
            fit = Cases[ #, Item[ Pane[ _, ___, ImageSize -> { { 0, Full }, Automatic }, ___, ImageSizeAction -> "ShrinkToFit", ___ ], ___, ItemSize -> Fit, ___ ], Infinity ] &;
            {
                DeleteDuplicates @ folderLabelTexts @ row,
                folderLabelCutsStartQ @ row,
                Length @ fit @ row,
                Union @ Cases[ row, Style[ _, "WorkspaceChatToolbarTitle", ___, HoldPattern[ PrivateFontOptions -> o_ ], ___ ] :> o, Infinity ],
                (* the warning: a cell of the row's grid of its own, between the folder icon and the folder *)
                Replace[
                    missing,
                    {
                        Grid[ { { _, Tooltip[ w_, _String ], Item[ _Pane, ___ ], ___ } }, ___ ] :>
                            w === Wolfram`Chatbook`ACP`UI`Private`$acpWarningIcon,
                        _ -> False
                    }
                ],
                FreeQ[ fit @ missing, Wolfram`Chatbook`ACP`UI`Private`$acpWarningIcon ],
                FreeQ[ row, Wolfram`Chatbook`ACP`UI`Private`$acpWarningIcon ]
            }
        ],
        <| "Windows" -> <| |> |>
    ],
    {
        { { "devbox:", "/srv/build-00001/-home-ubuntu-Projects/00000000-1111-2222-3333-444444444444/scratchpad/remoteproj" } },
        True,
        1,
        { { "OperatorSubstitution" -> False } },
        True,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-FolderRow-KeepsName@@Tests/ACPWindow.wlt:4339,1-4382,2"
]

(* The kernel keeps a pathological path to $acpFolderLabelMaxLength pieces (its end, after an ellipsis); a display-safe
   marker is one piece, which the front end cuts whole *)
VerificationTest[
    Module[ { pieces = Wolfram`Chatbook`ACP`UI`Private`folderLabelPieces },
        {
            pieces[ "~/a\:27e6U+202E\:27e7b" ],
            pieces[ "/x\:27e6U+E0041\:27e7" ],
            (* not a marker: characters *)
            pieces[ "\:27e6U+12\:27e7" ],
            Length @ pieces[ "/" <> StringRepeat[ "a", 500 ] <> "/name" ],
            Take[ pieces[ "/" <> StringRepeat[ "a", 500 ] <> "/name" ], 2 ],
            StringJoin @ Take[ pieces[ "/" <> StringRepeat[ "a", 500 ] <> "/name" ], -5 ]
        }
    ],
    {
        { "~", "/", "a", "\:27e6U+202E\:27e7", "b" },
        { "/", "x", "\:27e6U+E0041\:27e7" },
        { "\:27e6", "U", "+", "1", "2", "\:27e7" },
        Wolfram`Chatbook`ACP`UI`Private`$acpFolderLabelMaxLength,
        { "\[Ellipsis]", "a" },
        "/name"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-FolderRow-Pieces@@Tests/ACPWindow.wlt:4386,1-4408,2"
]

(* The width of the label: the room that the folder icon, a warning and the Review button (its label and counts, measured
   in their fonts) leave, all front-end side (acpFitWidth) *)
VerificationTest[
    withACPMocks @ Module[ { width, plain, warning, review },
        width   = Wolfram`Chatbook`ACP`UI`Private`folderLabelWidth;
        plain   = width[ False, None ];
        warning = width[ True, None ];
        review  = width[ False, <| "Status" -> "Changes", "FileCount" -> 2, "Added" -> 40, "Deleted" -> 2 |> ];
        {
            Head /@ { plain, warning, review },
            ! FreeQ[ plain, FrontEnd`AbsoluteCurrentValue[ "ViewSize" ] ],
            (* { screen points, points at magnification 1 }: the screen points (and the safety margin) are not scaled *)
            ! FreeQ[ plain, N[ First @ Wolfram`Chatbook`ACP`UI`Private`$folderRowReserve + Wolfram`Chatbook`ACP`Rendering`Private`$fitSafetyMargin ] ] &&
                ! FreeQ[ plain, N[ Last @ Wolfram`Chatbook`ACP`UI`Private`$folderRowReserve ] ],
            ! FreeQ[ warning, N[ Last @ Wolfram`Chatbook`ACP`UI`Private`$folderRowReserve + Wolfram`Chatbook`ACP`UI`Private`$folderWarningReserve ] ],
            Cases[ review, HoldPattern[ FEPrivate`StringWidth ][ s_String, ___ ] :> s, Infinity ]
        }
    ],
    {
        { Wolfram`Chatbook`ACP`Rendering`Private`feHold, Wolfram`Chatbook`ACP`Rendering`Private`feHold, Wolfram`Chatbook`ACP`Rendering`Private`feHold },
        True,
        True,
        True,
        { "ReviewChangesButton", "+40", "\[Minus]2" }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-FolderRow-Width@@Tests/ACPWindow.wlt:4412,1-4437,2"
]

(* FE-only: the front end cuts the label at its start, at a piece: as much of the end as fits, after an ellipsis, a marker
   whole or not at all, and keeps the host (skipped without a front end) *)
VerificationTest[
    If[ $FrontEnd === Null,
        Missing[ "TestSkipped" ],
        Module[ { feHold, evaluate, label, results },
            feHold = Wolfram`Chatbook`ACP`Rendering`Private`feHold;
            label[ width_ ] := First @ Cases[
                ToBoxes @ Style[
                    Wolfram`Chatbook`ACP`Common`acpFitText @ <|
                        "Prefix" -> { { "devbox:", { } } },
                        "Object"     -> Wolfram`Chatbook`ACP`UI`Private`folderLabelPieces[ "~/projects/some/folder/repo\:27e6U+202E\:27e7x" ],
                        "Side"       -> Left,
                        "Width"      -> feHold[ width ],
                        (* as folderLabel: the host is never dropped *)
                        "DropPrefix" -> False
                    |>,
                    FontFamily -> "Source Sans Pro", FontSize -> 12
                ],
                DynamicBox[ e_, ___ ] :> HoldComplete[ e ],
                Infinity
            ];
            evaluate[ HoldComplete[ e_ ] ] := Module[ { nb, value },
                nb = NotebookPut @ Notebook[ {
                    Cell[ BoxData @ DynamicBox[ FEPrivate`Set[ FrontEnd`CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "Fit" } ], e ]; "", Evaluator -> None ], "Text", FontFamily -> "Source Sans Pro", FontSize -> 12 ]
                } ];
                Rasterize @ nb;
                value = CurrentValue[ nb, { TaggingRules, "Fit" } ];
                NotebookClose @ nb;
                value
            ];
            (* the text of the shown spans (the front end writes characters such as the ellipsis as \:xxxx in strings) *)
            results = StringJoin[
                StringReplace[ StringTrim[ #, "\"" ], "\\:" ~~ h: Repeated[ HexadecimalCharacter, { 4 } ] :> FromCharacterCode @ FromDigits[ h, 16 ] ] & /@
                    Cases[ evaluate @ label @ #, StyleBox[ s_String, ___ ] :> s, Infinity ]
            ] & /@ Range[ 70, 200, 6 ];
            {
                AllTrue[ results, StringStartsQ[ #, "devbox:" ] & ],
                AllTrue[ results, StringEndsQ[ #, "x" ] & ],
                AllTrue[ results, StringContainsQ[ #, "\:27e6U+202E\:27e7" ] || ! StringContainsQ[ #, "202E" | "\:27e7" ] & ],
                AnyTrue[ results, StringStartsQ[ #, "devbox:\[Ellipsis]" ] & ],
                AnyTrue[ results, StringContainsQ[ #, "\:27e6" ] && StringStartsQ[ #, "devbox:\[Ellipsis]" ] & ]
            }
        ]
    ],
    Missing[ "TestSkipped" ] | { True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-FolderRow-FrontEndCut-FEOnly@@Tests/ACPWindow.wlt:4441,1-4487,2"
]

(* A local folder is display-safe in the folder row too (its label and tooltip), like a remote one and like the review
   window: a bidi control shows as a marker, never raw *)
VerificationTest[
    withACPMocks[
        Module[ { dir, row },
            dir = FileNameJoin @ { $TemporaryDirectory, "repo\:202ex" };
            row = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ $testNB, testWindow[ $testNB, "ProjectDirectory" -> dir ] ];
            {
                DeleteDuplicates[ StringEndsQ[ First @ #, "repo\:27e6U+202E\:27e7x" ] & /@ folderLabelTexts @ row ],
                Count[ row, s_String /; StringContainsQ[ s, "repo\:27e6U+202E\:27e7x" ], Infinity ] >= 2,
                FreeQ[ row, s_String /; StringContainsQ[ s, "\:202e" ] ],
                (* the marker is one piece of the cut *)
                ! FreeQ[ ToBoxes @ row, l: { __String } /; MemberQ[ l, "\:27e6U+202E\:27e7" ] ]
            }
        ],
        <| "Windows" -> <| |> |>
    ],
    { { True }, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-FolderRow-LocalDisplaySafe@@Tests/ACPWindow.wlt:4491,1-4509,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Input Cell*)
VerificationTest[
    $acpInputCellBottom = withACPMocks[
        Wolfram`Chatbook`Common`acpChatInputCell[ "Bottom", $testNB ],
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    Cell[ _BoxData, "ChatInputField", ___, CellTags -> "Bottom", ___ ],
    SameTest -> MatchQ,
    TestID   -> "InputCell-Structure@@Tests/ACPWindow.wlt:4514,1-4522,2"
]

VerificationTest[
    With[ { nb = $testNB }, {
        ! FreeQ[ $acpInputCellBottom, BoxID -> "AttachedChatInputField" ],
        ! FreeQ[ $acpInputCellBottom, BoxID -> "ACPSendChatButton" ],
        ! FreeQ[ $acpInputCellBottom, BoxID -> "ACPStopChatButton" ],
        ! FreeQ[ $acpInputCellBottom, HoldPattern @ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACP", "Input" } ] ],
        ! FreeQ[ $acpInputCellBottom, HoldPattern @ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACP", "Busy" } ] ],
        ! FreeQ[ $acpInputCellBottom, HoldPattern[ _[ "ACP", "Send", nb ] ] ],
        ! FreeQ[ $acpInputCellBottom, HoldPattern[ _[ "ACP", "Stop", nb ] ] ],
        FreeQ[ $acpInputCellBottom, "EvaluateWorkspaceChat" | HoldPattern[ $WorkspaceChatInput ] ],
        FreeQ[ $acpInputCellBottom, _Failure ]
    } ],
    { True, True, True, True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "InputCell-Contents@@Tests/ACPWindow.wlt:4524,1-4539,2"
]

(* The "+" of the attach menu at the left of the input field, and the draft's chips above it (a derived view) *)
VerificationTest[
    With[ { nb = $testNB }, {
        ! FreeQ[ $acpInputCellBottom, BoxID -> "ACPAttachButton" ],
        ! FreeQ[ $acpInputCellBottom, HoldPattern[ _[ "ACP", "AttachMenu", nb ] ] ],
        MemberQ[ Wolfram`Chatbook`ACP`UI`Private`$acpDerivedViewNames, "Attachments" ],
        ! FreeQ[ $acpInputCellBottom, HoldPattern @ Wolfram`Chatbook`ACP`Attachments`Private`attachmentsView ]
    } ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "InputCell-Attachments@@Tests/ACPWindow.wlt:4542,1-4552,2"
]

(* The prompt notebook's button next to Send (PromptNotebook.wl) *)
VerificationTest[
    With[ { nb = $testNB }, {
        ! FreeQ[ $acpInputCellBottom, BoxID -> "ACPPromptNotebookButton" ],
        ! FreeQ[ $acpInputCellBottom, HoldPattern[ _[ "ACP", "OpenPromptNotebook", nb ] ] ],
        ! FreeQ[ $acpInputCellBottom, HoldPattern[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "WorkspaceToolbarIconOpenAsChatbook" ] ] ]
    } ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "InputCell-PromptNotebookButton@@Tests/ACPWindow.wlt:4555,1-4564,2"
]

(* The chips name attachments in button code by their keys only; the view is rendered again only when the draft or a
   preparation changes *)
VerificationTest[
    withACPMocks[
        Module[ { view, empty, preparing, sym, bump },
            view      = Wolfram`Chatbook`ACP`Attachments`Private`attachmentsView[ $testNB, testWindow[ $testNB, "Attachments" -> { $nbRef, $fileRef } ] ];
            empty     = Wolfram`Chatbook`ACP`Attachments`Private`attachmentsView[ $testNB, testWindow @ $testNB ];
            preparing = Wolfram`Chatbook`ACP`Attachments`Private`attachmentsView[ $testNB, preparingWindow[ "t1", "x" ] ];
            sym = Wolfram`Chatbook`ACP`Common`acpEntitySymbol[ Wolfram`Chatbook`ACP`Common`acpWindowKey @ $testNB, "Attachments" ];
            bump := ReleaseHold @ Replace[ sym, HoldComplete[ s_ ] :> Hold @ s ];
            Wolfram`Chatbook`ACP`Common`acpSyncDerivedView[ $testNB, "Attachments", Wolfram`Chatbook`ACP`Attachments`Private`attachmentsSignature ];
            {
                Cases[ view, HoldPattern[ _[ "ACP", action: "RemoveAttachment" | "ShowAttachment", args___ ] ] :> { action, args }, Infinity ],
                FreeQ[ Cases[ view, HoldPattern[ _[ "ACP", ___ ] ], Infinity ], "/tmp/data.csv" | "Spec.nb" | "data.csv" ],
                empty,
                ! FreeQ[ preparing, s_String /; StringContainsQ[ s, "Preparing 2 attachments" ] ],
                bump,
                Wolfram`Chatbook`ACP`Common`acpWindowSet[ $testNB, "Usage", <| "used" -> 1 |> ];
                Wolfram`Chatbook`ACP`Common`acpSyncDerivedView[ $testNB, "Attachments", Wolfram`Chatbook`ACP`Attachments`Private`attachmentsSignature ];
                bump,
                Wolfram`Chatbook`ACP`Common`acpSetDraftAttachments[ $testNB, { $fileRef } ];
                Wolfram`Chatbook`ACP`Common`acpSyncDerivedView[ $testNB, "Attachments", Wolfram`Chatbook`ACP`Attachments`Private`attachmentsSignature ];
                bump
            }
        ],
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    {
        { { "ShowAttachment", $testNB, "nb-1" }, { "RemoveAttachment", $testNB, "nb-1" }, { "RemoveAttachment", $testNB, "file-1" } },
        True,
        Spacer[ { 0, 0 } ],
        True,
        1,
        1,
        2
    },
    SameTest -> MatchQ,
    TestID   -> "InputArea-AttachmentChips@@Tests/ACPWindow.wlt:4568,1-4604,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`Common`acpChatInputCell[ "Top", $testNB ],
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    Cell[ _BoxData, "ChatInputField", ___, CellTags -> "Top", ___ ],
    SameTest -> MatchQ,
    TestID   -> "InputCell-Top@@Tests/ACPWindow.wlt:4606,1-4614,2"
]

VerificationTest[
    withACPMocks[
        {
            Wolfram`Chatbook`ACP`UI`Private`acpInputAreaView @ $testNB,
            Wolfram`Chatbook`ACP`UI`Private`acpInputAreaView[ $testNB, testWindow[ $testNB, "PendingPermissions" -> <| "7" -> <| |> |> ] ],
            Wolfram`Chatbook`ACP`UI`Private`acpInputAreaView[ $testNB, testWindow[ $testNB, "QueuedPrompt" -> "Later", "Notice" -> "Note" ] ]
        },
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    {
        Spacer[ { 0, 0 } ],
        Column[ { Pane[ permissionPanel[ $testNB ], ___ ] }, ___ ],
        Column[ { _Framed, _Framed }, ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "InputArea@@Tests/ACPWindow.wlt:4616,1-4632,2"
]

VerificationTest[
    withACPMocks[
        {
            Wolfram`Chatbook`ACP`UI`Private`acpInputFooterView[
                $testNB,
                testWindow[ $testNB, "ConfigOptions" -> ReplacePart[ $testConfigOptions, { 3, "currentValue" } -> "plan" ] ]
            ],
            Wolfram`Chatbook`ACP`UI`Private`acpInputFooterView[ $testNB, testWindow[ $testNB, "Usage" -> <| "used" -> 1, "size" -> 2 |> ] ],
            Wolfram`Chatbook`ACP`UI`Private`acpInputFooterView[ $testNB, testWindow[ $testNB, "ConfigOptions" -> { } ] ],
            Wolfram`Chatbook`ACP`UI`Private`acpInputFooter @ $testNB
        }
    ],
    {
        Row[ { _Framed, Style[ "OpenAI (your account)", ___ ] }, _ ],
        Row[ { "", Style[ "OpenAI (your account)", ___ ] }, _ ],
        Spacer[ { 0, 0 } ],
        Pane[ Row @ { usageMeter[ $testNB ], Row[ { _Dynamic, _Dynamic } ] }, ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "InputFooter@@Tests/ACPWindow.wlt:4634,1-4654,2"
]

(* Views that contain widgets only re-render when their part of the window state changes *)
VerificationTest[
    withACPMocks[
        Module[ { sym, bump },
            sym = Wolfram`Chatbook`ACP`Common`acpEntitySymbol[ Wolfram`Chatbook`ACP`Common`acpWindowKey @ $testNB, "InputArea" ];
            bump := ReleaseHold @ Replace[ sym, HoldComplete[ s_ ] :> Hold @ s ];
            Wolfram`Chatbook`ACP`Common`acpSyncDerivedView[ $testNB, "InputArea", Wolfram`Chatbook`ACP`UI`Private`acpInputAreaSignature ];
            {
                bump,
                Wolfram`Chatbook`ACP`Common`acpWindowSet[ $testNB, "Usage", <| "used" -> 1 |> ];
                Wolfram`Chatbook`ACP`Common`acpSyncDerivedView[ $testNB, "InputArea", Wolfram`Chatbook`ACP`UI`Private`acpInputAreaSignature ];
                bump,
                Wolfram`Chatbook`ACP`Common`acpWindowSet[ $testNB, "Notice", "Hi" ];
                Wolfram`Chatbook`ACP`Common`acpSyncDerivedView[ $testNB, "InputArea", Wolfram`Chatbook`ACP`UI`Private`acpInputAreaSignature ];
                bump
            }
        ],
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    { 1, 1, 2 },
    SameTest -> MatchQ,
    TestID   -> "DerivedViews@@Tests/ACPWindow.wlt:4657,1-4678,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*New Chat*)
VerificationTest[
    withACPMocks[
        Block[ { CurrentValue, Wolfram`Chatbook`ChatModes`Common`moveChatInputToTop = logCall[ "MoveInputToTop", ## ] & },
            Wolfram`Chatbook`Common`acpAction[ "NewChat", $testNB ];
            {
                calledQ /@ { "NotebookDelete", "MoveInputToTop", "NewSession", "Stop" },
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, { "QueuedPrompt", "Notice", "Turns" } ],
                StringQ @ CurrentValue[ $testNB, { TaggingRules, "ChatNotebookSettings", "ConversationUUID" } ]
            }
        ],
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "QueuedPrompt" -> "x", "Notice" -> "y", "Turns" -> { "t" } ] |> |>
    ],
    { { True, True, True, False }, { None, None, { } }, True },
    SameTest -> MatchQ,
    TestID   -> "NewChat@@Tests/ACPWindow.wlt:4683,1-4698,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Kernel Restarts*)
VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`Common`acpEnsureWindowRecord @ $testNB,
        <| "FE" -> <| { $testNB, "ProjectDirectory" } -> $TemporaryDirectory, { $testNB, "ResumableSessionID" } -> "ses_9" |> |>
    ],
    KeyValuePattern @ {
        "Notebook"           -> $testNB,
        "Status"             -> "Disconnected",
        "ProjectDirectory"   -> _String,
        "ResumableSessionID" -> "ses_9",
        "Agent"              -> "OpenCode"
    },
    SameTest -> MatchQ,
    TestID   -> "EnsureWindowRecord-Rebuild@@Tests/ACPWindow.wlt:4703,1-4717,2"
]

(* The explicit agent settings are restored from the TaggingRules *)
VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`Common`acpEnsureWindowRecord[ $testNB ][ "Settings" ],
        <| "FE" -> <|
            { $testNB, "ProjectDirectory" } -> $TemporaryDirectory,
            { $testNB, "Settings" } -> <| "ACPAgentCommandLine" -> "/opt/oc", "ACPModel" -> "a/b", "Other" -> 1 |>
        |> |>
    ],
    <| "ACPAgentCommandLine" -> "/opt/oc", "ACPModel" -> "a/b" |>,
    SameTest -> MatchQ,
    TestID   -> "EnsureWindowRecord-RebuildSettings@@Tests/ACPWindow.wlt:4720,1-4731,2"
]

(* A partial record (no "Status") is rebuilt too *)
VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`Common`acpEnsureWindowRecord @ $testNB,
        <|
            "Windows" -> <| $testNB -> <| "Notebook" -> $testNB, "QueuedPrompt" -> None |> |>,
            "FE"      -> <| { $testNB, "ProjectDirectory" } -> $TemporaryDirectory |>
        |>
    ],
    KeyValuePattern @ { "Status" -> "Disconnected", "ProjectDirectory" -> _String, "Agent" -> "OpenCode" },
    SameTest -> MatchQ,
    TestID   -> "EnsureWindowRecord-RebuildPartial@@Tests/ACPWindow.wlt:4734,1-4745,2"
]

(* After a kernel restart, the queued prompt's x button (CancelQueuedPrompt) must not create a partial record that
   blocks reconnecting *)
VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`Common`acpAction[ "CancelQueuedPrompt", $testNB ];
        Wolfram`Chatbook`ACP`Common`acpWindowGet @ $testNB,
        <| "FE" -> <| { $testNB, "ProjectDirectory" } -> $TemporaryDirectory |> |>
    ],
    KeyValuePattern @ { "Status" -> "Disconnected", "ProjectDirectory" -> _String, "QueuedPrompt" -> None },
    SameTest -> MatchQ,
    TestID   -> "CancelQueuedPrompt-NoRecord@@Tests/ACPWindow.wlt:4749,1-4758,2"
]

(* The draft's attachments are rebuilt from the TaggingRules (the front end may give associations back as rules; other
   values are dropped) *)
VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`Common`acpEnsureWindowRecord[ $testNB ][ "Attachments" ],
        <| "FE" -> <|
            { $testNB, "ProjectDirectory" } -> $TemporaryDirectory,
            { $testNB, "Attachments" } -> { Normal @ $nbRef, $fileRef, <| "Kind" -> "File" |>, None }
        |> |>
    ],
    { $nbRef, $fileRef },
    SameTest -> MatchQ,
    TestID   -> "EnsureWindowRecord-RebuildDraft@@Tests/ACPWindow.wlt:4762,1-4773,2"
]

(* A message that was being prepared, and one that was queued, when the kernel quit go back into the draft (queued first:
   it was sent earlier), before what was typed since, with a notice; the TaggingRules forget them *)
VerificationTest[
    withACPMocks[
        Module[ { window = Wolfram`Chatbook`ACP`Common`acpEnsureWindowRecord @ $testNB },
            {
                Lookup[ window, { "Attachments", "Notice", "QueuedPrompt", "Preparing" } ],
                Lookup[ $feFlags, { { $testNB, "Input" }, { $testNB, "Attachments" }, { $testNB, "QueuedPrompt" }, { $testNB, "PreparingPrompt" } } ]
            }
        ],
        <| "FE" -> <|
            { $testNB, "ProjectDirectory" } -> $TemporaryDirectory,
            { $testNB, "Input" }            -> "typed",
            { $testNB, "QueuedPrompt" }     -> <| "Text" -> "Queued", "Attachments" -> { $fileRef } |>,
            { $testNB, "PreparingPrompt" }  -> Normal @ <| "Input" -> "Preparing", "Text" -> "Preparing", "Attachments" -> { $nbRef } |>
        |> |>
    ],
    {
        {
            { $nbRef, $fileRef },
            "The kernel was restarted: the message that was waiting to be sent is back in the input field.",
            None,
            None
        },
        { "Queued\n\nPreparing\n\ntyped", { $nbRef, $fileRef }, None, None }
    },
    SameTest -> MatchQ,
    TestID   -> "EnsureWindowRecord-RebuildPendingPrompts@@Tests/ACPWindow.wlt:4777,1-4803,2"
]

VerificationTest[
    withACPMocks[
        Block[
            {
                Cells = Replace[ { ## }, { { _, CellTags -> "ACPActiveTurn" } :> { $outCell }, _ :> { } } ] &,
                Wolfram`Chatbook`ACP`UI`Private`acpRefreshWindowUI = logCall[ "RefreshUI", ## ] &
            },
            Wolfram`Chatbook`ACP`Common`acpMarkOrphanCells @ $testNB;
            { calls[ "NotebookWrite" ], calls[ "RefreshUI" ] }
        ]
    ],
    {
        { { $outCell, Cell[ BoxData @ TemplateBox[ _, "AssistantMessageBox" ], "ChatOutput", ___ ], None, AutoScroll -> False } },
        { { $testNB } }
    },
    SameTest -> MatchQ,
    TestID   -> "MarkOrphanCells@@Tests/ACPWindow.wlt:4805,1-4822,2"
]

(* A window whose input text was never set (e.g. a notebook given the ACPChat stylesheet by hand) gets an empty input,
   so the input field does not show Inherited; existing input is kept *)
VerificationTest[
    {
        withACPMocks @ Block[
            {
                Wolfram`Chatbook`ACP`UI`Private`acpNotebookExistsQ   = True &,
                Wolfram`Chatbook`ACP`Common`acpEnsureWindowRecord    = <| |> &,
                Wolfram`Chatbook`ACP`Common`acpUpdateWindowTitle     = Null &,
                Cells = { } &,
                Wolfram`Chatbook`Common`attachWorkspaceChatInput = Null &
            },
            Wolfram`Chatbook`ACP`UI`Private`acpInitializeWindow @ $testNB;
            Wolfram`Chatbook`ACP`Common`acpFE[ $testNB, "Input", Inherited ]
        ],
        withACPMocks[
            Block[
                {
                    Wolfram`Chatbook`ACP`UI`Private`acpNotebookExistsQ   = True &,
                    Wolfram`Chatbook`ACP`Common`acpEnsureWindowRecord    = <| |> &,
                    Wolfram`Chatbook`ACP`Common`acpUpdateWindowTitle     = Null &,
                    Cells = { } &,
                    Wolfram`Chatbook`Common`attachWorkspaceChatInput = Null &
                },
                Wolfram`Chatbook`ACP`UI`Private`acpInitializeWindow @ $testNB;
                Wolfram`Chatbook`ACP`Common`acpFE[ $testNB, "Input", Inherited ]
            ],
            <| "FE" -> <| { $testNB, "Input" } -> "draft" |> |>
        ]
    },
    { "", "draft" },
    SameTest -> MatchQ,
    TestID   -> "InitializeWindow-InputInitialized@@Tests/ACPWindow.wlt:4826,1-4857,2"
]

(* After a kernel restart the toolbar is set again even if the rebuilt cell is the same expression: the front end must
   evaluate its Dynamics in the new kernel and reset its DynamicModule state *)
VerificationTest[
    withACPMocks @ Module[ { toolbar, other },
        toolbar = Cell[ "toolbar", CellTags -> "ACPToolbar" ];
        other   = Cell[ "other" ];
        Block[
            {
                AbsoluteCurrentValue = Replace[ { ## }, { { _, DockedCells } :> { other, toolbar }, _ :> None } ] &,
                Wolfram`Chatbook`ACP`UI`Private`acpToolbarDockedCell = toolbar &
            },
            Wolfram`Chatbook`ACP`UI`Private`acpRefreshToolbar @ $testNB;
            calls[ "SetOptions" ]
        ]
    ],
    { { $testNB, DockedCells -> { Cell[ "other" ], Cell[ "toolbar", CellTags -> "ACPToolbar" ] } } },
    SameTest -> MatchQ,
    TestID   -> "RefreshToolbar-AlwaysSet@@Tests/ACPWindow.wlt:4861,1-4877,2"
]

VerificationTest[
    (* no ACP toolbar (e.g. docked cells replaced by the user): nothing is set *)
    withACPMocks @ Block[ { AbsoluteCurrentValue = Replace[ { ## }, { { _, DockedCells } :> { Cell[ "other" ] }, _ :> None } ] & },
        Wolfram`Chatbook`ACP`UI`Private`acpRefreshToolbar @ $testNB;
        calls[ "SetOptions" ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "RefreshToolbar-NoToolbar@@Tests/ACPWindow.wlt:4879,1-4888,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Strings*)
VerificationTest[
    Select[ Wolfram`Chatbook`ACP`Common`$acpUIStrings, ! StringQ @ # || StringLength @ # === 0 & ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "UIStrings@@Tests/ACPWindow.wlt:4893,1-4898,2"
]

(* All ACP label keys used in UI.wl have English defaults *)
VerificationTest[
    Complement[
        Union @ StringCases[
            ReadString @ FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "Source", "Chatbook", "ACP", "UI.wl" },
            "acpLabel[ \"" ~~ key: Except[ "\"" ].. ~~ "\"" :> key
        ],
        Keys @ Wolfram`Chatbook`ACP`Common`$acpUIStrings
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "UIStrings-Coverage@@Tests/ACPWindow.wlt:4901,1-4912,2"
]

(* ... and in Attachments.wl (its strings are in $acpUIStrings) *)
VerificationTest[
    Complement[
        Union @ StringCases[
            ReadString @ FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "Source", "Chatbook", "ACP", "Attachments.wl" },
            ("acpLabel" | "throwAttachment" | "attachmentFailure") ~~ "[ \"" ~~ key: Except[ "\"" ].. ~~ "\"" :> key
        ],
        Keys @ Wolfram`Chatbook`ACP`Common`$acpUIStrings
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "UIStrings-Coverage-Attachments@@Tests/ACPWindow.wlt:4915,1-4926,2"
]

(* ... and in PromptNotebook.wl *)
VerificationTest[
    Complement[
        Union @ StringCases[
            ReadString @ FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "Source", "Chatbook", "ACP", "PromptNotebook.wl" },
            "acpLabel[ \"" ~~ key: Except[ "\"" ].. ~~ "\"" :> key
        ],
        Keys @ Wolfram`Chatbook`ACP`Common`$acpUIStrings
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "UIStrings-Coverage-PromptNotebook@@Tests/ACPWindow.wlt:4929,1-4940,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Text Resources*)

(* Every acpLabel key ($acpStrings in Transcript.wl, $acpUIStrings in UI.wl, $acpConnectionStrings in Agents.wl,
   $acpReviewStrings in Review.wl, $acpSessionsStrings in Sessions.wl, $acpFolderPickerStrings in FolderPicker.wl) is a
   text resource "ACP" <> key in ChatbookStrings.tr and in each localized copy (English text until localized). *)
VerificationTest[
    $acpTextResourceFiles = Prepend[
        FileNames[ "ChatbookStrings.tr", FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "FrontEnd", "TextResources" }, { 2 } ],
        FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "FrontEnd", "TextResources", "ChatbookStrings.tr" }
    ];
    (* The ChatbookStrings resource of a .tr file as an association *)
    acpReadTextResources[ file_ ] := Module[ { text, body },
        text = ReadString @ file;
        body = First @ StringCases[ text, "@@resource ChatbookStrings" ~~ Shortest[ b___ ] ~~ "\n}\n" :> b <> "\n}", 1 ];
        Association @ ToExpression[ body, InputForm ]
    ];
    $acpTextResources = AssociationMap[ acpReadTextResources, $acpTextResourceFiles ];
    $acpResourceKeys = Prepend[
        "ACP" <> # & /@ Union[
            Keys @ Wolfram`Chatbook`ACP`Common`$acpStrings,
            Keys @ Wolfram`Chatbook`ACP`Common`$acpUIStrings,
            Keys @ Wolfram`Chatbook`ACP`Common`$acpConnectionStrings,
            Keys @ Wolfram`Chatbook`ACP`Common`$acpReviewStrings,
            Keys @ Wolfram`Chatbook`ACP`Common`$acpSessionsStrings,
            Keys @ Wolfram`Chatbook`ACP`Common`$acpFolderPickerStrings
        ],
        "ACPWindowTitle" (* the ACPChat.nb stylesheet's WindowTitle *)
    ];
    { Length @ $acpTextResourceFiles, AllTrue[ $acpTextResources, AssociationQ[ # ] && AllTrue[ #, StringQ ] & ] },
    { 7, True },
    SameTest -> MatchQ,
    TestID   -> "TextResources-Parse@@Tests/ACPWindow.wlt:4949,1-4976,2"
]

VerificationTest[
    DeleteCases[ Complement[ $acpResourceKeys, Keys @ # ] & /@ $acpTextResources, { } ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "TextResources-KeyParity@@Tests/ACPWindow.wlt:4978,1-4983,2"
]

(* No leftover resources for keys that no longer exist *)
VerificationTest[
    DeleteCases[ Complement[ Select[ Keys @ #, StringStartsQ[ "ACP" ] ], $acpResourceKeys ] & /@ $acpTextResources, { } ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "TextResources-NoStaleKeys@@Tests/ACPWindow.wlt:4986,1-4991,2"
]

(* The English resources are the table text, so labels are the same with and without a front end *)
VerificationTest[
    Module[ { english = First @ $acpTextResources, tables },
        tables = Join[
            Wolfram`Chatbook`ACP`Common`$acpConnectionStrings,
            Wolfram`Chatbook`ACP`Common`$acpUIStrings,
            Wolfram`Chatbook`ACP`Common`$acpStrings,
            Wolfram`Chatbook`ACP`Common`$acpReviewStrings,
            Wolfram`Chatbook`ACP`Common`$acpSessionsStrings,
            Wolfram`Chatbook`ACP`Common`$acpFolderPickerStrings
        ];
        Select[ KeyValueMap[ { #1, #2, english[ "ACP" <> #1 ] } &, tables ], #[[ 2 ]] =!= #[[ 3 ]] & ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "TextResources-EnglishText@@Tests/ACPWindow.wlt:4994,1-5009,2"
]

(* The paclet's own reader of ChatbookStrings.tr (the cloud's text resources; the MX build evaluates it) reads the whole
   resource, although texts contain "}" (e.g. "Arguments" -> {"-i", "path"}) *)
VerificationTest[
    Module[ { cloud = Wolfram`Chatbook`Common`Private`getCloudTextResources[ ], english = First @ $acpTextResources },
        {
            AssociationQ @ cloud,
            Length @ cloud === Length @ english,
            KeyTake[ cloud, $acpResourceKeys ] === KeyTake[ english, $acpResourceKeys ],
            StringContainsQ[ cloud[ "ACPErrorSSHAuthFailedDetail" ], "{\"-i\", \"path\"}" ]
        }
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "TextResources-CloudTextResources@@Tests/ACPWindow.wlt:5013,1-5025,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Front End*)

(* These need a front end (CI runs the tests with one). "ProjectDirectory" -> None, so no agent is started. *)
VerificationTest[
    $acpFrontEndTestsQ = MatchQ[ $FrontEnd, _FrontEndObject ];
    $acpTestWindow = If[ $acpFrontEndTestsQ,
        Block[ { Wolfram`Chatbook`ACP`Common`acpEnsureConnected = Null & },
            ShowNotebookAssistance[ None, "ACPWindow", "NewChat" -> True, "ChatNotebookSettings" -> <| "ProjectDirectory" -> None |> ]
        ],
        Missing[ "TestSkipped" ]
    ],
    _NotebookObject | Missing[ "TestSkipped" ],
    SameTest -> MatchQ,
    TestID   -> "FrontEnd-CreateWindow@@Tests/ACPWindow.wlt:5032,1-5043,2"
]

(* A window without a source notebook gets the default width, capped to its display *)
VerificationTest[
    If[ $acpFrontEndTestsQ,
        AbsoluteCurrentValue[ $acpTestWindow, { WindowSize, 1 } ] == Wolfram`Chatbook`ChatModes`Common`attachedWindowWidth[
            Wolfram`Chatbook`ACP`UI`Private`$acpWindowWidth,
            1,
            Wolfram`Chatbook`ChatModes`Common`notebookDisplayRange @ $acpTestWindow
        ],
        Missing[ "TestSkipped" ]
    ],
    True | Missing[ "TestSkipped" ],
    SameTest -> MatchQ,
    TestID   -> "FrontEnd-WindowWidth@@Tests/ACPWindow.wlt:5046,1-5058,2"
]

VerificationTest[
    If[ $acpFrontEndTestsQ,
        {
            CurrentValue[ $acpTestWindow, StyleDefinitions ],
            AbsoluteCurrentValue[ $acpTestWindow, { TaggingRules, "ChatNotebookSettings", "AppName" } ],
            Wolfram`Chatbook`Common`acpWindowQ @ $acpTestWindow,
            CurrentValue[ $acpTestWindow, { TaggingRules, "ACP", "KernelSessionID" } ] === $SessionID,
            StringQ @ CurrentValue[ $acpTestWindow, Evaluator ],
            Wolfram`Chatbook`ChatModes`Common`findCurrentWorkspaceChat[ "ACP" ] === $acpTestWindow,
            Wolfram`Chatbook`ChatModes`Common`findCurrentWorkspaceChat[ "NotebookAssistance" ] =!= $acpTestWindow,
            Wolfram`Chatbook`ACP`Common`acpWindowGet[ $acpTestWindow, "Status" ],
            CurrentValue[ $acpTestWindow, WindowTitle ]
        },
        Missing[ "TestSkipped" ]
    ],
    Missing[ "TestSkipped" ] | {
        FrontEnd`FileName[ { "Wolfram" }, "ACPChat.nb", ___ ],
        "ACP",
        True,
        True,
        True,
        True,
        True,
        "NoDirectory",
        _String
    },
    SameTest -> MatchQ,
    TestID   -> "FrontEnd-WindowSettings@@Tests/ACPWindow.wlt:5060,1-5088,2"
]

VerificationTest[
    If[ $acpFrontEndTestsQ,
        Block[ { Wolfram`Chatbook`ACP`Common`acpEnsureConnected = Null &, Wolfram`Chatbook`ACP`Common`acpDisconnect = Null & },
            Module[ { new },
                new = ShowNotebookAssistance[ None, "ACPWindow", "NewChat" -> True, "ChatNotebookSettings" -> <| "ProjectDirectory" -> None |> ];
                {
                    MatchQ[ new, _NotebookObject ] && new =!= $acpTestWindow,
                    MemberQ[ Notebooks[ ], $acpTestWindow ],
                    KeyExistsQ[ Wolfram`Chatbook`ACP`Common`$acpWindows, $acpTestWindow ],
                    Wolfram`Chatbook`ACP`UI`Private`acpCloseWindow @ new;
                    MemberQ[ Notebooks[ ], new ] || KeyExistsQ[ Wolfram`Chatbook`ACP`Common`$acpWindows, new ]
                }
            ]
        ],
        Missing[ "TestSkipped" ]
    ],
    Missing[ "TestSkipped" ] | { True, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "FrontEnd-NewChatReplacesWindow@@Tests/ACPWindow.wlt:5090,1-5109,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Debug Log*)

(* Nothing was logged as a message or failure outside the tests that do it on purpose (withExpectedLog) *)
VerificationTest[
    Select[
        Internal`BagPart[ Wolfram`Chatbook`ACP`Common`$acpDebugLog, All ],
        With[ { t = #[ "Time" ] },
            t >= $acpLogStart &&
                MemberQ[ { "Message", "Uncaught", "FinalCellFailed", "FinalCellFallback", "FinishedFormattingFallback" }, #[ "Where" ] ] &&
                ! AnyTrue[ $acpExpectedLogWindows, #[[ 1 ]] <= t <= #[[ 2 ]] & ]
        ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Window-DebugLog@@Tests/ACPWindow.wlt:5116,1-5128,2"
]

(* :!CodeAnalysis::EndBlock:: *)
