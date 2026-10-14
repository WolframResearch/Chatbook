(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ACPSessions.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ACPSessions.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* Tests for ACP/Sessions.wl and its integration in Connection.wl, UI.wl, Transcript.wl and Rendering.wl (see
   docs/acp-window.md, "Sessions"): the sessions store and listing, grouping and hiding, restoring a session (replay
   accumulator, turns, written cells, same folder / other folder / failures), new session in a folder, delete, timeouts,
   the "Restoring" state, kernel restart and window close hooks, the Sessions window (notebook, cell, views, actions,
   placement, relative times), strings.
   The pure tests always run. The connection tests drive the Connection layer headlessly (no front end; fake
   NotebookObjects) against the mock agent in Data/ACP/MockAgent (a copy of ACPLink's) with scenarios written at run
   time (they need the test's project folders); they are skipped (Missing["TestSkipped"]) if ACPLink or python3 is
   missing. Cells of restored sessions are captured instead of written (there is no front end). *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    Needs[ "Wolfram`Chatbook`ACP`Common`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPSessions-LoadACPContext@@Tests/ACPSessions.wlt:35,1-40,2"
]

VerificationTest[
    (* CI runs every test file in one kernel and one context: helpers that other test files define too are cleared
       first, so that none of their definitions is used here *)
    ClearAll[ boxStrings, connectionClosedQ, containsTextQ, currentOption, lastLog, mockIn, mockRecords,
        mockRequestsIn, newMockLog, newWindow ];

    $acpLLMKitEnabled     = False;
    $acpAssumeWindowsOpen = True;
    Wolfram`Chatbook`ACP`Transcript`Private`$acpNoFrontEndLabels    = True;
    Wolfram`Chatbook`ACP`Rendering`Private`$acpNoFrontEndFormatting = True;

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
    $savedPersisted = AssociationMap[
        acpPersistedSetting,
        { { "LastProjectDirectory" }, { "LastModel", "MockACPAgent" }, { "LastEffort", "MockACPAgent" } }
    ];
    $acpLogStart   = AbsoluteTime[ ];
    $acpConnTestsQ = TrueQ[ StringQ @ $python && FileExistsQ @ $mockScript && acpLinkAvailableQ[ ] && acpLoadACPLink[ ] === True ];

    $scratch     = CreateDirectory[ ];
    $scenarioDir = CreateDirectory @ FileNameJoin @ { $scratch, "scenarios" };
    $project1    = ExpandFileName @ CreateDirectory @ FileNameJoin @ { $scratch, "project1" };
    $project2    = ExpandFileName @ CreateDirectory @ FileNameJoin @ { $scratch, "project2" };
    $project3    = ExpandFileName @ FileNameJoin @ { $scratch, "gone" }; (* never created: a session whose folder was deleted *)

    ifConnTests // ClearAll;
    ifConnTests // Attributes = { HoldFirst };
    ifConnTests[ eval_ ] := If[ TrueQ @ $acpConnTestsQ, eval, Missing[ "TestSkipped" ] ];

    waitUntil // ClearAll;
    waitUntil // Attributes = { HoldFirst };
    waitUntil[ cond_, timeout_: 15 ] := Module[ { deadline = AbsoluteTime[ ] + timeout },
        While[ ! TrueQ @ cond && AbsoluteTime[ ] < deadline, Pause[ 0.05 ] ];
        TrueQ @ cond
    ];

    (* The mock agent; every connection gets its own wire log; scenarios are read from $scenarioDir first *)
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
            { $mockScript, "--log", newMockLog[ ], "--scenario-dir", $scenarioDir, "--idle-timeout", "120", "--max-lifetime", "600" },
            If[ StringQ @ $mockProcessScenario, { "--scenario", $mockProcessScenario }, { } ]
        ],
        "Environment" -> Inherited
    |>;
    writeScenario[ name_String, scenario_Association ] := Export[ FileNameJoin @ { $scenarioDir, name <> ".json" }, scenario, "RawJSON" ];

    (* One read of the file's current contents (ReadList on a file that the mock is still appending to can return the
       same line over and over, until the kernel runs out of memory); an unterminated last line is left for later *)
    mockRecords[ file_String ] := Module[ { bytes = Quiet @ ReadByteArray @ file, text, lines },
        text  = If[ ByteArrayQ @ bytes, ByteArrayToString[ bytes, "UTF-8" ], "" ];
        lines = StringSplit[ text, "\n" ];
        If[ lines =!= { } && ! StringEndsQ[ text, "\n" ], lines = Most @ lines ];
        Select[ Quiet[ Developer`ReadRawJSONString /@ lines ], AssociationQ ]
    ];
    mockIn[ file_String ] := Cases[ mockRecords @ file, KeyValuePattern @ { "dir" -> "in", "msg" -> m_Association } :> m ];
    mockRequestsIn[ file_String, method_String ] := Select[ mockIn @ file, Lookup[ #, "method", None ] === method && KeyExistsQ[ #, "id" ] & ];
    lastLog[ ] := Last[ $mockLogs, None ];
    (* Listings started (first pages: no cursor) *)
    listingsIn[ file_String ] := Count[ mockRequestsIn[ file, "session/list" ], KeyValuePattern[ "params" -> p_ /; ! KeyExistsQ[ p, "cursor" ] ] ];
    connectionClosedQ[ conn_ ] := ! MemberQ[ Replace[ Quiet @ acpLink[ "ACPConnections" ][ ], Except[ _List ] -> { } ], conn ];

    $windows = { };
    newWindow[ dir_, settings_Association: <| |> ] := With[
        { nbo = NotebookObject[ "acp-sessions-test-" <> ToString[ Length @ $windows + 1 ] ] },
        AppendTo[ $windows, nbo ];
        acpWindowUpdate[ nbo, Join[ #, Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, dir, "MockACPAgent", settings ] ] & ];
        nbo
    ];
    connectWindow[ nbo_ ] := (acpEnsureConnected @ nbo; waitUntil[ acpWindowGet[ nbo, "Status" ] === "Ready" ]);
    store[ nbo_ ] := acpSessionsOf @ nbo;
    restoredQ[ nbo_ ] := acpWindowGet[ nbo, "Status" ] === "Ready" && acpWindowGet[ nbo, "Restore" ] === None && acpWindowGet[ nbo, "PendingRestore" ] === None;
    currentOption[ nbo_, category_ ] := Lookup[ acpFindConfigOption[ acpWindowGet[ nbo, "ConfigOptions", { } ], category ], "currentValue", None ];

    (* Cells of restored sessions are captured (headless: there is no front end to write them to) *)
    $restoreWrites = <| |>;
    $restoreClears = <| |>;
    $savedWriteCells = DownValues @ Wolfram`Chatbook`ACP`Sessions`Private`restoreWriteCells;
    $savedClearCells = DownValues @ Wolfram`Chatbook`ACP`Sessions`Private`restoreClearCells;
    DownValues[ Wolfram`Chatbook`ACP`Sessions`Private`restoreWriteCells ] = Prepend[
        $savedWriteCells,
        HoldPattern[ Wolfram`Chatbook`ACP`Sessions`Private`restoreWriteCells[ nbo_NotebookObject, cells_List, _ ] ] :>
            ($restoreWrites[ nbo ] = Join[ Lookup[ $restoreWrites, nbo, { } ], cells ]; Null)
    ];
    DownValues[ Wolfram`Chatbook`ACP`Sessions`Private`restoreClearCells ] = Prepend[
        $savedClearCells,
        HoldPattern[ Wolfram`Chatbook`ACP`Sessions`Private`restoreClearCells[ nbo_NotebookObject, _ ] ] :>
            ($restoreWrites[ nbo ] = { }; $restoreClears[ nbo ] = Lookup[ $restoreClears, nbo, 0 ] + 1; { })
    ];
    (* Notebook flags written by the test windows (TaggingRules {"ACP", key}) *)
    $feSets = { };
    $savedFESet = DownValues @ acpFESet;
    DownValues[ acpFESet ] = Prepend[
        $savedFESet,
        HoldPattern[ acpFESet[ nbo_NotebookObject, key_String, value_ ] ] :>
            ((AppendTo[ $feSets, { nbo, key, value } ]; value) /; StringStartsQ[ First @ nbo, "acp-sessions-test-" ])
    ];

    (* Strings in boxes or cells *)
    boxStrings[ expr_ ] := Cases[ expr, s_String :> StringTrim[ s, "\"" ], Infinity ];
    containsTextQ[ expr_, text_String ] := AnyTrue[ boxStrings @ expr, StringContainsQ[ #, text ] & ];

    (* Updates as OpenCode replays them *)
    userChunk[ mid_String, text_String ] := <| "sessionUpdate" -> "user_message_chunk", "messageId" -> mid, "content" -> <| "type" -> "text", "text" -> text |> |>;
    agentChunk[ mid_String, text_String ] := <| "sessionUpdate" -> "agent_message_chunk", "messageId" -> mid, "content" -> <| "type" -> "text", "text" -> text |> |>;
    thoughtChunk[ mid_String, text_String ] := <| "sessionUpdate" -> "agent_thought_chunk", "messageId" -> mid, "content" -> <| "type" -> "text", "text" -> text |> |>;
    toolCall[ id_String, title_String, kind_String ] := <| "sessionUpdate" -> "tool_call", "toolCallId" -> id, "title" -> title, "kind" -> kind, "status" -> "pending", "rawInput" -> <| "x" -> 1 |> |>;
    toolDone[ id_String, text_String ] := <| "sessionUpdate" -> "tool_call_update", "toolCallId" -> id, "status" -> "completed", "content" -> { <| "type" -> "content", "content" -> <| "type" -> "text", "text" -> text |> |> } |>;
    toolDeclined[ id_String ] := <|
        "sessionUpdate" -> "tool_call_update", "toolCallId" -> id, "status" -> "failed",
        "content"       -> { <| "type" -> "content", "content" -> <| "type" -> "text", "text" -> "The user declined this tool call" |> |> },
        "rawOutput"     -> <| "error" -> "The user declined this tool call" |>
    |>;

    (* A four-turn history: a tool and an answer; a thought, an answer and an attached file; a cancelled turn (no
       output); a declined tool and an answer *)
    $historyA = {
        userChunk[ "msg_u1", "First question" ],
        toolCall[ "call_1", "read", "read" ],
        toolDone[ "call_1", "contents" ],
        agentChunk[ "msg_a1", "First answer" ],
        userChunk[ "msg_u2", "Second question" ],
        <| "sessionUpdate" -> "user_message_chunk", "messageId" -> "msg_u2", "content" -> <| "type" -> "resource_link", "name" -> "notes.md", "uri" -> "file:///x/notes.md" |> |>,
        thoughtChunk[ "msg_a2:reasoning:0", "Thinking about it" ],
        agentChunk[ "msg_a2", "Second answer" ],
        userChunk[ "msg_u3", "Cancelled question" ],
        userChunk[ "msg_u4", "Fourth question" ],
        toolCall[ "call_2", "rm -rf build", "execute" ],
        toolDeclined[ "call_2" ],
        agentChunk[ "msg_a4", "OK, I won't." ]
    };

    $mockConfigOptions = {
        <| "id" -> "model", "name" -> "Model", "category" -> "model", "type" -> "select", "currentValue" -> "m1",
           "options" -> { <| "value" -> "m1", "name" -> "Model One" |>, <| "value" -> "m2", "name" -> "Model Two" |> } |>,
        <| "id" -> "effort", "name" -> "Effort", "category" -> "thought_level", "type" -> "select", "currentValue" -> "default",
           "options" -> { <| "value" -> "default", "name" -> "Default" |>, <| "value" -> "high", "name" -> "High" |> } |>,
        <| "id" -> "mode", "name" -> "Session Mode", "category" -> "mode", "type" -> "select", "currentValue" -> "build",
           "options" -> { <| "value" -> "build", "name" -> "Build" |>, <| "value" -> "plan", "name" -> "Plan" |> } |>
    };

    (* OpenCode-like: pages of 2 with a cursor on the last page, strict sessions, the fallback title for new sessions *)
    writeScenario[ "cb-sessions", <|
        "description" -> "Chatbook ACPSessions.wlt: listed sessions in three folders (one deleted), histories, OpenCode-like paging",
        "agent" -> <|
            "listPageSize"         -> 2,
            "listCursorOnLastPage" -> True,
            "strictSessions"       -> True,
            "sessionTitle"         -> "New session - ${createdAt}",
            "sessions" -> {
                <| "sessionId" -> "ses_a1"   , "cwd" -> $project1, "title" -> "Add stdev"                               , "updatedAt" -> "2026-10-10T10:00:00.000Z" |>,
                <| "sessionId" -> "ses_a2"   , "cwd" -> $project1, "title" -> "New session - 2026-10-09T09:00:00.000Z"  , "updatedAt" -> "2026-10-09T09:00:00.100Z" |>,
                <| "sessionId" -> "ses_child", "cwd" -> $project1, "title" -> "Child session - 2026-10-10T10:00:01.000Z", "updatedAt" -> "2026-10-10T10:00:01.000Z" |>,
                <| "sessionId" -> "ses_b1"   , "cwd" -> $project2, "title" -> "Refactor calc"                           , "updatedAt" -> "2026-10-10T12:00:00.000Z" |>,
                <| "sessionId" -> "ses_c1"   , "cwd" -> $project3, "title" -> "Old project"                             , "updatedAt" -> "2026-09-01T00:00:00.000Z" |>
            },
            "histories" -> <|
                "ses_a1" -> $historyA,
                "ses_b1" -> { userChunk[ "msg_b1", "Question in project 2" ], agentChunk[ "msg_b2", "Answer in project 2" ] }
            |>
        |>
    |> ];
    ,
    _,
    SameTest -> MatchQ,
    TestID   -> "ACPSessions-Definitions@@Tests/ACPSessions.wlt:42,1-226,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Strings*)
VerificationTest[
    Select[ $acpSessionsStrings, ! StringQ @ # || StringLength @ # === 0 & ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "SessionsStrings@@Tests/ACPSessions.wlt:231,1-236,2"
]

(* Every acpLabel key used in Sessions.wl has an English default (in any of the tables) *)
VerificationTest[
    Complement[
        Union @ StringCases[
            ReadString @ FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "Source", "Chatbook", "ACP", "Sessions.wl" },
            "acpLabel[ \"" ~~ key: Except[ "\"" ].. ~~ "\"" :> key
        ],
        Keys @ Join[ $acpSessionsStrings, $acpStrings, $acpUIStrings, $acpConnectionStrings, $acpReviewStrings ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "SessionsStrings-Coverage@@Tests/ACPSessions.wlt:239,1-250,2"
]

(* The keys added for sessions are text resources in all seven .tr files, with the English text in ChatbookStrings.tr *)
VerificationTest[
    Module[ { files, keys, english },
        files = Prepend[
            FileNames[ "ChatbookStrings.tr", FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "FrontEnd", "TextResources" }, { 2 } ],
            FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "FrontEnd", "TextResources", "ChatbookStrings.tr" }
        ];
        keys = Join[
            $acpSessionsStrings,
            KeyTake[ $acpStrings, { "WorkedReplayed", "ThoughtReplayed", "ReplayNoReply", "ToolbarRestoring" } ],
            KeyTake[ $acpUIStrings, { "QueuedPromptRestoring", "MenusDisabledRestoring", "NoticeDirectoryWhileRestoring" } ],
            KeyTake[ $acpConnectionStrings, { "NoticeSessionLoadFailed", "NoticeSessionLoadUnsupported", "SessionsListFailed", "SessionsDeleteFailed" } ]
        ];
        english = Association @ ToExpression[
            First @ StringCases[ ReadString @ First @ files, "@@resource ChatbookStrings" ~~ Shortest[ b___ ] ~~ "\n}\n" :> b <> "\n}", 1 ],
            InputForm
        ];
        {
            Length @ files,
            Length @ keys,
            AllTrue[ files, Function[ f, With[ { text = ReadString @ f }, AllTrue[ Keys @ keys, StringContainsQ[ text, "\"ACP" <> # <> "\" ->" ] & ] ] ] ],
            Select[ Keys @ keys, english[ "ACP" <> # ] =!= keys[ # ] & ]
        }
    ],
    { 7, 49, True, { } },
    SameTest -> MatchQ,
    TestID   -> "SessionsStrings-TextResources@@Tests/ACPSessions.wlt:253,1-279,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Pure Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Session Items*)
VerificationTest[
    {
        acpSessionTime[ "2026-10-11T05:05:38.554Z" ] == AbsoluteTime @ DateObject[ { 2026, 10, 11, 5, 5, 38.554 }, TimeZone -> 0 ],
        acpSessionTime[ "2026-10-11T05:05:38Z" ] == AbsoluteTime @ DateObject[ { 2026, 10, 11, 5, 5, 38 }, TimeZone -> 0 ],
        acpSessionTime[ "2026-10-11T07:05:38+02:00" ] == AbsoluteTime @ DateObject[ { 2026, 10, 11, 5, 5, 38 }, TimeZone -> 0 ],
        acpSessionTime[ 1791580747226 ] == AbsoluteTime @ FromUnixTime[ 1791580747.226 ],
        acpSessionTime[ "New session - 2026-10-11T05:05:38.554Z" ],
        acpSessionTime[ "garbage" ],
        acpSessionTime[ None ]
    },
    { True, True, True, True, None, None, None },
    SameTest -> MatchQ,
    TestID   -> "SessionTime@@Tests/ACPSessions.wlt:288,1-301,2"
]

VerificationTest[
    acpSessionHiddenTitleQ /@ {
        "New session - 2026-10-11T14:16:15.380Z",
        "Child session - 2026-10-11T14:16:15.380Z",
        "Child session - anything",
        "New session - ideas for the parser",
        "Add stdev to stats.py",
        None
    },
    { True, True, True, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "SessionHiddenTitle@@Tests/ACPSessions.wlt:303,1-315,2"
]

(* The fallback title (shown for the window's own session before its first prompt) is shown without its time *)
VerificationTest[
    Wolfram`Chatbook`ACP`Sessions`Private`sessionsTitle /@ {
        <| "Title" -> "New session - 2026-10-11T20:31:14.931Z" |>,
        <| "Title" -> "New session - ideas for the parser" |>,
        <| "Title" -> "Add stdev to stats.py" |>,
        <| "Title" -> "  " |>,
        <| "Title" -> None |>
    },
    { "New session", "New session - ideas for the parser", "Add stdev to stats.py", "Untitled session", "Untitled session" },
    SameTest -> MatchQ,
    TestID   -> "SessionsTitle-FallbackTitle@@Tests/ACPSessions.wlt:318,1-329,2"
]

(* The fallback title alone does not hide a session that was updated long after its creation (it was used, but OpenCode
   could not make a title); the window's own setup changes a new session within a fraction of a second *)
VerificationTest[
    Lookup[
        acpSessionItems @ {
            <| "sessionId" -> "used", "cwd" -> "/p", "title" -> "New session - 2026-10-09T09:00:00.000Z", "updatedAt" -> "2026-10-09T12:00:00.000Z" |>,
            <| "sessionId" -> "setup", "cwd" -> "/p", "title" -> "New session - 2026-10-09T08:00:00.000Z", "updatedAt" -> "2026-10-09T08:00:00.170Z" |>,
            <| "sessionId" -> "slow", "cwd" -> "/p", "title" -> "New session - 2026-10-09T07:00:00.000Z", "updatedAt" -> "2026-10-09T07:00:09.000Z" |>,
            <| "sessionId" -> "notime", "cwd" -> "/p", "title" -> "New session - 2026-10-09T06:00:00.000Z" |>,
            <| "sessionId" -> "child", "cwd" -> "/p", "title" -> "Child session - 2026-10-09T05:00:00.000Z", "updatedAt" -> "2026-10-09T09:00:00.000Z" |>
        },
        { "SessionID", "Hidden" }
    ],
    (* newest first *)
    { { "used", False }, { "child", True }, { "setup", True }, { "slow", True }, { "notime", True } },
    SameTest -> MatchQ,
    TestID   -> "SessionItems-UsedFallbackTitle@@Tests/ACPSessions.wlt:333,1-348,2"
]

VerificationTest[
    acpSessionItems @ {
        <| "sessionId" -> "s-old", "cwd" -> "/p", "title" -> "Old", "updatedAt" -> "2026-01-01T00:00:00Z" |>,
        <| "sessionId" -> "s-new", "cwd" -> "/p", "title" -> "New session - 2026-10-01T00:00:00.000Z", "updatedAt" -> "2026-10-01T00:00:00.000Z" |>,
        <| "sessionId" -> "s-notime", "cwd" -> "/q", "title" -> "  " |>,
        <| "sessionId" -> "s-mid", "cwd" -> "/q", "title" -> "Evil \:f7c1 title", "updatedAt" -> "2026-05-01T00:00:00Z" |>,
        <| "sessionId" -> "s-old", "cwd" -> "/p", "title" -> "Duplicate", "updatedAt" -> "2026-12-01T00:00:00Z" |>,
        <| "cwd" -> "/p", "title" -> "No id" |>,
        <| "sessionId" -> "s-nocwd", "title" -> "No cwd" |>,
        "not a row"
    },
    {
        KeyValuePattern @ { "SessionID" -> "s-new", "Cwd" -> "/p", "Hidden" -> True, "UpdatedAt" -> _? NumberQ },
        KeyValuePattern @ { "SessionID" -> "s-mid", "Title" -> "Evil \:fffd title", "Hidden" -> False },
        KeyValuePattern @ { "SessionID" -> "s-old", "Title" -> "Old", "Hidden" -> False },
        <| "SessionID" -> "s-notime", "Cwd" -> "/q", "Title" -> None, "UpdatedAt" -> None, "Hidden" -> False |>
    },
    SameTest -> MatchQ,
    TestID   -> "SessionItems@@Tests/ACPSessions.wlt:350,1-369,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Projects*)
VerificationTest[
    Module[ { items, projects },
        items = acpSessionItems @ {
            <| "sessionId" -> "cur-new", "cwd" -> "/home/u/p1", "title" -> "New session - 2026-10-11T00:00:00.000Z", "updatedAt" -> "2026-10-11T00:00:00Z" |>,
            <| "sessionId" -> "b1", "cwd" -> "/home/u/p2/", "title" -> "B1", "updatedAt" -> "2026-10-10T00:00:00Z" |>,
            <| "sessionId" -> "a1", "cwd" -> "/home/u/p1", "title" -> "A1", "updatedAt" -> "2026-10-09T00:00:00Z" |>,
            <| "sessionId" -> "b2", "cwd" -> "/home/u/p2", "title" -> "B2", "updatedAt" -> "2026-10-08T00:00:00Z" |>,
            <| "sessionId" -> "hidden", "cwd" -> "/home/u/p3", "title" -> "Child session - x", "updatedAt" -> "2026-10-12T00:00:00Z" |>,
            <| "sessionId" -> "a0", "cwd" -> "/home/u/p1", "title" -> "New session - 2026-01-01T00:00:00.000Z", "updatedAt" -> "2026-01-01T00:00:00Z" |>
        };
        projects = acpSessionsProjects[ items, { "cur-new" }, "/home/u/p1/" ];
        {
            Lookup[ projects, "Key" ],
            Lookup[ projects, "Name" ],
            Lookup[ projects, "Current" ],
            Lookup[ projects, "Count" ],
            Map[ { #[ "SessionID" ], #[ "Current" ] } &, Lookup[ projects, "Sessions" ], { 2 } ],
            (* a project without visible sessions: only the window's own one appears (first) *)
            Lookup[ acpSessionsProjects[ items, { }, "/home/u/p9" ], { "Key", "Count" }, None ][[ 1 ]],
            acpSessionsProjects[ { }, { }, None ]
        }
    ],
    {
        { "/home/u/p1", "/home/u/p2" },
        { "p1", "p2" },
        { True, False },
        { 2, 2 },
        { { { "cur-new", True }, { "a1", False } }, { { "b1", False }, { "b2", False } } },
        { "/home/u/p9", 0 },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "SessionsProjects@@Tests/ACPSessions.wlt:374,1-407,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Replay*)
VerificationTest[
    {
        acpReplayRanges @ $historyA,
        acpReplayRanges @ { agentChunk[ "m0", "after compaction" ], userChunk[ "u1", "q" ], agentChunk[ "a1", "a" ] },
        (* chunks of one user message without IDs stay one turn; after agent output they start one *)
        acpReplayRanges @ {
            <| "sessionUpdate" -> "user_message_chunk", "content" -> <| "type" -> "text", "text" -> "a" |> |>,
            <| "sessionUpdate" -> "user_message_chunk", "content" -> <| "type" -> "text", "text" -> "b" |> |>,
            agentChunk[ "a1", "x" ],
            <| "sessionUpdate" -> "user_message_chunk", "content" -> <| "type" -> "text", "text" -> "c" |> |>
        },
        acpReplayRanges @ { }
    },
    {
        { { 1, 4 }, { 5, 8 }, { 9, 9 }, { 10, 13 } },
        { { 1, 1 }, { 2, 3 } },
        { { 1, 3 }, { 4, 4 } },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "ReplayRanges@@Tests/ACPSessions.wlt:412,1-433,2"
]

VerificationTest[
    Module[ { r },
        r = Fold[ acpReplayAppend[ #1, #2, 1000.0 ] &, acpNewRestore @ <| "Token" -> "t" |>, $historyA ];
        {
            r[ "Count" ], r[ "Kept" ], r[ "Dropped" ], r[ "Turns" ],
            acpReplayUpdates @ r === $historyA,
            r[ "Bytes" ] === Total[ ByteCount /@ $historyA ],
            r[ "LastUpdateAt" ]
        }
    ],
    { 13, 13, 0, 4, True, True, 1000.0 },
    SameTest -> MatchQ,
    TestID   -> "ReplayAppend@@Tests/ACPSessions.wlt:435,1-448,2"
]

(* Past the caps the oldest chunks are dropped; the job drops the partial turn at the start and counts the turns that are
   not shown *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`ACP`Sessions`Private`$acpReplayMaxUpdates = 10,
            Wolfram`Chatbook`ACP`Sessions`Private`$acpReplayChunkSize  = 3
        },
        Module[ { updates, r, job },
            updates = Flatten @ Table[ { userChunk[ "u" <> ToString @ i, "q" <> ToString @ i ], agentChunk[ "a" <> ToString @ i, "a" <> ToString @ i ] }, { i, 8 } ];
            r = Fold[ acpReplayAppend[ #1, #2, 1.0 ] &, acpNewRestore @ <| "Token" -> "t" |>, updates ];
            job = Wolfram`Chatbook`ACP`Sessions`Private`restoreNewJob[ NotebookObject[ "fake" ], <| "Status" -> "Restoring" |>, r ];
            {
                r[ "Count" ], r[ "Kept" ] <= 10, r[ "Count" ] - r[ "Dropped" ] === r[ "Kept" ], r[ "Turns" ],
                Length @ acpReplayUpdates @ r === r[ "Kept" ],
                First[ job[ "Updates" ] ][ "sessionUpdate" ],
                Length @ job[ "Ranges" ] + job[ "Hidden" ]
            }
        ]
    ],
    { 16, True, True, 8, True, "user_message_chunk", 8 },
    SameTest -> MatchQ,
    TestID   -> "ReplayAppend-Caps@@Tests/ACPSessions.wlt:452,1-473,2"
]

VerificationTest[
    Module[ { ranges, turns },
        ranges = acpReplayRanges @ $historyA;
        turns  = MapIndexed[
            acpReplayTurn[ Take[ $historyA, #1 ], <| "ID" -> "replay-" <> ToString @ First @ #2, "SessionID" -> "ses_a1", "StartTime" -> 100.0 + First @ #2 |> ] &,
            ranges
        ];
        {
            Lookup[ turns, "Prompt" ],
            Lookup[ turns, "Replayed" ],
            Lookup[ turns, "StopReason" ],
            Length /@ Lookup[ turns, "Order" ],
            Lookup[ turns[[ 4 ]][ "Entities" ][ { "Tool", "call_2" } ], { "Status", "ClientOutcome" } ],
            Lookup[ turns[[ 1 ]][ "Entities" ][ { "Tool", "call_1" } ], { "Status", "ClientOutcome" } ],
            acpWorkedForLabel /@ turns,
            AllTrue[ turns, AssociationQ[ # ] && ! KeyExistsQ[ $acpTurns, #[ "ID" ] ] & ]
        }
    ],
    {
        { "First question", "Second question\n[notes.md]", "Cancelled question", "Fourth question" },
        { True, True, True, True },
        { "end_turn", "end_turn", "end_turn", "end_turn" },
        { 2, 2, 0, 2 },
        { "failed", "Declined" },
        { "completed", None },
        { "Worked", "Worked", "Worked", "Worked" },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ReplayTurn@@Tests/ACPSessions.wlt:475,1-505,2"
]

(* Final cells of replayed turns have no timing ("Worked", "Thoughts"), and a turn without output says "No reply." *)
VerificationTest[
    Module[ { ranges, cells },
        ranges = acpReplayRanges @ $historyA;
        cells  = MapIndexed[
            acpFinalCell @ acpReplayTurn[ Take[ $historyA, #1 ], <| "ID" -> "replay-cell-" <> ToString @ First @ #2, "StartTime" -> 100.0 + First @ #2 |> ] &,
            ranges
        ];
        Scan[ acpDropRenderCache[ "replay-cell-" <> ToString @ # ] &, Range @ 4 ];
        {
            containsTextQ[ cells[[ 1 ]], "Worked" ] && ! containsTextQ[ cells, "Worked for" ],
            containsTextQ[ cells[[ 2 ]], "Thoughts" ] && ! containsTextQ[ cells, "Thought for" ],
            containsTextQ[ cells[[ 2 ]], "Second answer" ],
            containsTextQ[ cells[[ 3 ]], "No reply." ],
            containsTextQ[ cells[[ 4 ]], "Declined" ] && containsTextQ[ cells[[ 4 ]], "OK, I won't." ],
            Lookup[ #[[ -1, 2, "ACPTurn" ]], "Replayed" ] & /@ cells
        }
    ],
    { True, True, True, True, True, { True, True, True, True } },
    SameTest -> MatchQ,
    TestID   -> "ReplayTurn-FinalCells@@Tests/ACPSessions.wlt:508,1-528,2"
]

(* Live turns keep their timing labels *)
VerificationTest[
    {
        acpWorkedForLabel[ <| acpNewTurn @ <| "StartTime" -> 0.0 |>, "EndTime" -> 5.0 |>, 10.0 ],
        Block[ { Wolfram`Chatbook`ACP`Rendering`Private`$replayedTurn = False },
            Wolfram`Chatbook`ACP`Rendering`Private`thoughtLabel @ <| "FirstTime" -> 0.0, "LastTime" -> 4.0 |>
        ]
    },
    { "Worked for 5s", "Thought for 4 seconds" },
    SameTest -> MatchQ,
    TestID   -> "ReplayLabels-LiveUnchanged@@Tests/ACPSessions.wlt:531,1-541,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Busy State*)
VerificationTest[
    Module[ { base = Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ NotebookObject[ "busy" ], "/p", "OpenCode", <| |> ] },
        base[ "Status" ] = "Ready";
        {
            acpSessionsBusyState @ base,
            acpSessionsBusyState @ <| base, "CurrentTurn" -> "t1" |>,
            acpSessionsBusyState @ <| base, "CurrentTurn" -> "t1", "PendingPermissions" -> <| "r1" -> <| |> |> |>,
            acpSessionsBusyState @ <| base, "ConnectToken" -> "tok" |>,
            acpSessionsBusyState @ <| base, "Status" -> "Connecting" |>,
            acpSessionsBusyState @ <| base, "Status" -> "Restoring", "Restore" -> <| "Stage" -> "Loading" |> |>,
            acpSessionsBusyState @ <| base, "Status" -> "Disconnected", "PendingRestore" -> <| "SessionID" -> "s", "Cwd" -> "/q" |> |>,
            acpSessionsBusyLabel @ <| base, "CurrentTurn" -> "t1" |>,
            acpSessionsBusyLabel @ <| base, "Status" -> "Restoring" |>,
            acpSessionsBusyLabel @ base
        }
    ],
    { None, "Running", "Permission", "Connecting", "Connecting", "Restoring", "Restoring", "Wait for the current turn to finish", "Restoring\[Ellipsis]", None },
    SameTest -> MatchQ,
    TestID   -> "BusyState@@Tests/ACPSessions.wlt:546,1-565,2"
]

(* Restore and new session are refused while the window is busy; the current session is a no-op *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-sessions-busy" ], base, results },
        base = <| Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, $project1, "OpenCode", <| |> ], "Status" -> "Ready", "SessionID" -> "cur" |>;
        results = Function[ w,
            Block[ { $acpWindows = <| nbo -> w |> }, { acpRestoreSession[ nbo, "other", $project1 ], acpNewSessionIn[ nbo, $project2 ] } ]
        ] /@ {
            <| base, "CurrentTurn" -> "t1" |>,
            <| base, "Status" -> "Restoring", "Restore" -> <| "Stage" -> "Writing", "Token" -> "x" |> |>,
            <| base, "ConnectToken" -> "tok" |>
        };
        {
            results,
            Block[ { $acpWindows = <| nbo -> base |> }, acpRestoreSession[ nbo, "cur", $project1 ] ],
            Block[ { $acpWindows = <| nbo -> <| base, "Capabilities" -> <| "loadSession" -> False |> |> |> }, acpRestoreSession[ nbo, "other", $project1 ] ],
            Block[ { $acpWindows = <| |> }, acpRestoreSession[ nbo, "other", $project1 ] ]
        }
    ],
    {
        {
            { Failure[ "Busy", <| "Reason" -> "Running" |> ], Failure[ "Busy", <| "Reason" -> "Running" |> ] },
            { Failure[ "Busy", <| "Reason" -> "Restoring" |> ], Failure[ "Busy", <| "Reason" -> "Restoring" |> ] },
            { Failure[ "Busy", <| "Reason" -> "Connecting" |> ], Failure[ "Busy", <| "Reason" -> "Connecting" |> ] }
        },
        "Current",
        Failure[ "Unsupported", _ ],
        Missing[ "NotFound" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Restore-Preconditions@@Tests/ACPSessions.wlt:568,1-597,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Restoring State in the Window*)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-sessions-restoring" ], window, button, menus, row, area, queued },
        window = <|
            Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, $project1, "OpenCode", <| |> ],
            "Status"        -> "Restoring",
            "Restore"       -> acpNewRestore @ <| "SessionID" -> "s", "Token" -> "t" |>,
            "ConfigOptions" -> $mockConfigOptions,
            "QueuedPrompt"  -> "hello"
        |>;
        (* no front end preferences (recent models), so nothing waits for a front end *)
        Block[ { $acpWindows = <| nbo -> window |>, acpEnsurePublisher = Null &, Wolfram`Chatbook`ACP`UI`Private`acpPreference = Missing[ "NotSet" ] & },
            button = Wolfram`Chatbook`ACP`UI`Private`acpNewChatButton[ nbo, window ];
            menus  = Wolfram`Chatbook`ACP`UI`Private`acpConfigMenusView[ nbo, window ];
            row    = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ nbo, window ];
            area   = Wolfram`Chatbook`ACP`UI`Private`acpInputAreaView[ nbo, window ];
            queued = Wolfram`Chatbook`ACP`UI`Private`acpInputAreaView[ nbo, <| window, "Status" -> "Ready", "Restore" -> None |> ]
        ];
        {
            (* level 1 only: the button's code must not be evaluated *)
            Cases[ button, HoldPattern[ (Enabled | BoxID) -> v_ ] :> v, { 1 } ],
            Union @ Cases[ menus, HoldPattern[ Enabled -> e_ ] :> e, Infinity ],
            containsTextQ[ menus, "Settings can't be changed while a session is loading" ],
            Union @ Cases[ row, HoldPattern[ Enabled -> e_ ] :> e, Infinity ],
            containsTextQ[ area, "Queued, sent when the session is loaded: hello" ],
            containsTextQ[ queued, "Queued, sent when the agent is done: hello" ],
            Wolfram`Chatbook`ACP`UI`Private`acpNewChatSignature @ window =!= Wolfram`Chatbook`ACP`UI`Private`acpNewChatSignature @ <| window, "Status" -> "Ready", "Restore" -> None |>,
            Cases[ Wolfram`Chatbook`ACP`UI`Private`acpNewChatButton[ nbo, <| window, "Status" -> "Ready", "Restore" -> None |> ], HoldPattern[ Enabled -> v_ ] :> v, { 1 } ]
        }
    ],
    { { "ACPNewChatButton", False }, { False }, True, { False }, True, True, True, { True } },
    SameTest -> MatchQ,
    TestID   -> "Restoring-Toolbar@@Tests/ACPSessions.wlt:602,1-634,2"
]

VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-sessions-restoring-status" ] },
        Block[ { $acpWindows = <| nbo -> <| Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, $project1, "OpenCode", <| |> ], "Status" -> "Restoring" |> |> },
            containsTextQ[ Wolfram`Chatbook`ACP`Rendering`Private`statusContent0 @ nbo, "Loading the session" ]
        ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Restoring-ToolbarStatus@@Tests/ACPSessions.wlt:636,1-645,2"
]

(* Send queues the prompt while a session is restored (its user cell must come after the restored transcript), and the
   queued prompt waits until the restore is done; New, the folder and config changes are ignored meanwhile *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-sessions-send" ], window, log = { }, result },
        window = <|
            Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, $project1, "OpenCode", <| |> ],
            "Status"  -> "Restoring",
            "Restore" -> acpNewRestore @ <| "SessionID" -> "s", "Token" -> "t" |>
        |>;
        Block[
            {
                $acpWindows            = <| nbo -> window |>,
                acpCheckSession        = True &,
                acpFE                  = Function[ { n, key, default }, If[ key === "Input", "hello", default ] ],
                acpFESet               = (AppendTo[ log, { "FESet", ##2 } ]; #3) &,
                acpSetProjectDirectory = (AppendTo[ log, { "SetProjectDirectory" } ]; Null) &,
                acpSetConfigOption     = (AppendTo[ log, { "SetConfigOption" } ]; Null) &,
                acpNewSession          = (AppendTo[ log, { "NewSession" } ]; Null) &,
                NotebookDelete         = (AppendTo[ log, { "NotebookDelete" } ]; Null) &
            },
            result = {
                evaluateACPChat @ nbo,
                acpWindowGet[ nbo, "QueuedPrompt" ],
                acpWindowGet[ nbo, "CurrentTurn" ],
                acpSendQueuedPrompt @ nbo,
                acpWindowGet[ nbo, "QueuedPrompt" ],
                acpNewChat @ nbo,
                Wolfram`Chatbook`ACP`UI`Private`acpSetProjectDirectoryAction[ nbo, $project2 ],
                acpWindowGet[ nbo, "Notice" ],
                Wolfram`Chatbook`ACP`UI`Private`acpSetConfigOptionAction[ nbo, "model", "m2" ]
            }
        ];
        { result, log }
    ],
    {
        { Null, "hello", None, Null, "hello", Null, Null, "The project folder can't be changed while a session is loading.", Null },
        { { "FESet", "Input", "" } }
    },
    SameTest -> MatchQ,
    TestID   -> "Restoring-SendQueues@@Tests/ACPSessions.wlt:649,1-687,2"
]

(* A config change (e.g. ShowNotebookAssistance with "ACPModel") waits while the restored session loads (it is applied to
   it once loaded); while its turns are written the restored session is the window's, and the change is sent at once *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-sessions-config" ], base, restore, sent = { }, run },
        restore = acpNewRestore @ <| "SessionID" -> "s-new", "Token" -> "t" |>;
        base    = <|
            Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, $project1, "OpenCode", <| |> ],
            "Status"     -> "Restoring",
            "Connection" -> Wolfram`ChatbookTests`Fake`ACPConnection[ "c-config" ],
            "SessionID"  -> "s-old"
        |>;
        run[ w_ ] := Block[
            {
                $acpWindows        = <| nbo -> w |>,
                acpEnsurePublisher = Null &,
                Wolfram`Chatbook`ACP`Connection`Private`writeRequest = Function[ { c, m, p, id }, AppendTo[ sent, p ]; Wolfram`ChatbookTests`Fake`ACPRequest[ <| "ID" -> id |> ] ]
            },
            { acpSetConfigOption[ nbo, "model", "m2" ], acpWindowGet[ nbo, "PendingConfig" ] }
        ];
        {
            run @ <| base, "Restore" -> restore |>,
            run @ <| base, "SessionID" -> "s-new", "Restore" -> <| restore, "Stage" -> "Writing" |> |>,
            (* the load response is being handled: the window's session is not the restored one yet *)
            run @ <| base, "Restore" -> <| restore, "Stage" -> "Writing" |> |>,
            sent
        }
    ],
    {
        { "Pending", <| "model" -> "m2" |> },
        { "Sent", <| "model" -> "m2" |> },
        { "Pending", <| "model" -> "m2" |> },
        { <| "sessionId" -> "s-new", "configId" -> "model", "value" -> "m2" |> }
    },
    SameTest -> MatchQ,
    TestID   -> "Restoring-ConfigWhileWriting@@Tests/ACPSessions.wlt:691,1-724,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Writing a Restored Session*)

(* The write job (with the scheduler stubbed out, so the steps run here): the first step clears the transcript; then the
   last 30 turns are written after a note about the earlier ones; then the window is ready *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-sessions-test-write" ], updates, restore, window, steps = 0, cells },
        updates = Flatten @ Table[ { userChunk[ "u" <> ToString @ i, "q" <> ToString @ i ], agentChunk[ "a" <> ToString @ i, "answer " <> ToString @ i ] }, { i, 35 } ];
        restore = <| Fold[ acpReplayAppend[ #1, #2, 1.0 ] &, acpNewRestore @ <| "SessionID" -> "s", "Token" -> "tw" |>, updates ], "Stage" -> "Writing" |>;
        window  = <| Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, $project1, "OpenCode", <| |> ], "Status" -> "Restoring", "Restore" -> restore |>;
        $restoreWrites[ nbo ] = { };
        (* without time for more, each step writes one turn *)
        Block[ { $acpWindows = <| nbo -> window |>, acpSchedule = Function[ Null, Null, HoldAll ], Wolfram`Chatbook`ACP`Sessions`Private`$acpRestoreStepTime = 0.0 },
            While[ AssociationQ @ acpWindowGet[ nbo, "Restore" ] && steps < 200, steps++; acpRestoreWriteStep[ nbo, "tw" ] ];
            cells = $restoreWrites[ nbo ];
            {
                steps,
                Lookup[ $restoreClears, nbo, 0 ],
                Length @ cells,
                First[ cells ][[ 1 ]],
                cells[[ 2 ]][[ 2 ]],
                containsTextQ[ cells[[ 2 ]], "q6" ],
                containsTextQ[ Last @ cells, "answer 35" ],
                Union[ #[[ 2 ]] & /@ Rest @ cells ],
                KeyTake[ acpWindowGet @ nbo, { "Status", "Restore" } ],
                KeyExistsQ[ Wolfram`Chatbook`ACP`Sessions`Private`$restoreJobs, nbo ]
            }
        ]
    ],
    {
        31,
        1,
        61,
        "5 earlier messages are not shown.",
        "ChatInput",
        True,
        True,
        { "ChatInput", "ChatOutput" },
        <| "Status" -> "Disconnected", "Restore" -> None |>,
        False
    },
    SameTest -> MatchQ,
    TestID   -> "RestoreWrite-Steps@@Tests/ACPSessions.wlt:732,1-770,2"
]

(* A newer restore (another token) or a window without the restore ends the job *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-sessions-test-write2" ], window },
        window = <|
            Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, $project1, "OpenCode", <| |> ],
            "Status"  -> "Restoring",
            "Restore" -> <| acpNewRestore @ <| "SessionID" -> "s", "Token" -> "new" |>, "Stage" -> "Writing" |>
        |>;
        $restoreWrites[ nbo ] = { };
        Block[ { $acpWindows = <| nbo -> window |>, acpSchedule = Function[ Null, Null, HoldAll ] },
            { acpRestoreWriteStep[ nbo, "old" ], Lookup[ $restoreClears, nbo, 0 ], acpWindowGet[ nbo, "Restore" ][ "Token" ] }
        ]
    ],
    { Null, 0, "new" },
    SameTest -> MatchQ,
    TestID   -> "RestoreWrite-Superseded@@Tests/ACPSessions.wlt:773,1-788,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Housekeeping Fallbacks*)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-sessions-hk" ], base, now = AbsoluteTime[ ], run },
        base = Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, $project1, "OpenCode", <| |> ];
        run[ w_ ] := Block[ { $acpWindows = <| nbo -> w |>, acpSchedule = Function[ Null, Null, HoldAll ] },
            Wolfram`Chatbook`ACP`Sessions`Private`restoreHousekeeping[ nbo, w, now ];
            KeyTake[ acpWindowGet @ nbo, { "Status", "Restore", "PendingRestore" } ]
        ];
        {
            (* "Restoring" without a restore *)
            run @ <| base, "Status" -> "Restoring" |>,
            (* a write job without progress *)
            run @ <| base, "Status" -> "Restoring", "Restore" -> <| acpNewRestore @ <| "Token" -> "t" |>, "Stage" -> "Writing", "StepAt" -> now - 100 |> |>,
            (* a pending restore of a connection that failed *)
            run @ <| base, "Status" -> "Error", "PendingRestore" -> <| "SessionID" -> "s", "Cwd" -> "/p" |> |>
        }
    ],
    {
        <| "Status" -> "Disconnected", "Restore" -> None, "PendingRestore" -> None |>,
        <| "Status" -> "Disconnected", "Restore" -> None, "PendingRestore" -> None |>,
        <| "Status" -> "Error", "Restore" -> None, "PendingRestore" -> None |>
    },
    SameTest -> MatchQ,
    TestID   -> "Housekeeping-RestoreFallbacks@@Tests/ACPSessions.wlt:793,1-816,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Window Hooks*)

(* After a kernel restart the toolbar and input are rebuilt and an open Sessions window is recovered (scheduled) *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-sessions-hooks" ], scheduled = { } },
        Block[
            {
                acpSchedule                                        = Function[ e, AppendTo[ scheduled, HoldForm @ e ], HoldFirst ],
                Cells                                              = { } &,
                NotebookDelete                                     = Null &,
                Wolfram`Chatbook`Common`attachWorkspaceChatInput   = Null &,
                Wolfram`Chatbook`ACP`UI`Private`acpRefreshToolbar  = Null &
            },
            Wolfram`Chatbook`ACP`UI`Private`acpRefreshWindowUI @ nbo;
            Wolfram`Chatbook`ACP`UI`Private`acpWindowClosed @ nbo
        ];
        With[ { n = nbo },
            {
                MemberQ[ scheduled, HoldForm @ acpSessionsRecover @ n ],
                ! FreeQ[ scheduled, HoldPattern @ acpSessionsCloseWindow @ n ]
            }
        ]
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "WindowHooks-Scheduled@@Tests/ACPSessions.wlt:823,1-846,2"
]

VerificationTest[
    Module[ { owner = NotebookObject[ "acp-sessions-owner" ], sessions = NotebookObject[ "acp-sessions-window" ], log = { }, window, recovered },
        window = <| Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ owner, $project1, "OpenCode", <| |> ], "Status" -> "Disconnected" |>;
        Block[
            {
                $acpWindows           = <| owner -> window |>,
                acpSessionsWindowOf   = If[ # === owner, sessions, None ] &,
                NotebookClose         = (AppendTo[ log, { "Close", # } ]; Null) &,
                acpSessionsCell       = Cell[ "sessions of " <> First @ #, CellTags -> "ACPSessions" ] &,
                Cells                 = If[ MatchQ[ { ## }, { sessions, CellTags -> "ACPSessions" } ], { CellObject[ "c1" ] }, { } ] &,
                NotebookWrite         = (AppendTo[ log, { "Write", #1, #2 } ]; Null) &
            },
            recovered = acpSessionsRecover @ owner;
            acpSessionsCloseWindow @ owner;
            {
                recovered,
                KeyTake[ acpSessionsOf @ owner, { "Open", "Stale", "Status" } ],
                log
            }
        ]
    ],
    {
        NotebookObject[ "acp-sessions-window" ],
        <| "Open" -> True, "Stale" -> True, "Status" -> "NotConnected" |>,
        {
            { "Write", CellObject[ "c1" ], Cell[ "sessions of acp-sessions-owner", CellTags -> "ACPSessions" ] },
            { "Close", NotebookObject[ "acp-sessions-window" ] }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "WindowHooks-RecoverAndClose@@Tests/ACPSessions.wlt:848,1-879,2"
]

VerificationTest[
    {
        acpSessionsWindowOf @ NotebookObject[ "acp-sessions-owner" ],
        acpSessionsCell @ NotebookObject[ "acp-sessions-owner" ],
        acpSessionsList @ NotebookObject[ "acp-sessions-no-record" ],
        acpDeleteSession[ NotebookObject[ "acp-sessions-no-record" ], "s" ]
    },
    { None, Cell[ _BoxData, ___, CellTags -> "ACPSessions", ___ ], Missing[ "NotFound" ], Missing[ "NotFound" ] },
    SameTest -> MatchQ,
    TestID   -> "WindowHooks-Headless@@Tests/ACPSessions.wlt:881,1-891,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sessions Window*)

(* The Sessions window without a front end: placement, notebook options, the content cell, the views (rendered from
   window records), the window's actions and the toolbar toggle. *)
VerificationTest[
    $sp = "Wolfram`Chatbook`ACP`Sessions`Private`";
    sessionsContent = Symbol[ $sp <> "sessionsContent" ];
    sessionsKey     = Symbol[ $sp <> "sessionsKey" ];
    viewSignature   = Symbol[ $sp <> "sessionsViewSignature" ];
    $viewNow  = AbsoluteTime @ DateObject[ { 2026, 10, 11, 15, 0, 0 } ];
    $viewNB   = NotebookObject[ "acp-sessions-view" ];
    $fakeConn = Wolfram`ChatbookTests`Fake`ACPConnection[ "c1" ];
    $allCaps  = <| "loadSession" -> True, "sessionCapabilities" -> <| "list" -> <| |>, "delete" -> <| |>, "close" -> <| |>, "resume" -> <| |> |> |>;
    $longTitle = "Fix the order-dependent test in Formatting.wlt and make the reader robust against huge logs";
    viewItem[ id_, dir_, title_, ago_ ] := <| "SessionID" -> id, "Cwd" -> dir, "Title" -> title, "UpdatedAt" -> $viewNow - ago, "Hidden" -> acpSessionHiddenTitleQ @ title |>;
    $viewItems = {
        viewItem[ "v1", $project1, "Add a Sessions window", 120 ],
        viewItem[ "v2", $project1, $longTitle, 3 * 3600 ],
        viewItem[ "v3", $project2, "Refactor the importer", 26 * 3600 ],
        viewItem[ "v4", $project1, "Old work", 400 * 86400 ],
        viewItem[ "v5", $project3, "In a deleted folder", 40 * 86400 ],
        viewItem[ "v6", $project2, "New session - 2026-10-11T12:00:00.000Z", 60 ]
    };
    viewWindow[ extra_: <| |>, store_: <| |> ] := Join[
        Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ $viewNB, $project1, "OpenCode", <| |> ],
        <|
            "Status"       -> "Ready",
            "Connection"   -> $fakeConn,
            "Capabilities" -> $allCaps,
            "AgentInfo"    -> <| "Name" -> "OpenCode" |>,
            "SessionID"    -> "v1",
            "Sessions"     -> Join[ <| "Status" -> "Ready", "Items" -> $viewItems, "ListedAt" -> $viewNow, "Open" -> True |>, store ]
        |>,
        extra
    ];
    view[ window_ ] := Block[ { acpEnsurePublisher = Null & }, sessionsContent[ $viewNB, window, $viewNow ] ];
    boxIDs[ expr_ ] := Cases[ expr, HoldPattern[ BoxID -> id_String ] :> id, Infinity ];
    (* the Enabled option of the button with the given BoxID (level 1 of the Button only: its code is never evaluated) *)
    buttonEnabled[ expr_, id_String ] := FirstCase[
        expr,
        b: HoldPattern @ Button[ ___, BoxID -> id, ___ ] :> Replace[ Cases[ Unevaluated @ b, HoldPattern[ Enabled -> e_ ] :> e, { 1 } ], { { } -> True, { e_ } :> e } ],
        Missing[ ],
        Infinity
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "SessionsWindow-Definitions@@Tests/ACPSessions.wlt:899,1-943,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Relative Times*)
VerificationTest[
    With[ { now = $viewNow },
        {
            acpShortRelativeTime[ now - 5, now ],
            acpShortRelativeTime[ now + 30, now ], (* clocks differ: "now" *)
            acpShortRelativeTime[ now - 59, now ],
            acpShortRelativeTime[ now - 60, now ],
            acpShortRelativeTime[ now - 3 * 60 - 59, now ],
            acpShortRelativeTime[ now - 2 * 3600 - 1, now ],
            acpShortRelativeTime[ now - 86399, now ],
            acpShortRelativeTime[ now - 5 * 86400, now ],
            acpShortRelativeTime[ now - 7 * 86400, now ],
            acpShortRelativeTime[ AbsoluteTime @ DateObject[ { 2026, 3, 4, 12, 0, 0 } ], now ],
            acpShortRelativeTime[ AbsoluteTime @ DateObject[ { 2025, 12, 1, 12, 0, 0 } ], now ],
            acpShortRelativeTime[ None, now ]
        }
    ],
    { "now", "now", "now", "1m", "3m", "2h", "23h", "5d", "Oct 4", "Mar 4", "2025-12-01", "" },
    SameTest -> MatchQ,
    TestID   -> "ShortRelativeTime@@Tests/ACPSessions.wlt:948,1-968,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Placement*)
VerificationTest[
    {
        (* room on the left of the ACP window *)
        acpSessionsPlacement[ <| "Left" -> 800, "Width" -> 360, "Bottom" -> 40, "Top" -> 30 |>, { 0, 1920 }, 300 ],
        (* at the display's left edge: the ACP window moves right just enough *)
        acpSessionsPlacement[ <| "Left" -> 0, "Width" -> 360, "Bottom" -> 40, "Top" -> 30 |>, { 0, 1920 }, 300 ],
        acpSessionsPlacement[ <| "Left" -> 120, "Width" -> 360, "Bottom" -> 0, "Top" -> 25 |>, { 0, 1920 }, 300 ],
        (* a second display left of the main one (negative coordinates) *)
        acpSessionsPlacement[ <| "Left" -> -1920, "Width" -> 360, "Bottom" -> 0, "Top" -> 0 |>, { -1920, 0 }, 300 ],
        (* too narrow for both: over the ACP window at the left edge *)
        acpSessionsPlacement[ <| "Left" -> 0, "Width" -> 600, "Bottom" -> 10, "Top" -> 10 |>, { 0, 800 }, 300 ],
        (* exactly fits on the left; exactly fits beside *)
        acpSessionsPlacement[ <| "Left" -> 300, "Width" -> 360, "Bottom" -> 0, "Top" -> 0 |>, { 0, 1000 }, 300 ][ "Placement" ],
        acpSessionsPlacement[ <| "Left" -> 0, "Width" -> 700, "Bottom" -> 0, "Top" -> 0 |>, { 0, 1000 }, 300 ][ "Placement" ]
    },
    {
        <| "Placement" -> "Left", "WindowMargins" -> { { 500, Automatic }, { 40, 30 } }, "OwnerWindowMargins" -> None, "WindowSize" -> { 300, Automatic } |>,
        <|
            "Placement"          -> "SlideOwner",
            "WindowMargins"      -> { { 0, Automatic }, { 40, 30 } },
            "OwnerWindowMargins" -> { { 300, Automatic }, { 40, 30 } },
            "WindowSize"         -> { 300, Automatic }
        |>,
        <| "Placement" -> "SlideOwner", "WindowMargins" -> { { 0, Automatic }, { 0, 25 } }, "OwnerWindowMargins" -> { { 300, Automatic }, { 0, 25 } }, "WindowSize" -> { 300, Automatic } |>,
        <| "Placement" -> "SlideOwner", "WindowMargins" -> { { -1920, Automatic }, { 0, 0 } }, "OwnerWindowMargins" -> { { -1620, Automatic }, { 0, 0 } }, "WindowSize" -> { 300, Automatic } |>,
        <| "Placement" -> "Overlap", "WindowMargins" -> { { 0, Automatic }, { 10, 10 } }, "OwnerWindowMargins" -> None, "WindowSize" -> { 300, Automatic } |>,
        "Left",
        "SlideOwner"
    },
    SameTest -> MatchQ,
    TestID   -> "Placement@@Tests/ACPSessions.wlt:973,1-1004,2"
]

(* With the ACP window's height and frame width (as measured in a Linux front end with a window manager): the same top
   and height, and the windows touch *)
VerificationTest[
    {
        acpSessionsPlacement[ <| "Left" -> 300, "Width" -> 360, "Bottom" -> 105.75, "Top" -> 142.5, "Height" -> 525, "Frame" -> 9 |>, { 0, 1440 }, 300 ],
        acpSessionsPlacement[ <| "Left" -> 800, "Width" -> 360, "Bottom" -> 40, "Top" -> 30, "Height" -> 600, "Frame" -> 9 |>, { 0, 1920 }, 300 ],
        (* a frame that is not a number counts as none *)
        acpSessionsPlacement[ <| "Left" -> 800, "Width" -> 360, "Bottom" -> 40, "Top" -> 30, "Height" -> 600, "Frame" -> None |>, { 0, 1920 }, 300 ][ "WindowMargins" ],
        (* the frame decides whether the window fits on the left *)
        acpSessionsPlacement[ <| "Left" -> 300, "Width" -> 360, "Bottom" -> 0, "Top" -> 0, "Frame" -> 1 |>, { 0, 1000 }, 300 ][ "Placement" ],
        Wolfram`Chatbook`ACP`Sessions`Private`sessionsFrameWidth[ { 300, 771 }, 360, { 0, 1440 } ],
        Wolfram`Chatbook`ACP`Sessions`Private`sessionsFrameWidth[ { 300, 0 }, 360, { 0, 2880 } ],
        Wolfram`Chatbook`ACP`Sessions`Private`sessionsFrameWidth[ { 300, 800 }, 360, { 0, 1440 } ],
        Wolfram`Chatbook`ACP`Sessions`Private`sessionsFrameWidth[ { 300, Automatic }, 360, { 0, 1440 } ]
    },
    {
        <|
            "Placement"          -> "SlideOwner",
            "WindowMargins"      -> { { 0, Automatic }, { Automatic, 142.5 } },
            "OwnerWindowMargins" -> { { 309, Automatic }, { 105.75, 142.5 } },
            "WindowSize"         -> { 300, 525 }
        |>,
        <| "Placement" -> "Left", "WindowMargins" -> { { 491, Automatic }, { Automatic, 30 } }, "OwnerWindowMargins" -> None, "WindowSize" -> { 300, 600 } |>,
        { { 500, Automatic }, { Automatic, 30 } },
        "SlideOwner",
        9,
        0,
        0,
        0
    },
    SameTest -> MatchQ,
    TestID   -> "Placement-HeightAndFrame@@Tests/ACPSessions.wlt:1008,1-1038,2"
]

(* Without a front end: the default size, no margins, the ACP window is not moved *)
VerificationTest[
    acpSessionsGeometry @ $viewNB,
    <|
        "Placement"          -> "Default",
        "WindowMargins"      -> Automatic,
        "OwnerWindowMargins" -> None,
        "WindowSize"         -> { If[ $OperatingSystem === "MacOSX", 375, 300 ], Automatic },
        "Magnification"      -> 0.85
    |>,
    SameTest -> MatchQ,
    TestID   -> "Placement-Headless@@Tests/ACPSessions.wlt:1041,1-1052,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Notebook and Cell*)
VerificationTest[
    Module[ { nb, opts, events },
        nb   = acpSessionsNotebook[ $viewNB, acpSessionsPlacement[ <| "Left" -> 800, "Width" -> 360, "Bottom" -> 40, "Top" -> 30 |>, { 0, 1920 }, 300 ] ];
        opts = Association[ List @@ Rest @ nb ];
        events = opts[ NotebookEventActions ];
        {
            Head @ nb,
            Length @ First @ nb,
            Lookup[ opts, { WindowMargins, WindowSize, WindowTitle, Evaluator, Magnification } ],
            opts[ TaggingRules ],
            Lookup[ opts, { Deployed, Editable, Saveable, Selectable, ShowCellBracket, ClosingAutoSave, "ClosingSaveDialog", CellInsertionPointCell } ],
            Lookup[ opts, { StyleDefinitions, WindowToolbars, WindowElements, WindowFrameElements } ],
            MatchQ[ opts[ Background ], _LightDarkSwitched ],
            opts[ CellInsertionPointColor ] === opts[ Background ],
            First @ events,
            ! FreeQ[ Cases[ events, HoldPattern[ "WindowClose" :> c_ ] :> HoldComplete @ c ], "SessionsClosed" ],
            ! FreeQ[ Cases[ events, HoldPattern[ "EscapeKeyDown" :> c_ ] :> HoldComplete @ c ], "SessionsCancelDelete" ],
            (* no margins: the front end places it *)
            KeyExistsQ[ Association[ List @@ Rest @ acpSessionsNotebook[ $viewNB, acpSessionsGeometry @ $viewNB ] ], WindowMargins ]
        }
    ],
    {
        Notebook,
        1,
        { { { 500, Automatic }, { 40, 30 } }, { 300, Automatic }, "Sessions", "Local", 0.85 },
        <| "ACPSessions" -> <| "Owner" -> $viewNB |>, "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |> |>,
        { True, False, False, False, False, False, False, None },
        { "Default.nb", { }, { "VerticalScrollBar" }, { "CloseBox", "ResizeArea" } },
        True,
        True,
        ParentList,
        True,
        True,
        False
    },
    SameTest -> MatchQ,
    TestID   -> "SessionsNotebook-Options@@Tests/ACPSessions.wlt:1057,1-1094,2"
]

(* One self-contained cell: no style name, every option inline, the owner in its own TaggingRules, the cell tag that
   acpSessionsRebuildWindow finds; the views are kernel Dynamics written with full context names that load Chatbook *)
VerificationTest[
    Module[ { cell, opts },
        cell = acpSessionsCell @ $viewNB;
        opts = Association @ Cases[ List @@ Rest @ cell, _Rule ];
        {
            Head @ cell,
            MatchQ[ First @ cell, BoxData[ _ ] ],
            Cases[ List @@ Rest @ cell, _String ],
            Lookup[ opts, { CellTags, TaggingRules, Deployed, Editable, Selectable, ShowCellBracket, ShowStringCharacters, CellMargins, FontFamily } ],
            (* Deletable -> False would make acpSessionsRebuildWindow's NotebookWrite insert a second cell *)
            KeyTake[ opts, { StyleDefinitions, Deletable } ],
            Length @ Cases[ cell, _DynamicBox, Infinity ],
            ! FreeQ[ cell, Wolfram`Chatbook`ACP`Common`acpRenderView ],
            ! FreeQ[ cell, Wolfram`Chatbook`ACP`Common`acpSyncDerivedView ],
            Count[ cell, HoldPattern @ Needs[ "Wolfram`Chatbook`" -> None ], Infinity ],
            (* the view's change symbol exists before the front end sees the cell *)
            MatchQ[ acpEntitySymbol[ Wolfram`Chatbook`ACP`Common`acpWindowKey @ $viewNB, "Sessions" ], HoldComplete[ _Symbol ] ]
        }
    ],
    {
        Cell,
        True,
        { },
        { "ACPSessions", <| "ACPSessions" -> <| "Owner" -> $viewNB |> |>, True, False, False, False, False, 0, "Source Sans Pro" },
        <| |>,
        2,
        True,
        True,
        2,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "SessionsCell-Structure@@Tests/ACPSessions.wlt:1098,1-1131,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Views*)

(* Projects (the window's open with its sessions, others closed), the current session highlighted without actions, a
   long title shortened (the whole title in the tooltip), relative times, the hidden session left out, a project whose
   folder is gone *)
VerificationTest[
    Module[ { v, ids, k },
        v   = view @ viewWindow[ ];
        ids = boxIDs @ v;
        k   = sessionsKey;
        {
            FreeQ[ v, _Failure | _Missing ],
            containsTextQ[ v, "Sessions" ] && containsTextQ[ v, "OpenCode" ],
            MemberQ[ ids, "ACPSessionsRefresh" ],
            (* projects in order of their newest session; the window's folder first here *)
            (* every project row is in the Mouseover twice (normal and hover) *)
            DeleteDuplicates @ Select[ ids, StringStartsQ[ "ACPSessionsProject-" ] ] === ( "ACPSessionsProject-" <> k[ # ] & /@ { $project1, $project2, $project3 } ),
            Select[ ids, StringStartsQ[ "ACPSessionsOpen-" ] ] === { "ACPSessionsOpen-" <> k[ "v2" ], "ACPSessionsOpen-" <> k[ "v4" ] },
            Select[ ids, StringStartsQ[ "ACPSessionsDelete-" ] ] === { "ACPSessionsDelete-" <> k[ "v2" ], "ACPSessionsDelete-" <> k[ "v4" ] },
            containsTextQ[ v, "Shown in the agent window" ],
            containsTextQ[ v, "Add a Sessions window" ],
            (* closed project: its sessions are not shown; the hidden session never *)
            containsTextQ[ v, "Refactor the importer" ],
            containsTextQ[ v, "New session - " ],
            (* the long title: 40 characters with an ellipsis, the whole title in the tooltip *)
            MemberQ[ boxStrings @ v, StringTake[ $longTitle, 39 ] <> "\[Ellipsis]" ],
            MemberQ[ boxStrings @ v, $longTitle ],
            containsTextQ[ v, "2m" ] && containsTextQ[ v, "3h" ] && containsTextQ[ v, "2025-09-06" ],
            containsTextQ[ v, "Updated Oct 11, 2026 12:00" ],
            (* the missing folder: "+" and open-folder disabled *)
            buttonEnabled[ v, "ACPSessionsNew-" <> k[ $project3 ] ],
            buttonEnabled[ v, "ACPSessionsOpenFolder-" <> k[ $project3 ] ],
            buttonEnabled[ v, "ACPSessionsNew-" <> k[ $project2 ] ],
            containsTextQ[ v, "This folder no longer exists" ],
            (* no text from the agent in button code: only keys *)
            FreeQ[ Cases[ v, HoldPattern @ Button[ _, code_, ___ ] :> HoldComplete @ code, Infinity ], "v2" | $project1 ]
        }
    ],
    { True, True, True, True, True, True, True, True, False, False, True, True, True, True, False, False, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "SessionsView-Rows@@Tests/ACPSessions.wlt:1140,1-1176,2"
]

(* Opened and closed projects are kept in the store; the window's own folder without visible sessions: "No sessions yet" *)
VerificationTest[
    Module[ { k = sessionsKey, opened, empty },
        $project4 = ExpandFileName @ CreateDirectory @ FileNameJoin @ { $scratch, "project4" };
        opened = view @ viewWindow[ <| |>, <| "Expanded" -> <| $project1 -> False, $project2 -> True |> |> ];
        empty  = view @ <| viewWindow[ ], "ProjectDirectory" -> $project4, "SessionID" -> "fresh" |>;
        {
            containsTextQ[ opened, "Refactor the importer" ],
            containsTextQ[ opened, "Add a Sessions window" ],
            containsTextQ[ opened, "New session - " ],
            Select[ boxIDs @ empty, StringStartsQ[ "ACPSessionsProject-" ] ][[ 1 ]] === "ACPSessionsProject-" <> k[ $project4 ],
            containsTextQ[ empty, "No sessions yet" ],
            (* the window has no project of its own among them: the first project is open *)
            containsTextQ[ view @ <| viewWindow[ ], "ProjectDirectory" -> None, "SessionID" -> None |>, "Add a Sessions window" ]
        }
    ],
    { True, False, False, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "SessionsView-Projects@@Tests/ACPSessions.wlt:1179,1-1197,2"
]

(* A project shows its newest 25 sessions (and the window's own one, wherever it is) and "Show 4 more" (the window's own
   one is not counted again); the action shows 25 more *)
VerificationTest[
    Module[ { k = sessionsKey, many, window, before, after, opens },
        many   = Table[ viewItem[ "m" <> ToString @ i, $project1, "Many " <> ToString @ i, 60 * i ], { i, 30 } ];
        window = viewWindow[ <| "SessionID" -> "m28" |>, <| "Items" -> many |> ];
        opens  = Function[ v, Length @ Select[ boxIDs @ v, StringStartsQ[ "ACPSessionsOpen-" ] ] ];
        before = view @ window;
        Block[ { $acpWindows = <| $viewNB -> window |>, acpEnsurePublisher = Null &, acpCheckSession = True & },
            {
                Wolfram`Chatbook`Common`acpAction[ "SessionsShowMore", $viewNB, k[ $project1 ] ],
                Wolfram`Chatbook`Common`acpAction[ "SessionsShowMore", $viewNB, "nope" ],
                after = view @ acpWindowGet @ $viewNB;
                opens @ before,
                containsTextQ[ before, "Many 28" ],
                containsTextQ[ before, "Many 27" ],
                containsTextQ[ before, "Show 4 more" ],
                MemberQ[ boxIDs @ before, "ACPSessionsShowMore-" <> k[ $project1 ] ],
                opens @ after,
                containsTextQ[ after, "more" ]
            }
        ]
    ],
    { 50, Missing[ "NotFound" ], 25, True, False, True, True, 29, False },
    SameTest -> MatchQ,
    TestID   -> "SessionsView-ShowMore@@Tests/ACPSessions.wlt:1201,1-1225,2"
]

(* The window's own session past the first page is shown and not counted: with 26 sessions and the own one last, there
   is nothing more to show; with 50 and the own one 40th, 24 more *)
VerificationTest[
    Module[ { many, moreText },
        many     = Table[ viewItem[ "n" <> ToString @ i, $project1, "Numbered " <> ToString @ i, 60 * i ], { i, 50 } ];
        moreText = Function[ v, Select[ boxStrings @ v, StringMatchQ[ "Show " ~~ DigitCharacter.. ~~ " more" ] ] ];
        {
            moreText @ view @ viewWindow[ <| "SessionID" -> "n26" |>, <| "Items" -> Take[ many, 26 ] |> ],
            containsTextQ[ view @ viewWindow[ <| "SessionID" -> "n26" |>, <| "Items" -> Take[ many, 26 ] |> ], "Numbered 26" ],
            moreText @ view @ viewWindow[ <| "SessionID" -> "n40" |>, <| "Items" -> many |> ],
            moreText @ view @ viewWindow[ <| "SessionID" -> "n1" |>, <| "Items" -> Take[ many, 30 ] |> ]
        }
    ],
    { { }, True, { "Show 24 more" }, { "Show 5 more" } },
    SameTest -> MatchQ,
    TestID   -> "SessionsView-ShowMore-OwnSession@@Tests/ACPSessions.wlt:1229,1-1243,2"
]

(* A disconnected window's own (resumable) session is shown even if it was never used; without it, it is hidden *)
VerificationTest[
    Module[ { disconnected },
        (* the never-used v6 is the only session of project2 *)
        disconnected = viewWindow[
            <| "Status" -> "Disconnected", "Connection" -> None, "SessionID" -> None, "ResumableSessionID" -> "v6", "ProjectDirectory" -> $project2 |>,
            <| "Status" -> "NotConnected", "Items" -> Select[ $viewItems, #[ "SessionID" ] =!= "v3" & ] |>
        ];
        {
            (* shown as "New session", without the time of OpenCode's fallback title *)
            MemberQ[ boxStrings @ view @ disconnected, "New session" ],
            containsTextQ[ view @ disconnected, "No sessions yet" ],
            containsTextQ[ view @ disconnected, "Shown in the agent window" ],
            MemberQ[ boxStrings @ view @ <| disconnected, "ResumableSessionID" -> None |>, "New session" ],
            containsTextQ[ view @ <| disconnected, "ResumableSessionID" -> None |>, "No sessions yet" ]
        }
    ],
    { True, False, True, False, True },
    SameTest -> MatchQ,
    TestID   -> "SessionsView-ResumableShown@@Tests/ACPSessions.wlt:1246,1-1265,2"
]

(* An agent that can delete sessions but not load them: the rows can't be opened but have the trash button *)
VerificationTest[
    Module[ { k = sessionsKey, caps, v },
        caps = <| "sessionCapabilities" -> <| "list" -> <| |>, "delete" -> <| |> |> |>;
        v    = view @ viewWindow[ <| "Capabilities" -> caps |> ];
        {
            Select[ boxIDs @ v, StringStartsQ[ "ACPSessionsOpen-" ] ],
            DeleteDuplicates @ Select[ boxIDs @ v, StringStartsQ[ "ACPSessionsDelete-" ] ],
            containsTextQ[ v, "OpenCode can't open saved sessions" ],
            (* busy: no trash button either *)
            Select[ boxIDs @ view @ viewWindow[ <| "Capabilities" -> caps, "CurrentTurn" -> "t1" |> ], StringStartsQ[ "ACPSessionsDelete-" ] ],
            (* the confirmation works as with loadSession *)
            containsTextQ[ view @ viewWindow[ <| "Capabilities" -> caps |>, <| "ConfirmDelete" -> <| "SessionID" -> "v2", "ArmAt" -> 0 |> |> ], "Delete this session?" ]
        }
    ],
    { { }, { "ACPSessionsDelete-" <> sessionsKey[ "v2" ], "ACPSessionsDelete-" <> sessionsKey[ "v4" ] }, True, { }, True },
    SameTest -> MatchQ,
    TestID   -> "SessionsView-DeleteWithoutLoad@@Tests/ACPSessions.wlt:1268,1-1285,2"
]

(* Text the agent chose never reaches boxes with the front end's linear syntax characters: its name (initialize
   response) in the Sessions window's labels, and a project folder that came from a listed session (restored from
   another folder) in the toolbar and the window title *)
VerificationTest[
    Module[ { evil, rawQ, dir, nbo = NotebookObject[ "acp-sessions-evil" ], window, row },
        evil = "\:f7c1\:f7c9StyleBox[\"HIDDEN\", FontSize -> 1]\:f7c0";
        rawQ = Function[ expr, ! FreeQ[ expr, s_String /; StringContainsQ[ s, "\:f7c1" | "\:f7c9" | "\:f7c0" ] ] ];
        dir  = FileNameJoin @ { $scratch, "proj" <> evil <> "x" };
        window = <| Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, dir, "OpenCode", <| |> ], "Status" -> "Disconnected" |>;
        Block[ { $acpWindows = <| nbo -> window |>, acpEnsurePublisher = Null &, Wolfram`Chatbook`ACP`UI`Private`acpPreference = Missing[ "NotSet" ] & },
            row = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ nbo, window ]
        ];
        {
            rawQ @ Wolfram`Chatbook`ACP`Connection`Private`agentInfoOf[ <| "title" -> "Agent" <> evil, "version" -> "1" <> evil |>, <| |> ],
            rawQ @ view @ viewWindow[ <| "AgentInfo" -> <| "Name" -> "Agent" <> evil |>, "Capabilities" -> <| |> |>, <| "Status" -> "Unsupported" |> ],
            rawQ @ view @ viewWindow[ <| "AgentInfo" -> <| "Name" -> "Agent" <> evil |>, "Capabilities" -> <| "sessionCapabilities" -> <| "list" -> <| |> |> |> |> ],
            rawQ @ acpSessionsBusyLabel @ viewWindow[ <| "AgentInfo" -> <| "Name" -> "Agent" <> evil |>, "ConnectToken" -> "t" |> ],
            rawQ @ Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString[ dir, "OpenCode", False ],
            rawQ @ Wolfram`Chatbook`ACP`UI`Private`acpWindowTitleString[ dir, "OpenCode", True ],
            rawQ @ row,
            (* the folder name is still there, neutralized *)
            containsTextQ[ row, "proj\:fffd" ]
        }
    ],
    { False, False, False, False, False, False, False, True },
    SameTest -> MatchQ,
    TestID   -> "AgentTextNeutralized@@Tests/ACPSessions.wlt:1290,1-1314,2"
]

(* The trash button asks first: "Delete this session?" with Delete and Cancel (Cancel last, where the trash was) *)
VerificationTest[
    Module[ { v, ids, k = sessionsKey },
        v   = view @ viewWindow[ <| |>, <| "ConfirmDelete" -> <| "SessionID" -> "v2", "ArmAt" -> 0 |> |> ];
        ids = boxIDs @ v;
        {
            containsTextQ[ v, "Delete this session?" ],
            Select[ ids, StringStartsQ[ "ACPSessionsDelete" ] ],
            MemberQ[ ids, "ACPSessionsOpen-" <> k[ "v2" ] ],
            (* busy: no confirmation, no actions *)
            containsTextQ[ view @ viewWindow[ <| "CurrentTurn" -> "t1" |>, <| "ConfirmDelete" -> <| "SessionID" -> "v2", "ArmAt" -> 0 |> |> ], "Delete this session?" ]
        }
    ],
    {
        True,
        { "ACPSessionsDeleteConfirm-" <> sessionsKey[ "v2" ], "ACPSessionsDeleteCancel-" <> sessionsKey[ "v2" ], "ACPSessionsDelete-" <> sessionsKey[ "v4" ] },
        False,
        False
    },
    SameTest -> MatchQ,
    TestID   -> "SessionsView-Confirm@@Tests/ACPSessions.wlt:1317,1-1337,2"
]

(* While the ACP window is busy, sessions can't be opened or deleted and "+" is disabled; the tooltip says why *)
VerificationTest[
    Module[ { k = sessionsKey, running, permission, restoring },
        running    = view @ viewWindow[ <| "CurrentTurn" -> "t1", "Status" -> "Running" |> ];
        permission = view @ viewWindow[ <| "CurrentTurn" -> "t1", "PendingPermissions" -> <| "r1" -> <| |> |> |> ];
        restoring  = view @ viewWindow[ <| "Status" -> "Restoring", "Restore" -> <| "SessionID" -> "v4", "Stage" -> "Loading", "Token" -> "t" |> |> ];
        {
            Select[ boxIDs @ running, StringStartsQ[ "ACPSessionsOpen-" | "ACPSessionsDelete-" ] ],
            buttonEnabled[ running, "ACPSessionsNew-" <> k[ $project2 ] ],
            buttonEnabled[ running, "ACPSessionsOpenFolder-" <> k[ $project2 ] ],
            containsTextQ[ running, "Wait for the current turn to finish" ],
            containsTextQ[ permission, "Answer the pending approval request first" ],
            (* restoring: the restored session is the highlighted one, with "Loading..." *)
            Select[ boxIDs @ restoring, StringStartsQ[ "ACPSessionsOpen-" ] ],
            containsTextQ[ restoring, "Loading\[Ellipsis]" ],
            containsTextQ[ restoring, "Restoring\[Ellipsis]" ]
        }
    ],
    { { }, False, True, True, True, { }, True, True },
    SameTest -> MatchQ,
    TestID   -> "SessionsView-Busy@@Tests/ACPSessions.wlt:1340,1-1360,2"
]

(* Status lines; a session being deleted; the notice of a failed delete *)
VerificationTest[
    Module[ { lines, status, v },
        lines  = {
            "Choose a project folder to see sessions",
            "Sessions are listed when OpenCode is connected",
            "OpenCode can't list sessions",
            "Loading sessions\[Ellipsis]",
            "Couldn't list the sessions: boom"
        };
        status = Function[ w, Intersection[ boxStrings @ view @ w, lines ] ];
        v = view @ viewWindow[ <| |>, <| "Deleting" -> <| "v2" -> $fakeConn |>, "Notice" -> "Couldn't delete the session: gone" |> ];
        {
            status @ viewWindow[ <| "ProjectDirectory" -> None, "Status" -> "NoDirectory", "Connection" -> None |>, <| "Status" -> "NotConnected", "Items" -> { }, "ListedAt" -> None |> ],
            status @ viewWindow[ <| "Status" -> "Disconnected", "Connection" -> None |>, <| "Status" -> "NotConnected", "Items" -> { }, "ListedAt" -> None |> ],
            status @ viewWindow[ <| "Capabilities" -> <| |> |>, <| "Status" -> "Unsupported", "Items" -> { }, "ListedAt" -> None |> ],
            status @ viewWindow[ <| |>, <| "Status" -> "Listing", "Items" -> { }, "ListedAt" -> None |> ],
            status @ viewWindow[ <| |>, <| "Status" -> "Error", "Error" -> <| "Code" -> 1, "Message" -> "Couldn't list the sessions: boom" |>, "Items" -> { }, "ListedAt" -> None |> ],
            (* no window record (after a kernel restart) *)
            Intersection[ boxStrings @ Block[ { acpEnsurePublisher = Null & }, sessionsContent[ $viewNB, Missing[ "NotFound" ], $viewNow ] ], lines ],
            containsTextQ[ v, "Deleting\[Ellipsis]" ],
            MemberQ[ boxIDs @ v, "ACPSessionsDelete-" <> sessionsKey[ "v2" ] ],
            containsTextQ[ v, "Couldn't delete the session: gone" ],
            MemberQ[ boxIDs @ v, "ACPSessionsDismissNotice" ],
            (* no delete without the capability or a connection; restore still works without a connection *)
            Select[ boxIDs @ view @ viewWindow[ <| "Capabilities" -> <| "loadSession" -> True |> |> ], StringStartsQ[ "ACPSessionsDelete-" ] ],
            Length @ Select[ boxIDs @ view @ viewWindow[ <| "Connection" -> None, "Capabilities" -> None, "Status" -> "Disconnected" |> ], StringStartsQ[ "ACPSessionsOpen-" ] ],
            containsTextQ[ view @ viewWindow[ <| "Capabilities" -> <| "sessionCapabilities" -> <| "list" -> <| |> |> |> |> ], "OpenCode can't open saved sessions" ]
        }
    ],
    {
        { "Choose a project folder to see sessions" },
        { "Sessions are listed when OpenCode is connected" },
        { "OpenCode can't list sessions" },
        { "Loading sessions\[Ellipsis]" },
        { "Couldn't list the sessions: boom" },
        { "Sessions are listed when OpenCode is connected" },
        True,
        False,
        True,
        True,
        { },
        2,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "SessionsView-Status@@Tests/ACPSessions.wlt:1363,1-1409,2"
]

(* The view re-renders when what it shows changes, not on listing steps that change nothing *)
VerificationTest[
    Module[ { w = viewWindow[ ] },
        {
            viewSignature @ w === viewSignature @ <| w, "Sessions" -> <| w[ "Sessions" ], "Status" -> "Listing", "Token" -> "t", "Stale" -> True, "ListedAt" -> $viewNow + 5 |> |>,
            viewSignature @ w === viewSignature @ <| w, "Sessions" -> <| w[ "Sessions" ], "Minute" -> 123 |> |>,
            viewSignature @ w === viewSignature @ <| w, "Sessions" -> <| w[ "Sessions" ], "Expanded" -> <| $project2 -> True |> |> |>,
            viewSignature @ w === viewSignature @ <| w, "Sessions" -> <| w[ "Sessions" ], "ConfirmDelete" -> <| "SessionID" -> "v2", "ArmAt" -> 0 |> |> |>,
            viewSignature @ w === viewSignature @ <| w, "CurrentTurn" -> "t1" |>,
            viewSignature @ w === viewSignature @ <| w, "Usage" -> <| "used" -> 5 |> |>,
            viewSignature @ Missing[ ]
        }
    ],
    { True, False, False, False, False, True, None },
    SameTest -> MatchQ,
    TestID   -> "SessionsView-Signature@@Tests/ACPSessions.wlt:1412,1-1427,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Window Actions*)
VerificationTest[
    Module[ { k = sessionsKey, log = { }, run, results },
        run = Function[ args, Wolfram`Chatbook`Common`acpAction @@ args ];
        Block[
            {
                $acpWindows           = <| $viewNB -> viewWindow[ ] |>,
                acpEnsurePublisher    = Null &,
                acpCheckSession       = True &,
                acpRestoreSession     = (AppendTo[ log, { "Restore", ## } ]; "Restoring") &,
                acpNewSessionIn       = (AppendTo[ log, { "New", ## } ]; "New") &,
                acpReviewOpenFile     = (AppendTo[ log, { "OpenFile", ## } ]; Null) &,
                acpDeleteSession      = (AppendTo[ log, { "Delete", ## } ]; "Deleting") &
            },
            results = {
                run @ { "SessionsOpen", $viewNB, k[ "v2" ] },
                run @ { "SessionsNew", $viewNB, k[ $project2 ] },
                run @ { "SessionsNew", $viewNB, k[ $project1 ] },
                run @ { "SessionsOpenFolder", $viewNB, k[ $project2 ] },
                run @ { "SessionsOpen", $viewNB, "nope" },
                run @ { "SessionsToggleProject", $viewNB, k[ $project2 ], False },
                acpSessionsOf[ $viewNB ][ "Expanded" ],
                run @ { "SessionsToggleProject", $viewNB, k[ $project1 ], True },
                acpSessionsOf[ $viewNB ][ "Expanded" ],
                (* delete: the confirmation, a click before it is armed is ignored, then it deletes *)
                run @ { "SessionsConfirmDelete", $viewNB, k[ "v4" ] },
                MatchQ[ acpSessionsOf[ $viewNB ][ "ConfirmDelete" ], <| "SessionID" -> "v4", "ArmAt" -> _? NumberQ |> ],
                run @ { "SessionsDelete", $viewNB, k[ "v4" ] },
                Pause[ 0.45 ];
                run @ { "SessionsDelete", $viewNB, k[ "v2" ] }, (* not the confirmed one *)
                run @ { "SessionsDelete", $viewNB, k[ "v4" ] },
                acpSessionsOf[ $viewNB ][ "ConfirmDelete" ],
                (* cancel; Escape when nothing is confirmed changes nothing *)
                run @ { "SessionsConfirmDelete", $viewNB, k[ "v2" ] },
                run @ { "SessionsCancelDelete", $viewNB },
                acpSessionsOf[ $viewNB ][ "ConfirmDelete" ],
                run @ { "SessionsCancelDelete", $viewNB }
            }
        ];
        { results, log }
    ],
    {
        {
            "Restoring",
            "New",
            "New",
            $project2,
            Missing[ "NotFound" ],
            True,
            <| $project2 -> True |>,
            False,
            <| $project2 -> True, $project1 -> False |>,
            "Confirm",
            True,
            Missing[ "NotArmed" ],
            Missing[ "NotConfirmed" ],
            "Deleting",
            None,
            "Confirm",
            "Cancelled",
            None,
            "Cancelled"
        },
        {
            { "Restore", $viewNB, "v2", $project1 },
            { "New", $viewNB, $project2 },
            { "New", $viewNB, $project1 },
            { "OpenFile", $project2 },
            { "Delete", $viewNB, "v4" }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "SessionsWindow-Actions@@Tests/ACPSessions.wlt:1432,1-1504,2"
]

(* Delete is refused while the window is busy; a refusal of the backend becomes the window's notice *)
VerificationTest[
    Module[ { k = sessionsKey, armed },
        armed = <| "ConfirmDelete" -> <| "SessionID" -> "v4", "ArmAt" -> 0 |> |>;
        {
            Block[ { $acpWindows = <| $viewNB -> viewWindow[ <| "CurrentTurn" -> "t1" |>, armed ] |>, acpEnsurePublisher = Null &, acpCheckSession = True & },
                { Wolfram`Chatbook`Common`acpAction[ "SessionsDelete", $viewNB, k[ "v4" ] ], acpSessionsOf[ $viewNB ][ "ConfirmDelete" ] }
            ],
            Block[
                {
                    $acpWindows        = <| $viewNB -> viewWindow[ <| |>, armed ] |>,
                    acpEnsurePublisher = Null &,
                    acpCheckSession    = True &,
                    acpDeleteSession   = Failure[ "NotConnected", <| |> ] &
                },
                { Wolfram`Chatbook`Common`acpAction[ "SessionsDelete", $viewNB, k[ "v4" ] ], acpSessionsOf[ $viewNB ][ "Notice" ] }
            ],
            Block[ { $acpWindows = <| $viewNB -> viewWindow[ <| |>, <| "Notice" -> "x" |> ] |>, acpEnsurePublisher = Null &, acpCheckSession = True & },
                Wolfram`Chatbook`Common`acpAction[ "SessionsDismissNotice", $viewNB ];
                acpSessionsOf[ $viewNB ][ "Notice" ]
            ]
        }
    ],
    {
        { Failure[ "Busy", _ ], None },
        { Failure[ "NotConnected", _ ], "This session can't be deleted now." },
        None
    },
    SameTest -> MatchQ,
    TestID   -> "SessionsWindow-DeleteRefused@@Tests/ACPSessions.wlt:1507,1-1536,2"
]

(* The toolbar button opens the window (placed, with the owner in its TaggingRules) and lists; again, it closes it *)
VerificationTest[
    Module[ { log = { }, sessions = NotebookObject[ "acp-sessions-window-2" ], open = None, first, second },
        Block[
            {
                $acpWindows          = <| $viewNB -> viewWindow[ <| |>, <| "Open" -> False, "ConfirmDelete" -> <| "SessionID" -> "v2", "ArmAt" -> 0 |> |> ] |>,
                acpEnsurePublisher   = Null &,
                acpCheckSession      = True &,
                acpSessionsList      = (AppendTo[ log, { "List", # } ]; "Listing") &,
                acpSessionsWindowOf  = open &,
                NotebookPut          = (AppendTo[ log, { "Put", # } ]; open = sessions) &,
                NotebookClose        = (AppendTo[ log, { "Close", # } ]; open = None; Null) &
            },
            first  = { Wolfram`Chatbook`Common`acpAction[ "ToggleSessions", $viewNB ], KeyTake[ acpSessionsOf @ $viewNB, { "Open", "ConfirmDelete" } ] };
            second = { Wolfram`Chatbook`Common`acpAction[ "ToggleSessions", $viewNB ], acpSessionsOf[ $viewNB ][ "Open" ] }
        ];
        {
            first,
            second,
            log[[ All, 1 ]],
            MatchQ[
                log[[ 1, 2 ]],
                Notebook[
                    { Cell[ _BoxData, ___, CellTags -> "ACPSessions", ___ ] },
                    ___,
                    TaggingRules -> KeyValuePattern[ "ACPSessions" -> <| "Owner" -> $viewNB |> ],
                    ___
                ]
            ],
            log[[ 2 ]],
            log[[ 3 ]]
        }
    ],
    {
        { NotebookObject[ "acp-sessions-window-2" ], <| "Open" -> True, "ConfirmDelete" -> None |> },
        { "Closed", False },
        { "Put", "List", "Close" },
        True,
        { "List", $viewNB },
        { "Close", NotebookObject[ "acp-sessions-window-2" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "ToggleSessions@@Tests/ACPSessions.wlt:1539,1-1581,2"
]

(* Whether the open Sessions window is hidden by the windows in front of it (front to back, as Notebooks[] lists them) *)
VerificationTest[
    Module[ { owner = NotebookObject[ "o" ], sessions = NotebookObject[ "s" ], user = NotebookObject[ "u" ], palette = NotebookObject[ "p" ], info },
        info[ nb_, rect_, visible_: True, floating_: False ] := <| "Notebook" -> nb, "Visible" -> visible, "Floating" -> floating, "Rect" -> rect |>;
        {
            (* beside the ACP window ("SlideOwner"), nothing else in front: visible *)
            acpSessionsCoveredQ[ { info[ owner, { { 300, 660 }, { 30, 900 } } ], info[ sessions, { { 0, 300 }, { 30, 900 } } ] }, owner, sessions ],
            (* a maximized notebook in front of it: hidden *)
            acpSessionsCoveredQ[ { info[ owner, { { 0, 360 }, { 30, 900 } } ], info[ user, { { 0, 1920 }, { 0, 1050 } } ], info[ sessions, { { 0, 300 }, { 30, 900 } } ] }, owner, sessions ],
            (* the ACP window over it ("Overlap"): hidden *)
            acpSessionsCoveredQ[ { info[ owner, { { 0, 360 }, { 30, 900 } } ], info[ sessions, { { 0, 300 }, { 30, 900 } } ] }, owner, sessions ],
            (* a window in front that covers less than half of it, a palette, an invisible window: visible *)
            acpSessionsCoveredQ[ { info[ owner, { { 300, 660 }, { 30, 900 } } ], info[ user, { { 200, 1000 }, { 0, 1000 } } ], info[ sessions, { { 0, 300 }, { 30, 900 } } ] }, owner, sessions ],
            acpSessionsCoveredQ[ { info[ palette, { { 0, 300 }, { 0, 900 } }, True, True ], info[ owner, { { 300, 660 }, { 30, 900 } } ], info[ sessions, { { 0, 300 }, { 30, 900 } } ] }, owner, sessions ],
            acpSessionsCoveredQ[ { info[ owner, { { 300, 660 }, { 30, 900 } } ], info[ user, { { 0, 1920 }, { 0, 1050 } }, False ], info[ sessions, { { 0, 300 }, { 30, 900 } } ] }, owner, sessions ],
            (* the order is not trusted if the ACP window is not in front; no geometry: visible *)
            acpSessionsCoveredQ[ { info[ user, { { 0, 1920 }, { 0, 1050 } } ], info[ owner, { { 300, 660 }, { 30, 900 } } ], info[ sessions, { { 0, 300 }, { 30, 900 } } ] }, owner, sessions ],
            acpSessionsCoveredQ[ { info[ owner, None ], info[ user, None ], info[ sessions, None ] }, owner, sessions ],
            acpSessionsCoveredQ[ { }, owner, sessions ],
            (* without a front end the toolbar button closes it *)
            Wolfram`Chatbook`ACP`Sessions`Private`sessionsCoveredQ[ owner, sessions ]
        }
    ],
    { False, True, True, False, False, False, False, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "SessionsCoveredQ@@Tests/ACPSessions.wlt:1584,1-1609,2"
]

(* A hidden Sessions window is brought back (placed and selected, and it lists) instead of being closed *)
VerificationTest[
    Module[ { log = { }, sessions = NotebookObject[ "acp-sessions-window-3" ], result },
        Block[
            {
                $acpWindows          = <| $viewNB -> viewWindow[ <| |>, <| "Open" -> True |> ] |>,
                acpEnsurePublisher   = Null &,
                acpCheckSession      = True &,
                acpSessionsList      = (AppendTo[ log, { "List", # } ]; "Listing") &,
                acpSessionsWindowOf  = sessions &,
                SetSelectedNotebook  = (AppendTo[ log, { "Select", # } ]; #) &,
                NotebookClose        = (AppendTo[ log, { "Close", # } ]; Null) &,
                Wolfram`Chatbook`ACP`Sessions`Private`sessionsCoveredQ = True &
            },
            result = Wolfram`Chatbook`Common`acpAction[ "ToggleSessions", $viewNB ];
            { result, log, acpSessionsOf[ $viewNB ][ "Open" ] }
        ]
    ],
    { "Raised", { { "Select", NotebookObject[ "acp-sessions-window-3" ] }, { "List", $viewNB } }, True },
    SameTest -> MatchQ,
    TestID   -> "ToggleSessions-Covered@@Tests/ACPSessions.wlt:1612,1-1632,2"
]

(* The toolbar has the Sessions button (icon only, with a tooltip) *)
VerificationTest[
    Module[ { button = acpSessionsButton @ $viewNB },
        {
            Cases[ button, HoldPattern[ BoxID -> id_ ] :> id, { 1 } ],
            ! FreeQ[ Cases[ button, HoldPattern @ Button[ _, code_, ___ ] :> HoldComplete @ code, { 0 } ], "ToggleSessions" ],
            containsTextQ[ button, "Sessions" ],
            ! FreeQ[ button, "WorkspaceToolbarIconHistory" ]
        }
    ],
    { { "ACPSessionsButton" }, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "SessionsButton@@Tests/ACPSessions.wlt:1635,1-1647,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Remote Windows*)

(* A remote window's sessions are in folders on its host: POSIX paths that are never looked at on this computer *)
VerificationTest[
    $remoteSSH   = <| "MachineName" -> "devbox.example.com", "Username" -> "u", "Arguments" -> { }, "Executable" -> Automatic |>;
    $remoteItems = {
        viewItem[ "r1", "/home/u/p/", "Remote one", 120 ],
        viewItem[ "r2", "/home/u/p", "Remote two", 3600 ],
        viewItem[ "r3", "/", "At the root", 7200 ],
        viewItem[ "r4", "/srv/gone dir", "Elsewhere", 86400 ]
    };
    remoteViewWindow[ extra_: <| |>, store_: <| |> ] := viewWindow[
        <| "ProjectDirectory" -> "/home/u/p", "Settings" -> <| "SSHSettings" -> $remoteSSH |>, "RemoteHome" -> "/home/u", "SessionID" -> "r1", extra |>,
        <| "Items" -> $remoteItems, store |>
    ];
    (* Evaluates eval with DirectoryQ and ExpandFileName of the remote paths sown (and not done): { result, sown } *)
    remotePathQ[ p_String ] := p === "/" || p === "//" || StringStartsQ[ p, { "/home/u", "/srv" } ];
    remoteTrap // Attributes = { HoldAll };
    remoteTrap[ eval_ ] := Module[ { r = Reap @ Internal`InheritedBlock[ { DirectoryQ, ExpandFileName },
            Unprotect[ DirectoryQ, ExpandFileName ];
            DirectoryQ[ p_String ] /; remotePathQ @ p := (Sow[ { "DirectoryQ", p } ]; False);
            ExpandFileName[ p_String ] /; remotePathQ @ p := (Sow[ { "ExpandFileName", p } ]; p);
            eval
        ] },
        { First @ r, Flatten[ Last @ r, 1 ] }
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPSessions-Remote-Definitions@@Tests/ACPSessions.wlt:1654,1-1681,2"
]

(* Grouping: "/home/u/p/" and "/home/u/p" are one project, named with POSIX names; the root is "/" *)
VerificationTest[
    remoteTrap @ Module[ { projects, key },
        projects = acpSessionsProjects @ remoteViewWindow[ ];
        key      = Wolfram`Chatbook`ACP`Sessions`Private`sessionsPathKey;
        {
            Lookup[ projects, "Key" ],
            Lookup[ projects, "Name" ],
            Lookup[ projects, "Count" ],
            Lookup[ projects, "Current" ],
            key[ #, True ] & /@ { "/home/u/p/", "/home/u/p", "/", "//", "~/x/", "rel" },
            Wolfram`Chatbook`ACP`Sessions`Private`samePathQ @@@ {
                { "/home/u/p/", "/home/u/p", True },
                { "/home/u/p", "/home/u/P", True },
                { "/home/u/p", "/home/u/p/q/..", True }
            },
            (* a name with a line break or an invisible character is shown visibly *)
            Lookup[ acpSessionsProjects[ { viewItem[ "x", "/srv/a\nb\:202e", "X", 1 ] }, { }, None, True ], "Name" ]
        }
    ],
    {
        {
            { "/home/u/p", "/", "/srv/gone dir" },
            { "p", "/", "gone dir" },
            { 2, 1, 1 },
            { True, False, False },
            { "/home/u/p", "/home/u/p", "/", "/", "~/x", "rel" },
            { True, False, False },
            { "a\:2424b\:27e6U+202E\:27e7" }
        },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPSessions-Remote-Grouping@@Tests/ACPSessions.wlt:1684,1-1717,2"
]

(* The view of a remote window: no folder is "missing" (none is looked at on this computer), "+" works everywhere, the
   tooltip is the folder on the host, abbreviated with the remote home *)
VerificationTest[
    remoteTrap @ Module[ { k = sessionsKey, v },
        v = view @ remoteViewWindow[ ];
        {
            FreeQ[ v, _Failure | _Missing ],
            containsTextQ[ v, "This folder no longer exists" ],
            buttonEnabled[ v, "ACPSessionsNew-" <> k[ "/srv/gone dir" ] ],
            buttonEnabled[ v, "ACPSessionsNew-" <> k[ "/" ] ],
            MemberQ[ boxStrings @ v, "~/p on devbox" ],
            MemberQ[ boxStrings @ v, "/srv/gone dir on devbox" ],
            containsTextQ[ v, "Remote one" ] && containsTextQ[ v, "Remote two" ]
        }
    ],
    { { True, False, True, True, True, True, True }, { } },
    SameTest -> MatchQ,
    TestID   -> "ACPSessions-Remote-NoMissing@@Tests/ACPSessions.wlt:1721,1-1737,2"
]

(* No "open folder" for a remote window's folders (not on this computer): no button, and the action does nothing *)
VerificationTest[
    Module[ { k = sessionsKey, log = { }, v, result },
        v = view @ remoteViewWindow[ ];
        result = Block[
            {
                $acpWindows        = <| $viewNB -> remoteViewWindow[ ] |>,
                acpEnsurePublisher = Null &,
                acpCheckSession    = True &,
                acpReviewOpenFile  = (AppendTo[ log, { "OpenFile", ## } ]; Null) &
            },
            Wolfram`Chatbook`Common`acpAction[ "SessionsOpenFolder", $viewNB, k[ "/home/u/p" ] ]
        ];
        {
            Select[ boxIDs @ v, StringStartsQ[ "ACPSessionsOpenFolder-" ] ],
            Length @ Select[ boxIDs @ view @ viewWindow[ ], StringStartsQ[ "ACPSessionsOpenFolder-" ] ] > 0,
            result,
            log
        }
    ],
    { { }, True, Missing[ "Remote" ], { } },
    SameTest -> MatchQ,
    TestID   -> "ACPSessions-Remote-NoOpenFolder@@Tests/ACPSessions.wlt:1740,1-1762,2"
]

(* The header names the host; the view's signature follows the host and the remote home *)
VerificationTest[
    Module[ { v = view @ remoteViewWindow[ ] },
        {
            MemberQ[ boxStrings @ v, "OpenCode on devbox" ],
            MemberQ[ boxStrings @ view @ viewWindow[ ], "OpenCode" ],
            viewSignature @ remoteViewWindow[ ] =!= viewSignature @ remoteViewWindow[ <| "RemoteHome" -> "/home/v" |> ],
            viewSignature @ remoteViewWindow[ ] =!= viewSignature @ remoteViewWindow[ <| "Settings" -> <| "SSHSettings" -> <| $remoteSSH, "MachineName" -> "other" |> |> |> ],
            viewSignature @ remoteViewWindow[ ] === viewSignature @ remoteViewWindow[ <| "LastActivity" -> 1 |> ]
        }
    ],
    { True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPSessions-Remote-Header@@Tests/ACPSessions.wlt:1765,1-1778,2"
]

(* Restoring a session (or "+") in another folder of a remote window: the listed cwd is kept exactly ("Raw": a folder
   name may end in a space) and never looked at on this computer; a cwd that is not a remote folder path is refused
   with a notice; the window's own folder (with or without "/" at the end) is the same folder *)
VerificationTest[
    remoteTrap @ Module[ { nbo = NotebookObject[ "acp-sessions-remote" ], log = { }, window, results },
        window = <|
            Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, "/home/u/p", "OpenCode", <| "SSHSettings" -> $remoteSSH |> ],
            "Status"     -> "Ready",
            "SessionID"  -> "cur",
            "RemoteHome" -> "/home/u"
        |>;
        results = Block[
            {
                $acpWindows                = <| nbo -> window |>,
                acpPublish                 = Null &,
                acpEnsurePublisher         = Null &,
                acpChangeProjectDirectory  = (AppendTo[ log, { "Change", ## } ]; #2) &,
                acpSetNotice               = (AppendTo[ log, { "Notice", ## } ]; Null) &,
                acpNewChat                 = (AppendTo[ log, { "NewChat", ## } ]; Null) &
            },
            {
                acpRestoreSession[ nbo, "s1", "/home/u/q " ],
                acpRestoreSession[ nbo, "s2", "/home/u/a\nb" ],
                acpRestoreSession[ nbo, "s3", "relative" ],
                acpNewSessionIn[ nbo, "/home/u/q " ],
                acpNewSessionIn[ nbo, "/home/u/p/" ],
                acpNewSessionIn[ nbo, "~bob/x" ]
            }
        ];
        { results, log }
    ],
    {
        {
            {
                "Restoring",
                Failure[ "InvalidFolder", <| "Cwd" -> "/home/u/a\nb" |> ],
                Failure[ "InvalidFolder", <| "Cwd" -> "relative" |> ],
                "New",
                "New",
                Failure[ "InvalidFolder", <| "Cwd" -> "~bob/x" |> ]
            },
            {
                { "Change", _NotebookObject, "/home/u/q ", <| "PendingRestore" -> <| "SessionID" -> "s1", "Cwd" -> "/home/u/q " |>, "Raw" -> True |> },
                { "Notice", _NotebookObject, "/home/u/a\:2424b is not a folder path on u@devbox.example.com: it must start with / or ~/." },
                { "Notice", _NotebookObject, "relative is not a folder path on u@devbox.example.com: it must start with / or ~/." },
                { "Change", _NotebookObject, "/home/u/q ", <| "Raw" -> True |> },
                { "NewChat", _NotebookObject },
                { "Notice", _NotebookObject, _String }
            }
        },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPSessions-Remote-Restore@@Tests/ACPSessions.wlt:1783,1-1834,2"
]

(* Replayed turns of a remote window carry its host ("Remote"): a file link of the agent is shown with its path on the
   host, not as a link to a file on this computer *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-sessions-remote-replay" ], window, restore, job, cells },
        window  = <|
            Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, "/home/u/p", "OpenCode", <| "SSHSettings" -> $remoteSSH |> ],
            "RemoteHome" -> "/home/u"
        |>;
        restore = Fold[
            acpReplayAppend[ #1, #2, 1.0 ] &,
            acpNewRestore @ <| "SessionID" -> "s1", "Token" -> "t1" |>,
            {
                userChunk[ "u1", "Where is it?" ],
                <| "sessionUpdate" -> "agent_message_chunk", "messageId" -> "a1", "content" -> <| "type" -> "text", "text" -> "Here:" |> |>,
                <| "sessionUpdate" -> "agent_message_chunk", "messageId" -> "a1", "content" -> <| "type" -> "resource_link", "uri" -> "file:///home/u/p/notes.md", "name" -> "notes.md" |> |>
            }
        ];
        job   = Wolfram`Chatbook`ACP`Sessions`Private`restoreNewJob[ nbo, window, restore ];
        cells = Wolfram`Chatbook`ACP`Sessions`Private`restoreTurnCells[ job, 1 ];
        {
            job[ "Remote" ],
            containsTextQ[ cells, "On u@devbox.example.com: /home/u/p/notes.md" ],
            FreeQ[ cells, _ButtonBox | TemplateBox[ _, "HyperlinkURL" | "HyperlinkDefault", ___ ] ],
            Lookup[ Wolfram`Chatbook`ACP`Sessions`Private`restoreNewJob[ nbo, <| window, "Settings" -> <| |> |>, restore ], "Remote" ]
        }
    ],
    { <| "Host" -> "u@devbox.example.com", "Short" -> "devbox", "Home" -> "/home/u" |>, True, True, None },
    SameTest -> MatchQ,
    TestID   -> "ACPSessions-Remote-ReplayTurn@@Tests/ACPSessions.wlt:1838,1-1865,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Connection Tests*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Listing*)
VerificationTest[
    ifConnTests[
        $mockProcessScenario = "cb-sessions";
        $w1 = newWindow[ $project1, <| "ACPModel" -> "m2" |> ];
        { connectWindow @ $w1, acpWindowGet[ $w1, "SessionID" ], currentOption[ $w1, "model" ], acpSessionsOf[ $w1 ][ "Status" ] }
    ],
    Missing[ "TestSkipped" ] | { True, "sess-1", "m2", "Idle" },
    SameTest -> MatchQ,
    TestID   -> "List-Connect@@Tests/ACPSessions.wlt:1874,1-1883,2"
]

(* Opening the Sessions window lists every folder's sessions: no cwd, pages followed by their cursor until an empty page
   (OpenCode sends a cursor on the last non-empty page too) *)
VerificationTest[
    ifConnTests @ Module[ { requests },
        acpSessionsOpened @ $w1;
        waitUntil[ acpSessionsOf[ $w1 ][ "Status" ] === "Ready" ];
        requests = mockRequestsIn[ lastLog[ ], "session/list" ];
        {
            Length @ requests,
            Lookup[ requests, "params" ][[ 1 ]],
            AllTrue[ Rest @ Lookup[ requests, "params" ], MatchQ[ <| "cursor" -> _String |> ] ],
            StringStartsQ[ #, "cb-" ] & /@ Lookup[ requests, "id" ],
            Lookup[ acpSessionsOf[ $w1 ][ "Items" ], "SessionID" ],
            Lookup[ acpSessionsOf[ $w1 ][ "Items" ], "Hidden" ],
            KeyTake[ acpSessionsOf @ $w1, { "Open", "Stale", "Error", "Token", "Partial" } ],
            NumberQ @ acpSessionsOf[ $w1 ][ "ListedAt" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        4,
        <| |>,
        True,
        { True, True, True, True },
        { "sess-1", "ses_b1", "ses_child", "ses_a1", "ses_a2", "ses_c1" },
        { True, False, True, False, True, False },
        <| "Open" -> True, "Stale" -> False, "Error" -> None, "Token" -> None, "Partial" -> { } |>,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "List-Paging@@Tests/ACPSessions.wlt:1887,1-1915,2"
]

VerificationTest[
    ifConnTests @ Module[ { projects = acpSessionsProjects @ acpWindowGet @ $w1 },
        {
            Lookup[ projects, "Cwd" ],
            Lookup[ projects, "Current" ],
            Map[ #[ "SessionID" ] &, Lookup[ projects, "Sessions" ], { 2 } ],
            (* the current session is shown although it was never used *)
            projects[[ 1, "Sessions", 1, "Current" ]]
        }
    ],
    Missing[ "TestSkipped" ] | {
        { $project1, $project2, $project3 },
        { True, False, False },
        { { "sess-1", "ses_a1" }, { "ses_b1" }, { "ses_c1" } },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "List-Projects@@Tests/ACPSessions.wlt:1917,1-1935,2"
]

(* Listings only happen while the Sessions window is open; a turn's end lists now and once more later *)
VerificationTest[
    ifConnTests @ Module[ { log = lastLog[ ], n0, n1, n2, n3 },
        acpSessionsClosed @ $w1;
        n0 = listingsIn @ log;
        acpSessionsMarkStale @ $w1;
        Pause[ 1.5 ];
        n1 = listingsIn @ log;
        acpSessionsOpened @ $w1;
        waitUntil[ listingsIn @ log === n1 + 1 && acpSessionsOf[ $w1 ][ "Status" ] === "Ready" ];
        n2 = listingsIn @ log;
        (* long enough for the first listing to finish before the second is due (otherwise they coalesce) *)
        Block[ { Wolfram`Chatbook`ACP`Sessions`Private`$acpSessionsRecheckDelay = 3 },
            acpSessionsNoteTurnEnd @ $w1
        ];
        waitUntil[ listingsIn @ log >= n2 + 2, 15 ];
        n3 = listingsIn @ log;
        { n1 - n0, n2 - n1, n3 - n2, waitUntil[ acpSessionsOf[ $w1 ][ "Status" ] === "Ready" ], acpSessionsOf[ $w1 ][ "RecheckAt" ] }
    ],
    Missing[ "TestSkipped" ] | { 0, 1, 2, True, None },
    SameTest -> MatchQ,
    TestID   -> "List-Triggers@@Tests/ACPSessions.wlt:1938,1-1959,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Restore in the Same Folder*)

(* session/load with the listed cwd on the window's connection; the replay becomes four turns (user cell + final cell
   each); the session that was left is closed; the restored session keeps its own config (no set_config_option); its ID
   is the resumable one (record and TaggingRules) *)
VerificationTest[
    ifConnTests @ Module[ { log = lastLog[ ], configBefore, result, load },
        configBefore = Length @ mockRequestsIn[ log, "session/set_config_option" ];
        $feSets = { };
        result = acpRestoreSession[ $w1, "ses_a1", $project1 ];
        {
            result,
            acpWindowGet[ $w1, "Status" ],
            waitUntil @ restoredQ @ $w1,
            load = Lookup[ mockRequestsIn[ log, "session/load" ], "params" ],
            acpWindowGet[ $w1, "SessionID" ],
            acpWindowGet[ $w1, "ResumableSessionID" ],
            waitUntil @ MemberQ[ $feSets, { $w1, "ResumableSessionID", "ses_a1" } ],
            Lookup[ mockRequestsIn[ log, "session/close" ], "params" ],
            Length @ mockRequestsIn[ log, "session/set_config_option" ] - configBefore,
            acpWindowGet[ $w1, "ConfigOptions" ] === $mockConfigOptions,
            currentOption[ $w1, "model" ],
            acpWindowGet[ $w1, "SessionOrigin" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        "Restoring",
        "Restoring",
        True,
        { KeyValuePattern @ { "sessionId" -> "ses_a1", "cwd" -> $project1, "mcpServers" -> { } } },
        "ses_a1",
        "ses_a1",
        True,
        { <| "sessionId" -> "sess-1" |> },
        0,
        True,
        "m1",
        "Loaded"
    },
    SameTest -> MatchQ,
    TestID   -> "Restore-SameFolder@@Tests/ACPSessions.wlt:1968,1-2004,2"
]

VerificationTest[
    ifConnTests @ Module[ { cells = Lookup[ $restoreWrites, $w1, { } ] },
        {
            Lookup[ $restoreClears, $w1, 0 ],
            #[[ 2 ]] & /@ cells,
            containsTextQ[ cells[[ 1 ]], "First question" ],
            containsTextQ[ cells[[ 3 ]], "Second question" ] && containsTextQ[ cells[[ 3 ]], "[notes.md]" ],
            containsTextQ[ cells[[ 2 ]], "Worked" ] && containsTextQ[ cells[[ 2 ]], "First answer" ],
            containsTextQ[ cells[[ 4 ]], "Thoughts" ],
            containsTextQ[ cells[[ 6 ]], "No reply." ],
            containsTextQ[ cells[[ 8 ]], "Declined" ],
            containsTextQ[ cells, "Worked for" ] || containsTextQ[ cells, "Thought for" ],
            (* the replay never went to a (missing) current turn *)
            Select[ Internal`BagPart[ $acpDebugLog, All ], #[ "Time" ] >= $acpLogStart && #[ "Where" ] === "UpdateWithoutTurn" && #[ "Data", "SessionID" ] === "ses_a1" & ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        1,
        { "ChatInput", "ChatOutput", "ChatInput", "ChatOutput", "ChatInput", "ChatOutput", "ChatInput", "ChatOutput" },
        True, True, True, True, True, True,
        False,
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "Restore-SameFolder-Cells@@Tests/ACPSessions.wlt:2006,1-2031,2"
]

(* After the restore the list is fetched again; explicit model changes work as before *)
VerificationTest[
    ifConnTests @ Module[ { log = lastLog[ ] },
        acpSetConfigOption[ $w1, "model", "m2" ];
        {
            waitUntil[ currentOption[ $w1, "model" ] === "m2" ],
            Lookup[ Last @ mockRequestsIn[ log, "session/set_config_option" ], "params" ],
            waitUntil[ acpSessionsOf[ $w1 ][ "Status" ] === "Ready" && ! TrueQ @ acpSessionsOf[ $w1 ][ "Stale" ] ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, KeyValuePattern @ { "sessionId" -> "ses_a1", "configId" -> "model", "value" -> "m2" }, True },
    SameTest -> MatchQ,
    TestID   -> "Restore-SameFolder-AfterRestore@@Tests/ACPSessions.wlt:2034,1-2046,2"
]

(* A failed load leaves the window with its session and transcript and shows the error *)
VerificationTest[
    ifConnTests @ Module[ { log = lastLog[ ], clears = Lookup[ $restoreClears, $w1, 0 ], closes },
        closes = Length @ mockRequestsIn[ log, "session/close" ];
        acpRestoreSession[ $w1, "ses_ghost", $project1 ];
        {
            waitUntil @ restoredQ @ $w1,
            acpWindowGet[ $w1, "SessionID" ],
            Lookup[ $restoreClears, $w1, 0 ] - clears,
            Length @ mockRequestsIn[ log, "session/close" ] - closes,
            acpWindowGet[ $w1, "Notice" ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, "ses_a1", 0, 0, _String? (StringStartsQ[ #, "Couldn't open the session: " ] && StringContainsQ[ #, "session not found: ses_ghost" ] &) },
    SameTest -> MatchQ,
    TestID   -> "Restore-SameFolder-Failure@@Tests/ACPSessions.wlt:2049,1-2064,2"
]

(* Restoring the current session does nothing *)
VerificationTest[
    ifConnTests @ { acpRestoreSession[ $w1, "ses_a1", $project1 ], acpWindowGet[ $w1, "Status" ] },
    Missing[ "TestSkipped" ] | { "Current", "Ready" },
    SameTest -> MatchQ,
    TestID   -> "Restore-Current@@Tests/ACPSessions.wlt:2067,1-2072,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Delete*)
VerificationTest[
    ifConnTests @ Module[ { log = lastLog[ ] },
        acpSetNotice[ $w1, None ];
        {
            acpDeleteSession[ $w1, "ses_a1" ],
            acpDeleteSession[ $w1, "ses_never_listed" ],
            waitUntil[ acpSessionsOf[ $w1 ][ "Deleting" ] === <| |> ],
            Lookup[ mockRequestsIn[ log, "session/delete" ], "params" ],
            acpSessionsOf[ $w1 ][ "Notice" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        Failure[ "CurrentSession", <| "SessionID" -> "ses_a1" |> ],
        "Deleting",
        True,
        { <| "sessionId" -> "ses_never_listed" |> },
        None
    },
    SameTest -> MatchQ,
    TestID   -> "Delete-CurrentAndUnknown@@Tests/ACPSessions.wlt:2077,1-2097,2"
]

VerificationTest[
    ifConnTests @ Module[ { log = lastLog[ ], n },
        waitUntil[ acpSessionsOf[ $w1 ][ "Status" ] === "Ready" && ! TrueQ @ acpSessionsOf[ $w1 ][ "Stale" ] ];
        n = listingsIn @ log;
        {
            acpDeleteSession[ $w1, "ses_a2" ],
            waitUntil[ ! MemberQ[ Lookup[ acpSessionsOf[ $w1 ][ "Items" ], "SessionID" ], "ses_a2" ] ],
            (* listed again *)
            waitUntil[ listingsIn @ log > n && acpSessionsOf[ $w1 ][ "Status" ] === "Ready" ],
            MemberQ[ Lookup[ acpSessionsOf[ $w1 ][ "Items" ], "SessionID" ], "ses_a2" ],
            MemberQ[ Lookup[ acpSessionsOf[ $w1 ][ "Items" ], "SessionID" ], "ses_a1" ]
        }
    ],
    Missing[ "TestSkipped" ] | { "Deleting", True, True, False, True },
    SameTest -> MatchQ,
    TestID   -> "Delete-Listed@@Tests/ACPSessions.wlt:2099,1-2115,2"
]

(* An error response becomes the store's notice *)
VerificationTest[
    ifConnTests[
        acpSessionsSet[ $w1, "Deleting", <| "ses_x" -> acpWindowGet[ $w1, "Connection" ] |> ];
        acpSessionsOnDeleteResponse[ $w1, <| "SessionID" -> "ses_x" |>, <| "Error" -> True, "Code" -> -32603, "Message" -> "Internal error" |> ];
        WithCleanup[
            KeyTake[ acpSessionsOf @ $w1, { "Deleting", "Notice" } ],
            acpSessionsSet[ $w1, "Notice", None ]
        ]
    ],
    Missing[ "TestSkipped" ] | <| "Deleting" -> <| |>, "Notice" -> "Couldn't delete the session: Internal error" |>,
    SameTest -> MatchQ,
    TestID   -> "Delete-Error@@Tests/ACPSessions.wlt:2118,1-2130,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Restore From Another Folder*)

(* The project folder changes (a new connection) and the new connection loads the session instead of creating one *)
VerificationTest[
    ifConnTests @ Module[ { oldConn = acpWindowGet[ $w1, "Connection" ], logs = Length @ $mockLogs, log },
        {
            acpRestoreSession[ $w1, "ses_b1", $project2 ],
            acpWindowGet[ $w1, "ProjectDirectory" ],
            waitUntil[ restoredQ @ $w1 && Length @ $mockLogs === logs + 1 ],
            waitUntil[ connectionClosedQ @ oldConn ],
            log = lastLog[ ];
            Lookup[ mockRequestsIn[ log, "session/load" ], "params" ],
            mockRequestsIn[ log, "session/new" ],
            mockRequestsIn[ log, "session/set_config_option" ],
            acpWindowGet[ $w1, "SessionID" ],
            #[[ 2 ]] & /@ Lookup[ $restoreWrites, $w1, { } ],
            containsTextQ[ Lookup[ $restoreWrites, $w1, { } ], "Answer in project 2" ],
            (* the store survives the project switch and lists on the new connection *)
            waitUntil[ listingsIn @ log >= 1 && acpSessionsOf[ $w1 ][ "Status" ] === "Ready" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        "Restoring",
        $project2,
        True,
        True,
        { KeyValuePattern @ { "sessionId" -> "ses_b1", "cwd" -> $project2, "mcpServers" -> { } } },
        { },
        { },
        "ses_b1",
        { "ChatInput", "ChatOutput" },
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Restore-OtherFolder@@Tests/ACPSessions.wlt:2137,1-2170,2"
]

(* If the load fails there, the window falls back to a new session in that folder and shows the error *)
VerificationTest[
    ifConnTests @ Module[ { logs = Length @ $mockLogs, log },
        {
            acpRestoreSession[ $w1, "ses_ghost", $project1 ],
            waitUntil[ restoredQ @ $w1 && Length @ $mockLogs === logs + 1 && StringQ @ acpWindowGet[ $w1, "SessionID" ] ],
            log = lastLog[ ];
            Lookup[ mockRequestsIn[ log, "session/load" ], "params" ],
            Lookup[ mockRequestsIn[ log, "session/new" ], "params" ],
            acpWindowGet[ $w1, "ProjectDirectory" ],
            acpWindowGet[ $w1, "SessionID" ],
            acpWindowGet[ $w1, "Notice" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        "Restoring",
        True,
        { KeyValuePattern @ { "sessionId" -> "ses_ghost", "cwd" -> $project1, "mcpServers" -> { } } },
        { KeyValuePattern @ { "cwd" -> $project1, "mcpServers" -> { } } },
        $project1,
        "sess-1",
        _String? (StringContainsQ[ "session not found: ses_ghost" ])
    },
    SameTest -> MatchQ,
    TestID   -> "Restore-OtherFolder-Failure@@Tests/ACPSessions.wlt:2173,1-2197,2"
]

(* A session whose folder no longer exists can't be restored *)
VerificationTest[
    ifConnTests @ {
        acpRestoreSession[ $w1, "ses_c1", $project3 ],
        acpWindowGet[ $w1, "ProjectDirectory" ],
        StringStartsQ[ acpWindowGet[ $w1, "Notice" ], "The folder of this session no longer exists: " ]
    },
    Missing[ "TestSkipped" ] | { Failure[ "FolderMissing", _ ], $project1, True },
    SameTest -> MatchQ,
    TestID   -> "Restore-FolderMissing@@Tests/ACPSessions.wlt:2200,1-2209,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*New Session in a Folder*)
VerificationTest[
    ifConnTests @ Module[ { calls = { }, same, logs = Length @ $mockLogs, log },
        same = Block[ { acpNewChat = (AppendTo[ calls, { ## } ]; Null) & }, acpNewSessionIn[ $w1, $project1 <> "/" ] ];
        {
            same,
            calls,
            acpNewSessionIn[ $w1, $project2 ],
            waitUntil[ acpWindowGet[ $w1, "Status" ] === "Ready" && Length @ $mockLogs === logs + 1 && StringQ @ acpWindowGet[ $w1, "SessionID" ] ],
            log = lastLog[ ];
            Lookup[ mockRequestsIn[ log, "session/new" ], "params" ],
            mockRequestsIn[ log, "session/load" ],
            acpWindowGet[ $w1, "ProjectDirectory" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        "New",
        { { $w1 } },
        "New",
        True,
        { KeyValuePattern @ { "cwd" -> $project2, "mcpServers" -> { } } },
        { },
        $project2
    },
    SameTest -> MatchQ,
    TestID   -> "NewSessionIn@@Tests/ACPSessions.wlt:2214,1-2239,2"
]

VerificationTest[
    ifConnTests @ Module[ { conn = acpWindowGet[ $w1, "Connection" ] },
        acpDisconnect[ $w1, "Test" ];
        {
            waitUntil[ connectionClosedQ @ conn ],
            (* without a connection the store says so (housekeeping, while the Sessions window is open) *)
            waitUntil[ acpSessionsOf[ $w1 ][ "Status" ] === "NotConnected" ],
            acpSessionsList @ $w1
        }
    ],
    Missing[ "TestSkipped" ] | { True, True, "NotConnected" },
    SameTest -> MatchQ,
    TestID   -> "List-NotConnected@@Tests/ACPSessions.wlt:2241,1-2254,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Slow Loads*)

(* A load whose replay takes seconds: the window is "Restoring" (actions refused) until the turns are written *)
VerificationTest[
    ifConnTests[
        writeScenario[ "cb-sessions-slow", <|
            "description" -> "Chatbook ACPSessions.wlt: session/load replays slowly (0.3 s per update), then waits 4 s before responding",
            "agent"   -> <| "histories" -> <| "ses_s1" -> $historyA, "ses_s3" -> $historyA |> |>,
            "methods" -> <| "session/load" -> <| "steps" -> {
                <| "type" -> "replay", "interval" -> 0.3 |>,
                <| "type" -> "delay", "seconds" -> 4 |>,
                <| "type" -> "respond", "result" -> <| "configOptions" -> $mockConfigOptions |> |>
            } |> |>
        |> ];
        $mockProcessScenario = "cb-sessions-slow";
        $w2 = newWindow @ $project1;
        connectWindow @ $w2;
        {
            acpRestoreSession[ $w2, "ses_s1", $project1 ],
            waitUntil[ acpWindowGet[ $w2, "Restore" ][ "Count" ] >= 2 ],
            acpWindowGet[ $w2, "Status" ],
            acpRestoreSession[ $w2, "ses_s2", $project1 ],
            acpNewSessionIn[ $w2, $project2 ],
            acpSessionsBusyState @ acpWindowGet @ $w2,
            waitUntil[ restoredQ @ $w2, 20 ],
            acpWindowGet[ $w2, "SessionID" ],
            Count[ Lookup[ $restoreWrites, $w2, { } ], Cell[ __, "ChatOutput", ___ ] ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        "Restoring",
        True,
        "Restoring",
        Failure[ "Busy", <| "Reason" -> "Restoring" |> ],
        Failure[ "Busy", <| "Reason" -> "Restoring" |> ],
        "Restoring",
        True,
        "ses_s1",
        4
    },
    SameTest -> MatchQ,
    TestID   -> "SlowLoad-Restoring@@Tests/ACPSessions.wlt:2261,1-2300,2"
]

(* The load timeout counts from the last replayed update: a long replay is not cut off, a load that stalls after it is *)
VerificationTest[
    ifConnTests @ Module[ { timeoutVar = Wolfram`Chatbook`ACP`Connection`Private`$acpSessionLoadTimeout, sent, failedAt, lastUpdate, result },
        WithCleanup[
            Wolfram`Chatbook`ACP`Connection`Private`$acpSessionLoadTimeout = 1.5,
            sent = AbsoluteTime[ ];
            acpRestoreSession[ $w2, "ses_s3", $project1 ];
            (* the replay takes about 4 s, longer than the timeout *)
            waitUntil[ acpWindowGet[ $w2, "Restore" ][ "Count" ] >= 13, 10 ];
            lastUpdate = acpWindowGet[ $w2, "Restore" ][ "LastUpdateAt" ];
            result = waitUntil[ acpWindowGet[ $w2, "Restore" ] === None, 10 ];
            failedAt = AbsoluteTime[ ];
            {
                lastUpdate - sent > 3,
                result,
                failedAt - lastUpdate >= 1.5,
                acpWindowGet[ $w2, "SessionID" ],
                acpWindowGet[ $w2, "Status" ],
                acpWindowGet[ $w2, "Notice" ]
            },
            Wolfram`Chatbook`ACP`Connection`Private`$acpSessionLoadTimeout = timeoutVar
        ]
    ],
    Missing[ "TestSkipped" ] | { True, True, True, "ses_s1", "Ready", "Couldn't open the session: Mock ACP Agent didn't respond in time." },
    SameTest -> MatchQ,
    TestID   -> "SlowLoad-TimeoutFromLastUpdate@@Tests/ACPSessions.wlt:2303,1-2328,2"
]

(* The load that timed out gets its response late: the agent attached the session after all, so it is closed again
   (the request was kept as "AbandonedLoad"); the window stays on its session *)
VerificationTest[
    ifConnTests @ Module[ { conn = acpWindowGet[ $w2, "Connection" ], log = lastLog[ ] },
        {
            waitUntil[ MemberQ[ Lookup[ mockRequestsIn[ log, "session/close" ], "params" ], <| "sessionId" -> "ses_s3" |> ], 10 ],
            acpWindowGet[ $w2, "SessionID" ],
            Count[ Values @ acpWindowGet[ $w2, "Requests" ], KeyValuePattern[ "Kind" -> "AbandonedLoad" ] ],
            AnyTrue[ Internal`BagPart[ $acpDebugLog, All ], #[ "Time" ] >= $acpLogStart && #[ "Where" ] === "AbandonedLoadResponse" & ],
            acpDisconnect[ $w2, "Test" ];
            waitUntil[ connectionClosedQ @ conn ],
            acpWindowGet[ $w2, "SessionID" ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, "ses_s1", 0, True, True, None },
    SameTest -> MatchQ,
    TestID   -> "SlowLoad-AbandonedClosed@@Tests/ACPSessions.wlt:2332,1-2347,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Timeouts and Races*)

(* A session/load that times out while connecting (restore from another folder) falls back to a new session there, like
   an error response; its late response closes the session again *)
VerificationTest[
    ifConnTests[
        writeScenario[ "cb-sessions-stall", <|
            "description" -> "Chatbook ACPSessions.wlt: session/load replays and answers 3 s later; session/list and session/delete answer after 3 s",
            "agent" -> <|
                "strictSessions" -> True,
                "sessions"       -> {
                    <| "sessionId" -> "ses_a1", "cwd" -> $project1, "title" -> "Add stdev", "updatedAt" -> "2026-10-10T10:00:00.000Z" |>,
                    <| "sessionId" -> "ses_b1", "cwd" -> $project2, "title" -> "Refactor calc", "updatedAt" -> "2026-10-10T12:00:00.000Z" |>
                },
                "histories"      -> <| "ses_b1" -> { userChunk[ "msg_b1", "Question in project 2" ], agentChunk[ "msg_b2", "Answer in project 2" ] } |>
            |>,
            "methods" -> <|
                "session/load"   -> <| "steps" -> {
                    <| "type" -> "replay" |>,
                    <| "type" -> "delay", "seconds" -> 3 |>,
                    <| "type" -> "respond", "result" -> <| "configOptions" -> $mockConfigOptions |> |>
                } |>,
                "session/list"   -> <| "steps" -> { <| "type" -> "delay", "seconds" -> 3 |>, <| "type" -> "respond", "result" -> <| "sessions" -> { } |> |> } |>,
                "session/delete" -> <| "steps" -> { <| "type" -> "delay", "seconds" -> 3 |>, <| "type" -> "respond", "result" -> <| |> |> } |>
            |>
        |> ];
        $mockProcessScenario = "cb-sessions-stall";
        $w7 = newWindow[ $project1, <| "ACPModel" -> "m1" |> ];
        connectWindow @ $w7;
        Module[ { timeoutVar = Wolfram`Chatbook`ACP`Connection`Private`$acpSessionLoadTimeout, logs = Length @ $mockLogs, log },
            WithCleanup[
                Wolfram`Chatbook`ACP`Connection`Private`$acpSessionLoadTimeout = 1.5,
                {
                    acpRestoreSession[ $w7, "ses_b1", $project2 ],
                    waitUntil[ Length @ $mockLogs === logs + 1 && restoredQ @ $w7 && StringQ @ acpWindowGet[ $w7, "SessionID" ], 20 ],
                    log = lastLog[ ];
                    Lookup[ mockRequestsIn[ log, "session/load" ], "params" ],
                    Lookup[ mockRequestsIn[ log, "session/new" ], "params" ],
                    acpWindowGet[ $w7, { "ProjectDirectory", "SessionID", "Notice", "Error" } ],
                    waitUntil[ MemberQ[ Lookup[ mockRequestsIn[ log, "session/close" ], "params" ], <| "sessionId" -> "ses_b1" |> ], 10 ],
                    acpWindowGet[ $w7, "SessionID" ]
                },
                Wolfram`Chatbook`ACP`Connection`Private`$acpSessionLoadTimeout = timeoutVar
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | {
        "Restoring",
        True,
        { KeyValuePattern @ { "sessionId" -> "ses_b1", "cwd" -> $project2 } },
        { KeyValuePattern @ { "cwd" -> $project2 } },
        { $project2, "sess-1", "Couldn't open the session: Mock ACP Agent didn't respond in time.", None },
        True,
        "sess-1"
    },
    SameTest -> MatchQ,
    TestID   -> "SetupLoad-TimeoutFallsBack@@Tests/ACPSessions.wlt:2355,1-2408,2"
]

(* session/list and session/delete that get no response in time: the listing fails with a timeout error, the delete
   with a notice *)
VerificationTest[
    ifConnTests @ Module[ { vars, saved },
        vars  = { Wolfram`Chatbook`ACP`Connection`Private`$acpSessionListTimeout, Wolfram`Chatbook`ACP`Connection`Private`$acpSessionDeleteTimeout };
        saved = vars;
        WithCleanup[
            Wolfram`Chatbook`ACP`Connection`Private`$acpSessionListTimeout   = 1;
            Wolfram`Chatbook`ACP`Connection`Private`$acpSessionDeleteTimeout = 1,
            acpSetNotice[ $w7, None ];
            acpSessionsOpened @ $w7;
            {
                waitUntil[ acpSessionsOf[ $w7 ][ "Status" ] === "Error", 10 ],
                acpSessionsOf[ $w7 ][ "Error" ],
                acpSessionsClosed @ $w7;
                acpDeleteSession[ $w7, "ses_a1" ],
                waitUntil[ acpSessionsOf[ $w7 ][ "Deleting" ] === <| |>, 10 ],
                acpSessionsOf[ $w7 ][ "Notice" ]
            },
            { Wolfram`Chatbook`ACP`Connection`Private`$acpSessionListTimeout, Wolfram`Chatbook`ACP`Connection`Private`$acpSessionDeleteTimeout } = saved
        ]
    ],
    Missing[ "TestSkipped" ] | {
        True,
        <| "Code" -> "Timeout", "Message" -> "Mock ACP Agent didn't respond in time." |>,
        "Deleting",
        True,
        "Couldn't delete the session: Mock ACP Agent didn't respond in time."
    },
    SameTest -> MatchQ,
    TestID   -> "ListAndDelete-Timeouts@@Tests/ACPSessions.wlt:2412,1-2441,2"
]

(* A delete whose connection goes away before the response (here: Reconnect) is forgotten, so the session doesn't stay
   "Deleting..." for good, and it can be deleted again on the new connection *)
VerificationTest[
    ifConnTests @ Module[ { logs, log },
        Pause[ 3 ]; (* the late responses of the previous test *)
        acpSessionsSet[ $w7, "Notice", None ];
        logs = Length @ $mockLogs;
        {
            acpDeleteSession[ $w7, "ses_a1" ],
            Keys @ acpSessionsOf[ $w7 ][ "Deleting" ],
            acpReconnect @ $w7;
            waitUntil[ Length @ $mockLogs === logs + 1 && acpWindowGet[ $w7, "Status" ] === "Ready" ],
            waitUntil[ acpSessionsOf[ $w7 ][ "Deleting" ] === <| |>, 5 ],
            AnyTrue[ Internal`BagPart[ $acpDebugLog, All ], #[ "Time" ] >= $acpLogStart && #[ "Where" ] === "SessionDeleteDropped" & ],
            acpDeleteSession[ $w7, "ses_a1" ],
            log = lastLog[ ];
            waitUntil[ Length @ mockRequestsIn[ log, "session/delete" ] === 1 ],
            waitUntil[ acpSessionsOf[ $w7 ][ "Deleting" ] === <| |>, 10 ],
            acpSessionsOf[ $w7 ][ "Notice" ]
        }
    ],
    Missing[ "TestSkipped" ] | { "Deleting", { "ses_a1" }, True, True, True, "Deleting", True, True, None },
    SameTest -> MatchQ,
    TestID   -> "Delete-ConnectionReplaced@@Tests/ACPSessions.wlt:2445,1-2467,2"
]

VerificationTest[
    ifConnTests @ Module[ { conn = acpWindowGet[ $w7, "Connection" ] },
        acpDisconnect[ $w7, "Test" ];
        $mockProcessScenario = None;
        waitUntil[ connectionClosedQ @ conn ]
    ],
    Missing[ "TestSkipped" ] | True,
    SameTest -> MatchQ,
    TestID   -> "TimeoutsAndRaces-Disconnect@@Tests/ACPSessions.wlt:2469,1-2478,2"
]

(* A model change for the session that is left, still waiting for its response when a restore starts, is neither
   applied to the restored session nor allowed to overwrite its options when the response comes (constraint: a restored
   session keeps its own config); the choice is still remembered. $FrontEnd = Null: the persisted settings are the
   headless ones (restored afterwards) also when the tests run under a front end; under UsingFrontEnd the choice written
   by the pump was not read back from the front end's preferences. *)
VerificationTest[
    ifConnTests @ Block[
        {
            $FrontEnd = Null,
            Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings = Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings
        },
        writeScenario[ "cb-sessions-slow-config", <|
            "description" -> "Chatbook ACPSessions.wlt: session/set_config_option answers after 2 s (always model m2, mode plan)",
            "agent" -> <|
                "strictSessions" -> True,
                "sessions"       -> { <| "sessionId" -> "ses_a1", "cwd" -> $project1, "title" -> "Add stdev", "updatedAt" -> "2026-10-10T10:00:00.000Z" |> },
                "histories"      -> <| "ses_a1" -> $historyA |>
            |>,
            "methods" -> <| "session/set_config_option" -> <| "steps" -> {
                <| "type" -> "delay", "seconds" -> 2 |>,
                <| "type" -> "respond", "result" -> <| "configOptions" -> ReplacePart[ $mockConfigOptions, { { 1, "currentValue" } -> "m2", { 3, "currentValue" } -> "plan" } ] |> |>
            } |> |>
        |> ];
        $mockProcessScenario = "cb-sessions-slow-config";
        $w8 = newWindow[ $project1, <| "ACPModel" -> "m1" |> ];
        connectWindow @ $w8;
        Module[ { log = lastLog[ ], configBefore },
            configBefore = Length @ mockRequestsIn[ log, "session/set_config_option" ];
            WithCleanup[
                {
                    acpSetConfigOption[ $w8, "model", "m2" ],
                    acpRestoreSession[ $w8, "ses_a1", $project1 ],
                    waitUntil[ restoredQ @ $w8, 15 ],
                    (* the response for sess-1 *)
                    waitUntil[ FreeQ[ Values @ acpWindowGet[ $w8, "Requests" ], KeyValuePattern[ "Kind" -> "SetConfig" ] ], 10 ],
                    Pause[ 0.5 ];
                    Lookup[ Drop[ mockRequestsIn[ log, "session/set_config_option" ], configBefore ], "params" ],
                    acpWindowGet[ $w8, "SessionID" ],
                    { currentOption[ $w8, "model" ], currentOption[ $w8, "mode" ] },
                    acpWindowGet[ $w8, "PendingConfig" ],
                    waitUntil[ acpPersistedSetting[ { "LastModel", "MockACPAgent" } ] === "m2" ],
                    AnyTrue[ Internal`BagPart[ $acpDebugLog, All ], #[ "Time" ] >= $acpLogStart && #[ "Where" ] === "StaleConfigResponse" & ]
                },
                acpDisconnect[ $w8, "Test" ];
                $mockProcessScenario = None
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | {
        "Sent",
        "Restoring",
        True,
        True,
        { <| "sessionId" -> "sess-1", "configId" -> "model", "value" -> "m2" |> },
        "ses_a1",
        { "m1", "build" },
        <| |>,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Restore-PendingConfigOfLeftSession@@Tests/ACPSessions.wlt:2485,1-2542,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Listing Edge Cases*)

(* At most 20 pages per listing *)
VerificationTest[
    ifConnTests[
        writeScenario[ "cb-sessions-many", <|
            "description" -> "Chatbook ACPSessions.wlt: 25 sessions, one per page",
            "agent" -> <|
                "listPageSize" -> 1,
                "sessions" -> Table[
                    <| "sessionId" -> "ses_m" <> IntegerString[ i, 10, 2 ], "cwd" -> $project1, "title" -> "Session " <> ToString @ i,
                       "updatedAt" -> DateString[ DateObject[ { 2026, 1, i }, TimeZone -> 0 ], "ISODateTime" ] <> "Z" |>,
                    { i, 25 }
                ]
            |>
        |> ];
        $mockProcessScenario = "cb-sessions-many";
        $w3 = newWindow @ $project1;
        connectWindow @ $w3;
        acpSessionsOpened @ $w3;
        WithCleanup[
            {
                waitUntil[ acpSessionsOf[ $w3 ][ "Status" ] === "Ready", 30 ],
                Length @ mockRequestsIn[ lastLog[ ], "session/list" ],
                Length @ acpSessionsOf[ $w3 ][ "Items" ],
                acpSessionsOf[ $w3 ][ "Items" ][[ 2, "SessionID" ]],
                AnyTrue[ Internal`BagPart[ $acpDebugLog, All ], #[ "Time" ] >= $acpLogStart && #[ "Where" ] === "SessionListCapped" & ]
            },
            acpDisconnect[ $w3, "Test" ]
        ]
    ],
    Missing[ "TestSkipped" ] | { True, 20, 20, "ses_m25", True },
    SameTest -> MatchQ,
    TestID   -> "List-PageCap@@Tests/ACPSessions.wlt:2549,1-2580,2"
]

(* An empty page ends the listing even with a cursor; an error response sets "Error" *)
VerificationTest[
    ifConnTests[
        writeScenario[ "cb-sessions-empty-cursor", <|
            "description" -> "Chatbook ACPSessions.wlt: session/list gives an empty page with a cursor",
            "methods" -> <| "session/list" -> <| "result" -> <| "sessions" -> { }, "nextCursor" -> "more" |> |> |>
        |> ];
        writeScenario[ "cb-sessions-list-error", <|
            "description" -> "Chatbook ACPSessions.wlt: session/list fails",
            "methods" -> <| "session/list" -> <| "error" -> <| "code" -> -32603, "message" -> "Internal error: database locked" |> |> |>
        |> ];
        $mockProcessScenario = "cb-sessions-empty-cursor";
        $w4 = newWindow @ $project1;
        connectWindow @ $w4;
        acpSessionsOpened @ $w4;
        {
            waitUntil[ acpSessionsOf[ $w4 ][ "Status" ] === "Ready" ],
            Length @ mockRequestsIn[ lastLog[ ], "session/list" ],
            acpSessionsOf[ $w4 ][ "Items" ],
            acpDisconnect[ $w4, "Test" ];
            $mockProcessScenario = "cb-sessions-list-error";
            connectWindow @ $w4,
            acpSessionsRefresh @ $w4,
            waitUntil[ acpSessionsOf[ $w4 ][ "Status" ] === "Error" ],
            acpSessionsOf[ $w4 ][ "Error" ],
            acpDisconnect[ $w4, "Test" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        True,
        1,
        { },
        True,
        "Listing",
        True,
        <| "Code" -> -32603, "Message" -> "Couldn't list the sessions: Internal error: database locked" |>,
        Null
    },
    SameTest -> MatchQ,
    TestID   -> "List-EmptyCursorAndError@@Tests/ACPSessions.wlt:2583,1-2622,2"
]

(* An agent that advertises neither list, load nor delete *)
VerificationTest[
    ifConnTests[
        writeScenario[ "cb-sessions-unsupported", <|
            "description" -> "Chatbook ACPSessions.wlt: no session list, load or delete",
            "agent" -> <| "agentCapabilities" -> <| "loadSession" -> False, "sessionCapabilities" -> <| "close" -> <| |>, "resume" -> <| |> |> |> |>
        |> ];
        $mockProcessScenario = "cb-sessions-unsupported";
        $w5 = newWindow @ $project1;
        connectWindow @ $w5;
        WithCleanup[
            {
                acpSessionsOpened @ $w5,
                acpSessionsOf[ $w5 ][ "Status" ],
                acpRestoreSession[ $w5, "ses_a1", $project1 ],
                acpDeleteSession[ $w5, "ses_a2" ],
                acpSessionsCapabilities @ acpWindowGet @ $w5,
                mockRequestsIn[ lastLog[ ], "session/list" ]
            },
            acpDisconnect[ $w5, "Test" ];
            $mockProcessScenario = None
        ]
    ],
    Missing[ "TestSkipped" ] | {
        "Unsupported",
        "Unsupported",
        Failure[ "Unsupported", _ ],
        Failure[ "Unsupported", _ ],
        <| "List" -> False, "Load" -> False, "Delete" -> False, "Close" -> True, "Resume" -> True |>,
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "Unsupported@@Tests/ACPSessions.wlt:2625,1-2657,2"
]

(* A pending restore of a window whose agent can't load sessions continues with a new session and says so *)
VerificationTest[
    ifConnTests[
        $mockProcessScenario = "cb-sessions-unsupported";
        $w6 = newWindow @ $project1;
        acpWindowUpdate[ $w6, <| #, "PendingRestore" -> <| "SessionID" -> "ses_a1", "Cwd" -> $project1 |> |> & ];
        WithCleanup[
            {
                connectWindow @ $w6,
                mockRequestsIn[ lastLog[ ], "session/load" ],
                Length @ mockRequestsIn[ lastLog[ ], "session/new" ],
                acpWindowGet[ $w6, "PendingRestore" ],
                acpWindowGet[ $w6, "Notice" ]
            },
            acpDisconnect[ $w6, "Test" ];
            $mockProcessScenario = None
        ]
    ],
    Missing[ "TestSkipped" ] | { True, { }, 1, None, "Mock ACP Agent can't open saved sessions, so a new session was started." },
    SameTest -> MatchQ,
    TestID   -> "PendingRestore-Unsupported@@Tests/ACPSessions.wlt:2660,1-2680,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    ifConnTests[
        Scan[ acpDisconnect[ #, "TestCleanup" ] &, $windows ];
        Scan[ acpWindowDrop, $windows ];
        {
            waitUntil[ Replace[ Quiet @ ACPConnections[ ], Except[ _List ] -> { } ] === { } ],
            waitUntil[ Wolfram`Chatbook`ACP`State`Private`$publisherTask === None ],
            Wolfram`Chatbook`ACP`Sessions`Private`$restoreJobs,
            Wolfram`Chatbook`ACP`Connection`Private`$ownedConnections
        }
    ],
    Missing[ "TestSkipped" ] | { True, True, <| |>, <| |> },
    SameTest -> MatchQ,
    TestID   -> "Cleanup-NoLeftovers@@Tests/ACPSessions.wlt:2685,1-2699,2"
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
    TestID   -> "Cleanup-DebugLog@@Tests/ACPSessions.wlt:2702,1-2713,2"
]

VerificationTest[
    DownValues[ Wolfram`Chatbook`ACP`Sessions`Private`restoreWriteCells ] = $savedWriteCells;
    DownValues[ Wolfram`Chatbook`ACP`Sessions`Private`restoreClearCells ] = $savedClearCells;
    DownValues[ acpFESet ] = $savedFESet;
    KeyDropFrom[ $acpAgents, "MockACPAgent" ];
    Scan[ acpWindowDrop, $windows ];
    $acpAssumeWindowsOpen = False;
    $acpLLMKitEnabled = True;
    Wolfram`Chatbook`ACP`Transcript`Private`$acpNoFrontEndLabels    = False;
    Wolfram`Chatbook`ACP`Rendering`Private`$acpNoFrontEndFormatting = False;
    Quiet @ DeleteDirectory[ $scratch, DeleteContents -> True ];
    (* Only changed settings are written: with a front end, writing Inherited to an unset {"LastModel", agent} leaves an
       empty "LastModel" in its preferences *)
    KeyValueMap[
        If[ acpPersistedSetting[ #1 ] =!= #2, acpSetPersistedSetting[ #1, Replace[ #2, _Missing -> Inherited ] ] ] &,
        $savedPersisted
    ];
    If[ TrueQ @ $setACPLinkEnv, SetEnvironment[ "ACPLINK_DIRECTORY" -> None ] ];
    {
        KeyExistsQ[ $acpAgents, "MockACPAgent" ],
        DirectoryQ @ $scratch,
        AssociationMap[ acpPersistedSetting, Keys @ $savedPersisted ] === $savedPersisted
    },
    { False, False, True },
    SameTest -> MatchQ,
    TestID   -> "Cleanup-Restore@@Tests/ACPSessions.wlt:2715,1-2741,2"
]

(* :!CodeAnalysis::EndBlock:: *)
