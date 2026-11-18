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
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    $userNotebook = NotebookObject[ "user-notebook", "user-notebook" ];
    $chatInput    = CellObject[ "chat-input" ];
    $chatOutput   = CellObject[ "chat-output" ];
    $sidebarCell  = CellObject[ "sidebar-cell" ];

    $handoffTool = Wolfram`Chatbook`Tools`Private`$defaultChatTools0[ "NotebookEditHandoff" ];

    $helperCell = CellObject[ "helper-cell" ];

    (* Calls the tool function as the chat's tool evaluation would, with the chat state and front end stubbed.
       Gives the tool's result, a log of the front end calls, and the recorded handoff: *)
    runHandoffTool[ ] := Module[ { log = { }, result },
        Block[
            {
                Wolfram`Chatbook`$ChatEvaluationCell          = $chatInput,
                Wolfram`Chatbook`Common`$lastCellObject       = $chatOutput,
                Wolfram`Chatbook`Common`parentNotebook        = $userNotebook &,
                NotebookRead                                  = Function[ Cell[ "Delete the first three cells", "ChatInput" ] ],
                SessionSubmit                                 = Function[ task, AppendTo[ log, HoldComplete @ task ], HoldAll ]
            },
            Wolfram`Chatbook`Tools`Private`$chatbarHandoffs = <| |>;
            result = Wolfram`Chatbook`Tools`Private`notebookEditHandoff @ <| "request" -> "Delete the first three cells" |>;
            { result, log, Values @ Wolfram`Chatbook`Tools`Private`$chatbarHandoffs }
        ]
    ];

    (* Runs one polling step for a handoff in the given phase, with the front end stubbed, logging each call.
       safeWrite is whether the front end accepts the probe write (sidebarWriteSafeQ's gate), sidebar is the
       sidebarCellObject result, and sidebarValues[key] gives the sidebar cell's settings. Gives the log, the
       remaining handoff ids, and the recorded phase: *)
    runHandoffStep[ phase_, safeWrite_, sidebar_, sidebarValues_, started_: None ] := Module[ { log = { }, id = "test-handoff" },
        Block[
            {
                CurrentValue,
                CurrentChatSettings,
                Wolfram`Chatbook`Tools`Private`$handoffSettleTicks  = 1,
                MathLink`CallFrontEnd                               = Function[ If[ TrueQ @ safeWrite, True, $Failed ] ],
                NextCell                                            = Function[ $chatOutput ],
                Developer`CellInformation                           = Function[ <| "Style" -> "ChatOutput" |> ],
                FrontEndExecute                                     = Function[ AppendTo[ log, { "FrontEndExecute", # } ] ],
                NotebookDelete                                      = Function[ AppendTo[ log, { "NotebookDelete", # } ] ],
                Wolfram`Chatbook`ShowNotebookAssistance             = Function[ AppendTo[ log, { "ShowNotebookAssistance", ## } ] ],
                Wolfram`Chatbook`ChatModes`Common`sidebarCellObject = sidebar &,
                Wolfram`Chatbook`Common`evaluateSidebarChat         = Function[ AppendTo[ log, { "evaluateSidebarChat", #1, #3 } ] ],
                Cells                                               = Function[ { $helperCell } ],
                SessionSubmit                                       = Function[ Null, AppendTo[ log, { "SessionSubmit" } ], HoldAll ],
                TaskRemove                                          = Function[ AppendTo[ log, { "TaskRemove" } ] ]
            },
            CurrentValue[ _, { ___, key_String } ] := sidebarValues @ key;
            CurrentChatSettings /: Set[ CurrentChatSettings[ args___ ], value_ ] := (
                AppendTo[ log, { "CurrentChatSettings", args, value } ];
                value
            );
            Wolfram`Chatbook`Tools`Private`$chatbarHandoffs = <|
                id -> <|
                    "Notebook" -> $userNotebook,
                    "Cells"    -> { $chatInput, $chatOutput },
                    "Input"    -> "Delete the first three cells",
                    "Phase"    -> phase,
                    "Started"  -> Replace[ started, None :> AbsoluteTime[ ] ]
                |>
            |>;
            Wolfram`Chatbook`Tools`Private`chatbarHandoffStep @ id;
            {
                log,
                Keys @ Wolfram`Chatbook`Tools`Private`$chatbarHandoffs,
                Wolfram`Chatbook`Tools`Private`$chatbarHandoffs[ id, "Phase" ]
            }
        ]
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Selection*)

(* The tool exists and is one of the default tools: *)
VerificationTest[
    $handoffTool,
    HoldPattern @ LLMTool[ KeyValuePattern @ { "CanonicalName" -> "NotebookEditHandoff", "Hidden" -> True }, ___ ],
    SameTest -> MatchQ,
    TestID   -> "NotebookEditHandoff-IsDefaultTool"
]

(* The WolframAIAssistant persona (the chatbar's) declares the tool, since a persona's explicit tool list replaces
   the defaults, so an Enabled tool that isn't in it would never be offered: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Tools`Private`$toolBox = <| |>, Wolfram`Chatbook`Tools`Private`$selectedTools = <| |> },
        MemberQ[
            Wolfram`Chatbook`Tools`Private`getToolNames @ <|
                "Tools"        -> Automatic,
                "LLMEvaluator" -> Wolfram`Chatbook`GetPersonaData[ "WolframAIAssistant" ]
            |>,
            "NotebookEditHandoff"
        ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NotebookEditHandoff-InChatbarPersonaTools"
]

(* Only a chat submitted from the chatbar gets the tool: *)
VerificationTest[
    Wolfram`Chatbook`Tools`Private`toolEnabledQ @ $handoffTool,
    False,
    SameTest -> MatchQ,
    TestID   -> "NotebookEditHandoff-DisabledByDefault"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatbarChat = True },
        Wolfram`Chatbook`Tools`Private`toolEnabledQ @ $handoffTool
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NotebookEditHandoff-EnabledForChatbar"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* The tool's result ends the chat (no tool response goes back to the model): *)
VerificationTest[
    First @ runHandoffTool[ ],
    KeyValuePattern @ { "SendToolResponse" -> False, "String" -> _String },
    SameTest -> MatchQ,
    TestID   -> "NotebookEditHandoff-TerminalResult"
]

(* The tool records the handoff (chat cells and the prompt from the chat input cell) and starts its polling task;
   the cells are only touched later, from the task, once the chat has stopped: *)
VerificationTest[
    Rest @ runHandoffTool[ ],
    {
        { HoldComplete @ ScheduledTask[ Wolfram`Chatbook`Tools`Private`chatbarHandoffStep[ _ ], 0.25 ] },
        { KeyValuePattern @ {
            "Notebook" -> $userNotebook,
            "Cells"    -> { $chatInput, $chatOutput },
            "Input"    -> "Delete the first three cells",
            "Phase"    -> "RemoveChat"
        } }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookEditHandoff-RecordsHandoff"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Handoff*)

(* Once the front end is done formatting the chat's cells, the handoff flashes one blob cue over them, removes
   them, and opens the sidebar with notebook editing switched on, in that order: *)
VerificationTest[
    runHandoffStep[ "RemoveChat", True, $Failed, <| |> ],
    { {
        { "FrontEndExecute", FrontEnd`FlashCellBlob[ { $chatInput, $chatOutput }, ___ ] },
        { "NotebookDelete", { $chatInput, $chatOutput } },
        { "ShowNotebookAssistance", $userNotebook, "Sidebar", "ChatNotebookSettings" -> KeyValuePattern[ "NotebookEditing" -> True ] }
    }, { "test-handoff" }, "Submit" },
    SameTest -> MatchQ,
    TestID   -> "ChatbarHandoff-BlobsThenDeletesThenOpensSidebar"
]

(* While the sidebar is still opening, initializing, or formatting, a polling step submits nothing and keeps
   waiting: *)
VerificationTest[
    runHandoffStep[ "Submit", True, $Failed, <| |> ],
    { { }, { "test-handoff" }, "Submit" },
    SameTest -> MatchQ,
    TestID   -> "ChatbarHandoff-WaitsForSidebar"
]

VerificationTest[
    runHandoffStep[ "Submit", True, $sidebarCell, <| "SidebarChat" -> Inherited |> ],
    { { }, { "test-handoff" }, "Submit" },
    SameTest -> MatchQ,
    TestID   -> "ChatbarHandoff-WaitsForSidebarSettings"
]

(* An initialized sidebar whose editing switch is still off gets the switch set before the prompt goes in: *)
VerificationTest[
    runHandoffStep[ "Submit", True, $sidebarCell, <| "SidebarChat" -> True, "NotebookEditing" -> False |> ],
    { {
        ___,
        { "CurrentChatSettings", $sidebarCell, "NotebookEditing", True },
        ___,
        { "evaluateSidebarChat", $userNotebook, "Delete the first three cells" },
        ___
    }, { }, _Missing },
    SameTest -> MatchQ,
    TestID   -> "ChatbarHandoff-SwitchesOnEditing"
]

(* Once the sidebar is ready with editing on, the same prompt goes into the sidebar's chat and the handoff ends: *)
VerificationTest[
    runHandoffStep[ "Submit", True, $sidebarCell, <| "SidebarChat" -> True, "NotebookEditing" -> True |> ],
    { log_ /; MatchQ[ log, { ___, { "evaluateSidebarChat", $userNotebook, "Delete the first three cells" }, ___ } ] &&
        FreeQ[ log, "CurrentChatSettings" ], { }, _Missing },
    SameTest -> MatchQ,
    TestID   -> "ChatbarHandoff-SubmitsToSidebar"
]

(* A phase acts only once its gates have held for $handoffSettleTicks consecutive ticks, and a failed gate
   resets the count: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Tools`Private`$handoffSettleTicks = 2,
            NextCell                                           = Function[ $chatOutput ],
            Developer`CellInformation                          = Function[ <| "Style" -> "ChatOutput" |> ],
            FrontEndExecute                                    = Null &,
            NotebookDelete                                     = Null &,
            Wolfram`Chatbook`ShowNotebookAssistance            = Null &
        },
        Wolfram`Chatbook`Tools`Private`$chatbarHandoffs = <|
            "settle-test" -> <|
                "Notebook" -> $userNotebook,
                "Cells"    -> { $chatInput },
                "Input"    -> "x",
                "Phase"    -> "RemoveChat",
                "Started"  -> AbsoluteTime[ ]
            |>
        |>;
        {
            Wolfram`Chatbook`Tools`Private`chatbarHandoffStep[ "settle-test" ];
            Wolfram`Chatbook`Tools`Private`$chatbarHandoffs[ "settle-test", "Phase" ],
            Wolfram`Chatbook`Tools`Private`chatbarHandoffStep[ "settle-test" ];
            Wolfram`Chatbook`Tools`Private`$chatbarHandoffs[ "settle-test", "Phase" ]
        }
    ],
    { "RemoveChat", "Submit" },
    SameTest -> MatchQ,
    TestID   -> "ChatbarHandoff-SettlesBeforeActing"
]

(* A sidebar that never becomes ready ends the handoff instead of polling forever: *)
VerificationTest[
    runHandoffStep[ "Submit", True, $Failed, <| |>, AbsoluteTime[ ] - 60 ],
    { { ___ }, { }, _Missing },
    SameTest -> MatchQ,
    TestID   -> "ChatbarHandoff-TimesOut"
]

(* :!CodeAnalysis::EndBlock:: *)
