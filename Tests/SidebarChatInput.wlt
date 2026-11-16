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
                Wolfram`Chatbook`Common`evaluateSidebarChat = Function[
                    AppendTo[ log, { "evaluateSidebarChat", #1, #3 } ];
                    AppendTo[ log, { "evaluateSidebarChat-InputField", #5 } ]
                ],
                Wolfram`Chatbook`ChatModes`UI`Private`$workspaceChatInitialized = True
            },
            CurrentValue /: Set[ CurrentValue[ args___ ], value_ ] := (AppendTo[ log, { "CurrentValue", args } ]; value);
            ReleaseHold @ $sendHandler;
            log
        ]
    ];

    $sidebarChatInput  = CellObject[ "sidebar-chat-input" ];
    $sidebarChatOutput = CellObject[ "sidebar-chat-output" ];

    (* Sends "Hello" from the sidebar with a stubbed front end. ChatCellEvaluate gives result, and then the cell after
       the chat input is next (None for no cell). The arguments of
       evaluateSidebarChat after the input are args. Gives the result and a log of the calls that look at or change
       the sidebar: *)
    sendSidebarChat[ result_, next_, args__ ] := Module[ { log = { } },
        Block[
            {
                CurrentValue,
                ChatCellEvaluate = result &,
                NextCell         = (AppendTo[ log, { "NextCell", # } ]; next) &,
                NotebookDelete   = AppendTo[ log, { "NotebookDelete", # } ] &,
                Wolfram`Chatbook`Common`appendCellToSidebarChat = $sidebarChatInput &,
                Wolfram`Chatbook`Common`setCurrentValue         = Null &
            },
            { Wolfram`Chatbook`Common`evaluateSidebarChat[ $userNotebook, $sidebarCell, "Hello", args ], log }
        ]
    ];

    (* Sends "Hello" from the sidebar with a stubbed front end, where the chat (in ChatCellEvaluate) evaluates eval: *)
    sendSidebarChatEvaluating // Attributes = { HoldFirst };
    sendSidebarChatEvaluating[ eval_ ] := Module[ { cell = None },
        Block[
            {
                CurrentValue,
                Wolfram`Chatbook`Actions`EvaluateChatInput      = eval &,
                Wolfram`Chatbook`Common`appendCellToSidebarChat = $sidebarChatInput &,
                Wolfram`Chatbook`Common`setCurrentValue         = Null &
            },
            Wolfram`Chatbook`Common`evaluateSidebarChat[ $userNotebook, $sidebarCell, "Hello", Dynamic @ cell ]
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
    Module[ { file },
        file = FileNameJoin @ { PacletObject[ "Wolfram/Chatbook" ][ "Location" ], "FrontEnd", "TextResources", "ChatbookResources.tr" };
        {
            StringContainsQ[ ReadString @ file, "ChatModes`UI`Private`clearSidebarOverlayMenus[" ],
            StringContainsQ[ ReadString @ file, "ChatModes`UI`Private`clearOverlayMenus[" ]
        }
    ],
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "SidebarSend-PrebuiltResource"
]

(* The input field variable is given, so that the text of a stopped chat can be put back in it: *)
VerificationTest[
    Cases[ runSidebarSend[ ], { "evaluateSidebarChat-InputField", field_ } :> HoldComplete @ field ],
    { HoldComplete @ Dynamic @ Typeset`fieldContent$$ },
    SameTest -> MatchQ,
    TestID   -> "SidebarSend-InputField-GH#1710"
]

VerificationTest[
    Module[ { file },
        file = FileNameJoin @ { PacletObject[ "Wolfram/Chatbook" ][ "Location" ], "FrontEnd", "TextResources", "ChatbookResources.tr" };
        StringContainsQ[
            StringDelete[ ReadString @ file, WhitespaceCharacter ],
            "Wolfram`Chatbook`Common`evaluateSidebarChat[Typeset`nbo$$,Typeset`sidebarCell$$,Typeset`input$$,Dynamic[Typeset`chatEvalCell$$],Dynamic[Typeset`fieldContent$$]]"
        ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SidebarSend-PrebuiltResource-InputField-GH#1710"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Stopped Chats*)

(* A chat that is stopped before its response arrives has no output cell. Its input is removed, so the next message
   isn't also answering it, and its text is put back in the input field: *)
VerificationTest[
    Module[ { cell = None, field = "" },
        { sendSidebarChat[ Null, None, Dynamic @ cell, Dynamic @ field ], cell, field }
    ],
    {
        { Null, { { "NextCell", $sidebarChatInput }, { "NotebookDelete", $sidebarChatInput } } },
        $sidebarChatInput,
        "Hello"
    },
    SameTest -> MatchQ,
    TestID   -> "EvaluateSidebarChat-StoppedChat-GH#1710"
]

(* Text typed while the chat ran is kept: *)
VerificationTest[
    Module[ { cell = None, field = "New text" },
        { sendSidebarChat[ Null, None, Dynamic @ cell, Dynamic @ field ], field }
    ],
    { { Null, { { "NextCell", $sidebarChatInput }, { "NotebookDelete", $sidebarChatInput } } }, "New text" },
    SameTest -> MatchQ,
    TestID   -> "EvaluateSidebarChat-StoppedChat-KeepsNewInput-GH#1710"
]

(* The sidebar input cell of a front end session that started with an older version of Chatbook doesn't give the input
   field. The input is still removed: *)
VerificationTest[
    Module[ { cell = None },
        sendSidebarChat[ Null, None, Dynamic @ cell ]
    ],
    { Null, { { "NextCell", $sidebarChatInput }, { "NotebookDelete", $sidebarChatInput } } },
    SameTest -> MatchQ,
    TestID   -> "EvaluateSidebarChat-StoppedChat-NoInputField-GH#1710"
]

(* A chat that left a cell after its input (a response, or the error cell of a failed request) keeps its input, and
   the input field stays empty: *)
VerificationTest[
    Module[ { cell = None, field = "" },
        { sendSidebarChat[ Null, $sidebarChatOutput, Dynamic @ cell, Dynamic @ field ], field }
    ],
    { { Null, { { "NextCell", $sidebarChatInput } } }, "" },
    SameTest -> MatchQ,
    TestID   -> "EvaluateSidebarChat-Answered-GH#1710"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Failures*)

(* A failure in the chat is reported once, with the data of where it happened. It used to be caught by
   ChatCellEvaluate, so evaluateSidebarChat reported a second failure, which hid the first one: *)
VerificationTest[
    sendSidebarChatEvaluating @ Wolfram`Chatbook`Common`throwInternalFailure @ sidebarChatFailureTest[ ],
    Failure[ _, KeyValuePattern[ "MessageParameters" :> { _, KeyValuePattern[ "Evaluation" :> sidebarChatFailureTest[ ] ] } ] ],
    { General::ChatbookInternal },
    SameTest -> MatchQ,
    TestID   -> "EvaluateSidebarChat-InternalFailure-GH#1639"
]

(* A failure that the chat throws without a message (e.g. an API error when there's no output cell to write it to) is
   not reported as an internal failure: *)
VerificationTest[
    sendSidebarChatEvaluating @ Wolfram`Chatbook`Common`throwTop @ Failure[ "APIError", <| "StatusCode" -> 500 |> ],
    Failure[ "APIError", <| "StatusCode" -> 500 |> ],
    SameTest -> MatchQ,
    TestID   -> "EvaluateSidebarChat-ThrownFailure-GH#1639"
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
    Module[ { file },
        file = FileNameJoin @ { PacletObject[ "Wolfram/Chatbook" ][ "Location" ], "FrontEnd", "TextResources", "ChatbookResources.tr" };
        With[ { s = StringDelete[ ReadString @ file, WhitespaceCharacter ] },
            {
                StringContainsQ[ s, "Wolfram`Chatbook`Common`chatEvaluatingInQ[ParentCell[EvaluationCell[]]]" ],
                StringContainsQ[ s, "\"StopChatIn\",ParentCell[EvaluationCell[]]" ],
                StringContainsQ[ s, "FEPrivate`SameQ[Typeset`initializedQ$$,True]" ],
                StringContainsQ[ s, "$ChatEvaluationCell===Typeset`chatEvalCell$$" ]
            }
        ]
    ],
    { True, True, True, False },
    SameTest -> MatchQ,
    TestID   -> "SendButton-PrebuiltResource"
]

(* :!CodeAnalysis::EndBlock:: *)
