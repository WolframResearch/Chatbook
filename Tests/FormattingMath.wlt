(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/FormattingMath.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/FormattingMath.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Helpers*)

(* mathItems[ md ] gives the normalized TextData items (see NormalizeTextData) for a markdown string, with every
   formatted math cell replaced by:
     MathTeX[ input, state, cellOptions... ]        for finished output
     MathTeXStreaming[ boxes, cellOptions... ]      for streaming output
   The replacement only applies to the exact cell structure the formatter creates for math, so a change to the wrapper
   (e.g. a missing FormBox or a different template name) still makes the tests below fail.
   mathTrimmedText[ str ] is a pattern for a string that is str apart from whitespace at its ends. *)
VerificationTest[
    ClearAll[ mathItems, MathTeX, MathTeXStreaming, $mathCellRules, mathTrimmedText ];
    $mathCellRules = {
        Cell[
            BoxData @ FormBox[
                TemplateBox[
                    KeyValuePattern @ { "boxes" -> _, "input" -> input_String, "state" -> state_String },
                    "TeXAssistantTemplate"
                ],
                TraditionalForm
            ],
            opts___
        ] :> MathTeX[ input, state, opts ],
        Cell[ BoxData @ FormBox[ StyleBox[ boxes_, "TeXAssistantBoxes" ], TraditionalForm ], opts___ ] :>
            MathTeXStreaming[ boxes, opts ]
    };
    mathItems[ md_String ] := mathItems[ md, "Finished" ];
    mathItems[ md_String, status_String ] :=
        ReplaceAll[ NormalizeTextData @ FormatMarkdown[ md, status ], $mathCellRules ];
    mathTrimmedText[ str_String ] := _String? (StringTrim @ # === str &),
    Null,
    SameTest -> MatchQ,
    TestID   -> "Math-Helpers@@Tests/FormattingMath.wlt:32,1-55,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Math Cells*)

(* Finished math is a TeXAssistantTemplate box in a TraditionalForm FormBox, in an inline Cell. The template keeps the
   boxes made from the TeX, the TeX itself (used by CellToString) and the parse state: *)
VerificationTest[
    FormatMarkdown[ "$$x^2$$" ],
    {
        Cell @ BoxData @ FormBox[
            TemplateBox[
                KeyValuePattern @ {
                    "boxes"  -> FormBox[ SuperscriptBox[ StyleBox[ "x", "TI" ], "2" ], TraditionalForm ],
                    "errors" -> { },
                    "input"  -> "x^2",
                    "state"  -> "Boxes"
                },
                "TeXAssistantTemplate"
            ],
            TraditionalForm
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Cell-Finished@@Tests/FormattingMath.wlt:63,1-81,2"
]

(* While streaming, only the boxes are shown, wrapped in a "TeXAssistantBoxes" StyleBox instead of the template: *)
VerificationTest[
    FormatMarkdown[ "$$x^2$$", "Streaming" ],
    {
        Cell @ BoxData @ FormBox[
            StyleBox[ FormBox[ SuperscriptBox[ StyleBox[ "x", "TI" ], "2" ], TraditionalForm ], "TeXAssistantBoxes" ],
            TraditionalForm
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Cell-Streaming@@Tests/FormattingMath.wlt:84,1-94,2"
]

(* The streaming boxes are the same boxes that the finished template holds, for every delimiter and in nested
   content, so the math does not change its appearance when the response finishes: *)
VerificationTest[
    Table[
        SameQ[
            FirstCase[
                FormatMarkdown @ md,
                TemplateBox[ as_Association, "TeXAssistantTemplate" ] :> as[ "boxes" ],
                $Failed,
                Infinity
            ],
            FirstCase[ FormatMarkdown[ md, "Streaming" ], StyleBox[ b_, "TeXAssistantBoxes" ] :> b, None, Infinity ]
        ],
        { md, { "$x$", "\\(\\alpha\\)", "\\[\\frac{1}{2}\\]", "$$\\frac{a}{b$$", "- item $y^2$", "## $z$" } }
    ],
    { True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Math-Cell-Streaming-Same-Boxes@@Tests/FormattingMath.wlt:98,1-114,2"
]

(* Math is an inline cell in the surrounding text: *)
VerificationTest[
    mathItems[ "Let $x$ be a variable." ],
    { "Let ", MathTeX[ "x", "Boxes" ], " be a variable." },
    SameTest -> MatchQ,
    TestID   -> "Math-Cell-Inline-In-Text@@Tests/FormattingMath.wlt:117,1-122,2"
]

(* The TeX parser (InputAssistant`TeXAssistant) runs once for a math expression, not again for every streamed chunk that
   contains it, in another context, or when the response finishes. The TeX includes $ModuleNumber so that it hasn't been
   parsed before in the session: *)
VerificationTest[
    Module[ { count = 0, inside = False, math },
        math = "$$q_{" <> ToString @ $ModuleNumber <> "}$$";
        Internal`InheritedBlock[ { InputAssistant`TeXAssistant },
            Unprotect @ InputAssistant`TeXAssistant;
            InputAssistant`TeXAssistant[ s_String ] /; ! inside :=
                Block[ { inside = True }, count++; InputAssistant`TeXAssistant @ s ];
            FormatMarkdown[ "Let " <> math, "Streaming" ];
            FormatMarkdown[ "Let " <> math <> " be", "Streaming" ];
            FormatMarkdown[ "- Let " <> math <> " be", "Streaming" ];
            FormatMarkdown[ "- Let " <> math <> " be" ];
            count
        ]
    ],
    1,
    SameTest -> MatchQ,
    TestID   -> "Math-Cell-TeX-Parsed-Once@@Tests/FormattingMath.wlt:127,1-144,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Delimiters*)

(* $$...$$, \(...\) and $...$ all give the same inline math cell: *)
VerificationTest[
    mathItems /@ { "A $$x^2$$ B", "A \\(x^2\\) B", "A $x^2$ B" },
    ConstantArray[ { "A ", MathTeX[ "x^2", "Boxes" ], " B" }, 3 ],
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Equivalent@@Tests/FormattingMath.wlt:151,1-156,2"
]

(* \[...\] gives the same math cell too (see the "Bracket Delimiters" section for its other rules): *)
VerificationTest[
    mathItems /@ { "\\[x^2\\]", "\\[\\alpha\\]" },
    { { MathTeX[ "x^2", "Boxes" ] }, { MathTeX[ "\\alpha", "Boxes" ] } },
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Brackets@@Tests/FormattingMath.wlt:159,1-164,2"
]

(* Display math is not rendered differently from inline math, it's an inline cell in the text: *)
VerificationTest[
    mathItems[ "The formula $$E = mc^2$$ is famous." ],
    { "The formula ", MathTeX[ "E = mc^2", "Boxes" ], " is famous." },
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Display-Inline@@Tests/FormattingMath.wlt:167,1-172,2"
]

(* Display math on its own line keeps the line breaks around it: *)
VerificationTest[
    mathItems[ "Line one\n$$x$$\nLine two" ],
    { "Line one\n", MathTeX[ "x", "Boxes" ], "\nLine two" },
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Display-Own-Line@@Tests/FormattingMath.wlt:175,1-180,2"
]

(* Display math in its own paragraph: the blank lines next to it become single line breaks (as they do next to other
   block content), so it is still on its own line: *)
VerificationTest[
    mathItems[ "Here:\n\n$$x^2$$\n\nmore" ],
    { "Here:\n", MathTeX[ "x^2", "Boxes" ], "\nmore" },
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Display-Paragraph@@Tests/FormattingMath.wlt:184,1-189,2"
]

(* Several math expressions on one line: *)
VerificationTest[
    mathItems /@ { "$x$, $y$, and $z$.", "\\(a\\) and \\(b\\)", "$$a$$ and $$b$$" },
    {
        { MathTeX[ "x", "Boxes" ], ", ", MathTeX[ "y", "Boxes" ], ", and ", MathTeX[ "z", "Boxes" ], "." },
        { MathTeX[ "a", "Boxes" ], " and ", MathTeX[ "b", "Boxes" ] },
        { MathTeX[ "a", "Boxes" ], " and ", MathTeX[ "b", "Boxes" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Multiple@@Tests/FormattingMath.wlt:192,1-201,2"
]

(* Math does not need whitespace around its delimiters: *)
VerificationTest[
    mathItems /@ { "a$x$b", "($x$)", "$x$y", "$x$$y$" },
    {
        { "a", MathTeX[ "x", "Boxes" ], "b" },
        { "(", MathTeX[ "x", "Boxes" ], ")" },
        { MathTeX[ "x", "Boxes" ], "y" },
        { MathTeX[ "x", "Boxes" ], MathTeX[ "y", "Boxes" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Adjacent@@Tests/FormattingMath.wlt:204,1-214,2"
]

(* $$...$$, \(...\) and \[...\] can span lines. Whitespace at the ends of the TeX is trimmed, but line breaks inside
   it are kept: *)
VerificationTest[
    mathItems /@ { "$$x\n+y$$", "\\(a\nb\\)", "$$\nx^2\n$$", "\\[\nx^2\n\\]" },
    {
        { MathTeX[ "x\n+y", "Boxes" ] },
        { MathTeX[ "a\nb", "Boxes" ] },
        { MathTeX[ "x^2", "Boxes" ] },
        { MathTeX[ "x^2", "Boxes" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Multiline@@Tests/FormattingMath.wlt:218,1-228,2"
]

(* With "\r\n" line endings, the line breaks around the math are kept. (The exact strings are not checked here: they
   currently become "\r \n", see the quirks.) *)
VerificationTest[
    mathItems /@ { "Text\r\n$$x^2$$\r\nMore", "$x$\r\n$y$" },
    With[ { crlf = ("\r"|" ")... ~~ "\n" },
        {
            {
                _String? (StringMatchQ[ "Text" ~~ crlf ]),
                MathTeX[ "x^2", "Boxes" ],
                _String? (StringMatchQ[ crlf ~~ "More" ])
            },
            { MathTeX[ "x", "Boxes" ], _String? (StringMatchQ[ crlf ]), MathTeX[ "y", "Boxes" ] }
        }
    ],
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-CRLF@@Tests/FormattingMath.wlt:232,1-246,2"
]

(* A multi-line environment with "&" and "\\": *)
VerificationTest[
    mathItems[ "$$\n\\begin{aligned}\na &= b \\\\\n&= c\n\\end{aligned}\n$$" ],
    { MathTeX[ "\\begin{aligned}\na &= b \\\\\n&= c\n\\end{aligned}", "Boxes" ] },
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Aligned@@Tests/FormattingMath.wlt:249,1-254,2"
]

(* Lines inside display math that look like other markdown blocks are part of the math: *)
VerificationTest[
    mathItems /@ { "Intro:\n$$\n- x\n$$", "$$\n|a| = |b|\n$$" },
    { { "Intro:\n", MathTeX[ "- x", "Boxes" ] }, { MathTeX[ "|a| = |b|", "Boxes" ] } },
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Block-Lookalikes@@Tests/FormattingMath.wlt:257,1-262,2"
]

(* Unterminated or empty delimiters are left as text: *)
VerificationTest[
    mathItems /@ { "$$x^2", "\\(a", "$x^2", "$100", "$$$$", "\\(\\)" },
    { { "$$x^2" }, { "\\(a" }, { "$x^2" }, { "$100" }, { "$$$$" }, { "\\(\\)" } },
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Unterminated@@Tests/FormattingMath.wlt:265,1-270,2"
]

(* The same holds while streaming, so partial math is shown as text until its closing delimiter arrives: *)
VerificationTest[
    mathItems[ #, "Streaming" ] & /@ { "The value is $x", "The value is $$\\frac{1}{", "\\(x^2" },
    { { "The value is $x" }, { "The value is $$\\frac{1}{" }, { "\\(x^2" } },
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Unterminated-Streaming@@Tests/FormattingMath.wlt:273,1-278,2"
]

(* The same in list items and headings: *)
VerificationTest[
    mathItems[ #, "Streaming" ] & /@ { "- item $x", "## Heading $$x" },
    {
        { Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " item $x" }, "InlineItem" ] },
        {
            Cell[
                BoxData @ PaneBox[ StyleBox[ "\"Heading $$x\"", "Section", ___ ], ___ ],
                "InlineSection",
                ___
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Unterminated-Streaming-Nested@@Tests/FormattingMath.wlt:281,1-295,2"
]

(* An unterminated \[ is a markdown-escaped bracket, so it is shown without its backslash while streaming: *)
VerificationTest[
    mathItems[ "Text\n\\[ x", "Streaming" ],
    { "Text\n[ x" },
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Unterminated-Brackets-Streaming@@Tests/FormattingMath.wlt:298,1-303,2"
]

(* Once the closing delimiter arrives while streaming, the math is shown: *)
VerificationTest[
    mathItems[ "Let $x^2$ be", "Streaming" ],
    { "Let ", MathTeXStreaming[ FormBox[ SuperscriptBox[ StyleBox[ "x", "TI" ], "2" ], TraditionalForm ] ], " be" },
    SameTest -> MatchQ,
    TestID   -> "Math-Delimiters-Terminated-Streaming@@Tests/FormattingMath.wlt:306,1-311,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Single Dollar Math*)

(* Text in single dollars is only math if it looks like math (probablyMathQ), so that dollar amounts in prose are left
   alone: *)
VerificationTest[
    mathItems /@ { "costs $5 and $10", "It costs $5 or $10 for 2 items", "$5 and $x$" },
    { { "costs $5 and $10" }, { "It costs $5 or $10 for 2 items" }, { "$5 and ", MathTeX[ "x", "Boxes" ] } },
    SameTest -> MatchQ,
    TestID   -> "Math-Dollar-Amounts@@Tests/FormattingMath.wlt:319,1-324,2"
]

(* The same rule applies in list items: *)
VerificationTest[
    mathItems[ "- costs $5 and $10, or $x$" ],
    {
        Cell[
            TextData @ { StyleBox[ "\[Bullet]", ___ ], " costs $5 and $10, or ", MathTeX[ "x", "Boxes" ] },
            "InlineItem"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Dollar-Amounts-In-List@@Tests/FormattingMath.wlt:327,1-337,2"
]

(* Escaped dollars are never math delimiters: *)
VerificationTest[
    mathItems /@ { "Price: \\$5 - \\$10", "x = \\$5 and y = \\$6", "\\$5 and $x^2$" },
    { { "Price: $5 - $10" }, { "x = $5 and y = $6" }, { "$5 and ", MathTeX[ "x^2", "Boxes" ] } },
    SameTest -> MatchQ,
    TestID   -> "Math-Dollar-Escaped-Amounts@@Tests/FormattingMath.wlt:340,1-345,2"
]

(* Only letters, digits and parentheses: *)
VerificationTest[
    mathItems /@ { "$x$", "$xy$", "$f(x)$", "$2x$", "$(abc)$" },
    {
        { MathTeX[ "x", "Boxes" ] },
        { MathTeX[ "xy", "Boxes" ] },
        { MathTeX[ "f(x)", "Boxes" ] },
        { MathTeX[ "2x", "Boxes" ] },
        { MathTeX[ "(abc)", "Boxes" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Dollar-Letters-And-Digits@@Tests/FormattingMath.wlt:348,1-359,2"
]

(* Anything with "+", "-", "=" or "^": *)
VerificationTest[
    mathItems /@ { "$-1$", "$x = 5$", "$a+b$", "$x^2$ here" },
    {
        { MathTeX[ "-1", "Boxes" ] },
        { MathTeX[ "x = 5", "Boxes" ] },
        { MathTeX[ "a+b", "Boxes" ] },
        { MathTeX[ "x^2", "Boxes" ], " here" }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Dollar-Operators@@Tests/FormattingMath.wlt:362,1-372,2"
]

(* Anything with a TeX command: *)
VerificationTest[
    mathItems /@ { "$\\alpha$ here", "$x \\cdot y$", "$\\frac{1}{2}$", "$e^{i\\pi}$" },
    {
        { MathTeX[ "\\alpha", "Boxes" ], " here" },
        { MathTeX[ "x \\cdot y", "Boxes" ] },
        { MathTeX[ "\\frac{1}{2}", "Boxes" ] },
        { MathTeX[ "e^{i\\pi}", "Boxes" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Dollar-Commands@@Tests/FormattingMath.wlt:375,1-385,2"
]

(* Unicode letters count as letters, and are converted to TeX commands: *)
VerificationTest[
    mathItems /@ { "$\[Alpha]$", "$\[Pi] r^2$" },
    { { MathTeX[ "\\alpha", "Boxes" ] }, { MathTeX[ "\\pi r^2", "Boxes" ] } },
    SameTest -> MatchQ,
    TestID   -> "Math-Dollar-Unicode@@Tests/FormattingMath.wlt:388,1-393,2"
]

(* Single dollar math can't span lines: *)
VerificationTest[
    mathItems /@ { "$x\ny$", "I paid $5\nfor 2+2 = $4" },
    { { "$x\ny$" }, { "I paid $5\nfor 2+2 = $4" } },
    SameTest -> MatchQ,
    TestID   -> "Math-Dollar-Newline@@Tests/FormattingMath.wlt:396,1-401,2"
]

(* Single dollar math must be shorter than 100 characters: *)
VerificationTest[
    {
        mathItems[ "$" <> StringRepeat[ "a+", 49 ] <> "a$" ],
        mathItems[
            "It costs $5 now, and later - after the price increase that everyone has been talking about for many " <>
            "weeks now - $10"
        ]
    },
    {
        { MathTeX[ StringRepeat[ "a+", 49 ] <> "a", "Boxes" ] },
        {
            "It costs $5 now, and later - after the price increase that everyone has been talking about for many " <>
            "weeks now - $10"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Dollar-Length@@Tests/FormattingMath.wlt:404,1-421,2"
]

(* None of these limits apply to the other delimiters: *)
VerificationTest[
    mathItems /@ { "$$x > y$$", "$$" <> StringRepeat[ "a+", 60 ] <> "a$$", "$$|x|$$" },
    {
        { MathTeX[ "x > y", "Boxes" ] },
        { MathTeX[ StringRepeat[ "a+", 60 ] <> "a", "Boxes" ] },
        { MathTeX[ "|x|", "Boxes" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Display-Not-Gated@@Tests/FormattingMath.wlt:424,1-433,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Math Contents*)

(* Math that only contains digits, ".", "," and spaces is shown as plain text: *)
VerificationTest[
    mathItems /@ { "$$1,000.5$$", "$$1,000$$ items", "$5$", "\\(3.14\\)" },
    { { "1,000.5" }, { "1,000 items" }, { "5" }, { "3.14" } },
    SameTest -> MatchQ,
    TestID   -> "Math-Numeric-Plain-Text@@Tests/FormattingMath.wlt:440,1-445,2"
]

(* The same while streaming: *)
VerificationTest[
    mathItems[ "$$1,000$$", "Streaming" ],
    { "1,000" },
    SameTest -> MatchQ,
    TestID   -> "Math-Numeric-Plain-Text-Streaming@@Tests/FormattingMath.wlt:448,1-453,2"
]

(* Math that is the name of a System symbol (longer than one character) is formatted as inline code, which makes it
   a documentation link: *)
VerificationTest[
    mathItems /@ { "Use $$Sin$$ and $Plot$", "$$Gamma$$" },
    {
        {
            "Use ",
            Cell @ BoxData @ TemplateBox[ { "Sin", "paclet:ref/Sin", _ }, "TextRefLink" ],
            " and ",
            Cell @ BoxData @ TemplateBox[ { "Plot", "paclet:ref/Plot", _ }, "TextRefLink" ]
        },
        { Cell @ BoxData @ TemplateBox[ { "Gamma", "paclet:ref/Gamma", _ }, "TextRefLink" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-System-Symbol-Link@@Tests/FormattingMath.wlt:457,1-470,2"
]

(* The same while streaming: *)
VerificationTest[
    mathItems[ "Use $$Sin$$", "Streaming" ],
    { "Use ", Cell @ BoxData @ TemplateBox[ { "Sin", "paclet:ref/Sin", _ }, "TextRefLink" ] },
    SameTest -> MatchQ,
    TestID   -> "Math-System-Symbol-Link-Streaming@@Tests/FormattingMath.wlt:473,1-478,2"
]

(* One-letter System symbols and other names are TeX: *)
VerificationTest[
    mathItems /@ { "$$E$$", "$$N$$", "$$Foo$$" },
    { { MathTeX[ "E", "Boxes" ] }, { MathTeX[ "N", "Boxes" ] }, { MathTeX[ "Foo", "Boxes" ] } },
    SameTest -> MatchQ,
    TestID   -> "Math-System-Symbol-Single-Letter@@Tests/FormattingMath.wlt:481,1-486,2"
]

(* If the TeX can't be made into boxes at all (mocked here, since TeXAssistant always gives boxes), the math is
   formatted as inline code instead. Markdown escapes in it are removed, as in other inline code: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`makeTeXBoxes = $Failed & },
        mathItems /@ { "Then $$x^2$$ end", "Then $$x$$ end", "Cost \\$5 and $$\\$x$$" }
    ],
    {
        {
            "Then ",
            Cell[ BoxData @ TemplateBox[ { Cell[ "x^2", ___ ] }, "ChatCodeInlineTemplate" ], "ChatCodeActive" ],
            " end"
        },
        { "Then ", StyleBox[ "x", "TI" ], " end" },
        {
            "Cost $5 and ",
            Cell[ BoxData @ TemplateBox[ { Cell[ "$x", ___ ] }, "ChatCodeInlineTemplate" ], "ChatCodeActive" ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-TeX-Failure-Fallback@@Tests/FormattingMath.wlt:490,1-508,2"
]

(* The same while streaming: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$resultCellCache = <| |>,
            Wolfram`Chatbook`Common`makeTeXBoxes     = $Failed &
        },
        mathItems[ "Then $$x^2$$ end", "Streaming" ]
    ],
    {
        "Then ",
        Cell[ BoxData @ TemplateBox[ { Cell[ "x^2", ___ ] }, "ChatCodeInlineTemplate" ], "ChatCodeActive" ],
        " end"
    },
    SameTest -> MatchQ,
    TestID   -> "Math-TeX-Failure-Fallback-Streaming@@Tests/FormattingMath.wlt:511,1-526,2"
]

(* A TeX template without boxes is put in the FormBox as is, even while streaming: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$resultCellCache = <| |>,
            Wolfram`Chatbook`Common`makeTeXBoxes =
                RawBoxes @ TemplateBox[ <| "input" -> #, "state" -> "Boxes" |>, "TeXAssistantTemplate" ] &
        },
        { FormatMarkdown[ "$$x^2$$" ], FormatMarkdown[ "$$x^2$$", "Streaming" ] }
    ],
    ConstantArray[
        {
            Cell @ BoxData @ FormBox[
                TemplateBox[ <| "input" -> "x^2", "state" -> "Boxes" |>, "TeXAssistantTemplate" ],
                TraditionalForm
            ]
        },
        2
    ],
    SameTest -> MatchQ,
    TestID   -> "Math-TeX-Template-Without-Boxes@@Tests/FormattingMath.wlt:529,1-549,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*TeX Preprocessing*)

(* The TeX is preprocessed before it is parsed, and the template keeps the preprocessed TeX. Unicode characters are
   converted to TeX commands: *)
VerificationTest[
    mathItems[ "$$\[Alpha] + \[Beta]$$" ],
    { MathTeX[ "\\alpha + \\beta", "Boxes" ] },
    SameTest -> MatchQ,
    TestID   -> "Math-Preprocess-Unicode@@Tests/FormattingMath.wlt:557,1-562,2"
]

(* Other symbols with a TeX command are converted too. Characters without one are left as they are: *)
VerificationTest[
    mathItems /@ { "$$x \[TildeTilde] y$$", "$$\[Infinity]$$", "$$\:4e2d + x$$" },
    { { MathTeX[ "x \\approx y", "Boxes" ] }, { MathTeX[ "\\infty", "Boxes" ] }, { MathTeX[ "\:4e2d + x", "Boxes" ] } },
    SameTest -> MatchQ,
    TestID   -> "Math-Preprocess-Unicode-Other@@Tests/FormattingMath.wlt:565,1-570,2"
]

(* Commas are removed from numbers with thousands separators: *)
VerificationTest[
    mathItems[ "$$100,000 + x$$" ],
    { MathTeX[ "100000 + x", "Boxes" ] },
    SameTest -> MatchQ,
    TestID   -> "Math-Preprocess-Thousands@@Tests/FormattingMath.wlt:573,1-578,2"
]

(* Ordinal and text superscripts get the braces and \text they need: *)
VerificationTest[
    mathItems /@ { "$$1^{st}$$", "$$x^\\text{th}$$" },
    { { MathTeX[ "1^{\\text{st}}", "Boxes" ] }, { MathTeX[ "x^{\\text{th}}", "Boxes" ] } },
    SameTest -> MatchQ,
    TestID   -> "Math-Preprocess-Superscripts@@Tests/FormattingMath.wlt:581,1-586,2"
]

(* If the TeX can't be parsed, math symbols inside \text{...} are put in $...$ and it's parsed again. The template
   keeps the TeX from the second attempt: *)
VerificationTest[
    mathItems[ "$$\\text{if \\alpha > 0}$$" ],
    { MathTeX[ "\\text{if $\\alpha$ > 0}", "Boxes" ] },
    SameTest -> MatchQ,
    TestID   -> "Math-Preprocess-Text-Retry@@Tests/FormattingMath.wlt:590,1-595,2"
]

(* If the second attempt fails too, the template keeps the TeX from the first attempt: *)
VerificationTest[
    mathItems[ "$$\\text{\\alpha}\\frac{a$$" ],
    { MathTeX[ "\\text{\\alpha}\\frac{a", "Error" ] },
    SameTest -> MatchQ,
    TestID   -> "Math-Preprocess-Text-Retry-Fails@@Tests/FormattingMath.wlt:598,1-603,2"
]

(* \text{...} that parses is left alone: *)
VerificationTest[
    mathItems /@ { "$$\\text{if } \\alpha > 0$$", "$$\\textbf{v} = 1$$" },
    { { MathTeX[ "\\text{if } \\alpha > 0", "Boxes" ] }, { MathTeX[ "\\textbf{v} = 1", "Boxes" ] } },
    SameTest -> MatchQ,
    TestID   -> "Math-Preprocess-Text-Valid@@Tests/FormattingMath.wlt:606,1-611,2"
]

(* HTML entities are decoded before math is found: *)
VerificationTest[
    mathItems[ "$$a &lt; b$$" ],
    { MathTeX[ "a < b", "Boxes" ] },
    SameTest -> MatchQ,
    TestID   -> "Math-HTML-Entities@@Tests/FormattingMath.wlt:614,1-619,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Invalid TeX*)

(* TeX that can't be parsed is still a math cell, in the "Error" state, and keeps its TeX: *)
VerificationTest[
    FormatMarkdown[ "$$\\frac{a}{b$$" ],
    {
        Cell @ BoxData @ FormBox[
            TemplateBox[
                KeyValuePattern @ {
                    "boxes" -> InterpretationBox[ "", _Failure ],
                    "input" -> "\\frac{a}{b",
                    "state" -> "Error"
                },
                "TeXAssistantTemplate"
            ],
            TraditionalForm
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Invalid-Unbalanced@@Tests/FormattingMath.wlt:626,1-643,2"
]

(* While streaming, the error boxes are shown: *)
VerificationTest[
    FormatMarkdown[ "$$\\frac{a}{b$$", "Streaming" ],
    {
        Cell @ BoxData @ FormBox[
            StyleBox[ InterpretationBox[ "", _Failure ], "TeXAssistantBoxes" ],
            TraditionalForm
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Invalid-Unbalanced-Streaming@@Tests/FormattingMath.wlt:646,1-656,2"
]

(* Unknown commands and blank lines. Whether an unknown command is an error is up to the TeX parser: *)
VerificationTest[
    mathItems /@ { "$\\notacommand$", "$$\\foo{x}$$", "$$a\n\nb$$" },
    {
        { MathTeX[ "\\notacommand", "Error" ] },
        { MathTeX[ "\\foo{x}", _String ] },
        { MathTeX[ "a\n\nb", "Error" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Invalid-Unknown-Command@@Tests/FormattingMath.wlt:659,1-668,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Escapes In Math*)

(* Markdown escapes inside math belong to the TeX, so they reach the TeX parser with their backslash (see also the
   TeX-Escaped-* tests in Formatting.wlt): *)
VerificationTest[
    mathItems /@ {
        "$$a \\* b$$",
        "$$\\|x\\|$$",
        "$$a \\\\ b$$",
        "$$\\$100$$",
        "$$a\\_b$$",
        "\\(\\$5\\)",
        "\\(a\\_b\\)",
        "\\[ \\$5 \\]",
        "\\[ a \\\\ b \\]"
    },
    {
        { MathTeX[ "a \\* b", "Boxes" ] },
        { MathTeX[ "\\|x\\|", "Boxes" ] },
        { MathTeX[ "a \\\\ b", "Boxes" ] },
        { MathTeX[ "\\$100", "Boxes" ] },
        { MathTeX[ "a\\_b", "Boxes" ] },
        { MathTeX[ "\\$5", "Boxes" ] },
        { MathTeX[ "a\\_b", "Boxes" ] },
        { MathTeX[ "\\$5", "Boxes" ] },
        { MathTeX[ "a \\\\ b", "Boxes" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Escapes-Kept@@Tests/FormattingMath.wlt:676,1-701,2"
]

(* Backslashes that are not markdown escapes are kept too: *)
VerificationTest[
    mathItems /@ { "$$\\{a, b\\}$$", "$$\\{ x \\mid x > 0 \\}$$", "$$\\int_0^1 x\\,dx$$" },
    {
        { MathTeX[ "\\{a, b\\}", "Boxes" ] },
        { MathTeX[ "\\{ x \\mid x > 0 \\}", "Boxes" ] },
        { MathTeX[ "\\int_0^1 x\\,dx", "Boxes" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Escapes-Non-Markdown@@Tests/FormattingMath.wlt:704,1-713,2"
]

(* TeX line breaks "\\" in a matrix: *)
VerificationTest[
    mathItems[ "$$\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}$$" ],
    { MathTeX[ "\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}", "Boxes" ] },
    SameTest -> MatchQ,
    TestID   -> "Math-Escapes-Matrix@@Tests/FormattingMath.wlt:716,1-721,2"
]

(* In the same text, escapes outside of math are removed, while those inside are kept: *)
VerificationTest[
    mathItems /@ { "Use \\$ and $$\\$x$$", "Cost \\$5 and \\(x^2\\)" },
    {
        { "Use $ and ", MathTeX[ "\\$x", "Boxes" ] },
        { "Cost $5 and ", MathTeX[ "x^2", "Boxes" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Escapes-Outside-Removed@@Tests/FormattingMath.wlt:724,1-732,2"
]

(* The same while streaming: *)
VerificationTest[
    mathItems[ #, "Streaming" ] & /@ { "$$\\$5$$", "Cost \\$5 and $x^2$" },
    {
        { MathTeXStreaming[ FormBox[ "$5", TraditionalForm ] ] },
        { "Cost $5 and ", MathTeXStreaming[ FormBox[ SuperscriptBox[ StyleBox[ "x", "TI" ], "2" ], TraditionalForm ] ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Escapes-Streaming@@Tests/FormattingMath.wlt:735,1-743,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Bracket Delimiters*)

(* "\[" is also a markdown escape, so text with \[...\] is formatted with the rules for escaped text. There, \[...\]
   is only math when it has whitespace (or the start/end of the text) on both sides: *)
VerificationTest[
    mathItems /@ { "\\[x^2\\]", "\\[\nx^2\n\\]", "\\[\\frac{1}{2}\\]" },
    { { MathTeX[ "x^2", "Boxes" ] }, { MathTeX[ "x^2", "Boxes" ] }, { MathTeX[ "\\frac{1}{2}", "Boxes" ] } },
    SameTest -> MatchQ,
    TestID   -> "Math-Brackets-Whitespace-Delimited@@Tests/FormattingMath.wlt:751,1-756,2"
]

(* Text around whitespace-delimited \[...\] stays in order. (The whitespace next to the math is not checked here: it is
   currently removed, which is a known issue.) *)
VerificationTest[
    mathItems /@ { "Before \\[x^2\\] after", "Here:\n\n\\[x^2\\]\n\nmore" },
    {
        { mathTrimmedText[ "Before" ], MathTeX[ "x^2", "Boxes" ], mathTrimmedText[ "after" ] },
        { mathTrimmedText[ "Here:" ], MathTeX[ "x^2", "Boxes" ], mathTrimmedText[ "more" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Brackets-Surrounding-Text@@Tests/FormattingMath.wlt:760,1-768,2"
]

(* Without whitespace around them, "\[" and "\]" are escaped brackets: *)
VerificationTest[
    mathItems /@ { "items\\[0\\] and items\\[1\\]", "a\\[x^2\\]b" },
    { { "items[0] and items[1]" }, { "a[x^2]b" } },
    SameTest -> MatchQ,
    TestID   -> "Math-Brackets-Not-Delimited@@Tests/FormattingMath.wlt:771,1-776,2"
]

(* Whitespace-delimited \[...\] while streaming: *)
VerificationTest[
    mathItems[ "\\[\\alpha\\]", "Streaming" ],
    { MathTeXStreaming[ FormBox[ "\[Alpha]", TraditionalForm ] ] },
    SameTest -> MatchQ,
    TestID   -> "Math-Brackets-Streaming@@Tests/FormattingMath.wlt:779,1-784,2"
]

(* The rules for text without escapes also have a \[...\] rule, which doesn't need whitespace. It is only reached when
   the backslash comes from an HTML entity, since those are decoded after the check for escapes (or in a table inside a
   code fence, which is not tested here): *)
VerificationTest[
    mathItems /@ { "a&#92;[x&#92;]b", "a &#92;[x&#92;] b", "- a&#92;[x&#92;]b" },
    {
        { "a", MathTeX[ "x", "Boxes" ], "b" },
        { "a ", MathTeX[ "x", "Boxes" ], " b" },
        {
            Cell[
                TextData @ { StyleBox[ "\[Bullet]", ___ ], " a", MathTeX[ "x", "Boxes" ], "b" },
                "InlineItem"
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Brackets-Unescaped-Rules@@Tests/FormattingMath.wlt:789,1-803,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Math In Other Content*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Lists*)

VerificationTest[
    mathItems[ "- $x^2$ item" ],
    { Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " ", MathTeX[ "x^2", "Boxes" ], " item" }, "InlineItem" ] },
    SameTest -> MatchQ,
    TestID   -> "Math-List-Item@@Tests/FormattingMath.wlt:813,1-818,2"
]

(* Inline and display math in items and sub-items: *)
VerificationTest[
    mathItems[ "- item with $\\alpha$ and $$\\beta$$\n  - sub $y$" ],
    {
        Cell[
            TextData @ {
                StyleBox[ "\[Bullet]", ___ ],
                " item with ",
                MathTeX[ "\\alpha", "Boxes" ],
                " and ",
                MathTeX[ "\\beta", "Boxes" ]
            },
            "InlineItem"
        ],
        "\n",
        Cell[ TextData @ { "  ", StyleBox[ "\[Bullet]", ___ ], " sub ", MathTeX[ "y", "Boxes" ] }, "InlineSubitem" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Math-List-Subitem@@Tests/FormattingMath.wlt:821,1-839,2"
]

(* \(...\) in a list item: *)
VerificationTest[
    mathItems[ "- item \\(x\\) end" ],
    { Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " item ", MathTeX[ "x", "Boxes" ], " end" }, "InlineItem" ] },
    SameTest -> MatchQ,
    TestID   -> "Math-List-Parentheses@@Tests/FormattingMath.wlt:842,1-847,2"
]

(* Math in a list item while streaming: *)
VerificationTest[
    mathItems[ "- $x$", "Streaming" ],
    {
        Cell[
            TextData @ {
                StyleBox[ "\[Bullet]", ___ ],
                " ",
                MathTeXStreaming[ FormBox[ StyleBox[ "x", "TI" ], TraditionalForm ] ]
            },
            "InlineItem"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Math-List-Item-Streaming@@Tests/FormattingMath.wlt:850,1-864,2"
]

(* Numbered lists are plain text, with math formatted as usual: *)
VerificationTest[
    mathItems[ "1. Step one: $x = 1$\n2. Step two: $$y = 2$$" ],
    { "1. Step one: ", MathTeX[ "x = 1", "Boxes" ], "\n2. Step two: ", MathTeX[ "y = 2", "Boxes" ] },
    SameTest -> MatchQ,
    TestID   -> "Math-Numbered-List@@Tests/FormattingMath.wlt:867,1-872,2"
]

(* In list items, emphasis around math alone applies to the math cell: *)
VerificationTest[
    mathItems /@ { "- **$x^2$** item", "- *$x$* item" },
    {
        {
            Cell[
                TextData @ {
                    StyleBox[ "\[Bullet]", ___ ],
                    " ",
                    MathTeX[ "x^2", "Boxes", FontWeight -> Bold ],
                    " item"
                },
                "InlineItem"
            ]
        },
        {
            Cell[
                TextData @ { StyleBox[ "\[Bullet]", ___ ], " ", MathTeX[ "x", "Boxes", FontSlant -> Italic ], " item" },
                "InlineItem"
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-List-Emphasis@@Tests/FormattingMath.wlt:875,1-898,2"
]

(* Display math between list items: *)
VerificationTest[
    mathItems[ "- a\n$$x$$\n- b" ],
    {
        Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " a" }, "InlineItem" ],
        "\n",
        MathTeX[ "x", "Boxes" ],
        "\n",
        Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " b" }, "InlineItem" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Between-List-Items@@Tests/FormattingMath.wlt:901,1-912,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Headings*)

VerificationTest[
    mathItems /@ { "## $x^2$ heading", "# Title $\\pi$", "#### $x$ sub" },
    {
        {
            Cell[
                BoxData @ PaneBox[
                    StyleBox[
                        Cell[ TextData @ { MathTeX[ "x^2", "Boxes" ], " heading" }, ___ ],
                        "Section",
                        ___,
                        FontSize -> 22,
                        ___
                    ],
                    ___
                ],
                "InlineSection",
                ___
            ]
        },
        {
            Cell[
                BoxData @ PaneBox[
                    StyleBox[
                        Cell[ TextData @ { "Title ", MathTeX[ "\\pi", "Boxes" ] }, ___ ],
                        "Title",
                        ___,
                        FontSize -> 26,
                        ___
                    ],
                    ___
                ],
                "InlineSection",
                ___
            ]
        },
        {
            Cell[
                BoxData @ PaneBox[
                    StyleBox[ Cell[ TextData @ { MathTeX[ "x", "Boxes" ], " sub" }, ___ ], "Subsubsection", ___ ],
                    ___
                ],
                "InlineSection",
                ___
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Heading@@Tests/FormattingMath.wlt:918,1-966,2"
]

(* Emphasis around math alone in a heading applies to the math cell: *)
VerificationTest[
    mathItems[ "## **$x$**" ],
    {
        Cell[
            BoxData @ PaneBox[
                StyleBox[ Cell[ TextData @ { MathTeX[ "x", "Boxes", FontWeight -> Bold ] }, ___ ], "Section", ___ ],
                ___
            ],
            "InlineSection",
            ___
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Heading-Emphasis@@Tests/FormattingMath.wlt:969,1-983,2"
]

(* A heading with an escape outside its math: *)
VerificationTest[
    mathItems[ "## Cost \\$5 and $x^2$" ],
    {
        Cell[
            BoxData @ PaneBox[
                StyleBox[ Cell[ TextData @ { "Cost $5 and ", MathTeX[ "x^2", "Boxes" ] }, ___ ], "Section", ___ ],
                ___
            ],
            "InlineSection",
            ___
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Heading-Escaped@@Tests/FormattingMath.wlt:986,1-1000,2"
]

(* Math in a heading while streaming: *)
VerificationTest[
    mathItems[ "## $x$", "Streaming" ],
    {
        Cell[
            BoxData @ PaneBox[
                StyleBox[
                    Cell[ TextData @ { MathTeXStreaming[ FormBox[ StyleBox[ "x", "TI" ], TraditionalForm ] ] }, ___ ],
                    "Section",
                    ___
                ],
                ___
            ],
            "InlineSection",
            ___
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Heading-Streaming@@Tests/FormattingMath.wlt:1003,1-1021,2"
]

(* Display math next to a heading: *)
VerificationTest[
    mathItems /@ { "$$x^2$$\n## Heading", "## Heading\n$$x^2$$" },
    {
        { MathTeX[ "x^2", "Boxes" ], "\n", Cell[ _, "InlineSection", ___ ] },
        { Cell[ _, "InlineSection", ___ ], "\n", MathTeX[ "x^2", "Boxes" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Next-To-Heading@@Tests/FormattingMath.wlt:1024,1-1032,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tables*)

(* Math in table cells, including the header row: *)
VerificationTest[
    Map[
        FirstCase[
            mathItems @ #,
            Cell[ BoxData[ b_ ], "TextTableForm", ___ ] :>
                FirstCase[ b, GridBox[ rows_, ___ ] :> rows, $Failed, Infinity ],
            $Failed
        ] &,
        {
            "| a | b |\n|---|---|\n| $z^2$ | $\\frac{1}{2}$ |",
            "| $x$ | b |\n|---|---|\n| 1 | $y^2$ |"
        }
    ],
    {
        { { _, _ }, { MathTeX[ "z^2", "Boxes" ], MathTeX[ "\\frac{1}{2}", "Boxes" ] } },
        { { TagBox[ MathTeX[ "x", "Boxes" ], ___ ], _ }, { _, MathTeX[ "y^2", "Boxes" ] } }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Table@@Tests/FormattingMath.wlt:1039,1-1058,2"
]

(* An escaped "|" in table math doesn't split the cell, and is a TeX \| in the math: *)
VerificationTest[
    FirstCase[
        mathItems[ "| a | b |\n|---|---|\n| $$\\|x\\|$$ | 1 |" ],
        GridBox[ rows_, ___ ] :> rows,
        $Failed,
        Infinity
    ],
    { { _, _ }, { MathTeX[ "\\|x\\|", "Boxes" ], _ } },
    SameTest -> MatchQ,
    TestID   -> "Math-Table-Escaped-Pipe@@Tests/FormattingMath.wlt:1061,1-1071,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Block Quotes*)

VerificationTest[
    FirstCase[
        mathItems @ #,
        Cell[ BoxData @ GridBox[ { { PaneBox[ Cell[ TextData[ t_ ], ___ ], ___ ] } }, ___ ], "BlockQuote", ___ ] :> t,
        $Failed
    ] & /@ { "> quote with $x^2$ math", "> $$x$$\n> more $y$" },
    {
        { "quote with ", MathTeX[ "x^2", "Boxes" ], " math" },
        { MathTeX[ "x", "Boxes" ], "\nmore ", MathTeX[ "y", "Boxes" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Block-Quote@@Tests/FormattingMath.wlt:1077,1-1089,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Code*)

(* Math next to inline code: *)
VerificationTest[
    mathItems /@ { "`x` and $x^2$", "$x^2$`code`", "Use `Sin` and $$Sin$$" },
    {
        { StyleBox[ "x", "TI" ], " and ", MathTeX[ "x^2", "Boxes" ] },
        { MathTeX[ "x^2", "Boxes" ], StyleBox[ "code", "TI" ] },
        {
            "Use ",
            Cell @ BoxData @ TemplateBox[ { "Sin", "paclet:ref/Sin", _ }, "TextRefLink" ],
            " and ",
            Cell @ BoxData @ TemplateBox[ { "Sin", "paclet:ref/Sin", _ }, "TextRefLink" ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Next-To-Inline-Code@@Tests/FormattingMath.wlt:1096,1-1110,2"
]

(* Math delimiters inside inline code are code: *)
VerificationTest[
    mathItems /@ { "`$x^2$`", "``$$x$$``", "- `$x$` item" },
    {
        { Cell[ BoxData @ TemplateBox[ { Cell[ "$x^2$", ___ ] }, "ChatCodeInlineTemplate" ], "ChatCodeActive" ] },
        { Cell[ BoxData @ TemplateBox[ { Cell[ "$$x$$", ___ ] }, "ChatCodeInlineTemplate" ], "ChatCodeActive" ] },
        {
            Cell[
                TextData @ {
                    StyleBox[ "\[Bullet]", ___ ],
                    " ",
                    Cell[ BoxData @ TemplateBox[ { Cell[ "$x$", ___ ] }, "ChatCodeInlineTemplate" ], "ChatCodeActive" ],
                    " item"
                },
                "InlineItem"
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-In-Inline-Code@@Tests/FormattingMath.wlt:1113,1-1132,2"
]

(* Math delimiters inside code blocks are code: *)
VerificationTest[
    mathItems[ "```\n$x^2$\n```" ],
    {
        Cell[
            BoxData @ TemplateBox[ { Cell[ "$x^2$", "ChatPreformatted", ___ ], "" }, "ChatCodeBlockTemplate" ],
            "ChatCodeBlock"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Math-In-Code-Block@@Tests/FormattingMath.wlt:1135,1-1145,2"
]

(* Math next to code blocks, with and without escapes: *)
VerificationTest[
    mathItems /@ {
        "Before\n\n```wl\n1+1\n```\n\n$$x^2$$",
        "$$x^2$$\n\n```wl\n1+1\n```",
        "$$\\$x$$\n\n```wl\n1\n```",
        "Text \\$5 then $$y$$\n\n```wl\n1\n```"
    },
    {
        { "Before\n", Cell[ _, "ChatCodeBlock" ], "\n", MathTeX[ "x^2", "Boxes" ] },
        { MathTeX[ "x^2", "Boxes" ], "\n", Cell[ _, "ChatCodeBlock" ] },
        { MathTeX[ "\\$x", "Boxes" ], "\n", Cell[ _, "ChatCodeBlock" ] },
        { "Text $5 then ", MathTeX[ "y", "Boxes" ], "\n", Cell[ _, "ChatCodeBlock" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Next-To-Code-Block@@Tests/FormattingMath.wlt:1148,1-1163,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Other*)

(* Math in thoughts is formatted the same way: *)
VerificationTest[
    With[ { items = mathItems[ "<think>\nThe value $x^2$ here\n</think>\nAnswer $$y$$" ] },
        {
            FirstCase[ items, TemplateBox[ { TextData[ t_ ], ___ }, "ThoughtsOpener", ___ ] :> t, $Failed, Infinity ],
            Last @ items
        }
    ],
    { { "The value ", MathTeX[ "x^2", "Boxes" ], " here" }, MathTeX[ "y", "Boxes" ] },
    SameTest -> MatchQ,
    TestID   -> "Math-In-Thoughts@@Tests/FormattingMath.wlt:1170,1-1180,2"
]

(* Thoughts with escapes use the rules for escaped text, including whitespace-delimited \[...\]: *)
VerificationTest[
    FirstCase[
        mathItems @ #,
        TemplateBox[ { TextData[ t_ ], ___ }, "ThoughtsOpener", ___ ] :> t,
        $Failed,
        Infinity
    ] & /@ { "<think>\n\\[x^2\\]\n</think>\nAnswer", "<think>\nCost \\$5, $$\\$x$$\n</think>\nAnswer" },
    { { MathTeX[ "x^2", "Boxes" ] }, { "Cost $5, ", MathTeX[ "\\$x", "Boxes" ] } },
    SameTest -> MatchQ,
    TestID   -> "Math-In-Thoughts-Escaped@@Tests/FormattingMath.wlt:1183,1-1193,2"
]

(* The TeX text commands \textbf and \textit are also recognized outside of math: *)
VerificationTest[
    mathItems /@ { "Some \\textbf{bold} and \\textit{italic} text", "- Some \\textbf{bold} $x$" },
    {
        {
            "Some ",
            StyleBox[ "bold", FontWeight -> Bold ],
            " and ",
            StyleBox[ "italic", FontSlant -> Italic ],
            " text"
        },
        {
            Cell[
                TextData @ {
                    StyleBox[ "\[Bullet]", ___ ],
                    " Some ",
                    StyleBox[ "bold", FontWeight -> Bold ],
                    " ",
                    MathTeX[ "x", "Boxes" ]
                },
                "InlineItem"
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Math-TeX-Text-Commands@@Tests/FormattingMath.wlt:1196,1-1221,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Serialization*)

(* All math delimiters serialize as $$...$$ (see also the TeX-Serialization-* tests in Formatting.wlt): *)
VerificationTest[
    MarkdownRoundTrip /@ { "$$x^2$$", "$x^2$", "\\(x^2\\)", "\\[x^2\\]", "\\[\\alpha\\]" },
    { "$$x^2$$", "$$x^2$$", "$$x^2$$", "$$x^2$$", "$$\\alpha$$" },
    SameTest -> MatchQ,
    TestID   -> "Math-Serialization-Delimiters@@Tests/FormattingMath.wlt:1228,1-1233,2"
]

(* Inline math in text: *)
VerificationTest[
    MarkdownRoundTrip /@ { "The $$\\sqrt{2}$$ is irrational", "Let $x$ be", "$x$ $y$" },
    { "The $$\\sqrt{2}$$ is irrational", "Let $$x$$ be", "$$x$$ $$y$$" },
    SameTest -> MatchQ,
    TestID   -> "Math-Serialization-Inline@@Tests/FormattingMath.wlt:1236,1-1241,2"
]

(* Multi-line math keeps its inner line breaks; the whitespace at its ends is trimmed: *)
VerificationTest[
    MarkdownRoundTrip /@ {
        "$$x\n+y$$",
        "The equation $$\n\\int_0^1 f(x)\\,dx\n$$ is shown",
        "$$\n\\begin{aligned}\na &= b \\\\\n&= c\n\\end{aligned}\n$$"
    },
    {
        "$$x\n+y$$",
        "The equation $$\\int_0^1 f(x)\\,dx$$ is shown",
        "$$\\begin{aligned}\na &= b \\\\\n&= c\n\\end{aligned}$$"
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Serialization-Multiline@@Tests/FormattingMath.wlt:1244,1-1257,2"
]

(* Escapes in the math are kept: *)
VerificationTest[
    MarkdownRoundTrip /@ {
        "$$\\$5$$",
        "$$a \\_ b$$",
        "\\(\\$5\\)",
        "$$\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}$$"
    },
    { "$$\\$5$$", "$$a \\_ b$$", "$$\\$5$$", "$$\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}$$" },
    SameTest -> MatchQ,
    TestID   -> "Math-Serialization-Escapes@@Tests/FormattingMath.wlt:1260,1-1270,2"
]

(* Math that couldn't be parsed serializes to its TeX: *)
VerificationTest[
    MarkdownRoundTrip /@ { "$$\\frac{a}{b$$", "$\\notacommand$" },
    { "$$\\frac{a}{b$$", "$$\\notacommand$$" },
    SameTest -> MatchQ,
    TestID   -> "Math-Serialization-Invalid@@Tests/FormattingMath.wlt:1273,1-1278,2"
]

(* Numbers serialize as text, and System symbol names as links: *)
VerificationTest[
    MarkdownRoundTrip /@ { "$$1,000$$", "Use $$Sin$$ and $Plot$" },
    { "1,000", "Use [Sin](paclet:ref/Sin) and [Plot](paclet:ref/Plot)" },
    SameTest -> MatchQ,
    TestID   -> "Math-Serialization-Numeric-And-Links@@Tests/FormattingMath.wlt:1281,1-1286,2"
]

(* The preprocessed TeX is what's serialized: *)
VerificationTest[
    MarkdownRoundTrip /@ { "$$\[Alpha] + \[Beta]$$", "$$100,000 + x$$", "$$\\text{if \\alpha > 0}$$" },
    { "$$\\alpha + \\beta$$", "$$100000 + x$$", "$$\\text{if $\\alpha$ > 0}$$" },
    SameTest -> MatchQ,
    TestID   -> "Math-Serialization-Preprocessed@@Tests/FormattingMath.wlt:1289,1-1294,2"
]

(* Dollars that are not math are escaped: *)
VerificationTest[
    MarkdownRoundTrip /@ { "costs $5 and $10", "$5 and $x$", "Price: \\$5 - \\$10" },
    { "costs \\$5 and \\$10", "\\$5 and $$x$$", "Price: \\$5 - \\$10" },
    SameTest -> MatchQ,
    TestID   -> "Math-Serialization-Dollar-Amounts@@Tests/FormattingMath.wlt:1297,1-1302,2"
]

(* Math cells right next to each other are joined into one $$...$$ with a space: *)
VerificationTest[
    MarkdownRoundTrip /@ { "$x$$y$", "\\(a\\)\\(b\\)" },
    { "$$x y$$", "$$a b$$" },
    SameTest -> MatchQ,
    TestID   -> "Math-Serialization-Adjacent@@Tests/FormattingMath.wlt:1305,1-1310,2"
]

(* Math in other content: *)
VerificationTest[
    MarkdownRoundTrip /@ {
        "- $x^2$ item",
        "- item with $\\alpha$ and $$\\beta$$\n  - sub $y$",
        "- **$x^2$** item",
        "1. Step one: $x = 1$\n2. Step two: $$y = 2$$",
        "## $x^2$ heading",
        "## Cost \\$5 and $x^2$",
        "> quote with $x^2$ math",
        "> $$x$$\n> more $y$"
    },
    {
        "* $$x^2$$ item",
        "* item with $$\\alpha$$ and $$\\beta$$\n  * sub $$y$$",
        "* **$$x^2$$** item",
        "1. Step one: $$x = 1$$\n2. Step two: $$y = 2$$",
        "## $$x^2$$ heading",
        "## Cost \\$5 and $$x^2$$",
        "> quote with $$x^2$$ math",
        "> $$x$$\n> more $$y$$"
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Serialization-Nested@@Tests/FormattingMath.wlt:1313,1-1336,2"
]

(* Math in table cells: *)
VerificationTest[
    MarkdownRoundTrip[ "| $x$ | b |\n|---|---|\n| 1 | $y^2$ |" ],
    _String? (StringContainsQ[ #, "| $$x$$ |" ] && StringContainsQ[ #, "| $$y^2$$ |" ] &),
    SameTest -> MatchQ,
    TestID   -> "Math-Serialization-Table@@Tests/FormattingMath.wlt:1339,1-1344,2"
]

(* Display math on its own line stays on its own line: *)
VerificationTest[
    MarkdownRoundTrip /@ { "Line one\n$$x$$\nLine two", "Here:\n\n$$x^2$$\n\nmore" },
    {
        _String? (StringMatchQ[ "Line one" ~~ " "... ~~ "\n" ~~ "$$x$$" ~~ "\n" ~~ "Line two" ]),
        _String? (StringMatchQ[ "Here:" ~~ " "... ~~ ("\n"|"\n\n") ~~ "$$x^2$$" ~~ ("\n"|"\n\n") ~~ "more" ])
    },
    SameTest -> MatchQ,
    TestID   -> "Math-Serialization-Display-Lines@@Tests/FormattingMath.wlt:1347,1-1355,2"
]

(* Math that fell back to inline code serializes as inline code: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`makeTeXBoxes = $Failed & }, MarkdownRoundTrip[ "Then $$x^2$$ end" ] ],
    "Then ``x^2`` end",
    SameTest -> MatchQ,
    TestID   -> "Math-Serialization-Fallback@@Tests/FormattingMath.wlt:1358,1-1363,2"
]

(* :!CodeAnalysis::EndBlock:: *)
