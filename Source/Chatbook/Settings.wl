(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Settings`" ];
Begin[ "`Private`" ];

(* :!CodeAnalysis::BeginBlock:: *)

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`Actions`"           ];
Needs[ "Wolfram`Chatbook`Common`"            ];
Needs[ "Wolfram`Chatbook`Personas`"          ];
Needs[ "Wolfram`Chatbook`ResourceInstaller`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$cloudInheritanceFix := $cloudNotebooks;

$defaultChatSettings = <|
    "AllowSelectionContext"          -> Automatic,
    "AppName"                        -> Automatic,
    "Assistance"                     -> Automatic,
    "Authentication"                 -> Automatic,
    "AutoFormat"                     -> True,
    "AutoSaveConversations"          -> Automatic,
    "BasePrompt"                     -> Automatic,
    "BypassResponseChecking"         -> Automatic,
    "ChatContextPreprompt"           -> Automatic,
    "ChatDrivenNotebook"             -> False,
    "ChatHistoryLength"              -> 1000,
    "ChatInputIndicator"             -> Automatic,
    "ConversationUUID"               -> None,
    "ConversionRules"                -> None,
    "ConvertSystemRoleToUser"        -> Automatic,
    "DynamicAutoFormat"              -> Automatic,
    "EnableChatGroupSettings"        -> False,
    "EnableLLMServices"              -> Automatic,
    "ForceSynchronous"               -> Automatic,
    "FrequencyPenalty"               -> 0.1,
    "HandlerFunctions"               :> $DefaultChatHandlerFunctions,
    "HandlerFunctionsKeys"           -> Automatic,
    "HybridToolMethod"               -> Automatic,
    "IncludeHistory"                 -> Automatic,
    "InitialChatCell"                -> True,
    "LLMEvaluator"                   -> "CodeAssistant",
    "MaxCellStringLength"            -> Automatic,
    "MaxContextTokens"               -> Automatic,
    "MaxOutputCellStringLength"      -> Automatic,
    "MaxTokens"                      -> Automatic,
    "MaxToolResponses"               -> 5,
    "MergeMessages"                  -> True,
    "MinimumResponsesToSave"         -> 1,
    "Model"                          :> $DefaultModel,
    "Multimodal"                     -> Automatic,
    "NotebookWriteMethod"            -> Automatic,
    "OpenAIAPICompletionURL"         -> "https://api.openai.com/v1/chat/completions",
    "OpenAIKey"                      -> Automatic,
    "OpenToolCallBoxes"              -> Automatic,
    "PresencePenalty"                -> 0.1,
    "ProcessingFunctions"            :> $DefaultChatProcessingFunctions,
    "PromptGeneratorMessagePosition" -> 2,
    "PromptGeneratorMessageRole"     -> "System",
    "PromptGenerators"               -> { },
    "PromptGeneratorsEnabled"        -> Automatic, (* TODO *)
    "Prompts"                        -> { },
    "ReplaceUnicodeCharacters"       -> Automatic,
    "SendToolResponse"               -> Automatic,
    "SetCellDingbat"                 -> True,
    "ShowMinimized"                  -> Automatic,
    "StopTokens"                     -> Automatic,
    "StreamingOutputMethod"          -> Automatic,
    "TabbedOutput"                   -> True, (* TODO: define a "MaxOutputPages" setting *)
    "TargetCloudObject"              -> Automatic,
    "Temperature"                    -> 0.7,
    "TimeConstraint"                 -> Automatic,
    "TokenBudgetMultiplier"          -> Automatic,
    "Tokenizer"                      -> Automatic,
    "ToolCallExamplePromptStyle"     -> Automatic,
    "ToolCallFrequency"              -> Automatic,
    "ToolCallRetryMessage"           -> Automatic,
    "ToolExamplePrompt"              -> Automatic,
    "ToolMethod"                     -> Automatic,
    "ToolOptions"                    :> $DefaultToolOptions,
    "ToolResponseRole"               -> Automatic,
    "ToolResponseStyle"              -> Automatic,
    "Tools"                          -> Automatic,
    "ToolSelectionType"              -> <| |>,
    "ToolsEnabled"                   -> Automatic,
    "TopP"                           -> 1,
    "TrackScrollingWhenPlaced"       -> Automatic,
    "VisiblePersonas"                -> $corePersonaNames
|>;

$cachedGlobalSettings := $cachedGlobalSettings = getGlobalSettingsFile[ ];

$nonInheritedPersonaValues = {
    "ChatDrivenNotebook",
    "CurrentPreferencesTab",
    "EnableLLMServices",
    "Icon",
    "InheritanceTest",
    "InitialChatCell",
    "LLMEvaluator",
    "PersonaFavorites",
    "ServiceDefaultModel"
};

$currentChatSettings          = None;
$currentSettingsCache         = None;
$absoluteCurrentSettingsCache = None;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Argument Patterns*)
$$validRootSettingValue = Inherited | _? (AssociationQ@*Association);
$$frontEndObject        = HoldPattern[ $FrontEnd | _FrontEndObject ];
$$hybridToolService     = "OpenAI"|"AzureOpenAI"|"LLMKit";
$$hybridToolModel       = _String | { $$hybridToolService, _ } | KeyValuePattern[ "Service" -> $$hybridToolService ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Model-specific settings*)
$modelAutoSettings = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Services*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Anthropic*)
$modelAutoSettings[ "Anthropic" ] = <| |>;

$modelAutoSettings[ "Anthropic", Automatic ] = <|
    "ReplaceUnicodeCharacters" -> True,
    "ToolMethod"               -> "Service"
|>;

$modelAutoSettings[ "Anthropic", "Claude2" ] = <|
    "ToolMethod"       -> Automatic,
    "ToolResponseRole" -> "User"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*AzureOpenAI*)
$modelAutoSettings[ "AzureOpenAI" ] = <| |>;

$modelAutoSettings[ "AzureOpenAI", Automatic ] = <|
    "ToolMethod"                 -> "Service",
    "ToolCallExamplePromptStyle" -> "Basic"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*DeepSeek*)
$modelAutoSettings[ "DeepSeek" ] = <| |>;

$modelAutoSettings[ "DeepSeek", "DeepSeekReasoner" ] = <|
    "HybridToolMethod" -> False,
    "ToolResponseRole" -> "User"
|>;

$modelAutoSettings[ "DeepSeek", "DeepSeekChat" ] = <|
    "ToolMethod" -> "Service"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*GoogleGemini*)
$modelAutoSettings[ "GoogleGemini" ] = <| |>;

$modelAutoSettings[ "GoogleGemini", "GeminiPro" ] = <|
    "ToolsEnabled" -> False
|>;

$modelAutoSettings[ "GoogleGemini", "GeminiProVision" ] = <|
    "ToolsEnabled" -> False
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*MistralAI*)
$modelAutoSettings[ "MistralAI" ] = <| |>;

$modelAutoSettings[ "MistralAI", Automatic ] = <|
    "ToolResponseRole"  -> "User",
    "ToolResponseStyle" -> "SystemTags"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*OpenAI*)
$modelAutoSettings[ "OpenAI" ] = <| |>;

$modelAutoSettings[ "OpenAI", "GPT35" ] = <|
    "ToolMethod" -> "Service"
|>;

$modelAutoSettings[ "OpenAI", Automatic ] = <|
    "ToolMethod"                 -> "Service",
    "ToolCallExamplePromptStyle" -> "Basic"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*TogetherAI*)
$modelAutoSettings[ "TogetherAI" ] = <| |>;

$modelAutoSettings[ "TogetherAI", "DeepSeekReasoner" ] = <|
    "ToolResponseRole" -> "User"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Any Service*)
$modelAutoSettings[ Automatic ] = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*gpt-4o*)
$modelAutoSettings[ Automatic, "GPT4Omni" ] = <|
    "HybridToolMethod"           -> True,
    "ToolCallExamplePromptStyle" -> Automatic,
    "ToolMethod"                 -> Automatic
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*OpenAI reasoning models*)

(* Note: Max tokens are halved for these models in order to leave room for reasoning *)
$modelAutoSettings[ Automatic, "O1Mini" ] = <|
    "ForceSynchronous"        -> False,
    "ConvertSystemRoleToUser" -> True,
    "MaxContextTokens"        -> 64000,
    "Multimodal"              -> False,
    "ToolsEnabled"            -> False
|>;

$modelAutoSettings[ Automatic, "O1" ] = <|
    "ForceSynchronous"           -> True,
    "HybridToolMethod"           -> False,
    "MaxContextTokens"           -> 100000,
    "MaxToolResponses"           -> 3,
    "Multimodal"                 -> True,
    "ToolCallExamplePromptStyle" -> "Basic",
    "ToolMethod"                 -> "Service"
|>;

$modelAutoSettings[ Automatic, "O3Mini" ] = <|
    "HybridToolMethod"           -> True,
    "MaxContextTokens"           -> 100000,
    "Multimodal"                 -> False,
    "ToolCallExamplePromptStyle" -> Automatic,
    "ToolMethod"                 -> Automatic
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Local models*)
$modelAutoSettings[ Automatic, "Qwen" ] = <|
    "ToolResponseRole" -> "User"
|>;

$modelAutoSettings[ Automatic, "Nemotron" ] = <|
    "ToolResponseRole" -> "User"
|>;

$modelAutoSettings[ Automatic, "Mistral" ] = <|
    "ToolResponseRole" -> "User"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Defaults*)
$modelAutoSettings[ Automatic, Automatic ] = <|
    "ConvertSystemRoleToUser"  -> False,
    "ReplaceUnicodeCharacters" -> False,
    "ToolResponseRole"         -> "System"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*autoModelSetting*)
autoModelSetting // beginDefinition;

autoModelSetting[ KeyValuePattern[ "Model" -> model_Association ], key_ ] :=
    autoModelSetting[ model, key ];

autoModelSetting[ model0_Association, key_String ] :=
    With[ { model = resolveFullModelSpec @ model0 },
        autoModelSetting[ model[ "Service" ], model[ "Name" ], model[ "BaseID" ], model[ "Family" ], key ]
    ];

autoModelSetting[ service_String, name_String, id_String, family_String, key_String ] :=
    autoModelSetting[ service, name, id, family, key ] =
        FirstCase[
            Unevaluated @ {
                (* Check in order of specificity: *)
                $modelAutoSettings[ service  , name     , key ],
                $modelAutoSettings[ service  , id       , key ],
                $modelAutoSettings[ service  , family   , key ],

                (* Check service-agnostic defaults: *)
                $modelAutoSettings[ Automatic, name     , key ],
                $modelAutoSettings[ Automatic, id       , key ],
                $modelAutoSettings[ Automatic, family   , key ],

                (* Check for service-level default: *)
                $modelAutoSettings[ service  , Automatic, key ],

                (* Check for global default: *)
                $modelAutoSettings[ Automatic, Automatic, key ]
            },
            e_ :> With[ { s = e }, s /; ! MissingQ @ s ]
        ];

autoModelSetting // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Defaults*)
$ChatAbort    = None;
$ChatPost     = None;
$ChatPre      = None;

$DefaultModel :=
    If[ $VersionNumber >= 14.1,
        <| "Service" -> "LLMKit", "Name" -> Automatic |>,
        <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Handler Functions*)
$DefaultChatHandlerFunctions = <|
    "ChatAbort"             :> $ChatAbort,
    "ChatPost"              :> $ChatPost,
    "ChatPre"               :> $ChatPre,
    "ToolRequestReceived"   -> None,
    "ToolResponseGenerated" -> None
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Processing Functions*)
$DefaultChatProcessingFunctions = <|
    "CellToChatMessage"   -> CellToChatMessage,
    "ChatMessages"        -> (#1 &),
    "ChatSubmit"          -> Automatic,
    "FormatChatOutput"    -> FormatChatOutput,
    "FormatToolCall"      -> FormatToolCall,
    "WriteChatOutputCell" -> WriteChatOutputCell
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$CurrentChatSettings*)
$CurrentChatSettings := If[ AssociationQ @ $currentChatSettings, $currentChatSettings, AbsoluteCurrentChatSettings[ ] ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AbsoluteCurrentChatSettings*)
AbsoluteCurrentChatSettings // beginDefinition;
AbsoluteCurrentChatSettings[ ] := catchMine @ AbsoluteCurrentChatSettings @ $FrontEnd;
AbsoluteCurrentChatSettings[ obj: $$feObj ] := catchMine @ absoluteCurrentChatSettings @ obj;
AbsoluteCurrentChatSettings[ obj: $$feObj, keys__String ] := catchMine @ absoluteCurrentChatSettings[ obj, keys ];
AbsoluteCurrentChatSettings // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*absoluteCurrentChatSettings*)
absoluteCurrentChatSettings // beginDefinition;

absoluteCurrentChatSettings[ obj: $$feObj ] := Enclose[
    Catch @ Module[ { cached, settings },
        cached = $absoluteCurrentSettingsCache @ obj;
        If[ AssociationQ @ cached, Throw @ cached ];
        settings = ConfirmBy[ absoluteCurrentChatSettings0 @ obj, AssociationQ, "Settings" ];
        If[ AssociationQ @ $absoluteCurrentSettingsCache,
            $absoluteCurrentSettingsCache[ obj ] = settings,
            settings
        ]
    ],
    throwInternalFailure
];

absoluteCurrentChatSettings[ obj: $$feObj, keys__ ] := Enclose[
    Module[ { settings },
        settings = ConfirmBy[ absoluteCurrentChatSettings @ obj, AssociationQ, "Settings" ];
        Replace[ settings @ keys, _Missing -> Inherited ]
    ],
    throwInternalFailure
];

absoluteCurrentChatSettings // endDefinition;


absoluteCurrentChatSettings0 // beginDefinition;
absoluteCurrentChatSettings0[ ] := absoluteCurrentChatSettings0 @ $FrontEnd;
absoluteCurrentChatSettings0[ obj: $$feObj ] := resolveAutoSettings @ currentChatSettings @ obj;
absoluteCurrentChatSettings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveAutoSettings*)
resolveAutoSettings // beginDefinition;

(* Don't do anything if settings have already been resolved *)
resolveAutoSettings[ settings: KeyValuePattern[ "ResolvedAutoSettings" -> True ] ] :=
    settings;

(* Add additional settings and resolve actual LLMTool expressions *)
resolveAutoSettings[ settings0_Association ] := Enclose[
    Module[ { persona, combined, settings, resolved },

        If[ $catching, $currentChatSettings = settings0 ];

        persona = ConfirmMatch[ getLLMEvaluator @ settings0, _String |_Association | None, "LLMEvaluator" ];

        combined = If[ AssociationQ @ persona,
                       mergeChatSettings @ {
                           evaluateSettings @ settings0,
                           evaluateSettings @ DeleteCases[
                               KeyDrop[ persona, $nonInheritedPersonaValues ],
                               $$unspecified
                           ]
                       },
                       settings0
                   ];

        settings = ConfirmBy[ evaluateSettings @ combined, AssociationQ, "Evaluated" ];

        (* Evaluate initialization if defined: *)
        Lookup[ settings, { Initialization, "Initialization" } ];
        KeyDropFrom[ settings, { Initialization, "Initialization" } ];

        resolved = ConfirmBy[
            resolveAutoSettings0 @ <|
                settings,
                "HandlerFunctions"     -> getHandlerFunctions @ settings,
                "LLMEvaluator"         -> persona,
                "Model"                -> resolveFullModelSpec @ settings,
                "ProcessingFunctions"  -> getProcessingFunctions @ settings,
                "ResolvedAutoSettings" -> True,
                If[ StringQ @ settings[ "Tokenizer" ],
                    <|
                        "TokenizerName" -> getTokenizerName @ settings,
                        "Tokenizer"     -> Automatic
                    |>,
                    "TokenizerName" -> Automatic
                ]
            |>,
            AssociationQ,
            "Resolved"
        ];

        If[ $chatState,
            addHandlerArguments[ "ChatNotebookSettings" -> resolved ];

            (* TODO: this is not ideal *)
            $multimodalMessages      = TrueQ @ resolved[ "Multimodal" ];
            $tokenBudget             = makeTokenBudget @ resolved;
            $tokenPressure           = 0.0;
            $initialCellStringBudget = makeCellStringBudget @ resolved;
            $cellStringBudget        = $initialCellStringBudget;
            $conversionRules         = resolved[ "ConversionRules" ];
            $openToolCallBoxes       = resolved[ "OpenToolCallBoxes" ];

            If[ resolved[ "ForceSynchronous" ], $showProgressText = True ];

            setLLMKitFlags @ resolved;
        ];
        If[ $catching, $currentChatSettings = resolved ];

        resolved
    ] // LogChatTiming[ "ResolveAutoSettings" ],
    throwInternalFailure
];

resolveAutoSettings // endDefinition;


resolveAutoSettings0 // beginDefinition;

(* Evaluate rhs of RuleDelayed settings to get final value *)
resolveAutoSettings0[ settings: KeyValuePattern[ _ :> _ ] ] :=
    resolveAutoSettings @ AssociationMap[ Apply @ Rule, settings ];

resolveAutoSettings0[ settings_Association ] := Enclose[
    Module[ { auto, sorted, resolved, override, result },
        auto     = ConfirmBy[ Select[ settings, SameAs @ Automatic ], AssociationQ, "Auto" ];
        sorted   = ConfirmBy[ <| KeyTake[ auto, $autoSettingKeyPriority ], auto |>, AssociationQ, "Sorted" ];
        resolved = ConfirmBy[ Fold[ resolveAutoSetting, settings, Normal @ sorted ], AssociationQ, "Resolved" ];
        override = ConfirmBy[ overrideSettings @ resolved, AssociationQ, "Override" ];
        If[ $chatState,
            If[ override[ "Assistance"    ], $AutomaticAssistance = True ];
            If[ override[ "WorkspaceChat" ], $WorkspaceChat       = True ];
        ];
        result = ConfirmBy[ resolveTools @ KeySort @ override, AssociationQ, "ResolveTools" ];
        If[ result[ "ToolMethod" ] === Automatic,
            result[ "ToolMethod" ] = chooseToolMethod @ result
        ];
        result[ "StopTokens" ] = autoStopTokens @ result;
        result
    ],
    throwInternalFailure
];

resolveAutoSettings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setLLMKitFlags*)
setLLMKitFlags // beginDefinition;
setLLMKitFlags[ as_ ] := setLLMKitFlags[ as[ "Authentication" ], as[ "Model", "Service" ] ];
setLLMKitFlags[ "LLMKit", service_String ] := ($llmKit = True; $llmKitService = service);
setLLMKitFlags[ "LLMKit", _ ] := $llmKit = True;
setLLMKitFlags[ _, _ ] := $llmKit = False;
setLLMKitFlags // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*overrideSettings*)
overrideSettings // beginDefinition;

overrideSettings[ settings_Association ] := <|
    settings,
    If[ llmKitQ @ settings, $llmKitOverrides, <| |> ]
|>;

overrideSettings // endDefinition;

(* TODO: these shouldn't be mutually exclusive: *)
$llmKitOverrides = <| "Authentication" -> "LLMKit" |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*llmKitQ*)
llmKitQ // beginDefinition;

llmKitQ[ as_Association ] := TrueQ @ Or[
    as[ "Authentication"          ] === "LLMKit",
    as[ "Model", "Service"        ] === "LLMKit",
    as[ "Model", "Authentication" ] === "LLMKit"
];

llmKitQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*evaluateSettings*)
(* Evaluate rhs of RuleDelayed settings to get final value *)
evaluateSettings // beginDefinition;
evaluateSettings[ settings_? AssociationQ ] := AssociationMap[ Apply @ Rule, settings ];
evaluateSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveAutoSetting*)
resolveAutoSetting // beginDefinition;
resolveAutoSetting[ settings_, key_ -> value_ ] := <| settings, key -> resolveAutoSetting0[ settings, key ] |>;
resolveAutoSetting // endDefinition;


resolveAutoSetting0 // beginDefinition;

(* See if model-specific default is defined: *)
resolveAutoSetting0[ as_, name_String ] :=
    With[ { s = autoModelSetting[ as, name ] },
        s /; ! MatchQ[ s, $$unspecified ]
    ];

(* Otherwise resolve defaults normally: *)
resolveAutoSetting0[ as_, "AllowSelectionContext"          ] := TrueQ[ $WorkspaceChat || $InlineChat ];
resolveAutoSetting0[ as_, "AppName"                        ] := $defaultAppName;
resolveAutoSetting0[ as_, "Assistance"                     ] := False;
resolveAutoSetting0[ as_, "Authentication"                 ] := autoAuthentication @ as;
resolveAutoSetting0[ as_, "AutoSaveConversations"          ] := autoSaveConversationsQ @ as;
resolveAutoSetting0[ as_, "BypassResponseChecking"         ] := bypassResponseCheckingQ @ as;
resolveAutoSetting0[ as_, "ChatInputIndicator"             ] := "\|01f4ac";
resolveAutoSetting0[ as_, "DynamicAutoFormat"              ] := dynamicAutoFormatQ @ as;
resolveAutoSetting0[ as_, "EnableLLMServices"              ] := $useLLMServices;
resolveAutoSetting0[ as_, "ForceSynchronous"               ] := forceSynchronousQ @ as;
resolveAutoSetting0[ as_, "HandlerFunctionsKeys"           ] := chatHandlerFunctionsKeys @ as;
resolveAutoSetting0[ as_, "HybridToolMethod"               ] := hybridToolMethodQ @ as;
resolveAutoSetting0[ as_, "IncludeHistory"                 ] := Automatic;
resolveAutoSetting0[ as_, "MaxCellStringLength"            ] := chooseMaxCellStringLength @ as;
resolveAutoSetting0[ as_, "MaxContextTokens"               ] := autoMaxContextTokens @ as;
resolveAutoSetting0[ as_, "MaxOutputCellStringLength"      ] := chooseMaxOutputCellStringLength @ as;
resolveAutoSetting0[ as_, "MaxTokens"                      ] := autoMaxTokens @ as;
resolveAutoSetting0[ as_, "Multimodal"                     ] := multimodalQ @ as;
resolveAutoSetting0[ as_, "NotebookWriteMethod"            ] := "PreemptiveLink";
resolveAutoSetting0[ as_, "OpenToolCallBoxes"              ] := openToolCallBoxesQ @ as;
resolveAutoSetting0[ as_, "PromptGeneratorMessagePosition" ] := 2;
resolveAutoSetting0[ as_, "PromptGeneratorMessageRole"     ] := "System";
resolveAutoSetting0[ as_, "PromptGenerators"               ] := { };
resolveAutoSetting0[ as_, "ShowMinimized"                  ] := Automatic;
resolveAutoSetting0[ as_, "StreamingOutputMethod"          ] := "PartialDynamic";
resolveAutoSetting0[ as_, "TokenBudgetMultiplier"          ] := 1;
resolveAutoSetting0[ as_, "Tokenizer"                      ] := getTokenizer @ as;
resolveAutoSetting0[ as_, "TokenizerName"                  ] := getTokenizerName @ as;
resolveAutoSetting0[ as_, "ToolCallExamplePromptStyle"     ] := chooseToolExamplePromptStyle @ as;
resolveAutoSetting0[ as_, "ToolCallFrequency"              ] := Automatic;
resolveAutoSetting0[ as_, "ToolCallRetryMessage"           ] := toolCallRetryMessageQ @ as;
resolveAutoSetting0[ as_, "ToolExamplePrompt"              ] := chooseToolExamplePromptSpec @ as;
resolveAutoSetting0[ as_, "ToolsEnabled"                   ] := toolsEnabledQ @ as;
resolveAutoSetting0[ as_, "TrackScrollingWhenPlaced"       ] := scrollOutputQ @ as;
resolveAutoSetting0[ as_, key_String                       ] := Automatic;
resolveAutoSetting0 // endDefinition;

(* Settings that require other settings to be resolved first: *)
$autoSettingKeyDependencies = <|
    "Authentication"             -> "Model",
    "AutoSaveConversations"      -> { "AppName", "ConversationUUID" },
    "BypassResponseChecking"     -> "ForceSynchronous",
    "ForceSynchronous"           -> "Model",
    "HandlerFunctionsKeys"       -> "EnableLLMServices",
    "HybridToolMethod"           -> { "Model", "ToolsEnabled", "ToolMethod" },
    "MaxCellStringLength"        -> { "Model", "MaxContextTokens" },
    "MaxContextTokens"           -> { "Authentication", "Model" },
    "MaxOutputCellStringLength"  -> "MaxCellStringLength",
    "MaxTokens"                  -> "Model",
    "Multimodal"                 -> { "EnableLLMServices", "Model" },
    "OpenToolCallBoxes"          -> "SendToolResponse",
    "Tokenizer"                  -> "TokenizerName",
    "TokenizerName"              -> "Model",
    "ToolCallExamplePromptStyle" -> { "Model", "ToolsEnabled" },
    "ToolCallRetryMessage"       -> { "Authentication", "Model" },
    "ToolExamplePrompt"          -> "Model",
    "Tools"                      -> { "LLMEvaluator", "ToolsEnabled" },
    "ToolsEnabled"               -> { "Model", "ToolCallFrequency" }
|>;

(* Sort topologically so dependencies will be satisfied in order: *)
$autoSettingKeyPriority := Enclose[
    $autoSettingKeyPriority = ConfirmMatch[
        DeleteDuplicates @ Prepend[
            TopologicalSort @ Flatten @ KeyValueMap[
                Thread @* Reverse @* Rule,
                $autoSettingKeyDependencies
            ],
            "Model"
        ],
        { __String? StringQ }
    ],
    throwInternalFailure[ $autoSettingKeyPriority, ## ] &
];

(* TODO: resolve these automatic values here:
    * BasePrompt (might not be possible here)
    * ChatContextPreprompt
*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*hybridToolMethodQ*)
hybridToolMethodQ // beginDefinition;
hybridToolMethodQ[ KeyValuePattern[ "ToolsEnabled" -> False ] ] := False;
hybridToolMethodQ[ KeyValuePattern[ "ToolMethod" -> "Service" ] ] := False;
hybridToolMethodQ[ as_Association ] := hybridToolMethodQ[ as, as[ "Model" ] ];
hybridToolMethodQ[ as_, $$hybridToolModel ] := True;
hybridToolMethodQ[ as_, _ ] := False;
hybridToolMethodQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolCallRetryMessageQ*)
toolCallRetryMessageQ // beginDefinition;
toolCallRetryMessageQ[ as_Association ] := llmKitQ @ as;
toolCallRetryMessageQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*autoAuthentication*)
autoAuthentication // beginDefinition;
autoAuthentication[ as_Association ] := autoAuthentication[ as, as[ "Model" ] ];
autoAuthentication[ as_, KeyValuePattern[ "Authentication" -> auth: Except[ $$unspecified ] ] ] := auth;
autoAuthentication[ as_, KeyValuePattern[ "Service" -> "LLMKit" ] ] := "LLMKit";
autoAuthentication[ as_, auth_ ] := Automatic;
autoAuthentication // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*openToolCallBoxesQ*)
openToolCallBoxesQ // beginDefinition;
openToolCallBoxesQ[ as_Association ] := If[ as[ "SendToolResponse" ] === False, True, Automatic ];
openToolCallBoxesQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*bypassResponseCheckingQ*)
bypassResponseCheckingQ // beginDefinition;
bypassResponseCheckingQ[ as_Association ] := TrueQ @ as[ "ForceSynchronous" ];
bypassResponseCheckingQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*forceSynchronousQ*)
forceSynchronousQ // beginDefinition;
forceSynchronousQ[ as_Association ] := serviceName @ as === "GoogleGemini";
forceSynchronousQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*autoSaveConversationsQ*)
autoSaveConversationsQ // beginDefinition;
autoSaveConversationsQ[ as_Association ] := TrueQ[ StringQ @ as[ "AppName" ] && StringQ @ as[ "ConversationUUID" ] ];
autoSaveConversationsQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chooseToolMethod*)
chooseToolMethod // beginDefinition;
chooseToolMethod[ as_Association ] := chooseToolMethod[ as, as[ "Tools" ] ];
chooseToolMethod[ as_, tools_List ] := If[ AllTrue[ tools, simpleToolQ ], "Simple", Automatic ];
chooseToolMethod[ as_, _ ] := Automatic;
chooseToolMethod // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*simpleToolQ*)
simpleToolQ // beginDefinition;
simpleToolQ[ tool_ ] := simpleToolQ[ tool, $DefaultTools ];
simpleToolQ[ name_String, default_Association ] := KeyExistsQ[ default, name ];
simpleToolQ[ tool: HoldPattern[ _LLMTool ], default_Association ] := MemberQ[ default, tool ];
simpleToolQ[ _, default_Association ] := False;
simpleToolQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chooseToolExamplePromptSpec*)
chooseToolExamplePromptSpec // beginDefinition;
chooseToolExamplePromptSpec[ as_Association ] := chooseToolExamplePromptSpec[ as, as[ "Model" ] ];
chooseToolExamplePromptSpec[ as_, model_String ] := autoToolExamplePromptSpec[ "OpenAI" ];
chooseToolExamplePromptSpec[ as_, { service_String, _String } ] := autoToolExamplePromptSpec @ service;
chooseToolExamplePromptSpec[ as_, model_Association ] := autoToolExamplePromptSpec @ model[ "Service" ];
chooseToolExamplePromptSpec // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*autoToolExamplePromptSpec*)
autoToolExamplePromptSpec // beginDefinition;
autoToolExamplePromptSpec[ _ ] := Automatic;
autoToolExamplePromptSpec // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chooseToolExamplePromptStyle*)
chooseToolExamplePromptStyle // beginDefinition;
chooseToolExamplePromptStyle[ KeyValuePattern[ "ToolsEnabled" -> False ] ] := None;
chooseToolExamplePromptStyle[ settings_Association ] := chooseToolExamplePromptStyle[ settings, settings[ "Model" ] ];
chooseToolExamplePromptStyle[ _, as_Association ] := autoToolExamplePromptStyle[ as[ "Service" ], as[ "Family" ] ];
chooseToolExamplePromptStyle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*autoToolExamplePromptStyle*)
autoToolExamplePromptStyle // beginDefinition;

autoToolExamplePromptStyle[ service_, family_ ] := autoToolExamplePromptStyle[ service, family ] =
    autoToolExamplePromptStyle0[ service, family ];

autoToolExamplePromptStyle // endDefinition;


autoToolExamplePromptStyle0 // beginDefinition;

(* By service: *)
autoToolExamplePromptStyle0[ "AzureOpenAI", _ ] := "ChatML";
autoToolExamplePromptStyle0[ "OpenAI"     , _ ] := "ChatML";
autoToolExamplePromptStyle0[ "Anthropic"  , _ ] := "XML";

(* By model family: *)
autoToolExamplePromptStyle0[ _, "Phi"           ] := "Phi";
autoToolExamplePromptStyle0[ _, "Llama"         ] := "Llama";
autoToolExamplePromptStyle0[ _, "Gemma"         ] := "Gemma";
autoToolExamplePromptStyle0[ _, "Qwen"          ] := "ChatML";
autoToolExamplePromptStyle0[ _, "Nemotron"      ] := "Nemotron";
autoToolExamplePromptStyle0[ _, "Mistral"       ] := "Instruct";
autoToolExamplePromptStyle0[ _, "DeepSeekCoder" ] := "DeepSeekCoder";

(* Default: *)
autoToolExamplePromptStyle0[ _, _ ] := "Basic";

autoToolExamplePromptStyle0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*autoStopTokens*)
autoStopTokens // beginDefinition;

autoStopTokens[ KeyValuePattern[ "ToolsEnabled" -> False ] ] :=
    If[ TrueQ @ $AutomaticAssistance, { "[INFO]" }, None ];

autoStopTokens[ as_Association ] := Replace[
    DeleteDuplicates @ Flatten @ {
        methodStopTokens @ as[ "ToolMethod" ],
        styleStopTokens @ as[ "ToolCallExamplePromptStyle" ],
        If[ TrueQ @ $AutomaticAssistance, "[INFO]", Nothing ]
    },
    { } -> None
];

autoStopTokens // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*methodStopTokens*)
methodStopTokens // beginDefinition;
methodStopTokens[ "Simple"         ] := { "\n/exec", "/end" };
methodStopTokens[ "Service"        ] := { "/end" };
methodStopTokens[ "Textual"|"JSON" ] := { "ENDTOOLCALL", "/end" };
methodStopTokens[ _                ] := { "ENDTOOLCALL", "\n/exec", "/end" };
methodStopTokens // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*styleStopTokens*)
styleStopTokens // beginDefinition;
styleStopTokens[ "Phi"           ] := { "<|user|>", "<|assistant|>" };
styleStopTokens[ "Llama"         ] := { "<|start_header_id|>" };
styleStopTokens[ "Gemma"         ] := { "<start_of_turn>" };
styleStopTokens[ "Nemotron"      ] := { "<extra_id_0>", "<extra_id_1>" };
styleStopTokens[ "DeepSeekCoder" ] := { "<\:ff5cbegin\:2581of\:2581sentence\:ff5c>" };
styleStopTokens[ _String | None  ] := { };
styleStopTokens // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chooseMaxCellStringLength*)
(* FIXME: need to hook into token pressure to gradually decrease limits *)
chooseMaxCellStringLength // beginDefinition;
chooseMaxCellStringLength[ as_Association ] := chooseMaxCellStringLength[ as, as[ "MaxContextTokens" ] ];
chooseMaxCellStringLength[ as_, Infinity ] := Infinity;
chooseMaxCellStringLength[ as_, tokens: $$size ] := Ceiling[ $defaultMaxCellStringLength * tokens / 2^14 ];
chooseMaxCellStringLength // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chooseMaxOutputCellStringLength*)
chooseMaxOutputCellStringLength // beginDefinition;
chooseMaxOutputCellStringLength[ as_Association ] := chooseMaxOutputCellStringLength[ as, as[ "MaxCellStringLength" ] ];
chooseMaxOutputCellStringLength[ as_, size: $$size ] := Min[ Ceiling[ size / 10 ], 1000 ];
chooseMaxOutputCellStringLength // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*autoMaxContextTokens*)
autoMaxContextTokens // beginDefinition;
autoMaxContextTokens[ as_? ollamaQ ] := serviceMaxContextTokens @ as;
autoMaxContextTokens[ as_Association? llmKitQ ] := Min[ 2^16, autoMaxContextTokens[ as, as[ "Model" ] ] ];
autoMaxContextTokens[ as_Association ] := autoMaxContextTokens[ as, as[ "Model" ] ];
autoMaxContextTokens[ as_, model_ ] := autoMaxContextTokens[ as, model, toModelName @ model ];
autoMaxContextTokens[ _, _, name_String ] := autoMaxContextTokens0 @ name;
autoMaxContextTokens // endDefinition;

autoMaxContextTokens0 // beginDefinition;
autoMaxContextTokens0[ name_String ] := autoMaxContextTokens0 @ StringSplit[ name, "-"|Whitespace ];
autoMaxContextTokens0[ { ___, "o1"                          , ___ } ] := 2^17;
autoMaxContextTokens0[ { ___, "gpt"|"chatgpt", "4o"         , ___ } ] := 2^17;
autoMaxContextTokens0[ { ___, "gpt", "4", "vision"          , ___ } ] := 2^17;
autoMaxContextTokens0[ { ___, "gpt", "4", "turbo"           , ___ } ] := 2^17;
autoMaxContextTokens0[ { ___, "claude", "2"                 , ___ } ] := 10^5;
autoMaxContextTokens0[ { ___, "claude", "2.1"|"3"           , ___ } ] := 2*10^5;
autoMaxContextTokens0[ { ___, "16k"                         , ___ } ] := 2^14;
autoMaxContextTokens0[ { ___, "32k"                         , ___ } ] := 2^15;
autoMaxContextTokens0[ { ___, "gpt", "4"                    , ___ } ] := 2^13;
autoMaxContextTokens0[ { ___, "gpt", "3.5"                  , ___ } ] := 2^12;
autoMaxContextTokens0[ { ___, "chat", "bison", "001"        , ___ } ] := 20000;
autoMaxContextTokens0[ { ___, "gemini", ___, "pro", "vision", ___ } ] := 12288;
autoMaxContextTokens0[ { ___, "gemini", ___, "pro"          , ___ } ] := 30720;
autoMaxContextTokens0[ { ___, "phi3.5"                      , ___ } ] := 2^17;
autoMaxContextTokens0[ _List                                        ] := 2^12;
autoMaxContextTokens0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ollamaQ*)
ollamaQ // beginDefinition;
ollamaQ[ as_Association ] := MatchQ[ serviceName @ as, "Ollama"|"ollama" ];
ollamaQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*serviceMaxContextTokens*)
serviceMaxContextTokens // beginDefinition;

serviceMaxContextTokens[ settings_Association ] :=
    serviceMaxContextTokens[ serviceName @ settings, toModelName @ settings ];

serviceMaxContextTokens[ service_String, name_String ] :=
    Module[ { max },
        max = Quiet @ ServiceExecute[ service, "ModelContextLength", { "Name" -> name } ];
        If[ TrueQ @ Positive @ max,
            serviceMaxContextTokens[ service, name ] = Floor @ max,
            autoMaxContextTokens0 @ name
        ]
    ];

serviceMaxContextTokens // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*autoMaxTokens*)
autoMaxTokens // beginDefinition;
autoMaxTokens[ as_Association ] := autoMaxTokens[ as, as[ "Model" ] ];
autoMaxTokens[ as_, model_ ] := autoMaxTokens[ as, model, toModelName @ model ];
autoMaxTokens[ as_, model_, name_String ] := Lookup[ $maxTokensTable, name, Automatic ];
autoMaxTokens // endDefinition;

(* FIXME: this should be something queryable from LLMServices: *)
$maxTokensTable = <|
    "gpt-4-vision-preview" -> 4096,
    "gpt-4-1106-preview"   -> 4096
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*multimodalQ*)
multimodalQ // beginDefinition;
multimodalQ[ as_Association ] := multimodalQ[ as, multimodalModelQ @ as[ "Model" ], as[ "EnableLLMServices" ] ];
multimodalQ[ as_, True , False ] := True;
multimodalQ[ as_, True , True  ] := multimodalPacletsAvailable[ ];
multimodalQ[ as_, False, _     ] := False;
multimodalQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*$multimodalPacletsAvailable*)
multimodalPacletsAvailable // beginDefinition;

multimodalPacletsAvailable[ ] := multimodalPacletsAvailable[ ] = (
    initTools[ ];
    multimodalPacletsAvailable[
        PacletObject[ "Wolfram/LLMFunctions"     ],
        PacletObject[ "ServiceConnection_OpenAI" ]
    ]
);

multimodalPacletsAvailable[ llmFunctions_PacletObject? PacletObjectQ, openAI_PacletObject? PacletObjectQ ] :=
    TrueQ @ And[
        PacletNewerQ[ llmFunctions, "1.2.4" ],
        Or[ PacletNewerQ[ openAI, "13.3.18" ],
            openAI[ "Version" ] === "13.3.18" && multimodalOpenAIQ @ openAI
        ]
    ];

multimodalPacletsAvailable // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*multimodalOpenAIQ*)
multimodalOpenAIQ // beginDefinition;

multimodalOpenAIQ[ openAI_PacletObject ] := Enclose[
    Catch @ Module[ { dir, file, multimodal },

        dir  = ConfirmBy[ openAI[ "Location" ], DirectoryQ, "Location" ];
        file = ConfirmBy[ FileNameJoin @ { dir, "Kernel", "OpenAI.m" }, FileExistsQ, "File" ];

        multimodal = WithCleanup[
            Quiet @ Close @ file,
            ConfirmMatch[ Find[ file, "data:image/jpeg;base64," ], _String? StringQ | EndOfFile, "Find" ],
            Quiet @ Close @ file
        ];

        StringQ @ multimodal
    ],
    throwInternalFailure
];

multimodalOpenAIQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*serviceFrameworkAvailable*)
serviceFrameworkAvailable // beginDefinition;

serviceFrameworkAvailable[ ] := serviceFrameworkAvailable[ ] = (
    serviceFrameworkAvailable[
        PacletObject[ "ServiceFramework" ]
    ]
);

serviceFrameworkAvailable[ sf_PacletObject? PacletObjectQ] :=
    Not @ TrueQ @ PacletNewerQ[ "0.1.0", sf ];

serviceFrameworkAvailable // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getLLMEvaluator*)
getLLMEvaluator // beginDefinition;
getLLMEvaluator[ as_Association ] := getLLMEvaluator[ as, Lookup[ as, "LLMEvaluator" ] ];

getLLMEvaluator[ as_, name_String ] :=
    (* If there isn't any information on `name`, getNamedLLMEvaluator just returns `name`; if that happens, avoid
       infinite recursion by just returning *)
    Replace[ getNamedLLMEvaluator @ name,
             {
                name   -> name,
                other_ :> getLLMEvaluator[ as, other ]
            }
    ];

getLLMEvaluator[ as_, evaluator_Association ] := evaluator;
getLLMEvaluator[ _, _ ] := None;
getLLMEvaluator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getNamedLLMEvaluator*)
getNamedLLMEvaluator // beginDefinition;
getNamedLLMEvaluator[ name_String ] := getNamedLLMEvaluator[ name, GetCachedPersonaData @ name ];
getNamedLLMEvaluator[ name_String, evaluator_Association ] := Append[ evaluator, "LLMEvaluatorName" -> name ];
getNamedLLMEvaluator[ name_String, _ ] := name;
getNamedLLMEvaluator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolsEnabledQ*)
$$disabledToolsModel = Alternatives[
    "chat-bison-001",
    "gemini-1.0-pro" ~~ ___,
    "gemini-pro-vision",
    "gemini-pro"
];

toolsEnabledQ // beginDefinition;
toolsEnabledQ[ KeyValuePattern[ "ToolsEnabled" -> enabled: True|False ] ] := enabled;
toolsEnabledQ[ KeyValuePattern[ "ToolCallFrequency" -> freq: (_Integer|_Real)? NonPositive ] ] := False;
toolsEnabledQ[ model_Association ] := With[ { e = autoModelSetting[ model, "ToolsEnabled" ] }, e /; BooleanQ @ e ];
toolsEnabledQ[ KeyValuePattern[ "Model" -> model_ ] ] := toolsEnabledQ @ toModelName @ model;
toolsEnabledQ[ model: KeyValuePattern @ { "Service" -> _, "Name" -> _ } ] := toolsEnabledQ @ toModelName @ model;
toolsEnabledQ[ { service_String, name_String } ] := toolsEnabledQ @ <| "Service" -> service, "Name" -> name |>;
toolsEnabledQ[ model_String ] := ! StringMatchQ[ model, $$disabledToolsModel, IgnoreCase -> True ];
toolsEnabledQ[ ___ ] := False;
toolsEnabledQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*dynamicSplitQ*)
dynamicSplitQ // beginDefinition;
dynamicSplitQ[ as_Association ] := dynamicSplitQ @ Lookup[ as, "StreamingOutputMethod", Automatic ];
dynamicSplitQ[ sym_Symbol ] := dynamicSplitQ @ SymbolName @ sym;
dynamicSplitQ[ "PartialDynamic"|"Automatic"|"Inherited" ] := True;
dynamicSplitQ[ "FullDynamic"|"Dynamic" ] := False;
dynamicSplitQ[ other_ ] := (messagePrint[ "InvalidStreamingOutputMethod", other ]; True);
dynamicSplitQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CurrentChatSettings*)

(* TODO: need to support something like CurrentChatSettings[scope, {"key1", "key2", ...}] for nested values *)

GeneralUtilities`SetUsage[ CurrentChatSettings, "\
CurrentChatSettings[] gives the current global chat settings.
CurrentChatSettings[\"key$\"] gives the global setting for the specified key.
CurrentChatSettings[obj$] gives all settings scoped by obj$.
CurrentChatSettings[obj$, \"key$\"] gives the setting scoped by obj$ for the specified key.
CurrentChatSettings[obj$, $$] = value$ sets the chat settings for obj$ to value$.
CurrentChatSettings[obj$, $$] =. resets the chat settings for obj$ to the default value.

* The value for obj$ can be any of the following:
| $FrontEnd          | persistent global scope |
| $FrontEndSession   | session global scope    |
| NotebookObject[$$] | notebook scope          |
| CellObject[$$]     | cell scope              |
* When setting chat settings without a key using CurrentChatSettings[obj$] = value$, \
the value$ must be an Association or Inherited.
* CurrentChatSettings[obj$, $$] =. is equivalent to CurrentChatSettings[obj$, $$] = Inherited.\
" ];

CurrentChatSettings[ ] := catchMine @
    If[ TrueQ[ $Notebooks || $CloudEvaluation ],
        CurrentChatSettings @ $FrontEnd,
        $defaultChatSettings
    ];

CurrentChatSettings[ key_String ] := catchMine @
    If[ TrueQ[ $Notebooks || $CloudEvaluation ],
        CurrentChatSettings[ $FrontEnd, key ],
        Lookup[ $defaultChatSettings, key, Inherited ]
    ];

CurrentChatSettings[ cell_CellObject ] := catchMine @
    With[ { parent = Quiet @ parentCell @ cell },
        If[ MatchQ[ parent, Except[ cell, _CellObject ] ],
            CurrentChatSettings @ parent,
            currentChatSettings @ cell
        ]
    ];

CurrentChatSettings[ cell_CellObject, key_String ] := catchMine @
    With[ { parent = Quiet @ parentCell @ cell },
        If[ MatchQ[ parent, Except[ cell, _CellObject ] ],
            CurrentChatSettings[ parent, key ],
            currentChatSettings[ cell, key ]
        ]
    ];

CurrentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession ] := catchMine @
    If[ TrueQ @ $Notebooks,
        currentChatSettings @ obj,
        $defaultChatSettings
    ];

CurrentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] := catchMine @
    If[ TrueQ @ $Notebooks,
        currentChatSettings[ obj, key ],
        Lookup[ $defaultChatSettings, key, Inherited ]
    ];

CurrentChatSettings[ args___ ] :=
    catchMine @ throwFailure[ "InvalidArguments", CurrentChatSettings, HoldForm @ CurrentChatSettings @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*UpValues*)
CurrentChatSettings /: HoldPattern @ Set[ CurrentChatSettings[ args___ ], value_ ] :=
    catchTop[ setCurrentChatSettings[ args, value ], CurrentChatSettings ];

CurrentChatSettings /: HoldPattern @ Unset[ CurrentChatSettings[ args___ ] ] :=
    catchTop[ unsetCurrentChatSettings @ args, CurrentChatSettings ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setCurrentChatSettings*)
setCurrentChatSettings // beginDefinition;
setCurrentChatSettings[ args___ ] /; $CloudEvaluation := setCurrentChatSettings0 @ args;
setCurrentChatSettings[ args___ ] := UsingFrontEnd @ setCurrentChatSettings0 @ args;
setCurrentChatSettings // endDefinition;


setCurrentChatSettings0 // beginDefinition;

(* Root settings: *)
setCurrentChatSettings0[ value: $$validRootSettingValue ] :=
    setCurrentChatSettings1[ $FrontEnd, value ];

setCurrentChatSettings0[ obj: $$feObj, value: $$validRootSettingValue ] :=
    setCurrentChatSettings1[ obj, value ];

(* Key settings: *)
setCurrentChatSettings0[ key_String? StringQ, value_ ] :=
    setCurrentChatSettings1[ $FrontEnd, key, value ];

setCurrentChatSettings0[ obj: $$feObj, key_String? StringQ, value_ ] :=
    setCurrentChatSettings1[ obj, key, value ];

(* Invalid scope: *)
setCurrentChatSettings0[ obj: Except[ $$feObj ], a__ ] := throwFailure[
    "InvalidFrontEndScope",
    obj,
    CurrentChatSettings,
    HoldForm @ setCurrentChatSettings0[ obj, a ]
];

(* Invalid key: *)
setCurrentChatSettings0[ obj: $$feObj, key_, value_ ] := throwFailure[
    "InvalidSettingsKey",
    key,
    CurrentChatSettings,
    HoldForm @ setCurrentChatSettings0[ obj, key, value ]
];

(* Invalid root settings: *)
setCurrentChatSettings0[ value: Except[ $$validRootSettingValue ] ] := throwFailure[
    "InvalidRootSettings",
    value,
    CurrentChatSettings,
    HoldForm @ setCurrentChatSettings0 @ value
];

setCurrentChatSettings0[ obj: $$feObj, value: Except[ $$validRootSettingValue ] ] := throwFailure[
    "InvalidRootSettings",
    value,
    CurrentChatSettings,
    HoldForm @ setCurrentChatSettings0 @ value
];

setCurrentChatSettings0 // endDefinition;


setCurrentChatSettings1 // beginDefinition;

setCurrentChatSettings1[ scope: $$feObj, Inherited ] := WithCleanup[
    If[ TrueQ @ $CloudEvaluation,
        setCurrentChatSettingsCloud[ scope, Inherited ],
        CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings" } ] = Inherited
    ],
    (* Invalidate cache *)
    If[ AssociationQ @ $currentSettingsCache, $currentSettingsCache = <| |> ]
    (* Note: It may be more slightly more efficient to just invalidate for the given `scope`, but that would require
       also finding scopes that `scope` inherits from and invalidating those as well. This is much simpler. *)
];

setCurrentChatSettings1[ scope: $$feObj, value_ ] :=
    With[ { as = Association @ value },
        WithCleanup[
            If[ TrueQ @ $CloudEvaluation,
                setCurrentChatSettingsCloud[ scope, as ],
                CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings" } ] = as
            ],
            (* Invalidate cache *)
            If[ AssociationQ @ $currentSettingsCache, $currentSettingsCache = <| |> ]
        ] /; AssociationQ @ as
    ];

setCurrentChatSettings1[ scope: $$feObj, key_String? StringQ, value_ ] := WithCleanup[
    If[ TrueQ @ $CloudEvaluation,
        setCurrentChatSettingsCloud[ scope, key, value ],
        CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", key } ] = value
    ],
    (* Invalidate cache *)
    If[ AssociationQ @ $currentSettingsCache, $currentSettingsCache = <| |> ]
];

setCurrentChatSettings1 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setCurrentChatSettingsCloud*)
setCurrentChatSettingsCloud // beginDefinition;

setCurrentChatSettingsCloud[ scope: $$frontEndObject, value_ ] :=
    With[ { as = Association @ value },
        (
            setGlobalChatSettings @ as;
            CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings" } ] = as
        ) /; AssociationQ @ as
    ];

setCurrentChatSettingsCloud[ scope: $$frontEndObject, Inherited ] := (
    setGlobalChatSettings @ Inherited;
    CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings" } ] = Inherited
);

setCurrentChatSettingsCloud[ scope: $$frontEndObject, key_String? StringQ, value_ ] := (
    setGlobalChatSettings[ key, value ];
    Needs[ "GeneralUtilities`" -> None ];
    CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", key } ] = value;
    CurrentValue[ scope, TaggingRules ] = GeneralUtilities`ToAssociations @ CurrentValue[ scope, TaggingRules ];
    value
);

setCurrentChatSettingsCloud[ scope: $$feObj, value_ ] :=
    With[ { as = Association @ value },
        (CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings" } ] = as) /; AssociationQ @ as
    ];

setCurrentChatSettingsCloud[ scope: $$feObj, Inherited ] := (
    CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings" } ] = Inherited
);

setCurrentChatSettingsCloud[ scope: $$feObj, key_String? StringQ, value_ ] := (
    Needs[ "GeneralUtilities`" -> None ];
    CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", key } ] = value;
    CurrentValue[ scope, TaggingRules ] = GeneralUtilities`ToAssociations @ CurrentValue[ scope, TaggingRules ];
    value
);

setCurrentChatSettingsCloud // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setGlobalChatSettings*)
setGlobalChatSettings // beginDefinition;

setGlobalChatSettings[ Inherited ] :=
    storeGlobalSettings @ <| |>;

setGlobalChatSettings[ settings_Association? AssociationQ ] :=
    storeGlobalSettings @ settings;

setGlobalChatSettings[ key_String? StringQ, Inherited ] := Enclose[
    Module[ { settings },
        settings = ConfirmBy[ getGlobalSettingsFile[ ], AssociationQ, "ReadSettings" ];
        KeyDropFrom[ settings, key ];
        ConfirmBy[ storeGlobalSettings @ settings, StringQ, "StoreSettings" ];
        $cachedGlobalSettings = settings;
        Inherited
    ],
    throwInternalFailure
];

setGlobalChatSettings[ key_String? StringQ, value_ ] := Enclose[
    Module[ { settings },
        settings = ConfirmBy[ getGlobalSettingsFile[ ], AssociationQ, "ReadSettings" ];
        settings[ key ] = value;
        ConfirmBy[ storeGlobalSettings @ settings, StringQ, "StoreSettings" ];
        $cachedGlobalSettings = settings;
        value
    ],
    throwInternalFailure
];

setGlobalChatSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getGlobalChatSettings*)
getGlobalChatSettings // beginDefinition;

getGlobalChatSettings[ ] :=
    mergeChatSettings @ Flatten @ { $defaultChatSettings, getGlobalSettingsFile[ ] };

getGlobalChatSettings[ key_String? StringQ ] :=
    getGlobalChatSettings[ getGlobalChatSettings[ ], key ];

getGlobalChatSettings[ settings_Association? AssociationQ, key_String? StringQ ] :=
    Lookup[ settings, key, Lookup[ $defaultChatSettings, key, Inherited ] ];

getGlobalChatSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getGlobalSettingsFile*)
getGlobalSettingsFile // beginDefinition;

getGlobalSettingsFile[ ] := Enclose[
    Module[ { file },
        file = ConfirmBy[ $globalSettingsFile, StringQ, "GlobalSettingsFile" ];
        $cachedGlobalSettings =
            If[ FileExistsQ @ file,
                ConfirmBy[ Developer`ReadWXFFile @ file, AssociationQ, "ReadSettings" ],
                <| |>
            ]
    ],
    Function[
        Quiet @ DeleteFile @ $globalSettingsFile;
        throwInternalFailure[ getGlobalSettingsFile[ ], ## ]
    ]
];

getGlobalSettingsFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*storeGlobalSettings*)
storeGlobalSettings // beginDefinition;

storeGlobalSettings[ settings_Association? AssociationQ ] := Enclose[
    Module[ { file },
        file = ConfirmBy[ $globalSettingsFile, StringQ, "GlobalSettingsFile" ];
        ConfirmBy[ Developer`WriteWXFFile[ file, settings ], StringQ, "StoreSettings" ];
        $cachedGlobalSettings = settings;
        file
    ],
    throwInternalFailure
];

storeGlobalSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$globalSettingsFile*)
$globalSettingsFile := Enclose[
    Module[ { dir },
        dir  = ConfirmBy[ $ResourceInstallationDirectory, StringQ, "ResourceInstallationDirectory" ];
        $globalSettingsFile = ConfirmBy[ FileNameJoin @ { dir, "GlobalChatSettings.wxf" }, StringQ, "File" ]
    ],
    throwInternalFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unsetCurrentChatSettings*)
unsetCurrentChatSettings // beginDefinition;

(* Root settings: *)
unsetCurrentChatSettings[ ] := unsetCurrentChatSettings0 @ $FrontEnd;
unsetCurrentChatSettings[ obj: $$feObj ] := unsetCurrentChatSettings0 @ obj;

(* Key settings: *)
unsetCurrentChatSettings[ key_? StringQ ] := unsetCurrentChatSettings0[ $FrontEnd, key ];
unsetCurrentChatSettings[ obj: $$feObj, key_? StringQ ] := unsetCurrentChatSettings0[ obj, key ];

(* Invalid scope: *)
unsetCurrentChatSettings[ obj: Except[ $$feObj ], a___ ] := throwFailure[
    "InvalidFrontEndScope",
    obj,
    CurrentChatSettings,
    HoldForm @ unsetCurrentChatSettings[ obj, a ]
];

(* Invalid key: *)
unsetCurrentChatSettings[ obj: $$feObj, key_ ] := throwFailure[
    "InvalidSettingsKey",
    key,
    CurrentChatSettings,
    HoldForm @ unsetCurrentChatSettings[ obj, key ]
];

unsetCurrentChatSettings // endDefinition;

unsetCurrentChatSettings0 // beginDefinition;
unsetCurrentChatSettings0[ obj: $$feObj ] := setCurrentChatSettings[ obj, Inherited ];
unsetCurrentChatSettings0[ obj: $$feObj, key_? StringQ ] := setCurrentChatSettings[ obj, key, Inherited ];
unsetCurrentChatSettings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*currentChatSettings*)
currentChatSettings // beginDefinition;

currentChatSettings[ obj: $$feObj ] := Enclose[
    Catch @ Module[ { cached, settings },
        cached = $currentSettingsCache @ obj;
        If[ AssociationQ @ cached, Throw @ cached ];
        settings = ConfirmMatch[ currentChatSettings0 @ obj, _Association? AssociationQ | _Missing, "Settings" ];
        If[ AssociationQ @ $currentSettingsCache && AssociationQ @ settings,
            $currentSettingsCache[ obj ] = settings,
            settings
        ]
    ],
    throwInternalFailure
];

currentChatSettings[ obj: $$feObj, key_ ] := Enclose[
    Catch @ Module[ { cached, settings },
        cached = $currentSettingsCache @ obj;
        If[ AssociationQ @ cached && KeyExistsQ[ cached, key ], Throw @ cached @ key ];
        If[ AssociationQ @ $currentSettingsCache,
            settings = ConfirmMatch[ currentChatSettings @ obj, _Association? AssociationQ | _Missing, "Settings" ];
            If[ MissingQ @ settings, Throw @ Inherited ];
            Lookup[ settings, key, Inherited ],
            currentChatSettings0[ obj, key ]
        ]
    ],
    throwInternalFailure
];

currentChatSettings // endDefinition;


currentChatSettings0 // beginDefinition;

currentChatSettings0[ fe: $$frontEndObject ] /; $CloudEvaluation :=
    getGlobalChatSettings[ ];

currentChatSettings0[ fe: $$frontEndObject, key_String ] /; $CloudEvaluation :=
    getGlobalChatSettings[ key ];

currentChatSettings0[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession ] := (
    verifyInheritance @ obj;
    currentChatSettings1 @ obj
);

currentChatSettings0[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] := (
    verifyInheritance @ obj;
    currentChatSettings1[ obj, key ]
);

currentChatSettings0[ cell0_CellObject ] := Catch @ Enclose[
    Catch @ Module[ { cell, cellInfo, styles, nbo, delimiter, settings },

        verifyInheritance @ cell0;

        cell = cell0;
        cellInfo = ConfirmMatch[ cellInformation @ cell, _Association|_Missing, "CellInformation" ];
        If[ MissingQ @ cellInfo, Throw @ Missing[ "NotAvailable" ] ];
        styles = ConfirmMatch[ Flatten @ List @ Lookup[ cellInfo, "Style" ], { ___String } ];

        If[ MemberQ[ styles, $$nestedCellStyle ],
            cell   = ConfirmMatch[ topParentCell @ cell, _CellObject, "ParentCell" ];
            styles = cellStyles @ cell;
        ];

        If[ cellInfo[ "ChatNotebookSettings", "ChatDelimiter" ], Throw @ currentChatSettings1 @ cell ];

        nbo = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "ParentNotebook" ];

        delimiter = ConfirmMatch[ getPrecedingDelimiter[ cell, nbo ], _CellObject|_Missing, "Delimiter" ];

        settings = Select[
            Map[ Association,
                 Flatten @ {
                    absoluteCurrentValue[ cell, { TaggingRules, "ChatNotebookSettings" } ],
                    CurrentValue[ DeleteMissing @ { delimiter, cell }, { TaggingRules, "ChatNotebookSettings" } ]
                 }
            ],
            AssociationQ
        ];

        ConfirmBy[
            mergeChatSettings @ Flatten @ { $defaultChatSettings, $cachedGlobalSettings, settings },
            AssociationQ,
            "CombinedSettings"
        ]
    ],
    throwInternalFailure
];

currentChatSettings0[ cell0_CellObject, key_String ] := Catch @ Enclose[
    Catch @ Module[ { cell, cellInfo, styles, nbo, cells, delimiter, values },

        verifyInheritance @ cell0;

        cell = cell0;
        cellInfo = ConfirmMatch[ cellInformation @ cell, _Association|_Missing, "CellInformation" ];
        If[ MissingQ @ cellInfo, Throw @ Missing[ "NotAvailable" ] ];
        styles = ConfirmMatch[ Flatten @ List @ Lookup[ cellInfo, "Style" ], { ___String } ];

        If[ MemberQ[ styles, $$nestedCellStyle ],
            cell   = ConfirmMatch[ topParentCell @ cell, _CellObject, "ParentCell" ];
            styles = cellStyles @ cell;
        ];

        If[ cellInfo[ "ChatNotebookSettings", "ChatDelimiter" ], Throw @ currentChatSettings1[ cell, key ] ];

        nbo   = ConfirmMatch[ parentNotebook @ cell, _NotebookObject, "ParentNotebook" ];
        cells = ConfirmMatch[ Cells @ nbo, { __CellObject }, "ChatCells" ];

        (* There are apparently temporary mystery cells that get created that aren't in the root cell list which are
           then immediately removed. These inherit the style specified by `DefaultNewCellStyle`. In chat-driven
           notebooks, this is set to "ChatInput", which has a dynamic cell dingbat that needs to resolve
           `currentChatSettings`. In this case, we have special behavior here to prevent a failure. Since that new
           temporary cell doesn't get displayed anyway, we don't need to actually resolve the chat settings for it,
           so we just return a default value instead. Yes, this is an ugly hack.
        *)
        If[ And[ MemberQ[ styles, $$chatInputStyle ], (*It's a "ChatInput" cell*)
                 ! MemberQ[ cells, cell ], (*It's not in the list of cells*)
                 MatchQ[ CurrentValue[ nbo, DefaultNewCellStyle ], $$chatInputStyle ] (*Due to DefaultNewCellStyle*)
            ],
            Throw @ Lookup[ $cachedGlobalSettings, key, Lookup[ $defaultChatSettings, key, Inherited ] ]
        ];

        delimiter = ConfirmMatch[ getPrecedingDelimiter[ cell, nbo, cells ], _CellObject|_Missing, "Delimiter" ];

        values = CurrentValue[ DeleteMissing @ { cell, delimiter }, { TaggingRules, "ChatNotebookSettings", key } ];

        (* TODO: this should also use `mergeChatSettings` in case the values are associations *)
        FirstCase[
            values,
            Except[ Inherited ],
            Replace[
                absoluteCurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", key } ],
                Inherited :> Lookup[ $cachedGlobalSettings, key, Lookup[ $defaultChatSettings, key, Inherited ] ]
            ]
        ]
    ],
    throwInternalFailure
];

currentChatSettings0 // endDefinition;


currentChatSettings1 // beginDefinition;

currentChatSettings1[ obj: _CellObject|_NotebookObject|_FrontEndObject|$FrontEndSession ] :=
    mergeChatSettings @ Map[
        evaluateSettings,
        {
            $defaultChatSettings,
            $cachedGlobalSettings,
            Replace[
                Association @ absoluteCurrentValue[ obj, { TaggingRules, "ChatNotebookSettings" } ],
                Except[ _? AssociationQ ] :> <| |>
            ]
        }
    ];

currentChatSettings1[ obj: _CellObject|_NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] := Replace[
    absoluteCurrentValue[ obj, { TaggingRules, "ChatNotebookSettings", key } ],
    Inherited :> Lookup[ $cachedGlobalSettings, key, Lookup[ $defaultChatSettings, key, Inherited ] ]
];

currentChatSettings1 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*absoluteCurrentValue*)
absoluteCurrentValue // beginDefinition;

(* Workaround for AbsoluteCurrentValue not properly inheriting TaggingRules in cloud notebooks: *)
absoluteCurrentValue[ cell_CellObject, { TaggingRules, "ChatNotebookSettings" } ] /; $cloudInheritanceFix :=
    mergeChatSettings @ {
        Replace[
            Association @ AbsoluteCurrentValue[ parentNotebook @ cell, { TaggingRules, "ChatNotebookSettings" } ],
            Except[ _? AssociationQ ] -> <| |>
        ],
        Replace[
            Association @ AbsoluteCurrentValue[ cell, { TaggingRules, "ChatNotebookSettings" } ],
            Except[ _? AssociationQ ] -> <| |>
        ]
    };

absoluteCurrentValue[ cell_CellObject, { TaggingRules, "ChatNotebookSettings", key_ } ] /; $cloudInheritanceFix :=
    Replace[
        AbsoluteCurrentValue[ cell, { TaggingRules, "ChatNotebookSettings", key } ],
        Inherited :> AbsoluteCurrentValue[ parentNotebook @ cell, { TaggingRules, "ChatNotebookSettings", key } ]
    ];

absoluteCurrentValue[ args___ ] :=
    AbsoluteCurrentValue @ args;

absoluteCurrentValue // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeChatSettings*)
mergeChatSettings // beginDefinition;
mergeChatSettings[ a_List ] := mergeChatSettings[ a ] = mergeChatSettings0 @ a //. $mergeSettingsDispatch;
mergeChatSettings // endDefinition;

mergeChatSettings0 // beginDefinition;
mergeChatSettings0[ { a___, (Inherited|ParentList).., b___ } ] := mergeChatSettings0 @ { a, b };
mergeChatSettings0[ { a___, { b___ }, { c___, ParentList, d___ } } ] := mergeChatSettings0 @ { a, { c, b, d } };
mergeChatSettings0[ { a___, b: Except[ $$unspecified ], { c___, ParentList, d___ } } ] := mergeChatSettings0 @ { a, { c, b, d } };
mergeChatSettings0[ { a_? AssociationQ, b__? AssociationQ } ] := DeleteMissing @ Merge[ { a, b }, mergeChatSettings0 ];
mergeChatSettings0[ { a___, Except[ _? AssociationQ ].., b__? AssociationQ } ] := mergeChatSettings0 @ { a, b };
mergeChatSettings0[ { __, e: Except[ _? AssociationQ ] } ] := e;
mergeChatSettings0[ { e_ } ] := e;
mergeChatSettings0[ { } ] := Missing[ ];
mergeChatSettings0 // endDefinition;


$mergeSettingsDispatch := $mergeSettingsDispatch = Dispatch @ Flatten @ {
    DownValues @ mergeChatSettings0,
    HoldPattern @ Merge[ { a___, b_, b_, c___ }, mergeChatSettings0 ] :> Merge[ { a, b, c }, mergeChatSettings0 ],
    HoldPattern @ Merge[ { a_ }, mergeChatSettings0 ] :> a
};

(* TODO: need to apply special merging/inheritance for things like "Prompts" *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getPrecedingDelimiter*)
getPrecedingDelimiter // beginDefinition;

getPrecedingDelimiter[ cell_CellObject ] :=
    getPrecedingDelimiter[ cell, parentNotebook @ cell ];

getPrecedingDelimiter[ cell_CellObject, nbo_NotebookObject ] :=
    getPrecedingDelimiter[ cell, nbo, Cells @ nbo ];

getPrecedingDelimiter[ cell_CellObject, nbo_, { before0___CellObject, cell_, ___ } ] :=
    Module[ { before, delimiterTest, pos },
        before = Reverse @ { before0 };
        delimiterTest = AbsoluteCurrentValue[ before, { TaggingRules, "ChatNotebookSettings", "ChatDelimiter" } ];
        pos = FirstPosition[ delimiterTest, True ];
        If[ MissingQ @ pos, Missing[ "NotAvailable" ], Extract[ before, pos ] ]
    ];

getPrecedingDelimiter[ cell_CellObject, nbo_, cells: { ___CellObject } ] /; ! MemberQ[ cells, cell ] :=
    Missing[ "NotAvailable" ];

getPrecedingDelimiter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*verifyInheritance*)
verifyInheritance // beginDefinition;
verifyInheritance[ obj_ ] /; $SynchronousEvaluation || $CloudEvaluation := True;
verifyInheritance[ obj_? inheritingQ ] := True;
verifyInheritance[ obj: $$feObj ] := With[ { verified = verifyInheritance0 @ obj }, inheritingQ @ obj ];
verifyInheritance // endDefinition;


verifyInheritance0 // beginDefinition;

(* Repair tagging rules at top-level and set the inheritance flag: *)
verifyInheritance0[ fe_FrontEndObject ] := Enclose[
    Module[ { tags },

        tags = ConfirmMatch[
            trToAssociations @ CurrentValue[ fe, TaggingRules ],
            _? AssociationQ | Inherited,
            "Tags"
        ];

        CurrentValue[ fe, TaggingRules ] = tags;
        CurrentValue[ fe, { TaggingRules, "ChatNotebookSettings", "InheritanceTest" } ] = True;

        ConfirmBy[ CurrentValue[ fe, TaggingRules ], AssociationQ, "Verify" ]
    ],
    throwInternalFailure[ verifyInheritance0 @ fe, ## ] &
];

(* Otherwise, recurse upwards repairing tagging rules: *)
verifyInheritance0[ obj: Except[ _FrontEndObject, $$feObj ] ] :=
    Module[ { parent, tags },
        parent = feParentObject @ obj;
        tags   = verifyInheritance0 @ parent;
        repairTaggingRules[ obj, tags ]
    ];

verifyInheritance0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inheritingQ*)
inheritingQ // beginDefinition;

inheritingQ[ obj: $$feObj ] :=
    TrueQ @ Replace[
        AbsoluteCurrentValue[ obj, { TaggingRules, "ChatNotebookSettings", "InheritanceTest" } ],
        $Failed -> True
    ];

inheritingQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*repairTaggingRules*)
repairTaggingRules // beginDefinition;

repairTaggingRules[ box_BoxObject, parentTags_Association? AssociationQ ] := parentTags;

repairTaggingRules[ obj: $$feObj, parentTags_Association? AssociationQ ] := Enclose[
    Module[ { tags, keep },

        tags = ConfirmMatch[
            trToAssociations @ CurrentValue[ obj, TaggingRules ],
            _? AssociationQ | Inherited,
            "Tags"
        ];

        keep = ConfirmMatch[
            associationComplement[ tags, parentTags ],
            _? AssociationQ | Inherited,
            "Complement"
        ];

        If[ keep[ "ChatNotebookSettings", "InheritanceTest" ],
            keep[ "ChatNotebookSettings", "InheritanceTest" ] =.
        ];

        If[ keep === <| |>,
            CurrentValue[ obj, TaggingRules ] = Inherited,
            CurrentValue[ obj, TaggingRules ] = keep
        ]
    ],
    throwInternalFailure[ repairTaggingRules[ obj, parentTags ], ## ] &
];

repairTaggingRules // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*trToAssociations*)
trToAssociations // beginDefinition;
trToAssociations[ expr_ ] := Replace[ trToAssociations0 @ expr, { } | <| |> -> Inherited ];
trToAssociations // endDefinition;

trToAssociations0 // beginDefinition;

trToAssociations0[ as_Association? AssociationQ ] :=
    Replace[
        DeleteCases[ trToAssociations /@ as /. HoldPattern @ trToAssociations[ expr_ ] :> expr, <| |> | Inherited ],
        <| |> -> Inherited
    ];

trToAssociations0[ { rules: (Rule|RuleDelayed)[ _, _ ].. } ] :=
    trToAssociations0 @ Association @ rules;

trToAssociations0[ expr_ ] :=
    expr;

trToAssociations0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*associationComplement*)
associationComplement // beginDefinition;

associationComplement[ as1_? AssociationQ, as2_? AssociationQ ] :=
    Module[ { complement, common },
        complement = Complement[ as1, as2 ];
        common     = Intersection[ Keys @ complement, Keys @ as2 ];
        Scan[ Function[ complement[ # ] = associationComplement[ as1[ # ], as2[ # ] ] ], common ];
        complement
    ];

associationComplement[ as1: { (Rule|RuleDelayed)[ _, _ ]... }, as2_ ] :=
    associationComplement[ Association @ as1, as2 ];

associationComplement[ as1_, as2: { (Rule|RuleDelayed)[ _, _ ]... } ] :=
    associationComplement[ as1, Association @ as2 ];

associationComplement[ as_, _ ] := as;

associationComplement // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $mergeSettingsDispatch;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
