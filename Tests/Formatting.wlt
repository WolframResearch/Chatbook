(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Formatting.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Formatting.wlt:11,1-16,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*TeX Escapes*)

(* Inside math the escape belongs to TeX rather than markdown, so the backslash has to reach the TeX parser
   intact for it to render a literal dollar sign: *)
VerificationTest[
    FirstCase[
        FormatChatOutput[ "Here is some TeX: $$\\$123.45 / \\$6.78$$" ],
        TemplateBox[ as_Association, "TeXAssistantTemplate" ] :> as,
        $Failed,
        Infinity
    ],
    KeyValuePattern @ {
        "input" -> "\\$123.45 / \\$6.78",
        "boxes" -> FormBox[ RowBox @ { "$123.45", "/", "$6.78" }, TraditionalForm ],
        "state" -> "Boxes"
    },
    SameTest -> MatchQ,
    TestID   -> "TeX-Escaped-Dollar@@Tests/Formatting.wlt:24,1-38,2"
]

(* The same holds for the other characters markdown escapes: *)
VerificationTest[
    FirstCase[
        FormatChatOutput[ "$$a \\_ b \\# c$$" ],
        TemplateBox[ as_Association, "TeXAssistantTemplate" ] :> as,
        $Failed,
        Infinity
    ],
    KeyValuePattern @ {
        "input" -> "a \\_ b \\# c",
        "boxes" -> FormBox[
            RowBox @ { StyleBox[ "a", "TI" ], "_", StyleBox[ "b", "TI" ], "#", StyleBox[ "c", "TI" ] },
            TraditionalForm
        ],
        "state" -> "Boxes"
    },
    SameTest -> MatchQ,
    TestID   -> "TeX-Escaped-Underscore-And-Hash@@Tests/Formatting.wlt:41,1-58,2"
]

VerificationTest[
    FirstCase[
        FormatChatOutput[ "Before \\[x^2\\] after" ],
        TemplateBox[ as_Association, "TeXAssistantTemplate" ] :> as,
        $Failed,
        Infinity
    ],
    KeyValuePattern @ {
        "input" -> "x^2",
        "state" -> "Boxes"
    },
    SameTest -> MatchQ,
    TestID   -> "TeX-Whitespace-Delimited-Brackets@@Tests/Formatting.wlt:60,1-73,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*TeX Serialization*)

(* Formatted assistant math as it is stored in a chat notebook serializes back to the TeX it was created from: *)
VerificationTest[
    CellToString @ Cell[
        TextData @ {
            "The value of ",
            Cell @ BoxData @ FormBox[
                TemplateBox[
                    <|
                        "boxes"  -> FormBox[ RowBox @ { "sin", StyleBox[ "x", "TI" ] }, TraditionalForm ],
                        "errors" -> { },
                        "input"  -> "\\sin{x}",
                        "state"  -> "Boxes"
                    |>,
                    "TeXAssistantTemplate"
                ],
                TraditionalForm
            ],
            " is shown."
        },
        "ChatOutput"
    ],
    "The value of $$\\sin{x}$$ is shown.",
    SameTest -> MatchQ,
    TestID   -> "TeX-Serialization-Stored-Boxes@@Tests/Formatting.wlt:80,1-103,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* Display and inline math (including math nested in other formatting) use their stored TeX, so serializing them does
   not need to export the boxes as TeX: *)
VerificationTest[
    Module[ { count = 0, strings },
        strings = Block[
            { Wolfram`Chatbook`Serialization`Private`serializeTraditionalForm = (count++; "EXPORTED") & },
            CellToString /@ {
                Cell[
                    FormatChatOutput[
                        "Then $$\\int_0^1 x^2 \\, dx = \\frac{1}{3}$$ and \\(a+b\\) follow, with $\\sin{x}$ too."
                    ][[ 1, 1 ]],
                    "ChatOutput"
                ],
                Cell[ FormatChatOutput[ "- item with $\\alpha$ math" ][[ 1, 1 ]], "ChatOutput" ]
            }
        ];
        { strings, count }
    ],
    {
        {
            "Then $$\\int_0^1 x^2 \\, dx = \\frac{1}{3}$$ and $$a+b$$ follow, with $$\\sin{x}$$ too.",
            "* item with $$\\alpha$$ math"
        },
        0
    },
    SameTest -> MatchQ,
    TestID   -> "TeX-Serialization-Skips-TeX-Export@@Tests/Formatting.wlt:110,1-135,2"
]

(* The same holds for math in tables and headings: *)
VerificationTest[
    Module[ { count = 0, strings },
        strings = Block[
            { Wolfram`Chatbook`Serialization`Private`serializeTraditionalForm = (count++; "EXPORTED") & },
            CellToString @ Cell[ FormatChatOutput[ # ][[ 1, 1 ]], "ChatOutput" ] & /@ {
                "| a | b |\n|---|---|\n| $z^2$ | $\\frac{1}{2}$ |",
                "### Heading with $\\pi r^2$\n\nmore"
            }
        ];
        { strings, count }
    ],
    {
        {
            _String? (StringContainsQ[ "| $$z^2$$ | $$\\frac{1}{2}$$ |" ]),
            "### Heading with $$\\pi r^2$$\n\nmore"
        },
        0
    },
    SameTest -> MatchQ,
    TestID   -> "TeX-Serialization-Table-And-Heading@@Tests/Formatting.wlt:138,1-158,2"
]

(* TeX boxes that do not have their TeX source still go through TeX export: *)
VerificationTest[
    Module[ { count = 0, string },
        string = Block[
            { Wolfram`Chatbook`Serialization`Private`serializeTraditionalForm = (count++; "EXPORTED") & },
            CellToString @ Cell[
                TextData @ {
                    "Old ",
                    Cell @ BoxData @ FormBox[
                        TemplateBox[
                            <| "boxes" -> FormBox[ "x", TraditionalForm ], "state" -> "Boxes" |>,
                            "TeXAssistantTemplate"
                        ],
                        TraditionalForm
                    ],
                    " box"
                },
                "ChatOutput"
            ]
        ];
        { string, count }
    ],
    { "Old EXPORTED box", 1 },
    SameTest -> MatchQ,
    TestID   -> "TeX-Serialization-Without-Input@@Tests/Formatting.wlt:161,1-185,2"
]

(* The math prompt is requested every time the math is serialized, not only the first time: *)
VerificationTest[
    Table[
        Block[ { Wolfram`Chatbook`Prompting`Private`$collectedPromptComponents = <| |> },
            CellToString @ Cell[ FormatChatOutput[ "Math $y^3$ here" ][[ 1, 1 ]], "ChatOutput" ];
            KeyExistsQ[ Wolfram`Chatbook`Prompting`Private`$collectedPromptComponents, "Math" ]
        ],
        2
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "TeX-Serialization-Math-Prompt@@Tests/Formatting.wlt:188,1-199,2"
]

(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Markdown Escapes*)

(* Outside of math the backslash only marks the escape, so it is dropped instead of being kept: *)
VerificationTest[
    FormatChatOutput[ "Cost: \\$5 and \\$6" ],
    RawBoxes @ Cell @ TextData @ { "Cost: $5 and $6" },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Escaped-Dollar@@Tests/Formatting.wlt:208,1-213,2"
]

(* Escapes have to be restored before inline code is formatted. Otherwise the escape sentinel is still
   embedded in the string when the symbol name is looked up, so the code renders as ordinary inline code
   instead of resolving to a documentation link: *)
VerificationTest[
    FormatChatOutput[ "Try `\\$Failed` next" ],
    RawBoxes @ Cell @ TextData @ {
        "Try ",
        Cell @ BoxData @ TemplateBox[ { "$Failed", "paclet:ref/$Failed", _String }, "TextRefLink" ],
        " next"
    },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Escaped-Dollar-In-Inline-Code@@Tests/Formatting.wlt:218,1-227,2"
]

(* Text right before a code block is still formatted as markdown when the response contains an escape: *)
VerificationTest[
    Cases[
        FormatChatOutput[ "## Heading\n\n- Item\n\n---\n\nCost: \\$5\n\n```wl\n1 + 1\n```" ],
        Cell[ _, style: "InlineSection"|"InlineItem"|"MarkdownDelimiter"|"ChatCodeBlock", ___ ] :> style,
        Infinity
    ],
    { "InlineSection", "InlineItem", "MarkdownDelimiter", "ChatCodeBlock" },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Escaped-Blocks-Before-Code-Block@@Tests/Formatting.wlt:230,1-239,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Markdown Emphasis*)

(* Underscores inside words (e.g. tool names) do not mark emphasis: *)
VerificationTest[
    FormatChatOutput[ "Use the wolfram_language_evaluator tool with snake__case__name or x___y___z." ],
    RawBoxes @ Cell @ TextData @ { "Use the wolfram_language_evaluator tool with snake__case__name or x___y___z." },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Intraword-Underscores@@Tests/Formatting.wlt:246,1-251,2"
]

VerificationTest[
    FormatChatOutput[ "Some _italic_, __bold__, and ___both___ text (_in parentheses_)." ],
    RawBoxes @ Cell @ TextData @ {
        "Some ",
        StyleBox[ "italic", FontSlant -> Italic ],
        ", ",
        StyleBox[ "bold", FontWeight -> Bold ],
        ", and ",
        StyleBox[ "both", FontWeight -> Bold, FontSlant -> Italic ],
        " text (",
        StyleBox[ "in parentheses", FontSlant -> Italic ],
        ")."
    },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Underscore-Emphasis@@Tests/Formatting.wlt:253,1-268,2"
]

(* Underscores inside words are not escaped when serialized, since they can't mark emphasis: *)
VerificationTest[
    CellToString /@ {
        Cell[ FormatChatOutput[ "Use the wolfram_language_evaluator tool." ][[ 1, 1 ]], "ChatOutput" ],
        Cell[ "Rename my__var to _private or __init__", "Text" ]
    },
    { "Use the wolfram_language_evaluator tool.", "Rename my__var to \\_private or \\_\\_init\\_\\_" },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Intraword-Underscores-Serialization@@Tests/Formatting.wlt:271,1-279,2"
]

(* Asterisks can still mark emphasis inside words: *)
VerificationTest[
    FormatChatOutput[ "un*frigging*believable" ],
    RawBoxes @ Cell @ TextData @ { "un", StyleBox[ "frigging", FontSlant -> Italic ], "believable" },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Intraword-Asterisks@@Tests/Formatting.wlt:282,1-287,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Documentation Links*)

(* Models sometimes wrap a documentation link in backticks. The link is what was meant, so it renders as a
   link rather than as code displaying the markdown verbatim: *)
VerificationTest[
    FormatChatOutput[ "See `[Table](paclet:ref/Table)` for details" ],
    RawBoxes @ Cell @ TextData @ {
        "See ",
        Cell @ BoxData @ TemplateBox[ { "Table", "paclet:ref/Table", _String }, "TextRefLink" ],
        " for details"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Ref-Link@@Tests/Formatting.wlt:295,1-304,2"
]

(* The same holds when the symbol name inside the link was escaped: *)
VerificationTest[
    FormatChatOutput[ "See `[\\$Failed](paclet:ref/\\$Failed)` for details" ],
    RawBoxes @ Cell @ TextData @ {
        "See ",
        Cell @ BoxData @ TemplateBox[ { "$Failed", "paclet:ref/$Failed", _String }, "TextRefLink" ],
        " for details"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Ref-Link-Escaped-Name@@Tests/Formatting.wlt:307,1-316,2"
]

(* Only a self-referential link is rewritten this way. A label that disagrees with the reference carries
   information that the link alone would lose, so it stays as code: *)
VerificationTest[
    FormatChatOutput[ "See `[Foo](paclet:ref/Bar)` for details" ],
    RawBoxes @ Cell @ TextData @ {
        "See ",
        Cell[
            BoxData @ TemplateBox[
                { Cell[ "[Foo](paclet:ref/Bar)", Background -> None ] },
                "ChatCodeInlineTemplate"
            ],
            "ChatCodeActive"
        ],
        " for details"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Ref-Link-Mismatched-Name@@Tests/Formatting.wlt:320,1-335,2"
]

(* Combination of link around the function head and escaped brackets around the arguments. *)
VerificationTest[
    Cases[
        FormatChatOutput[ "In Wolfram Language, use [Factorial2](paclet:ref/Factorial2)\\[42\\]." ],
        s_String /; StringContainsQ[ s, "[42]" ] :> s,
        Infinity
    ],
    { "[42]." },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Escaped-Brackets-After-Link@@Tests/Formatting.wlt:338,1-347,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ASCII art versus tool calls*)

VerificationTest[
    StringReplace[
        FirstCase[ FormatChatOutput[ "/\\\\_/\\\\\n( o.o )\n > ^ <" ], s_String :> s, $Failed, Infinity ],
        "\r\n" -> "\n"
    ],
    "/\\_/\\\n( o.o )\n > ^ <",
    SameTest -> MatchQ,
    TestID   -> "Markdown-ASCII-Art-Backslashes@@Tests/Formatting.wlt:353,1-361,2"
]

VerificationTest[
    ToCharacterCode /@ StringReplace[
        Cases[
            FormatChatOutput[ "```text\n /\\\\_/\\\\\\\\\n( o.o )\n > ^ <\n```" ],
            Cell[ code_, "ChatPreformatted", ___ ] :> code,
            Infinity
        ],
        "\r\n" -> "\n"
    ],
    ToCharacterCode /@ { " /\\_/\\\\\n( o.o )\n > ^ <" },
    SameTest -> MatchQ,
    TestID   -> "Markdown-TextFence-Unescapes-ASCII-Art@@Tests/Formatting.wlt:363,1-375,2"
]

VerificationTest[
    StringReplace[
        Cases[
            FormatChatOutput[ "```python\nprint('\\\\')\n```" ],
            Cell[ code_, "ExternalLanguage", ___ ] :> code,
            Infinity
        ],
        "\r\n" -> "\n"
    ],
    { "print('\\\\')" },
    SameTest -> MatchQ,
    TestID   -> "Markdown-CodeFence-Preserves-Code-Backslashes@@Tests/Formatting.wlt:377,1-389,2"
]

VerificationTest[
    Cases[
        FormatChatOutput[ "/\\\\_/\\\\\n( o.o )\n > ^ <" ],
        Cell[ _, "InlineToolCall", ___ ],
        Infinity
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Markdown-ASCII-Art-Not-ToolCall@@Tests/Formatting.wlt:391,1-400,2"
]

VerificationTest[
    Cases[
        FormatChatOutput[ "/external-tool.v1\n{}\nRESULT\nok\nENDRESULT(abc123)" ],
        Cell[ _, "InlineToolCall", ___ ],
        Infinity
    ],
    { _Cell },
    SameTest -> MatchQ,
    TestID   -> "Markdown-External-Slash-ToolCall@@Tests/Formatting.wlt:402,1-411,2"
]

VerificationTest[
    ToCharacterCode @ StringReplace[
        FirstCase[
            FormatChatOutput[ "<thinking>/\\\\_/\\\\\n( o.o )\n > ^ <</thinking>" ],
            TemplateBox[ { text_, _, ___ }, "ThoughtsOpener" ] :> CellToString @ Cell[ text, "Text" ],
            $Failed,
            Infinity
        ],
        "\r\n" -> "\n"
    ],
    (* Thoughts are formatted as markdown, so escaped backslashes are displayed the same way as in chat output: *)
    ToCharacterCode @ "/\\_/\\\n( o.o )\n > ^ <",
    SameTest -> MatchQ,
    TestID   -> "Thinking-Preserves-ASCII-Art@@Tests/Formatting.wlt:413,1-427,2"
]

VerificationTest[
    FirstCase[
        FormatChatOutput[ "<THINKING>fish &amp; chips /\\\\_/\\\\</THINKING>" ],
        TemplateBox[ { text_, _, ___ }, "ThoughtsOpener" ] :> CellToString @ Cell[ text, "Text" ],
        $Failed,
        Infinity
    ],
    "fish & chips /\\_/\\",
    SameTest -> MatchQ,
    TestID   -> "Thinking-Escapes-Ignore-Case-And-Import-HTML@@Tests/Formatting.wlt:429,1-439,2"
]

VerificationTest[
    Cases[
        FormatChatOutput[
            "Sure:\n\n```text\n /\\\\_/\\\\\\\\\n( o.o )\n > ^ <\n```\n\nAnother one:\n\n```text\n /\\\\_/\\\\  \n( -.- ) \n > ~ <\n```"
        ],
        TextData[ data_ ] :> Replace[
            data,
            { ___, "Sure: \n", _Cell, "\nAnother one: \n", _Cell, ___ } :> True
        ],
        Infinity
    ],
    { True },
    SameTest -> MatchQ,
    TestID   -> "Markdown-TextFence-Block-Separators@@Tests/Formatting.wlt:441,1-455,2"
]

VerificationTest[
    Cases[
        FormatChatOutput[ "Here is some code:\n\n```text\n1+1\n```" ],
        TextData[ { "Here is some code: \n", Cell[ _, "ChatCodeBlock", ___ ] } ] :> True,
        Infinity
    ],
    { True },
    SameTest -> MatchQ,
    TestID   -> "Markdown-TextFence-Text-Before-Code@@Tests/Formatting.wlt:457,1-466,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Calls with Escaped Markdown*)

(* An escaped character anywhere in the response must not split up tool calls whose results contain code blocks
   (e.g. documentation search results), and the raw tool call text is kept as is: *)
VerificationTest[
    With[
        {
            toolCall = StringJoin[
                "/doc_search\nmessages\n/exec\nRESULT\nSee ``\\$MessageGroups``:\n",
                "```wl\nIn[1]:= Quiet[1/0]\n```\nENDRESULT(abc123)"
            ]
        },
        Cases[
            FormatChatOutput[ toolCall <> "\nThe price is \\$5." ],
            Cell[ _, "InlineToolCall", ___, TaggingRules -> KeyValuePattern[ "ToolCall" -> s_String ], ___ ] :>
                s === toolCall,
            Infinity
        ]
    ],
    { True },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Escaped-ToolCall-Code-Block-Result@@Tests/Formatting.wlt:474,1-492,2"
]

(* Escapes are only removed from the text around tool calls, not from the tool call itself: *)
VerificationTest[
    With[ { toolCall = "/wl\nStringReplace[s, \"\\\\$\" -> \"\"]\n/exec\nRESULT\nOut[1]= x\nENDRESULT(abc123)" },
        Cases[
            FormatChatOutput[ toolCall <> "\nCost \\$5." ],
            Cell[ _, "InlineToolCall", ___, TaggingRules -> KeyValuePattern[ "ToolCall" -> s_String ], ___ ] :>
                s === toolCall,
            Infinity
        ]
    ],
    { True },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Escaped-ToolCall-Raw-Text@@Tests/Formatting.wlt:495,1-507,2"
]

(* Tool calls keep the same line breaks around them as they do in text without escapes: *)
VerificationTest[
    With[
        {
            toolCalls = StringJoin[
                "/wl\n1+1\n/exec\nRESULT\n```wl\nIn[1]:= 1+1\n```\nOut[1]= 2\nENDRESULT(abc123)\n\n\n",
                "/wl\n2+2\n/exec\nRESULT\nOut[1]= 4\nENDRESULT(def456)\n"
            ]
        },
        FormatChatOutput[ "Cost " <> # <> "5:\n\n" <> toolCalls <> "Done." ][[ 1, 1, 1 ]] & /@ { "\\$", "$" }
    ],
    {
        { "Cost $5: \n", Cell[ _, "InlineToolCall", ___ ], "\n", Cell[ _, "InlineToolCall", ___ ], "\nDone." },
        { "Cost $5: \n", Cell[ _, "InlineToolCall", ___ ], "\n", Cell[ _, "InlineToolCall", ___ ], "\nDone." }
    },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Escaped-ToolCall-Line-Breaks@@Tests/Formatting.wlt:510,1-526,2"
]

(* A bad tool call is discarded by /retry, and escapes are still handled in the discarded text: *)
VerificationTest[
    With[
        {
            boxes = FormatChatOutput @ StringJoin[
                "/wl\n1+1\n/exec\nRESULT\n```wl\nIn[1]:= 1+1\n```\nOut[1]= error\nENDRESULT(abc123)\n",
                "Oops, that cost \\$5.\n/retry\n",
                "/wl\n2+2\n/exec\nRESULT\nOut[1]= 4\nENDRESULT(def456)\nCost \\$5."
            ]
        },
        {
            boxes[[ 1, 1, 1 ]],
            (* The discarded material is compressed until it's viewed: *)
            FirstCase[
                boxes,
                HoldPattern @ BaseDecode[ b64_String ] :> BinaryDeserialize @ BaseDecode @ b64,
                $Failed,
                Infinity
            ]
        }
    ],
    {
        { Cell[ _, "DiscardedMaterial", ___ ], "\n", Cell[ _, "InlineToolCall", ___ ], "\nCost $5." },
        Column[ { RawBoxes @ Cell[ TextData @ { Cell[ _, "InlineToolCall", ___ ], "\nOops, that cost $5." }, ___ ] }, ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Escaped-ToolCall-Retry@@Tests/Formatting.wlt:529,1-555,2"
]

(* Consecutive discarded tool calls are grouped into a single opener, with one row per tool call: *)
VerificationTest[
    With[
        {
            boxes = FormatChatOutput @ StringJoin[
                "/wl\n0\n/exec\nRESULT\nOut[1]= 0\nENDRESULT(aaa111)\nBad one.\n/retry\n",
                "/wl\n1\n/exec\nRESULT\nOut[1]= 1\nENDRESULT(bbb222)\nBad two.\n/retry\n",
                "/wl\n2\n/exec\nRESULT\nOut[1]= 2\nENDRESULT(ccc333)\nDone."
            ]
        },
        {
            Count[ boxes, Cell[ _, "DiscardedMaterial", ___ ], Infinity ],
            FirstCase[
                boxes,
                HoldPattern @ BaseDecode[ b64_String ] :> BinaryDeserialize @ BaseDecode @ b64,
                $Failed,
                Infinity
            ]
        }
    ],
    {
        1,
        Column[
            {
                RawBoxes @ Cell[ TextData @ { Cell[ _, "InlineToolCall", ___ ], "\nBad one." }, ___ ],
                RawBoxes @ Cell[ TextData @ { Cell[ _, "InlineToolCall", ___ ], "\nBad two." }, ___ ]
            },
            ___
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Discarded-ToolCalls-Grouped@@Tests/Formatting.wlt:558,1-589,2"
]

(* Tool call openers use the "ToolIconCall<name>" resource for each button state, falling back to the generic icon: *)
VerificationTest[
    Union @ Cases[
        FormatChatOutput @ StringJoin[
            "TOOLCALL: web_fetcher\n{\n\t\"url\":\"https://example.com\"\n}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\nok\nENDRESULT(abcd1234)\n\n",
            "TOOLCALL: made_up_tool\n{\n\t\"x\":\"1\"\n}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\nok\nENDRESULT(efgh5678)\n\nDone."
        ],
        FEPrivate`FrontEndResource[ "ChatbookExpressions", name_String ][ _ ] :> name,
        Infinity
    ],
    { "ToolIconCallGenericTool", "ToolIconCallWebFetcher" },
    SameTest -> MatchQ,
    TestID   -> "ToolCall-Opener-Icons@@Tests/Formatting.wlt:592,1-604,2"
]

(* Front-end-evaluated opener buttons return Null, otherwise the front end reports 'Could not process unknown packet
   "True"' each time the opener is toggled: *)
VerificationTest[
    Cases[
        FormatChatOutput[
            "TOOLCALL: web_fetcher\n{\n\t\"url\":\"https://example.com\"\n}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\nok\nENDRESULT(abcd1234)\n\nDone."
        ],
        ButtonBox[ ___, ButtonFunction :> f_, ___, Evaluator -> None, ___ ] :> HoldComplete @ f,
        Infinity
    ],
    { HoldComplete[ _; Null ].. },
    SameTest -> MatchQ,
    TestID   -> "ToolCall-Opener-Null-ButtonFunction@@Tests/Formatting.wlt:608,1-619,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Placeholders*)

(* Placeholder["description"] in WL code gets its StandardForm typesetting so it displays as a proper placeholder
   instead of plain code: *)
VerificationTest[
    FirstCase[
        StringToBoxes[ "data = Placeholder[\"your data\"];\ndoTheThing[data]", "WL" ],
        TagBox[ b_FrameBox, "Placeholder" ] :> b,
        $Failed,
        Infinity
    ],
    FrameBox[ "\"your data\"" ],
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Boxes@@Tests/Formatting.wlt:627,1-637,2"
]

(* Placeholder allows arbitrary label expressions, so these are formatted too by wrapping the already-parsed
   label boxes (avoiding a ToExpression round trip that could create symbols with unwanted contexts): *)
VerificationTest[
    FirstCase[
        StringToBoxes[ "DateListPlot[Placeholder[your data]]", "WL" ],
        TagBox[ b_FrameBox, "Placeholder" ] :> b,
        $Failed,
        Infinity
    ],
    FrameBox @ RowBox @ { "your", " ", "data" },
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Expression-Label@@Tests/Formatting.wlt:641,1-651,2"
]

(* String labels can contain escaped quotes: *)
VerificationTest[
    FirstCase[
        StringToBoxes[
            "data = Placeholder[\"{{\\\"Feb 12 2026\\\", 10}, {\\\"Mar 05 2026\\\", 14}, ...}\"];\nDateListPlot[data]",
            "WL"
        ],
        TagBox[ b_FrameBox, "Placeholder" ] :> b,
        $Failed,
        Infinity
    ],
    FrameBox[ "\"{{\\\"Feb 12 2026\\\", 10}, {\\\"Mar 05 2026\\\", 14}, ...}\"" ],
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Escaped-Quotes@@Tests/Formatting.wlt:654,1-667,2"
]

(* Placeholder takes at most one argument, so empty or multiple arguments are not valid labels and are left as-is: *)
VerificationTest[
    StringToBoxes[ "f[Placeholder[a, b], Placeholder[]]", "WL" ],
    boxes_ /; FreeQ[ boxes, TagBox[ _, "Placeholder", ___ ] ],
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Invalid-Arguments-Unchanged@@Tests/Formatting.wlt:670,1-675,2"
]

(* The full formatting path renders the placeholder in finished chat output: *)
VerificationTest[
    FirstCase[
        FormatChatOutput[ "```wl\ndata = Placeholder[\"your data\"];\ndoTheThing[data]\n```\n" ],
        TagBox[ b_FrameBox, "Placeholder" ] :> b,
        $Failed,
        Infinity
    ],
    FrameBox[ "\"your data\"" ],
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Formatted-Output@@Tests/Formatting.wlt:678,1-688,2"
]

(* While streaming, code is rendered from plain strings, so the placeholder appears as embedded linear syntax: *)
VerificationTest[
    Position[
        FormatChatOutput[
            "```wl\ndata = Placeholder[\"your data\"];\ndoTheThing[data]\n```\n",
            <| "Status" -> "Streaming" |>
        ],
        s_String /; StringContainsQ[ s, "TagBox" ] && StringContainsQ[ s, "Placeholder" ]
    ],
    { __ },
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Streaming@@Tests/Formatting.wlt:691,1-702,2"
]

(* A placeholder that has not finished streaming in yet is still rendered: *)
VerificationTest[
    Position[
        FormatChatOutput[ "```wl\ndata = Placeholder[\"your da", <| "Status" -> "Streaming" |> ],
        s_String /; StringContainsQ[ s, "TagBox" ] && StringContainsQ[ s, "Placeholder" ]
    ],
    { __ },
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Streaming-Partial@@Tests/Formatting.wlt:705,1-713,2"
]

(* Serializing the formatted boxes back to text for the LLM recovers the original code instead of losing the
   Placeholder head: *)
VerificationTest[
    CellToString @ Cell[
        BoxData @ RowBox @ { "data", "=", TagBox[ FrameBox[ "\"your data\"" ], "Placeholder" ], ";" },
        "Input"
    ],
    "```wl\ndata = Placeholder[\"your data\"];\n```",
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Serialization-RoundTrip@@Tests/Formatting.wlt:717,1-725,2"
]

(* Expression labels round-trip through serialization as well: *)
VerificationTest[
    CellToString @ Cell[
        BoxData @ RowBox @ { "DateListPlot", "[", TagBox[ FrameBox @ RowBox @ { "your", " ", "data" }, "Placeholder" ], "]" },
        "Input"
    ],
    "```wl\nDateListPlot[Placeholder[your data]]\n```",
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Serialization-RoundTrip-Expression-Label@@Tests/Formatting.wlt:728,1-736,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Color Swatches*)

(* Color constructors with literal numeric arguments get their StandardForm typesetting, so they display as interactive
   color swatches instead of plain code: *)
VerificationTest[
    StringToBoxes[ "RGBColor[1, 0, 0]", "WL" ],
    TemplateBox[ KeyValuePattern[ "color" -> RGBColor[ 1, 0, 0 ] ], "RGBColorSwatchTemplate", ___ ],
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-RGBColor@@Tests/Formatting.wlt:744,1-749,2"
]

(* Every supported color model is converted: *)
VerificationTest[
    Cases[
        StringToBoxes[
            "{CMYKColor[0, 1, 1, 0], GrayLevel[0.5], Hue[0.3], LABColor[50, 20, 30], LCHColor[50, 20, 30], LUVColor[50, 20, 30], XYZColor[0.5, 0.5, 0.5]}",
            "WL"
        ],
        TemplateBox[ KeyValuePattern[ "color" -> color_ ], name_String, ___ ] :> { name, color },
        Infinity
    ],
    {
        { "CMYKColorSwatchTemplate"     , CMYKColor[ 0, 1, 1, 0 ]   },
        { "GrayLevelColorSwatchTemplate", GrayLevel[ 0.5 ]          },
        { "HueColorSwatchTemplate"      , Hue[ 0.3 ]                },
        { "LABColorSwatchTemplate"      , LABColor[ 50, 20, 30 ]    },
        { "LCHColorSwatchTemplate"      , LCHColor[ 50, 20, 30 ]    },
        { "LUVColorSwatchTemplate"      , LUVColor[ 50, 20, 30 ]    },
        { "XYZColorSwatchTemplate"      , XYZColor[ 0.5, 0.5, 0.5 ] }
    },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-All-Color-Models@@Tests/Formatting.wlt:752,1-772,2"
]

(* LightDarkSwitched and ThemeColor typeset to their own template boxes rather than a "...ColorSwatchTemplate": *)
VerificationTest[
    Cases[
        StringToBoxes[ "{LightDarkSwitched[RGBColor[1, 0, 0], RGBColor[0, 1, 0]], LightDarkSwitched[RGBColor[1, 0, 0]]}", "WL" ],
        TemplateBox[ as_Association, name_String, ___ ] :> { name, as },
        Infinity
    ],
    {
        { "LightDarkSwitched" , KeyValuePattern @ { "light" -> RGBColor[ 1, 0, 0 ], "dark" -> RGBColor[ 0, 1, 0 ] } },
        { "LightDarkSwitched1", KeyValuePattern[ "light" -> RGBColor[ 1, 0, 0 ] ] }
    },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-LightDarkSwitched@@Tests/Formatting.wlt:775,1-787,2"
]

VerificationTest[
    Cases[
        StringToBoxes[ "{ThemeColor[\"Background\"], ThemeColor[{0.3 -> \"Foreground\", 0.7 -> \"Background\"}]}", "WL" ],
        TemplateBox[ as_Association, name_String, ___ ] :> { name, as },
        Infinity
    ],
    {
        { "ThemeColor"       , KeyValuePattern[ "name" -> "Background" ] },
        { "ThemeColorBlended", KeyValuePattern @ { "frac1" -> 0.3, "name1" -> "Foreground", "frac2" -> 0.7, "name2" -> "Background" } }
    },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-ThemeColor@@Tests/Formatting.wlt:789,1-801,2"
]

(* Swatches are substituted in place inside larger expressions: *)
VerificationTest[
    StringToBoxes[ "Graphics[{RGBColor[1, 0, 0], Disk[]}]", "WL" ],
    RowBox @ {
        "Graphics",
        "[",
        RowBox @ {
            "{",
            RowBox @ {
                TemplateBox[ KeyValuePattern[ "color" -> RGBColor[ 1, 0, 0 ] ], "RGBColorSwatchTemplate", ___ ],
                ",",
                RowBox @ { "Disk", "[", "]" }
            },
            "}"
        },
        "]"
    },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Nested-In-Expression@@Tests/Formatting.wlt:804,1-822,2"
]

(* Arguments that are not literal numbers (symbols, patterns, unevaluated expressions) do not typeset as swatches in the
   front end either, so the code is left as-is: *)
VerificationTest[
    StringToBoxes[ "{RGBColor[Red, Green, Blue], Hue[N[1/3]], RGBColor[1, 0], Cases[expr, RGBColor[r_, g_, b_]]}", "WL" ],
    boxes_ /; FreeQ[ boxes, _TemplateBox ],
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Non-Numeric-Arguments-Unchanged@@Tests/Formatting.wlt:826,1-831,2"
]

(* When a color is not converted, special boxes inside its arguments are still formatted: *)
VerificationTest[
    StringToBoxes[ "RGBColor[Placeholder[\"red\"], 0, 0]", "WL" ],
    RowBox @ { "RGBColor", "[", RowBox @ { TagBox[ FrameBox[ "\"red\"" ], "Placeholder" ], ",", "0", ",", "0" }, "]" },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Inner-Special-Boxes-Still-Formatted@@Tests/Formatting.wlt:834,1-839,2"
]

(* The full formatting path renders swatches in finished chat output, both in code and in sandbox output rows: *)
VerificationTest[
    Cases[
        FormatChatOutput[ "```wl\nIn[1]:= RGBColor[1, 0, 0]\nOut[1]= RGBColor[1, 0, 0]\n```\n" ],
        Cell[ BoxData[ swatch_TemplateBox ], style: "ChatCode"|"Output", ___ ] :> { style, swatch },
        Infinity
    ],
    {
        { "ChatCode", TemplateBox[ KeyValuePattern[ "color" -> RGBColor[ 1, 0, 0 ] ], "RGBColorSwatchTemplate", ___ ] },
        { "Output"  , TemplateBox[ KeyValuePattern[ "color" -> RGBColor[ 1, 0, 0 ] ], "RGBColorSwatchTemplate", ___ ] }
    },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Formatted-Output@@Tests/Formatting.wlt:842,1-854,2"
]

(* Serializing the formatted boxes back to text for the LLM recovers the original code: *)
VerificationTest[
    CellToString @ Cell[
        BoxData @ StringToBoxes[ "{RGBColor[1, 0, 0], Hue[0.3], GrayLevel[0.5]}", "WL" ],
        "Output"
    ],
    "```wl\n{RGBColor[1, 0, 0], Hue[0.3], GrayLevel[0.5]}\n```",
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Serialization-RoundTrip@@Tests/Formatting.wlt:857,1-865,2"
]

(* LightDarkSwitched and ThemeColor, including their one-argument and blended variants, round-trip as well: *)
VerificationTest[
    CellToString @ Cell[
        BoxData @ StringToBoxes[
            "{LightDarkSwitched[RGBColor[1, 0, 0], RGBColor[0, 1, 0]], LightDarkSwitched[RGBColor[1, 0, 0]], ThemeColor[\"Background\"], ThemeColor[{0.3 -> \"Foreground\", 0.7 -> \"Background\"}]}",
            "WL"
        ],
        "Output"
    ],
    "```wl\n{LightDarkSwitched[RGBColor[1, 0, 0], RGBColor[0, 1, 0]], LightDarkSwitched[RGBColor[1, 0, 0]], ThemeColor[\"Background\"], ThemeColor[{0.3 -> \"Foreground\", 0.7 -> \"Background\"}]}\n```",
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Serialization-RoundTrip-LightDarkSwitched-ThemeColor@@Tests/Formatting.wlt:868,1-879,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* Those template boxes have precomputed serialization rules, so they do not need the front end stylesheet lookup that
   undeclared template boxes fall back to: *)
VerificationTest[
    Wolfram`Chatbook`Serialization`Private`$templateBoxRules[ #1 ][ #2 ] & @@@ {
        { "LightDarkSwitched" , <| "light" -> RGBColor[ 1, 0, 0 ], "dark" -> RGBColor[ 0, 1, 0 ] |> },
        { "LightDarkSwitched1", <| "light" -> RGBColor[ 1, 0, 0 ] |> },
        { "ThemeColor"        , <| "name" -> "Background" |> },
        { "ThemeColorBlended" , <| "frac1" -> 0.3, "name1" -> "Foreground", "frac2" -> 0.7, "name2" -> "Background" |> }
    },
    {
        "LightDarkSwitched[RGBColor[1, 0, 0], RGBColor[0, 1, 0]]",
        "LightDarkSwitched[RGBColor[1, 0, 0]]",
        "ThemeColor[\"Background\"]",
        "ThemeColor[{0.3 -> \"Foreground\", 0.7 -> \"Background\"}]"
    },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Serialization-Precomputed-Rules@@Tests/Formatting.wlt:886,1-901,2"
]

(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Dynamic Attachments*)

(* Each insertion of dynamic content needs fresh boxes. Reusing cached Manipulate boxes aliases their generated
   DynamicModule identities, so a second reference to the same expression does not work independently: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Formatting`Private`$boxCache = <| |> },
        With[ { uri = MakeExpressionURI @ Manipulate[ x, { x, 0, 1 } ] },
            FormatChatOutput @ StringRiffle[ { uri, uri }, "\n\n" ]
        ];
        Wolfram`Chatbook`Formatting`Private`$boxCache
    ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "Manipulate-Boxes-Are-Not-Cached@@Tests/Formatting.wlt:911,1-921,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Dynamic Progress Indicators*)
VerificationTest[
    Wolfram`Chatbook`Formatting`Private`activeToolProgressIndicator[ ],
    RawBoxes @ TagBox[ _, "ChatbookActiveToolProgress" ],
    SameTest -> MatchQ,
    TestID   -> "ActiveToolProgressIndicator-Tagged@@Tests/Formatting.wlt:929,1-934,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`$ChatHandlerData =
                <| "ChatNotebookSettings" -> <| "ToolMethod" -> "Textual" |> |>
        },
        Wolfram`Chatbook`SendChat`Private`dynamicProgressIndicatorQ[ "Streaming text", "Formatted text" ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "DynamicProgressIndicator-OrdinaryText@@Tests/Formatting.wlt:936,1-947,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`$ChatHandlerData =
                <| "ChatNotebookSettings" -> <| "ToolMethod" -> "Textual" |> |>
        },
        Wolfram`Chatbook`SendChat`Private`dynamicProgressIndicatorQ[
            "Partial tool call",
            RawBoxes @ TagBox[ "Progress", "ChatbookActiveToolProgress" ]
        ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "DynamicProgressIndicator-ActiveTool@@Tests/Formatting.wlt:949,1-963,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`$ChatHandlerData =
                <| "ChatNotebookSettings" -> <| "ToolMethod" -> "Textual" |> |>
        },
        Wolfram`Chatbook`SendChat`Private`dynamicProgressIndicatorQ[ "", "" ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "DynamicProgressIndicator-EmptyContent@@Tests/Formatting.wlt:965,1-976,2"
]

VerificationTest[
    Internal`InheritedBlock[
        {
            Wolfram`Chatbook`SendChat`Private`simpleToolFreeQ,
            Wolfram`Chatbook`SendChat`Private`toolFreeQ0
        },
        ClearAll[
            Wolfram`Chatbook`SendChat`Private`simpleToolFreeQ,
            Wolfram`Chatbook`SendChat`Private`toolFreeQ0
        ];
        Wolfram`Chatbook`SendChat`Private`simpleToolFreeQ[ _String ] := True;
        Wolfram`Chatbook`SendChat`Private`toolFreeQ0[ _String ] := False;
        Block[
            {
                Wolfram`Chatbook`$ChatHandlerData =
                    <| "ChatNotebookSettings" -> <| "ToolMethod" -> "Simple" |> |>
            },
            Wolfram`Chatbook`SendChat`Private`dynamicProgressIndicatorQ[ "text", "Formatted text" ]
        ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "DynamicProgressIndicator-MethodAware@@Tests/Formatting.wlt:978,1-1001,2"
]

(* :!CodeAnalysis::EndBlock:: *)

VerificationTest[
    Cases[
        FormatChatOutput[
            "TOOLCALL: WFRSearch\n{\n\t\"query\":\"ASCII art image to text animal function repository\"\n}\nENDARGUMENTS\nENDTOOLCALL\nRESULT\n\nENDRESULT(eqpuy6jhv)\n\nHere are a few:\n\n```text\n /\\_/\\\\\n( o.o )\n > ^ <\n```"
        ],
        Cell[ _, "InlineToolCall", ___ ],
        Infinity
    ],
    { _Cell },
    SameTest -> MatchQ,
    TestID   -> "Markdown-ToolCall-Before-Escaped-CodeBlock@@Tests/Formatting.wlt:1005,1-1016,2"
]
