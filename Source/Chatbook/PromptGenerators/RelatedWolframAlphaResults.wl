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
$multimodal         = True;
$keepAllImages      = False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$$count = _Integer | UpTo[ _Integer ];
$$xml   = HoldPattern[ _XMLElement | XMLObject[ _ ][ ___ ] ];

(* cSpell: ignore expressiontypes, imagesource, microsources, userinfoused *)
$$ignoredXMLTag = Alternatives[
    "datasources",
    "definitions",
    "expressiontypes",
    "imagesource",
    "infos",
    "microsources",
    "notes",
    "sources",
    "states",
    "userinfoused"
];

$$ws = ___String? (StringMatchQ[ WhitespaceCharacter... ]);

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedWolframAlphaResults*)
RelatedWolframAlphaResults // beginDefinition;
RelatedWolframAlphaResults // Options = {
    "LLMEvaluator"      -> Automatic,
    "MaxItems"          -> Automatic,
    "Method"            -> Automatic,
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

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Prompt*)
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

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Content*)
(* TODO *)

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
(*$citationHint*)
$citationHint = "

If you use any information from these results, you should cite the relevant URL with a markdown link in your response.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$markdownHint*)
$markdownHint = "

======

You can use any markdown links from these results in your response to show images, \
formatted expressions, etc. to the user." <> $citationHint;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$wolframAlphaResultTemplate*)
$wolframAlphaResultTemplate = StringTemplate[ "\
<query>`1`</query>
<url>`2`</url>
<results>
`3`
</results>" ];

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
                ConfirmBy[ $citationHint, StringQ, "CitationHint" ]
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
    TemplateApply[
        $wolframAlphaResultTemplate,
        { StringTrim @ query, makeWolframAlphaURL @ query, StringTrim @ res }
    ];

getWolframAlphaResult[ query_String, _ ] :=
    TemplateApply[
        $wolframAlphaResultTemplate,
        { StringTrim @ query, makeWolframAlphaURL @ query, Missing[ "No Results Found" ] }
    ];

getWolframAlphaResult // endDefinition;

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
(*submitXMLRequest*)
submitXMLRequest // beginDefinition;
submitXMLRequest // Attributes = { HoldFirst };

submitXMLRequest[ assoc_ ] :=
    submitXMLRequest[ assoc, # ] &;

submitXMLRequest[ assoc_, query_String ] := Enclose[
    Module[ { request, task },

        If[ ! AssociationQ @ assoc, assoc = <| |> ];
        If[ ! AssociationQ @ assoc @ query, assoc @ query = <| |> ];
        assoc[ query, "Query" ] = query;

        request = HTTPRequest[
            "https://api.wolframalpha.com/v2/query",
            <|
                "Query" -> {
                    "input"       -> query,
                    "reinterpret" -> False,
                    "appid"       -> ConfirmBy[ $wolframAlphaAppID, StringQ, "AppID" ],
                    "format"      -> "image,plaintext",
                    "output"      -> "xml"
                }
            |>
        ];

        task = URLSubmit[
            request,
            HandlerFunctionsKeys -> { "StatusCode", "BodyByteArray" },
            HandlerFunctions     -> <| "TaskFinished" -> setXMLResult @ assoc @ query |>,
            TimeConstraint       -> 30
        ];

        task
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

setXMLResult[ result_, as: KeyValuePattern[ "BodyByteArray" -> bytes_ByteArray ] ] :=
    Module[ { xmlString, xml, warnings, processed },
        xmlString = ByteArrayToString @ bytes;
        xml = ImportString[ xmlString, { "XML", "XMLObject" }, "NormalizeWhitespace" -> False ];
        warnings = Internal`Bag[ ];
        processed = Block[ { $warnings = warnings }, processXML @ xml ];
        If[ ! AssociationQ @ result, result = <| |> ];
        result = <| result, as, "Content" -> processed, "Warnings" -> Internal`BagPart[ warnings, All ] |>
    ];

setXMLResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processXML*)
processXML // beginDefinition;

processXML[ xml_ ] := Enclose[
    Catch @ Module[ { parsed, pods, markdown, data },

        parsed = parseXML @ xml;
        If[ MatchQ[ parsed, KeyValuePattern[ "Type" -> "Error" ] ], Throw @ parsed ];
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

parsePodContent[ XMLElement[ "mathml", _, xml_ ] ] :=
    parseMathML @ xml;

parsePodContent[ XMLElement[ $$ignoredXMLTag, _, _ ] ] :=
    { };

parsePodContent[ _String ] :=
    { };

parsePodContent // endDefinition;

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
(* ::Subsubsection::Closed:: *)
(*parseAssumptions*)
parseAssumptions // beginDefinition;
parseAssumptions[ ___ ] := { }; (* TODO: Implement *)
parseAssumptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
