BeginPackage[ "Wolfram`ChatbookScripts`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
Wolfram`PacletCICD`$Debug = True;

Off[ General::shdw           ];
Off[ PacletInstall::samevers ];

If[ StringQ @ Environment[ "GITHUB_ACTIONS" ], PacletInstall[ "Wolfram/LLMFunctions", UpdatePacletSites -> True ] ];

If[ ! PacletObjectQ @ PacletObject[ "Wolfram/PacletCICD" ],
    PacletInstall[ "https://github.com/WolframResearch/PacletCICD/releases/download/v0.36.2/Wolfram__PacletCICD-0.36.2.paclet" ]
];

Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

cFile = cicd`ScriptConfirmBy[ #, FileExistsQ ] &;
cDir  = cicd`ScriptConfirmBy[ #, DirectoryQ  ] &;
cStr  = cicd`ScriptConfirmBy[ #, StringQ     ] &;

Needs[ "DefinitionNotebookClient`" -> None ];
DefinitionNotebookClient`$DisabledHints = <| "MessageTag" -> #, "Level" -> All, "ID" -> All |> & /@ {
    "CodeInspectionFileIssue/TopLevel",
    "HeroImageTooSmall",
    "InternalContextWarning",
    "StylesheetSubdirectory"
};

$messageHistoryLength = 10;
$messageNumber        = 0;
$messageHistory       = <| |>;
$stackHistory         = <| |>;
$inputFileName        = cFile @ Replace[ $InputFileName, "" :> NotebookFileName[ ] ];
$pacletDir            = cDir @ DirectoryName[ $inputFileName, 2 ];
$scriptDir            = DirectoryName @ $inputFileName;

Internal`AddHandler[ "Message", messageHandler ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
$testingHeads = HoldPattern @ Alternatives[
    TestReport,
    VerificationTest,
    Testing`Private`extractUnevaluated
];
(* :!CodeAnalysis::EndBlock:: *)

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

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
messagePrint[ msg_MessageName, args___ ] :=
    Print[ "::warning::",
           ToString @ Unevaluated @ msg <> ": " <> messageString[ msg, args ]
    ];
(* :!CodeAnalysis::EndBlock:: *)

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
(*Command Line Arguments*)
$scriptCommandLine := Select[ Flatten @ { Replace[ $ScriptCommandLine, { } :> $CommandLine ] }, StringQ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getBooleanArgument*)
getBooleanArgument // Attributes = { HoldRest };

getBooleanArgument[ name_ ] :=
    getBooleanArgument[ name, False ];

getBooleanArgument[ name_String, default_ ] :=
    getBooleanArgument[ { name, name }, default ];

getBooleanArgument[ { short_String, full_String }, default_ ] := Catch[
    Module[ { named, interpreted, res },
        If[ MemberQ[ $scriptCommandLine, "-"<>short | "--"<>full ], Throw[ True, $booleanTag ] ];
        named = getNamedArgument @ full;
        If[ ! StringQ @ named, Throw[ default, $booleanTag ] ];
        interpreted = Interpreter[ "Boolean" ][ named ];
        If[ BooleanQ @ interpreted,
            interpreted,
            res = default;
            cicd`ConsoleError @ TemplateApply[
                "The value \"`1`\" specified for \"`2`\" is not a valid boolean value. Using default value: \"`3`\".",
                { named, full, res }
            ];
            res
        ]
    ],
    $booleanTag
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getNamedArgument*)
getNamedArgument // Attributes = { HoldRest };

getNamedArgument[ name_ ] :=
    getNamedArgument[ name, Missing[ "NotSpecified" ] ];

getNamedArgument[ name_String, default_ ] :=
    Module[ { arg },
        arg = SelectFirst[ $scriptCommandLine, StringQ @ # && StringStartsQ[ #, "--"<>name<>"=" ] & ];
        If[ StringQ @ arg,
            StringDelete[ arg, StartOfString ~~ "--"<>name<>"=" ],
            default
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
$$ws = WhitespaceCharacter...;
$$id = "\"" ~~ Except[ "\"" ].. ~~ "\"";

$envSHA = SelectFirst[
    { Environment[ "GITHUB_SHA" ], Environment[ "BUILD_VCS_NUMBER_WolframLanguage_Paclets_Chatbook_PacChatbook" ] },
    StringQ
];

$inCICD = StringQ @ $envSHA;
$updatePacletInfo = TrueQ[ $inCICD && ! MatchQ[ Environment[ "UPDATE_PACLET_INFO" ], "false"|"False"|"0" ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*gitCommand*)
gitCommand[ { cmd__String }, dir_ ] :=
    Enclose @ Module[ { res },
        res = RunProcess[ { "git", cmd }, ProcessDirectory -> ExpandFileName @ dir ];
        ConfirmAssert[ res[ "ExitCode" ] === 0 ];
        StringTrim @ ConfirmBy[ res[ "StandardOutput" ], StringQ ]
    ];

gitCommand[ cmd_String, dir_ ] := gitCommand[ { cmd }, dir ];

gitCommand[ cmd_ ] := gitCommand[ cmd, Directory[ ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*releaseID*)
releaseID[ dir_ ] := FirstCase[
    Unevaluated @ { $envSHA, gitCommand[ { "rev-parse", "HEAD" }, dir ] },
    expr_ :> With[ { id = expr }, id /; StringQ @ id ],
    "None"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*releaseURL*)
releaseURL[ file_ ] := Enclose[
    Module[ { pac, repo, ver },
        pac  = PacletObject @ Flatten @ File @ file;
        repo = ConfirmBy[ Environment[ "GITHUB_REPOSITORY" ], StringQ ];
        ver  = ConfirmBy[ pac[ "Version" ], StringQ ];
        TemplateApply[ "https://github.com/`1`/releases/tag/v`2`", { repo, ver } ]
    ],
    "None" &
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
    "None" &
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*updatePacletInfo*)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
updatePacletInfo[ dir_ ] /; $updatePacletInfo := Enclose[
    Module[
        { cs, file, string, id, date, url, run, cmt, oldID, new },

        cs     = ConfirmBy[ Echo[ #1, "Update PacletInfo [" <> ToString @ #2 <> "]: " ], StringQ, #2 ] &;
        file   = cs[ FileNameJoin @ { dir, "PacletInfo.wl" }, "Original PacletInfo" ];
        string = cs[ ReadString @ file, "ReadString" ];
        id     = cs[ releaseID @ dir, "ReleaseID" ];
        date   = cs[ DateString[ "ISODateTime", TimeZone -> 0 ], "Timestamp" ];
        date   = StringTrim[ date, "Z" ] <> "Z";
        url    = cs[ releaseURL @ file, "ReleaseURL" ];
        run    = cs[ actionURL[ ], "ActionURL" ];
        cmt    = cs[ commitURL @ id, "CommitURL" ];
        oldID  = cs[ PacletObject[ Flatten @ File @ dir ][ "ReleaseID" ], "OldReleaseID" ];

        new = cs[
            StringReplace[
                string,
                {
                    "\r\n"           -> "\n",
                    oldID            -> id,
                    "$RELEASE_DATE$" -> date,
                    "$RELEASE_URL$"  -> url,
                    "$ACTION_URL$"   -> run,
                    "$COMMIT_URL$"   -> cmt
                }
            ],
            "Updated PacletInfo"
        ];

        Print[ "Updating PacletInfo"     ];
        Print[ "    ReleaseID:   ", id   ];
        Print[ "    ReleaseDate: ", date ];
        Print[ "    ReleaseURL:  ", url  ];
        Print[ "    ActionURL:   ", run  ];
        Print[ "    CommitURL:   ", cmt  ];

        Confirm @ WithCleanup[ BinaryWrite[ file, new ],
                               Close @ file
                  ];

        (* Print[ "Updating definition notebook" ];
        updateReleaseInfoCell[ dir, url, cmt, run ] *)
    ],
    Function[
        Print[ "::error::Failed to update PacletInfo template parameters." ];
        Print[ "    ", ToString[ #, InputForm ] ];
        If[ StringQ @ Environment[ "GITHUB_ACTION" ], Exit[ 1 ] ]
    ]
];
(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*setPacletReleaseID*)
(* :!CodeAnalysis::Disable::LeakedVariable:: *)
setPacletReleaseID[ dir_ ] :=
    setPacletReleaseID[ dir, releaseID @ dir ];

setPacletReleaseID[ dir_, id_String? StringQ ] :=
    Enclose @ Module[ { file, bytes, string, new },
        file = ConfirmBy[ FileNameJoin @ { dir, "PacletInfo.wl" }, FileExistsQ, "PacletInfoFile" ];
        bytes = ConfirmBy[ ReadByteArray @ file, ByteArrayQ, "ByteArray" ];
        Quiet @ Close @ file;
        string = ConfirmBy[ ByteArrayToString @ bytes, StringQ, "String" ];
        new = StringReplace[ string, before: ("\"ReleaseID\""~~$$ws~~"->"~~$$ws) ~~ $$id :> before<>"\""<>id<>"\"" ];
        cicd`ConsoleNotice @ SequenceForm[ "Setting paclet release ID: ", id ];
        WithCleanup[ BinaryWrite[ file, StringToByteArray @ new ], Close @ file ];
        id
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*updateReleaseInfoCell*)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
updateReleaseInfoCell[ dir_, url_, cmt_, run_ ] /;
    Environment[ "GITHUB_WORKFLOW" ] === "Release" :=
    UsingFrontEnd @ Enclose @ Module[ { cells, nbFile, nbo, cell },

        cells  = ConfirmMatch[ releaseInfoCell[ url, cmt, run ], { __Cell }, "Cells" ];
        nbFile = ConfirmBy[ FileNameJoin @ { dir, "ResourceDefinition.nb" }, FileExistsQ, "File" ];
        nbo    = ConfirmMatch[ NotebookOpen @ nbFile, _NotebookObject, "Notebook" ];
        cell   = ConfirmMatch[ First[ Cells[ nbo, CellTags -> "ReleaseInfoTag" ], $Failed ], _CellObject, "Cell" ];

        ConfirmMatch[ NotebookWrite[ cell, cells ], Null, "NotebookWrite" ];
        ConfirmMatch[ NotebookSave @ nbo, Null, "NotebookSave" ];
        NotebookClose @ nbo;

        Print[ "Updated definition notebook: ", nbFile ];
        nbFile
    ];
(* :!CodeAnalysis::EndBlock:: *)

commitURL[ sha_String ] := URLBuild @ { "https://github.com/WolframResearch/Chatbook/commit", sha };


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
    Cell @ BoxData @ ToBoxes @ Get @ FileNameJoin @ {
        DirectoryName @ $inputFileName,
        "Resources",
        "Icons",
        name<>".wl"
    };

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
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
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
                First @ $stackHistory,
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
        ];

        result
    ];
(* :!CodeAnalysis::EndBlock:: *)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
noExit    := Wolfram`PacletCICD`Private`noExit;
setOutput := Wolfram`PacletCICD`Private`setOutput;
(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Setup*)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
Print[ "Paclet Directory: ", $pacletDir ];

updatePacletInfo @ $pacletDir;

setResourceSystemBase[ ];
Print[ "ResourceSystemBase: ", $ResourceSystemBase ];

$defNB = File @ FileNameJoin @ { $pacletDir, "ResourceDefinition.nb" };
Print[ "Definition Notebook: ", $defNB ];

cicd`ScriptConfirmBy[ PacletDirectoryLoad @ $pacletDir, MemberQ @ $pacletDir ];
cicd`ScriptConfirmAssert[
    StringStartsQ[ FindFile[ "Wolfram`Chatbook`" ], $pacletDir ],
    TemplateApply[
        "Chatbook context points to \"`1`\" which is not contained in the expected paclet directory \"`2`\".",
        { FindFile["Wolfram`Chatbook`"], $pacletDir }
    ]
];

$loadedDefinitions = True;

(* :!CodeAnalysis::EndBlock:: *)

EndPackage[ ];
