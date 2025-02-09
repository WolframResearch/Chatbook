(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                         ];
Needs[ "Wolfram`Chatbook`Common`"                  ];
Needs[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$snippetType                  = "Text";
$documentationSnippetVersion := $snippetVersion;
$baseURL                      = "https://www.wolframcloud.com/obj/wolframai-content/DocumentationSnippets";
$documentationSnippetBaseURL := URLBuild @ { $baseURL, $documentationSnippetVersion, $snippetType };
$resourceSnippetBaseURL       = URLBuild @ { $baseURL, "Resources", $snippetType };

$documentationSnippetsCacheDirectory := $documentationSnippetsCacheDirectory =
    ChatbookFilesDirectory @ { "DocumentationSnippets", "Documentation", $documentationSnippetVersion };

$resourceSnippetsCacheDirectory := $resourceSnippetsCacheDirectory =
    ChatbookFilesDirectory @ { "DocumentationSnippets", "ResourceSystem" };

$rerankMethod := $rerankMethod = CurrentChatSettings[ "DocumentationRerankMethod" ];

$rerankScoreThreshold = 3;

$bestDocumentationPromptMethod := $bestDocumentationPromptMethod = CurrentChatSettings[ "RerankPromptStyle" ];
$bestDocumentationPrompt := If[ $bestDocumentationPromptMethod === "JSON",
                                $bestDocumentationPromptLarge,
                                $bestDocumentationPromptSmall
                            ];

$defaultSources = { "Documentation", "FunctionRepository", "DataRepository" };

$sourceAliases = <|
    "DataRepository"     -> "DataRepositoryURIs",
    "Documentation"      -> "DocumentationURIs",
    "FunctionRepository" -> "FunctionRepositoryURIs"
|>;

$maxSelectedSources       = 3;
$minUnfilteredItems       = 20;
$unfilteredItemsPerSource = 20;

$filteringLLMConfig = <| "StopTokens" -> { "CasualChat" } |>;


$$assistantTypeTag = "Computational"|"Knowledge"|"CasualChat";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$snippetVersion*)
$snippetVersion := $snippetVersion = If[ $VersionNumber >= 14.2, "14-2-0-11168610", "14-1-0-10549042" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
Chatbook::CloudDownloadError           = "Unable to download required data from the cloud. Please try again later.";
Chatbook::InvalidSources               = "Invalid value for the \"Sources\" option: `1`.";
Chatbook::InvalidMaxSources            = "Invalid value for the \"MaxSources\" option: `1`.";
Chatbook::SnippetFunctionOutputFailure = "The snippet function `1` returned a list of length `2` for `3` values.";
Chatbook::SnippetFunctionLengthFailure = "The snippet function `1` returned a list of length `2` for `3` values.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$RelatedDocumentationSources*)
$RelatedDocumentationSources = Automatic;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedDocumentation*)
RelatedDocumentation // beginDefinition;
RelatedDocumentation // Options = {
    "FilteredCount"     -> Automatic,
    "FilterResults"     -> Automatic,
    "LLMEvaluator"      -> Automatic,
    "MaxItems"          -> Automatic,
    "MaxSources"        -> $maxSelectedSources,
    "RerankPromptStyle" -> Automatic,
    "RerankMethod"      -> Automatic,
    "Sources"           :> $RelatedDocumentationSources
};

GeneralUtilities`SetUsage[ RelatedDocumentation, "\
RelatedDocumentation[\"string$\"] gives a list of documentation URIs that are semantically related to the \
conversational-style question specified by \"string$\".
RelatedDocumentation[All] gives the full list of available documentation URIs." ];

RelatedDocumentation[ ___ ] /; $noSemanticSearch := Failure[
    "SemanticSearchUnavailable",
    <|
        "MessageTemplate"   :> "SemanticSearch paclet is not available.",
        "MessageParameters" -> { }
    |>
];

RelatedDocumentation[ prompt_, opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedDocumentation[ prompt, Automatic, opts ];

RelatedDocumentation[ prompt_, Automatic, opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedDocumentation[ prompt, "URIs", opts ];

RelatedDocumentation[ prompt_, count: _Integer | UpTo[ _Integer ], opts: OptionsPattern[ ] ] :=
    RelatedDocumentation[ prompt, Automatic, count, opts ];

RelatedDocumentation[ prompt_, property_, opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedDocumentation[
        prompt,
        property,
        getMaxItems[
            OptionValue @ MaxItems,
            getSources[ prompt, OptionValue[ "Sources" ], OptionValue[ "MaxSources" ] ]
        ],
        opts
    ];

RelatedDocumentation[ prompt_, Automatic, count_, opts: OptionsPattern[ ] ] :=
    RelatedDocumentation[ prompt, "URIs", count, opts ];

RelatedDocumentation[ prompt: $$prompt, "URIs", Automatic, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    (* TODO: filter results *)
    URL /@ ConfirmMatch[
        vectorDBSearch[ getSources[ prompt, OptionValue[ "Sources" ], OptionValue[ "MaxSources" ] ], prompt, "Values" ],
        { ___String },
        "Values"
    ],
    throwInternalFailure
];

RelatedDocumentation[ All, "URIs", Automatic, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    (* TODO: filter results *)
    URL /@ Union @ ConfirmMatch[
        vectorDBSearch[ getSources[ None, OptionValue[ "Sources" ], OptionValue[ "MaxSources" ] ], All ],
        { ___String },
        "Values"
    ],
    throwInternalFailure
];

RelatedDocumentation[ prompt: $$prompt, "Snippets", Automatic, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    ConfirmMatch[
        (* TODO: filter results *)
        DeleteMissing @ makeDocSnippets @ vectorDBSearch[
            getSources[ prompt, OptionValue[ "Sources" ], OptionValue[ "MaxSources" ] ],
            prompt,
            "Results"
        ],
        { ___String },
        "Snippets"
    ],
    throwInternalFailure
];

RelatedDocumentation[ prompt_, property_, UpTo[ n_Integer ], opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedDocumentation[ prompt, property, n, opts ];

RelatedDocumentation[ prompt_, property_, n_Integer, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    Take[ ConfirmBy[ RelatedDocumentation[ prompt, property, Automatic, opts ], ListQ ], UpTo @ n ],
    throwInternalFailure
];

RelatedDocumentation[
    prompt: $$prompt,
    property: "Results"|"Values"|"EmbeddingVector"|All,
    n_Integer,
    opts: OptionsPattern[ ]
] :=
    catchMine @ Enclose[
        (* TODO: filter results *)
        Take[
            ConfirmBy[
                vectorDBSearch[
                    getSources[ prompt, OptionValue[ "Sources" ], OptionValue[ "MaxSources" ] ],
                    prompt,
                    property
                ],
                ListQ,
                "Results"
            ],
            UpTo @ n
        ],
        throwInternalFailure
    ];

RelatedDocumentation[ prompt_, property: "Index"|"Distance", n_Integer, opts: OptionsPattern[ ] ] :=
    catchMine @ Enclose[
        Lookup[
            Take[
                ConfirmMatch[
                    RelatedDocumentation[ prompt, "Results", n, opts ],
                    { KeyValuePattern[ property -> _ ]... },
                    "Results"
                ],
                UpTo @ n
            ],
            property
        ],
        throwInternalFailure
    ];

RelatedDocumentation[ prompt_, "Prompt", n_Integer, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[
        {
            $rerankMethod = Replace[
                OptionValue[ "RerankMethod" ],
                $$unspecified :> $rerankMethod
            ],
            $bestDocumentationPromptMethod = Replace[
                OptionValue[ "RerankPromptStyle" ],
                $$unspecified :> $bestDocumentationPromptMethod
            ],
            $filteringLLMConfig = Replace[
                OptionValue[ "LLMEvaluator" ],
                $$unspecified :> $filteringLLMConfig
            ],
            $RelatedDocumentationSources = getSources[ prompt, OptionValue[ "Sources" ], OptionValue[ "MaxSources" ] ]
        },
        relatedDocumentationPrompt[
            ensureChatMessages @ prompt,
            n,
            MatchQ[ OptionValue[ "FilterResults" ], Automatic|True ],
            Replace[ OptionValue[ "FilteredCount" ], Automatic -> Ceiling[ n / 4 ] ]
        ]
    ];

RelatedDocumentation[ args___ ] := catchMine @ throwFailure[
    "InvalidArguments",
    RelatedDocumentation,
    HoldForm @ RelatedDocumentation @ args
];

RelatedDocumentation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getMaxItems*)
getMaxItems // beginDefinition;
getMaxItems[ $$unspecified, sources_List ] := Max[ $minUnfilteredItems, $unfilteredItemsPerSource * Length @ sources ];
getMaxItems[ Infinity, _ ] := 100;
getMaxItems[ n: $$size, _ ] := Ceiling @ n;
getMaxItems[ UpTo[ n_ ], sources_ ] := getMaxItems[ n, sources ];
getMaxItems // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getSources*)
getSources // beginDefinition;
getSources[ prompt_, names_List, max_ ] := toSource /@ Flatten @ names;
getSources[ prompt_, name_String, max_ ] := { toSource @ name };
getSources[ prompt_, All, max_ ] := toSource /@ $defaultSources;
getSources[ None, Automatic, max_Integer? NonNegative ] := toSource /@ Take[ $defaultSources, UpTo[ max ] ];
getSources[ prompt_, Automatic, max_Integer? NonNegative ] := autoSelectSources[ prompt, max ];
getSources[ prompt_, source_, max_Integer? NonNegative ] := throwFailure[ "InvalidSources", source ];
getSources[ prompt_, source_, max_ ] := throwFailure[ "InvalidMaxSources", max ];
getSources // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*autoSelectSources*)
autoSelectSources // beginDefinition;

autoSelectSources[ prompt_, max_ ] /; max >= Length @ $defaultSources :=
    toSource /@ $defaultSources;

autoSelectSources[ prompt_, max_Integer? NonNegative ] := Enclose[
    Module[ { values },
        values = ConfirmMatch[ vectorDBSearch[ "SourceSelector", prompt, "Values" ], { ___String }, "Values" ];
        ConfirmMatch[ toSource /@ Take[ values, UpTo[ max ] ], { ___String }, "Result" ]
    ],
    throwInternalFailure
];

autoSelectSources // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toSource*)
toSource // beginDefinition;
toSource[ name_String ] := Lookup[ $sourceAliases, name, name ];
toSource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensureChatMessages*)
ensureChatMessages // beginDefinition;
ensureChatMessages[ prompt_String ] := { <| "Role" -> "User", "Content" -> prompt |> };
ensureChatMessages[ message: KeyValuePattern[ "Role" -> _ ] ] := { message };
ensureChatMessages[ messages: $$chatMessages ] := messages;
ensureChatMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relatedDocumentationPrompt*)
relatedDocumentationPrompt // beginDefinition;

relatedDocumentationPrompt[ messages: $$chatMessages, count_, filter_, filterCount_ ] := Enclose[
    Catch @ Module[ { results, filtered, string },

        results = ConfirmMatch[
            RelatedDocumentation[ messages, "Results", count ],
            { ___Association },
            "Results"
        ] // LogChatTiming[ "RelatedDocumentationResults" ] // withApproximateProgress[ "CheckingDocumentation", 0.2 ];

        If[ results === { }, Throw[ "" ] ];

        results = Take[ DeleteDuplicatesBy[ results, Lookup[ "Value" ] ], UpTo[ count ] ];

        filtered = ConfirmMatch[
            filterSnippets[ messages, results, filter, filterCount ] // LogChatTiming[ "FilterSnippets" ],
            { ___String },
            "Filtered"
        ];

        string = StringTrim @ StringRiffle[ DeleteCases[ filtered, "" ], "\n\n======\n\n" ];

        If[ string === "",
            "",
            prependRelatedDocsHeader[ string, filter ]
        ]
    ],
    throwInternalFailure
];

relatedDocumentationPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*prependRelatedDocsHeader*)
prependRelatedDocsHeader // beginDefinition;
prependRelatedDocsHeader[ string_String, True ] := $relatedDocsStringFilteredHeader <> string;
prependRelatedDocsHeader[ string_String, _    ] := $relatedDocsStringUnfilteredHeader <> string;
prependRelatedDocsHeader // endDefinition;


$relatedDocsStringFilteredHeader =
"IMPORTANT: Here are some Wolfram documentation snippets that you should use to respond.\n\n";

$relatedDocsStringUnfilteredHeader =
"Here are some Wolfram documentation snippets that you may find useful.\n\n";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*filterSnippets*)
filterSnippets // beginDefinition;


filterSnippets[ messages_, results_List, Except[ True ], filterCount_ ] := Enclose[
    ConfirmMatch[ makeDocSnippets @ results, { ___String }, "Snippets" ],
    throwInternalFailure
];


filterSnippets[
    messages_,
    results_List,
    True,
    filterCount_Integer? Positive
] /; $rerankMethod === None := Enclose[
    Catch @ Module[ { snippets },
        snippets = ConfirmMatch[ makeDocSnippets @ results, { ___String }, "Snippets" ];
        Take[ snippets, UpTo[ filterCount ] ]
    ],
    throwInternalFailure
];


filterSnippets[
    messages_,
    results_List,
    True,
    filterCount_Integer? Positive
] /; $rerankMethod === "rerank-english-v3.0" (* EXPERIMENTAL *) := Enclose[
    Catch @ Module[ { snippets, inserted, transcript, instructions, resp, respResults, idx, ranked },

        snippets = ConfirmMatch[ makeDocSnippets @ results, { ___String }, "Snippets" ];
        setProgressDisplay[ "ProgressTextChoosingDocumentation" ];
        inserted = insertContextPrompt @ messages;
        transcript = ConfirmBy[ getSmallContextString @ inserted, StringQ, "Transcript" ];

        instructions = ConfirmBy[
            TemplateApply[ $documentationRerankPrompt, <| "Transcript" -> transcript |> ],
            StringQ,
            "Prompt"
        ];

        resp = ServiceExecute[
            "Cohere",
            "RawRerank",
            {
                "model"     -> "rerank-english-v3.0",
                "query"     -> instructions,
                "documents" -> snippets
            }
        ];

        If[ FailureQ @ resp, throwTop @ resp ];

        respResults = ConfirmMatch[ resp[ "results" ], { __Association }, "Results" ];

        idx = ConfirmMatch[
            Select[ respResults, #[ "relevance_score" ] > 0.01 & ][[ All, "index" ]] + 1,
            { ___Integer },
            "Indices"
        ];

        ranked = ConfirmMatch[ snippets[[ idx ]], { ___String }, "Ranked" ];

        (* FIXME: need to add handler data here *)

        Take[ ranked, UpTo[ filterCount ] ]
    ],
    throwInternalFailure
];


filterSnippets[ messages_, results0_List, True, filterCount_Integer? Positive ] := Enclose[
    Catch @ Module[
        {
            results, snippets, inserted, transcript, xml,
            instructions, response, uriToSnippet, uris, selected, pages
        },

        results = ConfirmMatch[ addDocSnippets @ results0, { ___Association }, "Results" ];
        snippets = ConfirmMatch[ Lookup[ results, "Snippet" ], { ___String }, "Snippets" ];
        setProgressDisplay[ "ChoosingDocumentation" ];
        inserted = insertContextPrompt @ messages;
        transcript = ConfirmBy[ getSmallContextString @ inserted, StringQ, "Transcript" ];

        xml = ConfirmMatch[ snippetXML /@ snippets, { __String }, "XML" ];
        instructions = ConfirmBy[
            TemplateApply[
                $bestDocumentationPrompt,
                <|
                    "FilteredCount" -> filterCount,
                    "Snippets"      -> StringRiffle[ xml, "\n\n" ],
                    "Transcript"    -> transcript
                |>
            ],
            StringQ,
            "Prompt"
        ];

        response = StringTrim @ ConfirmBy[
            LogChatTiming[
                llmSynthesize[ instructions, Replace[ $filteringLLMConfig, Automatic -> Verbatim @ Automatic, { 1 } ] ],
                "WaitForFilterSnippetsTask"
            ] // withApproximateProgress[ 0.5 ],
            StringQ,
            "Response"
        ];

        uriToSnippet = <| #Value -> #Snippet & /@ results |>;
        uris = ConfirmMatch[ Keys @ uriToSnippet, { ___String }, "URIs" ];
        selected = ConfirmMatch[ LogChatTiming @ selectSnippetsFromResponse[ response, uris ], { ___String }, "Pages" ];
        pages = ConfirmMatch[ Lookup[ uriToSnippet, selected ], { ___String }, "Pages" ];

        addHandlerArguments[
            "RelatedDocumentation" -> <|
                "Results"      -> uris,
                "Filtered"     -> selected,
                "Response"     -> response,
                "Instructions" -> instructions
            |>
        ];

        pages
    ],
    throwInternalFailure
];


filterSnippets // endDefinition;



$bestDocumentationPromptLarge = StringTemplate[ "\
Your task is to read a chat transcript between a user and assistant, and then select any relevant Wolfram Language \
documentation snippets that could help the assistant answer the user's latest message.

Each snippet is uniquely identified by a URI (always starts with 'paclet:' or 'https://*.wolframcloud.com').
You must also include the fragment appearing after the '#' in the URI.

Choose up to %%FilteredCount%% documentation snippets that would help answer the user's MOST RECENT message.

Respond with JSON in the following format:
{
	\"AssistantType\": assistantType,
	\"Snippets\": [
		{\"URI\": uri1, \"Score\": score1},
		{\"URI\": uri2, \"Score\": score2},
		...
	]
}

For \"AssistantType\", specify the type of assistant that should handle the user's message:
	\"Computational\": The user's message requires a computational response.
	\"Knowledge\": The user's message requires a knowledge-based response.
	\"CasualChat\": The user's message is casual and could be answered by a non-specialist. For example, simple greetings or general questions.

Specify a score as any number from 1 to 5 for your chosen snippets using the following rubric:
	1: The snippet is completely irrelevant to the user's message or has no usefulness.
	2: The snippet is somewhat related, but the assistant could easily answer the user's message without it.
	3: The snippet is related and might help the assistant answer the user's message.
	4: The snippet is very relevant and would significantly help the assistant answer the user's message.
	5: It would be impossible for the assistant to answer the user's message correctly without this snippet.

Here is the chat transcript:

<transcript>
%%Transcript%%
</transcript>

Here are the available documentation snippets to choose from:

<snippets>
%%Snippets%%
</snippets>

Reminder: Choose up to %%FilteredCount%% documentation snippets that would help answer the user's MOST RECENT message.
You can (and should) skip snippets that are not relevant to the user's message or are redundant.
Respond only with the specified JSON and nothing else.
If there are no relevant pages, respond with [].
", Delimiters -> "%%" ];



$bestDocumentationPromptSmall = StringTemplate[ "\
Your task is to read a chat transcript and select relevant Wolfram Language documentation snippets to help answer the \
user's latest message.

On the first line of your response, write one of these assistant types:
	\"Computational\": The user's message requires a computational response.
	\"Knowledge\": The user's message requires a knowledge-based response.
	\"CasualChat\": The user's message is casual and could be answered by a non-specialist. For example, simple greetings or general questions.

Then on each subsequent line, write a score (1-5) and id pair, separated by a space:
<score> <id>

Specify the score as any number from 1 to 5 for your chosen snippets using the following rubric:
	1: The snippet is completely irrelevant to the user's message or has no usefulness.
	2: The snippet is somewhat related, but the assistant could easily answer the user's message without it.
	3: The snippet is related and might help the assistant answer the user's message.
	4: The snippet is very relevant and would significantly help the assistant answer the user's message.
	5: It would be impossible for the assistant to answer the user's message correctly without this snippet.

<example>
Computational
4 Plus-3
3 ArithmeticFunctions-1
</example>

Here is the chat transcript:

<transcript>
%%Transcript%%
</transcript>

Available documentation snippets:

<snippets>
%%Snippets%%
</snippets>

Choose up to %%FilteredCount%% of the most relevant snippets. Skip irrelevant or redundant ones.
If there are multiple snippets that express the same idea, you should prefer the one that is easiest to understand.
If no relevant pages exist, only respond with the assistant type.
Respond only in the specified format and do not include any other text.\
", Delimiters -> "%%" ];



$documentationRerankPrompt = StringTemplate[ "\
Read the chat transcript between a user and assistant, and then give me the best Wolfram Language documentation \
snippet that could help the assistant answer the user's latest message.

The snippet does not need to exactly answer the user's message if it can be easily generalized.
Prefer built-in system symbols over other resources.
Simpler is better.

Here is the chat transcript:

<transcript>
%%Transcript%%
</transcript>\
", Delimiters -> "%%" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*selectSnippetsFromResponse*)
selectSnippetsFromResponse // beginDefinition;

selectSnippetsFromResponse[ response_String, uris_List ] /; $bestDocumentationPromptMethod === "JSON" := Enclose[
    Catch @ Module[ { jsonString, jsonData, selected },
        jsonString = ConfirmBy[ First[ StringCases[ response, Longest[ "{" ~~ __ ~~ "}" ], 1 ], None ], StringQ ];
        jsonData = ConfirmBy[ Quiet @ Developer`ReadRawJSONString @ jsonString, AssociationQ ];
        selected = ConfirmMatch[ Select[ jsonData[ "Snippets" ], #[ "Score" ] >= $rerankScoreThreshold & ], { __ } ];
        ConfirmMatch[
            Intersection[ Cases[ selected, KeyValuePattern[ "URI" -> uri_String ] :> StringTrim @ uri ], uris ],
            { __String }
        ]
    ],
    selectSnippetsFromString[ response, uris ] &
];

selectSnippetsFromResponse[ response_String, uris_List ] :=
    selectSnippetsFromResponseSmall[ response, uris, uriToSnippetID /@ uris ];

selectSnippetsFromResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*selectSnippetsFromResponseSmall*)
selectSnippetsFromResponseSmall // beginDefinition;

selectSnippetsFromResponseSmall[ response_String, uris_List, ids_List ] := Enclose[
    Catch @ Module[ { idPatt, scored, selected, selectedIDs, selectedURIs },

        If[ StringMatchQ[ StringTrim @ response, $$assistantTypeTag|"", IgnoreCase -> True ], Throw @ { } ];

        idPatt = ReverseSortBy[ ids, StringLength ];

        scored = ConfirmMatch[
            StringCases[
                response,
                StringExpression[
                    StartOfLine,
                    s: NumberString,
                    Whitespace,
                    Shortest[ Except[ "\n" ]... ],
                    id: idPatt,
                    Shortest[ Except[ "\n" ]... ],
                    WhitespaceCharacter...,
                    EndOfLine
                ] :> <| "Score" -> ToExpression @ s, "ID" -> snippetIDToURI @ id |>
            ],
            { __Association }
        ];

        ConfirmAssert[ AllTrue[ scored, NumberQ @ #[ "Score" ] & ], "ScoreCheck" ];

        selected = ReverseSortBy[
            ConfirmMatch[
                Select[ scored, #[ "Score" ] >= $rerankScoreThreshold & ],
                { ___Association }
            ],
            Lookup[ "Score" ]
        ];

        If[ selected === { }, Throw @ { } ];

        selectedIDs = ConfirmMatch[ Lookup[ selected, "ID" ], { ___String }, "SelectedIDs" ];
        selectedURIs = ConfirmMatch[ snippetIDToURI /@ selectedIDs, { ___String }, "SelectedURIs" ];
        ConfirmMatch[ Cases[ selectedURIs, Alternatives @@ uris ], { ___String } ]
    ],
    snippetIDToURI /@ selectSnippetsFromString[ response, ids ] &
];

selectSnippetsFromResponseSmall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*scoreSnippetLine*)
scoreSnippetLine // beginDefinition;

scoreSnippetLine[ $$assistantTypeTag ] :=
    Nothing;

scoreSnippetLine[ line_String ] /; StringMatchQ[ StringTrim @ line, $$assistantTypeTag, IgnoreCase -> True ] :=
    Nothing;

scoreSnippetLine[ line_String ] := Enclose[
    Module[ { scoreString, id, score },
        { scoreString, id } = ConfirmMatch[ StringSplit[ line, Whitespace ], { _String, _String }, "Split" ];
        score = ToExpression @ ConfirmBy[ scoreString, StringMatchQ @ NumberString, "Score" ];
        <| "Score" -> score, "ID" -> id |>
    ],
    $Failed &
];

scoreSnippetLine // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*selectSnippetsFromString*)
selectSnippetsFromString // beginDefinition;
selectSnippetsFromString[ response_String, ids: { ___String } ] := StringCases[ response, ids ];
selectSnippetsFromString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*snippetXML*)
snippetXML // beginDefinition;

snippetXML[ snippet_String ] :=
    snippetXML[ snippet, $bestDocumentationPromptMethod ];

snippetXML[ snippet_String, "JSON" ] :=
    "<snippet>\n"<>snippet<>"\n</snippet>";

snippetXML[ snippet_String, "Small" ] := snippetXML[ snippet, "Small" ] = Enclose[
    StringReplace[
        snippet,
        StartOfString ~~ header: Except[ "\n" ].. ~~ "\n" ~~ uri: Except[ "\n" ].. ~~ "\n" ~~ rest__ ~~ EndOfString :>
            StringJoin[
                "<snippet id='", ConfirmBy[ uriToSnippetID @ uri, StringQ, "ID" ], "'>\n",
                header, "\n",
                rest, "\n</snippet>"
            ]
    ],
    throwInternalFailure
];

snippetXML[ snippet_String, other_ ] :=
    snippetXML[ snippet, "Small" ];

snippetXML // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*uriToSnippetID*)
uriToSnippetID // beginDefinition;

uriToSnippetID[ uri_String ] := Enclose[
    Module[ { split, base, counter, id },
        split = Last @ ConfirmMatch[ StringSplit[ uri, "/" ], { __String }, "Split" ];
        base = First @ StringSplit[ split, "#" ];
        counter = ConfirmBy[ getSnippetIDCounter[ uri, base ], IntegerQ, "Counter" ];
        id = base <> "-" <> ToString @ counter;
        snippetIDToURI[ id ] = uri;
        uriToSnippetID[ uri ] = id
    ],
    throwInternalFailure
];

uriToSnippetID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*snippetIDToURI*)
snippetIDToURI // beginDefinition;
(* This is defined for individual ids during evaluation of uriToSnippetID. *)
snippetIDToURI[ id_String ] := id;
snippetIDToURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getSnippetIDCounter*)
getSnippetIDCounter // beginDefinition;

getSnippetIDCounter[ uri_String ] :=
    getSnippetIDCounter[ uri, First @ StringSplit[ Last @ StringSplit[ uri, "/" ], "#" ] ];

getSnippetIDCounter[ uri_String, base_String ] := getSnippetIDCounter[ uri, base ] =
    If[ IntegerQ @ $snippetIDCounters[ base ],
        ++$snippetIDCounters[ base ],
        $snippetIDCounters[ base ] = 1
    ];

getSnippetIDCounter // endDefinition;

$snippetIDCounters = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Documentation Snippets*)
$documentationSnippets = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*addDocSnippets*)
addDocSnippets // beginDefinition;

addDocSnippets[ results: { ___Association } ] := Enclose[
    Module[ { withOrdering, grouped, withSnippets, sorted },

        withOrdering = MapIndexed[ <| "Position" -> First[ #2 ], #1 |> &, results ];
        grouped      = GroupBy[ withOrdering, Lookup[ "SnippetFunction" ] ];

        withSnippets = ConfirmMatch[
            Flatten @ KeyValueMap[ applySnippetFunction, grouped ],
            { ___Association },
            "WithSnippets"
        ];

        sorted = ConfirmMatch[ SortBy[ withSnippets, Lookup[ "Position" ] ], { ___Association }, "Sorted" ];

        ConfirmAssert[ Length @ sorted === Length @ results, "LengthCheck" ];

        sorted
    ],
    throwInternalFailure
];

addDocSnippets // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeDocSnippets*)
makeDocSnippets // beginDefinition;

makeDocSnippets[ results: { ___Association } ] := Enclose[
    Module[ { sorted, snippets },
        sorted   = ConfirmMatch[ addDocSnippets @ results, { ___Association }, "Sorted" ];
        snippets = ConfirmMatch[ Lookup[ sorted, "Snippet" ], { ___String }, "Snippets" ];
        ConfirmAssert[ Length @ snippets === Length @ results, "LengthCheck" ];
        DeleteDuplicates @ snippets
    ],
    throwInternalFailure
];

makeDocSnippets // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applySnippetFunction*)
applySnippetFunction // beginDefinition;

applySnippetFunction[ f_, { } ] := { };

applySnippetFunction[ f_, data: { ___Association } ] := Enclose[
    Module[ { values, snippets, snippetLen, valuesLen },

        values     = ConfirmMatch[ Lookup[ data, "Value" ], { ___String }, "Values" ];
        snippets   = f @ values;
        snippetLen = Length @ snippets;
        valuesLen  = Length @ values;

        If[ ! MatchQ[ snippets, { ___String } ], throwFailure[ "SnippetFunctionOutputFailure", f, snippets ] ];
        If[ snippetLen =!= valuesLen, throwFailure[ "SnippetFunctionLengthFailure", f, snippetLen, valuesLen ] ];

        ConfirmBy[
            Association /@ Transpose @ { data, Thread[ "Snippet" -> snippets ] },
            AllTrue @ AssociationQ,
            "Result"
        ]
    ] // LogChatTiming @ { "ApplySnippetFunction", f },
    throwInternalFailure
];

applySnippetFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getSnippets*)
getSnippets // beginDefinition;

getSnippets[ uris: { ___String } ] := Enclose[
    Module[ { data, snippets, strings },
        data = ConfirmBy[ getDocumentationSnippetData @ uris, AssociationQ, "Data" ];
        snippets = ConfirmMatch[ Lookup[ data, uris ], { ___Association }, "Snippets" ];
        strings = ConfirmMatch[ Lookup[ "String" ] /@ snippets, { ___String }, "Strings" ];
        ConfirmAssert[ Length @ strings === Length @ uris, "LengthCheck" ];
        "# " <> # & /@ strings
    ],
    throwInternalFailure
];

getSnippets[ uri_String ] :=
    First @ getSnippets @ { uri };

getSnippets // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getDocumentationSnippetData*)
getDocumentationSnippetData // beginDefinition;

getDocumentationSnippetData[ { } ] := <| |>;

getDocumentationSnippetData[ uris: { __String } ] := Enclose[
    Module[ { cached, missing },

        cached = ConfirmBy[
            AssociationMap[ getCachedDocumentationSnippet, uris ],
            AllTrue @ MatchQ[ _Missing | KeyValuePattern[ "String" -> _String ] ],
            "Cached"
        ];

        missing = ConfirmMatch[
            Union[ First /@ StringSplit[ Keys @ Select[ cached, MissingQ ], "#" ] ],
            { ___String },
            "Missing"
        ];

        LogChatTiming @ fetchDocumentationSnippets @ missing;

        ConfirmBy[
            AssociationMap[ getCachedDocumentationSnippet, uris ],
            AllTrue @ MatchQ[ KeyValuePattern[ "String" -> _String ] ],
            "Result"
        ]
    ] // LogChatTiming[ "GetDocumentationSnippets" ],
    throwInternalFailure
];

getDocumentationSnippetData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getCachedDocumentationSnippet*)
getCachedDocumentationSnippet // beginDefinition;
getCachedDocumentationSnippet[ uri_String ] := getCachedDocumentationSnippet @ StringSplit[ uri, "#" ];
getCachedDocumentationSnippet[ { base_String } ] := getCachedDocumentationSnippet @ { base, None };
getCachedDocumentationSnippet[ { base_String, fragment_ } ] := getCachedDocumentationSnippet0[ base, fragment ];
getCachedDocumentationSnippet // endDefinition;


getCachedDocumentationSnippet0 // beginDefinition;

getCachedDocumentationSnippet0[ base_String, fragment_ ] :=
    With[ { snippet = $documentationSnippets[ base, fragment ] },
        snippet /; snippetDataQ @ snippet
    ];

getCachedDocumentationSnippet0[ base_String, fragment_ ] := Enclose[
    Catch @ Module[ { file, data, snippet },
        file = ConfirmBy[ snippetCacheFile @ base, StringQ, "File" ];
        data = If[ TrueQ @ FileExistsQ @ file, Quiet @ Developer`ReadWXFFile @ file, Throw @ Missing[ "NotCached" ] ];
        snippet = data[ fragment ];
        If[ AssociationQ @ data && snippetDataQ @ snippet,
            $documentationSnippets[ base ] = data; snippet,
            Missing[ "NotCached" ]
        ]
    ],
    throwInternalFailure
];

getCachedDocumentationSnippet0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*snippetDataQ*)
snippetDataQ // beginDefinition;
snippetDataQ[ KeyValuePattern[ "String" -> _String ] ] := True;
snippetDataQ[ _ ] := False;
snippetDataQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*snippetCacheFile*)
snippetCacheFile // beginDefinition;

snippetCacheFile[ uri_String ] /; StringStartsQ[ uri, "paclet:" ] :=
    snippetCacheFile[ uri, StringDelete[ uri, "paclet:" ], "Documentation" ];

snippetCacheFile[ uri_String ] /; StringStartsQ[ uri, "https://resources.wolframcloud.com/" ] :=
    snippetCacheFile[ uri, StringDelete[ uri, "https://resources.wolframcloud.com/" ], "ResourceSystem" ];

snippetCacheFile[ uri_String ] /; StringStartsQ[ uri, "https://datarepository.wolframcloud.com/" ] :=
    snippetCacheFile[
        uri,
        "DataRepository" <> StringDelete[ uri, "https://datarepository.wolframcloud.com/" ],
        "ResourceSystem"
    ];

snippetCacheFile[ uri_String, path0_String, name_String ] := Enclose[
    Module[ { path, file },
        path = ConfirmBy[ StringTrim[ path0, "/" ] <> ".wxf", StringQ, "Path" ];
        file = ConfirmBy[ FileNameJoin @ { snippetCacheDirectory @ name, path }, StringQ, "File" ];
        snippetCacheFile[ uri ] = file
    ],
    throwInternalFailure
];

snippetCacheFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*snippetCacheDirectory*)
snippetCacheDirectory // beginDefinition;
snippetCacheDirectory[ "Documentation"  ] := $documentationSnippetsCacheDirectory;
snippetCacheDirectory[ "ResourceSystem" ] := $resourceSnippetsCacheDirectory;
snippetCacheDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*fetchDocumentationSnippets*)
fetchDocumentationSnippets // beginDefinition;

fetchDocumentationSnippets[ { } ] := { };

fetchDocumentationSnippets[ uris: { __String } ] := Enclose[
     Module[ { count, text, $results, tasks },
        count = Length @ uris;

        text = If[ $EvaluationEnvironment === "Session",
                   ConfirmBy[
                       If[ count === 1,
                           trStringTemplate[ "ProgressTextDownloadingSnippet" ][ count ],
                           trStringTemplate[ "ProgressTextDownloadingSnippets" ][ count ]
                       ],
                       StringQ,
                       "Text"
                   ],
                   ""
               ];

        withApproximateProgress[
            $results = AssociationMap[ <| "URI" -> #1 |> &, uris ];
            tasks = fetchDocumentationSnippets0 @ $results /@ uris;
            TaskWait @ tasks;
            processDocumentationSnippetResults @ $results,
            Verbatim @ text,
            0.5
        ]
    ],
    throwInternalFailure
];

fetchDocumentationSnippets // endDefinition;


fetchDocumentationSnippets0 // beginDefinition;
fetchDocumentationSnippets0 // Attributes = { HoldFirst };

fetchDocumentationSnippets0[ $results_ ] :=
    fetchDocumentationSnippets0[ $results, # ] &;

fetchDocumentationSnippets0[ $results_, uri_String ] := Enclose[
    Module[ { url, setResult, task },
        url = ConfirmBy[ toDocSnippetURL @ uri, StringQ, "URL" ];
        setResult = Function[ $results[ uri ] = <| $results @ uri, # |> ];

        task = URLSubmit[
            url,
            HandlerFunctions -> <|
                "BodyReceived"     -> setResult,
                "ConnectionFailed" -> Function[ $results[ uri ] = <| $results @ uri, # |> ]
            |>,
            HandlerFunctionsKeys -> { "BodyByteArray", "StatusCode", "Headers", "ContentType", "Cookies" }
        ];

        $results[ uri, "URL"  ] = url;
        $results[ uri, "Task" ] = task
    ],
    throwInternalFailure
];

fetchDocumentationSnippets0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toDocSnippetURL*)
toDocSnippetURL // beginDefinition;

toDocSnippetURL[ uri_String ] /; StringStartsQ[ uri, "paclet:" ] :=
    URLBuild @ { $documentationSnippetBaseURL, StringDelete[ uri, StartOfString~~"paclet:" ] <> ".wxf" };

toDocSnippetURL[ uri_String ] :=
    toDocSnippetURL0 @ URLParse[ uri, { "Domain", "Path" } ];

toDocSnippetURL // endDefinition;


toDocSnippetURL0 // beginDefinition;

toDocSnippetURL0[ { "resources.wolframcloud.com", { "", repo_String, "resources", name_String } } ] :=
    URLBuild @ { $resourceSnippetBaseURL, repo, name <> ".wxf" };

toDocSnippetURL0[ { "datarepository.wolframcloud.com", { "", "resources", name_String } } ] :=
    URLBuild @ { $resourceSnippetBaseURL, "DataRepository", name <> ".wxf" };

toDocSnippetURL0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processDocumentationSnippetResults*)
processDocumentationSnippetResults // beginDefinition;
processDocumentationSnippetResults[ results_Association ] := KeyValueMap[ processDocumentationSnippetResult, results ];
processDocumentationSnippetResults // endDefinition;

(* TODO: retry failed results *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processDocumentationSnippetResult*)
processDocumentationSnippetResult // beginDefinition;

processDocumentationSnippetResult[ base_String, as_Association ] :=
    processDocumentationSnippetResult[ base, as, as[ "BodyByteArray" ], as[ "StatusCode" ] ];

processDocumentationSnippetResult[ base_String, as_, bytes_ByteArray, 200 ] :=
    processDocumentationSnippetResult[ base, as, Quiet @ Developer`ReadWXFByteArray @ bytes ];

(* A 401/403 means we're missing a file in the snippet deployment or it has the wrong permissions,
   so it should trigger an internal failure, otherwise just issue a generic cloud download failure. *)
processDocumentationSnippetResult[ base_String, as_Association, bytes_, code: Except[ 401|403 ] ] :=
    throwFailureToChatOutput @ Failure[
        "CloudDownloadError",
        <|
            "MessageTemplate"   :> Chatbook::CloudDownloadError,
            "MessageParameters" -> { },
            KeyTake[ as, { "URL", "StatusCode" } ],
            as
        |>
    ];

processDocumentationSnippetResult[ base_String, as_, data_List ] := Enclose[
    Module[ { combined, keyed, processed, file },
        combined = ConfirmMatch[ makeCombinedSnippet @ data, None -> _Association, "Combined" ];
        keyed = Last @ StringSplit[ ConfirmBy[ #[ "URI" ], StringQ, "URI" ], "#" ] -> # & /@ data;
        processed = ConfirmBy[ Association[ combined, keyed ], AssociationQ, "Processed" ];
        file = ConfirmBy[ snippetCacheFile @ base, StringQ, "File" ];
        ConfirmBy[ GeneralUtilities`EnsureDirectory @ DirectoryName @ file, DirectoryQ, "Directory" ];
        ConfirmBy[ Developer`WriteWXFFile[ file, processed ], FileExistsQ, "Export" ];
        $documentationSnippets[ base ] = processed
    ],
    throwInternalFailure
];

processDocumentationSnippetResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCombinedSnippet*)
makeCombinedSnippet // beginDefinition;
makeCombinedSnippet[ { data_Association, ___ } ] := makeCombinedSnippet @ data;
(* TODO: combined several initial snippets instead of just one *)
makeCombinedSnippet[ data_Association ] := None -> data;
makeCombinedSnippet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cacheDocumentationSnippetResult*)
cacheDocumentationSnippetResult // beginDefinition;

cacheDocumentationSnippetResult[ as_Association ] :=
    cacheDocumentationSnippetResult[ as[ "URI" ], as ];

cacheDocumentationSnippetResult[ uri_String, as_Association ] :=
    uri -> cacheDocumentationSnippetResult[ StringSplit[ uri, "#" ], as ];

cacheDocumentationSnippetResult[ { base_String, fragment: _String|None }, as_Association ] :=
    If[ AssociationQ @ $documentationSnippets[ base ],
        $documentationSnippets[ base, fragment ] = as,
        $documentationSnippets[ base ] = <| fragment -> as |>
    ];

cacheDocumentationSnippetResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
