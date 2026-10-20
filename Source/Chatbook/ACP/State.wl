(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`State`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ACP`Common`" ];

(* Kernel-side state for ACP windows (see docs/acp-window.md, "State model" and "Threading rules").

   Rules for everything in the ACP subpackage:
   * Reader handlers, scheduled tasks, Dynamic renderers and preemptive button actions run inside `acpIsolated`.
   * Shared state is only modified through `acpWindowUpdate`/`acpTurnUpdate` (PreemptProtect'ed, pure updates).
   * Front end views track per-window/per-turn/per-entity symbols, which are bumped by `acpPublish`. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$acpPumpInterval         = Quantity[ 50 , "Milliseconds" ];
$acpPublishEvery         = 4;  (* pump ticks per publication and housekeeping tick (0.2 s) *)
$acpPumpIdleTicks        = 40; (* the pump task removes itself after 2 s with nothing to do *)
$acpScheduleDelay        = Quantity[ 50 , "Milliseconds" ];
$acpMaxDebugLogLength    = 2000;
(* OpenACPConnection must support this option (ACPLink fix branch): remote windows hold back the launch script and every
   message until the remote shell asks for it (Connection.wl's openConnection0) *)
$acpMinimumACPLinkOption = "StandardInputPreambleTrigger";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Stores*)

(* These are intentionally not reset if this file is reloaded during development, so open connections are not
   orphaned. In the MX build they start out empty. *)
If[ ! AssociationQ @ $acpWindows, $acpWindows = <| |> ];
If[ ! AssociationQ @ $acpTurns  , $acpTurns   = <| |> ];
If[ ! AssociationQ @ $acpOpen   , $acpOpen    = <| |> ];
If[ ! AssociationQ @ $symbols   , $symbols    = <| |> ];
If[ ! AssociationQ @ $dirty     , $dirty      = <| |> ];
If[ ! AssociationQ @ $housekeeping, $housekeeping = <| |> ];
If[ ! MatchQ[ $acpDebugLog, _Internal`Bag ], $acpDebugLog = Internal`Bag[ ] ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Window Records*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpWindowGet*)
acpWindowGet // beginDefinition;
acpWindowGet[ nbo_NotebookObject ] := Lookup[ $acpWindows, nbo, Missing[ "NotFound" ] ];
acpWindowGet[ nbo_NotebookObject, key_ ] := acpWindowGet[ nbo, key, Missing[ "KeyAbsent", key ] ];
acpWindowGet[ nbo_NotebookObject, key_, default_ ] := acpWindowGet0[ acpWindowGet @ nbo, key, default ];
acpWindowGet // endDefinition;

acpWindowGet0 // beginDefinition;
acpWindowGet0[ as_Association, key_, default_ ] := Lookup[ as, key, default ];
acpWindowGet0[ _Missing, key_, default_ ] := default;
acpWindowGet0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpWindowUpdate*)

(* `f` receives the current record (or a new <| "Notebook" -> nbo |> record) and returns the new record. Anything other
   than an association leaves the record unchanged and is returned as-is. `f` must be fast and must not make front end
   calls or perform I/O, since it runs inside PreemptProtect. *)
acpWindowUpdate // beginDefinition;

acpWindowUpdate[ nbo_NotebookObject, f_ ] := Module[ { result },
    result = PreemptProtect @ Module[ { old, new },
        old = Lookup[ $acpWindows, nbo, <| "Notebook" -> nbo |> ];
        new = f @ old;
        If[ AssociationQ @ new, $acpWindows[ nbo ] = new ];
        new
    ];
    If[ AssociationQ @ result, acpMarkWindowDirty @ nbo ];
    result
];

acpWindowUpdate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpWindowSet*)
acpWindowSet // beginDefinition;
acpWindowSet[ nbo_NotebookObject, key_, value_ ] := acpWindowUpdate[ nbo, Append[ #, key -> value ] & ];
acpWindowSet[ nbo_NotebookObject, rules: _Association | { (_Rule|_RuleDelayed)... } ] := acpWindowUpdate[ nbo, Join[ #, Association @ rules ] & ];
acpWindowSet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpWindowDrop*)
acpWindowDrop // beginDefinition;

acpWindowDrop[ nbo_NotebookObject ] := (
    PreemptProtect[ KeyDropFrom[ $acpWindows, nbo ] ];
    dropSymbol @ { "Window", nbo };
    Null
);

acpWindowDrop // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Turn Records*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpTurnCreate*)
acpTurnCreate // beginDefinition;

acpTurnCreate[ turn: KeyValuePattern[ "ID" -> id_String ] ] := (
    PreemptProtect[ $acpTurns[ id ] = turn ];
    acpMarkLayoutDirty @ id;
    id
);

acpTurnCreate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpTurnGet*)
acpTurnGet // beginDefinition;
acpTurnGet[ id_String ] := Lookup[ $acpTurns, id, Missing[ "NotFound" ] ];
acpTurnGet[ id_String, key_ ] := acpTurnGet[ id, key, Missing[ "KeyAbsent", key ] ];
acpTurnGet[ id_String, key_, default_ ] := acpWindowGet0[ acpTurnGet @ id, key, default ];
acpTurnGet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpTurnUpdate*)

(* `f` receives the current turn record and returns either
     * a new turn record (all entities and the layout are marked dirty), or
     * <| "Turn" -> newTurn, "Changed" -> { key... } | All, "Layout" -> True|False |> to mark only what changed.
   Anything else leaves the turn unchanged. Returns the result of `f` (or Missing if the turn does not exist).
   `f` must be fast and must not make front end calls or perform I/O, since it runs inside PreemptProtect. *)
acpTurnUpdate // beginDefinition;

acpTurnUpdate[ id_String, f_ ] := Module[ { result },
    result = PreemptProtect @ Module[ { old, new },
        old = Lookup[ $acpTurns, id, Missing[ "NotFound" ] ];
        If[ MissingQ @ old, Return[ old, Module ] ];
        new = f @ old;
        Which[
            MatchQ[ new, KeyValuePattern[ "Turn" -> _Association ] ],
                $acpTurns[ id ] = new[ "Turn" ];
                new,
            AssociationQ @ new,
                $acpTurns[ id ] = new;
                <| "Turn" -> new, "Changed" -> All, "Layout" -> True |>,
            True,
                new
        ]
    ];
    markTurnChanges[ id, result ];
    result
];

acpTurnUpdate // endDefinition;


markTurnChanges // beginDefinition;

markTurnChanges[ id_, as: KeyValuePattern[ "Turn" -> turn_Association ] ] := (
    Replace[
        Lookup[ as, "Changed", All ],
        {
            All          :> acpMarkDirty[ id, Keys @ Lookup[ turn, "Entities", <| |> ] ],
            keys_List    :> acpMarkDirty[ id, keys ],
            _            :> Null
        }
    ];
    If[ TrueQ @ Lookup[ as, "Layout", False ], acpMarkLayoutDirty @ id ]
    (* The window symbol is not marked here: window-level views depend on the window record, which is marked dirty by
       acpWindowUpdate. Bumping it on every streamed chunk would re-render toolbar views several times a second. *)
);

markTurnChanges[ _, _ ] := Null;

markTurnChanges // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpTurnDrop*)

(* Called after a turn has been finalized (its output cell no longer contains live views). *)
acpTurnDrop // beginDefinition;

acpTurnDrop[ id_String ] := (
    PreemptProtect[
        KeyDropFrom[ $acpTurns, id ];
        $acpOpen = KeySelect[ $acpOpen, ! MatchQ[ #, { id, ___ } ] & ];
        $dirty   = KeySelect[ $dirty  , ! MatchQ[ #, { "Layout", id } | { "Entity", id, _ } ] & ]
    ];
    dropSymbols @ { "Layout", id };
    dropSymbols @ { "Entity", id, _ };
    (* After the turn record is gone, so a late preemptive render finds no turn and cannot fill the caches again: *)
    acpDropRenderCache @ id;
    Null
);

acpTurnDrop // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Change Publication*)

(* Front end views use `acpTrackedDynamic[ acpEntitySymbol[ turnID, key ], view[ ... ] ]` (and the window/layout
   variants), which track one change symbol each. Handlers mark symbols dirty; `acpPublish` (run every $acpPublishInterval by the
   publisher task, or directly from fast UI actions) increments them, which invalidates the corresponding Dynamics. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Symbols*)

(* These return HoldComplete[ sym ]. Use acpTrackedDynamic to build a Dynamic that tracks the symbol. *)
acpWindowSymbol // beginDefinition;
acpWindowSymbol[ nbo_NotebookObject ] := changeSymbolHeld @ { "Window", nbo };
acpWindowSymbol // endDefinition;

acpLayoutSymbol // beginDefinition;
acpLayoutSymbol[ id_String ] := changeSymbolHeld @ { "Layout", id };
acpLayoutSymbol // endDefinition;

acpEntitySymbol // beginDefinition;
acpEntitySymbol[ id_String, key_ ] := changeSymbolHeld @ { "Entity", id, key };
acpEntitySymbol // endDefinition;

(* Change symbols are created by name with our own counter rather than with Unique: a symbol created by Unique
   during a front end Dynamic evaluation is never tracked by Dynamics that read it later (verified in a front end),
   and these symbols are often first requested from inside a Dynamic (e.g. the view of a new entity).
   Names also contain a tag of the kernel session, so the views of a kernel that was restarted (still in the front end
   until they are rebuilt) never track the symbols of another entity in the new kernel, and views rebuilt after a
   restart always differ from the old ones. *)
If[ ! IntegerQ @ $symbolCounter, $symbolCounter = 0 ];

changeSymbolHeld // beginDefinition;

changeSymbolHeld[ spec_ ] := PreemptProtect @ Lookup[
    $symbols,
    Key @ spec,
    $symbols[ spec ] = newChangeSymbol[ ]
];

changeSymbolHeld // endDefinition;


newChangeSymbol // beginDefinition;

newChangeSymbol[ ] := Replace[
    ToExpression[
        "Wolfram`Chatbook`ACP`State`Private`acpChangeSymbol" <> sessionTag[ ] <> "n" <> ToString[ ++$symbolCounter ],
        InputForm,
        HoldComplete
    ],
    HoldComplete[ s_Symbol ] :> (s = 0; HoldComplete @ s)
];

newChangeSymbol // endDefinition;


(* Evaluated each time ($SessionID must not be fixed in the MX build) *)
sessionTag // beginDefinition;
sessionTag[ ] := IntegerString[ Mod[ $SessionID, 36^6 ], 36, 6 ];
sessionTag // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpTrackedDynamic*)

(* acpTrackedDynamic[ HoldComplete[ sym ], expr, opts ] gives Dynamic[ sym; expr, TrackedSymbols :> { sym }, opts ],
   so the front end re-evaluates expr only when sym is bumped by acpPublish. expr is held. *)
acpTrackedDynamic // beginDefinition;
acpTrackedDynamic // Attributes = { HoldRest };

acpTrackedDynamic[ HoldComplete[ s_Symbol ], expr_, opts___ ] :=
    Dynamic[ s; expr, TrackedSymbols :> { s }, opts ];

acpTrackedDynamic // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*dropSymbol(s)*)
dropSymbol // beginDefinition;
dropSymbol[ spec_ ] := dropSymbols @ spec;
dropSymbol // endDefinition;

dropSymbols // beginDefinition;

(* The symbols themselves are removed as well, so they don't accumulate over a long session. Callers drop symbols only
   after the views that track them are gone (final cell written, window closed, cells cleared). Names are never reused,
   so a stale front end Dynamic can at worst create one bare symbol without a value. *)
dropSymbols[ pattern_ ] := PreemptProtect @ With[ { k = Select[ Keys @ $symbols, MatchQ[ pattern ] ] },
    Scan[ Replace[ $symbols[ # ], HoldComplete[ s_Symbol ] :> Quiet @ Remove @ s ] &, k ];
    KeyDropFrom[ $symbols, k ];
    $dirty = KeyDrop[ $dirty, k ];
    Null
];

dropSymbols // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMarkDirty*)
acpMarkDirty // beginDefinition;

acpMarkDirty[ id_String, keys_List ] := (
    PreemptProtect @ Scan[ ($dirty[ { "Entity", id, # } ] = True) &, keys ];
    acpEnsurePublisher[ ]
);

acpMarkDirty // endDefinition;


acpMarkLayoutDirty // beginDefinition;
acpMarkLayoutDirty[ id_String ] := (PreemptProtect[ $dirty[ { "Layout", id } ] = True ]; acpEnsurePublisher[ ]);
acpMarkLayoutDirty // endDefinition;


acpMarkWindowDirty // beginDefinition;
acpMarkWindowDirty[ nbo_NotebookObject ] := (PreemptProtect[ $dirty[ { "Window", nbo } ] = True ]; acpEnsurePublisher[ ]);
acpMarkWindowDirty // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPublish*)
acpPublish // beginDefinition;

acpPublish[ ] := Module[ { specs },
    specs = PreemptProtect @ With[ { k = Keys @ $dirty }, $dirty = <| |>; k ];
    Scan[ bumpSymbol, specs ];
    Length @ specs
];

acpPublish // endDefinition;


bumpSymbol // beginDefinition;

(* Only symbols that exist are bumped: a view that is created later reads the current state anyway, and a dropped
   symbol must not be created again by a publish that raced with acpTurnDrop. *)
bumpSymbol[ spec_ ] := Replace[
    Lookup[ $symbols, Key @ spec, None ],
    HoldComplete[ s_Symbol ] :> (s = If[ IntegerQ @ s, s + 1, 1 ])
];

bumpSymbol // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Publisher Task*)

(* A single kernel-wide recurring task, the pump, runs the evaluations queued by acpSchedule (every tick), publishes
   dirty symbols and runs the registered housekeeping functions (every $acpPublishEvery ticks). It is the only scheduled
   task Chatbook's ACP code creates: the 15.0.1 kernel can deadlock when several one-shot scheduled tasks come due
   together, or when recurring tasks remove themselves at a high rate (see ACPLink's UPSTREAM-NOTES.md, "Kernel scheduler
   deadlocks"). The pump removes itself only after it has had nothing to do for $acpPumpIdleTicks ticks. *)
If[ ! MatchQ[ $publisherTask, _TaskObject ], $publisherTask = None ];
If[ ! IntegerQ @ $publisherTicks, $publisherTicks = 0 ];
If[ ! IntegerQ @ $pumpTicks     , $pumpTicks      = 0 ];
If[ ! IntegerQ @ $idleTicks     , $idleTicks      = 0 ];
If[ ! IntegerQ @ $scheduleCount , $scheduleCount  = 0 ];
If[ ! ListQ @ $scheduled        , $scheduled      = { } ];

acpEnsurePublisher // beginDefinition;

acpEnsurePublisher[ ] := PreemptProtect @ If[ ! publisherRunningQ[ ],
    $idleTicks     = 0;
    $publisherTask = SessionSubmit @ ScheduledTask[ pumpTick[ ], $acpPumpInterval ]
];

acpEnsurePublisher // endDefinition;


publisherRunningQ // beginDefinition;
publisherRunningQ[ ] := MatchQ[ $publisherTask, _TaskObject ] && MatchQ[ Quiet @ $publisherTask[ "TaskStatus" ], "Running" | "Pending" ];
publisherRunningQ // endDefinition;


pumpTick // beginDefinition;

pumpTick[ ] := acpIsolated[
    $pumpTicks++;
    runScheduled[ ];
    If[ Mod[ $pumpTicks, $acpPublishEvery ] === 0, publisherTick[ ] ];
    If[ $scheduled === { } && ! publisherNeededQ[ ], $idleTicks++, $idleTicks = 0 ];
    If[ $idleTicks >= $acpPumpIdleTicks,
        PreemptProtect[
            Quiet @ TaskRemove @ $publisherTask;
            $publisherTask = None;
            $idleTicks     = 0
        ]
    ]
];

pumpTick // endDefinition;


(* Runs the queued evaluations that are due, in order. Evaluations queued while these run wait for a later tick. *)
runScheduled // beginDefinition;

runScheduled[ ] := Module[ { now, due },
    now = SessionTime[ ];
    due = PreemptProtect @ With[ { d = Select[ $scheduled, First[ # ] <= now & ] },
        If[ d =!= { }, $scheduled = Select[ $scheduled, First[ # ] > now & ] ];
        d
    ];
    Scan[ Replace[ Last @ #, HoldComplete[ eval_ ] :> acpIsolated @ eval ] &, SortBy[ due, Most ] ];
    Length @ due
];

runScheduled // endDefinition;


publisherTick // beginDefinition;

publisherTick[ ] := acpIsolated[
    $publisherTicks++;
    acpPublish[ ];
    KeyValueMap[ runHousekeeping, $housekeeping ]
];

publisherTick // endDefinition;


runHousekeeping // beginDefinition;
runHousekeeping[ name_, KeyValuePattern @ { "Function" -> f_, "Every" -> n_Integer } ] :=
    If[ Mod[ $publisherTicks, n ] === 0, acpIsolated @ f[ ] ];
runHousekeeping // endDefinition;


(* The pump keeps running while there are dirty symbols, running turns, or open ACP connections
   (housekeeping such as the window-closed sweeper needs to run while a connection exists), while one-shot processes run
   (Git.wl's runner: git, and the remote runs of Remote.wl, also those that drain), while a remote folder picker
   lists (FolderPicker.wl), and while MCP tool calls wait in MCP.wl's queue or its server runs: a window without a
   connection would otherwise stop the pump, and the picker's housekeeping (the fallback for a lost listing) or MCP.wl's
   (the queue's watchdog, which triggers a queue whose drain was dropped again, and the stop of an idle server) would
   never run. *)
publisherNeededQ // beginDefinition;

publisherNeededQ[ ] := Or[
    Length @ $dirty > 0,
    TrueQ @ acpBackgroundRunsQ[ ],
    TrueQ @ acpMCPPendingQ[ ],
    AnyTrue[ Values @ $acpWindows, publisherNeededQ ]
];

publisherNeededQ[ window_Association ] := Or[
    MemberQ[ { "Connecting", "Running", "Restoring" }, Lookup[ window, "Status" ] ],
    ! MatchQ[ Lookup[ window, "Connection", None ], None | _Missing ],
    Lookup[ Replace[ Lookup[ window, "FolderPicker", None ], Except[ _Association ] -> <| |> ], "Status", None ] === "Loading"
];

publisherNeededQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRegisterHousekeeping*)

(* Registers a zero-argument function `f` that is called (isolated) every `n` publication ticks (0.2 s each) while the
   pump task runs. *)
acpRegisterHousekeeping // beginDefinition;

acpRegisterHousekeeping[ name_String, f_, n_Integer? Positive ] := (
    $housekeeping[ name ] = <| "Function" -> f, "Every" -> n |>;
    name
);

acpRegisterHousekeeping // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Opener State*)

(* Open/closed state of openers in live views. Keys are { turnID, key } (or any list starting with the turn ID). *)
acpOpenQ // beginDefinition;
acpOpenQ[ id_String, key_, default_ ] := TrueQ @ Lookup[ $acpOpen, Key @ { id, key }, default ];
acpOpenQ // endDefinition;

acpToggleOpen // beginDefinition;

acpToggleOpen[ id_String, key_, default_ ] := Module[ { new },
    new = PreemptProtect[ $acpOpen[ { id, key } ] = ! acpOpenQ[ id, key, default ] ];
    PreemptProtect[ $dirty[ { "Entity", id, key } ] = True; $dirty[ { "Layout", id } ] = True ];
    acpPublish[ ];
    new
];

acpToggleOpen // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Isolation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpIsolated*)

(* Every asynchronous or preemptive ACP entry point runs inside acpIsolated (rule R3 in docs/acp-window.md):
     * Catch[..., _] is the outermost boundary, so nothing thrown by ACP code can unwind an evaluation it preempted
       (e.g. a Notebook Assistant chat running inside catchTop).
     * AbortProtect defers user aborts until ACP state updates are complete.
     * Chatbook chat globals are Blocked so ACP code never sees (or modifies) the state of a concurrent chat.
       $catching is True, so Chatbook's throwFailure/throwInternalFailure throw to our Catch instead of returning.
     * Messages are vetoed and recorded in the ACP debug log.
   The value of a failed evaluation is a Failure["ACPInternal", ...]. *)
acpIsolated // beginDefinition;
acpIsolated // Attributes = { HoldFirst };
acpIsolated[ eval_ ] := isolatedCatch @ AbortProtect @ isolatedBlock @ eval;
acpIsolated // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpIsolatedAbortable*)

(* Like acpIsolated, but a user abort (Alt+.) is not deferred: it ends the evaluation. Only for main link evaluations
   that run code the user must be able to abort, such as the MCP tool calls of MCP.wl's drain, which runs as a queued
   button evaluation. *)
acpIsolatedAbortable // beginDefinition;
acpIsolatedAbortable // Attributes = { HoldFirst };
acpIsolatedAbortable[ eval_ ] := isolatedCatch @ isolatedBlock @ eval;
acpIsolatedAbortable // endDefinition;


(* Catch[ expr, _, f ] only catches tagged throws, so an outer untagged Catch is needed as well. `normal` tells a regular
   result (or a handled tagged throw) apart from the value of an untagged Throw. *)
isolatedCatch // beginDefinition;
isolatedCatch // Attributes = { HoldFirst };

isolatedCatch[ eval_ ] := Module[ { normal = False, result },
    result = Catch @ Catch[
        With[ { r = eval }, normal = True; r ],
        _,
        (normal = True; isolatedFailure[ #1, #2 ]) &
    ];
    If[ TrueQ @ normal, result, isolatedFailure[ result, None ] ]
];

isolatedCatch // endDefinition;


isolatedBlock // beginDefinition;
isolatedBlock // Attributes = { HoldFirst };

isolatedBlock[ eval_ ] := Block[
    {
        $catching                     = True,
        $chatState                    = False,
        $ChatHandlerData              = <| |>,
        $WorkspaceChat                = True,
        $SidebarChat                  = False,
        $InlineChat                   = False,
        $AutomaticAssistance          = False,
        $thinkingStart                = None,
        $thinkingEnd                  = None,
        $customToolFormatter          = None,
        $openToolCallBoxes            = Automatic,
        $toolCallCount                = 0,
        $receivedToolCall             = False,
        $progressContainer            = None,
        $currentSettingsCache         = None,
        $absoluteCurrentSettingsCache = None,
        $dynamicText                  = False
    },
    Internal`InheritedBlock[ { $evaluationCell, $evaluationNotebook },
        Internal`HandlerBlock[ { "Message.Veto", vetoMessage }, eval ]
    ]
];

isolatedBlock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpCatchAll*)

(* acpCatchAll[ eval ] gives the value of eval, or $Failed if eval throws (tagged or untagged Throw, including Chatbook's
   throwFailure/throwInternalFailure when $catching is True). acpCatchAll[ eval, f ] gives f[ value, tag ] instead (tag is
   None for an untagged Throw). Unlike acpIsolated it does not Block anything (e.g. $dynamicText), veto messages or
   defer aborts, so it can be used inside code that relies on those. *)
acpCatchAll // beginDefinition;
acpCatchAll // Attributes = { HoldFirst };

acpCatchAll[ eval_ ] := acpCatchAll[ eval, $Failed & ];

acpCatchAll[ eval_, f_ ] := Module[ { normal = False, tagged = False, result },
    result = Catch @ Catch[
        With[ { r = eval }, normal = True; r ],
        _,
        (tagged = True; f[ #1, #2 ]) &
    ];
    Which[
        TrueQ @ normal, result,
        TrueQ @ tagged, result,
        True          , f[ result, None ]
    ]
];

acpCatchAll // endDefinition;


vetoMessage // beginDefinition;
(* The second part of the message info is True when the message would actually be printed (i.e. it is not Off). *)
vetoMessage[ msg_ ] := (If[ TrueQ @ Quiet @ msg[[ 2 ]], acpLog[ "Message", msg ] ]; False);
vetoMessage // endDefinition;


isolatedFailure // beginDefinition;

isolatedFailure[ value_, tag_ ] := (
    acpLog[ "Uncaught", <| "Value" -> value, "Tag" -> tag |> ];
    Failure[ "ACPInternal", <| "MessageTemplate" -> "Internal error in ACP code.", "Value" -> value, "Tag" -> tag |> ]
);

isolatedFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSchedule*)

(* Deferred evaluation: queues `eval` for the pump task, which evaluates it (inside acpIsolated) once at least `delay`
   has passed, in the order of due time and then of scheduling. Never one-shot ScheduledTasks: several of them coming
   due together can deadlock the kernel, and {Now} ones are silently dropped under load. *)
acpSchedule // beginDefinition;
acpSchedule // Attributes = { HoldFirst };

acpSchedule[ eval_ ] := acpSchedule[ eval, $acpScheduleDelay ];

acpSchedule[ eval_, delay_Quantity ] := With[ { due = SessionTime[ ] + delaySeconds @ delay },
    PreemptProtect @ AppendTo[ $scheduled, { due, ++$scheduleCount, HoldComplete @ eval } ];
    acpEnsurePublisher[ ];
    Null
];

acpSchedule // endDefinition;


(* Avoids the units framework for the usual units: acpSchedule is called in reader handlers. *)
delaySeconds // beginDefinition;
delaySeconds[ Quantity[ n_? NumericQ, "Milliseconds" ] ] := N[ n / 1000 ];
delaySeconds[ Quantity[ n_? NumericQ, "Seconds" ] ] := N @ n;
delaySeconds[ q_Quantity ] := N @ QuantityMagnitude @ UnitConvert[ q, "Seconds" ];
delaySeconds // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpLog*)
acpLog // beginDefinition;

(* PreemptProtect: acpLog also runs on the main link (MCP.wl's drain), where a preemptive evaluation that logs could
   otherwise come between the truncation and the append and lose entries *)
acpLog[ where_String, data_ ] := (
    PreemptProtect[
        If[ Internal`BagLength @ $acpDebugLog >= $acpMaxDebugLogLength,
            $acpDebugLog = Internal`Bag @ Take[ Internal`BagPart[ $acpDebugLog, All ], -Quotient[ $acpMaxDebugLogLength, 2 ] ]
        ];
        Internal`StuffBag[ $acpDebugLog, <| "Time" -> AbsoluteTime[ ], "Where" -> where, "Data" -> data |> ]
    ];
    Null
);

acpLog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ACPLink*)

(* ACPLink is an optional dependency. It is loaded on demand the first time an ACP window connects. For development,
   the environment variable ACPLINK_DIRECTORY may point to an ACPLink paclet directory (the one containing
   PacletInfo.wl). Its public symbols live in System`, so they are only referenced through acpLink["name"] to avoid
   creating them in kernels that never use ACP. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpLinkAvailableQ*)
acpLinkAvailableQ // beginDefinition;
acpLinkAvailableQ[ ] := TrueQ @ $acpLinkLoaded || findACPLink[ ] =!= None;
acpLinkAvailableQ // endDefinition;


findACPLink // beginDefinition;

findACPLink[ ] := Module[ { dir },
    If[ PacletFind[ "ACPLink" ] =!= { }, Return[ First @ PacletFind[ "ACPLink" ], Module ] ];
    dir = Environment[ "ACPLINK_DIRECTORY" ];
    If[ StringQ @ dir && FileExistsQ @ FileNameJoin @ { dir, "PacletInfo.wl" },
        Quiet @ PacletDirectoryLoad @ dir;
        If[ PacletFind[ "ACPLink" ] =!= { }, Return[ First @ PacletFind[ "ACPLink" ], Module ] ]
    ];
    None
];

findACPLink // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpLoadACPLink*)

(* Returns True or a Failure (codes "ACPLinkMissing" / "ACPLinkTooOld"); never throws. *)
$acpLinkLoaded = False;

(* Called about once a second per connected window (connection liveness checks), so the loaded case must be cheap.
   The check is in the body: a conditional definition would never be used, since the unconditional f[] definition of
   loadACPLink0 would come first. *)
acpLoadACPLink // beginDefinition;
acpLoadACPLink[ ] := If[ TrueQ @ $acpLinkLoaded, True, loadACPLink0[ ] ];
acpLoadACPLink // endDefinition;


loadACPLink0 // beginDefinition;

loadACPLink0[ ] := Catch @ Module[ { paclet, options },
    paclet = findACPLink[ ];
    If[ paclet === None,
        Throw @ Failure[ "ACPLinkMissing", <|
            "MessageTemplate" -> "The ACPLink paclet is required for agent chats but is not installed."
        |> ]
    ];
    If[ ! MemberQ[ $Packages, "ACPLink`" ], Quiet @ Needs[ "ACPLink`" ] ];
    options = Quiet @ Keys @ Options @ Symbol[ "System`OpenACPConnection" ];
    If[ ! MemberQ[ options, $acpMinimumACPLinkOption ],
        Throw @ Failure[ "ACPLinkTooOld", <|
            "MessageTemplate"   -> "The installed ACPLink paclet (`1`) is too old for agent chats.",
            "MessageParameters" -> { paclet[ "Version" ] }
        |> ]
    ];
    $acpLinkLoaded = True
];

loadACPLink0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpLink*)

(* acpLink["OpenACPConnection"] gives System`OpenACPConnection (after acpLoadACPLink[] succeeded). *)
acpLink // beginDefinition;
acpLink[ name_String ] := Symbol[ "System`" <> name ];
acpLink // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Front End Flags*)

(* UI flags stored in the window notebook's TaggingRules (rule R8 in docs/acp-window.md): they survive kernel quits and input field
   re-attachment, and the front end can read them without a kernel round trip. *)
acpFE // beginDefinition;
acpFE[ nbo_NotebookObject, key_String ] := acpFE[ nbo, key, Missing[ "NotSet" ] ];
acpFE[ nbo_NotebookObject, key_String, default_ ] := Replace[
    Quiet @ CurrentValue[ nbo, { TaggingRules, "ACP", key } ],
    Inherited | $Failed | _Missing :> default
];
acpFE // endDefinition;

acpFESet // beginDefinition;
acpFESet[ nbo_NotebookObject, key_String, value_ ] := (Quiet[ CurrentValue[ nbo, { TaggingRules, "ACP", key } ] = value ]; value);
acpFESet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*acpCheckSession*)

(* Detects a kernel restart for a window (the TaggingRules owner session differs from $SessionID) and resets
   front end flags. Kernel-side records of the old session are gone anyway; orphaned live output cells are replaced
   by acpMarkOrphanCells (UI.wl), which also rebuilds the toolbar and the input field. The window record, with the
   change symbols those views track, is rebuilt first, here: the rebuilt views then show the window's state at once and
   track symbols that were created in this evaluation (an entry point, never the toolbar's DestroyAfterEvaluation
   Dynamic, whose new symbols the front end would not track). Returns True if the window was already owned by this
   kernel session. *)
acpCheckSession // beginDefinition;

acpCheckSession[ nbo_NotebookObject ] := Module[ { owner },
    owner = acpFE[ nbo, "KernelSessionID", None ];
    If[ owner === $SessionID,
        True,
        acpFESet[ nbo, "KernelSessionID", $SessionID ];
        acpFESet[ nbo, "Busy", False ];
        If[ owner =!= None,
            acpLog[ "KernelRestart", <| "Notebook" -> nbo, "PreviousSession" -> owner |> ];
            acpEnsureWindowRecord @ nbo;
            acpMarkOrphanCells @ nbo
        ];
        False
    ]
];

acpCheckSession // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
