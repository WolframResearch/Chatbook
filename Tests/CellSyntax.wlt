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
        csTag, csExact, csBody, csExactBody, csCode, csText, csStores, csKey, csWrite, csCells, csFailureMessage, csMessage,
        csRoundTrip, csFormula, csFrontEnd, csEvaluator, csRefusal, csNotRefused
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

    (* Text in the cell syntax as cells: the records, the cells, or the message of a refusal *)
    csWrite[ text_String, opts___ ] := Wolfram`Chatbook`Common`cellsFromString[ text, opts ];
    csCells[ text_String, opts___ ] := Replace[ csWrite[ text, opts ], records: { ___Association } :> Lookup[ records, "Cell" ] ];
    csFailureMessage[ result_ ] := Replace[ result, failure_Failure :> TemplateApply[ failure[ "MessageTemplate" ], failure[ "MessageParameters" ] ] ];
    csMessage[ text_String, opts___ ] := csFailureMessage @ csWrite[ text, opts ];

    (* What a text is refused with, by where it is written: as the body of a new cell of a style, as the body of the
       existing cell c7, as the data of a <RawBoxes> tag in a cell of code or of text, or as an attribute of a new cell *)
    csRefusal[ style: "Input" | "Text" | "Program", body_String ] := csMessage[ "<cell style='" <> style <> "'>\n" <> body <> "\n</cell>" ];
    csRefusal[ "style", value_String ] := csMessage[ "<cell style='" <> value <> "'>\nx\n</cell>" ];
    csRefusal[ name: "options" | "CellLabel" | "CellTags", value_String ] :=
        csMessage[ "<cell style='Text' " <> name <> "='" <> StringReplace[ value, { "&" -> "&amp;", "'" -> "&apos;" } ] <> "'>\nx\n</cell>" ];

    (* A table of refusals has a row for each text that is refused: { where it is written, the text, a part of the
       message }. This gives the rows that are not refused with their message. *)
    csNotRefused[ rows_List ] := Select[ rows, ! TrueQ @ Quiet @ StringContainsQ[ csRefusal[ #[[ 1 ]], #[[ 2 ]] ], #[[ 3 ]] ] & ];

    (* Reads a cell with an exact body and writes the text back as that cell, with what reading recorded (or without
       it). edit is applied to the text in between. *)
    csRoundTrip[ cell_Cell, edit_: Identity, originals_: True ] := csStores @ Module[ { text },
        text = csExact @ cell;
        Replace[
            csWrite[
                edit @ text,
                "Cells"     -> <| "c1" -> cell |>,
                "Originals" -> If[ originals, Wolfram`Chatbook`Common`$cellOriginals, <| |> ]
            ],
            { KeyValuePattern[ "Cell" -> new_ ] } :> new
        ]
    ];

    (* An inline formula of the TeX input assistant that was typed as this input *)
    csFormula[ input_String ] := Cell @ BoxData @ FormBox[
        TemplateBox[
            <| "boxes" -> FormBox[ StyleBox[ "x", "TI" ], TraditionalForm ], "errors" -> { }, "input" -> input, "state" -> "Boxes" |>,
            "TeXAssistantTemplate"
        ],
        TraditionalForm
    ];

    (* What the front end gives back for a cell that is written to a notebook, without the ExpressionUUIDs *)
    csFrontEnd[ cell_Cell ] := UsingFrontEnd @ Module[ { nb },
        nb = NotebookPut[ Notebook @ { cell, Cell[ "after", "Text" ] }, Visible -> False ];
        WithCleanup[
            DeleteCases[ NotebookRead @ Cells @ nb, ExpressionUUID -> _, Infinity ],
            NotebookClose @ nb
        ]
    ];

    (* Evaluates with the evaluator tool of a chat, and with its method *)
    csEvaluator // Attributes = { HoldRest };
    csEvaluator[ method_String, eval_ ] := Block[
        {
            Wolfram`Chatbook`Common`$selectedTools = <| "WolframLanguageEvaluator" -> True |>,
            Wolfram`Chatbook`Common`$toolOptions   = <|
                "WolframLanguageEvaluator" -> <| $DefaultToolOptions[ "WolframLanguageEvaluator" ], "Method" -> method |>
            |>
        },
        eval
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

(* The writer reads asterisks as emphasis only where they are not inside of a word, so bold or italic text that
   touches a letter or a digit is not written with markers. When the text around it is edited, it is still that
   box: *)
VerificationTest[
    With[ { items = { "un", StyleBox[ "frigging", FontWeight -> Bold ], "believable ", StyleBox[ "bold", FontWeight -> Bold ], " (", StyleBox[ "it", FontSlant -> Italic ], ") ", StyleBox[ "a", FontWeight -> Bold ], StyleBox[ "b", FontSlant -> Italic ], "2" } },
        {
            csText @ items,
            csRoundTrip[ Cell[ TextData @ items, "Text" ], StringReplace[ "believable" -> "likely" ] ] === Cell[ TextData[ items /. "believable " -> "likely " ], "Text" ]
        }
    ],
    {
        "un<RawBoxes>StyleBox[\"frigging\", FontWeight -> Bold]</RawBoxes>believable **bold** (*it*) **a**<RawBoxes>StyleBox[\"b\", FontSlant -> Italic]</RawBoxes>2",
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Text-EmphasisInsideWords"
]

(* The writer drops a heading marker at the start of a heading and a list marker at the start of an item. Text of
   such a cell that starts like one has its first character as an entity, so that it is kept when the body is
   edited: *)
VerificationTest[
    {
        csExactBody /@ {
            Cell[ "## not a marker", "Section" ], Cell[ "- dash", "Item" ], Cell[ "12. number", "ItemNumbered" ], Cell[ "* star", "Subitem" ],
            Cell[ "- dash", "Text" ], Cell[ TextData @ { "# ", StyleBox[ "x", FontWeight -> Bold ] }, "Subsection" ]
        },
        csRoundTrip[ Cell[ "## not a marker", "Section" ], StringReplace[ "marker" -> "heading" ] ],
        csRoundTrip[ Cell[ "- dash", "Item" ], StringReplace[ "dash" -> "dashes" ] ],
        csRoundTrip[ Cell[ "12. number", "ItemNumbered" ], StringReplace[ "number" -> "numbers" ] ]
    },
    {
        { "&#35;# not a marker", "&#45; dash", "&#49;2. number", "\\* star", "- dash", "&#35; **x**" },
        Cell[ "## not a heading", "Section" ],
        Cell[ "- dashes", "Item" ],
        Cell[ "12. numbers", "ItemNumbered" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Text-MarkersAtTheStart"
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

(* The address of a link can hold parentheses in pairs. It comes back as the link that it was: *)
VerificationTest[
    With[ { link = ButtonBox[ " text", BaseStyle -> "Hyperlink", ButtonData -> { URL[ "https://en.wikipedia.org/wiki/Function_(mathematics)" ], None } ] },
        {
            csText @ { "See", link, "." },
            csCells[ "<cell style='Text'>\n" <> csText @ { "See", link, "." } <> "\n</cell>" ]
        }
    ],
    {
        "See[ text](https://en.wikipedia.org/wiki/Function_(mathematics)).",
        {
            Cell[
                TextData @ { "See", ButtonBox[ " text", BaseStyle -> "Hyperlink", ButtonData -> { URL[ "https://en.wikipedia.org/wiki/Function_(mathematics)" ], None }, ButtonNote -> _ ], "." },
                "Text"
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Text-LinkWithParentheses"
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

(* A formula that is not changed is written back as it was, with its dollars, when text next to it changes. One that is
   changed is a new formula: *)
VerificationTest[
    With[ { cell = Cell[ TextData @ { "from 1 to ", csFormula[ "$n$" ], " and to ", csFormula[ "$m$" ], "." }, "Text" ] },
        {
            csRoundTrip[ cell, StringReplace[ "from 1" -> "from 2" ] ],
            csRoundTrip[ cell, StringReplace[ "$$m$$" -> "$$k$$" ] ]
        }
    ],
    {
        Cell[ TextData @ { "from 2 to ", csFormula[ "$n$" ], " and to ", csFormula[ "$m$" ], "." }, "Text" ],
        Cell[
            TextData @ {
                "from 1 to ",
                csFormula[ "$n$" ],
                " and to ",
                Cell @ BoxData @ FormBox[ TemplateBox[ KeyValuePattern @ { "input" -> "k", "state" -> "Boxes" }, "TeXAssistantTemplate" ], TraditionalForm ],
                "."
            },
            "Text"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-MathWithDollarSigns"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tables*)
(* The table of the chat formatter is a markdown table on unwrapped lines. When the text next to it changes, it is
   still the table that it was: *)
VerificationTest[
    Module[ { items, body },
        items = FormatMarkdown[ "Before\n\n| Name | Value |\n| --- | --- |\n| a | " <> StringRepeat[ "long ", 60 ] <> "|\n\nAfter" ];
        body = csText @ items;
        {
            StringCount[ body, "long" ],
            StringCases[ body, StartOfLine ~~ "| Name" ~~ Except[ "\n" ].. ],
            Cases[ items, Cell[ _BoxData, "TextTableForm", ___ ] ] ===
                Cases[ First @ First @ csRoundTrip[ Cell[ TextData @ items, "Text" ], StringReplace[ "After" -> "Later" ] ], Cell[ _BoxData, "TextTableForm", ___ ] ]
        }
    ],
    { 60, { _String? (StringMatchQ[ "| Name" ~~ " "... ~~ " | Value" ~~ " "... ~~ " |" ]) }, True },
    SameTest -> MatchQ,
    TestID   -> "Text-Table"
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

(* Each cell has its own records: the same markdown gives each cell the boxes that it had. Reading a cell again
   replaces what was recorded for it, so a piece that the cell no longer has is not its own any more (here it is found
   in the other cell): *)
VerificationTest[
    csStores @ Module[ { cells, changed, read },
        cells   = {
            Cell[ TextData @ { StyleBox[ "x", FontWeight -> "Bold" ], " a" }, "Text" ],
            Cell[ TextData @ { StyleBox[ "x", FontWeight -> Bold, StripOnInput -> False ], " a" }, "Text" ]
        };
        changed = Cell[ TextData @ { "only ", StyleBox[ "y", FontSlant -> "Italic" ] }, "Text" ];
        read    = csExact @ Notebook @ cells;
        {
            csCells[
                StringReplace[ read, " a" -> " b" ],
                "Cells"     -> <| "c1" -> cells[[ 1 ]], "c2" -> cells[[ 2 ]] |>,
                "Originals" -> Wolfram`Chatbook`Common`$cellOriginals
            ],
            csExact @ changed;
            csCells[
                "<cell id='c1'>\n**x** and *y*\n</cell>",
                "Cells"     -> <| "c1" -> changed, "c2" -> cells[[ 2 ]] |>,
                "Originals" -> Wolfram`Chatbook`Common`$cellOriginals
            ]
        }
    ],
    {
        {
            Cell[ TextData @ { StyleBox[ "x", FontWeight -> "Bold" ], " b" }, "Text" ],
            Cell[ TextData @ { StyleBox[ "x", FontWeight -> Bold, StripOnInput -> False ], " b" }, "Text" ]
        },
        { Cell[ TextData @ { StyleBox[ "x", FontWeight -> Bold, StripOnInput -> False ], " and ", StyleBox[ "y", FontSlant -> "Italic" ] }, "Text" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Originals-PerCellAndReadAgain"
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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Writing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cell Tags*)
VerificationTest[
    csWrite[ "<cell style='Text'>\nHello world\n</cell>" ],
    { <| "ID" -> None, "Cell" -> Cell[ "Hello world", "Text" ], "Attributes" -> <| "Styles" -> { "Text" }, "Options" -> { } |>, "Extra" -> <| |>, "Tag" -> 1 |> },
    SameTest -> MatchQ,
    TestID   -> "Write-CellTag"
]

(* The body is what is between the line break after the opening tag and the one before the closing tag: *)
VerificationTest[
    csCells[ "<cell style='Program'>\n\n  a\n\n</cell>\n\n<cell style='Text'>x</cell>\n<cell style='Text'>\n\n</cell>\n<cell style='Section'>\n</cell>" ],
    { Cell[ "\n  a\n", "Program" ], Cell[ "x", "Text" ], Cell[ "", "Text" ], Cell[ "", "Section" ] },
    SameTest -> MatchQ,
    TestID   -> "Write-BodyBoundaries"
]

VerificationTest[
    csCells[ "<cell style=\"Text, Extra\" CellLabel='it&apos;s &lt;a> &amp; b&#10;c' CellTags='t1,t2' options='CellFrame -> True, FontFamily -> \"A&lt;B>&apos;s\"'>\nx\n</cell>" ],
    { Cell[ "x", "Text", "Extra", CellLabel -> "it's <a> & b\nc", CellTags -> { "t1", "t2" }, CellFrame -> True, FontFamily -> "A<B>'s" ] },
    SameTest -> MatchQ,
    TestID   -> "Write-Attributes"
]

(* The markers of selections are not content: *)
VerificationTest[
    csCells[ "<selection>\n\n<cell style='Text'>\nab<selection>cd</selection>ef<selection></selection>\n</cell>\n\n</selection>" ],
    { Cell[ "abcdef", "Text" ] },
    SameTest -> MatchQ,
    TestID   -> "Write-SelectionMarkers"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Existing Cells*)

(* An attribute that is left out keeps its value, and so do the options that a tag does not show: *)
VerificationTest[
    csWrite[
        "<cell id='c3'>\nnew text\n</cell>",
        "Cells" -> <| "c3" -> Cell[ "old", "Section", CellTags -> "t", CellLabel -> "L", Background -> GrayLevel[ 0.9 ], ExpressionUUID -> "u", CellObject -> CellObject[ "u", "v" ] ] |>
    ],
    {
        <|
            "ID"         -> "c3",
            "Cell"       -> Cell[ "new text", "Section", CellTags -> "t", CellLabel -> "L", Background -> GrayLevel[ 0.9 ], ExpressionUUID -> "u" ],
            "Attributes" -> <| "Styles" -> { "Section" }, "Options" -> { CellTags -> "t", CellLabel -> "L", Background -> GrayLevel[ 0.9 ], ExpressionUUID -> "u" } |>,
            "Extra"      -> <| |>,
            "Tag"        -> 1
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "Write-ExistingCellKeepsAttributes"
]

(* An attribute replaces what it shows of the cell, and an empty one removes it. The options attribute replaces the
   options that the tag showed, in their places: one that is too long to be shown stays. *)
VerificationTest[
    With[ { long = TaggingRules -> <| "Data" -> StringRepeat[ "a", 300 ] |> },
        csCells[
            "<cell id='c3' style='Subsection' CellLabel='' CellTags='x,y' options='Background -> GrayLevel[0.5], FontSize -> 12'>\nt\n</cell>",
            "Cells" -> <| "c3" -> Cell[ "t", "Section", CellFrame -> True, CellLabel -> "L", long, Background -> GrayLevel[ 0.9 ], CellTags -> "t", CellID -> 7 ] |>
        ] === { Cell[ "t", "Subsection", long, Background -> GrayLevel[ 0.5 ], CellTags -> { "x", "y" }, CellID -> 7, FontSize -> 12 ] }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Write-ExistingCellChangesAttributes"
]

(* The id of a tag is read as models write it (C1, #2, 2), and the records of the cell are found under it: two cells
   whose text reads the same and is different boxes are both written back as the boxes that they were. *)
VerificationTest[
    With[
        {
            cells = <|
                "c1" -> Cell[ TextData @ { "A ", StyleBox[ "word", FontWeight -> "Bold" ], " here" }, "Text" ],
                "c2" -> Cell[ TextData @ { "A ", StyleBox[ "word", FontWeight -> Bold ], " there" }, "Text" ]
            |>
        },
        csStores[
            csExact @ Notebook @ Values @ cells;
            Lookup[
                csWrite[
                    "<cell id='C1'>\nA **word** here.\n</cell>\n<cell id='#2'>\nA **word** there.\n</cell>\n<cell id=' 2 ' CellTags='t'/>",
                    "Cells"     -> cells,
                    "Originals" -> Wolfram`Chatbook`Common`$cellOriginals
                ],
                { "ID", "Cell" }
            ]
        ]
    ],
    {
        { "c1", Cell[ TextData @ { "A ", StyleBox[ "word", FontWeight -> "Bold" ], " here." }, "Text" ] },
        { "c2", Cell[ TextData @ { "A ", StyleBox[ "word", FontWeight -> Bold ], " there." }, "Text" ] },
        { "c2", Missing[ "Unchanged" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Write-IDsAsWritten"
]

(* A tag without a body changes attributes only: *)
VerificationTest[
    csWrite[ "<cell id='c3' CellTags='x'/>", "Cells" -> <| "c3" -> Cell[ "t", "Text", CellTags -> { "a", "b" }, CellID -> 7 ] |> ],
    { <| "ID" -> "c3", "Cell" -> Missing[ "Unchanged" ], "Attributes" -> <| "Styles" -> { "Text" }, "Options" -> { CellTags -> "x", CellID -> 7 } |>, "Extra" -> <| |>, "Tag" -> 1 |> },
    SameTest -> MatchQ,
    TestID   -> "Write-AttributesOnly"
]

(* An option of the cell that is written as it was read is the cell's own. It is not checked, also when another
   option is added: *)
VerificationTest[
    With[ { cell = Cell[ "t", "Text", FontSize -> 1.5 Inherited, CellEventActions -> { "MouseClicked" :> Beep[ ] } ] },
        {
            StringCases[ csTag @ cell, "options='" ~~ Except[ "'" ].. ~~ "'" ],
            csCells[
                StringReplace[ csTag @ cell, "}'>" -> "}, CellFrame -> True'>" ],
                "Cells" -> <| "c1" -> cell |>
            ] === { Append[ cell, CellFrame -> True ] }
        }
    ],
    { { "options='FontSize -> 1.5*Inherited, CellEventActions -> {\"MouseClicked\" :> Beep[]}'" }, True },
    SameTest -> MatchQ,
    TestID   -> "Write-OwnOptionsNotChecked"
]

(* The kind of a body is given by the content of an existing cell, and by the styles of a new one: *)
VerificationTest[
    {
        csCells[ "<cell id='c1'>\na*b*c\n</cell>", "Cells" -> <| "c1" -> Cell[ "1+1", "Input" ] |> ],
        csCells[ "<cell id='c1' style='Item'>\na\\*b\\*c\n</cell>", "Cells" -> <| "c1" -> Cell[ "x", "Text" ] |> ],
        csCells[ "<cell style='Program'>\na *b* c\n</cell>\n<cell style='ExternalLanguage'>\na *b* c\n</cell>\n<cell style='MyStyle'>\na *b* c\n</cell>\n<cell>\na *b* c\n</cell>" ]
    },
    {
        { Cell[ "a*b*c", "Input" ] },
        { Cell[ "a*b*c", "Item" ] },
        {
            Cell[ "a *b* c", "Program" ],
            Cell[ "a *b* c", "ExternalLanguage" ],
            Cell[ TextData @ { "a ", StyleBox[ "b", FontSlant -> Italic ], " c" }, "MyStyle" ],
            Cell[ TextData @ { "a ", StyleBox[ "b", FontSlant -> Italic ], " c" } ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Write-BodyKinds"
]

(* The content of a delimiter is not in its body, so it is left alone: *)
VerificationTest[
    csCells[ "<cell id='c1' style='Delimiter' CellTags='d'>\n\n</cell>", "Cells" -> <| "c1" -> Cell[ "\[HorizontalLine]", "Delimiter", CellFrame -> True ] |> ],
    { Cell[ "\[HorizontalLine]", "Delimiter", CellFrame -> True, CellTags -> "d" ] },
    SameTest -> MatchQ,
    TestID   -> "Write-Delimiter"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Text Outside of Cell Tags*)

(* Only cell tags are read. Text between them is refused with what to write instead, also a line that a model adds
   for a tool and markdown as in a chat reply. Blank lines between the tags are no text: *)
VerificationTest[
    {
        csMessage[ "Some *text* here.\n\n<cell style='Input'>\nx = 1\n</cell>" ],
        csMessage[ "<cell style='Text'>\nx\n</cell>\nafter: c26\n<cell style='Text'>\ny\n</cell>" ],
        csMessage[ "<cell style='Text'>\nx\n</cell>\n\n```wl\n1 + 1\n```" ],
        csCells[ "\n\n<cell style='Text'>\nx\n</cell>\n\n\n<cell style='Text'>\ny\n</cell>\n\n" ]
    },
    {
        "The text outside of cell tags is not read (Some *text* here.). Write each new cell as its own <cell style='...'> block: the tag on a line, the content on the next lines and </cell> on a line of its own. Blank lines between the blocks are fine.",
        _String? (StringStartsQ[ "The text outside of cell tags is not read (after: c26). Write each new cell as its own <cell style='...'> block" ]),
        _String? (StringStartsQ[ "The text outside of cell tags is not read (```wl\n1 + 1\n```). Write each new cell" ]),
        { Cell[ "x", "Text" ], Cell[ "y", "Text" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Write-TextOutsideOfTags"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Callers*)

(* A caller can have attributes of its own in a cell tag: they are not read, and the record of the cell has the ones
   that its tag gives. The existing cells can come from a function, which is asked once for a tag. The record has the
   number of its tag in the text, which is what a message calls a new cell by. *)
VerificationTest[
    Module[ { asked = { } },
        {
            csWrite[
                "<cell id='c3' after='c5' delete='true'/>\n<cell style='Text' before='c1'>\nnew\n</cell>\n<cell id='c3'>\nchanged\n</cell>",
                "Cells"           -> Function[ id, AppendTo[ asked, id ]; If[ id === "c3", Cell[ "old", "Text", CellTags -> "t" ], Missing[ "NoCell", id ] ] ],
                "ExtraAttributes" -> { "after", "before", "delete" }
            ],
            asked,
            csMessage[ "<cell style='Text'>\nx\n</cell>\n<cell id='c4' after='c1'/>", "Cells" -> (Missing[ "NoCell", # ] &), "ExtraAttributes" -> { "after" } ],
            csMessage[ "<cell style='Text'>\nx\n</cell>\n<cell style='Text' after='c1'>\n<RawBoxes>Sin[1]</RawBoxes>\n</cell>", "ExtraAttributes" -> { "after" } ],
            csMessage[ "<cell style='Text' after='c1'>\nx\n</cell>" ],
            csMessage[ "<cell style='Text' position='c1'>\nx\n</cell>", "ExtraAttributes" -> { "after", "before" } ]
        }
    ],
    {
        {
            <| "ID" -> "c3", "Cell" -> Missing[ "Unchanged" ], "Attributes" -> <| "Styles" -> { "Text" }, "Options" -> { CellTags -> "t" } |>, "Extra" -> <| "after" -> "c5", "delete" -> "true" |>, "Tag" -> 1 |>,
            <| "ID" -> None, "Cell" -> Cell[ "new", "Text" ], "Attributes" -> <| "Styles" -> { "Text" }, "Options" -> { } |>, "Extra" -> <| "before" -> "c1" |>, "Tag" -> 2 |>,
            <| "ID" -> "c3", "Cell" -> Cell[ "changed", "Text", CellTags -> "t" ], "Attributes" -> <| "Styles" -> { "Text" }, "Options" -> { CellTags -> "t" } |>, "Extra" -> <| |>, "Tag" -> 3 |>
        },
        { "c3", "c3" },
        "Cell c4 does not exist. Use the id of a cell that was read, or leave the id out to write a new cell.",
        _String? (StringStartsQ[ "Cell tag 2 (a new cell) has <RawBoxes> that are not only boxes and plain data" ]),
        "Cell tag 1 (a new cell) has the attribute after, which is not one of id, style, CellLabel, CellTags and options.",
        "Cell tag 1 (a new cell) has the attribute position, which is not one of id, style, CellLabel, CellTags, options, after and before."
    },
    SameTest -> MatchQ,
    TestID   -> "Write-ExtraAttributesAndCellFunction"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Writing Text*)

(* Plain text is read from left to right: backslash escapes, long names and the two entities. Other markdown has no
   meaning in a body: *)
VerificationTest[
    csCells[ "<cell style='Text'>\na\\*b \\`c\\` \\$d \\| e\\\\f [x\\](y) \\_x\\_ \\~\\~q\\~\\~ \\[FormalX] \\[Alpha] \\:03b2 \\\\[Alpha] \\" <> "[NotAName] &lt;cell> &amp;lt; R&D\n# no heading\n- no item\n\n1. x\n</cell>" ],
    { Cell[ "a*b `c` $d | e\\f [x](y) _x_ ~~q~~ \[FormalX] \[Alpha] \[Beta] \\[Alpha] \\" <> "[NotAName] <cell> &lt; R&D\n# no heading\n- no item\n\n1. x", "Text" ] },
    SameTest -> MatchQ,
    TestID   -> "WriteText-PlainText"
]

(* What is read is what was written, for any text: *)
VerificationTest[
    Select[
        {
            "a*b `c` $d | e\\f [x](y) snake_case _x_ __init__ ~~q~~ ~~~",
            "\\*", "\\\\", "\\[Alpha]", "\\[", "\\](", "\\~~", "&amp;lt;", "&lt;cell>", "<cell", "\\&lt;", "]]((",
            "a \[FormalX] \\[FormalX] \[Alpha] \[Rule] \\\[Rule]", "line 1\n  line 2\n\n# line 4", " lead and trail ",
            "<selection> </RawBoxes> <!attachment://content-abcde!> ![x](y)", "**b** *i* ``c`` $$m$$ | t |\n| - |"
        },
        csRoundTrip @ Cell[ #, "Text" ] =!= Cell[ #, "Text" ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "WriteText-PlainTextRoundTrip"
]

(* HTML entities are read in text, by name and by number, in one pass. Other text with an ampersand is as it is, and
   so is a number that is no character: *)
VerificationTest[
    csCells[ "<cell style='Text'>\na &lt; b &amp; c &gt; d &quot;e&quot; &apos;f&apos; &#39;g&#39; &#x41; &nbsp;&mdash;&hellip; &amp;lt; AT&T; x&y &#0; &nosuch;\n</cell>" ],
    { Cell[ "a < b & c > d \"e\" 'f' 'g' A \[NonBreakingSpace]\[LongDash]\[Ellipsis] &lt; AT&T; x&y &#0; &nosuch;", "Text" ] },
    SameTest -> MatchQ,
    TestID   -> "WriteText-Entities"
]

(* New markdown becomes the boxes of a notebook. Nothing in it is changed: inline code is not made a link or repaired,
   and a formula is one whatever it holds. *)
VerificationTest[
    csCells[ "<cell style='Text'>\n**bold** *italic* ***both*** ~~struck~~ ~~**x\\*y**~~ [Wolfram](https://www.wolfram.com) [Plot](paclet:ref/Plot) ``Plot[x, {x, 0, 1}`` `Sin` $$5$$\n</cell>" ],
    {
        Cell[
            TextData @ {
                StyleBox[ "bold", FontWeight -> Bold ], " ",
                StyleBox[ "italic", FontSlant -> Italic ], " ",
                StyleBox[ "both", FontWeight -> Bold, FontSlant -> Italic ], " ",
                StyleBox[ "struck", FontVariations -> { "StrikeThrough" -> True } ], " ",
                StyleBox[ "x*y", FontWeight -> Bold, FontVariations -> { "StrikeThrough" -> True } ], " ",
                ButtonBox[ "Wolfram", BaseStyle -> "Hyperlink", ButtonData -> { URL[ "https://www.wolfram.com" ], None }, ButtonNote -> "https://www.wolfram.com" ], " ",
                ButtonBox[ "Plot", BaseStyle -> "Link", ButtonData -> "paclet:ref/Plot" ], " ",
                Cell[ BoxData[ "Plot[x, {x, 0, 1}" ], "InlineCode" ], " ",
                Cell[ BoxData[ "Sin" ], "InlineCode" ], " ",
                Cell @ BoxData @ FormBox[ TemplateBox[ KeyValuePattern @ { "input" -> "5", "state" -> "Boxes" }, "TeXAssistantTemplate" ], TraditionalForm ]
            },
            "Text"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-NewMarkdown"
]

(* Emphasis opens before and closes after a character that is not white space, and can hold other pieces. The style
   goes to each run of text: *)
VerificationTest[
    csCells[ "<cell style='Text'>\nThe area is 2 * 3 * 4. **bold with *italic* inside**, *it **b** x*, **with ``code``** and ~~**both**~~.\n</cell>" ],
    {
        Cell[
            TextData @ {
                "The area is 2 * 3 * 4. ",
                StyleBox[ "bold with ", FontWeight -> Bold ], StyleBox[ "italic", FontWeight -> Bold, FontSlant -> Italic ], StyleBox[ " inside", FontWeight -> Bold ],
                ", ",
                StyleBox[ "it ", FontSlant -> Italic ], StyleBox[ "b", FontWeight -> Bold, FontSlant -> Italic ], StyleBox[ " x", FontSlant -> Italic ],
                ", ",
                StyleBox[ "with ", FontWeight -> Bold ], Cell[ BoxData[ "code" ], "InlineCode" ],
                " and ",
                StyleBox[ "both", FontWeight -> Bold, FontVariations -> { "StrikeThrough" -> True } ],
                "."
            },
            "Text"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-Emphasis"
]

(* Asterisks are emphasis only where they are not inside of a word, as models write products (2*3*4). Underscores
   are read the same way. The markers of bold and italic can touch: *)
VerificationTest[
    {
        csCells[ "<cell style='Text'>\n2*3*4, a*b + c*d and m*c^2, but *this* and **that**. un**frig**ing **bold**text and *.txt or **/*.wl\n</cell>" ],
        csCells[ "<cell style='Text'>\n_italic_ and __bold__, my_var_name, _private and a_b_c.\n</cell>" ],
        csCells[ "<cell style='Text'>\n**a *b*** and ***c** d* and **e***f*\n</cell>" ]
    },
    {
        {
            Cell[
                TextData @ {
                    "2*3*4, a*b + c*d and m*c^2, but ", StyleBox[ "this", FontSlant -> Italic ], " and ", StyleBox[ "that", FontWeight -> Bold ],
                    ". un**frig**ing **bold**text and *.txt or **/*.wl"
                },
                "Text"
            ]
        },
        {
            Cell[
                TextData @ { StyleBox[ "italic", FontSlant -> Italic ], " and ", StyleBox[ "bold", FontWeight -> Bold ], ", my_var_name, _private and a_b_c." },
                "Text"
            ]
        },
        {
            Cell[
                TextData @ {
                    StyleBox[ "a ", FontWeight -> Bold ], StyleBox[ "b", FontWeight -> Bold, FontSlant -> Italic ], " and ",
                    StyleBox[ "c", FontWeight -> Bold, FontSlant -> Italic ], StyleBox[ " d", FontSlant -> Italic ], " and ",
                    StyleBox[ "e", FontWeight -> Bold ], StyleBox[ "f", FontSlant -> Italic ]
                },
                "Text"
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-EmphasisNotInsideWords"
]

(* What models write as in a chat: a \! that opens no linear syntax is text, an image link is a link (nothing is
   fetched), and \( \) and \[ \] hold math, which a long name is not. *)
VerificationTest[
    csCells[ "<cell style='Text'>\nHello world\\! An ![image](https://example.com/a_(1).png), $$a\\!b$$, \\(x^2\\) and \\[y^2\\], not \\[Alpha] or \\\\(z\\\\).\n</cell>" ] /.
        TemplateBox[ data_Association, "TeXAssistantTemplate", ___ ] :> data[ "input" ],
    {
        Cell[
            TextData @ {
                "Hello world\\! An ",
                ButtonBox[ "image", BaseStyle -> "Hyperlink", ButtonData -> { URL[ "https://example.com/a_(1).png" ], None }, ButtonNote -> "https://example.com/a_(1).png" ],
                ", ",
                Cell @ BoxData @ FormBox[ "a\\!b", TraditionalForm ],
                ", ",
                Cell @ BoxData @ FormBox[ "x^2", TraditionalForm ],
                " and ",
                Cell @ BoxData @ FormBox[ "y^2", TraditionalForm ],
                ", not \[Alpha] or \\(z\\)."
            },
            "Text"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-AsInAChat"
]

(* The marker that the default markdown has for a heading or an item says what the style of the cell says, and is
   not content there. In other cells it is text: *)
VerificationTest[
    csCells[ "<cell style='Section'>\n## A heading\n</cell>\n<cell style='Item'>\n- an item\n</cell>\n<cell style='ItemNumbered'>\n1. first\n</cell>\n<cell style='Subitem'>\n* sub *item*\n</cell>\n<cell style='Text'>\n- not an item\n</cell>\n<cell style='Item'>\n*italic* start\n</cell>" ],
    {
        Cell[ "A heading", "Section" ],
        Cell[ "an item", "Item" ],
        Cell[ "first", "ItemNumbered" ],
        Cell[ TextData @ { "sub ", StyleBox[ "item", FontSlant -> Italic ] }, "Subitem" ],
        Cell[ "- not an item", "Text" ],
        Cell[ TextData @ { StyleBox[ "italic", FontSlant -> Italic ], " start" }, "Item" ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-MarkersOfTheDefaultMarkdown"
]

(* The label of a link can hold other pieces, and keeps its own spaces: *)
VerificationTest[
    csCells[ "<cell style='Text'>\n[**bold** label](https://example.com) and the[ research ](paclet:ref/Plot)on it\n</cell>" ],
    {
        Cell[
            TextData @ {
                ButtonBox[ RowBox @ { StyleBox[ "bold", FontWeight -> Bold ], " label" }, BaseStyle -> "Hyperlink", ButtonData -> { URL[ "https://example.com" ], None }, ButtonNote -> "https://example.com" ],
                " and the",
                ButtonBox[ " research ", BaseStyle -> "Link", ButtonData -> "paclet:ref/Plot" ],
                "on it"
            },
            "Text"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-LinkLabels"
]

(* A pipe is text unless the body holds a table: a header row and a row of dashes under it. Inline code in such text is
   not made a link by the chat formatter. *)
VerificationTest[
    csCells[ "<cell style='Text'>\nUse a | b for alternatives, and `Or` for logic.\n| not | a table |\n</cell>" ],
    { Cell[ TextData @ { "Use a | b for alternatives, and ", Cell[ BoxData[ "Or" ], "InlineCode" ], " for logic.\n| not | a table |" }, "Text" ] },
    SameTest -> MatchQ,
    TestID   -> "WriteText-PipesAreText"
]

VerificationTest[
    csCells[ "<cell style='Text'>\nso $$\\lim_{x \\to 2} f(x) = 5$$.\n</cell>" ],
    {
        Cell[
            TextData @ {
                "so ",
                Cell @ BoxData @ FormBox[
                    TemplateBox[ KeyValuePattern @ { "boxes" -> _FormBox, "input" -> "\\lim_{x \\to 2} f(x) = 5", "state" -> "Boxes" }, "TeXAssistantTemplate" ],
                    TraditionalForm
                ],
                "."
            },
            "Text"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-Math"
]

(* A table is an inline cell, as the chat formatter makes it, and reads as the same table again: *)
VerificationTest[
    With[ { cells = csCells[ "<cell style='Text'>\nBefore\n| Name | Value |\n| --- | --- |\n| a | 1 |\nAfter\n</cell>" ] },
        {
            cells,
            Replace[ cells, { cell_Cell } :> StringCount[ csExactBody @ cell, "|" ] ]
        }
    ],
    {
        { Cell[ TextData @ { "Before\n", Cell[ _BoxData, "TextTableForm", ___ ], "\nAfter" }, "Text" ] },
        9
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-Table"
]

(* Code in a table stays the text that it is and is not typeset, as inline code and as the text of a table cell: *)
VerificationTest[
    With[ { code = "RGBColor[1, 0, 0]" },
        With[ { cells = csCells[ "<cell style='Text'>\n| a | b |\n|---|---|\n| `" <> code <> "` | " <> code <> " |\n</cell>" ] },
            {
                Cases[ cells, Cell[ BoxData[ text_String ], "InlineWL", ___ ] :> text === code, Infinity ],
                FreeQ[ cells, _TemplateBox ]
            }
        ]
    ],
    { { True, True }, True },
    SameTest -> MatchQ,
    TestID   -> "WriteText-TableCodeIsText"
]

(* In a table an image link is a link. A URI, three backticks and an image link that can't be read are refused there,
   also a URI that has a value: *)
VerificationTest[
    csStores[
        Wolfram`Chatbook`Common`$attachments[ "content-abcde" ] = HoldComplete[ 1 ];
        {
            Cases[ csCells[ "<cell style='Text'>\n| a | b |\n|---|---|\n| ![pic](https://example.com/a.png) | 2 |\n</cell>" ], _ButtonBox, Infinity ],
            csNotRefused @ {
                { "Text", "| a | b |\n|---|---|\n| <!expression://content-abcde!> | 2 |", "Cell tag 1 (a new cell) has the URI expression://content-abcde in a table, where a URI is not read" },
                { "Text", "| a | b |\n|---|---|\n| [the value](expression://content-abcde) | 2 |", "has the URI expression://content-abcde in a table" },
                { "Text", "| a | b |\n|---|---|\n| ```wl | 2 |", "has three backticks in a table" },
                { "Text", "| a | b |\n|---|---|\n| ![x](https://example.com/a b.png) | 2 |", "has an image link in a table that could not be read" }
            }
        }
    ],
    {
        { ButtonBox[ "pic", BaseStyle -> "Hyperlink", ButtonData -> { URL[ "https://example.com/a.png" ], None }, ___ ] },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-TableImagesAndURIs"
]

(* A body that is one piece gives boxes again for a cell that had boxes, and for a new formula cell. With text around
   it, the piece is an inline cell. *)
VerificationTest[
    With[ { formula = Cell[ BoxData @ FormBox[ RowBox @ { "a", "=", "b" }, TraditionalForm ], "DisplayFormula" ] },
        {
            csCells[ "<cell style='DisplayFormulaNumbered'>\n$$a=b$$\n</cell>\n<cell style='Text'>\n$$a=b$$\n</cell>" ],
            csRoundTrip[ Cell[ BoxData @ GridBox @ { { SqrtBox[ "1" ], "2" } }, "Text" ], StringReplace[ "\"2\"" -> "\"3\"" ] ],
            csRoundTrip[ formula, StringReplace[ "$$a=b$$" -> "Then $$a=b$$ holds." ] ]
        }
    ],
    {
        {
            Cell[ BoxData @ FormBox[ TemplateBox[ KeyValuePattern[ "input" -> "a=b" ], "TeXAssistantTemplate" ], TraditionalForm ], "DisplayFormulaNumbered" ],
            Cell[ TextData @ { Cell @ BoxData @ FormBox[ TemplateBox[ KeyValuePattern[ "input" -> "a=b" ], "TeXAssistantTemplate" ], TraditionalForm ] }, "Text" ]
        },
        Cell[ BoxData @ GridBox @ { { SqrtBox[ "1" ], "3" } }, "Text" ],
        Cell[ TextData @ { "Then ", Cell @ BoxData @ FormBox[ RowBox @ { "a", "=", "b" }, TraditionalForm ], " holds." }, "DisplayFormula" ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-BoxesInCellsOfText"
]

(* A table that is not changed is the grid that it was read from, also when text next to it changes. A table that is
   changed is the table that the chat formatter makes: *)
VerificationTest[
    With[
        {
            grid = Cell @ BoxData @ TagBox[ GridBox @ { { "\"a\"", "\"b\"" }, { "\"c\"", "\"d\"" } }, "Grid" ],
            whole = Cell[ BoxData @ TagBox[ GridBox @ { { "\"a\"", "\"b\"" }, { "\"c\"", "\"d\"" } }, "Grid" ], "Text" ]
        },
        {
            csRoundTrip @ whole === whole,
            csRoundTrip[ whole, Identity, False ] === whole,
            csRoundTrip[ Cell[ TextData @ { "A table:\n", grid, "\nand text." }, "Text" ], StringReplace[ "and text" -> "and more text" ] ] ===
                Cell[ TextData @ { "A table:\n", grid, "\nand more text." }, "Text" ],
            csRoundTrip[ whole, StringReplace[ "| c | d |" -> "| c | e |" ] ]
        }
    ],
    {
        True,
        True,
        True,
        Cell[ BoxData[ boxes_ ] /; ! FreeQ[ boxes, GridBox[ { { "\"a\"", "\"b\"" }, { "\"c\"", "\"e\"" } }, ___ ] ], "Text" ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-GridOfText"
]

(* Pieces that follow one another end at their first closing marker: *)
VerificationTest[
    csCells[ "<cell style='Text'>\n``a````b``**c***d*\n</cell>" ],
    {
        Cell[
            TextData @ {
                Cell[ BoxData[ "a" ], "InlineCode" ], Cell[ BoxData[ "b" ], "InlineCode" ],
                StyleBox[ "c", FontWeight -> Bold ], StyleBox[ "d", FontSlant -> Italic ]
            },
            "Text"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-AdjacentPieces"
]

(* In text, new boxes are an inline cell, unless they are a cell, or a style box or a link of text. A string is text: *)
VerificationTest[
    csCells[ "<cell style='Text'>\na <RawBoxes>FractionBox[\"1\", \"2\"]</RawBoxes> b <RawBoxes>StyleBox[\"red\", FontColor -> RGBColor[1, 0, 0]]</RawBoxes> c <RawBoxes>Cell[BoxData[SqrtBox[\"x\"]], \"InlineFormula\"]</RawBoxes> d <RawBoxes>\"*e*\"</RawBoxes>\n</cell>" ],
    {
        Cell[
            TextData @ {
                "a ", Cell @ BoxData @ FractionBox[ "1", "2" ], " b ", StyleBox[ "red", FontColor -> RGBColor[ 1, 0, 0 ] ], " c ",
                Cell[ BoxData @ SqrtBox[ "x" ], "InlineFormula" ], " d *e*"
            },
            "Text"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-RawBoxes"
]

(* A StyleBox or a link that holds other boxes than text corrupts the cell if it is an item of text itself, so it is in
   an inline cell. The front end gives the cell back as it is written (and the cell after it, which a corrupt cell
   takes with it). *)
VerificationTest[
    With[
        {
            cells = csCells @ StringJoin[
                "<cell style='Text'>\nA <RawBoxes>StyleBox[SuperscriptBox[\"x\", \"2\"], FontColor -> RGBColor[1, 0, 0]]</RawBoxes>",
                " and <RawBoxes>ButtonBox[SuperscriptBox[\"x\", \"2\"], BaseStyle -> \"Hyperlink\", ButtonData -> {URL[\"https://a.b\"], None}]</RawBoxes>",
                " and <RawBoxes>StyleBox[StyleBox[FractionBox[\"1\", \"2\"], \"TI\"], FontWeight -> Bold]</RawBoxes>.\n</cell>"
            ]
        },
        { cells, Replace[ cells, { cell_Cell } :> csFrontEnd @ cell === { cell, Cell[ "after", "Text" ] } ] }
    ],
    {
        {
            Cell[
                TextData @ {
                    "A ",
                    Cell @ BoxData @ StyleBox[ SuperscriptBox[ "x", "2" ], FontColor -> RGBColor[ 1, 0, 0 ] ],
                    " and ",
                    Cell @ BoxData @ ButtonBox[ SuperscriptBox[ "x", "2" ], BaseStyle -> "Hyperlink", ButtonData -> { URL[ "https://a.b" ], None } ],
                    " and ",
                    Cell @ BoxData @ StyleBox[ StyleBox[ FractionBox[ "1", "2" ], "TI" ], FontWeight -> Bold ],
                    "."
                },
                "Text"
            ]
        },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-StyledBoxes"
]

(* Boxes that were recorded in code are no item of text either: copied into text, or in a cell of code that is made a
   cell of text, they are in an inline cell. The user's own items of text are put back as they are. *)
VerificationTest[
    csStores @ Module[ { code, text, user, read },
        code = Cell[ BoxData @ RowBox @ { SuperscriptBox[ "x", "2" ], "+", "1" }, "Input" ];
        text = Cell[ "Some text.", "Text" ];
        user = Cell[ TextData @ { "Version ", StyleBox[ ValueBox[ "$VersionNumber" ], FontWeight -> "Plain" ], " of ", RowBox @ { "init", ".", "m" }, "." }, "Text" ];
        read = csExact @ Notebook @ { code, text, user };
        Lookup[
            csWrite[
                StringJoin[
                    "<cell id='c2'>\nSome <RawBoxes>SuperscriptBox[\"x\", \"2\"]</RawBoxes> text.\n</cell>\n",
                    "<cell id='c1' style='Text'>\n<RawBoxes>SuperscriptBox[\"x\", \"2\"]</RawBoxes> is text now\n</cell>\n",
                    StringReplace[ Last @ StringSplit[ read, "\n\n" ], "Version " -> "The version " ]
                ],
                "Cells"     -> <| "c1" -> code, "c2" -> text, "c3" -> user |>,
                "Originals" -> Wolfram`Chatbook`Common`$cellOriginals
            ],
            "Cell"
        ]
    ],
    {
        Cell[ TextData @ { "Some ", Cell @ BoxData @ SuperscriptBox[ "x", "2" ], " text." }, "Text" ],
        Cell[ TextData @ { Cell @ BoxData @ SuperscriptBox[ "x", "2" ], " is text now" }, "Text" ],
        Cell[ TextData @ { "The version ", StyleBox[ ValueBox[ "$VersionNumber" ], FontWeight -> "Plain" ], " of ", RowBox @ { "init", ".", "m" }, "." }, "Text" ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-RecordedBoxesOfCode"
]

(* Text that is changed in one place keeps every other item as it is, also items that markdown stands for and that
   would be other boxes if they were new: *)
VerificationTest[
    Module[ { items, cell },
        items = {
            "A link ",
            TemplateBox[ { "site", { URL[ "https://example.com/b" ], None }, "https://example.com/b", "HyperlinkActionRecycled", { "HyperlinkActive" }, BaseStyle -> { "Hyperlink" } }, "HyperlinkTemplate" ],
            ", code ",
            Cell[ BoxData @ RowBox @ { "f", "[", "x", "]" }, "InlineFormula", FontFamily -> "Source Sans Pro" ],
            ", math ",
            Cell[ BoxData @ FormBox[ RowBox @ { SuperscriptBox[ "x", "2" ], "+", "1" }, TraditionalForm ], FormatType -> TraditionalForm ],
            ", a ",
            StyleBox[ "bold", FontWeight -> "Bold" ],
            " word, ",
            StyleBox[ "red", FontColor -> RGBColor[ 1, 0, 0 ] ],
            ", a graphic ",
            Cell @ BoxData @ GraphicsBox[ { DiskBox[ { 0, 0 } ] }, ImageSize -> 20 ],
            " and a button ",
            Cell @ BoxData @ ButtonBox[ "\"go\"", ButtonFunction :> Beep[ ], Evaluator -> Automatic ],
            "."
        };
        cell = Cell[ TextData @ items, "Text", CellTags -> "t" ];
        {
            csRoundTrip @ cell === cell,
            csRoundTrip[ cell, StringReplace[ " word, " -> " and *new* word, " ] ] ===
                Cell[ TextData @ Flatten @ Replace[ items, " word, " -> { " and ", StyleBox[ "new", FontSlant -> Italic ], " word, " }, { 1 } ], "Text", CellTags -> "t" ]
        }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "WriteText-EditKeepsItems"
]

(* Different boxes that would read as the same markdown each keep their own, once the body is changed: the later ones
   are read as boxes. Here that is inline code in two forms, and a formula that was typed with and without dollars. *)
VerificationTest[
    With[
        {
            items = {
                Cell[ "f[x]", "InlineCode" ], " ", StyleBox[ "f[x]", "InlineCode" ], " ", StyleBox[ "g", "TI" ], " ",
                csFormula[ "$n$" ], " ", csFormula[ "n" ], " ", csFormula[ "$n$" ]
            }
        },
        {
            csText @ items,
            csRoundTrip[ Cell[ TextData @ items, "Text" ], StringReplace[ "``g``" -> "``g`` and more" ] ] ===
                Cell[ TextData @ ReplacePart[ items, 6 -> " and more " ], "Text" ]
        }
    ],
    {
        _String? (StringMatchQ[ "``f[x]`` <RawBoxes>StyleBox[\"f[x]\", \"InlineCode\"]</RawBoxes> ``g`` $$n$$ <RawBoxes>Cell[BoxData[FormBox[TemplateBox[" ~~ __ ~~ "</RawBoxes> $$n$$" ]),
        True
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-SameMarkdownKeepsBoxes"
]

(* The records of the cell itself are looked up first, then those of the other cells. A text that stands for
   different boxes in the other cells is not used: *)
VerificationTest[
    With[
        {
            originals = <|
                "c1" -> <| "**a**" -> StyleBox[ "a", FontWeight -> "Bold" ] |>,
                "c2" -> <| "**a**" -> StyleBox[ "a", FontWeight -> Bold, StripOnInput -> False ], "**b**" -> StyleBox[ "b", FontWeight -> "Bold" ], "*c*" -> StyleBox[ "c", FontSlant -> "Italic" ] |>,
                "c3" -> <| "**b**" -> StyleBox[ "b", FontWeight -> Bold, StripOnInput -> False ] |>
            |>,
            cells = <| "c1" -> Cell[ "x", "Text" ], "c2" -> Cell[ "y", "Text" ] |>
        },
        csCells[ "<cell id='c1'>\n**a** **b** *c*\n</cell>\n<cell id='c2'>\n**a**\n</cell>\n<cell style='Text'>\n*c*\n</cell>", "Cells" -> cells, "Originals" -> originals ]
    ],
    {
        Cell[ TextData @ { StyleBox[ "a", FontWeight -> "Bold" ], " ", StyleBox[ "b", FontWeight -> Bold ], " ", StyleBox[ "c", FontSlant -> "Italic" ] }, "Text" ],
        Cell[ TextData @ { StyleBox[ "a", FontWeight -> Bold, StripOnInput -> False ] }, "Text" ],
        Cell[ TextData @ { StyleBox[ "c", FontSlant -> "Italic" ] }, "Text" ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteText-OriginalsOfOtherCells"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Evaluated Tags*)

(* The notebook tools get what a tag does from evaluateToBoxes: the boxes and what the evaluator printed, or the
   failure *)
VerificationTest[
    csEvaluator[
        "Session",
        {
            Wolfram`Chatbook`Common`evaluateToBoxes[ "Print[\"printed\"]; 2^10", "StandardForm", "ToBoxes" ],
            Wolfram`Chatbook`Common`evaluateToBoxes[ "Sin[x]^2", "TraditionalForm", "MakeBoxes" ][ "Boxes" ],
            Wolfram`Chatbook`Common`evaluateToBoxes[ "1, 2", "StandardForm", "ToBoxes" ]
        }
    ],
    {
        KeyValuePattern @ { "Boxes" -> "1024", "Output" -> _String? (StringContainsQ[ "printed" ]) },
        RowBox @ { SuperscriptBox[ "sin", "2" ], "(", "x", ")" },
        Failure[ "CellSyntax", KeyValuePattern[ "MessageTemplate" -> _String? (StringContainsQ[ "gave no boxes" ]) ] ]
    },
    SameTest -> MatchQ,
    TestID   -> "Evaluated-EvaluateToBoxes"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*What Is Refused*)

(* What the model writes is checked by two rules: one for text and one for data. Each has a table of refusals here: a
   row is where a text is written (see csRefusal), the text, and a part of the message that it is refused with. A test
   gives the rows of its group that are not refused that way. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*The Rule for Text*)

(* What is made of the text is checked, not only what is typed: linear syntax that a table, a pipe, inline code,
   emphasis or an entity would carry into the cell is refused there too, in any spelling: *)
VerificationTest[
    With[ { escaped = "\\:f7c1\\:f7c9\\:f7c8DynamicBox[ToBoxes[1]]\\:f7c0" },
        csNotRefused @ {
            { "Text", "| a | b |\n|---|---|\n| " <> escaped <> " | 2 |", "has linear syntax (\\:f7c1)" },
            { "Text", "| a | b |\n|---|---|\n| x &#92;!&#92;(&#92;*DynamicBox[1]&#92;) | 2 |", "has linear syntax (\\!\\()" },
            { "Text", "See a | b " <> escaped, "has linear syntax (\\:f7c1)" },
            { "Text", "See ``" <> escaped <> "`` here.", "has linear syntax (\\:f7c1)" },
            { "Text", "See `" <> escaped <> "` here.", "has linear syntax (\\:f7c1)" },
            { "Text", "See **" <> escaped <> "** here.", "has linear syntax (\\:f7c1)" },
            { "Text", "See &#63425;&#x2a;DynamicBox[ToBoxes[1]]&#63424; here.", "has linear syntax (\\:f7c1)" }
        }
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Refused-Text-InWhatIsMade"
]

(* A new value of a label, of tags or of a style is checked as the text of a body is: *)
VerificationTest[
    csNotRefused @ {
        { "CellLabel", "a" <> FromCharacterCode @ { 16^^F7C1, 16^^F7C9 } <> "b", "Cell tag 1 (a new cell) has linear syntax (\\:f7c1)" },
        { "CellTags", "a" <> FromCharacterCode[ 7 ] <> "b", "Cell tag 1 (a new cell) has control characters" },
        { "style", "Te" <> FromCharacterCode[ 16^^F7C1 ] <> "xt", "Cell tag 1 (a new cell) has linear syntax (\\:f7c1)" }
    },
    { },
    SameTest -> MatchQ,
    TestID   -> "Refused-Text-InAttributes"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*The Rule for Data*)

(* A template that the existing cell holds is not the model's: boxes of the cell that the model changed around it are
   written with the template as the cell has it, also a template with an association (a TeX formula), with linear
   syntax in a string or with a symbol of another context, none of which the model could write. It can be written
   at another place of the cell too. A template that differs from the cell's is refused, and so is anything else
   that is not plain data next to the cell's template. The message says to copy the template or to leave it out. *)
VerificationTest[
    With[
        {
            cell = Cell[
                BoxData @ GridBox @ {
                    { "a", TemplateBox[ { Cell @ TextData @ "Out", "paclet:ref/Out" }, "RefLink", BaseStyle -> { "InlineFormula" } ] },
                    { "b", TemplateBox[ <| "boxes" -> FormBox[ "y", TraditionalForm ], "errors" -> { }, "input" -> "y", "state" -> "Boxes" |>, "TeXAssistantTemplate" ] },
                    { "c", TemplateBox[ { "\!\(\*StyleBox[\"x\", \"TI\"]\)", CellSyntaxTest`csSymbol }, "Other" ] }
                },
                "Text"
            ]
        },
        {
            StringCount[ csExactBody @ cell, "<RawBoxes>" ],
            csRoundTrip[ cell, StringReplace[ "\"a\"" -> "\"A\"" ] ] === (cell /. "a" -> "A"),
            csRoundTrip[ cell, StringReplace[ "\"c\"" -> "TemplateBox[{Cell[TextData[\"Out\"]], \"paclet:ref/Out\"}, \"RefLink\", BaseStyle -> {\"InlineFormula\"}]" ] ] === (cell /. "c" -> cell[[ 1, 1, 1, 1, 2 ]]),
            csFailureMessage @ csRoundTrip[ cell, StringReplace[ "paclet:ref/Out" -> "paclet:ref/In" ] ],
            csFailureMessage @ csRoundTrip[ cell, StringReplace[ "\"a\"" -> "DynamicBox[ToBoxes[1]]" ] ]
        }
    ],
    {
        1,
        True,
        True,
        _String? (StringStartsQ[ "Cell c1 has <RawBoxes> with a TemplateBox, which is not written: a template shows and does what its stylesheet style says, which can run code on a click. Only a TemplateBox that the cell already has is kept: copy it unchanged from the cell as it was read, or leave it out. What was written: " ]),
        _String? (StringStartsQ[ "Cell c1 has <RawBoxes> that are not only boxes and plain data" ])
    },
    SameTest -> MatchQ,
    TestID   -> "Refused-Data-TemplatesOfTheCell"
]

(* The options that a cell tag never shows are not the model's to set: *)
VerificationTest[
    csNotRefused @ {
        { "options", "ExpressionUUID -> \"abc\"", "Cell tag 1 (a new cell) has the option ExpressionUUID, which a cell tag does not show and cannot set. Leave it out: the cell keeps its own." },
        { "options", "CellFrame -> True, GeneratedCell -> False", "Cell tag 1 (a new cell) has the option GeneratedCell, which a cell tag does not show" }
    },
    { },
    SameTest -> MatchQ,
    TestID   -> "Refused-Data-HiddenOptions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Round Trips*)

(* Cells of every kind that is not generated. An unchanged body gives the content of the cell back whatever it holds,
   also without what reading recorded: *)
VerificationTest[
    With[
        {
            formula = Function[ input,
                Cell @ BoxData @ FormBox[
                    TemplateBox[ <| "boxes" -> FormBox[ SuperscriptBox[ StyleBox[ "x", "TI" ], "2" ], TraditionalForm ], "errors" -> { }, "input" -> input, "state" -> "Boxes" |>, "TeXAssistantTemplate" ],
                    TraditionalForm
                ]
            ],
            image = GraphicsBox[ TagBox[ RasterBox[ { { 0., 1. }, { 1., 0. } }, { { 0, 2 }, { 2, 0 } }, { 0, 1 } ], BoxForm`ImageTag[ "Real32", ColorSpace -> "Grayscale" ] ], ImageSize -> 20 ]
        },
        Select[
            {
                (* Headings and other styles of text *)
                Cell[ "A Title", "Title" ], Cell[ "Sub", "Subtitle" ], Cell[ "Ch", "Chapter" ], Cell[ "Sec", "Section" ], Cell[ "Subsec", "Subsection" ],
                Cell[ "Subsubsec", "Subsubsection" ], Cell[ "S4", "Subsubsubsection" ], Cell[ "Me", "Author" ], Cell[ "Abs", "Abstract" ], Cell[ "small", "SmallText" ],
                Cell[ "Then:", "CodeText" ], Cell[ "one", "ItemNumbered" ], Cell[ "para", "ItemParagraph" ], Cell[ "mine", "MyStyle" ], Cell[ "question?", "ChatInput" ],
                (* Text *)
                Cell[ "Plain text.", "Text" ],
                Cell[ "Line 1\nLine 2\n\nLine 4", "Text" ],
                Cell[ "a*b _c_ # d $e$ `f` g|h [link](y) &amp; &lt; <cell> \[Rule] \\[Rule] ~~s~~ **b** 1. x\n- y\n# z", "Text" ],
                Cell[ "", "Text" ],
                Cell[ TextData[ "one string" ], "Text" ],
                Cell[ TextData @ { "list of one" }, "Text" ],
                Cell[ "  leading and trailing  ", "Text" ],
                (* Items *)
                Cell[ "First", "Item" ], Cell[ TextData @ { "An ", StyleBox[ "important", FontWeight -> "Bold" ], " item" }, "Item" ], Cell[ "Second", "Subitem" ], Cell[ "Third", "Subsubitem" ],
                (* Styles *)
                Cell[
                    TextData @ {
                        "x ", StyleBox[ "bold", FontWeight -> "Bold" ], " ", StyleBox[ "bold2", FontWeight -> Bold ], " ", StyleBox[ "italic", FontSlant -> "Italic" ], " ",
                        StyleBox[ "both", FontWeight -> "Bold", FontSlant -> "Italic" ], " ", StyleBox[ "struck", FontVariations -> { "StrikeThrough" -> True } ], " y"
                    },
                    "Text"
                ],
                Cell[
                    TextData @ {
                        StyleBox[ "under", FontVariations -> { "Underline" -> True } ], StyleBox[ "red", FontColor -> RGBColor[ 1, 0, 0 ] ], StyleBox[ "big", FontSize -> 24 ],
                        StyleBox[ "input", "Input" ], StyleBox[ "mono", "MR" ]
                    },
                    "Text"
                ],
                (* Inline code *)
                Cell[
                    TextData @ {
                        "a ", StyleBox[ "x", "TI" ], " b ", StyleBox[ "code", "InlineCode" ], " c ", Cell[ "f[x]", "InlineCode" ], " d ",
                        Cell[ BoxData @ ButtonBox[ "Plot", BaseStyle -> "Link", ButtonData -> "paclet:ref/Plot" ], "InlineFormula", FontFamily -> "Source Sans Pro" ], " e ",
                        Cell[ BoxData @ RowBox @ { "g", "[", "y", "]" }, "InlineFormula" ]
                    },
                    "Text"
                ],
                (* Inline boxes and formulas *)
                Cell[
                    TextData @ {
                        "bare ", Cell @ BoxData @ RowBox @ { SuperscriptBox[ "x", "2" ], "+", FractionBox[ "1", "2" ] }, " standard ",
                        Cell @ BoxData @ FormBox[ SuperscriptBox[ "x", "2" ], StandardForm ], " traditional ",
                        Cell @ BoxData @ FormBox[ RowBox @ { SuperscriptBox[ "x", "2" ], "+", FractionBox[ "1", "2" ] }, TraditionalForm ]
                    },
                    "Text"
                ],
                Cell[ TextData @ { "so ", formula[ "x^2" ], " and ", formula[ "\\lim_{x \\to 2} f(x) = 5" ], "." }, "Text" ],
                (* Links *)
                Cell[
                    TextData @ {
                        ButtonBox[ "Wolfram", BaseStyle -> "Hyperlink", ButtonData -> { URL[ "https://www.wolfram.com" ], None }, ButtonNote -> "https://www.wolfram.com" ], " ",
                        ButtonBox[ "Plot", BaseStyle -> "Link", ButtonData -> "paclet:ref/Plot" ], " ",
                        Cell @ BoxData @ TemplateBox[ { "site", "https://example.com/a" }, "HyperlinkURL" ], " ",
                        TemplateBox[ { "site", { URL[ "https://example.com/b" ], None }, "https://example.com/b", "HyperlinkActionRecycled", { "HyperlinkActive" }, BaseStyle -> { "Hyperlink" } }, "HyperlinkTemplate" ], " ",
                        Cell @ BoxData @ TemplateBox[ { "Sin", "paclet:ref/Sin", "https://reference.wolfram.com/language/ref/Sin.html" }, "TextRefLink" ]
                    },
                    "Text"
                ],
                (* Input *)
                Cell[ BoxData @ RowBox @ { "Plot", "[", RowBox @ { RowBox @ { "Sin", "[", "x", "]" }, ",", RowBox @ { "{", RowBox @ { "x", ",", "0", ",", RowBox @ { "2", " ", "Pi" } }, "}" } }, "]" }, "Input" ],
                Cell[ BoxData @ RowBox @ { "a", "\[Rule]", RowBox @ { "b", "\[LeftDoubleBracket]", "1", "\[RightDoubleBracket]" } }, "Input" ],
                Cell[ BoxData @ RowBox @ { "a", "->", RowBox @ { "b", "[", RowBox @ { "[", "1", "]" }, "]" } }, "Input" ],
                Cell[ BoxData @ RowBox @ { "\[LeftAssociation]", RowBox @ { "\"k\"", "\[Rule]", "1" }, "\[RightAssociation]" }, "Input" ],
                Cell[ BoxData @ RowBox @ { "<|", RowBox @ { "\"k\"", "->", "1" }, "|>" }, "Input" ],
                Cell[ BoxData @ RowBox @ { RowBox @ { RowBox @ { "x", "=", "1" }, ";" }, RowBox @ { "(*", " ", RowBox @ { "a", " ", "comment" }, " ", "*)" } }, "Input" ],
                Cell[ BoxData @ RowBox @ { "f", "[", "\[IndentingNewLine]", RowBox @ { "a", ",", "\[IndentingNewLine]", "b" }, "\[IndentingNewLine]", "]" }, "Input" ],
                Cell[ BoxData @ RowBox @ { "f", "[", "\n", "  ", RowBox @ { "a", ",", "\n", "  ", "b" }, "\n", "]" }, "Input" ],
                Cell[ BoxData @ { RowBox @ { "a", "=", "1" }, "\[IndentingNewLine]", RowBox @ { "b", "=", "2" } }, "Input" ],
                Cell[ BoxData @ RowBox @ { SuperscriptBox[ "x", "2" ], "+", FractionBox[ "1", "2" ], "+", SqrtBox[ "y" ], "+", RadicalBox[ "z", "3" ], "+", SubscriptBox[ "x", "1" ], "+", SubsuperscriptBox[ "x", "1", "2" ] }, "Input" ],
                Cell[ BoxData @ RowBox @ { "m", "=", RowBox @ { "(", "\[NoBreak]", GridBox[ { { "1", "2" }, { "3", "4" } } ], "\[NoBreak]", ")" } }, "Input" ],
                Cell[ BoxData @ RowBox @ { "s", "=", "\"a\\nb\\t\\\"c\\\"\"" }, "Input" ],
                Cell[ BoxData @ RowBox @ { "q", "=", TemplateBox[ { "5", "\"m\"", "meters", "\"Meters\"" }, "Quantity" ] }, "Input" ],
                Cell[ BoxData @ RowBox @ { "ColorNegate", "[", image, "]" }, "Input" ],
                Cell[ BoxData @ RowBox @ { "1", "+", "1" }, "Input", CellLabel -> "In[1]:=" ],
                Cell[ BoxData[ "" ], "Input" ],
                Cell[ BoxData[ "x" ], "Input" ],
                Cell[ "1+1", "Input" ],
                Cell[ BoxData @ RowBox @ { RowBox @ { "f", "[", "x_", "]" }, ":=", RowBox @ { "x", "^", "2" } }, "Code" ],
                Cell[ BoxData @ { RowBox @ { "a", "=", "1" }, "\n", RowBox @ { "b", "=", "2" } }, "Code", InitializationCell -> True ],
                (* Options *)
                Cell[ "x", "Text", CellTags -> "one" ], Cell[ "x", "Text", CellTags -> { "a", "b" } ],
                Cell[ "x", "Text", Background -> RGBColor[ 1, 0.9, 0.8 ], CellFrame -> True, TextAlignment -> Center, FontSize -> 14 ],
                Cell[ "x", "Text", TaggingRules -> <| "a" -> { 1, 2 } |>, CellOpen -> False ], Cell[ "x", "Text", "Extra" ],
                Cell[ "x", "Text", ExpressionUUID -> "5ec7a6f0-4a9d-4b62-8d0c-0d4f4a3c2b1a", CellChangeTimes -> { 3.9*^9 }, CellID -> 12 ],
                Cell[ "x", "Text", FontSize -> 1.5 Inherited, CellEventActions -> { "MouseClicked" :> Beep[ ] }, TaggingRules -> <| "long" -> StringRepeat[ "a", 300 ] |> ],
                (* Formulas *)
                Cell[ BoxData @ FormBox[ RowBox @ { SuperscriptBox[ "e", RowBox @ { "i", " ", "\[Pi]" } ], "+", "1", "=", "0" }, TraditionalForm ], "DisplayFormula" ],
                Cell[ BoxData @ FormBox[ RowBox @ { "a", "=", "b" }, TraditionalForm ], "DisplayFormulaNumbered" ],
                Cell[ BoxData @ SuperscriptBox[ "x", "2" ], "InlineFormula" ],
                (* Other languages and other content *)
                Cell[ "x = 1  # comment\n", "Program" ],
                Cell[ "echo \"</cell>\" <!attachment://content-abcde!>", "Program" ],
                Cell[ "bell " <> FromCharacterCode[ 7 ] <> " in text", "Text" ],
                Cell[ "print(1)", "ExternalLanguage", CellEvaluationLanguage -> "Python" ],
                Cell[ "", "Delimiter" ], Cell[ "\[HorizontalLine]", "PageBreak", PageBreakBelow -> True ],
                Cell[ "quoted text", "BlockQuote" ],
                Cell[ BoxData @ image, "Picture" ],
                Cell[ RawData[ "Cell[\"x\", \"Text\"]" ], "Text" ],
                Cell[ TextData @ { "A ", Cell @ BoxData @ GraphicsBox[ { DiskBox[ { 0, 0 } ] }, ImageSize -> 20 ], " graphic and \!\(\*SuperscriptBox[\(x\), \(2\)]\) in a string." }, "Text" ],
                (* Content that only an unchanged body gives back *)
                Cell[ BoxData @ RowBox @ { "f", "[", RowBox @ { "a", " ", ",", "  ", DynamicBox[ ToBoxes[ $csX ] ], ",", RowBox @ { "a", "x" } }, "]" }, "Input" ],
                Cell[ BoxData @ RowBox @ { SubsuperscriptBox[ "\[Integral]", "0", "\[Pi]" ], RowBox @ { RowBox @ { "Cos", "[", "x", "]" }, RowBox @ { "\[DifferentialD]", "x" } } }, "Input" ],
                Cell[ BoxData @ RowBox @ { RowBox @ { "a", "=", "1" }, "\[IndentingNewLine]", "   ", RowBox @ { "b", "=", "2" } }, "Input" ],
                Cell[ TextData @ { "a", "b ", StyleBox[ "c ", FontWeight -> "Bold" ], ButtonBox[ " d ", BaseStyle -> "Link", ButtonData -> "paclet:ref/Plot" ] }, "Text" ]
            },
            csRoundTrip[ #, Identity, False ] =!= # &
        ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "RoundTrip-Unchanged"
]

(* Written as a new cell without what reading recorded, markdown is new: it stands for the link, the formula and the
   inline code that the writer makes. Content that is not plain data is refused. *)
VerificationTest[
    With[ { new = Function[ cell, csStores @ Replace[ csCells @ StringReplace[ csExact @ cell, StartOfString ~~ "<cell id='c1'" -> "<cell" ], { c_Cell } :> c ] ] },
        {
            new @ Cell[
                TextData @ {
                    Cell @ BoxData @ TemplateBox[ { "site", "https://example.com/a" }, "HyperlinkURL" ], " ",
                    Cell @ BoxData @ FormBox[ SuperscriptBox[ "x", "2" ], TraditionalForm ], " ",
                    StyleBox[ "x", "TI" ]
                },
                "Text"
            ],
            new @ Cell[ RawData[ "Cell[\"x\", \"Text\"]" ], "Text" ]
        }
    ],
    {
        Cell[
            TextData @ {
                ButtonBox[ "site", BaseStyle -> "Hyperlink", ButtonData -> { URL[ "https://example.com/a" ], None }, ButtonNote -> "https://example.com/a" ], " ",
                Cell @ BoxData @ FormBox[ TemplateBox[ KeyValuePattern[ "input" -> "x^2" ], "TeXAssistantTemplate" ], TraditionalForm ], " ",
                Cell[ BoxData[ "x" ], "InlineCode" ]
            },
            "Text"
        ],
        _Failure
    },
    SameTest -> MatchQ,
    TestID   -> "RoundTrip-NewCells"
]

(* :!CodeAnalysis::EndBlock:: *)
