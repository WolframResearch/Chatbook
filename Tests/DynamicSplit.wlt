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

(* While streaming, writeChunk0 splits completed code blocks, images, and tool calls out of the dynamic content so they
   can be written as static content. To avoid scanning the entire dynamic content for every chunk, the split is skipped
   when the new text can't complete a match. These tests check that the results are always the same as splitting the
   entire content every time. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    (* The original implementation, which splits the entire content for every chunk (and declines a split in a think
       tag, as splitDynamicContent does): *)
    referenceSplit[ content_String ] :=
        With[ { split = StringSplit[ content, Wolfram`Chatbook`Common`$dynamicSplitRules, All ] },
            If[ Wolfram`Chatbook`SendChat`Private`thinkTagSplitQ @ split, { content }, DeleteCases[ split, "" ] ]
        ];

    (* Splits a string into chunks of random lengths: *)
    randomChunks[ text_String, seed_Integer, max_Integer ] := BlockRandom[
        SeedRandom @ seed;
        Module[ { sizes = { }, total = 0, k },
            While[ total < StringLength @ text,
                k = Min[ RandomInteger[ { 1, max } ], StringLength @ text - total ];
                AppendTo[ sizes, k ];
                total += k
            ];
            StringTake[ text, Transpose @ { Accumulate @ sizes - sizes + 1, Accumulate @ sizes } ]
        ]
    ];

    (* Changes made to the dynamic content outside of writeChunk0 (e.g. by checkForBadRetry, appendToolResult,
       trimPartialStopToken, appendCitations, and removeSeverityTag): *)
    modifyContent[ content_String ] := Switch[ RandomInteger[ { 1, 5 } ],
        1, content <> "\n/retry\n",
        2, content <> "\nRESULT\nOut[1]= 2\nENDRESULT(xyz)\n",
        3, StringDrop[ content, -Min[ StringLength @ content, RandomInteger[ { 1, 4 } ] ] ],
        4, content <> " [1](https://example.com/source) (citation)",
        5, StringDrop[ content, Min[ StringLength @ content, RandomInteger[ { 1, 30 } ] ] ]
    ];

    (* Updates the dynamic content for each chunk like writeChunk0 does, occasionally modifying it in between chunks,
       and compares the split with the reference at every step. Gives the number of mismatches and skipped splits.
       The probability of modifying the content before each chunk is given by `p`: *)
    compareSplits[ chunks_List, seed_Integer, p_: 0.05 ] := BlockRandom[
        SeedRandom @ seed;
        Block[ { Wolfram`Chatbook`SendChat`Private`$dynamicSplitChecked = None },
            Module[ { dynamic, mismatches = 0, skipped = 0, new, parts, expected },
                dynamic = ProgressIndicator[ Appearance -> "Percolate" ];
                Do[
                    If[ StringQ @ dynamic && RandomReal[ ] < p, dynamic = modifyContent @ dynamic ];
                    new = Wolfram`Chatbook`SendChat`Private`appendStringContent[ dynamic, chunk ];
                    If[ Wolfram`Chatbook`SendChat`Private`dynamicSplitSkipQ[
                            new,
                            Wolfram`Chatbook`SendChat`Private`$dynamicSplitChecked
                        ],
                        skipped++
                    ];
                    parts    = Wolfram`Chatbook`SendChat`Private`splitDynamicContent @ new;
                    expected = referenceSplit @ new;
                    If[ parts =!= expected, mismatches++ ];
                    dynamic = If[ Length @ expected > 1, Last @ expected, new ],
                    { chunk, chunks }
                ];
                { mismatches, skipped }
            ]
        ]
    ];

    (* Streams chunks through writeChunk0 with front end operations stubbed out, giving the parts that would be written
       as static content along with the final container contents: *)
    writeChunks[ chunks_List ] := Module[ { container, static = { } },
        container = <|
            "DynamicContent" -> ProgressIndicator[ Appearance -> "Percolate" ],
            "FullContent"    -> ProgressIndicator[ Appearance -> "Percolate" ]
        |>;
        Block[
            {
                Wolfram`Chatbook`Common`$alwaysOpen                         = False,
                Wolfram`Chatbook`SendChat`Private`$dynamicSplit             = True,
                Wolfram`Chatbook`SendChat`Private`$dynamicSplitChecked      = None,
                Wolfram`Chatbook`SendChat`Private`writeDynamicChunkAsStatic = Function[ AppendTo[ static, #1 ] ],
                Wolfram`Chatbook`SendChat`Private`openChatCell              = Function[ Null ]
            },
            Scan[ Wolfram`Chatbook`SendChat`Private`writeChunk0[ Dynamic @ container, None, #, # ] &, chunks ]
        ];
        { static, container[ "DynamicContent" ], container[ "FullContent" ] }
    ];

    (* Makes "wl" and "wa" valid tool names for simple tool calls: *)
    withToolNames // Attributes = { HoldFirst };
    withToolNames[ eval_ ] := Block[
        { Wolfram`Chatbook`Common`toolShortNameQ = Function[ MemberQ[ { "wl", "wa" }, #1 ] ] },
        eval
    ];

    $splitCorpora = <|
        "Markdown" -> StringJoin[
            "## Solving the problem\n\nTo compute the **eigenvalues** of a matrix (in general), use `Eigenvalues`.\n\n",
            "```wl\nm = {{2, -1}, {-1, 2}};\nEigenvalues[m]\n```\n\n",
            "Inline code like ```Eigenvalues[m]``` is not a block. Use `N[m]` (machine precision) for speed.\n\n",
            "```\nplain block without a language\n```\n",
            "| Function | Returns |\n|---|---|\n| `Eigenvalues` | values (exact) |\n\n",
            "The roots are $2 \\pm \\sqrt{2}$, so f(x) = (x - 1)(x - 3).\n\n",
            "````markdown\n```wl\nnested\n```\n````\n\nDone."
        ],
        "Images" -> StringJoin[
            "Here is a plot (see below):\n\n![Plot of sin(x)](attachment://content-1234.png)\n\n",
            "And another ![a [nested](link) alt](https://example.com/a.png) inline (with parens).\n\n",
            "![unterminated](https://example.com/b.png\n\nmore text (with parens) here.\n\n",
            "![second](https://example.com/c.png) and ![third](https://example.com/d.png)."
        ],
        "ToolCalls" -> StringJoin[
            "Let me check that (quickly).\n\nTOOLCALL: wolfram_language_evaluator\n{\"code\": \"Prime[5]\"}\n",
            "ENDARGUMENTS\nENDTOOLCALL\nRESULT\n11\nENDRESULT\n\nThe answer is 11 (the fifth prime).\n\n",
            "TOOLCALL: web_search\n{\"query\": \"x\"}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\nfound (2)\nENDRESULT(a1b2c3)\n\n",
            "Done."
        ],
        "SimpleToolCalls" -> StringJoin[
            "Running it now:\n\n/wl\nPrime[123]\n/exec\nRESULT\nOut[1]= 677\nENDRESULT(70ua8j1ev)\n\n",
            "The result is 677 (as expected).\n\n```\n/wl\n1 + 1\n```\n\n",
            "```wl\n/wa\nweather\n```\n\nENDRESULT without a tool call, then ENDRESULT( and ENDRESULT(x) here.\n\n",
            "  /wa\npopulation of France\n/exec\nRESULT\n68 million\nENDRESULT\n"
        ],
        "Reasoning" -> StringJoin[
            "<think type='summary' id='abc123'>\n**Planning**\n\nI will write ```code``` and call (maybe) a tool.\n",
            "</think>\nHere is the code:\n\n```wl\nf[x_] := x^2\n```\n\nAnd f(3) = 9."
        ],
        (* A code block and an image in the thoughts (quirk 202): *)
        "Thinking" -> StringJoin[
            "<think>\nLet me compute:\n```wl\n1+1\n```\nThat gives 2 (as expected), see ![sum](attachment://a).\n",
            "</think>\nThe answer is:\n\n```wl\n1 + 1\n```\n\nIt gives 2, and ![a plot](attachment://content-1) shows it."
        ],
        (* Auto-correction can change text that came before the new chunk: *)
        "AutoCorrect" -> StringJoin[
            "Audio: \\!\\(\\*AudioBox[\"attachment://audio-1.wav\"]\\) done (ok).\n\n",
            "Some ```inline``` code and paclet:ref/ResourceFunction/Foo (a link).\n\n",
            "```wl\nx = 1\n```\nEnd."
        ],
        "Prose" -> StringRiffle[
            Table[
                "Paragraph " <> ToString @ i <> " talks about f(x) = x^2 (a parabola), with `code` and **bold** text.",
                { i, 40 }
            ],
            "\n\n"
        ]
    |>;
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*dynamicSplitSkipQ*)
VerificationTest[
    Wolfram`Chatbook`SendChat`Private`dynamicSplitSkipQ @@@ {
        (* Only text without delimiters was added: *)
        { "Some text and more", "Some text" },
        { "f(x) = x^2", "f(x" },
        { "Same", "Same" },
        { "Anything", "" },
        (* A delimiter was completed by the new text: *)
        { "```wl\nx```", "```wl\nx``" },
        { "TOOLCALL: x\nENDRESULT", "TOOLCALL: x\nENDRES" },
        { "TOOLCALL: x\nENDRESULT(abc)", "TOOLCALL: x\nENDRESULT(abc" },
        { "See ![image](url)", "See ![image](url" },
        (* The content was changed before the new text: *)
        { "Some test and more", "Some text" },
        { "Some", "Some text" },
        (* There's nothing known about the content: *)
        { "Some text", None }
    },
    { True, True, True, True, False, False, False, False, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "DynamicSplitSkipQ"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*splitDynamicContent*)
VerificationTest[
    Block[ { Wolfram`Chatbook`SendChat`Private`$dynamicSplitChecked = None },
        Function[
            content,
            {
                Wolfram`Chatbook`SendChat`Private`splitDynamicContent @ content,
                Wolfram`Chatbook`SendChat`Private`$dynamicSplitChecked
            }
        ] /@ {
            "Some text",
            "Some text (more)",
            "Some text (more)\n```wl\n1+1",
            "Some text (more)\n```wl\n1+1\n```",
            "```wl\n1+1\n```",
            "```wl\n1+1\n```\nMore",
            "More",
            ""
        }
    ],
    {
        { { "Some text" }, "Some text" },
        { { "Some text (more)" }, "Some text (more)" },
        { { "Some text (more)\n```wl\n1+1" }, "Some text (more)\n```wl\n1+1" },
        { { "Some text (more)\n", "```wl\n1+1\n```" }, None },
        { { "```wl\n1+1\n```" }, None },
        { { "```wl\n1+1\n```", "\nMore" }, None },
        { { "More" }, "More" },
        { { }, "" }
    },
    SameTest -> MatchQ,
    TestID   -> "SplitDynamicContent-CheckedContent"
]

(* The checked content is not used after the start of the content changes (e.g. when removeSeverityTag removes a tag): *)
VerificationTest[
    Block[ { Wolfram`Chatbook`SendChat`Private`$dynamicSplitChecked = None },
        {
            Wolfram`Chatbook`SendChat`Private`splitDynamicContent[ "[WARNING] Here is code:\n```wl\nx\n``" ],
            Wolfram`Chatbook`SendChat`Private`splitDynamicContent[ "Here is code:\n```wl\nx\n```\nAnd then more" ]
        }
    ],
    {
        { "[WARNING] Here is code:\n```wl\nx\n``" },
        { "Here is code:\n", "```wl\nx\n```", "\nAnd then more" }
    },
    SameTest -> MatchQ,
    TestID   -> "SplitDynamicContent-ChangedStart"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`SendChat`Private`$dynamicSplitChecked = None },
        Function[
            content,
            Wolfram`Chatbook`SendChat`Private`splitDynamicContent @ content === referenceSplit @ content
        ] /@ Join[
            Values @ $splitCorpora,
            { "", " ", "```", "``````", "TOOLCALL:ENDRESULT", "![](", "![a](b)", "x ![a](b)", "![a](b) x" }
        ]
    ],
    { True .. },
    SameTest -> MatchQ,
    TestID   -> "SplitDynamicContent-Reference"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Streaming*)

(* Splits the content from random chunkings of each corpus and compares the results with the reference at every step: *)
VerificationTest[
    Flatten[
        Table[
            With[
                {
                    result = If[ tools,
                        withToolNames @ compareSplits[ randomChunks[ corpus, seed, max ], seed ],
                        compareSplits[ randomChunks[ corpus, seed, max ], seed ]
                    ]
                },
                If[ First @ result === 0, { }, { { corpus, seed, max, tools, result } } ]
            ],
            { corpus, Values @ $splitCorpora },
            { seed, 3 },
            { max, { 3, 9, 25 } },
            { tools, { False, True } }
        ],
        4
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "SplitDynamicContent-RandomChunks"
]

(* Most chunks of long prose should not need a full split: *)
VerificationTest[
    Module[ { chunks, result },
        chunks = randomChunks[ $splitCorpora[ "Prose" ], 1, 9 ];
        result = compareSplits[ chunks, 1, 0 ];
        { First @ result, Last @ result / Length @ chunks > 0.8 }
    ],
    { 0, True },
    SameTest -> MatchQ,
    TestID   -> "SplitDynamicContent-SkipsProse"
]

(* The full writeChunk0 results (static parts and final content) are the same as with the reference implementation: *)
VerificationTest[
    Flatten[
        Table[
            With[ { chunks = randomChunks[ corpus, seed, max ] },
                If[ writeChunks @ chunks === Block[
                        { Wolfram`Chatbook`SendChat`Private`splitDynamicContent = referenceSplit },
                        writeChunks @ chunks
                    ],
                    { },
                    { { corpus, seed, max } }
                ]
            ],
            { corpus, Values @ $splitCorpora },
            { seed, 1 },
            { max, { 4, 16 } }
        ],
        3
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "WriteChunk0-Reference"
]

(* Static parts are actually written while streaming: *)
VerificationTest[
    Module[ { static, dynamic, full },
        { static, dynamic, full } = writeChunks @ randomChunks[ $splitCorpora[ "Markdown" ], 1, 5 ];
        {
            Length @ static >= 3,
            StringContainsQ[ StringJoin @ static, "```wl\nm = {{2, -1}, {-1, 2}};\nEigenvalues[m]\n```" ],
            StringContainsQ[ StringJoin @ static, "```\nplain block without a language\n```" ],
            StringEndsQ[ full, dynamic ]
        }
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "WriteChunk0-StaticParts"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Think Tags*)

(* A split in an open think tag is declined (quirk 202), since the static part would end the thoughts early. So is a
   split after a code fence that opens in the thoughts and closes after them, but not a split after a tag in a code
   block. Declined content is checked content, so the next chunk only splits again if it can complete a match: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`SendChat`Private`$dynamicSplitChecked = None },
        Function[
            content,
            {
                Wolfram`Chatbook`SendChat`Private`splitDynamicContent @ content,
                Wolfram`Chatbook`SendChat`Private`$dynamicSplitChecked
            }
        ] /@ {
            "<think>\nLet me compute:\n```wl\n1+1\n```",
            "<think>\nLet me compute:\n```wl\n1+1\n```\nThat gives 2.\n</think>\nThe answer",
            "<think>\nLet me compute:\n```wl\n1+1\n```\nThat gives 2.\n</think>\nThe answer:\n```wl\n2\n```\nDone",
            "<thinking>\nI will write ```code``` here.\n</thinking>\nCode:\n```wl\nx\n```\nDone",
            "The opener:\n```xml\n<think>\n```\nDone"
        }
    ],
    {
        { { "<think>\nLet me compute:\n```wl\n1+1\n```" }, "<think>\nLet me compute:\n```wl\n1+1\n```" },
        {
            { "<think>\nLet me compute:\n```wl\n1+1\n```\nThat gives 2.\n</think>\nThe answer" },
            "<think>\nLet me compute:\n```wl\n1+1\n```\nThat gives 2.\n</think>\nThe answer"
        },
        {
            {
                "<think>\nLet me compute:\n",
                "```wl\n1+1\n```",
                "\nThat gives 2.\n</think>\nThe answer:\n",
                "```wl\n2\n```",
                "\nDone"
            },
            None
        },
        {
            { "<thinking>\nI will write ```code``` here.\n</thinking>\nCode:\n```wl\nx\n```\nDone" },
            "<thinking>\nI will write ```code``` here.\n</thinking>\nCode:\n```wl\nx\n```\nDone"
        },
        { { "The opener:\n", "```xml\n<think>\n```", "\nDone" }, None }
    },
    SameTest -> MatchQ,
    TestID   -> "SplitDynamicContent-ThinkTags"
]

(* Prose after declined content should not need a full split for every chunk: *)
VerificationTest[
    Module[ { chunks, result },
        chunks = randomChunks[ "<think>\n```wl\n1+1\n```\n</think>\n" <> $splitCorpora[ "Prose" ], 1, 9 ];
        result = compareSplits[ chunks, 1, 0 ];
        { First @ result, Last @ result / Length @ chunks > 0.8 }
    ],
    { 0, True },
    SameTest -> MatchQ,
    TestID   -> "SplitDynamicContent-SkipsDeclined"
]

(* While streaming, the static parts that are written never end in the thoughts: *)
VerificationTest[
    Flatten @ Table[
        Module[ { static },
            static = First @ writeChunks @ randomChunks[ $splitCorpora[ "Thinking" ], seed, max ];
            {
                Length @ static >= 1,
                AllTrue[ static, StringCount[ #, "<think" ] === StringCount[ #, "</think" ] & ]
            }
        ],
        { seed, 3 },
        { max, { 3, 20 } }
    ],
    { True .. },
    SameTest -> MatchQ,
    TestID   -> "WriteChunk0-ThinkTags"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Consistency*)

(* The static part of a split is formatted on its own, so a split point has to be a boundary between the parts that
   $textDataFormatRules gives for the whole text: formatting the static part and the rest separately gives the same
   parts as formatting the whole text. Whitespace at the ends of text parts is ignored, since it can move across a split
   point (bullets, headings and /retry take the newlines before them) and each cell trims it.

   splitDynamicContent declines the split points next to a match in a think tag (see thinkTagSplitQ in SendChat.wl), so
   these are skipped below. It makes the split point before a match when the text so far ends with that match, and the
   one after a match when more text follows, so it sees the parts up to the end of that match either way.

   Known exception: an image or tool call inside a list item, heading, table row or block quote, or inside a code block
   that isn't closed yet. The split rules don't see these blocks and split it out of them. The documents here avoid
   this. *)
VerificationTest[
    (* With All, the parts alternate between text and matches: *)
    splitParts[ text_String ] := StringSplit[ text, Wolfram`Chatbook`Common`$dynamicSplitRules, All ];

    formatParts[ text_String ] := normalizeParts @ StringSplit[
        text,
        Wolfram`Chatbook`Formatting`Private`$textDataFormatRules,
        IgnoreCase -> True
    ];

    (* Joins adjacent strings, trims them, and drops the empty ones. A ``` at either end of a text is dropped, as
       formatTextString does, since the split rules leave the code fence line of a tool call written in a code fence in
       the static part: *)
    normalizeParts[ parts_List ] := DeleteCases[
        Flatten @ Replace[ Split[ parts, StringQ[ #1 ] && StringQ[ #2 ] & ], s: { __String } :> normalizeText @ s, { 1 } ],
        ""
    ];

    normalizeText[ strings_List ] := StringTrim @ StringDelete[
        StringJoin @ strings,
        { StartOfString ~~ "\n"... ~~ "```", "```" ~~ "\n"... ~~ EndOfString }
    ];

    (* Whether splitDynamicContent declines the split point after the i-th part (the parts up to the end of the match
       next to it, and then any text): *)
    declinedQ[ parts_List, i_Integer ] :=
        Wolfram`Chatbook`SendChat`Private`thinkTagSplitQ @ Append[ parts[[ ;; If[ OddQ @ i, i + 1, i ] ]], "" ];

    (* The split points (after the i-th part) where formatting the two sides separately gives different parts: *)
    inconsistentSplits[ text_String ] := Module[ { parts, whole },
        parts = splitParts @ text;
        (* The TOOLCALL rule adds a newline after its match, so this isn't always the same as text: *)
        whole = formatParts @ StringJoin @ parts;
        Select[
            Range[ Length @ parts - 1 ],
            Function[
                i,
                And[
                    ! declinedQ[ parts, i ],
                    whole =!= normalizeParts @ Join[
                        formatParts @ StringJoin @ parts[[ ;; i ]],
                        formatParts @ StringJoin @ parts[[ i + 1 ;; ]]
                    ]
                ]
            ]
        ]
    ];

    $consistencyCorpora = Append[
        $splitCorpora,
        "Blocks" -> StringJoin[
            "<thinking>\nThe user wants a plot.\n</thinking>\n## Plot\n\n![plot](attachment://content-abc12)\n",
            "* an item with `code`\n* another item\n\n```wl\nPlot[x, {x, 0, 1}]\n```\n| a | b |\n|---|---|\n| 1 | 2 |\n\n",
            "> a quote\n\n---\nI'll check (again).\n\nTOOLCALL: wl\n{}\nENDTOOLCALL\nRESULT\n1\nENDRESULT\n/retry\n",
            "/wl\n1 + 1\n/exec\nRESULT\n2\nENDRESULT\n### Done with $x^2$"
        ]
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Consistency-Definitions"
]

VerificationTest[
    {
        Select[ inconsistentSplits /@ $consistencyCorpora, # =!= { } & ],
        withToolNames @ Select[ inconsistentSplits /@ $consistencyCorpora, # =!= { } & ]
    },
    { <| |>, <| |> },
    SameTest -> MatchQ,
    TestID   -> "SplitDynamicContent-ConsistentParts"
]

(* See $dynamicSplitRules for why dynamicSplitSkipQ relies on this: *)
VerificationTest[
    withToolNames @ With[ { matches = Flatten[ splitParts[ # ][[ 2 ;; ;; 2 ]] & /@ Values @ $consistencyCorpora ] },
        {
            Length @ matches,
            (* The TOOLCALL rule adds a newline after its match: *)
            Select[ matches, ! StringEndsQ[ StringDelete[ #, "\n" ~~ EndOfString ], "```" | "ENDRESULT" | ")" ] & ]
        }
    ],
    { _? (GreaterThan[ 15 ]), { } },
    SameTest -> MatchQ,
    TestID   -> "SplitDynamicContent-MatchEnds"
]

(* :!CodeAnalysis::EndBlock:: *)
