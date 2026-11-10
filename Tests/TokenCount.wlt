(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/TokenCount.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/TokenCount.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    (* Resolved chat settings contain both the tokenizer name and the tokenizer itself: *)
    tokenizerSettings[ name_String ] := <|
        "TokenizerName"    -> name,
        "Tokenizer"        -> Wolfram`Chatbook`Common`getTokenizer @ <| "TokenizerName" -> name |>,
        "MaxContextTokens" -> 2000
    |>;

    (* Evaluates `eval` with an empty token count cache: *)
    withTokenCountCache // Attributes = { HoldFirst };
    withTokenCountCache[ eval_ ] := Block[ { Wolfram`Chatbook`ChatMessages`Private`$tokenCountCache = <| |> }, eval ];

    (* Evaluates `eval` as if token counts were never cached: *)
    withoutTokenCountCache // Attributes = { HoldFirst };
    withoutTokenCountCache[ eval_ ] := withTokenCountCache @ Block[
        { Wolfram`Chatbook`ChatMessages`Private`tokenCountCacheKey = None & },
        eval
    ];

    tokenCountCacheSize[ ] := Length @ Wolfram`Chatbook`ChatMessages`Private`$tokenCountCache;

    countTokens[ settings_, messages_List ] :=
        Wolfram`Chatbook`ChatMessages`Private`tokenCount[ settings, # ] & /@ messages;

    $tokenizerNames = { "gpt-4o", "claude-3", "generic", "gpt-4", "chat-bison" };

    $longText = StringRiffle[
        Table[
            "Paragraph " <> ToString @ i <> ": The quick brown fox jumps over the lazy dog. " <>
                "```wl\nTable[Prime[n]^2, {n, " <> ToString @ i <> "}]\n```",
            { i, 50 }
        ],
        "\n\n"
    ];

    (* Messages that have text content, which can be cached: *)
    $textMessages = {
        "Hello world",
        "",
        "[Cell Excised]",
        "Gr\[UDoubleDot]\[SZ]e \:65e5\:672c\:8a9e \[Alpha] + \[Beta] \[Rule] \[Infinity] \|01f600",
        $longText,
        <| "Role" -> "User"     , "Content" -> "How do I compute eigenvalues?" |>,
        <| "Role" -> "System"   , "Content" -> $longText |>,
        <| "Role" -> "Assistant", "Content" -> { "First part.", "Second part." } |>,
        <| "Role" -> "User"     , "Content" -> { <| "Type" -> "Text", "Data" -> "Typed text content" |> } |>
    };

    (* Messages that are counted without using the cache: *)
    $otherMessages = {
        <| "Role" -> "User", "Content" -> "This message already has a count", "TokenCount" -> 42 |>,
        <|
            "Role"    -> "Assistant",
            "Content" -> {
                <| "Type" -> "Reasoning", "Data" -> "Encrypted reasoning is not counted" |>,
                <| "Type" -> "Text"     , "Data" -> "The answer is 391." |>
            }
        |>
    };

    $imageMessage = <|
        "Role"    -> "User",
        "Content" -> { "What is in this image?", Image @ ConstantArray[ 0.5, { 40, 60 } ] }
    |>;
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions@@Tests/TokenCount.wlt:25,1-93,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*tokenCount*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cached Counts*)
VerificationTest[
    Table[
        Module[ { settings, messages, expected, cold, warm, size },
            settings = tokenizerSettings @ name;
            messages = Join[ $textMessages, $otherMessages ];
            expected = withoutTokenCountCache @ countTokens[ settings, messages ];
            { cold, warm, size } = withTokenCountCache @ {
                countTokens[ settings, messages ],
                countTokens[ settings, messages ],
                tokenCountCacheSize[ ]
            };
            { MatchQ[ expected, { __Integer } ], cold === expected, warm === expected, size }
        ],
        { name, $tokenizerNames }
    ],
    (* Only the distinct text contents are cached ("" and "[Cell Excised]" have the same content): *)
    ConstantArray[ { True, True, True, 7 }, Length @ $tokenizerNames ],
    SameTest -> MatchQ,
    TestID   -> "CachedCountsMatchUncached@@Tests/TokenCount.wlt:102,1-121,2"
]

VerificationTest[
    Table[
        Module[ { settings, expected },
            settings = tokenizerSettings @ name;
            expected = withoutTokenCountCache @ countTokens[ settings, { $imageMessage, $imageMessage } ];
            withTokenCountCache @ {
                MatchQ[ expected, { n_Integer, n_Integer } ],
                countTokens[ settings, { $imageMessage, $imageMessage } ] === expected,
                tokenCountCacheSize[ ]
            }
        ],
        { name, { "gpt-4o", "claude-3", "generic" } }
    ],
    ConstantArray[ { True, True, 0 }, 3 ],
    SameTest -> MatchQ,
    TestID   -> "ImageContentNotCached@@Tests/TokenCount.wlt:123,1-139,2"
]

VerificationTest[
    withTokenCountCache @ Module[ { text, gpt, bison },
        text  = "Different tokenizers must never share cached counts: \[Alpha]\[Beta]\[Gamma]";
        gpt   = tokenizerSettings[ "gpt-4o" ];
        bison = tokenizerSettings[ "chat-bison" ];
        {
            Wolfram`Chatbook`ChatMessages`Private`tokenCount[ gpt, text ],
            Wolfram`Chatbook`ChatMessages`Private`tokenCount[ bison, text ],
            Wolfram`Chatbook`ChatMessages`Private`tokenCount[ gpt, text ],
            Wolfram`Chatbook`ChatMessages`Private`tokenCount[ bison, text ],
            Length @ ToCharacterCode[ text, "UTF8" ],
            withoutTokenCountCache @ Wolfram`Chatbook`ChatMessages`Private`tokenCount[ gpt, text ],
            tokenCountCacheSize[ ]
        }
    ],
    { a_Integer, b_Integer, a_, b_, b_, a_, 2 } /; a =!= b,
    SameTest -> MatchQ,
    TestID   -> "SeparateTokenizers@@Tests/TokenCount.wlt:141,1-159,2"
]

VerificationTest[
    Module[ { settings, text, calls, count },
        settings = tokenizerSettings[ "gpt-4o" ];
        text     = "A cached count does not apply the tokenizer again";
        (* Counts the same text three times and returns the counts and the number of times the tokenizer was applied: *)
        count[ ] := Block[
            { calls = 0, Wolfram`Chatbook`ChatMessages`Private`applyTokenizer0 = (calls++; #1[ #2 ]) & },
            { Table[ Wolfram`Chatbook`ChatMessages`Private`tokenCount[ settings, text ], 3 ], calls }
        ];
        { withoutTokenCountCache @ count[ ], withTokenCountCache @ count[ ] }
    ],
    { { { n_Integer, n_, n_ }, 3 }, { { n_, n_, n_ }, 1 } },
    SameTest -> MatchQ,
    TestID   -> "CacheHitSkipsTokenizer@@Tests/TokenCount.wlt:161,1-175,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Custom Tokenizers*)
VerificationTest[
    withTokenCountCache @ Module[ { text, custom, mismatched },
        text   = "Custom tokenizers are not cached";
        custom = <| "TokenizerName" -> "Custom", "Tokenizer" -> (ConstantArray[ 0, StringLength @ # ] &) |>;
        (* A custom tokenizer that does not correspond to the given tokenizer name: *)
        mismatched = <| custom, "TokenizerName" -> "gpt-4o" |>;
        {
            Wolfram`Chatbook`ChatMessages`Private`tokenCount[ tokenizerSettings[ "gpt-4o" ], text ],
            Wolfram`Chatbook`ChatMessages`Private`tokenCount[ custom, text ],
            Wolfram`Chatbook`ChatMessages`Private`tokenCount[ mismatched, text ],
            StringLength @ text,
            tokenCountCacheSize[ ]
        }
    ],
    { a_Integer, n_Integer, n_, n_, 1 } /; a =!= n,
    SameTest -> MatchQ,
    TestID   -> "CustomTokenizerNotCached@@Tests/TokenCount.wlt:180,1-197,2"
]

VerificationTest[
    withTokenCountCache @ Module[ { i = 0, settings },
        settings = <| "TokenizerName" -> "Custom", "Tokenizer" -> Function[ ConstantArray[ 0, ++i ] ] |>;
        {
            Table[ Wolfram`Chatbook`ChatMessages`Private`tokenCount[ settings, "Same text" ], 3 ],
            tokenCountCacheSize[ ]
        }
    ],
    { { 1, 2, 3 }, 0 },
    SameTest -> MatchQ,
    TestID   -> "NonDeterministicTokenizerNotCached@@Tests/TokenCount.wlt:199,1-210,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cache Size*)
VerificationTest[
    withTokenCountCache @ Block[ { Wolfram`Chatbook`ChatMessages`Private`$maxTokenCountCacheSize = 10 },
        Module[ { settings, messages, sizes, keys },
            settings = tokenizerSettings[ "gpt-4o" ];
            messages = Table[ "Message number " <> ToString @ i <> StringRepeat[ " word", i ], { i, 25 } ];
            sizes    = Table[
                Wolfram`Chatbook`ChatMessages`Private`tokenCount[ settings, message ];
                tokenCountCacheSize[ ],
                { message, messages }
            ];
            keys = Keys @ Wolfram`Chatbook`ChatMessages`Private`$tokenCountCache;
            {
                sizes,
                (* The oldest half of the entries is discarded when the cache is full: *)
                keys === ({ "gpt-4o", True, Hash @ # } & /@ Take[ messages, -10 ]),
                countTokens[ settings, messages ] === withoutTokenCountCache @ countTokens[ settings, messages ],
                tokenCountCacheSize[ ] <= 10
            }
        ]
    ],
    { Join[ Range[ 10 ], Range[ 6, 10 ], Range[ 6, 10 ], Range[ 6, 10 ] ], True, True, True },
    SameTest -> MatchQ,
    TestID   -> "CacheSizeIsBounded@@Tests/TokenCount.wlt:215,1-238,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*tokenCheckedMessage*)
VerificationTest[
    Module[ { settings, messages, run, uncached, cold, warm },

        settings = tokenizerSettings[ "gpt-4o" ];
        (* The last message is too large for the remaining budget, so it gets truncated: *)
        messages = Join[ $textMessages, { <| "Role" -> "User", "Content" -> StringRepeat[ $longText, 4 ] |> } ];

        run[ ] := Block[
            {
                Wolfram`Chatbook`Common`$tokenBudget             = 2000,
                Wolfram`Chatbook`Common`$tokenPressure           = 0.0,
                Wolfram`Chatbook`Common`$initialCellStringBudget = 10000,
                Wolfram`Chatbook`Common`$cellStringBudget        = 10000,
                Wolfram`Chatbook`Common`$tokenBudgetLog          = Internal`Bag[ ]
            },
            {
                Wolfram`Chatbook`ChatMessages`Private`tokenCheckedMessage[ settings, # ] & /@ messages,
                Wolfram`Chatbook`Common`$tokenBudget,
                Wolfram`Chatbook`Common`$tokenPressure,
                Wolfram`Chatbook`Common`$cellStringBudget,
                Internal`BagPart[ Wolfram`Chatbook`Common`$tokenBudgetLog, All ]
            }
        ];

        uncached = withoutTokenCountCache @ run[ ];
        { cold, warm } = withTokenCountCache @ { run[ ], run[ ] };

        {
            cold === uncached,
            warm === uncached,
            Length @ Last @ uncached === Length @ messages,
            Last @ First @ uncached =!= Last @ messages
        }
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "BudgetSideEffects@@Tests/TokenCount.wlt:243,1-280,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*logUsage*)
VerificationTest[
    Module[ { settings, messages, response, run, uncached, cold, warm },

        settings = tokenizerSettings[ "gpt-4o" ];
        messages = Select[ $textMessages, AssociationQ ];
        response = "The eigenvalues can be computed with `Eigenvalues`.";

        (* First request, then a second request after a tool call: *)
        run[ ] := Block[ { $ChatHandlerData = <| |> },
            Wolfram`Chatbook`Common`logUsage[ settings, messages, response ];
            Wolfram`Chatbook`Common`logUsage[
                settings,
                Append[ messages, <| "Role" -> "Assistant", "Content" -> response |> ],
                "Done."
            ];
            $ChatHandlerData[ "Usage" ]
        ];

        uncached = withoutTokenCountCache @ run[ ];
        { cold, warm } = withTokenCountCache @ { run[ ], run[ ] };

        { uncached, cold === uncached, warm === uncached }
    ],
    { KeyValuePattern @ { "Prompt" -> _Integer, "Completion" -> _Integer, "Requests" -> 2 }, True, True },
    SameTest -> MatchQ,
    TestID   -> "LogUsage@@Tests/TokenCount.wlt:285,1-311,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Token Count Estimates*)

(* The tokenizers of the current models estimate the token count of text, which doesn't need a NetEncoder: *)
VerificationTest[
    withTokenCountCache @ Block[
        {
            Wolfram`Chatbook`Common`$cachedTokenizers = KeyDrop[
                Wolfram`Chatbook`Common`$cachedTokenizers,
                { "gpt-4o-text", "claude", "gpt-2" }
            ]
        },
        {
            countTokens[ tokenizerSettings @ #, { $longText } ] & /@ { "gpt-4o", "claude-3", "generic" },
            Keys @ KeyTake[ Wolfram`Chatbook`Common`$cachedTokenizers, { "gpt-4o-text", "claude", "gpt-2" } ]
        }
    ],
    { { { n_Integer? Positive }, { n_ }, { n_ } }, { } },
    SameTest -> MatchQ,
    TestID   -> "Estimate-NoNetEncoder@@Tests/TokenCount.wlt:318,1-334,2"
]

(* The estimate must not be below the exact counts for typical content, and not far above them: *)
VerificationTest[
    Module[ { texts, estimates, exact },
        texts = {
            $longText,
            "How do I compute the eigenvalues of a matrix, and which function plots them in the complex plane?",
            "Plot3D[Sin[x] Cos[y], {x, 0, 2 Pi}, {y, 0, 2 Pi}, PlotRange -> All, ColorFunction -> \"Rainbow\"]",
            StringRiffle[ Table[ ToString @ N[ Sqrt @ i, 10 ], { i, 200 } ], ", " ],
            StringRiffle[ "paclet:ref/" <> # <> "#" <> ToString @ Hash @ # & /@ Take[ Names[ "System`*Plot*" ], 60 ], "
" ],
            (* Russian, which the claude tokenizer counts at about four times the gpt-4o count: *)
            StringJoin[
                "\:0424\:0443\:043d\:043a\:0446\:0438\:044f Plot \:0440\:0438\:0441\:0443\:0435\:0442 ",
                "\:043a\:0440\:0438\:0432\:0443\:044e \:0434\:043b\:044f \:0444\:0443\:043d\:043a\:0446\:0438\:0438 ",
                "\:043e\:0434\:043d\:043e\:0439 \:043f\:0435\:0440\:0435\:043c\:0435\:043d\:043d\:043e\:0439. ",
                "\:0418\:0441\:043f\:043e\:043b\:044c\:0437\:0443\:0439\:0442\:0435 Plot[{Sin[x], Cos[x]}, {x, 0, 2 ",
                "Pi}], \:0447\:0442\:043e\:0431\:044b \:043f\:043e\:043a\:0430\:0437\:0430\:0442\:044c ",
                "\:043e\:0431\:0435 \:043a\:0440\:0438\:0432\:044b\:0435 \:043d\:0430 \:043e\:0434\:043d\:0438\:0445 ",
                "\:043e\:0441\:044f\:0445, \:0438 \:0434\:043e\:0431\:0430\:0432\:044c\:0442\:0435 PlotLegends, ",
                "\:0447\:0442\:043e\:0431\:044b \:043f\:043e\:0434\:043f\:0438\:0441\:0430\:0442\:044c \:0438\:0445."
            ],
            ExampleData @ { "Text", "DeclarationOfIndependence" }
        };
        estimates = Wolfram`Chatbook`Common`estimateTokenCount /@ texts;
        exact = Table[
            Length @ Wolfram`Chatbook`Common`cachedTokenizer[ name ][ text ],
            { name, { "gpt-4o-text", "claude" } },
            { text, texts }
        ];
        {
            And @@ Thread[ estimates >= Max /@ Transpose @ exact ],
            And @@ Thread[ estimates <= 1.6 * Max /@ Transpose @ exact ]
        }
    ],
    { True, True },
    TestID -> "Estimate-NotBelowExactCounts@@Tests/TokenCount.wlt:337,1-372,2"
]

VerificationTest[
    {
        Wolfram`Chatbook`Common`estimateTokenCount[ "" ],
        Wolfram`Chatbook`Common`estimateTokenCount /@ { "a", " ", "
", "\[Alpha]", "\:65e5", "\|01f600", "7" },
        Length @ Wolfram`Chatbook`ChatMessages`Private`estimatedTokenizer[ "Hello world" ] === Wolfram`Chatbook`Common`estimateTokenCount[ "Hello world" ],
        (* Texts of the same kind are counted in proportion to their length: *)
        Wolfram`Chatbook`Common`estimateTokenCount @ StringRepeat[ $longText <> "

", 20 ] / Wolfram`Chatbook`Common`estimateTokenCount[ $longText <> "

" ]
    },
    { 0, { __Integer? Positive }, True, n_ /; 19.9 <= n <= 20.1 },
    SameTest -> MatchQ,
    TestID   -> "Estimate-EdgeCases@@Tests/TokenCount.wlt:374,1-390,2"
]

(* Exact counts are still available, and the two kinds of counts are cached separately: *)
VerificationTest[
    withTokenCountCache @ Module[ { settings, estimated, exact },
        settings  = tokenizerSettings[ "gpt-4o" ];
        estimated = Wolfram`Chatbook`ChatMessages`Private`tokenCount[ settings, $longText ];
        exact     = Block[ { Wolfram`Chatbook`Common`$estimateTokenCounts = False }, Wolfram`Chatbook`ChatMessages`Private`tokenCount[ settings, $longText ] ];
        {
            estimated === Wolfram`Chatbook`Common`estimateTokenCount @ $longText,
            exact === Length @ Wolfram`Chatbook`Common`cachedTokenizer[ "gpt-4o-text" ][ $longText ],
            estimated =!= exact,
            Wolfram`Chatbook`ChatMessages`Private`tokenCount[ settings, $longText ] === estimated,
            Wolfram`Chatbook`ChatMessages`Private`tokenCount[ tokenizerSettings[ "gpt-4o-text" ], $longText ] === exact
        }
    ],
    { True, True, True, True, True },
    TestID -> "Estimate-ExactCounts@@Tests/TokenCount.wlt:393,1-408,2"
]

(* A message is left empty when the remaining budget is too small for any of it: *)
VerificationTest[
    Table[
        Block[
            {
                Wolfram`Chatbook`Common`$tokenBudget             = budget,
                Wolfram`Chatbook`Common`$tokenPressure           = 0.0,
                Wolfram`Chatbook`Common`$initialCellStringBudget = 10000,
                Wolfram`Chatbook`Common`$cellStringBudget        = 10000,
                Wolfram`Chatbook`Common`$tokenBudgetLog          = Internal`Bag[ ]
            },
            StringLength @ Wolfram`Chatbook`ChatMessages`Private`tokenCheckedMessage[
                tokenizerSettings[ "gpt-4o" ],
                <| "Role" -> "User", "Content" -> $longText |>
            ][ "Content" ]
        ],
        { budget, { 0, 1, 5, 100 } }
    ],
    { 0, 0, 0, n_Integer /; n > 100 },
    SameTest -> MatchQ,
    TestID   -> "TinyBudget@@Tests/TokenCount.wlt:411,1-431,2"
]

(* :!CodeAnalysis::EndBlock:: *)
