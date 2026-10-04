(* ::Package:: *)

(* ::Title:: *)
(*Front End Server*)


(* ::Text:: *)
(*A small command server that runs in a kernel attached to a Wolfram front end (WolframNB), so that external tools*)
(*(e.g. an AI coding agent using Developer/FrontEndServer/fe.py) can drive the real notebook UI.*)
(**)
(*Protocol: newline-delimited JSON over TCP on 127.0.0.1.*)
(*  request:  {"id": 1, "token": "...", "command": "evaluate", "args": {...}}*)
(*  response: {"id": 1, "ok": true, "result": ...}  or  {"id": 1, "ok": false, "error": "...", ...}*)


(* ::Section::Closed:: *)
(*Package Header*)


BeginPackage[ "Wolfram`ChatbookFrontEndServer`" ];

StartFrontEndServer;
StopFrontEndServer;
FrontEndServerInformation;
FrontEndServerNotebook;
FrontEndServerCell;
$FrontEndServer;
$FrontEndServerRegistryDirectory;

Begin[ "`Private`" ];

(* Reloading this file into a kernel with a running server must replace every definition, but keep the server's state.
   The socket handler is never cleared: while definitions are being replaced it just collects incoming events, which
   are processed at the end of this file. *)
$reloading = True;
If[ ! ListQ @ $pendingEvents, $pendingEvents = { } ];
handleEvent[ event_ ] := If[ TrueQ @ $reloading, AppendTo[ $pendingEvents, event ], CheckAll[ handleEvent0 @ event, Null & ] ];

ClearAll[ StartFrontEndServer, StopFrontEndServer, FrontEndServerInformation, FrontEndServerNotebook, FrontEndServerCell ];
With[ { keep = { "handleEvent", "$reloading", "$pendingEvents", "$queue", "$pumping", "$pumpTriggered", "$pumpBox", "$pumpNotebook", "$pumpEvaluator", "$serverToken", "$readyLinks", "$buffers", "$doneCells", "$autoStarted" } },
    Scan[
        (* Names of the form x$123 are Module variables, possibly of the evaluation that is doing this reload: *)
        If[ ! MemberQ[ keep, Last @ StringSplit[ #, "`" ] ] && ! StringMatchQ[ #, __ ~~ "$" ~~ DigitCharacter.. ], ClearAll @ # ] &,
        Names[ "Wolfram`ChatbookFrontEndServer`Private`*" ]
    ]
];


(* ::Section::Closed:: *)
(*Config*)


$inputFileName = Replace[ $InputFileName, "" :> NotebookFileName[ ] ];
$packageDirectory = DirectoryName @ $inputFileName;

$defaultPortRange = { 2400, 2499 };
$maxResultCharacters = 20000;

$FrontEndServerRegistryDirectory := Replace[
    Environment[ "CHATBOOK_FE_SERVER_REGISTRY" ],
    Except[ _String? (StringLength[ # ] > 0 &) ] :>
        FileNameJoin @ { $UserBaseDirectory, "ApplicationData", "ChatbookFrontEndServer", "Servers" }
];

If[ ! AssociationQ @ $FrontEndServer, $FrontEndServer = None ];
(* Servers started by an older version of this file only kept the token in $FrontEndServer: *)
If[ ! StringQ @ $serverToken, $serverToken = If[ AssociationQ @ $FrontEndServer, Lookup[ $FrontEndServer, "Token", None ], None ] ];
If[ ! AssociationQ @ $doneCells, $doneCells = <| |> ];
If[ ! MatchQ[ $pumpEvaluator, _String | Automatic ], $pumpEvaluator = Automatic ];


(* ::Section::Closed:: *)
(*StartFrontEndServer*)


StartFrontEndServer // Options = {
    "Host"     -> "127.0.0.1",
    "Name"     -> Automatic,
    "Registry" -> True,
    "Token"    -> Automatic
};

StartFrontEndServer[ opts: OptionsPattern[ ] ] := StartFrontEndServer[ Automatic, opts ];

StartFrontEndServer[ port_, opts: OptionsPattern[ ] ] := Enclose[
    Module[ { host, listener, actualPort, token, name, info },

        ConfirmAssert[ $FrontEnd =!= Null, "StartFrontEndServer requires a kernel attached to a front end." ];

        (* Restart cleanly if a server is already running in this kernel: *)
        If[ AssociationQ @ $FrontEndServer, StopFrontEndServer[ ] ];

        host  = OptionValue[ "Host" ];
        token = Replace[ OptionValue[ "Token" ], Except[ _String ] :> CreateUUID[ ] ];

        (* Requests are authenticated against $serverToken, which must be set before the port is open: *)
        $serverToken = token;
        listener     = ConfirmMatch[ listen[ host, port ], _SocketListener, "Listen" ];
        actualPort   = ConfirmBy[ listener[ "Socket" ][ "DestinationPort" ], IntegerQ, "Port" ];
        name         = Replace[ OptionValue[ "Name" ], Automatic :> "fe-" <> ToString @ actualPort ];

        (* The pump button must evaluate in this kernel, also when it was started from a notebook whose evaluator is
           not the default one (not known when started from an init file, where the default is right): *)
        If[ ! MatchQ[ $pumpNotebook, _NotebookObject ] || EvaluationNotebook[ ] =!= $pumpNotebook,
            $pumpEvaluator = Replace[ Quiet @ AbsoluteCurrentValue[ EvaluationCell[ ], Evaluator ], Except[ _String ] -> Automatic ]
        ];

        info = <|
            "Name"            -> name,
            "Host"            -> host,
            "Port"            -> actualPort,
            "Token"           -> token,
            "KernelPID"       -> $ProcessID,
            "FrontEndPID"     -> $ParentProcessID,
            "Display"         -> Replace[ Environment[ "DISPLAY" ], $Failed -> Null ],
            "Version"         -> $VersionNumber,
            "SystemID"        -> $SystemID,
            "StartTime"       -> UnixTime[ ],
            "Launched"        -> StringQ @ Environment[ "CHATBOOK_FE_SERVER_PORT" ],
            "Listener"        -> listener,
            "RegistryFile"    -> None
        |>;

        $FrontEndServer = info;
        If[ TrueQ @ OptionValue[ "Registry" ], $FrontEndServer[ "RegistryFile" ] = writeRegistry @ info ];
        $queue = { };
        $pumping = False;
        $pumpTriggered = None;
        (* Not possible yet when started from an init file; the pump is then created on the first request: *)
        If[ frontEndReadyQ[ ], createPump[ ] ];
        FrontEndServerInformation[ ]
    ],
    Function[ failure, failure ]
];


(* ::Subsection::Closed:: *)
(*listen*)


(* Messages are split into lines by `handleEvent` itself: the built-in RecordSeparators option gets quadratically slow
   for large messages (it re-reads the whole buffer on every chunk). *)
listen[ host_String, port_Integer ] := Quiet @ SocketListen[ { host, port }, handleEvent ];

listen[ host_String, Automatic ] := FirstCase[
    Range @@ $defaultPortRange,
    port_ :> With[ { l = listen[ host, port ] }, l /; MatchQ[ l, _SocketListener ] ],
    listen[ host, 0 ]
];

listen[ host_String, 0 ] := Quiet @ SocketListen[ { host, Automatic }, handleEvent ];


(* ::Section::Closed:: *)
(*StopFrontEndServer*)


StopFrontEndServer[ ] := Module[ { info = $FrontEndServer },
    If[ ! AssociationQ @ info, Return @ Missing[ "NotRunning" ] ];
    Quiet[ Close @ info[ "Listener" ][ "Socket" ] ];
    Quiet[ DeleteObject @ info[ "Listener" ] ];
    If[ StringQ @ info[ "RegistryFile" ] && FileExistsQ @ info[ "RegistryFile" ], Quiet @ DeleteFile @ info[ "RegistryFile" ] ];
    Quiet @ NotebookClose @ $pumpNotebook;
    $pumpNotebook = $pumpBox = None;
    $queue = { };
    $serverToken = None;
    $FrontEndServer = None;
    KeyDrop[ info, { "Listener", "Token" } ]
];


(* ::Section::Closed:: *)
(*FrontEndServerInformation*)


(* The access token is deliberately left out (it would otherwise be displayed in a notebook); clients read it from
   the registry file, which only the current user can read. *)
FrontEndServerInformation[ ] :=
    If[ AssociationQ @ $FrontEndServer,
        KeyDrop[ $FrontEndServer, { "Listener", "Token" } ],
        Missing[ "NotRunning" ]
    ];


(* ::Section::Closed:: *)
(*FrontEndServerNotebook / FrontEndServerCell*)


(* Resolve the notebook and cell references used by fe.py (titles, ids, "selected", ...), for use in evaluated code: *)
FrontEndServerNotebook[ ref_ ] := Catch[ resolveNotebook @ ref, $commandTag ];
FrontEndServerCell[ ref_ ] := Catch[ resolveCell @ ref, $commandTag ];


(* ::Section::Closed:: *)
(*Registry*)


writeRegistry[ info_Association ] := Enclose[
    Module[ { dir, file, json },
        dir  = ConfirmBy[ ensureDirectory @ $FrontEndServerRegistryDirectory, DirectoryQ, "Directory" ];
        file = FileNameJoin @ { dir, ToString @ info[ "Port" ] <> ".json" };
        json = KeyDrop[ info, { "Listener", "RegistryFile" } ];
        (* The file contains the access token, so only the current user may read the directory: *)
        If[ $OperatingSystem =!= "Windows", Quiet @ RunProcess @ { "chmod", "700", dir } ];
        ConfirmBy[ Export[ file, json, "RawJSON", "Compact" -> False ], StringQ, "Export" ];
        If[ $OperatingSystem =!= "Windows", Quiet @ RunProcess @ { "chmod", "600", file } ];
        file
    ],
    None &
];

ensureDirectory[ dir_String ] := If[ DirectoryQ @ dir, dir, Quiet @ CreateDirectory[ dir, CreateIntermediateDirectories -> True ] ];


(* ::Section::Closed:: *)
(*Event Handling*)


(* SocketListen handlers run *preemptively* (like Dynamic evaluations): front end calls made from them go over the
   front end's service link, and doing a lot of front end work there can deadlock the kernel and the front end
   against main-link activity (for example a notebook assistant window initializing).

   So the handler does no front end work of its own. It validates the request, answers "ping" itself, and otherwise
   queues the request and fires a Method -> "Queued" button in a hidden notebook. The front end then runs `pump[]`
   as an ordinary main-link evaluation, exactly as if a user had clicked a button, and `pump[]` processes the queue.

   Consequence: while the kernel is busy with another evaluation (e.g. an input cell), requests wait until it is done.
   Requests with "preemptive": true are processed directly in the handler instead, which allows inspecting state
   during a long evaluation, at some risk. *)

If[ ! ListQ @ $queue, $queue = { } ];
If[ ! BooleanQ @ $pumping, $pumping = False ];
If[ ! NumberQ @ $pumpTriggered, $pumpTriggered = None ];
$pumpRetriggerInterval = 5;


(* handleEvent itself is defined at the top of this file (it must survive reloads). It wraps handleEvent0 in CheckAll,
   since an Abort or uncaught Throw escaping a handler would abort whatever the kernel happens to be evaluating. *)

handleEvent0[ event_Association ] := Module[ { socket, bytes },
    socket = event[ "SourceSocket" ];
    bytes  = event[ "DataByteArray" ];
    If[ MatchQ[ socket, _SocketObject ] && ByteArrayQ @ bytes && Length @ bytes > 0,
        Scan[ handleLine[ socket, # ] &, takeLines[ socket, bytes ] ]
    ]
];

handleEvent0[ ___ ] := Null;


handleLine[ socket_, line_ByteArray ] := Module[ { string, request },
    string = Quiet @ Check[ ByteArrayToString[ line, "UTF-8" ], $Failed ];
    If[ ! StringQ @ string, Return @ sendResponse[ socket, errorResponse[ Null, "EncodingError", "The request is not valid UTF-8." ] ] ];
    If[ StringTrim @ string === "", Return @ Null ]; (* blank lines are allowed as keep-alives *)
    request = Catch[ parseRequest @ string, $tag ];
    retriggerStrandedPump[ ];
    Which[
        KeyExistsQ[ request, "ok" ], sendResponse[ socket, request ], (* invalid request *)
        request[ "command" ] === "ping" || TrueQ @ request[ "preemptive" ], sendResponse[ socket, processRequest @ request ],
        True, enqueue[ socket, request ]
    ]
];

handleLine[ ___ ] := Null;


(* ::Subsection::Closed:: *)
(*Line buffering*)


(* Data arrives in arbitrary chunks (at most 8 KB each): one chunk can hold several requests or end in the middle of
   one (even in the middle of a UTF-8 sequence). Complete lines are split off at newline bytes (UTF-8 continuation
   bytes are never 10) and the rest is buffered per client socket. *)
If[ ! AssociationQ @ $buffers, $buffers = <| |> ];
$maxRequestBytes = 512 * 1024^2;

takeLines[ socket_, bytes_ByteArray ] := Module[ { newlines, lines = { }, start = 1 },
    newlines = Pick[ Range @ Length @ bytes, Normal @ bytes, 10 ];
    Do[
        AppendTo[ lines, joinBuffered[ socket, If[ nl > start, bytes[[ start ;; nl - 1 ]], None ] ] ];
        start = nl + 1,
        { nl, newlines }
    ];
    If[ start <= Length @ bytes, appendBuffered[ socket, bytes[[ start ;; ]] ] ];
    lines
];

appendBuffered[ socket_, bytes_ByteArray ] := (
    If[ ! KeyExistsQ[ $buffers, socket ], purgeBuffers[ ] ];
    $buffers[ socket ] = Append[ Lookup[ $buffers, socket, { } ], bytes ];
    If[ Total[ Length /@ $buffers[ socket ] ] > $maxRequestBytes,
        KeyDropFrom[ $buffers, socket ];
        sendResponse[ socket, errorResponse[ Null, "RequestTooLarge", "The request exceeds the maximum size." ] ]
    ]
);

joinBuffered[ socket_, tail_ ] := Module[ { parts = Lookup[ $buffers, socket, { } ] },
    KeyDropFrom[ $buffers, socket ];
    If[ ByteArrayQ @ tail, AppendTo[ parts, tail ] ];
    Replace[ parts, { { } -> ByteArray[ { } ], { one_ } :> one, many_ :> Join @@ many } ]
];

(* There is no disconnect event, so drop partial requests of clients that are gone: *)
purgeBuffers[ ] := Module[ { live },
    live = Quiet @ $FrontEndServer[ "Listener" ][ "Socket" ][ "ConnectedClients" ];
    If[ ListQ @ live, KeyDropFrom[ $buffers, Complement[ Keys @ $buffers, live ] ] ]
];


(* ::Subsection::Closed:: *)
(*parseRequest*)


parseRequest[ data_String ] := Module[ { request, id, command, args },

    request = Quiet @ Developer`ReadRawJSONString @ StringTrim[ data, "\r" ];
    If[ ! AssociationQ @ request, Throw[ errorResponse[ Null, "InvalidJSON", "Could not parse request as JSON." ], $tag ] ];

    id = Lookup[ request, "id", Null ];

    If[ ! StringQ @ $serverToken || Lookup[ request, "token", None ] =!= $serverToken,
        Throw[ errorResponse[ id, "Unauthorized", "Missing or invalid token." ], $tag ]
    ];

    command = Lookup[ request, "command", None ];
    args    = Replace[ Lookup[ request, "args", <| |> ], Except[ _Association ] :> <| |> ];

    If[ ! KeyExistsQ[ $commands, command ],
        Throw[ errorResponse[ id, "UnknownCommand", "Unknown command: " <> ToString[ command, InputForm ], <| "Commands" -> Keys @ $commands |> ], $tag ]
    ];

    <|
        "id"         -> id,
        "command"    -> command,
        "args"       -> args,
        "preemptive" -> TrueQ @ Lookup[ request, "preemptive", False ],
        "deadline"   -> Replace[ Lookup[ request, "deadline", None ], Except[ _? NumericQ ] -> None ]
    |>
];


(* ::Subsection::Closed:: *)
(*processRequest*)


processRequest[ request_Association ] := Module[ { id, command, result, timing },
    id      = request[ "id" ];
    command = request[ "command" ];

    (* The client gave up waiting; don't perform stale actions (e.g. a click) long after the fact: *)
    If[ NumberQ @ request[ "deadline" ] && unixTime[ ] > request[ "deadline" ],
        Return @ errorResponse[ id, "Expired", "The request expired before it could be processed." ]
    ];

    (* When started from an init file, the server is listening before the kernel's front end link is usable: *)
    If[ command =!= "ping" && ! frontEndReadyQ[ ],
        Return @ errorResponse[ id, "FrontEndNotReady", "The front end connection is not ready yet; retry shortly." ]
    ];

    { timing, result } = AbsoluteTiming @ CheckAll[
        Catch[ $commands[ command ][ request[ "args" ] ], $commandTag ],
        Function[ { value, interrupt }, If[ interrupt === Hold[ ], value, commandFailure[ "Interrupted", "The command was interrupted: " <> inputString[ interrupt, 500 ], <| |> ] ] ]
    ];

    If[ MatchQ[ result, _commandFailure ],
        errorResponse[ id, result[[ 1 ]], result[[ 2 ]], <| result[[ 3 ]], "Timing" -> timing |> ],
        <| "id" -> id, "ok" -> True, "result" -> toJSON @ result, "timing" -> timing |>
    ]
];


unixTime[ ] := AbsoluteTime[ TimeZone -> 0 ] - 2208988800;


(* Syntax error messages, from parsing in a throwaway context: *)
syntaxMessages[ code_String ] := Module[ { messages },
    messages = Block[ { $Context = "Wolfram`ChatbookFrontEndServer`SyntaxCheck`", $ContextPath = { "System`" } },
        messageStrings @ EvaluationData @ ToExpression[ code, InputForm, HoldComplete ]
    ];
    Quiet @ Remove[ "Wolfram`ChatbookFrontEndServer`SyntaxCheck`*" ];
    messages
];


(* Like a notebook or Get, read and evaluate one top-level expression at a time, so that e.g. BeginPackage affects how
   the following expressions are parsed. (The code was already checked for syntax errors as a whole.) *)
evaluateStatements[ code_String ] := Module[ { stream, held, result = Null },
    stream = StringToStream @ code;
    WithCleanup[
        While[ MatchQ[ held = Read[ stream, HoldComplete @ Expression ], _HoldComplete ], result = runHeld @ held ],
        Close @ stream
    ];
    result
];

(* Evaluating through a definition of its own absorbs a top-level Return[...] in the code: *)
runHeld[ HoldComplete[ e_ ] ] := e;
runHeld[ HoldComplete[ ] ] := Null;

ensureContextPath[ path_List ] := Join[ path, Complement[ { "System`", "Global`" }, path ] ];
ensureContextPath[ _ ] := { "System`", "Global`" };


(* ::Subsection::Closed:: *)
(*Queue*)


enqueue[ socket_, request_Association ] := (
    AppendTo[ $queue, { socket, request } ];
    (* A running pump picks up new requests itself. While the kernel is busy with another evaluation, the trigger is
       left for later: the client keeps pinging while it waits, and the first request that arrives while the kernel is
       idle fires it (see retriggerStrandedPump). *)
    If[ ! TrueQ @ $pumping && kernelIdleQ[ ], triggerPump[ ] ]
);


(* Whether the kernel's main loop is idle, i.e. this handler was not started at a preemption point inside another
   evaluation. Front end calls from a handler that interrupts an evaluation (for example one that is itself waiting
   for the front end, like a streaming chat output) risk a deadlock, so the handler only talks to the front end when
   the kernel is idle. When idle, the outermost evaluation is the asynchronous task that runs this handler. *)
kernelIdleQ[ ] := MatchQ[
    First[ Stack[ _ ], None ],
    HoldPattern[ (HoldForm | HoldCompleteForm)[ Block[ { $AsynchronousTask = _ }, ___ ] ] ]
];


triggerPump[ ] := Module[ { triggered },
    (* A pump is already scheduled, e.g. waiting for a cell evaluation to finish; avoid more front end calls: *)
    If[ NumberQ @ $pumpTriggered && AbsoluteTime[ ] - $pumpTriggered < $pumpRetriggerInterval, Return @ Null ];
    triggered = fireTrigger[ $pumpBox ] || fireTrigger[ createPump[ ] ];
    If[ triggered,
        $pumpTriggered = AbsoluteTime[ ],
        (* No usable pump (e.g. the front end is not ready yet); process the queue right here: *)
        pump[ ]
    ]
];

(* If the front end dropped a pump evaluation (e.g. when evaluations were aborted), queued requests would wait forever;
   any incoming request (pings included) re-fires the trigger once the pending pump is overdue: *)
retriggerStrandedPump[ ] :=
    If[ $queue =!= { } && ! TrueQ @ $pumping && kernelIdleQ[ ] &&
        ( ! NumberQ @ $pumpTriggered || AbsoluteTime[ ] - $pumpTriggered >= $pumpRetriggerInterval ),
        triggerPump[ ]
    ];

fireTrigger[ box_BoxObject ] := TrueQ @ Quiet @ MathLink`CallFrontEnd @ FrontEnd`TriggerControlBoxObject @ box;
fireTrigger[ _ ] := False;


(* Processes queued requests; normally run as a queued main-link evaluation through the pump button: *)
pump[ ] := (
    $pumpTriggered = None;
    If[ ! TrueQ @ $pumping,
        $pumping = True;
        WithCleanup[
            While[ $queue =!= { },
                With[ { item = First @ $queue },
                    $queue = Rest @ $queue;
                    sendResponse[ item[[ 1 ]], processRequest @ item[[ 2 ]] ]
                ]
            ],
            $pumping = False
        ];
        cleanPumpNotebook[ ];
        (* A request may have been queued just after the loop's last check: *)
        If[ $queue =!= { }, pump[ ] ]
    ]
);


(* ::Subsection::Closed:: *)
(*Pump notebook*)


If[ ! MatchQ[ $pumpBox, _BoxObject ], $pumpBox = None ];
If[ ! MatchQ[ $pumpNotebook, _NotebookObject ], $pumpNotebook = None ];

createPump[ ] := Enclose[
    Module[ { nb, box },
        ConfirmAssert @ frontEndReadyQ[ ];
        Quiet @ NotebookClose @ $pumpNotebook;
        nb = ConfirmMatch[
            NotebookPut @ Notebook[
                {
                    Cell[
                        BoxData @ ButtonBox[
                            "\"Front End Server Pump\"",
                            ButtonFunction :> Wolfram`ChatbookFrontEndServer`Private`pump[ ],
                            Evaluator      -> $pumpEvaluator,
                            Method         -> "Queued",
                            BoxID          -> "FrontEndServerPump"
                        ],
                        "Text"
                    ]
                },
                Visible       -> False,
                Saveable      -> False,
                (* A notebook's Evaluator must be a kernel name; Automatic would make the front end complain: *)
                If[ StringQ @ $pumpEvaluator, Evaluator -> $pumpEvaluator, Nothing ],
                WindowTitle   -> "Front End Server Pump",
                TaggingRules  -> <| "FrontEndServerPump" -> True |>
            ],
            _NotebookObject,
            "Notebook"
        ];
        box = ConfirmMatch[
            MathLink`CallFrontEnd @ FrontEnd`BoxReferenceBoxObject[
                FE`BoxReference[ nb, { { "FrontEndServerPump" } } ],
                FE`SearchStart -> "StartFromBeginning",
                FE`SearchStop  -> "StopAtEnd"
            ],
            _BoxObject,
            "BoxObject"
        ];
        $pumpNotebook = nb;
        $pumpBox = box
    ],
    None &
];


(* Anything printed by queued evaluations lands in the pump notebook (their evaluation notebook); keep it empty: *)
cleanPumpNotebook[ ] := Quiet @ With[ { cells = Cells @ $pumpNotebook },
    If[ MatchQ[ cells, { _, __ } ], NotebookDelete @ Rest @ cells ]
];


serverNotebookQ[ nb_NotebookObject ] := nb === $pumpNotebook || TrueQ @ Quiet @ CurrentValue[ nb, { TaggingRules, "FrontEndServerPump" } ];
serverNotebookQ[ _ ] := False;


errorResponse[ id_, tag_, message_ ] := errorResponse[ id, tag, message, <| |> ];
errorResponse[ id_, tag_, message_, extra_Association ] :=
    <| "id" -> id, "ok" -> False, "error" -> ToString @ message, "errorType" -> ToString @ tag, KeyMap[ decapitalize, toJSON /@ extra ] |>;

decapitalize[ s_String ] := ToLowerCase @ StringTake[ s, 1 ] <> StringDrop[ s, 1 ];
decapitalize[ other_ ] := other;

commandError[ tag_, message_ ] := commandError[ tag, message, <| |> ];
commandError[ tag_, message_, extra_Association ] := Throw[ commandFailure[ tag, message, extra ], $commandTag ];


(* ::Subsection::Closed:: *)
(*sendResponse*)


(* Compact JSON never contains a raw newline, so one response is exactly one line. *)
sendResponse[ socket_SocketObject, response_Association ] := Module[ { json },
    json = Quiet @ Developer`WriteRawJSONString[ response, "Compact" -> True ];
    If[ ! StringQ @ json,
        json = Developer`WriteRawJSONString[
            <|
                "id"        -> Lookup[ response, "id", Null ],
                "ok"        -> False,
                "errorType" -> "EncodingError",
                "error"     -> "Could not encode the response as JSON: " <> inputString[ response, 2000 ]
            |>,
            "Compact" -> True
        ]
    ];
    writeBytes[ socket, StringToByteArray[ json <> "\n", "UTF-8" ] ]
];

sendResponse[ ___ ] := Null;


(* SocketWriteMessage is much faster than BinaryWrite (which goes through a stream with many small round trips), and
   WriteString does not write UTF-8. Writing to a client that has gone away just fails. *)
$writeChunkSize = 2^20;

writeBytes[ socket_, bytes_ByteArray ] := With[ { n = Length @ bytes },
    Quiet @ Catch @ Do[
        If[ FailureQ @ SocketWriteMessage[ socket, bytes[[ i ;; Min[ i + $writeChunkSize - 1, n ] ]] ], Throw @ $Failed ],
        { i, 1, n, $writeChunkSize }
    ]
];


(* ::Subsection::Closed:: *)
(*toJSON*)


(* Convert an arbitrary WL result into something WriteRawJSONString can encode. *)
toJSON[ as_Association ] := Association @ KeyValueMap[ ToString[ #1 ] -> toJSON[ #2 ] &, as ];
toJSON[ list_List ] := toJSON /@ list;
toJSON[ s_String ] := s;
toJSON[ i_Integer ] := i;
toJSON[ r_Real ] := If[ Abs[ r ] < 10.^300, r, ToString @ r ];
toJSON[ True ] := True;
toJSON[ False ] := False;
toJSON[ Null ] := Null;
toJSON[ None ] := Null;
toJSON[ r_Rational ] := N @ r;
toJSON[ other_ ] := inputString @ other;


(* ::Section::Closed:: *)
(*Utilities*)


inputString[ expr_ ] := inputString[ expr, $maxResultCharacters ];
inputString[ expr_, max_ ] := truncate[ ToString[ Unevaluated @ expr, InputForm, PageWidth -> Infinity, CharacterEncoding -> "Unicode" ], max ];

truncate[ s_String, max_Integer ] /; StringLength[ s ] > max :=
    StringTake[ s, max ] <> "... [truncated " <> ToString[ StringLength[ s ] - max ] <> " characters]";
truncate[ s_String, _ ] := s;

objectID[ obj_ ] := ToString[ obj, InputForm ];


(* ::Section::Closed:: *)
(*Commands*)


$commands = <| |>;


(* ::Subsection::Closed:: *)
(*Argument Helpers*)


requireArg[ args_Association, key_String ] := Lookup[ args, key, commandError[ "MissingArgument", "Missing required argument \"" <> key <> "\"." ] ];

intArg[ args_, key_, default_ ] := Replace[ Lookup[ args, key, default ], { n_? NumericQ :> Round @ n, _ :> default } ];
numArg[ args_, key_, default_ ] := Replace[ Lookup[ args, key, default ], { n_? NumericQ :> n, _ :> default } ];
boolArg[ args_, key_, default_ ] := Replace[ Lookup[ args, key, default ], { True -> True, False -> False, _ :> default } ];


(* ::Subsection::Closed:: *)
(*ping / info*)


(* Answered directly in the socket handler, so it avoids front end calls once the front end is known to be ready: *)
$commands[ "ping" ] = Function @ <|
    "pong"        -> True,
    "ready"       -> frontEndReadyQ[ ],
    "queued"      -> Length @ $queue,
    "pumping"     -> TrueQ @ $pumping,
    "pumpPending" -> If[ NumberQ @ $pumpTriggered, Round[ AbsoluteTime[ ] - $pumpTriggered, 0.01 ], Null ],
    "time"        -> UnixTime[ ]
|>;


(* Whether front end calls work in the current context. This is tracked per link, because the socket handler talks to
   the front end over its service link, while queued evaluations use the main link, which becomes usable a little later
   during startup. Cached once true, since checking requires a round trip to the front end. *)
If[ ! AssociationQ @ $readyLinks, $readyLinks = <| |> ];

frontEndReadyQ[ ] := Replace[
    $FrontEnd,
    {
        FrontEndObject[ link_ ] :> TrueQ @ $readyLinks[ link ] || ( $readyLinks[ link ] = ListQ @ Quiet @ Notebooks[ ] ),
        _ :> False
    }
];

$commands[ "info" ] = Function @ Module[ { info = FrontEndServerInformation[ ] },
    <|
        info,
        "FrontEndVersion"  -> Quiet @ CurrentValue[ $FrontEnd, "FrontEndVersion" ],
        "KernelVersion"    -> $Version,
        "ChatbookVersion"  -> chatbookVersion[ ],
        "ChatbookLocation" -> chatbookLocation[ ],
        "Notebooks"        -> Length @ Select[ userNotebooks[ ], visibleQ ]
    |>
];

(* Processed through the queue like every other command, so it returns once the kernel is free: *)
(* (Cells written by "evaluateCell" may still be waiting in the front end's evaluation queue, so report those.) *)
$commands[ "sync" ] = Function @ Module[ { pending },
    pending = Select[ Keys @ $doneCells, pendingCellQ ];
    <| "idle" -> pending === { }, "pending" -> Length @ pending, "time" -> UnixTime[ ] |>
];

pendingCellQ[ id_String ] := Module[ { cell = Quiet @ resolveCell @ id },
    If[ MatchQ[ cell, _CellObject ],
        cellEvaluatingQ[ cell, Association @ Replace[ Quiet @ Developer`CellInformation @ cell, Except[ _List ] -> { } ] ],
        KeyDropFrom[ $doneCells, id ]; False
    ]
];


chatbookVersion[ ] := Replace[
    Quiet @ PacletObject[ "Wolfram/Chatbook" ][ "Version" ],
    Except[ _String ] -> Missing[ "NotAvailable" ]
];

chatbookLocation[ ] := Replace[
    Quiet @ PacletObject[ "Wolfram/Chatbook" ][ "Location" ],
    Except[ _String ] -> Missing[ "NotAvailable" ]
];


(* ::Subsection::Closed:: *)
(*evaluate*)


(* Evaluate code directly in the server kernel (inside the socket handler).
   Use this for queries and for driving the FE via NotebookWrite, FrontEndTokenExecute, etc.
   Long-running evaluations block the handler (and the kernel), so keep them short. *)
$commands[ "evaluate" ] = Function[ args, evaluateCode[ args ] ];

evaluateCode[ args_Association ] := Module[ { code, timeout, max, context, data, result, out },
    code    = requireArg[ args, "code" ];
    timeout = numArg[ args, "timeout", 60 ];
    max     = intArg[ args, "maxCharacters", $maxResultCharacters ];

    If[ ! StringQ @ code, commandError[ "InvalidArgument", "\"code\" must be a string." ] ];

    context = Replace[ Lookup[ args, "context", "Global`" ], Except[ _String ] -> "Global`" ];
    (* SyntaxQ creates no symbols, unlike parsing everything up front (statements are parsed one at a time below): *)
    If[ ! TrueQ @ Quiet @ SyntaxQ @ code, commandError[ "SyntaxError", "Could not parse code.", <| "Messages" -> syntaxMessages @ code |> ] ];

    (* Output and messages are captured by EvaluationData; blocking the streams keeps them out of the evaluation
       notebook (the hidden pump notebook) and the Messages window. $ContextPath is not blocked, so that packages
       loaded by the code stay loaded, as they would in a notebook: *)
    data = Block[ { $Output = { }, $Messages = { }, $Context = context },
        EvaluationData @ TimeConstrained[ evaluateStatements @ code, timeout, $timedOut ]
    ];

    result = data[ "Result" ];
    out = <|
        "result"   -> If[ imageResultQ @ result, shortForm @ result, formatResult[ result, Lookup[ args, "form", "InputForm" ], max ] ],
        "head"     -> ToString[ Head @ result, InputForm ],
        "success"  -> TrueQ @ data[ "Success" ] && result =!= $timedOut,
        "messages" -> messageStrings @ data,
        "output"   -> Replace[ Lookup[ data, "OutputLog", { } ], Except[ _List ] -> { } ],
        "timing"   -> data[ "AbsoluteTiming" ]
    |>;

    If[ result === $timedOut, out[ "result" ] = "$TimedOut"; out[ "timedOut" ] = True ];

    If[ imageResultQ @ result || StringQ @ Lookup[ args, "imagePath", None ],
        out[ "image" ] = exportImage[ result, Lookup[ args, "imagePath", Automatic ], numArg[ args, "imageResolution", 144 ] ]
    ];

    out
];


(* One line per message, with arguments in InputForm (MessagesText gives 2D-formatted text): *)
messageStrings[ data_ ] := Replace[
    Lookup[ data, "MessagesExpressions", Missing[ ] ],
    {
        list_List :> messageString /@ list,
        _ :> Replace[ Lookup[ data, "MessagesText", { } ], Except[ _List ] -> { } ]
    }
];

messageString[ Hold[ Message[ mn: MessageName[ sym_Symbol, tag_String, ___ ], args___ ] ] ] := Module[ { name, template, strings },
    name     = ToString[ Unevaluated @ mn, InputForm ];
    template = Replace[ mn, Except[ _String ] :> Replace[ MessageName[ General, tag ], Except[ _String ] -> None ] ];
    strings  = messageArgString /@ { args };
    If[ StringQ @ template,
        name <> ": " <> ToString @ StringForm[ template, Sequence @@ strings ],
        name <> ": " <> StringRiffle[ strings, ", " ]
    ]
];

messageString[ other_ ] := inputString[ other, 500 ];

messageArgString[ HoldCompleteForm[ e_ ] ] := inputString[ Unevaluated @ e, 300 ];
messageArgString[ HoldForm[ e_ ] ] := inputString[ Unevaluated @ e, 300 ];
messageArgString[ s_String ] := truncate[ s, 300 ];
messageArgString[ e_ ] := inputString[ Unevaluated @ e, 300 ];


formatResult[ result_, "InputForm", max_ ] := inputString[ result, max ];
formatResult[ result_, "OutputForm", max_ ] := truncate[ ToString[ result, OutputForm, PageWidth -> 120 ], max ];
formatResult[ result_, "String", max_ ] := truncate[ If[ StringQ @ result, result, ToString @ result ], max ];
formatResult[ result_, "JSON", max_ ] := toJSON @ result;
formatResult[ result_, "TeXForm", max_ ] := truncate[ ToString[ result, TeXForm ], max ];
formatResult[ result_, _, max_ ] := inputString[ result, max ];


imageResultQ[ _Graphics | _Graphics3D | _Image | _Image3D | _Legended | _GeoGraphics | _Graph | _Manipulate ] := True;
imageResultQ[ _ ] := False;

shortForm[ img_Image ] := "Image[<" <> StringRiffle[ ToString /@ ImageDimensions @ img, "x" ] <> ">]";
shortForm[ expr_ ] := ToString[ Head @ expr, InputForm ] <> "[<...>]";


exportImage[ expr_, path_, resolution_ ] := Enclose[
    Module[ { image, file },
        image = ConfirmBy[ If[ ImageQ @ expr, expr, Rasterize[ expr, ImageResolution -> resolution ] ], ImageQ, "Rasterize" ];
        file  = Replace[ path, Except[ _String ] :> newImagePath[ "result" ] ];
        ConfirmBy[ Export[ file, image, "PNG" ], StringQ, "Export" ];
        <| "path" -> file, "width" -> ImageDimensions[ image ][[ 1 ]], "height" -> ImageDimensions[ image ][[ 2 ]] |>
    ],
    <| "error" -> "Could not export image" |> &
];


newImagePath[ prefix_String ] := FileNameJoin @ {
    ensureDirectory @ FileNameJoin @ { $TemporaryDirectory, "ChatbookFrontEndServer-" <> $Username, "images" },
    prefix <> "-" <> DateString[ "ISODateTime" ] ~StringReplace~ ( ":" -> "" ) <> "-" <> ToString @ RandomInteger[ 99999 ] <> ".png"
};


(* ::Subsection::Closed:: *)
(*Notebooks*)


$commands[ "notebooks" ] = Function[ args,
    notebookSummary /@ Select[ userNotebooks[ ], If[ boolArg[ args, "includeHidden", False ], True &, visibleQ ] ]
];

visibleQ[ nb_NotebookObject ] := TrueQ @ Quiet @ AbsoluteCurrentValue[ nb, Visible ];

userNotebooks[ ] := Select[ Notebooks[ ], ! serverNotebookQ[ # ] & ];

notebookSummary[ nb_NotebookObject ] := Module[ { margins, size, tags },
    margins = Quiet @ AbsoluteCurrentValue[ nb, WindowMargins ];
    size    = Quiet @ AbsoluteCurrentValue[ nb, WindowSize ];
    tags    = Quiet @ CurrentValue[ nb, TaggingRules ];
    <|
        "id"          -> nb[[ 1 ]],
        "object"      -> objectID @ nb,
        "title"       -> Quiet @ AbsoluteCurrentValue[ nb, WindowTitle ],
        "file"        -> Replace[ Quiet @ NotebookFileName @ nb, Except[ _String ] -> Null ],
        "visible"     -> visibleQ @ nb,
        "selected"    -> nb === SelectedNotebook[ ],
        "windowFrame" -> Quiet @ AbsoluteCurrentValue[ nb, WindowFrame ],
        "styleSheet"  -> styleSheetName @ Quiet @ AbsoluteCurrentValue[ nb, StyleDefinitions ],
        "rect"        -> windowRect[ margins, size ],
        "cells"       -> Length @ Cells @ nb,
        "kind"        -> notebookKind[ nb, tags ]
    |>
];

windowRect[ { { left_? NumericQ, _ }, { _, top_? NumericQ } }, { w_? NumericQ, h_? NumericQ } ] :=
    <| "left" -> left, "top" -> top, "width" -> w, "height" -> h |>;
windowRect[ ___ ] := Null;

styleSheetName[ FrontEnd`FileName[ _, name_String, ___ ] ] := name;
styleSheetName[ name_String ] := name;
styleSheetName[ _Notebook ] := "(embedded)";
styleSheetName[ other_ ] := inputString[ other, 200 ];

notebookKind[ nb_, tags_ ] := Which[
    nb === MessagesNotebook[ ], "Messages",
    ! FreeQ[ tags, "NotebookAssistanceWindow" | "WorkspaceChat" -> True ], "ChatbookAssistant",
    TrueQ @ Quiet @ AbsoluteCurrentValue[ nb, { TaggingRules, "ChatNotebookSettings", "WorkspaceChat" } ], "ChatbookAssistant",
    True, "Notebook"
];


(* ::Subsection::Closed:: *)
(*resolveNotebook*)


resolveNotebook[ ref_ ] := Replace[ findNotebook @ ref, Except[ _NotebookObject ] :> commandError[ "NotebookNotFound", "No notebook matches " <> ToString[ ref, InputForm ] <> "." ] ];

findNotebook[ Automatic | Null | "selected" ] := SelectedNotebook[ ];
findNotebook[ "input" ] := InputNotebook[ ];
findNotebook[ "messages" ] := MessagesNotebook[ ];
findNotebook[ "console" ] := consoleNotebook[ ];
findNotebook[ ref_String ] /; StringStartsQ[ ref, "NotebookObject[" ] := Quiet @ ToExpression @ ref;
findNotebook[ ref_String ] := Module[ { nbs = userNotebooks[ ], byID, titles },
    byID = SelectFirst[ nbs, MemberQ[ List @@ #, ref ] & ];
    If[ MatchQ[ byID, _NotebookObject ], Return @ byID ];
    titles = { #, ToString @ Quiet @ AbsoluteCurrentValue[ #, WindowTitle ] } & /@ nbs;
    Replace[ Cases[ titles, { nb_, title_ } /; title === ref :> nb ], {
        { nb_, ___ } :> nb,
        { } :> Replace[ Cases[ titles, { nb_, title_ } /; StringContainsQ[ title, ref, IgnoreCase -> True ] :> { nb, title } ], {
            { } -> Missing[ ],
            { { nb_, _ } } :> nb,
            many_ :> commandError[ "AmbiguousNotebook", "Several notebooks match " <> ToString[ ref, InputForm ] <> ".", <| "Titles" -> many[[ All, 2 ]] |> ]
        } ]
    } ]
];
findNotebook[ ___ ] := Missing[ ];


(* A notebook for evaluating input cells that are sent with the "evaluateCell" command: *)
consoleNotebook[ ] := Module[ { existing },
    existing = SelectFirst[ Notebooks[ ], TrueQ @ Quiet @ CurrentValue[ #, { TaggingRules, "FrontEndServerConsole" } ] & ];
    If[ MatchQ[ existing, _NotebookObject ],
        existing,
        CreateDocument[ { }, WindowTitle -> "Front End Server Console", TaggingRules -> <| "FrontEndServerConsole" -> True |>, Saveable -> False ]
    ]
];


(* ::Subsection::Closed:: *)
(*Cells*)


$commands[ "cells" ] = Function[ args,
    Module[ { nb, cells, max, shared },
        nb    = resolveNotebook @ Lookup[ args, "notebook", Automatic ];
        max   = intArg[ args, "maxCharacters", 200 ];
        cells = Which[
            boolArg[ args, "sidebar", False ], sidebarCells @ nb,
            boolArg[ args, "attached", False ], allAttachedCells @ nb,
            True, Cells @ nb
        ];
        If[ StringQ @ Lookup[ args, "style", None ], cells = Select[ cells, cellStyle[ # ] === args[ "style" ] & ] ];
        (* Attached cells (e.g. the chat bar) can have the same id in several notebooks; give those a reference that
           identifies them uniquely: *)
        shared = If[ boolArg[ args, "attached", False ] || boolArg[ args, "sidebar", False ],
            Keys @ Select[ Counts[ #[[ 1 ]] & /@ allCells[ ] ], # > 1 & ],
            { }
        ];
        MapIndexed[ Append[ cellSummary[ #1, First[ #2 ], max ], "ref" -> If[ MemberQ[ shared, #1[[ 1 ]] ], objectID @ #1, #1[[ 1 ]] ] ] &, cells ]
    ]
];

cellSummary[ cell_CellObject, index_, max_ ] := Module[ { info },
    info = Association @ Replace[ Quiet @ Developer`CellInformation @ cell, Except[ _List ] -> { } ];
    <|
        "index"      -> index,
        "id"         -> cell[[ 1 ]],
        "object"     -> objectID @ cell,
        "style"      -> cellStyle @ cell,
        "evaluating" -> TrueQ @ Lookup[ info, "Evaluating", False ],
        "generated"  -> TrueQ @ Quiet @ AbsoluteCurrentValue[ cell, GeneratedCell ],
        "tags"       -> Replace[ Quiet @ AbsoluteCurrentValue[ cell, CellTags ], { s_String :> { s }, Except[ _List ] -> { } } ],
        "text"       -> truncate[ escapePrivateUse @ cellText @ cell, max ]
    |>
];

cellStyle[ cell_CellObject ] := Replace[ Quiet @ Developer`CellInformation @ cell, { { ___, "Style" -> style_, ___ } :> style, _ -> Null } ];

cellText[ cell_CellObject ] := cellText[ cell, "Plain" ];
cellText[ cell_CellObject, fmt_ ] /; ! MemberQ[ $cellTextFormats, fmt ] :=
    commandError[ "InvalidArgument", "Unknown format " <> ToString[ fmt, InputForm ] <> ".", <| "Formats" -> $cellTextFormats |> ];
cellText[ cell_CellObject, "Plain" ] := Replace[
    Quiet @ FrontEndExecute @ FrontEnd`ExportPacket[ cell, "PlainText" ],
    { { s_String, ___ } :> StringTrim @ s, _ :> "" }
];
cellText[ cell_CellObject, "InputText" ] := Replace[
    Quiet @ FrontEndExecute @ FrontEnd`ExportPacket[ cell, "InputText" ],
    { { s_String, ___ } :> StringTrim @ s, _ :> "" }
];
cellText[ cell_CellObject, "Markdown" ] := Replace[
    Quiet[ Needs[ "Wolfram`Chatbook`" -> None ]; Wolfram`Chatbook`CellToString @ NotebookRead @ cell ],
    Except[ _String ] :> cellText[ cell, "Plain" ]
];
cellText[ cell_CellObject, "Expression" ] := inputString[ NotebookRead @ cell, $maxResultCharacters ];

$cellTextFormats = { "Plain", "InputText", "Markdown", "Expression" };

(* Private-use characters (e.g. \[FreeformPrompt]) are invisible in a terminal, so show them as named characters: *)
escapePrivateUse[ text_String ] := StringReplace[
    text,
    c: RegularExpression[ "[\\x{E000}-\\x{F8FF}]" ] :> StringTake[ ToString[ c, InputForm, CharacterEncoding -> "ASCII" ], { 2, -2 } ]
];
escapePrivateUse[ other_ ] := other;


resolveCell[ ref_String ] := Module[ { cell },
    cell = If[ StringStartsQ[ ref, "CellObject[" ],
        Quiet @ ToExpression @ ref,
        (* Attached cells such as the chat bar can have the same id in several notebooks: *)
        Replace[ DeleteDuplicates @ Select[ allCells[ ], #[[ 1 ]] === ref & ], {
            { } -> Missing[ ],
            { one_ } :> one,
            many_ :> commandError[ "AmbiguousCell", "Several cells have the id " <> ref <> "; use the full object.", <| "Objects" -> objectID /@ many |> ]
        } ]
    ];
    If[ MatchQ[ cell, _CellObject ], cell, commandError[ "CellNotFound", "No cell matches " <> ToString[ ref, InputForm ] <> "." ] ]
];

resolveCell[ _ ] := commandError[ "InvalidArgument", "Cell references must be strings." ];

(* All cells of all user notebooks, including docked and attached cells (and the cells inside them): *)
allCells[ ] := Flatten[ notebookCells /@ userNotebooks[ ] ];
notebookCells[ nb_NotebookObject ] := Join[ Replace[ Quiet @ Cells @ nb, Except[ _List ] -> { } ], allAttachedCells @ nb ];


$commands[ "readCell" ] = Function[ args,
    Module[ { cell = resolveCell @ requireArg[ args, "cell" ] },
        <|
            "id"    -> cell[[ 1 ]],
            "style" -> cellStyle @ cell,
            "text"  -> truncate[ escapePrivateUse @ cellText[ cell, Lookup[ args, "format", "Plain" ] ], intArg[ args, "maxCharacters", $maxResultCharacters ] ]
        |>
    ]
];


(* ::Subsection::Closed:: *)
(*evaluateCell*)


(* Write an input cell to a notebook and evaluate it through the front end, exactly as if the user had pressed
   Shift+Enter. Returns immediately; poll with "cellStatus" to collect the results. *)
$commands[ "evaluateCell" ] = Function[ args,
    Module[ { nb, code, boxes, cell },
        nb   = resolveNotebook @ Lookup[ args, "notebook", "console" ];
        code = requireArg[ args, "code" ];
        If[ ! TrueQ @ Quiet @ SyntaxQ @ code, commandError[ "SyntaxError", "Could not parse code.", <| "Messages" -> syntaxMessages @ code |> ] ];
        boxes = Replace[
            Quiet @ FrontEndExecute @ FrontEnd`ReparseBoxStructurePacket @ code,
            Except[ _BoxData | _RowBox | _String ] :> code
        ];
        SelectionMove[ nb, After, Notebook ];
        NotebookWrite[ nb, Cell[ If[ MatchQ[ boxes, _BoxData ], boxes, BoxData @ boxes ], "Input" ], All ];
        cell = First[ SelectedCells @ nb, commandError[ "WriteFailed", "Could not write the input cell." ] ];
        (* Mark completion from the kernel, since a cell that is queued but not started yet does not count as
           "Evaluating" in the front end: *)
        With[ { id = cell[[ 1 ]] },
            $doneCells[ id ] = False;
            SetOptions[ cell, CellEpilog :> Wolfram`ChatbookFrontEndServer`Private`markCellDone[ id ] ]
        ];
        SelectionEvaluate @ nb;
        <| "cell" -> cell[[ 1 ]], "notebook" -> nb[[ 1 ]] |>
    ]
];


$commands[ "cellStatus" ] = Function[ args,
    Module[ { cell, info, outputs },
        cell    = resolveCell @ requireArg[ args, "cell" ];
        info    = Association @ Replace[ Quiet @ Developer`CellInformation @ cell, Except[ _List ] -> { } ];
        outputs = generatedCells @ cell;
        <|
            "evaluating" -> cellEvaluatingQ[ cell, info ],
            "outputs"    -> (<|
                "id"    -> #[[ 1 ]],
                "style" -> cellStyle @ #,
                "text"  -> truncate[ escapePrivateUse @ outputText[ #, Lookup[ args, "format", Automatic ] ], intArg[ args, "maxCharacters", $maxResultCharacters ] ]
            |> &) /@ outputs
        |>
    ]
];

markCellDone[ id_String ] := ( $doneCells[ id ] = True; );

(* For cells written by "evaluateCell", the cell's epilog marks completion. If that never happens (e.g. the evaluation
   was aborted), the cell counts as done once it has an In[...] label and is no longer evaluating. *)
cellEvaluatingQ[ cell_, info_ ] := Module[ { id = cell[[ 1 ]] },
    Which[
        TrueQ @ $doneCells[ id ], KeyDropFrom[ $doneCells, id ]; False,
        TrueQ @ Lookup[ info, "Evaluating", False ], True,
        KeyExistsQ[ $doneCells, id ] && ! StringQ @ Replace[ Quiet @ AbsoluteCurrentValue[ cell, CellLabel ], "" -> None ], True,
        True, KeyDropFrom[ $doneCells, id ]; False
    ]
];

(* Output cells as InputText (i.e. InputForm-like), other generated cells (messages, prints) as plain text: *)
outputText[ cell_, Automatic ] := Module[ { content = Quiet @ NotebookRead @ cell },
    Which[
        ! FreeQ[ content, GraphicsBox | Graphics3DBox | GraphBox ] && ByteCount @ content > 5000,
            "<graphics; view it with: screenshot --cell " <> cell[[ 1 ]] <> ">",
        cellStyle @ cell === "Output",
            cellText[ cell, "InputText" ],
        cellStyle @ cell === "Message",
            (* The plain text of a message cell is just its tag: *)
            Replace[ cellText[ cell, "Markdown" ], s_String /; StringFreeQ[ s, " " ] :> cellText[ cell, "InputText" ] ],
        True,
            cellText[ cell, "Plain" ]
    ]
];
outputText[ cell_, fmt_ ] := cellText[ cell, fmt ];


(* Cells generated by evaluating the given input cell (Output, Message, Print, ...): *)
generatedCells[ cell_CellObject ] := Module[ { next = cell, out = { } },
    While[ MatchQ[ next = Quiet @ NextCell @ next, _CellObject ] && TrueQ @ Quiet @ AbsoluteCurrentValue[ next, GeneratedCell ],
        AppendTo[ out, next ]
    ];
    out
];


(* ::Subsection::Closed:: *)
(*notebook*)


$commands[ "notebook" ] = Function[ args, notebookSummary @ resolveNotebook @ Lookup[ args, "notebook", Automatic ] ];


(* ::Subsection::Closed:: *)
(*locate*)


(* Find something on screen and return its bounding rectangles in screen coordinates (front end points).
   Targets: "boxID" (a box with that BoxID, searched in the notebook and in all of its attached cells),
   "text" (the n-th occurrence of some text, via NotebookFind), or "cell" (a cell's contents).
   Note: this moves the notebook's selection to the located item. *)
$commands[ "locate" ] = Function[ args, locate @ args ];

locate[ args_Association ] := Module[ { nb, target, found, geometry, rects },
    target = Which[
        StringQ @ Lookup[ args, "boxID", None ], { "BoxID", args[ "boxID" ] },
        StringQ @ Lookup[ args, "text", None ], { "Text", args[ "text" ] },
        StringQ @ Lookup[ args, "cell", None ], { "Cell", args[ "cell" ] },
        True, commandError[ "MissingArgument", "Give one of \"boxID\", \"text\", or \"cell\"." ]
    ];
    Switch[ target,
        { "BoxID", _ },
            nb = resolveNotebook @ Lookup[ args, "notebook", Automatic ];
            found = selectBox[ nb, Last @ target, Replace[ Lookup[ args, "scope", Automatic ], Except[ _String ] -> Automatic ] ],
        { "Text", _ },
            nb = resolveNotebook @ Lookup[ args, "notebook", Automatic ];
            found = selectText[ nb, Last @ target, intArg[ args, "occurrence", 1 ] ],
        { "Cell", _ },
            With[ { cell = resolveCell @ Last @ target },
                nb = ParentNotebook @ cell;
                found = selectCell @ cell
            ]
    ];
    geometry = selectionGeometry @ nb;
    rects = geometry[ "Rects" ];
    (* Boxes in docked cells are reported relative to the content area instead of the docked area. Make them relative
       to the docked area (the top of the window, below its menu bar if it has one); the client knows where the
       window really is (WindowMargins can be stale, e.g. when a window manager moved the window): *)
    If[ MatchQ[ found, KeyValuePattern[ "Scope" -> "Docked" ] ],
        rects = shiftRects[ rects, -Lookup[ Replace[ contentRect @ nb, Null -> <| |> ], "top", 0 ] ]
    ];
    <|
        "notebook"    -> nb[[ 1 ]],
        "target"      -> First @ target,
        "scope"       -> If[ AssociationQ @ found, found[ "Scope" ], "Notebook" ],
        "match"       -> If[ AssociationQ @ found, Lookup[ found, "Match", "Exact" ], "Exact" ],
        "coordinates" -> geometry[ "Coordinates" ],
        "menuBar"     -> menuBarQ @ nb,
        "content"     -> contentRect @ nb,
        "rects"       -> rects,
        "window"      -> notebookSummary[ nb ][ "rect" ]
    |>
];


(* Selections inside BoxData are reported in screen coordinates (a list of rectangles). Text selections in
   TextData/string cells come back as a single rectangle in *document* coordinates relative to the content area: x can be
   converted to the screen, but y depends on the (unavailable) scroll position, so the client finds it on screen. *)
selectionGeometry[ nb_NotebookObject ] := Module[ { raw, content },
    raw = Quiet @ FrontEndExecute @ FrontEnd`GetSelectionBoundingBoxes @ nb;
    If[ MatchQ[ raw, { { _? NumericQ, _? NumericQ }, { _? NumericQ, _? NumericQ } } ],
        content = contentRect @ nb;
        <|
            "Coordinates" -> "Document",
            "Rects"       -> shiftRects[ toRect /@ { raw }, 0, If[ AssociationQ @ content, content[ "left" ], 0 ] ]
        |>,
        <| "Coordinates" -> "Screen", "Rects" -> selectionRects @ nb |>
    ]
];

toRect[ { { x0_, y0_ }, { x1_, y1_ } } ] := <| "left" -> Min[ x0, x1 ], "top" -> Min[ y0, y1 ], "width" -> Abs[ x1 - x0 ], "height" -> Abs[ y1 - y0 ] |>;

(* The notebook's content area (below docked cells, excluding scroll bars) in screen points: *)
contentRect[ nb_NotebookObject ] := Replace[
    FirstCase[
        Quiet @ MathLink`CallFrontEnd @ FrontEnd`UndocumentedBoxInformationPacket[ nb, False ],
        HoldPattern[ FE`WindowRectangle -> r_ ] :> r,
        None,
        Infinity
    ],
    { { { l_? NumericQ, t_? NumericQ }, { r_? NumericQ, b_? NumericQ } } :> <| "left" -> l, "top" -> t, "width" -> r - l, "height" -> b - t |>, _ -> Null }
];


selectionRects[ nb_NotebookObject ] := Cases[
    Quiet @ FrontEndExecute @ FrontEnd`GetSelectionBoundingBoxes @ nb,
    { { x0_? NumericQ, y0_? NumericQ }, { x1_? NumericQ, y1_? NumericQ } } :>
        <| "left" -> Min[ x0, x1 ], "top" -> Min[ y0, y1 ], "width" -> Abs[ x1 - x0 ], "height" -> Abs[ y1 - y0 ] |>,
    { 0, Infinity }
];

shiftRects[ rects_List, dy_? NumericQ ] := shiftRects[ rects, dy, 0 ];
shiftRects[ rects_List, dy_? NumericQ, dx_? NumericQ ] := MapAt[ # + dx &, MapAt[ # + dy &, rects, { All, "top" } ], { All, "left" } ];
shiftRects[ rects_, ___ ] := rects;


(* On Linux, a notebook's menu bar is drawn inside its window, above the docked cells: *)
menuBarQ[ nb_NotebookObject ] := $OperatingSystem === "Unix" && MemberQ[ Quiet @ AbsoluteCurrentValue[ nb, WindowElements ], "MenuBar" ];

$menuBarHeight = 14.25; (* 19 px at 96 dpi *)


(* Selects the box with the given BoxID and returns where it was found. *)
selectBox[ nb_NotebookObject, id_String ] := selectBox[ nb, id, Automatic ];
selectBox[ nb_NotebookObject, id_String, scope_ ] := Module[ { found },
    found = findBoxObject[ nb, id, scope ];
    If[ ! AssociationQ @ found, commandError[ "BoxNotFound", boxNotFoundMessage @ id ] ];
    (* SelectionMove on the BoxObject would select the whole cell for attached and docked cells: *)
    Quiet @ MathLink`CallFrontEnd @ FrontEnd`BoxReferenceFind[
        FE`BoxReference[ nb, { { id } } ],
        FE`SearchStart -> found[ "Start" ],
        FE`SearchStop  -> found[ "Stop" ],
        AutoScroll     -> True
    ];
    found
];


(* Search the notebook first, then each docked and attached cell (recursively), since toolbars, sidebars, chat bars,
   and popups are docked/attached cells that a plain notebook search does not reach: *)
(* Optionally restricted to one kind of scope ("Notebook", "Docked", "Attached" or "Sidebar"), since some BoxIDs
   (e.g. the chat input field) exist in several places: *)
findBoxObject[ nb_NotebookObject, id_String, scope_String ] := Catch @ Module[ { box, cells },
    If[ scope === "Notebook",
        box = boxObjectIn[ nb, id, "StartFromBeginning", "StopAtEnd" ];
        If[ MatchQ[ box, _BoxObject ], Throw @ <| "Box" -> box, "Scope" -> "Notebook", "Start" -> "StartFromBeginning", "Stop" -> "StopAtEnd" |> ];
        Throw @ Missing[ "NotFound" ]
    ];
    cells = Switch[ scope,
        "Docked", Replace[ Quiet @ Cells[ nb, DockedCell -> True ], Except[ _List ] -> { } ],
        "Sidebar", sidebarCells @ nb,
        _, Complement[ allAttachedCells @ nb, sidebarCells @ nb ]
    ];
    Do[
        box = boxObjectIn[ nb, id, cell, cell ];
        If[ MatchQ[ box, _BoxObject ], Throw @ <| "Box" -> box, "Scope" -> scope, "Start" -> cell, "Stop" -> cell |> ],
        { cell, cells }
    ];
    Missing[ "NotFound" ]
];

findBoxObject[ nb_NotebookObject, id_String, Automatic | None ] := findBoxObject[ nb, id ];

findBoxObject[ nb_NotebookObject, id_String ] := Catch @ Module[ { box },
    box = boxObjectIn[ nb, id, "StartFromBeginning", "StopAtEnd" ];
    If[ MatchQ[ box, _BoxObject ], Throw @ <| "Box" -> box, "Scope" -> "Notebook", "Start" -> "StartFromBeginning", "Stop" -> "StopAtEnd" |> ];
    Do[
        box = boxObjectIn[ nb, id, cell, cell ];
        If[ MatchQ[ box, _BoxObject ], Throw @ <| "Box" -> box, "Scope" -> "Docked", "Start" -> cell, "Stop" -> cell |> ],
        { cell, Replace[ Quiet @ Cells[ nb, DockedCell -> True ], Except[ _List ] -> { } ] }
    ];
    Do[
        box = boxObjectIn[ nb, id, cell, cell ];
        If[ MatchQ[ box, _BoxObject ], Throw @ <| "Box" -> box, "Scope" -> attachedScope @ cell, "Start" -> cell, "Stop" -> cell |> ],
        { cell, allAttachedCells @ nb }
    ];
    Missing[ "NotFound" ]
];

boxObjectIn[ nb_, id_, start_, stop_ ] := Quiet @ MathLink`CallFrontEnd @ FrontEnd`BoxReferenceBoxObject[
    FE`BoxReference[ nb, { { id } } ],
    FE`SearchStart -> start,
    FE`SearchStop  -> stop
];


(* Attached cells (recursively), plus "sidebar" cells: the notebook assistant sidebar is not an attached cell itself,
   but it is the parent of an attached helper cell. Cells inside those (e.g. sidebar chat messages) are included too. *)
allAttachedCells[ nb_NotebookObject ] := Module[ { seen = { }, queue, regular, cellsOf },
    cellsOf = Replace[ Quiet @ Cells[ ##, AttachedCell -> True ], Except[ _List ] -> { } ] &;
    regular = Replace[ Quiet @ Cells @ nb, Except[ _List ] -> { } ];
    queue = Join[ cellsOf @ nb, Flatten[ cellsOf /@ Replace[ Quiet @ Cells[ nb, DockedCell -> True ], Except[ _List ] -> { } ] ] ];
    While[ queue =!= { },
        With[ { cell = First @ queue },
            queue = Rest @ queue;
            If[ MatchQ[ cell, _CellObject ] && ! MemberQ[ seen, cell ] && ! MemberQ[ regular, cell ],
                AppendTo[ seen, cell ];
                queue = Join[
                    queue,
                    cellsOf @ cell,
                    Replace[ Quiet @ Cells @ cell, Except[ _List ] -> { } ],
                    Cases[ { Quiet @ ParentCell @ cell }, _CellObject ]
                ]
            ]
        ]
    ];
    seen
];

(* Boxes in the sidebar are reported with x relative to the notebook's content area (to the right of the sidebar): *)
attachedScope[ cell_CellObject ] := If[ MemberQ[ sidebarCells @ ParentNotebook @ cell, cell ], "Sidebar", "Attached" ];

(* The notebook assistant sidebar cells and everything inside them: *)
sidebarCells[ nb_NotebookObject ] := Module[ { roots, all = { }, queue },
    roots = Select[ allAttachedCells @ nb, MemberQ[ Flatten @ { cellStyle @ # }, "NotebookAssistant`Sidebar`NotebookAssistantSidebarCell" ] & ];
    queue = roots;
    While[ queue =!= { },
        With[ { cell = First @ queue },
            queue = Rest @ queue;
            If[ ! MemberQ[ all, cell ],
                AppendTo[ all, cell ];
                queue = Join[ queue, Replace[ Quiet @ Cells @ cell, Except[ _List ] -> { } ], Replace[ Quiet @ Cells[ cell, AttachedCell -> True ], Except[ _List ] -> { } ] ]
            ]
        ]
    ];
    all
];


boxNotFoundMessage[ id_ ] :=
    "No box with BoxID " <> ToString[ id, InputForm ] <> " was found in the notebook or its docked/attached cells. " <>
    "Some controls only exist while hovering (use `move`) or while a chat is running, and BoxIDs that were added " <>
    "recently are only present with the development Chatbook.";


(* NotebookFind does not see text inside boxes such as TemplateBoxes (e.g. chat messages) or in docked/attached cells;
   in that case fall back to the cell whose text contains it, and locate the whole cell. *)
selectText[ nb_NotebookObject, text_String, n_Integer ] := Module[ { found, cell },
    SelectionMove[ nb, Before, Notebook, AutoScroll -> False ];
    Do[ found = NotebookFind[ nb, text, Next ], { Max[ n, 1 ] } ];
    If[ found =!= $Failed, Return @ <| "Scope" -> "Notebook", "Match" -> "Exact" |> ];
    cell = Select[ notebookCells @ nb, StringContainsQ[ cellText @ #, text ] & ];
    If[ Length @ cell < Max[ n, 1 ], commandError[ "TextNotFound", "Text " <> ToString[ text, InputForm ] <> " was not found." ] ];
    Append[ selectCell @ cell[[ Max[ n, 1 ] ]], "Match" -> "Cell" ]
];


(* Select a cell's contents and say where the cell lives (docked cells need a coordinate correction): *)
selectCell[ cell_CellObject ] := (
    SelectionMove[ cell, All, CellContents ];
    <| "Scope" -> Which[
        MemberQ[ Quiet @ Cells[ ParentNotebook @ cell, DockedCell -> True ], cell ], "Docked",
        MemberQ[ sidebarCells @ ParentNotebook @ cell, cell ], "Sidebar",
        MatchQ[ Quiet @ ParentCell @ cell, _CellObject ], "Attached",
        True, "Notebook"
    ] |>
);


(* ::Subsection::Closed:: *)
(*deselect*)


(* Collapse the selection that `locate` leaves behind (to an insertion point after the located cell): *)
$commands[ "deselect" ] = Function[ args,
    Module[ { nb = resolveNotebook @ Lookup[ args, "notebook", Automatic ] },
        Quiet @ SelectionMove[ nb, After, Cell, AutoScroll -> False ];
        <| "notebook" -> nb[[ 1 ]] |>
    ]
];


(* ::Subsection::Closed:: *)
(*focusCell*)


(* Put the insertion point at the end of a cell's contents and focus its window, so that typed keys go there: *)
$commands[ "focusCell" ] = Function[ args,
    Module[ { cell = resolveCell @ requireArg[ args, "cell" ], nb },
        nb = ParentNotebook @ cell;
        SetSelectedNotebook @ nb;
        SelectionMove[ cell, If[ boolArg[ args, "start", False ], Before, After ], CellContents ];
        <| "cell" -> cell[[ 1 ]], "notebook" -> nb[[ 1 ]], "title" -> Quiet @ AbsoluteCurrentValue[ nb, WindowTitle ] |>
    ]
];


(* ::Subsection::Closed:: *)
(*press*)


(* Activate a control (button, checkbox, ...) by BoxID through the front end, without synthesizing mouse input. *)
$commands[ "press" ] = Function[ args,
    Module[ { nb, box },
        nb  = resolveNotebook @ Lookup[ args, "notebook", Automatic ];
        box = findBoxObject[ nb, requireArg[ args, "boxID" ], Replace[ Lookup[ args, "scope", Automatic ], Except[ _String ] -> Automatic ] ];
        If[ ! AssociationQ @ box, commandError[ "BoxNotFound", boxNotFoundMessage @ args[ "boxID" ] ] ];
        <|
            "pressed"   -> args[ "boxID" ],
            "scope"     -> box[ "Scope" ],
            "triggered" -> TrueQ @ MathLink`CallFrontEnd @ FrontEnd`TriggerControlBoxObject @ box[ "Box" ]
        |>
    ]
];


(* ::Subsection::Closed:: *)
(*Messages window*)


$commands[ "messages" ] = Function[ args,
    Module[ { nb, cells, texts },
        nb    = MessagesNotebook[ ];
        cells = If[ MatchQ[ nb, _NotebookObject ], Cells @ nb, { } ];
        texts = <| "style" -> cellStyle @ #, "text" -> truncate[ cellText @ #, 2000 ] |> & /@ cells;
        If[ boolArg[ args, "clear", False ] && cells =!= { }, NotebookDelete @ cells ];
        texts
    ]
];


(* ::Subsection::Closed:: *)
(*Front end tokens, selection and windows*)


$commands[ "token" ] = Function[ args,
    Module[ { token, nb, param },
        token = requireArg[ args, "token" ];
        param = Lookup[ args, "parameter", Missing[ ] ];
        nb    = If[ KeyExistsQ[ args, "notebook" ], resolveNotebook @ args[ "notebook" ], Automatic ];
        Which[
            nb === Automatic && MissingQ @ param, FrontEndTokenExecute[ token ],
            nb === Automatic, FrontEndTokenExecute[ token, param ],
            MissingQ @ param, FrontEndTokenExecute[ nb, token ],
            True, FrontEndTokenExecute[ nb, token, param ]
        ];
        <| "token" -> token |>
    ]
];


$commands[ "select" ] = Function[ args,
    Module[ { nb = resolveNotebook @ requireArg[ args, "notebook" ] },
        SetSelectedNotebook @ nb;
        notebookSummary @ nb
    ]
];


$commands[ "close" ] = Function[ args,
    Module[ { nb = resolveNotebook @ requireArg[ args, "notebook" ] },
        If[ ! boolArg[ args, "save", False ], SetOptions[ nb, Saveable -> False ] ];
        NotebookClose @ nb;
        <| "closed" -> nb[[ 1 ]] |>
    ]
];


(* ::Subsection::Closed:: *)
(*Front end screenshots*)


(* Front end rendered images: a fallback for platforms where the client cannot capture the screen itself. *)
$commands[ "rasterize" ] = Function[ args,
    Module[ { target, image, file },
        target = Which[
            KeyExistsQ[ args, "cell" ], resolveCell @ args[ "cell" ],
            boolArg[ args, "screen", False ], Automatic,
            True, resolveNotebook @ Lookup[ args, "notebook", Automatic ]
        ];
        image = Switch[ target,
            Automatic, CurrentScreenImage[ ],
            _NotebookObject, CurrentNotebookImage @ target,
            _CellObject, Rasterize[ target, ImageResolution -> numArg[ args, "resolution", 144 ] ]
        ];
        If[ ! ImageQ @ image, commandError[ "RasterizeFailed", "Could not capture an image of the target." ] ];
        file = Replace[ Lookup[ args, "path", Automatic ], Except[ _String ] :> newImagePath[ "fe" ] ];
        If[ ! StringQ @ Quiet @ Export[ file, image, "PNG" ], commandError[ "ExportFailed", "Could not write " <> file <> "." ] ];
        <| "path" -> file, "width" -> ImageDimensions[ image ][[ 1 ]], "height" -> ImageDimensions[ image ][[ 2 ]] |>
    ]
];


(* ::Section::Closed:: *)
(*Reload Support*)


(* When this file is reloaded into a kernel with a running server, keep the listener compatible with this code: *)
If[ AssociationQ @ $FrontEndServer && MatchQ[ $FrontEndServer[ "Listener" ], _SocketListener ],
    Quiet @ SetOptions[ $FrontEndServer[ "Listener" ], RecordSeparators -> None ]
];

(* Process the events that arrived while this file was loading: *)
$reloading = False;
With[ { pending = $pendingEvents }, $pendingEvents = { }; Scan[ handleEvent, pending ] ];


(* ::Section::Closed:: *)
(*Package Footer*)


End[ ];
EndPackage[ ];
