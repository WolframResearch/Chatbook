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

    (* Calls the tool function as the chat's tool evaluation would, with the chat state and front end stubbed.
       Gives the tool's result and a log of the front end calls: *)
    runHandoffTool[ ] := Module[ { log = { } },
        Block[
            {
                Wolfram`Chatbook`$ChatEvaluationCell          = $chatInput,
                Wolfram`Chatbook`Common`$lastCellObject       = $chatOutput,
                Wolfram`Chatbook`Common`parentNotebook        = $userNotebook &,
                NotebookRead                                  = Function[ Cell[ "Delete the first three cells", "ChatInput" ] ],
                SessionSubmit                                 = Function[ task, AppendTo[ log, HoldComplete @ task ], HoldAll ]
            },
            { Wolfram`Chatbook`Tools`Private`notebookEditHandoff @ <| "request" -> "Delete the first three cells" |>, log }
        ]
    ];

    (* Runs the handoff (what the tool schedules) with the front end stubbed, logging each call: *)
    runStartHandoff[ ] := Module[ { log = { } },
        Block[
            {
                FrontEndExecute                                 = Function[ AppendTo[ log, { "FrontEndExecute", # } ] ],
                NotebookDelete                                  = Function[ AppendTo[ log, { "NotebookDelete", # } ] ],
                Wolfram`Chatbook`ShowNotebookAssistance         = Function[ AppendTo[ log, { "ShowNotebookAssistance", ## } ] ],
                SessionSubmit                                   = Function[ Null, AppendTo[ log, { "SessionSubmit" } ], HoldAll ]
            },
            Wolfram`Chatbook`Tools`Private`$chatbarHandoffs = <| |>;
            Wolfram`Chatbook`Tools`Private`startChatbarHandoff[ $userNotebook, { $chatInput, $chatOutput }, "Delete the first three cells" ];
            log
        ]
    ];

    (* Runs one polling step for a handoff whose sidebar is in the given state. sidebarValues[key] gives the sidebar
       cell's setting, and sidebar is the sidebarCellObject result. Gives the calls that submit the prompt: *)
    runHandoffStep[ sidebar_, sidebarValues_, started_: None ] := Module[ { log = { }, id = "test-handoff" },
        Block[
            {
                CurrentValue,
                CurrentChatSettings,
                Wolfram`Chatbook`ChatModes`Common`sidebarCellObject = sidebar &,
                Wolfram`Chatbook`Common`evaluateSidebarChat         = Function[ AppendTo[ log, { "evaluateSidebarChat", #1, #3 } ] ],
                Cells                                               = Function[ { } ],
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
                    "Input"    -> "Delete the first three cells",
                    "Started"  -> Replace[ started, None :> AbsoluteTime[ ] ]
                |>
            |>;
            Wolfram`Chatbook`Tools`Private`chatbarHandoffStep @ id;
            { log, Keys @ Wolfram`Chatbook`Tools`Private`$chatbarHandoffs }
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

(* The handoff itself is scheduled to run after the chat has stopped, with the chat's cells and the prompt from the
   chat input cell: *)
VerificationTest[
    Last @ runHandoffTool[ ],
    { HoldComplete @ ScheduledTask[
        Wolfram`Chatbook`Tools`Private`startChatbarHandoff[ nbo_, { input_, output_ }, prompt_ ] /; And[
            nbo === $userNotebook,
            input === $chatInput,
            output === $chatOutput,
            prompt === "Delete the first three cells"
        ],
        { _ }
    ] },
    SameTest -> MatchQ,
    TestID   -> "NotebookEditHandoff-SchedulesHandoff"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Handoff*)

(* The handoff flashes one blob cue over the chat's cells, removes them, and opens the sidebar with notebook editing
   switched on, in that order: *)
VerificationTest[
    runStartHandoff[ ],
    {
        { "FrontEndExecute", FrontEnd`FlashCellBlob[ { $chatInput, $chatOutput }, ___ ] },
        { "NotebookDelete", { $chatInput, $chatOutput } },
        { "ShowNotebookAssistance", $userNotebook, "Sidebar", "ChatNotebookSettings" -> KeyValuePattern[ "NotebookEditing" -> True ] },
        { "SessionSubmit" }
    },
    SameTest -> MatchQ,
    TestID   -> "ChatbarHandoff-BlobsThenDeletesThenOpensSidebar"
]

(* While the sidebar is still opening or initializing, a polling step submits nothing and keeps waiting: *)
VerificationTest[
    runHandoffStep[ $Failed, <| |> ],
    { { }, { "test-handoff" } },
    SameTest -> MatchQ,
    TestID   -> "ChatbarHandoff-WaitsForSidebar"
]

VerificationTest[
    runHandoffStep[ $sidebarCell, <| "SidebarChat" -> Inherited |> ],
    { { }, { "test-handoff" } },
    SameTest -> MatchQ,
    TestID   -> "ChatbarHandoff-WaitsForSidebarSettings"
]

(* An initialized sidebar whose editing switch is still off gets the switch set before the prompt goes in: *)
VerificationTest[
    runHandoffStep[ $sidebarCell, <| "SidebarChat" -> True, "NotebookEditing" -> False |> ],
    { {
        ___,
        { "CurrentChatSettings", $sidebarCell, "NotebookEditing", True },
        ___,
        { "evaluateSidebarChat", $userNotebook, "Delete the first three cells" },
        ___
    }, { } },
    SameTest -> MatchQ,
    TestID   -> "ChatbarHandoff-SwitchesOnEditing"
]

(* Once the sidebar is ready with editing on, the same prompt goes into the sidebar's chat and the handoff ends: *)
VerificationTest[
    runHandoffStep[ $sidebarCell, <| "SidebarChat" -> True, "NotebookEditing" -> True |> ],
    { log_ /; MatchQ[ log, { ___, { "evaluateSidebarChat", $userNotebook, "Delete the first three cells" }, ___ } ] &&
        FreeQ[ log, "CurrentChatSettings" ], { } },
    SameTest -> MatchQ,
    TestID   -> "ChatbarHandoff-SubmitsToSidebar"
]

(* A sidebar that never becomes ready ends the handoff instead of polling forever: *)
VerificationTest[
    runHandoffStep[ $Failed, <| |>, AbsoluteTime[ ] - 60 ],
    { { ___ }, { } },
    SameTest -> MatchQ,
    TestID   -> "ChatbarHandoff-TimesOut"
]

(* :!CodeAnalysis::EndBlock:: *)
