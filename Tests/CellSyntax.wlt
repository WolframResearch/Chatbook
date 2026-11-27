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

(* Tests for the cell syntax of docs/cell-syntax.md: reading with CellToString ("IncludeXML" for cell tags and
   "PreserveBoxes" for exact bodies), writing with cellsFromString, and round trips. Reading needs no front end. Writing
   code needs one, since the front end tokenizes it. The stores that reading writes to ($attachments,
   $notebookAttachments, $cellOriginals) are Blocked in the tests that use them, so that nothing is left for other test
   files (CI runs them all in one kernel), and so is what a test reads of the chat ($selectedTools). *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    (* CI runs every test file in one kernel and one context: these helpers are only defined here *)
    ClearAll[
        csTag, csExact, csBody, csExactBody, csCode
    ];

    (* Cells in cell tags, with lossy and with exact bodies *)
    csTag[ cell_, opts___ ]   := CellToString[ cell, "IncludeXML" -> True, opts ];
    csExact[ cell_, opts___ ] := CellToString[ cell, "IncludeXML" -> True, "PreserveBoxes" -> True, opts ];

    (* The body of a single cell tag *)
    csBody[ tag_String ] := Replace[
        StringCases[
            tag,
            StartOfString ~~ "<cell" ~~ Except[ "\n" ]... ~~ ">\n" ~~ body___ ~~ "\n</cell>" ~~ EndOfString :> body
        ],
        { { body_ } :> body, _ :> $Failed }
    ];

    csExactBody[ cell_, opts___ ] := csBody @ csExact[ cell, opts ];

    (* The exact body of an Input cell with these boxes, and of a Text cell with these items *)
    csCode[ boxes_ ] := csExactBody @ Cell[ BoxData @ boxes, "Input" ];

    True,
    True,
    SameTest -> MatchQ,
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*The Cell Tag*)
(* Every option that is not hidden is in the options attribute, in InputForm and in the order of the cell: *)
VerificationTest[
    csTag @ Cell[
        "Hello world",
        "Text",
        "Extra",
        CellLabel -> "Note 1",
        CellTags -> { "intro", "draft" },
        CellFrame -> True,
        Background -> RGBColor[ 0.14, 0.8, 0.14 ],
        CellMargins :> { { 10, 10 }, { 5, 5 } }
    ],
    StringJoin[
        "<cell id='c1' style='Text, Extra' CellLabel='Note 1' CellTags='intro,draft' ",
        "options='CellFrame -> True, Background -> RGBColor[0.14, 0.8, 0.14], CellMargins :> {{10, 10}, {5, 5}}'>\n",
        "Hello world\n</cell>"
    ],
    SameTest -> MatchQ,
    TestID   -> "Tag-Attributes"
]

(* The options that say nothing to a reader are left out, with the pseudo-option that notebookRead adds: *)
VerificationTest[
    csTag @ Cell[
        "x",
        "Text",
        ExpressionUUID -> "5ec7a6f0-4a9d-4b62-8d0c-0d4f4a3c2b1a",
        CellChangeTimes -> { 3.9*^9, 3.9*^9 },
        CellID -> 123456,
        GeneratedCell -> False,
        CellAutoOverwrite -> False,
        CellObject -> CellObject[ "5ec7a6f0-4a9d-4b62-8d0c-0d4f4a3c2b1a", "c4f7" ],
        ShowCellBracket -> False
    ],
    "<cell id='c1' style='Text' options='ShowCellBracket -> False'>\nx\n</cell>",
    SameTest -> MatchQ,
    TestID   -> "Tag-HiddenOptions"
]

VerificationTest[
    csTag @ Cell[ "x", "Text", TaggingRules -> <| "Data" -> StringRepeat[ "a", 200 ] |>, CellOpen -> False ],
    "<cell id='c1' style='Text' options='CellOpen -> False'>\nx\n</cell>",
    SameTest -> MatchQ,
    TestID   -> "Tag-LongOptionLeftOut"
]

VerificationTest[
    csTag @ Cell[ "x", CellLabel -> "it's <a> & b\nc", CellDingbat -> "\[FilledSmallSquare]" ],
    "<cell id='c1' CellLabel='it&apos;s &lt;a> &amp; b&#10;c' options='CellDingbat -> \"\\[FilledSmallSquare]\"'>\nx\n</cell>",
    SameTest -> MatchQ,
    TestID   -> "Tag-AttributeEscapes"
]

(* An option value is read back with its symbols in the right contexts: *)
VerificationTest[
    Module[ { tag, options },
        tag = Block[ { $Context = "CellSyntaxTest`", $ContextPath = { "CellSyntaxTest`", "System`" } },
            csTag @ Cell[ "x", "Text", TaggingRules -> { "f" -> CellSyntaxTest`f }, FontFamily -> "A<B>'s" ]
        ];
        options = StringReplace[
            First @ StringCases[ tag, "options='" ~~ value: Except[ "'" ].. ~~ "'" :> value ],
            { "&lt;" -> "<", "&apos;" -> "'", "&amp;" -> "&" }
        ];
        ToExpression[ "{" <> options <> "}" ]
    ],
    { TaggingRules -> { "f" -> CellSyntaxTest`f }, FontFamily -> "A<B>'s" },
    SameTest -> MatchQ,
    TestID   -> "Tag-OptionsReadBack"
]

(* Tags that can't be joined with commas, and a label that is not a string, are shown as options: *)
VerificationTest[
    {
        csTag @ Cell[ "x", "Text", CellTags -> "one" ],
        csTag @ Cell[ "x", "Text", CellTags -> { "a,b", "c" }, CellLabel -> None ]
    },
    {
        "<cell id='c1' style='Text' CellTags='one'>\nx\n</cell>",
        "<cell id='c1' style='Text' options='CellTags -> {\"a,b\", \"c\"}, CellLabel -> None'>\nx\n</cell>"
    },
    SameTest -> MatchQ,
    TestID   -> "Tag-TagsAndLabelAsOptions"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Ids*)
VerificationTest[
    csTag @ Notebook @ {
        Cell[ "a", "Section" ],
        Cell @ CellGroupData[ { Cell[ "b", "Text" ], Cell[ "c", "ChatInput" ] }, Open ],
        Cell[ "d", "Text" ]
    },
    StringJoin[
        "<cell id='c1' style='Section'>\na\n</cell>\n\n",
        "<cell id='c2' style='Text'>\nb\n</cell>\n\n",
        "<cell id='c3' style='ChatInput'>\nc\n</cell>\n\n",
        "<cell id='c4' style='Text'>\nd\n</cell>"
    ],
    SameTest -> MatchQ,
    TestID   -> "Tag-SequentialIDs"
]

(* A caller gives the ids with $cellIDFunction, which gets the cell with the CellObject it was read from: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$cellIDFunction = Replace[
                {
                    Cell[ __, CellObject -> CellObject[ uuid_String, ___ ], ___ ] :> "n" <> uuid,
                    _ :> Missing[ "NotFound" ]
                }
            ]
        },
        csTag @ Notebook @ { Cell[ "a", "Text", CellObject -> CellObject[ "7", "x" ] ], Cell[ "b", "Text" ] }
    ],
    "<cell id='n7' style='Text'>\na\n</cell>\n\n<cell style='Text'>\nb\n</cell>",
    SameTest -> MatchQ,
    TestID   -> "Tag-IDFunction"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Without Tags*)

(* The default of "PreserveBoxes" is a hook for callers, as the one of "IncludeXML" is: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$preserveCellBoxes = True },
        {
            CellToString[ Cell[ BoxData @ SuperscriptBox[ "b", "2" ], "Input" ], "IncludeXML" -> True ],
            CellToString[ Cell[ BoxData @ SuperscriptBox[ "b", "2" ], "Input" ], "IncludeXML" -> True, "PreserveBoxes" -> False ]
        }
    ],
    {
        "<cell id='c1' style='Input'>\n<RawBoxes>SuperscriptBox[\"b\", \"2\"]</RawBoxes>\n</cell>",
        "<cell id='c1' style='Input'>\nb^2\n</cell>"
    },
    SameTest -> MatchQ,
    TestID   -> "PreserveBoxes-Hook"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Bodies Without Decoration*)

(* What the tag says is not in the body, with lossy and with exact bodies: no heading marker, bullet, code fence or
   label, and nothing for a delimiter *)
VerificationTest[
    Map[
        Function[ cell, { csBody @ csTag @ cell, csExactBody @ cell } ],
        {
            Cell[ "Stuff", "Section" ],
            Cell[ "Top", "Title" ],
            Cell[ "First", "Item" ],
            Cell[ "Second", "Subitem" ],
            Cell[ BoxData @ RowBox @ { "1", "+", "1" }, "Input", CellLabel -> "In[1]:=" ],
            Cell[ BoxData[ "2" ], "Output", CellLabel -> "Out[1]=" ],
            Cell[ "", "Delimiter" ],
            Cell[ "", "PageBreak" ],
            Cell[ "x = 1  # comment", "Program" ],
            Cell[ "print(1)", "ExternalLanguage", CellEvaluationLanguage -> "Python" ],
            Cell[ "printed text", "Print" ],
            Cell[ BoxData[ "5" ], "Echo" ]
        }
    ],
    {
        { "Stuff", "<RawBoxes>\"Stuff\"</RawBoxes>" },
        { "Top", "<RawBoxes>\"Top\"</RawBoxes>" },
        { "First", "<RawBoxes>\"First\"</RawBoxes>" },
        { "Second", "<RawBoxes>\"Second\"</RawBoxes>" },
        { "1 + 1", "1 + 1" },
        { "2", "2" },
        { "", "" },
        { "", "" },
        { "x = 1  # comment", "x = 1  # comment" },
        { "print(1)", "print(1)" },
        { "printed text", "printed text" },
        { "5", "5" }
    },
    SameTest -> MatchQ,
    TestID   -> "Body-NoDecoration"
]

VerificationTest[
    csTag @ Notebook @ {
        Cell[ "Stuff", "Section" ],
        Cell[ BoxData @ RowBox @ { "1", "+", "1" }, "Input", CellLabel -> "In[1]:=" ],
        Cell[ "", "Delimiter" ]
    },
    StringJoin[
        "<cell id='c1' style='Section'>\nStuff\n</cell>\n\n",
        "<cell id='c2' style='Input' CellLabel='In[1]:='>\n1 + 1\n</cell>\n\n",
        "<cell id='c3' style='Delimiter'>\n\n</cell>"
    ],
    SameTest -> MatchQ,
    TestID   -> "Body-NoDecoration-Notebook"
]

(* A code block inside of a cell is content, so it keeps its fence: *)
VerificationTest[
    csBody @ csTag @ Cell[ TextData @ FormatMarkdown[ "Run this:\n```python\nprint(1)\n```" ], "ChatOutput" ],
    _String? (StringEndsQ[ "\n```Python\nprint(1)\n```" ]),
    SameTest -> MatchQ,
    TestID   -> "Body-InnerCodeBlockKeepsFence"
]

(* A lossy body is not escaped like an exact one, but a cell tag in its text is, so that no body holds one: *)
VerificationTest[
    csTag @ Cell[ "Write <cell id='c2'>\nx\n</cell> or <CELL>.", "ChatOutput" ],
    "<cell id='c1' style='ChatOutput'>\nWrite &lt;cell id='c2'>\nx\n&lt;/cell> or &lt;CELL>.\n</cell>",
    SameTest -> MatchQ,
    TestID   -> "Body-LossyCellTags"
]

(* Adjacent code cells are not merged, and blank lines in a body are kept: *)
VerificationTest[
    csExact @ Notebook @ { Cell[ "a\n\n\n```", "Program" ], Cell[ "```\nb", "Program" ] },
    "<cell id='c1' style='Program'>\na\n\n\n```\n</cell>\n\n<cell id='c2' style='Program'>\n```\nb\n</cell>",
    SameTest -> MatchQ,
    TestID   -> "Body-CellsNotMerged"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Exact Code*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tokens*)
VerificationTest[
    csCode @ RowBox @ { "s", "=", RowBox @ { "\"a\\nb\\t\\\"c\\\"\"", "<>", "\"\\\\d\"" } },
    "s = \"a\\nb\\t\\\"c\\\"\" <> \"\\\\d\"",
    SameTest -> MatchQ,
    TestID   -> "Code-StringEscapes"
]

VerificationTest[
    csCode @ RowBox @ { "{", RowBox @ { "22583.17958127243`", ",", "1.5`20.", ",", "16^^ff", ",", "2.*^-3", ",", "1.`*^10" }, "}" },
    "{22583.17958127243`, 1.5`20., 16^^ff, 2.*^-3, 1.`*^10}",
    SameTest -> MatchQ,
    TestID   -> "Code-NumberMarks"
]

(* A comment keeps its own spacing, also around operators: *)
VerificationTest[
    csCode @ RowBox @ {
        "x",
        "=",
        "1",
        ";",
        RowBox @ { "(*", " ", RowBox @ { RowBox @ { "a", "+", "b" }, ",", "  ", RowBox @ { "c", "->", "d" } }, " ", "*)" }
    },
    "x = 1;(* a+b,  c->d *)",
    SameTest -> MatchQ,
    TestID   -> "Code-Comment"
]

(* A comment has no escapes, so the text of a long name in it (which is not the character) can only be given as boxes: *)
VerificationTest[
    {
        csCode @ RowBox @ { "(*", " ", "\[Alpha]\[FormalX]", " ", "*)" },
        csCode @ RowBox @ { "(*", " ", "\\[FormalX]", " ", "*)" }
    },
    { "(* \[Alpha]\\[FormalX] *)", "<RawBoxes>RowBox[{\"(*\", \" \", \"\\\\[FormalX]\", \" \", \"*)\"}]</RawBoxes>" },
    SameTest -> MatchQ,
    TestID   -> "Code-CommentLongNames"
]

(* Unparsed code is one token: *)
VerificationTest[
    csCode[ "f[x_]:=x^2+1" ],
    "f[x_]:=x^2+1",
    SameTest -> MatchQ,
    TestID   -> "Code-UnparsedString"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Spacing*)

(* The list that the writer uses to take the spaces out again is the list of operators that get them: *)
VerificationTest[
    Select[
        List @@ Wolfram`Chatbook`Serialization`Private`$$spacedInfixOperator,
        Function[ op, ! StringMatchQ[ csCode @ RowBox @ { "a", op, "b" }, "a " ~~ Except[ " " ].. ~~ " b" ] ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Code-SpacedOperators"
]

VerificationTest[
    csCode @ RowBox @ { "f", "[", RowBox @ { "a", ",", RowBox @ { "b", "//", "g" }, ",", RowBox @ { "h", "@", "c" }, ",", RowBox @ { "d", ";", "e" }, ",", RowBox @ { "2", " ", "x" } }, "]" },
    "f[a, b//g, h@c, d;e, 2 x]",
    SameTest -> MatchQ,
    TestID   -> "Code-OtherOperatorsNotSpaced"
]

(* The cell's own spaces are left out where a space is written anyway, in whatever RowBox they are, and kept elsewhere: *)
VerificationTest[
    csCode @ RowBox @ { "a", " ", "+", " ", "b", ",", RowBox @ { " ", "c" }, " ", ";", " ", "d", "  ", "e" },
    "a + b, c ; d  e",
    SameTest -> MatchQ,
    TestID   -> "Code-OwnSpacesNextToOperators"
]

VerificationTest[
    csCode @ RowBox @ { RowBox @ { "-", "x" }, "+", RowBox @ { "a", "-", RowBox @ { "-", "b" } }, "-", RowBox @ { "++", "i" } },
    "-x + a - -b - ++i",
    SameTest -> MatchQ,
    TestID   -> "Code-PrefixOperators"
]

(* No space is written at the start or the end of a line: *)
VerificationTest[
    csCode @ RowBox @ { "?", "a", "\n", RowBox @ { "b", "+" }, "\n", RowBox @ { "+", "c", "," }, "\n", "d", "=" },
    "? a\nb +\n+ c,\nd =",
    SameTest -> MatchQ,
    TestID   -> "Code-NoSpaceAtLineEnds"
]

(* Two tokens that would read as one where they meet have a space between them. A number before a name reads as two,
   and so do an operator and a name: *)
VerificationTest[
    {
        csCode @ RowBox @ { "Boole", "[", RowBox @ { RowBox @ { "a", "x" }, "<", "y" }, "]" },
        csCode @ RowBox @ {
            RowBox @ { "#", "Log" }, "+", RowBox @ { "2", "x" }, "+", RowBox @ { "x", "2" }, "+", RowBox @ { "1", ".", "5" }, "+",
            RowBox @ { "x", "\[FormalX]" }, "+", RowBox @ { RowBox @ { "f", "[", "x", "]" }, RowBox @ { "\[DifferentialD]", "x" } }
        }
    },
    { "Boole[a x < y]", "# Log + 2x + x 2 + 1 . 5 + x \\[FormalX] + f[x]\\[DifferentialD]x" },
    SameTest -> MatchQ,
    TestID   -> "Code-TokensKeptApart"
]

(* In a Code cell the front end adds no spacing, so its spaces are content: the code is written with its tokens and
   spaces exactly as they are. So is code that has a space of its own where one would be written. A comment does
   not count, and tokens that would join are still kept apart: *)
VerificationTest[
    {
        csExactBody @ Cell[ BoxData @ RowBox @ { "a", "=", RowBox @ { "f", "[", RowBox @ { "1", ",", "2" }, "]" } }, "Code" ],
        csExactBody @ Cell[ BoxData @ RowBox @ { "a", "=", RowBox @ { "f", "[", RowBox @ { "1", ",", "2" }, "]" } }, "Input" ],
        csExactBody @ Cell[ BoxData @ RowBox @ { "a", " ", "=", " ", RowBox @ { "f", "[", RowBox @ { "1", ",", "2" }, "]" } }, "Input" ],
        csExactBody @ Cell[ BoxData @ RowBox @ { RowBox @ { "(*", " ", "a", " ", "=", " ", "b", " ", "*)" }, RowBox @ { "x", "=", "1" } }, "Input" ],
        csExactBody @ Cell[ BoxData @ RowBox @ { "a", "-", RowBox @ { "-", "b" }, "+", RowBox @ { "x", "y" } }, "Code" ]
    },
    { "a=f[1,2]", "a = f[1, 2]", "a = f[1,2]", "(* a = b *)x = 1", "a- -b+x y" },
    SameTest -> MatchQ,
    TestID   -> "Code-OwnSpacing"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Line Breaks*)

(* After a \[IndentingNewLine] the line is indented by the open brackets, less one that it closes: *)
VerificationTest[
    csCode @ RowBox @ {
        "f",
        "[",
        "\[IndentingNewLine]",
        RowBox @ {
            RowBox @ { "{", "\[IndentingNewLine]", RowBox @ { "a", ",", "\[IndentingNewLine]", "b" }, "\[IndentingNewLine]", "}" },
            ",",
            "\[IndentingNewLine]",
            RowBox @ { "m", "\[LeftDoubleBracket]", "\[IndentingNewLine]", "1", "\[IndentingNewLine]", "\[RightDoubleBracket]" }
        },
        "\[IndentingNewLine]",
        "]",
        "\[IndentingNewLine]",
        "g"
    },
    "f[\n    {\n        a,\n        b\n    },\n    m[[\n            1\n    ]]\n]\ng",
    SameTest -> MatchQ,
    TestID   -> "Code-IndentingNewLine"
]

(* After a "\n" the spaces are the ones of the cell: *)
VerificationTest[
    csCode @ RowBox @ { "f", "[", "\n", "  ", RowBox @ { "x", ",", "\n", "\t", "y" }, "\n", "]" },
    "f[\n  x,\n\ty\n]",
    SameTest -> MatchQ,
    TestID   -> "Code-NewlineKeepsSpaces"
]

VerificationTest[
    csExactBody @ Cell[ BoxData @ { RowBox @ { "a", "=", "1" }, "\n", RowBox @ { "b", "=", "2" } }, "Input" ],
    "a = 1\nb = 2",
    SameTest -> MatchQ,
    TestID   -> "Code-BoxDataList"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Characters*)
VerificationTest[
    csCode @ RowBox @ {
        "a", "\[Rule]", "b", "\[RuleDelayed]", "c", "\[Equal]", "d", "\[NotEqual]", "e", "\[LessEqual]", "f",
        "\[GreaterEqual]", "g", "\[Function]", "h", "\[TwoWayRule]",
        RowBox @ { "\[LeftAssociation]", RowBox @ { "k", "\[LeftDoubleBracket]", "1", "\[RightDoubleBracket]" }, "\[RightAssociation]" }
    },
    "a -> b :> c == d != e <= f >= g |-> h <-> <|k[[1]]|>",
    SameTest -> MatchQ,
    TestID   -> "Code-OperatorCharacters"
]

(* Only whole tokens are operators. In a string or a comment the character is written as its long name: *)
VerificationTest[
    csCode @ RowBox @ { "\"a\[Rule]b\"", "\[Rule]", RowBox @ { "(*", " ", "\[Rule]", " ", "*)" } },
    "\"a\\[Rule]b\" -> (* \\[Rule] *)",
    SameTest -> MatchQ,
    TestID   -> "Code-OperatorCharactersInStrings"
]

(* Private use characters are long names, or \:xxxx without a name. Other characters are written as they are: *)
VerificationTest[
    csCode @ RowBox @ { "\[ImaginaryI]", "+", "\[FormalX]", "+", "\[Alpha]", "+", FromCharacterCode[ 16^^E123 ], "+", "x\[DirectedEdge]y" },
    "\\[ImaginaryI] + \\[FormalX] + \[Alpha] + \\:e123 + x\\[DirectedEdge]y",
    SameTest -> MatchQ,
    TestID   -> "Code-PrivateUseCharacters"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Raw Boxes*)

(* Only the box that code can't say is in <RawBoxes>, whole and on one line: *)
VerificationTest[
    csCode @ RowBox @ {
        "Solve",
        "[",
        RowBox @ {
            RowBox @ { RowBox @ { SuperscriptBox[ "x", RowBox @ { "n", "+", "1" } ], "+", FractionBox[ "\[Alpha]", "2" ] }, "\[Equal]", "0" },
            ",",
            "x"
        },
        "]"
    },
    StringJoin[
        "Solve[<RawBoxes>SuperscriptBox[\"x\", RowBox[{\"n\", \"+\", \"1\"}]]</RawBoxes> + ",
        "<RawBoxes>FractionBox[\"\\[Alpha]\", \"2\"]</RawBoxes> == 0, x]"
    ],
    SameTest -> MatchQ,
    TestID   -> "Code-MinimalRawBoxes"
]

(* The text in <RawBoxes> gives the box back, with symbols of other contexts: *)
VerificationTest[
    With[
        {
            box = TagBox[
                GridBox[ { { "a\nb", "\"q\"" }, { "\[Rule]", "1.5`" } }, GridBoxAlignment -> { "Columns" -> { { Left } } } ],
                Function[ BoxForm`e$, TableForm[ BoxForm`e$ ] ]
            ]
        },
        Replace[
            StringCases[ csCode @ box, StartOfString ~~ "<RawBoxes>" ~~ text__ ~~ "</RawBoxes>" ~~ EndOfString :> text ],
            { text_ } :> StringFreeQ[ text, "\n" ] && PrintableASCIIQ @ text && ToExpression @ text === box
        ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Code-RawBoxesReadBack"
]

(* Text that holds a tag or a URI of the syntax is in <RawBoxes>, written so that it does not read as one: *)
VerificationTest[
    Map[
        Function[ token,
            Replace[
                StringCases[ csCode @ RowBox @ { "f", "[", token, "]" }, "f[<RawBoxes>" ~~ text__ ~~ "</RawBoxes>]" :> text ],
                {
                    { text_ } :> And[
                        StringFreeQ[ text, "</" | "<cell" | "<RawBoxes" | "<selection" | "://content", IgnoreCase -> True ],
                        ToExpression @ text === token
                    ],
                    _ :> False
                }
            ]
        ],
        {
            "\"</cell>\"",
            "\"a <RawBoxes>x</RawBoxes>\"",
            "\"<selection>\"",
            "\"<CELL id='c1'>\"",
            "\"![Image](attachment://content-abcde)\""
        }
    ],
    { True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Code-TagsInTokens"
]

VerificationTest[
    csCode @ RowBox @ { "a", "<", "cell", ">", "b", ";", RowBox @ { "(*", " ", RowBox @ { "<", "cell", ">" }, " ", "*)" } },
    "a < cell > b;<RawBoxes>RowBox[{\"(*\", \" \", RowBox[{\"<\", \"cell\", \">\"}], \" \", \"*)\"}]</RawBoxes>",
    SameTest -> MatchQ,
    TestID   -> "Code-TagsAcrossTokens"
]

(* Tokens that make a cell tag where they meet can't be written as code: *)
VerificationTest[
    csCode @ RowBox @ { RowBox @ { "<<", "cell`" }, ";", "x" },
    "<RawBoxes>RowBox[{RowBox[{\"<<\", \"cell`\"}], \";\", \"x\"}]</RawBoxes>",
    SameTest -> MatchQ,
    TestID   -> "Code-CellTagWhereTokensMeet"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Other Content*)

(* A string in a code cell is the string as it is, without markdown escapes or long names: *)
VerificationTest[
    {
        csExactBody @ Cell[ "Plot[x_*2, {x, 0, 1}] (* `a` $b \[FormalX] *)", "Input" ],
        csExactBody @ Cell[ "def f(a_b):\n    return a_b * 2  # [x](y)\n", "Program" ],
        csExactBody @ Cell[ "x</cell>", "Code" ]
    },
    {
        "Plot[x_*2, {x, 0, 1}] (* `a` $b \[FormalX] *)",
        "def f(a_b):\n    return a_b * 2  # [x](y)\n",
        "<RawBoxes>\"x\\.3c/cell>\"</RawBoxes>"
    },
    SameTest -> MatchQ,
    TestID   -> "Body-PlainStrings"
]

VerificationTest[
    csExactBody @ Cell[ RawData[ "Cell[\"x\", \"Text\"]" ], "Text" ],
    "<RawBoxes>RawData[\"Cell[\\\"x\\\", \\\"Text\\\"]\"]</RawBoxes>",
    SameTest -> MatchQ,
    TestID   -> "Body-OtherContent"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Truncated*)

VerificationTest[
    {
        StringStartsQ[
            csTag @ Cell[ BoxData @ RowBox @ Riffle[ ToString /@ Range[ 400 ], "," ], "Output" ],
            "<cell id='c1' style='Output' truncated='true'>\n1, 2, 3"
        ],
        StringStartsQ[
            csTag @ Cell[ BoxData @ RowBox @ Riffle[ ToString /@ Range[ 40 ], "," ], "Output" ],
            "<cell id='c1' style='Output'>\n1, 2, 3"
        ]
    },
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "Truncated-LossyBody"
]

(* :!CodeAnalysis::EndBlock:: *)
