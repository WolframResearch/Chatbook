(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Test Definitions*)
VerificationTest[
    $testCell     = CellObject[ "WidgetSendTestCell" ];
    $testNotebook = NotebookObject[ "WidgetSendTestNotebook" ];

    (* Gives { sendArguments, writes } where writes are the front end values set by WidgetSend: *)
    widgetSendResult[ cell_ ] := Module[ { sendArguments = None, writes = { } },
        Internal`InheritedBlock[
            {
                Wolfram`Chatbook`$ChatHandlerData,
                Wolfram`Chatbook`Common`$lastCellObject,
                Wolfram`Chatbook`Common`$lastTask,
                Wolfram`Chatbook`Common`parentNotebook,
                Wolfram`Chatbook`Common`setCurrentValue,
                Wolfram`Chatbook`Common`rootEvaluationCell
            },
            Wolfram`Chatbook`Common`parentNotebook[ $testCell ] = $testNotebook;
            Wolfram`Chatbook`Common`rootEvaluationCell[ ] = $testCell;
            DownValues[ Wolfram`Chatbook`Common`setCurrentValue ] = {
                HoldPattern[ Wolfram`Chatbook`Common`setCurrentValue[ args___ ] ] :> (AppendTo[ writes, { args } ]; Null)
            };
            (* SendChat is private to the Actions package: *)
            Block[
                {
                    Wolfram`Chatbook`Actions`Private`SendChat = Function[
                        sendArguments = { ##, Wolfram`Chatbook`$AutomaticAssistance };
                        Null
                    ]
                },
                Wolfram`Chatbook`Actions`WidgetSend @ cell
            ]
        ];
        { sendArguments, writes }
    ];

    Null,
    Null,
    SameTest -> SameQ,
    TestID   -> "WidgetSend-TestDefinitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook Settings*)

(* Sending a single cell with the widget should not turn on automatic assistance for the whole notebook: *)
VerificationTest[
    widgetSendResult @ $testCell,
    { { $testCell, True }, { } },
    SameTest -> SameQ,
    TestID   -> "WidgetSend-AssistanceUnchanged"
]

VerificationTest[
    widgetSendResult @ $Failed,
    { { $testCell, True }, { } },
    SameTest -> SameQ,
    TestID   -> "WidgetSend-RootEvaluationCell-AssistanceUnchanged"
]

VerificationTest[
    Wolfram`Chatbook`$AutomaticAssistance,
    False,
    SameTest -> SameQ,
    TestID   -> "WidgetSend-AutomaticAssistanceScoped"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Button Method*)

(* The first chat in a kernel can take longer than the preemptive evaluation timeout, which would abort it, so the
   widget button in the built stylesheets must be queued: *)
VerificationTest[
    Module[ { dir, methods },
        dir = PacletObject[ "Wolfram/Chatbook" ][ "Location" ];
        methods[ file_ ] := Cases[
            ReadList[ FileNameJoin @ Prepend[ file, dir ], HoldComplete @ Expression ],
            cell: Cell[ StyleData[ "ChatWidgetButton" ], ___ ] :>
                Cases[ cell, ButtonBox[ ___, Method -> m_, ___ ] :> m, Infinity ],
            Infinity
        ];
        methods /@ {
            { "FrontEnd", "StyleSheets", "Chatbook.nb" },
            { "FrontEnd", "Assets", "Extensions", "CoreExtensions.nb" }
        }
    ],
    { { { "Queued" } }, { { "Queued" } } },
    SameTest -> SameQ,
    TestID   -> "WidgetSend-QueuedButton-GH#1718"
]

(* :!CodeAnalysis::EndBlock:: *)
