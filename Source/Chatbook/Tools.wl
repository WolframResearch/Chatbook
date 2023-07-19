(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];

(* cSpell: ignore TOOLCALL, ENDARGUMENTS, ENDTOOLCALL, Deflatten, Liouville *)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

Wolfram`Chatbook`$DefaultTools;
Wolfram`Chatbook`$ToolFunctions;
Wolfram`Chatbook`FormatToolResponse;
Wolfram`Chatbook`GetExpressionURI;
Wolfram`Chatbook`GetExpressionURIs;
Wolfram`Chatbook`MakeExpressionURI;

`$attachments;
`$defaultChatTools;
`$toolConfiguration;
`getToolByName;
`initTools;
`makeExpressionURI;
`makeToolConfiguration;
`makeToolResponseString;
`resolveTools;
`withToolBox;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"               ];
Needs[ "Wolfram`Chatbook`Common`"        ];
Needs[ "Wolfram`Chatbook`Serialization`" ];
Needs[ "Wolfram`Chatbook`Utils`"         ];
Needs[ "Wolfram`Chatbook`Sandbox`"       ];
Needs[ "Wolfram`Chatbook`Prompting`"     ];

PacletInstall[ "Wolfram/LLMFunctions" ];
Needs[ "Wolfram`LLMFunctions`" ];

System`LLMTool;
System`LLMConfiguration;

(* TODO:
    ImageSynthesize
    LongTermMemory
    Definitions
    TestWriter
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Exported Functions for Tool Repository*)
$DefaultTools := $defaultChatTools;

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

$toolBox       = <| |>;
$selectedTools = <| |>;
$attachments   = <| |>;

$cloudUnsupportedTools = { "WolframLanguageEvaluator", "DocumentationSearcher" };

$defaultToolOrder = {
    "DocumentationLookup",
    "DocumentationSearcher",
    "WolframAlpha",
    "WolframLanguageEvaluator"
};

$webSessionVisible = False;

$toolNameAliases = <|
    "DocumentationSearch" -> "DocumentationSearcher",
    "WebFetch"            -> "WebFetcher",
    "WebImageSearch"      -> "WebImageSearcher",
    "WebSearch"           -> "WebSearcher"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Toolbox*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withToolBox*)
withToolBox // beginDefinition;
withToolBox // Attributes = { HoldFirst };
withToolBox[ eval_ ] := Block[ { $selectedTools = <| |> }, eval ];
withToolBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*selectTools*)
selectTools // beginDefinition;

selectTools[ as: KeyValuePattern[ "LLMEvaluator" -> KeyValuePattern[ "Tools" -> tools_ ] ] ] := (
    selectTools @ KeyDrop[ as, "LLMEvaluator" ];
    selectTools @ tools;
);

selectTools[ KeyValuePattern[ "Tools" -> tools_ ] ] :=
    selectTools @ tools;

selectTools[ Automatic|Inherited ] :=
    selectTools @ $defaultChatTools;

selectTools[ None ] :=
    $selectedTools = <| |>;

selectTools[ tools_Association ] :=
    KeyValueMap[ selectTools, tools ];

selectTools[ tools_List ] :=
    selectTools /@ tools;

selectTools[ name_String ] /; KeyExistsQ[ $toolBox, name ] :=
    $selectedTools[ name ] = $toolBox[ name ];

selectTools[ name_String ] /; KeyExistsQ[ $toolNameAliases, name ] :=
    selectTools @ $toolNameAliases @ name;

selectTools[ name_String ] :=
    selectTools[ name, Lookup[ $defaultChatTools, name ] ]; (* TODO: fetch from repository *)

selectTools[ tool: HoldPattern @ LLMTool[ KeyValuePattern[ "Name" -> name_ ], ___ ] ] :=
    selectTools[ name, tool ];

selectTools[ (Rule|RuleDelayed)[ name_String, tool_ ] ] :=
    selectTools[ name, tool ];

selectTools[ name_String, Automatic|Inherited ] :=
    selectTools[ name, Lookup[ $defaultChatTools, name ] ];

selectTools[ name_String, None ] :=
    KeyDropFrom[ $selectedTools, name ];

selectTools[ name_String, tool_LLMTool ] :=
    $selectedTools[ name ] = $toolBox[ name ] = tool;

selectTools[ name_String, Missing[ "KeyAbsent", name_ ] ] :=
    If[ TrueQ @ KeyExistsQ[ $defaultChatTools0, name ],
        Null,
        messagePrint[ "ToolNotFound", name ]
    ];

selectTools // endDefinition;

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

    PacletInstall[ "Wolfram/LLMFunctions" ];
    Needs[ "Wolfram`LLMFunctions`" -> None ];
);

initTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolveTools*)
resolveTools // beginDefinition;

resolveTools[ settings: KeyValuePattern[ "ToolsEnabled" -> True ] ] := (
    initTools[ ];
    selectTools @ settings;
    $lastSelectedTools = $selectedTools;
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
(*$toolPrompt*)
$toolPrompt := TemplateObject[
    {
        $toolPre,
        TemplateSequence[
            StringTemplate[
                "Name: `Name`\nDescription: `Description`\nArguments: `Parameters`\n\n",
                InsertionFunction -> toolTemplateDataString
            ],
            TemplateExpression[ #[ "Data" ] & /@ TemplateSlot[ "Tools" ] ]
        ],
        $toolPost
    },
    CombinerFunction  -> StringJoin,
    InsertionFunction -> TextString
];


$toolPre = "\
# Tool Instructions

You have access to system tools which can be used to do things, fetch data, compute, etc. while you create your response. Here are the available tools:

";


$toolPost := "

To call a tool, write the following on a new line at any time during your response:

```
TOOLCALL: <tool name>
{
	\"<parameter name 1>\": <value 1>
	\"<parameter name 2>\": <value 2>
}
ENDARGUMENTS
ENDTOOLCALL
```

The system will execute the requested tool call and you will receive a system message containing the result.

You can then use this result to finish writing your response for the user.

You must write the TOOLCALL in your CURRENT response. \
Do not state that you will use a tool and end your message before making the tool call.

If a user asks you to use a specific tool, you MUST attempt to use that tool as requested, \
even if you think it will not work. \
If the tool fails, use any error message to correct the issue or explain why it failed. \
NEVER state that a tool cannot be used for a particular task without trying it first. \
You did not create these tools, so you do not know what they can and cannot do.

" <> $fullExamples;


toolTemplateDataString[ str_String ] := str;
toolTemplateDataString[ expr_ ] := ToString[ expr, InputForm ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Default Tools*)
$defaultChatTools := If[ TrueQ @ $CloudEvaluation,
                         KeyDrop[ $defaultChatTools0, $cloudUnsupportedTools ],
                         $defaultChatTools0
                     ];

$defaultChatTools0 = <| |>;

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
toolName[ HoldPattern @ LLMTool[ KeyValuePattern[ "Name" -> name_String ], ___ ], type_ ] := toolName[ name, type ];
toolName[ name_, Automatic ] := toolName[ name, "Canonical" ];
toolName[ name_String, "Machine" ] := toMachineToolName @ name;
toolName[ name_String, "Canonical" ] := toCanonicalToolName @ name;
toolName[ name_String, "Display" ] := toDisplayToolName @ name;
toolName // endDefinition;

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

$defaultChatTools0[ "DocumentationSearcher" ] = LLMTool[
    <|
        "Name"        -> toMachineToolName[ "DocumentationSearcher" ],
        "DisplayName" -> toDisplayToolName[ "DocumentationSearcher" ],
        "Icon"        -> RawBoxes @ TemplateBox[ { }, "PersonaDocumentation" ],
        "Description" -> $documentationSearchDescription,
        "Parameters"  -> {
            "query" -> <|
                "Interpreter" -> "String",
                "Help"        -> "A string representing a documentation search query",
                "Required"    -> True
            |>
        },
        "Function" -> documentationSearch
    |>,
    { }
];

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
$defaultChatTools0[ "DocumentationLookup" ] = LLMTool[
    <|
        "Name"        -> toMachineToolName[ "DocumentationLookup" ],
        "DisplayName" -> toDisplayToolName[ "DocumentationLookup" ],
        "Icon"        -> RawBoxes @ TemplateBox[ { }, "PersonaDocumentation" ],
        "Description" -> "Get documentation pages for Wolfram Language symbols.",
        "Parameters"  -> {
            "names" -> <|
                "Interpreter" -> DelimitedSequence[ "WolframLanguageSymbol", "," ],
                "Help"        -> "One or more Wolfram Language symbols separated by commas",
                "Required"    -> True
            |>
        },
        "Function" -> documentationLookup
    |>,
    { }
];

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
Evaluate Wolfram Language code for the user in a separate sandboxed kernel. \
You do not need to tell the user the input code that you are evaluating. \
They will be able to inspect it if they want to. \
The user does not automatically see the result. \
You must include the result in your response in order for them to see it. \
If a formatted result is provided as a markdown link, use that in your response instead of typing out the output.
";

$defaultChatTools0[ "WolframLanguageEvaluator" ] = LLMTool[
    <|
        "Name"        -> toMachineToolName[ "WolframLanguageEvaluator" ],
        "DisplayName" -> toDisplayToolName[ "WolframLanguageEvaluator" ],
        "Icon"        -> RawBoxes @ TemplateBox[ { }, "AssistantEvaluate" ],
        "Description" -> $sandboxEvaluateDescription,
        "Parameters"  -> {
            "code" -> <|
                "Interpreter" -> "String",
                "Help"        -> "Wolfram Language code to evaluate",
                "Required"    -> True
            |>
        },
        "Function" -> sandboxEvaluate
    |>,
    { }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*wolframLanguageEvaluator*)
wolframLanguageEvaluator // beginDefinition;
wolframLanguageEvaluator[ code_String ] := wolframLanguageEvaluator[ code, sandboxEvaluate @ code ];
wolframLanguageEvaluator[ code_, KeyValuePattern[ "String" -> result_String ] ] := result;
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

$wolframAlphaIcon = RawBoxes @ PaneBox[
    DynamicBox @ FEPrivate`FrontEndResource[ "FEBitmaps", "InsertionAlpha" ],
    BaselinePosition -> Center -> Scaled[ 0.55 ]
];

$defaultChatTools0[ "WolframAlpha" ] = LLMTool[
    <|
        "Name"        -> toMachineToolName[ "WolframAlpha" ],
        "DisplayName" -> toDisplayToolName[ "WolframAlpha" ],
        "Icon"        -> $wolframAlphaIcon,
        "Description" -> $wolframAlphaDescription,
        "Parameters"  -> {
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
        },
        "Function" -> getWolframAlphaText
    |>,
    { }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getWolframAlphaText*)
getWolframAlphaText // beginDefinition;

getWolframAlphaText[ KeyValuePattern[ "input" -> query_String ] ] :=
    getWolframAlphaText @ query;

getWolframAlphaText[ query_String ] :=
    getWolframAlphaText[ query, WolframAlpha[ query, { All, { "Title", "Plaintext", "ComputableData", "Content" } } ] ];

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
$defaultChatTools0[ "WebSearcher" ] = LLMTool[
    <|
        "Name"        -> toMachineToolName[ "WebSearcher" ],
        "DisplayName" -> toDisplayToolName[ "WebSearcher" ],
        "Icon"        -> RawBoxes @ TemplateBox[ { }, "PersonaFromURL" ],
        "Description" -> "Search the web.",
        "Parameters"  -> {
            "query" -> <|
                "Interpreter" -> "String",
                "Help"        -> "Search query text",
                "Required"    -> True
            |>
        },
        "Function" -> webSearch
    |>,
    { }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*webSearch*)
webSearch // beginDefinition;

webSearch[ KeyValuePattern[ "query" -> query_ ] ] := webSearch @ query;
webSearch[ query_String ] := webSearch @ SearchQueryString @ query;

webSearch[ query_SearchQueryString ] := StringJoin[
    "Results", "\n",
    "-------", "\n\n",
    StringReplace[
        Developer`WriteRawJSONString[
            Normal @ WebSearch[ query, MaxItems -> 5 ] /. URL[ url_ ] :> url
        ],
        "\\/" -> "/"
    ],
    "\n\n",
    "-------", "\n\n",
    "Use the web_fetcher tool to get the content of a URL."
];

webSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WebFetch*)
$defaultChatTools0[ "WebFetcher" ] = LLMTool[
    <|
        "Name"        -> toMachineToolName[ "WebFetcher" ],
        "DisplayName" -> toDisplayToolName[ "WebFetcher" ],
        "Icon"        -> RawBoxes @ TemplateBox[ { }, "PersonaFromURL" ],
        "Description" -> "Fetch plain text or image links from a URL.",
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
        },
        "Function" -> webFetch
    |>,
    { }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*webFetch*)
webFetch // beginDefinition;
webFetch[ KeyValuePattern @ { "url" -> url_, "format" -> fmt_ } ] := webFetch[ url, fmt ];
webFetch[ url_, "Plaintext" ] := fetchWebText @ url;
webFetch[ url: _URL|_String, fmt_String ] := webFetch[ url, fmt, Import[ url, { "HTML", fmt } ] ];
webFetch[ url_, "ImageLinks", { } ] := "No links found at " <> TextString @ url;
webFetch[ url_, "ImageLinks", links: { __String } ] := StringRiffle[ links, "\n" ];
webFetch[ url_, fmt_, result_String ] := result;
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
        StringRiffle[ strings, "\n\n" ]
    ],
    Import[ url, { "HTML", "Plaintext" } ] &
];

fetchWebText // endDefinition;

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
$defaultChatTools0[ "WebImageSearcher" ] = LLMTool[
    <|
        "Name"        -> toMachineToolName[ "WebImageSearcher" ],
        "DisplayName" -> toDisplayToolName[ "WebImageSearcher" ],
        "Icon"        -> RawBoxes @ TemplateBox[ { }, "PersonaFromURL" ],
        "Description" -> "Search the web for images.",
        "Parameters"  -> {
            "query" -> <|
                "Interpreter" -> "String",
                "Help"        -> "Search query text",
                "Required"    -> True
            |>
        },
        "Function" -> webImageSearch
    |>,
    { }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*webImageSearch*)
webImageSearch // beginDefinition;
webImageSearch[ KeyValuePattern[ "query" -> query_ ] ] := webImageSearch @ query;
webImageSearch[ query_String ] := webImageSearch @ SearchQueryString @ query;
webImageSearch[ query_SearchQueryString ] := webImageSearch[ query, WebImageSearch[ query, "ImageHyperlinks" ] ];
webImageSearch[ query_, { } ] := "No results found";
webImageSearch[ query_, urls: { __ } ] := StringRiffle[ TextString /@ urls, "\n" ];
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
    With[ { string = TextString @ expr },
        If[ StringLength @ string < 150,
            If[ StringContainsQ[ string, "\n" ], "\n" <> string, string ],
            StringJoin[
                "\n",
                ToString[ Unevaluated @ Short[ expr, 1 ], OutputForm, PageWidth -> 80 ], "\n\n\n",
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
(* ::Section::Closed:: *)
(*Package Footer*)

(* Sort tools to their default ordering: *)
$defaultChatTools0 = Association[ KeyTake[ $defaultChatTools0, $defaultToolOrder ], $defaultChatTools0 ];

If[ Wolfram`ChatbookInternal`$BuildingMX,
    $toolConfiguration;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
