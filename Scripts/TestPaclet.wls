#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];
Get @ cFile @ FileNameJoin @ { DirectoryName @ $InputFileName, "BuildMX.wls" };

SetOptions[ TestReport, ProgressReporting -> False ];

Print[ "Scope context test: ", Context /@ Names[ "*`Scope" ] ];

(* This is a hack to avoid a mysterious issue with the FE not finding the chatbook stylesheet
   the first time a test is run: *)
UsingFrontEnd @ TestReport @ FileNameJoin @ { DirectoryName[ $InputFileName, 2 ], "Tests/CurrentChatSettings.wlt" };

(* Now run the actual tests: *)
result = UsingFrontEnd @ checkResult @ Wolfram`PacletCICD`TestPaclet @ $defNB;

EndPackage[ ];

Wolfram`ChatbookScripts`result