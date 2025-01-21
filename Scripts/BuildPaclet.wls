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
(*Build*)
result = checkResult @ cicd`BuildPaclet[
    $defNB,
    "Check"      -> $check,
    "ExitOnFail" -> True,
    "Target"     -> "Submit"
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