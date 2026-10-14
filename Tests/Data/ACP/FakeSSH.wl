(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`ChatbookTests`ACPFakeSSH`" ];

(* Test helpers for remote windows (SSHSettings) without a real ssh or sshd: the fake ssh (Data/ACP/fake-ssh, a POSIX
   shell script that parses ssh's command line, logs it and runs the remote command locally like sshd would, in a fake
   home folder with a clean environment). Loaded with Get by the initialization test of each test file that needs it.
   Unix only: on Windows (or without /bin/sh) every test wrapped in ifFakeSSH is skipped. *)

`$fakeSSH;
`$fakeSSHAvailableQ;
`$permissionsEnforcedQ;
`fakeSSHCalls;
`fakeSSHCleanup;
`fakeSSHSettings;
`fakeSSHSetup;
`ifFakeSSH;
`ifPermissionsEnforced;
`readFileBytes;
`withFakeSSHEnvironment;

Begin[ "`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$fakeSSHSource = FileNameJoin @ { DirectoryName @ $InputFileName, "fake-ssh" };

(* The variables fakeSSHSetup sets, and their values before (restored by fakeSSHCleanup) *)
$fakeSSHVariables = { "FAKE_SSH_HOME", "FAKE_SSH_LOG", "FAKE_SSH_KEEP_ENV", "TMPDIR" };
$savedEnvironment = <| |>;

If[ ! AssociationQ @ $fakeSSH, $fakeSSH = None ];
If[ ! BooleanQ @ $permissionsEnforcedQ, $permissionsEnforcedQ = False ];

$fakeSSHAvailableQ := $OperatingSystem =!= "Windows" && FileExistsQ[ "/bin/sh" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Setup*)

(* Copies the fake ssh to scratch/bin (made executable with RunProcess: only during test initialization, before any ACP
   connection), creates scratch/home (the "remote" home) and scratch/tmp (TMPDIR of the "remote" scripts), and sets
   FAKE_SSH_HOME, FAKE_SSH_LOG, TMPDIR and FAKE_SSH_KEEP_ENV with SetEnvironment, so that every ssh process started by
   the kernel uses them. Gives <| "Executable", "Home", "Log", "Tmp", "Scratch" |>, also kept in $fakeSSH. *)
fakeSSHSetup[ scratch_String ] := Module[ { bin, home, tmp, exe, log },
    bin  = ensureDirectory @ FileNameJoin @ { scratch, "bin" };
    home = ensureDirectory @ FileNameJoin @ { scratch, "home" };
    tmp  = ensureDirectory @ FileNameJoin @ { scratch, "tmp" };
    exe  = FileNameJoin @ { bin, "fake-ssh" };
    log  = FileNameJoin @ { scratch, "fake-ssh.log" };
    If[ FileExistsQ @ exe, DeleteFile @ exe ];
    CopyFile[ $fakeSSHSource, exe ];
    RunProcess[ { "chmod", "755", exe } ];
    If[ ! FileExistsQ @ log, CreateFile @ log ];
    $permissionsEnforcedQ = permissionsEnforcedQ @ scratch;
    $savedEnvironment = AssociationMap[ Environment, $fakeSSHVariables ];
    SetEnvironment @ {
        "FAKE_SSH_HOME"     -> home,
        "FAKE_SSH_LOG"      -> log,
        "FAKE_SSH_KEEP_ENV" -> "TMPDIR",
        "TMPDIR"            -> tmp
    };
    $fakeSSH = <| "Executable" -> exe, "Home" -> home, "Log" -> log, "Tmp" -> tmp, "Scratch" -> scratch |>
];


ensureDirectory[ dir_String ] := If[ DirectoryQ @ dir, dir, CreateDirectory[ dir, CreateIntermediateDirectories -> True ] ];


(* Whether permission bits are enforced: entering a folder of mode 000 must fail. It doesn't for root (CI runs the
   tests as root), whose CAP_DAC_OVERRIDE enters and reads mode-000 folders and files. *)
permissionsEnforcedQ[ scratch_String ] := Module[ { dir, result },
    dir = FileNameJoin @ { scratch, "permission-probe" };
    result = RunProcess[ { "/bin/sh", "-c", "mkdir permission-probe && chmod 000 permission-probe && cd permission-probe" }, ProcessDirectory -> scratch ];
    RunProcess[ { "chmod", "755", dir } ];
    Quiet @ DeleteDirectory[ dir, DeleteContents -> True ];
    AssociationQ @ result && result[ "ExitCode" ] =!= 0
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Settings and calls*)

(* "SSHSettings" for a host of the fake ssh (testhost runs commands; see fake-ssh for the failing hosts) *)
fakeSSHSettings[ host_String: "testhost", extra___Rule ] := <|
    "MachineName" -> host,
    "Executable"  -> $fakeSSH[ "Executable" ],
    extra
|>;


(* The calls of the fake ssh since setup, as { { arg1, arg2, ... }, ... } (the log holds each call's argument count and
   arguments, NUL-terminated; arguments may be empty) *)
fakeSSHCalls[ ] := Module[ { bytes, fields, calls = { }, n },
    bytes = readFileBytes @ $fakeSSH[ "Log" ];
    If[ Length @ bytes === 0, Return[ { }, Module ] ];
    fields = Most @ StringSplit[ ByteArrayToString[ bytes, "UTF-8" ], "\000", All ];
    While[ fields =!= { },
        n = FromDigits @ First @ fields;
        AppendTo[ calls, Take[ Rest @ fields, UpTo[ n ] ] ];
        fields = Drop[ fields, Min[ n + 1, Length @ fields ] ]
    ];
    calls
];


(* The bytes of a file, through a stream of its own: ReadByteArray[file] reads from a stream that is already open for
   the file if there is one (a second read of the same file can then give nothing, and a ProcessLink stream file waits
   for its process to end) *)
readFileBytes[ file_String ] := Module[ { stream, bytes },
    stream = Quiet @ OpenRead[ file, BinaryFormat -> True ];
    If[ Head @ stream =!= InputStream, Return[ ByteArray[ { } ], Module ] ];
    bytes = ReadByteArray @ stream;
    Close @ stream;
    If[ ByteArrayQ @ bytes, bytes, ByteArray[ { } ] ]
];


(* Evaluates eval with environment variables set (None removes one), then restores them *)
withFakeSSHEnvironment // Attributes = { HoldRest };

withFakeSSHEnvironment[ vars_Association, eval_ ] := Module[ { saved },
    saved = AssociationMap[ Environment, Keys @ vars ];
    WithCleanup[
        SetEnvironment @ Normal @ vars,
        eval,
        SetEnvironment @ KeyValueMap[ #1 -> Replace[ #2, Except[ _String ] -> None ] &, saved ]
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Gates*)
ifFakeSSH // Attributes = { HoldAll };
ifFakeSSH[ eval_ ] := If[ TrueQ @ $fakeSSHAvailableQ, eval, Missing[ "TestSkipped" ] ];

ifPermissionsEnforced // Attributes = { HoldAll };
ifPermissionsEnforced[ eval_ ] := If[ TrueQ @ $permissionsEnforcedQ, eval, Missing[ "TestSkipped" ] ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)

(* Restores the environment variables of fakeSSHSetup and deletes what it created (no RunProcess here: ACP readers may
   still be active; tests that change permission bits restore them themselves) *)
fakeSSHCleanup[ ] := (
    If[ $savedEnvironment =!= <| |>,
        SetEnvironment @ KeyValueMap[ #1 -> Replace[ #2, Except[ _String ] -> None ] &, $savedEnvironment ];
        $savedEnvironment = <| |>
    ];
    If[ AssociationQ @ $fakeSSH,
        Quiet @ DeleteDirectory[ #, DeleteContents -> True ] & /@ Lookup[ $fakeSSH, { "Home", "Tmp" } ];
        Quiet @ DeleteDirectory[ DirectoryName @ $fakeSSH[ "Executable" ], DeleteContents -> True ];
        Quiet @ DeleteFile @ $fakeSSH[ "Log" ];
        $fakeSSH = None
    ];
    Null
);

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
