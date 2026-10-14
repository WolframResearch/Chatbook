(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`Remote`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ACP`Common`" ];

(* One-shot remote operations of remote windows ("SSHSettings"; see docs/acp-window.md): the git checks, the Review
   window's change sets and the remote folder picker's listings each run one sh script on the remote machine, over one
   ssh connection of their own (acpRemoteRun). This file has the runner, the script templates (Assets/RemoteScripts),
   the READY handshake, the parser of the scripts' framed output (protocol ACPR1), the errors of one-shot runs, the
   folder listing (format ACPLS1) and the host failure latch.

   Rules:
   * Nothing blocks: ssh is started with StartProcess and polled from the pump (acpProcessRun, Git.wl). The runner
     writes only a short first line before the remote shell has answered it (the READY handshake), so no write can wait
     for ssh to sign in, whatever the pipe size. Never RunProcess (it can hang while an ACP reader is active).
   * One connection per operation, at most $acpRemoteMaxRuns at once per host; no persistent shell, no ControlMaster.
   * Remote output is bounded: caps on bytes, frames and records, incremental searches, and numbers are read with
     FromDigits after a digits check. Remote text is never ToExpression'd; names reach boxes only through
     acpRemoteDisplayName.
   * No secrets: the scripts hold no keys, and results and logs never hold a script or the standard error. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$acpRemoteTimeout        = 30;                                 (* seconds, the default of acpRemoteRun *)
$acpRemoteDeadlineSlack  = 10;                                 (* the remote watchdog fires at Ceiling[timeout] + this *)
$acpRemoteMaxScript      = 16384;                              (* bytes of a filled script (a sanity cap) *)
$acpRemoteMaxRuns        = 3;                                  (* one-shot runs at once per host (draining ones count) *)
$acpRemoteMaxOutput      = 64 * 2^20;                          (* bytes of standard output and error together *)
$acpRemoteMaxErrorKept   = 2^20;                               (* only the end of standard error is kept *)
$acpRemoteMaxBeforeReady = 65536;                              (* bytes of standard output before READY, else "NoReady" *)
$acpRemoteMaxFrames      = 16;                                 (* frames parsed (a full git script passes more) *)
$acpRemoteDrainTimeout   = 30;                                 (* seconds a run cancelled before READY may take to end *)
$acpRemoteLatchMemory    = 600;                                (* seconds an auth failure adds the penalty hint *)
$acpRemoteSlotRetry      = Quantity[ 250, "Milliseconds" ];    (* a Quantity: acpSchedule takes no plain numbers *)

(* The folder listing (list.sh): folders and other entries listed per class (hidden or not), entries looked at, and the
   cap of the listing frame *)
$acpRemoteListMaxFolders  = 1000;
$acpRemoteListMaxFiles    = 200;
$acpRemoteListScanFolders = 20000;
$acpRemoteListScanFiles   = 5000;
$acpRemoteListOutputCap   = 2^20;

(* The templates in Assets/RemoteScripts *)
$remoteTemplateNames = { "prelude", "git", "list" };

(* Error kinds that latch a host (B5.6), and those that also start the penalty memory *)
$latchingKinds = { "SSHAuthFailed", "SSHHostKeyUnknown", "SSHHostKeyChanged", "SSHBadArguments" };
$authKinds     = { "SSHAuthFailed", "SSHHostKeyUnknown", "SSHHostKeyChanged" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Stores*)

(* Kernel state, never persisted. Not reset if this file is reloaded during development:
     $remoteRuns                 process run ID (acpProcessRun) -> host key: the slots in use (a run holds its slot
                                 while it is in Git.wl's run table, also while it drains);
     $acpRemoteHostErrors        host key -> <| "Error" -> error info, "At" -> time |>: the latch;
     $acpRemoteHostAuthFailedAt  host key -> time of the last authentication or host key failure (not cleared by user
                                 actions: it decides the PerSourcePenalties hint). *)
If[ ! AssociationQ @ $remoteRuns               , $remoteRuns                = <| |> ];
If[ ! AssociationQ @ $acpRemoteHostErrors      , $acpRemoteHostErrors       = <| |> ];
If[ ! AssociationQ @ $acpRemoteHostAuthFailedAt, $acpRemoteHostAuthFailedAt = <| |> ];
If[ ! IntegerQ @ $remoteRequestCount           , $remoteRequestCount        = 0 ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Scripts*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteTemplate*)

(* A script template of Assets/RemoteScripts (<name>.sh): read once per session, CR removed (a Windows checkout without
   .gitattributes has CRLF, which dash rejects), minified. Values are inserted afterwards, never minified. *)
acpRemoteTemplate // beginDefinition;

acpRemoteTemplate[ name_String ] /; MemberQ[ $remoteTemplateNames, name ] := Enclose[
    Module[ { dir, file, text },
        dir  = ConfirmBy[ $thisPaclet[ "AssetLocation", "RemoteScripts" ], DirectoryQ, "Directory" ];
        file = ConfirmBy[ FileNameJoin @ { dir, name <> ".sh" }, FileExistsQ, "File" ];
        text = ConfirmBy[ remoteTemplateText @ readTextFile @ file, StringQ, "Text" ];
        acpRemoteTemplate[ name ] = text
    ],
    throwInternalFailure[ acpRemoteTemplate @ name, ## ] &
];

acpRemoteTemplate // endDefinition;


remoteTemplateText // beginDefinition;
remoteTemplateText[ text_String ] := acpRemoteMinify @ StringReplace[ text, { "\r\n" -> "\n", "\r" -> "\n" } ];
remoteTemplateText // endDefinition;


(* A file's text, read through a stream of its own (ReadByteArray[file] would reuse a stream that is already open for
   the file) *)
readTextFile // beginDefinition;

readTextFile[ file_String ] := Module[ { stream, bytes },
    stream = OpenRead[ file, BinaryFormat -> True ];
    If[ Head @ stream =!= InputStream, Return[ $Failed, Module ] ];
    bytes = WithCleanup[ ReadByteArray @ stream, Close @ stream ];
    If[ ByteArrayQ @ bytes, ByteArrayToString[ bytes, "UTF-8" ], "" ]
];

readTextFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteMinify*)

(* Drops full-line comments, empty lines and leading indentation. Only ever applied to templates: applied to a script
   with inserted values, it would also change lines inside a quoted value ("/srv/a\n  b" would become "/srv/a\nb", and a
   line starting with "#" would be dropped, leaving an unterminated quote). *)
acpRemoteMinify // beginDefinition;

acpRemoteMinify[ script_String ] := StringJoin @ Map[
    # <> "\n" &,
    Select[
        StringDelete[ StringSplit[ script, "\n" ], StartOfString ~~ (" " | "\t").. ],
        # =!= "" && ! StringStartsQ[ #, "#" ] &
    ]
];

acpRemoteMinify // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteScript*)

(* The parts of one run (the READY handshake):
     "Ready"  -> the first line written: it makes the remote shell print the READY marker as soon as ssh has signed in
                 and forwards standard input ("set +xv": an inherited SHELLOPTS must not trace the script);
     "Marker" -> the READY marker the runner waits for in the standard output;
     "Script" -> what is written then: the minified prelude with the nonce and the watchdog's deadline (filled by one
                 StringReplace, which never rescans what it inserted), a newline and the body.
   Failure["RemoteScriptTooLarge"] above $acpRemoteMaxScript bytes. *)
acpRemoteScript // beginDefinition;

acpRemoteScript[ nonce_String, deadline_Integer, body_String ] /; StringMatchQ[ nonce, RegularExpression[ "[0-9A-Za-z]+" ] ] :=
    Module[ { prelude, script },
        prelude = StringReplace[
            acpRemoteTemplate[ "prelude" ],
            { "@NONCE@" -> nonce, "@DEADLINE@" -> ToString @ Max[ deadline, 1 ] }
        ];
        script = StringToByteArray[ prelude <> "\n" <> body, "UTF-8" ];
        If[ Length @ script > $acpRemoteMaxScript,
            Failure[ "RemoteScriptTooLarge", <|
                "MessageTemplate"   -> "The remote script has `1` bytes, more than the `2` allowed.",
                "MessageParameters" -> { Length @ script, $acpRemoteMaxScript },
                "Bytes"             -> Length @ script
            |> ],
            <|
                "Ready"  -> StringToByteArray[ "set +xv; printf '\\n#ACPR1 " <> nonce <> " READY\\n'\n", "UTF-8" ],
                "Marker" -> StringToByteArray[ "#ACPR1 " <> nonce <> " READY\n", "UTF-8" ],
                "Script" -> script
            |>
        ]
    ];

acpRemoteScript[ _, _, _ ] := Failure[ "InvalidRemoteScript", <|
    "MessageTemplate"   -> "The remote script could not be made.",
    "MessageParameters" -> { }
|> ];

acpRemoteScript // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Running*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteRun*)

(* acpRemoteRun[ssh, body, continuation, opts] runs the sh script body (after the prelude) on the remote machine with
   one ssh connection ("exec /bin/sh -s"); gives a run ID. continuation[result] is evaluated (isolated) in the pump,
   always exactly once, with
     <| "Status"   -> "OK" | "SSHFailed" | "StartFailed" | "TimedOut" | "RemoteTimedOut" | "TooLarge" | "Cancelled"
                      | "Incomplete" | "NoReady" | "Latched",
        "Frames"   -> <| name -> <| "ExitCode", "Output", "OutputTruncated", "Error", "ErrorTruncated" |> |> (also the
                      complete frames of a run that was cut),
        "Stop"     -> the code of the script's early stop | None,
        "ExitCode" -> ssh's exit code | None,
        "Error"    -> None | the error info (acpErrorInfo, with "Actions" -> {}),
        "Host"     -> acpSSHHostLabel @ ssh,
        "Duration" -> seconds since the call |>
   ssh: the "SSHSettings" (canonical or not). body: the script (a Failure gives "StartFailed"). opts:
     "Timeout"   -> seconds ($acpRemoteTimeout) from the start of ssh (and for the wait for a slot);
     "MaxOutput" -> bytes ($acpRemoteMaxOutput);
     "MaxFrames" -> frames parsed ($acpRemoteMaxFrames);
     "Owner", "Request" -> as acpGitRun: the run is cancelled when the owner's window is gone or the request superseded
                    (before READY it is drained, not killed: see acpProcessRun's "CancelBeforeReady");
     "Automatic" -> True for runs Chatbook starts by itself (not after a click): they are refused while the host is
                    latched ("Latched", without a connection); other runs clear the host's latch first;
     "Label"     -> a name for the debug log.
   Steps: the latch; ssh (acpFindSSH); the script (acpRemoteScript); a slot of the host (else a retry after
   $acpRemoteSlotRetry, through the pump); acpProcessRun with the READY line as input, and the script as the input that
   waits for the READY marker. *)
acpRemoteRun // beginDefinition;

acpRemoteRun[ ssh_, body_, continuation_ ] := acpRemoteRun[ ssh, body, continuation, <| |> ];

acpRemoteRun[ ssh0_, body_, continuation_, opts_Association ] := Module[ { request, ssh, key, program, nonce, parts },
    request = <|
        "ID"           -> "remote-run-" <> ToString[ ++$remoteRequestCount ],
        "Continuation" -> continuation,
        "RequestedAt"  -> AbsoluteTime[ ],
        "Label"        -> Replace[ Lookup[ opts, "Label", None ], Except[ _String ] -> "Remote" ],
        "Owner"        -> Lookup[ opts, "Owner", None ],
        "Request"      -> Lookup[ opts, "Request", None ],
        "Timeout"      -> Replace[ Lookup[ opts, "Timeout", $acpRemoteTimeout ], Except[ _? Positive ] -> $acpRemoteTimeout ],
        "MaxOutput"    -> Replace[ Lookup[ opts, "MaxOutput", $acpRemoteMaxOutput ], Except[ _Integer? Positive ] -> $acpRemoteMaxOutput ],
        "MaxFrames"    -> Replace[ Lookup[ opts, "MaxFrames", $acpRemoteMaxFrames ], Except[ _Integer? Positive ] -> $acpRemoteMaxFrames ],
        "Automatic"    -> TrueQ @ Lookup[ opts, "Automatic", False ],
        "Host"         -> None
    |>;

    ssh = acpSSHSettings @ ssh0;
    If[ ! AssociationQ @ ssh, Return[ remoteEndEarly[ request, "StartFailed", invalidSettingsError @ ssh ], Module ] ];
    key     = acpSSHHostKey @ ssh;
    request = <| request, "SSH" -> ssh, "HostKey" -> key, "Host" -> acpSSHHostLabel @ ssh |>;

    (* The host failure latch: automatic runs make no connection while it is set; any other run clears it *)
    If[ request[ "Automatic" ],
        If[ acpRemoteHostLatchedQ @ key, Return[ remoteEndEarly[ request, "Latched", latchedError @ key ], Module ] ],
        acpRemoteClearHostError @ key
    ];

    program = acpFindSSH @ ssh;
    If[ ! StringQ @ program, Return[ remoteEndEarly[ request, "StartFailed", oneShotError @ acpErrorInfo @ program ], Module ] ];

    nonce = StringDelete[ CreateUUID[ ], "-" ];
    parts = If[ StringQ @ body,
        acpRemoteScript[ nonce, Ceiling @ request[ "Timeout" ] + $acpRemoteDeadlineSlack, body ],
        body
    ];
    If[ ! AssociationQ @ parts,
        Return[ remoteEndEarly[ request, "StartFailed", remoteError[ "RemoteScriptFailed", request, <| "HintKey" -> None |> ] ], Module ]
    ];

    remoteStart @ <| request, "Program" -> program, "Nonce" -> nonce, "Parts" -> parts |>;
    request[ "ID" ]
];

acpRemoteRun // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*remoteStart*)

(* Starts ssh if the host has a free slot (checked and taken under PreemptProtect); otherwise tries again after
   $acpRemoteSlotRetry, through the pump (no queue, no ScheduledTask). A run that waits is cancelled or times out
   without a connection. *)
remoteStart // beginDefinition;

remoteStart[ request_Association ] := Module[ { started },
    If[ acpRunCancelledQ[ request[ "Owner" ], request[ "Request" ] ],
        Return[ remoteEndEarly[ request, "Cancelled", None ], Module ]
    ];
    started = PreemptProtect @ If[ remoteSlotsInUse @ request[ "HostKey" ] < $acpRemoteMaxRuns,
        With[ { id = remoteStartProcess @ request }, $remoteRuns[ id ] = request[ "HostKey" ] ];
        True,
        False
    ];
    Which[
        started,
            Null,
        AbsoluteTime[ ] - request[ "RequestedAt" ] > request[ "Timeout" ],
            remoteEndEarly[ request, "TimedOut", remoteError[ "RemoteOperationTimedOut", request, <| |> ] ],
        True,
            With[ { r = request }, acpSchedule[ remoteStart @ r, $acpRemoteSlotRetry ] ]
    ]
];

remoteStart // endDefinition;


remoteStartProcess // beginDefinition;

remoteStartProcess[ request_Association ] := With[ { parts = request[ "Parts" ] },
    acpProcessRun[
        acpSSHCommand[ <| request[ "SSH" ], "Program" -> request[ "Program" ] |>, $acpSSHScriptCommand ],
        $HomeDirectory,
        remoteDone[ request, # ] &,
        <|
            "Timeout"           -> request[ "Timeout" ],
            "MaxOutput"         -> request[ "MaxOutput" ],
            "Owner"             -> request[ "Owner" ],
            "Request"           -> request[ "Request" ],
            "Environment"       -> acpSSHEnvironment[ ],
            "Input"             -> parts[ "Ready" ],
            "InputAfter"        -> <| "Marker" -> parts[ "Marker" ], "Bytes" -> parts[ "Script" ], "Limit" -> $acpRemoteMaxBeforeReady |>,
            "Decode"            -> False,
            "ErrorKeep"         -> $acpRemoteMaxErrorKept,
            "CancelBeforeReady" -> "Drain",
            "DrainTimeout"      -> $acpRemoteDrainTimeout,
            "Arguments"         -> { "ssh", request[ "Host" ] }
        |>
    ]
];

remoteStartProcess // endDefinition;


(* The slots of a host that are in use: its runs that are still running or draining *)
remoteSlotsInUse // beginDefinition;

remoteSlotsInUse[ key_ ] := (
    remoteReleaseSlots[ ];
    Count[ Values @ $remoteRuns, key ]
);

remoteSlotsInUse // endDefinition;


remoteReleaseSlots // beginDefinition;
remoteReleaseSlots[ ] := PreemptProtect[ $remoteRuns = KeySelect[ $remoteRuns, acpProcessRunningQ ] ];
remoteReleaseSlots // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*remoteDone*)

(* The end of a run (the continuation of acpProcessRun, in the pump): releases the slots of runs that are gone (a run
   that drains keeps its slot until it is gone), updates the host's latch, logs, and calls the continuation *)
remoteDone // beginDefinition;

remoteDone[ request_Association, raw_Association ] := Module[ { parsed, result },
    remoteReleaseSlots[ ];
    parsed = remoteParse[ raw, request[ "Nonce" ], request[ "MaxFrames" ] ];
    result = <|
        remoteResult[ raw, parsed, request[ "SSH" ] ],
        "Duration" -> AbsoluteTime[ ] - request[ "RequestedAt" ]
    |>;
    Which[
        TrueQ @ parsed[ "Begun" ], acpRemoteClearHostError @ request[ "HostKey" ],
        AssociationQ @ result[ "Error" ], acpRemoteNoteHostError[ request[ "HostKey" ], result[ "Error" ] ]
    ];
    remoteFinish[ request, result ]
];

remoteDone // endDefinition;


(* A run that ends without ssh (latched, not started, cancelled or timed out while waiting): its continuation runs in the
   pump, as always *)
remoteEndEarly // beginDefinition;

remoteEndEarly[ request_Association, status_String, error_ ] := With[
    {
        r = request,
        result = <|
            "Status"   -> status,
            "Frames"   -> <| |>,
            "Stop"     -> None,
            "ExitCode" -> None,
            "Error"    -> error,
            "Host"     -> request[ "Host" ],
            "Duration" -> AbsoluteTime[ ] - request[ "RequestedAt" ]
        |>
    },
    acpSchedule @ remoteFinish[ r, result ];
    request[ "ID" ]
];

remoteEndEarly // endDefinition;


remoteFinish // beginDefinition;

remoteFinish[ request_Association, result_Association ] := (
    acpLog[ "RemoteRun", <|
        "Label"    -> request[ "Label" ],
        "Status"   -> result[ "Status" ],
        "Code"     -> Replace[ result[ "Error" ], { e_Association :> Lookup[ e, "Code", None ], _ -> None } ],
        "ExitCode" -> result[ "ExitCode" ],
        "Seconds"  -> result[ "Duration" ]
    |> ];
    acpIsolated @ request[ "Continuation" ][ result ];
    Null
);

remoteFinish // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteResult*)

(* The result of a run (see acpRemoteRun) from the result of acpProcessRun (raw: "Output" and "Error" are ByteArrays),
   the run's nonce, the canonical SSH settings and the frame cap. Status, in order: StartFailed, Cancelled, TooLarge,
   NoReady, TimedOut (the local timeout), OK (the END marker was read), SSHFailed (no BEGIN marker: ssh, the sign-in or
   the login shell failed, nothing ran), RemoteTimedOut (exit code 143: the remote watchdog), Incomplete. *)
acpRemoteResult // beginDefinition;

acpRemoteResult[ raw_Association, nonce_String, ssh_Association, maxFrames_Integer ] :=
    remoteResult[ raw, remoteParse[ raw, nonce, maxFrames ], ssh ];

acpRemoteResult // endDefinition;


remoteParse // beginDefinition;

(* A run that never got its script (not started, no READY) has nothing to parse *)
remoteParse[ raw_Association, nonce_String, maxFrames_Integer ] := Replace[
    Lookup[ raw, "Output", None ],
    {
        bytes_ByteArray /; ! TrueQ[ raw[ "StartFailed" ] || Lookup[ raw, "NoReady", False ] ] :>
            acpRemoteParseFrames[ bytes, nonce, maxFrames ],
        _ :>
            remoteParsed[ False, False, <| |>, None, False, False ]
    }
];

remoteParse // endDefinition;


remoteResult // beginDefinition;

remoteResult[ raw_Association, parsed_Association, ssh_Association ] := Module[ { status },
    status = Which[
        TrueQ @ raw[ "StartFailed" ]              , "StartFailed",
        TrueQ @ raw[ "Cancelled" ]                , "Cancelled",
        TrueQ @ raw[ "TooLarge" ]                 , "TooLarge",
        TrueQ @ Lookup[ raw, "NoReady", False ]   , "NoReady",
        TrueQ @ raw[ "TimedOut" ]                 , "TimedOut",
        TrueQ @ parsed[ "Complete" ]              , "OK",
        ! TrueQ @ parsed[ "Begun" ]               , "SSHFailed",
        raw[ "ExitCode" ] === 143                 , "RemoteTimedOut",
        True                                      , "Incomplete"
    ];
    <|
        "Status"   -> status,
        "Frames"   -> parsed[ "Frames" ],
        "Stop"     -> parsed[ "Stop" ],
        "ExitCode" -> raw[ "ExitCode" ],
        "Error"    -> acpRemoteErrorInfo[ raw, parsed, status, ssh ],
        "Host"     -> acpSSHHostLabel @ ssh,
        "Duration" -> Lookup[ raw, "Duration", 0 ]
    |>
];

remoteResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteErrorInfo*)

(* The error of a run that did not end with its END marker: the error info of acpErrorInfo (Connection.wl), with
   "Actions" -> {} (the callers add their own buttons). None for "OK" and "Cancelled".
     no BEGIN, exit 255 (or none)       ssh's own failure: acpSSHExitError (SSHHostKeyUnknown, SSHAuthFailed, ...)
     no BEGIN, another exit code        RemoteScriptFailed (no /bin/sh, a forced command, a restricted shell)
     "NoReady"                          RemoteScriptFailed with the advice about a noisy login shell
     BEGIN, no END, exit 255 or none    SSHConnectionLost
     BEGIN, no END, exit 143            RemoteOperationTimedOut (the remote watchdog)
     BEGIN, no END, another exit code   RemoteScriptFailed without advice (the script's output was cut or malformed)
     local timeout after BEGIN          RemoteOperationTimedOut
     local timeout before BEGIN         SSHConnectTimeout (with ssh's text so far)
     ssh could not be started           SSHStartFailed
     too much output                    RemoteScriptFailed without advice
   "Output" is the end of ssh's standard error, cleaned as for connection errors (acpSSHExitError: no debug lines, no
   lines that name secrets, neutralized). *)
acpRemoteErrorInfo // beginDefinition;

acpRemoteErrorInfo[ raw_Association, parsed_Association, status_String, ssh_Association ] := Module[
    { stderr, exit, begun, context },
    stderr  = Replace[ Lookup[ raw, "Error", "" ], Except[ _ByteArray | _String ] -> "" ];
    exit    = Replace[ Lookup[ raw, "ExitCode", None ], Except[ _Integer ] -> None ];
    begun   = TrueQ @ parsed[ "Begun" ];
    context = remoteErrorContext @ ssh;
    oneShotError @ Switch[ status,
        "OK" | "Cancelled",
            None,
        "StartFailed",
            acpErrorInfo[ "SSHStartFailed", None, None, context ],
        "NoReady",
            remoteKindError[ "RemoteScriptFailed", <| context, "HintKey" -> "ErrorRemoteNoisyShellDetail" |>, stderr ],
        "TooLarge",
            remoteKindError[ "RemoteScriptFailed", <| context, "HintKey" -> None |>, stderr ],
        "TimedOut",
            If[ begun,
                acpErrorInfo[ "RemoteOperationTimedOut", None, None, context ],
                acpSSHTimeoutError[ stderr, context ]
            ],
        "SSHFailed",
            If[ IntegerQ @ exit && exit =!= 255,
                remoteKindError[ "RemoteScriptFailed", <| context, "ExitCode" -> exit |>, stderr ],
                acpSSHExitError[ 255, stderr, context ]
            ],
        "RemoteTimedOut",
            acpErrorInfo[ "RemoteOperationTimedOut", None, None, <| context, "ExitCode" -> exit |> ],
        "Incomplete",
            If[ exit === None || exit === 255,
                remoteKindError[ "SSHConnectionLost", <| context, "ExitCode" -> exit |>, stderr ],
                remoteKindError[ "RemoteScriptFailed", <| context, "ExitCode" -> exit, "HintKey" -> None |>, stderr ]
            ],
        _,
            None
    ]
];

acpRemoteErrorInfo // endDefinition;


(* The context of a one-shot run's errors: the host, the terminal command (the host key advice), and whether the host
   refused a sign-in recently (the PerSourcePenalties advice) *)
remoteErrorContext // beginDefinition;

remoteErrorContext[ ssh_Association ] := <|
    "Setup"             -> True,
    "SSH"               -> ssh,
    "Host"              -> acpSSHHostLabel @ ssh,
    "Command"           -> acpSSHTerminalCommand @ ssh,
    "RecentAuthFailure" -> acpRemoteRecentAuthFailureQ @ acpSSHHostKey @ ssh
|>;

remoteErrorContext // endDefinition;


(* An error of the kind with the cleaned end of standard error as its "Output" *)
remoteKindError // beginDefinition;

remoteKindError[ kind_String, context_Association, stderr_ ] :=
    acpErrorInfo[ kind, None, None, <| context, "Output" -> remoteStderrOutput[ stderr, context ] |> ];

remoteKindError // endDefinition;


(* The cleaned end of ssh's standard error (as acpSSHExitError gives it for connection errors) *)
remoteStderrOutput // beginDefinition;
remoteStderrOutput[ stderr_, context_Association ] := Lookup[ acpSSHExitError[ 255, stderr, context ], "Output", None ];
remoteStderrOutput // endDefinition;


(* An error of a run that has no raw result (not started) *)
remoteError // beginDefinition;

remoteError[ kind_String, request_Association, extra_Association ] := oneShotError @ acpErrorInfo[
    kind,
    None,
    None,
    <| If[ AssociationQ @ request[ "SSH" ], remoteErrorContext @ request[ "SSH" ], <| |> ], extra |>
];

remoteError // endDefinition;


(* Settings that are not valid remote settings (a Failure of acpSSHSettings, or None: local) *)
invalidSettingsError // beginDefinition;
invalidSettingsError[ failure_Failure ] := oneShotError @ acpErrorInfo @ failure;
invalidSettingsError[ _ ] := oneShotError @ acpErrorInfo[ "InvalidSSHSettings", None, None, <| |> ];
invalidSettingsError // endDefinition;


oneShotError // beginDefinition;
oneShotError[ error_Association ] := <| error, "Actions" -> { } |>;
oneShotError[ None ] := None;
oneShotError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Framed output*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteParseFrames*)

(* The standard output of a run (protocol ACPR1):
     <anything: login-shell noise, the READY line; ignored>
     \n#ACPR1 <nonce> BEGIN\n
     { record }
     #ACPR1 <nonce> END\n                   (absent if the script died, was killed or the stream was cut)
     record := "F " name " " exit " " olen " " otrunc " " elen " " etrunc "\n" <olen bytes> <elen bytes> "\n"
             | "S " code "\n"               (the script stopped early: the last record, END follows)
   Gives <| "Begun", "Complete", "Frames" -> <| name -> <| "ExitCode" -> _Integer | None, "Output" -> ByteArray,
   "OutputTruncated", "Error" -> ByteArray, "ErrorTruncated" |> |>, "Stop" -> code | None,
   "Malformed" -> False | "Record" | "TooManyFrames", "Cut" |>. A cut stream keeps its complete frames; the first frame
   of a name is kept.
   Bounded work: the BEGIN marker is searched for in the first MB only, each record line is unpacked from a window of at
   most 512 bytes and its data taken with Take (linear in the number of records), parsing stops after maxFrames frames
   ("TooManyFrames"), and an S record must be followed by END (anything else is "Record"), so the loop reads at most
   maxFrames + 2 records whatever the remote prints. The S record does not count toward maxFrames: a run with exactly
   maxFrames frames may still stop. Numbers are read with FromDigits after the record line matched its pattern. *)
acpRemoteParseFrames // beginDefinition;

acpRemoteParseFrames[ bytes_ByteArray, nonce_String ] := acpRemoteParseFrames[ bytes, nonce, $acpRemoteMaxFrames ];

acpRemoteParseFrames[ bytes_ByteArray, nonce_String, maxFrames_Integer ] := Module[
    { n, begin, pos, frames, count, stop, complete, malformed, cut, endLine, window, nl, line, parts, ol, el },
    n         = Length @ bytes;
    frames    = <| |>;
    count     = 0;
    stop      = None;
    complete  = False;
    malformed = False;
    cut       = False;
    endLine   = "#ACPR1 " <> nonce <> " END";
    (* A byte search: 10 ms for a MB of noise, where converting it to a string and searching that takes 70 ms *)
    begin     = SequencePosition[ Normal @ Take[ bytes, UpTo[ 2^20 ] ], ToCharacterCode[ "\n#ACPR1 " <> nonce <> " BEGIN\n" ], 1 ];
    If[ begin === { }, Return[ remoteParsed[ False, False, frames, None, False, False ], Module ] ];
    pos = begin[[ 1, 2 ]] + 1;
    While[ True,
        If[ pos > n, cut = True; Break[ ] ];
        window = Normal @ Take[ bytes, { pos, Min[ n, pos + 511 ] } ];
        nl     = FirstPosition[ window, 10, None, { 1 } ];
        If[ nl === None, If[ Length @ window < 512, cut = True, malformed = "Record" ]; Break[ ] ];
        line = FromCharacterCode @ Take[ window, nl[[ 1 ]] - 1 ];
        pos += nl[[ 1 ]];
        Which[
            line === endLine,
                complete = True;
                Break[ ],
            (* cb_stop prints END right after its S record: anything else after it is not the script's *)
            stop =!= None,
                malformed = "Record";
                Break[ ],
            StringMatchQ[ line, RegularExpression[ "S [A-Za-z0-9._-]+" ] ],
                stop = StringDrop[ line, 2 ],
            StringMatchQ[ line, RegularExpression[ "F [A-Za-z0-9._-]+ (-|[0-9]+) [0-9]+ [01] [0-9]+ [01]" ] ],
                If[ ++count > maxFrames, malformed = "TooManyFrames"; Break[ ] ];
                parts = StringSplit @ line;
                { ol, el } = FromDigits /@ parts[[ { 4, 6 } ]];
                If[ pos + ol + el > n, cut = True; Break[ ] ];
                If[ bytes[[ pos + ol + el ]] =!= 10, malformed = "Record"; Break[ ] ];
                If[ ! KeyExistsQ[ frames, parts[[ 2 ]] ],
                    frames[ parts[[ 2 ]] ] = <|
                        "ExitCode"        -> If[ parts[[ 3 ]] === "-", None, FromDigits @ parts[[ 3 ]] ],
                        "Output"          -> takeBytes[ bytes, pos, ol ],
                        "OutputTruncated" -> parts[[ 5 ]] === "1",
                        "Error"           -> takeBytes[ bytes, pos + ol, el ],
                        "ErrorTruncated"  -> parts[[ 7 ]] === "1"
                    |>
                ];
                pos += ol + el + 1,
            True,
                malformed = "Record";
                Break[ ]
        ]
    ];
    remoteParsed[ True, complete, frames, stop, malformed, cut ]
];

acpRemoteParseFrames // endDefinition;


remoteParsed // beginDefinition;

remoteParsed[ begun_, complete_, frames_, stop_, malformed_, cut_ ] := <|
    "Begun"     -> begun,
    "Complete"  -> complete,
    "Frames"    -> frames,
    "Stop"      -> stop,
    "Malformed" -> malformed,
    "Cut"       -> cut
|>;

remoteParsed // endDefinition;


(* len bytes from position a *)
takeBytes // beginDefinition;
takeBytes[ bytes_ByteArray, a_Integer, len_Integer ] := If[ len > 0, Take[ bytes, { a, a + len - 1 } ], ByteArray[ { } ] ];
takeBytes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Folder listing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteListBody*)

(* The body of one folder listing (list.sh's cb_ls, in a frame named "list"): lnonce marks the start of the listing,
   path is the folder ("~", "~/...", absolute, or relative to base; None: the remote home), and with fallback the
   nearest folder above it that can be opened is listed if it can't be. Every value is a single-quoted word. A Failure if
   a value can't be quoted (a NUL character). *)
acpRemoteListBody // beginDefinition;

acpRemoteListBody[ lnonce_String, path_String, base: _String | None, fallback_ ] := Module[ { words },
    words = acpShellQuote /@ { lnonce, path, Replace[ base, None -> "" ] };
    If[ ! AllTrue[ words, StringQ ], Return[ FirstCase[ words, _Failure ], Module ] ];
    StringJoin[
        acpRemoteTemplate[ "list" ],
        "\ncb_run list ", ToString @ $acpRemoteListOutputCap, " 4096 cb_ls ",
        StringRiffle[ words, " " ], " ",
        StringRiffle[
            ToString /@ {
                $acpRemoteListMaxFolders,
                $acpRemoteListMaxFiles,
                $acpRemoteListScanFolders,
                $acpRemoteListScanFiles,
                If[ TrueQ @ fallback, 1, 0 ]
            },
            " "
        ],
        "\ncb_end\n"
    ]
];

acpRemoteListBody // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteListingParse*)

(* A folder listing (the output of the "list" frame), from its first field "v:1:<lnonce>" on (anything before it, e.g.
   text from the remote shell's startup files, is ignored). Fields are NUL-terminated "tag:value" (see list.sh). Gives
     <| "Status" -> "OK" | "Missing" | "NotFolder" | "NoAccess" | "Unreadable" | "BadPath" | "Malformed",
        "RequestedStatus" (of the requested folder), "Fallback" -> the folder listed instead | None,
        "Warning" -> "Unlisted" | None, "Home", "Requested", "Path", "RealPath",
        "Entries" -> { <| "Name", "Kind" -> "Folder" | "File" | "Other" | "BrokenLink", "Link", "Locked", "Hidden",
                          "Usable" |> ... } (in the script's order),
        "Counts" -> <| "Folders", "HiddenFolders", "Files", "HiddenFiles" |> | None,
        "Capped" -> <| "Folders" -> n | None, "Files" -> n | None |>, "Complete" |>
   A listing without its end field "e:" is "Malformed". Names and paths are UTF-8 if they are valid UTF-8, else
   Missing["Undecodable", latin1] (an entry with such a name has its Latin-1 text and is not "Usable"; nor is a name that
   no folder can have, such as one with "/").
   The script's caps hold only for an honest remote, so they are enforced here too: at most $acpRemoteListOutputCap
   bytes are read, at most a listing's worth of fields, at most $acpRemoteListMaxFolders folders and
   $acpRemoteListMaxFiles other entries per class (hidden or not); a path longer than $acpRemoteMaxPathLength makes the
   listing "Malformed"; the home folder is kept only if it is an absolute path without control characters
   (acpRemoteCheckedPath; "RemoteValueRejected" is logged otherwise). *)
acpRemoteListingParse // beginDefinition;

acpRemoteListingParse[ bytes_ByteArray, lnonce_String ] := Module[ { text, start, fields },
    text  = ByteArrayToString[ Take[ bytes, UpTo[ $acpRemoteListOutputCap ] ], "ISOLatin1" ];
    start = StringPosition[ text, "v:1:" <> lnonce <> "\000", 1 ];
    If[ start === { }, Return[ listingResult @ <| |>, Module ] ];
    fields = Most @ StringSplit[ StringDrop[ text, start[[ 1, 2 ]] ], "\000", All ];
    If[ Length @ fields > listingMaxFields[ ], Return[ listingResult @ <| |>, Module ] ];
    listingResult @ listingFields @ fields
];

acpRemoteListingParse[ _, _ ] := listingResult @ <| |>;

acpRemoteListingParse // endDefinition;


(* The most fields an honest listing has: its entries, a fallback field pair per level of the deepest path, and the
   rest *)
listingMaxFields // beginDefinition;
listingMaxFields[ ] := 2 * ($acpRemoteListMaxFolders + $acpRemoteListMaxFiles) + $acpRemoteMaxPathLength + 64;
listingMaxFields // endDefinition;


$listingStatuses = <|
    "ok"         -> "OK",
    "missing"    -> "Missing",
    "notdir"     -> "NotFolder",
    "access"     -> "NoAccess",
    "unreadable" -> "Unreadable",
    "badpath"    -> "BadPath"
|>;


(* The keys of the path fields *)
$listingPathKeys = <| "q" -> "Requested", "p" -> "Path", "r" -> "RealPath", "a" -> "Fallback" |>;


(* The values of the fields: the entries (at most the caps of each class, in order) and the other fields (in order; a
   later field of a tag replaces an earlier one, except for the first status, "RequestedStatus"; a path longer than
   $acpRemoteMaxPathLength sets "TooLong"). The fields are split and decoded as lists (a listing has up to 2,400
   entries: 0.02 s, where one field at a time takes 0.13 s). *)
listingFields // beginDefinition;

listingFields[ fields_List ] := Module[ { colonQ, tags, raw, entryQ, values, tag, value },
    colonQ = StringContainsQ[ fields, ":" ];
    tags   = MapThread[ If[ #2, #1, "" ] &, { StringReplace[ fields, RegularExpression[ "(?s)^([^:]*):.*$" ] -> "$1" ], colonQ } ];
    raw    = MapThread[ If[ #2, #1, "" ] &, { StringReplace[ fields, RegularExpression[ "^[^:]*:" ] -> "", 1 ], colonQ } ];
    entryQ = StringMatchQ[ tags, RegularExpression[ "[dfob]l?x?" ] ];
    values = <| "TooLong" -> False |>;
    Do[
        { tag, value } = field;
        Switch[ tag,
            "h",
                values[ "Home" ] = value,
            "q" | "p" | "r" | "a",
                If[ StringLength @ remoteText @ value > $acpRemoteMaxPathLength, values[ "TooLong" ] = True ];
                values[ $listingPathKeys[ tag ] ] = value,
            "s",
                values[ "Status" ] = Lookup[ $listingStatuses, Replace[ value, Except[ _String ] -> "" ], "Malformed" ];
                If[ ! KeyExistsQ[ values, "RequestedStatus" ], values[ "RequestedStatus" ] = values[ "Status" ] ],
            "w",
                If[ value === "unlisted", values[ "Warning" ] = "Unlisted" ],
            "c",
                values[ "Counts" ] = listingCounts @ value,
            "xd",
                values[ "CappedFolders" ] = listingNumber @ value,
            "xf",
                values[ "CappedFiles" ] = listingNumber @ value,
            "e",
                values[ "Complete" ] = True,
            _,
                Null
        ],
        { field, Transpose @ { Pick[ tags, entryQ, False ], remoteDecodeList @ Pick[ raw, entryQ, False ] } }
    ];
    <| values, "Entries" -> listingEntries[ Pick[ tags, entryQ ], Pick[ raw, entryQ ] ] |>
];

listingFields // endDefinition;


(* The entries: at most $acpRemoteListMaxFolders folders and $acpRemoteListMaxFiles other entries of each class (hidden
   or not), in the script's order. "Usable": the name can be put into a path (valid UTF-8, and a name a folder entry can
   have). Computed list by list (2,400 entries: 0.01 s). *)
listingEntries // beginDefinition;

listingEntries[ { }, _ ] := { };

listingEntries[ tags0_List, raw_List ] := Module[ { names, texts, hidden, classes, keep, tags },
    names   = remoteDecodeList @ raw;
    texts   = remoteText /@ names;
    hidden  = StringStartsQ[ texts, "." ];
    classes = 2 * Boole[ StringStartsQ[ tags0, "d" ] ] + Boole @ hidden;
    keep    = Sort @ Catenate @ KeyValueMap[
        Take[ #2, UpTo @ If[ #1 >= 2, $acpRemoteListMaxFolders, $acpRemoteListMaxFiles ] ] &,
        PositionIndex @ classes
    ];
    tags = tags0[[ keep ]];
    MapThread[
        <| "Name" -> #1, "Kind" -> #2, "Link" -> #3, "Locked" -> #4, "Hidden" -> #5, "Usable" -> #6 |> &,
        {
            texts[[ keep ]],
            Lookup[ $listingKinds, StringTake[ tags, 1 ] ],
            MapThread[ Or, { StringContainsQ[ tags, "l" ], StringStartsQ[ tags, "b" ] } ],
            StringEndsQ[ tags, "x" ],
            hidden[[ keep ]],
            usableNamesQ @ names[[ keep ]]
        }
    ]
];

listingEntries // endDefinition;


$listingKinds = <| "d" -> "Folder", "f" -> "File", "o" -> "Other", "b" -> "BrokenLink" |>;


(* For each name: whether it is a string (valid UTF-8) other than "", "." and "..", without "/" *)
usableNamesQ // beginDefinition;

usableNamesQ[ names_List ] := With[ { strings = Replace[ names, Except[ _String ] -> "/", { 1 } ] },
    MapThread[ #1 && ! #2 &, { StringFreeQ[ strings, "/" ], StringMatchQ[ strings, RegularExpression[ "\\.{0,2}" ] ] } ]
];

usableNamesQ // endDefinition;


listingCounts // beginDefinition;

listingCounts[ s_String ] /; StringMatchQ[ s, RegularExpression[ "[0-9]{1,18} [0-9]{1,18} [0-9]{1,18} [0-9]{1,18}" ] ] :=
    AssociationThread[ { "Folders", "HiddenFolders", "Files", "HiddenFiles" } -> FromDigits /@ StringSplit @ s ];

listingCounts[ _ ] := None;

listingCounts // endDefinition;


listingNumber // beginDefinition;
listingNumber[ s_String ] /; StringMatchQ[ s, RegularExpression[ "[0-9]{1,18}" ] ] := FromDigits @ s;
listingNumber[ _ ] := None;
listingNumber // endDefinition;



listingResult // beginDefinition;

listingResult[ values_Association ] := Module[ { complete, status },
    complete = TrueQ @ Lookup[ values, "Complete", False ];
    status   = If[ complete && ! TrueQ @ Lookup[ values, "TooLong", False ], Lookup[ values, "Status", "Malformed" ], "Malformed" ];
    <|
        "Status"          -> status,
        "RequestedStatus" -> Lookup[ values, "RequestedStatus", None ],
        "Fallback"        -> Lookup[ values, "Fallback", None ],
        "Warning"         -> Lookup[ values, "Warning", None ],
        "Home"            -> listingHome @ Lookup[ values, "Home", None ],
        "Requested"       -> Lookup[ values, "Requested", None ],
        "Path"            -> Lookup[ values, "Path", None ],
        "RealPath"        -> Lookup[ values, "RealPath", None ],
        "Entries"         -> Lookup[ values, "Entries", { } ],
        "Counts"          -> Lookup[ values, "Counts", None ],
        "Capped"          -> <| "Folders" -> Lookup[ values, "CappedFolders", None ], "Files" -> Lookup[ values, "CappedFiles", None ] |>,
        "Complete"        -> complete
    |>
];

listingResult // endDefinition;


(* The remote home folder of a listing: kept only if it is an absolute path without control characters (V6) *)
listingHome // beginDefinition;
listingHome[ None ] := None;
listingHome[ home_String ] := acpRemoteCheckedPath[ home, "Home" ];
listingHome[ _ ] := (acpLog[ "RemoteValueRejected", <| "Key" -> "Home" |> ]; None);
listingHome // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*remoteDecode*)

(* Text from the remote machine (given as a string of ISO 8859-1 characters, one per byte): ASCII as it is; otherwise
   UTF-8 if the bytes encode back to the same bytes (ByteArrayToString[_, "UTF-8"] does not fail on invalid input: it
   decodes those bytes as ISO 8859-1, with a message); else Missing["Undecodable", latin1]. *)
remoteDecode // beginDefinition;

remoteDecode[ latin1_String ] /; StringMatchQ[ latin1, RegularExpression[ "[\\x00-\\x7f]*" ] ] := latin1;

remoteDecode[ latin1_String ] := With[ { bytes = StringToByteArray[ latin1, "ISOLatin1" ] },
    With[ { utf8 = Quiet @ ByteArrayToString[ bytes, "UTF-8" ] },
        If[ StringQ @ utf8 && Quiet @ StringToByteArray[ utf8, "UTF-8" ] === bytes, utf8, Missing[ "Undecodable", latin1 ] ]
    ]
];

remoteDecode // endDefinition;


(* remoteDecode of a list: the ASCII strings (most of them) are found with one test of the whole list *)
remoteDecodeList // beginDefinition;

remoteDecodeList[ { } ] := { };

remoteDecodeList[ list: { __String } ] := MapThread[
    If[ #2, #1, remoteDecode @ #1 ] &,
    { list, StringMatchQ[ list, RegularExpression[ "[\\x00-\\x7f]*" ] ] }
];

remoteDecodeList // endDefinition;


remoteText // beginDefinition;
remoteText[ s_String ] := s;
remoteText[ Missing[ _, s_String ] ] := s;
remoteText[ _ ] := "";
remoteText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Host failure latch*)

(* sshd's PerSourcePenalties (OpenSSH 9.8 and later) refuse a client for up to 10 minutes after failed sign-ins: 5 s
   of penalty per failed authentication, 1 s per connection closed before it, enforced from 15 s. With one connection
   per operation, a wrong key would reach that quickly. So after an authentication, host key or bad arguments failure,
   the host is latched: automatic runs (git checks, the picker's first listing) make no connection until a user action
   clears it (acpRemoteClearHostError), or a run reaches its script or the agent's launch reaches the agent. Kernel state
   only (safe in reader handlers). *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteNoteHostError*)

(* Notes the error of a run or of the agent's ssh for the host: a latching kind latches it (the error is kept, to be
   given to the automatic runs it refuses); an authentication or host key failure is also remembered for the
   PerSourcePenalties hint. None (a run that reached its script) clears the latch. *)
acpRemoteNoteHostError // beginDefinition;

acpRemoteNoteHostError[ key_String, error_Association ] := With[ { kind = Lookup[ error, "Code", None ], now = AbsoluteTime[ ] },
    If[ MemberQ[ $latchingKinds, kind ], PreemptProtect[ $acpRemoteHostErrors[ key ] = <| "Error" -> error, "At" -> now |> ] ];
    If[ MemberQ[ $authKinds, kind ], PreemptProtect[ $acpRemoteHostAuthFailedAt[ key ] = now ] ];
    Null
];

acpRemoteNoteHostError[ key_, None ] := acpRemoteClearHostError @ key;

acpRemoteNoteHostError[ _, _ ] := Null;

acpRemoteNoteHostError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteClearHostError*)

(* Clears the host's latch: user actions (Reconnect, the picker's clicks, the Review window, changed settings) and runs
   that got through *)
acpRemoteClearHostError // beginDefinition;
acpRemoteClearHostError[ key_String ] := (PreemptProtect @ KeyDropFrom[ $acpRemoteHostErrors, key ]; Null);
acpRemoteClearHostError[ _ ] := Null;
acpRemoteClearHostError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteHostLatchedQ*)
acpRemoteHostLatchedQ // beginDefinition;
acpRemoteHostLatchedQ[ key_String ] := KeyExistsQ[ $acpRemoteHostErrors, key ];
acpRemoteHostLatchedQ[ _ ] := False;
acpRemoteHostLatchedQ // endDefinition;


(* The error a latched host gives automatic runs *)
latchedError // beginDefinition;
latchedError[ key_String ] := oneShotError @ Lookup[ Lookup[ $acpRemoteHostErrors, key, <| |> ], "Error", None ];
latchedError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteRecentAuthFailureQ*)

(* Whether the host refused a sign-in (authentication or host key) within $acpRemoteLatchMemory seconds: then a server
   that can't be reached may be enforcing its penalties (ErrorSSHPenaltyDetail) *)
acpRemoteRecentAuthFailureQ // beginDefinition;

acpRemoteRecentAuthFailureQ[ key_String ] := With[ { time = Lookup[ $acpRemoteHostAuthFailedAt, key, None ] },
    NumericQ @ time && AbsoluteTime[ ] - time < $acpRemoteLatchMemory
];

acpRemoteRecentAuthFailureQ[ _ ] := False;

acpRemoteRecentAuthFailureQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
(* The templates are read into the MX file; if that fails, they are read when they are first used *)
addToMXInitialization[
    Quiet @ Catch[ acpRemoteTemplate /@ $remoteTemplateNames, _ ];
];

End[ ];
EndPackage[ ];
