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
$snippetType                 = "Text";
$documentationSnippetVersion = "14-1-0-10549042";
$baseURL                     = "https://www.wolframcloud.com/obj/wolframai-content/DocumentationSnippets";
$documentationSnippetBaseURL = URLBuild @ { $baseURL, $documentationSnippetVersion, $snippetType };
$resourceSnippetBaseURL      = URLBuild @ { $baseURL, "Resources", $snippetType };

$documentationSnippetsCacheDirectory := $documentationSnippetsCacheDirectory =
    ChatbookFilesDirectory @ { "DocumentationSnippets", "Documentation", $documentationSnippetVersion };

$resourceSnippetsCacheDirectory := $resourceSnippetsCacheDirectory =
    ChatbookFilesDirectory @ { "DocumentationSnippets", "ResourceSystem" };

$rerankMethod := CurrentChatSettings[ "DocumentationRerankMethod" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
Chatbook::CloudDownloadError = "Unable to download required data from the cloud. Please try again later.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedDocumentation*)
RelatedDocumentation // beginDefinition;
RelatedDocumentation // Options = {
    "FilteredCount" -> Automatic,
    "FilterResults" -> Automatic,
    "MaxItems"      -> 20
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
    catchMine @ RelatedDocumentation[ prompt, property, OptionValue @ MaxItems, opts ];

RelatedDocumentation[ prompt_, Automatic, count_, opts: OptionsPattern[ ] ] :=
    RelatedDocumentation[ prompt, "URIs", count, opts ];

RelatedDocumentation[ prompt: $$prompt, "URIs", Automatic, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    (* TODO: filter results *)
    ConfirmMatch[ vectorDBSearch[ "DocumentationURIs", prompt, "Values" ], { ___String }, "Queries" ],
    throwInternalFailure
];

RelatedDocumentation[ All, "URIs", Automatic, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    (* TODO: filter results *)
    Union @ ConfirmMatch[ vectorDBSearch[ "DocumentationURIs", All ], { __String }, "QueryList" ],
    throwInternalFailure
];

RelatedDocumentation[ prompt: $$prompt, "Snippets", Automatic, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    ConfirmMatch[
        (* TODO: filter results *)
        DeleteMissing[ makeDocSnippets @ vectorDBSearch[ "DocumentationURIs", prompt, "Values" ] ],
        { ___String },
        "Snippets"
    ],
    throwInternalFailure
];

RelatedDocumentation[ prompt_, property_, UpTo[ n_Integer ], opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedDocumentation[ prompt, property, n, opts ];

RelatedDocumentation[ prompt_, property_, n_Integer, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    Take[ ConfirmMatch[ RelatedDocumentation[ prompt, property, Automatic, opts ], { ___String } ], UpTo @ n ],
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
        Take[ ConfirmBy[ vectorDBSearch[ "DocumentationURIs", prompt, property ], ListQ, "Results" ], UpTo @ n ],
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
    catchMine @ relatedDocumentationPrompt[
        ensureChatMessages @ prompt,
        n,
        MatchQ[ OptionValue[ "FilterResults" ], Automatic|True ],
        Replace[ OptionValue[ "FilteredCount" ], Automatic -> Ceiling[ n / 4 ] ]
    ];

RelatedDocumentation[ args___ ] := catchMine @ throwFailure[
    "InvalidArguments",
    RelatedDocumentation,
    HoldForm @ RelatedDocumentation @ args
];

RelatedDocumentation // endDefinition;

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
    Catch @ Module[ { uris, filtered, string },

        uris = ConfirmMatch[
            RelatedDocumentation[ messages, "URIs", count ],
            { ___String },
             "URIs"
        ] // LogChatTiming[ "RelatedDocumentationURIs" ] // withApproximateProgress[ "CheckingDocumentation", 0.2 ];

        If[ uris === { }, Throw[ "" ] ];

        filtered = ConfirmMatch[
            filterSnippets[ messages, uris, filter, filterCount ] // LogChatTiming[ "FilterSnippets" ],
            { ___String },
            "Filtered"
        ];

        string = StringTrim @ StringRiffle[ "# "<># & /@ DeleteCases[ filtered, "" ], "\n\n======\n\n" ];

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
"IMPORTANT: Here are some Wolfram documentation snippets that were retrieved based on semantic similarity to the \
current context. Please use them if they can help answer the user's latest message.\n\n";

$relatedDocsStringUnfilteredHeader =
"Here are some Wolfram documentation snippets that you may find useful.\n\n";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*filterSnippets*)
filterSnippets // beginDefinition;


filterSnippets[ messages_, uris: { __String }, Except[ True ], filterCount_ ] := Enclose[
    ConfirmMatch[ makeDocSnippets @ uris, { ___String }, "Snippets" ],
    throwInternalFailure
];


filterSnippets[
    messages_,
    uris: { __String },
    True,
    filterCount_Integer? Positive
] /; $rerankMethod === "rerank-english-v3.0" (* EXPERIMENTAL *) := Enclose[
    Catch @ Module[ { snippets, inserted, transcript, instructions, resp, results, idx, ranked },

        snippets = ConfirmMatch[ makeDocSnippets @ uris, { ___String }, "Snippets" ];
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

        results = ConfirmMatch[ resp[ "results" ], { __Association }, "Results" ];

        idx = ConfirmMatch[
            Select[ results, #[ "relevance_score" ] > 0.01 & ][[ All, "index" ]] + 1,
            { ___Integer },
            "Indices"
        ];

        ranked = ConfirmMatch[ snippets[[ idx ]], { ___String }, "Ranked" ];

        Take[ ranked, UpTo[ filterCount ] ]
    ],
    throwInternalFailure
];


filterSnippets[ messages_, uris: { __String }, True, filterCount_Integer? Positive ] := Enclose[
    Catch @ Module[ { snippets, inserted, transcript, xml, instructions, response, pages },

        snippets = ConfirmMatch[ makeDocSnippets @ uris, { ___String }, "Snippets" ];
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
                llmSynthesize[ instructions, <| "StopTokens" -> "\"CasualChat\"" |> ],
                "WaitForFilterSnippetsTask"
            ] // withApproximateProgress[ 0.5 ],
            StringQ,
            "Response"
        ];

        pages = ConfirmMatch[ makeDocSnippets @ selectSnippetsFromJSON[ response, uris ], { ___String }, "Pages" ];

        pages
    ],
    throwInternalFailure
];


filterSnippets // endDefinition;



$bestDocumentationPrompt = StringTemplate[ "\
Your task is to read a chat transcript between a user and assistant, and then select any relevant Wolfram Language \
documentation snippets that could help the assistant answer the user's latest message.

Each snippet is uniquely identified by a URI (always starts with 'paclet:' or 'https://resources.wolframcloud.com').

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
(*selectSnippetsFromJSON*)
selectSnippetsFromJSON // beginDefinition;

selectSnippetsFromJSON[ response_String, uris_List ] := Enclose[
    Catch @ Module[ { jsonString, jsonData, selected },
        jsonString = ConfirmBy[ First[ StringCases[ response, Longest[ "{" ~~ __ ~~ "}" ], 1 ], None ], StringQ ];
        jsonData = ConfirmBy[ Quiet @ Developer`ReadRawJSONString @ jsonString, AssociationQ ];
        selected = ConfirmMatch[ Select[ jsonData[ "Snippets" ], #[ "Score" ] >= 3 & ], { __ } ];
        ConfirmMatch[
            Intersection[ Cases[ selected, KeyValuePattern[ "URI" -> uri_String ] :> StringTrim @ uri ], uris ],
            { __String }
        ]
    ],
    selectSnippetsFromString[ response, uris ] &
];

selectSnippetsFromJSON // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*selectSnippetsFromString*)
selectSnippetsFromString // beginDefinition;
selectSnippetsFromString[ response_String, uris: { ___String } ] := StringCases[ response, uris ];
selectSnippetsFromString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*snippetXML*)
snippetXML // beginDefinition;
snippetXML[ snippet_String ] := "<snippet>\n" <> snippet <> "\n</snippet>";
snippetXML // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Documentation Snippets*)
$documentationSnippets = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeDocSnippets*)
makeDocSnippets // beginDefinition;

makeDocSnippets[ uris0: { ___String } ] := Enclose[
    Module[ { uris, data, snippets, strings },
        uris = DeleteDuplicates @ uris0;
        data = ConfirmBy[ getDocumentationSnippetData @ uris, AssociationQ, "Data" ];
        snippets = ConfirmMatch[ Values @ data, { ___Association }, "Snippets" ];
        strings = ConfirmMatch[ Lookup[ "String" ] /@ snippets, { ___String }, "Strings" ];
        strings
    ],
    throwInternalFailure
];

makeDocSnippets[ uri_String ] :=
    First @ makeDocSnippets @ { uri };

makeDocSnippets // endDefinition;

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

        text = ConfirmBy[
            If[ count === 1,
                trStringTemplate[ "ProgressTextDownloadingSnippet" ][ count ],
                trStringTemplate[ "ProgressTextDownloadingSnippets" ][ count ]
            ],
            StringQ,
            "Text"
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

processDocumentationSnippetResult[ base_String, as_Association, bytes_, code: Except[ 200, _Integer ] ] :=
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
