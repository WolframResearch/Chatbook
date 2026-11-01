(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/SelectContextCells.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/SelectContextCells.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    syntheticCellInfo[ cursors_List ] := MapIndexed[
        <| "CursorPosition" -> #1, "CellObject" -> CellObject[ First @ #2 ] |> &,
        cursors
    ];

    syntheticCellInfo[ n_Integer, rules___Rule ] :=
        syntheticCellInfo @ ReplacePart[ ConstantArray[ None, n ], { rules } ];

    selectIndices[ info_ ] := Block[
        {
            Wolfram`Chatbook`ChatModes`Context`Private`$maxCellsBeforeSelection = 100,
            Wolfram`Chatbook`ChatModes`Context`Private`$maxCellsAfterSelection  = 50
        },
        Replace[
            Wolfram`Chatbook`ChatModes`Context`Private`selectContextCells @ info,
            CellObject[ k_ ] :> k,
            { 2 }
        ]
    ];

    timedSelectIndices[ info_ ] := AbsoluteTiming @ selectIndices @ info,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions@@Tests/SelectContextCells.wlt:24,1-49,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cursor Positions*)
VerificationTest[
    selectIndices @ syntheticCellInfo[ 10, 1 -> "AboveCell" ],
    <| "Before" -> { }, "Selected" -> { }, "After" -> Range[ 2, 10 ] |>,
    SameTest -> MatchQ,
    TestID   -> "AboveFirstCell@@Tests/SelectContextCells.wlt:54,1-59,2"
]

VerificationTest[
    selectIndices @ syntheticCellInfo[ 10, 4 -> "BelowCell" ],
    <| "Before" -> Range[ 4 ], "Selected" -> { }, "After" -> Range[ 5, 10 ] |>,
    SameTest -> MatchQ,
    TestID   -> "BelowCell@@Tests/SelectContextCells.wlt:61,1-66,2"
]

VerificationTest[
    selectIndices @ syntheticCellInfo[ 10, 6 -> { 1, 3 } ],
    <| "Before" -> Range[ 5 ], "Selected" -> { 6 }, "After" -> Range[ 7, 10 ] |>,
    SameTest -> MatchQ,
    TestID   -> "CursorInCell@@Tests/SelectContextCells.wlt:68,1-73,2"
]

VerificationTest[
    selectIndices @ syntheticCellInfo[ 10, 3 -> "CellBracket", 4 -> "CellBracket", 5 -> "CellBracket" ],
    <| "Before" -> { 1, 2 }, "Selected" -> { 3, 4, 5 }, "After" -> Range[ 6, 10 ] |>,
    SameTest -> MatchQ,
    TestID   -> "CellBracketRun@@Tests/SelectContextCells.wlt:75,1-80,2"
]

VerificationTest[
    selectIndices @ syntheticCellInfo[ 10, 10 -> "CellBracket" ],
    <| "Before" -> Range[ 9 ], "Selected" -> { 10 }, "After" -> { } |>,
    SameTest -> MatchQ,
    TestID   -> "CellBracketLastCell@@Tests/SelectContextCells.wlt:82,1-87,2"
]

VerificationTest[
    selectIndices @ syntheticCellInfo[ 10 ],
    <| "Before" -> Range[ 10 ], "Selected" -> { }, "After" -> { } |>,
    SameTest -> MatchQ,
    TestID   -> "NoCursor@@Tests/SelectContextCells.wlt:89,1-94,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Large Notebooks*)
VerificationTest[
    timedSelectIndices @ syntheticCellInfo[ 3000, 1500 -> "CellBracket" ],
    {
        _Real? (# < 1 &),
        <| "Before" -> Range[ 1400, 1499 ], "Selected" -> { 1500 }, "After" -> Range[ 1501, 1550 ] |>
    },
    SameTest -> MatchQ,
    TestID   -> "LargeNotebookCellBracket@@Tests/SelectContextCells.wlt:99,1-107,2"
]

VerificationTest[
    timedSelectIndices @ syntheticCellInfo[ 3000 ],
    { _Real? (# < 1 &), <| "Before" -> Range[ 2901, 3000 ], "Selected" -> { }, "After" -> { } |> },
    SameTest -> MatchQ,
    TestID   -> "LargeNotebookNoCursor@@Tests/SelectContextCells.wlt:109,1-114,2"
]

VerificationTest[
    timedSelectIndices @ syntheticCellInfo[ 3000, 1500 -> { 1, 1 } ],
    {
        _Real? (# < 1 &),
        <| "Before" -> Range[ 1400, 1499 ], "Selected" -> { 1500 }, "After" -> Range[ 1501, 1550 ] |>
    },
    SameTest -> MatchQ,
    TestID   -> "LargeNotebookCursorInCell@@Tests/SelectContextCells.wlt:116,1-124,2"
]

(* :!CodeAnalysis::EndBlock:: *)
