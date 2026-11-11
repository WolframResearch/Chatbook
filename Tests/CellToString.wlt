(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/CellToString.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/CellToString.wlt:11,1-16,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FractionBox*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Compound Terms*)
VerificationTest[
    CellToString @ FractionBox[ "1", RowBox @ { "2", "+", "3" } ],
    "(1/(2 + 3))",
    SameTest -> MatchQ,
    TestID   -> "FractionBox-CompoundDenominator@@Tests/CellToString.wlt:25,1-30,2"
]

VerificationTest[
    CellToString @ FractionBox[ RowBox @ { "1", "+", "2" }, "3" ],
    "((1 + 2)/3)",
    SameTest -> MatchQ,
    TestID   -> "FractionBox-CompoundNumerator@@Tests/CellToString.wlt:32,1-37,2"
]

VerificationTest[
    CellToString @ FractionBox[ "1", RowBox @ { "2", " ", "x" } ],
    "(1/(2 x))",
    SameTest -> MatchQ,
    TestID   -> "FractionBox-ImplicitTimesDenominator@@Tests/CellToString.wlt:39,1-44,2"
]

VerificationTest[
    CellToString @ FractionBox[ "1", TagBox[ RowBox @ { "2", "+", "3" }, HoldForm ] ],
    "(1/(2 + 3))",
    SameTest -> MatchQ,
    TestID   -> "FractionBox-WrappedCompoundDenominator@@Tests/CellToString.wlt:46,1-51,2"
]

VerificationTest[
    CellToString @ Cell[ BoxData @ FractionBox[ "1", RowBox @ { "2", "+", "3" } ], "Input" ],
    "```wl\n(1/(2 + 3))\n```",
    SameTest -> MatchQ,
    TestID   -> "FractionBox-InputCell@@Tests/CellToString.wlt:53,1-58,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Single Terms*)
VerificationTest[
    CellToString @ FractionBox[ "a", "b" ],
    "(a/b)",
    SameTest -> MatchQ,
    TestID   -> "FractionBox-Strings@@Tests/CellToString.wlt:63,1-68,2"
]

VerificationTest[
    CellToString @ FractionBox[ "1", RowBox @ { "(", RowBox @ { "2", "+", "3" }, ")" } ],
    "(1/(2 + 3))",
    SameTest -> MatchQ,
    TestID   -> "FractionBox-AlreadyParenthesized@@Tests/CellToString.wlt:70,1-75,2"
]

VerificationTest[
    CellToString @ FractionBox[ RowBox @ { "f", "[", "x", "]" }, RowBox @ { "g", "[", RowBox @ { "x", ",", "y" }, "]" } ],
    "(f[x]/g[x, y])",
    SameTest -> MatchQ,
    TestID   -> "FractionBox-FunctionApplication@@Tests/CellToString.wlt:77,1-82,2"
]

VerificationTest[
    CellToString @ FractionBox[ SuperscriptBox[ "x", "2" ], SqrtBox[ "y" ] ],
    "(x^2/Sqrt[y])",
    SameTest -> MatchQ,
    TestID   -> "FractionBox-MathBoxes@@Tests/CellToString.wlt:84,1-89,2"
]

VerificationTest[
    CellToString @ FractionBox[ FractionBox[ "1", "2" ], FractionBox[ "3", "4" ] ],
    "((1/2)/(3/4))",
    SameTest -> MatchQ,
    TestID   -> "FractionBox-Nested@@Tests/CellToString.wlt:91,1-96,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Value*)
VerificationTest[
    ToExpression[
        CellToString @ FractionBox[ RowBox @ { "1", "+", "2" }, RowBox @ { "2", " ", RowBox @ { "(", RowBox @ { "3", "+", "4" }, ")" } } ],
        InputForm
    ],
    ToExpression @ FractionBox[ RowBox @ { "1", "+", "2" }, RowBox @ { "2", " ", RowBox @ { "(", RowBox @ { "3", "+", "4" }, ")" } } ],
    SameTest -> MatchQ,
    TestID   -> "FractionBox-PreservesValue@@Tests/CellToString.wlt:101,1-109,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Scripts and Radicals*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Exponents*)
VerificationTest[
    CellToString @ SuperscriptBox[ "x", RowBox @ { "a", "+", "b" } ],
    "x^(a + b)",
    SameTest -> MatchQ,
    TestID   -> "SuperscriptBox-CompoundExponent-GH#1807@@Tests/CellToString.wlt:118,1-123,2"
]

VerificationTest[
    CellToString @ SuperscriptBox[ "x", RowBox @ { "a", " ", "b" } ],
    "x^(a b)",
    SameTest -> MatchQ,
    TestID   -> "SuperscriptBox-ImplicitTimesExponent-GH#1807@@Tests/CellToString.wlt:125,1-130,2"
]

VerificationTest[
    CellToString @ SuperscriptBox[ "x", TagBox[ RowBox @ { "a", "+", "b" }, HoldForm ] ],
    "x^(a + b)",
    SameTest -> MatchQ,
    TestID   -> "SuperscriptBox-WrappedCompoundExponent-GH#1807@@Tests/CellToString.wlt:132,1-137,2"
]

VerificationTest[
    CellToString @ FractionBox[ "1", SuperscriptBox[ "x", RowBox @ { "a", "+", "b" } ] ],
    "(1/x^(a + b))",
    SameTest -> MatchQ,
    TestID   -> "SuperscriptBox-CompoundExponentInFraction-GH#1807@@Tests/CellToString.wlt:139,1-144,2"
]

VerificationTest[
    CellToString @ SuperscriptBox[ "x", RowBox @ { "(", RowBox @ { "a", "+", "b" }, ")" } ],
    "x^(a + b)",
    SameTest -> MatchQ,
    TestID   -> "SuperscriptBox-AlreadyParenthesizedExponent-GH#1807@@Tests/CellToString.wlt:146,1-151,2"
]

VerificationTest[
    CellToString /@ {
        SuperscriptBox[ "x", "2" ],
        SuperscriptBox[ "x", SuperscriptBox[ "y", "z" ] ],
        SuperscriptBox[ "x", RowBox @ { "f", "[", "y", "]" } ],
        SuperscriptBox[ "x", SqrtBox[ "y" ] ],
        SuperscriptBox[ "x", TagBox[ "2", HoldForm ] ]
    },
    { "x^2", "x^y^z", "x^f[y]", "x^Sqrt[y]", "x^2" },
    SameTest -> MatchQ,
    TestID   -> "SuperscriptBox-SingleTermExponents-GH#1807@@Tests/CellToString.wlt:153,1-164,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Bases*)
VerificationTest[
    CellToString @ SuperscriptBox[ RowBox @ { "a", "+", "b" }, "2" ],
    "(a + b)^2",
    SameTest -> MatchQ,
    TestID   -> "SuperscriptBox-CompoundBase-GH#1807@@Tests/CellToString.wlt:169,1-174,2"
]

VerificationTest[
    CellToString @ SuperscriptBox[ RowBox @ { "-", "1" }, "2" ],
    "(-1)^2",
    SameTest -> MatchQ,
    TestID   -> "SuperscriptBox-NegativeBase-GH#1807@@Tests/CellToString.wlt:176,1-181,2"
]

VerificationTest[
    CellToString @ SuperscriptBox[ SuperscriptBox[ "x", "y" ], "z" ],
    "(x^y)^z",
    SameTest -> MatchQ,
    TestID   -> "SuperscriptBox-PowerBase-GH#1807@@Tests/CellToString.wlt:183,1-188,2"
]

VerificationTest[
    CellToString @ SuperscriptBox[ TagBox[ SuperscriptBox[ "x", "y" ], HoldForm ], "z" ],
    "(x^y)^z",
    SameTest -> MatchQ,
    TestID   -> "SuperscriptBox-WrappedPowerBase-GH#1807@@Tests/CellToString.wlt:190,1-195,2"
]

VerificationTest[
    CellToString /@ {
        SuperscriptBox[ SqrtBox[ "y" ], "2" ],
        SuperscriptBox[ FractionBox[ "a", "b" ], "2" ],
        SuperscriptBox[ RowBox @ { "f", "[", "x", "]" }, "2" ],
        SuperscriptBox[ SubscriptBox[ "x", "1" ], "2" ]
    },
    { "Sqrt[y]^2", "(a/b)^2", "f[x]^2", "Subscript[x, 1]^2" },
    SameTest -> MatchQ,
    TestID   -> "SuperscriptBox-SingleTermBases-GH#1807@@Tests/CellToString.wlt:197,1-207,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Radicals*)
VerificationTest[
    CellToString @ RadicalBox[ RowBox @ { "a", "+", "b" }, "3" ],
    "(a + b)^(1/(3))",
    SameTest -> MatchQ,
    TestID   -> "RadicalBox-CompoundRadicand-GH#1807@@Tests/CellToString.wlt:212,1-217,2"
]

VerificationTest[
    CellToString @ RadicalBox[ SuperscriptBox[ "x", "2" ], "3" ],
    "(x^2)^(1/(3))",
    SameTest -> MatchQ,
    TestID   -> "RadicalBox-PowerRadicand-GH#1807@@Tests/CellToString.wlt:219,1-224,2"
]

VerificationTest[
    CellToString @ RadicalBox[ "x", "3" ],
    "x^(1/(3))",
    SameTest -> MatchQ,
    TestID   -> "RadicalBox-SingleTermRadicand-GH#1807@@Tests/CellToString.wlt:226,1-231,2"
]

VerificationTest[
    CellToString @ RadicalBox[ RowBox @ { "a", "+", "b" }, "3", SurdForm -> True ],
    "Surd[a + b, 3]",
    SameTest -> MatchQ,
    TestID   -> "RadicalBox-SurdForm-GH#1807@@Tests/CellToString.wlt:233,1-238,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Inline Scripts*)

(* Table cells are serialized as inline code. A grid needs at least two rows and columns to stay a table. *)
VerificationTest[
    tableCell[ box_ ] := StringTrim @ StringSplit[ StringSplit[ CellToString @ GridBox @ { { box, "h" }, { "c", "d" } }, "\n" ][[ 3 ]], "|" ][[ 1 ]],
    Null,
    SameTest -> MatchQ,
    TestID   -> "DefineTableCell@@Tests/CellToString.wlt:245,1-250,2"
]

VerificationTest[
    tableCell @ SubscriptBox[ "x", RowBox @ { "a", "+", "b" } ],
    "Subscript[x, a + b]",
    SameTest -> MatchQ,
    TestID   -> "SubscriptBox-InlineCompoundSubscript-GH#1807@@Tests/CellToString.wlt:252,1-257,2"
]

VerificationTest[
    tableCell @ SubscriptBox[ RowBox @ { "a", "+", "b" }, "1" ],
    "Subscript[a + b, 1]",
    SameTest -> MatchQ,
    TestID   -> "SubscriptBox-InlineCompoundBase-GH#1807@@Tests/CellToString.wlt:259,1-264,2"
]

VerificationTest[
    tableCell @ SubsuperscriptBox[ "x", RowBox @ { "a", "+", "b" }, "2" ],
    "Subsuperscript[x, a + b, 2]",
    SameTest -> MatchQ,
    TestID   -> "SubsuperscriptBox-InlineCompoundSubscript-GH#1807@@Tests/CellToString.wlt:266,1-271,2"
]

VerificationTest[
    tableCell /@ {
        SubscriptBox[ "x", "1" ],
        SubscriptBox[ StyleBox[ "x", "TI" ], StyleBox[ "i", "TI" ] ],
        SubsuperscriptBox[ "x", "i", "2" ]
    },
    { "x1", "xi", "xi2" },
    SameTest -> MatchQ,
    TestID   -> "ScriptBoxes-InlineTokensConcatenate-GH#1807@@Tests/CellToString.wlt:273,1-282,2"
]

VerificationTest[
    tableCell @ SubscriptBox[
        StyleBox[ "f", "TI" ],
        StyleBox[ RowBox @ { StyleBox[ "1", "TR" ], StyleBox[ "n", "TI" ] }, ZeroWidthTimes -> True ]
    ],
    "f1n",
    SameTest -> MatchQ,
    TestID   -> "SubscriptBox-InlineMultiIndex-GH#1807@@Tests/CellToString.wlt:284,1-292,2"
]

VerificationTest[
    tableCell /@ { SubscriptBox[ "x", RowBox @ { "i", ",", "j" } ], SubscriptBox[ "x", RowBox @ { "a", " ", "b" } ] },
    { "Subscript[x, i, j]", "Subscript[x, a b]" },
    SameTest -> MatchQ,
    TestID   -> "SubscriptBox-InlineRowsWithOperators-GH#1807@@Tests/CellToString.wlt:294,1-299,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Documentation Styles*)
VerificationTest[
    CellToString @ SuperscriptBox[ StyleBox[ "x", "TI" ], StyleBox[ "n", "TI" ] ],
    "``x``^``n``",
    SameTest -> MatchQ,
    TestID   -> "SuperscriptBox-StyledTermsNotParenthesized-GH#1807@@Tests/CellToString.wlt:304,1-309,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Value*)
VerificationTest[
    Select[
        {
            SuperscriptBox[ "2", RowBox @ { "3", "+", "5" } ],
            SuperscriptBox[ "2", RowBox @ { "3", " ", "5" } ],
            SuperscriptBox[ "2", SuperscriptBox[ "3", "2" ] ],
            SuperscriptBox[ SuperscriptBox[ "2", "3" ], "2" ],
            SuperscriptBox[ RowBox @ { "3", "+", "5" }, "2" ],
            SuperscriptBox[ RowBox @ { "-", "3" }, "2" ],
            RadicalBox[ RowBox @ { "3", "+", "5" }, "3" ],
            RadicalBox[ SuperscriptBox[ "2", "3" ], "3" ],
            FractionBox[ "1", SuperscriptBox[ "2", RowBox @ { "1", "+", "2" } ] ]
        },
        ToExpression[ CellToString @ #, InputForm ] =!= ToExpression[ #, StandardForm ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ScriptBoxes-PreserveValue-GH#1807@@Tests/CellToString.wlt:314,1-332,2"
]
