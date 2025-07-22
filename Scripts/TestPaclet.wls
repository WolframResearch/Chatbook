#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

SetOptions[ TestReport, ProgressReporting -> False ];

(* This is a hack to avoid a mysterious issue with the FE not finding the chatbook stylesheet
   the first time a test is run: *)
UsingFrontEnd @ TestReport @ FileNameJoin @ { DirectoryName[ $InputFileName, 2 ], "Tests/CurrentChatSettings.wlt" };

(* Now run the actual tests: *)
result = UsingFrontEnd @ Block[ { messagePrint }, checkResult @ Wolfram`PacletCICD`TestPaclet @ $defNB ];

EndPackage[ ];

Wolfram`ChatbookScripts`result