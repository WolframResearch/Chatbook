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
