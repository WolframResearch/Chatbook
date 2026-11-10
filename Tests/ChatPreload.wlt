(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ChatPreload.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ChatPreload.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* The experimental "PreloadNotebookAssistant" setting runs chat initialization in scheduled tasks, one step at a time
   and only while the kernel is idle. These tests run the steps directly instead of scheduling them. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    (* Evaluates `eval` as a kernel with a front end would, with three steps that are recorded in `ran`, and the delays
       of the tasks that would have been scheduled in `scheduled`: *)
    withChatPreload // Attributes = { HoldRest };
    withChatPreload[ { idle_, enabled_, initialized_ }, eval_ ] := Block[
        {
            $Notebooks = True,
            Wolfram`Chatbook`ChatModes`UI`Private`$workspaceChatInitialized = initialized,
            Wolfram`Chatbook`ChatModes`UI`Private`$chatPreloadEnabled       = enabled,
            Wolfram`Chatbook`ChatModes`UI`Private`$chatPreloadStep          = 1,
            Wolfram`Chatbook`ChatModes`UI`Private`$chatPreloadTask          = None,
            Wolfram`Chatbook`ChatModes`UI`Private`$chatPreloadSteps         = {
                "A" -> Hold @ AppendTo[ ran, "A" ],
                "B" -> Hold[ AppendTo[ ran, "B" ]; Wolfram`Chatbook`Common`throwTop @ $Failed; AppendTo[ ran, "X" ] ],
                "C" -> Hold @ AppendTo[ ran, "C" ]
            },
            Wolfram`Chatbook`ChatModes`UI`Private`kernelIdleQ             = idle &,
            Wolfram`Chatbook`ChatModes`UI`Private`scheduleChatPreloadStep = AppendTo[ scheduled, # ] &,
            ran       = { },
            scheduled = { }
        },
        eval
    ];

    preloadStep := Wolfram`Chatbook`ChatModes`UI`Private`chatPreloadStep[ ];
    $stepDelay  := Wolfram`Chatbook`ChatModes`UI`Private`$chatPreloadStepDelay;
    $retryDelay := Wolfram`Chatbook`ChatModes`UI`Private`$chatPreloadRetryDelay;
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions@@Tests/ChatPreload.wlt:27,1-58,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*chatPreloadStep*)

(* Each call runs one step and schedules the next one. A step that fails does not stop the others: *)
VerificationTest[
    withChatPreload[ { True, True, False },
        Table[ preloadStep; { ran, scheduled }, 4 ]
    ],
    {
        { { "A" }, { $stepDelay } },
        { { "A", "B" }, { $stepDelay, $stepDelay } },
        { { "A", "B", "C" }, { $stepDelay, $stepDelay } },
        { { "A", "B", "C" }, { $stepDelay, $stepDelay } }
    },
    TestID -> "Steps-OneAtATime@@Tests/ChatPreload.wlt:65,1-76,2"
]

(* Nothing is evaluated inside another evaluation: the step is postponed instead: *)
VerificationTest[
    withChatPreload[ { False, True, False },
        preloadStep;
        preloadStep;
        { ran, scheduled, Wolfram`Chatbook`ChatModes`UI`Private`$chatPreloadStep }
    ],
    { { }, { $retryDelay, $retryDelay }, 1 },
    TestID -> "Steps-PostponedWhileBusy@@Tests/ChatPreload.wlt:79,1-87,2"
]

(* Nothing runs when the setting is off, when the notebook assistant has already been initialized, or without a front
   end: *)
VerificationTest[
    {
        withChatPreload[ { True, False, False }, preloadStep; { ran, scheduled } ],
        withChatPreload[ { True, True, True }, preloadStep; { ran, scheduled } ],
        withChatPreload[ { True, True, False }, Block[ { $Notebooks = False }, preloadStep; { ran, scheduled } ] ]
    },
    { { { }, { } }, { { }, { } }, { { }, { } } },
    TestID -> "Steps-NotEnabled@@Tests/ChatPreload.wlt:91,1-99,2"
]

(* The setting is read once, by the first step that runs while the kernel is idle: *)
VerificationTest[
    Module[ { reads = 0 },
        Internal`InheritedBlock[ { CurrentChatSettings },
            Unprotect @ CurrentChatSettings;
            CurrentChatSettings[ $FrontEnd, "PreloadNotebookAssistant" ] := (reads++; True);
            withChatPreload[ { True, None, False },
                Table[ preloadStep; { reads, ran, Wolfram`Chatbook`ChatModes`UI`Private`$chatPreloadEnabled }, 2 ]
            ]
        ]
    ],
    { { 1, { }, True }, { 1, { "A" }, True } },
    TestID -> "Steps-ReadsSettingOnce@@Tests/ChatPreload.wlt:102,1-114,2"
]

(* The setting is off by default: *)
VerificationTest[
    Lookup[ Wolfram`Chatbook`Common`$defaultChatSettings, "PreloadNotebookAssistant", False ],
    False,
    TestID -> "Setting-OffByDefault@@Tests/ChatPreload.wlt:117,1-121,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*kernelIdleQ*)

(* A scheduled task that fires during an evaluation (here, the test) must not be considered idle: *)
VerificationTest[
    Module[ { result = None },
        SessionSubmit @ ScheduledTask[ result = Wolfram`Chatbook`ChatModes`UI`Private`kernelIdleQ[ ], { 0.1 } ];
        TimeConstrained[ While[ result === None, Pause[ 0.05 ] ], 10 ];
        { result, Wolfram`Chatbook`ChatModes`UI`Private`kernelIdleQ[ ] }
    ],
    { False, False },
    TestID -> "KernelIdleQ-InsideEvaluation@@Tests/ChatPreload.wlt:128,1-136,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*scheduleChatPreload*)

(* Loading Chatbook only schedules a task, and nothing once chat has been initialized: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`ChatModes`UI`Private`$workspaceChatInitialized = False,
            Wolfram`Chatbook`ChatModes`UI`Private`$chatPreloadTask          = None,
            Wolfram`Chatbook`ChatModes`UI`Private`scheduleChatPreloadStep   = AppendTo[ scheduled, # ] &,
            scheduled = { }
        },
        Wolfram`Chatbook`Common`scheduleChatPreload[ ];
        Block[ { Wolfram`Chatbook`ChatModes`UI`Private`$workspaceChatInitialized = True },
            Wolfram`Chatbook`Common`scheduleChatPreload[ ]
        ];
        scheduled
    ],
    { Wolfram`Chatbook`ChatModes`UI`Private`$chatPreloadInitialDelay },
    TestID -> "ScheduleChatPreload@@Tests/ChatPreload.wlt:143,1-159,2"
]

(* :!CodeAnalysis::EndBlock:: *)
