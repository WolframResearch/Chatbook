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
        csTag, csBody
    ];

    (* Cells in cell tags, with lossy and with exact bodies *)
    csTag[ cell_, opts___ ]   := CellToString[ cell, "IncludeXML" -> True, opts ];

    (* The body of a single cell tag *)
    csBody[ tag_String ] := Replace[
        StringCases[
            tag,
            StartOfString ~~ "<cell" ~~ Except[ "\n" ]... ~~ ">\n" ~~ body___ ~~ "\n</cell>" ~~ EndOfString :> body
        ],
        { { body_ } :> body, _ :> $Failed }
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
(* ::Section::Closed:: *)
(*Bodies Without Decoration*)

(* What the tag says is not in the body, with lossy and with exact bodies: no heading marker, bullet, code fence or
   label, and nothing for a delimiter *)
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
