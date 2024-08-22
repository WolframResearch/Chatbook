(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    If[ ! TrueQ @ Wolfram`ChatbookTests`$TestDefinitionsLoaded,
        Get @ FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" }
    ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/RelatedDocumentation.wlt:4,1-11,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/RelatedDocumentation.wlt:13,1-18,2"
]

VerificationTest[
    Context @ RelatedDocumentation,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentationContext@@Tests/RelatedDocumentation.wlt:20,1-25,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedDocumentation*)
VerificationTest[
    uris = RelatedDocumentation[ "What's the biggest pokemon?" ],
    { __String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs@@Tests/RelatedDocumentation.wlt:30,1-35,2"
]

(* cSpell: ignore textcontent *)
VerificationTest[
    Length @ Select[
        uris,
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
    TestID   -> "RelatedDocumentation-URIs-Count@@Tests/RelatedDocumentation.wlt:38,1-52,2"
]

VerificationTest[
    snippets = RelatedDocumentation[ "What's the biggest pokemon?", "Snippets" ],
    { __String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets@@Tests/RelatedDocumentation.wlt:54,1-59,2"
]

VerificationTest[
    Total @ StringCount[ snippets, "Entity[\"Pokemon\"," ],
    _Integer? (GreaterThan[ 5 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets-Count@@Tests/RelatedDocumentation.wlt:61,1-66,2"
]

VerificationTest[
    uris = RelatedDocumentation[ "What's the biggest pokemon?", Automatic, 3 ],
    { _String, _String, _String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs-Count@@Tests/RelatedDocumentation.wlt:68,1-73,2"
]

VerificationTest[
    AllTrue[ uris, StringStartsQ[ "paclet:ref/" ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs-Match@@Tests/RelatedDocumentation.wlt:75,1-80,2"
]

VerificationTest[
    RelatedDocumentation[ "What's the biggest pokemon?", "Snippets", 3 ],
    { _String, _String, _String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets-Count@@Tests/RelatedDocumentation.wlt:82,1-87,2"
]