(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ACPState.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ACPState.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::NoSurroundingCatch:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*acpIsolated*)

(* Nothing evaluated inside acpIsolated may escape into the evaluation it interrupted: *)
VerificationTest[
    Catch[ Wolfram`Chatbook`ACP`Common`acpIsolated[ Throw[ 1, "tag" ] ], _, "escaped" & ],
    Failure[ "ACPInternal", KeyValuePattern @ { "Value" -> 1, "Tag" -> "tag" } ],
    SameTest -> MatchQ,
    TestID   -> "ACPState-Isolated-TaggedThrow@@Tests/ACPState.wlt:27,1-32,2"
]

VerificationTest[
    Catch[ Wolfram`Chatbook`ACP`Common`acpIsolated[ Throw[ 2 ] ] ],
    Failure[ "ACPInternal", KeyValuePattern @ { "Value" -> 2, "Tag" -> None } ],
    SameTest -> MatchQ,
    TestID   -> "ACPState-Isolated-UntaggedThrow@@Tests/ACPState.wlt:34,1-39,2"
]

VerificationTest[
    Wolfram`Chatbook`ACP`Common`acpIsolated[ Wolfram`Chatbook`Common`throwInternalFailure[ foo[ 1 ] ] ],
    _Failure,
    SameTest -> MatchQ,
    TestID   -> "ACPState-Isolated-InternalFailure@@Tests/ACPState.wlt:41,1-46,2"
]

VerificationTest[
    Wolfram`Chatbook`ACP`Common`acpIsolated[ 1 + 1 ],
    2,
    TestID -> "ACPState-Isolated-NormalResult@@Tests/ACPState.wlt:48,1-52,2"
]

(* A Throw that is caught inside the isolated evaluation is not affected: *)
VerificationTest[
    Wolfram`Chatbook`ACP`Common`acpIsolated[ Catch[ Throw[ 3 ]; 4 ] ],
    3,
    TestID -> "ACPState-Isolated-InnerCatch@@Tests/ACPState.wlt:55,1-59,2"
]

(* Messages are vetoed and only messages that would have been printed are logged: *)
VerificationTest[
    Module[ { before, result },
        General::acptest = "test message `1`";
        before = Internal`BagLength @ Wolfram`Chatbook`ACP`Common`$acpDebugLog;
        result = Wolfram`Chatbook`ACP`Common`acpIsolated[
            Message[ General::acptest, 1 ];
            Message[ General::newsym, "x", "y" ]; (* Off by default *)
            5
        ];
        { result, Internal`BagLength @ Wolfram`Chatbook`ACP`Common`$acpDebugLog - before }
    ],
    { 5, 1 },
    TestID -> "ACPState-Isolated-Messages@@Tests/ACPState.wlt:62,1-75,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*acpSchedule*)

(* Scheduled evaluations go through one recurring pump task (several one-shot tasks coming due together can deadlock
   the 15.0.1 kernel). Waiting with Pause lets the pump run. *)
VerificationTest[
    waitUntil // ClearAll;
    waitUntil // Attributes = { HoldFirst };
    waitUntil[ cond_, timeout_: 15 ] := Module[ { deadline = AbsoluteTime[ ] + timeout },
        While[ ! TrueQ @ cond && AbsoluteTime[ ] < deadline, Pause[ 0.05 ] ];
        TrueQ @ cond
    ];
    pumpTasks[ ] := Select[
        Tasks[ ],
        StringContainsQ[ ToString[ #[ "EvaluationExpression" ], InputForm ], "pumpTick" ] &
    ];
    Null,
    Null,
    TestID -> "ACPState-Schedule-Definitions@@Tests/ACPState.wlt:83,1-97,2"
]

VerificationTest[
    Module[ { results = { }, start, finished, tasks },
        start = AbsoluteTime[ ];
        Do[ With[ { i = i }, Wolfram`Chatbook`ACP`Common`acpSchedule[ AppendTo[ results, i ] ] ], { i, 200 } ];
        tasks = Length @ pumpTasks[ ];
        finished = waitUntil[ Length @ results === 200, 10 ];
        { finished, results === Range[ 200 ], tasks, AbsoluteTime[ ] - start < 5 }
    ],
    { True, True, 1, True },
    SameTest -> MatchQ,
    TestID   -> "ACPState-Schedule-Burst@@Tests/ACPState.wlt:99,1-110,2"
]

VerificationTest[
    Module[ { results = { }, start },
        start = SessionTime[ ];
        Wolfram`Chatbook`ACP`Common`acpSchedule[ AppendTo[ results, { "late", SessionTime[ ] - start } ], Quantity[ 400, "Milliseconds" ] ];
        Wolfram`Chatbook`ACP`Common`acpSchedule[ AppendTo[ results, { "default", SessionTime[ ] - start } ] ];
        Wolfram`Chatbook`ACP`Common`acpSchedule[ AppendTo[ results, { "seconds", SessionTime[ ] - start } ], Quantity[ 0.2, "Seconds" ] ];
        waitUntil[ Length @ results === 3, 10 ];
        { results[[ All, 1 ]], results[[ 1, 2 ]] >= 0.05, results[[ 2, 2 ]] >= 0.2, results[[ 3, 2 ]] >= 0.4 }
    ],
    { { "default", "seconds", "late" }, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPState-Schedule-Delay@@Tests/ACPState.wlt:112,1-124,2"
]

(* A scheduled evaluation that throws does not stop the others; one that schedules more work runs it later *)
VerificationTest[
    Module[ { results = { } },
        Wolfram`Chatbook`ACP`Common`acpSchedule[ AppendTo[ results, 1 ]; Throw[ "x" ]; AppendTo[ results, "not reached" ] ];
        Wolfram`Chatbook`ACP`Common`acpSchedule[
            AppendTo[ results, 2 ];
            Wolfram`Chatbook`ACP`Common`acpSchedule @ AppendTo[ results, 4 ]
        ];
        Wolfram`Chatbook`ACP`Common`acpSchedule[ AppendTo[ results, 3 ] ];
        waitUntil[ Length @ results === 4, 10 ];
        Pause[ 0.2 ];
        results
    ],
    { 1, 2, 3, 4 },
    TestID -> "ACPState-Schedule-Isolated@@Tests/ACPState.wlt:127,1-141,2"
]

(* The pump removes itself once it has had nothing to do for a while, and is created again on demand *)
VerificationTest[
    Module[ { stopped, restarted, results = { } },
        stopped = waitUntil[ Wolfram`Chatbook`ACP`State`Private`$publisherTask === None && pumpTasks[ ] === { }, 10 ];
        Wolfram`Chatbook`ACP`Common`acpSchedule[ AppendTo[ results, 1 ] ];
        restarted = Length @ pumpTasks[ ];
        { stopped, restarted, waitUntil[ results === { 1 }, 10 ], waitUntil[ pumpTasks[ ] === { }, 10 ] }
    ],
    { True, 1, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPState-Schedule-PumpStops@@Tests/ACPState.wlt:144,1-154,2"
]

(* Everything logged after this point is unexpected (checked by ACPState-DebugLog at the end): *)
VerificationTest[
    $acpLogStart = AbsoluteTime[ ];
    NumberQ @ $acpLogStart,
    True,
    TestID -> "ACPState-DebugLog-Start@@Tests/ACPState.wlt:157,1-162,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*acpCatchAll*)

(* acpCatchAll catches tagged and untagged throws (including Chatbook failures) without isolating anything else *)
VerificationTest[
    {
        Wolfram`Chatbook`ACP`Common`acpCatchAll[ 1 + 1 ],
        Wolfram`Chatbook`ACP`Common`acpCatchAll[ Throw[ 1 ] ],
        Wolfram`Chatbook`ACP`Common`acpCatchAll[ Throw[ 1, "tag" ] ],
        Wolfram`Chatbook`ACP`Common`acpCatchAll[ Throw[ 1 ], { ## } & ],
        Wolfram`Chatbook`ACP`Common`acpCatchAll[ Throw[ 1, "tag" ], { ## } & ],
        (* an untagged Cell is not mistaken for a result: *)
        Wolfram`Chatbook`ACP`Common`acpCatchAll[ Throw[ Cell[ "x" ] ] ],
        Wolfram`Chatbook`ACP`Common`acpCatchAll[ Catch[ Throw[ 3 ]; 4 ] ],
        Block[ { Wolfram`Chatbook`Common`$catching = True },
            Wolfram`Chatbook`ACP`Common`acpCatchAll[ Wolfram`Chatbook`Common`throwInternalFailure[ foo[ 1 ] ] ]
        ]
    },
    { 2, $Failed, $Failed, { 1, None }, { 1, "tag" }, $Failed, 3, $Failed },
    SameTest -> MatchQ,
    TestID   -> "ACPState-CatchAll@@Tests/ACPState.wlt:169,1-186,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Change Symbols*)

(* Change symbols must not be created with Unique: symbols created by Unique during a front end Dynamic evaluation are
   never tracked by Dynamics that read them later. They are named with State.wl's own counter, so two new symbols have
   consecutive numbers (which Unique would not give), and a tag of the kernel session, so views left over from a
   kernel that was restarted never track symbols of the new kernel. *)
VerificationTest[
    Module[ { names, tag },
        (* the names contain a tag of the kernel session: *)
        tag = IntegerString[ Mod[ $SessionID, 36^6 ], 36, 6 ];
        names = Replace[
            Wolfram`Chatbook`ACP`Common`acpEntitySymbol[ "acp-state-test-" <> CreateUUID[ ], { "Message", "m1" } ],
            HoldComplete[ s_Symbol ] :> SymbolName @ Unevaluated @ s
        ] & /@ { 1, 2 };
        {
            names,
            First @ names === "acpChangeSymbol" <> tag <> "n" <> ToString[ Wolfram`Chatbook`ACP`State`Private`$symbolCounter - 1 ],
            Last @ names === "acpChangeSymbol" <> tag <> "n" <> ToString @ Wolfram`Chatbook`ACP`State`Private`$symbolCounter
        }
    ],
    { { _String? (StringMatchQ[ "acpChangeSymbol" ~~ Repeated[ LetterCharacter | DigitCharacter, { 6 } ] ~~ "n" ~~ DigitCharacter.. ]), _String }, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPState-ChangeSymbol-Named@@Tests/ACPState.wlt:196,1-213,2"
]

VerificationTest[
    Wolfram`Chatbook`ACP`Common`acpEntitySymbol[ "acp-state-test", { "Message", "m1" } ] ===
        Wolfram`Chatbook`ACP`Common`acpEntitySymbol[ "acp-state-test", { "Message", "m1" } ],
    True,
    TestID -> "ACPState-ChangeSymbol-Stable@@Tests/ACPState.wlt:215,1-220,2"
]

VerificationTest[
    Module[ { held, before, after },
        held   = Wolfram`Chatbook`ACP`Common`acpEntitySymbol[ "acp-state-test", { "Message", "m1" } ];
        before = ReleaseHold @ held;
        Wolfram`Chatbook`ACP`Common`acpMarkDirty[ "acp-state-test", { { "Message", "m1" } } ];
        Wolfram`Chatbook`ACP`Common`acpPublish[ ];
        after = ReleaseHold @ held;
        after - before
    ],
    1,
    TestID -> "ACPState-ChangeSymbol-Publish@@Tests/ACPState.wlt:222,1-233,2"
]

VerificationTest[
    Wolfram`Chatbook`ACP`Common`acpTrackedDynamic[
        HoldComplete[ Wolfram`ChatbookTests`Private`x ],
        Wolfram`ChatbookTests`Private`f[ 1 ]
    ],
    HoldPattern @ Dynamic[
        CompoundExpression[ Wolfram`ChatbookTests`Private`x, Wolfram`ChatbookTests`Private`f[ 1 ] ],
        TrackedSymbols :> { Wolfram`ChatbookTests`Private`x }
    ],
    SameTest -> MatchQ,
    TestID   -> "ACPState-TrackedDynamic@@Tests/ACPState.wlt:235,1-246,2"
]

VerificationTest[
    Module[ { names },
        names = Replace[
            Values @ KeySelect[ Wolfram`Chatbook`ACP`State`Private`$symbols, MatchQ[ { _, "acp-state-test", ___ } ] ],
            HoldComplete[ s_Symbol ] :> Context @ Unevaluated @ s <> SymbolName @ Unevaluated @ s,
            { 1 }
        ];
        (* the render caches of the turn are dropped too: *)
        Wolfram`Chatbook`ACP`Rendering`Private`$renderCache[ { "acp-state-test", { "Message", "m1" } } ] = { 1, "boxes" };
        Wolfram`Chatbook`ACP`Rendering`Private`$textCache[ { "acp-state-test", { "Message", "m1" } } ] = <| |>;
        Wolfram`Chatbook`ACP`Common`acpTurnDrop[ "acp-state-test" ];
        {
            Length @ names > 0,
            Select[ Keys @ Wolfram`Chatbook`ACP`State`Private`$symbols, MatchQ[ { _, "acp-state-test", ___ } ] ],
            (* the symbols themselves are removed: *)
            Select[ names, NameQ ],
            Select[ Keys @ Wolfram`Chatbook`ACP`Rendering`Private`$renderCache, MatchQ[ { "acp-state-test", _ } ] ],
            Select[ Keys @ Wolfram`Chatbook`ACP`Rendering`Private`$textCache, MatchQ[ { "acp-state-test", _ } ] ]
        }
    ],
    { True, { }, { }, { }, { } },
    SameTest -> MatchQ,
    TestID   -> "ACPState-TurnDrop-Symbols@@Tests/ACPState.wlt:248,1-271,2"
]

(* Publishing a dirty spec whose symbol was dropped does not create the symbol again *)
VerificationTest[
    Module[ { count },
        count = Length @ Wolfram`Chatbook`ACP`State`Private`$symbols;
        Wolfram`Chatbook`ACP`State`Private`bumpSymbol @ { "Entity", "acp-state-dropped", { "Message", "m1" } };
        Length @ Wolfram`Chatbook`ACP`State`Private`$symbols - count
    ],
    0,
    TestID -> "ACPState-Publish-NoResurrection@@Tests/ACPState.wlt:274,1-282,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ACPLink*)

(* Once ACPLink is loaded, acpLoadACPLink is cheap: it is called about once a second per connected window *)
VerificationTest[
    Module[ { calls = 0 },
        Block[
            {
                Wolfram`Chatbook`ACP`State`Private`$acpLinkLoaded = True,
                Wolfram`Chatbook`ACP`State`Private`findACPLink = (calls++; None) &
            },
            { Table[ Wolfram`Chatbook`ACP`Common`acpLoadACPLink[ ], 3 ], calls }
        ]
    ],
    { { True, True, True }, 0 },
    SameTest -> MatchQ,
    TestID   -> "ACPState-LoadACPLink-Cached@@Tests/ACPState.wlt:289,1-302,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`ACP`State`Private`$acpLinkLoaded = False,
            Wolfram`Chatbook`ACP`State`Private`findACPLink = None &
        },
        Wolfram`Chatbook`ACP`Common`acpLoadACPLink[ ]
    ],
    Failure[ "ACPLinkMissing", _ ],
    SameTest -> MatchQ,
    TestID   -> "ACPState-LoadACPLink-Missing@@Tests/ACPState.wlt:304,1-315,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Kernel Restarts*)

(* The front end does not track symbols created while it evaluates the toolbar's DestroyAfterEvaluation DynamicBox
   (makeACPChatDockedCell[], from the ACPChat.nb stylesheet), which it evaluates again in a new kernel after a restart.
   The window's state (record and change symbols) must be rebuilt outside that Dynamic and before the toolbar that
   tracks it is built (D3 finding F2a). Headless: the window's TaggingRules are emulated (acpFE, acpFESet) and the front
   end work of the rebuild is recorded instead of done. *)
VerificationTest[
    ClearAll[ restartFlagsFE, restartWindowState, restartForget ];
    (* acpFE/acpFESet on an association of TaggingRules {"ACP", key} values *)
    restartFlagsFE[ flags_Symbol ] := {
        Function[ { nbo, key, default }, Lookup[ flags, key, default ] ],
        Function[ { nbo, key, value }, flags[ key ] = value ]
    };
    restartFlagsFE // Attributes = { HoldFirst };
    (* whether the window has a record and its window change symbol (without creating it) *)
    restartWindowState[ nbo_ ] := {
        KeyExistsQ[ Replace[ Wolfram`Chatbook`ACP`Common`acpWindowGet @ nbo, Except[ _Association ] -> <| |> ], "Status" ],
        KeyExistsQ[ Wolfram`Chatbook`ACP`State`Private`$symbols, { "Window", nbo } ]
    };
    restartForget[ nbo_ ] := (
        Wolfram`Chatbook`ACP`UI`Private`acpForgetWindow @ nbo;
        KeyDropFrom[ Wolfram`Chatbook`ACP`UI`Private`$placeholderToolbars, Key @ nbo ];
    );
    Null,
    Null,
    TestID -> "ACPState-Restart-Definitions@@Tests/ACPState.wlt:326,1-346,2"
]

(* A window this kernel does not know (a new kernel after a restart): the toolbar's Dynamic shows a placeholder whose
   Initialization runs "InitializeWindow"; it creates no change symbols and no record, and notes the window *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-state-restart-" <> CreateUUID[ ] ], counter, result },
        counter = Wolfram`Chatbook`ACP`State`Private`$symbolCounter;
        result  = Block[ { EvaluationNotebook = nbo & }, Wolfram`Chatbook`Common`makeACPChatDockedCell[ ] ];
        WithCleanup[
            {
                Head @ result,
                Wolfram`Chatbook`ACP`State`Private`$symbolCounter - counter,
                restartWindowState @ nbo,
                KeyExistsQ[ Wolfram`Chatbook`ACP`UI`Private`$placeholderToolbars, nbo ],
                ! FreeQ[ result, HoldPattern[ Initialization :> _ ] ] && ! FreeQ[ result, "InitializeWindow" ]
            },
            restartForget @ nbo
        ]
    ],
    { Framed, 0, { False, False }, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPState-Restart-PlaceholderToolbar@@Tests/ACPState.wlt:350,1-368,2"
]

(* A window this kernel knows (created in this session): the toolbar is built in the Dynamic from the symbols that
   exist already; none is created there *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-state-restart-" <> CreateUUID[ ] ], counter, result },
        Wolfram`Chatbook`ACP`UI`Private`acpRegisterWindow[ nbo, None, "OpenCode", <| |> ];
        counter = Wolfram`Chatbook`ACP`State`Private`$symbolCounter;
        result  = Block[ { EvaluationNotebook = nbo & }, Wolfram`Chatbook`Common`makeACPChatDockedCell[ ] ];
        WithCleanup[
            {
                Head @ result,
                Wolfram`Chatbook`ACP`State`Private`$symbolCounter - counter,
                KeyExistsQ[ Wolfram`Chatbook`ACP`UI`Private`$placeholderToolbars, nbo ],
                StringContainsQ[ ToString[ result, InputForm ], "acpChangeSymbol" ]
            },
            restartForget @ nbo
        ]
    ],
    { Framed, 0, False, True },
    SameTest -> MatchQ,
    TestID   -> "ACPState-Restart-KnownWindowToolbar@@Tests/ACPState.wlt:372,1-390,2"
]

(* acpCheckSession after a kernel restart (the TaggingRules name another kernel session): the record and its change
   symbols are rebuilt before acpMarkOrphanCells rebuilds the toolbar and the input field *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-state-restart-" <> CreateUUID[ ] ], flags, fe, seen = { }, result },
        flags = <| "KernelSessionID" -> $SessionID + 1, "Busy" -> True, "ProjectDirectory" -> None, "Agent" -> "OpenCode" |>;
        fe = restartFlagsFE @ flags;
        result = Block[
            {
                Wolfram`Chatbook`ACP`Common`acpFE             = fe[[ 1 ]],
                Wolfram`Chatbook`ACP`Common`acpFESet          = fe[[ 2 ]],
                Wolfram`Chatbook`ACP`Common`acpMarkOrphanCells = Function[ n, AppendTo[ seen, restartWindowState @ n ] ]
            },
            Wolfram`Chatbook`ACP`Common`acpCheckSession @ nbo
        ];
        WithCleanup[
            { result, seen, flags[ "KernelSessionID" ] === $SessionID, flags[ "Busy" ], Wolfram`Chatbook`ACP`Common`acpWindowGet[ nbo, "Status" ] },
            restartForget @ nbo
        ]
    ],
    { False, { { True, True } }, True, False, "NoDirectory" },
    SameTest -> MatchQ,
    TestID   -> "ACPState-Restart-RecordBeforeUI@@Tests/ACPState.wlt:394,1-414,2"
]

(* The placeholder's Initialization (acpInitializeWindow, in the pump) without a kernel restart (e.g. a window whose
   record was forgotten): the toolbar replaces the placeholder once the record and its symbols exist *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-state-restart-" <> CreateUUID[ ] ], flags, fe, seen = { } },
        flags = <| "KernelSessionID" -> $SessionID, "ProjectDirectory" -> None, "Agent" -> "OpenCode", "Input" -> "" |>;
        fe = restartFlagsFE @ flags;
        Block[ { EvaluationNotebook = nbo & }, Wolfram`Chatbook`Common`makeACPChatDockedCell[ ] ];
        Block[
            {
                Wolfram`Chatbook`ACP`Common`acpFE                  = fe[[ 1 ]],
                Wolfram`Chatbook`ACP`Common`acpFESet               = fe[[ 2 ]],
                Wolfram`Chatbook`ACP`Common`acpUpdateWindowTitle   = Null &,
                Wolfram`Chatbook`ACP`UI`Private`acpNotebookExistsQ = True &,
                Cells                                              = { CellObject[ "acp-state-input" ] } &,
                Wolfram`Chatbook`ACP`UI`Private`acpRefreshToolbar  = Function[ n,
                    AppendTo[ seen, restartWindowState @ n ];
                    KeyDropFrom[ Wolfram`Chatbook`ACP`UI`Private`$placeholderToolbars, Key @ n ]
                ]
            },
            Wolfram`Chatbook`ACP`UI`Private`acpInitializeWindow @ nbo;
            (* a second Initialization (the new toolbar's) rebuilds nothing *)
            Wolfram`Chatbook`ACP`UI`Private`acpInitializeWindow @ nbo
        ];
        WithCleanup[
            { seen, KeyExistsQ[ Wolfram`Chatbook`ACP`UI`Private`$placeholderToolbars, nbo ] },
            restartForget @ nbo
        ]
    ],
    { { { True, True } }, False },
    SameTest -> MatchQ,
    TestID   -> "ACPState-Restart-PlaceholderReplaced@@Tests/ACPState.wlt:418,1-447,2"
]

(* A window closed while it still shows the placeholder is forgotten with its placeholder note *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-state-restart-" <> CreateUUID[ ] ], noted },
        Block[ { EvaluationNotebook = nbo & }, Wolfram`Chatbook`Common`makeACPChatDockedCell[ ] ];
        noted = KeyExistsQ[ Wolfram`Chatbook`ACP`UI`Private`$placeholderToolbars, nbo ];
        Wolfram`Chatbook`ACP`UI`Private`acpForgetWindow @ nbo;
        WithCleanup[
            { noted, KeyExistsQ[ Wolfram`Chatbook`ACP`UI`Private`$placeholderToolbars, nbo ] },
            restartForget @ nbo
        ]
    ],
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "ACPState-Restart-ForgetDropsPlaceholder@@Tests/ACPState.wlt:450,1-463,2"
]

(* A kernel restart is logged ("KernelRestart"), so that a rebuild that went wrong can be told from one that never ran *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-state-restart-" <> CreateUUID[ ] ], flags, fe, t0 = AbsoluteTime[ ] },
        flags = <| "KernelSessionID" -> $SessionID + 1, "ProjectDirectory" -> None, "Agent" -> "OpenCode" |>;
        fe = restartFlagsFE @ flags;
        Block[
            {
                Wolfram`Chatbook`ACP`Common`acpFE              = fe[[ 1 ]],
                Wolfram`Chatbook`ACP`Common`acpFESet           = fe[[ 2 ]],
                Wolfram`Chatbook`ACP`Common`acpMarkOrphanCells = Null &
            },
            (* the second call finds the window owned by this session: nothing more is logged *)
            Wolfram`Chatbook`ACP`Common`acpCheckSession @ nbo;
            Wolfram`Chatbook`ACP`Common`acpCheckSession @ nbo
        ];
        WithCleanup[
            Cases[
                Internal`BagPart[ Wolfram`Chatbook`ACP`Common`$acpDebugLog, All ],
                KeyValuePattern @ { "Where" -> "KernelRestart", "Time" -> t_ /; t >= t0, "Data" -> KeyValuePattern[ "Notebook" -> nbo ] } :> True
            ],
            restartForget @ nbo
        ]
    ],
    { True },
    SameTest -> MatchQ,
    TestID   -> "ACPState-Restart-Logged@@Tests/ACPState.wlt:466,1-491,2"
]

(* acpRefreshToolbar replaces the toolbar cell among the window's docked cells (also with its tag given in a list, and a
   single docked cell); docked cells without the toolbar are kept, and that is logged ("ToolbarNotFound") *)
VerificationTest[
    Module[ { nbo = NotebookObject[ "acp-state-restart-" <> CreateUUID[ ] ], strip, toolbar, set, refresh, t0 = AbsoluteTime[ ] },
        strip   = Cell[ "", CellTags -> "Strip" ];
        toolbar = Cell[ "old", CellTags -> { "ACPToolbar" } ];
        refresh = Function[ docked,
            set = None;
            Block[
                {
                    AbsoluteCurrentValue = docked &,
                    SetOptions           = Function[ { n, opt }, set = opt; Null ]
                },
                Wolfram`Chatbook`ACP`UI`Private`acpRefreshToolbar @ nbo
            ];
            Replace[ set, {
                ( DockedCells -> cells_List ) :> Replace[ cells, { Cell[ BoxData[ _ ], ___, CellTags -> "ACPToolbar", ___ ] -> "New", Cell[ _, CellTags -> t_ ] :> t }, { 1 } ],
                None -> None
            } ]
        ];
        WithCleanup[
            {
                refresh @ { strip, toolbar },
                refresh @ Cell[ "old", CellTags -> "ACPToolbar" ],
                refresh @ { strip },
                Cases[
                    Internal`BagPart[ Wolfram`Chatbook`ACP`Common`$acpDebugLog, All ],
                    KeyValuePattern @ { "Where" -> "ToolbarNotFound", "Time" -> t_ /; t >= t0, "Data" -> KeyValuePattern @ { "Notebook" -> nbo, "DockedCells" -> d_ } } :> d
                ]
            },
            restartForget @ nbo
        ]
    ],
    { { "Strip", "New" }, { "New" }, None, { { 1, { "Strip" } } } },
    SameTest -> MatchQ,
    TestID   -> "ACPState-Restart-RefreshToolbar@@Tests/ACPState.wlt:495,1-529,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Debug Log*)

(* Isolated code swallows messages and failures into the debug log; nothing unexpected may have been logged *)
VerificationTest[
    Select[
        Internal`BagPart[ Wolfram`Chatbook`ACP`Common`$acpDebugLog, All ],
        #[ "Time" ] >= $acpLogStart && MemberQ[ { "Message", "Uncaught", "FinalCellFailed", "FinalCellFallback", "FinishedFormattingFallback" }, #[ "Where" ] ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPState-DebugLog@@Tests/ACPState.wlt:536,1-544,2"
]

(* :!CodeAnalysis::EndBlock:: *)
