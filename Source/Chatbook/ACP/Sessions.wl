(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`Sessions`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];
Needs[ "Wolfram`Chatbook`ACP`Common`"       ];

(* Sessions (see docs/acp-window.md, "Sessions"): the agent's saved sessions, grouped by project folder, for the Sessions
   window, and the actions on them: restore a session in the ACP window (with its history), start a new session in a
   folder, delete a session.

   The protocol requests (session/list, session/load, session/delete) are sent by Connection.wl, on the window's own
   connection, with "cb-" string IDs; their response continuations call the handlers here. How this follows the runtime
   rules (R1-R8 in docs/acp-window.md, "Threading rules"):
   * Nothing waits for the agent (R1). Listing pages, the next page and the completion are separate steps: the reader
     handler only stores a page (kernel state) and schedules the next page or the completion through the pump (R2, R5).
   * Replayed updates of a session that is being loaded are appended to an accumulator in the window record ("Restore")
     by the reader handler; the turns are built and written in time-boxed pump steps (acpRestoreWriteStep), only the
     last $acpReplayTurnsShown of them.
   * All state is in the window record ("Sessions", "Restore", "PendingRestore"), changed with acpWindowUpdate (R4).
   * Housekeeping ("ACPSessions") lists again when a listing is wanted (debounced), and is the fallback for stuck
     listings and restores (R5).
   * Text from the agent (session titles, folders, IDs) never becomes boxes unneutralized (acpNeutralizeLinearSyntax),
     is never interpreted (no ToExpression), and IDs are opaque strings. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$acpSessionListMaxPages   = 20;         (* session/list pages per listing (OpenCode: 100 sessions per page) *)
$acpReplayMaxUpdates      = 20000;      (* replayed updates kept per restore (the newest) *)
$acpReplayMaxBytes        = 32 * 2^20;  (* ... and bytes (ByteCount) *)
$acpReplayChunkSize       = 256;        (* updates per accumulator chunk *)
$acpReplayTurnsShown      = 30;         (* turns of a restored session that are written *)
$acpRestoreStepTime       = 0.15;       (* seconds of work per step of writing a restored session *)
$acpRestoreStepRetry      = 2;          (* seconds without a step after which housekeeping schedules one again *)
$acpRestoreWriteTimeout   = 60;         (* seconds without a step after which housekeeping ends the restore *)
$acpSessionsRecheckDelay  = 10;         (* seconds after a turn ended for a second listing (titles are made later) *)
$acpSessionsListGrace     = 35;         (* seconds after which a listing without progress is given up *)
$acpSessionTitleMaxLength = 500;
$acpUnusedSessionGrace    = 10;         (* seconds after its creation within which a session counts as never used *)
$sessionsHousekeepingTicks = 2;         (* 0.4 s *)

(* The Sessions window *)
$acpSessionsWindowWidth  := $acpSessionsWindowWidth = Switch[ $OperatingSystem, "MacOSX", 375, _, 300 ]; (* at 0.85 *)
$sessionsTitleLength      = 40;         (* characters of a session title shown in a row (the tooltip has all) *)
$sessionsNameLength       = 30;         (* characters of a folder name shown in a project row *)
$sessionsDeleteArmDelay   = 0.4;        (* seconds before the Delete button of a confirmation accepts clicks *)
$sessionsPageSize         = 25;         (* sessions of an open project shown at first, and more per "Show more" *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Strings*)

(* English defaults for the strings of this file (see acpLabel in Transcript.wl). Every key must also be in the .tr
   files as "ACP" <> key (checked by Tests/ACPWindow.wlt). Strings made in reader handlers are in $acpConnectionStrings
   (Agents.wl). *)
$acpSessionsStrings = <|
    "ReplayEarlierTurnsOne"      -> "1 earlier message is not shown.",
    "ReplayEarlierTurns"         -> "`n` earlier messages are not shown.",
    "NoticeSessionFolderMissing" -> "The folder of this session no longer exists: `path`",
    "SessionsBusyRunning"        -> "Wait for the current turn to finish",
    "SessionsBusyPermission"     -> "Answer the pending approval request first",
    "SessionsBusyConnecting"     -> "Wait until `agent` is connected",
    "SessionsBusyRestoring"      -> "Restoring\[Ellipsis]",
    "SessionsButtonTooltip"      -> "Sessions",
    "SessionsWindowTitle"        -> "Sessions",
    "SessionsTitle"              -> "Sessions",
    "SessionsRefresh"            -> "Refresh the list",
    "SessionsLoading"            -> "Loading sessions\[Ellipsis]",
    "SessionsNoProject"          -> "Choose a project folder to see sessions",
    "SessionsNotConnected"       -> "Sessions are listed when `agent` is connected",
    "SessionsUnsupported"        -> "`agent` can't list sessions",
    "SessionsEmpty"              -> "No sessions yet",
    "SessionsUntitled"           -> "Untitled session",
    "SessionsNewSession"         -> "New session",
    "SessionsNewHere"            -> "New session in this folder",
    "SessionsOpenFolder"         -> "Open the folder",
    "SessionsFolderMissing"      -> "This folder no longer exists",
    "SessionsCurrent"            -> "Shown in the agent window",
    "SessionsLoadUnsupported"    -> "`agent` can't open saved sessions",
    "SessionsDeleteTooltip"      -> "Delete this session",
    "SessionsDeleteConfirm"      -> "Delete this session?",
    "SessionsDelete"             -> "Delete",
    "SessionsCancel"             -> "Cancel",
    "SessionsDeleting"           -> "Deleting\[Ellipsis]",
    "SessionsRestoring"          -> "Loading\[Ellipsis]",
    "SessionsDeleteUnavailable"  -> "This session can't be deleted now.",
    "SessionsUpdated"            -> "Updated `time`",
    "SessionsTimeNow"            -> "now",
    "SessionsTimeMinutes"        -> "`n`m",
    "SessionsTimeHours"          -> "`n`h",
    "SessionsTimeDays"           -> "`n`d",
    "SessionsShowMore"           -> "Show `n` more"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Stores*)

(* Write jobs of restored sessions (see acpRestoreWriteStep): nbo -> <| "Token", "Updates", "Ranges", "Next", ... |>.
   Kept out of the window record, which is copied on every update. *)
If[ ! AssociationQ @ $restoreJobs, $restoreJobs = <| |> ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sessions Store*)

(* The window record's "Sessions" key (missing until the first listing is requested; acpSessionsOf fills in the
   defaults):
     "Status"    -> "Idle" (not listed yet) | "Listing" | "Ready" | "Error" | "Unsupported" (the agent doesn't
                    advertise sessionCapabilities.list) | "NotConnected" (the window has no connection)
     "Items"     -> the sessions of the last complete listing, newest first:
                    <| "SessionID", "Cwd" (both as the agent sent them: pass them unchanged to the actions, never make
                    boxes of them without acpNeutralizeLinearSyntax), "Title" (neutralized, or None), "UpdatedAt"
                    (AbsoluteTime or None), "Hidden" (never-used or child session) |>
     "ListedAt"  -> AbsoluteTime of the last complete listing, or None
     "Error"     -> None | <| "Code", "Message" |> of the last failed listing
     "Stale"     -> True if a listing is wanted (housekeeping lists while "Open")
     "RecheckAt" -> AbsoluteTime of a second listing after a turn ended, or None
     "Open"      -> True while a Sessions window is open for the ACP window (listings only happen then)
     "Notice"    -> None | String: an error of the last delete
     "Deleting"  -> <| session ID -> connection |>: outstanding session/delete requests, with the connection they were
                    sent on (housekeeping drops those of an earlier connection: a disconnect drops their requests)
     "Minute"    -> Floor[AbsoluteTime[] / 60], updated by housekeeping while "Open" (relative times re-render)
   and, while a listing runs: "Token", "Partial" (raw rows), "Pages", "PageAt", "Connection". The Sessions window keeps
   its own state here too (see "Sessions Window"):
     "Expanded"      -> <| project key -> True|False |>: projects the user opened or closed (the others are open if
                        they are the window's project)
     "ConfirmDelete" -> None | <| "SessionID", "ArmAt" |>: the session whose row asks "Delete this session?"; its
                        Delete button works from ArmAt on
     "Shown"         -> <| project key -> n |>: how many sessions of a project are shown (default $sessionsPageSize) *)
$sessionsDefaults = <|
    "Status"        -> "Idle",
    "Items"         -> { },
    "ListedAt"      -> None,
    "Error"         -> None,
    "Stale"         -> False,
    "RecheckAt"     -> None,
    "Open"          -> False,
    "Notice"        -> None,
    "Deleting"      -> <| |>,
    "Minute"        -> None,
    "Expanded"      -> <| |>,
    "ConfirmDelete" -> None,
    "Shown"         -> <| |>,
    "Token"         -> None,
    "Partial"       -> { },
    "Pages"         -> 0,
    "PageAt"        -> None,
    "Connection"    -> None
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionsOf*)
acpSessionsOf // beginDefinition;
acpSessionsOf[ window_Association ] := Join[ $sessionsDefaults, Replace[ Lookup[ window, "Sessions", <| |> ], Except[ _Association ] -> <| |> ] ];
acpSessionsOf[ nbo_NotebookObject ] := acpSessionsOf @ Replace[ acpWindowGet @ nbo, Except[ _Association ] -> <| |> ];
acpSessionsOf[ _ ] := $sessionsDefaults;
acpSessionsOf // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sessionsUpdate*)

(* Applies f[store, window] to the store of an existing window record (never creates a record). f gives the new store;
   anything else leaves the record unchanged (and does not mark the window dirty). Safe in reader handlers. *)
sessionsUpdate // beginDefinition;

sessionsUpdate[ nbo_NotebookObject, f_ ] := acpWindowUpdate[
    nbo,
    Function[ w,
        If[ KeyExistsQ[ w, "Status" ],
            With[ { new = f[ acpSessionsOf @ w, w ] }, If[ AssociationQ @ new, <| w, "Sessions" -> new |>, Missing[ "Unchanged" ] ] ],
            Missing[ "NotFound" ]
        ]
    ]
];

sessionsUpdate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionsSet*)

(* Merges keys into the store (e.g. UI state of the Sessions window). Gives the new window record or a Missing. *)
acpSessionsSet // beginDefinition;
acpSessionsSet[ nbo_NotebookObject, key_String, value_ ] := acpSessionsSet[ nbo, <| key -> value |> ];
acpSessionsSet[ nbo_NotebookObject, rules: _Association | { (_Rule|_RuleDelayed)... } ] := sessionsUpdate[ nbo, Join[ #1, Association @ rules ] & ];
acpSessionsSet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deletingOf*)

(* The outstanding deletes of a store: <| session ID -> connection |> *)
deletingOf // beginDefinition;
deletingOf[ store_Association ] := Replace[ Lookup[ store, "Deleting", <| |> ], Except[ _Association ] -> <| |> ];
deletingOf // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Window record helpers*)
windowSet // beginDefinition;

(* acpWindowSet for existing records only *)
windowSet[ nbo_NotebookObject, rules_Association ] := acpWindowUpdate[
    nbo,
    Function[ w, If[ KeyExistsQ[ w, "Status" ], Join[ w, rules ], Missing[ "NotFound" ] ] ]
];

windowSet // endDefinition;


existingWindow // beginDefinition;
existingWindow[ nbo_NotebookObject ] := Replace[ acpWindowGet @ nbo, Except[ _Association? (KeyExistsQ[ "Status" ]) ] -> None ];
existingWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Capabilities and Busy State*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionsCapabilities*)

(* What the window's agent advertised (all False before the initialize response): load is the top-level loadSession
   boolean of ACP v1, the others are under sessionCapabilities. *)
acpSessionsCapabilities // beginDefinition;

acpSessionsCapabilities[ window_Association ] := With[ { caps = Lookup[ window, "Capabilities", None ] },
    <|
        "List"   -> sessionCapabilityQ[ caps, "list" ],
        "Load"   -> MatchQ[ caps, KeyValuePattern[ "loadSession" -> True ] ],
        "Delete" -> sessionCapabilityQ[ caps, "delete" ],
        "Close"  -> sessionCapabilityQ[ caps, "close" ],
        "Resume" -> sessionCapabilityQ[ caps, "resume" ]
    |>
];

acpSessionsCapabilities[ _ ] := <| "List" -> False, "Load" -> False, "Delete" -> False, "Close" -> False, "Resume" -> False |>;

acpSessionsCapabilities // endDefinition;


sessionCapabilityQ // beginDefinition;
sessionCapabilityQ[ caps_, name_String ] := MatchQ[ caps, KeyValuePattern[ "sessionCapabilities" -> KeyValuePattern[ name -> _Association ] ] ];
sessionCapabilityQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRestoringQ*)

(* A session is being restored: loaded (or about to be, after the connection is ready) or written. Blocks Send (the
   prompt is queued), the toolbar's New, folder and config menus, and the Sessions window's actions. *)
acpRestoringQ // beginDefinition;

acpRestoringQ[ window_Association ] := Or[
    Lookup[ window, "Status", None ] === "Restoring",
    AssociationQ @ Lookup[ window, "Restore", None ],
    AssociationQ @ Lookup[ window, "PendingRestore", None ]
];

acpRestoringQ[ _ ] := False;

acpRestoringQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionsBusyState*)

(* Why the Sessions window's actions (restore, new in folder, delete) are disabled: None (they are not), "Restoring",
   "Permission" (an approval is pending), "Running" (a turn runs, also while it is queued for the connection or being
   finalized) or "Connecting". *)
acpSessionsBusyState // beginDefinition;

acpSessionsBusyState[ window_Association ] := Which[
    acpRestoringQ @ window,
        "Restoring",
    Length @ Replace[ Lookup[ window, "PendingPermissions", <| |> ], Except[ _Association ] -> <| |> ] > 0,
        "Permission",
    StringQ @ Lookup[ window, "CurrentTurn", None ],
        "Running",
    StringQ @ Lookup[ window, "ConnectToken", None ] || Lookup[ window, "Status", None ] === "Connecting",
        "Connecting",
    True,
        None
];

acpSessionsBusyState[ _ ] := None;

acpSessionsBusyState // endDefinition;


(* The tooltip of disabled actions *)
acpSessionsBusyLabel // beginDefinition;

acpSessionsBusyLabel[ window_Association ] := Replace[
    acpSessionsBusyState @ window,
    {
        "Restoring"  :> acpLabel[ "SessionsBusyRestoring" ],
        "Permission" :> acpLabel[ "SessionsBusyPermission" ],
        "Running"    :> acpLabel[ "SessionsBusyRunning" ],
        "Connecting" :> acpLabel[ "SessionsBusyConnecting", <| "agent" -> agentName @ window |> ],
        _            -> None
    }
];

acpSessionsBusyLabel[ _ ] := None;

acpSessionsBusyLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*currentSessionIDs*)

(* The sessions the window shows or is about to show: never hidden, never deleted *)
currentSessionIDs // beginDefinition;

currentSessionIDs[ window_Association ] := DeleteDuplicates @ Cases[
    {
        Lookup[ window, "SessionID", None ],
        Lookup[ Replace[ Lookup[ window, "Restore", None ], Except[ _Association ] -> <| |> ], "SessionID", None ],
        Lookup[ Replace[ Lookup[ window, "PendingRestore", None ], Except[ _Association ] -> <| |> ], "SessionID", None ]
    },
    _String
];

currentSessionIDs[ _ ] := { };

currentSessionIDs // endDefinition;


(* The session the transcript belongs to: the current one, or (without a connection) the one that would be resumed *)
activeSessionID // beginDefinition;

activeSessionID[ window_Association ] := Replace[
    Lookup[ window, "SessionID", None ],
    Except[ _String ] :> Replace[ Lookup[ window, "ResumableSessionID", None ], Except[ _String ] -> None ]
];

activeSessionID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Listing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Triggers*)

(* A Sessions window was opened for the ACP window: listings happen while it is open (it lists right away, or once the
   connection is ready). A listing that housekeeping started meanwhile (it may run between the two steps here) is
   enough: it is not repeated. Safe in any context that may write to the connection (not in DestroyAfterEvaluation
   boxes). *)
acpSessionsOpened // beginDefinition;

acpSessionsOpened[ nbo_NotebookObject ] := (
    sessionsUpdate[ nbo, <| #1, "Open" -> True, "Notice" -> None |> & ];
    acpSessionsList[ nbo, False ]
);

acpSessionsOpened // endDefinition;


acpSessionsClosed // beginDefinition;
acpSessionsClosed[ nbo_NotebookObject ] := (sessionsUpdate[ nbo, <| #1, "Open" -> False, "Notice" -> None |> & ]; Null);
acpSessionsClosed // endDefinition;


(* The Refresh button: lists now (or again after the running listing; acpSessionsList marks the store stale then) *)
acpSessionsRefresh // beginDefinition;

acpSessionsRefresh[ nbo_NotebookObject ] := (
    acpCheckSession @ nbo;
    acpEnsureWindowRecord @ nbo;
    sessionsUpdate[ nbo, <| #1, "Notice" -> None |> & ];
    With[ { status = acpSessionsList @ nbo }, acpPublish[ ]; status ]
);

acpSessionsRefresh // endDefinition;


(* A listing is wanted (connection ready, session restored/created/deleted). Kernel state only: safe in reader
   handlers. Housekeeping lists while the Sessions window is open. *)
acpSessionsMarkStale // beginDefinition;

acpSessionsMarkStale[ nbo_NotebookObject ] := (
    sessionsUpdate[ nbo, If[ TrueQ @ #1[ "Stale" ], Missing[ "Unchanged" ], <| #1, "Stale" -> True |> ] & ];
    Null
);

acpSessionsMarkStale[ _ ] := Null;

acpSessionsMarkStale // endDefinition;


(* A turn ended: list now and once more later, since OpenCode titles a new session asynchronously and never says when *)
acpSessionsNoteTurnEnd // beginDefinition;

acpSessionsNoteTurnEnd[ nbo_NotebookObject ] := (
    sessionsUpdate[ nbo, <| #1, "Stale" -> True, "RecheckAt" -> AbsoluteTime[ ] + $acpSessionsRecheckDelay |> & ];
    Null
);

acpSessionsNoteTurnEnd[ _ ] := Null;

acpSessionsNoteTurnEnd // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionsList*)

(* Starts a listing of all sessions (session/list without cwd, so every project folder; later pages with the cursor).
   Gives the store's status: "Listing", "NotConnected", "Idle" (the connection is not ready yet: it lists then),
   "Unsupported", or Missing["NotFound"]. A listing that runs already is not started twice: the store is marked stale
   (unless again is False), so housekeeping lists again afterwards. *)
acpSessionsList // beginDefinition;

acpSessionsList[ nbo_NotebookObject ] := acpSessionsList[ nbo, True ];

acpSessionsList[ nbo_NotebookObject, again_ ] := Catch @ Module[ { window, store, conn, now, token, sent },
    window = existingWindow @ nbo;
    If[ ! AssociationQ @ window, Throw @ Missing[ "NotFound" ] ];
    store = acpSessionsOf @ window;
    conn  = Lookup[ window, "Connection", None ];
    now   = AbsoluteTime[ ];

    Which[
        ! acpConnectionQ @ conn && ! StringQ @ Lookup[ window, "ConnectToken", None ],
            sessionsUpdate[ nbo, <| #1, "Status" -> "NotConnected", "Stale" -> True, "Token" -> None, "Partial" -> { } |> & ];
            Throw[ "NotConnected" ],
        ! acpConnectionQ @ conn || ! AssociationQ @ Lookup[ window, "Capabilities", None ],
            (* connecting: listed once the connection is ready (Connection.wl's becomeReady marks the store stale) *)
            sessionsUpdate[ nbo, <| #1, "Status" -> If[ #1[ "Status" ] === "Listing", "Idle", #1[ "Status" ] ], "Stale" -> True, "Token" -> None |> & ];
            Throw[ "Idle" ],
        ! acpSessionsCapabilities[ window ][ "List" ],
            sessionsUpdate[ nbo, <| #1, "Status" -> "Unsupported", "Stale" -> False, "Token" -> None, "Partial" -> { } |> & ];
            Throw[ "Unsupported" ],
        listingQ[ store, window, now ],
            If[ TrueQ @ again, sessionsUpdate[ nbo, <| #1, "Stale" -> True |> & ] ];
            Throw[ "Listing" ]
    ];

    token = CreateUUID[ "sessions-" ];
    sessionsUpdate[
        nbo,
        <|
            #1,
            "Status"     -> "Listing",
            "Token"      -> token,
            "Stale"      -> False,
            "Partial"    -> { },
            "Pages"      -> 0,
            "PageAt"     -> now,
            "Connection" -> conn
        |> &
    ];
    sent = acpSendSessionList[ nbo, conn, token, None, 1 ];
    If[ FailureQ @ sent,
        acpSessionsListFailed[ nbo, token, <| "Code" -> "SendFailed", "Message" -> acpConnectionLabel[ "ErrorSendFailed", <| "agent" -> agentName @ window |> ] |> ]
    ];
    "Listing"
];

acpSessionsList // endDefinition;


(* A listing of the window's current connection is running (and still making progress) *)
listingQ // beginDefinition;

listingQ[ store_Association, window_Association, now_ ] := And[
    store[ "Status" ] === "Listing",
    StringQ @ store[ "Token" ],
    store[ "Connection" ] === Lookup[ window, "Connection", None ],
    NumberQ @ store[ "PageAt" ],
    now - store[ "PageAt" ] < $acpSessionsListGrace
];

listingQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionsOnListResponse*)

(* The response to a session/list page (reader handler: kernel state only). The page's raw rows are stored; the next
   page (if there is a cursor, the page was not empty and fewer than $acpSessionListMaxPages pages were listed) or the
   completion is scheduled for the pump. OpenCode sends a cursor on the last non-empty page too, so the listing ends
   with an empty page. *)
acpSessionsOnListResponse // beginDefinition;

acpSessionsOnListResponse[ nbo_NotebookObject, data_Association, resp_Association, time_ ] := Module[
    { token, page, result, rows, cursor, current = False },

    token = Lookup[ data, "Token", None ];
    page  = Replace[ Lookup[ data, "Page", 1 ], Except[ _Integer ] -> 1 ];

    If[ TrueQ @ resp[ "Error" ],
        acpSessionsListFailed[ nbo, token, <| "Code" -> resp[ "Code" ], "Message" -> agentMessage[ resp[ "Message" ], "SessionsListFailed" ] |> ];
        Return[ Null, Module ]
    ];

    result = Replace[ resp[ "Result" ], Except[ _Association ] -> <| |> ];
    rows   = Select[ Replace[ Lookup[ result, "sessions", { } ], Except[ _List ] -> { } ], AssociationQ ];
    cursor = Replace[ Lookup[ result, "nextCursor", None ], Except[ _String? (StringLength[ # ] > 0 &) ] -> None ];

    sessionsUpdate[
        nbo,
        Function[ { s, w },
            If[ s[ "Token" ] === token && s[ "Status" ] === "Listing",
                current = True;
                <| s, "Partial" -> Join[ s[ "Partial" ], rows ], "Pages" -> page, "PageAt" -> time |>,
                Missing[ "Stale" ]
            ]
        ]
    ];
    If[ ! current, acpLog[ "StaleSessionList", <| "Page" -> page |> ]; Return[ Null, Module ] ];

    Which[
        StringQ @ cursor && rows =!= { } && page < $acpSessionListMaxPages,
            With[ { c = cursor, p = page + 1 }, acpSchedule @ sessionsNextPage[ nbo, token, c, p ] ],
        True,
            If[ StringQ @ cursor && rows =!= { }, acpLog[ "SessionListCapped", <| "Pages" -> page |> ] ];
            acpSchedule @ sessionsFinishListing[ nbo, token ]
    ]
];

acpSessionsOnListResponse // endDefinition;


(* The next page (pump) *)
sessionsNextPage // beginDefinition;

sessionsNextPage[ nbo_NotebookObject, token_String, cursor_String, page_Integer ] := Module[ { window, store, conn, sent },
    window = existingWindow @ nbo;
    If[ ! AssociationQ @ window, Return[ Null, Module ] ];
    store = acpSessionsOf @ window;
    conn  = Lookup[ window, "Connection", None ];
    If[ store[ "Token" ] =!= token || store[ "Connection" ] =!= conn || ! acpConnectionQ @ conn, Return[ Null, Module ] ];
    sent = acpSendSessionList[ nbo, conn, token, cursor, page ];
    If[ FailureQ @ sent,
        acpSessionsListFailed[ nbo, token, <| "Code" -> "SendFailed", "Message" -> acpConnectionLabel[ "ErrorSendFailed", <| "agent" -> agentName @ window |> ] |> ]
    ]
];

sessionsNextPage // endDefinition;


(* The listing is complete (pump): the rows become items *)
sessionsFinishListing // beginDefinition;

sessionsFinishListing[ nbo_NotebookObject, token_String ] := Module[ { store, items },
    store = acpSessionsOf @ nbo;
    If[ store[ "Token" ] =!= token, Return[ Null, Module ] ];
    items = acpSessionItems @ store[ "Partial" ];
    sessionsUpdate[
        nbo,
        If[ #1[ "Token" ] === token,
            <|
                #1,
                "Status"     -> "Ready",
                "Items"      -> items,
                "ListedAt"   -> AbsoluteTime[ ],
                "Error"      -> None,
                "Token"      -> None,
                "Partial"    -> { },
                "Pages"      -> 0,
                "Connection" -> None
            |>,
            Missing[ "Stale" ]
        ] &
    ];
    acpPublish[ ];
    Null
];

sessionsFinishListing // endDefinition;


(* A listing failed (error response, timeout, write failure): error = <| "Code", "Message" |> *)
acpSessionsListFailed // beginDefinition;

acpSessionsListFailed[ nbo_NotebookObject, token_, error_Association ] := (
    acpLog[ "SessionListFailed", <| "Code" -> Lookup[ error, "Code", None ] |> ];
    sessionsUpdate[
        nbo,
        If[ #1[ "Token" ] === token,
            <|
                #1,
                "Status"     -> "Error",
                "Error"      -> KeyTake[ error, { "Code", "Message" } ],
                "Token"      -> None,
                "Partial"    -> { },
                "Pages"      -> 0,
                "Connection" -> None
            |>,
            Missing[ "Stale" ]
        ] &
    ];
    Null
);

acpSessionsListFailed // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionItems*)

(* Items from raw session/list rows: rows without a string sessionId and cwd are dropped, the first row of each ID is
   kept, newest first (rows without a time last, in the agent's order). *)
acpSessionItems // beginDefinition;

acpSessionItems[ rows_List ] := Module[ { items },
    items = DeleteDuplicatesBy[ DeleteCases[ sessionItem /@ rows, None ], #[ "SessionID" ] & ];
    (* numeric keys only: Sort orders Infinity after all numbers, but -Infinity too *)
    SortBy[
        MapIndexed[ { #1, First @ #2 } &, items ],
        { Replace[ #[[ 1, "UpdatedAt" ]], { t_? NumberQ :> -t, _ -> $lastKey } ] &, #[[ 2 ]] & }
    ][[ All, 1 ]]
];

acpSessionItems // endDefinition;

(* A sort key after every negated time *)
$lastKey = 10.0^30;


sessionItem // beginDefinition;

sessionItem[ row_Association ] := Module[ { id, cwd, title, updated },
    id    = Lookup[ row, "sessionId", None ];
    cwd   = Lookup[ row, "cwd", None ];
    If[ ! StringQ @ id || ! StringQ @ cwd || StringLength @ id === 0 || StringLength @ cwd === 0, Return[ None, Module ] ];
    title = Replace[
        Lookup[ row, "title", None ],
        {
            t_String /; StringLength @ StringTrim @ t > 0 :> acpNeutralizeLinearSyntax @ StringTake[ StringTrim @ t, UpTo[ $acpSessionTitleMaxLength ] ],
            _ -> None
        }
    ];
    updated = acpSessionTime @ Lookup[ row, "updatedAt", None ];
    <|
        "SessionID" -> id,
        "Cwd"       -> cwd,
        "Title"     -> title,
        "UpdatedAt" -> updated,
        "Hidden"    -> sessionHiddenQ[ title, updated ]
    |>
];

sessionItem[ _ ] := None;

sessionItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionTime*)

(* AbsoluteTime of an updatedAt value (ISO 8601 string, e.g. OpenCode's "2026-10-11T05:05:38.554Z"; epoch seconds or
   milliseconds), or None. FromDateString's automatic format handles the fractional seconds and "Z" ("ISODateTime" does
   not); it is only applied to strings that start like an ISO date, since it also "parses" other text. *)
acpSessionTime // beginDefinition;

acpSessionTime[ s_String ] /; StringMatchQ[ s, RegularExpression[ "\\d{4}-\\d{2}-\\d{2}([T ].*)?" ] ] :=
    Replace[ Quiet @ FromDateString @ s, { d_DateObject? DateObjectQ :> AbsoluteTime @ d, _ -> None } ];

acpSessionTime[ ms_Integer ] /; ms > 10^11 := AbsoluteTime @ FromUnixTime[ ms / 1000 ];

acpSessionTime[ t_? NumberQ ] /; t > 0 := AbsoluteTime @ FromUnixTime @ t;

acpSessionTime[ _ ] := None;

acpSessionTime // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionHiddenTitleQ*)

(* Never-used sessions keep OpenCode's fallback title "New session - <ISO time>"; subagent sessions are "Child session
   - ...". Both are hidden (except the window's current session, see acpSessionsProjects; and see sessionHiddenQ). *)
acpSessionHiddenTitleQ // beginDefinition;

acpSessionHiddenTitleQ[ title_String ] := Or[
    StringMatchQ[ title, RegularExpression[ "(?s)New session - \\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}.*" ] ],
    StringStartsQ[ title, "Child session - " ]
];

acpSessionHiddenTitleQ[ _ ] := False;

acpSessionHiddenTitleQ // endDefinition;


(* Whether a listed session is hidden. The fallback title "New session - <time of creation>" also stays if OpenCode
   could not make a title (e.g. the title model failed on every prompt): a session with that title that was updated
   more than $acpUnusedSessionGrace seconds after its creation was used, and is shown (a session that only got the
   window's model and effort after session/new is updated within a fraction of a second; a later model change alone
   also shows it). *)
sessionHiddenQ // beginDefinition;

sessionHiddenQ[ title_String, updated_ ] /; StringStartsQ[ title, "New session - " ] && acpSessionHiddenTitleQ @ title :=
    With[ { created = acpSessionTime @ StringDrop[ title, StringLength[ "New session - " ] ] },
        ! (NumberQ @ created && NumberQ @ updated && updated - created > $acpUnusedSessionGrace)
    ];

sessionHiddenQ[ title_, _ ] := acpSessionHiddenTitleQ @ title;

sessionHiddenQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionsProjects*)

(* The projects of a window's listing, for the Sessions window:
     { <| "Cwd" (as the agent sent it; the window's folder for a project without sessions), "Key" (the normalized path),
          "Name" (the folder name, neutralized), "Sessions" -> { item <| ..., "Current" -> bool |>, ... } (newest first),
          "Count", "UpdatedAt" (of the newest session, or None), "Current" (the window's project) |>, ... }
   Projects are ordered by their newest session; hidden sessions are left out (except the window's current one); the
   window's project always appears, first if it has no visible sessions. *)
acpSessionsProjects // beginDefinition;

(* The window's own sessions are never hidden: also the resumable one of a disconnected window (activeSessionID) *)
acpSessionsProjects[ window_Association ] := acpSessionsProjects[
    acpSessionsOf[ window ][ "Items" ],
    DeleteDuplicates @ Cases[ Append[ currentSessionIDs @ window, activeSessionID @ window ], _String ],
    Lookup[ window, "ProjectDirectory", None ]
];

acpSessionsProjects[ items_List, current_List, currentDir_ ] := Module[ { visible, groups, currentKey, projects },
    visible    = Select[ items, AssociationQ[ # ] && (! TrueQ @ #[ "Hidden" ] || MemberQ[ current, #[ "SessionID" ] ]) & ];
    groups     = GroupBy[ visible, sessionsPathKey @ #[ "Cwd" ] & ];
    currentKey = If[ StringQ @ currentDir, sessionsPathKey @ currentDir, None ];
    projects   = KeyValueMap[ sessionsProject[ #1, First[ #2 ][ "Cwd" ], #2, current, currentKey ] &, groups ];
    If[ StringQ @ currentKey && ! KeyExistsQ[ groups, currentKey ],
        AppendTo[ projects, sessionsProject[ currentKey, currentDir, { }, current, currentKey ] ]
    ];
    SortBy[
        MapIndexed[ { #1, First @ #2 } &, projects ],
        { Replace[ #[[ 1, "UpdatedAt" ]], { t_? NumberQ :> -t, _ -> -$lastKey } ] &, #[[ 2 ]] & }
    ][[ All, 1 ]]
];

acpSessionsProjects // endDefinition;


sessionsProject // beginDefinition;

sessionsProject[ key_String, cwd_String, sessions_List, current_List, currentKey_ ] := With[
    { times = Cases[ Lookup[ sessions, "UpdatedAt", None ], _? NumberQ ] },
    <|
        "Cwd"       -> cwd,
        "Key"       -> key,
        "Name"      -> acpNeutralizeLinearSyntax @ Replace[ FileNameTake @ key, "" -> key ],
        "Sessions"  -> (<| #, "Current" -> MemberQ[ current, #[ "SessionID" ] ] |> & /@ sessions),
        "Count"     -> Length @ sessions,
        "UpdatedAt" -> If[ times === { }, None, Max @ times ],
        "Current"   -> key === currentKey
    |>
];

sessionsProject // endDefinition;


(* Paths of the same folder compare equal: expanded, without trailing separators *)
sessionsPathKey // beginDefinition;

sessionsPathKey[ path_String ] := Module[ { expanded },
    expanded = Replace[ Quiet @ ExpandFileName @ path, Except[ _String ] -> path ];
    Replace[ StringDelete[ expanded, ("/" | "\\").. ~~ EndOfString ], "" -> expanded ]
];

sessionsPathKey[ other_ ] := other;

sessionsPathKey // endDefinition;


samePathQ // beginDefinition;
samePathQ[ a_String, b_String ] := sessionsPathKey @ a === sessionsPathKey @ b;
samePathQ[ _, _ ] := False;
samePathQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Restoring Sessions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRestoreSession*)

(* Shows a saved session in the ACP window, with its history ("RestoreSession" action):
     * same folder, connection ready: session/load on the current connection (Connection.wl's acpLoadSession); the
       transcript stays until the load succeeds; then the session that was left is closed;
     * same folder, not connected: the window reconnects (folder and transcript unchanged) and loads the session
       instead of resuming its own; if the load fails (error or timeout), it resumes its own session (or creates one);
     * another folder: the project folder changes (disconnect, clear, reconnect) and the new connection loads the
       session instead of creating one; if the load fails, it creates a new session there.
   The session's listed cwd is passed to session/load unchanged (OpenCode requires its exact directory). Refused while
   the window is busy (acpSessionsBusyState); the current session is a no-op ("Current"). *)
acpRestoreSession // beginDefinition;

acpRestoreSession[ nbo_NotebookObject, sid_String, cwd_String ] := Catch @ Module[ { window, busy, dir, sameQ, readyQ },
    window = existingWindow @ nbo;
    If[ ! AssociationQ @ window, Throw @ Missing[ "NotFound" ] ];
    If[ StringLength @ sid === 0 || StringLength @ cwd === 0, Throw @ Failure[ "InvalidSession", <| "SessionID" -> sid, "Cwd" -> cwd |> ] ];
    If[ sid === activeSessionID @ window, Throw[ "Current" ] ];

    busy = acpSessionsBusyState @ window;
    If[ busy =!= None, Throw @ Failure[ "Busy", <| "Reason" -> busy |> ] ];
    If[ AssociationQ @ Lookup[ window, "Capabilities", None ] && ! acpSessionsCapabilities[ window ][ "Load" ],
        Throw @ Failure[ "Unsupported", <| "Capability" -> "loadSession" |> ]
    ];

    dir    = Lookup[ window, "ProjectDirectory", None ];
    sameQ  = samePathQ[ cwd, dir ];
    readyQ = And[
        Lookup[ window, "Status", None ] === "Ready",
        acpConnectionQ @ Lookup[ window, "Connection", None ],
        StringQ @ Lookup[ window, "SessionID", None ]
    ];

    Which[
        sameQ && readyQ,
            acpLoadSession[ nbo, sid, cwd ],
        sameQ,
            (* config values chosen while disconnected were for the session that is left (Connection.wl's sendSessionLoad
               drops them the same way on a connected window) *)
            windowSet[ nbo, <| "PendingRestore" -> <| "SessionID" -> sid, "Cwd" -> cwd |>, "Notice" -> None, "PendingConfig" -> <| |> |> ];
            acpReconnect @ nbo,
        ! TrueQ @ Quiet @ DirectoryQ @ cwd,
            acpSetNotice[ nbo, acpLabel[ "NoticeSessionFolderMissing", <| "path" -> displayPath @ cwd |> ] ];
            Throw @ Failure[ "FolderMissing", <| "Cwd" -> cwd |> ],
        True,
            acpChangeProjectDirectory[ nbo, cwd, <| "PendingRestore" -> <| "SessionID" -> sid, "Cwd" -> cwd |> |> ]
    ];
    acpPublish[ ];
    "Restoring"
];

acpRestoreSession // endDefinition;


acpRestoreSessionAction // beginDefinition;

acpRestoreSessionAction[ nbo_NotebookObject, sid_String, cwd_String ] := (
    acpCheckSession @ nbo;
    acpEnsureWindowRecord @ nbo;
    acpRestoreSession[ nbo, sid, cwd ]
);

acpRestoreSessionAction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpNewRestore*)

(* The window record's "Restore" while a session is restored (created by Connection.wl when session/load is sent):
     "SessionID", "Cwd", "Token", "Mode" ("SameConnection": loaded on the window's connection, "Setup": loaded instead of
     a new session while connecting), "PreviousSessionID" (closed after a successful same-connection load), "Stage"
     ("Loading" while the replay arrives, "Writing" while the turns are written), "StartedAt", "LastUpdateAt" (the load
     timeout counts from here), and the replay accumulator: "Chunks" (lists of updates), "ChunkBytes", "Tail",
     "TailBytes", "Count" (updates received), "Kept", "Bytes", "Dropped" (oldest updates dropped by the caps), "Turns"
     (turns seen), "UserMessageID", "TurnHasWork". *)
acpNewRestore // beginDefinition;

acpNewRestore[ props_Association ] := With[ { now = AbsoluteTime[ ] },
    Join[
        <|
            "SessionID"         -> None,
            "Cwd"               -> None,
            "Token"             -> None,
            "Mode"              -> "SameConnection",
            "PreviousSessionID" -> None,
            "Stage"             -> "Loading",
            "StartedAt"         -> now,
            "LastUpdateAt"      -> now,
            "Chunks"            -> { },
            "ChunkBytes"        -> { },
            "Tail"              -> { },
            "TailBytes"         -> 0,
            "Count"             -> 0,
            "Kept"              -> 0,
            "Bytes"             -> 0,
            "Dropped"           -> 0,
            "Turns"             -> 0,
            "UserMessageID"     -> None,
            "TurnHasWork"       -> False
        |>,
        props
    ]
];

acpNewRestore // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRestoreAppendUpdate*)

(* A replayed update of the session being loaded (reader handler: kernel state only, append only). *)
acpRestoreAppendUpdate // beginDefinition;

acpRestoreAppendUpdate[ nbo_NotebookObject, token_String, update_Association, time_ ] := (
    acpWindowUpdate[
        nbo,
        Function[ w,
            With[ { r = Lookup[ w, "Restore", None ] },
                If[ AssociationQ @ r && r[ "Token" ] === token && r[ "Stage" ] === "Loading",
                    <| w, "Restore" -> acpReplayAppend[ r, update, time ] |>,
                    Missing[ "Stale" ]
                ]
            ]
        ]
    ];
    Null
);

acpRestoreAppendUpdate // endDefinition;


(* Appends to the accumulator (pure). Updates are collected in chunks, so an append copies at most one chunk; past the
   caps the oldest chunks are dropped (the newest turns are the ones shown). Turns are counted the way acpReplayRanges
   splits them. *)
acpReplayAppend // beginDefinition;

acpReplayAppend[ r0_Association, update_Association, time_ ] := Module[ { r = r0, size, user, mid, starts },
    size   = ByteCount @ update;
    user   = Lookup[ update, "sessionUpdate", None ] === "user_message_chunk";
    mid    = Lookup[ update, "messageId", None ];
    starts = If[ user, r[ "Count" ] === 0 || TrueQ @ r[ "TurnHasWork" ] || mid =!= r[ "UserMessageID" ], r[ "Count" ] === 0 ];

    r[ "Tail" ]          = Append[ r[ "Tail" ], update ];
    r[ "TailBytes" ]     = r[ "TailBytes" ] + size;
    r[ "Count" ]         = r[ "Count" ] + 1;
    r[ "Kept" ]          = r[ "Kept" ] + 1;
    r[ "Bytes" ]         = r[ "Bytes" ] + size;
    r[ "LastUpdateAt" ]  = time;
    r[ "Turns" ]         = r[ "Turns" ] + Boole @ starts;
    r[ "UserMessageID" ] = If[ user, mid, r[ "UserMessageID" ] ];
    r[ "TurnHasWork" ]   = If[ user, If[ starts, False, TrueQ @ r[ "TurnHasWork" ] ], True ];

    If[ Length @ r[ "Tail" ] >= $acpReplayChunkSize || r[ "TailBytes" ] >= $acpReplayMaxBytes / 16,
        r[ "Chunks" ]     = Append[ r[ "Chunks" ], r[ "Tail" ] ];
        r[ "ChunkBytes" ] = Append[ r[ "ChunkBytes" ], r[ "TailBytes" ] ];
        r[ "Tail" ]       = { };
        r[ "TailBytes" ]  = 0
    ];

    While[ (r[ "Kept" ] > $acpReplayMaxUpdates || r[ "Bytes" ] > $acpReplayMaxBytes) && r[ "Chunks" ] =!= { },
        r[ "Kept" ]       = r[ "Kept" ] - Length @ First @ r[ "Chunks" ];
        r[ "Dropped" ]    = r[ "Dropped" ] + Length @ First @ r[ "Chunks" ];
        r[ "Bytes" ]      = r[ "Bytes" ] - First @ r[ "ChunkBytes" ];
        r[ "Chunks" ]     = Rest @ r[ "Chunks" ];
        r[ "ChunkBytes" ] = Rest @ r[ "ChunkBytes" ]
    ];
    r
];

acpReplayAppend // endDefinition;


(* All updates kept by an accumulator, oldest first *)
acpReplayUpdates // beginDefinition;
acpReplayUpdates[ r_Association ] := Join[ Join @@ Replace[ Lookup[ r, "Chunks", { } ], Except[ _List ] -> { } ], Replace[ Lookup[ r, "Tail", { } ], Except[ _List ] -> { } ] ];
acpReplayUpdates // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReplayRanges*)

(* The turns of a replay as { start, end } positions. A turn starts with a user_message_chunk whose messageId differs
   from the current user message (or that follows agent output); chunks of the same user message (text, attached files)
   stay in one turn. Agent output before the first user message (e.g. after compaction) is a turn without a prompt.
   Nothing else marks the end of a turn (no stop reason, no timing). *)
acpReplayRanges // beginDefinition;

acpReplayRanges[ updates_List ] := Module[ { ranges = Internal`Bag[ ], start = None, mid = None, work = False, i = 0 },
    Do[
        i++;
        If[ Lookup[ u, "sessionUpdate", None ] === "user_message_chunk",
            With[ { m = Lookup[ u, "messageId", None ] },
                If[ start === None || work || m =!= mid,
                    If[ start =!= None, Internal`StuffBag[ ranges, { start, i - 1 } ] ];
                    start = i;
                    work  = False
                ];
                mid = m
            ],
            If[ start === None, start = i; mid = None ];
            work = True
        ],
        { u, updates }
    ];
    If[ start =!= None, Internal`StuffBag[ ranges, { start, i } ] ];
    Internal`BagPart[ ranges, All ]
];

acpReplayRanges // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReplayTurn*)

(* A finished turn record from the updates of one replayed turn (pure; the turn is never registered in $acpTurns): the
   user chunks give the prompt, everything else goes through the Transcript reducer with synthetic, increasing times
   (a replay has no timing), and the turn ends normally ("end_turn"). Tools that failed with the agent's text for a
   declined or interrupted tool call get the neutral client outcome a live turn would show. props: "ID", "Notebook",
   "SessionID", "ProjectDirectory", "AgentName", "StartTime". *)
acpReplayTurn // beginDefinition;

acpReplayTurn[ updates_List, props_Association ] := Module[ { t, turn, texts = { }, attachments = { } },
    t    = Replace[ Lookup[ props, "StartTime", None ], Except[ _? NumberQ ] :> AbsoluteTime[ ] ];
    turn = acpNewTurn @ <| props, "Prompt" -> "", "StartTime" -> t, "Status" -> "Done", "Replayed" -> True |>;
    Do[
        If[ Lookup[ u, "sessionUpdate", None ] === "user_message_chunk",
            Replace[
                replayPromptPart @ Lookup[ u, "content", None ],
                {
                    { "Text", s_String } :> AppendTo[ texts, s ],
                    { "Attachment", s_String } :> AppendTo[ attachments, s ]
                }
            ],
            t += 0.001;
            turn = Replace[ acpApplyUpdate[ turn, u, t ], { KeyValuePattern[ "Turn" -> new_Association ] :> new, _ :> turn } ]
        ],
        { u, Select[ updates, AssociationQ ] }
    ];
    turn[ "Prompt" ] = StringTrim[
        StringJoin[ texts ] <> If[ attachments === { }, "", "\n" <> StringRiffle[ ("[" <> # <> "]") & /@ attachments, "\n" ] ]
    ];
    turn = Replace[
        acpApplyTurnEnd[ turn, <| "StopReason" -> "end_turn" |>, t + 0.001 ],
        { KeyValuePattern[ "Turn" -> new_Association ] :> new, _ :> turn }
    ];
    replayClientOutcomes @ turn
];

acpReplayTurn // endDefinition;


(* { "Text", text } | { "Attachment", name } | None for an ACP content block of a user message *)
replayPromptPart // beginDefinition;
replayPromptPart[ KeyValuePattern @ { "type" -> "text", "text" -> s_String } ] := { "Text", s };
replayPromptPart[ c: KeyValuePattern[ "type" -> _String ] ] := Replace[
    SelectFirst[
        {
            Lookup[ c, "name", None ],
            Lookup[ c, "filename", None ],
            Lookup[ c, "uri", None ],
            Lookup[ Replace[ Lookup[ c, "resource", <| |> ], Except[ _Association ] -> <| |> ], "uri", None ]
        },
        StringQ[ # ] && StringLength[ # ] > 0 &,
        None
    ],
    { s_String :> { "Attachment", FileNameTake @ s }, _ -> None }
];
replayPromptPart[ _ ] := None;
replayPromptPart // endDefinition;


(* Failed tools whose output is the agent's text for a declined or interrupted call (e.g. "The user declined this tool
   call") are shown as "Declined"/"Stopped", like in the live turn (permission decisions are not replayed). *)
replayClientOutcomes // beginDefinition;

replayClientOutcomes[ turn_Association ] := Module[ { entities },
    entities = Replace[ Lookup[ turn, "Entities", <| |> ], Except[ _Association ] -> <| |> ];
    <|
        turn,
        "Entities" -> Map[
            Function[ e,
                If[ MatchQ[ e, KeyValuePattern @ { "Type" -> "Tool", "Status" -> "failed", "ClientOutcome" -> None } ],
                    With[ { texts = Select[ toolTexts @ e, acpClientInterruptionTextQ ] },
                        Which[
                            texts === { }, e,
                            AnyTrue[ texts, StringContainsQ[ #, "declined", IgnoreCase -> True ] & ], <| e, "ClientOutcome" -> "Declined" |>,
                            True, <| e, "ClientOutcome" -> "Stopped" |>
                        ]
                    ],
                    e
                ]
            ],
            entities
        ]
    |>
];

replayClientOutcomes // endDefinition;


toolTexts // beginDefinition;

toolTexts[ tool_Association ] := Join[
    Cases[ { Lookup[ tool, "RawOutput", None ] }, KeyValuePattern[ "error" -> e_String ] :> e ],
    Cases[
        Replace[ Lookup[ tool, "Content", { } ], Except[ _List ] -> { } ],
        KeyValuePattern @ { "type" -> "content", "content" -> KeyValuePattern @ { "type" -> "text", "text" -> t_String } } :> t
    ]
];

toolTexts // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRestoreWriteStep*)

(* Writes a restored session in time-boxed pump steps (scheduled by Connection.wl once session/load succeeded; each step
   schedules the next): the first step splits the replay into turns and starts a new conversation; the following steps
   build and write turns (a user cell and the final cell each, about $acpRestoreStepTime seconds of work per step, at
   least one turn), the last $acpReplayTurnsShown turns only, after a note saying how many earlier turns are not shown.
   The old transcript is deleted right after the first cells are written after it, so the input field is never moved
   (the user may be typing the next prompt); a session without turns clears the transcript at once, like New. Then the
   window is "Ready" (a prompt queued meanwhile is sent by housekeeping). A newer restore, a closed window or a
   disconnect that dropped the restore ends the job. *)
acpRestoreWriteStep // beginDefinition;

acpRestoreWriteStep[ nbo_NotebookObject, token_String ] := Catch @ Module[ { window, restore, job, deadline, cells, first },
    window  = existingWindow @ nbo;
    restore = If[ AssociationQ @ window, Lookup[ window, "Restore", None ], None ];
    If[ ! AssociationQ @ restore || restore[ "Token" ] =!= token || restore[ "Stage" ] =!= "Writing",
        If[ Lookup[ Lookup[ $restoreJobs, nbo, <| |> ], "Token", None ] === token, KeyDropFrom[ $restoreJobs, nbo ] ];
        Throw @ Null
    ];

    job = Lookup[ $restoreJobs, nbo, None ];
    If[ ! AssociationQ @ job || job[ "Token" ] =!= token,
        job = restoreNewJob[ nbo, window, restore ];
        restoreStepDone[ nbo, token ];
        job[ "OldCells" ] = Replace[ restoreClearCells[ nbo, job[ "Ranges" ] =!= { } || job[ "Hidden" ] > 0 ], Except[ { ___CellObject } ] -> { } ];
        $restoreJobs[ nbo ] = job;
        acpSchedule @ acpRestoreWriteStep[ nbo, token ];
        Throw @ Null
    ];

    deadline = AbsoluteTime[ ] + $acpRestoreStepTime;
    cells    = Internal`Bag[ ];
    first    = job[ "Next" ];
    If[ first === 1 && job[ "Hidden" ] > 0, Internal`StuffBag[ cells, restoreNoteCell @ job[ "Hidden" ] ] ];
    While[ job[ "Next" ] <= Length @ job[ "Ranges" ] && (job[ "Next" ] === first || AbsoluteTime[ ] < deadline),
        Scan[ Internal`StuffBag[ cells, # ] &, restoreTurnCells[ job, job[ "Next" ] ] ];
        job[ "Next" ] = job[ "Next" ] + 1
    ];
    restoreWriteCells[ nbo, Internal`BagPart[ cells, All ], job[ "OldCells" ] ];
    job[ "OldCells" ] = { };
    job[ "Written" ]  = job[ "Written" ] + Internal`BagLength @ cells;

    If[ job[ "Next" ] > Length @ job[ "Ranges" ],
        restoreFinish[ nbo, token, job ],
        $restoreJobs[ nbo ] = job;
        restoreStepDone[ nbo, token ];
        acpSchedule @ acpRestoreWriteStep[ nbo, token ]
    ]
];

acpRestoreWriteStep // endDefinition;


(* The job of a restore: the replay split into turns (the last $acpReplayTurnsShown are written). The updates move from
   the window record to the job. If the caps dropped the oldest updates, the partial turn at the start is dropped too. *)
restoreNewJob // beginDefinition;

restoreNewJob[ nbo_NotebookObject, window_Association, restore_Association ] := Module[ { updates, ranges, shown },
    updates = acpReplayUpdates @ restore;
    If[ restore[ "Dropped" ] > 0,
        updates = Drop[
            updates,
            Replace[
                FirstPosition[ updates, KeyValuePattern[ "sessionUpdate" -> "user_message_chunk" ], { Length @ updates + 1 }, { 1 }, Heads -> False ],
                { { n_Integer } :> n - 1, _ -> 0 }
            ]
        ]
    ];
    ranges = acpReplayRanges @ updates;
    shown  = Take[ ranges, -Min[ $acpReplayTurnsShown, Length @ ranges ] ];
    <|
        "Token"            -> restore[ "Token" ],
        "Notebook"         -> nbo,
        "SessionID"        -> restore[ "SessionID" ],
        "Updates"          -> updates,
        "Ranges"           -> shown,
        "Next"             -> 1,
        "Hidden"           -> Max[ 0, Max[ restore[ "Turns" ], Length @ ranges ] - Length @ shown ],
        "ProjectDirectory" -> Lookup[ window, "ProjectDirectory", None ],
        "AgentName"        -> agentName @ window,
        "BaseTime"         -> AbsoluteTime[ ],
        "Written"          -> 0,
        "OldCells"         -> { }
    |>
];

restoreNewJob // endDefinition;


(* The cells of the i-th shown turn: the user cell (if there is a prompt) and the final cell *)
restoreTurnCells // beginDefinition;

restoreTurnCells[ job_Association, i_Integer ] := Module[ { range, turn, cells },
    range = job[ "Ranges" ][[ i ]];
    turn  = acpReplayTurn[
        Take[ job[ "Updates" ], range ],
        <|
            "ID"               -> "acp-replay-" <> CreateUUID[ ],
            "Notebook"         -> job[ "Notebook" ],
            "SessionID"        -> job[ "SessionID" ],
            "ProjectDirectory" -> job[ "ProjectDirectory" ],
            "AgentName"        -> job[ "AgentName" ],
            "StartTime"        -> job[ "BaseTime" ] + i
        |>
    ];
    cells = {
        If[ StringLength @ turn[ "Prompt" ] > 0, restoreUserCell @ turn[ "Prompt" ], Nothing ],
        Replace[ acpCatchAll @ acpFinalCell @ turn, Except[ _Cell ] :> acpFinalCell @ <| |> ]
    };
    acpDropRenderCache @ turn[ "ID" ];
    cells
];

restoreTurnCells // endDefinition;


(* The user message cell of a replayed prompt (like a live user cell, without the cell tag that finds a new cell) *)
restoreUserCell // beginDefinition;

restoreUserCell[ prompt_String ] := Replace[
    workspaceChatInputCellExpr[ acpNeutralizeLinearSyntax @ prompt, "acp-replay-input" ],
    Cell[ a___, CellTags -> _, b___ ] :> Cell[ a, b ]
];

restoreUserCell // endDefinition;


(* "12 earlier messages are not shown." *)
restoreNoteCell // beginDefinition;

restoreNoteCell[ n_Integer ] := With[
    { text = If[ n === 1, acpLabel[ "ReplayEarlierTurnsOne" ], acpLabel[ "ReplayEarlierTurns", <| "n" -> n |> ] ] },
    Cell[
        text,
        "Text",
        CellMargins       -> { { 20, 20 }, { 6, 12 } },
        Editable          -> False,
        FontColor         -> GrayLevel[ 0.55 ],
        FontSize          -> 12,
        FontSlant         -> Italic,
        GeneratedCell     -> True,
        TaggingRules      -> <| "CellToStringData" -> text, "ChatNotebookSettings" -> <| "ACPWindow" -> True |> |>,
        TextAlignment     -> Center
    ]
];

restoreNoteCell // endDefinition;


(* The job made progress (the watchdog in housekeeping counts from here); the updates are in the job now *)
restoreStepDone // beginDefinition;

restoreStepDone[ nbo_NotebookObject, token_String ] := acpWindowUpdate[
    nbo,
    Function[ w,
        With[ { r = Lookup[ w, "Restore", None ] },
            If[ AssociationQ @ r && r[ "Token" ] === token,
                <| w, "Restore" -> <| r, "Chunks" -> { }, "ChunkBytes" -> { }, "Tail" -> { }, "StepAt" -> AbsoluteTime[ ] |> |>,
                Missing[ "Stale" ]
            ]
        ]
    ]
];

restoreStepDone // endDefinition;


(* The restored session is shown: the window is ready (or stays disconnected, if the agent died meanwhile). job: the
   write job, or None (housekeeping ended a job without progress: the job of the token, if there is one). *)
restoreFinish // beginDefinition;

restoreFinish[ nbo_NotebookObject, token_String, job0_ ] := With[
    { job = Replace[ job0, Except[ _Association ] :> Replace[ Lookup[ $restoreJobs, nbo, None ], Except[ KeyValuePattern[ "Token" -> token ] ] -> None ] ] },
    KeyDropFrom[ $restoreJobs, nbo ];
    restoreFinishCells[ nbo, job ];
    acpWindowUpdate[
        nbo,
        Function[ w,
            With[ { r = Lookup[ w, "Restore", None ] },
                If[ KeyExistsQ[ w, "Status" ] && AssociationQ @ r && r[ "Token" ] === token,
                    <|
                        w,
                        "Restore" -> None,
                        "Status"  -> If[ w[ "Status" ] === "Restoring",
                            If[ acpConnectionQ @ Lookup[ w, "Connection", None ], "Ready", "Disconnected" ],
                            w[ "Status" ]
                        ]
                    |>,
                    Missing[ "Stale" ]
                ]
            ]
        ]
    ];
    acpPublish[ ];
    Null
];

restoreFinish // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Front end*)

(* Front end parts of the job; nothing is written without a front end (headless tests replace these). *)
restoreFrontEndQ // beginDefinition;
restoreFrontEndQ[ nbo_NotebookObject ] := $FrontEnd =!= Null && MemberQ[ Notebooks[ ], nbo ];
restoreFrontEndQ // endDefinition;


(* The first step: a new conversation UUID. writes: whether the job will write cells; then the transcript's cells are
   given (restoreWriteCells deletes them after the first cells are written after them, so the attached input field,
   where the user may be typing, is not touched); otherwise the transcript is deleted now and the input field moves to
   the top, like New. *)
restoreClearCells // beginDefinition;

restoreClearCells[ nbo_NotebookObject, writes_ ] := If[ restoreFrontEndQ @ nbo,
    CurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings", "ConversationUUID" } ] = createUUID[ ];
    With[ { cells = Replace[ Cells @ nbo, Except[ { ___CellObject } ] -> { } ] },
        If[ TrueQ @ writes,
            cells,
            If[ cells =!= { }, NotebookDelete @ cells ];
            moveChatInputToTop @ nbo;
            { }
        ]
    ],
    { }
];

restoreClearCells // endDefinition;


(* Appends cells after the last cell without moving the selection or scrolling, then deletes the old transcript's cells
   (old: given by restoreClearCells for the first write, then { }). The first write into an empty window is at the
   selection, after the notebook's last cell; the input field then moves from the top to the bottom and gets the focus
   back if it had it. *)
restoreWriteCells // beginDefinition;

restoreWriteCells[ _NotebookObject, { }, _ ] := Null;

restoreWriteCells[ nbo_NotebookObject, cells: { __Cell }, old_ ] := If[ restoreFrontEndQ @ nbo,
    With[ { last = Last[ Cells @ nbo, None ] },
        If[ MatchQ[ last, _CellObject ],
            contextBlock @ NotebookWrite[ System`NotebookLocationSpecifier[ last, "After" ], cells, None, AutoScroll -> False ];
            If[ MatchQ[ old, { __CellObject } ], Quiet @ NotebookDelete @ old ],
            With[ { focused = inputFieldFocusedQ @ nbo },
                SelectionMove[ nbo, After, Notebook, AutoScroll -> False ];
                contextBlock @ NotebookWrite[ nbo, cells, None ];
                moveChatInputToBottom @ nbo;
                If[ focused, Quiet @ moveToChatInputField[ nbo, True ] ]
            ]
        ]
    ]
];

restoreWriteCells // endDefinition;


(* After the job: the old transcript's cells, if the job ended before its first write (e.g. housekeeping gave it up),
   are deleted; the input field is at the top of an empty window, else at the bottom, with the last turn scrolled into
   view above it: from the top of the notebook, moving the selection after the last cell scrolls just enough to show
   the end at the bottom of the window ("ScrollNotebookEnd" would leave only the bottom of the last cell at the top of
   the window, and without scrolling to the top first the result depends on where the old transcript was scrolled to);
   the selection then goes back into the input field, where the user continues the session. *)
restoreFinishCells // beginDefinition;

restoreFinishCells[ nbo_NotebookObject, job_ ] := If[ restoreFrontEndQ @ nbo,
    With[ { old = Replace[ Lookup[ Replace[ job, Except[ _Association ] -> <| |> ], "OldCells", { } ], Except[ { ___CellObject } ] -> { } ] },
        If[ old =!= { }, Quiet @ NotebookDelete @ old ];
        Which[
            Cells @ nbo === { },
                Quiet @ moveChatInputToTop @ nbo,
            AssociationQ @ job && job[ "Written" ] > 0,
                Quiet @ moveChatInputToBottom @ nbo;
                Quiet @ FrontEndTokenExecute[ nbo, "ScrollNotebookStart" ];
                Quiet @ SelectionMove[ nbo, After, Notebook, AutoScroll -> True ];
                Quiet @ moveToChatInputField[ nbo, True ]
        ]
    ]
];

restoreFinishCells // endDefinition;


(* Whether the selection is in the window's attached input field *)
inputFieldFocusedQ // beginDefinition;

inputFieldFocusedQ[ nbo_NotebookObject ] := TrueQ @ Quiet @ IntersectingQ[
    Replace[ SelectedCells @ nbo, Except[ _List ] -> { } ],
    Replace[ Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField" ], Except[ _List ] -> { } ]
];

inputFieldFocusedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*New Session in a Folder*)

(* "+" of a project in the Sessions window ("NewSessionIn" action): in the window's folder what New does; in another
   folder the project folder changes (a new connection with a new session there). Refused while the window is busy. *)
acpNewSessionIn // beginDefinition;

acpNewSessionIn[ nbo_NotebookObject, cwd_String ] := Catch @ Module[ { window, busy },
    window = existingWindow @ nbo;
    If[ ! AssociationQ @ window, Throw @ Missing[ "NotFound" ] ];
    busy = acpSessionsBusyState @ window;
    If[ busy =!= None, Throw @ Failure[ "Busy", <| "Reason" -> busy |> ] ];
    Which[
        samePathQ[ cwd, Lookup[ window, "ProjectDirectory", None ] ],
            acpNewChat @ nbo,
        ! TrueQ @ Quiet @ DirectoryQ @ cwd,
            acpSetNotice[ nbo, acpLabel[ "NoticeSessionFolderMissing", <| "path" -> displayPath @ cwd |> ] ];
            Throw @ Failure[ "FolderMissing", <| "Cwd" -> cwd |> ],
        True,
            acpChangeProjectDirectory[ nbo, cwd ]
    ];
    acpSessionsMarkStale @ nbo;
    acpPublish[ ];
    "New"
];

acpNewSessionIn // endDefinition;


acpNewSessionInAction // beginDefinition;

acpNewSessionInAction[ nbo_NotebookObject, cwd_String ] := (
    acpCheckSession @ nbo;
    acpEnsureWindowRecord @ nbo;
    acpNewSessionIn[ nbo, cwd ]
);

acpNewSessionInAction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Deleting Sessions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpDeleteSession*)

(* Deletes a saved session ("DeleteSession" action, after the Sessions window's confirmation): raw session/delete on the
   window's connection (any listed ID, also one this connection never saw). Never the window's current (or resumable, or
   restoring) session; only if the agent advertises sessionCapabilities.delete. The item disappears when the agent
   confirms (and the list is fetched again); an error becomes the store's "Notice". *)
acpDeleteSession // beginDefinition;

acpDeleteSession[ nbo_NotebookObject, sid_String ] := Catch @ Module[ { window, conn, sent },
    window = existingWindow @ nbo;
    If[ ! AssociationQ @ window, Throw @ Missing[ "NotFound" ] ];
    If[ StringLength @ sid === 0, Throw @ Failure[ "InvalidSession", <| "SessionID" -> sid |> ] ];
    If[ MemberQ[ Append[ currentSessionIDs @ window, Lookup[ window, "ResumableSessionID", None ] ], sid ],
        Throw @ Failure[ "CurrentSession", <| "SessionID" -> sid |> ]
    ];
    conn = Lookup[ window, "Connection", None ];
    If[ ! acpConnectionQ @ conn || ! AssociationQ @ Lookup[ window, "Capabilities", None ], Throw @ Failure[ "NotConnected", <| |> ] ];
    If[ ! acpSessionsCapabilities[ window ][ "Delete" ], Throw @ Failure[ "Unsupported", <| "Capability" -> "delete" |> ] ];
    If[ KeyExistsQ[ deletingOf @ acpSessionsOf @ window, sid ], Throw[ "Deleting" ] ];

    sessionsUpdate[ nbo, <| #1, "Deleting" -> Append[ deletingOf @ #1, sid -> conn ], "Notice" -> None |> & ];
    sent = acpSendSessionDelete[ nbo, conn, sid ];
    If[ FailureQ @ sent,
        acpSessionsDeleteFailed[ nbo, sid, acpConnectionLabel[ "ErrorSendFailed", <| "agent" -> agentName @ window |> ] ];
        Throw @ sent
    ];
    acpPublish[ ];
    "Deleting"
];

acpDeleteSession // endDefinition;


acpDeleteSessionAction // beginDefinition;

acpDeleteSessionAction[ nbo_NotebookObject, sid_String ] := (
    acpCheckSession @ nbo;
    acpEnsureWindowRecord @ nbo;
    acpDeleteSession[ nbo, sid ]
);

acpDeleteSessionAction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionsOnDeleteResponse*)

(* The response to session/delete (reader handler: kernel state only) *)
acpSessionsOnDeleteResponse // beginDefinition;

acpSessionsOnDeleteResponse[ nbo_NotebookObject, data_Association, resp_Association ] := With[ { sid = Lookup[ data, "SessionID", None ] },
    If[ TrueQ @ resp[ "Error" ],
        acpSessionsDeleteFailed[ nbo, sid, agentMessage[ resp[ "Message" ], "SessionsDeleteFailed" ] ],
        sessionsUpdate[
            nbo,
            <|
                #1,
                "Deleting" -> KeyDrop[ deletingOf @ #1, { sid } ],
                "Items"    -> Select[ #1[ "Items" ], Lookup[ #, "SessionID", None ] =!= sid & ],
                "Stale"    -> True
            |> &
        ]
    ];
    Null
];

acpSessionsOnDeleteResponse // endDefinition;


(* A delete failed: message is the notice text *)
acpSessionsDeleteFailed // beginDefinition;

acpSessionsDeleteFailed[ nbo_NotebookObject, sid_, message_String ] := (
    acpLog[ "SessionDeleteFailed", <| "SessionID" -> sid |> ];
    sessionsUpdate[ nbo, <| #1, "Deleting" -> KeyDrop[ deletingOf @ #1, { sid } ], "Notice" -> message |> & ];
    Null
);

acpSessionsDeleteFailed // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sessions Window*)

(* The Sessions window is a separate notebook beside the ACP window, found by its TaggingRules ({"ACPSessions", "Owner"}
   is the ACP window's NotebookObject), so it is found again after a kernel restart. Its content is one self-contained
   cell (cell tag "ACPSessions"), made by acpSessionsCell. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionsWindowOf*)
acpSessionsWindowOf // beginDefinition;

acpSessionsWindowOf[ owner_NotebookObject ] := If[ $FrontEnd === Null,
    None,
    SelectFirst[ Replace[ Notebooks[ ], Except[ _List ] -> { } ], Quiet @ CurrentValue[ #, { TaggingRules, "ACPSessions", "Owner" } ] === owner &, None ]
];

acpSessionsWindowOf // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionsCloseWindow*)

(* Closing the ACP window closes its Sessions window (UI.wl's window-closed cleanup) *)
acpSessionsCloseWindow // beginDefinition;

acpSessionsCloseWindow[ owner_NotebookObject ] := With[ { sessions = acpSessionsWindowOf @ owner },
    If[ MatchQ[ sessions, _NotebookObject ], Quiet @ NotebookClose @ sessions ];
    Null
];

acpSessionsCloseWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionsRecover*)

(* After a kernel restart (scheduled by UI.wl's acpRefreshWindowUI, like the toolbar rebuild): an open Sessions window
   gets fresh content (its views tracked symbols of the old kernel) and the store, which started out empty, lists again
   once the window is connected. *)
acpSessionsRecover // beginDefinition;

acpSessionsRecover[ owner_NotebookObject ] := With[ { sessions = acpSessionsWindowOf @ owner },
    If[ MatchQ[ sessions, _NotebookObject ],
        acpEnsureWindowRecord @ owner;
        acpSessionsOpened @ owner;
        acpSessionsRebuildWindow[ sessions, owner ]
    ];
    sessions
];

acpSessionsRecover // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionsRebuildWindow*)

(* Replaces the content cell of a Sessions window with a fresh acpSessionsCell (if there is one) *)
acpSessionsRebuildWindow // beginDefinition;

acpSessionsRebuildWindow[ sessions_NotebookObject, owner_NotebookObject ] := Module[ { cell, old },
    cell = acpSessionsCell @ owner;
    If[ ! MatchQ[ cell, _Cell ], Return[ Null, Module ] ];
    old = Replace[ Quiet @ Cells[ sessions, CellTags -> "ACPSessions" ], Except[ _List ] -> { } ];
    If[ MatchQ[ old, { __CellObject } ],
        contextBlock @ NotebookWrite[ First @ old, cell, None, AutoScroll -> False ];
        If[ Length @ old > 1, NotebookDelete @ Rest @ old ]
    ];
    Null
];

acpSessionsRebuildWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Toolbar Button*)

(* The icon-only "Sessions" button in the ACP window's toolbar (UI.wl's acpToolbarMainRow): opens the Sessions window
   beside the ACP window, or closes it if it is open. *)
acpSessionsButton // beginDefinition;

acpSessionsButton[ nbo_NotebookObject ] := acpActionButton[
    blueHueButtonAppearance[
        Tooltip[
            chatbookIcon[ "WorkspaceToolbarIconHistory", False, color @ "NA_BlueHueButtonIcon" ],
            acpLabel[ "SessionsButtonTooltip" ]
        ],
        { Automatic, 24 },
        { { 5, 5 }, { 0, 0 } }
    ],
    { "ToggleSessions", nbo },
    BoxID -> "ACPSessionsButton"
];

acpSessionsButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpToggleSessions*)

(* ChatbookAction["ACP", "ToggleSessions", owner] (the toolbar button): closes the open Sessions window of the ACP window,
   or opens one beside it (see acpSessionsPlacement) and lists the sessions. An open Sessions window that other windows
   hide (e.g. a maximized notebook the user clicked into, or the ACP window itself in the "Overlap" placement) is placed
   beside the ACP window again and brought to the front instead of being closed (a click would seem to do nothing).
   Gives "Closed", "Raised" or the new window. Closing from the kernel does not run the window's "WindowClose" event, so
   the store is told here. *)
acpToggleSessions // beginDefinition;

acpToggleSessions[ owner_NotebookObject ] := Module[ { existing },
    acpCheckSession @ owner;
    acpEnsureWindowRecord @ owner;
    existing = acpSessionsWindowOf @ owner;
    Which[
        ! MatchQ[ existing, _NotebookObject ],
            sessionsOpenWindow @ owner,
        sessionsCoveredQ[ owner, existing ],
            sessionsRaiseWindow[ owner, existing ],
        True,
            acpSessionsClosed @ owner;
            Quiet @ NotebookClose @ existing;
            acpPublish[ ];
            "Closed"
    ]
];

acpToggleSessions // endDefinition;


(* The hidden Sessions window is placed beside the ACP window again (which may have moved), selected, and lists *)
sessionsRaiseWindow // beginDefinition;

sessionsRaiseWindow[ owner_NotebookObject, sessions_NotebookObject ] := Module[ { geometry },
    geometry = acpSessionsGeometry @ owner;
    If[ MatchQ[ geometry[ "OwnerWindowMargins" ], { { _, _ }, { _, _ } } ],
        Quiet @ SetOptions[ owner, WindowMargins -> geometry[ "OwnerWindowMargins" ] ]
    ];
    (* only the position: a width the user gave the window is kept *)
    If[ MatchQ[ geometry[ "WindowMargins" ], { { _, _ }, { _, _ } } ],
        Quiet @ SetOptions[ sessions, WindowMargins -> geometry[ "WindowMargins" ] ]
    ];
    sessionsMoveToActiveDesktop @ sessions;
    Quiet @ SetSelectedNotebook @ sessions;
    acpSessionsOpened @ owner;
    acpPublish[ ];
    "Raised"
];

sessionsRaiseWindow // endDefinition;


(* Whether other windows hide most of the Sessions window (front end calls: the windows in front of it) *)
sessionsCoveredQ // beginDefinition;

sessionsCoveredQ[ owner_NotebookObject, sessions_NotebookObject ] := If[ $FrontEnd === Null,
    False,
    acpSessionsCoveredQ[ sessionsStackInfo @ sessions, owner, sessions ]
];

sessionsCoveredQ // endDefinition;


(* The windows of the front end from the front one to the Sessions window (Notebooks[] lists them front to back):
   { <| "Notebook", "Visible", "Floating" (palettes, which stay in front), "Rect" -> { { left, right }, { top, bottom } }
   in screen coordinates from the top left, or None |>, ... } *)
sessionsStackInfo // beginDefinition;

sessionsStackInfo[ sessions_NotebookObject ] := Module[ { stack, n, visible, floating, frames, margins, sizes },
    stack = Replace[ Quiet @ Notebooks[ ], Except[ { ___NotebookObject } ] -> { } ];
    n     = Replace[ FirstPosition[ stack, sessions, { 0 }, { 1 }, Heads -> False ], { { i_Integer } :> i, _ -> 0 } ];
    If[ n === 0, Return[ { }, Module ] ];
    stack    = Take[ stack, n ];
    visible  = sessionsWindowValues[ stack, Visible ];
    floating = sessionsWindowValues[ stack, WindowFloating ];
    frames   = sessionsWindowValues[ stack, WindowFrame ];
    margins  = sessionsWindowValues[ stack, WindowMargins ];
    sizes    = sessionsWindowValues[ stack, WindowSize ];
    MapThread[
        <|
            "Notebook" -> #1,
            "Visible"  -> TrueQ @ #2,
            "Floating" -> TrueQ @ #3 || #4 === "Palette",
            "Rect"     -> sessionsWindowRect[ #5, #6 ]
        |> &,
        { stack, visible, floating, frames, margins, sizes }
    ]
];

sessionsStackInfo // endDefinition;


(* One resolved option value per window (None where the front end gives none) *)
sessionsWindowValues // beginDefinition;

sessionsWindowValues[ nbs_List, option_ ] := Replace[
    Quiet @ AbsoluteCurrentValue[ nbs, option ],
    Except[ values_List /; Length @ values === Length @ nbs ] :> ConstantArray[ None, Length @ nbs ]
];

sessionsWindowValues // endDefinition;


sessionsWindowRect // beginDefinition;

sessionsWindowRect[ { { l_? NumberQ, _ }, { _, t_? NumberQ } }, { w_? NumberQ, h_? NumberQ } ] := { { l, l + w }, { t, t + h } };
sessionsWindowRect[ m_? NumberQ, size_ ] := sessionsWindowRect[ { { m, m }, { m, m } }, size ];
sessionsWindowRect[ _, _ ] := None;

sessionsWindowRect // endDefinition;


(* Whether the windows in front of the Sessions window hide most of it (pure). stack: sessionsStackInfo, front to back.
   Only visible windows that are not palettes count; the order is trusted only if the ACP window (whose toolbar button
   was clicked, so it was brought to the front) is the first of them; otherwise (or without geometry) the window counts
   as visible, and the button closes it as before. *)
acpSessionsCoveredQ // beginDefinition;

acpSessionsCoveredQ[ stack_List, owner_, sessions_ ] := Module[ { windows, n, rect },
    windows = Select[ stack, AssociationQ[ # ] && TrueQ @ #[ "Visible" ] && ! TrueQ @ #[ "Floating" ] & ];
    If[ windows === { } || First[ windows ][ "Notebook" ] =!= owner, Return[ False, Module ] ];
    n = Replace[ FirstPosition[ Lookup[ windows, "Notebook" ], sessions, { 0 }, { 1 }, Heads -> False ], { { i_Integer } :> i, _ -> 0 } ];
    If[ n === 0, Return[ False, Module ] ];
    rect = windows[[ n, "Rect" ]];
    If[ ! MatchQ[ rect, { { _? NumberQ, _? NumberQ }, { _? NumberQ, _? NumberQ } } ], Return[ False, Module ] ];
    AnyTrue[ Take[ windows, n - 1 ], coversQ[ #[ "Rect" ], rect ] & ]
];

acpSessionsCoveredQ[ ___ ] := False;

acpSessionsCoveredQ // endDefinition;


(* Whether rect a covers more than half of rect b ({ { x0, x1 }, { y0, y1 } }) *)
coversQ // beginDefinition;

coversQ[ { { ax0_? NumberQ, ax1_? NumberQ }, { ay0_? NumberQ, ay1_? NumberQ } }, { { bx0_, bx1_ }, { by0_, by1_ } } ] := With[
    {
        overlap = Max[ 0, Min[ ax1, bx1 ] - Max[ ax0, bx0 ] ] * Max[ 0, Min[ ay1, by1 ] - Max[ ay0, by0 ] ],
        area    = (bx1 - bx0) * (by1 - by0)
    },
    area > 0 && overlap > area / 2
];

coversQ[ _, _ ] := False;

coversQ // endDefinition;


sessionsOpenWindow // beginDefinition;

sessionsOpenWindow[ owner_NotebookObject ] := Module[ { geometry, sessions },
    acpSessionsSet[ owner, "ConfirmDelete", None ];
    acpFileIcon @ { "Directory" }; (* loads the icons once, here rather than in the view's first rendering *)
    geometry = acpSessionsGeometry @ owner;
    (* The ACP window moves right first if that makes room (like a sidebar would) *)
    If[ MatchQ[ geometry[ "OwnerWindowMargins" ], { { _, _ }, { _, _ } } ],
        Quiet @ SetOptions[ owner, WindowMargins -> geometry[ "OwnerWindowMargins" ] ]
    ];
    sessions = NotebookPut @ acpSessionsNotebook[ owner, geometry ];
    If[ MatchQ[ sessions, _NotebookObject ], sessionsMoveToActiveDesktop @ sessions ];
    acpSessionsOpened @ owner;
    acpPublish[ ];
    sessions
];

sessionsOpenWindow // endDefinition;


(* macOS: the window opens on the active desktop (Space), as attachToLeft does for the ACP window *)
sessionsMoveToActiveDesktop // beginDefinition;

sessionsMoveToActiveDesktop[ nbo_NotebookObject ] := If[
    And[
        $FrontEnd =!= Null,
        BoxForm`sufficientVersionQ[ 14.2 ],
        Internal`CachedSystemInformation[ "FrontEnd", "OperatingSystem" ] === "MacOSX"
    ],
    Quiet @ FE`Evaluate @ Evaluate @ FEPrivate`MoveToActiveDesktop @ nbo
];

sessionsMoveToActiveDesktop // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Placement*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpSessionsPlacement*)

(* Where the Sessions window goes (pure). owner: the ACP window's resolved geometry in WindowMargins coordinates,
   <| "Left", "Width", "Bottom", "Top", "Height", "Frame" |> ("Width", "Height": its WindowSize; "Frame": the width of
   its window frame's left and right borders together, which WindowMargins include and WindowSize does not); display:
   { xmin, xmax } of the display the ACP window is on; width: the width of the Sessions window. It gets the ACP window's
   top margin and height (both windows have the same kind of frame; the ACP window's bottom margin would make it taller
   where a window manager adds the title bar of a new window after placing it, as on Linux), or without a height its top
   and bottom margins, and goes
     * "Left": left of the ACP window, if that fits on the display;
     * "SlideOwner": at the display's left edge, with the ACP window moved right just enough ("OwnerWindowMargins"), if
       the display is wide enough for both (what a sidebar would do; the ACP window usually sits at the left edge);
     * "Overlap": at the display's left edge, over the ACP window. *)
acpSessionsPlacement // beginDefinition;

acpSessionsPlacement[ owner_Association, { xmin_? NumberQ, xmax_ }, width_? NumberQ ] := Module[ { l, w, b, t, h, f, v },
    { l, w, b, t, h } = Lookup[ owner, { "Left", "Width", "Bottom", "Top", "Height" }, None ];
    f = Replace[ Lookup[ owner, "Frame", 0 ], Except[ _? NumberQ ] -> 0 ];
    v = If[ NumberQ @ h, { Automatic, t }, { b, t } ];
    Append[
        Which[
            l - width - f >= xmin,
                <| "Placement" -> "Left", "WindowMargins" -> { { l - width - f, Automatic }, v }, "OwnerWindowMargins" -> None |>,
            xmin + width + f + w <= xmax,
                <|
                    "Placement"          -> "SlideOwner",
                    "WindowMargins"      -> { { xmin, Automatic }, v },
                    "OwnerWindowMargins" -> { { xmin + width + f, Automatic }, { b, t } }
                |>,
            True,
                <| "Placement" -> "Overlap", "WindowMargins" -> { { xmin, Automatic }, v }, "OwnerWindowMargins" -> None |>
        ],
        "WindowSize" -> { width, If[ NumberQ @ h, h, Automatic ] }
    ]
];

acpSessionsPlacement // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpSessionsGeometry*)

(* The placement of a new Sessions window beside the ACP window owner (front end calls; placed once, it does not follow
   later moves), plus the "Magnification" of the ACP window. Without a usable front end answer: the default size and
   place. The width scales with the ACP window's magnification like the ACP window's width does. *)
acpSessionsGeometry // beginDefinition;

acpSessionsGeometry[ owner_NotebookObject ] := Module[ { mag, width, margins, size, display },
    mag     = Replace[ If[ $FrontEnd === Null, None, Quiet @ AbsoluteCurrentValue[ owner, Magnification ] ], Except[ _? NumberQ ] -> 0.85 ];
    width   = Ceiling[ $acpSessionsWindowWidth * mag / 0.85 ];
    margins = If[ $FrontEnd === Null, None, Quiet @ AbsoluteCurrentValue[ owner, WindowMargins ] ];
    margins = Replace[ margins, m_? NumberQ :> { { m, m }, { m, m } } ];
    size    = If[ $FrontEnd === Null, None, Quiet @ AbsoluteCurrentValue[ owner, WindowSize ] ];
    Append[
        If[ MatchQ[ margins, { { _? NumberQ, _ }, { _? NumberQ, _? NumberQ } } ] && MatchQ[ size, { _? NumberQ, _ } ],
            display = sessionsDisplayRange[ owner, margins[[ 1, 1 ]] + size[[ 1 ]] ];
            acpSessionsPlacement[
                <|
                    "Left"   -> margins[[ 1, 1 ]],
                    "Width"  -> size[[ 1 ]],
                    "Bottom" -> margins[[ 2, 1 ]],
                    "Top"    -> margins[[ 2, 2 ]],
                    "Height" -> size[[ 2 ]],
                    "Frame"  -> sessionsFrameWidth[ margins[[ 1 ]], size[[ 1 ]], display ]
                |>,
                display,
                width
            ],
            <| "Placement" -> "Default", "WindowMargins" -> Automatic, "OwnerWindowMargins" -> None, "WindowSize" -> { width, Automatic } |>
        ],
        "Magnification" -> mag
    ]
];

acpSessionsGeometry // endDefinition;


(* The width of the left and right borders of a window's frame together: what its horizontal WindowMargins and its
   WindowSize width leave of the display (where the right margin is measured from the display's right edge, i.e. a
   single display or the rightmost one), if that is plausible (0 to 24 points); otherwise 0 (the windows then overlap by
   the width of a border). *)
sessionsFrameWidth // beginDefinition;

sessionsFrameWidth[ { l_? NumberQ, r_? NumberQ }, w_? NumberQ, { _, xmax_? NumberQ } ] :=
    With[ { f = xmax - r - l - w }, If[ 0 <= f <= 24, f, 0 ] ];

sessionsFrameWidth[ _, _, _ ] := 0;

sessionsFrameWidth // endDefinition;


(* { xmin, xmax } of the display the window is on (as attachToLeft finds it). If that is not known, the display is
   assumed to end at the window's right edge, so the ACP window is never moved off an unknown display. *)
sessionsDisplayRange // beginDefinition;

sessionsDisplayRange[ nbo_NotebookObject, right_ ] := Module[ { index, displays },
    index    = Quiet @ NotebookTools`NotebookDisplayIndex @ nbo;
    displays = Quiet @ CurrentValue[ "ConnectedDisplays" ];
    Replace[
        If[ IntegerQ @ index && ListQ @ displays && 1 <= index <= Length @ displays, displays[[ index ]], None ],
        {
            KeyValuePattern[ "FullRegion" -> { { xmin_? NumberQ, xmax_? NumberQ }, _ } ] :> { xmin, xmax },
            _ :> { 0, Max[ right, 0 ] }
        }
    ]
];

sessionsDisplayRange // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionsNotebook*)

(* The Sessions window (pure): one content cell; the options of a deployed list window (no cell brackets, selection,
   insertion point or editing, never saved), excluded from the Notebook Assistant's notebook context
   (ExcludeFromChat), with the ACP window's kernel, magnification and background. geometry: see acpSessionsGeometry. *)
acpSessionsNotebook // beginDefinition;

acpSessionsNotebook[ owner_NotebookObject, geometry_Association ] := Notebook[
    { acpSessionsCell @ owner },
    Sequence @@ {
        If[ MatchQ[ geometry[ "WindowMargins" ], { { _, _ }, { _, _ } } ], WindowMargins -> geometry[ "WindowMargins" ], Nothing ],
        WindowSize              -> Replace[ geometry[ "WindowSize" ], Except[ { _, _ } ] -> { $acpSessionsWindowWidth, Automatic } ],
        Magnification           -> Replace[ geometry[ "Magnification" ], Except[ _? NumberQ ] -> 0.85 ],
        WindowTitle             -> acpLabel[ "SessionsWindowTitle" ],
        Evaluator               -> sessionsEvaluator @ owner,
        TaggingRules            -> <|
            "ACPSessions"          -> <| "Owner" -> owner |>,
            "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |>
        |>,
        Background              -> $sessionsBackground,
        CellInsertionPointCell  -> None,
        CellInsertionPointColor -> $sessionsBackground,
        ClosingAutoSave         -> False,
        "ClosingSaveDialog"     -> False,
        Deployed                -> True,
        Editable                -> False,
        NotebookEventActions    -> sessionsEventActions @ owner,
        Saveable                -> False,
        Selectable              -> False,
        ShowCellBracket         -> False,
        StyleDefinitions        -> "Default.nb",
        WindowElements          -> { "VerticalScrollBar" },
        WindowFrameElements     -> { "CloseBox", "ResizeArea" },
        WindowToolbars          -> { }
    }
];

acpSessionsNotebook // endDefinition;


(* Closing the window tells the store (no more listings); Escape cancels a delete confirmation *)
sessionsEventActions // beginDefinition;

sessionsEventActions[ owner_NotebookObject ] := Replace[
    { acpActionCode[ "SessionsClosed", owner ], acpActionCode[ "SessionsCancelDelete", owner ] },
    { Hold[ closed_ ], Hold[ cancel_ ] } :> { ParentList, "WindowClose" :> closed, "EscapeKeyDown" :> cancel }
];

sessionsEventActions // endDefinition;


(* The kernel that holds the ACP window's state *)
sessionsEvaluator // beginDefinition;

sessionsEvaluator[ owner_NotebookObject ] := Replace[
    If[ $FrontEnd === Null, None, Quiet @ AbsoluteCurrentValue[ owner, Evaluator ] ],
    Except[ _String ] -> "Local"
];

sessionsEvaluator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSessionsCell*)

(* The content of the Sessions window: one self-contained cell (every option inline, no styles of a private stylesheet,
   icons inline or from Chatbook's front end resources, the owner in the cell's own TaggingRules), so that it can also
   be the content of a front end sidebar panel. The view re-renders only when the part of the window state it shows
   changes (sessionsDynamic with sessionsViewSignature), so hover states and clicks are not lost while the ACP window
   streams a turn. *)
acpSessionsCell // beginDefinition;

acpSessionsCell[ owner_NotebookObject ] := Cell[
    BoxData @ sessionsBoxes @ sessionsDynamic @ owner,
    Background           -> $sessionsBackground,
    CellFrame            -> 0,
    CellFrameMargins     -> 0,
    CellMargins          -> 0,
    CellTags             -> "ACPSessions",
    Deployed             -> True,
    Editable             -> False,
    FontColor            -> $sessionsFont,
    FontFamily           -> "Source Sans Pro",
    FontSize             -> 13,
    LineSpacing          -> { 1, 0 },
    PrivateFontOptions   -> { "OperatorSubstitution" -> False },
    Selectable           -> False,
    ShowAutoStyles       -> False,
    ShowCellBracket      -> False,
    ShowStringCharacters -> False,
    TaggingRules         -> <| "ACPSessions" -> <| "Owner" -> owner |> |>
];

acpSessionsCell // endDefinition;


(* The derived view (like UI.wl's acpWindowDerivedDynamic): an invisible watcher tracks the window symbol and bumps the
   view's symbol when sessionsViewSignature changes; the view tracks only that symbol. Both load Chatbook first: after a
   kernel restart the window is still open and its Dynamics are evaluated by a kernel that may not have loaded Chatbook
   yet (the view then shows the state without a window record until acpSessionsRecover rebuilds the cell). *)
sessionsDynamic // beginDefinition;

sessionsDynamic[ owner_NotebookObject ] :=
    sessionsDynamic[ acpWindowSymbol @ owner, acpEntitySymbol[ acpWindowKey @ owner, "Sessions" ], owner ];

sessionsDynamic[ HoldComplete[ w_Symbol ], HoldComplete[ d_Symbol ], owner_NotebookObject ] := Row @ {
    Dynamic[
        w;
        Needs[ "Wolfram`Chatbook`" -> None ];
        acpSyncDerivedView[ owner, "Sessions", sessionsViewSignature ];
        Spacer[ { 0, 0 } ],
        TrackedSymbols :> { w }
    ],
    Dynamic[
        d;
        Needs[ "Wolfram`Chatbook`" -> None ];
        acpRenderView[ sessionsContent, owner ],
        TrackedSymbols :> { d }
    ]
};

sessionsDynamic // endDefinition;


(* Boxes made with only System` and Global` on $ContextPath, so that every symbol in them (the views' Dynamic
   expressions) is written with its full context name and still resolves when the front end evaluates it. *)
sessionsBoxes // beginDefinition;
sessionsBoxes[ expr_ ] := Block[ { $Context = "Global`", $ContextPath = { "System`", "Global`" } }, ToBoxes @ expr ];
sessionsBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*View*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Colors*)
$sessionsBackground := color @ "NA_NotebookBackground";
$sessionsFont       := color @ "NA_OverlayMenuFont";
$sessionsMuted      := acpColor[ "Muted" ];
$sessionsAccent     := color @ "NA_BlueHueButtonIcon";
$sessionsInactive   := color @ "NA_BlueHueButtonIconInactive";
$sessionsHover      := color @ "NA_OverlayMenuItemBackgroundHover";
$sessionsCurrent    := LightDarkSwitched[ RGBColor[ 0.89, 0.95, 0.99 ], RGBColor[ 0.12, 0.22, 0.29 ] ];
$sessionsHeader     := color @ "NA_Toolbar";
$sessionsDivider    := color @ "NA_OverlayMenuFrame";
$sessionsDanger     := LightDarkSwitched[ RGBColor[ 0.80, 0.17, 0.13 ], RGBColor[ 0.70, 0.20, 0.17 ] ];
$sessionsDangerHover := LightDarkSwitched[ RGBColor[ 0.68, 0.12, 0.09 ], RGBColor[ 0.80, 0.27, 0.23 ] ];
$sessionsButton      := LightDarkSwitched[ GrayLevel[ 1.0 ], GrayLevel[ 0.22 ] ];
$sessionsButtonHover := LightDarkSwitched[ GrayLevel[ 0.94 ], GrayLevel[ 0.30 ] ];
$sessionsButtonFrame := LightDarkSwitched[ GrayLevel[ 0.75 ], GrayLevel[ 0.45 ] ];

(* The text of the cell (buttons would use the button font) *)
$sessionsTextStyle := {
    FontColor          -> $sessionsFont,
    FontFamily         -> "Source Sans Pro",
    FontSize           -> 13,
    PrivateFontOptions -> { "OperatorSubstitution" -> False }
};

(* Left margins of the rows: session titles line up with the folder names of the project rows *)
$projectRowIndent = 8;
$sessionRowIndent = 38;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sessionsViewSignature*)

(* The part of the window state the view shows. Listing steps that change nothing visible (e.g. "Listing" -> "Ready"
   with the same items) do not re-render it; "Minute" refreshes the relative times. *)
sessionsViewSignature // beginDefinition;

sessionsViewSignature[ window_Association ] := With[ { store = acpSessionsOf @ window },
    {
        KeyTake[ store, { "Items", "Error", "Notice", "Minute", "Expanded", "ConfirmDelete", "Shown" } ],
        Keys @ deletingOf @ store,
        NumberQ @ store[ "ListedAt" ],
        sessionsStatus[ window, store ],
        Lookup[ window, { "SessionID", "ResumableSessionID", "ProjectDirectory" }, None ],
        agentName @ window,
        acpSessionsBusyState @ window,
        currentSessionIDs @ window,
        acpSessionsCapabilities @ window,
        acpConnectionQ @ Lookup[ window, "Connection", None ]
    }
];

sessionsViewSignature[ _ ] := None;

sessionsViewSignature // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sessionsStatus*)

(* What the status line under the header says: None, { "NoProject" }, { "NotConnected" }, { "Unsupported" },
   { "Error", message } or { "Loading" } (nothing listed yet). *)
sessionsStatus // beginDefinition;

sessionsStatus[ window_Association, store_Association ] := Which[
    ! StringQ @ Lookup[ window, "ProjectDirectory", None ],
        { "NoProject" },
    store[ "Status" ] === "Unsupported",
        { "Unsupported" },
    ! acpConnectionQ @ Lookup[ window, "Connection", None ] && ! StringQ @ Lookup[ window, "ConnectToken", None ],
        { "NotConnected" },
    store[ "Status" ] === "Error" && AssociationQ @ store[ "Error" ],
        { "Error", Replace[ Lookup[ store[ "Error" ], "Message", None ], Except[ _String ] -> "" ] },
    ! NumberQ @ store[ "ListedAt" ] && store[ "Items" ] === { },
        { "Loading" },
    True,
        None
];

sessionsStatus // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sessionsContent*)

(* The view: header, status line, notice and the projects with their sessions. now: AbsoluteTime for relative times. *)
sessionsContent // beginDefinition;

sessionsContent[ owner_NotebookObject ] := sessionsContent[ owner, acpWindowGet @ owner, AbsoluteTime[ ] ];

sessionsContent[ owner_NotebookObject, window_Association, now_? NumberQ ] := Module[ { store, status },
    store  = acpSessionsOf @ window;
    status = sessionsStatus[ window, store ];
    sessionsLayout @ {
        sessionsHeader[ owner, agentName @ window ],
        sessionsStatusView[ status, agentName @ window ],
        sessionsNoticeView[ owner, store[ "Notice" ] ],
        If[ NumberQ @ store[ "ListedAt" ] || store[ "Items" ] =!= { },
            sessionsProjectsView @ sessionsViewContext[ owner, window, store, now ],
            Nothing
        ]
    }
];

(* No window record (e.g. right after a kernel restart, before the ACP window recovered) *)
sessionsContent[ owner_NotebookObject, _, _ ] := sessionsLayout @ {
    sessionsHeader[ owner, None ],
    sessionsStatusView[ { "NotConnected" }, agentName @ <| |> ]
};

sessionsContent // endDefinition;


sessionsLayout // beginDefinition;

sessionsLayout[ items_List ] := Column[
    Flatten @ items,
    Alignment -> Left,
    ItemSize  -> Full,
    Spacings  -> 0
];

sessionsLayout // endDefinition;


(* What the rows need to know about the window *)
sessionsViewContext // beginDefinition;

sessionsViewContext[ owner_NotebookObject, window_Association, store_Association, now_ ] := Module[ { busy, caps, restore },
    busy    = acpSessionsBusyLabel @ window;
    caps    = acpSessionsCapabilities @ window;
    restore = Replace[ Lookup[ window, "Restore", None ], Except[ _Association ] :> Replace[ Lookup[ window, "PendingRestore", None ], Except[ _Association ] -> <| |> ] ];
    <|
        "Owner"     -> owner,
        "Window"    -> window,
        "Store"     -> store,
        "Now"       -> now,
        "Agent"     -> agentName @ window,
        "Busy"      -> busy,
        (* without a connection the capabilities are unknown: restoring reconnects first (Sessions.wl decides) *)
        "CanLoad"   -> caps[ "Load" ] || ! AssociationQ @ Lookup[ window, "Capabilities", None ],
        "CanDelete" -> caps[ "Delete" ] && acpConnectionQ @ Lookup[ window, "Connection", None ],
        "Active"    -> activeSessionID @ window,
        "Restoring" -> Lookup[ restore, "SessionID", None ],
        "Deleting"  -> Keys @ deletingOf @ store,
        "Confirm"   -> If[ busy === None, Lookup[ Replace[ store[ "ConfirmDelete" ], Except[ _Association ] -> <| |> ], "SessionID", None ], None ]
    |>
];

sessionsViewContext // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Header*)

(* "Sessions", the agent's name (muted) and the Refresh button *)
sessionsHeader // beginDefinition;

sessionsHeader[ owner_NotebookObject, agent_ ] := Framed[
    Grid[
        { {
            Style[ acpLabel[ "SessionsTitle" ], FontSize -> 14, FontWeight -> "DemiBold", FontColor -> $sessionsFont ],
            If[ StringQ @ agent, Style[ agent, FontSize -> 12, FontColor -> $sessionsMuted ], "" ],
            Item[ "", ItemSize -> Fit ],
            sessionsRefreshButton @ owner
        } },
        Alignment -> { Left, Center },
        Spacings  -> { { 0, 0.6, 0, 0 }, 0 }
    ],
    Background   -> $sessionsHeader,
    FrameMargins -> { { 12, 6 }, { 4, 4 } },
    FrameStyle   -> None,
    ImageSize    -> Full
];

sessionsHeader // endDefinition;


sessionsRefreshButton // beginDefinition;

sessionsRefreshButton[ owner_NotebookObject ] := acpActionButton[
    blueHueButtonAppearance[ Tooltip[ $sessionsRefreshIcon, acpLabel[ "SessionsRefresh" ] ], { Automatic, 24 }, { { 5, 5 }, { 0, 0 } } ],
    { "SessionsRefresh", owner },
    BoxID -> "ACPSessionsRefresh"
];

sessionsRefreshButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Status and Notice*)
sessionsStatusView // beginDefinition;

sessionsStatusView[ None, _ ] := Nothing;

sessionsStatusView[ { "Loading" }, _ ] := sessionsStatusPane @ Row @ {
    ProgressIndicator[ Appearance -> "Percolate", ImageSize -> { 30, 8 } ],
    Spacer[ 6 ],
    Style[ acpLabel[ "SessionsLoading" ], FontColor -> $sessionsMuted ]
};

sessionsStatusView[ { "NoProject" }, _ ] := sessionsStatusPane @ Style[ acpLabel[ "SessionsNoProject" ], FontColor -> $sessionsMuted ];

sessionsStatusView[ { "NotConnected" }, agent_ ] :=
    sessionsStatusPane @ Style[ acpLabel[ "SessionsNotConnected", <| "agent" -> agent |> ], FontColor -> $sessionsMuted ];

sessionsStatusView[ { "Unsupported" }, agent_ ] :=
    sessionsStatusPane @ Style[ acpLabel[ "SessionsUnsupported", <| "agent" -> agent |> ], FontColor -> $sessionsMuted ];

sessionsStatusView[ { "Error", message_String }, _ ] := sessionsStatusPane @ Style[ message, FontColor -> acpColor[ "RedText" ] ];

sessionsStatusView // endDefinition;


sessionsStatusPane // beginDefinition;

sessionsStatusPane[ expr_ ] := Pane[
    Style[ expr, FontSize -> 12, LineBreakWithin -> Automatic ],
    FrameMargins -> { { 12, 10 }, { 4, 8 } },
    ImageSize    -> Full
];

sessionsStatusPane // endDefinition;


(* The error of the last delete, dismissable *)
sessionsNoticeView // beginDefinition;

sessionsNoticeView[ owner_NotebookObject, notice_String ] := Pane[
    Framed[
        Grid[
            { {
                Style[ notice, FontSize -> 12, FontColor -> LightDarkSwitched @ RGBColor[ "#555555" ] ],
                Tooltip[ acpActionButton[ $sessionsCloseGlyph, { "SessionsDismissNotice", owner }, BoxID -> "ACPSessionsDismissNotice" ], acpLabel[ "NoticeDismiss" ] ]
            } },
            Alignment -> { { Left, Right }, Center },
            ItemSize  -> { { Fit, Automatic } },
            Spacings  -> { 0.5, 0 }
        ],
        Background     -> LightDarkSwitched[ RGBColor[ "#F5F5F5" ], RGBColor[ "#2C2C2C" ] ],
        FrameMargins   -> { { 6, 4 }, { 3, 3 } },
        FrameStyle     -> LightDarkSwitched[ RGBColor[ "#E5E5E5" ], RGBColor[ "#3C3C3C" ] ],
        ImageSize      -> Full,
        RoundingRadius -> 4
    ],
    FrameMargins -> { { 8, 8 }, { 2, 6 } },
    ImageSize    -> Full
];

sessionsNoticeView[ _, _ ] := Nothing;

sessionsNoticeView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Projects*)

(* The projects (acpSessionsProjects): the window's project is open unless the user closed it; if the window has no
   project, the first one is. *)
sessionsProjectsView // beginDefinition;

sessionsProjectsView[ ctx_Association ] := Module[ { projects, firstKey },
    projects = acpSessionsProjects @ ctx[ "Window" ];
    firstKey = If[ AnyTrue[ projects, TrueQ @ #[ "Current" ] & ], None, Replace[ projects, { { p_, ___ } :> p[ "Key" ], _ -> None } ] ];
    If[ projects === { },
        sessionsEmptyLine[ $projectRowIndent ],
        Pane[
            Column[ Flatten[ sessionsProjectView[ ctx, #, firstKey ] & /@ projects ], Alignment -> Left, ItemSize -> Full, Spacings -> 0 ],
            FrameMargins -> { { 4, 4 }, { 8, 4 } },
            ImageSize    -> Full
        ]
    ]
];

sessionsProjectsView // endDefinition;


sessionsProjectView // beginDefinition;

sessionsProjectView[ ctx_Association, project_Association, firstKey_ ] := Module[ { open, sessions, shown, flags, rows, more },
    open     = Lookup[ ctx[ "Store" ][ "Expanded" ], project[ "Key" ], TrueQ @ project[ "Current" ] || project[ "Key" ] === firstKey ];
    sessions = project[ "Sessions" ];
    shown    = Replace[ Lookup[ ctx[ "Store" ][ "Shown" ], project[ "Key" ], $sessionsPageSize ], Except[ _Integer? Positive ] -> $sessionsPageSize ];
    (* the newest ones, and the window's own session wherever it is *)
    flags    = MapIndexed[ First[ #2 ] <= shown || TrueQ @ #1[ "Current" ] || #1[ "SessionID" ] === ctx[ "Active" ] &, sessions ];
    rows     = Pick[ sessions, flags ];
    (* "Show n more": the sessions that the next page adds (the window's own one is shown already) *)
    more     = If[ Length @ rows < Length @ sessions,
        Replace[
            Count[ flags[[ shown + 1 ;; Min[ shown + $sessionsPageSize, Length @ flags ] ]], False ],
            0 :> Min[ $sessionsPageSize, Length @ sessions - Length @ rows ]
        ],
        0
    ];
    {
        sessionsProjectRow[ ctx, project, TrueQ @ open ],
        If[ TrueQ @ open,
            {
                If[ sessions === { }, sessionsEmptyLine[ $sessionRowIndent ], sessionsSessionRow[ ctx, # ] & /@ rows ],
                If[ more > 0, sessionsMoreRow[ ctx, project, more ], Nothing ]
            },
            Nothing
        ]
    }
];

sessionsProjectView // endDefinition;


(* Chevron, folder icon, folder name (the window's project in the accent color) and the number of sessions; the full path
   in the tooltip. On hover: "+" (new session in the folder) and open-folder buttons. *)
sessionsProjectRow // beginDefinition;

sessionsProjectRow[ ctx_Association, project_Association, open_ ] := Module[
    { owner, key, missing, busy, nameColor, toggle, newButton, openButton },

    owner     = ctx[ "Owner" ];
    key       = sessionsKey @ project[ "Key" ];
    missing   = ! TrueQ @ Quiet @ DirectoryQ @ project[ "Cwd" ];
    busy      = ctx[ "Busy" ];
    nameColor = Which[ missing, $sessionsMuted, TrueQ @ project[ "Current" ], $sessionsAccent, True, $sessionsFont ];

    toggle = Tooltip[
        acpActionButton[
            Grid[
                { {
                    sessionsChevron @ open,
                    RawBoxes @ acpFileIcon @ { "Directory" },
                    Style[ sessionsShorten[ project[ "Name" ], $sessionsNameLength ], FontWeight -> "DemiBold", FontColor -> nameColor, LineBreakWithin -> False ],
                    Style[ project[ "Count" ], FontSize -> 12, FontColor -> $sessionsMuted ]
                } },
                Alignment -> { Left, Center },
                Spacings  -> { { 0, 0.35, 0.4, 0.5 }, 0 }
            ],
            { "SessionsToggleProject", owner, key, open },
            Alignment -> Left,
            BaseStyle -> $sessionsTextStyle,
            BoxID     -> "ACPSessionsProject-" <> key
        ],
        If[ missing,
            acpLabel[ "SessionsFolderMissing" ],
            acpNeutralizeLinearSyntax @ acpAbbreviatePath[ project[ "Cwd" ], None ]
        ]
    ];

    newButton = sessionsIconButton[
        sessionsIcon[ "New", ! missing && busy === None ],
        Which[ missing, acpLabel[ "SessionsFolderMissing" ], StringQ @ busy, busy, True, acpLabel[ "SessionsNewHere" ] ],
        { "SessionsNew", owner, key },
        "ACPSessionsNew-" <> key,
        ! missing && busy === None
    ];

    openButton = sessionsIconButton[
        sessionsIcon[ "OpenFolder", ! missing ],
        If[ missing, acpLabel[ "SessionsFolderMissing" ], acpLabel[ "SessionsOpenFolder" ] ],
        { "SessionsOpenFolder", owner, key },
        "ACPSessionsOpenFolder-" <> key,
        ! missing
    ];

    Mouseover[
        sessionsRowFrame[ { { toggle, "" } }, None, $projectRowIndent ],
        sessionsRowFrame[ { { toggle, Row[ { newButton, openButton }, Spacer[ 4 ] ] } }, $sessionsHover, $projectRowIndent ]
    ]
];

sessionsProjectRow // endDefinition;


(* "Show 25 more": a project's further sessions (rendering every session of a project with hundreds is slow) *)
sessionsMoreRow // beginDefinition;

sessionsMoreRow[ ctx_Association, project_Association, n_Integer ] := Pane[
    acpActionButton[
        Style[ acpLabel[ "SessionsShowMore", <| "n" -> n |> ], FontSize -> 12, FontColor -> $sessionsAccent ],
        { "SessionsShowMore", ctx[ "Owner" ], sessionsKey @ project[ "Key" ] },
        Alignment -> Left,
        BaseStyle -> $sessionsTextStyle,
        BoxID     -> "ACPSessionsShowMore-" <> sessionsKey @ project[ "Key" ]
    ],
    Alignment    -> Left,
    FrameMargins -> { { $sessionRowIndent + 1, 8 }, { 4, 4 } },
    ImageSize    -> Full
];

sessionsMoreRow // endDefinition;


(* "No sessions yet" (indent: the left margin) *)
sessionsEmptyLine // beginDefinition;

sessionsEmptyLine[ indent_ ] := Pane[
    Style[ acpLabel[ "SessionsEmpty" ], FontSize -> 12, FontSlant -> Italic, FontColor -> $sessionsMuted ],
    FrameMargins -> { { indent + 4, 8 }, { 4, 4 } },
    ImageSize    -> Full
];

sessionsEmptyLine // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Sessions*)

(* A session: its title (one line, shortened; the full title in the tooltip) and the short relative time. The window's
   own session is highlighted and has no actions; on hover, other sessions are highlighted like the Notebook Assistant's
   History rows and show the trash button instead of the time; clicking the title restores the session. While the ACP
   window is busy the rows are muted and do nothing (the tooltip says why); if the agent can't open saved sessions they
   are muted and only offer the trash button. *)
sessionsSessionRow // beginDefinition;

sessionsSessionRow[ ctx_Association, item_Association ] := Module[
    { owner, sid, key, title, short, time, current, reason, titleView, timeView },

    owner   = ctx[ "Owner" ];
    sid     = item[ "SessionID" ];
    key     = sessionsKey @ sid;
    title   = sessionsTitle @ item;
    short   = sessionsShorten[ title, $sessionsTitleLength ];
    time    = sessionsTimeView[ item[ "UpdatedAt" ], ctx[ "Now" ], $sessionsMuted ];
    (* while a session is restored, it is the highlighted one *)
    current = If[ StringQ @ ctx[ "Restoring" ], sid === ctx[ "Restoring" ], TrueQ @ item[ "Current" ] || sid === ctx[ "Active" ] ];
    reason  = Which[
        StringQ @ ctx[ "Busy" ], ctx[ "Busy" ],
        ! TrueQ @ ctx[ "CanLoad" ], acpLabel[ "SessionsLoadUnsupported", <| "agent" -> ctx[ "Agent" ] |> ],
        True, None
    ];

    Which[
        sid === ctx[ "Confirm" ] && ! current,
            sessionsConfirmRow[ owner, key ],

        MemberQ[ ctx[ "Deleting" ], sid ],
            sessionsRowFrame[ { { sessionsTitleView[ short, title, $sessionsMuted ], sessionsMutedText @ acpLabel[ "SessionsDeleting" ] } }, None, $sessionRowIndent ],

        current,
            timeView = If[ sid === ctx[ "Restoring" ], sessionsMutedText @ acpLabel[ "SessionsRestoring" ], time ];
            Tooltip[
                sessionsRowFrame[ { { sessionsTitleView[ short, None, $sessionsAccent, "DemiBold" ], timeView } }, $sessionsCurrent, $sessionRowIndent, True ],
                Column @ { title, acpLabel[ "SessionsCurrent" ] }
            ],

        StringQ @ reason && (StringQ @ ctx[ "Busy" ] || ! TrueQ @ ctx[ "CanDelete" ]),
            Tooltip[
                sessionsRowFrame[ { { sessionsTitleView[ short, None, $sessionsMuted ], time } }, None, $sessionRowIndent ],
                Column @ { title, Style[ reason, FontSlant -> Italic ] }
            ],

        (* the agent can't open saved sessions but can delete them: the title is no button, the trash button is there *)
        StringQ @ reason,
            titleView = Tooltip[ sessionsTitleView[ short, None, $sessionsMuted ], Column @ { title, Style[ reason, FontSlant -> Italic ] } ];
            Mouseover[
                sessionsRowFrame[ { { titleView, time } }, None, $sessionRowIndent ],
                sessionsRowFrame[
                    { {
                        titleView,
                        sessionsIconButton[ sessionsIcon[ "Trash", True ], acpLabel[ "SessionsDeleteTooltip" ], { "SessionsConfirmDelete", owner, key }, "ACPSessionsDelete-" <> key, True ]
                    } },
                    $sessionsHover,
                    $sessionRowIndent
                ]
            ],

        True,
            titleView = acpActionButton[
                sessionsTitleView[ short, title, $sessionsFont ],
                { "SessionsOpen", owner, key },
                Alignment -> Left,
                BaseStyle -> $sessionsTextStyle,
                BoxID     -> "ACPSessionsOpen-" <> key,
                ImageSize -> Full
            ];
            Mouseover[
                sessionsRowFrame[ { { sessionsTitleView[ short, title, $sessionsFont ], time } }, None, $sessionRowIndent ],
                sessionsRowFrame[
                    { {
                        titleView,
                        If[ TrueQ @ ctx[ "CanDelete" ],
                            sessionsIconButton[ sessionsIcon[ "Trash", True ], acpLabel[ "SessionsDeleteTooltip" ], { "SessionsConfirmDelete", owner, key }, "ACPSessionsDelete-" <> key, True ],
                            time
                        ]
                    } },
                    $sessionsHover,
                    $sessionRowIndent
                ]
            ]
    ]
];

sessionsSessionRow // endDefinition;


(* "Delete this session?" with Delete and Cancel; Cancel is where the trash button was, so a double click on the trash
   button cancels. Delete only works $sessionsDeleteArmDelay seconds after the confirmation appeared ("SessionsDelete"). *)
sessionsConfirmRow // beginDefinition;

sessionsConfirmRow[ owner_NotebookObject, key_String ] := Pane[
    Framed[
        Grid[
            { {
                Style[ acpLabel[ "SessionsDeleteConfirm" ], FontColor -> acpColor[ "ErrorFont" ], LineBreakWithin -> False ],
                Item[ "", ItemSize -> Fit ],
                acpActionButton[ sessionsButtonLabel[ acpLabel[ "SessionsDelete" ], "Danger" ], { "SessionsDelete", owner, key }, BoxID -> "ACPSessionsDeleteConfirm-" <> key ],
                acpActionButton[ sessionsButtonLabel[ acpLabel[ "SessionsCancel" ], "Secondary" ], { "SessionsCancelDelete", owner }, BoxID -> "ACPSessionsDeleteCancel-" <> key ]
            } },
            Alignment -> { Left, Center },
            Spacings  -> { { 0, 0, 0, 0.5 }, 0 }
        ],
        Background     -> acpColor[ "ErrorBackground" ],
        FrameMargins   -> { { $sessionRowIndent - 1, 4 }, { 3, 3 } },
        FrameStyle     -> acpColor[ "ErrorFrame" ],
        ImageSize      -> Full,
        RoundingRadius -> 4
    ],
    FrameMargins -> { { 0, 0 }, { 1, 1 } },
    ImageSize    -> Full
];

sessionsConfirmRow // endDefinition;


sessionsButtonLabel // beginDefinition;

sessionsButtonLabel[ label_String, style_String ] := Mouseover[
    sessionsButtonFrame[ label, style, False ],
    sessionsButtonFrame[ label, style, True ]
];

sessionsButtonLabel // endDefinition;


sessionsButtonFrame // beginDefinition;

sessionsButtonFrame[ label_String, "Danger", hover_ ] := Framed[
    Style[ label, FontColor -> White, FontWeight -> "DemiBold", FontSize -> 12 ],
    Background     -> If[ TrueQ @ hover, $sessionsDangerHover, $sessionsDanger ],
    FrameMargins   -> { { 8, 8 }, { 1, 1 } },
    FrameStyle     -> If[ TrueQ @ hover, $sessionsDangerHover, $sessionsDanger ],
    RoundingRadius -> 3
];

sessionsButtonFrame[ label_String, _, hover_ ] := Framed[
    Style[ label, FontColor -> $sessionsFont, FontSize -> 12 ],
    Background     -> If[ TrueQ @ hover, $sessionsButtonHover, $sessionsButton ],
    FrameMargins   -> { { 8, 8 }, { 1, 1 } },
    FrameStyle     -> $sessionsButtonFrame,
    RoundingRadius -> 3
];

sessionsButtonFrame // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Row Parts*)

(* A full-width row: { { left, right } } (the left item takes the free width), background (None: transparent), the left
   margin; accent: a bar on the left (the window's own session). *)
sessionsRowFrame // beginDefinition;

sessionsRowFrame[ { { left_, right_ } }, background_, indent_ ] := sessionsRowFrame[ { { left, right } }, background, indent, False ];

sessionsRowFrame[ { { left_, right_ } }, background_, indent_, False ] := Framed[
    Grid[
        { { left, right } },
        Alignment -> { { Left, Right }, Baseline },
        ItemSize  -> { { Fit, Automatic } },
        Spacings  -> { 0.8, 0 }
    ],
    Background     -> Replace[ background, None -> $sessionsBackground ],
    FrameMargins   -> { { indent, 6 }, { 3, 3 } },
    FrameStyle     -> None,
    ImageMargins   -> { { 0, 0 }, { 1, 0 } },
    ImageSize      -> Full,
    RoundingRadius -> 3
];

(* The accent bar is the background of a narrow first column (frames would draw a border around the row) *)
sessionsRowFrame[ { { left_, right_ } }, background_, indent_, True ] := Pane[
    Grid[
        {
            {
                "",
                Pane[
                    Grid[
                        { { left, right } },
                        Alignment -> { { Left, Right }, Baseline },
                        ItemSize  -> { { Fit, Automatic } },
                        Spacings  -> { 0.8, 0 }
                    ],
                    FrameMargins -> { { indent - 0.8, 7 }, { 4, 4 } },
                    ImageSize    -> Full
                ]
            }
        },
        Alignment  -> { Left, Center },
        Background -> { { $sessionsAccent, Replace[ background, None -> $sessionsBackground ] } },
        ItemSize   -> { { 0.25, Fit } },
        Spacings   -> { 0, 0 }
    ],
    ImageMargins -> { { 0, 0 }, { 1, 0 } },
    ImageSize    -> Full
];

sessionsRowFrame // endDefinition;


(* A title in one line (the pane clips what the shortening left too wide; text in a Tooltip alone would wrap); tooltip:
   the full title (None: no tooltip) *)
sessionsTitleView // beginDefinition;

sessionsTitleView[ short_String, tooltip_, fontColor_ ] := sessionsTitleView[ short, tooltip, fontColor, Plain ];

sessionsTitleView[ short_String, tooltip_, fontColor_, weight_ ] := With[
    {
        text = Pane[
            Style[ short, FontColor -> fontColor, FontWeight -> weight, LineBreakWithin -> False ],
            BaselinePosition -> Baseline,
            ImageSize        -> Full,
            ImageSizeAction  -> "Clip"
        ]
    },
    If[ StringQ @ tooltip, Tooltip[ text, tooltip ], text ]
];

sessionsTitleView // endDefinition;


(* The relative time ("3m"), its date in the tooltip *)
sessionsTimeView // beginDefinition;

sessionsTimeView[ t_? NumberQ, now_, fontColor_ ] := Tooltip[
    Style[ acpShortRelativeTime[ t, now ], FontSize -> 12, FontColor -> fontColor, LineBreakWithin -> False ],
    acpLabel[ "SessionsUpdated", <| "time" -> DateString[ t, { "MonthNameShort", " ", "DayShort", ", ", "Year", " ", "Hour24", ":", "Minute" } ] |> ]
];

sessionsTimeView[ _, _, _ ] := "";

sessionsTimeView // endDefinition;


sessionsMutedText // beginDefinition;
sessionsMutedText[ text_String ] := Style[ text, FontSize -> 12, FontColor -> $sessionsMuted, FontSlant -> Italic, LineBreakWithin -> False ];
sessionsMutedText // endDefinition;


(* The title of an item for display (the agent's titles are neutralized by acpSessionItems): one line. OpenCode's
   fallback title "New session - <ISO time>" (the window's own session before its first prompt) is shown as "New
   session"; the time since the last update is beside it anyway. *)
sessionsTitle // beginDefinition;

sessionsTitle[ item_Association ] := Replace[
    Lookup[ item, "Title", None ],
    {
        t_String /; StringStartsQ[ t, "New session - " ] && acpSessionHiddenTitleQ @ t :> acpLabel[ "SessionsNewSession" ],
        t_String /; StringLength @ StringTrim @ t > 0 :> StringReplace[ StringTrim @ t, WhitespaceCharacter.. -> " " ],
        _ :> acpLabel[ "SessionsUntitled" ]
    }
];

sessionsTitle // endDefinition;


(* At most n characters, with an ellipsis if shortened *)
sessionsShorten // beginDefinition;
sessionsShorten[ s_String, n_Integer ] := If[ StringLength @ s > n, StringTrim @ StringTake[ s, n - 1 ] <> "\[Ellipsis]", s ];
sessionsShorten[ other_, _ ] := other;
sessionsShorten // endDefinition;


(* Action arguments name items and projects by a key made from the session ID or folder, so that no text from the agent
   is put into button code; the actions look the key up in the store (sessionsItemOf, sessionsProjectOf). *)
sessionsKey // beginDefinition;
sessionsKey[ s_String ] := IntegerString[ Hash[ s, "SHA256" ], 36 ];
sessionsKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Icons*)

(* An icon button; disabled buttons show their tooltip too (it says why) *)
sessionsIconButton // beginDefinition;

sessionsIconButton[ icon_, tooltip_, { args__ }, boxID_String, enabled_ ] := Tooltip[
    acpActionButton[ Pane[ icon, ImageSize -> { 18, 18 }, Alignment -> { Center, Center } ], { args }, BoxID -> boxID, Enabled -> TrueQ @ enabled ],
    tooltip
];

sessionsIconButton // endDefinition;


(* Icons: "New" ("+", as the toolbar's New button), "OpenFolder", "Trash" (the History rows' icon with its own hover);
   enabled: False draws them gray *)
sessionsIcon // beginDefinition;

sessionsIcon[ "New", enabled_ ] := chatbookIcon[ "WorkspaceToolbarIconNew", False, If[ TrueQ @ enabled, $sessionsAccent, $sessionsInactive ] ];

sessionsIcon[ "Trash", _ ] := chatbookIcon[ "WorkspaceHistoryTrashIcon", False ];

sessionsIcon[ "OpenFolder", enabled_ ] := Graphics[
    {
        If[ TrueQ @ enabled, $sessionsAccent, $sessionsInactive ],
        AbsoluteThickness[ 1.3 ],
        CapForm[ "Round" ],
        JoinForm[ "Round" ],
        (* a box open at the top right, with an arrow out of it *)
        Line @ { { 0.45, 1.0 }, { 0.0, 1.0 }, { 0.0, 0.0 }, { 1.0, 0.0 }, { 1.0, 0.55 } },
        Line @ { { 0.45, 0.55 }, { 1.12, 1.22 } },
        Line @ { { 0.68, 1.22 }, { 1.12, 1.22 }, { 1.12, 0.78 } }
    },
    AspectRatio      -> 1,
    BaselinePosition -> Scaled[ 0.1 ],
    ImageSize        -> { 12, 12 },
    PlotRange        -> { { -0.1, 1.25 }, { -0.1, 1.25 } }
];

sessionsIcon // endDefinition;


(* A small triangle: pointing right (closed) or down (open) *)
sessionsChevron // beginDefinition;

sessionsChevron[ open_ ] := Graphics[
    {
        $sessionsMuted,
        Polygon @ If[ TrueQ @ open, { { 0, 0.75 }, { 1, 0.75 }, { 0.5, 0.15 } }, { { 0.2, 0 }, { 0.2, 1 }, { 0.8, 0.5 } } ]
    },
    AspectRatio      -> 1,
    BaselinePosition -> Scaled[ 0.1 ],
    ImageSize        -> { 9, 9 },
    PlotRange        -> { { 0, 1 }, { 0, 1 } }
];

sessionsChevron // endDefinition;


(* A circular arrow *)
$sessionsRefreshIcon := Graphics[
    {
        $sessionsAccent,
        AbsoluteThickness[ 1.4 ],
        CapForm[ "Round" ],
        Circle[ { 0, 0 }, 1, { 0.25 Pi, 1.85 Pi } ],
        Polygon @ { { 0.42, 0.98 }, { 1.12, 1.18 }, { 0.95, 0.42 } }
    },
    AspectRatio      -> 1,
    BaselinePosition -> Scaled[ 0.15 ],
    ImageSize        -> { 13, 13 },
    PlotRange        -> { { -1.3, 1.3 }, { -1.3, 1.3 } }
];

$sessionsCloseGlyph = Style[ "\[Times]", FontSize -> 14, FontColor -> GrayLevel[ 0.5 ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpShortRelativeTime*)

(* How long ago t was, short ("now", "3m", "2h", "5d"), or its date ("Mar 4"; in another year "2025-12-01"). t, now:
   AbsoluteTime. *)
acpShortRelativeTime // beginDefinition;

acpShortRelativeTime[ t_? NumberQ, now_? NumberQ ] := With[ { s = now - t },
    Which[
        s < 60        , acpLabel[ "SessionsTimeNow" ],
        s < 3600      , acpLabel[ "SessionsTimeMinutes", <| "n" -> Floor[ s / 60 ] |> ],
        s < 86400     , acpLabel[ "SessionsTimeHours", <| "n" -> Floor[ s / 3600 ] |> ],
        s < 7 * 86400 , acpLabel[ "SessionsTimeDays", <| "n" -> Floor[ s / 86400 ] |> ],
        First @ DateList @ t === First @ DateList @ now,
            DateString[ t, { "MonthNameShort", " ", "DayShort" } ],
        True,
            DateString[ t, { "Year", "-", "Month", "-", "Day" } ]
    ]
];

acpShortRelativeTime[ _, _ ] := "";

acpShortRelativeTime // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Window Actions*)

(* The Sessions window's buttons (ChatbookAction["ACP", name, owner, ...]). Items and projects are named by sessionsKey
   and looked up in the store, so the agent's IDs and folders reach the backend unchanged without being put into button
   code. Each action first checks the kernel session (a click after a kernel restart recovers the ACP window). *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpSessionsWindowAction*)
acpSessionsWindowAction // beginDefinition;

acpSessionsWindowAction[ name_String, owner_NotebookObject, args___ ] := (
    acpCheckSession @ owner;
    acpEnsureWindowRecord @ owner;
    With[ { result = sessionsWindowAction[ name, owner, args ] }, acpPublish[ ]; result ]
);

acpSessionsWindowAction // endDefinition;


sessionsWindowAction // beginDefinition;

(* Restore the session (the ACP window gets the focus) *)
sessionsWindowAction[ "SessionsOpen", owner_, key_String ] := Replace[
    sessionsItemOf[ owner, key ],
    item_Association :> (
        acpSessionsSet[ owner, "ConfirmDelete", None ];
        sessionsFocusOwner[ owner, acpRestoreSession[ owner, item[ "SessionID" ], item[ "Cwd" ] ] ]
    )
];

(* "+": a new session in the project's folder *)
sessionsWindowAction[ "SessionsNew", owner_, key_String ] := Replace[
    sessionsProjectOf[ owner, key ],
    project_Association :> (
        acpSessionsSet[ owner, "ConfirmDelete", None ];
        sessionsFocusOwner[ owner, acpNewSessionIn[ owner, project[ "Cwd" ] ] ]
    )
];

(* The folder in the file manager (never launches an application bundle: Review.wl's acpReviewOpenFile) *)
sessionsWindowAction[ "SessionsOpenFolder", owner_, key_String ] := Replace[
    sessionsProjectOf[ owner, key ],
    project_Association :> (acpReviewOpenFile @ project[ "Cwd" ]; project[ "Cwd" ])
];

(* More sessions of a project *)
sessionsWindowAction[ "SessionsShowMore", owner_, key_String ] := Replace[
    sessionsProjectOf[ owner, key ],
    project_Association :> (
        sessionsUpdate[
            owner,
            <|
                #1,
                "Shown" -> <|
                    #1[ "Shown" ],
                    project[ "Key" ] -> Replace[ Lookup[ #1[ "Shown" ], project[ "Key" ], $sessionsPageSize ], Except[ _Integer ] -> $sessionsPageSize ] + $sessionsPageSize
                |>
            |> &
        ];
        acpSessionsOf[ owner ][ "Shown" ][ project[ "Key" ] ]
    )
];

(* Open or close a project *)
sessionsWindowAction[ "SessionsToggleProject", owner_, key_String, open_ ] := Replace[
    sessionsProjectOf[ owner, key ],
    project_Association :> (
        sessionsUpdate[ owner, <| #1, "Expanded" -> <| #1[ "Expanded" ], project[ "Key" ] -> ! TrueQ @ open |> |> & ];
        ! TrueQ @ open
    )
];

(* The trash button: the row asks for confirmation *)
sessionsWindowAction[ "SessionsConfirmDelete", owner_, key_String ] := Replace[
    sessionsItemOf[ owner, key ],
    item_Association :> (
        acpSessionsSet[ owner, "ConfirmDelete", <| "SessionID" -> item[ "SessionID" ], "ArmAt" -> AbsoluteTime[ ] + $sessionsDeleteArmDelay |> ];
        "Confirm"
    )
];

sessionsWindowAction[ "SessionsCancelDelete", owner_ ] := (
    sessionsUpdate[ owner, If[ #1[ "ConfirmDelete" ] === None, Missing[ "Unchanged" ], <| #1, "ConfirmDelete" -> None |> ] & ];
    "Cancelled"
);

(* Delete, from the confirmation (only once it is armed, and not while the ACP window is busy) *)
sessionsWindowAction[ "SessionsDelete", owner_, key_String ] := Catch @ Module[ { item, confirm, result },
    item    = sessionsItemOf[ owner, key ];
    confirm = acpSessionsOf[ owner ][ "ConfirmDelete" ];
    If[ ! AssociationQ @ item || ! AssociationQ @ confirm || confirm[ "SessionID" ] =!= item[ "SessionID" ], Throw @ Missing[ "NotConfirmed" ] ];
    If[ AbsoluteTime[ ] < confirm[ "ArmAt" ], Throw @ Missing[ "NotArmed" ] ];
    acpSessionsSet[ owner, "ConfirmDelete", None ];
    If[ acpSessionsBusyState @ acpWindowGet @ owner =!= None, Throw @ Failure[ "Busy", <| |> ] ];
    result = acpDeleteSession[ owner, item[ "SessionID" ] ];
    (* a failed send already set a notice; the other refusals are races with the view *)
    If[ FailureQ @ result && result[ "Tag" ] =!= "SendFailed",
        acpSessionsSet[ owner, "Notice", acpLabel[ "SessionsDeleteUnavailable" ] ]
    ];
    result
];

sessionsWindowAction[ "SessionsDismissNotice", owner_ ] := (acpSessionsSet[ owner, "Notice", None ]; Null);

sessionsWindowAction // endDefinition;


(* After a restore or new session started: the ACP window gets the focus (its input field) *)
sessionsFocusOwner // beginDefinition;

sessionsFocusOwner[ owner_NotebookObject, result: "Restoring" | "New" | "Current" ] := (
    If[ $FrontEnd =!= Null && MemberQ[ Notebooks[ ], owner ],
        SetSelectedNotebook @ owner;
        Quiet @ moveToChatInputField[ owner, True ]
    ];
    result
);

sessionsFocusOwner[ _, result_ ] := result;

sessionsFocusOwner // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Lookups*)

(* The listed item of a session key, or Missing *)
sessionsItemOf // beginDefinition;

sessionsItemOf[ owner_NotebookObject, key_String ] := SelectFirst[
    acpSessionsOf[ owner ][ "Items" ],
    AssociationQ[ # ] && StringQ @ #[ "SessionID" ] && sessionsKey @ #[ "SessionID" ] === key &,
    Missing[ "NotFound" ]
];

sessionsItemOf // endDefinition;


(* The project of a project key (from acpSessionsProjects, so also the window's own folder without sessions), or
   Missing *)
sessionsProjectOf // beginDefinition;

sessionsProjectOf[ owner_NotebookObject, key_String ] := With[ { window = acpWindowGet @ owner },
    If[ AssociationQ @ window,
        SelectFirst[ acpSessionsProjects @ window, sessionsKey @ #[ "Key" ] === key &, Missing[ "NotFound" ] ],
        Missing[ "NotFound" ]
    ]
];

sessionsProjectOf // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Housekeeping*)

(* Every $sessionsHousekeepingTicks publication ticks (while the pump runs), for each window:
     * restores: a write job without a step for $acpRestoreStepRetry seconds gets another step (a lost task), one
       without progress for $acpRestoreWriteTimeout seconds is ended; a window that is "Restoring" without a restore
       becomes ready again; a pending restore of a connection that failed is dropped;
     * deletes sent on an earlier connection are forgotten;
     * listings, while the Sessions window is open: the minute of relative times, the second listing after a turn,
       "NotConnected" without a connection, a listing without progress is given up, and a wanted listing starts once
       the connection is ready.
   Write jobs of windows that no longer restore are dropped. *)
sessionsHousekeeping // beginDefinition;

sessionsHousekeeping[ ] := With[ { now = AbsoluteTime[ ] },
    KeyValueMap[ sessionsWindowHousekeeping[ #1, #2, now ] &, $acpWindows ];
    sweepRestoreJobs[ ];
    Null
];

sessionsHousekeeping // endDefinition;


sessionsWindowHousekeeping // beginDefinition;

sessionsWindowHousekeeping[ nbo_NotebookObject, window_Association, now_ ] /; KeyExistsQ[ window, "Status" ] := acpIsolated[
    restoreHousekeeping[ nbo, window, now ];
    deletingHousekeeping[ nbo, window ];
    listingHousekeeping[ nbo, window, now ]
];

sessionsWindowHousekeeping[ _, _, _ ] := Null;

sessionsWindowHousekeeping // endDefinition;


restoreHousekeeping // beginDefinition;

restoreHousekeeping[ nbo_, window_, now_ ] := Module[ { restore, pending, status, stepAt },
    restore = Lookup[ window, "Restore", None ];
    pending = Lookup[ window, "PendingRestore", None ];
    status  = Lookup[ window, "Status", None ];
    Which[
        AssociationQ @ restore && restore[ "Stage" ] === "Writing",
            stepAt = Replace[ Lookup[ restore, "StepAt", None ], Except[ _? NumberQ ] -> Lookup[ restore, "LastUpdateAt", now ] ];
            Which[
                now - stepAt > $acpRestoreWriteTimeout,
                    acpLog[ "RestoreWriteTimeout", <| "SessionID" -> restore[ "SessionID" ] |> ];
                    restoreFinish[ nbo, restore[ "Token" ], None ],
                now - stepAt > $acpRestoreStepRetry,
                    With[ { t = restore[ "Token" ] }, acpSchedule @ acpRestoreWriteStep[ nbo, t ] ]
            ],
        status === "Restoring" && ! AssociationQ @ restore && ! AssociationQ @ pending,
            acpLog[ "RestoreStatusReset", <| |> ];
            acpWindowUpdate[
                nbo,
                Function[ w,
                    If[ w[ "Status" ] === "Restoring" && ! AssociationQ @ Lookup[ w, "Restore", None ],
                        <| w, "Status" -> If[ acpConnectionQ @ Lookup[ w, "Connection", None ], "Ready", "Disconnected" ] |>,
                        Missing[ "Unchanged" ]
                    ]
                ]
            ],
        AssociationQ @ pending && MemberQ[ { "Error", "NoDirectory" }, status ],
            acpLog[ "PendingRestoreDropped", <| "Status" -> status |> ];
            windowSet[ nbo, <| "PendingRestore" -> None |> ]
    ]
];

restoreHousekeeping // endDefinition;


(* Deletes sent on an earlier connection are forgotten: the disconnect (or reconnect, project switch, agent exit) dropped
   their requests, so neither their response nor their timeout will ever end them, and the session would stay
   "Deleting..." for good. Whether the agent deleted it shows in the next listing. *)
deletingHousekeeping // beginDefinition;

deletingHousekeeping[ nbo_, window_ ] := Module[ { conn, stale },
    conn  = Lookup[ window, "Connection", None ];
    stale = Keys @ Select[ deletingOf @ acpSessionsOf @ window, # =!= conn & ];
    If[ stale =!= { },
        acpLog[ "SessionDeleteDropped", <| "SessionIDs" -> stale |> ];
        sessionsUpdate[
            nbo,
            Function[ { s, w },
                With[ { c = Lookup[ w, "Connection", None ] },
                    <| s, "Deleting" -> Select[ deletingOf @ s, # === c & ], "Stale" -> True |>
                ]
            ]
        ]
    ]
];

deletingHousekeeping // endDefinition;


listingHousekeeping // beginDefinition;

listingHousekeeping[ nbo_, window_, now_ ] := Module[ { store, conn, connecting },
    store = acpSessionsOf @ window;
    If[ ! TrueQ @ store[ "Open" ], Return[ Null, Module ] ];
    conn       = Lookup[ window, "Connection", None ];
    connecting = StringQ @ Lookup[ window, "ConnectToken", None ];
    (* views that show relative times ("3m") track this *)
    If[ store[ "Minute" ] =!= Floor[ now / 60 ], With[ { m = Floor[ now / 60 ] }, sessionsUpdate[ nbo, <| #1, "Minute" -> m |> & ] ] ];
    If[ NumberQ @ store[ "RecheckAt" ] && now >= store[ "RecheckAt" ],
        sessionsUpdate[ nbo, <| #1, "RecheckAt" -> None, "Stale" -> True |> & ];
        store = <| store, "Stale" -> True |>
    ];
    Which[
        ! acpConnectionQ @ conn && ! connecting,
            If[ store[ "Status" ] =!= "NotConnected",
                sessionsUpdate[ nbo, <| #1, "Status" -> "NotConnected", "Stale" -> True, "Token" -> None, "Partial" -> { }, "Connection" -> None |> & ]
            ],
        (* a listing of an earlier connection: list again *)
        store[ "Status" ] === "Listing" && store[ "Connection" ] =!= conn,
            sessionsUpdate[ nbo, <| #1, "Status" -> "Idle", "Stale" -> True, "Token" -> None, "Partial" -> { }, "Connection" -> None |> & ],
        store[ "Status" ] === "Listing" && ! listingQ[ store, window, now ],
            acpSessionsListFailed[
                nbo,
                store[ "Token" ],
                <| "Code" -> "Timeout", "Message" -> acpConnectionLabel[ "ErrorTimeout", <| "agent" -> agentName @ window |> ] |>
            ],
        TrueQ @ store[ "Stale" ] && store[ "Status" ] =!= "Listing" && acpConnectionQ @ conn && AssociationQ @ Lookup[ window, "Capabilities", None ],
            acpSessionsList @ nbo
    ]
];

listingHousekeeping // endDefinition;


sweepRestoreJobs // beginDefinition;

sweepRestoreJobs[ ] := KeyValueMap[
    Function[ { nbo, job },
        If[ Lookup[ Replace[ acpWindowGet[ nbo, "Restore", None ], Except[ _Association ] -> <| |> ], "Token", None ] =!= job[ "Token" ],
            KeyDropFrom[ $restoreJobs, nbo ]
        ]
    ],
    $restoreJobs
];

sweepRestoreJobs // endDefinition;


acpRegisterHousekeeping[ "ACPSessions", sessionsHousekeeping, $sessionsHousekeepingTicks ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Utilities*)
(* The agent's name for labels: from its initialize response (neutralized there, by Connection.wl's agentInfoOf, and
   again here, since every label of this file takes it) or the agent's configured name *)
agentName // beginDefinition;

agentName[ window_Association ] := acpNeutralizeLinearSyntax @ Replace[
    Lookup[ Replace[ Lookup[ window, "AgentInfo", None ], Except[ _Association ] -> <| |> ], "Name", None ],
    Except[ _String? (StringLength[ # ] > 0 &) ] :> Replace[ Lookup[ window, "Agent", "OpenCode" ], Except[ _String ] -> "OpenCode" ]
];

agentName[ _ ] := "OpenCode";

agentName // endDefinition;


(* The text of a notice for an agent's error message (neutralized; the agent wrote it) *)
agentMessage // beginDefinition;

agentMessage[ message_, key_String ] := acpConnectionLabel[
    key,
    <| "message" -> acpNeutralizeLinearSyntax @ StringTake[ Replace[ message, Except[ _String ] -> "" ], UpTo[ 500 ] ] |>
];

agentMessage // endDefinition;


(* A folder for a notice: home abbreviated, neutralized *)
displayPath // beginDefinition;
displayPath[ path_String ] := acpNeutralizeLinearSyntax @ acpAbbreviatePath[ path, None ];
displayPath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
