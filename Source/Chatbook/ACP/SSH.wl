(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`SSH`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ACP`Common`" ];

(* Remote mode over SSH (see docs/acp-window.md): the "SSHSettings" setting and its accessors, host identity and
   per-host preference keys, the ssh command, quoting and remote path helpers, the agent's launch script and its markers,
   and the classification of ssh's exits into the error kinds of the error table (Connection.wl, "Errors").

   Everything here is pure: no front end calls and no processes (acpFindSSH only checks files), so it is safe in reader
   handlers, renderers and housekeeping (R2). Remote text (paths, names, ssh's and the agent's output) reaches boxes only
   through acpRemoteDisplayName or acpNeutralizeLinearSyntax, and is never ToExpression'd. Paths that come from the
   remote machine are used only if acpRemoteAbsolutePathQ. No secret is ever on a command line: the launch script, which
   holds the LLMKit key, is written to ssh's standard input, and it is never logged. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

(* The keys of "SSHSettings", in the order of the canonical form *)
$acpSSHSettingKeys = { "MachineName", "Username", "Arguments", "Executable" };

(* ssh's options (OpenSSH's getopt string): the ones that take a value, the flags, and the ones that would keep
   Chatbook's command from running or from reading its standard input (no command, no stdin, background, multiplexing,
   queries); -o keys (lower case) with the same effect. -S is checked like -o ControlPath (sshArgumentsProblem). -q, -E
   and -y are allowed, but they take ssh's own messages out of its standard error, so its failures are classified less
   precisely. *)
$acpSSHValueOptions     = Characters[ "BbcDEeFIiJLlmOoPpQRSWw" ];
$acpSSHFlagOptions      = Characters[ "46AaCfGgKkMNnqsTtVvXxYy" ];
$acpSSHForbiddenOptions = Characters[ "fGMNnOQsVW" ];
$acpSSHForbiddenConfig  = { "stdinnull", "sessiontype", "forkafterauthentication" };

(* RegularExpression, not (LetterCharacter | "@").. : "@" and "*" are metacharacters in string patterns, so that
   pattern matches "a b" *)
$acpSSHHostRegex  = RegularExpression[ "[\\p{L}\\p{N}._:%\\[\\]-]+" ];
$acpSSHUserRegex  = RegularExpression[ "[\\p{L}\\p{N}._@+-]+" ];
$controlCharacter = RegularExpression[ "[\\x00-\\x1f\\x7f]" ];

(* Options that come before the user's "Arguments" (ssh uses the first value of an option, so neither the user's ssh
   config nor "Arguments" can change them): no prompts, host keys always checked (also for localhost) and known_hosts
   never written, no forwarding, no command or local command of the config, one connection per operation.
   VerifyHostKeyDNS is left to the user's config: host keys in DNSSEC-signed SSHFP records are a host key check too. *)
$acpSSHFixedOptions = {
    "-o", "BatchMode=yes",
    "-o", "StrictHostKeyChecking=yes",
    "-o", "CheckHostIP=no",
    "-o", "UpdateHostKeys=no",
    "-o", "NoHostAuthenticationForLocalhost=no",
    "-o", "ForwardAgent=no",
    "-o", "ForwardX11=no",
    "-o", "GSSAPIDelegateCredentials=no",
    "-o", "ClearAllForwardings=yes",
    "-o", "RemoteCommand=none",
    "-o", "PermitLocalCommand=no",
    "-o", "ControlMaster=no",
    "-o", "ControlPath=none"
};

(* Options after the user's "Arguments" (the user's values win) *)
$acpSSHDefaultOptions = { "-o", "ConnectTimeout=20", "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=3" };

(* Why each fixed option can't be set to another value with "Arguments" (keys in lower case) *)
$fixedOptionReasons = <|
    "batchmode"                        -> "it never prompts",
    "stricthostkeychecking"            -> "it always checks host keys and never changes known_hosts",
    "checkhostip"                      -> "it always checks host keys and never changes known_hosts",
    "updatehostkeys"                   -> "it always checks host keys and never changes known_hosts",
    "nohostauthenticationforlocalhost" -> "it always checks host keys and never changes known_hosts",
    "forwardagent"                     -> "use -A, -X or -K to turn forwarding on",
    "forwardx11"                       -> "use -A, -X or -K to turn forwarding on",
    "gssapidelegatecredentials"        -> "use -A, -X or -K to turn forwarding on",
    "clearallforwardings"              -> "use -A, -X or -K to turn forwarding on",
    "remotecommand"                    -> "it runs its own command",
    "permitlocalcommand"               -> "it runs its own command",
    "controlmaster"                    -> "it uses one connection per operation",
    "controlpath"                      -> "it uses one connection per operation"
|>;

(* The remote commands. Both contain neither '"' nor '\' (ProcessLink's Windows command line only rewrites '"').
   The agent launch: tracing off (an inherited SHELLOPTS=xtrace would print the launch line with the key), the trigger
   line on standard error (ACPLink writes the launch script when it sees it), then one line of standard input is read
   (one byte at a time, so the JSON-RPC stream after it is untouched) and evaluated; "set -f; IFS=; eval $s" is
   eval "$s" without '"', and the script undoes both. Exit 125: standard input ended before a whole line. *)
$acpSSHLaunchTrigger = "chatbook-acp-ready";
$acpSSHLaunchCommand = "exec /bin/sh -c 'set +xv; echo chatbook-acp-ready >&2; IFS= read -r s || exit 125; set -f; IFS=; eval $s'";

(* One-shot operations (Remote.wl): the remote shell reads the script from standard input *)
$acpSSHScriptCommand = "exec /bin/sh -s";

(* The launch script's markers on standard error: chatbook-acp:<nonce>:<key>:<value> *)
$acpSSHMarkerPrefix = "chatbook-acp:";

(* Paths from the remote machine: at most this many characters (Linux's PATH_MAX) *)
$acpRemoteMaxPathLength = 4096;

(* ssh's standard error is classified on its last 64 KB (ssh's own message is always at the end) and the launch markers
   are read from its first 64 KB, so that hostile output can't block a reader handler *)
$acpRemoteClassifyBytes = 65536;

(* Where the launch script looks for a program given by name after the remote PATH (as acpFindProgram does locally:
   $acpProgramHomeDirectories and $acpProgramSystemDirectories of Agents.wl) *)
$launchSearchDirectories = {
    "\"$HOME/.opencode/bin\"",
    "\"$HOME/.local/bin\"",
    "\"$HOME/.bun/bin\"",
    "\"$HOME/.npm-global/bin\"",
    "/opt/homebrew/bin",
    "/usr/local/bin"
};

(* Where ssh is looked for when "Executable" is Automatic (besides PATH) *)
$sshSystemDirectories = { "/usr/bin", "/usr/local/bin", "/opt/homebrew/bin" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Settings*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSSHSettings*)

(* The "SSHSettings" setting:
     None, Automatic                       -> None: local (the agent, the folder and git are on this computer);
     "host", "user@host"                   -> the same as <| "MachineName" -> "host" |>;
     <| "MachineName" -> ..., ... |>, rules -> the canonical form
       <| "MachineName" -> _String, "Username" -> Automatic | _String, "Arguments" -> { ___String },
          "Executable" -> Automatic | _String |>
     anything invalid                      -> Failure[ "InvalidSSHSettings", <| ..., "Reason", "Key", "Value", "Detail" |> ]
   Idempotent on the canonical form. The canonical form holds no secrets (at most the path of a key file) and is what
   window records and TaggingRules store. The "Detail" of a failure is an English sentence for a kernel message. *)
acpSSHSettings // beginDefinition;

acpSSHSettings[ None | Automatic ] := None;

acpSSHSettings[ s_String ] := acpSSHSettings @ <| "MachineName" -> s |>;

acpSSHSettings[ rules: { (_Rule|_RuleDelayed)... } ] := acpSSHSettings @ Association @ rules;

acpSSHSettings[ as_Association ] := Catch[ canonicalSSHSettings @ as, $sshSettingsTag ];

acpSSHSettings[ other_ ] := sshSettingsFailure[
    "NotAnAssociation",
    None,
    other,
    "\"SSHSettings\" must be None, a host name or an association with \"MachineName\" (and optionally \"Username\", \
\"Arguments\" and \"Executable\")"
];

acpSSHSettings // endDefinition;


(* Checks in this order; the first problem is thrown (to $sshSettingsTag) as a Failure *)
canonicalSSHSettings // beginDefinition;

canonicalSSHSettings[ as_Association ] := Module[ { unknown, machine, user, at, args, exe },
    unknown = Select[ Keys @ as, ! MemberQ[ $acpSSHSettingKeys, # ] & ];
    If[ unknown =!= { },
        throwSettings[
            "UnknownKey",
            First @ unknown,
            as[ First @ unknown ],
            "unknown key " <> ToString[ First @ unknown, InputForm ] <>
                " (the keys are \"MachineName\", \"Username\", \"Arguments\" and \"Executable\")"
        ]
    ];

    machine = settingText @ Lookup[ as, "MachineName", Missing[ "NotSpecified" ] ];
    user    = Replace[ settingText @ Lookup[ as, "Username", Automatic ], None -> Automatic ];
    If[ MissingQ @ machine, throwSettings[ "MissingMachineName", "MachineName", machine, "\"MachineName\" is missing" ] ];
    If[ ! StringQ @ machine || machine === "",
        throwSettings[
            "InvalidMachineName",
            "MachineName",
            machine,
            "\"MachineName\" must be a host name, an IP address or a Host of your SSH configuration"
        ]
    ];

    (* ssh's destination form "user@host": split at the last "@" (a user name may contain "@"), unless "Username" is
       given too *)
    at = Flatten @ Position[ Characters @ machine, "@" ];
    If[ at =!= { },
        If[ user =!= Automatic,
            throwSettings[
                "AmbiguousUsername",
                "MachineName",
                machine,
                "give the user either in \"MachineName\" or with \"Username\", not both"
            ]
        ];
        { user, machine } = { StringTake[ machine, Last @ at - 1 ], StringDrop[ machine, Last @ at ] }
    ];

    If[ ! hostNameQ @ machine,
        throwSettings[
            "InvalidMachineName",
            "MachineName",
            machine,
            "\"MachineName\" can only contain letters, digits and . - _ : % [ ], can't start with - and can have at \
most 255 characters"
        ]
    ];
    If[ user =!= Automatic && ! userNameQ @ user,
        throwSettings[
            "InvalidUsername",
            "Username",
            user,
            "\"Username\" can only contain letters, digits and . - _ @ +, can't start with - and can have at most 256 \
characters"
        ]
    ];

    args = Replace[
        Lookup[ as, "Arguments", { } ],
        { None | Automatic -> { }, list_List :> Replace[ list, File[ s_String ] :> s, { 1 } ] }
    ];
    If[ ! MatchQ[ args, { ___String } ],
        throwSettings[
            "InvalidArguments",
            "Arguments",
            args,
            "\"Arguments\" must be a list of strings, e.g. {\"-i\", \"~/.ssh/key.pem\"}"
        ]
    ];
    Replace[ sshArgumentsProblem @ args, failure_Failure :> Throw[ failure, $sshSettingsTag ] ];

    exe = Replace[ settingText @ Lookup[ as, "Executable", Automatic ], None -> Automatic ];
    If[ exe =!= Automatic && ! (StringQ @ exe && exe =!= "" && ! StringContainsQ[ exe, $controlCharacter ]),
        throwSettings[
            "InvalidExecutable",
            "Executable",
            exe,
            "\"Executable\" must be Automatic or the path or name of the ssh program"
        ]
    ];

    <| "MachineName" -> machine, "Username" -> user, "Arguments" -> args, "Executable" -> exe |>
];

canonicalSSHSettings // endDefinition;


(* Values of the settings: File[ s ] is s, strings are trimmed *)
settingText // beginDefinition;
settingText[ File[ s_String ] ] := settingText @ s;
settingText[ s_String ] := StringTrim @ s;
settingText[ other_ ] := other;
settingText // endDefinition;


hostNameQ // beginDefinition;
hostNameQ[ s_String ] := StringLength @ s <= 255 && StringMatchQ[ s, $acpSSHHostRegex ] && ! StringStartsQ[ s, "-" ];
hostNameQ[ _ ] := False;
hostNameQ // endDefinition;


userNameQ // beginDefinition;
userNameQ[ s_String ] := StringLength @ s <= 256 && StringMatchQ[ s, $acpSSHUserRegex ] && ! StringStartsQ[ s, "-" ];
userNameQ[ _ ] := False;
userNameQ // endDefinition;


sshSettingsFailure // beginDefinition;

sshSettingsFailure[ reason_String, key_, value_, detail_String ] := Failure[ "InvalidSSHSettings", <|
    "MessageTemplate"   -> "`Detail`",
    "MessageParameters" -> <| "Detail" -> detail |>,
    "Reason"            -> reason,
    "Key"               -> key,
    "Value"             -> value,
    "Detail"            -> detail
|> ];

sshSettingsFailure // endDefinition;


throwSettings // beginDefinition;
throwSettings[ args___ ] := Throw[ sshSettingsFailure @ args, $sshSettingsTag ];
throwSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sshArgumentsProblem*)

(* None, or a Failure for the first argument that ssh would take as the destination or the command, that keeps
   Chatbook's command from running or from reading its input, that sets an option Chatbook sets itself to another value
   (it would be ignored, because Chatbook's options come first), or that is not an OpenSSH option. The words are scanned
   like ssh's getopt: an option that takes a value takes the rest of the word or else the next word. *)
sshArgumentsProblem // beginDefinition;

sshArgumentsProblem[ args: { ___String } ] := Catch[
    Module[ { i = 1, n = Length @ args, word, letters, c, value },
        While[ i <= n,
            word = args[[ i ]];
            If[ StringContainsQ[ word, $controlCharacter ], Throw[ controlCharacterFailure @ word, $sshSettingsTag ] ];
            If[ word === "--" || word === "-" || ! StringStartsQ[ word, "-" ],
                Throw[
                    sshSettingsFailure[
                        "UnsupportedArgument",
                        "Arguments",
                        word,
                        ToString[ word, InputForm ] <>
                            " is not an ssh option: give the host with \"MachineName\" (Chatbook adds the command)"
                    ],
                    $sshSettingsTag
                ]
            ];
            letters = Characters @ StringDrop[ word, 1 ];
            Do[
                c = letters[[ k ]];
                Which[
                    MemberQ[ $acpSSHValueOptions, c ],
                        value = Which[
                            k < Length @ letters, StringJoin @ Drop[ letters, k ],
                            i < n, args[[ ++i ]],
                            True, Throw[
                                sshSettingsFailure[ "UnsupportedArgument", "Arguments", word, "the ssh option -" <> c <> " needs a value" ],
                                $sshSettingsTag
                            ]
                        ];
                        If[ StringContainsQ[ value, $controlCharacter ], Throw[ controlCharacterFailure @ value, $sshSettingsTag ] ];
                        If[ MemberQ[ $acpSSHForbiddenOptions, c ], Throw[ forbiddenOption[ "-" <> c ], $sshSettingsTag ] ];
                        If[ c === "o", Replace[ configOptionProblem @ value, f_Failure :> Throw[ f, $sshSettingsTag ] ] ];
                        If[ c === "S", Replace[ controlPathProblem @ value, f_Failure :> Throw[ f, $sshSettingsTag ] ] ];
                        Break[ ],
                    MemberQ[ $acpSSHFlagOptions, c ],
                        If[ MemberQ[ $acpSSHForbiddenOptions, c ], Throw[ forbiddenOption[ "-" <> c ], $sshSettingsTag ] ],
                    True,
                        Throw[
                            sshSettingsFailure[ "UnsupportedArgument", "Arguments", word, "-" <> c <> " is not an ssh option" ],
                            $sshSettingsTag
                        ]
                ],
                { k, Length @ letters }
            ];
            i++
        ];
        None
    ],
    $sshSettingsTag
];

sshArgumentsProblem // endDefinition;


(* None, or a Failure for an -o value that can't be used *)
configOptionProblem // beginDefinition;

configOptionProblem[ value_String ] := Module[ { key, val },
    { key, val } = configOption @ value;
    Which[
        MemberQ[ $acpSSHForbiddenConfig, key ],
            forbiddenOption[ "-o " <> value ],
        KeyExistsQ[ $fixedOptionValues, key ] && configValue @ val =!= $fixedOptionValues[ key ],
            fixedOptionFailure[ key, value ],
        True,
            None
    ]
];

configOptionProblem // endDefinition;


(* None, or a Failure for the value of -S. -S sets ControlPath, but unlike -o it replaces an earlier value, so it would
   override Chatbook's ControlPath=none: it gets the refusal of -o ControlPath=<value>, and only none is accepted (as ssh
   compares it: the whole value, in any case, not trimmed or unquoted as a config line) *)
controlPathProblem // beginDefinition;
controlPathProblem[ value_String ] := If[ ToLowerCase @ value === "none", None, fixedOptionFailure[ "controlpath", "-S " <> value ] ];
controlPathProblem // endDefinition;


(* The Failure for a value of a fixed option (key in lower case) *)
fixedOptionFailure // beginDefinition;

fixedOptionFailure[ key_String, value_String ] := sshSettingsFailure[
    "UnsupportedArgument",
    "Arguments",
    value,
    "Chatbook sets the ssh option " <> $fixedOptionNames[ key ] <> " itself: " <> $fixedOptionReasons[ key ]
];

fixedOptionFailure // endDefinition;


(* An -o value as ssh reads a config line: { key in lower case, value }; the key ends at "=" or white space, and the
   value may be quoted *)
configOption // beginDefinition;

configOption[ value_String ] := Replace[
    StringCases[ value, RegularExpression[ "(?s)^\\s*([^\\s=]*)\\s*=?\\s*(.*?)\\s*$" ] :> { "$1", "$2" }, 1 ],
    {
        { { key_String, val_String } } :> { ToLowerCase @ key, Replace[ val, q_String /; StringMatchQ[ q, "\"" ~~ ___ ~~ "\"" ] && StringLength @ q >= 2 :> StringTake[ q, { 2, -2 } ] ] },
        _ :> { "", "" }
    }
];

configOption // endDefinition;


(* A value for comparison with a fixed one: case-insensitive, with true meaning yes and false meaning no *)
configValue // beginDefinition;
configValue[ value_String ] := Replace[ ToLowerCase @ StringTrim @ value, { "true" -> "yes", "false" -> "no" } ];
configValue // endDefinition;


(* The fixed options' values and names by lower-case key *)
$fixedOptionValues := $fixedOptionValues = Association[
    Cases[ $acpSSHFixedOptions, s_String /; StringContainsQ[ s, "=" ] :> Rule @@ (configValue /@ StringSplit[ s, "=", 2 ]) ]
];

$fixedOptionNames := $fixedOptionNames = Association[
    Cases[ $acpSSHFixedOptions, s_String /; StringContainsQ[ s, "=" ] :> With[ { k = First @ StringSplit[ s, "=", 2 ] }, ToLowerCase @ k -> k ] ]
];


forbiddenOption // beginDefinition;

forbiddenOption[ option_String ] := sshSettingsFailure[
    "UnsupportedArgument",
    "Arguments",
    option,
    "the ssh option " <> option <> " can't be used: Chatbook runs its own command over each connection and sends it input"
];

forbiddenOption // endDefinition;


controlCharacterFailure // beginDefinition;

controlCharacterFailure[ value_String ] := sshSettingsFailure[
    "InvalidArgument",
    "Arguments",
    value,
    "the arguments can't contain line breaks or other control characters"
];

controlCharacterFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Accessors*)

(* The SSH settings of window settings, of a window record, or of a window (None: local; a Failure for invalid stored
   settings, which counts as remote: a window never falls back to local). Not memoized: acpSSHSettings takes
   microseconds. *)
acpSettingsSSH // beginDefinition;
acpSettingsSSH[ settings_Association ] := acpSSHSettings @ Lookup[ settings, "SSHSettings", None ];
acpSettingsSSH[ _ ] := None;
acpSettingsSSH // endDefinition;


acpWindowSSH // beginDefinition;
acpWindowSSH[ window_Association ] := acpSettingsSSH @ Lookup[ window, "Settings", <| |> ];
acpWindowSSH[ nbo_NotebookObject ] := acpWindowSSH @ acpWindowGet @ nbo;
acpWindowSSH[ _ ] := None;
acpWindowSSH // endDefinition;


acpRemoteQ // beginDefinition;
acpRemoteQ[ w_ ] := acpWindowSSH @ w =!= None;
acpRemoteQ // endDefinition;


(* Host identity of a window for keys and display: None for a local window, "?" for invalid stored settings *)
acpWindowHostKey // beginDefinition;
acpWindowHostKey[ w_ ] := windowHost[ acpSSHHostKey, w ];
acpWindowHostKey // endDefinition;

acpWindowHostLabel // beginDefinition;
acpWindowHostLabel[ w_ ] := windowHost[ acpSSHHostLabel, w ];
acpWindowHostLabel // endDefinition;

acpWindowShortHost // beginDefinition;
acpWindowShortHost[ w_ ] := windowHost[ acpSSHShortHost, w ];
acpWindowShortHost // endDefinition;

windowHost // beginDefinition;
windowHost[ f_, w_ ] := Replace[ acpWindowSSH @ w, { ssh_Association :> f @ ssh, _Failure -> "?", _ -> None } ];
windowHost // endDefinition;


(* The remote home folder that a window knows (from the launch markers, a listing or the preferences), or None *)
acpWindowRemoteHome // beginDefinition;
acpWindowRemoteHome[ window_Association ] := Replace[ Lookup[ window, "RemoteHome", None ], Except[ _String? acpRemoteAbsolutePathQ ] -> None ];
acpWindowRemoteHome[ nbo_NotebookObject ] := acpWindowRemoteHome @ acpWindowGet @ nbo;
acpWindowRemoteHome[ _ ] := None;
acpWindowRemoteHome // endDefinition;


(* What pure path renderers need (permission scope, resource links, Sessions tooltips, turn records) *)
acpPathContext // beginDefinition;

acpPathContext[ w_ ] := If[ acpRemoteQ @ w,
    <| "Remote" -> True , "Host" -> acpWindowShortHost @ w, "HostLabel" -> acpWindowHostLabel @ w, "Home" -> acpWindowRemoteHome @ w |>,
    <| "Remote" -> False, "Host" -> None, "HostLabel" -> None, "Home" -> $HomeDirectory |>
];

acpPathContext // endDefinition;


(* Whether a project folder can be used: a local folder must exist; a remote one (also for invalid stored settings)
   is only checked for its form, never on the local disk *)
acpProjectDirectoryQ // beginDefinition;
acpProjectDirectoryQ[ dir_, None ] := StringQ @ dir && StringLength @ StringTrim @ dir > 0 && TrueQ @ Quiet @ DirectoryQ @ dir;
acpProjectDirectoryQ[ dir_, _ ] := acpRemoteProjectDirectoryQ @ dir;
acpProjectDirectoryQ // endDefinition;


(* A project folder setting in the form a window keeps: local folders as acpNormalizeDirectory (UI.wl) gives them,
   remote ones without any local file name function (acpRemoteNormalizeDirectory) *)
acpNormalizeProjectDirectory // beginDefinition;
acpNormalizeProjectDirectory[ dir_, None, _ ] := acpNormalizeDirectory @ dir;
acpNormalizeProjectDirectory[ dir_, _, home_ ] := acpRemoteNormalizeDirectory[ dir, home ];
acpNormalizeProjectDirectory[ dir_, window_Association ] := acpNormalizeProjectDirectory[ dir, acpWindowSSH @ window, acpWindowRemoteHome @ window ];
acpNormalizeProjectDirectory[ dir_, nbo_NotebookObject ] := acpNormalizeProjectDirectory[ dir, Replace[ acpWindowGet @ nbo, Except[ _Association ] -> <| |> ] ];
acpNormalizeProjectDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Host identity*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSSHHostKey*)

(* [user@]machine[:port], the identity of a host for per-host preferences and for comparing settings: the machine in
   lower case; the user from "Username", else from the first -l or -o User= in "Arguments"; the port from the first -p
   or -o Port= in "Arguments", omitted when it is 22. Two users on one host don't share a "last folder", and "-p 22" is
   the same host as no port. *)
acpSSHHostKey // beginDefinition;

acpSSHHostKey[ ssh_Association ] := Module[ { values, user, port },
    values = sshOptionValues @ Lookup[ ssh, "Arguments", { } ];
    user   = Replace[ Lookup[ ssh, "Username", Automatic ], Except[ _String ] :> optionUser @ values ];
    port   = optionPort @ values;
    StringJoin[
        If[ StringQ @ user, user <> "@", "" ],
        ToLowerCase @ Lookup[ ssh, "MachineName", "" ],
        If[ IntegerQ @ port && port =!= 22, ":" <> IntegerString @ port, "" ]
    ]
];

acpSSHHostKey[ _ ] := None;

acpSSHHostKey // endDefinition;


(* The values of the options in "Arguments" that take one, in order: { { letter, value }, ... } (scanned like ssh's
   getopt; the scan stops at a word that is not an option) *)
sshOptionValues // beginDefinition;

sshOptionValues[ args: { ___String } ] := Module[ { i = 1, n = Length @ args, word, letters, c, values = Internal`Bag[ ] },
    While[ i <= n,
        word = args[[ i ]];
        If[ ! StringStartsQ[ word, "-" ] || word === "--" || word === "-", Break[ ] ];
        letters = Characters @ StringDrop[ word, 1 ];
        Do[
            c = letters[[ k ]];
            If[ MemberQ[ $acpSSHValueOptions, c ],
                Internal`StuffBag[
                    values,
                    { c, Which[ k < Length @ letters, StringJoin @ Drop[ letters, k ], i < n, args[[ ++i ]], True, None ] }
                ];
                Break[ ]
            ],
            { k, Length @ letters }
        ];
        i++
    ];
    Cases[ Internal`BagPart[ values, All ], { _String, _String } ]
];

sshOptionValues[ _ ] := { };

sshOptionValues // endDefinition;


(* The user of the first -l or -o User= *)
optionUser // beginDefinition;
optionUser[ values_List ] := FirstCase[ optionValue[ "l", "user", # ] & /@ values, _String, None ];
optionUser // endDefinition;


(* The port of the first -p or -o Port= (None if it is not a number) *)
optionPort // beginDefinition;

optionPort[ values_List ] := Replace[
    FirstCase[ optionValue[ "p", "port", # ] & /@ values, _String, None ],
    { p_String /; StringMatchQ[ p, RegularExpression[ "[0-9]{1,5}" ] ] :> FromDigits @ p, _ -> None }
];

optionPort // endDefinition;


(* The value of an option given as -<letter> value or as -o <key>=value; None for other options and empty values *)
optionValue // beginDefinition;
optionValue[ letter_String, _, { letter_, value_String } ] /; value =!= "" := value;
optionValue[ _, key_String, { "o", option_String } ] := Replace[ configOption @ option, { { key, value_String } /; value =!= "" :> value, _ -> None } ];
optionValue[ _, _, _ ] := None;
optionValue // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSSHHostLabel*)

(* user@machine (if "Username" is given) or machine, as given: for messages *)
acpSSHHostLabel // beginDefinition;

acpSSHHostLabel[ ssh_Association ] := With[ { user = Lookup[ ssh, "Username", Automatic ], machine = Lookup[ ssh, "MachineName", "" ] },
    If[ StringQ @ user, user <> "@" <> machine, machine ]
];

acpSSHHostLabel[ _ ] := None;

acpSSHHostLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSSHShortHost*)

(* For the folder row, the window title and the status line: an IPv4 or IPv6 address whole, a DNS name up to its first
   dot (ec2-203-0-113-100.compute-1.amazonaws.com gives ec2-203-0-113-100), an ssh config alias as it is *)
acpSSHShortHost // beginDefinition;

acpSSHShortHost[ ssh_Association ] := With[ { machine = Lookup[ ssh, "MachineName", "" ] },
    Which[
        StringMatchQ[ machine, RegularExpression[ "[0-9]{1,3}(\\.[0-9]{1,3}){3}" ] ], machine,
        StringContainsQ[ machine, ":" ], machine,
        StringContainsQ[ machine, "." ] && ! StringStartsQ[ machine, "." ], First @ StringSplit[ machine, "." ],
        True, machine
    ]
];

acpSSHShortHost[ _ ] := None;

acpSSHShortHost // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSSHTerminalCommand*)

(* The command to type in a terminal to connect the way Chatbook does (for the host key and sign-in instructions):
   <"Executable" or ssh> [-l user] <Arguments...> <machine>, each word quoted for the shells of this computer's operating
   system (acpSSHTerminalCommand[ssh, os] for another one) *)
acpSSHTerminalCommand // beginDefinition;

acpSSHTerminalCommand[ ssh_ ] := acpSSHTerminalCommand[ ssh, $OperatingSystem ];

acpSSHTerminalCommand[ ssh_Association, os_String ] := StringRiffle[
    terminalWord[ os, # ] & /@ Join[
        { Replace[ Lookup[ ssh, "Executable", Automatic ], Except[ _String ] -> "ssh" ] },
        If[ StringQ @ Lookup[ ssh, "Username", Automatic ], { "-l", ssh[ "Username" ] }, { } ],
        Lookup[ ssh, "Arguments", { } ],
        { Lookup[ ssh, "MachineName", "" ] }
    ],
    " "
];

acpSSHTerminalCommand[ _, _ ] := None;

acpSSHTerminalCommand // endDefinition;


(* A word of the terminal command, as is if it has only characters that no shell of the system treats specially, else
   quoted. Windows: in double quotes by the rules of the C runtime that ssh.exe parses its command line with: " as \",
   and backslashes doubled before a quote and at the end. cmd.exe passes that on as typed, unless a word with a " also
   contains & | < > or ^ (cmd's own quoting toggles at every "); PowerShell also expands $ and ` in double quotes. No
   one quoting fits every Windows shell, so such options are better kept in the ssh config file. Other systems: POSIX
   single quotes, with ' as '\''. *)
terminalWord // beginDefinition;

terminalWord[ "Windows", word_String ] := If[ word =!= "" && StringMatchQ[ word, $windowsPlainWord ],
    word,
    "\"" <> StringReplace[
        word,
        {
            b: "\\"... ~~ "\""       :> StringRepeat[ "\\", 2 * StringLength @ b + 1 ] <> "\"",
            b: "\\".. ~~ EndOfString :> StringRepeat[ "\\", 2 * StringLength @ b ]
        }
    ] <> "\""
];

terminalWord[ _, word_String ] := If[ word =!= "" && StringMatchQ[ word, $posixPlainWord ] && ! StringStartsQ[ word, "=" ],
    word,
    "'" <> StringReplace[ word, "'" -> "'\\''" ] <> "'"
];

terminalWord // endDefinition;

(* No white space, quotes or characters that cmd.exe, PowerShell or a POSIX shell (a leading "=": zsh) read specially.
   % is plain on Windows too: double quotes wouldn't keep cmd.exe from expanding a %NAME% that is defined, and it
   passes an undefined one (ssh's own %h, %p) on as typed *)
$windowsPlainWord = RegularExpression[ "[\\p{L}\\p{N}_@%+=:./\\\\~-]+" ];
$posixPlainWord   = RegularExpression[ "[\\p{L}\\p{N}_@%+=:,./~-]+" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Preference keys*)

(* Per-host preferences ({"SSH", hostKey, ...} under $acpPreferencesPath). None for invalid settings: writers skip a
   None key, so nothing is persisted under a made-up host. Behind one function, so that a hashed key is a one-line change
   if the front end mishandles keys with "@", ":" or ".". *)
acpSSHPreferenceKey // beginDefinition;
acpSSHPreferenceKey[ ssh_Association ] := { "SSH", acpSSHHostKey @ ssh };
acpSSHPreferenceKey[ _ ] := None;
acpSSHPreferenceKey // endDefinition;


(* The preference that holds the last project folder: the local one for local windows, the host's for remote ones *)
acpLastProjectDirectoryKey // beginDefinition;
acpLastProjectDirectoryKey[ None ] := { "LastProjectDirectory" };
acpLastProjectDirectoryKey[ ssh_Association ] := Append[ acpSSHPreferenceKey @ ssh, "LastProjectDirectory" ];
acpLastProjectDirectoryKey[ _ ] := None;
acpLastProjectDirectoryKey // endDefinition;


(* The preference that holds a host's home folder *)
acpRemoteHomeKey // beginDefinition;
acpRemoteHomeKey[ ssh_Association ] := Append[ acpSSHPreferenceKey @ ssh, "Home" ];
acpRemoteHomeKey[ _ ] := None;
acpRemoteHomeKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ssh*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFindSSH*)

(* The absolute path of the local ssh program, or Failure[ "SSHNotFound", ... ]. Without RunProcess (it can hang while
   an ACP reader is active): "Executable" is looked up like an agent's program; Automatic looks in PATH and the usual
   folders, and on Windows in the folders of Windows' OpenSSH Client and of Git for Windows. acpFindSSH[ssh, env] looks
   in env (as acpFindProgram; for tests). *)
acpFindSSH // beginDefinition;

acpFindSSH[ ssh_Association ] := acpFindSSH[ ssh, acpProgramEnvironment[ ] ];

acpFindSSH[ ssh_Association, env_Association ] := Module[ { windowsQ, program, path },
    windowsQ = Lookup[ env, "OperatingSystem", $OperatingSystem ] === "Windows";
    program  = Lookup[ ssh, "Executable", Automatic ];
    path = If[ StringQ @ program,
        acpFindProgram[ program, env ],
        Replace[
            acpFindProgram[ "ssh", <| env, "HomeDirectory" -> None, "SystemDirectories" -> $sshSystemDirectories |> ],
            None :> If[ windowsQ, SelectFirst[ windowsSSHLocations[ ], acpExecutableFileQ, None ], None ]
        ]
    ];
    If[ StringQ @ path, path, sshNotFound[ windowsQ, program ] ]
];

acpFindSSH[ _, env_Association ] := sshNotFound[ Lookup[ env, "OperatingSystem", $OperatingSystem ] === "Windows", Automatic ];
acpFindSSH[ _ ] := sshNotFound[ $OperatingSystem === "Windows", Automatic ];

acpFindSSH // endDefinition;


(* An "Executable" that was not found is named in the error ("Path", which the error texts show display-safe), so that
   a typo in it is not mistaken for a missing OpenSSH client *)
sshNotFound // beginDefinition;

sshNotFound[ windowsQ_, program_String ] := Failure[ "SSHNotFound", <|
    "MessageTemplate"   -> acpConnectionLabel[ "ErrorSSHNotFoundPath" ],
    "MessageParameters" -> <| "path" -> acpRemoteDisplayName @ program |>,
    "Windows"           -> TrueQ @ windowsQ,
    "Path"              -> program
|> ];

sshNotFound[ windowsQ_, _ ] := Failure[ "SSHNotFound", <|
    "MessageTemplate"   -> acpConnectionLabel[ "ErrorSSHNotFound" ],
    "MessageParameters" -> { },
    "Windows"           -> TrueQ @ windowsQ
|> ];

sshNotFound // endDefinition;


(* Windows' OpenSSH Client, then a separately installed OpenSSH, then Git for Windows' ssh *)
windowsSSHLocations // beginDefinition;

windowsSSHLocations[ ] := Cases[
    {
        { Environment[ "SystemRoot" ], "System32", "OpenSSH", "ssh.exe" },
        { Environment[ "ProgramFiles" ], "OpenSSH", "ssh.exe" },
        { Environment[ "ProgramFiles" ], "Git", "usr", "bin", "ssh.exe" }
    },
    { root_String, rest__ } :> FileNameJoin @ { root, rest }
];

windowsSSHLocations // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSSHEnvironment*)

(* The environment of every ssh process: the kernel's (as for local agents) plus SSH_ASKPASS_REQUIRE=never, so that no
   hop (e.g. a jump host, which command-line options don't reach) can open an askpass dialog; OpenSSH < 8.4 ignores it.
   Nothing of it reaches the remote machine except ssh's own SendEnv variables. *)
acpSSHEnvironment // beginDefinition;
acpSSHEnvironment[ ] := Join[ acpInheritedEnvironment[ ], <| "SSH_ASKPASS_REQUIRE" -> "never" |> ];
acpSSHEnvironment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSSHCommand*)

(* The ssh command line that runs remoteCommand: the fixed options (first: they win over the user's ssh config and
   "Arguments"), -l user (the first -l wins), the user's "Arguments", the default options (the user's win), then -T (last:
   it beats a user's -t/-tt), "--" (a host name can't be taken for an option) and the host. ssh is the canonical settings
   plus "Program" (from acpFindSSH). *)
acpSSHCommand // beginDefinition;

acpSSHCommand[ ssh_Association, remoteCommand_String ] := Join[
    { Lookup[ ssh, "Program", Replace[ Lookup[ ssh, "Executable", Automatic ], Except[ _String ] -> "ssh" ] ] },
    $acpSSHFixedOptions,
    If[ StringQ @ Lookup[ ssh, "Username", Automatic ], { "-l", ssh[ "Username" ] }, { } ],
    Lookup[ ssh, "Arguments", { } ],
    $acpSSHDefaultOptions,
    { "-T", "--", ssh[ "MachineName" ], remoteCommand }
];

acpSSHCommand // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Remote paths*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Quoting*)

(* A string as one word of a POSIX shell command; a Failure for a string with a NUL character, which no shell word can
   hold *)
acpShellQuote // beginDefinition;

acpShellQuote[ s_String ] /; StringContainsQ[ s, FromCharacterCode[ 0 ] ] := Failure[ "InvalidShellValue", <|
    "MessageTemplate"   -> "A value for a remote command contains a NUL character.",
    "MessageParameters" -> { }
|> ];

acpShellQuote[ s_String ] := "'" <> StringReplace[ s, "'" -> "'\\''" ] <> "'";

acpShellQuote // endDefinition;


acpShellWords // beginDefinition;

acpShellWords[ words: { ___String } ] := With[ { quoted = acpShellQuote /@ words },
    If[ AllTrue[ quoted, StringQ ], StringRiffle[ quoted, " " ], FirstCase[ quoted, _Failure ] ]
];

acpShellWords // endDefinition;


(* A remote path as a shell word: "~" and "~/..." relative to the remote home ($HOME), others quoted as they are
   (~user is not supported) *)
acpRemotePathWord // beginDefinition;
acpRemotePathWord[ "~" ] := "\"$HOME\"";
acpRemotePathWord[ path_String ] /; StringStartsQ[ path, "~/" ] := With[ { rest = StringDrop[ path, 2 ] },
    If[ rest === "", "\"$HOME\"/", Replace[ acpShellQuote @ rest, q_String :> "\"$HOME\"/" <> q ] ]
];
acpRemotePathWord[ path_String ] := acpShellQuote @ path;
acpRemotePathWord // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Validity*)

(* A folder path for a remote window: absolute, ~ or ~/..., without control characters (the launch script is one line
   and OpenCode's cwd is JSON), at most $acpRemoteMaxPathLength characters. Syntax only. *)
acpRemoteProjectDirectoryQ // beginDefinition;

acpRemoteProjectDirectoryQ[ s_String ] := StringLength @ s <= $acpRemoteMaxPathLength && StringMatchQ[
    s,
    RegularExpression[ "~|~/[^\\x00-\\x1f\\x7f]*|/[^\\x00-\\x1f\\x7f]*" ]
];

acpRemoteProjectDirectoryQ[ _ ] := False;

acpRemoteProjectDirectoryQ // endDefinition;


(* An "ACPAgentCommandLine" that can be sent to the remote machine: Automatic, a program, or { program, args... }; no
   control characters anywhere, and the program is not empty, does not start with "-", and does not start with "~"
   unless with "~/" *)
acpRemoteCommandLineQ // beginDefinition;
acpRemoteCommandLineQ[ Automatic ] := True;
acpRemoteCommandLineQ[ File[ program_String ] ] := remoteProgramQ @ program;
acpRemoteCommandLineQ[ program_String ] := remoteProgramQ @ program;
acpRemoteCommandLineQ[ { File[ program_String ], args___String } ] := acpRemoteCommandLineQ @ { program, args };
acpRemoteCommandLineQ[ { program_String, args___String } ] :=
    remoteProgramQ @ program && NoneTrue[ { args }, StringContainsQ[ #, $controlCharacter ] & ];
acpRemoteCommandLineQ[ _ ] := False;
acpRemoteCommandLineQ // endDefinition;


remoteProgramQ // beginDefinition;

remoteProgramQ[ program_String ] := With[ { p = StringTrim @ program },
    p =!= "" &&
        ! StringContainsQ[ program, $controlCharacter ] &&
        ! StringStartsQ[ p, "-" ] &&
        (! StringStartsQ[ p, "~" ] || StringStartsQ[ p, "~/" ])
];

remoteProgramQ // endDefinition;


(* The gate for every path that comes from the remote machine (home folder, folders, the agent's path): absolute, no
   control characters, at most $acpRemoteMaxPathLength characters *)
acpRemoteAbsolutePathQ // beginDefinition;

acpRemoteAbsolutePathQ[ s_String ] :=
    StringLength @ s <= $acpRemoteMaxPathLength && StringStartsQ[ s, "/" ] && ! StringContainsQ[ s, $controlCharacter ];

acpRemoteAbsolutePathQ[ _ ] := False;

acpRemoteAbsolutePathQ // endDefinition;


(* A path from the remote machine if acpRemoteAbsolutePathQ, else None; a rejected value is logged with the name of its
   key only (never the value) *)
acpRemoteCheckedPath // beginDefinition;

acpRemoteCheckedPath[ value_, key_String ] := Which[
    acpRemoteAbsolutePathQ @ value, value,
    MissingQ @ value || value === None, None,
    True, acpLog[ "RemoteValueRejected", <| "Key" -> key |> ]; None
];

acpRemoteCheckedPath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Home folder*)

(* /home/u/x gives ~/x and /home/u gives ~, if home is /home/u; unchanged for an unknown, "/" or relative home, and for
   other users' paths *)
acpRemoteAbbreviate // beginDefinition;

acpRemoteAbbreviate[ path_String, home0_String ] := With[ { home = dropTrailingSlashes @ home0 },
    Which[
        ! StringStartsQ[ home, "/" ] || home === "/", path,
        path === home, "~",
        StringStartsQ[ path, home <> "/" ], "~" <> StringDrop[ path, StringLength @ home ],
        True, path
    ]
];

acpRemoteAbbreviate[ path_, _ ] := path;

acpRemoteAbbreviate // endDefinition;


(* ~ and ~/x as absolute paths, if the home folder is known; otherwise unchanged *)
acpRemoteExpandHome // beginDefinition;

acpRemoteExpandHome[ path_String, home0_String ] /; StringStartsQ[ home0, "/" ] := With[ { home = dropTrailingSlashes @ home0 },
    Which[
        path === "~", home,
        StringStartsQ[ path, "~/" ], If[ home === "/", "", home ] <> StringDrop[ path, 1 ],
        True, path
    ]
];

acpRemoteExpandHome[ path_, _ ] := path;

acpRemoteExpandHome // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteNormalizeDirectory*)

(* A remote folder setting as a window keeps it (or None): File[ p ] is p, trimmed, ~ expanded when the home is known,
   trailing "/" dropped (not for "/"). Never ExpandFileName, which turns /home/x into C:\home\x on Windows. With
   "Raw" -> True (agent-provided or already normalized folders) the string is not trimmed: a folder name may end in a
   space. *)
acpRemoteNormalizeDirectory // beginDefinition;

acpRemoteNormalizeDirectory[ dir_, home_ ] := acpRemoteNormalizeDirectory[ dir, home, "Raw" -> False ];

acpRemoteNormalizeDirectory[ File[ dir_String ], home_, raw_ ] := acpRemoteNormalizeDirectory[ dir, home, raw ];

acpRemoteNormalizeDirectory[ dir0_String, home_, "Raw" -> raw_ ] := With[ { dir = If[ TrueQ @ raw, dir0, StringTrim @ dir0 ] },
    If[ dir === "", None, dropTrailingSlashes @ acpRemoteExpandHome[ dir, home ] ]
];

acpRemoteNormalizeDirectory[ _, _, _ ] := None;

acpRemoteNormalizeDirectory // endDefinition;


dropTrailingSlashes // beginDefinition;
dropTrailingSlashes[ path_String ] := If[ StringEndsQ[ path, "/" ], Replace[ StringDelete[ path, "/".. ~~ EndOfString ], "" -> "/" ], path ];
dropTrailingSlashes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*POSIX path operations*)

(* "/a/./b/../c//" gives "/a/c": lexical only (links are not resolved); relative paths are unchanged *)
acpRemoteLexicalPath // beginDefinition;

acpRemoteLexicalPath[ path_String ] /; StringStartsQ[ path, "/" ] := Module[ { parts = { } },
    Scan[
        Switch[ #, "" | ".", Null, "..", If[ parts =!= { }, parts = Most @ parts ], _, AppendTo[ parts, # ] ] &,
        StringSplit[ path, "/", All ]
    ];
    "/" <> StringRiffle[ parts, "/" ]
];

acpRemoteLexicalPath[ path_ ] := path;

acpRemoteLexicalPath // endDefinition;


(* /a/b gives /a, /a gives /, / gives /; ~/x gives ~ *)
acpRemoteParent // beginDefinition;

acpRemoteParent[ path_String ] /; StringStartsQ[ path, "/" ] :=
    Replace[ StringDelete[ acpRemoteLexicalPath @ path, "/" ~~ Except[ "/" ]... ~~ EndOfString ], "" -> "/" ];

acpRemoteParent[ path_String ] := With[ { p = dropTrailingSlashes @ path },
    If[ StringContainsQ[ p, "/" ], dropTrailingSlashes @ StringDelete[ p, "/" ~~ Except[ "/" ]... ~~ EndOfString ], p ]
];

acpRemoteParent // endDefinition;


(* A name in a folder, without a doubled "/" *)
acpRemoteChild // beginDefinition;
acpRemoteChild[ path_String, name_String ] := If[ StringEndsQ[ path, "/" ], path <> name, path <> "/" <> name ];
acpRemoteChild // endDefinition;


(* The last component of a path ("/" for the root) *)
acpRemotePathName // beginDefinition;
acpRemotePathName[ path_String ] := With[ { p = dropTrailingSlashes @ path },
    If[ p === "/", "/", Last[ StringSplit[ p, "/" ], p ] ]
];
acpRemotePathName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteDisplayName*)

(* Remote text (a name or a path) for display: line breaks and tabs as visible symbols, other control characters as
   U+FFFD, and as a visible [[U+XXXX]] the C1 controls, the line and paragraph separators (U+2028, U+2029) and every
   character that Unicode's Default_Ignorable_Code_Point property says to draw as nothing: the bidi controls (ALM U+061C
   included), zero width characters and joiners, the soft hyphen, fillers such as U+3164, variation selectors (an
   emoji's U+FE0F too: a run of them can carry hidden text), tag characters and the reserved code points of those
   blocks. So "evil<U+202E>txt.exe" can't pass for another name, no text hides in a name, and a name always shows as one
   line; letters of right-to-left scripts are unchanged. Then acpNeutralizeLinearSyntax. The only way remote names reach
   boxes. *)
acpRemoteDisplayName // beginDefinition;
acpRemoteDisplayName[ s_String ] := acpNeutralizeLinearSyntax @ StringReplace[ s, $displayNameRules ];
acpRemoteDisplayName[ other_ ] := other;
acpRemoteDisplayName // endDefinition;


$displayNameRules := $displayNameRules = {
    "\n" -> "\:2424",
    "\r" -> "\:240d",
    "\t" -> "\:2409",
    Alternatives @@ Join[
        CharacterRange[ 0, 8 ],
        CharacterRange[ 11, 12 ],
        CharacterRange[ 14, 31 ],
        { FromCharacterCode[ 127 ] }
    ] -> "\:fffd",
    c: RegularExpression @ $visibleCodePoints :> "\:27e6U+" <> codePointHex @ First @ ToCharacterCode @ c <> "\:27e7"
};

(* One character class: a regular expression stays fast with the 4096 code points of the tags block *)
$visibleCodePoints = StringJoin[
    "[",
    "\\x{80}-\\x{9F}",          (* C1 controls *)
    "\\x{AD}",                  (* soft hyphen *)
    "\\x{34F}",                 (* combining grapheme joiner *)
    "\\x{61C}",                 (* Arabic letter mark (a bidi control) *)
    "\\x{115F}\\x{1160}",       (* Hangul choseong and jungseong fillers *)
    "\\x{17B4}\\x{17B5}",       (* Khmer inherent vowels *)
    "\\x{180B}-\\x{180F}",      (* Mongolian free variation selectors and vowel separator *)
    "\\x{200B}-\\x{200F}",      (* zero width space, joiners, LRM, RLM *)
    "\\x{2028}-\\x{202E}",      (* line and paragraph separators; embeddings and overrides *)
    "\\x{2060}-\\x{206F}",      (* word joiner, invisible operators, isolates, deprecated format characters *)
    "\\x{3164}",                (* Hangul filler *)
    "\\x{FE00}-\\x{FE0F}",      (* variation selectors *)
    "\\x{FEFF}",                (* byte order mark *)
    "\\x{FFA0}",                (* halfwidth Hangul filler *)
    "\\x{FFF0}-\\x{FFF8}",      (* reserved, default ignorable *)
    "\\x{1BCA0}-\\x{1BCA3}",    (* shorthand format controls *)
    "\\x{1D173}-\\x{1D17A}",    (* musical symbol format controls *)
    "\\x{E0000}-\\x{E0FFF}",    (* tag characters, variation selectors supplement, reserved *)
    "]"
];


(* At least four hex digits: five for a code point beyond U+FFFF (IntegerString[n, 16, 4] would cut them) *)
codePointHex // beginDefinition;
codePointHex[ code_Integer ] := ToUpperCase @ IntegerString[ code, 16, Max[ 4, IntegerLength[ code, 16 ] ] ];
codePointHex // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRemoteFolderLabel*)

(* { host, path } for display in at most about max characters: the host cut to 16 characters, the path abbreviated
   with the home folder and kept from its end in whole names: "\[Ellipsis]/" and as many of its last names as fit, so the
   folder's own name is never cut (unless it alone is too long: then its middle is) *)
acpRemoteFolderLabel // beginDefinition;

acpRemoteFolderLabel[ short_String, path_String, home_, max_Integer ] := Module[ { host, display, room },
    host    = If[ StringLength @ short > 16, StringTake[ short, 15 ] <> "\[Ellipsis]", short ];
    display = acpRemoteDisplayName @ acpRemoteAbbreviate[ path, home ];
    room    = Max[ 12, max - StringLength @ host - 1 ];
    { host, shortenPathEnd[ display, room ] }
];

acpRemoteFolderLabel // endDefinition;


(* A path in at most n characters: as it is, else "\[Ellipsis]/" and its last names (the last one always, its middle cut if
   that alone is too long) *)
shortenPathEnd // beginDefinition;

shortenPathEnd[ path_String, n_Integer ] /; StringLength @ path <= n := path;

shortenPathEnd[ path_String, n_Integer ] := Module[ { names, tail },
    names = DeleteCases[ StringSplit[ path, "/" ], "" ];
    If[ names === { }, Return[ shortenMiddle[ path, n ], Module ] ];
    tail = { Last @ names };
    Do[
        If[ StringLength @ StringRiffle[ Prepend[ tail, names[[ i ]] ], "/" ] + 2 <= n, PrependTo[ tail, names[[ i ]] ], Break[ ] ],
        { i, Length @ names - 1, 1, -1 }
    ];
    If[ StringLength @ First @ tail + 2 > n,
        "\[Ellipsis]/" <> shortenMiddle[ First @ tail, n - 2 ],
        "\[Ellipsis]/" <> StringRiffle[ tail, "/" ]
    ]
];

shortenPathEnd // endDefinition;


(* A name in at most n characters, its middle replaced by an ellipsis *)
shortenMiddle // beginDefinition;

shortenMiddle[ s_String, n_Integer ] /; StringLength @ s <= n := s;

shortenMiddle[ s_String, n_Integer ] := With[ { head = Ceiling[ (n - 1) / 2 ] },
    StringTake[ s, head ] <> "\[Ellipsis]" <> StringTake[ s, -(n - 1 - head) ]
];

shortenMiddle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Launch script*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSSHLaunchNonce*)

(* A new nonce for each launch: 16 lower-case hex characters *)
acpSSHLaunchNonce // beginDefinition;
acpSSHLaunchNonce[ ] := StringTake[ ToLowerCase @ StringDelete[ CreateUUID[ ], "-" ], 16 ];
acpSSHLaunchNonce // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSSHLaunchScript*)

(* The launch script: ONE line (ending in "\n") that $acpSSHLaunchCommand reads and evaluates on the remote machine. It
   exports the variables, reports the home folder, enters the project folder (~ and ~/... relative to the remote home)
   and reports it, finds the agent's program (a path, or a name in the remote PATH and the usual install folders),
   reports it, and runs the agent with its arguments in the project folder. Every value is a single-quoted word.
   Markers on standard error: chatbook-acp:<nonce>:home|cwd|agent:<path> and :error:<kind>:<value> (exit 120 for the
   folder, 127 for the agent). The agent is not exec'd: the launch shell waits and exits with its exit code, so an
   agent killed by signal n gives 128+n (and the shell's "Killed" line) instead of ssh's silent exit 255.
   Gives Failure[ "InvalidLaunchValue", ... ] if a value contains a line break or NUL, or a variable name is not a shell
   name. The script may contain secrets (the variables): it is only ever written to ssh's standard input, and nothing
   here logs it or puts a value into a Failure. *)
acpSSHLaunchScript // beginDefinition;

acpSSHLaunchScript[ nonce_String, dir_String, { program_String, args___String }, vars_Association ] := Module[ { statements },
    If[ ! AllTrue[ Keys @ vars, StringQ[ # ] && StringMatchQ[ #, RegularExpression[ "[A-Za-z_][A-Za-z0-9_]*" ] ] & ],
        Return[ launchValueFailure[ "VariableName" ], Module ]
    ];
    If[ ! AllTrue[ Join[ { nonce, dir, program, args }, Values @ vars ], launchValueQ ],
        Return[ launchValueFailure[ "Value" ], Module ]
    ];
    statements = {
        "unset IFS",
        "set +f",
        If[ vars === <| |>, Nothing, "export " <> StringRiffle[ KeyValueMap[ #1 <> "=" <> acpShellQuote[ #2 ] &, vars ], " " ] ],
        "m=" <> acpShellQuote[ $acpSSHMarkerPrefix <> nonce ],
        "printf '%s:home:%s\\n' \"$m\" \"$HOME\" >&2",
        "d=" <> acpShellQuote @ dir,
        "case $d in '~') d=$HOME;; '~/'*) d=$HOME/${d#??};; esac",
        "if [ ! -d \"$d\" ]; then if [ -e \"$d\" ]; then r=not-a-folder; else r=no-folder; fi; \
printf '%s:error:%s:%s\\n' \"$m\" \"$r\" \"$d\" >&2; exit 120; fi",
        "cd \"$d\" || { printf '%s:error:folder-access:%s\\n' \"$m\" \"$d\" >&2; exit 120; }",
        "printf '%s:cwd:%s\\n' \"$m\" \"$PWD\" >&2",
        "p=",
        "n=" <> acpShellQuote @ program,
        "r() { case $1 in /*) if [ -f \"$1\" ] && [ -x \"$1\" ]; then p=$1; fi;; esac; }",
        "case $n in '~/'*) r \"$HOME/${n#??}\";; /*) r \"$n\";; */*) r \"$PWD/$n\";; *) set -f; IFS=:; for x in $PATH " <>
            StringRiffle[ $launchSearchDirectories, " " ] <>
            "; do if [ -z \"$p\" ] && [ -n \"$x\" ]; then r \"$x/$n\"; fi; done; unset IFS; set +f;; esac",
        "if [ -z \"$p\" ]; then printf '%s:error:no-agent:%s\\n' \"$m\" \"$n\" >&2; exit 127; fi",
        "case :$PATH: in *\":${p%/*}:\"*) ;; *) if [ -n \"${p%/*}\" ]; then PATH=${p%/*}:$PATH; export PATH; fi;; esac",
        "printf '%s:agent:%s\\n' \"$m\" \"$p\" >&2",
        "\"$p\"" <> StringJoin[ " " <> acpShellQuote[ # ] & /@ { args } ] <> "; exit $?"
    };
    StringRiffle[ statements, "; " ] <> "\n"
];

acpSSHLaunchScript[ nonce_, dir_, command_, vars: { (_Rule|_RuleDelayed)... } ] :=
    acpSSHLaunchScript[ nonce, dir, command, Association @ vars ];

acpSSHLaunchScript[ _, _, _, _ ] := launchValueFailure[ "Value" ];

acpSSHLaunchScript // endDefinition;


(* A value that fits into the one-line script *)
launchValueQ // beginDefinition;
launchValueQ[ s_String ] := ! StringContainsQ[ s, "\n" | "\r" | FromCharacterCode[ 0 ] ];
launchValueQ[ _ ] := False;
launchValueQ // endDefinition;


(* Never holds a value: the values may be secrets *)
launchValueFailure // beginDefinition;

launchValueFailure[ reason_String ] := Failure[ "InvalidLaunchValue", <|
    "MessageTemplate"   -> "The agent's command line, folder or environment can't be sent to the remote machine.",
    "MessageParameters" -> { },
    "Reason"            -> reason
|> ];

launchValueFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Markers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSSHLaunchMarkers*)

(* The markers of one launch (its nonce) in ssh's standard error: <| "Home", "Cwd", "Agent" -> path | None,
   "Error" -> { kind, value } | None |>. Lines with another nonce (startup files, the agent) are ignored; values may
   contain ":". Home, Cwd and Agent are kept only if acpRemoteAbsolutePathQ ("RemoteValueRejected" is logged otherwise).
   The launch script prints the home and the current folder each right before another marker, so a home or folder with
   a line break shows up as a marker line followed by a line that is not a marker: such a value is rejected too. *)
acpSSHLaunchMarkers // beginDefinition;

acpSSHLaunchMarkers[ nonce_String, stderr_ ] := markerValues @ launchMarkers[ nonce, stderrHead @ stderr ];

acpSSHLaunchMarkers // endDefinition;


markerValues // beginDefinition;

markerValues[ markers_List ] := <|
    "Home"  -> markerPath[ markers, "home" , "Home" , True  ],
    "Cwd"   -> markerPath[ markers, "cwd"  , "Cwd"  , True  ],
    "Agent" -> markerPath[ markers, "agent", "Agent", False ],
    "Error" -> FirstCase[ markers, { "error", value_, _ } :> splitOnce @ value, None ]
|>;

markerValues // endDefinition;


(* The path of the first marker with the key (None if there is none); with followedQ, a value that is not followed by
   another marker is rejected (the path had a line break, or the launch failed right after the marker) *)
markerPath // beginDefinition;

markerPath[ markers_List, key_String, name_String, followedQ_ ] := Replace[
    FirstCase[ markers, { key, value_, next_ } :> { value, next }, None ],
    {
        None                                          :> None,
        { _, False } /; followedQ                     :> (acpLog[ "RemoteValueRejected", <| "Key" -> name |> ]; None),
        { value_, _ }                                 :> acpRemoteCheckedPath[ value, name ]
    }
];

markerPath // endDefinition;


(* { { key, value, followedByMarkerQ }, ... } for the marker lines of a nonce, in order *)
launchMarkers // beginDefinition;

launchMarkers[ nonce_String, text_String ] := Module[ { prefix, lines, markerQ },
    prefix  = $acpSSHMarkerPrefix <> nonce <> ":";
    lines   = StringSplit[ text, { "\r\n", "\r", "\n" } ];
    markerQ = StringStartsQ[ lines, prefix ];
    Map[
        Append[ splitOnce @ StringDrop[ lines[[ # ]], StringLength @ prefix ], # < Length @ lines && markerQ[[ # + 1 ]] ] &,
        Flatten @ Position[ markerQ, True ]
    ]
];

launchMarkers[ None, _ ] := { };

launchMarkers // endDefinition;


(* "a:b:c" gives { "a", "b:c" }; "a" gives { "a", "" } *)
splitOnce // beginDefinition;

splitOnce[ s_String ] := Replace[
    StringPosition[ s, ":", 1 ],
    { { { i_, _ } } :> { StringTake[ s, i - 1 ], StringDrop[ s, i ] }, _ :> { s, "" } }
];

splitOnce // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Standard error text*)

(* ssh's standard error is a string, a ByteArray (one-shot runs) or missing. Only its first and its last
   $acpRemoteClassifyBytes are ever looked at: the markers are at the start, ssh's own message is at the end. *)
stderrHead // beginDefinition;
stderrHead[ s_String ] := If[ StringLength @ s > $acpRemoteClassifyBytes, StringTake[ s, $acpRemoteClassifyBytes ], s ];
stderrHead[ b_ByteArray ] := decodeStderr @ If[ Length @ b > $acpRemoteClassifyBytes, Take[ b, $acpRemoteClassifyBytes ], b ];
stderrHead[ _ ] := "";
stderrHead // endDefinition;


(* The end of standard error, without a first line that was cut (unless it is the only one) *)
stderrEnd // beginDefinition;

stderrEnd[ s_String ] := If[ StringLength @ s > $acpRemoteClassifyBytes, dropPartialLine @ StringTake[ s, -$acpRemoteClassifyBytes ], s ];

stderrEnd[ b_ByteArray ] := If[ Length @ b > $acpRemoteClassifyBytes,
    dropPartialLine @ decodeStderr @ Take[ b, -$acpRemoteClassifyBytes ],
    decodeStderr @ b
];

stderrEnd[ _ ] := "";

stderrEnd // endDefinition;


dropPartialLine // beginDefinition;
dropPartialLine[ s_String ] := Replace[ StringPosition[ s, "\n", 1 ], { { { i_, _ } } :> StringDrop[ s, i ], _ :> s } ];
dropPartialLine // endDefinition;


(* UTF-8 if the bytes are valid UTF-8, else ISO 8859-1 (ByteArrayToString gives a Latin-1 decoding with a message for
   invalid UTF-8) *)
decodeStderr // beginDefinition;

decodeStderr[ b_ByteArray ] := With[ { s = Quiet @ ByteArrayToString[ b, "UTF-8" ] },
    If[ StringQ @ s && Quiet @ StringToByteArray[ s, "UTF-8" ] === b, s, ByteArrayToString[ b, "ISOLatin1" ] ]
];

decodeStderr[ _ ] := "";

decodeStderr // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Exit classification*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSSHExitKind*)

(* The error kind of an ssh process that ended (the agent's connection, or a one-shot run that never began its script):
   acpSSHExitKind[ exitCode, stderr, <| "Setup" -> setupQ, "Nonce" -> nonce |> ]. exitCode is an integer, or Missing
   when the connection is gone without one; stderr is ssh's standard error (with the launch markers for the nonce);
   setupQ is True while the session is being set up. See analyzeSSHExit for the rules. *)
acpSSHExitKind // beginDefinition;
acpSSHExitKind[ exitCode_, stderr_ ] := acpSSHExitKind[ exitCode, stderr, <| |> ];
acpSSHExitKind[ exitCode_, stderr_, context_Association ] := analyzeSSHExit[ exitCode, stderr, context ][ "Kind" ];
acpSSHExitKind // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*analyzeSSHExit*)

(* <| "Kind", "ExitCode", "Markers" (as acpSSHLaunchMarkers), "HomeQ", "AgentQ" (whether those markers arrived), "Tail"
   (the end of stderr), "Nonce", "Text" (the end of stderr in lower case without the launch's markers, debug1: lines,
   the trigger line and the "Unsupported option" line of an ssh without GSSAPI) |>.
   The rules, first match wins; the patterns are case-insensitive literal strings (plus one linear regex) matched on at
   most the last $acpRemoteClassifyBytes of the text:
     1-3   the launch's error markers: RemoteFolderMissing, RemoteFolderAccess, RemoteAgentNotFound;
     4     SSHConnectionLost: after setup, no exit code or 255 with ssh's text for a connection that ended; during
           setup, 255 with that text after the home marker;
     5-11  ssh's own failures, only before the home marker (afterwards ssh had connected, and the text is the agent's):
           SSHHostKeyChanged (before 5: its text ends like 6's), SSHHostKeyUnknown, SSHAuthFailed, SSHHostNotFound,
           SSHConnectionRefused, SSHUnreachable, SSHBadArguments. Before them all, ssh's line for a TCP connection that
           couldn't be made gives SSHUnreachable whatever the system's text for the error, unless the connection was
           refused (9): ssh saw no host key and tried no sign-in, so a firewall's "Permission denied" (EACCES, or
           Win32-OpenSSH's unmapped WSAEACCES) is not SSHAuthFailed;
     12-13 125 (standard input ended before the script) or 255 without the home marker: SSHFailed;
     14    another exit code without the home marker (the login shell never ran the bootstrap: nologin, a restricted
           shell, ForceCommand): RemoteScriptFailed;
     15    otherwise RemoteAgentExited. *)
analyzeSSHExit // beginDefinition;

analyzeSSHExit[ exitCode0_, stderr_, context_Association ] := Module[
    { exitCode, setupQ, nonce, markers, homeQ, agentQ, tail, text, error, kind },

    exitCode = Replace[ exitCode0, Except[ _Integer ] -> Missing[ "NoExitCode" ] ];
    setupQ   = TrueQ @ Lookup[ context, "Setup", True ];
    nonce    = Replace[ Lookup[ context, "Nonce", None ], Except[ _String? (StringMatchQ[ #, RegularExpression[ "[0-9A-Za-z]+" ] ] &) ] -> None ];
    markers  = launchMarkers[ nonce, stderrHead @ stderr ];
    homeQ    = MemberQ[ markers, { "home", __ } ];
    agentQ   = MemberQ[ markers, { "agent", __ } ];
    error    = FirstCase[ markers, { "error", value_, _ } :> First @ splitOnce @ value, None ];
    tail     = stderrEnd @ stderr;
    text     = classificationText[ tail, nonce ];

    kind = Which[
        MatchQ[ error, "no-folder" | "not-a-folder" ], "RemoteFolderMissing",
        error === "folder-access"                     , "RemoteFolderAccess",
        error === "no-agent"                          , "RemoteAgentNotFound",
        If[ setupQ,
            exitCode === 255 && homeQ && disconnectQ @ text,
            MissingQ @ exitCode || exitCode === 255 && disconnectQ @ text
        ], "SSHConnectionLost",
        ! homeQ && connectFailedQ @ text , "SSHUnreachable",
        ! homeQ && hostKeyChangedQ @ text, "SSHHostKeyChanged",
        ! homeQ && containsAnyQ[ text, $hostKeyUnknownTexts ], "SSHHostKeyUnknown",
        ! homeQ && containsAnyQ[ text, $authFailedTexts     ], "SSHAuthFailed",
        ! homeQ && containsAnyQ[ text, $hostNotFoundTexts   ], "SSHHostNotFound",
        ! homeQ && containsAnyQ[ text, $refusedTexts        ], "SSHConnectionRefused",
        ! homeQ && containsAnyQ[ text, $unreachableTexts    ], "SSHUnreachable",
        ! homeQ && containsAnyQ[ text, $badArgumentsTexts   ], "SSHBadArguments",
        ! homeQ && MatchQ[ exitCode, 125 | 255 ]              , "SSHFailed",
        ! homeQ && IntegerQ @ exitCode                        , "RemoteScriptFailed",
        True                                                  , "RemoteAgentExited"
    ];

    <|
        "Kind"     -> kind,
        "ExitCode" -> exitCode,
        "Markers"  -> markerValues @ markers,
        "HomeQ"    -> homeQ,
        "AgentQ"   -> agentQ,
        "Tail"     -> tail,
        "Nonce"    -> nonce,
        "Text"     -> text
    |>
];

analyzeSSHExit // endDefinition;


(* The text that the rules match: the end of stderr in lower case, without the lines that are not ssh's or the remote
   side's text (the launch markers, debug1: lines, the trigger line, and the warning of an ssh without GSSAPI about
   GSSAPIDelegateCredentials). One linear pass. *)
classificationText // beginDefinition;
classificationText[ tail_String, nonce_ ] := StringDelete[ ToLowerCase @ tail, ignoredLinesRegex @ nonce ];
classificationText // endDefinition;


ignoredLinesRegex // beginDefinition;

ignoredLinesRegex[ nonce_ ] := RegularExpression[ StringJoin[
    "(?m)^(?:debug1:[^\\n]*|",
    If[ StringQ @ nonce, "chatbook-acp:" <> ToLowerCase @ nonce <> ":[^\\n]*|", "" ],
    "chatbook-acp-ready\\r?|[^\\n]*unsupported option \"gssapi[^\\n]*)(?:\\n|\\z)"
] ];

ignoredLinesRegex // endDefinition;


(* The same lines of the end of stderr, in their own case, for the error's "Output" *)
textLines // beginDefinition;

textLines[ tail_String, nonce_ ] := Module[ { lines },
    lines = StringSplit[ tail, { "\r\n", "\r", "\n" } ];
    lines = Pick[ lines, StringStartsQ[ lines, If[ StringQ @ nonce, { $acpSSHMarkerPrefix <> nonce <> ":", "debug1:" }, "debug1:" ] ], False ];
    lines = DeleteCases[ lines, $acpSSHLaunchTrigger ];
    Pick[ lines, StringContainsQ[ lines, "unsupported option \"gssapi", IgnoreCase -> True ], False ]
];

textLines // endDefinition;


(* The texts of the rules (lower case; OpenSSH's messages, Windows' and macOS' resolver messages, Win32-OpenSSH's
   network errors). "read from remote host" and $connectFailedText are ssh's own prefixes (clientloop.c, sshconnect.c)
   for an established connection that failed and for a TCP connection that couldn't be made, whatever the system's
   text for the error follows (Windows' ssh.exe gives "Connection aborted" or "Unknown error"). A name that was not
   found has another prefix ("ssh: could not resolve hostname"). *)
$connectFailedText   = "ssh: connect to host ";
$disconnectTexts     = {
    "not responding", "closed by remote host", "broken pipe", "connection reset", "client_loop:", "packet_write_wait",
    "read from remote host"
};
$hostKeyChangedTexts = { "remote host identification has changed" };
$hostKeyUnknownTexts = { "host key verification failed", "host key is known for" };
$authFailedTexts     = { "permission denied", "too many authentication failures", "authentication failed", "no such identity", "bad permissions", "unprotected private key file" };
$hostNotFoundTexts   = { "could not resolve hostname", "no such host is known", "nodename nor servname provided" };
$refusedTexts        = { "connection refused" };
$unreachableTexts    = {
    "connection timed out", "operation timed out", "timed out during banner exchange", "no route to host",
    "network is unreachable", "host is down", "connection reset", "connection closed by", "kex_exchange_identification",
    "host is unreachable", "network unreachable", "network is down"
};
$badArgumentsTexts   = {
    "bad configuration option", "unknown option", "illegal option", "command-line: line",
    "cannot execute command-line and remote command", "missing argument", "bad port", "usage: ssh"
};
$keyPermissionsTexts = { "bad permissions", "unprotected private key file" };
(* "not accessible: no such file", not "not accessible": the key permissions warning says "NOT accessible by others" *)
$keyMissingTexts     = { "no such identity", "not accessible: no such file" };

(* \S+, not .+: .+ backtracks quadratically on a long line *)
$hostKeyChangedRegex = RegularExpression[ "host key for \\S+ has changed" ];


containsAnyQ // beginDefinition;
containsAnyQ[ text_String, literals_List ] := AnyTrue[ literals, StringContainsQ[ text, # ] & ];
containsAnyQ // endDefinition;

disconnectQ // beginDefinition;
disconnectQ[ text_String ] := containsAnyQ[ text, $disconnectTexts ];
disconnectQ // endDefinition;

(* ssh's connect failure, unless refused: a refused connection keeps its own kind *)
connectFailedQ // beginDefinition;
connectFailedQ[ text_String ] := StringContainsQ[ text, $connectFailedText ] && ! containsAnyQ[ text, $refusedTexts ];
connectFailedQ // endDefinition;

hostKeyChangedQ // beginDefinition;
hostKeyChangedQ[ text_String ] := containsAnyQ[ text, $hostKeyChangedTexts ] || StringContainsQ[ text, $hostKeyChangedRegex ];
hostKeyChangedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*SSH errors*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSSHExitError*)

(* The error info (acpErrorInfo, Connection.wl) of an ssh process that ended: the kind of acpSSHExitKind; "Output",
   the end of the text (the last $acpStderrLines lines without markers and secrets, neutralized); "Hints", the keys of
   additional advice; "Path", the folder of an error marker or the window's. Pure (safe in reader handlers).
   context: "Setup", "Nonce", "Agent", "Host", "Command", "Example", "InstallURL", "Windows", "RecentAuthFailure",
   "Path" (the window's folder), "RemoteHome", and "SSH" (the canonical settings, for "Host" and "Command" if they are
   not given). *)
acpSSHExitError // beginDefinition;

acpSSHExitError[ exitCode_, stderr_, context_Association ] :=
    sshErrorInfo[ analyzeSSHExit[ exitCode, stderr, context ], context ];

acpSSHExitError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSSHTimeoutError*)

(* The error of a remote connection whose setup took too long, from ssh's standard error so far: without the home
   marker the launch script never ran (ssh was still connecting or signing in, or a startup file blocked):
   SSHConnectTimeout with ssh's text; with it, the agent did not answer: RemoteTimeout with the end of its text. *)
acpSSHTimeoutError // beginDefinition;

acpSSHTimeoutError[ stderr_, context_Association ] := Module[ { analysis },
    analysis = analyzeSSHExit[ Missing[ "NoExitCode" ], stderr, <| context, "Setup" -> True |> ];
    sshErrorInfo[ <| analysis, "Kind" -> If[ TrueQ @ analysis[ "HomeQ" ], "RemoteTimeout", "SSHConnectTimeout" ] |>, context ]
];

acpSSHTimeoutError // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sshErrorInfo*)

sshErrorInfo // beginDefinition;

sshErrorInfo[ analysis_Association, context_Association ] := Module[ { kind, ssh, markers, home, output, hints, path },
    kind    = analysis[ "Kind" ];
    ssh     = Lookup[ context, "SSH", None ];
    markers = analysis[ "Markers" ];
    home    = Replace[ markers[ "Home" ], None :> Replace[ Lookup[ context, "RemoteHome", None ], Except[ _String? acpRemoteAbsolutePathQ ] -> None ] ];
    output  = If[ MemberQ[ { "RemoteFolderMissing", "RemoteAgentNotFound" }, kind ],
        None,
        sshOutput[ textLines[ analysis[ "Tail" ], analysis[ "Nonce" ] ], kind ]
    ];
    hints   = sshHints[ kind, analysis, context ];
    path    = Replace[ markers[ "Error" ], { { _, p_String } /; p =!= "" :> p, _ :> Lookup[ context, "Path", None ] } ];
    acpErrorInfo[
        kind,
        None,
        None,
        <|
            context,
            "Host"     -> Lookup[ context, "Host", acpSSHHostLabel @ ssh ],
            "Command"  -> Lookup[ context, "Command", acpSSHTerminalCommand @ ssh ],
            "Example"  -> Lookup[ context, "Example", If[ StringQ @ home, acpRemoteChild[ home, ".opencode/bin/opencode" ], "~/.opencode/bin/opencode" ] ],
            "Output"   -> output,
            "Hints"    -> hints,
            "Path"     -> path,
            "ExitCode" -> analysis[ "ExitCode" ]
        |>
    ]
];

sshErrorInfo // endDefinition;


(* The keys of the advice added to the kind's own (Connection.wl's errorHint makes paragraphs of them) *)
sshHints // beginDefinition;

sshHints[ kind_String, analysis_Association, context_Association ] := With[ { text = analysis[ "Text" ] },
    Join[
        If[ StringStartsQ[ kind, "SSH" ] && containsAnyQ[ text, $keyPermissionsTexts ], { "ErrorSSHKeyPermissionsDetail" }, { } ],
        If[ StringStartsQ[ kind, "SSH" ] && containsAnyQ[ text, $keyMissingTexts ], { "ErrorSSHKeyMissingDetail" }, { } ],
        If[ kind === "RemoteAgentExited" && TrueQ @ analysis[ "AgentQ" ] && signalExitQ @ analysis[ "ExitCode" ],
            { "ErrorRemoteAgentSignalDetail" },
            { }
        ],
        If[ kind === "SSHUnreachable" && TrueQ @ Lookup[ context, "RecentAuthFailure", False ], { "ErrorSSHPenaltyDetail" }, { } ]
    ]
];

sshHints // endDefinition;


(* The launch shell reports an agent killed by signal n as 128+n; a 255 that reaches rule 15 means the launch shell
   itself was killed, or the user's -q silenced ssh *)
signalExitQ // beginDefinition;
signalExitQ[ code_Integer ] := 129 <= code <= 192 || code === 255;
signalExitQ[ _ ] := False;
signalExitQ // endDefinition;


(* What ssh or the remote side said: the last $acpStderrLines lines of the text, without lines that name the launch
   script's variables (an inherited trace before the bootstrap could still print them) and, for SSHBadArguments,
   without ssh's usage text; neutralized; None if empty *)
sshOutput // beginDefinition;

sshOutput[ lines0_List, kind_String ] := Module[ { lines, text },
    lines = Pick[ lines0, StringContainsQ[ lines0, "LLMKIT_API_KEY" | "OPENCODE_CONFIG_CONTENT" ], False ];
    If[ kind === "SSHBadArguments", lines = dropUsage @ lines ];
    lines = Take[ lines, -Min[ Length @ lines, $acpStderrLines ] ];
    text  = StringTrim @ StringRiffle[ lines, "\n" ];
    If[ StringLength @ text > $acpMaxDetailLength, text = "\[Ellipsis]" <> StringTake[ text, -$acpMaxDetailLength ] ];
    If[ text === "", None, acpNeutralizeLinearSyntax @ text ]
];

sshOutput // endDefinition;


(* Drops ssh's usage text: the line starting with "usage:" and the indented lines after it *)
dropUsage // beginDefinition;

dropUsage[ lines_List ] := Module[ { inUsage = False },
    Select[
        lines,
        Function[ line,
            Which[
                StringStartsQ[ line, "usage:", IgnoreCase -> True ], inUsage = True; False,
                inUsage && StringStartsQ[ line, WhitespaceCharacter ], False,
                True, inUsage = False; True
            ]
        ]
    ]
];

dropUsage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
