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
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cursor Positions*)
VerificationTest[
    selectIndices @ syntheticCellInfo[ 10, 1 -> "AboveCell" ],
    <| "Before" -> { }, "Selected" -> { }, "After" -> Range[ 1, 10 ] |>,
    SameTest -> MatchQ,
    TestID   -> "AboveFirstCell"
]

VerificationTest[
    selectIndices @ syntheticCellInfo[ 10, 4 -> "BelowCell" ],
    <| "Before" -> Range[ 4 ], "Selected" -> { }, "After" -> Range[ 5, 10 ] |>,
    SameTest -> MatchQ,
    TestID   -> "BelowCell"
]

VerificationTest[
    selectIndices @ syntheticCellInfo[ 10, 6 -> { 1, 3 } ],
    <| "Before" -> Range[ 5 ], "Selected" -> { 6 }, "After" -> Range[ 7, 10 ] |>,
    SameTest -> MatchQ,
    TestID   -> "CursorInCell"
]

VerificationTest[
    selectIndices @ syntheticCellInfo[ 10, 3 -> "CellBracket", 4 -> "CellBracket", 5 -> "CellBracket" ],
    <| "Before" -> { 1, 2 }, "Selected" -> { 3, 4, 5 }, "After" -> Range[ 6, 10 ] |>,
    SameTest -> MatchQ,
    TestID   -> "CellBracketRun"
]

VerificationTest[
    selectIndices @ syntheticCellInfo[ 10, 10 -> "CellBracket" ],
    <| "Before" -> Range[ 9 ], "Selected" -> { 10 }, "After" -> { } |>,
    SameTest -> MatchQ,
    TestID   -> "CellBracketLastCell"
]

VerificationTest[
    selectIndices @ syntheticCellInfo[ 10 ],
    <| "Before" -> Range[ 10 ], "Selected" -> { }, "After" -> { } |>,
    SameTest -> MatchQ,
    TestID   -> "NoCursor"
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
    TestID   -> "LargeNotebookCellBracket"
]

VerificationTest[
    timedSelectIndices @ syntheticCellInfo[ 3000 ],
    { _Real? (# < 1 &), <| "Before" -> Range[ 2901, 3000 ], "Selected" -> { }, "After" -> { } |> },
    SameTest -> MatchQ,
    TestID   -> "LargeNotebookNoCursor"
]

VerificationTest[
    timedSelectIndices @ syntheticCellInfo[ 3000, 1500 -> { 1, 1 } ],
    {
        _Real? (# < 1 &),
        <| "Before" -> Range[ 1400, 1499 ], "Selected" -> { 1500 }, "After" -> Range[ 1501, 1550 ] |>
    },
    SameTest -> MatchQ,
    TestID   -> "LargeNotebookCursorInCell"
]

(* :!CodeAnalysis::EndBlock:: *)
