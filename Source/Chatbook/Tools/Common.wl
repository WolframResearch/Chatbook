(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];

(* :!CodeAnalysis::BeginBlock:: *)

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`ChatMessages`"      ];
Needs[ "Wolfram`Chatbook`Common`"            ];
Needs[ "Wolfram`Chatbook`Formatting`"        ];
Needs[ "Wolfram`Chatbook`Models`"            ];
Needs[ "Wolfram`Chatbook`Personas`"          ];
Needs[ "Wolfram`Chatbook`Prompting`"         ];
Needs[ "Wolfram`Chatbook`ResourceInstaller`" ];
Needs[ "Wolfram`Chatbook`Sandbox`"           ];
Needs[ "Wolfram`Chatbook`Serialization`"     ];
Needs[ "Wolfram`Chatbook`Utils`"             ];

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
(*Tool Lists*)
$DefaultTools   := $defaultChatTools;
$InstalledTools := $installedTools;
$AvailableTools := Association[ $DefaultTools, $InstalledTools ];

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
    "WolframLanguageEvaluator" -> <|
        "AllowedExecutePaths"      -> Automatic,
        "AllowedReadPaths"         -> All,
        "AllowedWritePaths"        -> Automatic,
        "EvaluationTimeConstraint" -> 60,
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

$defaultToolIcon = RawBoxes @ TemplateBox[ { }, "WrenchIcon" ];

$attachments           = <| |>;
$selectedTools         = <| |>;
$toolBox               = <| |>;
$toolEvaluationResults = <| |>;
$toolOptions           = <| |>;

$cloudUnsupportedTools = { "DocumentationSearcher" };

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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Default Tools*)
$defaultChatTools := If[ TrueQ @ $CloudEvaluation,
                         KeyDrop[ $defaultChatTools0, $cloudUnsupportedTools ],
                         $defaultChatTools0
                     ];

$defaultChatTools0 = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Installed Tools*)
$installedTools := Association @ Cases[
    GetInstalledResourceData[ "LLMTool" ],
    as: KeyValuePattern[ "Tool" -> tool_ ] :> (toolName @ tool -> addExtraToolData[ tool, as ])
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
getToolByName[ name_String ] := Lookup[ $toolBox, toCanonicalToolName @ name ];
getToolByName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolName*)
toolName // beginDefinition;
toolName[ tool_ ] := toolName[ tool, Automatic ];
toolName[ HoldPattern @ LLMTool[ as_Association, ___ ], type_ ] := toolName[ as, type ];
toolName[ KeyValuePattern[ "CanonicalName" -> name_String ], "Canonical" ] := name;
toolName[ KeyValuePattern[ "DisplayName" -> name_String ], "Display" ] := name;
toolName[ KeyValuePattern[ "Name" -> name_String ], type_ ] := toolName[ name, type ];
toolName[ tool_, Automatic ] := toolName[ tool, "Canonical" ];
toolName[ name_String, "Machine" ] := toMachineToolName @ name;
toolName[ name_String, "Canonical" ] := toCanonicalToolName @ name;
toolName[ name_String, "Display" ] := toDisplayToolName @ name;
toolName[ tools_List, type_ ] := toolName[ #, type ] & /@ tools;
toolName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolData*)
toolData // beginDefinition;

toolData[ HoldPattern @ LLMTool[ as_Association, ___ ] ] :=
    toolData @ as;

toolData[ name_String ] /; KeyExistsQ[ $toolBox, name ] :=
    toolData @ $toolBox[ name ];

toolData[ name_String ] /; KeyExistsQ[ $defaultChatTools, name ] :=
    toolData @ $defaultChatTools[ name ];

toolData[ as: KeyValuePattern @ { "Function"|"ToolCall" -> _ } ] := <|
    toolDefaultData @ toolName @ as,
    "Icon" -> toolDefaultIcon @ as,
    as
|>;

toolData[ tools_List ] :=
    toolData /@ tools;

toolData // endDefinition;

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

toolDefaultData[ name_String ] := <|
    "CanonicalName" -> toCanonicalToolName @ name,
    "DisplayName"   -> toDisplayToolName @ name,
    "Name"          -> toMachineToolName @ name,
    "Icon"          -> $defaultToolIcon
|>;

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
    TemplateApply[
        (* cSpell: ignore TOOLCALL, ENDARGUMENTS, ENDTOOLCALL *)
        "TOOLCALL: `1`\n`2`\nENDARGUMENTS\nENDTOOLCALL",
        { toMachineToolName @ name, Developer`WriteRawJSONString @ params }
    ];

formatToolCallExample // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Toolbox*)

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
    Module[ { llmEvaluatorName, toolNames, selections, selectionTypes, add, remove, selectedNames },

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

        selectTools0 /@ selectedNames
    ],
    throwInternalFailure[ selectTools @ as, ## ] &
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
getToolNames[ tools_, Automatic|Inherited ] := getToolNames @ tools;

(* Persona declares an explicit list of tools *)
getToolNames[ Automatic|None|Inherited, personaTools_List ] := getToolNames @ personaTools;

(* The user has specified an explicit list of tools as well, so include them *)
getToolNames[ tools_List, personaTools_List ] := Union[ getToolNames @ tools, getToolNames @ personaTools ];

(* Get name of each tool *)
getToolNames[ tools_List ] := DeleteDuplicates @ Flatten[ getCachedToolName /@ tools ];

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
    throwInternalFailure[ getCachedToolName @ tool, ## ] &
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
toolRequestParser := toolRequestParser =
    Quiet[ Check[ $toolConfiguration[ "ToolRequestParser" ],
                  Wolfram`LLMFunctions`LLMConfiguration`$DefaultTextualToolMethod[ "ToolRequestParser" ],
                  LLMConfiguration::invprop
           ],
           LLMConfiguration::invprop
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolPrompt*)
makeToolPrompt // beginDefinition;

makeToolPrompt[ settings_Association ] := $lastToolPrompt = TemplateObject[
    Riffle[
        DeleteMissing @ {
            $toolPre,
            TemplateSequence[
                TemplateExpression @ TemplateObject[
                    {
                        "Tool Name: ",
                        TemplateSlot[ "Name" ],
                        "\nDisplay Name: ",
                        TemplateSlot[
                            "DisplayName",
                            DefaultValue :> TemplateExpression @ toDisplayToolName @ TemplateSlot[ "Name" ]
                        ],
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
                    Append[ #[ "Data" ], "Schema" -> ExportString[ #[ "JSONSchema" ], "JSON" ] ] &,
                    TemplateSlot[ "Tools" ]
                ]
            ],
            $toolPost,
            $fullExamples,
            makeToolPreferencePrompt @ settings
        },
        "\n\n"
    ],
    CombinerFunction  -> StringJoin,
    InsertionFunction -> TextString
];

makeToolPrompt // endDefinition;


$toolPre = "\
# Tool Instructions

You have access to tools which can be used to do things, fetch data, compute, etc. while you create your response. \
Each tool takes input as JSON following a JSON schema. Here are the available tools and their associated schemas:";


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

You must write the TOOLCALL in your CURRENT response. \
Do not state that you will use a tool and end your message before making the tool call.

If a user asks you to use a specific tool, you MUST attempt to use that tool as requested, \
even if you think it will not work. \
If the tool fails, use any error message to correct the issue or explain why it failed. \
NEVER state that a tool cannot be used for a particular task without trying it first. \
You did not create these tools, so you do not know what they can and cannot do.

You should try to avoid mentioning tools by name in your response and instead speak generally about their function. \
For example, if there were a number_adder tool, you would instead talk about \"adding numbers\". If you must mention \
a tool by name, you should use the DisplayName property instead of the tool name.";

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
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
