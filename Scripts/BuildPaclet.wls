#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];
If[ ! StringQ @ Environment[ "GITHUB_ACTIONS" ], System`$PublisherID = "Wolfram" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Arguments*)
$check    = getBooleanArgument[ { "c", "check"    }, True  ];
$install  = getBooleanArgument[ { "i", "install"  }, False ];
$mx       = getBooleanArgument[ { "m", "mx"       }, True  ];
$unformat = getBooleanArgument[ { "u", "unformat" }, True  ];
$download = getBooleanArgument[ { "s", "snippets" }, True  ];

$wolframVersionOverride = getNamedArgument[ "wolfram-version", None ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Optional Dependencies*)
If[ $unformat, Get @ cFile @ FileNameJoin @ { $scriptDir, "UnformatFiles.wls" } ];
If[ $mx      , Get @ cFile @ FileNameJoin @ { $scriptDir, "BuildMX.wls" } ];
If[ $check   , Get @ cFile @ FileNameJoin @ { $scriptDir, "Resources", "CodeInspectorRules.wl" } ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Other*)
Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Download Documentation Snippets*)
If[ $download,
    Block[ { $ProgressReporting = True },
        cicd`ConsoleLog[ "Downloading documentation snippets..." ];
        snippetDir = cDir @ Wolfram`Chatbook`InstallDocumentationResources[ ][ "Location" ];
        targetDir = FileNameJoin @ { $pacletDir, "Assets/Snippets/Streamable" };
        If[ DirectoryQ @ targetDir, DeleteDirectory[ targetDir, DeleteContents -> True ] ];
        GeneralUtilities`EnsureDirectory @ DirectoryName @ targetDir;
        copied = cDir @ CopyDirectory[ snippetDir, targetDir ];
        cicd`ConsoleLog @ SequenceForm[ "Copied documentation snippets to: ", copied ];
        If[ StringQ @ Environment[ "GITHUB_ACTIONS" ], DeleteDirectory[ snippetDir, DeleteContents -> True ] ];
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Build*)
result = checkResult @ cicd`BuildPaclet[
    $defNB,
    "Check"      -> $check,
    "ExitOnFail" -> True,
    "Target"     -> "Submit"
];

cicd`ConsoleLog @ SequenceForm[ "Built paclet: ", cFile @ result[ "PacletArchive" ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Override Wolfram version in built paclet*)
If[ StringQ @ $wolframVersionOverride,
    newVersion = StringTrim[ $wolframVersionOverride, "\"" ];
    cicd`ConsoleNotice @ SequenceForm[ "Overriding Wolfram version in built paclet" ];
    archive = cFile @ result[ "PacletArchive" ];
    tmp = cDir @ CreateDirectory[ ];
    extracted = cicd`ScriptConfirmMatch[ ExtractArchive[ archive, tmp ], { __String } ];
    pacInfoFile = First @ FileNames[ "PacletInfo.wl", tmp, { 2 } ];
    string = cStr @ ReadString @ pacInfoFile;

    new = StringReplace[
        string,
        StringExpression[
            a: ("\"WolframVersion\"" ~~ WhitespaceCharacter... ~~ "->" ~~ WhitespaceCharacter... ~~ "\""),
            old: Except[ "\"" ]..,
            b: "\""
        ] :> (
            oldVersion = old;
            a<>newVersion<>b
        )
    ];

    cicd`ScriptConfirmAssert[ oldVersion =!= newVersion, "UnchangedWolframVersion" ];

    cicd`ConsoleNotice @ SequenceForm[ "Replacing Wolfram version ", oldVersion, " with ", newVersion ];

    cFile @ Export[ pacInfoFile, new, "String" ];
    dir = cStr @ DirectoryName @ pacInfoFile;
    newArchive = cFile @ CreatePacletArchive @ dir;
    copied = cFile @ CopyFile[ newArchive, archive, OverwriteTarget -> True ];
    cicd`ConsoleNotice @ SequenceForm[ "Replaced Wolfram version in paclet archive: ", copied ];
    DeleteDirectory[ tmp, DeleteContents -> True ];
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install*)
If[ $install,
    archive = cFile @ result[ "PacletArchive" ];
    cicd`ConsoleNotice @ SequenceForm[ "Installing paclet file: ", archive ];
    installed = cicd`ScriptConfirmBy[ PacletInstall[ archive, ForceVersionInstall -> True ], PacletObjectQ ];
    cicd`ConsoleNotice @ SequenceForm[ "Installed paclet: ", cDir @ installed[ "Location" ] ];
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
EndPackage[ ];

Wolfram`ChatbookScripts`result