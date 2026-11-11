(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

VerificationTest[
    Context @ RelatedDocumentation,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentationContext"
]

$defaultTestOptions =
    If[ StringQ @ Environment[ "GITHUB_ACTIONS" ],
        LLMEvaluator -> <| "Model" -> { "OpenAI", "gpt-4o-mini" }, Authentication -> Automatic |>,
        Sequence @@ { }
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedDocumentation*)
VerificationTest[
    urls = RelatedDocumentation[ "What's the biggest pokemon?" ],
    { URL[ _String ].. },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs"
]

VerificationTest[
    FileNames[ All, ChatbookFilesDirectory[ "VectorDatabases" ], Infinity ],
    { Repeated[ _String, { 40, Infinity } ] },
    SameTest -> MatchQ,
    TestID   -> "VectorDatabase-Files"
]

VerificationTest[
    Length @ Select[
        First /@ urls,
        StringStartsQ @ StringExpression[
            "paclet:ref/",
            "interpreter"|"entity"|"textcontent",
            "/",
            "Pokemon"|"ComputedPokemon",
            "#"
        ]
    ],
    _Integer? (GreaterThan[ 5 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs-Count"
]

VerificationTest[
    snippets = RelatedDocumentation[ "What's the biggest pokemon?", "Snippets" ],
    { __String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets"
]

VerificationTest[
    Total @ StringCount[ snippets, "Entity[\"Pokemon\"," ],
    _Integer? (GreaterThan[ 5 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets-Count"
]

VerificationTest[
    urls = RelatedDocumentation[ "What's the biggest pokemon?", Automatic, 3, "Sources" -> { "Documentation" } ],
    { URL[ _String ], URL[ _String ], URL[ _String ] },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs-Count"
]

VerificationTest[
    AllTrue[ First /@ urls, StringStartsQ[ "paclet:ref/" ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs-Match"
]

VerificationTest[
    RelatedDocumentation[ "What's the biggest pokemon?", "Snippets", 3 ],
    { _String, _String, _String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets-Count"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Prompt*)
VerificationTest[
    prompt = RelatedDocumentation[
        "What's the 123456789th prime?",
        "Prompt",
        "FilterResults" -> False,
        "MaxItems"      -> 20
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt"
]

VerificationTest[
    StringCount[ prompt, "paclet:ref/Prime#" ],
    _Integer? Positive,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt-Count"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Message Input*)
VerificationTest[
    prompt = RelatedDocumentation[
        {
            <| "Role" -> "User"     , "Content" -> "What's the 123456789th prime?"  |>,
            <| "Role" -> "Assistant", "Content" -> "```wl\nPrime[123456789]\n```"   |>,
            <| "Role" -> "User"     , "Content" -> "What about the one after that?" |>
        },
        "Prompt",
        "FilterResults" -> False,
        "MaxItems"      -> 20
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt-Messages"
]

VerificationTest[
    StringCount[ prompt, { "paclet:ref/Prime#", "paclet:ref/NextPrime#" } ],
    _Integer? (GreaterEqualThan[ 5 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt-Messages-Count"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Selection Prompt*)
VerificationTest[
    prompt = Block[
        { Wolfram`Chatbook`Common`$contextPrompt = "```wl\nIn[1]:= Prime[123456789]\nOut[1]= 2543568463\n```" },
        RelatedDocumentation[
            { <| "Role" -> "User", "Content" -> "What does this do?" |> },
            "Prompt",
            "FilterResults" -> False,
            "MaxItems"      -> 20
        ]
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt-Selection"
]

VerificationTest[
    StringCount[ prompt, "paclet:ref/Prime#" ],
    _Integer? (GreaterEqualThan[ 2 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt-Selection-Count"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Regression Tests*)
VerificationTest[
    Take[ RelatedDocumentation[ { <| "Role" -> "User", "Content" -> "Hello" |> } ], UpTo[ 30 ] ][[ All, 1 ]],
    { __String? (StringFreeQ[ "$Username" ]) },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Regression-UserPrefix"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Vector Database Tests*)

(* These ensure the source selector and each component vector database is working properly. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DataRepositoryURIs*)
VerificationTest[
    RelatedDocumentation[ "Show me a map of meteorite impacts", "URIs", 5 ],
    {
        ___,
        URL[ _String? (StringStartsQ[ "https://datarepository.wolframcloud.com/resources/Meteorite-Landings#" ]) ],
        ___
    },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-DataRepositoryURIs-1"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DocumentationURIs*)
VerificationTest[
    RelatedDocumentation[ "What's the 123456789th prime?", "URIs", 5 ],
    { ___, URL[ _String? (StringStartsQ[ "paclet:ref/Prime#" ]) ], ___ },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-DocumentationURIs-1"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*EntityValues*)
VerificationTest[
    SelectFirst[
        RelatedDocumentation[ "What are the biggest craters from asteroid strikes?", "Snippets", 5 ],
        StringContainsQ @ StringExpression[
            "EntityClass[\"EarthImpact\", {EntityProperty[\"EarthImpact\", \"Diameter\"] -> TakeLargest[",
            DigitCharacter..,
            "]}]"
        ]
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-EntityValues-1"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FunctionRepositoryURIs*)
VerificationTest[
    RelatedDocumentation[ "What's the resistance of a red green blue resistor?", "URIs", 5 ],
    {
        ___,
        URL[ _String? (StringContainsQ[ "/FromResistorColorCode#" ]) ],
        ___
    },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-FunctionRepositoryURIs-1"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*NeuralNetRepositoryURIs*)
VerificationTest[
    SelectFirst[
        RelatedDocumentation[
            "I want to run some text generation experiments with GPT2. Can you tell me how I can get started?",
            "Snippets",
            5
        ],
        StringContainsQ[ "GPT2 Transformer Trained on WebText Data" ]
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-NeuralNetRepositoryURIs-1"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*PacletRepositoryURIs*)
VerificationTest[
    SelectFirst[
        RelatedDocumentation[
            "How can I automatically run tests when I open a PR for my paclet on GitHub?",
            "Snippets",
            5
        ],
        StringContainsQ[ "Wolfram`PacletCICD`CheckPaclet" ]
    ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-PacletRepositoryURIs-1"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Regression Tests*)
(* Ensure that asynchronous tasks spawned by RelatedDocumentation work in an asynchronous environment. *)
VerificationTest[
    TaskWait @ SessionSubmit[
        res = RelatedDocumentation[ "What's the 123456789th prime?", "Prompt", $defaultTestOptions ]
    ];
    res,
    _String? (StringContainsQ[ "Prime" ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-SessionSubmit"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DocumentationLookup*)
VerificationTest[
    $DefaultTools[ "DocumentationLookup" ][ <| "ids" -> "AstroGraphics" |> ],
    _String? (StringContainsQ[ "# AstroGraphics\n\nAstroGraphics[" ]),
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-Markdown"
]

VerificationTest[
    StringSplit[
        $DefaultTools[ "DocumentationLookup" ][ <| "ids" -> { "Plot", "paclet:ref/ListPlot" } |> ],
        "\n\n======\n\n"
    ],
    { _String? (StringStartsQ[ "# Plot\n" ]), _String? (StringStartsQ[ "# ListPlot\n" ]) },
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-Markdown-Multiple"
]

VerificationTest[
    $DefaultTools[ "DocumentationLookup" ][ <| "ids" -> "Pi" |> ],
    _String? (StringContainsQ[ "Pi is \[Pi], with numerical value \[TildeEqual]3.14159" ]),
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-Markdown-UTF8-GH#1744"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

VerificationTest[
    docLookup = $DefaultTools[ "DocumentationLookup" ][ <| "ids" -> # |> ] &;
    lookupItems = StringSplit[ docLookup @ #, "\n\n======\n\n" ] &;
    $frPage = "https://resources.wolframcloud.com/FunctionRepository/resources/FITImport";
    $frSnippet = First @ Keys @ Wolfram`Chatbook`Common`getPageSnippets @ $frPage;
    $tableSnippet = First @ Keys @ Wolfram`Chatbook`Common`getPageSnippets[ "paclet:ref/Table" ];
    $entitySnippet = First @ Keys @ Wolfram`Chatbook`Common`getPageSnippets[ "paclet:ref/entity/Planet" ];
    $pacletPage = "https://paclets.com/RickHennigan/ComputationalFitness";
    { $frSnippet, $tableSnippet, $entitySnippet },
    { _String? (StringStartsQ[ $frPage <> "#" ]), _String? (StringStartsQ[ "paclet:ref/Table#" ]), _String },
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-Definitions"
]

VerificationTest[
    Wolfram`Chatbook`Tools`Private`toDocumentationURI /@ {
        "Table",
        "System`Table",
        "guide/ListManipulation",
        "https://reference.wolfram.com/language/ref/Table.html",
        "https://reference.wolfram.com/language/ref/Table.html#23775",
        "https://reference.wolfram.com/language/ref/Table#23775",
        "resource:function/FITImport#334957977",
        "resource:data/Sample-Data-Fishers-Irises",
        "resource:nn/ResNet-50-Trained-on-ImageNet-Competition-Data",
        "resource:paclet/RickHennigan/ComputationalFitness/ref/FITImport.html",
        "https://paclets.com/RickHennigan/ComputationalFitness"
    },
    {
        "paclet:ref/Table",
        "paclet:ref/Table",
        "paclet:guide/ListManipulation",
        "paclet:ref/Table",
        "paclet:ref/Table#23775",
        "paclet:ref/Table#23775",
        "https://resources.wolframcloud.com/FunctionRepository/resources/FITImport#334957977",
        "https://datarepository.wolframcloud.com/resources/Sample-Data-Fishers-Irises",
        "https://resources.wolframcloud.com/NeuralNetRepository/resources/ResNet-50-Trained-on-ImageNet-Competition-Data",
        "https://paclets.com/RickHennigan/ComputationalFitness/ref/FITImport.html",
        "https://paclets.com/RickHennigan/ComputationalFitness"
    },
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-URIs"
]

(* Snippet URIs give just that snippet, also in their short form: *)
VerificationTest[
    {
        docLookup @ $tableSnippet,
        docLookup @ StringReplace[ $frSnippet, $frPage -> "resource:function/FITImport" ]
    },
    {
        _String? (StringStartsQ[ "# Table" ~~ Except[ "\n" ]... ~~ "\n" <> $tableSnippet <> "\n\n" ]),
        _String? (StringStartsQ[ "# WFR > FITImport > " ~~ Except[ "\n" ].. ~~ "\n" <> $frSnippet <> "\n\n" ])
    },
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-Snippets"
]

(* Resource pages are made from their snippets, with sections from their breadcrumbs, and without images: *)
VerificationTest[
    page = docLookup[ "resource:function/FITImport" ];
    {
        StringStartsQ[ page, "# WFR > FITImport\n" <> $frPage <> "\n\n## Description\n\n" ],
        StringContainsQ[ page, "\n\n## Examples > Basic Examples\n\n" ],
        StringFreeQ[ page, "\n## Examples > Basic Examples > 2\n" ],
        StringFreeQ[ page, "MarkdownImageBox" | "attachment://" ],
        docLookup @ $frPage === page
    },
    { True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-ResourcePage"
]

(* Misses give NotFound for each id that isn't found, and other ids are not affected: *)
VerificationTest[
    lookupItems @ {
        $tableSnippet,
        "resource:function/FITImport",
        "NoSuchSymbolXYZ",
        "paclet:ref/Table#nosuchsnippet",
        "resource:function/NoSuchFunctionXYZ",
        "resource:function/NoSuchFunctionXYZ#1",
        "bogus id"
    },
    {
        _String? (StringContainsQ[ $tableSnippet ]),
        _String? (StringStartsQ[ "# WFR > FITImport\n" ]),
        "Missing[\"NotFound\", \"paclet:ref/NoSuchSymbolXYZ\"]",
        "Missing[\"NotFound\", \"paclet:ref/Table#nosuchsnippet\"]",
        "Missing[\"NotFound\", \"https://resources.wolframcloud.com/FunctionRepository/resources/NoSuchFunctionXYZ\"]",
        "Missing[\"NotFound\", \"https://resources.wolframcloud.com/FunctionRepository/resources/NoSuchFunctionXYZ#1\"]",
        "Missing[\"NotFound\", \"bogus id\"]"
    },
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-NotFound"
]

(* The same with the production value of $snippetDebug: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDebug = False },
        lookupItems @ { "paclet:ref/Table#nosuchsnippet", $tableSnippet }
    ],
    { "Missing[\"NotFound\", \"paclet:ref/Table#nosuchsnippet\"]", _String? (StringContainsQ[ $tableSnippet ]) },
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-NotFound-Production"
]

(* A page that couldn't be downloaded is tried again next time: *)
VerificationTest[
    {
        Block[
            {
                Wolfram`Chatbook`Common`$documentationMarkdownBaseURL =
                    "https://www.wolframcloud.com/obj/wolframai-content/NoSuchDirectory"
            },
            docLookup[ "Range" ]
        ],
        docLookup[ "Range" ]
    },
    { "Missing[\"NotFound\", \"paclet:ref/Range\"]", _String? (StringContainsQ[ "# Range\n" ]) },
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-NotFound-Not-Cached"
]

(* Entity values and paclets come with the instructions that the RAG prompt gives with them, once per call: *)
VerificationTest[
    {
        entityItems = lookupItems @ { $entitySnippet, $entitySnippet },
        pacletItems = lookupItems @ { $pacletPage, "resource:paclet/RickHennigan/ComputationalFitness/ref/FITImport.html" }
    },
    {
        {
            _String? (StringContainsQ[ $entitySnippet ]),
            _String? (StringContainsQ[ $entitySnippet ]),
            Wolfram`Chatbook`PromptGenerators`Common`getNamedSnippet[ "BasicEntityUsage" ],
            Wolfram`Chatbook`PromptGenerators`Common`getNamedSnippet[ "EntityValueInstructions" ]
        },
        {
            _String? (StringStartsQ[ "# Paclet Repository > RickHennigan/ComputationalFitness\n" ]),
            _String? (StringStartsQ[ "# Paclet Repository > RickHennigan/ComputationalFitness > FITImport\n" ]),
            _String? (StringStartsQ[ "# PacletSymbol" ~~ Except[ "\n" ]... ~~ "\npaclet:ref/PacletSymbol#1\n" ]),
            Wolfram`Chatbook`PromptGenerators`VectorDatabases`Private`$pacletRepositoryInstructions
        }
    },
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-Instructions"
]

VerificationTest[
    lookupItems[ "Table" ],
    { _String? (StringStartsQ[ "# Table\n" ]) },
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-No-Instructions"
]

(* Long pages are cut, and pages that use ExampleData files get the same hint as the RAG prompt. The hint only lists
   files that exist, and they ship with the documentation, which some installations (e.g. the CI engine) don't have: *)
VerificationTest[
    plotPage = docLookup[ "Plot" ];
    {
        StringLength @ plotPage <= Wolfram`Chatbook`Tools`Private`$maxPageLength + 20,
        StringEndsQ[ plotPage, "\n\n[Page truncated]" ],
        StringContainsQ[ docLookup[ "Import" ], "<system-hint>" ~~ ___ ~~ "\"ExampleData/rose.gif\"" ]
    },
    { True, True, StringQ @ FindFile[ "ExampleData/rose.gif" ] },
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-LongPages-ExampleData"
]

(* The tool's formatter shows each item, and doesn't fail on any output: *)
VerificationTest[
    Wolfram`Chatbook`Tools`Private`documentationSearchFormatter[ #, "Result" ] & /@ {
        docLookup @ { $tableSnippet, "resource:function/FITImport", "NoSuchSymbolXYZ" },
        StringRiffle[ pacletItems, "\n\n======\n\n" ],
        ""
    },
    { _Column? (Length @ First @ # === 3 &), _Column? (Length @ First @ # === 4 &), "" },
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-Formatter"
]

(* Freeform inputs in documentation results are formatted without Wolfram|Alpha calls (formatNLInputSlow). The same
   code in a chat response still gets them, even with the static code block cache from the tool call's formatting: *)
VerificationTest[
    $freeformCode = "```wl\nEntityValue[\[FreeformPrompt][\"domestic cat\"], \"Lifespan\"]\n```";
    $slowQueries  = { };
    Internal`InheritedBlock[ { Wolfram`Chatbook`Formatting`Private`formatNLInputSlow },
        (* Records the calls instead of making them: *)
        DownValues[ Wolfram`Chatbook`Formatting`Private`formatNLInputSlow ] = {
            HoldPattern @ Wolfram`Chatbook`Formatting`Private`formatNLInputSlow[ q_String ] :> (
                AppendTo[ $slowQueries, q ];
                Wolfram`Chatbook`Formatting`Private`formatNLInputFast @ q
            )
        };
        Block[
            {
                Wolfram`Chatbook`Common`$useStaticCodeBlockCache = True,
                Wolfram`Chatbook`Formatting`Private`$staticCodeBlockCache = <| |>
            },
            {
                Wolfram`Chatbook`Tools`Private`documentationSearchFormatter[
                    "# Example\npaclet:ref/Example#1\n\n" <> $freeformCode,
                    "Result"
                ],
                $slowQueries,
                FormatChatOutput @ $freeformCode,
                $slowQueries
            }
        ]
    ],
    { _Column? (! FreeQ[ #, "CalculateInput" ] &), { }, _RawBoxes, { "\"domestic cat\"" } },
    SameTest -> MatchQ,
    TestID   -> "DocumentationLookup-Formatter-FreeformPrompt"
]

(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FilterSnippets Response Cache*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* The LLM is mocked in these tests, and LLMKit is disabled so that no network requests are made for filtering: *)
cachedFilterResponse[ args___ ] :=
    Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`cachedFilterSnippetsResponse[ args ];

$filterCalls = 0;

$mockFilterLLM = Function[ { prompt, config }, "Computational\n5 Mock-" <> ToString[ ++$filterCalls ] ];

(* Selects the first two snippet IDs that are listed in the instructions: *)
$mockSelectionLLM = Function[ { prompt, config },
    $filterCalls++;
    StringJoin[
        "Computational\n",
        StringRiffle[
            "5 " <> # & /@ Take[
                StringSplit[ Last @ StringSplit[ prompt, "These are the available snippet IDs:\n" ], "\n" ],
                UpTo[ 2 ]
            ],
            "\n"
        ]
    ]
];

withMockFilterLLM // Attributes = { HoldFirst };

withMockFilterLLM[ eval_ ] := withMockFilterLLM[ eval, $mockFilterLLM ];

withMockFilterLLM[ eval_, mock_ ] := Block[
    {
        Wolfram`Chatbook`Common`llmSynthesize = mock,
        Wolfram`Chatbook`Common`$llmKit = False,
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$filterSnippetsResponseCache = <| |>,
        $filterCalls = 0
    },
    eval
];

filterCacheHits[ log_Internal`Bag ] :=
    Length @ Cases[ Internal`BagPart[ log, All ], KeyValuePattern[ "Tag" -> "FilterSnippetsCacheHit" ], Infinity ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cachedFilterSnippetsResponse*)
VerificationTest[
    withMockFilterLLM @ {
        cachedFilterResponse[ "instructions 1", <| |> ],
        cachedFilterResponse[ "instructions 1", <| |> ],
        $filterCalls
    },
    { "Computational\n5 Mock-1", "Computational\n5 Mock-1", 1 },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-Repeat"
]

VerificationTest[
    withMockFilterLLM @ Block[ { Wolfram`Chatbook`Common`$timingLog = Internal`Bag[ ] },
        cachedFilterResponse[ "instructions 1", <| |> ];
        cachedFilterResponse[ "instructions 1", <| |> ];
        filterCacheHits @ Wolfram`Chatbook`Common`$timingLog
    ],
    1,
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-Repeat-Timing"
]

VerificationTest[
    withMockFilterLLM @ {
        cachedFilterResponse[ "instructions 1", <| |> ],
        cachedFilterResponse[ "instructions 2", <| |> ],
        cachedFilterResponse[ "instructions 2", <| |> ],
        $filterCalls
    },
    { "Computational\n5 Mock-1", "Computational\n5 Mock-2", "Computational\n5 Mock-2", 2 },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-DifferentInstructions"
]

VerificationTest[
    withMockFilterLLM @ {
        cachedFilterResponse[ "instructions 1", <| |> ],
        cachedFilterResponse[ "instructions 1", <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o-mini" |> |> ],
        cachedFilterResponse[ "instructions 1", <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o-mini" |> |> ],
        $filterCalls
    },
    { "Computational\n5 Mock-1", "Computational\n5 Mock-2", "Computational\n5 Mock-2", 2 },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-DifferentModel"
]

VerificationTest[
    withMockFilterLLM[
        {
            Catch[ cachedFilterResponse[ "instructions 1", <| |> ], "MockFailure" ],
            cachedFilterResponse[ "instructions 1", <| |> ],
            cachedFilterResponse[ "instructions 1", <| |> ],
            $filterCalls
        },
        Function[ { prompt, config },
            If[ ++$filterCalls === 1, Throw[ "Failed", "MockFailure" ], "Computational\n5 Mock-" <> ToString @ $filterCalls ]
        ]
    ],
    { "Failed", "Computational\n5 Mock-2", "Computational\n5 Mock-2", 2 },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-FailureNotCached"
]

VerificationTest[
    withMockFilterLLM[
        {
            cachedFilterResponse[ "instructions 1", <| |> ],
            cachedFilterResponse[ "instructions 1", <| |> ],
            cachedFilterResponse[ "instructions 1", <| |> ],
            $filterCalls
        },
        Function[ { prompt, config },
            If[ ++$filterCalls === 1, $Failed, "Computational\n5 Mock-" <> ToString @ $filterCalls ]
        ]
    ],
    { $Failed, "Computational\n5 Mock-2", "Computational\n5 Mock-2", 2 },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-NonStringNotCached"
]

VerificationTest[
    withMockFilterLLM @ Module[ { cache, first },
        Do[ cachedFilterResponse[ "instructions " <> ToString @ i, <| |> ], { i, 70 } ];
        cache = Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$filterSnippetsResponseCache;
        first = cachedFilterResponse[ "instructions 1", <| |> ];
        { Length @ cache, cachedFilterResponse[ "instructions 70", <| |> ], first, $filterCalls }
    ],
    { 64, "Computational\n5 Mock-70", "Computational\n5 Mock-71", 71 },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-Bounded"
]

VerificationTest[
    withMockFilterLLM @ Block[
        { Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$filterSnippetsCacheSize = 0 },
        cachedFilterResponse[ "instructions 1", <| |> ];
        cachedFilterResponse[ "instructions 1", <| |> ];
        $filterCalls
    ],
    2,
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-Disabled"
]

(* Hits still resolve the filtering configuration, so a non-LLMKit authentication still turns off LLMKit for the chat: *)
VerificationTest[
    withMockFilterLLM @ Block[ { Wolfram`Chatbook`Common`$llmKitService = "LLMKitOpenAI" },
        Table[
            Wolfram`Chatbook`Common`withChatState[
                Wolfram`Chatbook`Common`$llmKit = True;
                {
                    cachedFilterResponse[ "instructions 1", <| "Authentication" -> Verbatim @ Automatic |> ],
                    Wolfram`Chatbook`Common`$llmKit,
                    $filterCalls
                }
            ],
            2
        ]
    ],
    { { "Computational\n5 Mock-1", False, 1 }, { "Computational\n5 Mock-1", False, 1 } },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-AuthenticationSideEffect"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*llmSynthesizeCacheKey*)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$llmKit = False },
        {
            Wolfram`Chatbook`Common`llmSynthesizeCacheKey[ "instructions", <| |> ],
            Wolfram`Chatbook`Common`llmSynthesizeCacheKey[ "instructions", <| |> ]
        }
    ],
    { key_Integer, key_Integer },
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesizeCacheKey-Stable"
]

(* The same model through a different authentication path is a different request: *)
VerificationTest[
    SameQ[
        Block[ { Wolfram`Chatbook`Common`$llmKit = True, Wolfram`Chatbook`Common`$llmKitService = "OpenAI" },
            Wolfram`Chatbook`Common`llmSynthesizeCacheKey[ "instructions", <| |> ]
        ],
        Block[ { Wolfram`Chatbook`Common`$llmKit = False },
            Wolfram`Chatbook`Common`llmSynthesizeCacheKey[ "instructions", <| |> ]
        ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesizeCacheKey-Authentication"
]

VerificationTest[
    SameQ[
        Block[ { Wolfram`Chatbook`Common`$llmKit = True, Wolfram`Chatbook`Common`$llmKitService = "LLMKitOpenAI" },
            Wolfram`Chatbook`Common`llmSynthesizeCacheKey[ "instructions", <| |> ]
        ],
        Block[ { Wolfram`Chatbook`Common`$llmKit = True, Wolfram`Chatbook`Common`$llmKitService = "LLMKitAnthropic" },
            Wolfram`Chatbook`Common`llmSynthesizeCacheKey[ "instructions", <| |> ]
        ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesizeCacheKey-Service"
]

(* LLMKit requests are made for the signed-in user, so responses are not reused across cloud accounts: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$llmKit = True, Wolfram`Chatbook`Common`$llmKitService = "LLMKitOpenAI" },
        SameQ[
            Block[ { $CloudUserID = "user1@example.com" },
                Wolfram`Chatbook`Common`llmSynthesizeCacheKey[ "instructions", <| |> ]
            ],
            Block[ { $CloudUserID = "user2@example.com" },
                Wolfram`Chatbook`Common`llmSynthesizeCacheKey[ "instructions", <| |> ]
            ]
        ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "LLMSynthesizeCacheKey-CloudUser"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*RelatedDocumentation*)
VerificationTest[
    withMockFilterLLM[
        Module[ { messages, prompt1, data1, calls1, prompt2, data2, hits },
            messages = { <| "Role" -> "User", "Content" -> "How do I make a 3D plot of a surface?" |> };
            prompt1  = RelatedDocumentation[ messages, "Prompt", "FilterResults" -> True, "MaxItems" -> 20 ];
            data1    = $ChatHandlerData[ "RelatedDocumentation" ];
            calls1   = $filterCalls;
            Block[ { Wolfram`Chatbook`Common`$timingLog = Internal`Bag[ ] },
                prompt2 = RelatedDocumentation[ messages, "Prompt", "FilterResults" -> True, "MaxItems" -> 20 ];
                hits    = filterCacheHits @ Wolfram`Chatbook`Common`$timingLog
            ];
            data2 = $ChatHandlerData[ "RelatedDocumentation" ];
            { calls1, $filterCalls, hits, prompt1 === prompt2, data1 === data2, prompt1, data1[ "Filtered" ] }
        ],
        $mockSelectionLLM
    ],
    { 1, 1, 1, True, True, _String? (StringStartsQ[ "IMPORTANT: " ]), { __String } },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-RelatedDocumentation-Repeat"
]

(* Sources used for citations are still added when the response comes from the cache: *)
VerificationTest[
    withMockFilterLLM[
        Wolfram`Chatbook`Common`withChatState @ Module[ { messages, sources1, sources2 },
            messages = { <| "Role" -> "User", "Content" -> "How do I make a 3D plot of a surface?" |> };
            RelatedDocumentation[ messages, "Prompt", "FilterResults" -> True, "MaxItems" -> 20 ];
            sources1 = Wolfram`Chatbook`Common`$sources;
            Wolfram`Chatbook`Common`$sources = <| |>;
            RelatedDocumentation[ messages, "Prompt", "FilterResults" -> True, "MaxItems" -> 20 ];
            sources2 = Wolfram`Chatbook`Common`$sources;
            { $filterCalls, sources1 === sources2, sources1 }
        ],
        $mockSelectionLLM
    ],
    { 1, True, _Association? (Length @ # > 0 &) },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-RelatedDocumentation-Sources"
]

VerificationTest[
    withMockFilterLLM[
        Module[ { prompt1, prompt2 },
            prompt1 = RelatedDocumentation[
                { <| "Role" -> "User", "Content" -> "How do I make a 3D plot of a surface?" |> },
                "Prompt",
                "FilterResults" -> True,
                "MaxItems"      -> 20
            ];
            prompt2 = RelatedDocumentation[
                {
                    <| "Role" -> "User"     , "Content" -> "How do I make a 3D plot of a surface?"         |>,
                    <| "Role" -> "Assistant", "Content" -> "Use Plot3D[Sin[x y], {x, -2, 2}, {y, -2, 2}]." |>,
                    <| "Role" -> "User"     , "Content" -> "Can I color it by height?"                     |>
                },
                "Prompt",
                "FilterResults" -> True,
                "MaxItems"      -> 20
            ];
            { $filterCalls, prompt1, prompt2 }
        ],
        $mockSelectionLLM
    ],
    { 2, _String, _String },
    SameTest -> MatchQ,
    TestID   -> "FilterSnippetsCache-RelatedDocumentation-DifferentTranscript"
]

(* :!CodeAnalysis::EndBlock:: *)
