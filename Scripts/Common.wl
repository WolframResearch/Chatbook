(* cSpell: ignore samevers *)

BeginPackage[ "Wolfram`ChatbookScripts`" ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
Wolfram`PacletCICD`$Debug = True;

Off[ General::shdw           ];
Off[ PacletInstall::samevers ];

If[ ! PacletObjectQ @ PacletObject[ "Wolfram/PacletCICD" ],
    PacletInstall[ "https://github.com/WolframResearch/PacletCICD/releases/download/v0.35.0/Wolfram__PacletCICD-0.35.0.paclet" ]
];

Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

cFile = cicd`ScriptConfirmBy[ #, FileExistsQ ] &;
cDir  = cicd`ScriptConfirmBy[ #, DirectoryQ  ] &;
cStr  = cicd`ScriptConfirmBy[ #, StringQ     ] &;

Needs[ "DefinitionNotebookClient`" -> None ];
DefinitionNotebookClient`$DisabledHints = {
    <|
        "MessageTag" -> "HeroImageTooSmall",
        "Level"      -> All,
        "ID"         -> All
    |>,
    <|
        "MessageTag" -> "InternalContextWarning",
        "Level"      -> All,
        "ID"         -> All
    |>
};

$messageHistoryLength = 10;
$messageNumber        = 0;
$messageHistory       = <| |>;
$stackHistory         = <| |>;
$inputFileName        = cFile @ Replace[ $InputFileName, "" :> NotebookFileName[ ] ];
$pacletDir            = cDir @ DirectoryName[ $inputFileName, 2 ];

Internal`AddHandler[ "Message", messageHandler ];

$testingHeads = HoldPattern @ Alternatives[
    TestReport,
    VerificationTest,
    Testing`Private`extractUnevaluated
];

$testStack = With[ { h = $testingHeads }, HoldForm[ h[ ___ ] ] ];

messageHandler[
    Hold @ Message[ Wolfram`PacletCICD`TestPaclet::Failures, ___ ],
    _
] := Null;

messageHandler[ Hold[ msg_, True ] ] /; $messageNumber < $messageHistoryLength :=
    StackInhibit @ Module[ { stack, keys, limit, drop },
        stack = Stack[ _ ];
        If[ MemberQ[ stack, $testStack ], Throw[ Null, $tag ] ];

        $messageNumber += 1;
        $messageHistory[ $messageNumber ] = HoldForm @ msg;
        $stackHistory[   $messageNumber ] = stack;

        keys  = Union[ Keys @ $messageHistory, Keys @ $stackHistory ];
        limit = $messageNumber - $messageHistoryLength;
        drop  = Select[ keys, ! TrueQ[ # > limit ] & ];

        KeyDropFrom[ $messageHistory, drop ];
        KeyDropFrom[ $stackHistory  , drop ];

        messagePrint @ msg;
    ] ~Catch~ $tag;


messagePrint // Attributes = { HoldFirst };

messagePrint[ Message[ msg_, args___ ] ] :=
    messagePrint[ msg, args ];

messagePrint[ msg_MessageName, args___ ] :=
    Print[ "::warning::",
           ToString @ Unevaluated @ msg <> ": " <> messageString[ msg, args ]
    ];


messageString[ template_String, args___ ] :=
    ToString[ StringForm[ template, Sequence @@ Short /@ { args } ],
              OutputForm,
              PageWidth -> 80
    ];

messageString[ HoldPattern @ MessageName[ f_, tag_ ], args___ ] :=
    With[ { template = MessageName[ General, tag ] },
        messageString[ template, args ] /; StringQ @ template
    ];

messageString[ ___ ] := "-- Message text not found --";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*gitCommand*)
gitCommand[ { cmd__String }, dir_ ] :=
    Enclose @ Module[ { res },
        res = RunProcess[ { "git", cmd }, ProcessDirectory -> dir ];
        ConfirmAssert[ res[ "ExitCode" ] === 0 ];
        StringTrim @ ConfirmBy[ res[ "StandardOutput" ], StringQ ]
    ];

gitCommand[ cmd_String, dir_ ] := gitCommand[ { cmd }, dir ];

gitCommand[ cmd_ ] := gitCommand[ cmd, Directory[ ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*releaseID*)
releaseID[ dir_ ] :=
    With[ { sha = Environment[ "GITHUB_SHA" ] },
        If[ StringQ @ sha,
            sha,
            gitCommand[ { "rev-parse", "HEAD" }, dir ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*releaseURL*)
releaseURL[ file_ ] :=
    Enclose @ Module[ { pac, repo, ver },
        pac  = PacletObject @ Flatten @ File @ file;
        repo = ConfirmBy[ Environment[ "GITHUB_REPOSITORY" ], StringQ ];
        ver  = ConfirmBy[ pac[ "Version" ], StringQ ];
        TemplateApply[ "https://github.com/`1`/releases/tag/v`2`", { repo, ver } ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*actionURL*)
actionURL[ ] := Enclose[
    Module[ { cs, domain, repo, runID },
        cs     = ConfirmBy[ #, StringQ ] &;
        domain = cs @ Environment[ "GITHUB_SERVER_URL" ];
        repo   = cs @ Environment[ "GITHUB_REPOSITORY" ];
        runID  = cs @ Environment[ "GITHUB_RUN_ID"     ];
        cs @ URLBuild @ { domain, repo, "actions", "runs", runID }
    ],
    "$ACTION_URL$" &
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*updatePacletInfo*)
updatePacletInfo[ dir_ ] /; StringQ @ Environment[ "GITHUB_ACTION" ] := Enclose[
    Module[
        { cs, file, string, id, date, url, run, cmt, new },

        cs     = ConfirmBy[ #, StringQ ] &;
        file   = cs @ FileNameJoin @ { dir, "PacletInfo.wl" };
        string = cs @ ReadString @ file;
        id     = cs @ releaseID @ dir;
        date   = cs @ DateString[ "ISODateTime", TimeZone -> 0 ];
        date   = StringTrim[ date, "Z" ] <> "Z";
        url    = cs @ releaseURL @ file;
        run    = cs @ actionURL[ ];
        cmt    = cs @ commitURL @ id;

        new = cs @ StringReplace[
            string,
            {
                "\r\n"           -> "\n",
                "$RELEASE_ID$"   -> id,
                "$RELEASE_DATE$" -> date,
                "$RELEASE_URL$"  -> url,
                "$ACTION_URL$"   -> run
            }
        ];

        Print[ "Updating PacletInfo"     ];
        Print[ "    ReleaseID:   ", id   ];
        Print[ "    ReleaseDate: ", date ];
        Print[ "    ReleaseURL:  ", url  ];
        Print[ "    ActionURL:   ", run  ];

        Confirm @ WithCleanup[ BinaryWrite[ file, new ],
                               Close @ file
                  ];

        Print[ "Updating definition notebook" ];
        updateReleaseInfoCell[ dir, url, cmt, run ]
    ],
    Function[
        Print[ "::error::Failed to update PacletInfo template parameters." ];
        Exit[ 1 ]
    ]
];



(* updateReleaseInfoCell[ dir_, url_, cmt_, run_ ] /;
    Environment[ "GITHUB_WORKFLOW" ] === "Release" :=
    Enclose @ Module[ { cells, nbFile, nb, rule, exported },

        cells  = ConfirmMatch[ releaseInfoCell[ url, cmt, run ], { __Cell } ];
        nbFile = FileNameJoin @ { dir, "ResourceDefinition.nb" };
        nb     = ConfirmMatch[ Import[ nbFile, "NB" ], _Notebook ];
        rule   = Cell[ ___, CellTags -> { ___, "ReleaseInfoTag", ___ }, ___ ] :>
                     Sequence @@ cells;

        exported = ConfirmBy[ Export[ nbFile, nb /. rule, "NB" ], FileExistsQ ];
        Print[ "Updated definition notebook: ", exported ];
        exported
    ]; *)

updateReleaseInfoCell[ dir_, url_, cmt_, run_ ] /;
    Environment[ "GITHUB_WORKFLOW" ] === "Release" :=
    UsingFrontEnd @ Enclose @ Module[ { nbFile, nb, nbo, saved, exported },
        nbFile   = ExpandFileName @ FileNameJoin @ { dir, "ResourceDefinition.nb" };
        nb       = cicd`ScriptConfirmMatch[ Import[ nbFile, "NB" ], _Notebook, "Import" ];
        nbo      = cicd`ScriptConfirmMatch[ NotebookPut @ nb, _NotebookObject, "NotebookPut" ];
        saved    = cicd`ScriptConfirmMatch[ NotebookSave[ nbo, nbFile ], Null, "NotebookSave" ];
        exported = cicd`ScriptConfirmBy[ Export[ nbFile, Import[ nbFile, "NB" ], "NB" ], FileExistsQ, "Export" ];
        Print[ "Updated definition notebook: ", exported ];
        exported
    ];


commitURL[ sha_String ] := Enclose @ URLBuild @ {
    "https://github.com",
    ConfirmBy[ Environment[ "GITHUB_REPOSITORY" ], StringQ ],
    "commit",
    sha
};


releaseInfoCell[ release_, commit_, run_ ] := Enclose[
    Module[ { environment },
        environment = ConfirmBy[ Environment[ #1 ], StringQ ] &;
        {
            Cell[
                TextData @ {
                    getIcon[ "Tag" ],
                    " ",
                    ButtonBox[
                        FileNameTake @ release,
                        BaseStyle  -> "Hyperlink",
                        ButtonData -> { URL @ release, None },
                        ButtonNote -> release
                    ]
                },
                "Text"
            ],
            Cell[
                TextData @ {
                    getIcon[ "Commit" ],
                    " ",
                    ButtonBox[
                        StringTake[ FileNameTake @ commit, 7 ],
                        BaseStyle  -> "Hyperlink",
                        ButtonData -> { URL @ commit, None },
                        ButtonNote -> commit
                    ]
                },
                "Text"
            ],
            Cell[
                TextData @ {
                    getIcon[ "Action" ],
                    " ",
                    ButtonBox[
                        StringJoin[
                            environment[ "GITHUB_WORKFLOW" ],
                            "/",
                            environment[ "GITHUB_JOB" ]
                        ],
                        BaseStyle  -> "Hyperlink",
                        ButtonData -> { URL @ run, None },
                        ButtonNote -> run
                    ]
                },
                "Text"
            ]
        }
    ],
    None &
];


getIcon[ name_String ] := getIcon[ name ] =
    Get @ FileNameJoin @ { DirectoryName @ $inputFileName, "Resources", "Icons", name<>".wl" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*setResourceSystemBase*)
setResourceSystemBase[ ] := (
    Needs[ "ResourceSystemClient`" -> None ];
    $ResourceSystemBase =
        With[ { rsBase = Environment[ "RESOURCE_SYSTEM_BASE" ] },
            If[ StringQ @ rsBase, rsBase, $ResourceSystemBase ]
        ]
);

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*checkResult*)
checkResult // Attributes = { HoldFirst };

checkResult[ eval: (sym_Symbol)[ args___ ] ] :=
    Module[ { result, ctx, name, stacks, stackName, full },

        result = noExit @ eval;
        ctx    = Context @ Unevaluated @ sym;
        name   = SymbolName @ Unevaluated @ sym;
        full   = ctx <> name;

        If[ $messageNumber > 0
            ,
            stackName = name <> "StackHistory";
            stacks = ExpandFileName[ stackName <> ".wxf" ];
            Print[ "::notice::Exporting stack data: ", stacks ];
            Export[
                stacks,
                $stackHistory,
                "WXF",
                PerformanceGoal -> "Size"
            ];
            setOutput[ "PACLET_STACK_HISTORY", stacks     ];
            setOutput[ "PACLET_STACK_NAME"   , stackName  ];
        ];

        If[ MatchQ[ Head @ result, HoldPattern @ sym ]
            ,
            Print[ "::error::" <> full <> " not defined" ];
            Exit[ 1 ]
        ];

        If[ FailureQ @ result,
            Print[ "::error::" <> full <> " failed" ];
            Exit[ 1 ]
        ]
    ];

noExit    := Wolfram`PacletCICD`Private`noExit;
setOutput := Wolfram`PacletCICD`Private`setOutput;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Setup*)
Print[ "Paclet Directory: ", $pacletDir ];

updatePacletInfo @ $pacletDir;

setResourceSystemBase[ ];
Print[ "ResourceSystemBase: ", $ResourceSystemBase ];

$defNB = File @ FileNameJoin @ { $pacletDir, "ResourceDefinition.nb" };
Print[ "Definition Notebook: ", $defNB ];


$loadedDefinitions = True;

(* :!CodeAnalysis::EndBlock:: *)

EndPackage[ ];
