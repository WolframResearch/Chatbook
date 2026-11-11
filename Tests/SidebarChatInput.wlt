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
    $sidebarCell  = CellObject[ "sidebar-cell" ];

    (* The (held) send handler of the sidebar chat input cell, which runs when the return key is pressed: *)
    $sendHandler = FirstCase[
        Wolfram`Chatbook`Common`makeSidebarChatInputCell[ ],
        HoldPattern @ DynamicWrapperBox[ _, handler_, ___ ] :> HoldComplete @ handler,
        Missing[ "NotFound" ],
        Infinity
    ];

    (* Runs the send handler for a sidebar in the user's notebook, with front end calls replaced by a log: *)
    runSidebarSend[ ] := Module[ { log = { } },
        Block[
            {
                Typeset`nbo$$            = $userNotebook,
                Typeset`sidebarCell$$    = $sidebarCell,
                Typeset`input$$          = "Reply with exactly: OK2",
                Typeset`returnKeyDownQ$$ = True,
                Typeset`chatEvalCell$$   = { },
                CurrentValue,
                FE`Evaluate                   = Function[ Null, { }, HoldAll ],
                Cells                         = Function[ { } ],
                NotebookDelete                = Function[ AppendTo[ log, { "NotebookDelete", ## } ] ],
                FrontEndExecute               = Function[ AppendTo[ log, { "FrontEndExecute", ## } ] ],
                SetOptions                    = Function[ AppendTo[ log, { "SetOptions", ## } ] ],
                Wolfram`Chatbook`Common`setCurrentValue = Function[ AppendTo[ log, { "setCurrentValue", ## } ] ],
                Wolfram`Chatbook`Common`cellTaggedQ     = False &,
                Wolfram`Chatbook`Common`evaluateSidebarChat = Function[ AppendTo[ log, { "evaluateSidebarChat", #1, #3 } ] ],
                Wolfram`Chatbook`ChatModes`UI`Private`$workspaceChatInitialized = True
            },
            CurrentValue /: Set[ CurrentValue[ args___ ], value_ ] := (AppendTo[ log, { "CurrentValue", args } ]; value);
            ReleaseHold @ $sendHandler;
            log
        ]
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sidebar Send*)

(* Sending a sidebar message evaluates the chat in the user's notebook: *)
VerificationTest[
    Cases[ runSidebarSend[ ], { "evaluateSidebarChat", __ } ],
    { { "evaluateSidebarChat", $userNotebook, "Reply with exactly: OK2" } },
    SameTest -> MatchQ,
    TestID   -> "SidebarSend-EvaluatesChat"
]

(* Sending a sidebar message must not write the user's notebook options, e.g. WindowElements: *)
VerificationTest[
    FreeQ[ runSidebarSend[ ], { "setCurrentValue", $userNotebook, ___ } | { "SetOptions", $userNotebook, ___ } | WindowElements ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SidebarSend-NoWindowElementsWrite"
]

(* The front end runs the pre-built copy of the sidebar cell from the text resources, so it must match the source: *)
VerificationTest[
    Module[ { files },
        files = FileNameJoin @ { PacletObject[ "Wolfram/Chatbook" ][ "Location" ], #, "TextResources", "ChatbookResources.tr" } & /@
            { "FrontEnd", "DarkModeSupport" };
        {
            StringContainsQ[ ReadString @ #, "ChatModes`UI`Private`clearSidebarOverlayMenus[" ],
            StringContainsQ[ ReadString @ #, "ChatModes`UI`Private`clearOverlayMenus[" ]
        } & /@ Select[ files, FileExistsQ ]
    ],
    { { True, False }.. },
    SameTest -> MatchQ,
    TestID   -> "SidebarSend-PrebuiltResource"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Send/Stop Button*)

(* The send/stop button shows Stop only for a chat in this sidebar (robustness-4/sidebar-5): *)
VerificationTest[
    $inputCellBoxes = Wolfram`Chatbook`Common`makeSidebarChatInputCell[ ];
    $sendStopDynamic = FirstCase[
        $inputCellBoxes,
        PaneSelectorBox[ { False -> _, True -> _ }, d: (Dynamic|DynamicBox)[ ___ ], ___ ] /;
            ! FreeQ[ d, Wolfram`Chatbook`Common`chatEvaluatingInQ ] :> HoldComplete @ d,
        Missing[ "NotFound" ],
        Infinity
    ],
    HoldComplete[ (Dynamic|DynamicBox)[
        TrueQ[ Wolfram`Chatbook`Common`chatEvaluatingInQ[ ParentCell[ EvaluationCell[ ] ] ] ],
        TrackedSymbols :> { Wolfram`Chatbook`$ChatEvaluationCell }
    ] ],
    SameTest -> MatchQ,
    TestID   -> "SendButton-ScopedDynamic-robustness-4"
]

(* The front end evaluates a kernel Dynamic in a DynamicModule with the module's variables, even if it doesn't use them.
   When the sidebar is first opened from the menu, that can happen before the kernel knows them, which printed
   FE`ExecuteInDynamicModule::novaldu (chatbar-8). So the kernel Dynamic is behind a front end check that the
   module's Initialization has run: *)
VerificationTest[
    $initGate = FirstCase[
        $inputCellBoxes,
        PaneSelectorBox[ { False -> _, True -> inner_ }, (Dynamic|DynamicBox)[ FEPrivate`SameQ[ Typeset`initializedQ$$, True ], ___ ], ___ ] :>
            HoldComplete @ inner,
        Missing[ "NotFound" ],
        Infinity
    ];
    {
        MatchQ[ $initGate, _HoldComplete ],
        ! FreeQ[ $initGate, Wolfram`Chatbook`Common`chatEvaluatingInQ ],
        Count[ $inputCellBoxes, HoldPattern[ Wolfram`Chatbook`Common`chatEvaluatingInQ ], Infinity, Heads -> True ]
    },
    { True, True, 1 },
    SameTest -> MatchQ,
    TestID   -> "SendButton-InitializationGate-chatbar-8"
]

VerificationTest[
    $inputModule = FirstCase[ $inputCellBoxes, box: DynamicModuleBox[ { ___, HoldPattern[ Typeset`chatEvalCell$$ = _ ], ___ }, ___ ] :> HoldComplete @ box, None, Infinity ];
    {
        ! FreeQ[ $inputModule, HoldPattern[ DynamicModuleBox[ { ___, Typeset`initializedQ$$ = False, ___ }, ___ ] ] ],
        ! FreeQ[ Cases[ $inputModule, HoldPattern[ Initialization :> init_ ] :> HoldComplete @ init, Infinity ], HoldPattern[ Typeset`initializedQ$$ = True ] ]
    },
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "SendButton-InitializationSetsFlag-chatbar-8"
]

VerificationTest[
    FirstCase[
        $inputCellBoxes,
        b: HoldPattern[ ButtonBox[ __ ] ] /; ! FreeQ[ b, "NASidebarChatInputCellStopButton" ] :>
            FirstCase[ b, HoldPattern[ ButtonFunction :> f_ ] :> HoldComplete @ f, Missing[ ], Infinity ],
        Missing[ ],
        Infinity
    ],
    HoldComplete[ CompoundExpression[ _, Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChatIn", ParentCell[ EvaluationCell[ ] ] ] ] ],
    SameTest -> MatchQ,
    TestID   -> "SendButton-ScopedStop-robustness-4"
]

(* The front end draws the prebuilt sidebar cell, so it must match the source: *)
VerificationTest[
    Module[ { files },
        files = FileNameJoin @ { PacletObject[ "Wolfram/Chatbook" ][ "Location" ], #, "TextResources", "ChatbookResources.tr" } & /@
            { "FrontEnd", "DarkModeSupport" };
        With[ { s = StringDelete[ ReadString @ #, WhitespaceCharacter ] },
            {
                StringContainsQ[ s, "Wolfram`Chatbook`Common`chatEvaluatingInQ[ParentCell[EvaluationCell[]]]" ],
                StringContainsQ[ s, "\"StopChatIn\",ParentCell[EvaluationCell[]]" ],
                StringContainsQ[ s, "FEPrivate`SameQ[Typeset`initializedQ$$,True]" ],
                StringContainsQ[ s, "$ChatEvaluationCell===Typeset`chatEvalCell$$" ]
            }
        ] & /@ Select[ files, FileExistsQ ]
    ],
    { { True, True, True, False }.. },
    SameTest -> MatchQ,
    TestID   -> "SendButton-PrebuiltResource"
]

(* :!CodeAnalysis::EndBlock:: *)
