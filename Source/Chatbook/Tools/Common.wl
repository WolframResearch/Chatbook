(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];

(* :!CodeAnalysis::BeginBlock:: *)

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`Common`"            ];
Needs[ "Wolfram`Chatbook`Personas`"          ];
Needs[ "Wolfram`Chatbook`ResourceInstaller`" ];

HoldComplete[
    System`LLMTool;
    System`LLMConfiguration;
];

(* TODO:
    ImageSynthesize
    LongTermMemory
    Definitions
    TestWriter
*)
(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$$llmTool  = HoldPattern[ _LLMTool ];
$$llmToolH = HoldPattern[ LLMTool ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Lists*)
$DefaultTools   := $defaultChatTools;
$InstalledTools := $installedTools;
$AvailableTools := Association[ $DefaultTools, $InstalledTools, $selectedTools ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Exported Functions for Tool Repository*)
$ToolFunctions = <|
    "ChatPreferences"          -> chatPreferences,
    "DocumentationLookup"      -> documentationLookup,
    "DocumentationSearcher"    -> documentationSearch,
    "WebFetcher"               -> webFetch,
    "WebImageSearcher"         -> webImageSearch,
    "WebSearcher"              -> webSearch,
    "WolframAlpha"             -> getWolframAlphaText,
    "WolframLanguageEvaluator" -> wolframLanguageEvaluator
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Configuration*)
$defaultWebTextLength    = 12000;
$toolResultStringLength := Ceiling[ $initialCellStringBudget/2 ];
$webSessionVisible       = False;

$DefaultToolOptions = <|
    "WolframAlpha" -> <|
        "DefaultPods"     -> False,
        "FoldPods"        -> False,
        "MaxPodByteCount" -> 1000000
    |>,
    "WolframLanguageEvaluator" -> <|
        "AllowedExecutePaths"      -> Automatic,
        "AllowedReadPaths"         -> All,
        "AllowedWritePaths"        -> Automatic,
        "AppendURIPrompt"          -> False,
        "EvaluationTimeConstraint" -> 60,
        "Method"                   -> Automatic,
        "PingTimeConstraint"       -> 30
    |>,
    "WebFetcher" -> <|
        "MaxContentLength" -> $defaultWebTextLength
    |>,
    "WebSearcher" -> <|
        "AllowAdultContent" -> Inherited,
        "Language"          -> Inherited,
        "MaxItems"          -> 5,
        "Method"            -> "Google"
    |>,
    "WebImageSearcher" -> <|
        "AllowAdultContent" -> Inherited,
        "Language"          -> Inherited,
        "MaxItems"          -> 5,
        "Method"            -> "Google"
    |>
|>;

$defaultToolIcon = Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "WrenchIcon" ];

$selectedTools         = <| |>;
$toolBox               = <| |>;
$toolEvaluationResults = <| |>;
$toolOptions           = <| |>;

$cloudUnsupportedTools = { };

$defaultToolOrder = {
    "DocumentationLookup",
    "DocumentationSearcher",
    "WolframAlpha",
    "WolframLanguageEvaluator"
};

$toolNameAliases = <|
    "DocumentationSearch" -> "DocumentationSearcher",
    "WebFetch"            -> "WebFetcher",
    "WebImageSearch"      -> "WebImageSearcher",
    "WebSearch"           -> "WebSearcher"
|>;

$installedToolExtraKeys = {
    "Description",
    "DocumentationLink",
    "Origin",
    "ResourceName",
    "Templated",
    "Version"
};

$autoAppearanceRules = <|
    "DocumentationLink"  -> None,
    "FormattingFunction" -> Automatic,
    "Icon"               -> $defaultToolIcon,
    "Origin"             -> "Unknown"
|>;

$appearanceRulesKeys = Keys @ $autoAppearanceRules;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Default Tools*)
$defaultChatTools := (
    reevaluateToolExpressions[ ];
    If[ TrueQ @ $CloudEvaluation,
        KeyDrop[ $defaultChatTools0, $cloudUnsupportedTools ],
        $defaultChatTools0
    ]
);

$defaultChatTools0 = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*reevaluateToolExpressions*)
reevaluateToolExpressions // beginDefinition;

reevaluateToolExpressions[ ] :=
    If[ TrueQ @ Wolfram`ChatbookInternal`$BuildingMX,
        Null,
        $defaultChatTools0 = AssociationMap[ Identity, $defaultChatTools0 ];
        reevaluateToolExpressions[ ] = Null
    ];

reevaluateToolExpressions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Installed Tools*)
$installedTools := Association @ Cases[
    GetInstalledResourceData[ "LLMTool" ],
    as: KeyValuePattern[ "Tool" -> tool0_ ] :>
        With[ { tool = Quiet @ tool0 },
            (toolName @ tool -> addExtraToolData[ tool, as ]) /; MatchQ[ tool, _LLMTool ]
        ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*addExtraToolData*)
addExtraToolData // beginDefinition;

addExtraToolData[ tool: HoldPattern @ LLMTool[ as_Association, a___ ], extra_Association ] :=
    With[ { new = Join[ KeyTake[ extra, $installedToolExtraKeys ], as ] }, LLMTool[ new, a ] ];

addExtraToolData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getToolByName*)
getToolByName // beginDefinition;

getToolByName[ name_String ] := Lookup[
    $AvailableTools,
    name,
    Lookup[ $AvailableTools, toCanonicalToolName @ name ]
];

getToolByName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getToolByShortName*)
getToolByShortName // beginDefinition;
getToolByShortName[ cmd_String ] := SelectFirst[ $toolBox, toolShortName[ #1 ] === cmd & ];
getToolByShortName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolName*)
toolName // beginDefinition;
toolName[ tool_ ] := toolName[ tool, Automatic ];
toolName[ tool: $$llmTool, type_ ] := toolName[ tool type ] = toolName[ toolData @ tool, type ];
toolName[ KeyValuePattern[ "CanonicalName" -> name_String ], "Canonical" ] := name;
toolName[ KeyValuePattern[ "DisplayName" -> name_String ], "Display" ] := name;
toolName[ KeyValuePattern[ "Name" -> name_String ], type_ ] := toolName[ name, type ];
toolName[ tool_, Automatic ] := toolName[ tool, "Canonical" ];
toolName[ name_String, "Machine" ] := toMachineToolName @ name;
toolName[ name_String, "Canonical" ] := toCanonicalToolName @ name;
toolName[ name_String, "Display" ] := toDisplayToolName @ name;
toolName[ tools_List, type_ ] := toolName[ #, type ] & /@ tools;
toolName[ Inherited|ParentList, type_ ] := Missing[ "NotAvailable" ];
toolName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolData*)
toolData // beginDefinition;

toolData[ tool: $$llmToolH[ as_Association, ___ ] ] := toolData[ tool ] =
    toolData @ <| toolAppearanceRules @ tool, as |>;

toolData[ name_String ] /; KeyExistsQ[ $toolBox, name ] :=
    toolData @ $toolBox[ name ];

toolData[ name_String ] /; KeyExistsQ[ $defaultChatTools, name ] :=
    toolData @ $defaultChatTools[ name ];

toolData[ as: KeyValuePattern @ { "Function"|"ToolCall" -> _ } ] := <|
    toolDefaultData @ toolName @ as,
    "Icon" -> toolDefaultIcon @ as,
    DeleteCases[ as, Automatic ]
|>;

toolData[ tools_List ] :=
    toolData /@ tools;

toolData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolAppearanceRules*)
toolAppearanceRules // beginDefinition;

toolAppearanceRules[ tool: $$llmToolH[ as_Association, { opts: OptionsPattern[ ] }, ___ ] ] := Enclose[
    Module[ { optValue, optSetting, inlineSetting, autoSettings, combined },
        optValue      = Association @ quietOptionValue[ LLMTool, { opts }, AppearanceRules ];
        optSetting    = If[ AssociationQ @ optValue, optValue, <| |> ];
        inlineSetting = ConfirmBy[ KeyTake[ as, $appearanceRulesKeys ], AssociationQ, "Inline" ];
        autoSettings  = ConfirmBy[ $autoAppearanceRules, AssociationQ, "Auto" ];
        combined      = ConfirmBy[ <| $autoAppearanceRules, inlineSetting, optSetting |> , AssociationQ, "Combined" ];

        toolAppearanceRules[ tool ] = combined
    ],
    throwInternalFailure
];

toolAppearanceRules[ tool: $$llmToolH[ as_Association, ___ ] ] :=
    <| $autoAppearanceRules, KeyTake[ as, $appearanceRulesKeys ] |>;

toolAppearanceRules // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*quietOptionValue*)
quietOptionValue // beginDefinition;

quietOptionValue[ sym_Symbol, opts_List, name_ ] :=
    quietOptionValue[ sym, opts, name, Automatic ];

quietOptionValue[ sym_Symbol, { opts: OptionsPattern[ ] }, name_, default_ ] := Quiet[
    Replace[ OptionValue[ sym, { opts }, name ], HoldPattern[ name ] :> default ],
    { OptionValue::nodef, OptionValue::optnf }
];

quietOptionValue // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolDefaultIcon*)
toolDefaultIcon // beginDefinition;

toolDefaultIcon[ KeyValuePattern[ "Origin" -> "LLMToolRepository" ] ] :=
    RawBoxes @ TemplateBox[ { }, "ToolManagerRepository" ];

toolDefaultIcon[ _Association ] :=
    $defaultToolIcon;

toolDefaultIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolDefaultData*)
toolDefaultData // beginDefinition;

toolDefaultData[ name_String ] :=
    With[ { mName = toMachineToolName @ name },
        <|
            "CanonicalName" -> toCanonicalToolName @ name,
            "DisplayName"   -> toDisplayToolName @ name,
            "Name"          -> mName,
            "ShortName"     -> mName,
            "Icon"          -> $defaultToolIcon
        |>
    ];

toolDefaultData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toMachineToolName*)
toMachineToolName // beginDefinition;

toMachineToolName[ s_String ] :=
    ToLowerCase @ StringReplace[
        StringTrim @ s,
        { " " -> "_", a_?LowerCaseQ ~~ b_?UpperCaseQ ~~ c_?LowerCaseQ :> a<>"_"<>b<>c }
    ];

toMachineToolName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toCanonicalToolName*)
toCanonicalToolName // beginDefinition;

toCanonicalToolName[ s_String ] :=
    Capitalize @ StringReplace[ StringTrim @ s, a_~~("_"|" ")~~b_ :> a <> ToUpperCase @ b ];

toCanonicalToolName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toDisplayToolName*)
toDisplayToolName // beginDefinition;

toDisplayToolName[ s_String ] :=
    Capitalize[
        StringReplace[
            StringTrim @ s,
            { "_" :> " ", a_?LowerCaseQ ~~ b_?UpperCaseQ ~~ c_?LowerCaseQ :> a<>" "<>b<>c }
        ],
        "TitleCase"
    ];

toDisplayToolName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatToolCallExample*)
formatToolCallExample // beginDefinition;

formatToolCallExample[ name_String, params_Association ] :=
    formatToolCallExample[ name, params, $ChatHandlerData[ "ChatNotebookSettings", "ToolMethod" ] ];

formatToolCallExample[ name_String, params_Association, "Simple" ] := Enclose[
    Module[ { command, values },
        command = ConfirmBy[ toolShortName @ name, StringQ, "Command" ];
        values = ConfirmMatch[ Values @ params, { ___String }, "Values" ];
        TemplateApply[ "/`1`\n`2`\n/exec", { command, StringRiffle[ values, "\n" ] } ]
    ],
    throwInternalFailure
];

formatToolCallExample[ name_String, params_Association, _ ] :=
    TemplateApply[
        "TOOLCALL: `1`\n`2`\nENDARGUMENTS\nENDTOOLCALL",
        { toMachineToolName @ name, Developer`WriteRawJSONString @ params }
    ];

formatToolCallExample // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Toolbox*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolSelectedQ*)
toolSelectedQ // beginDefinition;
toolSelectedQ[ name_String ] := KeyExistsQ[ $selectedTools, name ];
toolSelectedQ[ tools_List ] := AllTrue[ tools, toolSelectedQ ];
toolSelectedQ[ tool_ ] := KeyExistsQ[ $selectedTools, toolName @ tool ];
toolSelectedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withToolBox*)
withToolBox // beginDefinition;
withToolBox // Attributes = { HoldFirst };
withToolBox[ eval_ ] := Block[ { $selectedTools = <| |>, $toolOptions = $DefaultToolOptions }, eval ];
withToolBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*selectTools*)
selectTools // beginDefinition;

selectTools[ as_Association ] := Enclose[
    Module[ { llmEvaluatorName, toolNames, selections, selectionTypes, add, remove, selectedNames, short },

        llmEvaluatorName = ConfirmBy[ getLLMEvaluatorName @ as, StringQ, "LLMEvaluatorName" ];
        toolNames        = ConfirmMatch[ getToolNames @ as, { ___String }, "Names" ];
        selections       = ConfirmBy[ getToolSelections @ as, AssociationQ, "Selections" ];
        selectionTypes   = ConfirmBy[ getToolSelectionTypes @ as, AssociationQ, "SelectionTypes" ];

        add = ConfirmMatch[
            Union[
                Keys @ Select[ selections, Lookup @ llmEvaluatorName ],
                Keys @ Select[ selectionTypes, SameAs @ All ]
            ],
            { ___String },
            "ToolAdditions"
        ];

        remove = ConfirmMatch[
            Union[
                Keys @ Select[ selections, Not @* Lookup[ llmEvaluatorName ] ],
                Keys @ Select[ selectionTypes, SameAs @ None ]
            ],
            { ___String },
            "ToolRemovals"
        ];

        selectedNames = ConfirmMatch[
            Complement[ Union[ toolNames, add ], remove ],
            { ___String },
            "SelectedNames"
        ];

        selectTools0 /@ selectedNames;

        $selectedTools = Select[ $selectedTools, toolEnabledQ ];
        short = <| (toolShortName[ # ] -> # &) /@ Values[ $selectedTools ] |>;

        addHandlerArguments[ "ToolShortNames" -> short ];

        $selectedTools
    ],
    throwInternalFailure
];

selectTools // endDefinition;


(* TODO: Most of this functionality is moved to `getToolNames`. This only needs to operate on strings. *)
selectTools0 // beginDefinition;

selectTools0[ Automatic|Inherited ] := selectTools0 @ $defaultChatTools;
selectTools0[ None                ] := $selectedTools = <| |>;
selectTools0[ name_String         ] /; KeyExistsQ[ $toolBox, name ] := $selectedTools[ name ] = $toolBox[ name ];
selectTools0[ name_String         ] /; KeyExistsQ[ $toolNameAliases, name ] := selectTools0 @ $toolNameAliases @ name;
selectTools0[ name_String         ] := selectTools0[ name, Lookup[ $AvailableTools, name ] ];
selectTools0[ tools_List          ] := selectTools0 /@ tools;
selectTools0[ tools_Association   ] := KeyValueMap[ selectTools0, tools ];

(* Literal LLMTool specification: *)
selectTools0[ tool: HoldPattern @ LLMTool[ KeyValuePattern[ "Name" -> name_ ], ___ ] ] := selectTools0[ name, tool ];

(* Rules can be used to enable/disable by name: *)
selectTools0[ (Rule|RuleDelayed)[ name_String, tool_ ] ] := selectTools0[ name, tool ];

(* Inherit from core tools: *)
selectTools0[ name_String, Automatic|Inherited ] := selectTools0[ name, Lookup[ $defaultChatTools, name ] ];

(* Disable tool: *)
selectTools0[ name_String, None ] := KeyDropFrom[ $selectedTools, name ];

(* Select a literal LLMTool: *)
selectTools0[ name_String, tool: HoldPattern[ _LLMTool ] ] := $selectedTools[ name ] = $toolBox[ name ] = tool;

(* Tool not found: *)
selectTools0[ name_String, Missing[ "KeyAbsent", name_ ] ] :=
    If[ TrueQ @ KeyExistsQ[ $defaultChatTools0, name ],
        (* A default tool that was filtered for compatibility *)
        Null,
        (* An unknown tool name *)
        messagePrint[ "ToolNotFound", name ]
    ];

selectTools0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolEnabledQ*)
toolEnabledQ // beginDefinition;
toolEnabledQ[ $$llmToolH[ as_, ___ ] ] := as[ "Enabled" ] =!= False;
toolEnabledQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getLLMEvaluatorName*)
getLLMEvaluatorName // beginDefinition;
getLLMEvaluatorName[ KeyValuePattern[ "LLMEvaluatorName" -> name_String ] ] := name;
getLLMEvaluatorName[ KeyValuePattern[ "LLMEvaluator" -> name_String ] ] := name;

getLLMEvaluatorName[ KeyValuePattern[ "LLMEvaluator" -> evaluator_Association ] ] :=
    Lookup[ evaluator, "LLMEvaluatorName", Lookup[ evaluator, "Name" ] ];

getLLMEvaluatorName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolNames*)
getToolNames // beginDefinition;

(* Persona declares tools, so combine with defaults as appropriate *)
getToolNames[ as: KeyValuePattern[ "LLMEvaluator" -> KeyValuePattern[ "Tools" -> tools_ ] ] ] :=
    getToolNames[ Lookup[ as, "Tools", None ], tools ];

(* No tool specification by persona, so get defaults *)
getToolNames[ as_Association ] :=
    getToolNames @ Lookup[ as, "Tools", Automatic ];

(* Persona does not want any tools *)
getToolNames[ tools_, None ] := { };

(* Persona wants default tools *)
getToolNames[ tools_, Automatic|Inherited|ParentList ] := getToolNames @ tools;

(* Persona declares an explicit list of tools *)
getToolNames[ Automatic|None|Inherited, personaTools_List ] := getToolNames @ personaTools;

(* Persona inherits tools: *)
getToolNames[ { parent___ }, { a___, ParentList, b___ } ] := getToolNames @ { a, parent, b };

(* The user has specified an explicit list of tools as well, so include them *)
getToolNames[ tools_List, personaTools_List ] := Union[ getToolNames @ tools, getToolNames @ personaTools ];

(* Get name of each tool *)
getToolNames[ tools_List ] :=
    DeleteDuplicates @ Flatten[ getCachedToolName /@ DeleteCases[ tools, $$unspecified|ParentList ] ];

(* Default tools *)
getToolNames[ Automatic|Inherited ] := Keys @ $DefaultTools;

(* All tools *)
getToolNames[ All ] := Keys @ $AvailableTools;

(* No tools *)
getToolNames[ None ] := { };

(* A single tool specification without an enclosing list *)
getToolNames[ tool: Except[ _List ] ] := getToolNames @ { tool };

getToolNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getCachedToolName*)
getCachedToolName // beginDefinition;

getCachedToolName[ tool: HoldPattern[ _LLMTool ] ] := Enclose[
    Module[ { name },
        name = ConfirmBy[ toolName @ tool, StringQ, "Name" ];
        ConfirmAssert[ AssociationQ @ $toolBox, "ToolBox" ];
        $toolBox[ name ] = tool;
        name
    ],
    throwInternalFailure
];

getCachedToolName[ name_String ] :=
    With[ { canonical = toCanonicalToolName @ name },
        Which[
            KeyExistsQ[ $toolBox         , canonical ], canonical,
            KeyExistsQ[ $toolNameAliases , canonical ], getCachedToolName @ $toolNameAliases @ canonical,
            KeyExistsQ[ $defaultChatTools, canonical ], getCachedToolName @ $defaultChatTools @ canonical,
            True                                      , name
        ]
    ];

getCachedToolName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolSelections*)
getToolSelections // beginDefinition;
getToolSelections[ as_Association ] := getToolSelections[ as, Lookup[ as, "ToolSelections", <| |> ] ];
getToolSelections[ as_, selections_Association ] := KeyTake[ selections, Keys @ $AvailableTools ];
getToolSelections[ as_, Except[ _Association ] ] := <| |>;
getToolSelections // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolSelectionTypes*)
getToolSelectionTypes // beginDefinition;
getToolSelectionTypes[ as_Association ] := getToolSelectionTypes[ as, Lookup[ as, "ToolSelectionType", <| |> ] ];
getToolSelectionTypes[ as_, selections_Association ] := KeyTake[ selections, Keys @ $AvailableTools ];
getToolSelectionTypes[ as_, Except[ _Association ] ] := <| |>;
getToolSelectionTypes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*initTools*)
initTools // beginDefinition;

initTools[ ] := initTools[ ] = (

    If[ $CloudEvaluation && $VersionNumber <= 13.2,

        If[ PacletFind[ "ServiceConnection_OpenAI" ] === { },
            PacletInstall[ "ServiceConnection_OpenAI", PacletSite -> "https://pacletserver.wolfram.com" ]
        ];

        WithCleanup[
            Unprotect @ TemplateObject,
            TemplateObject // Options = DeleteDuplicatesBy[
                Append[ Options @ TemplateObject, MetaInformation -> <| |> ],
                ToString @* First
            ],
            Protect @ TemplateObject
        ]
    ];


    installLLMFunctions[ ];
);

initTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installLLMFunctions*)
installLLMFunctions // beginDefinition;

installLLMFunctions[ ] := Enclose[
    Module[ { before, paclet, opts, reload },
        before = Quiet @ PacletObject[ "Wolfram/LLMFunctions" ];
        paclet = ConfirmBy[ PacletInstall[ "Wolfram/LLMFunctions" ], PacletObjectQ, "PacletInstall" ];

        If[ ! TrueQ @ Quiet @ PacletNewerQ[ paclet, "1.2.1" ],
            opts = If[ $CloudEvaluation, PacletSite -> "https://pacletserver.wolfram.com", UpdatePacletSites -> True ];
            paclet = ConfirmBy[ PacletInstall[ "Wolfram/LLMFunctions", opts ], PacletObjectQ, "PacletUpdate" ];
            ConfirmAssert[ PacletNewerQ[ paclet, "1.2.1" ], "PacletVersion" ];
            reload = True,
            reload = PacletObjectQ @ before && PacletNewerQ[ paclet, before ]
        ];

        If[ TrueQ @ reload, reloadLLMFunctions[ ] ];
        Needs[ "Wolfram`LLMFunctions`" -> None ];
        installLLMFunctions[ ] = paclet
    ],
    throwInternalFailure[ installLLMFunctions[ ], ## ] &
];

installLLMFunctions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reloadLLMFunctions*)
reloadLLMFunctions // beginDefinition;

reloadLLMFunctions[ ] := Enclose[
    Module[ { paclet, files },
        paclet = ConfirmBy[ PacletObject[ "Wolfram/LLMFunctions" ], PacletObjectQ, "PacletObject" ];
        files = Select[ $LoadedFiles, StringContainsQ[ "LLMFunctions" ] ];
        If[ ! AnyTrue[ files, StringStartsQ @ paclet[ "Location" ] ],
            (* Force paclet to reload if the new one has not been loaded *)
            WithCleanup[
                Unprotect @ $Packages,
                $Packages = Select[ $Packages, Not @* StringStartsQ[ "Wolfram`LLMFunctions`" ] ];
                ClearAll[ "Wolfram`LLMFunctions`*" ];
                ClearAll[ "Wolfram`LLMFunctions`*`*" ];
                Block[ { $ContextPath }, Get[ "Wolfram`LLMFunctions`" ] ],
                Protect @ $Packages
            ]
        ]
    ],
    throwInternalFailure[ reloadLLMFunctions[ ], ## ] &
];

reloadLLMFunctions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveTools*)
resolveTools // beginDefinition;

resolveTools[ settings: KeyValuePattern[ "ToolsEnabled" -> True ] ] := (
    initTools[ ];
    selectTools @ settings;
    $toolOptions = Lookup[ settings, "ToolOptions", $DefaultToolOptions ];
    $lastSelectedTools = $selectedTools;
    $lastToolOptions = $toolOptions;
    If[ KeyExistsQ[ $selectedTools, "WolframLanguageEvaluator" ], needsBasePrompt[ "WolframLanguageEvaluatorTool" ] ];
    Append[ settings, "Tools" -> Values @ $selectedTools ]
);

resolveTools[ settings_Association ] := settings;

resolveTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeToolConfiguration*)
makeToolConfiguration // beginDefinition;

makeToolConfiguration[ settings_Association ] := Enclose[
    Module[ { tools },
        tools = ConfirmMatch[ DeleteDuplicates @ Flatten @ Values @ $selectedTools, { ___LLMTool }, "SelectedTools" ];
        $toolConfiguration = LLMConfiguration @ <| "Tools" -> tools, "ToolPrompt" -> makeToolPrompt @ settings |>
    ],
    throwInternalFailure[ makeToolConfiguration @ settings, ## ] &
];

makeToolConfiguration // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$toolConfiguration*)
$toolConfiguration := $toolConfiguration = LLMConfiguration @ <| "Tools" -> Values @ $defaultChatTools |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolRequestParser*)
toolRequestParser // beginDefinition;

toolRequestParser[ content_String ] := Enclose[
    Catch @ Module[ { calls, toolName, paramsJSON, rawCallString, callPosition, bag, params },

        calls = StringCases[
            content,
            StringExpression[
                StartOfString,
                Longest[ ___ ],
                callString: StringExpression[
                    "TOOLCALL: ",
                    Shortest[ toolNameStr__ ],
                    EndOfLine,
                    Shortest[ paramsStr__ ],
                    "ENDARGUMENTS",
                    WhitespaceCharacter...,
                    EndOfString
                ]
            ] :> { StringTrim @ toolNameStr, paramsStr, StringTrim @ callString }
        ];

        If[ Length @ calls =!= 1, Throw @ None ];
        { toolName, paramsJSON, rawCallString } = First @ calls;
        callPosition = Last @ StringPosition[ content, rawCallString ];
        bag = Internal`Bag[ ];

        params = Quiet @ Internal`HandlerBlock[ { "Message", jsonMessageHandler @ bag },
                             Developer`ReadRawJSONString @ paramsJSON
                         ];

        If[ FailureQ @ params,
            Throw @ { callPosition, Failure[ "InvalidJSON", <| "Message" -> makeJSONFailureMessage @ bag |> ] }
        ];

        {
            callPosition,
            System`LLMToolRequest[ toolName, Normal @ params, rawCallString<>"\nENDTOOLCALL" ]
        }
    ],
    throwInternalFailure
];

toolRequestParser // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeJSONFailureMessage*)
makeJSONFailureMessage // beginDefinition;

makeJSONFailureMessage[ bag_Internal`Bag ] :=
    makeJSONFailureMessage @ Internal`BagPart[ bag, All ];

makeJSONFailureMessage[ messages: { __String } ] := StringRiffle[
    Flatten @ { "Parsing arguments as JSON failed with the following messages:", "\t" <> # & /@ messages },
    "\n"
];

makeJSONFailureMessage[ ___ ] :=
    "Arguments were not valid JSON.";

makeJSONFailureMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*jsonMessageHandler*)
jsonMessageHandler // beginDefinition;

jsonMessageHandler[ bag_Internal`Bag ] :=
    jsonMessageHandler[ bag, # ] &;

jsonMessageHandler[
    bag_Internal`Bag,
    Hold[ Message[ msg: MessageName[ Developer`ReadRawJSONString, tag__ ], params___ ], _ ]
] := Enclose[
    Module[ { template, args, string },
        template = ConfirmBy[ If[ StringQ @ msg, msg, MessageName[ General, tag ] ], StringQ ];
        args = ConfirmMatch[ messageParameterString /@ Unevaluated @ { params }, { ___String } ];
        string = ConfirmBy[ TemplateApply[ template, args ], StringQ ];
        Internal`StuffBag[ bag, string ]
    ],
    throwInternalFailure
];

jsonMessageHandler // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*messageParameterString*)
messageParameterString // beginDefinition;
messageParameterString // Attributes = { HoldAllComplete };
messageParameterString[ expr_ ] := ToString[ Unevaluated @ Short[ expr, 1 ], PageWidth -> 80 ];
messageParameterString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*simpleToolRequestParser*)
simpleToolRequestParser // beginDefinition;

simpleToolRequestParser[ string_String ] := Enclose[
    Catch @ Module[ { tools, commands, calls, command, argString, callString, callPos, tool, name, paramNames, params },

        tools = ConfirmMatch[ Values @ $AvailableTools, { ___LLMTool }, "Tools" ];
        commands = ConfirmMatch[ toolShortName /@ tools, { ___String }, "Commands" ];

        (* TODO: return failure when trying to use an invalid tool command string *)
        calls = StringCases[
            StringDelete[ string, "/" ~~ commands ~~ ___ ~~ "/exec" ],
            Longest @ StringExpression[
                StartOfString,
                ___,
                StartOfLine,
                WhitespaceCharacter...,
                s: ("/" ~~ cmd: commands ~~ args___),
                EndOfString
            ] :> { StringTrim @ cmd, StringTrim @ args, s }
        ];

        If[ calls === { }, Throw @ None ];

        { command, argString, callString } = ConfirmMatch[ First @ calls, { _String, _String, _String }, "CallParts" ];

        callPos = ConfirmMatch[ Last[ StringPosition[ string, callString ], $Failed ], { __Integer }, "CallPosition" ];
        tool = ConfirmMatch[ AssociationThread[ commands -> tools ][ command ], _LLMTool, "Tool" ];

        name = ConfirmBy[ tool[ "Name" ], StringQ, "ToolName" ];

        paramNames = Keys @ ConfirmMatch[ tool[ "Parameters" ], KeyValuePattern @ { }, "ParameterNames" ];
        params = ConfirmBy[ parseSimpleToolCallParameterStrings[ paramNames, argString ], AssociationQ, "Parameters" ];

        { callPos, LLMToolRequest[ name, params, callString ] }
    ],
    throwInternalFailure
];

simpleToolRequestParser // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseSimpleToolCallParameterStrings*)
$$argNameDelimiter = (":"|"="|"-") ~~ " "...;

parseSimpleToolCallParameterStrings // beginDefinition;

parseSimpleToolCallParameterStrings[ { param_String }, argString_String ] :=
    <| param -> StringDelete[ argString, StartOfString ~~ WhitespaceCharacter... ~~ param ~~ $$argNameDelimiter ] |>;

parseSimpleToolCallParameterStrings[ paramNames: { __String }, argString_String ] := Enclose[
    Catch @ Module[ { namedSplit, defaults, pairs, as },
        namedSplit = StringSplit[ argString, StartOfLine ~~ (" "|"\t"|"")... ~~ p: paramNames ~~ $$argNameDelimiter :> p ];
        If[ OddQ @ Length @ namedSplit, Throw @ parseSimpleToolCallParameterStrings0[ paramNames, argString ] ];
        defaults = AssociationMap[ "" &, paramNames ];
        pairs = ConfirmMatch[ Partition[ namedSplit, 2 ], { { _String, _String } .. }, "Pairs" ];
        as = ConfirmBy[ <| defaults, Rule @@@ pairs |>, AssociationQ, "Parameters" ];
        ConfirmBy[ trimSimpleParameterString /@ as, AllTrue @ StringQ, "Result" ]
    ],
    throwInternalFailure
];

parseSimpleToolCallParameterStrings // endDefinition;


parseSimpleToolCallParameterStrings0 // beginDefinition;

parseSimpleToolCallParameterStrings0[ paramNames: { __String }, argString_String ] := Enclose[
    Module[ { split, padded, threaded },
        split = StringSplit[ argString, "\n" ];
        padded = PadRight[ split, Length @ paramNames, "" ];
        threaded = ConfirmBy[ AssociationThread[ paramNames -> padded ], AssociationQ, "Parameters" ];
        ConfirmBy[ trimSimpleParameterString /@ threaded, AllTrue @ StringQ, "Result" ]
    ],
    throwInternalFailure
];

parseSimpleToolCallParameterStrings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*trimSimpleParameterString*)
trimSimpleParameterString // beginDefinition;

trimSimpleParameterString[ s_String ] := StringDelete[
    s,
    {
        StartOfString ~~ Alternatives[
            WhitespaceCharacter... ~~ "|" ~~ WhitespaceCharacter... ~~ "\n" ~~ WhitespaceCharacter...,
            WhitespaceCharacter...
        ],
        WhitespaceCharacter... ~~ EndOfString
    }
];

trimSimpleParameterString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolShortName*)
toolShortName // beginDefinition;

toolShortName[ $$llmToolH[ as_Association, ___ ] ] :=
    toolShortName @ as;

toolShortName[ as_Association ] :=
    Lookup[ as, "ShortName", Lookup[ as, "Name" ] ];

toolShortName[ name_String ] :=
    With[ { tool = getToolByName @ name },
        If[ MatchQ[ tool, $$llmTool ],
            toolShortName @ tool,
            name
        ]
    ];

toolShortName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolPrompt*)
makeToolPrompt // beginDefinition;

makeToolPrompt[ settings_Association ] := $lastToolPrompt = TemplateObject[
    Riffle[
        DeleteMissing @ Flatten @ {
            getToolPrePrompt @ settings,
            getToolListingPrompt @ settings,
            getToolExamplePrompt @ settings,
            getToolPostPrompt @ settings,
            makeToolPreferencePrompt @ settings
        },
        "\n\n"
    ],
    CombinerFunction  -> StringJoin,
    InsertionFunction -> TextString
];

makeToolPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolPrePrompt*)
getToolPrePrompt // beginDefinition;
getToolPrePrompt[ as_Association ] := getToolPrePrompt[ as, as[ "ToolMethod" ], as[ "ToolPrePrompt" ] ];
getToolPrePrompt[ as_, "Service", $$unspecified ] := Nothing;
getToolPrePrompt[ as_, "Simple", $$unspecified ] := $simpleToolPre;
getToolPrePrompt[ as_, method_, $$unspecified ] := $toolPre;
getToolPrePrompt[ as_, method_, prompt: $$template ] := prompt;
getToolPrePrompt[ as_, method_, None ] := Nothing;
getToolPrePrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolListingPrompt*)
getToolListingPrompt // beginDefinition;
getToolListingPrompt[ as_Association ] := getToolListingPrompt[ as, as[ "ToolMethod" ], as[ "ToolListingPrompt" ] ];
getToolListingPrompt[ as_, "Service", $$unspecified ] := Nothing;
getToolListingPrompt[ as_, "Simple", $$unspecified ] := $simpleToolListing;
getToolListingPrompt[ as_, method_, $$unspecified ] := $toolListing;
getToolListingPrompt[ as_, method_, prompt: $$template ] := prompt;
getToolListingPrompt[ as_, method_, None ] := Nothing;
getToolListingPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolPostPrompt*)
getToolPostPrompt // beginDefinition;
getToolPostPrompt[ as_Association ] := getToolPostPrompt[ as, as[ "ToolMethod" ], as[ "ToolPostPrompt" ] ];
getToolPostPrompt[ as_, "Service", $$unspecified ] := Nothing;
getToolPostPrompt[ as_, "Simple", $$unspecified ] := $simpleToolPost;
getToolPostPrompt[ as_, method_, $$unspecified ] := $toolPost;
getToolPostPrompt[ as_, method_, prompt: $$template ] := prompt;
getToolPostPrompt[ as_, method_, None ] := Nothing;
getToolPostPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolExamplePrompt*)
getToolExamplePrompt // beginDefinition;

getToolExamplePrompt[ as_Association ] :=
    getToolExamplePrompt[ as, as[ "ToolMethod" ], as[ "ToolExamplePrompt" ], as[ "ToolCallExamplePromptStyle" ] ];

getToolExamplePrompt[ as_, method_, $$unspecified, style_String ] :=
    Block[ { $messageTemplateType = style }, $fullExamples ];

getToolExamplePrompt[ as_, method_, prompt: $$template, style_ ] :=
    prompt;

getToolExamplePrompt[ as_, method_, None, style_ ] :=
    Nothing;

getToolExamplePrompt[ as_, method_, $$unspecified, None ] :=
    Nothing;

getToolExamplePrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Tool Prompt Components*)
$toolPre = "\
# Tool Instructions

You have access to tools which can be used to do things, fetch data, compute, etc. while you create your response. \
Each tool takes input as JSON following a JSON schema.";


$toolPost := "\
To call a tool, write the following at any time during your response:

TOOLCALL: <tool name>
{
	\"<parameter name 1>\": <value 1>
	\"<parameter name 2>\": <value 2>
}
ENDARGUMENTS
ENDTOOLCALL

Always use valid JSON to specify the parameters in the tool call. Always follow the tool's JSON schema to specify the \
parameters in the tool call. Fill in the values in <> brackets with the values for the particular tool. Provide as \
many parameters as the tool requires. Always make one tool call at a time. Always write two line breaks before each \
tool call.

The system will execute the requested tool call and you will receive a system message containing the result. \
You can then use this result to finish writing your response for the user.

These are text-based tools, which you call by writing text, \
so you must write the tool call DURING your CURRENT response. \
Do not state that you will use a tool and end your message text before making the tool call \
or the entire system will fail catastrophically.

If a user asks you to use a specific tool, you MUST attempt to use that tool as requested, \
even if you think it will not work. \
If the tool fails, use any error message to correct the issue or explain why it failed. \
NEVER state that a tool cannot be used for a particular task without trying it first. \
You did not create these tools, so you do not know what they can and cannot do.

You should try to avoid mentioning tools by name in your response and instead speak generally about their function. \
For example, if there were a number_adder tool, you would instead talk about \"adding numbers\". If you must mention \
a tool by name, you should use the DisplayName property instead of the tool name.

IMPORTANT! If a tool call fails to give the desired result for any reason, \
you MUST write /retry before making the next tool call:

/retry
TOOLCALL: <tool name>
<new parameters>
ENDARGUMENTS
ENDTOOLCALL

This will hide the previous tool call in a collapsed section that the user can open if they wish to see prior attempts.
If you fail to do this, the user will have a hard time knowing which tool calls contain the correct results.
Only make one tool call at a time.";


$toolListing = {
    "Here are the available tools and their associated schemas:\n\n",
    TemplateSequence[
        TemplateExpression @ TemplateObject[
            {
                "Tool Name: ",
                TemplateSlot[ "Name" ],
                "\nDisplay Name: ",
                TemplateSlot[ "DisplayName" ],
                "\nDescription: ",
                TemplateSlot[ "Description" ],
                "\nSchema:\n",
                TemplateSlot[ "Schema" ],
                "\n\n"
            },
            CombinerFunction  -> StringJoin,
            InsertionFunction -> TextString
        ],
        TemplateExpression @ Map[
            Association[
                #[ "Data" ],
                "Schema" -> ExportString[ #[ "JSONSchema" ], "JSON" ],
                "DisplayName" -> getToolDisplayName @ #
            ] &,
            TemplateSlot[ "Tools" ]
        ]
    ]
};


$simpleToolPre = "\
# Tools

You have access to tools which can be used to compute results.
To call a tool, write the following before ending your response:

/command
arg1
arg2
/exec

After you write /exec, the system will execute the tool call for you and return the result.

If your arguments require multiple lines, specify the name of each argument followed by a colon and a space, \
then the value:

/command
arg1: value that
spans multiple
lines
arg2: another
value
/exec
";


$simpleToolPost = "\
## Important

You must write the tool call in your CURRENT response.
Do not state that you will use a tool and end your message before making the tool call.
Only make one tool call at a time.";


$simpleToolListing = {
    "## Available Tools\n\n",
    TemplateExpression @ StringRiffle[ simpleToolSchema /@ TemplateSlot[ "Tools" ], "\n\n" ]
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*simpleToolSchema*)
simpleToolSchema // beginDefinition;

simpleToolSchema[ $$llmToolH[ as_, ___ ] ] :=
    simpleToolSchema @ as;

simpleToolSchema[ as_Association ] := Enclose[
    Module[ { data, name, command, description, args, argStrings },

        data        = ConfirmBy[ toolData @ as, AssociationQ, "Data" ];
        name        = ConfirmBy[ toolName[ data, "Display" ], StringQ, "Name" ];
        command     = ConfirmBy[ toolShortName @ data, StringQ, "ShortName" ];
        description = ConfirmBy[ data[ "Description" ], StringQ, "Description" ];
        args        = ConfirmMatch[ as[ "Parameters" ], KeyValuePattern @ { }, "Arguments" ];
        argStrings  = ConfirmMatch[ simpleArgStrings @ args, { __String }, "ArgStrings" ];

        StringReplace[
            TemplateApply[
                $simpleSchemaTemplate,
                <|
                    "DisplayName" -> name,
                    "ShortName"   -> command,
                    "Description" -> description,
                    "Arguments"   -> StringRiffle[ argStrings, "\n" ]
                |>
            ],
        "\n\n" -> "\n"
        ]
    ],
    throwInternalFailure
];

simpleToolSchema // endDefinition;


$simpleSchemaTemplate = StringTemplate[ "\
%%DisplayName%% (/%%ShortName%%)
%%Description%%
Arguments
%%Arguments%%",
Delimiters -> "%%"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*simpleArgString*)
simpleArgStrings // beginDefinition;
simpleArgStrings[ params_Association? AssociationQ ] := KeyValueMap[ simpleArgString, params ];
simpleArgStrings[ params: KeyValuePattern @ { } ] := Cases[ params, _[ a_, b_ ] :> simpleArgString[ a, b ] ];
simpleArgStrings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*simpleArgString*)
simpleArgString // beginDefinition;

simpleArgString[ name_String, info_Association ] :=
    "\t" <> StringTrim @ simpleArgString[ name, info[ "Interpreter" ], info[ "Help" ], info[ "Required" ] ];

simpleArgString[ name_String, "String", _Missing, required_ ] :=
    StringRiffle @ { name, If[ required === False, "(optional)", Nothing ] };

simpleArgString[ name_String, "String", help_String, required_ ] :=
    StringRiffle @ { name, "-", help, If[ required === False, "(optional)", Nothing ] };

simpleArgString[ name_String, type_String, help_, required_ ] /; ToLowerCase @ name === ToLowerCase @ type :=
    simpleArgString[ name, "String", help, required ];

simpleArgString[ name_String, type_String, _Missing, required_ ] :=
    StringRiffle @ { name, If[ required === False, "(" <> type <> ", optional)", "("<>type<>")" ] };

simpleArgString[ name_String, type_String, help_String, required_ ] :=
    StringRiffle @ { name, "-", help, If[ required === False, "(" <> type <> ", optional)", "("<>type<>")" ] };

simpleArgString[ name_String, type: Except[ _String ], help_, required_ ] :=
    simpleArgString[ name, "String", help, required ];

simpleArgString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeToolPreferencePrompt*)
makeToolPreferencePrompt // beginDefinition;

makeToolPreferencePrompt[ settings_ ] :=
    makeToolPreferencePrompt[ settings, settings[ "ToolCallFrequency" ] ];

makeToolPreferencePrompt[ settings_, Automatic ] :=
    Missing[ "NotAvailable" ];

makeToolPreferencePrompt[ settings_, freq_? NumberQ ] :=
    With[ { key = Round @ Clip[ 5 * freq, { 0, 5 } ] },
        TemplateApply[
            $toolPreferencePrompt,
            <| "Number" -> Round[ freq * 100 ], "Explanation" -> Lookup[ $toolFrequencyExplanations, key, "" ] |>
        ]
    ];

makeToolPreferencePrompt // endDefinition;


$toolPreferencePrompt = "\
## User Tool Call Preferences

The user has specified their desired tool calling frequency to be `Number`% with the following instructions:

IMPORTANT
`Explanation`";


$toolFrequencyExplanations = <|
    0 -> "Only use a tool if explicitly instructed to use tools. Never use tools unless specifically asked to.",
    1 -> "Avoid using tools unless you think it is necessary.",
    2 -> "Only use tools if you think it will significantly improve the quality of your response.",
    3 -> "Use tools whenever it is appropriate to do so.",
    4 -> "Use tools whenever there's even a slight chance that it could improve the quality of your response (e.g. fact checking).",
    5 -> "ALWAYS make a tool call in EVERY response, no matter what."
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeToolPreferencePrompt*)
removeToolPreferencePrompt // beginDefinition;

removeToolPreferencePrompt[ {
    system: KeyValuePattern @ { "Role" -> "System", "Content" -> content_ },
    rest__
} ] := {
    <| system, "Content" -> ReplaceAll[ content, s_String :> RuleCondition @ StringDelete[ s, $$toolPreferences ] ] |>,
    rest
};

removeToolPreferencePrompt[ messages_ ] := messages;

removeToolPreferencePrompt // endDefinition;


$$toolPreferences = Apply[
    StringExpression,
    StringSplit[
        TemplateApply[ $toolPreferencePrompt, <| "Number" -> "*", "Explanation" -> "*" |> ],
        "*" -> Except[ "\n" ]..
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Properties*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getToolIcon*)
getToolIcon // beginDefinition;
getToolIcon[ tool: $$llmTool ] := getToolIcon @ toolData @ tool;
getToolIcon[ as_Association ] := Lookup[ toolData @ as, "Icon", Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "WrenchIcon" ] ];
getToolIcon[ _ ] := $defaultToolIcon;
getToolIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getToolDisplayName*)
getToolDisplayName // beginDefinition;

getToolDisplayName[ tool_ ] :=
    getToolDisplayName[ tool, Missing[ "NotFound" ] ];

getToolDisplayName[ tool: $$llmTool, default_ ] :=
    getToolDisplayName @ toolData @ tool;

getToolDisplayName[ as_Association, default_ ] :=
    Lookup[ as, "DisplayName", toDisplayToolName @ Lookup[ as, "Name", default ] ];

getToolDisplayName[ _, default_ ] :=
    default;

getToolDisplayName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getToolFormattingFunction*)
getToolFormattingFunction // beginDefinition;
getToolFormattingFunction[ HoldPattern @ LLMTool[ as_, ___ ] ] := getToolFormattingFunction @ as;
getToolFormattingFunction[ as_Association ] := Lookup[ as, "FormattingFunction", Automatic ];
getToolFormattingFunction[ _ ] := Automatic;
getToolFormattingFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $toolConfiguration;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
