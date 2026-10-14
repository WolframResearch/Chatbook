(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`Git`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ACP`Common`" ];

(* The git backend of "Review changes" (see docs/acp-window.md, "Reviewing changes"): finding git, running it
   asynchronously, parsing its output, change sets (status, line counts, per-file patches and untracked files) and the
   git summary of ACP windows (the window record's "Git" key), which triggers and housekeeping keep up to date.

   Rules:
   * Git never blocks the kernel: no RunProcess (it can hang while an ACP reader is active). Commands are started with
     StartProcess and polled from the pump (acpSchedule); output is drained with non-blocking reads.
   * Nothing writes to the repository: every command is read-only and runs with --no-optional-locks (status does not
     refresh .git/index or take index.lock) and diff.autoRefreshIndex=false (git diff writes the refreshed index even
     with --no-optional-locks).
   * Repository config cannot make git run programs: fsmonitor, external diff drivers and textconv are off, every
     configured filter driver is neutralized (its commands are emptied and it is not required; a driver whose name
     contains "=" can't be, so the request fails instead), all transports are off (a partial clone can't fetch objects
     with programs from its config), the pager is off and dirty submodules are not inspected (no git processes inside
     submodules).
   * Reader handlers only mark the summary stale (acpGitMarkStale, acpGitNoteSessionUpdate). Requests are started by
     the pump (acpGitCheck and acpGitChanges only schedule them).
   * Bounded work: a timeout and an output cap per command, bounded reads in each poll, at most $acpGitMaxFiles files
     per change set, a size cap and a read budget for untracked files, linear-time parsers. A newer request from the
     same requester supersedes a running one (its process is killed).
   * Remote windows ("SSHSettings"): a request runs one script (Assets/RemoteScripts/git.sh) on the remote machine over
     one ssh connection (acpRemoteRun, Remote.wl), which runs the same git commands and reads the untracked files there.
     The steps below then replay its frames instead of running git (see "Remote"), so remote and local change sets are
     the same. Nothing local is ever checked for a remote folder (no DirectoryQ, ExpandFileName or FileNameJoin). *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$acpGitMaxFiles          = 500;        (* files listed in a change set (the rest are only counted) *)
$gitPollInterval         = Quantity[ 50, "Milliseconds" ];
$gitTimeout              = 20;         (* seconds per command of a full change set *)
$gitSummaryTimeout       = 10;         (* seconds per command of a summary check *)
$gitMaxOutput            = 16 * 2^20;  (* bytes of output (standard output and error) per command *)
$gitReadPerPoll          = 4 * 2^20;   (* bytes read from each stream of a command per poll *)
$gitSplitSlice           = 2000;       (* patch chunks parsed per pump tick *)
$gitMaxUntrackedFileSize = 2^20;       (* untracked files larger than this are not read *)
$gitBinaryCheckBytes     = 8000;       (* a NUL byte in the first 8000 bytes means binary, as in git *)
$gitMinimumVersion       = { 2, 25 };  (* rev-parse --show-object-format *)
$gitNoLazyFetchVersion   = { 2, 45 };  (* git --no-lazy-fetch (partial clones must not fetch objects) *)
$gitMinCheckInterval     = 2;          (* seconds between checks triggered by tool calls and turn ends *)
$gitIdleCheckInterval    = 15;         (* seconds between periodic checks of an idle window... *)
$gitIdleCheckFactor      = 30;         (* ...or this many times the duration of the last check, if that is longer *)
$gitRequestTimeout       = 150;        (* seconds after which a check that never finished is considered lost *)
$gitNotFoundRecheck      = 60;         (* seconds before looking for git again after it was not found *)
$gitErrorDetailLines     = 12;         (* lines (and characters, below) of git's standard error kept in errors *)
$gitErrorDetailLength    = 1500;
$gitHousekeepingTicks    = 2;          (* publication ticks (0.2 s each) between housekeeping runs *)

(* Remote windows ("SSHSettings"): each request is one script run over its own ssh connection (acpRemoteRun), so the
   timeouts are per request, and checks are less frequent (each one is a new sign-in on the remote machine) *)
$gitRemoteSummaryTimeout    = 30;      (* seconds per summary check *)
$gitRemoteTimeout           = 90;      (* seconds per full change set *)
$gitRemoteMinCheckInterval  = 5;       (* as $gitMinCheckInterval *)
$gitRemoteIdleCheckInterval = 60;      (* as $gitIdleCheckInterval *)

(* Test hooks of the remote git script: the folders searched for git after the remote PATH (Automatic: the script's own
   list, /usr/bin /usr/local/bin /opt/homebrew/bin), and whether the script may count lines with a NUL-safe awk (False:
   the portable path, one od per file) *)
$gitRemoteSystemDirectories = Automatic;
$gitRemoteNULSafe           = True;

(* Bytes of untracked files read per request (the same for summary checks and full change sets, so that both count the
   same lines): *)
$gitUntrackedBudget = 16 * 2^20;

(* The field terminator of -z output *)
$gitNUL = FromCharacterCode[ 0 ];

(* Empty tree of each object format: the base of the diffs in a repository without commits *)
$gitEmptyTrees = <|
    "sha1"   -> "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
    "sha256" -> "6ef19b41225c5369f1c104d45d8d85efa9b057b53b14b4b9b939dd74decc5321"
|>;

(* Configuration passed with -c to every command (after the version check). Read-only and predictable output:
   no fsmonitor (it can run a hook or start a daemon), no transports (git before 2.45 has no --no-lazy-fetch: a partial
   clone would fetch missing objects, running the upload-pack, ssh command or credential helper of the repository's
   config, and write them to .git/objects), unquoted non-ASCII paths, git diff must not write the index,
   repository-root-relative diff paths, " " for empty context lines. *)
$gitSafeConfig = {
    "core.fsmonitor=false",
    "core.useBuiltinFSMonitor=false",
    "protocol.allow=never",
    "core.quotepath=off",
    "diff.autoRefreshIndex=false",
    "diff.relative=false",
    "diff.suppressBlankEmpty=false"
};

(* Untracked files are listed one by one (--untracked-files=all); dirty submodules are not inspected. *)
$gitStatusArguments = {
    "status", "--porcelain=v2", "-z", "--branch", "--no-ahead-behind", "--untracked-files=all", "--renames",
    "--ignore-submodules=dirty", "--", "."
};

$gitDiffOptions = { "-M", "--no-ext-diff", "--no-textconv", "--no-color", "--ignore-submodules=dirty" };

$gitPatchOptions = { "-U3", "--src-prefix=a/", "--dst-prefix=b/", "--submodule=short" };

(* Tools that change files (canonical names and ACP tool kinds). Completed tools of other kinds that are not known to
   be read-only (e.g. MCP tools, kind "other") count as changing files too. *)
$gitChangingToolNames  = { "edit", "write", "patch", "multiedit", "shell", "subagent" };
$gitChangingToolKinds  = { "edit", "delete", "move", "execute" };
$gitReadOnlyToolNames  = { "read", "glob", "grep", "list", "ls", "webfetch", "websearch", "codesearch", "todoread", "todowrite", "skill", "lsp" };
$gitReadOnlyToolKinds  = { "read", "search", "think", "fetch", "switch_mode" };

(* Set to False to disable git: no checks, no processes, change sets are "Unavailable". *)
If[ ! BooleanQ @ $acpGitEnabled, $acpGitEnabled = True ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Stores*)

(* Running commands (run ID -> run), the acpFindGit[] cache, git versions (by executable), repository information
   (by project directory) and the token of the latest request of each requester (see gitSupersededQ). Not reset if this
   file is reloaded during development, so running commands are not lost. *)
If[ ! AssociationQ @ $gitRuns          , $gitRuns           = <| |> ];
If[ ! AssociationQ @ $gitPathCache     , $gitPathCache      = <| |> ];
If[ ! AssociationQ @ $gitVersions      , $gitVersions       = <| |> ];
If[ ! AssociationQ @ $gitRepositoryInfo, $gitRepositoryInfo = <| |> ];
If[ ! AssociationQ @ $gitCurrentRequests, $gitCurrentRequests = <| |> ];
If[ ! IntegerQ @ $gitRunCount          , $gitRunCount       = 0 ];
If[ ! IntegerQ @ $gitRequestCount      , $gitRequestCount   = 0 ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Finding Git*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFindGit*)

(* acpFindGit[] gives the path of the git executable, or None. It looks in the directories of Environment["PATH"],
   then in the usual install directories (a front end started from the macOS Dock gives the kernel a minimal PATH).
   On macOS, /usr/bin/git is a stub that opens an "install the command line developer tools" dialog when they are
   missing, so it is only used if the tools (or Xcode) are installed. No processes are started. The result is memoized
   for the kernel session; None is looked up again after $gitNotFoundRecheck seconds.
   acpFindGit[<| "PATH", "OperatingSystem", "SystemDirectories", "MacStub", "MacDeveloperTools" |>] is used by tests. *)
acpFindGit // beginDefinition;

acpFindGit[ ] := Module[ { cached, path },
    cached = $gitPathCache;
    If[ KeyExistsQ[ cached, "Path" ] && (StringQ @ cached[ "Path" ] || AbsoluteTime[ ] - cached[ "Time" ] < $gitNotFoundRecheck),
        Return[ cached[ "Path" ], Module ]
    ];
    path = acpFindGit @ gitDefaultEnvironment[ ];
    $gitPathCache = <| "Path" -> path, "Time" -> AbsoluteTime[ ] |>;
    path
];

acpFindGit[ env_Association ] := Module[ { os, windowsQ, names, dirs },
    os       = Lookup[ env, "OperatingSystem", $OperatingSystem ];
    windowsQ = os === "Windows";
    names    = If[ windowsQ, { "git.exe" }, { "git" } ];
    dirs     = Join[
        acpPathDirectories[ Lookup[ env, "PATH", None ], windowsQ ],
        Select[ Replace[ Lookup[ env, "SystemDirectories", { } ], Except[ _List ] -> { } ], StringQ ]
    ];
    SelectFirst[
        DeleteDuplicates @ Flatten @ Outer[ FileNameJoin @ { #1, #2 } &, dirs, names ],
        usableGitQ[ #, os, env ] &,
        None
    ]
];

acpFindGit // endDefinition;


gitDefaultEnvironment // beginDefinition;

gitDefaultEnvironment[ ] := <|
    "PATH"              -> Environment[ "PATH" ],
    "OperatingSystem"   -> $OperatingSystem,
    "SystemDirectories" -> gitSystemDirectories @ $OperatingSystem,
    "MacStub"           -> "/usr/bin/git",
    "MacDeveloperTools" -> {
        "/Library/Developer/CommandLineTools/usr/bin/git",
        "/Applications/Xcode.app/Contents/Developer/usr/bin/git"
    }
|>;

gitDefaultEnvironment // endDefinition;


(* Git for Windows (machine-wide or per-user installation), or the usual Unix directories (including Homebrew's) *)
gitSystemDirectories // beginDefinition;

gitSystemDirectories[ "Windows" ] := Module[ { roots },
    roots = DeleteDuplicates @ Select[
        {
            Environment[ "ProgramFiles" ],
            "C:\\Program Files",
            Replace[ Environment[ "LOCALAPPDATA" ], { s_String :> FileNameJoin @ { s, "Programs" }, _ -> None } ]
        },
        StringQ
    ];
    Flatten @ Table[ FileNameJoin @ { root, "Git", sub }, { root, roots }, { sub, { "cmd", "bin" } } ]
];

gitSystemDirectories[ _ ] := { "/usr/bin", "/usr/local/bin", "/opt/homebrew/bin" };

gitSystemDirectories // endDefinition;


usableGitQ // beginDefinition;

usableGitQ[ path_String, os_, env_Association ] := And[
    acpExecutableFileQ @ path,
    Or[
        os =!= "MacOSX",
        ! samePathQ[ path, Lookup[ env, "MacStub", None ] ],
        AnyTrue[ Replace[ Lookup[ env, "MacDeveloperTools", { } ], Except[ _List ] -> { } ], acpExecutableFileQ ]
    ]
];

usableGitQ // endDefinition;


samePathQ // beginDefinition;
samePathQ[ a_String, b_String ] := StringDelete[ Quiet @ ExpandFileName @ a, "/" ~~ EndOfString ] === StringDelete[ Quiet @ ExpandFileName @ b, "/" ~~ EndOfString ];
samePathQ[ _, _ ] := False;
samePathQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitWorkTreeRoot*)

(* The nearest directory, starting at dir and going up, that contains a ".git" entry (a directory, or a file for
   worktrees and submodules), or None. Only a hint, found without processes: if there is none, git is never started;
   otherwise git decides. The path is walked up as given and, if that finds nothing, with symbolic links resolved (git
   works in the physical directory: a link to a subdirectory of a repository is in that repository). *)
acpGitWorkTreeRoot // beginDefinition;

acpGitWorkTreeRoot[ File[ dir_String ] ] := acpGitWorkTreeRoot @ dir;

acpGitWorkTreeRoot[ dir_String ] := Replace[
    gitWalkUp @ Quiet @ ExpandFileName @ dir,
    None :> Replace[ Quiet @ AbsoluteFileName @ dir, { resolved_String :> gitWalkUp @ resolved, _ -> None } ]
];

acpGitWorkTreeRoot[ _ ] := None;

acpGitWorkTreeRoot // endDefinition;


gitWalkUp // beginDefinition;

gitWalkUp[ dir_String ] := Module[ { d = dir, parent, n = 0 },
    If[ ! TrueQ @ Quiet @ DirectoryQ @ d, Return[ None, Module ] ];
    While[ n++ < 256,
        If[ TrueQ @ Quiet @ FileExistsQ @ FileNameJoin @ { d, ".git" }, Return[ gitTrimSeparator @ d, Module ] ];
        parent = Quiet @ DirectoryName @ d;
        If[ ! StringQ @ parent || parent === "" || parent === d, Break[ ] ];
        d = parent
    ];
    None
];

gitWalkUp[ _ ] := None;

gitWalkUp // endDefinition;


(* DirectoryName keeps a trailing separator ("/a/b/"); roots ("/", "C:\") keep theirs *)
gitTrimSeparator // beginDefinition;

gitTrimSeparator[ dir_String ] := With[ { trimmed = StringDelete[ dir, ("/" | "\\").. ~~ EndOfString ] },
    If[ trimmed === "" || StringMatchQ[ trimmed, LetterCharacter ~~ ":" ], dir, trimmed ]
];

gitTrimSeparator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Running Git*)

(* Defaults of acpProcessRun's "InputAfter" (bytes of standard output without the marker) and "DrainTimeout" (seconds) *)
$processMarkerLimit  = 65536;
$processDrainTimeout = 30;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitRun*)

(* acpGitRun[args, dir, continuation, opts] runs git with the arguments args in the directory dir (acpProcessRun);
   continuation[result] is then evaluated (isolated) in the pump, with
     <| "ExitCode" -> code | None, "Output" -> String, "Error" -> String, "TimedOut" -> _, "TooLarge" -> _,
        "Cancelled" -> _, "StartFailed" -> _, "Duration" -> seconds, "Arguments" -> args |>
   "Output" and "Error" are decoded as UTF-8 (bytes that are not valid UTF-8 as ISO 8859-1), with "\r\n" normalized to
   "\n". opts (an association): "Timeout", "MaxOutput", "Owner", "Request" (see acpProcessRun) and
     "Git"       -> the executable (acpFindGit[] by default).
   The continuation is always called, also when git cannot be started ("StartFailed"). Gives the run ID. *)
acpGitRun // beginDefinition;

acpGitRun[ args_List, dir_String, continuation_ ] := acpGitRun[ args, dir, continuation, <| |> ];

acpGitRun[ args: { ___String }, dir_String, continuation_, opts_Association ] := With[
    { git = Replace[ Lookup[ opts, "Git", Automatic ], Automatic :> acpFindGit[ ] ] },
    If[ StringQ @ git,
        acpProcessRun[ Prepend[ args, git ], dir, continuation, <| opts, "Arguments" -> args |> ],
        processStartFailed[ continuation, <| opts, "Arguments" -> args |> ]
    ]
];

acpGitRun // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpProcessRun*)

(* acpProcessRun[command, dir, continuation, opts] runs a command (the program and its arguments) in the directory dir
   without blocking: it is started with StartProcess and polled from the pump until it has finished; continuation[result]
   is then evaluated (isolated) in the pump, always exactly once (also when the command can't be started), with
     <| "ExitCode" -> code | None, "Output", "Error", "TimedOut" -> _, "TooLarge" -> _, "Cancelled" -> _,
        "StartFailed" -> _, "Duration" -> seconds (since the start), "Arguments" -> args |>
   and also "NoReady" and "ErrorTruncated" for runs with "InputAfter" or "ErrorKeep". Gives the run ID. opts:
     "Timeout"     -> seconds ($gitTimeout) from the start: the process is killed and the result is marked "TimedOut";
     "MaxOutput"   -> bytes ($gitMaxOutput) of standard output and error together: reading stops, the process is killed
                      and the result is marked "TooLarge" (with the first "MaxOutput" bytes of the output);
     "Owner"       -> NotebookObject | None: the process is killed and the result is marked "Cancelled" once the owner's
                      window record is gone;
     "Request"     -> { key, token } | None: the same, once the request token is no longer the latest of key (see
                      gitSupersededQ and acpSetCurrentRequest);
     "Environment" -> Inherited | Association: the environment of the process;
     "Input"       -> None | ByteArray: written right after the start; standard input is then closed, unless
                      "InputAfter" is given;
     "InputAfter"  -> None | <| "Marker" -> ByteArray, "Bytes" -> ByteArray, "Limit" -> bytes |>: once the marker appears
                      in the standard output, the bytes are written and standard input is closed. If "Limit" bytes
                      ($processMarkerLimit) of standard output arrive without the marker, the process is killed and the
                      result is marked "NoReady". Each poll searches only its new output, plus the end of the previous
                      one (gitAwaitMarker);
     "CancelBeforeReady" -> "Kill" | "Drain": a run that is cancelled (owner gone, superseded) while its marker is still
                      awaited is killed, or with "Drain": the continuation is called with "Cancelled" at once, but the
                      process is left to end by itself: standard input is closed, and its output is read and dropped
                      until it exits, or until "DrainTimeout" seconds ($processDrainTimeout) have passed (then it is
                      killed). Such a run stays in $gitRuns until it is gone. (A remote run that is still signing in thus
                      ends cleanly instead of being cut off, which sshd counts as a failed login.)
     "Decode"      -> True | False: "Output" and "Error" are text (acpGitDecode), or ByteArrays (ByteArray[{}] if empty);
     "ErrorKeep"   -> None | bytes: only the end of standard error is kept ("ErrorTruncated" tells whether some was
                      dropped); it still counts toward "MaxOutput";
     "Arguments"   -> what results report (the command by default).
   Processes are always released with KillProcess when they are done (also when they have finished: otherwise every
   process leaks file descriptors in the 15.0.1 kernel). Reads, writes and status checks block ProcessLink's
   $processRunningQTimeout to 0, like ACPLink: while a RunProcess (anywhere in the kernel) reads its child's output,
   ProcessLink sets it to 200 and a read of another process would block until that process writes. Writes are quiet
   (BinaryWrite::errwstrm for a process that has exited: its exit code and output tell what happened). Each poll reads at
   most $gitReadPerPoll bytes per stream (see gitDrain), so the cap and the timeout hold for fast writers too. *)
acpProcessRun // beginDefinition;

acpProcessRun[ command: { __String }, dir_String, continuation_, opts_Association ] := Module[
    { settings, id, proc, input },
    settings = processSettings[ command, opts ];
    proc     = Quiet @ Catch[ StartProcess[ command, Sequence @@ processOptions[ dir, Lookup[ opts, "Environment", Inherited ] ] ], _, $Failed & ];
    If[ ! MatchQ[ proc, _ProcessObject ], Return[ processStartFailed[ continuation, settings ], Module ] ];

    input = Lookup[ opts, "Input", None ];
    If[ ByteArrayQ @ input,
        gitNonBlocking @ BinaryWrite[ proc, input ];
        If[ settings[ "InputAfter" ] === None, gitNonBlocking @ Close @ ProcessConnection[ proc, "StandardInput" ] ]
    ];

    id = "git-run-" <> ToString[ ++$gitRunCount ];
    PreemptProtect[
        $gitRuns[ id ] = <|
            settings,
            "Process"        -> proc,
            "Continuation"   -> continuation,
            "StartedAt"      -> AbsoluteTime[ ],
            "Output"         -> { },
            "Error"          -> { },
            "ErrorTruncated" -> False,
            "Bytes"          -> 0,
            "OutputEnded"    -> False,
            "ErrorEnded"     -> False,
            "ReadyTail"      -> ByteArray[ { } ],
            "BeforeReady"    -> 0,
            "DrainingSince"  -> None
        |>
    ];
    With[ { i = id }, acpSchedule[ gitPoll @ i, $gitPollInterval ] ];
    id
];

acpProcessRun // endDefinition;


(* The settings of a run (its record without the process and its state), from the options of acpProcessRun *)
processSettings // beginDefinition;

processSettings[ command_List, opts_Association ] := Module[ { after, keep },
    after = processInputAfter @ Lookup[ opts, "InputAfter", None ];
    keep  = Replace[ Lookup[ opts, "ErrorKeep", None ], Except[ _Integer? Positive ] -> None ];
    <|
        "Arguments"         -> Lookup[ opts, "Arguments", command ],
        "Timeout"           -> Replace[ Lookup[ opts, "Timeout", $gitTimeout ], Except[ _? Positive ] -> $gitTimeout ],
        "MaxOutput"         -> Replace[ Lookup[ opts, "MaxOutput", $gitMaxOutput ], Except[ _Integer? Positive ] -> $gitMaxOutput ],
        "Owner"             -> Lookup[ opts, "Owner", None ],
        "Request"           -> Lookup[ opts, "Request", None ],
        "Decode"            -> Lookup[ opts, "Decode", True ] =!= False,
        "ErrorKeep"         -> keep,
        "InputAfter"        -> after,
        "CancelBeforeReady" -> Replace[ Lookup[ opts, "CancelBeforeReady", "Kill" ], Except[ "Drain" ] -> "Kill" ],
        "DrainTimeout"      -> Replace[ Lookup[ opts, "DrainTimeout", $processDrainTimeout ], Except[ _? Positive ] -> $processDrainTimeout ],
        "Extended"          -> after =!= None || IntegerQ @ keep
    |>
];

processSettings // endDefinition;


processInputAfter // beginDefinition;

processInputAfter[ after_Association ] := With[ { marker = Lookup[ after, "Marker", None ], bytes = Lookup[ after, "Bytes", None ] },
    If[ ByteArrayQ @ marker && ByteArrayQ @ bytes,
        <|
            "Marker"     -> marker,
            "MarkerText" -> ByteArrayToString[ marker, "ISOLatin1" ],
            "Bytes"      -> bytes,
            "Limit"      -> Replace[ Lookup[ after, "Limit", $processMarkerLimit ], Except[ _Integer? Positive ] -> $processMarkerLimit ]
        |>,
        None
    ]
];

processInputAfter[ _ ] := None;

processInputAfter // endDefinition;


processOptions // beginDefinition;
processOptions[ dir_String, env_Association ] := { ProcessDirectory -> dir, ProcessEnvironment -> env };
processOptions[ dir_String, _ ] := { ProcessDirectory -> dir };
processOptions // endDefinition;


(* A run that could not be started: the continuation gets a "StartFailed" result (in the pump, as always). Gives a run
   ID, as acpProcessRun. *)
processStartFailed // beginDefinition;

processStartFailed[ continuation_, settings0_Association ] := With[
    {
        f      = continuation,
        result = gitRunResult[ processSettings[ { }, settings0 ], None, { }, { }, "StartFailed", 0 ]
    },
    acpSchedule @ gitCallContinuation[ f, result ];
    "git-run-" <> ToString[ ++$gitRunCount ]
];

processStartFailed // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*gitPoll*)

(* One poll of a running command (in the pump): drain both streams, write the input that waits for a marker, then
   finish, kill or poll again. A draining run (cancelled before its marker, see acpProcessRun) only reads and drops its
   output until it ends. *)
gitPoll // beginDefinition;

gitPoll[ id_String ] := Module[ { run, proc, draining, finished, out, err, bytes },
    run = Lookup[ $gitRuns, id, None ];
    If[ ! AssociationQ @ run, Return[ Null, Module ] ];
    proc     = run[ "Process" ];
    draining = run[ "DrainingSince" ] =!= None;
    If[ ! draining && (ownerGoneQ @ run[ "Owner" ] || gitSupersededQ @ run[ "Request" ]),
        Return[
            If[ run[ "InputAfter" ] =!= None && run[ "CancelBeforeReady" ] === "Drain",
                gitStartDraining @ id,
                gitEndRun[ id, "Cancelled" ]
            ],
            Module
        ]
    ];

    (* Checked before reading: everything the process wrote before it exited can then be read in this poll *)
    finished = gitFinishedQ @ proc;
    out   = If[ run[ "OutputEnded" ], <| "Chunks" -> { }, "Ended" -> True |>, gitDrain[ proc, "StandardOutput", run[ "MaxOutput" ] - run[ "Bytes" ], finished ] ];
    bytes = run[ "Bytes" ] + Total[ Length /@ out[ "Chunks" ] ];
    err   = If[ run[ "ErrorEnded" ], <| "Chunks" -> { }, "Ended" -> True |>, gitDrain[ proc, "StandardError", run[ "MaxOutput" ] - bytes, finished ] ];
    bytes = bytes + Total[ Length /@ err[ "Chunks" ] ];
    run   = <|
        run,
        "Output"      -> If[ draining, { }, Join[ run[ "Output" ], out[ "Chunks" ] ] ],
        "Error"       -> If[ draining, { }, Join[ run[ "Error" ], err[ "Chunks" ] ] ],
        "Bytes"       -> bytes,
        "OutputEnded" -> out[ "Ended" ],
        "ErrorEnded"  -> err[ "Ended" ]
    |>;
    If[ ! draining, run = gitAwaitMarker[ gitKeepErrorEnd @ run, out[ "Chunks" ] ] ];
    PreemptProtect @ If[ KeyExistsQ[ $gitRuns, id ], $gitRuns[ id ] = run ];

    Which[
        bytes > run[ "MaxOutput" ],
            gitEndRun[ id, "TooLarge" ],
        run[ "OutputEnded" ] && run[ "ErrorEnded" ] && finished,
            gitEndRun[ id, "Finished" ],
        draining && AbsoluteTime[ ] - run[ "DrainingSince" ] > run[ "DrainTimeout" ],
            gitEndRun[ id, "TimedOut" ],
        ! draining && AbsoluteTime[ ] - run[ "StartedAt" ] > run[ "Timeout" ],
            gitEndRun[ id, "TimedOut" ],
        ! draining && run[ "InputAfter" ] =!= None && run[ "BeforeReady" ] > run[ "InputAfter", "Limit" ],
            gitEndRun[ id, "NoReady" ],
        True,
            With[ { i = id }, acpSchedule[ gitPoll @ i, $gitPollInterval ] ]
    ]
];

gitPoll // endDefinition;


(* The input that waits for a marker ("InputAfter"): searched for in the output read in this poll, plus the last bytes
   of the previous polls ("ReadyTail", one byte shorter than the marker), and only up to the limit, so that the work per
   poll is bounded however much the process writes. Found: the bytes are written and standard input is closed. *)
gitAwaitMarker // beginDefinition;

gitAwaitMarker[ run_Association, chunks_List ] := Module[ { after, new, room, joined, keep },
    after = run[ "InputAfter" ];
    If[ after === None || chunks === { }, Return[ run, Module ] ];
    new    = Join @@ chunks;
    room   = Max[ 0, after[ "Limit" ] - run[ "BeforeReady" ] ] + Length @ after[ "Marker" ];
    joined = Join[ run[ "ReadyTail" ], Take[ new, UpTo[ room ] ] ];
    If[ StringContainsQ[ ByteArrayToString[ joined, "ISOLatin1" ], after[ "MarkerText" ] ],
        gitNonBlocking @ BinaryWrite[ run[ "Process" ], after[ "Bytes" ] ];
        gitNonBlocking @ Close @ ProcessConnection[ run[ "Process" ], "StandardInput" ];
        <| run, "InputAfter" -> None, "ReadyTail" -> ByteArray[ { } ] |>,
        keep = Min[ Length @ joined, Length @ after[ "Marker" ] - 1 ];
        <|
            run,
            "BeforeReady" -> run[ "BeforeReady" ] + Length @ new,
            "ReadyTail"   -> If[ keep > 0, Take[ joined, -keep ], ByteArray[ { } ] ]
        |>
    ]
];

gitAwaitMarker // endDefinition;


(* "ErrorKeep": only the last bytes of standard error are kept *)
gitKeepErrorEnd // beginDefinition;

gitKeepErrorEnd[ run_Association ] := With[ { keep = run[ "ErrorKeep" ] },
    If[ IntegerQ @ keep && Total[ Length /@ run[ "Error" ] ] > keep,
        <| run, "Error" -> { Take[ Join @@ run[ "Error" ], -keep ] }, "ErrorTruncated" -> True |>,
        run
    ]
];

gitKeepErrorEnd // endDefinition;


(* A run cancelled before its marker with "CancelBeforeReady" -> "Drain": the continuation is called with "Cancelled"
   now, and the process is left to end by itself (standard input is closed; the following polls drop its output) *)
gitStartDraining // beginDefinition;

gitStartDraining[ id_String ] := Module[ { run },
    run = Lookup[ $gitRuns, id, None ];
    If[ ! AssociationQ @ run, Return[ Null, Module ] ];
    run = <| run, "DrainingSince" -> AbsoluteTime[ ], "Output" -> { }, "Error" -> { } |>;
    PreemptProtect @ If[ KeyExistsQ[ $gitRuns, id ], $gitRuns[ id ] = run ];
    gitNonBlocking @ Close @ ProcessConnection[ run[ "Process" ], "StandardInput" ];
    With[ { i = id }, acpSchedule[ gitPoll @ i, $gitPollInterval ] ];
    gitCallContinuation[ run[ "Continuation" ], gitRunResult[ run, None, { }, { }, "Cancelled", AbsoluteTime[ ] - run[ "StartedAt" ] ] ]
];

gitStartDraining // endDefinition;


(* Reads what is available on a stream without waiting: at most $gitReadPerPoll bytes, and at most one byte more than
   budget (so that a larger output is noticed). ProcessLink writes the output of the process to a file and the stream
   reads that file, so what is available is the file's size minus the stream position. A read of exactly that many
   bytes returns at once (a read of more bytes waits for them, and an EndOfBuffer read goes on for as long as the
   process keeps writing, which can be all of its output). The stream has ended when the process had finished before
   the poll and everything was read. Streams that are not files are read with EndOfBuffer: {} means that nothing is
   available yet, EndOfFile (or anything else) that the stream has ended. *)
gitDrain // beginDefinition;

gitDrain[ proc_, stream_String, budget_Integer, finished_ ] := Module[
    { connection, chunks = { }, ended = False, available, chunk, n = 0, bytes = 0 },
    connection = gitNonBlocking @ ProcessConnection[ proc, stream ];
    While[ n++ < 64 && bytes <= budget && bytes < $gitReadPerPoll,
        available = gitAvailableBytes @ connection;
        Which[
            ! IntegerQ @ available,
                chunk = gitNonBlocking @ ReadByteArray[ connection, EndOfBuffer ];
                Which[
                    ByteArrayQ @ chunk && Length @ chunk > 0, AppendTo[ chunks, chunk ]; bytes += Length @ chunk,
                    MatchQ[ chunk, { } | _ByteArray ]       , Break[ ],
                    True                                    , ended = True; Break[ ]
                ],
            available > 0,
                chunk = gitNonBlocking @ ReadByteArray[ connection, Min[ available, $gitReadPerPoll - bytes, budget - bytes + 1 ] ];
                If[ ByteArrayQ @ chunk && Length @ chunk > 0,
                    AppendTo[ chunks, chunk ]; bytes += Length @ chunk,
                    ended = True; Break[ ]
                ],
            True,
                ended = TrueQ @ finished;
                Break[ ]
        ]
    ];
    <| "Chunks" -> chunks, "Ended" -> ended |>
];

gitDrain // endDefinition;


(* Bytes that can be read from a process stream without waiting, or None if that is not known *)
gitAvailableBytes // beginDefinition;

gitAvailableBytes[ stream: InputStream[ file_String, ___ ] ] := With[
    { size = Quiet @ FileByteCount @ file, position = Quiet @ StreamPosition @ stream },
    If[ IntegerQ @ size && IntegerQ @ position, Max[ size - position, 0 ], None ]
];

gitAvailableBytes[ _ ] := None;

gitAvailableBytes // endDefinition;


(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
gitNonBlocking // beginDefinition;
gitNonBlocking // Attributes = { HoldFirst };
gitNonBlocking[ eval_ ] := Block[ { ProcessLink`Private`$processRunningQTimeout = 0 }, Quiet @ eval ];
gitNonBlocking // endDefinition;
(* :!CodeAnalysis::EndBlock:: *)


gitFinishedQ // beginDefinition;
gitFinishedQ[ proc_ ] := gitNonBlocking @ ProcessStatus @ proc =!= "Running";
gitFinishedQ // endDefinition;


ownerGoneQ // beginDefinition;
ownerGoneQ[ nbo_NotebookObject ] := ! AssociationQ @ acpWindowGet @ nbo;
ownerGoneQ[ _ ] := False;
ownerGoneQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*gitEndRun*)

(* Removes the run, releases (or kills) the process and calls the continuation (not for a draining run: it was called
   when the run was cancelled). how: "Finished" | "TimedOut" | "TooLarge" | "Cancelled" | "NoReady". The output passed
   on is cut at the cap (the last poll reads one byte more); with "ErrorKeep", standard error is its kept end. *)
gitEndRun // beginDefinition;

gitEndRun[ id_String, how_String ] := Module[ { run, exit, output, error },
    run = PreemptProtect @ With[ { r = Lookup[ $gitRuns, id, None ] }, KeyDropFrom[ $gitRuns, id ]; r ];
    If[ ! AssociationQ @ run, Return[ Null, Module ] ];
    exit = If[ how === "Finished", gitExitCode @ run[ "Process" ], None ];
    gitNonBlocking @ KillProcess @ run[ "Process" ];
    If[ run[ "DrainingSince" ] =!= None,
        acpLog[ "ProcessDrained", <| "How" -> how, "ExitCode" -> exit, "Seconds" -> AbsoluteTime[ ] - run[ "DrainingSince" ] |> ];
        Return[ Null, Module ]
    ];
    output = gitTakeBytes[ run[ "Output" ], run[ "MaxOutput" ] ];
    error  = If[ IntegerQ @ run[ "ErrorKeep" ],
        run[ "Error" ],
        gitTakeBytes[ run[ "Error" ], run[ "MaxOutput" ] - Total[ Length /@ output ] ]
    ];
    gitCallContinuation[
        run[ "Continuation" ],
        gitRunResult[ run, exit, output, error, how, AbsoluteTime[ ] - run[ "StartedAt" ] ]
    ]
];

gitEndRun // endDefinition;


(* The first n bytes of a list of ByteArrays, as a list of ByteArrays (only the last chunk kept is copied) *)
gitTakeBytes // beginDefinition;

gitTakeBytes[ chunks_List, n_Integer ] /; Total[ Length /@ chunks ] <= n := chunks;

gitTakeBytes[ chunks: { __ByteArray }, n_Integer? Positive ] := Module[ { ends, whole, rest },
    ends  = Accumulate[ Length /@ chunks ];
    whole = LengthWhile[ ends, # <= n & ];
    rest  = n - If[ whole === 0, 0, ends[[ whole ]] ];
    Join[ Take[ chunks, whole ], If[ rest > 0, { Take[ chunks[[ whole + 1 ]], rest ] }, { } ] ]
];

gitTakeBytes[ _List, _Integer ] := { };

gitTakeBytes // endDefinition;


gitExitCode // beginDefinition;
gitExitCode[ proc_ ] := Replace[ gitNonBlocking @ ProcessInformation[ proc, "ExitCode" ], Except[ _Integer ] -> None ];
gitExitCode // endDefinition;


(* The result of a run (run: its record or settings) *)
gitRunResult // beginDefinition;

gitRunResult[ run_Association, exit_, out_List, err_List, how_String, duration_ ] := Join[
    <|
        "ExitCode"    -> exit,
        "Output"      -> gitRunOutput[ run, out ],
        "Error"       -> gitRunOutput[ run, err ],
        "TimedOut"    -> how === "TimedOut",
        "TooLarge"    -> how === "TooLarge",
        "Cancelled"   -> how === "Cancelled",
        "StartFailed" -> how === "StartFailed",
        "Duration"    -> duration,
        "Arguments"   -> run[ "Arguments" ]
    |>,
    If[ TrueQ @ run[ "Extended" ],
        <| "NoReady" -> how === "NoReady", "ErrorTruncated" -> TrueQ @ Lookup[ run, "ErrorTruncated", False ] |>,
        <| |>
    ]
];

gitRunResult // endDefinition;


gitRunOutput // beginDefinition;
gitRunOutput[ run_Association, chunks_List ] /; TrueQ @ run[ "Decode" ] := acpGitDecode @ chunks;
gitRunOutput[ _, { } ] := ByteArray[ { } ];
gitRunOutput[ _, chunks: { __ByteArray } ] := Join @@ chunks;
gitRunOutput // endDefinition;


gitCallContinuation // beginDefinition;
gitCallContinuation[ f_, result_ ] := (acpIsolated @ f @ result; Null);
gitCallContinuation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Exported helpers*)

(* Makes token the latest request of key: a run started with "Request" -> { key, oldToken } is then cancelled at its
   next poll (see gitSupersededQ) *)
acpSetCurrentRequest // beginDefinition;
acpSetCurrentRequest[ key_, token_ ] := PreemptProtect[ $gitCurrentRequests[ key ] = token ];
acpSetCurrentRequest // endDefinition;


(* Whether a run with these "Owner" and "Request" options would be cancelled (e.g. before it is started) *)
acpRunCancelledQ // beginDefinition;
acpRunCancelledQ[ owner_, request_ ] := TrueQ[ ownerGoneQ @ owner || gitSupersededQ @ request ];
acpRunCancelledQ // endDefinition;


(* Whether a run (an ID of acpProcessRun) is still running or draining *)
acpProcessRunningQ // beginDefinition;
acpProcessRunningQ[ id_String ] := KeyExistsQ[ $gitRuns, id ];
acpProcessRunningQ[ _ ] := False;
acpProcessRunningQ // endDefinition;


(* Whether any run of acpProcessRun (git, or a remote one-shot run) is running or draining: the pump must keep running
   for them *)
acpBackgroundRunsQ // beginDefinition;
acpBackgroundRunsQ[ ] := Length @ $gitRuns > 0;
acpBackgroundRunsQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitDecode*)

(* Bytes (a ByteArray or a list of them) as text: UTF-8, where invalid bytes become the ISO 8859-1 characters (that is
   what ByteArrayToString does, with messages), with "\r\n" normalized to "\n". Everything git writes and every
   untracked file is decoded here, so the characters of the front end's linear syntax are neutralized here too
   (acpNeutralizeLinearSyntax): file names and contents must never become boxes in the review window. *)
acpGitDecode // beginDefinition;

acpGitDecode[ { } ] := "";

acpGitDecode[ chunks: { __ByteArray } ] := acpGitDecode @ Apply[ Join, chunks ];

acpGitDecode[ bytes_ByteArray ] := acpNeutralizeLinearSyntax @ gitNormalizeNewlines @ Replace[
    Quiet @ ByteArrayToString[ bytes, "UTF-8" ],
    Except[ _String ] :> Replace[ Quiet @ ByteArrayToString[ bytes, "ISOLatin1" ], Except[ _String ] -> "" ]
];

acpGitDecode[ _ ] := "";

acpGitDecode // endDefinition;


(* "\r\n" -> "\n" (a search for a literal string is much faster than a replacement that finds nothing) *)
gitNormalizeNewlines // beginDefinition;
gitNormalizeNewlines[ s_String ] := If[ StringContainsQ[ s, "\r\n" ], StringReplace[ s, "\r\n" -> "\n" ], s ];
gitNormalizeNewlines // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*gitCommand*)

(* The arguments of a git command with the global options of this file: no pager, no optional locks, no lazy fetches
   (if git supports it), $gitSafeConfig and the neutralized filter drivers. *)
gitCommand // beginDefinition;

gitCommand[ state_Association, args_List ] := Join[
    { "--no-pager", "--no-optional-locks" },
    If[ gitVersionAtLeastQ[ Lookup[ state, "Version", { 0 } ], $gitNoLazyFetchVersion ], { "--no-lazy-fetch" }, { } ],
    Catenate[ { "-c", # } & /@ Join[ $gitSafeConfig, gitFilterOverrides @ Lookup[ state, "Filters", { } ] ] ],
    args
];

gitCommand // endDefinition;


(* A filter driver runs its clean command (or its process) when status or diff read a file of the working tree. Empty
   commands are skipped, and an empty process also disables the clean command (git only uses clean and smudge when
   there is no process); the driver must not be required, since a required driver that is not applied fails the
   command. Git splits -c arguments at the first "=", so drivers whose names contain "=" can't be overridden this way
   (see gitStepFilters). The name can be empty (filter..clean, for the attribute "filter="). *)
gitFilterOverrides // beginDefinition;

gitFilterOverrides[ names: { ___String } ] := Catenate @ Map[
    { "filter." <> # <> ".clean=", "filter." <> # <> ".smudge=", "filter." <> # <> ".process=", "filter." <> # <> ".required=false" } &,
    names
];

gitFilterOverrides[ _ ] := { };

gitFilterOverrides // endDefinition;


gitVersionAtLeastQ // beginDefinition;

gitVersionAtLeastQ[ version: { ___Integer }, minimum: { ___Integer } ] := With[
    { a = PadRight[ version, 3 ], b = PadRight[ minimum, 3 ] },
    FirstCase[ Transpose @ { a, b }, { x_, y_ } /; x =!= y :> x > y, True ]
];

gitVersionAtLeastQ[ _, _ ] := False;

gitVersionAtLeastQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Parsing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitParseVersion*)

(* "git version 2.53.0", "git version 2.39.5 (Apple Git-154)", "git version 2.45.1.windows.1" -> { 2, 53, 0 } etc.
   None if the output is not recognized. *)
acpGitParseVersion // beginDefinition;

acpGitParseVersion[ output_String ] := FirstCase[
    StringCases[
        output,
        RegularExpression[ "git version (\\d+)\\.(\\d+)(?:\\.(\\d+))?" ] :> { "$1", "$2", "$3" },
        1
    ],
    parts_List :> ToExpression /@ DeleteCases[ parts, "" ],
    None
];

acpGitParseVersion[ _ ] := None;

acpGitParseVersion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitParseRevParse*)

(* The output of rev-parse --show-toplevel --show-prefix --show-object-format (one line each, in that order; the
   prefix is "" at the top level and ends with "/" otherwise). An unknown object format line (e.g. an old git that
   echoes the option) means sha1. *)
acpGitParseRevParse // beginDefinition;

acpGitParseRevParse[ output_String ] := Module[ { lines },
    lines = StringSplit[ output, "\n", All ];
    <|
        "Root"         -> Replace[ First[ lines, None ], Except[ _String? (StringLength[ # ] > 0 &) ] -> None ],
        "Prefix"       -> Replace[ If[ Length @ lines >= 2, lines[[ 2 ]], "" ], Except[ _String ] -> "" ],
        "ObjectFormat" -> Replace[ If[ Length @ lines >= 3, lines[[ 3 ]], "" ], Except[ "sha1" | "sha256" ] -> "sha1" ]
    |>
];

acpGitParseRevParse[ _ ] := <| "Root" -> None, "Prefix" -> "", "ObjectFormat" -> "sha1" |>;

acpGitParseRevParse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitParseFilterDrivers*)

(* The names of the filter drivers in the output of config -z --get-regexp ^filter\. (entries "key\nvalue", NUL
   terminated; keys are filter.<name>.<variable>, where the name may be empty and may contain any character but
   newlines, e.g. dots, spaces and "="). *)
acpGitParseFilterDrivers // beginDefinition;

acpGitParseFilterDrivers[ output_String ] := DeleteDuplicates @ Flatten @ Map[
    StringCases[
        First @ StringSplit[ #, "\n", 2 ],
        StartOfString ~~ "filter." ~~ name___ ~~ "." ~~ Except[ "." ].. ~~ EndOfString :> name
    ] &,
    Select[ StringSplit[ output, $gitNUL ], StringLength[ # ] > 0 & ]
];

acpGitParseFilterDrivers[ _ ] := { };

acpGitParseFilterDrivers // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitParseStatus*)

(* status --porcelain=v2 -z --branch: header lines "# branch.oid <oid> | (initial)" and "# branch.head <name> |
   (detached)", then NUL-terminated entries (fields are separated by single spaces, the path is the rest):
     1 XY sub mH mI mW hH hI path                 changed
     2 XY sub mH mI mW hH hI Xscore path<NUL>orig  renamed or copied (the original path is the next field)
     u XY sub m1 m2 m3 mW h1 h2 h3 path           unmerged
     ? path                                       untracked (a directory, e.g. a nested repository, ends with "/")
   Paths are relative to the repository root. Gives
     <| "Branch" -> <| "OID", "Head", "Initial", "Detached" |>, "Entries" -> { entry... } |>
   with entries <| "Path", "OrigPath", "XY", "Status", "Submodule", "Directory" |> (see gitEntryStatus), in git's order:
   tracked files, then untracked files, each sorted by path (byte-wise). *)
acpGitParseStatus // beginDefinition;

acpGitParseStatus[ output_String ] := With[ { data = gitStatusData @ output },
    <| "Branch" -> data[ "Branch" ], "Entries" -> Join[ data[ "Tracked" ], untrackedEntry /@ data[ "Untracked" ] ] |>
];

acpGitParseStatus[ _ ] := acpGitParseStatus[ "" ];

acpGitParseStatus // endDefinition;


(* What the change set code uses: <| "Branch", "Tracked" -> { entry... }, "Untracked" -> { path... } |>. Untracked files
   stay paths (a working tree can have hundreds of thousands, of which at most $acpGitMaxFiles are listed), and the
   fields of each kind are matched at once. Also accepts the result of acpGitParseStatus. *)
gitStatusData // beginDefinition;

gitStatusData[ output_String ] := Module[ { fields, n, kinds, items },
    fields = StringSplit[ output, $gitNUL ];
    n      = Length @ fields;
    kinds  = StringTake[ fields, UpTo[ 2 ] ];
    (* The field after a rename or copy entry is its original path, whatever it looks like (also "2 ..."; one pass in
       order, so that an original path is never taken for an entry): *)
    Do[
        If[ kinds[[ p ]] === "2 " && p < n, kinds[[ p + 1 ]] = "" ],
        { p, Flatten @ Position[ kinds, "2 ", { 1 }, Heads -> False ] }
    ];
    items = Join[
        statusItems[ fields, kinds, "1", $statusChanged ],
        statusItems[ fields, kinds, "2", $statusRenamed ],
        statusItems[ fields, kinds, "u", $statusUnmerged ]
    ];
    <|
        "Branch"    -> statusBranch @ Pick[ fields, kinds, "# " ],
        "Tracked"   -> If[ items === { }, { }, items[[ Ordering @ items[[ All, 1 ]], 2 ]] ],
        "Untracked" -> StringDrop[ Pick[ fields, kinds, "? " ], 2 ]
    |>
];

gitStatusData[ KeyValuePattern @ { "Branch" -> branch_Association, "Entries" -> entries_List } ] := <|
    "Branch"    -> branch,
    "Tracked"   -> Select[ entries, #[ "Status" ] =!= "Untracked" & ],
    "Untracked" -> Lookup[ Select[ entries, #[ "Status" ] === "Untracked" & ], "Path", { } ]
|>;

gitStatusData[ data: KeyValuePattern @ { "Branch" -> _Association, "Tracked" -> _List, "Untracked" -> _List } ] := data;

gitStatusData[ _ ] := gitStatusData[ "" ];

gitStatusData // endDefinition;


(* (?s): paths may contain newlines. The groups are XY, sub and the path. *)
$statusChanged  = RegularExpression[ "(?s)^1 (..) (\\S{4}) [0-7]+ [0-7]+ [0-7]+ [0-9a-f]+ [0-9a-f]+ (.+)$" ];
$statusRenamed  = RegularExpression[ "(?s)^2 (..) (\\S{4}) [0-7]+ [0-7]+ [0-7]+ [0-9a-f]+ [0-9a-f]+ [RC]\\d+ (.+)$" ];
$statusUnmerged = RegularExpression[ "(?s)^u (..) (\\S{4}) [0-7]+ [0-7]+ [0-7]+ [0-7]+ [0-9a-f]+ [0-9a-f]+ [0-9a-f]+ (.+)$" ];


(* { position, entry } for the entries of one kind ("1", "2" or "u"); fields that do not match are skipped, and so are
   entries that do not differ from HEAD (status None, see gitEntryStatus). A renamed file whose new path was deleted
   from the working tree is its original path, deleted. *)
statusItems // beginDefinition;

statusItems[ fields_List, kinds_List, kind_String, re_ ] := Module[ { positions, matches, keep, rows, statuses, origins, paths, entries },
    positions = Flatten @ Position[ kinds, kind <> " ", { 1 }, Heads -> False ];
    matches   = StringCases[ fields[[ positions ]], re :> { "$1", "$2", "$3" }, 1 ];
    keep      = Flatten @ Position[ matches, { { _, _, _ } }, { 1 }, Heads -> False ];
    If[ keep === { }, Return[ { }, Module ] ];
    positions = positions[[ keep ]];
    rows      = matches[[ keep, 1 ]];
    (* One status per combination of XY and sub (there are only a few): *)
    statuses  = Lookup[
        AssociationMap[ gitEntryStatus[ kind, #[[ 1 ]], #[[ 2 ]] ] &, Union @ rows[[ All, { 1, 2 } ]] ],
        Key /@ rows[[ All, { 1, 2 } ]]
    ];
    origins   = If[ kind === "2",
        If[ # < Length @ fields, fields[[ # + 1 ]], None ] & /@ positions,
        ConstantArray[ None, Length @ positions ]
    ];
    paths = rows[[ All, 3 ]];
    If[ kind === "2",
        With[ { deleted = Select[ Flatten @ Position[ statuses, "Deleted", { 1 }, Heads -> False ], StringQ @ origins[[ # ]] & ] },
            paths[[ deleted ]]   = origins[[ deleted ]];
            origins[[ deleted ]] = None
        ]
    ];
    keep = Flatten @ Position[ statuses, _String, { 1 }, Heads -> False ];
    entries = AssociationThread[ { "Path", "OrigPath", "XY", "Status", "Submodule", "Directory" }, # ] & /@ Transpose @ {
        paths[[ keep ]],
        origins[[ keep ]],
        rows[[ keep, 1 ]],
        statuses[[ keep ]],
        StringStartsQ[ rows[[ keep, 2 ]], "S" ],
        ConstantArray[ False, Length @ keep ]
    };
    Transpose @ { positions[[ keep ]], entries }
];

statusItems // endDefinition;


statusBranch // beginDefinition;

statusBranch[ headers_List ] := Module[ { oid, head },
    oid  = FirstCase[ headers, h_String /; StringStartsQ[ h, "# branch.oid " ] :> StringDrop[ h, 13 ], None ];
    head = FirstCase[ headers, h_String /; StringStartsQ[ h, "# branch.head " ] :> StringDrop[ h, 14 ], None ];
    <|
        "OID"      -> If[ oid === "(initial)", None, oid ],
        "Head"     -> If[ head === "(detached)", None, head ],
        "Initial"  -> oid === "(initial)",
        "Detached" -> head === "(detached)"
    |>
];

statusBranch // endDefinition;


untrackedEntry // beginDefinition;

untrackedEntry[ path_String ] := <|
    "Path"      -> path,
    "OrigPath"  -> None,
    "XY"        -> "??",
    "Status"    -> "Untracked",
    "Submodule" -> False,
    "Directory" -> StringEndsQ[ path, "/" ]
|>;

untrackedEntry // endDefinition;


(* The change of a file compared with HEAD (index and working tree combined): "Modified" | "Added" | "Deleted" |
   "Renamed" | "Copied" | "TypeChanged" | "Conflict" | "Untracked" | "Submodule", or None (no difference). X is the
   index compared with HEAD and Y the working tree compared with the index, so a file that was added (or copied) to
   the index and then deleted from the working tree ("AD", "CD") is in neither HEAD nor the working tree, and a file that
   was renamed and then deleted ("RD") is a deleted original. *)
gitEntryStatus // beginDefinition;

gitEntryStatus[ "?", _, _ ] := "Untracked";
gitEntryStatus[ "u", _, _ ] := "Conflict";
gitEntryStatus[ _, "AD" | "CD", _ ] := None;
gitEntryStatus[ _, "RD", _ ] := "Deleted";
gitEntryStatus[ _, _, sub_String ] /; StringStartsQ[ sub, "S" ] := "Submodule";

gitEntryStatus[ _, xy_String, _ ] := With[ { c = Characters @ xy },
    Which[
        MemberQ[ c, "R" ], "Renamed",
        MemberQ[ c, "C" ], "Copied",
        MemberQ[ c, "D" ], "Deleted",
        MemberQ[ c, "A" ], "Added",
        MemberQ[ c, "T" ], "TypeChanged",
        True             , "Modified"
    ]
];

gitEntryStatus // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitParseNumstat*)

(* diff --numstat -z: "added<TAB>deleted<TAB>path<NUL>" per file; a rename or copy has an empty path followed by
   "old<NUL>new<NUL>"; binary files have "-" counts. Gives { <| "Path", "OrigPath", "Added", "Deleted", "Binary" |>... }
   (counts are None for binary files). *)
acpGitParseNumstat // beginDefinition;
acpGitParseNumstat[ output_String ] := KeyValueMap[ numstatEntry, gitNumstatData @ output ];
acpGitParseNumstat[ _ ] := { };
acpGitParseNumstat // endDefinition;


(* What the change set code uses: <| path -> { added, deleted, origPath } |> (all fields are matched at once). Also
   accepts the result of acpGitParseNumstat. *)
gitNumstatData // beginDefinition;

gitNumstatData[ output_String ] := Module[ { fields, n, matches, renames = Internal`Bag[ ], consumed, normal, columns },
    fields   = StringSplit[ output, $gitNUL ];
    n        = Length @ fields;
    matches  = StringCases[ fields, $numstatField :> { "$1", "$2", "$3" }, 1 ];
    (* A packed array of 0 and 1, so that setting an element does not copy it: *)
    consumed = ConstantArray[ 0, n ];
    (* A rename or copy has an empty path and is followed by the old and the new path (which are never entries; one
       pass in order, linear in the number of renames): *)
    Do[
        If[ consumed[[ i ]] === 0 && i + 2 <= n,
            Internal`StuffBag[ renames, i ];
            consumed[[ i + 1 ]] = 1;
            consumed[[ i + 2 ]] = 1
        ],
        { i, Flatten @ Position[ matches, { { _, _, "" } }, { 1 }, Heads -> False ] }
    ];
    renames = Internal`BagPart[ renames, All ];
    normal  = Flatten @ Position[ matches, { { _, _, Except[ "" ] } }, { 1 }, Heads -> False ];
    normal  = Pick[ normal, consumed[[ normal ]], 0 ];
    If[ normal === { } && renames === { }, Return[ <| |>, Module ] ];
    (* Columns { path, added, deleted, orig }, in the order of the output: *)
    columns = Map[
        #[[ Ordering @ Join[ normal, renames ] ]] &,
        {
            Join[ matches[[ normal, 1, 3 ]], fields[[ renames + 2 ]] ],
            numstatCounts @ Join[ matches[[ normal, 1, 1 ]], matches[[ renames, 1, 1 ]] ],
            numstatCounts @ Join[ matches[[ normal, 1, 2 ]], matches[[ renames, 1, 2 ]] ],
            Join[ ConstantArray[ None, Length @ normal ], fields[[ renames + 1 ]] ]
        }
    ];
    AssociationThread[ columns[[ 1 ]], Transpose @ Rest @ columns ]
];

gitNumstatData[ entries: { ___Association } ] :=
    Association @ Map[ #[ "Path" ] -> { #[ "Added" ], #[ "Deleted" ], #[ "OrigPath" ] } &, entries ];

gitNumstatData[ data_Association ] := data;

gitNumstatData[ _ ] := <| |>;

gitNumstatData // endDefinition;


$numstatField = RegularExpression[ "(?s)^(-|\\d+)\t(-|\\d+)\t(.*)$" ];


numstatCounts // beginDefinition;
numstatCounts[ counts_List ] := Replace[ counts, { "-" -> None, s_String :> FromDigits @ s }, { 1 } ];
numstatCounts // endDefinition;


numstatEntry // beginDefinition;

numstatEntry[ path_String, { added_, deleted_, orig_ } ] := <|
    "Path"     -> path,
    "OrigPath" -> orig,
    "Added"    -> added,
    "Deleted"  -> deleted,
    "Binary"   -> added === None || deleted === None
|>;

numstatEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitUnquotePath*)

(* Git writes paths with special characters (control characters, '"', '\') as C-style quoted strings, also with
   core.quotepath=off: \a \b \t \n \v \f \r \" \\ and octal escapes \ooo for other bytes (consecutive escapes are the
   bytes of one UTF-8 character). Unquoted strings are returned unchanged. *)
acpGitUnquotePath // beginDefinition;

acpGitUnquotePath[ s_String ] /; StringLength @ s >= 2 && StringStartsQ[ s, "\"" ] && StringEndsQ[ s, "\"" ] :=
    StringReplace[
        StringTake[ s, { 2, -2 } ],
        {
            RegularExpression[ "(?:\\\\[0-7]{3})+" ] :> gitDecodeOctal[ "$0" ],
            "\\" ~~ c_ :> Lookup[ $gitEscapes, c, c ]
        }
    ];

acpGitUnquotePath[ s_String ] := s;

acpGitUnquotePath // endDefinition;


$gitEscapes = <|
    "a"  -> FromCharacterCode[ 7 ],
    "b"  -> FromCharacterCode[ 8 ],
    "t"  -> "\t",
    "n"  -> "\n",
    "v"  -> FromCharacterCode[ 11 ],
    "f"  -> FromCharacterCode[ 12 ],
    "r"  -> "\r",
    "\"" -> "\"",
    "\\" -> "\\"
|>;


gitDecodeOctal // beginDefinition;

gitDecodeOctal[ escapes_String ] := acpGitDecode @ ByteArray @ Map[
    FromDigits[ #, 8 ] &,
    StringCases[ escapes, "\\" ~~ d: Repeated[ DigitCharacter, { 3 } ] :> d ]
];

gitDecodeOctal // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitSplitPatch*)

(* Splits git's patch (diff with --src-prefix=a/ --dst-prefix=b/) into one chunk per "diff --git " line (lines of
   hunks always start with " ", "+", "-" or "\", so the split is unambiguous). Each chunk is
     <| "OldPath", "NewPath" (repository-relative, None for /dev/null), "Header" (the lines before the first hunk),
        "Hunks" (the text from the first "@@" line, or None), "Binary", "NewFile", "DeletedFile", "Rename", "Copy",
        "Similarity", "OldMode", "NewMode", "Submodule" |>
   Paths come from "rename/copy from/to" lines, else from the "---"/"+++" lines, else from the "diff --git" line
   (where an unquoted "a/P b/P" pair is split in the middle, like git apply does). A patch can have up to $gitMaxOutput
   bytes, in one file or in tens of thousands, so the patch is split with string positions (gitPatchTexts) and the
   header lines of all chunks are parsed at once (gitPatchChunks): the time is linear in the size of the patch, and
   requests split the chunks in slices (gitStepSplit). *)
acpGitSplitPatch // beginDefinition;
acpGitSplitPatch[ patch_String ] := gitPatchChunks @ gitPatchTexts @ patch;
acpGitSplitPatch[ _ ] := { };
acpGitSplitPatch // endDefinition;


(* The text of each chunk of a patch (without the newline before the next chunk) *)
gitPatchTexts // beginDefinition;

gitPatchTexts[ patch_String ] := Module[ { starts, texts },
    starts = Join[
        If[ StringStartsQ[ patch, "diff --git " ], { 1 }, { } ],
        StringPosition[ patch, "\ndiff --git " ][[ All, 1 ]] + 1
    ];
    If[ starts === { }, Return[ { }, Module ] ];
    texts = StringTake[ patch, Transpose @ { starts, Append[ Rest @ starts - 2, StringLength @ patch ] } ];
    (* The end of the patch (lines of hunks are never empty): *)
    texts[[ -1 ]] = gitTrimNewlines @ texts[[ -1 ]];
    texts
];

gitPatchTexts // endDefinition;


(* Chunks for chunk texts. Each header field is found in all headers with one StringCases. *)
gitPatchChunks // beginDefinition;

gitPatchChunks[ { } ] := { };

gitPatchChunks[ texts: { __String } ] := Module[ { hunkStarts, headers, hunks, field, flag },
    hunkStarts = Replace[ StringPosition[ texts, "\n@@", 1 ], { { { p_, _ } } :> p, _ -> None }, { 1 } ];
    headers    = MapThread[ If[ #2 === None, #1, StringTake[ #1, #2 - 1 ] ] &, { texts, hunkStarts } ];
    hunks      = MapThread[ If[ #2 === None, None, StringDrop[ #1, #2 ] ] &, { texts, hunkStarts } ];
    (* The value of the first header line that starts with a prefix (a regular expression), in each header, or None: *)
    field = Function[ prefix,
        Replace[ StringCases[ headers, RegularExpression[ "(?m)^" <> prefix <> "(.*)$" ] :> "$1", 1 ], { { v_String } :> v, _ -> None }, { 1 } ]
    ];
    flag = Function[ prefix, StringContainsQ[ headers, RegularExpression[ "(?m)^" <> prefix ] ] ];
    MapThread[
        gitPatchChunk,
        {
            headers,
            hunks,
            field[ "rename from " ],
            field[ "rename to " ],
            field[ "copy from " ],
            field[ "copy to " ],
            field[ "--- " ],
            field[ "\\+\\+\\+ " ],
            field[ "old mode " ],
            field[ "new mode " ],
            field[ "new file mode " ],
            field[ "deleted file mode " ],
            field[ "index \\S+ (?=[0-7]+$)" ],
            field[ "similarity index " ],
            flag[ "Binary files " ]
        }
    ]
];

gitPatchChunks // endDefinition;


gitPatchChunk // beginDefinition;

gitPatchChunk[
    header_String, hunks_, renameFrom_, renameTo_, copyFrom_, copyTo_, minus_, plus_, oldMode_, newMode_, newFileMode_,
    deletedFileMode_, indexMode_, similarity_, binary_
] := Module[ { from, to, headerPaths, chunk },
    from = Replace[ renameFrom, None -> copyFrom ];
    to   = Replace[ renameTo, None -> copyTo ];
    (* Only needed without rename/copy lines and without ---/+++ lines (e.g. binary files and mode changes): *)
    headerPaths := headerPaths = gitDiffHeaderPaths @ StringDrop[ First @ StringSplit[ header, "\n", 2 ], 11 ];
    chunk = <|
        "OldPath"     -> Which[
            StringQ @ from , acpGitUnquotePath @ from,
            StringQ @ minus, gitPatchFilePath[ minus, "a/" ],
            True           , First @ headerPaths
        ],
        "NewPath"     -> Which[
            StringQ @ to   , acpGitUnquotePath @ to,
            StringQ @ plus , gitPatchFilePath[ plus, "b/" ],
            True           , Last @ headerPaths
        ],
        "Header"      -> header,
        "Hunks"       -> hunks,
        "Binary"      -> TrueQ @ binary,
        "NewFile"     -> StringQ @ newFileMode,
        "DeletedFile" -> StringQ @ deletedFileMode,
        "Rename"      -> StringQ @ renameFrom,
        "Copy"        -> StringQ @ copyFrom,
        "Similarity"  -> Replace[ similarity, { s_String /; StringMatchQ[ s, DigitCharacter.. ~~ "%" ] :> ToExpression @ StringDrop[ s, -1 ], _ -> None } ],
        "OldMode"     -> FirstCase[ { oldMode, deletedFileMode, indexMode }, _String, None ],
        "NewMode"     -> FirstCase[ { newMode, newFileMode, indexMode }, _String, None ]
    |>;
    chunk[ "Submodule" ] = chunk[ "OldMode" ] === "160000" || chunk[ "NewMode" ] === "160000";
    (* Deleted files have no new path, new files no old path: *)
    If[ chunk[ "NewFile" ]    , chunk[ "OldPath" ] = None ];
    If[ chunk[ "DeletedFile" ], chunk[ "NewPath" ] = None ];
    chunk
];

gitPatchChunk // endDefinition;


(* Without trailing newlines *)
gitTrimNewlines // beginDefinition;

gitTrimNewlines[ text_String ] := Module[ { k = StringLength @ text },
    While[ k > 0 && StringTake[ text, { k } ] === "\n", k-- ];
    StringTake[ text, k ]
];

gitTrimNewlines // endDefinition;


(* "a/path", "a/path<TAB>" (git adds a tab after names with spaces), "\"a/...\"" or "/dev/null" *)
gitPatchFilePath // beginDefinition;

gitPatchFilePath[ "/dev/null", _ ] := None;

gitPatchFilePath[ s_String, prefix_String ] := gitStripPrefix[
    If[ StringStartsQ[ s, "\"" ], acpGitUnquotePath @ s, StringDelete[ s, "\t" ~~ EndOfString ] ],
    prefix
];

gitPatchFilePath // endDefinition;


gitStripPrefix // beginDefinition;
gitStripPrefix[ s_String, prefix_String ] := If[ StringStartsQ[ s, prefix ], StringDrop[ s, StringLength @ prefix ], s ];
gitStripPrefix[ _, _ ] := None;
gitStripPrefix // endDefinition;


(* The two paths of a "diff --git " line: { old, new }, each quoted or not. Unquoted paths are ambiguous when they
   contain " b/"; when both are the same (everything but renames and copies, which have their own lines), the line is
   "a/P b/P" and is split in the middle. *)
gitDiffHeaderPaths // beginDefinition;

gitDiffHeaderPaths[ rest_String ] := Module[ { pair },
    pair = Which[
        StringStartsQ[ rest, "\"" ],
            First[
                StringCases[ rest, RegularExpression[ "(?s)^(\"(?:[^\"\\\\]|\\\\.)*\") (.*)$" ] :> { "$1", "$2" }, 1 ],
                { rest, None }
            ],
        StringEndsQ[ rest, "\"" ],
            First[
                StringCases[ rest, RegularExpression[ "(?s)^(.*?) (\"(?:[^\"\\\\]|\\\\.)*\")$" ] :> { "$1", "$2" }, 1 ],
                { rest, None }
            ],
        True,
            gitSplitUnquotedPair @ rest
    ];
    {
        gitStripPrefix[ Replace[ pair[[ 1 ]], s_String :> acpGitUnquotePath @ s ], "a/" ],
        gitStripPrefix[ Replace[ pair[[ 2 ]], s_String :> acpGitUnquotePath @ s ], "b/" ]
    }
];

gitDiffHeaderPaths // endDefinition;


gitSplitUnquotedPair // beginDefinition;

gitSplitUnquotedPair[ rest_String ] := Module[ { len, p, positions },
    len = StringLength @ rest;
    If[ OddQ @ len && len >= 7,
        p = StringTake[ rest, { 3, 2 + (len - 5) / 2 } ];
        If[ rest === "a/" <> p <> " b/" <> p, Return[ { "a/" <> p, "b/" <> p }, Module ] ]
    ];
    positions = StringPosition[ rest, " b/" ];
    If[ Length @ positions === 1,
        { StringTake[ rest, positions[[ 1, 1 ]] - 1 ], StringDrop[ rest, positions[[ 1, 1 ]] ] },
        { None, None }
    ]
];

gitSplitUnquotedPair // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Change Sets*)

(* A change set describes the uncommitted changes of a project directory (everything that differs from HEAD: staged
   and unstaged changes of tracked files, as one diff against HEAD, plus untracked files that are not ignored),
   restricted to the project directory:
     "Token"          -> the request token (None for change sets built by acpGitBuildChangeSet)
     "Directory"      -> the project directory
     "Status"         -> "Changes" | "Clean" | "Unavailable" (no usable git) | "NotRepository" | "Error" |
                         "NoDirectory" (a window without a project directory)
     "Error"          -> None | <| "Code", "Step", "ExitCode", "Detail" (end of git's standard error, or None) |>
                         Codes: "NotFound", "Disabled", "GitTooOld", "InvalidSSHSettings" (with "Unavailable");
                         "StartFailed", "GitFailed", "TimedOut", "TooLarge", "Cancelled", "Superseded" (a newer request
                         replaced it), "UnsafeConfig" (a filter driver that can't be turned off; "Detail" names it),
                         "SSHFailed" (ssh, the sign-in or the remote login shell failed), "RemoteFailed" (the remote
                         script could not run, e.g. no temporary folder) (with "Error"). Errors of remote requests may
                         also have "SSHCode" (the kind of the ssh error, e.g. "SSHAuthFailed") and "Error" (its error
                         info, see acpErrorInfo: "Message", "Hint", "Output", "Detail", ...)
     "Git", "GitVersion" -> the executable and its version ("2.53.0"), or None
     "Root", "Prefix", "ObjectFormat" -> the repository root, the project directory relative to it ("" or "dir/"),
                         "sha1" | "sha256"
     "Branch", "Detached", "Initial", "OID" -> the current branch (None if detached), whether HEAD is detached,
                         whether there are no commits yet, the HEAD commit (None without commits)
     "Files"          -> { file... }, in natural path order (see gitListedEntries), at most $acpGitMaxFiles
     "FileCount"      -> the number of changed files; "MoreFiles" -> how many of them are not in "Files"
     "Added", "Deleted" -> line counts of all changed tracked text files plus the untracked text files that were read
     "Mode"           -> "Full" (with patches and untracked contents) | "Summary"
     "PatchComplete"  -> False if git's patch was cut short (too large, timed out or failed)
     "CountsComplete" -> False if the line counts could not be determined
     "CheckedAt", "Duration" -> AbsoluteTime when the change set was made, and how long it took (seconds)
     "Remote"         -> None (a local folder) | <| "Host" (user@machine), "Short" (the short host name), "Home" (the
                         remote home folder, or None) |> for a folder on another computer (paths are POSIX paths there)
   Files:
     "Path"           -> path relative to the project directory, "/"-separated ("dir/" for untracked directories)
     "RepoPath"       -> path relative to the repository root
     "FullPath"       -> the absolute file name
     "OrigPath", "OrigRepoPath" -> the original path of renamed and copied files, or None
     "Status"         -> "Modified" | "Added" | "Deleted" | "Renamed" | "Copied" | "TypeChanged" | "Conflict" |
                         "Untracked" | "Submodule"
     "XY"             -> git's two status letters ("M.", ".M", "R.", "UU", "??", ...; "" for files only in the patch)
     "Added", "Deleted" -> line counts, or None (binary files, submodules, unread untracked files)
     "Binary", "Directory" -> True for binary files and for untracked directories (e.g. nested repositories)
     "Header"         -> git's extended header lines ("diff --git", "index", modes, renames) or None
     "Patch"          -> the hunks of the diff against HEAD (from the first "@@" line) or None
     "Content"        -> the text of an untracked text file (full change sets), or None
     "OldMode", "NewMode" -> file modes ("100644", "100755", "120000", "160000") from the patch, or None
     "LinkTarget"     -> for an untracked symbolic link, the absolute path it resolves to (None if it does not)
     "Remote"         -> True for the files of a remote folder (they are not on this computer)
     "Note"           -> None | "Binary" | "ModeChanged" (only the mode changed) | "Renamed" (renamed or copied
                         without changes) | "Empty" (an empty new or deleted file) | "Submodule" | "Directory" |
                         "TooLarge" (untracked file over the size cap) | "NotRead" (the read budget was used up) |
                         "SymbolicLink" (an untracked symbolic link, counted as one added line, like git) |
                         "NotRegular" (an untracked special file) | "Unreadable" | "NoDiff" (git shows no difference)
                         | "PatchUnavailable" (git's patch was cut short before this file)
   Statuses are relative to HEAD: files that were added to the index and then deleted are not listed, and a file that
   was renamed in the index and then deleted is its original path, deleted. git status and the diff can see renames
   differently (status compares HEAD with the index, the diff HEAD with the working tree): renames that only the diff
   finds are paired (gitPairRenames), and the counts of renames that only status finds include the original file
   (gitEntryNumstat).
   Change sets are made by acpGitChanges (and the summary checks) and by acpGitBuildChangeSet, which builds one from git
   output (e.g. for tests). *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitChanges*)

(* acpGitChanges[target, continuation] collects the uncommitted changes of a project directory: a full change set,
   with per-file patches and the contents of untracked files. continuation[changes] is evaluated (isolated) in the pump
   when it is ready (always exactly once). target is a directory, or an ACP window: then its project directory is used
   and the window's git summary is updated from the result too (an explicit check, which supersedes a running one).
   acpGitChanges[dir, continuation, key]: a request for a directory that supersedes the running request with the same
   key (any expression that identifies the requester, e.g. its window); the full requests of an ACP window supersede
   each other. A superseded request stops at its next step (its running git command is killed) and its continuation
   gets a change set with the error "Superseded". Gives the request token (changes["Token"]): compare it to ignore the
   results of superseded requests. The request is only queued here, so this is safe anywhere (git is started by the
   pump). acpGitChanges[dir, continuation, key, ssh]: a folder on another computer ("SSHSettings", canonical or not;
   None: this computer), e.g. for a review window without its ACP window. A remote folder is used as it is (never
   ExpandFileName, which would make a Windows path of it); invalid settings give an "Unavailable" change set. *)
acpGitChanges // beginDefinition;

acpGitChanges[ File[ dir_String ], args___ ] := acpGitChanges[ dir, args ];

acpGitChanges[ dir_String, continuation_ ] := acpGitChanges[ dir, continuation, None ];

acpGitChanges[ dir_String, continuation_, key_ ] := acpGitChanges[ dir, continuation, key, None ];

acpGitChanges[ dir_String, continuation_, key_, ssh0_ ] := With[ { token = gitNewToken[ ], ssh = gitRequestSSH @ ssh0 },
    gitQueueRequest @ gitNewRequest[
        token,
        If[ ssh === None, Quiet @ ExpandFileName @ dir, dir ],
        "Full",
        None,
        continuation,
        key,
        ssh
    ];
    token
];

acpGitChanges[ nbo_NotebookObject, continuation_ ] := Replace[
    gitStartWindowRequest[ nbo, "Full", continuation ],
    None :> With[ { token = gitNewToken[ ] },
        (* No window record or no project directory: *)
        With[ { changes = gitEmptyChangeSet[ gitNewRequest[ token, None, "Full", None, None, None ], "NoDirectory", None ] },
            acpSchedule @ gitCallContinuation[ continuation, changes ]
        ];
        token
    ]
];

acpGitChanges // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Requests*)

(* A request runs these steps one after the other (each git command's continuation starts the next step):
     checks without processes (directory, git executable, .git hint) -> version (once per executable and session) ->
     repository information (rev-parse, once per directory and .git hint) -> filter drivers (config) -> status ->
     line counts (diff --numstat, if tracked files changed) -> patch (full change sets) -> untracked files (read by
   the kernel) -> change set. The state is an association: "Token", "Directory", "Mode" ("Summary" | "Full"), "Owner",
   "Continuation", "Key" (None, or the requester: a newer request with the same key supersedes this one), "StartedAt",
   "Remote" (None, or the canonical "SSHSettings" of a folder on another computer, or their Failure) and what the steps
   found. Every path ends in gitFinish, which calls the continuation. *)
gitNewToken // beginDefinition;
gitNewToken[ ] := "git-" <> ToString[ ++$gitRequestCount ];
gitNewToken // endDefinition;


gitNewRequest // beginDefinition;

gitNewRequest[ token_, dir_, mode_, owner_, continuation_, key_ ] := gitNewRequest[ token, dir, mode, owner, continuation, key, None ];

gitNewRequest[ token_, dir_, mode_, owner_, continuation_, key_, remote_ ] := <|
    "Token"        -> token,
    "Directory"    -> dir,
    "Mode"         -> mode,
    "Owner"        -> owner,
    "Continuation" -> continuation,
    "Key"          -> key,
    "StartedAt"    -> AbsoluteTime[ ],
    "Remote"       -> remote
|>;

gitNewRequest // endDefinition;


(* The "Remote" of a request for "SSHSettings" (canonical or not): None (this computer), the canonical settings, or
   their Failure (never treated as local) *)
gitRequestSSH // beginDefinition;
gitRequestSSH[ None | Automatic | Inherited | $Failed | _Missing ] := None;
gitRequestSSH[ ssh_ ] := acpSSHSettings @ ssh;
gitRequestSSH // endDefinition;


gitRemoteQ // beginDefinition;
gitRemoteQ[ state_Association ] := AssociationQ @ Lookup[ state, "Remote", None ];
gitRemoteQ[ _ ] := False;
gitRemoteQ // endDefinition;


(* Queues the request; it becomes the latest request of its key *)
gitQueueRequest // beginDefinition;

gitQueueRequest[ state_Association ] := (
    If[ state[ "Key" ] =!= None, With[ { key = state[ "Key" ] }, PreemptProtect[ $gitCurrentRequests[ key ] = state[ "Token" ] ] ] ];
    acpSchedule @ gitRequest @ state;
    Null
);

gitQueueRequest // endDefinition;


(* True if a newer request with the same key was queued. Also for { key, token } (runs of commands). *)
gitSupersededQ // beginDefinition;
gitSupersededQ[ state_Association ] := gitSupersededQ @ { Lookup[ state, "Key", None ], Lookup[ state, "Token", None ] };
gitSupersededQ[ { None, _ } ] := False;
gitSupersededQ[ { key_, token_ } ] := Lookup[ $gitCurrentRequests, Key @ key, None ] =!= token;
gitSupersededQ[ _ ] := False;
gitSupersededQ // endDefinition;


(* Continues a request that is still the latest of its key; otherwise ends it ("Superseded") and gives False *)
gitCurrentQ // beginDefinition;

gitCurrentQ[ state_Association ] := If[ gitSupersededQ @ state,
    gitFinish[ state, "Error", <| "Code" -> "Superseded", "Step" -> None, "ExitCode" -> None, "Detail" -> None |> ];
    False,
    True
];

gitCurrentQ // endDefinition;


gitRequest // beginDefinition;

gitRequest[ state_Association ] := Module[ { dir, git, hint },
    If[ ! gitCurrentQ @ state, Return[ Null, Module ] ];
    dir = state[ "Directory" ];
    If[ ! TrueQ @ $acpGitEnabled, Return[ gitFinish[ state, "Unavailable", gitError[ "Disabled", None, None ] ], Module ] ];
    (* A folder on another computer: no local checks, one remote script (see "Remote") *)
    If[ FailureQ @ Lookup[ state, "Remote", None ], Return[ gitFinish[ state, "Unavailable", gitInvalidSettingsError @ state[ "Remote" ] ], Module ] ];
    If[ gitRemoteQ @ state, Return[ gitRemoteRequest @ state, Module ] ];
    If[ ! StringQ @ dir || ! TrueQ @ Quiet @ DirectoryQ @ dir, Return[ gitFinish[ state, "NotRepository", None ], Module ] ];
    git = acpFindGit[ ];
    If[ ! StringQ @ git, Return[ gitFinish[ state, "Unavailable", gitError[ "NotFound", None, None ] ], Module ] ];
    hint = acpGitWorkTreeRoot @ dir;
    If[ hint === None, Return[ gitFinish[ state, "NotRepository", None ], Module ] ];
    gitStepVersion @ <| state, "Git" -> git, "Hint" -> hint |>
];

gitRequest // endDefinition;


(* Runs a git command of a request; next[state, result] continues (unless the request was superseded meanwhile). step
   names the command ("Version", "Repository", "Config", "Status", "Numstat", "Patch"): a remote request takes its
   result from the frame of the remote script that ran it (gitRemoteStepResult), in the next pump tick. *)
gitRunStep // beginDefinition;

gitRunStep[ state_Association, step_String, args_List, next_ ] := With[ { s = state },
    Which[
        ! gitCurrentQ @ state,
            Null,
        gitRemoteQ @ state,
            With[ { result = gitRemoteStepResult[ state, step, args ] }, acpSchedule[ If[ gitCurrentQ @ s, next[ s, result ] ] ] ],
        True,
            acpGitRun[
                args,
                state[ "Directory" ],
                Function[ result, If[ gitCurrentQ @ s, next[ s, result ] ] ],
                <|
                    "Timeout" -> If[ state[ "Mode" ] === "Full", $gitTimeout, $gitSummaryTimeout ],
                    "Owner"   -> state[ "Owner" ],
                    "Request" -> Lookup[ state, { "Key", "Token" } ],
                    "Git"     -> state[ "Git" ]
                |>
            ]
    ]
];

gitRunStep // endDefinition;


(* True if a command succeeded (its exit code is one of codes); otherwise the request is finished with an error (or as
   "NotRepository", if git says so) and the result is False. *)
gitStepOKQ // beginDefinition;

gitStepOKQ[ state_, result_Association, step_String, codes_List ] := Which[
    TrueQ @ result[ "Cancelled" ]          , gitFinish[ state, "Error", gitError[ "Cancelled", step, result ] ]; False,
    TrueQ @ result[ "StartFailed" ]        , gitFinish[ state, "Error", gitError[ "StartFailed", step, result ] ]; False,
    TrueQ @ result[ "TimedOut" ]           , gitFinish[ state, "Error", gitError[ "TimedOut", step, result ] ]; False,
    TrueQ @ result[ "TooLarge" ]           , gitFinish[ state, "Error", gitError[ "TooLarge", step, result ] ]; False,
    MemberQ[ codes, result[ "ExitCode" ] ] , True,
    notRepositoryErrorQ @ result[ "Error" ], gitFinish[ state, "NotRepository", None ]; False,
    True                                   , gitFinish[ state, "Error", gitError[ "GitFailed", step, result ] ]; False
];

gitStepOKQ // endDefinition;


notRepositoryErrorQ // beginDefinition;
notRepositoryErrorQ[ s_String ] := StringContainsQ[ s, "not a git repository" | "must be run in a work tree", IgnoreCase -> True ];
notRepositoryErrorQ[ _ ] := False;
notRepositoryErrorQ // endDefinition;


gitError // beginDefinition;

gitError[ code_String, step_, result_ ] := <|
    "Code"     -> code,
    "Step"     -> step,
    "ExitCode" -> If[ AssociationQ @ result, Lookup[ result, "ExitCode", None ], None ],
    "Detail"   -> If[ AssociationQ @ result, gitErrorDetail @ Lookup[ result, "Error", "" ], None ]
|>;

gitError // endDefinition;


(* The end of git's standard error *)
gitErrorDetail // beginDefinition;

gitErrorDetail[ s_String ] := Module[ { lines, tail },
    lines = StringSplit[ StringTrim @ s, "\n" ];
    tail  = StringTrim @ StringRiffle[ Take[ lines, -Min[ Length @ lines, $gitErrorDetailLines ] ], "\n" ];
    Which[
        tail === "", None,
        StringLength @ tail > $gitErrorDetailLength, "\[Ellipsis]" <> StringTake[ tail, -$gitErrorDetailLength ],
        True, tail
    ]
];

gitErrorDetail[ _ ] := None;

gitErrorDetail // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Steps*)

(* git --version runs without the global options of gitCommand: it does not look at the repository, and a git that is
   too old to know them (--no-optional-locks is from 2.15) is then reported as too old instead of failing. The version
   of a remote git is not cached: the same path can be another git on another computer. *)
gitStepVersion // beginDefinition;

gitStepVersion[ state_Association ] := With[
    { version = If[ gitRemoteQ @ state, None, Lookup[ $gitVersions, state[ "Git" ], None ] ] },
    If[ ListQ @ version,
        gitCheckVersion[ state, version ],
        gitRunStep[ state, "Version", { "--version" }, gitStepVersion ]
    ]
];

gitStepVersion[ state_Association, result_Association ] := If[ gitStepOKQ[ state, result, "Version", { 0 } ],
    With[ { version = acpGitParseVersion @ result[ "Output" ] },
        If[ ListQ @ version && ! gitRemoteQ @ state, PreemptProtect[ $gitVersions[ state[ "Git" ] ] = version ] ];
        gitCheckVersion[ state, version ]
    ]
];

gitStepVersion // endDefinition;


gitCheckVersion // beginDefinition;

gitCheckVersion[ state_, version_ ] := If[ gitVersionAtLeastQ[ version, $gitMinimumVersion ],
    gitStepRepository @ <| state, "Version" -> version |>,
    gitFinish[ <| state, "Version" -> version |>, "Unavailable", gitError[ "GitTooOld", "Version", None ] ]
];

gitCheckVersion // endDefinition;


gitStepRepository // beginDefinition;

(* Remote repositories are not cached (the same path can exist on both computers) *)
gitStepRepository[ state_Association ] := With[
    { cached = If[ gitRemoteQ @ state, None, Lookup[ $gitRepositoryInfo, state[ "Directory" ], None ] ] },
    If[ AssociationQ @ cached && cached[ "Hint" ] === state[ "Hint" ],
        gitStepFilters @ <| state, "Repository" -> cached |>,
        gitRunStep[
            state,
            "Repository",
            gitCommand[ state, { "rev-parse", "--show-toplevel", "--show-prefix", "--show-object-format" } ],
            gitStepRepository
        ]
    ]
];

gitStepRepository[ state_Association, result_Association ] := If[ gitStepOKQ[ state, result, "Repository", { 0 } ],
    With[ { info = <| acpGitParseRevParse @ result[ "Output" ], "Hint" -> state[ "Hint" ] |> },
        If[ StringQ @ info[ "Root" ],
            If[ ! gitRemoteQ @ state, PreemptProtect[ $gitRepositoryInfo[ state[ "Directory" ] ] = info ] ];
            gitStepFilters @ <| state, "Repository" -> info |>,
            gitFinish[ state, "Error", gitError[ "GitFailed", "Repository", result ] ]
        ]
    ]
];

gitStepRepository // endDefinition;


(* Exit code 1: no filter drivers are configured. A driver whose name contains "=" can't be neutralized with -c (see
   gitFilterOverrides): the request fails ("UnsafeConfig") rather than letting git run it. *)
gitStepFilters // beginDefinition;

gitStepFilters[ state_Association ] :=
    gitRunStep[ state, "Config", gitCommand[ state, { "config", "-z", "--get-regexp", "^filter\\." } ], gitStepFilters ];

gitStepFilters[ state_Association, result_Association ] := If[ gitStepOKQ[ state, result, "Config", { 0, 1 } ],
    With[ { names = acpGitParseFilterDrivers @ result[ "Output" ] },
        With[ { unsafe = Select[ names, StringContainsQ[ "=" ] ] },
            If[ unsafe === { },
                gitStepStatus @ <| state, "Filters" -> names |>,
                gitFinish[
                    state,
                    "Error",
                    <| "Code" -> "UnsafeConfig", "Step" -> "Config", "ExitCode" -> None, "Detail" -> StringRiffle[ "filter." <> # & /@ unsafe, "\n" ] |>
                ]
            ]
        ]
    ]
];

gitStepFilters // endDefinition;


gitStepStatus // beginDefinition;

gitStepStatus[ state_Association ] := gitRunStep[ state, "Status", gitCommand[ state, $gitStatusArguments ], gitStepStatus ];

gitStepStatus[ state_Association, result_Association ] := If[ gitStepOKQ[ state, result, "Status", { 0 } ],
    gitStepNumstat @ <| state, "Status" -> gitStatusData @ result[ "Output" ] |>
];

gitStepStatus // endDefinition;


(* Line counts of tracked files. If they cannot be determined, the change set is still made (without counts). *)
gitStepNumstat // beginDefinition;

gitStepNumstat[ state_Association ] := If[ gitTrackedChangesQ @ state,
    gitRunStep[
        state,
        "Numstat",
        gitCommand[ state, Join[ { "diff", gitBase @ state, "--numstat", "-z" }, $gitDiffOptions, { "--", "." } ] ],
        gitStepNumstat
    ],
    gitStepPatch @ <| state, "Numstat" -> { }, "CountsComplete" -> True |>
];

gitStepNumstat[ state_Association, result_Association ] := Which[
    TrueQ @ result[ "Cancelled" ],
        gitFinish[ state, "Error", gitError[ "Cancelled", "Numstat", result ] ],
    result[ "ExitCode" ] === 0 && ! TrueQ @ result[ "TooLarge" ],
        gitStepPatch @ <| state, "Numstat" -> gitNumstatData @ result[ "Output" ], "CountsComplete" -> True |>,
    True,
        acpLog[ "GitCountsFailed", gitError[ "GitFailed", "Numstat", result ] ];
        gitStepPatch @ <| state, "Numstat" -> { }, "CountsComplete" -> False |>
];

gitStepNumstat // endDefinition;


(* Full change sets only. A patch that was cut short (too large, timed out) keeps its complete chunks. The chunks are
   parsed by gitStepSplit, the untracked files read and the change set built in later pump ticks, so that no single
   evaluation of the pump takes long. *)
gitStepPatch // beginDefinition;

gitStepPatch[ state_Association ] := Which[
    state[ "Mode" ] =!= "Full",
        With[ { s = <| state, "Patch" -> None, "PatchComplete" -> True |> }, acpSchedule @ gitStepUntracked @ s ],
    gitTrackedChangesQ @ state,
        gitRunStep[
            state,
            "Patch",
            gitCommand[ state, Join[ { "diff", gitBase @ state }, $gitDiffOptions, $gitPatchOptions, { "--", "." } ] ],
            gitStepPatch
        ],
    True,
        With[ { s = <| state, "Patch" -> { }, "PatchComplete" -> True |> }, acpSchedule @ gitStepUntracked @ s ]
];

gitStepPatch[ state_Association, result_Association ] := Module[ { complete, texts },
    If[ TrueQ @ result[ "Cancelled" ], Return[ gitFinish[ state, "Error", gitError[ "Cancelled", "Patch", result ] ], Module ] ];
    complete = result[ "ExitCode" ] === 0 && ! TrueQ @ result[ "TooLarge" ];
    texts    = Which[
        complete, gitPatchTexts @ result[ "Output" ],
        TrueQ @ result[ "TooLarge" ] || TrueQ @ result[ "TimedOut" ], Replace[ gitPatchTexts @ result[ "Output" ], l: { __ } :> Most @ l ],
        True, { }
    ];
    If[ ! complete, acpLog[ "GitPatchIncomplete", gitError[ "GitFailed", "Patch", result ] ] ];
    With[ { s = <| state, "PatchTexts" -> texts, "Patch" -> { }, "PatchComplete" -> complete |> }, acpSchedule @ gitStepSplit @ s ]
];

gitStepPatch // endDefinition;


(* Parses the chunks of the patch, $gitSplitSlice per pump tick *)
gitStepSplit // beginDefinition;

gitStepSplit[ state_Association ] := Module[ { texts, n, next },
    If[ ! gitCurrentQ @ state, Return[ Null, Module ] ];
    texts = state[ "PatchTexts" ];
    n     = Min[ Length @ texts, $gitSplitSlice ];
    next  = <| state, "Patch" -> Join[ state[ "Patch" ], gitPatchChunks @ Take[ texts, n ] ], "PatchTexts" -> Drop[ texts, n ] |>;
    If[ next[ "PatchTexts" ] === { },
        With[ { s = KeyDrop[ next, "PatchTexts" ] }, acpSchedule @ gitStepUntracked @ s ],
        With[ { s = next }, acpSchedule @ gitStepSplit @ s ]
    ]
];

gitStepSplit // endDefinition;


(* The untracked files that will be listed are read by the kernel (counts, binary check, contents), within the budget.
   A remote script read them on the remote machine: its records give the same information (gitRemoteUntracked); a run
   that ended before its records (e.g. it timed out) ends the request with the run's error. *)
gitStepUntracked // beginDefinition;

gitStepUntracked[ state_Association ] := Module[ { repository, listed, paths, untracked },
    If[ ! gitCurrentQ @ state, Return[ Null, Module ] ];
    If[ gitRemoteQ @ state && ! KeyExistsQ[ Lookup[ state, "RemoteFrames", <| |> ], $gitRemoteFrames[ "Untracked" ] ],
        (* the exit codes { } are never met: this always ends the request with an error *)
        Return[ gitStepOKQ[ state, gitRemoteStepResult[ state, "Untracked", { } ], "Untracked", { } ], Module ]
    ];
    repository = state[ "Repository" ];
    listed     = gitListedEntries[ state[ "Status" ], { } ];
    paths      = Lookup[ Select[ listed, #[ "Status" ] === "Untracked" && ! #[ "Directory" ] & ], "Path", { } ];
    untracked  = If[ gitRemoteQ @ state,
        gitRemoteUntracked[ state, paths ],
        gitReadUntracked[
            repository[ "Root" ],
            paths,
            $gitUntrackedBudget,
            state[ "Mode" ] === "Full"
        ]
    ];
    (* The change set is built in the next tick (the frames of a remote script are no longer needed): *)
    With[ { s = <| KeyDrop[ state, "RemoteFrames" ], "Untracked" -> untracked |> },
        acpSchedule[ If[ gitCurrentQ @ s, gitFinish[ s, Automatic, None ] ] ]
    ]
];

gitStepUntracked // endDefinition;


gitTrackedChangesQ // beginDefinition;
gitTrackedChangesQ[ state_Association ] := state[ "Status" ][ "Tracked" ] =!= { };
gitTrackedChangesQ // endDefinition;


(* HEAD, or the empty tree in a repository without commits *)
gitBase // beginDefinition;

gitBase[ state_Association ] := If[ TrueQ @ state[ "Status" ][ "Branch" ][ "Initial" ],
    Lookup[ $gitEmptyTrees, Lookup[ state[ "Repository" ], "ObjectFormat", "sha1" ], $gitEmptyTrees[ "sha1" ] ],
    "HEAD"
];

gitBase // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Untracked Files*)

(* <| repoPath -> <| "Added", "Binary", "Content", "Note", "Bytes", "LinkTarget" |> |>. Only regular files are read:
   never devices or pipes, which could block the kernel. Files over $gitMaxUntrackedFileSize are not read ("TooLarge");
   once budget bytes have been read, the remaining files are not read ("NotRead"). Symbolic links are never followed:
   git would add the link itself (one line, the target path), not the file it points to, which can be anywhere (note
   "SymbolicLink", with the resolved target, or None if it does not exist). *)
gitReadUntracked // beginDefinition;

gitReadUntracked[ root_String, paths_List, budget0_Integer, keepContent_ ] := Module[ { budget = budget0, result = <| |>, info },
    Do[
        info = gitUntrackedFileInfo[ gitFullPath[ root, path ], budget, keepContent ];
        budget -= info[ "Bytes" ];
        result[ path ] = info,
        { path, paths }
    ];
    result
];

gitReadUntracked[ _, _, _, _ ] := <| |>;

gitReadUntracked // endDefinition;


gitUntrackedFileInfo // beginDefinition;

gitUntrackedFileInfo[ file_String, budget_Integer, keepContent_ ] := Module[ { link, size, bytes, text },
    link = gitSymbolicLink @ file;
    If[ ListQ @ link, Return[ <| untrackedInfo[ 1, "SymbolicLink", 0 ], "LinkTarget" -> First @ link |>, Module ] ];
    Switch[ Quiet @ FileType @ file,
        File, Null,
        (* gone since git listed it, or a name that was changed when it was decoded (see acpGitDecode): *)
        None, Return[ untrackedInfo[ None, "Unreadable", 0 ], Module ],
        _   , Return[ untrackedInfo[ None, "NotRegular", 0 ], Module ]
    ];
    size = Quiet @ FileByteCount @ file;
    Which[
        ! IntegerQ @ size                , Return[ untrackedInfo[ None, "Unreadable", 0 ], Module ],
        size > $gitMaxUntrackedFileSize  , Return[ untrackedInfo[ None, "TooLarge", 0 ], Module ],
        size > budget                    , Return[ untrackedInfo[ None, "NotRead", 0 ], Module ],
        size === 0                       , Return[ <| untrackedInfo[ 0, "Empty", 0 ], "Content" -> If[ TrueQ @ keepContent, "", None ] |>, Module ]
    ];
    bytes = gitReadBytes[ file, size ];
    Which[
        ! ByteArrayQ @ bytes,
            untrackedInfo[ None, "Unreadable", 0 ],
        MemberQ[ Normal @ bytes[[ 1 ;; Min[ Length @ bytes, $gitBinaryCheckBytes ] ]], 0 ],
            <| untrackedInfo[ None, "Binary", Length @ bytes ], "Binary" -> True |>,
        True,
            text = acpGitDecode @ bytes;
            <|
                untrackedInfo[ gitLineCount @ text, None, Length @ bytes ],
                "Content" -> If[ TrueQ @ keepContent, text, None ]
            |>
    ]
];

gitUntrackedFileInfo // endDefinition;


untrackedInfo // beginDefinition;

untrackedInfo[ added_, note_, bytes_Integer ] := <|
    "Added"      -> added,
    "Binary"     -> False,
    "Content"    -> None,
    "Note"       -> note,
    "Bytes"      -> bytes,
    "LinkTarget" -> None
|>;

untrackedInfo // endDefinition;


(* { target } if file is a symbolic link (target: the absolute path it resolves to, or None if it does not resolve),
   otherwise None. FileType and AbsoluteFileName follow links, so a link is a file whose resolved path differs from
   its resolved folder joined with its name; one that does not resolve is listed in its folder but has no type. *)
gitSymbolicLink // beginDefinition;

gitSymbolicLink[ file_String ] := Module[ { name, folder, resolved },
    name   = FileNameTake @ file;
    folder = Quiet @ AbsoluteFileName @ DirectoryName @ file;
    If[ ! StringQ @ folder, Return[ None, Module ] ];
    If[ Quiet @ FileType @ file === None,
        Return[ If[ MemberQ[ FileNameTake /@ Quiet @ FileNames[ name, folder ], name ], { None }, None ], Module ]
    ];
    resolved = Quiet @ AbsoluteFileName @ file;
    Which[
        ! StringQ @ resolved                                        , None,
        gitSamePathQ[ resolved, FileNameJoin @ { folder, name } ], None,
        True                                                        , { resolved }
    ]
];

gitSymbolicLink[ _ ] := None;

gitSymbolicLink // endDefinition;


(* The same path, also if the file system gives names in another Unicode normalization form (e.g. HFS+) *)
gitSamePathQ // beginDefinition;
gitSamePathQ[ a_String, b_String ] := a === b || CharacterNormalize[ gitTrimSeparator @ a, "NFC" ] === CharacterNormalize[ gitTrimSeparator @ b, "NFC" ];
gitSamePathQ // endDefinition;


(* At most n bytes, with a stream of our own (ReadByteArray[file, n] would reuse an open stream of the file) *)
gitReadBytes // beginDefinition;

gitReadBytes[ file_String, n_Integer ] := Module[ { stream },
    stream = Quiet @ OpenRead[ file, BinaryFormat -> True ];
    If[ ! MatchQ[ stream, _InputStream ], Return[ $Failed, Module ] ];
    WithCleanup[ Quiet @ ReadByteArray[ stream, n ], Quiet @ Close @ stream ]
];

gitReadBytes // endDefinition;


gitLineCount // beginDefinition;
gitLineCount[ "" ] := 0;
gitLineCount[ text_String ] := StringCount[ text, "\n" ] + If[ StringEndsQ[ text, "\n" ], 0, 1 ];
gitLineCount // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Remote*)

(* A request for a folder on another computer runs one script there (Assets/RemoteScripts/git.sh after the prelude of
   Remote.wl) over one ssh connection (acpRemoteRun). The script mirrors the local steps: it finds git as acpFindGit
   does, runs the same git commands with the same options (the filter drivers neutralized, read-only), reads the
   untracked files in batched passes, and gives one frame per command (see $gitRemoteFrames), the untracked records and,
   for full change sets, the text of each untracked text file (frame c<index>). The steps above then replay the frames
   (gitRunStep, gitStepUntracked), so a remote change set is made by the same code as a local one. Remote output is
   bounded: at most $acpGitMaxFiles untracked records are used, numbers are read with FromDigits after a digits check,
   and all text is decoded with acpGitDecode (which neutralizes the front end's linear syntax). Summary checks are
   "Automatic" runs (refused without a connection while the host is latched after a failed sign-in, see Remote.wl); full
   change sets come from the Review window, a user action, and clear the latch. *)

(* The frame of each step *)
$gitRemoteFrames = <|
    "Version"    -> "version",
    "Repository" -> "revparse",
    "Config"     -> "config",
    "Status"     -> "status",
    "Numstat"    -> "numstat",
    "Patch"      -> "patch",
    "Untracked"  -> "untracked"
|>;

(* The kinds of the untracked records *)
$gitRemoteKinds = <|
    "missing"    -> "Unreadable",
    "unreadable" -> "Unreadable",
    "other"      -> "NotRegular",
    "toolarge"   -> "TooLarge",
    "notread"    -> "NotRead"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*gitRemoteScript*)

(* The body of the remote git script for a folder (absolute, "~" or "~/...") and a mode: the template filled from this
   file's constants with one StringReplace, which never rescans what it inserted (a folder named "x@FULL@y" stays as it
   is). A Failure for a folder that can't be quoted (a NUL character). *)
gitRemoteScript // beginDefinition;

gitRemoteScript[ dir_String, mode_String ] := Module[ { word },
    word = acpRemotePathWord @ dir;
    If[ ! StringQ @ word, Return[ word, Module ] ];
    StringReplace[
        acpRemoteTemplate[ "git" ],
        Join[
            {
                "@DIR@"        -> word,
                "@FULL@"       -> If[ mode === "Full", "1", "0" ],
                "@MINMAJ@"     -> ToString @ $gitMinimumVersion[[ 1 ]],
                "@MINMIN@"     -> ToString @ $gitMinimumVersion[[ 2 ]],
                "@LAZYMAJ@"    -> ToString @ $gitNoLazyFetchVersion[[ 1 ]],
                "@LAZYMIN@"    -> ToString @ $gitNoLazyFetchVersion[[ 2 ]],
                "@SAFECONFIG@" -> acpShellWords @ Catenate[ { "-c", # } & /@ $gitSafeConfig ],
                "@STATUSARGS@" -> acpShellWords @ $gitStatusArguments,
                "@DIFFOPTS@"   -> acpShellWords @ $gitDiffOptions,
                "@PATCHOPTS@"  -> acpShellWords @ $gitPatchOptions,
                "@EMPTY1@"     -> $gitEmptyTrees[ "sha1" ],
                "@EMPTY256@"   -> $gitEmptyTrees[ "sha256" ],
                "@MAXOUT@"     -> ToString @ $gitMaxOutput,
                "@CFGCAP@"     -> ToString[ 2^20 ],
                "@MAXFILES@"   -> ToString @ $acpGitMaxFiles,
                "@MAXFILE@"    -> ToString @ $gitMaxUntrackedFileSize,
                "@BUDGET@"     -> ToString @ $gitUntrackedBudget,
                "@BINCHECK@"   -> ToString @ $gitBinaryCheckBytes,
                "@NULSAFE@"    -> If[ TrueQ @ $gitRemoteNULSafe, "1", "0" ]
            },
            gitRemoteSearchRules @ $gitRemoteSystemDirectories
        ]
    ]
];

gitRemoteScript // endDefinition;


(* The test hook $gitRemoteSystemDirectories: the folders the script searches for git after the remote PATH *)
gitRemoteSearchRules // beginDefinition;

gitRemoteSearchRules[ dirs: { ___String } ] := With[ { words = acpShellWords @ dirs },
    If[ StringQ @ words, { "$PATH /usr/bin /usr/local/bin /opt/homebrew/bin;" -> "$PATH " <> words <> ";" }, { } ]
];

gitRemoteSearchRules[ _ ] := { };

gitRemoteSearchRules // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*gitRemoteRequest*)

(* Runs the script of a remote request (in the pump, from gitRequest); gitRemoteResult continues with its result. A
   folder that is not an absolute path is not a repository (a "~/..." folder is resolved by the agent's launch first). *)
gitRemoteRequest // beginDefinition;

gitRemoteRequest[ state_Association ] := Module[ { dir, mode },
    dir  = state[ "Directory" ];
    mode = state[ "Mode" ];
    If[ ! acpRemoteAbsolutePathQ @ dir, Return[ gitFinish[ state, "NotRepository", None ], Module ] ];
    With[ { s = state },
        acpRemoteRun[
            state[ "Remote" ],
            gitRemoteScript[ dir, mode ],
            Function[ result, If[ gitCurrentQ @ s, gitRemoteResult[ s, result ] ] ],
            <|
                "Timeout"   -> If[ mode === "Full", $gitRemoteTimeout, $gitRemoteSummaryTimeout ],
                "MaxOutput" -> 3 * $gitMaxOutput + $gitUntrackedBudget + 2^22,
                "MaxFrames" -> If[ mode === "Full", $acpGitMaxFiles + 16, 16 ],
                "Automatic" -> mode =!= "Full",
                "Owner"     -> state[ "Owner" ],
                "Request"   -> Lookup[ state, { "Key", "Token" } ],
                "Label"     -> "Git"
            |>
        ]
    ];
    Null
];

gitRemoteRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*gitRemoteResult*)

(* The result of the remote script (see acpRemoteRun): a run that did not get to git ends the request (the script's stops
   nodir/norepo, nogit and tmpdir; ssh's failures; a host that is latched after a failed sign-in, like an ssh failure);
   otherwise the steps replay its frames, from the version on (also those of a run that was cut: the steps whose frames
   are missing end the request with the run's error, see gitRemoteStepResult). The remote home folder is kept only if it
   is an absolute path without control characters. *)
gitRemoteResult // beginDefinition;

gitRemoteResult[ state_Association, result_Association ] := Module[ { status, frames, stop },
    status = result[ "Status" ];
    frames = Replace[ result[ "Frames" ], Except[ _Association ] -> <| |> ];
    stop   = result[ "Stop" ];
    Which[
        status === "Cancelled",
            gitFinish[ state, "Error", gitError[ "Cancelled", None, None ] ],
        MatchQ[ status, "SSHFailed" | "Latched" ],
            gitFinish[ state, "Error", gitRemoteError[ "SSHFailed", result ] ],
        status === "NoReady",
            gitFinish[ state, "Error", gitRemoteError[ "RemoteFailed", result ] ],
        status === "StartFailed",
            gitFinish[ state, "Error", gitRemoteError[ "StartFailed", result ] ],
        stop === "tmpdir",
            gitFinish[ state, "Error", gitRemoteError[ "RemoteFailed", result ] ],
        MatchQ[ stop, "nodir" | "norepo" ],
            gitFinish[ state, "NotRepository", None ],
        stop === "nogit",
            gitFinish[ state, "Unavailable", gitError[ "NotFound", None, None ] ],
        ! KeyExistsQ[ frames, "git" ],
            gitFinish[
                state,
                "Error",
                gitRemoteError[ Switch[ status, "TimedOut" | "RemoteTimedOut", "TimedOut", "TooLarge", "TooLarge", _, "RemoteFailed" ], result ]
            ],
        True,
            gitStepVersion @ <|
                state,
                "Git"            -> acpGitDecode @ frames[ "git", "Output" ],
                "Hint"           -> None,
                "RemoteFrames"   -> frames,
                "RemoteStatus"   -> status,
                "RemoteStop"     -> stop,
                "RemoteExitCode" -> result[ "ExitCode" ],
                "RemoteError"    -> result[ "Error" ],
                "RemoteHome"     -> acpRemoteCheckedPath[ acpGitDecode @ Lookup[ Lookup[ frames, "home", <| |> ], "Output", ByteArray[ { } ] ], "Home" ]
            |>
    ]
];

gitRemoteResult // endDefinition;


(* The change set error of a remote run: its code, and the kind and error info of ssh's failure (or the remote script's),
   whose "Detail" is the advice and ssh's own text *)
gitRemoteError // beginDefinition;

gitRemoteError[ code_String, result_Association ] := With[ { error = Replace[ Lookup[ result, "Error", None ], Except[ _Association ] -> None ] },
    <|
        "Code"     -> code,
        "Step"     -> If[ code === "SSHFailed", "Connect", None ],
        "ExitCode" -> Replace[ Lookup[ result, "ExitCode", None ], Except[ _Integer ] -> None ],
        "Detail"   -> If[ AssociationQ @ error, Replace[ Lookup[ error, "Detail", None ], Except[ _String ] -> None ], None ],
        "SSHCode"  -> If[ AssociationQ @ error, Lookup[ error, "Code", None ], None ],
        "Stop"     -> Lookup[ result, "Stop", None ],
        "Error"    -> error
    |>
];

gitRemoteError // endDefinition;


(* Invalid "SSHSettings": the validation detail (it names the setting and the problem, never a secret) *)
gitInvalidSettingsError // beginDefinition;

gitInvalidSettingsError[ failure_Failure ] := <|
    "Code"     -> "InvalidSSHSettings",
    "Step"     -> None,
    "ExitCode" -> None,
    "Detail"   -> Replace[ Quiet @ failure[ "Detail" ], Except[ _String ] -> None ]
|>;

gitInvalidSettingsError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*gitRemoteStepResult*)

(* The result of a step (as acpGitRun gives it) from the frame of its command. A step whose frame is missing ends the
   request: the run timed out or its output was too large, ssh's connection was lost (git's error is then ssh's message),
   or the script stopped before it (which an honest script does only when an earlier step fails). *)
gitRemoteStepResult // beginDefinition;

gitRemoteStepResult[ state_Association, step_String, args_List ] := With[
    { frame = Lookup[ Lookup[ state, "RemoteFrames", <| |> ], Lookup[ $gitRemoteFrames, step, None ], None ] },
    If[ AssociationQ @ frame,
        <|
            "ExitCode"    -> Replace[ frame[ "ExitCode" ], Except[ _Integer ] -> None ],
            "Output"      -> acpGitDecode @ frame[ "Output" ],
            "Error"       -> acpGitDecode @ frame[ "Error" ],
            "TimedOut"    -> False,
            "TooLarge"    -> TrueQ @ frame[ "OutputTruncated" ],
            "Cancelled"   -> False,
            "StartFailed" -> False,
            "Duration"    -> 0,
            "Arguments"   -> args
        |>,
        gitRemoteMissingStep[ state, args ]
    ]
];

gitRemoteStepResult // endDefinition;


gitRemoteMissingStep // beginDefinition;

gitRemoteMissingStep[ state_Association, args_List ] := With[
    {
        base = <|
            "ExitCode"    -> None,
            "Output"      -> "",
            "Error"       -> "",
            "TimedOut"    -> False,
            "TooLarge"    -> False,
            "Cancelled"   -> False,
            "StartFailed" -> False,
            "Duration"    -> 0,
            "Arguments"   -> args
        |>
    },
    Switch[ Lookup[ state, "RemoteStatus", None ],
        "TimedOut" | "RemoteTimedOut",
            <| base, "TimedOut" -> True |>,
        "TooLarge",
            <| base, "TooLarge" -> True |>,
        "OK",
            <|
                base,
                "StartFailed" -> True,
                "Error"       -> acpLabel[ "ReviewDetailRemoteStopped", <| "stop" -> Replace[ Lookup[ state, "RemoteStop", None ], Except[ _String ] -> "end" ] |> ]
            |>,
        _,
            (* ssh's exit code (never 0: the step must not succeed) and its message *)
            <|
                base,
                "ExitCode" -> Replace[ Lookup[ state, "RemoteExitCode", None ], Except[ _Integer? (# =!= 0 &) ] -> None ],
                "Error"    -> Replace[ Lookup[ Replace[ Lookup[ state, "RemoteError", None ], Except[ _Association ] -> <| |> ], "Output", None ], Except[ _String ] -> "" ]
            |>
    ]
];

gitRemoteMissingStep // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*gitRemoteUntracked*)

(* The untracked files of a remote request (<| path -> info |> for the listed paths, as gitReadUntracked gives them),
   from the script's records "index kind size lines target path" (NUL-terminated fields, decoded like the status, so
   the paths are the status's paths) and, for full change sets, the text frames c<index>. At most $acpGitMaxFiles records
   are used (the script's own cap, enforced again here): records whose index is not in 1..$acpGitMaxFiles or repeats an
   earlier one are ignored, and so are later records of the same path. A listed path without a record was not found by
   the script, whose candidates are lines: a name with a line break ("Unreadable"); otherwise "NotRead". *)
gitRemoteUntracked // beginDefinition;

gitRemoteUntracked[ state_Association, paths_List ] := Module[ { frames, full, records, byPath },
    frames  = Lookup[ state, "RemoteFrames", <| |> ];
    full    = Lookup[ state, "Mode", None ] === "Full";
    records = gitRemoteRecords @ Lookup[ Lookup[ frames, $gitRemoteFrames[ "Untracked" ], <| |> ], "Output", ByteArray[ { } ] ];
    byPath  = If[ records === { }, <| |>, GroupBy[ records, Last, First ] ];
    AssociationMap[
        Function[ path,
            Replace[
                Lookup[ byPath, path, None ],
                {
                    record_List :> gitRemoteUntrackedInfo[ record, frames, full ],
                    _ :> untrackedInfo[ None, If[ StringContainsQ[ path, "\n" ], "Unreadable", "NotRead" ], 0 ]
                }
            ]
        ],
        paths
    ]
];

gitRemoteUntracked // endDefinition;


(* The records of the untracked frame: lists of 6 strings with a valid, new index. Only the fields of the first
   $acpGitMaxFiles records are split off, whatever the size of the frame. *)
gitRemoteRecords // beginDefinition;

gitRemoteRecords[ bytes_ByteArray ] := Module[ { text, ends, fields, seen = <| |> },
    text = acpGitDecode @ bytes;
    ends = StringPosition[ text, $gitNUL, 6 * $acpGitMaxFiles ][[ All, 1 ]];
    If[ Length @ ends < 6, Return[ { }, Module ] ];
    fields = StringTake[ text, Transpose @ { Prepend[ Most @ ends + 1, 1 ], ends - 1 } ];
    Select[
        Partition[ fields, 6 ],
        Function[ record,
            With[ { i = gitRemoteNumber @ First @ record },
                If[ IntegerQ @ i && 1 <= i <= $acpGitMaxFiles && ! KeyExistsQ[ seen, i ], seen[ i ] = True; True, False ]
            ]
        ]
    ]
];

gitRemoteRecords[ _ ] := { };

gitRemoteRecords // endDefinition;


(* A number of the remote output (at most 18 digits), or None *)
gitRemoteNumber // beginDefinition;
gitRemoteNumber[ s_String ] /; StringMatchQ[ s, RegularExpression[ "[0-9]{1,18}" ] ] := FromDigits @ s;
gitRemoteNumber[ _ ] := None;
gitRemoteNumber // endDefinition;


(* What a record says about a file, as gitUntrackedFileInfo: links are one added line (never followed), text files
   their line count (and in full change sets their text, from the frame c<index>), binary files their size *)
gitRemoteUntrackedInfo // beginDefinition;

gitRemoteUntrackedInfo[ { index_, kind_, size0_, lines0_, target_, _ }, frames_Association, full_ ] := Module[
    { size, lines, content },
    size  = gitRemoteNumber @ size0;
    lines = gitRemoteNumber @ lines0;
    Which[
        kind === "link",
            <| untrackedInfo[ 1, "SymbolicLink", 0 ], "LinkTarget" -> If[ StringQ @ target && target =!= "", target, None ] |>,
        KeyExistsQ[ $gitRemoteKinds, kind ],
            untrackedInfo[ None, $gitRemoteKinds[ kind ], 0 ],
        kind === "empty",
            <| untrackedInfo[ 0, "Empty", 0 ], "Content" -> If[ TrueQ @ full, "", None ] |>,
        kind === "binary" && IntegerQ @ size,
            <| untrackedInfo[ None, "Binary", size ], "Binary" -> True |>,
        kind === "text" && IntegerQ @ size && IntegerQ @ lines,
            content = If[ TrueQ @ full,
                Replace[ Lookup[ frames, "c" <> index, None ], { frame_Association :> acpGitDecode @ frame[ "Output" ], _ -> None } ],
                None
            ];
            <| untrackedInfo[ lines, None, size ], "Content" -> content |>,
        True,
            untrackedInfo[ None, "Unreadable", 0 ]
    ]
];

gitRemoteUntrackedInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*gitFinish*)

(* Ends a request: builds the change set (status Automatic) or an empty one with the given status and error, and calls
   the continuation. *)
gitFinish // beginDefinition;

gitFinish[ state_Association, status_, error_ ] := Module[ { changes },
    (* The request is no longer running: *)
    If[ state[ "Key" ] =!= None,
        PreemptProtect @ If[ Lookup[ $gitCurrentRequests, Key @ state[ "Key" ], None ] === state[ "Token" ],
            KeyDropFrom[ $gitCurrentRequests, { state[ "Key" ] } ]
        ]
    ];
    changes = If[ status === Automatic,
        Join[
            gitEmptyChangeSet[ state, "Clean", None ],
            KeyDrop[ acpGitBuildChangeSet @ gitChangeSetInput @ state, { "Token", "CheckedAt", "Duration" } ]
        ],
        gitEmptyChangeSet[ state, status, error ]
    ];
    gitCallContinuation[ state[ "Continuation" ], changes ]
];

gitFinish // endDefinition;


gitChangeSetInput // beginDefinition;

gitChangeSetInput[ state_Association ] := With[ { repository = state[ "Repository" ] },
    <|
        "Directory"      -> state[ "Directory" ],
        "Git"            -> state[ "Git" ],
        "GitVersion"     -> gitVersionString @ state[ "Version" ],
        "Root"           -> repository[ "Root" ],
        "Prefix"         -> repository[ "Prefix" ],
        "ObjectFormat"   -> repository[ "ObjectFormat" ],
        "Mode"           -> state[ "Mode" ],
        "Status"         -> state[ "Status" ],
        "Numstat"        -> state[ "Numstat" ],
        "CountsComplete" -> state[ "CountsComplete" ],
        "Patch"          -> state[ "Patch" ],
        "PatchComplete"  -> state[ "PatchComplete" ],
        "Untracked"      -> state[ "Untracked" ],
        "Remote"         -> gitChangeSetRemote @ state
    |>
];

gitChangeSetInput // endDefinition;


(* The change set's "Remote": None for a local folder; the host and the remote home folder (from the remote script, if
   it reported one) for a remote one; "?" for invalid settings *)
gitChangeSetRemote // beginDefinition;

gitChangeSetRemote[ state_Association ] := Replace[
    Lookup[ state, "Remote", None ],
    {
        ssh_Association :> <|
            "Host"  -> acpSSHHostLabel @ ssh,
            "Short" -> acpSSHShortHost @ ssh,
            "Home"  -> Replace[ Lookup[ state, "RemoteHome", None ], Except[ _String? acpRemoteAbsolutePathQ ] -> None ]
        |>,
        _Failure -> <| "Host" -> "?", "Short" -> "?", "Home" -> None |>,
        _ -> None
    }
];

gitChangeSetRemote // endDefinition;


(* A change set with every key, for the request's state *)
gitEmptyChangeSet // beginDefinition;

gitEmptyChangeSet[ state_Association, status_String, error_ ] := With[ { repository = Lookup[ state, "Repository", <| |> ] },
    <|
        "Token"          -> Lookup[ state, "Token", None ],
        "Directory"      -> Lookup[ state, "Directory", None ],
        "Status"         -> status,
        "Error"          -> error,
        "Git"            -> Lookup[ state, "Git", None ],
        "GitVersion"     -> gitVersionString @ Lookup[ state, "Version", None ],
        "Root"           -> Lookup[ repository, "Root", None ],
        "Prefix"         -> Lookup[ repository, "Prefix", None ],
        "ObjectFormat"   -> Lookup[ repository, "ObjectFormat", None ],
        "Branch"         -> None,
        "Detached"       -> False,
        "Initial"        -> False,
        "OID"            -> None,
        "Files"          -> { },
        "FileCount"      -> 0,
        "MoreFiles"      -> 0,
        "Added"          -> 0,
        "Deleted"        -> 0,
        "Mode"           -> Lookup[ state, "Mode", "Full" ],
        "PatchComplete"  -> True,
        "CountsComplete" -> True,
        "CheckedAt"      -> AbsoluteTime[ ],
        "Duration"       -> Replace[ AbsoluteTime[ ] - Lookup[ state, "StartedAt", AbsoluteTime[ ] ], Except[ _? NumberQ ] -> 0 ],
        "Remote"         -> gitChangeSetRemote @ state
    |>
];

gitEmptyChangeSet // endDefinition;


gitVersionString // beginDefinition;
gitVersionString[ version: { __Integer } ] := StringRiffle[ ToString /@ version, "." ];
gitVersionString[ _ ] := None;
gitVersionString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitBuildChangeSet*)

(* Builds a change set (with status "Changes" or "Clean") from git output. input:
     "Directory", "Root" (default: the directory), "Prefix" (default ""), "ObjectFormat",
     "Status"         -> the output of status --porcelain=v2 -z --branch (or acpGitParseStatus of it)
     "Numstat"        -> the output of diff --numstat -z (or acpGitParseNumstat of it), or None
     "Patch"          -> git's patch (or acpGitSplitPatch of it), or None (a summary: no patches)
     "Untracked"      -> <| repoPath -> <| "Added", "Binary", "Content", "Note" |> |> for untracked files that were read
     "Mode"           -> "Full" | "Summary" (default: "Full" if there is a patch)
     "PatchComplete", "CountsComplete" -> True | False
     "Remote"         -> None | <| "Host", "Short", "Home" |> (a folder on another computer: its paths are POSIX paths)
   Files that are only in the patch (e.g. changed between the status and diff commands) are listed too. *)
acpGitBuildChangeSet // beginDefinition;

acpGitBuildChangeSet[ input_Association ] := Module[
    {
        dir, root, prefix, status, numstat, chunks, untracked, remote, tracked, byChunk, unmatched, extra, count, listed,
        paths, files, counted, added, deleted
    },

    dir       = Lookup[ input, "Directory", None ];
    remote    = Replace[ Lookup[ input, "Remote", None ], Except[ _Association ] -> None ];
    root      = Replace[ Lookup[ input, "Root", dir ], Except[ _String ] -> dir ];
    prefix    = Replace[ Lookup[ input, "Prefix", "" ], Except[ _String ] -> "" ];
    status    = gitStatusData @ Lookup[ input, "Status", "" ];
    numstat   = gitNumstatData @ Lookup[ input, "Numstat", None ];
    chunks    = Replace[ Lookup[ input, "Patch", None ], { s_String :> acpGitSplitPatch @ s, Except[ _List ] -> None } ];
    untracked = Replace[ Lookup[ input, "Untracked", <| |> ], Except[ _Association ] -> <| |> ];

    tracked = gitPairRenames[ status[ "Tracked" ], numstat ];
    { byChunk, unmatched } = If[ ListQ @ chunks, gitMatchChunks[ tracked, chunks ], { <| |>, { } } ];
    (* Chunks that match no status entry, by path (a type change has two chunks for one path): *)
    unmatched = GroupBy[ unmatched, gitChunkEntry[ # ][ "Path" ] & ];
    extra     = gitChunkEntry @* First /@ Values @ unmatched;
    byChunk   = Join[ byChunk, unmatched ];
    count     = Length @ tracked + Length @ extra + Length @ status[ "Untracked" ];

    listed = gitListedEntries[ <| status, "Tracked" -> tracked |>, extra ];
    paths  = AssociationThread[ Lookup[ Join[ tracked, extra ], "Path", { } ] -> True ];
    files  = gitFileRecord[
        #,
        prefix,
        root,
        Replace[ gitEntryNumstat[ #, numstat, paths ], counts_List :> numstatEntry[ #[ "Path" ], counts ] ],
        (* An untracked file can have the path of a tracked entry (e.g. after git rm --cached): its own content counts *)
        If[ #[ "Status" ] === "Untracked", { }, Lookup[ byChunk, #[ "Path" ], { } ] ],
        ListQ @ chunks,
        TrueQ @ Lookup[ input, "PatchComplete", True ],
        Lookup[ untracked, #[ "Path" ], None ],
        AssociationQ @ remote
    ] & /@ listed;

    (* Totals: all tracked changes (except submodules) and the untracked files that were counted *)
    counted = Values @ KeyDrop[ numstat, Lookup[ Select[ Join[ tracked, extra ], #[ "Submodule" ] & ], "Path", { } ] ];
    added   = Total @ Select[ Join[ counted[[ All, 1 ]], Lookup[ Select[ files, #[ "Status" ] === "Untracked" & ], "Added", { } ] ], IntegerQ ];
    deleted = Total @ Select[ counted[[ All, 2 ]], IntegerQ ];

    <|
        "Token"          -> None,
        "Directory"      -> dir,
        "Status"         -> If[ count === 0, "Clean", "Changes" ],
        "Error"          -> None,
        "Git"            -> Lookup[ input, "Git", None ],
        "GitVersion"     -> Lookup[ input, "GitVersion", None ],
        "Root"           -> root,
        "Prefix"         -> prefix,
        "ObjectFormat"   -> Replace[ Lookup[ input, "ObjectFormat", "sha1" ], Except[ "sha1" | "sha256" ] -> "sha1" ],
        "Branch"         -> status[ "Branch" ][ "Head" ],
        "Detached"       -> TrueQ @ status[ "Branch" ][ "Detached" ],
        "Initial"        -> TrueQ @ status[ "Branch" ][ "Initial" ],
        "OID"            -> status[ "Branch" ][ "OID" ],
        "Files"          -> files,
        "FileCount"      -> count,
        "MoreFiles"      -> count - Length @ files,
        "Added"          -> added,
        "Deleted"        -> deleted,
        "Mode"           -> Replace[ Lookup[ input, "Mode", Automatic ], Except[ "Full" | "Summary" ] :> If[ ListQ @ chunks, "Full", "Summary" ] ],
        "PatchComplete"  -> TrueQ @ Lookup[ input, "PatchComplete", True ],
        "CountsComplete" -> TrueQ @ Lookup[ input, "CountsComplete", True ],
        "CheckedAt"      -> AbsoluteTime[ ],
        "Duration"       -> 0,
        "Remote"         -> remote
    |>
];

acpGitBuildChangeSet // endDefinition;


(* The files that are listed: the first $acpGitMaxFiles by path in git's order (byte-wise, so "B" comes before "a"), in
   natural path order (gitNaturalOrdering). Git lists tracked and untracked files sorted, so only the first
   $acpGitMaxFiles of each are candidates; extra entries (chunks without a status entry) are few. *)
gitListedEntries // beginDefinition;

gitListedEntries[ status_Association, extra_List ] := Module[ { candidates, listed },
    candidates = Join[
        Take[ status[ "Tracked" ], UpTo @ $acpGitMaxFiles ],
        extra,
        untrackedEntry /@ Take[ status[ "Untracked" ], UpTo @ $acpGitMaxFiles ]
    ];
    listed = candidates[[ Take[ Ordering[ gitSortKey /@ Lookup[ candidates, "Path", { } ] ], UpTo @ $acpGitMaxFiles ] ]];
    listed[[ gitNaturalOrdering @ Lookup[ listed, "Path", { } ] ]]
];

gitListedEntries // endDefinition;


(* A string whose canonical order is the code point order of path *)
gitSortKey // beginDefinition;
gitSortKey[ path_String ] := StringJoin @ IntegerString[ ToCharacterCode @ path, 16, 6 ];
gitSortKey // endDefinition;


(* The ordering of paths in natural order, as file browsers show them: folder by folder (so that the files of a folder
   stay together), ignoring case, with runs of digits compared by their value ("mod2.py" before "mod10.py"). Names that
   differ only in case or in leading zeros are in git's order. *)
gitNaturalOrdering // beginDefinition;

gitNaturalOrdering[ { } ] := { };

gitNaturalOrdering[ paths: { __String } ] := Ordering[ gitNaturalSortKey /@ paths ];

gitNaturalOrdering // endDefinition;


(* The same order for other lists of names or paths (the remote folder picker) *)
acpNaturalOrdering // beginDefinition;
acpNaturalOrdering[ names: { ___String } ] := gitNaturalOrdering @ names;
acpNaturalOrdering // endDefinition;


(* A string of hexadecimal digits whose canonical order is the natural order of paths. Each folder or file name gives
   its natural key (naturalNameKey), "000000", its code points (gitSortKey) and "000000": the separators sort before any
   character, so a name sorts before longer names that start with it, and the code points break ties between names that
   are the same in natural order before the next name is compared. *)
gitNaturalSortKey // beginDefinition;

gitNaturalSortKey[ path_String ] := StringJoin[ { naturalNameKey @ #, "000000", gitSortKey @ #, "000000" } & /@ StringSplit[ path, "/" ] ];

gitNaturalSortKey // endDefinition;


(* Six hexadecimal digits per character code (in lower case), and for a run of digits the code of "0" followed by the
   number of digits (without leading zeros) and the digits *)
naturalNameKey // beginDefinition;

naturalNameKey[ name_String ] := StringJoin @ Replace[
    StringSplit[ ToLowerCase @ name, digits: DigitCharacter.. :> naturalNumberKey @ digits ],
    {
        text_String :> StringJoin @ IntegerString[ ToCharacterCode @ text, 16, 6 ],
        naturalNumberKey[ digits_ ] :> With[ { n = Replace[ StringDelete[ digits, StartOfString ~~ "0".. ], "" -> "0" ] },
            "000030" <> IntegerString[ Min[ StringLength @ n, 255 ], 16, 2 ] <> n
        ]
    },
    { 1 }
];

naturalNameKey // endDefinition;


(* git status finds renames between HEAD and the index, git diff HEAD -M between HEAD and the working tree, so they can
   disagree. A rename that only the diff finds (e.g. a copy was added to the index and the original deleted only in
   the working tree: status has an added and a deleted file) becomes one renamed entry, as in the diff. *)
gitPairRenames // beginDefinition;

gitPairRenames[ tracked_List, numstat_Association ] := Module[ { pairs, index, statuses, news, olds, i, j, hits, entries },
    pairs = Select[ numstat, StringQ @ #[[ 3 ]] & ];
    If[ pairs === <| |> || tracked === { }, Return[ tracked, Module ] ];
    index    = AssociationThread[ Lookup[ tracked, "Path" ] -> Range @ Length @ tracked ];
    statuses = Lookup[ tracked, "Status" ];
    news     = Keys @ pairs;
    olds     = Values[ pairs ][[ All, 3 ]];
    i        = Lookup[ index, news, None ];
    j        = Lookup[ index, olds, None ];
    hits     = Flatten @ Position[
        MapThread[ IntegerQ @ #1 && IntegerQ @ #2 && statuses[[ #1 ]] === "Added" && statuses[[ #2 ]] === "Deleted" &, { i, j } ],
        True,
        { 1 },
        Heads -> False
    ];
    If[ hits === { }, Return[ tracked, Module ] ];
    entries = tracked;
    Do[ entries[[ i[[ k ]] ]] = <| entries[[ i[[ k ]] ]], "Status" -> "Renamed", "OrigPath" -> olds[[ k ]] |>, { k, hits } ];
    Delete[ entries, List /@ j[[ hits ]] ]
];

gitPairRenames // endDefinition;


(* The line counts of an entry: { added, deleted, origPath } or None. A rename that only git status finds (e.g. the file
   was renamed in the index and then rewritten in the working tree) is a deleted and an added file in the diff: both
   count, unless the original path has its own entry. *)
gitEntryNumstat // beginDefinition;

gitEntryNumstat[ entry_Association, numstat_Association, paths_Association ] := Module[ { own, orig, old },
    own  = Lookup[ numstat, entry[ "Path" ], None ];
    orig = entry[ "OrigPath" ];
    old  = If[ entry[ "Status" ] === "Renamed" && StringQ @ orig && ! KeyExistsQ[ paths, orig ], Lookup[ numstat, orig, None ], None ];
    If[ ListQ @ own && ListQ @ old && own[[ 3 ]] === None,
        { gitAddCounts[ own[[ 1 ]], old[[ 1 ]] ], gitAddCounts[ own[[ 2 ]], old[[ 2 ]] ], None },
        own
    ]
];

gitEntryNumstat // endDefinition;


gitAddCounts // beginDefinition;
gitAddCounts[ a_Integer, b_Integer ] := a + b;
gitAddCounts[ _, _ ] := None;
gitAddCounts // endDefinition;


(* Chunks of the patch by status entry path: a chunk belongs to the entry whose path is its new path, else its old path
   (deleted files), else whose original path is its old path (renames). Gives { <| path -> { chunk... } |>, unmatched }. *)
gitMatchChunks // beginDefinition;

gitMatchChunks[ entries_List, chunks_List ] := Module[ { paths, byPath, byOrig, olds, targets, matched },
    If[ chunks === { }, Return[ { <| |>, { } }, Module ] ];
    paths   = Lookup[ entries, "Path", { } ];
    byPath  = AssociationThread[ paths -> paths ];
    byOrig  = Association @ Cases[ entries, KeyValuePattern @ { "Path" -> p_, "OrigPath" -> o_String } :> (o -> p) ];
    olds    = Lookup[ chunks, "OldPath" ];
    (* The entry of each chunk (or None), in the order of the rules above: *)
    targets = MapThread[
        FirstCase[ { ## }, _String, None ] &,
        { Lookup[ byPath, Lookup[ chunks, "NewPath" ], None ], Lookup[ byPath, olds, None ], Lookup[ byOrig, olds, None ] }
    ];
    matched = Pick[ Transpose @ { targets, chunks }, StringQ /@ targets ];
    {
        If[ matched === { }, <| |>, GroupBy[ matched, First -> Last ] ],
        Pick[ chunks, targets, None ]
    }
];

gitMatchChunks // endDefinition;


(* A status-like entry for a chunk that matches no status entry *)
gitChunkEntry // beginDefinition;

gitChunkEntry[ chunk_Association ] := <|
    "Path"      -> Replace[ chunk[ "NewPath" ], None :> Replace[ chunk[ "OldPath" ], None -> "" ] ],
    "OrigPath"  -> If[ TrueQ[ chunk[ "Rename" ] || chunk[ "Copy" ] ], chunk[ "OldPath" ], None ],
    "XY"        -> "",
    "Status"    -> Which[
        TrueQ @ chunk[ "Submodule" ]  , "Submodule",
        TrueQ @ chunk[ "NewFile" ]    , "Added",
        TrueQ @ chunk[ "DeletedFile" ], "Deleted",
        TrueQ @ chunk[ "Rename" ]     , "Renamed",
        TrueQ @ chunk[ "Copy" ]       , "Copied",
        True                          , "Modified"
    ],
    "Submodule" -> TrueQ @ chunk[ "Submodule" ],
    "Directory" -> False
|>;

gitChunkEntry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*gitFileRecord*)
(* numstat: the file's line counts (from acpGitParseNumstat) or None; untracked: what was read of an untracked file or
   None; remote: True for a folder on another computer (a POSIX full path, made without FileNameJoin, which would use
   "\" on Windows) *)
gitFileRecord // beginDefinition;

gitFileRecord[ entry_Association, prefix_String, root_, numstat_, chunks_List, patchesQ_, patchComplete_, untracked_ ] :=
    gitFileRecord[ entry, prefix, root, numstat, chunks, patchesQ, patchComplete, untracked, False ];

gitFileRecord[ entry_Association, prefix_String, root_, numstat_, chunks_List, patchesQ_, patchComplete_, untracked_, remote_ ] := Module[
    { path, orig, counts, binary, untrackedQ, note },
    path       = entry[ "Path" ];
    orig       = entry[ "OrigPath" ];
    untrackedQ = entry[ "Status" ] === "Untracked";
    counts     = If[ ! untrackedQ && AssociationQ @ numstat, numstat, None ];
    binary     = Or[
        TrueQ @ Lookup[ Replace[ counts, None -> <| |> ], "Binary", False ],
        AnyTrue[ chunks, TrueQ @ #[ "Binary" ] & ],
        untrackedQ && AssociationQ @ untracked && TrueQ @ untracked[ "Binary" ]
    ];
    note = gitFileNote[ entry, chunks, binary, patchesQ, patchComplete, untracked ];
    <|
        "Path"         -> gitProjectPath[ path, prefix ],
        "RepoPath"     -> path,
        "FullPath"     -> If[ TrueQ @ remote, gitPosixFullPath[ root, path ], gitFullPath[ root, path ] ],
        "OrigPath"     -> If[ StringQ @ orig, gitProjectPath[ orig, prefix ], None ],
        "OrigRepoPath" -> orig,
        "Status"       -> entry[ "Status" ],
        "XY"           -> entry[ "XY" ],
        "Added"        -> gitFileCount[ entry, counts, untracked, "Added" ],
        "Deleted"      -> gitFileCount[ entry, counts, untracked, "Deleted" ],
        "Binary"       -> binary,
        "Directory"    -> TrueQ @ entry[ "Directory" ],
        "Header"       -> If[ chunks === { }, None, StringRiffle[ Lookup[ chunks, "Header" ], "\n" ] ],
        "Patch"        -> Replace[ StringRiffle[ Cases[ Lookup[ chunks, "Hunks", { } ], _String ], "\n" ], "" -> None ],
        "Content"      -> If[ untrackedQ && AssociationQ @ untracked, Replace[ Lookup[ untracked, "Content", None ], Except[ _String ] -> None ], None ],
        "OldMode"      -> FirstCase[ Lookup[ chunks, "OldMode", { } ], _String, None ],
        "NewMode"      -> FirstCase[ Reverse @ Lookup[ chunks, "NewMode", { } ], _String, None ],
        "LinkTarget"   -> If[ untrackedQ && AssociationQ @ untracked, Replace[ Lookup[ untracked, "LinkTarget", None ], Except[ _String ] -> None ], None ],
        "Note"         -> note,
        "Remote"       -> TrueQ @ remote
    |>
];

gitFileRecord // endDefinition;


gitFileCount // beginDefinition;
gitFileCount[ KeyValuePattern[ "Submodule" -> True ], _, _, _ ] := None;
gitFileCount[ KeyValuePattern[ "Status" -> "Untracked" ], _, untracked_Association, "Added" ] := Replace[ Lookup[ untracked, "Added", None ], Except[ _Integer ] -> None ];
gitFileCount[ KeyValuePattern[ "Status" -> "Untracked" ], _, untracked_Association, "Deleted" ] := If[ IntegerQ @ Lookup[ untracked, "Added", None ], 0, None ];
gitFileCount[ KeyValuePattern[ "Status" -> "Untracked" ], _, _, _ ] := None;
gitFileCount[ _, counts_Association, _, key_ ] := Replace[ Lookup[ counts, key, None ], Except[ _Integer ] -> None ];
gitFileCount[ _, _, _, _ ] := None;
gitFileCount // endDefinition;


gitFileNote // beginDefinition;

gitFileNote[ entry_, chunks_, binary_, patchesQ_, patchComplete_, untracked_ ] := Which[
    TrueQ @ entry[ "Submodule" ],
        "Submodule",
    entry[ "Status" ] === "Untracked",
        Which[
            TrueQ @ entry[ "Directory" ]    , "Directory",
            AssociationQ @ untracked        , Replace[ Lookup[ untracked, "Note", None ], Except[ _String ] -> None ],
            True                            , "NotRead"
        ],
    binary,
        "Binary",
    chunks === { },
        Which[ ! TrueQ @ patchesQ, None, TrueQ @ patchComplete, "NoDiff", True, "PatchUnavailable" ],
    AllTrue[ chunks, ! StringQ @ #[ "Hunks" ] & ],
        Which[
            AnyTrue[ chunks, TrueQ[ #[ "Rename" ] || #[ "Copy" ] ] & ]         , "Renamed",
            AnyTrue[ chunks, TrueQ[ #[ "NewFile" ] || #[ "DeletedFile" ] ] & ] , "Empty",
            AnyTrue[ chunks, StringQ[ #[ "OldMode" ] ] && StringQ[ #[ "NewMode" ] ] && #[ "OldMode" ] =!= #[ "NewMode" ] & ], "ModeChanged",
            True                                                                  , "NoDiff"
        ],
    True,
        None
];

gitFileNote // endDefinition;


(* Path relative to the project directory (prefix: the project directory relative to the repository root, "" or
   ending with "/"). Paths outside of it (e.g. the original path of a rename) get ".." components. *)
gitProjectPath // beginDefinition;

gitProjectPath[ path_String, "" ] := path;

gitProjectPath[ path_String, prefix_String ] /; StringStartsQ[ path, prefix ] := StringDrop[ path, StringLength @ prefix ];

gitProjectPath[ path_String, prefix_String ] := Module[ { from, to, common },
    from   = StringSplit[ prefix, "/" ];
    to     = StringSplit[ path, "/", All ];
    common = LengthWhile[ Transpose @ { Take[ from, UpTo @ Length @ to ], Take[ to, UpTo @ Length @ from ] }, Apply @ SameQ ];
    StringRiffle[ Join[ ConstantArray[ "..", Length @ from - common ], Drop[ to, common ] ], "/" ]
];

gitProjectPath[ path_, _ ] := path;

gitProjectPath // endDefinition;


gitFullPath // beginDefinition;
gitFullPath[ root_String, path_String ] := FileNameJoin @ Prepend[ StringSplit[ StringDelete[ path, "/" ~~ EndOfString ], "/" ], root ];
gitFullPath[ _, _ ] := None;
gitFullPath // endDefinition;


(* The same for a POSIX path on another computer: a string join with "/" *)
gitPosixFullPath // beginDefinition;
gitPosixFullPath[ root_String, path_String ] := StringDelete[ root, "/" ~~ EndOfString ] <> "/" <> StringDelete[ path, "/" ~~ EndOfString ];
gitPosixFullPath[ _, _ ] := None;
gitPosixFullPath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Window Summary*)

(* The window record's "Git" key (kernel state only: after a kernel restart the next check rebuilds it):
     "Directory"  -> the project directory the summary is for (None if the window has none)
     "Status"     -> "Unknown" | "Checking" (first check of the directory) | "Unavailable" (no usable git) |
                     "NotRepository" | "Clean" | "Changes" | "Error"
     "FileCount", "Added", "Deleted" -> the counts of the last check
     "Branch", "Detached", "Initial", "Root", "Prefix" -> repository information of the last check
     "Error"      -> None | the change set's error (<| "Code", "Step", "ExitCode", "Detail" |>)
     "CheckedAt", "Duration" -> when the last check finished (AbsoluteTime) and how long it took (seconds)
     "StartedAt"  -> when the current (or last) check started
     "InFlight"   -> True while a check runs; "Token" -> its token (results of other checks are dropped)
     "Stale"      -> True if files may have changed since the current or last check started (a check follows)
     "Paused"     -> True after a check timed out or its output was too large, or (remote windows) ssh or the remote
                     script failed: no periodic checks until the next trigger (a tool call, the end of a turn, a
                     directory change, an explicit check)
     "Remote"     -> the host key (acpSSHHostKey; "?" for invalid settings) of a remote window, None for a local one:
                     the same path on another host is another folder
   The project directory of a remote window is used once it is an absolute path (after the agent's launch resolved a
   "~/..." folder), and its first check waits until the window is connected, so that it never signs in to a host in
   parallel with the agent's own first sign-in. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitSummary*)

(* The window's git summary, with defaults for missing keys *)
acpGitSummary // beginDefinition;

acpGitSummary[ nbo_NotebookObject ] := acpGitSummary @ acpWindowGet @ nbo;

acpGitSummary[ window_Association ] := Join[
    gitInitialSummary[ gitWindowDirectory @ window, acpWindowHostKey @ window ],
    Replace[ Lookup[ window, "Git", <| |> ], Except[ _Association ] -> <| |> ]
];

acpGitSummary[ _ ] := gitInitialSummary @ None;

acpGitSummary // endDefinition;


gitInitialSummary // beginDefinition;

gitInitialSummary[ dir_ ] := gitInitialSummary[ dir, None ];

gitInitialSummary[ dir_, remote_ ] := <|
    "Directory" -> dir,
    "Status"    -> "Unknown",
    "FileCount" -> 0,
    "Added"     -> 0,
    "Deleted"   -> 0,
    "Branch"    -> None,
    "Detached"  -> False,
    "Initial"   -> False,
    "Root"      -> None,
    "Prefix"    -> None,
    "Error"     -> None,
    "CheckedAt" -> None,
    "Duration"  -> None,
    "StartedAt" -> None,
    "InFlight"  -> False,
    "Token"     -> None,
    "Stale"     -> False,
    "Paused"    -> False,
    "Remote"    -> remote
|>;

gitInitialSummary // endDefinition;


gitWindowQ // beginDefinition;
gitWindowQ[ window_Association ] := KeyExistsQ[ window, "Status" ];
gitWindowQ[ _ ] := False;
gitWindowQ // endDefinition;


(* The window's project directory, or None; for a remote window only an absolute path (a "~/..." folder is resolved by
   the agent's launch; nothing local is ever checked) *)
gitWindowDirectory // beginDefinition;

gitWindowDirectory[ window_Association ] := Replace[
    Lookup[ window, "ProjectDirectory", None ],
    {
        dir_String /; acpRemoteQ @ window :> If[ acpRemoteAbsolutePathQ @ dir, dir, None ],
        Except[ _String? (StringLength[ # ] > 0 &) ] -> None
    }
];

gitWindowDirectory[ _ ] := None;

gitWindowDirectory // endDefinition;


(* Whether the agent of a window is connected: the first check of a remote window waits for that (see above) *)
gitConnectedQ // beginDefinition;
gitConnectedQ[ window_Association ] := MemberQ[ { "Ready", "Running", "Restoring" }, Lookup[ window, "Status", None ] ];
gitConnectedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitCheck*)

(* Starts a summary check (status and line counts) of the window's project directory. A check that is already running is
   superseded (its result is dropped). The request is queued for the pump. Gives its token, or None (no window record or
   no project directory). Normally called by housekeeping (see "Housekeeping"). *)
acpGitCheck // beginDefinition;
acpGitCheck[ nbo_NotebookObject ] := gitStartWindowRequest[ nbo, "Summary", None ];
acpGitCheck // endDefinition;


(* Marks the window's summary as being checked (with a new token) and queues the request; the result updates the
   summary (and is passed on to continuation, unless it is None). The request supersedes a running one of the same mode
   for the window (its key is { mode, nbo }); one of the other mode keeps running, but only the result whose token is the
   summary's updates the summary. A remote window's request runs on its host (acpWindowSSH; invalid settings give an
   "Unavailable" result). *)
gitStartWindowRequest // beginDefinition;

gitStartWindowRequest[ nbo_NotebookObject, mode_String, continuation_ ] := Module[ { window, dir, remote, token, claimed = False },
    window = acpWindowGet @ nbo;
    If[ ! gitWindowQ @ window, Return[ None, Module ] ];
    dir    = gitWindowDirectory @ window;
    remote = acpWindowHostKey @ window;
    If[ dir === None, gitResetSummary @ nbo; Return[ None, Module ] ];
    token = gitNewToken[ ];
    acpWindowUpdate[
        nbo,
        Function[ w,
            If[ gitWindowQ @ w && gitWindowDirectory @ w === dir && acpWindowHostKey @ w === remote,
                claimed = True;
                <| w, "Git" -> gitStartedSummary[ acpGitSummary @ w, dir, token, remote ] |>,
                Missing[ "NotFound" ]
            ]
        ]
    ];
    If[ ! claimed, Return[ None, Module ] ];
    With[ { n = nbo, f = continuation },
        gitQueueRequest @ gitNewRequest[
            token,
            dir,
            mode,
            nbo,
            Function[ changes, gitApplySummary[ n, changes ]; If[ f =!= None, f @ changes ] ],
            { mode, nbo },
            acpWindowSSH @ window
        ]
    ];
    token
];

gitStartWindowRequest // endDefinition;


gitStartedSummary // beginDefinition;

gitStartedSummary[ old_Association, dir_String, token_String ] := gitStartedSummary[ old, dir, token, None ];

gitStartedSummary[ old_Association, dir_String, token_String, remote_ ] := With[
    { same = old[ "Directory" ] === dir && Lookup[ old, "Remote", None ] === remote },
    <|
        If[ same, old, gitInitialSummary[ dir, remote ] ],
        "Status"    -> If[ same && old[ "Status" ] =!= "Unknown", old[ "Status" ], "Checking" ],
        "InFlight"  -> True,
        "Token"     -> token,
        "StartedAt" -> AbsoluteTime[ ],
        "Stale"     -> False,
        "Paused"    -> False
    |>
];

gitStartedSummary // endDefinition;


(* Results of superseded checks, or for another directory or host than the window's current one, are dropped. Stale marks
   that arrived while the check ran are kept (another check follows). *)
gitApplySummary // beginDefinition;

gitApplySummary[ nbo_NotebookObject, changes_Association ] := acpWindowUpdate[
    nbo,
    Function[ w,
        With[ { git = acpGitSummary @ w },
            If[ And[
                    gitWindowQ @ w,
                    git[ "Token" ] === changes[ "Token" ],
                    gitWindowDirectory @ w === changes[ "Directory" ],
                    git[ "Remote" ] === acpWindowHostKey @ w
                ],
                <| w, "Git" -> gitResultSummary[ git, changes ] |>,
                Missing[ "Superseded" ]
            ]
        ]
    ]
];

gitApplySummary // endDefinition;


gitResultSummary // beginDefinition;

gitResultSummary[ git_Association, changes_Association ] := <|
    git,
    "Status"    -> Replace[ changes[ "Status" ], "NoDirectory" -> "Unknown" ],
    "FileCount" -> changes[ "FileCount" ],
    "Added"     -> changes[ "Added" ],
    "Deleted"   -> changes[ "Deleted" ],
    "Branch"    -> changes[ "Branch" ],
    "Detached"  -> changes[ "Detached" ],
    "Initial"   -> changes[ "Initial" ],
    "Root"      -> changes[ "Root" ],
    "Prefix"    -> changes[ "Prefix" ],
    "Error"     -> changes[ "Error" ],
    "CheckedAt" -> changes[ "CheckedAt" ],
    "Duration"  -> changes[ "Duration" ],
    "InFlight"  -> False,
    (* Paused after checks that took too long, and (remote windows) after ssh or the remote script failed: a wrong key
       or host does not sign in again every minute, which servers can count as an attack (fail2ban) *)
    "Paused"    -> MatchQ[ changes[ "Error" ], KeyValuePattern[ "Code" -> "TimedOut" | "TooLarge" | "SSHFailed" | "RemoteFailed" ] ]
|>;

gitResultSummary // endDefinition;


(* A window without a project directory (or a remote window that is not connected yet): an "Unknown" summary (only
   written if it changes) *)
gitResetSummary // beginDefinition;

gitResetSummary[ nbo_NotebookObject ] := acpWindowUpdate[
    nbo,
    Function[ w,
        With[ { git = acpGitSummary @ w, remote = acpWindowHostKey @ w },
            If[ gitWindowQ @ w && (! KeyExistsQ[ w, "Git" ] || git[ "Directory" ] =!= None || TrueQ @ git[ "InFlight" ] || git[ "Remote" ] =!= remote),
                <| w, "Git" -> gitInitialSummary[ None, remote ] |>,
                Missing[ "Unchanged" ]
            ]
        ]
    ]
];

gitResetSummary // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitMarkStale*)

(* Files of the window's project may have changed (a tool call completed, a turn ended): housekeeping starts a check
   ($gitMinCheckInterval seconds after the last one started, at the earliest). Only updates kernel state, so it is safe in
   reader handlers. *)
acpGitMarkStale // beginDefinition;

acpGitMarkStale[ nbo_NotebookObject ] := (
    acpWindowUpdate[
        nbo,
        Function[ w,
            With[ { git = acpGitSummary @ w },
                If[ gitWindowQ @ w && ! (TrueQ @ git[ "Stale" ] && ! TrueQ @ git[ "Paused" ]),
                    <| w, "Git" -> <| git, "Stale" -> True, "Paused" -> False |> |>,
                    Missing[ "Unchanged" ]
                ]
            ]
        ]
    ];
    Null
);

acpGitMarkStale[ _ ] := Null;

acpGitMarkStale // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpGitNoteSessionUpdate*)

(* Called by the reader handler for each session update applied to a turn: a tool call that completed (or failed) and
   may have changed files marks the summary stale. *)
acpGitNoteSessionUpdate // beginDefinition;

acpGitNoteSessionUpdate[ nbo_NotebookObject, turnID_String, update_Association ] := If[
    MatchQ[
        update,
        KeyValuePattern @ {
            "sessionUpdate" -> "tool_call" | "tool_call_update",
            "status"        -> "completed" | "failed",
            "toolCallId"    -> _String
        }
    ] && gitFileChangingToolQ @ gitToolEntity[ turnID, update[ "toolCallId" ] ],
    acpGitMarkStale @ nbo
];

acpGitNoteSessionUpdate[ ___ ] := Null;

acpGitNoteSessionUpdate // endDefinition;


gitToolEntity // beginDefinition;

gitToolEntity[ turnID_String, id_String ] := Replace[
    acpTurnGet[ turnID, "Entities", <| |> ],
    { entities_Association :> Replace[ Lookup[ entities, Key @ { "Tool", id }, <| |> ], Except[ _Association ] -> <| |> ], _ -> <| |> }
];

gitToolEntity // endDefinition;


gitFileChangingToolQ // beginDefinition;

gitFileChangingToolQ[ tool_Association ] := With[ { name = Lookup[ tool, "Name", None ], kind = Lookup[ tool, "Kind", None ] },
    Which[
        MemberQ[ $gitChangingToolNames, name ] || MemberQ[ $gitChangingToolKinds, kind ], True,
        MemberQ[ $gitReadOnlyToolNames, name ] || MemberQ[ $gitReadOnlyToolKinds, kind ], False,
        True, True
    ]
];

gitFileChangingToolQ[ _ ] := True;

gitFileChangingToolQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Housekeeping*)

(* Every $gitHousekeepingTicks publication ticks (while the pump runs), for each window, a summary check starts when
     1. the summary is missing or for another directory (new window, directory change, record rebuilt after a kernel
        restart);
     2. it is stale (a tool call that may have changed files completed, or a turn ended) and the last check started at
        least $gitMinCheckInterval seconds ago;
     3. the window is idle and the last check finished more than $gitIdleCheckInterval seconds ago (or
        $gitIdleCheckFactor times its duration, if that is longer), unless checks are paused after a timeout.
   Only one check per window runs at a time; a check that never finished is given up after $gitRequestTimeout seconds.
   Remote windows: the summary is also for another host in 1 (the same path on another host is another folder); the
   check of 1 waits until the window is connected (the summary is reset meanwhile, so the counts of another folder or
   host are not shown); 2 and 3 use $gitRemoteMinCheckInterval and $gitRemoteIdleCheckInterval (each check is a new
   sign-in), and checks are also paused after ssh or the remote script failed (gitResultSummary). *)
gitHousekeeping // beginDefinition;

gitHousekeeping[ ] := With[ { now = AbsoluteTime[ ] },
    If[ TrueQ @ $acpGitEnabled, KeyValueMap[ gitWindowHousekeeping[ #1, #2, now ] &, $acpWindows ] ];
    Null
];

gitHousekeeping // endDefinition;


gitWindowHousekeeping // beginDefinition;

gitWindowHousekeeping[ nbo_NotebookObject, window_Association? gitWindowQ, now_ ] := acpIsolated @ Module[ { dir, git, remote },
    dir    = gitWindowDirectory @ window;
    git    = acpGitSummary @ window;
    remote = acpWindowHostKey @ window;
    Which[
        ! KeyExistsQ[ window, "Git" ] || git[ "Directory" ] =!= dir || git[ "Remote" ] =!= remote,
            Which[
                ! StringQ @ dir                       , gitResetSummary @ nbo,
                remote === None || gitConnectedQ @ window, acpGitCheck @ nbo,
                True                                  , gitResetSummary @ nbo
            ],
        ! StringQ @ dir,
            Null,
        TrueQ @ git[ "InFlight" ],
            If[ ! NumberQ @ git[ "StartedAt" ] || now - git[ "StartedAt" ] > $gitRequestTimeout, gitCheckLost[ nbo, git[ "Token" ] ] ],
        TrueQ @ git[ "Stale" ],
            If[ ! NumberQ @ git[ "StartedAt" ] || now - git[ "StartedAt" ] >= gitMinCheckInterval @ remote, acpGitCheck @ nbo ],
        gitIdleCheckDueQ[ window, git, now ],
            acpGitCheck @ nbo
    ]
];

gitWindowHousekeeping[ _, _, _ ] := Null;

gitWindowHousekeeping // endDefinition;


gitIdleCheckDueQ // beginDefinition;

gitIdleCheckDueQ[ window_, git_, now_ ] := And[
    ! StringQ @ Lookup[ window, "CurrentTurn", None ],
    ! TrueQ @ git[ "Paused" ],
    NumberQ @ git[ "CheckedAt" ],
    now - git[ "CheckedAt" ] >= Max[
        gitIdleCheckInterval @ acpWindowHostKey @ window,
        $gitIdleCheckFactor * Replace[ git[ "Duration" ], Except[ _? NumberQ ] -> 0 ]
    ]
];

gitIdleCheckDueQ // endDefinition;


(* The intervals of rules 2 and 3 for a window's host key (None: a local window) *)
gitMinCheckInterval // beginDefinition;
gitMinCheckInterval[ None ] := $gitMinCheckInterval;
gitMinCheckInterval[ _ ] := $gitRemoteMinCheckInterval;
gitMinCheckInterval // endDefinition;


gitIdleCheckInterval // beginDefinition;
gitIdleCheckInterval[ None ] := $gitIdleCheckInterval;
gitIdleCheckInterval[ _ ] := $gitRemoteIdleCheckInterval;
gitIdleCheckInterval // endDefinition;


gitCheckLost // beginDefinition;

gitCheckLost[ nbo_NotebookObject, token_ ] := (
    acpLog[ "GitCheckLost", token ];
    acpWindowUpdate[
        nbo,
        Function[ w,
            With[ { git = acpGitSummary @ w },
                If[ gitWindowQ @ w && git[ "Token" ] === token,
                    <| w, "Git" -> <| git, "InFlight" -> False, "Stale" -> True |> |>,
                    Missing[ "Unchanged" ]
                ]
            ]
        ]
    ]
);

gitCheckLost // endDefinition;


acpRegisterHousekeeping[ "ACPGit", gitHousekeeping, $gitHousekeepingTicks ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
