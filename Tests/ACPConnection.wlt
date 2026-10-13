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
   (Missing["TestSkipped"]) if ACPLink (with the UpdateInterval option of OpenACPConnection) or python3 is missing.
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
    TestID   -> "ACPConnection-LoadACPContext@@Tests/ACPConnection.wlt:33,1-38,2"
]

VerificationTest[
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
    TestID   -> "ACPConnection-Definitions@@Tests/ACPConnection.wlt:40,1-172,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Agents*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*OpenCode Configuration*)
VerificationTest[
    Developer`ReadRawJSONString @ acpOpenCodeConfigJSON[ ],
    <| "$schema" -> "https://opencode.ai/config.json", "permission" -> <| "edit" -> "ask", "bash" -> "ask" |> |>,
    SameTest -> MatchQ,
    TestID   -> "OpenCodeConfigJSON-NoLLMKit@@Tests/ACPConnection.wlt:181,1-186,2"
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
        <| "edit" -> "ask", "bash" -> "ask" |>,
        "@ai-sdk/openai-compatible",
        "https://services.wolfram.com/api/llmkit/v1",
        "Bearer {env:LLMKIT_API_KEY}",
        Sort @ { "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano", "gpt-4o", "gpt-4o-mini", "gpt-5-mini", "gpt-5-nano", "gpt-5.2", "gpt-5.4", "gpt-5.4-mini", "gpt-5.4-nano" },
        True,
        False
    },
    SameTest -> MatchQ,
    TestID   -> "OpenCodeConfigJSON-LLMKit@@Tests/ACPConnection.wlt:188,1-213,2"
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
    TestID   -> "OpenCodeEnvironment-NoKey@@Tests/ACPConnection.wlt:215,1-229,2"
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
    TestID   -> "OpenCodeEnvironment-Key@@Tests/ACPConnection.wlt:231,1-243,2"
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
    TestID -> "OpenCodeEnvironment-UnpassableVariables@@Tests/ACPConnection.wlt:245,1-259,2"
]

VerificationTest[
    (* Disabled in these tests: no network request is made *)
    acpLLMKitAPIKey[ ],
    None,
    SameTest -> MatchQ,
    TestID   -> "LLMKitAPIKey-Disabled@@Tests/ACPConnection.wlt:261,1-267,2"
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
    TestID   -> "LLMKitKey-Definitions@@Tests/ACPConnection.wlt:272,1-303,2"
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
    TestID   -> "LLMKitKey-UsesActiveKeyWithGrant@@Tests/ACPConnection.wlt:305,1-320,2"
]

VerificationTest[
    findKey[ <| "Keys" -> { keyRecord[ "No grant", "fake-key-a", "Active", { "MCPAPIs", "AgentOne" } ] }, "Grants" -> { "AgentOne", "MCPAPIs" } |>, (True &) ],
    { <| "Key" -> None, "Status" -> "NoPermission", "Definitive" -> True |>, { { "GET", "keys", None }, { "GET", "permissions", None } } },
    SameTest -> MatchQ,
    TestID   -> "LLMKitKey-NeverUsesKeysWithoutGrant@@Tests/ACPConnection.wlt:322,1-327,2"
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
    TestID   -> "LLMKitKey-CreatesKey@@Tests/ACPConnection.wlt:329,1-342,2"
]

VerificationTest[
    findKey[ <| "Keys" -> { }, "Grants" -> { "LLMKitAPIs" }, "CreateSucceeds" -> True |>, (False &) ],
    { <| "Key" -> None, "Status" -> "CreationNotAllowed", "Definitive" -> False |>, { { "GET", "keys", None }, { "GET", "permissions", None } } },
    SameTest -> MatchQ,
    TestID   -> "LLMKitKey-CreationNotAllowed@@Tests/ACPConnection.wlt:344,1-349,2"
]

VerificationTest[
    findKey[
        <| "Keys" -> { keyRecord[ "Chatbook ACP access to LLMKit", "fake-key-d", "Inactive", { "LLMKitAPIs" } ] }, "Grants" -> { "LLMKitAPIs" }, "CreateSucceeds" -> True |>,
        (True &)
    ],
    { <| "Key" -> None, "Status" -> "KeyNameTaken", "Definitive" -> True |>, { { "GET", "keys", None }, { "GET", "permissions", None } } },
    SameTest -> MatchQ,
    TestID   -> "LLMKitKey-NoSecondKeyWithSameName@@Tests/ACPConnection.wlt:351,1-359,2"
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
    TestID   -> "LLMKitKey-Failures@@Tests/ACPConnection.wlt:361,1-374,2"
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
    TestID   -> "LLMKitAPIKey-CreationAttemptedOnce@@Tests/ACPConnection.wlt:376,1-398,2"
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
    TestID   -> "LLMKitAPIKey-Cached@@Tests/ACPConnection.wlt:400,1-427,2"
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
    TestID   -> "PreferredModel@@Tests/ACPConnection.wlt:432,1-468,2"
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
    TestID   -> "BillingLabel@@Tests/ACPConnection.wlt:470,1-495,2"
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
    TestID   -> "FindConfigOption@@Tests/ACPConnection.wlt:497,1-507,2"
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
    TestID   -> "FindProgram-Setup@@Tests/ACPConnection.wlt:512,1-528,2"
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
    TestID   -> "FindProgram-Found@@Tests/ACPConnection.wlt:530,1-545,2"
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
    TestID   -> "FindProgram-NotFound@@Tests/ACPConnection.wlt:547,1-558,2"
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
    TestID   -> "FindProgram-Windows@@Tests/ACPConnection.wlt:560,1-573,2"
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
    TestID   -> "AgentSpec-CommandLine@@Tests/ACPConnection.wlt:576,1-613,2"
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
    TestID   -> "AgentSpec@@Tests/ACPConnection.wlt:615,1-662,2"
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
    TestID   -> "CommandLineSetting@@Tests/ACPConnection.wlt:664,1-689,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Persisted Settings*)
VerificationTest[
    {
        acpPersistedSetting[ { "LastModel", "TestAgent" } ],
        acpSetPersistedSetting[ { "LastModel", "TestAgent" }, "m2" ],
        acpPersistedSetting[ { "LastModel", "TestAgent" } ],
        acpPersistedSetting[ { "LastEffort", "TestAgent" }, None ],
        acpSetPersistedSetting[ { "LastModel", "TestAgent" }, Inherited ],
        acpPersistedSetting[ { "LastModel", "TestAgent" }, "default" ]
    },
    { Missing[ "NotSet" ], "m2", "m2", None, Inherited, "default" },
    SameTest -> MatchQ,
    TestID   -> "PersistedSettings-Headless@@Tests/ACPConnection.wlt:694,1-706,2"
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
    TestID   -> "ErrorInfo-ModelUnavailable@@Tests/ACPConnection.wlt:711,1-722,2"
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
    TestID   -> "ErrorInfo-Table@@Tests/ACPConnection.wlt:724,1-746,2"
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
    TestID   -> "ErrorInfo-Failures@@Tests/ACPConnection.wlt:748,1-763,2"
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
    TestID   -> "ErrorInfo-ProviderErrorsAreNotModelErrors@@Tests/ACPConnection.wlt:765,1-791,2"
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
    TestID   -> "MessageData@@Tests/ACPConnection.wlt:793,1-807,2"
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
    TestID   -> "ConnectionUtilities@@Tests/ACPConnection.wlt:809,1-821,2"
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
    TestID   -> "CurrentModel-NoConfigOptions@@Tests/ACPConnection.wlt:823,1-833,2"
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
    TestID   -> "Connect-NoDirectory@@Tests/ACPConnection.wlt:838,1-846,2"
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
    TestID   -> "Connect-AgentNotFound@@Tests/ACPConnection.wlt:848,1-862,2"
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
    TestID   -> "Connect-UnknownAgent@@Tests/ACPConnection.wlt:864,1-874,2"
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
    TestID   -> "Connect-Ready@@Tests/ACPConnection.wlt:879,1-887,2"
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
    TestID   -> "Connect-WindowRecord@@Tests/ACPConnection.wlt:889,1-906,2"
]

VerificationTest[
    ifConnTests[ {
        currentOption[ $w1, "model" ],
        acpConnectionQ @ acpWindowGet[ $w1, "Connection" ],
        ! connectionClosedQ @ acpWindowGet[ $w1, "Connection" ] (* the helper is not vacuous *)
    } ],
    Missing[ "TestSkipped" ] | { "m2", True, True },
    SameTest -> MatchQ,
    TestID   -> "Connect-PreferredModelApplied@@Tests/ACPConnection.wlt:908,1-917,2"
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
    TestID   -> "Connect-Idempotent@@Tests/ACPConnection.wlt:919,1-931,2"
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
        KeyValuePattern @ { "cwd" -> ExpandFileName @ $project1, "mcpServers" -> { } },
        { KeyValuePattern @ { "configId" -> "model", "sessionId" -> "sess-1", "value" -> "m2" } }
    },
    SameTest -> MatchQ,
    TestID   -> "Connect-WireLog@@Tests/ACPConnection.wlt:933,1-959,2"
]

VerificationTest[
    ifConnTests @ AllTrue[ Values @ Wolfram`Chatbook`ACP`State`Private`$housekeeping, KeyExistsQ[ #, "Function" ] & ] &&
        SubsetQ[ Keys @ Wolfram`Chatbook`ACP`State`Private`$housekeeping, { "ACPConnection", "ACPConnectionSweep" } ],
    Missing[ "TestSkipped" ] | True,
    SameTest -> MatchQ,
    TestID   -> "Connect-HousekeepingRegistered@@Tests/ACPConnection.wlt:961,1-967,2"
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
    TestID   -> "Prompt-StreamingAndPermissionRequest@@Tests/ACPConnection.wlt:972,1-992,2"
]

VerificationTest[
    ifConnTests[
        Pause[ 0.5 ]; (* answered later, while the agent waits *)
        { acpAnswerPermission[ $w1, $perm1, "once" ], waitFinal @ $t1 }
    ],
    Missing[ "TestSkipped" ] | { True, True },
    SameTest -> MatchQ,
    TestID   -> "Prompt-AnswerPermissionLater@@Tests/ACPConnection.wlt:994,1-1002,2"
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
    TestID   -> "Prompt-FinalTurn@@Tests/ACPConnection.wlt:1004,1-1021,2"
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
    TestID   -> "Prompt-WindowAfterTurn@@Tests/ACPConnection.wlt:1023,1-1038,2"
]

VerificationTest[
    ifConnTests @ acpAnswerPermission[ $w1, 999, "once" ],
    Missing[ "TestSkipped" ] | Missing[ "NotPending", 999 ],
    SameTest -> MatchQ,
    TestID   -> "Prompt-AnswerUnknownPermission@@Tests/ACPConnection.wlt:1040,1-1045,2"
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
    TestID   -> "Prompt-CancelRequest@@Tests/ACPConnection.wlt:1047,1-1068,2"
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
    TestID   -> "Prompt-StopWithPendingPermission@@Tests/ACPConnection.wlt:1070,1-1100,2"
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
    TestID   -> "Prompt-BackgroundPermissionCancelled@@Tests/ACPConnection.wlt:1102,1-1121,2"
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
    TestID   -> "Prompt-PermissionAfterStop@@Tests/ACPConnection.wlt:1123,1-1148,2"
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
    TestID   -> "Prompt-ModelUnavailable@@Tests/ACPConnection.wlt:1150,1-1164,2"
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
    TestID   -> "Prompt-MCPReadyDetection@@Tests/ACPConnection.wlt:1166,1-1176,2"
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
    TestID   -> "Handlers-Isolated@@Tests/ACPConnection.wlt:1178,1-1192,2"
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
    TestID   -> "ConfigOption-Mode@@Tests/ACPConnection.wlt:1197,1-1207,2"
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
    TestID   -> "ConfigOption-Error@@Tests/ACPConnection.wlt:1209,1-1221,2"
]

VerificationTest[
    ifConnTests[
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
    TestID   -> "ConfigOption-ModelPersisted@@Tests/ACPConnection.wlt:1223,1-1236,2"
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
    TestID   -> "Session-New@@Tests/ACPConnection.wlt:1241,1-1258,2"
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
    TestID   -> "Session-Disconnect@@Tests/ACPConnection.wlt:1260,1-1278,2"
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
    Missing[ "TestSkipped" ] | { True, 2, { KeyValuePattern @ { "sessionId" -> "sess-2", "cwd" -> ExpandFileName @ $project1, "mcpServers" -> { } } }, { }, "sess-2", None, { }, "m1", "Resumed" },
    SameTest -> MatchQ,
    TestID   -> "Session-Resume@@Tests/ACPConnection.wlt:1283,1-1306,2"
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
    TestID   -> "Session-ResumeFallsBackToNew@@Tests/ACPConnection.wlt:1308,1-1327,2"
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
    TestID   -> "Session-DisconnectRunningTurn@@Tests/ACPConnection.wlt:1329,1-1349,2"
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
    TestID   -> "Session-StopTimeout@@Tests/ACPConnection.wlt:1351,1-1371,2"
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
    TestID   -> "AgentDeath-DuringTurn@@Tests/ACPConnection.wlt:1376,1-1396,2"
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
    TestID   -> "AgentDeath-DuringSetup@@Tests/ACPConnection.wlt:1398,1-1412,2"
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
    TestID   -> "SessionError-NoModels@@Tests/ACPConnection.wlt:1414,1-1434,2"
]

VerificationTest[
    ifConnTests[
        acpReconnect @ $w3;
        { waitUntil[ acpWindowGet[ $w3, "Status" ] === "Ready" ], acpWindowGet[ $w3, "Error" ] }
    ],
    Missing[ "TestSkipped" ] | { True, None },
    SameTest -> MatchQ,
    TestID   -> "Reconnect-ClearsError@@Tests/ACPConnection.wlt:1436,1-1444,2"
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
    TestID   -> "Reconnect-AfterCommandLineSet@@Tests/ACPConnection.wlt:1446,1-1470,2"
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
    TestID   -> "ProjectDirectory-Invalid@@Tests/ACPConnection.wlt:1475,1-1483,2"
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
        { KeyValuePattern @ { "cwd" -> ExpandFileName @ $project2, "mcpServers" -> { } } },
        { },
        ExpandFileName @ $project2
    },
    SameTest -> MatchQ,
    TestID   -> "ProjectDirectory-Change@@Tests/ACPConnection.wlt:1485,1-1506,2"
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
    TestID   -> "ProjectDirectory-RefusedWhileRunning@@Tests/ACPConnection.wlt:1508,1-1519,2"
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
    TestID   -> "WindowUpdates-ConfigAndMode@@Tests/ACPConnection.wlt:1524,1-1561,2"
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
    TestID   -> "Session-NewWhileDisconnected@@Tests/ACPConnection.wlt:1563,1-1578,2"
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
    TestID   -> "Housekeeping-StuckConnect@@Tests/ACPConnection.wlt:1583,1-1593,2"
]

VerificationTest[
    ifConnTests[
        acpWindowUpdate[ $w4, <| #, "MCPReady" -> False, "SessionStartedAt" -> AbsoluteTime[ ] - 100 |> & ];
        waitUntil[ acpWindowGet[ $w4, "MCPReady" ] === True ]
    ],
    Missing[ "TestSkipped" ] | True,
    SameTest -> MatchQ,
    TestID   -> "Housekeeping-MCPReadyTimeout@@Tests/ACPConnection.wlt:1595,1-1603,2"
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
    TestID   -> "Housekeeping-SetupTimeout@@Tests/ACPConnection.wlt:1605,1-1623,2"
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
    TestID   -> "Housekeeping-DeadConnection@@Tests/ACPConnection.wlt:1625,1-1640,2"
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
    TestID   -> "Cleanup-OrphanConnectionSweep@@Tests/ACPConnection.wlt:1645,1-1656,2"
]

VerificationTest[
    ifConnTests[
        Scan[ acpDisconnect[ #, "TestCleanup" ] &, $windows ];
        Scan[ acpWindowDrop, $windows ];
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
    TestID   -> "Cleanup-NoLeftoverProcessesOrTasks@@Tests/ACPConnection.wlt:1658,1-1681,2"
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
    TestID   -> "Cleanup-DebugLog@@Tests/ACPConnection.wlt:1684,1-1695,2"
]

VerificationTest[
    DownValues[ acpTurnDrop ] = $savedTurnDrop;
    KeyDropFrom[ $acpAgents, "MockACPAgent" ];
    Scan[ acpWindowDrop, $windows ];
    $acpAssumeWindowsOpen = False;
    $acpLLMKitEnabled = True;
    Quiet @ DeleteDirectory[ $scratch, DeleteContents -> True ];
    (* Persisted choices and the environment as they were before the tests (Inherited removes a setting): *)
    KeyValueMap[ acpSetPersistedSetting[ #1, Replace[ #2, _Missing -> Inherited ] ] &, $savedPersisted ];
    If[ TrueQ @ $setACPLinkEnv, SetEnvironment[ "ACPLINK_DIRECTORY" -> None ] ];
    {
        KeyExistsQ[ $acpAgents, "MockACPAgent" ],
        DirectoryQ @ $scratch,
        AssociationMap[ acpPersistedSetting, Keys @ $savedPersisted ] === $savedPersisted,
        ! TrueQ @ $setACPLinkEnv || Environment[ "ACPLINK_DIRECTORY" ] === $Failed
    },
    { False, False, True, True },
    SameTest -> MatchQ,
    TestID   -> "Cleanup-Restore@@Tests/ACPConnection.wlt:1697,1-1716,2"
]

(* :!CodeAnalysis::EndBlock:: *)
