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
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
VerificationTest[
    config = Quiet[ GenerateLLMConfiguration[ ], LLMServices`Defaults`Private`LLMFunctions::llmrstrt ],
    HoldPattern @ LLMConfiguration[ _Association? AssociationQ, ___ ],
    SameTest -> MatchQ,
    TestID   -> "NoArgs@@Tests/GenerateLLMConfiguration.wlt:30,1-35,2"
]
(* :!CodeAnalysis::EndBlock:: *)

VerificationTest[
    SelectFirst[ config[ "Prompts" ], StringQ ],
    _String? (StringContainsQ[ "Wolfram AI Assistant" ]),
    SameTest -> MatchQ,
    TestID   -> "NoArgs-Prompt@@Tests/GenerateLLMConfiguration.wlt:38,1-43,2"
]

VerificationTest[
    SelectFirst[ GenerateLLMConfiguration[ "NotebookAssistant" ][ "Prompts" ], StringQ ],
    _String? (StringContainsQ[ "Notebook Assistant" ]),
    SameTest -> MatchQ,
    TestID   -> "Named-Prompt-1@@Tests/GenerateLLMConfiguration.wlt:45,1-50,2"
]

VerificationTest[
    SelectFirst[ GenerateLLMConfiguration[ "Birdnardo" ][ "Prompts" ], StringQ ],
    _String? (StringContainsQ[ "Birdnardo" ]),
    SameTest -> MatchQ,
    TestID   -> "Named-Prompt-2@@Tests/GenerateLLMConfiguration.wlt:52,1-57,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tools*)
VerificationTest[
    Sort[ #[ "Data" ][ "CanonicalName" ] & /@ GenerateLLMConfiguration[ "NotebookAssistant" ][ "Tools" ] ],
    { "CreateNotebook", "DocumentationSearcher", "WebFetcher", "WolframAlpha", "WolframLanguageEvaluator" },
    SameTest -> MatchQ,
    TestID   -> "Named-Tools@@Tests/GenerateLLMConfiguration.wlt:62,1-67,2"
]

VerificationTest[
    Map[
        #[ "Data" ][ "CanonicalName" ] &,
        GenerateLLMConfiguration[ "NotebookAssistant", <| "Tools" -> { "WebSearcher" } |> ][ "Tools" ]
    ],
    { "WebSearcher" },
    SameTest -> MatchQ,
    TestID   -> "Named-Tools-Filtered@@Tests/GenerateLLMConfiguration.wlt:69,1-77,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Model/Service*)
VerificationTest[
    model = GenerateLLMConfiguration[ "NotebookAssistant" ][ "Model" ],
    KeyValuePattern[ "Authentication" -> "LLMKit" ],
    SameTest -> MatchQ,
    TestID   -> "Model@@Tests/GenerateLLMConfiguration.wlt:82,1-87,2"
]

VerificationTest[
    model[ "Service" ],
    If[ $VersionNumber >= 14.3, _String? (StringStartsQ[ "LLMKit" ]), _String ],
    SameTest -> MatchQ,
    TestID   -> "Model-Service@@Tests/GenerateLLMConfiguration.wlt:89,1-94,2"
]

VerificationTest[
    model[ "Name" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "Model-Name@@Tests/GenerateLLMConfiguration.wlt:96,1-101,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Error Handling*)
VerificationTest[
    GenerateLLMConfiguration[ "DoesNotExist" ],
    Failure[ "GenerateLLMConfiguration::PersonaNotFound", _ ],
    { GenerateLLMConfiguration::PersonaNotFound },
    SameTest -> MatchQ,
    TestID   -> "Error-1@@Tests/GenerateLLMConfiguration.wlt:106,1-112,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ReplaceUnicodeCharacters*)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
VerificationTest[
    $ffp = FromCharacterCode[ 16^^F351 ];
    replaceUnicode = Wolfram`Chatbook`SendChat`Private`replaceUnicodeCharacters;
    autoCorrect = Wolfram`Chatbook`Common`autoCorrect;
    { StringQ @ replaceUnicode @ $ffp, StringQ @ autoCorrect @ $ffp },
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "ReplaceUnicode-Init@@Tests/GenerateLLMConfiguration.wlt:119,1-127,2"
]

(* Outgoing content must be pure ASCII, since the models this is enabled for mishandle the private use area *)
VerificationTest[
    ToCharacterCode @ replaceUnicode[ $ffp <> "[\"France\"]" ],
    _? (AllTrue[ # < 128 & ]),
    SameTest -> MatchQ,
    TestID   -> "ReplaceUnicode-ASCII@@Tests/GenerateLLMConfiguration.wlt:130,1-135,2"
]

VerificationTest[
    replaceUnicode @ $ffp,
    "\\"<>"[FreeformPrompt]",
    SameTest -> MatchQ,
    TestID   -> "ReplaceUnicode-LongName@@Tests/GenerateLLMConfiguration.wlt:137,1-142,2"
]

(* autoCorrect must restore whatever replaceUnicodeCharacters sent to the model *)
VerificationTest[
    autoCorrect @ replaceUnicode @ # === # & /@ { $ffp, $ffp <> "[\"France\"]", "no freeform prompt here" },
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ReplaceUnicode-RoundTrip@@Tests/GenerateLLMConfiguration.wlt:145,1-150,2"
]

(* The ", Entity" hallucination must not survive, and must not pick up a second \[FreeformPrompt] *)
VerificationTest[
    autoCorrect @ replaceUnicode[ $ffp <> "[\"France\", Entity]" ],
    $ffp <> "[\"France\"]",
    SameTest -> MatchQ,
    TestID   -> "ReplaceUnicode-Entity@@Tests/GenerateLLMConfiguration.wlt:153,1-158,2"
]

VerificationTest[
    StringCount[ autoCorrect[ "\\"<>"[FreeformPrompt][\"France\", Entity]" ], $ffp ],
    1,
    SameTest -> MatchQ,
    TestID   -> "ReplaceUnicode-EntityNoDouble@@Tests/GenerateLLMConfiguration.wlt:160,1-165,2"
]
(* :!CodeAnalysis::EndBlock:: *)