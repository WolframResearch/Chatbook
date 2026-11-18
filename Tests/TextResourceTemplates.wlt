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

(* The resource is looked up when the Dynamic is displayed, so it follows the front end's language. The front end can't
   fill in slots, so the "System" kernel does it. The label only uses System symbols (and Typeset` variables), so
   displaying it (also in a saved notebook) doesn't need Chatbook, and it has no tracked symbols, so it doesn't update
   whenever a Chatbook global changes: *)
VerificationTest[
    Wolfram`Chatbook`Common`trTemplate[ "WorkspaceHistoryPageTemplate", 3, Style[ "7", Bold ] ],
    Dynamic[
        _Function[ "WorkspaceHistoryPageTemplate", { "1" -> 3, "2" -> Style[ "7", Bold ] }, FrontEndResource[ "ChatbookStrings", "WorkspaceHistoryPageTemplate" ] ],
        Evaluator      -> "System",
        TrackedSymbols :> { }
    ],
    SameTest -> MatchQ,
    TestID   -> "Positional-Slots"
]

VerificationTest[
    Wolfram`Chatbook`Common`trTemplate[ "ToolManagerTooltipNonDeletable1", <| "name" -> "WebFetcher" |> ],
    Dynamic[
        _Function[ "ToolManagerTooltipNonDeletable1", { "name" -> "WebFetcher" }, FrontEndResource[ "ChatbookStrings", "ToolManagerTooltipNonDeletable1" ] ],
        Evaluator      -> "System",
        TrackedSymbols :> { }
    ],
    SameTest -> MatchQ,
    TestID   -> "Named-Slots"
]

VerificationTest[
    Cases[
        Wolfram`Chatbook`Common`trTemplate[ "ToolManagerTooltipNonDeletable1", <| "name" -> "WebFetcher" |> ],
        s_Symbol /; ! StringStartsQ[ Context @ s, "System`" | "Typeset`" ] :> s,
        Infinity,
        Heads -> True
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Only-System-Symbols"
]

(* The template is filled in like this when the label is displayed. Slots can be in any order and can repeat, and
   missing values are left empty. Without the resource, only the values are shown: *)
VerificationTest[
    With[ { f = Extract[ Wolfram`Chatbook`Common`trTemplate[ "X", <| "a" -> Style[ "A", Bold ], "b" -> 2 |> ], { 1, 0 }, Hold ] },
        With[ { fill = ReleaseHold @ f[ "X", { "a" -> Style[ "A", Bold ], "b" -> 2 }, # ] & },
            { ToString @ fill[ "`b` then `a`, `a` and `c`." ], Head @ fill[ "`a`" ], ToString @ fill[ $Failed ] }
        ]
    ],
    { "2 then A, A and .", Style, "A 2" },
    SameTest -> MatchQ,
    TestID   -> "Fill-In"
]

(* The DynamicModule variables of Dynamic arguments are localized: *)
VerificationTest[
    FreeQ[
        ToBoxes @ DynamicModule[ { page = 3 }, Wolfram`Chatbook`Common`trTemplate[ "WorkspaceHistoryPageTemplate", Dynamic @ page, 7 ] ],
        Dynamic[ page ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "DynamicModule-Variables"
]

(* A saved label is serialized with the English text: *)
VerificationTest[
    {
        Wolfram`Chatbook`CellToString @ Cell[ BoxData @ ToBoxes @ Wolfram`Chatbook`Common`trTemplate[ "FormattingThinkingComplete", <| "time" -> "5" |> ], "Text" ],
        Wolfram`Chatbook`CellToString @ Cell[ BoxData @ ToBoxes @ Wolfram`Chatbook`Common`trTemplate[ "FormattingToolUsedTemplate", Style[ "Web Fetcher", FontWeight -> "Plain" ] ], "Text" ]
    },
    { "Thought for 5 seconds", "Used Web Fetcher" },
    SameTest -> MatchQ,
    TestID   -> "Serialization"
]

(* The cloud has no front end resources, so the English text is filled in right away: *)
VerificationTest[
    ToString @ Block[ { $CloudEvaluation = True },
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

(* Every translation of a template has the same slots as the English one, so no value is lost or left as a literal slot.
   Slots are filled by splitting at backticks, so a template must have an even number of them: *)
readTextResources[ file_ ] := Association @ ToExpression @ First @ StringCases[
    ReadString @ file,
    "@@resource ChatbookStrings" ~~ WhitespaceCharacter... ~~ rules: Shortest[ "{" ~~ ___ ~~ "}" ] :> rules,
    1
];

templateSlots[ s_String ] := Sort @ StringCases[ s, "`" ~~ slot: Except[ "`" ].. ~~ "`" :> slot ];

VerificationTest[
    Module[ { files, english, templates },
        files = FileNames[
            "ChatbookStrings.tr",
            FileNameJoin @ { Wolfram`Chatbook`Common`$thisPaclet[ "Location" ], "FrontEnd", "TextResources" },
            Infinity
        ];
        english   = readTextResources @ SelectFirst[ files, FileNameTake[ #, { -2 } ] === "TextResources" & ];
        templates = Keys @ Select[ english, StringQ[ # ] && StringContainsQ[ #, "`" ] & ];
        {
            Length @ files,
            Flatten[
                Table[
                    With[ { s = Lookup[ readTextResources @ file, name ] },
                        If[ StringQ @ s && (OddQ @ StringCount[ s, "`" ] || templateSlots @ s =!= templateSlots @ english @ name),
                            { { FileNameTake[ file, { -2 } ], name } },
                            { }
                        ]
                    ],
                    { file, files },
                    { name, templates }
                ],
                2
            ]
        }
    ],
    { 7, { } },
    SameTest -> MatchQ,
    TestID   -> "Translations-Have-Same-Slots"
]

(* :!CodeAnalysis::EndBlock:: *)
