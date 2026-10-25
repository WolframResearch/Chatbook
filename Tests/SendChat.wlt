(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/SendChat.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/SendChat.wlt:11,1-16,2"
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
    TestID   -> "AsyncChatSubmitQ@@Tests/SendChat.wlt:30,1-45,2"
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
    TestID   -> "SendChat-Definitions@@Tests/SendChat.wlt:53,1-112,2"
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
    TestID   -> "SendChat-ChatOutputData-Async@@Tests/SendChat.wlt:115,1-129,2"
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
    TestID   -> "SendChat-ChatOutputData-ForceSynchronous@@Tests/SendChat.wlt:132,1-146,2"
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
    TestID   -> "SendChat-ChatOutputData-CustomChatSubmit@@Tests/SendChat.wlt:149,1-163,2"
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
    TestID   -> "SendChat-ChatOutputData-Cloud@@Tests/SendChat.wlt:166,1-176,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*StopChat*)

(* Runs StopChat on an output cell with the front end stubbed out, where `settings` are the output cell's chat
   settings and the response so far is "Partial response". Returns the TaggingRules keys of the final cell that StopChat
   writes: *)
VerificationTest[
    stopChatTaggingRules[ settings_ ] := Module[ { written, result },
        written = Internal`Bag[ ];
        Block[
            {
                CurrentValue                                              = Inherited &,
                FinishDynamic                                             = Null &,
                Wolfram`Chatbook`$AutomaticAssistance                     = False,
                Wolfram`Chatbook`$WorkspaceChat                           = False,
                Wolfram`Chatbook`$SidebarChat                             = False,
                Wolfram`Chatbook`Common`$cloudNotebooks                   = False,
                Wolfram`Chatbook`Common`$lastTask                         = None,
                Wolfram`Chatbook`Common`parentCell                        = None &,
                Wolfram`Chatbook`Common`cellOpenQ                         = True &,
                Wolfram`Chatbook`Common`setCurrentValue                   = Null &,
                Wolfram`Chatbook`Common`usingFrontEnd                     = Function[ eval, eval, HoldFirst ],
                Wolfram`Chatbook`Actions`Private`ensureChatOutputCell     = # &,
                Wolfram`Chatbook`SendChat`Private`waitForLastChatOutput   = Null &,
                Wolfram`Chatbook`Common`currentChatSettings = <|
                    settings,
                    "AutoFormat" -> False,
                    "Container"  -> <| "FullContent" -> "Partial response" |>,
                    "Task"       -> None
                |> &,
                Wolfram`Chatbook`Common`applyProcessingFunction = Function[
                    If[ #2 === "WriteChatOutputCell", Internal`StuffBag[ written, #3 ] ]
                ]
            },
            result = Wolfram`Chatbook`ChatbookAction[ "StopChat", CellObject[ "TestOutputCell" ] ];
            If[ FailureQ @ result,
                result,
                Replace[
                    Internal`BagPart[ written, All ],
                    HoldComplete[ _, Cell[ __, TaggingRules -> rules_, ___ ], _ ] :> Sort @ Keys @ rules,
                    { 1 }
                ]
            ]
        ]
    ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "StopChat-ChatOutputData-Definitions@@Tests/SendChat.wlt:185,1-227,2"
]

VerificationTest[
    stopChatTaggingRules @ <| Wolfram`Chatbook`Common`$defaultChatSettings, "Data" -> $expectedData |>,
    { { "CellToStringData", "ChatData" } },
    SameTest -> SameQ,
    TestID   -> "StopChat-ChatOutputData@@Tests/SendChat.wlt:229,1-234,2"
]

(* For asynchronous requests, a chat can be stopped after a response chunk arrives but before sendChat writes "Data" to
   the output cell. The final cell is then written without "ChatData": *)
VerificationTest[
    stopChatTaggingRules @ Wolfram`Chatbook`Common`$defaultChatSettings,
    { { "CellToStringData" } },
    SameTest -> SameQ,
    TestID   -> "StopChat-ChatOutputData-Not-Written-GH#1709@@Tests/SendChat.wlt:238,1-243,2"
]

(* :!CodeAnalysis::EndBlock:: *)
