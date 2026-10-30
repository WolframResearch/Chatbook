(* ::**************************************************************************************************************:: *)
(* ResolvedReasoningDefault.wl

   Helper for Scripts/CheckReasoningEfforts.wls, run as a subprocess so it can load a branch's
   Chatbook (and the paclet directories it needs) independently of the caller's own kernel.

   Usage:
       wolframscript -f Scripts/ResolvedReasoningDefault.wl <ChatbookDir> <model> [<model> ...]

   Prints one WL expression to stdout: what the Chatbook checkout at <ChatbookDir> declares, resolves and sends for
   each OpenAI model's reasoning effort, on each request method. It is an Association with these keys:

     "Checkout"              <| "Directory", "Commit" (git HEAD), "SourceModified" (uncommitted changes in Source/) |>
     "Paclets"               the LLMFunctions and LLMConnections versions loaded
     "Gate"                  the Responses gate, $responsesAPIAvailable
     "ReasoningEffortScale"  the checkout's $reasoningEffortScale, weakest first
     "Models"                an Association from each model name to:
         "Family", "BaseID"    from resolveFullModelSpec; per-model settings are keyed by "BaseID"
         "EnableResponses"     the "EnableResponses" model setting
         "RequestMethod"       what chooseRequestMethod picks (so it depends on "Gate")
         "Responses", "ChatCompletions", each an Association of:
             "ReasoningEfforts"  the declared levels "Reasoning" is clamped to: requestMethodReasoningEfforts over the
                                 "ReasoningEfforts" model setting
             "Reasoning"         the value "Reasoning" -> Automatic resolves to on that request method, as
                                 AbsoluteCurrentChatSettings reports it: resolveAutoSetting0[ settings, "Reasoning" ],
                                 which reads "ResponsesReasoning" first on the Responses endpoint
             "Sent"              what makeLLMConfiguration sends for that value:
                                 resolveReasoningEffort @ requestReasoningSummaries @ settings

   A model that cannot be resolved is Missing[ "ModelNotResolved" ]; a value the checkout does not declare is
   Missing[ "NotDeclared" ].

   LLMFunctions and LLMConnections are loaded from checkouts next to the Chatbook checkout this script
   belongs to (see below), or from the installed paclets when a checkout is not there.
*)
dir = $ScriptCommandLine[[ 2 ]];
models = Drop[ $ScriptCommandLine, 2 ];

(* The Responses-endpoint gate ($responsesAPIAvailable) needs a modern-enough LLMFunctions and LLMConnections. Load the
   working-tree copies, assumed to be checked out next to the Chatbook checkout that holds this script, so that every
   checkout CheckReasoningEfforts.wls compares is resolved under the same paclet versions rather than whatever is
   installed:
       <parent>/Chatbook/Scripts/ResolvedReasoningDefault.wl
       <parent>/LLMFunctions/LLMFunctions/PacletInfo.wl
       <parent>/LLMConnections/LLMConnections/PacletInfo.wl
   A missing checkout is reported on stderr, and the installed paclet is used instead. *)
$siblingDirectory = ParentDirectory @ DirectoryName[ $InputFileName, 2 ];
Scan[
    With[ { pacletDir = FileNameJoin @ { $siblingDirectory, #, # } },
        If[ FileExistsQ @ FileNameJoin @ { pacletDir, "PacletInfo.wl" },
            Quiet @ PacletDirectoryLoad @ pacletDir,
            WriteString[ "stderr", "No ", #, " checkout at ", pacletDir, "; using the installed paclet.\n" ]
        ]
    ] &,
    { "LLMFunctions", "LLMConnections" }
];
PacletDirectoryLoad @ dir;
Needs[ "Wolfram`Chatbook`" ];

(* ::**************************************************************************************************************:: *)
(* Chatbook's own functions, most of them private to their files *)

chatbookSymbol[ name_String ] :=
    Replace[ Names[ "Wolfram`Chatbook`*`" <> name ], {
        { full_String } :> Symbol @ full,
        other_          :> (WriteString[ "stderr", "Cannot identify Chatbook's ", name, ": ", ToString @ other, "\n" ];
                            Exit[ 1 ])
    } ];

resolveFullModelSpec          = chatbookSymbol[ "resolveFullModelSpec" ];
autoModelSetting              = chatbookSymbol[ "autoModelSetting" ];
chooseRequestMethod           = chatbookSymbol[ "chooseRequestMethod" ];
requestMethodReasoningEfforts = chatbookSymbol[ "requestMethodReasoningEfforts" ];
resolveAutoSetting0           = chatbookSymbol[ "resolveAutoSetting0" ];
requestReasoningSummaries     = chatbookSymbol[ "requestReasoningSummaries" ];
resolveReasoningEffort        = chatbookSymbol[ "resolveReasoningEffort" ];

(* ::**************************************************************************************************************:: *)
(* Resolution *)

declared[ value_ ] := Replace[ value, Automatic | Inherited | _Missing | $Failed -> Missing[ "NotDeclared" ] ];

perRequestMethod[ settings_Association, levels_, method_String ] :=
    Module[ { withMethod = <| settings, "RequestMethod" -> method |>, reasoning },
        reasoning = Quiet @ Check[ resolveAutoSetting0[ withMethod, "Reasoning" ], $Failed ];
        (* No rule matched when resolveAutoSetting0 stays unevaluated: *)
        reasoning = If[ Head @ reasoning === resolveAutoSetting0, Missing[ "NotDeclared" ], declared @ reasoning ];
        <|
            "ReasoningEfforts" -> If[ MatchQ[ levels, { __String } ],
                                      requestMethodReasoningEfforts[ withMethod, levels ],
                                      Missing[ "NotDeclared" ]
                                  ],
            "Reasoning"        -> reasoning,
            "Sent"             -> If[ MissingQ @ reasoning,
                                      Missing[ "NotDeclared" ],
                                      declared @ Quiet @ Check[
                                          resolveReasoningEffort @ requestReasoningSummaries @
                                              <| withMethod, "Reasoning" -> reasoning |>,
                                          $Failed
                                      ]
                                  ]
        |>
    ];

resolved[ model_String ] :=
    Module[ { spec, settings, levels },
        spec = Quiet @ Check[ resolveFullModelSpec @ <| "Service" -> "OpenAI", "Name" -> model |>, $Failed ];
        If[ ! AssociationQ @ spec, Return[ Missing[ "ModelNotResolved" ], Module ] ];
        settings = <| "Model" -> spec |>;
        levels   = Quiet @ autoModelSetting[ settings, "ReasoningEfforts" ];
        <|
            "Family"          -> declared @ Lookup[ spec, "Family" ],
            "BaseID"          -> declared @ Lookup[ spec, "BaseID" ],
            "EnableResponses" -> TrueQ @ Quiet @ autoModelSetting[ settings, "EnableResponses" ],
            "RequestMethod"   -> Quiet @ chooseRequestMethod @ settings,
            "Responses"       -> perRequestMethod[ settings, levels, "Responses" ],
            "ChatCompletions" -> perRequestMethod[ settings, levels, "ChatCompletions" ]
        |>
    ];

git[ args__String ] := Quiet @ RunProcess[ { "git", "-C", dir, args }, "StandardOutput" ];

commit = StringTrim @ git[ "rev-parse", "HEAD" ];

checkout = <|
    "Directory"      -> ExpandFileName @ dir,
    "Commit"         -> If[ StringMatchQ[ commit, HexadecimalCharacter.. ], commit, Missing[ "NotAGitCheckout" ] ],
    "SourceModified" -> git[ "status", "--porcelain", "--", "Source" ] =!= ""
|>;

WriteString[ "stdout", ToString[
    <|
        "Checkout"             -> checkout,
        "Paclets"              -> <|
            "LLMFunctions"   -> PacletObject[ "Wolfram/LLMFunctions" ][ "Version" ],
            "LLMConnections" -> PacletObject[ "LLMConnections" ][ "Version" ]
        |>,
        "Gate"                 -> TrueQ @ chatbookSymbol[ "$responsesAPIAvailable" ],
        "ReasoningEffortScale" -> chatbookSymbol[ "$reasoningEffortScale" ],
        "Models"               -> AssociationMap[ resolved, models ]
    |>,
    InputForm
] ];
