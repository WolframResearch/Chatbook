(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/FormattingInline.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/FormattingInline.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* Characterization tests for inline (span-level) markdown: emphasis, inline code, links and the \[FreeformPrompt]
   character. Text is first split by `$textDataFormatRules` (block constructs, inline code, math), then each remaining
   text fragment is formatted by `formatTextString`, which applies `$stringFormatRules` (emphasis, links, \textit and
   \textbf, inline code again, ...). The text of list items, headings and block quotes goes straight to
   `formatTextString`. Several tests below depend on which of the two passes handles a construct. *)
VerificationTest[
    ClearAll[
        formatted,
        refLinkCell,
        codeTemplateCell,
        inlineWLCell,
        resourceFunctionBoxesQ,
        hyperlinkButton,
        bulletItemContent,
        innerTextData
    ];

    (* The formatted TextData items, without invisible differences in how adjacent text is split into strings: *)
    formatted[ md_String, status_: "Finished" ] := NormalizeTextData @ FormatMarkdown[ md, status ];

    (* A documentation link, as created for inline code that names a System symbol (e.g. `Plot`): *)
    refLinkCell[ label_String, name_String ] := Cell @ BoxData @ TemplateBox[
        { label, "paclet:ref/" <> name, "https://reference.wolfram.com/language/ref/" <> name <> ".html" },
        "TextRefLink"
    ];
    refLinkCell[ name_String ] := refLinkCell[ name, name ];

    (* Inline code that is displayed verbatim: *)
    codeTemplateCell[ code_ ] := Cell[
        BoxData @ TemplateBox[ { Cell[ code, Background -> None ] }, "ChatCodeInlineTemplate" ],
        "ChatCodeActive"
    ];

    (* Inline code that is displayed as syntax-colored Wolfram Language input. Additional options are added by
       emphasis (e.g. FontWeight -> Bold): *)
    inlineWLCell[ boxes_, extra___ ] := Cell[
        BoxData @ boxes,
        "InlineWL",
        "Input",
        OrderlessPatternSequence[
            LanguageCategory     -> "Input",
            ShowAutoStyles       -> True,
            ShowStringCharacters -> True,
            ShowSyntaxStyles     -> True,
            extra
        ]
    ];

    (* The resource function box for ResourceFunction[name]. Its internals come from the FunctionResource paclet, so
       only its tag and the function name are checked: *)
    resourceFunctionBoxesQ[ boxes_, name_String ] := With[ { s = ToString[ boxes, InputForm ] },
        StringContainsQ[ s, "FunctionResourceBox" ] && StringContainsQ[ s, name ]
    ];

    (* A web link: *)
    hyperlinkButton[ label_, url_String ] := ButtonBox[
        label,
        OrderlessPatternSequence[ BaseStyle -> "Hyperlink", ButtonData -> { URL @ url, None }, ButtonNote -> url ]
    ];

    (* The formatted content of a single list item (everything after the bullet and the space that follows it): *)
    bulletItemContent[ md_String, status_: "Finished" ] := Replace[
        formatted[ md, status ],
        {
            {
                Cell[
                    TextData @ { StyleBox[ "\[Bullet]", ___ ], first_String? (StringStartsQ[ " " ]), content___ },
                    "InlineItem",
                    ___
                ]
            } :> NormalizeTextData @ { StringDrop[ first, 1 ], content },
            other_ :> other
        }
    ];

    (* The style of the single cell that a heading or block quote creates, and its formatted text: *)
    innerTextData[ md_String ] := Replace[
        formatted @ md,
        {
            { cell: Cell[ _, style_String, ___ ] } :> {
                style,
                FirstCase[ cell, Cell[ TextData[ td_ ], ___ ] :> NormalizeTextData @ Flatten @ { td }, $Failed, Infinity ]
            },
            other_ :> other
        }
    ];,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Inline-Definitions@@Tests/FormattingInline.wlt:30,1-114,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Emphasis*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Asterisks*)

(* Three asterisks give bold italic, two give bold, one gives italic. Combined styles are StyleBox options: *)
VerificationTest[
    formatted[ "Some ***bold italic***, **bold**, and *italic* text" ],
    {
        "Some ",
        StyleBox[ "bold italic", OrderlessPatternSequence[ FontWeight -> Bold, FontSlant -> Italic ] ],
        ", ",
        StyleBox[ "bold", FontWeight -> Bold ],
        ", and ",
        StyleBox[ "italic", FontSlant -> Italic ],
        " text"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Asterisks@@Tests/FormattingInline.wlt:125,1-138,2"
]

(* Asterisk emphasis also works inside words (as in CommonMark), for bold as well as italic: *)
VerificationTest[
    {
        formatted[ "**bold**text and text**bold**" ],
        formatted[ "*a*b*c*" ],
        formatted[ "2*3*4" ]
    },
    {
        { StyleBox[ "bold", FontWeight -> Bold ], "text and text", StyleBox[ "bold", FontWeight -> Bold ] },
        { StyleBox[ "a", FontSlant -> Italic ], "b", StyleBox[ "c", FontSlant -> Italic ] },
        { "2", StyleBox[ "3", FontSlant -> Italic ], "4" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Intraword-Asterisks@@Tests/FormattingInline.wlt:141,1-154,2"
]

(* Multi-word emphasis and emphasis that is the whole response: *)
VerificationTest[
    {
        formatted[ "*multi word italic phrase*" ],
        formatted[ "**multi word bold phrase**" ],
        formatted[ "**Note:** text" ],
        formatted[ "**Note**: Use `Plot`." ]
    },
    {
        { StyleBox[ "multi word italic phrase", FontSlant -> Italic ] },
        { StyleBox[ "multi word bold phrase", FontWeight -> Bold ] },
        { StyleBox[ "Note:", FontWeight -> Bold ], " text" },
        { StyleBox[ "Note", FontWeight -> Bold ], ": Use ", refLinkCell[ "Plot" ], "." }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Multiple-Words@@Tests/FormattingInline.wlt:157,1-172,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Underscores*)

(* Underscores only mark emphasis at word boundaries (see also Markdown-Underscore-Emphasis and
   Markdown-Intraword-Underscores in Formatting.wlt). An opening or closing underscore next to a letter is literal: *)
VerificationTest[
    formatted /@ { "__bold__text", "text__bold__", "_a_b", "a_b_ c", "___a___b", "snake_case_name and x_1" },
    { { "__bold__text" }, { "text__bold__" }, { "_a_b" }, { "a_b_ c" }, { "___a___b" }, { "snake_case_name and x_1" } },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Underscore-Word-Boundaries@@Tests/FormattingInline.wlt:180,1-185,2"
]

(* Punctuation next to the underscores is a word boundary, so emphasis is applied: *)
VerificationTest[
    formatted[ "(_a_) [_b_] \"_c_\" _d_." ],
    {
        "(",
        StyleBox[ "a", FontSlant -> Italic ],
        ") [",
        StyleBox[ "b", FontSlant -> Italic ],
        "] \"",
        StyleBox[ "c", FontSlant -> Italic ],
        "\" ",
        StyleBox[ "d", FontSlant -> Italic ],
        "."
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Underscore-Punctuation-Boundaries@@Tests/FormattingInline.wlt:188,1-203,2"
]

(* Python-style dunder names that are not in backticks become bold, as they do in CommonMark: *)
VerificationTest[
    formatted[ "file_name.txt and __main__.py and __init__" ],
    { "file_name.txt and ", StyleBox[ "main", FontWeight -> Bold ], ".py and ", StyleBox[ "init", FontWeight -> Bold ] },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Dunder-Names@@Tests/FormattingInline.wlt:206,1-211,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Strikethrough*)

(* Two tildes give strikethrough (via FontVariations). A single tilde is literal: *)
VerificationTest[
    {
        formatted[ "Some ~~struck~~ text" ],
        formatted[ "~~a~~b" ],
        formatted[ "~a~ single" ]
    },
    {
        { "Some ", StyleBox[ "struck", FontVariations -> { "StrikeThrough" -> True } ], " text" },
        { StyleBox[ "a", FontVariations -> { "StrikeThrough" -> True } ], "b" },
        { "~a~ single" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Strikethrough@@Tests/FormattingInline.wlt:218,1-231,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Unmatched Markers*)

(* Markers without a partner are shown as is: *)
VerificationTest[
    formatted /@ { "**unclosed bold", "*unclosed italic", "~~unclosed", "__", "x * y", "a*b" },
    { { "**unclosed bold" }, { "*unclosed italic" }, { "~~unclosed" }, { "__" }, { "x * y" }, { "a*b" } },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Unmatched-Markers@@Tests/FormattingInline.wlt:238,1-243,2"
]

(* Emphasis never spans a line break (CommonMark allows it to span a single line break). Each rule explicitly requires
   text without "\n", so this looks intentional: it keeps a stray marker from pairing with one on a later line: *)
VerificationTest[
    formatted /@ {
        "**bold\nacross** lines",
        "*italic\nacross* lines",
        "~~strike\nacross~~ lines",
        "__bold\nacross__ lines",
        "***both\nacross*** lines"
    },
    {
        { "**bold\nacross** lines" },
        { "*italic\nacross* lines" },
        { "~~strike\nacross~~ lines" },
        { "__bold\nacross__ lines" },
        { "***both\nacross*** lines" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Not-Across-Lines@@Tests/FormattingInline.wlt:247,1-264,2"
]

(* Emphasis on either side of a line break is formatted separately, and the line break is kept (a "\r\n" as "\n"): *)
VerificationTest[
    {
        formatted[ "**x**\n**y**" ],
        formatted[ "A\nB *it*\nC" ],
        formatted[ "Line one with *it*\r\nLine two with **bold**" ],
        formatted[ "Text\n\n**Bold paragraph**\n\nMore" ]
    },
    {
        { StyleBox[ "x", FontWeight -> Bold ], "\n", StyleBox[ "y", FontWeight -> Bold ] },
        { "A\nB ", StyleBox[ "it", FontSlant -> Italic ], "\nC" },
        { "Line one with ", StyleBox[ "it", FontSlant -> Italic ], "\nLine two with ", StyleBox[ "bold", FontWeight -> Bold ] },
        { "Text\n\n", StyleBox[ "Bold paragraph", FontWeight -> Bold ], "\n\nMore" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Line-Breaks-Between@@Tests/FormattingInline.wlt:267,1-282,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Nested and Adjacent Emphasis*)

(* Emphasis that contains a single other emphasis is merged into one StyleBox with both styles: *)
VerificationTest[
    formatted /@ { "**_a_**", "__*a*__", "~~**both**~~", "**~~both~~**", "*~~a~~*", "~~*a*~~", "***~~all~~***" },
    {
        { StyleBox[ "a", OrderlessPatternSequence[ FontWeight -> Bold, FontSlant -> Italic ] ] },
        { StyleBox[ "a", OrderlessPatternSequence[ FontWeight -> Bold, FontSlant -> Italic ] ] },
        { StyleBox[ "both", OrderlessPatternSequence[ FontWeight -> Bold, FontVariations -> { "StrikeThrough" -> True } ] ] },
        { StyleBox[ "both", OrderlessPatternSequence[ FontWeight -> Bold, FontVariations -> { "StrikeThrough" -> True } ] ] },
        { StyleBox[ "a", OrderlessPatternSequence[ FontSlant -> Italic, FontVariations -> { "StrikeThrough" -> True } ] ] },
        { StyleBox[ "a", OrderlessPatternSequence[ FontSlant -> Italic, FontVariations -> { "StrikeThrough" -> True } ] ] },
        {
            StyleBox[
                "all",
                OrderlessPatternSequence[
                    FontWeight     -> Bold,
                    FontSlant      -> Italic,
                    FontVariations -> { "StrikeThrough" -> True }
                ]
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Nested-Combined-Styles@@Tests/FormattingInline.wlt:289,1-311,2"
]

(* Nesting the same style twice gives that style once (styleBox uses DeleteDuplicates): *)
VerificationTest[
    formatted /@ { "**__a__**", "*_a_*", "_*a*_", "\\textbf{**a**}" },
    {
        { StyleBox[ "a", FontWeight -> Bold ] },
        { StyleBox[ "a", FontSlant -> Italic ] },
        { StyleBox[ "a", FontSlant -> Italic ] },
        { StyleBox[ "a", FontWeight -> Bold ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Nested-Same-Style-Deduplicated@@Tests/FormattingInline.wlt:314,1-324,2"
]

(* Adjacent emphasis spans stay separate: *)
VerificationTest[
    formatted /@ {
        "**bold** *italic*",
        "**bold**_italic_",
        "**a** **b**",
        "a **b** c **d** e",
        "***a*** and ***b***",
        "~~a~~~~b~~"
    },
    {
        { StyleBox[ "bold", FontWeight -> Bold ], " ", StyleBox[ "italic", FontSlant -> Italic ] },
        { StyleBox[ "bold", FontWeight -> Bold ], StyleBox[ "italic", FontSlant -> Italic ] },
        { StyleBox[ "a", FontWeight -> Bold ], " ", StyleBox[ "b", FontWeight -> Bold ] },
        { "a ", StyleBox[ "b", FontWeight -> Bold ], " c ", StyleBox[ "d", FontWeight -> Bold ], " e" },
        {
            StyleBox[ "a", OrderlessPatternSequence[ FontWeight -> Bold, FontSlant -> Italic ] ],
            " and ",
            StyleBox[ "b", OrderlessPatternSequence[ FontWeight -> Bold, FontSlant -> Italic ] ]
        },
        {
            StyleBox[ "a", FontVariations -> { "StrikeThrough" -> True } ],
            StyleBox[ "b", FontVariations -> { "StrikeThrough" -> True } ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Adjacent@@Tests/FormattingInline.wlt:327,1-353,2"
]

(* Non-ASCII text in emphasis and inline code: *)
VerificationTest[
    formatted[ "Unicode **\[EAcute]t\[EAcute]** and *\:65e5\:672c* and `\[Alpha]` and **\:2764**" ],
    {
        "Unicode ",
        StyleBox[ "\[EAcute]t\[EAcute]", FontWeight -> Bold ],
        " and ",
        StyleBox[ "\:65e5\:672c", FontSlant -> Italic ],
        " and ",
        StyleBox[ "\[Alpha]", "TI" ],
        " and ",
        StyleBox[ "\:2764", FontWeight -> Bold ]
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Unicode@@Tests/FormattingInline.wlt:356,1-370,2"
]

(* Emphasis is applied at any position in a long line: *)
VerificationTest[
    formatted[ "Very long " <> StringRepeat[ "word ", 200 ] <> "**bold** end" ],
    { "Very long " <> StringRepeat[ "word ", 200 ], StyleBox[ "bold", FontWeight -> Bold ], " end" },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Long-Line@@Tests/FormattingInline.wlt:373,1-378,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Emphasis Containing Links and Code*)

(* Emphasis around a web link wraps the ButtonBox in a StyleBox: *)
VerificationTest[
    {
        formatted[ "*[link](https://example.com)*" ],
        formatted[ "**[ex](https://example.com)**" ]
    },
    {
        { StyleBox[ hyperlinkButton[ "link", "https://example.com" ], FontSlant -> Italic ] },
        { StyleBox[ hyperlinkButton[ "ex", "https://example.com" ], FontWeight -> Bold ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Around-Hyperlink@@Tests/FormattingInline.wlt:385,1-396,2"
]

(* Emphasis around a documentation link is dropped and only the link is shown (styleBox has a special case for
   TextRefLink cells): *)
VerificationTest[
    formatted[ "**[Plot](paclet:ref/Plot)**" ],
    { refLinkCell[ "Plot" ] },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Around-Ref-Link-Dropped@@Tests/FormattingInline.wlt:400,1-405,2"
]

(* In list items the whole item text goes through formatTextString, so emphasis around inline code is applied to the
   code cell: options are appended to the Cell or StyleBox. A documentation link drops the emphasis: *)
VerificationTest[
    bulletItemContent /@ { "- **`foo bar`**", "- *`foo`*", "- **`Plot[x]`**", "- **`Plot`**" },
    {
        {
            Cell[
                BoxData @ TemplateBox[ { Cell[ "foo bar", Background -> None ] }, "ChatCodeInlineTemplate" ],
                "ChatCodeActive",
                FontWeight -> Bold
            ]
        },
        { StyleBox[ "foo", "TI", FontSlant -> Italic ] },
        { inlineWLCell[ RowBox @ { "Plot", "[", "x", "]" }, FontWeight -> Bold ] },
        { refLinkCell[ "Plot" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Around-Inline-Code-In-List-Item@@Tests/FormattingInline.wlt:409,1-425,2"
]

(* The streaming display does not parse the code, but keeps the emphasis: *)
VerificationTest[
    bulletItemContent[ "- **`Plot[x]`**", "Streaming" ],
    { inlineWLCell[ "Plot[x]", FontWeight -> Bold ] },
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Around-Inline-Code-In-List-Item-Streaming@@Tests/FormattingInline.wlt:428,1-433,2"
]

(* Emphasis, inline code and links give the same output while streaming as when finished: *)
VerificationTest[
    With[ { md = "Use `Plot` (see [docs](https://example.com)) and **bold**, *it*, ~~old~~ and `x`." },
        { formatted @ md, formatted[ md, "Streaming" ] }
    ],
    ConstantArray[
        {
            "Use ",
            refLinkCell[ "Plot" ],
            " (see ",
            hyperlinkButton[ "docs", "https://example.com" ],
            ") and ",
            StyleBox[ "bold", FontWeight -> Bold ],
            ", ",
            StyleBox[ "it", FontSlant -> Italic ],
            ", ",
            StyleBox[ "old", FontVariations -> { "StrikeThrough" -> True } ],
            " and ",
            StyleBox[ "x", "TI" ],
            "."
        },
        2
    ],
    SameTest -> MatchQ,
    TestID   -> "Inline-Emphasis-Streaming-Same-As-Finished@@Tests/FormattingInline.wlt:436,1-460,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*TeX Text Commands*)

(* \textit{...} and \textbf{...} are formatted like markdown emphasis: *)
VerificationTest[
    {
        formatted[ "\\textit{italic text} and \\textbf{bold text}" ],
        formatted[ "\\textit{multiple words here}" ]
    },
    {
        { StyleBox[ "italic text", FontSlant -> Italic ], " and ", StyleBox[ "bold text", FontWeight -> Bold ] },
        { StyleBox[ "multiple words here", FontSlant -> Italic ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-TeX-Text-Commands@@Tests/FormattingInline.wlt:467,1-478,2"
]

(* Unlike markdown emphasis, the TeX commands can span a line break. They can be nested inside markdown emphasis (and
   the other way around), and adjacent commands stay separate: *)
VerificationTest[
    {
        formatted[ "\\textit{line\nbreak}" ],
        formatted[ "**\\textit{a}**" ],
        formatted[ "*\\textbf{a}*" ],
        formatted[ "\\textit{**bold**}" ],
        formatted[ "\\textbf{a}\\textbf{b}" ]
    },
    {
        { StyleBox[ "line\nbreak", FontSlant -> Italic ] },
        { StyleBox[ "a", OrderlessPatternSequence[ FontWeight -> Bold, FontSlant -> Italic ] ] },
        { StyleBox[ "a", OrderlessPatternSequence[ FontWeight -> Bold, FontSlant -> Italic ] ] },
        { StyleBox[ "bold", OrderlessPatternSequence[ FontWeight -> Bold, FontSlant -> Italic ] ] },
        { StyleBox[ "a", FontWeight -> Bold ], StyleBox[ "b", FontWeight -> Bold ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-TeX-Text-Commands-Line-Break-And-Nesting@@Tests/FormattingInline.wlt:482,1-499,2"
]

(* The commands are not formatted when the argument contains braces, is empty, or is not closed: *)
VerificationTest[
    formatted /@ { "\\textit{a{b}c}", "\\textit{unclosed", "\\textbf{x} \\textit{}" },
    { { "\\textit{a{b}c}" }, { "\\textit{unclosed" }, { StyleBox[ "x", FontWeight -> Bold ], " \\textit{}" } },
    SameTest -> MatchQ,
    TestID   -> "Inline-TeX-Text-Commands-Not-Formatted@@Tests/FormattingInline.wlt:502,1-507,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Code*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*System Symbols*)

(* Inline code that is the name of a System symbol becomes a documentation link (see also Inline-Code-Ref-Link* and
   Markdown-Escaped-Dollar-In-Inline-Code in Formatting.wlt): *)
VerificationTest[
    formatted[ "Use `Plot`, `ListPlot3D`, and `$Version`." ],
    { "Use ", refLinkCell[ "Plot" ], ", ", refLinkCell[ "ListPlot3D" ], ", and ", refLinkCell[ "$Version" ], "." },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-System-Symbol@@Tests/FormattingInline.wlt:519,1-524,2"
]

(* A context-qualified System name keeps its context in the label, but links to the plain name: *)
VerificationTest[
    formatted[ "Use `System`Plot` or ``System`Plot``" ],
    { "Use ", refLinkCell[ "System`Plot", "Plot" ], " or ", refLinkCell[ "System`Plot", "Plot" ] },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Context-Qualified-System-Symbol@@Tests/FormattingInline.wlt:527,1-532,2"
]

(* Inline code at the start or end of the text, and next to punctuation: *)
VerificationTest[
    {
        formatted[ "`Plot`" ],
        formatted[ "`Plot` at start" ],
        formatted[ "end with `Plot`" ],
        formatted[ "(`Plot`)" ],
        formatted[ "`Plot`/`ListPlot`" ]
    },
    {
        { refLinkCell[ "Plot" ] },
        { refLinkCell[ "Plot" ], " at start" },
        { "end with ", refLinkCell[ "Plot" ] },
        { "(", refLinkCell[ "Plot" ], ")" },
        { refLinkCell[ "Plot" ], "/", refLinkCell[ "ListPlot" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-System-Symbol-Positions@@Tests/FormattingInline.wlt:535,1-552,2"
]

(* A paragraph break after inline code is kept when other text comes between them. (Directly after the code, it
   currently collapses to a single line break, which is a known bug and not tested.) *)
VerificationTest[
    { formatted[ "Use `Plot`.\n\nNext" ], formatted[ "Use **bold**\n\nNext" ] },
    { { "Use ", refLinkCell[ "Plot" ], ".\n\nNext" }, { "Use ", StyleBox[ "bold", FontWeight -> Bold ], "\n\nNext" } },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Paragraph-Break@@Tests/FormattingInline.wlt:556,1-561,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Other Code*)

(* Names that are not System symbols (including other contexts, Chatbook's own symbols, and names that don't exist)
   are shown as verbatim code: *)
VerificationTest[
    formatted[ "Use `" <> # <> "` here" ] & /@ {
        "Wolfram",
        "CreateChatNotebook",
        "MyFunction",
        "Developer`ToPackedArray",
        "Global`x"
    },
    {
        { "Use ", codeTemplateCell[ "Wolfram" ], " here" },
        { "Use ", codeTemplateCell[ "CreateChatNotebook" ], " here" },
        { "Use ", codeTemplateCell[ "MyFunction" ], " here" },
        { "Use ", codeTemplateCell[ "Developer`ToPackedArray" ], " here" },
        { "Use ", codeTemplateCell[ "Global`x" ], " here" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Not-System-Symbol@@Tests/FormattingInline.wlt:569,1-586,2"
]

(* All-lowercase code is shown in the "TI" (italic variable) style instead of as code: *)
VerificationTest[
    formatted[ "Use `x`, `integrate`, and `\[Alpha]`" ],
    { "Use ", StyleBox[ "x", "TI" ], ", ", StyleBox[ "integrate", "TI" ], ", and ", StyleBox[ "\[Alpha]", "TI" ] },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Lowercase@@Tests/FormattingInline.wlt:589,1-594,2"
]

(* Code with any character that isn't a lowercase letter (including underscores and spaces) is verbatim code.
   Markdown markers inside inline code are not formatted: *)
VerificationTest[
    formatted[ "Use `" <> # <> "` here" ] & /@ {
        "foo_bar",
        "foo bar",
        "INTEGRATE",
        "x -> 1",
        "f[x_] := x^2",
        "a*b*c",
        "x_y_z",
        "#",
        "Plot@x"
    },
    {
        { "Use ", codeTemplateCell[ "foo_bar" ], " here" },
        { "Use ", codeTemplateCell[ "foo bar" ], " here" },
        { "Use ", codeTemplateCell[ "INTEGRATE" ], " here" },
        { "Use ", codeTemplateCell[ "x -> 1" ], " here" },
        { "Use ", codeTemplateCell[ "f[x_] := x^2" ], " here" },
        { "Use ", codeTemplateCell[ "a*b*c" ], " here" },
        { "Use ", codeTemplateCell[ "x_y_z" ], " here" },
        { "Use ", codeTemplateCell[ "#" ], " here" },
        { "Use ", codeTemplateCell[ "Plot@x" ], " here" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Verbatim@@Tests/FormattingInline.wlt:598,1-623,2"
]

(* Code with "*" is never a System symbol, even though NameQ treats "*" as a wildcard (nameQ excludes it): *)
VerificationTest[
    formatted[ "Use `Plot*`, `P*`, `*` and `**` here" ],
    {
        "Use ",
        codeTemplateCell[ "Plot*" ],
        ", ",
        codeTemplateCell[ "P*" ],
        ", ",
        codeTemplateCell[ "*" ],
        " and ",
        codeTemplateCell[ "**" ],
        " here"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Wildcard-Names@@Tests/FormattingInline.wlt:626,1-641,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Wolfram Language Code*)

(* Code that starts with a System symbol and either ends with a bracketed argument list or continues with a rule is
   parsed with the front end and shown as syntax-colored input: *)
VerificationTest[
    formatted[ "Use `Plot[x, {x, 0, 1}]`, `Rule -> 1` and `Rule :> 1` here" ],
    {
        "Use ",
        inlineWLCell @ RowBox @ {
            "Plot",
            "[",
            RowBox @ { "x", ",", RowBox @ { "{", RowBox @ { "x", ",", "0", ",", "1" }, "}" } },
            "]"
        },
        ", ",
        inlineWLCell @ RowBox @ { "Rule", "->", "1" },
        " and ",
        inlineWLCell @ RowBox @ { "Rule", ":>", "1" },
        " here"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-WL@@Tests/FormattingInline.wlt:649,1-667,2"
]

(* While streaming, the code is not parsed: *)
VerificationTest[
    formatted[ "Use `Plot[x, {x, 0, 1}]`, `Rule -> 1` and `Rule :> 1` here", "Streaming" ],
    {
        "Use ",
        inlineWLCell[ "Plot[x, {x, 0, 1}]" ],
        ", ",
        inlineWLCell[ "Rule -> 1" ],
        " and ",
        inlineWLCell[ "Rule :> 1" ],
        " here"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-WL-Streaming@@Tests/FormattingInline.wlt:670,1-683,2"
]

(* Whitespace around a rule operator is optional, but the argument list must follow the name directly: *)
VerificationTest[
    formatted[ "Use `Rule->1` and `Plot [x]` here" ],
    { "Use ", inlineWLCell @ RowBox @ { "Rule", "->", "1" }, " and ", codeTemplateCell[ "Plot [x]" ], " here" },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-WL-Spacing@@Tests/FormattingInline.wlt:686,1-691,2"
]

(* Inline code that is a quoted string is shown as a WL string: *)
VerificationTest[
    { formatted[ "Use `\"a string\"` here" ], formatted[ "Use `\"a string\"` here", "Streaming" ] },
    ConstantArray[ { "Use ", inlineWLCell[ "\"a string\"" ], " here" }, 2 ],
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-WL-String-Literal@@Tests/FormattingInline.wlt:694,1-699,2"
]

(* Inline code that contains \[FreeformPrompt] is WL code. A leading \[FreeformPrompt] is kept as a plain character,
   one anywhere else is replaced by the small colored \[FreeformPrompt] box: *)
VerificationTest[
    {
        formatted[ "Use `\[FreeformPrompt] population` here" ],
        formatted[ "Use `x \[FreeformPrompt] y` here" ],
        formatted[ "Use `\[FreeformPrompt]` here" ]
    },
    {
        { "Use ", inlineWLCell @ RowBox @ { "\[FreeformPrompt]", " ", "population" }, " here" },
        {
            "Use ",
            inlineWLCell @ RowBox @ {
                "x",
                " ",
                StyleBox[ "\[FreeformPrompt]", OrderlessPatternSequence[ FontColor -> _, FontSize -> 9 ] ],
                " ",
                "y"
            },
            " here"
        },
        { "Use ", inlineWLCell[ "\[FreeformPrompt]" ], " here" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-FreeformPrompt@@Tests/FormattingInline.wlt:703,1-726,2"
]

(* While streaming, the code is not parsed, so a \[FreeformPrompt] that is not leading stays a plain character: *)
VerificationTest[
    {
        formatted[ "Use `\[FreeformPrompt] population` here", "Streaming" ],
        formatted[ "Use `x \[FreeformPrompt] y` here", "Streaming" ]
    },
    {
        { "Use ", inlineWLCell[ "\[FreeformPrompt] population" ], " here" },
        { "Use ", inlineWLCell[ "x \[FreeformPrompt] y" ], " here" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-FreeformPrompt-Streaming@@Tests/FormattingInline.wlt:729,1-740,2"
]

(* ResourceFunction code is shown with the resource function box. Only the streaming display is tested here, since
   the finished display looks up the resource (network access): *)
VerificationTest[
    formatted[ "Use `ResourceFunction[\"Foo\"]` here", "Streaming" ],
    {
        "Use ",
        inlineWLCell[ b_ /; resourceFunctionBoxesQ[ b, "Foo" ] ],
        " here"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-ResourceFunction-Streaming@@Tests/FormattingInline.wlt:744,1-753,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Backticks*)

(* Double backticks allow a backtick inside the code: *)
VerificationTest[
    {
        formatted[ "Use ``a`b`` here" ],
        formatted[ "Use ``x`` here" ],
        formatted[ "Use ``Plot`` here" ]
    },
    {
        { "Use ", codeTemplateCell[ "a`b" ], " here" },
        { "Use ", StyleBox[ "x", "TI" ], " here" },
        { "Use ", refLinkCell[ "Plot" ], " here" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Double-Backticks@@Tests/FormattingInline.wlt:760,1-773,2"
]

(* Single backticks around a context name or a fully qualified symbol name include the context marks (the
   inlineSyntaxQ rule): *)
VerificationTest[
    formatted[ "Use `" <> # <> "` here" ] & /@ { "Wolfram`Chatbook`", "Global`", "Wolfram`Chatbook`FormatChatOutput" },
    {
        { "Use ", codeTemplateCell[ "Wolfram`Chatbook`" ], " here" },
        { "Use ", codeTemplateCell[ "Global`" ], " here" },
        { "Use ", codeTemplateCell[ "Wolfram`Chatbook`FormatChatOutput" ], " here" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Context-Names@@Tests/FormattingInline.wlt:777,1-786,2"
]

(* Triple backticks on a single line are inline code (autoCorrect rewrites them to double backticks): *)
VerificationTest[
    { formatted[ "Use ```inline triple``` here" ], formatted[ "Use ```Plot``` here" ] },
    { { "Use ", codeTemplateCell[ "inline triple" ], " here" }, { "Use ", refLinkCell[ "Plot" ], " here" } },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Triple-Backticks-Single-Line@@Tests/FormattingInline.wlt:789,1-794,2"
]

(* Unlike CommonMark, an escaped backtick inside single backticks is part of the code: *)
VerificationTest[
    formatted[ "Use `a\\`b` and `\\$x` here" ],
    { "Use ", codeTemplateCell[ "a`b" ], " and ", codeTemplateCell[ "$x" ], " here" },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Escaped-Backtick@@Tests/FormattingInline.wlt:797,1-802,2"
]

(* Backticks that are not closed on the same line, and empty backticks, are shown as is: *)
VerificationTest[
    formatted /@ { "Use `unclosed here", "Use `multi\nline` here", "Use `` here", "Use ``co" },
    { { "Use `unclosed here" }, { "Use `multi\nline` here" }, { "Use `` here" }, { "Use ``co" } },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Not-Code@@Tests/FormattingInline.wlt:805,1-810,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Wolfram Language Responses*)

(* A text fragment that is entirely WL code (by the same test as inline code) is shown as syntax-colored input
   without needing backticks: *)
VerificationTest[
    formatted /@ { "Plot[x, {x, 0, 1}]", "Print[\"hello\"]", "Pi -> 3.14" },
    {
        {
            inlineWLCell @ RowBox @ {
                "Plot",
                "[",
                RowBox @ { "x", ",", RowBox @ { "{", RowBox @ { "x", ",", "0", ",", "1" }, "}" } },
                "]"
            }
        },
        { inlineWLCell @ RowBox @ { "Print", "[", "\"hello\"", "]" } },
        { inlineWLCell @ RowBox @ { "Pi", "->", "3.14" } }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-WL-Response@@Tests/FormattingInline.wlt:818,1-834,2"
]

VerificationTest[
    formatted[ #, "Streaming" ] & /@ { "Plot[x, {x, 0, 1}]", "Print[\"hello\"]", "Pi -> 3.14" },
    {
        { inlineWLCell[ "Plot[x, {x, 0, 1}]" ] },
        { inlineWLCell[ "Print[\"hello\"]" ] },
        { inlineWLCell[ "Pi -> 3.14" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-WL-Response-Streaming@@Tests/FormattingInline.wlt:836,1-845,2"
]

(* Text that only starts with WL code, a bare System name, or code that doesn't start with a System symbol stays
   text. A quoted string is WL code only in backticks: *)
VerificationTest[
    formatted /@ { "Plot", "Plot[x] + 1", "Plot[x]\nmore", "x -> 1", "Plot[x, {x, 0, 1}] and more", "\"a string\"" },
    {
        { "Plot" },
        { "Plot[x] + 1" },
        { "Plot[x]\nmore" },
        { "x -> 1" },
        { "Plot[x, {x, 0, 1}] and more" },
        { "\"a string\"" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-WL-Response-Not-Code@@Tests/FormattingInline.wlt:849,1-861,2"
]

(* A response that starts with \[FreeformPrompt] is WL code too: *)
VerificationTest[
    formatted[ "\[FreeformPrompt] population of France" ],
    { inlineWLCell @ RowBox @ { "\[FreeformPrompt]", " ", "population", " ", "of", " ", "France" } },
    SameTest -> MatchQ,
    TestID   -> "Inline-WL-Response-FreeformPrompt@@Tests/FormattingInline.wlt:864,1-869,2"
]

(* The same applies to the text of a list item or heading, and to emphasized text: *)
VerificationTest[
    {
        bulletItemContent[ "- Plot[x, {x, 0, 1}]" ],
        innerTextData[ "## Plot[x]" ],
        formatted[ "**Plot[x]**" ]
    },
    {
        {
            inlineWLCell @ RowBox @ {
                "Plot",
                "[",
                RowBox @ { "x", ",", RowBox @ { "{", RowBox @ { "x", ",", "0", ",", "1" }, "}" } },
                "]"
            }
        },
        { "InlineSection", { inlineWLCell @ RowBox @ { "Plot", "[", "x", "]" } } },
        { inlineWLCell[ RowBox @ { "Plot", "[", "x", "]" }, FontWeight -> Bold ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-WL-Response-In-Blocks@@Tests/FormattingInline.wlt:872,1-892,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Hyperlinks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Web Links*)

(* Links to anything other than a paclet: URI become a ButtonBox with the "Hyperlink" style. The URL is used as is: *)
VerificationTest[
    formatted /@ {
        "See [Example](https://example.com) now",
        "See [Example](http://example.com/a?b=c&d=e#frag) now",
        "Link: [ex](www.example.com)",
        "Link: [ex](mailto:a@b.com)",
        "Link: [ex](#anchor)",
        "Link: [ex](/relative/path)"
    },
    {
        { "See ", hyperlinkButton[ "Example", "https://example.com" ], " now" },
        { "See ", hyperlinkButton[ "Example", "http://example.com/a?b=c&d=e#frag" ], " now" },
        { "Link: ", hyperlinkButton[ "ex", "www.example.com" ] },
        { "Link: ", hyperlinkButton[ "ex", "mailto:a@b.com" ] },
        { "Link: ", hyperlinkButton[ "ex", "#anchor" ] },
        { "Link: ", hyperlinkButton[ "ex", "/relative/path" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Hyperlink-URL@@Tests/FormattingInline.wlt:903,1-922,2"
]

(* Several links, links next to punctuation, and links directly followed by text: *)
VerificationTest[
    formatted /@ {
        "See [one](https://a.com) and [two](https://b.com).",
        "See ([docs](https://example.com)).",
        "[link](https://example.com)text"
    },
    {
        { "See ", hyperlinkButton[ "one", "https://a.com" ], " and ", hyperlinkButton[ "two", "https://b.com" ], "." },
        { "See (", hyperlinkButton[ "docs", "https://example.com" ], ")." },
        { hyperlinkButton[ "link", "https://example.com" ], "text" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Hyperlink-Multiple-And-Punctuation@@Tests/FormattingInline.wlt:925,1-938,2"
]

(* Emphasis in the label is formatted inside the button: *)
VerificationTest[
    formatted /@ { "See [*it*](https://example.com) now", "[**bold label**](https://example.com)" },
    {
        { "See ", hyperlinkButton[ StyleBox[ "it", FontSlant -> Italic ], "https://example.com" ], " now" },
        { hyperlinkButton[ StyleBox[ "bold label", FontWeight -> Bold ], "https://example.com" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Hyperlink-Formatted-Label@@Tests/FormattingInline.wlt:941,1-949,2"
]

(* Labels can contain brackets: *)
VerificationTest[
    formatted /@ { "See [a [bracketed] label](https://example.com) now", "See [f[x]](https://example.com) now" },
    {
        { "See ", hyperlinkButton[ "a [bracketed] label", "https://example.com" ], " now" },
        { "See ", hyperlinkButton[ "f[x]", "https://example.com" ], " now" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Hyperlink-Bracketed-Label@@Tests/FormattingInline.wlt:952,1-960,2"
]

(* Escapes are removed from the label and the URL: *)
VerificationTest[
    formatted /@ { "[a\\_b](https://example.com)", "[x](https://example.com/a\\_b)" },
    {
        { hyperlinkButton[ "a_b", "https://example.com" ] },
        { hyperlinkButton[ "x", "https://example.com/a_b" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Hyperlink-Escaped-Characters@@Tests/FormattingInline.wlt:963,1-971,2"
]

(* Underscores in a URL are not emphasis, in links or bare URLs: *)
VerificationTest[
    {
        formatted[ "Visit [docs](https://example.com/some_page_name) for _details_" ],
        formatted[ "See https://example.com/some_page_name here" ]
    },
    {
        {
            "Visit ",
            hyperlinkButton[ "docs", "https://example.com/some_page_name" ],
            " for ",
            StyleBox[ "details", FontSlant -> Italic ]
        },
        { "See https://example.com/some_page_name here" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Hyperlink-Underscores-In-URL@@Tests/FormattingInline.wlt:974,1-990,2"
]

(* Bare URLs are not turned into links: *)
VerificationTest[
    formatted[ "See https://example.com now" ],
    { "See https://example.com now" },
    SameTest -> MatchQ,
    TestID   -> "Inline-Hyperlink-Bare-URL@@Tests/FormattingInline.wlt:993,1-998,2"
]

(* Not links: an empty URL, a space between label and URL, and an unterminated link (e.g. while streaming): *)
VerificationTest[
    {
        formatted[ "See [label]() now" ],
        formatted[ "See [label] (https://example.com) now" ],
        formatted[ "See [link](https://exa", "Streaming" ],
        formatted[ "See [link](paclet:ref/Pl", "Streaming" ]
    },
    {
        { "See [label]() now" },
        { "See [label] (https://example.com) now" },
        { "See [link](https://exa" },
        { "See [link](paclet:ref/Pl" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Hyperlink-Not-Links@@Tests/FormattingInline.wlt:1001,1-1016,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Documentation Links*)

(* Links to paclet: URIs become TextRefLink templates with the corresponding reference.wolfram.com URL: *)
VerificationTest[
    formatted /@ {
        "See [Plot](paclet:ref/Plot) now",
        "See [the guide](paclet:guide/ListManipulation) now",
        "Link: [ex](paclet:Wolfram/Chatbook/ref/CreateChatNotebook)"
    },
    {
        { "See ", refLinkCell[ "Plot" ], " now" },
        {
            "See ",
            Cell @ BoxData @ TemplateBox[
                {
                    "the guide",
                    "paclet:guide/ListManipulation",
                    "https://reference.wolfram.com/language/guide/ListManipulation.html"
                },
                "TextRefLink"
            ],
            " now"
        },
        {
            "Link: ",
            Cell @ BoxData @ TemplateBox[
                {
                    "ex",
                    "paclet:Wolfram/Chatbook/ref/CreateChatNotebook",
                    "https://reference.wolfram.com/language/Wolfram/Chatbook/ref/CreateChatNotebook.html"
                },
                "TextRefLink"
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Hyperlink-Paclet@@Tests/FormattingInline.wlt:1023,1-1057,2"
]

(* Whitespace and backticks around the label are trimmed. This also happens in list items, where the label is not
   rewritten first: *)
VerificationTest[
    {
        formatted[ "See [ Plot ](paclet:ref/Plot) now" ],
        formatted[ "See [`Plot`](paclet:ref/Plot) now" ],
        bulletItemContent[ "- [`Plot`](paclet:ref/Plot)" ],
        bulletItemContent[ "- [`code`](paclet:ref/Plot)" ]
    },
    {
        { "See ", refLinkCell[ "Plot" ], " now" },
        { "See ", refLinkCell[ "Plot" ], " now" },
        { refLinkCell[ "Plot" ] },
        { refLinkCell[ "code", "Plot" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Hyperlink-Paclet-Label-Trimmed@@Tests/FormattingInline.wlt:1061,1-1076,2"
]

(* Escaped backticks in the label are literal characters, so they are kept: *)
VerificationTest[
    formatted[ "See [\\`Plot\\`](paclet:ref/Plot) now" ],
    { "See ", refLinkCell[ "`Plot`", "Plot" ], " now" },
    SameTest -> MatchQ,
    TestID   -> "Inline-Hyperlink-Paclet-Escaped-Backticks@@Tests/FormattingInline.wlt:1079,1-1084,2"
]

(* Text directly after a documentation link is not part of it: *)
VerificationTest[
    formatted /@ { "[Plot](paclet:ref/Plot)[x]", "See [Plot](paclet:ref/Plot), [ListPlot](paclet:ref/ListPlot)." },
    {
        { refLinkCell[ "Plot" ], "[x]" },
        { "See ", refLinkCell[ "Plot" ], ", ", refLinkCell[ "ListPlot" ], "." }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Hyperlink-Paclet-Adjacent-Text@@Tests/FormattingInline.wlt:1087,1-1095,2"
]

(* A fragment (e.g. a snippet URI) stays in the paclet: URI, which the documentation center resolves, and comes after
   ".html" in the web URL: *)
VerificationTest[
    formatted /@ {
        "See [Table](paclet:ref/Table#23775) now",
        "See [speed](paclet:ref/entity/TaxonomicSpecies#0a1b2c) now"
    },
    {
        {
            "See ",
            Cell @ BoxData @ TemplateBox[
                {
                    "Table",
                    "paclet:ref/Table#23775",
                    "https://reference.wolfram.com/language/ref/Table.html#23775"
                },
                "TextRefLink"
            ],
            " now"
        },
        {
            "See ",
            Cell @ BoxData @ TemplateBox[
                {
                    "speed",
                    "paclet:ref/entity/TaxonomicSpecies#0a1b2c",
                    "https://reference.wolfram.com/language/ref/entity/TaxonomicSpecies.html#0a1b2c"
                },
                "TextRefLink"
            ],
            " now"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Hyperlink-Paclet-Fragment"
]

VerificationTest[
    MarkdownRoundTrip[ "See [Table](paclet:ref/Table#23775) now" ],
    "See [Table](paclet:ref/Table#23775) now",
    SameTest -> MatchQ,
    TestID   -> "Inline-RoundTrip-Paclet-Fragment"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Links With Code Labels*)

(* A label that is entirely in backticks has the backticks removed before the link is formatted, so it renders as an
   ordinary link (web URL) or documentation link (paclet: URI): *)
VerificationTest[
    formatted /@ {
        "See [`code`](https://example.com) now",
        "See [`Plot`](https://example.com) now",
        "See [`Plot`](paclet:ref/Plot) now"
    },
    {
        { "See ", hyperlinkButton[ "code", "https://example.com" ], " now" },
        { "See ", hyperlinkButton[ "Plot", "https://example.com" ], " now" },
        { "See ", refLinkCell[ "Plot" ], " now" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Link-Backticked-Label@@Tests/FormattingInline.wlt:1103,1-1116,2"
]

(* That rewrite only happens at the paragraph level. In a list item the label is formatted as inline code inside the
   link instead: *)
VerificationTest[
    bulletItemContent[ "- [`code`](https://example.com)" ],
    { hyperlinkButton[ StyleBox[ "code", "TI" ], "https://example.com" ] },
    SameTest -> MatchQ,
    TestID   -> "Inline-Link-Backticked-Label-In-List-Item@@Tests/FormattingInline.wlt:1120,1-1125,2"
]

(* A label that formats to a single cell is put in the button as is, e.g. verbatim inline code in a list item, or a
   label that is entirely WL code (see Wolfram Language Responses): *)
VerificationTest[
    {
        bulletItemContent[ "- [`foo bar`](https://example.com)" ],
        formatted[ "See [Plot[x]](https://example.com) now" ],
        formatted[ "See [Plot[x]](https://example.com) now", "Streaming" ]
    },
    {
        { hyperlinkButton[ codeTemplateCell[ "foo bar" ], "https://example.com" ] },
        { "See ", hyperlinkButton[ inlineWLCell @ RowBox @ { "Plot", "[", "x", "]" }, "https://example.com" ], " now" },
        { "See ", hyperlinkButton[ inlineWLCell[ "Plot[x]" ], "https://example.com" ], " now" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Link-Cell-Label@@Tests/FormattingInline.wlt:1129,1-1142,2"
]

(* A link whose label is ResourceFunction code is shown as the resource function box, with or without backticks around
   the label. The URL is dropped. Only the streaming display is tested here, since the finished display looks up the
   resource (network access): *)
VerificationTest[
    formatted[ #, "Streaming" ] & /@ {
        "See [`ResourceFunction[\"Foo\"]`](https://example.com/Foo) now",
        "See [ResourceFunction[\"Foo\"]](https://example.com/Foo) now"
    },
    ConstantArray[
        {
            "See ",
            inlineWLCell[ b_ /; resourceFunctionBoxesQ[ b, "Foo" ] ],
            " now"
        },
        2
    ],
    SameTest -> MatchQ,
    TestID   -> "Inline-Link-ResourceFunction-Streaming@@Tests/FormattingInline.wlt:1147,1-1162,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FreeformPrompt*)

(* A \[FreeformPrompt] character in text becomes a small colored link to the natural language input guide: *)
VerificationTest[
    formatted[ "Ask \[FreeformPrompt] here" ],
    {
        "Ask ",
        Cell @ BoxData @ TemplateBox[
            {
                StyleBox[ "\[FreeformPrompt]", OrderlessPatternSequence[ FontColor -> _, FontSize -> 9 ] ],
                "paclet:guide/KnowledgeRepresentationAndAccess#203374175"
            },
            "HyperlinkPaclet"
        ],
        " here"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-FreeformPrompt-Text@@Tests/FormattingInline.wlt:1169,1-1184,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Formatting in Blocks*)

(* All inline constructs are formatted in list items: *)
VerificationTest[
    bulletItemContent[ "- Use `Plot` and **bold** and *it* and [ex](https://example.com)" ],
    {
        "Use ",
        refLinkCell[ "Plot" ],
        " and ",
        StyleBox[ "bold", FontWeight -> Bold ],
        " and ",
        StyleBox[ "it", FontSlant -> Italic ],
        " and ",
        hyperlinkButton[ "ex", "https://example.com" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-In-List-Item@@Tests/FormattingInline.wlt:1191,1-1205,2"
]

(* List item text skips the inline code rules of the first pass, so formatTextString's own inline code rules handle
   double backticks, context names and verbatim code there, with the same results as in paragraphs: *)
VerificationTest[
    bulletItemContent[ "- Use ``a`b`` and `Wolfram`Chatbook`` and `foo bar` and ~~old~~" ],
    {
        "Use ",
        codeTemplateCell[ "a`b" ],
        " and ",
        codeTemplateCell[ "Wolfram`Chatbook`" ],
        " and ",
        codeTemplateCell[ "foo bar" ],
        " and ",
        StyleBox[ "old", FontVariations -> { "StrikeThrough" -> True } ]
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-In-List-Item-Code@@Tests/FormattingInline.wlt:1209,1-1223,2"
]

(* ... in headings: *)
VerificationTest[
    {
        innerTextData[ "## Using `Plot` with **bold**" ],
        innerTextData[ "## [Link](https://example.com) heading" ]
    },
    {
        { "InlineSection", { "Using ", refLinkCell[ "Plot" ], " with ", StyleBox[ "bold", FontWeight -> Bold ] } },
        { "InlineSection", { hyperlinkButton[ "Link", "https://example.com" ], " heading" } }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-In-Heading@@Tests/FormattingInline.wlt:1226,1-1237,2"
]

(* ... and in block quotes: *)
VerificationTest[
    innerTextData[ "> Quote with `Plot` and **bold** and _it_" ],
    {
        "BlockQuote",
        {
            "Quote with ",
            refLinkCell[ "Plot" ],
            " and ",
            StyleBox[ "bold", FontWeight -> Bold ],
            " and ",
            StyleBox[ "it", FontSlant -> Italic ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-In-Block-Quote@@Tests/FormattingInline.wlt:1240,1-1255,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Escaped Markdown*)

(* Escaped markers are shown without the backslash and don't format anything, while the other markers in the same
   text are still formatted: *)
VerificationTest[
    formatted /@ {
        "Escaped \\*not italic\\* and *italic*",
        "Escaped \\_not\\_ and _italic_",
        "Escaped \\`not code\\` and `code`"
    },
    {
        { "Escaped *not italic* and ", StyleBox[ "italic", FontSlant -> Italic ] },
        { "Escaped _not_ and ", StyleBox[ "italic", FontSlant -> Italic ] },
        { "Escaped `not code` and ", StyleBox[ "code", "TI" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Escaped-Markers@@Tests/FormattingInline.wlt:1263,1-1276,2"
]

(* An escape anywhere in the text doesn't change how the other inline constructs are formatted: *)
VerificationTest[
    formatted[ "Cost \\$5 and **bold** and `Plot` and [ex](https://example.com) and \\textit{it}" ],
    {
        "Cost $5 and ",
        StyleBox[ "bold", FontWeight -> Bold ],
        " and ",
        refLinkCell[ "Plot" ],
        " and ",
        hyperlinkButton[ "ex", "https://example.com" ],
        " and ",
        StyleBox[ "it", FontSlant -> Italic ]
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Escaped-With-Formatting@@Tests/FormattingInline.wlt:1279,1-1293,2"
]

(* A literal backslash that doesn't escape anything is kept: *)
VerificationTest[
    formatted[ "Text with \\\\ backslash and *italic*" ],
    { "Text with \\ backslash and ", StyleBox[ "italic", FontSlant -> Italic ] },
    SameTest -> MatchQ,
    TestID   -> "Inline-Escaped-Backslash@@Tests/FormattingInline.wlt:1296,1-1301,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Streaming*)

(* Unterminated inline constructs are shown as plain text while streaming. Constructs that are complete are
   formatted: *)
VerificationTest[
    formatted[ #, "Streaming" ] & /@ { "Use `Plo", "Use **bol", "Use *ita", "Use ~~str", "Use `Plot` and `Lis" },
    {
        { "Use `Plo" },
        { "Use **bol" },
        { "Use *ita" },
        { "Use ~~str" },
        { "Use ", refLinkCell[ "Plot" ], " and `Lis" }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Streaming-Unterminated@@Tests/FormattingInline.wlt:1309,1-1320,2"
]

(* A fence that has been started but has no language or code yet is not shown (formatTextString removes it): *)
VerificationTest[
    { formatted[ "Text\n```" ], formatted[ "Text\n```", "Streaming" ], formatted[ "```" ] },
    { { "Text" }, { "Text" }, { } },
    SameTest -> MatchQ,
    TestID   -> "Inline-Streaming-Dangling-Fence@@Tests/FormattingInline.wlt:1323,1-1328,2"
]

(* The same rule hides a stray extra fence after a code block, which is left over as a text fragment of its own: *)
VerificationTest[
    { formatted[ "```wl\n1+1\n```\n```" ], formatted[ "```wl\n1+1\n```\n```", "Streaming" ] },
    { { Cell[ _, "ChatCodeBlock", ___ ] }, { Cell[ _, "ChatCodeBlock", ___ ] } },
    SameTest -> MatchQ,
    TestID   -> "Inline-Stray-Fence-After-Code-Block@@Tests/FormattingInline.wlt:1331,1-1336,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Serialization*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Emphasis*)

(* Asterisk emphasis serializes back to the same markdown: *)
VerificationTest[
    MarkdownRoundTrip /@ {
        "Some ***bold italic*** text",
        "Some **bold** text",
        "Some *italic* text",
        "Some ~~struck~~ text",
        "un*frigging*believable",
        "a **b** c **d** e",
        "**x**\n**y**",
        "Text\n\n**Bold paragraph**\n\nMore"
    },
    {
        "Some ***bold italic*** text",
        "Some **bold** text",
        "Some *italic* text",
        "Some ~~struck~~ text",
        "un*frigging*believable",
        "a **b** c **d** e",
        "**x**\n**y**",
        "Text\n\n**Bold paragraph**\n\nMore"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-RoundTrip-Emphasis@@Tests/FormattingInline.wlt:1347,1-1370,2"
]

(* Underscores and TeX text commands serialize as asterisks, and combined styles serialize in a fixed order: *)
VerificationTest[
    MarkdownRoundTrip /@ {
        "Some ___bold italic___ text",
        "Some __bold__ text",
        "Some _italic_ text",
        "\\textit{italic text} and \\textbf{bold text}",
        "~~**both**~~",
        "**_a_**",
        "*~~a~~*"
    },
    {
        "Some ***bold italic*** text",
        "Some **bold** text",
        "Some *italic* text",
        "*italic text* and **bold text**",
        "**~~both~~**",
        "***a***",
        "*~~a~~*"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-RoundTrip-Emphasis-Normalized@@Tests/FormattingInline.wlt:1373,1-1394,2"
]

(* Markers that were shown literally are escaped when serialized (except tildes): *)
VerificationTest[
    MarkdownRoundTrip /@ { "**unclosed bold", "*unclosed italic", "x * y", "Use `unclosed here", "~~unclosed" },
    { "\\*\\*unclosed bold", "\\*unclosed italic", "x \\* y", "Use \\`unclosed here", "~~unclosed" },
    SameTest -> MatchQ,
    TestID   -> "Inline-RoundTrip-Literal-Markers-Escaped@@Tests/FormattingInline.wlt:1397,1-1402,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Inline Code*)

(* System symbols serialize as documentation links, other inline code as double-backtick code: *)
VerificationTest[
    MarkdownRoundTrip /@ {
        "Use `Plot` here",
        "Use `System`Plot` here",
        "Use `x` here",
        "Use `foo bar` here",
        "Use `foo_bar` here",
        "Use ```inline triple``` here",
        "Use `Plot[x, {x, 0, 1}]` here",
        "Use `\"a string\"` here",
        "Use `x \[FreeformPrompt] y` here",
        "Plot[x, {x, 0, 1}]"
    },
    {
        "Use [Plot](paclet:ref/Plot) here",
        "Use [System`Plot](paclet:ref/Plot) here",
        "Use ``x`` here",
        "Use ``foo bar`` here",
        "Use ``foo_bar`` here",
        "Use ``inline triple`` here",
        "Use ``Plot[x, {x, 0, 1}]`` here",
        "Use ``\"a string\"`` here",
        "Use ``x \[FreeformPrompt] y`` here",
        "``Plot[x, {x, 0, 1}]``"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-RoundTrip-Inline-Code@@Tests/FormattingInline.wlt:1409,1-1436,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Links*)

(* Links serialize as markdown links. Emphasis around a link serializes inside the label, and backticks around a
   label are gone: *)
VerificationTest[
    MarkdownRoundTrip /@ {
        "See [Example](https://example.com) now",
        "See [*it*](https://example.com) now",
        "*[link](https://example.com)*",
        "See [a [bracketed] label](https://example.com) now",
        "See [Plot](paclet:ref/Plot) now",
        "See [the guide](paclet:guide/ListManipulation) now",
        "See [`code`](https://example.com) now",
        "See [`Plot`](paclet:ref/Plot) now"
    },
    {
        "See [Example](https://example.com) now",
        "See [*it*](https://example.com) now",
        "[*link*](https://example.com)",
        "See [a [bracketed] label](https://example.com) now",
        "See [Plot](paclet:ref/Plot) now",
        "See [the guide](paclet:guide/ListManipulation) now",
        "See [code](https://example.com) now",
        "See [Plot](paclet:ref/Plot) now"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-RoundTrip-Hyperlinks@@Tests/FormattingInline.wlt:1444,1-1467,2"
]

(* The \[FreeformPrompt] link serializes as a markdown link to its guide page: *)
VerificationTest[
    MarkdownRoundTrip[ "Ask \[FreeformPrompt] here" ],
    "Ask [\[FreeformPrompt]](paclet:guide/KnowledgeRepresentationAndAccess#203374175) here",
    SameTest -> MatchQ,
    TestID   -> "Inline-RoundTrip-FreeformPrompt@@Tests/FormattingInline.wlt:1470,1-1475,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Blocks*)

(* Inline formatting in list items, headings and block quotes serializes inside the block: *)
VerificationTest[
    MarkdownRoundTrip /@ {
        "- Use `Plot` and **bold** and *it* and [ex](https://example.com)",
        "- **`foo bar`**",
        "- [`foo bar`](https://example.com)",
        "## Using `Plot` with **bold**",
        "> Quote with `Plot` and **bold** and _it_"
    },
    {
        "* Use [Plot](paclet:ref/Plot) and **bold** and *it* and [ex](https://example.com)",
        "* **``foo bar``**",
        "* [``foo bar``](https://example.com)",
        "## Using [Plot](paclet:ref/Plot) with **bold**",
        "> Quote with [Plot](paclet:ref/Plot) and **bold** and *it*"
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-RoundTrip-Blocks@@Tests/FormattingInline.wlt:1482,1-1499,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Reformatting*)

(* Formatting the serialized markdown again gives the same output. This also holds where the serialized markdown
   escapes characters inside code or puts emphasis markers next to each other: *)
VerificationTest[
    Select[
        {
            "Some ~~struck~~ text",
            "**bold**_italic_",
            "\\textbf{a}\\textbf{b}",
            "**unclosed bold",
            "x * y",
            "Escaped \\*not italic\\* and *italic*",
            "Cost \\$5 and **bold** and `Plot`",
            "Use `Plot`, `ListPlot`, and `Table`.",
            "Use `f[x_] := x^2` here",
            "Use `Wolfram`Chatbook`` here",
            "Use `#` and `x_` here",
            "Use `a*b*c` here",
            "Use ``a`b`` here",
            "See [`code`](https://example.com) now"
        },
        formatted @ MarkdownRoundTrip @ # =!= formatted @ # &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Inline-RoundTrip-Reformat-Stable@@Tests/FormattingInline.wlt:1507,1-1530,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Four Backticks*)

(* Code in four backticks is inline code, in paragraphs as in list items and headings. autoCorrect rewrites ````x```` as
   ```x```, which is then inline code like ``x``: *)
VerificationTest[
    {
        formatted[ "Use ````foo bar```` here" ],
        formatted[ "Use ````Plot```` here" ],
        formatted[ "Use ````foo bar```` here", "Streaming" ],
        bulletItemContent[ "- Use ````foo bar```` here" ],
        innerTextData[ "## Use ````foo bar```` here" ]
    },
    {
        { "Use ", codeTemplateCell[ "foo bar" ], " here" },
        { "Use ", refLinkCell[ "Plot" ], " here" },
        { "Use ", codeTemplateCell[ "foo bar" ], " here" },
        { "Use ", codeTemplateCell[ "foo bar" ], " here" },
        { "InlineSection", { "Use ", codeTemplateCell[ "foo bar" ], " here" } }
    },
    SameTest -> MatchQ,
    TestID   -> "Inline-Code-Four-Backticks@@Tests/FormattingInline.wlt:1538,1-1555,2"
]

VerificationTest[
    MarkdownRoundTrip /@ { "Use ````foo bar```` here", "- Use ````foo bar```` here" },
    { "Use ``foo bar`` here", "* Use ``foo bar`` here" },
    SameTest -> MatchQ,
    TestID   -> "Inline-RoundTrip-Four-Backticks@@Tests/FormattingInline.wlt:1557,1-1562,2"
]

(* :!CodeAnalysis::EndBlock:: *)
