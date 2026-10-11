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
   variable; the injected OpenCode config refers to it as {env:LLMKIT_API_KEY}. *)

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
    "ErrorAgentNotFoundDetail"     -> "Install it from `url`, or give its location with the \"ACPAgentExecutable\" setting.",
    "ErrorAgentNotFoundPath"       -> "The file `path` does not exist.",
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

    (* Notices (shown above the input field) *)
    "NoticeBackgroundPermission"   -> "A background subagent asked for permission after the turn ended; the request was cancelled.",
    "NoticeSessionNotResumed"      -> "New session: `agent` doesn't remember the messages above.",
    "NoticeConfigOptionFailed"     -> "Couldn't change `option`: `message`",

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
     "Executable"  -> a path, a command list {exe, args...}, or a function of the window settings that returns a path
                      (or a Failure["AgentNotFound", ...])
     "Arguments"   -> extra command line arguments (may be a RuleDelayed)
     "Environment" -> process environment: Inherited or an association (may be a RuleDelayed; evaluated only right
                      before the agent is started)
     "BillingLabel"-> a function of the model value giving the billing label
   The window setting "ACPAgentExecutable" overrides "Executable" (for OpenCode it is validated by acpFindOpenCode). *)
If[ ! AssociationQ @ $acpAgents, $acpAgents = <| |> ];

$acpAgents[ "OpenCode" ] = <|
    "Name"         -> "OpenCode",
    "Executable"   -> acpFindOpenCode,
    "Arguments"    -> { "acp" },
    "Environment"  :> acpOpenCodeEnvironment[ ],
    "BillingLabel" -> acpBillingLabel,
    "InstallURL"   -> $openCodeInstallURL
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpAgentSpec*)

(* acpAgentSpec[name, settings] gives <| "Name", "Command" -> {exe, args...}, "Environment" :> env |> or a Failure
   ("UnknownAgent", "AgentNotFound"). The environment is left unevaluated (RuleDelayed): it may contain secrets and is
   only evaluated by the code that starts the agent. *)
acpAgentSpec // beginDefinition;

acpAgentSpec[ name_String ] := acpAgentSpec[ name, <| |> ];

acpAgentSpec[ name_String, settings_Association ] := Catch @ Module[ { agent, exe, args, command },
    agent = Lookup[ $acpAgents, name, Missing[ "UnknownAgent" ] ];
    If[ ! AssociationQ @ agent,
        Throw @ Failure[ "UnknownAgent", <|
            "MessageTemplate"   -> acpConnectionLabel[ "ErrorUnknownAgent", <| "agent" -> name |> ],
            "MessageParameters" -> { },
            "Agent"             -> name
        |> ]
    ];
    exe = agentExecutable[ name, agent, settings ];
    If[ FailureQ @ exe, Throw @ exe ];
    args    = Replace[ Lookup[ agent, "Arguments", { } ], Except[ _List ] -> { } ];
    command = Flatten @ { exe, args };
    If[ ! MatchQ[ command, { __String } ],
        Throw @ agentNotFound[ Lookup[ agent, "Name", name ], None, Lookup[ agent, "InstallURL", None ] ]
    ];
    With[ { a = agent },
        <|
            "Name"        -> Replace[ Lookup[ agent, "Name", name ], Except[ _String ] -> name ],
            "Command"     -> command,
            "Environment" :> Lookup[ a, "Environment", Inherited ]
        |>
    ]
];

acpAgentSpec // endDefinition;


agentExecutable // beginDefinition;

(* OpenCode validates the explicit setting itself: *)
agentExecutable[ "OpenCode", _, settings_ ] :=
    acpFindOpenCode @ settings;

agentExecutable[ name_, agent_Association, settings_Association ] :=
    Replace[
        explicitExecutable @ settings,
        None :> Replace[
            Lookup[ agent, "Executable", None ],
            {
                exe: _String | { __String } :> exe,
                File[ exe_String ] :> exe,
                None :> agentNotFound[ Lookup[ agent, "Name", name ], None, Lookup[ agent, "InstallURL", None ] ],
                f_ :> f @ settings
            }
        ]
    ];

agentExecutable // endDefinition;


explicitExecutable // beginDefinition;
explicitExecutable[ settings_Association ] := explicitExecutable @ Lookup[ settings, "ACPAgentExecutable", Automatic ];
explicitExecutable[ File[ path_String ] ] := explicitExecutable @ path;
explicitExecutable[ path_String ] /; StringLength @ StringTrim @ path > 0 := StringTrim @ path;
explicitExecutable[ command: { __String } ] := command;
explicitExecutable[ _ ] := None;
explicitExecutable // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFindOpenCode*)

(* acpFindOpenCode[settings] finds the opencode executable: the "ACPAgentExecutable" setting (if given; it must exist),
   then the directories in Environment["PATH"], then the usual install directories in the home directory (the
   installer's ~/.opencode/bin, then ~/.local/bin, ~/.bun/bin, ~/.npm-global/bin), then the usual system directories
   (Homebrew, /usr/local/bin: a front end started from the macOS Dock gives the kernel a minimal PATH without them).
   No RunProcess (RunProcess can hang while an ACP reader is active).
   acpFindOpenCode[settings, <| "PATH" -> _, "HomeDirectory" -> _, "OperatingSystem" -> _, "SystemDirectories" -> _ |>]
   is used by tests ("SystemDirectories" defaults to none there). *)
acpFindOpenCode // beginDefinition;

acpFindOpenCode[ ] := acpFindOpenCode @ <| |>;

acpFindOpenCode[ settings_Association ] := acpFindOpenCode[
    settings,
    <|
        "PATH"              -> Environment[ "PATH" ],
        "HomeDirectory"     -> $HomeDirectory,
        "OperatingSystem"   -> $OperatingSystem,
        "SystemDirectories" -> $openCodeSystemDirectories
    |>
];

acpFindOpenCode[ settings_Association, env_Association ] := Catch @ Module[ { explicit, windowsQ, names, dirs, home },
    explicit = explicitExecutable @ settings;
    Which[
        StringQ @ explicit,
            Throw @ If[ acpExecutableFileQ @ explicit,
                Quiet @ ExpandFileName @ explicit,
                agentNotFound[ "OpenCode", explicit, $openCodeInstallURL ]
            ],
        MatchQ[ explicit, { __String } ],
            Throw @ explicit
    ];

    windowsQ = Lookup[ env, "OperatingSystem", $OperatingSystem ] === "Windows";
    names    = If[ windowsQ, { "opencode.exe", "opencode.cmd", "opencode" }, { "opencode" } ];
    dirs     = acpPathDirectories[ Lookup[ env, "PATH", None ], windowsQ ];
    home     = Lookup[ env, "HomeDirectory", None ];
    If[ StringQ @ home,
        dirs = Join[ dirs, FileNameJoin @ Prepend[ #, home ] & /@ If[ windowsQ, { { ".opencode", "bin" } }, $openCodeHomeDirectories ] ]
    ];
    If[ ! windowsQ, dirs = Join[ dirs, Select[ Replace[ Lookup[ env, "SystemDirectories", { } ], Except[ _List ] -> { } ], StringQ ] ] ];

    Replace[
        SelectFirst[ Flatten @ Outer[ FileNameJoin @ { #1, #2 } &, dirs, names ], acpExecutableFileQ, None ],
        None :> agentNotFound[ "OpenCode", None, $openCodeInstallURL ]
    ]
];

acpFindOpenCode // endDefinition;

(* Install directories relative to the home directory (the OpenCode installer, pipx/uv style, bun, npm prefix) *)
$openCodeHomeDirectories = { { ".opencode", "bin" }, { ".local", "bin" }, { ".bun", "bin" }, { ".npm-global", "bin" } };

(* Directories that a GUI-started kernel's PATH may lack (macOS: Homebrew on Apple silicon and Intel) *)
$openCodeSystemDirectories = { "/opt/homebrew/bin", "/usr/local/bin" };


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


openCodeConfig // beginDefinition;

openCodeConfig[ llmKit_ ] := Join[
    <|
        "$schema"    -> $openCodeConfigSchema,
        "permission" -> <| "edit" -> "ask", "bash" -> "ask" |>
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

acpOpenCodeEnvironment[ key_ ] := Join[
    inheritedEnvironment[ ],
    <| "OPENCODE_CONFIG_CONTENT" -> acpOpenCodeConfigJSON @ StringQ @ key |>,
    If[ StringQ @ key, <| "LLMKIT_API_KEY" -> key |>, <| |> ]
];

acpOpenCodeEnvironment // endDefinition;


(* The kernel's environment without the variables that ACPLink refuses in an explicit environment (::envval, the open
   fails): a name or value containing "=" or surrounding spaces, unless the name is a valid shell name and the system is
   not Windows. Exported bash functions (BASH_FUNC_name%%) are such variables; StartProcess would drop them anyway. *)
inheritedEnvironment // beginDefinition;

inheritedEnvironment[ ] := Association @ Select[
    Normal @ Association @ Replace[ GetEnvironment[ ], Except[ _List | _Association ] -> { } ],
    passableEnvironmentRuleQ
];

inheritedEnvironment // endDefinition;


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
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
