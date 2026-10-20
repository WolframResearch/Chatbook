(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`Connection`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ACP`Common`" ];

(* Connection and session lifecycle: connect/resume, routing of agent messages, permissions, cancellation, config
   options, cleanup (see docs/acp-window.md, "State model" and "Threading rules").

   How this follows the runtime rules (R1-R8 in docs/acp-window.md, "Threading rules"):
   * Nothing here waits for the agent (R1). Requests are written with SendACPRequest and a string ID ("cb-<uuid>"); the
     continuation is stored in the window record ("Requests") and run by acpOnResponse when the response arrives.
   * Reader handlers (acpOnNotification, acpOnResponse, acpOnFailure, acpOnConnectionRemoved, acpOnPermissionRequest)
     run inside ACPLink's reader tick (inside its PreemptProtect). They are wrapped in acpIsolated, only update kernel
     state (acpWindowUpdate / acpTurnUpdate), write messages (SendACPRequest / SendACPResponse) and schedule work with
     acpSchedule: no front end calls, no waits, no synchronous ACPLink requests, no CloseACPConnection (R2, R3, R4).
   * Front end calls (persisted settings, notebook TaggingRules, liveness checks) happen in scheduled tasks or in the
     preemptive UI actions that call the public functions, never in handlers (R2, R8).
   * Correctness-critical timeouts have a periodic housekeeping fallback (R5): stuck connects, unanswered setup
     requests, Stop without a response, dead connections, closed windows. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$acpReadInterval       = Quantity[ 100, "Milliseconds" ]; (* ACPLink's permanent reader task *)
$acpRequestPrefix      = "cb-";
$acpConnectTimeout     = 60;  (* seconds to wait for each response of the connection setup *)
$acpConfigTimeout      = 30;  (* seconds to wait for the response to a config option change *)
$acpStopTimeout        = 10;  (* seconds after Stop without a prompt response before the turn is ended locally *)
$acpRescheduleAfter    = 15;  (* seconds after which a connection attempt that never started is scheduled again *)
$acpMaxConnectAttempts = 3;
$acpMCPReadyTimeout    = 90;  (* seconds after the session started after which MCP servers are assumed to be ready *)
$acpSessionListTimeout = 30;  (* seconds to wait for a session/list page *)
$acpSessionLoadTimeout = 60;  (* seconds to wait for the session/load response after the last replayed update *)
$acpSessionDeleteTimeout = 30; (* seconds to wait for a session/delete response *)
$acpAbandonedLoadExpiry = 600; (* seconds a session/load that timed out still waits for its late response *)
$acpMaxDetailLength    = 1500;
$acpStderrLines        = 12;
$acpClientName         = "wolfram-chatbook";
$acpClientTitle        = "Wolfram Chatbook";
(* how long a connection whose "initialize" could not be written waits for the agent's exit event (exit code and
   standard error) before it fails with "InitFailed" *)
$acpInitSendGrace      = Quantity[ 2, "Seconds" ];
(* seconds between two runs of housekeeping (normally about 1 s apart) after which the kernel counts as having been
   blocked meanwhile: that run decides no timeouts, unless the run before it decided none either (see
   connectionHousekeeping) *)
$acpStallThreshold     = 1.5;

$$setupRequestKind = "Initialize" | "SessionNew" | "SessionResume" | "Config";

(* Set to True to treat every window that has a record as open (tests without a front end use fake NotebookObjects). *)
If[ ! BooleanQ @ $acpAssumeWindowsOpen, $acpAssumeWindowsOpen = False ];

(* Test hook: None, or a function evaluated right before "initialize" is written (tests use Pause[0.5] & to let an agent
   that exits at once exit before the write) *)
$acpBeforeInitializeHook = None;

(* Connections started by this file (connection -> NotebookObject) and connections that are being closed
   (connection -> AbsoluteTime). Not reset on reload so that open connections are not orphaned. *)
If[ ! AssociationQ @ $ownedConnections  , $ownedConnections   = <| |> ];
If[ ! AssociationQ @ $closingConnections, $closingConnections = <| |> ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Connecting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpEnsureConnected*)

(* Idempotent and fast; safe to call from anywhere. If the window is not connected (or connecting), it marks it
   "Connecting" and schedules acpConnect, which does the work. A window in "Error" stays there until acpReconnect.
   Gives the window status. *)
acpEnsureConnected // beginDefinition;

acpEnsureConnected[ nbo_NotebookObject ] := Catch @ Module[ { window, validQ, token, claimed = False },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window, Throw @ Missing[ "NotFound" ] ];
    If[ connectingOrConnectedQ @ window || Lookup[ window, "Status" ] === "Error", Throw @ Lookup[ window, "Status" ] ];

    validQ = validProjectDirectoryQ[ Lookup[ window, "ProjectDirectory", None ], window ];
    token  = createUUID[ ];

    windowUpdate[
        nbo,
        Function[ w,
            Which[
                connectingOrConnectedQ @ w || Lookup[ w, "Status" ] === "Error",
                    w,
                ! validQ,
                    <| w, "Status" -> "NoDirectory" |>,
                True,
                    claimed = True;
                    <|
                        w,
                        "Status"             -> "Connecting",
                        "Error"              -> None,
                        "ConnectToken"       -> token,
                        "ConnectScheduledAt" -> AbsoluteTime[ ],
                        "ConnectAttempts"    -> 1
                    |>
            ]
        ]
    ];

    If[ claimed, With[ { t = token }, acpSchedule @ acpConnect[ nbo, t ] ] ];
    acpWindowGet[ nbo, "Status" ]
];

acpEnsureConnected // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpConnect*)

(* Runs in a scheduled task (acpSchedule). Starts the agent (OpenACPConnection, ~0.6 s) with ACPLink's permanent
   reader and sends "initialize"; the rest of the setup is done by the response continuations:
   initialize -> session/resume (if possible) or session/new -> config options (model, effort, mode) -> "Ready".
   A remote window (acpRemoteQ) starts ssh instead (Agents.wl's remoteAgentSpec): its folder is never checked or expanded
   on this computer, not even ~ (the launch script enters it, and the initialize continuation learns the absolute path
   from its markers), ACPLink holds back the launch script and "initialize" until the remote shell asks for them, and
   the folder is persisted (per host) only once the launch has entered it.
   A local window that offers the MCP server of the notebook tools (acpMCPEnabledQ: "ACPMCPServer", and with Automatic
   the agent's own program) makes sure that the kernel's server runs (MCP.wl) and gets a token for the new connection,
   which its sessions offer to the agent (acpMCPServersParam).
   Keys of remote windows' records set here and in remoteLaunched: "LaunchNonce" (per launch), "Remote" (the spec's:
   host, host key, canonical settings, the agent's command line there, install URL; no secrets), "RemoteHome",
   "RemoteAgentPath", "RemoteVerified" (the launch reached the host), "LaunchMarkers" (the launch's marker lines); every
   window: "InitSendFailedAt" (the "initialize" write failed, see initSendFailed), "LaunchProgress" (see
   observeLaunchProgress). *)
acpConnect // beginDefinition;

acpConnect[ nbo_NotebookObject, token_String ] := Catch @ Module[
    { window, remote, dir, load, agent, settings, spec, nonce, prefs, before, conn, claimed = False },

    window = acpWindowGet @ nbo;
    If[ ! currentTokenQ[ window, token ], Throw @ Null ];
    (* Another run for the same attempt (checkStuckConnect scheduled one while the first was still queued): the window
       already holds the connection that the first run opened, and a second agent would only be closed again *)
    If[ acpConnectionQ @ Lookup[ window, "Connection", None ], acpLog[ "ConnectSkipped", <| |> ]; Throw @ Null ];
    If[ ! acpWindowAliveQ @ nbo, abandonConnectAttempt[ nbo, token ]; Throw @ Null ];

    (* Free the memory of connections that are still being closed before another agent is started: *)
    closePendingConnections[ ];

    remote = acpRemoteQ @ window;
    dir    = Lookup[ window, "ProjectDirectory", None ];
    If[ ! validProjectDirectoryQ[ dir, window ], failConnectAttempt[ nbo, token, None ]; Throw @ Null ];
    (* "Raw": the stored folder is already normalized (and a restored one may end in a space). A remote ~ folder is not
       expanded with the home the window knows, which may be out of date (a host alias moved to another machine): the
       launch script resolves it with the remote $HOME, and remoteLaunched stores the absolute folder. *)
    dir = If[ remote, acpRemoteNormalizeDirectory[ dir, None, "Raw" -> True ], Quiet @ ExpandFileName @ dir ];

    load = acpLoadACPLink[ ];
    If[ FailureQ @ load, failConnectAttempt[ nbo, token, acpErrorInfo @ load ]; Throw @ Null ];

    agent    = Replace[ Lookup[ window, "Agent", "OpenCode" ], Except[ _String ] -> "OpenCode" ];
    settings = settingsOf @ window;
    spec     = acpAgentSpec[ agent, settings ];
    If[ FailureQ @ spec, failConnectAttempt[ nbo, token, acpErrorInfo @ spec ]; Throw @ Null ];
    nonce = If[ remote, acpSSHLaunchNonce[ ], None ];
    If[ remote, spec = Append[ spec, "LaunchNonce" -> nonce ] ];

    (* Front end reads/writes happen here, not in the handlers. A remote folder is not persisted yet: it is not verified,
       and a mistyped one would become the default of every new window for the host. *)
    prefs = agentPreferences @ agent;
    If[ ! remote, acpSetPersistedSetting[ "LastProjectDirectory", dir ] ];

    (* The MCP server of the notebook tools (MCP.wl; the first time, this loads AgentTools), for local windows that offer
       it. If there is none, the sessions get no MCP servers. *)
    If[ ! remote && acpMCPEnabledQ[ agent, settings ], acpMCPEnsureServer[ ] ];

    (* The window may have been closed or reset in the meantime: *)
    If[ ! currentTokenQ[ acpWindowGet @ nbo, token ], Throw @ Null ];

    before = acpLinkConnections[ ];
    conn   = openConnection[ nbo, spec, dir ];
    If[ ! acpConnectionQ @ conn,
        closeStrayConnections[ before, Lookup[ spec, "Command" ] ];
        failConnectAttempt[
            nbo,
            token,
            If[ remote,
                acpErrorInfo[ "SSHStartFailed", None, None, <| "Agent" -> spec[ "Name" ], "Host" -> spec[ "Remote", "Host" ] |> ],
                acpErrorInfo[ "ConnectFailed", None, None, <| "Agent" -> spec[ "Name" ] |> ]
            ]
        ];
        Throw @ Null
    ];
    registerConnection[ conn, nbo ];

    windowUpdate[
        nbo,
        Function[ w,
            If[ currentTokenQ[ w, token ],
                claimed = True;
                KeyDrop[
                    <|
                        w,
                        "Connection"         -> conn,
                        "ConnectDirectory"   -> dir,
                        "ConnectedAt"        -> AbsoluteTime[ ],
                        "AgentPreferences"   -> prefs,
                        "AgentInfo"          -> <| "Name" -> spec[ "Name" ], "Version" -> "" |>,
                        "Capabilities"       -> None,
                        "SessionID"          -> None,
                        "Requests"           -> <| |>,
                        "PendingPermissions" -> <| |>,
                        "Commands"           -> { },
                        "MCPReady"           -> False,
                        "ConfigAttempts"     -> <| |>,
                        "LaunchNonce"        -> nonce,
                        "LaunchMarkers"      -> None,
                        "LaunchProgress"     -> 0,
                        "Remote"             -> Lookup[ spec, "Remote", None ]
                    |>,
                    { "InitSendFailedAt" }
                ],
                w
            ]
        ]
    ];

    If[ ! claimed, releaseConnection @ conn; Throw @ Null ];

    (* The connection's token for the MCP server, before the initialize response can start a session *)
    acpMCPConnectionStarted[ nbo, conn ];

    If[ FailureQ @ sendInitialize[ nbo, conn ],
        (* The agent may have exited already (e.g. a wrong command line, or ssh rejected its arguments): its exit event,
           with the exit code and standard error, arrives within a reader tick and is reported by onAgentExited. Only
           if the window still holds the connection after the grace period, the connection fails here. *)
        windowUpdate[ nbo, Function[ w, If[ Lookup[ w, "Connection", None ] === conn, <| w, "InitSendFailedAt" -> AbsoluteTime[ ] |>, w ] ] ];
        With[ { c = conn, name = spec[ "Name" ] }, acpSchedule[ initSendFailed[ nbo, c, name ], $acpInitSendGrace ] ]
    ];

    conn
];

acpConnect // endDefinition;


(* Writes "initialize" (for a remote window ACPLink queues it until the remote shell asks for the launch script) *)
sendInitialize // beginDefinition;

sendInitialize[ nbo_NotebookObject, conn_ ] := (
    If[ $acpBeforeInitializeHook =!= None, $acpBeforeInitializeHook[ ] ];
    sendRequest[ nbo, conn, "initialize", initializeParams[ ], "Initialize", <| |> ]
);

sendInitialize // endDefinition;


(* The grace period of a failed "initialize" write is over: if the agent's exit was not reported meanwhile, the
   connection fails *)
initSendFailed // beginDefinition;

initSendFailed[ nbo_NotebookObject, conn_, name_ ] :=
    If[ acpWindowGet[ nbo, "Connection", None ] === conn,
        failConnection[ nbo, conn, acpErrorInfo[ "InitFailed", None, None, <| "Agent" -> name |> ] ]
    ];

initSendFailed // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*openConnection*)

(* The agent's environment (which may contain the LLMKit key) is only evaluated in here, and nothing that happens in
   here can be logged: messages are quieted and any exception is discarded. *)
openConnection // beginDefinition;

openConnection[ nbo_, spec_, dir_ ] := Replace[
    Quiet @ Catch[ Catch @ openConnection0[ nbo, spec, dir ], _, $Failed & ],
    Except[ _? acpConnectionQ ] -> $Failed
];

openConnection // endDefinition;


(* A remote agent (spec "Remote") is ssh running the read bootstrap in the local home folder; the launch script goes
   to its standard input as ACPLink's "StandardInputPreamble", which ACPLink holds back, with every message sent
   meanwhile ("initialize"), until the bootstrap's trigger line arrives on standard error: nothing is written to ssh
   before the remote shell reads (V2). *)
openConnection0 // beginDefinition;

openConnection0[ nbo_, spec_, dir_ ] := acpLink[ "OpenACPConnection" ][
    Lookup[ spec, "Command" ],
    ProcessDirectory              -> Replace[ Lookup[ spec, "Directory", Automatic ], Automatic -> dir ],
    ProcessEnvironment            -> Lookup[ spec, "Environment", Inherited ],
    Sequence @@ If[ AssociationQ @ Lookup[ spec, "Remote", None ],
        {
            "StandardInputPreamble"        -> sshLaunchPreamble[ spec, dir ],
            "StandardInputPreambleTrigger" -> $acpSSHLaunchTrigger
        },
        { }
    ],
    acpLink[ "ACPClientMethods" ] -> <| "session/request_permission" -> permissionMethod @ nbo |>,
    HandlerFunctions              -> connectionHandlers @ nbo,
    HandlerFunctionsKeys          -> All,
    UpdateInterval                -> $acpReadInterval
];

openConnection0 // endDefinition;


(* The launch script as UTF-8 bytes. It holds the agent's variables (the LLMKit key), so it is only ever built here,
   where openConnection discards anything thrown and quiets every message. *)
sshLaunchPreamble // beginDefinition;

sshLaunchPreamble[ spec_Association, dir_String ] := Module[ { script },
    script = acpSSHLaunchScript[
        Lookup[ spec, "LaunchNonce", None ],
        dir,
        spec[ "Remote", "AgentCommand" ],
        Replace[ Lookup[ spec, "Variables", <| |> ], Except[ _Association ] -> <| |> ]
    ];
    If[ ! StringQ @ script, Throw[ script, $sshLaunchPreambleTag ] ];
    StringToByteArray[ script, "UTF-8" ]
];

sshLaunchPreamble // endDefinition;


connectionHandlers // beginDefinition;

connectionHandlers[ nbo_NotebookObject ] := <|
    "NotificationReceived" -> Function[ event, acpOnNotification[ nbo, event ] ],
    "ResponseReceived"     -> Function[ event, acpOnResponse[ nbo, event ] ],
    "FailureOccurred"      -> Function[ event, acpOnFailure[ nbo, event ] ],
    "TaskFinished"         -> Function[ event, acpOnConnectionRemoved[ nbo, event ] ],
    "TaskRemoved"          -> Function[ event, acpOnConnectionRemoved[ nbo, event ] ]
|>;

connectionHandlers // endDefinition;


permissionMethod // beginDefinition;
permissionMethod[ nbo_NotebookObject ] := Function[ request, acpOnPermissionRequest[ nbo, request ] ];
permissionMethod // endDefinition;


initializeParams // beginDefinition;

(* No fs/terminal methods; elicitation, compaction and child-session updates are not advertised. *)
initializeParams[ ] := <|
    "protocolVersion"    -> 1,
    "clientCapabilities" -> <| "fs" -> <| "readTextFile" -> False, "writeTextFile" -> False |>, "terminal" -> False |>,
    "clientInfo"         -> <| "name" -> $acpClientName, "title" -> $acpClientTitle, "version" -> chatbookVersion[ ] |>
|>;

initializeParams // endDefinition;


chatbookVersion // beginDefinition;
chatbookVersion[ ] := Replace[ Quiet @ $thisPaclet[ "Version" ], Except[ _String ] -> "0" ];
chatbookVersion // endDefinition;


(* Persisted per-agent choices (front end reads; only called from acpConnect) *)
agentPreferences // beginDefinition;

agentPreferences[ agent_String ] := <|
    "LastModel"  -> Replace[ acpPersistedSetting[ { "LastModel" , agent }, None ], Except[ _String ] -> None ],
    "LastEffort" -> Replace[ acpPersistedSetting[ { "LastEffort", agent }, None ], Except[ _String ] -> None ]
|>;

agentPreferences // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Connection attempt failures*)
failConnectAttempt // beginDefinition;

(* error === None means the project directory is missing *)
failConnectAttempt[ nbo_NotebookObject, token_String, error_ ] :=
    windowUpdate[ nbo, Function[ w, If[ currentTokenQ[ w, token ], connectionFailedRecord[ w, error ], w ] ] ];

failConnectAttempt // endDefinition;


abandonConnectAttempt // beginDefinition;

abandonConnectAttempt[ nbo_NotebookObject, token_String ] := windowUpdate[
    nbo,
    Function[ w, If[ currentTokenQ[ w, token ], <| w, "ConnectToken" -> None, "Status" -> "Disconnected" |>, w ] ]
];

abandonConnectAttempt // endDefinition;


(* An open that failed after ACPLink had registered the connection (e.g. something threw after the agent was started)
   would leave the agent running with no owner: connections that appeared during this window's open and run its command
   line are closed. Other connections of the kernel (open before, or with another command line) are left alone. *)
closeStrayConnections // beginDefinition;

closeStrayConnections[ before_List, command_ ] := Scan[
    (acpLog[ "StrayConnection", # ]; releaseConnection @ #) &,
    Select[ Complement[ acpLinkConnections[ ], before ], Quiet[ #[ "ProcessCommandLine" ] ] === command & ]
];

closeStrayConnections // endDefinition;


(* A connection failed during setup (or its session could not be created): close it and show the error. *)
failConnection // beginDefinition;

failConnection[ nbo_NotebookObject, conn_, error_ ] := Module[ { window },
    window = acpWindowGet @ nbo;
    If[ AssociationQ @ window && Lookup[ window, "Connection", None ] === conn,
        endSentTurn[ nbo, window, <| "Error" -> error |> ];
        windowUpdate[ nbo, Function[ w, If[ Lookup[ w, "Connection", None ] === conn, connectionFailedRecord[ w, error ], w ] ] ]
    ];
    releaseConnection @ conn;
    (* the code and the exit code only, never stderr *)
    acpLog[ "ConnectionFailed", <|
        "Code"     -> Replace[ error, { KeyValuePattern[ "Code" -> c_ ] :> c, _ -> None } ],
        "ExitCode" -> Replace[ error, { KeyValuePattern[ "Data" -> KeyValuePattern[ "ExitCode" -> c_ ] ] :> c, _ -> None } ]
    |> ];
    Null
];

failConnection // endDefinition;


connectionFailedRecord // beginDefinition;

connectionFailedRecord[ w_Association, error_ ] := <|
    w,
    "Status"             -> If[ error === None, "NoDirectory", "Error" ],
    "Error"              -> error,
    "Connection"         -> None,
    "ConnectToken"       -> None,
    "SessionID"          -> None,
    "Requests"           -> <| |>,
    "PendingPermissions" -> <| |>,
    "MCPReady"           -> False,
    "Restore"            -> loadingDropped @ w,
    "PendingRestore"     -> None
|>;

connectionFailedRecord // endDefinition;


(* A restore whose session is still loading ends with the connection; one that is being written is finished (the
   replay is complete) *)
loadingDropped // beginDefinition;
loadingDropped[ w_Association ] := Replace[ Lookup[ w, "Restore", None ], { r_Association /; r[ "Stage" ] === "Writing" :> r, _ -> None } ];
loadingDropped // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Requests*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sendRequest*)

(* Records the continuation (kind + data) in the window's "Requests" first, then writes the request (synchronously, with
   a string ID that can never collide with the agent's integer request IDs). Gives the ID or a Failure. *)
sendRequest // beginDefinition;

sendRequest[ nbo_, conn_, method_, params_, kind_, data_ ] :=
    sendRequest[ nbo, conn, method, params, kind, data, $acpRequestPrefix <> createUUID[ ] ];

sendRequest[ nbo_NotebookObject, conn_, method_String, params_Association, kind_String, data_Association, id_String ] :=
    Module[ { sent },
        windowUpdate[
            nbo,
            Function[ w,
                <|
                    w,
                    "Requests" -> Append[
                        requestsOf @ w,
                        id -> <| "Kind" -> kind, "Method" -> method, "Data" -> data, "Connection" -> conn, "SentAt" -> AbsoluteTime[ ] |>
                    ]
                |>
            ]
        ];
        sent = writeRequest[ conn, method, params, id ];
        If[ sentRequestQ @ sent,
            id,
            dropRequest[ nbo, id ];
            acpLog[ "SendFailed", <| "Method" -> method, "ID" -> id |> ];
            Failure[ "SendFailed", <| "Method" -> method, "ID" -> id |> ]
        ]
    ];

sendRequest // endDefinition;


writeRequest // beginDefinition;

writeRequest[ conn_? acpConnectionQ, method_String, params_Association, id_String ] := Quiet @ Catch[
    acpLink[ "SendACPRequest" ][ conn, acpLink[ "ACPRequest" ][ <| "Method" -> method, "ID" -> id, "Parameters" -> params |> ] ],
    _,
    $Failed &
];

writeRequest[ ___ ] := $Failed;

writeRequest // endDefinition;


(* A request whose response nobody waits for (e.g. session/close) *)
sendWithoutContinuation // beginDefinition;
sendWithoutContinuation[ conn_, method_String, params_Association ] := writeRequest[ conn, method, params, $acpRequestPrefix <> createUUID[ ] ];
sendWithoutContinuation // endDefinition;


sentRequestQ // beginDefinition;
sentRequestQ[ h_Symbol[ KeyValuePattern[ "ID" -> _ ] ] ] := SymbolName @ h === "ACPRequest";
sentRequestQ[ _ ] := False;
sentRequestQ // endDefinition;


dropRequest // beginDefinition;
dropRequest[ nbo_NotebookObject, id_ ] := windowUpdate[ nbo, Function[ w, <| w, "Requests" -> KeyDrop[ requestsOf @ w, { id } ] |> ] ];
dropRequest // endDefinition;


(* Removes the request with this ID from the window's "Requests" and gives its record (or Missing) *)
takeRequest // beginDefinition;

takeRequest[ nbo_NotebookObject, id_ ] := Module[ { info = Missing[ "NotFound" ] },
    windowUpdate[
        nbo,
        Function[ w,
            With[ { requests = requestsOf @ w },
                If[ KeyExistsQ[ requests, id ],
                    info = requests[ id ];
                    <| w, "Requests" -> KeyDrop[ requests, { id } ] |>,
                    Missing[ "NotFound" ] (* leaves the record unchanged *)
                ]
            ]
        ]
    ];
    info
];

takeRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Handlers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpOnNotification*)

(* Connection-level "NotificationReceived" (session/update, $/cancel_request). Events of a connection that is no longer
   the window's (closed or replaced) are ignored. *)
acpOnNotification // beginDefinition;
acpOnNotification[ nbo_, event_ ] := (acpIsolated @ onNotification[ nbo, event ]; Null);
acpOnNotification // endDefinition;


onNotification // beginDefinition;

onNotification[ nbo_NotebookObject, event_Association ] := Module[ { window, conn, data, params, time },
    window = acpWindowGet @ nbo;
    conn   = Lookup[ event, "Connection", None ];
    If[ ! AssociationQ @ window || Lookup[ window, "Connection", None ] =!= conn,
        acpLog[ "StaleNotification", <| "Method" -> Lookup[ messageData @ Lookup[ event, "Message", None ], "Method", None ] |> ];
        Return[ Null, Module ]
    ];
    data   = messageData @ Lookup[ event, "Message", None ];
    params = Replace[ Lookup[ data, "Parameters", <| |> ], Except[ _Association ] -> <| |> ];
    time   = AbsoluteTime[ ];
    Switch[ Lookup[ data, "Method", None ],
        "session/update"  , onSessionUpdate[ nbo, window, params, time ],
        "$/cancel_request", onCancelRequest[ nbo, window, conn, params, time ],
        _                 , acpLog[ "UnhandledNotification", Lookup[ data, "Method", None ] ]
    ]
];

onNotification[ _, _ ] := Null;

onNotification // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*onSessionUpdate*)
onSessionUpdate // beginDefinition;

onSessionUpdate[ nbo_, window_, params_, time_ ] := Module[ { sid, update, own },
    sid    = Lookup[ params, "sessionId", None ];
    update = Replace[ Lookup[ params, "update", <| |> ], Except[ _Association ] -> <| |> ];
    If[ StringQ @ sid && sid === loadingSessionID @ window, Return[ onReplayUpdate[ nbo, window, update, time ], Module ] ];
    own    = StringQ @ sid && sid === Lookup[ window, "SessionID", None ];
    Switch[ Lookup[ update, "sessionUpdate", None ],
        "available_commands_update",
            If[ own, setCommands[ nbo, Lookup[ update, "availableCommands", { } ] ] ],
        "config_option_update",
            If[ own, mergeConfigOptions[ nbo, Lookup[ update, "configOptions", { } ] ] ],
        "current_mode_update",
            If[ own, setCurrentMode[ nbo, Lookup[ update, "currentModeId", None ] ] ],
        "usage_update",
            If[ own, setUsage[ nbo, update ] ];
            applyToTurn[ nbo, window, sid, update, time ],
        _,
            applyToTurn[ nbo, window, sid, update, time ]
    ]
];

onSessionUpdate // endDefinition;


(* The session whose session/load is outstanding (its replay is collected, see Sessions.wl), or None *)
loadingSessionID // beginDefinition;

loadingSessionID[ window_Association ] := Replace[
    Lookup[ window, "Restore", None ],
    { KeyValuePattern @ { "Stage" -> "Loading", "SessionID" -> sid_String } :> sid, _ -> None }
];

loadingSessionID[ _ ] := None;

loadingSessionID // endDefinition;


(* An update of the session that is being loaded: the replayed history goes to the restore's accumulator (Sessions.wl).
   OpenCode sends the window-level updates (commands, config options) only after the load response; commands that
   arrive earlier are applied like the window's own, config option, mode and usage updates are left to the load
   response. *)
onReplayUpdate // beginDefinition;

onReplayUpdate[ nbo_, window_, update_Association, time_ ] := Switch[ Lookup[ update, "sessionUpdate", None ],
    "available_commands_update",
        setCommands[ nbo, Lookup[ update, "availableCommands", { } ] ],
    "config_option_update" | "current_mode_update" | "usage_update",
        acpLog[ "ReplayUpdateIgnored", Lookup[ update, "sessionUpdate", None ] ],
    _,
        acpRestoreAppendUpdate[ nbo, window[ "Restore", "Token" ], update, time ]
];

onReplayUpdate // endDefinition;


(* Updates go to the window's current turn if it belongs to that session (and is not being finalized). A tool call that
   completed and may have changed files marks the window's git summary stale (Git.wl). *)
applyToTurn // beginDefinition;

applyToTurn[ nbo_, window_, sid_, update_Association, time_ ] := Module[ { turnID, turn },
    turnID = Lookup[ window, "CurrentTurn", None ];
    turn   = If[ StringQ @ turnID, acpTurnGet @ turnID, None ];
    If[ AssociationQ @ turn && Lookup[ turn, "SessionID", None ] === sid && ! TrueQ @ Lookup[ turn, "FinalizeClaimed", False ],
        acpTurnUpdate[ turnID, acpApplyUpdate[ #, update, time ] & ];
        acpGitNoteSessionUpdate[ nbo, turnID, update ],
        acpLog[ "UpdateWithoutTurn", <| "Kind" -> Lookup[ update, "sessionUpdate", None ], "SessionID" -> sid |> ]
    ]
];

applyToTurn // endDefinition;


(* MCP servers are ready once their prompts appear as commands (named "Server:Prompt", e.g. "Wolfram:Search") *)
setCommands // beginDefinition;

setCommands[ nbo_, commands0_ ] := With[ { commands = Select[ Replace[ commands0, Except[ _List ] -> { } ], AssociationQ ] },
    windowUpdate[
        nbo,
        Function[ w,
            <|
                w,
                "Commands" -> commands,
                "MCPReady" -> TrueQ @ Lookup[ w, "MCPReady", False ] || mcpCommandsQ @ commands
            |>
        ]
    ]
];

setCommands // endDefinition;


mcpCommandsQ // beginDefinition;
mcpCommandsQ[ commands_List ] := AnyTrue[ commands, StringQ[ Lookup[ #, "name", None ] ] && StringContainsQ[ #[ "name" ], ":" ] & ];
mcpCommandsQ // endDefinition;


mergeConfigOptions // beginDefinition;

mergeConfigOptions[ nbo_, new0_ ] := With[ { new = Select[ Replace[ new0, Except[ _List ] -> { } ], AssociationQ ] },
    If[ new =!= { },
        windowUpdate[ nbo, Function[ w, <| w, "ConfigOptions" -> mergeOptions[ configOptionsOf @ w, new ] |> ] ]
    ]
];

mergeConfigOptions // endDefinition;


(* Options with the same id are replaced in place; new ones are appended *)
mergeOptions // beginDefinition;

mergeOptions[ old_List, new_List ] := Module[ { byID, oldIDs },
    byID   = Association @ Cases[ new, o: KeyValuePattern[ "id" -> id_ ] :> (id -> o) ];
    oldIDs = Lookup[ old, "id", None ];
    Join[
        Replace[ old, KeyValuePattern[ "id" -> id_ ] /; KeyExistsQ[ byID, id ] :> byID[ id ], { 1 } ],
        Select[ new, ! MemberQ[ oldIDs, Lookup[ #, "id", None ] ] & ]
    ]
];

mergeOptions // endDefinition;


setCurrentMode // beginDefinition;

setCurrentMode[ nbo_, mode_String ] := windowUpdate[
    nbo,
    Function[ w,
        <|
            w,
            "ConfigOptions" -> Replace[
                configOptionsOf @ w,
                o_Association /; Lookup[ o, "category" ] === "mode" || Lookup[ o, "id" ] === "mode" :> <| o, "currentValue" -> mode |>,
                { 1 }
            ]
        |>
    ]
];

setCurrentMode[ _, _ ] := Null;

setCurrentMode // endDefinition;


setUsage // beginDefinition;
setUsage[ nbo_, update_Association ] := windowUpdate[ nbo, Function[ w, <| w, "Usage" -> KeyTake[ update, { "used", "size", "cost" } ] |> ] ];
setUsage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*onCancelRequest*)

(* $/cancel_request: the agent withdrew one of its requests (e.g. a permission request made moot by "Always allow" or by
   Stop). The card is removed; the tool's own updates decide its status. The request is answered "cancelled" (the
   fixed ACPLink answers it itself before delivering the notification; then this second answer is refused, harmlessly). *)
onCancelRequest // beginDefinition;

onCancelRequest[ nbo_, _, conn_, params_, time_ ] := Module[ { reqID, info },
    reqID = Lookup[ params, "requestId", None ];
    info  = takePendingPermission[ nbo, reqID ];
    If[ AssociationQ @ info,
        If[ StringQ @ info[ "TurnID" ], acpTurnUpdate[ info[ "TurnID" ], acpApplyPermissionWithdrawn[ #, reqID, time ] & ] ];
        answerOutcome[ conn, reqID, None ],
        acpLog[ "CancelRequestIgnored", <| "RequestID" -> reqID |> ]
    ]
];

onCancelRequest // endDefinition;


(* Removes a pending permission request from the window and gives its record (or Missing) *)
takePendingPermission // beginDefinition;

takePendingPermission[ nbo_NotebookObject, reqID_ ] := Module[ { info = Missing[ "NotPending" ] },
    windowUpdate[
        nbo,
        Function[ w,
            With[ { pending = pendingOf @ w },
                If[ KeyExistsQ[ pending, reqID ],
                    info = pending[ reqID ];
                    <| w, "PendingPermissions" -> KeyDrop[ pending, { reqID } ] |>,
                    Missing[ "NotPending" ]
                ]
            ]
        ]
    ];
    info
];

takePendingPermission // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpOnResponse*)

(* Connection-level "ResponseReceived": runs the continuation recorded by sendRequest. Error responses are handled
   here only (ACPLink also reports them as "FailureOccurred"; that one is just logged), so each error is shown once. *)
acpOnResponse // beginDefinition;
acpOnResponse[ nbo_, event_ ] := (acpIsolated @ onResponse[ nbo, event ]; Null);
acpOnResponse // endDefinition;


onResponse // beginDefinition;

onResponse[ nbo_NotebookObject, event_Association ] := Module[ { data, id, conn, info },
    data = messageData @ Lookup[ event, "Message", None ];
    id   = Lookup[ data, "ID", None ];
    conn = Lookup[ event, "Connection", None ];
    info = takeRequest[ nbo, id ];
    Which[
        ! AssociationQ @ info,
            acpLog[ "UnmatchedResponse", <| "ID" -> id |> ],
        info[ "Connection" ] =!= conn || acpWindowGet[ nbo, "Connection", None ] =!= conn,
            acpLog[ "StaleResponse", <| "ID" -> id, "Kind" -> info[ "Kind" ] |> ],
        True,
            onRequestResponse[ info[ "Kind" ], nbo, conn, info, responseOf @ data, AbsoluteTime[ ] ]
    ]
];

onResponse[ _, _ ] := Null;

onResponse // endDefinition;


(* <| "Error" -> False, "Result" -> _ |> or <| "Error" -> True, "Code", "Message", "Data" |> *)
responseOf // beginDefinition;

responseOf[ data_Association ] :=
    If[ KeyExistsQ[ data, "ErrorCode" ] || KeyExistsQ[ data, "ErrorMessage" ],
        <|
            "Error"   -> True,
            "Code"    -> Lookup[ data, "ErrorCode", None ],
            "Message" -> Lookup[ data, "ErrorMessage", None ],
            "Data"    -> Lookup[ data, "ErrorData", None ]
        |>,
        <| "Error" -> False, "Result" -> Replace[ Lookup[ data, "Result", <| |> ], Except[ _Association ] -> <| |> ] |>
    ];

responseOf // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*onRequestResponse*)
onRequestResponse // beginDefinition;

(* initialize -> session *)
onRequestResponse[ "Initialize", nbo_, conn_, _, resp_, _ ] := Module[ { window, result, agentInfo, caps },
    window = acpWindowGet @ nbo;
    If[ TrueQ @ resp[ "Error" ],
        failConnection[ nbo, conn, responseError[ window, resp, "InitFailed" ] ];
        Return[ Null, Module ]
    ];
    result    = resp[ "Result" ];
    agentInfo = Replace[ Lookup[ result, "agentInfo", <| |> ], Except[ _Association ] -> <| |> ];
    caps      = Replace[ Lookup[ result, "agentCapabilities", <| |> ], Except[ _Association ] -> <| |> ];
    windowUpdate[
        nbo,
        Function[ w,
            If[ Lookup[ w, "Connection", None ] === conn,
                <|
                    w,
                    "AgentInfo"       -> agentInfoOf[ agentInfo, w ],
                    "Capabilities"    -> caps,
                    "ProtocolVersion" -> Lookup[ result, "protocolVersion", None ]
                |>,
                w
            ]
        ]
    ];
    If[ acpRemoteQ @ window && ! remoteLaunched[ nbo, conn, acpWindowGet @ nbo ], Return[ Null, Module ] ];
    startSession[ nbo, conn ]
];

(* session/resume: fall back to session/new (the agent then doesn't remember the transcript) *)
onRequestResponse[ "SessionResume", nbo_, conn_, info_, resp_, time_ ] := Module[ { window },
    window = acpWindowGet @ nbo;
    Which[
        TrueQ @ resp[ "Error" ],
            acpLog[ "ResumeFailed", <| "Code" -> resp[ "Code" ], "Message" -> resp[ "Message" ] |> ];
            windowUpdate[
                nbo,
                <|
                    #,
                    "ResumableSessionID" -> None,
                    "Notice" -> acpConnectionLabel[ "NoticeSessionNotResumed", <| "agent" -> agentDisplayName @ window |> ]
                |> &
            ];
            newSession[ nbo, conn ],
        TrueQ @ Lookup[ window, "NewSessionRequested", False ],
            newSession[ nbo, conn ],
        True,
            sessionEstablished[ nbo, conn, info[ "Data", "SessionID" ], Lookup[ resp[ "Result" ], "configOptions", None ], "Resumed", time ]
    ]
];

onRequestResponse[ "SessionNew", nbo_, conn_, _, resp_, time_ ] := Module[ { window, sid },
    window = acpWindowGet @ nbo;
    If[ TrueQ @ resp[ "Error" ],
        failConnection[ nbo, conn, responseError[ window, resp, "SessionFailed" ] ];
        Return[ Null, Module ]
    ];
    sid = Lookup[ resp[ "Result" ], "sessionId", None ];
    If[ ! StringQ @ sid,
        failConnection[ nbo, conn, acpErrorInfo[ "SessionFailed", None, None, <| "Agent" -> agentDisplayName @ window |> ] ];
        Return[ Null, Module ]
    ];
    sessionEstablished[ nbo, conn, sid, Lookup[ resp[ "Result" ], "configOptions", None ], "New", time ]
];

(* A config option set while setting up the session; continues with the next one *)
onRequestResponse[ "Config", nbo_, conn_, info_, resp_, _ ] := (
    applyConfigResponse[ nbo, info[ "Data" ], resp ];
    continueConfiguration[ nbo, conn ]
);

(* A config option the user changed *)
onRequestResponse[ "SetConfig", nbo_, _, info_, resp_, _ ] :=
    applyConfigResponse[ nbo, info[ "Data" ], resp ];

onRequestResponse[ "Prompt", nbo_, _, info_, resp_, time_ ] :=
    onPromptResponse[ nbo, info[ "Data", "TurnID" ], resp, time ];

(* Sessions (Sessions.wl) *)
onRequestResponse[ "SessionLoad", nbo_, conn_, info_, resp_, time_ ] :=
    onSessionLoadResponse[ nbo, conn, info[ "Data" ], resp, time ];

onRequestResponse[ "SessionList", nbo_, _, info_, resp_, time_ ] :=
    acpSessionsOnListResponse[ nbo, info[ "Data" ], resp, time ];

onRequestResponse[ "SessionDelete", nbo_, _, info_, resp_, _ ] :=
    acpSessionsOnDeleteResponse[ nbo, info[ "Data" ], resp ];

onRequestResponse[ "AbandonedLoad", nbo_, conn_, info_, resp_, _ ] :=
    onAbandonedLoadResponse[ nbo, conn, info[ "Data" ], resp ];

onRequestResponse[ "Ignore", ___ ] := Null;

onRequestResponse[ kind_, ___ ] := acpLog[ "UnknownRequestKind", kind ];

onRequestResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Remote launch*)

(* The agent of a remote window answered "initialize", so the launch script entered the folder: its markers on ssh's
   standard error give the remote home, the absolute folder ($PWD, also for a ~ folder) and the agent's path (each checked
   with acpRemoteAbsolutePathQ). The session is created with that folder, which also replaces a ~ folder in the window
   and is persisted as the host's last folder (front end writes are scheduled: this is a reader handler). Gives False
   (the connection failed) if no absolute folder is known. *)
remoteLaunched // beginDefinition;

remoteLaunched[ nbo_NotebookObject, conn_, window_Association ] := Module[ { stderr, launch, cwd, home, ssh },
    stderr = Replace[ Quiet @ conn[ "StandardError" ], Except[ _String ] -> "" ];
    launch = acpSSHLaunchMarkers[ Replace[ Lookup[ window, "LaunchNonce", None ], Except[ _String ] -> "" ], stderr ];
    cwd    = Which[
        acpRemoteAbsolutePathQ @ launch[ "Cwd" ], launch[ "Cwd" ],
        acpRemoteAbsolutePathQ @ Lookup[ window, "ConnectDirectory", None ], window[ "ConnectDirectory" ],
        True, None
    ];
    If[ cwd === None,
        failConnection[ nbo, conn, acpErrorInfo[ "SessionFailed", None, None, <| "Agent" -> agentDisplayName @ window |> ] ];
        Return[ False, Module ]
    ];
    home = launch[ "Home" ];
    windowUpdate[
        nbo,
        Function[ w,
            If[ Lookup[ w, "Connection", None ] === conn,
                <|
                    w,
                    "ConnectDirectory" -> cwd,
                    "RemoteHome"       -> Replace[ home, None :> Lookup[ w, "RemoteHome", None ] ],
                    "RemoteAgentPath"  -> launch[ "Agent" ],
                    "RemoteVerified"   -> True,
                    "LaunchMarkers"    -> launchMarkerText[ Lookup[ w, "LaunchNonce", None ], launch ],
                    If[ Lookup[ w, "ProjectDirectory", None ] =!= cwd, "ProjectDirectory" -> cwd, Nothing ]
                |>,
                w
            ]
        ]
    ];
    (* The launch reached the agent: the host's failure latch (Remote.wl) is over *)
    If[ StringQ @ launch[ "Agent" ], acpRemoteClearHostError @ acpWindowHostKey @ window ];
    ssh = acpWindowSSH @ window;
    If[ Lookup[ window, "ProjectDirectory", None ] =!= cwd, acpSchedule @ acpFESet[ nbo, "ProjectDirectory", cwd ] ];
    With[ { key = acpLastProjectDirectoryKey @ ssh },
        If[ ListQ @ key && AssociationQ @ ssh, acpSchedule @ acpSetPersistedSetting[ key, cwd ] ]
    ];
    With[ { key = acpRemoteHomeKey @ ssh },
        If[ ListQ @ key && StringQ @ home, acpSchedule @ acpSetPersistedSetting[ key, home ] ]
    ];
    True
];

remoteLaunched // endDefinition;


(* The launch's markers as lines of standard error, kept in the window record ("LaunchMarkers"): ACPLink reports only the
   end of standard error when the agent exits, so a long-running agent's markers are added back for the classification
   of its exit (remoteExitError). Paths only, no secrets. *)
launchMarkerText // beginDefinition;

launchMarkerText[ nonce_String, launch_Association ] := StringJoin @ KeyValueMap[
    If[ StringQ @ #2, $acpSSHMarkerPrefix <> nonce <> ":" <> #1 <> ":" <> #2 <> "\n", "" ] &,
    <| "home" -> launch[ "Home" ], "cwd" -> launch[ "Cwd" ], "agent" -> launch[ "Agent" ] |>
];

launchMarkerText[ _, _ ] := None;

launchMarkerText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Sessions*)
startSession // beginDefinition;

(* session/load of a pending restore (Sessions.wl: a session of another folder, or of a window that was not connected), or
   session/resume of the window's session, or session/new. *)
startSession[ nbo_NotebookObject, conn_ ] := Module[ { window, dir, resumeID, resumeDir, pending, sent },
    window    = acpWindowGet @ nbo;
    dir       = Lookup[ window, "ConnectDirectory", None ];
    resumeID  = Lookup[ window, "ResumableSessionID", None ];
    resumeDir = Replace[ Lookup[ window, "ResumableDirectory", None ], Except[ _String ] -> dir ];
    pending   = Lookup[ window, "PendingRestore", None ];
    If[ MatchQ[ pending, KeyValuePattern @ { "SessionID" -> _String, "Cwd" -> _String } ] && ! TrueQ @ Lookup[ window, "NewSessionRequested", False ],
        If[ acpSessionsCapabilities[ window ][ "Load" ],
            Return[ sendSessionLoad[ nbo, conn, pending[ "SessionID" ], pending[ "Cwd" ], "Setup", None ], Module ],
            windowUpdate[
                nbo,
                <| #, "PendingRestore" -> None, "Notice" -> acpConnectionLabel[ "NoticeSessionLoadUnsupported", <| "agent" -> agentDisplayName @ window |> ] |> &
            ]
        ]
    ];
    If[ AssociationQ @ pending, windowUpdate[ nbo, <| #, "PendingRestore" -> None |> & ] ];
    sent = If[ StringQ @ resumeID && resumeDir === dir && resumeCapableQ @ window && ! TrueQ @ Lookup[ window, "NewSessionRequested", False ],
        sendRequest[
            nbo,
            conn,
            "session/resume",
            <| "sessionId" -> resumeID, "cwd" -> dir, "mcpServers" -> acpMCPServersParam @ window |>,
            "SessionResume",
            <| "SessionID" -> resumeID |>
        ],
        sendNewSession[ nbo, conn, dir ]
    ];
    If[ FailureQ @ sent,
        failConnection[ nbo, conn, acpErrorInfo[ "SessionFailed", None, None, <| "Agent" -> agentDisplayName @ window |> ] ]
    ]
];

startSession // endDefinition;


newSession // beginDefinition;

newSession[ nbo_NotebookObject, conn_ ] := Module[ { window, sent },
    window = acpWindowGet @ nbo;
    sent = sendNewSession[ nbo, conn, Lookup[ window, "ConnectDirectory", None ] ];
    If[ FailureQ @ sent,
        failConnection[ nbo, conn, acpErrorInfo[ "SessionFailed", None, None, <| "Agent" -> agentDisplayName @ window |> ] ]
    ]
];

newSession // endDefinition;


(* The MCP servers of session/new, session/load and session/resume: MCP.wl's notebook tools server for a local window
   whose agent supports HTTP MCP servers, else none (acpMCPServersParam, a pure lookup) *)
sendNewSession // beginDefinition;
sendNewSession[ nbo_, conn_, dir_String ] := sendRequest[ nbo, conn, "session/new", <| "cwd" -> dir, "mcpServers" -> acpMCPServersParam @ nbo |>, "SessionNew", <| |> ];
sendNewSession[ _, _, _ ] := Failure[ "NoDirectory", <| |> ];
sendNewSession // endDefinition;


resumeCapableQ // beginDefinition;
resumeCapableQ[ window_Association ] := MatchQ[ Lookup[ window, "Capabilities", None ], KeyValuePattern[ "sessionCapabilities" -> KeyValuePattern[ "resume" -> _Association ] ] ];
resumeCapableQ[ _ ] := False;
resumeCapableQ // endDefinition;


closeCapableQ // beginDefinition;
closeCapableQ[ window_Association ] := MatchQ[ Lookup[ window, "Capabilities", None ], KeyValuePattern[ "sessionCapabilities" -> KeyValuePattern[ "close" -> _Association ] ] ];
closeCapableQ[ _ ] := False;
closeCapableQ // endDefinition;


(* The session exists: remember it (also in the notebook, for resuming after a kernel restart) and apply config options.
   how: "New", "Resumed" or "Loaded" (a restored session, Sessions.wl). *)
sessionEstablished // beginDefinition;

sessionEstablished[ nbo_NotebookObject, conn_, sid_String, options_, how_String, time_ ] := (
    windowUpdate[
        nbo,
        Function[ w,
            If[ Lookup[ w, "Connection", None ] =!= conn,
                w,
                <|
                    w,
                    "SessionID"           -> sid,
                    "ResumableSessionID"  -> sid,
                    "ResumableDirectory"  -> Lookup[ w, "ConnectDirectory", None ],
                    "ConfigOptions"       -> If[ ListQ @ options, Select[ options, AssociationQ ], configOptionsOf @ w ],
                    "SessionStartedAt"    -> time,
                    "PendingPermissions"  -> <| |>,
                    "NewSessionRequested" -> False,
                    "Usage"               -> If[ how === "Resumed", Lookup[ w, "Usage", None ], None ],
                    "SessionOrigin"       -> how,
                    "ConfigAttempts"      -> <| |>
                |>
            ]
        ]
    ];
    acpSchedule @ acpFESet[ nbo, "ResumableSessionID", sid ];
    continueConfiguration[ nbo, conn ]
);

sessionEstablished[ nbo_, conn_, _, _, _, _ ] :=
    failConnection[ nbo, conn, acpErrorInfo[ "SessionFailed", None, None, <| "Agent" -> agentDisplayName @ acpWindowGet @ nbo |> ] ];

sessionEstablished // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Config options during setup*)

(* Applies the next needed config option (model, then effort, then mode), one request at a time; "Ready" when done. *)
continueConfiguration // beginDefinition;

continueConfiguration[ nbo_NotebookObject, conn_ ] := Module[ { window, step, sent },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window || Lookup[ window, "Connection", None ] =!= conn, Return[ Null, Module ] ];
    step = nextConfigStep @ window;
    If[ MatchQ[ step, { _String, _, _String } ],
        windowUpdate[ nbo, Function[ w, <| w, "ConfigAttempts" -> Append[ Lookup[ w, "ConfigAttempts", <| |> ], step[[ 1 ]] -> step[[ 2 ]] ] |> ] ];
        sent = sendRequest[
            nbo,
            conn,
            "session/set_config_option",
            <| "sessionId" -> Lookup[ window, "SessionID", None ], "configId" -> step[[ 1 ]], "value" -> step[[ 2 ]] |>,
            "Config",
            <| "ConfigID" -> step[[ 1 ]], "Value" -> step[[ 2 ]], "Origin" -> step[[ 3 ]], "SessionID" -> Lookup[ window, "SessionID", None ] |>
        ];
        If[ FailureQ @ sent, continueConfiguration[ nbo, conn ] ],
        becomeReady[ nbo, conn ]
    ]
];

continueConfiguration // endDefinition;


(* { configId, value, origin } or None. A new session gets the preferred model and effort; a loaded (restored) or resumed
   session keeps its own (set_config_option would also move it to the top of the agent's session list): only choices
   the user made while it was being set up are applied. *)
nextConfigStep // beginDefinition;

nextConfigStep[ window_Association ] := Module[ { options, pending, attempts, prefs, settings, requested, own, steps },
    options   = configOptionsOf @ window;
    pending   = pendingConfigOf @ window;
    attempts  = Replace[ Lookup[ window, "ConfigAttempts", <| |> ], Except[ _Association ] -> <| |> ];
    prefs     = Replace[ Lookup[ window, "AgentPreferences", <| |> ], Except[ _Association ] -> <| |> ];
    settings  = settingsOf @ window;
    requested = Replace[ Lookup[ window, "UserModel", None ], Except[ _String ] :> Lookup[ settings, "ACPModel", None ] ];
    own       = MemberQ[ { "Loaded", "Resumed" }, Lookup[ window, "SessionOrigin", None ] ];
    steps = {
        configTarget[
            acpFindConfigOption[ options, "model" ],
            pending,
            If[ own,
                None,
                acpPreferredModel[
                    options,
                    <|
                        "Requested"    -> requested,
                        "LastUsed"     -> Lookup[ prefs, "LastModel", None ],
                        "FailedModels" -> failedModelsOf @ window
                    |>
                ]
            ]
        ],
        configTarget[ acpFindConfigOption[ options, "thought_level" ], pending, If[ own, None, Lookup[ prefs, "LastEffort", None ] ] ],
        configTarget[ acpFindConfigOption[ options, "mode" ], pending, None ]
    };
    FirstCase[ steps, step: { id_String, value_, _ } /; Lookup[ attempts, id, Missing[ ] ] =!= value :> step, None ]
];

nextConfigStep // endDefinition;


configTarget // beginDefinition;

configTarget[ option_Association, pending_Association, default_ ] := Module[ { id, current, target, origin },
    id      = Lookup[ option, "id", None ];
    current = Lookup[ option, "currentValue", None ];
    If[ KeyExistsQ[ pending, id ],
        target = pending[ id ]; origin = "User",
        target = default; origin = "Default"
    ];
    If[ StringQ @ id && target =!= current && offeredQ[ option, target ], { id, target, origin }, Nothing ]
];

configTarget[ _, _, _ ] := Nothing;

configTarget // endDefinition;


offeredQ // beginDefinition;
offeredQ[ KeyValuePattern[ "type" -> "boolean" ], value_ ] := BooleanQ @ value;
offeredQ[ option_Association, value_String ] := MemberQ[ acpOptionValues @ option, value ];
offeredQ[ _, _ ] := False;
offeredQ // endDefinition;


becomeReady // beginDefinition;

(* A restored session stays "Restoring" until its turns are written (Sessions.wl's acpRestoreWriteStep) *)
becomeReady[ nbo_NotebookObject, conn_ ] := (
    windowUpdate[
        nbo,
        Function[ w,
            If[ Lookup[ w, "Connection", None ] =!= conn,
                w,
                <|
                    w,
                    "Status"          -> Which[ AssociationQ @ Lookup[ w, "Restore", None ], "Restoring", runningTurnQ @ w, "Running", True, "Ready" ],
                    "ConnectToken"    -> None,
                    "ConnectAttempts" -> 0,
                    "PendingConfig"   -> <| |>,
                    "Error"           -> None
                |>
            ]
        ]
    ];
    acpSessionsMarkStale @ nbo
);

becomeReady // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Config option responses*)

(* Updates the config options from a session/set_config_option response. A value the user chose is persisted per
   agent (model and effort; not mode). A failed model is marked as failed for this session. The response to a request
   for a session the window has left meanwhile (a session restored on the same connection, Sessions.wl) only records
   the user's choice as a preference: the window's options, pending values and notice are the new session's. *)
applyConfigResponse // beginDefinition;

applyConfigResponse[ nbo_NotebookObject, data_Association, resp_Association ] := Module[ { window, id, value, user, own, category },
    window   = acpWindowGet @ nbo;
    id       = Lookup[ data, "ConfigID", None ];
    value    = Lookup[ data, "Value", None ];
    user     = Lookup[ data, "Origin", None ] === "User";
    own      = currentSessionRequestQ[ window, data ];
    category = Lookup[ Replace[ SelectFirst[ configOptionsOf @ window, Lookup[ #, "id", None ] === id &, <| |> ], Except[ _Association ] -> <| |> ], "category", None ];
    If[ ! own, acpLog[ "StaleConfigResponse", <| "ConfigID" -> id, "SessionID" -> Lookup[ data, "SessionID", None ] |> ] ];

    If[ TrueQ @ resp[ "Error" ],
        If[ category === "model" && StringQ @ value, markModelFailed[ nbo, value ] ];
        acpLog[ "ConfigOptionFailed", <| "ConfigID" -> id, "Value" -> value, "Message" -> resp[ "Message" ] |> ];
        If[ own,
            windowUpdate[
                nbo,
                Function[ w,
                    <|
                        w,
                        "PendingConfig" -> dropPendingValue[ pendingConfigOf @ w, id, value ],
                        If[ user,
                            "Notice" -> acpConnectionLabel[
                                "NoticeConfigOptionFailed",
                                <| "option" -> configOptionName[ w, id ], "message" -> Replace[ resp[ "Message" ], Except[ _String ] -> "" ] |>
                            ],
                            Nothing
                        ]
                    |>
                ]
            ]
        ],

        windowUpdate[
            nbo,
            Function[ w,
                <|
                    w,
                    If[ own,
                        "ConfigOptions" -> Replace[
                            Lookup[ resp[ "Result" ], "configOptions", None ],
                            {
                                o_List :> Select[ o, AssociationQ ],
                                _ :> setOptionValue[ configOptionsOf @ w, id, value ]
                            }
                        ],
                        Nothing
                    ],
                    If[ own, "PendingConfig" -> dropPendingValue[ pendingConfigOf @ w, id, value ], Nothing ],
                    If[ user && category === "model", "UserModel" -> value, Nothing ],
                    (* a model the user picks again gets another chance *)
                    If[ user && category === "model" && StringQ @ value, "FailedModels" -> DeleteCases[ failedModelsOf @ w, value ], Nothing ],
                    If[ user, "AgentPreferences" -> updatePreferences[ Lookup[ w, "AgentPreferences", <| |> ], category, value ], Nothing ]
                |>
            ]
        ];
        If[ user, persistChoice[ Lookup[ window, "Agent", "OpenCode" ], category, value ] ]
    ]
];

applyConfigResponse // endDefinition;


dropPendingValue // beginDefinition;
dropPendingValue[ pending_Association, id_, value_ ] := If[ Lookup[ pending, id, Missing[ ] ] === value, KeyDrop[ pending, { id } ], pending ];
dropPendingValue // endDefinition;


(* Whether a config request was for the window's current session (requests without a session are) *)
currentSessionRequestQ // beginDefinition;
currentSessionRequestQ[ window_Association, data_Association ] := ! StringQ @ Lookup[ data, "SessionID", None ] || data[ "SessionID" ] === Lookup[ window, "SessionID", None ];
currentSessionRequestQ[ _, _ ] := True;
currentSessionRequestQ // endDefinition;


setOptionValue // beginDefinition;
setOptionValue[ options_List, id_, value_ ] := Replace[ options, o: KeyValuePattern[ "id" -> id ] :> <| o, "currentValue" -> value |>, { 1 } ];
setOptionValue // endDefinition;


configOptionName // beginDefinition;
configOptionName[ window_, id_ ] := Replace[
    Lookup[ Replace[ SelectFirst[ configOptionsOf @ window, Lookup[ #, "id", None ] === id &, <| |> ], Except[ _Association ] -> <| |> ], "name", id ],
    Except[ _String ] :> ToString @ id
];
configOptionName // endDefinition;


updatePreferences // beginDefinition;
updatePreferences[ prefs_Association, "model"        , value_String ] := <| prefs, "LastModel"  -> value |>;
updatePreferences[ prefs_Association, "thought_level", value_String ] := <| prefs, "LastEffort" -> value |>;
updatePreferences[ prefs_Association, _, _ ] := prefs;
updatePreferences[ _, category_, value_ ] := updatePreferences[ <| |>, category, value ];
updatePreferences // endDefinition;


(* Persisting is a front end call, so it is scheduled *)
persistChoice // beginDefinition;
persistChoice[ agent_String, "model"        , value_String ] := acpSchedule @ acpSetPersistedSetting[ { "LastModel" , agent }, value ];
persistChoice[ agent_String, "thought_level", value_String ] := acpSchedule @ acpSetPersistedSetting[ { "LastEffort", agent }, value ];
persistChoice[ _, _, _ ] := Null;
persistChoice // endDefinition;


markModelFailed // beginDefinition;

markModelFailed[ nbo_NotebookObject, model_String ] := windowUpdate[
    nbo,
    Function[ w, <| w, "FailedModels" -> DeleteDuplicates @ Append[ failedModelsOf @ w, model ] |> ]
];

markModelFailed // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Prompt responses*)

(* The turn ended (stop reason and usage, or an error); finalization is scheduled (UI.wl's acpFinalizeTurn, with its own
   housekeeping fallback for a lost task). *)
onPromptResponse // beginDefinition;

onPromptResponse[ nbo_NotebookObject, turnID_String, resp_Association, time_ ] := Module[ { window, model, error, end },
    window = acpWindowGet @ nbo;
    model  = currentModel @ window;
    end = If[ TrueQ @ resp[ "Error" ],
        error = responseError[ window, resp, "AgentError" ];
        If[ Lookup[ error, "Code" ] === "ModelUnavailable" && StringQ @ model, markModelFailed[ nbo, model ] ];
        <| "Error" -> error |>,
        <| "StopReason" -> Lookup[ resp[ "Result" ], "stopReason", None ], "Usage" -> Lookup[ resp[ "Result" ], "usage", None ] |>
    ];
    If[ AssociationQ @ acpTurnGet @ turnID, acpTurnUpdate[ turnID, acpApplyTurnEnd[ #, end, time ] & ] ];
    cancelTurnPermissions[ nbo, turnID ];
    windowUpdate[
        nbo,
        Function[ w,
            If[ Lookup[ w, "CurrentTurn", None ] === turnID && Lookup[ w, "Status", None ] === "Running",
                <| w, "Status" -> "Ready" |>,
                w
            ]
        ]
    ];
    acpSchedule @ acpFinalizeTurn @ turnID
];

onPromptResponse[ _, _, _, _ ] := Null;

onPromptResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpOnFailure*)

(* Connection-level "FailureOccurred": Failure["AgentExited", <| "ExitCode", "StandardErrorTail" |>] (fixed ACPLink) is
   the agent's death; everything else (e.g. "ErrorResponse", which is also delivered as a response) is only logged. *)
acpOnFailure // beginDefinition;
acpOnFailure[ nbo_, event_ ] := (acpIsolated @ onFailure[ nbo, event ]; Null);
acpOnFailure // endDefinition;


onFailure // beginDefinition;

onFailure[ nbo_NotebookObject, event_Association ] := With[ { failure = Lookup[ event, "Failure", None ] },
    If[ MatchQ[ failure, Failure[ "AgentExited", _Association ] ],
        onAgentExited[ nbo, connectionOfFailure[ event, failure ], failure ],
        acpLog[ "ConnectionFailure", <| "Tag" -> Replace[ failure, { Failure[ tag_, ___ ] :> tag, other_ :> Head @ other } ] |> ]
    ]
];

onFailure[ _, _ ] := Null;

onFailure // endDefinition;


connectionOfFailure // beginDefinition;
connectionOfFailure[ event_, Failure[ _, as_Association ] ] := SelectFirst[ { Lookup[ event, "Connection", None ], Lookup[ as, "Connection", None ] }, acpConnectionQ, None ];
connectionOfFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpOnConnectionRemoved*)

(* The connection's own task finished or was removed: the connection was closed (by us: the window no longer refers to
   it) or the agent died. A "Reason" of Failure["AgentExited", ...] (fixed ACPLink) is handled at once; otherwise the
   connection is checked shortly after (the close completes after this event). *)
acpOnConnectionRemoved // beginDefinition;
acpOnConnectionRemoved[ nbo_, event_ ] := (acpIsolated @ onConnectionRemoved[ nbo, event ]; Null);
acpOnConnectionRemoved // endDefinition;


onConnectionRemoved // beginDefinition;

onConnectionRemoved[ nbo_NotebookObject, event_Association ] := Module[ { reason, conn, current },
    reason  = Lookup[ event, "Reason", None ];
    conn    = Lookup[ event, "Connection", None ];
    current = acpWindowGet[ nbo, "Connection", None ];
    Which[
        MatchQ[ reason, Failure[ "AgentExited", _Association ] ],
            onAgentExited[ nbo, connectionOfFailure[ event, reason ], reason ],
        acpConnectionQ @ conn && conn =!= current,
            Null, (* an old connection *)
        acpConnectionQ @ current,
            acpSchedule @ checkConnectionAlive[ nbo, current ],
        True,
            Null
    ]
];

onConnectionRemoved[ _, _ ] := Null;

onConnectionRemoved // endDefinition;


checkConnectionAlive // beginDefinition;

checkConnectionAlive[ nbo_NotebookObject, conn_ ] :=
    If[ acpWindowGet[ nbo, "Connection", None ] === conn && acpConnectionQ @ conn && ! closingQ @ conn && ! openConnectionQ @ conn,
        onAgentExited[ nbo, conn, Missing[ "NotAvailable" ] ]
    ];

checkConnectionAlive // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*onAgentExited*)

(* The agent process died: the running turn ends with an "AgentExited" error (exit code and the end of stderr in the
   details), the window becomes "Disconnected" (with a Reconnect action) or "Error" during setup. The resumable session
   is kept. Idempotent. For a remote window the process is ssh: its exit is classified (remoteExitError), and the remote
   home of a launch that failed after reporting it becomes the window's. *)
onAgentExited // beginDefinition;

onAgentExited[ nbo_NotebookObject, conn_, failure_ ] := Module[ { window, info, error, setupQ, exit },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window || ! acpConnectionQ @ conn || Lookup[ window, "Connection", None ] =!= conn,
        Return[ Null, Module ]
    ];
    info   = Replace[ failure, { Failure[ _, as_Association ] :> as, _ -> <| |> } ];
    setupQ = StringQ @ Lookup[ window, "ConnectToken", None ] || ! StringQ @ Lookup[ window, "SessionID", None ];
    exit   = If[ acpRemoteQ @ window,
        remoteExitError[
            window,
            Lookup[ info, "ExitCode", Missing[ "NotAvailable" ] ],
            Lookup[ info, "StandardErrorTail", "" ],
            setupQ
        ],
        <|
            "Error" -> acpErrorInfo[
                "AgentExited",
                None,
                None,
                <|
                    "Agent"             -> agentDisplayName @ window,
                    "ExitCode"          -> Lookup[ info, "ExitCode", Missing[ "NotAvailable" ] ],
                    "StandardErrorTail" -> Lookup[ info, "StandardErrorTail", Missing[ "NotAvailable" ] ]
                |>
            ],
            "RemoteHome" -> None
        |>
    ];
    error = exit[ "Error" ];
    endSentTurn[ nbo, window, <| "Error" -> error |> ];
    windowUpdate[
        nbo,
        Function[ w,
            If[ Lookup[ w, "Connection", None ] =!= conn,
                w,
                <|
                    w,
                    "Status"             -> If[ setupQ, "Error", "Disconnected" ],
                    "Error"              -> error,
                    "Connection"         -> None,
                    "ConnectToken"       -> None,
                    "SessionID"          -> None,
                    "Requests"           -> <| |>,
                    "PendingPermissions" -> <| |>,
                    "MCPReady"           -> False,
                    "Restore"            -> loadingDropped @ w,
                    "PendingRestore"     -> None,
                    If[ StringQ @ exit[ "RemoteHome" ], "RemoteHome" -> exit[ "RemoteHome" ], Nothing ]
                |>
            ]
        ]
    ];
    releaseConnection @ conn;
    acpLog[ "AgentExited", <| "ExitCode" -> Lookup[ info, "ExitCode", None ] |> ]
];

onAgentExited // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Remote errors*)

(* The error of a remote window whose ssh ended (SSH.wl's acpSSHExitError: ssh's failures, the launch script's markers,
   the agent's exit), as <| "Error", "RemoteHome" -> the home the launch reported if it differs from the window's, else
   None |>. Kernel state and pure string work only (it runs in reader handlers): a failure that latches the host is
   noted (Remote.wl's acpRemoteNoteHostError); a missing folder that is the host's persisted last folder is forgotten,
   and a reported home that differs from the window's is persisted for the host, in scheduled tasks (a launch that
   fails, e.g. for a missing folder, still corrects a home persisted for another machine of the same host name).
   ACPLink reports only the end of standard error, so the markers of a launch that got as far as the agent
   ("LaunchMarkers") are put in front of it when they are no longer in it. *)
remoteExitError // beginDefinition;

remoteExitError[ window_Association, exitCode_, tail0_, setupQ_ ] := Module[ { nonce, tail, markers, error, missing, home },
    nonce = Lookup[ window, "LaunchNonce", None ];
    tail  = Replace[ tail0, Except[ _String ] -> "" ];
    If[ StringQ @ nonce && StringQ @ Lookup[ window, "LaunchMarkers", None ] && ! StringContainsQ[ tail, $acpSSHMarkerPrefix <> nonce <> ":home:" ],
        tail = window[ "LaunchMarkers" ] <> tail
    ];
    markers = acpSSHLaunchMarkers[ Replace[ nonce, Except[ _String ] -> "" ], tail ];
    error   = acpSSHExitError[ exitCode, tail, remoteErrorContext[ window, setupQ ] ];
    acpRemoteNoteHostError[ acpWindowHostKey @ window, error ];
    If[ Lookup[ error, "Code", None ] === "RemoteFolderMissing",
        missing = Select[
            {
                Replace[ Lookup[ markers, "Error", None ], { { _, p_String } :> p, _ -> None } ],
                Lookup[ window, "ProjectDirectory", None ]
            },
            StringQ
        ];
        With[ { ssh = acpWindowSSH @ window, paths = missing }, acpSchedule @ acpClearPersistedLastFolder[ ssh, paths ] ]
    ];
    (* acpSSHLaunchMarkers keeps only a home that passes acpRemoteAbsolutePathQ (and is followed by another marker) *)
    home = Replace[ Lookup[ markers, "Home", None ], Except[ _String ] -> None ];
    If[ home === acpWindowRemoteHome @ window, home = None ];
    With[ { key = acpRemoteHomeKey @ acpWindowSSH @ window, h = home },
        If[ ListQ @ key && StringQ @ h, acpSchedule @ acpSetPersistedSetting[ key, h ] ]
    ];
    <| "Error" -> error, "RemoteHome" -> home |>
];

remoteExitError // endDefinition;


(* The context of a remote window's errors (acpSSHExitError, acpSSHTimeoutError): the launch's nonce, the agent, the
   canonical SSH settings (for the host label and the ssh command of the hints), the agent's install URL, the folder,
   the remote home, and whether the host refused a sign-in recently (sshd's PerSourcePenalties, Remote.wl) *)
remoteErrorContext // beginDefinition;

remoteErrorContext[ window_Association, setupQ_ ] := <|
    "Setup"             -> TrueQ @ setupQ,
    "Nonce"             -> Lookup[ window, "LaunchNonce", None ],
    "Agent"             -> agentDisplayName @ window,
    "SSH"               -> acpWindowSSH @ window,
    "InstallURL"        -> Lookup[ Replace[ Lookup[ window, "Remote", None ], Except[ _Association ] -> <| |> ], "InstallURL", None ],
    "Path"              -> Lookup[ window, "ProjectDirectory", None ],
    "RemoteHome"        -> acpWindowRemoteHome @ window,
    "RecentAuthFailure" -> TrueQ @ acpRemoteRecentAuthFailureQ @ acpWindowHostKey @ window
|>;

remoteErrorContext // endDefinition;


(* A remote window's connection setup took too long: SSHConnectTimeout (the launch script never ran: ssh was still
   connecting or signing in) or RemoteTimeout (the agent did not answer), from ssh's standard error so far *)
remoteTimeoutError // beginDefinition;

remoteTimeoutError[ window_Association, conn_ ] := acpSSHTimeoutError[
    If[ acpConnectionQ @ conn, Replace[ Quiet @ conn[ "StandardError" ], Except[ _String ] -> "" ], "" ],
    remoteErrorContext[ window, True ]
];

remoteTimeoutError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Permissions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpOnPermissionRequest*)

(* The ACPClientMethods function for session/request_permission. It must return immediately: the request is recorded
   in the window's "PendingPermissions" (ordered by arrival; the input area shows the first) and in the turn (reducer);
   the answer is sent later by acpAnswerPermission. A request with no running turn for its session (e.g. a subagent that
   outlived a cancelled turn), or one that arrives after Stop, is answered "cancelled" at once. Accepts the ACPRequest of the fixed ACPLink
   and the raw JSONRPCProcessRequest of older versions. *)
acpOnPermissionRequest // beginDefinition;
acpOnPermissionRequest[ nbo_, request_ ] := (acpIsolated @ onPermissionRequest[ nbo, request ]; Null);
acpOnPermissionRequest // endDefinition;


onPermissionRequest // beginDefinition;

onPermissionRequest[ nbo_NotebookObject, request_ ] := Module[
    { time, data, id, params, sid, window, conn, turnID, turn, stopped, toolKey },

    time   = AbsoluteTime[ ];
    data   = messageData @ request;
    id     = Lookup[ data, "ID", None ];
    params = Replace[ Lookup[ data, "Parameters", <| |> ], Except[ _Association ] -> <| |> ];
    sid    = Lookup[ params, "sessionId", None ];
    window = acpWindowGet @ nbo;
    conn   = Replace[
        Lookup[ data, "Connection", None ],
        Except[ _? acpConnectionQ ] :> If[ AssociationQ @ window, Lookup[ window, "Connection", None ], None ]
    ];
    If[ id === None, Return[ Null, Module ] ];

    turnID  = If[ AssociationQ @ window, Lookup[ window, "CurrentTurn", None ], None ];
    turn    = If[ StringQ @ turnID, acpTurnGet @ turnID, None ];
    (* stopTurn sets "ClientCancel" -> "Stop": requests that arrive after Stop are refused, not shown *)
    stopped = AssociationQ @ turn && Lookup[ turn, "ClientCancel", None ] === "Stop";

    If[ AssociationQ @ window && acpConnectionQ @ conn && Lookup[ window, "Connection", None ] === conn &&
            AssociationQ @ turn && Lookup[ turn, "SessionID", None ] === sid && StringQ @ Lookup[ turn, "RequestID", None ] &&
            ! acpTurnEndedQ @ turn && ! TrueQ @ Lookup[ turn, "FinalizeClaimed", False ] && ! stopped,

        acpTurnUpdate[ turnID, acpApplyPermissionRequest[ #, id, params, time ] & ];
        toolKey = Lookup[ Lookup[ Lookup[ Replace[ acpTurnGet @ turnID, Except[ _Association ] -> <| |> ], "Index", <| |> ], "Permission", <| |> ], Key @ id, None ];
        windowUpdate[
            nbo,
            Function[ w,
                <|
                    w,
                    "PendingPermissions" -> Append[
                        pendingOf @ w,
                        id -> <| "TurnID" -> turnID, "ToolKey" -> toolKey, "Params" -> params, "ArrivedAt" -> time, "SessionID" -> sid |>
                    ]
                |>
            ]
        ];
        (* the panel shows the window titles of the notebooks that a call of the notebook tools names: they take front
           end calls, so the pump looks them up (a remote window's agent can't reach this computer's notebooks) *)
        If[ ! acpRemoteQ @ window,
            With[ { specs = acpPermissionNotebooks @ params },
                If[ specs =!= { }, acpSchedule @ resolvePermissionNotebooks[ nbo, id, specs ] ]
            ]
        ],

        answerOutcome[ conn, id, None ];
        If[ AssociationQ @ window && Lookup[ window, "Connection", None ] === conn && ! stopped,
            backgroundPermissionNotice[ nbo, turnID, turn, sid, time ]
        ];
        acpLog[ "PermissionCancelled", <| "RequestID" -> id, "SessionID" -> sid, "Stopped" -> stopped |> ]
    ]
];

onPermissionRequest[ _, _ ] := Null;

onPermissionRequest // endDefinition;


(* In the pump: adds the window titles of the notebooks that a pending request names (acpNotebookTitles, which makes
   front end calls) to the request as "NotebookTitles", for the permission panel, which then shows them. Nothing if the
   request was answered meanwhile or no notebook was found. *)
resolvePermissionNotebooks // beginDefinition;

resolvePermissionNotebooks[ nbo_NotebookObject, id_, specs_List ] := Module[ { titles },
    If[ ! KeyExistsQ[ pendingOf @ Replace[ acpWindowGet @ nbo, Except[ _Association ] -> <| |> ], id ], Return[ Null, Module ] ];
    titles = acpNotebookTitles @ specs;
    If[ AssociationQ @ titles && titles =!= <| |>,
        windowUpdate[
            nbo,
            Function[ w,
                If[ KeyExistsQ[ pendingOf @ w, id ],
                    <| w, "PendingPermissions" -> MapAt[ Append[ #, "NotebookTitles" -> titles ] &, pendingOf @ w, Key @ id ] |>,
                    Missing[ "NotFound" ]
                ]
            ]
        ]
    ];
    Null
];

resolvePermissionNotebooks // endDefinition;


backgroundPermissionNotice // beginDefinition;

(* A notice entity is added to the turn only if it is still running in the same session: appended after a streaming
   answer it would start a new segment, and appended to an ended turn it would hide the answer. *)
backgroundPermissionNotice[ nbo_, turnID_, turn_, sid_, time_ ] := With[ { text = acpConnectionLabel[ "NoticeBackgroundPermission" ] },
    If[ AssociationQ @ turn && ! TrueQ @ Lookup[ turn, "FinalizeClaimed", False ] &&
            ! acpTurnEndedQ @ turn && Lookup[ turn, "SessionID", None ] === sid,
        acpTurnUpdate[ turnID, acpApplyNotice[ #, <| "Kind" -> "Info", "Text" -> text |>, time ] & ],
        windowUpdate[ nbo, <| #, "Notice" -> text |> & ]
    ]
];

backgroundPermissionNotice // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpAnswerPermission*)

(* Answers a pending permission request (preemptive UI action): option is an optionId ("once", "always", "reject",
   ...) or None/"cancelled". A request that is no longer pending (withdrawn, already answered) is ignored.
   Gives True if the answer was written. *)
acpAnswerPermission // beginDefinition;

acpAnswerPermission[ nbo_NotebookObject, reqID_, option_ ] := Catch @ Module[ { info, conn, sent, time },
    time = AbsoluteTime[ ];
    info = takePendingPermission[ nbo, reqID ];
    If[ ! AssociationQ @ info, Throw @ Missing[ "NotPending", reqID ] ];
    conn = acpWindowGet[ nbo, "Connection", None ];
    sent = answerOutcome[ conn, reqID, option ];
    If[ StringQ @ info[ "TurnID" ],
        acpTurnUpdate[ info[ "TurnID" ], acpApplyPermissionOutcome[ #, reqID, Replace[ option, "cancelled" -> None ], time ] & ]
    ];
    respondedQ @ sent
];

acpAnswerPermission // endDefinition;


answerOutcome // beginDefinition;

answerOutcome[ conn_? acpConnectionQ, reqID_, option_ ] := Quiet @ Catch[
    acpLink[ "SendACPResponse" ][ conn, acpLink[ "ACPResponse" ][ <| "ID" -> reqID, "Result" -> permissionResult @ option |> ] ],
    _,
    $Failed &
];

answerOutcome[ _, _, _ ] := Failure[ "NotConnected", <| |> ];

answerOutcome // endDefinition;


(* Answers "cancelled" and removes the window's pending permission requests of a turn that ended (the turn record
   already shows them cancelled). Gives the request IDs. Safe in reader handlers: windowUpdate never creates records
   and answerOutcome only writes to the connection. *)
cancelTurnPermissions // beginDefinition;

cancelTurnPermissions[ nbo_NotebookObject, turnID_String ] := Module[ { ids = { }, conn },
    windowUpdate[
        nbo,
        Function[ w,
            ids = Keys @ Select[ pendingOf @ w, Lookup[ #, "TurnID", None ] === turnID & ];
            If[ ids === { }, w, <| w, "PendingPermissions" -> KeyDrop[ pendingOf @ w, ids ] |> ]
        ]
    ];
    conn = acpWindowGet[ nbo, "Connection", None ];
    Scan[ answerOutcome[ conn, #, None ] &, ids ];
    ids
];

cancelTurnPermissions // endDefinition;


permissionResult // beginDefinition;
permissionResult[ None | Null | "cancelled" ] := <| "outcome" -> <| "outcome" -> "cancelled" |> |>;
permissionResult[ option_String ] := <| "outcome" -> <| "outcome" -> "selected", "optionId" -> option |> |>;
permissionResult[ _ ] := permissionResult @ None;
permissionResult // endDefinition;


respondedQ // beginDefinition;
respondedQ[ h_Symbol[ _Association ] ] := SymbolName @ h === "ACPResponse";
respondedQ[ _ ] := False;
respondedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompts*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSendPrompt*)

(* Sends the turn's prompt (session/prompt with a "cb-" string ID); called by UI.wl after it created the turn and set
   the window "Running". The response is handled by onPromptResponse. *)
acpSendPrompt // beginDefinition;

acpSendPrompt[ nbo_NotebookObject, turnID_String ] := Catch @ Module[ { window, turn, conn, sid, id, sent },
    window = acpWindowGet @ nbo;
    turn   = acpTurnGet @ turnID;
    If[ ! AssociationQ @ window || ! AssociationQ @ turn, Throw @ Missing[ "NotFound" ] ];
    conn = Lookup[ window, "Connection", None ];
    sid  = Lookup[ window, "SessionID", None ];
    If[ ! acpConnectionQ @ conn || ! StringQ @ sid,
        endTurnLocally[ nbo, turnID, <| "Error" -> acpErrorInfo[ "NotConnected", None, None, <| "Agent" -> agentDisplayName @ window |> ] |>, None ];
        Throw @ Failure[ "NotConnected", <| |> ]
    ];
    id = $acpRequestPrefix <> createUUID[ ];
    acpTurnUpdate[
        turnID,
        <|
            "Turn" -> <|
                #,
                "RequestID"        -> id,
                "SessionID"        -> sid,
                "AgentName"        -> agentDisplayName @ window,
                "ProjectDirectory" -> Replace[ Lookup[ #, "ProjectDirectory", None ], None :> Lookup[ window, "ProjectDirectory", None ] ],
                "Remote"           -> Replace[ Lookup[ #, "Remote", None ], None :> acpTurnRemote @ window ]
            |>,
            "Changed" -> { },
            "Layout"  -> False
        |> &
    ];
    sent = sendRequest[
        nbo,
        conn,
        "session/prompt",
        <| "sessionId" -> sid, "prompt" -> { <| "type" -> "text", "text" -> Replace[ Lookup[ turn, "Prompt", "" ], Except[ _String ] -> "" ] |> } |>,
        "Prompt",
        <| "TurnID" -> turnID |>,
        id
    ];
    If[ FailureQ @ sent,
        endTurnLocally[ nbo, turnID, <| "Error" -> acpErrorInfo[ "SendFailed", None, None, <| "Agent" -> agentDisplayName @ window |> ] |>, None ]
    ];
    sent
];

acpSendPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpStop*)

(* Stop (preemptive): session/cancel; unfinished tools become "Stopped" and pending permissions are answered "cancelled"
   (by the fixed ACPLink's SendACPCancelPrompt, which gives the IDs it answered; the others are answered here). The agent
   then ends the turn with stopReason "cancelled"; if it doesn't within $acpStopTimeout seconds, housekeeping ends it. *)
acpStop // beginDefinition;

acpStop[ nbo_NotebookObject ] := Catch @ Module[ { window, turnID, turn, time, conn, sid, pending, answered },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window, Throw @ Null ];
    turnID = Lookup[ window, "CurrentTurn", None ];
    turn   = If[ StringQ @ turnID, acpTurnGet @ turnID, None ];
    If[ ! AssociationQ @ turn || acpTurnEndedQ @ turn, Throw @ Null ];
    time = AbsoluteTime[ ];

    acpTurnUpdate[ turnID, stopTurn[ #, time ] & ];

    pending = Keys @ Select[ pendingOf @ window, Lookup[ #, "TurnID", None ] === turnID & ];
    windowUpdate[ nbo, Function[ w, <| w, "PendingPermissions" -> KeyDrop[ pendingOf @ w, pending ] |> ] ];

    conn = Lookup[ window, "Connection", None ];
    sid  = Replace[ Lookup[ turn, "SessionID", None ], Except[ _String ] :> Lookup[ window, "SessionID", None ] ];
    If[ ! acpConnectionQ @ conn || ! StringQ @ Lookup[ turn, "RequestID", None ] || ! StringQ @ sid,
        endTurnLocally[ nbo, turnID, <| "StopReason" -> "cancelled" |>, None ];
        Throw @ Null
    ];

    answered = Quiet @ Catch[ acpLink[ "SendACPCancelPrompt" ][ conn, sid ], _, $Failed & ];
    answered = Replace[ answered, Except[ _List ] -> { } ];
    Scan[ answerOutcome[ conn, #, None ] &, Complement[ pending, answered ] ];
    Null
];

acpStop // endDefinition;


stopTurn // beginDefinition;

stopTurn[ turn_Association, time_ ] := Replace[
    acpApplyClientCancel[ turn, "Stop", time ],
    res: KeyValuePattern[ "Turn" -> t_Association ] :> <| res, "Turn" -> <| t, "StopRequestedAt" -> time |> |>
];

stopTurn // endDefinition;


(* Ends a turn without an agent response and schedules its finalization. stop -> "Stop" also applies the client
   cancel (unfinished tools become "Stopped"). *)
endTurnLocally // beginDefinition;

endTurnLocally[ nbo_NotebookObject, turnID_String, end_Association, stop_ ] := Module[ { time },
    time = AbsoluteTime[ ];
    If[ AssociationQ @ acpTurnGet @ turnID,
        acpTurnUpdate[ turnID, endTurn[ #, end, stop, time ] & ];
        cancelTurnPermissions[ nbo, turnID ];
        windowUpdate[
            nbo,
            Function[ w,
                If[ Lookup[ w, "CurrentTurn", None ] === turnID && Lookup[ w, "Status", None ] === "Running",
                    <| w, "Status" -> If[ acpConnectionQ @ Lookup[ w, "Connection", None ], "Ready", "Disconnected" ] |>,
                    w
                ]
            ]
        ];
        acpSchedule @ acpFinalizeTurn @ turnID
    ]
];

endTurnLocally // endDefinition;


endTurn // beginDefinition;

endTurn[ turn_Association, end_Association, stop_, time_ ] := Module[ { r1, r2 },
    r1 = If[ stop === "Stop", acpApplyClientCancel[ turn, "Stop", time ], <| "Turn" -> turn, "Changed" -> { }, "Layout" -> False |> ];
    r2 = acpApplyTurnEnd[ r1[ "Turn" ], end, time ];
    <| "Turn" -> r2[ "Turn" ], "Changed" -> Union[ r1[ "Changed" ], r2[ "Changed" ] ], "Layout" -> True |>
];

endTurn // endDefinition;


(* Ends the window's current turn if its prompt was sent and it has not ended (connection failures, agent death) *)
endSentTurn // beginDefinition;

endSentTurn[ nbo_NotebookObject, window_Association, end_Association ] := endSentTurn[ nbo, window, end, None ];

endSentTurn[ nbo_NotebookObject, window_Association, end_Association, stop_ ] := Module[ { turnID, turn },
    turnID = Lookup[ window, "CurrentTurn", None ];
    turn   = If[ StringQ @ turnID, acpTurnGet @ turnID, None ];
    If[ AssociationQ @ turn && StringQ @ Lookup[ turn, "RequestID", None ] && ! acpTurnEndedQ @ turn,
        endTurnLocally[ nbo, turnID, end, stop ]
    ]
];

endSentTurn[ _, _, _ ] := Null;
endSentTurn[ _, _, _, _ ] := Null;

endSentTurn // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sessions and Settings*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpNewSession*)

(* New chat (UI.wl stops a running turn and clears the cells first): a new session on the same connection (session/close
   for the old one if supported), model/effort reapplied; the resumable session is forgotten. Without a connection the
   next connection starts a new session. *)
acpNewSession // beginDefinition;

acpNewSession[ nbo_NotebookObject ] := Catch @ Module[ { window, conn, oldSID, token },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window, Throw @ Missing[ "NotFound" ] ];
    (* UI.wl stops a running turn first; if it didn't, the turn is cancelled here (it ends on the old session) *)
    If[ runningTurnQ @ window, acpStop @ nbo; window = acpWindowGet @ nbo ];
    acpSchedule @ acpFESet[ nbo, "ResumableSessionID", None ];
    conn   = Lookup[ window, "Connection", None ];
    oldSID = Lookup[ window, "SessionID", None ];

    If[ ! acpConnectionQ @ conn || ! StringQ @ oldSID,
        (* Connecting (a session/resume may be in flight) or not connected: *)
        windowUpdate[ nbo, Function[ w, <| w, "ResumableSessionID" -> None, "NewSessionRequested" -> connectingOrConnectedQ @ w |> ] ];
        If[ ! connectingOrConnectedQ @ window && Lookup[ window, "Status" ] === "Disconnected", acpEnsureConnected @ nbo ];
        Throw @ Null
    ];

    token = createUUID[ ];
    windowUpdate[
        nbo,
        Function[ w,
            <|
                w,
                "SessionID"           -> None,
                "ResumableSessionID"  -> None,
                "NewSessionRequested" -> False,
                "Status"              -> "Connecting",
                "ConnectToken"        -> token,
                "ConnectScheduledAt"  -> AbsoluteTime[ ],
                "PendingPermissions"  -> <| |>,
                "Usage"               -> None,
                "ConfigAttempts"      -> <| |>
            |>
        ]
    ];
    If[ closeCapableQ @ window, sendWithoutContinuation[ conn, "session/close", <| "sessionId" -> oldSID |> ] ];
    If[ FailureQ @ sendNewSession[ nbo, conn, Lookup[ window, "ConnectDirectory", None ] ],
        failConnection[ nbo, conn, acpErrorInfo[ "SessionFailed", None, None, <| "Agent" -> agentDisplayName @ window |> ] ]
    ];
    Null
];

acpNewSession // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Restoring sessions*)

(* session/load for Sessions.wl's acpRestoreSession: the window's connection loads another session of the same folder
   (mode "SameConnection"; startSession sends it in mode "Setup" instead of a new session). The window is "Restoring"
   while the replay arrives (onReplayUpdate collects it) and while the turns are written; the session it showed stays
   attached until the load succeeds. *)
acpLoadSession // beginDefinition;

acpLoadSession[ nbo_NotebookObject, sid_String, cwd_String ] := Catch @ Module[ { window, conn, previous },
    window   = acpWindowGet @ nbo;
    conn     = Lookup[ window, "Connection", None ];
    previous = Lookup[ window, "SessionID", None ];
    If[ ! acpConnectionQ @ conn || ! StringQ @ previous, Throw @ Failure[ "NotConnected", <| |> ] ];
    sendSessionLoad[ nbo, conn, sid, cwd, "SameConnection", previous ]
];

acpLoadSession // endDefinition;


(* Sends session/load with the session's own listed cwd (unchanged: OpenCode requires its exact directory) and the same
   MCP servers as session/new. Safe in reader handlers (startSession). *)
sendSessionLoad // beginDefinition;

sendSessionLoad[ nbo_NotebookObject, conn_, sid_String, cwd_String, mode_String, previous_ ] := Module[ { token, data, sent },
    token = CreateUUID[ "restore-" ];
    data  = <| "SessionID" -> sid, "Token" -> token, "Mode" -> mode |>;
    windowUpdate[
        nbo,
        <|
            #,
            "Status"         -> "Restoring",
            "PendingRestore" -> None,
            "Notice"         -> None,
            (* On the window's connection the pending config values are changes of the session that is left (sent, not
               answered yet): they must not be applied to the loaded session (nextConfigStep). Values chosen while it
               loads are applied to it. *)
            If[ mode === "SameConnection", "PendingConfig" -> <| |>, Nothing ],
            "Restore"        -> acpNewRestore @ <|
                "SessionID"         -> sid,
                "Cwd"               -> cwd,
                "Token"             -> token,
                "Mode"              -> mode,
                "PreviousSessionID" -> previous
            |>
        |> &
    ];
    sent = sendRequest[ nbo, conn, "session/load", <| "sessionId" -> sid, "cwd" -> cwd, "mcpServers" -> acpMCPServersParam @ nbo |>, "SessionLoad", data ];
    If[ FailureQ @ sent,
        sessionLoadFailed[ nbo, conn, data, acpErrorInfo[ "SendFailed", None, None, <| "Agent" -> agentDisplayName @ acpWindowGet @ nbo |> ] ]
    ];
    sent
];

sendSessionLoad // endDefinition;


(* The load response: the replay is complete (OpenCode sends it before the response) *)
onSessionLoadResponse // beginDefinition;

onSessionLoadResponse[ nbo_NotebookObject, conn_, data_Association, resp_Association, time_ ] := Module[ { window, restore, sid },
    window  = acpWindowGet @ nbo;
    restore = Lookup[ window, "Restore", None ];
    sid     = Lookup[ data, "SessionID", None ];
    Which[
        ! AssociationQ @ restore || restore[ "Token" ] =!= data[ "Token" ],
            (* the restore was given up meanwhile: the session must not stay attached *)
            acpLog[ "StaleSessionLoad", <| "SessionID" -> sid |> ];
            If[ ! TrueQ @ resp[ "Error" ] && StringQ @ sid && sid =!= Lookup[ window, "SessionID", None ] && closeCapableQ @ window,
                sendWithoutContinuation[ conn, "session/close", <| "sessionId" -> sid |> ]
            ],
        TrueQ @ resp[ "Error" ],
            sessionLoadFailed[ nbo, conn, data, responseError[ window, resp, "SessionFailed" ] ],
        True,
            sessionLoaded[ nbo, conn, data, restore, resp[ "Result" ], time ]
    ]
];

onSessionLoadResponse // endDefinition;


(* The late response of a load that timed out (checkRequestTimeouts): the agent attached the session after all, so it is
   closed again (unless the window shows or loads it by now) *)
onAbandonedLoadResponse // beginDefinition;

onAbandonedLoadResponse[ nbo_NotebookObject, conn_, data_Association, resp_Association ] := Module[ { window, sid },
    window = acpWindowGet @ nbo;
    sid    = Lookup[ data, "SessionID", None ];
    acpLog[ "AbandonedLoadResponse", <| "SessionID" -> sid, "Error" -> TrueQ @ resp[ "Error" ] |> ];
    If[ And[
            ! TrueQ @ resp[ "Error" ],
            StringQ @ sid,
            ! MemberQ[ { Lookup[ window, "SessionID", None ], loadingSessionID @ window }, sid ],
            closeCapableQ @ window
        ],
        sendWithoutContinuation[ conn, "session/close", <| "sessionId" -> sid |> ]
    ];
    Null
];

onAbandonedLoadResponse // endDefinition;


(* The session is the window's now (with the config options of the load response: nothing is re-applied, see
   nextConfigStep); the session that was left is closed; the turns are written by the pump (Sessions.wl). *)
sessionLoaded // beginDefinition;

sessionLoaded[ nbo_NotebookObject, conn_, data_Association, restore_Association, result_Association, time_ ] := Module[ { window, previous },
    window = acpWindowGet @ nbo;
    windowUpdate[
        nbo,
        Function[ w,
            If[ AssociationQ @ Lookup[ w, "Restore", None ] && w[ "Restore", "Token" ] === data[ "Token" ],
                <| w, "Restore" -> <| w[ "Restore" ], "Stage" -> "Writing", "LoadedAt" -> time, "StepAt" -> time |>, "Turns" -> { } |>,
                w
            ]
        ]
    ];
    sessionEstablished[ nbo, conn, data[ "SessionID" ], Lookup[ result, "configOptions", None ], "Loaded", time ];
    previous = restore[ "PreviousSessionID" ];
    If[ data[ "Mode" ] === "SameConnection" && StringQ @ previous && previous =!= data[ "SessionID" ] && closeCapableQ @ window,
        sendWithoutContinuation[ conn, "session/close", <| "sessionId" -> previous |> ]
    ];
    With[ { token = data[ "Token" ] }, acpSchedule @ acpRestoreWriteStep[ nbo, token ] ];
    acpSessionsMarkStale @ nbo
];

sessionLoaded // endDefinition;


(* The load failed (error response, timeout, write failure). On the window's connection, the window goes back to the
   session it showed (the transcript was not touched) and shows the error; while connecting, it continues with the
   session it would have used without the restore (resume, or a new session) and shows the error. error is an
   acpErrorInfo record. *)
sessionLoadFailed // beginDefinition;

sessionLoadFailed[ nbo_NotebookObject, conn_, data_Association, error_ ] := Module[ { window, restore, notice, current = False },
    window  = acpWindowGet @ nbo;
    restore = Lookup[ window, "Restore", None ];
    If[ ! AssociationQ @ restore || restore[ "Token" ] =!= data[ "Token" ], Return[ Null, Module ] ];
    notice = acpConnectionLabel[ "NoticeSessionLoadFailed", <| "message" -> loadErrorMessage @ error |> ];
    acpLog[ "SessionLoadFailed", <| "Code" -> Lookup[ Replace[ error, Except[ _Association ] -> <| |> ], "Code", None ], "Mode" -> data[ "Mode" ] |> ];
    windowUpdate[
        nbo,
        Function[ w,
            If[ AssociationQ @ Lookup[ w, "Restore", None ] && w[ "Restore", "Token" ] === data[ "Token" ],
                current = True;
                <|
                    w,
                    "Restore" -> None,
                    "Notice"  -> notice,
                    "Status"  -> Which[
                        data[ "Mode" ] =!= "SameConnection", "Connecting",
                        ! acpConnectionQ @ Lookup[ w, "Connection", None ], w[ "Status" ],
                        runningTurnQ @ w, "Running",
                        True, "Ready"
                    ]
                |>,
                w
            ]
        ]
    ];
    If[ current && data[ "Mode" ] =!= "SameConnection" && acpConnectionQ @ conn && acpWindowGet[ nbo, "Connection", None ] === conn,
        startSession[ nbo, conn ]
    ];
    acpSessionsMarkStale @ nbo
];

sessionLoadFailed // endDefinition;


(* The agent's own message if there is one (e.g. "session not found"), else the friendly one; neutralized *)
loadErrorMessage // beginDefinition;

loadErrorMessage[ error_Association ] := acpNeutralizeLinearSyntax @ StringTake[
    SelectFirst[ Lookup[ error, { "Detail", "Message" }, None ], StringQ[ # ] && StringLength[ # ] > 0 &, "" ],
    UpTo[ 500 ]
];

loadErrorMessage[ _ ] := "";

loadErrorMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Listing and deleting sessions*)

(* session/list (all folders: no cwd; cursor for later pages) and session/delete for Sessions.wl; the responses go to
   acpSessionsOnListResponse / acpSessionsOnDeleteResponse. Give the request ID or a Failure. *)
acpSendSessionList // beginDefinition;

acpSendSessionList[ nbo_NotebookObject, conn_, token_String, cursor_, page_Integer ] := sendRequest[
    nbo,
    conn,
    "session/list",
    If[ StringQ @ cursor, <| "cursor" -> cursor |>, <| |> ],
    "SessionList",
    <| "Token" -> token, "Page" -> page |>
];

acpSendSessionList // endDefinition;


acpSendSessionDelete // beginDefinition;

acpSendSessionDelete[ nbo_NotebookObject, conn_, sid_String ] :=
    sendRequest[ nbo, conn, "session/delete", <| "sessionId" -> sid |>, "SessionDelete", <| "SessionID" -> sid |> ];

acpSendSessionDelete // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSetConfigOption*)

(* Model/mode/effort menus (preemptive): the value is recorded in "PendingConfig" (the menus show it at once) and sent
   with session/set_config_option; the response updates "ConfigOptions" and persists model/effort. While the session is
   being set up (or not connected) the pending value is applied during the setup. *)
acpSetConfigOption // beginDefinition;

acpSetConfigOption[ nbo_NotebookObject, configID_String, value_ ] := Catch @ Module[ { window, conn, sid, sent },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window, Throw @ Missing[ "NotFound" ] ];
    windowUpdate[ nbo, Function[ w, <| w, "PendingConfig" -> Append[ pendingConfigOf @ w, configID -> value ] |> ] ];
    conn = Lookup[ window, "Connection", None ];
    sid  = Lookup[ window, "SessionID", None ];
    (* Applied when the session is set up, or loaded: while a restored session loads, the session the window shows is
       about to be replaced; once it is loaded (its turns are being written) it is the window's session *)
    If[ ! acpConnectionQ @ conn || ! StringQ @ sid || StringQ @ Lookup[ window, "ConnectToken", None ] || restoreLoadingQ[ window, sid ],
        Throw @ "Pending"
    ];
    sent = sendRequest[
        nbo,
        conn,
        "session/set_config_option",
        <| "sessionId" -> sid, "configId" -> configID, "value" -> value |>,
        "SetConfig",
        <| "ConfigID" -> configID, "Value" -> value, "Origin" -> "User", "SessionID" -> sid |>
    ];
    If[ FailureQ @ sent,
        windowUpdate[ nbo, Function[ w, <| w, "PendingConfig" -> dropPendingValue[ pendingConfigOf @ w, configID, value ] |> ] ];
        Throw @ sent
    ];
    "Sent"
];

acpSetConfigOption // endDefinition;


restoreLoadingQ // beginDefinition;
restoreLoadingQ[ window_Association, sid_ ] := MatchQ[ Lookup[ window, "Restore", None ], r_Association /; r[ "Stage" ] =!= "Writing" || r[ "SessionID" ] =!= sid ];
restoreLoadingQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSetProjectDirectory*)

(* Changing the project directory (preemptive UI action) is a new chat in the new directory: disconnect, clear the
   transcript, store the directory (window record, notebook TaggingRules, persisted last directory) and reconnect.
   Refused while a turn is running (the UI disables the chooser). extra: keys for the reset window record, e.g. the
   "PendingRestore" of a session restored from another folder (Sessions.wl), which the new connection then loads
   instead of creating a new session; "Raw" -> True takes the folder exactly as given (one the agent listed), apart from
   ~ and a trailing /. A remote window's folder is checked as a remote path only (never on this computer) and is
   persisted for its host once the launch has entered it (remoteLaunched). Gives the folder, Null (unchanged) or a
   Failure. *)
acpSetProjectDirectory // beginDefinition;

acpSetProjectDirectory[ nbo_NotebookObject, dir_ ] := acpSetProjectDirectory[ nbo, dir, <| |> ];

acpSetProjectDirectory[ nbo_NotebookObject, File[ dir_String ], extra_Association ] := acpSetProjectDirectory[ nbo, dir, extra ];

acpSetProjectDirectory[ nbo_NotebookObject, dir0_, extra_Association ] := Catch @ Module[ { window, dir },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window, Throw @ Missing[ "NotFound" ] ];
    dir = If[ TrueQ @ Lookup[ extra, "Raw", False ] && acpRemoteQ @ window,
        acpRemoteNormalizeDirectory[ dir0, acpWindowRemoteHome @ window, "Raw" -> True ],
        acpNormalizeProjectDirectory[ dir0, window ]
    ];
    If[ ! validProjectDirectoryQ[ dir, window ], Throw @ Failure[ "InvalidDirectory", <| "Directory" -> dir0 |> ] ];
    If[ dir === Lookup[ window, "ProjectDirectory", None ], Throw @ Null ];
    If[ StringQ @ Lookup[ window, "CurrentTurn", None ], Throw @ Failure[ "Running", <| |> ] ];

    resetProjectDirectory[ nbo, dir, KeyDrop[ extra, { "Raw" } ] ];
    If[ ! acpRemoteQ @ window, acpSetPersistedSetting[ "LastProjectDirectory", dir ] ];
    acpEnsureConnected @ nbo;
    dir
];

acpSetProjectDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpResetProjectDirectory*)

(* The folder after a change of the window's host (UI.wl's acpReuseWindow, which merged the new "SSHSettings" first): a
   new chat in dir, or without a folder for None ("NoDirectory"), even for the same folder string (the same path on
   another machine is another folder). The other host's state is dropped: the resumable session, the remote home (the new
   host's persisted one instead), whether the host was reached ("RemoteVerified"), the listed sessions, and the folder
   picker of the old host. Does not connect (the caller does, once). *)
acpResetProjectDirectory // beginDefinition;

acpResetProjectDirectory[ nbo_NotebookObject, dir0_ ] := Catch @ Module[ { window, ssh, dir },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window, Throw @ Missing[ "NotFound" ] ];
    ssh = acpWindowSSH @ window;
    dir = If[ StringQ @ dir0 && validProjectDirectoryQ[ dir0, window ], dir0, None ];
    resetProjectDirectory[
        nbo,
        dir,
        <|
            "RemoteHome"     -> acpPersistedRemoteHome @ ssh,
            "RemoteVerified" -> False,
            "Sessions"       -> resetSessionsStore @ window
        |>
    ];
    acpFolderPickerCloseWindow @ nbo;
    dir
];

acpResetProjectDirectory // endDefinition;


(* The reset steps of a new folder: disconnect, drop the turns and the session state, store the folder (window record
   and TaggingRules), clear the cells. extra: more keys of the window record. *)
resetProjectDirectory // beginDefinition;

resetProjectDirectory[ nbo_NotebookObject, dir_, extra_Association ] := (
    acpDisconnect[ nbo, "DirectoryChanged" ];
    dropWindowTurns @ nbo;
    windowUpdate[
        nbo,
        Function[ w,
            <|
                w,
                "ProjectDirectory"   -> dir,
                "Status"             -> If[ StringQ @ dir, "Disconnected", "NoDirectory" ],
                "Error"              -> None,
                "Turns"              -> { },
                "QueuedPrompt"       -> None,
                "QueuedTurn"         -> None,
                "Notice"             -> None,
                "ResumableSessionID" -> None,
                "ResumableDirectory" -> None,
                "Usage"              -> None,
                "ConfigOptions"      -> { },
                "PendingConfig"      -> <| |>,
                "Restore"            -> None,
                "PendingRestore"     -> None,
                extra
            |>
        ]
    ];
    acpFESet[ nbo, "ProjectDirectory", dir ];
    acpFESet[ nbo, "ResumableSessionID", None ];
    clearWindowCells @ nbo;
    Null
);

resetProjectDirectory // endDefinition;


(* The Sessions store without another host's sessions (UI state such as "Open" is kept) *)
resetSessionsStore // beginDefinition;

resetSessionsStore[ window_Association ] := Replace[
    Lookup[ window, "Sessions", None ],
    store_Association :> <|
        store,
        "Status"        -> "Idle",
        "Items"         -> { },
        "ListedAt"      -> None,
        "Error"         -> None,
        "Deleting"      -> <| |>,
        "Expanded"      -> <| |>,
        "ConfirmDelete" -> None
    |>
];

resetSessionsStore // endDefinition;


dropWindowTurns // beginDefinition;

dropWindowTurns[ nbo_NotebookObject ] := Scan[
    acpTurnDrop, (* also drops the turn's render caches *)
    Select[ Keys @ $acpTurns, acpTurnGet[ #, "Notebook", None ] === nbo & ]
];

dropWindowTurns // endDefinition;


(* Front end: delete the chat cells and start a new conversation UUID (no-op without a front end) *)
clearWindowCells // beginDefinition;

clearWindowCells[ nbo_NotebookObject ] := If[ $FrontEnd =!= Null,
    With[ { cells = Quiet @ Cells @ nbo },
        If[ MatchQ[ cells, { __CellObject } ], Quiet @ NotebookDelete @ cells ]
    ];
    Quiet[ CurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings", "ConversationUUID" } ] = createUUID[ ] ]
];

clearWindowCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Disconnecting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpDisconnect*)

(* Ends the connection of a window (window closed, directory change, reconnect, ...): a sent turn that is still running
   ends as stopped, pending permissions are answered "cancelled", the session is closed (best effort, no wait) and the
   connection is closed in a scheduled task (CloseACPConnection waits up to its grace period and kills the agent's
   process tree). The window becomes "Disconnected" and keeps its resumable session. Safe in any context. *)
acpDisconnect // beginDefinition;

acpDisconnect[ nbo_NotebookObject ] := acpDisconnect[ nbo, "User" ];

acpDisconnect[ nbo_NotebookObject, reason_ ] := Catch @ Module[ { window, conn, sid, pending, validQ },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window,
        (* No window record (e.g. already forgotten): close whatever this window still owns *)
        Scan[ releaseConnection, ownedConnectionsOf @ nbo ];
        Throw @ Null
    ];
    conn    = Lookup[ window, "Connection", None ];
    sid     = Lookup[ window, "SessionID", None ];
    pending = Keys @ pendingOf @ window;
    validQ  = validProjectDirectoryQ[ Lookup[ window, "ProjectDirectory", None ], window ];

    endSentTurn[ nbo, window, <| "StopReason" -> "cancelled" |>, "Stop" ];

    windowUpdate[
        nbo,
        Function[ w,
            <|
                w,
                "Status"             -> If[ validQ, "Disconnected", "NoDirectory" ],
                "Connection"         -> None,
                "ConnectToken"       -> None,
                "SessionID"          -> None,
                "Requests"           -> <| |>,
                "PendingPermissions" -> <| |>,
                "MCPReady"           -> False,
                "Restore"            -> loadingDropped @ w
            |>
        ]
    ];

    If[ acpConnectionQ @ conn,
        Scan[ answerOutcome[ conn, #, None ] &, pending ];
        If[ StringQ @ sid && closeCapableQ @ window, sendWithoutContinuation[ conn, "session/close", <| "sessionId" -> sid |> ] ];
        releaseConnection @ conn
    ];
    acpLog[ "Disconnected", <| "Reason" -> reason |> ];
    Null
];

acpDisconnect // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReconnect*)

(* The Reconnect action: disconnect (keeping the resumable session), clear the error and connect again. Reconnecting is
   a user action (a button, new settings), so it also clears a remote host's failure latch (Remote.wl). *)
acpReconnect // beginDefinition;

acpReconnect[ nbo_NotebookObject ] := Catch @ Module[ { window, validQ },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window, Throw @ Missing[ "NotFound" ] ];
    If[ connectingOrConnectedQ @ window, acpDisconnect[ nbo, "Reconnect" ] ];
    If[ StringQ @ acpWindowHostKey @ window, acpRemoteClearHostError @ acpWindowHostKey @ window ];
    validQ = validProjectDirectoryQ[ Lookup[ window, "ProjectDirectory", None ], window ];
    windowUpdate[ nbo, Function[ w, <| w, "Error" -> None, "Status" -> If[ validQ, "Disconnected", "NoDirectory" ] |> ] ];
    acpEnsureConnected @ nbo
];

acpReconnect // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Closing connections*)
registerConnection // beginDefinition;
registerConnection[ conn_, nbo_ ] := PreemptProtect[ $ownedConnections[ conn ] = nbo ];
registerConnection // endDefinition;


(* Forget a connection and close it shortly (in a scheduled task, never inside a reader handler) *)
releaseConnection // beginDefinition;

releaseConnection[ conn_? acpConnectionQ ] := (
    PreemptProtect[ $closingConnections[ conn ] = AbsoluteTime[ ] ];
    acpSchedule @ closeConnectionNow @ conn;
    Null
);

releaseConnection[ _ ] := Null;

releaseConnection // endDefinition;


closeConnectionNow // beginDefinition;

closeConnectionNow[ conn_ ] := (
    If[ openConnectionQ @ conn, Quiet @ Catch[ acpLink[ "CloseACPConnection" ][ conn ], _, Null & ] ];
    PreemptProtect[
        $closingConnections = KeySelect[ $closingConnections, # =!= conn & ];
        $ownedConnections   = KeySelect[ $ownedConnections  , # =!= conn & ]
    ];
    Null
);

closeConnectionNow // endDefinition;


closePendingConnections // beginDefinition;
closePendingConnections[ ] := Scan[ closeConnectionNow, Keys @ $closingConnections ];
closePendingConnections // endDefinition;


closingQ // beginDefinition;
closingQ[ conn_ ] := KeyExistsQ[ $closingConnections, conn ];
closingQ // endDefinition;


ownedConnectionsOf // beginDefinition;
ownedConnectionsOf[ nbo_ ] := Keys @ Select[ $ownedConnections, # === nbo & ];
ownedConnectionsOf // endDefinition;


(* Whether ACPLink still has the connection open *)
openConnectionQ // beginDefinition;
openConnectionQ[ conn_? acpConnectionQ ] := MemberQ[ acpLinkConnections[ ], conn ];
openConnectionQ[ _ ] := False;
openConnectionQ // endDefinition;


(* ACPLink's open connections (also other users' of the kernel) *)
acpLinkConnections // beginDefinition;

acpLinkConnections[ ] := If[ acpLoadACPLink[ ] === True,
    Replace[ Quiet @ acpLink[ "ACPConnections" ][ ], Except[ _List ] -> { } ],
    { }
];

acpLinkConnections // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Housekeeping*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpConnectionHousekeeping*)

(* Every second while the publisher runs (fallbacks for lost tasks and silent agents):
     * a Stop without a prompt response for $acpStopTimeout seconds ends the turn locally;
     * setup requests without a response for $acpConnectTimeout seconds fail the connection (a remote launch that
       reports progress restarts the clock, see observeLaunchProgress); a user config change without a response for
       $acpConfigTimeout seconds is dropped;
     * a connection attempt whose task never ran is scheduled again (at most $acpMaxConnectAttempts times);
     * MCP servers are assumed ready $acpMCPReadyTimeout seconds after the session started;
     * a connection that ACPLink no longer has open (agent died without an event) is treated as agent death.
   No timeout is decided by the first run after the kernel was blocked (more than $acpStallThreshold seconds since the
   previous run, or no previous run): housekeeping can run right after the evaluation that blocked it, in the same pump
   tick, while an answer that arrived meanwhile is still unread (ACPLink's readers are scheduled tasks too, and could
   not run either). Deciding then would fail an agent that answered, and close a remote launch that ssh had just
   reached (its launch script waits for the reader to see the trigger line). By the next run the readers have run: a
   later run is a later pump tick, and the readers run between two ticks. So the next run decides, even if it came late
   too: only one run in a row is skipped, or a kernel that stays busy (every run late) would never time anything out. *)
If[ ! NumberQ @ $lastHousekeepingAt, $lastHousekeepingAt = None ];
If[ ! BooleanQ @ $housekeepingSkipped, $housekeepingSkipped = False ];

connectionHousekeeping // beginDefinition;

connectionHousekeeping[ ] := With[ { now = AbsoluteTime[ ], last = $lastHousekeepingAt },
    $lastHousekeepingAt = now;
    With[ { stalled = (! NumberQ @ last || now - last > $acpStallThreshold) && ! TrueQ @ $housekeepingSkipped },
        $housekeepingSkipped = stalled;
        If[ stalled && NumberQ @ last, acpLog[ "HousekeepingGap", <| "Seconds" -> now - last |> ] ];
        KeyValueMap[ windowHousekeeping[ #1, #2, now, stalled ] &, $acpWindows ]
    ];
    Null
];

connectionHousekeeping // endDefinition;


windowHousekeeping // beginDefinition;

windowHousekeeping[ nbo_NotebookObject, window0_Association, now_, stalled_ ] := acpIsolated @ Module[ { window },
    window = observeLaunchProgress[ nbo, window0, now ];
    If[ ! TrueQ @ stalled,
        checkStopTimeout[ nbo, window, now ];
        checkRequestTimeouts[ nbo, window, now ];
        checkStuckConnect[ nbo, window, now ]
    ];
    checkMCPReady[ nbo, window, now ];
    If[ acpConnectionQ @ Lookup[ window, "Connection", None ], checkConnectionAlive[ nbo, window[ "Connection" ] ] ]
];

windowHousekeeping[ _, _, _, _ ] := Null;

windowHousekeeping // endDefinition;


(* A remote launch reports its progress on ssh's standard error: the trigger line once the remote shell runs, then the
   launch script's markers (home, cwd, agent; see SSH.wl's acpSSHLaunchMarkers). While "initialize" is unanswered,
   housekeeping counts these lines, and when there are more than before, the clock of the "initialize" request starts
   again: the setup timeout is the time the launch has not moved on, not the time since the start, so a slow sign-in
   (or a kernel that was blocked while it went on) does not fail a launch that has just reached the agent. A launch
   reports a handful of such lines, so the timeout restarts a few times at most. Reading the standard error here also
   writes a launch script whose trigger line arrived while ACPLink's reader could not run (the kernel was blocked:
   JSONRPCProcessStandardError releases it), so the agent starts now rather than after the next read. Gives the
   window record (updated). *)
observeLaunchProgress // beginDefinition;

observeLaunchProgress[ nbo_NotebookObject, window_Association, now_ ] := Module[ { conn, ids, count },
    conn = Lookup[ window, "Connection", None ];
    ids  = Keys @ Select[ requestsOf @ window, #[ "Kind" ] === "Initialize" & ];
    If[ ids === { } || ! acpRemoteQ @ window || ! acpConnectionQ @ conn, Return[ window, Module ] ];
    count = launchProgressCount[ Lookup[ window, "LaunchNonce", None ], Quiet @ conn[ "StandardError" ] ];
    If[ count <= Replace[ Lookup[ window, "LaunchProgress", 0 ], Except[ _Integer ] -> 0 ], Return[ window, Module ] ];
    acpLog[ "LaunchProgress", count ];
    Replace[
        windowUpdate[
            nbo,
            Function[ w,
                If[ Lookup[ w, "Connection", None ] === conn,
                    <| w, "LaunchProgress" -> count, "Requests" -> restartClocks[ requestsOf @ w, ids, now ] |>,
                    w
                ]
            ]
        ],
        Except[ _Association ] -> window
    ]
];

observeLaunchProgress[ _, window_, _ ] := window;

observeLaunchProgress // endDefinition;


(* The progress lines of the launch with this nonce in standard error so far: the trigger line and the markers *)
launchProgressCount // beginDefinition;

launchProgressCount[ nonce_String, stderr_String ] := With[ { prefix = $acpSSHMarkerPrefix <> nonce <> ":" },
    Count[
        StringDelete[ StringSplit[ stderr, "\n" ], "\r" ~~ EndOfString ],
        line_ /; line === $acpSSHLaunchTrigger || StringStartsQ[ line, prefix ]
    ]
];

launchProgressCount[ _, _ ] := 0;

launchProgressCount // endDefinition;


(* The requests with these IDs count from now *)
restartClocks // beginDefinition;

restartClocks[ requests_Association, ids_List, now_ ] := Fold[
    If[ KeyExistsQ[ #1, #2 ], <| #1, #2 -> <| #1[ #2 ], "SentAt" -> now |> |>, #1 ] &,
    requests,
    ids
];

restartClocks // endDefinition;


checkStopTimeout // beginDefinition;

checkStopTimeout[ nbo_, window_, now_ ] := Module[ { turnID, turn, stopped },
    turnID  = Lookup[ window, "CurrentTurn", None ];
    turn    = If[ StringQ @ turnID, acpTurnGet @ turnID, None ];
    stopped = If[ AssociationQ @ turn, Lookup[ turn, "StopRequestedAt", None ], None ];
    If[ NumberQ @ stopped && now - stopped > $acpStopTimeout && ! acpTurnEndedQ @ turn,
        acpLog[ "StopTimeout", turnID ];
        windowUpdate[
            nbo,
            Function[ w, <| w, "Requests" -> Select[ requestsOf @ w, ! MatchQ[ #, KeyValuePattern @ { "Kind" -> "Prompt", "Data" -> KeyValuePattern[ "TurnID" -> turnID ] } ] & ] |> ]
        ];
        endTurnLocally[ nbo, turnID, <| "StopReason" -> "cancelled" |>, None ]
    ]
];

checkStopTimeout // endDefinition;


checkRequestTimeouts // beginDefinition;

checkRequestTimeouts[ nbo_, window_, now_ ] := Module[
    { requests, conn, late, setupLate, configLate, loadLate, listLate, deleteLate, abandoned, timeout },
    requests   = requestsOf @ window;
    conn       = Lookup[ window, "Connection", None ];
    late       = Select[ requests, requestLateQ[ window, #, now ] & ];
    setupLate  = Select[ late, MatchQ[ #[ "Kind" ], $$setupRequestKind ] & ];
    configLate = Select[ late, #[ "Kind" ] === "SetConfig" & ];
    loadLate   = Select[ late, #[ "Kind" ] === "SessionLoad" & ];
    listLate   = Select[ late, #[ "Kind" ] === "SessionList" & ];
    deleteLate = Select[ late, #[ "Kind" ] === "SessionDelete" & ];
    abandoned  = Select[ requests, #[ "Kind" ] === "AbandonedLoad" && now - #[ "SentAt" ] > $acpAbandonedLoadExpiry & ];
    timeout    = acpErrorInfo[ "Timeout", None, None, <| "Agent" -> agentDisplayName @ window |> ];
    If[ Length @ setupLate > 0 && acpConnectionQ @ conn,
        failConnection[ nbo, conn, If[ acpRemoteQ @ window, remoteTimeoutError[ window, conn ], timeout ] ]
    ];
    KeyValueMap[
        Function[ { id, info },
            dropRequest[ nbo, id ];
            windowUpdate[
                nbo,
                Function[ w,
                    If[ currentSessionRequestQ[ w, info[ "Data" ] ],
                        <| w, "PendingConfig" -> dropPendingValue[ pendingConfigOf @ w, info[ "Data", "ConfigID" ], info[ "Data", "Value" ] ] |>,
                        w
                    ]
                ]
            ]
        ],
        configLate
    ];
    (* A load that times out fails like one with an error response (sessionLoadFailed): on the window's connection the
       window goes back to the session it showed; during the connection setup it continues with the session it would
       have used without the restore (whose own setup timeout still catches an agent that hangs). The request is kept
       as "AbandonedLoad", so that a late successful response closes the session it attached. *)
    KeyValueMap[
        Function[ { id, info },
            abandonLoadRequest[ nbo, id, now ];
            acpLog[ "SessionLoadTimeout", <| "Mode" -> info[ "Data", "Mode" ] |> ];
            sessionLoadFailed[ nbo, conn, info[ "Data" ], timeout ]
        ],
        loadLate
    ];
    KeyValueMap[ dropRequest[ nbo, #1 ] &, abandoned ];
    KeyValueMap[
        Function[ { id, info },
            dropRequest[ nbo, id ];
            acpSessionsListFailed[ nbo, info[ "Data", "Token" ], <| "Code" -> "Timeout", "Message" -> timeout[ "Message" ] |> ]
        ],
        listLate
    ];
    KeyValueMap[
        Function[ { id, info },
            dropRequest[ nbo, id ];
            acpSessionsDeleteFailed[ nbo, info[ "Data", "SessionID" ], acpConnectionLabel[ "SessionsDeleteFailed", <| "message" -> timeout[ "Message" ] |> ] ]
        ],
        deleteLate
    ]
];

checkRequestTimeouts // endDefinition;


(* Whether an outstanding request has waited too long for its response *)
requestLateQ // beginDefinition;

requestLateQ[ window_, request_Association, now_ ] := With[ { sent = Lookup[ request, "SentAt", now ] },
    Switch[ Lookup[ request, "Kind", None ],
        $$setupRequestKind, now - sent > $acpConnectTimeout,
        "SetConfig"       , now - sent > $acpConfigTimeout,
        (* a long replay arrives over many reader ticks: the load times out after its last replayed update *)
        "SessionLoad"     , now - Max[ sent, replayActivity[ window, Lookup[ request, "Data", <| |> ] ] ] > $acpSessionLoadTimeout,
        "SessionList"     , now - sent > $acpSessionListTimeout,
        "SessionDelete"   , now - sent > $acpSessionDeleteTimeout,
        _                 , False
    ]
];

requestLateQ // endDefinition;


(* The record of a load request that timed out stays (kind "AbandonedLoad", counted from now for its expiry) *)
abandonLoadRequest // beginDefinition;

abandonLoadRequest[ nbo_NotebookObject, id_, now_ ] := windowUpdate[
    nbo,
    Function[ w,
        With[ { requests = requestsOf @ w },
            If[ KeyExistsQ[ requests, id ],
                <| w, "Requests" -> <| requests, id -> <| requests[ id ], "Kind" -> "AbandonedLoad", "SentAt" -> now |> |> |>,
                w
            ]
        ]
    ]
];

abandonLoadRequest // endDefinition;


(* When the restore of a load request last made progress (its last replayed update) *)
replayActivity // beginDefinition;

replayActivity[ window_Association, data_Association ] := Replace[
    Lookup[ window, "Restore", None ],
    { r: KeyValuePattern @ { "Token" -> t_, "LastUpdateAt" -> time_? NumberQ } /; t === Lookup[ data, "Token", None ] :> time, _ -> 0 }
];

replayActivity[ _, _ ] := 0;

replayActivity // endDefinition;


checkStuckConnect // beginDefinition;

checkStuckConnect[ nbo_, window_, now_ ] := Module[ { token, scheduled, attempts },
    token     = Lookup[ window, "ConnectToken", None ];
    scheduled = Lookup[ window, "ConnectScheduledAt", None ];
    attempts  = Replace[ Lookup[ window, "ConnectAttempts", 1 ], Except[ _Integer ] -> 1 ];
    If[ StringQ @ token && ! acpConnectionQ @ Lookup[ window, "Connection", None ] && NumberQ @ scheduled && now - scheduled > $acpRescheduleAfter,
        If[ attempts >= $acpMaxConnectAttempts,
            failConnectAttempt[
                nbo,
                token,
                If[ acpRemoteQ @ window,
                    remoteTimeoutError[ window, None ],
                    acpErrorInfo[ "Timeout", None, None, <| "Agent" -> agentDisplayName @ window |> ]
                ]
            ],
            windowUpdate[
                nbo,
                Function[ w, If[ currentTokenQ[ w, token ], <| w, "ConnectScheduledAt" -> now, "ConnectAttempts" -> attempts + 1 |>, w ] ]
            ];
            acpLog[ "ConnectRescheduled", attempts ];
            acpSchedule @ acpConnect[ nbo, token ]
        ]
    ]
];

checkStuckConnect // endDefinition;


checkMCPReady // beginDefinition;

checkMCPReady[ nbo_, window_, now_ ] := With[ { started = Lookup[ window, "SessionStartedAt", None ] },
    If[ MemberQ[ { "Ready", "Running" }, Lookup[ window, "Status", None ] ] && Lookup[ window, "MCPReady", False ] =!= True &&
            NumberQ @ started && now - started > $acpMCPReadyTimeout,
        windowUpdate[ nbo, <| #, "MCPReady" -> True |> & ]
    ]
];

checkMCPReady // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*connectionSweep*)

(* Every 10 seconds while the publisher runs:
     * windows whose notebook was closed without the "WindowClose" event (e.g. programmatically) are disconnected and
       forgotten through UI.wl's "WindowClosed" action;
     * connections started here that no window refers to any more are closed. *)
connectionSweep // beginDefinition;

connectionSweep[ ] := (sweepClosedWindows[ ]; sweepOrphanConnections[ ]; Null);

connectionSweep // endDefinition;


sweepClosedWindows // beginDefinition;

sweepClosedWindows[ ] := If[ ! TrueQ @ $acpAssumeWindowsOpen && $FrontEnd =!= Null,
    With[ { notebooks = Quiet @ Notebooks[ ] },
        If[ ListQ @ notebooks,
            KeyValueMap[
                Function[ { nbo, window },
                    If[ activeWindowQ @ window && ! notebookOpenQ[ nbo, notebooks ],
                        acpLog[ "SweptClosedWindow", nbo ];
                        acpAction[ "WindowClosed", nbo ]
                    ]
                ],
                $acpWindows
            ]
        ]
    ]
];

sweepClosedWindows // endDefinition;


sweepOrphanConnections // beginDefinition;

sweepOrphanConnections[ ] := Module[ { referenced },
    referenced = Cases[ Values @ $acpWindows, KeyValuePattern[ "Connection" -> c_? acpConnectionQ ] :> c ];
    Scan[
        If[ ! MemberQ[ referenced, # ] && ! closingQ @ #, acpLog[ "SweptOrphanConnection", # ]; releaseConnection @ # ] &,
        Keys @ $ownedConnections
    ]
];

sweepOrphanConnections // endDefinition;


activeWindowQ // beginDefinition;
activeWindowQ[ window_Association ] := connectingOrConnectedQ @ window;
activeWindowQ[ _ ] := False;
activeWindowQ // endDefinition;


acpRegisterHousekeeping[ "ACPConnection"     , connectionHousekeeping, 5  ];
acpRegisterHousekeeping[ "ACPConnectionSweep", connectionSweep       , 50 ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Errors*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpErrorInfo*)

(* The error table. Gives <| "Code", "Message", "Hint", "Output", "Detail", "Actions", "Data" |> for
     * acpErrorInfo[failure] (ACPLink loading, agent lookup, agent exit, ssh not found, invalid SSH settings), or
     * acpErrorInfo[code, message, data, context]: code is a JSON-RPC error code (with the agent's message and error
       data) or one of our codes ("ConnectFailed", "InitFailed", the SSH and Remote kinds of SSH.wl, ...); context may
       give "Agent", "Model", "Default" (the code to use if the error is not recognized), "ExitCode",
       "StandardErrorTail", "Path", "InstallURL", and for remote windows "Host", "Command", "Example", "Windows",
       "Output" (ssh's or the remote side's text, neutralized), "Hints" (keys of additional advice), "HintKey" (replaces
       the kind's own advice; None for none), "Detail" (of invalid SSH settings).
   "Message" is our sentence, "Hint" our advice, "Output" what the agent, ssh or the remote side said (neutralized), and
   "Detail" both (for the full view, logs and copying).
   "Actions" are the buttons of acpErrorView: "ChooseModel", "SignIn", "Reconnect", "LocateAgent", "ChooseDirectory". *)
acpErrorInfo // beginDefinition;

acpErrorInfo[ failure: Failure[ tag_String, as_Association ] ] := acpErrorInfo[
    tag,
    If[ KeyExistsQ[ as, "MessageTemplate" ], Replace[ Quiet @ failure[ "Message" ], Except[ _String ] -> None ], None ],
    None,
    KeyTake[
        as,
        {
            "Agent", "ExitCode", "StandardErrorTail", "Path", "InstallURL",
            "Host", "Command", "Example", "Hints", "Detail", "Windows", "Output"
        }
    ]
];

acpErrorInfo[ failure_Failure ] := acpErrorInfo[ "AgentError", Quiet @ failure[ "Message" ], None, <| |> ];

acpErrorInfo[ code_ ] := acpErrorInfo[ code, None, None, <| |> ];
acpErrorInfo[ code_, message_ ] := acpErrorInfo[ code, message, None, <| |> ];
acpErrorInfo[ code_, message_, data_ ] := acpErrorInfo[ code, message, data, <| |> ];

acpErrorInfo[ code_, message_, data_, context_Association ] := Module[ { kind, agent, model, text, hint, output, detail },
    kind   = classifyError[ code, message, data, Lookup[ context, "Default", "AgentError" ] ];
    agent  = Replace[ Lookup[ context, "Agent", "OpenCode" ], Except[ _String ] -> "OpenCode" ];
    model  = Lookup[ context, "Model", None ];
    text   = errorText[ kind, agent, model, context ];
    hint   = errorHint[ kind, agent, context ];
    output = errorOutput[ kind, message, text, context ];
    detail = truncateDetail @ Replace[ StringRiffle[ DeleteCases[ { hint, output }, None ], "\n\n" ], "" -> None ];
    <|
        "Code"    -> kind,
        "Message" -> text,
        "Hint"    -> hint,
        "Output"  -> output,
        "Detail"  -> detail,
        "Actions" -> Lookup[ $errorActions, kind, { } ],
        "Data"    -> <|
            "ErrorCode"    -> code,
            "ErrorMessage" -> message,
            "ErrorData"    -> data,
            "ExitCode"     -> Lookup[ context, "ExitCode", None ],
            "Host"         -> Lookup[ context, "Host", None ]
        |>
    |>
];

acpErrorInfo // endDefinition;


$errorActions = <|
    "ACPLinkMissing"   -> { "Reconnect" },
    "ACPLinkTooOld"    -> { "Reconnect" },
    "UnknownAgent"     -> { },
    "AgentNotFound"    -> { "LocateAgent", "Reconnect" },
    "ConnectFailed"    -> { "LocateAgent", "Reconnect" },
    "InitFailed"       -> { "Reconnect" },
    "SessionFailed"    -> { "Reconnect" },
    "Timeout"          -> { "Reconnect" },
    "AgentExited"      -> { "Reconnect" },
    "NotConnected"     -> { "Reconnect" },
    "SendFailed"       -> { "Reconnect" },
    "ModelUnavailable" -> { "ChooseModel" },
    "AuthRequired"     -> { "SignIn", "Reconnect" },
    "NoModels"         -> { "SignIn", "Reconnect" },
    "ProviderError"    -> { "ChooseModel" },
    "ServerUnavailable"-> { "Reconnect" },
    "AgentError"       -> { },

    (* Remote windows (SSH.wl); one-shot operations (Remote.wl) replace the actions with their own *)
    "SSHNotFound"             -> { "Reconnect" },
    "SSHStartFailed"          -> { "Reconnect" },
    "SSHHostKeyUnknown"       -> { "Reconnect" },
    "SSHHostKeyChanged"       -> { "Reconnect" },
    "SSHAuthFailed"           -> { "Reconnect" },
    "SSHHostNotFound"         -> { "Reconnect" },
    "SSHConnectionRefused"    -> { "Reconnect" },
    "SSHUnreachable"          -> { "Reconnect" },
    "SSHBadArguments"         -> { "Reconnect" },
    "SSHConnectTimeout"       -> { "Reconnect" },
    "SSHConnectionLost"       -> { "Reconnect" },
    "SSHFailed"               -> { "Reconnect" },
    "RemoteFolderMissing"     -> { "ChooseDirectory", "Reconnect" },
    "RemoteFolderAccess"      -> { "ChooseDirectory", "Reconnect" },
    "RemoteAgentNotFound"     -> { "Reconnect" },
    "RemoteAgentExited"       -> { "Reconnect" },
    "RemoteTimeout"           -> { "Reconnect" },
    "RemoteScriptFailed"      -> { "Reconnect" },
    "RemoteOperationTimedOut" -> { },
    "InvalidSSHSettings"      -> { }
|>;

$errorLabels = <|
    "ACPLinkMissing"   -> "ErrorACPLinkMissing",
    "ACPLinkTooOld"    -> "ErrorACPLinkTooOld",
    "UnknownAgent"     -> "ErrorUnknownAgent",
    "AgentNotFound"    -> "ErrorAgentNotFound",
    "ConnectFailed"    -> "ErrorConnectFailed",
    "InitFailed"       -> "ErrorInitFailed",
    "SessionFailed"    -> "ErrorSessionFailed",
    "Timeout"          -> "ErrorTimeout",
    "AgentExited"      -> "ErrorAgentExited",
    "NotConnected"     -> "ErrorNotConnected",
    "SendFailed"       -> "ErrorSendFailed",
    "AuthRequired"     -> "ErrorAuthRequired",
    "NoModels"         -> "ErrorNoModels",
    "ProviderError"    -> "ErrorProviderError",
    "ServerUnavailable"-> "ErrorServerUnavailable",
    "AgentError"       -> "ErrorAgent",

    (* Remote windows (SSH.wl) *)
    "SSHNotFound"             -> "ErrorSSHNotFound",
    "SSHStartFailed"          -> "ErrorSSHStartFailed",
    "SSHHostKeyUnknown"       -> "ErrorSSHHostKeyUnknown",
    "SSHHostKeyChanged"       -> "ErrorSSHHostKeyChanged",
    "SSHAuthFailed"           -> "ErrorSSHAuthFailed",
    "SSHHostNotFound"         -> "ErrorSSHHostNotFound",
    "SSHConnectionRefused"    -> "ErrorSSHConnectionRefused",
    "SSHUnreachable"          -> "ErrorSSHUnreachable",
    "SSHBadArguments"         -> "ErrorSSHBadArguments",
    "SSHConnectTimeout"       -> "ErrorSSHConnectTimeout",
    "SSHConnectionLost"       -> "ErrorSSHConnectionLost",
    "SSHFailed"               -> "ErrorSSHFailed",
    "RemoteFolderMissing"     -> "ErrorRemoteFolderMissing",
    "RemoteFolderAccess"      -> "ErrorRemoteFolderAccess",
    "RemoteAgentNotFound"     -> "ErrorRemoteAgentNotFound",
    "RemoteAgentExited"       -> "ErrorRemoteAgentExited",
    "RemoteTimeout"           -> "ErrorRemoteTimeout",
    "RemoteScriptFailed"      -> "ErrorRemoteScriptFailed",
    "RemoteOperationTimedOut" -> "ErrorRemoteOperationTimedOut",
    "InvalidSSHSettings"      -> "ErrorInvalidSSHSettings"
|>;


classifyError // beginDefinition;

classifyError[ code_, message_, data_, default_ ] := Module[ { msg, name },
    msg  = If[ StringQ @ message, message, "" ];
    name = Replace[ If[ AssociationQ @ data, Lookup[ data, "errorName", None ], None ], Except[ _String ] -> "" ];
    Which[
        StringQ @ code && KeyExistsQ[ $errorActions, code ],
            code,
        code === -32000 || StringContainsQ[ msg, "auth" ~~ ___ ~~ "required", IgnoreCase -> True ],
            "AuthRequired",
        StringContainsQ[ msg, "No models are available", IgnoreCase -> True ] || name === "CatalogNotReady",
            "NoModels",
        (* other provider.invalid-request errors (e.g. context length) are ProviderErrors: the model may work again *)
        StringContainsQ[ msg, "deprecated", IgnoreCase -> True ] ||
            StringContainsQ[ msg, "model" ~~ ___ ~~ ("not found" | "not supported" | "does not exist"), IgnoreCase -> True ],
            "ModelUnavailable",
        name === "ServerUnavailable",
            "ServerUnavailable",
        StringStartsQ[ name, "provider." ],
            "ProviderError",
        StringQ @ default && KeyExistsQ[ $errorActions, default ],
            default,
        True,
            "AgentError"
    ]
];

classifyError // endDefinition;


errorText // beginDefinition;

errorText[ "ModelUnavailable", agent_, model_String, _ ] :=
    acpConnectionLabel[ "ErrorModelUnavailable", <| "model" -> model, "agent" -> agent |> ];

errorText[ "ModelUnavailable", _, _, _ ] :=
    acpConnectionLabel[ "ErrorModelUnavailableGeneric" ];

(* A remote agent's sign-in happens on its host: the text names the host (the instruction with the ssh command for a
   terminal is the advice, see errorHint) *)
errorText[ kind: "AuthRequired" | "NoModels", agent_, _, context_ ] /; StringQ @ Lookup[ context, "Host", None ] :=
    acpConnectionLabel[ "Error" <> kind <> "Remote", errorParameters[ agent, context ] ];

(* An "Executable" of the "SSHSettings" that was not found is named (SSH.wl's acpFindSSH gives it as "Path"), so that a
   typo in it is not mistaken for a missing OpenSSH client *)
errorText[ "SSHNotFound", agent_, _, context_ ] /; StringQ @ Lookup[ context, "Path", None ] :=
    acpConnectionLabel[ "ErrorSSHNotFoundPath", errorParameters[ agent, context ] ];

errorText[ kind_String, agent_, _, context_ ] :=
    acpConnectionLabel[ Lookup[ $errorLabels, kind, "ErrorAgent" ], errorParameters[ agent, context ] ];

errorText // endDefinition;


(* The parameters of the error texts. Every key a template uses is given ("" if the context has no value), because
   TemplateApply silently inserts "" for a missing key. Remote paths are shown with acpRemoteDisplayName. *)
errorParameters // beginDefinition;

errorParameters[ agent_, context_Association ] := <|
    "agent"   -> Replace[ Lookup[ context, "Agent", agent ], Except[ _String ] -> agent ],
    "host"    -> parameterText @ Lookup[ context, "Host", None ],
    "path"    -> parameterText @ acpRemoteDisplayName @ Lookup[ context, "Path", None ],
    "command" -> parameterText @ Lookup[ context, "Command", None ],
    "url"     -> parameterText @ Lookup[ context, "InstallURL", None ],
    "example" -> parameterText @ Lookup[ context, "Example", None ],
    "code"    -> Replace[ Lookup[ context, "ExitCode", None ], Except[ _Integer ] -> "" ]
|>;

errorParameters // endDefinition;


parameterText // beginDefinition;
parameterText[ s_String ] := acpNeutralizeLinearSyntax @ s;
parameterText[ _ ] := "";
parameterText // endDefinition;


(* Our advice below the friendly message: install hints, the exit code, what to do about an ssh failure *)
errorHint // beginDefinition;

errorHint[ "AgentNotFound", _, context_ ] := Which[
    StringQ @ Lookup[ context, "Path", None ],
        acpConnectionLabel[ "ErrorAgentNotFoundPath", <| "path" -> context[ "Path" ] |> ],
    StringQ @ Lookup[ context, "InstallURL", None ],
        acpConnectionLabel[ "ErrorAgentNotFoundDetail", <| "url" -> context[ "InstallURL" ] |> ],
    True,
        None
];

errorHint[ "AgentExited", _, context_ ] := With[ { code = Lookup[ context, "ExitCode", None ] },
    If[ IntegerQ @ code, acpConnectionLabel[ "ErrorAgentExitedDetail", <| "code" -> code |> ], None ]
];

errorHint[ "InvalidSSHSettings", _, context_ ] := Replace[
    Lookup[ context, "Detail", None ],
    Except[ _String? (StringLength @ StringTrim @ # > 0 &) ] -> None
];

(* Remote windows: the kind's own advice ("Error" <> kind <> "Detail", the exit code for RemoteAgentExited, the Windows
   variant for SSHNotFound, or context "HintKey"), then the context's "Hints", each a paragraph *)
errorHint[ kind_String, agent_, context_ ] /; remoteErrorKindQ @ kind := Module[ { base, keys, params },
    base = Which[
        KeyExistsQ[ context, "HintKey" ], context[ "HintKey" ],
        kind === "RemoteAgentExited", If[ IntegerQ @ Lookup[ context, "ExitCode", None ], "ErrorAgentExitedDetail", None ],
        kind === "SSHNotFound" && StringQ @ Lookup[ context, "Path", None ], "ErrorSSHNotFoundPathDetail",
        kind === "SSHNotFound" && TrueQ @ Lookup[ context, "Windows", False ], "ErrorSSHNotFoundDetailWindows",
        True, "Error" <> kind <> "Detail"
    ];
    keys = Select[
        DeleteDuplicates @ Prepend[ Replace[ Lookup[ context, "Hints", { } ], Except[ { ___String } ] -> { } ], base ],
        StringQ[ # ] && KeyExistsQ[ $acpConnectionStrings, # ] &
    ];
    params = errorParameters[ agent, context ];
    Replace[ StringRiffle[ acpConnectionLabel[ #, params ] & /@ keys, "\n\n" ], "" -> None ]
];

(* A remote agent's sign-in runs on its host: the message stays short, and the advice is the instruction with the ssh
   command for a terminal (the toolbar shows it in the details, with "Copy") *)
errorHint[ kind: "AuthRequired" | "NoModels", agent_, context_ ] /; StringQ @ Lookup[ context, "Host", None ] :=
    acpConnectionLabel[ "Error" <> kind <> "RemoteDetail", errorParameters[ agent, context ] ];

errorHint[ _, _, _ ] := None;

errorHint // endDefinition;


(* What the agent, ssh or the remote side said (neutralized): the end of the agent's stderr, the cleaned ssh text of
   SSH.wl, or the agent's own message if it is not our sentence *)
errorOutput // beginDefinition;

errorOutput[ "AgentNotFound" | "InvalidSSHSettings", _, _, _ ] := None;

errorOutput[ "AgentExited", _, _, context_ ] :=
    truncateDetail @ acpNeutralizeLinearSyntax @ stderrTail @ Lookup[ context, "StandardErrorTail", None ];

errorOutput[ kind_String, _, _, context_ ] /; remoteErrorKindQ @ kind := Replace[
    Lookup[ context, "Output", None ],
    { s_String /; StringLength @ StringTrim @ s > 0 :> truncateDetail @ acpNeutralizeLinearSyntax @ s, _ -> None }
];

errorOutput[ _, message_String, text_, _ ] /; StringLength @ StringTrim @ message > 0 && StringTrim @ message =!= text :=
    truncateDetail @ acpNeutralizeLinearSyntax @ StringTrim @ message;

errorOutput[ _, _, _, _ ] := None;

errorOutput // endDefinition;


(* The kinds of remote windows (SSH.wl, Remote.wl) *)
remoteErrorKindQ // beginDefinition;
remoteErrorKindQ[ kind_String ] := StringStartsQ[ kind, "SSH" | "Remote" ];
remoteErrorKindQ // endDefinition;


stderrTail // beginDefinition;

stderrTail[ s_String ] := Module[ { lines },
    lines = StringSplit[ StringTrim @ s, "\n" ];
    Replace[ StringTrim @ StringRiffle[ Take[ lines, -Min[ Length @ lines, $acpStderrLines ] ], "\n" ], "" -> None ]
];

stderrTail[ _ ] := None;

stderrTail // endDefinition;


truncateDetail // beginDefinition;
truncateDetail[ s_String ] := If[ StringLength @ s > $acpMaxDetailLength, "\[Ellipsis]" <> StringTake[ s, -$acpMaxDetailLength ], s ];
truncateDetail[ other_ ] := other;
truncateDetail // endDefinition;


(* The error of an error response; for a remote window with its host and the ssh command for a terminal (sign-in texts) *)
responseError // beginDefinition;

responseError[ window_, resp_Association, default_String ] := acpErrorInfo[
    resp[ "Code" ],
    resp[ "Message" ],
    resp[ "Data" ],
    <|
        "Agent"   -> agentDisplayName @ window,
        "Model"   -> currentModel @ window,
        "Default" -> default,
        If[ AssociationQ @ acpWindowSSH @ window,
            Sequence @@ {
                "Host"    -> acpWindowHostLabel @ window,
                "Command" -> acpSSHTerminalCommand @ acpWindowSSH @ window
            },
            Nothing
        ]
    |>
];

responseError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpConnectionQ*)
acpConnectionQ // beginDefinition;
acpConnectionQ[ h_Symbol[ _String ] ] := SymbolName @ h === "ACPConnection";
acpConnectionQ[ _ ] := False;
acpConnectionQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpWindowAliveQ*)

(* Whether the window still exists: its notebook is open (front end call: not for reader handlers). Without a front end
   (or with $acpAssumeWindowsOpen) a window exists while it has a record. *)
acpWindowAliveQ // beginDefinition;

acpWindowAliveQ[ nbo_NotebookObject ] := Which[
    ! AssociationQ @ acpWindowGet @ nbo,
        False,
    TrueQ @ $acpAssumeWindowsOpen || $FrontEnd === Null,
        True,
    True,
        notebookOpenQ[ nbo, Quiet @ Notebooks[ ] ]
];

acpWindowAliveQ[ _ ] := False;

acpWindowAliveQ // endDefinition;


(* Notebooks[] may not list every window (e.g. while it is invisible); NotebookInformation fails for closed ones *)
notebookOpenQ // beginDefinition;
notebookOpenQ[ nbo_NotebookObject, notebooks_List ] := MemberQ[ notebooks, nbo ] || ListQ @ Quiet @ NotebookInformation @ nbo;
notebookOpenQ[ _NotebookObject, _ ] := True; (* no answer from the front end: assume open *)
notebookOpenQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Window records*)

(* acpWindowUpdate for existing window records only (acpWindowUpdate would create a record for an unknown window).
   f gives the new record; anything else leaves it unchanged. *)
windowUpdate // beginDefinition;
windowUpdate[ nbo_NotebookObject, f_ ] := acpWindowUpdate[ nbo, Function[ w, If[ existingWindowQ @ w, f @ w, Missing[ "NotFound" ] ] ] ];
windowUpdate // endDefinition;


existingWindowQ // beginDefinition;
existingWindowQ[ w_Association ] := KeyExistsQ[ w, "Status" ];
existingWindowQ[ _ ] := False;
existingWindowQ // endDefinition;


currentTokenQ // beginDefinition;
currentTokenQ[ window_Association, token_String ] := Lookup[ window, "ConnectToken", None ] === token;
currentTokenQ[ _, _ ] := False;
currentTokenQ // endDefinition;


(* A connection exists or is being set up *)
connectingOrConnectedQ // beginDefinition;
connectingOrConnectedQ[ window_Association ] := StringQ @ Lookup[ window, "ConnectToken", None ] || acpConnectionQ @ Lookup[ window, "Connection", None ];
connectingOrConnectedQ[ _ ] := False;
connectingOrConnectedQ // endDefinition;


runningTurnQ // beginDefinition;

runningTurnQ[ window_Association ] := With[ { turnID = Lookup[ window, "CurrentTurn", None ] },
    StringQ @ turnID && With[ { turn = acpTurnGet @ turnID },
        AssociationQ @ turn && StringQ @ Lookup[ turn, "RequestID", None ] && ! acpTurnEndedQ @ turn
    ]
];

runningTurnQ[ _ ] := False;

runningTurnQ // endDefinition;


(* A local folder must exist; a remote one (also with invalid SSH settings) must be an absolute or ~/ path: it is never
   checked on this computer (the launch script reports a missing one) *)
validProjectDirectoryQ // beginDefinition;
validProjectDirectoryQ[ dir_, window_ ] := acpProjectDirectoryQ[ dir, acpWindowSSH @ window ];
validProjectDirectoryQ // endDefinition;


requestsOf      // beginDefinition;
requestsOf[ w_ ] := Replace[ Lookup[ w, "Requests", <| |> ], Except[ _Association ] -> <| |> ];
requestsOf      // endDefinition;

pendingOf       // beginDefinition;
pendingOf[ w_ ] := Replace[ Lookup[ w, "PendingPermissions", <| |> ], Except[ _Association ] -> <| |> ];
pendingOf       // endDefinition;

pendingConfigOf // beginDefinition;
pendingConfigOf[ w_ ] := Replace[ Lookup[ w, "PendingConfig", <| |> ], Except[ _Association ] -> <| |> ];
pendingConfigOf // endDefinition;

configOptionsOf // beginDefinition;
configOptionsOf[ w_ ] := Select[ Replace[ Lookup[ w, "ConfigOptions", { } ], Except[ _List ] -> { } ], AssociationQ ];
configOptionsOf // endDefinition;

settingsOf      // beginDefinition;
settingsOf[ w_ ] := Replace[ Lookup[ w, "Settings", <| |> ], Except[ _Association ] -> <| |> ];
settingsOf      // endDefinition;

failedModelsOf  // beginDefinition;
failedModelsOf[ w_ ] := Replace[ Lookup[ w, "FailedModels", { } ], Except[ _List ] -> { } ];
failedModelsOf  // endDefinition;


currentModel // beginDefinition;
(* acpFindConfigOption gives a Missing when there are no config options (e.g. session/new failed) *)
currentModel[ window_Association ] := Replace[
    Lookup[ Replace[ acpFindConfigOption[ configOptionsOf @ window, "model" ], Except[ _Association ] -> <| |> ], "currentValue", None ],
    Except[ _String ] -> None
];
currentModel[ _ ] := None;
currentModel // endDefinition;


agentDisplayName // beginDefinition;

agentDisplayName[ window_Association ] := Replace[
    Lookup[ Replace[ Lookup[ window, "AgentInfo", None ], Except[ _Association ] -> <| |> ], "Name", Lookup[ window, "Agent", "OpenCode" ] ],
    Except[ _String? (StringLength[ # ] > 0 &) ] :> Replace[ Lookup[ window, "Agent", "OpenCode" ], Except[ _String ] -> "OpenCode" ]
];

agentDisplayName[ _ ] := "OpenCode";

agentDisplayName // endDefinition;


(* The agent's name and version from its initialize response: text the agent chose, shown in labels, the toolbar and
   error messages, so it is neutralized here, once (acpNeutralizeLinearSyntax) *)
agentInfoOf // beginDefinition;

agentInfoOf[ info_Association, window_ ] := <|
    "Name"    -> agentText @ Replace[ Lookup[ info, "title", None ], Except[ _String ] :> Replace[ Lookup[ info, "name", None ], Except[ _String ] :> agentDisplayName @ window ] ],
    "Version" -> agentText @ Replace[ Lookup[ info, "version", "" ], Except[ _String ] -> "" ]
|>;

agentInfoOf // endDefinition;


agentText // beginDefinition;
agentText[ s_String ] := acpNeutralizeLinearSyntax @ StringTake[ s, UpTo[ 200 ] ];
agentText // endDefinition;


(* The association inside ACPNotification[...], ACPRequest[...], ACPResponse[...] or JSONRPCProcessRequest[...] *)
messageData // beginDefinition;
messageData[ _[ data_Association ] ] := data;
messageData[ data_Association ] := data;
messageData[ _ ] := <| |>;
messageData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
