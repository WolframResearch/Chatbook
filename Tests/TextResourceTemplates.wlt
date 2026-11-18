(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*trTemplate*)

(* The resource is looked up when the Dynamic is displayed, so it follows the front end's language. The Dynamic only
   uses System functions, so displaying it doesn't need Chatbook, and it has no tracked symbols, so it doesn't update
   whenever a Chatbook global changes: *)
VerificationTest[
    Wolfram`Chatbook`Common`trTemplate[ "WorkspaceHistoryPageTemplate", 3, Style[ "7", Bold ] ],
    Dynamic[
        StringForm[ FrontEndResource[ "ChatbookStrings", "WorkspaceHistoryPageTemplate" ], 3, Style[ "7", Bold ] ],
        TrackedSymbols :> { }
    ],
    SameTest -> MatchQ,
    TestID   -> "Positional-Slots"
]

VerificationTest[
    Wolfram`Chatbook`Common`trTemplate[ "ToolManagerTooltipNonDeletable1", <| "name" -> "WebFetcher" |> ],
    (* The expected association is inserted with With, since a held literal association isn't the same as an evaluated one: *)
    With[ { as = <| "name" -> "WebFetcher" |> },
        Dynamic[
            TemplateApply[ FrontEndResource[ "ChatbookStrings", "ToolManagerTooltipNonDeletable1" ], as ],
            TrackedSymbols :> { }
        ]
    ],
    SameTest -> SameQ,
    TestID   -> "Named-Slots"
]

VerificationTest[
    Cases[
        Wolfram`Chatbook`Common`trTemplate[ "ToolManagerTooltipNonDeletable1", <| "name" -> "WebFetcher" |> ],
        s_Symbol /; ! StringStartsQ[ Context @ s, "System`" ] :> s,
        Infinity,
        Heads -> True
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Only-System-Symbols"
]

(* The cloud has no front end resources, so the English text is filled in right away: *)
VerificationTest[
    Block[ { $CloudEvaluation = True },
        Wolfram`Chatbook`Common`trTemplate[ "ToolManagerTooltipNonDeletable2", <| "name" -> "A", "persona" -> "B" |> ]
    ],
    "A is provided by the persona B and cannot be deleted separately.",
    SameTest -> MatchQ,
    TestID   -> "Cloud-Named-Slots"
]

VerificationTest[
    ToString @ Block[ { $CloudEvaluation = True },
        Wolfram`Chatbook`Common`trTemplate[ "WorkspaceHistoryPageTemplate", 3, 7 ]
    ],
    "Page 3 of 7",
    SameTest -> MatchQ,
    TestID   -> "Cloud-Positional-Slots"
]

(* Every resource used with named slots has only named slots in each language, so TemplateApply fills them all: *)
readTextResources[ file_ ] := Association @ ToExpression @ First @ StringCases[
    ReadString @ file,
    "@@resource ChatbookStrings" ~~ WhitespaceCharacter... ~~ rules: Shortest[ "{" ~~ ___ ~~ "}" ] :> rules,
    1
];

VerificationTest[
    Module[ { names, files },
        names = {
            "ToolManagerTooltipNonDeletable1",
            "ToolManagerTooltipNonDeletable2",
            "ToolManagerTooltipNonConfigurable",
            "PersonaManagerOriginRepositoryTooltip",
            "PreferencesContentLLMKitUpgradePro",
            "PreferencesContentLLMKitUpgradeResearch",
            "PreferencesContentLLMKitEnabledTitle"
        };
        files = FileNames[
            "ChatbookStrings.tr",
            FileNameJoin @ { Wolfram`Chatbook`Common`$thisPaclet[ "Location" ], "FrontEnd", "TextResources" },
            Infinity
        ];
        {
            Length @ files,
            Flatten[
                Table[
                    With[ { s = Lookup[ readTextResources @ file, name, "" ] },
                        If[ StringQ @ s && StringContainsQ[ s, "`" ~~ DigitCharacter.. ~~ "`" ], { { file, name } }, { } ]
                    ],
                    { file, files },
                    { name, names }
                ],
                2
            ]
        }
    ],
    { 7, { } },
    SameTest -> MatchQ,
    TestID   -> "Named-Slot-Resources-Have-No-Positional-Slots"
]

(* :!CodeAnalysis::EndBlock:: *)
