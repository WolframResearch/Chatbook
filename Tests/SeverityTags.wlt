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

(* The severity tag checks run on the full response for every streamed chunk, so they only look at a short
   whitespace-stripped prefix of it. These tests compare them against the original implementations, which stripped
   all whitespace from the whole string. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    referenceTaggedQ[ s_String, tag_ ] :=
        StringStartsQ[ StringDelete[ s, Whitespace ], "["~~tag~~"]", IgnoreCase -> True ];

    referenceUntaggedQ[ s0_String ] :=
        With[ { s = StringDelete[ s0, Whitespace ] },
            Or[ StringStartsQ[ s, Except[ "[" ] ],
                And[
                    StringLength @ s >= Wolfram`Chatbook`SendChat`Private`$maxTagLength,
                    ! StringStartsQ[ s, Wolfram`Chatbook`SendChat`Private`$$tagPrefix, IgnoreCase -> True ]
                ]
            ]
        ];

    (* Includes some characters that are not WhitespaceCharacter (e.g. U+200B Zero Width Space): *)
    $severityTagWhitespace = Join[
        { " ", "\n", "\t", "\r\n", "  ", "\[NonBreakingSpace]", "\[InvisibleSpace]", "\:2003", "\:3000" },
        FromCharacterCode /@ { 12, 133, 8203 }
    ];

    $severityTagFragments = Join[
        $severityTagWhitespace,
        {
            "[", "]", "[[", "]]", "ERROR", "error", "Error", "WARNING", "warning", "Warning", "INFO", "info", "INF",
            "WARN", "ERR", "E", "R", "[ERROR]", "[warning]", "[ INFO ]", "Hello", "x", "abc", "\:0131", "\:212a"
        }
    ];

    randomSeverityTagWhitespace[ ] := StringJoin @ RandomChoice[
        $severityTagWhitespace,
        RandomChoice[ { 0.5, 0.2, 0.2, 0.1 } -> { 0, 1, RandomInteger @ { 2, 40 }, RandomInteger @ { 100, 700 } } ]
    ];

    spacedSeverityTag[ s_String ] := StringJoin @ Riffle[
        Characters @ s,
        Table[ randomSeverityTagWhitespace[ ], StringLength @ s - 1 ]
    ];

    randomSeverityTagString[ ] := Switch[ RandomInteger @ { 1, 4 },
        1,
        StringJoin[ randomSeverityTagWhitespace[ ], RandomChoice[ $severityTagFragments, RandomInteger @ { 0, 12 } ] ],
        2,
        StringJoin[
            randomSeverityTagWhitespace[ ],
            spacedSeverityTag @ RandomChoice @ {
                "[ERROR]", "[WARNING]", "[INFO]", "[Error]", "[warning]", "[info]",
                "[INF", "[", "[WARNIN", "[ERRORS]", "[INFO]x", "[infox]"
            },
            randomSeverityTagWhitespace[ ],
            RandomChoice[ $severityTagFragments, RandomInteger @ { 0, 5 } ]
        ],
        3,
        StringJoin @ RandomChoice[ $severityTagFragments, RandomInteger @ { 0, 4 } ],
        4,
        StringJoin @ Riffle[
            RandomChoice[ Join[ $severityTagFragments, { "a", "b" } ], RandomInteger @ { 0, 40 } ],
            randomSeverityTagWhitespace[ ]
        ]
    ];

    $severityTagStrings = Join[
        {
            "",
            " ",
            "[",
            "[INF",
            "[ e r r o r ]",
            "[ e r r o r ] something went wrong",
            "\n\n[WARNING]",
            StringRepeat[ " ", 500 ] <> "[ERROR]",
            StringRepeat[ " ", 500 ] <> "[INFO",
            StringRepeat[ "\n", 1000 ] <> "Hello",
            "[" <> StringRepeat[ " ", 300 ] <> "INFO]",
            StringRepeat[ "a", 8 ],
            StringRepeat[ "a", 9 ],
            StringRepeat[ "a ", 8 ],
            StringRepeat[ "a ", 9 ],
            "[abcdefg",
            "[abcdefgh",
            StringRepeat[ "Hello world. ", 5000 ],
            "[INFO] " <> StringRepeat[ "Hello world. ", 5000 ]
        },
        BlockRandom[ SeedRandom[ 1234 ]; Table[ randomSeverityTagString[ ], 2000 ] ]
    ];,
    Null,
    SameTest -> MatchQ,
    TestID   -> "SeverityTags-Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*nonWhitespacePrefix*)
VerificationTest[
    Wolfram`Chatbook`SendChat`Private`nonWhitespacePrefix /@ { "", " ", "\n\t ", "[ e r r o r ]", " a b c " },
    { "", "", "", "[error]", "abc" },
    SameTest -> MatchQ,
    TestID   -> "NonWhitespacePrefix-Short"
]

VerificationTest[
    Wolfram`Chatbook`SendChat`Private`nonWhitespacePrefix[ StringRepeat[ " ", 1000 ] <> "[ERROR] " <> StringRepeat[ "x", 1000 ] ],
    _String? (StringMatchQ[ "[ERROR]" ~~ "x".. ] ),
    SameTest -> MatchQ,
    TestID   -> "NonWhitespacePrefix-Leading-Whitespace"
]

(* The prefix is either long enough for every check or all of the non-whitespace characters: *)
VerificationTest[
    Select[
        $severityTagStrings,
        Function[
            s,
            With[
                {
                    full   = StringDelete[ s, Whitespace ],
                    prefix = Wolfram`Chatbook`SendChat`Private`nonWhitespacePrefix @ s
                },
                ! And[
                    StringStartsQ[ full, prefix ],
                    StringLength @ prefix >= 2 * Wolfram`Chatbook`SendChat`Private`$maxTagLength || prefix === full
                ]
            ]
        ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "NonWhitespacePrefix-Property"
]

(* Only the start of a long response is used: *)
VerificationTest[
    StringLength /@ Wolfram`Chatbook`SendChat`Private`nonWhitespacePrefix /@ {
        StringRepeat[ "Hello world. ", 5000 ],
        StringRepeat[ " ", 500 ] <> StringRepeat[ "Hello world. ", 5000 ]
    },
    { _Integer? (Between @ { 18, 100 }), _Integer? (Between @ { 18, 1000 }) },
    SameTest -> MatchQ,
    TestID   -> "NonWhitespacePrefix-Bounded"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tagged*)
VerificationTest[
    {
        Wolfram`Chatbook`SendChat`Private`errorTaggedQ[ "  [ERROR] oops" ],
        Wolfram`Chatbook`SendChat`Private`errorTaggedQ[ "[ e r r o r ] oops" ],
        Wolfram`Chatbook`SendChat`Private`warningTaggedQ[ StringRepeat[ "\n", 500 ] <> "[ Warning ]" ],
        Wolfram`Chatbook`SendChat`Private`infoTaggedQ[ "[INFO]" <> StringRepeat[ "Hello world. ", 5000 ] ],
        Wolfram`Chatbook`SendChat`Private`infoTaggedQ[ "[INF" ],
        Wolfram`Chatbook`SendChat`Private`errorTaggedQ[ "[WARNING]" ],
        Wolfram`Chatbook`SendChat`Private`errorTaggedQ[ "" ],
        Wolfram`Chatbook`SendChat`Private`errorTaggedQ[ None ],
        Wolfram`Chatbook`SendChat`Private`errorTaggedQ[ <| "FullContent" -> "\n[error]" |> ],
        Wolfram`Chatbook`SendChat`Private`taggedQ[ "  [ info ]" ]
    },
    { True, True, True, True, False, False, False, False, True, True },
    SameTest -> MatchQ,
    TestID   -> "TaggedQ-Examples"
]

VerificationTest[
    Select[
        $severityTagStrings,
        Function[
            s,
            ! And[
                Wolfram`Chatbook`SendChat`Private`errorTaggedQ @ s === referenceTaggedQ[ s, "ERROR" ],
                Wolfram`Chatbook`SendChat`Private`warningTaggedQ @ s === referenceTaggedQ[ s, "WARNING" ],
                Wolfram`Chatbook`SendChat`Private`infoTaggedQ @ s === referenceTaggedQ[ s, "INFO" ],
                Wolfram`Chatbook`SendChat`Private`taggedQ @ s ===
                    referenceTaggedQ[ s, Wolfram`Chatbook`SendChat`Private`$$severityTag ],
                Wolfram`Chatbook`SendChat`Private`errorTaggedQ @ <| "FullContent" -> s |> ===
                    referenceTaggedQ[ s, "ERROR" ]
            ]
        ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "TaggedQ-Matches-Reference"
]

(* Make sure the generated strings cover both outcomes: *)
VerificationTest[
    Sort @ Union @ Table[ referenceTaggedQ[ s, Wolfram`Chatbook`SendChat`Private`$$severityTag ], { s, $severityTagStrings } ],
    { False, True },
    SameTest -> MatchQ,
    TestID   -> "TaggedQ-Reference-Coverage"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Untagged*)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$alwaysOpen = True },
        Wolfram`Chatbook`SendChat`Private`untaggedQ /@ {
            "Hello",
            "  Hello",
            "",
            "[",
            "[INF",
            "[abcdefg",
            "[abcdefgh",
            "[ e r r o r ] oops",
            StringRepeat[ " ", 500 ] <> "[ERROR] oops",
            StringRepeat[ " ", 500 ] <> "[bad tag] " <> StringRepeat[ "Hello world. ", 5000 ],
            <| "FullContent" -> "Hello" |>
        }
    ],
    { True, True, False, False, False, False, True, False, False, True, True },
    SameTest -> MatchQ,
    TestID   -> "UntaggedQ-Examples"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$alwaysOpen = False },
        Wolfram`Chatbook`SendChat`Private`untaggedQ /@ { "Hello", <| "FullContent" -> "Hello" |> }
    ],
    { False, False },
    SameTest -> MatchQ,
    TestID   -> "UntaggedQ-Not-Always-Open"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$alwaysOpen = True },
        Select[
            $severityTagStrings,
            Function[
                s,
                ! And[
                    Wolfram`Chatbook`SendChat`Private`untaggedQ @ s === referenceUntaggedQ @ s,
                    Wolfram`Chatbook`SendChat`Private`untaggedQ @ <| "FullContent" -> s |> === referenceUntaggedQ @ s
                ]
            ]
        ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "UntaggedQ-Matches-Reference"
]

VerificationTest[
    Sort @ Union @ Table[ referenceUntaggedQ @ s, { s, $severityTagStrings } ],
    { False, True },
    SameTest -> MatchQ,
    TestID   -> "UntaggedQ-Reference-Coverage"
]

(* :!CodeAnalysis::EndBlock:: *)
