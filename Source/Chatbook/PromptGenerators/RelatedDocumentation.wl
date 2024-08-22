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

RelatedDocumentation[ prompt_ ] := catchMine @ RelatedDocumentation[ prompt, Automatic ];
RelatedDocumentation[ prompt_, Automatic ] := catchMine @ RelatedDocumentation[ prompt, "URIs" ];
RelatedDocumentation[ prompt_, count: _Integer | UpTo[ _Integer ] ] := RelatedDocumentation[ prompt, Automatic, count ];
RelatedDocumentation[ prompt_, property_ ] := catchMine @ RelatedDocumentation[ prompt, property, Automatic ];
RelatedDocumentation[ prompt_, Automatic, count_ ] := RelatedDocumentation[ prompt, "URIs", count ];

RelatedDocumentation[ prompt: _String | { ___String }, "URIs", Automatic ] := catchMine @ Enclose[
    ConfirmMatch[ vectorDBSearch[ "DocumentationURIs", prompt, "Values" ], { ___String }, "Queries" ],
    throwInternalFailure
];

RelatedDocumentation[ All, "URIs", Automatic ] := catchMine @ Enclose[
    Union @ ConfirmMatch[ vectorDBSearch[ "DocumentationURIs", All ], { __String }, "QueryList" ],
    throwInternalFailure
];

RelatedDocumentation[ prompt_, "Snippets", Automatic ] := catchMine @ Enclose[
    ConfirmMatch[
        DeleteMissing[ makeDocSnippets @ vectorDBSearch[ "DocumentationURIs", prompt, "Values" ] ],
        { ___String },
        "Snippets"
    ],
    throwInternalFailure
];

RelatedDocumentation[ prompt_, property_, UpTo[ n_Integer ] ] :=
    catchMine @ RelatedDocumentation[ prompt, property, n ];

RelatedDocumentation[ prompt_, property_, n_Integer ] := catchMine @ Enclose[
    Take[ ConfirmMatch[ RelatedDocumentation[ prompt, property, Automatic ], { ___String } ], UpTo @ n ],
    throwInternalFailure
];

RelatedDocumentation[ prompt_, property: "Results"|"Values"|"EmbeddingVector"|All, n_Integer ] := catchMine @ Enclose[
    Take[ ConfirmBy[ vectorDBSearch[ "DocumentationURIs", prompt, property ], ListQ, "Results" ], UpTo @ n ],
    throwInternalFailure
];

RelatedDocumentation[ prompt_, property: "Index"|"Distance", n_Integer ] := catchMine @ Enclose[
    Lookup[
        Take[
            ConfirmMatch[
                RelatedDocumentation[ prompt, "Results", n ],
                { KeyValuePattern[ property -> _ ]... },
                "Results"
            ],
            UpTo @ n
        ],
        property
    ],
    throwInternalFailure
];

RelatedDocumentation[ args___ ] := catchMine @ throwFailure[
    "InvalidArguments",
    RelatedDocumentation,
    HoldForm @ RelatedDocumentation @ args
];

RelatedDocumentation // endDefinition;

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
    ],
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
