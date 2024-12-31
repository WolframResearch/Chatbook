#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];
Get @ cFile @ FileNameJoin @ { $scriptDir, "Resources", "CodeInspectorRules.wl" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run*)
result = checkResult @ Wolfram`PacletCICD`CheckPaclet[
    $defNB,
    "Target"           -> "Submit",
    "FailureCondition" -> { "Warning", "Error" }
];

EndPackage[ ];

Wolfram`ChatbookScripts`result