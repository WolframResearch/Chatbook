(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ACPRemote.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ACPRemote.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* Tests for remote windows (ACP/SSH.wl; see docs/acp-window.md): the "SSHSettings" setting, host identity, the ssh
   command, quoting and remote paths, the launch script and its markers, and the classification of ssh's exits. The pure
   tests always run. The tests that run shells or the fake ssh (Data/ACP/fake-ssh, set up by Data/ACP/FakeSSH.wl) are
   skipped on Windows or without /bin/sh (ifFakeSSH); they need neither ACPLink nor python, so they run in CI. The fixtures
   in Data/ACP/SSHErrors are OpenSSH 10.2's texts (ssh's own lines end in CR LF) and the launch script's stderr; those
   named *-windows hold Win32-OpenSSH's texts (8.1 and 9.x, from its sources). Nothing here needs or uses a front end:
   the code under test makes no front end calls, persists nothing and opens no windows. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    Needs[ "Wolfram`Chatbook`ACP`Common`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPRemote-LoadACPContext@@Tests/ACPRemote.wlt:33,1-38,2"
]

(* A test of its own, so that the tests after it are read with the helpers' context on $ContextPath *)
VerificationTest[
    Get @ FileNameJoin @ { DirectoryName @ $TestFileName, "Data", "ACP", "FakeSSH.wl" };
    MemberQ[ $ContextPath, "Wolfram`ChatbookTests`ACPFakeSSH`" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPRemote-LoadFakeSSH@@Tests/ACPRemote.wlt:41,1-47,2"
]

VerificationTest[
    (* CI runs every test file in one kernel and one context: helpers that other test files define too are cleared
       first, so that none of their definitions is used here *)
    ClearAll[ fileDescriptors, listingFixture, logSince, processRuns, remoteSSH, runShell, waitUntil, writeText ];

    $sshErrorsDirectory = FileNameJoin @ { DirectoryName @ $TestFileName, "Data", "ACP", "SSHErrors" };
    $scratch = CreateDirectory[ ];
    If[ TrueQ @ $fakeSSHAvailableQ, fakeSSHSetup @ FileNameJoin @ { $scratch, "fake" } ];

    (* Anything logged as a message or failure after this point is unexpected (Cleanup-DebugLog) *)
    $acpLogStart = AbsoluteTime[ ];

    $nonce = "0123456789abcdef";
    $tricky = "it's \"q\" $HOME `x` \\ \[Alpha] ~. -x ;id";

    sshSettings = Wolfram`Chatbook`Common`acpSSHSettings;
    reason[ Failure[ _, as_Association ] ] := as[ "Reason" ];
    reason[ other_ ] := other;

    (* A fixture of Data/ACP/SSHErrors as it was written (CR LF kept; readFileBytes: ReadByteArray[file] can reuse an open
       stream of the file) *)
    fixture[ name_String ] := ByteArrayToString[ readFileBytes @ FileNameJoin @ { $sshErrorsDirectory, name <> ".txt" }, "UTF-8" ];

    (* The debug log entries since t0 *)
    logSince[ t0_ ] := Select[ Internal`BagPart[ $acpDebugLog, All ], #[ "Time" ] >= t0 & ];

    (* A result with a scratch home folder written as "HOME" *)
    withoutHome[ home_String ][ s_String ] := StringReplace[ s, home -> "HOME" ];
    withoutHome[ home_String ][ expr: _List | _Association ] := withoutHome[ home ] /@ expr;
    withoutHome[ home_String ][ expr_ ] := expr;

    (* The fastest of three timings *)
    minTiming // Attributes = { HoldFirst };
    minTiming[ eval_ ] := Min @ Table[ First @ AbsoluteTiming @ eval, 3 ];

    $shells = Select[
        { { "/bin/sh" }, { "/bin/bash" }, { "/usr/bin/busybox", "sh" }, { "/bin/busybox", "sh" } },
        FileExistsQ @ First @ # &
    ];
    $shells = DeleteDuplicatesBy[ $shells, Last ];

    (* The single-quoted body of the bootstrap (what the remote /bin/sh runs) *)
    $bootstrapBody = First @ StringCases[ $acpSSHLaunchCommand, "'" ~~ body__ ~~ "'" :> body ];

    (* Runs a shell with arguments in a clean environment (vars), with standard input from a file holding input and
       standard output and error in files: <| "ExitCode", "Output" -> ByteArray, "Error" -> String |> *)
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
        <|
            "ExitCode" -> code,
            "Output"   -> readFileBytes @ out,
            "Error"    -> ByteArrayToString[ readFileBytes @ err, "UTF-8" ]
        |>
    ];

    (* Runs a launch script through the bootstrap's body under a shell, as the remote login shell would *)
    runLaunch[ shell_List, script_String, rest_String, home_String, vars_Association: <| |> ] :=
        runShell[ shell, { "-c", $bootstrapBody }, script <> rest, home, <| "HOME" -> home, vars |> ];

    (* A fake remote home for the launch script: folders "proj" and "odd dir's", a file "afile", executable programs
       .local/bin/tool, bin2/tool2 and proj/sub/tool3 that print their name and PATH *)
    makeHome[ name_String ] := Module[ { home },
        home = CreateDirectory @ FileNameJoin @ { $scratch, name };
        RunProcess[
            {
                "/bin/sh", "-c",
                "mkdir -p proj/sub \"odd dir's\" .local/bin bin2 && : > afile && " <>
                "for f in .local/bin/tool bin2/tool2 proj/sub/tool3; do " <>
                "printf '#!/bin/sh\\nprintf \"%%s:%%s\\\\n\" \"${0##*/}\" \"$PATH\"\\n' > \"$f\"; chmod 755 \"$f\"; done"
            },
            ProcessDirectory -> home
        ];
        home
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPRemote-Definitions@@Tests/ACPRemote.wlt:49,1-136,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Settings*)
VerificationTest[
    {
        sshSettings @ <|
            "Username"    -> "ubuntu",
            "MachineName" -> "ec2-203-0-113-100.compute-1.amazonaws.com",
            "Arguments"   -> { "-i", "C:/Users/rhennigan/keys/aws_key.pem" }
        |>,
        sshSettings @ { "MachineName" -> " devbox ", "Arguments" -> { "-i", File[ "~/k" ] }, "Executable" -> File[ "/tmp/fake-ssh" ] },
        sshSettings @ { "MachineName" :> "devbox", "Username" -> None, "Arguments" -> None, "Executable" -> None },
        sshSettings @ <| "MachineName" -> File[ "devbox" ], "Arguments" -> Automatic |>,
        sshSettings @ "devbox",
        sshSettings @ "ubuntu@devbox",
        Lookup[ sshSettings @ <| "MachineName" -> "me@10.0.0.5" |>, { "Username", "MachineName" } ],
        Lookup[ sshSettings @ <| "MachineName" -> "me@corp.example@h1" |>, { "Username", "MachineName" } ],
        sshSettings[ <| "MachineName" -> "fe80::1%eth0" |> ][ "MachineName" ],
        sshSettings[ <| "MachineName" -> "[::1]" |> ][ "MachineName" ],
        sshSettings[ <| "MachineName" -> "h", "Username" -> # |> ][ "Username" ] & /@ { "ubuntu", "user@dom.com", "first.last", "x_y-z", "\[EAcute]mile" },
        sshSettings /@ { None, Automatic },
        With[ { s = sshSettings @ <| "MachineName" -> "u@h", "Arguments" -> { "-p", "2" } |> }, sshSettings @ s === s ],
        Keys @ sshSettings @ <| "Executable" -> "ssh", "Arguments" -> { }, "MachineName" -> "h" |>
    },
    {
        <|
            "MachineName" -> "ec2-203-0-113-100.compute-1.amazonaws.com",
            "Username"    -> "ubuntu",
            "Arguments"   -> { "-i", "C:/Users/rhennigan/keys/aws_key.pem" },
            "Executable"  -> Automatic
        |>,
        <| "MachineName" -> "devbox", "Username" -> Automatic, "Arguments" -> { "-i", "~/k" }, "Executable" -> "/tmp/fake-ssh" |>,
        <| "MachineName" -> "devbox", "Username" -> Automatic, "Arguments" -> { }, "Executable" -> Automatic |>,
        <| "MachineName" -> "devbox", "Username" -> Automatic, "Arguments" -> { }, "Executable" -> Automatic |>,
        <| "MachineName" -> "devbox", "Username" -> Automatic, "Arguments" -> { }, "Executable" -> Automatic |>,
        <| "MachineName" -> "devbox", "Username" -> "ubuntu", "Arguments" -> { }, "Executable" -> Automatic |>,
        { "me", "10.0.0.5" },
        { "me@corp.example", "h1" },
        "fe80::1%eth0",
        "[::1]",
        { "ubuntu", "user@dom.com", "first.last", "x_y-z", "\[EAcute]mile" },
        { None, None },
        True,
        { "MachineName", "Username", "Arguments", "Executable" }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Settings-Valid@@Tests/ACPRemote.wlt:141,1-185,2"
]

VerificationTest[
    {
        reason @ sshSettings @ <| "MachineName" -> "h", "Port" -> 22 |>,
        reason @ sshSettings @ <| "Username" -> "u" |>,
        reason /@ (sshSettings @ <| "MachineName" -> # |> & /@ { "a;b", "a b", "a$b", "a'b", "a|b", "a/b", "a,b", "a*b", "h\nx" }),
        reason /@ (sshSettings @ <| "MachineName" -> # |> & /@ { "-oProxyCommand=touch /tmp/x", StringRepeat[ "a", 256 ], "", 42, "@h" }),
        reason @ sshSettings @ <| "MachineName" -> "a@h", "Username" -> "b" |>,
        reason /@ (sshSettings @ <| "MachineName" -> "h", "Username" -> # |> & /@ { "-x", "a b", "a;b", "a`b", "a$", "a\\" }),
        reason /@ (sshSettings @ <| "MachineName" -> "h", "Arguments" -> # |> & /@ { "-i key", { "-p", 22 } }),
        reason /@ (sshSettings @ <| "MachineName" -> "h", "Arguments" -> # |> & /@ { { "-i", "a\nb" }, { "-v\t" } }),
        reason /@ (sshSettings @ <| "MachineName" -> "h", "Executable" -> # |> & /@ { 1, "", "a\nb" }),
        reason /@ { sshSettings @ 42, sshSettings @ File[ "h" ] },
        reason /@ (sshSettings @ <| "MachineName" -> "h", "Arguments" -> # |> & /@ {
            { "myhost" }, { "-i", "k", "otherhost" }, { "--" }, { "-N" }, { "-vN" }, { "-n" }, { "-f" }, { "-M" }, { "-s" },
            { "-W", "h:22" }, { "-o", "StdinNull=yes" }, { "-oSessionType none" }, { "-o", "ForkAfterAuthentication yes" },
            { "-Z" }, { "-i" }, { "-o", "StrictHostKeyChecking=no" }, { "-oStrictHostKeyChecking accept-new" },
            { "-o", "CheckHostIP=yes" }, { "-o", "BatchMode=no" }, { "-o", "ForwardAgent=yes" }
        }),
        reason /@ (sshSettings @ <| "MachineName" -> "h", "Arguments" -> # |> & /@ {
            { "-" }, { "-o", "GSSAPIDelegateCredentials=yes" }, { "-o", "UpdateHostKeys=yes" }, { "-o", "ForwardX11 yes" },
            { "-o", "ClearAllForwardings=no" }, { "-o", "RemoteCommand=ls" }, { "-o", "PermitLocalCommand=yes" },
            { "-o", "ControlMaster=auto" }, { "-o", "ControlPath=/tmp/cm" }, { "-o", "StrictHostKeyChecking=\"no\"" },
            { "-o", "STRICTHOSTKEYCHECKING = false" }, { "-o", "StrictHostKeyChecking" }, { "-O", "exit" }, { "-G" }
        }),
        sshSettings[ <| "MachineName" -> "h", "Arguments" -> { "-N" } |> ][ "Detail" ],
        sshSettings[ <| "MachineName" -> "h", "Arguments" -> { "-o", "StrictHostKeyChecking=no" } |> ][ "Detail" ],
        sshSettings[ <| "MachineName" -> "h", "Arguments" -> { "-o", "ForwardAgent=yes" } |> ][ "Detail" ],
        sshSettings[ <| "MachineName" -> "h", "Arguments" -> { "myhost" } |> ][ "Detail" ],
        Lookup[ Last @ sshSettings @ <| "MachineName" -> "h", "Port" -> 22 |>, { "MessageTemplate", "MessageParameters", "Key", "Value" } ],
        (* -S replaces an earlier ControlPath (-o is first-wins): refused like -o ControlPath, except none (as ssh compares
           it: in any case, but not trimmed or unquoted); localhost's host key is checked too *)
        reason /@ (sshSettings @ <| "MachineName" -> "h", "Arguments" -> # |> & /@ {
            { "-S", "/tmp/ctl" }, { "-S/tmp/ctl" }, { "-vS", "/x" }, { "-vS/x" }, { "-S", "\"none\"" }, { "-S", " none" },
            { "-o", "NoHostAuthenticationForLocalhost=yes" }, { "-oNoHostAuthenticationForLocalhost yes" }
        }),
        Lookup[ Last @ sshSettings @ <| "MachineName" -> "h", "Arguments" -> { "-vS", "/tmp/ctl" } |>, { "Value", "Detail" } ],
        sshSettings[ <| "MachineName" -> "h", "Arguments" -> { "-o", "NoHostAuthenticationForLocalhost=yes" } |> ][ "Detail" ]
    },
    {
        "UnknownKey",
        "MissingMachineName",
        ConstantArray[ "InvalidMachineName", 9 ],
        Append[ ConstantArray[ "InvalidMachineName", 4 ], "InvalidUsername" ],
        "AmbiguousUsername",
        ConstantArray[ "InvalidUsername", 6 ],
        { "InvalidArguments", "InvalidArguments" },
        { "InvalidArgument", "InvalidArgument" },
        ConstantArray[ "InvalidExecutable", 3 ],
        { "NotAnAssociation", "NotAnAssociation" },
        ConstantArray[ "UnsupportedArgument", 20 ],
        ConstantArray[ "UnsupportedArgument", 14 ],
        "the ssh option -N can't be used: Chatbook runs its own command over each connection and sends it input",
        "Chatbook sets the ssh option StrictHostKeyChecking itself: it always checks host keys and never changes known_hosts",
        "Chatbook sets the ssh option ForwardAgent itself: use -A, -X or -K to turn forwarding on",
        "\"myhost\" is not an ssh option: give the host with \"MachineName\" (Chatbook adds the command)",
        { "`Detail`", <| "Detail" -> _String |>, "Port", 22 },
        ConstantArray[ "UnsupportedArgument", 8 ],
        { "-S /tmp/ctl", "Chatbook sets the ssh option ControlPath itself: it uses one connection per operation" },
        "Chatbook sets the ssh option NoHostAuthenticationForLocalhost itself: it always checks host keys and never changes known_hosts"
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Settings-Invalid@@Tests/ACPRemote.wlt:187,1-249,2"
]

VerificationTest[
    sshSettings[ <| "MachineName" -> "h", "Arguments" -> # |> ][ "Arguments" ] & /@ {
        { "-p", "2222" },
        { "-p2222", "-vq" },
        { "-o", "StrictHostKeyChecking=yes" },
        { "-o", "stricthostkeychecking true" },
        { "-J", "jump@bastion" },
        { "-F", "C:/Users/me/.ssh/config", "-i", "a b.pem" },
        { "-o", "ProxyCommand=ssh -W %h:%p bastion" },
        { "-i", "-N" },
        { "-A" },
        { "-K" },
        (* the values Chatbook sets itself; VerifyHostKeyDNS is the user's (SSHFP records in DNSSEC are a host key check);
           -E and -y are allowed (they take ssh's messages out of stderr, like -q) *)
        { "-S", "none" },
        { "-vSNONE" },
        { "-o", "NoHostAuthenticationForLocalhost=no" },
        { "-o", "VerifyHostKeyDNS=yes" },
        { "-E", "C:/Users/me/ssh.log", "-y" }
    },
    {
        { "-p", "2222" },
        { "-p2222", "-vq" },
        { "-o", "StrictHostKeyChecking=yes" },
        { "-o", "stricthostkeychecking true" },
        { "-J", "jump@bastion" },
        { "-F", "C:/Users/me/.ssh/config", "-i", "a b.pem" },
        { "-o", "ProxyCommand=ssh -W %h:%p bastion" },
        { "-i", "-N" },
        { "-A" },
        { "-K" },
        { "-S", "none" },
        { "-vSNONE" },
        { "-o", "NoHostAuthenticationForLocalhost=no" },
        { "-o", "VerifyHostKeyDNS=yes" },
        { "-E", "C:/Users/me/ssh.log", "-y" }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Settings-AllowedArguments@@Tests/ACPRemote.wlt:251,1-290,2"
]

(* "@" is a string-pattern metacharacter: (LetterCharacter | "@").. matches "a b" *)
VerificationTest[
    {
        reason /@ (sshSettings @ <| "MachineName" -> "h", "Username" -> # |> & /@ { "a b", "a;b", "a*b" }),
        reason /@ (sshSettings /@ { "a b@h", "a;b@h" }),
        StringMatchQ[ "a b", (LetterCharacter | "@")..]
    },
    {
        { "InvalidUsername", "InvalidUsername", "InvalidUsername" },
        { "InvalidUsername", "InvalidUsername" },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Settings-AtPitfall@@Tests/ACPRemote.wlt:293,1-306,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Host identity*)
VerificationTest[
    acpSSHHostKey @* sshSettings /@ {
        <| "MachineName" -> "EC2-203-0-113-100.compute-1.amazonaws.com", "Username" -> "ubuntu", "Arguments" -> { "-i", "C:/k.pem" } |>,
        <| "MachineName" -> "devbox", "Arguments" -> { "-p", "2222" } |>,
        <| "MachineName" -> "10.0.0.5", "Username" -> "me", "Arguments" -> { "-p2200" } |>,
        <| "MachineName" -> "h", "Arguments" -> { "-o", "Port=2201", "-p", "9" } |>,
        <| "MachineName" -> "h", "Arguments" -> { "-oPort 2202" } |>,
        <| "MachineName" -> "h", "Arguments" -> { "-i", "-p" } |>,
        <| "MachineName" -> "h", "Arguments" -> { "-vp2202" } |>,
        <| "MachineName" -> "h", "Arguments" -> { "-p", "22" } |>,
        <| "MachineName" -> "h", "Arguments" -> { "-o", "Port=22" } |>,
        <| "MachineName" -> "h", "Arguments" -> { "-l", "bob" } |>,
        <| "MachineName" -> "h", "Arguments" -> { "-vqlcarol" } |>,
        <| "MachineName" -> "h", "Arguments" -> { "-o", "User=carol", "-l", "bob" } |>,
        <| "MachineName" -> "h", "Arguments" -> { "-oUser=carol" } |>,
        <| "MachineName" -> "h", "Arguments" -> { "-o", "User carol", "-p", "2222" } |>,
        <| "MachineName" -> "h", "Arguments" -> { "-l", "a", "-l", "b" } |>,
        <| "MachineName" -> "h", "Username" -> "u", "Arguments" -> { "-l", "bob" } |>,
        <| "MachineName" -> "bob@H", "Arguments" -> { "-p", "2222" } |>,
        "Devbox"
    },
    {
        "ubuntu@ec2-203-0-113-100.compute-1.amazonaws.com",
        "devbox:2222",
        "me@10.0.0.5:2200",
        "h:2201",
        "h:2202",
        "h",
        "h:2202",
        "h",
        "h",
        "bob@h",
        "carol@h",
        "carol@h",
        "carol@h",
        "carol@h:2222",
        "a@h",
        "u@h",
        "bob@h:2222",
        "devbox"
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-HostKey@@Tests/ACPRemote.wlt:311,1-354,2"
]

VerificationTest[
    {
        acpSSHHostLabel @ sshSettings @ "ubuntu@EC2.Example.com",
        acpSSHHostLabel @ sshSettings @ <| "MachineName" -> "Devbox", "Arguments" -> { "-l", "bob" } |>,
        acpSSHHostLabel /@ { None, Failure[ "x", <| |> ] }
    },
    { "ubuntu@EC2.Example.com", "Devbox", { None, None } },
    SameTest -> MatchQ,
    TestID   -> "Remote-HostLabel@@Tests/ACPRemote.wlt:356,1-365,2"
]

VerificationTest[
    {
        acpSSHShortHost @* sshSettings /@ {
            "ec2-203-0-113-100.compute-1.amazonaws.com", "203.0.113.100", "devbox", "fe80::1", "[::1]", "fe80::1%eth0",
            "u@build.example.com"
        },
        acpSSHShortHost @ None
    },
    { { "ec2-203-0-113-100", "203.0.113.100", "devbox", "fe80::1", "[::1]", "fe80::1%eth0", "build" }, None },
    SameTest -> MatchQ,
    TestID   -> "Remote-ShortHost@@Tests/ACPRemote.wlt:367,1-378,2"
]

VerificationTest[
    With[ { ssh = sshSettings @ <| "MachineName" -> "u@Host.Example.com", "Arguments" -> { "-p", "2222" } |>, bad = sshSettings @ "-x" },
        {
            acpSSHPreferenceKey @ ssh,
            acpLastProjectDirectoryKey @ ssh,
            acpRemoteHomeKey @ ssh,
            acpLastProjectDirectoryKey @ None,
            FailureQ @ bad,
            acpSSHPreferenceKey /@ { bad, None },
            acpLastProjectDirectoryKey @ bad,
            acpRemoteHomeKey /@ { bad, None }
        }
    ],
    {
        { "SSH", "u@host.example.com:2222" },
        { "SSH", "u@host.example.com:2222", "LastProjectDirectory" },
        { "SSH", "u@host.example.com:2222", "Home" },
        { "LastProjectDirectory" },
        True,
        { None, None },
        None,
        { None, None }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-PreferenceKey@@Tests/ACPRemote.wlt:380,1-405,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Accessors*)
VerificationTest[
    Module[ { local, none, remote, invalid, short, nbo = NotebookObject[ "acp-remote-test-window" ] },
        local   = <| "Settings" -> <| "ACPModel" -> "m" |>, "RemoteHome" -> "/home/u" |>;
        none    = <| "Settings" -> <| "SSHSettings" -> None |> |>;
        remote  = <| "Settings" -> <| "SSHSettings" -> sshSettings @ "u@devbox.example.com" |>, "RemoteHome" -> "/home/u" |>;
        invalid = <| "Settings" -> <| "SSHSettings" -> <| "MachineName" -> "-x" |> |>, "RemoteHome" -> "relative" |>;
        short   = <| "Settings" -> <| "SSHSettings" -> "devbox" |> |>;
        Block[ { Wolfram`Chatbook`ACP`Common`$acpWindows = <| nbo -> remote |> },
            {
                acpWindowSSH /@ { local, none, <| |>, 42 },
                acpWindowSSH @ remote,
                FailureQ @ acpWindowSSH @ invalid,
                acpWindowSSH[ short ][ "MachineName" ],
                acpWindowSSH[ nbo ][ "Username" ],
                acpWindowSSH @ NotebookObject[ "acp-remote-test-unknown" ],
                acpRemoteQ /@ { local, none, remote, invalid, short, nbo },
                acpSettingsSSH /@ { <| "SSHSettings" -> "h" |>, <| |>, None },
                acpWindowHostKey /@ { local, remote, invalid, nbo },
                acpWindowHostLabel /@ { local, remote, invalid },
                acpWindowShortHost /@ { local, remote, invalid },
                acpWindowRemoteHome /@ {
                    local, remote, invalid, nbo, <| "RemoteHome" -> "/a\nb" |>,
                    <| "RemoteHome" -> "/" <> StringRepeat[ "a", 5000 ] |>, <| |>, None
                },
                acpPathContext @ local,
                acpPathContext @ remote,
                acpPathContext @ invalid,
                acpNormalizeProjectDirectory[ " ~/proj/ ", remote ],
                acpNormalizeProjectDirectory[ "~/proj", invalid ],
                acpNormalizeProjectDirectory[ "/srv/app/", sshSettings @ "h", None ],
                acpNormalizeProjectDirectory[ File[ " " <> $TemporaryDirectory <> " " ], None, None ] === ExpandFileName @ $TemporaryDirectory,
                acpNormalizeProjectDirectory[ "~/x", nbo ]
            }
        ]
    ],
    {
        { None, None, None, None },
        <| "MachineName" -> "devbox.example.com", "Username" -> "u", "Arguments" -> { }, "Executable" -> Automatic |>,
        True,
        "devbox",
        "u",
        None,
        { False, False, True, True, True, True },
        { KeyValuePattern[ "MachineName" -> "h" ], None, None },
        { None, "u@devbox.example.com", "?", "u@devbox.example.com" },
        { None, "u@devbox.example.com", "?" },
        { None, "devbox", "?" },
        { "/home/u", "/home/u", None, "/home/u", None, None, None, None },
        <| "Remote" -> False, "Host" -> None, "HostLabel" -> None, "Home" -> $HomeDirectory |>,
        <| "Remote" -> True, "Host" -> "devbox", "HostLabel" -> "u@devbox.example.com", "Home" -> "/home/u" |>,
        <| "Remote" -> True, "Host" -> "?", "HostLabel" -> "?", "Home" -> None |>,
        "/home/u/proj",
        "~/proj",
        "/srv/app",
        True,
        "/home/u/x"
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Accessors@@Tests/ACPRemote.wlt:410,1-469,2"
]

(* Local folders must exist; remote ones are only checked for their form, never on the local disk *)
VerificationTest[
    With[ { ssh = sshSettings @ "h", missing = FileNameJoin @ { $TemporaryDirectory, "no-such-folder-" <> CreateUUID[ ] } },
        {
            acpProjectDirectoryQ[ #, None ] & /@ { $TemporaryDirectory, missing, "", "  ", None, 42 },
            acpProjectDirectoryQ[ #, ssh ] & /@ { "~", "~/x", "/srv/x", missing, "/", "relative", "~bob", "~bob/x", "/a\nb", "/a\tb", "", None },
            acpProjectDirectoryQ[ "~/x", Failure[ "InvalidSSHSettings", <| |> ] ],
            Wolfram`Chatbook`Common`acpRemoteProjectDirectoryQ /@ {
                "/" <> StringRepeat[ "a", 4095 ],
                "/" <> StringRepeat[ "a", 4096 ],
                "~/x\n",
                "/x\:007f",
                "C:\\x",
                File[ "/x" ]
            },
            Internal`InheritedBlock[ { DirectoryQ },
                Unprotect @ DirectoryQ;
                DirectoryQ[ p_String ] /; StringStartsQ[ p, "/remote-only" ] := (Sow[ p ]; False);
                Reap[ acpProjectDirectoryQ[ "/remote-only/x", ssh ] ]
            ]
        }
    ],
    {
        { True, False, False, False, False, False },
        { True, True, True, True, True, False, False, False, False, False, False, False },
        True,
        { True, False, False, False, False, False },
        { True, { } }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-ProjectDirectoryQ@@Tests/ACPRemote.wlt:472,1-502,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Remote paths*)
VerificationTest[
    {
        acpRemoteAbbreviate[ #, "/home/u" ] & /@ { "/home/u/x", "/home/u", "/home/u/", "/home/u2/x", "/srv/x", "~/x" },
        acpRemoteAbbreviate[ "/home/u/x", # ] & /@ { None, "/", "relative", "/home/u/" },
        acpRemoteExpandHome[ #, "/home/u" ] & /@ { "~", "~/x", "~/", "/srv", "~bob/x", "x" },
        acpRemoteExpandHome[ #, "/" ] & /@ { "~", "~/x" },
        acpRemoteExpandHome[ "~/x", # ] & /@ { None, "relative" },
        acpRemoteNormalizeDirectory[ #, "/home/u" ] & /@ {
            " ~/proj/ ", File[ "/srv/app//" ], "/", "//", "~", "~/", "/home/x", "C:\\x", "", "   ", None, 42
        },
        acpRemoteNormalizeDirectory[ "~/proj", None ],
        acpRemoteNormalizeDirectory[ "/srv/ends with space ", None, "Raw" -> True ],
        acpRemoteNormalizeDirectory[ "/srv/ends with space ", None ],
        acpRemoteNormalizeDirectory[ "~/a ", "/home/u", "Raw" -> True ],
        acpRemoteLexicalPath /@ { "/a/./b/../c//", "/", "/..", "/a/b/", "//x", "rel/../x" },
        acpRemoteParent /@ { "/a/b", "/a", "/", "/a//b//", "~/x", "~", "/a/b/.." },
        { acpRemoteChild[ "/", "x" ], acpRemoteChild[ "/a", "b" ], acpRemoteChild[ "/a/", "b" ], acpRemoteChild[ "~", "x" ] },
        acpRemotePathName /@ { "/a/b", "/a/b/", "/", "~", "/a" },
        acpRemoteAbsolutePathQ /@ {
            "/x", "/", "/" <> StringRepeat[ "a", 4095 ], "/" <> StringRepeat[ "a", 4096 ], "x", "~/x", "/a\nb", "/a\rb", "/a\:0000", None
        },
        acpRemoteFolderLabel[ "ec2-203-0-113-100", "/home/ubuntu/projects/my-app", "/home/ubuntu", 42 ],
        acpRemoteFolderLabel[ "devbox", "/home/ubuntu/projects/some/deeply/nested/folder/structure/app", "/home/ubuntu", 42 ],
        acpRemoteFolderLabel[ "devbox", "/srv/new\nline", None, 20 ],
        Wolfram`Chatbook`Common`acpRemoteCommandLineQ /@ {
            Automatic, "opencode", File[ "/opt/oc" ], "~/.opencode/bin/opencode", { "/opt/oc", "acp" }, { File[ "oc" ], "acp", "" },
            "", "  ", "-x", "~bob/oc", { "-x" }, { "oc", "a\nb" }, "oc\n", { }, { "oc", 1 }, 42, None
        }
    },
    {
        { "~/x", "~", "~/", "/home/u2/x", "/srv/x", "~/x" },
        { "/home/u/x", "/home/u/x", "/home/u/x", "~/x" },
        { "/home/u", "/home/u/x", "/home/u/", "/srv", "~bob/x", "x" },
        { "/", "/x" },
        { "~/x", "~/x" },
        { "/home/u/proj", "/srv/app", "/", "/", "/home/u", "/home/u", "/home/x", "C:\\x", None, None, None, None },
        "~/proj",
        "/srv/ends with space ",
        "/srv/ends with space",
        "/home/u/a ",
        { "/a/c", "/", "/", "/a/b", "/x", "rel/../x" },
        { "/a", "/", "/", "/a", "~", "~", "/" },
        { "/x", "/a/b", "/a/b", "~/x" },
        { "b", "b", "/", "~", "a" },
        { True, True, True, False, False, False, False, False, False, False },
        { "ec2-203-0-113-1\[Ellipsis]", "~/projects/my-app" },
        { "devbox", "\[Ellipsis]/nested/folder/structure/app" },
        { "devbox", "/srv/new\:2424line" },
        { True, True, True, True, True, True, False, False, False, False, False, False, False, False, False, False, False }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Paths@@Tests/ACPRemote.wlt:507,1-559,2"
]

(* The folder row's label (and the review window's header): the folder's own name is never cut: "\[Ellipsis]/" and as many
   of the last names as fit in the room the host leaves (at least 12 characters); a name that alone is too long loses its
   middle. Display-safe, and never longer than the room. *)
VerificationTest[
    Module[ { scratch, room },
        scratch = "/tmp/build-00001/-home-ubuntu-Projects/00000000-1111-2222-3333-444444444444/scratchpad/remoteproj";
        room    = Max[ 12, #2 - StringLength[ #1 ] - 1 ] &;
        {
            acpRemoteFolderLabel[ "127.0.0.1", scratch, None, 30 ],
            acpRemoteFolderLabel[ "127.0.0.1", scratch, None, 42 ],
            acpRemoteFolderLabel[ "127.0.0.1", scratch, None, 0 ],
            acpRemoteFolderLabel[ "h", "/srv/" <> StringRepeat[ "n", 50 ], None, 30 ],
            acpRemoteFolderLabel[ "h", "/srv/a/rtl\:202eevil", None, 20 ],
            acpRemoteFolderLabel[ "h", #, "/home/u", 20 ] & /@ { "/", "/home/u", "/home/u/x" },
            (* never longer than the room, always ending with the whole name when it fits *)
            AllTrue[
                Tuples[ { { "h", "127.0.0.1", "ec2-203-0-113-100" }, { scratch, "/a/bb/ccc/dddd/eeeee/ffffff", "/" <> StringRepeat[ "x", 40 ] }, { 0, 20, 30, 42, 80 } } ],
                Function[ t,
                    With[ { label = acpRemoteFolderLabel[ t[[ 1 ]], t[[ 2 ]], None, t[[ 3 ]] ], name = acpRemotePathName @ t[[ 2 ]] },
                        And[
                            StringLength @ label[[ 2 ]] <= room[ label[[ 1 ]], t[[ 3 ]] ],
                            label[[ 2 ]] === t[[ 2 ]] || StringEndsQ[ label[[ 2 ]], "/" <> name ] || StringLength @ name + 2 > room[ label[[ 1 ]], t[[ 3 ]] ]
                        ]
                    ]
                ]
            ]
        }
    ],
    {
        { "127.0.0.1", "\[Ellipsis]/remoteproj" },
        { "127.0.0.1", "\[Ellipsis]/scratchpad/remoteproj" },
        { "127.0.0.1", "\[Ellipsis]/remoteproj" },
        { "h", "\[Ellipsis]/" <> StringRepeat[ "n", 13 ] <> "\[Ellipsis]" <> StringRepeat[ "n", 12 ] },
        { "h", "\[Ellipsis]/rtl\:27e6U+202E\:27e7evil" },
        { { "h", "/" }, { "h", "~" }, { "h", "~/x" } },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-FolderLabel@@Tests/ACPRemote.wlt:564,1-600,2"
]

VerificationTest[
    {
        acpRemoteDisplayName[ "a\nb\rc\td\:0001e\:007ff\:001bg" ],
        acpRemoteDisplayName[ "evil\:202etxt.exe\:200b\:0085x" ],
        acpRemoteDisplayName /@ { "\:2066a\:2069", "\:feffbom", "\:200f", "\:2060" },
        (* the last bidi control (ALM), the line and paragraph separators, and invisible characters and fillers *)
        acpRemoteDisplayName /@ { "ab\:061ccd", "a\:2028b\:2029c", "a\:3164b" },
        acpRemoteDisplayName[ "\:00ad\:034f\:115f\:1160\:180e\:ffa0" ],
        acpRemoteDisplayName /@ { "\:05e9\:05dc\:05d5\:05dd", "\:0645\:0631\:062d\:0628\:0627", "\:0645\:0631\:062d\:0628\:0627 123" },
        acpRemoteDisplayName[ "x\:f7c1y\:f7c0" ],
        acpRemoteDisplayName /@ { None, 42 },
        First @ AbsoluteTiming @ Do[ acpRemoteDisplayName @ StringRepeat[ "abcdefghi\:202e", 10 ], 100 ] < 0.1
    },
    {
        "a\:2424b\:240dc\:2409d\:fffde\:fffdf\:fffdg",
        "evil\:27e6U+202E\:27e7txt.exe\:27e6U+200B\:27e7\:27e6U+0085\:27e7x",
        { "\:27e6U+2066\:27e7a\:27e6U+2069\:27e7", "\:27e6U+FEFF\:27e7bom", "\:27e6U+200F\:27e7", "\:27e6U+2060\:27e7" },
        { "ab\:27e6U+061C\:27e7cd", "a\:27e6U+2028\:27e7b\:27e6U+2029\:27e7c", "a\:27e6U+3164\:27e7b" },
        "\:27e6U+00AD\:27e7\:27e6U+034F\:27e7\:27e6U+115F\:27e7\:27e6U+1160\:27e7\:27e6U+180E\:27e7\:27e6U+FFA0\:27e7",
        { "\:05e9\:05dc\:05d5\:05dd", "\:0645\:0631\:062d\:0628\:0627", "\:0645\:0631\:062d\:0628\:0627 123" },
        "x\:fffdy\:fffd",
        { None, 42 },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-DisplayName@@Tests/ACPRemote.wlt:602,1-628,2"
]

(* Every code point of Unicode's Default_Ignorable_Code_Point property (DerivedCoreProperties.txt: 4174 code points,
   tag characters and variation selectors included), the C1 controls and U+2028-U+2029 show as [[U+XXXX]], with five hex
   digits beyond U+FFFF. Their neighbours, an emoji beyond U+FFFF and letters of other scripts are unchanged. An emoji's
   U+FE0F shows too: a run of variation selectors can carry hidden text *)
VerificationTest[
    Module[ { hex, shownQ, ignorable, others, neighbours },
        hex[ n_ ] := ToUpperCase @ IntegerString[ n, 16, Max[ 4, IntegerLength[ n, 16 ] ] ];
        shownQ[ n_ ] := acpRemoteDisplayName[ "a" <> FromCharacterCode @ n <> "b" ] === "a\:27e6U+" <> hex @ n <> "\:27e7b";
        ignorable = Join[
            { 16^^00AD, 16^^034F, 16^^061C, 16^^115F, 16^^1160, 16^^17B4, 16^^17B5 },
            Range[ 16^^180B, 16^^180F ],
            Range[ 16^^200B, 16^^200F ],
            Range[ 16^^202A, 16^^202E ],
            Range[ 16^^2060, 16^^206F ],
            { 16^^3164 },
            Range[ 16^^FE00, 16^^FE0F ],
            { 16^^FEFF, 16^^FFA0 },
            Range[ 16^^FFF0, 16^^FFF8 ],
            Range[ 16^^1BCA0, 16^^1BCA3 ],
            Range[ 16^^1D173, 16^^1D17A ],
            Range[ 16^^E0000, 16^^E0FFF ]
        ];
        others = Join[ Range[ 128, 159 ], { 16^^2028, 16^^2029 } ];
        neighbours = {
            160, 16^^00AC, 16^^00AE, 16^^034E, 16^^0350, 16^^061B, 16^^061D, 16^^115E, 16^^1161, 16^^17B3, 16^^17B6,
            16^^180A, 16^^1810, 16^^200A, 16^^2010, 16^^2027, 16^^202F, 16^^205F, 16^^2070, 16^^3163, 16^^3165, 16^^FDFF,
            16^^FE10, 16^^FEFE, 16^^FF9F, 16^^FFA1, 16^^FFEF, 16^^FFF9, 16^^FFFD, 16^^1BC9F, 16^^1BCA4, 16^^1D172,
            16^^1D17B, 16^^DFFFF, 16^^E1000, 16^^1F600, 16^^4E2D, 16^^05D0, 16^^0627
        };
        {
            Length @ ignorable,
            Select[ Join[ ignorable, others ], ! shownQ @ # & ],
            Select[ neighbours, acpRemoteDisplayName[ "a" <> FromCharacterCode @ # <> "b" ] =!= "a" <> FromCharacterCode @ # <> "b" & ],
            (* text hidden in tag characters, a deprecated format character, an emoji's variation selector *)
            acpRemoteDisplayName[ "ok" <> FromCharacterCode @ { 16^^E0001, 16^^E0068, 16^^E0069, 16^^E007F } ],
            acpRemoteDisplayName[ "a\:206ab" ],
            acpRemoteDisplayName[ "\:2764\:fe0f" ],
            First @ AbsoluteTiming @ Do[
                acpRemoteDisplayName @ StringJoin @ ConstantArray[ "abcdefghi" <> FromCharacterCode[ 16^^E0041 ], 10 ],
                100
            ] < 0.1
        }
    ],
    {
        4174,
        { },
        { },
        "ok\:27e6U+E0001\:27e7\:27e6U+E0068\:27e7\:27e6U+E0069\:27e7\:27e6U+E007F\:27e7",
        "a\:27e6U+206A\:27e7b",
        "\:2764\:27e6U+FE0F\:27e7",
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-DisplayName-DefaultIgnorable@@Tests/ACPRemote.wlt:634,1-684,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Quoting*)
VerificationTest[
    ifFakeSSH @ Module[ { values, roundTrip },
        values = { "plain", "it's", "'", "''", "a\"b", "$HOME", "`id`", "$(id)", "a\\b\\\\", "line1\nline2\n", "\[Alpha]\[Beta] \:4e2d",
            "-n", "-e x", "", " lead and trail ", "*", "~", "a;b|c&d", $tricky };
        roundTrip[ s_ ] := FromCharacterCode[
            Normal @ runShell[ { "/bin/sh" }, { "-c", "printf %s " <> acpShellQuote @ s }, "", $scratch ][ "Output" ],
            "UTF-8"
        ];
        {
            Select[ values, roundTrip @ # =!= # & ],
            acpShellQuote[ "it's" ],
            acpShellQuote[ "" ],
            FailureQ @ acpShellQuote[ "a\:0000b" ],
            acpShellWords @ { "a b", "c'd" },
            FailureQ @ acpShellWords @ { "a", "\:0000" }
        }
    ],
    Missing[ "TestSkipped" ] | { { }, "'it'\\''s'", "''", True, "'a b' 'c'\\''d'", True },
    SameTest -> MatchQ,
    TestID   -> "Remote-Quote@@Tests/ACPRemote.wlt:689,1-709,2"
]

VerificationTest[
    ifFakeSSH @ Module[ { home = CreateDirectory @ FileNameJoin @ { $scratch, "path word home" }, expand },
        expand[ path_ ] := FromCharacterCode[
            Normal @ runShell[ { "/bin/sh" }, { "-c", "printf %s " <> acpRemotePathWord @ path }, "", $scratch, <| "HOME" -> home |> ][ "Output" ],
            "UTF-8"
        ];
        {
            acpRemotePathWord /@ { "~", "~/x y", "/a'b", "~/" },
            expand /@ { "~", "~/x y", "~/it's $HOME", "/a'b", "~bob", "~/" },
            FailureQ @ acpRemotePathWord[ "~/a\:0000" ]
        } // withoutHome[ home ]
    ],
    Missing[ "TestSkipped" ] | {
        { "\"$HOME\"", "\"$HOME\"/'x y'", "'/a'\\''b'", "\"$HOME\"/" },
        { "HOME", "HOME/x y", "HOME/it's $HOME", "/a'b", "~bob", "HOME/" },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-PathWord@@Tests/ACPRemote.wlt:711,1-730,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ssh*)
VerificationTest[
    Module[ { ssh, command, fixed, n },
        ssh     = <| sshSettings @ <| "MachineName" -> "u@h", "Arguments" -> { "-tt", "-i", "k.pem" } |>, "Program" -> "/usr/bin/ssh" |>;
        command = acpSSHCommand[ ssh, $acpSSHLaunchCommand ];
        fixed   = $acpSSHFixedOptions;
        n       = Length @ fixed;
        {
            First @ command,
            Take[ command, { 2, n + 1 } ] === fixed,
            Take[ command, { n + 2, n + 3 } ],
            Take[ command, { n + 4, n + 6 } ],
            Take[ command, { n + 7, n + 6 + Length @ $acpSSHDefaultOptions } ] === $acpSSHDefaultOptions,
            Take[ command, -4 ],
            SubsetQ[ fixed, { "StrictHostKeyChecking=yes", "CheckHostIP=no", "GSSAPIDelegateCredentials=no", "BatchMode=yes", "ControlMaster=no", "NoHostAuthenticationForLocalhost=no" } ],
            Partition[ fixed, 2 ][[ All, 1 ]] === ConstantArray[ "-o", n / 2 ],
            And @@ StringFreeQ[ { $acpSSHLaunchCommand, $acpSSHScriptCommand }, "\"" | "\\" ],
            StringContainsQ[ $acpSSHLaunchCommand, $acpSSHLaunchTrigger ],
            StringStartsQ[ $acpSSHLaunchCommand, "exec /bin/sh -c 'set +xv; echo " <> $acpSSHLaunchTrigger <> " >&2;" ],
            Take[ acpSSHCommand[ ssh, $acpSSHScriptCommand ], -3 ],
            First @ acpSSHCommand[ sshSettings @ <| "MachineName" -> "h", "Executable" -> "/opt/ssh" |>, "true" ],
            First @ acpSSHCommand[ sshSettings @ "h", "true" ],
            FreeQ[ acpSSHCommand[ sshSettings @ "h", "true" ], "-l" ]
        }
    ],
    {
        "/usr/bin/ssh",
        True,
        { "-l", "u" },
        { "-tt", "-i", "k.pem" },
        True,
        { "-T", "--", "h", $acpSSHLaunchCommand },
        True,
        True,
        True,
        True,
        True,
        { "--", "h", "exec /bin/sh -s" },
        "/opt/ssh",
        "ssh",
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-SSHCommand@@Tests/ACPRemote.wlt:735,1-778,2"
]

(* What the real ssh makes of the command (ssh -G prints the options it would use, without connecting): the fixed options
   win over a config that turns the host key checks and connection sharing off, "-S none" keeps ControlPath none, and
   VerifyHostKeyDNS stays the config's. The control: the config alone is in effect. Only a scratch config is read (-F:
   neither ~/.ssh/config nor the system's); skipped without /usr/bin/ssh. *)
VerificationTest[
    If[ $OperatingSystem === "Windows" || ! FileExistsQ[ "/usr/bin/ssh" ],
        Missing[ "TestSkipped" ],
        Module[ { config, command, options },
            config = FileNameJoin @ { $scratch, "ssh-G-config" };
            BinaryWrite[ config, StringToByteArray[ StringRiffle[
                {
                    "Host *",
                    "  StrictHostKeyChecking no",
                    "  NoHostAuthenticationForLocalhost yes",
                    "  BatchMode no",
                    "  ControlMaster auto",
                    "  ControlPath /tmp/chatbook-ssh-G-%C",
                    "  VerifyHostKeyDNS yes",
                    ""
                },
                "\n"
            ] ] ];
            Close @ config;
            command = acpSSHCommand[ <| sshSettings @ <| "MachineName" -> "localhost", "Arguments" -> { "-S", "none" } |>, "Program" -> "/usr/bin/ssh" |>, "true" ];
            options[ args_List ] := With[ { run = RunProcess[ Join[ { "/usr/bin/ssh", "-G", "-F", config }, args ], ProcessEnvironment -> <| "PATH" -> "/usr/bin:/bin" |> ] },
                {
                    run[ "ExitCode" ],
                    KeyTake[
                        Association[ Rule @@@ Select[ StringSplit[ StringSplit[ run[ "StandardOutput" ], "\n" ], " ", 2 ], Length @ # === 2 & ] ],
                        { "stricthostkeychecking", "nohostauthenticationforlocalhost", "batchmode", "controlmaster", "controlpath", "verifyhostkeydns" }
                    ]
                }
            ];
            { options @ Rest @ command, options @ { "--", "localhost", "true" } }
        ]
    ],
    Missing[ "TestSkipped" ] | {
        { 0, <| "stricthostkeychecking" -> "true", "nohostauthenticationforlocalhost" -> "no", "batchmode" -> "yes", "controlmaster" -> "false", "verifyhostkeydns" -> "true" |> },
        {
            0,
            <|
                "stricthostkeychecking" -> "false", "nohostauthenticationforlocalhost" -> "yes", "batchmode" -> "no", "controlmaster" -> "auto",
                "controlpath" -> _String? (StringStartsQ[ "/tmp/chatbook-ssh-G-" ]), "verifyhostkeydns" -> "true"
            |>
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-SSHCommand-ConfigOverride@@Tests/ACPRemote.wlt:784,1-828,2"
]

VerificationTest[
    Module[ { env = acpSSHEnvironment[ ] },
        {
            env[ "SSH_ASKPASS_REQUIRE" ],
            AllTrue[ Keys @ env, StringQ ],
            AllTrue[ Values @ env, StringQ ],
            Select[ Keys @ env, StringContainsQ[ #, "=" ] || StringTrim @ # =!= # & ],
            KeySort @ KeyDrop[ env, "SSH_ASKPASS_REQUIRE" ] === KeySort @ acpInheritedEnvironment[ ]
        }
    ],
    { "never", True, True, { }, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-SSHEnvironment@@Tests/ACPRemote.wlt:830,1-843,2"
]

VerificationTest[
    ifFakeSSH @ Module[ { exe = $fakeSSH[ "Executable" ], dir, unix },
        dir  = DirectoryName @ exe;
        unix = <| "PATH" -> dir, "HomeDirectory" -> None, "OperatingSystem" -> "Unix", "SystemDirectories" -> { } |>;
        {
            acpFindSSH @ sshSettings @ <| "MachineName" -> "h", "Executable" -> exe |>,
            acpFindSSH[ sshSettings @ <| "MachineName" -> "h", "Executable" -> "fake-ssh" |>, unix ],
            acpFindSSH[ sshSettings @ <| "MachineName" -> "h", "Executable" -> File[ exe ] |>, <| unix, "PATH" -> "" |> ],
            acpFindSSH @ sshSettings @ <| "MachineName" -> "h", "Executable" -> FileNameJoin @ { dir, "no-such-ssh" } |>,
            acpFindSSH[ sshSettings @ "h", <| unix, "PATH" -> "", "OperatingSystem" -> "Windows" |> ],
            acpFindSSH[ sshSettings @ <| "MachineName" -> "h", "Executable" -> "no-such-ssh" |>, unix ],
            acpErrorInfo @ acpFindSSH @ sshSettings @ <| "MachineName" -> "h", "Executable" -> FileNameJoin @ { dir, "no-such-ssh" } |>,
            acpErrorInfo @ acpFindSSH[ sshSettings @ "h", <| unix, "PATH" -> "", "OperatingSystem" -> "Windows" |> ],
            acpFindSSH @ None
        }
    ],
    Missing[ "TestSkipped" ] | {
        $fakeSSH[ "Executable" ],
        $fakeSSH[ "Executable" ],
        $fakeSSH[ "Executable" ],
        Failure[ "SSHNotFound", KeyValuePattern @ { "Windows" -> False, "Path" -> _String? (StringEndsQ[ "no-such-ssh" ]) } ],
        Failure[ "SSHNotFound", KeyValuePattern[ "Windows" -> True ] ],
        Failure[ "SSHNotFound", KeyValuePattern[ "Path" -> "no-such-ssh" ] ],
        (* a missing "Executable" is named, and the advice is to check it (not to install OpenSSH) *)
        KeyValuePattern @ {
            "Code" -> "SSHNotFound",
            "Message" -> _String? (StringEndsQ[ "no-such-ssh was not found or is not executable on this computer." ]),
            "Hint" -> _String? (StringStartsQ[ "Check \"Executable\"" ]),
            "Actions" -> { "Reconnect" }
        },
        (* the same words on every version of Windows: the Settings page moved in Windows 11 24H2 *)
        KeyValuePattern @ { "Code" -> "SSHNotFound", "Hint" -> _String? (StringContainsQ[ "Optional features in the Start menu search" ]) },
        Failure[ "SSHNotFound", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-FindSSH@@Tests/ACPRemote.wlt:845,1-881,2"
]

(* An "Executable" that is not found is named in the error (display-safe), so that a typo in it does not read as a missing
   OpenSSH client: in the Failure and in the window's error (message and advice); without "Executable" the error keeps
   the general text and advice and has no path *)
VerificationTest[
    Module[ { env, given, automatic },
        env       = <| "PATH" -> "", "HomeDirectory" -> None, "OperatingSystem" -> "Unix", "SystemDirectories" -> { } |>;
        given     = acpFindSSH[ <| "MachineName" -> "h", "Executable" -> "/nonexistent/ss\:202eh" |>, env ];
        (* no ssh in the system folders either *)
        automatic = Block[ { Wolfram`Chatbook`ACP`SSH`Private`$sshSystemDirectories = { } }, acpFindSSH[ <| "MachineName" -> "h" |>, env ] ];
        {
            given,
            given[ "Message" ],
            automatic[ "Message" ],
            KeyExistsQ[ Last @ automatic, "Path" ],
            KeyTake[ acpErrorInfo @ given, { "Code", "Message", "Hint" } ],
            KeyTake[ acpErrorInfo @ automatic, { "Code", "Message", "Hint" } ]
        }
    ],
    {
        Failure[ "SSHNotFound", KeyValuePattern @ { "Path" -> "/nonexistent/ss\:202eh", "Windows" -> False } ],
        "/nonexistent/ss\:27e6U+202E\:27e7h was not found or is not executable on this computer.",
        "The ssh program was not found on this computer.",
        False,
        <|
            "Code"    -> "SSHNotFound",
            "Message" -> "/nonexistent/ss\:27e6U+202E\:27e7h was not found or is not executable on this computer.",
            "Hint"    -> "Check \"Executable\" in the \"SSHSettings\" setting: it must be the path or the name of the ssh program on this computer (Automatic finds ssh)."
        |>,
        <|
            "Code"    -> "SSHNotFound",
            "Message" -> "The ssh program was not found on this computer.",
            "Hint"    -> "Install the OpenSSH client, or give the path of ssh with \"Executable\" in the \"SSHSettings\" setting."
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-FindSSH-ExecutableNamed@@Tests/ACPRemote.wlt:886,1-919,2"
]

(* Error texts of remote windows: the advice for a refused connection names no particular port; a remote agent's
   sign-in errors keep their message short, and the instruction with the ssh command is their advice ("Hint"), which
   the toolbar shows in the details with "Copy" (the agent's own words stay the line under the message); a local
   agent's sign-in errors have no such advice *)
VerificationTest[
    Module[ { context, parts },
        context = <| "Host" -> "u@h", "Command" -> "ssh -l u h", "Agent" -> "OpenCode" |>;
        parts   = KeyTake[ acpErrorParts @ acpErrorInfo[ -32603, "No models are available", None, context ], { "Line", "Details", "MoreQ" } ];
        {
            With[ { hint = acpErrorInfo[ "SSHConnectionRefused", None, None, <| "Host" -> "u@h" |> ][ "Hint" ] },
                { StringContainsQ[ hint, "{\"-p\", \"<port>\"}" ], StringContainsQ[ hint, "2222" ] }
            ],
            KeyTake[ acpErrorInfo[ -32603, "No models are available", None, context ], { "Code", "Message", "Hint" } ],
            KeyTake[ acpErrorInfo[ -32000, "Authentication required", None, context ], { "Code", "Message", "Hint" } ],
            parts,
            acpErrorInfo[ -32603, "No models are available", None, <| "Agent" -> "OpenCode" |> ][ "Hint" ]
        }
    ],
    {
        { True, False },
        <|
            "Code"    -> "NoModels",
            "Message" -> "OpenCode on u@h has no models available.",
            "Hint"    -> "Sign in to a provider on u@h: connect with ssh -l u h in a terminal, run \"opencode auth login\" there, then reconnect."
        |>,
        <|
            "Code"    -> "AuthRequired",
            "Message" -> "OpenCode on u@h needs you to sign in to the model provider.",
            "Hint"    -> "The sign-in runs on u@h: connect with ssh -l u h in a terminal, run \"opencode auth login\" there, then reconnect."
        |>,
        <|
            "Line"    -> "No models are available",
            "Details" -> "Sign in to a provider on u@h: connect with ssh -l u h in a terminal, run \"opencode auth login\" there, then reconnect.\n\nNo models are available",
            "MoreQ"   -> True
        |>,
        None
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-ErrorTexts@@Tests/ACPRemote.wlt:925,1-960,2"
]

(* The terminal command of the host key and sign-in instructions: "Executable" (else ssh), each word quoted for the
   shells of the client's system: Windows by the C runtime's rules that ssh.exe parses its command line with (not a
   particular shell's: see terminalWord), other systems with POSIX single quotes *)
VerificationTest[
    Module[ { key, proxy, exe, ssh, posix },
        key   = <| "Username" -> "ubuntu", "MachineName" -> "ec2.example.com", "Arguments" -> { "-i", "C:/Users/John Smith/k.pem", "-p", "2222" } |>;
        proxy = "ProxyCommand=\"C:\\Program Files\\Git\\usr\\bin\\connect.exe\" -S proxy:1080 %h %p";
        exe   = "C:\\Program Files\\Git\\usr\\bin\\ssh.exe";
        ssh   = sshSettings @ <| "MachineName" -> "h", "Arguments" -> { "-o", proxy, "-i", "C:\\keys dir\\", "-i", "C:\\keys\\k" }, "Executable" -> exe |>;
        posix = sshSettings @ <| "MachineName" -> "h", "Arguments" -> { "-o", "ProxyCommand=it's \"x\" $HOME `id`", "-i", "~/k", "-o", "Ciphers=a,b" }, "Executable" -> "/opt/my ssh/ssh" |>;
        {
            acpSSHTerminalCommand[ sshSettings @ key, "Windows" ],
            acpSSHTerminalCommand[ sshSettings @ key, "Unix" ],
            acpSSHTerminalCommand[ sshSettings @ key, "MacOSX" ],
            acpSSHTerminalCommand @ sshSettings @ key === acpSSHTerminalCommand[ sshSettings @ key, $OperatingSystem ],
            acpSSHTerminalCommand[ ssh, "Windows" ],
            acpSSHTerminalCommand[ posix, "Unix" ],
            acpSSHTerminalCommand[ sshSettings @ <| "MachineName" -> "h", "Executable" -> "/opt/ssh" |>, "Unix" ],
            acpSSHTerminalCommand[ sshSettings @ "devbox", # ] & /@ { "Windows", "Unix" },
            acpSSHTerminalCommand[ sshSettings @ "me@10.0.0.5", "Unix" ],
            acpSSHTerminalCommand /@ { None, Failure[ "x", <| |> ] },
            acpSSHTerminalCommand[ None, "Windows" ]
        }
    ],
    {
        "ssh -l ubuntu -i \"C:/Users/John Smith/k.pem\" -p 2222 ec2.example.com",
        "ssh -l ubuntu -i 'C:/Users/John Smith/k.pem' -p 2222 ec2.example.com",
        "ssh -l ubuntu -i 'C:/Users/John Smith/k.pem' -p 2222 ec2.example.com",
        True,
        "\"C:\\Program Files\\Git\\usr\\bin\\ssh.exe\" -o \"ProxyCommand=\\\"C:\\Program Files\\Git\\usr\\bin\\connect.exe\\\" -S proxy:1080 %h %p\" -i \"C:\\keys dir\\\\\" -i C:\\keys\\k h",
        "'/opt/my ssh/ssh' -o 'ProxyCommand=it'\\''s \"x\" $HOME `id`' -i ~/k -o Ciphers=a,b h",
        "/opt/ssh h",
        { "ssh devbox", "ssh devbox" },
        "ssh -l me 10.0.0.5",
        { None, None },
        None
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-TerminalCommand@@Tests/ACPRemote.wlt:965,1-1001,2"
]

(* The quoted words come back as the arguments ssh gets: Windows' through the C runtime's rules (CommandLineToArgvW,
   written out below), POSIX ones through /bin/sh *)
VerificationTest[
    Module[ { words, argv, msvcSplit, ssh, posixArgs },
        words = {
            "plain", "", "a b", "say \"hi\"", "a\\\"b", "C:\\dir with space\\", "C:\\x\\y", "tab\there", "'single'", "a,b", "$HOME",
            "ProxyCommand=\"C:\\Program Files\\Git\\usr\\bin\\connect.exe\" -S proxy:1080 %h %p", "=x", "\[Alpha] \:4e2d"
        };
        argv[ os_ ] := Join[ { "ssh" }, words, { "h" } ];
        ssh = <| sshSettings @ "h", "Arguments" -> words |>;
        (* the C runtime's parsing of a command line (backslashes are literal unless they precede a quote) *)
        msvcSplit[ line_String ] := Module[ { chars = Characters @ line, i = 1, n, args = { }, current = "", inArg = False, quoted = False, k },
            n = Length @ chars;
            While[ i <= n,
                Which[
                    chars[[ i ]] === "\\",
                        k = 0;
                        While[ i <= n && chars[[ i ]] === "\\", k++; i++ ];
                        If[ i <= n && chars[[ i ]] === "\"",
                            current = current <> StringRepeat[ "\\", Quotient[ k, 2 ] ];
                            If[ OddQ @ k, current = current <> "\""; i++ ];
                            ,
                            current = current <> StringRepeat[ "\\", k ]
                        ];
                        inArg = True,
                    chars[[ i ]] === "\"",
                        quoted = ! quoted; inArg = True; i++,
                    MemberQ[ { " ", "\t" }, chars[[ i ]] ] && ! quoted,
                        If[ inArg, AppendTo[ args, current ] ]; current = ""; inArg = False; i++,
                    True,
                        current = current <> chars[[ i ]]; inArg = True; i++
                ]
            ];
            If[ inArg, AppendTo[ args, current ] ];
            args
        ];
        posixArgs = If[ FileExistsQ[ "/bin/sh" ] && $OperatingSystem =!= "Windows",
            StringSplit[
                FromCharacterCode[
                    Normal @ runShell[ { "/bin/sh" }, { "-c", "set -f; set -- " <> acpSSHTerminalCommand[ ssh, "Unix" ] <> "; printf '%s\\000' \"$@\"" }, "", $scratch ][ "Output" ],
                    "UTF-8"
                ],
                "\000",
                All
            ],
            Missing[ "TestSkipped" ]
        ];
        {
            msvcSplit @ acpSSHTerminalCommand[ ssh, "Windows" ] === argv[ "Windows" ],
            (* the parser reads a plain backslash as itself and an escaped quote as a quote *)
            msvcSplit[ "a\\b \"c d\" \"e\\\"f\" g\\\\\\\"h \"i\\\\\"" ],
            posixArgs
        }
    ],
    {
        True,
        { "a\\b", "c d", "e\"f", "g\\\"h", "i\\" },
        Missing[ "TestSkipped" ] | Append[ Join[ { "ssh" }, { "plain", "", "a b", "say \"hi\"", "a\\\"b", "C:\\dir with space\\", "C:\\x\\y", "tab\there", "'single'", "a,b", "$HOME", "ProxyCommand=\"C:\\Program Files\\Git\\usr\\bin\\connect.exe\" -S proxy:1080 %h %p", "=x", "\[Alpha] \:4e2d" }, { "h" } ], "" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-TerminalCommand-RoundTrip@@Tests/ACPRemote.wlt:1005,1-1064,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Launch script*)
VerificationTest[
    Module[ { script, secret = "FAKEKEY-launch-0123456789", failures },
        script   = acpSSHLaunchScript[ $nonce, "~/proj", { "opencode", "acp" }, <| "A_B" -> "it's", "LLMKIT_API_KEY" -> secret |> ];
        failures = {
            acpSSHLaunchScript[ $nonce, "~/a\nb", { "opencode" }, <| |> ],
            acpSSHLaunchScript[ $nonce, "~/proj", { "open\rcode" }, <| |> ],
            acpSSHLaunchScript[ $nonce, "~/proj", { "opencode", "a\nb" }, <| |> ],
            acpSSHLaunchScript[ $nonce, "~/proj", { "opencode" }, <| "K" -> secret <> "\n" |> ],
            acpSSHLaunchScript[ $nonce, "~/proj", { "opencode" }, <| "K" -> secret <> "\:0000" |> ],
            acpSSHLaunchScript[ $nonce, "~/proj", { "opencode" }, <| "1A" -> secret |> ],
            acpSSHLaunchScript[ $nonce, "~/proj", { "opencode" }, <| "A-B" -> secret |> ],
            acpSSHLaunchScript[ $nonce, "~/proj", { "opencode" }, <| "A=B" -> secret |> ],
            acpSSHLaunchScript[ $nonce, "~/proj", { "opencode" }, <| "K" -> 42 |> ],
            acpSSHLaunchScript[ $nonce, "~/proj", { }, <| |> ]
        };
        {
            StringCount[ script, "\n" ],
            StringEndsQ[ script, "\n" ],
            StringContainsQ[ script, "export A_B='it'\\''s' LLMKIT_API_KEY='" <> secret <> "'" ],
            StringContainsQ[ script, "\"$p\" 'acp'; exit $?" ],
            StringStartsQ[ acpSSHLaunchScript[ $nonce, "~", { "opencode" }, <| |> ], "unset IFS; set +f; m='chatbook-acp:" <> $nonce <> "'; " ],
            AllTrue[ failures, MatchQ[ #, Failure[ "InvalidLaunchValue", _ ] ] & ],
            FreeQ[ failures, s_String /; StringContainsQ[ s, secret ] ],
            acpSSHLaunchScript[ $nonce, "~", { "opencode" }, { "A" -> "x" } ] === acpSSHLaunchScript[ $nonce, "~", { "opencode" }, <| "A" -> "x" |> ],
            StringMatchQ[ acpSSHLaunchNonce[ ], RegularExpression[ "[0-9a-f]{16}" ] ],
            acpSSHLaunchNonce[ ] =!= acpSSHLaunchNonce[ ]
        }
    ],
    { 1, True, True, True, True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-LaunchScript@@Tests/ACPRemote.wlt:1069,1-1100,2"
]

(* The script under each available shell, through the bootstrap's body (as the remote login shell runs it) *)
VerificationTest[
    ifFakeSSH @ Module[ { home, results },
        home = makeHome[ "launch-home" ];
        results = Function[ shell,
            Module[ { run, script, out },
                script[ dir_, command_, vars_: <| |> ] := acpSSHLaunchScript[ $nonce, dir, command, vars ];
                out[ r_ ] := FromCharacterCode[ Normal @ r[ "Output" ], "UTF-8" ];
                run[ args__ ] := runLaunch[ shell, args, home ];
                With[
                    {
                        odd     = run[ script[ "~/odd dir's", { "/bin/sh", "-c", "pwd; printf '%s\\n' \"$1\" \"$V\"", "argv0", $tricky }, <| "V" -> $tricky |> ], "" ],
                        missing = run[ script[ "~/no-such-folder", { "/bin/sh" } ], "" ],
                        file    = run[ script[ "~/afile", { "/bin/sh" } ], "" ],
                        noAgent = run[ script[ "~/proj", { "no-such-agent", "acp" } ], "" ],
                        lookup  = run[ script[ "~/proj", { "tool" } ], "" ],
                        inPath  = runLaunch[ shell, script[ "~/proj", { "tool2" } ], "", home, <| "PATH" -> home <> "/bin2:/usr/bin:/bin" |> ],
                        tilde   = run[ script[ "~/proj", { "~/bin2/tool2" } ], "" ],
                        rel     = run[ script[ "~/proj", { "sub/tool3" } ], "" ],
                        abs     = run[ script[ home <> "/proj/", { "/bin/sh", "-c", "pwd" } ], "" ],
                        exit3   = run[ script[ "~", { "/bin/sh", "-c", "exit 3" } ], "" ],
                        killed  = run[ script[ "~", { "/bin/sh", "-c", "kill -9 $$" } ], "" ],
                        stdin   = run[ script[ "~", { "/bin/cat" } ], "{\"jsonrpc\":\"2.0\",\"id\":1}\n~.\nline 3 \[Alpha]\n" ]
                    },
                    {
                        odd[ "ExitCode" ],
                        out @ odd,
                        acpSSHLaunchMarkers[ $nonce, odd[ "Error" ] ],
                        { missing[ "ExitCode" ], acpSSHLaunchMarkers[ $nonce, missing[ "Error" ] ][ "Error" ] },
                        { file[ "ExitCode" ], acpSSHLaunchMarkers[ $nonce, file[ "Error" ] ][ "Error" ] },
                        { noAgent[ "ExitCode" ], acpSSHLaunchMarkers[ $nonce, noAgent[ "Error" ] ][ "Error" ] },
                        { lookup[ "ExitCode" ], out @ lookup, acpSSHLaunchMarkers[ $nonce, lookup[ "Error" ] ][ "Agent" ] },
                        { inPath[ "ExitCode" ], out @ inPath },
                        { tilde[ "ExitCode" ], StringTake[ out @ tilde, 6 ] },
                        { rel[ "ExitCode" ], StringTake[ out @ rel, 6 ] },
                        { abs[ "ExitCode" ], out @ abs },
                        exit3[ "ExitCode" ],
                        { killed[ "ExitCode" ], acpSSHExitKind[ killed[ "ExitCode" ], killed[ "Error" ], <| "Nonce" -> $nonce, "Setup" -> False |> ] },
                        { stdin[ "ExitCode" ], out @ stdin }
                    }
                ]
            ]
        ] /@ $shells;
        DeleteDuplicates @ withoutHome[ home ][ results ]
    ],
    Missing[ "TestSkipped" ] | {
        {
            0,
            "HOME/odd dir's\n" <> $tricky <> "\n" <> $tricky <> "\n",
            <| "Home" -> "HOME", "Cwd" -> "HOME/odd dir's", "Agent" -> "/bin/sh", "Error" -> None |>,
            { 120, { "no-folder", "HOME/no-such-folder" } },
            { 120, { "not-a-folder", "HOME/afile" } },
            { 127, { "no-agent", "no-such-agent" } },
            { 0, "tool:HOME/.local/bin:/usr/bin:/bin\n", "HOME/.local/bin/tool" },
            { 0, "tool2:HOME/bin2:/usr/bin:/bin\n" },
            { 0, "tool2:" },
            { 0, "tool3:" },
            { 0, "HOME/proj\n" },
            3,
            { 137, "RemoteAgentExited" },
            { 0, "{\"jsonrpc\":\"2.0\",\"id\":1}\n~.\nline 3 \[Alpha]\n" }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-LaunchScript-Shells@@Tests/ACPRemote.wlt:1103,1-1167,2"
]

(* With bash as sh and SHELLOPTS=xtrace:verbose, the bootstrap's "set +xv" keeps the launch line (and its secret) off
   standard error *)
VerificationTest[
    ifFakeSSH @ If[ ! FileExistsQ[ "/bin/bash" ],
        Missing[ "TestSkipped" ],
        Module[ { home, sh, secret = "FAKEKEY-trace-0123456789", script, result },
            home   = makeHome[ "trace-home" ];
            sh     = FileNameJoin @ { $scratch, "sh" };
            RunProcess[ { "ln", "-sf", "/bin/bash", sh } ];
            script = acpSSHLaunchScript[ $nonce, "~/proj", { "/bin/sh", "-c", "exit 0" }, <| "LLMKIT_API_KEY" -> secret, "OPENCODE_CONFIG_CONTENT" -> "{}" |> ];
            result = runLaunch[ { sh }, script, "", home, <| "SHELLOPTS" -> "xtrace:verbose" |> ];
            {
                result[ "ExitCode" ],
                StringFreeQ[ result[ "Error" ], secret ],
                StringContainsQ[ result[ "Error" ], "\n" <> $acpSSHLaunchTrigger <> "\n" ] || StringStartsQ[ result[ "Error" ], $acpSSHLaunchTrigger <> "\n" ],
                StringFreeQ[ result[ "Error" ], "LLMKIT_API_KEY" ],
                (* without "set +xv" the same shell would trace the secret: the test can see it *)
                StringContainsQ[
                    runShell[ { sh }, { "-c", StringDelete[ $bootstrapBody, "set +xv; " ] }, script, home, <| "HOME" -> home, "SHELLOPTS" -> "xtrace" |> ][ "Error" ],
                    secret
                ]
            }
        ]
    ],
    Missing[ "TestSkipped" ] | { 0, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-LaunchScript-NoTrace@@Tests/ACPRemote.wlt:1171,1-1196,2"
]

(* The bootstrap through the fake ssh, the way ACPLink runs it (no ACPLink, no python: this runs in CI): the trigger
   line comes before anything is written, the launch script and the protocol stream pass byte-exact *)
VerificationTest[
    ifFakeSSH @ Module[ { ssh, command, home, streamBytes, waitFor, launch, json, ok, missing, noAgent, empty },
        ssh     = <| sshSettings @ fakeSSHSettings[ ], "Program" -> $fakeSSH[ "Executable" ] |>;
        command = acpSSHCommand[ ssh, $acpSSHLaunchCommand ];
        home    = $fakeSSH[ "Home" ];
        Quiet @ CreateDirectory @ FileNameJoin @ { home, "proj" };
        json    = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"x\":\"\[Alpha]\"}}\n";
        (* stdout and stderr of a ProcessLink process are files that grow: read what was written since the last read, by
           size (as gitDrain); a read to EndOfFile, even through the file's name, waits for the process to end *)
        streamBytes[ stream_InputStream ] := With[ { size = Quiet @ FileByteCount @ First @ stream, position = Quiet @ StreamPosition @ stream },
            If[ IntegerQ @ size && IntegerQ @ position && size > position,
                Replace[ Quiet @ ReadByteArray[ stream, size - position ], Except[ _ByteArray ] -> Nothing ],
                Nothing
            ]
        ];
        waitFor // Attributes = { HoldFirst };
        waitFor[ cond_, timeout_: 15 ] := Module[ { deadline = AbsoluteTime[ ] + timeout },
            While[ ! TrueQ @ cond && AbsoluteTime[ ] < deadline, Pause[ 0.05 ] ];
            TrueQ @ cond
        ];
        launch[ script_, rest_ ] := Module[ { proc, out = { }, err = { }, drain, bytes, triggerQ, exitQ },
            proc  = StartProcess[ command, ProcessDirectory -> $HomeDirectory, ProcessEnvironment -> acpSSHEnvironment[ ] ];
            drain[ ] := (
                AppendTo[ out, streamBytes @ ProcessConnection[ proc, "StandardOutput" ] ];
                AppendTo[ err, streamBytes @ ProcessConnection[ proc, "StandardError" ] ]
            );
            bytes[ chunks_ ] := If[ chunks === { }, ByteArray[ { } ], Join @@ chunks ];
            triggerQ = waitFor[ drain[ ]; StringContainsQ[ ByteArrayToString[ bytes @ err, "UTF-8" ], $acpSSHLaunchTrigger <> "\n" ] ];
            If[ StringQ @ script, BinaryWrite[ proc, StringToByteArray[ script <> rest, "UTF-8" ] ] ];
            Close @ ProcessConnection[ proc, "StandardInput" ];
            exitQ = waitFor[ drain[ ]; ProcessStatus @ proc =!= "Running" ];
            drain[ ];
            <|
                "Trigger"  -> triggerQ,
                "ExitCode" -> If[ exitQ, ProcessInformation[ proc, "ExitCode" ], KillProcess @ proc; "Running" ],
                "Output"   -> bytes @ out,
                "Markers"  -> acpSSHLaunchMarkers[ $nonce, ByteArrayToString[ bytes @ err, "UTF-8" ] ]
            |>
        ];
        ok      = launch[ acpSSHLaunchScript[ $nonce, "~/proj", { "/bin/sh", "-c", "printf '%s\\n' \"$MOCK_REMOTE_VAR\"; cat" }, <| "MOCK_REMOTE_VAR" -> $tricky |> ], json ];
        missing = launch[ acpSSHLaunchScript[ $nonce, "~/no-such-folder", { "/bin/sh" }, <| |> ], "" ];
        noAgent = launch[ acpSSHLaunchScript[ $nonce, "~/proj", { "no-such-agent" }, <| |> ], "" ];
        empty   = launch[ None, "" ];
        {
            ok[ "Trigger" ],
            ok[ "ExitCode" ],
            ok[ "Output" ] === StringToByteArray[ $tricky <> "\n" <> json, "UTF-8" ],
            ok[ "Markers" ],
            Lookup[ missing, { "Trigger", "ExitCode" } ],
            missing[ "Markers", "Error" ],
            Lookup[ noAgent, { "Trigger", "ExitCode" } ],
            noAgent[ "Markers", "Error" ],
            Lookup[ empty, { "Trigger", "ExitCode" } ],
            Last @ fakeSSHCalls[ ] === Rest @ command
        } // withoutHome[ home ]
    ],
    Missing[ "TestSkipped" ] | {
        True,
        0,
        True,
        <| "Home" -> "HOME", "Cwd" -> "HOME/proj", "Agent" -> "/bin/sh", "Error" -> None |>,
        { True, 120 },
        { "no-folder", "HOME/no-such-folder" },
        { True, 127 },
        { "no-agent", "no-such-agent" },
        { True, 125 },
        True
    },
    SameTest       -> MatchQ,
    TimeConstraint -> 180,
    TestID         -> "Remote-LaunchBootstrap@@Tests/ACPRemote.wlt:1200,1-1271,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Markers*)
VerificationTest[
    {
        acpSSHLaunchMarkers[ $nonce, fixture[ "signal-agent" ] ],
        acpSSHLaunchMarkers[ $nonce, fixture[ "folder-missing" ] ],
        acpSSHLaunchMarkers[ $nonce, fixture[ "no-agent" ] ][ "Error" ],
        acpSSHLaunchMarkers[ "ffffffffffffffff", fixture[ "signal-agent" ] ],
        acpSSHLaunchMarkers[ $nonce, StringRiffle[ {
            "chatbook-acp:ffffffffffffffff:home:/decoy",
            "chatbook-acp:" <> $nonce <> ":home:/home/u",
            "chatbook-acp:" <> $nonce <> ":cwd:/srv/a:b:c",
            "chatbook-acp:" <> $nonce <> ":agent:/opt/x:y/oc"
        }, "\r\n" ] ],
        acpSSHLaunchMarkers[ $nonce, StringToByteArray[ fixture[ "signal-agent" ], "UTF-8" ] ][ "Cwd" ],
        acpSSHLaunchMarkers[ $nonce, "" ],
        acpSSHLaunchMarkers[ $nonce, Missing[ "NotAvailable" ] ],
        acpSSHLaunchMarkers[ $nonce, "chatbook-acp:" <> $nonce <> ":error\n" ][ "Error" ]
    },
    {
        <| "Home" -> "/home/ubuntu", "Cwd" -> "/home/ubuntu/projects/app", "Agent" -> "/bin/sh", "Error" -> None |>,
        <| "Home" -> "/home/ubuntu", "Cwd" -> None, "Agent" -> None, "Error" -> { "no-folder", "/home/ubuntu/no-such-folder" } |>,
        { "no-agent", "no-such-agent" },
        <| "Home" -> None, "Cwd" -> None, "Agent" -> None, "Error" -> None |>,
        <| "Home" -> "/home/u", "Cwd" -> "/srv/a:b:c", "Agent" -> "/opt/x:y/oc", "Error" -> None |>,
        "/home/ubuntu/projects/app",
        <| "Home" -> None, "Cwd" -> None, "Agent" -> None, "Error" -> None |>,
        <| "Home" -> None, "Cwd" -> None, "Agent" -> None, "Error" -> None |>,
        { "", "" }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-LaunchMarkers@@Tests/ACPRemote.wlt:1276,1-1306,2"
]

(* A home or folder from a marker that is not an absolute path without control characters, of at most 4096
   characters, is rejected (None); the rejection is logged with the key only *)
VerificationTest[
    Module[ { t0 = AbsoluteTime[ ], m = "chatbook-acp:" <> $nonce <> ":", long = "/" <> StringRepeat[ "x", 10240 ], newline, big, relative, log },
        newline  = acpSSHLaunchMarkers[ $nonce, m <> "home:/home/evil\n" <> "inject\n" <> m <> "cwd:/srv/new\nline\n" <> m <> "agent:/bin/sh\n" ];
        big      = acpSSHLaunchMarkers[ $nonce, m <> "home:" <> long <> "\n" <> m <> "cwd:" <> long <> "\n" <> m <> "agent:" <> long <> "\n" ];
        relative = acpSSHLaunchMarkers[ $nonce, m <> "home:relative\n" <> m <> "cwd:~/x\n" <> m <> "agent:opencode\n" ];
        log      = Select[ logSince @ t0, #[ "Where" ] === "RemoteValueRejected" & ];
        {
            newline,
            big,
            relative,
            Sort @ Lookup[ log, "Data" ],
            FreeQ[ logSince @ t0, s_String /; StringContainsQ[ s, "evil" | "relative" | "xxxxxxxx" | "new" ] ],
            acpRemoteCheckedPath[ #, "Home" ] & /@ { "/ok", "rel", None, Missing[ "NotAvailable" ] }
        }
    ],
    {
        <| "Home" -> None, "Cwd" -> None, "Agent" -> "/bin/sh", "Error" -> None |>,
        <| "Home" -> None, "Cwd" -> None, "Agent" -> None, "Error" -> None |>,
        <| "Home" -> None, "Cwd" -> None, "Agent" -> None, "Error" -> None |>,
        {
            <| "Key" -> "Agent" |>, <| "Key" -> "Agent" |>,
            <| "Key" -> "Cwd" |>, <| "Key" -> "Cwd" |>, <| "Key" -> "Cwd" |>,
            <| "Key" -> "Home" |>, <| "Key" -> "Home" |>, <| "Key" -> "Home" |>
        },
        True,
        { "/ok", None, None, None }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-RemoteValues@@Tests/ACPRemote.wlt:1310,1-1339,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Exit classification*)

(* Every rule against the fixtures: { fixture, exit code, setup, expected kind } *)
VerificationTest[
    Select[
        {
            { "hostkey-unknown"    , 255, True , "SSHHostKeyUnknown"    },
            { "hostkey-changed"    , 255, True , "SSHHostKeyChanged"    },
            { "auth-denied"        , 255, True , "SSHAuthFailed"        },
            { "key-permissions"    , 255, True , "SSHAuthFailed"        },
            { "no-such-identity"   , 255, True , "SSHAuthFailed"        },
            { "gssapi-unsupported" , 255, True , "SSHAuthFailed"        },
            { "debug-auth"         , 255, True , "SSHAuthFailed"        },
            { "dns"                , 255, True , "SSHHostNotFound"      },
            { "dns-windows"        , 255, True , "SSHHostNotFound"      },
            { "dns-macos"          , 255, True , "SSHHostNotFound"      },
            { "refused"            , 255, True , "SSHConnectionRefused" },
            { "key-missing-refused", 255, True , "SSHConnectionRefused" },
            { "timeout"            , 255, True , "SSHUnreachable"       },
            { "banner-timeout"     , 255, True , "SSHUnreachable"       },
            { "kex-reset"          , 255, True , "SSHUnreachable"       },
            { "closed"             , 255, True , "SSHUnreachable"       },
            { "bad-option"         , 255, True , "SSHBadArguments"      },
            { "unknown-option"     , 255, True , "SSHBadArguments"      },
            { "empty-stdin"        , 125, True , "SSHFailed"            },
            { "nologin"            , 1  , True , "RemoteScriptFailed"   },
            { "folder-missing"     , 120, True , "RemoteFolderMissing"  },
            { "not-a-folder"       , 120, True , "RemoteFolderMissing"  },
            { "folder-access"      , 120, True , "RemoteFolderAccess"   },
            { "no-agent"           , 127, True , "RemoteAgentNotFound"  },
            { "signal-agent"       , 137, True , "RemoteAgentExited"    },
            { "signal-agent"       , 137, False, "RemoteAgentExited"    },
            { "silent-255"         , 255, True , "RemoteAgentExited"    },
            { "silent-255"         , 255, False, "RemoteAgentExited"    },
            { "alive-timeout"      , 255, False, "SSHConnectionLost"    },
            { "alive-timeout"      , 255, True , "SSHConnectionLost"    },
            { "drop-setup"         , 255, True , "SSHConnectionLost"    },
            { "agent-exited"       , 3  , False, "RemoteAgentExited"    },
            { "agent-text"         , 1  , True , "RemoteAgentExited"    },
            { "agent-text"         , 1  , False, "RemoteAgentExited"    },
            (* Win32-OpenSSH: a connection that Windows aborted (9.x prints the read error, then fails to send the
               disconnect; 8.1 keeps the read error in a buffer that is never flushed), and a TCP connect failure
               whose Winsock error has no text *)
            { "read-aborted-windows"    , 255, False, "SSHConnectionLost" },
            { "read-aborted-windows"    , 255, True , "SSHConnectionLost" },
            { "send-disconnect-windows" , 255, False, "SSHConnectionLost" },
            { "send-disconnect-windows" , 255, True , "SSHConnectionLost" },
            { "connect-unknown-windows" , 255, True , "SSHUnreachable"    }
        },
        acpSSHExitKind[ #[[ 2 ]], fixture @ #[[ 1 ]], <| "Setup" -> #[[ 3 ]], "Nonce" -> $nonce |> ] =!= #[[ 4 ]] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Remote-ExitKind@@Tests/ACPRemote.wlt:1346,1-1397,2"
]

VerificationTest[
    {
        acpSSHExitKind[ 255, "", <| "Setup" -> True, "Nonce" -> $nonce |> ],
        acpSSHExitKind[ Missing[ "NoExitCode" ], "", <| "Setup" -> False, "Nonce" -> $nonce |> ],
        acpSSHExitKind[ Missing[ "NoExitCode" ], fixture[ "silent-255" ], <| "Setup" -> True, "Nonce" -> $nonce |> ],
        acpSSHExitKind[ 255, "", <| "Setup" -> False |> ],
        acpSSHExitKind[ 255, fixture[ "silent-255" ], <| "Setup" -> False, "Nonce" -> $nonce |> ],
        acpSSHExitKind[ 255, "client_loop: send disconnect: Broken pipe\r\n", <| "Setup" -> False |> ],
        acpSSHExitKind[ 255, fixture[ "auth-denied" ], <| "Setup" -> True |> ],
        acpSSHExitKind[ 255, StringToByteArray @ fixture[ "hostkey-changed" ], <| "Setup" -> True |> ],
        acpSSHExitKind[ 255, fixture[ "refused" ] ],
        (* another launch's markers are not this launch's *)
        acpSSHExitKind[ 120, fixture[ "folder-missing" ], <| "Setup" -> True, "Nonce" -> "ffffffffffffffff" |> ],
        acpSSHExitKind[ 120, fixture[ "folder-missing" ], <| "Setup" -> True |> ],
        acpSSHExitKind[ None, "", <| "Setup" -> False |> ],
        (* only ssh's read error, as a -q leaves it on 9.x: ssh's own prefix, not the system's text *)
        acpSSHExitKind[ 255, fixture[ "silent-255" ] <> "Read from remote host h: " <> #, <| "Setup" -> False, "Nonce" -> $nonce |> ] & /@ {
            "Connection aborted\r\n", "Connection timed out\r\n", "Unknown error\r\n"
        },
        (* the agent's own text about its network is not ssh's *)
        acpSSHExitKind[ 255, fixture[ "silent-255" ] <> "Error: connection timed out\n", <| "Setup" -> False, "Nonce" -> $nonce |> ]
    },
    {
        "SSHFailed",
        "SSHConnectionLost",
        "RemoteAgentExited",
        "SSHFailed",
        "RemoteAgentExited",
        "SSHConnectionLost",
        "SSHAuthFailed",
        "SSHHostKeyChanged",
        "SSHConnectionRefused",
        "RemoteScriptFailed",
        "RemoteScriptFailed",
        "SSHConnectionLost",
        { "SSHConnectionLost", "SSHConnectionLost", "SSHConnectionLost" },
        "RemoteAgentExited"
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-ExitKind-Edges@@Tests/ACPRemote.wlt:1399,1-1439,2"
]

(* ssh's TCP connect failure ("ssh: connect to host <h> port <p>: <error>") is SSHUnreachable whatever the error's
   text (Win32-OpenSSH leaves unmapped Winsock errors as "Unknown error", and gives a firewall's WSAEACCES as
   "Permission denied", like Linux's EACCES), with the penalty advice after a recent failed sign-in. It comes before the
   host key and sign-in rules: without a connection ssh saw no key and tried no sign-in. A refused connection and a
   name that was not found keep their kinds, a real sign-in failure stays SSHAuthFailed, and the text counts only
   before the home marker, like the other texts of ssh *)
VerificationTest[
    Module[ { context, connect },
        context = <| "SSH" -> sshSettings @ "u@h", "Nonce" -> $nonce, "Setup" -> True |>;
        connect[ error_ ] := "ssh: connect to host 10.1.2.3 port 22: " <> error <> "\r\n";
        {
            acpSSHExitKind[ 255, connect @ #, context ] & /@ {
                "Unknown error", "Host is unreachable", "Network unreachable", "Network is down", "No route to host",
                "Connection refused", "Address family not supported by protocol", "Permission denied",
                "Operation not permitted"
            },
            (* with the GSSAPI warning and a missing key's warning before it, as Windows' ssh.exe prints them *)
            acpSSHExitKind[ 255, "command-line line 0: Unsupported option \"gssapidelegatecredentials\"\r\n" <> connect[ "Permission denied" ], context ],
            acpSSHExitKind[
                255,
                "Warning: Identity file C:\\k not accessible: No such file or directory.\r\n" <> connect[ "Permission denied" ],
                context
            ],
            acpSSHExitKind[ 255, fixture[ # ], context ] & /@ {
                "refused", "dns", "dns-windows", "dns-macos", "timeout", "auth-denied", "key-missing-refused"
            },
            acpSSHExitError[ 255, fixture[ "connect-unknown-windows" ], <| context, "RecentAuthFailure" -> True |> ][ "Hint" ],
            acpSSHExitError[ 255, fixture[ "connect-unknown-windows" ], <| context, "RecentAuthFailure" -> False |> ][ "Hint" ],
            acpSSHExitError[ 255, connect[ "Permission denied" ], <| context, "RecentAuthFailure" -> True |> ][ "Hint" ],
            acpSSHExitError[ 255, fixture[ "connect-unknown-windows" ], context ][ "Output" ],
            (* after the home marker the text is not ssh's *)
            acpSSHExitKind[ 255, fixture[ "silent-255" ] <> connect[ # ], context ] & /@ { "Unknown error", "Permission denied" }
        }
    ],
    {
        {
            "SSHUnreachable", "SSHUnreachable", "SSHUnreachable", "SSHUnreachable", "SSHUnreachable", "SSHConnectionRefused",
            "SSHUnreachable", "SSHUnreachable", "SSHUnreachable"
        },
        "SSHUnreachable",
        "SSHUnreachable",
        {
            "SSHConnectionRefused", "SSHHostNotFound", "SSHHostNotFound", "SSHHostNotFound", "SSHUnreachable", "SSHAuthFailed",
            "SSHConnectionRefused"
        },
        "After failed sign-ins, the server may refuse connections from this computer for a while. Wait a minute, then reconnect.",
        None,
        "After failed sign-ins, the server may refuse connections from this computer for a while. Wait a minute, then reconnect.",
        "ssh: connect to host 10.1.2.3 port 22: Unknown error",
        { "RemoteAgentExited", "RemoteAgentExited" }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-ExitKind-ConnectFailure@@Tests/ACPRemote.wlt:1447,1-1494,2"
]

(* Hostile output: only the end of the text is matched, with linear-time patterns *)
VerificationTest[
    Module[ { adversarial, noise, tail },
        adversarial = StringRepeat[ "Host key for dd ", 16384 ];
        noise       = StringRepeat[ "some noise line from the remote\n", 2^21 ];
        tail        = noise <> "ubuntu@h: Permission denied (publickey).\r\n";
        {
            StringLength @ adversarial,
            StringLength @ noise,
            acpSSHExitKind[ 255, adversarial, <| "Setup" -> True |> ],
            acpSSHExitKind[ 255, tail, <| "Setup" -> True, "Nonce" -> $nonce |> ],
            minTiming @ acpSSHExitKind[ 255, adversarial, <| "Setup" -> True |> ] < 0.01,
            minTiming @ acpSSHExitKind[ 255, noise, <| "Setup" -> True, "Nonce" -> $nonce |> ] < 0.01,
            minTiming @ acpSSHExitError[ 255, tail, <| "Setup" -> True, "Nonce" -> $nonce |> ] < 0.02,
            StringContainsQ[ acpSSHExitError[ 255, tail, <| "Setup" -> True |> ][ "Output" ], "Permission denied" ]
        }
    ],
    { 262144, 67108864, "SSHFailed", "SSHAuthFailed", True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-ExitKind-LongLine@@Tests/ACPRemote.wlt:1497,1-1516,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SSH errors*)
VerificationTest[
    Module[ { ssh = sshSettings @ "u@h", context, error },
        context = <| "Agent" -> "OpenCode", "SSH" -> ssh, "Nonce" -> $nonce, "Setup" -> True, "InstallURL" -> "https://opencode.ai" |>;
        error[ name_, code_, extra___ ] := acpSSHExitError[ code, fixture @ name, <| context, extra |> ];
        {
            error[ "key-permissions", 255 ],
            error[ "key-missing-refused", 255 ],
            error[ "no-such-identity", 255 ][ "Hint" ],
            error[ "unknown-option", 255 ][ "Output" ],
            error[ "debug-auth", 255 ][ "Output" ],
            error[ "gssapi-unsupported", 255 ][ "Output" ],
            error[ "signal-agent", 137, "Setup" -> False ],
            error[ "silent-255", 255, "Setup" -> False ][ "Hint" ],
            error[ "agent-exited", 3, "Setup" -> False ][ "Hint" ],
            error[ "folder-missing", 120 ],
            KeyTake[ error[ "folder-access", 120 ], { "Code", "Message", "Output", "Actions" } ],
            error[ "no-agent", 127 ],
            error[ "hostkey-unknown", 255 ][ "Hint" ],
            KeyTake[ error[ "hostkey-changed", 255 ], { "Message", "Hint" } ],
            error[ "closed", 255, "RecentAuthFailure" -> True ][ "Hint" ],
            error[ "closed", 255, "RecentAuthFailure" -> False ][ "Hint" ],
            KeyTake[ error[ "nologin", 1 ], { "Code", "Hint", "Output", "Actions" } ],
            KeyTake[ error[ "empty-stdin", 125 ], { "Code", "Message", "Hint", "Output" } ],
            KeyTake[ error[ "drop-setup", 255 ], { "Code", "Message", "Output" } ],
            error[ "folder-missing", 120, "Path" -> "~/elsewhere" ][ "Message" ],
            error[ "auth-denied", 255, "Host" -> "given@host" ][ "Message" ],
            acpSSHExitError[ 255, StringRepeat[ "x", 100 ] <> "\:f7c1\r\n", context ][ "Output" ],
            StringLength @ acpSSHExitError[ 255, StringRiffle[ ConstantArray[ StringRepeat[ "y", 300 ], 20 ], "\r\n" ], context ][ "Output" ],
            Select[
                Flatten @ Table[ Lookup[ error[ name, 255 ], { "Detail", "Output", "Hint", "Message" } ], { name, FileBaseName /@ FileNames[ "*.txt", $sshErrorsDirectory ] } ],
                StringQ[ # ] && StringContainsQ[ #, "\r" ] &
            ],
            KeyTake[ acpSSHTimeoutError[ "", context ], { "Code", "Message", "Output", "Actions" } ],
            KeyTake[ acpSSHTimeoutError[ "chatbook-acp-ready\nWarning: Permanently added 'h' (ED25519) to the list of known hosts.\r\n", context ], { "Code", "Output" } ],
            KeyTake[ acpSSHTimeoutError[ fixture[ "agent-exited" ], context ], { "Code", "Message", "Output" } ],
            acpErrorInfo @ Failure[ "InvalidSSHSettings", <| "Detail" -> "\"MachineName\" is missing", "Agent" -> "OpenCode" |> ]
        }
    ],
    {
        KeyValuePattern @ {
            "Code"    -> "SSHAuthFailed",
            "Message" -> "u@h didn't accept your SSH key.",
            "Hint"    -> StringJoin[
                "Agent chats sign in without prompts: use a key that is loaded in your SSH agent or has no passphrase, and ",
                "give its file with \"Arguments\" -> {\"-i\", \"path\"} in the \"SSHSettings\" setting if it is not a default key.",
                "\n\nssh ignores the key file because other users can read it. Restrict its permissions to your user account."
            ],
            "Output"  -> StringRiffle[ StringSplit[ fixture[ "key-permissions" ], "\r\n" ], "\n" ],
            "Detail"  -> _String? (StringContainsQ[ "your user account.\n\n" <> StringRepeat[ "\:0040", 59 ] <> "\n" ]),
            "Actions" -> { "Reconnect" },
            "Data"    -> KeyValuePattern @ { "ExitCode" -> 255, "Host" -> "u@h" }
        },
        KeyValuePattern @ {
            "Code" -> "SSHConnectionRefused",
            "Hint" -> "Check that its SSH server is running and that the port is right (for another port: \"Arguments\" -> {\"-p\", \"<port>\"}).\n\nssh couldn't find the key file given with \"-i\"."
        },
        _String? (StringEndsQ[ "ssh couldn't find the key file given with \"-i\"." ]),
        "unknown option -- Z",
        "ubuntu@127.0.0.1: Permission denied (publickey).",
        "ubuntu@127.0.0.1: Permission denied (publickey).",
        KeyValuePattern @ {
            "Code"    -> "RemoteAgentExited",
            "Message" -> "OpenCode on u@h stopped unexpectedly.",
            "Hint"    -> "Exit code: 137.\n\nIt may have been stopped by the system, for example because u@h ran out of memory.",
            "Output"  -> "Killed",
            "Actions" -> { "Reconnect" }
        },
        "Exit code: 255.\n\nIt may have been stopped by the system, for example because u@h ran out of memory.",
        "Exit code: 3.",
        KeyValuePattern @ {
            "Code"    -> "RemoteFolderMissing",
            "Message" -> "The folder /home/ubuntu/no-such-folder doesn't exist on u@h.",
            "Hint"    -> None,
            "Output"  -> None,
            "Detail"  -> None,
            "Actions" -> { "ChooseDirectory", "Reconnect" }
        },
        <|
            "Code"    -> "RemoteFolderAccess",
            "Message" -> "The folder /home/ubuntu/locked on u@h can't be opened.",
            "Output"  -> "/bin/sh: 1: cd: can't cd to /home/ubuntu/locked",
            "Actions" -> { "ChooseDirectory", "Reconnect" }
        |>,
        KeyValuePattern @ {
            "Code"    -> "RemoteAgentNotFound",
            "Message" -> "OpenCode was not found on u@h.",
            "Hint"    -> "Install it there (https://opencode.ai), or give its path on u@h with the \"ACPAgentCommandLine\" setting, for example {\"/home/ubuntu/.opencode/bin/opencode\", \"acp\"}.",
            "Output"  -> None
        },
        _String? (StringStartsQ[ "Connect to it once in a terminal with ssh -l u h, check" ]),
        <| "Message" -> "The host key of u@h has changed.", "Hint" -> _String? (StringStartsQ[ "This can mean that someone is intercepting" ]) |>,
        "After failed sign-ins, the server may refuse connections from this computer for a while. Wait a minute, then reconnect.",
        None,
        <|
            "Code"    -> "RemoteScriptFailed",
            "Hint"    -> _String? (StringContainsQ[ "did not run the command" ]),
            "Output"  -> "This account is currently not available.",
            "Actions" -> { "Reconnect" }
        |>,
        <| "Code" -> "SSHFailed", "Message" -> "Couldn't connect to u@h with ssh.", "Hint" -> None, "Output" -> None |>,
        <| "Code" -> "SSHConnectionLost", "Message" -> "The connection to u@h was lost.", "Output" -> "Timeout, server ec2-203-0-113-100.compute-1.amazonaws.com not responding." |>,
        "The folder /home/ubuntu/no-such-folder doesn't exist on u@h.",
        "given@host didn't accept your SSH key.",
        StringRepeat[ "x", 100 ] <> "\:fffd",
        1501,
        { },
        <| "Code" -> "SSHConnectTimeout", "Message" -> "Connecting to u@h took too long.", "Output" -> None, "Actions" -> { "Reconnect" } |>,
        <| "Code" -> "SSHConnectTimeout", "Output" -> "Warning: Permanently added 'h' (ED25519) to the list of known hosts." |>,
        <| "Code" -> "RemoteTimeout", "Message" -> "OpenCode on u@h didn't respond in time.", "Output" -> "Error: something failed" |>,
        KeyValuePattern @ {
            "Code"    -> "InvalidSSHSettings",
            "Message" -> "The \"SSHSettings\" of this window are not valid.",
            "Hint"    -> "\"MachineName\" is missing",
            "Output"  -> None,
            "Detail"  -> "\"MachineName\" is missing",
            "Actions" -> { }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-HintOutput@@Tests/ACPRemote.wlt:1521,1-1641,2"
]

(* A traced launch line (bash as sh with an inherited xtrace, before the bootstrap could turn it off) never reaches the
   error's "Output" or "Detail" *)
VerificationTest[
    Module[ { secret = "FAKEKEY-output-0123456789", t0 = AbsoluteTime[ ], stderr, errors },
        stderr = StringRiffle[
            {
                "+ eval 'unset IFS; set +f; export OPENCODE_CONFIG_CONTENT='\\''{}'\\'' LLMKIT_API_KEY='\\''" <> secret <> "'\\'''",
                "++ export LLMKIT_API_KEY=" <> secret,
                "++ OPENCODE_CONFIG_CONTENT='{}'",
                "chatbook-acp:" <> $nonce <> ":home:/home/u",
                "chatbook-acp:" <> $nonce <> ":cwd:/home/u/p",
                "chatbook-acp:" <> $nonce <> ":agent:/home/u/.opencode/bin/opencode",
                "Error: boom"
            },
            "\n"
        ];
        errors = {
            acpSSHExitError[ 1, stderr, <| "Setup" -> True, "Nonce" -> $nonce |> ],
            acpSSHExitError[ 255, StringReplace[ stderr, "chatbook-acp:" -> "x:" ], <| "Setup" -> True |> ],
            acpSSHTimeoutError[ stderr, <| "Nonce" -> $nonce |> ]
        };
        {
            #[ "Code" ] & /@ errors,
            #[ "Output" ] & /@ errors,
            FreeQ[ errors, s_String /; StringContainsQ[ s, secret ] ],
            FreeQ[ logSince @ t0, s_String /; StringContainsQ[ s, secret ] ]
        }
    ],
    {
        { "RemoteAgentExited", "SSHFailed", "RemoteTimeout" },
        { "Error: boom", _String? (StringFreeQ[ "LLMKIT" | "OPENCODE" ]), "Error: boom" },
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-OutputDropsSecrets@@Tests/ACPRemote.wlt:1645,1-1679,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Fake ssh*)

(* The fake ssh itself, so that a broken fake fails here and not as mysterious connection errors *)
VerificationTest[
    ifFakeSSH @ Module[ { exe = $fakeSSH[ "Executable" ], before, result },
        before = Length @ fakeSSHCalls[ ];
        result = runShell[ { exe }, { "-p", "2222", "-vqlcarol", "-o", "", "--", "testhost", "printf", "%s,", "a b", "" }, "", $scratch, <| "FAKE_SSH_LOG" -> $fakeSSH[ "Log" ], "FAKE_SSH_HOME" -> $fakeSSH[ "Home" ] |> ];
        {
            result[ "ExitCode" ],
            FromCharacterCode[ Normal @ result[ "Output" ], "UTF-8" ],
            Length @ fakeSSHCalls[ ] - before,
            Last @ fakeSSHCalls[ ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        0,
        "a,b,",
        1,
        { "-p", "2222", "-vqlcarol", "-o", "", "--", "testhost", "printf", "%s,", "a b", "" }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-FakeSSH-ArgvLog@@Tests/ACPRemote.wlt:1686,1-1705,2"
]

VerificationTest[
    ifFakeSSH @ Module[ { exe = $fakeSSH[ "Executable" ], run },
        run[ host_ ] := runShell[ { exe }, { "-l", "me", "--", host, "true" }, "", $scratch ];
        {
            Lookup[ run[ "x.fail-auth.test" ], { "ExitCode", "Error" } ],
            acpSSHExitKind[ 255, run[ "x.fail-hostkey.test" ][ "Error" ] ],
            acpSSHExitKind[ 255, run[ "x.fail-changed.test" ][ "Error" ] ],
            acpSSHExitError[ 255, run[ "x.fail-keyperm.test" ][ "Error" ], <| |> ][ "Hint" ],
            acpSSHExitKind[ 255, run[ "x.fail-refused.test" ][ "Error" ] ],
            acpSSHExitKind[ 255, run[ "x.fail-dns.test" ][ "Error" ] ],
            acpSSHExitKind[ 255, run[ "x.fail-timeout.test" ][ "Error" ] ],
            acpSSHExitKind[ 255, run[ "x.fail-closed.test" ][ "Error" ] ],
            runShell[ { exe }, { "-Z", "h", "true" }, "", $scratch ][ "ExitCode" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        { 255, "me@x.fail-auth.test: Permission denied (publickey).\r\n" },
        "SSHHostKeyUnknown",
        "SSHHostKeyChanged",
        _String? (StringContainsQ[ "other users can read it" ]),
        "SSHConnectionRefused",
        "SSHHostNotFound",
        "SSHUnreachable",
        "SSHUnreachable",
        255
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-FakeSSH-FailureHosts@@Tests/ACPRemote.wlt:1707,1-1735,2"
]

VerificationTest[
    ifFakeSSH @ Module[ { exe = $fakeSSH[ "Executable" ], result, lines },
        result = runShell[
            { exe },
            { "--", "testhost", "pwd; env" },
            "",
            $scratch,
            <|
                "FAKE_SSH_HOME"     -> $fakeSSH[ "Home" ],
                "FAKE_SSH_KEEP_ENV" -> "TMPDIR",
                "TMPDIR"            -> $fakeSSH[ "Tmp" ],
                "SECRET_LOCAL_VAR"  -> "local-only",
                "USER"              -> "tester"
            |>
        ];
        lines = StringSplit[ FromCharacterCode[ Normal @ result[ "Output" ], "UTF-8" ], "\n" ];
        {
            result[ "ExitCode" ],
            First @ lines === $fakeSSH[ "Home" ],
            Complement[ First /@ StringSplit[ Rest @ lines, "=", 2 ], { "PWD", "OLDPWD", "SHLVL", "_" } ],
            MemberQ[ lines, "HOME=" <> $fakeSSH[ "Home" ] ],
            MemberQ[ lines, "TMPDIR=" <> $fakeSSH[ "Tmp" ] ],
            MemberQ[ lines, "PATH=/usr/bin:/bin" ]
        }
    ],
    Missing[ "TestSkipped" ] | { 0, True, { "HOME", "LOGNAME", "PATH", "SHELL", "TMPDIR", "USER" }, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-FakeSSH-CleanEnvironment@@Tests/ACPRemote.wlt:1737,1-1765,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*One-shot runs*)

(* Tests for ACP/Remote.wl: the script templates (Assets/RemoteScripts), the READY handshake, the framed output
   (ACPR1), the runner acpRemoteRun through the fake ssh, the errors of one-shot runs, the host failure latch and the
   folder listing (ACPLS1). The pure tests always run; the runner tests are skipped without the fake ssh (ifFakeSSH) and
   need neither ACPLink nor python. The listing fixtures in Data/ACP/RemoteListing (nonce "N") were made by list.sh
   under dash, with the remote home written as /home/u. *)
VerificationTest[
    $listingDirectory = FileNameJoin @ { DirectoryName @ $TestFileName, "Data", "ACP", "RemoteListing" };
    $remoteScriptsDirectory = FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "Assets", "RemoteScripts" };
    $remoteNonce = "0123456789abcdef0123456789abcdef";
    $procfsQ = $OperatingSystem === "Unix" && DirectoryQ[ "/proc/self" ];

    (* Waiting with Pause lets the pump (the runs' polls) run *)
    waitUntil // Attributes = { HoldFirst };
    waitUntil[ cond_, timeout_: 30 ] := Module[ { deadline = AbsoluteTime[ ] + timeout },
        While[ ! TrueQ @ cond && AbsoluteTime[ ] < deadline, Pause[ 0.05 ] ];
        TrueQ @ cond
    ];

    (* Canonical settings of a host of the fake ssh *)
    remoteSSH[ host_String: "testhost", extra___Rule ] := sshSettings @ fakeSSHSettings[ host, extra ];

    (* acpRemoteRun, waiting for its result *)
    runRemote[ ssh_, body_, opts_Association: <| |> ] := Module[ { result = None },
        acpRemoteRun[ ssh, body, (result = #) &, opts ];
        waitUntil[ AssociationQ @ result, 60 ];
        result
    ];

    frameText[ result_Association, name_String ] := Replace[
        result[ "Frames", name, "Output" ],
        { b_ByteArray :> ByteArrayToString[ b, "UTF-8" ], _ -> Missing[ "NoFrame" ] }
    ];

    processRuns[ ] := Wolfram`Chatbook`ACP`Git`Private`$gitRuns;
    slotsInUse[ ssh_ ] := Wolfram`Chatbook`ACP`Remote`Private`remoteSlotsInUse @ acpSSHHostKey @ ssh;

    fileDescriptors[ ] := Length @ FileNames[ "*", "/proc/" <> ToString @ $ProcessID <> "/fd" ];

    (* The processes whose command line contains s (Linux) *)
    processesWith[ s_String ] := Select[
        Select[ FileNames[ "*", "/proc" ], StringMatchQ[ FileNameTake @ #, DigitCharacter.. ] & ],
        StringContainsQ[ StringReplace[ ByteArrayToString[ readFileBytes @ FileNameJoin @ { #, "cmdline" }, "ISOLatin1" ], "\000" -> " " ], s ] &
    ];

    writeText[ file_String, text_String ] := (BinaryWrite[ file, StringToByteArray[ text, "UTF-8" ] ]; Close @ file; file);

    (* Bytes of a stream for the parser: strings (UTF-8), byte lists and ByteArrays *)
    toBytes[ b_ByteArray ] := b;
    toBytes[ s_String ] := StringToByteArray[ s, "UTF-8" ];
    toBytes[ l_List ] := ByteArray @ l;
    record[ name_String, exit_String, out_, err_, otrunc_: 0, etrunc_: 0 ] := With[ { o = toBytes @ out, e = toBytes @ err },
        Join[
            toBytes @ StringRiffle[ { "F", name, exit, ToString @ Length @ o, ToString @ otrunc, ToString @ Length @ e, ToString @ etrunc }, " " ],
            ByteArray[ { 10 } ], o, e, ByteArray[ { 10 } ]
        ]
    ];
    stream[ parts___ ] := Join @@ ( toBytes /@ { parts } );

    (* The body of the remote git script (Git.wl's gitRemoteScript, B6.1: the template filled from Git.wl's constants) *)
    gitTestBody[ dir_String, full_ ] := Wolfram`Chatbook`ACP`Git`Private`gitRemoteScript[ dir, If[ TrueQ @ full, "Full", "Summary" ] ];

    (* A listing fixture *)
    listingFixture[ name_String ] := readFileBytes @ FileNameJoin @ { $listingDirectory, name <> ".bin" };
    entryNamed[ listing_Association, name_String ] := SelectFirst[ listing[ "Entries" ], #[ "Name" ] === name &, None ];

    (* Login shells that print 8 MB at once, or 80 KB in 2 KB pieces 20 ms apart, before they run the command (ssh
       wrappers around the fake) *)
    If[ TrueQ @ $fakeSSHAvailableQ,
        $noisySSH = writeText[
            FileNameJoin @ { $scratch, "noisy-ssh" },
            "#!/bin/sh\nhead -c 8388608 /dev/zero | tr '\\000' n\nexec '" <> $fakeSSH[ "Executable" ] <> "' \"$@\"\n"
        ];
        $tricklingSSH = writeText[
            FileNameJoin @ { $scratch, "trickling-ssh" },
            "#!/bin/sh\ni=0\nwhile [ $i -lt 40 ]; do head -c 2048 /dev/zero | tr '\\000' n; sleep 0.02; i=$((i+1)); done\nexec '" <>
                $fakeSSH[ "Executable" ] <> "' \"$@\"\n"
        ];
        RunProcess[ { "chmod", "755", $noisySSH, $tricklingSSH } ]
    ];

    (* The run's polls (gitPoll), each timed *)
    timedPolls // Attributes = { HoldFirst };
    timedPolls[ eval_ ] := Module[ { times = { }, result },
        Internal`InheritedBlock[ { Wolfram`Chatbook`ACP`Git`Private`gitPoll },
            DownValues[ Wolfram`Chatbook`ACP`Git`Private`gitPoll ] = Prepend[
                DownValues @ Wolfram`Chatbook`ACP`Git`Private`gitPoll,
                HoldPattern[ Wolfram`Chatbook`ACP`Git`Private`gitPoll[ id_String ] ] :>
                    With[ { t = AbsoluteTiming @ Block[ { $timedPoll = True }, Wolfram`Chatbook`ACP`Git`Private`gitPoll @ id ] },
                        AppendTo[ times, First @ t ];
                        Last @ t
                    ] /; ! TrueQ @ $timedPoll
            ];
            result = eval
        ];
        { result, times }
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPRemote-RunnerDefinitions@@Tests/ACPRemote.wlt:1776,1-1871,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Scripts*)

(* One-shot runs use "exec /bin/sh -s" as the remote command, after the host; the script is never on a command line *)
VerificationTest[
    Module[ { ssh, command },
        ssh     = sshSettings @ <| "MachineName" -> "devbox", "Username" -> "me", "Arguments" -> { "-p", "2222" } |>;
        command = acpSSHCommand[ <| ssh, "Program" -> "ssh" |>, $acpSSHScriptCommand ];
        {
            Take[ command, -4 ],
            StringFreeQ[ $acpSSHScriptCommand, "\"" | "\\" ],
            ifFakeSSH @ Module[ { before, result, call },
                before = Length @ fakeSSHCalls[ ];
                result = runRemote[ remoteSSH[ ], "cb_end\n" ];
                call   = Last @ fakeSSHCalls[ ];
                {
                    result[ "Status" ],
                    Length @ fakeSSHCalls[ ] - before,
                    Take[ call, -4 ],
                    call === Rest @ acpSSHCommand[ <| remoteSSH[ ], "Program" -> $fakeSSH[ "Executable" ] |>, $acpSSHScriptCommand ],
                    FreeQ[ call, _String? (StringContainsQ[ "ACPR1" ]) ]
                }
            ]
        }
    ],
    {
        { "-T", "--", "devbox", "exec /bin/sh -s" },
        True,
        Missing[ "TestSkipped" ] | { "OK", 1, { "-T", "--", "testhost", "exec /bin/sh -s" }, True, True }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-ScriptCommand@@Tests/ACPRemote.wlt:1878,1-1906,2"
]

(* Every generated script is under $acpRemoteMaxScript, also with the longest paths; the first write (READY) is short *)
VerificationTest[
    Module[ { long, bodies, sizes, parts },
        long   = "/" <> StringRepeat[ "x", $acpRemoteMaxPathLength - 1 ];
        bodies = <|
            "GitSummary"    -> gitTestBody[ "~/projects/app", False ],
            "GitFull"       -> gitTestBody[ "~/projects/app", True ],
            "GitLongPath"   -> gitTestBody[ long, True ],
            "List"          -> acpRemoteListBody[ "0123456789abcdef", "~/projects/app", None, True ],
            "ListLongPaths" -> acpRemoteListBody[ "0123456789abcdef", long, long, True ]
        |>;
        sizes = Length @ acpRemoteScript[ $remoteNonce, 40, # ][ "Script" ] & /@ bodies;
        parts = acpRemoteScript[ $remoteNonce, 40, "cb_end\n" ];
        {
            AllTrue[ sizes, # < $acpRemoteMaxScript & ],
            sizes[ "GitFull" ] < 10500 && sizes[ "List" ] < 5000,
            ByteArrayToString @ parts[ "Ready" ],
            Length @ parts[ "Ready" ] < 80,
            ByteArrayToString @ parts[ "Marker" ],
            StringStartsQ[ ByteArrayToString @ parts[ "Script" ], "cb_nonce='" <> $remoteNonce <> "'\n" ],
            StringContainsQ[ ByteArrayToString @ parts[ "Script" ], "cb_watchdog '40'" ],
            StringEndsQ[ ByteArrayToString @ parts[ "Script" ], "\ncb_end\n" ],
            acpRemoteScript[ $remoteNonce, 40, StringRepeat[ ": x\n", 5000 ] ],
            acpRemoteScript[ "not a nonce'", 40, "cb_end\n" ]
        }
    ],
    {
        True,
        True,
        "set +xv; printf '\\n#ACPR1 " <> $remoteNonce <> " READY\\n'\n",
        True,
        "#ACPR1 " <> $remoteNonce <> " READY\n",
        True,
        True,
        True,
        Failure[ "RemoteScriptTooLarge", _ ],
        Failure[ "InvalidRemoteScript", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-ScriptSize@@Tests/ACPRemote.wlt:1909,1-1948,2"
]

(* Every generated script passes dash -n (sh -n without dash) and has no CR *)
VerificationTest[
    ifFakeSSH @ Module[ { checker, scripts },
        checker = SelectFirst[ { "/bin/dash", "/usr/bin/dash" }, FileExistsQ, "/bin/sh" ];
        scripts = ByteArrayToString[ acpRemoteScript[ $remoteNonce, 40, # ][ "Script" ], "UTF-8" ] & /@ {
            gitTestBody[ "~/odd dir's", False ],
            gitTestBody[ "/srv/a\n  b", True ],
            acpRemoteListBody[ "N", "a\n# b'", "/srv/x@FULL@y", True ],
            "cb_end\n"
        };
        {
            runShell[ { checker }, { "-n" }, #, $scratch ][ "ExitCode" ] & /@ scripts,
            StringFreeQ[ #, "\r" ] & /@ scripts,
            StringFreeQ[ acpRemoteTemplate[ # ], "\r" ] & /@ { "prelude", "git", "list" }
        }
    ],
    Missing[ "TestSkipped" ] | { { 0, 0, 0, 0 }, { True, True, True, True }, { True, True, True } },
    SameTest -> MatchQ,
    TestID   -> "Remote-ScriptSyntax@@Tests/ACPRemote.wlt:1951,1-1969,2"
]

(* Values are inserted after the templates were minified, with one StringReplace: lines inside a value are never
   trimmed or dropped, and a value that looks like a placeholder stays as it is *)
VerificationTest[
    Module[ { values, body, git },
        values = { "a\n  b", "a\n\nb", "a\n# b'", "x@FULL@y", "@NONCE@ @DEADLINE@ @DIR@", $tricky };
        body   = StringJoin[
            MapIndexed[ "cb_value v" <> ToString @ First @ #2 <> " " <> acpShellQuote @ #1 <> "\n" &, values ],
            "cb_end\n"
        ];
        git = gitTestBody[ "/srv/x@FULL@y", False ];
        {
            StringContainsQ[ git, "cd -- '/srv/x@FULL@y' " ],
            StringContainsQ[ git, "\ncb_full=0\n" ],
            StringContainsQ[ acpRemoteListBody[ "N", "a\n  b", None, False ], " 'a\n  b' " ],
            StringContainsQ[ ByteArrayToString @ acpRemoteScript[ $remoteNonce, 40, body ][ "Script" ], "'a\n# b'\\'''" ],
            ifFakeSSH @ With[ { result = runRemote[ remoteSSH[ ], body ] },
                { result[ "Status" ], frameText[ result, "v" <> ToString @ # ] & /@ Range @ Length @ values }
            ]
        }
    ],
    {
        True,
        True,
        True,
        True,
        Missing[ "TestSkipped" ] | { "OK", { "a\n  b", "a\n\nb", "a\n# b'", "x@FULL@y", "@NONCE@ @DEADLINE@ @DIR@", $tricky } }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-ScriptValues@@Tests/ACPRemote.wlt:1973,1-2000,2"
]

(* A template read with CRLF line ends (a Windows checkout without .gitattributes) gives the same script *)
VerificationTest[
    Module[ { crlf },
        crlf = AssociationMap[
            StringReplace[ ByteArrayToString[ readFileBytes @ FileNameJoin @ { $remoteScriptsDirectory, # <> ".sh" }, "UTF-8" ], "\n" -> "\r\n" ] &,
            { "prelude", "git", "list" }
        ];
        {
            AllTrue[ crlf, StringContainsQ[ "\r\n" ] ],
            KeyValueMap[ Wolfram`Chatbook`ACP`Remote`Private`remoteTemplateText[ #2 ] === acpRemoteTemplate[ #1 ] &, crlf ],
            acpRemoteMinify[ "# comment\n  a=1\n\n\tb=2 # not a comment line\n    # indented comment\n'\n  kept'\n" ]
        }
    ],
    { True, { True, True, True }, "a=1\nb=2 # not a comment line\n'\nkept'\n" },
    SameTest -> MatchQ,
    TestID   -> "Remote-TemplateCRLF@@Tests/ACPRemote.wlt:2003,1-2018,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Framed output*)
VerificationTest[
    Module[ { all, begin, end, ok, parsed, cut, malformed, chunk, big, bigParsed, time },
        all   = ByteArray @ Range[ 0, 255 ];
        begin = "\n#ACPR1 abc123 BEGIN\n";
        end   = "#ACPR1 abc123 END\n";
        ok    = stream[
            "Welcome!\n#ACPR1 not-the-nonce BEGIN\nF fake 0 3 0 0 0\nxyz\n",
            begin,
            record[ "bytes", "0", all, all ],
            record[ "empty", "-", { }, { } ],
            record[ "decoy", "3", end, begin, 1, 1 ],
            "S stopped\n",
            end
        ];
        parsed = acpRemoteParseFrames[ ok, "abc123" ];
        cut    = acpRemoteParseFrames[ Take[ ok, Length @ ok - 40 ], "abc123" ];
        malformed = acpRemoteParseFrames[ stream[ begin, #, end ], "abc123" ][ "Malformed" ] & /@ {
            "F x 0 1a 0 0 0\n",         (* a length that is not a number *)
            "F x 0 2+2 0 0 0\n",        (* never evaluated *)
            "F x 0 2 0 0 0\nabc\n",     (* the data is not followed by a newline *)
            "F x/y 0 0 0 0 0\n\n",      (* a name with a character outside [A-Za-z0-9._-] *)
            StringRepeat[ "F", 600 ],   (* a record line longer than 512 bytes *)
            "\n"
        };
        chunk     = ByteArray @ RandomInteger[ 255, 70000 ];
        big       = Join[ toBytes @ begin, Join @@ Table[ record[ "c" <> ToString @ i, "-", chunk, { } ], { i, 600 } ], toBytes @ end ];
        time      = First @ AbsoluteTiming[ bigParsed = acpRemoteParseFrames[ big, "abc123", 616 ] ];
        {
            Lookup[ parsed, { "Begun", "Complete", "Stop", "Malformed", "Cut" } ],
            Keys @ parsed[ "Frames" ],
            parsed[ "Frames", "bytes" ] === <| "ExitCode" -> 0, "Output" -> all, "OutputTruncated" -> False, "Error" -> all, "ErrorTruncated" -> False |>,
            parsed[ "Frames", "empty" ] === <| "ExitCode" -> None, "Output" -> ByteArray[ { } ], "OutputTruncated" -> False, "Error" -> ByteArray[ { } ], "ErrorTruncated" -> False |>,
            parsed[ "Frames", "decoy" ] === <| "ExitCode" -> 3, "Output" -> toBytes @ end, "OutputTruncated" -> True, "Error" -> toBytes @ begin, "ErrorTruncated" -> True |>,
            Lookup[ cut, { "Begun", "Complete", "Stop", "Malformed", "Cut" } ],
            Keys @ cut[ "Frames" ],
            malformed,
            Lookup[ acpRemoteParseFrames[ stream[ "F x 0 0 0 0 0\n\n", end ], "abc123" ], { "Begun", "Complete", "Frames" } ],
            acpRemoteParseFrames[ ok, "other" ][ "Begun" ],
            Lookup[ acpRemoteParseFrames[ stream[ begin, "S tmpdir\n", end ], "abc123" ], { "Complete", "Stop", "Frames" } ],
            Length @ big > 40 * 10^6,
            time < 1,
            Lookup[ bigParsed, { "Complete", "Malformed" } ],
            Length @ bigParsed[ "Frames" ],
            bigParsed[ "Frames", "c600", "Output" ] === chunk
        }
    ],
    {
        { True, True, "stopped", False, False },
        { "bytes", "empty", "decoy" },
        True,
        True,
        True,
        { True, False, None, False, True },
        { "bytes", "empty" },
        { "Record", "Record", "Record", "Record", "Record", "Record" },
        { False, False, <| |> },
        False,
        { True, "tmpdir", <| |> },
        True,
        True,
        { True, False },
        600,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-ParseFrames@@Tests/ACPRemote.wlt:2023,1-2089,2"
]

(* Hostile output: parsing stops after maxFrames frames, at once, and an S record (the script's early stop) must be
   followed by END, so a flood of S records stops at the second one; the S record doesn't count toward maxFrames *)
VerificationTest[
    Module[ { begin, end, seventeen, many, p17, t17, pMany, tMany, sFlood, pS, tS, parse },
        begin     = "\n#ACPR1 cap BEGIN\n";
        end       = "#ACPR1 cap END\n";
        seventeen = stream[ begin, Sequence @@ Table[ record[ "f" <> ToString @ i, "0", "x", "" ], { i, 17 } ], end ];
        many      = stream[ begin, StringRepeat[ "F f 0 0 0 0 0\n\n", 200000 ], end ];
        sFlood    = stream[ begin, StringRepeat[ "S x\n", 200000 ], end ];
        t17       = minTiming[ p17 = acpRemoteParseFrames[ seventeen, "cap" ] ];
        tMany     = First @ AbsoluteTiming[ pMany = acpRemoteParseFrames[ many, "cap", 516 ] ];
        tS        = minTiming[ pS = acpRemoteParseFrames[ sFlood, "cap" ] ];
        parse[ parts___ ] := Lookup[ acpRemoteParseFrames[ stream[ begin, parts ], "cap" ], { "Complete", "Stop", "Malformed", "Cut", "Frames" } ];
        {
            Lookup[ p17, { "Begun", "Complete", "Malformed" } ],
            Keys @ p17[ "Frames" ] === Table[ "f" <> ToString @ i, { i, 16 } ],
            t17 < 0.01,
            Lookup[ pMany, { "Complete", "Malformed" } ],
            Keys @ pMany[ "Frames" ],
            tMany < 0.5,
            Lookup[ acpRemoteParseFrames[ seventeen, "cap", 17 ], { "Complete", "Malformed" } ],
            Length @ sFlood > 800000,
            Lookup[ pS, { "Stop", "Malformed", "Complete" } ],
            tS < 0.01,
            (* a frame after the stop; two stops; a stop at the end of a cut stream *)
            MapAt[ Keys, parse[ record[ "a", "0", "x", "" ], "S early\n", record[ "b", "0", "y", "" ], end ], 5 ],
            parse[ "S a\nS b\n", end ],
            parse[ "S x\n" ],
            (* exactly maxFrames frames, then the stop *)
            MapAt[ Length, parse[ Sequence @@ Table[ record[ "f" <> ToString @ i, "0", "x", "" ], { i, 16 } ], "S late\n", end ], 5 ]
        }
    ],
    {
        { True, False, "TooManyFrames" }, True, True, { False, "TooManyFrames" }, { "f" }, True, { True, False },
        True,
        { "x", "Record", False },
        True,
        { False, "early", "Record", False, { "a" } },
        { False, "a", "Record", False, <| |> },
        { False, "x", False, True, <| |> },
        { True, "late", False, False, 16 }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-ParseFrames-RecordCap@@Tests/ACPRemote.wlt:2093,1-2135,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Errors*)

(* The errors of one-shot runs (B5.3), from hand-made results of acpProcessRun *)
VerificationTest[
    Module[ { ssh, key, raw, begin, end, result, info, results, penalty },
        ssh   = sshSettings @ <| "MachineName" -> "h.example", "Username" -> "me" |>;
        key   = acpSSHHostKey @ ssh;
        begin = "\n#ACPR1 n1 BEGIN\n";
        end   = "#ACPR1 n1 END\n";
        raw[ exit_, out_, err_, flags___Rule ] := <|
            "ExitCode" -> exit, "Output" -> toBytes @ out, "Error" -> toBytes @ err, "TimedOut" -> False, "TooLarge" -> False,
            "Cancelled" -> False, "StartFailed" -> False, "Duration" -> 1, "Arguments" -> { "ssh", "me@h.example" },
            "NoReady" -> False, "ErrorTruncated" -> False, flags
        |>;
        result[ r_ ] := acpRemoteResult[ r, "n1", ssh, 16 ];
        info[ r_ ] := With[ { res = result @ r }, { res[ "Status" ], Replace[ res[ "Error" ], e_Association :> e[ "Code" ] ] } ];
        KeyDropFrom[ $acpRemoteHostAuthFailedAt, key ];
        results = {
            result @ raw[ 255, "", fixture[ "auth-denied" ] ],
            result @ raw[ 127, "", "sh: 1: exec: /bin/sh: not found\n" ],
            result @ raw[ None, "noise", "", "NoReady" -> True ],
            result @ raw[ None, "", "", "TooLarge" -> True ]
        };
        $acpRemoteHostAuthFailedAt[ key ] = AbsoluteTime[ ];
        penalty = result @ raw[ 255, "", fixture[ "closed" ] ];
        KeyDropFrom[ $acpRemoteHostAuthFailedAt, key ];
        {
            info /@ {
                raw[ 255, "", fixture[ "auth-denied" ] ],
                raw[ 127, "", "sh: 1: exec: /bin/sh: not found\n" ],
                raw[ None, "noise", "", "NoReady" -> True ],
                raw[ 255, begin, "Connection to h.example closed by remote host.\r\n" ],
                raw[ None, begin, "" ],
                raw[ 143, begin, "" ],
                raw[ None, begin, "", "TimedOut" -> True ],
                raw[ None, "", "debug1: Connecting to h.example\r\n", "TimedOut" -> True ],
                raw[ None, "", "", "StartFailed" -> True ],
                raw[ 0, begin <> end, "" ],
                raw[ None, begin, "", "Cancelled" -> True ],
                raw[ None, "", "", "TooLarge" -> True ],
                raw[ 0, begin <> "F x 0 1a 0 0 0\n", "" ],
                raw[ 255, "", fixture[ "closed" ] ]
            },
            #[ "Error", "Actions" ] & /@ results,
            #[ "Host" ] & /@ results,
            StringFreeQ[ ToString @ #[ "Error", "Detail" ], "\r" ] & /@ results,
            StringEndsQ[ results[[ 1, "Error", "Output" ]], "Permission denied (publickey)." ],
            StringContainsQ[ results[[ 2, "Error", "Hint" ]], "did not run the command" ],
            StringContainsQ[ results[[ 2, "Error", "Output" ]], "not found" ],
            StringContainsQ[ results[[ 3, "Error", "Hint" ]], "printed too much text" ],
            results[[ 4, "Error", "Hint" ]],
            penalty[ "Error", "Code" ],
            StringContainsQ[ penalty[ "Error", "Hint" ], acpConnectionLabel[ "ErrorSSHPenaltyDetail" ] ]
        }
    ],
    {
        {
            { "SSHFailed", "SSHAuthFailed" },
            { "SSHFailed", "RemoteScriptFailed" },
            { "NoReady", "RemoteScriptFailed" },
            { "Incomplete", "SSHConnectionLost" },
            { "Incomplete", "SSHConnectionLost" },
            { "RemoteTimedOut", "RemoteOperationTimedOut" },
            { "TimedOut", "RemoteOperationTimedOut" },
            { "TimedOut", "SSHConnectTimeout" },
            { "StartFailed", "SSHStartFailed" },
            { "OK", None },
            { "Cancelled", None },
            { "TooLarge", "RemoteScriptFailed" },
            { "Incomplete", "RemoteScriptFailed" },
            { "SSHFailed", "SSHUnreachable" }
        },
        { { }, { }, { }, { } },
        { "me@h.example", "me@h.example", "me@h.example", "me@h.example" },
        { True, True, True, True },
        True,
        True,
        True,
        True,
        None,
        "SSHUnreachable",
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-ErrorInfo@@Tests/ACPRemote.wlt:2142,1-2224,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Runs*)
VerificationTest[
    ifFakeSSH @ Module[ { result },
        result = runRemote[ remoteSSH[ ], "cb_run a 100 100 printf 'hello\\n'\ncb_value home \"$HOME\"\ncb_end\n", <| "Label" -> "Test" |> ];
        {
            Lookup[ result, { "Status", "Stop", "ExitCode", "Error", "Host" } ],
            Keys @ result[ "Frames" ],
            result[ "Frames", "a" ] === <|
                "ExitCode"        -> 0,
                "Output"          -> toBytes[ "hello\n" ],
                "OutputTruncated" -> False,
                "Error"           -> ByteArray[ { } ],
                "ErrorTruncated"  -> False
            |>,
            frameText[ result, "home" ] === $fakeSSH[ "Home" ],
            0 < result[ "Duration" ] < 10
        }
    ],
    Missing[ "TestSkipped" ] | { { "OK", None, 0, None, "testhost" }, { "a", "home" }, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-OK@@Tests/ACPRemote.wlt:2229,1-2249,2"
]

(* Exit codes of commands, early stops, and scripts that end without END *)
VerificationTest[
    ifFakeSSH @ Module[ { stops, exit7, exit255, term },
        stops   = runRemote[ remoteSSH[ ], "cb_run ok 100 100 true\ncb_run three 100 100 sh -c 'exit 3'\ncb_run missing 100 100 no-such-command-cb\ncb_stop early\ncb_value never x\n" ];
        exit7   = runRemote[ remoteSSH[ ], "cb_value a 1\nexit 7\n" ];
        exit255 = runRemote[ remoteSSH[ ], "cb_value a 1\nexit 255\n" ];
        term    = runRemote[ remoteSSH[ ], "cb_value a 1\nkill -s TERM $$\nsleep 5\n" ];
        {
            Lookup[ stops, { "Status", "Stop", "ExitCode" } ],
            #[ "ExitCode" ] & /@ stops[ "Frames" ],
            StringLength @ ByteArrayToString @ stops[ "Frames", "missing", "Error" ] > 0,
            Lookup[ exit7, { "Status", "ExitCode" } ],
            exit7[ "Error", "Code" ],
            Keys @ exit7[ "Frames" ],
            Lookup[ exit255, { "Status", "ExitCode" } ],
            exit255[ "Error", "Code" ],
            Lookup[ term, { "Status", "ExitCode" } ],
            term[ "Error", "Code" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        { "OK", "early", 0 },
        <| "ok" -> 0, "three" -> 3, "missing" -> 127 |>,
        True,
        { "Incomplete", 7 },
        "RemoteScriptFailed",
        { "a" },
        { "Incomplete", 255 },
        "SSHConnectionLost",
        { "RemoteTimedOut", 143 },
        "RemoteOperationTimedOut"
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-ExitCodes@@Tests/ACPRemote.wlt:2252,1-2285,2"
]

(* Frames are cut at their caps (the command stops early); a run whose output passes "MaxOutput" is "TooLarge" *)
VerificationTest[
    ifFakeSSH @ Module[ { capped, large },
        capped = runRemote[ remoteSSH[ ], "cb_run big 1000 100 sh -c 'head -c 100000 /dev/zero; head -c 5000 /dev/zero >&2'\ncb_end\n" ];
        large  = runRemote[ remoteSSH[ ], "cb_run big 300000 0 head -c 300000 /dev/zero\ncb_end\n", <| "MaxOutput" -> 100000 |> ];
        {
            capped[ "Status" ],
            Lookup[ capped[ "Frames", "big" ], { "OutputTruncated", "ErrorTruncated" } ],
            Length /@ Lookup[ capped[ "Frames", "big" ], { "Output", "Error" } ],
            Lookup[ large, { "Status", "Frames" } ],
            Lookup[ large[ "Error" ], { "Code", "Hint", "Actions" } ]
        }
    ],
    Missing[ "TestSkipped" ] | { "OK", { True, True }, { 1000, 100 }, { "TooLarge", <| |> }, { "RemoteScriptFailed", None, { } } },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-Truncation@@Tests/ACPRemote.wlt:2288,1-2303,2"
]

(* The READY handshake: with a host that reads nothing for 3 s (like ssh before it has signed in), starting a run with
   a 75 KB script returns at once (a write of more than the pipe holds would wait), and the script is written later *)
VerificationTest[
    ifFakeSSH @ Module[ { body, call, result = None },
        body = StringJoin[ StringRepeat[ ": padding padding padding padding padding\n", 1800 ], "cb_value x ok\ncb_end\n" ];
        withFakeSSHEnvironment[ <| "FAKE_SSH_DELAY" -> "3" |>,
            Block[ { $acpRemoteMaxScript = 2^17 },
                call = First @ AbsoluteTiming @ acpRemoteRun[ remoteSSH[ "x.slow.test" ], body, (result = #) &, <| |> ]
            ]
        ];
        waitUntil[ AssociationQ @ result, 30 ];
        { StringLength @ body > 70000, call < 0.5, result[ "Status" ], frameText[ result, "x" ], result[ "Duration" ] > 2.5 }
    ],
    Missing[ "TestSkipped" ] | { True, True, "OK", "ok", True },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-Handshake@@Tests/ACPRemote.wlt:2307,1-2321,2"
]

(* The local timeout: after BEGIN the operation took too long, before it the connection did *)
VerificationTest[
    ifFakeSSH @ Module[ { after, before },
        after  = runRemote[ remoteSSH[ ], "cb_run s 10 10 sleep 31.25\ncb_end\n", <| "Timeout" -> 2 |> ];
        before = runRemote[ remoteSSH[ "x.hang.test" ], "cb_end\n", <| "Timeout" -> 2 |> ];
        {
            Lookup[ after, { "Status", "ExitCode" } ],
            Lookup[ after[ "Error" ], { "Code", "Message", "Actions" } ],
            after[ "Duration" ] < 6,
            before[ "Status" ],
            Lookup[ before[ "Error" ], { "Code", "Message" } ],
            before[ "Duration" ] < 6
        }
    ],
    Missing[ "TestSkipped" ] | {
        { "TimedOut", None },
        { "RemoteOperationTimedOut", "The operation on testhost took too long.", { } },
        True,
        "TimedOut",
        { "SSHConnectTimeout", "Connecting to x.hang.test took too long." },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-Timeout@@Tests/ACPRemote.wlt:2324,1-2347,2"
]

(* The remote watchdog (a backstop: normally the local timeout fires first) ends the remote script and everything it
   started at its deadline *)
VerificationTest[
    ifFakeSSH @ Module[ { result },
        result = Block[ { $acpRemoteDeadlineSlack = -28 },
            runRemote[ remoteSSH[ ], "cb_run s 10 10 sleep 32.5\ncb_end\n", <| "Timeout" -> 30 |> ]
        ];
        {
            Lookup[ result, { "Status", "ExitCode" } ],
            result[ "Error", "Code" ],
            result[ "Duration" ] < 10,
            ! $procfsQ || waitUntil[ processesWith[ "sleep 32.5" ] === { }, 10 ]
        }
    ],
    Missing[ "TestSkipped" ] | { { "RemoteTimedOut", 143 }, "RemoteOperationTimedOut", True, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-Watchdog@@Tests/ACPRemote.wlt:2351,1-2366,2"
]

(* A run is cancelled when its owner window is gone or its request is superseded; after READY it is killed at once;
   a run that is cancelled before it starts makes no connection *)
VerificationTest[
    ifFakeSSH @ Module[ { nbo, owner = None, superseded = None, early = None, key, t, before },
        nbo = NotebookObject[ "acp-remote-test-owner" ];
        acpWindowUpdate[ nbo, <| #, "Status" -> "Ready" |> & ];
        acpRemoteRun[ remoteSSH[ ], "cb_run s 10 10 sleep 3\ncb_end\n", (owner = #) &, <| "Owner" -> nbo |> ];
        Pause[ 0.7 ];
        acpWindowDrop @ nbo;
        waitUntil[ AssociationQ @ owner, 10 ];

        key = { "acp-remote-test", 1 };
        acpSetCurrentRequest[ key, "t1" ];
        acpRemoteRun[ remoteSSH[ ], "cb_run s 10 10 sleep 3\ncb_end\n", (superseded = #) &, <| "Request" -> { key, "t1" } |> ];
        Pause[ 0.7 ];
        acpSetCurrentRequest[ key, "t2" ];
        t = AbsoluteTime[ ];
        waitUntil[ AssociationQ @ superseded, 10 ];
        t = AbsoluteTime[ ] - t;

        before = Length @ fakeSSHCalls[ ];
        acpRemoteRun[ remoteSSH[ ], "cb_end\n", (early = #) &, <| "Request" -> { key, "t1" } |> ];
        waitUntil[ AssociationQ @ early, 10 ];
        {
            Lookup[ owner, { "Status", "Error" } ],
            Lookup[ superseded, { "Status", "Error" } ],
            t < 1,
            waitUntil[ processRuns[ ] === <| |>, 5 ],
            Lookup[ early, { "Status", "Error" } ],
            Length @ fakeSSHCalls[ ] - before
        }
    ],
    Missing[ "TestSkipped" ] | { { "Cancelled", None }, { "Cancelled", None }, True, True, { "Cancelled", None }, 0 },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-Cancelled@@Tests/ACPRemote.wlt:2370,1-2403,2"
]

(* Superseded before READY (ssh may still be signing in): the continuation gets "Cancelled" at once, but ssh is not
   killed: it ends by itself (exit code 0), and the run keeps its host slot until then *)
VerificationTest[
    ifFakeSSH @ Module[ { ssh, key, t0, result = None, cancelSeconds, slots, background, drained },
        ssh = remoteSSH[ "x.slow.test" ];
        key = { "acp-remote-test", 2 };
        t0  = AbsoluteTime[ ];
        acpSetCurrentRequest[ key, "t1" ];
        withFakeSSHEnvironment[ <| "FAKE_SSH_DELAY" -> "3" |>,
            acpRemoteRun[ ssh, "cb_end\n", (result = #) &, <| "Request" -> { key, "t1" } |> ]
        ];
        Pause[ 0.3 ];
        acpSetCurrentRequest[ key, "t2" ];
        cancelSeconds = AbsoluteTime[ ];
        waitUntil[ AssociationQ @ result, 5 ];
        cancelSeconds = AbsoluteTime[ ] - cancelSeconds;
        slots      = slotsInUse @ ssh;
        background = acpBackgroundRunsQ[ ];
        waitUntil[ processRuns[ ] === <| |>, 15 ];
        drained = Lookup[ Select[ logSince @ t0, #[ "Where" ] === "ProcessDrained" & ], "Data" ];
        {
            Lookup[ result, { "Status", "Error" } ],
            cancelSeconds < 0.5,
            slots,
            background,
            Lookup[ drained, { "How", "ExitCode" } ],
            drained[[ 1, "Seconds" ]] > 2,
            slotsInUse @ ssh,
            acpBackgroundRunsQ[ ]
        }
    ],
    Missing[ "TestSkipped" ] | { { "Cancelled", None }, True, 1, True, { { "Finished", 0 } }, True, 0, False },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-CancelBeforeReady@@Tests/ACPRemote.wlt:2407,1-2439,2"
]

(* Runs that can't start: ssh not found, invalid settings, a script that can't be made *)
VerificationTest[
    Module[ { missing, invalid, local },
        missing = runRemote[ <| "MachineName" -> "testhost", "Executable" -> FileNameJoin @ { $scratch, "no-such-ssh" } |>, "cb_end\n" ];
        invalid = runRemote[ <| "MachineName" -> "-bad" |>, "cb_end\n" ];
        local   = runRemote[ None, "cb_end\n" ];
        {
            Lookup[ missing, { "Status", "Frames", "ExitCode", "Host" } ],
            Lookup[ missing[ "Error" ], { "Code", "Actions" } ],
            Lookup[ invalid[ "Error" ], { "Code", "Actions" } ],
            invalid[ "Status" ],
            local[ "Error", "Code" ],
            ifFakeSSH @ Module[ { before, nul, large },
                before = Length @ fakeSSHCalls[ ];
                nul    = runRemote[ remoteSSH[ ], acpRemoteListBody[ "N", "a\000b", None, False ] ];
                large  = runRemote[ remoteSSH[ ], StringRepeat[ ": x\n", 5000 ] ];
                {
                    Lookup[ nul, { "Status", "Host" } ],
                    nul[ "Error", "Code" ],
                    Lookup[ large, { "Status" } ],
                    large[ "Error", "Code" ],
                    Length @ fakeSSHCalls[ ] - before
                }
            ]
        }
    ],
    {
        { "StartFailed", <| |>, None, "testhost" },
        { "SSHNotFound", { } },
        { "InvalidSSHSettings", { } },
        "StartFailed",
        "InvalidSSHSettings",
        Missing[ "TestSkipped" ] | { { "StartFailed", "testhost" }, "RemoteScriptFailed", { "StartFailed" }, "RemoteScriptFailed", 0 }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-StartFailed@@Tests/ACPRemote.wlt:2442,1-2477,2"
]

(* ssh's failures give the connection errors' kinds, hints and texts (without CR); a host that never answers times out *)
VerificationTest[
    ifFakeSSH @ Module[ { hosts, results = <| |>, hang, ordered },
        hosts = { "fail-hostkey", "fail-changed", "fail-auth", "fail-keyperm", "fail-refused", "fail-dns", "fail-timeout", "fail-closed" };
        Scan[ With[ { h = # }, acpRemoteRun[ remoteSSH[ "x." <> h <> ".test" ], "cb_end\n", (results[ h ] = #) & ] ] &, hosts ];
        hang = runRemote[ remoteSSH[ "x.hang.test" ], "cb_end\n", <| "Timeout" -> 2 |> ];
        waitUntil[ Length @ results === Length @ hosts, 30 ];
        ordered = Lookup[ results, hosts ];
        {
            #[ "Error", "Code" ] & /@ ordered,
            DeleteDuplicates[ Lookup[ ordered, { "Status", "ExitCode" } ] ],
            AllTrue[ ordered, StringFreeQ[ ToString @ #[ "Error", "Detail" ], "\r" ] && StringFreeQ[ ToString @ #[ "Error", "Output" ], "\r" ] & ],
            StringContainsQ[ results[ "fail-keyperm", "Error", "Hint" ], acpConnectionLabel[ "ErrorSSHKeyPermissionsDetail" ] ],
            StringContainsQ[ results[ "fail-hostkey", "Error", "Hint" ], acpSSHTerminalCommand @ remoteSSH[ "x.fail-hostkey.test" ] ],
            StringEndsQ[ results[ "fail-auth", "Error", "Output" ], "Permission denied (publickey)." ],
            results[ "fail-dns", "Error", "Message" ],
            Lookup[ hang, { "Status" } ],
            hang[ "Error", "Code" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        {
            "SSHHostKeyUnknown", "SSHHostKeyChanged", "SSHAuthFailed", "SSHAuthFailed", "SSHConnectionRefused",
            "SSHHostNotFound", "SSHUnreachable", "SSHUnreachable"
        },
        { { "SSHFailed", 255 } },
        True,
        True,
        True,
        True,
        "The host x.fail-dns.test was not found.",
        { "TimedOut" },
        "SSHConnectTimeout"
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-SSHErrors@@Tests/ACPRemote.wlt:2480,1-2515,2"
]

(* A login shell that prints a banner and a decoy marker on standard output *)
VerificationTest[
    ifFakeSSH @ With[ { result = runRemote[ remoteSSH[ "x.motd.test" ], "cb_value x ok\ncb_end\n" ] },
        { result[ "Status" ], frameText[ result, "x" ], Keys @ result[ "Frames" ] }
    ],
    Missing[ "TestSkipped" ] | { "OK", "ok", { "x" } },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-Noise@@Tests/ACPRemote.wlt:2518,1-2525,2"
]

(* A login shell that prints more than 64 KB before READY: the run ends "NoReady", and no poll takes long (each poll
   searches only its new output, up to the limit). Trickled out, the noise reaches many polls; printed at once, it
   ends the run in the first one. The bounds are loose (a loaded machine); the work per poll is what they guard. *)
VerificationTest[
    ifFakeSSH @ Module[ { trickled, trickledTimes, flood, floodTimes },
        { trickled, trickledTimes } = timedPolls @ runRemote[ remoteSSH[ "testhost", "Executable" -> $tricklingSSH ], "cb_end\n" ];
        { flood, floodTimes }       = timedPolls @ runRemote[ remoteSSH[ "testhost", "Executable" -> $noisySSH ], "cb_end\n" ];
        {
            Lookup[ #, { "Status", "Frames" } ] & /@ { trickled, flood },
            #[ "Error", "Code" ] & /@ { trickled, flood },
            StringContainsQ[ #[ "Error", "Hint" ], "printed too much text" ] & /@ { trickled, flood },
            Length @ trickledTimes >= 5,
            Median @ trickledTimes < 0.05,
            Max @ trickledTimes < 0.25,
            Max @ floodTimes < 0.25,
            #[ "Duration" ] < 5 & /@ { trickled, flood }
        }
    ],
    Missing[ "TestSkipped" ] | {
        { { "NoReady", <| |> }, { "NoReady", <| |> } },
        { "RemoteScriptFailed", "RemoteScriptFailed" },
        { True, True },
        True,
        True,
        True,
        True,
        { True, True }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-NoiseBeforeReady@@Tests/ACPRemote.wlt:2530,1-2557,2"
]

(* The READY marker split across reads (gitAwaitMarker): the end of the earlier output ("ReadyTail", shorter than the
   marker) is searched with the new output, so the marker is found wherever it is cut, and the script is written once;
   a marker that begins beyond the limit is not looked for *)
VerificationTest[
    Module[ { marker, run, await, split, writes },
        marker = StringToByteArray[ "#ACPR1 " <> $remoteNonce <> " READY\n" ];
        run[ limit_ ] := <|
            "InputAfter"  -> <| "Limit" -> limit, "Marker" -> marker, "MarkerText" -> ByteArrayToString[ marker, "ISOLatin1" ], "Bytes" -> toBytes[ "script" ] |>,
            "BeforeReady" -> 0,
            "ReadyTail"   -> ByteArray[ { } ],
            "Process"     -> None
        |>;
        (* gitAwaitMarker over successive reads (each a list of chunks): the run after each, and the writes it made *)
        await[ limit_, reads_List ] := Module[ { calls = { }, r = run @ limit, states = { } },
            Block[ { Wolfram`Chatbook`ACP`Git`Private`gitNonBlocking = Function[ Null, AppendTo[ calls, HoldComplete[ # ] ], HoldAll ] },
                Scan[ (r = Wolfram`Chatbook`ACP`Git`Private`gitAwaitMarker[ r, toBytes /@ # ]; AppendTo[ states, r ]) &, reads ]
            ];
            <| "States" -> states, "Writes" -> Count[ calls, HoldComplete[ _BinaryWrite ] ], "Closes" -> Count[ calls, HoldComplete[ _Close ] ] |>
        ];
        (* the marker cut at byte k: noise and its first k bytes, then the rest and more output *)
        split[ k_ ] := With[ { result = await[ 65536, { { "login noise\n", Take[ marker, k ] }, { Drop[ marker, k ], "BEGIN" } } ] },
            {
                #[ "InputAfter" ] === None & /@ result[ "States" ],
                result[ "Writes" ],
                result[ "Closes" ],
                Length @ result[ "States" ][[ 1, "ReadyTail" ]] < Length @ marker
            }
        ];
        writes = await[ 100, { { StringRepeat[ "n", 200 ], marker } } ];
        {
            split /@ { 1, 10, Length @ marker - 1 },
            (* the marker within one read, in pieces *)
            Lookup[ await[ 65536, { { "x", Take[ marker, 5 ], Drop[ marker, 5 ] } } ], { "Writes", "Closes" } ],
            (* noise in many reads, then the marker: the tail stays short *)
            Max[ Length[ #[ "ReadyTail" ] ] & /@ Most @ await[ 65536, Append[ Table[ { StringRepeat[ "n", 1000 ] }, 20 ], { marker } ] ][ "States" ] ] < Length @ marker,
            (* beginning beyond the limit: not found, and the run is over the limit *)
            { writes[ "Writes" ], Last[ writes[ "States" ] ][ "InputAfter" ] =!= None, Last[ writes[ "States" ] ][ "BeforeReady" ] > 100 },
            (* beginning within the limit, ending beyond it: found *)
            Lookup[ await[ 100, { { StringRepeat[ "n", 90 ], marker } } ], "Writes" ]
        }
    ],
    {
        ConstantArray[ { { False, True }, 1, 1, True }, 3 ],
        { 1, 1 },
        True,
        { 0, True, True },
        1
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-AwaitMarker-Split@@Tests/ACPRemote.wlt:2562,1-2609,2"
]

(* A flood of "S" records after BEGIN (something on the remote writes to the script's output): the parse stops at the
   second record, so the pump is never blocked (the waiting loop's 50 ms ticks keep coming) *)
VerificationTest[
    ifFakeSSH @ Module[ { result = None, ticks = { }, t0 },
        acpRemoteRun[ remoteSSH[ ], "yes 'S x' | head -n 250000\ncb_end\n", (result = #) &, <| |> ];
        t0 = AbsoluteTime[ ];
        While[ ! AssociationQ @ result && AbsoluteTime[ ] - t0 < 60, Pause[ 0.05 ]; AppendTo[ ticks, AbsoluteTime[ ] ] ];
        {
            Lookup[ result, { "Status", "Stop", "Frames" } ],
            result[ "Error", "Code" ],
            Max @ Differences @ Prepend[ ticks, t0 ] < 0.2,
            result[ "Duration" ] < 5
        }
    ],
    Missing[ "TestSkipped" ] | { { "Incomplete", "x", <| |> }, "RemoteScriptFailed", True, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-StopFlood@@Tests/ACPRemote.wlt:2613,1-2628,2"
]

(* Only the end of standard error is kept (ssh's message is at the end); it still counts toward the output cap *)
VerificationTest[
    ifFakeSSH @ Module[ { raw = None, result },
        acpProcessRun[
            { "/bin/sh", "-c", "head -c 3145728 /dev/zero | tr '\\000' e >&2; printf END >&2; printf out" },
            $scratch,
            (raw = #) &,
            <| "ErrorKeep" -> 2^20, "Decode" -> False, "MaxOutput" -> 2^23 |>
        ];
        waitUntil[ AssociationQ @ raw, 30 ];
        result = runRemote[
            remoteSSH[ ],
            "cb_value a 1\nhead -c 3145728 /dev/zero | tr '\\000' e >&2\nprintf '\\nlast line\\n' >&2\nexit 255\n"
        ];
        {
            Lookup[ raw, { "ExitCode", "ErrorTruncated", "NoReady", "TooLarge" } ],
            Length @ raw[ "Error" ],
            ByteArrayToString @ Take[ raw[ "Error" ], -3 ],
            ByteArrayToString @ raw[ "Output" ],
            Lookup[ result, { "Status", "ExitCode" } ],
            Lookup[ result[ "Error" ], { "Code", "Output" } ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        { 0, True, False, False },
        1048576,
        "END",
        "out",
        { "Incomplete", 255 },
        { "SSHConnectionLost", "last line" }
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-ErrorKeep@@Tests/ACPRemote.wlt:2631,1-2663,2"
]

(* After an authentication failure the host is latched: automatic runs make no connection ("Latched", with the cached
   error), a run started by the user clears the latch and connects *)
VerificationTest[
    ifFakeSSH @ Module[ { ssh, key, first, latched, n1, automatic, n2, user, n3, other },
        ssh = remoteSSH[ "x.fail-auth.test" ];
        key = acpSSHHostKey @ ssh;
        acpRemoteClearHostError @ key;
        first     = runRemote[ ssh, "cb_end\n" ];
        latched   = acpRemoteHostLatchedQ @ key;
        n1        = Length @ fakeSSHCalls[ ];
        automatic = runRemote[ ssh, "cb_end\n", <| "Automatic" -> True |> ];
        n2        = Length @ fakeSSHCalls[ ];
        user      = runRemote[ ssh, "cb_end\n" ];
        n3        = Length @ fakeSSHCalls[ ];
        other     = runRemote[ remoteSSH[ ], "cb_end\n", <| "Automatic" -> True |> ];
        acpRemoteNoteHostError[ key, None ];
        {
            first[ "Error", "Code" ],
            latched,
            Lookup[ automatic, { "Status", "Frames", "ExitCode" } ],
            Lookup[ automatic[ "Error" ], { "Code", "Actions" } ],
            n2 - n1,
            user[ "Error", "Code" ],
            n3 - n2,
            other[ "Status" ],
            acpRemoteHostLatchedQ @ key,
            acpRemoteHostLatchedQ[ "?" ],
            acpRemoteClearHostError @ None
        }
    ],
    Missing[ "TestSkipped" ] | {
        "SSHAuthFailed",
        True,
        { "Latched", <| |>, None },
        { "SSHAuthFailed", { } },
        0,
        "SSHAuthFailed",
        1,
        "OK",
        False,
        False,
        Null
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-Latch@@Tests/ACPRemote.wlt:2667,1-2710,2"
]

(* Within $acpRemoteLatchMemory of an authentication failure, a host that can't be reached may be enforcing sshd's
   PerSourcePenalties: the error says so *)
VerificationTest[
    ifFakeSSH @ Module[ { ssh, key, recent, old },
        ssh = remoteSSH[ "x.fail-closed.test" ];
        key = acpSSHHostKey @ ssh;
        $acpRemoteHostAuthFailedAt[ key ] = AbsoluteTime[ ];
        recent = runRemote[ ssh, "cb_end\n" ];
        $acpRemoteHostAuthFailedAt[ key ] = AbsoluteTime[ ] - $acpRemoteLatchMemory - 100;
        old = runRemote[ ssh, "cb_end\n" ];
        KeyDropFrom[ $acpRemoteHostAuthFailedAt, key ];
        {
            recent[ "Error", "Code" ],
            StringContainsQ[ recent[ "Error", "Hint" ], acpConnectionLabel[ "ErrorSSHPenaltyDetail" ] ],
            old[ "Error", "Code" ],
            StringContainsQ[ Replace[ old[ "Error", "Hint" ], None -> "" ], acpConnectionLabel[ "ErrorSSHPenaltyDetail" ] ]
        }
    ],
    Missing[ "TestSkipped" ] | { "SSHUnreachable", True, "SSHUnreachable", False },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-PenaltyHint@@Tests/ACPRemote.wlt:2714,1-2733,2"
]

(* At most $acpRemoteMaxRuns runs at once per host; the others wait for a slot (through the pump), and every
   continuation runs exactly once *)
VerificationTest[
    ifFakeSSH @ Module[ { calls, results, body, maxRuns = 0 },
        calls   = ConstantArray[ 0, 6 ];
        results = ConstantArray[ None, 6 ];
        body    = "cb_run n 100 100 /bin/sh -c 'mkdir -p \"$HOME/cap\" && mkdir \"$HOME/cap/$$\" && ls \"$HOME/cap\" | wc -l; sleep 1; rmdir \"$HOME/cap/$$\"'\ncb_end\n";
        Do[ With[ { i = i }, acpRemoteRun[ remoteSSH[ ], body, (calls[[ i ]]++; results[[ i ]] = #) & ] ], { i, 6 } ];
        waitUntil[ maxRuns = Max[ maxRuns, Length @ processRuns[ ] ]; Total @ calls >= 6, 30 ];
        Pause[ 0.5 ];
        {
            calls,
            #[ "Status" ] & /@ results,
            Max[ FromDigits @ StringTrim @ frameText[ #, "n" ] & /@ results ] <= 3,
            maxRuns
        }
    ],
    Missing[ "TestSkipped" ] | { { 1, 1, 1, 1, 1, 1 }, { "OK", "OK", "OK", "OK", "OK", "OK" }, True, 3 },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-Cap@@Tests/ACPRemote.wlt:2737,1-2755,2"
]

(* Finished runs release their processes (each one would otherwise leak file descriptors) *)
VerificationTest[
    ifFakeSSH @ If[ ! $procfsQ,
        True,
        Module[ { before },
            runRemote[ remoteSSH[ ], "cb_end\n" ];
            before = fileDescriptors[ ];
            Do[ runRemote[ remoteSSH[ ], "cb_value x 1\ncb_end\n" ], { 20 } ];
            fileDescriptors[ ] - before < 10
        ]
    ],
    Missing[ "TestSkipped" ] | True,
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-NoDescriptorLeak@@Tests/ACPRemote.wlt:2758,1-2771,2"
]

(* The prelude removes its temporary folder (in TMPDIR) after a complete run, an early stop and the watchdog *)
VerificationTest[
    ifFakeSSH @ Module[ { tmp, ok, stop, watchdog },
        waitUntil[ processRuns[ ] === <| |>, 30 ];
        tmp = CreateDirectory @ FileNameJoin @ { $scratch, "tmp-cleanup" };
        withFakeSSHEnvironment[ <| "TMPDIR" -> tmp |>,
            ok       = runRemote[ remoteSSH[ ], "cb_value d \"$cb_d\"\ncb_end\n" ];
            stop     = runRemote[ remoteSSH[ ], "cb_stop early\n" ];
            watchdog = Block[ { $acpRemoteDeadlineSlack = -28 },
                runRemote[ remoteSSH[ ], "cb_run s 10 10 sleep 33.75\ncb_end\n", <| "Timeout" -> 30 |> ]
            ]
        ];
        {
            StringStartsQ[ frameText[ ok, "d" ], FileNameJoin @ { tmp, "chatbook." } ],
            Lookup[ { ok, stop, watchdog }, "Status" ],
            stop[ "Stop" ],
            FileNames[ "*", tmp ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, { "OK", "OK", "RemoteTimedOut" }, "early", { } },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-TempCleanup@@Tests/ACPRemote.wlt:2774,1-2795,2"
]

(* The prelude keeps only absolute PATH entries: an empty or relative entry would run a program of the folder the
   script works in (here the home folder, with a trojan "uname") *)
VerificationTest[
    ifFakeSSH @ Module[ { home, trojan, marker, control, controlRan, results },
        home   = $fakeSSH[ "Home" ];
        trojan = FileNameJoin @ { home, "uname" };
        marker = FileNameJoin @ { home, "trojan-ran" };
        writeText[ trojan, "#!/bin/sh\n: > \"$HOME/trojan-ran\"\necho TROJAN\n" ];
        RunProcess[ { "chmod", "755", trojan } ];
        control    = runShell[ { "/bin/sh" }, { "-c", "PATH=:/usr/bin:/bin; uname" }, "", home, <| "HOME" -> home |> ];
        controlRan = FileExistsQ @ marker;
        Quiet @ DeleteFile @ marker;
        results = withFakeSSHEnvironment[ <| "FAKE_SSH_PATH" -> # |>,
            runRemote[ remoteSSH[ ], "cb_run u 1000 1000 uname\ncb_value path \"$PATH\"\ncb_end\n" ]
        ] & /@ { ":/usr/bin:/bin", ".:/usr/bin:/bin", "/usr/bin::/bin" };
        DeleteFile @ trojan;
        {
            ByteArrayToString @ control[ "Output" ],
            controlRan,
            #[ "Status" ] & /@ results,
            frameText[ #, "u" ] & /@ results,
            frameText[ #, "path" ] & /@ results,
            FileExistsQ @ marker
        }
    ],
    Missing[ "TestSkipped" ] | {
        "TROJAN\n",
        True,
        { "OK", "OK", "OK" },
        { Except[ "TROJAN\n", _String ].. },
        { "/usr/bin:/bin", "/usr/bin:/bin", "/usr/bin:/bin" },
        False
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-PathFilter@@Tests/ACPRemote.wlt:2799,1-2832,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Folder listing*)
VerificationTest[
    Module[ { parse, ok, unusable, fallback, capped, caps, odd },
        parse = acpRemoteListingParse[ listingFixture @ #, "N" ] &;
        ok    = parse[ "ok" ];
        unusable = Select[ ok[ "Entries" ], ! #[ "Usable" ] & ];
        fallback = parse[ "fallback" ];
        capped   = parse[ "capped" ];
        caps = acpRemoteListingParse[
            StringToByteArray @ StringJoin[
                "v:1:N\000h:/h\000q:/x\000s:ok\000p:/x\000r:/x\000",
                Table[ "d:f" <> ToString @ i <> "\000", { i, 1500 } ],
                Table[ "d:.h" <> ToString @ i <> "\000", { i, 1100 } ],
                Table[ "f:x" <> ToString @ i <> "\000", { i, 300 } ],
                "c:1500 1100 300 0\000e:\000"
            ],
            "N"
        ];
        odd = acpRemoteListingParse[
            StringToByteArray[ "v:1:N\000h:/h\000q:/x\000s:ok\000p:/x\000r:/x\000d:a/b\000d:.\000d:..\000d:ok\000c:2 2 0 x\000xd:1e3\000e:\000" ],
            "N"
        ];
        {
            Lookup[ ok, { "Status", "RequestedStatus", "Fallback", "Warning", "Home", "Requested", "Path", "RealPath", "Complete" } ],
            ok[ "Counts" ],
            ok[ "Capped" ],
            Length @ ok[ "Entries" ],
            Counts @ Lookup[ ok[ "Entries" ], "Kind" ],
            AllTrue[ { "new\nline", "trail\n", "CR\rname", "  lead and trail  ", "a;b&c|d", "\:f7c1linear", "emoji \|01f680", "\:00fcn\:00efc\:00f6d\:00e9 \:2603" }, entryNamed[ ok, # ] =!= None & ],
            Lookup[ unusable, { "Name", "Kind", "Usable" } ],
            Lookup[ entryNamed[ ok, "link-to-dir" ], { "Kind", "Link", "Locked", "Hidden" } ],
            Lookup[ entryNamed[ ok, "link-to-locked" ], { "Kind", "Link", "Locked" } ],
            Lookup[ entryNamed[ ok, "broken-link" ], { "Kind", "Link" } ],
            Lookup[ entryNamed[ ok, "link-to-file" ], { "Kind", "Link" } ],
            Lookup[ entryNamed[ ok, "fifo" ], { "Kind", "Link" } ],
            Lookup[ entryNamed[ ok, ".hidden" ], { "Kind", "Hidden" } ],
            Lookup[ parse[ # ], { "Status", "RequestedStatus", "Path", "Entries" } ] & /@ { "missing", "notdir", "access" },
            Lookup[ parse[ "unreadable" ], { "Status", "Path", "Entries" } ],
            Lookup[ fallback, { "Status", "RequestedStatus", "Requested", "Fallback", "Path" } ],
            Length @ fallback[ "Entries" ],
            Lookup[ capped, { "Status", "Capped", "Counts" } ],
            Length @ capped[ "Entries" ],
            Lookup[ parse[ "unlisted" ], { "Status", "Warning", "Entries" } ],
            Lookup[ parse[ "empty" ], { "Status", "Warning", "Entries", "Counts" } ],
            Lookup[ parse[ "malformed" ], { "Status", "Complete", "Path" } ],
            acpRemoteListingParse[ listingFixture[ "ok" ], "OTHER" ][ "Status" ],
            parse[ "noise" ] === ok,
            Counts[ { #[ "Kind" ], #[ "Hidden" ] } & /@ caps[ "Entries" ] ],
            Lookup[ odd[ "Entries" ], { "Name", "Usable" } ],
            Lookup[ odd, { "Status", "Counts", "Capped" } ],
            acpRemoteListingParse[ StringToByteArray @ StringJoin[ "v:1:N\000", Table[ "f:x\000", 7000 ], "e:\000" ], "N" ][ "Status" ],
            acpRemoteListingParse[ ByteArray[ { } ], "N" ][ "Status" ]
        }
    ],
    {
        { "OK", "OK", None, None, "/home/u", "/home/u/proj", "/home/u/proj", "/home/u/proj", True },
        <| "Folders" -> 31, "HiddenFolders" -> 3, "Files" -> 9, "HiddenFiles" -> 2 |>,
        <| "Folders" -> None, "Files" -> None |>,
        45,
        <| "Folder" -> 34, "File" -> 7, "BrokenLink" -> 2, "Other" -> 2 |>,
        True,
        { { "bad\:00ff\:00feutf8", "Folder", False } },
        { "Folder", True, False, False },
        { "Folder", True, True },
        { "BrokenLink", True },
        { "File", True },
        { "Other", False },
        { "Folder", True },
        {
            { "Missing", "Missing", None, { } },
            { "NotFolder", "NotFolder", None, { } },
            { "NoAccess", "NoAccess", None, { } }
        },
        { "Unreadable", "/home/u/proj/xonly", { } },
        { "OK", "Missing", "/home/u/proj/gone/deeper", "/home/u/proj", "/home/u/proj" },
        45,
        { "OK", <| "Folders" -> 100, "Files" -> 50 |>, <| "Folders" -> 100, "HiddenFolders" -> 0, "Files" -> 50, "HiddenFiles" -> 0 |> },
        15,
        { "OK", "Unlisted", { } },
        { "OK", None, { }, <| "Folders" -> 0, "HiddenFolders" -> 0, "Files" -> 0, "HiddenFiles" -> 0 |> },
        { "Malformed", False, None },
        "Malformed",
        True,
        <| { "Folder", False } -> 1000, { "Folder", True } -> 1000, { "File", False } -> 200 |>,
        { { "a/b", False }, { ".", False }, { "..", False }, { "ok", True } },
        { "OK", None, <| "Folders" -> None, "Files" -> None |> },
        "Malformed",
        "Malformed"
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-ListingParse@@Tests/ACPRemote.wlt:2837,1-2927,2"
]

(* The listing script under every available shell, as the remote runs it (the prelude and the body on standard input
   of sh -s): the same listing in every shell, and every usable folder opens by its child path with the exact path *)
VerificationTest[
    ifFakeSSH @ Module[ { root, proj, tmp, names, list, listings, base, reopened, result },
        root = CreateDirectory @ FileNameJoin @ { $scratch, "listing" };
        proj = CreateDirectory @ FileNameJoin @ { root, "proj" };
        tmp  = CreateDirectory @ FileNameJoin @ { root, "tmp" };
        names = {
            "with space", "it's", "new\nline", "tab\there", "trail\n", "CR\rname", "$dollar", "`tick`", "a;b&c|d",
            "back\\slash", "dq\"uote", "~tilde", "-dash", "*star", "?q", "[bracket]", "x:colon", "Alpha2", "alpha",
            "  lead and trail  ", "emoji \|01f680", "\:00fcn\:00efc\:00f6d\:00e9", "\:f7c1linear", ".hidden", "...",
            "..dotdot", "Zeta"
        };
        RunProcess[
            Join[
                {
                    "/bin/sh", "-c",
                    "cd \"$1\" && shift && for n in \"$@\"; do mkdir -- \"$n\"; done && " <>
                    "mkdir \"$(printf 'bad\\377\\376utf8')\" && ln -s Zeta link-to-dir && ln -s nowhere broken-link && " <>
                    ": > README.md && : > .env && ln -s README.md link-to-file",
                    "sh",
                    proj
                },
                names
            ]
        ];
        list[ shell_List, path_String, base_ ] := Module[ { lnonce = "L" <> StringDelete[ CreateUUID[ ], "-" ], script, run, parsed },
            script = ByteArrayToString[ acpRemoteScript[ $remoteNonce, 30, acpRemoteListBody[ lnonce, path, base, False ] ][ "Script" ], "UTF-8" ];
            run    = runShell[ shell, { "-s" }, script, root, <| "HOME" -> root, "TMPDIR" -> tmp |> ];
            parsed = acpRemoteParseFrames[ run[ "Output" ], $remoteNonce ];
            If[ TrueQ @ parsed[ "Complete" ], acpRemoteListingParse[ parsed[ "Frames", "list", "Output" ], lnonce ], parsed ]
        ];
        listings = list[ #, "proj", root ] & /@ $shells;
        base     = First @ listings;
        reopened = Map[
            With[ { child = acpRemoteChild[ base[ "Path" ], #[ "Name" ] ] }, Lookup[ list[ { "/bin/sh" }, child, None ], { "Status", "Path" } ] === { "OK", child } ] &,
            Select[ base[ "Entries" ], #[ "Kind" ] === "Folder" && #[ "Usable" ] && ! #[ "Locked" ] & ]
        ];
        result = {
            Lookup[ base, { "Status", "Path", "Home" } ] === { "OK", proj, root },
            Length @ base[ "Entries" ],
            Sort @ Lookup[ Select[ base[ "Entries" ], #[ "Kind" ] === "Folder" && #[ "Usable" ] & ], "Name" ] === Sort @ Append[ names, "link-to-dir" ],
            Lookup[ Select[ base[ "Entries" ], ! #[ "Usable" ] & ], "Name" ],
            AllTrue[ listings, # === base & ],
            Length @ reopened,
            And @@ reopened,
            Lookup[ list[ { "/bin/sh" }, "~/proj", None ], { "Status", "Path" } ] === { "OK", proj },
            Lookup[ list[ { "/bin/sh" }, "~/proj/no-such/deeper", None ], { "Status", "Path" } ]
        };
        (* DeleteDirectory can't remove the folder whose name is not UTF-8 *)
        RunProcess[ { "rm", "-rf", root } ];
        result
    ],
    Missing[ "TestSkipped" ] | { True, 33, True, { "bad\:00ff\:00feutf8" }, True, 28, True, True, { "Missing", None } },
    SameTest -> MatchQ,
    TestID   -> "Remote-ListingShells@@Tests/ACPRemote.wlt:2931,1-2985,2"
]

(* A listing's home folder is kept only if it is an absolute path without control characters, of at most 4096
   characters; a rejected one is logged with the key only. (The parser persists nothing: that a rejected home is never
   persisted is tested through the picker, in ACPFolderPicker.wlt.) *)
VerificationTest[
    Module[ { t0 = AbsoluteTime[ ], listing, parsed, log },
        listing[ home_String ] := StringToByteArray[ "v:1:N\000h:" <> home <> "\000q:/x\000s:ok\000p:/x\000r:/x\000c:0 0 0 0\000e:\000", "UTF-8" ];
        parsed = acpRemoteListingParse[ listing @ #, "N" ] & /@ { "/home/evil\nx", StringRepeat[ "/x", 5120 ], "relative", "/home/ok" };
        log    = Select[ logSince @ t0, #[ "Where" ] === "RemoteValueRejected" & ];
        {
            Lookup[ parsed, "Home" ],
            Lookup[ parsed, "Status" ],
            Lookup[ log, "Data" ],
            FreeQ[ logSince @ t0, s_String /; StringContainsQ[ s, "evil" | "relative" | "/x/x/x" ] ]
        }
    ],
    {
        { None, None, None, "/home/ok" },
        { "OK", "OK", "OK", "OK" },
        { <| "Key" -> "Home" |>, <| "Key" -> "Home" |>, <| "Key" -> "Home" |> },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-RemoteValues-Listing@@Tests/ACPRemote.wlt:2990,1-3010,2"
]

(* No run, slot or poll is left; the remote processes the tests started are gone (the watchdog of the timed-out run
   ends its sleep) *)
VerificationTest[
    Scan[
        With[ { key = acpSSHHostKey @ sshSettings @ <| "MachineName" -> # |> },
            acpRemoteClearHostError @ key;
            KeyDropFrom[ $acpRemoteHostAuthFailedAt, key ]
        ] &,
        { "testhost", "x.fail-hostkey.test", "x.fail-changed.test", "x.fail-auth.test", "x.fail-keyperm.test" }
    ];
    {
        waitUntil[ processRuns[ ] === <| |>, 30 ],
        Wolfram`Chatbook`ACP`Remote`Private`remoteReleaseSlots[ ];
        Wolfram`Chatbook`ACP`Remote`Private`$remoteRuns,
        Select[ Tasks[ ], StringContainsQ[ ToString[ #[ "EvaluationExpression" ], InputForm ], "gitPoll" | "remoteStart" ] & ],
        ! $procfsQ || waitUntil[ processesWith /@ { "sleep 31.25", "sleep 32.5", "sleep 33.75" } === { { }, { }, { } }, 20 ],
        $acpRemoteHostErrors
    },
    { True, <| |>, { }, True, <| |> },
    SameTest -> MatchQ,
    TestID   -> "Remote-Run-NoLeftoverRuns@@Tests/ACPRemote.wlt:3014,1-3033,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)

(* Nothing unexpected may have been logged as a message or failure *)
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
    TestID   -> "Cleanup-DebugLog@@Tests/ACPRemote.wlt:3040,1-3051,2"
]

VerificationTest[
    fakeSSHCleanup[ ];
    Quiet @ DeleteDirectory[ $scratch, DeleteContents -> True ];
    {
        DirectoryQ @ $scratch,
        $fakeSSH,
        ! $fakeSSHAvailableQ || Environment[ "FAKE_SSH_HOME" ] === $Failed
    },
    { False, None, True },
    SameTest -> MatchQ,
    TestID   -> "Cleanup-Restore@@Tests/ACPRemote.wlt:3053,1-3064,2"
]

(* :!CodeAnalysis::EndBlock:: *)
