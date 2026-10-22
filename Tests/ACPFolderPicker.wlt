(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ACPFolderPicker.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ACPFolderPicker.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* Tests for the remote folder picker (ACP/FolderPicker.wl; see docs/acp-window.md): the picker's view of listings, its
   pure parts (placement, the notebook, paths), the listings through the fake ssh (Data/ACP/fake-ssh, set up by
   Data/ACP/FakeSSH.wl: no sshd, fake NotebookObjects as ACP windows), navigation, errors, Choose, host switches and the
   views. Tests that use the fake ssh are skipped on Windows or without /bin/sh (ifFakeSSH); the connection after Choose
   and host switches uses the mock agent and is skipped without ACPLink or python (ifConnTests); tests that need
   permission bits are skipped as root (ifPermissionsEnforced). Every test after the definitions runs without a front
   end (headless), also when the test kernel has one (CI runs the tests under UsingFrontEnd): the picker then gives
   "Opened" instead of a window, and persisted settings stay in $headlessSettings (restored by Cleanup-Restore), never
   in the front end's preferences (Cleanup-FrontEndPreferences checks that they are unchanged). *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    Needs[ "Wolfram`Chatbook`ACP`Common`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPFolderPicker-LoadACPContext@@Tests/ACPFolderPicker.wlt:35,1-40,2"
]

(* A test of its own, so that the tests after it are read with the helpers' context on $ContextPath *)
VerificationTest[
    Get @ FileNameJoin @ { DirectoryName @ $TestFileName, "Data", "ACP", "FakeSSH.wl" };
    MemberQ[ $ContextPath, "Wolfram`ChatbookTests`ACPFakeSSH`" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPFolderPicker-LoadFakeSSH@@Tests/ACPFolderPicker.wlt:43,1-49,2"
]

(* Everything that runs processes (RunProcess) is done here, before any ACP connection *)
VerificationTest[
    (* CI runs every test file in one kernel and one context: helpers that other test files define too are cleared
       first, so that none of their definitions is used here *)
    ClearAll[ listingFixture, logSince, newMockLog, newRemoteWindow, newWindow, processRuns, remoteSSH, reuseWindow,
        runShell, withLocalPathTrap ];

    $acpLLMKitEnabled     = False;
    $acpAssumeWindowsOpen = True;
    $savedGitEnabled      = $acpGitEnabled;
    $acpGitEnabled        = False; (* no git checks of connected windows: their ssh calls would add to the counts *)

    $fpContext = "Wolfram`Chatbook`ACP`FolderPicker`Private`";
    fpSymbol[ name_String ] := Symbol[ $fpContext <> name ];
    fpOutcome       = fpSymbol[ "pickerOutcome" ];
    fpEntries       = fpSymbol[ "pickerEntries" ];
    fpStatusView    = fpSymbol[ "pickerStatusView" ];
    fpButtonsView   = fpSymbol[ "pickerButtonsView" ];
    fpListView      = fpSymbol[ "pickerListView" ];
    fpToggleView    = fpSymbol[ "pickerToggleView" ];
    fpStatusSig     = fpSymbol[ "pickerStatusSignature" ];
    fpButtonsSig    = fpSymbol[ "pickerButtonsSignature" ];
    fpListSig       = fpSymbol[ "pickerListSignature" ];
    fpTargetPath    = fpSymbol[ "pickerTargetPath" ];
    fpStartPath     = fpSymbol[ "pickerStartPath" ];
    fpTildeUserQ    = fpSymbol[ "tildeUserQ" ];
    fpPathQ         = fpSymbol[ "pickerPathQ" ];
    fpDefaults      = fpSymbol[ "$pickerDefaults" ];
    fpHousekeeping  = fpSymbol[ "pickerHousekeeping" ];
    fpLostAfter     = fpSymbol[ "pickerLostAfter" ];

    $mockDirectory = FileNameJoin @ { DirectoryName @ $TestFileName, "Data", "ACP", "MockAgent" };
    $mockScript    = FileNameJoin @ { $mockDirectory, "mock_acp_agent.py" };
    $python        = SelectFirst[
        { Environment[ "ACPLINK_TEST_PYTHON" ], "/usr/bin/python3", "/usr/local/bin/python3", "/opt/homebrew/bin/python3" },
        StringQ[ # ] && FileExistsQ[ # ] && ! DirectoryQ[ # ] &,
        None
    ];
    $setACPLinkEnv = False;
    If[ ! StringQ @ Environment[ "ACPLINK_DIRECTORY" ] && DirectoryQ @ FileNameJoin @ { $HomeDirectory, "ACPLink", "ACPLink" },
        SetEnvironment[ "ACPLINK_DIRECTORY" -> FileNameJoin @ { $HomeDirectory, "ACPLink", "ACPLink" } ];
        $setACPLinkEnv = True
    ];

    (* Persisted settings the tests change (headless: Agents.wl's $headlessSettings); restored by Cleanup-Restore *)
    $savedHeadlessSettings = Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings;
    (* The front end's ACP preferences (Agents.wl's $acpPreferencesPath), which no test may change: a write that escapes
       the headless Block goes to the front end's live preferences, which it saves in init.m
       (Cleanup-FrontEndPreferences) *)
    $fePreferencesPath = { PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "ACP" };
    $fePreferences0    = If[ $FrontEnd === Null, None, Quiet @ CurrentValue[ $FrontEnd, $fePreferencesPath ] ];

    (* Anything logged as a message or failure after this point is unexpected (Cleanup-DebugLog) *)
    $acpLogStart = AbsoluteTime[ ];
    $acpConnTestsQ = TrueQ[ StringQ @ $python && FileExistsQ @ $mockScript && acpLinkAvailableQ[ ] && acpLoadACPLink[ ] === True ];
    $procfsQ = $OperatingSystem === "Unix" && DirectoryQ[ "/proc/self" ];

    ifConnTests // ClearAll;
    ifConnTests // Attributes = { HoldFirst };
    ifConnTests[ eval_ ] := If[ TrueQ @ $acpConnTestsQ, eval, Missing[ "TestSkipped" ] ];

    $scratch = CreateDirectory[ ];
    $localProject = CreateDirectory @ FileNameJoin @ { $scratch, "local-project" };
    (* The expected outputs of skipped tests use $home too *)
    $home = "/fake-ssh-unavailable";
    If[ TrueQ @ $fakeSSHAvailableQ,
        fakeSSHSetup @ FileNameJoin @ { $scratch, "fake" };
        $home = $fakeSSH[ "Home" ];
        (* The "remote" home: a project with folders in natural order, a hidden folder, a link, files and a broken link;
           folders to navigate; a deep path; an empty folder; a folder with only files; folders without permissions *)
        RunProcess[
            {
                "/bin/sh", "-c",
                StringJoin[
                    "mkdir -p proj/a2 proj/a10 proj/B proj/.hidden 'proj/with space' other deep/a/b/c/d empty filesonly ",
                    "perm/locked perm/xonly && ln -s a2 proj/link-a2 && ln -s nowhere proj/broken && ",
                    ": > proj/README.md && : > proj/.env && : > proj/notes.txt && : > filesonly/x.txt && : > file.txt && ",
                    "chmod 000 perm/locked && chmod 111 perm/xonly"
                ]
            },
            ProcessDirectory -> $home
        ];
        (* Folders whose names the path field shows display-safe (Go-DisplaySafePrefix) *)
        Scan[
            CreateDirectory[ FileNameJoin @ { $home, "other", #, "src" }, CreateIntermediateDirectories -> True ] &,
            { "a\tb", "rtl\:202ex" }
        ];
        (* Tricky names (the picker's keys and child paths must round-trip them) *)
        $names = CreateDirectory @ FileNameJoin @ { $scratch, "names" };
        $trickyNames = {
            "with space", "it's", "new\nline", "tab\there", "CR\rname", "$dollar", "`tick`", "back\\slash", "dq\"uote",
            "~tilde", "-dash", "*star", "[bracket]", "Alpha2", "alpha", "emoji \|01f680", "\:00fcn\:00efc\:00f6d\:00e9",
            "\:f7c1linear", "rtl\:202eevil", ".hidden", "..dotdot"
        };
        RunProcess[
            Join[ { "/bin/sh", "-c", "cd \"$1\" && shift && for n in \"$@\"; do mkdir -- \"$n\"; done && mkdir \"$(printf 'bad\\377utf8')\" && ln -s Alpha2 link", "sh", $names }, $trickyNames ]
        ];
        $namesTmp = CreateDirectory @ FileNameJoin @ { $scratch, "names-tmp" }
    ];

    $shells = DeleteDuplicatesBy[
        Select[ { { "/bin/sh" }, { "/bin/bash" }, { "/usr/bin/busybox", "sh" }, { "/bin/busybox", "sh" } }, FileExistsQ @ First @ # & ],
        Last
    ];
    $dash = SelectFirst[ { "/bin/dash", "/usr/bin/dash" }, FileExistsQ, "/bin/sh" ];

    (* Runs a shell with arguments in a clean environment, with standard input from a file holding input and standard
       output and error in files: <| "ExitCode", "Output" -> ByteArray, "Error" -> String |> *)
    runShell[ shell_List, args_List, input_String, dir_String, vars_Association: <| |> ] := Module[ { run, in, out, err, code },
        run = CreateDirectory @ FileNameJoin @ { $scratch, "run-" <> CreateUUID[ ] };
        { in, out, err } = FileNameJoin @ { run, # } & /@ { "in", "out", "err" };
        BinaryWrite[ in, StringToByteArray[ input, "UTF-8" ] ];
        Close @ in;
        code = RunProcess[
            Join[ { "/bin/sh", "-c", "exec \"$@\" < \"$CB_IN\" > \"$CB_OUT\" 2> \"$CB_ERR\"", "sh" }, shell, args ],
            "ExitCode",
            ProcessEnvironment -> <| "PATH" -> "/usr/bin:/bin", vars, "CB_IN" -> in, "CB_OUT" -> out, "CB_ERR" -> err |>,
            ProcessDirectory   -> dir
        ];
        <| "ExitCode" -> code, "Output" -> readFileBytes @ out, "Error" -> ByteArray[ readFileBytes @ err ] |>
    ];

    (* Waiting with Pause lets the pump (the runs' polls, the picker's results) run *)
    waitUntil // ClearAll;
    waitUntil // Attributes = { HoldFirst };
    waitUntil[ cond_, timeout_: 30 ] := Module[ { deadline = AbsoluteTime[ ] + timeout },
        While[ ! TrueQ @ cond && AbsoluteTime[ ] < deadline, Pause[ 0.05 ] ];
        TrueQ @ cond
    ];

    (* Evaluates a test without a front end, also when the test kernel has one: acpFolderPickerOpen gives "Opened" (no
       picker window), labels are plain strings, and persisted settings are read and written in $headlessSettings. The
       pump sees the Block while the test waits in it (Pause), so deferred work that is due soon (persisted writes, the
       results of runs) is waited for here, before the front end is back. *)
    headless // ClearAll;
    headless // Attributes = { HoldAll };
    headless[ eval_ ] := Block[ { $FrontEnd = Null },
        With[ { result = eval },
            waitUntil[ Select[ Wolfram`Chatbook`ACP`State`Private`$scheduled, First[ # ] <= SessionTime[ ] + 1 & ] === { }, 5 ];
            result
        ]
    ];

    (* The mock agent (as in ACPConnection.wlt) *)
    $mockLogs = { };
    newMockLog[ ] := With[ { file = FileNameJoin @ { $scratch, "mock-" <> ToString[ Length @ $mockLogs + 1 ] <> ".log" } },
        AppendTo[ $mockLogs, file ];
        file
    ];
    $acpAgents[ "MockACPAgent" ] = <|
        "Name"        -> "MockACPAgent",
        "Executable"  -> $python,
        "Arguments"   :> { $mockScript, "--log", newMockLog[ ], "--idle-timeout", "120", "--max-lifetime", "600" },
        "Environment" -> Inherited
    |>;

    (* Canonical "SSHSettings" of a fake ssh host; without the fake (Windows, no /bin/sh) plain settings, so that the
       tests that never run ssh still see a valid host *)
    remoteSSH[ host_String: "testhost", extra___Rule ] := Wolfram`Chatbook`Common`acpSSHSettings @ If[ AssociationQ @ $fakeSSH,
        fakeSSHSettings[ host, extra ],
        <| "MachineName" -> host, extra |>
    ];

    (* ACP windows without a front end: a record as UI.wl registers it (disconnected, or without a folder) *)
    $windows = { };
    newWindow[ dir_, settings_Association, extra_Association: <| |> ] := With[
        { nbo = NotebookObject[ "acp-picker-test-" <> ToString[ Length @ $windows + 1 ] ] },
        AppendTo[ $windows, nbo ];
        acpWindowUpdate[
            nbo,
            <|
                #,
                Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, dir, "MockACPAgent", settings ],
                "Status" -> If[ StringQ @ dir, "Disconnected", "NoDirectory" ],
                extra
            |> &
        ];
        nbo
    ];
    newRemoteWindow[ dir_, ssh_: Automatic, extra_Association: <| |> ] :=
        newWindow[ dir, <| "SSHSettings" -> Replace[ ssh, Automatic :> remoteSSH[ ] ] |>, extra ];

    pickerOf[ nbo_ ] := acpFolderPickerOf @ acpWindowGet @ nbo;
    listedQ[ nbo_ ] := With[ { s = pickerOf @ nbo }, AssociationQ @ s && s[ "Status" ] =!= "Loading" ];
    waitListed[ nbo_, timeout_: 30 ] := waitUntil[ listedQ @ nbo, timeout ];
    pickerAction[ name_String, nbo_, args___ ] := Wolfram`Chatbook`Common`acpAction[ name, nbo, args ];
    (* An action, then the listing it starts: the store afterwards *)
    navigate[ name_String, nbo_, args___ ] := (pickerAction[ name, nbo, args ]; waitListed @ nbo; pickerOf @ nbo);
    openPicker[ nbo_ ] := (acpFolderPickerOpen @ nbo; waitListed @ nbo; pickerOf @ nbo);
    entryKey[ nbo_, name_String ] := SelectFirst[ pickerOf[ nbo ][ "Entries" ], #[ "Name" ] === name &, <| |> ][ "Key" ];
    sshCalls[ ] := If[ TrueQ @ $fakeSSHAvailableQ, Length @ fakeSSHCalls[ ], 0 ];

    (* The debug log since t0 *)
    logSince[ t0_ ] := Select[ Internal`BagPart[ $acpDebugLog, All ], #[ "Time" ] >= t0 & ];

    (* A store as the picker makes it, with rules *)
    testStore[ rules___ ] := <| fpDefaults, "Open" -> True, "SSH" -> remoteSSH[ ], "HostKey" -> "testhost", "Home" -> "/home/u", rules |>;
    testEntry[ name_String, kind_String: "Folder", rules___ ] := <|
        "Name" -> name, "Kind" -> kind, "Link" -> False, "Locked" -> False, "Hidden" -> StringStartsQ[ name, "." ],
        "Usable" -> True, "Key" -> Wolfram`Chatbook`ACP`FolderPicker`Private`pickerKey @ name, rules
    |>;
    (* A listing result of the runner with a "list" frame *)
    listResult[ bytes_ByteArray ] := <|
        "Status" -> "OK", "Frames" -> <| "list" -> <| "Output" -> bytes, "Error" -> ByteArray[ { } ] |> |>, "Stop" -> None,
        "ExitCode" -> 0, "Error" -> None, "Host" -> "testhost", "Duration" -> 0.1
    |>;
    listingFixture[ name_String ] := readFileBytes @ FileNameJoin @ { DirectoryName @ $TestFileName, "Data", "ACP", "RemoteListing", name <> ".bin" };

    (* Strings and the ACP actions of an expression (a view) *)
    stringsIn[ expr_ ] := Cases[ expr, s_String :> s, Infinity ];
    actionsIn[ expr_ ] := Cases[ expr, HoldPattern[ _[ "ACP", a_String, ___ ] ] :> a, Infinity, Heads -> True ];
    textQ[ expr_, s_String ] := AnyTrue[ stringsIn @ expr, StringContainsQ[ #, s ] & ];

    (* Evaluates eval with any DirectoryQ or ExpandFileName of a path starting with one of prefixes recorded in
       $localPathCalls (and not done) *)
    withLocalPathTrap // Attributes = { HoldRest };
    withLocalPathTrap[ prefixes_, eval_ ] := Internal`InheritedBlock[ { DirectoryQ, ExpandFileName },
        Unprotect[ DirectoryQ, ExpandFileName ];
        DirectoryQ[ p_String ] /; StringStartsQ[ p, prefixes ] := (AppendTo[ $localPathCalls, { "DirectoryQ", p } ]; False);
        ExpandFileName[ p_String ] /; StringStartsQ[ p, prefixes ] := (AppendTo[ $localPathCalls, { "ExpandFileName", p } ]; p);
        eval
    ];
    $localPathCalls = { };

    (* acpReuseWindow (ShowNotebookAssistance on the open window) without a front end *)
    reuseWindow[ nbo_, settings_Association ] := Block[
        {
            acpCheckSession                               = True &,
            Wolfram`Chatbook`Common`moveToChatInputField = Null &,
            SetSelectedNotebook                           = Null &
        },
        Wolfram`Chatbook`ACP`UI`Private`acpReuseWindow[ None, nbo, settings ]
    ];

    processRuns[ ] := Wolfram`Chatbook`ACP`Git`Private`$gitRuns;
    (* No process runs and no one-shot run holds a host slot *)
    runsDoneQ[ ] := processRuns[ ] === <| |> && Wolfram`Chatbook`ACP`Remote`Private`$remoteRuns === <| |>;
    (* A listing in ACPLS1 (nonce "N") of the folder /x with the home folder home, as the remote sends it *)
    homeListing[ home_String ] := StringToByteArray[
        "v:1:N\000h:" <> home <> "\000q:/x\000s:ok\000p:/x\000r:/x\000c:0 0 0 0\000e:\000",
        "UTF-8"
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPFolderPicker-Definitions@@Tests/ACPFolderPicker.wlt:52,1-297,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Listings*)

(* The picker's view of listings (the fixtures of Data/ACP/RemoteListing, nonce "N"): a listing (ok, unreadable,
   fallback, capped, unlisted, noise, empty), a navigation error (missing, not a folder, no access), or "Failed"
   (malformed, a foreign nonce, no "list" frame). Folders come first in natural order, keys are unique and are not the
   names. *)
VerificationTest[
    headless @ Module[ { store, outcome, ok, entries, applied, nbo, fallback },
        store   = testStore[ "Path" -> "/home/u" ];
        outcome = fpOutcome[ store, listResult @ listingFixture @ #, "N" ] &;
        ok      = outcome[ "ok" ];
        entries = fpEntries @ ok[ "Listing" ];
        (* the store after a fallback listing (acpFolderPickerOnResult, as the runner calls it) *)
        nbo = newRemoteWindow[ None ];
        acpWindowUpdate[ nbo, <| #, "FolderPicker" -> testStore[ "Request" -> <| "Token" -> "t1", "Path" -> "/home/u/proj/gone/deeper", "Kind" -> "Open" |>, "Status" -> "Loading" ] |> & ];
        applied  = acpFolderPickerOnResult[ nbo, "t1", "N", listResult @ listingFixture[ "fallback" ] ];
        fallback = pickerOf @ nbo;
        {
            Lookup[ outcome /@ { "ok", "unreadable", "fallback", "capped", "unlisted", "noise", "empty" }, "Kind" ],
            Lookup[ Lookup[ outcome /@ { "missing", "notdir", "access" }, "Error" ], { "Code", "Message", "Navigation" } ],
            Lookup[ Lookup[ outcome /@ { "malformed" }, "Error" ], { "Code", "Message", "Navigation" } ],
            Lookup[ fpOutcome[ store, listResult @ listingFixture[ "ok" ], "OTHER" ], { "Kind" } ],
            Lookup[ fpOutcome[ store, <| listResult @ ByteArray[ { } ], "Frames" -> <| |> |>, "N" ], "Kind" ],
            Length @ entries,
            Lookup[ entries[[ ;; 3 ]], "Name" ],
            Union @ Lookup[ entries[[ ;; 34 ]], "Kind" ],
            Union @ Lookup[ entries[[ 35 ;; ]], "Kind" ] === Sort @ { "File", "BrokenLink", "Other" },
            DuplicateFreeQ @ Lookup[ entries, "Key" ],
            Intersection[ Lookup[ entries, "Key" ], Lookup[ entries, "Name" ] ],
            AllTrue[ Lookup[ entries, "Key" ], StringMatchQ[ #, RegularExpression[ "[0-9a-z]+" ] ] & ],
            Lookup[ SelectFirst[ entries, StringStartsQ[ #[ "Name" ], "bad" ] & ], { "Usable", "Kind" } ],
            applied,
            Lookup[ fallback, { "Status", "Path", "ListingStatus", "Notice", "InputShown", "Version", "Request", "Error" } ],
            Lookup[ fpOutcome[ store, listResult @ listingFixture[ "unreadable" ], "N" ][ "Listing" ], { "Status", "Path" } ],
            fpOutcome[ store, listResult @ listingFixture[ "capped" ], "N" ][ "Listing", "Capped" ],
            fpOutcome[ store, listResult @ listingFixture[ "unlisted" ], "N" ][ "Listing", "Warning" ]
        }
    ],
    {
        { "Listing", "Listing", "Listing", "Listing", "Listing", "Listing", "Listing" },
        {
            { "Missing", "The folder ~/nope doesn't exist.", True },
            { "NotFolder", "~/proj/README.md is not a folder.", True },
            { "NoAccess", "You don't have permission to open ~/proj/locked.", True }
        },
        { { "Failed", "The folder could not be listed on testhost.", False } },
        { "Error" },
        "Error",
        45,
        { "  lead and trail  ", "$dollar", "*" },
        { "Folder" },
        True,
        True,
        { },
        True,
        { False, "Folder" },
        "Listing",
        {
            "Ready", "/home/u/proj", "OK", "~/proj/gone/deeper doesn't exist anymore; showing ~/proj.", "~/proj", 1, None, None
        },
        { "Unreadable", "/home/u/proj/xonly" },
        <| "Folders" -> 100, "Files" -> 50 |>,
        "Unlisted"
    },
    SameTest -> MatchQ,
    TestID   -> "Parse-Fixtures@@Tests/ACPFolderPicker.wlt:307,1-367,2"
]

(* A listing's home folder replaces the window's home when it differs (a stale persisted one, e.g. of an ssh alias that
   now points to another machine), and is persisted for the host; a window of another host keeps its home *)
VerificationTest[
    headless @ Module[ { saved, request, nbo, other, before, results },
        saved   = acpPersistedSetting[ { "SSH", "testhost", "Home" }, Inherited ];
        request = <| "Token" -> "t-home", "Path" -> "/home/u/proj", "Kind" -> "Open" |>;
        acpSetPersistedSetting[ { "SSH", "testhost", "Home" }, "/old" ];
        nbo    = newRemoteWindow[ None, Automatic, <| "RemoteHome" -> "/old" |> ];
        before = acpWindowGet[ nbo, "RemoteHome" ];
        acpWindowUpdate[ nbo, <| #, "FolderPicker" -> testStore[ "Status" -> "Loading", "Request" -> request, "Home" -> "/old" ] |> & ];
        other = newRemoteWindow[ None, remoteSSH[ "otherhost" ], <| "RemoteHome" -> "/other-home" |> ];
        acpWindowUpdate[ other, <| #, "FolderPicker" -> testStore[ "Status" -> "Loading", "Request" -> request ] |> & ];
        results = {
            before,
            acpFolderPickerOnResult[ nbo, "t-home", "N", listResult @ listingFixture[ "ok" ] ],
            acpWindowGet[ nbo, "RemoteHome" ],
            pickerOf[ nbo ][ "Home" ],
            acpPersistedSetting[ { "SSH", "testhost", "Home" } ],
            acpFolderPickerOnResult[ other, "t-home", "N", listResult @ listingFixture[ "ok" ] ],
            acpWindowGet[ other, "RemoteHome" ]
        };
        acpSetPersistedSetting[ { "SSH", "testhost", "Home" }, saved ];
        results
    ],
    { "/old", "Listing", "/home/u", "/home/u", "/home/u", "Listing", "/other-home" },
    SameTest -> MatchQ,
    TestID   -> "KeepHome-ReplacesStale@@Tests/ACPFolderPicker.wlt:371,1-396,2"
]

(* A home folder that the parser rejects (a control character, a relative path) is never persisted and never becomes
   the window's home, through the path that persists homes (acpFolderPickerOnResult): a host without a home keeps none
   (the window's "RemoteHome" stays None), and a host with one keeps it (persisted and in the window); the listing
   itself is shown *)
VerificationTest[
    headless @ Module[ { known, settings0, run, results },
        known = { "SSH", "rejected-known.example", "Home" };
        acpSetPersistedSetting[ known, "/home/good" ];
        settings0 = Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings;
        run[ host_String, home_String, windowHome_ ] := Module[ { ssh, nbo },
            ssh = remoteSSH @ host;
            nbo = newRemoteWindow[ None, ssh, <| "RemoteHome" -> windowHome |> ];
            acpWindowUpdate[
                nbo,
                <|
                    #,
                    "FolderPicker" -> testStore[
                        "SSH" -> ssh, "HostKey" -> host, "Home" -> windowHome, "Status" -> "Loading",
                        "Request" -> <| "Token" -> "t-rejected", "Path" -> "/x", "Kind" -> "Open" |>
                    ]
                |> &
            ];
            {
                acpFolderPickerOnResult[ nbo, "t-rejected", "N", listResult @ homeListing @ home ],
                Lookup[ pickerOf @ nbo, { "Status", "Path", "Home" } ],
                acpWindowGet[ nbo, "RemoteHome" ]
            }
        ];
        results = Join[
            run[ "rejected.example", #, None ] & /@ { "/home/evil\nx", "home/u" },
            run[ "rejected-known.example", #, "/home/good" ] & /@ { "/home/evil\nx", "home/u" }
        ];
        {
            results,
            Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings === settings0,
            acpSetPersistedSetting[ known, Inherited ]
        }
    ],
    {
        {
            { "Listing", { "Ready", "/x", None }, None },
            { "Listing", { "Ready", "/x", None }, None },
            { "Listing", { "Ready", "/x", "/home/good" }, "/home/good" },
            { "Listing", { "Ready", "/x", "/home/good" }, "/home/good" }
        },
        True,
        Inherited
    },
    SameTest -> MatchQ,
    TestID   -> "KeepHome-Rejected@@Tests/ACPFolderPicker.wlt:402,1-448,2"
]

(* The listing body under every available shell, as the remote runs it (the prelude and the body on standard input of
   sh -s), parsed as the picker does: the same entries in every shell, and every folder that can be entered opens by
   its child path (acpRemoteChild of the listed path and the name) with exactly that path *)
VerificationTest[
    ifFakeSSH @ headless @ Module[ { nonce = "0123456789abcdef", list, listings, base, reopened },
        list[ shell_List, path_String, fallback_ ] := Module[ { lnonce = "L" <> StringDelete[ CreateUUID[ ], "-" ], script, run, parsed },
            script = ByteArrayToString[ acpRemoteScript[ nonce, 30, acpRemoteListBody[ lnonce, path, None, fallback ] ][ "Script" ], "UTF-8" ];
            run    = runShell[ shell, { "-s" }, script, $scratch, <| "HOME" -> $scratch, "TMPDIR" -> $namesTmp |> ];
            parsed = acpRemoteParseFrames[ run[ "Output" ], nonce ];
            fpOutcome[ testStore[ ], <| listResult @ ByteArray[ { } ], "Frames" -> parsed[ "Frames" ] |>, lnonce ]
        ];
        listings = list[ #, $names, False ] & /@ $shells;
        base     = First @ listings;
        reopened = Map[
            With[ { child = acpRemoteChild[ base[ "Listing", "Path" ], #[ "Name" ] ] },
                With[ { o = list[ { "/bin/sh" }, child, False ] }, o[ "Kind" ] === "Listing" && o[ "Listing", "Path" ] === child ]
            ] &,
            Select[ fpEntries @ base[ "Listing" ], #[ "Kind" ] === "Folder" && #[ "Usable" ] && ! #[ "Locked" ] & ]
        ];
        {
            base[ "Kind" ],
            Length @ $shells > 0,
            AllTrue[ listings, fpEntries[ #[ "Listing" ] ] === fpEntries[ base[ "Listing" ] ] & ],
            Sort @ Lookup[ Select[ fpEntries @ base[ "Listing" ], #[ "Usable" ] & ], "Name" ] === Sort @ Append[ $trickyNames, "link" ],
            Lookup[ Select[ fpEntries @ base[ "Listing" ], ! #[ "Usable" ] & ], "Name" ],
            Length @ reopened,
            And @@ reopened,
            (* the first listing's fallback: a folder that is gone lists the nearest one above it *)
            Lookup[ list[ { "/bin/sh" }, $names <> "/gone/deeper", True ][ "Listing" ], { "Path", "RequestedStatus" } ]
        }
    ],
    Missing[ "TestSkipped" ] | { "Listing", True, True, True, { "bad\:00ffutf8" }, 22, True, { $names, "Missing" } },
    SameTest -> MatchQ,
    TestID   -> "Script-Shells@@Tests/ACPFolderPicker.wlt:453,1-484,2"
]

(* A listing's script (prelude and body) is far below $acpRemoteMaxScript, also with the longest paths; it has no CR and
   passes dash -n *)
VerificationTest[
    headless @ Module[ { long, scripts },
        long    = "/" <> StringRepeat[ "x", $acpRemoteMaxPathLength - 1 ];
        scripts = acpRemoteScript[ "0123456789abcdef", 40, acpRemoteListBody[ "L0123", #1, #2, True ] ][ "Script" ] & @@@ {
            { "~/projects/app", None },
            { long, long },
            { "it's \"q\" $HOME `x` \\\n a", "/srv/a b" }
        };
        {
            Max[ Length /@ scripts ] < $acpRemoteMaxScript,
            Length @ First @ scripts < 6000,
            AllTrue[ scripts, FreeQ[ Normal @ #, 13 ] & ],
            ifFakeSSH @ AllTrue[ scripts, runShell[ { $dash }, { "-n" }, ByteArrayToString[ #, "UTF-8" ], $scratch ][ "ExitCode" ] === 0 & ]
        }
    ],
    { True, True, True, True | Missing[ "TestSkipped" ] },
    SameTest -> MatchQ,
    TestID   -> "Script-Size@@Tests/ACPFolderPicker.wlt:488,1-506,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Pure Parts*)

(* The remote path helpers (SSH.wl) as the picker uses them, and the picker's own path checks *)
VerificationTest[
    headless @ {
        acpRemoteParent /@ { "/a/b", "/a", "/", "/a//b//", "/a/./b/../c" },
        acpRemoteChild @@@ { { "/a", "b" }, { "/", "b" }, { "/a/", "b c" } },
        acpRemoteAbbreviate[ #, "/home/u" ] & /@ { "/home/u/x", "/home/u", "/home/u2/x", "/srv" },
        acpRemoteAbbreviate[ "/home/u/x", None ],
        acpRemoteExpandHome[ #, "/home/u" ] & /@ { "~", "~/x", "/a", "x" },
        acpRemoteExpandHome[ "~/x", None ],
        acpRemoteNormalizeDirectory[ #, "/home/u" ] & /@ { " ~/x/ ", File[ "/srv/app/" ], "/", "" },
        Wolfram`Chatbook`Common`acpRemoteProjectDirectoryQ /@ { "/srv", "~", "~/x", "rel", "~bob", "/a\nb", StringRepeat[ "/x", 2048 ], "/" <> StringRepeat[ "x", 4096 ] },
        acpRemotePathName /@ { "/a/b", "/a/b/", "/" },
        acpRemoteDisplayName /@ { "a\nb", "c\rd", "t\tx", "\:f7c1x", "rtl\:202eevil" },
        acpRemoteFolderLabel[ "ec2-203-0-113-100", "/home/ubuntu/projects/my-app", "/home/ubuntu", 42 ],
        fpTildeUserQ /@ { "~", "~/x", "~bob", "~bob/x", "/a" },
        fpPathQ /@ { "/a", "rel", "", "  ", "/a\000b", "/" <> StringRepeat[ "x", 5000 ] },
        fpTargetPath[ <| "Path" -> #1, "Base" -> #2 |>, "/home/u" ] & @@@ {
            { "/a/./b/../c", None }, { "..", "/home/u/proj/B" }, { "sub", "/srv" }, { "~/x", None }, { "~", None }, { "rel", None }
        }
    },
    {
        { "/a", "/", "/", "/a", "/a" },
        { "/a/b", "/b", "/a/b c" },
        { "~/x", "~", "/home/u2/x", "/srv" },
        "/home/u/x",
        { "/home/u", "/home/u/x", "/a", "x" },
        "~/x",
        { "/home/u/x", "/srv/app", "/", None },
        { True, True, True, False, False, False, True, False },
        { "b", "b", "/" },
        { "a\:2424b", "c\:240dd", "t\:2409x", "\:fffdx", "rtl\:27e6U+202E\:27e7evil" },
        { "ec2-203-0-113-1\[Ellipsis]", "~/projects/my-app" },
        { False, False, True, True, False },
        { True, True, False, False, False, False },
        { "/a/c", "/home/u/proj", "/srv/sub", "/home/u/x", "/home/u", "rel" }
    },
    SameTest -> MatchQ,
    TestID   -> "Paths@@Tests/ACPFolderPicker.wlt:513,1-550,2"
]

(* Host identity: the picker's store and its preference keys use acpSSHHostKey; labels use the short host *)
VerificationTest[
    headless @ {
        acpSSHHostKey @ Wolfram`Chatbook`Common`acpSSHSettings @ #1 & /@ {
            <| "MachineName" -> "EC2-203-0-113-100.compute-1.amazonaws.com", "Username" -> "ubuntu", "Arguments" -> { "-i", "C:/k.pem" } |>,
            <| "MachineName" -> "devbox", "Arguments" -> { "-p", "2222" } |>,
            <| "MachineName" -> "10.0.0.5", "Username" -> "me", "Arguments" -> { "-p2200" } |>,
            <| "MachineName" -> "h", "Arguments" -> { "-o", "Port=2201", "-p", "9" } |>,
            <| "MachineName" -> "h", "Arguments" -> { "-vp2202" } |>,
            <| "MachineName" -> "h", "Arguments" -> { "-i", "-p" } |>,
            <| "MachineName" -> "h", "Arguments" -> { "-p", "22" } |>
        },
        acpSSHShortHost @ <| "MachineName" -> # |> & /@ { "ec2-203-0-113-100.compute-1.amazonaws.com", "203.0.113.100", "devbox", "fe80::1" },
        acpRemoteHomeKey @ remoteSSH[ ],
        acpLastProjectDirectoryKey @ remoteSSH[ "testhost", "Username" -> "me" ]
    },
    {
        { "ubuntu@ec2-203-0-113-100.compute-1.amazonaws.com", "devbox:2222", "me@10.0.0.5:2200", "h:2201", "h:2202", "h", "h" },
        { "ec2-203-0-113-100", "203.0.113.100", "devbox", "fe80::1" },
        { "SSH", "testhost", "Home" },
        { "SSH", "me@testhost", "LastProjectDirectory" }
    },
    SameTest -> MatchQ,
    TestID   -> "HostKey@@Tests/ACPFolderPicker.wlt:553,1-576,2"
]

(* Placement: centered on the ACP window, clamped to the display at both edges, 40 points below its top, at most as tall
   as the ACP window leaves room for (at least 300 points); without geometry the front end places it *)
VerificationTest[
    headless @ Module[ { owner },
        owner = <| "Left" -> #1, "Width" -> 360, "Top" -> 30, "Height" -> #2 |> &;
        {
            acpFolderPickerPlacement[ owner[ 100, 900 ], { 0, 1920 }, { 440, 560 } ],
            acpFolderPickerPlacement[ owner[ 0, 900 ], { 0, 1920 }, { 440, 560 } ][ "WindowMargins" ],
            acpFolderPickerPlacement[ owner[ 1700, 900 ], { 0, 1920 }, { 440, 560 } ][ "WindowMargins" ],
            acpFolderPickerPlacement[ owner[ 2000, 900 ], { 1920, 3840 }, { 440, 560 } ][ "WindowMargins" ],
            acpFolderPickerPlacement[ owner[ 100, 400 ], { 0, 1920 }, { 440, 560 } ][ "WindowSize" ],
            acpFolderPickerPlacement[ owner[ 100, 200 ], { 0, 1920 }, { 440, 560 } ][ "WindowSize" ],
            acpFolderPickerPlacement[ owner[ 100, Automatic ], { 0, 1920 }, { 440, 560 } ][ "WindowSize" ],
            acpFolderPickerPlacement[ <| |>, { 0, 1920 }, { 440, 560 } ],
            acpFolderPickerPlacement[ owner[ 100, 900 ], None, { 440, 560 } ],
            (* headless: the ACP window's geometry is unknown *)
            acpFolderPickerGeometry @ NotebookObject[ "acp-picker-geometry" ],
            KeyTake[ acpOwnerGeometry @ NotebookObject[ "acp-picker-geometry" ], { "Left", "Display", "Magnification" } ]
        }
    ],
    {
        <| "WindowMargins" -> { { 60, Automatic }, { Automatic, 70 } }, "WindowSize" -> { 440, 560 } |>,
        { { 0, Automatic }, { Automatic, 70 } },
        { { 1480, Automatic }, { Automatic, 70 } },
        { { 1960, Automatic }, { Automatic, 70 } },
        { 440, 360 },
        { 440, 300 },
        { 440, 560 },
        <| "WindowMargins" -> Automatic, "WindowSize" -> { 440, 560 } |>,
        <| "WindowMargins" -> Automatic, "WindowSize" -> { 440, 560 } |>,
        <| "WindowMargins" -> Automatic, "WindowSize" -> { 440 | 520, 560 | 600 }, "Magnification" -> 0.85 |>,
        <| "Left" -> None, "Display" -> None, "Magnification" -> 0.85 |>
    },
    SameTest -> MatchQ,
    TestID   -> "Placement@@Tests/ACPFolderPicker.wlt:580,1-613,2"
]

(* With the ACP window's default width (480 points; 600 on macOS, where the picker is 520 wide) the picker is inside the
   window, also at the display's left edge *)
VerificationTest[
    headless @ {
        acpFolderPickerPlacement[ <| "Left" -> 0, "Width" -> 480, "Top" -> 30, "Height" -> 700 |>, { 0, 1366 }, { 440, 560 } ],
        acpFolderPickerPlacement[ <| "Left" -> 0, "Width" -> 600, "Top" -> 30, "Height" -> 700 |>, { 0, 1440 }, { 520, 600 } ][ "WindowMargins" ]
    },
    {
        <| "WindowMargins" -> { { 20, Automatic }, { Automatic, 70 } }, "WindowSize" -> { 440, 560 } |>,
        { { 40, Automatic }, { Automatic, 70 } }
    },
    SameTest -> MatchQ,
    TestID   -> "Placement-DefaultWidth@@Tests/ACPFolderPicker.wlt:617,1-628,2"
]

(* The picker window (pure): deployed, never saved, excluded from chat, owner and host key in the TaggingRules, the owner's
   kernel; the path field is an InputField bound to the TaggingRules and outside every Dynamic; the docked cell is
   selectable (typing) and the notebook is not; Escape cancels, closing tells the store; the list cell is tagged *)
VerificationTest[
    headless @ Module[ { owner, nb, options, docked, boxes, tagging },
        owner   = NotebookObject[ "acp-picker-notebook-owner" ];
        nb      = acpFolderPickerNotebook[ owner, <| "WindowMargins" -> { { 60, Automatic }, { Automatic, 70 } }, "WindowSize" -> { 440, 560 }, "Magnification" -> 1. |>, remoteSSH[ "testhost", "Username" -> "u" ] ];
        options = Association @ Cases[ List @@ Rest @ nb, _Rule | _RuleDelayed ];
        docked  = First @ options[ DockedCells ];
        boxes   = First @ docked;
        tagging = options[ TaggingRules ];
        {
            Head @ nb,
            Lookup[ options, { Deployed, Editable, Saveable, Selectable, ShowCellBracket, ClosingAutoSave, "ClosingSaveDialog", StyleDefinitions } ],
            Lookup[ options, { WindowMargins, WindowSize, Magnification, Evaluator, WindowTitle } ],
            tagging,
            Head @ docked,
            Lookup[ Association @ Cases[ List @@ Rest @ docked, _Rule ], Selectable ],
            Length @ Cases[ boxes, _InputFieldBox, Infinity ],
            Cases[ boxes, InputFieldBox[ Dynamic[ CurrentValue[ _, { TaggingRules, "ACPFolderPicker", "Input" } ] ], String, ___ ], Infinity ] =!= { },
            Cases[ boxes, DynamicBox[ x_ /; ! FreeQ[ x, InputFieldBox ], ___ ], Infinity ],
            Cases[ boxes, (BoxID -> id_String) :> id, Infinity ] // Sort,
            Sort @ actionsIn @ boxes,
            Sort @ Cases[ options[ NotebookEventActions ], (e_String :> _) :> e ],
            Sort @ actionsIn @ options[ NotebookEventActions ],
            Lookup[ Association @ Cases[ List @@ Rest @ First @ First @ nb, _Rule ], CellTags ],
            textQ[ boxes, "on u@testhost" ]
        }
    ],
    {
        Notebook,
        { True, False, False, False, False, False, False, "Default.nb" },
        { { { 60, Automatic }, { Automatic, 70 } }, { 440, 560 }, 1., "Local", "Choose a project folder on testhost" },
        <|
            "ACPFolderPicker"      -> <| "Owner" -> NotebookObject[ "acp-picker-notebook-owner" ], "HostKey" -> "u@testhost", "Input" -> "", "Path" -> None |>,
            "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |>
        |>,
        Cell,
        True,
        1,
        True,
        { },
        { "ACPFolderPickerGo", "ACPFolderPickerHome", "ACPFolderPickerPath", "ACPFolderPickerRefresh", "ACPFolderPickerUp" },
        { "FolderPickerCancel", "FolderPickerGo", "FolderPickerGo", "FolderPickerHome", "FolderPickerRefresh", "FolderPickerUp" },
        { "EscapeKeyDown", "WindowClose" },
        { "FolderPickerCancel", "FolderPickerClosed" },
        "ACPFolderPickerList",
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Notebook@@Tests/ACPFolderPicker.wlt:633,1-681,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Listing Through ssh*)

(* The first listing of a window without a folder: the home folder; the listing's home is kept in the window and
   persisted for the host. A listing of the project: folders first (natural order: a2 before a10, case does not
   matter), then files; hidden entries are listed (the view filters them); unique keys; the path field shows the
   abbreviated path; the debug log has no paths *)
VerificationTest[
    ifFakeSSH @ headless @ Module[ { nbo, t0, opened, start, store, log },
        acpSetPersistedSetting[ { "SSH", "testhost", "Home" }, Inherited ];
        t0  = AbsoluteTime[ ];
        nbo = newRemoteWindow[ None ];
        opened = acpFolderPickerOpen @ nbo;
        start  = pickerOf @ nbo;
        waitListed @ nbo;
        store = pickerOf @ nbo;
        $startWindow = nbo;
        log = Select[ logSince @ t0, #[ "Where" ] === "FolderPickerListed" & ];
        {
            opened,
            Lookup[ start, { "Status", "Path", "HostKey" } ],
            start[ "Request" ][ "Kind" ],
            Lookup[ store, { "Status", "Path", "Home", "InputShown", "ListingStatus", "Error", "Version", "Request" } ],
            acpWindowGet[ nbo, "RemoteHome" ],
            acpPersistedSetting[ { "SSH", "testhost", "Home" } ],
            acpFolderPickerStart[ nbo, "~/proj", None, "Open" ] // StringQ,
            waitListed @ nbo,
            Lookup[ pickerOf[ nbo ][ "Entries" ], "Name" ],
            DuplicateFreeQ @ Lookup[ pickerOf[ nbo ][ "Entries" ], "Key" ],
            Lookup[ pickerOf @ nbo, { "Path", "InputShown", "Counts" } ],
            Lookup[ First @ log, "Data" ],
            FreeQ[ logSince @ t0, s_String /; StringContainsQ[ s, $home ] ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        "Opened",
        { "Loading", None, "testhost" },
        "Open",
        { "Ready", $home, $home, "~", "OK", None, 1, None },
        $home,
        $home,
        True,
        True,
        { ".hidden", "a2", "a10", "B", "link-a2", "with space", ".env", "broken", "notes.txt", "README.md" },
        True,
        { $home <> "/proj", "~/proj", <| "Folders" -> 5, "HiddenFolders" -> 1, "Files" -> 3, "HiddenFiles" -> 1 |> },
        KeyValuePattern @ { "Status" -> "OK", "Entries" -> 7, "Seconds" -> _? NumberQ },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Start-Listing@@Tests/ACPFolderPicker.wlt:691,1-735,2"
]

(* Navigation: Enter (by key, never by name), Up, Home, Go (relative to the listed folder, absolute, ~, ..), Go with the
   field unchanged (lists the folder again), ~bob (an error, without ssh); an action without a picker does nothing *)
VerificationTest[
    ifFakeSSH @ headless @ Module[ { nbo = $startWindow, steps = <| |>, before, tilde, noPicker },
        steps[ "Enter" ] = Lookup[ navigate[ "FolderPickerEnter", nbo, entryKey[ nbo, "a2" ] ], { "Path", "LastRequest" } ];
        steps[ "Up" ]    = Lookup[ navigate[ "FolderPickerUp", nbo ], { "Path", "LastRequest" } ];
        steps[ "Home" ]  = Lookup[ navigate[ "FolderPickerHome", nbo ], { "Path", "LastRequest" } ];
        steps[ "GoRel" ] = Lookup[ navigate[ "FolderPickerGo", nbo, "proj/B" ], { "Path", "LastRequest" } ];
        steps[ "GoDot" ] = Lookup[ navigate[ "FolderPickerGo", nbo, ".." ], { "Path", "LastRequest" } ];
        steps[ "GoAbs" ] = Lookup[ navigate[ "FolderPickerGo", nbo, $home <> "/other" ], { "Path", "LastRequest" } ];
        steps[ "GoHome" ] = Lookup[ navigate[ "FolderPickerGo", nbo, "~" ], { "Path", "LastRequest" } ];
        steps[ "Same" ]  = Lookup[ navigate[ "FolderPickerGo", nbo, pickerOf[ nbo ][ "InputShown" ] ], { "Path", "LastRequest", "Version" } ];
        steps[ "Refresh" ] = Lookup[ navigate[ "FolderPickerRefresh", nbo ], { "Path", "LastRequest" } ];
        before = sshCalls[ ];
        tilde  = pickerAction[ "FolderPickerGo", nbo, "~bob/x" ];
        Pause[ 0.5 ];
        noPicker = pickerAction[ "FolderPickerUp", newRemoteWindow[ None ] ];
        {
            { #[[ 1 ]], #[[ 2, "Kind" ]] } & /@ KeyDrop[ steps, "Same" ],
            steps[[ "Same", 2, "Kind" ]],
            steps[[ "Same", 2, "Path" ]],
            steps[[ "GoRel", 2, "Base" ]],
            Lookup[ tilde, { "Code", "Message" } ],
            sshCalls[ ] - before,
            Lookup[ pickerOf @ nbo, { "Status", "Path", "InputShown" } ],
            pickerOf[ nbo ][ "Error", "Code" ],
            pickerAction[ "FolderPickerEmpty", nbo ],
            pickerAction[ "FolderPickerGo", nbo, "   " ],
            noPicker,
            (* Up at the root does nothing *)
            navigate[ "FolderPickerGo", nbo, "/" ][ "Path" ],
            pickerAction[ "FolderPickerUp", nbo ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        <|
            "Enter"   -> { $home <> "/proj/a2", "Enter" },
            "Up"      -> { $home <> "/proj", "Up" },
            "Home"    -> { $home, "Home" },
            "GoRel"   -> { $home <> "/proj/B", "Go" },
            "GoDot"   -> { $home <> "/proj", "Go" },
            "GoAbs"   -> { $home <> "/other", "Go" },
            "GoHome"  -> { $home, "Go" },
            "Refresh" -> { $home, "Refresh" }
        |>,
        "Refresh",
        $home,
        $home,
        { "Tilde", "Only ~ and ~/\[Ellipsis] are supported, not ~user." },
        0,
        { "Ready", $home, "~" },
        "Tilde",
        Missing[ "UnknownAction", "FolderPickerEmpty" ],
        Missing[ "Empty" ],
        Missing[ "NoPicker" ],
        "/",
        Missing[ "Root" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Navigate@@Tests/ACPFolderPicker.wlt:739,1-797,2"
]

(* Folders that can't be listed: an error for the request; the previous listing stays (with the path field's text);
   a new request clears the error *)
VerificationTest[
    ifFakeSSH @ headless @ Module[ { nbo = $startWindow, before, missing, notFolder, noAccess },
        navigate[ "FolderPickerGo", nbo, $home <> "/proj" ];
        before    = Lookup[ pickerOf @ nbo, { "Path", "Version", "InputShown", "Entries" } ];
        missing   = navigate[ "FolderPickerGo", nbo, "nope/deeper" ];
        notFolder = navigate[ "FolderPickerGo", nbo, $home <> "/file.txt" ];
        noAccess  = ifPermissionsEnforced @ navigate[ "FolderPickerGo", nbo, $home <> "/perm/locked" ];
        {
            Lookup[ missing, { "Status", "Path", "Version", "InputShown", "Entries" } ] === Prepend[ before, "Ready" ],
            Lookup[ missing[ "Error" ], { "Code", "Message", "Navigation" } ],
            Lookup[ notFolder[ "Error" ], { "Code", "Message" } ],
            Replace[ noAccess, s_Association :> { s[ "Error", "Code" ], s[ "Path" ], s[ "Version" ] === before[[ 2 ]] } ],
            navigate[ "FolderPickerRefresh", nbo ][ "Error" ],
            pickerOf[ nbo ][ "Version" ] === before[[ 2 ]] + 1
        }
    ],
    Missing[ "TestSkipped" ] | {
        True,
        { "Missing", "The folder ~/proj/nope/deeper doesn't exist.", True },
        { "NotFolder", "~/file.txt is not a folder." },
        Missing[ "TestSkipped" ] | { "NoAccess", $home <> "/proj", True },
        None,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Navigate-Errors@@Tests/ACPFolderPicker.wlt:801,1-827,2"
]

(* The path field shows a folder with a tab or a bidi character display-safe (U+2409, [[U+202E]]); Go with that text
   plus "/src" lists the raw folder's src (the shown prefix stands for the raw path), while text that changes the last
   name ("x" appended, not a component boundary) is taken literally and doesn't exist *)
VerificationTest[
    ifFakeSSH @ headless @ Module[ { nbo, results },
        nbo = newRemoteWindow[ None ];
        openPicker @ nbo;
        results = Map[
            Function[ name,
                Module[ { shown, edited, literal },
                    navigate[ "FolderPickerGo", nbo, $home <> "/other" ];
                    shown  = navigate[ "FolderPickerEnter", nbo, entryKey[ nbo, name ] ][ "InputShown" ];
                    edited = Lookup[ navigate[ "FolderPickerGo", nbo, shown <> "/src" ], { "Status", "Path", "Error" } ];
                    navigate[ "FolderPickerUp", nbo ];
                    literal = navigate[ "FolderPickerGo", nbo, shown <> "x" ];
                    { shown, edited, Lookup[ literal, { "Status", "Path" } ], literal[ "Error", "Code" ] }
                ]
            ],
            { "a\tb", "rtl\:202ex" }
        ];
        acpFolderPickerCloseWindow @ nbo;
        results
    ],
    Missing[ "TestSkipped" ] | {
        { "~/other/a\:2409b", { "Ready", $home <> "/other/a\tb/src", None }, { "Ready", $home <> "/other/a\tb" }, "Missing" },
        {
            "~/other/rtl\:27e6U+202E\:27e7x",
            { "Ready", $home <> "/other/rtl\:202ex/src", None },
            { "Ready", $home <> "/other/rtl\:202ex" },
            "Missing"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Go-DisplaySafePrefix@@Tests/ACPFolderPicker.wlt:832,1-863,2"
]

(* Navigation is debounced: three Up clicks 80 ms apart make one ssh connection, for the last target (three levels up:
   each Up starts from the folder the running request lists). Real clicks are separate evaluations with pump ticks
   (50 ms) between them, so the clicks are spaced: only the debounce (150 ms) collapses them then. The control without
   the debounce makes a connection per click. *)
VerificationTest[
    ifFakeSSH @ headless @ Module[ { nbo = $startWindow, clicks, before, tokens, store, debounced, control },
        clicks[ ] := Table[ With[ { t = pickerAction[ "FolderPickerUp", nbo ] }, Pause[ 0.08 ]; t ], 3 ];
        navigate[ "FolderPickerGo", nbo, $home <> "/deep/a/b/c/d" ];
        before = sshCalls[ ];
        tokens = clicks[ ];
        waitListed @ nbo;
        store = pickerOf @ nbo;
        Pause[ 0.3 ];
        debounced = { Length @ Union @ tokens, sshCalls[ ] - before, store[ "Path" ], store[ "LastRequest", "Kind" ] };

        waitUntil[ runsDoneQ[ ], 15 ];
        navigate[ "FolderPickerGo", nbo, $home <> "/deep/a/b/c/d" ];
        before = sshCalls[ ];
        Block[ { $acpFolderPickerDebounce = Quantity[ 1, "Milliseconds" ] }, clicks[ ] ];
        waitListed @ nbo;
        control = { waitUntil[ runsDoneQ[ ], 15 ], sshCalls[ ] - before >= 2, pickerOf[ nbo ][ "Path" ] };
        { debounced, control }
    ],
    Missing[ "TestSkipped" ] | { { 3, 1, $home <> "/deep/a", "Up" }, { True, True, $home <> "/deep/a" } },
    SameTest -> MatchQ,
    TestID   -> "Debounce@@Tests/ACPFolderPicker.wlt:869,1-891,2"
]

(* "Show hidden" only filters the view (no ssh call) and is persisted (written by the pump); "Show more" pages *)
VerificationTest[
    ifFakeSSH @ headless @ Module[ { nbo = $startWindow, before, shown, toggled, back },
        acpSetPersistedSetting[ { "FolderPickerShowHidden" }, Inherited ];
        navigate[ "FolderPickerGo", nbo, $home <> "/proj" ];
        before  = sshCalls[ ];
        shown   = { pickerAction[ "FolderPickerShowMore", nbo ], pickerOf[ nbo ][ "Shown" ] };
        toggled = { pickerAction[ "FolderPickerToggleHidden", nbo ], Lookup[ pickerOf @ nbo, { "ShowHidden", "Shown", "Status" } ] };
        waitUntil[ acpPersistedSetting[ { "FolderPickerShowHidden" } ] === True, 5 ];
        AppendTo[ toggled, acpPersistedSetting[ { "FolderPickerShowHidden" } ] ];
        back = pickerAction[ "FolderPickerToggleHidden", nbo ];
        waitUntil[ acpPersistedSetting[ { "FolderPickerShowHidden" } ] === False, 5 ];
        { shown, toggled, back, acpPersistedSetting[ { "FolderPickerShowHidden" } ], sshCalls[ ] - before }
    ],
    Missing[ "TestSkipped" ] | { { 100, 100 }, { True, { True, 50, "Ready" }, True }, False, False, 0 },
    SameTest -> MatchQ,
    TestID   -> "ShowHidden-ShowMore@@Tests/ACPFolderPicker.wlt:894,1-910,2"
]

(* The automatic open (a new remote window without a folder) does nothing while the host is latched (sshd's
   PerSourcePenalties), while the window shows an error or once it has a folder; a user open clears the latch and
   lists *)
VerificationTest[
    ifFakeSSH @ headless @ Module[ { nbo, before, scheduled, auto, user },
        nbo = newRemoteWindow[ None ];
        acpRemoteNoteHostError[ "testhost", <| "Code" -> "SSHAuthFailed", "Message" -> "testhost didn't accept your SSH key." |> ];
        before    = sshCalls[ ];
        scheduled = acpFolderPickerAutoOpen @ nbo;
        Pause[ 0.6 ];
        auto = { pickerOf @ nbo, sshCalls[ ] - before, acpFolderPickerOpen[ nbo, "Automatic" -> True ], acpRemoteHostLatchedQ[ "testhost" ] };
        user = openPicker @ nbo;
        {
            scheduled,
            auto,
            acpRemoteHostLatchedQ[ "testhost" ],
            Lookup[ user, { "Status", "Path", "Automatic" } ],
            sshCalls[ ] - before,
            (* an open picker is raised (a second open makes no listing) *)
            acpFolderPickerOpen @ nbo,
            sshCalls[ ] - before,
            acpFolderPickerOpen[ newRemoteWindow[ None, Automatic, <| "Status" -> "Error" |> ], "Automatic" -> True ],
            acpFolderPickerOpen[ newRemoteWindow[ $home <> "/proj" ], "Automatic" -> True ],
            acpFolderPickerAutoOpen @ newRemoteWindow[ $home <> "/proj" ],
            acpFolderPickerAutoOpen @ newWindow[ None, <| |> ],
            acpFolderPickerOpen @ newWindow[ $localProject, <| |> ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        True,
        { None, 0, Missing[ "Latched" ], True },
        False,
        { "Ready", $home, False },
        1,
        "Raised",
        1,
        Missing[ "Error" ],
        Missing[ "HasDirectory" ],
        False,
        False,
        Missing[ "NotRemote" ]
    },
    SameTest -> MatchQ,
    TestID   -> "AutoOpenLatched@@Tests/ACPFolderPicker.wlt:915,1-956,2"
]

(* The first listing starts at the window's folder: if it is gone, the nearest folder above it is listed, with a notice *)
VerificationTest[
    ifFakeSSH @ headless @ Module[ { nbo, store },
        nbo   = newRemoteWindow[ $home <> "/proj/gone/deeper" ];
        store = openPicker @ nbo;
        {
            Lookup[ store, { "Status", "Path", "ListingStatus", "Notice", "InputShown", "Error" } ],
            store[ "LastRequest", "Fallback" ],
            (* the notice is for the first listing only *)
            navigate[ "FolderPickerRefresh", nbo ][ "Notice" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        { "Ready", $home <> "/proj", "OK", "~/proj/gone/deeper doesn't exist anymore; showing ~/proj.", "~/proj", None },
        True,
        None
    },
    SameTest -> MatchQ,
    TestID   -> "Fallback@@Tests/ACPFolderPicker.wlt:959,1-977,2"
]

(* A newer request replaces a running one: with a host that signs in slowly (x.slow.test), the first listing is
   superseded before READY (drained, its continuation gets "Cancelled") and only the second result is applied *)
VerificationTest[
    ifFakeSSH @ headless @ withFakeSSHEnvironment[
        <| "FAKE_SSH_DELAY" -> "2" |>,
        Module[ { nbo, t0, version, store, runs },
            nbo = newRemoteWindow[ None, remoteSSH[ "x.slow.test" ] ];
            openPicker @ nbo;
            version = pickerOf[ nbo ][ "Version" ];
            t0 = AbsoluteTime[ ];
            pickerAction[ "FolderPickerGo", nbo, $home <> "/proj" ];
            Pause[ 0.8 ];
            pickerAction[ "FolderPickerGo", nbo, $home <> "/other" ];
            waitListed @ nbo;
            store = pickerOf @ nbo;
            runs  = Lookup[ Select[ logSince @ t0, #[ "Where" ] === "RemoteRun" & ], "Data" ];
            {
                Lookup[ store, { "Status", "Path", "Error" } ],
                store[ "Version" ] - version,
                Sort @ Lookup[ runs, "Status" ],
                waitUntil[ processRuns[ ] === <| |>, 15 ]
            }
        ]
    ],
    Missing[ "TestSkipped" ] | { { "Ready", $home <> "/other", None }, 1, { "Cancelled", "OK" }, True },
    SameTest -> MatchQ,
    TestID   -> "Supersede@@Tests/ACPFolderPicker.wlt:981,1-1006,2"
]

(* ssh failures: the store shows the error info of the run (the toolbar's messages and hints, no CR, no buttons of its
   own), with "Try again" and "Copy" ("Copy command" for an unknown host key); without a listing Choose is not
   possible *)
VerificationTest[
    ifFakeSSH @ headless @ Module[ { hosts, results },
        hosts   = { "x.fail-auth.test", "x.fail-hostkey.test", "x.fail-refused.test", "x.fail-dns.test" };
        results = Map[
            Function[ host,
                Module[ { nbo, store, view },
                    nbo   = newRemoteWindow[ None, remoteSSH @ host ];
                    store = openPicker @ nbo;
                    view  = fpStatusView @ nbo;
                    {
                        Lookup[ store, { "Status", "Path" } ],
                        Lookup[ store[ "Error" ], { "Code", "Actions" } ],
                        AllTrue[ Select[ Values @ store[ "Error" ], StringQ ], StringFreeQ[ #, "\r" ] & ],
                        textQ[ view, store[ "Error", "Message" ] ],
                        actionsIn @ view,
                        acpFolderPickerChoose @ nbo
                    }
                ]
            ],
            hosts
        ];
        Scan[ (acpRemoteClearHostError[ # ]; KeyDropFrom[ $acpRemoteHostAuthFailedAt, # ]) &, hosts ];
        results
    ],
    Missing[ "TestSkipped" ] | {
        { { "Error", None }, { "SSHAuthFailed", { } }, True, True, { "FolderPickerRefresh", "FolderPickerCopyError" }, Missing[ "NotReady" ] },
        { { "Error", None }, { "SSHHostKeyUnknown", { } }, True, True, { "FolderPickerRefresh", "FolderPickerCopyCommand" }, Missing[ "NotReady" ] },
        { { "Error", None }, { "SSHConnectionRefused", { } }, True, True, { "FolderPickerRefresh", "FolderPickerCopyError" }, Missing[ "NotReady" ] },
        { { "Error", None }, { "SSHHostNotFound", { } }, True, True, { "FolderPickerRefresh", "FolderPickerCopyError" }, Missing[ "NotReady" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "SSH-Errors@@Tests/ACPFolderPicker.wlt:1011,1-1043,2"
]

(* A listing that takes too long *)
VerificationTest[
    ifFakeSSH @ headless @ Block[ { $acpFolderPickerTimeout = 2 },
        Module[ { nbo, store },
            nbo   = newRemoteWindow[ None, remoteSSH[ "x.hang.test" ] ];
            store = openPicker @ nbo;
            {
                Lookup[ store, { "Status", "Path" } ],
                Lookup[ store[ "Error" ], { "Code", "Message", "Navigation" } ],
                actionsIn @ fpStatusView @ nbo
            }
        ]
    ],
    Missing[ "TestSkipped" ] | {
        { "Error", None },
        { "Timeout", "Listing the folder on x.hang.test took too long.", False },
        { "FolderPickerRefresh" }
    },
    SameTest -> MatchQ,
    TestID   -> "Timeout@@Tests/ACPFolderPicker.wlt:1046,1-1065,2"
]

(* A listing whose run waits for a host slot is not lost: acpRemoteRun bounds the slot wait and the ssh run separately,
   each by the timeout, so a live listing can take longer than the timeout plus the grace. Scaled: timeout 4 s, grace
   1 s, three runs hold x.slow.test's slots for its 3 s sign-in, and the listing signs in for 3 s more (about 6.5 s
   in all, more than 4 + 1 s). *)
VerificationTest[
    ifFakeSSH @ headless @ withFakeSSHEnvironment[
        <| "FAKE_SSH_DELAY" -> "3" |>,
        Block[ { $acpFolderPickerTimeout = 4, Wolfram`Chatbook`ACP`FolderPicker`Private`$pickerLostGrace = 1 },
            Module[ { ssh, t0, busy = { }, nbo, listed, seconds, store, lost },
                ssh = remoteSSH[ "x.slow.test" ];
                t0  = AbsoluteTime[ ];
                Do[ acpRemoteRun[ ssh, "cb_end\n", AppendTo[ busy, #[ "Status" ] ] &, <| "Label" -> "Busy" |> ], { 3 } ];
                nbo = newRemoteWindow[ None, ssh ];
                acpFolderPickerOpen @ nbo;
                listed  = waitListed[ nbo, 20 ];
                seconds = AbsoluteTime[ ] - t0;
                store   = pickerOf @ nbo;
                lost    = Select[ logSince @ t0, #[ "Where" ] === "FolderPickerListFailed" && TrueQ @ #[ "Data", "Lost" ] & ];
                {
                    listed,
                    Lookup[ store, { "Status", "Path", "Error" } ],
                    lost,
                    seconds > 5,
                    waitUntil[ Length @ busy === 3, 10 ];
                    Union @ busy,
                    acpFolderPickerCloseWindow @ nbo;
                    waitUntil[ runsDoneQ[ ], 20 ]
                }
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | { True, { "Ready", $home, None }, { }, True, { "OK" }, True },
    SameTest -> MatchQ,
    TestID   -> "SlotWait-NotLost@@Tests/ACPFolderPicker.wlt:1071,1-1101,2"
]

(* The picker lists with the window's current SSH settings: fixing "Executable" or "Arguments" for the same host
   (ShowNotebookAssistance on the open window: no host switch, so the picker stays open) reaches "Try again" and
   Refresh, also after "Choose folder..." raised the open picker; settings of another host close the picker without
   ssh *)
VerificationTest[
    ifFakeSSH @ headless @ Module[ { nbo, bad, failed, fixed, args, chooseBefore, raised, chosen, before, hostChanged },
        bad = remoteSSH[ "testhost", "Executable" -> FileNameJoin @ { $scratch, "no-such-dir", "ssh" } ];
        nbo = newRemoteWindow[ None, bad ];
        failed = Append[ Lookup[ openPicker @ nbo, { "Status", "Path" } ], pickerOf[ nbo ][ "Error", "Code" ] ];

        (* (a) a working "Executable" for the same host *)
        reuseWindow[ nbo, <| "SSHSettings" -> fakeSSHSettings[ "testhost" ] |> ];
        fixed = {
            AssociationQ @ pickerOf @ nbo,
            Lookup[ navigate[ "FolderPickerRefresh", nbo ], { "Status", "Path", "Error" } ],
            pickerOf[ nbo ][ "SSH", "Executable" ] === $fakeSSH[ "Executable" ]
        };

        (* (b) other "Arguments" for the same host *)
        reuseWindow[ nbo, <| "SSHSettings" -> fakeSSHSettings[ "testhost", "Arguments" -> { "-o", "ConnectTimeout=7" } ] |> ];
        navigate[ "FolderPickerRefresh", nbo ];
        args = { MemberQ[ Last @ fakeSSHCalls[ ], "ConnectTimeout=7" ], pickerOf[ nbo ][ "SSH" ] === acpWindowSSH @ nbo };

        (* (c) "Choose folder..." raises the open picker (no listing); the next listing uses the new settings *)
        reuseWindow[ nbo, <| "SSHSettings" -> fakeSSHSettings[ "testhost", "Arguments" -> { "-o", "ConnectTimeout=9" } ] |> ];
        chooseBefore = sshCalls[ ];
        raised = pickerAction[ "ChooseDirectory", nbo ];
        Pause[ 0.4 ];
        chosen = { raised, sshCalls[ ] - chooseBefore };
        navigate[ "FolderPickerRefresh", nbo ];
        AppendTo[ chosen, MemberQ[ Last @ fakeSSHCalls[ ], "ConnectTimeout=9" ] ];

        (* (d) the host changed under the picker (no host switch closed it): the listing closes it and runs no ssh *)
        acpWindowUpdate[ nbo, <| #, "Settings" -> <| "SSHSettings" -> remoteSSH[ "otherhost" ] |> |> & ];
        before = sshCalls[ ];
        hostChanged = { StringQ @ pickerAction[ "FolderPickerRefresh", nbo ], waitUntil[ pickerOf[ nbo ] === None, 5 ] };
        Pause[ 0.3 ];
        AppendTo[ hostChanged, sshCalls[ ] - before ];
        { failed, fixed, args, chosen, hostChanged, waitUntil[ runsDoneQ[ ], 15 ] }
    ],
    Missing[ "TestSkipped" ] | {
        { "Error", None, "SSHNotFound" },
        { True, { "Ready", $home, None }, True },
        { True, True },
        { "Raised", 0, True },
        { True, True, 0 },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "SameHostSettings@@Tests/ACPFolderPicker.wlt:1107,1-1153,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Choose*)

(* Choose: refused while the agent works, for a folder that can't be listed, for a path with a control character and
   after a host change; otherwise the listed (absolute) folder becomes the window's folder (a new chat there: the window
   connects), the picker closes, and the folder is persisted for the host once the launch has entered it (the mock agent
   through the fake ssh); the local last folder is untouched *)
VerificationTest[
    ifFakeSSH @ headless @ Module[ { nbo, running, unreadable, control, hostChanged, path, connecting, local },
        acpSetPersistedSetting[ { "SSH", "testhost", "LastProjectDirectory" }, Inherited ];
        local = acpPersistedSetting[ { "LastProjectDirectory" } ];
        nbo = newRemoteWindow[ None ];
        openPicker @ nbo;
        navigate[ "FolderPickerGo", nbo, $home <> "/proj" ];

        acpWindowUpdate[ nbo, <| #, "CurrentTurn" -> "turn-busy" |> & ];
        running = { acpFolderPickerChoose @ nbo, acpWindowGet[ nbo, "Notice" ], AssociationQ @ pickerOf @ nbo };
        acpWindowUpdate[ nbo, <| #, "CurrentTurn" -> None, "Notice" -> None |> & ];

        Wolfram`Chatbook`ACP`FolderPicker`Private`pickerUpdate[ nbo, <| #1, "ListingStatus" -> "Unreadable" |> & ];
        unreadable = { acpFolderPickerChoose @ nbo };
        Wolfram`Chatbook`ACP`FolderPicker`Private`pickerUpdate[ nbo, <| #1, "ListingStatus" -> "OK", "Warning" -> "Unlisted" |> & ];
        AppendTo[ unreadable, acpFolderPickerChoose @ nbo ];
        Wolfram`Chatbook`ACP`FolderPicker`Private`pickerUpdate[ nbo, <| #1, "Warning" -> None, "Path" -> $home <> "/new\nline" |> & ];
        control = acpFolderPickerChoose @ nbo;
        Wolfram`Chatbook`ACP`FolderPicker`Private`pickerUpdate[ nbo, <| #1, "Path" -> $home <> "/proj" |> & ];
        acpWindowUpdate[ nbo, <| #, "Settings" -> <| "SSHSettings" -> remoteSSH[ "otherhost" ] |> |> & ];
        hostChanged = acpFolderPickerChoose @ nbo;
        acpWindowUpdate[ nbo, <| #, "Settings" -> <| "SSHSettings" -> remoteSSH[ ] |> |> & ];

        path       = acpFolderPickerChoose @ nbo;
        connecting = Lookup[ acpWindowGet @ nbo, { "ProjectDirectory", "Status" } ];
        {
            running,
            { unreadable, control, hostChanged },
            path,
            connecting,
            pickerOf @ nbo,
            ifConnTests @ {
                waitUntil[ acpWindowGet[ nbo, "Status" ] === "Ready", 30 ],
                waitUntil[ acpPersistedSetting[ { "SSH", "testhost", "LastProjectDirectory" } ] === $home <> "/proj" ]
            },
            acpPersistedSetting[ { "LastProjectDirectory" } ] === local,
            acpDisconnect[ nbo, "Test" ]; acpWindowGet[ nbo, "ProjectDirectory" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        { Null, "The project folder can't be changed while the agent is working.", True },
        { { Missing[ "Unreadable" ], Missing[ "Unreadable" ] }, Missing[ "InvalidPath" ], Missing[ "HostChanged" ] },
        $home <> "/proj",
        { $home <> "/proj", "Connecting" },
        None,
        Missing[ "TestSkipped" ] | { True, True },
        True,
        $home <> "/proj"
    },
    SameTest -> MatchQ,
    TestID   -> "Choose@@Tests/ACPFolderPicker.wlt:1163,1-1214,2"
]

(* A folder that can be entered but not listed (mode 111) can't be chosen *)
VerificationTest[
    ifFakeSSH @ headless @ ifPermissionsEnforced @ Module[ { nbo, store },
        nbo = newRemoteWindow[ None ];
        openPicker @ nbo;
        store = navigate[ "FolderPickerGo", nbo, $home <> "/perm/xonly" ];
        { Lookup[ store, { "Status", "ListingStatus", "Path", "Entries" } ], acpFolderPickerChoose @ nbo, textQ[ fpListView @ nbo, "You can open this folder but not list its contents." ] }
    ],
    Missing[ "TestSkipped" ] | { { "Ready", "Unreadable", $home <> "/perm/xonly", { } }, Missing[ "Unreadable" ], True },
    SameTest -> MatchQ,
    TestID   -> "Choose-Unreadable@@Tests/ACPFolderPicker.wlt:1217,1-1227,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Project Folders*)

(* The folder of a remote window: Automatic is the host's last folder if there is a valid one (else none: the picker
   opens), an explicit ~/x is kept as given, also when the host's home is known (the launch resolves it with the remote
   $HOME); no folder is looked at on this computer. The picker starts at the window's folder, else the host's last
   folder, else ~. *)
VerificationTest[
    headless @ Module[ { default, ssh },
        default = Wolfram`Chatbook`ACP`UI`Private`acpDefaultProjectDirectory;
        ssh     = remoteSSH[ "defaults.example" ];
        $localPathCalls = { };
        withLocalPathTrap[
            { "/srv", "~" },
            {
                acpSetPersistedSetting[ { "SSH", "defaults.example", "LastProjectDirectory" }, Inherited ];
                acpSetPersistedSetting[ { "SSH", "defaults.example", "Home" }, Inherited ];
                default[ None, <| "SSHSettings" -> ssh |> ],
                default[ None, <| "SSHSettings" -> ssh, "ProjectDirectory" -> "~/x" |> ],
                fpStartPath[ <| |>, ssh ],
                acpSetPersistedSetting[ { "SSH", "defaults.example", "LastProjectDirectory" }, "/srv/app" ];
                acpSetPersistedSetting[ { "SSH", "defaults.example", "Home" }, "/srv/home" ];
                default[ None, <| "SSHSettings" -> ssh |> ],
                default[ None, <| "SSHSettings" -> ssh, "ProjectDirectory" -> "~/x" |> ],
                default[ None, <| "SSHSettings" -> ssh, "ProjectDirectory" -> File[ " /srv/b/ " ] |> ],
                fpStartPath[ <| |>, ssh ],
                fpStartPath[ <| "ProjectDirectory" -> "/srv/current" |>, ssh ],
                acpSetPersistedSetting[ { "SSH", "defaults.example", "LastProjectDirectory" }, "relative" ];
                default[ None, <| "SSHSettings" -> ssh |> ],
                fpStartPath[ <| |>, ssh ],
                $localPathCalls
            }
        ]
    ],
    { None, "~/x", "~", "/srv/app", "~/x", "/srv/b", "/srv/app", "/srv/current", None, "~", { } },
    SameTest -> MatchQ,
    TestID   -> "Defaults@@Tests/ACPFolderPicker.wlt:1237,1-1267,2"
]

(* A host switch closes the picker of the old host; a remote host without a last folder leaves the window without one
   and its picker opens by itself (on the new host); a host with a last folder opens none; back to this computer opens
   none; refused while a turn runs (the picker stays) *)
VerificationTest[
    ifFakeSSH @ headless @ Module[ { nbo, refused, toOther, toLocal, toRemote },
        acpSetPersistedSetting[ { "SSH", "otherhost", "LastProjectDirectory" }, Inherited ];
        acpSetPersistedSetting[ { "SSH", "testhost", "LastProjectDirectory" }, $home <> "/proj" ];
        (* the host was reached ("RemoteVerified"): its folder is not kept for another host *)
        nbo = newRemoteWindow[ $home <> "/proj", Automatic, <| "RemoteVerified" -> True |> ];
        openPicker @ nbo;

        acpWindowUpdate[ nbo, <| #, "CurrentTurn" -> "turn-busy", "Status" -> "Running" |> & ];
        reuseWindow[ nbo, <| "SSHSettings" -> remoteSSH[ "otherhost" ] |> ];
        refused = { acpWindowHostKey @ acpWindowGet @ nbo, acpWindowGet[ nbo, "Notice" ], pickerOf[ nbo ][ "HostKey" ] };
        acpWindowUpdate[ nbo, <| #, "CurrentTurn" -> None, "Status" -> "Disconnected", "Notice" -> None |> & ];

        reuseWindow[ nbo, <| "SSHSettings" -> remoteSSH[ "otherhost" ] |> ];
        toOther = {
            Lookup[ acpWindowGet @ nbo, { "ProjectDirectory", "Status" } ],
            Lookup[ Replace[ pickerOf @ nbo, None -> <| |> ], "HostKey", None ] =!= "testhost",
            waitUntil[ AssociationQ @ pickerOf @ nbo, 5 ] && waitListed @ nbo,
            Lookup[ pickerOf @ nbo, { "HostKey", "Status", "Path", "Automatic" } ]
        };

        reuseWindow[ nbo, <| "SSHSettings" -> None, "ProjectDirectory" -> $localProject |> ];
        Pause[ 0.5 ];
        toLocal = { acpRemoteQ @ acpWindowGet @ nbo, pickerOf @ nbo };

        reuseWindow[ nbo, <| "SSHSettings" -> remoteSSH[ ] |> ];
        Pause[ 0.5 ];
        toRemote = { acpWindowGet[ nbo, "ProjectDirectory" ], pickerOf @ nbo };
        acpDisconnect[ nbo, "Test" ];
        { refused, toOther, toLocal, toRemote }
    ],
    Missing[ "TestSkipped" ] | {
        { "testhost", "The SSH settings can't be changed while the agent is working.", "testhost" },
        { { None, "NoDirectory" }, True, True, { "otherhost", "Ready", $home, True } },
        { False, None },
        { $home <> "/proj", None }
    },
    SameTest -> MatchQ,
    TestID   -> "HostSwitch@@Tests/ACPFolderPicker.wlt:1272,1-1311,2"
]

(* The record of a remote window rebuilt after a kernel restart (from its TaggingRules): the folder is a remote path
   stored normalized (a ~ folder stays one: the launch resolves it; never ExpandFileName), and "RemoteHome" comes from
   the preferences; a picker can't be recovered without a front end *)
VerificationTest[
    headless @ Module[ { nbo, flags, record },
        nbo   = NotebookObject[ "acp-picker-rebuild" ];
        flags = <|
            "Settings"         -> <| "SSHSettings" -> remoteSSH[ "rebuild.example" ] |>,
            "ProjectDirectory" -> "~/proj/",
            "Agent"            -> "OpenCode"
        |>;
        acpSetPersistedSetting[ { "SSH", "rebuild.example", "Home" }, "/home/rebuild" ];
        $localPathCalls = { };
        record = withLocalPathTrap[
            { "~", "/home/rebuild" },
            Block[ { acpFE = Lookup[ flags, #2, If[ Length @ { ## } > 2, #3, Missing[ "NotSet" ] ] ] & },
                Wolfram`Chatbook`ACP`UI`Private`acpRebuildWindowRecord @ nbo
            ]
        ];
        {
            Lookup[ record, { "ProjectDirectory", "Status", "RemoteHome", "FolderPicker" } ],
            $localPathCalls,
            acpFolderPickerRecover @ nbo,
            acpWindowDrop @ nbo;
            acpSetPersistedSetting[ { "SSH", "rebuild.example", "Home" }, Inherited ]
        }
    ],
    { { "~/proj", "Disconnected", "/home/rebuild", Missing[ "KeyAbsent", "FolderPicker" ] }, { }, None, Inherited },
    SameTest -> MatchQ,
    TestID   -> "Rebuild@@Tests/ACPFolderPicker.wlt:1316,1-1343,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Views*)

(* Every state renders: no store yet, the first listing, a navigation running (rows muted, no buttons), ready (rows,
   Choose with the full path in its tooltip, the counts), the current folder, a link, empty and special folders, the
   fallback notice, navigation errors, ssh errors and the picker's own errors (with "Try again"), caps. Remote names
   are display-safe (U+F7C1 becomes U+FFFD; U+202E is shown as [[U+202E]] in the row and in the Choose tooltip). The
   signatures do not change when a turn updates the window. *)
VerificationTest[
    headless @ Module[ { nbo, entries, ready, view, render, sshError, states, results, window, sigs },
        nbo     = NotebookObject[ "acp-picker-views" ];
        entries = {
            testEntry[ "a2" ], testEntry[ "a10" ], testEntry[ "rtl\:202eevil" ], testEntry[ "\:f7c1linear" ],
            testEntry[ "locked", "Folder", "Locked" -> True ], testEntry[ "link", "Folder", "Link" -> True ],
            testEntry[ "bad\:00ff", "Folder", "Usable" -> False ], testEntry[ ".hidden" ],
            testEntry[ "README.md", "File" ], testEntry[ "gone", "BrokenLink", "Link" -> True ], testEntry[ ".env", "File" ]
        };
        ready = testStore[
            "Status" -> "Ready", "Path" -> "/home/u/proj", "RealPath" -> "/home/u/proj", "Entries" -> entries,
            "Counts" -> <| "Folders" -> 7, "HiddenFolders" -> 1, "Files" -> 2, "HiddenFiles" -> 1 |>, "ListingStatus" -> "OK",
            "InputShown" -> "~/proj", "Version" -> 3
        ];
        sshError = <| "Code" -> "SSHAuthFailed", "Message" -> "testhost didn't accept your SSH key.", "Detail" -> "Use a key.\n\nPermission denied (publickey).", "Actions" -> { } |>;
        render[ store_, extra_: <| |> ] := Module[ { w },
            w = <| Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, "/home/u/other", "OpenCode", <| "SSHSettings" -> remoteSSH[ ] |> ], "FolderPicker" -> store, extra |>;
            Block[ { $acpWindows = <| nbo -> w |> },
                <|
                    "Status"  -> fpStatusView @ nbo,
                    "Buttons" -> fpButtonsView @ nbo,
                    "List"    -> fpListView @ nbo,
                    "Toggle"  -> fpToggleView @ nbo
                |>
            ]
        ];
        view[ v_ ] := <| "Strings" -> stringsIn @ v, "Actions" -> actionsIn @ v, "Failed" -> ! FreeQ[ v, _Failure ] |>;
        states = <|
            "NoStore"    -> render[ None ],
            "First"      -> render @ testStore[ "Status" -> "Loading", "Request" -> <| "Token" -> "t", "Path" -> "~", "Kind" -> "Open" |> ],
            "Navigating" -> render @ <| ready, "Status" -> "Loading", "Request" -> <| "Token" -> "t", "Path" -> "/home/u/proj/a2", "Kind" -> "Enter" |> |>,
            "Ready"      -> render @ ready,
            "Hidden"     -> render @ <| ready, "ShowHidden" -> True |>,
            "Current"    -> render[ <| ready, "RealPath" -> "/data/proj" |>, <| "ProjectDirectory" -> "/home/u/proj" |> ],
            "Empty"      -> render @ <| ready, "Entries" -> { }, "Counts" -> <| "Folders" -> 0, "HiddenFolders" -> 0, "Files" -> 0, "HiddenFiles" -> 0 |> |>,
            "NoFolders"  -> render @ <| ready, "Entries" -> { testEntry[ "x.txt", "File" ] } |>,
            "HiddenOnly" -> render @ <| ready, "Entries" -> { testEntry[ ".git" ] } |>,
            "Unreadable" -> render @ <| ready, "Entries" -> { }, "ListingStatus" -> "Unreadable" |>,
            "Unlisted"   -> render @ <| ready, "Entries" -> { }, "Warning" -> "Unlisted" |>,
            "Fallback"   -> render @ <| ready, "Notice" -> "~/gone doesn't exist anymore; showing ~/proj." |>,
            "Navigation" -> render @ <| ready, "Error" -> <| "Code" -> "Missing", "Message" -> "The folder ~/nope doesn't exist.", "Source" -> "FolderPicker", "Navigation" -> True |> |>,
            "SSH"        -> render @ testStore[ "Status" -> "Error", "Error" -> sshError ],
            "Timeout"    -> render @ <| ready, "Error" -> <| "Code" -> "Timeout", "Message" -> "Listing the folder on testhost took too long.", "Source" -> "FolderPicker", "Navigation" -> False |> |>,
            "Failed"     -> render @ testStore[ "Status" -> "Error", "Error" -> <| "Code" -> "Failed", "Message" -> "The folder could not be listed on testhost.", "Detail" -> "sh: \:f7c1oops", "Source" -> "FolderPicker", "Navigation" -> False |> ],
            "Caps"       -> render @ <| ready,
                "Entries" -> Join[ Table[ testEntry[ "f" <> ToString @ i ], { i, 60 } ], Table[ testEntry[ "x" <> ToString @ i <> ".txt", "File" ], { i, 25 } ] ],
                "Counts" -> <| "Folders" -> 1200, "HiddenFolders" -> 0, "Files" -> 5000, "HiddenFiles" -> 0 |>,
                "Capped" -> <| "Folders" -> None, "Files" -> 5000 |> |>,
            "Running"    -> render[ ready, <| "CurrentTurn" -> "turn-1" |> ],
            "Odd"        -> render @ <| ready, "Path" -> "/home/u/rtl\:202eevil" |>
        |>;
        results = Map[ view, states, { 2 } ];
        window = <| Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, "/home/u/other", "OpenCode", <| "SSHSettings" -> remoteSSH[ ] |> ], "FolderPicker" -> ready |>;
        sigs = { fpStatusSig @ #, fpButtonsSig @ #, fpListSig @ # } &;
        {
            Select[ results, AnyTrue[ #, TrueQ @ #[ "Failed" ] & ] & ],
            MemberQ[ results[ "NoStore", "Status", "Strings" ], "Connecting to testhost\[Ellipsis]" ],
            results[ "NoStore", "Buttons", "Actions" ],
            MemberQ[ results[ "First", "Status", "Strings" ], "Connecting to testhost\[Ellipsis]" ],
            MemberQ[ results[ "Navigating", "Status", "Strings" ], "Listing ~/proj/a2\[Ellipsis]" ],
            results[ "Navigating", "List", "Actions" ],
            results[ "Navigating", "Buttons", "Actions" ],
            Normal @ Counts @ results[ "Ready", "List", "Actions" ],
            Sort @ results[ "Ready", "Buttons", "Actions" ],
            MemberQ[ results[ "Ready", "Buttons", "Strings" ], "Use /home/u/proj as the project folder" ],
            MemberQ[ results[ "Ready", "List", "Strings" ], "7 folders, 2 files" ],
            MemberQ[ results[ "Hidden", "List", "Strings" ], "8 folders, 3 files" ],
            Count[ results[ "Hidden", "List", "Actions" ], "FolderPickerEnter" ],
            Select[ results[ "Current", "Status", "Strings" ], StringMatchQ[ "Current folder" | "Link to /data/proj" ] ],
            MemberQ[ results[ #, "List", "Strings" ], # ] & /@ <|
                "Empty" -> "This folder is empty.", "NoFolders" -> "No folders in this folder.",
                "HiddenOnly" -> "This folder has only hidden items.", "Unreadable" -> "You can open this folder but not list its contents.",
                "Unlisted" -> "This folder can't be read over SSH (on a Mac, privacy settings may block it)."
            |>,
            MemberQ[ results[ "Fallback", "Status", "Strings" ], "~/gone doesn't exist anymore; showing ~/proj." ],
            { MemberQ[ results[ "Navigation", "Status", "Strings" ], "The folder ~/nope doesn't exist." ], results[ "Navigation", "Status", "Actions" ] },
            { textQ[ states[ "SSH", "Status" ], "testhost didn't accept your SSH key." ], results[ "SSH", "Status", "Actions" ], results[ "SSH", "Buttons", "Actions" ] },
            { MemberQ[ results[ "Timeout", "Status", "Strings" ], "Listing the folder on testhost took too long." ], results[ "Timeout", "Status", "Actions" ] },
            { textQ[ states[ "Failed", "Status" ], "sh: \:fffdoops" ], FreeQ[ ToBoxes @ states[ "Failed", "Status" ], s_String /; StringContainsQ[ s, "\:f7c1" ] ] },
            Select[ results[ "Caps", "List", "Strings" ], StringContainsQ[ "more" | "listed" | "items" ] ],
            Count[ results[ "Caps", "List", "Actions" ], "FolderPickerEnter" ],
            { results[ "Running", "Buttons", "Actions" ], MemberQ[ results[ "Running", "Buttons", "Strings" ], "The project folder can't be changed while the agent is working." ] },
            (* display-safe names *)
            FreeQ[ ToBoxes @ states[ "Ready", "List" ], s_String /; StringContainsQ[ s, "\:f7c1" | "\:202e" ] ],
            textQ[ states[ "Ready", "List" ], "\:fffdlinear" ],
            textQ[ states[ "Ready", "List" ], "rtl\:27e6U+202E\:27e7evil" ],
            MemberQ[ results[ "Odd", "Buttons", "Strings" ], "Use /home/u/rtl\:27e6U+202E\:27e7evil as the project folder" ],
            FreeQ[ ToBoxes @ states[ "Odd", "Buttons" ], s_String /; StringContainsQ[ s, "\:202e" ] ],
            (* rows: locked and unusable folders and files have no button; names never in button code *)
            Select[ stringsIn @ states[ "Ready", "List" ], StringMatchQ[ "You don't have permission to open this folder." | "Symbolic link" | "Broken symbolic link" | "This name is not valid UTF-8 text, so it can't be used in a path." ] ] // Union,
            FreeQ[ Cases[ states[ "Ready", "List" ], Button[ _, code_, ___ ] :> HoldComplete @ code, Infinity ], "a2" | "a10" ],
            (* signatures *)
            sigs[ window ] === sigs[ <| window, "LastActivity" -> 0, "Usage" -> <| "Used" -> 5 |>, "Turns" -> { "t1" } |> ],
            sigs[ window ] =!= sigs[ <| window, "FolderPicker" -> <| ready, "Version" -> 4 |> |> ]
        }
    ],
    {
        <| |>,
        True,
        { "FolderPickerCancel" },
        True,
        True,
        { },
        { "FolderPickerCancel" },
        { "FolderPickerEnter" -> 5 },
        { "FolderPickerCancel", "FolderPickerChoose" },
        True,
        True,
        True,
        6,
        { "Current folder", "Link to /data/proj" },
        <| "Empty" -> True, "NoFolders" -> True, "HiddenOnly" -> True, "Unreadable" -> True, "Unlisted" -> True |>,
        True,
        { True, { } },
        { True, { "FolderPickerRefresh", "FolderPickerCopyError" }, { "FolderPickerCancel" } },
        { True, { "FolderPickerRefresh" } },
        { True, True },
        {
            "Show 10 more folders", "and 4980 more files", "Only the first 1000 folders are listed. Type a path to open another one.",
            "This folder has more than 5000 other items."
        },
        50,
        { { "FolderPickerCancel" }, True },
        True,
        True,
        True,
        True,
        True,
        {
            "Broken symbolic link", "Symbolic link", "This name is not valid UTF-8 text, so it can't be used in a path.",
            "You don't have permission to open this folder."
        },
        True,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Views@@Tests/ACPFolderPicker.wlt:1354,1-1492,2"
]

(* Counts in the singular and the plural (templates "...One" for 1 in the text resources): the counts line, "and 1 more
   file" and "Show 1 more folder". The status line names the listed folder (display-safe; "~" for the home folder, "/"
   for the root; a long name shortened), with its path in the tooltip: the path field shows the start of a long path. *)
VerificationTest[
    headless @ Module[ { nbo, render, base, counted, named },
        nbo    = NotebookObject[ "acp-picker-counts" ];
        render = Function[ store,
            Block[
                {
                    $acpWindows = <| nbo -> <|
                        Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, "/home/u/other", "OpenCode", <| "SSHSettings" -> remoteSSH[ ] |> ],
                        "FolderPicker" -> store
                    |> |>
                },
                <| "Status" -> fpStatusView @ nbo, "List" -> fpListView @ nbo |>
            ]
        ];
        base = testStore[ "Status" -> "Ready", "Path" -> "/home/u/proj", "ListingStatus" -> "OK", "InputShown" -> "~/proj", "Version" -> 1 ];
        counted = Function[ { folders, files },
            Select[
                stringsIn @ render[
                    <|
                        base,
                        "Entries" -> Join[ Table[ testEntry[ "f" <> ToString @ i ], { i, folders } ], Table[ testEntry[ "x" <> ToString @ i <> ".txt", "File" ], { i, files } ] ],
                        "Counts"  -> <| "Folders" -> folders, "HiddenFolders" -> 0, "Files" -> files, "HiddenFiles" -> 0 |>
                    |>
                ][ "List" ],
                StringMatchQ[ (DigitCharacter.. ~~ " folder" ~~ ___) | ("Show " | "and ") ~~ ___ ]
            ]
        ];
        named = Function[ path, render[ <| base, "Path" -> path, "Entries" -> { } |> ][ "Status" ] ];
        {
            counted[ 1, 0 ],
            counted[ 1, 1 ],
            counted[ 0, 2 ],
            counted[ 2, 21 ],
            counted[ 51, 0 ],
            MemberQ[ stringsIn @ named[ "/home/u/proj" ], "proj" ],
            textQ[ named[ "/home/u/proj" ], "The folder shown: ~/proj" ],
            MemberQ[ stringsIn @ named[ "/home/u" ], "~" ],
            MemberQ[ stringsIn @ named[ "/" ], "/" ],
            MemberQ[ stringsIn @ named[ "/srv/rtl\:202eevil" ], "rtl\:27e6U+202E\:27e7evil" ],
            FreeQ[ ToBoxes @ named[ "/srv/rtl\:202eevil" ], s_String /; StringContainsQ[ s, "\:202e" ] ],
            MemberQ[ stringsIn @ named[ "/srv/" <> StringRepeat[ "n", 100 ] ], StringRepeat[ "n", 59 ] <> "\[Ellipsis]" ]
        }
    ],
    {
        { "1 folder, 0 files" },
        { "1 folder, 1 file" },
        { "0 folders, 2 files" },
        { "and 1 more file", "2 folders, 21 files" },
        { "Show 1 more folder", "51 folders, 0 files" },
        True,
        True,
        True,
        True,
        True,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Views-CountsAndName@@Tests/ACPFolderPicker.wlt:1497,1-1556,2"
]

(* A navigation error (a typed folder that doesn't exist) keeps the previous listing: the status line still names the
   listed folder (with its "Current folder" badge), above the red line; with no listing there is only the red line *)
VerificationTest[
    headless @ Module[ { nbo, base, error, status },
        nbo    = NotebookObject[ "acp-picker-navigation-error" ];
        base   = testStore[ "Status" -> "Ready", "Path" -> "/home/u/proj", "ListingStatus" -> "OK", "InputShown" -> "~/proj", "Version" -> 1, "Entries" -> { } ];
        error  = Wolfram`Chatbook`ACP`FolderPicker`Private`pickerError[ "Missing", "/home/u/nope", base ];
        status = Function[ store,
            Block[
                {
                    $acpWindows = <| nbo -> <|
                        Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, "/home/u/proj", "OpenCode", <| "SSHSettings" -> remoteSSH[ ] |> ],
                        "FolderPicker" -> store
                    |> |>
                },
                fpStatusView @ nbo
            ]
        ];
        {
            TrueQ @ error[ "Navigation" ],
            With[ { view = status @ <| base, "Error" -> error |> },
                { MemberQ[ stringsIn @ view, "proj" ], textQ[ view, error[ "Message" ] ], textQ[ view, "Current folder" ] }
            ],
            With[ { view = status @ <| base, "Status" -> "Error", "Path" -> None, "Error" -> error |> },
                { MemberQ[ stringsIn @ view, "proj" ], textQ[ view, error[ "Message" ] ] }
            ]
        }
    ],
    { True, { True, True, True }, { False, True } },
    SameTest -> MatchQ,
    TestID   -> "Views-NavigationErrorKeepsName@@Tests/ACPFolderPicker.wlt:1560,1-1589,2"
]

(* An ssh error in the picker: the full error view with "Try again" and a copy button that carries no text: "Copy
   command" for an unknown host key (its advice is to run the ssh command in a terminal), else "Copy" (the advice and
   ssh's text, as the toolbar's "Copy" gives them). The actions give what they copy (without a front end nothing is
   copied). *)
VerificationTest[
    headless @ Module[ { nbo, ssh, fixture, hostKey, auth, view, hostKeyView, copiedCommand, authView, copiedError },
        nbo     = newRemoteWindow[ None ];
        ssh     = remoteSSH[ ];
        fixture = ReadString @ FileNameJoin @ { DirectoryName @ $TestFileName, "Data", "ACP", "SSHErrors", # <> ".txt" } &;
        hostKey = acpSSHExitError[ 255, fixture[ "hostkey-unknown" ], <| "Setup" -> True, "SSH" -> ssh |> ];
        auth    = acpSSHExitError[ 255, fixture[ "auth-denied" ], <| "Setup" -> True, "SSH" -> ssh |> ];
        view    = Function[ error, acpWindowUpdate[ nbo, <| #, "FolderPicker" -> testStore[ "Status" -> "Error", "Error" -> error ] |> & ]; fpStatusView @ nbo ];
        (* each copy action reads the store's error, so it runs while its error is shown *)
        hostKeyView   = view @ hostKey;
        copiedCommand = pickerAction[ "FolderPickerCopyCommand", nbo ];
        authView      = view @ auth;
        copiedError   = pickerAction[ "FolderPickerCopyError", nbo ];
        {
            hostKey[ "Code" ],
            Sort @ actionsIn @ hostKeyView,
            copiedCommand === acpSSHTerminalCommand @ ssh,
            FreeQ[ Cases[ hostKeyView, HoldPattern @ Button[ _, code_, ___ ] :> HoldComplete @ code, Infinity ], _String? (StringContainsQ[ "testhost" ]) ],
            auth[ "Code" ],
            Sort @ actionsIn @ authView,
            copiedError === acpErrorParts[ auth ][ "Details" ],
            StringQ @ copiedError
        }
    ],
    {
        "SSHHostKeyUnknown",
        { "FolderPickerCopyCommand", "FolderPickerRefresh" },
        True,
        True,
        "SSHAuthFailed",
        { "FolderPickerCopyError", "FolderPickerRefresh" },
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Views-SSHErrorCopy@@Tests/ACPFolderPicker.wlt:1595,1-1631,2"
]

(* The header (a docked cell) wraps its lines: the "DockedCell" style turns line breaking off, the cell turns it on, so
   a long message never widens the header; the path field stays one line; "Show hidden" is on the host's line, so the
   status line has the header's whole width *)
VerificationTest[
    headless @ Module[ { nb, docked, options, boxes },
        nb      = acpFolderPickerNotebook[ NotebookObject[ "acp-picker-header" ], <| |>, remoteSSH[ "testhost", "Username" -> "u" ] ];
        docked  = First @ Lookup[ Association @ Cases[ List @@ Rest @ nb, _Rule | _RuleDelayed ], DockedCells ];
        options = Association @ Cases[ List @@ Rest @ docked, _Rule ];
        boxes   = First @ docked;
        {
            Lookup[ options, { LineBreakWithin, LineIndent } ],
            Cases[ boxes, InputFieldBox[ ___, HoldPattern[ BaseStyle -> s_ ], ___ ] :> Lookup[ Association @ Cases[ Flatten @ { s }, _Rule ], LineBreakWithin ], Infinity ],
            (* the host's row has the toggle *)
            Cases[
                boxes,
                GridBox[ { row_List }, ___ ] /; textQ[ row, "on u@testhost" ] :> ! FreeQ[ row, Wolfram`Chatbook`ACP`FolderPicker`Private`pickerToggleView ],
                Infinity
            ]
        }
    ],
    { { Automatic, 0 }, { False }, { True } },
    SameTest -> MatchQ,
    TestID   -> "Header-Layout@@Tests/ACPFolderPicker.wlt:1636,1-1656,2"
]

(* FE-only: in the picker's header (a docked cell, with its own options) a long fallback notice wraps at the window's
   width: rasterized, it makes the status line taller, not wider (skipped without a front end). No settings are read or
   written: the views are rendered from a window record in a Block. *)
VerificationTest[
    If[ $FrontEnd === Null,
        Missing[ "TestSkipped" ],
        Module[ { nbo, docked, size, long, short },
            nbo    = NotebookObject[ "acp-picker-wrap" ];
            docked = First @ Lookup[ Association @ Cases[ List @@ Rest @ acpFolderPickerNotebook[ nbo, <| |>, remoteSSH[ ] ], _Rule | _RuleDelayed ], DockedCells ];
            size   = Function[ notice,
                Block[
                    {
                        $acpWindows = <| nbo -> <|
                            Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, "/home/u/other", "OpenCode", <| "SSHSettings" -> remoteSSH[ ] |> ],
                            "FolderPicker" -> testStore[ "Status" -> "Ready", "Path" -> "/home/u/proj", "ListingStatus" -> "OK", "Entries" -> { }, "Notice" -> notice ]
                        |> |>
                    },
                    ImageDimensions @ Rasterize[
                        Cell[ BoxData @ PaneBox[ ToBoxes @ fpStatusView @ nbo, ImageSize -> { 300, Automatic } ], "DockedCell", Sequence @@ Rest @ docked ],
                        ImageResolution -> 72
                    ]
                ]
            ];
            long  = size @ StringRiffle[ ConstantArray[ "/tmp/a-b/c", 40 ], " " ];
            short = size @ "/tmp/a-b/c";
            { long[[ 1 ]] <= short[[ 1 ]], long[[ 2 ]] > 3 * short[[ 2 ]] }
        ]
    ],
    Missing[ "TestSkipped" ] | { True, True },
    SameTest -> MatchQ,
    TestID   -> "Header-Wraps-FEOnly@@Tests/ACPFolderPicker.wlt:1661,1-1689,2"
]

(* A listing whose result never arrives (a lost continuation): the store stays "Loading" with nothing scheduled, yet the
   pump keeps running (State.wl's publisherNeededQ) and the picker's housekeeping ends it with the timeout error once
   pickerLostAfter[] seconds have passed since it started *)
VerificationTest[
    headless @ Module[ { nbo, needed, started, result },
        nbo = newRemoteWindow[ None ];
        acpWindowUpdate[
            nbo,
            <|
                #,
                "FolderPicker" -> testStore[
                    "Status"  -> "Loading",
                    "Request" -> <| "Token" -> "lost", "Path" -> "~", "Kind" -> "Open", "StartedAt" -> AbsoluteTime[ ] - fpLostAfter[ ] + 3 |>
                ]
            |> &
        ];
        needed  = Wolfram`Chatbook`ACP`State`Private`publisherNeededQ @ acpWindowGet @ nbo;
        started = AbsoluteTime[ ];
        result  = waitUntil[ pickerOf[ nbo ][ "Status" ] =!= "Loading", 15 ];
        {
            needed,
            result,
            AbsoluteTime[ ] - started > 2.5,
            Lookup[ pickerOf @ nbo, { "Status", "Request" } ],
            Lookup[ pickerOf[ nbo ][ "Error" ], { "Code", "Message" } ],
            Wolfram`Chatbook`ACP`State`Private`publisherNeededQ @ acpWindowGet @ nbo
        }
    ],
    { True, True, True, { "Error", None }, { "Timeout", "Listing the folder on testhost took too long." }, False },
    SameTest -> MatchQ,
    TestID   -> "LostContinuation@@Tests/ACPFolderPicker.wlt:1694,1-1722,2"
]

(* The folder row of a remote window (UI.wl): host:path with the remote home abbreviated (strings in the label's boxes
   are quoted), the host and the whole path in the tooltip, warnings for the home folder, the root and a missing folder
   (from the window's error), and the folder (the label is the button) runs "ChooseDirectory" (the picker); a local
   window keeps the front end's directory dialog. Nothing is looked at on this computer for a remote folder. *)
VerificationTest[
    headless @ Module[ { nbo, remote, row, local },
        nbo    = NotebookObject[ "acp-picker-folder-row" ];
        remote = <|
            Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, "/remote/u/projects/app", "OpenCode", <| "SSHSettings" -> remoteSSH[ "ec2-203-0-113-100.compute-1.amazonaws.com", "Username" -> "ubuntu" ] |> ],
            "Status" -> "Ready", "RemoteHome" -> "/remote/u"
        |>;
        row = Block[ { $acpWindows = <| nbo -> # |> }, Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ nbo, # ] ] &;
        $localPathCalls = { };
        withLocalPathTrap[
            { "/remote" },
            {
                With[ { v = row @ remote },
                    {
                        MemberQ[ StringTrim[ #, "\"" ] & /@ stringsIn @ v, "ec2-203-0-113-1\[Ellipsis]:" ],
                        MemberQ[ StringTrim[ #, "\"" ] & /@ stringsIn @ v, "~/projects/app" ],
                        MemberQ[ stringsIn @ v, "Project folder on ubuntu@ec2-203-0-113-100.compute-1.amazonaws.com: /remote/u/projects/app" ],
                        actionsIn @ v,
                        FreeQ[ v, _FileNameSetter ]
                    }
                ],
                textQ[ row @ <| remote, "ProjectDirectory" -> "/remote/u" |>, "This is your home folder on ec2-203-0-113-100" ],
                textQ[ row @ <| remote, "ProjectDirectory" -> "/" |>, "This is the root folder of ec2-203-0-113-100" ],
                textQ[ row @ <| remote, "Error" -> <| "Code" -> "RemoteFolderMissing" |> |>, "This folder doesn't exist on ec2-203-0-113-100." ],
                textQ[ row @ <| remote, "ProjectDirectory" -> None, "Status" -> "NoDirectory" |>, "No project folder on ec2-203-0-113-100" ],
                $localPathCalls
            }
        ] ~Join~ {
            local = row @ <| Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, $localProject, "OpenCode", <| |> ], "Status" -> "Ready" |>;
            { FreeQ[ local, _FileNameSetter ], actionsIn @ local }
        }
    ],
    { { True, True, True, { "ChooseDirectory" }, True }, True, True, True, True, { }, { False, { "SetProjectDirectory" } } },
    SameTest -> MatchQ,
    TestID   -> "FolderRow@@Tests/ACPFolderPicker.wlt:1728,1-1763,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)

(* Closing an ACP window closes its picker and ends its listing; no run, picker store or connection is left *)
VerificationTest[
    headless @ Module[ { closed },
        closed = ifFakeSSH @ Module[ { nbo },
            nbo = newRemoteWindow[ None ];
            acpFolderPickerOpen @ nbo;
            { acpFolderPickerCloseWindow @ nbo, pickerOf @ nbo, waitUntil[ processRuns[ ] === <| |>, 15 ] }
        ];
        Scan[ acpDisconnect[ #, "TestCleanup" ] &, $windows ];
        Scan[ acpWindowDrop, $windows ];
        {
            closed,
            waitUntil[ processRuns[ ] === <| |>, 30 ],
            ifConnTests @ waitUntil[ Replace[ Quiet @ acpLink[ "ACPConnections" ][ ], Except[ _List ] -> { } ] === { }, 30 ],
            Select[ Values @ $acpWindows, AssociationQ @ Lookup[ #, "FolderPicker", None ] & ]
        }
    ],
    { Missing[ "TestSkipped" ] | { Null, None, True }, True, Missing[ "TestSkipped" ] | True, { } },
    SameTest -> MatchQ,
    TestID   -> "Cleanup-NoLeftovers@@Tests/ACPFolderPicker.wlt:1770,1-1789,2"
]

(* Isolated handlers and tasks swallow messages and failures into the debug log; nothing unexpected may have been logged *)
VerificationTest[
    headless @ Select[
        Internal`BagPart[ $acpDebugLog, All ],
        And[
            #[ "Time" ] >= $acpLogStart,
            MemberQ[ { "Message", "Uncaught", "FinalCellFailed", "FinalCellFallback", "FinishedFormattingFallback" }, #[ "Where" ] ]
        ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Cleanup-DebugLog@@Tests/ACPFolderPicker.wlt:1792,1-1803,2"
]

VerificationTest[
    headless[
        (* no ACP reader is active any more: permission bits can be restored with RunProcess *)
        If[ AssociationQ @ $fakeSSH, RunProcess[ { "chmod", "-R", "u+rwx", FileNameJoin @ { $home, "perm" } } ] ];
        If[ StringQ @ $names, RunProcess[ { "rm", "-rf", $names } ] ];
        Scan[ (acpRemoteClearHostError[ # ]; KeyDropFrom[ $acpRemoteHostAuthFailedAt, # ]) &, { "testhost", "x.slow.test", "x.hang.test", "otherhost" } ];
        Wolfram`Chatbook`ACP`Agents`Private`$headlessSettings = $savedHeadlessSettings;
        KeyDropFrom[ $acpAgents, "MockACPAgent" ];
        $acpGitEnabled        = $savedGitEnabled;
        $acpAssumeWindowsOpen = False;
        $acpLLMKitEnabled     = True;
        fakeSSHCleanup[ ];
        Quiet @ DeleteDirectory[ $scratch, DeleteContents -> True ];
        If[ TrueQ @ $setACPLinkEnv, SetEnvironment[ "ACPLINK_DIRECTORY" -> None ] ];
        { DirectoryQ @ $scratch, $fakeSSH, KeyExistsQ[ $acpAgents, "MockACPAgent" ], $acpRemoteHostErrors }
    ]
    ,
    { False, None, False, <| |> },
    SameTest -> MatchQ,
    TestID   -> "Cleanup-Restore@@Tests/ACPFolderPicker.wlt:1805,1-1825,2"
]

(* With a front end (CI's UsingFrontEnd, a notebook), no test wrote the front end's ACP preferences: every persisted
   write stayed in $headlessSettings. Not headless itself, and deferred work still queued runs first (with the front
   end, as it would after the file), so that a late write is seen here. Without a front end: None. *)
VerificationTest[
    If[ $fePreferences0 === None,
        None,
        waitUntil[ Wolfram`Chatbook`ACP`State`Private`$scheduled === { }, 5 ];
        Quiet @ CurrentValue[ $FrontEnd, $fePreferencesPath ]
    ],
    $fePreferences0,
    SameTest -> SameQ,
    TestID   -> "Cleanup-FrontEndPreferences@@Tests/ACPFolderPicker.wlt:1830,1-1839,2"
]

(* :!CodeAnalysis::EndBlock:: *)
