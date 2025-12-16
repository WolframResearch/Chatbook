(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/RelatedDocumentation.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/RelatedDocumentation.wlt:11,1-16,2"
]

VerificationTest[
    Context @ RelatedDocumentation,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentationContext@@Tests/RelatedDocumentation.wlt:18,1-23,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedDocumentation*)
VerificationTest[
    urls = RelatedDocumentation[ "What's the biggest pokemon?" ],
    { URL[ _String ].. },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs@@Tests/RelatedDocumentation.wlt:28,1-33,2"
]

VerificationTest[
    FileNames[ All, ChatbookFilesDirectory[ "VectorDatabases" ], Infinity ],
    { Repeated[ _String, { 40, Infinity } ] },
    SameTest -> MatchQ,
    TestID   -> "VectorDatabase-Files@@Tests/RelatedDocumentation.wlt:35,1-40,2"
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
    TestID   -> "RelatedDocumentation-URIs-Count@@Tests/RelatedDocumentation.wlt:42,1-56,2"
]

VerificationTest[
    snippets = RelatedDocumentation[ "What's the biggest pokemon?", "Snippets" ],
    { __String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets@@Tests/RelatedDocumentation.wlt:58,1-63,2"
]

VerificationTest[
    Total @ StringCount[ snippets, "Entity[\"Pokemon\"," ],
    _Integer? (GreaterThan[ 5 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets-Count@@Tests/RelatedDocumentation.wlt:65,1-70,2"
]

VerificationTest[
    urls = RelatedDocumentation[ "What's the biggest pokemon?", Automatic, 3, "Sources" -> { "Documentation" } ],
    { URL[ _String ], URL[ _String ], URL[ _String ] },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs-Count@@Tests/RelatedDocumentation.wlt:72,1-77,2"
]

VerificationTest[
    AllTrue[ First /@ urls, StringStartsQ[ "paclet:ref/" ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs-Match@@Tests/RelatedDocumentation.wlt:79,1-84,2"
]

VerificationTest[
    RelatedDocumentation[ "What's the biggest pokemon?", "Snippets", 3 ],
    { _String, _String, _String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets-Count@@Tests/RelatedDocumentation.wlt:86,1-91,2"
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
    TestID   -> "RelatedDocumentation-Prompt@@Tests/RelatedDocumentation.wlt:96,1-106,2"
]

VerificationTest[
    StringCount[ prompt, "paclet:ref/Prime#" ],
    _Integer? Positive,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt-Count@@Tests/RelatedDocumentation.wlt:108,1-113,2"
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
    TestID   -> "RelatedDocumentation-Prompt-Messages@@Tests/RelatedDocumentation.wlt:118,1-132,2"
]

VerificationTest[
    StringCount[ prompt, { "paclet:ref/Prime#", "paclet:ref/NextPrime#" } ],
    _Integer? (GreaterEqualThan[ 5 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt-Messages-Count@@Tests/RelatedDocumentation.wlt:134,1-139,2"
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
    TestID   -> "RelatedDocumentation-Prompt-Selection@@Tests/RelatedDocumentation.wlt:144,1-157,2"
]

VerificationTest[
    StringCount[ prompt, "paclet:ref/Prime#" ],
    _Integer? (GreaterEqualThan[ 2 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Prompt-Selection-Count@@Tests/RelatedDocumentation.wlt:159,1-164,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Regression Tests*)
VerificationTest[
    Take[ RelatedDocumentation[ { <| "Role" -> "User", "Content" -> "Hello" |> } ], UpTo[ 30 ] ][[ All, 1 ]],
    { __String? (StringFreeQ[ "$Username" ]) },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Regression-UserPrefix@@Tests/RelatedDocumentation.wlt:169,1-174,2"
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
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-DataRepositoryURIs-1@@Tests/RelatedDocumentation.wlt:185,1-194,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DocumentationURIs*)
VerificationTest[
    RelatedDocumentation[ "What's the 123456789th prime?", "URIs", 5 ],
    { ___, URL[ _String? (StringStartsQ[ "paclet:ref/Prime#" ]) ], ___ },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-DocumentationURIs-1@@Tests/RelatedDocumentation.wlt:199,1-204,2"
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
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-EntityValues-1@@Tests/RelatedDocumentation.wlt:209,1-221,2"
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
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-FunctionRepositoryURIs-1@@Tests/RelatedDocumentation.wlt:226,1-235,2"
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
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-NeuralNetRepositoryURIs-1@@Tests/RelatedDocumentation.wlt:240,1-252,2"
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
    TestID   -> "RelatedDocumentation-VectorDatabaseTests-PacletRepositoryURIs-1@@Tests/RelatedDocumentation.wlt:257,1-269,2"
]