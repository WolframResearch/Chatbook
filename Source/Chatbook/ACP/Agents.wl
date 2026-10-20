(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`Agents`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ACP`Common`" ];

(* Agent registry and configuration (see docs/acp-window.md, "Files"): executable discovery, OpenCode config injection, LLMKit key
   discovery, model preferences, billing labels and persisted preferences.

   Secrets: the LLMKit API key (and the full list of the user's Wolfram API keys that is read to find it) is only ever
   held in local variables and in the per-session cache below. It is never logged, printed, stored in window records,
   notebook TaggingRules or front end options, and never passed to code that can throw an internal failure (internal
   failures capture the evaluation stack). The key reaches the agent only through the LLMKIT_API_KEY environment
   variable (for a remote agent: exported by the launch script, which is sent over ssh's standard input, never on a
   command line); the injected OpenCode config refers to it as {env:LLMKIT_API_KEY}. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$acpPreferencesPath   = { PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "ACP" };
$openCodeInstallURL   = "https://opencode.ai";
$openCodeConfigSchema = "https://opencode.ai/config.json";
$llmKitBaseURL        = "https://services.wolfram.com/api/llmkit/v1";
$wolframKeysURL       = "https://services.wolfram.com/wolfram-keys/currentUser/";
$llmKitGrant          = "LLMKitAPIs";
$llmKitKeyName        = "Chatbook ACP access to LLMKit";
$llmKitKeyDescription = "API key for Chatbook agent chats (ACP) to access Wolfram LLMKit";
$llmKitRequestTimeout = 5; (* seconds; the lookup runs (once per session) in the scheduled connect task, so keep it short *)

(* Model preference after the agent's own default (which may be deprecated, e.g. opencode/exo-free): *)
$fallbackModels = { "llmkit/gpt-5.4", "openai/gpt-6.1-sol" };

(* LLMKit chat models for the injected OpenCode provider. Embedding and image models and gpt-5.2-codex (which fails on
   /chat/completions) are deliberately excluded; "limit" is required by OpenCode for some of them (the gpt-4o models). *)
$llmKitModels = <|
    "gpt-5.4"      -> <| "name" -> "GPT-5.4"     , "tool_call" -> True, "limit" -> <| "context" -> 1050000, "output" -> 128000 |> |>,
    "gpt-5.4-mini" -> <| "name" -> "GPT-5.4 mini", "tool_call" -> True, "limit" -> <| "context" -> 400000 , "output" -> 128000 |> |>,
    "gpt-5.4-nano" -> <| "name" -> "GPT-5.4 nano", "tool_call" -> True, "limit" -> <| "context" -> 400000 , "output" -> 128000 |> |>,
    "gpt-5.2"      -> <| "name" -> "GPT-5.2"     , "tool_call" -> True, "limit" -> <| "context" -> 400000 , "output" -> 128000 |> |>,
    "gpt-5-mini"   -> <| "name" -> "GPT-5 mini"  , "tool_call" -> True, "limit" -> <| "context" -> 400000 , "output" -> 128000 |> |>,
    "gpt-5-nano"   -> <| "name" -> "GPT-5 nano"  , "tool_call" -> True, "limit" -> <| "context" -> 400000 , "output" -> 128000 |> |>,
    "gpt-4.1"      -> <| "name" -> "GPT-4.1"     , "tool_call" -> True, "limit" -> <| "context" -> 1047576, "output" -> 32768  |> |>,
    "gpt-4.1-mini" -> <| "name" -> "GPT-4.1 mini", "tool_call" -> True, "limit" -> <| "context" -> 1047576, "output" -> 32768  |> |>,
    "gpt-4.1-nano" -> <| "name" -> "GPT-4.1 nano", "tool_call" -> True, "limit" -> <| "context" -> 1047576, "output" -> 32768  |> |>,
    "gpt-4o"       -> <| "name" -> "GPT-4o"      , "tool_call" -> True, "limit" -> <| "context" -> 128000 , "output" -> 16384  |> |>,
    "gpt-4o-mini"  -> <| "name" -> "GPT-4o mini" , "tool_call" -> True, "limit" -> <| "context" -> 128000 , "output" -> 16384  |> |>
|>;

(* Set to False to never look for (or create) an LLMKit key, e.g. in tests. *)
If[ ! BooleanQ @ $acpLLMKitEnabled, $acpLLMKitEnabled = True ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Strings*)

(* English text for every user-visible string of Agents.wl and Connection.wl. acpConnectionLabel never makes front end
   calls, so it is safe in reader handlers. *)
$acpConnectionStrings = <|
    (* Errors *)
    "ErrorACPLinkMissing"          -> "Agent chats need the ACPLink paclet, which is not installed.",
    "ErrorACPLinkTooOld"           -> "The installed ACPLink paclet is too old for agent chats. Please update it.",
    "ErrorUnknownAgent"            -> "Unknown agent: `agent`.",
    "ErrorAgentNotFound"           -> "`agent` was not found on this computer.",
    "ErrorAgentNotFoundDetail"     -> "Install it from `url`, or give its command line with the \"ACPAgentCommandLine\" setting.",
    "ErrorAgentNotFoundPath"       -> "`path` was not found.",
    "ErrorConnectFailed"           -> "Couldn't start `agent`.",
    "ErrorInitFailed"              -> "`agent` didn't accept the connection.",
    "ErrorTimeout"                 -> "`agent` didn't respond in time.",
    "ErrorSessionFailed"           -> "`agent` couldn't start a chat session.",
    "ErrorAgentExited"             -> "`agent` stopped unexpectedly.",
    "ErrorAgentExitedDetail"       -> "Exit code: `code`.",
    "ErrorNotConnected"            -> "`agent` is not connected.",
    "ErrorSendFailed"              -> "The message couldn't be sent to `agent`.",
    "ErrorModelUnavailable"        -> "The model `model` isn't available.",
    "ErrorModelUnavailableGeneric" -> "The selected model isn't available.",
    "ErrorAuthRequired"            -> "`agent` needs you to sign in to the model provider: run \"opencode auth login\" in a terminal, then reconnect.",
    "ErrorNoModels"                -> "`agent` has no models available: sign in to a provider with \"opencode auth login\" in a terminal, then reconnect.",
    "ErrorProviderError"           -> "The model provider reported an error.",
    "ErrorServerUnavailable"       -> "The `agent` server is not available.",
    "ErrorAgent"                   -> "`agent` reported an error.",

    (* Errors of remote windows (SSH.wl): `host` is the host label, `path` a folder on it, `command` the ssh command for
       a terminal, `url` the agent's install URL, `example` the path of the agent on the host *)
    "ErrorSSHNotFound"                -> "The ssh program was not found on this computer.",
    "ErrorSSHNotFoundDetail"          -> "Install the OpenSSH client, or give the path of ssh with \"Executable\" in the \"SSHSettings\" setting.",
    "ErrorSSHNotFoundDetailWindows"   -> "Install the OpenSSH Client (type Optional features in the Start menu search, then add OpenSSH Client), or give the path of ssh.exe with \"Executable\" in the \"SSHSettings\" setting.",
    "ErrorSSHNotFoundPath"            -> "`path` was not found or is not executable on this computer.",
    "ErrorSSHNotFoundPathDetail"      -> "Check \"Executable\" in the \"SSHSettings\" setting: it must be the path or the name of the ssh program on this computer (Automatic finds ssh).",
    "ErrorSSHStartFailed"             -> "Couldn't start ssh.",
    "ErrorSSHHostKeyUnknown"          -> "`host` is not a known host yet.",
    "ErrorSSHHostKeyUnknownDetail"    -> "Connect to it once in a terminal with `command`, check that the host key fingerprint is the server's and accept it, then reconnect. Agent chats always check host keys: if your ssh configuration turns host key checking off for this host (StrictHostKeyChecking no, UserKnownHostsFile /dev/null), keep its key in your known_hosts file instead.",
    "ErrorSSHHostKeyChanged"          -> "The host key of `host` has changed.",
    "ErrorSSHHostKeyChangedDetail"    -> "This can mean that someone is intercepting the connection, or that the server was reinstalled. Check the new key with the server's administrator before you change your known_hosts file.",
    "ErrorSSHAuthFailed"              -> "`host` didn't accept your SSH key.",
    "ErrorSSHAuthFailedDetail"        -> "Agent chats sign in without prompts: use a key that is loaded in your SSH agent or has no passphrase, and give its file with \"Arguments\" -> {\"-i\", \"path\"} in the \"SSHSettings\" setting if it is not a default key.",
    "ErrorSSHKeyPermissionsDetail"    -> "ssh ignores the key file because other users can read it. Restrict its permissions to your user account.",
    "ErrorSSHKeyMissingDetail"        -> "ssh couldn't find the key file given with \"-i\".",
    "ErrorSSHHostNotFound"            -> "The host `host` was not found.",
    "ErrorSSHHostNotFoundDetail"      -> "Check \"MachineName\" in the \"SSHSettings\" setting and your network connection.",
    "ErrorSSHConnectionRefused"       -> "`host` refused the connection.",
    "ErrorSSHConnectionRefusedDetail" -> "Check that its SSH server is running and that the port is right (for another port: \"Arguments\" -> {\"-p\", \"<port>\"}).",
    "ErrorSSHUnreachable"             -> "Couldn't reach `host`.",
    "ErrorSSHPenaltyDetail"           -> "After failed sign-ins, the server may refuse connections from this computer for a while. Wait a minute, then reconnect.",
    "ErrorSSHConnectTimeout"          -> "Connecting to `host` took too long.",
    "ErrorSSHBadArguments"            -> "ssh didn't accept the \"Arguments\" of the \"SSHSettings\" setting.",
    "ErrorSSHConnectionLost"          -> "The connection to `host` was lost.",
    "ErrorSSHFailed"                  -> "Couldn't connect to `host` with ssh.",
    "ErrorRemoteFolderMissing"        -> "The folder `path` doesn't exist on `host`.",
    "ErrorRemoteFolderAccess"         -> "The folder `path` on `host` can't be opened.",
    "ErrorRemoteAgentNotFound"        -> "`agent` was not found on `host`.",
    "ErrorRemoteAgentNotFoundDetail"  -> "Install it there (`url`), or give its path on `host` with the \"ACPAgentCommandLine\" setting, for example {\"`example`\", \"acp\"}.",
    "ErrorRemoteAgentExited"          -> "`agent` on `host` stopped unexpectedly.",
    "ErrorRemoteAgentSignalDetail"    -> "It may have been stopped by the system, for example because `host` ran out of memory.",
    "ErrorRemoteTimeout"              -> "`agent` on `host` didn't respond in time.",
    "ErrorRemoteScriptFailed"         -> "The command on `host` could not run.",
    "ErrorRemoteScriptFailedDetail"   -> "The account's login shell on `host` did not run the command (for example a shell that refuses logins, a restricted shell, or a forced command). Check that `host` gives this user a normal shell.",
    "ErrorRemoteNoisyShellDetail"     -> "The login shell on `host` printed too much text before the command started. Check the startup files (such as .bashrc) of the remote account.",
    "ErrorRemoteOperationTimedOut"    -> "The operation on `host` took too long.",
    "ErrorInvalidSSHSettings"         -> "The \"SSHSettings\" of this window are not valid.",
    "ErrorInvalidRemoteCommand"       -> "`agent` can't be started on another computer.",
    "ErrorAuthRequiredRemote"         -> "`agent` on `host` needs you to sign in to the model provider.",
    "ErrorAuthRequiredRemoteDetail"   -> "The sign-in runs on `host`: connect with `command` in a terminal, run \"opencode auth login\" there, then reconnect.",
    "ErrorNoModelsRemote"             -> "`agent` on `host` has no models available.",
    "ErrorNoModelsRemoteDetail"       -> "Sign in to a provider on `host`: connect with `command` in a terminal, run \"opencode auth login\" there, then reconnect.",

    (* Notices (shown above the input field) *)
    "NoticeBackgroundPermission"   -> "A background subagent asked for permission after the turn ended; the request was cancelled.",
    "NoticeSessionNotResumed"      -> "New session: `agent` doesn't remember the messages above.",
    "NoticeConfigOptionFailed"     -> "Couldn't change `option`: `message`",
    "NoticeSessionLoadFailed"      -> "Couldn't open the session: `message`",
    "NoticeSessionLoadUnsupported" -> "`agent` can't open saved sessions, so a new session was started.",

    (* Sessions window (Sessions.wl) *)
    "SessionsListFailed"           -> "Couldn't list the sessions: `message`",
    "SessionsDeleteFailed"         -> "Couldn't delete the session: `message`",

    (* Billing labels for models *)
    "BillingLLMKit"                -> "Wolfram LLMKit",
    "BillingOpenAI"                -> "OpenAI (your account)",
    "BillingAnthropic"             -> "Anthropic (your account)",
    "BillingGoogle"                -> "Google (your account)",
    "BillingOpenCodeFree"          -> "OpenCode (free)",
    "BillingOpenCodeZen"           -> "OpenCode Zen"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpConnectionLabel*)
acpConnectionLabel // beginDefinition;

acpConnectionLabel[ key_String ] := Replace[ Lookup[ $acpConnectionStrings, key, key ], Except[ _String ] -> key ];

acpConnectionLabel[ key_String, params_Association ] := Replace[
    Quiet @ TemplateApply[ StringTemplate @ acpConnectionLabel @ key, params ],
    Except[ _String ] :> acpConnectionLabel @ key
];

acpConnectionLabel[ key_, ___ ] := ToString @ key;

acpConnectionLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Agent Registry*)

(* An agent is described by:
     "Name"        -> display name
     "Executable"  -> its program: a path or a command name (found by acpFindProgram), a command list {program, args...},
                      or a function of the window settings that gives a path (or a Failure["AgentNotFound", ...])
     "Arguments"   -> its command line arguments
     "Environment" -> process environment: Inherited or an association (may be a RuleDelayed; evaluated only right
                      before the agent is started)
     "Variables"   -> the agent's own variables (an association; may be a RuleDelayed, evaluated only right before the
                      agent is started), which the launch script of a remote window exports (sent over ssh's standard
                      input, never on a command line); a local agent gets them through "Environment". Optional.
     "BillingLabel"-> a function of the model value giving the billing label
   The window setting "ACPAgentCommandLine" (see acpCommandLineSetting) replaces the program (the agent's "Arguments"
   are kept) or the whole command line. *)
If[ ! AssociationQ @ $acpAgents, $acpAgents = <| |> ];

$acpAgents[ "OpenCode" ] = <|
    "Name"         -> "OpenCode",
    "Executable"   -> "opencode",
    "Arguments"    -> { "acp" },
    "Environment"  :> acpOpenCodeEnvironment[ ],
    "Variables"    :> acpOpenCodeVariables @ acpLLMKitAPIKey[ ],
    "BillingLabel" -> acpBillingLabel,
    "InstallURL"   -> $openCodeInstallURL
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpAgentSpec*)

(* acpAgentSpec[name, settings] gives <| "Name", "Command" -> {program, args...}, "Environment" :> env, "Directory",
   "Remote" |> or a Failure ("UnknownAgent", "AgentNotFound"; for remote windows also "InvalidSSHSettings",
   "SSHNotFound", "InvalidRemoteCommand"). The program is an absolute path (acpFindProgram). The environment is left
   unevaluated (RuleDelayed): it may contain secrets and is only evaluated by the code that starts the agent.
   "Directory" -> Automatic (the project folder) and "Remote" -> None for local agents; with "SSHSettings" see
   remoteAgentSpec. acpAgentSpec[name, settings, env] looks programs up in env (see acpFindProgram; used by tests). *)
acpAgentSpec // beginDefinition;

acpAgentSpec[ name_String ] := acpAgentSpec[ name, <| |> ];

acpAgentSpec[ name_String, settings_Association ] := acpAgentSpec[ name, settings, acpProgramEnvironment[ ] ];

acpAgentSpec[ name_String, settings_Association, env_Association ] := Catch @ Module[ { agent, display, ssh, command },
    agent = Lookup[ $acpAgents, name, Missing[ "UnknownAgent" ] ];
    If[ ! AssociationQ @ agent,
        Throw @ Failure[ "UnknownAgent", <|
            "MessageTemplate"   -> acpConnectionLabel[ "ErrorUnknownAgent", <| "agent" -> name |> ],
            "MessageParameters" -> { },
            "Agent"             -> name
        |> ]
    ];
    display = Replace[ Lookup[ agent, "Name", name ], Except[ _String ] -> name ];
    ssh     = acpSettingsSSH @ settings;
    If[ ssh =!= None, Throw @ remoteAgentSpec[ agent, display, ssh, settings, env ] ];
    command = Replace[
        acpCommandLineSetting @ settings,
        {
            { "Program", program_ }                   :> extendCommand[ programCommand[ program, agent, display, env ], agentArguments @ agent ],
            { "CommandLine", { program_, rest___ } } :> extendCommand[ programCommand[ program, agent, display, env ], { rest } ],
            _                                         :> extendCommand[ agentCommand[ agent, display, settings, env ], agentArguments @ agent ]
        }
    ];
    If[ FailureQ @ command, Throw @ command ];
    If[ ! MatchQ[ command, { __String } ], Throw @ agentNotFound[ display, None, Lookup[ agent, "InstallURL", None ] ] ];
    With[ { a = agent },
        <|
            "Name"        -> display,
            "Command"     -> command,
            "Environment" :> Lookup[ a, "Environment", Inherited ],
            "Directory"   -> Automatic,
            "Remote"      -> None
        |>
    ]
];

acpAgentSpec // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*remoteAgentSpec*)

(* The agent of a remote window (ssh is acpSettingsSSH of the settings: canonical, or a Failure). The command is the
   local ssh (acpSSHCommand) running the read bootstrap $acpSSHLaunchCommand in the local home folder, with ssh's
   environment (acpSSHEnvironment); the launch script (Connection.wl, from "Remote" and "Variables") is sent over ssh's
   standard input. "Remote" holds no secrets: the host, its key, the canonical settings, the agent's command line on the
   remote machine (no local lookup: the launch script finds the program there) and its install URL. "Variables" (the
   LLMKit key) stays unevaluated until the agent is started. *)
remoteAgentSpec // beginDefinition;

remoteAgentSpec[ agent_Association, display_String, ssh_Failure, _, _ ] := Failure[ "InvalidSSHSettings", <|
    "Detail" -> Replace[ Lookup[ Last @ ssh, "Detail", None ], Except[ _String ] -> None ],
    "Agent"  -> display
|> ];

remoteAgentSpec[ agent_Association, display_String, ssh_Association, settings_Association, env_Association ] :=
    Catch @ Module[ { program, command, url },
        url     = Lookup[ agent, "InstallURL", None ];
        program = acpFindSSH[ ssh, env ];
        If[ FailureQ @ program, Throw @ Failure[ First @ program, <| Last @ program, "Agent" -> display |> ] ];
        command = remoteAgentCommand[ agent, display, settings ];
        If[ FailureQ @ command, Throw @ command ];
        If[ ! acpRemoteCommandLineQ @ command, Throw @ invalidRemoteCommand @ display ];
        With[ { a = agent },
            <|
                "Name"        -> display,
                "Command"     -> acpSSHCommand[ <| ssh, "Program" -> program |>, $acpSSHLaunchCommand ],
                "Environment" :> acpSSHEnvironment[ ],
                "Directory"   -> $HomeDirectory,
                "Remote"      -> <|
                    "Host"         -> acpSSHHostLabel @ ssh,
                    "HostKey"      -> acpSSHHostKey @ ssh,
                    "SSH"          -> ssh,
                    "AgentCommand" -> command,
                    "InstallURL"   -> url
                |>,
                "Variables"   :> Replace[ Lookup[ a, "Variables", <| |> ], Except[ _Association ] -> <| |> ]
            |>
        ]
    ];

remoteAgentSpec // endDefinition;


(* The agent's command line on the remote machine, from the "ACPAgentCommandLine" setting or the registry, without any
   local lookup: {program, args...}, or a Failure for an agent whose program is found by a function (only on this
   computer) *)
remoteAgentCommand // beginDefinition;

remoteAgentCommand[ agent_Association, display_, settings_Association ] := Replace[
    acpCommandLineSetting @ settings,
    {
        { "Program", program_String }                  :> Join[ { program }, agentArguments @ agent ],
        { "CommandLine", { program_String, rest___ } } :> { program, rest },
        _ :> Replace[
            Lookup[ agent, "Executable", None ],
            {
                program_String                     :> Join[ { program }, agentArguments @ agent ],
                File[ program_String ]             :> Join[ { program }, agentArguments @ agent ],
                { program_String, rest___String }  :> Join[ { program, rest }, agentArguments @ agent ],
                _                                  :> invalidRemoteCommand @ display
            }
        ]
    }
];

remoteAgentCommand // endDefinition;


invalidRemoteCommand // beginDefinition;

invalidRemoteCommand[ display_ ] := Failure[ "InvalidRemoteCommand", <|
    "MessageTemplate"   -> acpConnectionLabel[ "ErrorInvalidRemoteCommand", <| "agent" -> display |> ],
    "MessageParameters" -> { },
    "Agent"             -> display
|> ];

invalidRemoteCommand // endDefinition;


(* A command followed by more arguments (evaluated only if the command is not a Failure) *)
extendCommand // beginDefinition;
extendCommand // Attributes = { HoldRest };
extendCommand[ failure_? FailureQ, _ ] := failure;
extendCommand[ command_List, args_ ] := Join[ command, Replace[ args, Except[ _List ] -> { } ] ];
extendCommand // endDefinition;


(* The registry's "Arguments" of an agent (evaluated only when they are used: they may be a RuleDelayed) *)
agentArguments // beginDefinition;
agentArguments[ agent_Association ] := Replace[ Lookup[ agent, "Arguments", { } ], Except[ { ___String } ] -> { } ];
agentArguments // endDefinition;


(* The start of the agent's own command line (without its "Arguments"), from the registry's "Executable", or a
   Failure["AgentNotFound", ...] *)
agentCommand // beginDefinition;

agentCommand[ agent_Association, display_, settings_, env_ ] := Replace[
    Lookup[ agent, "Executable", None ],
    {
        program: _String | File[ _String ] :> programCommand[ program, agent, display, env ],
        { program_String, rest___String }  :> extendCommand[ programCommand[ program, agent, display, env ], { rest } ],
        None                               :> agentNotFound[ display, None, Lookup[ agent, "InstallURL", None ] ],
        f_                                 :> Replace[
            f @ settings,
            {
                path_String        :> { path },
                failure_? FailureQ :> failure,
                _                  :> agentNotFound[ display, None, Lookup[ agent, "InstallURL", None ] ]
            }
        ]
    }
];

agentCommand // endDefinition;


(* { absolute path of the program }, or a Failure["AgentNotFound", ...]. A program given explicitly (by
   "ACPAgentCommandLine") is named in the error; the registry's default program is not (the error then suggests
   installing the agent). *)
programCommand // beginDefinition;

programCommand[ File[ program_String ], rest___ ] := programCommand[ program, rest ];

programCommand[ program_String, agent_Association, display_, env_Association ] := Replace[
    acpFindProgram[ program, env ],
    {
        path_String :> { path },
        None        :> agentNotFound[
            display,
            If[ program === Lookup[ agent, "Executable", None ], None, program ],
            Lookup[ agent, "InstallURL", None ]
        ]
    }
];

programCommand // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpCommandLineSetting*)

(* The "ACPAgentCommandLine" window setting:
     Automatic                            -> None: the agent's own command line;
     "program" or File["program"]         -> { "Program", program }: that program, with the agent's arguments (a string
                                             is a program, as in RunProcess, not a command line to split; and the agent's
                                             arguments are kept, so that the "Locate OpenCode..." file or a path to
                                             opencode just works);
     { program, args... }                 -> { "CommandLine", { program, args... } }: exactly this command line, as in
                                             RunProcess (the agent's arguments are not added).
   A program is a path or a command name (see acpFindProgram). Anything else counts as Automatic
   (ShowNotebookAssistance rejects it). *)
acpCommandLineSetting // beginDefinition;

acpCommandLineSetting[ settings_Association ] := acpCommandLineSetting @ Lookup[ settings, "ACPAgentCommandLine", Automatic ];
acpCommandLineSetting[ File[ program_String ] ] := acpCommandLineSetting @ program;
acpCommandLineSetting[ program_String ] /; StringLength @ StringTrim @ program > 0 := { "Program", StringTrim @ program };
acpCommandLineSetting[ { File[ program_String ], args___String } ] := acpCommandLineSetting @ { program, args };
acpCommandLineSetting[ { program_String, args___String } ] /; StringLength @ StringTrim @ program > 0 :=
    { "CommandLine", { StringTrim @ program, args } };
acpCommandLineSetting[ _ ] := None;

acpCommandLineSetting // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpOwnAgentCommandQ*)

(* Whether the window settings run the agent's own program (name: the registry's name), which gets the window's
   environment (e.g. OPENCODE_CONFIG_CONTENT with its "ask" rules): the registry's command line, a program (with the
   agent's arguments: the "Locate OpenCode..." file, a path to opencode), or a whole command line whose program has the
   name of the registry's program (e.g. {"/opt/oc/bin/opencode", "acp", "--print-logs"}). Not a command line that runs
   another program, such as docker, env, ssh or a wrapper script, which may not pass the environment on. Pure (the MCP
   server's handler uses it through MCP.wl's acpMCPEnabledQ). *)
acpOwnAgentCommandQ // beginDefinition;

acpOwnAgentCommandQ[ name_, settings_Association ] := Replace[
    acpCommandLineSetting @ settings,
    {
        None | { "Program", _ }                    -> True,
        { "CommandLine", { program_String, ___ } } :> agentProgramQ[ Lookup[ $acpAgents, name, <| |> ], program ],
        _                                          -> False
    }
];

acpOwnAgentCommandQ // endDefinition;


(* Whether a program (a path or a command name) has the name of the agent's program: the same file name without its
   extension (opencode, /usr/local/bin/opencode, opencode.cmd), in any case on Windows. False for an agent whose
   program is found by a function. *)
agentProgramQ // beginDefinition;

agentProgramQ[ agent_Association, program_String ] := With[
    {
        own = Replace[
            Lookup[ agent, "Executable", None ],
            { p_String | File[ p_String ] | { p_String, ___ } :> FileBaseName @ p, _ -> None }
        ]
    },
    StringQ @ own && If[ $OperatingSystem === "Windows",
        ToLowerCase @ FileBaseName @ program === ToLowerCase @ own,
        FileBaseName @ program === own
    ]
];

agentProgramQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFindProgram*)

(* acpFindProgram[program, env] gives the absolute path of a program, or None:
     * a path (with a directory part, or starting with ~): that file, if it exists (relative paths are relative to the
       kernel's current directory);
     * a command name: the first match in the directories of env["PATH"], then in the usual install directories in the
       home directory (the OpenCode installer's ~/.opencode/bin, then ~/.local/bin, ~/.bun/bin, ~/.npm-global/bin), then
       in the usual system directories (Homebrew, /usr/local/bin: a front end started from the macOS Dock gives the
       kernel a minimal PATH without them). On Windows a name without an extension also matches name.exe and name.cmd.
   env: <| "PATH", "HomeDirectory", "OperatingSystem", "SystemDirectories" |>, acpProgramEnvironment[ ] for the kernel's
   (tests pass their own; "SystemDirectories" defaults to none there). No RunProcess (RunProcess can hang while an ACP
   reader is active). *)
acpFindProgram // beginDefinition;

acpFindProgram[ program_String ] := acpFindProgram[ program, acpProgramEnvironment[ ] ];

acpFindProgram[ program_String, env_Association ] := Module[ { windowsQ, names, dirs, home },
    windowsQ = Lookup[ env, "OperatingSystem", $OperatingSystem ] === "Windows";
    If[ programPathQ[ program, windowsQ ],
        Return[ With[ { path = Quiet @ ExpandFileName @ program }, If[ acpExecutableFileQ @ path, path, None ] ], Module ]
    ];
    names = If[ windowsQ && FileExtension @ program === "", { program <> ".exe", program <> ".cmd", program }, { program } ];
    dirs  = acpPathDirectories[ Lookup[ env, "PATH", None ], windowsQ ];
    home  = Lookup[ env, "HomeDirectory", None ];
    If[ StringQ @ home,
        dirs = Join[ dirs, FileNameJoin @ Prepend[ #, home ] & /@ If[ windowsQ, { { ".opencode", "bin" } }, $acpProgramHomeDirectories ] ]
    ];
    If[ ! windowsQ, dirs = Join[ dirs, Select[ Replace[ Lookup[ env, "SystemDirectories", { } ], Except[ _List ] -> { } ], StringQ ] ] ];
    SelectFirst[ Flatten @ Outer[ FileNameJoin @ { #1, #2 } &, dirs, names ], acpExecutableFileQ, None ]
];

acpFindProgram[ _, _ ] := None;

acpFindProgram // endDefinition;


(* Whether a program is given as a path rather than as a command name to look up *)
programPathQ // beginDefinition;
programPathQ[ program_String, windowsQ_ ] := StringContainsQ[ program, If[ TrueQ @ windowsQ, "/" | "\\", "/" ] ] || StringStartsQ[ program, "~" ];
programPathQ // endDefinition;


(* The kernel's PATH, home directory and operating system for acpFindProgram *)
acpProgramEnvironment // beginDefinition;

acpProgramEnvironment[ ] := <|
    "PATH"              -> Environment[ "PATH" ],
    "HomeDirectory"     -> $HomeDirectory,
    "OperatingSystem"   -> $OperatingSystem,
    "SystemDirectories" -> $acpProgramSystemDirectories
|>;

acpProgramEnvironment // endDefinition;

(* Install directories relative to the home directory (the OpenCode installer, pipx/uv style, bun, npm prefix) *)
$acpProgramHomeDirectories = { { ".opencode", "bin" }, { ".local", "bin" }, { ".bun", "bin" }, { ".npm-global", "bin" } };

(* Directories that a GUI-started kernel's PATH may lack (macOS: Homebrew on Apple silicon and Intel) *)
$acpProgramSystemDirectories = { "/opt/homebrew/bin", "/usr/local/bin" };


acpPathDirectories // beginDefinition;

acpPathDirectories[ path_String, windowsQ_ ] := Select[
    StringTrim[ #, "\"" ] & /@ StringSplit[ path, If[ TrueQ @ windowsQ, ";", ":" ] ],
    StringLength[ # ] > 0 &
];

acpPathDirectories[ _, _ ] := { };

acpPathDirectories // endDefinition;


acpExecutableFileQ // beginDefinition;
acpExecutableFileQ[ file_String ] := TrueQ @ Quiet @ FileExistsQ @ file && ! TrueQ @ Quiet @ DirectoryQ @ file;
acpExecutableFileQ[ _ ] := False;
acpExecutableFileQ // endDefinition;


agentNotFound // beginDefinition;

agentNotFound[ agent_, path_, url_ ] := Failure[ "AgentNotFound", <|
    "MessageTemplate"   -> acpConnectionLabel[ "ErrorAgentNotFound", <| "agent" -> agent |> ],
    "MessageParameters" -> { },
    "Agent"             -> agent,
    "Path"              -> path,
    "InstallURL"        -> url
|> ];

agentNotFound // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*OpenCode Configuration*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpOpenCodeConfigJSON*)

(* The inline OpenCode config (OPENCODE_CONFIG_CONTENT, merged with the user's global config with the highest
   precedence; OPENCODE_CONFIG_DIR is never used because it replaces the global config and drops e.g. the Wolfram MCP
   server). acpOpenCodeConfigJSON[True] adds the Wolfram LLMKit provider, whose API key is read from the environment
   variable LLMKIT_API_KEY (the key itself is never part of the JSON). *)
acpOpenCodeConfigJSON // beginDefinition;

acpOpenCodeConfigJSON[ ] := acpOpenCodeConfigJSON @ False;

acpOpenCodeConfigJSON[ llmKit_ ] := Developer`WriteRawJSONString[ openCodeConfig @ TrueQ @ llmKit, "Compact" -> True ];

acpOpenCodeConfigJSON // endDefinition;


(* Edits, shell commands and the notebook tools that change open notebooks (MCP.wl's acpMCPToolPermissions, e.g.
   "WolframNotebooks_InsertCells") ask for permission. These rules only reach an agent that gets the environment: see
   acpOwnAgentCommandQ. *)
openCodeConfig // beginDefinition;

openCodeConfig[ llmKit_ ] := Join[
    <|
        "$schema"    -> $openCodeConfigSchema,
        "permission" -> <| "edit" -> "ask", "bash" -> "ask", acpMCPToolPermissions[ ] |>
    |>,
    If[ TrueQ @ llmKit, <| "provider" -> <| "llmkit" -> $llmKitProvider |> |>, <| |> ]
];

openCodeConfig // endDefinition;


$llmKitProvider := <|
    "npm"     -> "@ai-sdk/openai-compatible",
    "name"    -> "Wolfram LLMKit",
    "options" -> <|
        "baseURL" -> $llmKitBaseURL,
        "headers" -> <| "Authorization" -> "Bearer {env:LLMKIT_API_KEY}" |>
    |>,
    "models"  -> $llmKitModels
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpOpenCodeEnvironment*)

(* <| GetEnvironment[], "OPENCODE_CONFIG_CONTENT" -> json, ("LLMKIT_API_KEY" -> key) |> *)
acpOpenCodeEnvironment // beginDefinition;

acpOpenCodeEnvironment[ ] := acpOpenCodeEnvironment @ acpLLMKitAPIKey[ ];

acpOpenCodeEnvironment[ key_ ] := Join[ acpInheritedEnvironment[ ], acpOpenCodeVariables @ key ];

acpOpenCodeEnvironment // endDefinition;


(* OpenCode's own variables: <| "OPENCODE_CONFIG_CONTENT" -> json, ("LLMKIT_API_KEY" -> key) |>. A local OpenCode gets
   them in its environment (acpOpenCodeEnvironment), a remote one from the launch script (the registry's "Variables"). *)
acpOpenCodeVariables // beginDefinition;

acpOpenCodeVariables[ key_ ] := Join[
    <| "OPENCODE_CONFIG_CONTENT" -> acpOpenCodeConfigJSON @ StringQ @ key |>,
    If[ StringQ @ key, <| "LLMKIT_API_KEY" -> key |>, <| |> ]
];

acpOpenCodeVariables // endDefinition;


(* The kernel's environment without the variables that ACPLink refuses in an explicit environment (::envval, the open
   fails): a name or value containing "=" or surrounding spaces, unless the name is a valid shell name and the system is
   not Windows. Exported bash functions (BASH_FUNC_name%%) are such variables; StartProcess would drop them anyway.
   Also the environment of ssh for remote windows (acpSSHEnvironment, SSH.wl). *)
acpInheritedEnvironment // beginDefinition;

acpInheritedEnvironment[ ] := Association @ Select[
    Normal @ Association @ Replace[ GetEnvironment[ ], Except[ _List | _Association ] -> { } ],
    passableEnvironmentRuleQ
];

acpInheritedEnvironment // endDefinition;


passableEnvironmentRuleQ[ name_String -> value_String ] :=
    plainEnvironmentStringQ @ name && plainEnvironmentStringQ @ value ||
        $OperatingSystem =!= "Windows" && StringMatchQ[ name, RegularExpression[ "[A-Za-z_][A-Za-z0-9_]*" ] ];

passableEnvironmentRuleQ[ _ ] := False;

plainEnvironmentStringQ[ s_String ] := ! StringContainsQ[ s, "=" ] && StringTrim @ s === s;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*LLMKit API Key*)

(* Per-session state: the cached lookup result (<| "Key" -> key | None |>, only for definitive results) and whether a key
   creation was already attempted (at most one attempt per kernel session). *)
If[ ! MatchQ[ $llmKitKeyCache, _Association | None ], $llmKitKeyCache = None ];
If[ ! BooleanQ @ $llmKitCreationAttempted, $llmKitCreationAttempted = False ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpLLMKitAPIKey*)

(* An active Wolfram API key with the LLMKitAPIs grant, or None. Only looked up if $acpLLMKitEnabled and
   $CloudConnected; makes signed requests to the wolfram-keys service (synchronous, so never call it from a reader
   handler). Never throws and never logs the key. *)
acpLLMKitAPIKey // beginDefinition;

acpLLMKitAPIKey[ ] := Replace[
    Quiet @ Catch[ cachedLLMKitAPIKey[ ], _, None & ],
    Except[ _String? StringQ ] -> None
];

acpLLMKitAPIKey // endDefinition;


cachedLLMKitAPIKey // beginDefinition;

cachedLLMKitAPIKey[ ] := Which[
    ! TrueQ @ $acpLLMKitEnabled || ! TrueQ @ cloudConnectedQ[ ],
        None,
    AssociationQ @ $llmKitKeyCache,
        Lookup[ $llmKitKeyCache, "Key", None ],
    True,
        Module[ { result },
            result = acpFindLLMKitKey[ wolframKeysRequest, claimKeyCreation ];
            If[ TrueQ @ Lookup[ result, "Definitive", False ],
                $llmKitKeyCache = <| "Key" -> Lookup[ result, "Key", None ] |>
            ];
            acpLog[ "LLMKitKey", <| "Status" -> Lookup[ result, "Status", None ] |> ];
            Lookup[ result, "Key", None ]
        ]
];

cachedLLMKitAPIKey // endDefinition;


cloudConnectedQ // beginDefinition;
cloudConnectedQ[ ] := TrueQ @ $CloudConnected;
cloudConnectedQ // endDefinition;


(* Allows at most one key creation per kernel session: *)
claimKeyCreation // beginDefinition;
claimKeyCreation[ ] := PreemptProtect @ If[ TrueQ @ $llmKitCreationAttempted, False, $llmKitCreationAttempted = True; True ];
claimKeyCreation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFindLLMKitKey*)

(* acpFindLLMKitKey[request, createQ] finds (or creates) an LLMKit key:
     1. list the user's keys; use an "Active" key with the LLMKitAPIs grant;
     2. otherwise, if the user has the LLMKitAPIs permission, no key named $llmKitKeyName exists yet, and createQ[]
        gives True, create one key with that grant and list the keys again.
   request[method, endpoint, body] performs the request ("GET"|"POST", "keys"|"permissions") and gives
   <| "StatusCode" -> code, "Body" -> parsed JSON |> or a Failure. createQ[] is called right before a creation.
   Gives <| "Key" -> key | None, "Status" -> _String, "Definitive" -> True|False |>; never throws.
   Keys without the LLMKitAPIs grant are never used. *)
acpFindLLMKitKey // beginDefinition;

acpFindLLMKitKey[ request_, createQ_ ] := Replace[
    Quiet @ Catch[ findLLMKitKey[ request, createQ ], _, (<| "Key" -> None, "Status" -> "Exception", "Definitive" -> False |> &) ],
    Except[ _Association ] -> <| "Key" -> None, "Status" -> "Exception", "Definitive" -> False |>
];

acpFindLLMKitKey // endDefinition;


findLLMKitKey // beginDefinition;

findLLMKitKey[ request_, createQ_ ] := Catch @ Module[ { records, key, grants, created },

    records = keyRecords @ request[ "GET", "keys", None ];
    If[ ! ListQ @ records, Throw @ keyResult[ None, "ListFailed", False ] ];

    key = llmKitKeyFromRecords @ records;
    If[ StringQ @ key, Throw @ keyResult[ key, "Found", True ] ];

    grants = permissionGrants @ request[ "GET", "permissions", None ];
    If[ ! ListQ @ grants, Throw @ keyResult[ None, "PermissionsFailed", False ] ];
    If[ ! MemberQ[ grants, $llmKitGrant ], Throw @ keyResult[ None, "NoPermission", True ] ];

    (* Never create a second key with our name (e.g. one that was disabled or lost its grant): *)
    If[ AnyTrue[ records, MatchQ[ #, KeyValuePattern[ "name" -> $llmKitKeyName ] ] & ],
        Throw @ keyResult[ None, "KeyNameTaken", True ]
    ];

    If[ ! TrueQ @ createQ[ ], Throw @ keyResult[ None, "CreationNotAllowed", False ] ];

    created = request[
        "POST",
        "keys",
        <| "name" -> $llmKitKeyName, "description" -> $llmKitKeyDescription, "permissions" -> { $llmKitGrant } |>
    ];

    If[ ! MatchQ[ created, KeyValuePattern @ { "StatusCode" -> 200|201, "Body" -> KeyValuePattern[ "success" -> True ] } ],
        Throw @ keyResult[ None, "CreateFailed", True ]
    ];

    (* Use the key only as listed by the service, i.e. with its grant: *)
    key = llmKitKeyFromRecords @ keyRecords @ request[ "GET", "keys", None ];
    If[ StringQ @ key, keyResult[ key, "Created", True ], keyResult[ None, "CreatedNotListed", False ] ]
];

findLLMKitKey // endDefinition;


keyResult // beginDefinition;
keyResult[ key_, status_String, definitive_ ] := <| "Key" -> key, "Status" -> status, "Definitive" -> TrueQ @ definitive |>;
keyResult // endDefinition;


keyRecords // beginDefinition;
keyRecords[ KeyValuePattern @ { "StatusCode" -> 200, "Body" -> KeyValuePattern @ { "success" -> True, "data" -> data_List } } ] := data;
keyRecords[ _ ] := $Failed;
keyRecords // endDefinition;


permissionGrants // beginDefinition;

permissionGrants[ KeyValuePattern @ { "StatusCode" -> 200, "Body" -> KeyValuePattern @ { "success" -> True, "data" -> data_List } } ] :=
    Cases[
        data,
        KeyValuePattern[ "permissionId" -> KeyValuePattern[ "grantImmutableId" -> g_String ] ] |
        KeyValuePattern[ "grantImmutableId" -> g_String ] :> g
    ];

permissionGrants[ _ ] := $Failed;

permissionGrants // endDefinition;


llmKitKeyFromRecords // beginDefinition;

llmKitKeyFromRecords[ records_List ] := FirstCase[
    records,
    record: KeyValuePattern @ { "status" -> "Active", "apiKey" -> key_String } /; llmKitGrantQ @ record :> key,
    None
];

llmKitKeyFromRecords[ _ ] := None;

llmKitKeyFromRecords // endDefinition;


llmKitGrantQ // beginDefinition;

llmKitGrantQ[ record_Association ] := AnyTrue[
    Replace[ Lookup[ record, "permissions", { } ], Except[ _List ] -> { } ],
    MatchQ[
        #,
        KeyValuePattern[ "wolframKeyPermissionId" -> KeyValuePattern[ "grantImmutableId" -> $llmKitGrant ] ] |
        KeyValuePattern[ "grant" -> KeyValuePattern[ "immutableId" -> $llmKitGrant ] ]
    ] &
];

llmKitGrantQ[ _ ] := False;

llmKitGrantQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*wolframKeysRequest*)

(* A signed request to the wolfram-keys service. The response body is parsed but never logged. *)
wolframKeysRequest // beginDefinition;

wolframKeysRequest[ method_String, endpoint_String, body_ ] := Module[ { request, signed, response },
    request = HTTPRequest[
        $wolframKeysURL <> endpoint,
        Join[
            <| "Method" -> method |>,
            If[ AssociationQ @ body,
                <|
                    "ContentType" -> "application/json",
                    "Body"        -> StringToByteArray[ Developer`WriteRawJSONString[ body, "Compact" -> True ], "UTF-8" ]
                |>,
                <| |>
            ]
        ]
    ];
    signed   = Quiet @ Symbol[ "CloudObject`SignCloudRequest" ][ request ];
    response = If[ MatchQ[ signed, _HTTPRequest ], Quiet @ URLRead[ signed, TimeConstraint -> $llmKitRequestTimeout ], $Failed ];
    If[ MatchQ[ response, _HTTPResponse ],
        <|
            "StatusCode" -> response[ "StatusCode" ],
            "Body"       -> Replace[ Quiet @ Developer`ReadRawJSONString @ response[ "Body" ], Except[ _Association ] -> <| |> ]
        |>,
        Failure[ "RequestFailed", <| "Endpoint" -> endpoint |> ]
    ]
];

wolframKeysRequest[ ___ ] := Failure[ "RequestFailed", <| |> ];

wolframKeysRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Models*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPreferredModel*)

(* acpPreferredModel[configOptions, prefs] gives the model to select after a session was created: the first of
   prefs["Requested"] (explicit "ACPModel" setting or a pending user choice), prefs["LastUsed"] (persisted last choice
   for the agent), llmkit/gpt-5.4 and openai/gpt-6.1-sol that the agent offers and that has not failed in this session
   (prefs["FailedModels"]); otherwise the agent's current value. Missing["NotAvailable"] if there is no model option. *)
acpPreferredModel // beginDefinition;

acpPreferredModel[ configOptions_ ] := acpPreferredModel[ configOptions, <| |> ];

acpPreferredModel[ configOptions_List, prefs_Association ] := Module[ { option, values, failed, candidates },
    option = acpFindConfigOption[ configOptions, "model" ];
    If[ ! AssociationQ @ option, Return[ Missing[ "NotAvailable" ], Module ] ];
    values     = acpOptionValues @ option;
    failed     = Replace[ Lookup[ prefs, "FailedModels", { } ], Except[ _List ] -> { } ];
    candidates = Join[ { Lookup[ prefs, "Requested", None ], Lookup[ prefs, "LastUsed", None ] }, $fallbackModels ];
    FirstCase[
        candidates,
        model_String /; MemberQ[ values, model ] && ! MemberQ[ failed, model ] :> model,
        Lookup[ option, "currentValue", Missing[ "NotAvailable" ] ]
    ]
];

acpPreferredModel[ _, _ ] := Missing[ "NotAvailable" ];

acpPreferredModel // endDefinition;


(* acpFindConfigOption[configOptions, category] gives the raw ACP configOption with that category ("model" | "mode" |
   "thought_level"), or with the conventional id for it. *)
acpFindConfigOption // beginDefinition;

acpFindConfigOption[ configOptions_List, category_String ] := FirstCase[
    configOptions,
    opt_Association /; Lookup[ opt, "category" ] === category :> opt,
    FirstCase[
        configOptions,
        opt_Association /; Lookup[ opt, "id" ] === Lookup[ $categoryIDs, category, None ] :> opt,
        Missing[ "NotAvailable" ]
    ]
];

acpFindConfigOption[ _, _ ] := Missing[ "NotAvailable" ];

acpFindConfigOption // endDefinition;

$categoryIDs = <| "model" -> "model", "mode" -> "mode", "thought_level" -> "effort" |>;


(* All values of a select option (option groups are flattened) *)
acpOptionValues // beginDefinition;

acpOptionValues[ option_Association ] := Flatten @ Replace[
    Replace[ Lookup[ option, "options", { } ], Except[ _List ] -> { } ],
    {
        KeyValuePattern[ "value" -> v_String ] :> { v },
        KeyValuePattern[ "options" -> sub_List ] :> Cases[ sub, KeyValuePattern[ "value" -> v_String ] :> v ],
        _ -> { }
    },
    { 1 }
];

acpOptionValues[ _ ] := { };

acpOptionValues // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpBillingLabel*)

(* Who pays for a model: "Wolfram LLMKit" | "OpenAI (your account)" | "OpenCode (free)" | ... | the provider name. *)
acpBillingLabel // beginDefinition;

acpBillingLabel[ model_String ] := Module[ { provider, name },
    { provider, name } = If[ StringContainsQ[ model, "/" ], StringSplit[ model, "/", 2 ], { "", model } ];
    Switch[ ToLowerCase @ provider,
        "llmkit"   , acpConnectionLabel[ "BillingLLMKit" ],
        "openai"   , acpConnectionLabel[ "BillingOpenAI" ],
        "anthropic", acpConnectionLabel[ "BillingAnthropic" ],
        "google"   , acpConnectionLabel[ "BillingGoogle" ],
        "opencode" , If[ freeOpenCodeModelQ @ name, acpConnectionLabel[ "BillingOpenCodeFree" ], acpConnectionLabel[ "BillingOpenCodeZen" ] ],
        ""         , "",
        _          , provider
    ]
];

acpBillingLabel[ _ ] := "";

acpBillingLabel // endDefinition;


freeOpenCodeModelQ // beginDefinition;
freeOpenCodeModelQ[ name_String ] := StringEndsQ[ name, "-free" ] || name === "big-pickle";
freeOpenCodeModelQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Persisted Settings*)

(* User choices that outlive the session (last project directory, last model/effort per agent), stored in
   CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "ACP", keys...}].
   These are front end calls: never use them in reader handlers (read before connecting, write via acpSchedule).
   Without a front end (e.g. in tests) a kernel-session store is used instead. *)
If[ ! AssociationQ @ $headlessSettings, $headlessSettings = <| |> ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPersistedSetting*)
acpPersistedSetting // beginDefinition;

acpPersistedSetting[ key_String ] := acpPersistedSetting[ { key } ];
acpPersistedSetting[ key_String, default_ ] := acpPersistedSetting[ { key }, default ];
acpPersistedSetting[ keys_List ] := acpPersistedSetting[ keys, Missing[ "NotSet" ] ];

acpPersistedSetting[ keys: { __String }, default_ ] :=
    If[ $FrontEnd === Null,
        Lookup[ $headlessSettings, Key @ keys, default ],
        Replace[
            Quiet @ CurrentValue[ $FrontEnd, Join[ $acpPreferencesPath, keys ] ],
            Inherited | $Failed | _Missing | _CurrentValue -> default
        ]
    ];

acpPersistedSetting // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSetPersistedSetting*)

(* Setting a value of Inherited removes it. *)
acpSetPersistedSetting // beginDefinition;

acpSetPersistedSetting[ key_String, value_ ] := acpSetPersistedSetting[ { key }, value ];

acpSetPersistedSetting[ keys: { __String }, value_ ] := (
    If[ $FrontEnd === Null,
        If[ value === Inherited,
            PreemptProtect[ $headlessSettings = KeySelect[ $headlessSettings, # =!= keys & ] ],
            PreemptProtect[ $headlessSettings[ keys ] = value ]
        ],
        Quiet[ CurrentValue[ $FrontEnd, Join[ $acpPreferencesPath, keys ] ] = value ]
    ];
    value
);

acpSetPersistedSetting // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Remote hosts*)

(* The persisted home folder of a remote host ({"SSH", hostKey, "Home"}, written once a launch reported it), or None
   (local, invalid settings, not known yet, or not an absolute path). A front end read: not for reader handlers. *)
acpPersistedRemoteHome // beginDefinition;

acpPersistedRemoteHome[ ssh_ ] := With[ { key = acpRemoteHomeKey @ ssh },
    If[ ListQ @ key,
        Replace[ acpPersistedSetting[ key, None ], Except[ _String? acpRemoteAbsolutePathQ ] -> None ],
        None
    ]
];

acpPersistedRemoteHome // endDefinition;


(* Forgets the persisted last folder of a remote host ({"SSH", hostKey, "LastProjectDirectory"}) if it is one of paths,
   e.g. a folder that no longer exists (RemoteFolderMissing). Writes nothing if it was changed meanwhile. A front end
   call: scheduled from reader handlers. *)
acpClearPersistedLastFolder // beginDefinition;

acpClearPersistedLastFolder[ ssh_, path_String ] := acpClearPersistedLastFolder[ ssh, { path } ];

acpClearPersistedLastFolder[ ssh_Association, paths_List ] := With[ { key = acpLastProjectDirectoryKey @ ssh },
    If[ ListQ @ key && MemberQ[ Select[ paths, StringQ ], acpPersistedSetting[ key, None ] ],
        acpSetPersistedSetting[ key, Inherited ];
        True,
        False
    ]
];

acpClearPersistedLastFolder[ _, _ ] := False;

acpClearPersistedLastFolder // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
