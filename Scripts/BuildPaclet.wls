#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];
Get @ cFile @ FileNameJoin @ { DirectoryName @ $InputFileName, "BuildStylesheet.wls" };
Get @ cFile @ FileNameJoin @ { DirectoryName @ $InputFileName, "BuildMX.wls" };

result = checkResult @ Wolfram`PacletCICD`BuildPaclet[
    $defNB,
    "Check"      -> False,
    "ExitOnFail" -> True,
    "Target"     -> "Submit"
];

EndPackage[ ];

Wolfram`ChatbookScripts`result