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
    TestID   -> "Definitions@@Tests/ACPWindow.wlt:25,1-165,2"
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
    TestID   -> "NAInputCell-GoldenData@@Tests/ACPWindow.wlt:172,1-178,2"
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
    TestID   -> "NAInputCell-Golden@@Tests/ACPWindow.wlt:182,1-192,2"
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
    TestID   -> "NAInputCell-LoadReference@@Tests/ACPWindow.wlt:195,1-214,2"
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
    TestID   -> "NAInputCell-Reference@@Tests/ACPWindow.wlt:216,1-228,2"
]

(* attachWorkspaceChatInput dispatches on the window's AppName *)
VerificationTest[
    Block[ { $SessionID = 0 },
        Wolfram`Chatbook`ChatModes`UI`Private`workspaceChatInputCell[ $testNB, "Top", "NotebookAssistance" ] ===
            Wolfram`Chatbook`ChatModes`UI`Private`attachedWorkspaceChatInputCell[ "Top" ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WorkspaceChatInputCell-Dispatch-NA@@Tests/ACPWindow.wlt:231,1-239,2"
]

VerificationTest[
    withACPMocks @ Wolfram`Chatbook`ChatModes`UI`Private`workspaceChatInputCell[ $testNB, "Bottom", "ACP" ],
    Cell[ _BoxData, "ChatInputField", ___, CellTags -> "Bottom", ___ ],
    SameTest -> MatchQ,
    TestID   -> "WorkspaceChatInputCell-Dispatch-ACP@@Tests/ACPWindow.wlt:241,1-246,2"
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
    TestID   -> "EvaluateWorkspaceChat-Equivalence-String@@Tests/ACPWindow.wlt:254,1-294,2"
]

VerificationTest[
    nbEquivalence[ Wolfram`Chatbook`Common`evaluateWorkspaceChat, RowBox @ { "x", "+", SuperscriptBox[ "y", "2" ] } ] ===
        nbEquivalence[ Wolfram`Chatbook`ChatModes`Evaluate`Private`referenceEvaluateWorkspaceChat, RowBox @ { "x", "+", SuperscriptBox[ "y", "2" ] } ],
    True,
    SameTest -> MatchQ,
    TestID   -> "EvaluateWorkspaceChat-Equivalence-Boxes@@Tests/ACPWindow.wlt:296,1-302,2"
]

VerificationTest[
    {
        nbEquivalence[ Wolfram`Chatbook`Common`evaluateWorkspaceChat, "   " ],
        nbEquivalence[ Wolfram`Chatbook`Common`evaluateWorkspaceChat, "   " ] ===
            nbEquivalence[ Wolfram`Chatbook`ChatModes`Evaluate`Private`referenceEvaluateWorkspaceChat, "   " ]
    },
    { { Null, "", { } }, True },
    SameTest -> MatchQ,
    TestID   -> "EvaluateWorkspaceChat-Equivalence-NoInput@@Tests/ACPWindow.wlt:304,1-313,2"
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
    TestID   -> "WriteWorkspaceChatInputCell-Result@@Tests/ACPWindow.wlt:315,1-333,2"
]

VerificationTest[
    Module[ { input = "\n  " },
        Block[ { $callLog = { }, NotebookWrite = logCall[ "NotebookWrite", ## ] & },
            { Wolfram`Chatbook`Common`writeWorkspaceChatInputCell[ $testNB, Dynamic @ input ], input, $callLog }
        ]
    ],
    { Missing[ "NoInput" ], "", { } },
    SameTest -> MatchQ,
    TestID   -> "WriteWorkspaceChatInputCell-NoInput@@Tests/ACPWindow.wlt:335,1-344,2"
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
    TestID   -> "WriteWorkspaceChatInputCell-CurrentValue@@Tests/ACPWindow.wlt:347,1-372,2"
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
    TestID   -> "ShowNotebookAssistance-ACPWindow-Arguments@@Tests/ACPWindow.wlt:377,1-391,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ $testNB, "ACPWindow" ]
    ],
    { $testNB, "", False, False, <| |> },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-Defaults@@Tests/ACPWindow.wlt:393,1-400,2"
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
    TestID   -> "ShowNotebookAssistance-ACPWindow-UserNotebook@@Tests/ACPWindow.wlt:402,1-413,2"
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
    TestID   -> "ShowNotebookAssistance-ACPWindow-CellObject@@Tests/ACPWindow.wlt:415,1-426,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ProjectDirectory" -> 42 |> ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidDirectory@@Tests/ACPWindow.wlt:428,1-436,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPAgent" -> "SomethingElse" |> ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidAgent@@Tests/ACPWindow.wlt:438,1-446,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> "/tmp/project" ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidSettings@@Tests/ACPWindow.wlt:448,1-456,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPModel" -> None |> ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidModel@@Tests/ACPWindow.wlt:458,1-466,2"
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
    TestID   -> "ShowNotebookAssistance-ACPWindow-CommandLine@@Tests/ACPWindow.wlt:469,1-491,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`showACPWindow = ({ ## } &) },
        ShowNotebookAssistance[ None, "ACPWindow", "ChatNotebookSettings" -> <| "ACPAgentCommandLine" -> { "ssh", 22 } |> ]
    ],
    _Failure,
    { ShowNotebookAssistance::InvalidACPWindowSettings },
    SameTest -> MatchQ,
    TestID   -> "ShowNotebookAssistance-ACPWindow-InvalidCommandLine@@Tests/ACPWindow.wlt:493,1-501,2"
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
    TestID   -> "ACPAction-Names@@Tests/ACPWindow.wlt:508,1-524,2"
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
        { { "SessionsShowMore"      , $testNB, "k2"            }, Wolfram`Chatbook`ACP`Common`acpSessionsWindowAction, { "SessionsShowMore", $testNB, "k2" } }
    };
    Sort[ #[[ 1, 1 ]] & /@ $acpActionDispatch ] === Sort @ Wolfram`Chatbook`ACP`UI`Private`$acpActionNames,
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPAction-DispatchTable@@Tests/ACPWindow.wlt:526,1-570,2"
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
    TestID   -> "ACPAction-Dispatch@@Tests/ACPWindow.wlt:572,1-585,2"
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
    TestID   -> "ACPAction-ChatbookAction@@Tests/ACPWindow.wlt:587,1-597,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`acpAction[ "NotAnAction", 1, 2 ],
    Missing[ "UnknownAction", "NotAnAction" ],
    SameTest -> MatchQ,
    TestID   -> "ACPAction-Unknown@@Tests/ACPWindow.wlt:599,1-604,2"
]

(* Failures in actions never escape (they may run preemptively inside a Notebook Assistant chat) *)
VerificationTest[
    withExpectedLog @ Block[ { Wolfram`Chatbook`ACP`Common`evaluateACPChat = Throw[ "escaped", "SomeTag" ] & },
        Catch[ Wolfram`Chatbook`Common`acpAction[ "Send", $testNB ], _, "escaped" & ]
    ],
    Failure[ "ACPInternal", _ ],
    SameTest -> MatchQ,
    TestID   -> "ACPAction-Isolated-Throw@@Tests/ACPWindow.wlt:607,1-614,2"
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
    TestID   -> "ACPAction-Isolated-InternalFailure@@Tests/ACPWindow.wlt:616,1-627,2"
]

VerificationTest[
    withExpectedLog @ Block[ { Wolfram`Chatbook`ACP`Common`evaluateACPChat = (Message[ General::argx, "x", 1 ]; 1/0) & },
        Wolfram`Chatbook`Common`acpAction[ "Send", $testNB ]
    ],
    ComplexInfinity,
    SameTest -> MatchQ,
    TestID   -> "ACPAction-Isolated-Messages@@Tests/ACPWindow.wlt:629,1-636,2"
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
    TestID   -> "EvaluateACPChat-Ready@@Tests/ACPWindow.wlt:641,1-689,2"
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
    TestID   -> "EvaluateACPChat-Connecting@@Tests/ACPWindow.wlt:691,1-706,2"
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
    TestID   -> "EvaluateACPChat-Disconnected@@Tests/ACPWindow.wlt:708,1-723,2"
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
    TestID   -> "EvaluateACPChat-NoDirectory@@Tests/ACPWindow.wlt:725,1-742,2"
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
    TestID   -> "EvaluateACPChat-QueuePrompt@@Tests/ACPWindow.wlt:744,1-761,2"
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
    TestID   -> "EvaluateACPChat-NoInput@@Tests/ACPWindow.wlt:763,1-774,2"
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
    TestID   -> "QueuedTurn-SentWhenReady@@Tests/ACPWindow.wlt:777,1-798,2"
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
    TestID   -> "QueuedTurn-FailsOnError@@Tests/ACPWindow.wlt:800,1-821,2"
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
    TestID   -> "QueuedTurn-StopLocally@@Tests/ACPWindow.wlt:823,1-842,2"
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
    TestID   -> "Stop-Running@@Tests/ACPWindow.wlt:844,1-857,2"
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
    TestID   -> "Stop-NothingRunning@@Tests/ACPWindow.wlt:859,1-871,2"
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
    TestID   -> "FinalizeTurn@@Tests/ACPWindow.wlt:876,1-912,2"
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
    TestID   -> "FinalizeTurn-Debounce@@Tests/ACPWindow.wlt:914,1-926,2"
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
    TestID   -> "FinalizeTurn-CellGone@@Tests/ACPWindow.wlt:928,1-946,2"
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
    TestID   -> "FinalizeTurn-Fallback@@Tests/ACPWindow.wlt:948,1-974,2"
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
    TestID   -> "FinalizeTurn-SendsQueuedPrompt@@Tests/ACPWindow.wlt:979,1-1021,2"
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
    TestID   -> "FinalizeTurn-QueuedPromptWriteFails@@Tests/ACPWindow.wlt:1024,1-1047,2"
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
    TestID   -> "FinalizeTurn-UntaggedThrow@@Tests/ACPWindow.wlt:1051,1-1076,2"
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
    TestID   -> "FinalizeTurn-EverythingThrows@@Tests/ACPWindow.wlt:1078,1-1102,2"
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
    TestID   -> "FinalizeTurn-SettleBusyFlag@@Tests/ACPWindow.wlt:1106,1-1137,2"
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
    TestID   -> "FinalizeTurn-CancelsPendingPermissions@@Tests/ACPWindow.wlt:1141,1-1158,2"
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
    TestID   -> "Housekeeping-FinalizeFallback@@Tests/ACPWindow.wlt:1161,1-1173,2"
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
    TestID   -> "Housekeeping-FinalizeTimeout@@Tests/ACPWindow.wlt:1176,1-1204,2"
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
    TestID   -> "ConfigOptionValues@@Tests/ACPWindow.wlt:1209,1-1222,2"
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
    TestID   -> "ConfigMenus-Structure@@Tests/ACPWindow.wlt:1224,1-1238,2"
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
    TestID   -> "ConfigMenus-ModelItems@@Tests/ACPWindow.wlt:1240,1-1267,2"
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
    TestID   -> "ConfigMenus-DisabledWhileRunning@@Tests/ACPWindow.wlt:1269,1-1280,2"
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
    TestID   -> "ConfigMenus-EffortHidden@@Tests/ACPWindow.wlt:1282,1-1296,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`UI`Private`acpConfigMenusView[ $testNB, testWindow[ $testNB, "ConfigOptions" -> { } ] ]
    ],
    Spacer[ 0 ],
    SameTest -> MatchQ,
    TestID   -> "ConfigMenus-NoOptions@@Tests/ACPWindow.wlt:1298,1-1305,2"
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
    TestID   -> "SetConfigOption-RecentModels@@Tests/ACPWindow.wlt:1308,1-1319,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`Common`acpAction[ "SetConfigOption", $testNB, "model", "opencode/big-pickle" ];
        calledQ[ "SetConfigOption" ],
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "CurrentTurn" -> "turn-1" ] |> |>
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "SetConfigOption-IgnoredWhileRunning@@Tests/ACPWindow.wlt:1321,1-1330,2"
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
    TestID   -> "ModelNames@@Tests/ACPWindow.wlt:1332,1-1342,2"
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
    TestID   -> "ModelMenu-ProviderLabels@@Tests/ACPWindow.wlt:1346,1-1363,2"
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
    TestID   -> "ProjectDirectoryHelpers@@Tests/ACPWindow.wlt:1365,1-1391,2"
]

VerificationTest[
    withACPMocks @ {
        Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString[ "/home/user/TestProject", "OpenCode", False ],
        Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString[ "/home/user/TestProject", "OpenCode", True ],
        Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString[ None, "OpenCode", False ]
    },
    { "TestProject \[LongDash] OpenCode", "Approval needed \[LongDash] TestProject", "OpenCode" },
    SameTest -> MatchQ,
    TestID   -> "WindowTitle@@Tests/ACPWindow.wlt:1393,1-1402,2"
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
    TestID   -> "WindowTitle-Update@@Tests/ACPWindow.wlt:1404,1-1416,2"
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
    TestID   -> "ToolbarStructure@@Tests/ACPWindow.wlt:1418,1-1434,2"
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
    TestID   -> "ToolbarIsolated@@Tests/ACPWindow.wlt:1438,1-1458,2"
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
    TestID   -> "DirectoryRow@@Tests/ACPWindow.wlt:1460,1-1471,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`UI`Private`acpSetProjectDirectoryAction[ $testNB, File @ FileNameJoin @ { $TemporaryDirectory, "." } ];
        calls[ "SetProjectDirectory" ],
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "ProjectDirectory" -> "/nonexistent" ] |> |>
    ],
    { { $testNB, ExpandFileName @ $TemporaryDirectory } },
    SameTest -> MatchQ,
    TestID   -> "SetProjectDirectory@@Tests/ACPWindow.wlt:1473,1-1482,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`ACP`UI`Private`acpSetProjectDirectoryAction[ $testNB, $HomeDirectory ];
        { calledQ[ "SetProjectDirectory" ], Wolfram`Chatbook`ACP`Common`acpWindowGet[ $testNB, "Notice" ] },
        <| "Windows" -> <| $testNB -> testWindow[ $testNB, "CurrentTurn" -> "turn-1" ] |> |>
    ],
    { False, "The project folder can't be changed while the agent is working." },
    SameTest -> MatchQ,
    TestID   -> "SetProjectDirectory-WhileRunning@@Tests/ACPWindow.wlt:1484,1-1493,2"
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
    TestID   -> "ReuseWindow-ChangeDirectory@@Tests/ACPWindow.wlt:1496,1-1516,2"
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
    TestID   -> "ReuseWindow-Running@@Tests/ACPWindow.wlt:1518,1-1537,2"
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
    TestID   -> "ReuseWindow-SameDirectory@@Tests/ACPWindow.wlt:1539,1-1554,2"
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
    TestID   -> "ReuseWindow-Settings-ErrorReconnects@@Tests/ACPWindow.wlt:1558,1-1583,2"
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
    TestID   -> "ReuseWindow-Settings-Model@@Tests/ACPWindow.wlt:1586,1-1602,2"
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
    TestID   -> "ReuseWindow-Settings-WhileRunning@@Tests/ACPWindow.wlt:1605,1-1622,2"
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
    TestID   -> "SetAgentExecutable@@Tests/ACPWindow.wlt:1625,1-1645,2"
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
    TestID   -> "InputCell-Structure@@Tests/ACPWindow.wlt:1650,1-1658,2"
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
    TestID   -> "InputCell-Contents@@Tests/ACPWindow.wlt:1660,1-1675,2"
]

VerificationTest[
    withACPMocks[
        Wolfram`Chatbook`Common`acpChatInputCell[ "Top", $testNB ],
        <| "Windows" -> <| $testNB -> testWindow @ $testNB |> |>
    ],
    Cell[ _BoxData, "ChatInputField", ___, CellTags -> "Top", ___ ],
    SameTest -> MatchQ,
    TestID   -> "InputCell-Top@@Tests/ACPWindow.wlt:1677,1-1685,2"
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
    TestID   -> "InputArea@@Tests/ACPWindow.wlt:1687,1-1703,2"
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
    TestID   -> "InputFooter@@Tests/ACPWindow.wlt:1705,1-1725,2"
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
    TestID   -> "DerivedViews@@Tests/ACPWindow.wlt:1728,1-1749,2"
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
    TestID   -> "NewChat@@Tests/ACPWindow.wlt:1754,1-1769,2"
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
    TestID   -> "EnsureWindowRecord-Rebuild@@Tests/ACPWindow.wlt:1774,1-1788,2"
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
    TestID   -> "EnsureWindowRecord-RebuildSettings@@Tests/ACPWindow.wlt:1791,1-1802,2"
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
    TestID   -> "EnsureWindowRecord-RebuildPartial@@Tests/ACPWindow.wlt:1805,1-1816,2"
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
    TestID   -> "CancelQueuedPrompt-NoRecord@@Tests/ACPWindow.wlt:1820,1-1829,2"
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
    TestID   -> "MarkOrphanCells@@Tests/ACPWindow.wlt:1831,1-1848,2"
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
    TestID   -> "InitializeWindow-InputInitialized@@Tests/ACPWindow.wlt:1852,1-1883,2"
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
    TestID   -> "RefreshToolbar-AlwaysSet@@Tests/ACPWindow.wlt:1887,1-1903,2"
]

VerificationTest[
    (* no ACP toolbar (e.g. docked cells replaced by the user): nothing is set *)
    withACPMocks @ Block[ { AbsoluteCurrentValue = Replace[ { ## }, { { _, DockedCells } :> { Cell[ "other" ] }, _ :> None } ] & },
        Wolfram`Chatbook`ACP`UI`Private`acpRefreshToolbar @ $testNB;
        calls[ "SetOptions" ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "RefreshToolbar-NoToolbar@@Tests/ACPWindow.wlt:1905,1-1914,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Strings*)
VerificationTest[
    Select[ Wolfram`Chatbook`ACP`Common`$acpUIStrings, ! StringQ @ # || StringLength @ # === 0 & ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "UIStrings@@Tests/ACPWindow.wlt:1919,1-1924,2"
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
    TestID   -> "UIStrings-Coverage@@Tests/ACPWindow.wlt:1927,1-1938,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Text Resources*)

(* Every acpLabel key ($acpStrings in Transcript.wl, $acpUIStrings in UI.wl, $acpConnectionStrings in Agents.wl,
   $acpReviewStrings in Review.wl, $acpSessionsStrings in Sessions.wl) is a text resource "ACP" <> key in
   ChatbookStrings.tr and in each localized copy (English text until localized). *)
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
            Keys @ Wolfram`Chatbook`ACP`Common`$acpSessionsStrings
        ],
        "ACPWindowTitle" (* the ACPChat.nb stylesheet's WindowTitle *)
    ];
    { Length @ $acpTextResourceFiles, AllTrue[ $acpTextResources, AssociationQ[ # ] && AllTrue[ #, StringQ ] & ] },
    { 7, True },
    SameTest -> MatchQ,
    TestID   -> "TextResources-Parse@@Tests/ACPWindow.wlt:1947,1-1973,2"
]

VerificationTest[
    DeleteCases[ Complement[ $acpResourceKeys, Keys @ # ] & /@ $acpTextResources, { } ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "TextResources-KeyParity@@Tests/ACPWindow.wlt:1975,1-1980,2"
]

(* No leftover resources for keys that no longer exist *)
VerificationTest[
    DeleteCases[ Complement[ Select[ Keys @ #, StringStartsQ[ "ACP" ] ], $acpResourceKeys ] & /@ $acpTextResources, { } ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "TextResources-NoStaleKeys@@Tests/ACPWindow.wlt:1983,1-1988,2"
]

(* The English resources are the table text, so labels are the same with and without a front end *)
VerificationTest[
    Module[ { english = First @ $acpTextResources, tables },
        tables = Join[
            Wolfram`Chatbook`ACP`Common`$acpConnectionStrings,
            Wolfram`Chatbook`ACP`Common`$acpUIStrings,
            Wolfram`Chatbook`ACP`Common`$acpStrings,
            Wolfram`Chatbook`ACP`Common`$acpReviewStrings,
            Wolfram`Chatbook`ACP`Common`$acpSessionsStrings
        ];
        Select[ KeyValueMap[ { #1, #2, english[ "ACP" <> #1 ] } &, tables ], #[[ 2 ]] =!= #[[ 3 ]] & ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "TextResources-EnglishText@@Tests/ACPWindow.wlt:1991,1-2005,2"
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
    TestID   -> "FrontEnd-CreateWindow@@Tests/ACPWindow.wlt:2012,1-2023,2"
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
    TestID   -> "FrontEnd-WindowSettings@@Tests/ACPWindow.wlt:2025,1-2053,2"
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
    TestID   -> "FrontEnd-NewChatReplacesWindow@@Tests/ACPWindow.wlt:2055,1-2074,2"
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
    TestID   -> "Window-DebugLog@@Tests/ACPWindow.wlt:2081,1-2093,2"
]

(* :!CodeAnalysis::EndBlock:: *)
