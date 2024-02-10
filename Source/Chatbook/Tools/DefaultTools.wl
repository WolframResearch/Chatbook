(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];

(* cSpell: ignore TOOLCALL, ENDARGUMENTS, ENDTOOLCALL, Deflatten, Liouville, unexp *)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatPreferences*)

(* Uncomment the following when the ChatPreferences tool is ready: *)
(* $defaultChatTools0[ "ChatPreferences" ] = <|
    toolDefaultData[ "ChatPreferences" ],
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "ChatBlockSettingsMenuIcon" ],
    "Description"        -> $chatPreferencesDescription,
    "Function"           -> chatPreferences,
    "FormattingFunction" -> toolAutoFormatter,
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "action" -> <|
            "Interpreter" -> { "get", "set" },
            "Help"        -> "Whether to get or set chat settings",
            "Required"    -> True
        |>,
        "key" -> <|
            "Interpreter" -> "String",
            "Help"        -> "Which chat setting to get or set",
            "Required"    -> False
        |>,
        "value" -> <|
            "Interpreter" -> "String",
            "Help"        -> "The value to set the chat setting to",
            "Required"    -> False
        |>,
        "scope" -> <|
            "Interpreter" -> { "global", "notebook" },
            "Help"        -> "The scope of the chat setting (default is 'notebook')",
            "Required"    -> False
        |>
    }
|>; *)

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
    "Origin"             -> "BuiltIn",
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
    "Origin"             -> "BuiltIn",
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
cellToString[ args___ ] := CellToString[
    args,
    "ContentTypes"        -> If[ TrueQ @ $multimodalMessages, { "Text", "Image" }, Automatic ],
    "MaxCellStringLength" -> 100
];

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
    "Command"            -> "wl",
    "Description"        -> $sandboxEvaluateDescription,
    "Enabled"            :> ! TrueQ @ $AutomaticAssistance,
    "FormattingFunction" -> sandboxFormatter,
    "Function"           -> sandboxEvaluate,
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "AssistantEvaluate" ],
    "Origin"             -> "BuiltIn",
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
    "Command"            -> "wa",
    "Description"        -> $wolframAlphaDescription,
    "DisplayName"        -> "Wolfram|Alpha",
    "Enabled"            :> ! TrueQ @ $AutomaticAssistance,
    "FormattingFunction" -> wolframAlphaResultFormatter,
    "Function"           -> getWolframAlphaText,
    "Icon"               -> $wolframAlphaIcon,
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "input" -> <|
            "Interpreter" -> "String",
            "Help"        -> "the input",
            "Required"    -> True
        |>,
        "steps" -> <|
            "Interpreter" -> "Boolean",
            "Help"        -> "whether to show step-by-step solution",
            "Required"    -> False
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

getWolframAlphaText[ as_Association ] :=
    getWolframAlphaText[ as[ "input" ], as[ "steps" ] ];

getWolframAlphaText[ query_String, steps: True|False|_Missing ] :=
    Module[ { result, data, string },
        result = WolframAlpha @ query;
        data = WolframAlpha[
            query,
            { All, { "Title", "Plaintext", "ComputableData", "Content" } },
            PodStates -> { If[ TrueQ @ steps, "Step-by-step solution", Nothing ] }
        ];
        string = getWolframAlphaText[ query, steps, data ];
        getWolframAlphaText[ query, steps ] = <| "Result" -> result, "String" -> string |>
    ];

getWolframAlphaText[ query_String, steps_, { } ] :=
    "No results returned";

getWolframAlphaText[ query_String, steps_, info_List ] :=
    getWolframAlphaText[ query, steps, associationKeyDeflatten[ makeKeySequenceRule /@ info ] ];

getWolframAlphaText[ query_String, steps_, as_Association? AssociationQ ] :=
    getWolframAlphaText[ query, steps, waResultText @ as ];

getWolframAlphaText[ query_String, steps_, result_String ] :=
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

waResultText0[ KeyValuePattern @ { "Content"|"ComputableData" -> expr_ } ] /;
    ! FreeQ[ Unevaluated @ expr, _Missing ] := Nothing;

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
    "Origin"             -> "BuiltIn",
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
webSearch[ query_String ] := Block[ { PrintTemporary }, webSearch @ SearchQueryString @ query ];

webSearch[ query_SearchQueryString ] := Enclose[
    Catch @ Module[ { result, json, string },
        result = ConfirmMatch[ webSearch0 @ query, _Dataset|_Failure, "WebSearch" ];

        If[ MatchQ[ result, _Failure ],
            Throw @ <| "Result" -> result, "String" -> makeFailureString @ result |>
        ];

        json   = ConfirmBy[ Developer`WriteRawJSONString[ Normal @ result /. URL[ url_ ] :> url ], StringQ, "JSON" ];
        json   = StringReplace[ json, "\\/" -> "/" ];
        string = ConfirmBy[ TemplateApply[ $webSearchResultTemplate, json ], StringQ, "TemplateApply" ];

        <| "Result" -> result, "String" -> string |>
    ],
    throwInternalFailure[ webSearch @ query, ## ] &
];

webSearch // endDefinition;


webSearch0 // beginDefinition;

webSearch0[ query_SearchQueryString ] := Enclose[
    Module[ { opts, raw, result, held, $unavailable },
        opts   = Sequence @@ ConfirmMatch[ toolOptions[ "WebSearcher" ], { $$optionsSequence }, "Options" ];
        result = Quiet[
            Check[
                raw = WebSearch[ query, opts ],
                $unavailable,
                IntegratedServices`IntegratedServices::unexp
            ],
            IntegratedServices`IntegratedServices::unexp
        ];

        held = HoldForm @ Evaluate @ raw;

        Quiet @ Replace[
            result,
            {
                $unavailable       :> messageFailure[ "IntegratedServiceUnavailable", "WebSearch", held ],
                Except[ _Dataset ] :> messageFailure[ "IntegratedServiceError"      , "WebSearch", held ]
            }
        ]
    ],
    throwInternalFailure[ webImageSearch0 @ query, ## ] &
];

webSearch0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$webSearchResultTemplate*)
$webSearchResultTemplate := StringTemplate @ StringJoin[
    "Results\n-------\n\n`1`\n\n-------",
    If[ KeyExistsQ[ $selectedTools, "WebFetcher" ],
        $webSearchFetchPrompt,
        ""
    ]
];

$webSearchFetchPrompt = "

Important: The snippet text is not enough information to write an informed response! If there are any relevant \
results, you should now immediately use the web_fetcher tool to retrieve them before responding. Do not ask the user \
for permission first. If it made sense to use the web_searcher tool, it's also implied that you should use the \
web_fetcher tool.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WebFetch*)
$defaultChatTools0[ "WebFetcher" ] = <|
    toolDefaultData[ "WebFetcher" ],
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "ToolIconWebFetcher" ],
    "Description"        -> "Fetch plain text or image links from a URL.",
    "Function"           -> webFetch,
    "FormattingFunction" -> toolAutoFormatter,
    "Origin"             -> "BuiltIn",
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

fetchWebText[ url_String, _Missing | _? FailureQ ] :=
    shortenWebText @ niceWebText @ Import[ url, { "HTML", "Plaintext" } ];

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

startWebSession[ ] := $currentWebSession =
    If[ TrueQ @ $CloudEvaluation,
        Missing[ "NotAvailable" ],
        StartWebSession[ Visible -> $webSessionVisible ]
    ];

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
    "Origin"             -> "BuiltIn",
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
webImageSearch[ query_String ] := Block[ { PrintTemporary }, webImageSearch @ SearchQueryString @ query ];
webImageSearch[ query_SearchQueryString ] := webImageSearch[ query, webImageSearch0[ query ] ];

webImageSearch[ query_, { } ] := <|
    "Result" -> { },
    "String" -> "No results found"
|>;

webImageSearch[ query_, urls: { __ } ] := <|
    "Result" -> Column[ Hyperlink /@ urls, BaseStyle -> "Text" ],
    "String" -> StringRiffle[ TextString /@ urls, "\n" ]
|>;

webImageSearch[ query_, failed_Failure ] := <|
    "Result" -> failed,
    "String" -> makeFailureString @ failed
|>;

webImageSearch // endDefinition;


webImageSearch0 // beginDefinition;

webImageSearch0[ query_SearchQueryString ] := Enclose[
    Module[ { opts, raw, result, held, $unavailable },
        opts   = Sequence @@ ConfirmMatch[ toolOptions[ "WebImageSearcher" ], { $$optionsSequence }, "Options" ];
        result = Quiet[
            Check[
                raw = WebImageSearch[ query, "ImageHyperlinks", opts ],
                $unavailable,
                IntegratedServices`IntegratedServices::unexp
            ],
            IntegratedServices`IntegratedServices::unexp
        ];

        held = HoldForm @ Evaluate @ raw;

        Quiet @ Replace[
            result,
            {
                $unavailable    :> messageFailure[ "IntegratedServiceUnavailable", "WebImageSearch", held ],
                Except[ _List ] :> messageFailure[ "IntegratedServiceError"      , "WebImageSearch", held ]
            }
        ]
    ],
    throwInternalFailure[ webImageSearch0 @ query, ## ] &
];

webImageSearch0 // endDefinition;

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

![Formatted Result](expression://content-{id})

[assistant]
The half-order fractional derivative of $$x^n$$ with respect to $$x$$ is given by:
![Fractional Derivative](expression://content-{id})
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
Out[n]= ![image](attachment://content-{id})

[assistant]
Here's the plot of $$\\sin{x}$$ from -5 to 5:
![Plot](attachment://content-{id})"
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
$expressionSchemes = { "attachment", "audio", "dynamic", "expression", "video" };
$$expressionScheme = Alternatives @@ $expressionSchemes;

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
GetExpressionURIs // Options = { Tooltip -> Automatic };

GetExpressionURIs[ str_, opts: OptionsPattern[ ] ] :=
    GetExpressionURIs[ str, ## &, opts ];

GetExpressionURIs[ str_String, wrapper_, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[ { $uriTooltip = OptionValue @ Tooltip },
        StringSplit[
            str,
            link: Shortest[ "![" ~~ __ ~~ "](" ~~ __ ~~ ")" ] :> catchAlways @ GetExpressionURI[ link, wrapper ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*GetExpressionURI*)
GetExpressionURI // ClearAll;
GetExpressionURI // Options = { Tooltip -> Automatic };

GetExpressionURI[ uri_, opts: OptionsPattern[ ] ] :=
    catchMine @ GetExpressionURI[ uri, ## &, opts ];

GetExpressionURI[ URL[ uri_ ], wrapper_, opts: OptionsPattern[ ] ] :=
    catchMine @ GetExpressionURI[ uri, wrapper, opts ];

GetExpressionURI[ uri_String, wrapper_, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    Module[ { held },
        held = ConfirmMatch[ getExpressionURI[ uri, OptionValue[ Tooltip ] ], _HoldComplete, "GetExpressionURI" ];
        wrapper @@ held
    ],
    throwInternalFailure[ GetExpressionURI[ uri, wrapper ], ## ] &
];

GetExpressionURI[ All, wrapper_, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    Module[ { attachments },
        attachments = ConfirmBy[ $attachments, AssociationQ, "Attachments" ];
        ConfirmAssert[ AllTrue[ attachments, MatchQ[ _HoldComplete ] ], "HeldAttachments" ];
        Replace[ attachments, HoldComplete[ a___ ] :> RuleCondition @ wrapper @ a, { 1 } ]
    ],
    throwInternalFailure[ GetExpressionURI[ All, wrapper ], ## ] &
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getExpressionURI0*)
getExpressionURI // beginDefinition;
getExpressionURI[ uri_, tooltip_ ] := Block[ { $tooltip = tooltip }, getExpressionURI0 @ uri ];
getExpressionURI // endDefinition;


getExpressionURI0 // beginDefinition;

getExpressionURI0[ str_String ] :=
    Module[ { split },
        split = First[ StringSplit[ str, "![" ~~ alt__ ~~ "](" ~~ url__ ~~ ")" :> { alt, url } ], $Failed ];
        getExpressionURI0 @@ split /; MatchQ[ split, { _String, _String } ]
    ];

getExpressionURI0[ uri_String ] := getExpressionURI0[ None, uri ];

getExpressionURI0[ tooltip_, uri_String ] := getExpressionURI0[ tooltip, uri, URLParse @ uri ];

getExpressionURI0[ tooltip_, uri_, as: KeyValuePattern @ { "Scheme" -> $$expressionScheme, "Domain" -> key_ } ] :=
    Enclose[
        ConfirmMatch[ displayAttachment[ uri, tooltip, key ], _HoldComplete, "DisplayAttachment" ],
        throwInternalFailure[ getExpressionURI0[ tooltip, uri, as ], ## ] &
    ];

getExpressionURI0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*displayAttachment*)
displayAttachment // beginDefinition;

displayAttachment[ uri_, None, key_ ] :=
    getAttachment[ uri, key ];

displayAttachment[ uri_, tooltip_String, key_ ] := Enclose[
    Replace[
        ConfirmMatch[ getAttachment[ uri, key ], _HoldComplete, "GetAttachment" ],
        HoldComplete[ expr_ ] :>
            If[ TrueQ @ $tooltip,
                HoldComplete @ Tooltip[ expr, tooltip ],
                HoldComplete @ expr
            ]
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

makeToolResponseString[ failure_Failure ] := makeFailureString @ failure;

makeToolResponseString[ expr_? simpleResultQ ] :=
    With[ { string = fixLineEndings @ TextString @ expr },
        If[ StringLength @ string < $toolResultStringLength,
            If[ StringContainsQ[ string, "\n" ], "\n" <> string, string ],
            StringJoin[
                "\n",
                fixLineEndings @ ToString[
                    Unevaluated @ Short[ expr, Floor[ $toolResultStringLength / 100 ] ],
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
    With[ { id = "content-" <> Hash[ Unevaluated @ expr, Automatic, "HexString" ] },
        $attachments[ id ] = HoldComplete @ expr;
        "![" <> TextString @ label <> "](" <> TextString @ scheme <> "://" <> id <> ")"
    ];

makeExpressionURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*expressionURILabel*)
expressionURILabel // beginDefinition;
expressionURILabel // Attributes = { HoldAllComplete };

(* Audio *)
expressionURILabel[ Audio[ path_String, ___ ] ] := "Audio Player: " <> path;
expressionURILabel[ Audio[ File[ path_String ], ___ ] ] := "Audio Player: " <> path;
expressionURILabel[ _Audio ] := "Embedded Audio Player";

(* Video *)
expressionURILabel[ Video[ path_String, ___ ] ] := "Video Player: " <> path;
expressionURILabel[ Video[ File[ path_String ], ___ ] ] := "Video Player: " <> path;
expressionURILabel[ _Video ] := "Embedded Video Player";

(* Dynamic *)
expressionURILabel[ _Manipulate ] := "Embedded Interactive Content";

(* Graphics *)
expressionURILabel[ _Graph|_Graph3D ] := "Graph";
expressionURILabel[ _Tree ] := "Tree";
expressionURILabel[ _Graphics|_Graphics3D|_Image|_Image3D|_Legended|_RawBoxes ] := "Image";

(* Data *)
expressionURILabel[ _List|_Association ] := "Data";

(* Other *)
expressionURILabel[ _ ] := "Content";

expressionURILabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*expressionURIScheme*)
expressionURIScheme // beginDefinition;
expressionURIScheme // Attributes = { HoldAllComplete };
expressionURIScheme[ _Video ] := (needsBasePrompt[ "SpecialURIVideo" ]; "video");
expressionURIScheme[ _Audio ] := (needsBasePrompt[ "SpecialURIAudio" ]; "audio");
expressionURIScheme[ _Manipulate|_DynamicModule|_Dynamic ] := (needsBasePrompt[ "SpecialURIDynamic" ]; "dynamic");
expressionURIScheme[ _Graph|_Graph3D|_Graphics|_Graphics3D|_Image|_Image3D|_Legended|_Tree|_RawBoxes ] := "attachment";
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
getToolIcon[ tool: $$llmTool ] := getToolIcon @ toolData @ tool;
getToolIcon[ as_Association ] := Lookup[ toolData @ as, "Icon", RawBoxes @ TemplateBox[ { }, "WrenchIcon" ] ];
getToolIcon[ _ ] := $defaultToolIcon;
getToolIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
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
