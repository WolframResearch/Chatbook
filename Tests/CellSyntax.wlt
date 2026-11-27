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
        csTag, csExact, csBody, csExactBody, csCode, csText, csStores, csKey, csFormula
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
    csText[ items_ ] := csExactBody @ Cell[ TextData @ items, "Text" ];

    (* Evaluates with empty stores *)
    csStores // Attributes = { HoldFirst };
    csStores[ eval_ ] := Block[
        {
            Wolfram`Chatbook`Common`$attachments         = <| |>,
            Wolfram`Chatbook`Common`$notebookAttachments = <| |>,
            Wolfram`Chatbook`Common`$cellOriginals       = <| |>
        },
        eval
    ];

    (* The key of the URI in a body *)
    csKey[ body_String ] := First[ StringCases[ body, "://" ~~ key: ("content-" ~~ WordCharacter..) ~~ ")" :> key ], None ];

    (* An inline formula of the TeX input assistant that was typed as this input *)
    csFormula[ input_String ] := Cell @ BoxData @ FormBox[
        TemplateBox[
            <| "boxes" -> FormBox[ StyleBox[ "x", "TI" ], TraditionalForm ], "errors" -> { }, "input" -> input, "state" -> "Boxes" |>,
            "TeXAssistantTemplate"
        ],
        TraditionalForm
    ];

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

(* Without cell tags, "PreserveBoxes" gives exact bodies with the decoration of the default markdown around them: *)
VerificationTest[
    CellToString[
        Notebook @ {
            Cell[ "Stuff", "Section" ],
            Cell[ TextData @ { "An ", StyleBox[ "x", FontColor -> RGBColor[ 1, 0, 0 ] ] }, "Item" ],
            Cell[ BoxData @ RowBox @ { "a", "+", SuperscriptBox[ "b", "2" ] }, "Input", CellLabel -> "In[1]:=" ],
            Cell[ BoxData @ FormBox[ RowBox @ { "a", "=", "b" }, TraditionalForm ], "DisplayFormula" ],
            Cell[ "", "Delimiter" ]
        },
        "PreserveBoxes" -> True
    ],
    StringJoin[
        "## Stuff\n\n",
        "* An <RawBoxes>StyleBox[\"x\", FontColor -> RGBColor[1, 0, 0]]</RawBoxes>\n\n",
        "```wl\nIn[1]:= a + <RawBoxes>SuperscriptBox[\"b\", \"2\"]</RawBoxes>\n```\n\n",
        "$$a=b$$\n\n",
        "---"
    ],
    SameTest -> MatchQ,
    TestID   -> "PreserveBoxes-WithoutTags"
]

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
        { "Stuff", "Stuff" },
        { "Top", "Top" },
        { "First", "First" },
        { "Second", "Second" },
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
(*Exact Text*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Plain Text*)
VerificationTest[
    csExactBody @ Cell[ "a*b `c` $d | e\\f [x](y) [1] f[x] snake_case _x_ ~~q~~ ~5 # h", "Text" ],
    "a\\*b \\`c\\` \\$d \\| e\\\\f [x\\](y) [1] f[x] snake_case \\_x\\_ \\~\\~q\\~\\~ ~5 # h",
    SameTest -> MatchQ,
    TestID   -> "Text-MarkdownEscapes"
]

VerificationTest[
    csExactBody @ Cell[ "<cell> </cell> <RawBoxes> <ToBoxes form='x'> <selection> <!attachment://content-abcde!> a<b &lt; &amp; &#65; &#x41; R&D; a & b", "Text" ],
    "&lt;cell> &lt;/cell> &lt;RawBoxes> &lt;ToBoxes form='x'> &lt;selection> &lt;!attachment://content-abcde!> a<b &amp;lt; &amp;amp; &amp;#65; &amp;#x41; R&amp;D; a & b",
    SameTest -> MatchQ,
    TestID   -> "Text-TagAndEntityEscapes"
]

VerificationTest[
    csText @ { "a \[FormalX] ", "\[Alpha]", " \[Rule] b" },
    "a \\[FormalX] \[Alpha] \\[Rule] b",
    SameTest -> MatchQ,
    TestID   -> "Text-PrivateUseCharacters"
]

(* A character that is not in the private use area is written as itself, whatever its name is: a typographic
   apostrophe (U+2019), a dash and typographic quotes stay those characters, in text and in code. *)
VerificationTest[
    With[ { text = FromCharacterCode @ { 105, 116, 8217, 115, 32, 8211, 32, 8220, 120, 8221 } },
        {
            csExactBody @ Cell[ text, "Text" ] === text,
            csCode @ RowBox @ { "f", "[", "\"" <> text <> "\"", "]" } === "f[\"" <> text <> "\"]"
        }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "Text-OtherCharactersAsTheyAre"
]

(* Adjacent strings are one text, so what they make together is escaped: *)
VerificationTest[
    csText @ { "[x]", "(y) ~", "~z" },
    "[x\\](y) \\~\\~z",
    SameTest -> MatchQ,
    TestID   -> "Text-AdjacentStrings"
]

(* Linear syntax and control characters can't be in the text, so that part of the string is in <RawBoxes>: *)
VerificationTest[
    csText @ { "ab \!\(\*SuperscriptBox[x, 2]\) cd" <> FromCharacterCode[ 7 ] <> " ef" },
    "ab <RawBoxes>\"\\!\\(\\*SuperscriptBox[x, 2]\\) cd\\007\"</RawBoxes> ef",
    SameTest -> MatchQ,
    TestID   -> "Text-RawCharacters"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Styles*)
VerificationTest[
    csText @ {
        StyleBox[ "bold", FontWeight -> "Bold" ],
        " ",
        StyleBox[ "italic", FontSlant -> Italic ],
        " ",
        StyleBox[ "both", FontWeight -> Bold, FontSlant -> "Italic" ],
        " ",
        StyleBox[ "struck", FontVariations -> { "StrikeThrough" -> True } ],
        " ",
        StyleBox[ "all*", StripOnInput -> False, FontVariations -> { "StrikeThrough" -> True }, FontSlant -> Italic, FontWeight -> Bold ]
    },
    "**bold** *italic* ***both*** ~~struck~~ ~~***all\\****~~",
    SameTest -> MatchQ,
    TestID   -> "Text-Styles"
]

(* A style that markdown can't say is in <RawBoxes>, whole: *)
VerificationTest[
    csText @ {
        StyleBox[ "red", FontColor -> RGBColor[ 1, 0, 0 ] ],
        StyleBox[ "big", FontWeight -> "Bold", FontSize -> 20 ],
        StyleBox[ "two\nlines", FontWeight -> "Bold" ],
        StyleBox[ "a~b", FontVariations -> { "StrikeThrough" -> True } ],
        StyleBox[ RowBox @ { "x", "y" }, FontSlant -> "Italic" ]
    },
    StringJoin[
        "<RawBoxes>StyleBox[\"red\", FontColor -> RGBColor[1, 0, 0]]</RawBoxes>",
        "<RawBoxes>StyleBox[\"big\", FontWeight -> \"Bold\", FontSize -> 20]</RawBoxes>",
        "<RawBoxes>StyleBox[\"two\\nlines\", FontWeight -> \"Bold\"]</RawBoxes>",
        "<RawBoxes>StyleBox[\"a~b\", FontVariations -> {\"StrikeThrough\" -> True}]</RawBoxes>",
        "<RawBoxes>StyleBox[RowBox[{\"x\", \"y\"}], FontSlant -> \"Italic\"]</RawBoxes>"
    ],
    SameTest -> MatchQ,
    TestID   -> "Text-StylesAsRawBoxes"
]

(* Emphasis opens before and closes after a character that is not white space, so text with a space at an end is not
   written with markers: *)
VerificationTest[
    csText @ { StyleBox[ "Note: ", FontWeight -> "Bold" ], StyleBox[ " x", FontSlant -> "Italic" ], StyleBox[ "a b", FontWeight -> "Bold" ] },
    StringJoin[
        "<RawBoxes>StyleBox[\"Note: \", FontWeight -> \"Bold\"]</RawBoxes>",
        "<RawBoxes>StyleBox[\" x\", FontSlant -> \"Italic\"]</RawBoxes>",
        "**a b**"
    ],
    SameTest -> MatchQ,
    TestID   -> "Text-EmphasisWithSpacesAtItsEnds"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Links*)
VerificationTest[
    csText @ {
        ButtonBox[ "Wolfram", BaseStyle -> "Hyperlink", ButtonData -> { URL[ "https://www.wolfram.com" ], None }, ButtonNote -> "https://www.wolfram.com" ],
        " ",
        ButtonBox[ "Plot", BaseStyle -> "Link", ButtonData -> "paclet:ref/Plot" ],
        " ",
        Cell @ BoxData @ TemplateBox[ { "site", "https://example.com/a" }, "HyperlinkURL" ],
        " ",
        TemplateBox[ { "site", { URL[ "https://example.com/b" ], None }, "https://example.com/b", "HyperlinkActionRecycled", { "HyperlinkActive" }, BaseStyle -> { "Hyperlink" } }, "HyperlinkTemplate" ],
        " ",
        Cell[ BoxData @ TemplateBox[ { Cell @ TextData @ "Table", "paclet:ref/Table" }, "RefLink", BaseStyle -> { "InlineFormula" } ], "InlineFormula" ],
        " ",
        Cell @ BoxData @ TemplateBox[ { "Sin", "paclet:ref/Sin", "https://reference.wolfram.com/language/ref/Sin.html" }, "TextRefLink" ]
    },
    StringJoin[
        "[Wolfram](https://www.wolfram.com) [Plot](paclet:ref/Plot) [site](https://example.com/a) ",
        "[site](https://example.com/b) [Table](paclet:ref/Table) [Sin](paclet:ref/Sin)"
    ],
    SameTest -> MatchQ,
    TestID   -> "Text-Links"
]

(* A link whose label would not read back as one label is in <RawBoxes>. A backslash in a label escapes the character
   after it, so a label can't end with one: *)
VerificationTest[
    csText @ {
        ButtonBox[ "a]b", BaseStyle -> "Hyperlink", ButtonData -> { URL[ "https://example.com" ], None } ],
        ButtonBox[ "a\\", BaseStyle -> "Link", ButtonData -> "paclet:ref/Plot" ],
        ButtonBox[ "a_b", BaseStyle -> "Link", ButtonData -> "paclet:ref/Plot" ]
    },
    StringJoin[
        "<RawBoxes>ButtonBox[\"a]b\", BaseStyle -> \"Hyperlink\", ButtonData -> {URL[\"https://example.com\"], None}]</RawBoxes>",
        "<RawBoxes>ButtonBox[\"a\\\\\", BaseStyle -> \"Link\", ButtonData -> \"paclet:ref/Plot\"]</RawBoxes>",
        "[a_b](paclet:ref/Plot)"
    ],
    SameTest -> MatchQ,
    TestID   -> "Text-LinkAsRawBoxes"
]

(* The label of a link keeps the spaces at its ends: *)
VerificationTest[
    csText @ { "Read the", ButtonBox[ " research ", BaseStyle -> "Hyperlink", ButtonData -> { URL[ "https://example.com" ], None } ], "on this." },
    "Read the[ research ](https://example.com)on this.",
    SameTest -> MatchQ,
    TestID   -> "Text-LinkLabelSpaces"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Inline Code*)
VerificationTest[
    csText @ {
        Cell[ BoxData @ TemplateBox[ { Cell[ "foo[x]", Background -> None ] }, "ChatCodeInlineTemplate" ], "ChatCodeActive" ],
        " ",
        StyleBox[ "x", "TI" ],
        " ",
        Cell[ BoxData @ RowBox @ { "Plot", "[", RowBox @ { "x", ",", RowBox @ { "y", "\[Rule]", "1" } }, "]" }, "InlineFormula" ],
        " ",
        Cell[ "Global`x", "InlineCode" ]
    },
    "``foo[x]`` ``x`` ``Plot[x, y -> 1]`` ``Global`x``",
    SameTest -> MatchQ,
    TestID   -> "Text-InlineCode"
]

(* Inline code that is more than code, or that the backticks can't hold, is in <RawBoxes>: *)
VerificationTest[
    csText @ { Cell[ BoxData @ SuperscriptBox[ "x", "2" ], "InlineFormula" ], StyleBox[ "a``b", "InlineCode" ] },
    StringJoin[
        "<RawBoxes>Cell[BoxData[SuperscriptBox[\"x\", \"2\"]], \"InlineFormula\"]</RawBoxes>",
        "<RawBoxes>StyleBox[\"a``b\", \"InlineCode\"]</RawBoxes>"
    ],
    SameTest -> MatchQ,
    TestID   -> "Text-InlineCodeAsRawBoxes"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Math*)

(* A formula that was made from LaTeX is written as that LaTeX: *)
VerificationTest[
    csText @ {
        "so ",
        Cell @ BoxData @ FormBox[
            TemplateBox[
                <| "boxes" -> FormBox[ "x", TraditionalForm ], "errors" -> { }, "input" -> "\\lim_{x \\to 2} f(x) = 5", "state" -> "Boxes" |>,
                "TeXAssistantTemplate"
            ],
            TraditionalForm
        ],
        "."
    },
    "so $$\\lim_{x \\to 2} f(x) = 5$$.",
    SameTest -> MatchQ,
    TestID   -> "Text-MathFromTeX"
]

(* Another TraditionalForm formula is converted if it is only layout. This also has to work without a front end, where
   exporting to "TeXFragment" gives an empty formula: *)
VerificationTest[
    csText @ {
        Cell[
            BoxData @ FormBox[ RowBox @ { SuperscriptBox[ "x", "2" ], "+", FractionBox[ "1", "2" ] }, TraditionalForm ],
            FormatType -> TraditionalForm
        ]
    },
    "$$x^2+\\frac{1}{2}$$",
    SameTest -> MatchQ,
    TestID   -> "Text-MathFromBoxes"
]

VerificationTest[
    csText @ {
        Cell @ BoxData @ FormBox[ TagBox[ "x", HoldForm ], TraditionalForm ],
        Cell[ BoxData @ FormBox[ "y", TraditionalForm ], "InlineFormula" ]
    },
    StringJoin[
        "<RawBoxes>Cell[BoxData[FormBox[TagBox[\"x\", HoldForm], TraditionalForm]]]</RawBoxes>",
        "<RawBoxes>Cell[BoxData[FormBox[\"y\", TraditionalForm]], \"InlineFormula\"]</RawBoxes>"
    ],
    SameTest -> MatchQ,
    TestID   -> "Text-MathAsRawBoxes"
]

(* The input of the TeX input assistant can be in dollars of its own, which are not written: *)
VerificationTest[
    csText @ { "from 1 to ", csFormula[ "$n$" ], " or ", csFormula[ "$$x<y$$" ], " or ", csFormula[ "$ {n\\choose 9} $" ] },
    "from 1 to $$n$$ or $$x<y$$ or $$ {n\\choose 9} $$",
    SameTest -> MatchQ,
    TestID   -> "Text-MathWithDollarSigns"
]

(* LaTeX that would make a "$$" with the dollar signs around it can't be written between them: input with a dollar at
   one end only, and input that is more than one formula: *)
VerificationTest[
    csText @ { csFormula[ "$x" ], csFormula[ "x$" ], csFormula[ "$a$ and $b$" ] },
    _String? (StringCount[ #, "<RawBoxes>Cell[BoxData[FormBox[TemplateBox[<|\"boxes\" -> " ] === 3 && StringFreeQ[ #, "$$" ] &),
    SameTest -> MatchQ,
    TestID   -> "Text-MathWithOtherDollarSigns"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Boxes in Cells of Text*)

(* A cell of text whose content is boxes (a formula, a table) has the body that the boxes would have as an inline cell
   in text, and is written from it: *)
VerificationTest[
    {
        csExactBody @ Cell[ BoxData @ FormBox[ RowBox @ { "a", "=", "b" }, TraditionalForm ], "DisplayFormula" ],
        csExactBody @ Cell[ BoxData @ GridBox @ { { SqrtBox[ "1" ], "2" } }, "Text" ],
        csExactBody @ Cell[ BoxData @ RowBox @ { "a", "+", "b" }, "Program" ]
    },
    { "$$a=b$$", "<RawBoxes>Cell[BoxData[GridBox[{{SqrtBox[\"1\"], \"2\"}}]]]</RawBoxes>", "a + b" },
    SameTest -> MatchQ,
    TestID   -> "Body-BoxesInCellsOfText"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Grids of Text*)

(* In a cell of text, a grid whose entries are all plain text is a markdown table, also in the wrappers that TableForm,
   Grid and Column put around it: with the headings that it has, and with an empty header row otherwise. *)
VerificationTest[
    With[
        {
            table = TagBox[
                TagBox[
                    GridBox[
                        { { TagBox[ "First", HoldForm ], TagBox[ "Second", HoldForm ], TagBox[ "Third", HoldForm ] }, { "a", "b", "c" }, { "d", "e", "f" } },
                        GridBoxAlignment -> { "Columns" -> { { Left } }, "Rows" -> { { Baseline } } },
                        GridBoxDividers -> { "Columns" -> { { False } }, "Rows" -> { False, True, { False }, False } }
                    ],
                    { None, OutputFormsDump`HeadedColumns }
                ],
                Function[ BoxForm`e$, TableForm[ BoxForm`e$, TableHeadings -> { None, { "First", "Second", "Third" } } ] ]
            ]
        },
        {
            csExactBody @ Cell[ BoxData @ table, "Text" ],
            csExactBody @ Cell[ BoxData @ TagBox[ GridBox[ { { "\"a\"", "\"b\"" }, { "\"c\"", "\"d\"" } }, AutoDelete -> False ], "Grid" ], "Text" ],
            csExactBody @ Cell[ BoxData @ TagBox[ GridBox[ { { "\"a\"" }, { "\"b\"" } }, DefaultBaseStyle -> "Column" ], "Column" ], "Text" ],
            csExactBody @ Cell[ BoxData @ GridBox @ { { "1", "2" } }, "Text" ]
        }
    ],
    {
        "| First | Second | Third |\n| :---- | :----- | :---- |\n| a     | b      | c     |\n| d     | e      | f     |",
        "|   |   |\n| - | - |\n| a | b |\n| c | d |",
        "|   |\n| - |\n| a |\n| b |",
        "|   |   |\n| - | - |\n| 1 | 2 |"
    },
    SameTest -> MatchQ,
    TestID   -> "Body-GridOfText"
]

(* A grid stays boxes if an entry is not plain text on one line, if it has no text at all (the default markdown has no
   table for it), and in code, where it is a matrix: *)
VerificationTest[
    {
        csExactBody @ Cell[ BoxData @ GridBox @ { { "1", RowBox @ { "-", "2" } } }, "Text" ],
        csExactBody @ Cell[ BoxData @ GridBox @ { { "a\nb", "c" } }, "Text" ],
        csExactBody @ Cell[ BoxData @ GridBox @ { { "", "" }, { "", "" } }, "Text" ],
        csCode @ RowBox @ { "m", "=", GridBox @ { { "1", "2" }, { "3", "4" } } },
        csCode @ GridBox @ { { "1", "2" }, { "3", "4" } }
    },
    {
        "<RawBoxes>Cell[BoxData[GridBox[{{\"1\", RowBox[{\"-\", \"2\"}]}}]]]</RawBoxes>",
        "<RawBoxes>Cell[BoxData[GridBox[{{\"a\\nb\", \"c\"}}]]]</RawBoxes>",
        "<RawBoxes>Cell[BoxData[GridBox[{{\"\", \"\"}, {\"\", \"\"}}]]]</RawBoxes>",
        "m = <RawBoxes>GridBox[{{\"1\", \"2\"}, {\"3\", \"4\"}}]</RawBoxes>",
        "<RawBoxes>GridBox[{{\"1\", \"2\"}, {\"3\", \"4\"}}]</RawBoxes>"
    },
    SameTest -> MatchQ,
    TestID   -> "Body-GridAsRawBoxes"
]

(* An inline cell with such a grid is a table if it is on lines of its own. Anywhere else the text after it would read
   as part of its last row, so it is boxes there. This also holds for the table that the chat formatter makes. *)
VerificationTest[
    With[ { grid = Cell @ BoxData @ TagBox[ GridBox @ { { "\"a\"", "\"b\"" }, { "\"c\"", "\"d\"" } }, "Grid" ] },
        {
            csText @ { "A table:\n", grid, "\nand text." },
            csText @ { grid },
            csText @ { "A table ", grid, "\nand text." },
            csText @ { "A table:\n", grid, " and text." },
            StringCount[ csText @ Append[ FormatMarkdown[ "Before\n\n| Name | Value |\n| --- | --- |\n| a | 1 |" ], " and text." ], "<RawBoxes>Cell[BoxData[" ]
        }
    ],
    {
        "A table:\n|   |   |\n| - | - |\n| a | b |\n| c | d |\nand text.",
        "|   |   |\n| - | - |\n| a | b |\n| c | d |",
        _String? (StringStartsQ[ "A table <RawBoxes>Cell[BoxData[TagBox[GridBox[" ]),
        _String? (StringMatchQ[ "A table:\n<RawBoxes>Cell[BoxData[TagBox[GridBox[" ~~ __ ~~ "</RawBoxes> and text." ]),
        1
    },
    SameTest -> MatchQ,
    TestID   -> "Text-GridOfText"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Raw Boxes*)
VerificationTest[
    csText @ { "a ", Cell[ BoxData @ RowBox @ { "x", "+", "y" }, "Output", FontSize -> 10 ], " b ", Cell[ "c", "MyStyle" ] },
    StringJoin[
        "a <RawBoxes>Cell[BoxData[RowBox[{\"x\", \"+\", \"y\"}]], \"Output\", FontSize -> 10]</RawBoxes>",
        " b <RawBoxes>Cell[\"c\", \"MyStyle\"]</RawBoxes>"
    ],
    SameTest -> MatchQ,
    TestID   -> "Text-RawBoxes"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Originals*)

(* Reading records what each piece of a body stands for, for the writer (see "Writing Text" and "Writing Code" for
   what it does with the records). Nothing is recorded unless the caller asks for it, and nothing for a cell without
   an id: *)
VerificationTest[
    {
        csText @ { StyleBox[ "x", FontWeight -> "Bold" ], StyleBox[ "red", FontColor -> RGBColor[ 1, 0, 0 ] ] },
        Wolfram`Chatbook`Common`$cellOriginals,
        csStores @ Block[ { Wolfram`Chatbook`Common`$cellIDFunction = None & },
            { csExact @ Cell[ TextData @ { StyleBox[ "x", FontWeight -> "Bold" ] }, "Text" ], Wolfram`Chatbook`Common`$cellOriginals }
        ]
    },
    {
        "**x**<RawBoxes>StyleBox[\"red\", FontColor -> RGBColor[1, 0, 0]]</RawBoxes>",
        None,
        { "<cell style='Text'>\n**x**\n</cell>", <| |> }
    },
    SameTest -> MatchQ,
    TestID   -> "Originals-NoneByDefault"
]

(* The ExpressionUUID of an inline cell is left out, so that inline cells that read the same are the same piece: *)
VerificationTest[
    csText @ {
        Cell[ BoxData @ RowBox @ { "f", "[", "x", "]" }, "InlineFormula", ExpressionUUID -> "5ec7a6f0-4a9d-4b62-8d0c-0d4f4a3c2b1a" ],
        Cell[ BoxData @ RowBox @ { "f", "[", "x", "]" }, "InlineFormula", ExpressionUUID -> "0d4f4a3c-4a9d-4b62-8d0c-5ec7a6f02b1a" ],
        Cell[ BoxData @ SqrtBox[ "x" ], "InlineFormula", ExpressionUUID -> "8d0c0d4f-4a9d-4b62-8d0c-0d4f4a3c2b1a" ]
    },
    "``f[x]````f[x]``<RawBoxes>Cell[BoxData[SqrtBox[\"x\"]], \"InlineFormula\"]</RawBoxes>",
    SameTest -> MatchQ,
    TestID   -> "Originals-InlineCellUUIDs"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*URIs*)

(* A graphic is a URI for its boxes, which are kept as they are. They are in $attachments in the form that is made an
   image for multimodal chats, and reading notes the key: *)
VerificationTest[
    csStores @ Module[ { graphics, body, key },
        graphics = GraphicsBox[ { RGBColor[ 1, 0, 0 ], DiskBox[ { 0, 0 } ] }, ImageSize -> 50 ];
        body = csCode @ RowBox @ { "ImageResize", "[", RowBox @ { graphics, ",", "100" }, "]" };
        key = csKey @ body;
        {
            body === "ImageResize[![Image](attachment://" <> key <> "), 100]",
            Wolfram`Chatbook`Common`$attachments[ key ] === With[ { boxes = graphics }, HoldComplete @ RawBoxes @ StyleBox[ boxes, "GraphicsRawBoxes" ] ],
            Wolfram`Chatbook`Common`graphicsQ @@ Wolfram`Chatbook`Common`$attachments[ key ],
            Keys @ Wolfram`Chatbook`Common`$notebookAttachments === { key }
        }
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "URI-Graphics"
]

(* An inline cell with a graphic is a URI for the cell: *)
VerificationTest[
    csStores @ Module[ { cell, body, key },
        cell = Cell[ BoxData @ GraphicsBox[ { DiskBox[ { 0, 0 } ] }, ImageSize -> 20 ], FontSize -> 10 ];
        body = csText @ { "see ", cell, " here" };
        key = csKey @ body;
        {
            body === "see ![Image](attachment://" <> key <> ") here",
            Wolfram`Chatbook`Common`$attachments[ key ] === With[ { boxes = cell }, HoldComplete @ RawBoxes @ StyleBox[ boxes, "GraphicsRawBoxes" ] ]
        }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "URI-GraphicsInText"
]

(* Dynamic boxes are a URI for the boxes, which are kept as they are and not interpreted: *)
VerificationTest[
    csStores @ Block[ { $csRan = False },
        Module[ { dynamic, body, key },
            dynamic = DynamicModuleBox[
                { },
                InterpretationBox[ "x", $csRan = True ],
                Initialization :> ($csRan = True)
            ];
            body = csCode @ RowBox @ { "f", "[", dynamic, "]" };
            key = csKey @ body;
            {
                body === "f[![DynamicModuleBox](expression://" <> key <> ")]",
                Wolfram`Chatbook`Common`$attachments[ key ] === With[ { boxes = dynamic }, HoldComplete @ RawBoxes @ boxes ],
                $csRan
            }
        ]
    ],
    { True, True, False },
    SameTest -> MatchQ,
    TestID   -> "URI-DynamicBoxes"
]

(* Boxes are a URI when they are longer than 2000 characters as <RawBoxes>: *)
VerificationTest[
    csStores @ Module[ { small, large, bodies },
        small  = GridBox @ Table[ ToString[ i + j ], { i, 10 }, { j, 10 } ];
        large  = GridBox @ Table[ ToString[ i + j ], { i, 20 }, { j, 20 } ];
        bodies = csCode /@ { small, large };
        {
            StringStartsQ[ bodies[[ 1 ]], "<RawBoxes>GridBox[" ],
            StringMatchQ[ bodies[[ 2 ]], "![GridBox](expression://content-" ~~ WordCharacter.. ~~ ")" ],
            Wolfram`Chatbook`Common`$attachments[ csKey @ bodies[[ 2 ]] ] === With[ { boxes = large }, HoldComplete @ RawBoxes @ boxes ],
            Length @ Wolfram`Chatbook`Common`$attachments
        }
    ],
    { True, True, True, 1 },
    SameTest -> MatchQ,
    TestID   -> "URI-LargeBoxes"
]

(* What exact reading adds to $attachments is bounded by number and by size: the boxes that were read longest ago are
   dropped first, and reading boxes again makes them the newest. Other attachments stay. *)
VerificationTest[
    csStores @ Module[ { boxes, other, keys },
        (* GraphicsBox holds its arguments *)
        boxes = Function[ r, GraphicsBox[ { DiskBox[ { 0, 0 }, r ] } ] ] /@ { 1, 2, 3 };
        other = csKey @ MakeExpressionURI[ "kept" ];
        {
            Block[ { Wolfram`Chatbook`Serialization`Private`$maxNotebookAttachments = 2 },
                keys = csKey @* csCode /@ boxes[[ { 1, 2, 1, 3 } ]];
                { keys[[ 1 ]] === keys[[ 3 ]], Keys @ Wolfram`Chatbook`Common`$attachments === { other, keys[[ 3 ]], keys[[ 4 ]] } }
            ],
            Block[ { Wolfram`Chatbook`Serialization`Private`$maxNotebookAttachmentBytes = ByteCount @ First @ boxes + 1 },
                keys = csKey @* csCode /@ boxes;
                Keys @ Wolfram`Chatbook`Common`$attachments === { other, keys[[ 3 ]] }
            ]
        }
    ],
    { { True, True }, True },
    SameTest -> MatchQ,
    TestID   -> "URI-AttachmentsBound"
]

(* The default serialization of graphics is not changed by any of this: *)
VerificationTest[
    csStores @ {
        CellToString[ Cell[ BoxData @ GraphicsBox[ { DiskBox[ { 0, 0 } ] } ], "Output" ], "ContentTypes" -> { "Text", "Image" } ],
        Wolfram`Chatbook`Common`$notebookAttachments
    },
    { _String? (StringContainsQ[ "\\!\\(\\*MarkdownImageBox[\"![Image](attachment://content-" ]), <| |> },
    SameTest -> MatchQ,
    TestID   -> "URI-DefaultUnchanged"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Automatic*)

(* With "PreserveBoxes" -> Automatic, cells that evaluation made keep the lossy body and its length limit: *)
VerificationTest[
    CellToString[
        Notebook @ {
            Cell[ BoxData @ RowBox @ { SuperscriptBox[ "x", "2" ], "+", "1" }, "Input", CellLabel -> "In[1]:=" ],
            Cell[ BoxData @ RowBox @ { SuperscriptBox[ "x", "2" ], "+", "1" }, "Output", CellLabel -> "Out[1]=" ],
            Cell[ BoxData @ SuperscriptBox[ "y", "2" ], "Print" ],
            Cell[ BoxData @ SuperscriptBox[ "z", "2" ], "Echo" ],
            Cell[ BoxData @ TemplateBox[ { "Power", "infy", "\"Infinite expression 1/0 encountered.\"", 2, 1, 1, 123, "Local" }, "MessageTemplate" ], "Message", "MSG" ],
            Cell[ TextData @ { "A ", StyleBox[ "red", FontColor -> RGBColor[ 1, 0, 0 ] ], " word" }, "ChatOutput" ],
            Cell[ TextData @ { "A ", StyleBox[ "red", FontColor -> RGBColor[ 1, 0, 0 ] ], " word" }, "Text" ]
        },
        "IncludeXML"    -> True,
        "PreserveBoxes" -> Automatic
    ],
    StringJoin[
        "<cell id='c1' style='Input' CellLabel='In[1]:='>\n<RawBoxes>SuperscriptBox[\"x\", \"2\"]</RawBoxes> + 1\n</cell>\n\n",
        "<cell id='c2' style='Output' CellLabel='Out[1]='>\nx^2 + 1\n</cell>\n\n",
        "<cell id='c3' style='Print'>\ny^2\n</cell>\n\n",
        "<cell id='c4' style='Echo'>\nz^2\n</cell>\n\n",
        "<cell id='c5' style='Message, MSG'>\nPower::infy: Infinite expression 1/0 encountered.\n</cell>\n\n",
        "<cell id='c6' style='ChatOutput'>\nA red word\n</cell>\n\n",
        "<cell id='c7' style='Text'>\nA <RawBoxes>StyleBox[\"red\", FontColor -> RGBColor[1, 0, 0]]</RawBoxes> word\n</cell>"
    ],
    SameTest -> MatchQ,
    TestID   -> "Automatic-GeneratedCellsStayLossy"
]

VerificationTest[
    With[ { output = Cell[ BoxData @ RowBox @ Riffle[ ToString /@ Range[ 400 ], "," ], "Output" ] },
        {
            StringLength @ CellToString[ output, "IncludeXML" -> True, "PreserveBoxes" -> Automatic ],
            StringLength @ csExactBody @ output
        }
    ],
    { _Integer? (# < 600 &), 1890 },
    SameTest -> MatchQ,
    TestID   -> "Automatic-OutputLengthLimit"
]

(* In a cell tag, a graphic in a lossy body is an image link to its boxes as in an exact body, whatever the content
   types are: an image, a plot, a plot with a legend and a graphic in text. The boxes are not interpreted, and reading
   notes their keys. Without cell tags the lossy body is the default one. *)
VerificationTest[
    csStores @ Module[ { image, plot, legended, cells, text, keys },
        image    = ToBoxes @ Image[ { { { 1., 0., 0. } } } ];
        plot     = GraphicsBox[ { RGBColor[ 1, 0, 0 ], DiskBox[ { 0, 0 } ] }, ImageSize -> 40 ];
        legended = TemplateBox[ { plot, "\"legend\"" }, "Legended" ];
        cells    = {
            Cell[ BoxData @ image, "Output", CellLabel -> "Out[1]=" ],
            Cell[ BoxData @ RowBox @ { "{", RowBox @ { plot, ",", "5" }, "}" }, "Output" ],
            Cell[ BoxData @ legended, "Print" ],
            Cell[ TextData @ { "A plot: ", Cell @ BoxData @ plot, "." }, "ChatOutput" ],
            Cell[ BoxData @ RowBox @ { "f", "[", legended, "]" }, "Input" ]
        };
        text = CellToString[ Notebook @ cells, "IncludeXML" -> True, "PreserveBoxes" -> Automatic ];
        keys = StringCases[ text, "![Image](attachment://" ~~ key: (WordCharacter | "-").. ~~ ")" :> key ];
        {
            StringReplace[ text, "content-" ~~ WordCharacter.. -> "KEY" ],
            text === CellToString[ Notebook @ cells, "IncludeXML" -> True, "PreserveBoxes" -> Automatic, "ContentTypes" -> { "Text", "Image" } ],
            Wolfram`Chatbook`Common`$attachments[ First @ keys ] === With[ { boxes = image }, HoldComplete @ RawBoxes @ StyleBox[ boxes, "GraphicsRawBoxes" ] ],
            Sort @ Keys @ Wolfram`Chatbook`Common`$notebookAttachments === Union @ keys,
            StringFreeQ[ CellToString[ Notebook @ cells[[ ;; 2 ]], "PreserveBoxes" -> Automatic ], "](attachment://" ]
        }
    ],
    {
        StringJoin[
            "<cell id='c1' style='Output' CellLabel='Out[1]='>\n![Image](attachment://KEY)\n</cell>\n\n",
            "<cell id='c2' style='Output'>\n{![Image](attachment://KEY), 5}\n</cell>\n\n",
            "<cell id='c3' style='Print'>\n![Image](attachment://KEY)\n</cell>\n\n",
            "<cell id='c4' style='ChatOutput'>\nA plot: ![Image](attachment://KEY).\n</cell>\n\n",
            "<cell id='c5' style='Input'>\nf[![Image](attachment://KEY)]\n</cell>"
        ],
        True,
        True,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Automatic-GraphicsAreImageLinks"
]

(* A cell with many graphics, which the default markdown shows as one image of the cell, has a link for each of them.
   What a cell tag writes is not kept for the default serialization: a TraditionalForm output with a graphic (whose
   text the serializer keeps for its boxes) reads without cell tags as it does in a kernel that never read it with
   them. *)
VerificationTest[
    csStores @ With[
        {
            many    = Cell[ BoxData @ RowBox @ Riffle[ Table[ GraphicsBox[ { DiskBox[ { 0, 0 }, r ] }, ImageSize -> 20 ], { r, 8 } ], "," ], "Output" ],
            formula = Cell[ BoxData @ FormBox[ RowBox @ { "{", GraphicsBox[ { DiskBox[ { 0, 0 }, 7 ] }, ImageSize -> 33 ], "}" }, TraditionalForm ], "Output" ]
        },
        {
            StringCount[ CellToString[ many, "IncludeXML" -> True, "PreserveBoxes" -> Automatic ], "![Image](attachment://content-" ],
            StringCount[ CellToString @ many, "![cell image](attachment://content-" ],
            CellToString[ formula, "IncludeXML" -> True, "PreserveBoxes" -> Automatic ],
            CellToString @ formula
        }
    ],
    {
        8,
        1,
        _String? (StringMatchQ[ "<cell id='c1' style='Output'>\n{![Image](attachment://content-" ~~ WordCharacter.. ~~ ")}\n</cell>" ]),
        _String? (StringFreeQ[ "attachment://" ])
    },
    SameTest -> MatchQ,
    TestID   -> "Automatic-GraphicsLinksNotKept"
]

(* A multimodal chat gets the image of such a link, and a chat without images gets the text as it is: *)
VerificationTest[
    csStores @ With[ { text = CellToString[ Cell[ BoxData @ ToBoxes @ Image[ { { { 1., 0., 0. } } } ], "Output" ], "IncludeXML" -> True, "PreserveBoxes" -> Automatic ] },
        {
            Block[ { Wolfram`Chatbook`Common`$multimodalMessages = True }, Wolfram`Chatbook`Common`expandMultimodalString @ text ],
            Block[ { Wolfram`Chatbook`Common`$multimodalMessages = False }, Wolfram`Chatbook`Common`expandMultimodalString @ text ] === text
        }
    ],
    {
        {
            KeyValuePattern @ { "Type" -> "Text", "Data" -> _String? (StringEndsQ[ "![Image](attachment://content-" ~~ WordCharacter.. ~~ ")" ]) },
            KeyValuePattern @ { "Type" -> "Image", "Data" -> _Image },
            KeyValuePattern @ { "Type" -> "Text", "Data" -> "\n</cell>" }
        },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Automatic-GraphicsForMultimodalChats"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Selections*)

(* The markers that the notebook context puts between cells are lines of their own, and use no id: *)
VerificationTest[
    csExact @ Notebook @ {
        Cell[ "a", "Text" ],
        Cell @ Verbatim[ "<selection>" ],
        Cell[ "b", "Text" ],
        Cell @ Verbatim[ "</selection>" ],
        Cell[ "c", "Text" ],
        Cell @ Verbatim[ "<selection></selection>" ]
    },
    StringJoin[
        "<cell id='c1' style='Text'>\na\n</cell>\n\n",
        "<selection>\n\n",
        "<cell id='c2' style='Text'>\nb\n</cell>\n\n",
        "</selection>\n\n",
        "<cell id='c3' style='Text'>\nc\n</cell>\n\n",
        "<selection></selection>"
    ],
    SameTest -> MatchQ,
    TestID   -> "Selection-LinesBetweenCells"
]

(* A marker inside of a cell is given as Verbatim. The same text as content is escaped: *)
VerificationTest[
    {
        csCode @ RowBox @ { "Pl", Verbatim[ "<selection>" ], "ot", Verbatim[ "</selection>" ], "[", "\"<selection>\"", "]" },
        csText @ { "x", Verbatim[ "<selection></selection>" ], "y <selection>" }
    },
    {
        "Pl<selection>ot</selection>[<RawBoxes>\"\\\"\\.3cselection>\\\"\"</RawBoxes>]",
        "x<selection></selection>y &lt;selection>"
    },
    SameTest -> MatchQ,
    TestID   -> "Selection-InsideCells"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Truncated*)

(* An exact body has no length limit unless the caller gives one. A body that was cut says so: *)
VerificationTest[
    With[ { cell = Cell[ StringRepeat[ "abcdefghi ", 2000 ], "Text" ] },
        {
            csExact @ cell === "<cell id='c1' style='Text'>\n" <> StringRepeat[ "abcdefghi ", 2000 ] <> "\n</cell>",
            StringStartsQ[
                csExact[ cell, "MaxCellStringLength" -> 100 ],
                "<cell id='c1' style='Text' truncated='true'>\nabcdefghi "
            ],
            StringLength @ csExactBody[ cell, "MaxCellStringLength" -> 100 ],
            StringStartsQ[ csExact[ cell, "MaxCellStringLength" -> 50000 ], "<cell id='c1' style='Text'>\nabcdefghi " ]
        }
    ],
    { True, True, _Integer? (50 < # <= 100 &), True },
    SameTest -> MatchQ,
    TestID   -> "Truncated-ExactBody"
]

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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Linear Syntax*)

(* The front end reads linear syntax in the text of boxes, so a token or a piece of markdown with it is not written as
   it is. In a plain string it is only text, and a \! without \( opens nothing: *)
VerificationTest[
    {
        csCode @ RowBox @ { "f", "[", "\"\\!\\(\\*SuperscriptBox[x, 2]\\)\"", "]" },
        csCode @ RowBox @ { "g", "[", "\"a\\\\!b\"", "]" },
        csText @ { StyleBox[ "a\\!\\(b\\)", "InlineCode" ], " ", StyleBox[ "a\\!b", "InlineCode" ] },
        csExactBody @ Cell[ "re.sub(r\"\\*\", \"\", s)  # \\!", "Program" ]
    },
    {
        "f[<RawBoxes>\"\\\"\\\\!\\\\(\\\\*SuperscriptBox[x, 2]\\\\)\\\"\"</RawBoxes>]",
        "g[\"a\\\\!b\"]",
        "<RawBoxes>StyleBox[\"a\\\\!\\\\(b\\\\)\", \"InlineCode\"]</RawBoxes> ``a\\!b``",
        "re.sub(r\"\\*\", \"\", s)  # \\!"
    },
    SameTest -> MatchQ,
    TestID   -> "LinearSyntax-NotWrittenAsText"
]

(* :!CodeAnalysis::EndBlock:: *)
