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
            Wolfram`Chatbook`ACP`Common`acpBillingLabel       = Replace[ #, { s_String /; StringStartsQ[ s, "openai/" ] :> "OpenAI (your account)", _ :> "OpenCode (free)" } ] &,
            Wolfram`Chatbook`ACP`Common`acpNewTurn            = mockNewTurn,
            Wolfram`Chatbook`ACP`Common`acpApplyTurnEnd       = mockApplyTurnEnd,
            Wolfram`Chatbook`ACP`Common`acpLiveView           = (Dynamic @ liveView[ # ] &),
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
    TestID   -> "Definitions@@Tests/ACPWindow.wlt:25,1-169,2"
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
    TestID   -> "NAInputCell-GoldenData@@Tests/ACPWindow.wlt:176,1-182,2"
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
    TestID   -> "NAInputCell-Golden@@Tests/ACPWindow.wlt:186,1-196,2"
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
    TestID   -> "NAInputCell-LoadReference@@Tests/ACPWindow.wlt:199,1-218,2"
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
    TestID   -> "NAInputCell-Reference@@Tests/ACPWindow.wlt:220,1-232,2"
]

(* attachWorkspaceChatInput dispatches on the window's AppName *)
VerificationTest[
    Block[ { $SessionID = 0 },
        Wolfram`Chatbook`ChatModes`UI`Private`workspaceChatInputCell[ $testNB, "Top", "NotebookAssistance" ] ===
            Wolfram`Chatbook`ChatModes`UI`Private`attachedWorkspaceChatInputCell[ "Top" ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WorkspaceChatInputCell-Dispatch-NA@@Tests/ACPWindow.wlt:235,1-243,2"
]

VerificationTest[
    withACPMocks @ Wolfram`Chatbook`ChatModes`UI`Private`workspaceChatInputCell[ $testNB, "Bottom", "ACP" ],
    Cell[ _BoxData, "ChatInputField", ___, CellTags -> "Bottom", ___ ],
    SameTest -> MatchQ,
    TestID   -> "WorkspaceChatInputCell-Dispatch-ACP@@Tests/ACPWindow.wlt:245,1-250,2"
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
    TestID   -> "EvaluateWorkspaceChat-Equivalence-String@@Tests/ACPWindow.wlt:258,1-298,2"
]

VerificationTest[
    nbEquivalence[ Wolfram`Chatbook`Common`evaluateWorkspaceChat, RowBox @ { "x", "+", SuperscriptBox[ "y", "2" ] } ] ===
        nbEquivalence[ Wolfram`Chatbook`ChatModes`Evaluate`Private`referenceEvaluateWorkspaceChat, RowBox @ { "x", "+", SuperscriptBox[ "y", "2" ] } ],
    True,
    SameTest -> MatchQ,
    TestID   -> "EvaluateWorkspaceChat-Equivalence-Boxes@@Tests/ACPWindow.wlt:300,1-306,2"
]

VerificationTest[
    {
        nbEquivalence[ Wolfram`Chatbook`Common`evaluateWorkspaceChat, "   " ],
        nbEquivalence[ Wolfram`Chatbook`Common`evaluateWorkspaceChat, "   " ] ===
            nbEquivalence[ Wolfram`Chatbook`ChatModes`Evaluate`Private`referenceEvaluateWorkspaceChat, "   " ]
    },
    { { Null, "", { } }, True },
    SameTest -> MatchQ,
    TestID   -> "EvaluateWorkspaceChat-Equivalence-NoInput@@Tests/ACPWindow.wlt:308,1-317,2"
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
    TestID   -> "WriteWorkspaceChatInputCell-Result@@Tests/ACPWindow.wlt:319,1-337,2"
]

VerificationTest[
    Module[ { input = "\n  " },
        Block[ { $callLog = { }, NotebookWrite = logCall[ "NotebookWrite", ## ] & },
            { Wolfram`Chatbook`Common`writeWorkspaceChatInputCell[ $testNB, Dynamic @ input ], input, $callLog }
        ]
    ],
    { Missing[ "NoInput" ], "", { } },
    SameTest -> MatchQ,
    TestID   -> "WriteWorkspaceChatInputCell-NoInput@@Tests/ACPWindow.wlt:339,1-348,2"
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
    TestID   -> "WriteWorkspaceChatInputCell-CurrentValue@@Tests/ACPWindow.wlt:351,1-376,2"
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
    TestID   -> "ShowNotebookAssistance-ACPWindow-Arguments@@Tests/ACPWindow.wlt:381,1-395,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ $testNB, "ACPWindow" ]
    ],
    { $testNB, "", False, False, <| |> },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-Defaults@@Tests/ACPWindow.wlt:397,1-404,2"
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
    TestID   -> "ShowNotebookAssistance-ACPWindow-UserNotebook@@Tests/ACPWindow.wlt:406,1-417,2"
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
    TestID   -> "ShowNotebookAssistance-ACPWindow-CellObject@@Tests/ACPWindow.wlt:419,1-430,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ProjectDirectory" -> 42 |> ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidDirectory@@Tests/ACPWindow.wlt:432,1-440,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPAgent" -> "SomethingElse" |> ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidAgent@@Tests/ACPWindow.wlt:442,1-450,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> "/tmp/project" ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidSettings@@Tests/ACPWindow.wlt:452,1-460,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPModel" -> None |> ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidModel@@Tests/ACPWindow.wlt:462,1-470,2"
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
    TestID   -> "ShowNotebookAssistance-ACPWindow-MCPServer@@Tests/ACPWindow.wlt:473,1-483,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPMCPServer" -> "off" |> ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidMCPServer@@Tests/ACPWindow.wlt:485,1-493,2"
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
    TestID   -> "ShowNotebookAssistance-ACPWindow-CommandLine@@Tests/ACPWindow.wlt:496,1-518,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPAgentCommandLine" -> { "ssh", 22 } |> ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidCommandLine@@Tests/ACPWindow.wlt:520,1-528,2"
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
    TestID   -> "ShowNotebookAssistance-ACPWindow-SSHSettings@@Tests/ACPWindow.wlt:531,1-586,2"
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
    TestID   -> "ShowNotebookAssistance-ACPWindow-SSHPair@@Tests/ACPWindow.wlt:589,1-613,2"
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
    TestID   -> "ACPAction-Names@@Tests/ACPWindow.wlt:620,1-636,2"
]

VerificationTest[
    $acpActionDispatch = {
        { { "Send"               , $testNB                     }, Wolfram`Chatbook`ACP`Common`evaluateACPChat                      , { $testNB } },
        { { "Stop"               , $testNB                     }, Wolfram`Chatbook`ACP`UI`Private`acpStopAction                , { $testNB } },
        { { "NewChat"            , $testNB                     }, Wolfram`Chatbook`ACP`Common`acpNewChat                       , { $testNB } },
        { { "ToggleOpen"         , "turn-1", { "Tool", "t1" }, True }, Wolfram`Chatbook`ACP`Common`acpToggleOpen               , { "turn-1", { "Tool", "t1" }, True } },
        { { "PermissionResponse" , $testNB, "req-1", "once"    }, Wolfram`Chatbook`ACP`UI`Private`acpPermissionResponseAction  , { $testNB, "req-1", "once" } },
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
        { { "FolderPickerClosed"      , $testNB                }, Wolfram`Chatbook`ACP`Common`acpFolderPickerAction, { "FolderPickerClosed", $testNB } }
    };
    Sort[ #[[ 1, 1 ]] & /@ $acpActionDispatch ] === Sort @ Wolfram`Chatbook`ACP`UI`Private`$acpActionNames,
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPAction-DispatchTable@@Tests/ACPWindow.wlt:638,1-697,2"
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
    TestID   -> "ACPAction-Dispatch@@Tests/ACPWindow.wlt:699,1-712,2"
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
    TestID   -> "ACPAction-ChatbookAction@@Tests/ACPWindow.wlt:714,1-724,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`acpAction[ "NotAnAction", 1, 2 ],
    Missing[ "UnknownAction", "NotAnAction" ],
    SameTest -> MatchQ,
    TestID   -> "ACPAction-Unknown@@Tests/ACPWindow.wlt:726,1-731,2"
]

(* Failures in actions never escape (they may run preemptively inside a Notebook Assistant chat) *)
VerificationTest[
    withExpectedLog @ Block[ { Wolfram`Chatbook`ACP`Common`evaluateACPChat = Throw[ "escaped", "SomeTag" ] & },
        Catch[ Wolfram`Chatbook`Common`acpAction[ "Send", $testNB ], _, "escaped" & ]
    ],
    Failure[ "ACPInternal", _ ],
    SameTest -> MatchQ,
    TestID   -> "ACPAction-Isolated-Throw@@Tests/ACPWindow.wlt:734,1-741,2"
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
    TestID   -> "ACPAction-Isolated-InternalFailure@@Tests/ACPWindow.wlt:743,1-754,2"
]

VerificationTest[
    withExpectedLog @ Block[ { Wolfram`Chatbook`ACP`Common`evaluateACPChat = (Message[ General::argx, "x", 1 ]; 1/0) & },
        Wolfram`Chatbook`Common`acpAction[ "Send", $testNB ]
    ],
    ComplexInfinity,
    SameTest -> MatchQ,
    TestID   -> "ACPAction-Isolated-Messages@@Tests/ACPWindow.wlt:756,1-763,2"
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
    TestID   -> "EvaluateACPChat-Ready@@Tests/ACPWindow.wlt:768,1-816,2"
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
    TestID   -> "EvaluateACPChat-Connecting@@Tests/ACPWindow.wlt:818,1-833,2"
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
    TestID   -> "EvaluateACPChat-Disconnected@@Tests/ACPWindow.wlt:835,1-850,2"
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
    TestID   -> "EvaluateACPChat-NoDirectory@@Tests/ACPWindow.wlt:852,1-869,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB;
        Wolfram`Chatbook`ACP`Common`evaluateACPChat @ $testNB;
        {
            Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "QueuedPrompt" ],
            $feFlags[ { $testNB, "Input" } ],
            Length @ calls[ "WriteUserCell" ]
        },
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-0" ] |>,
            "FE"      -> <| { $testNB, "Input" } -> "Also do this" |>
        |>
    ],
    { "Also do this", "", 0 },
    SameTest -> MatchQ,
    TestID   -> "EvaluateACPChat-QueuePrompt@@Tests/ACPWindow.wlt:871,1-888,2"
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
    TestID   -> "EvaluateACPChat-NoInput@@Tests/ACPWindow.wlt:890,1-901,2"
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
    TestID   -> "QueuedTurn-SentWhenReady@@Tests/ACPWindow.wlt:904,1-925,2"
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
    TestID   -> "QueuedTurn-FailsOnError@@Tests/ACPWindow.wlt:927,1-948,2"
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
    TestID   -> "QueuedTurn-StopLocally@@Tests/ACPWindow.wlt:950,1-969,2"
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
    TestID   -> "Stop-Running@@Tests/ACPWindow.wlt:971,1-984,2"
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
    TestID   -> "Stop-NothingRunning@@Tests/ACPWindow.wlt:986,1-998,2"
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
    TestID   -> "FinalizeTurn@@Tests/ACPWindow.wlt:1003,1-1039,2"
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
    TestID   -> "FinalizeTurn-Debounce@@Tests/ACPWindow.wlt:1041,1-1053,2"
]

VerificationTest[
    withACPMocks[
        Block[ { ParentNotebook = $Failed & },
            Wolfram`Chatbook`ACP`Common`acpFinalizeTurn[ "turn-1" ];
            {
                calledQ[ "NotebookWrite" ],
                KeyExistsQ[ Wolfram`Chatbook`ACP`Common`$acpTurns, "turn-1" ],
                Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "CurrentTurn" ]
            }
        ],
        <|
            "Windows" -> <| $testNB -> testWindow[ $testNB, "Status" -> "Running", "CurrentTurn" -> "turn-1" ] |>,
            "Turns"   -> <| "turn-1" -> $endedTurn |>
        |>
    ],
    { False, False, None },
    SameTest -> MatchQ,
    TestID   -> "FinalizeTurn-CellGone@@Tests/ACPWindow.wlt:1055,1-1073,2"
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
    TestID   -> "FinalizeTurn-Fallback@@Tests/ACPWindow.wlt:1075,1-1101,2"
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
    TestID   -> "FinalizeTurn-SendsQueuedPrompt@@Tests/ACPWindow.wlt:1106,1-1148,2"
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
    TestID   -> "FinalizeTurn-QueuedPromptWriteFails@@Tests/ACPWindow.wlt:1151,1-1174,2"
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
    TestID   -> "FinalizeTurn-UntaggedThrow@@Tests/ACPWindow.wlt:1178,1-1203,2"
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
    TestID   -> "FinalizeTurn-EverythingThrows@@Tests/ACPWindow.wlt:1205,1-1229,2"
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
    TestID   -> "FinalizeTurn-SettleBusyFlag@@Tests/ACPWindow.wlt:1233,1-1264,2"
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
    TestID   -> "FinalizeTurn-CancelsPendingPermissions@@Tests/ACPWindow.wlt:1268,1-1285,2"
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
    TestID   -> "Housekeeping-FinalizeFallback@@Tests/ACPWindow.wlt:1288,1-1300,2"
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
    TestID   -> "Housekeeping-FinalizeTimeout@@Tests/ACPWindow.wlt:1303,1-1331,2"
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
    TestID   -> "ConfigOptionValues@@Tests/ACPWindow.wlt:1336,1-1349,2"
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
    TestID   -> "ConfigMenus-Structure@@Tests/ACPWindow.wlt:1351,1-1365,2"
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
    TestID   -> "ConfigMenus-ModelItems@@Tests/ACPWindow.wlt:1367,1-1394,2"
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
    TestID   -> "ConfigMenus-DisabledWhileRunning@@Tests/ACPWindow.wlt:1396,1-1407,2"
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
    TestID   -> "ConfigMenus-EffortHidden@@Tests/ACPWindow.wlt:1409,1-1423,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`UI`Private`acpConfigMenusView[ $testNB, testWindow[ $testNB, "ConfigOptions" -> { } ] ]
    ],
    Spacer[ 0 ],
    SameTest -> MatchQ,
    TestID   -> "ConfigMenus-NoOptions@@Tests/ACPWindow.wlt:1425,1-1432,2"
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
    TestID   -> "SetConfigOption-RecentModels@@Tests/ACPWindow.wlt:1435,1-1446,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`Common`acpAction[ "SetConfigOption", $testNB, "model", "opencode/big-pickle" ];
        calledQ[ "SetConfigOption" ],
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "CurrentTurn" -> "turn-1" ] |> |>
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "SetConfigOption-IgnoredWhileRunning@@Tests/ACPWindow.wlt:1448,1-1457,2"
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
    TestID   -> "ModelNames@@Tests/ACPWindow.wlt:1459,1-1469,2"
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
    TestID   -> "ModelMenu-ProviderLabels@@Tests/ACPWindow.wlt:1473,1-1490,2"
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
    TestID   -> "ProjectDirectoryHelpers@@Tests/ACPWindow.wlt:1492,1-1518,2"
]

VerificationTest[
    withACPMocks @ {
        Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString[ "/home/user/TestProject", "OpenCode", False ],
        Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString[ "/home/user/TestProject", "OpenCode", True ],
        Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString[ None, "OpenCode", False ]
    },
    { "TestProject \[LongDash] OpenCode", "Approval needed \[LongDash] TestProject", "OpenCode" },
    SameTest -> MatchQ,
    TestID   -> "WindowTitle@@Tests/ACPWindow.wlt:1520,1-1529,2"
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
    TestID   -> "WindowTitle-Update@@Tests/ACPWindow.wlt:1531,1-1543,2"
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
    TestID   -> "ToolbarStructure@@Tests/ACPWindow.wlt:1545,1-1561,2"
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
    TestID   -> "ToolbarIsolated@@Tests/ACPWindow.wlt:1565,1-1585,2"
]

VerificationTest[
    withACPMocks @ Module[ { view },
        view = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ $testNB, testWindow @ $testNB ];
        {
            Cases[ view, FileNameSetter[ _Dynamic, "Directory", ___, Enabled -> e_, ___ ] :> e, Infinity ],
            ! FreeQ[ view, "SetProjectDirectory" ]
        }
    ],
    { { True }, True },
    SameTest -> MatchQ,
    TestID   -> "DirectoryRow@@Tests/ACPWindow.wlt:1587,1-1598,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`UI`Private`acpSetProjectDirectoryAction[ $testNB, File @ FileNameJoin @ { $TemporaryDirectory, "." } ];
        calls[ "SetProjectDirectory" ],
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "ProjectDirectory" -> "/nonexistent" ] |> |>
    ],
    { { $testNB, ExpandFileName @ $TemporaryDirectory } },
    SameTest -> MatchQ,
    TestID   -> "SetProjectDirectory@@Tests/ACPWindow.wlt:1600,1-1609,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`UI`Private`acpSetProjectDirectoryAction[ $testNB, $HomeDirectory ];
        { calledQ[ "SetProjectDirectory" ], Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Notice" ] },
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "CurrentTurn" -> "turn-1" ] |> |>
    ],
    { False, "The project folder can't be changed while the agent is working." },
    SameTest -> MatchQ,
    TestID   -> "SetProjectDirectory-WhileRunning@@Tests/ACPWindow.wlt:1611,1-1620,2"
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
    { $testNB, { { $testNB, _String } }, { { $testNB2, $testNB } }, True },
    SameTest -> MatchQ,
    TestID   -> "ReuseWindow-ChangeDirectory@@Tests/ACPWindow.wlt:1623,1-1643,2"
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
    TestID   -> "ReuseWindow-Running@@Tests/ACPWindow.wlt:1645,1-1664,2"
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
    TestID   -> "ReuseWindow-SameDirectory@@Tests/ACPWindow.wlt:1666,1-1681,2"
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
    TestID   -> "ReuseWindow-Settings-ErrorReconnects@@Tests/ACPWindow.wlt:1685,1-1710,2"
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
    TestID   -> "ReuseWindow-Settings-Model@@Tests/ACPWindow.wlt:1713,1-1729,2"
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
    TestID   -> "ReuseWindow-Settings-MCPServer@@Tests/ACPWindow.wlt:1736,1-1787,2"
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
    TestID   -> "ReuseWindow-Settings-WhileRunning@@Tests/ACPWindow.wlt:1790,1-1807,2"
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
    TestID   -> "SetAgentExecutable@@Tests/ACPWindow.wlt:1810,1-1830,2"
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
    TestID   -> "ACPWindow-RemoteDefinitions@@Tests/ACPWindow.wlt:1835,1-1861,2"
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
    TestID   -> "ACPWindow-PersistedSettingNames@@Tests/ACPWindow.wlt:1867,1-1912,2"
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
    TestID   -> "ACPWindow-RebuildRemoteFolderRaw@@Tests/ACPWindow.wlt:1917,1-1958,2"
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
    TestID   -> "ACPWindow-MergeNormalForm@@Tests/ACPWindow.wlt:1962,1-1986,2"
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
    TestID   -> "ACPWindow-ReuseHostSwitchRefusedWhileRunning@@Tests/ACPWindow.wlt:1990,1-2020,2"
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
    TestID   -> "ACPWindow-ExplicitFolderMissing@@Tests/ACPWindow.wlt:2024,1-2061,2"
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
    TestID   -> "ACPWindow-ReusePlan-HostSwitch@@Tests/ACPWindow.wlt:2067,1-2130,2"
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
    TestID   -> "ACPWindow-RemoteDefaultFolderKeepsTilde@@Tests/ACPWindow.wlt:2135,1-2158,2"
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
    TestID   -> "ACPWindow-ReusePlan-TildeFolder@@Tests/ACPWindow.wlt:2162,1-2211,2"
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
    TestID   -> "ACPWindow-LocateAgentRemote@@Tests/ACPWindow.wlt:2214,1-2240,2"
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
    TestID   -> "ACPWindow-RemoteViewDefinitions@@Tests/ACPWindow.wlt:2245,1-2269,2"
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
    TestID   -> "ACPWindow-StatusView-Remote@@Tests/ACPWindow.wlt:2274,1-2328,2"
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
    TestID   -> "ACPWindow-ErrorDetailToggle@@Tests/ACPWindow.wlt:2333,1-2391,2"
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
    TestID   -> "ACPWindow-Actions@@Tests/ACPWindow.wlt:2395,1-2428,2"
]

VerificationTest[
    SubsetQ[
        Wolfram`Chatbook`ACP`UI`Private`$acpActionNames,
        { "ChooseDirectory", "CopyErrorDetail", "CopyNoticeCommand", "FolderPickerCopyCommand", "FolderPickerCopyError", "ToggleErrorDetail" }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-Actions-Names@@Tests/ACPWindow.wlt:2430,1-2438,2"
]

(* The folder row of a remote window: host:path with the remote home abbreviated (the whole path and the host in the
   tooltip), "Change..." runs "ChooseDirectory" (the remote picker) instead of the front end's directory dialog,
   warnings for the remote home, the root and a missing folder; nothing looked at on this computer *)
VerificationTest[
    withACPMocks[
        Module[ { row, sig, texts, results },
            row   = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ $testNB, # ] &;
            sig   = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowSignature;
            texts = Cases[ #, s_String :> s, Infinity ] &;
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
                        FreeQ[ v, Wolfram`Chatbook`ACP`UI`Private`$acpWarningIcon ]
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
        { True, True, True, 0, True, True, True },
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
    TestID   -> "ACPWindow-FolderRow-Remote@@Tests/ACPWindow.wlt:2443,1-2505,2"
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
    TestID   -> "ACPWindow-WindowTitle-Remote@@Tests/ACPWindow.wlt:2508,1-2533,2"
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
    TestID   -> "ACPWindow-SignIn-Remote@@Tests/ACPWindow.wlt:2539,1-2574,2"
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
    TestID   -> "ACPWindow-Notice-TextStyle@@Tests/ACPWindow.wlt:2578,1-2590,2"
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
    TestID   -> "ACPWindow-Notice-TextStyle-FEOnly@@Tests/ACPWindow.wlt:2594,1-2610,2"
]

(* The folder row keeps the folder's own name whole ("\[Ellipsis]/" and as many of the last names as fit) and gives the
   folder the room the buttons leave: a Fit column whose pane draws a still too wide folder smaller, so "Review" and
   "Change..." always stay in the window and the name stays visible; a warning (here: the folder is missing) has its own
   column before the folder, out of that pane, so a narrow window never hides it; paths are drawn as typed *)
VerificationTest[
    withACPMocks[
        Module[ { long, row, missing, fit },
            long    = "/srv/build-00001/-home-ubuntu-Projects/00000000-1111-2222-3333-444444444444/scratchpad/remoteproj";
            row     = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ $testNB, remoteWindow[ $testNB, "ProjectDirectory" -> long ] ];
            missing = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[
                $testNB,
                remoteWindow[ $testNB, "ProjectDirectory" -> long, "Error" -> <| "Code" -> "RemoteFolderMissing" |> ]
            ];
            fit = Cases[ #, Item[ Pane[ _, ___, ImageSizeAction -> "ShrinkToFit", ___ ], ___, ItemSize -> Fit, ___ ], Infinity ] &;
            {
                Cases[ row, Style[ s_String, "WorkspaceChatToolbarTitle", ___ ] :> s, Infinity ],
                Length @ fit @ row,
                Union @ Cases[ row, Style[ _String, "WorkspaceChatToolbarTitle", ___, HoldPattern[ PrivateFontOptions -> o_ ], ___ ] :> o, Infinity ],
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
    { { "devbox:", "\[Ellipsis]/scratchpad/remoteproj" }, 1, { { "OperatorSubstitution" -> False } }, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-FolderRow-KeepsName@@Tests/ACPWindow.wlt:2616,1-2648,2"
]

(* A local folder is display-safe in the folder row too (its label and tooltip), like a remote one and like the review
   window: a bidi control shows as a marker, never raw *)
VerificationTest[
    withACPMocks[
        Module[ { dir, row },
            dir = FileNameJoin @ { $TemporaryDirectory, "repo\:202ex" };
            row = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ $testNB, testWindow[ $testNB, "ProjectDirectory" -> dir ] ];
            {
                Cases[ row, Style[ s_String, "WorkspaceChatToolbarTitle", ___ ] :> StringEndsQ[ s, "repo\:27e6U+202E\:27e7x" ], Infinity ],
                Count[ row, s_String /; StringContainsQ[ s, "repo\:27e6U+202E\:27e7x" ], Infinity ] >= 2,
                FreeQ[ row, s_String /; StringContainsQ[ s, "\:202e" ] ]
            }
        ],
        <| "Windows" -> <| |> |>
    ],
    { { True }, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPWindow-FolderRow-LocalDisplaySafe@@Tests/ACPWindow.wlt:2652,1-2668,2"
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
    TestID   -> "InputCell-Structure@@Tests/ACPWindow.wlt:2673,1-2681,2"
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
    TestID   -> "InputCell-Contents@@Tests/ACPWindow.wlt:2683,1-2698,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`Common`acpChatInputCell[ "Top", $testNB ],
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    Cell[ _BoxData, "ChatInputField", ___, CellTags -> "Top", ___ ],
    SameTest -> MatchQ,
    TestID   -> "InputCell-Top@@Tests/ACPWindow.wlt:2700,1-2708,2"
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
    TestID   -> "InputArea@@Tests/ACPWindow.wlt:2710,1-2726,2"
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
    TestID   -> "InputFooter@@Tests/ACPWindow.wlt:2728,1-2748,2"
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
    TestID   -> "DerivedViews@@Tests/ACPWindow.wlt:2751,1-2772,2"
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
    TestID   -> "NewChat@@Tests/ACPWindow.wlt:2777,1-2792,2"
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
    TestID   -> "EnsureWindowRecord-Rebuild@@Tests/ACPWindow.wlt:2797,1-2811,2"
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
    TestID   -> "EnsureWindowRecord-RebuildSettings@@Tests/ACPWindow.wlt:2814,1-2825,2"
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
    TestID   -> "EnsureWindowRecord-RebuildPartial@@Tests/ACPWindow.wlt:2828,1-2839,2"
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
    TestID   -> "CancelQueuedPrompt-NoRecord@@Tests/ACPWindow.wlt:2843,1-2852,2"
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
    TestID   -> "MarkOrphanCells@@Tests/ACPWindow.wlt:2854,1-2871,2"
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
    TestID   -> "InitializeWindow-InputInitialized@@Tests/ACPWindow.wlt:2875,1-2906,2"
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
    TestID   -> "RefreshToolbar-AlwaysSet@@Tests/ACPWindow.wlt:2910,1-2926,2"
]

VerificationTest[
    (* no ACP toolbar (e.g. docked cells replaced by the user): nothing is set *)
    withACPMocks @ Block[ { AbsoluteCurrentValue = Replace[ { ## }, { { _, DockedCells } :> { Cell[ "other" ] }, _ :> None } ] & },
        Wolfram`Chatbook`ACP`UI`Private`acpRefreshToolbar @ $testNB;
        calls[ "SetOptions" ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "RefreshToolbar-NoToolbar@@Tests/ACPWindow.wlt:2928,1-2937,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Strings*)
VerificationTest[
    Select[ Wolfram`Chatbook`ACP`Common`$acpUIStrings, ! StringQ @ # || StringLength @ # === 0 & ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "UIStrings@@Tests/ACPWindow.wlt:2942,1-2947,2"
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
    TestID   -> "UIStrings-Coverage@@Tests/ACPWindow.wlt:2950,1-2961,2"
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
    TestID   -> "TextResources-Parse@@Tests/ACPWindow.wlt:2970,1-2997,2"
]

VerificationTest[
    DeleteCases[ Complement[ $acpResourceKeys, Keys @ # ] & /@ $acpTextResources, { } ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "TextResources-KeyParity@@Tests/ACPWindow.wlt:2999,1-3004,2"
]

(* No leftover resources for keys that no longer exist *)
VerificationTest[
    DeleteCases[ Complement[ Select[ Keys @ #, StringStartsQ[ "ACP" ] ], $acpResourceKeys ] & /@ $acpTextResources, { } ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "TextResources-NoStaleKeys@@Tests/ACPWindow.wlt:3007,1-3012,2"
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
    TestID   -> "TextResources-EnglishText@@Tests/ACPWindow.wlt:3015,1-3030,2"
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
    TestID   -> "TextResources-CloudTextResources@@Tests/ACPWindow.wlt:3034,1-3046,2"
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
    TestID   -> "FrontEnd-CreateWindow@@Tests/ACPWindow.wlt:3053,1-3064,2"
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
    TestID   -> "FrontEnd-WindowSettings@@Tests/ACPWindow.wlt:3066,1-3094,2"
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
    TestID   -> "FrontEnd-NewChatReplacesWindow@@Tests/ACPWindow.wlt:3096,1-3115,2"
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
    TestID   -> "Window-DebugLog@@Tests/ACPWindow.wlt:3122,1-3134,2"
]

(* :!CodeAnalysis::EndBlock:: *)
