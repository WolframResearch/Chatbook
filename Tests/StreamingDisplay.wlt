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

(* The streaming output display polls the chat container on a fixed interval. These tests cover the per-chat trigger
   that lets the chunk handlers refresh it immediately at key moments, and the check that skips reformatting (and
   scrolling) when the content has not changed since the last update. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*createDynamicTrigger*)
VerificationTest[
    Module[ { container, trigger },
        container = <| "DynamicContent" -> None, "FullContent" -> "", "UUID" -> "test" |>;
        trigger = Wolfram`Chatbook`SendChat`Private`createDynamicTrigger @ container;
        {
            trigger,
            container[ "DynamicTrigger" ] === trigger,
            ReleaseHold @ trigger
        }
    ],
    { HoldComplete[ _Symbol ], True, 0 },
    SameTest -> MatchQ,
    TestID   -> "CreateDynamicTrigger"
]

VerificationTest[
    Module[ { container1, container2, trigger1, trigger2 },
        container1 = <| "DynamicContent" -> None |>;
        container2 = <| "DynamicContent" -> None |>;
        trigger1 = Wolfram`Chatbook`SendChat`Private`createDynamicTrigger @ container1;
        trigger2 = Wolfram`Chatbook`SendChat`Private`createDynamicTrigger @ container2;
        trigger1 =!= trigger2
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CreateDynamicTrigger-PerContainer"
]

VerificationTest[
    Module[ { container },
        Wolfram`Chatbook`SendChat`Private`createDynamicTrigger @ container
    ],
    HoldComplete[ _Symbol ],
    SameTest -> MatchQ,
    TestID   -> "CreateDynamicTrigger-NoContainer"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*updateDynamicDisplay*)
VerificationTest[
    Module[ { container },
        container = <| "DynamicContent" -> "Hello", "FullContent" -> "Hello" |>;
        {
            Wolfram`Chatbook`SendChat`Private`updateDynamicDisplay @ container,
            container
        }
    ],
    { Null, <| "DynamicContent" -> "Hello", "FullContent" -> "Hello" |> },
    SameTest -> MatchQ,
    TestID   -> "UpdateDynamicDisplay-NoTrigger"
]

VerificationTest[
    Module[ { container, trigger, values },
        container = <| "DynamicContent" -> None, "FullContent" -> "" |>;
        trigger = Wolfram`Chatbook`SendChat`Private`createDynamicTrigger @ container;
        values = Table[
            container[ "DynamicContent" ] = content;
            Wolfram`Chatbook`SendChat`Private`updateDynamicDisplay @ container;
            ReleaseHold @ trigger,
            { content, { None, ProgressIndicator[ Appearance -> "Percolate" ], "", " \n\t " } }
        ];
        container[ "DynamicContent" ] = "Hello";
        Wolfram`Chatbook`SendChat`Private`updateDynamicDisplay @ container;
        { values, ReleaseHold @ trigger, TrueQ @ container[ "DynamicUpdatePending" ] }
    ],
    { { 0, 0, 0, 0 }, _Real, False },
    SameTest -> MatchQ,
    TestID   -> "UpdateDynamicDisplay-FirstVisibleText"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`SendChat`Private`$dynamicTriggerInterval = 0 },
        Module[ { container, trigger, first },
            container = <| "DynamicContent" -> "Hello", "FullContent" -> "Hello" |>;
            trigger = Wolfram`Chatbook`SendChat`Private`createDynamicTrigger @ container;
            Wolfram`Chatbook`SendChat`Private`updateDynamicDisplay @ container;
            first = ReleaseHold @ trigger;
            (* More streamed text does not fire the trigger again, even without throttling: *)
            Do[
                container[ "DynamicContent" ] = container[ "DynamicContent" ] <> " world";
                Wolfram`Chatbook`SendChat`Private`updateDynamicDisplay @ container,
                { 5 }
            ];
            { NumberQ @ first, ReleaseHold @ trigger === first }
        ]
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "UpdateDynamicDisplay-NoPerChunkUpdates"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`SendChat`Private`$dynamicTriggerInterval = Infinity },
        Module[ { container, trigger, first, throttled, fired },
            container = <| "DynamicContent" -> "Hello", "FullContent" -> "Hello" |>;
            trigger = Wolfram`Chatbook`SendChat`Private`createDynamicTrigger @ container;
            (* The first visible text is not throttled: *)
            Wolfram`Chatbook`SendChat`Private`updateDynamicDisplay @ container;
            first = ReleaseHold @ trigger;

            (* A request made before the throttle interval has passed stays pending: *)
            container[ "DynamicUpdatePending" ] = True;
            Wolfram`Chatbook`SendChat`Private`updateDynamicDisplay @ container;
            throttled = { ReleaseHold @ trigger === first, container[ "DynamicUpdatePending" ] };

            (* Once the interval has passed, the next chunk fires it: *)
            Wolfram`Chatbook`SendChat`Private`$dynamicTriggerInterval = 0;
            Pause[ 0.05 ]; (* AbsoluteTime has a coarse resolution on some systems *)
            Wolfram`Chatbook`SendChat`Private`updateDynamicDisplay @ container;
            fired = { ReleaseHold @ trigger > first, container[ "DynamicUpdatePending" ] };

            { throttled, fired }
        ]
    ],
    { { True, True }, { True, False } },
    SameTest -> MatchQ,
    TestID   -> "UpdateDynamicDisplay-Throttle"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*writeChunk0*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$alwaysOpen             = False,
            Wolfram`Chatbook`SendChat`Private`$dynamicSplit = False,
            Wolfram`Chatbook`$InlineChat                    = False
        },
        Module[ { container, trigger, values },
            container = <| "DynamicContent" -> None, "FullContent" -> ProgressIndicator[ Appearance -> "Percolate" ] |>;
            trigger = Wolfram`Chatbook`SendChat`Private`createDynamicTrigger @ container;
            values = Table[
                Wolfram`Chatbook`SendChat`Private`writeChunk0[ Dynamic @ container, None, chunk, chunk ];
                ReleaseHold @ trigger,
                { chunk, { "", "\n", "Hello", " world", "!" } }
            ];
            { values, container[ "DynamicContent" ], container[ "FullContent" ] }
        ]
    ],
    { { 0, 0, t_Real, t_Real, t_Real }, "Hello world!", "Hello world!" },
    SameTest -> MatchQ,
    TestID   -> "WriteChunk0-FirstVisibleText"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$alwaysOpen                       = False,
            Wolfram`Chatbook`SendChat`Private`$dynamicSplit           = True,
            Wolfram`Chatbook`$InlineChat                              = False,
            Wolfram`Chatbook`SendChat`Private`$dynamicTriggerInterval = Infinity,
            Wolfram`Chatbook`SendChat`Private`writeDynamicChunkAsStatic
        },
        Module[ { container, trigger, written = { }, first, afterStatic, afterNext },
            Wolfram`Chatbook`SendChat`Private`writeDynamicChunkAsStatic[ static_, box_ ] := AppendTo[ written, static ];
            container = <| "DynamicContent" -> None, "FullContent" -> "", "DynamicBoxObject" -> None |>;
            trigger = Wolfram`Chatbook`SendChat`Private`createDynamicTrigger @ container;

            Wolfram`Chatbook`SendChat`Private`writeChunk0[ Dynamic @ container, None, #, # ] & /@ {
                "Here is some code:\n\n",
                "```wl\n1 + 1\n"
            };
            first = ReleaseHold @ trigger;

            (* Completing the code block writes it as static content, which requests an update: *)
            Wolfram`Chatbook`SendChat`Private`writeChunk0[ Dynamic @ container, None, "```\n", "```\n" ];
            Wolfram`Chatbook`SendChat`Private`writeChunk0[ Dynamic @ container, None, "Done", "Done" ];
            afterStatic = { written, container[ "DynamicContent" ], ReleaseHold @ trigger === first, container[ "DynamicUpdatePending" ] };

            (* The pending update fires with the next chunk once the throttle interval has passed: *)
            Wolfram`Chatbook`SendChat`Private`$dynamicTriggerInterval = 0;
            Pause[ 0.05 ]; (* AbsoluteTime has a coarse resolution on some systems *)
            Wolfram`Chatbook`SendChat`Private`writeChunk0[ Dynamic @ container, None, ".", "." ];
            afterNext = { ReleaseHold @ trigger > first, container[ "DynamicUpdatePending" ] };

            { NumberQ @ first, afterStatic, afterNext }
        ]
    ],
    {
        True,
        { { "Here is some code:\n\n```wl\n1 + 1\n```" }, "Done", True, True },
        { True, False }
    },
    SameTest -> MatchQ,
    TestID   -> "WriteChunk0-StaticWrite"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*activeAIAssistantDynamicModule*)

(* Extracts the held body and options of the "Active" Dynamic in the streaming output DynamicModule: *)
activeDynamic[ dm_ ] := First @ Cases[
    dm,
    ("Active" -> Verbatim[ Dynamic ][ body_, opts___ ]) :> { HoldComplete @ body, { opts } },
    Infinity
];

VerificationTest[
    Module[ { container, dm, body, opts },
        container = <| "DynamicContent" -> None, "FullContent" -> "", "UUID" -> "test" |>;
        dm = Wolfram`Chatbook`SendChat`Private`activeAIAssistantDynamicModule[ container, <| |>, None, #1 &, True ];
        { body, opts } = activeDynamic @ dm;
        { Head @ dm, opts, container[ "DynamicTrigger" ] }
    ],
    { DynamicModule, { TrackedSymbols :> { t_Symbol }, UpdateInterval -> 0.5 }, HoldComplete[ t_Symbol ] },
    SameTest -> MatchQ,
    TestID   -> "ActiveDynamic-TracksTrigger"
]

VerificationTest[
    Module[ { container, dm, body, opts, calls = 0, scrolls = 0, results },
        container = <| "DynamicContent" -> None, "FullContent" -> "", "UUID" -> "test" |>;
        dm = Wolfram`Chatbook`SendChat`Private`activeAIAssistantDynamicModule[ container, <| |>, None, #1 &, True ];
        { body, opts } = activeDynamic @ dm;
        Block[
            {
                Wolfram`Chatbook`SendChat`Private`cachedDynamicOutput,
                Wolfram`Chatbook`SendChat`Private`displayedContentHash = None,
                Wolfram`Chatbook`SendChat`Private`finishedSignal       = False,
                Wolfram`Chatbook`SendChat`Private`scrollToEnd          = (scrolls++) &,
                Wolfram`Chatbook`SendChat`Private`dynamicTextDisplay   = Function[ Null, calls++; { "Formatted", #1[ "DynamicContent" ] }, HoldFirst ]
            },
            results = {
                (* Waiting for content: *)
                ReleaseHold @ body,
                ReleaseHold @ body,
                (* Streaming: *)
                container[ "DynamicContent" ] = "Hello";
                ReleaseHold @ body,
                ReleaseHold @ body,
                ReleaseHold @ body,
                container[ "DynamicContent" ] = "Hello world";
                ReleaseHold @ body,
                ReleaseHold @ body,
                (* Finished: *)
                container[ "FinishedCell" ] = Cell[ "Hello world" ];
                ReleaseHold @ body
            };
            { results, calls, scrolls, Wolfram`Chatbook`SendChat`Private`finishedSignal }
        ]
    ],
    {
        {
            { "Formatted", None },
            { "Formatted", None },
            { "Formatted", "Hello" },
            { "Formatted", "Hello" },
            { "Formatted", "Hello" },
            { "Formatted", "Hello world" },
            { "Formatted", "Hello world" },
            { "Formatted", "Hello world" }
        },
        3,
        3,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ActiveDynamic-UnchangedContent"
]

VerificationTest[
    Module[ { container, dm, body, opts, calls = 0 },
        container = <| "DynamicContent" -> "Hello", "FullContent" -> "Hello", "UUID" -> "test" |>;
        dm = Wolfram`Chatbook`SendChat`Private`activeAIAssistantDynamicModule[ container, <| |>, None, #1 &, True ];
        { body, opts } = activeDynamic @ dm;
        Block[
            {
                Wolfram`Chatbook`SendChat`Private`cachedDynamicOutput,
                Wolfram`Chatbook`SendChat`Private`displayedContentHash = None,
                Wolfram`Chatbook`SendChat`Private`finishedSignal       = False,
                Wolfram`Chatbook`SendChat`Private`scrollToEnd          = Null &,
                Wolfram`Chatbook`SendChat`Private`dynamicTextDisplay   = Function[ Null, calls++; Failure[ "Test", <| |> ], HoldFirst ]
            },
            (* Failed formatting is not cached, so it is retried on the next update: *)
            Do[ ReleaseHold @ body, { 3 } ];
            calls
        ]
    ],
    3,
    SameTest -> MatchQ,
    TestID   -> "ActiveDynamic-FailureNotCached"
]

(* :!CodeAnalysis::EndBlock:: *)
