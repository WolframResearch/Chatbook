(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ACPMCP.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ACPMCP.wlt:11,1-16,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`ACP`Common`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-LoadACPContext@@Tests/ACPMCP.wlt:18,1-23,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
(* :!CodeAnalysis::Disable::NoSurroundingCatch:: *)

(* Tests for the MCP server of the notebook tools (ACP/MCP.wl; see docs/acp-window.md, "MCP server"): the setting, the
   OpenCode permission rules, the "mcpServers" parameter, the connections' tokens and their revocation, the queue of tool
   calls and its drain, the hidden pump notebook, the server, and an agent that calls the server.
   The pure tests and the queue tests (with made-up calls) always run. The server tests need an AgentTools paclet with
   StartMCPSocketServer: for development, AGENTTOOLS_DIRECTORY (default ~/AgentTools, if it exists) points to an AgentTools
   checkout; without one (CI) they give Missing["TestSkipped"]. The agent tests also need ACPLink and python3: they run
   the mock agent in Data/ACP/MockAgent (a copy of ACPLink's), whose mcp_request steps call the server the way OpenCode
   does, headlessly (fake NotebookObjects), and so does the drain: the pump drains the queue (also under UsingFrontEnd,
   whose pump tasks see $FrontEnd === Null), and ListNotebooks lists nothing there. The pump notebook test needs a front
   end (UsingFrontEnd) and never fires the button. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    (* CI runs every test file in one kernel and one context: these helpers are only defined here *)
    ClearAll[
        fakeInfo, fakeRun, ifMCP, ifMCPAgent, mcpBodyResult, mcpConnect, mcpDebugLog, mcpEvents, mcpHTTP, mcpJob,
        mcpLastLog, mcpLogSince, mcpNewLog, mcpRecords, mcpRequestsIn, mcpResponses, mcpServersOf, mcpStartTurn,
        mcpTokenOf, mcpTokensOf, mcpWait, mcpWindow, mcpWriteScenario, withMCPState
    ];

    $acpLogStart = AbsoluteTime[ ]; (* see ACPMCP-DebugLog *)
    $mcpSavedAssumeOpen   = $acpAssumeWindowsOpen;
    $mcpSavedLLMKit       = $acpLLMKitEnabled;
    $acpAssumeWindowsOpen = True;
    $acpLLMKitEnabled     = False;

    (* The development copies of AgentTools and ACPLink (the environment is restored by ACPMCP-Cleanup) *)
    $mcpSetAgentToolsEnv = False;
    If[ ! StringQ @ Environment[ "AGENTTOOLS_DIRECTORY" ] && FileExistsQ @ FileNameJoin @ { $HomeDirectory, "AgentTools", "PacletInfo.wl" },
        SetEnvironment[ "AGENTTOOLS_DIRECTORY" -> FileNameJoin @ { $HomeDirectory, "AgentTools" } ];
        $mcpSetAgentToolsEnv = True
    ];
    $mcpSetACPLinkEnv = False;
    If[ ! StringQ @ Environment[ "ACPLINK_DIRECTORY" ] && DirectoryQ @ FileNameJoin @ { $HomeDirectory, "ACPLink", "ACPLink" },
        SetEnvironment[ "ACPLINK_DIRECTORY" -> FileNameJoin @ { $HomeDirectory, "ACPLink", "ACPLink" } ];
        $mcpSetACPLinkEnv = True
    ];

    $mcpPython = SelectFirst[
        { Environment[ "ACPLINK_TEST_PYTHON" ], "/usr/bin/python3", "/usr/local/bin/python3", "/opt/homebrew/bin/python3" },
        StringQ[ # ] && FileExistsQ[ # ] && ! DirectoryQ[ # ] &,
        None
    ];
    $mcpMockScript = FileNameJoin @ { DirectoryName @ $TestFileName, "Data", "ACP", "MockAgent", "mock_acp_agent.py" };
    (* Whether AgentTools was on $ContextPath before Chatbook loaded it (by the user or the host; see ACPMCP-AgentTools) *)
    $mcpAgentToolsOnPath0 = MemberQ[ $ContextPath, "Wolfram`AgentTools`" ];
    $mcpTestsQ      = TrueQ @ acpMCPAvailableQ[ ];
    $mcpAgentTestsQ = TrueQ[ $mcpTestsQ && StringQ @ $mcpPython && FileExistsQ @ $mcpMockScript && acpLinkAvailableQ[ ] && acpLoadACPLink[ ] === True ];
    $mcpFrontEndQ   = TrueQ @ Quiet @ MatchQ[ UsingFrontEnd @ $FrontEnd, _FrontEndObject ];

    (* The server and agent tests let the pump drain the queue, also in a notebook front end's kernel, whose pump would
       fire the queued button instead: its evaluation would wait for the test's own (main link) evaluation to end. The
       Block encloses the tests' waits, so the pump's tasks see it. *)
    ifMCP // Attributes = { HoldFirst };
    ifMCP[ eval_ ] := If[ TrueQ @ $mcpTestsQ,
        Block[ { Wolfram`Chatbook`ACP`MCP`Private`notebookFrontEndQ = False & }, eval ],
        Missing[ "TestSkipped" ]
    ];
    ifMCPAgent // Attributes = { HoldFirst };
    ifMCPAgent[ eval_ ] := If[ TrueQ @ $mcpAgentTestsQ,
        Block[ { Wolfram`Chatbook`ACP`MCP`Private`notebookFrontEndQ = False & }, eval ],
        Missing[ "TestSkipped" ]
    ];

    (* Waiting with Pause lets scheduled tasks (the pump, ACPLink's reader, the server's handler) run: *)
    mcpWait // Attributes = { HoldFirst };
    mcpWait[ cond_, timeout_: 15 ] := Module[ { deadline = AbsoluteTime[ ] + timeout },
        While[ ! TrueQ @ cond && AbsoluteTime[ ] < deadline, Pause[ 0.05 ] ];
        TrueQ @ cond
    ];

    $mcpScratch     = CreateDirectory[ ];
    $mcpScenarioDir = CreateDirectory @ FileNameJoin @ { $mcpScratch, "scenarios" };
    $mcpProject     = ExpandFileName @ CreateDirectory @ FileNameJoin @ { $mcpScratch, "project" };

    (* Made-up windows: the record UI.wl registers *)
    $mcpWindows = { };
    mcpWindow[ settings_Association, rules___Rule ] := With[
        { nbo = NotebookObject[ "acp-mcp-test-" <> ToString[ Length @ $mcpWindows + 1 ] ] },
        AppendTo[ $mcpWindows, nbo ];
        acpWindowUpdate[
            nbo,
            <| #, Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, $mcpProject, "MockMCPAgent", settings ], rules |> &
        ];
        nbo
    ];
    $mcpHTTPCapabilities = <| "loadSession" -> True, "mcpCapabilities" -> <| "http" -> True, "sse" -> False |> |>;
    $mcpRemoteSettings   = <| "SSHSettings" -> Wolfram`Chatbook`Common`acpSSHSettings[ "testhost" ] |>;

    (* The tests of parameters, tokens and the queue use a made-up server record, their own windows, tokens and queue,
       and the pump drains the queue (no pump notebook). The server's housekeeping state is theirs too, so that the
       pump's housekeeping, which sees the Blocked values while a test waits, neither stops the made-up server nor
       counts file descriptors meanwhile. *)
    $mcpFakeServer = <| "Object" -> None, "URL" -> "http://127.0.0.1:1234/mcp", "Port" -> 1234, "StartedAt" -> 0 |>;
    withMCPState // Attributes = { HoldFirst };
    withMCPState[ eval_ ] := Block[
        {
            Wolfram`Chatbook`ACP`Common`$acpWindows             = <| |>,
            Wolfram`Chatbook`ACP`MCP`Private`$mcpServer         = $mcpFakeServer,
            Wolfram`Chatbook`ACP`MCP`Private`$mcpTokens         = <| |>,
            Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue          = { },
            Wolfram`Chatbook`ACP`MCP`Private`$mcpJobs           = { },
            Wolfram`Chatbook`ACP`MCP`Private`$mcpDraining       = False,
            Wolfram`Chatbook`ACP`MCP`Private`$mcpLastKick       = 0,
            Wolfram`Chatbook`ACP`MCP`Private`$mcpEvaluator      = None,
            Wolfram`Chatbook`ACP`MCP`Private`$mcpIdleSince      = None,
            Wolfram`Chatbook`ACP`MCP`Private`$mcpLastFdCheck    = AbsoluteTime[ ],
            Wolfram`Chatbook`ACP`MCP`Private`$mcpFdLimitReached = False,
            Wolfram`Chatbook`ACP`MCP`Private`notebookFrontEndQ = False &
        },
        eval
    ];

    (* Made-up deferred calls, as AgentTools hands them to the evaluation function *)
    $mcpRuns    = { };
    $mcpRejects = { };
    fakeRun[ name_String ] := fakeRun[ name, <| "jsonrpc" -> "2.0", "id" -> 1, "result" -> <| "content" -> { }, "isError" -> False |> |> ];
    fakeRun[ name_String, response_ ] := Function[ AppendTo[ $mcpRuns, name ]; response ];
    fakeInfo[ name_String, token_ ] := fakeInfo[ name, token, True ];
    fakeInfo[ name_String, token_, active_ ] := <|
        "Method"     -> "tools/call",
        "Name"       -> name,
        "Arguments"  -> <| |>,
        "RequestID"  -> 1,
        "Token"      -> token,
        "ReceivedAt" -> AbsoluteTime[ ],
        "Reject"     -> Function[ AppendTo[ $mcpRejects, { name, # } ]; Null ],
        "ActiveQ"    -> Function[ active ]
    |>;
    (* A queued call as acpMCPEnqueue queues it (without the token, with the window and connection of the token) *)
    mcpJob[ run_, info_Association ] := Wolfram`Chatbook`ACP`MCP`Private`queueEntry[ run, info ];

    (* Debug log entries since a time *)
    mcpLogSince[ t0_, where_String ] := Cases[
        Internal`BagPart[ $acpDebugLog, All ],
        KeyValuePattern @ { "Time" -> t_ /; t >= t0, "Where" -> where, "Data" -> d_ } :> d
    ];
    mcpDebugLog[ ] := Internal`BagPart[ $acpDebugLog, All ];

    (* A plain HTTP client of the server *)
    mcpHTTP[ body_Association, headers_List ] := URLRead[
        HTTPRequest[
            acpMCPServer[ ][ "URL" ],
            <|
                "Method"  -> "POST",
                "Headers" -> Join[ { "Accept" -> "application/json, text/event-stream", "Content-Type" -> "application/json" }, headers ],
                "Body"    -> Developer`WriteRawJSONString @ body
            |>
        ],
        TimeConstraint -> 30
    ];
    mcpHTTP[ body_Association, token_String ] := mcpHTTP[ body, { "Authorization" -> "Bearer " <> token } ];
    (* The JSON-RPC result of an answer: JSON, or the message event of an event stream (a deferred call) *)
    mcpBodyResult[ body_String ] := Lookup[
        If[ StringStartsQ[ body, "{" ],
            Developer`ReadRawJSONString @ body,
            First[ StringCases[ body, "data: " ~~ json: Shortest[ __ ] ~~ "\n" :> Developer`ReadRawJSONString @ json ], <| |> ]
        ],
        "result"
    ];

    (* The mock agent, with its own wire log per connection; scenarios are read from $mcpScenarioDir first *)
    $mcpMockLogs = { };
    $mcpProcessScenario = None;
    mcpNewLog[ ] := With[ { file = FileNameJoin @ { $mcpScratch, "mock-" <> ToString[ Length @ $mcpMockLogs + 1 ] <> ".log" } },
        AppendTo[ $mcpMockLogs, file ];
        file
    ];
    $acpAgents[ "MockMCPAgent" ] = <|
        "Name"        -> "MockMCPAgent",
        "Executable"  -> $mcpPython,
        "Arguments"   :> Join[
            { $mcpMockScript, "--log", mcpNewLog[ ], "--scenario-dir", $mcpScenarioDir, "--idle-timeout", "120", "--max-lifetime", "600" },
            If[ StringQ @ $mcpProcessScenario, { "--scenario", $mcpProcessScenario }, { } ]
        ],
        "Environment" -> Inherited
    |>;
    mcpWriteScenario[ name_String, scenario_Association ] := Export[ FileNameJoin @ { $mcpScenarioDir, name <> ".json" }, scenario, "RawJSON" ];
    mcpLastLog[ ] := Last[ $mcpMockLogs, None ];
    $mcpSavedPersisted = AssociationMap[
        acpPersistedSetting,
        { { "LastProjectDirectory" }, { "LastModel", "MockMCPAgent" }, { "LastEffort", "MockMCPAgent" } }
    ];

    (* One read of the wire log's current contents (an unterminated last line is left for later) *)
    mcpRecords[ file_String ] := Module[ { bytes = Quiet @ ReadByteArray @ file, text, lines },
        text  = If[ ByteArrayQ @ bytes, ByteArrayToString[ bytes, "UTF-8" ], "" ];
        lines = StringSplit[ text, "\n" ];
        If[ lines =!= { } && ! StringEndsQ[ text, "\n" ], lines = Most @ lines ];
        Select[ Quiet[ Developer`ReadRawJSONString /@ lines ], AssociationQ ]
    ];
    mcpRequestsIn[ file_String, method_String ] := Cases[
        mcpRecords @ file,
        KeyValuePattern @ { "dir" -> "in", "msg" -> m: KeyValuePattern @ { "method" -> method, "id" -> _ } } :> m
    ];
    mcpEvents[ file_String, name_String ] := Cases[ mcpRecords @ file, r: KeyValuePattern @ { "dir" -> "event", "event" -> name } :> r ];
    (* The mcp_response events of the mock's mcp_request steps, by their "as" *)
    mcpResponses[ file_String ] := Association @ Cases[
        mcpEvents[ file, "mcp_response" ],
        r: KeyValuePattern[ "as" -> as_String ] :> as -> r
    ];
    (* The "mcpServers" of a session request, and the bearer token of its entry *)
    mcpServersOf[ file_String, method_String ] := Lookup[ Lookup[ mcpRequestsIn[ file, method ], "params" ], "mcpServers" ];
    mcpTokenOf[ servers_ ] := Replace[
        servers,
        { { KeyValuePattern[ "headers" -> { KeyValuePattern[ "value" -> v_String ] } ] } :> StringDelete[ v, StartOfString ~~ "Bearer " ], _ -> None }
    ];
    mcpTokensOf[ nbo_ ] := Keys @ Select[ Wolfram`Chatbook`ACP`MCP`Private`$mcpTokens, #[ "Window" ] === nbo & ];

    mcpConnect[ nbo_ ] := (acpEnsureConnected @ nbo; mcpWait[ acpWindowGet[ nbo, "Status" ] === "Ready" ]);

    (* The kernel-side part of UI.wl's acpStartTurn (no cells) *)
    mcpStartTurn[ nbo_, prompt_String ] := Module[ { id = "acp-mcp-turn-" <> CreateUUID[ ] },
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

    (* A thrown value that the queue tests use on purpose (its "Uncaught" entry is expected, see ACPMCP-DebugLog) *)
    $mcpTestThrow = "acp-mcp-test-throw";

    $mcpEntryPattern = KeyValuePattern @ {
        "type"    -> "http",
        "name"    -> "WolframNotebooks",
        "url"     -> _String? (StringMatchQ[ "http://127.0.0.1:" ~~ DigitCharacter.. ~~ "/mcp" ]),
        "headers" -> { KeyValuePattern @ { "name" -> "Authorization", "value" -> _String? (StringMatchQ[ RegularExpression[ "Bearer [0-9a-f]{64}" ] ]) } }
    };
    Null,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Definitions@@Tests/ACPMCP.wlt:44,1-270,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Settings and Permissions*)

(* "ACPMCPServer": True offers the server and False doesn't; Automatic offers it when Chatbook starts the agent's own
   program (which gets OPENCODE_CONFIG_CONTENT with its "ask" rules): the registry's command line, a program, or a
   command line whose program has the name of the agent's *)
VerificationTest[
    {
        acpMCPEnabledQ[ "OpenCode", # ] & /@ {
            <| |>,
            <| "ACPMCPServer" -> True |>,
            <| "ACPMCPServer" -> Automatic |>,
            <| "ACPMCPServer" -> False |>,
            None
        },
        acpMCPEnabledQ[ "OpenCode", <| "ACPAgentCommandLine" -> # |> ] & /@ {
            "/opt/agents/run-opencode",
            File[ "/opt/agents/run-opencode" ],
            { "/usr/local/bin/opencode", "acp", "--print-logs" },
            { File[ "~/.opencode/bin/opencode" ], "acp" },
            { "opencode.cmd", "acp" }
        },
        acpMCPEnabledQ[ "OpenCode", <| "ACPAgentCommandLine" -> # |> ] & /@ {
            { "docker", "run", "-i", "--network=host", "oc-image", "opencode", "acp" },
            { "/usr/bin/env", "-i", "opencode", "acp" },
            { "ssh", "-R", "41234:127.0.0.1:41234", "devbox", "opencode", "acp" },
            { "/opt/agents/opencode-wrapper.sh" }
        },
        {
            acpMCPEnabledQ[ "OpenCode", <| "ACPAgentCommandLine" -> { "docker", "run", "oc" }, "ACPMCPServer" -> True |> ],
            acpMCPEnabledQ[ "OpenCode", <| "ACPAgentCommandLine" -> { "docker", "run", "oc" }, "ACPMCPServer" -> Automatic |> ],
            acpMCPEnabledQ[ "OpenCode", <| "ACPAgentCommandLine" -> { "/usr/local/bin/opencode", "acp" }, "ACPMCPServer" -> False |> ]
        },
        (* an agent that is not in the registry: only its default command line *)
        { acpMCPEnabledQ[ "NoSuchAgent", <| |> ], acpMCPEnabledQ[ "NoSuchAgent", <| "ACPAgentCommandLine" -> { "opencode", "acp" } |> ] }
    },
    {
        { True, True, True, False, True },
        { True, True, True, True, True },
        { False, False, False, False },
        { True, False, False },
        { True, False }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-EnabledQ@@Tests/ACPMCP.wlt:279,1-318,2"
]

(* OpenCode asks before the tools that change open notebooks: its permission names are <server>_<tool>, with characters
   outside [a-zA-Z0-9_-] replaced by "_" *)
VerificationTest[
    {
        $acpMCPServerName,
        acpMCPToolPermissions[ ],
        Wolfram`Chatbook`ACP`MCP`Private`openCodeActionName[ "My server.v2", "a/b tool" ],
        Developer`ReadRawJSONString[ acpOpenCodeConfigJSON[ ] ][ "permission" ]
    },
    {
        "WolframNotebooks",
        <| "WolframNotebooks_InsertCells" -> "ask", "WolframNotebooks_ReplaceCells" -> "ask", "WolframNotebooks_DeleteCells" -> "ask" |>,
        "My_server_v2_a_b_tool",
        <|
            "edit"                          -> "ask",
            "bash"                          -> "ask",
            "WolframNotebooks_InsertCells"  -> "ask",
            "WolframNotebooks_ReplaceCells" -> "ask",
            "WolframNotebooks_DeleteCells"  -> "ask"
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-ToolPermissions@@Tests/ACPMCP.wlt:322,1-343,2"
]

VerificationTest[
    Keys @ acpMCPToolPermissions[ ] === ("WolframNotebooks_" <> # & /@ $acpNotebookEditTools),
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-ToolPermissions-EditTools@@Tests/ACPMCP.wlt:345,1-350,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Session Parameters*)

(* The entry of a local window whose agent supports HTTP MCP servers, with the bearer token of the window's connection;
   http may be true or an object *)
VerificationTest[
    withMCPState @ Module[ { w1, w2, t1, t2, hide },
        w1   = mcpWindow[ <| |>, "Connection" -> "conn-a", "Capabilities" -> $mcpHTTPCapabilities ];
        w2   = mcpWindow[ <| |>, "Connection" -> "conn-b", "Capabilities" -> <| "mcpCapabilities" -> <| "http" -> <| |> |> |> ];
        t1   = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w1, "conn-a" ];
        t2   = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w2, "conn-b" ];
        (* the values of an Association are not evaluated again after a replacement: the condition evaluates them *)
        hide = ReplaceAll[ #, s_String :> With[ { r = StringReplace[ s, { t1 -> "<t1>", t2 -> "<t2>" } ] }, r /; True ] ] &;
        {
            StringMatchQ[ { t1, t2 }, RegularExpression[ "[0-9a-f]{64}" ] ],
            t1 =!= t2,
            hide @ acpMCPServersParam @ w1,
            hide @ acpMCPServersParam @ acpWindowGet @ w2,
            acpMCPServersParam @ acpWindowGet @ w1 === acpMCPServersParam @ w1
        }
    ],
    {
        { True, True },
        True,
        {
            <|
                "type"    -> "http",
                "name"    -> "WolframNotebooks",
                "url"     -> "http://127.0.0.1:1234/mcp",
                "headers" -> { <| "name" -> "Authorization", "value" -> "Bearer <t1>" |> }
            |>
        },
        { KeyValuePattern[ "headers" -> { <| "name" -> "Authorization", "value" -> "Bearer <t2>" |> } ] },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-ServersParam-Entry@@Tests/ACPMCP.wlt:358,1-390,2"
]

(* No entry: the agent does not support HTTP MCP servers (or did not say), a remote window (its agent can't reach this
   computer's 127.0.0.1), the setting is off, there is no server, or the window's connection has no token *)
VerificationTest[
    withMCPState @ Module[ { windows },
        windows = {
            mcpWindow[ <| |>, "Connection" -> "c1", "Capabilities" -> <| "mcpCapabilities" -> <| "http" -> False, "sse" -> True |> |> ],
            mcpWindow[ <| |>, "Connection" -> "c2", "Capabilities" -> <| "loadSession" -> True |> ],
            mcpWindow[ <| |>, "Connection" -> "c3", "Capabilities" -> None ],
            mcpWindow[ $mcpRemoteSettings, "Connection" -> "c4", "Capabilities" -> $mcpHTTPCapabilities ],
            mcpWindow[ <| "ACPMCPServer" -> False |>, "Connection" -> "c5", "Capabilities" -> $mcpHTTPCapabilities ]
        };
        MapThread[ Wolfram`Chatbook`ACP`MCP`Private`issueToken, { windows, { "c1", "c2", "c3", "c4", "c5" } } ];
        {
            acpMCPServersParam /@ windows,
            (* the window's connection has no token: none was issued, or it was issued for an earlier connection *)
            acpMCPServersParam @ mcpWindow[ <| |>, "Connection" -> "c6", "Capabilities" -> $mcpHTTPCapabilities ],
            acpMCPServersParam @ mcpWindow[ <| |>, "Connection" -> None, "Capabilities" -> $mcpHTTPCapabilities ],
            Module[ { w = mcpWindow[ <| |>, "Connection" -> "c7", "Capabilities" -> $mcpHTTPCapabilities ] },
                Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w, "c7" ];
                acpWindowSet[ w, "Connection", "c8" ];
                acpMCPServersParam @ w
            ],
            (* no server *)
            Module[ { w = mcpWindow[ <| |>, "Connection" -> "c9", "Capabilities" -> $mcpHTTPCapabilities ] },
                Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w, "c9" ];
                { Length @ acpMCPServersParam @ w, Block[ { Wolfram`Chatbook`ACP`MCP`Private`$mcpServer = None }, acpMCPServersParam @ w ] }
            ],
            acpMCPServersParam @ NotebookObject[ "acp-mcp-no-such-window" ],
            acpMCPServersParam @ Missing[ "NotFound" ]
        }
    ],
    { { { }, { }, { }, { }, { } }, { }, { }, { }, { 1, { } }, { }, { } },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-ServersParam-None@@Tests/ACPMCP.wlt:394,1-426,2"
]

(* A command line that runs another program than the agent's (here env, which could drop OPENCODE_CONFIG_CONTENT and
   so the "ask" rules of the edit tools) gets the server only with "ACPMCPServer" -> True; no token is issued without
   it *)
VerificationTest[
    withMCPState @ Module[ { env, auto, explicit },
        env      = { "/usr/bin/env", "-i", "opencode", "acp" };
        auto     = mcpWindow[ <| "ACPAgentCommandLine" -> env |>, "Agent" -> "OpenCode", "Connection" -> "cl-1", "Capabilities" -> $mcpHTTPCapabilities ];
        explicit = mcpWindow[
            <| "ACPAgentCommandLine" -> env, "ACPMCPServer" -> True |>,
            "Agent"        -> "OpenCode",
            "Connection"   -> "cl-2",
            "Capabilities" -> $mcpHTTPCapabilities
        ];
        {
            acpMCPConnectionStarted[ auto, "cl-1" ],
            acpMCPServersParam @ auto,
            StringQ @ acpMCPConnectionStarted[ explicit, "cl-2" ],
            acpMCPServersParam @ explicit
        }
    ],
    { None, { }, True, { $mcpEntryPattern } },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-ServersParam-CommandLine@@Tests/ACPMCP.wlt:431,1-451,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tokens*)

(* A connection of a local window with the setting on gets a token when there is a server; tokens are random *)
VerificationTest[
    withMCPState @ Module[ { local, remote, off, tokens },
        local  = mcpWindow[ <| |>, "Connection" -> "conn-1" ];
        remote = mcpWindow[ $mcpRemoteSettings, "Connection" -> "conn-2" ];
        off    = mcpWindow[ <| "ACPMCPServer" -> False |>, "Connection" -> "conn-3" ];
        tokens = {
            acpMCPConnectionStarted[ local, "conn-1" ],
            acpMCPConnectionStarted[ remote, "conn-2" ],
            acpMCPConnectionStarted[ off, "conn-3" ],
            Block[ { Wolfram`Chatbook`ACP`MCP`Private`$mcpServer = None }, acpMCPConnectionStarted[ local, "conn-1" ] ]
        };
        {
            StringMatchQ[ First @ tokens, RegularExpression[ "[0-9a-f]{64}" ] ],
            Rest @ tokens,
            acpMCPAuthorizedQ @ First @ tokens,
            Length @ Wolfram`Chatbook`ACP`MCP`Private`$mcpTokens,
            Length @ DeleteDuplicates @ Table[ Wolfram`Chatbook`ACP`MCP`Private`newToken[ ], 20 ]
        }
    ],
    { True, { None, None, None }, True, 1, 20 },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Token-Issue@@Tests/ACPMCP.wlt:458,1-480,2"
]

(* Only a valid token's connection is authorized; the handler also calls the function with None (no header) *)
VerificationTest[
    withMCPState[ acpMCPAuthorizedQ /@ { None, "", "abc", 42, Missing[ ] } ],
    { False, False, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Token-Unknown@@Tests/ACPMCP.wlt:483,1-488,2"
]

(* Every way a connection ends revokes its token: another connection, a failed connection (connectionFailedRecord),
   a disconnect, a forgotten window record (the agent's exit is tested with the mock agent below); housekeeping forgets
   revoked tokens and keeps valid ones *)
VerificationTest[
    withMCPState @ Module[ { windows, tokens, before, after },
        windows = Table[ mcpWindow[ <| |>, "Connection" -> "conn-" <> ToString @ i ], { i, 5 } ];
        tokens  = MapIndexed[ Wolfram`Chatbook`ACP`MCP`Private`issueToken[ #1, "conn-" <> ToString @ First @ #2 ] &, windows ];
        before  = acpMCPAuthorizedQ /@ tokens;
        acpWindowSet[ windows[[ 1 ]], "Connection", "conn-other" ];
        acpWindowUpdate[ windows[[ 2 ]], Wolfram`Chatbook`ACP`Connection`Private`connectionFailedRecord[ #, <| "Code" -> "Test" |> ] & ];
        acpDisconnect[ windows[[ 3 ]], "Test" ];
        Wolfram`Chatbook`ACP`UI`Private`acpForgetWindow @ windows[[ 4 ]];
        after = acpMCPAuthorizedQ /@ tokens;
        Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ];
        {
            before,
            after,
            Keys @ Wolfram`Chatbook`ACP`MCP`Private`$mcpTokens === { tokens[[ 5 ]] },
            acpWindowGet[ windows[[ 3 ]], "Connection" ]
        }
    ],
    { { True, True, True, True, True }, { False, False, False, False, True }, True, None },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Token-Revoked@@Tests/ACPMCP.wlt:493,1-514,2"
]

(* Turning "ACPMCPServer" off revokes the connection's token at once (the window only reconnects after a running turn):
   the handler answers 401 (acpMCPAuthorizedQ), a call that was queued before is rejected, and housekeeping forgets the
   token. So does a command line that no longer runs the agent's own program, with Automatic. *)
VerificationTest[
    withMCPState @ Module[ { w1, w2, t1, t2, before, t0 = AbsoluteTime[ ] },
        $mcpRuns = { }; $mcpRejects = { };
        w1 = mcpWindow[ <| |>, "Connection" -> "off-1" ];
        w2 = mcpWindow[ <| |>, "Connection" -> "off-2" ];
        t1 = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w1, "off-1" ];
        t2 = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w2, "off-2" ];
        before = acpMCPAuthorizedQ /@ { t1, t2 };
        PreemptProtect[
            acpMCPEnqueue[ fakeRun[ "Queued" ], fakeInfo[ "Queued", t1 ] ];
            acpWindowUpdate[ w1, <| #, "Settings" -> <| "ACPMCPServer" -> False |> |> & ];
            acpWindowUpdate[ w2, <| #, "Settings" -> <| "ACPAgentCommandLine" -> { "/usr/bin/env", "opencode", "acp" } |> |> & ]
        ];
        mcpWait[ Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue === { } && ! Wolfram`Chatbook`ACP`MCP`Private`$mcpDraining ];
        Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ];
        {
            before,
            acpMCPAuthorizedQ /@ { t1, t2 },
            $mcpRuns,
            $mcpRejects,
            mcpLogSince[ t0, "MCPToolRejected" ],
            Wolfram`Chatbook`ACP`MCP`Private`$mcpTokens,
            acpWindowGet[ w1, "Connection" ]
        }
    ],
    {
        { True, True },
        { False, False },
        { },
        { { "Queued", "The ACP connection that made this call has ended." } },
        { <| "Tool" -> "Queued" |> },
        <| |>,
        "off-1"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Token-SettingOffRevokes@@Tests/ACPMCP.wlt:519,1-555,2"
]

(* The token is a secret: it is in no window record (nor the parameter's result anywhere but the request) *)
VerificationTest[
    withMCPState @ Module[ { w, token },
        w     = mcpWindow[ <| |>, "Connection" -> "conn-s", "Capabilities" -> $mcpHTTPCapabilities ];
        token = acpMCPConnectionStarted[ w, "conn-s" ];
        acpMCPServersParam @ w;
        {
            StringQ @ token,
            StringFreeQ[ ToString[ acpWindowGet @ w, InputForm ], token ],
            StringFreeQ[ ToString[ mcpDebugLog[ ], InputForm ], token ]
        }
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Token-NotInRecord@@Tests/ACPMCP.wlt:558,1-572,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Queue*)

(* The handler only queues the call; the pump drains the queue (no notebook front end) and runs the call *)
VerificationTest[
    withMCPState @ Module[ { w, token, t0 = AbsoluteTime[ ] },
        $mcpRuns = { }; $mcpRejects = { };
        w     = mcpWindow[ <| |>, "Connection" -> "conn-q1" ];
        token = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w, "conn-q1" ];
        {
            acpMCPEnqueue[ fakeRun[ "ListNotebooks" ], fakeInfo[ "ListNotebooks", token ] ],
            mcpWait[ $mcpRuns =!= { } && Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue === { } && ! Wolfram`Chatbook`ACP`MCP`Private`$mcpDraining ],
            $mcpRuns,
            $mcpRejects,
            mcpLogSince[ t0, "MCPToolCall" ]
        }
    ],
    {
        Null,
        True,
        { "ListNotebooks" },
        { },
        { <| "Tool" -> "ListNotebooks", "Mode" -> "Pump", "Status" -> "OK", "Waited" -> _? NumberQ, "Seconds" -> _? NumberQ |> }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Queue-Drain@@Tests/ACPMCP.wlt:579,1-601,2"
]

(* Calls run in the order they were queued, one after the other, and the status says what run[] gave *)
VerificationTest[
    withMCPState @ Module[ { w, token, t0 = AbsoluteTime[ ] },
        $mcpRuns = { };
        w     = mcpWindow[ <| |>, "Connection" -> "conn-q2" ];
        token = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w, "conn-q2" ];
        PreemptProtect[
            acpMCPEnqueue[ fakeRun[ "A" ], fakeInfo[ "A", token ] ];
            acpMCPEnqueue[ fakeRun[ "B", <| "id" -> 2, "result" -> <| "isError" -> True |> |> ], fakeInfo[ "B", token ] ];
            acpMCPEnqueue[ fakeRun[ "C", <| "id" -> 3, "error" -> <| "code" -> -32603 |> |> ], fakeInfo[ "C", token ] ];
            acpMCPEnqueue[ fakeRun[ "D", Null ], fakeInfo[ "D", token ] ]
        ];
        mcpWait[ Length @ $mcpRuns === 4 && Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue === { } ];
        { $mcpRuns, Lookup[ mcpLogSince[ t0, "MCPToolCall" ], { "Tool", "Status" } ] }
    ],
    { { "A", "B", "C", "D" }, { { "A", "OK" }, { "B", "Error" }, { "C", "Error" }, { "D", "NotRun" } } },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Queue-Order@@Tests/ACPMCP.wlt:604,1-621,2"
]

(* Other main link jobs (acpMainLinkRun: the preparation of a message's attachments) are run by the same drain, after the
   tool calls; a job leaves the queue before it runs, and the pump keeps running while one waits *)
VerificationTest[
    withMCPState @ Module[ { w, token, t0 = AbsoluteTime[ ], jobs = { }, waiting },
        $mcpRuns = { };
        w     = mcpWindow[ <| |>, "Connection" -> "conn-q9" ];
        token = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w, "conn-q9" ];
        PreemptProtect[
            acpMainLinkRun[ w, AppendTo[ jobs, { "J1", $mcpRuns, Length @ Wolfram`Chatbook`ACP`MCP`Private`$mcpJobs } ], "TestJob" ];
            acpMCPEnqueue[ fakeRun[ "A" ], fakeInfo[ "A", token ] ];
            acpMainLinkRun[ w, AppendTo[ jobs, { "J2", $mcpRuns, Length @ Wolfram`Chatbook`ACP`MCP`Private`$mcpJobs } ] ];
            waiting = Wolfram`Chatbook`ACP`MCP`Private`waitingQ[ ]
        ];
        {
            waiting,
            mcpWait[ Length @ jobs === 2 && Wolfram`Chatbook`ACP`MCP`Private`$mcpJobs === { } && ! Wolfram`Chatbook`ACP`MCP`Private`$mcpDraining ],
            jobs,
            Lookup[ mcpLogSince[ t0, "MainLinkJob" ], { "Label", "Mode" } ],
            Wolfram`Chatbook`ACP`MCP`Private`waitingQ[ ]
        }
    ],
    { True, True, { { "J1", { "A" }, 1 }, { "J2", { "A" }, 0 } }, { { "TestJob", "Pump" }, { "Job", "Pump" } }, False },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Queue-MainLinkJobs@@Tests/ACPMCP.wlt:625,1-647,2"
]

(* A call whose connection has ended is rejected without running it; one that is no longer active (answered,
   cancelled, its client gone) is skipped *)
VerificationTest[
    withMCPState @ Module[ { w, token, t0 = AbsoluteTime[ ] },
        $mcpRuns = { }; $mcpRejects = { };
        w     = mcpWindow[ <| |>, "Connection" -> "conn-q3" ];
        token = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w, "conn-q3" ];
        acpWindowSet[ w, "Connection", None ];
        PreemptProtect[
            acpMCPEnqueue[ fakeRun[ "Ended" ], fakeInfo[ "Ended", token ] ];
            acpMCPEnqueue[ fakeRun[ "Unknown" ], fakeInfo[ "Unknown", "not-a-token" ] ];
            acpMCPEnqueue[ fakeRun[ "Inactive" ], fakeInfo[ "Inactive", token, False ] ]
        ];
        mcpWait[ Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue === { } && ! Wolfram`Chatbook`ACP`MCP`Private`$mcpDraining ];
        { $mcpRuns, $mcpRejects, mcpLogSince[ t0, "MCPToolRejected" ], mcpLogSince[ t0, "MCPToolSkipped" ] }
    ],
    {
        { },
        {
            { "Ended", "The ACP connection that made this call has ended." },
            { "Unknown", "The ACP connection that made this call has ended." }
        },
        { <| "Tool" -> "Ended" |>, <| "Tool" -> "Unknown" |> },
        { <| "Tool" -> "Inactive" |> }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Queue-RejectAndSkip@@Tests/ACPMCP.wlt:651,1-676,2"
]

(* An internal error never leaves the agent waiting: the call is answered with an error, and the drain goes on *)
VerificationTest[
    withMCPState @ Module[ { w, token, t0 = AbsoluteTime[ ] },
        $mcpRuns = { }; $mcpRejects = { };
        w     = mcpWindow[ <| |>, "Connection" -> "conn-q4" ];
        token = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w, "conn-q4" ];
        PreemptProtect[
            acpMCPEnqueue[ Function[ Throw @ $mcpTestThrow ], fakeInfo[ "Throws", token ] ];
            acpMCPEnqueue[ fakeRun[ "After" ], fakeInfo[ "After", token ] ]
        ];
        mcpWait[ Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue === { } && ! Wolfram`Chatbook`ACP`MCP`Private`$mcpDraining ];
        {
            $mcpRuns,
            $mcpRejects,
            Count[ mcpLogSince[ t0, "Uncaught" ], KeyValuePattern[ "Value" -> $mcpTestThrow ] ]
        }
    ],
    { { "After" }, { { "Throws", "The tool call failed because of an internal error in Chatbook." } }, 1 },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Queue-InternalError@@Tests/ACPMCP.wlt:679,1-698,2"
]

(* run[] gives a Failure for an internal error in AgentTools while it claimed or answered the call: a call that is still
   active afterwards is answered with an error, one that AgentTools answered is not *)
VerificationTest[
    withMCPState @ Module[ { w, token, t0 = AbsoluteTime[ ] },
        $mcpRuns = { }; $mcpRejects = { };
        w     = mcpWindow[ <| |>, "Connection" -> "conn-q6" ];
        token = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w, "conn-q6" ];
        PreemptProtect[
            acpMCPEnqueue[ fakeRun[ "Active", Failure[ "Internal", <| |> ] ], fakeInfo[ "Active", token ] ];
            acpMCPEnqueue[
                fakeRun[ "Answered", Failure[ "Internal", <| |> ] ],
                <| fakeInfo[ "Answered", token ], "ActiveQ" -> Function[ ! MemberQ[ $mcpRuns, "Answered" ] ] |>
            ]
        ];
        mcpWait[ Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue === { } && ! Wolfram`Chatbook`ACP`MCP`Private`$mcpDraining ];
        { $mcpRuns, $mcpRejects, Lookup[ mcpLogSince[ t0, "MCPToolCall" ], { "Tool", "Status" } ] }
    ],
    {
        { "Active", "Answered" },
        { { "Active", "The tool call failed because of an internal error in Chatbook." } },
        { { "Active", "Error" }, { "Answered", "Error" } }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Queue-RunFailure@@Tests/ACPMCP.wlt:702,1-724,2"
]

(* The queue never holds the bearer token: a tool's internal failure during a drain is logged (as "NotebookToolFailed",
   and its message as "Message") with the evaluation stack ("Stack" :> $stack, in the failure's data), which must not
   show it (the stack has the drain's frames, such as runJob), nor may anything else in the log *)
VerificationTest[
    withMCPState @ Module[ { w, token, t0 = AbsoluteTime[ ], log, stacks },
        w     = mcpWindow[ <| |>, "Connection" -> "conn-q7" ];
        token = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w, "conn-q7" ];
        acpMCPEnqueue[
            Function[
                Wolfram`Chatbook`ACP`NotebookTools`Private`toolResult[
                    "ReadNotebook",
                    Wolfram`Chatbook`Common`throwInternalFailure @ mcpFailingCall[ 1 ]
                ];
                <| "jsonrpc" -> "2.0", "id" -> 1, "result" -> <| "content" -> { }, "isError" -> True |> |>
            ],
            fakeInfo[ "ReadNotebook", token ]
        ];
        mcpWait[ Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue === { } && ! Wolfram`Chatbook`ACP`MCP`Private`$mcpDraining ];
        log    = Select[ mcpDebugLog[ ], #[ "Time" ] >= t0 & ];
        stacks = Cases[
            log /. failure_Failure :> With[ { data = Last @ failure }, data /; True ],
            data_Association /; KeyExistsQ[ data, "Stack" ] :> Lookup[ data, "Stack" ],
            Infinity
        ];
        {
            Lookup[ mcpLogSince[ t0, "NotebookToolFailed" ], "Tool" ],
            MatchQ[ stacks, { { __ }.. } ] && AnyTrue[ stacks, StringContainsQ[ ToString[ #, InputForm ], "runJob" ] & ],
            StringFreeQ[ ToString[ log, InputForm ], token ],
            StringFreeQ[ ToString[ stacks, InputForm ], token ],
            FreeQ[ Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue, token ]
        }
    ],
    { { "ReadNotebook" }, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Queue-TokenNotInStack@@Tests/ACPMCP.wlt:729,1-761,2"
]

(* The pump keeps running while calls wait (only they decide it here: no dirty symbols, background runs, windows or
   server), and while the server runs; a running drain takes new calls itself (the kick does nothing) *)
VerificationTest[
    withMCPState @ Block[
        {
            Wolfram`Chatbook`ACP`State`Private`$dirty      = <| |>,
            Wolfram`Chatbook`ACP`Common`acpBackgroundRunsQ = False &,
            Wolfram`Chatbook`ACP`MCP`Private`$mcpServer    = None
        },
        Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue    = { mcpJob[ fakeRun[ "Waiting" ], fakeInfo[ "Waiting", "x" ] ] };
        Wolfram`Chatbook`ACP`MCP`Private`$mcpDraining = True;
        $mcpRuns = { };
        {
            acpMCPPendingQ[ ],
            Wolfram`Chatbook`ACP`State`Private`publisherNeededQ[ ],
            acpMCPKick[ ],
            Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ],
            Length @ Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue,
            $mcpRuns,
            Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue = { };
            Wolfram`Chatbook`ACP`State`Private`publisherNeededQ[ ],
            Wolfram`Chatbook`ACP`MCP`Private`$mcpServer = $mcpFakeServer;
            Wolfram`Chatbook`ACP`State`Private`publisherNeededQ[ ]
        }
    ],
    { True, True, Null, Null, 1, { }, False, True },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Queue-PumpAlive@@Tests/ACPMCP.wlt:765,1-791,2"
]

(* An abort (Alt+.) at any point of a drain never leaves it claimed, which would stop every later drain: the claim is
   made where an abort can't interrupt it, and only a claim that was made is released. The drains here are aborted
   at random points (an empty queue: each drain only claims, releases and cleans up). *)
VerificationTest[
    withMCPState @ Block[ { Wolfram`Chatbook`ACP`MCP`Private`$mcpPumpNotebook = None },
        Module[ { stuck },
            stuck = BlockRandom[
                Table[
                    Wolfram`Chatbook`ACP`MCP`Private`$mcpDraining = False;
                    TimeConstrained[ While[ True, acpMCPDrain[ ] ], RandomReal[ { 0.002, 0.02 } ] ];
                    TrueQ @ Wolfram`Chatbook`ACP`MCP`Private`$mcpDraining,
                    { 300 }
                ],
                RandomSeeding -> 2
            ];
            { Count[ stuck, True ], Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue }
        ]
    ],
    { 0, { } },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Queue-DrainAbortReleases@@Tests/ACPMCP.wlt:796,1-814,2"
]

(* The watchdog: calls that wait with no drain running are drained again once the last trigger is older than
   $mcpRetriggerDelay (the front end merges triggers and drops a pending run when the evaluation ahead of it is
   aborted) *)
VerificationTest[
    withMCPState @ Module[ { w, token, job },
        $mcpRuns = { };
        w     = mcpWindow[ <| |>, "Connection" -> "conn-q5" ];
        token = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w, "conn-q5" ];
        job   = mcpJob[ fakeRun[ "Stranded" ], fakeInfo[ "Stranded", token ] ];
        Wolfram`Chatbook`ACP`MCP`Private`$mcpLastKick = AbsoluteTime[ ];
        Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue    = { job };
        Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ];
        {
            $mcpRuns,
            Wolfram`Chatbook`ACP`MCP`Private`$mcpLastKick = AbsoluteTime[ ] - 10;
            Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ];
            mcpWait[ Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue === { } ];
            $mcpRuns
        }
    ],
    { { }, { "Stranded" } },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Queue-Watchdog@@Tests/ACPMCP.wlt:819,1-839,2"
]

(* Only a notebook front end's kernel fires the pump button: a plain kernel has no front end, and UsingFrontEnd's
   main evaluation has $Notebooks and a FrontEndObject but no parent link (its pump tasks see no front end at all) *)
VerificationTest[
    Which[
        MatchQ[ $ParentLink, _LinkObject ], Missing[ "TestSkipped" ], (* the tests run in a notebook front end's kernel *)
        ! TrueQ @ $mcpFrontEndQ, { Wolfram`Chatbook`ACP`MCP`Private`notebookFrontEndQ[ ], Missing[ "NoFrontEnd" ] },
        True, {
            Wolfram`Chatbook`ACP`MCP`Private`notebookFrontEndQ[ ],
            UsingFrontEnd @ { TrueQ @ $Notebooks, MatchQ[ $FrontEnd, _FrontEndObject ], Wolfram`Chatbook`ACP`MCP`Private`notebookFrontEndQ[ ] }
        }
    ],
    Missing[ "TestSkipped" ] | { False, Missing[ "NoFrontEnd" ] } | { False, { True, True, False } },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-NotebookFrontEndQ@@Tests/ACPMCP.wlt:843,1-855,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Pump Notebook*)

(* Hidden, never saved, excluded from AI, evaluated by the ACP windows' kernel; the button is queued and calls the drain
   by its full name *)
VerificationTest[
    Wolfram`Chatbook`ACP`MCP`Private`pumpNotebook[ "Local 2" ],
    Notebook[
        {
            Cell[
                BoxData @ ButtonBox[
                    "\"ACP MCP\"",
                    ButtonFunction :> Wolfram`Chatbook`ACP`Common`acpMCPDrain[ ],
                    Evaluator      -> "Local 2",
                    Method         -> "Queued",
                    BoxID          -> "ACPMCPPump"
                ],
                "Text",
                CellTags -> "ACPMCPPump"
            ]
        },
        Visible      -> False,
        Saveable     -> False,
        Evaluator    -> "Local 2",
        WindowTitle  -> "ACP MCP Pump",
        TaggingRules -> <| "ACPMCPPump" -> <| "KernelSessionID" -> $SessionID |>, "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |> |>
    ],
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-PumpNotebook-Expression@@Tests/ACPMCP.wlt:863,1-887,2"
]

(* In a front end (the button is never fired here): the notebook is made with its button's BoxObject; it is invisible,
   and the notebook tools don't list it; making it again closes the earlier one, but not the pump of another kernel;
   cleaning keeps only the button's cell *)
VerificationTest[
    If[ TrueQ @ $mcpFrontEndQ,
        UsingFrontEnd @ Module[ { box1, nb1, visible, box2, nb2, other, listed, cleaned, result },
            other = NotebookPut @ Wolfram`Chatbook`ACP`MCP`Private`pumpNotebook[ "ACPMCPOtherKernel" ];
            box1  = Wolfram`Chatbook`ACP`MCP`Private`createPump[ "ACPMCPTestKernel" ];
            nb1   = Wolfram`Chatbook`ACP`MCP`Private`$mcpPumpNotebook;
            visible = { CurrentValue[ nb1, Visible ], MemberQ[ Notebooks[ ], nb1 ] };
            listed = Developer`ReadRawJSONString[ SelectFirst[ acpNotebookTools[ ], #[ "Name" ] === "ListNotebooks" & ][ <| |> ] ];
            box2  = Wolfram`Chatbook`ACP`MCP`Private`createPump[ "ACPMCPTestKernel" ];
            nb2   = Wolfram`Chatbook`ACP`MCP`Private`$mcpPumpNotebook;
            NotebookWrite[ NotebookLocationSpecifier[ First @ Cells @ nb2, "After" ], Cell[ "printed", "Print" ], None ];
            cleaned = { Length @ Cells @ nb2, Wolfram`Chatbook`ACP`MCP`Private`cleanPumpNotebook[ ]; NotebookRead @ Cells @ nb2 };
            result = {
                MatchQ[ box1, _BoxObject ],
                visible,
                NoneTrue[ Lookup[ listed, "id", { } ], StringStartsQ[ First @ nb1, # ] & ],
                MatchQ[ box2, _BoxObject ] && box2 =!= box1,
                MemberQ[ Notebooks[ ], nb1 ],
                MemberQ[ Notebooks[ ], nb2 ] && MemberQ[ Notebooks[ ], other ],
                Wolfram`Chatbook`ACP`MCP`Private`pumpNotebookQ[ nb2, "ACPMCPTestKernel" ],
                Wolfram`Chatbook`ACP`MCP`Private`pumpNotebookQ[ other, "ACPMCPTestKernel" ],
                cleaned
            };
            Wolfram`Chatbook`ACP`MCP`Private`closePumpNotebooks[ "ACPMCPTestKernel" ];
            NotebookClose @ other;
            Append[ result, MemberQ[ Notebooks[ ], nb2 ] || MemberQ[ Notebooks[ ], other ] ]
        ],
        Missing[ "TestSkipped" ]
    ],
    Missing[ "TestSkipped" ] | {
        True,
        { False, True },
        True,
        True,
        False,
        True,
        True,
        False,
        { 2, { Cell[ BoxData[ _ButtonBox ], "Text", ___, CellTags -> "ACPMCPPump", ___ ] } },
        False
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-PumpNotebook-FrontEnd@@Tests/ACPMCP.wlt:892,1-935,2"
]

(* The pump button's kernel is never guessed: in a notebook front end's kernel, the first window that gets a token
   names it (its Evaluator), and until one has, the pump drains the queue itself instead of making a pump notebook; a
   kernel without a notebook front end makes no front end call for it. Here the button can't be fired, so after the
   pump notebook was made (for the named kernel) the pump drains the queue too. *)
VerificationTest[
    withMCPState @ Module[ { evaluator = $Failed, pumps = { }, w1, w2, t1, t2, t0 = AbsoluteTime[ ], plain, first },
        $mcpRuns = { };
        Block[
            {
                Wolfram`Chatbook`ACP`MCP`Private`windowEvaluator = (evaluator &),
                Wolfram`Chatbook`ACP`MCP`Private`fireTrigger     = False &,
                Wolfram`Chatbook`ACP`MCP`Private`createPump      = (AppendTo[ pumps, # ]; None) &
            },
            w1 = mcpWindow[ <| |>, "Connection" -> "ev-1" ];
            w2 = mcpWindow[ <| |>, "Connection" -> "ev-2" ];
            (* no notebook front end: the window's kernel is not read *)
            evaluator = "Local 2";
            Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w1, "ev-0" ];
            plain = Wolfram`Chatbook`ACP`MCP`Private`$mcpEvaluator;
            Block[ { Wolfram`Chatbook`ACP`MCP`Private`notebookFrontEndQ = True & },
                (* the window's Evaluator could not be read: still unknown *)
                evaluator = $Failed;
                t1 = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w1, "ev-1" ];
                acpMCPEnqueue[ fakeRun[ "A" ], fakeInfo[ "A", t1 ] ];
                mcpWait[ $mcpRuns === { "A" } && ! Wolfram`Chatbook`ACP`MCP`Private`$mcpDraining ];
                first = { Wolfram`Chatbook`ACP`MCP`Private`$mcpEvaluator, pumps };
                evaluator = "Local 2";
                t2 = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w2, "ev-2" ];
                acpMCPEnqueue[ fakeRun[ "B" ], fakeInfo[ "B", t2 ] ];
                mcpWait[ $mcpRuns === { "A", "B" } && ! Wolfram`Chatbook`ACP`MCP`Private`$mcpDraining ]
            ]
        ];
        {
            plain,
            first,
            Wolfram`Chatbook`ACP`MCP`Private`$mcpEvaluator,
            pumps,
            $mcpRuns,
            mcpLogSince[ t0, "MCPPumpFailed" ],
            Lookup[ mcpLogSince[ t0, "MCPToolCall" ], "Mode" ]
        }
    ],
    {
        None,
        { None, { } },
        "Local 2",
        { "Local 2" },
        { "A", "B" },
        { <| "Code" -> "NoEvaluator" |>, <| "Code" -> "Trigger" |> },
        { "Pump", "Pump" }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-PumpNotebook-Evaluator@@Tests/ACPMCP.wlt:941,1-990,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Server Lifecycle*)

(* Housekeeping stops the server once no connection has had a valid token for $mcpIdleStopDelay seconds (the next
   connect starts it again); the pump keeps running for that while the server runs. A connect that finds the server
   running (acpMCPEnsureServer, right before its connection gets a token) starts the count again. *)
VerificationTest[
    withMCPState @ Module[ { w, t0 = AbsoluteTime[ ], valid, idle, connect, stopped },
        w = mcpWindow[ <| |>, "Connection" -> "idle-1" ];
        Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w, "idle-1" ];
        Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ];
        valid = { Wolfram`Chatbook`ACP`MCP`Private`$mcpIdleSince, acpMCPPendingQ[ ] };
        acpDisconnect[ w, "Test" ];
        Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ];
        idle = {
            NumberQ @ Wolfram`Chatbook`ACP`MCP`Private`$mcpIdleSince,
            AssociationQ @ Wolfram`Chatbook`ACP`MCP`Private`$mcpServer,
            Wolfram`Chatbook`ACP`MCP`Private`$mcpTokens
        };
        Wolfram`Chatbook`ACP`MCP`Private`$mcpIdleSince = AbsoluteTime[ ] - Wolfram`Chatbook`ACP`MCP`Private`$mcpIdleStopDelay - 1;
        connect = Block[ { Wolfram`Chatbook`ACP`MCP`Private`serverRunningQ = True & },
            { acpMCPEnsureServer[ ] === $mcpFakeServer, Wolfram`Chatbook`ACP`MCP`Private`$mcpIdleSince }
        ];
        Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ];
        AppendTo[ connect, AssociationQ @ Wolfram`Chatbook`ACP`MCP`Private`$mcpServer ];
        Wolfram`Chatbook`ACP`MCP`Private`$mcpIdleSince = AbsoluteTime[ ] - Wolfram`Chatbook`ACP`MCP`Private`$mcpIdleStopDelay - 1;
        Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ];
        stopped = { Wolfram`Chatbook`ACP`MCP`Private`$mcpServer, Wolfram`Chatbook`ACP`MCP`Private`$mcpIdleSince, acpMCPPendingQ[ ] };
        { valid, idle, connect, stopped, mcpLogSince[ t0, "MCPServerStopped" ] }
    ],
    {
        { None, True },
        { True, True, <| |> },
        { True, None, True },
        { None, None, False },
        { <| "Reason" -> "Idle" |> }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Server-IdleStop@@Tests/ACPMCP.wlt:999,1-1032,2"
]

(* The file descriptor guard: the limit is the soft limit of open files, at most select()'s FD_SETSIZE (1024). Above 75%
   of it, housekeeping stops the server and logs it, and no server is started again in the kernel session (also when
   the count is too high at the start); the sessions then get no MCP servers. *)
VerificationTest[
    withMCPState @ Module[ { fds = 700, soft = 524288, w, t0 = AbsoluteTime[ ], limits, below, above, start },
        Block[
            {
                Wolfram`Chatbook`ACP`MCP`Private`kernelFileDescriptors = (fds &),
                Wolfram`Chatbook`ACP`MCP`Private`softFileLimit         = (soft &)
            },
            limits = Table[ soft = s; Wolfram`Chatbook`ACP`MCP`Private`fileDescriptorLimit[ ], { s, { 524288, 256, None, 0 } } ];
            soft = 524288;
            w = mcpWindow[ <| |>, "Connection" -> "fd-1", "Capabilities" -> $mcpHTTPCapabilities ];
            Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w, "fd-1" ];
            Wolfram`Chatbook`ACP`MCP`Private`$mcpLastFdCheck = 0;
            Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ];
            below = { AssociationQ @ Wolfram`Chatbook`ACP`MCP`Private`$mcpServer, Wolfram`Chatbook`ACP`MCP`Private`$mcpFdLimitReached };
            fds = 800;
            Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ]; (* not due yet *)
            Wolfram`Chatbook`ACP`MCP`Private`$mcpLastFdCheck = 0;
            Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ];
            above = {
                Wolfram`Chatbook`ACP`MCP`Private`$mcpServer,
                Wolfram`Chatbook`ACP`MCP`Private`$mcpFdLimitReached,
                acpMCPServersParam @ w,
                acpMCPEnsureServer[ ]
            };
            (* a kernel that already holds too many when the server would start *)
            start = Block[
                {
                    Wolfram`Chatbook`ACP`MCP`Private`$mcpFdLimitReached = False,
                    Wolfram`Chatbook`ACP`MCP`Private`$mcpServer         = None
                },
                { acpMCPEnsureServer[ ], Wolfram`Chatbook`ACP`MCP`Private`$mcpFdLimitReached }
            ]
        ];
        { limits, below, above, start, mcpLogSince[ t0, "MCPServerFdLimit" ] }
    ],
    {
        { 1024, 256, 1024, 1024 },
        { True, False },
        { None, True, { }, Failure[ "MCPServerFdLimit", _ ] },
        { Failure[ "MCPServerFdLimit", _ ], True },
        { <| "FileDescriptors" -> 800, "Limit" -> 1024 |>, <| "FileDescriptors" -> 800, "Limit" -> 1024 |> }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Server-FdGuard@@Tests/ACPMCP.wlt:1037,1-1081,2"
]

(* The kernel's file descriptors are counted where /proc/self/fd exists (Linux), and nowhere else *)
VerificationTest[
    {
        Wolfram`Chatbook`ACP`MCP`Private`kernelFileDescriptors[ ],
        Wolfram`Chatbook`ACP`MCP`Private`fileDescriptorLimit[ ]
    },
    If[ $OperatingSystem === "Unix" && DirectoryQ[ "/proc/self/fd" ],
        { _Integer? Positive, _Integer? (1 <= # <= 1024 &) },
        { None, 1024 }
    ],
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Server-FdCount@@Tests/ACPMCP.wlt:1084,1-1095,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Server*)

(* AgentTools is loaded without putting its context on $ContextPath (unless it was there before Chatbook loaded it) *)
VerificationTest[
    ifMCP @ {
        acpMCPAvailableQ[ ],
        MemberQ[ $Packages, "Wolfram`AgentTools`" ],
        Wolfram`Chatbook`ACP`MCP`Private`$agentToolsLoaded,
        $mcpAgentToolsOnPath0 || ! MemberQ[ $ContextPath, "Wolfram`AgentTools`" ]
    },
    Missing[ "TestSkipped" ] | { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-AgentTools@@Tests/ACPMCP.wlt:1102,1-1112,2"
]

(* A loaded AgentTools that is too old (e.g. the installed one, which a front end's kernel loads at startup) is replaced
   only by the one of AGENTTOOLS_DIRECTORY, if that declares StartMCPSocketServer; otherwise the result is kept until the
   variable changes. A missing AgentTools is looked for again. (Made-up state: nothing is loaded.) *)
VerificationTest[
    Module[ { newQ = False, dir = None, paclet = None, gets = 0, t0 = AbsoluteTime[ ], status, steps },
        Block[
            {
                Wolfram`Chatbook`ACP`MCP`Private`$agentToolsLoaded      = None,
                Wolfram`Chatbook`ACP`MCP`Private`agentToolsLoadedQ     = True &,
                Wolfram`Chatbook`ACP`MCP`Private`socketServerFunctionQ = (newQ &),
                Wolfram`Chatbook`ACP`MCP`Private`agentToolsDirectory   = (dir &),
                Wolfram`Chatbook`ACP`MCP`Private`findAgentTools        = (paclet &),
                Wolfram`Chatbook`ACP`MCP`Private`getAgentTools         = (gets++; newQ = True) &
            },
            status = { Replace[ #, Failure[ tag_, as_ ] :> { tag, Lookup[ as, "Directory" ] } ], gets } &;
            steps = {
                (* no AGENTTOOLS_DIRECTORY: too old, and kept *)
                status @ Wolfram`Chatbook`ACP`MCP`Private`loadAgentTools[ ],
                (paclet = "a-paclet"; status @ Wolfram`Chatbook`ACP`MCP`Private`loadAgentTools[ ]),
                (* a directory without such an AgentTools: tried once *)
                (dir = "/dev/at1"; paclet = None; status @ Wolfram`Chatbook`ACP`MCP`Private`loadAgentTools[ ]),
                (paclet = "a-paclet"; status @ Wolfram`Chatbook`ACP`MCP`Private`loadAgentTools[ ]),
                (* another directory, with one: it is loaded *)
                (dir = "/dev/at2"; status @ Wolfram`Chatbook`ACP`MCP`Private`loadAgentTools[ ]),
                status @ Wolfram`Chatbook`ACP`MCP`Private`loadAgentTools[ ]
            };
            (* not loaded and not found: looked for again at the next connect *)
            Block[
                {
                    Wolfram`Chatbook`ACP`MCP`Private`$agentToolsLoaded  = None,
                    Wolfram`Chatbook`ACP`MCP`Private`agentToolsLoadedQ = False &,
                    Wolfram`Chatbook`ACP`MCP`Private`findAgentTools    = None &
                },
                AppendTo[
                    steps,
                    { status @ Wolfram`Chatbook`ACP`MCP`Private`loadAgentTools[ ], Wolfram`Chatbook`ACP`MCP`Private`$agentToolsLoaded }
                ]
            ]
        ];
        { steps, mcpLogSince[ t0, "MCPAgentToolsReloaded" ] }
    ],
    {
        {
            { { "AgentToolsTooOld", None }, 0 },
            { { "AgentToolsTooOld", None }, 0 },
            { { "AgentToolsTooOld", "/dev/at1" }, 0 },
            { { "AgentToolsTooOld", "/dev/at1" }, 0 },
            { True, 1 },
            { True, 1 },
            { { { "AgentToolsMissing", Missing[ "KeyAbsent", "Directory" ] }, 1 }, None }
        },
        { <| "Version" -> None |> }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-AgentTools-Reload@@Tests/ACPMCP.wlt:1117,1-1169,2"
]

(* One server per kernel: started once, then reused; its start logs only the port *)
VerificationTest[
    ifMCP @ Module[ { t0 = AbsoluteTime[ ], first, second },
        acpMCPStopServer[ ];
        first  = acpMCPEnsureServer[ ];
        second = acpMCPEnsureServer[ ];
        {
            KeyDrop[ first, "Object" ],
            first === second,
            acpMCPServer[ ][ { "Name", "Path", "Token", "Running" } ],
            acpMCPServer[ ][ "URL" ] === first[ "URL" ],
            mcpLogSince[ t0, "MCPServerStarted" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        <| "URL" -> _String? (StringMatchQ[ "http://127.0.0.1:" ~~ DigitCharacter.. ~~ "/mcp" ]), "Port" -> _Integer, "StartedAt" -> _Real |>,
        True,
        <| "Name" -> "WolframNotebooks", "Path" -> "/mcp", "Token" -> None, "Running" -> True |>,
        True,
        { <| "Port" -> _Integer |> }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Server-Start@@Tests/ACPMCP.wlt:1172,1-1194,2"
]

(* A server that stopped running (e.g. deleted by hand) is replaced at the next connect *)
VerificationTest[
    ifMCP @ Module[ { old },
        old = acpMCPServer[ ];
        DeleteObject @ old;
        { old[ "Running" ], acpMCPEnsureServer[ ][ "Object" ] =!= old, acpMCPServer[ ][ "Running" ] }
    ],
    Missing[ "TestSkipped" ] | { False, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Server-Restart@@Tests/ACPMCP.wlt:1197,1-1206,2"
]

(* Over HTTP: initialize (instructions, Chatbook's version), the six tools, a tool call through the queue, and 401s for
   a missing or an unknown token, the token of a window whose setting was turned off, and a revoked one *)
VerificationTest[
    ifMCP @ Module[ { w, token, init, list, call, noAuth, wrong, off, revoked, t0 = AbsoluteTime[ ] },
        w     = mcpWindow[ <| |>, "Status" -> "Ready", "Connection" -> "conn-http" ];
        token = Wolfram`Chatbook`ACP`MCP`Private`issueToken[ w, "conn-http" ];
        init  = mcpHTTP[
            <|
                "jsonrpc" -> "2.0",
                "id"      -> 1,
                "method"  -> "initialize",
                "params"  -> <| "protocolVersion" -> "2025-06-18", "capabilities" -> <| |>, "clientInfo" -> <| "name" -> "test", "version" -> "1" |> |>
            |>,
            token
        ];
        list   = mcpHTTP[ <| "jsonrpc" -> "2.0", "id" -> 2, "method" -> "tools/list" |>, token ];
        call   = mcpHTTP[ <| "jsonrpc" -> "2.0", "id" -> 3, "method" -> "tools/call", "params" -> <| "name" -> "ListNotebooks", "arguments" -> <| |> |> |>, token ];
        noAuth = mcpHTTP[ <| "jsonrpc" -> "2.0", "id" -> 4, "method" -> "tools/list" |>, { } ];
        wrong  = mcpHTTP[ <| "jsonrpc" -> "2.0", "id" -> 5, "method" -> "tools/list" |>, StringReverse @ token ];
        acpWindowUpdate[ w, <| #, "Settings" -> <| "ACPMCPServer" -> False |> |> & ];
        off = mcpHTTP[ <| "jsonrpc" -> "2.0", "id" -> 6, "method" -> "tools/list" |>, token ];
        acpWindowSet[ w, "Connection", None ];
        revoked = mcpHTTP[ <| "jsonrpc" -> "2.0", "id" -> 7, "method" -> "tools/list" |>, token ];
        acpWindowDrop @ w;
        {
            init[ "StatusCode" ],
            KeyTake[ Developer`ReadRawJSONString[ init[ "Body" ] ][ "result" ], { "serverInfo", "instructions" } ],
            list[ "StatusCode" ],
            Lookup[ Developer`ReadRawJSONString[ list[ "Body" ] ][ "result", "tools" ], "name" ],
            call[ "StatusCode" ],
            mcpBodyResult @ call[ "Body" ],
            Lookup[ mcpLogSince[ t0, "MCPToolCall" ], { "Tool", "Mode", "Status" } ],
            { noAuth[ "StatusCode" ], wrong[ "StatusCode" ], off[ "StatusCode" ], revoked[ "StatusCode" ] }
        }
    ],
    Missing[ "TestSkipped" ] | {
        200,
        <|
            "serverInfo"   -> <| "name" -> "WolframNotebooks", "version" -> Wolfram`Chatbook`Common`$thisPaclet[ "Version" ] |>,
            "instructions" -> _String? (StringContainsQ[ #, "ListNotebooks" ] && StringContainsQ[ #, "approval" ] &)
        |>,
        200,
        { "ListNotebooks", "ReadNotebook", "CreateNotebook", "InsertCells", "ReplaceCells", "DeleteCells" },
        200,
        <| "content" -> { <| "type" -> "text", "text" -> "[]" |> }, "isError" -> False |>,
        { { "ListNotebooks", "Pump", "OK" } },
        { 401, 401, 401, 401 }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Server-HTTP@@Tests/ACPMCP.wlt:1210,1-1258,2"
]

(* An idle server is stopped (its listener closes) and the next connect starts a new one *)
VerificationTest[
    ifMCP @ Module[ { old },
        old = acpMCPServer[ ];
        Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ]; (* no window has a valid token *)
        Wolfram`Chatbook`ACP`MCP`Private`$mcpIdleSince = AbsoluteTime[ ] - Wolfram`Chatbook`ACP`MCP`Private`$mcpIdleStopDelay - 1;
        Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ];
        { old[ "Running" ], acpMCPServer[ ], acpMCPEnsureServer[ ][ "Object" ] =!= old, acpMCPServer[ ][ "Running" ] }
    ],
    Missing[ "TestSkipped" ] | { False, None, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Server-IdleStopRestart@@Tests/ACPMCP.wlt:1261,1-1272,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Agent*)

(* The session gets the server with the token of its connection; the token is in no window record, debug log entry,
   persisted setting or notebook flag, and not in the server's summary box. The connect starts the server, in the pump,
   as for a real window (the agent tests below use that server). *)
VerificationTest[
    ifMCPAgent @ Module[ { servers, token, feSets = { }, t0 = AbsoluteTime[ ] },
        acpMCPStopServer[ ];
        $mcpW1 = mcpWindow[ <| |> ];
        Block[ { acpFESet = (AppendTo[ feSets, { ## } ]; #3) & },
            mcpConnect @ $mcpW1
        ];
        servers = First[ mcpServersOf[ mcpLastLog[ ], "session/new" ], None ];
        token   = mcpTokenOf @ servers;
        $mcpToken1 = token;
        {
            acpWindowGet[ $mcpW1, "Status" ],
            Length @ mcpLogSince[ t0, "MCPServerStarted" ],
            servers,
            servers[[ 1, "url" ]] === acpMCPServer[ ][ "URL" ],
            acpMCPAuthorizedQ @ token,
            mcpTokensOf @ $mcpW1 === { token },
            StringFreeQ[
                ToString[
                    {
                        acpWindowGet @ $mcpW1,
                        mcpDebugLog[ ],
                        feSets,
                        Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings,
                        ToBoxes @ acpMCPServer[ ]
                    },
                    InputForm
                ],
                token
            ]
        }
    ],
    Missing[ "TestSkipped" ] | { "Ready", 1, { $mcpEntryPattern }, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Agent-SessionNew@@Tests/ACPMCP.wlt:1281,1-1316,2"
]

(* The agent calls the server like OpenCode: initialize (then notifications/initialized), tools/list, a tool call
   (headless: ListNotebooks lists nothing), and requests with a wrong or no bearer token get 401 *)
VerificationTest[
    ifMCPAgent @ Module[ { log = mcpLastLog[ ], t0 = AbsoluteTime[ ], responses, initialized },
        mcpWriteScenario[ "cb-mcp-tools", <|
            "description" -> "Calls the session's MCP server the way OpenCode does",
            "steps"       -> {
                <| "type" -> "mcp_request", "method" -> "initialize", "as" -> "init" |>,
                <| "type" -> "mcp_request", "method" -> "tools/list", "as" -> "list" |>,
                <| "type" -> "mcp_request", "method" -> "tools/call", "params" -> <| "name" -> "ListNotebooks", "arguments" -> <| |> |>, "as" -> "nbs" |>,
                <| "type" -> "mcp_request", "method" -> "tools/list", "headers" -> <| "Authorization" -> "Bearer wrong" |>, "as" -> "wrong" |>,
                <| "type" -> "mcp_request", "method" -> "tools/list", "headers" -> <| "Authorization" -> Null |>, "as" -> "none" |>,
                <| "type" -> "notify", "update" -> <| "sessionUpdate" -> "agent_message_chunk", "content" -> <| "type" -> "text", "text" -> "${mcpText:nbs}" |> |> |>,
                <| "type" -> "respond" |>
            }
        |> ];
        mcpStartTurn[ $mcpW1, "scenario:cb-mcp-tools" ];
        mcpWait[ mcpEvents[ log, "scenario_end" ] =!= { } && acpWindowGet[ $mcpW1, "Status" ] === "Ready", 30 ];
        responses   = mcpResponses @ log;
        initialized = SelectFirst[ mcpEvents[ log, "mcp_response" ], #[ "method" ] === "notifications/initialized" &, <| |> ];
        {
            Lookup[ responses, { "init", "list", "nbs", "wrong", "none" } ][[ All, "status" ]],
            responses[ "init", "body", "result", "serverInfo", "name" ],
            initialized[ "status" ],
            Lookup[ responses[ "list", "body", "result", "tools" ], "name" ],
            responses[ "nbs", "body", "result" ],
            Lookup[ mcpLogSince[ t0, "MCPToolCall" ], { "Tool", "Status" } ],
            mcpEvents[ log, "mcp_error" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        { 200, 200, 200, 401, 401 },
        "WolframNotebooks",
        202,
        { "ListNotebooks", "ReadNotebook", "CreateNotebook", "InsertCells", "ReplaceCells", "DeleteCells" },
        <| "content" -> { <| "type" -> "text", "text" -> "[]" |> }, "isError" -> False |>,
        { { "ListNotebooks", "OK" } },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Agent-Tools@@Tests/ACPMCP.wlt:1320,1-1359,2"
]

(* A reconnect resumes the session with the new connection's token; the old one is revoked *)
VerificationTest[
    ifMCPAgent @ Module[ { servers, token },
        acpReconnect @ $mcpW1;
        mcpWait[ acpWindowGet[ $mcpW1, "Status" ] === "Ready" && mcpRequestsIn[ mcpLastLog[ ], "session/resume" ] =!= { } ];
        servers = First[ mcpServersOf[ mcpLastLog[ ], "session/resume" ], None ];
        token   = mcpTokenOf @ servers;
        $mcpToken2 = token;
        Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ];
        {
            servers,
            token =!= $mcpToken1,
            acpMCPAuthorizedQ /@ { $mcpToken1, token },
            mcpTokensOf @ $mcpW1 === { token },
            mcpHTTP[ <| "jsonrpc" -> "2.0", "id" -> 1, "method" -> "tools/list" |>, $mcpToken1 ][ "StatusCode" ]
        }
    ],
    Missing[ "TestSkipped" ] | { { $mcpEntryPattern }, True, { False, True }, True, 401 },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Agent-Resume@@Tests/ACPMCP.wlt:1362,1-1381,2"
]

(* The agent exits: its connection's token is revoked *)
VerificationTest[
    ifMCPAgent @ (
        mcpWriteScenario[ "cb-mcp-exit", <| "steps" -> { <| "type" -> "exit", "code" -> 3 |> } |> ];
        mcpStartTurn[ $mcpW1, "scenario:cb-mcp-exit" ];
        {
            mcpWait[ acpWindowGet[ $mcpW1, "Connection" ] === None ],
            acpMCPAuthorizedQ @ $mcpToken2
        }
    ),
    Missing[ "TestSkipped" ] | { True, False },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Agent-ExitRevokes@@Tests/ACPMCP.wlt:1384,1-1396,2"
]

(* No server: the setting is off (no token either), or the agent does not support HTTP MCP servers *)
VerificationTest[
    ifMCPAgent @ Module[ { off, offLog, noHTTP, noHTTPLog },
        off = mcpWindow[ <| "ACPMCPServer" -> False |> ];
        mcpConnect @ off;
        offLog = mcpLastLog[ ];
        mcpWriteScenario[ "cb-mcp-nohttp", <|
            "agent" -> <|
                "agentCapabilities" -> <|
                    "loadSession"         -> True,
                    "mcpCapabilities"     -> <| "http" -> False, "sse" -> False |>,
                    "sessionCapabilities" -> <| "close" -> <| |>, "list" -> <| |>, "resume" -> <| |> |>
                |>
            |>
        |> ];
        $mcpProcessScenario = "cb-mcp-nohttp";
        noHTTP = mcpWindow[ <| |> ];
        mcpConnect @ noHTTP;
        noHTTPLog = mcpLastLog[ ];
        $mcpProcessScenario = None;
        {
            acpWindowGet[ off, "Status" ],
            mcpServersOf[ offLog, "session/new" ],
            mcpTokensOf @ off,
            acpWindowGet[ noHTTP, "Status" ],
            mcpServersOf[ noHTTPLog, "session/new" ]
        }
    ],
    Missing[ "TestSkipped" ] | { "Ready", { { } }, { }, "Ready", { { } } },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Agent-NoServer@@Tests/ACPMCP.wlt:1399,1-1429,2"
]

(* A command line that runs another program than the agent's (here env, starting the mock agent) gets no server and no
   token with the default setting, since the "ask" rules might not reach the agent; with "ACPMCPServer" -> True it
   does *)
VerificationTest[
    ifMCPAgent @ With[ { env = SelectFirst[ { "/usr/bin/env", "/bin/env" }, FileExistsQ, None ] },
        If[ env === None,
            Missing[ "NoEnv" ],
            Module[ { commandLine, auto, autoLog, explicit, explicitLog },
                commandLine = Function[ log,
                    {
                        env, $mcpPython, $mcpMockScript, "--log", log, "--scenario-dir", $mcpScenarioDir,
                        "--idle-timeout", "120", "--max-lifetime", "600"
                    }
                ];
                autoLog = mcpNewLog[ ];
                auto    = mcpWindow[ <| "ACPAgentCommandLine" -> commandLine @ autoLog |> ];
                mcpConnect @ auto;
                explicitLog = mcpNewLog[ ];
                explicit    = mcpWindow[ <| "ACPAgentCommandLine" -> commandLine @ explicitLog, "ACPMCPServer" -> True |> ];
                mcpConnect @ explicit;
                {
                    acpWindowGet[ auto, "Status" ],
                    mcpServersOf[ autoLog, "session/new" ],
                    mcpTokensOf @ auto,
                    acpWindowGet[ explicit, "Status" ],
                    mcpServersOf[ explicitLog, "session/new" ],
                    Length @ mcpTokensOf @ explicit
                }
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | Missing[ "NoEnv" ] | { "Ready", { { } }, { }, "Ready", { { $mcpEntryPattern } }, 1 },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Agent-CommandLine@@Tests/ACPMCP.wlt:1434,1-1465,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    Scan[ acpDisconnect[ #, "TestCleanup" ] &, $mcpWindows ];
    If[ TrueQ @ $mcpAgentTestsQ, mcpWait[ Replace[ Quiet @ acpLink[ "ACPConnections" ][ ], Except[ _List ] -> { } ] === { } ] ];
    Scan[ acpWindowDrop, $mcpWindows ];
    acpMCPStopServer[ ];
    Wolfram`Chatbook`ACP`MCP`Private`mcpHousekeeping[ ];
    KeyDropFrom[ $acpAgents, "MockMCPAgent" ];
    KeyValueMap[
        If[ acpPersistedSetting[ #1 ] =!= #2, acpSetPersistedSetting[ #1, Replace[ #2, _Missing -> Inherited ] ] ] &,
        $mcpSavedPersisted
    ];
    If[ TrueQ @ $mcpSetAgentToolsEnv, SetEnvironment[ "AGENTTOOLS_DIRECTORY" -> None ] ];
    If[ TrueQ @ $mcpSetACPLinkEnv, SetEnvironment[ "ACPLINK_DIRECTORY" -> None ] ];
    $acpAssumeWindowsOpen = $mcpSavedAssumeOpen;
    $acpLLMKitEnabled     = $mcpSavedLLMKit;
    Quiet @ DeleteDirectory[ $mcpScratch, DeleteContents -> True ];
    {
        acpMCPServer[ ],
        Wolfram`Chatbook`ACP`MCP`Private`$mcpTokens,
        Wolfram`Chatbook`ACP`MCP`Private`$mcpQueue,
        AssociationMap[ acpPersistedSetting, Keys @ $mcpSavedPersisted ] === $mcpSavedPersisted
    },
    { None, <| |>, { }, True },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-Cleanup@@Tests/ACPMCP.wlt:1470,1-1495,2"
]

(* Isolated code swallows messages and failures into the debug log: nothing unexpected may have been logged (the
   queue tests throw $mcpTestThrow on purpose, and ACPMCP-Queue-TokenNotInStack fails mcpFailingCall internally, which
   gives a message) *)
VerificationTest[
    Select[
        mcpDebugLog[ ],
        And[
            #[ "Time" ] >= $acpLogStart,
            MemberQ[ { "Message", "Uncaught", "FinalCellFailed", "FinalCellFallback", "FinishedFormattingFallback" }, #[ "Where" ] ],
            ! MatchQ[ #[ "Data" ], KeyValuePattern[ "Value" -> $mcpTestThrow ] ],
            FreeQ[ #[ "Data" ], mcpFailingCall ]
        ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPMCP-DebugLog@@Tests/ACPMCP.wlt:1500,1-1513,2"
]

(* :!CodeAnalysis::EndBlock:: *)
