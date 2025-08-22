#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

SetOptions[ TestReport, ProgressReporting -> False ];

$buildDirectory  = FileNameJoin @ { $pacletDir, "build", "Wolfram__Chatbook" };
$mxFile          = FileNameJoin @ { $buildDirectory, "Source", "Chatbook", "64Bit", "Chatbook.mx" };
$testDir         = cDir @ FileNameJoin @ { $pacletDir, "Tests" };
$ccsTests        = FileNameJoin @ { $testDir, "CurrentChatSettings.wlt" };

If[ StringQ @ Environment[ "GITHUB_ACTIONS" ],
    GeneralUtilities`$DebugMode = True;
    ServiceConnect[ "OpenAI", Authentication -> <| "APIKey" -> Environment[ "OPENAI_API_KEY" ] |> ];
    If[ FileExistsQ @ $ccsTests,
        cicd`ConsoleLog[ "Skipping CurrentChatSettings.wlt" ];
        RenameFile[ $ccsTests, $ccsTests <> ".skipped" ]
    ];
    SetOptions[
        TestReport,
        HandlerFunctions -> <| "TestCreated" -> Function[ Print[ "Test Created: ", #[ "TestObject" ][ "TestID" ] ] ] |>,
        HandlerFunctionsKeys -> { "TestObject" }
    ]
];

If[ ! FileExistsQ @ $mxFile && getBooleanArgument[ { "b", "build" }, True ],
    Get @ cFile @ FileNameJoin @ { $scriptDir, "BuildPaclet.wls" }
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run Tests*)
(* This is a hack to avoid a mysterious issue with the FE not finding the chatbook stylesheet
   the first time a test is run: *)
If[ FileExistsQ @ $ccsTests, UsingFrontEnd @ TestReport @ $ccsTests ];

(* Now run the actual tests: *)
result = UsingFrontEnd @ Block[ { messagePrint }, checkResult @ Wolfram`PacletCICD`TestPaclet @ $defNB ];

EndPackage[ ];

Wolfram`ChatbookScripts`result