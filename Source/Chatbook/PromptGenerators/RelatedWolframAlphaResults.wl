(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`RelatedWolframAlphaResults`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                         ];
Needs[ "Wolfram`Chatbook`PromptGenerators`Common`" ];
Needs[ "Wolfram`Chatbook`Common`"                  ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$maxItems            = 5;
$largeResponseLength = 500;
$largeQueryLength   = 100;
$stopTokens         = { "[NONE]", "[WL]" };
$defaultConfig      = <| "StopTokens" -> $stopTokens, "Model" -> <| "Name" -> "gpt-4o-mini" |>, "MaxTokens" -> 250 |>;
$generatorLLMConfig = $defaultConfig;
$usePromptHeader    = True;
$multimodal         = True;
$keepAllImages      = False;
$wolframAlphaAppID  = None;
$instructions       = None;
$reinterpret        = False;
$showSteps          = True;
$includeWLResults  := TrueQ @ toolSelectedQ[ "WolframLanguageEvaluator" ];

$timeouts = <|
    "URLSubmit"   -> 25,
    "TaskWait"    -> 30,
    "AlphaScan"   -> 5,
    "AlphaPod"    -> 4,
    "AlphaFormat" -> 8,
    "AlphaParse"  -> 5,
    "AlphaTotal"  -> 20
|>;

$podStates := If[ TrueQ @ $showSteps,
                  Flatten @ { "Step-by-step solution", "Show all steps", ConstantArray[ "Result__More", 3 ] },
                  ConstantArray[ "Result__More", 3 ]
              ];

$formats := If[ TrueQ @ $includeWLResults,
                { "image", "plaintext", "minput" },
                { "image", "plaintext" }
            ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$$stringOrStrings = $$string | { $$string... };
$$count           = _Integer | UpTo[ _Integer ];
$$xml             = HoldPattern[ _XMLElement | XMLObject[ _ ][ ___ ] ];

(* cSpell: disable *)
$$ignoredXMLTag = Alternatives[
    "datasources",
    "definitions",
    "downloadformatgroups",
    "expressiontypes",
    "imagesource",
    "infos",
    "microsources",
    "notes",
    "relatedqueries", (* TODO: this could be included in the result prompt *)
    "sources",
    "states",
    "stepbystepcontenttype",
    "userinfoused"
];
(* cSpell: enable *)

$$ws = ___String? (StringMatchQ[ WhitespaceCharacter... ]);

$emptyResponses = Flatten @ {
    "",
    "[n]",
    "[n/a]",
    "[na]",
    "[none]",
    $stopTokens
};

$$emptyResponse = _String? (StringMatchQ[ $emptyResponses, IgnoreCase -> True ]);

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
Chatbook::UnhandledWolframAlphaXMLTag = "Unhandled Wolfram Alpha XML tag: ``";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedWolframAlphaResults*)
RelatedWolframAlphaResults // beginDefinition;
RelatedWolframAlphaResults // Options = {
    "AppID"             -> Automatic,
    "CacheResults"      -> False,
    "Debug"             -> False,
    "IncludeWLResults"  -> Automatic,
    "Instructions"      -> None,
    "LLMEvaluator"      -> Automatic,
    "MaxItems"          -> Automatic,
    "PromptHeader"      -> Automatic,
    "RandomQueryCount"  -> Automatic,
    "Reinterpret"       -> False,
    "RelatedQueryCount" -> Automatic,
    "SampleQueryCount"  -> Automatic
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Usage*)
GeneralUtilities`SetUsage[ RelatedWolframAlphaResults, "\
RelatedWolframAlphaResults[\"string$\"] gives a list of Wolfram|Alpha results that are semantically related to the \
conversational-style question specified by \"string$\"." ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Default Arguments*)
RelatedWolframAlphaResults[ prompt_, opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedWolframAlphaResults[ prompt, Automatic, opts ];

RelatedWolframAlphaResults[ prompt_, count: $$count, opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedWolframAlphaResults[ prompt, Automatic, count, opts ];

RelatedWolframAlphaResults[ prompt_, property_, opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedWolframAlphaResults[ prompt, property, Automatic, opts ];

RelatedWolframAlphaResults[ prompt_, property_, UpTo[ n_Integer ], opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedWolframAlphaResults[ prompt, property, n, opts ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Resolve Automatic Arguments*)
RelatedWolframAlphaResults[ prompt_, Automatic, count_, opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedWolframAlphaResults[ prompt, "Prompt", count, opts ];

RelatedWolframAlphaResults[ prompt_, property_, Automatic, opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedWolframAlphaResults[
        prompt,
        property,
        Replace[ OptionValue[ "MaxItems" ], $$unspecified :> $maxItems ],
        opts
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Main Definition*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Prompt*)
RelatedWolframAlphaResults[ prompt_, "Prompt", n_Integer, opts: OptionsPattern[ ] ] :=
    catchMine @ withChatState @ Block[
        {
            $cacheResults       = TrueQ @ OptionValue[ "CacheResults" ],
            $wolframAlphaDebug  = TrueQ @ OptionValue[ "Debug" ],
            $wolframAlphaAppID  = Replace[ OptionValue[ "AppID" ], $$unspecified :> $wolframAlphaAppID ],
            $generatorLLMConfig = Replace[ OptionValue[ "LLMEvaluator" ], $$unspecified :> $generatorLLMConfig ],
            $usePromptHeader    = Replace[ OptionValue[ "PromptHeader" ], $$unspecified :> $usePromptHeader ],
            $includeWLResults   = Replace[ OptionValue[ "IncludeWLResults" ], $$unspecified :> $includeWLResults ],
            $instructions       = OptionValue[ "Instructions" ],
            $maxItems           = n,
            $sampleQueries      = None,
            $sampleQueryCount   = Replace[ OptionValue[ "SampleQueryCount" ], $$unspecified|None :> 0 ],
            $reinterpret        = Replace[ OptionValue[ "Reinterpret" ], $$unspecified :> $reinterpret ]
        },
        relatedWolframAlphaResultsPrompt[
            ensureChatMessages @ prompt,
            n,
            Replace[ OptionValue[ "RelatedQueryCount" ], $$unspecified :> Min[ 20, $maxItems*4 ] ],
            Replace[ OptionValue[ "RandomQueryCount"  ], $$unspecified :> Min[ 20, $maxItems*4 ] ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Content*)
RelatedWolframAlphaResults[ prompt_, "Content", n_Integer, opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    Lookup[
        ConfirmMatch[
            RelatedWolframAlphaResults[ prompt, "FullData", n, opts ],
            KeyValuePattern[ "Content" -> { ___Association } ],
            "Content"
        ],
        "Content"
    ],
    throwInternalFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*FullData*)
RelatedWolframAlphaResults[ prompt_, "FullData", n_Integer, opts: OptionsPattern[ ] ] :=
    catchMine @ withChatState @ Block[
        {
            $cacheResults       = TrueQ @ OptionValue[ "CacheResults" ],
            $wolframAlphaDebug  = TrueQ @ OptionValue[ "Debug" ],
            $wolframAlphaAppID  = Replace[ OptionValue[ "AppID" ], $$unspecified :> $wolframAlphaAppID ],
            $generatorLLMConfig = Replace[ OptionValue[ "LLMEvaluator" ], $$unspecified :> $generatorLLMConfig ],
            $usePromptHeader    = Replace[ OptionValue[ "PromptHeader" ], $$unspecified :> $usePromptHeader ],
            $includeWLResults   = Replace[ OptionValue[ "IncludeWLResults" ], $$unspecified :> $includeWLResults ],
            $instructions       = OptionValue[ "Instructions" ],
            $maxItems           = n,
            $sampleQueries      = None,
            $sampleQueryCount   = Replace[ OptionValue[ "SampleQueryCount" ], $$unspecified|None :> All ],
            $reinterpret        = Replace[ OptionValue[ "Reinterpret" ], $$unspecified :> $reinterpret ]
        },
        relatedWolframAlphaResultsFullData[
            ensureChatMessages @ prompt,
            n,
            Replace[ OptionValue[ "RelatedQueryCount" ], $$unspecified :> Min[ 20, $maxItems*4 ] ],
            Replace[ OptionValue[ "RandomQueryCount"  ], $$unspecified :> Min[ 20, $maxItems*4 ] ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*End Definition*)
RelatedWolframAlphaResults // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompts*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$promptTemplate*)
(* TODO: explain the transcript *)
$promptTemplate := If[ TrueQ @ usingDocumentationQ[ ], $promptTemplateWithWL, $promptTemplateNoWL ];

$promptTemplateNoWL = StringTemplate[ "\
Your task is to write Wolfram Alpha queries that could help provide relevant info needed to answer a user's prompt.

Here are some examples of valid Wolfram Alpha queries to give you a sense of what kinds of things it can handle:
<examples>
`Examples`
</examples>

Reply with up to `MaxItems` queries each on a separate line and nothing else. \
Reply with [NONE] if the user's prompt is completely unrelated to anything computational or knowledge-based, \
e.g. casual conversation.

`Instructions`" ];

$promptTemplateWithWL = StringTemplate[ "\
Your task is to write Wolfram Alpha queries that could help provide relevant info needed to answer a user's prompt.

Here are some examples of valid Wolfram Alpha queries to give you a sense of what kinds of things it can handle:
<examples>
`Examples`
</examples>

Reply with up to `MaxItems` queries each on a separate line and nothing else. \
Reply with [NONE] if the user's prompt is completely unrelated to anything computational or knowledge-based, \
e.g. casual conversation.
Reply with [WL] if the user's prompt would be better answered with Wolfram Language documentation instead.

`Instructions`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$queryReminder*)
$queryReminder = "\
Reminder: You should respond ONLY with Wolfram Alpha queries and nothing else. \
Do not attempt to respond to the user's query directly.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$resultsPromptHeader*)
$resultsPromptHeader = "\
IMPORTANT: The following information was automatically generated using Wolfram Alpha \
and should be used to help answer the user's query using factual information.

======

";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$citationHint*)
$citationHint := If[ TrueQ @ $ChatHandlerData[ "ChatNotebookSettings", "AppendCitations" ], "", $citationHint0 ];

$citationHint0 = "

If you use any information from these results, you should cite the relevant URL with a markdown link in your response.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$markdownHint*)
$markdownHint := "

======

You can use any markdown links from these results in your response to show images, \
formatted expressions, etc. to the user." <> $citationHint;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$wolframAlphaResultTemplate*)
$wolframAlphaResultTemplate = StringTemplate[ "\
<result query='`1`' url='`2`'>

`3`

</result>" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$fewShotExamples*)
$fewShotExamples := makeMessagePairs @ {
    {
        "What has more people, LA or Osaka?",
        {
            "population of Los Angeles, California",
            "population of Osaka, Japan",
            "populations of Osaka, Japan and Los Angeles, California",
            "Osaka, Japan",
            "Los Angeles, California"
        }
    },
    {
        "Hello",
        None
    },
    {
        (* cSpell: ignore pokeman *)
        "What's the biggest pokeman?",
        { "largest Pok\[EAcute]mon by height", "largest Pok\[EAcute]mon by weight", "biggest Pok\[EAcute]mon" }
    },
    {
        "tell me some neat facts about NYC",
        { "New York City, New York" }
    },
    {
        "How can I split a list into triples but allow fewer items at the end?",
        Missing[ "WolframLanguage" ]
    },
    {
        "Show me a picture of a cat",
        { "picture of a cat", "domestic cat" }
    }
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeMessagePairs*)
makeMessagePairs // beginDefinition;

makeMessagePairs[ { input_String, outputs_ } ] :=
    makeMessagePairs[ input, outputs ];

makeMessagePairs[ input_String, outputs: { __String } ] := Flatten @ {
    <| "Role" -> "User"     , "Content" -> input |>,
    <| "Role" -> "Assistant", "Content" -> StringRiffle[ Take[ outputs, UpTo @ $maxItems ], "\n" ] |>
};

makeMessagePairs[ input_String, None ] := Flatten @ {
    <| "Role" -> "User"     , "Content" -> input    |>,
    <| "Role" -> "Assistant", "Content" -> "[NONE]" |>
};

makeMessagePairs[ input_String, Missing[ "WolframLanguage" ] ] :=
    If[ TrueQ @ usingDocumentationQ[ ],
        Flatten @ {
            <| "Role" -> "User"     , "Content" -> input |>,
            <| "Role" -> "Assistant", "Content" -> "[WL]" |>
        },
        { }
    ];

makeMessagePairs[ pairs_List ] :=
    Flatten[ makeMessagePairs /@ pairs ];

makeMessagePairs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*usingDocumentationQ*)
usingDocumentationQ // beginDefinition;
usingDocumentationQ[ ] := usingDocumentationQ @ $ChatHandlerData[ "ChatNotebookSettings", "PromptGenerators" ];
usingDocumentationQ[ generators_List ] := AnyTrue[ generators, usingDocumentationQ ];
usingDocumentationQ[ HoldPattern @ LLMPromptGenerator[ as_, ___ ] ] := usingDocumentationQ @ as;
usingDocumentationQ[ KeyValuePattern[ "Name" -> name_String ] ] := usingDocumentationQ @ name;
usingDocumentationQ[ "RelatedDocumentation" ] := True;
usingDocumentationQ[ _ ] := False;
usingDocumentationQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Supporting Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relatedWolframAlphaResultsPrompt*)
relatedWolframAlphaResultsPrompt // beginDefinition;

relatedWolframAlphaResultsPrompt[
    messages: $$chatMessages,
    count_,
    relatedCount_,
    randomCount_
] := Enclose[
    Catch @ Module[
        { contentAndQueries, content, queries, strings, sourceURLs, sourceStrings, resultsString, sampleString },

        contentAndQueries = ConfirmMatch[
            relatedWolframAlphaResultsFullData[ messages, count, relatedCount, randomCount ],
            KeyValuePattern @ { "Content" -> { ___Association }, "SampleQueries" -> { ___String } },
            "FullData"
        ];

        content = contentAndQueries[ "Content"       ];
        queries = contentAndQueries[ "SampleQueries" ];

        If[ content === { }, Throw[ "" ] ];

        addHandlerArguments[ "RelatedWolframAlphaResults" -> <| "Content" -> content |> ];

        strings = ConfirmMatch[ formatWolframAlphaResult /@ content, { __String }, "Strings" ];

        sourceURLs = ConfirmMatch[ content[[ All, "URL" ]], { ___String }, "SourceURLs" ];
        sourceStrings = ConfirmMatch[
            StringTrim @ StringReplace[
                strings,
                {
                    "<result query=" ~~ query: Except[ "\n" ].. ~~ " url=" ~~ Except[ "\n" ].. ~~ ">" :>
                        "# Query\n\n" <> StringTrim[ query, "'"|"\"" ],
                    "</result>" -> ""
                }
            ],
            { ___String },
            "SourceStrings"
        ];

        ConfirmAssert[ Length @ sourceURLs === Length @ sourceStrings, "SourceLengthCheck" ];

        KeyValueMap[
            AddToSources,
            Select[ AssociationThread[ sourceURLs -> sourceStrings ], ! StringEndsQ[ #, "No Results Found" ] & ]
        ];

        resultsString = StringRiffle[ strings, "\n\n" ];
        sampleString  = ConfirmBy[ createSampleQueryPrompt[ queries, $sampleQueryCount ], StringQ, "Sample" ];

        StringJoin[
            ConfirmBy[ $resultsPromptHeader, StringQ, "Header" ],
            resultsString,
            If[ StringContainsQ[ resultsString, "![" ~~ __ ~~ "](" ~~ __ ~~ ")" ],
                ConfirmBy[ $markdownHint, StringQ, "MarkdownHint" ],
                ConfirmBy[ $citationHint, StringQ, "CitationHint" ]
            ],
            sampleString
        ]
    ],
    throwInternalFailure
];

relatedWolframAlphaResultsPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createSampleQueryPrompt*)
createSampleQueryPrompt // beginDefinition;

createSampleQueryPrompt[ queries_, 0 | Automatic ] := "";

createSampleQueryPrompt[ queries: { __String }, count_? Positive ] := Enclose[
    ConfirmBy[
        $sampleQueriesHeader <> StringRiffle[ Take[ queries, UpTo[ count ] ], "\n" ],
        StringQ,
        "SampleQueryPrompt"
    ],
    throwInternalFailure
];

createSampleQueryPrompt[ queries_, UpTo[ count_ ] ] :=
    createSampleQueryPrompt[ queries, count ];

createSampleQueryPrompt[ queries_, All ] :=
    createSampleQueryPrompt[ queries, Infinity ];

createSampleQueryPrompt // endDefinition;


$sampleQueriesHeader = "

Here are some additional valid Wolfram|Alpha queries to demonstrate what kinds of queries it can accept:

";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateSuggestedQueries*)
generateSuggestedQueries // beginDefinition;

generateSuggestedQueries[ prompt_, count_Integer, relatedCount_Integer, randomCount_Integer ] := Enclose[
    Module[
        {
            relevant, all, combined, examples, systemPrompt, systemMessage, messages, transcript, config,
            response, content, confusionScores, confusionScore, queries
        },

        relevant = ConfirmMatch[
            Take[ vectorDBSearch[ "WolframAlphaQueries", prompt, "Values" ], UpTo[ relatedCount ] ],
            { __String },
            "RelevantQueries"
        ];

        all = ConfirmMatch[ $allQueries, { __String }, "AllQueries" ];

        combined = ConfirmMatch[
            Join[ relevant, cachedRandomSample[ Complement[ all, relevant ], randomCount ] ],
            { __String },
            "Combined"
        ];

        $sampleQueries = ConfirmMatch[ Take[ combined, $sampleQueryCount ], { ___String }, "SampleQueries" ];

        examples = StringRiffle[ combined, "\n" ];

        systemPrompt = StringTrim @ ConfirmBy[
            TemplateApply[
                $promptTemplate,
                <|
                    "Examples"     -> examples,
                    "MaxItems"     -> IntegerName @ count,
                    "Instructions" -> If[ StringQ @ $instructions, $instructions, "" ]
                |>
            ],
            StringQ,
            "SystemPrompt"
        ];

        systemMessage = <| "Role" -> "System", "Content" -> systemPrompt |>;

        transcript = ConfirmBy[
            getSmallContextString[
                (* FIXME: Need to implement per-chat caching to avoid repeating this for the same messages *)
                dropTrailingToolMessages @ insertContextPrompt @ prompt,
                "SingleMessageTemplate" -> StringTemplate[ "`Content`" ]
            ],
            StringQ,
            "Transcript"
        ];

        messages = ConfirmMatch[
            Flatten @ {
                systemMessage,
                $fewShotExamples,
                <| "Role" -> "User"  , "Content" -> transcript     |>,
                <| "Role" -> "System", "Content" -> $queryReminder |>
            },
            $$chatMessages,
            "Messages"
        ];

        config   = ConfirmBy[ mergeChatSettings @ { $defaultConfig, $generatorLLMConfig }, AssociationQ, "Config" ];
        response = ConfirmBy[ generateSuggestedQueries0[ messages, config ], AssociationQ, "Response" ];
        content  = StringTrim @ ConfirmBy[ response[ "Content" ], StringQ, "Content" ];

        confusionScores = ConfirmBy[ confusionScoreData @ content, AssociationQ, "ConfusionScores" ];
        confusionScore = ConfirmBy[ Total @ Values @ confusionScores, NumberQ, "ConfusionScore" ];

        queries = ConfirmMatch[
            If[ confusionScore > 1.0,
                { },
                checkForBadQueries @ DeleteCases[ StringTrim @ StringSplit[ content, "\n" ], $$emptyResponse ]
            ],
            { ___String },
            "Queries"
        ];

        addHandlerArguments[
            "RelatedWolframAlphaResults" -> <|
                "Messages"        -> messages,
                "Response"        -> response,
                "SampleQueries"   -> $sampleQueries,
                "Queries"         -> queries,
                "ConfusionScores" -> confusionScores
            |>
        ];

        queries
    ],
    throwInternalFailure
];

generateSuggestedQueries // endDefinition;


generateSuggestedQueries0 // beginDefinition;

generateSuggestedQueries0[ messages_, config_ ] := Enclose[
    Module[ { response },
        response = ConfirmBy[ llmChat[ messages, config ], AssociationQ, "Response" ];
        If[ TrueQ @ $cacheResults,
            generateSuggestedQueries0[ messages, config ] = response,
            response
        ]
    ],
    throwInternalFailure
];

generateSuggestedQueries0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dropTrailingToolMessages*)
dropTrailingToolMessages // beginDefinition;
dropTrailingToolMessages[ { before__, _? toolMessageQ, _ } ] := dropTrailingToolMessages @ { before };
dropTrailingToolMessages[ messages_List ] := messages;
dropTrailingToolMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkForBadQueries*)
checkForBadQueries // beginDefinition;

checkForBadQueries[ queries: { ___String } ] /; AnyTrue[ queries, probablyBadQueryQ ] := { };

checkForBadQueries[ queries: { ___String } ] := StringReplace[
    queries,
    StartOfString ~~ "[" ~~ q__ ~~ "]" ~~ EndOfString :> q
];

checkForBadQueries // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*confusionScoreData*)
confusionScoreData // beginDefinition;

confusionScoreData[ content_String ] := Select[
    Association[
        (#Weight * StringCount[ content, Shortest[ #Pattern ] ] &) /@ $confusionTestData,
        "LongResponse" -> N @ Max[ 0, (StringLength @ content - $largeResponseLength) / $largeResponseLength ]
    ],
    GreaterThan[ 0.0 ]
];

confusionScoreData // endDefinition;

$$wordBoundary = StartOfString | EndOfString | Except[ WordCharacter ];

$confusionTestData = <|
    "MarkdownSections"     -> <| "Weight" -> 0.50, "Pattern" -> StartOfLine ~~ "#".. ~~ " " |>,
    "MarkdownItems"        -> <| "Weight" -> 0.25, "Pattern" -> StartOfLine ~~ "-".. ~~ " " |>,
    "MarkdownLinks"        -> <| "Weight" -> 0.25, "Pattern" -> StartOfLine ~~ "["~~___~~"]("~~__~~")" |>,
    "MarkdownImages"       -> <| "Weight" -> 1.00, "Pattern" -> "!["~~___~~"]("~~__~~")" |>,
    "AttemptedToolCalls"   -> <| "Weight" -> 1.00, "Pattern" -> StartOfLine ~~ "/" ~~ Repeated[ Except[ WhitespaceCharacter ], { 2, 80 } ] ~~ "\n" |>,
    "NoteTags"             -> <| "Weight" -> 1.00, "Pattern" -> StartOfLine ~~ "[note: "~~___~~"]" |>,
    "SuspiciousLineBreaks" -> <| "Weight" -> 0.25, "Pattern" -> "\n\n" |>,
    "InlineTeX"            -> <| "Weight" -> 0.50, "Pattern" -> $$wordBoundary ~~ "$"~~___~~"$" ~~ $$wordBoundary |>,
    "InlineTeX2"           -> <| "Weight" -> 1.00, "Pattern" -> $$wordBoundary ~~ "$$"~~___~~"$$" ~~ $$wordBoundary |>
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*probablyBadQueryQ*)
probablyBadQueryQ // beginDefinition;
probablyBadQueryQ[ query_String ] := StringLength @ query > $largeQueryLength;
probablyBadQueryQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cachedRandomSample*)
cachedRandomSample // beginDefinition;

cachedRandomSample[ queries_List, count_ ] :=
    If[ TrueQ @ $cacheResults,
        cachedRandomSample[ queries, count ] = RandomSample[ queries, count ],
        RandomSample[ queries, count ]
    ];

cachedRandomSample // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$allQueries*)
$allQueries := $allQueries = Union @ RelatedWolframAlphaQueries @ All;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatWolframAlphaResult*)
formatWolframAlphaResult // beginDefinition;

formatWolframAlphaResult[ query_String, KeyValuePattern[ "String" -> res_String ] ] :=
    formatWolframAlphaResult0[ query, makeWolframAlphaURL @ query, StringTrim @ res ];

formatWolframAlphaResult[ query_String, _ ] :=
    formatWolframAlphaResult0[ query, makeWolframAlphaURL @ query, Missing[ "No Results Found" ] ];

formatWolframAlphaResult[ KeyValuePattern @ { "Query" -> query_String, "URL" -> url_String, "Content" -> content_ } ] :=
    formatWolframAlphaResult0[ query, url, makeContentString @ content ];

formatWolframAlphaResult // endDefinition;


formatWolframAlphaResult0 // beginDefinition;

formatWolframAlphaResult0[ query_String, url_String, content_ ] :=
    TemplateApply[
        $wolframAlphaResultTemplate,
        {
            StringReplace[ StringTrim @ query, "'" -> "&#39;" ],
            url,
            content
        }
    ];

formatWolframAlphaResult0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeContentString*)
makeContentString // beginDefinition;

makeContentString[ content: { ___Association } ] :=
    StringTrim @ StringJoin @ Cases[
        content,
        KeyValuePattern @ { "Type" -> "Text", "Data" -> text_String } :> text
    ];

makeContentString[ KeyValuePattern[ "Type" -> "Error" ] ] :=
    "No Results Found";

makeContentString[ $TimedOut ] :=
    "Request timed out";

makeContentString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeWolframAlphaURL*)
makeWolframAlphaURL // beginDefinition;
makeWolframAlphaURL[ query_String ] := URLBuild[ "https://www.wolframalpha.com/input", { "i" -> query } ];
makeWolframAlphaURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Wolfram Alpha Private Functions*)
normalizeWhitespace := normalizeWhitespace = Symbol[ "WolframAlphaClient`Private`customNormalizeWhitespace" ];
expandData          := expandData          = Symbol[ "WolframAlphaClient`Private`expandData" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadWolframAlphaClient*)
loadWolframAlphaClient // beginDefinition;
loadWolframAlphaClient[ ] := loadWolframAlphaClient[ ] = Quiet @ WolframAlpha[ ];
loadWolframAlphaClient // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Direct API Method*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relatedWolframAlphaResultsContent*)
relatedWolframAlphaResultsContent // beginDefinition;

relatedWolframAlphaResultsContent[ messages: $$chatMessages, count_, relatedCount_, randomCount_ ] :=
    relatedWolframAlphaResultsFullData[ messages, count, relatedCount, randomCount ][ "Content" ];

relatedWolframAlphaResultsContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relatedWolframAlphaResultsFullData*)
relatedWolframAlphaResultsFullData // beginDefinition;

relatedWolframAlphaResultsFullData[ messages: $$chatMessages, count_, relatedCount_, randomCount_ ] := Enclose[
    Catch @ Module[ { queries, sampleQueries, content },

        queries = ConfirmMatch[
            setServiceCaller[
                generateSuggestedQueries[ messages, count, relatedCount, randomCount ],
                "RelatedWolframAlphaResults"
            ],
            { ___String },
            "Queries"
        ];

        sampleQueries = ConfirmMatch[ $sampleQueries, { ___String }, "SampleQueries" ];

        If[ queries === { }, Throw @ <| "Content" -> { }, "SampleQueries" -> sampleQueries |> ];

        content = ConfirmMatch[ getWolframAlphaResults[ queries, "Content" ], { ___Association }, "Content" ];

        <| "Content" -> content, "SampleQueries" -> sampleQueries |>
    ],
    throwInternalFailure
];

relatedWolframAlphaResultsFullData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getWolframAlphaResults*)
getWolframAlphaResults // beginDefinition;
getWolframAlphaResults // Options = { "StepByStep" :> $showSteps };

(* Default type *)
getWolframAlphaResults[ queries: $$stringOrStrings, opts: OptionsPattern[ ] ] :=
    getWolframAlphaResults[ queries, "Content", opts ];

(* Text/String *)
getWolframAlphaResults[ queries: $$stringOrStrings, "Text"|"String", opts: OptionsPattern[ ] ] := Enclose[
    Module[ { strings },
        strings = ConfirmMatch[ getWolframAlphaResults[ queries, "Strings", opts ], { ___String }, "Strings" ];
        StringRiffle[ strings, "\n\n" ]
    ],
    throwInternalFailure
];

getWolframAlphaResults[ queries: $$stringOrStrings, "Strings", opts: OptionsPattern[ ] ] := Enclose[
    Module[ { content, strings },
        content = ConfirmMatch[
            getWolframAlphaAPIContent[ Flatten @ { queries }, opts ],
            { ___Association },
            "Content"
        ];

        strings = ConfirmMatch[ formatWolframAlphaResult /@ content, { ___String }, "Strings" ];

        strings
    ],
    throwInternalFailure
];

(* Content *)
getWolframAlphaResults[ query_String, "Content", opts: OptionsPattern[ ] ] := Enclose[
    First @ ConfirmMatch[ getWolframAlphaAPIContent[ { query }, opts ], { _Association }, "Result" ],
    throwInternalFailure
];

getWolframAlphaResults[ queries: { ___String }, "Content", opts: OptionsPattern[ ] ] :=
    getWolframAlphaAPIContent[ queries, opts ];


getWolframAlphaResults // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getWolframAlphaAPIContent*)
getWolframAlphaAPIContent // beginDefinition;
getWolframAlphaAPIContent // Options = { "StepByStep" :> $showSteps };

getWolframAlphaAPIContent[ { }, opts: OptionsPattern[ ] ] := { };

getWolframAlphaAPIContent[ queries: { ___String }, opts: OptionsPattern[ ] ] := Enclose[
    Module[ { results },
        results = ConfirmMatch[
            Block[ { $showSteps = TrueQ @ OptionValue[ "StepByStep" ] },
                getWolframAlphaAPIContent0 @ queries
            ],
            { ___Association },
            "Results"
        ];

        ConfirmMatch[ addWolframAlphaSources @ results, { ___Association }, "Results" ];

        results
    ],
    throwInternalFailure
];

getWolframAlphaAPIContent // endDefinition;


getWolframAlphaAPIContent0 // beginDefinition;

getWolframAlphaAPIContent0[ queries: { ___String } ] := Enclose[
    Module[ { results, tasks, content, cleaned },
        results = <| |>;
        tasks = ConfirmMatch[ submitXMLRequest[ results ] /@ queries, { ___TaskObject }, "Tasks" ];

        taskWaitYield[ tasks, TimeConstraint -> $timeouts[ "TaskWait" ] ];
        Quiet[ TaskRemove /@ tasks ];

        content = ConfirmMatch[ Values @ results, { ___Association }, "Content" ];

        cleaned = DeleteDuplicatesBy[
            KeyDrop[ content, { "StatusCode", "BodyByteArray" } ],
            waResultID
        ];

        If[ TrueQ @ $cacheResults,
            getWolframAlphaAPIContent0[ queries ] = cleaned,
            cleaned
        ]
    ],
    throwInternalFailure
];

getWolframAlphaAPIContent0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*waResultID*)
waResultID // beginDefinition;

waResultID[ as_Association ] := Enclose[
    Hash @ ConfirmBy[ waResultID0 @ as, StringQ, "ID" ],
    throwInternalFailure
];

waResultID // endDefinition;


waResultID0 // beginDefinition;

waResultID0[ as_Association ] :=
    waResultID0[ as, as[ "InputInterpretation" ] ];

waResultID0[ as_, int_String ] :=
    int;

waResultID0[ as_, int_Missing ] :=
    waResultID0[ as, int, as[ "Content" ] ];

waResultID0[ as_, int_, content: { __Association } ] :=
    With[ { s = makeContentString @ content },
        StringDelete[
            s,
            Shortest @ StringExpression[
                "https://",
                (LetterCharacter|DigitCharacter|"_")..,
                ".wolframalpha.com/files/",
                (LetterCharacter|DigitCharacter|"_")..,
                ".gif"|".png"
            ]
        ] /; StringQ @ s
    ];

waResultID0[ as_, int_, content_ ] :=
    as[ "Query" ];

waResultID0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addWolframAlphaSources*)
addWolframAlphaSources // beginDefinition;

addWolframAlphaSources[ results_List ] :=
    addWolframAlphaSources /@ results;

addWolframAlphaSources[ result_Association ] :=
    addWolframAlphaSources[ result[ "URL" ], result[ "Content" ] ];

addWolframAlphaSources[ url_String, content: { __Association } ] :=
    AddToSources[ url, content ];

addWolframAlphaSources[ url_String, $TimedOut | { } | KeyValuePattern[ "Type" -> "Error" ] ] :=
    Nothing;

addWolframAlphaSources // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*submitXMLRequest*)
submitXMLRequest // beginDefinition;
submitXMLRequest // Attributes = { HoldFirst };

submitXMLRequest[ assoc_ ] :=
    submitXMLRequest[ assoc, # ] &;

(* cSpell: ignore minput, sbsmode, podstate, scantimeout, podtimeout, formattimeout, parsetimeout, totaltimeout *)
submitXMLRequest[ assoc_, query_String ] /; StringQ @ $wolframAlphaAppID := Enclose[
    Module[ { request, task },

        If[ ! AssociationQ @ assoc, assoc = <| |> ];
        If[ ! AssociationQ @ assoc @ query, assoc @ query = <| |> ];
        assoc[ query, "Query"   ] = query;
        assoc[ query, "URL"     ] = makeWolframAlphaURL @ query;
        assoc[ query, "Content" ] = $TimedOut;

        request = HTTPRequest[
            "https://api.wolframalpha.com/v2/query",
            <|
                "Query" -> DeleteMissing @ <|
                    "input"         -> query,
                    "reinterpret"   -> $reinterpret,
                    "appid"         -> $wolframAlphaAppID,
                    "format"        -> StringRiffle[ $formats, "," ],
                    "output"        -> "xml",
                    "sbsmode"       -> If[ TrueQ @ $showSteps, "StepByStepDetails", Missing[ ] ],
                    "podstate"      -> StringRiffle[ $podStates, "," ],
                    "scantimeout"   -> $timeouts[ "AlphaScan"   ],
                    "podtimeout"    -> $timeouts[ "AlphaPod"    ],
                    "formattimeout" -> $timeouts[ "AlphaFormat" ],
                    "parsetimeout"  -> $timeouts[ "AlphaParse"  ],
                    "totaltimeout"  -> $timeouts[ "AlphaTotal"  ]
                |>
            |>
        ];

        task = URLSubmit[
            request,
            HandlerFunctionsKeys -> { "StatusCode", "BodyByteArray" },
            HandlerFunctions     -> <| "TaskFinished" -> setXMLResult @ assoc @ query |>,
            TimeConstraint       -> $timeouts[ "URLSubmit" ]
        ];

        ConfirmMatch[ task, _TaskObject, "Task" ]
    ],
    throwInternalFailure
];

submitXMLRequest[ assoc_, query_String ] := Enclose[
    Module[ { url, task },

        If[ ! AssociationQ @ assoc, assoc = <| |> ];
        If[ ! AssociationQ @ assoc @ query, assoc @ query = <| |> ];
        assoc[ query, "Query"   ] = query;
        assoc[ query, "URL"     ] = makeWolframAlphaURL @ query;
        assoc[ query, "Content" ] = $TimedOut;

        url = ConfirmBy[
            WolframAlpha[
                query,
                "URL",
                PodStates -> $podStates,
                Method    -> { "Formats" -> $formats }
            ],
            StringQ,
            "URL"
        ];

        $lastURL = url;

        task = URLSubmit[
            url,
            HandlerFunctionsKeys -> { "StatusCode", "BodyByteArray" },
            HandlerFunctions     -> <| "TaskFinished" -> setXMLResult @ assoc @ query |>,
            TimeConstraint       -> $timeouts[ "URLSubmit" ]
        ];

        ConfirmMatch[ task, _TaskObject, "Task" ]
    ],
    throwInternalFailure
];

submitXMLRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*setXMLResult*)
setXMLResult // beginDefinition;
setXMLResult // Attributes = { HoldFirst };

setXMLResult[ result_ ] :=
    setXMLResult[ result, # ] &;

setXMLResult[ result_, as: KeyValuePattern @ { "StatusCode" -> 200, "BodyByteArray" -> bytes_ByteArray } ] := Enclose[
    Module[ { xmlString, xml, warnings, processed, query, input, content },

        xmlString = ConfirmBy[ ByteArrayToString @ bytes, StringQ, "XMLString" ];

        xml = ConfirmMatch[
            ImportString[ xmlString, { "XML", "XMLObject" }, "NormalizeWhitespace" -> False ],
            $$xml,
            "XML"
        ];

        warnings  = Internal`Bag[ ];
        processed = Block[ { $warnings = warnings }, processXML @ xml ];
        query     = ConfirmBy[ result[ "Query" ], StringQ, "Query" ];
        input     = ConfirmMatch[ inputInterpretation[ query, xml ], _String|_Missing, "Input" ];
        content   = If[ ListQ @ processed && TrueQ @ $includeWLResults,
                        ConfirmBy[ formatNaturalLanguageInput @ processed, ListQ, "Content" ],
                        processed
                    ];

        If[ ! AssociationQ @ result, result = <| |> ];
        result = <|
            result,
            as,
            "InputInterpretation" -> input,
            "Content"             -> content,
            "Warnings"            -> Internal`BagPart[ warnings, All ]
        |>
    ],
    throwInternalFailure
];

setXMLResult[ result_, as: KeyValuePattern @ { "StatusCode" -> _Missing, "BodyByteArray" -> _Missing } ] :=
    result = <| result, as, "Content" -> $TimedOut |>;

setXMLResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatNaturalLanguageInput*)
formatNaturalLanguageInput // beginDefinition;

formatNaturalLanguageInput[ processed_List ] := ReplaceAll[
    processed,
    string_String :>
        RuleCondition @ StringReplace[
            string,
            "# Input interpretation\n\n" ~~ query__ ~~ "\n\n```wl\n" ~~ code__ ~~ "\n```" /;
                StringFreeQ[ query, "\n\n" ] :> makeInterpretationCode[ query, code ]
        ]
];

formatNaturalLanguageInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeInterpretationCode*)
makeInterpretationCode // beginDefinition;

makeInterpretationCode[ query0_String, code0_String ] := Enclose[
    Module[ { code, query, input },

        code = ConfirmBy[ rewriteEntityValueCode @ code0, StringQ, "Code" ];

        query = StringRiffle @ DeleteCases[ StringTrim @ StringSplit[ query0, { "\\|", "\n" } ], "" ];

        input = If[ StringMatchQ[ code, "EntityClass[" ~~ __ ~~ "]" ],
                    "EntityList[\[FreeformPrompt][\""<>query<>"\"]]",
                    "\[FreeformPrompt][\""<>query<>"\"]"
                ];

        ConfirmBy[
            TemplateApply[ $interpretationTemplate, <| "Input" -> input, "Query" -> query, "Code" -> code |> ],
            StringQ,
            "Result"
        ]
    ],
    throwInternalFailure
];

makeInterpretationCode // endDefinition;


$interpretationTemplate = StringTemplate[ "\
# Input interpretation

```wl
In[1]:= %%Input%%

During evaluation of In[1]:= [INFO] Interpreted \"%%Query%%\" as: %%Code%%
```", Delimiters -> "%%" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*rewriteEntityValueCode*)
rewriteEntityValueCode // beginDefinition;

rewriteEntityValueCode[ code_String ] :=
    If[ StringContainsQ[ code, "Entity[" ],
        rewriteEntityValueCode[ code, Quiet @ ToExpression[ code, InputForm, HoldComplete ] ],
        code
    ];

rewriteEntityValueCode[ code_, held_HoldComplete ] := Enclose[
    Catch @ Module[ { replaced },
        replaced = held /. HoldPattern[ (e_Entity)[ p: _EntityProperty | _String ] ] :> EntityValue[ e, p ];
        If[ replaced === held, Throw @ code ];
        ConfirmBy[
            Replace[ replaced, HoldComplete[ e_ ] :> ToString[ Unevaluated @ e, InputForm ] ],
            StringQ,
            "Result"
        ]
    ],
    throwInternalFailure
];

rewriteEntityValueCode[ code_, _ ] :=
    code;

rewriteEntityValueCode // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inputInterpretation*)
inputInterpretation // beginDefinition;

inputInterpretation[ query_String, xml_ ] := FirstCase[
    xml,
    XMLElement[ "pod", KeyValuePattern[ "title" -> "Input interpretation"|"Input" ], content_ ] :>
        With[ { s = StringTrim @ StringJoin @ Select[ parsePodContent @ content, StringQ ] },
            s /; s =!= ""
        ],
    Missing[ "NotFound" ],
    Infinity
];

inputInterpretation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processXML*)
processXML // beginDefinition;

processXML[ xml_ ] := Enclose[
    Catch @ Module[ { parsed, pods, markdown, data },

        parsed = parseXML @ xml;
        If[ MatchQ[ parsed, KeyValuePattern[ "Type" -> "Error" ] ], Throw @ parsed ];
        If[ MatchQ[ parsed, { KeyValuePattern[ "Title" -> "Input interpretation" ] } ],
            Throw @ <| "Type" -> "Error", "Data" -> Missing[ "NoContent" ] |>
        ];
        pods = SortBy[ Cases[ parsed, KeyValuePattern[ "Type" -> "Pod" ] ], Lookup[ "Position" ] ];
        markdown = toMarkdownData @ pods;

        data = Flatten @ Map[
            Function[
                If[ MatchQ[ #1, { _String, ___ } ],
                    <| "Type" -> "Text", "Data" -> StringRiffle[ #1, "\n\n" ] <> "\n\n" |>,
                    #1
                ]
            ],
            SplitBy[ markdown, StringQ ]
        ];

        data
    ],
    throwInternalFailure
];

processXML // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseXML*)
parseXML // beginDefinition;

parseXML[ XMLObject[ "Document" ][ _, xml_XMLElement, _ ] ] :=
    Catch[ parseXML @ xml, $xmlTop ];

parseXML[ XMLElement[ "queryresult", KeyValuePattern[ "success" -> "true" ], xml_ ] ] :=
    parseXML @ xml;

parseXML[ XMLElement[ "queryresult", as: KeyValuePattern[ "success" -> "false" ], _ ] ] :=
    Throw[ <| "Type" -> "Error", "Data" -> Association @ as |>, $xmlTop ];

parseXML[ xml_List ] :=
    Flatten[ parseXML /@ xml ];

parseXML[ XMLElement[
    "pod",
    as: KeyValuePattern @ { "title" -> title_String, "id" -> id_String, "position" -> pos_String },
    xml_
] ] := <|
    "Type"     -> "Pod",
    "ID"       -> id,
    "Title"    -> title,
    "Position" -> Internal`StringToMInteger @ pos,
    "Metadata" -> Association @ as,
    "Content"  -> stripRedundantContent @ Flatten @ { parsePodContent @ xml }
|>;

parseXML[ xml: XMLElement[ "assumptions", _, _ ] ] :=
    parseAssumptions @ xml;

parseXML[ XMLElement[ "warnings", _, xml_ ] ] :=
    (addWarnings @ xml; { });

parseXML[ s_String ] /; StringMatchQ[ s, WhitespaceCharacter... ] :=
    { };

parseXML[ XMLElement[ $$ignoredXMLTag, _, _ ] ] :=
    { };

parseXML[ XMLElement[ unhandledTag_String, _, _ ] ] := (
    If[ TrueQ @ $wolframAlphaDebug, messagePrint[ "UnhandledWolframAlphaXMLTag", unhandledTag ] ];
    { }
);

parseXML // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parsePodContent*)
parsePodContent // beginDefinition;

parsePodContent[ XMLElement[ "subpod", KeyValuePattern[ "title" -> "" ], xml_ ] ] :=
    parsePodContent @ xml;

parsePodContent[ XMLElement[ "subpod", KeyValuePattern[ "title" -> title_String ], xml_ ] ] := {
    "## "<>title,
    parsePodContent @ xml
};

parsePodContent[ xml_List ] :=
    Flatten[ parsePodContent /@ xml ];

parsePodContent[ XMLElement[
    "img",
    KeyValuePattern @ { "src" -> url_String, "alt" -> alt_String, "contenttype" -> mime_String },
    { }
] ] := <|
    "Type"     -> "Image",
    "Data"     -> URL @ url,
    "Caption"  -> alt,
    "MIMEType" -> mime
|>;

parsePodContent[ XMLElement[ "plaintext", _, text: _String | { __String } ] ] :=
    escapeMarkdownText @ StringJoin @ text;

parsePodContent[ XMLElement[ "plaintext", _, { } ] ] :=
    { };

parsePodContent[ xml: XMLElement[ "minput", _, _ ] ] :=
    parseWLCode @ xml;

parsePodContent[ XMLElement[ "mathml", _, xml_ ] ] :=
    parseMathML @ xml;

parsePodContent[ XMLElement[ $$ignoredXMLTag, _, _ ] ] :=
    { };

parsePodContent[ _String ] :=
    { };

parsePodContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseWLCode*)
parseWLCode // beginDefinition;

parseWLCode[ XMLElement[ "minput", _, xml_ ] ] :=
    parseWLCode @ xml;

parseWLCode[ code_String ] :=
    code;

parseWLCode[ content_List ] := Enclose[
    Catch @ Module[ { parsed, strings, code },
        parsed = ConfirmMatch[ Flatten[ parseWLCode /@ content ], { ___String }, "Parsed" ];
        strings = DeleteCases[ StringTrim @ parsed, "" ];
        If[ strings === { }, Throw @ { } ];
        code = StringRiffle[ strings, "\n\n" ];
        { "```wl\n" <> code <> "\n```" }
    ],
    throwInternalFailure
];

parseWLCode // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseAssumptions*)
parseAssumptions // beginDefinition;
parseAssumptions[ ___ ] := { }; (* TODO: Implement *)
parseAssumptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*escapeMarkdownText*)
escapeMarkdownText // beginDefinition;

escapeMarkdownText[ text_String ] :=
    escapeMarkdownString @ text;

escapeMarkdownText[ as: KeyValuePattern @ { "Type" -> "Text", "Data" -> text_String } ] :=
    <| as, "Data" -> escapeMarkdownText @ text |>;

escapeMarkdownText[ content_List ] :=
    escapeMarkdownText /@ content;

escapeMarkdownText[ other_ ] :=
    other;

escapeMarkdownText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseMathML*)
parseMathML // beginDefinition;

parseMathML[ xml_List ] :=
    Flatten[ parseMathML /@ xml ];

parseMathML[ XMLElement[ "math", _, { $$ws, xml: XMLElement[ "mtext", _, text: _String | { ___String } ], $$ws } ] ] :=
    { };

parseMathML[ xml: XMLElement[ "math", _, _ ] ] :=
    Enclose @ Module[ { bytes, boxes, tex },
        bytes = StringDelete[ ConfirmBy[ ExportString[ xml, "XML" ], StringQ, "Bytes" ], "\:f3a2" ];
        boxes = Confirm[ ImportString[ bytes, "MathML" ], "Boxes" ];
        tex = ConfirmBy[ CellToString @ boxes, StringQ, "TeX" ];
        StringReplace[
            tex,
            {
                "\\unicode{f3a2}" -> "",
                "\\unicode{" ~~ c: HexadecimalCharacter.. ~~ "}" :> FromCharacterCode[ FromDigits[ c, 16 ], "UTF-8" ]
            },
            IgnoreCase -> True
        ]
    ];

parseMathML[ s_String ] /; StringMatchQ[ s, WhitespaceCharacter... ] :=
    { };

parseMathML // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toMarkdownData*)
toMarkdownData // beginDefinition;

toMarkdownData[ pods_List ] :=
    Flatten[ toMarkdownData /@ pods ];

toMarkdownData[ as: KeyValuePattern[ "Type" -> type_String ] ] :=
    toMarkdownData[ type, as ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::KernelBug:: *)
toMarkdownData[
    "Pod",
    as: KeyValuePattern @ {
        "ID" -> "Input",
        "Content" -> {
            a___,
            KeyValuePattern @ { "Type" -> "Image", "Caption" -> None },
            b___
        }
    }
] := toMarkdownData[ "Pod", <| as, "Content" -> { a, b } |> ];
(* :!CodeAnalysis::EndBlock:: *)

toMarkdownData[ "Pod", as: KeyValuePattern @ { "Title" -> title_String, "Content" -> content_ } ] :=
    Flatten @ { "# "<>title, toMarkdownData @ content };

toMarkdownData[ "Text", KeyValuePattern[ "Data" -> text_String ] ] :=
    text;

toMarkdownData[ text_String ] :=
    text;

toMarkdownData[ "Image", KeyValuePattern @ { "Caption" -> caption_, "Data" -> URL[ uri_String ] } ] := {
    If[ StringQ @ caption && StringFreeQ[ caption, "["|"]" ],
        "!["<>caption<>"]("<>uri<>")",
        "![Image]("<>uri<>")"
    ],
    If[ TrueQ @ $multimodal, <| "Type" -> "Image", "Data" -> URL @ uri |>, Nothing ]
};

toMarkdownData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stripRedundantContent*)
stripRedundantContent // beginDefinition;

stripRedundantContent[ content_List ] :=
    Flatten @ FixedPoint[
        Composition[
            Flatten,
            SequenceReplace @ {
                { a_String, b_String } /;
                    StringTrim[ a, { "$$\\text{", "}$$" } ] === StringTrim[ b, { "$$\\text{", "}$$" } ] :>
                        StringTrim[ a, { "$$\\text{", "}$$" } ]
                ,
                { img: KeyValuePattern @ { "Type" -> "Image", "Caption" -> _String }, text_String } :>
                    Which[
                        redundantImageQ[ img, text ],
                            text,
                        redundantCaptionQ[ img, text ],
                            { <| img, "Caption" -> None, "OriginalCaption" -> img[ "Caption" ] |>, text },
                        True,
                            { img, text }
                    ]
            }
        ],
        content
    ];

stripRedundantContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*redundantImageQ*)
redundantImageQ // beginDefinition;

redundantImageQ[ ___ ] /; $keepAllImages :=
    False;

redundantImageQ[ as_Association, KeyValuePattern[ "Data" -> text_String ] ] :=
    redundantImageQ[ as, text ];

redundantImageQ[ as_, text_String ] /; StringMatchQ[ StringTrim @ text, "(" ~~ __ ~~ ")" ] :=
    False;

redundantImageQ[ as: KeyValuePattern[ "Caption" -> _String ], text_String ] :=
    redundantCaptionQ[ as, text ] && (Or[ StringFreeQ[ text, "|" ], StringFreeQ[ text, "\n" ] ]);

redundantImageQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*redundantCaptionQ*)
redundantCaptionQ // beginDefinition;

redundantCaptionQ[ as_Association, KeyValuePattern[ "Data" -> text_String ] ] :=
    redundantCaptionQ[ as, text ];

redundantCaptionQ[ KeyValuePattern[ "Caption" -> caption_String ], text_String ] :=
    StringDelete[ caption, Whitespace|"\\" ] === StringDelete[ text, Whitespace|"\\" ];

redundantCaptionQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
