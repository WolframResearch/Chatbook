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
    Context @ GenerateLLMConfiguration,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "GenerateLLMConfigurationContext"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GenerateLLMConfiguration*)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
VerificationTest[
    config = Quiet[ GenerateLLMConfiguration[ ], LLMServices`Defaults`Private`LLMFunctions::llmrstrt ],
    HoldPattern @ LLMConfiguration[ _Association? AssociationQ, ___ ],
    SameTest -> MatchQ,
    TestID   -> "NoArgs"
]
(* :!CodeAnalysis::EndBlock:: *)

VerificationTest[
    SelectFirst[ config[ "Prompts" ], StringQ ],
    _String? (StringContainsQ[ "Wolfram AI Assistant" ]),
    SameTest -> MatchQ,
    TestID   -> "NoArgs-Prompt"
]

VerificationTest[
    SelectFirst[ GenerateLLMConfiguration[ "NotebookAssistant" ][ "Prompts" ], StringQ ],
    _String? (StringContainsQ[ "Notebook Assistant" ]),
    SameTest -> MatchQ,
    TestID   -> "Named-Prompt-1"
]

VerificationTest[
    SelectFirst[ GenerateLLMConfiguration[ "Birdnardo" ][ "Prompts" ], StringQ ],
    _String? (StringContainsQ[ "Birdnardo" ]),
    SameTest -> MatchQ,
    TestID   -> "Named-Prompt-2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tools*)
VerificationTest[
    Sort[ #[ "Data" ][ "CanonicalName" ] & /@ GenerateLLMConfiguration[ "NotebookAssistant" ][ "Tools" ] ],
    {
        "CreateNotebook",
        "DocumentationLookup",
        "DocumentationSearcher",
        "WebFetcher",
        "WolframAlpha",
        "WolframLanguageEvaluator"
    },
    SameTest -> MatchQ,
    TestID   -> "Named-Tools"
]

VerificationTest[
    Map[
        #[ "Data" ][ "CanonicalName" ] &,
        GenerateLLMConfiguration[ "NotebookAssistant", <| "Tools" -> { "WebSearcher" } |> ][ "Tools" ]
    ],
    { "WebSearcher" },
    SameTest -> MatchQ,
    TestID   -> "Named-Tools-Filtered"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Model/Service*)
VerificationTest[
    model = GenerateLLMConfiguration[ "NotebookAssistant" ][ "Model" ],
    KeyValuePattern[ "Authentication" -> "LLMKit" ],
    SameTest -> MatchQ,
    TestID   -> "Model"
]

VerificationTest[
    model[ "Service" ],
    _String? (StringStartsQ[ "LLMKit" ]),
    SameTest -> MatchQ,
    TestID   -> "Model-Service"
]

VerificationTest[
    model[ "Name" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "Model-Name"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Handling*)
VerificationTest[
    GenerateLLMConfiguration[ "DoesNotExist" ],
    Failure[ "GenerateLLMConfiguration::PersonaNotFound", _ ],
    { GenerateLLMConfiguration::PersonaNotFound },
    SameTest -> MatchQ,
    TestID   -> "Error-1"
]