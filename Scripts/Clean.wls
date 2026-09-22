#!/usr/bin/env wolframscript


(* Restores the front-end files that the build rewrites in place, then removes
   the paclet's build artifacts.

   Unlike its sibling scripts, this one deliberately does NOT load Common.wl:
   that file may install PacletCICD over the network, calls PacletDirectoryLoad,
   and asserts that Wolfram`Chatbook` resolves inside this repository. Cleaning
   has to keep working when exactly those things are broken.

   Usage:
       wolframscript -f Scripts/Clean.wls [options]

   Options:
       -n, --dry-run           List what would be done without changing anything.
           --no-restore        Skip the git restore of front-end files.
           --snippets          Also remove Assets/Snippets/Streamable.
           --vector-databases  Also remove generated vector database assets.
           --all               Enable every optional group above.
           --usage             Show this message.

   Exit codes:
       0  Everything requested succeeded, or there was nothing to do.
       1  A restore or a delete was attempted and failed.
       2  The invocation was rejected; nothing was touched.

   Note: wolframscript itself consumes -h/--help, so they never reach the
   script; --usage (or -?) is the equivalent here.
*)

BeginPackage[ "Wolfram`ChatbookScripts`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Exit*)

(* 0 = succeeded or nothing to do; 1 = an operation failed; 2 = invocation rejected. *)
$exitCode = 0;

(* Monotone, so no later branch can downgrade a recorded failure. *)
raiseExitCode[ code_Integer ] := $exitCode = Max[ $exitCode, code ];

(* The script's only Exit. *)
finish[ ] := Exit[ $exitCode ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Arguments*)
$args = Select[ Flatten @ { $ScriptCommandLine }, StringQ ];

flagQ[ names___String ] := AnyTrue[ { names }, MemberQ[ $args, # ] & ];

(* Reject unknown options before any destructive work. The script name at
   position 1 is not an option and is ignored. *)
$knownOptions = {
    "-n", "--dry-run",
    "--no-restore",
    "--snippets",
    "--vector-databases",
    "--all",
    "--usage",
    "-?"
};

$unknownOptions = Select[ Rest @ $args, ! MemberQ[ $knownOptions, # ] & ];

If[ $unknownOptions =!= { },
    Print[ "Unknown option(s): " <> StringRiffle[ $unknownOptions, ", " ] ];
    Print[ "Run with --usage for the list of valid options." ];
    raiseExitCode[ 2 ];
    finish[ ]
];

$dryRun = flagQ[ "-n", "--dry-run" ];
$restore        = ! flagQ[ "--no-restore" ];
$allOptional    = flagQ[ "--all" ];
$cleanSnippets  = $allOptional || flagQ[ "--snippets" ];
$cleanVectorDBs = $allOptional || flagQ[ "--vector-databases" ];

If[ flagQ[ "--usage", "-?" ],
    Print[ "Usage: wolframscript -f Scripts/Clean.wls [options]\n\n" <>
           "  -n, --dry-run           List what would be done without changing anything.\n" <>
           "      --no-restore        Skip the git restore of front-end files.\n" <>
           "      --snippets          Also remove Assets/Snippets/Streamable.\n" <>
           "      --vector-databases  Also remove generated vector database assets.\n" <>
           "      --all               Enable every optional group above.\n" <>
           "      --usage             Show this message (wolframscript takes -h/--help).\n\n" <>
           "Exit codes:\n" <>
           "  0  Succeeded, or there was nothing to do.\n" <>
           "  1  A restore or a delete failed.\n" <>
           "  2  The invocation was rejected; nothing was touched."
    ];
    finish[ ]
];


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paclet Directory*)
$scriptFile = If[ StringQ @ $InputFileName && $InputFileName =!= "", $InputFileName, "" ];

If[ $scriptFile === "",
    Print[ "Cannot locate this script: $InputFileName is unset." ];
    raiseExitCode[ 2 ];
    finish[ ]
];

$pacletDir = DirectoryName[ ExpandFileName @ $scriptFile, 2 ];

$expectedPacletName = "Wolfram/Chatbook";

(* A relocated or copied script could still find a PacletInfo.wl in an unrelated
   directory. Verify the directory actually contains this paclet by checking its
   declared name and a repository-specific landmark file. *)
pacletDirLooksValid[ pacDir_String ] := Module[ { pacletInfoPath, pacletInfoText },
    pacletInfoPath = FileNameJoin @ { pacDir, "PacletInfo.wl" };
    And[
        FileExistsQ @ pacletInfoPath,
        FileExistsQ @ FileNameJoin @ { pacDir, "Source", "Chatbook", "Chatbook.wl" },
        StringQ @ (pacletInfoText = Quiet @ Import[ pacletInfoPath, "Text" ]),
        StringContainsQ[
            pacletInfoText,
            RegularExpression[ "\"Name\"\\s*->\\s*\"" <> $expectedPacletName <> "\"" ]
        ]
    ]
];

(* Guard the recursive deletes below against ever running outside the paclet. *)
If[ ! DirectoryQ @ $pacletDir || ! pacletDirLooksValid @ $pacletDir,
    Print[ "Refusing to clean: ", $pacletDir, " does not look like the ", $expectedPacletName, " paclet." ];
    raiseExitCode[ 2 ];
    finish[ ]
];

relative[ path_String ] := StringDelete[ path, StartOfString ~~ $pacletDir ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Restore Front-End Files*)

(* The build reformats these in place; restore them from the index. *)
$frontEndFiles = {
    "DarkModeSupport/StyleSheets/Chatbook.nb",
    "DarkModeSupport/StyleSheets/Wolfram/WorkspaceChat.nb",
    "FrontEnd/Assets/Extensions/CoreExtensions.nb",
    "FrontEnd/StyleSheets/Chatbook.nb",
    "FrontEnd/StyleSheets/Wolfram/WorkspaceChat.nb"
};

runGit[ args_List ] :=
    With[ { res = Quiet @ RunProcess[ Prepend[ args, "git" ], ProcessDirectory -> $pacletDir ] },
        If[ AssociationQ @ res, res, $Failed ]
    ];

gitOK[ res_ ] := AssociationQ @ res && res[ "ExitCode" ] === 0;

(* Only act on files git reports as modified, so the output names what changed.
   `git restore` reads from the index, so compare against the index too. *)
modifiedFrontEndFiles[ ] :=
    With[ { res = runGit @ Join[ { "diff", "--name-only", "--" }, $frontEndFiles ] },
        If[ gitOK @ res,
            Select[ StringTrim /@ StringSplit[ res[ "StandardOutput" ], "\n" ], # =!= "" & ],
            Print[ "git diff failed; cannot determine modified front-end files." ];
            raiseExitCode[ 1 ];
            $Failed
        ]
    ];

(* Returns True inside a work tree, False outside one, and $Failed if the
   check itself could not be performed. Distinguishes "git is unavailable /
   RunProcess failed" from "this directory is not a git work tree". *)
workTreeCheck[ ] :=
    With[ { res = runGit @ { "rev-parse", "--is-inside-work-tree" } },
        Which[
            ! gitOK @ res,
                Print[ "git rev-parse failed; cannot determine whether this is a git work tree." ];
                raiseExitCode[ 1 ];
                $Failed,

            StringTrim @ res[ "StandardOutput" ] === "true",
                True,

            StringTrim @ res[ "StandardOutput" ] === "false",
                Print[ "Not a git work tree; front-end restore skipped." ];
                raiseExitCode[ 1 ];
                False,

            True,
                Print[ "Unexpected output from git rev-parse: ", res[ "StandardOutput" ] ];
                raiseExitCode[ 1 ];
                $Failed
        ]
    ];

If[ $restore,
    With[ { inside = workTreeCheck[ ] },
        If[ inside === True,
            With[ { modified = modifiedFrontEndFiles[ ] },
                Which[
                    modified === $Failed,
                        Null,

                    modified === { },
                        Print[ "No modified front-end files to restore." ],

                    $dryRun,
                        Print[ "Would restore ", Length @ modified, " modified front-end file(s):" ];
                        Scan[ Print[ "    ", # ] &, modified ],

                    True,
                        Print[ "Restoring ", Length @ modified, " modified front-end file(s):" ];
                        Scan[ Print[ "    ", # ] &, modified ];
                        If[ ! gitOK @ runGit @ Join[ { "restore", "--" }, modified ],
                            Print[ "    git restore failed." ];
                            raiseExitCode[ 1 ]
                        ]
                ]
            ]
            ,
            (* Not a work tree or the check failed; the failure has already
               been reported and the exit code raised. Artifacts are still
               worth cleaning, so execution continues. *)
            Null
        ]
    ]
];


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Artifact Groups*)

(* Each group is { label, paths }; the paths are collected once and reused for
   both the report and the deletion, so the two can never disagree. *)
$groups = {
    (* Only direct children of a *Bit subdirectory are Chatbook MX artifacts. *)
    { "Compiled MX file",
      FileNames[ FileNameJoin @ { $pacletDir, "Source", "Chatbook", "*Bit", "Chatbook.mx" } ] },

    { "Build directory",
      Select[ { FileNameJoin @ { $pacletDir, "build" } }, DirectoryQ ] },

    { "Test stack history",
      FileNames[ "*StackHistory.wxf", $pacletDir, 1 ] }
};

If[ $cleanSnippets,
    AppendTo[ $groups,
        { "Documentation snippets",
          Select[ { FileNameJoin @ { $pacletDir, "Assets", "Snippets", "Streamable" } }, DirectoryQ ] }
    ]
];

If[ $cleanVectorDBs,
    AppendTo[ $groups,
        { "Vector databases",
          Join[
              FileNames[ { "*.usearch", "*.wl", "*.wxf" },
                         FileNameJoin @ { $pacletDir, "Assets", "VectorDatabases" },
                         Infinity
              ],
              FileNames[ "*.jsonl",
                         FileNameJoin @ { $pacletDir, "Developer", "VectorDatabases", "SourceData" },
                         1
              ]
          ] }
    ]
];


$targets = DeleteDuplicates @ Flatten[ Last /@ $groups ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Report*)
If[ $targets === { },
    Print[ "Nothing to clean in ", $pacletDir ];
    finish[ ]
];

Print[ If[ $dryRun, "Would remove:", "Removing:" ] ];

Scan[
    Function[ group,
        If[ Last @ group =!= { },
            Print[ "  ", First @ group, ":" ];
            Scan[ Print[ "    ", relative @ # ] &, Last @ group ]
        ]
    ],
    $groups
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Delete*)
$failures = { };

removePath[ path_String ] := (
    Quiet @ If[ DirectoryQ @ path,
                DeleteDirectory[ path, DeleteContents -> True ],
                DeleteFile @ path
            ];
    (* Trust the filesystem rather than the return value. *)
    If[ FileExistsQ @ path || DirectoryQ @ path, AppendTo[ $failures, path ] ]
);

If[ ! $dryRun, Scan[ removePath, $targets ] ];

If[ $dryRun,
    Print[ "Dry run: ", Length @ $targets, " item(s) left untouched." ];
    finish[ ]
];

If[ $failures =!= { },
    Print[ "Failed to remove ", Length @ $failures, " item(s):" ];
    Scan[ Print[ "    ", relative @ # ] &, $failures ];
    raiseExitCode[ 1 ]
    ,
    Print[ "Removed ", Length @ $targets, " item(s)." ]
];

EndPackage[ ];

(* Fully qualified: EndPackage has already popped the context. *)
Wolfram`ChatbookScripts`finish[ ]
