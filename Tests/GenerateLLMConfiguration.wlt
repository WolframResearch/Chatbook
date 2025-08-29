(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/GenerateLLMConfiguration.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/GenerateLLMConfiguration.wlt:11,1-16,2"
]

VerificationTest[
    Context @ GenerateLLMConfiguration,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "GenerateLLMConfigurationContext@@Tests/GenerateLLMConfiguration.wlt:18,1-23,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GenerateLLMConfiguration*)
VerificationTest[
    config = GenerateLLMConfiguration[ ],
    HoldPattern @ LLMConfiguration[ _Association? AssociationQ, ___ ],
    SameTest -> MatchQ,
    TestID   -> "NoArgs@@Tests/GenerateLLMConfiguration.wlt:28,1-33,2"
]

VerificationTest[
    SelectFirst[ config[ "Prompts" ], StringQ ],
    _String? (StringContainsQ[ "Notebook Assistant" ]),
    SameTest -> MatchQ,
    TestID   -> "NoArgs-Prompt@@Tests/GenerateLLMConfiguration.wlt:35,1-40,2"
]

VerificationTest[
    SelectFirst[ GenerateLLMConfiguration[ "NotebookAssistant" ][ "Prompts" ], StringQ ],
    _String? (StringContainsQ[ "Notebook Assistant" ]),
    SameTest -> MatchQ,
    TestID   -> "Named-Prompt-1@@Tests/GenerateLLMConfiguration.wlt:42,1-47,2"
]

VerificationTest[
    SelectFirst[ GenerateLLMConfiguration[ "Birdnardo" ][ "Prompts" ], StringQ ],
    _String? (StringContainsQ[ "Birdnardo" ]),
    SameTest -> MatchQ,
    TestID   -> "Named-Prompt-2@@Tests/GenerateLLMConfiguration.wlt:49,1-54,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tools*)
VerificationTest[
    #[ "Data" ][ "CanonicalName" ] & /@ GenerateLLMConfiguration[ "NotebookAssistant" ][ "Tools" ],
    { OrderlessPatternSequence[ "DocumentationSearcher", "WolframAlpha", "WolframLanguageEvaluator" ] },
    SameTest -> MatchQ,
    TestID   -> "Named-Tools@@Tests/GenerateLLMConfiguration.wlt:59,1-64,2"
]

VerificationTest[
    Map[
        #[ "Data" ][ "CanonicalName" ] &,
        GenerateLLMConfiguration[ "NotebookAssistant", <| "Tools" -> { "WebSearcher" } |> ][ "Tools" ]
    ],
    { "WebSearcher" },
    SameTest -> MatchQ,
    TestID   -> "Named-Tools-Filtered@@Tests/GenerateLLMConfiguration.wlt:66,1-74,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Model/Service*)
VerificationTest[
    model = GenerateLLMConfiguration[ "NotebookAssistant" ][ "Model" ],
    KeyValuePattern[ "Authentication" -> "LLMKit" ],
    SameTest -> MatchQ,
    TestID   -> "Model@@Tests/GenerateLLMConfiguration.wlt:79,1-84,2"
]

VerificationTest[
    model[ "Service" ],
    If[ $VersionNumber >= 14.3, _String? (StringStartsQ[ "LLMKit" ]), _String ],
    SameTest -> MatchQ,
    TestID   -> "Model-Service@@Tests/GenerateLLMConfiguration.wlt:86,1-91,2"
]

VerificationTest[
    model[ "Name" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "Model-Name@@Tests/GenerateLLMConfiguration.wlt:93,1-98,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Handling*)
VerificationTest[
    GenerateLLMConfiguration[ "DoesNotExist" ],
    Failure[ "GenerateLLMConfiguration::PersonaNotFound", _ ],
    { GenerateLLMConfiguration::PersonaNotFound },
    SameTest -> MatchQ,
    TestID   -> "Error-1@@Tests/GenerateLLMConfiguration.wlt:103,1-109,2"
]