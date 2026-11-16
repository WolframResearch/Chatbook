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
(*StopChat*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Definitions*)
VerificationTest[
    (* Runs StopChat[ ] the way a stop button does, with the front end stubbed out. A stop button runs it as a
       preemptive evaluation, which sees the Block-scoped state of a chat that is evaluating, so `evaluating` sets
       $chatState like withChatState does. `parent` gives each cell's parent cell. Returns the stop request,
       $ChatEvaluationCell afterwards, and the cells that StopChat stopped: *)
    stopChat[ evaluating_, lastCell_, stopRequested_: False, lastTask_: None, parent_: (None &) ] := Module[
        { stopped },
        stopped = Internal`Bag[ ];
        Block[
            {
                Wolfram`Chatbook`$ChatEvaluationCell             = CellObject[ "TestInputCell" ],
                Wolfram`Chatbook`Common`$chatState               = evaluating,
                Wolfram`Chatbook`Common`$chatStopRequested       = stopRequested,
                Wolfram`Chatbook`Common`$lastCellObject          = lastCell,
                Wolfram`Chatbook`Common`$lastTask                = lastTask,
                Wolfram`Chatbook`Common`parentCell               = parent,
                Wolfram`Chatbook`Actions`Private`chatOutputCellQ = MatchQ[ CellObject[ "TestOutputCell" ] ],
                Wolfram`Chatbook`Common`chatInputCellQ           = MatchQ[ CellObject[ "TestInputCell" ] ],
                (* Every cell that StopChat stops passes through here: *)
                Wolfram`Chatbook`Actions`Private`ensureChatOutputCell = (Internal`StuffBag[ stopped, # ]; None) &
            },
            Wolfram`Chatbook`ChatbookAction[ "StopChat" ];
            <|
                "StopRequested"      -> Wolfram`Chatbook`Common`$chatStopRequested,
                "ChatEvaluationCell" -> Wolfram`Chatbook`$ChatEvaluationCell,
                "Stopped"            -> Internal`BagPart[ stopped, All ]
            |>
        ]
    ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "StopChat-Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*While a Chat Is Evaluating*)

(* Before the chat has an output cell, the stop used to fall back to the input cell, which stopped nothing (or the
   previous chat), and the chat continued without a stop button: *)
VerificationTest[
    stopChat[ True, None ],
    <| "StopRequested" -> True, "ChatEvaluationCell" -> None, "Stopped" -> { } |>,
    SameTest -> SameQ,
    TestID   -> "StopChat-Evaluating-No-Output-Cell-GH#1708"
]

(* The output cell is stopped as before, and the chat is also told not to submit its request: *)
VerificationTest[
    stopChat[ True, CellObject[ "TestOutputCell" ] ],
    <| "StopRequested" -> True, "ChatEvaluationCell" -> None, "Stopped" -> { CellObject[ "TestOutputCell" ] } |>,
    SameTest -> SameQ,
    TestID   -> "StopChat-Evaluating-Output-Cell-GH#1707"
]

(* An output cell in the sidebar is nested in other cells, and it's the output cell that's stopped, not the sidebar: *)
VerificationTest[
    stopChat[
        True,
        CellObject[ "TestOutputCell" ],
        False,
        None,
        Replace[ {
            CellObject[ "TestOutputCell" ]    -> CellObject[ "TestScrollingCell" ],
            CellObject[ "TestScrollingCell" ] -> CellObject[ "TestSidebarCell" ],
            _                                 -> $Failed
        } ]
    ],
    <| "StopRequested" -> True, "ChatEvaluationCell" -> None, "Stopped" -> { CellObject[ "TestOutputCell" ] } |>,
    SameTest -> SameQ,
    TestID   -> "StopChat-Evaluating-Sidebar-Output-Cell-GH#1707"
]

(* A chat is only stopped once: *)
VerificationTest[
    stopChat[ True, CellObject[ "TestOutputCell" ], True ],
    <| "StopRequested" -> True, "ChatEvaluationCell" -> CellObject[ "TestInputCell" ], "Stopped" -> { } |>,
    SameTest -> SameQ,
    TestID   -> "StopChat-Evaluating-Already-Stopped"
]

(* The request's task is removed, even if it isn't in the output cell's settings yet: *)
VerificationTest[
    Module[ { task },
        task = SessionSubmit @ ScheduledTask[ Null, { 60 } ];
        stopChat[ True, None, False, task ];
        task[ "TaskStatus" ]
    ],
    "Removed",
    SameTest -> SameQ,
    TestID   -> "StopChat-Evaluating-Removes-Task-GH#1707"
]

(* If submitting the request failed, there's no task to remove: *)
VerificationTest[
    stopChat[ True, None, False, Failure[ "TestFailure", <| |> ] ],
    <| "StopRequested" -> True, "ChatEvaluationCell" -> None, "Stopped" -> { } |>,
    SameTest -> SameQ,
    TestID   -> "StopChat-Evaluating-Failed-Request"
]

(* The stop button in an output cell's dingbat (cloud notebooks) stops that cell. If it's the output of the chat that's
   evaluating, the chat stops too, and its stop button is hidden: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`$ChatEvaluationCell                  = CellObject[ "TestInputCell" ],
            Wolfram`Chatbook`Common`$chatState                    = #1,
            Wolfram`Chatbook`Common`$chatStopRequested            = False,
            Wolfram`Chatbook`Common`$lastCellObject               = CellObject[ "TestOutputCell" ],
            Wolfram`Chatbook`Common`$lastTask                     = None,
            Wolfram`Chatbook`Common`parentCell                    = None &,
            Wolfram`Chatbook`Common`writeReformattedCell          = Null &,
            Wolfram`Chatbook`Actions`Private`chatOutputCellQ      = True &,
            Wolfram`Chatbook`Actions`Private`ensureChatOutputCell = Identity,
            Wolfram`Chatbook`Common`currentChatSettings           = <|
                "Container" -> <| "FullContent" -> ProgressIndicator[ Appearance -> "Percolate" ] |>,
                "Task"      -> None
            |> &,
            FinishDynamic = Null &
        },
        Wolfram`Chatbook`ChatbookAction[ "StopChat", #2 ];
        { Wolfram`Chatbook`Common`$chatStopRequested, Wolfram`Chatbook`$ChatEvaluationCell }
    ] & @@@ {
        { True , CellObject[ "TestOutputCell" ]  },
        { True , CellObject[ "OtherOutputCell" ] },
        { False, CellObject[ "TestOutputCell" ]  }
    },
    {
        { True , None                            },
        { False, CellObject[ "TestInputCell" ] },
        { False, CellObject[ "TestInputCell" ] }
    },
    SameTest -> SameQ,
    TestID   -> "StopChat-Output-Cell-Button-GH#1707"
]

(* The chat's time limit stops it the same way, from the chat's own evaluation: *)
VerificationTest[
    Module[ { task },
        task = SessionSubmit @ ScheduledTask[ Null, { 60 } ];
        Block[
            {
                Wolfram`Chatbook`$ChatEvaluationCell        = CellObject[ "TestInputCell" ],
                Wolfram`Chatbook`Common`$chatState          = True,
                Wolfram`Chatbook`Common`$chatStopRequested  = False,
                Wolfram`Chatbook`Common`$lastCellObject     = None,
                Wolfram`Chatbook`Common`$lastTask           = task,
                Wolfram`Chatbook`Common`$nextTaskEvaluation = None
            },
            Wolfram`Chatbook`Common`waitForLastTask[ <| "TimeConstraint" -> 0.5 |> ];
            { Wolfram`Chatbook`Common`$chatStopRequested, Wolfram`Chatbook`$ChatEvaluationCell, task[ "TaskStatus" ] }
        ]
    ],
    { True, None, "Removed" },
    SameTest -> SameQ,
    TestID   -> "StopChat-Evaluating-Time-Limit"
]

(* A response that finished just before the stop isn't processed further, e.g. its tool call isn't evaluated: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$chatStopRequested  = #,
            Wolfram`Chatbook`Common`$nextTaskEvaluation = Hold[ "Evaluated" ]
        },
        { Wolfram`Chatbook`Actions`Private`runNextTask[ ], Wolfram`Chatbook`Common`$nextTaskEvaluation }
    ] & /@ { False, True },
    { { "Evaluated", None }, { Null, None } },
    SameTest -> SameQ,
    TestID   -> "RunNextTask-Stopped-GH#1707"
]

(* Each chat starts without a stop request, and a stop request ends with its chat: *)
VerificationTest[
    {
        Block[
            {
                Wolfram`Chatbook`Common`$chatStopRequested = True,
                Wolfram`Chatbook`Common`$lastTask,
                Wolfram`Chatbook`Common`$lastCellObject
            },
            Wolfram`Chatbook`Common`withChatState @ Wolfram`Chatbook`Common`$chatStopRequested
        ],
        Block[
            {
                Wolfram`Chatbook`Common`$chatStopRequested = False,
                Wolfram`Chatbook`Common`$lastTask,
                Wolfram`Chatbook`Common`$lastCellObject
            },
            Wolfram`Chatbook`Common`withChatState[ Wolfram`Chatbook`Common`$chatStopRequested = True ];
            Wolfram`Chatbook`Common`$chatStopRequested
        ]
    },
    { False, False },
    SameTest -> SameQ,
    TestID   -> "WithChatState-Stop-Request"
]

(* A chat that's evaluated inside an auto-assist chat's handler (e.g. by a tool) has its own stop request: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$autoAssistHandler = True,
            Wolfram`Chatbook`Common`$lastTask,
            Wolfram`Chatbook`Common`$lastCellObject
        },
        Wolfram`Chatbook`Common`withChatState[
            Wolfram`Chatbook`Common`$chatStopRequested = True;
            Wolfram`Chatbook`Common`chatStopRequestedQ[ ]
        ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "WithChatState-AutoAssist-Handler"
]

(* In chat notebooks, the stop button already shows while the chat is queued. If the chat is stopped before it sets
   $ChatEvaluationCell, its stop button doesn't show again: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`$ChatEvaluationCell                       = CellObject[ "TestInputCell" ],
            Wolfram`Chatbook`Common`$lastTask,
            Wolfram`Chatbook`Common`$lastCellObject,
            Wolfram`Chatbook`ChatState`Private`withEvaluationCell     = Function[ Null, #2, HoldAll ],
            Wolfram`Chatbook`ChatState`Private`withAppNameCaller      = Function[ Null, #2, HoldAll ],
            AbsoluteCurrentChatSettings                                = Null &
        },
        Wolfram`Chatbook`Common`withChatState[
            Wolfram`Chatbook`Common`$chatStopRequested = #;
            Wolfram`Chatbook`ChatState`Private`withChatEvaluationCell[
                CellObject[ "TestInputCell" ],
                Wolfram`Chatbook`$ChatEvaluationCell
            ]
        ]
    ] & /@ { False, True },
    { CellObject[ "TestInputCell" ], None },
    SameTest -> SameQ,
    TestID   -> "WithChatEvaluationCell-Stopped-Before"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Not Evaluating*)

(* Without a chat evaluating (e.g. after SendChat, which doesn't wait for the response), the last output cell is
   stopped as before: *)
VerificationTest[
    stopChat[ False, CellObject[ "TestOutputCell" ] ],
    <| "StopRequested" -> False, "ChatEvaluationCell" -> None, "Stopped" -> { CellObject[ "TestOutputCell" ] } |>,
    SameTest -> SameQ,
    TestID   -> "StopChat-Not-Evaluating"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Other Chats*)

(* An auto-assist chat's handlers run after its own evaluation has ended, possibly while another chat that was stopped
   is still evaluating. Returns whether the "TaskFinished" handler of a chat (auto-assist or not) sees a stop request in
   that case. The handler of a chat that isn't auto-assist runs in its own chat's evaluation, so it does: *)
VerificationTest[
    handlerStopRequest[ autoAssist_ ] := Module[ { container, handlers, seen },
        container = <| "FullContent" -> "", "DynamicContent" -> "" |>;
        seen      = "NotRun";
        Block[
            {
                Wolfram`Chatbook`Common`$lastTask,
                Wolfram`Chatbook`Common`$lastCellObject,
                Wolfram`Chatbook`Common`getHandlerFunctions            = <| |> &,
                Wolfram`Chatbook`Common`dynamicSplitQ                  = False &,
                Wolfram`Chatbook`Common`logUsage                       = Null &,
                Wolfram`Chatbook`SendChat`Private`feTaskQ              = True &,
                Wolfram`Chatbook`SendChat`Private`getToolFormatter     = None &,
                Wolfram`Chatbook`SendChat`Private`makeStopTokens       = None &,
                Wolfram`Chatbook`SendChat`Private`emulatedStopTokens   = None &,
                Wolfram`Chatbook`SendChat`Private`checkFinishReason    = Null &,
                Wolfram`Chatbook`SendChat`Private`trimStopTokens       = Null &,
                Wolfram`Chatbook`SendChat`Private`checkResponse        = (seen = Wolfram`Chatbook`Common`chatStopRequestedQ[ ]) &
            },
            handlers = Wolfram`Chatbook`Common`withChatState @ Block[
                { Wolfram`Chatbook`$AutomaticAssistance = autoAssist },
                Wolfram`Chatbook`SendChat`Private`chatHandlers[ container, CellObject[ "TestOutputCell" ], <| |> ]
            ];
            Block[ { Wolfram`Chatbook`Common`$chatState = True, Wolfram`Chatbook`Common`$chatStopRequested = True },
                handlers[ "TaskFinished" ][ <| "StatusCode" -> 200 |> ]
            ];
            seen
        ]
    ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "Handler-Definitions"
]

VerificationTest[
    handlerStopRequest /@ { True, False },
    { False, True },
    SameTest -> SameQ,
    TestID   -> "AutoAssist-Handler-Other-Chat-Stopped"
]

(* When an emulated stop token is found in a response chunk, the "BodyChunkReceived" handler processes the response
   itself, like the "TaskFinished" handler would. Returns whether it sees a stop request in the same case as above, and
   the status of the response's task (removed at the emulated stop token, so the handler did process the response): *)
VerificationTest[
    emulatedStopHandlerStopRequest[ autoAssist_ ] := Module[ { container, handlers, seen, task },
        container = <| "FullContent" -> "", "DynamicContent" -> "" |>;
        seen      = "NotRun";
        task      = SessionSubmit @ ScheduledTask[ Null, { 60 } ];
        Block[
            {
                Wolfram`Chatbook`Common`$lastTask,
                Wolfram`Chatbook`Common`$lastCellObject,
                Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered  = False,
                Wolfram`Chatbook`Common`getHandlerFunctions               = <| |> &,
                Wolfram`Chatbook`Common`dynamicSplitQ                     = False &,
                Wolfram`Chatbook`Common`logUsage                          = Null &,
                Wolfram`Chatbook`SendChat`Private`feTaskQ                 = True &,
                Wolfram`Chatbook`SendChat`Private`getToolFormatter        = None &,
                Wolfram`Chatbook`SendChat`Private`makeStopTokens          = None &,
                Wolfram`Chatbook`SendChat`Private`emulatedStopTokens      = { "STOP" } &,
                Wolfram`Chatbook`SendChat`Private`addExtractedBodyChunks  = Identity,
                Wolfram`Chatbook`SendChat`Private`checkFinishReason       = Null &,
                Wolfram`Chatbook`SendChat`Private`writeChunk              = Null &,
                Wolfram`Chatbook`SendChat`Private`applyEmulatedStopTokens = Function[
                    Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered = True;
                    #3
                ],
                Wolfram`Chatbook`SendChat`Private`checkResponse = (seen = Wolfram`Chatbook`Common`chatStopRequestedQ[ ]) &
            },
            handlers = Wolfram`Chatbook`Common`withChatState @ Block[
                { Wolfram`Chatbook`$AutomaticAssistance = autoAssist },
                Wolfram`Chatbook`SendChat`Private`chatHandlers[ container, CellObject[ "TestOutputCell" ], <| |> ]
            ];
            Block[
                {
                    Wolfram`Chatbook`Common`$chatState         = True,
                    Wolfram`Chatbook`Common`$chatStopRequested = True,
                    Wolfram`Chatbook`Common`$lastTask          = task
                },
                handlers[ "BodyChunkReceived" ][ <| "BodyChunk" -> "STOP" |> ]
            ];
            { seen, task[ "TaskStatus" ] }
        ]
    ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "EmulatedStop-Handler-Definitions"
]

VerificationTest[
    emulatedStopHandlerStopRequest /@ { True, False },
    { { False, "Removed" }, { True, "Removed" } },
    SameTest -> SameQ,
    TestID   -> "AutoAssist-EmulatedStop-Handler-Other-Chat-Stopped"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*sendChat*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Definitions*)
VerificationTest[
    (* Runs sendChat with the front end and LLM calls stubbed out, and simulates StopChat running during the given
       step by setting $chatStopRequested there ("Start" sets it before sendChat runs). `submitted` is what chatSubmit
       returns. Returns the steps that ran, the cells that sendChat stopped, the tasks it removed, the output cell
       settings it wrote, and $lastTask afterwards: *)
    sendChatStoppedAt[ step_, submitted_: "TestTask" ] := Module[ { log, evalCell, outputCell, messages, stopAt },
        log        = Internal`Bag[ ];
        evalCell   = CellObject[ "TestEvaluationCell" ];
        outputCell = CellObject[ "TestOutputCell" ];
        messages   = {
            <| "Role" -> "System", "Content" -> "System prompt" |>,
            <| "Role" -> "User"  , "Content" -> "Hello"         |>
        };
        stopAt = Function[
            Internal`StuffBag[ log, # ];
            If[ # === step, Wolfram`Chatbook`Common`$chatStopRequested = True ]
        ];
        Block[
            {
                CurrentValue                                                = Inherited &,
                Wolfram`Chatbook`$AutomaticAssistance                       = False,
                Wolfram`Chatbook`$WorkspaceChat                             = True,
                Wolfram`Chatbook`Common`$cloudNotebooks                     = False,
                Wolfram`Chatbook`Common`$useLLMServices                     = True,
                Wolfram`Chatbook`Common`$chatStopRequested                  = step === "Start",
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
                Wolfram`Chatbook`SendChat`Private`prepareMessagesForLLM     = #2 &,
                Wolfram`Chatbook`SendChat`Private`createNewChatOutput       = (stopAt[ "CreateOutput" ]; outputCell) &,
                Wolfram`Chatbook`SendChat`Private`writeErrorCell            = (Internal`StuffBag[ log, "Error" ]; Null) &,
                Wolfram`Chatbook`Common`constructMessages = Function[
                    stopAt[ "ConstructMessages" ];
                    Sow[ <| "Messages" -> messages |>, Wolfram`Chatbook`Common`$chatDataTag ];
                    messages
                ],
                Wolfram`Chatbook`Common`applyHandlerFunction = Function[
                    If[ #2 === "ChatPre", stopAt[ "ChatPre" ] ]
                ],
                Wolfram`Chatbook`SendChat`Private`chatSubmit = Function[
                    stopAt[ "ChatSubmit" ];
                    submitted
                ],
                Wolfram`Chatbook`Settings`Private`setCurrentChatSettings = Function[
                    Internal`StuffBag[ log, { "Write", #2 } ]
                ],
                Wolfram`Chatbook`Actions`StopChat  = Function[ Internal`StuffBag[ log, { "StopChat", # } ] ],
                Wolfram`Chatbook`Common`removeTask = Function[ Internal`StuffBag[ log, { "RemoveTask", # } ] ]
            },
            <|
                "Result" -> Wolfram`Chatbook`Common`sendChat[
                    evalCell,
                    NotebookObject[ "TestNotebook" ],
                    None,
                    <|
                        "ForceSynchronous"     -> False,
                        "IncludeHistory"       -> False,
                        "ProcessingFunctions"  -> <| "ChatSubmit" -> Automatic |>,
                        "ResolvedAutoSettings" -> True
                    |>
                ],
                "Events"   -> Internal`BagPart[ log, All ],
                "LastTask" -> Wolfram`Chatbook`Common`$lastTask
            |>
        ]
    ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "SendChat-Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Stopped Before Submitting*)

(* Without a stop, the request is submitted and the output cell settings are written: *)
VerificationTest[
    sendChatStoppedAt[ None ],
    <|
        "Result" -> "TestTask",
        "Events" -> {
            "CreateOutput",
            "ConstructMessages",
            "ChatPre",
            "ChatSubmit",
            { "Write", "Data" },
            { "Write", "CellObject" },
            { "Write", "Task" }
        },
        "LastTask" -> "TestTask"
    |>,
    SameTest -> SameQ,
    TestID   -> "SendChat-Not-Stopped"
]

(* Stopped before the output cell is created, so nothing is written: *)
VerificationTest[
    sendChatStoppedAt[ "Start" ],
    <| "Result" -> Null, "Events" -> { }, "LastTask" -> None |>,
    SameTest -> SameQ,
    TestID   -> "SendChat-Stopped-Before-Output-Cell-GH#1708"
]

(* Stopped while the output cell was being created, before StopChat could find it in $lastCellObject: *)
VerificationTest[
    sendChatStoppedAt[ "CreateOutput" ],
    <|
        "Result"   -> Null,
        "Events"   -> { "CreateOutput", { "StopChat", CellObject[ "TestOutputCell" ] } },
        "LastTask" -> None
    |>,
    SameTest -> SameQ,
    TestID   -> "SendChat-Stopped-Creating-Output-Cell-GH#1708"
]

(* Stopped while the messages were constructed (e.g. waiting for the documentation search). StopChat has already
   removed the output cell, so the chat just ends without calling "ChatPre" or submitting the request: *)
VerificationTest[
    sendChatStoppedAt[ "ConstructMessages" ],
    <| "Result" -> Null, "Events" -> { "CreateOutput", "ConstructMessages" }, "LastTask" -> None |>,
    SameTest -> SameQ,
    TestID   -> "SendChat-Stopped-Constructing-Messages-GH#1707"
]

VerificationTest[
    sendChatStoppedAt[ "ChatPre" ],
    <| "Result" -> Null, "Events" -> { "CreateOutput", "ConstructMessages", "ChatPre" }, "LastTask" -> None |>,
    SameTest -> SameQ,
    TestID   -> "SendChat-Stopped-ChatPre-GH#1707"
]

(* Stopped while the request was submitted, before StopChat could find the task in $lastTask: *)
VerificationTest[
    sendChatStoppedAt[ "ChatSubmit" ],
    <|
        "Result"   -> Null,
        "Events"   -> { "CreateOutput", "ConstructMessages", "ChatPre", "ChatSubmit", { "RemoveTask", "TestTask" } },
        "LastTask" -> None
    |>,
    SameTest -> SameQ,
    TestID   -> "SendChat-Stopped-Submitting-GH#1707"
]

(* The same, but submitting the request failed. The chat ends without a task, since the failure isn't one: *)
VerificationTest[
    sendChatStoppedAt[ "ChatSubmit", Failure[ "TestFailure", <| |> ] ],
    <|
        "Result" -> Null,
        "Events" -> {
            "CreateOutput",
            "ConstructMessages",
            "ChatPre",
            "ChatSubmit",
            { "RemoveTask", Failure[ "TestFailure", <| |> ] }
        },
        "LastTask" -> None
    |>,
    SameTest -> SameQ,
    TestID   -> "SendChat-Stopped-Submitting-Failed-GH#1707"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Stopped While Waiting*)

(* The chat waits for a slow request while constructing messages (e.g. the documentation search), and the stop button
   is pressed. A scheduled task stands in for the stop button's preemptive evaluation: both run during the wait and
   see the chat's state. The wait ends early, its request is removed, and the chat's request is never submitted: *)
VerificationTest[
    Module[ { log, evalCell, outputCell, messages, slow, time, result },
        log        = Internal`Bag[ ];
        evalCell   = CellObject[ "TestEvaluationCell" ];
        outputCell = CellObject[ "TestOutputCell" ];
        messages   = {
            <| "Role" -> "System", "Content" -> "System prompt" |>,
            <| "Role" -> "User"  , "Content" -> "Hello"         |>
        };
        slow = SessionSubmit @ ScheduledTask[ Null, { 60 } ];
        Block[
            {
                CurrentValue                                                = Inherited &,
                Wolfram`Chatbook`$AutomaticAssistance                       = False,
                Wolfram`Chatbook`$WorkspaceChat                             = True,
                Wolfram`Chatbook`$ChatEvaluationCell                        = evalCell,
                Wolfram`Chatbook`Common`$chatState                          = True,
                Wolfram`Chatbook`Common`$chatStopRequested                  = False,
                Wolfram`Chatbook`Common`$lastTask                           = None,
                Wolfram`Chatbook`Common`$lastCellObject                     = None,
                Wolfram`Chatbook`Common`$cloudNotebooks                     = False,
                Wolfram`Chatbook`Common`$useLLMServices                     = True,
                Wolfram`Chatbook`Common`$progressContainer                  = None,
                Wolfram`Chatbook`Common`resolveInlineReferences             = Null &,
                Wolfram`Chatbook`Common`withApproximateProgress             = Identity &,
                Wolfram`Chatbook`Common`setProgressDisplay                  = Null &,
                Wolfram`Chatbook`Common`addHandlerArguments                 = Null &,
                Wolfram`Chatbook`Common`applyHandlerFunction                = Null &,
                Wolfram`Chatbook`Common`parentCell                          = None &,
                Wolfram`Chatbook`SendChat`Private`selectChatCells           = { evalCell } &,
                Wolfram`Chatbook`SendChat`Private`chatHistoryCellsAndTarget = { { evalCell }, None } &,
                Wolfram`Chatbook`SendChat`Private`activeAIAssistantCell     = Cell[ "", "ChatOutput" ] &,
                Wolfram`Chatbook`SendChat`Private`prepareMessagesForLLM     = #2 &,
                Wolfram`Chatbook`SendChat`Private`createNewChatOutput       = outputCell &,
                Wolfram`Chatbook`Actions`Private`chatOutputCellQ            = MatchQ[ outputCell ],
                Wolfram`Chatbook`Common`constructMessages = Function[
                    (* The stop button is pressed halfway through the wait: *)
                    SessionSubmit @ ScheduledTask[ Wolfram`Chatbook`ChatbookAction[ "StopChat" ], { 0.5 } ];
                    Wolfram`Chatbook`Common`taskWaitYield[ slow, TimeConstraint -> 30 ];
                    Sow[ <| "Messages" -> messages |>, Wolfram`Chatbook`Common`$chatDataTag ];
                    messages
                ],
                Wolfram`Chatbook`SendChat`Private`chatSubmit = Function[
                    Internal`StuffBag[ log, "ChatSubmit" ];
                    "TestTask"
                ],
                (* Where StopChat removes the output cell: *)
                Wolfram`Chatbook`Actions`Private`ensureChatOutputCell = (Internal`StuffBag[ log, { "Stopped", # } ]; None) &
            },
            { time, result } = AbsoluteTiming @ Wolfram`Chatbook`Common`sendChat[
                evalCell,
                NotebookObject[ "TestNotebook" ],
                None,
                <|
                    "ForceSynchronous"     -> False,
                    "IncludeHistory"       -> False,
                    "ProcessingFunctions"  -> <| "ChatSubmit" -> Automatic |>,
                    "ResolvedAutoSettings" -> True
                |>
            ];
            <|
                "Result"             -> result,
                "Events"             -> Internal`BagPart[ log, All ],
                "WaitEndedEarly"     -> time < 10,
                "WaitedTask"         -> slow[ "TaskStatus" ],
                "ChatEvaluationCell" -> Wolfram`Chatbook`$ChatEvaluationCell
            |>
        ]
    ],
    <|
        "Result"             -> Null,
        "Events"             -> { { "Stopped", CellObject[ "TestOutputCell" ] } },
        "WaitEndedEarly"     -> True,
        "WaitedTask"         -> "Removed",
        "ChatEvaluationCell" -> None
    |>,
    SameTest -> SameQ,
    TestID   -> "SendChat-Stopped-While-Waiting-GH#1707"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*toolEvaluation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Definitions*)
VerificationTest[
    (* Runs toolEvaluation for a response with a tool call, with the tool, the front end and the LLM calls stubbed out,
       and simulates StopChat running during the given step. "ToolRequest" is the "ToolRequestReceived" handler, which
       runs just before the tool is evaluated, and "EvaluateTool" is the tool evaluation. `submitted` is what
       chatSubmit returns. Returns the steps that ran, the tasks that were removed, the output cell settings that were
       written, and $lastTask afterwards: *)
    (* Using LLMToolRequest the first time loads its definitions, which would also replace the GenerateLLMToolResponse
       stub, so that happens here first: *)
    $testToolRequest = LLMToolRequest[ "TestTool", <| |> ];
    toolEvaluationStoppedAt[ step_, submitted_: "TestTask" ] := Module[ { log, stopAt, container },
        log       = Internal`Bag[ ];
        container = <| "FullContent" -> "Calling a tool", "DynamicContent" -> "Calling a tool" |>;
        stopAt    = Function[
            Internal`StuffBag[ log, # ];
            If[ # === step, Wolfram`Chatbook`Common`$chatStopRequested = True ]
        ];
        Block[
            {
                Wolfram`Chatbook`Common`$chatStopRequested                = False,
                Wolfram`Chatbook`Common`$lastTask                         = None,
                Wolfram`Chatbook`Common`$useLLMServices                   = True,
                Wolfram`Chatbook`Common`$toolEvaluationResults            = <| |>,
                Wolfram`Chatbook`Common`addHandlerArguments               = Null &,
                Wolfram`Chatbook`Common`removeBasePrompt                  = #1 &,
                Wolfram`Chatbook`Common`removeToolPreferencePrompt        = Identity,
                Wolfram`Chatbook`Common`allowedMultimodalRoles            = All &,
                Wolfram`Chatbook`Common`expandMultimodalString            = Identity,
                Wolfram`Chatbook`Common`toolRequestParser                 = { None, $testToolRequest } &,
                Wolfram`Chatbook`SendChat`Private`checkForBadRetry        = #2 &,
                Wolfram`Chatbook`SendChat`Private`insertToolID            = #1 &,
                Wolfram`Chatbook`SendChat`Private`toolResponseString      = "Tool output" &,
                Wolfram`Chatbook`SendChat`Private`appendToolCallEndToken  = #2 &,
                Wolfram`Chatbook`SendChat`Private`checkMarkdownOutput     = Identity,
                Wolfram`Chatbook`SendChat`Private`makeToolResponseMessage = <| "Role" -> "User", "Content" -> #2 |> &,
                Wolfram`Chatbook`SendChat`Private`prepareMessagesForLLM   = #2 &,
                Wolfram`Chatbook`SendChat`Private`appendToolResult        = Null &,
                Wolfram`Chatbook`SendChat`Private`sendToolResponseQ       = True &,
                Wolfram`Chatbook`SendChat`Private`writeErrorCell          = (Internal`StuffBag[ log, "Error" ]; Null) &,
                Wolfram`Chatbook`Common`applyHandlerFunction = Function[
                    If[ #2 === "ToolRequestReceived", stopAt[ "ToolRequest" ] ]
                ],
                GenerateLLMToolResponse = Function[
                    stopAt[ "EvaluateTool" ];
                    Failure[ "TestToolResult", <| |> ]
                ],
                Wolfram`Chatbook`Common`constructMessages    = Function[ stopAt[ "ConstructMessages" ]; #2 ],
                Wolfram`Chatbook`SendChat`Private`chatSubmit = Function[ stopAt[ "ChatSubmit" ]; submitted ],
                Wolfram`Chatbook`Common`setCurrentValue      = Function[ Internal`StuffBag[ log, { "Write", Last @ #2 } ] ],
                Wolfram`Chatbook`Common`removeTask           = Function[ Internal`StuffBag[ log, { "RemoveTask", # } ] ]
            },
            <|
                "Result" -> Wolfram`Chatbook`SendChat`Private`toolEvaluation[
                    <| "Data" -> <| "Messages" -> { <| "Role" -> "User", "Content" -> "Hello" |> } |> |>,
                    Unevaluated @ container,
                    CellObject[ "TestOutputCell" ],
                    <| |>
                ],
                "Events"   -> Internal`BagPart[ log, All ],
                "LastTask" -> Wolfram`Chatbook`Common`$lastTask
            |>
        ]
    ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "ToolEvaluation-Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Stopped Before Submitting*)

(* Without a stop, the tool is evaluated and the tool response is sent: *)
VerificationTest[
    toolEvaluationStoppedAt[ None ],
    <|
        "Result" -> "TestTask",
        "Events" -> {
            "ToolRequest",
            "EvaluateTool",
            "ConstructMessages",
            "ChatSubmit",
            { "Write", "CellObject" },
            { "Write", "Task" }
        },
        "LastTask" -> "TestTask"
    |>,
    SameTest -> SameQ,
    TestID   -> "ToolEvaluation-Not-Stopped"
]

(* StopChat has already written the output cell, so the chat ends without evaluating the tool: *)
VerificationTest[
    toolEvaluationStoppedAt[ "ToolRequest" ],
    <| "Result" -> Null, "Events" -> { "ToolRequest" }, "LastTask" -> None |>,
    SameTest -> SameQ,
    TestID   -> "ToolEvaluation-Stopped-Before-Tool-GH#1707"
]

(* ... or without sending the tool response: *)
VerificationTest[
    toolEvaluationStoppedAt[ "EvaluateTool" ],
    <| "Result" -> Null, "Events" -> { "ToolRequest", "EvaluateTool" }, "LastTask" -> None |>,
    SameTest -> SameQ,
    TestID   -> "ToolEvaluation-Stopped-Evaluating-Tool-GH#1707"
]

VerificationTest[
    toolEvaluationStoppedAt[ "ConstructMessages" ],
    <| "Result" -> Null, "Events" -> { "ToolRequest", "EvaluateTool", "ConstructMessages" }, "LastTask" -> None |>,
    SameTest -> SameQ,
    TestID   -> "ToolEvaluation-Stopped-Constructing-Messages-GH#1707"
]

VerificationTest[
    toolEvaluationStoppedAt[ "ChatSubmit" ],
    <|
        "Result"   -> Null,
        "Events"   -> { "ToolRequest", "EvaluateTool", "ConstructMessages", "ChatSubmit", { "RemoveTask", "TestTask" } },
        "LastTask" -> None
    |>,
    SameTest -> SameQ,
    TestID   -> "ToolEvaluation-Stopped-Submitting-GH#1707"
]

VerificationTest[
    toolEvaluationStoppedAt[ "ChatSubmit", Failure[ "TestFailure", <| |> ] ],
    <|
        "Result" -> Null,
        "Events" -> {
            "ToolRequest",
            "EvaluateTool",
            "ConstructMessages",
            "ChatSubmit",
            { "RemoveTask", Failure[ "TestFailure", <| |> ] }
        },
        "LastTask" -> None
    |>,
    SameTest -> SameQ,
    TestID   -> "ToolEvaluation-Stopped-Submitting-Failed-GH#1707"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompt Generators*)

(* The prompt generators after the one the chat was stopped in don't run: *)
VerificationTest[
    Module[ { generators, ran },
        generators = { LLMPromptGenerator[ "First" ], LLMPromptGenerator[ "Second" ] };
        ran = { };
        Block[
            {
                Wolfram`Chatbook`Common`$chatStopRequested = False,
                Wolfram`Chatbook`PromptGenerators`DefaultPromptGenerators`Private`applyPromptGenerator = Function[
                    AppendTo[ ran, First @ FirstPosition[ generators, #1, { 0 }, { 1 } ] ];
                    Wolfram`Chatbook`Common`$chatStopRequested = True;
                    "Prompt"
                ]
            },
            {
                Wolfram`Chatbook`Common`applyPromptGenerators[
                    <| |>,
                    generators,
                    { <| "Role" -> "User", "Content" -> "Hello" |> }
                ],
                ran
            }
        ]
    ],
    { { "Prompt" }, { 1 } },
    SameTest -> SameQ,
    TestID   -> "ApplyPromptGenerators-Stopped-Chat-GH#1707"
]

(* A request with a time limit (e.g. the documentation search filter, or its retry) isn't submitted after the chat is
   stopped, since the wait for it would end right away. A request without a time limit is: *)
VerificationTest[
    Module[ { submitted },
        submitted = 0;
        Block[
            {
                Wolfram`Chatbook`Common`$chatStopRequested  = True,
                Wolfram`Chatbook`Common`llmSynthesizeSubmit = Function[
                    submitted++;
                    SessionSubmit @ ScheduledTask[ #3[ "Response", <| |> ], { 0.1 } ]
                ]
            },
            {
                Wolfram`Chatbook`Common`llmSynthesize[ "Hi", <| |>, TimeConstraint -> 30, "ReturnFailures" -> True ],
                submitted,
                Wolfram`Chatbook`Common`llmSynthesize[ "Hi", <| |> ],
                submitted
            }
        ]
    ],
    { Failure[ "TimedOut", _ ], 0, "Response", 1 },
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesize-Stopped-Chat-GH#1707"
]

(* Wolfram|Alpha results aren't cached if the chat was stopped, since the wait for them ended early: *)
VerificationTest[
    Module[ { submitted, query },
        submitted = 0;
        query     = "StopChat test query " <> CreateUUID[ ];
        Block[
            {
                Wolfram`Chatbook`Common`$chatStopRequested = True,
                Wolfram`Chatbook`PromptGenerators`RelatedWolframAlphaResults`Private`$cacheResults = True,
                Wolfram`Chatbook`PromptGenerators`RelatedWolframAlphaResults`Private`submitXMLRequest = Function[
                    Null,
                    (submitted++; SessionSubmit @ ScheduledTask[ Null, { 60 } ]) &,
                    HoldFirst
                ]
            },
            Do[
                Wolfram`Chatbook`PromptGenerators`RelatedWolframAlphaResults`Private`getWolframAlphaAPIContent0 @ { query },
                2
            ]
        ];
        submitted
    ],
    2,
    SameTest -> SameQ,
    TestID   -> "WolframAlphaResults-Stopped-Chat-Not-Cached"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*taskWaitYield*)

(* A wait with a time limit ends early when the chat is stopped, and the task is removed: *)
VerificationTest[
    Module[ { task, time },
        task = SessionSubmit @ ScheduledTask[ Null, { 60 } ];
        time = First @ AbsoluteTiming @ Block[ { Wolfram`Chatbook`Common`$chatStopRequested = True },
            Wolfram`Chatbook`Common`taskWaitYield[ task, TimeConstraint -> 30 ]
        ];
        { time < 5, task[ "TaskStatus" ] }
    ],
    { True, "Removed" },
    SameTest -> SameQ,
    TestID   -> "TaskWaitYield-Stopped-Chat-GH#1707"
]

(* Callers that wait without a time limit may need the result, so their waits don't end early: *)
VerificationTest[
    Module[ { task, result },
        task = SessionSubmit @ ScheduledTask[ Null, { 60 } ];
        result = Block[ { Wolfram`Chatbook`Common`$chatStopRequested = True },
            TimeConstrained[ Wolfram`Chatbook`Common`taskWaitYield @ task; "Returned", 1, "TimedOut" ]
        ];
        { result, task[ "TaskStatus" ] }
    ],
    { "TimedOut", "Removed" },
    SameTest -> SameQ,
    TestID   -> "TaskWaitYield-Stopped-Chat-Unlimited"
]

(* A wait in an auto-assist chat's handler (e.g. the documentation search in a tool call) doesn't end early because
   another chat was stopped: *)
VerificationTest[
    Module[ { task, time },
        task = SessionSubmit @ ScheduledTask[ Null, { 1 } ];
        time = First @ AbsoluteTiming @ Block[
            {
                Wolfram`Chatbook`Common`$chatStopRequested = True,
                Wolfram`Chatbook`Common`$autoAssistHandler = True
            },
            Wolfram`Chatbook`Common`taskWaitYield[ task, TimeConstraint -> 30 ]
        ];
        { time > 0.5, time < 10 }
    ],
    { True, True },
    SameTest -> SameQ,
    TestID   -> "TaskWaitYield-AutoAssist-Handler"
]

(* The task is also removed if an outer time limit interrupts the wait (it used to keep running, and its handler
   fired later): *)
VerificationTest[
    Module[ { task, result },
        task = SessionSubmit @ ScheduledTask[ Null, { 60 } ];
        result = TimeConstrained[
            Wolfram`Chatbook`Common`taskWaitYield[ task, TimeConstraint -> 30 ];
            "Returned",
            1,
            "TimedOut"
        ];
        { result, task[ "TaskStatus" ] }
    ],
    { "TimedOut", "Removed" },
    SameTest -> SameQ,
    TestID   -> "TaskWaitYield-Outer-TimeConstrained-GH#1707"
]

(* Same for an abort: *)
VerificationTest[
    Module[ { task, result },
        task = SessionSubmit @ ScheduledTask[ Null, { 60 } ];
        result = CheckAbort[
            Block[ { Pause = Abort[ ] & },
                Wolfram`Chatbook`Common`taskWaitYield[ task, TimeConstraint -> 30 ]
            ],
            "Aborted"
        ];
        { result, task[ "TaskStatus" ] }
    ],
    { "Aborted", "Removed" },
    SameTest -> SameQ,
    TestID   -> "TaskWaitYield-Abort-GH#1707"
]

(* Waiting for several tasks, an interruption also removes the tasks that weren't waited for yet: *)
VerificationTest[
    Module[ { tasks, result },
        tasks = Table[ SessionSubmit @ ScheduledTask[ Null, { 60 } ], 2 ];
        result = TimeConstrained[
            Wolfram`Chatbook`Common`taskWaitYield[ tasks, TimeConstraint -> 30 ];
            "Returned",
            1,
            "TimedOut"
        ];
        { result, #[ "TaskStatus" ] & /@ tasks }
    ],
    { "TimedOut", { "Removed", "Removed" } },
    SameTest -> SameQ,
    TestID   -> "TaskWaitYield-List-Outer-TimeConstrained-GH#1707"
]

(* The same for tasks in a nested list: *)
VerificationTest[
    Module[ { tasks, result },
        tasks = Table[ SessionSubmit @ ScheduledTask[ Null, { 60 } ], 3 ];
        result = TimeConstrained[
            Wolfram`Chatbook`Common`taskWaitYield[ { First @ tasks, Rest @ tasks }, TimeConstraint -> 30 ];
            "Returned",
            1,
            "TimedOut"
        ];
        { result, #[ "TaskStatus" ] & /@ tasks }
    ],
    { "TimedOut", { "Removed", "Removed", "Removed" } },
    SameTest -> SameQ,
    TestID   -> "TaskWaitYield-Nested-List-Outer-TimeConstrained"
]

(* Its own time limit still removes the task: *)
VerificationTest[
    Module[ { task },
        task = SessionSubmit @ ScheduledTask[ Null, { 60 } ];
        Wolfram`Chatbook`Common`taskWaitYield[ task, TimeConstraint -> 0.5 ];
        task[ "TaskStatus" ]
    ],
    "Removed",
    SameTest -> SameQ,
    TestID   -> "TaskWaitYield-TimeConstraint"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*StopChatIn*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Definitions*)
VerificationTest[
    (* A chat in a chat notebook, the assistant window, and the sidebar of a user notebook. The window's chat cells are
       top-level cells; the sidebar's are nested in its scrolling content cell, which is in the sidebar cell: *)
    $windowNB      = NotebookObject[ "TestWindow", "TestWindow" ];
    $chatNB        = NotebookObject[ "TestChatNotebook", "TestChatNotebook" ];
    $userNB        = NotebookObject[ "TestUserNotebook", "TestUserNotebook" ];
    $sidebarCell   = CellObject[ "TestSidebarCell" ];
    $windowInput   = CellObject[ "TestWindowInput" ];
    $chatNBInput   = CellObject[ "TestChatNotebookInput" ];
    $sidebarInput  = CellObject[ "TestSidebarInput" ];

    (* Evaluates eval with the front end stubbed out, and with `running` as the chat that is evaluating: *)
    withStubbedChatCells // Attributes = { HoldRest };
    withStubbedChatCells[ running_, eval_ ] := Block[
        {
            Wolfram`Chatbook`$ChatEvaluationCell = running,
            Wolfram`Chatbook`Common`parentNotebook = Replace[ {
                $windowInput  -> $windowNB,
                $chatNBInput  -> $chatNB,
                $sidebarInput -> $userNB,
                _             -> $Failed
            } ],
            Wolfram`Chatbook`Common`parentCell = Replace[ {
                $sidebarInput                     -> CellObject[ "TestScrollingCell" ],
                CellObject[ "TestScrollingCell" ] -> $sidebarCell,
                _                                 -> $Failed
            } ]
        },
        eval
    ];

    (* Whether ChatbookAction[ "StopChatIn", container ] stopped the chat that is evaluating: *)
    stopChatInStopped[ running_, container_ ] := Module[ { stopped = False },
        withStubbedChatCells[
            running,
            Block[ { Wolfram`Chatbook`Actions`StopChat = (stopped = True) & },
                Wolfram`Chatbook`ChatbookAction[ "StopChatIn", container ]
            ]
        ];
        stopped
    ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "StopChatIn-Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chatEvaluatingInQ*)
VerificationTest[
    withStubbedChatCells[
        $chatNBInput,
        Wolfram`Chatbook`Common`chatEvaluatingInQ /@ { $windowNB, $chatNB, $sidebarCell }
    ],
    { False, True, False },
    SameTest -> SameQ,
    TestID   -> "ChatEvaluatingInQ-ChatNotebook-robustness-4"
]

VerificationTest[
    withStubbedChatCells[
        $windowInput,
        Wolfram`Chatbook`Common`chatEvaluatingInQ /@ { $windowNB, $chatNB, $sidebarCell }
    ],
    { True, False, False },
    SameTest -> SameQ,
    TestID   -> "ChatEvaluatingInQ-Window"
]

(* A sidebar chat is in its sidebar cell, but not in the window or in the user notebook's own chats: *)
VerificationTest[
    withStubbedChatCells[
        $sidebarInput,
        Wolfram`Chatbook`Common`chatEvaluatingInQ /@ { $windowNB, $chatNB, $sidebarCell, CellObject[ "OtherSidebar" ] }
    ],
    { False, False, True, False },
    SameTest -> SameQ,
    TestID   -> "ChatEvaluatingInQ-Sidebar"
]

VerificationTest[
    withStubbedChatCells[
        None,
        Wolfram`Chatbook`Common`chatEvaluatingInQ /@ { $windowNB, $sidebarCell, $Failed }
    ],
    { False, False, False },
    SameTest -> SameQ,
    TestID   -> "ChatEvaluatingInQ-NoChat"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Scoped Stop*)

(* The assistant window's stop button must not stop a chat in another notebook: *)
VerificationTest[
    stopChatInStopped[ $chatNBInput, $windowNB ],
    False,
    SameTest -> SameQ,
    TestID   -> "StopChatIn-OtherNotebook-robustness-4"
]

VerificationTest[
    stopChatInStopped[ $sidebarInput, $windowNB ],
    False,
    SameTest -> SameQ,
    TestID   -> "StopChatIn-Window-SidebarChat"
]

VerificationTest[
    { stopChatInStopped[ $windowInput, $windowNB ], stopChatInStopped[ $sidebarInput, $sidebarCell ] },
    { True, True },
    SameTest -> SameQ,
    TestID   -> "StopChatIn-OwnChat"
]

VerificationTest[
    stopChatInStopped[ None, $windowNB ],
    False,
    SameTest -> SameQ,
    TestID   -> "StopChatIn-NoChat"
]

(* :!CodeAnalysis::EndBlock:: *)
