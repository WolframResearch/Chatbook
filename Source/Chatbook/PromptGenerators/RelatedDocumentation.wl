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

$snippetsCacheDirectory := $snippetsCacheDirectory = FileNameJoin @ {
    ExpandFileName @ LocalObject @ $LocalBase,
    "Chatbook/DocumentationSnippets"
};

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

        uris = ConfirmMatch[
            RelatedDocumentation[ messages, "URIs", count ],
            { ___String },
             "URIs"
        ] // LogChatTiming[ "RelatedDocumentationURIs" ];

        If[ uris === { }, Throw[ "" ] ];

        filtered = ConfirmMatch[
            filterSnippets[ messages, uris, filter ] // LogChatTiming[ "FilterSnippets" ],
            { ___String },
            "Filtered"
        ];

        string = StringTrim @ StringRiffle[ "# "<># & /@ DeleteCases[ filtered, "" ], "\n\n======\n\n" ];

        If[ string === "",
            "",
            $relatedDocsStringHeader <> string
        ]
    ],
    throwInternalFailure
];

relatedDocumentationPrompt // endDefinition;


$relatedDocsStringHeader = "\
IMPORTANT: Here are some Wolfram documentation snippets that you should use to respond.

";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*filterSnippets*)
filterSnippets // beginDefinition;

filterSnippets[ messages_, uris: { __String }, filter_ ] := Enclose[
    Catch @ Module[ { snippets, inserted, transcript, xml, instructions, response, pages },

        snippets = ConfirmMatch[ makeDocSnippets @ uris, { ___String }, "Snippets" ];
        If[ ! TrueQ @ filter, Throw @ snippets ];

        inserted = insertContextPrompt @ messages;
        transcript = ConfirmBy[ getSmallContextString @ inserted, StringQ, "Transcript" ];

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
        file = ConfirmBy[ FileNameJoin @ { $snippetsCacheDirectory, name, path }, StringQ, "File" ];
        snippetCacheFile[ uri ] = file
    ],
    throwInternalFailure
];

snippetCacheFile // endDefinition;

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
