(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/FormattingEscapes.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/FormattingEscapes.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* Characterization tests for markdown backslash escapes. The characters \ ` $ * _ # | [ ] can be escaped with a
   backslash. When the response contains any of these escapes, reformatTextData0 takes a separate path
   (reformatTextDataEscaped):
   1. The raw text is split with $textDataFormatRulesNoMarkdownUnescape, which only splits out the parts that have to
      keep their raw text: think tags, speech input, whitespace-delimited \[...\] math, code blocks and tool calls.
   2. Bad tool calls are discarded, and the whitespace next to tool calls is split out (splitToolCallSpacing).
   3. Each remaining text part has its escapes replaced by private-use placeholders, is formatted on its own with the
      normal rules, and then the placeholders are turned back into the plain characters (or into TeX escapes in math).
   Text that ends with a blank line before a code block keeps its line break (textBeforeCodeBlock).
   Many tests below compare a document that contains an escaped dollar sign "\$" with the same document using a plain
   "$" (both display "$"), since the two paths should give the same visible result. *)
VerificationTest[
    ClearAll[
        escPair, escSameQ, escCodeBlock, escToolCall, escItem, escSubitem, escSection, escInlineCode, escRefLink,
        escLink, escTeX, escQuote, escThoughts, escDelimiter, escPreformatted, escDiscardedContent, escReformat,
        escToolCallText, escToolCallText2
    ];

    (* Formats the same document twice, with "{$}" replaced by an escaped dollar sign "\$" and by a plain "$". Both
       display "$", but only the first one contains an escape, so it is formatted by the escaped path while the second
       one is formatted by the normal path: *)
    escPair[ md_String, status_String: "Finished" ] := {
        FormatMarkdown[ StringReplace[ md, "{$}" -> "\\$" ], status ],
        FormatMarkdown[ StringReplace[ md, "{$}" -> "$"   ], status ]
    };

    (* Whether both paths give the same result, apart from invisible differences (e.g. " \n" versus "\n"): *)
    escSameQ[ md_String, status_String: "Finished" ] := SameQ @@ (NormalizeTextData /@ escPair[ md, status ]);

    (* A code block, with the language name that is shown in its frame: *)
    escCodeBlock[ lang_ ] := Cell[ BoxData @ TemplateBox[ { _, lang }, "ChatCodeBlockTemplate" ], "ChatCodeBlock" ];

    escToolCall  = Cell[ _, "InlineToolCall", ___ ];
    escDelimiter = Cell[ _, "MarkdownDelimiter", ___ ];

    (* Bullet list items (top level and nested), as they are after NormalizeTextData (which joins the strings in the
       item, so the tests don't depend on how the item text is split): *)
    escItem[ content___ ] :=
        Cell[ TextData @ NormalizeTextData @ { StyleBox[ "\[Bullet]", ___ ], " ", content }, "InlineItem" ];
    escSubitem[ ws_String, content___ ] :=
        Cell[ TextData @ NormalizeTextData @ { ws, StyleBox[ "\[Bullet]", ___ ], " ", content }, "InlineSubitem" ];

    (* A heading with its section style and font size: *)
    escSection[ content_, style_String, size_ ] := Cell[
        BoxData @ PaneBox[
            StyleBox[
                content,
                style,
                OrderlessPatternSequence[ CellFrame -> 0, FontSize -> size, ShowStringCharacters -> False ]
            ],
            ImageMargins -> _
        ],
        "InlineSection",
        Background -> None
    ];

    (* Inline code shown verbatim: *)
    escInlineCode[ code_ ] := Cell[
        BoxData @ TemplateBox[ { Cell[ code, Background -> None ] }, "ChatCodeInlineTemplate" ],
        "ChatCodeActive"
    ];

    (* A documentation link: *)
    escRefLink[ name_String ] := Cell @ BoxData @ TemplateBox[ { name, "paclet:ref/" <> name, _String }, "TextRefLink" ];

    (* A web link: *)
    escLink[ label_, url_String ] := ButtonBox[
        label,
        OrderlessPatternSequence[ BaseStyle -> "Hyperlink", ButtonData -> { URL @ url, None }, ButtonNote -> url ]
    ];

    (* Math, with the TeX that is passed to the TeX parser (and used for serialization): *)
    escTeX[ input_String ] := Cell @ BoxData @ FormBox[
        TemplateBox[ KeyValuePattern @ { "input" -> input, "state" -> "Boxes" }, "TeXAssistantTemplate" ],
        TraditionalForm
    ];

    escQuote[ content_ ] := Cell[ BoxData @ GridBox[ { { PaneBox[ content, ___ ] } }, ___ ], "BlockQuote", ___ ];

    (* A finished think tag, with its formatted content and its serialization metadata: *)
    escThoughts[ content_, meta_ ] :=
        Cell[ BoxData @ TemplateBox[ { content, _, meta }, "ThoughtsOpener" ], "ThoughtsOpener", Background -> None ];

    (* The text of plain text code blocks (e.g. ```text): *)
    escPreformatted[ md_String ] :=
        Cases[ FormatMarkdown @ md, Cell[ code_String, "ChatPreformatted", ___ ] :> code, Infinity ];

    (* The content of a "Discarded material" opener, which is compressed until it's viewed: *)
    escDiscardedContent[ items_ ] := FirstCase[
        items,
        HoldPattern @ BaseDecode[ b64_String ] :> BinaryDeserialize @ BaseDecode @ b64,
        $Failed,
        Infinity
    ];

    (* Formats the serialized output again: *)
    escReformat[ md_String ] := NormalizeTextData @ FormatMarkdown @ MarkdownRoundTrip @ md;

    (* Tool calls in the simple format and in the TOOLCALL format: *)
    escToolCallText  = "/wl\n1+1\n/exec\nRESULT\nOut[1]= 2\nENDRESULT(abc123)";
    escToolCallText2 = StringJoin[
        "TOOLCALL: wolfram_language_evaluator\n{\"code\":\"1+1\"}\nENDARGUMENTS\nENDTOOLCALL\n",
        "RESULT\n2\nENDRESULT(def456)"
    ];,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Escapes-Definitions@@Tests/FormattingEscapes.wlt:36,1-132,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Escapable Characters*)

(* Each escapable character is shown without its backslash: *)
VerificationTest[
    FormatMarkdown /@ {
        "a \\\\ b",
        "a \\` b",
        "a \\$ b",
        "a \\* b",
        "a \\_ b",
        "a \\# b",
        "a \\| b",
        "a \\[ b",
        "a \\] b"
    },
    {
        { "a \\ b" },
        { "a ` b" },
        { "a $ b" },
        { "a * b" },
        { "a _ b" },
        { "a # b" },
        { "a | b" },
        { "a [ b" },
        { "a ] b" }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Each-Character@@Tests/FormattingEscapes.wlt:139,1-164,2"
]

(* Escapes at the start or end of the response, and responses that are only escapes: *)
VerificationTest[
    FormatMarkdown /@ { "\\*start", "end\\*", "\\$", "\\\\", "\\*\\_\\#\\|\\`" },
    { { "*start" }, { "end*" }, { "$" }, { "\\" }, { "*_#|`" } },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Start-And-End@@Tests/FormattingEscapes.wlt:167,1-172,2"
]

(* Whitespace around the response is trimmed as usual, and line breaks between escaped characters are kept: *)
VerificationTest[
    FormatMarkdown /@ { "\n\n\\*\n\n", "  \\$5 text  ", "\\*\n\\*\n\\*", "\\# a\n\\# b" },
    { { "*" }, { "$5 text" }, { "*\n*\n*" }, { "# a\n# b" } },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Whitespace-And-Line-Breaks@@Tests/FormattingEscapes.wlt:175,1-180,2"
]

(* A backslash before anything else is not an escape and is shown as typed, with or without escapes elsewhere in the
   text: *)
VerificationTest[
    FormatMarkdown /@ {
        "a \\x b",
        "a \\ b",
        "trailing \\",
        "C:\\Users\\me",
        "Use \\n for a newline, \\$5",
        "a \\x b \\*"
    },
    {
        { "a \\x b" },
        { "a \\ b" },
        { "trailing \\" },
        { "C:\\Users\\me" },
        { "Use \\n for a newline, $5" },
        { "a \\x b *" }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Non-Escapable-Backslash@@Tests/FormattingEscapes.wlt:184,1-203,2"
]

(* Escapes are read from left to right, so an escaped backslash does not escape the character after it: *)
VerificationTest[
    FormatMarkdown /@ { "a\\\\*b*", "a\\\\\\*b*", "a \\\\\\\\ b", "\\\\\\\\\\\\" },
    {
        { "a\\", StyleBox[ "b", FontSlant -> Italic ] },
        { "a\\*b*" },
        { "a \\\\ b" },
        { "\\\\\\" }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Backslash-Pairs@@Tests/FormattingEscapes.wlt:206,1-216,2"
]

(* Non-ASCII text and tabs next to escapes are kept: *)
VerificationTest[
    FormatMarkdown /@ { "Unicode \:00fc \\* \:65e5\:672c \\$", "Tab\t\\*\tafter" },
    { { "Unicode \:00fc * \:65e5\:672c $" }, { "Tab\t*\tafter" } },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Unicode-And-Tabs@@Tests/FormattingEscapes.wlt:219,1-224,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Escapes and Emphasis*)

(* Escaped markers don't format anything: *)
VerificationTest[
    FormatMarkdown /@ {
        "\\*not italic\\*",
        "\\*\\*not bold\\*\\*",
        "\\_not italic\\_",
        "\\_\\_not bold\\_\\_",
        "a\\*b\\*c",
        "\\`not code\\` here"
    },
    {
        { "*not italic*" },
        { "**not bold**" },
        { "_not italic_" },
        { "__not bold__" },
        { "a*b*c" },
        { "`not code` here" }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Emphasis-Markers-Literal@@Tests/FormattingEscapes.wlt:231,1-250,2"
]

(* Escaped markers inside emphasis are part of the emphasized text: *)
VerificationTest[
    FormatMarkdown /@ {
        "**bold \\* star**",
        "*italic \\* star*",
        "__bold \\_ under__",
        "***both \\* star***",
        "**\\*\\*double\\*\\***",
        "~~struck \\* out~~"
    },
    {
        { StyleBox[ "bold * star", FontWeight -> Bold ] },
        { StyleBox[ "italic * star", FontSlant -> Italic ] },
        { StyleBox[ "bold _ under", FontWeight -> Bold ] },
        { StyleBox[ "both * star", OrderlessPatternSequence[ FontWeight -> Bold, FontSlant -> Italic ] ] },
        { StyleBox[ "**double**", FontWeight -> Bold ] },
        { StyleBox[ "struck * out", FontVariations -> { "StrikeThrough" -> True } ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Inside-Emphasis@@Tests/FormattingEscapes.wlt:253,1-272,2"
]

(* An escaped marker right next to an emphasis marker is a literal character inside or next to the emphasis: *)
VerificationTest[
    FormatMarkdown /@ { "**\\***", "*\\**", "**bold**\\*", "\\***bold**", "\\**italic*" },
    {
        { StyleBox[ "*", FontWeight -> Bold ] },
        { StyleBox[ "*", FontSlant -> Italic ] },
        { StyleBox[ "bold", FontWeight -> Bold ], "*" },
        { "*", StyleBox[ "bold", FontWeight -> Bold ] },
        { "*", StyleBox[ "italic", FontSlant -> Italic ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Adjacent-To-Emphasis@@Tests/FormattingEscapes.wlt:275,1-286,2"
]

(* Escaped underscores inside words are plain underscores, like unescaped ones: *)
VerificationTest[
    FormatMarkdown[ "Word\\_with\\_escapes and snake_case" ],
    { "Word_with_escapes and snake_case" },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Underscore-Intraword@@Tests/FormattingEscapes.wlt:289,1-294,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Escapes in Block Constructs*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Headings*)

(* Escapes in headings are unescaped, and other formatting in the same heading still works: *)
VerificationTest[
    FormatMarkdown /@ {
        "# Heading \\# with hash",
        "## Heading with \\*stars\\* and **bold**",
        "### `code` and \\$5",
        "#### Level four \\_x\\_"
    },
    {
        { escSection[ "\"Heading # with hash\"", "Title", 26 ] },
        {
            escSection[
                Cell[ TextData @ { "Heading with *stars* and ", StyleBox[ "bold", FontWeight -> Bold ] }, Background -> None ],
                "Section",
                22
            ]
        },
        { escSection[ Cell[ TextData @ { StyleBox[ "code", "TI" ], " and $5" }, Background -> None ], "Subsection", Inherited ] },
        { escSection[ "\"Level four _x_\"", "Subsubsection", Inherited ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Headings@@Tests/FormattingEscapes.wlt:305,1-326,2"
]

(* An escaped "#" at the start of a line is not a heading: *)
VerificationTest[
    FormatMarkdown /@ { "\\# Not a heading", "\\## Not a heading\n\nText", "Text\n\\# Not a heading" },
    { { "# Not a heading" }, { "## Not a heading\n\nText" }, { "Text\n# Not a heading" } },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Heading-Marker@@Tests/FormattingEscapes.wlt:329,1-334,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Lists*)

(* Escapes in list items are unescaped, including nested items: *)
VerificationTest[
    NormalizeTextData @ FormatMarkdown[ "- \\*not italic\\* item\n- *italic* item\n  - sub \\$5" ],
    {
        escItem[ "*not italic* item" ],
        "\n",
        escItem[ StyleBox[ "italic", FontSlant -> Italic ], " item" ],
        "\n",
        escSubitem[ "  ", "sub $5" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-List-Items@@Tests/FormattingEscapes.wlt:341,1-352,2"
]

(* An escaped "*" at the start of a line is not a bullet, but an escaped "*" after the bullet marker is item text.
   Numbered list text is unescaped too: *)
VerificationTest[
    NormalizeTextData @* FormatMarkdown /@ { "\\* not a bullet", "* \\* item", "1. one \\* star" },
    { { "* not a bullet" }, { escItem[ "* item" ] }, { "1. one * star" } },
    SameTest -> MatchQ,
    TestID   -> "Escapes-List-Markers@@Tests/FormattingEscapes.wlt:356,1-361,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Block Quotes*)

(* Escapes in block quotes are unescaped, also on later lines of the quote, and other formatting still works: *)
VerificationTest[
    FormatMarkdown /@ { "> \\*quoted\\* text and **bold**", "> quote \\* star", "> line \\* one\n> line \\_two" },
    {
        {
            escQuote @ Cell[
                TextData @ { "*quoted* text and ", StyleBox[ "bold", FontWeight -> Bold ] },
                Background -> None
            ]
        },
        { escQuote[ "\"quote * star\"" ] },
        { escQuote[ "\"line * one\\nline _two\"" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Block-Quote@@Tests/FormattingEscapes.wlt:368,1-382,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Delimiters*)

(* Escaped asterisks or underscores on their own line are not a delimiter, while an unescaped delimiter in escaped text
   still is: *)
VerificationTest[
    NormalizeTextData @* FormatMarkdown /@ {
        "Text\n\n\\*\\*\\*\n\nMore",
        "Text\n\n\\_\\_\\_\n\nMore",
        "Text\n\n***\n\nMore \\$5"
    },
    {
        { "Text\n\n***\n\nMore" },
        { "Text\n\n___\n\nMore" },
        { "Text\n", escDelimiter, "\nMore $5" }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Delimiter-Rows@@Tests/FormattingEscapes.wlt:390,1-403,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tables*)

(* Escapes in table cells are unescaped, and other formatting in the cells still works: *)
VerificationTest[
    Cases[
        FormatMarkdown[ "| a | b |\n|---|---|\n| \\$5 | x\\_y |\n| \\*star\\* | **bold** |" ],
        GridBox[ rows_, ___ ] :> rows,
        Infinity
    ],
    {
        {
            { TagBox[ "\"a\"", HoldForm ], TagBox[ "\"b\"", HoldForm ] },
            { "\"$5\"", "\"x_y\"" },
            { "\"*star*\"", StyleBox[ "bold", FontWeight -> Bold ] }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Table-Cells@@Tests/FormattingEscapes.wlt:410,1-425,2"
]

(* Tables, block quotes and delimiters after escaped text look the same as without escapes: *)
VerificationTest[
    escSameQ /@ {
        "Para {$}5\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nAfter",
        "Para {$}5\n\n> quote\n\nAfter",
        "Para {$}5\n\n---\n\nAfter"
    },
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Blocks-After-Escaped-Text@@Tests/FormattingEscapes.wlt:428,1-437,2"
]

(* The table keeps the line breaks around it: *)
VerificationTest[
    NormalizeTextData @ FormatMarkdown[ "Para \\$5\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nAfter" ],
    { "Para $5\n", Cell[ _, "TextTableForm", ___ ], "\nAfter" },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Table-After-Escaped-Text@@Tests/FormattingEscapes.wlt:440,1-445,2"
]

(* A table in a code fence is still a table when the text has escapes. (The line breaks around it differ between the two
   paths, so they are not checked here.) *)
VerificationTest[
    Cases[ #, GridBox[ rows_, ___ ] :> rows, Infinity ] & /@ escPair[
        "Intro {$}5\n\n```\n| a | b |\n|---|---|\n| 1 | 2 |\n```\n\nAfter"
    ],
    {
        x: { { { TagBox[ "\"a\"", HoldForm ], TagBox[ "\"b\"", HoldForm ] }, { "\"1\"", "\"2\"" } } },
        x_
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Fenced-Table@@Tests/FormattingEscapes.wlt:449,1-459,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Links*)

(* Escapes in link labels and URLs are unescaped: *)
VerificationTest[
    FormatMarkdown /@ {
        "[a\\_b](https://example.com/a\\_b) end",
        "[label \\*star\\*](https://example.com) end",
        "[\\[bracketed\\]](https://example.com) end"
    },
    {
        { escLink[ "a_b", "https://example.com/a_b" ], " end" },
        { escLink[ "label *star*", "https://example.com" ], " end" },
        { escLink[ "[bracketed]", "https://example.com" ], " end" }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Link-Label-And-URL@@Tests/FormattingEscapes.wlt:466,1-479,2"
]

(* Escaped brackets don't make a link: *)
VerificationTest[
    FormatMarkdown[ "\\[not a link\\](https://example.com) end" ],
    { "[not a link](https://example.com) end" },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Escaped-Link-Brackets@@Tests/FormattingEscapes.wlt:482,1-487,2"
]

(* Documentation links work with escapes in their label and elsewhere in the text: *)
VerificationTest[
    FormatMarkdown /@ { "See [\\$Failed](paclet:ref/$Failed) here", "[Plot](paclet:ref/Plot) and \\$5" },
    { { "See ", escRefLink[ "$Failed" ], " here" }, { escRefLink[ "Plot" ], " and $5" } },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Paclet-Link-Label@@Tests/FormattingEscapes.wlt:490,1-495,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Code*)

(* Escaped dollar signs and backticks in inline code are unescaped (models often write `\$Failed`): *)
VerificationTest[
    FormatMarkdown /@ { "Use `\\$x` and \\$5", "Use ``a\\`b`` here" },
    { { "Use ", escInlineCode[ "$x" ], " and $5" }, { "Use ", escInlineCode[ "a`b" ], " here" } },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Inline-Code-Dollar-And-Backtick@@Tests/FormattingEscapes.wlt:502,1-507,2"
]

(* Backslashes in inline code that are not markdown escapes are kept: *)
VerificationTest[
    FormatMarkdown[ "Use `\\n` and `C:\\Users` here \\$" ],
    { "Use ", escInlineCode[ "\\n" ], " and ", escInlineCode[ "C:\\Users" ], " here $" },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Inline-Code-Other-Backslashes@@Tests/FormattingEscapes.wlt:510,1-515,2"
]

(* Inline code that is almost certainly Wolfram Language code is shown as syntax-colored input, with its escapes
   unescaped first, the same as without escapes: *)
VerificationTest[
    escPair[ "Use `Plot[{$}x, {x, 0, 1}]` here" ],
    {
        x: {
            "Use ",
            Cell[ BoxData @ RowBox @ { "Plot", "[", RowBox @ { "$x", ___ }, "]" }, "InlineWL", ___ ],
            " here"
        },
        x_
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Inline-WL-Code@@Tests/FormattingEscapes.wlt:519,1-531,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Code Blocks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Code Block Content*)

(* Code blocks are split out before escapes are handled, so their content keeps its backslashes: *)
VerificationTest[
    escPreformatted /@ { "```markdown\n\\*x\\* a\\\\b\n```", "```\na\\\\b \\*\n```" },
    { { "\\*x\\* a\\\\b" }, { "a\\\\b \\*" } },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Code-Block-Content-Kept@@Tests/FormattingEscapes.wlt:542,1-547,2"
]

(* Wolfram Language code blocks keep their backslashes too, and serialize with them (the invisible space before a line
   break is not checked): *)
VerificationTest[
    StringReplace[ MarkdownRoundTrip[ "Cost \\$5:\n\n```wl\nx = \"a\\\\b\"\n```" ], " \n" -> "\n" ],
    "Cost \\$5:\n\n```wl\nx = \"a\\\\b\"\n```",
    SameTest -> MatchQ,
    TestID   -> "Escapes-WL-Code-Block-Content-Kept@@Tests/FormattingEscapes.wlt:551,1-556,2"
]

(* Plain text code blocks ("text" or "plaintext", in any case) turn escaped backslashes into single backslashes, which
   models write in ASCII art. Other escapes are kept: *)
VerificationTest[
    escPreformatted /@ {
        "```text\na\\\\b \\* c\n```",
        "```plaintext\na\\\\b\n```",
        "```TEXT\na\\\\b\n```",
        "```text\na\\\\\\\\b\n```"
    },
    { { "a\\b \\* c" }, { "a\\b" }, { "a\\b" }, { "a\\\\b" } },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Plaintext-Code-Unescapes-Backslashes@@Tests/FormattingEscapes.wlt:560,1-570,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Text Before Code Blocks*)

(* Text that ends with a blank line before a code block keeps a line break (with a space before it, which helps the
   front end wrap the text before the inline code block cell), like it does without escapes: *)
VerificationTest[
    escPair[ "Text {$}5:\n\n```wl\n1+1\n```" ],
    { x: { "Text $5: \n", escCodeBlock[ "Wolfram" ] }, x_ },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Text-Before-Code-Block@@Tests/FormattingEscapes.wlt:578,1-583,2"
]

(* Any number of blank lines before a code block gives a single line break in the escaped path. (Without escapes, three
   line breaks give "\n\n", which shows an extra blank line.) *)
VerificationTest[
    FormatMarkdown[ "Text \\$5:\n\n\n```wl\n1+1\n```" ],
    { "Text $5: \n", escCodeBlock[ "Wolfram" ] },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Text-Before-Code-Block-Extra-Newlines@@Tests/FormattingEscapes.wlt:587,1-592,2"
]

(* Math in the text before a code block is formatted, with the line break kept, like without escapes: *)
VerificationTest[
    escPair[ "Cost {$}5 and $x^2$:\n\n```wl\n1\n```" ],
    { x: { "Cost $5 and ", escTeX[ "x^2" ], ": \n", escCodeBlock[ "Wolfram" ] }, x_ },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Text-Before-Code-Block-Math@@Tests/FormattingEscapes.wlt:595,1-600,2"
]

(* Headings and list items before a code block are the same in both paths: *)
VerificationTest[
    Map[ NormalizeTextData, escPair /@ { "## Heading {$}5\n\n```wl\n1\n```", "- item {$}5\n\n```wl\n1\n```" }, { 2 } ],
    {
        { x: { escSection[ "\"Heading $5\"", "Section", 22 ], "\n", escCodeBlock[ "Wolfram" ] }, x_ },
        { y: { escItem[ "item $5" ], "\n", escCodeBlock[ "Wolfram" ] }, y_ }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Blocks-Before-Code-Block@@Tests/FormattingEscapes.wlt:603,1-611,2"
]

(* Trailing blank lines after the last code block, and untagged code blocks, are the same in both paths: *)
VerificationTest[
    escPair /@ { "Text {$}5\n\n```wl\n1+1\n```\n\n", "Text {$}5\n\n```\nplain\n```" },
    {
        { x: { "Text $5 \n", escCodeBlock[ "Wolfram" ] }, x_ },
        { y: { "Text $5 \n", escCodeBlock[ "" ] }, y_ }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Code-Block-At-End@@Tests/FormattingEscapes.wlt:614,1-622,2"
]

(* Leading whitespace of the first text part is trimmed, while indentation of text between code blocks is kept, like
   without escapes: *)
VerificationTest[
    escPair /@ { "   Leading {$}5\n\n```wl\n1\n```", "```wl\n1\n```\n\n   Middle {$}5\n\n```wl\n2\n```" },
    {
        { x: { "Leading $5 \n", escCodeBlock[ "Wolfram" ] }, x_ },
        { y: { escCodeBlock[ "Wolfram" ], "\n   Middle $5 \n", escCodeBlock[ "Wolfram" ] }, y_ }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Text-Before-Code-Block-Indentation@@Tests/FormattingEscapes.wlt:626,1-634,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Text After Code Blocks*)

(* Text after a code block starts on the next line. The escaped path trims the line break after the code block, which
   only looks the same because the code block fills the line (both forms are accepted here): *)
VerificationTest[
    escPair /@ { "```wl\n1+1\n```\n\nAfter {$}5", "```wl\n1+1\n```\nAfter {$}5" },
    {
        { { escCodeBlock[ "Wolfram" ], "After $5" | "\nAfter $5" }, { escCodeBlock[ "Wolfram" ], "\nAfter $5" } },
        { { escCodeBlock[ "Wolfram" ], "After $5" | "\nAfter $5" }, { escCodeBlock[ "Wolfram" ], "\nAfter $5" } }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Text-After-Code-Block@@Tests/FormattingEscapes.wlt:642,1-650,2"
]

(* Text between two code blocks keeps the line breaks on both sides: *)
VerificationTest[
    FormatMarkdown[ "Before \\$5\n\n```wl\n1\n```\n\nMiddle\n\n```wl\n2\n```\n\nAfter" ],
    {
        "Before $5 \n",
        escCodeBlock[ "Wolfram" ],
        "\nMiddle \n",
        escCodeBlock[ "Wolfram" ],
        "After" | "\nAfter"
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Text-Between-Code-Blocks@@Tests/FormattingEscapes.wlt:653,1-664,2"
]

(* A blank line between two code blocks gives a line break between them, like without escapes: *)
VerificationTest[
    escPair[ "```wl\n1\n```\n\n```wl\n2\n```\n\n{$}5" ],
    {
        { escCodeBlock[ "Wolfram" ], "\n", escCodeBlock[ "Wolfram" ], "$5" | "\n$5" },
        { escCodeBlock[ "Wolfram" ], "\n", escCodeBlock[ "Wolfram" ], "\n$5" }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Blank-Line-Between-Code-Blocks@@Tests/FormattingEscapes.wlt:667,1-675,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Streaming*)

(* An unterminated code block while streaming: *)
VerificationTest[
    escPair[ "Text {$}5\n\n```wl\n1+", "Streaming" ],
    {
        x: {
            "Text $5 \n",
            Cell[ BoxData @ TemplateBox[ { Cell[ BoxData[ "1+" ], "ChatCodeActive" ], "wl" }, "ChatCodeBlockTemplate" ], "ChatCodeBlock" ]
        },
        x_
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Unterminated-Code-Block-Streaming@@Tests/FormattingEscapes.wlt:682,1-693,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Think Tags*)

(* Think tags are split out with their raw text, and their content is formatted on its own with its escapes handled.
   (The line breaks between the opener and the answer differ between the two paths, so they are not checked here.) *)
VerificationTest[
    FormatMarkdown[ "<think>a \\* b and **bold**</think>\n\nAnswer" ],
    {
        escThoughts[ TextData @ { "a * b and ", StyleBox[ "bold", FontWeight -> Bold ] }, <| "Type" -> "Literal" |> ],
        _String? (StringMatchQ[ "\n".. ~~ "Answer" ])
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Thoughts-Content@@Tests/FormattingEscapes.wlt:701,1-709,2"
]

(* Escapes in the thoughts and in the answer are each handled: *)
VerificationTest[
    FormatMarkdown[ "<think>x \\_y\\_</think>\n\nAnswer \\$5 and *it*" ],
    {
        escThoughts[ TextData @ { "x _y_" }, <| "Type" -> "Literal" |> ],
        _String? (StringMatchQ[ "\n".. ~~ "Answer $5 and " ]),
        StyleBox[ "it", FontSlant -> Italic ]
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Thoughts-And-Answer@@Tests/FormattingEscapes.wlt:712,1-721,2"
]

(* Blocks inside a think tag are formatted when its content has escapes: *)
VerificationTest[
    Cases[
        FormatMarkdown[ "<think>a \\$5\n- item \\*\n## head</think>\n\nAnswer" ],
        escThoughts[ TextData[ content_List ], _ ] :> NormalizeTextData @ content,
        Infinity
    ],
    {
        { "a $5\n", escItem[ "item *" ], "\n", escSection[ "\"head\"", "Section", 22 ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Thoughts-Blocks@@Tests/FormattingEscapes.wlt:724,1-735,2"
]

(* The content of a think tag is formatted the same in both paths: *)
VerificationTest[
    Cases[ escPair[ "<think>a {$}5 *b*</think>\n\nAnswer" ], escThoughts[ content_, _ ] :> content, Infinity ],
    { x: TextData @ { "a $5 ", StyleBox[ "b", FontSlant -> Italic ] }, x_ },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Thoughts-Same-In-Both-Paths@@Tests/FormattingEscapes.wlt:738,1-743,2"
]

(* Reasoning summaries keep their metadata: *)
VerificationTest[
    FormatMarkdown[ "<think type='summary' id='rs_1'>sum \\* mary</think>\n\nAnswer" ],
    {
        escThoughts[ TextData @ { "sum * mary" }, <| "Type" -> "Summary", "ID" -> "rs_1" |> ],
        _String? (StringMatchQ[ "\n".. ~~ "Answer" ])
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Reasoning-Summary@@Tests/FormattingEscapes.wlt:746,1-754,2"
]

(* An unterminated think tag, when finished and while streaming: *)
VerificationTest[
    FormatMarkdown[ "<think>partial \\* thinking", # ] & /@ { "Finished", "Streaming" },
    {
        {
            Cell[
                BoxData @ TemplateBox[ { TextData @ { "partial * thinking" }, _, <| "Type" -> "Literal" |> }, "ThinkingOpener" ],
                "ThinkingOpener",
                Background -> None
            ]
        },
        {
            Cell[
                BoxData @ TemplateBox[ { TextData @ { "partial * thinking" }, _, <| "Type" -> "Literal" |> }, "ThinkingOpener" ],
                "ThinkingOpener",
                Background -> None
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Thinking-Unterminated@@Tests/FormattingEscapes.wlt:757,1-777,2"
]

(* The other think tag forms in escaped text: a closed <thinking> tag, and unterminated <thinking> and reasoning summary
   tags (the rules for escaped text are a separate copy of the think tag rules): *)
VerificationTest[
    {
        FormatMarkdown[ "<thinking>a \\* b</thinking>\n\nAnswer" ],
        FormatMarkdown[ "<thinking>partial \\* x" ],
        FormatMarkdown[ "<think type='summary' id='rs_1'>partial \\* sum" ]
    },
    {
        {
            escThoughts[ TextData @ { "a * b" }, <| "Type" -> "Literal" |> ],
            _String? (StringMatchQ[ "\n".. ~~ "Answer" ])
        },
        {
            Cell[
                BoxData @ TemplateBox[ { TextData @ { "partial * x" }, _, <| "Type" -> "Literal" |> }, "ThinkingOpener" ],
                "ThinkingOpener",
                Background -> None
            ]
        },
        {
            Cell[
                BoxData @ TemplateBox[
                    { TextData @ { "partial * sum" }, _, <| "Type" -> "Summary", "ID" -> "rs_1" |> },
                    "ThinkingOpener"
                ],
                "ThinkingOpener",
                Background -> None
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Thinking-Tag-Variants@@Tests/FormattingEscapes.wlt:781,1-812,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Calls*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Call Spacing*)

(* Each text part between tool calls is formatted on its own, which trims its whitespace, so the whitespace next to a
   tool call is split out first (splitToolCallSpacing). This gives the same line breaks as without escapes: *)
VerificationTest[
    Select[
        {
            escToolCallText <> "\nAfter {$}5",
            escToolCallText <> "\n\nAfter {$}5",
            escToolCallText <> "After {$}5",
            "Before {$}5\n" <> escToolCallText,
            "Before {$}5\n\n" <> escToolCallText,
            "Before {$}5\n" <> escToolCallText <> "\nAfter",
            "Before {$}5\n\n\n" <> escToolCallText <> "\n\n\nAfter",
            "Before {$}5\n\n" <> escToolCallText2 <> "\n\nAfter",
            "Before {$}5\n" <> escToolCallText <> "\n\n```wl\n1\n```",
            "Text {$}5\n\n```wl\n1\n```\n\n" <> escToolCallText <> "\n\nAfter",
            escToolCallText2 <> "\n\n```wl\n1\n```\n\n" <> escToolCallText <> "\nEnd {$}5",
            escToolCallText2 <> "\n" <> escToolCallText <> "\nAfter {$}5",
            escToolCallText2 <> "\n\n" <> escToolCallText <> "\n\nAfter {$}5",
            "  " <> escToolCallText <> "  \n  After {$}5",
            "- item {$}5\n" <> escToolCallText <> "\n- item two",
            "## Head {$}5\n" <> escToolCallText <> "\n## Next",
            "<think>a {$}5</think>\n" <> escToolCallText <> "\nAfter"
        },
        ! (SameQ @@ escPair[ # ] && SameQ @@ escPair[ #, "Streaming" ]) &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Escapes-ToolCall-Spacing-Same-As-Plain@@Tests/FormattingEscapes.wlt:824,1-850,2"
]

(* Extra blank lines next to a tool call: *)
VerificationTest[
    FormatMarkdown[ "Before \\$5\n\n\n" <> escToolCallText <> "\n\n\nAfter" ],
    { "Before $5 \n", escToolCall, "\n\nAfter" },
    SameTest -> MatchQ,
    TestID   -> "Escapes-ToolCall-Extra-Blank-Lines@@Tests/FormattingEscapes.wlt:853,1-858,2"
]

(* Text directly after a tool call, and whitespace that is not a line break: *)
VerificationTest[
    FormatMarkdown /@ { escToolCallText <> "After \\$5", "  " <> escToolCallText <> "  \n  After \\$5" },
    { { escToolCall, "After $5" }, { escToolCall, "  \n  After $5" } },
    SameTest -> MatchQ,
    TestID   -> "Escapes-ToolCall-Adjacent-Text@@Tests/FormattingEscapes.wlt:861,1-866,2"
]

(* Tool calls separated only by whitespace get a single line break between them: *)
VerificationTest[
    FormatMarkdown[ escToolCallText2 <> "\n\n" <> escToolCallText <> "\n\nAfter \\$5" ],
    { escToolCall, "\n", escToolCall, "\nAfter $5" },
    SameTest -> MatchQ,
    TestID   -> "Escapes-ToolCall-Between-Tool-Calls@@Tests/FormattingEscapes.wlt:869,1-874,2"
]

(* Tool calls between list items and headings: *)
VerificationTest[
    NormalizeTextData @* FormatMarkdown /@ {
        "- item \\$5\n" <> escToolCallText <> "\n- item two",
        "## Head \\$5\n" <> escToolCallText <> "\n## Next"
    },
    {
        { escItem[ "item $5" ], "\n", escToolCall, "\n", escItem[ "item two" ] },
        { escSection[ "\"Head $5\"", "Section", 22 ], "\n", escToolCall, "\n", escSection[ "\"Next\"", "Section", 22 ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-ToolCall-Between-Blocks@@Tests/FormattingEscapes.wlt:877,1-888,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Discarded Material*)

(* Text in discarded material has its escapes handled, and the discarded content is the same as without escapes: *)
VerificationTest[
    Module[ { escaped, plain },
        { escaped, plain } = escDiscardedContent /@ escPair[
            escToolCallText <> "\nOops, *that* cost {$}5.\n/retry\n" <> escToolCallText <> "\nDone."
        ];
        { escaped, escaped === plain }
    ],
    {
        Column[
            {
                RawBoxes @ Cell[
                    TextData @ { escToolCall, "\nOops, ", StyleBox[ "that", FontSlant -> Italic ], " cost $5." },
                    "Text",
                    ___
                ]
            },
            ___
        ],
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Discarded-Material-Content@@Tests/FormattingEscapes.wlt:895,1-917,2"
]

(* The spacing around discarded material is the same as without escapes, also with text before it: *)
VerificationTest[
    escPair[ "Start {$}5\n" <> escToolCallText <> "\nOops.\n/retry\n" <> escToolCallText <> "\nDone." ],
    { x: { "Start $5 \n", Cell[ _, "DiscardedMaterial", ___ ], "\n", escToolCall, "\nDone." }, x_ },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Discarded-Material-Spacing@@Tests/FormattingEscapes.wlt:920,1-925,2"
]

(* While streaming, discarded material is a closed placeholder opener: *)
VerificationTest[
    escPair[ escToolCallText <> "\nOops {$}5.\n/retry\n" <> escToolCallText <> "\nDone.", "Streaming" ],
    { x: { Cell[ _, "DiscardedMaterial", ___ ], "\n", escToolCall, "\nDone." }, x_ },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Discarded-Material-Streaming@@Tests/FormattingEscapes.wlt:928,1-933,2"
]

(* Discarded material is left out when serialized: *)
VerificationTest[
    MarkdownRoundTrip[ escToolCallText <> "\nOops \\$5.\n/retry\n" <> escToolCallText <> "\nDone \\$5." ],
    escToolCallText <> "\nDone \\$5.",
    SameTest -> MatchQ,
    TestID   -> "Escapes-Discarded-Material-Serialization@@Tests/FormattingEscapes.wlt:936,1-941,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Escaped and Plain Paths*)

(* A key invariant: a document with an escape looks the same as the equivalent document without one. These documents
   give the same result in both paths (apart from invisible whitespace), when finished and while streaming: *)
VerificationTest[
    Select[
        {
            "Line one {$}5\nLine two",
            "  {$}5 text  ",
            "A {$}5\n\n\n\nB",
            "\n\n{$}5\n\n",
            "$$x^2$$ costs {$}5",
            "Some *italic* and {$}5 **bold** `Plot` and `code here`",
            "[label {$}5](https://example.com) and [Plot](paclet:ref/Plot)",
            "Text {$}5 `inline` text",
            "**`Plot` and {$}5**",
            "Text {$}5\n\n```\nplain\n```",
            "Text {$}5\n\n```wl\n1+1\n```\n\n",
            "## Heading {$}5\n\n```wl\n1\n```",
            "- item {$}5\n\n```wl\n1\n```",
            "## Steps {$}5\n\n1. First\n2. Second\n\n```wl\nx\n```",
            "Para {$}5\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nAfter",
            "Para {$}5\n\n> quote\n\nAfter",
            "Para {$}5\n\n---\n\nAfter",
            "# Title {$}5\n\nBody\n\n## Section\n\n- a\n- b\n  - c\n\n1. one\n2. two\n\n***\n\nEnd"
        },
        ! (escSameQ[ # ] && escSameQ[ #, "Streaming" ]) &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Paths-Equivalent@@Tests/FormattingEscapes.wlt:949,1-976,2"
]

(* A larger document with several block types: *)
VerificationTest[
    NormalizeTextData /@ escPair[ "# Title {$}5\n\nBody\n\n## Section\n\n- a\n- b\n  - c\n\n1. one\n2. two\n\n***\n\nEnd" ],
    {
        x: {
            escSection[ "\"Title $5\"", "Title", 26 ],
            "\nBody\n",
            escSection[ "\"Section\"", "Section", 22 ],
            "\n",
            escItem[ "a" ],
            "\n",
            escItem[ "b" ],
            "\n",
            escSubitem[ "  ", "c" ],
            "\n1. one\n2. two\n",
            escDelimiter,
            "\nEnd"
        },
        x_
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Paths-Equivalent-Document@@Tests/FormattingEscapes.wlt:979,1-1000,2"
]

(* Both paths serialize to the same markdown: *)
VerificationTest[
    Select[
        {
            "Cost {$}5 and *x*",
            "## Heading {$}5\n\n- item\n\nText",
            "Text {$}5\n\n```wl\n1+1\n```",
            "Before {$}5\n" <> escToolCallText <> "\nAfter",
            escToolCallText <> "\nOops {$}5.\n/retry\n" <> escToolCallText <> "\nDone."
        },
        Apply[ UnsameQ ] @ Map[
            MarkdownRoundTrip,
            { StringReplace[ #, "{$}" -> "\\$" ], StringReplace[ #, "{$}" -> "$" ] }
        ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Paths-Same-Serialization@@Tests/FormattingEscapes.wlt:1003,1-1020,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Math Interactions*)

(* Escaped dollar signs don't start or end math: *)
VerificationTest[
    FormatMarkdown /@ { "\\$x$ not math", "\\$\\$x\\$\\$ literal", "Escaped \\$x+y\\$ is not math" },
    { { "$x$ not math" }, { "$$x$$ literal" }, { "Escaped $x+y$ is not math" } },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Math-Escaped-Dollars@@Tests/FormattingEscapes.wlt:1027,1-1032,2"
]

(* Escaped dollar signs and math in the same text, and an escaped backslash before math: *)
VerificationTest[
    FormatMarkdown /@ { "Price \\$5 and $x^2$ here", "\\\\$x^2$ after backslash" },
    {
        { "Price $5 and ", escTeX[ "x^2" ], " here" },
        { "\\", escTeX[ "x^2" ], " after backslash" }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Math-Mixed@@Tests/FormattingEscapes.wlt:1035,1-1043,2"
]

(* Inside math, escapes go back to the TeX parser as backslash sequences, while escapes outside are removed: *)
VerificationTest[
    FormatMarkdown /@ { "Math $$a \\\\ b$$ end", "Math \\(a \\_ b\\) end \\*", "$\\alpha\\_1$ inline" },
    {
        { "Math ", escTeX[ "a \\\\ b" ], " end" },
        { "Math ", escTeX[ "a \\_ b" ], " end *" },
        { escTeX[ "\\alpha\\_1" ], " inline" }
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Math-TeX-Escapes@@Tests/FormattingEscapes.wlt:1046,1-1055,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*HTML Entities*)

(* HTML entities are decoded in escaped text too: *)
VerificationTest[
    FormatMarkdown /@ { "fish &amp; chips \\$5", "&lt;b&gt; and \\*", "&amp;\\$ mixed" },
    { { "fish & chips $5" }, { "<b> and *" }, { "&$ mixed" } },
    SameTest -> MatchQ,
    TestID   -> "Escapes-HTML-Entities@@Tests/FormattingEscapes.wlt:1062,1-1067,2"
]

(* In text without escapes, a backslash from an HTML entity is a literal backslash: *)
VerificationTest[
    FormatMarkdown[ "&#92;* entity" ],
    { "\\* entity" },
    SameTest -> MatchQ,
    TestID   -> "Escapes-HTML-Entity-Backslash@@Tests/FormattingEscapes.wlt:1070,1-1075,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Serialization*)

(* CellToString escapes ` $ * _ # | in text again, so escaped characters serialize back to their escapes. A backslash
   and brackets are not escaped: *)
VerificationTest[
    MarkdownRoundTrip /@ {
        "a \\\\ b",
        "a \\` b",
        "a \\$ b",
        "a \\* b",
        "a \\_ b",
        "a \\# b",
        "a \\| b",
        "a \\[ b",
        "a \\] b"
    },
    { "a \\ b", "a \\` b", "a \\$ b", "a \\* b", "a \\_ b", "a \\# b", "a \\| b", "a [ b", "a ] b" },
    SameTest -> MatchQ,
    TestID   -> "Escapes-RoundTrip-Each-Character@@Tests/FormattingEscapes.wlt:1083,1-1098,2"
]

VerificationTest[
    MarkdownRoundTrip /@ {
        "**bold \\* star**",
        "*italic \\* star*",
        "\\*\\*not bold\\*\\*",
        "__bold \\_ under__",
        "\\*not italic\\* and *italic*"
    },
    {
        "**bold \\* star**",
        "*italic \\* star*",
        "\\*\\*not bold\\*\\*",
        "**bold \\_ under**",
        "\\*not italic\\* and *italic*"
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-RoundTrip-Emphasis@@Tests/FormattingEscapes.wlt:1100,1-1117,2"
]

VerificationTest[
    MarkdownRoundTrip /@ {
        "## Heading with \\*stars\\* and **bold**",
        "- \\*not italic\\* item\n- *italic* item",
        "\\# Not a heading",
        "[label \\*star\\*](https://example.com) end"
    },
    {
        "## Heading with \\*stars\\* and **bold**",
        "* \\*not italic\\* item\n* *italic* item",
        "\\# Not a heading",
        "[label \\*star\\*](https://example.com) end"
    },
    SameTest -> MatchQ,
    TestID   -> "Escapes-RoundTrip-Blocks-And-Links@@Tests/FormattingEscapes.wlt:1119,1-1134,2"
]

(* Inline code with markdown characters serializes as double-backtick code, and the code looks the same after a round
   trip. (The markdown characters in the code are currently escaped too, e.g. ``x\*y``, which is reported as a quirk, so
   backslashes are removed before comparing. Formatting unescapes them again, which is why the round trip works.) *)
VerificationTest[
    With[ { md = "Use `x*y` and `a|b` and `#x` and `$y` here" },
        { StringDelete[ MarkdownRoundTrip @ md, "\\" ], escReformat @ md === NormalizeTextData @ FormatMarkdown @ md }
    ],
    { "Use ``x*y`` and ``a|b`` and ``#x`` and ``$y`` here", True },
    SameTest -> MatchQ,
    TestID   -> "Escapes-RoundTrip-Inline-Code@@Tests/FormattingEscapes.wlt:1139,1-1146,2"
]

(* Think tag content is escaped too: *)
VerificationTest[
    MarkdownRoundTrip[ "<think>a \\* b</think>\n\nAnswer \\$5" ],
    "<think>\na \\* b\n</think>\n\nAnswer \\$5",
    SameTest -> MatchQ,
    TestID   -> "Escapes-RoundTrip-Thoughts@@Tests/FormattingEscapes.wlt:1149,1-1154,2"
]

(* Code block content is not escaped. Plain text code blocks serialize with their unescaped backslashes and the
   "Plaintext" language: *)
VerificationTest[
    MarkdownRoundTrip /@ { "```markdown\n\\*x\\* a\\\\b\n```", "```text\na\\\\b \\* c\n```" },
    { "```markdown\n\\*x\\* a\\\\b\n```", "```Plaintext\na\\b \\* c\n```" },
    SameTest -> MatchQ,
    TestID   -> "Escapes-RoundTrip-Code-Blocks@@Tests/FormattingEscapes.wlt:1158,1-1163,2"
]

(* Math serializes with its TeX escapes, and the text around it with markdown escapes: *)
VerificationTest[
    MarkdownRoundTrip[ "Math $$a \\_ b$$ and \\_" ],
    "Math $$a \\_ b$$ and \\_",
    SameTest -> MatchQ,
    TestID   -> "Escapes-RoundTrip-Math@@Tests/FormattingEscapes.wlt:1166,1-1171,2"
]

(* Formatting the serialized output again gives the same result: *)
VerificationTest[
    Select[
        {
            "Cost \\$5, \\*not italic\\*, **bold \\* star**, \\_x\\_, \\# hash, a \\| pipe, and \\`tick\\`.",
            "[label \\*star\\*](https://example.com) and `\\$x`",
            "<think>a \\* b</think>\n\nAnswer \\$5",
            "Text \\$5\n\n```wl\n1+1\n```\n\nAfter",
            "Literal backslash \\\\ here",
            "Math $$a \\_ b$$ and \\_",
            "- \\*not italic\\* item\n- *italic* item"
        },
        NormalizeTextData @ FormatMarkdown @ # =!= escReformat @ # &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Escapes-RoundTrip-Reformat-Stable@@Tests/FormattingEscapes.wlt:1174,1-1190,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Streaming*)

(* Escaped text without code blocks, math, or tool calls is formatted the same while streaming: *)
VerificationTest[
    Select[
        {
            "\\*not italic\\* and **bold \\* star**",
            "## H \\$5\n\n- a \\_b\\_\n\n> q \\#1",
            "[label \\*star\\*](https://example.com) and `\\$x`",
            "| a | b |\n|---|---|\n| \\$5 | x\\_y |"
        },
        FormatMarkdown[ #, "Streaming" ] =!= FormatMarkdown @ # &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Escapes-Streaming-Same-As-Finished@@Tests/FormattingEscapes.wlt:1197,1-1210,2"
]

(* :!CodeAnalysis::EndBlock:: *)
