(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ACPGit.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ACPGit.wlt:11,1-16,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`ACP`Common`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPGit-LoadACPContext@@Tests/ACPGit.wlt:18,1-23,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* Tests for ACP/Git.wl (see docs/acp-window.md, "Reviewing changes"). The parsing, change set and housekeeping tests
   are pure. The runner tests start /bin/sh (skipped on Windows); the integration tests run the real git in small
   temporary repositories (skipped, Missing["TestSkipped"], when git is not found). Test repositories are set up with
   RunProcess and a local identity (-c user.name=...); GIT_CONFIG_GLOBAL points to a test file (which sets the global
   ignore and attributes files, whose defaults ~/.config/git/ignore and attributes git reads otherwise, to an empty file)
   and GIT_CONFIG_NOSYSTEM is set while the tests run, so the developer's git configuration is never read or changed. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    $acpLogStart = AbsoluteTime[ ]; (* see ACPGit-DebugLog *)

    $gitScratch  = CreateDirectory[ ];
    $gitExe      = acpFindGit[ ];
    $gitTestsQ   = StringQ @ $gitExe;
    $shTestsQ    = $OperatingSystem =!= "Windows" && FileExistsQ[ "/bin/sh" ];
    $procfsQ     = $OperatingSystem === "Unix" && DirectoryQ[ "/proc/self" ];

    (* Isolation from the developer's git configuration (restored by ACPGit-Cleanup): *)
    $savedGitEnvironment = AssociationMap[ Environment, { "GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM" } ];
    $emptyGitConfig      = FileNameJoin @ { $gitScratch, "empty.gitconfig" };
    $emptyFile           = FileNameJoin @ { $gitScratch, "empty" };
    $noHooks             = CreateDirectory @ FileNameJoin @ { $gitScratch, "nohooks" };
    BinaryWrite[ $emptyFile, { } ];
    Close @ $emptyFile;
    BinaryWrite[ $emptyGitConfig, StringToByteArray[ "[core]\n\texcludesFile = " <> $emptyFile <> "\n\tattributesFile = " <> $emptyFile <> "\n", "UTF-8" ] ];
    Close @ $emptyGitConfig;
    SetEnvironment[ { "GIT_CONFIG_GLOBAL" -> $emptyGitConfig, "GIT_CONFIG_NOSYSTEM" -> "1" } ];

    ifGitTests // ClearAll;
    ifGitTests // Attributes = { HoldFirst };
    ifGitTests[ eval_ ] := If[ TrueQ @ $gitTestsQ, eval, Missing[ "TestSkipped" ] ];

    ifShTests // ClearAll;
    ifShTests // Attributes = { HoldFirst };
    ifShTests[ eval_ ] := If[ TrueQ @ $shTestsQ, eval, Missing[ "TestSkipped" ] ];

    (* Waiting with Pause lets the pump (scheduled evaluations and housekeeping) run: *)
    waitUntil // ClearAll;
    waitUntil // Attributes = { HoldFirst };
    waitUntil[ cond_, timeout_: 20 ] := Module[ { deadline = AbsoluteTime[ ] + timeout },
        While[ ! TrueQ @ cond && AbsoluteTime[ ] < deadline, Pause[ 0.05 ] ];
        TrueQ @ cond
    ];

    (* Test setup only (the paclet never writes to repositories): *)
    gitSetup[ dir_String, args___String ] := RunProcess[
        Join[
            {
                $gitExe,
                "-c", "user.name=Chatbook Tests",
                "-c", "user.email=chatbook-tests@example.com",
                "-c", "init.defaultBranch=main",
                "-c", "commit.gpgsign=false",
                "-c", "core.autocrlf=false",
                "-c", "core.hooksPath=" <> $noHooks
            },
            { args }
        ],
        ProcessDirectory -> dir
    ][ "ExitCode" ];

    newRepository[ name_String ] := With[ { dir = CreateDirectory @ FileNameJoin @ { $gitScratch, name } },
        gitSetup[ dir, "init", "-q" ];
        dir
    ];

    writeBytes[ file_String, bytes_ ] := (
        Quiet @ CreateDirectory[ DirectoryName @ file ];
        BinaryWrite[ file, bytes ];
        Close @ file;
        file
    );
    writeText[ file_String, text_String ] := writeBytes[ file, StringToByteArray[ text, "UTF-8" ] ];

    (* A full change set of a directory or window (waits for it) *)
    changesOf[ target_ ] := Module[ { result = None },
        acpGitChanges[ target, (result = #) & ];
        waitUntil[ AssociationQ @ result ];
        result
    ];

    filesByPath[ changes_Association ] := AssociationThread[ Lookup[ changes[ "Files" ], "Path", { } ], changes[ "Files" ] ];

    runSync[ args_List, dir_String, opts_Association: <| |> ] := Module[ { result = None },
        acpGitRun[ args, dir, (result = #) &, opts ];
        waitUntil[ AssociationQ @ result ];
        result
    ];

    fileDescriptors[ ] := Length @ FileNames[ "*", "/proc/" <> ToString @ $ProcessID <> "/fd" ];

    processAliveQ[ pid_Integer ] := With[ { stat = Quiet @ ReadString[ "/proc/" <> ToString @ pid <> "/stat" ] },
        StringQ @ stat && ! StringContainsQ[ stat, ") Z " ]
    ];

    (* Windows: the same record UI.wl registers (fake NotebookObjects, no front end) *)
    $gitWindows = { };
    newWindow[ dir_ ] := With[ { nbo = NotebookObject[ "acp-git-test-" <> ToString[ Length @ $gitWindows + 1 ] ] },
        AppendTo[ $gitWindows, nbo ];
        acpWindowUpdate[ nbo, Join[ #, Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ nbo, dir, "OpenCode", <| |> ] ] & ];
        nbo
    ];

    (* porcelain v2 -z and numstat -z output *)
    $h = "4b5a6b88196afa553fa7b2a6fbe1a6418f5cdd26";
    nulJoin[ fields_List ] := StringJoin[ # <> FromCharacterCode[ 0 ] & /@ fields ];
    changed[ xy_String, path_String ] := "1 " <> xy <> " N... 100644 100644 100644 " <> $h <> " " <> $h <> " " <> path;
    ,
    _,
    SameTest -> MatchQ,
    TestID   -> "ACPGit-Definitions@@Tests/ACPGit.wlt:39,1-142,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Finding Git*)
VerificationTest[
    Module[ { binA, binB, stubDir, devTools, winDir, unix, mac },
        binA     = CreateDirectory @ FileNameJoin @ { $gitScratch, "find", "binA" };
        binB     = CreateDirectory @ FileNameJoin @ { $gitScratch, "find", "binB" };
        stubDir  = CreateDirectory @ FileNameJoin @ { $gitScratch, "find", "usrbin" };
        devTools = FileNameJoin @ { $gitScratch, "find", "CommandLineTools", "git" };
        winDir   = CreateDirectory @ FileNameJoin @ { $gitScratch, "find", "Git", "cmd" };
        writeText[ #, "" ] & /@ {
            FileNameJoin @ { binA, "git" },
            FileNameJoin @ { binB, "git" },
            FileNameJoin @ { stubDir, "git" },
            FileNameJoin @ { winDir, "git.exe" },
            FileNameJoin @ { binB, "git.exe" }
        };
        unix = <| "OperatingSystem" -> "Unix", "SystemDirectories" -> { } |>;
        mac  = <| "OperatingSystem" -> "MacOSX", "MacStub" -> FileNameJoin @ { stubDir, "git" }, "MacDeveloperTools" -> { devTools } |>;
        {
            (* PATH first, then the system directories: *)
            acpFindGit @ <| unix, "PATH" -> StringRiffle[ { binA, binB }, ":" ] |>,
            acpFindGit @ <| unix, "PATH" -> FileNameJoin @ { $gitScratch, "missing" }, "SystemDirectories" -> { binB } |>,
            acpFindGit @ <| unix, "PATH" -> "" |>,
            acpFindGit @ <| unix, "PATH" -> $Failed |>,
            (* macOS: the /usr/bin/git stub only counts when the developer tools are installed *)
            acpFindGit @ <| mac, "PATH" -> stubDir, "SystemDirectories" -> { } |>,
            acpFindGit @ <| mac, "PATH" -> stubDir, "SystemDirectories" -> { binA } |>,
            writeText[ devTools, "" ];
            acpFindGit @ <| mac, "PATH" -> stubDir, "SystemDirectories" -> { binA } |>,
            (* Windows: git.exe only; quoted PATH entries *)
            acpFindGit @ <| "OperatingSystem" -> "Windows", "PATH" -> "\"" <> binA <> "\";" <> winDir, "SystemDirectories" -> { } |>,
            acpFindGit @ <| "OperatingSystem" -> "Windows", "PATH" -> "", "SystemDirectories" -> { binB } |>
        } === {
            FileNameJoin @ { binA, "git" },
            FileNameJoin @ { binB, "git" },
            None,
            None,
            None,
            FileNameJoin @ { binA, "git" },
            FileNameJoin @ { stubDir, "git" },
            FileNameJoin @ { winDir, "git.exe" },
            FileNameJoin @ { binB, "git.exe" }
        }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "FindGit-InjectedEnvironment@@Tests/ACPGit.wlt:147,1-192,2"
]

VerificationTest[
    { acpFindGit[ ] === acpFindGit[ ], MatchQ[ acpFindGit[ ], _String | None ] },
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "FindGit-Memoized@@Tests/ACPGit.wlt:194,1-199,2"
]

VerificationTest[
    Module[ { root, deep, worktree, plain },
        root     = CreateDirectory @ FileNameJoin @ { $gitScratch, "hint", "repo" };
        deep     = CreateDirectory @ FileNameJoin @ { root, "a", "b" };
        worktree = CreateDirectory @ FileNameJoin @ { $gitScratch, "hint", "worktree" };
        plain    = CreateDirectory @ FileNameJoin @ { $gitScratch, "hint", "plain" };
        CreateDirectory @ FileNameJoin @ { root, ".git" };
        writeText[ FileNameJoin @ { worktree, ".git" }, "gitdir: /somewhere/else\n" ];
        {
            acpGitWorkTreeRoot @ root,
            acpGitWorkTreeRoot @ deep,
            acpGitWorkTreeRoot @ File @ deep,
            acpGitWorkTreeRoot @ worktree,
            acpGitWorkTreeRoot @ plain,
            acpGitWorkTreeRoot @ FileNameJoin @ { root, "missing" },
            acpGitWorkTreeRoot @ None
        } === { root, root, root, worktree, acpGitWorkTreeRoot @ $TemporaryDirectory, None, None }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "WorkTreeRoot@@Tests/ACPGit.wlt:201,1-222,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Parsing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Status*)
VerificationTest[
    acpGitParseStatus @ nulJoin @ {
        "# branch.oid " <> $h,
        "# branch.head main",
        "# branch.ab +0 -0",
        changed[ ".M", "src/a.txt" ],
        "1 A. N... 000000 100644 100644 0000000000000000000000000000000000000000 " <> $h <> " new file.txt",
        "1 D. N... 100644 000000 000000 " <> $h <> " 0000000000000000000000000000000000000000 staged gone.txt",
        changed[ ".D", "gone.txt" ],
        changed[ "MD", "changed then deleted.txt" ],
        "2 R. N... 100644 100644 100644 " <> $h <> " " <> $h <> " R100 renamed.txt",
        "orig name.txt",
        "2 C. N... 100644 100644 100644 " <> $h <> " " <> $h <> " C75 copy.txt",
        "source.txt",
        "u UU N... 100644 100644 100644 100644 " <> $h <> " " <> $h <> " " <> $h <> " conflict.txt",
        "1 .M SC.. 160000 160000 160000 " <> $h <> " " <> $h <> " vendor/lib",
        changed[ ".T", "link" ],
        changed[ ".A", "intent.txt" ],
        changed[ ".M", "\:00fcn\:00ef \"q\" \\ x.txt" ],
        changed[ ".M", " leading space.txt" ],
        "? untracked.md",
        "? nested/",
        "? two\nlines.txt",
        "! ignored.log"
    },
    <|
        "Branch"  -> <| "OID" -> $h, "Head" -> "main", "Initial" -> False, "Detached" -> False |>,
        "Entries" -> {
            <| "Path" -> "src/a.txt"               , "OrigPath" -> None           , "XY" -> ".M", "Status" -> "Modified"   , "Submodule" -> False, "Directory" -> False |>,
            <| "Path" -> "new file.txt"            , "OrigPath" -> None           , "XY" -> "A.", "Status" -> "Added"      , "Submodule" -> False, "Directory" -> False |>,
            <| "Path" -> "staged gone.txt"         , "OrigPath" -> None           , "XY" -> "D.", "Status" -> "Deleted"    , "Submodule" -> False, "Directory" -> False |>,
            <| "Path" -> "gone.txt"                , "OrigPath" -> None           , "XY" -> ".D", "Status" -> "Deleted"    , "Submodule" -> False, "Directory" -> False |>,
            <| "Path" -> "changed then deleted.txt", "OrigPath" -> None           , "XY" -> "MD", "Status" -> "Deleted"    , "Submodule" -> False, "Directory" -> False |>,
            <| "Path" -> "renamed.txt"             , "OrigPath" -> "orig name.txt", "XY" -> "R.", "Status" -> "Renamed"    , "Submodule" -> False, "Directory" -> False |>,
            <| "Path" -> "copy.txt"                , "OrigPath" -> "source.txt"   , "XY" -> "C.", "Status" -> "Copied"     , "Submodule" -> False, "Directory" -> False |>,
            <| "Path" -> "conflict.txt"            , "OrigPath" -> None           , "XY" -> "UU", "Status" -> "Conflict"   , "Submodule" -> False, "Directory" -> False |>,
            <| "Path" -> "vendor/lib"              , "OrigPath" -> None           , "XY" -> ".M", "Status" -> "Submodule"  , "Submodule" -> True , "Directory" -> False |>,
            <| "Path" -> "link"                    , "OrigPath" -> None           , "XY" -> ".T", "Status" -> "TypeChanged", "Submodule" -> False, "Directory" -> False |>,
            <| "Path" -> "intent.txt"              , "OrigPath" -> None           , "XY" -> ".A", "Status" -> "Added"      , "Submodule" -> False, "Directory" -> False |>,
            <| "Path" -> "\:00fcn\:00ef \"q\" \\ x.txt", "OrigPath" -> None       , "XY" -> ".M", "Status" -> "Modified"   , "Submodule" -> False, "Directory" -> False |>,
            <| "Path" -> " leading space.txt"      , "OrigPath" -> None           , "XY" -> ".M", "Status" -> "Modified"   , "Submodule" -> False, "Directory" -> False |>,
            <| "Path" -> "untracked.md"            , "OrigPath" -> None           , "XY" -> "??", "Status" -> "Untracked"  , "Submodule" -> False, "Directory" -> False |>,
            <| "Path" -> "nested/"                 , "OrigPath" -> None           , "XY" -> "??", "Status" -> "Untracked"  , "Submodule" -> False, "Directory" -> True  |>,
            <| "Path" -> "two\nlines.txt"          , "OrigPath" -> None           , "XY" -> "??", "Status" -> "Untracked"  , "Submodule" -> False, "Directory" -> False |>
        }
    |>,
    SameTest -> MatchQ,
    TestID   -> "ParseStatus-Entries@@Tests/ACPGit.wlt:231,1-279,2"
]

VerificationTest[
    {
        acpGitParseStatus @ nulJoin @ { "# branch.oid (initial)", "# branch.head main", "? a.txt" },
        acpGitParseStatus @ nulJoin @ { "# branch.oid " <> $h, "# branch.head (detached)" },
        acpGitParseStatus[ "" ],
        acpGitParseStatus[ None ]
    },
    {
        <| "Branch" -> <| "OID" -> None, "Head" -> "main", "Initial" -> True, "Detached" -> False |>, "Entries" -> { KeyValuePattern[ "Path" -> "a.txt" ] } |>,
        <| "Branch" -> <| "OID" -> $h, "Head" -> None, "Initial" -> False, "Detached" -> True |>, "Entries" -> { } |>,
        <| "Branch" -> <| "OID" -> None, "Head" -> None, "Initial" -> False, "Detached" -> False |>, "Entries" -> { } |>,
        <| "Branch" -> _Association, "Entries" -> { } |>
    },
    SameTest -> MatchQ,
    TestID   -> "ParseStatus-Headers@@Tests/ACPGit.wlt:281,1-296,2"
]

(* The original path of a rename is never an entry, also when it looks like one ("2 ..."), and the entry after it is
   still parsed. Statuses are relative to HEAD: added (or copied) then deleted is no change, renamed then deleted is a
   deleted original. *)
VerificationTest[
    Lookup[
        acpGitParseStatus[ nulJoin @ {
            "2 R. N... 100644 100644 100644 " <> $h <> " " <> $h <> " R100 3 notes.md",
            "2 notes.md",
            changed[ ".M", "zz.txt" ],
            "2 R. N... 100644 100644 100644 " <> $h <> " " <> $h <> " R100 b.txt",
            "2 R. N... fake",
            changed[ "AD", "added then deleted.txt" ],
            "2 RD N... 100644 100644 000000 " <> $h <> " " <> $h <> " R100 moved.txt",
            "orig.txt",
            "2 CD N... 100644 100644 000000 " <> $h <> " " <> $h <> " C100 copied.txt",
            "source.txt",
            "? new.txt"
        } ][ "Entries" ],
        { "Path", "OrigPath", "XY", "Status" }
    ],
    {
        { "3 notes.md", "2 notes.md"     , "R.", "Renamed"   },
        { "zz.txt"    , None             , ".M", "Modified"  },
        { "b.txt"     , "2 R. N... fake" , "R.", "Renamed"   },
        { "orig.txt"  , None             , "RD", "Deleted"   },
        { "new.txt"   , None             , "??", "Untracked" }
    },
    SameTest -> MatchQ,
    TestID   -> "ParseStatus-OriginalPaths@@Tests/ACPGit.wlt:301,1-327,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Numstat*)
VerificationTest[
    {
        acpGitParseNumstat @ nulJoin @ {
            "2\t1\tsrc/a.txt",
            "-\t-\timg.bin",
            "0\t0\t",
            "old name.txt",
            "new name.txt",
            "5\t0\ttab\there.txt",
            "1\t1\tvendor/lib"
        },
        acpGitParseNumstat[ "" ],
        acpGitParseNumstat[ None ]
    },
    {
        {
            <| "Path" -> "src/a.txt"   , "OrigPath" -> None          , "Added" -> 2   , "Deleted" -> 1   , "Binary" -> False |>,
            <| "Path" -> "img.bin"     , "OrigPath" -> None          , "Added" -> None, "Deleted" -> None, "Binary" -> True  |>,
            <| "Path" -> "new name.txt", "OrigPath" -> "old name.txt", "Added" -> 0   , "Deleted" -> 0   , "Binary" -> False |>,
            <| "Path" -> "tab\there.txt", "OrigPath" -> None         , "Added" -> 5   , "Deleted" -> 0   , "Binary" -> False |>,
            <| "Path" -> "vendor/lib"  , "OrigPath" -> None          , "Added" -> 1   , "Deleted" -> 1   , "Binary" -> False |>
        },
        { },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "ParseNumstat@@Tests/ACPGit.wlt:332,1-359,2"
]

(* A path field after a rename that looks like an entry itself is still a path *)
VerificationTest[
    acpGitParseNumstat @ nulJoin @ { "0\t0\t", "1\t2\tweird", "new", "3\t4\tx" },
    {
        <| "Path" -> "new", "OrigPath" -> "1\t2\tweird", "Added" -> 0, "Deleted" -> 0, "Binary" -> False |>,
        <| "Path" -> "x"  , "OrigPath" -> None          , "Added" -> 3, "Deleted" -> 4, "Binary" -> False |>
    },
    SameTest -> MatchQ,
    TestID   -> "ParseNumstat-RenamePaths@@Tests/ACPGit.wlt:362,1-370,2"
]

(* Many renames (e.g. git mv of a large folder) are parsed in linear time: 20,000 take well under a second *)
VerificationTest[
    Module[ { output, data, time },
        output = nulJoin @ Flatten @ Table[ { "0\t0\t", "old/f" <> ToString @ i, "new/f" <> ToString @ i }, { i, 20000 } ];
        time   = First @ AbsoluteTiming[ data = Wolfram`Chatbook`ACP`Git`Private`gitNumstatData @ output ];
        { Length @ data, data[ "new/f20000" ], time < 1.5 }
    ],
    { 20000, { 0, 0, "old/f20000" }, True },
    SameTest -> MatchQ,
    TestID   -> "ParseNumstat-ManyRenames@@Tests/ACPGit.wlt:373,1-382,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Other Output*)
VerificationTest[
    {
        acpGitParseRevParse[ "/home/user/repo\n\nsha1\n" ],
        acpGitParseRevParse[ "/home/user/repo\nsrc/lib/\nsha256\n" ],
        acpGitParseRevParse[ "/home/user/repo\n\n--show-object-format\n" ],
        acpGitParseRevParse[ "" ]
    },
    {
        <| "Root" -> "/home/user/repo", "Prefix" -> "", "ObjectFormat" -> "sha1" |>,
        <| "Root" -> "/home/user/repo", "Prefix" -> "src/lib/", "ObjectFormat" -> "sha256" |>,
        <| "Root" -> "/home/user/repo", "Prefix" -> "", "ObjectFormat" -> "sha1" |>,
        <| "Root" -> None, "Prefix" -> "", "ObjectFormat" -> "sha1" |>
    },
    SameTest -> MatchQ,
    TestID   -> "ParseRevParse@@Tests/ACPGit.wlt:387,1-402,2"
]

VerificationTest[
    {
        acpGitParseVersion[ "git version 2.53.0\n" ],
        acpGitParseVersion[ "git version 2.39.5 (Apple Git-154)\n" ],
        acpGitParseVersion[ "git version 2.45.1.windows.1\n" ],
        acpGitParseVersion[ "git version 3.0\n" ],
        acpGitParseVersion[ "something else" ],
        Wolfram`Chatbook`ACP`Git`Private`gitVersionAtLeastQ[ { 2, 25, 0 }, { 2, 25 } ],
        Wolfram`Chatbook`ACP`Git`Private`gitVersionAtLeastQ[ { 2, 24, 9 }, { 2, 25 } ],
        Wolfram`Chatbook`ACP`Git`Private`gitVersionAtLeastQ[ { 3, 0 }, { 2, 45 } ],
        Wolfram`Chatbook`ACP`Git`Private`gitVersionAtLeastQ[ None, { 2, 25 } ]
    },
    { { 2, 53, 0 }, { 2, 39, 5 }, { 2, 45, 1 }, { 3, 0 }, None, True, False, True, False },
    SameTest -> MatchQ,
    TestID   -> "ParseVersion@@Tests/ACPGit.wlt:404,1-419,2"
]

VerificationTest[
    {
        acpGitParseFilterDrivers @ nulJoin @ {
            "filter.lfs.clean\ngit-lfs clean -- %f",
            "filter.lfs.process\ngit-lfs filter-process",
            "filter.lfs.required\ntrue",
            "filter.with dots.and space.smudge\ncat",
            "filter..clean\nempty name",
            "filter.x=y.clean\nequals sign"
        },
        acpGitParseFilterDrivers[ "" ],
        Wolfram`Chatbook`ACP`Git`Private`gitFilterOverrides @ { "lfs", "" }
    },
    {
        { "lfs", "with dots.and space", "", "x=y" },
        { },
        {
            "filter.lfs.clean=", "filter.lfs.smudge=", "filter.lfs.process=", "filter.lfs.required=false",
            "filter..clean=", "filter..smudge=", "filter..process=", "filter..required=false"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ParseFilterDrivers@@Tests/ACPGit.wlt:421,1-444,2"
]

VerificationTest[
    {
        acpGitUnquotePath[ "plain name.txt" ],
        acpGitUnquotePath[ "\"quo\\\"te.txt\"" ],
        acpGitUnquotePath[ "\"tab\\there\\nnewline\\\\backslash\"" ],
        acpGitUnquotePath[ "\"\\303\\274n\\303\\257.txt\"" ],
        acpGitUnquotePath[ "\"a\\\\101\"" ],
        acpGitUnquotePath[ "\"\"" ]
    },
    { "plain name.txt", "quo\"te.txt", "tab\there\nnewline\\backslash", "\:00fcn\:00ef.txt", "a\\101", "" },
    SameTest -> MatchQ,
    TestID   -> "UnquotePath@@Tests/ACPGit.wlt:446,1-458,2"
]

VerificationTest[
    {
        acpGitDecode @ StringToByteArray[ "line 1\r\nl\:00efne 2\n", "UTF-8" ],
        acpGitDecode @ { StringToByteArray[ "ab", "UTF-8" ], ByteArray @ { 255, 99 } },
        acpGitDecode @ { },
        acpGitDecode @ None
    },
    { "line 1\nl\:00efne 2\n", "ab\:00ffc", "", "" },
    SameTest -> MatchQ,
    TestID   -> "Decode@@Tests/ACPGit.wlt:460,1-470,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Patches*)
VerificationTest[
    $patchLines = {
        "diff --git a/src/a.txt b/src/a.txt",
        "index 4cb29ea..6addb9b 100644",
        "--- a/src/a.txt",
        "+++ b/src/a.txt",
        "@@ -1,3 +1,4 @@",
        " one",
        "-two",
        "+TWO",
        " three",
        "+four",
        "diff --git a/new.txt b/new.txt",
        "new file mode 100644",
        "index 0000000..91d5523",
        "--- /dev/null",
        "+++ b/new.txt",
        "@@ -0,0 +1 @@",
        "+hello",
        "diff --git a/gone.txt b/gone.txt",
        "deleted file mode 100644",
        "index abaddc0..0000000",
        "--- a/gone.txt",
        "+++ /dev/null",
        "@@ -1 +0,0 @@",
        "-del",
        "diff --git a/old name.txt b/new name.txt",
        "similarity index 100%",
        "rename from old name.txt",
        "rename to new name.txt",
        "diff --git a/img.bin b/img.bin",
        "index 6772730..8d0cd2a 100644",
        "Binary files a/img.bin and b/img.bin differ",
        "diff --git a/mode.sh b/mode.sh",
        "old mode 100644",
        "new mode 100755",
        "diff --git a/vendor/lib b/vendor/lib",
        "index 6062d22..86b6f6d 160000",
        "--- a/vendor/lib",
        "+++ b/vendor/lib",
        "@@ -1 +1 @@",
        "-Subproject commit 6062d2221df3ac7addfcd0bba5a1faf1ab2076f3",
        "+Subproject commit 86b6f6d6e835c187ef09c436b4bc99c466c63641",
        "diff --git \"a/quo\\\"te.txt\" \"b/quo\\\"te.txt\"",
        "index bca70f3..8a08eba 100644",
        "--- \"a/quo\\\"te.txt\"",
        "+++ \"b/quo\\\"te.txt\"",
        "@@ -1 +1,2 @@",
        " q",
        "+r",
        "diff --git a/with space.txt b/with space.txt",
        "index 587be6b..b77b4eb 100644",
        "--- a/with space.txt\t",
        "+++ b/with space.txt\t",
        "@@ -1 +1,2 @@",
        " x",
        "+y",
        "diff --git a/tc.txt b/tc.txt",
        "deleted file mode 100644",
        "index 3cd5478..0000000",
        "--- a/tc.txt",
        "+++ /dev/null",
        "@@ -1 +0,0 @@",
        "-tc",
        "diff --git a/tc.txt b/tc.txt",
        "new file mode 120000",
        "index 0000000..9ce6ca3",
        "--- /dev/null",
        "+++ b/tc.txt",
        "@@ -0,0 +1 @@",
        "+src/a.txt",
        "\\ No newline at end of file",
        "diff --git a/extra.txt b/extra.txt",
        "index 1111111..2222222 100644",
        "--- a/extra.txt",
        "+++ b/extra.txt",
        "@@ -1 +1 @@",
        "-e",
        "+E",
        "diff --git a/empty.txt b/empty.txt",
        "new file mode 100644",
        "index 0000000..e69de29",
        ""
    };
    $patch  = StringRiffle[ $patchLines, "\n" ];
    $chunks = acpGitSplitPatch @ $patch;
    KeyTake[ #, { "OldPath", "NewPath", "Binary", "NewFile", "DeletedFile", "Rename", "Similarity", "OldMode", "NewMode", "Submodule" } ] & /@ $chunks,
    {
        <| "OldPath" -> "src/a.txt"    , "NewPath" -> "src/a.txt"    , "Binary" -> False, "NewFile" -> False, "DeletedFile" -> False, "Rename" -> False, "Similarity" -> None, "OldMode" -> "100644", "NewMode" -> "100644", "Submodule" -> False |>,
        <| "OldPath" -> None           , "NewPath" -> "new.txt"      , "Binary" -> False, "NewFile" -> True , "DeletedFile" -> False, "Rename" -> False, "Similarity" -> None, "OldMode" -> None    , "NewMode" -> "100644", "Submodule" -> False |>,
        <| "OldPath" -> "gone.txt"     , "NewPath" -> None           , "Binary" -> False, "NewFile" -> False, "DeletedFile" -> True , "Rename" -> False, "Similarity" -> None, "OldMode" -> "100644", "NewMode" -> None    , "Submodule" -> False |>,
        <| "OldPath" -> "old name.txt" , "NewPath" -> "new name.txt" , "Binary" -> False, "NewFile" -> False, "DeletedFile" -> False, "Rename" -> True , "Similarity" -> 100 , "OldMode" -> None    , "NewMode" -> None    , "Submodule" -> False |>,
        <| "OldPath" -> "img.bin"      , "NewPath" -> "img.bin"      , "Binary" -> True , "NewFile" -> False, "DeletedFile" -> False, "Rename" -> False, "Similarity" -> None, "OldMode" -> "100644", "NewMode" -> "100644", "Submodule" -> False |>,
        <| "OldPath" -> "mode.sh"      , "NewPath" -> "mode.sh"      , "Binary" -> False, "NewFile" -> False, "DeletedFile" -> False, "Rename" -> False, "Similarity" -> None, "OldMode" -> "100644", "NewMode" -> "100755", "Submodule" -> False |>,
        <| "OldPath" -> "vendor/lib"   , "NewPath" -> "vendor/lib"   , "Binary" -> False, "NewFile" -> False, "DeletedFile" -> False, "Rename" -> False, "Similarity" -> None, "OldMode" -> "160000", "NewMode" -> "160000", "Submodule" -> True  |>,
        <| "OldPath" -> "quo\"te.txt"  , "NewPath" -> "quo\"te.txt"  , "Binary" -> False, "NewFile" -> False, "DeletedFile" -> False, "Rename" -> False, "Similarity" -> None, "OldMode" -> "100644", "NewMode" -> "100644", "Submodule" -> False |>,
        <| "OldPath" -> "with space.txt", "NewPath" -> "with space.txt", "Binary" -> False, "NewFile" -> False, "DeletedFile" -> False, "Rename" -> False, "Similarity" -> None, "OldMode" -> "100644", "NewMode" -> "100644", "Submodule" -> False |>,
        <| "OldPath" -> "tc.txt"       , "NewPath" -> None           , "Binary" -> False, "NewFile" -> False, "DeletedFile" -> True , "Rename" -> False, "Similarity" -> None, "OldMode" -> "100644", "NewMode" -> None    , "Submodule" -> False |>,
        <| "OldPath" -> None           , "NewPath" -> "tc.txt"       , "Binary" -> False, "NewFile" -> True , "DeletedFile" -> False, "Rename" -> False, "Similarity" -> None, "OldMode" -> None    , "NewMode" -> "120000", "Submodule" -> False |>,
        <| "OldPath" -> "extra.txt"    , "NewPath" -> "extra.txt"    , "Binary" -> False, "NewFile" -> False, "DeletedFile" -> False, "Rename" -> False, "Similarity" -> None, "OldMode" -> "100644", "NewMode" -> "100644", "Submodule" -> False |>,
        <| "OldPath" -> None           , "NewPath" -> "empty.txt"    , "Binary" -> False, "NewFile" -> True , "DeletedFile" -> False, "Rename" -> False, "Similarity" -> None, "OldMode" -> None    , "NewMode" -> "100644", "Submodule" -> False |>
    },
    SameTest -> MatchQ,
    TestID   -> "SplitPatch-Paths@@Tests/ACPGit.wlt:475,1-579,2"
]

VerificationTest[
    {
        $chunks[[ 1, "Header" ]],
        $chunks[[ 1, "Hunks" ]],
        Lookup[ $chunks, "Hunks" ][[ { 4, 5, 6, 13 } ]],
        $chunks[[ 11, "Hunks" ]],
        acpGitSplitPatch[ "" ],
        acpGitSplitPatch[ "* Unmerged path x\n" ],
        acpGitSplitPatch[ None ]
    },
    {
        "diff --git a/src/a.txt b/src/a.txt\nindex 4cb29ea..6addb9b 100644\n--- a/src/a.txt\n+++ b/src/a.txt",
        "@@ -1,3 +1,4 @@\n one\n-two\n+TWO\n three\n+four",
        { None, None, None, None },
        "@@ -0,0 +1 @@\n+src/a.txt\n\\ No newline at end of file",
        { },
        { },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "SplitPatch-Hunks@@Tests/ACPGit.wlt:581,1-602,2"
]

(* Splitting is linear in the size of the patch: one file with 50,000 changed lines, or 20,000 small files *)
VerificationTest[
    Module[ { one, many, t1, t2, c1, c2 },
        one  = StringJoin[
            "diff --git a/x b/x\nindex 1111111..2222222 100644\n--- a/x\n+++ b/x\n@@ -1,50000 +1,50000 @@\n",
            Table[ { "-a", ToString @ k, "\n+b", ToString @ k, "\n" }, { k, 50000 } ]
        ];
        many = StringJoin @ Table[
            "diff --git a/d/f" <> ToString @ i <> ".js b/d/f" <> ToString @ i <> ".js\nindex 1111111..2222222 100644\n--- a/d/f" <>
                ToString @ i <> ".js\n+++ b/d/f" <> ToString @ i <> ".js\n@@ -1,3 +1,3 @@\n a\n-b\n+c\n d\n",
            { i, 20000 }
        ];
        t1 = First @ AbsoluteTiming[ c1 = acpGitSplitPatch @ one ];
        t2 = First @ AbsoluteTiming[ c2 = acpGitSplitPatch @ many ];
        {
            Length @ c1,
            StringCount[ c1[[ 1, "Hunks" ]], "\n" ],
            t1 < 1,
            Length @ c2,
            c2[[ -1 ]][ "NewPath" ],
            c2[[ -1 ]][ "Hunks" ],
            t2 < 5
        }
    ],
    { 1, 100000, True, 20000, "d/f20000.js", "@@ -1,3 +1,3 @@\n a\n-b\n+c\n d", True },
    SameTest -> MatchQ,
    TestID   -> "SplitPatch-Cost@@Tests/ACPGit.wlt:605,1-631,2"
]

(* Paths of "diff --git" lines (used when a chunk has no ---/+++ or rename lines) *)
VerificationTest[
    Wolfram`Chatbook`ACP`Git`Private`gitDiffHeaderPaths /@ {
        "a/x b/y b/x b/y",
        "a/plain.txt b/plain.txt",
        "\"a/tab\\there\" \"b/tab\\there\"",
        "a/old \"b/new\\\"name\"",
        "a/one b/two"
    },
    { { "x b/y", "x b/y" }, { "plain.txt", "plain.txt" }, { "tab\there", "tab\there" }, { "old", "new\"name" }, { "one", "two" } },
    SameTest -> MatchQ,
    TestID   -> "SplitPatch-HeaderPaths@@Tests/ACPGit.wlt:634,1-645,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Change Sets*)
VerificationTest[
    $csInput = <|
        "Directory" -> "/repo",
        "Root"      -> "/repo",
        "Prefix"    -> "",
        "Status"    -> nulJoin @ {
            "# branch.oid " <> $h,
            "# branch.head main",
            changed[ "A.", "empty.txt" ],
            changed[ ".D", "gone.txt" ],
            changed[ ".M", "img.bin" ],
            changed[ ".M", "mode.sh" ],
            "2 R. N... 100644 100644 100644 " <> $h <> " " <> $h <> " R100 new name.txt",
            "old name.txt",
            changed[ "A.", "new.txt" ],
            changed[ ".M", "quo\"te.txt" ],
            changed[ ".M", "src/a.txt" ],
            changed[ ".T", "tc.txt" ],
            "1 .M SC.. 160000 160000 160000 " <> $h <> " " <> $h <> " vendor/lib",
            changed[ ".M", "with space.txt" ],
            "? data.bin",
            "? nested/",
            "? notes.md",
            "? zz-unread.txt"
        },
        "Numstat"   -> nulJoin @ {
            "0\t0\tempty.txt", "0\t1\tgone.txt", "-\t-\timg.bin", "0\t0\tmode.sh", "0\t0\t", "old name.txt", "new name.txt",
            "1\t0\tnew.txt", "1\t0\tquo\"te.txt", "2\t1\tsrc/a.txt", "1\t1\ttc.txt", "1\t1\tvendor/lib", "1\t0\twith space.txt",
            "1\t1\textra.txt"
        },
        "Patch"     -> $patch,
        "Untracked" -> <|
            "notes.md" -> <| "Added" -> 2, "Binary" -> False, "Content" -> "x\ny\n", "Note" -> None |>,
            "data.bin" -> <| "Added" -> None, "Binary" -> True, "Content" -> None, "Note" -> "Binary" |>
        |>
    |>;
    $cs = acpGitBuildChangeSet @ $csInput;
    KeyDrop[ $cs, { "Files", "CheckedAt" } ],
    <|
        "Token"          -> None,
        "Directory"      -> "/repo",
        "Status"         -> "Changes",
        "Error"          -> None,
        "Git"            -> None,
        "GitVersion"     -> None,
        "Root"           -> "/repo",
        "Prefix"         -> "",
        "ObjectFormat"   -> "sha1",
        "Branch"         -> "main",
        "Detached"       -> False,
        "Initial"        -> False,
        "OID"            -> $h,
        "FileCount"      -> 16, (* 15 status entries and extra.txt, which is only in the patch *)
        "MoreFiles"      -> 0,
        "Added"          -> 9,  (* tracked text files without the submodule (7), and notes.md (2) *)
        "Deleted"        -> 4,
        "Mode"           -> "Full",
        "PatchComplete"  -> True,
        "CountsComplete" -> True,
        "Duration"       -> 0
    |>,
    SameTest -> MatchQ,
    TestID   -> "ChangeSet-Summary@@Tests/ACPGit.wlt:650,1-713,2"
]

VerificationTest[
    Map[
        Lookup[ #, { "Status", "XY", "Added", "Deleted", "Binary", "Directory", "Note" } ] &,
        filesByPath @ $cs
    ],
    <|
        "data.bin"       -> { "Untracked"  , "??", None, None, True , False, "Binary"      },
        "empty.txt"      -> { "Added"      , "A.", 0   , 0   , False, False, "Empty"       },
        "extra.txt"      -> { "Modified"   , ""  , 1   , 1   , False, False, None          },
        "gone.txt"       -> { "Deleted"    , ".D", 0   , 1   , False, False, None          },
        "img.bin"        -> { "Modified"   , ".M", None, None, True , False, "Binary"      },
        "mode.sh"        -> { "Modified"   , ".M", 0   , 0   , False, False, "ModeChanged" },
        "nested/"        -> { "Untracked"  , "??", None, None, False, True , "Directory"   },
        "new name.txt"   -> { "Renamed"    , "R.", 0   , 0   , False, False, "Renamed"     },
        "new.txt"        -> { "Added"      , "A.", 1   , 0   , False, False, None          },
        "notes.md"       -> { "Untracked"  , "??", 2   , 0   , False, False, None          },
        "quo\"te.txt"    -> { "Modified"   , ".M", 1   , 0   , False, False, None          },
        "src/a.txt"      -> { "Modified"   , ".M", 2   , 1   , False, False, None          },
        "tc.txt"         -> { "TypeChanged", ".T", 1   , 1   , False, False, None          },
        "vendor/lib"     -> { "Submodule"  , ".M", None, None, False, False, "Submodule"   },
        "with space.txt" -> { "Modified"   , ".M", 1   , 0   , False, False, None          },
        "zz-unread.txt"  -> { "Untracked"  , "??", None, None, False, False, "NotRead"     }
    |>,
    SameTest -> (KeySort[ #1 ] === KeySort[ #2 ] &),
    TestID   -> "ChangeSet-Files@@Tests/ACPGit.wlt:715,1-740,2"
]

VerificationTest[
    With[ { files = filesByPath @ $cs },
        {
            (* natural path order (here the same as git's order by code points): *)
            Lookup[ $cs[ "Files" ], "Path" ] === {
                "data.bin", "empty.txt", "extra.txt", "gone.txt", "img.bin", "mode.sh", "nested/", "new name.txt",
                "new.txt", "notes.md", "quo\"te.txt", "src/a.txt", "tc.txt", "vendor/lib", "with space.txt", "zz-unread.txt"
            },
            KeyTake[ files[ "src/a.txt" ], { "RepoPath", "FullPath", "OrigPath", "Header", "Patch", "Content", "OldMode", "NewMode" } ],
            KeyTake[ files[ "new name.txt" ], { "OrigPath", "OrigRepoPath", "Patch" } ],
            Lookup[ files[ "tc.txt" ], { "Patch", "OldMode", "NewMode" } ],
            Lookup[ files[ "notes.md" ], { "Content", "Header", "Patch" } ],
            files[ "with space.txt", "Patch" ]
        }
    ],
    {
        True,
        <|
            "RepoPath" -> "src/a.txt",
            "FullPath" -> FileNameJoin @ { "/repo", "src", "a.txt" },
            "OrigPath" -> None,
            "Header"   -> "diff --git a/src/a.txt b/src/a.txt\nindex 4cb29ea..6addb9b 100644\n--- a/src/a.txt\n+++ b/src/a.txt",
            "Patch"    -> "@@ -1,3 +1,4 @@\n one\n-two\n+TWO\n three\n+four",
            "Content"  -> None,
            "OldMode"  -> "100644",
            "NewMode"  -> "100644"
        |>,
        <| "OrigPath" -> "old name.txt", "OrigRepoPath" -> "old name.txt", "Patch" -> None |>,
        { "@@ -1 +0,0 @@\n-tc\n@@ -0,0 +1 @@\n+src/a.txt\n\\ No newline at end of file", "100644", "120000" },
        { "x\ny\n", None, None },
        "@@ -1 +1,2 @@\n x\n+y"
    },
    SameTest -> MatchQ,
    TestID   -> "ChangeSet-Patches@@Tests/ACPGit.wlt:742,1-776,2"
]

(* Files are listed in natural path order: folder by folder (the files of a folder stay together, also folders whose
   names differ only in case), ignoring case, numbers by value; names that are equal in natural order are in git's
   order *)
VerificationTest[
    Module[ { order, paths },
        order[ paths_List ] := paths[[ Wolfram`Chatbook`ACP`Git`Private`gitNaturalOrdering @ paths ]];
        paths = {
            "Data/x3.json", "Kernel/x", "README.md", "a.txt", "a/b", "a-b/c", "data/x2.json", "lib/a01.h", "lib/a1/b.c",
            "lib/a1/d.c", "src-old/a.py", "src.txt", "src/mod1.py", "src/mod10.py", "src/mod11.py", "src/mod12.py",
            "src/mod2.py", "v1.10.txt", "v1.9.txt", "x/file02", "x/file1", "x/file2", "z/a", "z10/a", "z9/a"
        };
        {
            order @ paths,
            order @ Reverse @ paths === order @ paths,
            order @ { },
            order @ { "b", "B", "a" },
            (* the listed files of a change set *)
            Lookup[
                acpGitBuildChangeSet[ <| "Directory" -> "/repo", "Status" -> nulJoin[ changed[ ".M", # ] & /@ Sort[ paths ] ] |> ][ "Files" ],
                "Path"
            ] === order @ paths
        }
    ],
    {
        {
            "a/b", "a-b/c", "a.txt", "Data/x3.json", "data/x2.json", "Kernel/x", "lib/a1/b.c", "lib/a1/d.c", "lib/a01.h",
            "README.md", "src/mod1.py", "src/mod2.py", "src/mod10.py", "src/mod11.py", "src/mod12.py", "src-old/a.py",
            "src.txt", "v1.9.txt", "v1.10.txt", "x/file1", "x/file02", "x/file2", "z/a", "z9/a", "z10/a"
        },
        True,
        { },
        { "a", "B", "b" },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ChangeSet-NaturalOrder@@Tests/ACPGit.wlt:781,1-814,2"
]

(* Ordering the listed files is cheap: 500 files with long paths take well under a second *)
VerificationTest[
    Module[ { paths },
        paths = Table[ StringRiffle[ { "Source", "Package" <> ToString @ Mod[ i, 7 ], "Sub" <> ToString @ Mod[ i, 13 ], "file_" <> ToString @ i <> "_name.wl" }, "/" ], { i, 500 } ];
        { Sort @ Wolfram`Chatbook`ACP`Git`Private`gitNaturalOrdering @ paths === Range[ 500 ], First @ AbsoluteTiming @ Wolfram`Chatbook`ACP`Git`Private`gitNaturalOrdering @ paths }
    ],
    { True, _? (# < 0.5 &) },
    SameTest -> MatchQ,
    TestID   -> "ChangeSet-NaturalOrderCost@@Tests/ACPGit.wlt:817,1-825,2"
]

(* The project directory is a subdirectory of the repository: paths are relative to it *)
VerificationTest[
    Module[ { cs },
        cs = acpGitBuildChangeSet @ <|
            "Directory" -> "/repo/src",
            "Root"      -> "/repo",
            "Prefix"    -> "src/",
            "Status"    -> nulJoin @ {
                "# branch.oid (initial)",
                "# branch.head main",
                changed[ "A.", "src/a.txt" ],
                "2 R. N... 100644 100644 100644 " <> $h <> " " <> $h <> " R90 src/x.txt",
                "lib/x.txt",
                "? src/deep/u.txt"
            },
            "Numstat"   -> None
        |>;
        {
            cs[ "Mode" ],
            cs[ "Initial" ],
            Lookup[ cs[ "Files" ], { "Path", "RepoPath", "OrigPath", "FullPath", "Note", "Patch" } ]
        }
    ],
    {
        "Summary",
        True,
        {
            { "a.txt"     , "src/a.txt"     , None           , FileNameJoin @ { "/repo", "src", "a.txt" }      , None     , None },
            { "deep/u.txt", "src/deep/u.txt", None           , FileNameJoin @ { "/repo", "src", "deep", "u.txt" }, "NotRead", None },
            { "x.txt"     , "src/x.txt"     , "../lib/x.txt" , FileNameJoin @ { "/repo", "src", "x.txt" }      , None     , None }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ChangeSet-Prefix@@Tests/ACPGit.wlt:828,1-861,2"
]

VerificationTest[
    Wolfram`Chatbook`ACP`Git`Private`gitProjectPath @@@ {
        { "src/a.txt", "src/" },
        { "lib/x.txt", "src/" },
        { "src2/x", "src/" },
        { "x/y/z", "x/w/" },
        { "a", "" },
        { "a/b/", "a/" }
    },
    { "a.txt", "../lib/x.txt", "../src2/x", "../y/z", "a", "b/" },
    SameTest -> MatchQ,
    TestID   -> "ChangeSet-ProjectPath@@Tests/ACPGit.wlt:863,1-875,2"
]

VerificationTest[
    Block[ { $acpGitMaxFiles = 3 },
        With[ { cs = acpGitBuildChangeSet @ $csInput },
            { cs[ "FileCount" ], cs[ "MoreFiles" ], Length @ cs[ "Files" ], cs[ "Added" ], cs[ "Deleted" ] }
        ]
    ],
    { 16, 13, 3, 7, 4 }, (* notes.md is not listed, so its lines are not counted *)
    SameTest -> MatchQ,
    TestID   -> "ChangeSet-MaxFiles@@Tests/ACPGit.wlt:877,1-886,2"
]

VerificationTest[
    {
        KeyTake[
            acpGitBuildChangeSet @ <| "Directory" -> "/repo", "Status" -> nulJoin @ { "# branch.oid " <> $h, "# branch.head main" }, "Patch" -> "" |>,
            { "Status", "Files", "FileCount", "MoreFiles", "Added", "Deleted", "Root" }
        ],
        (* git's patch was cut short before src/a.txt: *)
        Lookup[
            First @ acpGitBuildChangeSet[ <| "Directory" -> "/repo", "Status" -> nulJoin @ { changed[ ".M", "src/a.txt" ] }, "Patch" -> { }, "PatchComplete" -> False |> ][ "Files" ],
            { "Note", "Patch" }
        ],
        Lookup[
            First @ acpGitBuildChangeSet[ <| "Directory" -> "/repo", "Status" -> nulJoin @ { changed[ ".M", "src/a.txt" ] }, "Patch" -> { } |> ][ "Files" ],
            { "Note", "Patch" }
        ]
    },
    {
        <| "Status" -> "Clean", "Files" -> { }, "FileCount" -> 0, "MoreFiles" -> 0, "Added" -> 0, "Deleted" -> 0, "Root" -> "/repo" |>,
        { "PatchUnavailable", None },
        { "NoDiff", None }
    },
    SameTest -> MatchQ,
    TestID   -> "ChangeSet-CleanAndIncomplete@@Tests/ACPGit.wlt:888,1-911,2"
]

(* After git rm --cached, a path is both a deleted and an untracked file: the untracked one shows its own content, not
   the deletion *)
VerificationTest[
    Module[ { cs },
        cs = acpGitBuildChangeSet @ <|
            "Directory" -> "/repo",
            "Status"    -> nulJoin @ { changed[ "D.", "keep.txt" ], "? keep.txt" },
            "Numstat"   -> nulJoin @ { "0\t2\tkeep.txt" },
            "Patch"     -> "diff --git a/keep.txt b/keep.txt\ndeleted file mode 100644\nindex 1111111..0000000\n--- a/keep.txt\n+++ /dev/null\n@@ -1,2 +0,0 @@\n-a\n-b\n",
            "Untracked" -> <| "keep.txt" -> <| "Added" -> 2, "Binary" -> False, "Content" -> "a\nb\n", "Note" -> None |> |>
        |>;
        { Lookup[ cs, { "FileCount", "Added", "Deleted" } ], Lookup[ cs[ "Files" ], { "Status", "Added", "Deleted", "Patch", "Content" } ] }
    ],
    {
        { 2, 2, 2 },
        {
            { "Deleted"  , 0, 2, "@@ -1,2 +0,0 @@\n-a\n-b", None },
            { "Untracked", 2, 0, None, "a\nb\n" }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ChangeSet-RemovedFromIndex@@Tests/ACPGit.wlt:915,1-935,2"
]

(* git status (HEAD and index) and git diff -M (HEAD and working tree) can see renames differently: a rename only the
   diff finds is one renamed file; a rename only status finds counts the lines of both files *)
VerificationTest[
    Module[ { pair, split },
        pair = acpGitBuildChangeSet @ <|
            "Directory" -> "/repo",
            "Status"    -> nulJoin @ { changed[ "A.", "new.txt" ], changed[ ".D", "old.txt" ] },
            "Numstat"   -> nulJoin @ { "0\t0\t", "old.txt", "new.txt" },
            "Patch"     -> "diff --git a/old.txt b/new.txt\nsimilarity index 100%\nrename from old.txt\nrename to new.txt\n"
        |>;
        split = acpGitBuildChangeSet[ $splitInput = <|
            "Directory" -> "/repo",
            "Status"    -> nulJoin @ { "2 RM N... 100644 100644 100644 " <> $h <> " " <> $h <> " R100 b.txt", "a.txt" },
            "Numstat"   -> nulJoin @ { "0\t2\ta.txt", "3\t0\tb.txt" },
            "Patch"     -> StringJoin[
                "diff --git a/a.txt b/a.txt\ndeleted file mode 100644\nindex 1111111..0000000\n--- a/a.txt\n+++ /dev/null\n@@ -1,2 +0,0 @@\n-a\n-b\n",
                "diff --git a/b.txt b/b.txt\nnew file mode 100644\nindex 0000000..2222222\n--- /dev/null\n+++ b/b.txt\n@@ -0,0 +1,3 @@\n+1\n+2\n+3\n"
            ]
        |> ];
        {
            Lookup[ pair, { "FileCount", "Added", "Deleted" } ],
            Lookup[ pair[ "Files" ], { "Path", "OrigPath", "Status", "Added", "Deleted", "Note" } ],
            Lookup[ split, { "FileCount", "Added", "Deleted" } ],
            Lookup[ split[ "Files" ], { "Path", "OrigPath", "Status", "Added", "Deleted", "Note" } ],
            (* the same counts without the patch (summary checks) *)
            Lookup[ First @ acpGitBuildChangeSet[ KeyDrop[ $splitInput, "Patch" ] ][ "Files" ], { "Added", "Deleted" } ]
        }
    ],
    {
        { 1, 0, 0 },
        { { "new.txt", "old.txt", "Renamed", 0, 0, "Renamed" } },
        { 1, 3, 2 },
        { { "b.txt", "a.txt", "Renamed", 3, 2, None } },
        { 3, 2 }
    },
    SameTest -> MatchQ,
    TestID   -> "ChangeSet-RenamesDisagree@@Tests/ACPGit.wlt:939,1-974,2"
]

(* Many untracked files (e.g. a generated directory that is not ignored): only the first $acpGitMaxFiles are listed *)
VerificationTest[
    Module[ { status, changes, time },
        status = nulJoin @ Join[
            { "# branch.oid " <> $h, "# branch.head main", changed[ ".M", "b.txt" ] },
            Table[ "? gen/f" <> IntegerString[ i, 10, 5 ] <> ".js", { i, 20000 } ]
        ];
        time = First @ AbsoluteTiming[
            changes = acpGitBuildChangeSet @ <| "Directory" -> "/repo", "Status" -> status, "Numstat" -> nulJoin @ { "1\t0\tb.txt" } |>
        ];
        {
            Lookup[ changes, { "FileCount", "MoreFiles", "Added", "Deleted" } ],
            Length @ changes[ "Files" ],
            changes[ "Files" ][[ { 1, 2, -1 }, "Path" ]],
            time < 5
        }
    ],
    { { 20001, 19501, 1, 0 }, 500, { "b.txt", "gen/f00001.js", "gen/f00499.js" }, True },
    SameTest -> MatchQ,
    TestID   -> "ChangeSet-ManyUntrackedFiles@@Tests/ACPGit.wlt:977,1-996,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Window Summary*)
VerificationTest[
    {
        acpGitSummary @ <| "Status" -> "Ready", "ProjectDirectory" -> "/p" |>,
        acpGitSummary @ <| "Status" -> "Ready", "ProjectDirectory" -> "/p", "Git" -> <| "Directory" -> "/p", "Status" -> "Clean" |> |>,
        acpGitSummary @ NotebookObject[ "acp-git-no-such-window" ],
        acpGitSummary @ None
    },
    {
        KeyValuePattern @ { "Directory" -> "/p", "Status" -> "Unknown", "FileCount" -> 0, "InFlight" -> False, "Stale" -> False },
        KeyValuePattern @ { "Directory" -> "/p", "Status" -> "Clean", "FileCount" -> 0, "Token" -> None },
        KeyValuePattern @ { "Directory" -> None, "Status" -> "Unknown" },
        KeyValuePattern @ { "Directory" -> None, "Status" -> "Unknown" }
    },
    SameTest -> MatchQ,
    TestID   -> "Summary-Defaults@@Tests/ACPGit.wlt:1001,1-1016,2"
]

(* Which housekeeping action each window state leads to (the actions are replaced by recorders) *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-git-housekeeping" ], hk, base, git },
        hk[ window_, now_ ] := Module[ { calls = { } },
            Block[
                {
                    acpGitCheck = (AppendTo[ calls, "Check" ]; "token") &,
                    Wolfram`Chatbook`ACP`Git`Private`gitResetSummary = (AppendTo[ calls, "Reset" ]; Null) &,
                    Wolfram`Chatbook`ACP`Git`Private`gitCheckLost = (AppendTo[ calls, "Lost" ]; Null) &
                },
                Wolfram`Chatbook`ACP`Git`Private`gitWindowHousekeeping[ nbo, window, now ]
            ];
            calls
        ];
        base = <| "Status" -> "Ready", "ProjectDirectory" -> "/p", "CurrentTurn" -> None |>;
        git  = <| "Directory" -> "/p", "Status" -> "Clean", "CheckedAt" -> 980.0, "Duration" -> 0.1, "StartedAt" -> 979.9, "InFlight" -> False, "Stale" -> False, "Paused" -> False |>;
        {
            hk[ base, 1000.0 ],                                                                   (* no summary yet *)
            hk[ <| base, "Git" -> <| git, "Directory" -> "/old" |> |>, 1000.0 ],                  (* directory changed *)
            hk[ <| base, "ProjectDirectory" -> None |>, 1000.0 ],                                 (* no directory *)
            hk[ <| base, "ProjectDirectory" -> None, "Git" -> <| git, "Directory" -> None |> |>, 1000.0 ],
            hk[ <| base, "Git" -> <| git, "InFlight" -> True, "StartedAt" -> 990.0 |> |>, 1000.0 ],
            hk[ <| base, "Git" -> <| git, "InFlight" -> True, "StartedAt" -> 800.0 |> |>, 1000.0 ], (* lost *)
            hk[ <| base, "Git" -> <| git, "Stale" -> True, "StartedAt" -> 999.0 |> |>, 1000.0 ],   (* debounced *)
            hk[ <| base, "Git" -> <| git, "Stale" -> True, "StartedAt" -> 990.0 |> |>, 1000.0 ],
            hk[ <| base, "Git" -> <| git, "Stale" -> True, "Paused" -> True |> |>, 1000.0 ],
            hk[ <| base, "Git" -> git |>, 1000.0 ],                                               (* idle for 20 s *)
            hk[ <| base, "Git" -> git |>, 990.0 ],                                                (* idle for 10 s *)
            hk[ <| base, "Git" -> <| git, "Duration" -> 1.0 |> |>, 1000.0 ],                      (* slow checks: every 30 s *)
            hk[ <| base, "CurrentTurn" -> "turn", "Git" -> git |>, 1000.0 ],                      (* not idle *)
            hk[ <| base, "Git" -> <| git, "Paused" -> True |> |>, 1000.0 ],                       (* paused after a timeout *)
            hk[ <| "Notebook" -> nbo |>, 1000.0 ]                                                 (* partial record *)
        }
    ],
    {
        { "Check" },
        { "Check" },
        { "Reset" },
        { },
        { },
        { "Lost" },
        { },
        { "Check" },
        { "Check" },
        { "Check" },
        { },
        { },
        { },
        { },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "Summary-HousekeepingDecisions@@Tests/ACPGit.wlt:1019,1-1071,2"
]

(* Completed tool calls that may have changed files mark the summary stale (reader handler: kernel state only) *)
VerificationTest[
    Block[ { $acpGitEnabled = False },
        Module[ { nbo, turnID = "acp-git-hook-turn", apply, result },
            nbo = newWindow @ $gitScratch;
            acpTurnCreate @ acpNewTurn @ <| "ID" -> turnID, "Notebook" -> nbo, "SessionID" -> "s", "Prompt" -> "x", "StartTime" -> AbsoluteTime[ ] |>;
            apply[ update_ ] := (
                acpTurnUpdate[ turnID, acpApplyUpdate[ #, update, AbsoluteTime[ ] ] & ];
                acpGitNoteSessionUpdate[ nbo, turnID, update ];
                acpGitSummary[ nbo ][ "Stale" ]
            );
            result = {
                apply @ <| "sessionUpdate" -> "tool_call", "toolCallId" -> "t1", "title" -> "Read a.txt", "kind" -> "read", "status" -> "pending" |>,
                apply @ <| "sessionUpdate" -> "tool_call_update", "toolCallId" -> "t1", "status" -> "completed" |>,
                apply @ <| "sessionUpdate" -> "tool_call", "toolCallId" -> "t2", "title" -> "Edit a.txt", "kind" -> "edit", "status" -> "pending" |>,
                apply @ <| "sessionUpdate" -> "tool_call_update", "toolCallId" -> "t2", "status" -> "in_progress" |>,
                apply @ <| "sessionUpdate" -> "tool_call_update", "toolCallId" -> "t2", "status" -> "completed" |>
            };
            acpGitMarkStale @ NotebookObject[ "acp-git-no-such-window" ];
            acpTurnDrop @ turnID;
            acpWindowDrop @ nbo;
            {
                result,
                acpWindowGet @ NotebookObject[ "acp-git-no-such-window" ],
                Wolfram`Chatbook`ACP`Git`Private`gitFileChangingToolQ /@ {
                    <| "Name" -> "shell", "Kind" -> "execute" |>,
                    <| "Name" -> "grep", "Kind" -> "search" |>,
                    <| "Name" -> "wolfram_evaluate", "Kind" -> "other" |>,
                    <| "Name" -> None, "Kind" -> None |>,
                    <| "Name" -> "write", "Kind" -> None |>
                }
            }
        ]
    ],
    { { False, False, False, False, True }, _Missing, { True, False, True, True, True } },
    SameTest -> MatchQ,
    TestID   -> "Summary-ToolCallsMarkStale@@Tests/ACPGit.wlt:1074,1-1110,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Running Commands*)
VerificationTest[
    ifShTests @ Module[ { result },
        result = runSync[
            { "-c", "printf 'out \\303\\274\\r\\n'; printf 'err' >&2; printf '\\377' ; exit 3" },
            $gitScratch,
            <| "Git" -> "/bin/sh" |>
        ];
        KeyDrop[ result, "Duration" ]
    ],
    Missing[ "TestSkipped" ] | <|
        "ExitCode"    -> 3,
        "Output"      -> "out \:00fc\n\:00ff",
        "Error"       -> "err",
        "TimedOut"    -> False,
        "TooLarge"    -> False,
        "Cancelled"   -> False,
        "StartFailed" -> False,
        "Arguments"   -> { "-c", _String }
    |>,
    SameTest -> MatchQ,
    TestID   -> "Run-OutputAndExitCode@@Tests/ACPGit.wlt:1115,1-1136,2"
]

VerificationTest[
    ifShTests @ Module[ { slow, large, missing },
        slow    = runSync[ { "-c", "sleep 30" }, $gitScratch, <| "Git" -> "/bin/sh", "Timeout" -> 0.5 |> ];
        large   = runSync[ { "-c", "head -c 200000 /dev/zero" }, $gitScratch, <| "Git" -> "/bin/sh", "MaxOutput" -> 1000 |> ];
        missing = runSync[ { "--version" }, $gitScratch, <| "Git" -> FileNameJoin @ { $gitScratch, "no-such-git" } |> ];
        {
            Lookup[ slow, { "ExitCode", "TimedOut", "TooLarge" } ],
            slow[ "Duration" ] < 5,
            Lookup[ large, { "ExitCode", "TimedOut", "TooLarge" } ],
            StringLength @ large[ "Output" ] === 1000, (* cut at the cap *)
            Lookup[ missing, { "ExitCode", "StartFailed", "Output" } ],
            Wolfram`Chatbook`ACP`Git`Private`$gitRuns
        }
    ],
    Missing[ "TestSkipped" ] | { { None, True, False }, True, { None, False, True }, True, { None, True, "" }, <| |> },
    SameTest -> MatchQ,
    TestID   -> "Run-TimeoutTooLargeStartFailed@@Tests/ACPGit.wlt:1138,1-1155,2"
]

(* A fast writer: each poll reads a bounded amount, so the output cap and the timeout hold (a read of everything that is
   available goes on for as long as the process writes, and could return all of it) *)
VerificationTest[
    ifShTests @ Module[ { large, slow },
        large = runSync[ { "-c", "head -c 64000000 /dev/zero" }, $gitScratch, <| "Git" -> "/bin/sh", "MaxOutput" -> 2^20 |> ];
        slow  = runSync[ { "-c", "head -c 64000000 /dev/zero" }, $gitScratch, <| "Git" -> "/bin/sh", "MaxOutput" -> 2^30, "Timeout" -> 0.2 |> ];
        {
            Lookup[ large, { "TooLarge", "TimedOut" } ],
            StringLength @ large[ "Output" ],
            large[ "Duration" ] < 2,
            Lookup[ slow, { "TooLarge", "TimedOut" } ],
            slow[ "Duration" ] < 2,
            StringLength @ slow[ "Output" ] < 64000000
        }
    ],
    Missing[ "TestSkipped" ] | { { True, False }, 1048576, True, { False, True }, True, True },
    SameTest -> MatchQ,
    TestID   -> "Run-FastWriterBounded@@Tests/ACPGit.wlt:1159,1-1175,2"
]

(* A command of a request that was superseded is killed *)
VerificationTest[
    ifShTests @ Module[ { result = None, pid },
        Wolfram`Chatbook`ACP`Git`Private`$gitCurrentRequests[ "acp-git-test-key" ] = "t1";
        acpGitRun[ { "-c", "echo $$; exec sleep 30" }, $gitScratch, (result = #) &, <| "Git" -> "/bin/sh", "Request" -> { "acp-git-test-key", "t1" } |> ];
        Pause[ 0.5 ];
        Wolfram`Chatbook`ACP`Git`Private`$gitCurrentRequests[ "acp-git-test-key" ] = "t2";
        waitUntil[ AssociationQ @ result, 10 ];
        KeyDropFrom[ Wolfram`Chatbook`ACP`Git`Private`$gitCurrentRequests, "acp-git-test-key" ];
        pid = Quiet @ ToExpression @ StringTrim @ result[ "Output" ];
        {
            Lookup[ result, { "Cancelled", "ExitCode" } ],
            IntegerQ @ pid,
            ! $procfsQ || waitUntil[ ! processAliveQ @ pid, 5 ]
        }
    ],
    Missing[ "TestSkipped" ] | { { True, None }, True, True },
    SameTest -> MatchQ,
    TestID   -> "Run-Superseded@@Tests/ACPGit.wlt:1178,1-1196,2"
]

(* A command whose owner window is gone is killed *)
VerificationTest[
    ifShTests @ Module[ { nbo, result = None, pid },
        nbo = newWindow @ $gitScratch;
        acpGitRun[ { "-c", "echo $$; exec sleep 30" }, $gitScratch, (result = #) &, <| "Git" -> "/bin/sh", "Owner" -> nbo |> ];
        Pause[ 0.5 ];
        acpWindowDrop @ nbo;
        waitUntil[ AssociationQ @ result, 10 ];
        pid = Quiet @ ToExpression @ StringTrim @ result[ "Output" ];
        {
            Lookup[ result, { "Cancelled", "ExitCode" } ],
            IntegerQ @ pid,
            ! $procfsQ || waitUntil[ ! processAliveQ @ pid, 5 ]
        }
    ],
    Missing[ "TestSkipped" ] | { { True, None }, True, True },
    SameTest -> MatchQ,
    TestID   -> "Run-OwnerGone@@Tests/ACPGit.wlt:1199,1-1216,2"
]

(* Finished processes are released (each one would otherwise leak file descriptors) *)
VerificationTest[
    ifShTests @ If[ ! $procfsQ,
        True,
        Module[ { before },
            runSync[ { "-c", "true" }, $gitScratch, <| "Git" -> "/bin/sh" |> ];
            before = fileDescriptors[ ];
            Do[ runSync[ { "-c", "echo x; echo y >&2" }, $gitScratch, <| "Git" -> "/bin/sh" |> ], { 20 } ];
            fileDescriptors[ ] - before < 10
        ]
    ],
    Missing[ "TestSkipped" ] | True,
    SameTest -> MatchQ,
    TestID   -> "Run-NoDescriptorLeak@@Tests/ACPGit.wlt:1219,1-1232,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Git*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Repositories*)
VerificationTest[
    ifGitTests[
        $repoA = newRepository[ "repoA" ];
        writeText[ FileNameJoin @ { $repoA, "a.txt" }, "one\ntwo\nthree\n" ];
        writeText[ FileNameJoin @ { $repoA, "gone.txt" }, "bye\n" ];
        writeText[ FileNameJoin @ { $repoA, "old name.txt" }, "r1\nr2\nr3\nr4\n" ];
        writeBytes[ FileNameJoin @ { $repoA, "img.bin" }, ByteArray @ { 0, 1, 2, 3 } ];
        writeText[ FileNameJoin @ { $repoA, "sub", "b.txt" }, "b\n" ];
        writeText[ FileNameJoin @ { $repoA, "sub", "c.txt" }, "c\n" ];
        {
            gitSetup[ $repoA, "add", "." ],
            gitSetup[ $repoA, "commit", "-q", "-m", "initial" ],
            $cleanA = changesOf @ $repoA;
            KeyTake[ $cleanA, { "Status", "Error", "FileCount", "Files", "Branch", "Initial", "Root", "Prefix", "ObjectFormat", "Git", "GitVersion", "Token" } ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        0,
        0,
        <|
            "Status"       -> "Clean",
            "Error"        -> None,
            "FileCount"    -> 0,
            "Files"        -> { },
            "Branch"       -> "main",
            "Initial"      -> False,
            "Root"         -> _String,
            "Prefix"       -> "",
            "ObjectFormat" -> "sha1",
            "Git"          -> $gitExe,
            "GitVersion"   -> _String,
            "Token"        -> _String
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "Git-CleanRepository@@Tests/ACPGit.wlt:1241,1-1277,2"
]

VerificationTest[
    ifGitTests[
        writeText[ FileNameJoin @ { $repoA, "a.txt" }, "one\nTWO\nthree\nfour\n" ];
        DeleteFile @ FileNameJoin @ { $repoA, "gone.txt" };
        gitSetup[ $repoA, "mv", "old name.txt", "new name.txt" ];
        writeBytes[ FileNameJoin @ { $repoA, "img.bin" }, ByteArray @ { 0, 1, 2, 4 } ];
        writeText[ FileNameJoin @ { $repoA, "staged.txt" }, "s\n" ];
        gitSetup[ $repoA, "add", "staged.txt" ];
        writeText[ FileNameJoin @ { $repoA, "notes \:00fc.md" }, "x\ny" ];
        writeBytes[ FileNameJoin @ { $repoA, "data.bin" }, ByteArray @ { 1, 0, 2 } ];
        writeText[ FileNameJoin @ { $repoA, "sub", "b.txt" }, "b\nb2\n" ];
        $changesA = changesOf @ $repoA;
        {
            KeyTake[ $changesA, { "Status", "Error", "FileCount", "MoreFiles", "Added", "Deleted", "PatchComplete", "CountsComplete", "Mode" } ],
            Map[ Lookup[ #, { "Status", "Added", "Deleted", "Note" } ] &, filesByPath @ $changesA ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        <|
            "Status"         -> "Changes",
            "Error"          -> None,
            "FileCount"      -> 8,
            "MoreFiles"      -> 0,
            "Added"          -> 6, (* a.txt 2, staged.txt 1, notes 2, sub/b.txt 1 *)
            "Deleted"        -> 2, (* a.txt 1, gone.txt 1 *)
            "PatchComplete"  -> True,
            "CountsComplete" -> True,
            "Mode"           -> "Full"
        |>,
        KeyValuePattern @ {
            "a.txt"          -> { "Modified" , 2   , 1   , None      },
            "data.bin"       -> { "Untracked", None, None, "Binary"  },
            "gone.txt"       -> { "Deleted"  , 0   , 1   , None      },
            "img.bin"        -> { "Modified" , None, None, "Binary"  },
            "new name.txt"   -> { "Renamed"  , 0   , 0   , "Renamed" },
            "notes \:00fc.md"-> { "Untracked", 2   , 0   , None      },
            "staged.txt"     -> { "Added"    , 1   , 0   , None      },
            "sub/b.txt"      -> { "Modified" , 1   , 0   , None      }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Git-Changes@@Tests/ACPGit.wlt:1279,1-1321,2"
]

VerificationTest[
    ifGitTests @ With[ { files = filesByPath @ $changesA },
        {
            files[ "a.txt", "Patch" ],
            files[ "gone.txt", "Patch" ],
            files[ "new name.txt", "OrigPath" ],
            files[ "notes \:00fc.md", "Content" ],
            files[ "a.txt", "FullPath" ] === FileNameJoin @ { $changesA[ "Root" ], "a.txt" },
            FileExistsQ @ files[ "a.txt", "FullPath" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        "@@ -1,3 +1,4 @@\n one\n-two\n+TWO\n three\n+four",
        "@@ -1 +0,0 @@\n-bye",
        "old name.txt",
        "x\ny",
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Git-Changes-Patches@@Tests/ACPGit.wlt:1323,1-1344,2"
]

(* The project directory is a subdirectory: only its changes, with paths relative to it *)
VerificationTest[
    ifGitTests @ With[ { changes = changesOf @ FileNameJoin @ { $repoA, "sub" } },
        {
            KeyTake[ changes, { "Status", "FileCount", "Added", "Deleted", "Prefix" } ],
            Lookup[ changes[ "Files" ], { "Path", "RepoPath", "Status", "Patch" } ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        <| "Status" -> "Changes", "FileCount" -> 1, "Added" -> 1, "Deleted" -> 0, "Prefix" -> "sub/" |>,
        { { "b.txt", "sub/b.txt", "Modified", "@@ -1 +1,2 @@\n b\n+b2" } }
    },
    SameTest -> MatchQ,
    TestID   -> "Git-Subdirectory@@Tests/ACPGit.wlt:1347,1-1360,2"
]

(* No commits yet: the diff is against the empty tree *)
VerificationTest[
    ifGitTests @ Module[ { repo, changes },
        repo = newRepository[ "unborn" ];
        writeText[ FileNameJoin @ { repo, "a.txt" }, "1\n2\n" ];
        gitSetup[ repo, "add", "a.txt" ];
        writeText[ FileNameJoin @ { repo, "u.txt" }, "u\n" ];
        changes = changesOf @ repo;
        {
            KeyTake[ changes, { "Status", "Initial", "OID", "Branch", "FileCount", "Added", "Deleted" } ],
            Lookup[ changes[ "Files" ], { "Path", "Status", "Added", "Patch", "Content" } ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        <| "Status" -> "Changes", "Initial" -> True, "OID" -> None, "Branch" -> "main", "FileCount" -> 2, "Added" -> 3, "Deleted" -> 0 |>,
        { { "a.txt", "Added", 2, "@@ -0,0 +1,2 @@\n+1\n+2", None }, { "u.txt", "Untracked", 1, None, "u\n" } }
    },
    SameTest -> MatchQ,
    TestID   -> "Git-UnbornHead@@Tests/ACPGit.wlt:1363,1-1381,2"
]

VerificationTest[
    ifGitTests @ {
        KeyTake[ changesOf @ CreateDirectory @ FileNameJoin @ { $gitScratch, "not-a-repository" }, { "Status", "Error", "Files" } ],
        KeyTake[ changesOf @ FileNameJoin @ { $gitScratch, "missing" }, { "Status", "Error" } ],
        KeyTake[ changesOf @ FileNameJoin @ { $repoA, ".git" }, { "Status", "Error" } ]
    },
    Missing[ "TestSkipped" ] | {
        <| "Status" -> "NotRepository", "Error" -> None, "Files" -> { } |>,
        <| "Status" -> "NotRepository", "Error" -> None |>,
        <| "Status" -> "NotRepository", "Error" -> None |>
    },
    SameTest -> MatchQ,
    TestID   -> "Git-NotRepository@@Tests/ACPGit.wlt:1383,1-1396,2"
]

VerificationTest[
    ifGitTests @ Block[ { $acpGitEnabled = False },
        KeyTake[ changesOf @ $repoA, { "Status", "Error" } ]
    ],
    Missing[ "TestSkipped" ] | <| "Status" -> "Unavailable", "Error" -> KeyValuePattern[ "Code" -> "Disabled" ] |>,
    SameTest -> MatchQ,
    TestID   -> "Git-Disabled@@Tests/ACPGit.wlt:1398,1-1405,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Read-Only*)

(* A file whose modification time changed (same content) makes git refresh the index: git status and git diff write it
   when they can (git diff even with --no-optional-locks, only diff.autoRefreshIndex=false stops it). A modified file
   makes the checks run git diff (line counts, and the patch for full change sets). The checks must leave the index
   untouched. *)
VerificationTest[
    ifGitTests @ Module[ { repo, index, before, window, checked },
        repo  = newRepository[ "readonly" ];
        writeText[ FileNameJoin @ { repo, "f.txt" }, "f\n" ];
        writeText[ FileNameJoin @ { repo, "g.txt" }, "g\n" ];
        gitSetup[ repo, "add", "." ];
        gitSetup[ repo, "commit", "-q", "-m", "f" ];
        Pause[ 1.1 ];
        SetFileDate @ FileNameJoin @ { repo, "f.txt" };
        writeText[ FileNameJoin @ { repo, "g.txt" }, "g\nh\n" ];
        index  = FileNameJoin @ { repo, ".git", "index" };
        before = ReadByteArray @ index;
        $readOnlyRepository = repo;
        window = newWindow @ repo;
        acpGitCheck @ window;
        checked = waitUntil[ acpGitSummary[ window ][ "Status" ] === "Changes" && ! acpGitSummary[ window ][ "InFlight" ] ];
        {
            checked,
            acpGitSummary[ window ][ "Added" ],
            ReadByteArray @ index === before,
            Lookup[ changesOf @ repo, { "Status", "FileCount", "Added" } ],
            ReadByteArray @ index === before,
            FileExistsQ @ FileNameJoin @ { repo, ".git", "index.lock" }
        }
    ],
    Missing[ "TestSkipped" ] | { True, 1, True, { "Changes", 1, 1 }, True, False },
    SameTest -> MatchQ,
    TestID   -> "Git-ReadOnly-IndexUnchanged@@Tests/ACPGit.wlt:1415,1-1443,2"
]

(* The control: the same plain git diff does write the index (so the test above is meaningful) *)
VerificationTest[
    ifGitTests @ Module[ { index, before },
        index  = FileNameJoin @ { $readOnlyRepository, ".git", "index" };
        before = ReadByteArray @ index;
        RunProcess[ { $gitExe, "diff", "HEAD", "--numstat" }, ProcessDirectory -> $readOnlyRepository ];
        ReadByteArray @ index =!= before
    ],
    Missing[ "TestSkipped" ] | True,
    SameTest -> MatchQ,
    TestID   -> "Git-ReadOnly-Control@@Tests/ACPGit.wlt:1446,1-1456,2"
]

(* Filter drivers configured in the repository would run programs when git reads files of the working tree *)
VerificationTest[
    ifGitTests @ If[ ! TrueQ @ $shTestsQ,
        Missing[ "TestSkipped" ],
        Module[ { repo, marker, command, changes, ranBefore, ranControl },
            repo   = newRepository[ "filters" ];
            marker = FileNameJoin @ { $gitScratch, "filter-ran" };
            writeText[ FileNameJoin @ { repo, "a.txt" }, "a\n" ];
            writeText[ FileNameJoin @ { repo, ".gitattributes" }, "*.txt filter=probe\n" ];
            gitSetup[ repo, "add", "." ];
            gitSetup[ repo, "commit", "-q", "-m", "a" ];
            command = "sh -c 'echo ran >> \"" <> marker <> "\"; cat'";
            gitSetup[ repo, "config", "filter.probe.clean", command ];
            gitSetup[ repo, "config", "filter.probe.process", command ];
            gitSetup[ repo, "config", "filter.probe.required", "true" ];
            writeText[ FileNameJoin @ { repo, "a.txt" }, "a\nb\n" ];
            changes   = changesOf @ repo;
            ranBefore = FileExistsQ @ marker;
            (* git starts the process filter (which then fails its handshake: the marker is written anyway) *)
            RunProcess[ { $gitExe, "diff", "HEAD", "--numstat" }, ProcessDirectory -> repo ];
            ranControl = FileExistsQ @ marker;
            {
                KeyTake[ changes, { "Status", "Added", "Deleted" } ],
                Lookup[ changes[ "Files" ], "Path" ],
                ranBefore,
                ranControl
            }
        ]
    ],
    Missing[ "TestSkipped" ] | {
        <| "Status" -> "Changes", "Added" -> 1, "Deleted" -> 0 |>,
        { "a.txt" },
        False,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Git-FilterDriversNeutralized@@Tests/ACPGit.wlt:1459,1-1495,2"
]

(* A filter driver whose name contains "=" can't be turned off with -c (git splits at the first "="): the request fails
   instead of running it. A driver with an empty name is turned off like any other. *)
VerificationTest[
    ifGitTests @ If[ ! TrueQ @ $shTestsQ,
        Missing[ "TestSkipped" ],
        Module[ { marker, command, setUp, unsafe, empty },
            marker  = FileNameJoin @ { $gitScratch, "filter-ran-2" };
            command = "sh -c 'echo ran >> \"" <> marker <> "\"; cat'";
            setUp = Function[ { name, driver },
                With[ { repo = newRepository @ name },
                    writeText[ FileNameJoin @ { repo, "a.txt" }, "a\n" ];
                    gitSetup[ repo, "add", "." ];
                    gitSetup[ repo, "commit", "-q", "-m", "a" ];
                    writeText[ FileNameJoin @ { repo, ".gitattributes" }, "*.txt filter=" <> driver <> "\n" ];
                    (* the configuration file is written directly: git config can't set a driver with an empty name *)
                    writeText[
                        FileNameJoin @ { repo, ".git", "config" },
                        ReadString @ FileNameJoin @ { repo, ".git", "config" } <>
                            "[filter \"" <> driver <> "\"]\n\tclean = \"" <> StringReplace[ command, { "\\" -> "\\\\", "\"" -> "\\\"" } ] <> "\"\n\trequired = true\n"
                    ];
                    writeText[ FileNameJoin @ { repo, "a.txt" }, "a\nb\n" ];
                    repo
                ]
            ];
            unsafe = changesOf @ setUp[ "filter-equals", "x=y" ];
            empty  = changesOf @ setUp[ "filter-empty", "" ];
            {
                Lookup[ unsafe, { "Status", "FileCount" } ],
                KeyTake[ unsafe[ "Error" ], { "Code", "Detail" } ],
                Lookup[ empty, { "Status", "Added" } ],
                FileExistsQ @ marker,
                (* the control: plain git runs the driver with the empty name *)
                RunProcess[ { $gitExe, "diff", "HEAD", "--numstat" }, ProcessDirectory -> FileNameJoin @ { $gitScratch, "filter-empty" } ];
                FileExistsQ @ marker
            }
        ]
    ],
    Missing[ "TestSkipped" ] | {
        { "Error", 0 },
        <| "Code" -> "UnsafeConfig", "Detail" -> "filter.x=y" |>,
        { "Changes", 2 }, (* a.txt and .gitattributes *)
        False,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Git-FilterDriversUnsafeNames@@Tests/ACPGit.wlt:1499,1-1543,2"
]

(* With a git older than 2.45 (no --no-lazy-fetch), a partial clone would fetch missing objects, running the upload-pack
   of the repository's config: transports are off (protocol.allow=never) *)
VerificationTest[
    ifGitTests @ If[ ! TrueQ @ $shTestsQ,
        Missing[ "TestSkipped" ],
        Module[ { source, bare, work, marker, old, current, ran, control },
            source = newRepository[ "promisor-source" ];
            writeText[ FileNameJoin @ { source, "a.txt" }, "one\ntwo\n" ];
            gitSetup[ source, "add", "." ];
            gitSetup[ source, "commit", "-q", "-m", "a" ];
            bare = FileNameJoin @ { $gitScratch, "promisor.git" };
            gitSetup[ $gitScratch, "clone", "-q", "--bare", source, bare ];
            gitSetup[ bare, "config", "uploadpack.allowFilter", "true" ];
            work = FileNameJoin @ { $gitScratch, "promisor-work" };
            gitSetup[ $gitScratch, "clone", "-q", "--no-checkout", "--filter=blob:none", "file://" <> bare, work ];
            gitSetup[ work, "read-tree", "HEAD" ];
            writeText[ FileNameJoin @ { work, "a.txt" }, "one\nTWO\n" ];
            marker = FileNameJoin @ { $gitScratch, "upload-pack-ran" };
            gitSetup[ work, "config", "remote.origin.uploadpack", "sh -c 'echo ran >> \"" <> marker <> "\"; exit 1'" ];
            (* as an old git: no --no-lazy-fetch *)
            old = Block[ { Wolfram`Chatbook`ACP`Git`Private`$gitVersions = <| $gitExe -> { 2, 43, 0 } |> }, changesOf @ work ];
            current = changesOf @ work;
            ran     = FileExistsQ @ marker;
            (* the control: a plain git command fetches the missing object with the configured upload-pack *)
            RunProcess[ { $gitExe, "cat-file", "-p", "HEAD:a.txt" }, ProcessDirectory -> work ];
            control = FileExistsQ @ marker;
            {
                Lookup[ old, { "Status", "FileCount", "CountsComplete" } ],
                Lookup[ current, { "Status", "FileCount" } ],
                ran,
                control
            }
        ]
    ],
    Missing[ "TestSkipped" ] | { { "Changes", 1, False }, { "Changes", 1 }, False, True },
    SameTest -> MatchQ,
    TestID   -> "Git-PartialCloneNoFetch@@Tests/ACPGit.wlt:1547,1-1582,2"
]

(* Untracked symbolic links are listed as links (one added line, like git), never read through *)
VerificationTest[
    ifGitTests @ If[ ! TrueQ @ $shTestsQ,
        Missing[ "TestSkipped" ],
        Module[ { repo, outside, changes, files },
            repo    = newRepository[ "links" ];
            outside = CreateDirectory @ FileNameJoin @ { $gitScratch, "links-outside" };
            writeText[ FileNameJoin @ { outside, "secret.txt" }, "s1\ns2\ns3\n" ];
            writeText[ FileNameJoin @ { repo, "a.txt" }, "a\n" ];
            gitSetup[ repo, "add", "." ];
            gitSetup[ repo, "commit", "-q", "-m", "a" ];
            RunProcess[ { "ln", "-s", FileNameJoin @ { outside, "secret.txt" }, "link.txt" }, ProcessDirectory -> repo ];
            RunProcess[ { "ln", "-s", outside, "linkdir" }, ProcessDirectory -> repo ];
            RunProcess[ { "ln", "-s", "nowhere", "broken" }, ProcessDirectory -> repo ];
            changes = changesOf @ repo;
            files   = filesByPath @ changes;
            {
                Lookup[ changes, { "Status", "FileCount", "Added" } ],
                Lookup[ #, { "Status", "Added", "Note", "Content" } ] & /@ files,
                files[ "link.txt", "LinkTarget" ] === AbsoluteFileName @ FileNameJoin @ { outside, "secret.txt" },
                files[ "linkdir", "LinkTarget" ] === AbsoluteFileName @ outside,
                files[ "broken", "LinkTarget" ],
                FreeQ[ changes, "s1" ]
            }
        ]
    ],
    Missing[ "TestSkipped" ] | {
        { "Changes", 3, 3 },
        <|
            "broken"   -> { "Untracked", 1, "SymbolicLink", None },
            "link.txt" -> { "Untracked", 1, "SymbolicLink", None },
            "linkdir"  -> { "Untracked", 1, "SymbolicLink", None }
        |>,
        True,
        True,
        None,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Git-UntrackedLinks@@Tests/ACPGit.wlt:1585,1-1624,2"
]

(* Statuses relative to HEAD with the real git: added then deleted (not listed), renamed then deleted (the original is
   deleted), removed from the index (deleted and untracked); renames that status and diff see differently *)
VerificationTest[
    ifGitTests @ Module[ { repo, changes, files },
        repo = newRepository[ "index-then-worktree" ];
        writeText[ FileNameJoin @ { repo, "a.txt" }, "a1\na2\n" ];
        writeText[ FileNameJoin @ { repo, "keep.txt" }, "k1\nk2\n" ];
        writeText[ FileNameJoin @ { repo, "c.txt" }, "c1\nc2\nc3\nc4\n" ];
        writeText[ FileNameJoin @ { repo, "e.txt" }, "e1\ne2\ne3\n" ];
        gitSetup[ repo, "add", "." ];
        gitSetup[ repo, "commit", "-q", "-m", "a" ];
        (* AD *)
        writeText[ FileNameJoin @ { repo, "n.txt" }, "n\n" ];
        gitSetup[ repo, "add", "n.txt" ];
        DeleteFile @ FileNameJoin @ { repo, "n.txt" };
        (* RD *)
        gitSetup[ repo, "mv", "a.txt", "b.txt" ];
        DeleteFile @ FileNameJoin @ { repo, "b.txt" };
        (* D. and ?? *)
        gitSetup[ repo, "rm", "-q", "--cached", "keep.txt" ];
        (* a rename in the index, rewritten in the working tree: the diff sees a deleted and an added file *)
        gitSetup[ repo, "mv", "c.txt", "d.txt" ];
        writeText[ FileNameJoin @ { repo, "d.txt" }, "x1\nx2\nx3\nx4\nx5\n" ];
        (* a copy in the index, the original deleted in the working tree: the diff sees a rename *)
        CopyFile[ FileNameJoin @ { repo, "e.txt" }, FileNameJoin @ { repo, "f.txt" } ];
        gitSetup[ repo, "add", "f.txt" ];
        DeleteFile @ FileNameJoin @ { repo, "e.txt" };
        changes = changesOf @ repo;
        files   = Lookup[ changes[ "Files" ], { "Path", "Status", "OrigPath", "Added", "Deleted", "Note" } ];
        {
            Lookup[ changes, { "FileCount", "Added", "Deleted" } ],
            files,
            Lookup[ SelectFirst[ changes[ "Files" ], #[ "Status" ] === "Untracked" & ], { "Patch", "Content" } ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        { 5, 7, 8 },
        {
            { "a.txt"   , "Deleted"  , None   , 0, 2, None      },
            { "d.txt"   , "Renamed"  , "c.txt", 5, 4, None      },
            { "f.txt"   , "Renamed"  , "e.txt", 0, 0, "Renamed" },
            { "keep.txt", "Deleted"  , None   , 0, 2, None      },
            { "keep.txt", "Untracked", None   , 2, 0, None      }
        },
        { None, "k1\nk2\n" }
    },
    SameTest -> MatchQ,
    TestID   -> "Git-IndexAndWorkingTree@@Tests/ACPGit.wlt:1628,1-1674,2"
]

(* The private-use characters of the front end's linear syntax in file names and contents are neutralized when git's
   output and untracked files are decoded, so they can never become boxes in the review window *)
VerificationTest[
    ifGitTests @ Module[ { chars, payload, repo, changes },
        chars   = Characters @ FromCharacterCode @ Range[ 63424, 63437 ];
        payload = FromCharacterCode @ { 63425, 63433, 63432 } <> "StyleBox[\"X\", FontSize -> 1]" <> FromCharacterCode[ 63424 ];
        repo    = newRepository[ "linear-syntax" ];
        writeText[ FileNameJoin @ { repo, "a.txt" }, "a\n" ];
        gitSetup[ repo, "add", "." ];
        gitSetup[ repo, "commit", "-q", "-m", "a" ];
        writeText[ FileNameJoin @ { repo, "a.txt" }, "a\n" <> payload <> "\n" ];
        writeText[ FileNameJoin @ { repo, "n" <> payload <> ".txt" }, payload <> "\n" ];
        changes = changesOf @ repo;
        {
            Lookup[ changes, { "Status", "FileCount", "Added" } ],
            Cases[ changes, s_String /; AnyTrue[ chars, StringContainsQ[ s, # ] & ], Infinity ],
            Count[ changes, s_String /; StringContainsQ[ s, "\:fffd" ], Infinity ] > 0,
            (* the file with the changed name can't be read *)
            Lookup[ changes[ "Files" ], { "Status", "Note" } ]
        }
    ],
    Missing[ "TestSkipped" ] | { { "Changes", 2, 1 }, { }, True, { { "Modified", None }, { "Untracked", "Unreadable" } } },
    SameTest -> MatchQ,
    TestID   -> "Git-LinearSyntaxNeutralized@@Tests/ACPGit.wlt:1678,1-1700,2"
]

(* A project folder that is a symbolic link into a repository's subfolder (git works in the physical folder) *)
VerificationTest[
    ifGitTests @ If[ ! TrueQ @ $shTestsQ,
        Missing[ "TestSkipped" ],
        Module[ { repo, link, changes },
            repo = newRepository[ "linked" ];
            writeText[ FileNameJoin @ { repo, "sub", "a.txt" }, "a\n" ];
            gitSetup[ repo, "add", "." ];
            gitSetup[ repo, "commit", "-q", "-m", "a" ];
            writeText[ FileNameJoin @ { repo, "sub", "a.txt" }, "a\nb\n" ];
            link = FileNameJoin @ { $gitScratch, "linked-project" };
            RunProcess[ { "ln", "-s", FileNameJoin @ { repo, "sub" }, link } ];
            changes = changesOf @ link;
            {
                acpGitWorkTreeRoot @ link === AbsoluteFileName @ repo,
                Lookup[ changes, { "Status", "FileCount", "Added", "Prefix" } ],
                Lookup[ changes[ "Files" ], "Path" ]
            }
        ]
    ],
    Missing[ "TestSkipped" ] | { True, { "Changes", 1, 1, "sub/" }, { "a.txt" } },
    SameTest -> MatchQ,
    TestID   -> "Git-LinkedProjectFolder@@Tests/ACPGit.wlt:1703,1-1725,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Windows*)
VerificationTest[
    ifGitTests @ Module[ { window, token },
        window = newWindow @ $repoA;
        $repoAWindow = window;
        token = acpGitCheck @ window;
        {
            StringQ @ token,
            KeyTake[ acpGitSummary @ window, { "Directory", "Status", "InFlight", "Token" } ],
            waitUntil[ ! acpGitSummary[ window ][ "InFlight" ] ],
            KeyTake[ acpGitSummary @ window, { "Directory", "Status", "FileCount", "Added", "Deleted", "Branch", "Error", "InFlight", "Stale", "Paused" } ],
            NumberQ @ acpGitSummary[ window ][ "Duration" ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        True,
        <| "Directory" -> $repoA, "Status" -> "Checking", "InFlight" -> True, "Token" -> _String |>,
        True,
        <|
            "Directory" -> $repoA,
            "Status"    -> "Changes",
            "FileCount" -> 8,
            "Added"     -> 6,
            "Deleted"   -> 2,
            "Branch"    -> "main",
            "Error"     -> None,
            "InFlight"  -> False,
            "Stale"     -> False,
            "Paused"    -> False
        |>,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Window-Check@@Tests/ACPGit.wlt:1730,1-1763,2"
]

(* Stale: housekeeping checks again; the new counts arrive *)
VerificationTest[
    ifGitTests @ Module[ { window = $repoAWindow, checked },
        checked = acpGitSummary[ window ][ "CheckedAt" ];
        writeText[ FileNameJoin @ { $repoA, "more.txt" }, "m\n" ];
        acpGitMarkStale @ window;
        {
            acpGitSummary[ window ][ "Stale" ],
            waitUntil[ acpGitSummary[ window ][ "CheckedAt" ] =!= checked && ! acpGitSummary[ window ][ "InFlight" ] ],
            KeyTake[ acpGitSummary @ window, { "Status", "FileCount", "Added", "Stale" } ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, True, <| "Status" -> "Changes", "FileCount" -> 9, "Added" -> 7, "Stale" -> False |> },
    SameTest -> MatchQ,
    TestID   -> "Window-StaleCheck@@Tests/ACPGit.wlt:1766,1-1780,2"
]

(* A full request for a window updates its summary; a second one supersedes the first *)
VerificationTest[
    ifGitTests @ Module[ { window = $repoAWindow, first = None, second = None, t1, t2 },
        t1 = acpGitChanges[ window, (first = #) & ];
        t2 = acpGitChanges[ window, (second = #) & ];
        {
            waitUntil[ AssociationQ @ first && AssociationQ @ second && ! acpGitSummary[ window ][ "InFlight" ] ],
            { first[ "Token" ] === t1, second[ "Token" ] === t2, t1 =!= t2 },
            (* the first request stopped before it started git *)
            Lookup[ first, { "Status", "Error" } ],
            acpGitSummary[ window ][ "Token" ] === t2,
            Lookup[ second, { "Status", "FileCount", "Mode" } ],
            AllTrue[ Select[ second[ "Files" ], MemberQ[ { "Modified", "Deleted" }, #[ "Status" ] ] && #[ "Note" ] === None & ], StringQ @ #[ "Patch" ] & ],
            (* finished requests are no longer current *)
            KeyExistsQ[ Wolfram`Chatbook`ACP`Git`Private`$gitCurrentRequests, Key @ { "Full", window } ]
        }
    ],
    Missing[ "TestSkipped" ] | {
        True,
        { True, True, True },
        { "Error", KeyValuePattern[ "Code" -> "Superseded" ] },
        True,
        { "Changes", 9, "Full" },
        True,
        False
    },
    SameTest -> MatchQ,
    TestID   -> "Window-FullRequest@@Tests/ACPGit.wlt:1783,1-1810,2"
]

(* Summary checks and full change sets read the same untracked files, so the toolbar and the review window show the
   same counts *)
VerificationTest[
    ifGitTests @ Block[ { Wolfram`Chatbook`ACP`Git`Private`$gitUntrackedBudget = 10 },
        Module[ { repo, window, summary, full },
            repo = newRepository[ "budget" ];
            writeText[ FileNameJoin @ { repo, "a.txt" }, "a\n" ];
            gitSetup[ repo, "add", "." ];
            gitSetup[ repo, "commit", "-q", "-m", "a" ];
            writeText[ FileNameJoin @ { repo, "u1.txt" }, "1\n2\n3\n" ];
            writeText[ FileNameJoin @ { repo, "u2.txt" }, "4\n5\n6\n" ];
            window = newWindow @ repo;
            acpGitCheck @ window;
            waitUntil[ acpGitSummary[ window ][ "Status" ] === "Changes" && ! acpGitSummary[ window ][ "InFlight" ] ];
            summary = acpGitSummary[ window ][ "Added" ];
            full    = changesOf @ window;
            { summary, full[ "Added" ], acpGitSummary[ window ][ "Added" ], Lookup[ full[ "Files" ], "Note" ] }
        ]
    ],
    Missing[ "TestSkipped" ] | { 3, 3, 3, { None, "NotRead" } },
    SameTest -> MatchQ,
    TestID   -> "Window-SameCountsBothModes@@Tests/ACPGit.wlt:1814,1-1834,2"
]

(* A new project directory: the summary follows it (results for the old one are dropped) *)
VerificationTest[
    ifGitTests @ Module[ { window = $repoAWindow, clean },
        clean = newRepository[ "clean" ];
        acpWindowUpdate[ window, <| #, "ProjectDirectory" -> clean |> & ];
        acpGitMarkStale @ window; (* starts the pump; housekeeping notices the new directory *)
        {
            waitUntil[ acpGitSummary[ window ][ "Directory" ] === clean && acpGitSummary[ window ][ "Status" ] === "Clean" ],
            KeyTake[ acpGitSummary @ window, { "Directory", "Status", "FileCount", "Added", "Deleted" } ]
        }
    ],
    Missing[ "TestSkipped" ] | { True, KeyValuePattern @ { "Status" -> "Clean", "FileCount" -> 0, "Added" -> 0, "Deleted" -> 0 } },
    SameTest -> MatchQ,
    TestID   -> "Window-DirectoryChange@@Tests/ACPGit.wlt:1837,1-1850,2"
]

VerificationTest[
    Module[ { window, result = None, token },
        window = newWindow @ None;
        token  = acpGitChanges[ window, (result = #) & ];
        {
            StringQ @ token,
            waitUntil[ AssociationQ @ result, 10 ],
            KeyTake[ result, { "Token", "Status", "Directory", "Files", "Error" } ],
            acpGitSummary[ window ][ "Status" ],
            acpGitCheck @ window
        }
    ],
    { True, True, <| "Token" -> _String, "Status" -> "NoDirectory", "Directory" -> None, "Files" -> { }, "Error" -> None |>, "Unknown", None },
    SameTest -> MatchQ,
    TestID   -> "Window-NoDirectory@@Tests/ACPGit.wlt:1852,1-1867,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    Scan[ acpWindowDrop, $gitWindows ];
    {
        waitUntil[ Wolfram`Chatbook`ACP`Git`Private`$gitRuns === <| |>, 30 ],
        Select[ Tasks[ ], StringContainsQ[ ToString[ #[ "EvaluationExpression" ], InputForm ], "gitPoll" ] & ]
    },
    { True, { } },
    SameTest -> MatchQ,
    TestID   -> "ACPGit-NoLeftoverRuns@@Tests/ACPGit.wlt:1872,1-1881,2"
]

(* Isolated code swallows messages and failures into the debug log; nothing unexpected may have been logged *)
VerificationTest[
    Select[
        Internal`BagPart[ $acpDebugLog, All ],
        #[ "Time" ] >= $acpLogStart && MemberQ[ { "Message", "Uncaught", "GitCheckLost" }, #[ "Where" ] ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPGit-DebugLog@@Tests/ACPGit.wlt:1884,1-1892,2"
]

VerificationTest[
    Quiet @ DeleteDirectory[ $gitScratch, DeleteContents -> True ];
    SetEnvironment @ Normal @ Replace[ $savedGitEnvironment, Except[ _String ] -> None, { 1 } ];
    {
        DirectoryQ @ $gitScratch,
        AssociationMap[ Environment, Keys @ $savedGitEnvironment ] === $savedGitEnvironment
    },
    { False, True },
    SameTest -> MatchQ,
    TestID   -> "ACPGit-Cleanup@@Tests/ACPGit.wlt:1894,1-1904,2"
]

(* :!CodeAnalysis::EndBlock:: *)
