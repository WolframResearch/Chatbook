(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
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

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

$fitQuery = "How can I analyze the cycling power data in a FIT file?";
$catalogLine = StartOfString ~~ ("paclet:"|"resource:") ~~ Except[ WhitespaceCharacter ].. ~~ " - " ~~ __ ~~ EndOfString;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CatalogPrompt*)
VerificationTest[
    catalog = RelatedDocumentation[ $fitQuery, "CatalogPrompt", MaxItems -> 30 ],
    _String? (StringStartsQ[ "Here are Wolfram documentation snippets that might be relevant" ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-CatalogPrompt"
]

VerificationTest[
    catalogURIs = $ChatHandlerData[ "RelatedDocumentationCatalog", "Results" ],
    { __String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-CatalogPrompt-HandlerData"
]

VerificationTest[
    lines = StringSplit[
        RelatedDocumentation[ $fitQuery, "CatalogPrompt", MaxItems -> 30, "PromptHeader" -> False ],
        "\n"
    ],
    { __String? (StringMatchQ[ $catalogLine ]) },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-CatalogPrompt-NoHeader"
]

(* The header is followed by the same lines: *)
VerificationTest[
    StringEndsQ[ catalog, "\n\n" <> StringRiffle[ lines, "\n" ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-CatalogPrompt-HeaderAndLines"
]

(* Resource URIs are shortened, and the handler data has the full URIs of the lines: *)
VerificationTest[
    {
        AnyTrue[ lines, StringStartsQ[ "resource:function/FITImport#" ] ],
        AnyTrue[ lines, StringContainsQ[ "https://" ] ],
        AnyTrue[ catalogURIs, StringStartsQ[ "https://resources.wolframcloud.com/FunctionRepository/resources/" ] ],
        Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`shortenSnippetURI /@ catalogURIs ===
            (First @ StringSplit[ #, " - ", 2 ] &) /@ lines
    },
    { True, False, True, True },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-CatalogPrompt-ShortURIs"
]

(* Outside of a chat no tools are selected, so the header doesn't mention the documentation searcher: *)
VerificationTest[
    { StringContainsQ[ catalog, "documentation_lookup tool" ], StringContainsQ[ catalog, "searcher" ] },
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-CatalogPrompt-ToolNames"
]

(* The header uses the tool names that the model sees with each tool method: *)
VerificationTest[
    Function[ method,
        Block[
            {
                Wolfram`Chatbook`Common`$selectedTools = KeyTake[
                    $DefaultTools,
                    { "DocumentationLookup", "DocumentationSearcher" }
                ],
                $ChatHandlerData = <| "ChatNotebookSettings" -> <| "ToolMethod" -> method |> |>
            },
            Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`prependCatalogHeader[ "LINES" ]
        ]
    ] /@ { "Simple", "Service" },
    {
        _String? (
            StringContainsQ[ #, "with the /doc_lookup tool" ] &&
            StringContainsQ[ #, "with the /doc_search tool" ] &&
            StringEndsQ[ #, ".\n\nLINES" ] &
        ),
        _String? (
            StringContainsQ[ #, "with the documentation_lookup tool" ] &&
            StringContainsQ[ #, "with the documentation_searcher tool" ] &
        )
    },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-CatalogPrompt-ToolMethods"
]

(* The catalog lists the same candidates as the unfiltered "Prompt", whose output is unchanged: *)
VerificationTest[
    prompt = Block[ { Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`Private`$snippetDebug = False },
        RelatedDocumentation[ $fitQuery, "Prompt", MaxItems -> 30, "FilterResults" -> False ]
    ],
    _String? (StringStartsQ[ "Here are some Wolfram documentation snippets that you may find useful.\n\n======\n\n" ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-CatalogPrompt-Prompt"
]

VerificationTest[
    {
        AllTrue[ catalogURIs, StringContainsQ[ prompt, "\n" <> # <> "\n" ] & ],
        StringContainsQ[ prompt, "resource:" ],
        StringContainsQ[ prompt, "\n\n======\n\n# WFR > FITImport > " ]
    },
    { True, False, True },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-CatalogPrompt-SameCandidates"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedDocumentationList Prompt Generator*)
$generatorMessages = { <| "Role" -> "User", "Content" -> $fitQuery |> };

VerificationTest[
    Wolfram`Chatbook`Common`$defaultPromptGenerators[ "RelatedDocumentationList" ],
    HoldPattern @ LLMPromptGenerator[ KeyValuePattern[ "Name" -> "RelatedDocumentationList" ], ___ ],
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentationList-Registered"
]

(* With the DocumentationLookup tool, the generator gives a catalog: *)
VerificationTest[
    Block[
        { Wolfram`Chatbook`PromptGenerators`DefaultPromptGenerators`Private`relatedDocumentationGenerator = "Fallback" & },
        Wolfram`Chatbook`Common`withChatState @ Block[
            { Wolfram`Chatbook`Common`$selectedTools = KeyTake[ $DefaultTools, { "DocumentationLookup" } ] },
            Wolfram`Chatbook`PromptGenerators`DefaultPromptGenerators`Private`relatedDocumentationListGenerator @
                $generatorMessages
        ]
    ],
    _String? (StringStartsQ[ "Here are Wolfram documentation snippets that might be relevant" ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentationList-Catalog"
]

(* Without it (e.g. tools are disabled, or the persona doesn't have it), it does what "RelatedDocumentation" does: *)
VerificationTest[
    Block[
        { Wolfram`Chatbook`PromptGenerators`DefaultPromptGenerators`Private`relatedDocumentationGenerator = "Fallback" & },
        Wolfram`Chatbook`Common`withChatState @ Block[
            { Wolfram`Chatbook`Common`$selectedTools = KeyTake[ $DefaultTools, { "DocumentationSearcher" } ] },
            Wolfram`Chatbook`PromptGenerators`DefaultPromptGenerators`Private`relatedDocumentationListGenerator @
                $generatorMessages
        ]
    ],
    "Fallback",
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentationList-Fallback"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Settings*)
$generatorNames = Wolfram`Chatbook`PromptGenerators`DefaultPromptGenerators`Private`getPromptGeneratorName;

resolvedPersona[ persona_ ] := Wolfram`Chatbook`Common`withChatState @ Module[ { settings },
    settings = Wolfram`Chatbook`Common`resolveAutoSettings @ Wolfram`Chatbook`Common`mergeChatSettings @ {
        Wolfram`Chatbook`Common`$defaultChatSettings,
        <| "LLMEvaluator" -> persona, "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |> |>
    };
    {
        $generatorNames /@ settings[ "PromptGenerators" ],
        Wolfram`Chatbook`Common`toolSelectedQ[ "DocumentationLookup" ]
    }
];

(* Personas with tools get the catalog and the DocumentationLookup tool: *)
VerificationTest[
    resolvedPersona /@ { "CodeAssistant", "NotebookAssistant", "WolframAIAssistant", "Wolfie", "Birdnardo" },
    ConstantArray[ { { "RelatedDocumentationList" }, True }, 5 ],
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentationList-Personas"
]

(* CodeWriter has no tools, so its generator falls back to full snippets: *)
VerificationTest[
    resolvedPersona[ "CodeWriter" ],
    { { "RelatedDocumentationList" }, False },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentationList-Personas-CodeWriter"
]

(* The Notebook Assistant runs one documentation generator, and has the DocumentationLookup tool: *)
VerificationTest[
    Wolfram`Chatbook`Common`withChatState @ Module[ { settings },
        settings = Wolfram`Chatbook`Common`resolveAutoSettings @ Wolfram`Chatbook`Common`mergeChatSettings @ {
            Wolfram`Chatbook`Common`$defaultChatSettings,
            Wolfram`Chatbook`ChatModes`Common`$notebookAssistanceWorkspaceSettings,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |> |>
        };
        {
            $generatorNames /@ settings[ "PromptGenerators" ],
            Wolfram`Chatbook`Common`toolSelectedQ[ "DocumentationLookup" ]
        }
    ],
    { { "RelatedDocumentationList" }, True },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentationList-NotebookAssistance"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompt Generators Run Once*)

(* Gives the number of times a counting prompt generator ran, and the generated prompts in each request. These tests are
   for the generated prompts without prompt cache optimization (see Tests/PromptCache.wlt for the other case): *)
countGenerators // Attributes = { HoldFirst };
countGenerators[ eval_ ] := Wolfram`Chatbook`Common`withChatState @ Module[ { calls, generator, settings, results },
    calls     = 0;
    generator = LLMPromptGenerator[ "Generated prompt " <> ToString[ ++calls ] &, "Messages" ];
    settings  = Wolfram`Chatbook`Common`resolveAutoSettings @ Wolfram`Chatbook`Common`mergeChatSettings @ {
        Wolfram`Chatbook`Common`$defaultChatSettings,
        <|
            "LLMEvaluator"            -> "PlainChat",
            "Model"                   -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>,
            "PromptCacheOptimization" -> False,
            "PromptGenerators"        -> { generator }
        |>
    };
    results = Block[ { $CurrentChatSettings = settings, $settings = settings }, eval ];
    {
        calls,
        Cases[ #, KeyValuePattern[ "Content" -> s_String? (StringStartsQ[ "Generated prompt" ]) ] :> s ] & /@ results
    }
];

$firstMessages = {
    <| "Role" -> "System", "Content" -> "System prompt" |>,
    <| "Role" -> "User"  , "Content" -> "Hello"         |>
};

(* The request after a tool call gets the messages of the first request back (see toolEvaluation in SendChat.wl), and
   reuses their generated prompts instead of running the prompt generators again: *)
VerificationTest[
    countGenerators @ Module[ { first, data, second },
        { first, data } = Reap[
            Wolfram`Chatbook`Common`constructMessages[ $settings, $firstMessages ],
            Wolfram`Chatbook`Common`$chatDataTag
        ];
        second = Wolfram`Chatbook`Common`constructMessages[
            $settings,
            Join[
                First[ Flatten @ data ][ "Messages" ],
                {
                    <| "Role" -> "Assistant", "Content" -> "/wl\n1 + 1\n/exec" |>,
                    <| "Role" -> "System", "Content" -> "2", "ToolResponse" -> True |>
                }
            ]
        ];
        { first, second }
    ],
    { 1, { { "Generated prompt 1" }, { "Generated prompt 1" } } },
    SameTest -> MatchQ,
    TestID   -> "ConstructMessages-PromptGeneratorsRunOnce"
]

(* A new chat request runs them again: *)
VerificationTest[
    countGenerators @ Table[ Wolfram`Chatbook`Common`constructMessages[ $settings, $firstMessages ], 2 ],
    { 2, { { "Generated prompt 1" }, { "Generated prompt 2" } } },
    SameTest -> MatchQ,
    TestID   -> "ConstructMessages-PromptGeneratorsNewRequest"
]

(* :!CodeAnalysis::EndBlock:: *)
