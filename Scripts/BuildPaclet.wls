#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];
Get @ cFile @ FileNameJoin @ { DirectoryName @ $InputFileName, "UnformatFiles.wls" };
Get @ cFile @ FileNameJoin @ { DirectoryName @ $InputFileName, "BuildMX.wls" };
Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Build*)
result = checkResult @ cicd`BuildPaclet[
    $defNB,
    "Check"      -> False,
    "ExitOnFail" -> True,
    "Target"     -> "Submit"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Install*)
If[ MemberQ[ $scriptCommandLine, "-i"|"--install"|"--install=true" ],
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