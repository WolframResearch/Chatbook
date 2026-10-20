(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ACPConnection.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ACPConnection.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* Tests for ACP/Agents.wl and ACP/Connection.wl (see docs/acp-window.md, "Files", "Threading rules" and "ACPLink").
   The pure Agents tests always run. The connection tests drive the Connection layer headlessly (no front end; fake
   NotebookObjects) against the scripted mock agent in Data/ACP/MockAgent (a copy of ACPLink's); they are skipped
   (Missing["TestSkipped"]) if ACPLink (with the "StandardInputPreambleTrigger" option of OpenACPConnection) or python3
   is missing. The "Remote (SSH)" tests run the mock agent "remotely" through the fake ssh (Data/ACP/fake-ssh, set up by
   Data/ACP/FakeSSH.wl) and are also skipped on Windows or without /bin/sh.
   For development, ACPLink is found through the ACPLINK_DIRECTORY environment variable (default ~/ACPLink/ACPLink).
   The LLMKit key lookup is disabled ($acpLLMKitEnabled = False) and only tested with a mocked HTTP layer: these tests
   never call the wolfram-keys service. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    Needs[ "Wolfram`Chatbook`ACP`Common`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPConnection-LoadACPContext@@Tests/ACPConnection.wlt:35,1-40,2"
]

VerificationTest[
    (* CI runs every test file in one kernel and one context: helpers that other test files define too are cleared
       first, so that none of their definitions is used here *)
    ClearAll[ busyPumpItem, connectionClosedQ, connectionPID, currentOption, housekeepingThisTick, lastLog,
        mcpServersExpected, mockIn, mockRecords, mockRequestsIn, newMockLog, newRemoteWindow, newWindow, processAliveQ,
        remoteSSH, reuseWindow ];

    $acpLLMKitEnabled     = False;
    $acpAssumeWindowsOpen = True;

    $mockDirectory = FileNameJoin @ { DirectoryName @ $TestFileName, "Data", "ACP", "MockAgent" };
    $mockScript    = FileNameJoin @ { $mockDirectory, "mock_acp_agent.py" };
    $python        = SelectFirst[
        { Environment[ "ACPLINK_TEST_PYTHON" ], "/usr/bin/python3", "/usr/local/bin/python3", "/opt/homebrew/bin/python3" },
        StringQ[ # ] && FileExistsQ[ # ] && ! DirectoryQ[ # ] &,
        None
    ];
    $setACPLinkEnv = False; (* restored by Cleanup-Restore *)
    If[ ! StringQ @ Environment[ "ACPLINK_DIRECTORY" ] && DirectoryQ @ FileNameJoin @ { $HomeDirectory, "ACPLink", "ACPLink" },
        SetEnvironment[ "ACPLINK_DIRECTORY" -> FileNameJoin @ { $HomeDirectory, "ACPLink", "ACPLink" } ];
        $setACPLinkEnv = True
    ];
    (* The MCP server of the notebook tools (MCP.wl) needs an AgentTools with StartMCPSocketServer: for development, an
       AgentTools checkout (AGENTTOOLS_DIRECTORY, default ~/AgentTools); restored by Cleanup-Restore *)
    $setAgentToolsEnv = False;
    If[ ! StringQ @ Environment[ "AGENTTOOLS_DIRECTORY" ] && FileExistsQ @ FileNameJoin @ { $HomeDirectory, "AgentTools", "PacletInfo.wl" },
        SetEnvironment[ "AGENTTOOLS_DIRECTORY" -> FileNameJoin @ { $HomeDirectory, "AgentTools" } ];
        $setAgentToolsEnv = True
    ];
    (* Persisted choices that connecting and the tests change (with a front end they are the developer's real front end
       preferences); restored by Cleanup-Restore *)
    $savedPersisted = AssociationMap[
        acpPersistedSetting,
        { { "LastProjectDirectory" }, { "LastModel", "MockACPAgent" }, { "LastEffort", "MockACPAgent" } }
    ];
    (* Anything logged as a message or failure after this point is unexpected (Cleanup-DebugLog) *)
    $acpLogStart = AbsoluteTime[ ];
    $acpConnTestsQ = TrueQ[ StringQ @ $python && FileExistsQ @ $mockScript && acpLinkAvailableQ[ ] && acpLoadACPLink[ ] === True ];
    $procfsQ       = $OperatingSystem === "Unix" && DirectoryQ[ "/proc/self" ];
    (* The "mcpServers" of a local window's sessions: the notebook tools' server if an AgentTools with
       StartMCPSocketServer can be loaded (see Tests/ACPMCP.wlt), else none (CI) *)
    mcpServersExpected[ ] := If[ TrueQ @ acpMCPAvailableQ[ ],
        { KeyValuePattern @ { "type" -> "http", "name" -> "WolframNotebooks", "url" -> _String, "headers" -> { KeyValuePattern[ "name" -> "Authorization" ] } } },
        { }
    ];

    $scratch = CreateDirectory[ ];
    $project1 = CreateDirectory @ FileNameJoin @ { $scratch, "project1" };
    $project2 = CreateDirectory @ FileNameJoin @ { $scratch, "project2" };

    (* Gate for the connection tests: *)
    ifConnTests // ClearAll;
    ifConnTests // Attributes = { HoldFirst };
    ifConnTests[ eval_ ] := If[ TrueQ @ $acpConnTestsQ, eval, Missing[ "TestSkipped" ] ];

    (* Waiting with Pause lets scheduled tasks (ACPLink's reader, the publisher, acpSchedule) run: *)
    waitUntil // ClearAll;
    waitUntil // Attributes = { HoldFirst };
    waitUntil[ cond_, timeout_: 15 ] := Module[ { deadline = AbsoluteTime[ ] + timeout },
        While[ ! TrueQ @ cond && AbsoluteTime[ ] < deadline, Pause[ 0.05 ] ];
        TrueQ @ cond
    ];

    (* The mock agent as an ACP agent; every connection gets its own wire log *)
    $mockLogs = { };
    $mockProcessScenario = None;
    newMockLog[ ] := With[ { file = FileNameJoin @ { $scratch, "mock-" <> ToString[ Length @ $mockLogs + 1 ] <> ".log" } },
        AppendTo[ $mockLogs, file ];
        file
    ];
    $acpAgents[ "MockACPAgent" ] = <|
        "Name"        -> "MockACPAgent",
        "Executable"  -> $python,
        "Arguments"   :> Join[
            { $mockScript, "--log", newMockLog[ ], "--idle-timeout", "120", "--max-lifetime", "600" },
            If[ StringQ @ $mockProcessScenario, { "--scenario", $mockProcessScenario }, { } ]
        ],
        "Environment" -> Inherited
    |>;

    (* Wire log of the mock (one JSON object per line) *)
    (* One read of the file's current contents (ReadList on a file that the mock is still appending to can return the
       same line over and over, until the kernel runs out of memory); an unterminated last line is left for later *)
    mockRecords[ file_String ] := Module[ { bytes = Quiet @ ReadByteArray @ file, text, lines },
        text  = If[ ByteArrayQ @ bytes, ByteArrayToString[ bytes, "UTF-8" ], "" ];
        lines = StringSplit[ text, "\n" ];
        If[ lines =!= { } && ! StringEndsQ[ text, "\n" ], lines = Most @ lines ];
        Select[ Quiet[ Developer`ReadRawJSONString /@ lines ], AssociationQ ]
    ];
    mockIn[ file_String ] := Cases[ mockRecords @ file, KeyValuePattern @ { "dir" -> "in", "msg" -> m_Association } :> m ];
    mockOut[ file_String ] := Cases[ mockRecords @ file, KeyValuePattern @ { "dir" -> "out", "msg" -> m_Association } :> m ];
    mockRequestsIn[ file_String, method_String ] := Select[ mockIn @ file, Lookup[ #, "method", None ] === method && KeyExistsQ[ #, "id" ] & ];
    mockNotificationsIn[ file_String, method_String ] := Select[ mockIn @ file, Lookup[ #, "method", None ] === method && ! KeyExistsQ[ #, "id" ] & ];
    mockResponsesIn[ file_String ] := Select[ mockIn @ file, ! KeyExistsQ[ #, "method" ] && KeyExistsQ[ #, "id" ] & ];
    mockResponsesIn[ file_String, id_ ] := Select[ mockResponsesIn @ file, #[ "id" ] === id & ];
    mockPID[ file_String ] := FirstCase[ mockRecords @ file, KeyValuePattern @ { "dir" -> "event", "event" -> "start", "pid" -> p_Integer } :> p, None ];
    lastLog[ ] := Last[ $mockLogs, None ];

    processAliveQ[ pid_Integer ] := With[ { stat = Quiet @ ReadString[ "/proc/" <> ToString @ pid <> "/stat" ] },
        StringQ @ stat && ! StringContainsQ[ stat, ") Z " ]
    ];
    processAliveQ[ _ ] := False;

    (* Windows: the same record UI.wl registers *)
    registerWindow[ nbo_, dir_, settings_Association, agent_String: "MockACPAgent" ] := acpWindowUpdate[
        nbo,
        Join[ #, Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, dir, agent, settings ] ] &
    ];
    $windows = { };
    newWindow[ dir_, settings_Association: <| |>, agent_String: "MockACPAgent" ] := With[
        { nbo = NotebookObject[ "acp-connection-test-" <> ToString[ Length @ $windows + 1 ] ] },
        AppendTo[ $windows, nbo ];
        registerWindow[ nbo, dir, settings, agent ];
        nbo
    ];

    (* Turns: the kernel-side part of UI.wl's acpStartTurn (no cells) *)
    startTurn[ nbo_, prompt_String ] := Module[ { id = "acp-turn-" <> CreateUUID[ ] },
        acpTurnCreate @ acpNewTurn @ <|
            "ID"        -> id,
            "Notebook"  -> nbo,
            "SessionID" -> acpWindowGet[ nbo, "SessionID" ],
            "Prompt"    -> prompt,
            "StartTime" -> AbsoluteTime[ ]
        |>;
        acpWindowUpdate[ nbo, <| #, "Status" -> "Running", "CurrentTurn" -> id |> & ];
        acpSendPrompt[ nbo, id ];
        id
    ];

    (* Finalized turns are dropped by UI.wl's acpFinalizeTurn (headless: there is no output cell); keep their last state *)
    $droppedTurns = <| |>;
    $savedTurnDrop = DownValues @ acpTurnDrop;
    DownValues[ acpTurnDrop ] = Prepend[
        DownValues @ acpTurnDrop,
        HoldPattern[ acpTurnDrop[ id_String ] ] :> (
            ($droppedTurns[ id ] = acpTurnGet @ id; Block[ { $inTestDrop = True }, acpTurnDrop @ id ]) /; ! TrueQ @ $inTestDrop
        )
    ];
    finalTurn[ id_String ] := Lookup[ $droppedTurns, id, Missing[ "NotFinalized" ] ];
    waitFinal[ id_String, timeout_: 15 ] := waitUntil[ AssociationQ @ finalTurn @ id, timeout ];

    pendingIDs[ nbo_ ] := Keys @ Replace[ acpWindowGet[ nbo, "PendingPermissions", <| |> ], Except[ _Association ] -> <| |> ];
    currentOption[ nbo_, category_ ] := Lookup[ acpFindConfigOption[ acpWindowGet[ nbo, "ConfigOptions", { } ], category ], "currentValue", None ];
    (* ACPConnections is looked up when the helper runs: this definition is parsed before ACPLink is loaded (above), so
       a literal ACPConnections here would be Global`ACPConnections and the helper would always give True. *)
    connectionClosedQ[ conn_ ] := ! MemberQ[ Replace[ Quiet @ acpLink[ "ACPConnections" ][ ], Except[ _List ] -> { } ], conn ];
    ,
    _,
    SameTest -> MatchQ,
    TestID   -> "ACPConnection-Definitions@@Tests/ACPConnection.wlt:42,1-193,2"
]

(* A test of its own, so that the tests after it are read with the fake ssh helpers' context on $ContextPath *)
VerificationTest[
    Get @ FileNameJoin @ { DirectoryName @ $TestFileName, "Data", "ACP", "FakeSSH.wl" };
    MemberQ[ $ContextPath, "Wolfram`ChatbookTests`ACPFakeSSH`" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPConnection-LoadFakeSSH@@Tests/ACPConnection.wlt:196,1-202,2"
]

(* Everything the remote tests run is created here, before any agent is started: chmod (RunProcess) must not run while an
   ACP reader is active *)
VerificationTest[
    $remoteTestsQ = TrueQ[ $acpConnTestsQ && $fakeSSHAvailableQ ];
    ifRemoteTests // ClearAll;
    ifRemoteTests // Attributes = { HoldFirst };
    (* The remote tests use the kernel-session store of the persisted settings ($headlessSettings), with or without a
       front end (CI runs every file under UsingFrontEnd): the values they check are written by the pump, whose writes
       do not reach the front end's preferences under UsingFrontEnd. The pump's tasks run inside the Block while the
       tests wait. The snapshot below and Cleanup-RemoteRestore use the same store. *)
    ifRemoteTests[ eval_ ] := If[ TrueQ @ $remoteTestsQ, Block[ { $FrontEnd = Null }, eval ], Missing[ "TestSkipped" ] ];

    (* The value of a variable that the launch script exports remotely (quotes, $, backquotes, backslash, UTF-8) *)
    $remoteVarValue = "it's \"q\" $HOME `x` \\ \[Alpha]";
    (* Hosts whose persisted settings ({"SSH", host, ...}) the tests change; restored by Cleanup-RemoteRestore *)
    $remoteHostKeys = { "testhost", "otherhost", "tester@testhost", "x.fail-auth.test", "x.slow.test", "x.drop.test", "x.signal.test" };
    $savedRemotePersisted = Block[ { $FrontEnd = Null },
        AssociationMap[
            acpPersistedSetting,
            Catenate @ Table[ { { "SSH", host, "LastProjectDirectory" }, { "SSH", host, "Home" } }, { host, $remoteHostKeys } ]
        ]
    ];
    (* Hosts whose failure latch and sign-in failure times (Remote.wl) the tests may set; cleared by Cleanup-RemoteRestore *)
    $remoteTestHosts = Union[
        $remoteHostKeys,
        {
            "x.fail-hostkey.test", "x.fail-changed.test", "x.fail-keyperm.test", "x.fail-refused.test", "x.fail-dns.test",
            "x.fail-timeout.test", "x.fail-closed.test", "x.hang.test", "x.exit-home.test", "x.reject.test"
        }
    ];

    If[ TrueQ @ $remoteTestsQ,
        fakeSSHSetup @ FileNameJoin @ { $scratch, "fake" };
        $remoteHome = $fakeSSH[ "Home" ];
        CreateDirectory @ FileNameJoin @ { $remoteHome, # } & /@ { "proj", "proj2", "proj3", "proj4" };
        (* An ssh that rejects its arguments the way OpenSSH does (the fake ssh does not check -o keys) *)
        $badSSH = FileNameJoin @ { $scratch, "fake", "bin", "bad-ssh" };
        WriteString[ $badSSH, "#!/bin/sh\nprintf 'command-line: line 0: Bad configuration option: bogus\\r\\n' >&2\nexit 255\n" ];
        Close @ $badSSH;
        RunProcess[ { "chmod", "755", $badSSH } ];
        (* An agent that answers "initialize", reads the next request and kills itself (SIGKILL) *)
        $killerScript = FileNameJoin @ { $scratch, "killer.py" };
        WriteString[
            $killerScript,
            StringRiffle[
                {
                    "import json, os, signal, sys",
                    "msg = json.loads(sys.stdin.readline())",
                    "sys.stdout.write(json.dumps({'jsonrpc': '2.0', 'id': msg['id'], 'result': {'protocolVersion': 1, 'agentCapabilities': {}}}) + '\\n')",
                    "sys.stdout.flush()",
                    "sys.stdin.readline()",
                    "os.kill(os.getpid(), signal.SIGKILL)"
                },
                "\n"
            ] <> "\n"
        ];
        Close @ $killerScript
    ];

    (* The mock agent with a variable for the remote side, and the agent that kills itself *)
    $acpAgents[ "MockACPAgentVars" ] = Append[ $acpAgents[ "MockACPAgent" ], "Variables" :> <| "MOCK_REMOTE_VAR" -> $remoteVarValue |> ];
    $acpAgents[ "MockKiller" ] = <| "Name" -> "MockKiller", "Executable" -> $python, "Arguments" :> { $killerScript }, "Environment" -> Inherited |>;

    (* Canonical "SSHSettings" of a fake ssh host *)
    remoteSSH[ host_String: "testhost", extra___Rule ] := Wolfram`Chatbook`Common`acpSSHSettings @ fakeSSHSettings[ host, extra ];
    newRemoteWindow[ dir_, ssh_, extra_Association: <| |>, agent_String: "MockACPAgent" ] :=
        newWindow[ dir, <| "SSHSettings" -> ssh, extra |>, agent ];
    statusQ[ nbo_, status_ ] := acpWindowGet[ nbo, "Status" ] === status;
    errorOf[ nbo_ ] := Replace[ acpWindowGet[ nbo, "Error", None ], Except[ _Association ] -> <| |> ];
    mockStart[ file_String ] := FirstCase[ mockRecords @ file, KeyValuePattern @ { "dir" -> "event", "event" -> "start" }, None ];
    mockEventQ[ file_String, name_String ] := MemberQ[ mockRecords @ file, KeyValuePattern @ { "dir" -> "event", "event" -> name } ];
    (* "initialize" writes that failed since t0 (Connection.wl logs every failed write) *)
    initSendFailures[ t0_ ] := Count[
        Internal`BagPart[ $acpDebugLog, All ],
        KeyValuePattern @ { "Time" -> t_ /; t >= t0, "Where" -> "SendFailed", "Data" -> KeyValuePattern[ "Method" -> "initialize" ] }
    ];

    (* acpReuseWindow (ShowNotebookAssistance on the open window) without a front end *)
    reuseWindow[ nbo_, settings_Association ] := Block[
        {
            acpCheckSession                               = True &,
            Wolfram`Chatbook`Common`moveToChatInputField = Null &,
            SetSelectedNotebook                           = Null &
        },
        Wolfram`Chatbook`ACP`UI`Private`acpReuseWindow[ None, nbo, settings ]
    ];

    (* ACPLink's private state: whether it still holds the launch script of the connection's process, and the number of
       messages queued behind it (test-only peek) *)
    pendingPreamble[ conn_ ] := Module[ { process, pending },
        process = Symbol[ "ACPLink`ACP`InternalSymbols`lookupInACPConnectionData" ][
            Symbol[ "ACPLink`ACP`InternalSymbols`$acpConnections" ][ conn ],
            Symbol[ "ACPLink`JSONRPCProcess`CommonSymbols`JSONRPCProcess" ]
        ];
        pending = Symbol[ "ACPLink`JSONRPCProcess`InternalSymbols`$pendingStandardInputPreambles" ];
        If[ AssociationQ @ pending && KeyExistsQ[ pending, process ],
            { True, Length @ Lookup[ pending[ process ], "Queue", { } ] },
            { False, 0 }
        ]
    ];
    ,
    _,
    SameTest -> MatchQ,
    TestID   -> "ACPConnection-RemoteDefinitions@@Tests/ACPConnection.wlt:206,1-308,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Agents*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*OpenCode Configuration*)
VerificationTest[
    Developer`ReadRawJSONString @ acpOpenCodeConfigJSON[ ],
    <|
        "$schema"    -> "https://opencode.ai/config.json",
        "permission" -> <|
            "edit"                          -> "ask",
            "bash"                          -> "ask",
            "WolframNotebooks_InsertCells"  -> "ask",
            "WolframNotebooks_ReplaceCells" -> "ask",
            "WolframNotebooks_DeleteCells"  -> "ask"
        |>
    |>,
    SameTest -> MatchQ,
    TestID   -> "OpenCodeConfigJSON-NoLLMKit@@Tests/ACPConnection.wlt:317,1-331,2"
]

VerificationTest[
    Module[ { config, provider },
        config   = Developer`ReadRawJSONString @ acpOpenCodeConfigJSON @ True;
        provider = config[ "provider", "llmkit" ];
        {
            config[ "permission" ],
            provider[ "npm" ],
            provider[ "options", "baseURL" ],
            provider[ "options", "headers", "Authorization" ],
            Sort @ Keys @ provider[ "models" ],
            AllTrue[ Values @ provider[ "models" ], MatchQ[ #, KeyValuePattern @ { "tool_call" -> True, "limit" -> KeyValuePattern @ { "context" -> _Integer, "output" -> _Integer } } ] & ],
            KeyExistsQ[ config, "enabled_providers" ]
        }
    ],
    {
        <|
            "edit"                          -> "ask",
            "bash"                          -> "ask",
            "WolframNotebooks_InsertCells"  -> "ask",
            "WolframNotebooks_ReplaceCells" -> "ask",
            "WolframNotebooks_DeleteCells"  -> "ask"
        |>,
        "@ai-sdk/openai-compatible",
        "https://services.wolfram.com/api/llmkit/v1",
        "Bearer {env:LLMKIT_API_KEY}",
        Sort @ { "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano", "gpt-4o", "gpt-4o-mini", "gpt-5-mini", "gpt-5-nano", "gpt-5.2", "gpt-5.4", "gpt-5.4-mini", "gpt-5.4-nano" },
        True,
        False
    },
    SameTest -> MatchQ,
    TestID   -> "OpenCodeConfigJSON-LLMKit@@Tests/ACPConnection.wlt:333,1-364,2"
]

VerificationTest[
    Module[ { env },
        env = acpOpenCodeEnvironment @ None;
        {
            AssociationQ @ env,
            Lookup[ env, "PATH" ] === Environment[ "PATH" ],
            KeyExistsQ[ env, "LLMKIT_API_KEY" ],
            Developer`ReadRawJSONString @ env[ "OPENCODE_CONFIG_CONTENT" ] === Developer`ReadRawJSONString @ acpOpenCodeConfigJSON @ False,
            KeyExistsQ[ env, "OPENCODE_CONFIG_DIR" ] && ! StringQ @ Environment[ "OPENCODE_CONFIG_DIR" ]
        }
    ],
    { True, True, False, True, False },
    SameTest -> MatchQ,
    TestID   -> "OpenCodeEnvironment-NoKey@@Tests/ACPConnection.wlt:366,1-380,2"
]

VerificationTest[
    Module[ { env },
        env = acpOpenCodeEnvironment[ "fake-llmkit-key-for-tests" ];
        {
            env[ "LLMKIT_API_KEY" ],
            KeyExistsQ[ Developer`ReadRawJSONString @ env[ "OPENCODE_CONFIG_CONTENT" ], "provider" ],
            StringContainsQ[ env[ "OPENCODE_CONFIG_CONTENT" ], "fake-llmkit-key-for-tests" ]
        }
    ],
    { "fake-llmkit-key-for-tests", True, False },
    SameTest -> MatchQ,
    TestID   -> "OpenCodeEnvironment-Key@@Tests/ACPConnection.wlt:382,1-394,2"
]

VerificationTest[
    (* ACPLink fails the open (::envval) for an explicit variable with "=" in its value and a name that is not a valid
       shell name, such as an exported bash function; such variables are left out *)
    Module[ { vars, env },
        vars = <| "ACPTEST_FUNC%%" -> "() { x=1; }", "ACPTEST_EQ" -> "a=b", "ACPTEST_PLAIN%%" -> "plain" |>;
        WithCleanup[
            SetEnvironment @ Normal @ vars,
            env = acpOpenCodeEnvironment @ None;
            KeyTake[ env, Keys @ vars ],
            SetEnvironment[ # -> None ] & /@ Keys @ vars
        ]
    ],
    <| "ACPTEST_EQ" -> "a=b", "ACPTEST_PLAIN%%" -> "plain" |>,
    TestID -> "OpenCodeEnvironment-UnpassableVariables@@Tests/ACPConnection.wlt:396,1-410,2"
]

VerificationTest[
    (* Disabled in these tests: no network request is made *)
    acpLLMKitAPIKey[ ],
    None,
    SameTest -> MatchQ,
    TestID   -> "LLMKitAPIKey-Disabled@@Tests/ACPConnection.wlt:412,1-418,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*LLMKit Key Discovery*)
VerificationTest[
    grantPermission[ g_String ] := <| "wolframKeyPermissionId" -> <| "grantImmutableId" -> g |>, "grant" -> <| "immutableId" -> g, "displayName" -> g |> |>;
    keyRecord[ name_, key_, status_, grants_List ] := <| "name" -> name, "apiKey" -> key, "status" -> status, "permissions" -> grantPermission /@ grants |>;

    (* $mockKeyState: <| "ListStatus", "Keys", "Grants", "CreateSucceeds" |>; every request is recorded in $mockRequests *)
    mockKeysRequest[ method_, endpoint_, body_ ] := (
        AppendTo[ $mockRequests, { method, endpoint, body } ];
        Switch[ { method, endpoint },
            { "GET", "keys" },
                If[ Lookup[ $mockKeyState, "ListStatus", 200 ] === 200,
                    <| "StatusCode" -> 200, "Body" -> <| "success" -> True, "data" -> $mockKeyState[ "Keys" ] |> |>,
                    <| "StatusCode" -> $mockKeyState[ "ListStatus" ], "Body" -> <| |> |>
                ],
            { "GET", "permissions" },
                <| "StatusCode" -> 200, "Body" -> <| "success" -> True, "data" -> (<| "permissionId" -> <| "grantImmutableId" -> # |> |> & /@ $mockKeyState[ "Grants" ]) |> |>,
            { "POST", "keys" },
                If[ TrueQ @ $mockKeyState[ "CreateSucceeds" ],
                    $mockKeyState[ "Keys" ] = Append[ $mockKeyState[ "Keys" ], keyRecord[ body[ "name" ], "fake-created-key", "Active", body[ "permissions" ] ] ];
                    <| "StatusCode" -> 200, "Body" -> <| "success" -> True, "data" -> <| "name" -> body[ "name" ] |> |> |>,
                    <| "StatusCode" -> 400, "Body" -> <| "success" -> False |> |>
                ],
            _,
                Failure[ "Unexpected", <| |> ]
        ]
    );
    findKey[ state_Association, createQ_ ] := Block[ { $mockKeyState = state, $mockRequests = { } },
        { acpFindLLMKitKey[ mockKeysRequest, createQ ], $mockRequests }
    ],
    _,
    SameTest -> MatchQ,
    TestID   -> "LLMKitKey-Definitions@@Tests/ACPConnection.wlt:423,1-454,2"
]

VerificationTest[
    findKey[
        <|
            "Keys" -> {
                keyRecord[ "No grant", "fake-key-a", "Active", { "MCPAPIs" } ],
                keyRecord[ "Disabled", "fake-key-b", "Inactive", { "LLMKitAPIs" } ],
                keyRecord[ "Good", "fake-key-c", "Active", { "AgentOne", "LLMKitAPIs" } ]
            },
            "Grants" -> { "LLMKitAPIs" }
        |>,
        (True &)
    ],
    { <| "Key" -> "fake-key-c", "Status" -> "Found", "Definitive" -> True |>, { { "GET", "keys", None } } },
    SameTest -> MatchQ,
    TestID   -> "LLMKitKey-UsesActiveKeyWithGrant@@Tests/ACPConnection.wlt:456,1-471,2"
]

VerificationTest[
    findKey[ <| "Keys" -> { keyRecord[ "No grant", "fake-key-a", "Active", { "MCPAPIs", "AgentOne" } ] }, "Grants" -> { "AgentOne", "MCPAPIs" } |>, (True &) ],
    { <| "Key" -> None, "Status" -> "NoPermission", "Definitive" -> True |>, { { "GET", "keys", None }, { "GET", "permissions", None } } },
    SameTest -> MatchQ,
    TestID   -> "LLMKitKey-NeverUsesKeysWithoutGrant@@Tests/ACPConnection.wlt:473,1-478,2"
]

VerificationTest[
    findKey[ <| "Keys" -> { }, "Grants" -> { "LLMKitAPIs" }, "CreateSucceeds" -> True |>, (True &) ],
    {
        <| "Key" -> "fake-created-key", "Status" -> "Created", "Definitive" -> True |>,
        {
            { "GET", "keys", None },
            { "GET", "permissions", None },
            { "POST", "keys", KeyValuePattern @ { "name" -> "Chatbook ACP access to LLMKit", "permissions" -> { "LLMKitAPIs" } } },
            { "GET", "keys", None }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "LLMKitKey-CreatesKey@@Tests/ACPConnection.wlt:480,1-493,2"
]

VerificationTest[
    findKey[ <| "Keys" -> { }, "Grants" -> { "LLMKitAPIs" }, "CreateSucceeds" -> True |>, (False &) ],
    { <| "Key" -> None, "Status" -> "CreationNotAllowed", "Definitive" -> False |>, { { "GET", "keys", None }, { "GET", "permissions", None } } },
    SameTest -> MatchQ,
    TestID   -> "LLMKitKey-CreationNotAllowed@@Tests/ACPConnection.wlt:495,1-500,2"
]

VerificationTest[
    findKey[
        <| "Keys" -> { keyRecord[ "Chatbook ACP access to LLMKit", "fake-key-d", "Inactive", { "LLMKitAPIs" } ] }, "Grants" -> { "LLMKitAPIs" }, "CreateSucceeds" -> True |>,
        (True &)
    ],
    { <| "Key" -> None, "Status" -> "KeyNameTaken", "Definitive" -> True |>, { { "GET", "keys", None }, { "GET", "permissions", None } } },
    SameTest -> MatchQ,
    TestID   -> "LLMKitKey-NoSecondKeyWithSameName@@Tests/ACPConnection.wlt:502,1-510,2"
]

VerificationTest[
    {
        First @ findKey[ <| "ListStatus" -> 500, "Keys" -> { }, "Grants" -> { } |>, (True &) ],
        acpFindLLMKitKey[ Function[ { m, e, b }, Throw[ "boom", "ACPConnectionTest" ] ], (True &) ],
        acpFindLLMKitKey[ Function[ { m, e, b }, $Failed ], (True &) ]
    },
    {
        <| "Key" -> None, "Status" -> "ListFailed", "Definitive" -> False |>,
        KeyValuePattern @ { "Key" -> None, "Definitive" -> False, "Status" -> _String },
        <| "Key" -> None, "Status" -> "ListFailed", "Definitive" -> False |>
    },
    SameTest -> MatchQ,
    TestID   -> "LLMKitKey-Failures@@Tests/ACPConnection.wlt:512,1-525,2"
]

VerificationTest[
    (* The session-level function: cached, and at most one creation attempt per session (also if it fails) *)
    Block[
        {
            $mockKeyState  = <| "Keys" -> { }, "Grants" -> { "LLMKitAPIs" }, "CreateSucceeds" -> False |>,
            $mockRequests  = { },
            $acpLLMKitEnabled = True,
            Wolfram`Chatbook`ACP`Agents`Private`wolframKeysRequest        = mockKeysRequest,
            Wolfram`Chatbook`ACP`Agents`Private`cloudConnectedQ           = (True &),
            Wolfram`Chatbook`ACP`Agents`Private`$llmKitKeyCache           = None,
            Wolfram`Chatbook`ACP`Agents`Private`$llmKitCreationAttempted  = False
        },
        {
            acpLLMKitAPIKey[ ],
            acpLLMKitAPIKey[ ],
            Count[ $mockRequests, { "POST", ___ } ],
            Wolfram`Chatbook`ACP`Agents`Private`$llmKitCreationAttempted
        }
    ],
    { None, None, 1, True },
    SameTest -> MatchQ,
    TestID   -> "LLMKitAPIKey-CreationAttemptedOnce@@Tests/ACPConnection.wlt:527,1-549,2"
]

VerificationTest[
    Block[
        {
            $mockKeyState  = <| "Keys" -> { keyRecord[ "Good", "fake-key-c", "Active", { "LLMKitAPIs" } ] }, "Grants" -> { "LLMKitAPIs" } |>,
            $mockRequests  = { },
            $acpLLMKitEnabled = True,
            Wolfram`Chatbook`ACP`Agents`Private`wolframKeysRequest        = mockKeysRequest,
            Wolfram`Chatbook`ACP`Agents`Private`cloudConnectedQ           = (True &),
            Wolfram`Chatbook`ACP`Agents`Private`$llmKitKeyCache           = None,
            Wolfram`Chatbook`ACP`Agents`Private`$llmKitCreationAttempted  = False
        },
        {
            acpLLMKitAPIKey[ ],
            acpLLMKitAPIKey[ ],
            Length @ $mockRequests,
            (* Never logged: *)
            FreeQ[ Internal`BagPart[ $acpDebugLog, All ], "fake-key-c" ],
            (* Not cloud connected: no requests *)
            Block[ { Wolfram`Chatbook`ACP`Agents`Private`cloudConnectedQ = (False &), Wolfram`Chatbook`ACP`Agents`Private`$llmKitKeyCache = None },
                acpLLMKitAPIKey[ ]
            ],
            Length @ $mockRequests
        }
    ],
    { "fake-key-c", "fake-key-c", 1, True, None, 1 },
    SameTest -> MatchQ,
    TestID   -> "LLMKitAPIKey-Cached@@Tests/ACPConnection.wlt:551,1-578,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Models and Billing*)
VerificationTest[
    modelOptions[ values_List, current_String ] := {
        <| "id" -> "model", "name" -> "Model", "category" -> "model", "type" -> "select", "currentValue" -> current,
           "options" -> (<| "value" -> #, "name" -> # |> & /@ values) |>,
        <| "id" -> "mode", "name" -> "Session Mode", "category" -> "mode", "type" -> "select", "currentValue" -> "build",
           "options" -> { <| "value" -> "build", "name" -> "Build" |>, <| "value" -> "plan", "name" -> "Plan" |> } |>
    };
    $openCodeModels = { "openai/gpt-6.1-sol", "openai/gpt-6-luna", "opencode/big-pickle", "opencode/exo-free" };
    {
        acpPreferredModel @ modelOptions[ $openCodeModels, "opencode/exo-free" ],
        acpPreferredModel @ modelOptions[ Append[ $openCodeModels, "llmkit/gpt-5.4" ], "opencode/exo-free" ],
        acpPreferredModel[ modelOptions[ $openCodeModels, "opencode/exo-free" ], <| "LastUsed" -> "opencode/big-pickle" |> ],
        acpPreferredModel[ modelOptions[ $openCodeModels, "opencode/exo-free" ], <| "Requested" -> "openai/gpt-6-luna", "LastUsed" -> "opencode/big-pickle" |> ],
        acpPreferredModel[ modelOptions[ $openCodeModels, "opencode/exo-free" ], <| "Requested" -> "not/offered", "LastUsed" -> "also/not-offered" |> ],
        acpPreferredModel[ modelOptions[ $openCodeModels, "opencode/exo-free" ], <| "FailedModels" -> { "openai/gpt-6.1-sol" } |> ],
        acpPreferredModel @ modelOptions[ { "a/m1", "b/m2" }, "b/m2" ],
        acpPreferredModel @ { },
        (* Grouped options *)
        acpPreferredModel @ {
            <| "id" -> "model", "category" -> "model", "type" -> "select", "currentValue" -> "x/y",
               "options" -> { <| "group" -> "openai", "name" -> "OpenAI", "options" -> { <| "value" -> "openai/gpt-6.1-sol", "name" -> "GPT" |> } |> } |>
        }
    },
    {
        "openai/gpt-6.1-sol",
        "llmkit/gpt-5.4",
        "opencode/big-pickle",
        "openai/gpt-6-luna",
        "openai/gpt-6.1-sol",
        "opencode/exo-free",
        "b/m2",
        Missing[ "NotAvailable" ],
        "openai/gpt-6.1-sol"
    },
    SameTest -> MatchQ,
    TestID   -> "PreferredModel@@Tests/ACPConnection.wlt:583,1-619,2"
]

VerificationTest[
    acpBillingLabel /@ {
        "llmkit/gpt-5.4",
        "openai/gpt-6.1-sol",
        "opencode/big-pickle",
        "opencode/ling-3.1-flash-free",
        "opencode/gpt-5-zen",
        "anthropic/claude-sonnet",
        "mistral/large",
        "m1",
        None
    },
    {
        "Wolfram LLMKit",
        "OpenAI (your account)",
        "OpenCode (free)",
        "OpenCode (free)",
        "OpenCode Zen",
        "Anthropic (your account)",
        "mistral",
        "",
        ""
    },
    SameTest -> MatchQ,
    TestID   -> "BillingLabel@@Tests/ACPConnection.wlt:621,1-646,2"
]

VerificationTest[
    {
        acpFindConfigOption[ modelOptions[ { "a/b" }, "a/b" ], "mode" ][ "id" ],
        acpFindConfigOption[ { <| "id" -> "effort", "type" -> "select", "currentValue" -> "high", "options" -> { } |> }, "thought_level" ][ "id" ],
        acpFindConfigOption[ { }, "model" ],
        acpOptionValues @ First @ modelOptions[ { "a/b", "c/d" }, "a/b" ]
    },
    { "mode", "effort", Missing[ "NotAvailable" ], { "a/b", "c/d" } },
    SameTest -> MatchQ,
    TestID   -> "FindConfigOption@@Tests/ACPConnection.wlt:648,1-658,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Executable Discovery*)
VerificationTest[
    $exeRoot  = CreateDirectory @ FileNameJoin @ { $scratch, "exe" };
    $pathDir1 = CreateDirectory @ FileNameJoin @ { $exeRoot, "bin1" };
    $pathDir2 = CreateDirectory @ FileNameJoin @ { $exeRoot, "bin2" };
    $fakeHome = CreateDirectory @ FileNameJoin @ { $exeRoot, "home" };
    CreateDirectory[ FileNameJoin @ { $fakeHome, ".opencode", "bin" }, CreateIntermediateDirectories -> True ];
    CreateDirectory @ FileNameJoin @ { $pathDir1, "opencode" }; (* a directory is not an executable *)
    $pathExe = FileNameJoin @ { $pathDir2, "opencode" };
    $homeExe = FileNameJoin @ { $fakeHome, ".opencode", "bin", "opencode" };
    Export[ $pathExe, "#!/bin/sh\n", "Text" ];
    Export[ $homeExe, "#!/bin/sh\n", "Text" ];
    Export[ FileNameJoin @ { $pathDir2, "myagent" }, "#!/bin/sh\n", "Text" ];
    FileExistsQ /@ { $pathExe, $homeExe },
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "FindProgram-Setup@@Tests/ACPConnection.wlt:663,1-679,2"
]

VerificationTest[
    {
        (* the first match in PATH (a directory named opencode is not a program) *)
        acpFindProgram[ "opencode", <| "PATH" -> StringRiffle[ { $pathDir1, $pathDir2 }, ":" ], "HomeDirectory" -> $fakeHome, "OperatingSystem" -> "Unix" |> ],
        (* then the install directories in the home directory *)
        acpFindProgram[ "opencode", <| "PATH" -> $pathDir1, "HomeDirectory" -> $fakeHome, "OperatingSystem" -> "Unix" |> ],
        (* a path is used as given *)
        acpFindProgram[ $homeExe, <| "PATH" -> $pathDir2, "HomeDirectory" -> $fakeHome, "OperatingSystem" -> "Unix" |> ],
        acpFindProgram[ $pathExe, <| "PATH" -> "", "HomeDirectory" -> None, "OperatingSystem" -> "Unix" |> ],
        (* any command name, also from the system directories *)
        acpFindProgram[ "myagent", <| "PATH" -> $pathDir1, "HomeDirectory" -> None, "OperatingSystem" -> "Unix", "SystemDirectories" -> { $pathDir2 } |> ]
    },
    { $pathExe, $homeExe, $homeExe, $pathExe, FileNameJoin @ { $pathDir2, "myagent" } },
    SameTest -> MatchQ,
    TestID   -> "FindProgram-Found@@Tests/ACPConnection.wlt:681,1-696,2"
]

VerificationTest[
    {
        acpFindProgram[ "opencode", <| "PATH" -> $pathDir1, "HomeDirectory" -> $exeRoot, "OperatingSystem" -> "Unix" |> ],
        acpFindProgram[ FileNameJoin @ { $exeRoot, "missing" }, <| "PATH" -> $pathDir2, "HomeDirectory" -> $fakeHome, "OperatingSystem" -> "Unix" |> ],
        (* a path to a directory *)
        acpFindProgram[ FileNameJoin @ { $pathDir1, "opencode" }, <| "PATH" -> $pathDir2, "HomeDirectory" -> None, "OperatingSystem" -> "Unix" |> ],
        acpFindProgram[ "myagent", <| "PATH" -> $pathDir1, "HomeDirectory" -> None, "OperatingSystem" -> "Unix" |> ]
    },
    { None, None, None, None },
    SameTest -> MatchQ,
    TestID   -> "FindProgram-NotFound@@Tests/ACPConnection.wlt:698,1-709,2"
]

VerificationTest[
    Module[ { winDir, exe },
        winDir = CreateDirectory @ FileNameJoin @ { $exeRoot, "win" };
        exe = FileNameJoin @ { winDir, "opencode.exe" };
        Export[ exe, "", "Text" ];
        {
            acpFindProgram[ "opencode", <| "PATH" -> "\"" <> $pathDir1 <> "\";" <> winDir, "HomeDirectory" -> None, "OperatingSystem" -> "Windows" |> ] === exe,
            acpFindProgram[ "opencode.exe", <| "PATH" -> winDir, "HomeDirectory" -> None, "OperatingSystem" -> "Windows" |> ] === exe
        }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "FindProgram-Windows@@Tests/ACPConnection.wlt:711,1-724,2"
]

(* The "ACPAgentCommandLine" setting: a program gets the agent's arguments, a list is the whole command line *)
VerificationTest[
    Module[ { env, missing, command },
        env     = <| "PATH" -> $pathDir2, "HomeDirectory" -> None, "OperatingSystem" -> "Unix" |>;
        missing = FileNameJoin @ { $exeRoot, "missing" };
        command = acpAgentSpec[ "OpenCode", <| "ACPAgentCommandLine" -> # |>, env ][ "Command" ] &;
        {
            acpAgentSpec[ "OpenCode", <| |>, env ][ "Command" ],
            command @ Automatic,
            command @ "  ",
            command @ $homeExe,
            command @ File @ $homeExe,
            command @ "opencode",
            command @ { "opencode", "acp", "--print-logs" },
            command @ { File @ $homeExe, "acp" },
            command @ { $homeExe },
            acpAgentSpec[ "OpenCode", <| "ACPAgentCommandLine" -> { "no-such-program", "acp" } |>, env ],
            acpAgentSpec[ "OpenCode", <| "ACPAgentCommandLine" -> missing |>, env ],
            acpAgentSpec[ "OpenCode", <| |>, <| "PATH" -> $pathDir1, "HomeDirectory" -> None, "OperatingSystem" -> "Unix" |> ]
        }
    ],
    {
        { $pathExe, "acp" },
        { $pathExe, "acp" },
        { $pathExe, "acp" },
        { $homeExe, "acp" },
        { $homeExe, "acp" },
        { $pathExe, "acp" },
        { $pathExe, "acp", "--print-logs" },
        { $homeExe, "acp" },
        { $homeExe },
        Failure[ "AgentNotFound", KeyValuePattern @ { "Agent" -> "OpenCode", "Path" -> "no-such-program" } ],
        Failure[ "AgentNotFound", KeyValuePattern @ { "Path" -> FileNameJoin @ { $exeRoot, "missing" } } ],
        (* not found without an explicit command line: no path, the install URL *)
        Failure[ "AgentNotFound", KeyValuePattern @ { "Agent" -> "OpenCode", "Path" -> None, "InstallURL" -> "https://opencode.ai" } ]
    },
    SameTest -> MatchQ,
    TestID   -> "AgentSpec-CommandLine@@Tests/ACPConnection.wlt:727,1-764,2"
]

VerificationTest[
    Module[ { env, spec, custom },
        env    = <| "PATH" -> $pathDir2, "HomeDirectory" -> None, "OperatingSystem" -> "Unix" |>;
        spec   = acpAgentSpec[ "OpenCode", <| "ACPAgentCommandLine" -> $pathExe |>, env ];
        custom = Block[
            {
                $acpAgents = <|
                    $acpAgents,
                    "Custom"   -> <| "Name" -> "Custom Agent", "Executable" -> "myagent", "Arguments" -> { "--acp" } |>,
                    "Function" -> <| "Name" -> "Function Agent", "Executable" -> (FileNameJoin @ { $pathDir2, "myagent" } &) |>,
                    "Missing"  -> <| "Name" -> "Missing Agent", "Executable" -> "/no/such/agent", "Arguments" -> { "--acp" } |>
                |>
            },
            {
                acpAgentSpec[ "Custom", <| |>, env ][ "Command" ],
                acpAgentSpec[ "Custom", <| "ACPAgentCommandLine" -> { $homeExe, "agent" } |>, env ][ "Command" ],
                acpAgentSpec[ "Custom", <| |>, env ][ "Environment" ],
                acpAgentSpec[ "Function", <| |>, env ][ "Command" ],
                acpAgentSpec[ "Missing", <| |>, env ]
            }
        ];
        {
            spec[ "Name" ],
            spec[ "Command" ],
            (* The environment is not evaluated until it is used: *)
            MatchQ[ Normal @ spec, { ___, "Environment" :> _, ___ } ],
            KeyExistsQ[ spec[ "Environment" ], "OPENCODE_CONFIG_CONTENT" ],
            custom,
            acpAgentSpec[ "NoSuchAgent", <| |> ]
        }
    ],
    {
        "OpenCode",
        { $pathExe, "acp" },
        True,
        True,
        {
            { FileNameJoin @ { $pathDir2, "myagent" }, "--acp" },
            { $homeExe, "agent" },
            Inherited,
            { FileNameJoin @ { $pathDir2, "myagent" } },
            Failure[ "AgentNotFound", KeyValuePattern @ { "Agent" -> "Missing Agent", "Path" -> None } ]
        },
        Failure[ "UnknownAgent", KeyValuePattern[ "Agent" -> "NoSuchAgent" ] ]
    },
    SameTest -> MatchQ,
    TestID   -> "AgentSpec@@Tests/ACPConnection.wlt:766,1-813,2"
]

VerificationTest[
    {
        acpCommandLineSetting @ <| |>,
        acpCommandLineSetting @ <| "ACPAgentCommandLine" -> Automatic |>,
        acpCommandLineSetting @ <| "ACPAgentCommandLine" -> " /opt/oc " |>,
        acpCommandLineSetting @ <| "ACPAgentCommandLine" -> File[ "/opt/oc" ] |>,
        acpCommandLineSetting @ <| "ACPAgentCommandLine" -> { "ssh", "host", "opencode acp" } |>,
        acpCommandLineSetting @ <| "ACPAgentCommandLine" -> { File[ "/opt/oc" ], "acp" } |>,
        acpCommandLineSetting @ <| "ACPAgentCommandLine" -> { } |>,
        acpCommandLineSetting @ <| "ACPAgentCommandLine" -> { " ", "acp" } |>,
        acpCommandLineSetting @ <| "ACPAgentCommandLine" -> { "a", 1 } |>
    },
    {
        None,
        None,
        { "Program", "/opt/oc" },
        { "Program", "/opt/oc" },
        { "CommandLine", { "ssh", "host", "opencode acp" } },
        { "CommandLine", { "/opt/oc", "acp" } },
        None,
        None,
        None
    },
    SameTest -> MatchQ,
    TestID   -> "CommandLineSetting@@Tests/ACPConnection.wlt:815,1-840,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Persisted Settings*)
(* Headless also when the test kernel has a front end (CI runs under UsingFrontEnd): the front end's preferences are
   never written, and the store is the test's own *)
VerificationTest[
    Block[
        {
            $FrontEnd = Null,
            Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings = Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings
        },
        {
            acpPersistedSetting[ { "LastModel", "TestAgent" } ],
            acpSetPersistedSetting[ { "LastModel", "TestAgent" }, "m2" ],
            acpPersistedSetting[ { "LastModel", "TestAgent" } ],
            acpPersistedSetting[ { "LastEffort", "TestAgent" }, None ],
            acpSetPersistedSetting[ { "LastModel", "TestAgent" }, Inherited ],
            acpPersistedSetting[ { "LastModel", "TestAgent" }, "default" ]
        }
    ],
    { Missing[ "NotSet" ], "m2", "m2", None, Inherited, "default" },
    SameTest -> MatchQ,
    TestID   -> "PersistedSettings-Headless@@Tests/ACPConnection.wlt:847,1-865,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Errors*)
VerificationTest[
    acpErrorInfo[ -32603, "Internal error: Model exo-free has been deprecated.", <| "service" -> "session", "errorName" -> "provider.invalid-request" |>, <| "Model" -> "opencode/exo-free" |> ],
    KeyValuePattern @ {
        "Code"    -> "ModelUnavailable",
        "Message" -> _String? (StringContainsQ[ "opencode/exo-free" ]),
        "Detail"  -> "Internal error: Model exo-free has been deprecated.",
        "Actions" -> { "ChooseModel" },
        "Data"    -> KeyValuePattern[ "ErrorCode" -> -32603 ]
    },
    SameTest -> MatchQ,
    TestID   -> "ErrorInfo-ModelUnavailable@@Tests/ACPConnection.wlt:870,1-881,2"
]

VerificationTest[
    Lookup[
        {
            acpErrorInfo[ -32000, "Authentication required" ],
            acpErrorInfo[ -32603, "Internal error: No models are available", <| "errorName" -> "CatalogNotReady" |> ],
            acpErrorInfo[ -32603, "Upstream request failed", <| "errorName" -> "provider.rate-limit" |> ],
            acpErrorInfo[ -32603, "Something else" ],
            acpErrorInfo[ -32603, "Something else", None, <| "Default" -> "InitFailed" |> ],
            acpErrorInfo[ "NotConnected" ]
        },
        { "Code", "Actions" }
    ],
    {
        { "AuthRequired", { "SignIn", "Reconnect" } },
        { "NoModels", { "SignIn", "Reconnect" } },
        { "ProviderError", { "ChooseModel" } },
        { "AgentError", { } },
        { "InitFailed", { "Reconnect" } },
        { "NotConnected", { "Reconnect" } }
    },
    SameTest -> MatchQ,
    TestID   -> "ErrorInfo-Table@@Tests/ACPConnection.wlt:883,1-905,2"
]

VerificationTest[
    {
        acpErrorInfo[ "AgentExited", None, None, <| "Agent" -> "OpenCode", "ExitCode" -> 3, "StandardErrorTail" -> "line 1\nline 2\nfatal: boom\n" |> ],
        acpErrorInfo @ Failure[ "AgentNotFound", <| "Agent" -> "OpenCode", "Path" -> None, "InstallURL" -> "https://opencode.ai" |> ],
        acpErrorInfo @ Failure[ "ACPLinkMissing", <| "MessageTemplate" -> "The ACPLink paclet is required." |> ],
        acpErrorInfo @ Failure[ "UnknownAgent", <| "Agent" -> "X" |> ]
    },
    {
        KeyValuePattern @ { "Code" -> "AgentExited", "Message" -> "OpenCode stopped unexpectedly.", "Detail" -> _String? (StringContainsQ[ #, "Exit code: 3." ] && StringEndsQ[ #, "fatal: boom" ] &), "Actions" -> { "Reconnect" } },
        KeyValuePattern @ { "Code" -> "AgentNotFound", "Detail" -> _String? (StringContainsQ[ "https://opencode.ai" ]), "Actions" -> { "LocateAgent", "Reconnect" } },
        KeyValuePattern @ { "Code" -> "ACPLinkMissing", "Actions" -> { "Reconnect" } },
        KeyValuePattern @ { "Code" -> "UnknownAgent", "Message" -> "Unknown agent: X.", "Detail" -> None }
    },
    SameTest -> MatchQ,
    TestID   -> "ErrorInfo-Failures@@Tests/ACPConnection.wlt:907,1-922,2"
]

VerificationTest[
    (* Only deprecated or unknown models are ModelUnavailable (which blocks the model for the window); other
       provider.invalid-request errors, e.g. context length, are provider errors *)
    {
        KeyTake[
            acpErrorInfo[ -32603, "Internal error: Session too large to compact - context exceeds model limit even after stripping media", <| "errorName" -> "provider.invalid-request" |>, <| "Model" -> "m" |> ],
            { "Code", "Actions" }
        ],
        KeyTake[
            acpErrorInfo[ -32603, "Internal error: This model's maximum context length is 400000 tokens.", <| "errorName" -> "provider.invalid-request" |>, <| "Model" -> "openai/gpt-6.1-sol" |> ],
            { "Code", "Actions" }
        ],
        KeyTake[ acpErrorInfo[ -32603, "Internal error: OpenCode server is unavailable", <| "errorName" -> "ServerUnavailable" |> ], { "Code", "Actions" } ],
        acpErrorInfo[ -32603, "Internal error: OpenCode server is unavailable", <| "errorName" -> "ServerUnavailable" |>, <| "Agent" -> "OpenCode" |> ][ "Message" ],
        (* deprecated models are still ModelUnavailable: *)
        acpErrorInfo[ -32603, "Internal error: Model exo-free has been deprecated.", <| "errorName" -> "provider.invalid-request" |>, <| "Model" -> "opencode/exo-free" |> ][ "Code" ]
    },
    {
        <| "Code" -> "ProviderError", "Actions" -> { "ChooseModel" } |>,
        <| "Code" -> "ProviderError", "Actions" -> { "ChooseModel" } |>,
        <| "Code" -> "ServerUnavailable", "Actions" -> { "Reconnect" } |>,
        "The OpenCode server is not available.",
        "ModelUnavailable"
    },
    SameTest -> MatchQ,
    TestID   -> "ErrorInfo-ProviderErrorsAreNotModelErrors@@Tests/ACPConnection.wlt:924,1-950,2"
]

VerificationTest[
    (* The permission method accepts the ACPRequest of the fixed ACPLink and the raw JSONRPCProcessRequest of older ones *)
    Wolfram`Chatbook`ACP`Connection`Private`messageData /@ {
        ACPLinkTestFakeRequest[ <| "ID" -> 0, "Method" -> "session/request_permission", "Parameters" -> <| "sessionId" -> "s" |> |> ],
        <| "ID" -> 1 |>,
        "garbage"
    },
    {
        <| "ID" -> 0, "Method" -> "session/request_permission", "Parameters" -> <| "sessionId" -> "s" |> |>,
        <| "ID" -> 1 |>,
        <| |>
    },
    SameTest -> MatchQ,
    TestID   -> "MessageData@@Tests/ACPConnection.wlt:952,1-966,2"
]

VerificationTest[
    {
        acpConnectionQ @ ACPLinkTestFakeHead[ "x" ],
        acpConnectionQ @ None,
        acpWindowAliveQ @ NotebookObject[ "acp-connection-no-such-window" ],
        acpEnsureConnected @ NotebookObject[ "acp-connection-no-such-window" ],
        (* No record was created for the unknown window: *)
        MissingQ @ acpWindowGet @ NotebookObject[ "acp-connection-no-such-window" ]
    },
    { False, False, False, Missing[ "NotFound" ], True },
    SameTest -> MatchQ,
    TestID   -> "ConnectionUtilities@@Tests/ACPConnection.wlt:968,1-980,2"
]

VerificationTest[
    (* No message when the window has no config options (e.g. session/new failed) *)
    Wolfram`Chatbook`ACP`Connection`Private`currentModel /@ {
        <| "ConfigOptions" -> { } |>,
        <| |>,
        <| "ConfigOptions" -> { <| "id" -> "model", "category" -> "model", "currentValue" -> "m1" |> } |>
    },
    { None, None, "m1" },
    SameTest -> MatchQ,
    TestID   -> "CurrentModel-NoConfigOptions@@Tests/ACPConnection.wlt:982,1-992,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Connection Errors Without Agent Process*)
VerificationTest[
    Module[ { nbo },
        nbo = newWindow[ None, <| |> ];
        { acpEnsureConnected @ nbo, acpWindowGet[ nbo, "Status" ], acpWindowGet[ nbo, "ConnectToken", None ] }
    ],
    { "NoDirectory", "NoDirectory", None },
    SameTest -> MatchQ,
    TestID   -> "Connect-NoDirectory@@Tests/ACPConnection.wlt:997,1-1005,2"
]

VerificationTest[
    ifConnTests @ Module[ { nbo },
        nbo = newWindow[ $project1, <| "ACPAgentCommandLine" -> FileNameJoin @ { $scratch, "no-such-opencode" } |>, "OpenCode" ];
        acpEnsureConnected @ nbo;
        waitUntil[ acpWindowGet[ nbo, "Status" ] === "Error" ];
        { acpWindowGet[ nbo, "Status" ], acpWindowGet[ nbo, "Error" ], acpWindowGet[ nbo, "Connection" ] }
    ],
    Missing[ "TestSkipped" ] | {
        "Error",
        KeyValuePattern @ { "Code" -> "AgentNotFound", "Actions" -> { "LocateAgent", "Reconnect" }, "Detail" -> _String? (StringContainsQ[ "no-such-opencode" ]) },
        None
    },
    SameTest -> MatchQ,
    TestID   -> "Connect-AgentNotFound@@Tests/ACPConnection.wlt:1007,1-1021,2"
]

VerificationTest[
    ifConnTests @ Module[ { nbo },
        nbo = newWindow[ $project1, <| |>, "NoSuchAgent" ];
        acpEnsureConnected @ nbo;
        waitUntil[ acpWindowGet[ nbo, "Status" ] === "Error" ];
        { acpWindowGet[ nbo, "Status" ], acpWindowGet[ nbo, "Error", <| |> ][ "Code" ] }
    ],
    Missing[ "TestSkipped" ] | { "Error", "UnknownAgent" },
    SameTest -> MatchQ,
    TestID   -> "Connect-UnknownAgent@@Tests/ACPConnection.wlt:1023,1-1033,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Connecting*)
VerificationTest[
    ifConnTests[
        $w1 = newWindow[ $project1, <| "ACPModel" -> "m2" |> ];
        { acpEnsureConnected @ $w1, waitUntil[ acpWindowGet[ $w1, "Status" ] === "Ready" ] }
    ],
    Missing[ "TestSkipped" ] | { "Connecting", True },
    SameTest -> MatchQ,
    TestID   -> "Connect-Ready@@Tests/ACPConnection.wlt:1038,1-1046,2"
]

VerificationTest[
    ifConnTests @ KeyTake[
        acpWindowGet @ $w1,
        { "Status", "SessionID", "ResumableSessionID", "AgentInfo", "Requests", "ConnectToken", "PendingPermissions", "Error" }
    ],
    Missing[ "TestSkipped" ] | <|
        "Status"             -> "Ready",
        "SessionID"          -> "sess-1",
        "ResumableSessionID" -> "sess-1",
        "AgentInfo"          -> <| "Name" -> "Mock ACP Agent", "Version" -> "1.0.0" |>,
        "Requests"           -> <| |>,
        "ConnectToken"       -> None,
        "PendingPermissions" -> <| |>,
        "Error"              -> None
    |>,
    SameTest -> MatchQ,
    TestID   -> "Connect-WindowRecord@@Tests/ACPConnection.wlt:1048,1-1065,2"
]

VerificationTest[
    ifConnTests[ {
        currentOption[ $w1, "model" ],
        acpConnectionQ @ acpWindowGet[ $w1, "Connection" ],
        ! connectionClosedQ @ acpWindowGet[ $w1, "Connection" ] (* the helper is not vacuous *)
    } ],
    Missing[ "TestSkipped" ] | { "m2", True, True },
    SameTest -> MatchQ,
    TestID   -> "Connect-PreferredModelApplied@@Tests/ACPConnection.wlt:1067,1-1076,2"
]

VerificationTest[
    ifConnTests @ Module[ { log = lastLog[ ] },
        {
            acpEnsureConnected @ $w1,
            Length @ ACPConnections[ ],
            Length @ $mockLogs,
            Length @ mockRequestsIn[ log, "initialize" ]
        }
    ],
    Missing[ "TestSkipped" ] | { "Ready", 1, 1, 1 },
    SameTest -> MatchQ,
    TestID   -> "Connect-Idempotent@@Tests/ACPConnection.wlt:1078,1-1090,2"
]

VerificationTest[
    ifConnTests @ Module[ { log = lastLog[ ], init, new, config },
        init   = First @ mockRequestsIn[ log, "initialize" ];
        new    = First @ mockRequestsIn[ log, "session/new" ];
        config = mockRequestsIn[ log, "session/set_config_option" ];
        {
            init[ "id" ],
            init[ "params" ],
            new[ "id" ],
            new[ "params" ],
            Lookup[ config, "params" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        _String? (StringStartsQ[ "cb-" ]),
        KeyValuePattern @ {
            "protocolVersion"    -> 1,
            "clientCapabilities" -> <| "fs" -> <| "readTextFile" -> False, "writeTextFile" -> False |>, "terminal" -> False |>,
            "clientInfo"         -> KeyValuePattern[ "name" -> "wolfram-chatbook" ]
        },
        _String? (StringStartsQ[ "cb-" ]),
        KeyValuePattern @ { "cwd" -> ExpandFileName @ $project1, "mcpServers" -> mcpServersExpected[ ] },
        { KeyValuePattern @ { "configId" -> "model", "sessionId" -> "sess-1", "value" -> "m2" } }
    },
    SameTest -> MatchQ,
    TestID   -> "Connect-WireLog@@Tests/ACPConnection.wlt:1092,1-1118,2"
]

VerificationTest[
    ifConnTests @ AllTrue[ Values @ Wolfram`Chatbook`ACP`State`Private`$housekeeping, KeyExistsQ[ #, "Function" ] & ] &&
        SubsetQ[ Keys @ Wolfram`Chatbook`ACP`State`Private`$housekeeping, { "ACPConnection", "ACPConnectionSweep" } ],
    Missing[ "TestSkipped" ] | True,
    SameTest -> MatchQ,
    TestID   -> "Connect-HousekeepingRegistered@@Tests/ACPConnection.wlt:1120,1-1126,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompts and Permissions*)
VerificationTest[
    ifConnTests[
        $t1 = startTurn[ $w1, "scenario:cb-tools-permission write hello.txt" ];
        waitUntil[ Length @ pendingIDs @ $w1 > 0 ];
        $perm1 = First @ pendingIDs @ $w1;
        {
            acpTurnGet[ $t1, "RequestID" ],
            acpWindowGet[ $w1, "PendingPermissions" ][ $perm1 ],
            Keys @ acpTurnGet[ $t1, "Entities" ],
            acpTurnGet[ $t1, "Entities" ][ { "Tool", "call_write" } ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        _String? (StringStartsQ[ "cb-" ]),
        KeyValuePattern @ { "TurnID" -> $t1, "ToolKey" -> { "Tool", "call_write" }, "SessionID" -> "sess-1", "Params" -> KeyValuePattern[ "options" -> { _, _, _ } ] },
        { { "Thought", _ }, { "Message", "msg_1" }, { "Tool", "call_write" } },
        KeyValuePattern @ { "Name" -> "write", "Permission" -> KeyValuePattern @ { "RequestID" -> $perm1, "Outcome" -> None }, "Diffs" -> { __ } }
    },
    SameTest -> MatchQ,
    TestID   -> "Prompt-StreamingAndPermissionRequest@@Tests/ACPConnection.wlt:1131,1-1151,2"
]

VerificationTest[
    ifConnTests[
        Pause[ 0.5 ]; (* answered later, while the agent waits *)
        { acpAnswerPermission[ $w1, $perm1, "once" ], waitFinal @ $t1 }
    ],
    Missing[ "TestSkipped" ] | { True, True },
    SameTest -> MatchQ,
    TestID   -> "Prompt-AnswerPermissionLater@@Tests/ACPConnection.wlt:1153,1-1161,2"
]

VerificationTest[
    ifConnTests @ With[ { turn = finalTurn @ $t1 },
        {
            KeyTake[ turn, { "StopReason", "Error", "ClientCancel", "Usage" } ],
            turn[ "Entities" ][ { "Tool", "call_write" } ][ "Status" ],
            turn[ "Entities" ][ { "Tool", "call_write" } ][ "Permission", "Outcome" ],
            Lookup[ Select[ Values @ turn[ "Entities" ], #[ "Type" ] === "Message" & ], "Text" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        <| "StopReason" -> "end_turn", "Error" -> None, "ClientCancel" -> None, "Usage" -> KeyValuePattern[ "totalTokens" -> 120 ] |>,
        "completed",
        "once",
        { "I'll write the file.", "Done: hello.txt contains hi." }
    },
    SameTest -> MatchQ,
    TestID   -> "Prompt-FinalTurn@@Tests/ACPConnection.wlt:1163,1-1180,2"
]

VerificationTest[
    ifConnTests @ {
        KeyTake[ acpWindowGet @ $w1, { "Status", "CurrentTurn", "PendingPermissions", "Requests" } ],
        acpWindowGet[ $w1, "Usage" ],
        Lookup[ mockResponsesIn[ lastLog[ ], $perm1 ], "result" ],
        First[ mockRequestsIn[ lastLog[ ], "session/prompt" ] ][ "id" ] === finalTurn[ $t1 ][ "RequestID" ]
    },
    Missing[ "TestSkipped" ] | {
        <| "Status" -> "Ready", "CurrentTurn" -> None, "PendingPermissions" -> <| |>, "Requests" -> <| |> |>,
        <| "used" -> 2048, "size" -> 200000, "cost" -> KeyValuePattern[ "amount" -> 0 ] |>,
        { <| "outcome" -> <| "outcome" -> "selected", "optionId" -> "once" |> |> },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Prompt-WindowAfterTurn@@Tests/ACPConnection.wlt:1182,1-1197,2"
]

VerificationTest[
    ifConnTests @ acpAnswerPermission[ $w1, 999, "once" ],
    Missing[ "TestSkipped" ] | Missing[ "NotPending", 999 ],
    SameTest -> MatchQ,
    TestID   -> "Prompt-AnswerUnknownPermission@@Tests/ACPConnection.wlt:1199,1-1204,2"
]

VerificationTest[
    (* $/cancel_request withdraws a pending permission request *)
    ifConnTests @ Module[ { turnID, permID, withdrawn },
        turnID = startTurn[ $w1, "scenario:cb-cancel-request" ];
        waitUntil[ Length @ pendingIDs @ $w1 > 0 ];
        permID = First[ pendingIDs @ $w1, None ];
        withdrawn = waitUntil[ pendingIDs @ $w1 === { } ];
        waitFinal @ turnID;
        {
            IntegerQ @ permID,
            withdrawn,
            finalTurn[ turnID ][ "StopReason" ],
            finalTurn[ turnID ][ "Entities" ][ { "Tool", "call_w2" } ][ "Permission", "Outcome" ],
            finalTurn[ turnID ][ "Entities" ][ { "Tool", "call_w2" } ][ "Status" ],
            (* exactly one answer reached the agent (by ACPLink or by Chatbook) *)
            Lookup[ mockResponsesIn[ lastLog[ ], permID ], "result" ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, True, "end_turn", "withdrawn", "completed", { <| "outcome" -> <| "outcome" -> "cancelled" |> |> } },
    SameTest -> MatchQ,
    TestID   -> "Prompt-CancelRequest@@Tests/ACPConnection.wlt:1206,1-1227,2"
]

VerificationTest[
    (* Stop while a permission request is pending *)
    ifConnTests @ Module[ { turnID, permID, turn },
        turnID = startTurn[ $w1, "scenario:cb-tools-permission write again" ];
        waitUntil[ Length @ pendingIDs @ $w1 > 0 ];
        permID = First[ pendingIDs @ $w1, None ];
        acpStop @ $w1;
        waitFinal @ turnID;
        turn = finalTurn @ turnID;
        {
            pendingIDs @ $w1,
            KeyTake[ turn, { "StopReason", "ClientCancel", "Error" } ],
            turn[ "Entities" ][ { "Tool", "call_write" } ][ "ClientOutcome" ],
            turn[ "Entities" ][ { "Tool", "call_write" } ][ "Permission", "Outcome" ],
            Length @ mockNotificationsIn[ lastLog[ ], "session/cancel" ],
            Lookup[ mockResponsesIn[ lastLog[ ], permID ], "result" ],
            acpWindowGet[ $w1, "Status" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        { },
        <| "StopReason" -> "cancelled", "ClientCancel" -> "Stop", "Error" -> None |>,
        "Stopped" | "Declined",
        "cancelled",
        1,
        { <| "outcome" -> <| "outcome" -> "cancelled" |> |> },
        "Ready"
    },
    SameTest -> MatchQ,
    TestID   -> "Prompt-StopWithPendingPermission@@Tests/ACPConnection.wlt:1229,1-1259,2"
]

VerificationTest[
    (* A permission request after the turn ended (e.g. from a subagent) is answered "cancelled", with a notice *)
    ifConnTests @ Module[ { turnID, log, request },
        turnID = startTurn[ $w1, "scenario:cb-late-permission" ];
        waitFinal @ turnID;
        log = lastLog[ ];
        waitUntil[ MatchQ[ SelectFirst[ mockOut @ log, Lookup[ #, "method", None ] === "session/request_permission" && #[ "params", "toolCall", "toolCallId" ] === "ses_child:call_x" & ], _Association ] ];
        request = SelectFirst[ mockOut @ log, Lookup[ #, "method", None ] === "session/request_permission" && #[ "params", "toolCall", "toolCallId" ] === "ses_child:call_x" & ];
        waitUntil[ Length @ mockResponsesIn[ log, request[ "id" ] ] > 0 ];
        {
            finalTurn[ turnID ][ "StopReason" ],
            Lookup[ mockResponsesIn[ log, request[ "id" ] ], "result" ],
            pendingIDs @ $w1,
            acpWindowGet[ $w1, "Notice" ] === acpConnectionLabel[ "NoticeBackgroundPermission" ]
        }
    ],
    Missing[ "TestSkipped" ] | { "end_turn", { <| "outcome" -> <| "outcome" -> "cancelled" |> |> }, { }, True },
    SameTest -> MatchQ,
    TestID   -> "Prompt-BackgroundPermissionCancelled@@Tests/ACPConnection.wlt:1261,1-1280,2"
]

VerificationTest[
    (* A permission request that arrives after Stop but before the prompt response (OpenCode's subagents outlive a
       cancelled turn) is answered "cancelled" exactly once and does not stay pending after the turn *)
    ifConnTests @ Module[ { turnID, log, request },
        acpWindowUpdate[ $w1, <| #, "Notice" -> None |> & ];
        turnID = startTurn[ $w1, "scenario:cb-permission-after-stop" ];
        log = lastLog[ ];
        waitUntil[ MemberQ[ acpTurnGet[ turnID, "Order", { } ], { "Message", "msg_9" } ] ];
        acpStop @ $w1;
        waitFinal @ turnID;
        request = SelectFirst[ mockOut @ log, Lookup[ #, "method", None ] === "session/request_permission" && #[ "params", "toolCall", "toolCallId" ] === "ses_child:call_after_stop" &, <| |> ];
        waitUntil[ Length @ mockResponsesIn[ log, Lookup[ request, "id", None ] ] > 0 ];
        Pause[ 0.5 ]; (* no second answer *)
        {
            finalTurn[ turnID ][ "StopReason" ],
            pendingIDs @ $w1,
            Lookup[ mockResponsesIn[ log, Lookup[ request, "id", None ] ], "result" ],
            acpWindowGet[ $w1, "Status" ],
            (* refused because of the Stop, so no "background subagent" notice: *)
            acpWindowGet[ $w1, "Notice" ]
        }
    ],
    Missing[ "TestSkipped" ] | { "cancelled", { }, { <| "outcome" -> <| "outcome" -> "cancelled" |> |> }, "Ready", None },
    SameTest -> MatchQ,
    TestID   -> "Prompt-PermissionAfterStop@@Tests/ACPConnection.wlt:1282,1-1307,2"
]

VerificationTest[
    ifConnTests @ Module[ { turnID },
        acpWindowUpdate[ $w1, <| #, "Notice" -> None |> & ];
        turnID = startTurn[ $w1, "scenario:cb-model-error" ];
        waitFinal @ turnID;
        { finalTurn[ turnID ][ "Error" ], acpWindowGet[ $w1, "FailedModels" ], acpWindowGet[ $w1, "Status" ] }
    ],
    Missing[ "TestSkipped" ] | {
        KeyValuePattern @ { "Code" -> "ModelUnavailable", "Message" -> "The model m2 isn't available.", "Actions" -> { "ChooseModel" }, "Detail" -> _String },
        { "m2" },
        "Ready"
    },
    SameTest -> MatchQ,
    TestID   -> "Prompt-ModelUnavailable@@Tests/ACPConnection.wlt:1309,1-1323,2"
]

VerificationTest[
    ifConnTests @ Module[ { turnID, before },
        before = acpWindowGet[ $w1, "MCPReady" ];
        turnID = startTurn[ $w1, "scenario:cb-mcp-commands" ];
        waitFinal @ turnID;
        { before, acpWindowGet[ $w1, "MCPReady" ], MemberQ[ Lookup[ acpWindowGet[ $w1, "Commands" ], "name" ], "Wolfram:Search" ] }
    ],
    Missing[ "TestSkipped" ] | { False, True, True },
    SameTest -> MatchQ,
    TestID   -> "Prompt-MCPReadyDetection@@Tests/ACPConnection.wlt:1325,1-1335,2"
]

VerificationTest[
    (* Handlers never let anything escape (and ignore events of other connections) *)
    ifConnTests @ {
        acpOnNotification[ $w1, <| "Connection" -> acpWindowGet[ $w1, "Connection" ], "Message" -> "garbage" |> ],
        acpOnNotification[ $w1, "garbage" ],
        acpOnResponse[ $w1, <| "Connection" -> None |> ],
        acpOnFailure[ $w1, <| "Failure" -> Failure[ "ReadFailed", <| |> ] |> ],
        acpOnPermissionRequest[ $w1, 12345 ],
        acpOnConnectionRemoved[ $w1, <| "Connection" -> ACPConnection[ "not-the-window-connection" ] |> ],
        acpWindowGet[ $w1, "Status" ]
    },
    Missing[ "TestSkipped" ] | { Null, Null, Null, Null, Null, Null, "Ready" },
    SameTest -> MatchQ,
    TestID   -> "Handlers-Isolated@@Tests/ACPConnection.wlt:1337,1-1351,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config Options*)
VerificationTest[
    ifConnTests[
        {
            acpSetConfigOption[ $w1, "mode", "plan" ],
            waitUntil[ currentOption[ $w1, "mode" ] === "plan" && acpWindowGet[ $w1, "PendingConfig" ] === <| |> ]
        }
    ],
    Missing[ "TestSkipped" ] | { "Sent", True },
    SameTest -> MatchQ,
    TestID   -> "ConfigOption-Mode@@Tests/ACPConnection.wlt:1356,1-1366,2"
]

VerificationTest[
    ifConnTests[
        {
            acpSetConfigOption[ $w1, "mode", "no-such-mode" ],
            waitUntil[ acpWindowGet[ $w1, "PendingConfig" ] === <| |> && StringQ @ acpWindowGet[ $w1, "Notice" ] ],
            acpWindowGet[ $w1, "Notice" ],
            currentOption[ $w1, "mode" ]
        }
    ],
    Missing[ "TestSkipped" ] | { "Sent", True, _String? (StringStartsQ[ "Couldn't change Session Mode" ]), "plan" },
    SameTest -> MatchQ,
    TestID   -> "ConfigOption-Error@@Tests/ACPConnection.wlt:1368,1-1380,2"
]

(* $FrontEnd = Null: the persisted settings are the headless ones (restored afterwards) also when the tests run under a
   front end; under UsingFrontEnd the choice written by the pump was not read back from the front end's preferences. *)
VerificationTest[
    ifConnTests @ Block[
        {
            $FrontEnd = Null,
            Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings = Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings
        },
        acpWindowUpdate[ $w1, <| #, "Notice" -> None |> & ];
        {
            acpSetConfigOption[ $w1, "model", "m1" ],
            waitUntil[ currentOption[ $w1, "model" ] === "m1" && acpPersistedSetting[ { "LastModel", "MockACPAgent" } ] === "m1" ],
            acpWindowGet[ $w1, "UserModel" ],
            acpWindowGet[ $w1, "AgentPreferences" ][ "LastModel" ]
        }
    ],
    Missing[ "TestSkipped" ] | { "Sent", True, "m1", "m1" },
    SameTest -> MatchQ,
    TestID   -> "ConfigOption-ModelPersisted@@Tests/ACPConnection.wlt:1384,1-1401,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sessions*)
VerificationTest[
    ifConnTests[
        acpNewSession @ $w1;
        {
            acpWindowGet[ $w1, "Status" ],
            waitUntil[ acpWindowGet[ $w1, "Status" ] === "Ready" ],
            acpWindowGet[ $w1, "SessionID" ],
            acpWindowGet[ $w1, "ResumableSessionID" ],
            Lookup[ mockRequestsIn[ lastLog[ ], "session/close" ], "params" ],
            Length @ mockRequestsIn[ lastLog[ ], "session/new" ],
            currentOption[ $w1, "model" ],
            currentOption[ $w1, "mode" ]
        }
    ],
    Missing[ "TestSkipped" ] | { "Connecting", True, "sess-2", "sess-2", { <| "sessionId" -> "sess-1" |> }, 2, "m1", "build" },
    SameTest -> MatchQ,
    TestID   -> "Session-New@@Tests/ACPConnection.wlt:1406,1-1423,2"
]

VerificationTest[
    ifConnTests @ Module[ { conn, pid },
        conn = acpWindowGet[ $w1, "Connection" ];
        pid  = mockPID @ lastLog[ ];
        acpDisconnect[ $w1, "Test" ];
        {
            KeyTake[ acpWindowGet @ $w1, { "Status", "Connection", "SessionID", "ResumableSessionID" } ],
            waitUntil[ connectionClosedQ @ conn ],
            ! $procfsQ || waitUntil[ ! processAliveQ @ pid ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        <| "Status" -> "Disconnected", "Connection" -> None, "SessionID" -> None, "ResumableSessionID" -> "sess-2" |>,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Session-Disconnect@@Tests/ACPConnection.wlt:1425,1-1443,2"
]

(* A resumed session keeps its own config: the window's preferred model (here m2, the session's is m1; m2 is no longer
   marked as failed) is not applied (session/set_config_option would also move the session to the top of the agent's
   session list) *)
VerificationTest[
    ifConnTests[
        $failedModels = acpWindowGet[ $w1, "FailedModels" ];
        acpWindowUpdate[ $w1, <| #, "UserModel" -> "m2", "FailedModels" -> { } |> & ];
        acpEnsureConnected @ $w1;
        WithCleanup[
            {
                waitUntil[ acpWindowGet[ $w1, "Status" ] === "Ready" ],
                Length @ $mockLogs,
                Lookup[ mockRequestsIn[ lastLog[ ], "session/resume" ], "params" ],
                mockRequestsIn[ lastLog[ ], "session/new" ],
                acpWindowGet[ $w1, "SessionID" ],
                acpWindowGet[ $w1, "Notice" ],
                mockRequestsIn[ lastLog[ ], "session/set_config_option" ],
                currentOption[ $w1, "model" ],
                acpWindowGet[ $w1, "SessionOrigin" ]
            },
            acpWindowUpdate[ $w1, <| #, "UserModel" -> "m1", "FailedModels" -> $failedModels |> & ]
        ]
    ],
    Missing[ "TestSkipped" ] | { True, 2, { KeyValuePattern @ { "sessionId" -> "sess-2", "cwd" -> ExpandFileName @ $project1, "mcpServers" -> mcpServersExpected[ ] } }, { }, "sess-2", None, { }, "m1", "Resumed" },
    SameTest -> MatchQ,
    TestID   -> "Session-Resume@@Tests/ACPConnection.wlt:1448,1-1471,2"
]

VerificationTest[
    ifConnTests[
        acpDisconnect[ $w1, "Test" ];
        $mockProcessScenario = "cb-no-resume";
        acpEnsureConnected @ $w1;
        WithCleanup[
            {
                waitUntil[ acpWindowGet[ $w1, "Status" ] === "Ready" ],
                Length @ mockRequestsIn[ lastLog[ ], "session/resume" ],
                Length @ mockRequestsIn[ lastLog[ ], "session/new" ],
                acpWindowGet[ $w1, "SessionID" ],
                acpWindowGet[ $w1, "Notice" ] === acpConnectionLabel[ "NoticeSessionNotResumed", <| "agent" -> "Mock ACP Agent" |> ]
            },
            $mockProcessScenario = None
        ]
    ],
    Missing[ "TestSkipped" ] | { True, 1, 1, "sess-1", True },
    SameTest -> MatchQ,
    TestID   -> "Session-ResumeFallsBackToNew@@Tests/ACPConnection.wlt:1473,1-1492,2"
]

VerificationTest[
    (* Disconnecting ends a running turn as stopped and kills the agent *)
    ifConnTests @ Module[ { turnID, conn, pid },
        acpWindowUpdate[ $w1, <| #, "Notice" -> None |> & ];
        turnID = startTurn[ $w1, "scenario:base-cancel" ];
        waitUntil[ MemberQ[ Keys @ Replace[ acpTurnGet[ turnID, "Entities" ], Except[ _Association ] -> <| |> ], { "Message", _ } ] ];
        conn = acpWindowGet[ $w1, "Connection" ];
        pid  = mockPID @ lastLog[ ];
        acpDisconnect[ $w1, "Test" ];
        waitFinal @ turnID;
        {
            KeyTake[ finalTurn @ turnID, { "StopReason", "ClientCancel", "Error" } ],
            acpWindowGet[ $w1, "Status" ],
            waitUntil[ connectionClosedQ @ conn ],
            ! $procfsQ || waitUntil[ ! processAliveQ @ pid ]
        }
    ],
    Missing[ "TestSkipped" ] | { <| "StopReason" -> "cancelled", "ClientCancel" -> "Stop", "Error" -> None |>, "Disconnected", True, True },
    SameTest -> MatchQ,
    TestID   -> "Session-DisconnectRunningTurn@@Tests/ACPConnection.wlt:1494,1-1514,2"
]

VerificationTest[
    (* Stop without a response from the agent: the turn is ended locally after the Stop timeout *)
    ifConnTests @ Module[ { turnID, stopped },
        acpEnsureConnected @ $w1;
        waitUntil[ acpWindowGet[ $w1, "Status" ] === "Ready" ];
        turnID = startTurn[ $w1, "scenario:cb-ignore-cancel" ];
        waitUntil[ MemberQ[ Keys @ Replace[ acpTurnGet[ turnID, "Entities" ], Except[ _Association ] -> <| |> ], { "Message", _ } ] ];
        stopped = AbsoluteTime[ ];
        acpStop @ $w1;
        {
            waitFinal[ turnID, 20 ],
            AbsoluteTime[ ] - stopped > 9,
            KeyTake[ finalTurn @ turnID, { "StopReason", "ClientCancel" } ],
            acpWindowGet[ $w1, "Requests" ],
            acpWindowGet[ $w1, "Status" ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, True, <| "StopReason" -> "cancelled", "ClientCancel" -> "Stop" |>, <| |>, "Ready" },
    SameTest -> MatchQ,
    TestID   -> "Session-StopTimeout@@Tests/ACPConnection.wlt:1516,1-1536,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Agent Death*)
VerificationTest[
    ifConnTests @ Module[ { turnID, conn },
        conn   = acpWindowGet[ $w1, "Connection" ];
        turnID = startTurn[ $w1, "scenario:cb-crash" ];
        waitFinal @ turnID;
        {
            finalTurn[ turnID ][ "Error" ],
            KeyTake[ acpWindowGet @ $w1, { "Status", "Connection", "SessionID" } ],
            StringQ @ acpWindowGet[ $w1, "ResumableSessionID" ],
            waitUntil[ connectionClosedQ @ conn ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        KeyValuePattern @ { "Code" -> "AgentExited", "Actions" -> { "Reconnect" }, "Detail" -> _String? (StringContainsQ[ "fatal error" ]) },
        <| "Status" -> "Disconnected", "Connection" -> None, "SessionID" -> None |>,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "AgentDeath-DuringTurn@@Tests/ACPConnection.wlt:1541,1-1561,2"
]

VerificationTest[
    ifConnTests @ Module[ { nbo },
        $mockProcessScenario = "cb-exit-on-new";
        WithCleanup[
            nbo = newWindow[ $project1 ];
            acpEnsureConnected @ nbo;
            waitUntil[ acpWindowGet[ nbo, "Status" ] === "Error" ];
            { acpWindowGet[ nbo, "Status" ], acpWindowGet[ nbo, "Error" ][ "Code" ], acpWindowGet[ nbo, "Connection" ] },
            $mockProcessScenario = None
        ]
    ],
    Missing[ "TestSkipped" ] | { "Error", "AgentExited", None },
    SameTest -> MatchQ,
    TestID   -> "AgentDeath-DuringSetup@@Tests/ACPConnection.wlt:1563,1-1577,2"
]

VerificationTest[
    ifConnTests[
        $mockProcessScenario = "cb-no-models";
        WithCleanup[
            $w3 = newWindow[ $project1 ];
            acpEnsureConnected @ $w3;
            waitUntil[ acpWindowGet[ $w3, "Status" ] === "Error" ];
            {
                acpWindowGet[ $w3, "Error" ],
                acpWindowGet[ $w3, "Connection" ],
                waitUntil[ Length @ ACPConnections[ ] === 0 ],
                (* An error is sticky until Reconnect: *)
                acpEnsureConnected @ $w3
            },
            $mockProcessScenario = None
        ]
    ],
    Missing[ "TestSkipped" ] | { KeyValuePattern @ { "Code" -> "NoModels", "Actions" -> { "SignIn", "Reconnect" } }, None, True, "Error" },
    SameTest -> MatchQ,
    TestID   -> "SessionError-NoModels@@Tests/ACPConnection.wlt:1579,1-1599,2"
]

VerificationTest[
    ifConnTests[
        acpReconnect @ $w3;
        { waitUntil[ acpWindowGet[ $w3, "Status" ] === "Ready" ], acpWindowGet[ $w3, "Error" ] }
    ],
    Missing[ "TestSkipped" ] | { True, None },
    SameTest -> MatchQ,
    TestID   -> "Reconnect-ClearsError@@Tests/ACPConnection.wlt:1601,1-1609,2"
]

VerificationTest[
    (* A window whose agent could not be started connects once it is given a valid command line (UI.wl applies an
       "ACPAgentCommandLine" given to ShowNotebookAssistance for the open window, or chosen with "Locate OpenCode...") *)
    ifConnTests @ Module[ { nbo, result, conn },
        nbo = newWindow[ $project1, <| "ACPAgentCommandLine" -> FileNameJoin @ { $scratch, "no-such-agent" } |> ];
        acpEnsureConnected @ nbo;
        waitUntil[ acpWindowGet[ nbo, "Status" ] === "Error" ];
        Wolfram`Chatbook`ACP`UI`Private`acpApplyWindowSettings[
            nbo,
            Wolfram`Chatbook`ACP`UI`Private`acpMergeWindowSettings[ nbo, <| "ACPAgentCommandLine" -> $python |> ],
            False
        ];
        result = {
            waitUntil[ acpWindowGet[ nbo, "Status" ] === "Ready" ],
            acpWindowGet[ nbo, "Settings" ][ "ACPAgentCommandLine" ] === $python,
            acpWindowGet[ nbo, "Error" ]
        };
        conn = acpWindowGet[ nbo, "Connection" ];
        acpDisconnect[ nbo, "Test" ];
        Append[ result, waitUntil[ connectionClosedQ @ conn ] ]
    ],
    Missing[ "TestSkipped" ] | { True, True, None, True },
    SameTest -> MatchQ,
    TestID   -> "Reconnect-AfterCommandLineSet@@Tests/ACPConnection.wlt:1611,1-1635,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Project Directory*)
VerificationTest[
    ifConnTests @ {
        acpSetProjectDirectory[ $w1, FileNameJoin @ { $scratch, "no-such-directory" } ],
        acpSetProjectDirectory[ $w1, acpWindowGet[ $w1, "ProjectDirectory" ] ]
    },
    Missing[ "TestSkipped" ] | { Failure[ "InvalidDirectory", _ ], Null },
    SameTest -> MatchQ,
    TestID   -> "ProjectDirectory-Invalid@@Tests/ACPConnection.wlt:1640,1-1648,2"
]

VerificationTest[
    ifConnTests[
        {
            acpSetProjectDirectory[ $w1, $project2 ],
            KeyTake[ acpWindowGet @ $w1, { "ProjectDirectory", "ResumableSessionID", "Turns" } ],
            waitUntil[ acpWindowGet[ $w1, "Status" ] === "Ready" ],
            Lookup[ mockRequestsIn[ lastLog[ ], "session/new" ], "params" ],
            mockRequestsIn[ lastLog[ ], "session/resume" ],
            acpPersistedSetting[ "LastProjectDirectory" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        ExpandFileName @ $project2,
        <| "ProjectDirectory" -> ExpandFileName @ $project2, "ResumableSessionID" -> None, "Turns" -> { } |>,
        True,
        { KeyValuePattern @ { "cwd" -> ExpandFileName @ $project2, "mcpServers" -> mcpServersExpected[ ] } },
        { },
        ExpandFileName @ $project2
    },
    SameTest -> MatchQ,
    TestID   -> "ProjectDirectory-Change@@Tests/ACPConnection.wlt:1650,1-1671,2"
]

VerificationTest[
    ifConnTests @ Module[ { turnID, result },
        turnID = startTurn[ $w1, "scenario:base-cancel" ];
        result = acpSetProjectDirectory[ $w1, $project1 ];
        acpStop @ $w1;
        waitFinal @ turnID;
        { result, acpWindowGet[ $w1, "ProjectDirectory" ], finalTurn[ turnID ][ "StopReason" ] }
    ],
    Missing[ "TestSkipped" ] | { Failure[ "Running", _ ], ExpandFileName @ $project2, "cancelled" },
    SameTest -> MatchQ,
    TestID   -> "ProjectDirectory-RefusedWhileRunning@@Tests/ACPConnection.wlt:1673,1-1684,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Window-Level Updates*)
VerificationTest[
    ifConnTests @ Module[ { conn, sid, modes },
        conn = acpWindowGet[ $w1, "Connection" ];
        sid  = acpWindowGet[ $w1, "SessionID" ];
        acpOnNotification[ $w1, <|
            "Connection" -> conn,
            "Message"    -> TestNotification @ <|
                "Method"     -> "session/update",
                "Parameters" -> <| "sessionId" -> sid, "update" -> <|
                    "sessionUpdate" -> "config_option_update",
                    "configOptions" -> {
                        <| "id" -> "model", "name" -> "Model", "category" -> "model", "type" -> "select", "currentValue" -> "m2",
                           "options" -> { <| "value" -> "m1", "name" -> "Model One" |>, <| "value" -> "m2", "name" -> "Model Two" |> } |>
                    }
                |> |>
            |>
        |> ];
        acpOnNotification[ $w1, <|
            "Connection" -> conn,
            "Message"    -> TestNotification @ <|
                "Method"     -> "session/update",
                "Parameters" -> <| "sessionId" -> sid, "update" -> <| "sessionUpdate" -> "current_mode_update", "currentModeId" -> "plan" |> |>
            |>
        |> ];
        (* updates of another session don't change the window *)
        acpOnNotification[ $w1, <|
            "Connection" -> conn,
            "Message"    -> TestNotification @ <|
                "Method"     -> "session/update",
                "Parameters" -> <| "sessionId" -> "other-session", "update" -> <| "sessionUpdate" -> "current_mode_update", "currentModeId" -> "build" |> |>
            |>
        |> ];
        { currentOption[ $w1, "model" ], currentOption[ $w1, "mode" ], Lookup[ acpWindowGet[ $w1, "ConfigOptions" ], "id" ] }
    ],
    Missing[ "TestSkipped" ] | { "m2", "plan", { "model", "effort", "mode" } },
    SameTest -> MatchQ,
    TestID   -> "WindowUpdates-ConfigAndMode@@Tests/ACPConnection.wlt:1689,1-1726,2"
]

VerificationTest[
    (* New chat on a disconnected window: the next connection starts a new session (no resume) *)
    ifConnTests[
        acpDisconnect[ $w1, "Test" ];
        acpNewSession @ $w1;
        {
            acpWindowGet[ $w1, "ResumableSessionID" ],
            waitUntil[ acpWindowGet[ $w1, "Status" ] === "Ready" ],
            mockRequestsIn[ lastLog[ ], "session/resume" ],
            Length @ mockRequestsIn[ lastLog[ ], "session/new" ]
        }
    ],
    Missing[ "TestSkipped" ] | { None, True, { }, 1 },
    SameTest -> MatchQ,
    TestID   -> "Session-NewWhileDisconnected@@Tests/ACPConnection.wlt:1728,1-1743,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Housekeeping Fallbacks*)
VerificationTest[
    (* A connection attempt whose scheduled task never ran is scheduled again *)
    ifConnTests[
        $w4 = newWindow[ $project1 ];
        acpWindowUpdate[ $w4, <| #, "Status" -> "Connecting", "ConnectToken" -> "stuck-token", "ConnectScheduledAt" -> AbsoluteTime[ ] - 20, "ConnectAttempts" -> 1 |> & ];
        { waitUntil[ acpWindowGet[ $w4, "Status" ] === "Ready", 20 ], acpWindowGet[ $w4, "ConnectToken" ], acpWindowGet[ $w4, "ConnectAttempts" ] }
    ],
    Missing[ "TestSkipped" ] | { True, None, 0 },
    SameTest -> MatchQ,
    TestID   -> "Housekeeping-StuckConnect@@Tests/ACPConnection.wlt:1748,1-1758,2"
]

VerificationTest[
    ifConnTests[
        acpWindowUpdate[ $w4, <| #, "MCPReady" -> False, "SessionStartedAt" -> AbsoluteTime[ ] - 100 |> & ];
        waitUntil[ acpWindowGet[ $w4, "MCPReady" ] === True ]
    ],
    Missing[ "TestSkipped" ] | True,
    SameTest -> MatchQ,
    TestID   -> "Housekeeping-MCPReadyTimeout@@Tests/ACPConnection.wlt:1760,1-1768,2"
]

VerificationTest[
    (* A setup request without a response fails the connection *)
    ifConnTests @ Module[ { conn },
        conn = acpWindowGet[ $w4, "Connection" ];
        acpWindowUpdate[
            $w4,
            <| #, "Requests" -> <| "cb-test-stale" -> <| "Kind" -> "SessionNew", "Method" -> "session/new", "Data" -> <| |>, "Connection" -> conn, "SentAt" -> AbsoluteTime[ ] - 100 |> |> |> &
        ];
        {
            waitUntil[ acpWindowGet[ $w4, "Status" ] === "Error" ],
            acpWindowGet[ $w4, "Error" ][ "Code" ],
            acpWindowGet[ $w4, "Connection" ],
            waitUntil[ connectionClosedQ @ conn ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, "Timeout", None, True },
    SameTest -> MatchQ,
    TestID   -> "Housekeeping-SetupTimeout@@Tests/ACPConnection.wlt:1770,1-1788,2"
]

(* Agents for the timeout tests: the mock, silent for $mockStartDelay seconds before it reads anything (a launcher that
   is still connecting, or an agent that takes long to start). The PID of a connection's process comes from ACPLink's
   private state (test-only peek). *)
VerificationTest[
    $mockStartDelay = 0;
    $acpAgents[ "MockACPAgentSlowStart" ] = <|
        "Name"        -> "MockACPAgent",
        "Executable"  -> $python,
        "Arguments"   :> { $mockScript, "--log", newMockLog[ ], "--idle-timeout", "120", "--max-lifetime", "600", "--start-delay", ToString @ $mockStartDelay },
        "Environment" -> Inherited
    |>;
    connectionPID[ conn_ ] := Module[ { data, process },
        data    = Lookup[ Symbol[ "ACPLink`ACP`InternalSymbols`$acpConnections" ], conn, None ];
        process = If[ data === None, None, Symbol[ "ACPLink`ACP`InternalSymbols`lookupInACPConnectionData" ][ data, Symbol[ "ACPLink`JSONRPCProcess`CommonSymbols`JSONRPCProcess" ] ] ];
        Replace[ Quiet @ Symbol[ "ACPLink`JSONRPCProcess`CommonSymbols`JSONRPCProcessStatus" ][ process, "PID" ], Except[ _Integer ] -> None ]
    ];
    (* Evaluated in a pump item: the pump's own publisher tick and connection housekeeping run right after the item, in
       the same pump tick, as after an item that blocked the kernel (State.wl's pumpTick and runHousekeeping); the run
       before was a normal one *)
    housekeepingThisTick[ ] := With[ { every = Wolfram`Chatbook`ACP`State`Private`$housekeeping[ "ACPConnection", "Every" ] },
        Wolfram`Chatbook`ACP`State`Private`$pumpTicks = Wolfram`Chatbook`ACP`State`Private`$acpPublishEvery *
            Ceiling[ Wolfram`Chatbook`ACP`State`Private`$pumpTicks / Wolfram`Chatbook`ACP`State`Private`$acpPublishEvery ];
        Wolfram`Chatbook`ACP`State`Private`$publisherTicks = every * Ceiling[ Wolfram`Chatbook`ACP`State`Private`$publisherTicks / every + 1 ] - 1;
        Wolfram`Chatbook`ACP`Connection`Private`$housekeepingSkipped = False;
    ];
    (* A pump item that keeps the kernel busy for 0.2 s in every tick it runs in, while $busyPump is True: every run of
       housekeeping comes late *)
    $busyPump = False;
    busyPumpItem[ ] := If[ TrueQ @ $busyPump, Pause[ 0.2 ]; acpSchedule @ busyPumpItem[ ] ];
    Null,
    Null,
    TestID -> "Housekeeping-TimeoutDefinitions@@Tests/ACPConnection.wlt:1793,1-1822,2"
]

(* The kernel is blocked right after the agent was started (an evaluation in the pump, e.g. one that waits for the
   front end), for longer than the setup timeout, and housekeeping runs right after it, in the same pump tick: the
   agent's answer is there but unread, since ACPLink's reader could not run. The timeout is only confirmed at a later
   run, after the reader ran, so the connection goes on (D3 finding F2b) *)
VerificationTest[
    ifConnTests @ Block[ { Wolfram`Chatbook`ACP`Connection`Private`$acpConnectTimeout = 2 },
        Module[ { nbo },
            nbo = newWindow[ $project1 ];
            acpEnsureConnected @ nbo;
            (* due right after acpConnect: no reader tick in between, and housekeeping runs right after it *)
            acpSchedule[ Pause[ 3 ]; housekeepingThisTick[ ] ];
            { waitUntil[ MemberQ[ { "Ready", "Error" }, acpWindowGet[ nbo, "Status" ] ], 20 ], acpWindowGet[ nbo, "Status" ], acpWindowGet[ nbo, "Error" ] }
        ]
    ],
    Missing[ "TestSkipped" ] | { True, "Ready", None },
    SameTest -> MatchQ,
    TestID   -> "Housekeeping-StalledKernel-NoSpuriousTimeout@@Tests/ACPConnection.wlt:1828,1-1841,2"
]

(* A kernel that stays busy (every run of housekeeping comes late): only one run in a row decides no timeouts, so an
   agent that never answers still fails the connection. The busy pump item spreads the runs about 2.5 s apart; with a
   stall threshold of 0.3 s every run is late by construction (runs are at least 1 s apart) *)
VerificationTest[
    ifConnTests @ Block[
        {
            Wolfram`Chatbook`ACP`Connection`Private`$acpConnectTimeout = 1,
            Wolfram`Chatbook`ACP`Connection`Private`$acpStallThreshold = 0.3,
            $mockStartDelay = 30
        },
        Module[ { nbo, conn, runs = { } },
            nbo = newWindow[ $project1, <| |>, "MockACPAgentSlowStart" ];
            WithCleanup[
                $busyPump = True;
                acpSchedule @ busyPumpItem[ ];
                acpEnsureConnected @ nbo;
                waitUntil[ acpConnectionQ @ acpWindowGet[ nbo, "Connection" ] ];
                conn = acpWindowGet[ nbo, "Connection" ];
                {
                    waitUntil[
                        AppendTo[ runs, Wolfram`Chatbook`ACP`Connection`Private`$lastHousekeepingAt ];
                        statusQ[ nbo, "Error" ],
                        30
                    ],
                    errorOf[ nbo ][ "Code" ],
                    (* every run of housekeeping meanwhile came late *)
                    With[ { gaps = Differences @ Union @ Select[ runs, NumberQ ] }, gaps =!= { } && Min @ gaps > 0.3 ],
                    waitUntil[ connectionClosedQ @ conn ]
                },
                $busyPump = False
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | { True, "Timeout", True, True },
    SameTest -> MatchQ,
    TestID   -> "Housekeeping-BusyKernel-TimeoutFires@@Tests/ACPConnection.wlt:1846,1-1879,2"
]

(* An agent that never answers: the setup timeout ends its process (and the connection) *)
VerificationTest[
    ifConnTests @ Block[ { Wolfram`Chatbook`ACP`Connection`Private`$acpConnectTimeout = 1, $mockStartDelay = 30 },
        Module[ { nbo, conn, pid },
            nbo = newWindow[ $project1, <| |>, "MockACPAgentSlowStart" ];
            acpEnsureConnected @ nbo;
            waitUntil[ acpConnectionQ @ acpWindowGet[ nbo, "Connection" ] ];
            conn = acpWindowGet[ nbo, "Connection" ];
            pid  = connectionPID @ conn;
            {
                waitUntil[ statusQ[ nbo, "Error" ], 20 ],
                errorOf[ nbo ][ "Code" ],
                IntegerQ @ pid,
                waitUntil[ connectionClosedQ @ conn ],
                ! $procfsQ || waitUntil[ ! processAliveQ @ pid ]
            }
        ]
    ],
    Missing[ "TestSkipped" ] | { True, "Timeout", True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Housekeeping-SetupTimeout-EndsAgent@@Tests/ACPConnection.wlt:1882,1-1902,2"
]

VerificationTest[
    (* A connection that ACPLink no longer has (agent died without an event) is treated as agent death *)
    ifConnTests[
        $w5 = newWindow[ $project1 ];
        acpWindowUpdate[ $w5, <| #, "Status" -> "Ready", "Connection" -> ACPConnection[ "acp-connection-test-dead" ], "SessionID" -> "s-dead", "ResumableSessionID" -> "s-dead" |> & ];
        {
            waitUntil[ acpWindowGet[ $w5, "Status" ] === "Disconnected" ],
            acpWindowGet[ $w5, "Error" ][ "Code" ],
            acpWindowGet[ $w5, "Connection" ],
            acpWindowGet[ $w5, "ResumableSessionID" ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, "AgentExited", None, "s-dead" },
    SameTest -> MatchQ,
    TestID   -> "Housekeeping-DeadConnection@@Tests/ACPConnection.wlt:1904,1-1919,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Remote (SSH)*)

(* The mock agent "remotely": the fake ssh runs the launch bootstrap like sshd (a clean environment, the fake home folder
   Data/ACP/FakeSSH.wl set up), and the launch script finds the mock's absolute python and runs it in the folder. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Connecting*)
VerificationTest[
    ifRemoteTests[
        acpSetPersistedSetting[ { "SSH", "testhost", "LastProjectDirectory" }, Inherited ];
        $localLastDirectory = acpPersistedSetting[ { "LastProjectDirectory" } ];
        $rw1 = newRemoteWindow[ "~/proj", remoteSSH[ ] ];
        {
            acpEnsureConnected @ $rw1,
            (* not before the launch has entered the folder (a mistyped one must not become the host's default) *)
            MissingQ @ acpPersistedSetting[ { "SSH", "testhost", "LastProjectDirectory" } ],
            waitUntil[ statusQ[ $rw1, "Ready" ], 30 ],
            KeyTake[ acpWindowGet @ $rw1, { "ProjectDirectory", "ConnectDirectory", "RemoteHome", "RemoteVerified", "RemoteAgentPath", "Remote" } ],
            Lookup[ mockRequestsIn[ lastLog[ ], "session/new" ], "params" ],
            (* the host's last folder is written once the launch entered the folder: the absolute one, never "~/proj" *)
            waitUntil[ StringQ @ acpPersistedSetting[ { "SSH", "testhost", "LastProjectDirectory" } ] ],
            acpPersistedSetting[ { "SSH", "testhost", "LastProjectDirectory" } ],
            acpPersistedSetting[ { "SSH", "testhost", "Home" } ],
            acpPersistedSetting[ { "LastProjectDirectory" } ] === $localLastDirectory
        }
    ],
    Missing[ "TestSkipped" ] | {
        "Connecting",
        True,
        True,
        <|
            "ProjectDirectory" -> $remoteHome <> "/proj",
            "ConnectDirectory" -> $remoteHome <> "/proj",
            "RemoteHome"       -> $remoteHome,
            "RemoteVerified"   -> True,
            "RemoteAgentPath"  -> $python,
            "Remote"           -> KeyValuePattern @ { "Host" -> "testhost", "HostKey" -> "testhost", "InstallURL" -> None }
        |>,
        { KeyValuePattern @ { "cwd" -> $remoteHome <> "/proj", "mcpServers" -> { } } },
        True,
        $remoteHome <> "/proj",
        $remoteHome,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Connect@@Tests/ACPConnection.wlt:1931,1-1970,2"
]

(* A home persisted for the host that is out of date (the host name now points to another machine): a new window's ~
   folder is not expanded with it (acpDefaultProjectDirectory, acpConnect); the launch resolves it, and the real home
   replaces the persisted one *)
VerificationTest[
    ifRemoteTests @ Module[ { ssh = remoteSSH[ ], dir, nbo, result },
        acpSetPersistedSetting[ { "SSH", "testhost", "Home" }, "/nonexistent-old-home" ];
        dir = Wolfram`Chatbook`ACP`UI`Private`acpDefaultProjectDirectory[ None, <| "SSHSettings" -> ssh, "ProjectDirectory" -> "~/proj" |> ];
        nbo = newRemoteWindow[ dir, ssh ];
        result = {
            dir,
            acpWindowGet[ nbo, "RemoteHome" ],
            acpEnsureConnected @ nbo,
            waitUntil[ statusQ[ nbo, "Ready" ], 30 ],
            Lookup[ acpWindowGet @ nbo, { "ProjectDirectory", "ConnectDirectory", "RemoteHome" } ],
            Lookup[ mockRequestsIn[ lastLog[ ], "session/new" ], "params" ],
            waitUntil[ acpPersistedSetting[ { "SSH", "testhost", "Home" } ] === $remoteHome ]
        };
        acpDisconnect[ nbo, "Test" ];
        result
    ],
    Missing[ "TestSkipped" ] | {
        "~/proj",
        "/nonexistent-old-home",
        "Connecting",
        True,
        { $remoteHome <> "/proj", $remoteHome <> "/proj", $remoteHome },
        { KeyValuePattern @ { "cwd" -> $remoteHome <> "/proj" } },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-StaleHome-TildeFolder@@Tests/ACPConnection.wlt:1975,1-2003,2"
]

(* The agent's variables reach the remote agent byte-exact (over ssh's standard input), and nothing of the local
   environment does (ACPLink's process tag) *)
VerificationTest[
    ifRemoteTests[
        $rw2 = newRemoteWindow[
            "~/proj",
            remoteSSH[ "testhost", "Username" -> "tester", "Arguments" -> { "-o", "ServerAliveCountMax=5" } ],
            <| |>,
            "MockACPAgentVars"
        ];
        acpEnsureConnected @ $rw2;
        {
            waitUntil[ statusQ[ $rw2, "Ready" ], 30 ],
            Lookup[ mockStart @ lastLog[ ], "env" ],
            AnyTrue[ Lookup[ mockStart @ lastLog[ ], "argv" ], StringContainsQ[ #, $remoteVarValue ] & ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, <| "MOCK_REMOTE_VAR" -> $remoteVarValue |>, False },
    SameTest -> MatchQ,
    TestID   -> "Remote-Variables@@Tests/ACPConnection.wlt:2007,1-2025,2"
]

(* ssh's command line: the fixed options, -l, the user's Arguments, the default options, -T, --, the host and the
   bootstrap; no variable (name or value) is on any command line (the last launch: git checks of remote windows run
   their own ssh, with "exec /bin/sh -s") *)
VerificationTest[
    ifRemoteTests @ Module[ { calls },
        calls = fakeSSHCalls[ ];
        {
            Last @ Select[ calls, Last @ # === $acpSSHLaunchCommand & ],
            AnyTrue[ Catenate @ calls, StringContainsQ[ #, "MOCK_REMOTE_VAR" | $remoteVarValue | "OPENCODE_CONFIG_CONTENT" ] & ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        Join[
            $acpSSHFixedOptions,
            { "-l", "tester", "-o", "ServerAliveCountMax=5" },
            $acpSSHDefaultOptions,
            { "-T", "--", "testhost", $acpSSHLaunchCommand }
        ],
        False
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Argv@@Tests/ACPConnection.wlt:2030,1-2049,2"
]

(* The client capabilities stay off for remote agents: the kernel never reads or writes local files for them *)
VerificationTest[
    ifRemoteTests @ Lookup[ First @ mockRequestsIn[ lastLog[ ], "initialize" ], "params" ][ "clientCapabilities" ],
    Missing[ "TestSkipped" ] | <| "fs" -> <| "readTextFile" -> False, "writeTextFile" -> False |>, "terminal" -> False |>,
    SameTest -> MatchQ,
    TestID   -> "Remote-InitializeCapabilities@@Tests/ACPConnection.wlt:2052,1-2057,2"
]

(* Nothing is written to ssh before the remote shell asks for the launch script: ACPLink holds the script and the queued
   "initialize" while ssh connects (x.slow.test: 3 s), and the session is ready afterwards. Meanwhile the folder is not
   persisted for the host yet (only once the launch has entered it). *)
VerificationTest[
    ifRemoteTests @ withFakeSSHEnvironment[
        <| "FAKE_SSH_DELAY" -> "3" |>,
        Module[ { nbo, t0, opened, conn, during },
            acpSetPersistedSetting[ { "SSH", "x.slow.test", "LastProjectDirectory" }, Inherited ];
            nbo = newRemoteWindow[ "~/proj", remoteSSH[ "x.slow.test" ] ];
            t0  = AbsoluteTime[ ];
            acpEnsureConnected @ nbo;
            waitUntil[ acpConnectionQ @ acpWindowGet[ nbo, "Connection" ] ];
            opened = AbsoluteTime[ ] - t0;
            conn   = acpWindowGet[ nbo, "Connection" ];
            during = {
                pendingPreamble @ conn,
                acpWindowGet[ nbo, "Status" ],
                Lookup[ Values @ acpWindowGet[ nbo, "Requests" ], "Kind" ],
                MissingQ @ acpPersistedSetting[ { "SSH", "x.slow.test", "LastProjectDirectory" } ]
            };
            {
                opened < 2.5,
                during,
                waitUntil[ statusQ[ nbo, "Ready" ], 30 ],
                AbsoluteTime[ ] - t0 > 3,
                pendingPreamble @ conn,
                waitUntil[ acpPersistedSetting[ { "SSH", "x.slow.test", "LastProjectDirectory" } ] === $remoteHome <> "/proj" ]
            }
        ]
    ],
    Missing[ "TestSkipped" ] | { True, { { True, 1 }, "Connecting", { "Initialize" }, True }, True, True, { False, 0 }, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-LaunchWaitsForTrigger@@Tests/ACPConnection.wlt:2062,1-2092,2"
]

(* Connecting, reconnecting and changing the folder of a remote window never look at the folder on this computer (the
   fake home is a local folder: a DirectoryQ or ExpandFileName of it would be a local check). Git checks stay on: the
   window's git summary checks the folder over ssh (Git.wl), never locally. *)
VerificationTest[
    ifRemoteTests @ Module[ { nbo, conn, results },
        $fsCalls = { };
        Internal`InheritedBlock[ { DirectoryQ, ExpandFileName },
            Unprotect[ DirectoryQ, ExpandFileName ];
            DirectoryQ[ p_String ] /; StringStartsQ[ p, $remoteHome ] := (AppendTo[ $fsCalls, { "DirectoryQ", p } ]; False);
            ExpandFileName[ p_String ] /; StringStartsQ[ p, $remoteHome ] := (AppendTo[ $fsCalls, { "ExpandFileName", p } ]; p);
            nbo = newRemoteWindow[ $remoteHome <> "/proj", remoteSSH[ ] ];
            acpEnsureConnected @ nbo;
            results = { waitUntil[ statusQ[ nbo, "Ready" ], 30 ] };
            conn = acpWindowGet[ nbo, "Connection" ];
            acpReconnect @ nbo;
            AppendTo[ results, waitUntil[ statusQ[ nbo, "Ready" ] && acpWindowGet[ nbo, "Connection" ] =!= conn, 30 ] ];
            AppendTo[ results, acpSetProjectDirectory[ nbo, $remoteHome <> "/proj2" ] ];
            AppendTo[
                results,
                waitUntil[ statusQ[ nbo, "Ready" ] && acpWindowGet[ nbo, "ProjectDirectory" ] === $remoteHome <> "/proj2", 30 ]
            ];
            (* the git summary of the new folder (checked over ssh) *)
            AppendTo[
                results,
                waitUntil[ acpGitSummary[ nbo ][ "Directory" ] === $remoteHome <> "/proj2" && NumberQ @ acpGitSummary[ nbo ][ "CheckedAt" ], 30 ]
            ];
            acpDisconnect[ nbo, "Test" ]
        ];
        { results, $fsCalls }
    ],
    Missing[ "TestSkipped" ] | { { True, True, $remoteHome <> "/proj2", True, True }, { } },
    SameTest -> MatchQ,
    TestID   -> "Remote-NoLocalFS@@Tests/ACPConnection.wlt:2097,1-2127,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Settings changes and host switches*)

(* Other settings of the same host reconnect: the folder and the session stay (session/resume) *)
VerificationTest[
    ifRemoteTests @ Module[ { conn, sid },
        conn = acpWindowGet[ $rw1, "Connection" ];
        sid  = acpWindowGet[ $rw1, "SessionID" ];
        reuseWindow[ $rw1, <| "SSHSettings" -> remoteSSH[ "testhost", "Arguments" -> { "-o", "ServerAliveCountMax=4" } ] |> ];
        {
            waitUntil[ statusQ[ $rw1, "Ready" ] && acpWindowGet[ $rw1, "Connection" ] =!= conn, 30 ],
            acpWindowGet[ $rw1, "ProjectDirectory" ],
            StringQ @ sid && acpWindowGet[ $rw1, "SessionID" ] === sid,
            Lookup[ mockRequestsIn[ lastLog[ ], "session/resume" ], "params" ],
            acpWindowGet[ $rw1, "Settings" ][ "SSHSettings" ][ "Arguments" ],
            MemberQ[ Last @ Select[ fakeSSHCalls[ ], Last @ # === $acpSSHLaunchCommand & ], "ServerAliveCountMax=4" ],
            waitUntil[ connectionClosedQ @ conn ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        True,
        $remoteHome <> "/proj",
        True,
        { KeyValuePattern @ { "sessionId" -> _String, "cwd" -> $remoteHome <> "/proj" } },
        { "-o", "ServerAliveCountMax=4" },
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-SameHostReconnect@@Tests/ACPConnection.wlt:2134,1-2160,2"
]

(* Another host is a new chat in that host's last folder; the old connection is closed *)
VerificationTest[
    ifRemoteTests @ Module[ { conn },
        conn = acpWindowGet[ $rw1, "Connection" ];
        acpSetPersistedSetting[ { "SSH", "otherhost", "LastProjectDirectory" }, $remoteHome <> "/proj2" ];
        reuseWindow[ $rw1, <| "SSHSettings" -> remoteSSH[ "otherhost" ] |> ];
        {
            waitUntil[ statusQ[ $rw1, "Ready" ] && acpWindowGet[ $rw1, "Connection" ] =!= conn, 30 ],
            KeyTake[ acpWindowGet @ $rw1, { "ProjectDirectory", "RemoteVerified", "Notice" } ],
            acpWindowGet[ $rw1, "Remote" ][ "HostKey" ],
            acpWindowGet[ $rw1, "SessionOrigin" ] === "New",
            Lookup[ mockRequestsIn[ lastLog[ ], "session/new" ], "params" ],
            mockRequestsIn[ lastLog[ ], "session/resume" ],
            Last[ Select[ fakeSSHCalls[ ], Last @ # === $acpSSHLaunchCommand & ] ][[ -2 ]],
            waitUntil[ connectionClosedQ @ conn ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        True,
        <| "ProjectDirectory" -> $remoteHome <> "/proj2", "RemoteVerified" -> True, "Notice" -> None |>,
        "otherhost",
        True,
        { KeyValuePattern[ "cwd" -> $remoteHome <> "/proj2" ] },
        { },
        "otherhost",
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-HostSwitch@@Tests/ACPConnection.wlt:2163,1-2191,2"
]

(* A host that was never reached (a typo in the user name or port) keeps its folder for the corrected host *)
VerificationTest[
    ifRemoteTests @ Module[ { nbo, before },
        nbo = newRemoteWindow[ "~/proj3", remoteSSH[ "x.fail-auth.test" ] ];
        acpEnsureConnected @ nbo;
        waitUntil[ statusQ[ nbo, "Error" ], 30 ];
        before = { errorOf[ nbo ][ "Code" ], acpWindowGet[ nbo, "RemoteVerified" ] };
        reuseWindow[ nbo, <| "SSHSettings" -> remoteSSH[ "testhost" ] |> ];
        {
            before,
            waitUntil[ statusQ[ nbo, "Ready" ], 30 ],
            KeyTake[ acpWindowGet @ nbo, { "ProjectDirectory", "RemoteVerified", "Error" } ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        { "SSHAuthFailed", False },
        True,
        <| "ProjectDirectory" -> $remoteHome <> "/proj3", "RemoteVerified" -> True, "Error" -> None |>
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-HostSwitch-KeepsUnverifiedFolder@@Tests/ACPConnection.wlt:2194,1-2214,2"
]

(* A command line is for the machine that runs the agent: another host drops it (with a notice) unless the call gives one *)
VerificationTest[
    ifRemoteTests[
        $rw4 = newWindow[ $project1, <| "ACPAgentCommandLine" -> $python |> ];
        acpEnsureConnected @ $rw4;
        waitUntil[ statusQ[ $rw4, "Ready" ], 30 ];
        reuseWindow[ $rw4, <| "SSHSettings" -> remoteSSH[ ], "ProjectDirectory" -> "~/proj4" |> ];
        {
            waitUntil[ statusQ[ $rw4, "Ready" ] && acpRemoteQ @ acpWindowGet @ $rw4, 30 ],
            acpWindowGet[ $rw4, "Settings" ][ "ACPAgentCommandLine" ],
            acpWindowGet[ $rw4, "Notice" ],
            acpWindowGet[ $rw4, "ProjectDirectory" ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, Automatic, acpLabel[ "NoticeCommandLineReset" ], $remoteHome <> "/proj4" },
    SameTest -> MatchQ,
    TestID   -> "Remote-CommandLineReset@@Tests/ACPConnection.wlt:2217,1-2233,2"
]

(* Back to this computer: a local folder, no remote state; a command line given in the same call is kept *)
VerificationTest[
    ifRemoteTests[
        reuseWindow[ $rw4, <| "SSHSettings" -> None, "ProjectDirectory" -> $project1, "ACPAgentCommandLine" -> $python |> ];
        {
            waitUntil[ statusQ[ $rw4, "Ready" ] && ! acpRemoteQ @ acpWindowGet @ $rw4, 30 ],
            KeyTake[ acpWindowGet @ $rw4, { "ProjectDirectory", "Remote", "RemoteHome", "RemoteVerified", "Notice" } ],
            acpWindowGet[ $rw4, "Settings" ][ "ACPAgentCommandLine" ],
            Lookup[ mockRequestsIn[ lastLog[ ], "session/new" ], "params" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        True,
        <| "ProjectDirectory" -> ExpandFileName @ $project1, "Remote" -> None, "RemoteHome" -> None, "RemoteVerified" -> False, "Notice" -> None |>,
        $python,
        { KeyValuePattern[ "cwd" -> ExpandFileName @ $project1 ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-RemoteToLocal@@Tests/ACPConnection.wlt:2236,1-2254,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Errors*)

(* Sign-in errors of a remote agent name the host, and their advice ("Hint") gives the ssh command for a terminal *)
VerificationTest[
    ifRemoteTests[
        $mockProcessScenario = "cb-no-models";
        WithCleanup[
            Module[ { ssh = remoteSSH[ ], nbo, auth, text },
                text = Replace[ Lookup[ #, "Hint", None ], Except[ _String ] -> "" ] &;
                nbo = newRemoteWindow[ "~/proj", ssh ];
                acpEnsureConnected @ nbo;
                waitUntil[ statusQ[ nbo, "Error" ], 30 ];
                auth = Wolfram`Chatbook`ACP`Connection`Private`responseError[
                    acpWindowGet @ nbo,
                    <| "Error" -> True, "Code" -> -32000, "Message" -> "Authentication required", "Data" -> None |>,
                    "SessionFailed"
                ];
                {
                    errorOf[ nbo ][ "Code" ],
                    StringContainsQ[ errorOf[ nbo ][ "Message" ], " on testhost " ] && StringContainsQ[ text @ errorOf @ nbo, acpSSHTerminalCommand @ ssh ],
                    auth[ "Code" ],
                    StringContainsQ[ auth[ "Message" ], " on testhost " ] && StringContainsQ[ text @ auth, acpSSHTerminalCommand @ ssh ],
                    auth[ "Data", "Host" ]
                }
            ],
            $mockProcessScenario = None
        ]
    ],
    Missing[ "TestSkipped" ] | { "NoModels", True, "AuthRequired", True, "testhost" },
    SameTest -> MatchQ,
    TestID   -> "Remote-AuthRequiredText@@Tests/ACPConnection.wlt:2261,1-2289,2"
]

(* Invalid stored SSH settings: an error, and no ssh is started *)
VerificationTest[
    ifRemoteTests @ Module[ { nbo, calls },
        (* calls for this window's host (other remote windows may run their git checks meanwhile) *)
        calls[ ] := Count[ fakeSSHCalls[ ], call_List /; MemberQ[ call, "-oProxyCommand=x" ] ];
        nbo = newWindow[ "~/proj", <| "SSHSettings" -> <| "MachineName" -> "-oProxyCommand=x", "Executable" -> $fakeSSH[ "Executable" ] |> |> ];
        acpEnsureConnected @ nbo;
        {
            waitUntil[ statusQ[ nbo, "Error" ], 30 ],
            KeyTake[ errorOf @ nbo, { "Code", "Actions" } ],
            StringQ @ errorOf[ nbo ][ "Hint" ],
            calls[ ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, <| "Code" -> "InvalidSSHSettings", "Actions" -> { } |>, True, 0 },
    SameTest -> MatchQ,
    TestID   -> "Remote-InvalidStoredSettings@@Tests/ACPConnection.wlt:2292,1-2308,2"
]

(* A folder that doesn't exist on the host: the launch script's marker names it; it is never persisted, and the host's
   persisted last folder is forgotten if it was that folder *)
VerificationTest[
    ifRemoteTests @ Module[ { nbo, missing = $remoteHome <> "/missing" },
        acpSetPersistedSetting[ { "SSH", "testhost", "LastProjectDirectory" }, missing ];
        $localLastDirectory = acpPersistedSetting[ { "LastProjectDirectory" } ];
        nbo = newRemoteWindow[ "~/missing", remoteSSH[ ] ];
        acpEnsureConnected @ nbo;
        {
            waitUntil[ statusQ[ nbo, "Error" ], 30 ],
            KeyTake[ errorOf @ nbo, { "Code", "Actions" } ],
            StringContainsQ[ errorOf[ nbo ][ "Message" ], missing ] && StringContainsQ[ errorOf[ nbo ][ "Message" ], "testhost" ],
            waitUntil[ MissingQ @ acpPersistedSetting[ { "SSH", "testhost", "LastProjectDirectory" } ] ],
            acpPersistedSetting[ { "LastProjectDirectory" } ] === $localLastDirectory,
            acpWindowGet[ nbo, "ProjectDirectory" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        True,
        <| "Code" -> "RemoteFolderMissing", "Actions" -> { "ChooseDirectory", "Reconnect" } |>,
        True,
        True,
        True,
        "~/missing"
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-FolderMissing@@Tests/ACPConnection.wlt:2312,1-2337,2"
]

(* A launch that fails after reporting the remote home (here: a missing folder) still corrects an out-of-date home, in
   the window and persisted for the host; the ~ folder stays as the user gave it *)
VerificationTest[
    ifRemoteTests @ Module[ { nbo },
        acpSetPersistedSetting[ { "SSH", "testhost", "Home" }, "/nonexistent-old-home" ];
        nbo = newRemoteWindow[ "~/missing", remoteSSH[ ] ];
        {
            acpWindowGet[ nbo, "RemoteHome" ],
            acpEnsureConnected @ nbo,
            waitUntil[ statusQ[ nbo, "Error" ], 30 ],
            errorOf[ nbo ][ "Code" ],
            Lookup[ acpWindowGet @ nbo, { "ProjectDirectory", "RemoteHome", "RemoteVerified" } ],
            waitUntil[ acpPersistedSetting[ { "SSH", "testhost", "Home" } ] === $remoteHome ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        "/nonexistent-old-home",
        "Connecting",
        True,
        "RemoteFolderMissing",
        { "~/missing", $remoteHome, False },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-FailedLaunchCorrectsHome@@Tests/ACPConnection.wlt:2341,1-2364,2"
]

(* remoteExitError (a reader handler: kernel state only) gives the home a failed launch reported if it differs from
   the window's, and schedules its persisting for the host; not for the window's own home, a rejected one (a line
   break: the marker is not followed by another one) or an ssh failure before the launch. Runs without ACPLink. *)
VerificationTest[
    Module[ { nonce = "0123456789abcdef", ssh, window, marker, run, missing },
        ssh    = Wolfram`Chatbook`Common`acpSSHSettings @ <| "MachineName" -> "x.exit-home.test" |>;
        window = <|
            "Agent"            -> "OpenCode",
            "Settings"         -> <| "SSHSettings" -> ssh |>,
            "LaunchNonce"      -> nonce,
            "RemoteHome"       -> "/home/ec2-user",
            "ProjectDirectory" -> "~/proj"
        |>;
        marker[ m_String ] := "chatbook-acp:" <> nonce <> ":" <> m <> "\n";
        missing = marker[ "error:no-folder:/home/ubuntu/proj" ];
        run[ w_, exitCode_, stderr_ ] := Module[ { scheduled = { }, r },
            r = Block[ { acpSchedule = Function[ e, AppendTo[ scheduled, HoldForm @ e ], HoldFirst ] },
                Wolfram`Chatbook`ACP`Connection`Private`remoteExitError[ w, exitCode, stderr, True ]
            ];
            {
                Lookup[ r[ "Error" ], "Code" ],
                r[ "RemoteHome" ],
                Cases[ scheduled, HoldForm[ acpSetPersistedSetting[ key_, value_ ] ] :> { key, value } ]
            }
        ];
        {
            run[ window, 120, "chatbook-acp-ready\n" <> marker[ "home:/home/ubuntu" ] <> missing ],
            run[ <| window, "RemoteHome" -> None |>, 120, "chatbook-acp-ready\n" <> marker[ "home:/home/ubuntu" ] <> missing ],
            run[ window, 120, "chatbook-acp-ready\n" <> marker[ "home:/home/ec2-user" ] <> marker[ "error:no-folder:/home/ec2-user/proj" ] ],
            run[ window, 120, "chatbook-acp-ready\n" <> marker[ "home:/home/ubuntu" ] <> "x\n" <> missing ],
            run[ window, 255, "ssh: connect to host x.exit-home.test port 22: Connection refused\r\n" ]
        }
    ],
    {
        { "RemoteFolderMissing", "/home/ubuntu", { { { "SSH", "x.exit-home.test", "Home" }, "/home/ubuntu" } } },
        { "RemoteFolderMissing", "/home/ubuntu", { { { "SSH", "x.exit-home.test", "Home" }, "/home/ubuntu" } } },
        { "RemoteFolderMissing", None, { } },
        { "RemoteFolderMissing", None, { } },
        { "SSHConnectionRefused", None, { } }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-ExitError-Home@@Tests/ACPConnection.wlt:2369,1-2408,2"
]

(* A launch whose home marker is rejected (a line break in the value) is not persisted and does not replace the
   window's home; the folder of the cwd marker is still used (remoteLaunched). Runs without ACPLink: a stand-in
   connection gives the standard error, and the persisted settings are the headless ones. *)
VerificationTest[
    Block[ { $FrontEnd = Null, Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings = <| |> },
        Module[ { nonce = "fedcba9876543210", nbo, conn, marker, done = False, result },
            marker[ m_String ] := "chatbook-acp:" <> nonce <> ":" <> m <> "\n";
            conn[ "StandardError" ] = StringJoin[
                "chatbook-acp-ready\n",
                marker[ "home:/home/evil" ], "x\n",
                marker[ "cwd:/home/evil/proj" ],
                marker[ "agent:/usr/bin/agent" ]
            ];
            nbo = newRemoteWindow[ "~/proj", Wolfram`Chatbook`Common`acpSSHSettings @ <| "MachineName" -> "x.reject.test" |> ];
            acpWindowUpdate[ nbo, <| #, "Connection" -> conn, "LaunchNonce" -> nonce |> & ];
            result = {
                Wolfram`Chatbook`ACP`Connection`Private`remoteLaunched[ nbo, conn, acpWindowGet @ nbo ],
                Lookup[ acpWindowGet @ nbo, { "ProjectDirectory", "ConnectDirectory", "RemoteHome", "RemoteVerified" } ],
                acpSchedule[ done = True ];
                waitUntil[ done, 10 ],
                KeySelect[ Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings, MatchQ @ { "SSH", "x.reject.test", __ } ]
            };
            acpWindowUpdate[ nbo, <| #, "Connection" -> None |> & ];
            acpWindowDrop @ nbo;
            result
        ]
    ],
    {
        True,
        { "/home/evil/proj", "/home/evil/proj", None, True },
        True,
        <| { "SSH", "x.reject.test", "LastProjectDirectory" } -> "/home/evil/proj" |>
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Launched-RejectedHome@@Tests/ACPConnection.wlt:2413,1-2445,2"
]

VerificationTest[
    ifRemoteTests @ Module[ { nbo, error },
        nbo = newRemoteWindow[ "~/proj", remoteSSH[ ], <| "ACPAgentCommandLine" -> "/no/such/agent" |>, "OpenCode" ];
        acpEnsureConnected @ nbo;
        waitUntil[ statusQ[ nbo, "Error" ], 30 ];
        error = errorOf @ nbo;
        {
            error[ "Code" ],
            error[ "Message" ],
            StringContainsQ[ error[ "Hint" ], "https://opencode.ai" ] && StringContainsQ[ error[ "Hint" ], $remoteHome <> "/.opencode/bin/opencode" ]
        }
    ],
    Missing[ "TestSkipped" ] | { "RemoteAgentNotFound", "OpenCode was not found on testhost.", True },
    SameTest -> MatchQ,
    TestID   -> "Remote-AgentMissing@@Tests/ACPConnection.wlt:2447,1-2462,2"
]

(* An agent or ssh that exits right away: its exit (exit code, standard error) is reported, not "InitFailed", even when
   the "initialize" write fails because the process is gone already (the hook delays the write) *)
VerificationTest[
    ifRemoteTests @ Block[ { $acpBeforeInitializeHook = (Pause[ 0.5 ] &) },
        Module[ { t0, dns, bad },
            t0  = AbsoluteTime[ ];
            dns = newRemoteWindow[ "~/proj", remoteSSH[ "x.fail-dns.test" ] ];
            bad = newRemoteWindow[
                "~/proj",
                Wolfram`Chatbook`Common`acpSSHSettings @ <| "MachineName" -> "testhost", "Executable" -> $badSSH, "Arguments" -> { "-o", "Bogus=1" } |>
            ];
            acpEnsureConnected /@ { dns, bad };
            {
                waitUntil[ statusQ[ dns, "Error" ] && statusQ[ bad, "Error" ], 30 ],
                Pause[ 2.5 ], (* the grace period of a failed write is over: the reported error stays *)
                errorOf[ dns ][ "Code" ],
                errorOf[ bad ][ "Code" ],
                StringContainsQ[ errorOf[ bad ][ "Output" ], "Bad configuration option" ],
                initSendFailures[ t0 ] > 0 (* the race this is about did happen *)
            }
        ]
    ],
    Missing[ "TestSkipped" ] | { True, Null, "SSHHostNotFound", "SSHBadArguments", True, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-FastFail-NoInitFailed@@Tests/ACPConnection.wlt:2466,1-2489,2"
]

VerificationTest[
    ifRemoteTests @ Block[ { $acpBeforeInitializeHook = (Pause[ 0.5 ] &) },
        Module[ { t0, nbo },
            t0  = AbsoluteTime[ ];
            nbo = newWindow[ $project1, <| "ACPAgentCommandLine" -> { "/bin/sh", "-c", "echo 'fatal: boom' >&2; exit 3" } |> ];
            acpEnsureConnected @ nbo;
            {
                waitUntil[ statusQ[ nbo, "Error" ], 30 ],
                Pause[ 2.5 ],
                KeyTake[ errorOf @ nbo, { "Code", "Hint", "Output" } ],
                initSendFailures[ t0 ] > 0
            }
        ]
    ],
    Missing[ "TestSkipped" ] | { True, Null, <| "Code" -> "AgentExited", "Hint" -> "Exit code: 3.", "Output" -> "fatal: boom" |>, True },
    SameTest -> MatchQ,
    TestID   -> "Connection-InitSendFailed-Local@@Tests/ACPConnection.wlt:2491,1-2508,2"
]

(* An agent killed by a signal: the launch shell reports 128+n and its own "Killed" line; ssh's silent 255 for an agent
   killed by a signal (x.signal.test) is no lost connection either *)
VerificationTest[
    ifRemoteTests @ Module[ { killed, signal, hint },
        killed = newRemoteWindow[ "~/proj", remoteSSH[ ], <| |>, "MockKiller" ];
        signal = newRemoteWindow[ "~/proj", remoteSSH[ "x.signal.test" ], <| |>, "MockKiller" ];
        acpEnsureConnected /@ { killed, signal };
        hint = "It may have been stopped by the system";
        {
            waitUntil[ statusQ[ killed, "Error" ] && statusQ[ signal, "Error" ], 30 ],
            errorOf[ killed ][ "Code" ],
            errorOf[ killed ][ "Data", "ExitCode" ],
            StringContainsQ[ errorOf[ killed ][ "Hint" ], hint ],
            StringContainsQ[ errorOf[ killed ][ "Output" ], "Killed" ],
            errorOf[ signal ][ "Code" ],
            errorOf[ signal ][ "Data", "ExitCode" ],
            StringContainsQ[ errorOf[ signal ][ "Hint" ], hint ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, "RemoteAgentExited", 137, True, True, "RemoteAgentExited", 255, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-SignalExit@@Tests/ACPConnection.wlt:2512,1-2532,2"
]

(* ssh's own failures (OpenSSH's texts, lines ending in CR LF) *)
VerificationTest[
    ifRemoteTests @ Module[ { hosts, windows, errors },
        hosts = {
            "x.fail-hostkey.test", "x.fail-changed.test", "x.fail-auth.test", "x.fail-keyperm.test",
            "x.fail-refused.test", "x.fail-dns.test", "x.fail-timeout.test", "x.fail-closed.test"
        };
        windows = newRemoteWindow[ "~/proj", remoteSSH[ # ] ] & /@ hosts;
        acpEnsureConnected /@ windows;
        waitUntil[ AllTrue[ windows, statusQ[ #, "Error" ] & ], 30 ];
        errors = errorOf /@ windows;
        {
            Lookup[ errors, "Code" ],
            StringContainsQ[ errors[[ 4 ]][ "Detail" ], acpConnectionLabel[ "ErrorSSHKeyPermissionsDetail" ] ],
            AllTrue[ Lookup[ errors, "Detail" ], StringQ[ # ] && StringFreeQ[ #, "\r" ] & ],
            AllTrue[ errors, #[ "Actions" ] === { "Reconnect" } & ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        {
            "SSHHostKeyUnknown", "SSHHostKeyChanged", "SSHAuthFailed", "SSHAuthFailed",
            "SSHConnectionRefused", "SSHHostNotFound", "SSHUnreachable", "SSHUnreachable"
        },
        True,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-SSHFailures@@Tests/ACPConnection.wlt:2535,1-2563,2"
]

(* A login that never completes ends with the setup timeout *)
VerificationTest[
    ifRemoteTests @ Block[ { Wolfram`Chatbook`ACP`Connection`Private`$acpConnectTimeout = 2 },
        Module[ { nbo },
            nbo = newRemoteWindow[ "~/proj", remoteSSH[ "x.hang.test" ] ];
            acpEnsureConnected @ nbo;
            { waitUntil[ statusQ[ nbo, "Error" ], 30 ], errorOf[ nbo ][ "Code" ], acpWindowGet[ nbo, "Connection" ] }
        ]
    ],
    Missing[ "TestSkipped" ] | { True, "SSHConnectTimeout", None },
    SameTest -> MatchQ,
    TestID   -> "Remote-SetupTimeout@@Tests/ACPConnection.wlt:2566,1-2577,2"
]

(* The kernel is blocked right after ssh was started, for longer than the setup timeout, and housekeeping runs right
   after it, in the same pump tick: the trigger line is on ssh's standard error, unread, so the launch script was never
   written. Housekeeping sees the launch's progress (reading the standard error also releases the script) and its clock
   starts again: the window connects instead of failing with SSHConnectTimeout (D3 finding F2b) *)
VerificationTest[
    ifRemoteTests @ Block[ { Wolfram`Chatbook`ACP`Connection`Private`$acpConnectTimeout = 2 },
        Module[ { nbo },
            nbo = newRemoteWindow[ "~/proj", remoteSSH[ ] ];
            acpEnsureConnected @ nbo;
            (* due right after acpConnect: no reader tick in between, and housekeeping runs right after it *)
            acpSchedule[ Pause[ 3 ]; housekeepingThisTick[ ] ];
            {
                waitUntil[ MemberQ[ { "Ready", "Error" }, acpWindowGet[ nbo, "Status" ] ], 30 ],
                acpWindowGet[ nbo, "Status" ],
                acpWindowGet[ nbo, "Error" ],
                acpWindowGet[ nbo, "LaunchProgress" ] > 0
            }
        ]
    ],
    Missing[ "TestSkipped" ] | { True, "Ready", None, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-StalledKernel-NoSpuriousTimeout@@Tests/ACPConnection.wlt:2583,1-2601,2"
]

(* A slow sign-in (the trigger line comes after 3 s) and a slow agent (another 3 s) with a setup timeout of 4 s: the
   launch reports progress in between, which restarts the clock of "initialize", so the launch is not failed although
   the agent answers more than 6 s after ssh was started. Without the restart the timeout is decided by about 5 s; with
   it, not before about 7 s (4 s after housekeeping saw the agent's marker), while the agent answers at about 6.1 s *)
VerificationTest[
    ifRemoteTests @ withFakeSSHEnvironment[
        <| "FAKE_SSH_DELAY" -> "3" |>,
        Block[ { Wolfram`Chatbook`ACP`Connection`Private`$acpConnectTimeout = 4, $mockStartDelay = 3 },
            Module[ { nbo },
                nbo = newRemoteWindow[ "~/proj", remoteSSH[ "x.slow.test" ], <| |>, "MockACPAgentSlowStart" ];
                acpEnsureConnected @ nbo;
                {
                    waitUntil[ MemberQ[ { "Ready", "Error" }, acpWindowGet[ nbo, "Status" ] ], 30 ],
                    acpWindowGet[ nbo, "Status" ],
                    acpWindowGet[ nbo, "Error" ]
                }
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | { True, "Ready", None },
    SameTest -> MatchQ,
    TestID   -> "Remote-LaunchProgressRestartsTimeout@@Tests/ACPConnection.wlt:2607,1-2625,2"
]

(* A sign-in that does not complete within the setup timeout: the window fails with SSHConnectTimeout and ssh is ended,
   so the launch never completes later (no agent starts once ssh would have signed in) and nothing is left running *)
VerificationTest[
    ifRemoteTests @ withFakeSSHEnvironment[
        <| "FAKE_SSH_DELAY" -> "4" |>,
        Block[ { Wolfram`Chatbook`ACP`Connection`Private`$acpConnectTimeout = 1 },
            Module[ { nbo, conn, pid, log },
                nbo = newRemoteWindow[ "~/proj", remoteSSH[ "x.slow.test" ] ];
                acpEnsureConnected @ nbo;
                waitUntil[ acpConnectionQ @ acpWindowGet[ nbo, "Connection" ] ];
                conn = acpWindowGet[ nbo, "Connection" ];
                pid  = connectionPID @ conn;
                log  = lastLog[ ];
                {
                    waitUntil[ statusQ[ nbo, "Error" ], 20 ],
                    errorOf[ nbo ][ "Code" ],
                    IntegerQ @ pid,
                    waitUntil[ connectionClosedQ @ conn ],
                    ! $procfsQ || waitUntil[ ! processAliveQ @ pid ],
                    Pause[ 4 ]; FileExistsQ @ log
                }
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | { True, "SSHConnectTimeout", True, True, True, False },
    SameTest -> MatchQ,
    TestID   -> "Remote-TimeoutEndsLaunch@@Tests/ACPConnection.wlt:2629,1-2654,2"
]

(* A timeout decided while the launch completes (the decision reads ssh's standard error, which writes a launch script
   whose trigger line arrived unread): the agent starts during the close, and is ended with ssh all the same *)
VerificationTest[
    ifRemoteTests @ Module[ { nbo, conn, pid, log, agent },
        nbo = newRemoteWindow[ "~/proj", remoteSSH[ ] ];
        acpEnsureConnected @ nbo;
        (* right after acpConnect, before the reader ran: the timeout's decision, as housekeeping makes it *)
        acpSchedule[
            Pause[ 1 ];
            With[ { w = acpWindowGet @ nbo },
                conn = w[ "Connection" ];
                pid  = connectionPID @ conn;
                Wolfram`Chatbook`ACP`Connection`Private`failConnection[
                    nbo,
                    conn,
                    Wolfram`Chatbook`ACP`Connection`Private`remoteTimeoutError[ w, conn ]
                ]
            ]
        ];
        {
            waitUntil[ statusQ[ nbo, "Error" ], 20 ] && (log = lastLog[ ]; True),
            IntegerQ @ pid,
            waitUntil[ connectionClosedQ @ conn ],
            ! $procfsQ || waitUntil[ ! processAliveQ @ pid ],
            (* the agent did start, and was ended *)
            waitUntil[ IntegerQ[ agent = mockPID @ log ], 10 ],
            ! $procfsQ || waitUntil[ ! processAliveQ @ agent ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-TimeoutWhileLaunchCompletes@@Tests/ACPConnection.wlt:2658,1-2688,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Ending connections*)

(* A connection that drops after the session started: "Disconnected" with SSHConnectionLost *)
VerificationTest[
    ifRemoteTests @ withFakeSSHEnvironment[
        <| "FAKE_SSH_DROP_AFTER" -> "4" |>,
        Module[ { nbo },
            nbo = newRemoteWindow[ "~/proj", remoteSSH[ "x.drop.test" ] ];
            acpEnsureConnected @ nbo;
            {
                waitUntil[ statusQ[ nbo, "Ready" ], 30 ],
                waitUntil[ statusQ[ nbo, "Disconnected" ], 30 ],
                KeyTake[ errorOf @ nbo, { "Code", "Actions" } ]
            }
        ]
    ],
    Missing[ "TestSkipped" ] | { True, True, <| "Code" -> "SSHConnectionLost", "Actions" -> { "Reconnect" } |> },
    SameTest -> MatchQ,
    TestID   -> "Remote-Drop-Disconnected@@Tests/ACPConnection.wlt:2695,1-2711,2"
]

(* Closing ends the remote agent: ssh's standard input ends, which the agent sees *)
VerificationTest[
    ifRemoteTests @ Module[ { nbo, log, conn, pid },
        nbo = newRemoteWindow[ "~/proj", remoteSSH[ ] ];
        acpEnsureConnected @ nbo;
        waitUntil[ statusQ[ nbo, "Ready" ], 30 ];
        log  = lastLog[ ];
        conn = acpWindowGet[ nbo, "Connection" ];
        pid  = mockPID @ log;
        acpDisconnect[ nbo, "Test" ];
        {
            IntegerQ @ pid,
            waitUntil[ connectionClosedQ @ conn ],
            waitUntil[ mockEventQ[ log, "eof" ] ],
            ! $procfsQ || waitUntil[ ! processAliveQ @ pid ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-Close@@Tests/ACPConnection.wlt:2714,1-2733,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    (* A connection that no window refers to any more is closed by the sweeper *)
    ifConnTests @ Module[ { conn },
        conn = acpWindowGet[ $w3, "Connection" ];
        acpWindowDrop @ $w3;
        Wolfram`Chatbook`ACP`Connection`Private`connectionSweep[ ];
        { acpConnectionQ @ conn, waitUntil[ connectionClosedQ @ conn ] }
    ],
    Missing[ "TestSkipped" ] | { True, True },
    SameTest -> MatchQ,
    TestID   -> "Cleanup-OrphanConnectionSweep@@Tests/ACPConnection.wlt:2738,1-2749,2"
]

VerificationTest[
    ifConnTests[
        Scan[ acpDisconnect[ #, "TestCleanup" ] &, $windows ];
        Scan[ acpWindowDrop, $windows ];
        (* the notebook tools' server that the local windows started keeps the pump running until housekeeping stops it,
           30 s after its last connection (MCP.wl) *)
        acpMCPStopServer[ ];
        {
            waitUntil[ Replace[ Quiet @ ACPConnections[ ], Except[ _List ] -> { } ] === { } ],
            ! $procfsQ || waitUntil[ ! AnyTrue[ mockPID /@ $mockLogs, processAliveQ ] ],
            Length @ $mockLogs > 5,
            waitUntil[ Wolfram`Chatbook`ACP`State`Private`$publisherTask === None ],
            Select[
                Tasks[ ],
                StringContainsQ[
                    ToString[ #[ "EvaluationExpression" ], InputForm ],
                    "acpReaderTick" | "acpIsolated" | "publisherTick" | "closeConnectionNow" | "acpConnect"
                ] &
            ],
            Wolfram`Chatbook`ACP`Connection`Private`$ownedConnections,
            Wolfram`Chatbook`ACP`Connection`Private`$closingConnections
        }
    ],
    Missing[ "TestSkipped" ] | { True, True, True, True, { }, <| |>, <| |> },
    SameTest -> MatchQ,
    TestID   -> "Cleanup-NoLeftoverProcessesOrTasks@@Tests/ACPConnection.wlt:2751,1-2777,2"
]

(* The remote tests' agents, persisted per-host settings and fake ssh (environment variables, scratch copies) *)
VerificationTest[
    KeyDropFrom[ $acpAgents, { "MockACPAgentVars", "MockKiller", "MockACPAgentSlowStart" } ];
    (* the store the remote tests used (ifRemoteTests) *)
    Block[ { $FrontEnd = Null },
        KeyValueMap[ acpSetPersistedSetting[ #1, Replace[ #2, _Missing -> Inherited ] ] &, $savedRemotePersisted ]
    ];
    If[ AssociationQ @ $fakeSSH, fakeSSHCleanup[ ] ];
    (* the latch and the sign-in failure times of the fail-* hosts would refuse or change later automatic runs in the
       same kernel (TestPaclet runs every file in one) *)
    Scan[ (acpRemoteClearHostError[ # ]; KeyDropFrom[ $acpRemoteHostAuthFailedAt, # ]) &, $remoteTestHosts ];
    {
        AnyTrue[ { "MockACPAgentVars", "MockKiller", "MockACPAgentSlowStart" }, KeyExistsQ[ $acpAgents, # ] & ],
        Block[ { $FrontEnd = Null }, AssociationMap[ acpPersistedSetting, Keys @ $savedRemotePersisted ] === $savedRemotePersisted ],
        $fakeSSH,
        (* other files' hosts may still be latched in a shared kernel *)
        Intersection[ Keys @ $acpRemoteHostErrors, $remoteTestHosts ],
        Intersection[ Keys @ $acpRemoteHostAuthFailedAt, $remoteTestHosts ]
    },
    { False, True, None, { }, { } },
    SameTest -> MatchQ,
    TestID   -> "Cleanup-RemoteRestore@@Tests/ACPConnection.wlt:2780,1-2801,2"
]

(* Isolated handlers and tasks swallow messages and failures into the debug log; nothing unexpected may have been logged *)
VerificationTest[
    Select[
        Internal`BagPart[ $acpDebugLog, All ],
        And[
            #[ "Time" ] >= $acpLogStart,
            MemberQ[ { "Message", "Uncaught", "FinalCellFailed", "FinalCellFallback", "FinishedFormattingFallback" }, #[ "Where" ] ]
        ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Cleanup-DebugLog@@Tests/ACPConnection.wlt:2804,1-2815,2"
]

VerificationTest[
    DownValues[ acpTurnDrop ] = $savedTurnDrop;
    KeyDropFrom[ $acpAgents, "MockACPAgent" ];
    Scan[ acpWindowDrop, $windows ];
    $acpAssumeWindowsOpen = False;
    $acpLLMKitEnabled = True;
    Quiet @ DeleteDirectory[ $scratch, DeleteContents -> True ];
    (* Persisted choices and the environment as they were before the tests (Inherited removes a setting). Only changed
       ones are written: with a front end, writing Inherited to an unset {"LastModel", agent} leaves an empty
       "LastModel" in its preferences *)
    KeyValueMap[
        If[ acpPersistedSetting[ #1 ] =!= #2, acpSetPersistedSetting[ #1, Replace[ #2, _Missing -> Inherited ] ] ] &,
        $savedPersisted
    ];
    If[ TrueQ @ $setACPLinkEnv, SetEnvironment[ "ACPLINK_DIRECTORY" -> None ] ];
    (* the notebook tools' server that the local windows started (MCP.wl) *)
    acpMCPStopServer[ ];
    If[ TrueQ @ $setAgentToolsEnv, SetEnvironment[ "AGENTTOOLS_DIRECTORY" -> None ] ];
    {
        KeyExistsQ[ $acpAgents, "MockACPAgent" ],
        DirectoryQ @ $scratch,
        AssociationMap[ acpPersistedSetting, Keys @ $savedPersisted ] === $savedPersisted,
        ! TrueQ @ $setACPLinkEnv || Environment[ "ACPLINK_DIRECTORY" ] === $Failed,
        acpMCPServer[ ]
    },
    { False, False, True, True, None },
    SameTest -> MatchQ,
    TestID   -> "Cleanup-Restore@@Tests/ACPConnection.wlt:2817,1-2845,2"
]

(* :!CodeAnalysis::EndBlock:: *)
