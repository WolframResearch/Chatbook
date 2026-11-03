(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/FormattingPerformance.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/FormattingPerformance.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Exact Replacements*)
(* Faster definitions in the formatter that give the same results as the ones they replaced. formatTextString evaluates
   the right-hand sides of $stringFormatRules after the split, and drops a "" at either end as StringSplit does: *)
VerificationTest[
    Wolfram`Chatbook`Formatting`Private`formatTextString /@ { "**```**", "**```** a", "**a _```_**", "a **```** b" },
    { { }, { " a" }, { StyleBox[ "a ", FontWeight -> Bold ] }, { "a ", "", " b" } },
    TestID -> "DeferredRules-EmptyEnds@@Tests/FormattingPerformance.wlt:26,1-30,2"
]

(* $$mdRow2 matches the same substrings as the old table row pattern, on random strings: *)
VerificationTest[
    Module[ { old, new, strings },
        old = Except[ "\n" ].. ~~ Repeated[ ("|" ~~ Except[ "\n" ]...), { 2, Infinity } ] ~~ EndOfLine;
        new = Wolfram`Chatbook`Formatting`Private`$$mdRow2;
        strings = BlockRandom[ StringJoin /@ RandomChoice[ Characters[ "a ||\n" ], { 500, 12 } ], RandomSeeding -> 1 ];
        SameQ @@ (Union /@ StringPosition[ strings, #, Overlaps -> All ] & /@ { old, new })
    ],
    True,
    TestID -> "TableRow-SameMatches@@Tests/FormattingPerformance.wlt:33,1-42,2"
]

(* A 10 KB line with bold text formats in well under a second (it took about 4 s with the old definitions): *)
VerificationTest[
    First @ AbsoluteTiming @ FormatChatOutput @ StringRepeat[ "some words **bold** and more words ", 300 ],
    _? (LessThan[ 1 ]),
    SameTest -> MatchQ,
    TestID   -> "LongLine-Timing@@Tests/FormattingPerformance.wlt:45,1-50,2"
]

(* almostCertainlyWLCodeQ only tests the text before the first "[", whitespace, "-" or ":" as a System name. The old
   definition tested every prefix of up to 50 characters: *)
VerificationTest[
    Module[ { oldQ, inputs },
        oldQ[ wl_, inline_ ] := TrueQ @ Or[
            If[ TrueQ @ inline, StringContainsQ, StringStartsQ ][ wl, "\[FreeformPrompt]" ],
            StringMatchQ[
                wl,
                (name: Repeated[ _, { 1, 50 } ] /; Wolfram`Chatbook`Formatting`Private`systemNameQ @ name) ~~
                    Alternatives[ "[" ~~ ___ ~~ "]", Shortest[ WhitespaceCharacter... ] ~~ ("->"|":>") ~~ __ ]
            ],
            TrueQ @ inline && StringMatchQ[ wl, "\"" ~~ ___ ~~ "\"" ]
        ];
        inputs = Join[
            Tuples @ { Flatten @ Outer[ StringJoin, Names[ "System`*" ], { "[x]", " -> 1", ":>x" } ], { False } },
            Tuples @ { { "", "[x]", "Plus", "Plus[", "Plus[x", "Plus[x] y", "Plus [x]", "Plus->1", "Plus\t:> 1",
                "Plus\n-> 1", "Plus->", "Plus-1", "Plus:x", "Plus::usage", "plus[x]", "System`Plus[x]", "`Plus[x]",
                "Plu*[x]", "Plus@x", "f[Plus[x]]", "Plus[x][y]", "x -> Plus", "NotASystemName[x]", "\[Pi][x]",
                "$Line -> 1", StringRepeat[ "a", 60 ] <> "[x]", StringRepeat[ "Plus", 13 ] <> "[x]", "Sin[x]-1",
                "\[FreeformPrompt] x", "x \[FreeformPrompt]", "\"Plus\"", "\"Plus\"[x]" }, { True, False } }
        ];
        Select[ inputs, oldQ @@ # =!= Wolfram`Chatbook`Formatting`Private`almostCertainlyWLCodeQ @@ # & ]
    ],
    { },
    TestID -> "AlmostCertainlyWLCodeQ-SameAsBefore@@Tests/FormattingPerformance.wlt:54,1-77,2"
]

(* :!CodeAnalysis::EndBlock:: *)
