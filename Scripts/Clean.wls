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

   Note: wolframscript itself consumes -h/--help, so they never reach the
   script; --usage (or -?) is the equivalent here.
*)

BeginPackage[ "Wolfram`ChatbookScripts`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Arguments*)
$args = Select[ Flatten @ { $ScriptCommandLine }, StringQ ];

flagQ[ names___String ] := AnyTrue[ { names }, MemberQ[ $args, # ] & ];

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
           "      --usage             Show this message (wolframscript takes -h/--help)."
    ];
    Exit[ 0 ]
];


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paclet Directory*)
$scriptFile = If[ StringQ @ $InputFileName && $InputFileName =!= "", $InputFileName, "" ];

If[ $scriptFile === "",
    Print[ "Cannot locate this script: $InputFileName is unset." ];
    Exit[ 1 ]
];

$pacletDir = DirectoryName[ ExpandFileName @ $scriptFile, 2 ];

(* Guard the recursive deletes below against ever running outside the paclet. *)
If[ ! DirectoryQ @ $pacletDir || ! FileExistsQ @ FileNameJoin @ { $pacletDir, "PacletInfo.wl" },
    Print[ "Refusing to clean: no PacletInfo.wl found in ", $pacletDir ];
    Exit[ 1 ]
];

relative[ path_String ] := StringDelete[ path, StartOfString ~~ $pacletDir ];

$exitCode = 0;

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
            { }
        ]
    ];

If[ $restore,
    If[ ! gitOK @ runGit @ { "rev-parse", "--is-inside-work-tree" }
        ,
        (* Artifacts are still worth removing outside a work tree. *)
        Print[ "Not a git work tree; skipping front-end restore." ]
        ,
        With[ { modified = modifiedFrontEndFiles[ ] },
            Which[
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
                        $exitCode = 1
                    ]
            ]
        ]
    ]
];


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Artifact Groups*)

(* Each group is { label, paths }; the paths are collected once and reused for
   both the report and the deletion, so the two can never disagree. *)
$groups = {
    (* Every *Bit subdirectory, so a stale MX from another word length also goes. *)
    { "Compiled MX file",
      FileNames[ "Chatbook.mx", FileNameJoin @ { $pacletDir, "Source", "Chatbook" }, 2 ] },

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
    Exit[ 0 ]
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
    Exit[ $exitCode ]
];

If[ $failures =!= { },
    Print[ "Failed to remove ", Length @ $failures, " item(s):" ];
    Scan[ Print[ "    ", relative @ # ] &, $failures ];
    $exitCode = 1
    ,
    Print[ "Removed ", Length @ $targets, " item(s)." ]
];

EndPackage[ ];

(* Fully qualified: EndPackage has already popped the context. *)
Exit[ Wolfram`ChatbookScripts`$exitCode ]
