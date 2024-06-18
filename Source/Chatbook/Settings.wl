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
Needs[ "Wolfram`Chatbook`Serialization`"     ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$cloudInheritanceFix := $cloudNotebooks;

(* cSpell: ignore AIAPI *)
$defaultChatSettings = <|
    "Assistance"                 -> Automatic,
    "Authentication"             -> Automatic,
    "AutoFormat"                 -> True,
    "BasePrompt"                 -> Automatic,
    "BypassResponseChecking"     -> False,
    "ChatContextPreprompt"       -> Automatic,
    "ChatDrivenNotebook"         -> False,
    "ChatHistoryLength"          -> 1000,
    "ChatInputIndicator"         -> Automatic,
    "ConversionRules"            -> None,
    "DynamicAutoFormat"          -> Automatic,
    "EnableChatGroupSettings"    -> False,
    "EnableLLMServices"          -> Automatic,
    "FrequencyPenalty"           -> 0.1,
    "HandlerFunctions"           :> $DefaultChatHandlerFunctions,
    "HandlerFunctionsKeys"       -> Automatic,
    "IncludeHistory"             -> Automatic,
    "InitialChatCell"            -> True,
    "LLMEvaluator"               -> "CodeAssistant",
    "MaxCellStringLength"        -> Automatic,
    "MaxContextTokens"           -> Automatic,
    "MaxOutputCellStringLength"  -> Automatic,
    "MaxTokens"                  -> Automatic,
    "MergeMessages"              -> True,
    "Model"                      :> $DefaultModel,
    "Multimodal"                 -> Automatic,
    "NotebookWriteMethod"        -> Automatic,
    "OpenAIAPICompletionURL"     -> "https://api.openai.com/v1/chat/completions",
    "OpenAIKey"                  -> Automatic,
    "PresencePenalty"            -> 0.1,
    "ProcessingFunctions"        :> $DefaultChatProcessingFunctions,
    "Prompts"                    -> { },
    "SetCellDingbat"             -> True,
    "ShowMinimized"              -> Automatic,
    "StreamingOutputMethod"      -> Automatic,
    "TabbedOutput"               -> True, (* TODO: define a "MaxOutputPages" setting *)
    "TargetCloudObject"          -> Automatic,
    "Temperature"                -> 0.7,
    "TokenBudgetMultiplier"      -> Automatic,
    "Tokenizer"                  -> Automatic,
    "ToolCallExamplePromptStyle" -> Automatic,
    "ToolCallFrequency"          -> Automatic,
    "ToolExamplePrompt"          -> Automatic,
    "ToolMethod"                 -> Automatic,
    "ToolOptions"                :> $DefaultToolOptions,
    "Tools"                      -> Automatic,
    "ToolSelectionType"          -> <| |>,
    "ToolsEnabled"               -> Automatic,
    "TopP"                       -> 1,
    "TrackScrollingWhenPlaced"   -> Automatic,
    "VisiblePersonas"            -> $corePersonaNames
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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Argument Patterns*)
$$validRootSettingValue = Inherited | _? (AssociationQ@*Association);
$$frontEndObject        = HoldPattern[ $FrontEnd | _FrontEndObject ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Defaults*)
$ChatAbort    = None;
$ChatPost     = None;
$ChatPre      = None;
$DefaultModel = <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Handler Functions*)
$DefaultChatHandlerFunctions = <|
    "ChatAbort" :> $ChatAbort,
    "ChatPost"  :> $ChatPost,
    "ChatPre"   :> $ChatPre
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
(*AbsoluteCurrentChatSettings*)
AbsoluteCurrentChatSettings // beginDefinition;
AbsoluteCurrentChatSettings[ ] := AbsoluteCurrentChatSettings @ $FrontEnd;
AbsoluteCurrentChatSettings[ obj: $$feObj ] := resolveAutoSettings @ currentChatSettings @ obj;
AbsoluteCurrentChatSettings[ obj: $$feObj, keys__String ] := AbsoluteCurrentChatSettings[ obj ][ keys ];
AbsoluteCurrentChatSettings // endExportedDefinition;

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

        If[ TrueQ @ $chatState, addHandlerArguments[ "ChatNotebookSettings" -> resolved ] ];

        resolved
    ],
    throwInternalFailure
];

resolveAutoSettings // endDefinition;


resolveAutoSettings0 // beginDefinition;

(* Evaluate rhs of RuleDelayed settings to get final value *)
resolveAutoSettings0[ settings: KeyValuePattern[ _ :> _ ] ] :=
    resolveAutoSettings @ AssociationMap[ Apply @ Rule, settings ];

resolveAutoSettings0[ settings_Association ] := Enclose[
    Module[ { auto, sorted, resolved, result },
        auto     = ConfirmBy[ Select[ settings, SameAs @ Automatic ], AssociationQ, "Auto" ];
        sorted   = ConfirmBy[ <| KeyTake[ auto, $autoSettingKeyPriority ], auto |>, AssociationQ, "Sorted" ];
        resolved = ConfirmBy[ Fold[ resolveAutoSetting, settings, Normal @ sorted ], AssociationQ, "Resolved" ];
        If[ $chatState,
            If[ resolved[ "Assistance"    ], $AutomaticAssistance = True ];
            If[ resolved[ "WorkspaceChat" ], $WorkspaceChat       = True ];
        ];
        result = ConfirmBy[ resolveTools @ KeySort @ resolved, AssociationQ, "ResolveTools" ];
        If[ result[ "ToolMethod" ] === Automatic,
            result[ "ToolMethod" ] = chooseToolMethod @ result
        ];
        result
    ],
    throwInternalFailure
];

resolveAutoSettings0 // endDefinition;

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
resolveAutoSetting0[ as_, "Assistance"                 ] := False;
resolveAutoSetting0[ as_, "ChatInputIndicator"         ] := "\|01f4ac";
resolveAutoSetting0[ as_, "DynamicAutoFormat"          ] := dynamicAutoFormatQ @ as;
resolveAutoSetting0[ as_, "EnableLLMServices"          ] := $useLLMServices;
resolveAutoSetting0[ as_, "HandlerFunctionsKeys"       ] := chatHandlerFunctionsKeys @ as;
resolveAutoSetting0[ as_, "IncludeHistory"             ] := Automatic;
resolveAutoSetting0[ as_, "MaxCellStringLength"        ] := chooseMaxCellStringLength @ as;
resolveAutoSetting0[ as_, "MaxContextTokens"           ] := autoMaxContextTokens @ as;
resolveAutoSetting0[ as_, "MaxOutputCellStringLength"  ] := chooseMaxOutputCellStringLength @ as;
resolveAutoSetting0[ as_, "MaxTokens"                  ] := autoMaxTokens @ as;
resolveAutoSetting0[ as_, "Multimodal"                 ] := multimodalQ @ as;
resolveAutoSetting0[ as_, "NotebookWriteMethod"        ] := "PreemptiveLink";
resolveAutoSetting0[ as_, "ShowMinimized"              ] := Automatic;
resolveAutoSetting0[ as_, "StreamingOutputMethod"      ] := "PartialDynamic";
resolveAutoSetting0[ as_, "TokenBudgetMultiplier"      ] := 1;
resolveAutoSetting0[ as_, "Tokenizer"                  ] := getTokenizer @ as;
resolveAutoSetting0[ as_, "TokenizerName"              ] := getTokenizerName @ as;
resolveAutoSetting0[ as_, "ToolCallExamplePromptStyle" ] := chooseToolExamplePromptStyle @ as;
resolveAutoSetting0[ as_, "ToolCallFrequency"          ] := Automatic;
resolveAutoSetting0[ as_, "ToolExamplePrompt"          ] := chooseToolExamplePromptSpec @ as;
resolveAutoSetting0[ as_, "ToolMethod"                 ] := chooseToolMethod @ as;
resolveAutoSetting0[ as_, "ToolsEnabled"               ] := toolsEnabledQ @ as;
resolveAutoSetting0[ as_, "TrackScrollingWhenPlaced"   ] := scrollOutputQ @ as;
resolveAutoSetting0[ as_, key_String                   ] := Automatic;
resolveAutoSetting0 // endDefinition;

(* Settings that require other settings to be resolved first: *)
$autoSettingKeyDependencies = <|
    "HandlerFunctionsKeys"       -> "EnableLLMServices",
    "MaxCellStringLength"        -> { "Model", "MaxContextTokens" },
    "MaxContextTokens"           -> "Model",
    "MaxOutputCellStringLength"  -> "MaxCellStringLength",
    "MaxTokens"                  -> "Model",
    "Multimodal"                 -> { "EnableLLMServices", "Model" },
    "Tokenizer"                  -> "TokenizerName",
    "TokenizerName"              -> "Model",
    "ToolCallExamplePromptStyle" -> "Model",
    "ToolExamplePrompt"          -> "Model",
    "ToolMethod"                 -> "Tools",
    "Tools"                      -> { "LLMEvaluator", "ToolsEnabled" },
    "ToolsEnabled"               -> { "Model", "ToolCallFrequency" }
|>;

(* Sort topologically so dependencies will be satisfied in order: *)
$autoSettingKeyPriority := Enclose[
    $autoSettingKeyPriority = ConfirmMatch[
        TopologicalSort @ Flatten @ KeyValueMap[
            Thread @* Reverse @* Rule,
            $autoSettingKeyDependencies
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
simpleToolQ[ tool_LLMTool, default_Association ] := MemberQ[ default, tool ];
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
autoToolExamplePromptSpec[ "Anthropic" ] := None;
autoToolExamplePromptSpec[ _ ] := Automatic;
autoToolExamplePromptSpec // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chooseToolExamplePromptStyle*)
chooseToolExamplePromptStyle // beginDefinition;
chooseToolExamplePromptStyle[ as_Association ] := chooseToolExamplePromptStyle[ as, as[ "Model" ] ];
chooseToolExamplePromptStyle[ as_, model_String ] := autoToolExamplePromptStyle[ "OpenAI" ];
chooseToolExamplePromptStyle[ as_, { service_String, _String } ] := autoToolExamplePromptStyle @ service;
chooseToolExamplePromptStyle[ as_, model_Association ] := autoToolExamplePromptStyle @ model[ "Service" ];
chooseToolExamplePromptStyle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*autoToolExamplePromptStyle*)
autoToolExamplePromptStyle // beginDefinition;
autoToolExamplePromptStyle[ "AzureOpenAI"|"OpenAI" ] := "ChatML";
autoToolExamplePromptStyle[ _ ] := "Basic"; (* TODO: measure performance of other models to choose the best option *)
autoToolExamplePromptStyle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*chooseMaxCellStringLength*)
(* FIXME: need to hook into token pressure to gradually decrease limits *)
chooseMaxCellStringLength // beginDefinition;
chooseMaxCellStringLength[ as_Association ] := chooseMaxCellStringLength[ as, as[ "MaxContextTokens" ] ];
chooseMaxCellStringLength[ as_, Infinity ] := Infinity;
chooseMaxCellStringLength[ as_, tokens: $$size ] := Ceiling[ $defaultMaxCellStringLength * tokens / 2^13 ];
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
autoMaxContextTokens[ as_Association ] := autoMaxContextTokens[ as, as[ "Model" ] ];
autoMaxContextTokens[ as_, model_ ] := autoMaxContextTokens[ as, model, toModelName @ model ];
autoMaxContextTokens[ _, _, name_String ] := autoMaxContextTokens0 @ name;
autoMaxContextTokens // endDefinition;

autoMaxContextTokens0 // beginDefinition;
autoMaxContextTokens0[ name_String ] := autoMaxContextTokens0 @ StringSplit[ name, "-"|Whitespace ];
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
autoMaxContextTokens0[ _List                                        ] := 2^12;
autoMaxContextTokens0 // endDefinition;

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
    ___ ~~ "gpt-3" ~~ ___,
    "chat-bison-001",
    "claude-instant-1.2",
    "gemini-1.0-pro" ~~ ___,
    "gemini-pro-vision",
    "gemini-pro"
];

toolsEnabledQ[ KeyValuePattern[ "ToolsEnabled" -> enabled: True|False ] ] := enabled;
toolsEnabledQ[ KeyValuePattern[ "ToolCallFrequency" -> freq: (_Integer|_Real)? NonPositive ] ] := False;
toolsEnabledQ[ KeyValuePattern[ "Model" -> model_ ] ] := toolsEnabledQ @ toModelName @ model;
toolsEnabledQ[ model: KeyValuePattern @ { "Service" -> _, "Name" -> _ } ] := toolsEnabledQ @ toModelName @ model;
toolsEnabledQ[ model_String ] := ! StringMatchQ[ model, $$disabledToolsModel, IgnoreCase -> True ];
toolsEnabledQ[ ___ ] := False;

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
CurrentChatSettings[obj$, \"key$\"] gives the current chat settings for the CellObject or NotebookObject obj$ for the specified key.
CurrentChatSettings[obj$] gives all current chat settings for obj$.
CurrentChatSettings[] is equivalent to CurrentChatSettings[EvaluationCell[]].
CurrentChatSettings[\"key$\"] is equivalent to CurrentChatSettings[EvaluationCell[], \"key$\"].\
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

setCurrentChatSettings1[ scope: $$feObj, Inherited ] :=
    If[ TrueQ @ $CloudEvaluation,
        setCurrentChatSettingsCloud[ scope, Inherited ],
        CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings" } ] = Inherited
    ];

setCurrentChatSettings1[ scope: $$feObj, value_ ] :=
    With[ { as = Association @ value },
        If[ TrueQ @ $CloudEvaluation,
            setCurrentChatSettingsCloud[ scope, as ],
            CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings" } ] = as
        ] /; AssociationQ @ as
    ];

setCurrentChatSettings1[ scope: $$feObj, key_String? StringQ, value_ ] :=
    If[ TrueQ @ $CloudEvaluation,
        setCurrentChatSettingsCloud[ scope, key, value ],
        CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", key } ] = value
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
        dir  = ConfirmBy[ $ResourceInstallationDirectory, DirectoryQ, "ResourceInstallationDirectory" ];
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

(* FIXME: make this work in cloud *)
unsetCurrentChatSettings0[ obj: $$feObj ] :=
    (CurrentValue[ obj, { TaggingRules, "ChatNotebookSettings" } ] = Inherited);

unsetCurrentChatSettings0[ obj: $$feObj, key_? StringQ ] :=
    (CurrentValue[ obj, { TaggingRules, "ChatNotebookSettings" } ] = Inherited);

unsetCurrentChatSettings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*currentChatSettings*)
currentChatSettings // beginDefinition;

currentChatSettings[ fe: $$frontEndObject ] /; $CloudEvaluation :=
    getGlobalChatSettings[ ];

currentChatSettings[ fe: $$frontEndObject, key_String ] /; $CloudEvaluation :=
    getGlobalChatSettings[ key ];

currentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession ] := (
    verifyInheritance @ obj;
    currentChatSettings0 @ obj
);

currentChatSettings[ obj: _NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] := (
    verifyInheritance @ obj;
    currentChatSettings0[ obj, key ]
);

currentChatSettings[ cell0_CellObject ] := Catch @ Enclose[
    Module[ { cell, cellInfo, styles, nbo, delimiter, settings },

        verifyInheritance @ cell0;

        cell     = cell0;
        cellInfo = ConfirmBy[ cellInformation @ cell, AssociationQ, "CellInformation" ];
        styles   = ConfirmMatch[ Flatten @ List @ Lookup[ cellInfo, "Style" ], { ___String } ];

        If[ MemberQ[ styles, $$nestedCellStyle ],
            cell   = ConfirmMatch[ topParentCell @ cell, _CellObject, "ParentCell" ];
            styles = cellStyles @ cell;
        ];

        If[ cellInfo[ "ChatNotebookSettings", "ChatDelimiter" ], Throw @ currentChatSettings0 @ cell ];

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
    throwInternalFailure[ currentChatSettings @ cell0, ## ] &
];

currentChatSettings[ cell0_CellObject, key_String ] := Catch @ Enclose[
    Module[ { cell, cellInfo, styles, nbo, cells, delimiter, values },

        verifyInheritance @ cell0;

        cell     = cell0;
        cellInfo = ConfirmBy[ cellInformation @ cell, AssociationQ, "CellInformation" ];
        styles   = ConfirmMatch[ Flatten @ List @ Lookup[ cellInfo, "Style" ], { ___String } ];

        If[ MemberQ[ styles, $$nestedCellStyle ],
            cell   = ConfirmMatch[ topParentCell @ cell, _CellObject, "ParentCell" ];
            styles = cellStyles @ cell;
        ];

        If[ cellInfo[ "ChatNotebookSettings", "ChatDelimiter" ], Throw @ currentChatSettings0[ cell, key ] ];

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
    throwInternalFailure[ currentChatSettings[ cell0, key ], ## ] &
];

currentChatSettings // endDefinition;


currentChatSettings0 // beginDefinition;

currentChatSettings0[ obj: _CellObject|_NotebookObject|_FrontEndObject|$FrontEndSession ] :=
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

currentChatSettings0[ obj: _CellObject|_NotebookObject|_FrontEndObject|$FrontEndSession, key_String ] := Replace[
    absoluteCurrentValue[ obj, { TaggingRules, "ChatNotebookSettings", key } ],
    Inherited :> Lookup[ $cachedGlobalSettings, key, Lookup[ $defaultChatSettings, key, Inherited ] ]
];

currentChatSettings0 // endDefinition;

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
