#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

$buildDirectory  = FileNameJoin @ { $pacletDir, "build", "Wolfram__Chatbook" };
$mxFile          = FileNameJoin @ { $buildDirectory, "Source", "Chatbook", "64Bit", "Chatbook.mx" };
$testDir         = cDir @ FileNameJoin @ { $pacletDir, "Tests" };
$ccsTests        = FileNameJoin @ { $testDir, "CurrentChatSettings.wlt" };

If[ StringQ @ Environment[ "GITHUB_ACTIONS" ],
    Quiet[
        ServiceConnect[
            "OpenAI",
            "New",
            Authentication -> <| "APIKey" -> Environment[ "OPENAI_API_KEY" ] |>,
            SaveConnection -> False
        ],
        ServiceConnect::warnnosync
    ]
];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
(* Improve readability of GitHub Actions output by writing some test events to stdout. *)
SetOptions[
    TestReport,
    HandlerFunctions -> <|
        "FileStarted"   -> Function @ Print[ "Starting test file: ", #[ "TestFileName" ] ],
        "FileFinished"  -> Function @ Print[ "Finished test file: ", #[ "TestFileName" ] ],
        "TestCreated"   -> Function @ Print[ "\tCurrent test: " , #[ "TestObject" ][ "TestID" ] ],
        "TestEvaluated" -> checkTestResult
    |>,
    HandlerFunctionsKeys -> { "Outcome", "TestFileName", "TestObject" },
    ProgressReporting    -> False
];

checkTestResult[ as_Association ] :=
    Catch @ Module[ { outcome, testObject, testID, string },
        outcome = as[ "Outcome" ];
        If[ outcome =!= "Success",
            testObject = as[ "TestObject" ];
            If[ MemberQ[ FileNameSplit @ testObject[ "TestFileName" ], "TestResources" ], Throw @ Null ];
            testID = testObject[ "TestID" ];
            cicd`ConsoleError[ SequenceForm[ "\tTest failed: (", outcome, ") ", testID ], "Fatal" -> False ];
            If[ StringQ @ Environment[ "GITHUB_ACTIONS" ],
                string = ToString[
                    ReplaceAll[
                        testObject,
                        Hyperlink[ label_String, url_String ] /; And[
                            StringStartsQ[ label, "Report this issue" ],
                            StringStartsQ[ url, "https://github.com/" ~~ __ ~~ "/issues/new?" ]
                        ] :> RuleCondition @ Hyperlink[ label, First @ StringSplit[ url, "?" ] ]
                    ],
                    InputForm,
                    PageWidth -> Infinity
                ];
                If[ StringLength @ string > 5000, string = StringTake[ string, 5000 ] <> " ..." ];
                cicd`ConsoleLog @ string
            ]
        ]
    ];
(* :!CodeAnalysis::EndBlock:: *)

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