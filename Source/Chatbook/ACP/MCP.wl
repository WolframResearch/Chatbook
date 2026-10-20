(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`MCP`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ACP`Common`" ];

(* The MCP server of the notebook tools (see docs/acp-window.md, "MCP server"): one Streamable HTTP MCP server per
   kernel (AgentTools' StartMCPSocketServer, on 127.0.0.1) with the LLMTools of NotebookTools.wl, which a local window
   offers to its agent in session/new, session/load and session/resume (acpMCPServersParam), with a bearer token of its
   connection.

   Rules:
   * AgentTools is optional. It is loaded on demand the first time a local window that offers the server connects
     (acpMCPEnsureServer, called by acpConnect in the pump), never when Chatbook loads, and only a version that declares
     StartMCPSocketServer is loaded. Its symbols are only referenced through agentTools["name"] once it is loaded, so
     neither this kernel nor the MX file gets them otherwise. Without such an AgentTools the sessions get no MCP servers
     ("MCPServerUnavailable", logged once).
   * A window offers the server (acpMCPEnabledQ) with "ACPMCPServer" -> True, or with Automatic when Chatbook starts the
     agent's own program, which gets OPENCODE_CONFIG_CONTENT and so its "ask" rules for the edit tools; a command line
     that runs another program (docker, env, ssh, a wrapper) may not pass that on.
   * Tokens: every connection of such a window gets a random 256-bit token (acpMCPConnectionStarted, right after acpConnect
     claimed the connection, before "initialize" is sent). A token is valid while its window's "Connection" is still that
     connection and the window still offers the server, so every way a connection ends (failConnection, onAgentExited,
     acpDisconnect, acpForgetWindow), and turning the setting off, revokes it, and housekeeping forgets revoked ones.
     Tokens are secrets: they are kept in $mcpTokens and in the parameters of the session requests only, never in the
     window record, the TaggingRules, the queue, the debug log, a Failure or a message.
   * The server's handler runs inside SocketListen, a preemptive evaluation (R2): the authentication function
     (acpMCPAuthorizedQ) is a lookup, and the evaluation function (acpMCPEnqueue) only queues the call and schedules
     acpMCPKick. Neither makes front end calls or waits.
   * In a notebook front end's kernel, tool calls run on the kernel's main link: acpMCPKick (in the pump) fires the
     Method -> "Queued" button of a hidden notebook (the technique of Developer/FrontEndServer), whose ButtonFunction,
     acpMCPDrain, runs the queued calls one after the other as a main link evaluation. Meanwhile the front end's Dynamics
     and the pump keep running, calls wait behind the user's own evaluations, and Alt+. aborts the running call
     (AgentTools' run[] answers it "aborted"). The front end merges the triggers of a button and drops its pending run
     when the evaluation ahead of it is aborted, so the button drains the whole queue, and housekeeping triggers it again
     when calls wait with no drain running.
   * Without a notebook front end (tests; also under UsingFrontEnd, whose pump tasks see $FrontEnd === Null), and when the
     button can't be used (no window's kernel is known, or it can't be fired), the pump drains the queue itself.
   * The server runs only while it is used: housekeeping stops it once no connection has had a valid token for
     $mcpIdleStopDelay seconds (the next connect starts it again), and for the rest of the kernel session once the kernel
     holds too many file descriptors (the 15.0.1 kernel leaks some for every connection SocketListen accepts, with or
     without a token). *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
(* Not "Wolfram": OpenCode registers MCP servers by name per folder and would replace the user's own Wolfram server *)
$acpMCPServerName     = "WolframNotebooks";
$mcpPath              = "/mcp";
$mcpRetriggerDelay    = 3;  (* seconds since the last trigger after which waiting calls trigger the drain again *)
$mcpHousekeepingTicks = 5;  (* publication ticks (0.2 s each) between housekeeping runs *)
$mcpIdleStopDelay     = 30; (* seconds without a valid token after which housekeeping stops the server *)
$mcpFdCheckInterval   = 5;  (* seconds between the checks of the kernel's file descriptors while the server runs *)
$mcpFdStopFraction    = 0.75; (* the share of fileDescriptorLimit[] at which the server is stopped for good *)
(* select()'s FD_SETSIZE: a kernel with more file descriptors breaks SocketListen (in a front end's kernel the listener
   stopped answering; a wolframscript kernel crashed at 1064), whatever the soft limit of open files (524288 there) *)
$mcpFdSetSize         = 1024;
$mcpPumpTag           = "ACPMCPPump"; (* the button's BoxID, its cell's tag and the pump notebook's TaggingRules key *)
$mcpAgentToolsContext = "Wolfram`AgentTools`";
$mcpServerFunction    = "Wolfram`AgentTools`StartMCPSocketServer";

$mcpEndedText  = "The ACP connection that made this call has ended.";
$mcpFailedText = "The tool call failed because of an internal error in Chatbook.";

(* The server's initialize "instructions": OpenCode gives them to the model with the server's tools *)
$mcpInstructions = "\
These tools work on the notebooks that are open in the user's Wolfram desktop app (the front end), unsaved changes \
included; they are not files. Start with ListNotebooks: the first notebook it lists is the one the user is working in \
(\"this notebook\"). Notebooks and cells are named by the short ids that ListNotebooks and ReadNotebook give. New \
content is always markdown (```wl code blocks become Input cells, which are not evaluated); no tool evaluates code. \
InsertCells, ReplaceCells and DeleteCells change notebooks the user has open, so they need the user's approval. A call \
waits while the user's own evaluation runs in the front end.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*State*)

(* Not reset if this file is reloaded during development, so that a running server, its tokens and the queued calls are
   kept. In the MX build they start out empty.
     $mcpServer          None, or <| "Object" -> the MCPSocketServerObject, "URL", "Port", "StartedAt" |>
     $mcpTokens          token -> <| "Window" -> nbo, "Connection" -> conn, "IssuedAt" -> time |>
     $mcpQueue           the queued calls, oldest first: <| "ID", "Run" -> run, "Info" -> info without its "Token",
                         "Caller" -> <| "Window", "Connection" |> of the token (or None), "QueuedAt" -> time |>
     $mcpEvaluator       None, or the Evaluator of the ACP windows (this kernel), read when a token is issued in a
                         notebook front end's kernel: the kernel of the pump button
     $mcpIdleSince       None, or the time since which the server has run without a valid token
     $mcpFdLimitReached  True once the server was stopped because the kernel held too many file descriptors *)
If[ ! MatchQ[ $mcpServer, _Association | None ], $mcpServer = None ];
If[ ! AssociationQ @ $mcpTokens, $mcpTokens = <| |> ];
If[ ! ListQ @ $mcpQueue, $mcpQueue = { } ];
If[ ! IntegerQ @ $mcpJobCount, $mcpJobCount = 0 ];
If[ ! BooleanQ @ $mcpDraining, $mcpDraining = False ];
If[ ! NumberQ @ $mcpLastKick, $mcpLastKick = 0 ];
If[ ! MatchQ[ $mcpPumpNotebook, _NotebookObject ], $mcpPumpNotebook = None ];
If[ ! MatchQ[ $mcpPumpBox, _BoxObject ], $mcpPumpBox = None ];
If[ ! BooleanQ @ $mcpUnavailableLogged, $mcpUnavailableLogged = False ];
If[ ! StringQ @ $mcpEvaluator, $mcpEvaluator = None ];
If[ ! NumberQ @ $mcpIdleSince, $mcpIdleSince = None ];
If[ ! NumberQ @ $mcpLastFdCheck, $mcpLastFdCheck = 0 ];
If[ ! BooleanQ @ $mcpFdLimitReached, $mcpFdLimitReached = False ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AgentTools*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMCPAvailableQ*)

(* Whether an AgentTools with StartMCPSocketServer is loaded (it is loaded if needed and possible). Never throws. *)
acpMCPAvailableQ // beginDefinition;
acpMCPAvailableQ[ ] := TrueQ @ loadAgentTools[ ];
acpMCPAvailableQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadAgentTools*)

(* True or a Failure ("AgentToolsMissing", "AgentToolsTooOld"). A loaded AgentTools that is too old is only replaced by
   the one of AGENTTOOLS_DIRECTORY (see loadAgentTools0), so that result is kept until that variable changes; a missing
   one is looked for again at the next connect. *)
If[ ! MatchQ[ $agentToolsLoaded, True | _Failure ], $agentToolsLoaded = None ];

loadAgentTools // beginDefinition;
loadAgentTools[ ] := If[ loadAgainQ @ $agentToolsLoaded, loadAgentTools0[ ], $agentToolsLoaded ];
loadAgentTools // endDefinition;


loadAgainQ // beginDefinition;
loadAgainQ[ None ] := True;
loadAgainQ[ Failure[ "AgentToolsTooOld", KeyValuePattern[ "Directory" -> dir_ ] ] ] := dir =!= agentToolsDirectory[ ];
loadAgainQ[ _ ] := False;
loadAgainQ // endDefinition;


(* Needs with -> None: AgentTools' context is not added to $ContextPath, so the user's session does not see its symbols.
   AgentTools may already be loaded (by the user, for its own MCP server, or by the front end at startup: the AI Settings
   preferences use it). One that is too old is never reloaded (it may be in use), unless a developer set
   AGENTTOOLS_DIRECTORY to an AgentTools with StartMCPSocketServer (reloadAgentTools). *)
loadAgentTools0 // beginDefinition;

loadAgentTools0[ ] := Catch @ Module[ { paclet },
    If[ ! agentToolsLoadedQ[ ],
        paclet = findAgentTools[ ];
        If[ paclet === None,
            Throw @ Failure[ "AgentToolsMissing", <|
                "MessageTemplate" -> "No AgentTools paclet with StartMCPSocketServer is installed."
            |> ]
        ];
        Quiet @ Needs[ $mcpAgentToolsContext -> None ]
    ];
    If[ ! socketServerFunctionQ[ ] && StringQ @ agentToolsDirectory[ ], reloadAgentTools[ ] ];
    If[ ! socketServerFunctionQ[ ],
        Throw[ $agentToolsLoaded = Failure[ "AgentToolsTooOld", <|
            "MessageTemplate" -> "The loaded AgentTools paclet has no StartMCPSocketServer.",
            "Directory"       -> agentToolsDirectory[ ]
        |> ] ]
    ];
    $agentToolsLoaded = True
];

loadAgentTools0 // endDefinition;


agentToolsLoadedQ // beginDefinition;
agentToolsLoadedQ[ ] := MemberQ[ $Packages, $mcpAgentToolsContext ];
agentToolsLoadedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*findAgentTools*)

(* The AgentTools paclet that Needs loads, if it declares StartMCPSocketServer: older versions (such as the one that comes
   with Wolfram 15.0) are never loaded. For development, the environment variable AGENTTOOLS_DIRECTORY may point to an
   AgentTools paclet directory (the one containing PacletInfo.wl), which is then loaded with PacletDirectoryLoad, like
   ACPLINK_DIRECTORY for ACPLink (State.wl). *)
findAgentTools // beginDefinition;

findAgentTools[ ] := Module[ { dir, paclet },
    dir = agentToolsDirectory[ ];
    If[ StringQ @ dir, Quiet @ PacletDirectoryLoad @ dir ];
    paclet = First[ PacletFind[ "Wolfram/AgentTools" ], None ];
    If[ declaresSocketServerQ @ paclet, paclet, None ]
];

findAgentTools // endDefinition;


(* AGENTTOOLS_DIRECTORY, if it names a paclet directory, else None *)
agentToolsDirectory // beginDefinition;

agentToolsDirectory[ ] := With[ { dir = Environment[ "AGENTTOOLS_DIRECTORY" ] },
    If[ StringQ @ dir && FileExistsQ @ FileNameJoin @ { dir, "PacletInfo.wl" }, dir, None ]
];

agentToolsDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reloadAgentTools*)

(* A developer's AGENTTOOLS_DIRECTORY replaces a loaded AgentTools that is too old, typically the installed one that a
   front end's kernel loads at startup: if the directory holds an AgentTools with StartMCPSocketServer that Needs would
   load (findAgentTools, which also PacletDirectoryLoad's it), it is loaded with Get, whose loader replaces the
   definitions of the loaded one. PreemptProtect: no preemptive evaluation (such as a Dynamic of the AI Settings, which
   use AgentTools) may run while its symbols are cleared and defined again; the Block keeps its context off
   $ContextPath, like Needs[... -> None]. *)
reloadAgentTools // beginDefinition;

reloadAgentTools[ ] := With[ { paclet = findAgentTools[ ] },
    If[ paclet =!= None,
        getAgentTools[ ];
        acpLog[ "MCPAgentToolsReloaded", <| "Version" -> Replace[ Quiet @ paclet[ "Version" ], Except[ _String ] -> None ] |> ]
    ]
];

reloadAgentTools // endDefinition;


getAgentTools // beginDefinition;
getAgentTools[ ] := PreemptProtect @ Block[ { $ContextPath = $ContextPath }, Quiet @ Get @ $mcpAgentToolsContext ];
getAgentTools // endDefinition;


(* The paclet's kernel extension lists the function in its "Symbols" (read from PacletInfo.wl: nothing is loaded) *)
declaresSocketServerQ // beginDefinition;

declaresSocketServerQ[ paclet_PacletObject ] := MemberQ[
    Flatten @ Cases[
        Replace[ Quiet @ paclet[ "Extensions" ], Except[ _List ] -> { } ],
        { "Kernel", opts___ } :> Lookup[ Cases[ { opts }, _Rule | _RuleDelayed ], "Symbols", { } ]
    ],
    $mcpServerFunction
];

declaresSocketServerQ[ _ ] := False;

declaresSocketServerQ // endDefinition;


(* Names does not create the symbol, and an AgentTools without the function has no such symbol *)
socketServerFunctionQ // beginDefinition;

socketServerFunctionQ[ ] := Names[ $mcpServerFunction ] =!= { } &&
    MemberQ[ Quiet @ Keys @ Options @ agentTools[ "StartMCPSocketServer" ], "EvaluationFunction" ];

socketServerFunctionQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*agentTools*)

(* agentTools["StartMCPSocketServer"] gives Wolfram`AgentTools`StartMCPSocketServer. Only after loadAgentTools[] gave
   True: Symbol would create the symbol otherwise. *)
agentTools // beginDefinition;
agentTools[ name_String ] := Symbol[ $mcpAgentToolsContext <> name ];
agentTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Server*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMCPEnsureServer*)

(* Called by acpConnect (in the pump) for a local window that offers the server: starts the kernel's server unless it
   runs, loading AgentTools the first time (about 3.5 s from a source checkout). Gives the server record or a Failure;
   never throws. A server that no longer runs (e.g. deleted by hand) is replaced; connections that offered the old one
   keep its URL, which no longer answers. Once the kernel held too many file descriptors (fdLimitReachedQ, also checked
   here), no server is started for the rest of the kernel session. *)
acpMCPEnsureServer // beginDefinition;

acpMCPEnsureServer[ ] := acpCatchAll[
    ensureServer[ ],
    (
        acpLog[ "MCPServerFailed", <| "Code" -> "Internal" |> ];
        Failure[ "MCPServerFailed", <| "MessageTemplate" -> "The MCP server of the notebook tools could not be started." |> ]
    ) &
];

acpMCPEnsureServer // endDefinition;


ensureServer // beginDefinition;

ensureServer[ ] := Catch @ Module[ { load, object },
    (* a connect is about to give a connection its token: housekeeping's idle stop starts counting again *)
    If[ serverRunningQ[ ], $mcpIdleSince = None; Throw @ $mcpServer ];
    If[ TrueQ @ $mcpFdLimitReached || fdLimitReachedQ[ ],
        Throw @ Failure[ "MCPServerFdLimit", <|
            "MessageTemplate" -> "The MCP server of the notebook tools is off: the kernel has too many open files."
        |> ]
    ];
    load = loadAgentTools[ ];
    If[ FailureQ @ load, noteUnavailable @ load; Throw @ load ];
    acpMCPStopServer[ ];
    object = startServer[ ];
    If[ ! serverObjectQ @ object,
        acpLog[ "MCPServerFailed", <| "Code" -> failureCode @ object |> ];
        Throw @ Failure[ "MCPServerFailed", <|
            "MessageTemplate" -> "The MCP server of the notebook tools could not be started."
        |> ]
    ];
    $mcpServer = <| "Object" -> object, "URL" -> object[ "URL" ], "Port" -> object[ "Port" ], "StartedAt" -> AbsoluteTime[ ] |>;
    $mcpLastFdCheck = AbsoluteTime[ ];
    acpLog[ "MCPServerStarted", <| "Port" -> $mcpServer[ "Port" ] |> ];
    $mcpServer
];

ensureServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*startServer*)

(* An in-memory MCPServerObject with the notebook tools (the LLMTools themselves) and the instructions, on 127.0.0.1 and
   a free port. The handler authenticates with acpMCPAuthorizedQ and queues tool calls with acpMCPEnqueue. Messages are
   quieted and throws caught: a failure is logged ("MCPServerFailed") and the window connects without MCP servers. *)
startServer // beginDefinition;

startServer[ ] := Quiet @ acpCatchAll @ agentTools[ "StartMCPSocketServer" ][
    agentTools[ "MCPServerObject" ][ <|
        "Name"          -> $acpMCPServerName,
        "Location"      -> None,
        "ServerVersion" -> chatbookVersion[ ],
        "LLMEvaluator"  -> <| "Tools" -> acpNotebookTools[ ], "Prompts" -> $mcpInstructions |>
    |> ],
    "Authentication"     -> acpMCPAuthorizedQ,
    "EvaluationFunction" -> acpMCPEnqueue,
    "Path"               -> $mcpPath
];

startServer // endDefinition;


chatbookVersion // beginDefinition;
chatbookVersion[ ] := Replace[ Quiet @ $thisPaclet[ "Version" ], Except[ _String ] -> "0" ];
chatbookVersion // endDefinition;


serverObjectQ // beginDefinition;

serverObjectQ[ object: h_Symbol[ _Association ] ] :=
    SymbolName @ h === "MCPSocketServerObject" && StringQ @ Quiet @ object[ "URL" ] && IntegerQ @ Quiet @ object[ "Port" ];

serverObjectQ[ _ ] := False;

serverObjectQ // endDefinition;


serverRunningQ // beginDefinition;
serverRunningQ[ ] := AssociationQ @ $mcpServer && TrueQ @ Quiet @ $mcpServer[ "Object" ][ "Running" ];
serverRunningQ // endDefinition;


(* The tag of a failure, for the debug log (AgentTools' failures name no tokens: the server authenticates with a
   function) *)
failureCode // beginDefinition;
failureCode[ Failure[ tag_, ___ ] ] := tag;
failureCode[ other_ ] := ToString[ Head @ other, InputForm ];
failureCode // endDefinition;


noteUnavailable // beginDefinition;

noteUnavailable[ failure_ ] := If[ ! TrueQ @ $mcpUnavailableLogged,
    $mcpUnavailableLogged = True;
    acpLog[ "MCPServerUnavailable", <| "Code" -> failureCode @ failure |> ]
];

noteUnavailable // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMCPStopServer*)

(* Stops the kernel's server (housekeeping, when it is idle or the kernel holds too many file descriptors; tests,
   debugging); the next connect of a window starts a new one. AgentTools answers the calls it still has with an error,
   and the queued ones are dropped. Never from the server's handler: DeleteObject closes the listener. *)
acpMCPStopServer // beginDefinition;

acpMCPStopServer[ ] := Module[ { server },
    server = PreemptProtect @ With[ { s = $mcpServer }, $mcpServer = None; $mcpIdleSince = None; s ];
    If[ AssociationQ @ server,
        Quiet @ DeleteObject @ server[ "Object" ];
        PreemptProtect[ $mcpQueue = { } ]
    ];
    Null
];

acpMCPStopServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMCPServer*)

(* The kernel's MCPSocketServerObject (for debugging: its "Port", "URL", "Running", "PendingRequests"), or None *)
acpMCPServer // beginDefinition;
acpMCPServer[ ] := If[ AssociationQ @ $mcpServer, $mcpServer[ "Object" ], None ];
acpMCPServer // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Settings*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMCPEnabledQ*)

(* Whether the window settings offer the server to the agent (the registry's name): "ACPMCPServer" -> True does, False
   doesn't, and Automatic does when Chatbook starts the agent's own program (acpOwnAgentCommandQ). The edit tools ask
   only because of the "ask" rules in OPENCODE_CONFIG_CONTENT, which reaches the agent's own program, but not
   necessarily an agent that a command line such as docker, env or ssh starts. Pure (the handler uses it). *)
acpMCPEnabledQ // beginDefinition;

acpMCPEnabledQ[ agent_, settings_Association ] := Replace[
    Lookup[ settings, "ACPMCPServer", Automatic ],
    { True -> True, False -> False, _ :> acpOwnAgentCommandQ[ agent, settings ] }
];

acpMCPEnabledQ[ agent_, _ ] := acpMCPEnabledQ[ agent, <| |> ];

acpMCPEnabledQ // endDefinition;


(* A window that offers the server to its agent: a local one (a remote agent can't reach this computer's 127.0.0.1)
   whose settings offer it *)
mcpWindowQ // beginDefinition;

mcpWindowQ[ window_Association ] :=
    ! acpRemoteQ @ window && acpMCPEnabledQ[ Lookup[ window, "Agent", "OpenCode" ], Lookup[ window, "Settings", <| |> ] ];

mcpWindowQ[ _ ] := False;

mcpWindowQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tokens*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMCPConnectionStarted*)

(* acpConnect claimed the connection conn for the window. If the window offers the server and the server runs, the
   connection gets its token now, before "initialize" is sent (whose response starts the session). Gives the token or
   None, and never throws: without a token the sessions get no MCP servers. *)
acpMCPConnectionStarted // beginDefinition;

acpMCPConnectionStarted[ nbo_NotebookObject, conn_ ] :=
    If[ AssociationQ @ $mcpServer && mcpWindowQ @ acpWindowGet @ nbo,
        acpCatchAll[ issueToken[ nbo, conn ], (acpLog[ "MCPServerFailed", <| "Code" -> "Token" |> ]; None) & ],
        None
    ];

acpMCPConnectionStarted // endDefinition;


issueToken // beginDefinition;

issueToken[ nbo_NotebookObject, conn_ ] := With[ { token = newToken[ ] },
    PreemptProtect[ $mcpTokens[ token ] = <| "Window" -> nbo, "Connection" -> conn, "IssuedAt" -> AbsoluteTime[ ] |> ];
    noteEvaluator @ nbo;
    token
];

issueToken // endDefinition;


(* The pump button must be evaluated by this kernel, the one of the ACP windows (every window uses the kernel that
   holds its state: acpCurrentEvaluator in UI.wl). In a notebook front end's kernel (acpConnect runs in the pump, where
   front end calls are fine), the first window that gets a token tells its name: the kernel's name is never guessed. *)
noteEvaluator // beginDefinition;

noteEvaluator[ nbo_NotebookObject ] := If[ ! StringQ @ $mcpEvaluator && notebookFrontEndQ[ ],
    With[ { evaluator = windowEvaluator @ nbo }, If[ StringQ @ evaluator, $mcpEvaluator = evaluator ] ]
];

noteEvaluator // endDefinition;


windowEvaluator // beginDefinition;
windowEvaluator[ nbo_NotebookObject ] := Quiet @ AbsoluteCurrentValue[ nbo, Evaluator ];
windowEvaluator // endDefinition;


(* 256 bits from a cryptographic random source (the key of a new AES-256 key) as 64 hexadecimal digits, like the tokens
   of AgentTools' StartMCPSocketServer *)
newToken // beginDefinition;

newToken[ ] := Enclose[
    Module[ { bytes },
        bytes = ConfirmBy[ GenerateSymmetricKey[ ][ "Key" ], ByteArrayQ, "Key" ];
        ConfirmAssert[ Length @ bytes === 32, "KeyLength" ];
        StringJoin @ IntegerString[ Normal @ bytes, 16, 2 ]
    ],
    throwInternalFailure
];

newToken // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMCPAuthorizedQ*)

(* The server's "Authentication" function, called in the SocketListen handler with the request's bearer token (or
   None): True only for the token of a connection that is still its window's connection, in a window that still offers
   the server. A pure lookup. *)
acpMCPAuthorizedQ // beginDefinition;
acpMCPAuthorizedQ[ token_String ] := tokenValidQ @ Lookup[ $mcpTokens, token, None ];
acpMCPAuthorizedQ[ _ ] := False;
acpMCPAuthorizedQ // endDefinition;


(* A token's entry (or a queued call's "Caller") is valid while its window's "Connection" is that connection and the
   window offers the server: turning "ACPMCPServer" off (or a command line that does not run the agent's own program)
   revokes it at once, although the window only reconnects after a running turn *)
tokenValidQ // beginDefinition;

tokenValidQ[ KeyValuePattern @ { "Window" -> nbo_NotebookObject, "Connection" -> conn_ } ] :=
    conn =!= None && With[ { window = acpWindowGet @ nbo },
        AssociationQ @ window && Lookup[ window, "Connection", None ] === conn && mcpWindowQ @ window
    ];

tokenValidQ[ _ ] := False;

tokenValidQ // endDefinition;


(* The token of the window's connection, or None *)
windowToken // beginDefinition;

windowToken[ window_Association ] := With[
    { nbo = Lookup[ window, "Notebook", None ], conn = Lookup[ window, "Connection", None ] },
    If[ conn === None,
        None,
        First[ Keys @ Select[ $mcpTokens, MatchQ[ KeyValuePattern @ { "Window" -> nbo, "Connection" -> conn } ] ], None ]
    ]
];

windowToken // endDefinition;


pruneTokens // beginDefinition;
pruneTokens[ ] := PreemptProtect[ $mcpTokens = Select[ $mcpTokens, tokenValidQ ] ];
pruneTokens // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Session Parameters*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMCPServersParam*)

(* The "mcpServers" parameter of session/new, session/load and session/resume (the same entry for all three). Pure, so
   it can be used in reader handlers: { } for a remote window, with the setting off, without a server or a token for the
   window's connection, or when the agent does not support HTTP MCP servers (agentCapabilities.mcpCapabilities.http is
   true or an object). *)
acpMCPServersParam // beginDefinition;

acpMCPServersParam[ nbo_NotebookObject ] := acpMCPServersParam @ acpWindowGet @ nbo;

acpMCPServersParam[ window_Association ] := Module[ { token },
    If[ ! AssociationQ @ $mcpServer || ! mcpWindowQ @ window || ! httpCapableQ @ window, Return[ { }, Module ] ];
    token = windowToken @ window;
    If[ ! StringQ @ token, Return[ { }, Module ] ];
    {
        <|
            "type"    -> "http",
            "name"    -> $acpMCPServerName,
            "url"     -> $mcpServer[ "URL" ],
            "headers" -> { <| "name" -> "Authorization", "value" -> "Bearer " <> token |> }
        |>
    }
];

acpMCPServersParam[ _ ] := { };

acpMCPServersParam // endDefinition;


httpCapableQ // beginDefinition;

httpCapableQ[ window_Association ] := MatchQ[
    Lookup[ window, "Capabilities", None ],
    KeyValuePattern[ "mcpCapabilities" -> KeyValuePattern[ "http" -> True | _Association ] ]
];

httpCapableQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Queue*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMCPEnqueue*)

(* The server's "EvaluationFunction". AgentTools calls it with a deferred tools/call (or prompts/get) as run and info:
   in the SocketListen handler, or, for a request pipelined behind an earlier one, in the evaluation that answered the
   earlier one (e.g. a drain). It only queues the call and schedules acpMCPKick: no front end calls, no waiting. *)
acpMCPEnqueue // beginDefinition;

acpMCPEnqueue[ run_, info_Association ] := (
    PreemptProtect @ AppendTo[ $mcpQueue, queueEntry[ run, info ] ];
    acpSchedule @ acpMCPKick[ ];
    Null
);

acpMCPEnqueue // endDefinition;


(* The queue never holds the bearer token: the evaluation stack of a drain would show it, and so would the "Stack" of
   an internal failure that the debug log records. The call keeps the window and connection of its token ("Caller"),
   which the drain checks with tokenValidQ. *)
queueEntry // beginDefinition;

queueEntry[ run_, info_Association ] := <|
    "ID"       -> ++$mcpJobCount,
    "Run"      -> run,
    "Info"     -> KeyDrop[ info, "Token" ],
    "Caller"   -> tokenCaller @ Lookup[ info, "Token", None ],
    "QueuedAt" -> AbsoluteTime[ ]
|>;

queueEntry // endDefinition;


tokenCaller // beginDefinition;

tokenCaller[ token_String ] := Replace[
    Lookup[ $mcpTokens, token, None ],
    entry_Association :> KeyTake[ entry, { "Window", "Connection" } ]
];

tokenCaller[ _ ] := None;

tokenCaller // endDefinition;


(* Whether the pump must keep running for the MCP server (State.wl's publisherNeededQ): calls wait in the queue (the
   watchdog may have to trigger the drain again), or the server runs (housekeeping stops it when it is no longer used,
   and watches the kernel's file descriptors meanwhile) *)
acpMCPPendingQ // beginDefinition;
acpMCPPendingQ[ ] := $mcpQueue =!= { } || AssociationQ @ $mcpServer;
acpMCPPendingQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMCPKick*)

(* Runs in the pump (scheduled by acpMCPEnqueue; also housekeeping's retrigger). In a notebook front end's kernel it
   fires the pump button, whose queued evaluation drains the queue on the main link; without one it drains the queue
   right here. A running drain takes new calls itself. *)
acpMCPKick // beginDefinition;

acpMCPKick[ ] := Which[
    $mcpQueue === { } || TrueQ @ $mcpDraining,
        Null,
    notebookFrontEndQ[ ],
        $mcpLastKick = AbsoluteTime[ ];
        triggerDrain[ ],
    True,
        $mcpLastKick = AbsoluteTime[ ];
        drainQueue[ "Pump" ]
];

acpMCPKick // endDefinition;


(* The kernel of a notebook front end. Under UsingFrontEnd (tests, CI) the main evaluation has $Notebooks and a
   FrontEndObject too, but no parent link: firing a queued button in that front end could make it start a kernel. *)
notebookFrontEndQ // beginDefinition;
notebookFrontEndQ[ ] := TrueQ @ $Notebooks && MatchQ[ $FrontEnd, _FrontEndObject ] && MatchQ[ $ParentLink, _LinkObject ];
notebookFrontEndQ // endDefinition;


(* Fires the pump button. If that fails (no pump yet, or its notebook is gone, e.g. after a kernel restart), the pump
   notebook is made again, for the kernel that the ACP windows named ($mcpEvaluator, see noteEvaluator), and its button
   fired once more. If no window has named the kernel (a button for a guessed kernel could send every later drain to
   another kernel), or the button can't be fired, the queue is drained here, in the pump: the front end's Dynamics stop
   while the calls run, but the agent gets its answers. *)
triggerDrain // beginDefinition;

triggerDrain[ ] := Which[
    fireTrigger @ $mcpPumpBox,
        Null,
    ! StringQ @ $mcpEvaluator,
        acpLog[ "MCPPumpFailed", <| "Code" -> "NoEvaluator" |> ];
        drainQueue[ "Pump" ],
    ! fireTrigger @ createPump @ $mcpEvaluator,
        acpLog[ "MCPPumpFailed", <| "Code" -> "Trigger" |> ];
        drainQueue[ "Pump" ]
];

triggerDrain // endDefinition;


fireTrigger // beginDefinition;
fireTrigger[ box_BoxObject ] := TrueQ @ Quiet @ MathLink`CallFrontEnd @ FrontEnd`TriggerControlBoxObject @ box;
fireTrigger[ _ ] := False;
fireTrigger // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Pump Notebook*)

(* Makes the hidden notebook with the queued button and gives the button's BoxObject, or None. The pump notebooks of the
   same kernel are closed first: one that a kernel restart left behind, or an earlier one of this kernel session; those
   of other kernels are left alone. *)
createPump // beginDefinition;

createPump[ evaluator_String ] := Enclose[
    Module[ { closed, nbo, box },
        closed = closePumpNotebooks @ evaluator;
        nbo    = ConfirmMatch[ Quiet @ NotebookPut @ pumpNotebook @ evaluator, _NotebookObject, "Notebook" ];
        box    = ConfirmMatch[
            Quiet @ MathLink`CallFrontEnd @ FrontEnd`BoxReferenceBoxObject[
                FE`BoxReference[ nbo, { { $mcpPumpTag } } ],
                FE`SearchStart -> "StartFromBeginning",
                FE`SearchStop  -> "StopAtEnd"
            ],
            _BoxObject,
            "BoxObject"
        ];
        $mcpPumpNotebook = nbo;
        $mcpPumpBox      = box;
        acpLog[ "MCPPumpCreated", <| "Closed" -> closed |> ];
        box
    ],
    None &
];

createPump // endDefinition;


(* Invisible, never saved, excluded from AI (the notebook tools skip invisible notebooks anyway), and evaluated by the
   kernel of the ACP windows: the front end's default kernel may be another one. The ButtonFunction names the drain by
   its full name, which the MX build has too. *)
pumpNotebook // beginDefinition;

pumpNotebook[ evaluator_String ] := Notebook[
    {
        Cell[
            BoxData @ ButtonBox[
                "\"ACP MCP\"",
                ButtonFunction :> Wolfram`Chatbook`ACP`Common`acpMCPDrain[ ],
                Evaluator      -> evaluator,
                Method         -> "Queued",
                BoxID          -> $mcpPumpTag
            ],
            "Text",
            CellTags -> $mcpPumpTag
        ]
    },
    Visible      -> False,
    Saveable     -> False,
    Evaluator    -> evaluator,
    WindowTitle  -> "ACP MCP Pump",
    TaggingRules -> <|
        $mcpPumpTag            -> <| "KernelSessionID" -> $SessionID |>,
        "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |>
    |>
];

pumpNotebook // endDefinition;


(* Closes the pump notebooks of the kernel that the evaluator names and gives their number *)
closePumpNotebooks // beginDefinition;

closePumpNotebooks[ evaluator_String ] := Module[ { pumps },
    pumps = Select[ Replace[ Quiet @ Notebooks[ ], Except[ _List ] -> { } ], pumpNotebookQ[ #, evaluator ] & ];
    Scan[ Quiet @ NotebookClose @ # &, pumps ];
    $mcpPumpNotebook = None;
    $mcpPumpBox      = None;
    Length @ pumps
];

closePumpNotebooks // endDefinition;


pumpNotebookQ // beginDefinition;

pumpNotebookQ[ nbo_NotebookObject, evaluator_String ] := And[
    IntegerQ @ Quiet @ CurrentValue[ nbo, { TaggingRules, $mcpPumpTag, "KernelSessionID" } ],
    Quiet @ AbsoluteCurrentValue[ nbo, Evaluator ] === evaluator
];

pumpNotebookQ // endDefinition;


(* Print, Echo and message cells of the queued evaluations land in the pump notebook (their evaluation notebook): after
   each drain, every cell but the button's is deleted *)
cleanPumpNotebook // beginDefinition;

cleanPumpNotebook[ ] := If[ MatchQ[ $mcpPumpNotebook, _NotebookObject ],
    Quiet @ With[ { cells = Cells @ $mcpPumpNotebook },
        If[ MatchQ[ cells, { _, __ } ],
            NotebookDelete @ Complement[ cells, Cells[ $mcpPumpNotebook, CellTags -> $mcpPumpTag ] ]
        ]
    ]
];

cleanPumpNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMCPDrain*)

(* The ButtonFunction of the pump button: drains the queue as a main link evaluation. Isolated like every ACP entry point
   (nothing escapes, messages go to the debug log, chat globals are blocked), but without AbortProtect: Alt+. aborts the
   running call (AgentTools' run[] answers it "aborted"), and an abort between two calls ends the drain (housekeeping
   triggers it again for the calls that are left). *)
acpMCPDrain // beginDefinition;
acpMCPDrain[ ] := acpIsolatedAbortable @ drainQueue[ "MainLink" ];
acpMCPDrain // endDefinition;


(* Runs the queued calls in order until the queue is empty. One drain runs at a time; calls queued meanwhile are taken
   by the running one. A call leaves the queue only once it has been dealt with, so a call whose drain was aborted
   before it started stays queued (and run[] does nothing for a call that was answered already). mode: "MainLink" (the
   pump button) or "Pump". *)
drainQueue // beginDefinition;

drainQueue[ mode_String ] := Module[ { job, claimed = False },
    (* The claim is made in WithCleanup's first argument, which an abort (Alt+.) can't interrupt, and only a claim
       that was made is released: an abort right after the claim would otherwise leave the drain claimed for good *)
    WithCleanup[
        claimed = claimDrain[ ],
        If[ claimed, While[ AssociationQ[ job = First[ $mcpQueue, None ] ], runQueuedJob[ job, mode ] ] ],
        If[ claimed, $mcpDraining = False ]
    ];
    If[ ! claimed, Return[ Null, Module ] ];
    If[ mode === "MainLink", cleanPumpNotebook[ ] ];
    (* a call may have been queued after the loop's last check, while the drain still counted as running: *)
    If[ $mcpQueue =!= { }, drainQueue @ mode ]
];

drainQueue // endDefinition;


claimDrain // beginDefinition;
claimDrain[ ] := PreemptProtect @ If[ TrueQ @ $mcpDraining, False, $mcpDraining = True ];
claimDrain // endDefinition;


(* An internal error must not leave the agent waiting: the call is then answered with an error (Reject does nothing for
   a call that was answered already) *)
runQueuedJob // beginDefinition;

runQueuedJob[ job_Association, mode_String ] := (
    If[ FailureQ @ acpIsolatedAbortable @ runJob[ job, mode ],
        acpCatchAll @ Quiet @ job[ "Info" ][ "Reject" ][ $mcpFailedText ]
    ];
    PreemptProtect[ $mcpQueue = DeleteCases[ $mcpQueue, KeyValuePattern[ "ID" -> job[ "ID" ] ] ] ];
    Null
);

runQueuedJob // endDefinition;


(* A call is skipped if it is no longer active (answered, cancelled, its client gone, its server stopped), rejected if
   the connection that made it has ended or no longer offers the server (tokenValidQ of its "Caller"), and run
   otherwise. run[] gives a Failure for an internal error in AgentTools while it claimed or answered the call, which it
   then answers itself; a call that is still active after that is answered here, so the agent never waits for nothing.
   The log names the tool, never its arguments. *)
runJob // beginDefinition;

runJob[ job_Association, mode_String ] := Module[ { info, name, start, response },
    info = job[ "Info" ];
    name = Lookup[ info, "Name", None ];
    Which[
        ! TrueQ @ Quiet @ info[ "ActiveQ" ][ ],
            acpLog[ "MCPToolSkipped", <| "Tool" -> name |> ],
        ! tokenValidQ @ Lookup[ job, "Caller", None ],
            info[ "Reject" ][ $mcpEndedText ];
            acpLog[ "MCPToolRejected", <| "Tool" -> name |> ],
        True,
            start    = AbsoluteTime[ ];
            response = job[ "Run" ][ ];
            If[ FailureQ @ response && TrueQ @ Quiet @ info[ "ActiveQ" ][ ], info[ "Reject" ][ $mcpFailedText ] ];
            acpLog[ "MCPToolCall", <|
                "Tool"    -> name,
                "Mode"    -> mode,
                "Status"  -> responseStatus @ response,
                "Waited"  -> Round[ start - job[ "QueuedAt" ], 0.001 ],
                "Seconds" -> Round[ AbsoluteTime[ ] - start, 0.001 ]
            |> ]
    ];
    Null
];

runJob // endDefinition;


responseStatus // beginDefinition;
responseStatus[ KeyValuePattern[ "result" -> KeyValuePattern[ "isError" -> True ] ] ] := "Error";
responseStatus[ KeyValuePattern[ "error" -> _ ] ] := "Error";
responseStatus[ _Association ] := "OK";
responseStatus[ _Failure ] := "Error"; (* an internal error in AgentTools: the call was answered with an error *)
responseStatus[ _ ] := "NotRun"; (* run[] does nothing for a call that was answered or cancelled meanwhile *)
responseStatus // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*OpenCode Permissions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMCPToolPermissions*)

(* "ask" rules for the tools that change notebooks the user has open ($acpNotebookEditTools), for Chatbook's inline
   OpenCode config (Agents.wl). OpenCode checks the permission <server>_<tool> before it calls an MCP tool, with the
   characters outside [a-zA-Z0-9_-] replaced by "_", e.g. "WolframNotebooks_InsertCells"; for MCP tools its default is
   "allow". *)
acpMCPToolPermissions // beginDefinition;

acpMCPToolPermissions[ ] := AssociationMap[
    "ask" &,
    openCodeActionName[ $acpMCPServerName, # ] & /@ $acpNotebookEditTools
];

acpMCPToolPermissions // endDefinition;


openCodeActionName // beginDefinition;
openCodeActionName[ server_String, tool_String ] := openCodeName @ server <> "_" <> openCodeName @ tool;
openCodeActionName // endDefinition;

openCodeName // beginDefinition;
openCodeName[ name_String ] := StringReplace[ name, RegularExpression[ "[^a-zA-Z0-9_-]" ] -> "_" ];
openCodeName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Housekeeping*)

(* Every second while the pump runs (it runs while the server does, acpMCPPendingQ): forgets revoked tokens, looks after
   the server (serverHousekeeping), and triggers the drain again for calls that have waited more than
   $mcpRetriggerDelay seconds since the last trigger with no drain running (a drain dropped by the front end, or one
   that an abort ended). Never in the server's handler. *)
mcpHousekeeping // beginDefinition;

mcpHousekeeping[ ] := (
    If[ $mcpTokens =!= <| |>, pruneTokens[ ] ];
    If[ AssociationQ @ $mcpServer, serverHousekeeping @ AbsoluteTime[ ] ];
    If[ $mcpQueue =!= { } && ! TrueQ @ $mcpDraining && AbsoluteTime[ ] - $mcpLastKick > $mcpRetriggerDelay,
        acpMCPKick[ ]
    ];
    Null
);

mcpHousekeeping // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*serverHousekeeping*)

(* The server listens only while it is used: SocketListen accepts every connection before AgentTools can check its
   token, and the 15.0.1 kernel leaks file descriptors for each one (about 4 for a connection that the client closes),
   which are never given back. So the server is stopped (and started again by the next connect) once no connection has
   had a valid token for $mcpIdleStopDelay seconds; a start and a stop leak nothing (measured: 0 of 20 cycles). Every
   $mcpFdCheckInterval seconds the kernel's file descriptors are counted, and too many stop the server for the rest of
   the kernel session (fdLimitReachedQ). *)
serverHousekeeping // beginDefinition;

serverHousekeeping[ now_? NumberQ ] := Which[
    fdCheckDueQ @ now && fdLimitReachedQ[ ],
        acpMCPStopServer[ ],
    $mcpTokens =!= <| |>, (* the tokens that are left are valid (pruneTokens) *)
        $mcpIdleSince = None,
    ! NumberQ @ $mcpIdleSince,
        $mcpIdleSince = now,
    now - $mcpIdleSince >= $mcpIdleStopDelay,
        acpLog[ "MCPServerStopped", <| "Reason" -> "Idle" |> ];
        acpMCPStopServer[ ]
];

serverHousekeeping // endDefinition;


(* Whether the file descriptors are due to be counted (and notes the time) *)
fdCheckDueQ // beginDefinition;

fdCheckDueQ[ now_ ] := If[ now - $mcpLastFdCheck >= $mcpFdCheckInterval, $mcpLastFdCheck = now; True, False ];

fdCheckDueQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*fdLimitReachedQ*)

(* Whether the kernel holds too many file descriptors for the server: more than $mcpFdStopFraction of
   fileDescriptorLimit[]. Leaked descriptors are never given back, so the first time this is True it is logged
   ("MCPServerFdLimit") and the server stays off for the kernel session ($mcpFdLimitReached). Unknown (always False)
   where /proc/self/fd does not exist, e.g. on macOS and Windows. *)
fdLimitReachedQ // beginDefinition;

fdLimitReachedQ[ ] := Module[ { count, limit },
    count = kernelFileDescriptors[ ];
    If[ ! IntegerQ @ count, Return[ False, Module ] ];
    limit = fileDescriptorLimit[ ];
    If[ count <= $mcpFdStopFraction * limit, Return[ False, Module ] ];
    $mcpFdLimitReached = True;
    acpLog[ "MCPServerFdLimit", <| "FileDescriptors" -> count, "Limit" -> limit |> ];
    True
];

fdLimitReachedQ // endDefinition;


(* The number of the kernel's open file descriptors (Linux), or None *)
kernelFileDescriptors // beginDefinition;

kernelFileDescriptors[ ] := If[ $OperatingSystem === "Unix" && DirectoryQ[ "/proc/self/fd" ],
    Length @ FileNames[ "*", "/proc/self/fd" ],
    None
];

kernelFileDescriptors // endDefinition;


(* The kernel's soft limit of open files (/proc/self/limits), but at most select()'s FD_SETSIZE ($mcpFdSetSize) *)
fileDescriptorLimit // beginDefinition;

fileDescriptorLimit[ ] := With[ { soft = softFileLimit[ ] },
    If[ IntegerQ @ soft && soft > 0, Min[ soft, $mcpFdSetSize ], $mcpFdSetSize ]
];

fileDescriptorLimit // endDefinition;


softFileLimit // beginDefinition;

softFileLimit[ ] := With[ { limits = Quiet @ ReadString[ "/proc/self/limits" ] },
    If[ StringQ @ limits,
        First[ StringCases[ limits, "Max open files" ~~ Whitespace ~~ n: DigitCharacter.. :> FromDigits @ n, 1 ], None ],
        None
    ]
];

softFileLimit // endDefinition;

acpRegisterHousekeeping[ "ACPMCP", mcpHousekeeping, $mcpHousekeepingTicks ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
