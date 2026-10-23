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
    TestID   -> "Definitions"
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
    TestID   -> "CachedCountsMatchUncached"
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
    TestID   -> "ImageContentNotCached"
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
    TestID   -> "SeparateTokenizers"
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
    TestID   -> "CustomTokenizerNotCached"
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
    TestID   -> "NonDeterministicTokenizerNotCached"
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
                keys === ({ "gpt-4o", Hash @ # } & /@ Take[ messages, -10 ]),
                countTokens[ settings, messages ] === withoutTokenCountCache @ countTokens[ settings, messages ],
                tokenCountCacheSize[ ] <= 10
            }
        ]
    ],
    { Join[ Range[ 10 ], Range[ 6, 10 ], Range[ 6, 10 ], Range[ 6, 10 ] ], True, True, True },
    SameTest -> MatchQ,
    TestID   -> "CacheSizeIsBounded"
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
    TestID   -> "BudgetSideEffects"
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
    TestID   -> "LogUsage"
]

(* :!CodeAnalysis::EndBlock:: *)
