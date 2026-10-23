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
(*Chat Output Data*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*asyncChatSubmitQ*)

(* Only the default streaming submit returns before the response is processed: *)
VerificationTest[
    Block[ { $AutomaticAssistance = False },
        Wolfram`Chatbook`SendChat`Private`asyncChatSubmitQ @ Wolfram`Chatbook`Common`resolveAutoSettings @ <|
            Wolfram`Chatbook`Common`$defaultChatSettings,
            #
        |> & /@ {
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |> |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "o3" |> |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>, "ForceSynchronous" -> True |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>, "ProcessingFunctions" -> <| "ChatSubmit" -> (Null &) |> |>
        }
    ],
    { True, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "AsyncChatSubmitQ"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sendChat*)

(* Runs sendChat with the front end and LLM calls stubbed out, and returns the order in which the "ChatPre" handler,
   the chat submit, and the output cell settings writes occur: *)
VerificationTest[
    sendChatEvents[ settings_Association, cloud_: False ] := Module[ { log, evalCell, outputCell, messages, task },
        log        = Internal`Bag[ ];
        evalCell   = CellObject[ "TestEvaluationCell" ];
        outputCell = CellObject[ "TestOutputCell" ];
        messages   = { <| "Role" -> "System", "Content" -> "System prompt" |>, <| "Role" -> "User", "Content" -> "Hello" |> };
        task       = "TestTask";
        Block[
            {
                CurrentValue                                                = Inherited &,
                Wolfram`Chatbook`$AutomaticAssistance                       = False,
                Wolfram`Chatbook`$WorkspaceChat                             = True,
                Wolfram`Chatbook`Common`$cloudNotebooks                     = cloud,
                Wolfram`Chatbook`Common`$useLLMServices                     = True,
                Wolfram`Chatbook`Common`$lastTask                           = None,
                Wolfram`Chatbook`Common`$lastCellObject                     = None,
                Wolfram`Chatbook`Common`$progressContainer                  = None,
                Wolfram`Chatbook`Common`resolveInlineReferences             = Null &,
                Wolfram`Chatbook`Common`withApproximateProgress             = Identity &,
                Wolfram`Chatbook`Common`setProgressDisplay                  = Null &,
                Wolfram`Chatbook`Common`addHandlerArguments                 = Null &,
                Wolfram`Chatbook`SendChat`Private`selectChatCells           = { evalCell } &,
                Wolfram`Chatbook`SendChat`Private`chatHistoryCellsAndTarget = { { evalCell }, None } &,
                Wolfram`Chatbook`SendChat`Private`activeAIAssistantCell     = Cell[ "", "ChatOutput" ] &,
                Wolfram`Chatbook`SendChat`Private`createNewChatOutput       = outputCell &,
                Wolfram`Chatbook`SendChat`Private`prepareMessagesForLLM     = #2 &,
                Wolfram`Chatbook`Common`constructMessages = Function[
                    Sow[ <| "Messages" -> messages |>, Wolfram`Chatbook`Common`$chatDataTag ];
                    messages
                ],
                Wolfram`Chatbook`Common`applyHandlerFunction = Function[
                    If[ #2 === "ChatPre", Internal`StuffBag[ log, "ChatPre" ] ]
                ],
                Wolfram`Chatbook`SendChat`Private`chatSubmit = Function[
                    Internal`StuffBag[ log, "ChatSubmit" ];
                    task
                ],
                Wolfram`Chatbook`Settings`Private`setCurrentChatSettings = Function[
                    Internal`StuffBag[ log, { ## } ]
                ]
            },
            <|
                "Result" -> Wolfram`Chatbook`Common`sendChat[ evalCell, NotebookObject[ "TestNotebook" ], None, settings ],
                "Events" -> Internal`BagPart[ log, All ]
            |>
        ]
    ];
    $baseSettings = <|
        "ForceSynchronous"     -> False,
        "IncludeHistory"       -> False,
        "ProcessingFunctions"  -> <| "ChatSubmit" -> Automatic |>,
        "ResolvedAutoSettings" -> True
    |>;
    $expectedData = <|
        "Messages" -> { <| "Role" -> "System", "Content" -> "System prompt" |>, <| "Role" -> "User", "Content" -> "Hello" |> }
    |>,
    _Association,
    SameTest -> MatchQ,
    TestID   -> "SendChat-Definitions"
]

(* For asynchronous requests, the output cell's "Data" setting is written after the request is submitted: *)
VerificationTest[
    sendChatEvents @ $baseSettings,
    <|
        "Result" -> "TestTask",
        "Events" -> {
            "ChatPre",
            "ChatSubmit",
            { CellObject[ "TestOutputCell" ], "Data"      , $expectedData },
            { CellObject[ "TestOutputCell" ], "CellObject", CellObject[ "TestOutputCell" ] },
            { CellObject[ "TestOutputCell" ], "Task"      , "TestTask" }
        }
    |>,
    SameTest -> SameQ,
    TestID   -> "SendChat-ChatOutputData-Async"
]

(* A synchronous submit can finish the response before returning, so the data needs to be written beforehand: *)
VerificationTest[
    sendChatEvents @ <| $baseSettings, "ForceSynchronous" -> True |>,
    <|
        "Result" -> "TestTask",
        "Events" -> {
            { CellObject[ "TestOutputCell" ], "Data", $expectedData },
            "ChatPre",
            "ChatSubmit",
            { CellObject[ "TestOutputCell" ], "CellObject", CellObject[ "TestOutputCell" ] },
            { CellObject[ "TestOutputCell" ], "Task"      , "TestTask" }
        }
    |>,
    SameTest -> SameQ,
    TestID   -> "SendChat-ChatOutputData-ForceSynchronous"
]

(* A custom submit function might also be synchronous: *)
VerificationTest[
    sendChatEvents @ <| $baseSettings, "ProcessingFunctions" -> <| "ChatSubmit" -> (Null &) |> |>,
    <|
        "Result" -> "TestTask",
        "Events" -> {
            { CellObject[ "TestOutputCell" ], "Data", $expectedData },
            "ChatPre",
            "ChatSubmit",
            { CellObject[ "TestOutputCell" ], "CellObject", CellObject[ "TestOutputCell" ] },
            { CellObject[ "TestOutputCell" ], "Task"      , "TestTask" }
        }
    |>,
    SameTest -> SameQ,
    TestID   -> "SendChat-ChatOutputData-CustomChatSubmit"
]

(* Cloud notebooks do not store the "Data" setting: *)
VerificationTest[
    Lookup[ sendChatEvents[ $baseSettings, True ], "Events" ],
    {
        "ChatPre",
        "ChatSubmit",
        { CellObject[ "TestOutputCell" ], "CellObject", CellObject[ "TestOutputCell" ] },
        { CellObject[ "TestOutputCell" ], "Task"      , "TestTask" }
    },
    SameTest -> SameQ,
    TestID   -> "SendChat-ChatOutputData-Cloud"
]

(* :!CodeAnalysis::EndBlock:: *)
