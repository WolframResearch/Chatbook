(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                         ];
Needs[ "Wolfram`Chatbook`Common`"                  ];
Needs[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

(* TODO: move selectBestDocumentationPages to this file and implement via filtering option for RelatedDocumentation *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$documentationSnippetBaseURL = "https://www.wolframcloud.com/obj/wolframai-content/DocumentationSnippets/Text";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedDocumentation*)
RelatedDocumentation // beginDefinition;
RelatedDocumentation // Options = {
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
        MatchQ[ OptionValue[ "FilterResults" ], Automatic|True ]
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

relatedDocumentationPrompt[ messages: $$chatMessages, count_, filter_ ] := Enclose[
    Catch @ Module[ { uris, filtered, string },
        uris = ConfirmMatch[ RelatedDocumentation[ messages, "URIs", count ], { ___String }, "URIs" ];
        If[ uris === { }, Throw[ "" ] ];

        filtered = ConfirmMatch[ filterSnippets[ messages, uris, filter ], { ___String }, "Filtered" ];
        string = StringTrim @ StringRiffle[ "# "<># & /@ DeleteCases[ filtered, "" ], "\n\n======\n\n" ];
        $relatedDocsStringHeader <> string
    ],
    throwInternalFailure
];

relatedDocumentationPrompt // endDefinition;


$relatedDocsStringHeader = "\
Here are some Wolfram documentation snippets that might be helpful:

";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*filterSnippets*)
filterSnippets // beginDefinition;

filterSnippets[ messages_, uris: { __String }, filter_ ] := Enclose[
    Catch @ Module[ { snippets, transcript, xml, instructions, response, pages },

        snippets = ConfirmMatch[ makeDocSnippets @ uris, { ___String }, "Snippets" ];
        If[ ! TrueQ @ filter, Throw @ snippets ];

        transcript = ConfirmBy[ getSmallContextString @ insertContextPrompt @ messages, StringQ, "Transcript" ];

        xml = ConfirmMatch[ snippetXML /@ snippets, { __String }, "XML" ];
        instructions = ConfirmBy[
            TemplateApply[
                $bestDocumentationPrompt,
                <| "Snippets" -> StringRiffle[ xml, "\n\n" ], "Transcript" -> transcript |>
            ],
            StringQ,
            "Prompt"
        ];

        response = StringTrim @ ConfirmBy[ llmSynthesize @ instructions, StringQ, "Response" ];
        pages = ConfirmMatch[ makeDocSnippets @ StringCases[ response, uris ], { ___String }, "Pages" ];

        pages
    ],
    throwInternalFailure
];

filterSnippets // endDefinition;


$bestDocumentationPrompt = StringTemplate[ "\
Your task is to read a chat transcript between a user and assistant, and then select the most relevant \
Wolfram Language documentation snippets that could help the assistant answer the user's latest message. \
Each snippet is uniquely identified by a URI (always starts with 'paclet:' or 'https://resources.wolframcloud.com').

Choose up to 5 documentation snippets that would help answer the user's MOST RECENT message. \
Respond only with the corresponding URIs of the snippets and nothing else. \
If there are no relevant pages, respond with just the string \"none\".

Here is the chat transcript:

<transcript>
%%Transcript%%
</transcript>

Here are the available documentation snippets to choose from:

<snippets>
%%Snippets%%
</snippets>

Reminder: Choose up to 5 documentation snippets that would help answer the user's MOST RECENT message. \
Respond only with the corresponding URIs of the snippets and nothing else. \
If there are no relevant pages, respond with just the string \"none\".\
", Delimiters -> "%%" ];

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

        fetchDocumentationSnippets @ missing;

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
getCachedDocumentationSnippet[ { base_String, fragment_ } ] := $documentationSnippets[ base, fragment ];
getCachedDocumentationSnippet // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*fetchDocumentationSnippets*)
fetchDocumentationSnippets // beginDefinition;

fetchDocumentationSnippets[ { } ] := { };

fetchDocumentationSnippets[ uris: { __String } ] :=
    Module[ { $results, tasks },
        $results = AssociationMap[ <| "URI" -> #1 |> &, uris ];
        tasks = fetchDocumentationSnippets0 @ $results /@ uris;
        TaskWait @ tasks;
        processDocumentationSnippetResults @ $results
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
    URLBuild @ { $documentationSnippetBaseURL, "Resources", repo, name <> ".wxf" };

toDocSnippetURL0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processDocumentationSnippetResults*)
processDocumentationSnippetResults // beginDefinition;
processDocumentationSnippetResults[ results_Association ] := processDocumentationSnippetResult /@ results;
processDocumentationSnippetResults // endDefinition;

(* TODO: retry failed results *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processDocumentationSnippetResult*)
processDocumentationSnippetResult // beginDefinition;

processDocumentationSnippetResult[ as_Association ] :=
    processDocumentationSnippetResult[ as, as[ "BodyByteArray" ], as[ "StatusCode" ] ];

processDocumentationSnippetResult[ as_, bytes_ByteArray, 200 ] :=
    processDocumentationSnippetResult[ as, Quiet @ Developer`ReadWXFByteArray @ bytes ];

processDocumentationSnippetResult[ as_, data_List ] :=
    Association[
        makeCombinedSnippet @ data,
        cacheDocumentationSnippetResult /@ data
    ];

processDocumentationSnippetResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeCombinedSnippet*)
makeCombinedSnippet // beginDefinition;

makeCombinedSnippet[ { data_Association, ___ } ] := makeCombinedSnippet @ data;

makeCombinedSnippet[ data_Association ] := Enclose[
    Module[ { uri, base },
        uri = ConfirmBy[ data[ "URI" ], StringQ, "URI" ];
        base = ConfirmBy[ First @ StringSplit[ uri, "#" ], StringQ, "Base" ];
        cacheDocumentationSnippetResult[ { base, None }, data ]
    ],
    throwInternalFailure
];

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
