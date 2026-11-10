(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/WidgetSend.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/WidgetSend.wlt:11,1-16,2"
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
    TestID   -> "WidgetSend-TestDefinitions@@Tests/WidgetSend.wlt:24,1-62,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook Settings*)

(* Sending a single cell with the widget should not turn on automatic assistance for the whole notebook: *)
VerificationTest[
    widgetSendResult @ $testCell,
    { { $testCell, True }, { } },
    SameTest -> SameQ,
    TestID   -> "WidgetSend-AssistanceUnchanged@@Tests/WidgetSend.wlt:69,1-74,2"
]

VerificationTest[
    widgetSendResult @ $Failed,
    { { $testCell, True }, { } },
    SameTest -> SameQ,
    TestID   -> "WidgetSend-RootEvaluationCell-AssistanceUnchanged@@Tests/WidgetSend.wlt:76,1-81,2"
]

VerificationTest[
    Wolfram`Chatbook`$AutomaticAssistance,
    False,
    SameTest -> SameQ,
    TestID   -> "WidgetSend-AutomaticAssistanceScoped@@Tests/WidgetSend.wlt:83,1-88,2"
]

(* :!CodeAnalysis::EndBlock:: *)
