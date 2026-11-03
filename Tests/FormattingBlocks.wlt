(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/FormattingBlocks.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/FormattingBlocks.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* Characterization tests for block-level markdown: headings, bullet lists, horizontal rules, block quotes, paragraphs
   and line breaks, and HTML entities. They describe what the formatter currently does, so that a rewrite can be
   checked against them.

   Most tests compare against NormalizeTextData of the formatted items, which joins adjacent strings and removes
   spaces before line breaks. The patterns below match the cells that each block construct creates. Colors are
   resolved from the theme, so they're left open. *)
VerificationTest[
    ClearAll[
        blocksTextBox, blocksTextCell, blocksFontSize, blocksHeading, blocksSection, blocksItem, blocksSubitem,
        blocksQuote, blocksNormalized, blocksStyles, blocksRoundTrip
    ];

    (* A plain string inside boxes is stored as a string box ("\"text\"", which is what ToBoxes gives). Raw text would
       display the same, since these boxes don't show string characters: *)
    blocksTextBox[ s_String ] := Alternatives[ ToBoxes @ s, s ];

    (* Inline formatted content of a heading or block quote: *)
    blocksTextCell[ items___ ] := Cell[ TextData @ { items }, Background -> None ];

    (* Headings are inline cells with the notebook section style applied to the content. Levels without an explicit
       font size have FontSize -> Inherited, which looks the same as no FontSize option: *)
    blocksFontSize[ Inherited ] := Repeated[ FontSize -> Inherited, { 0, 1 } ];
    blocksFontSize[ size_ ] := FontSize -> size;

    blocksHeading[ content_, style_String, size_, margins_ ] := Cell[
        BoxData @ PaneBox[
            StyleBox[
                content,
                style,
                OrderlessPatternSequence[ CellFrame -> 0, ShowStringCharacters -> False, blocksFontSize @ size ]
            ],
            ImageMargins -> margins
        ],
        "InlineSection",
        Background -> None
    ];

    blocksSection[ content_ ] := blocksHeading[ content, "Section", 22, { { 0, 0 }, { 5, 15 } } ];

    (* Bullet items, after NormalizeTextData (so the space after the bullet is joined with the text that follows
       it): *)
    $$blocksBullet = StyleBox[ "\[Bullet]", FontColor -> _ ];
    blocksItem[ content___ ] := Cell[ TextData @ { $$blocksBullet, content }, "InlineItem" ];
    blocksSubitem[ indent_String, content___ ] :=
        Cell[ TextData @ { indent, $$blocksBullet, content }, "InlineSubitem" ];

    $$blocksDelimiter = Cell[ _BoxData, "MarkdownDelimiter", ___ ];
    $$blocksCodeBlock = Cell[ _, "ChatCodeBlock", ___ ];

    (* Inline code naming a system symbol becomes a documentation link: *)
    $$blocksPlotLink = Cell @ BoxData @ TemplateBox[ { "Plot", "paclet:ref/Plot", _String }, "TextRefLink" ];

    (* The link that "[Example](https://example.com)" (or "[link](...)") makes: *)
    $$blocksExampleLink = ButtonBox[
        "Example"|"link",
        OrderlessPatternSequence[
            BaseStyle  -> "Hyperlink",
            ButtonData -> { URL[ "https://example.com" ], None },
            ButtonNote -> "https://example.com"
        ]
    ];

    blocksQuote[ content_ ] := Cell[ BoxData @ GridBox[ { { PaneBox[ content, ___ ] } }, ___ ], "BlockQuote", ___ ];

    blocksNormalized[ md_String ] := NormalizeTextData @ FormatMarkdown @ md;
    blocksNormalized[ md_String, status_String ] := NormalizeTextData @ FormatMarkdown[ md, status ];

    (* The styles of the top-level cells, in order: *)
    blocksStyles[ md_String ] := Cases[ FormatMarkdown @ md, Cell[ _, style_String, ___ ] :> style ];

    (* Round trip through CellToString, ignoring the invisible spaces that come before some line breaks: *)
    blocksRoundTrip[ md_String ] := StringReplace[ MarkdownRoundTrip @ md, " ".. ~~ "\n" -> "\n" ],

    Null,
    SameTest -> MatchQ,
    TestID   -> "Blocks-Definitions@@Tests/FormattingBlocks.wlt:32,1-102,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Headings*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Structure and Levels*)

(* A heading is an "InlineSection" cell. The section style is applied to the content inside a PaneBox, which sets the
   spacing around it. The cell frame of the section style is turned off: *)
VerificationTest[
    FormatMarkdown[ "## Section" ],
    {
        Cell[
            BoxData @ PaneBox[
                StyleBox[
                    blocksTextBox[ "Section" ],
                    "Section",
                    OrderlessPatternSequence[ CellFrame -> 0, FontSize -> 22, ShowStringCharacters -> False ]
                ],
                ImageMargins -> { { 0, 0 }, { 5, 15 } }
            ],
            "InlineSection",
            Background -> None
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Structure@@Tests/FormattingBlocks.wlt:114,1-132,2"
]

(* The number of "#" characters selects the section style. Only "Title" and "Section" get an explicit font size (the
   others have FontSize -> Inherited, which is the same as no FontSize). The first four levels get larger margins.
   Levels deeper than six use the sixth level's style: *)
VerificationTest[
    Replace[
        FormatMarkdown[ StringRepeat[ "#", # ] <> " Heading" ],
        {
            { Cell[ BoxData @ PaneBox[ StyleBox[ _, style_String, opts___ ], paneOpts___ ], "InlineSection", ___ ] } :>
                { style, Lookup[ { opts }, FontSize, Inherited ], Lookup[ { paneOpts }, ImageMargins ] }
        }
    ] & /@ Range[ 8 ],
    {
        { "Title"              , 26       , { { 0, 0 }, { 5, 15 } } },
        { "Section"            , 22       , { { 0, 0 }, { 5, 15 } } },
        { "Subsection"         , Inherited, { { 0, 0 }, { 5, 15 } } },
        { "Subsubsection"      , Inherited, { { 0, 0 }, { 5, 15 } } },
        { "Subsubsubsection"   , Inherited, { { 0, 0 }, { 2, 5  } } },
        { "Subsubsubsubsection", Inherited, { { 0, 0 }, { 2, 5  } } },
        { "Subsubsubsubsection", Inherited, { { 0, 0 }, { 2, 5  } } },
        { "Subsubsubsubsection", Inherited, { { 0, 0 }, { 2, 5  } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Levels@@Tests/FormattingBlocks.wlt:137,1-157,2"
]

(* Each heading level serializes back to the same number of "#" characters: *)
VerificationTest[
    MarkdownRoundTrip /@ {
        "# Title",
        "## Section",
        "### Subsection",
        "#### Subsubsection",
        "##### Five",
        "###### Six"
    },
    {
        "# Title",
        "## Section",
        "### Subsection",
        "#### Subsubsection",
        "##### Five",
        "###### Six"
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Serialization@@Tests/FormattingBlocks.wlt:160,1-179,2"
]

(* Levels deeper than six share the sixth level's style, so they serialize as level six: *)
VerificationTest[
    MarkdownRoundTrip /@ { "####### Seven", "######## Eight" },
    { "###### Seven", "###### Eight" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Deeper-Than-Six-Serialization@@Tests/FormattingBlocks.wlt:182,1-187,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Inline Formatting in Headings*)

(* Heading text is formatted like other text. Formatted content is wrapped in a TextData cell inside the StyleBox: *)
VerificationTest[
    FormatMarkdown[ "## **Bold** heading" ],
    { blocksSection @ blocksTextCell[ StyleBox[ "Bold", FontWeight -> Bold ], " heading" ] },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Bold@@Tests/FormattingBlocks.wlt:194,1-199,2"
]

VerificationTest[
    FormatMarkdown /@ { "## A *b* c", "## ~~Old~~ New" },
    {
        { blocksSection @ blocksTextCell[ "A ", StyleBox[ "b", FontSlant -> Italic ], " c" ] },
        {
            blocksSection @ blocksTextCell[
                StyleBox[ "Old", FontVariations -> { "StrikeThrough" -> True } ],
                " New"
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Italic-And-Strikethrough@@Tests/FormattingBlocks.wlt:201,1-214,2"
]

(* Inline code naming a system symbol becomes a documentation link, also inside headings: *)
VerificationTest[
    FormatMarkdown /@ { "## Using `Plot` and *style*", "## `Plot`" },
    {
        {
            blocksSection @ blocksTextCell[
                "Using ",
                $$blocksPlotLink,
                " and ",
                StyleBox[ "style", FontSlant -> Italic ]
            ]
        },
        { blocksSection @ blocksTextCell[ $$blocksPlotLink ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Inline-Code@@Tests/FormattingBlocks.wlt:217,1-232,2"
]

VerificationTest[
    FormatMarkdown[ "## [Example](https://example.com)" ],
    { blocksSection @ blocksTextCell[ StyleBox[ $$blocksExampleLink ] | $$blocksExampleLink ] },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Hyperlink@@Tests/FormattingBlocks.wlt:234,1-239,2"
]

VerificationTest[
    FormatMarkdown[ "## Heading $x^2$" ],
    {
        blocksSection @ blocksTextCell[
            "Heading ",
            Cell @ BoxData @ FormBox[ TemplateBox[ _, "TeXAssistantTemplate" ], TraditionalForm ]
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Math@@Tests/FormattingBlocks.wlt:241,1-251,2"
]

VerificationTest[
    MarkdownRoundTrip /@ {
        "## **Bold** heading",
        "## A *b* c",
        "## ~~Old~~ New",
        "## Using `Plot` and *style*",
        "## [Example](https://example.com)"
    },
    {
        "## **Bold** heading",
        "## A *b* c",
        "## ~~Old~~ New",
        "## Using [Plot](paclet:ref/Plot) and *style*",
        "## [Example](https://example.com)"
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Inline-Formatting-Serialization@@Tests/FormattingBlocks.wlt:253,1-270,2"
]

(* HTML entities and unicode in headings: *)
VerificationTest[
    FormatMarkdown /@ { "## Fish &amp; Chips", "## H\[EAcute]ading \[LongDash] \[UDoubleDot]n\[IDoubleDot]code" },
    {
        { blocksSection @ blocksTextBox[ "Fish & Chips" ] },
        { blocksSection @ blocksTextBox[ "H\[EAcute]ading \[LongDash] \[UDoubleDot]n\[IDoubleDot]code" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Entities-And-Unicode@@Tests/FormattingBlocks.wlt:273,1-281,2"
]

VerificationTest[
    MarkdownRoundTrip /@ { "## Fish &amp; Chips", "## H\[EAcute]ading \[LongDash] \[UDoubleDot]n\[IDoubleDot]code" },
    { "## Fish & Chips", "## H\[EAcute]ading \[LongDash] \[UDoubleDot]n\[IDoubleDot]code" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Entities-And-Unicode-Serialization@@Tests/FormattingBlocks.wlt:283,1-288,2"
]

(* Only the leading "#" characters set the level. Other "#" characters are part of the heading text: *)
VerificationTest[
    {
        FormatMarkdown /@ { "# C# language", "## Heading #1" },
        MarkdownRoundTrip /@ { "# C# language", "## Heading #1" }
    },
    {
        {
            { blocksHeading[ blocksTextBox[ "C# language" ], "Title", 26, { { 0, 0 }, { 5, 15 } } ] },
            { blocksSection @ blocksTextBox[ "Heading #1" ] }
        },
        { "# C# language", "## Heading #1" }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Hash-In-Text@@Tests/FormattingBlocks.wlt:291,1-305,2"
]

(* A heading that is entirely bold (as LLMs often write) still has its content wrapped in a TextData cell: *)
VerificationTest[
    { FormatMarkdown[ "## **All bold**" ], MarkdownRoundTrip[ "## **All bold**" ] },
    { { blocksSection @ blocksTextCell @ StyleBox[ "All bold", FontWeight -> Bold ] }, "## **All bold**" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Fully-Formatted@@Tests/FormattingBlocks.wlt:308,1-313,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Not Headings*)

(* A heading needs a space after the "#" characters and has to start a line: *)
VerificationTest[
    FormatMarkdown /@ { "##NoSpace", "#hashtag here", "Text # not heading", "Text ## not heading" },
    { { "##NoSpace" }, { "#hashtag here" }, { "Text # not heading" }, { "Text ## not heading" } },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Requires-Space-And-Line-Start@@Tests/FormattingBlocks.wlt:320,1-325,2"
]

(* A heading needs some text. A partial heading while streaming stays plain text: *)
VerificationTest[
    { FormatMarkdown[ "# " ], FormatMarkdown[ "## ", "Streaming" ], FormatMarkdown[ "Text\n\n#", "Streaming" ] },
    { { "#" }, { "##" }, { "Text\n\n#" } },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Empty@@Tests/FormattingBlocks.wlt:328,1-333,2"
]

VerificationTest[
    FormatMarkdown[ "## Hea", "Streaming" ],
    { blocksSection @ blocksTextBox[ "Hea" ] },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Streaming-Partial@@Tests/FormattingBlocks.wlt:335,1-340,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Spacing Around Headings*)

(* The heading rule consumes the line breaks before the heading and the cell is preceded by a single line break. Blank
   lines around a heading are optional: *)
VerificationTest[
    blocksNormalized /@ { "Intro\n\n## Heading\n\nBody text", "Intro\n## Heading\nBody text" },
    {
        { "Intro\n", blocksSection @ blocksTextBox[ "Heading" ], "\nBody text" },
        { "Intro\n", blocksSection @ blocksTextBox[ "Heading" ], "\nBody text" }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Paragraph-Spacing@@Tests/FormattingBlocks.wlt:348,1-356,2"
]

(* Extra blank lines before a heading are dropped, but extra blank lines after one are kept: *)
VerificationTest[
    blocksNormalized /@ { "Para\n\n\n## H", "## H\n\n\nBody" },
    {
        { "Para\n", blocksSection @ blocksTextBox[ "H" ] },
        { blocksSection @ blocksTextBox[ "H" ], "\n\nBody" }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Extra-Blank-Lines@@Tests/FormattingBlocks.wlt:359,1-367,2"
]

(* Headings at the very start and end of the response: *)
VerificationTest[
    blocksNormalized /@ { "## Start\n\nBody", "Body\n\n## End heading", "## H\n", "\n\n## H\n\n" },
    {
        { blocksSection @ blocksTextBox[ "Start" ], "\nBody" },
        { "Body\n", blocksSection @ blocksTextBox[ "End heading" ] },
        { blocksSection @ blocksTextBox[ "H" ] },
        { blocksSection @ blocksTextBox[ "H" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Start-And-End@@Tests/FormattingBlocks.wlt:370,1-380,2"
]

VerificationTest[
    blocksNormalized[ "Text\n\n## A\n## B\n### C" ],
    {
        "Text\n",
        blocksSection @ blocksTextBox[ "A" ],
        "\n",
        blocksSection @ blocksTextBox[ "B" ],
        "\n",
        blocksHeading[ blocksTextBox[ "C" ], "Subsection", Inherited, { { 0, 0 }, { 5, 15 } } ]
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Consecutive@@Tests/FormattingBlocks.wlt:382,1-394,2"
]

(* When serialized, headings are surrounded by blank lines: *)
VerificationTest[
    blocksRoundTrip /@ { "Intro\n## Heading\nBody text", "Text\n\n## A\n## B\n### C" },
    { "Intro\n\n## Heading\n\nBody text", "Text\n\n## A\n\n## B\n\n### C" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Serialization-Spacing@@Tests/FormattingBlocks.wlt:397,1-402,2"
]

(* Headings directly before and after list items. When serialized, they are surrounded by blank lines: *)
VerificationTest[
    {
        blocksNormalized /@ { "- a\n## H", "## H\n- a", "- a\n\n## H\n\n- b" },
        blocksRoundTrip /@ { "- a\n## H", "## H\n- a", "- a\n\n## H\n\n- b" }
    },
    {
        {
            { blocksItem[ " a" ], "\n", blocksSection @ blocksTextBox[ "H" ] },
            { blocksSection @ blocksTextBox[ "H" ], "\n", blocksItem[ " a" ] },
            { blocksItem[ " a" ], "\n", blocksSection @ blocksTextBox[ "H" ], "\n", blocksItem[ " b" ] }
        },
        { "* a\n\n## H", "## H\n\n* a", "* a\n\n## H\n\n* b" }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Next-To-Lists@@Tests/FormattingBlocks.wlt:405,1-420,2"
]

(* Trailing spaces after the heading text are invisible and are dropped when serialized: *)
VerificationTest[
    MarkdownRoundTrip[ "## Heading   \nText" ],
    "## Heading\n\nText",
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Trailing-Spaces-Serialization@@Tests/FormattingBlocks.wlt:423,1-428,2"
]

(* Headings next to code blocks, with or without blank lines in between: *)
VerificationTest[
    Table[
        blocksNormalized[ md, status ],
        { md, { "```wl\n1+1\n```\n## After code", "## Before code\n```wl\n1+1\n```" } },
        { status, { "Finished", "Streaming" } }
    ],
    {
        {
            { $$blocksCodeBlock, "\n", blocksSection @ blocksTextBox[ "After code" ] },
            { $$blocksCodeBlock, "\n", blocksSection @ blocksTextBox[ "After code" ] }
        },
        {
            { blocksSection @ blocksTextBox[ "Before code" ], "\n", $$blocksCodeBlock },
            { blocksSection @ blocksTextBox[ "Before code" ], "\n", $$blocksCodeBlock }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Next-To-Code-Block@@Tests/FormattingBlocks.wlt:431,1-449,2"
]

VerificationTest[
    blocksRoundTrip /@ { "```wl\n1+1\n```\n## After code", "## Before code\n```wl\n1+1\n```" },
    { "```wl\n1 + 1\n```\n\n## After code", "## Before code\n\n```wl\n1 + 1\n```" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Heading-Next-To-Code-Block-Serialization@@Tests/FormattingBlocks.wlt:451,1-456,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Bullet Lists*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Items*)

(* Each item is an "InlineItem" cell holding a colored bullet character, a space, and the formatted item text. Items
   are separated by line breaks: *)
VerificationTest[
    blocksNormalized[ "* one\n* two" ],
    {
        Cell[ TextData @ { StyleBox[ "\[Bullet]", FontColor -> _ ], " one" }, "InlineItem" ],
        "\n",
        Cell[ TextData @ { StyleBox[ "\[Bullet]", FontColor -> _ ], " two" }, "InlineItem" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Structure@@Tests/FormattingBlocks.wlt:468,1-477,2"
]

(* "- " and "* " make the same items: *)
VerificationTest[
    FormatMarkdown[ "- one\n- two" ] === FormatMarkdown[ "* one\n* two" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Hyphen-Same-As-Asterisk@@Tests/FormattingBlocks.wlt:480,1-485,2"
]

(* Items always serialize with "*": *)
VerificationTest[
    MarkdownRoundTrip /@ { "- one\n- two", "* one\n* two" },
    { "* one\n* two", "* one\n* two" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Serialization@@Tests/FormattingBlocks.wlt:488,1-493,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Nested Items*)

(* An indented item is an "InlineSubitem" cell, and the indentation is kept in front of the bullet: *)
VerificationTest[
    blocksNormalized[ "- one\n  - nested\n    - deeper\n- back" ],
    {
        blocksItem[ " one" ],
        "\n",
        blocksSubitem[ "  ", " nested" ],
        "\n",
        blocksSubitem[ "    ", " deeper" ],
        "\n",
        blocksItem[ " back" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Nested@@Tests/FormattingBlocks.wlt:500,1-513,2"
]

VerificationTest[
    MarkdownRoundTrip[ "- one\n  - nested\n    - deeper\n- back" ],
    "* one\n  * nested\n    * deeper\n* back",
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Nested-Serialization@@Tests/FormattingBlocks.wlt:515,1-520,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Inline Formatting in Items*)

VerificationTest[
    blocksNormalized[ "- **bold** item\n- item with `Plot`\n- [link](https://example.com)\n- *italic*\n- ***both***" ],
    {
        blocksItem[ " ", StyleBox[ "bold", FontWeight -> Bold ], " item" ],
        "\n",
        blocksItem[ " item with ", $$blocksPlotLink ],
        "\n",
        blocksItem[ " ", $$blocksExampleLink ],
        "\n",
        blocksItem[ " ", StyleBox[ "italic", FontSlant -> Italic ] ],
        "\n",
        blocksItem[ " ", StyleBox[ "both", FontWeight -> Bold, FontSlant -> Italic ] ]
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Inline-Formatting@@Tests/FormattingBlocks.wlt:526,1-541,2"
]

VerificationTest[
    MarkdownRoundTrip[ "- **bold** item\n- item with `Plot`\n- [link](https://example.com)\n- *italic*\n- ***both***" ],
    "* **bold** item\n* item with [Plot](paclet:ref/Plot)\n* [link](https://example.com)\n* *italic*\n* ***both***",
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Inline-Formatting-Serialization@@Tests/FormattingBlocks.wlt:543,1-548,2"
]

(* A bold label at the start of an item, as LLMs often write: *)
VerificationTest[
    blocksNormalized[ "- **Note:** description here" ],
    { blocksItem[ " ", StyleBox[ "Note:", FontWeight -> Bold ], " description here" ] },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Bold-Label@@Tests/FormattingBlocks.wlt:551,1-556,2"
]

(* With the "* " marker, emphasis asterisks right after the marker belong to the item text: *)
VerificationTest[
    {
        blocksNormalized[ "* **Bold**: text\n* *italic* item" ],
        MarkdownRoundTrip[ "* **Bold**: text\n* *italic* item" ]
    },
    {
        {
            blocksItem[ " ", StyleBox[ "Bold", FontWeight -> Bold ], ": text" ],
            "\n",
            blocksItem[ " ", StyleBox[ "italic", FontSlant -> Italic ], " item" ]
        },
        "* **Bold**: text\n* *italic* item"
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Asterisk-Marker-With-Emphasis@@Tests/FormattingBlocks.wlt:559,1-574,2"
]

(* Item text is formatted as inline text only, so other markers in it are left as text: *)
VerificationTest[
    blocksNormalized /@ { "- a - b", "- 1. nested number", "- [ ] task\n- [x] done", "- item &lt;tag&gt;" },
    {
        { blocksItem[ " a - b" ] },
        { blocksItem[ " 1. nested number" ] },
        { blocksItem[ " [ ] task" ], "\n", blocksItem[ " [x] done" ] },
        { blocksItem[ " item <tag>" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Item-Text@@Tests/FormattingBlocks.wlt:577,1-587,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Spacing Around Lists*)

(* A list right after a paragraph, with or without a blank line. The bullet rule consumes all line breaks before the
   item, so the spacing before the list is the same either way: *)
VerificationTest[
    blocksNormalized /@ { "Intro:\n- one\n- two\n\nAfter", "Intro:\n\n- one\n- two\n\nAfter", "Text\n\n\n\n- one" },
    {
        { "Intro:\n", blocksItem[ " one" ], "\n", blocksItem[ " two" ], "\nAfter" },
        { "Intro:\n", blocksItem[ " one" ], "\n", blocksItem[ " two" ], "\nAfter" },
        { "Text\n", blocksItem[ " one" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-After-Paragraph@@Tests/FormattingBlocks.wlt:595,1-604,2"
]

(* Blank lines between items are dropped, so consecutive lists merge into one: *)
VerificationTest[
    blocksNormalized /@ { "- one\n- two\n\n- three", "- a\n\n\n- b" },
    {
        { blocksItem[ " one" ], "\n", blocksItem[ " two" ], "\n", blocksItem[ " three" ] },
        { blocksItem[ " a" ], "\n", blocksItem[ " b" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Blank-Lines-Between-Items@@Tests/FormattingBlocks.wlt:607,1-615,2"
]

(* A line that follows an item without a marker is plain text on the next line: *)
VerificationTest[
    blocksNormalized /@ { "- item\ncontinuation line", "* item\n**Bold** after", "**Bold** text\n* item" },
    {
        { blocksItem[ " item" ], "\ncontinuation line" },
        { blocksItem[ " item" ], "\n", StyleBox[ "Bold", FontWeight -> Bold ], " after" },
        { StyleBox[ "Bold", FontWeight -> Bold ], " text\n", blocksItem[ " item" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Adjacent-Text@@Tests/FormattingBlocks.wlt:618,1-627,2"
]

(* Leading and trailing blank lines around a list that is the whole response are trimmed: *)
VerificationTest[
    blocksNormalized[ "\n\n- a\n\n" ],
    { blocksItem[ " a" ] },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Trimmed@@Tests/FormattingBlocks.wlt:630,1-635,2"
]

VerificationTest[
    blocksRoundTrip /@ { "Intro:\n\n- one\n- two", "- one\n- two\n\n- three" },
    { "Intro:\n* one\n* two", "* one\n* two\n* three" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Spacing-Serialization@@Tests/FormattingBlocks.wlt:637,1-642,2"
]

VerificationTest[
    Table[ blocksNormalized[ "- item\n```wl\n1+1\n```", status ], { status, { "Finished", "Streaming" } } ],
    { { blocksItem[ " item" ], "\n", $$blocksCodeBlock }, { blocksItem[ " item" ], "\n", $$blocksCodeBlock } },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Before-Code-Block@@Tests/FormattingBlocks.wlt:644,1-649,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Not Bullets*)

(* A bullet needs a space after the marker, and only "*" and "-" are markers: *)
VerificationTest[
    FormatMarkdown /@ { "-not a bullet", "*not a bullet*", "- ", "a - b", "\[Bullet] item one\n\[Bullet] item two" },
    {
        { "-not a bullet" },
        { StyleBox[ "not a bullet", FontSlant -> Italic ] },
        { "-" },
        { "a - b" },
        { "\[Bullet] item one\n\[Bullet] item two" }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Not-Bullets@@Tests/FormattingBlocks.wlt:656,1-667,2"
]

(* "+" is not a bullet marker, so the text stays as written: *)
VerificationTest[
    { FormatMarkdown[ "+ plus one\n+ plus two" ], MarkdownRoundTrip[ "+ plus one\n+ plus two" ] },
    { { "+ plus one\n+ plus two" }, "+ plus one\n+ plus two" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Plus-Plain-Text@@Tests/FormattingBlocks.wlt:670,1-675,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Numbered Lists*)

(* Numbered lists have no special formatting. They stay plain text, which reads the same as the markdown. Inline
   formatting still applies: *)
VerificationTest[
    FormatMarkdown /@ {
        "1. first\n2. second\n3. third",
        "1) first\n2) second",
        "1. one\n\n2. two",
        "10. ten",
        "1. **First**: desc\n2. Second"
    },
    {
        { "1. first\n2. second\n3. third" },
        { "1) first\n2) second" },
        { "1. one\n\n2. two" },
        { "10. ten" },
        { "1. ", StyleBox[ "First", FontWeight -> Bold ], ": desc\n2. Second" }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Numbered-Plain-Text@@Tests/FormattingBlocks.wlt:683,1-700,2"
]

VerificationTest[
    MarkdownRoundTrip /@ { "1. first\n2. second\n3. third", "1) first\n2) second", "1. **First**: desc\n2. Second" },
    { "1. first\n2. second\n3. third", "1) first\n2) second", "1. **First**: desc\n2. Second" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Numbered-Serialization@@Tests/FormattingBlocks.wlt:702,1-707,2"
]

(* Bullets nested under a numbered item are subitems: *)
VerificationTest[
    blocksNormalized[ "1. first\n   - sub\n2. second" ],
    { "1. first\n", blocksSubitem[ "   ", " sub" ], "\n2. second" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Numbered-With-Bullets@@Tests/FormattingBlocks.wlt:710,1-715,2"
]

VerificationTest[
    blocksRoundTrip[ "1. first\n   - sub\n2. second" ],
    "1. first\n   * sub\n2. second",
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Numbered-With-Bullets-Serialization@@Tests/FormattingBlocks.wlt:717,1-722,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Streaming*)

(* A bare marker stays text until the item has some text: *)
VerificationTest[
    blocksNormalized[ #, "Streaming" ] & /@ { "- ", "- it", "Text\n\n- ", "- a\n- b\n  - c" },
    {
        { "-" },
        { blocksItem[ " it" ] },
        { "Text\n\n-" },
        { blocksItem[ " a" ], "\n", blocksItem[ " b" ], "\n", blocksSubitem[ "  ", " c" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-List-Streaming@@Tests/FormattingBlocks.wlt:729,1-739,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Horizontal Rules*)

(* A horizontal rule is a "MarkdownDelimiter" cell with a grid whose row divider draws the line: *)
VerificationTest[
    FormatMarkdown[ "---" ],
    {
        Cell[
            BoxData @ TagBox[
                GridBox[
                    { { TemplateBox[ { 0 }, "Spacer1" ] }, { TemplateBox[ { 0 }, "Spacer1" ] } },
                    OrderlessPatternSequence[
                        AutoDelete      -> False,
                        GridBoxDividers -> {
                            "Columns" -> { False, { True }, False },
                            "Rows"    -> { False, { True }, False }
                        },
                        GridBoxItemSize -> { "Columns" -> { { Fit } }, "Rows" -> { { Automatic } } },
                        FrameStyle      -> Directive[ _, AbsoluteThickness[ 1 ] ]
                    ]
                ],
                "Grid"
            ],
            "MarkdownDelimiter",
            OrderlessPatternSequence[ Background -> None, ShowStringCharacters -> False ]
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Delimiter-Structure@@Tests/FormattingBlocks.wlt:746,1-771,2"
]

(* Three or more "-", "*", or "_" characters on a line of their own all make the same rule: *)
VerificationTest[
    Union[ FormatMarkdown /@ { "---", "***", "___", "----------", "*****", "______" } ],
    { { $$blocksDelimiter } },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Delimiter-Variants@@Tests/FormattingBlocks.wlt:774,1-779,2"
]

VerificationTest[
    MarkdownRoundTrip /@ { "---", "***", "___", "----------", "*****", "______" },
    { "---", "---", "---", "---", "---", "---" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Delimiter-Serialization@@Tests/FormattingBlocks.wlt:781,1-786,2"
]

(* Blank lines around a rule are optional. Unlike headings and bullets, the rule doesn't consume the line breaks
   around it. A "\n\n" next to the rule becomes a single line break, so extra blank lines are kept. A line of "---"
   right after text is also a rule (not a setext heading): *)
VerificationTest[
    blocksNormalized /@ {
        "Above\n\n---\n\nBelow",
        "Above\n---\nBelow",
        "Above\n\n\n---\n\n\nBelow",
        "Text\n\n---\nMore\n***\nEnd"
    },
    {
        { "Above\n", $$blocksDelimiter, "\nBelow" },
        { "Above\n", $$blocksDelimiter, "\nBelow" },
        { "Above\n\n", $$blocksDelimiter, "\n\nBelow" },
        { "Text\n", $$blocksDelimiter, "\nMore\n", $$blocksDelimiter, "\nEnd" }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Delimiter-Between-Paragraphs@@Tests/FormattingBlocks.wlt:791,1-806,2"
]

(* Rules next to other blocks: *)
VerificationTest[
    blocksNormalized /@ { "---\n---", "- a\n---\n- b", "- a\n\n---", "## H\n---", "---\n## H" },
    {
        { $$blocksDelimiter, "\n", $$blocksDelimiter },
        { blocksItem[ " a" ], "\n", $$blocksDelimiter, "\n", blocksItem[ " b" ] },
        { blocksItem[ " a" ], "\n", $$blocksDelimiter },
        { blocksSection @ blocksTextBox[ "H" ], "\n", $$blocksDelimiter },
        { $$blocksDelimiter, "\n", blocksSection @ blocksTextBox[ "H" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Delimiter-Adjacent-Blocks@@Tests/FormattingBlocks.wlt:809,1-820,2"
]

(* When serialized, rules are surrounded by blank lines: *)
VerificationTest[
    blocksRoundTrip /@ { "Above\n---\nBelow", "Above\n\n\n---\n\n\nBelow", "---\n---", "- a\n---\n- b", "## H\n---" },
    { "Above\n\n---\n\nBelow", "Above\n\n---\n\nBelow", "---\n\n---", "* a\n\n---\n\n* b", "## H\n\n---" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Delimiter-Serialization-Spacing@@Tests/FormattingBlocks.wlt:823,1-828,2"
]

(* Fewer than three characters, mixed characters, or other text on the line: *)
VerificationTest[
    FormatMarkdown /@ { "--", "Text --- more", "-*-", "---text" },
    { { "--" }, { "Text --- more" }, { "-*-" }, { "---text" } },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Delimiter-Not-Delimiters@@Tests/FormattingBlocks.wlt:831,1-836,2"
]

VerificationTest[
    blocksNormalized[ #, "Streaming" ] & /@ { "--", "---", "Text\n\n---" },
    { { "--" }, { $$blocksDelimiter }, { "Text\n", $$blocksDelimiter } },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Delimiter-Streaming@@Tests/FormattingBlocks.wlt:838,1-843,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Block Quotes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Structure*)

(* A block quote is a "BlockQuote" cell with a one-cell grid. The grid draws the background and a thick left
   border. The quote text is in a full-width pane with a "Text" base style: *)
VerificationTest[
    FormatMarkdown[ "> A quote" ],
    {
        Cell[
            BoxData @ GridBox[
                {
                    {
                        PaneBox[
                            blocksTextBox[ "A quote" ],
                            OrderlessPatternSequence[
                                ImageMargins -> 5,
                                ImageSize    -> { Full, Automatic },
                                BaseStyle    -> { "Text", FontColor -> _ }
                            ]
                        ]
                    }
                },
                OrderlessPatternSequence[
                    AutoDelete        -> False,
                    GridBoxBackground -> { "Columns" -> { { _ } } },
                    GridBoxDividers   -> {
                        "ColumnsIndexed" -> { 1 -> Directive[ _, AbsoluteThickness[ 4 ] ] },
                        "Rows"           -> { { False } }
                    },
                    GridBoxItemSize   -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } }
                ]
            ],
            "BlockQuote",
            Background -> None
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-BlockQuote-Structure@@Tests/FormattingBlocks.wlt:855,1-888,2"
]

(* Consecutive quoted lines form one quote, with the ">" markers removed from each line. The space after ">" is
   optional, and extra spaces are removed: *)
VerificationTest[
    FormatMarkdown /@ { "> line one\n> line two", ">no space", ">  extra spaces" },
    {
        { blocksQuote @ blocksTextBox[ "line one\nline two" ] },
        { blocksQuote @ blocksTextBox[ "no space" ] },
        { blocksQuote @ blocksTextBox[ "extra spaces" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-BlockQuote-Lines@@Tests/FormattingBlocks.wlt:892,1-901,2"
]

(* A line with only ">" (or "> ") inside a quote is a blank line in the quote: *)
VerificationTest[
    FormatMarkdown /@ { "> q1\n>\n> q2", "> a\n> \n> b" },
    { { blocksQuote @ blocksTextBox[ "q1\n\nq2" ] }, { blocksQuote @ blocksTextBox[ "a\n\nb" ] } },
    SameTest -> MatchQ,
    TestID   -> "Blocks-BlockQuote-Blank-Quote-Line@@Tests/FormattingBlocks.wlt:904,1-909,2"
]

(* Quotes separated by a blank line are separate quotes: *)
VerificationTest[
    blocksNormalized[ "> q1\n\n> q2" ],
    { blocksQuote @ blocksTextBox[ "q1" ], "\n", blocksQuote @ blocksTextBox[ "q2" ] },
    SameTest -> MatchQ,
    TestID   -> "Blocks-BlockQuote-Separate-Quotes@@Tests/FormattingBlocks.wlt:912,1-917,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Inline Formatting in Quotes*)

VerificationTest[
    FormatMarkdown[ "> **bold** and `Plot` and *it*" ],
    {
        blocksQuote @ blocksTextCell[
            StyleBox[ "bold", FontWeight -> Bold ],
            " and ",
            $$blocksPlotLink,
            " and ",
            StyleBox[ "it", FontSlant -> Italic ]
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-BlockQuote-Inline-Formatting@@Tests/FormattingBlocks.wlt:923,1-936,2"
]

(* Quotes with formatted content serialize back to quoted markdown: *)
VerificationTest[
    MarkdownRoundTrip[ "> **bold** and `Plot` and *it*" ],
    "> **bold** and [Plot](paclet:ref/Plot) and *it*",
    SameTest -> MatchQ,
    TestID   -> "Blocks-BlockQuote-Inline-Formatting-Serialization@@Tests/FormattingBlocks.wlt:939,1-944,2"
]

(* A quote that is entirely bold or italic: *)
VerificationTest[
    { FormatMarkdown /@ { "> **Note**", "> *all italic*" }, MarkdownRoundTrip /@ { "> **Note**", "> *all italic*" } },
    {
        {
            { blocksQuote @ blocksTextCell @ StyleBox[ "Note", FontWeight -> Bold ] },
            { blocksQuote @ blocksTextCell @ StyleBox[ "all italic", FontSlant -> Italic ] }
        },
        { "> **Note**", "> *all italic*" }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-BlockQuote-Fully-Formatted@@Tests/FormattingBlocks.wlt:947,1-958,2"
]

VerificationTest[
    FormatMarkdown[ "> quote &amp; more" ],
    { blocksQuote @ blocksTextBox[ "quote & more" ] },
    SameTest -> MatchQ,
    TestID   -> "Blocks-BlockQuote-HTML-Entity@@Tests/FormattingBlocks.wlt:960,1-965,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Spacing Around Quotes*)

VerificationTest[
    blocksNormalized /@ { "Before\n\n> quoted\n\nAfter", "Before\n> quoted", "Text\n\n\n> q" },
    {
        { "Before\n", blocksQuote @ blocksTextBox[ "quoted" ], "\nAfter" },
        { "Before\n", blocksQuote @ blocksTextBox[ "quoted" ] },
        { "Text\n\n", blocksQuote @ blocksTextBox[ "q" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-BlockQuote-Between-Paragraphs@@Tests/FormattingBlocks.wlt:971,1-980,2"
]

(* Quotes next to other blocks, separated by a blank line after the quote: *)
VerificationTest[
    blocksNormalized /@ { "## Heading\n> quote", "## H\n\n> q", "- a\n> q", "> q\n\n## H", "> q\n\n- a" },
    {
        { blocksSection @ blocksTextBox[ "Heading" ], "\n", blocksQuote @ blocksTextBox[ "quote" ] },
        { blocksSection @ blocksTextBox[ "H" ], "\n", blocksQuote @ blocksTextBox[ "q" ] },
        { blocksItem[ " a" ], "\n", blocksQuote @ blocksTextBox[ "q" ] },
        { blocksQuote @ blocksTextBox[ "q" ], "\n", blocksSection @ blocksTextBox[ "H" ] },
        { blocksQuote @ blocksTextBox[ "q" ], "\n", blocksItem[ " a" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-BlockQuote-Adjacent-Blocks@@Tests/FormattingBlocks.wlt:983,1-994,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Not Quotes*)

VerificationTest[
    FormatMarkdown /@ { "a > b", ">", "x >= y" },
    { { "a > b" }, { ">" }, { "x >= y" } },
    SameTest -> MatchQ,
    TestID   -> "Blocks-BlockQuote-Not-Quotes@@Tests/FormattingBlocks.wlt:1000,1-1005,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Streaming*)

VerificationTest[
    FormatMarkdown[ #, "Streaming" ] & /@ { "> qu", "> " },
    { { blocksQuote @ blocksTextBox[ "qu" ] }, { blocksQuote @ blocksTextBox[ "" ] } },
    SameTest -> MatchQ,
    TestID   -> "Blocks-BlockQuote-Streaming@@Tests/FormattingBlocks.wlt:1011,1-1016,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paragraphs and Line Breaks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Line Breaks Between Paragraphs*)

(* Line breaks in plain text are kept as they are, including extra blank lines: *)
VerificationTest[
    FormatMarkdown /@ {
        "Line one\nLine two",
        "Para one\n\nPara two",
        "Para one\n\n\nPara two",
        "Para one\n\n\n\nPara two"
    },
    {
        { "Line one\nLine two" },
        { "Para one\n\nPara two" },
        { "Para one\n\n\nPara two" },
        { "Para one\n\n\n\nPara two" }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-Line-Breaks@@Tests/FormattingBlocks.wlt:1027,1-1042,2"
]

(* Serialization collapses runs of blank lines into one: *)
VerificationTest[
    MarkdownRoundTrip /@ {
        "Line one\nLine two",
        "Para one\n\nPara two",
        "Para one\n\n\nPara two",
        "Para one\n\n\n\nPara two"
    },
    { "Line one\nLine two", "Para one\n\nPara two", "Para one\n\nPara two", "Para one\n\nPara two" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-Line-Breaks-Serialization@@Tests/FormattingBlocks.wlt:1045,1-1055,2"
]

(* Text that ends with a single line break right before a block cell gets a space before the line break. This was
   added to fix bad line breaking in the front end when a text newline is followed by an inline cell (fe31de80): *)
VerificationTest[
    First @ FormatMarkdown[ # ] & /@ {
        "Intro\n## H",
        "Intro\n\n## H",
        "Intro\n- a",
        "Intro\n\n---",
        "Intro\n\n> q",
        "Intro\n\n```wl\n1+1\n```"
    },
    { "Intro \n", "Intro \n", "Intro \n", "Intro \n", "Intro \n", "Intro \n" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-Space-Before-Block-Line-Break@@Tests/FormattingBlocks.wlt:1059,1-1071,2"
]

(* Text after a block cell starts with a single line break, also when there's a blank line in the markdown (so no
   blank line is shown after a list). The line break that each block adds before itself is dropped when the block
   starts the response: *)
VerificationTest[
    blocksNormalized /@ { "## H\n\nBody", "- a\n\nBody", "---\n\nBody", "> q\n\nBody" },
    {
        { blocksSection @ blocksTextBox[ "H" ], "\nBody" },
        { blocksItem[ " a" ], "\nBody" },
        { $$blocksDelimiter, "\nBody" },
        { blocksQuote @ blocksTextBox[ "q" ], "\nBody" }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-Text-After-Block@@Tests/FormattingBlocks.wlt:1076,1-1086,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Leading and Trailing Whitespace*)

(* An empty or whitespace-only response gives no visible content: *)
VerificationTest[
    blocksNormalized /@ { "", "\n", " ", "  \n\n  " },
    { { }, { }, { }, { } },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-Empty-Response@@Tests/FormattingBlocks.wlt:1093,1-1098,2"
]

(* Whitespace at the start and end of the whole response is trimmed: *)
VerificationTest[
    FormatMarkdown /@ { "  \n\nLeading and trailing\n\n  ", "\n\n\nText\n\n\n", "   spaces   " },
    { { "Leading and trailing" }, { "Text" }, { "spaces" } },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-Trim-Response@@Tests/FormattingBlocks.wlt:1101,1-1106,2"
]

VerificationTest[
    blocksNormalized /@ { "  \n## H", "\n\n## H\n\n", "\n\n---\n\n", "\n\n> q\n\n" },
    {
        { blocksSection @ blocksTextBox[ "H" ] },
        { blocksSection @ blocksTextBox[ "H" ] },
        { $$blocksDelimiter },
        { blocksQuote @ blocksTextBox[ "q" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-Trim-Around-Blocks@@Tests/FormattingBlocks.wlt:1108,1-1118,2"
]

(* Trailing spaces at the end of a line (a markdown hard line break) give a normal line break. The spaces themselves
   are invisible, so they're ignored here: *)
VerificationTest[
    { blocksNormalized[ "Text  \nwith trailing spaces" ], blocksRoundTrip[ "Text  \nwith trailing spaces" ] },
    { { "Text\nwith trailing spaces" }, "Text\nwith trailing spaces" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-Trailing-Spaces@@Tests/FormattingBlocks.wlt:1122,1-1127,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Stray Code Fences*)

(* A code fence that doesn't open a code block is removed from the start or end of a text part: *)
VerificationTest[
    FormatMarkdown /@ { "Text\n```", "Text\n\n```", "Some text\n\n```\n", "foo```" },
    { { "Text" }, { "Text" }, { "Some text" }, { "foo" } },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-Stray-Fence@@Tests/FormattingBlocks.wlt:1134,1-1139,2"
]

(* An extra closing fence after a code block is removed as well: *)
VerificationTest[
    FormatMarkdown[ "```wl\n1+1\n```\n```" ],
    { $$blocksCodeBlock },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-Stray-Fence-After-Code-Block@@Tests/FormattingBlocks.wlt:1142,1-1147,2"
]

(* A fence in the middle of a line is kept: *)
VerificationTest[
    FormatMarkdown[ "Text ``` here" ],
    { "Text ``` here" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-Fence-In-Text@@Tests/FormattingBlocks.wlt:1150,1-1155,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Line Endings*)

(* Headings and bullets are recognized with "\r\n" line endings, and their text has no "\r" (which the front end
   doesn't display correctly): *)
VerificationTest[
    blocksNormalized[ "## Heading\r\n\r\nText\r\n- item\r\n- item2" ],
    { blocksSection @ blocksTextBox[ "Heading" ], "\nText\n", blocksItem[ " item" ], "\n", blocksItem[ " item2" ] },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-CRLF-Blocks@@Tests/FormattingBlocks.wlt:1163,1-1168,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Other Text*)

VerificationTest[
    With[ { md = "Unicode: caf\[EAcute] \[LongDash] \:65e5\:672c\:8a9e \|01f389" },
        { FormatMarkdown @ md, MarkdownRoundTrip @ md } === { { md }, md }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-Unicode@@Tests/FormattingBlocks.wlt:1174,1-1181,2"
]

(* Indented code blocks and setext headings are not supported, so they stay plain text: *)
VerificationTest[
    FormatMarkdown /@ { "Text\n\n    code line", "Heading\n=====\n\nText" },
    { { "Text\n\n    code line" }, { "Heading\n=====\n\nText" } },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-Unsupported-Blocks@@Tests/FormattingBlocks.wlt:1184,1-1189,2"
]

(* Long lines and many blocks: *)
VerificationTest[
    {
        FormatMarkdown[ "## " <> StringRepeat[ "word ", 2000 ] ],
        Cases[
            FormatMarkdown @ StringRiffle[ Table[ "- item " <> ToString @ i, { i, 300 } ], "\n" ],
            Cell[ _, style_String, ___ ] :> style
        ],
        FormatMarkdown @ StringRiffle[ Table[ "> quoted line " <> ToString @ i, { i, 300 } ], "\n" ]
    },
    {
        { blocksSection[ heading_String /; StringCount[ heading, "word" ] === 2000 ] },
        ConstantArray[ "InlineItem", 300 ],
        { blocksQuote[ quote_String /; StringCount[ quote, "quoted line" ] === 300 && StringFreeQ[ quote, ">" ] ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Paragraph-Long-Input@@Tests/FormattingBlocks.wlt:1192,1-1208,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Text That Is Wolfram Language Code*)

(* When all of the text of a part is almost certainly WL code (a system symbol followed by brackets), it is formatted
   as inline WL code. This applies to a whole response, a list item, a heading, or a quote. Text that starts with
   something else is left alone: *)
VerificationTest[
    blocksNormalized /@ { "Range[10]", "- Plot[Sin[x], {x, 0, 1}]", "## Plot[x]", "> Plot[x]", "Intro\n\nRange[10]" },
    {
        { Cell[ BoxData[ _ ], "InlineWL", ___ ] },
        { blocksItem[ " ", Cell[ BoxData[ _ ], "InlineWL", ___ ] ] },
        { blocksSection @ blocksTextCell @ Cell[ BoxData[ _ ], "InlineWL", ___ ] },
        { blocksQuote @ blocksTextCell @ Cell[ BoxData[ _ ], "InlineWL", ___ ] },
        { "Intro\n\nRange[10]" }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-WL-Code-Text@@Tests/FormattingBlocks.wlt:1217,1-1228,2"
]

VerificationTest[
    MarkdownRoundTrip /@ { "Range[10]", "- Plot[Sin[x], {x, 0, 1}]", "## Plot[x]", "> Plot[x]" },
    { "``Range[10]``", "* ``Plot[Sin[x], {x, 0, 1}]``", "## ``Plot[x]``", "> ``Plot[x]``" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-WL-Code-Text-Serialization@@Tests/FormattingBlocks.wlt:1230,1-1235,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*HTML Entities*)

(* Named and numeric (decimal and hexadecimal) HTML entities are decoded: *)
VerificationTest[
    FormatMarkdown /@ {
        "Fish &amp; chips",
        "a &lt; b &gt; c",
        "&quot;quoted&quot;",
        "&hellip; and &mdash;",
        "&copy; 2024",
        "dash &#8212; here &#x2014; hex",
        "&#60;tag&#62; &#39;q&#39;",
        "&lt;&gt;"
    },
    {
        { "Fish & chips" },
        { "a < b > c" },
        { "\"quoted\"" },
        { "\[Ellipsis] and \[LongDash]" },
        { "\[Copyright] 2024" },
        { "dash \[LongDash] here \[LongDash] hex" },
        { "<tag> 'q'" },
        { "<>" }
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-HTMLEntities-Decoded@@Tests/FormattingBlocks.wlt:1242,1-1265,2"
]

(* Entity names are lowercased before they are decoded, so "&AMP;" works (it is also a valid HTML5 entity). This also
   lowercases entities like "&Eacute;" (see the entity quirks): *)
VerificationTest[
    FormatMarkdown[ "&AMP; upper" ],
    { "& upper" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-HTMLEntities-Case-Insensitive@@Tests/FormattingBlocks.wlt:1269,1-1274,2"
]

(* Unknown entities, text that is too long to be an entity, and a bare "&" are left alone: *)
VerificationTest[
    FormatMarkdown /@ { "&unknown; entity", "&notanentityatall;", "a & b", "&a;b&c;" },
    { { "&unknown; entity" }, { "&notanentityatall;" }, { "a & b" }, { "&a;b&c;" } },
    SameTest -> MatchQ,
    TestID   -> "Blocks-HTMLEntities-Unknown@@Tests/FormattingBlocks.wlt:1277,1-1282,2"
]

(* Entities are decoded before anything else is parsed, so they are decoded inside code too: *)
VerificationTest[
    {
        FormatMarkdown[ "Use `a &amp; b` code" ],
        MarkdownRoundTrip[ "Use `a &amp; b` code" ],
        MarkdownRoundTrip[ "```wl\nx &amp;&amp; y\n```" ]
    },
    {
        {
            "Use ",
            Cell[ BoxData @ TemplateBox[ { Cell[ "a & b", ___ ] }, "ChatCodeInlineTemplate" ], "ChatCodeActive" ],
            " code"
        },
        "Use ``a & b`` code",
        "```wl\nx && y\n```"
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-HTMLEntities-In-Code@@Tests/FormattingBlocks.wlt:1285,1-1302,2"
]

VerificationTest[
    MarkdownRoundTrip /@ { "Fish &amp; chips", "a &lt; b &gt; c", "- item &lt;tag&gt;" },
    { "Fish & chips", "a < b > c", "* item <tag>" },
    SameTest -> MatchQ,
    TestID   -> "Blocks-HTMLEntities-Serialization@@Tests/FormattingBlocks.wlt:1304,1-1309,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Rule Precedence*)

(* Code blocks are split out first, so block markers inside them are kept as code: *)
VerificationTest[
    FormatMarkdown[ "```\n## not heading\n- not item\n---\n> not quote\n```" ],
    {
        Cell[
            BoxData @ TemplateBox[
                { Cell[ "## not heading\n- not item\n---\n> not quote", ___ ], _ },
                "ChatCodeBlockTemplate"
            ],
            "ChatCodeBlock",
            ___
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Precedence-Code-Block-Content@@Tests/FormattingBlocks.wlt:1316,1-1330,2"
]

(* The heading text is whatever follows the "#" characters, even if it looks like a bullet: *)
VerificationTest[
    FormatMarkdown[ "# - x" ],
    { blocksHeading[ blocksTextBox[ "- x" ], "Title", 26, { { 0, 0 }, { 5, 15 } } ] },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Precedence-Heading-Content@@Tests/FormattingBlocks.wlt:1333,1-1338,2"
]

(* Escaped markdown characters give the same blocks as without escapes. This includes blocks in the text before a code
   block: *)
VerificationTest[
    {
        SameQ[
            blocksNormalized[ "## H\n\n- a\n\n> q\n\n---\n\nCost \\$5" ],
            blocksNormalized[ "## H\n\n- a\n\n> q\n\n---\n\nCost $5" ]
        ],
        SameQ[
            blocksNormalized[ "## H\n\nCost \\$5\n\n- a\n\n```wl\n1+1\n```" ],
            blocksNormalized[ "## H\n\nCost $5\n\n- a\n\n```wl\n1+1\n```" ]
        ]
    },
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Precedence-Escaped-Path-Same-Blocks@@Tests/FormattingBlocks.wlt:1342,1-1356,2"
]

(* Escapes inside block content are unescaped: *)
VerificationTest[
    blocksNormalized[ "## H \\$5\n- a \\*b\\*\n> q \\_x\\_" ],
    {
        blocksSection @ blocksTextBox[ "H $5" ],
        "\n",
        blocksItem[ " a *b*" ],
        "\n",
        blocksQuote @ blocksTextBox[ "q _x_" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Precedence-Escapes-In-Blocks@@Tests/FormattingBlocks.wlt:1359,1-1370,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Documents*)

(* A response that uses each block construct: *)
VerificationTest[
    blocksNormalized @ StringJoin[
        "# Title\n\nIntro paragraph.\n\n## Section\n\n",
        "- one\n- **two**\n  - sub\n\n---\n\n> quote\n\nEnd."
    ],
    {
        blocksHeading[ blocksTextBox[ "Title" ], "Title", 26, { { 0, 0 }, { 5, 15 } } ],
        "\nIntro paragraph.\n",
        blocksSection @ blocksTextBox[ "Section" ],
        "\n",
        blocksItem[ " one" ],
        "\n",
        blocksItem[ " ", StyleBox[ "two", FontWeight -> Bold ] ],
        "\n",
        blocksSubitem[ "  ", " sub" ],
        "\n",
        $$blocksDelimiter,
        "\n",
        blocksQuote @ blocksTextBox[ "quote" ],
        "\nEnd."
    },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Document-Structure@@Tests/FormattingBlocks.wlt:1377,1-1400,2"
]

(* Block constructs format the same way while streaming. The second streaming call gets the block cells from the
   streaming cache ($resultCellCache): *)
VerificationTest[
    With[ { md = "# Title\n\nIntro paragraph.\n\n## Section\n\n- one\n- **two**\n  - sub\n\n---\n\n> quote\n\nEnd." },
        { FormatMarkdown[ md, "Streaming" ] === FormatMarkdown @ md, FormatMarkdown[ md, "Streaming" ] === FormatMarkdown @ md }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Document-Streaming-Same@@Tests/FormattingBlocks.wlt:1404,1-1411,2"
]

VerificationTest[
    blocksRoundTrip[ "# Title\n\nIntro paragraph.\n\n## Section\n\n- one\n- **two**\n  - sub\n\n---\n\nEnd." ],
    "# Title\n\nIntro paragraph.\n\n## Section\n\n* one\n* **two**\n  * sub\n\n---\n\nEnd.",
    SameTest -> MatchQ,
    TestID   -> "Blocks-Document-Serialization@@Tests/FormattingBlocks.wlt:1413,1-1418,2"
]

(* Formatting the serialized markdown again gives the same output: *)
VerificationTest[
    Function[ md, blocksNormalized @ MarkdownRoundTrip @ md === blocksNormalized @ md ] /@ {
        "# Title\n\nIntro paragraph.\n\n## Section\n\n- one\n- **two**\n  - sub\n\n---\n\nEnd.",
        "Intro\n- one\n- two\n\nAfter",
        "- one\n  - nested\n- back",
        "Above\n\n---\n\nBelow",
        "## H\n- a\n- b\n## H2\nText"
    },
    { True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Blocks-Document-Reformat-Serialized@@Tests/FormattingBlocks.wlt:1421,1-1432,2"
]

(* :!CodeAnalysis::EndBlock:: *)
