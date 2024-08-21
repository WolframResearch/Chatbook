(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Get @ FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" },
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
    uris = RelatedDocumentation[ "What's the biggest pokemon?" ],
    { __String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs@@Tests/RelatedDocumentation.wlt:28,1-33,2"
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
    TestID   -> "RelatedDocumentation-URIs-Count@@Tests/RelatedDocumentation.wlt:36,1-50,2"
]

VerificationTest[
    snippets = RelatedDocumentation[ "What's the biggest pokemon?", "Snippets" ],
    { __String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets@@Tests/RelatedDocumentation.wlt:52,1-57,2"
]

VerificationTest[
    Total @ StringCount[ snippets, "Entity[\"Pokemon\"," ],
    _Integer? (GreaterThan[ 5 ]),
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets-Count@@Tests/RelatedDocumentation.wlt:59,1-64,2"
]

VerificationTest[
    uris = RelatedDocumentation[ "What's the biggest pokemon?", Automatic, 3 ],
    { _String, _String, _String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs-Count@@Tests/RelatedDocumentation.wlt:66,1-71,2"
]

VerificationTest[
    AllTrue[ uris, StringStartsQ[ "paclet:ref/" ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-URIs-Match@@Tests/RelatedDocumentation.wlt:73,1-78,2"
]

VerificationTest[
    RelatedDocumentation[ "What's the biggest pokemon?", "Snippets", 3 ],
    { _String, _String, _String },
    SameTest -> MatchQ,
    TestID   -> "RelatedDocumentation-Snippets-Count@@Tests/RelatedDocumentation.wlt:80,1-85,2"
]