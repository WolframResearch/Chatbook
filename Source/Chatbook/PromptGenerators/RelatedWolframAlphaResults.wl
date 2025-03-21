(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`RelatedWolframAlphaResults`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                         ];
Needs[ "Wolfram`Chatbook`Common`"                  ];
Needs[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$maxItems           = 5;
$generatorLLMConfig = <| "StopTokens" -> { "[NONE]" } |>;
$usePromptHeader    = True;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$$count = _Integer | UpTo[ _Integer ];
$$xml   = HoldPattern[ _XMLElement | XMLObject[ _ ][ ___ ] ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedWolframAlphaResults*)
RelatedWolframAlphaResults // beginDefinition;
RelatedWolframAlphaResults // Options = {
    "LLMEvaluator"      -> Automatic,
    "MaxItems"          -> Automatic,
    "RandomQueryCount"  -> Automatic,
    "RelatedQueryCount" -> Automatic,
    "PromptHeader"      -> Automatic
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
RelatedWolframAlphaResults[ prompt_, "Prompt", n_Integer, opts: OptionsPattern[ ] ] :=
    catchMine @ Block[
        {
            $generatorLLMConfig = Replace[
                OptionValue[ "LLMEvaluator" ],
                $$unspecified :> $generatorLLMConfig
            ],
            $usePromptHeader = Replace[
                OptionValue[ "PromptHeader" ],
                $$unspecified :> $usePromptHeader
            ],
            $maxItems = n
        },
        relatedWolframAlphaResultsPrompt[
            ensureChatMessages @ prompt,
            n,
            Replace[ OptionValue[ "RelatedQueryCount" ], $$unspecified :> Min[ 20, $maxItems*4 ] ],
            Replace[ OptionValue[ "RandomQueryCount"  ], $$unspecified :> Min[ 20, $maxItems*4 ] ]
        ]
    ];

RelatedWolframAlphaResults // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompts*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$promptTemplate*)
(* TODO: explain the transcript *)
$promptTemplate = StringTemplate[ "\
Your task is to write Wolfram Alpha queries that could help provide relevant info needed to answer a user's prompt.

Here are some examples of valid Wolfram Alpha queries to give you a sense of what kinds of things it can handle:
<examples>
`Examples`
</examples>

Reply with up to `MaxItems` queries each on a separate line and nothing else. \
Reply with [NONE] if the user's prompt is completely unrelated to anything computational or knowledge-based, \
e.g. casual conversation." ];

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
(*$markdownHint*)
$markdownHint = "

======

You can use any markdown links from these results in your response to show images, \
formatted expressions, etc. to the user.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$wolframAlphaResultTemplate*)
$wolframAlphaResultTemplate = StringTemplate[ "<query>`1`</query>\n<results>\n`2`\n</results>" ];

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
        { }
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

makeMessagePairs[ input_String, { } ] := Flatten @ {
    <| "Role" -> "User"     , "Content" -> input    |>,
    <| "Role" -> "Assistant", "Content" -> "[NONE]" |>
};

makeMessagePairs[ pairs_List ] :=
    Flatten[ makeMessagePairs /@ pairs ];

makeMessagePairs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Supporting Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relatedWolframAlphaResultsPrompt*)
relatedWolframAlphaResultsPrompt // beginDefinition;

relatedWolframAlphaResultsPrompt[ messages: $$chatMessages, count_, relatedCount_, randomCount_ ] := Enclose[
    Catch @ Module[ { queries, waResults, resultsString },

        queries = ConfirmMatch[
            generateSuggestedQueries[ messages, count, relatedCount, randomCount ],
            { ___String },
            "Queries"
        ];

        If[ queries === { }, Throw[ "" ] ];

        waResults = ConfirmMatch[ getAllWolframAlphaResults @ queries, { __String }, "WolframAlphaResults" ];

        resultsString = StringRiffle[
            StringTrim @ DeleteDuplicatesBy[
                Select[ waResults, StringQ ],
                StringDelete @ Shortest[ "<query>" ~~ __ ~~ "</query>" ]
            ],
            "\n\n======\n\n"
        ];

        StringJoin[
            ConfirmBy[ $resultsPromptHeader, StringQ, "Header" ],
            resultsString,
            If[ StringContainsQ[ resultsString, "![" ~~ __ ~~ "](" ~~ __ ~~ ")" ],
                ConfirmBy[ $markdownHint, StringQ, "MarkdownHint" ],
                ""
            ]
        ]
    ],
    throwInternalFailure
];

relatedWolframAlphaResultsPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateSuggestedQueries*)
generateSuggestedQueries // beginDefinition;

generateSuggestedQueries[ prompt_, count_Integer, relatedCount_Integer, randomCount_Integer ] := Enclose[
    Module[ { relevant, all, combined, examples, systemPrompt, systemMessage, messages, transcript, response, content },

        relevant = ConfirmMatch[
            Take[ vectorDBSearch[ "WolframAlphaQueries", prompt, "Values" ], UpTo[ relatedCount ] ],
            { __String },
            "RelevantQueries"
        ];

        all = ConfirmMatch[ $allQueries, { __String }, "AllQueries" ];

        combined = ConfirmMatch[
            Join[ relevant, RandomSample[ Complement[ all, relevant ], randomCount ] ],
            { __String },
            "Combined"
        ];

        examples = StringRiffle[ combined, "\n" ];

        systemPrompt = ConfirmBy[
            TemplateApply[ $promptTemplate, <| "Examples" -> examples, "MaxItems" -> IntegerName @ count |> ],
            StringQ,
            "SystemPrompt"
        ];

        systemMessage = <| "Role" -> "System", "Content" -> systemPrompt |>;

        transcript = ConfirmBy[ getSmallContextString @ insertContextPrompt @ prompt, StringQ, "Transcript" ];

        messages = ConfirmMatch[
            Flatten @ { systemMessage, $fewShotExamples, <| "Role" -> "User", "Content" -> transcript |> },
            $$chatMessages,
            "Messages"
        ];

        response = ConfirmBy[
            (* FIXME: need to add a chat function that uses the proper config in LLMUtilities.wl *)
            LLMServices`Chat[ messages, LLMConfiguration @ $generatorLLMConfig ],
            AssociationQ,
            "Response"
        ];

        content = ConfirmBy[ response[ "Content" ], StringQ, "Content" ];

        ConfirmMatch[
            DeleteCases[ StringTrim @ StringSplit[ content, "\n" ], "[NONE]"|"" ],
            { ___String },
            "Queries"
        ]
    ],
    throwInternalFailure
];

generateSuggestedQueries // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$allQueries*)
$allQueries := $allQueries = Union @ RelatedWolframAlphaQueries @ All;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAllWolframAlphaResults*)
getAllWolframAlphaResults // beginDefinition;

getAllWolframAlphaResults[ queries: { ___String } ] := Enclose[
	Module[ { results, submitTime, tasks, waitTime, waitResult, formatTime, strings },
		results = <| |>;
		results[ "Timing" ] = <| |>;
		results[ "Queries" ] = AssociationMap[ <| "Timing" -> <| |> |> &, queries ];

		{ submitTime, tasks } = ConfirmMatch[
			AbsoluteTiming @ asyncWAInfo[ results[ "Queries" ], queries ],
			{ _Real, { ___TaskObject } },
			"Submit"
		];

		{ waitTime, waitResult } = ConfirmMatch[
			AbsoluteTiming @ TaskWait[ tasks, TimeConstraint -> 30 ],
			{ _Real, { ___ } },
			"TaskWait"
		];

		{ formatTime, strings } = ConfirmMatch[
			AbsoluteTiming @ KeyValueMap[ getWolframAlphaResult, results[ "Queries" ] ],
			{ _Real, { __String } },
			"Formatting"
		];

		results[ "Timing", "Submit"     ] = submitTime;
		results[ "Timing", "TaskWait"   ] = waitTime;
		results[ "Timing", "Formatting" ] = formatTime;

		$lastAsyncResults = results;
		strings
	],
	throwInternalFailure
];

getAllWolframAlphaResults // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*asyncWAInfo*)
asyncWAInfo // beginDefinition;
asyncWAInfo // Attributes = { HoldFirst };
asyncWAInfo[ assoc_, queries: { ___String } ] := submitQuery[ assoc ] /@ queries;
asyncWAInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*submitQuery*)
submitQuery // beginDefinition;
submitQuery // Attributes = { HoldFirst };

submitQuery[ assoc_ ] := submitQuery[ assoc, # ] &;

submitQuery[ assoc_, query_String ] :=
	Module[ { url, urlTiming, task, taskTiming },

		{ urlTiming, url } = AbsoluteTiming @ getURL @ query;


		{ taskTiming, task } = AbsoluteTiming @ URLSubmit[
			url,
			HandlerFunctionsKeys -> { "StatusCode", "BodyByteArray" },
			HandlerFunctions     -> <| "TaskFinished" -> setResult[ assoc, query, AbsoluteTime[ ] ] |>,
			TimeConstraint       -> 30
		];

		assoc[ query, "Query" ] = query;
		assoc[ query, "URL"   ] = url;
		assoc[ query, "Task"  ] = task;

		assoc[ query, "Timing", "URL"  ] = urlTiming;
		assoc[ query, "Timing", "Task" ] = taskTiming;

		task
	];

submitQuery // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getURL*)
getURL // beginDefinition;

getURL[ query_String ] := getURL[ query ] = WolframAlpha[
	query,
	"URL",
	PodStates -> { "Step-by-step solution" },
	Method    -> { "Formats" -> { "cell", "computabledata", "plaintext" } }
];

getURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setResult*)
setResult // beginDefinition;
setResult // Attributes = { HoldFirst };

setResult[ assoc_, query_, submitTime_ ] :=
	catchAlways @ setResult[ assoc, query, submitTime, # ] &;

setResult[
	assoc_,
	query_String,
	submitTime_? NumberQ,
	as: KeyValuePattern @ { "StatusCode" -> 200, "BodyByteArray" -> bytes_ByteArray }
] := Enclose[
    Module[ { info, infoTiming, string, stringTiming },

		assoc[ query, "Timing", "Response" ] = AbsoluteTime[ ] - submitTime;

		{ infoTiming, info } = ConfirmMatch[
			AbsoluteTiming @ byteArrayToPodInformation @ bytes,
			{ _Real, KeyValuePattern @ { } },
			"PodInfo"
		];

		{ stringTiming, string } = ConfirmMatch[
			AbsoluteTiming @ getWolframAlphaText[ query, True, info ],
			{ _Real, _String? StringQ },
			"String"
		];

		assoc[ query, "PodInfo"           ] = info;
		assoc[ query, "Timing", "PodInfo" ] = infoTiming;
		assoc[ query, "String"            ] = string;
		assoc[ query, "Timing", "String"  ] = stringTiming;
	],
    throwInternalFailure
];

setResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*byteArrayToPodInformation*)
byteArrayToPodInformation // beginDefinition;

byteArrayToPodInformation[ ba_ByteArray ] := Enclose[
    Module[ { string, rawXML, xml, processed, info },

        loadWolframAlphaClient[ ];

        string    = ConfirmBy[ ByteArrayToString @ ba, StringQ, "XMLString" ];
        rawXML    = ConfirmMatch[ ImportString[ string, "XML", "NormalizeWhitespace" -> False ], $$xml, "RawXML" ];
        xml       = ConfirmMatch[ normalizeWhitespace @ rawXML, $$xml, "XML" ];
        processed = ConfirmMatch[ expandData @ xml, $$xml, "ProcessedXML" ];

        info = ConfirmMatch[
            WolframAlpha[ "dummy", "PodInformation", Method -> { "ProcessedXML" -> processed } ],
            { (Rule|RuleDelayed)[ _, _ ]... }
        ];

        Cases[ info, (Rule|RuleDelayed)[ { _, "Title"|"Plaintext"|"ComputableData"|"Content" }, _ ] ]
    ],
    throwInternalFailure
];

byteArrayToPodInformation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getWolframAlphaResult*)
getWolframAlphaResult // beginDefinition;

getWolframAlphaResult[ query_String, KeyValuePattern[ "String" -> res_String ] ] :=
    TemplateApply[ $wolframAlphaResultTemplate, StringTrim @ { query, res } ];

getWolframAlphaResult[ query_String, _ ] :=
    TemplateApply[ $wolframAlphaResultTemplate, { StringTrim @ query, Missing[ "No Results Found" ] } ];

getWolframAlphaResult // endDefinition;

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
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
