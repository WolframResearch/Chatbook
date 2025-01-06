(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`DefaultPromptGenerators`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                         ];
Needs[ "Wolfram`Chatbook`Common`"                  ];
Needs[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

HoldComplete[
    System`LLMPromptGenerator
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
Chatbook::InvalidPromptGenerator = "Expected a valid LLMPromptGenerator instead of `1`.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DefaultPromptGenerators*)
$defaultPromptGenerators := $defaultPromptGenerators = <|
    "RelatedDocumentation" -> LLMPromptGenerator[ relatedDocumentationGenerator, "Messages" ],
    "WebSearch"            -> LLMPromptGenerator[ webSearchGenerator           , "Messages" ]
|>;

(* TODO: update RelatedWolframAlphaQueries to support same argument types as RelatedDocumentation *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*webSearchGenerator*)
webSearchGenerator // beginDefinition;

webSearchGenerator[ messages: $$chatMessages ] /; CurrentChatSettings[ "WebSearchRAGMethod" ] === "Tavily" := Enclose[
    Catch @ Module[ { key, string, request, response, data, results, snippets },

        key = SystemCredential[ "TAVILY_API_KEY" ];
        If[ ! StringQ @ key, Throw[ "" ] ];

        string = StringDelete[
            ConfirmBy[ getSmallContextString @ messages, StringQ, "String" ],
            Shortest[ ("/wl"|"/wa") ~~ __ ~~ "ENDRESULT\n" ]
        ];

        If[ StringLength @ string > 200, string = "..." <> StringTake[ string, { -197, -1 } ] ];

        request = HTTPRequest[
            "https://api.tavily.com/search",
            <|
                "Method"      -> "POST",
                "ContentType" -> "application/json",
                "Body"        -> Developer`WriteRawJSONString @ <| "query" -> string, "api_key" -> key |>
            |>
        ];

        response = URLRead @ request;

        If[ response[ "StatusCode" ] =!= 200, Throw[ "" ] ];

        data = Developer`ReadRawJSONString @ ByteArrayToString @ response[ "BodyByteArray" ];
        If[ ! AssociationQ @ data, Throw[ "" ] ];

        results = Select[
            ConfirmMatch[ data[ "results" ], { KeyValuePattern[ "score" -> $$size ]... }, "Results" ],
            #score > 0.1 &
        ];

        If[ results === { }, Throw[ "" ] ];

        snippets = ConfirmMatch[ formatWebSearchResult /@ results, { __String }, "Snippets" ];

        "# Web Search Results\n\n" <> StringRiffle[ snippets, "\n\n======\n\n" ] <> "\n\n======\n\n"
    ],
    throwInternalFailure
];

webSearchGenerator[ messages_ ] :=
    "";

webSearchGenerator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatWebSearchResult*)
formatWebSearchResult // beginDefinition;

formatWebSearchResult[ KeyValuePattern @ {
    "title"   -> title_String,
    "url"     -> url_String,
    "content" -> content_String
} ] := "## [" <> title <> "](" <> url <> ")\n\n" <> content;

formatWebSearchResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relatedDocumentationGenerator*)
relatedDocumentationGenerator // beginDefinition;

relatedDocumentationGenerator[ messages: $$chatMessages ] :=
    If[ TrueQ[ $InlineChat || $WorkspaceChat || $llmKit ],
        setServiceCaller[
            LogChatTiming @ RelatedDocumentation[ messages, "Prompt", MaxItems -> 20, "FilterResults" -> True ],
            "RelatedDocumentation"
        ],
        LogChatTiming @ RelatedDocumentation[ messages, "Prompt", MaxItems -> 5, "FilterResults" -> False ]
    ];

relatedDocumentationGenerator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relatedWolframAlphaQueriesGenerator*)
relatedWolframAlphaQueriesGenerator // beginDefinition;

relatedWolframAlphaQueriesGenerator[ messages: $$chatMessages ] :=
    If[ TrueQ[ $InlineChat || $WorkspaceChat ],
        setServiceCaller[
            LogChatTiming @ RelatedWolframAlphaQueries[ messages, "Prompt", MaxItems -> 20, "FilterResults" -> True ],
            "RelatedWolframAlphaQueries"
        ],
        LogChatTiming @ RelatedWolframAlphaQueries[ messages, "Prompt", MaxItems -> 5, "FilterResults" -> False ]
    ];

relatedWolframAlphaQueriesGenerator // endDefinition;

(* TODO: prompt generator selectors that work like tool selections *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*applyPromptGenerators*)
applyPromptGenerators // beginDefinition;

applyPromptGenerators[ settings_Association, messages_ ] :=
    applyPromptGenerators[ settings, settings[ "PromptGenerators" ], messages ];

applyPromptGenerators[ settings_, generators0_, messages: $$chatMessages ] := Enclose[
    Catch @ Module[ { generators, data, prompts },

        generators = ConfirmMatch[
            LogChatTiming[ toPromptGenerator /@ Flatten @ { generators0 }, "LLMPromptGenerators" ],
            { ___LLMPromptGenerator },
            "Generators"
        ];

        If[ generators === { }, Throw @ { } ];

        data = ConfirmBy[ makePromptGeneratorData[ settings, messages ], AssociationQ, "Data" ];
        prompts = ConfirmMatch[ applyPromptGenerator[ #, data ] & /@ generators, { $$string... }, "Prompts" ];

        DeleteCases[ prompts, "" ]
    ] // LogChatTiming[ "ApplyPromptGenerators" ],
    throwInternalFailure
];

applyPromptGenerators // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toPromptGenerator*)
toPromptGenerator // beginDefinition;
toPromptGenerator[ ___ ] /; $VersionNumber < 14.1 := Nothing;
toPromptGenerator[ name_String ] := toPromptGenerator @ $defaultPromptGenerators @ name;
toPromptGenerator[ generator: HoldPattern[ _LLMPromptGenerator ] ] := generator;
toPromptGenerator[ other_ ] := throwFailure[ "InvalidPromptGenerator", other ];
toPromptGenerator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePromptGeneratorData*)
makePromptGeneratorData // beginDefinition;

(* TODO: build the full spec supported by LLMPromptGenerator:
    * Input
    * Messages
    * LLMEvaluator
    * ChatObject
    * { spec1, spec2, ... }
*)
makePromptGeneratorData[ settings_, messages: { ___, KeyValuePattern[ "Content" -> input_ ] } ] := <|
    "Input"    -> input,
    "Messages" -> messages
|>;

makePromptGeneratorData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyPromptGenerator*)
applyPromptGenerator // beginDefinition;

applyPromptGenerator[ gen: HoldPattern[ _LLMPromptGenerator ], data_Association ] :=
    formatGeneratedPrompt @ LogChatTiming[ gen @ data, "ApplyPromptGenerator" ];

applyPromptGenerator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatGeneratedPrompt*)
formatGeneratedPrompt // beginDefinition;
formatGeneratedPrompt[ string_String ] := string;
formatGeneratedPrompt[ content_List ] := StringJoin[ formatGeneratedPrompt /@ content ];
formatGeneratedPrompt[ KeyValuePattern @ { "Type" -> "Text", "Data" -> data_ } ] := TextString @ data;
formatGeneratedPrompt[ KeyValuePattern @ { "Type" -> "Image", "Data" -> image_? image2DQ } ] := image;
formatGeneratedPrompt[ _Missing | None ] := "";
formatGeneratedPrompt[ expr_ ] := FormatToolResponse @ expr;
formatGeneratedPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
