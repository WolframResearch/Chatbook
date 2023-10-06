(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];

(* cSpell: ignore TOOLCALL, ENDARGUMENTS, ENDTOOLCALL, Deflatten, Liouville *)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

HoldComplete[
`$attachments;
`$defaultChatTools;
`$toolConfiguration;
`$toolEvaluationResults;
`$toolOptions;
`$toolResultStringLength;
`getToolByName;
`getToolDisplayName;
`getToolFormattingFunction;
`getToolIcon;
`initTools;
`makeExpressionURI;
`makeToolConfiguration;
`makeToolResponseString;
`resolveTools;
`toolData;
`toolName;
`toolOptionValue;
`toolRequestParser;
`withToolBox;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`Common`"            ];
Needs[ "Wolfram`Chatbook`Formatting`"        ];
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
$defaultWebTextLength   = 12000;
$toolResultStringLength = 500;
$webSessionVisible      = False;

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
    |>
|>;

$defaultToolIcon = RawBoxes @ TemplateBox[ { }, "WrenchIcon" ];

$attachments           = <| |>;
$selectedTools         = <| |>;
$toolBox               = <| |>;
$toolEvaluationResults = <| |>;
$toolOptions           = <| |>;

$cloudUnsupportedTools = { "WolframLanguageEvaluator", "DocumentationSearcher" };

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
(*Tool Options*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*SetToolOptions*)
SetToolOptions // ClearAll;

SetToolOptions[ name_String, opts: OptionsPattern[ ] ] :=
    SetToolOptions[ $FrontEnd, name, opts ];

SetToolOptions[ scope_, name_String, opts: OptionsPattern[ ] ] := UsingFrontEnd[
    KeyValueMap[
        (CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", "ToolOptions", name, ToString[ #1 ] } ] = #2) &,
        Association @ Reverse @ { opts }
    ];
    CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", "ToolOptions" } ]
];

SetToolOptions[ name_String, Inherited ] :=
    SetToolOptions[ $FrontEnd, name, Inherited ];

SetToolOptions[ scope_, name_String, Inherited ] := UsingFrontEnd[
    CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", "ToolOptions", name } ] = Inherited;
    CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", "ToolOptions" } ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolOptionValue*)
toolOptionValue // beginDefinition;
toolOptionValue[ name_String, key_String ] := toolOptionValue[ name, $toolOptions[ name ], key ];
toolOptionValue[ name_String, _Missing, key_String ] := toolOptionValue0[ $DefaultToolOptions[ name ], key ];
toolOptionValue[ name_String, opts_Association, key_String ] := toolOptionValue0[ opts, key ];
toolOptionValue // endDefinition;

toolOptionValue0 // beginDefinition;
toolOptionValue0[ opts_Association, key_String ] := Lookup[ opts, key, Lookup[ $DefaultToolOptions, key ] ];
toolOptionValue0 // endDefinition;

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
getLLMEvaluatorName[ KeyValuePattern[ "LLMEvaluator" -> evaluator_Association ] ] := getLLMEvaluatorName @ evaluator;
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
getToolSelections[ as_, selections_Association ] := selections;
getToolSelections[ as_, Except[ _Association ] ] := <| |>;
getToolSelections // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolSelectionTypes*)
getToolSelectionTypes // beginDefinition;
getToolSelectionTypes[ as_Association ] := getToolSelectionTypes[ as, Lookup[ as, "ToolSelectionType", <| |> ] ];
getToolSelectionTypes[ as_, selections_Association ] := selections;
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
        $toolConfiguration = LLMConfiguration @ <| "Tools" -> tools, "ToolPrompt" -> $toolPrompt |>
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
(*$toolPrompt*)
$toolPrompt := TemplateObject[
    {
        $toolPre,
        TemplateSequence[
            TemplateExpression @ StringTemplate[
                "Tool Name: `Name`\nDescription: `Description`\nSchema:\n`Schema`\n\n"
            ],
            TemplateExpression @ Map[
                Append[ #[ "Data" ], "Schema" -> ExportString[ #[ "JSONSchema" ], "JSON" ] ] &,
                TemplateSlot[ "Tools" ]
            ]
        ],
        $toolPost
    },
    CombinerFunction  -> StringJoin,
    InsertionFunction -> TextString
];


$toolPre = "\
# Tool Instructions

You have access to tools which can be used to do things, fetch data, compute, etc. while you create your response. \
Each tool takes input as JSON following a JSON schema. Here are the available tools and their associated schemas:

";


$toolPost := "

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

" <> $fullExamples;

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
        "TOOLCALL: `1`\n`2`\nENDARGUMENTS\nENDTOOLCALL",
        { toMachineToolName @ name, Developer`WriteRawJSONString @ params }
    ];

formatToolCallExample // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DocumentationSearch*)
$documentationSearchDescription = "\
Search Wolfram Language documentation for symbols and more. \
Follow up search results with the documentation lookup tool to get the full information.";

$defaultChatTools0[ "DocumentationSearcher" ] = <|
    toolDefaultData[ "DocumentationSearcher" ],
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "ToolIconDocumentationSearcher" ],
    "Description"        -> $documentationSearchDescription,
    "Function"           -> documentationSearch,
    "FormattingFunction" -> toolAutoFormatter,
    "Source"             -> "BuiltIn",
    "Parameters"         -> {
        "query" -> <|
            "Interpreter" -> "String",
            "Help"        -> "A string representing a documentation search query",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*documentationSearch*)
documentationSearch // beginDefinition;
documentationSearch[ KeyValuePattern[ "query" -> name_ ] ] := documentationSearch @ name;
documentationSearch[ names_List ] := StringRiffle[ documentationSearch /@ names, "\n\n" ];
documentationSearch[ name_String ] /; NameQ[ "System`" <> name ] := documentationLookup @ name;
documentationSearch[ query_String ] := documentationSearch[ query, documentationSearchAPI @ query ];
documentationSearch[ query_String, { } ] := ToString[ Missing[ "NoResults" ], InputForm ];
documentationSearch[ query_String, results_List ] := StringRiffle[ results, "\n" ];
documentationSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DocumentationLookup*)
$defaultChatTools0[ "DocumentationLookup" ] = <|
    toolDefaultData[ "DocumentationLookup" ],
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "ToolIconDocumentationLookup" ],
    "Description"        -> "Get documentation pages for Wolfram Language symbols.",
    "Function"           -> documentationLookup,
    "FormattingFunction" -> toolAutoFormatter,
    "Source"             -> "BuiltIn",
    "Parameters"         -> {
        "names" -> <|
            "Interpreter" -> DelimitedSequence[ "WolframLanguageSymbol", "," ],
            "Help"        -> "One or more Wolfram Language symbols separated by commas",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*documentationLookup*)
documentationLookup // beginDefinition;

documentationLookup[ KeyValuePattern[ "names" -> name_ ] ] := documentationLookup @ name;
documentationLookup[ name_Entity ] := documentationLookup @ CanonicalName @ name;
documentationLookup[ names_List ] := StringRiffle[ documentationLookup /@ names, "\n\n---\n\n" ];

documentationLookup[ name_String ] := Enclose[
    Module[ { usage, details, examples, strings, body },
        usage    = ConfirmMatch[ documentationUsage @ name, _String|_Missing, "Usage" ];
        details  = ConfirmMatch[ documentationDetails @ name, _String|_Missing, "Details" ];
        examples = ConfirmMatch[ documentationBasicExamples @ name, _String|_Missing, "Examples" ];
        strings  = ConfirmMatch[ DeleteMissing @ { usage, details, examples }, { ___String }, "Strings" ];
        body     = If[ strings === { }, ToString[ Missing[ "NotFound" ], InputForm ], StringRiffle[ strings, "\n\n" ] ];
        "# " <> name <> "\n\n" <> body
    ],
    throwInternalFailure[ documentationLookup @ name, ## ] &
];

documentationLookup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*documentationUsage*)
documentationUsage // beginDefinition;
documentationUsage[ name_String ] := documentationUsage[ name, wolframLanguageData[ name, "PlaintextUsage" ] ];
documentationUsage[ name_, missing_Missing ] := missing;
documentationUsage[ name_, usage_String ] := "## Usage\n\n" <> usage;
documentationUsage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*documentationDetails*)
documentationDetails // beginDefinition;
documentationDetails[ name_String ] := Missing[ ]; (* TODO *)
documentationDetails // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*documentationBasicExamples*)
documentationBasicExamples // beginDefinition;

documentationBasicExamples[ name_String ] :=
    documentationBasicExamples[ name, wolframLanguageData[ name, "DocumentationBasicExamples" ] ];

documentationBasicExamples[ name_, missing_Missing ] := missing;

documentationBasicExamples[ name_, examples_List ] := Enclose[
    Module[ { cells, strings },
        cells   = renumberCells @ Replace[ Flatten @ examples, RawBoxes[ cell_ ] :> cell, { 1 } ];
        strings = ConfirmMatch[ cellToString /@ cells, { ___String }, "CellToString" ];
        If[ strings === { },
            Missing[ ],
            StringDelete[ "## Basic Examples\n\n" <> StringRiffle[ strings, "\n\n" ], "```\n\n```" ]
        ]
    ],
    throwInternalFailure[ documentationBasicExamples[ name, examples ], ## ] &
];

documentationBasicExamples // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*cellToString*)
cellToString[ args___ ] := Block[ { $maxOutputCellStringLength = 100 }, CellToString @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*renumberCells*)
renumberCells // beginDefinition;
renumberCells[ cells_List ] := Block[ { $line = 0 }, renumberCell /@ Flatten @ cells ];
renumberCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*renumberCell*)
renumberCell // beginDefinition;

renumberCell[ Cell[ a__, "Input", b: (Rule|RuleDelayed)[ _, _ ]... ] ] :=
    Cell[ a, "Input", CellLabel -> "In[" <> ToString @ ++$line <> "]:=" ];

renumberCell[ Cell[ a__, "Output", b: (Rule|RuleDelayed)[ _, _ ]... ] ] :=
    Cell[ a, "Output", CellLabel -> "Out[" <> ToString @ $line <> "]=" ];

renumberCell[ Cell[ a__, style: "Print"|"Echo", b: (Rule|RuleDelayed)[ _, _ ]... ] ] :=
    Cell[ a, style, CellLabel -> "During evaluation of In[" <> ToString @ $line <> "]:=" ];

renumberCell[ cell_Cell ] := cell;

renumberCell // endDefinition;

$line = 0;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Evaluate*)
$sandboxEvaluateDescription = "\
Evaluate Wolfram Language code for the user in a separate kernel. \
The user does not automatically see the result. \
You must include the result in your response in order for them to see it. \
If a formatted result is provided as a markdown link, use that in your response instead of typing out the output.
The evaluator supports interactive content such as Manipulate.
You have read access to local files.
";

$defaultChatTools0[ "WolframLanguageEvaluator" ] = <|
    toolDefaultData[ "WolframLanguageEvaluator" ],
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "AssistantEvaluate" ],
    "Description"        -> $sandboxEvaluateDescription,
    "Function"           -> sandboxEvaluate,
    "FormattingFunction" -> sandboxFormatter,
    "Source"             -> "BuiltIn",
    "Parameters"         -> {
        "code" -> <|
            "Interpreter" -> "String",
            "Help"        -> "Wolfram Language code to evaluate",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*wolframLanguageEvaluator*)
wolframLanguageEvaluator // beginDefinition;
wolframLanguageEvaluator[ code_String ] := wolframLanguageEvaluator[ code, sandboxEvaluate @ code ];
wolframLanguageEvaluator[ code_, result_Association ] := KeyTake[ result, { "Result", "String" } ];
wolframLanguageEvaluator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Wolfram Alpha*)

(* $wolframAlphaDescription = "Get Wolfram|Alpha results

## Wolfram Alpha Tool Guidelines
- Understands natural language queries about entities in chemistry, physics, geography, history, art, astronomy, and more.
- Performs mathematical calculations, date and unit conversions, formula solving, etc.
- Convert inputs to simplified keyword queries whenever possible (e.g. convert \"how many people live in France\" to \"France population\").
- Use ONLY single-letter variable names, with or without integer subscript (e.g., n, n1, n_1).
- Use named physical constants (e.g., 'speed of light') without numerical substitution.
- Include a space between compound units (e.g., \"\[CapitalOmega] m\" for \"ohm*meter\").
- To solve for a variable in an equation with units, consider solving a corresponding equation without units; exclude counting units (e.g., books), include genuine units (e.g., kg).
- If data for multiple properties is needed, make separate calls for each property.
- If a Wolfram Alpha result is not relevant to the query:
 -- If Wolfram provides multiple 'Assumptions' for a query, choose the more relevant one(s) without explaining the initial result. If you are unsure, ask the user to choose.
 -- Re-send the exact same 'input' with NO modifications, and add the 'assumption' parameter, formatted as a list, with the relevant values.
 -- ONLY simplify or rephrase the initial query if a more relevant 'Assumption' or other input suggestions are not provided.
 -- Do not explain each step unless user input is needed. Proceed directly to making a better API call based on the available assumptions.
 "; *)

$wolframAlphaDescription = "\
Use natural language queries with Wolfram|Alpha to get up-to-date computational results about entities in chemistry, \
physics, geography, history, art, astronomy, and more.";

$wolframAlphaIcon = RawBoxes @ DynamicBox @ FEPrivate`FrontEndResource[ "FEBitmaps", "InsertionAlpha" ];

$defaultChatTools0[ "WolframAlpha" ] = <|
    toolDefaultData[ "WolframAlpha" ],
    "Icon"               -> $wolframAlphaIcon,
    "Description"        -> $wolframAlphaDescription,
    "Function"           -> getWolframAlphaText,
    "FormattingFunction" -> wolframAlphaResultFormatter,
    "Source"             -> "BuiltIn",
    "Parameters"         -> {
        "input" -> <|
            "Interpreter" -> "String",
            "Help"        -> "the input",
            "Required"    -> True
        |>(*,
        "assumption" -> <|
            "Interpreter" -> "String",
            "Help"        -> "the assumption to use, passed back from a previous query with the same input.",
            "Required"    -> False
        |>*)
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getWolframAlphaText*)
getWolframAlphaText // beginDefinition;

getWolframAlphaText[ KeyValuePattern[ "input" -> query_String ] ] :=
    getWolframAlphaText @ query;

getWolframAlphaText[ query_String ] :=
    Module[ { result, data, string },
        result = WolframAlpha @ query;
        data   = WolframAlpha[ query, { All, { "Title", "Plaintext", "ComputableData", "Content" } } ];
        string = getWolframAlphaText[ query, data ];
        getWolframAlphaText[ query ] = <| "Result" -> result, "String" -> string |>
    ];

getWolframAlphaText[ query_String, { } ] :=
    "No results returned";

getWolframAlphaText[ query_String, info_List ] :=
    getWolframAlphaText[ query, associationKeyDeflatten[ makeKeySequenceRule /@ info ] ];

getWolframAlphaText[ query_String, as_Association? AssociationQ ] :=
    getWolframAlphaText[ query, waResultText @ as ];

getWolframAlphaText[ query_String, result_String ] :=
    escapeMarkdownString @ result;

getWolframAlphaText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*wolframAlphaResultFormatter*)
wolframAlphaResultFormatter // beginDefinition;

wolframAlphaResultFormatter[ query_String, "Parameters", "input" ] :=
    clickToCopy @ query;

wolframAlphaResultFormatter[ KeyValuePattern[ "Result" -> result_ ], "Result" ] :=
    wolframAlphaResultFormatter[ result, "Result" ];

wolframAlphaResultFormatter[ result_, ___ ] :=
    result;

wolframAlphaResultFormatter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeKeySequenceRule*)
makeKeySequenceRule // beginDefinition;
makeKeySequenceRule[ { _, "Cell"|"Position"|"Scanner" } -> _ ] := Nothing;
makeKeySequenceRule[ key_ -> value_ ] := makeKeySequence @ key -> value;
makeKeySequenceRule // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeKeySequence*)
makeKeySequence // beginDefinition;

makeKeySequence[ { { path_String, n_Integer }, key_String } ] :=
    makeKeySequence @ Flatten @ { Reverse @ StringSplit[ path, ":" ], n, key };

makeKeySequence[ { path__String, 0, key_String } ] :=
    { path, key };

makeKeySequence[ { path__String, n_Integer, key_String } ] :=
    { path, "Data", n, key };

makeKeySequence // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*waResultText*)
waResultText // beginDefinition;
waResultText[ as_ ] := Block[ { $level = 1 }, StringRiffle[ Flatten @ Values[ waResultText0 /@ as ], "\n" ] ];
waResultText // endDefinition;


waResultText0 // beginDefinition;

waResultText0[ as: KeyValuePattern @ { "Title" -> title_String, "Data" -> data_ } ] :=
    StringRepeat[ "#", $level ] <> " " <> title <> "\n" <> waResultText0 @ data;

waResultText0[ as: KeyValuePattern[ _Integer -> _ ] ] :=
    waResultText0 /@ Values @ KeySort @ KeySelect[ as, IntegerQ ];

waResultText0[ KeyValuePattern @ { "Plaintext" -> text_String, "ComputableData" -> Hold[ expr_ ] } ] :=
    If[ ByteCount @ Unevaluated @ expr >= 500,
        If[ StringFreeQ[ text, "["|"]"|"\n" ],
            makeExpressionURI[ text, Unevaluated @ expr ] <> "\n",
            text <> "\n" <> makeExpressionURI[ Unevaluated @ expr ] <> "\n"
        ],
        text <> "\n"
    ];

waResultText0[ as: KeyValuePattern @ { "Plaintext" -> text_String, "ComputableData" -> expr: Except[ _Hold ] } ] :=
    waResultText0 @ Append[ as, "ComputableData" -> Hold @ expr ];

waResultText0[ KeyValuePattern @ { "Plaintext" -> text_String, "Content" -> content_ } ] :=
    If[ ByteCount @ content >= 500,
        If[ StringFreeQ[ text, "["|"]"|"\n" ],
            makeExpressionURI[ text, Unevaluated @ content ] <> "\n",
            text <> "\n" <> makeExpressionURI[ Unevaluated @ content ] <> "\n"
        ],
        text <> "\n"
    ];

waResultText0[ as_Association ] /; Length @ as === 1 :=
    waResultText0 @ First @ as;

waResultText0[ as_Association ] :=
    KeyValueMap[
        Function[
            StringJoin[
                StringRepeat[ "#", $level ],
                " ",
                ToString[ #1 ],
                "\n",
                Block[ { $level = $level + 1 }, waResultText0[ #2 ] ]
            ]
        ],
        as
    ];

waResultText0[ expr_ ] :=
    With[ { s = ToString[ Unevaluated @ expr, InputForm ] }, s <> "\n" /; StringLength @ s <= 100 ];

waResultText0[ expr_ ] :=
    makeExpressionURI @ Unevaluated @ expr <> "\n";

waResultText0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WebSearch*)
$defaultChatTools0[ "WebSearcher" ] = <|
    toolDefaultData[ "WebSearcher" ],
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "ToolIconWebSearcher" ],
    "Description"        -> "Search the web.",
    "Function"           -> webSearch,
    "FormattingFunction" -> toolAutoFormatter,
    "Source"             -> "BuiltIn",
    "Parameters"         -> {
        "query" -> <|
            "Interpreter" -> "String",
            "Help"        -> "Search query text",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*webSearch*)
webSearch // beginDefinition;

webSearch[ KeyValuePattern[ "query" -> query_ ] ] := webSearch @ query;
webSearch[ query_String ] := webSearch @ SearchQueryString @ query;

webSearch[ query_SearchQueryString ] := Enclose[
    Module[ { result, json, string },
        result = ConfirmMatch[ WebSearch[ query, MaxItems -> 5 ], _Dataset, "WebSearch" ];
        json   = ConfirmBy[ Developer`WriteRawJSONString[ Normal @ result /. URL[ url_ ] :> url ], StringQ, "JSON" ];
        json   = StringReplace[ json, "\\/" -> "/" ];
        string = ConfirmBy[ TemplateApply[ $webSearchResultTemplate, json ], StringQ, "TemplateApply" ];
        <| "Result" -> result, "String" -> string |>
    ]
];

webSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$webSearchResultTemplate*)
$webSearchResultTemplate := StringTemplate @ StringJoin[
    "Results\n-------\n\n`1`\n\n-------",
    If[ KeyExistsQ[ $selectedTools, "WebFetcher" ],
        "\n\nUse the web_fetcher tool to get the content of a URL.",
        ""
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WebFetch*)
$defaultChatTools0[ "WebFetcher" ] = <|
    toolDefaultData[ "WebFetcher" ],
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "ToolIconWebFetcher" ],
    "Description"        -> "Fetch plain text or image links from a URL.",
    "Function"           -> webFetch,
    "FormattingFunction" -> toolAutoFormatter,
    "Source"             -> "BuiltIn",
    "Parameters"  -> {
        "url" -> <|
            "Interpreter" -> "URL",
            "Help"        -> "The URL",
            "Required"    -> True
        |>,
        "format" -> <|
            "Interpreter" -> { "Plaintext", "ImageLinks" },
            "Help"        -> "The type of content to retrieve (\"Plaintext\" or \"ImageLinks\")",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*webFetch*)
webFetch // beginDefinition;
webFetch[ KeyValuePattern @ { "url" -> url_, "format" -> fmt_ } ] := webFetch[ url, fmt ];
webFetch[ url_, "Plaintext" ] := fetchWebText @ url;
webFetch[ url: _URL|_String, fmt_String ] := webFetch[ url, fmt, Import[ url, { "HTML", fmt } ] ];
webFetch[ url_, "ImageLinks", { } ] := <| "Result" -> { }, "String" -> "No links found at " <> TextString @ url |>;
webFetch[ url_, "ImageLinks", links: { __String } ] := <| "Result" -> links, "String" -> StringRiffle[ links, "\n" ] |>;
webFetch[ url_, fmt_, result_String ] := shortenWebText @ niceWebText @ result;
webFetch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fetchWebText*)
fetchWebText // beginDefinition;

fetchWebText[ URL[ url_ ] ] :=
    fetchWebText @ url;

fetchWebText[ url_String ] :=
    fetchWebText[ url, $webSession ];

fetchWebText[ url_String, session_WebSessionObject ] := Enclose[
    Module[ { body, strings },
        ConfirmMatch[ WebExecute[ session, { "OpenPage" -> url } ], _Success | { __Success } ];
        Pause[ 3 ]; (* Allow time for the page to load *)
        body = ConfirmMatch[ WebExecute[ session, "LocateElements" -> "Tag" -> "body" ], { __WebElementObject } ];
        strings = ConfirmMatch[ WebExecute[ "ElementText" -> body ], { __String } ];
        shortenWebText @ niceWebText @ strings
    ],
    shortenWebText @ niceWebText @ Import[ url, { "HTML", "Plaintext" } ] &
];

fetchWebText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*shortenWebText*)
shortenWebText // beginDefinition;
shortenWebText[ text_String ] := shortenWebText[ text, toolOptionValue[ "WebFetcher", "MaxContentLength" ] ];
shortenWebText[ text_String, len_Integer? Positive ] := StringTake[ text, UpTo[ len ] ];
shortenWebText[ text_String, Infinity|All ] := text;
shortenWebText[ text_String, _ ] := shortenWebText[ text, $defaultWebTextLength ];
shortenWebText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*niceWebText*)
niceWebText // beginDefinition;
niceWebText[ str_String ] := StringReplace[ StringDelete[ str, "\r" ], Longest[ "\n"~~Whitespace~~"\n" ] :> "\n\n" ];
niceWebText[ strings_List ] := StringRiffle[ StringTrim[ niceWebText /@ strings ], "\n\n" ];
niceWebText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$webSession*)
$webSession := getWebSession[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getWebSession*)
getWebSession // beginDefinition;
getWebSession[ ] := getWebSession @ $currentWebSession;
getWebSession[ session_WebSessionObject? validWebSessionQ ] := session;
getWebSession[ session_WebSessionObject ] := (Quiet @ DeleteObject @ session; startWebSession[ ]);
getWebSession[ _ ] := startWebSession[ ];
getWebSession // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*validWebSessionQ*)
validWebSessionQ // ClearAll;

validWebSessionQ[ session_WebSessionObject ] :=
    With[ { valid = Quiet @ StringQ @ WebExecute[ session, "PageURL" ] },
        If[ valid, True, Quiet @ DeleteObject @ session; False ]
    ];

validWebSessionQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*startWebSession*)
startWebSession // beginDefinition;
startWebSession[ ] := $currentWebSession = StartWebSession[ Visible -> $webSessionVisible ];
startWebSession // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WebImageSearch*)
$defaultChatTools0[ "WebImageSearcher" ] = <|
    toolDefaultData[ "WebImageSearcher" ],
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "ToolIconWebImageSearcher" ],
    "Description"        -> "Search the web for images.",
    "Function"           -> webImageSearch,
    "FormattingFunction" -> toolAutoFormatter,
    "Source"             -> "BuiltIn",
    "Parameters"         -> {
        "query" -> <|
            "Interpreter" -> "String",
            "Help"        -> "Search query text",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*webImageSearch*)
webImageSearch // beginDefinition;

webImageSearch[ KeyValuePattern[ "query" -> query_ ] ] := webImageSearch @ query;
webImageSearch[ query_String ] := webImageSearch @ SearchQueryString @ query;
webImageSearch[ query_SearchQueryString ] := webImageSearch[ query, WebImageSearch[ query, "ImageHyperlinks" ] ];

webImageSearch[ query_, { } ] := <|
    "Result" -> { },
    "String" -> "No results found"
|>;

webImageSearch[ query_, urls: { __ } ] := <|
    "Result" -> Column[ Hyperlink /@ urls, BaseStyle -> "Text" ],
    "String" -> StringRiffle[ TextString /@ urls, "\n" ]
|>;

webImageSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Full Examples*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$fullExamples*)
$fullExamples :=
    With[ { keys = $fullExamplesKeys },
        If[ keys === { },
            "",
            StringJoin[
                "## Full examples\n\n---\n\n",
                StringRiffle[ Values @ KeyTake[ $fullExamples0, $fullExamplesKeys ], "\n\n---\n\n" ],
                "\n\n---\n"
            ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$fullExamplesKeys*)
$fullExamplesKeys :=
    With[ { selected = Keys @ $selectedTools },
        Select[
            If[ TrueQ @ $CloudEvaluation,
                { "AstroGraphicsDocumentation" },
                {
                    "AstroGraphicsDocumentation",
                    "FileSystemTree",
                    "FractionalDerivatives",
                    "PlotEvaluate",
                    "TemporaryDirectory"
                }
            ],
            ContainsAll[ selected, $exampleDependencies[ #1 ] ] &
        ]
    ];

$exampleDependencies = <|
    "AstroGraphicsDocumentation" -> { "DocumentationLookup" },
    "FileSystemTree"             -> { "DocumentationSearcher", "DocumentationLookup" },
    "FractionalDerivatives"      -> { "DocumentationSearcher", "DocumentationLookup", "WolframLanguageEvaluator" },
    "PlotEvaluate"               -> { "WolframLanguageEvaluator" },
    "TemporaryDirectory"         -> { "DocumentationSearcher", "WolframLanguageEvaluator" }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$fullExamples0*)
$fullExamples0 = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*AstroGraphicsDocumentation*)
$fullExamples0[ "AstroGraphicsDocumentation" ] = TemplateApply[ "\
[user]
How do I use AstroGraphics?

[assistant]
Let me check the documentation for you. One moment...
`1`

[system]
Usage
AstroGraphics[primitives, options] represents a two-dimensional view of space and the celestial sphere.

Basic Examples
...

[assistant]
To use [AstroGraphics](paclet:ref/AstroGraphics), you need to provide a list of graphics primitives and options. \
For example, ...",
{
    formatToolCallExample[ "DocumentationLookup", <| "names" -> "AstroGraphics" |> ]
} ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*FileSystemTree*)
$fullExamples0[ "FileSystemTree" ] = "\
[user]
What's the best way to generate a tree of files in a given directory?

[assistant]
"<>formatToolCallExample[ "DocumentationSearcher", <| "query" -> "tree of files" |> ]<>"

[system]
* FileSystemTree - (score: 9.9) FileSystemTree[root] gives a tree whose keys are ...
* Tree Drawing - (score: 3.0) ...

[assistant]
"<>formatToolCallExample[ "DocumentationLookup", <| "names" -> "FileSystemTree" |> ]<>"

...";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*FractionalDerivatives*)
$fullExamples0[ "FractionalDerivatives" ] = "\
[user]
Calculate the half-order fractional derivative of x^n with respect to x.

[assistant]
"<>formatToolCallExample[ "DocumentationSearcher", <| "query" -> "fractional derivatives" |> ]<>"

[system]
* FractionalD - (score: 9.5) FractionalD[f, {x, a}] gives ...
* NFractionalD - (score: 9.2) ...

[assistant]
"<>formatToolCallExample[ "DocumentationLookup", <| "names" -> "FractionalD" |> ]<>"

[system]
Usage
FractionalD[f, {x, a}] gives the Riemann-Liouville fractional derivative D_x^a f(x) of order a of the function f.

Basic Examples
<example text>

[assistant]
"<>formatToolCallExample[ "WolframLanguageEvaluator", <| "code" -> "FractionalD[x^n, {x, 1/2}]" |> ]<>"

[system]
Out[n]= Piecewise[...]

![Formatted Result](expression://result-{id})

[assistant]
The half-order fractional derivative of $x^n$ with respect to $x$ is given by:
![Fractional Derivative](expression://result-{id})
";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*PlotEvaluate*)
$fullExamples0[ "PlotEvaluate" ] = StringJoin[ "\
[user]
Plot sin(x) from -5 to 5

[assistant]
", formatToolCallExample[
    "WolframLanguageEvaluator",
    <| "code" -> "Plot[Sin[x], {x, -10, 10}, AxesLabel -> {\"x\", \"sin(x)\"}]" |>
], "

[system]
Out[n]= ![image](attachment://result-{id})

[assistant]
Here's the plot of $\\sin{x}$ from -5 to 5:
![Plot](attachment://result-{id})"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*TemporaryDirectory*)
$fullExamples0[ "TemporaryDirectory" ] = "\
[user]
Where is the temporary directory located?

[assistant]
"<>formatToolCallExample[ "DocumentationSearcher", <| "query" -> "location of temporary directory" |> ]<>"

[system]
* $TemporaryDirectory - (score: 9.6) $TemporaryDirectory gives the main system directory for temporary files.
* CreateDirectory - (score: 8.5) CreateDirectory[\"dir\"] creates ...

[assistant]
"<>formatToolCallExample[ "WolframLanguageEvaluator", <| "code" -> "$TemporaryDirectory" |> ]<>"

[system]
Out[n]= \"C:\\Users\\UserName\\AppData\\Local\\Temp\"

[assistant]
The temporary directory is located at C:\\Users\\UserName\\AppData\\Local\\Temp.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Expression URIs*)
$$expressionScheme = "attachment"|"expression";

Chatbook::URIUnavailable = "The expression URI `1` is no longer available.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FormatToolResponse*)
FormatToolResponse // ClearAll;
FormatToolResponse[ response_ ] := makeToolResponseString @ response;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MakeExpressionURI*)
MakeExpressionURI // ClearAll;
MakeExpressionURI[ args: Repeated[ _, { 1, 3 } ] ] := makeExpressionURI @ args;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*GetExpressionURIs*)
GetExpressionURIs // ClearAll;

GetExpressionURIs[ str_ ] := GetExpressionURIs[ str, ## & ];

GetExpressionURIs[ str_String, wrapper_ ] := catchMine @ StringSplit[
    str,
    link: Shortest[ "![" ~~ __ ~~ "](" ~~ __ ~~ ")" ] :> catchAlways @ GetExpressionURI[ link, wrapper ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*GetExpressionURI*)
GetExpressionURI // ClearAll;

GetExpressionURI[ uri_ ] := catchMine @ GetExpressionURI[ uri, ## & ];
GetExpressionURI[ URL[ uri_ ], wrapper_ ] := catchMine @ GetExpressionURI[ uri, wrapper ];

GetExpressionURI[ uri_String, wrapper_ ] := catchMine @ Enclose[
    Module[ { held },
        held = ConfirmMatch[ getExpressionURI @ uri, _HoldComplete, "GetExpressionURI" ];
        wrapper @@ held
    ],
    throwInternalFailure[ GetExpressionURI[ uri, wrapper ], ## ] &
];

GetExpressionURI[ All, wrapper_ ] := catchMine @ Enclose[
    Module[ { attachments },
        attachments = ConfirmBy[ $attachments, AssociationQ, "Attachments" ];
        ConfirmAssert[ AllTrue[ attachments, MatchQ[ _HoldComplete ] ], "HeldAttachments" ];
        Replace[ attachments, HoldComplete[ a___ ] :> RuleCondition @ wrapper @ a, { 1 } ]
    ],
    throwInternalFailure[ GetExpressionURI[ All, wrapper ], ## ] &
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getExpressionURI*)
getExpressionURI // beginDefinition;

getExpressionURI[ str_String ] :=
    Module[ { split },
        split = First[ StringSplit[ str, "![" ~~ alt__ ~~ "](" ~~ url__ ~~ ")" :> { alt, url } ], $Failed ];
        getExpressionURI @@ split /; MatchQ[ split, { _String, _String } ]
    ];

getExpressionURI[ uri_String ] := getExpressionURI[ None, uri ];

getExpressionURI[ tooltip_, uri_String ] := getExpressionURI[ tooltip, uri, URLParse @ uri ];

getExpressionURI[ tooltip_, uri_, as: KeyValuePattern @ { "Scheme" -> $$expressionScheme, "Domain" -> key_ } ] :=
    Enclose[
        ConfirmMatch[ displayAttachment[ uri, tooltip, key ], _HoldComplete, "DisplayAttachment" ],
        throwInternalFailure[ getExpressionURI[ tooltip, uri, as ], ## ] &
    ];

getExpressionURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*displayAttachment*)
displayAttachment // beginDefinition;

displayAttachment[ uri_, None, key_ ] :=
    getAttachment[ uri, key ];

displayAttachment[ uri_, tooltip_String, key_ ] := Enclose[
    Replace[
        ConfirmMatch[ getAttachment[ uri, key ], _HoldComplete, "GetAttachment" ],
        HoldComplete[ expr_ ] :> HoldComplete @ Tooltip[ expr, tooltip ]
    ],
    throwInternalFailure[ displayAttachment[ uri, tooltip, key ], ## ] &
];

displayAttachment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getAttachment*)
getAttachment // beginDefinition;

getAttachment[ uri_String, key_String ] :=
    Lookup[ $attachments, key, throwFailure[ "URIUnavailable", uri ] ];

getAttachment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolResponseString*)
makeToolResponseString // beginDefinition;

makeToolResponseString[ expr_? simpleResultQ ] :=
    With[ { string = fixLineEndings @ TextString @ expr },
        If[ StringLength @ string < $toolResultStringLength,
            If[ StringContainsQ[ string, "\n" ], "\n" <> string, string ],
            StringJoin[
                "\n",
                fixLineEndings @ ToString[
                    Unevaluated @ Short[ expr, 5 ],
                    OutputForm,
                    PageWidth -> 100
                ],
                "\n\n\n",
                makeExpressionURI[ "expression", "Formatted Result", Unevaluated @ expr ]
            ]
        ]
    ];

makeToolResponseString[ expr_ ] := makeExpressionURI @ expr;

makeToolResponseString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeExpressionURI*)
makeExpressionURI // beginDefinition;

makeExpressionURI[ expr_ ] :=
    makeExpressionURI[ Automatic, Unevaluated @ expr ];

makeExpressionURI[ label_, expr_ ] :=
    makeExpressionURI[ Automatic, label, Unevaluated @ expr ];

makeExpressionURI[ Automatic, label_, expr_ ] :=
    makeExpressionURI[ expressionURIScheme @ expr, label, Unevaluated @ expr ];

makeExpressionURI[ scheme_, Automatic, expr_ ] :=
    makeExpressionURI[ scheme, expressionURILabel @ expr, Unevaluated @ expr ];

makeExpressionURI[ scheme_, label_, expr_ ] :=
    With[ { id = "result-" <> Hash[ Unevaluated @ expr, Automatic, "HexString" ] },
        $attachments[ id ] = HoldComplete @ expr;
        "![" <> TextString @ label <> "](" <> TextString @ scheme <> "://" <> id <> ")"
    ];

makeExpressionURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*expressionURILabel*)
expressionURILabel // beginDefinition;
expressionURILabel // Attributes = { HoldAllComplete };
expressionURILabel[ _Graphics|_Graphics3D|_Image|_Image3D|_Legended|_RawBoxes ] := "image";
expressionURILabel[ _List|_Association ] := "data";
expressionURILabel[ _ ] := "result";
expressionURILabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*expressionURIScheme*)
expressionURIScheme // beginDefinition;
expressionURIScheme // Attributes = { HoldAllComplete };
expressionURIScheme[ _Graphics|_Graphics3D|_Image|_Image3D|_Legended|_RawBoxes ] := "attachment";
expressionURIScheme[ _ ] := "expression";
expressionURIScheme // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Documentation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*wolframLanguageData*)
wolframLanguageData // beginDefinition;

wolframLanguageData[ name_, property_ ] := Enclose[
    wolframLanguageData[ name, property ] = ConfirmBy[ WolframLanguageData[ name, property ], Not@*FailureQ ],
    Missing[ "DataFailure" ] &
];

wolframLanguageData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Properties*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolIcon*)
getToolIcon // beginDefinition;
getToolIcon[ HoldPattern @ LLMTool[ as_, ___ ] ] := getToolIcon @ toolData @ as;
getToolIcon[ as_Association ] := Lookup[ toolData @ as, "Icon", RawBoxes @ TemplateBox[ { }, "WrenchIcon" ] ];
getToolIcon[ _ ] := $defaultToolIcon;
getToolIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolDisplayName*)
getToolDisplayName // beginDefinition;

getToolDisplayName[ tool_ ] :=
    getToolDisplayName[ tool, Missing[ "NotFound" ] ];

getToolDisplayName[ HoldPattern @ LLMTool[ as_, ___ ], default_ ] :=
    getToolDisplayName @ as;

getToolDisplayName[ as_Association, default_ ] :=
    toDisplayToolName @ Lookup[ as, "DisplayName", Lookup[ as, "Name", default ] ];

getToolDisplayName[ _, default_ ] :=
    default;

getToolDisplayName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getToolFormattingFunction*)
getToolFormattingFunction // beginDefinition;
getToolFormattingFunction[ HoldPattern @ LLMTool[ as_, ___ ] ] := getToolFormattingFunction @ as;
getToolFormattingFunction[ as_Association ] := Lookup[ as, "FormattingFunction", Automatic ];
getToolFormattingFunction[ _ ] := Automatic;
getToolFormattingFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)

(* Sort tools to their default ordering: *)
$defaultChatTools0 = Block[ { LLMTool },
    LLMTool[ #, { } ] & /@ Association[ KeyTake[ $defaultChatTools0, $defaultToolOrder ], $defaultChatTools0 ]
];

If[ Wolfram`ChatbookInternal`$BuildingMX,
    $toolConfiguration;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
