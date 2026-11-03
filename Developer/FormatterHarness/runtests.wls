(* Usage: ./runtests.sh file1.wlt [file2.wlt ...]
   Runs Chatbook tests in one kernel with a front end available and prints a concise report. *)
$files = Rest @ $ScriptCommandLine;
$repo  = Replace[ Environment[ "CHATBOOK_REPO" ], $Failed :> FileNameDrop[ DirectoryName @ $InputFileName, -2 ] ];
PacletDirectoryLoad[ $repo ];
UsingFrontEnd[ Null ];
Do[
    Module[ { report, results, failed },
        report  = TestReport[ file ];
        results = Values @ report[ "TestResults" ];
        failed  = Select[ results, #[ "Outcome" ] =!= "Success" & ];
        Print[ "FILE: ", file, "  passed ", Count[ results, _? (#[ "Outcome" ] === "Success" &) ], "/", Length @ results,
               "  time ", Round[ report[ "TimeElapsed" ], 0.1 ] ];
        Scan[
            Function[ r,
                Print[ "  FAIL [", r[ "Outcome" ], "] ", r[ "TestID" ] ];
                Print[ "    input:    ", StringTake[ ToString[ r[ "Input" ], InputForm ], UpTo[ 800 ] ] ];
                Print[ "    expected: ", StringTake[ ToString[ r[ "ExpectedOutput" ], InputForm ], UpTo[ 1500 ] ] ];
                Print[ "    actual:   ", StringTake[ ToString[ r[ "ActualOutput" ], InputForm ], UpTo[ 1500 ] ] ];
                If[ r[ "Outcome" ] === "MessagesFailure",
                    Print[ "    messages: ", StringTake[ ToString[ r[ "ActualMessages" ], InputForm ], UpTo[ 600 ] ] ]
                ]
            ],
            failed
        ]
    ],
    { file, $files }
];
