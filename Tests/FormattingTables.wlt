(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/FormattingTables.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/FormattingTables.wlt:11,1-16,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* Helpers that reduce a formatted "TextTableForm" cell to what determines its appearance:
   - "Grid": the visible items, row by row (headings, if any, are the first row). Plain text items are string boxes
     like "\"a\"" (shown without quotes, since the table has ShowStringCharacters -> False), and TableForm wraps the
     heading items in TagBox[..., HoldForm]. Both are display details, so they are removed here.
   - "Headings": whether a divider is drawn below the first row (i.e. the first row is shown as column headings).
   - "Alignments": the ColumnAlignments of the grid.
   Table cells are replaced with these summaries, and the remaining text items are normalized with NormalizeTextData. *)
VerificationTest[
    tableItem[ TagBox[ box_, HoldForm ] ] := tableItem @ box;
    tableItem[ TagBox[ StyleBox[ box_, ShowStringCharacters -> False ], ___ ] ] := tableItem @ box;
    (* TableForm pads missing headings with an invisible "\[Null]", which is removed here too: *)
    tableItem[ s_String ] /; StringMatchQ[ s, "\"" ~~ ___ ~~ "\"" ] :=
        StringDelete[ StringReplace[ StringTake[ s, { 2, -2 } ], "\\\"" -> "\"" ], "\[Null]" ];
    tableItem[ other_ ] := other;

    tableSummary[ Cell[ BoxData[ boxes_ ], "TextTableForm", ___ ] ] :=
        With[ { grid = FirstCase[ boxes, _GridBox, None, Infinity ] },
            <|
                "Grid"       -> Map[ tableItem, First @ grid, { 2 } ],
                "Headings"   -> MatchQ[
                    Lookup[ FirstCase[ grid, HoldPattern[ GridBoxDividers -> d_ ] :> d, { }, { 1 } ], "Rows", None ],
                    { False, True, ___ }
                ],
                "Alignments" -> FirstCase[ grid, HoldPattern[ ColumnAlignments -> a_ ] :> a, None, { 1 } ]
            |>
        ];

    formatTables[ md_String ] := formatTables[ md, "Finished" ];
    formatTables[ md_String, status_String ] := Replace[
        NormalizeTextData @ FormatMarkdown[ md, status ],
        cell: Cell[ _, "TextTableForm", ___ ] :> tableSummary @ cell,
        { 1 }
    ];

    (* Tables without alignment specifications are left aligned, given either as one value or one per column: *)
    $$left = Left | { Left.. };

    (* A headed table with plain text items and default alignment: *)
    headedTable[ grid_ ] := <| "Grid" -> grid, "Headings" -> True, "Alignments" -> $$left |>;
    plainTable[ grid_ ] := <| "Grid" -> grid, "Headings" -> False, "Alignments" -> $$left |>;

    (* Table summaries without the alignments: *)
    reformatted[ items_List ] := Replace[ items, a_Association :> KeyTake[ a, { "Grid", "Headings" } ], { 1 } ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Tables-Definitions@@Tests/FormattingTables.wlt:29,1-69,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Box Structure*)

(* A table with a header row and a delimiter row is a "TextTableForm" cell containing the boxes of a TableForm with
   TableHeadings: the headings are the first grid row, drawn with a divider below them. The HeadedColumns tag is what
   CellToString uses to write the heading row back out. The grid is shown in "Text" style without string characters,
   and the alignment from the delimiter row replaces every ColumnAlignments option of the grid. Headed tables are
   currently wrapped in two panes with the same vertical margins. The outer TagBox that holds the TableForm
   interpretation, and the HoldForm tags around the headings, are not visible, so they are optional here: *)
VerificationTest[
    FormatMarkdown[ "| a | b |\n|---|---|\n| 1 | 2 |" ],
    With[
        {
            grid = TagBox[
                GridBox[
                    {
                        { TagBox[ "\"a\"", HoldForm ] | "\"a\"", TagBox[ "\"b\"", HoldForm ] | "\"b\"" },
                        { "\"1\"", "\"2\"" }
                    },
                    OrderlessPatternSequence[
                        ColumnAlignments -> Left | { Left, Left },
                        GridBoxDividers  -> { ___, "Rows" -> { False, True, ___ }, ___ },
                        ___
                    ]
                ],
                { None, OutputFormsDump`HeadedColumns }
            ]
        },
        {
            Cell[
                BoxData @ PaneBox[
                    PaneBox[
                        StyleBox[ TagBox[ grid, _ ] | grid, "Text", ShowStringCharacters -> False, ___ ],
                        ImageMargins -> { { 0, 0 }, { 5, 5 } }
                    ],
                    ImageMargins -> { { 0, 0 }, { 5, 5 } }
                ],
                "TextTableForm"
            ]
        }
    ],
    SameTest -> MatchQ,
    TestID   -> "Tables-Structure-Headed@@Tests/FormattingTables.wlt:81,1-115,2"
]

(* Without a delimiter row, every row is a data row: there are no headings and the default alignment, in a single
   pane: *)
VerificationTest[
    FormatMarkdown[ "| a | b |\n| 1 | 2 |" ],
    With[
        {
            grid = GridBox[
                { { "\"a\"", "\"b\"" }, { "\"1\"", "\"2\"" } },
                OrderlessPatternSequence[ ColumnAlignments -> $$left, ___ ]
            ]
        },
        {
            Cell[
                BoxData @ PaneBox[
                    StyleBox[ TagBox[ grid, _ ] | grid, "Text", ShowStringCharacters -> False, ___ ],
                    ImageMargins -> { { 0, 0 }, { 5, 5 } }
                ],
                "TextTableForm"
            ]
        }
    ],
    SameTest -> MatchQ,
    TestID   -> "Tables-Structure-No-Delimiter-Row@@Tests/FormattingTables.wlt:119,1-140,2"
]

(* No divider is drawn under the first row, and there is no HeadedColumns tag (so CellToString does not write the first
   row as headings): *)
VerificationTest[
    With[ { boxes = FormatMarkdown[ "| a | b |\n| 1 | 2 |" ] },
        {
            FreeQ[ boxes, OutputFormsDump`HeadedColumns ],
            FreeQ[ boxes, HoldPattern[ GridBoxDividers -> KeyValuePattern[ "Rows" -> { ___, True, ___ } ] ] ]
        }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "Tables-Structure-No-Delimiter-Row-No-Headings@@Tests/FormattingTables.wlt:144,1-154,2"
]

(* An empty header row followed by a delimiter row gives a table without headings that still uses the alignment
   from the delimiter row, in a single pane: *)
VerificationTest[
    FormatMarkdown[ "| | |\n|:-:|--:|\n| 1 | 2 |\n| 3 | 4 |" ],
    With[
        {
            grid = GridBox[
                { { "\"1\"", "\"2\"" }, { "\"3\"", "\"4\"" } },
                OrderlessPatternSequence[ ColumnAlignments -> { Center, Right }, ___ ]
            ]
        },
        {
            Cell[
                BoxData @ PaneBox[
                    StyleBox[ TagBox[ grid, _ ] | grid, "Text", ShowStringCharacters -> False, ___ ],
                    ImageMargins -> { { 0, 0 }, { 5, 5 } }
                ],
                "TextTableForm"
            ]
        }
    ],
    SameTest -> MatchQ,
    TestID   -> "Tables-Structure-Empty-Header-Row@@Tests/FormattingTables.wlt:158,1-179,2"
]

(* ExplodeCell (used when copying a response as notebook cells) gives tables their own cell with the "Text" style
   added: *)
VerificationTest[
    Replace[
        ExplodeCell @ Cell[ TextData @ FormatMarkdown[ "Intro\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nOutro" ], "ChatOutput" ],
        Cell[ content_, styles___String, OptionsPattern[ ] ] :> { Head @ content, { styles } },
        { 1 }
    ],
    { { TextData, { "Text" } }, { BoxData, { "TextTableForm", "Text" } }, { TextData, { "Text" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Structure-ExplodeCell@@Tests/FormattingTables.wlt:183,1-192,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Detection*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Row Forms*)

(* Rows with leading and trailing pipes: *)
VerificationTest[
    formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |" ],
    { headedTable @ { { "a", "b" }, { "1", "2" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Rows-Outer-Pipes@@Tests/FormattingTables.wlt:203,1-208,2"
]

(* Pipes without surrounding spaces: *)
VerificationTest[
    formatTables[ "|a|b|\n|-|-|\n|1|2|" ],
    { headedTable @ { { "a", "b" }, { "1", "2" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Rows-Compact@@Tests/FormattingTables.wlt:211,1-216,2"
]

(* Rows without outer pipes are tables when they have at least three columns (two pipes per row): *)
VerificationTest[
    formatTables[ "a | b | c\n--- | --- | ---\n1 | 2 | 3" ],
    { headedTable @ { { "a", "b", "c" }, { "1", "2", "3" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Rows-No-Outer-Pipes@@Tests/FormattingTables.wlt:219,1-224,2"
]

(* Rows with only a trailing pipe: *)
VerificationTest[
    formatTables[ "a | b |\n---|---|\n1 | 2 |" ],
    { headedTable @ { { "a", "b" }, { "1", "2" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Rows-Trailing-Pipe-Only@@Tests/FormattingTables.wlt:227,1-232,2"
]

(* Whitespace (including tabs) around cell contents is trimmed: *)
VerificationTest[
    formatTables[ "|\ta\t|\tb\t|\n|---|---|\n|\t1\t|\t2\t|" ],
    { headedTable @ { { "a", "b" }, { "1", "2" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Rows-Tabs@@Tests/FormattingTables.wlt:235,1-240,2"
]

(* A single column table: *)
VerificationTest[
    formatTables[ "| a |\n|---|\n| 1 |" ],
    { headedTable @ { { "a" }, { "1" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Rows-Single-Column@@Tests/FormattingTables.wlt:243,1-248,2"
]

VerificationTest[
    formatTables[ "| a | b | c | d | e | f | g | h |\n|---|---|---|---|---|---|---|---|\n| 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |" ],
    { headedTable @ { CharacterRange[ "a", "h" ], ToString /@ Range[ 8 ] } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Rows-Many-Columns@@Tests/FormattingTables.wlt:250,1-255,2"
]

(* Rows with only a leading pipe are tables when they have at least three columns (two-column rows like this are
   currently not detected, see the quirks): *)
VerificationTest[
    formatTables[ "| a | b | c\n|---|---|---\n| 1 | 2 | 3" ],
    { headedTable @ { { "a", "b", "c" }, { "1", "2", "3" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Rows-Leading-Pipe-Only@@Tests/FormattingTables.wlt:259,1-264,2"
]

(* A table needs at least two rows. A single row is left as text: *)
VerificationTest[
    {
        FormatMarkdown[ "| a | b |" ],
        NormalizeTextData @ FormatMarkdown[ "Text before\n| a | b |\nText after" ]
    },
    { { "| a | b |" }, { "Text before\n| a | b |\nText after" } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Single-Row-Is-Text@@Tests/FormattingTables.wlt:267,1-275,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Position and Spacing*)

(* A table at the very start of the response has no line break before it: *)
VerificationTest[
    formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n\nAfter" ],
    { headedTable @ { { "a", "b" }, { "1", "2" } }, "\nAfter" },
    SameTest -> MatchQ,
    TestID   -> "Tables-At-Start@@Tests/FormattingTables.wlt:282,1-287,2"
]

(* A table at the end of the response, with or without a final newline: *)
VerificationTest[
    {
        formatTables[ "Before\n\n| a | b |\n|---|---|\n| 1 | 2 |" ],
        formatTables[ "Before\n\n| a | b |\n|---|---|\n| 1 | 2 |\n" ]
    },
    {
        { "Before\n", headedTable @ { { "a", "b" }, { "1", "2" } } },
        { "Before\n", headedTable @ { { "a", "b" }, { "1", "2" } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-At-End@@Tests/FormattingTables.wlt:290,1-301,2"
]

(* The blank lines before a table collapse into a single line break, and the blank line after it gives a single line
   break before the following text: *)
VerificationTest[
    {
        formatTables[ "Before\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nAfter" ],
        formatTables[ "Before\n\n\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nAfter" ]
    },
    {
        { "Before\n", headedTable @ { { "a", "b" }, { "1", "2" } }, "\nAfter" },
        { "Before\n", headedTable @ { { "a", "b" }, { "1", "2" } }, "\nAfter" }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Text-Around@@Tests/FormattingTables.wlt:305,1-316,2"
]

(* No blank line is needed between a paragraph and the table that follows it: *)
VerificationTest[
    formatTables[ "Before\n| a | b |\n|---|---|\n| 1 | 2 |" ],
    { "Before\n", headedTable @ { { "a", "b" }, { "1", "2" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-No-Blank-Line-Before@@Tests/FormattingTables.wlt:319,1-324,2"
]

(* Two tables separated by blank lines are matched together and then split into separate cells, with a line break
   between them: *)
VerificationTest[
    {
        formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n\n| c | d |\n|---|---|\n| 3 | 4 |" ],
        formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n\n\n| c | d |\n|---|---|\n| 3 | 4 |" ]
    },
    {
        {
            headedTable @ { { "a", "b" }, { "1", "2" } },
            "\n",
            headedTable @ { { "c", "d" }, { "3", "4" } }
        },
        {
            headedTable @ { { "a", "b" }, { "1", "2" } },
            "\n",
            headedTable @ { { "c", "d" }, { "3", "4" } }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Two-Tables@@Tests/FormattingTables.wlt:328,1-347,2"
]

(* Since tables separated by blank lines are matched together, a single row after a blank line becomes a table of its
   own when it follows a table (a lone row elsewhere is text): *)
VerificationTest[
    formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n\n| x | y |" ],
    {
        headedTable @ { { "a", "b" }, { "1", "2" } },
        "\n",
        plainTable @ { { "x", "y" } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Lone-Row-After-Table@@Tests/FormattingTables.wlt:351,1-360,2"
]

(* A paragraph with pipes after a table is still text: *)
VerificationTest[
    formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n\nThe a | b | c thing" ],
    { headedTable @ { { "a", "b" }, { "1", "2" } }, "\nThe a | b | c thing" },
    SameTest -> MatchQ,
    TestID   -> "Tables-Paragraph-With-Pipes-After@@Tests/FormattingTables.wlt:363,1-368,2"
]

(* Two tables with a paragraph between them are separate tables: *)
VerificationTest[
    formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n\nText\n\n| c | d |\n|---|---|\n| 3 | 4 |" ],
    {
        headedTable @ { { "a", "b" }, { "1", "2" } },
        "\nText\n",
        headedTable @ { { "c", "d" }, { "3", "4" } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Text-Between-Tables@@Tests/FormattingTables.wlt:371,1-380,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Code Fences*)

(* A code block whose content is a markdown table is shown as a table instead of code. The text before a fenced table
   keeps its blank line (unlike an unfenced table): *)
VerificationTest[
    {
        formatTables[ "```\n| a | b |\n|---|---|\n| 1 | 2 |\n```" ],
        formatTables[ "Text\n\n```markdown\n| a | b |\n|---|---|\n| 1 | 2 |\n```\n\nAfter" ]
    },
    {
        { headedTable @ { { "a", "b" }, { "1", "2" } } },
        { "Text\n\n", headedTable @ { { "a", "b" }, { "1", "2" } }, "\nAfter" }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Fenced@@Tests/FormattingTables.wlt:388,1-399,2"
]

(* Trailing spaces after the fence language and an indented closing fence: *)
VerificationTest[
    {
        formatTables[ "```markdown  \n| a | b |\n|---|---|\n| 1 | 2 |\n```" ],
        formatTables[ "```\n| a | b |\n|---|---|\n| 1 | 2 |\n  ```" ]
    },
    {
        { headedTable @ { { "a", "b" }, { "1", "2" } } },
        { headedTable @ { { "a", "b" }, { "1", "2" } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Fenced-Variants@@Tests/FormattingTables.wlt:402,1-413,2"
]

(* Two tables in one code block are split like unfenced tables: *)
VerificationTest[
    formatTables[ "```\n| a | b |\n|---|---|\n| 1 | 2 |\n\n| c | d |\n|---|---|\n| 3 | 4 |\n```" ],
    {
        headedTable @ { { "a", "b" }, { "1", "2" } },
        "\n",
        headedTable @ { { "c", "d" }, { "3", "4" } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Fenced-Two-Tables@@Tests/FormattingTables.wlt:416,1-425,2"
]

(* An unterminated code block (e.g. while streaming) that contains a table is shown as a table: *)
VerificationTest[
    {
        formatTables[ "```\n| a | b |\n|---|---|\n| 1 | 2 |" ],
        formatTables[ "```\n| a | b |\n|---|---|\n| 1 | 2 |\n", "Streaming" ]
    },
    {
        { headedTable @ { { "a", "b" }, { "1", "2" } } },
        { headedTable @ { { "a", "b" }, { "1", "2" } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Fenced-Unterminated@@Tests/FormattingTables.wlt:428,1-439,2"
]

(* A code block stays code unless every line is a table row, and a single row is not a table: *)
VerificationTest[
    {
        FormatMarkdown[ "```\n| a | b |\nnot a row\n```" ],
        FormatMarkdown[ "```\n| a | b |\n```" ],
        FormatMarkdown[ "```\n| a | b |\n", "Streaming" ]
    },
    {
        {
            Cell[
                BoxData @ TemplateBox[ { Cell[ "| a | b |\nnot a row", "ChatPreformatted", ___ ], ___ }, "ChatCodeBlockTemplate" ],
                "ChatCodeBlock",
                ___
            ]
        },
        {
            Cell[
                BoxData @ TemplateBox[ { Cell[ "| a | b |", "ChatPreformatted", ___ ], ___ }, "ChatCodeBlockTemplate" ],
                "ChatCodeBlock",
                ___
            ]
        },
        {
            Cell[
                BoxData @ TemplateBox[ { Cell[ "| a | b |", "ChatPreformatted", ___ ], ___ }, "ChatCodeBlockTemplate" ],
                "ChatCodeBlock",
                ___
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Fenced-Not-A-Table@@Tests/FormattingTables.wlt:442,1-473,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Header and Delimiter Rows*)

(* A delimiter row with a non-empty header row gives headings: *)
VerificationTest[
    formatTables[ "| Name | Value |\n|------|-------|\n| x | 1 |\n| y | 2 |" ],
    { headedTable @ { { "Name", "Value" }, { "x", "1" }, { "y", "2" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Header-Headed@@Tests/FormattingTables.wlt:480,1-485,2"
]

(* A header row with only some empty cells still gives headings: *)
VerificationTest[
    formatTables[ "| | b |\n|---|---|\n| 1 | 2 |" ],
    { headedTable @ { { "", "b" }, { "1", "2" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Header-Partially-Empty@@Tests/FormattingTables.wlt:488,1-493,2"
]

(* A header row that is all empty (blank, or cells containing only quotes around optional whitespace) is dropped,
   giving a table without headings: *)
VerificationTest[
    {
        formatTables[ "| | |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |" ],
        formatTables[ "|   |   |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |" ],
        formatTables[ "| \"\" | \" \" |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |" ],
        formatTables[ "| \"   \" | \"\t\" |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |" ]
    },
    {
        { plainTable @ { { "1", "2" }, { "3", "4" } } },
        { plainTable @ { { "1", "2" }, { "3", "4" } } },
        { plainTable @ { { "1", "2" }, { "3", "4" } } },
        { plainTable @ { { "1", "2" }, { "3", "4" } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Header-Empty@@Tests/FormattingTables.wlt:497,1-512,2"
]

(* A single-column table with an empty header cell has no headings either: *)
VerificationTest[
    formatTables[ "| |\n|---|\n| 1 |\n| 2 |" ],
    { plainTable @ { { "1" }, { "2" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Header-Empty-Single-Column@@Tests/FormattingTables.wlt:515,1-520,2"
]

(* An empty header row without a delimiter row is an ordinary (empty) data row: *)
VerificationTest[
    formatTables[ "| | |\n| 1 | 2 |" ],
    { plainTable @ { { "", "" }, { "1", "2" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Header-Empty-No-Delimiter@@Tests/FormattingTables.wlt:523,1-528,2"
]

(* Without a delimiter row, all rows are data rows (this includes numeric rows): *)
VerificationTest[
    {
        formatTables[ "| a | b |\n| 1 | 2 |" ],
        formatTables[ "| 1 | 2 |\n| 3 | 4 |" ]
    },
    {
        { plainTable @ { { "a", "b" }, { "1", "2" } } },
        { plainTable @ { { "1", "2" }, { "3", "4" } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-No-Delimiter-Row@@Tests/FormattingTables.wlt:531,1-542,2"
]

(* A quoted cell that is not empty keeps its quotes: *)
VerificationTest[
    formatTables[ "| \"x\" | b |\n|---|---|\n| 1 | 2 |" ],
    { headedTable @ { { "\"x\"", "b" }, { "1", "2" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Header-Quoted-Text@@Tests/FormattingTables.wlt:545,1-550,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Alignment*)

(* Delimiter cells set the column alignment: ":--" is Left, ":-:" Center, "--:" Right, and plain dashes Left: *)
VerificationTest[
    formatTables[ "| a | b | c | d |\n|:--|:-:|--:|---|\n| 1 | 2 | 3 | 4 |" ],
    {
        <|
            "Grid"       -> { { "a", "b", "c", "d" }, { "1", "2", "3", "4" } },
            "Headings"   -> True,
            "Alignments" -> { Left, Center, Right, Left }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Alignment@@Tests/FormattingTables.wlt:557,1-568,2"
]

(* Any number of dashes works (including one), and spaces inside and around delimiter cells are ignored (also between
   a colon and the dashes): *)
VerificationTest[
    {
        formatTables[ "| a | b | c | d | e |\n|:-|-:|:--:|-|  :---:  |\n| 1 | 2 | 3 | 4 | 5 |" ],
        formatTables[ "| a | b |\n| :--- | ---: |\n| 1 | 2 |" ],
        formatTables[ "| a | b |\n|-|-|\n| 1 | 2 |" ],
        formatTables[ "| a | b | c |\n| : --- : | --- : | : --- |\n| 1 | 2 | 3 |" ]
    },
    {
        { KeyValuePattern[ { "Headings" -> True, "Alignments" -> { Left, Right, Center, Left, Center } } ] },
        { KeyValuePattern[ { "Headings" -> True, "Alignments" -> { Left, Right } } ] },
        { KeyValuePattern[ { "Headings" -> True, "Alignments" -> $$left } ] },
        { KeyValuePattern[ { "Headings" -> True, "Alignments" -> { Center, Right, Left } } ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Alignment-Delimiter-Variants@@Tests/FormattingTables.wlt:572,1-587,2"
]

(* A delimiter row with fewer or more cells than the header row is still a delimiter row (the number of alignments
   follows the delimiter row, which does not matter here since all columns are left aligned): *)
VerificationTest[
    {
        formatTables[ "| a | b | c |\n|---|---|\n| 1 | 2 | 3 |" ],
        formatTables[ "| a | b |\n|---|---|---|\n| 1 | 2 |" ]
    },
    {
        { headedTable @ { { "a", "b", "c" }, { "1", "2", "3" } } },
        { headedTable @ { { "a", "b" }, { "1", "2" } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Alignment-Count-Mismatch@@Tests/FormattingTables.wlt:591,1-602,2"
]

(* A typical LLM table: bold headings, aligned columns and emoji: *)
VerificationTest[
    formatTables[ "| **Feature** | **Status** |\n|:---|:---:|\n| Tables | \:2705 |\n| Math | \:274c |" ],
    {
        <|
            "Grid" -> {
                { StyleBox[ "Feature", FontWeight -> Bold ], StyleBox[ "Status", FontWeight -> Bold ] },
                { "Tables", "\:2705" },
                { "Math", "\:274c" }
            },
            "Headings"   -> True,
            "Alignments" -> { Left, Center }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Alignment-Typical@@Tests/FormattingTables.wlt:605,1-620,2"
]

(* A row that has a cell that isn't a valid delimiter ("- -", "::", "===") is not a delimiter row: *)
VerificationTest[
    {
        formatTables[ "| a | b |\n|- -|---|\n| 1 | 2 |" ],
        formatTables[ "| a | b |\n|::|---|\n| 1 | 2 |" ],
        formatTables[ "| a | b |\n|===|===|\n| 1 | 2 |" ]
    },
    {
        { plainTable @ { { "a", "b" }, { "- -", "---" }, { "1", "2" } } },
        { plainTable @ { { "a", "b" }, { "::", "---" }, { "1", "2" } } },
        { plainTable @ { { "a", "b" }, { "===", "===" }, { "1", "2" } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Invalid-Delimiter-Cells@@Tests/FormattingTables.wlt:623,1-636,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Table Shape*)

(* Rows of different lengths are padded with empty items to the longest row: *)
VerificationTest[
    {
        formatTables[ "| a | b | c |\n|---|---|---|\n| 1 | 2 |\n| 3 | 4 | 5 | 6 |" ],
        formatTables[ "| a | b |\n| 1 |\n| 2 | 3 | 4 |" ]
    },
    {
        { headedTable @ { { "a", "b", "c", "" }, { "1", "2", "", "" }, { "3", "4", "5", "6" } } },
        { plainTable @ { { "a", "b", "" }, { "1", "", "" }, { "2", "3", "4" } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Ragged-Rows@@Tests/FormattingTables.wlt:643,1-654,2"
]

(* When rows have to be padded, a last column that only contains empty items is removed: *)
VerificationTest[
    formatTables[ "| a | b | |\n| 1 | 2 |" ],
    { plainTable @ { { "a", "b" }, { "1", "2" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Ragged-Trim-Empty-Column@@Tests/FormattingTables.wlt:657,1-662,2"
]

(* Empty cells in the middle of a row are kept, whether they contain spaces or not: *)
VerificationTest[
    {
        formatTables[ "| a |  | c |\n| 1 || 3 |" ],
        formatTables[ "| a | b |\n|---|---|\n|  | 2 |\n| 1 |  |" ],
        formatTables[ "| a | b |\n|---|---|\n| | |" ]
    },
    {
        { plainTable @ { { "a", "", "c" }, { "1", "", "3" } } },
        { headedTable @ { { "a", "b" }, { "", "2" }, { "1", "" } } },
        { headedTable @ { { "a", "b" }, { "", "" } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Empty-Cells@@Tests/FormattingTables.wlt:665,1-678,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cell Contents*)

(* Bold and italic text in cells (with asterisks or underscores): *)
VerificationTest[
    formatTables[ "| **bold** | *italic* | ***both*** |\n|---|---|---|\n| __b2__ | _i2_ | plain |" ],
    {
        headedTable @ {
            {
                StyleBox[ "bold", FontWeight -> Bold ],
                StyleBox[ "italic", FontSlant -> Italic ],
                StyleBox[ "both", OrderlessPatternSequence[ FontWeight -> Bold, FontSlant -> Italic ] ]
            },
            {
                StyleBox[ "b2", FontWeight -> Bold ],
                StyleBox[ "i2", FontSlant -> Italic ],
                "plain"
            }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Contents-Emphasis@@Tests/FormattingTables.wlt:685,1-703,2"
]

(* Strikethrough text in cells: *)
VerificationTest[
    formatTables[ "| ~~old~~ | new |\n|---|---|\n| 1 | 2 |" ],
    {
        headedTable @ {
            { StyleBox[ "old", FontVariations -> { "StrikeThrough" -> True } ], "new" },
            { "1", "2" }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Contents-Strikethrough@@Tests/FormattingTables.wlt:706,1-716,2"
]

(* Dollar signs in prices are not math, since each cell is formatted separately: *)
VerificationTest[
    formatTables[ "| Item | Price |\n|---|---|\n| Apple | $5 and $10 |\n| Pear | $2.50 |" ],
    { headedTable @ { { "Item", "Price" }, { "Apple", "$5 and $10" }, { "Pear", "$2.50" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Contents-Prices@@Tests/FormattingTables.wlt:719,1-724,2"
]

(* A cell that is only WL code (without backticks) is formatted as WL code, as it is in text: *)
VerificationTest[
    formatTables[ "| Function | Example |\n|---|---|\n| Plot | Plot[Sin[x], {x, 0, Pi}] |" ],
    {
        headedTable @ {
            { "Function", "Example" },
            { "Plot", Cell[ BoxData @ RowBox @ { "Plot", "[", _, "]" }, "InlineWL", ___ ] }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Contents-Bare-WL-Code@@Tests/FormattingTables.wlt:727,1-737,2"
]

(* Inline code in cells is formatted the same way as in text: a symbol-like name is italic ("TI"), a System symbol is a
   documentation link, WL code is an "InlineWL" cell, and other code is inline code: *)
VerificationTest[
    formatTables[ "| `code` | `Table` | `Plot[x, {x, 0, 1}]` |\n|---|---|---|\n| `x = 1` | y | c |" ],
    {
        headedTable @ {
            {
                StyleBox[ "code", "TI" ],
                Cell @ BoxData @ TemplateBox[ { "Table", "paclet:ref/Table", _String }, "TextRefLink" ],
                Cell[ BoxData @ RowBox @ { "Plot", "[", _, "]" }, "InlineWL", ___ ]
            },
            {
                Cell[ BoxData @ TemplateBox[ { Cell[ "x = 1", ___ ] }, "ChatCodeInlineTemplate" ], "ChatCodeActive", ___ ],
                "y",
                "c"
            }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Contents-Inline-Code@@Tests/FormattingTables.wlt:741,1-759,2"
]

(* Hyperlinks and documentation links: *)
VerificationTest[
    formatTables[ "| [label](https://example.com) | [`Table`](paclet:ref/Table) |\n|---|---|\n| x | y |" ],
    {
        headedTable @ {
            {
                ButtonBox[
                    "label",
                    OrderlessPatternSequence[
                        BaseStyle  -> "Hyperlink",
                        ButtonData -> { URL[ "https://example.com" ], None },
                        ___
                    ]
                ],
                Cell @ BoxData @ TemplateBox[ { "Table", "paclet:ref/Table", _String }, "TextRefLink" ]
            },
            { "x", "y" }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Contents-Links@@Tests/FormattingTables.wlt:762,1-782,2"
]

(* Math in cells ($...$, $$...$$ and \(...\)); math that is only a number is plain text: *)
VerificationTest[
    formatTables[ "| $x^2$ | $$\\alpha$$ | \\(y\\) |\n|---|---|---|\n| $1$ | 2 | 3 |" ],
    {
        headedTable @ {
            {
                Cell @ BoxData @ FormBox[
                    TemplateBox[ KeyValuePattern @ { "input" -> "x^2", "state" -> "Boxes" }, "TeXAssistantTemplate" ],
                    TraditionalForm
                ],
                Cell @ BoxData @ FormBox[
                    TemplateBox[ KeyValuePattern @ { "input" -> "\\alpha", "state" -> "Boxes" }, "TeXAssistantTemplate" ],
                    TraditionalForm
                ],
                Cell @ BoxData @ FormBox[
                    TemplateBox[ KeyValuePattern @ { "input" -> "y", "state" -> "Boxes" }, "TeXAssistantTemplate" ],
                    TraditionalForm
                ]
            },
            { "1", "2", "3" }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Contents-Math@@Tests/FormattingTables.wlt:785,1-808,2"
]

(* A cell that mixes formatted and plain text is a nested TextData cell: *)
VerificationTest[
    formatTables[ "| **a** text | b `c` d |\n|---|---|\n| x *y* z | w |" ],
    {
        headedTable @ {
            {
                Cell @ TextData @ { StyleBox[ "a", FontWeight -> Bold ], " text" },
                Cell @ TextData @ { "b ", StyleBox[ "c", "TI" ], " d" }
            },
            {
                Cell @ TextData @ { "x ", StyleBox[ "y", FontSlant -> Italic ], " z" },
                "w"
            }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Contents-Mixed@@Tests/FormattingTables.wlt:811,1-827,2"
]

(* Unicode text and HTML entities in cells, and markdown characters that have no meaning on their own: *)
VerificationTest[
    {
        formatTables[ "| \[Alpha] | \:4e2d\:6587 | \:2713 |\n|---|---|---|\n| \[Beta] | \:65e5\:672c | \:2717 |" ],
        formatTables[ "| a &amp; b | &lt;x&gt; |\n|---|---|\n| 1 | 2 |" ],
        formatTables[ "| # | * | Name |\n|---|---|---|\n| 1 | - | x |" ]
    },
    {
        { headedTable @ { { "\[Alpha]", "\:4e2d\:6587", "\:2713" }, { "\[Beta]", "\:65e5\:672c", "\:2717" } } },
        { headedTable @ { { "a & b", "<x>" }, { "1", "2" } } },
        { headedTable @ { { "#", "*", "Name" }, { "1", "-", "x" } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Contents-Unicode-And-Entities@@Tests/FormattingTables.wlt:830,1-843,2"
]

(* Long cell contents are kept whole: *)
VerificationTest[
    formatTables[ "| Name | Description |\n|---|---|\n| x | " <> StringRepeat[ "long ", 50 ] <> "|" ],
    { headedTable @ { { "Name", "Description" }, { "x", StringTrim @ StringRepeat[ "long ", 50 ] } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Contents-Long-Cell@@Tests/FormattingTables.wlt:846,1-851,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Escaped Characters*)

(* An escaped pipe is part of the cell text instead of separating cells (the response goes through the escaped
   markdown path): *)
VerificationTest[
    {
        formatTables[ "| a \\| b | c |\n|---|---|\n| 1 | 2 |" ],
        formatTables[ "| a | b |\n|---|---|\n| x \\| y | 2 |" ]
    },
    {
        { headedTable @ { { "a | b", "c" }, { "1", "2" } } },
        { headedTable @ { { "a", "b" }, { "x | y", "2" } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Escaped-Pipe@@Tests/FormattingTables.wlt:859,1-870,2"
]

(* An escaped pipe inside inline code in a cell: *)
VerificationTest[
    formatTables[ "| `a\\|b` | c |\n|---|---|\n| 1 | 2 |" ],
    {
        headedTable @ {
            {
                Cell[ BoxData @ TemplateBox[ { Cell[ "a|b", ___ ] }, "ChatCodeInlineTemplate" ], "ChatCodeActive", ___ ],
                "c"
            },
            { "1", "2" }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Escaped-Pipe-In-Inline-Code@@Tests/FormattingTables.wlt:873,1-886,2"
]

(* Other escaped markdown characters in cells are shown literally: *)
VerificationTest[
    formatTables[ "| a | b |\n|---|---|\n| \\*x\\* | 2 |" ],
    { headedTable @ { { "a", "b" }, { "*x*", "2" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Escaped-Asterisks@@Tests/FormattingTables.wlt:889,1-894,2"
]

(* Tables with an escape elsewhere get the same line breaks as without escapes (a fenced one keeps the blank line): *)
VerificationTest[
    {
        formatTables[ "Price \\$5\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nDone" ],
        formatTables[ "\\* x\n\n```\n| a | b |\n|---|---|\n| 1 | 2 |\n```" ]
    },
    {
        { "Price $5\n", headedTable @ { { "a", "b" }, { "1", "2" } }, "\nDone" },
        { "* x\n\n", headedTable @ { { "a", "b" }, { "1", "2" } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Escaped-Elsewhere@@Tests/FormattingTables.wlt:897,1-908,2"
]

(* A table followed by a code block when the response contains an escape: *)
VerificationTest[
    formatTables[ "Text \\* x\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n```wl\n1+1\n```" ],
    {
        "Text * x\n",
        headedTable @ { { "a", "b" }, { "1", "2" } },
        Repeated[ "\n", { 0, 1 } ],
        Cell[ BoxData @ TemplateBox[ { Cell[ _, "ChatCode", ___ ], "Wolfram" }, "ChatCodeBlockTemplate" ], "ChatCodeBlock", ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Escaped-Code-Block-After@@Tests/FormattingTables.wlt:911,1-921,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Neighboring Blocks*)

(* A heading directly before a table, with or without a blank line: *)
VerificationTest[
    {
        formatTables[ "## Results\n| a | b |\n|---|---|\n| 1 | 2 |" ],
        formatTables[ "## Results\n\n| a | b |\n|---|---|\n| 1 | 2 |" ]
    },
    {
        {
            Cell[ BoxData @ PaneBox[ StyleBox[ "\"Results\"", "Section", ___ ], ___ ], "InlineSection", ___ ],
            "\n",
            headedTable @ { { "a", "b" }, { "1", "2" } }
        },
        {
            Cell[ BoxData @ PaneBox[ StyleBox[ "\"Results\"", "Section", ___ ], ___ ], "InlineSection", ___ ],
            "\n",
            headedTable @ { { "a", "b" }, { "1", "2" } }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-After-Heading@@Tests/FormattingTables.wlt:928,1-947,2"
]

(* A list item and a code block directly before a table: *)
VerificationTest[
    {
        formatTables[ "- item\n| a | b |\n|---|---|\n| 1 | 2 |" ],
        formatTables[ "```wl\n1+1\n```\n| a | b |\n|---|---|\n| 1 | 2 |" ]
    },
    {
        {
            Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " item" }, "InlineItem", ___ ],
            "\n",
            headedTable @ { { "a", "b" }, { "1", "2" } }
        },
        {
            Cell[ _, "ChatCodeBlock", ___ ],
            "\n",
            headedTable @ { { "a", "b" }, { "1", "2" } }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-After-Item-And-Code-Block@@Tests/FormattingTables.wlt:950,1-969,2"
]

(* A list and a "---" delimiter directly before a table: *)
VerificationTest[
    {
        formatTables[ "- item one\n- item two\n\n| a | b |\n|---|---|\n| 1 | 2 |" ],
        formatTables[ "---\n| a | b |\n|---|---|\n| 1 | 2 |" ]
    },
    {
        {
            Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " item one" }, "InlineItem", ___ ],
            "\n",
            Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " item two" }, "InlineItem", ___ ],
            "\n",
            headedTable @ { { "a", "b" }, { "1", "2" } }
        },
        {
            Cell[ _, "MarkdownDelimiter", ___ ],
            "\n",
            headedTable @ { { "a", "b" }, { "1", "2" } }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-After-List-And-Delimiter@@Tests/FormattingTables.wlt:972,1-993,2"
]

(* Blocks after a table and a blank line: *)
VerificationTest[
    {
        formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n\n## Next" ],
        formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n\n- item" ],
        formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n\n---\n\nText" ],
        formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n\n```wl\n1+1\n```" ],
        formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n\n> quote" ]
    },
    {
        {
            headedTable @ { { "a", "b" }, { "1", "2" } },
            "\n",
            Cell[ BoxData @ PaneBox[ StyleBox[ "\"Next\"", "Section", ___ ], ___ ], "InlineSection", ___ ]
        },
        {
            headedTable @ { { "a", "b" }, { "1", "2" } },
            "\n",
            Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " item" }, "InlineItem", ___ ]
        },
        { headedTable @ { { "a", "b" }, { "1", "2" } }, "\n", Cell[ _, "MarkdownDelimiter", ___ ], "\nText" },
        {
            headedTable @ { { "a", "b" }, { "1", "2" } },
            "\n",
            Cell[ BoxData @ TemplateBox[ { Cell[ _, "ChatCode", ___ ], "Wolfram" }, "ChatCodeBlockTemplate" ], "ChatCodeBlock", ___ ]
        },
        { headedTable @ { { "a", "b" }, { "1", "2" } }, "\n", Cell[ _, "BlockQuote", ___ ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Blocks-After@@Tests/FormattingTables.wlt:996,1-1025,2"
]

(* List items take precedence over table rows, so list items that contain pipes stay list items: *)
VerificationTest[
    NormalizeTextData @ FormatMarkdown[ "- a | b | c\n- d | e | f" ],
    {
        Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " a | b | c" }, "InlineItem", ___ ],
        "\n",
        Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " d | e | f" }, "InlineItem", ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-List-Items-With-Pipes@@Tests/FormattingTables.wlt:1028,1-1037,2"
]

(* A code block directly after a table (no blank line) is still a separate block: *)
VerificationTest[
    formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n```wl\n1+1\n```" ],
    {
        headedTable @ { { "a", "b" }, { "1", "2" } },
        Repeated[ "\n", { 0, 1 } ],
        Cell[ _, "ChatCodeBlock", ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Code-Block-Directly-After@@Tests/FormattingTables.wlt:1040,1-1049,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Streaming*)

(* Tables with plain or emphasized text look the same while streaming as when finished: *)
VerificationTest[
    Map[
        formatTables[ #, "Streaming" ] === formatTables[ # ] &,
        {
            "| a | b |\n|---|---|\n| 1 | 2 |",
            "| a | b |\n| 1 | 2 |",
            "| | |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |",
            "| a | b | c | d |\n|:--|:-:|--:|---|\n| 1 | 2 | 3 | 4 |",
            "| a | b | c |\n|---|---|---|\n| 1 | 2 |\n| 3 | 4 | 5 | 6 |",
            "| **bold** | *italic* | ***both*** |\n|---|---|---|\n| __b2__ | _i2_ | plain |",
            "| [label](https://example.com) | [`Table`](paclet:ref/Table) |\n|---|---|\n| x | y |",
            "| a \\| b | c |\n|---|---|\n| 1 | 2 |",
            "Before\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nAfter",
            "```\n| a | b |\n|---|---|\n| 1 | 2 |\n```"
        }
    ],
    { True, True, True, True, True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Tables-Streaming-Same-As-Finished@@Tests/FormattingTables.wlt:1056,1-1075,2"
]

(* While streaming, math in cells uses the cheaper TeX boxes and WL code is not parsed yet: *)
VerificationTest[
    formatTables[ "| $x^2$ | `Plot[x, {x, 0, 1}]` |\n|---|---|\n| `x = 1` | c |", "Streaming" ],
    {
        headedTable @ {
            {
                Cell @ BoxData @ FormBox[
                    StyleBox[ FormBox[ _SuperscriptBox, TraditionalForm ], "TeXAssistantBoxes" ],
                    TraditionalForm
                ],
                Cell[ BoxData[ "Plot[x, {x, 0, 1}]" ], "InlineWL", ___ ]
            },
            {
                Cell[ BoxData @ TemplateBox[ { Cell[ "x = 1", ___ ] }, "ChatCodeInlineTemplate" ], "ChatCodeActive", ___ ],
                "c"
            }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Streaming-Math-And-Code@@Tests/FormattingTables.wlt:1078,1-1097,2"
]

(* While the first row and the start of the delimiter row are streaming in, there is only one row, so it is text: *)
VerificationTest[
    FormatMarkdown[ #, "Streaming" ] & /@ {
        "| a",
        "| a |",
        "| a | b |",
        "| a | b |\n",
        "| a | b |\n|",
        "| a | b |\n|---"
    },
    {
        { "| a" },
        { "| a |" },
        { "| a | b |" },
        { "| a | b |" },
        { "| a | b |\n|" },
        { "| a | b |\n|---" }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Streaming-First-Row@@Tests/FormattingTables.wlt:1100,1-1119,2"
]

(* Once the first body row is complete, the table is the same as the finished one: *)
VerificationTest[
    formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |", "Streaming" ],
    { headedTable @ { { "a", "b" }, { "1", "2" } } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Streaming-Complete-Row@@Tests/FormattingTables.wlt:1122,1-1127,2"
]

(* A later row is added to the table as soon as it has a closing pipe, padded to the width of the table: *)
VerificationTest[
    {
        formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n| 3 |", "Streaming" ],
        formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |", "Streaming" ]
    },
    {
        { headedTable @ { { "a", "b" }, { "1", "2" }, { "3", "" } } },
        { headedTable @ { { "a", "b" }, { "1", "2" }, { "3", "4" } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Streaming-Later-Rows@@Tests/FormattingTables.wlt:1130,1-1141,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Serialization*)

(* A headed table serializes to a markdown table with padded columns: *)
VerificationTest[
    {
        MarkdownRoundTrip[ "| a | b |\n|---|---|\n| 1 | 2 |" ],
        MarkdownRoundTrip[ "| Name | Description |\n|------|-------------|\n| Alpha | The first letter |\n| Beta | Second |" ]
    },
    {
        "| a | b |\n| - | - |\n| 1 | 2 |",
        "| Name  | Description      |\n| ----- | ---------------- |\n| Alpha | The first letter |\n| Beta  | Second           |"
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Serialization-Headed@@Tests/FormattingTables.wlt:1148,1-1159,2"
]

(* The same for tables written without outer pipes, with only one dash per delimiter cell, or in a code block (the
   fences are not kept, and the blank line after the table is currently lost): *)
VerificationTest[
    {
        MarkdownRoundTrip[ "a | b | c\n--- | --- | ---\n1 | 2 | 3" ],
        MarkdownRoundTrip[ "| a | b |\n|-|-|\n| 1 | 2 |" ],
        MarkdownRoundTrip[ "Text\n\n```markdown\n| a | b |\n|---|---|\n| 1 | 2 |\n```\n\nAfter" ]
    },
    {
        "| a | b | c |\n| - | - | - |\n| 1 | 2 | 3 |",
        "| a | b |\n| - | - |\n| 1 | 2 |",
        _String? (StringMatchQ[ "Text\n\n| a | b |\n| - | - |\n| 1 | 2 |\n" ~~ "\n"... ~~ "After" ])
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Serialization-Row-Forms@@Tests/FormattingTables.wlt:1163,1-1176,2"
]

(* Tables without headings get an empty header row, so the serialized table is still valid markdown: *)
VerificationTest[
    {
        MarkdownRoundTrip[ "| a | b |\n| 1 | 2 |" ],
        MarkdownRoundTrip[ "| | |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |" ],
        MarkdownRoundTrip[ "| | b |\n|---|---|\n| 1 | 2 |" ]
    },
    {
        "|   |   |\n| - | - |\n| a | b |\n| 1 | 2 |",
        "|   |   |\n| - | - |\n| 1 | 2 |\n| 3 | 4 |",
        "|   | b |\n| - | - |\n| 1 | 2 |"
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Serialization-No-Headings@@Tests/FormattingTables.wlt:1179,1-1192,2"
]

(* Single-column tables, with and without headings: *)
VerificationTest[
    {
        MarkdownRoundTrip[ "| a |\n|---|\n| 1 |\n| 2 |" ],
        MarkdownRoundTrip[ "| a |\n| 1 |\n| 2 |" ]
    },
    {
        "| a |\n| - |\n| 1 |\n| 2 |",
        "|   |\n| - |\n| a |\n| 1 |\n| 2 |"
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Serialization-Single-Column@@Tests/FormattingTables.wlt:1195,1-1206,2"
]

(* Padded ragged rows and empty cells: *)
VerificationTest[
    {
        MarkdownRoundTrip[ "| a | b | c |\n|---|---|---|\n| 1 | 2 |\n| 3 | 4 | 5 | 6 |" ],
        MarkdownRoundTrip[ "| a | b |\n|---|---|\n|  | 2 |\n| 1 |  |" ],
        MarkdownRoundTrip[ "| a | b |\n|---|---|\n| | |" ]
    },
    {
        "| a | b | c |   |\n| - | - | - | - |\n| 1 | 2 |   |   |\n| 3 | 4 | 5 | 6 |",
        "| a | b |\n| - | - |\n|   | 2 |\n| 1 |   |",
        "| a | b |\n| - | - |\n|   |   |"
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Serialization-Shape@@Tests/FormattingTables.wlt:1209,1-1222,2"
]

(* Pipes in cell text are escaped again: *)
VerificationTest[
    MarkdownRoundTrip[ "| a \\| b | c |\n|---|---|\n| 1 | 2 |" ],
    "| a \\| b | c |\n| ------ | - |\n| 1      | 2 |",
    SameTest -> MatchQ,
    TestID   -> "Tables-Serialization-Escaped-Pipe@@Tests/FormattingTables.wlt:1225,1-1230,2"
]

(* Emphasis, links and math in cells serialize as markdown (math as $$...$$): *)
VerificationTest[
    {
        MarkdownRoundTrip[ "| **bold** | *italic* | ***both*** |\n|---|---|---|\n| __b2__ | _i2_ | plain |" ],
        MarkdownRoundTrip[ "| [label](https://example.com) | b |\n|---|---|\n| 1 | 2 |" ],
        MarkdownRoundTrip[ "| $x^2$ | $$\\alpha$$ | \\(y\\) |\n|---|---|---|\n| $1$ | 2 | 3 |" ],
        MarkdownRoundTrip[ "| ~~old~~ | new |\n|---|---|\n| 1 | 2 |" ]
    },
    {
        "| **bold** | *italic* | ***both*** |\n| -------- | -------- | ---------- |\n| **b2**   | *i2*     | plain      |",
        "| [label](https://example.com) | b |\n| ---------------------------- | - |\n| 1                            | 2 |",
        "| $$x^2$$ | $$\\alpha$$ | $$y$$ |\n| ------- | ---------- | ----- |\n| 1       | 2          | 3     |",
        "| ~~old~~ | new |\n| ------- | --- |\n| 1       | 2   |"
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Serialization-Formatted-Contents@@Tests/FormattingTables.wlt:1233,1-1248,2"
]

(* Inline code and documentation links in cells are serialized without backticks (grid items are serialized as if they
   were already inside inline code): *)
VerificationTest[
    {
        MarkdownRoundTrip[ "| `code` | `Table` | `Plot[x, {x, 0, 1}]` |\n|---|---|---|\n| `x = 1` | y | c |" ],
        MarkdownRoundTrip[ "| [`Table`](paclet:ref/Table) | b `c` d |\n|---|---|\n| 1 | 2 |" ],
        MarkdownRoundTrip[ "| Function | Example |\n|---|---|\n| Plot | Plot[Sin[x], {x, 0, Pi}] |" ]
    },
    {
        "| code  | Table | Plot[x, {x, 0, 1}] |\n| ----- | ----- | ------------------ |\n| x = 1 | y     | c                  |",
        "| Table | b c d |\n| ----- | ----- |\n| 1     | 2     |",
        "| Function | Example                  |\n| -------- | ------------------------ |\n| Plot     | Plot[Sin[x], {x, 0, Pi}] |"
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Serialization-Inline-Code@@Tests/FormattingTables.wlt:1252,1-1265,2"
]

(* Unicode, HTML entities, quotes, dollar signs and other markdown characters in cells (they are not escaped): *)
VerificationTest[
    {
        MarkdownRoundTrip[ "| \[Alpha] | \:4e2d\:6587 | \:2713 |\n|---|---|---|\n| \[Beta] | \:65e5\:672c | \:2717 |" ],
        MarkdownRoundTrip[ "| a &amp; b | c |\n|---|---|\n| 1 | 2 |" ],
        MarkdownRoundTrip[ "| \"x\" | b |\n|---|---|\n| 1 | 2 |" ],
        MarkdownRoundTrip[ "| Item | Price |\n|---|---|\n| Apple | $5 and $10 |\n| Pear | $2.50 |" ],
        MarkdownRoundTrip[ "| # | * | Name |\n|---|---|---|\n| 1 | - | x |" ]
    },
    {
        "| \[Alpha] | \:4e2d\:6587 | \:2713 |\n| - | -- | - |\n| \[Beta] | \:65e5\:672c | \:2717 |",
        "| a & b | c |\n| ----- | - |\n| 1     | 2 |",
        "| \"x\" | b |\n| --- | - |\n| 1   | 2 |",
        "| Item  | Price      |\n| ----- | ---------- |\n| Apple | $5 and $10 |\n| Pear  | $2.50      |",
        "| # | * | Name |\n| - | - | ---- |\n| 1 | - | x    |"
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Serialization-Text-Contents@@Tests/FormattingTables.wlt:1268,1-1285,2"
]

(* Text and headings around a table (the blank line after the table is currently not kept, see the quirks): *)
VerificationTest[
    {
        MarkdownRoundTrip[ "Before\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nAfter" ],
        MarkdownRoundTrip[ "## Results\n\n| a | b |\n|---|---|\n| 1 | 2 |" ]
    },
    {
        _String? (StringMatchQ[ "Before" ~~ " "... ~~ "\n" ~~ "\n"... ~~ "| a | b |\n| - | - |\n| 1 | 2 |\n" ~~ "\n"... ~~ "After" ]),
        "## Results\n\n| a | b |\n| - | - |\n| 1 | 2 |"
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Serialization-Text-Around@@Tests/FormattingTables.wlt:1288,1-1299,2"
]

(* The header and data rows of an aligned table are kept (whether the alignment is kept is not tested here, see the
   notes for the rewrite): *)
VerificationTest[
    MarkdownRoundTrip[ "| a | b | c | d |\n|:--|:-:|--:|---|\n| 1 | 2 | 3 | 4 |" ],
    _String? (StringMatchQ[ "| a | b | c | d |\n| " ~~ Except[ "\n" ].. ~~ " |\n| 1 | 2 | 3 | 4 |" ]),
    SameTest -> MatchQ,
    TestID   -> "Tables-Serialization-Aligned-Content@@Tests/FormattingTables.wlt:1303,1-1308,2"
]

(* A very long cell is kept whole, while the other columns are padded to at most three characters: *)
VerificationTest[
    MarkdownRoundTrip[ "| a | b |\n|---|---|\n| " <> StringRepeat[ "word ", 40 ] <> "| x |" ],
    "| a   | b |\n| --- | - |\n| " <> StringTrim @ StringRepeat[ "word ", 40 ] <> " | x |",
    SameTest -> MatchQ,
    TestID   -> "Tables-Serialization-Long-Cell@@Tests/FormattingTables.wlt:1311,1-1316,2"
]

(* Formatting the serialized markdown again gives the same table: *)
VerificationTest[
    Map[
        reformatted[ formatTables @ MarkdownRoundTrip[ # ] ] === reformatted[ formatTables[ # ] ] &,
        {
            "| a | b |\n|---|---|\n| 1 | 2 |",
            "| a | b |\n| 1 | 2 |",
            "| | |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |",
            "| a | b | c |\n|---|---|---|\n| 1 | 2 |\n| 3 | 4 | 5 | 6 |",
            "| a \\| b | c |\n|---|---|\n| 1 | 2 |",
            "| **bold** | *italic* | ***both*** |\n|---|---|---|\n| __b2__ | _i2_ | plain |",
            "| [label](https://example.com) | b |\n|---|---|\n| 1 | 2 |",
            "Before\n\n| a | b |\n|---|---|\n| 1 | 2 |",
            "| ~~old~~ | new |\n|---|---|\n| 1 | 2 |",
            "| Item | Price |\n|---|---|\n| Apple | $5 and $10 |\n| Pear | $2.50 |",
            "| a |\n| 1 |\n| 2 |"
        }
    ],
    { True, True, True, True, True, True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Tables-Serialization-Reformat@@Tests/FormattingTables.wlt:1319,1-1339,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Blocks Directly After a Table*)

(* A table doesn't take the "\n" after its last row, so the text after it starts on a new line, with or without a
   blank line (it used to be drawn next to the last row), and more blank lines leave a blank line, as they do after the
   other blocks: *)
VerificationTest[
    {
        formatTables[ "Before\n| a | b |\n|---|---|\n| 1 | 2 |\nAfter text here" ],
        formatTables[ "Before\n| a | b |\n|---|---|\n| 1 | 2 |\n\nAfter text here" ],
        formatTables[ "Before\n| a | b |\n|---|---|\n| 1 | 2 |\n\n\nAfter text here" ],
        formatTables[ "a | b | c\n1 | 2 | 3\nAfter" ]
    },
    {
        { "Before\n", headedTable @ { { "a", "b" }, { "1", "2" } }, "\nAfter text here" },
        { "Before\n", headedTable @ { { "a", "b" }, { "1", "2" } }, "\nAfter text here" },
        { "Before\n", headedTable @ { { "a", "b" }, { "1", "2" } }, "\n\nAfter text here" },
        { plainTable @ { { "a", "b", "c" }, { "1", "2", "3" } }, "\nAfter" }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Text-Directly-After@@Tests/FormattingTables.wlt:1348,1-1363,2"
]

(* A list item, heading, horizontal rule, quote or code block on the line after a table is formatted as that block: *)
VerificationTest[
    formatTables[ "| a | b |\n|---|---|\n| 1 | 2 |\n" <> # ] & /@
        { "- item", "## Next", "---", "> quote", "```wl\n1+1\n```" },
    {
        { headedTable @ { { "a", "b" }, { "1", "2" } }, "\n", Cell[ _, "InlineItem", ___ ] },
        { headedTable @ { { "a", "b" }, { "1", "2" } }, "\n", Cell[ _, "InlineSection", ___ ] },
        { headedTable @ { { "a", "b" }, { "1", "2" } }, "\n", Cell[ _, "MarkdownDelimiter", ___ ] },
        { headedTable @ { { "a", "b" }, { "1", "2" } }, "\n", Cell[ _, "BlockQuote", ___ ] },
        { headedTable @ { { "a", "b" }, { "1", "2" } }, "\n", Cell[ _, "ChatCodeBlock", ___ ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Tables-Blocks-Directly-After@@Tests/FormattingTables.wlt:1366,1-1378,2"
]

(* While streaming, a later row is shown as text on the line after the table until it has a closing pipe (see
   Tables-Streaming-Later-Rows): *)
VerificationTest[
    formatTables[ #, "Streaming" ] & /@ { "| a | b |\n|---|---|\n| 1 | 2 |\n", "| a | b |\n|---|---|\n| 1 | 2 |\n| 3" },
    { { headedTable @ { { "a", "b" }, { "1", "2" } } }, { headedTable @ { { "a", "b" }, { "1", "2" } }, "\n| 3" } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Streaming-Partial-Row@@Tests/FormattingTables.wlt:1382,1-1387,2"
]

(* The text after a table is serialized on its own line (the space before a line break is invisible), and formatting
   the serialized markdown again gives the same output: *)
VerificationTest[
    {
        StringReplace[ MarkdownRoundTrip[ "Before\n| a | b |\n|---|---|\n| 1 | 2 |\nAfter" ], " \n" -> "\n" ],
        Map[
            reformatted[ formatTables @ MarkdownRoundTrip[ # ] ] === reformatted[ formatTables[ # ] ] &,
            { "Before\n| a | b |\n|---|---|\n| 1 | 2 |\nAfter", "| a | b |\n|---|---|\n| 1 | 2 |\n- item" }
        ]
    },
    { "Before\n| a | b |\n| - | - |\n| 1 | 2 |\nAfter", { True, True } },
    SameTest -> MatchQ,
    TestID   -> "Tables-Serialization-Text-Directly-After@@Tests/FormattingTables.wlt:1391,1-1402,2"
]

(* A tool call after a table starts on its own line in the serialized text, as the chat history needs: *)
VerificationTest[
    With[ { tc = "TOOLCALL: wolfram_language_evaluator\n{\"code\":\"1\"}\nRESULT\n1\nENDRESULT(abc)" },
        StringReplace[ MarkdownRoundTrip[ "| a | b |\n|---|---|\n| 1 | 2 |\n" <> tc <> "\nText" ], " \n" -> "\n" ]
    ],
    "| a | b |\n| - | - |\n| 1 | 2 |\n" <>
        "TOOLCALL: wolfram_language_evaluator\n{\"code\":\"1\"}\nRESULT\n1\nENDRESULT(abc)\nText",
    SameTest -> MatchQ,
    TestID   -> "Tables-Tool-Call-Directly-After-Serialization@@Tests/FormattingTables.wlt:1405,1-1413,2"
]
