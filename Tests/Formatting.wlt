(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
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
    TestID   -> "TeX-Escaped-Dollar"
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
    TestID   -> "TeX-Escaped-Underscore-And-Hash"
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
    TestID   -> "TeX-Whitespace-Delimited-Brackets"
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
    TestID   -> "TeX-Serialization-Stored-Boxes"
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
    TestID   -> "TeX-Serialization-Skips-TeX-Export"
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
    TestID   -> "TeX-Serialization-Table-And-Heading"
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
    TestID   -> "TeX-Serialization-Without-Input"
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
    TestID   -> "TeX-Serialization-Math-Prompt"
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
    TestID   -> "Markdown-Escaped-Dollar"
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
    TestID   -> "Markdown-Escaped-Dollar-In-Inline-Code"
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
    TestID   -> "Markdown-Escaped-Blocks-Before-Code-Block"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Markdown Emphasis*)

(* Underscores inside words (e.g. tool names) do not mark emphasis: *)
VerificationTest[
    FormatChatOutput[ "Use the wolfram_language_evaluator tool with snake__case__name or x___y___z." ],
    RawBoxes @ Cell @ TextData @ { "Use the wolfram_language_evaluator tool with snake__case__name or x___y___z." },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Intraword-Underscores"
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
    TestID   -> "Markdown-Underscore-Emphasis"
]

(* Underscores inside words are not escaped when serialized, since they can't mark emphasis: *)
VerificationTest[
    CellToString /@ {
        Cell[ FormatChatOutput[ "Use the wolfram_language_evaluator tool." ][[ 1, 1 ]], "ChatOutput" ],
        Cell[ "Rename my__var to _private or __init__", "Text" ]
    },
    { "Use the wolfram_language_evaluator tool.", "Rename my__var to \\_private or \\_\\_init\\_\\_" },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Intraword-Underscores-Serialization"
]

(* Asterisks can still mark emphasis inside words: *)
VerificationTest[
    FormatChatOutput[ "un*frigging*believable" ],
    RawBoxes @ Cell @ TextData @ { "un", StyleBox[ "frigging", FontSlant -> Italic ], "believable" },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Intraword-Asterisks"
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
    TestID   -> "Inline-Code-Ref-Link"
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
    TestID   -> "Inline-Code-Ref-Link-Escaped-Name"
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
    TestID   -> "Inline-Code-Ref-Link-Mismatched-Name"
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
    TestID   -> "Markdown-Escaped-Brackets-After-Link"
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
    TestID   -> "Markdown-ASCII-Art-Backslashes"
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
    TestID   -> "Markdown-TextFence-Unescapes-ASCII-Art"
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
    TestID   -> "Markdown-CodeFence-Preserves-Code-Backslashes"
]

VerificationTest[
    Cases[
        FormatChatOutput[ "/\\\\_/\\\\\n( o.o )\n > ^ <" ],
        Cell[ _, "InlineToolCall", ___ ],
        Infinity
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Markdown-ASCII-Art-Not-ToolCall"
]

VerificationTest[
    Cases[
        FormatChatOutput[ "/external-tool.v1\n{}\nRESULT\nok\nENDRESULT(abc123)" ],
        Cell[ _, "InlineToolCall", ___ ],
        Infinity
    ],
    { _Cell },
    SameTest -> MatchQ,
    TestID   -> "Markdown-External-Slash-ToolCall"
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
    TestID   -> "Thinking-Preserves-ASCII-Art"
]

VerificationTest[
    FirstCase[
        FormatChatOutput[ "<THINKING>fish &amp; chips /\\\\_/\\\\</THINKING>" ],
        TemplateBox[ { text_, _, ___ }, "ShortThoughts" ] :> CellToString @ Cell[ text, "Text" ],
        $Failed,
        Infinity
    ],
    "fish & chips /\\_/\\",
    SameTest -> MatchQ,
    TestID   -> "Thinking-Escapes-Ignore-Case-And-Import-HTML"
]

(* Thoughts of a single short line are shown as that line (ShortThoughts), without bold that covers the whole line. An
   unterminated bold title (a thought cut off by a stop) keeps the opener, and full-width characters count as 2.5: *)
VerificationTest[
    Wolfram`Chatbook`Common`shortThoughtsText /@ {
        "**Planning TOML import/export wrappers**",
        "  __Checking the tests__\n",
        "** Spaced title **",
        "Some **bold** text",
        "**First** and **second**",
        "**Not closed",
        "__init",
        "__init__ is the constructor",
        "**Title**\n\nBody",
        "line one\nline two",
        "",
        " \n ",
        StringRepeat[ "x", 75 ],
        StringRepeat[ "x", 76 ],
        "**" <> StringRepeat[ "x", 75 ] <> "**",
        "**" <> StringRepeat[ "x", 76 ] <> "**",
        StringRepeat[ "\:4e2d", 30 ],
        StringRepeat[ "\:4e2d", 31 ],
        "Planning " <> StringRepeat[ "\:30c6", 26 ],
        "Planning " <> StringRepeat[ "\:30c6", 27 ]
    },
    {
        "Planning TOML import/export wrappers",
        "Checking the tests",
        "Spaced title",
        "Some **bold** text",
        "**First** and **second**",
        None,
        None,
        "__init__ is the constructor",
        None,
        None,
        None,
        None,
        StringRepeat[ "x", 75 ],
        None,
        StringRepeat[ "x", 75 ],
        None,
        StringRepeat[ "\:4e2d", 30 ],
        None,
        "Planning " <> StringRepeat[ "\:30c6", 26 ],
        None
    },
    SameTest -> MatchQ,
    TestID   -> "ShortThoughtsText"
]

VerificationTest[
    Cases[
        FormatChatOutput[ "<think>\n**Planning the answer**\n</think>\n<think>\nA longer thought.\n\nIt has two paragraphs.\n</think>\nDone." ],
        TemplateBox[ { text_, _, meta_ }, name: "ShortThoughts" | "ThoughtsOpener" ] :>
            { name, CellToString @ Cell[ text, "Text" ], FreeQ[ text, FontWeight -> Bold ], meta },
        Infinity
    ],
    {
        { "ShortThoughts", "Planning the answer", True, <| "Type" -> "Literal" |> },
        { "ThoughtsOpener", s_String /; StringStartsQ[ s, "A longer thought." ] && StringEndsQ[ s, "It has two paragraphs." ], True, <| "Type" -> "Literal" |> }
    },
    SameTest -> MatchQ,
    TestID   -> "Thinking-Short-Line"
]

(* The thoughts templates are in the generated files (Developer/Resources/Styles.wl, built with
   BuildChatbookStylesheet[] and BuildStylesheets["CoreExtensions"]), so that cells with them render in any notebook and
   their display functions can be inlined: *)
VerificationTest[
    Module[ { names, root, defined },
        names   = { "ThoughtsOpener", "EmptyThoughts", "ShortThoughts" };
        root    = DirectoryName[ $TestFileName, 2 ];
        defined = Function[ file,
            Cases[
                ToExpression[ ReadString @ FileNameJoin @ Prepend[ file, root ], InputForm, HoldComplete ],
                Cell[ StyleData[ name: Alternatives @@ names ], ___, TemplateBoxOptions -> { ___, DisplayFunction -> _Function, ___ }, ___ ] :> name,
                Infinity
            ]
        ];
        {
            defined @ { "FrontEnd", "StyleSheets", "Chatbook.nb" },
            defined @ { "FrontEnd", "Assets", "Extensions", "CoreExtensions.nb" },
            Select[ names, MatchQ[ Wolfram`Chatbook`InlineTemplateBoxes @ TemplateBox[ { "", "", <| |> }, # ], TemplateBox[ _, #, DisplayFunction -> _Function ] ] & ]
        }
    ],
    ConstantArray[ { "ThoughtsOpener", "EmptyThoughts", "ShortThoughts" }, 3 ],
    SameTest -> MatchQ,
    TestID   -> "Thoughts-Templates-Built"
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
    TestID   -> "Markdown-TextFence-Block-Separators"
]

VerificationTest[
    Cases[
        FormatChatOutput[ "Here is some code:\n\n```text\n1+1\n```" ],
        TextData[ { "Here is some code: \n", Cell[ _, "ChatCodeBlock", ___ ] } ] :> True,
        Infinity
    ],
    { True },
    SameTest -> MatchQ,
    TestID   -> "Markdown-TextFence-Text-Before-Code"
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
    TestID   -> "Markdown-Escaped-ToolCall-Code-Block-Result"
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
    TestID   -> "Markdown-Escaped-ToolCall-Raw-Text"
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
    TestID   -> "Markdown-Escaped-ToolCall-Line-Breaks"
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
    TestID   -> "Markdown-Escaped-ToolCall-Retry"
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
    TestID   -> "Discarded-ToolCalls-Grouped"
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
    TestID   -> "ToolCall-Opener-Icons"
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
    TestID   -> "ToolCall-Opener-Null-ButtonFunction"
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
    TestID   -> "Placeholder-Boxes"
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
    TestID   -> "Placeholder-Expression-Label"
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
    TestID   -> "Placeholder-Escaped-Quotes"
]

(* Placeholder takes at most one argument, so empty or multiple arguments are not valid labels and are left as-is: *)
VerificationTest[
    StringToBoxes[ "f[Placeholder[a, b], Placeholder[]]", "WL" ],
    boxes_ /; FreeQ[ boxes, TagBox[ _, "Placeholder", ___ ] ],
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Invalid-Arguments-Unchanged"
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
    TestID   -> "Placeholder-Formatted-Output"
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
    TestID   -> "Placeholder-Streaming"
]

(* A placeholder that has not finished streaming in yet is still rendered: *)
VerificationTest[
    Position[
        FormatChatOutput[ "```wl\ndata = Placeholder[\"your da", <| "Status" -> "Streaming" |> ],
        s_String /; StringContainsQ[ s, "TagBox" ] && StringContainsQ[ s, "Placeholder" ]
    ],
    { __ },
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Streaming-Partial"
]

(* While streaming, Wolfram Language code is a string in a "ChatCodeActive" cell, which shows the quotes of its strings
   like the finished "ChatCode" cell (the chat output templates hide string characters): *)
VerificationTest[
    Cases[
        FormatChatOutput[ "```wl\nx = \"a\"\n```\n", <| "Status" -> "Streaming" |> ],
        Cell[ BoxData[ _String ], "ChatCodeActive", opts___ ] :> { opts },
        Infinity
    ],
    { { ShowStringCharacters -> True } },
    SameTest -> MatchQ,
    TestID   -> "Streaming-WL-Code-ShowsStringCharacters"
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
    TestID   -> "Placeholder-Serialization-RoundTrip"
]

(* Expression labels round-trip through serialization as well: *)
VerificationTest[
    CellToString @ Cell[
        BoxData @ RowBox @ { "DateListPlot", "[", TagBox[ FrameBox @ RowBox @ { "your", " ", "data" }, "Placeholder" ], "]" },
        "Input"
    ],
    "```wl\nDateListPlot[Placeholder[your data]]\n```",
    SameTest -> MatchQ,
    TestID   -> "Placeholder-Serialization-RoundTrip-Expression-Label"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Code Folding*)
VerificationTest[
    (* The code and the label of each fold in formatted boxes: *)
    foldedCode[ boxes_ ] := Cases[
        boxes,
        InterpretationBox[
            DynamicModuleBox[ _, TemplateBox[ { _, label_, ___ }, "IconizedObject", ___ ], ___ ],
            code_,
            ___,
            BaseStyle -> "FoldedCode",
            ___
        ] :> { HoldComplete @ code, label },
        Infinity
    ];

    $optionsLabel = StyleBox[ "\"options\"", "IconizedCustomName", ___ ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "CodeFolding-Definitions"
]

(* Code that's folded with IconizedObject is displayed like an iconized selection in a notebook, with the code as its
   interpretation: *)
VerificationTest[
    foldedCode @ StringToBoxes[
        "Plot[Sin[x], {x, 0, 10}, IconizedObject[Sequence[PlotStyle -> Red, Filling -> Axis], \"options\"]]",
        "WL"
    ],
    { { HoldComplete @ Sequence[ PlotStyle -> Red, Filling -> Axis ], $optionsLabel } },
    SameTest -> MatchQ,
    TestID   -> "CodeFolding-Boxes"
]

(* The label is optional: *)
VerificationTest[
    foldedCode @ StringToBoxes[ "Total[IconizedObject[Range[100]]]", "WL" ],
    { { HoldComplete @ Range[ 100 ], Except[ _StyleBox ] } },
    SameTest -> MatchQ,
    TestID   -> "CodeFolding-No-Label"
]

(* Several arguments are folded together if they weren't wrapped in Sequence, where a string as the last argument is
   the label: *)
VerificationTest[
    foldedCode @ StringToBoxes[
        "Plot[Sin[x], {x, 0, 10}, IconizedObject[PlotStyle -> Red, Filling -> Axis, \"options\"], IconizedObject[Frame -> True, Axes -> False]]",
        "WL"
    ],
    {
        { HoldComplete @ Sequence[ PlotStyle -> Red, Filling -> Axis ], $optionsLabel },
        { HoldComplete @ Sequence[ Frame -> True, Axes -> False ], Except[ _StyleBox ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeFolding-Missing-Sequence"
]

(* The formatted code evaluates the same as the code that was folded, including folds inside of folds and code that's
   spread over several lines: *)
VerificationTest[
    ToExpression[
        StringToBoxes[
            "{\n    1,\n    IconizedObject[\n        Sequence[2, 3],\n        \"more\"\n    ],\n    IconizedObject[4, 5],\n    IconizedObject[{IconizedObject[6, \"inner\"]}, \"outer\"]\n}",
            "WL"
        ],
        StandardForm
    ],
    { 1, 2, 3, 4, 5, { 6 } },
    SameTest -> MatchQ,
    TestID   -> "CodeFolding-Evaluation"
]

(* Without anything to fold, the code is left as it is: *)
VerificationTest[
    StringToBoxes[ "f[IconizedObject[]]", "WL" ],
    RowBox @ { "f", "[", RowBox @ { "IconizedObject", "[", "]" }, "]" },
    SameTest -> MatchQ,
    TestID   -> "CodeFolding-No-Arguments-Unchanged"
]

(* Code with embedded boxes is not folded: *)
VerificationTest[
    foldedCode @ StringToBoxes[ "{IconizedObject[\\!\\(x\\^2\\), \"math\"], IconizedObject[x^2, \"math\"]}", "WL" ],
    { { HoldComplete[ _^2 ], _ } },
    SameTest -> MatchQ,
    TestID   -> "CodeFolding-Embedded-Boxes-Unchanged"
]

(* The full formatting path folds code in finished chat output: *)
VerificationTest[
    foldedCode @ FormatChatOutput[
        "```wl\nPlot[Sin[x], {x, 0, 10}, IconizedObject[Sequence[PlotStyle -> Red, Filling -> Axis], \"options\"]]\n```\n"
    ],
    { { HoldComplete @ Sequence[ PlotStyle -> Red, Filling -> Axis ], $optionsLabel } },
    SameTest -> MatchQ,
    TestID   -> "CodeFolding-Formatted-Output"
]

(* While streaming, everything from the start of a fold is hidden behind an icon, since finding where the fold ends
   would need the code to be parsed: *)
VerificationTest[
    Table[
        Cases[
            FormatChatOutput[ "```wl\nPlot[Sin[x], {x, 0, 10}, " <> rest, <| "Status" -> "Streaming" |> ],
            s_String /; StringStartsQ[ s, "Plot[Sin[x], {x, 0, 10}, " ] :> {
                StringContainsQ[ s, "TemplateBox" ~~ __ ~~ "\"IconizedObject\"" ],
                StringFreeQ[ s, "IconizedObject[" | "PlotStyle" | "more" ]
            },
            Infinity
        ],
        {
            rest,
            {
                "IconizedObject",
                "IconizedObject[Sequence[PlotStyle -> Red, Fill",
                "IconizedObject[Sequence[PlotStyle -> Red, Filling -> Axis], \"options\"]];\nmore"
            }
        }
    ],
    { { { True, True } }, { { True, True } }, { { True, True } } },
    SameTest -> MatchQ,
    TestID   -> "CodeFolding-Streaming"
]

(* Serializing the formatted boxes back to text for the LLM gives the folded code in full: *)
VerificationTest[
    CellToString @ Cell[
        BoxData @ StringToBoxes[
            "Plot[Sin[x], {x, 0, 10}, IconizedObject[Sequence[PlotStyle -> Red, Filling -> Axis], \"options\"]]",
            "WL"
        ],
        "Input"
    ],
    "```wl\nPlot[Sin[x], {x, 0, 10}, IconizedObject[Sequence[PlotStyle -> Red, Filling -> Axis], \"options\"]]\n```",
    SameTest -> MatchQ,
    TestID   -> "CodeFolding-Serialization-RoundTrip"
]

VerificationTest[
    CellToString @ Cell[
        BoxData @ StringToBoxes[ "{IconizedObject[Range[100]], IconizedObject[1, 2]}", "WL" ],
        "Input"
    ],
    "```wl\n{IconizedObject[Range[100]], IconizedObject[Sequence[1, 2]]}\n```",
    SameTest -> MatchQ,
    TestID   -> "CodeFolding-Serialization-RoundTrip-No-Label"
]

(* Other iconized expressions can be large, so they are still only summarized: *)
VerificationTest[
    CellToString @ Cell[ BoxData @ ToBoxes @ Iconize[ Range[ 100 ], "data" ], "Input" ],
    "```wl\nIconizedObject[\[LeftGuillemet]data\[RightGuillemet]]\n```",
    SameTest -> MatchQ,
    TestID   -> "CodeFolding-Serialization-Other-Iconized-Objects"
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
    TestID   -> "ColorSwatch-RGBColor"
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
    TestID   -> "ColorSwatch-All-Color-Models"
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
    TestID   -> "ColorSwatch-LightDarkSwitched"
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
    TestID   -> "ColorSwatch-ThemeColor"
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
    TestID   -> "ColorSwatch-Nested-In-Expression"
]

(* Arguments that are not literal numbers (symbols, patterns, unevaluated expressions) do not typeset as swatches in the
   front end either, so the code is left as-is: *)
VerificationTest[
    StringToBoxes[ "{RGBColor[Red, Green, Blue], Hue[N[1/3]], RGBColor[1, 0], Cases[expr, RGBColor[r_, g_, b_]]}", "WL" ],
    boxes_ /; FreeQ[ boxes, _TemplateBox ],
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Non-Numeric-Arguments-Unchanged"
]

(* When a color is not converted, special boxes inside its arguments are still formatted: *)
VerificationTest[
    StringToBoxes[ "RGBColor[Placeholder[\"red\"], 0, 0]", "WL" ],
    RowBox @ { "RGBColor", "[", RowBox @ { TagBox[ FrameBox[ "\"red\"" ], "Placeholder" ], ",", "0", ",", "0" }, "]" },
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Inner-Special-Boxes-Still-Formatted"
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
    TestID   -> "ColorSwatch-Formatted-Output"
]

(* Serializing the formatted boxes back to text for the LLM recovers the original code: *)
VerificationTest[
    CellToString @ Cell[
        BoxData @ StringToBoxes[ "{RGBColor[1, 0, 0], Hue[0.3], GrayLevel[0.5]}", "WL" ],
        "Output"
    ],
    "```wl\n{RGBColor[1, 0, 0], Hue[0.3], GrayLevel[0.5]}\n```",
    SameTest -> MatchQ,
    TestID   -> "ColorSwatch-Serialization-RoundTrip"
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
    TestID   -> "ColorSwatch-Serialization-RoundTrip-LightDarkSwitched-ThemeColor"
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
    TestID   -> "ColorSwatch-Serialization-Precomputed-Rules"
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
    TestID   -> "Manipulate-Boxes-Are-Not-Cached"
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
    TestID   -> "ActiveToolProgressIndicator-Tagged"
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
    TestID   -> "DynamicProgressIndicator-OrdinaryText"
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
    TestID   -> "DynamicProgressIndicator-ActiveTool"
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
    TestID   -> "DynamicProgressIndicator-EmptyContent"
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
    TestID   -> "DynamicProgressIndicator-MethodAware"
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
    TestID   -> "Markdown-ToolCall-Before-Escaped-CodeBlock"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Line Endings*)

(* "\r\n" and a lone "\r" are line breaks, so a response written with either one formats exactly like the same response
   written with "\n", when finished, while streaming, and serialized. These are the responses that don't: *)
VerificationTest[
    Select[
        Tuples @ {
            {
                "Line one\nLine two\n\nPara two",
                "## Heading\n\nText\n- item\n- item2\n  - nested\n\n1. one\n2. two",
                "> a\n> b\n\n---\n\nAfter",
                "| a | b |\n|---|---|\n| 1 | 2 |\n\nAfter",
                "Text\n\n```python\na = 1\nb = 2\n```\n\n```wl\na = 1;\nb = 2\n```\n\nAfter",
                StringJoin[
                    "A\n\nTOOLCALL: web_fetcher\n{\"url\":\"https://example.com\"}\nENDARGUMENTS\nENDTOOLCALL\n",
                    "RESULT\nok\nENDRESULT(crlf0001)\n\nB"
                ],
                "Before\n<think>\nSome thoughts\n- a\n- b\n</think>\nAfter",
                "Text\n$$x^2$$\nMore with *it*\nand \\$5"
            },
            { "\r\n", "\r" }
        },
        Function[
            With[ { md = #[[ 1 ]], other = StringReplace[ #[[ 1 ]], "\n" -> #[[ 2 ]] ] },
                Or[
                    FormatMarkdown @ other =!= FormatMarkdown @ md,
                    FormatMarkdown[ other, "Streaming" ] =!= FormatMarkdown[ md, "Streaming" ],
                    MarkdownRoundTrip @ other =!= MarkdownRoundTrip @ md
                ]
            ]
        ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Markdown-Line-Endings-Same-As-LF"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*TeX Conversion Re-entrancy*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* Calling makeTeXBoxes from inside the conversion stands in for a preemptive evaluation that interrupts it: *)
VerificationTest[
    Module[ { calls = 0, nested, id, reentered },
        (* The inputs include $ModuleNumber so that they haven't been converted before in the session: *)
        id = ToString @ $ModuleNumber;
        reentered = "reentered-" <> id;
        Block[ { InputAssistant`TeXAssistant },
            InputAssistant`TeXAssistant[ input_String ] := (
                calls++;
                If[ calls === 1, nested = Wolfram`Chatbook`Common`makeTeXBoxes @ reentered ];
                RawBoxes @ TemplateBox[
                    <| "boxes" -> "x", "errors" -> { }, "input" -> input, "state" -> "Boxes" |>,
                    "TeXAssistantTemplate"
                ]
            );
            {
                Wolfram`Chatbook`Common`makeTeXBoxes[ "outer-" <> id ],
                calls,
                nested,
                Wolfram`Chatbook`Common`makeTeXBoxes @ reentered,
                calls
            }
        ]
    ],
    { _RawBoxes, 1, $Failed, _RawBoxes, 2 },
    SameTest -> MatchQ,
    TestID   -> "TeX-Reentrant-Conversion-Skipped-Not-Cached-GH#1796"
]

VerificationTest[
    Module[ { id, math, cached, nested },
        id = ToString @ $ModuleNumber;
        math = "x^{" <> id <> "}";
        cached = Wolfram`Chatbook`Common`makeTeXBoxes @ math;
        Block[ { InputAssistant`TeXAssistant },
            InputAssistant`TeXAssistant[ input_String ] := (
                nested = Wolfram`Chatbook`Common`makeTeXBoxes @ math;
                RawBoxes @ TemplateBox[
                    <| "boxes" -> "x", "errors" -> { }, "input" -> input, "state" -> "Boxes" |>,
                    "TeXAssistantTemplate"
                ]
            );
            Wolfram`Chatbook`Common`makeTeXBoxes[ "cached-outer-" <> id ];
            { MatchQ[ cached, _RawBoxes ], nested === cached }
        ]
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "TeX-Reentrant-Conversion-Uses-Cache-GH#1796"
]

(* The guard is released when a conversion fails or is interrupted: *)
VerificationTest[
    With[ { id = ToString @ $ModuleNumber },
        Block[ { InputAssistant`TeXAssistant },
            InputAssistant`TeXAssistant[ _String ] := Throw[ "interrupted", "gh1796" ];
            Catch[ Wolfram`Chatbook`Common`makeTeXBoxes[ "throws-" <> id ], "gh1796" ];
            InputAssistant`TeXAssistant[ input_String ] := RawBoxes @ TemplateBox[
                <| "boxes" -> "x", "errors" -> { }, "input" -> input, "state" -> "Boxes" |>,
                "TeXAssistantTemplate"
            ];
            Wolfram`Chatbook`Common`makeTeXBoxes[ "after-throw-" <> id ]
        ]
    ],
    _RawBoxes,
    SameTest -> MatchQ,
    TestID   -> "TeX-Conversion-Guard-Released-After-Throw-GH#1796"
]

(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Untrusted Content Safety*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
(* :!CodeAnalysis::Disable::GlobalSymbol:: *)

(* The finished-mode formatter turns DateObject[...] boxes into a date, which evaluates the expression (ReleaseHold).
   An option whose value is arbitrary code (never a literal atom), or a RuleDelayed option, must not be evaluated: the
   boxes are kept as plain code instead. This holds in a code block, in inline code, and in a tool result formatted by
   toolAutoFormatter. The probe symbol would be assigned if the option value were evaluated. *)
VerificationTest[
    {
        Block[ { Global`cbDateProbe = "unset" },
            FormatChatOutput[
                "```wl\nDateObject[{2024, 1, 1}, TimeZone -> (Global`cbDateProbe = 1; 0)]\n```",
                <| "Status" -> "Finished" |>
            ];
            Global`cbDateProbe
        ],
        Block[ { Global`cbDateProbe = "unset" },
            FormatChatOutput[
                "```wl\nDateObject[{2024, 1, 1}, TimeZone :> (Global`cbDateProbe = 1; 0)]\n```",
                <| "Status" -> "Finished" |>
            ];
            Global`cbDateProbe
        ],
        Block[ { Global`cbDateProbe = "unset" },
            FormatChatOutput[
                "Use `DateObject[{2024, 1, 1}, TimeZone -> (Global`cbDateProbe = 1; 0)]` here.",
                <| "Status" -> "Finished" |>
            ];
            Global`cbDateProbe
        ],
        Block[ { Global`cbDateProbe = "unset" },
            Wolfram`Chatbook`Formatting`Private`toolAutoFormatter[
                "Fetched page:\n```wl\nDateObject[{2024, 1, 1}, TimeZone -> (Global`cbDateProbe = 1; 0)]\n```\n",
                "Result"
            ];
            Global`cbDateProbe
        ]
    },
    { "unset", "unset", "unset", "unset" },
    SameTest -> MatchQ,
    TestID   -> "UntrustedContent-DateObject-Options-Not-Evaluated"
]

(* A DateObject with a literal option (and with positional arguments only) still formats as a date, so the protection
   does not break the common case: *)
VerificationTest[
    {
        FreeQ[ StringToBoxes[ "DateObject[{2024, 1, 1}, TimeZone -> \"America/New_York\"]", "WL" ], TemplateBox[ _, "DateObject", ___ ] ],
        FreeQ[ StringToBoxes[ "DateObject[{2024, 1, 1}, \"Day\", \"Gregorian\", -5.]", "WL" ], TemplateBox[ _, "DateObject", ___ ] ]
    },
    { False, False },
    SameTest -> MatchQ,
    TestID   -> "UntrustedContent-DateObject-Literal-Option-Still-Formats"
]

(* An entity whose qualifier list holds arbitrary code (e.g. EntityProperty's third argument) must not be evaluated by
   MakeBoxes: the boxes are kept as plain code. The probe would be assigned if the qualifier value were evaluated. *)
VerificationTest[
    {
        Block[ { Global`cbEntProbe = "unset" },
            StringToBoxes[ "EntityProperty[\"Country\", \"Population\", {\"Date\" -> (Global`cbEntProbe = 1; 2020)}]", "WL" ];
            Global`cbEntProbe
        ],
        FreeQ[ StringToBoxes[ "EntityProperty[\"Country\", \"Population\", {\"Date\" -> (expr; 2020)}]", "WL" ], _TemplateBox ]
    },
    { "unset", True },
    SameTest -> MatchQ,
    TestID   -> "UntrustedContent-Entity-Qualifier-Not-Evaluated"
]

(* HTML entities in the model's text are decoded only when they are real named or numeric entities, with their case
   kept, each on its own (also adjacent ones); anything else (e.g. a bit of code that looks like "&...;") is returned
   unchanged, never lowercased: *)
VerificationTest[
    Wolfram`Chatbook`Formatting`Private`importHTMLEntities /@ {
        "result = Map[#^2 &, M];",
        "a && B;",
        "#&/@L;",
        "x &amp; y",
        "&Alpha; and &alpha;",
        "&#34;q&#34;",
        "&amp;",
        "&lt;&gt;",
        "cout &lt;&lt; x",
        "a &gt;&gt; b",
        "x&lt;y;",
        "&#x3C;b&#62;"
    },
    {
        "result = Map[#^2 &, M];",
        "a && B;",
        "#&/@L;",
        "x & y",
        "\[CapitalAlpha] and \[Alpha]",
        "\"q\"",
        "&",
        "<>",
        "cout << x",
        "a >> b",
        "x<y;",
        "<b>"
    },
    SameTest -> MatchQ,
    TestID   -> "ImportHTMLEntity-Real-Entities-Only"
]

(* Code keeps its HTML entities as they are written, in code blocks (also one that is not closed yet) and inline code,
   while the same entities in the text around it are decoded: *)
VerificationTest[
    {
        Wolfram`Chatbook`Formatting`Private`importHTMLEntities[
            "Use &lt;b&gt;:\n```wl\nStringReplace[html, {\"&lt;\" -> \"<\", \"&amp;\" -> \"&\"}]\n```\nthen `a &amp;&amp; b` and ``x &lt; y`` &amp; more"
        ],
        Wolfram`Chatbook`Formatting`Private`importHTMLEntities[ "Streaming &amp;\n```python\nhtml.replace('&amp;', '&')" ],
        Cases[
            FormatChatOutput[ "```python\nhtml.replace('&amp;', '&')\n```", <| "Status" -> "Finished" |> ],
            s_String /; StringContainsQ[ s, "html.replace" ] :> StringContainsQ[ s, "'&amp;'" ],
            Infinity
        ],
        ! FreeQ[
            FormatChatOutput[ "```wl\nStringReplace[html, \"&lt;\" -> \"<\"]\n```", <| "Status" -> "Streaming" |> ],
            s_String /; StringContainsQ[ s, "&lt;" ]
        ]
    },
    {
        "Use <b>:\n```wl\nStringReplace[html, {\"&lt;\" -> \"<\", \"&amp;\" -> \"&\"}]\n```\nthen `a &amp;&amp; b` and ``x &lt; y`` & more",
        "Streaming &\n```python\nhtml.replace('&amp;', '&')",
        { __? TrueQ },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ImportHTMLEntity-Code-Kept-Verbatim"
]

(* The untrusted-content switch keeps the formatter from importing markdown images (they become links to their source)
   and from evaluating special boxes (a Wolfram|Alpha query, a DateObject: both are kept as code), and decodes no HTML
   entities (the "&amp;" is kept). Without the switch the same text queries Wolfram|Alpha and formats the date, so the
   test can't pass because the formatter does neither anyway. Queries are unique, as their results are cached. *)
VerificationTest[
    Module[ { imageCalls = { }, alphaCalls = { }, query, format },
        query[ ] := "population of " <> CreateUUID[ ];
        format[ text_ ] := FormatChatOutput[ text, <| "Status" -> "Finished" |> ];
        Block[
            {
                Import       = (AppendTo[ imageCalls, { ## } ]; $Failed) &,
                WolframAlpha = (AppendTo[ alphaCalls, { ## } ]; $Failed) &
            },
            {
                ! FreeQ[
                    Wolfram`Chatbook`Common`withUntrustedContent @ format[ "![alt](https://example.com/x.png)" ],
                    ButtonBox[ "alt", ___, ButtonData -> { URL[ "https://example.com/x.png" ], None }, ___ ]
                ],
                imageCalls,
                Wolfram`Chatbook`Common`withUntrustedContent @ format[ "```wl\n\[FreeformPrompt][\"" <> query[ ] <> "\"]\n```" ];
                alphaCalls,
                format[ "```wl\n\[FreeformPrompt][\"" <> query[ ] <> "\"]\n```" ];
                Length @ alphaCalls,
                FreeQ[
                    Wolfram`Chatbook`Common`withUntrustedContent @ format[ "```wl\nDateObject[{2024, 1, 1}, TimeZone -> \"America/New_York\"]\n```" ],
                    TemplateBox[ _, "DateObject", ___ ]
                ],
                FreeQ[
                    format[ "```wl\nDateObject[{2024, 1, 1}, TimeZone -> \"America/New_York\"]\n```" ],
                    TemplateBox[ _, "DateObject", ___ ]
                ],
                ! FreeQ[
                    Wolfram`Chatbook`Common`withUntrustedContent @ format[ "x &amp; y" ],
                    s_String /; StringContainsQ[ s, "&amp;" ]
                ]
            }
        ]
    ],
    { True, { }, { }, 1, True, False, True },
    SameTest -> MatchQ,
    TestID   -> "UntrustedContent-Switch-Disables-Effects"
]

(* The front end's linear syntax (private-use characters) in the model's text, in a tool result or in the code of a
   tool call never makes the front end evaluate a box expression (with the code in it) and never reaches
   the output boxes, where the front end would turn it into boxes when it shows them: the characters are replaced with
   U+FFFD. The probe would gain an entry if the box expression were evaluated. *)
VerificationTest[
    Module[ { payload, linearSyntaxQ, results },
        payload[ tag_String ] := "f[\!\(\*RowBox[{AppendTo[Global`cbLinearSyntaxProbe, \"" <> tag <> "\"]; \"x\"}]\)]";
        linearSyntaxQ[ expr_ ] := ! FreeQ[ expr, s_String /; StringContainsQ[ s, "\!" | "\(" | "\*" ] ];
        Global`cbLinearSyntaxProbe = { };
        results = {
            FormatChatOutput[ "```wl\n" <> payload[ "block" ] <> "\n```", <| "Status" -> "Finished" |> ],
            FormatChatOutput[ "Run `" <> payload[ "inline" ] <> "` now.", <| "Status" -> "Finished" |> ],
            FormatChatOutput[ "Some text " <> payload[ "text" ], <| "Status" -> "Finished" |> ],
            FormatChatOutput[ "Some text " <> payload[ "streaming" ], <| "Status" -> "Streaming" |> ],
            FormatChatOutput[
                StringJoin[
                    "TOOLCALL: WebFetcher\n{\"url\": \"https://example.com\"}\nRESULT\nFetched page:\n```wl\n",
                    payload[ "toolcall" ],
                    "\n```\nENDRESULT(abc123)\nENDTOOLCALL"
                ],
                <| "Status" -> "Finished" |>
            ],
            Block[ { Wolfram`Chatbook`Common`$dynamicText = False },
                Wolfram`Chatbook`Common`makeInteractiveCodeCell[ "Wolfram", payload[ "code" ] ]
            ],
            StringToBoxes[ payload[ "stringToBoxes" ], "WL" ]
        };
        {
            Global`cbLinearSyntaxProbe,
            linearSyntaxQ /@ results,
            (* the code is still shown, with the replacement characters *)
            ! FreeQ[ #, s_String /; StringContainsQ[ s, "\:fffd" ] ] & /@ results
        }
    ],
    { { }, { False, False, False, False, False, False, False }, { True, True, True, True, True, True, True } },
    SameTest -> MatchQ,
    TestID   -> "UntrustedContent-LinearSyntax-Not-Evaluated"
]

(* The characters of linear syntax are also replaced when the formatter makes them from the text, after the text itself
   was checked: from hexadecimal or decimal HTML entities (in prose, and in inline code whose backticks are entities too,
   streaming or finished) and from TeX's \char, also by the untrusted-content formatter (which decodes no entity but
   does format TeX). Other entities are still decoded. *)
VerificationTest[
    Module[ { linearSyntaxQ, entities, tex, results },
        linearSyntaxQ[ expr_ ] := ! FreeQ[ expr, s_String /; AnyTrue[ ToCharacterCode @ s, 63424 <= # <= 63437 & ] ];
        entities = "&#xF7C1;&#xF7C9;RowBox[{&#34;x&#34;}]&#63424;";
        tex = "$$\\text{\\char63425\\char63433 x\\char63424}$$";
        results = {
            FormatChatOutput[ "Some text " <> entities, <| "Status" -> "Finished" |> ],
            FormatChatOutput[ "Some text " <> entities, <| "Status" -> "Streaming" |> ],
            FormatChatOutput[ "Run &#96;f[" <> entities <> "]&#96; now.", <| "Status" -> "Finished" |> ],
            FormatChatOutput[ "Run &#96;f[" <> entities <> "]&#96; now.", <| "Status" -> "Streaming" |> ],
            FormatChatOutput[ "Math: " <> tex, <| "Status" -> "Finished" |> ],
            FormatChatOutput[ "Math: " <> tex, <| "Status" -> "Streaming" |> ],
            Wolfram`Chatbook`Common`withUntrustedContent @ FormatChatOutput[ "Math: " <> tex, <| "Status" -> "Finished" |> ]
        };
        {
            linearSyntaxQ /@ results,
            ! FreeQ[ #, s_String /; StringContainsQ[ s, "\:fffd" ] ] & /@ results,
            Wolfram`Chatbook`Formatting`Private`importHTMLEntity /@ { "&#xF7C1;", "&#63432;", "&#x41;", "&#66;" }
        }
    ],
    {
        { False, False, False, False, False, False, False },
        { True, True, True, True, True, True, True },
        { "\:fffd", "\:fffd", "A", "B" }
    },
    SameTest -> MatchQ,
    TestID   -> "UntrustedContent-LinearSyntax-Decoded-Characters"
]

(* What a tool call shows besides its text: the model's parameters (with the tool's formatter, with clickToCopy, or as
   a query string), the raw tool call, and a result that toolAutoFormatter shows as an expression (WebSearcher's
   Dataset, a list) have the characters replaced. Expressions without them are left as they are. A Dataset is checked by
   its Normal form, as patterns do not always see the strings in it. *)
VerificationTest[
    Module[ { linearSyntaxQ, payload, results },
        linearSyntaxQ[ expr_ ] := ! FreeQ[ expr, s_String /; AnyTrue[ ToCharacterCode @ s, 63424 <= # <= 63437 & ] ];
        payload = "q \!\(\*RowBox[{\"x\"}]\)";
        results = ReplaceAll[ d_Dataset :> RuleCondition @ Normal @ d ] @ {
            Wolfram`Chatbook`Formatting`Private`makeToolCallInputSection @ <|
                "Parameters"         -> <| "query" -> payload |>,
                "FormattingFunction" -> Wolfram`Chatbook`Common`toolAutoFormatter
            |>,
            Wolfram`Chatbook`Formatting`Private`makeToolCallInputSection @ <|
                "Parameters"         -> <| "query" -> payload |>,
                "FormattingFunction" -> (Wolfram`Chatbook`Common`clickToCopy[ #1 ] &)
            |>,
            Wolfram`Chatbook`Formatting`Private`makeToolCallInputSection @ <| "Parameters" -> payload |>,
            Wolfram`Chatbook`Formatting`Private`makeToolCallRawView @ <|
                "ToolCall" -> "TOOLCALL: web_searcher\n{\"query\": \"" <> payload <> "\"}"
            |>,
            Wolfram`Chatbook`Formatting`Private`makeToolCallOutputSection @ <|
                "Result"             -> <| "Result" -> Dataset @ { <| "Title" -> payload |> }, "String" -> "" |>,
                "FormattingFunction" -> Wolfram`Chatbook`Common`toolAutoFormatter
            |>,
            Wolfram`Chatbook`Common`toolAutoFormatter[ { payload }, "Result" ]
        };
        {
            linearSyntaxQ /@ results,
            ! FreeQ[ #, s_String /; StringContainsQ[ s, "\:fffd" ] ] & /@ results,
            Wolfram`Chatbook`Common`neutralizeLinearSyntax @ <| "a" -> { "b", 1, None } |>
        }
    ],
    {
        { False, False, False, False, False, False },
        { True, True, True, True, True, True },
        <| "a" -> { "b", 1, None } |>
    },
    SameTest -> MatchQ,
    TestID   -> "UntrustedContent-LinearSyntax-ToolCall-Views"
]

(* :!CodeAnalysis::EndBlock:: *)
