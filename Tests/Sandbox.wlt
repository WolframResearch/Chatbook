(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Sandbox.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Sandbox.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Default Sandbox Paths*)

(* AgentTools persists evaluator session state from the sandbox kernel to this directory: *)
VerificationTest[
    MemberQ[
        Wolfram`Chatbook`Sandbox`Private`$defaultWritePaths,
        FileNameJoin @ { $UserBaseDirectory, "ApplicationData", "Wolfram", "AgentTools" }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "DefaultWritePaths-AgentTools-GH#1595@@Tests/Sandbox.wlt:26,1-34,2"
]

VerificationTest[
    MemberQ[
        Wolfram`Chatbook`Sandbox`Private`makeWritePaths @ Automatic,
        FileNameJoin @ { $UserBaseDirectory, "ApplicationData", "Wolfram", "AgentTools" }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MakeWritePaths-Automatic-AgentTools-GH#1595@@Tests/Sandbox.wlt:36,1-44,2"
]

(* Session files are read back via Get, which relies on read access to all of ApplicationData. *)
(* Initializing $defaultReadPaths mentions the front end, which is not available when running tests: *)
VerificationTest[
    Quiet[
        MemberQ[
            Wolfram`Chatbook`Sandbox`Private`$defaultReadPaths,
            FileNameJoin @ { $UserBaseDirectory, "ApplicationData" }
        ],
        FrontEndObject::notavail
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "DefaultReadPaths-ApplicationData-GH#1595@@Tests/Sandbox.wlt:48,1-59,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Input Segments*)
VerificationTest[
    Lookup[
        Wolfram`Chatbook`Sandbox`Private`toSandboxSegments[ "a = 1;\nb\n\n(* comment *)\nc;\nf[x_] :=\n    x + 1\n" ][ "Segments" ],
        "Input"
    ],
    { "a = 1;", "b", "c;", "f[x_] :=\n    x + 1" },
    SameTest -> MatchQ,
    TestID   -> "InputSegments-Split@@Tests/Sandbox.wlt:64,1-72,2"
]

VerificationTest[
    Lookup[ Wolfram`Chatbook`Sandbox`Private`toSandboxSegments[ "(* comment *)" ][ "Segments" ], "Input" ],
    { HoldComplete[ Null ] },
    SameTest -> MatchQ,
    TestID   -> "InputSegments-OnlyComments@@Tests/Sandbox.wlt:74,1-79,2"
]

(* Input with an unfixable syntax error is kept together so the evaluator can report it: *)
VerificationTest[
    Lookup[ Wolfram`Chatbook`Sandbox`Private`toSandboxSegments[ "1 + 1\n2 + " ][ "Segments" ], "Input" ],
    { "1 + 1\n2 + " },
    SameTest -> MatchQ,
    TestID   -> "InputSegments-SyntaxError@@Tests/Sandbox.wlt:82,1-87,2"
]

(* Splitting input does not create any symbols: *)
VerificationTest[
    Wolfram`Chatbook`Sandbox`Private`toSandboxSegments[ "segmentTestSymbol1 = 1\nsegmentTestSymbol2[segmentTestSymbol3_]" ];
    Names[ "*`segmentTestSymbol*" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "InputSegments-NoSymbols@@Tests/Sandbox.wlt:90,1-96,2"
]

VerificationTest[
    Wolfram`Chatbook`Sandbox`Private`toSandboxSegments[ "InlinedExpression[\"attachment://missing\"] + 1" ][ "Segments" ],
    {
        KeyValuePattern @ {
            "Input"         -> _String? (StringMatchQ[ "\"Wolfram`Chatbook`Sandbox`Macro`" ~~ __ ~~ "\" + 1" ]),
            "InputString"   -> "InlinedExpression[\"attachment://missing\"] + 1",
            "MacroKeys"     -> { _String },
            "MacroValues"   -> HoldComplete[ _Failure ],
            "MacroMessages" -> { _String? (StringStartsQ[ "[ERROR]" ]) }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "InputSegments-Macros@@Tests/Sandbox.wlt:98,1-111,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Repairs*)
VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "Dimensions[{{1,2},{3,4},{5,6}}" ],
    "Dimensions[{{1,2},{3,4},{5,6}}]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-MissingClosers@@Tests/Sandbox.wlt:116,1-121,2"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "Plot[Sin[x], {x, 0, Pi" ],
    "Plot[Sin[x], {x, 0, Pi}]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-MissingMixedClosers@@Tests/Sandbox.wlt:123,1-128,2"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "x = {1, 2, 3\nTotal[x]" ],
    "x = {1, 2, 3}\nTotal[x]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-MissingClosersEndOfLine@@Tests/Sandbox.wlt:130,1-135,2"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "Table[i^2,\n  {i, 10}\nTotal[%]" ],
    "Table[i^2,\n  {i, 10}]\nTotal[%]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-MissingClosersMultiline@@Tests/Sandbox.wlt:137,1-142,2"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "Module[{a = 1},\n  a + 1" ],
    "Module[{a = 1},\n  a + 1]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-MissingClosersEnd@@Tests/Sandbox.wlt:144,1-149,2"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "<|\"a\" -> 1" ],
    "<|\"a\" -> 1|>",
    SameTest -> MatchQ,
    TestID   -> "Repairs-MissingAssociationCloser@@Tests/Sandbox.wlt:151,1-156,2"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "{\"]\", 1" ],
    "{\"]\", 1}",
    SameTest -> MatchQ,
    TestID   -> "Repairs-ClosersInStrings@@Tests/Sandbox.wlt:158,1-163,2"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "f[{1,2]" ],
    "f[{1,2}]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-MismatchedClosers@@Tests/Sandbox.wlt:165,1-170,2"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "Print['hi'" ],
    "Print[\"hi\"]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-SingleQuotes@@Tests/Sandbox.wlt:172,1-177,2"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "// a comment\nx = 1" ],
    "(*a comment*)\nx = 1",
    SameTest -> MatchQ,
    TestID   -> "Repairs-LineComments@@Tests/Sandbox.wlt:179,1-184,2"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "f[1,]" ],
    "f[1,]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-ImplicitNull@@Tests/Sandbox.wlt:186,1-191,2"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "1 +" ],
    "1 +",
    SameTest -> MatchQ,
    TestID   -> "Repairs-Unfixable@@Tests/Sandbox.wlt:193,1-198,2"
]

(* :!CodeAnalysis::EndBlock:: *)
