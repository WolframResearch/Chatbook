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
(*Config*)
$filterDocumentationRAG := TrueQ[ $InlineChat || $WorkspaceChat || $SideBarChat || $llmKit ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
Chatbook::InvalidPromptGenerator = "Expected a valid LLMPromptGenerator instead of `1`.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DefaultPromptGenerators*)
$defaultPromptGenerators := $defaultPromptGenerators = insertPromptGeneratorNames @ <|
    "RelatedDocumentation"       -> LLMPromptGenerator[ relatedDocumentationGenerator      , "Messages" ],
    "RelatedWolframAlphaResults" -> LLMPromptGenerator[ relatedWolframAlphaResultsGenerator, "Messages" ],
    "WebSearch"                  -> LLMPromptGenerator[ webSearchGenerator                 , "Messages" ]
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relatedWolframAlphaResultsGenerator*)
relatedWolframAlphaResultsGenerator // beginDefinition;

relatedWolframAlphaResultsGenerator[ messages: $$chatMessages ] :=
    LogChatTiming @ RelatedWolframAlphaResults[ messages, "Prompt", MaxItems -> 5 ];

relatedWolframAlphaResultsGenerator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*webSearchGenerator*)
webSearchGenerator // beginDefinition;

webSearchGenerator[ messages: $$chatMessages ] := Enclose[
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
    If[ TrueQ @ $filterDocumentationRAG,
        LogChatTiming @ RelatedDocumentation[ messages, "Prompt", MaxItems -> 50, "FilterResults" -> True ],
        LogChatTiming @ RelatedDocumentation[ messages, "Prompt", MaxItems -> 5, "FilterResults" -> False ]
    ];

relatedDocumentationGenerator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relatedWolframAlphaQueriesGenerator*)
relatedWolframAlphaQueriesGenerator // beginDefinition;

relatedWolframAlphaQueriesGenerator[ messages: $$chatMessages ] :=
    LogChatTiming @ RelatedWolframAlphaQueries[ messages, "Prompt" ];

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

applyPromptGenerator[ gen: HoldPattern[ _LLMPromptGenerator ], data_Association ] := Enclose[
    Module[ { settings, name, as, result },
        settings = ConfirmBy[ $CurrentChatSettings, AssociationQ, "Settings" ];
        name = ConfirmMatch[ getPromptGeneratorName @ gen, _String | _Missing, "Name" ];
        as = <| "PromptGenerator" -> gen, "PromptGeneratorData" -> data, "PromptGeneratorName" -> name |>;
        applyHandlerFunction[ settings, "PromptGeneratorStart", as ];
        result = formatGeneratedPrompt @ LogChatTiming[ gen @ data, "ApplyPromptGenerator" ];
        applyHandlerFunction[ settings, "PromptGeneratorEnd", <| as, "PromptGeneratorResult" -> result |> ];
        result
    ],
    throwInternalFailure
];

applyPromptGenerator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getPromptGeneratorName*)
getPromptGeneratorName // beginDefinition;
getPromptGeneratorName[ HoldPattern @ LLMPromptGenerator[ as_, ___ ] ] := getPromptGeneratorName @ as;
getPromptGeneratorName[ gen_Association ] := Lookup[ gen, "Name", Missing[ "NotAvailable" ] ];
getPromptGeneratorName // endDefinition;

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
(* ::Subsection::Closed:: *)
(*insertPromptGeneratorNames*)
insertPromptGeneratorNames // beginDefinition;

insertPromptGeneratorNames[ generators_Association ] :=
    Association @ KeyValueMap[ #1 -> insertPromptGeneratorNames[ #1, #2 ] &, generators ];

insertPromptGeneratorNames[ name_String, HoldPattern @ LLMPromptGenerator[ as_Association, a___ ] ] :=
    LLMPromptGenerator[ <| as, "Name" -> name |>, a ];

insertPromptGeneratorNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
