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
$acpMaxDetailLength    = 1500;
$acpStderrLines        = 12;
$acpClientName         = "wolfram-chatbook";
$acpClientTitle        = "Wolfram Chatbook";

$$setupRequestKind = "Initialize" | "SessionNew" | "SessionResume" | "Config";

(* Set to True to treat every window that has a record as open (tests without a front end use fake NotebookObjects). *)
If[ ! BooleanQ @ $acpAssumeWindowsOpen, $acpAssumeWindowsOpen = False ];

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

    validQ = validProjectDirectoryQ @ Lookup[ window, "ProjectDirectory", None ];
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
   initialize -> session/resume (if possible) or session/new -> config options (model, effort, mode) -> "Ready". *)
acpConnect // beginDefinition;

acpConnect[ nbo_NotebookObject, token_String ] := Catch @ Module[
    { window, dir, load, agent, settings, spec, prefs, conn, claimed = False },

    window = acpWindowGet @ nbo;
    If[ ! currentTokenQ[ window, token ], Throw @ Null ];
    If[ ! acpWindowAliveQ @ nbo, abandonConnectAttempt[ nbo, token ]; Throw @ Null ];

    (* Free the memory of connections that are still being closed before another agent is started: *)
    closePendingConnections[ ];

    dir = Lookup[ window, "ProjectDirectory", None ];
    If[ ! validProjectDirectoryQ @ dir, failConnectAttempt[ nbo, token, None ]; Throw @ Null ];
    dir = Quiet @ ExpandFileName @ dir;

    load = acpLoadACPLink[ ];
    If[ FailureQ @ load, failConnectAttempt[ nbo, token, acpErrorInfo @ load ]; Throw @ Null ];

    agent    = Replace[ Lookup[ window, "Agent", "OpenCode" ], Except[ _String ] -> "OpenCode" ];
    settings = settingsOf @ window;
    spec     = acpAgentSpec[ agent, settings ];
    If[ FailureQ @ spec, failConnectAttempt[ nbo, token, acpErrorInfo @ spec ]; Throw @ Null ];

    (* Front end reads/writes happen here, not in the handlers: *)
    prefs = agentPreferences @ agent;
    acpSetPersistedSetting[ "LastProjectDirectory", dir ];

    (* The window may have been closed or reset in the meantime: *)
    If[ ! currentTokenQ[ acpWindowGet @ nbo, token ], Throw @ Null ];

    conn = openConnection[ nbo, spec, dir ];
    If[ ! acpConnectionQ @ conn,
        failConnectAttempt[ nbo, token, acpErrorInfo[ "ConnectFailed", None, None, <| "Agent" -> spec[ "Name" ] |> ] ];
        Throw @ Null
    ];
    registerConnection[ conn, nbo ];

    windowUpdate[
        nbo,
        Function[ w,
            If[ currentTokenQ[ w, token ],
                claimed = True;
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
                    "ConfigAttempts"     -> <| |>
                |>,
                w
            ]
        ]
    ];

    If[ ! claimed, releaseConnection @ conn; Throw @ Null ];

    If[ FailureQ @ sendRequest[ nbo, conn, "initialize", initializeParams[ ], "Initialize", <| |> ],
        failConnection[ nbo, conn, acpErrorInfo[ "InitFailed", None, None, <| "Agent" -> spec[ "Name" ] |> ] ]
    ];

    conn
];

acpConnect // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*openConnection*)

(* The agent's environment (which may contain the LLMKit key) is only evaluated in here, and nothing that happens in
   here can be logged: messages are quieted and any exception is discarded. *)
openConnection // beginDefinition;

openConnection[ nbo_, spec_, dir_ ] := Replace[
    Quiet @ Catch[ openConnection0[ nbo, spec, dir ], _, $Failed & ],
    Except[ _? acpConnectionQ ] -> $Failed
];

openConnection // endDefinition;


openConnection0 // beginDefinition;

openConnection0[ nbo_, spec_, dir_ ] := acpLink[ "OpenACPConnection" ][
    Lookup[ spec, "Command" ],
    ProcessDirectory              -> dir,
    ProcessEnvironment            -> Lookup[ spec, "Environment", Inherited ],
    acpLink[ "ACPClientMethods" ] -> <| "session/request_permission" -> permissionMethod @ nbo |>,
    HandlerFunctions              -> connectionHandlers @ nbo,
    HandlerFunctionsKeys          -> All,
    UpdateInterval                -> $acpReadInterval
];

openConnection0 // endDefinition;


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


(* A connection failed during setup (or its session could not be created): close it and show the error. *)
failConnection // beginDefinition;

failConnection[ nbo_NotebookObject, conn_, error_ ] := Module[ { window },
    window = acpWindowGet @ nbo;
    If[ AssociationQ @ window && Lookup[ window, "Connection", None ] === conn,
        endSentTurn[ nbo, window, <| "Error" -> error |> ];
        windowUpdate[ nbo, Function[ w, If[ Lookup[ w, "Connection", None ] === conn, connectionFailedRecord[ w, error ], w ] ] ]
    ];
    releaseConnection @ conn;
    acpLog[ "ConnectionFailed", <| "Code" -> Lookup[ Replace[ error, Except[ _Association ] -> <| |> ], "Code", None ] |> ];
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
    "MCPReady"           -> False
|>;

connectionFailedRecord // endDefinition;

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


(* Updates go to the window's current turn if it belongs to that session (and is not being finalized). *)
applyToTurn // beginDefinition;

applyToTurn[ _, window_, sid_, update_Association, time_ ] := Module[ { turnID, turn },
    turnID = Lookup[ window, "CurrentTurn", None ];
    turn   = If[ StringQ @ turnID, acpTurnGet @ turnID, None ];
    If[ AssociationQ @ turn && Lookup[ turn, "SessionID", None ] === sid && ! TrueQ @ Lookup[ turn, "FinalizeClaimed", False ],
        acpTurnUpdate[ turnID, acpApplyUpdate[ #, update, time ] & ],
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

onRequestResponse[ "Ignore", ___ ] := Null;

onRequestResponse[ kind_, ___ ] := acpLog[ "UnknownRequestKind", kind ];

onRequestResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Sessions*)
startSession // beginDefinition;

startSession[ nbo_NotebookObject, conn_ ] := Module[ { window, dir, resumeID, resumeDir, sent },
    window    = acpWindowGet @ nbo;
    dir       = Lookup[ window, "ConnectDirectory", None ];
    resumeID  = Lookup[ window, "ResumableSessionID", None ];
    resumeDir = Replace[ Lookup[ window, "ResumableDirectory", None ], Except[ _String ] -> dir ];
    sent = If[ StringQ @ resumeID && resumeDir === dir && resumeCapableQ @ window && ! TrueQ @ Lookup[ window, "NewSessionRequested", False ],
        sendRequest[
            nbo,
            conn,
            "session/resume",
            <| "sessionId" -> resumeID, "cwd" -> dir, "mcpServers" -> { } |>,
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


sendNewSession // beginDefinition;
sendNewSession[ nbo_, conn_, dir_String ] := sendRequest[ nbo, conn, "session/new", <| "cwd" -> dir, "mcpServers" -> { } |>, "SessionNew", <| |> ];
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


(* The session exists: remember it (also in the notebook, for resuming after a kernel restart) and apply config options *)
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
                    "Usage"               -> If[ how === "New", None, Lookup[ w, "Usage", None ] ],
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
            <| "ConfigID" -> step[[ 1 ]], "Value" -> step[[ 2 ]], "Origin" -> step[[ 3 ]] |>
        ];
        If[ FailureQ @ sent, continueConfiguration[ nbo, conn ] ],
        becomeReady[ nbo, conn ]
    ]
];

continueConfiguration // endDefinition;


(* { configId, value, origin } or None *)
nextConfigStep // beginDefinition;

nextConfigStep[ window_Association ] := Module[ { options, pending, attempts, prefs, settings, requested, steps },
    options   = configOptionsOf @ window;
    pending   = pendingConfigOf @ window;
    attempts  = Replace[ Lookup[ window, "ConfigAttempts", <| |> ], Except[ _Association ] -> <| |> ];
    prefs     = Replace[ Lookup[ window, "AgentPreferences", <| |> ], Except[ _Association ] -> <| |> ];
    settings  = settingsOf @ window;
    requested = Replace[ Lookup[ window, "UserModel", None ], Except[ _String ] :> Lookup[ settings, "ACPModel", None ] ];
    steps = {
        configTarget[
            acpFindConfigOption[ options, "model" ],
            pending,
            acpPreferredModel[
                options,
                <|
                    "Requested"    -> requested,
                    "LastUsed"     -> Lookup[ prefs, "LastModel", None ],
                    "FailedModels" -> failedModelsOf @ window
                |>
            ]
        ],
        configTarget[ acpFindConfigOption[ options, "thought_level" ], pending, Lookup[ prefs, "LastEffort", None ] ],
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

becomeReady[ nbo_NotebookObject, conn_ ] := windowUpdate[
    nbo,
    Function[ w,
        If[ Lookup[ w, "Connection", None ] =!= conn,
            w,
            <|
                w,
                "Status"          -> If[ runningTurnQ @ w, "Running", "Ready" ],
                "ConnectToken"    -> None,
                "ConnectAttempts" -> 0,
                "PendingConfig"   -> <| |>,
                "Error"           -> None
            |>
        ]
    ]
];

becomeReady // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Config option responses*)

(* Updates the config options from a session/set_config_option response. A value the user chose is persisted per
   agent (model and effort; not mode). A failed model is marked as failed for this session. *)
applyConfigResponse // beginDefinition;

applyConfigResponse[ nbo_NotebookObject, data_Association, resp_Association ] := Module[ { window, id, value, user, category },
    window   = acpWindowGet @ nbo;
    id       = Lookup[ data, "ConfigID", None ];
    value    = Lookup[ data, "Value", None ];
    user     = Lookup[ data, "Origin", None ] === "User";
    category = Lookup[ Replace[ SelectFirst[ configOptionsOf @ window, Lookup[ #, "id", None ] === id &, <| |> ], Except[ _Association ] -> <| |> ], "category", None ];

    If[ TrueQ @ resp[ "Error" ],
        If[ category === "model" && StringQ @ value, markModelFailed[ nbo, value ] ];
        acpLog[ "ConfigOptionFailed", <| "ConfigID" -> id, "Value" -> value, "Message" -> resp[ "Message" ] |> ];
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
        ],

        windowUpdate[
            nbo,
            Function[ w,
                <|
                    w,
                    "ConfigOptions" -> Replace[
                        Lookup[ resp[ "Result" ], "configOptions", None ],
                        {
                            o_List :> Select[ o, AssociationQ ],
                            _ :> setOptionValue[ configOptionsOf @ w, id, value ]
                        }
                    ],
                    "PendingConfig" -> dropPendingValue[ pendingConfigOf @ w, id, value ],
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
   is kept. Idempotent. *)
onAgentExited // beginDefinition;

onAgentExited[ nbo_NotebookObject, conn_, failure_ ] := Module[ { window, info, error, setupQ },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window || ! acpConnectionQ @ conn || Lookup[ window, "Connection", None ] =!= conn,
        Return[ Null, Module ]
    ];
    info  = Replace[ failure, { Failure[ _, as_Association ] :> as, _ -> <| |> } ];
    error = acpErrorInfo[
        "AgentExited",
        None,
        None,
        <|
            "Agent"             -> agentDisplayName @ window,
            "ExitCode"          -> Lookup[ info, "ExitCode", Missing[ "NotAvailable" ] ],
            "StandardErrorTail" -> Lookup[ info, "StandardErrorTail", Missing[ "NotAvailable" ] ]
        |>
    ];
    setupQ = StringQ @ Lookup[ window, "ConnectToken", None ] || ! StringQ @ Lookup[ window, "SessionID", None ];
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
                    "MCPReady"           -> False
                |>
            ]
        ]
    ];
    releaseConnection @ conn;
    acpLog[ "AgentExited", <| "ExitCode" -> Lookup[ info, "ExitCode", None ] |> ]
];

onAgentExited // endDefinition;

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
                "ProjectDirectory" -> Replace[ Lookup[ #, "ProjectDirectory", None ], None :> Lookup[ window, "ProjectDirectory", None ] ]
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
    If[ ! acpConnectionQ @ conn || ! StringQ @ sid || StringQ @ Lookup[ window, "ConnectToken", None ],
        Throw @ "Pending"
    ];
    sent = sendRequest[
        nbo,
        conn,
        "session/set_config_option",
        <| "sessionId" -> sid, "configId" -> configID, "value" -> value |>,
        "SetConfig",
        <| "ConfigID" -> configID, "Value" -> value, "Origin" -> "User" |>
    ];
    If[ FailureQ @ sent,
        windowUpdate[ nbo, Function[ w, <| w, "PendingConfig" -> dropPendingValue[ pendingConfigOf @ w, configID, value ] |> ] ];
        Throw @ sent
    ];
    "Sent"
];

acpSetConfigOption // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSetProjectDirectory*)

(* Changing the project directory (preemptive UI action) is a new chat in the new directory: disconnect, clear the
   transcript, store the directory (window record, notebook TaggingRules, persisted last directory) and reconnect.
   Refused while a turn is running (the UI disables the chooser). *)
acpSetProjectDirectory // beginDefinition;

acpSetProjectDirectory[ nbo_NotebookObject, File[ dir_String ] ] := acpSetProjectDirectory[ nbo, dir ];

acpSetProjectDirectory[ nbo_NotebookObject, dir0_ ] := Catch @ Module[ { window, dir },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window, Throw @ Missing[ "NotFound" ] ];
    dir = If[ StringQ @ dir0, Quiet @ ExpandFileName @ StringTrim @ dir0, None ];
    If[ ! validProjectDirectoryQ @ dir, Throw @ Failure[ "InvalidDirectory", <| "Directory" -> dir0 |> ] ];
    If[ dir === Lookup[ window, "ProjectDirectory", None ], Throw @ Null ];
    If[ StringQ @ Lookup[ window, "CurrentTurn", None ], Throw @ Failure[ "Running", <| |> ] ];

    acpDisconnect[ nbo, "DirectoryChanged" ];
    dropWindowTurns @ nbo;
    windowUpdate[
        nbo,
        Function[ w,
            <|
                w,
                "ProjectDirectory"   -> dir,
                "Status"             -> "Disconnected",
                "Error"              -> None,
                "Turns"              -> { },
                "QueuedPrompt"       -> None,
                "QueuedTurn"         -> None,
                "Notice"             -> None,
                "ResumableSessionID" -> None,
                "ResumableDirectory" -> None,
                "Usage"              -> None,
                "ConfigOptions"      -> { },
                "PendingConfig"      -> <| |>
            |>
        ]
    ];
    acpFESet[ nbo, "ProjectDirectory", dir ];
    acpFESet[ nbo, "ResumableSessionID", None ];
    clearWindowCells @ nbo;
    acpSetPersistedSetting[ "LastProjectDirectory", dir ];
    acpEnsureConnected @ nbo;
    dir
];

acpSetProjectDirectory // endDefinition;


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
    validQ  = validProjectDirectoryQ @ Lookup[ window, "ProjectDirectory", None ];

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
                "MCPReady"           -> False
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

(* The Reconnect action: disconnect (keeping the resumable session), clear the error and connect again. *)
acpReconnect // beginDefinition;

acpReconnect[ nbo_NotebookObject ] := Catch @ Module[ { window, validQ },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window, Throw @ Missing[ "NotFound" ] ];
    If[ connectingOrConnectedQ @ window, acpDisconnect[ nbo, "Reconnect" ] ];
    validQ = validProjectDirectoryQ @ Lookup[ window, "ProjectDirectory", None ];
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

openConnectionQ[ conn_? acpConnectionQ ] := acpLoadACPLink[ ] === True && MemberQ[
    Replace[ Quiet @ acpLink[ "ACPConnections" ][ ], Except[ _List ] -> { } ],
    conn
];

openConnectionQ[ _ ] := False;

openConnectionQ // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Housekeeping*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpConnectionHousekeeping*)

(* Every second while the publisher runs (fallbacks for lost tasks and silent agents):
     * a Stop without a prompt response for $acpStopTimeout seconds ends the turn locally;
     * setup requests without a response for $acpConnectTimeout seconds fail the connection; a user config change
       without a response for $acpConfigTimeout seconds is dropped;
     * a connection attempt whose task never ran is scheduled again (at most $acpMaxConnectAttempts times);
     * MCP servers are assumed ready $acpMCPReadyTimeout seconds after the session started;
     * a connection that ACPLink no longer has open (agent died without an event) is treated as agent death. *)
connectionHousekeeping // beginDefinition;

connectionHousekeeping[ ] := With[ { now = AbsoluteTime[ ] },
    KeyValueMap[ windowHousekeeping[ #1, #2, now ] &, $acpWindows ];
    Null
];

connectionHousekeeping // endDefinition;


windowHousekeeping // beginDefinition;

windowHousekeeping[ nbo_NotebookObject, window_Association, now_ ] := acpIsolated[
    checkStopTimeout[ nbo, window, now ];
    checkRequestTimeouts[ nbo, window, now ];
    checkStuckConnect[ nbo, window, now ];
    checkMCPReady[ nbo, window, now ];
    If[ acpConnectionQ @ Lookup[ window, "Connection", None ], checkConnectionAlive[ nbo, window[ "Connection" ] ] ]
];

windowHousekeeping[ _, _, _ ] := Null;

windowHousekeeping // endDefinition;


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

checkRequestTimeouts[ nbo_, window_, now_ ] := Module[ { requests, conn, setupLate, configLate },
    requests   = requestsOf @ window;
    conn       = Lookup[ window, "Connection", None ];
    setupLate  = Select[ requests, MatchQ[ #[ "Kind" ], $$setupRequestKind ] && now - #[ "SentAt" ] > $acpConnectTimeout & ];
    configLate = Select[ requests, #[ "Kind" ] === "SetConfig" && now - #[ "SentAt" ] > $acpConfigTimeout & ];
    If[ Length @ setupLate > 0 && acpConnectionQ @ conn,
        failConnection[ nbo, conn, acpErrorInfo[ "Timeout", None, None, <| "Agent" -> agentDisplayName @ window |> ] ]
    ];
    KeyValueMap[
        Function[ { id, info },
            dropRequest[ nbo, id ];
            windowUpdate[ nbo, Function[ w, <| w, "PendingConfig" -> dropPendingValue[ pendingConfigOf @ w, info[ "Data", "ConfigID" ], info[ "Data", "Value" ] ] |> ] ]
        ],
        configLate
    ]
];

checkRequestTimeouts // endDefinition;


checkStuckConnect // beginDefinition;

checkStuckConnect[ nbo_, window_, now_ ] := Module[ { token, scheduled, attempts },
    token     = Lookup[ window, "ConnectToken", None ];
    scheduled = Lookup[ window, "ConnectScheduledAt", None ];
    attempts  = Replace[ Lookup[ window, "ConnectAttempts", 1 ], Except[ _Integer ] -> 1 ];
    If[ StringQ @ token && ! acpConnectionQ @ Lookup[ window, "Connection", None ] && NumberQ @ scheduled && now - scheduled > $acpRescheduleAfter,
        If[ attempts >= $acpMaxConnectAttempts,
            failConnectAttempt[ nbo, token, acpErrorInfo[ "Timeout", None, None, <| "Agent" -> agentDisplayName @ window |> ] ],
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

(* The error table. Gives <| "Code", "Message", "Detail", "Actions", "Data" |> for
     * acpErrorInfo[failure] (ACPLink loading, agent lookup, agent exit), or
     * acpErrorInfo[code, message, data, context]: code is a JSON-RPC error code (with the agent's message and error
       data) or one of our codes ("ConnectFailed", "InitFailed", ...); context may give "Agent", "Model", "Default"
       (the code to use if the error is not recognized), "ExitCode", "StandardErrorTail", "Path", "InstallURL".
   "Actions" are the buttons of acpErrorView: "ChooseModel", "SignIn", "Reconnect", "LocateAgent". *)
acpErrorInfo // beginDefinition;

acpErrorInfo[ failure: Failure[ tag_String, as_Association ] ] := acpErrorInfo[
    tag,
    If[ KeyExistsQ[ as, "MessageTemplate" ], Replace[ Quiet @ failure[ "Message" ], Except[ _String ] -> None ], None ],
    None,
    KeyTake[ as, { "Agent", "ExitCode", "StandardErrorTail", "Path", "InstallURL" } ]
];

acpErrorInfo[ failure_Failure ] := acpErrorInfo[ "AgentError", Quiet @ failure[ "Message" ], None, <| |> ];

acpErrorInfo[ code_ ] := acpErrorInfo[ code, None, None, <| |> ];
acpErrorInfo[ code_, message_ ] := acpErrorInfo[ code, message, None, <| |> ];
acpErrorInfo[ code_, message_, data_ ] := acpErrorInfo[ code, message, data, <| |> ];

acpErrorInfo[ code_, message_, data_, context_Association ] := Module[ { kind, agent, model, text, detail },
    kind   = classifyError[ code, message, data, Lookup[ context, "Default", "AgentError" ] ];
    agent  = Replace[ Lookup[ context, "Agent", "OpenCode" ], Except[ _String ] -> "OpenCode" ];
    model  = Lookup[ context, "Model", None ];
    text   = errorText[ kind, agent, model, context ];
    detail = errorDetail[ kind, message, text, context ];
    <|
        "Code"    -> kind,
        "Message" -> text,
        "Detail"  -> detail,
        "Actions" -> Lookup[ $errorActions, kind, { } ],
        "Data"    -> <| "ErrorCode" -> code, "ErrorMessage" -> message, "ErrorData" -> data |>
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
    "AgentError"       -> { }
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
    "AgentError"       -> "ErrorAgent"
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

errorText[ kind_String, agent_, _, context_ ] :=
    acpConnectionLabel[ Lookup[ $errorLabels, kind, "ErrorAgent" ], <| "agent" -> Replace[ Lookup[ context, "Agent", agent ], Except[ _String ] -> agent ] |> ];

errorText // endDefinition;


(* Details shown below the friendly message: the agent's own message, exit code and end of stderr, install hints *)
errorDetail // beginDefinition;

errorDetail[ "AgentNotFound", _, _, context_ ] := Which[
    StringQ @ Lookup[ context, "Path", None ],
        acpConnectionLabel[ "ErrorAgentNotFoundPath", <| "path" -> context[ "Path" ] |> ],
    StringQ @ Lookup[ context, "InstallURL", None ],
        acpConnectionLabel[ "ErrorAgentNotFoundDetail", <| "url" -> context[ "InstallURL" ] |> ],
    True,
        None
];

errorDetail[ "AgentExited", _, _, context_ ] := Module[ { code, tail },
    code = Lookup[ context, "ExitCode", None ];
    tail = stderrTail @ Lookup[ context, "StandardErrorTail", None ];
    truncateDetail @ Replace[
        StringRiffle[
            DeleteCases[ { If[ IntegerQ @ code, acpConnectionLabel[ "ErrorAgentExitedDetail", <| "code" -> code |> ], None ], tail }, None ],
            "\n"
        ],
        "" -> None
    ]
];

errorDetail[ _, message_String, text_, _ ] /; StringLength @ StringTrim @ message > 0 && StringTrim @ message =!= text :=
    truncateDetail @ StringTrim @ message;

errorDetail[ _, _, _, _ ] := None;

errorDetail // endDefinition;


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


(* The error of an error response *)
responseError // beginDefinition;

responseError[ window_, resp_Association, default_String ] := acpErrorInfo[
    resp[ "Code" ],
    resp[ "Message" ],
    resp[ "Data" ],
    <| "Agent" -> agentDisplayName @ window, "Model" -> currentModel @ window, "Default" -> default |>
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


validProjectDirectoryQ // beginDefinition;
validProjectDirectoryQ[ dir_String ] := StringLength @ StringTrim @ dir > 0 && TrueQ @ Quiet @ DirectoryQ @ dir;
validProjectDirectoryQ[ _ ] := False;
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


agentInfoOf // beginDefinition;

agentInfoOf[ info_Association, window_ ] := <|
    "Name"    -> Replace[ Lookup[ info, "title", None ], Except[ _String ] :> Replace[ Lookup[ info, "name", None ], Except[ _String ] :> agentDisplayName @ window ] ],
    "Version" -> Replace[ Lookup[ info, "version", "" ], Except[ _String ] -> "" ]
|>;

agentInfoOf // endDefinition;


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
