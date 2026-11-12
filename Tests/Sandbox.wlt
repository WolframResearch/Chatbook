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
(*Default Sandbox Paths*)

(* AgentTools persists evaluator session state from the sandbox kernel to this directory: *)
VerificationTest[
    MemberQ[
        Wolfram`Chatbook`Sandbox`Private`$defaultWritePaths,
        FileNameJoin @ { $UserBaseDirectory, "ApplicationData", "Wolfram", "AgentTools" }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "DefaultWritePaths-AgentTools-GH#1595"
]

VerificationTest[
    MemberQ[
        Wolfram`Chatbook`Sandbox`Private`makeWritePaths @ Automatic,
        FileNameJoin @ { $UserBaseDirectory, "ApplicationData", "Wolfram", "AgentTools" }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MakeWritePaths-Automatic-AgentTools-GH#1595"
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
    TestID   -> "DefaultReadPaths-ApplicationData-GH#1595"
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
    TestID   -> "InputSegments-Split"
]

VerificationTest[
    Lookup[ Wolfram`Chatbook`Sandbox`Private`toSandboxSegments[ "(* comment *)" ][ "Segments" ], "Input" ],
    { HoldComplete[ Null ] },
    SameTest -> MatchQ,
    TestID   -> "InputSegments-OnlyComments"
]

(* Input with an unfixable syntax error is kept together so the evaluator can report it: *)
VerificationTest[
    Lookup[ Wolfram`Chatbook`Sandbox`Private`toSandboxSegments[ "1 + 1\n2 + " ][ "Segments" ], "Input" ],
    { "1 + 1\n2 + " },
    SameTest -> MatchQ,
    TestID   -> "InputSegments-SyntaxError"
]

(* Splitting input does not create any symbols: *)
VerificationTest[
    Wolfram`Chatbook`Sandbox`Private`toSandboxSegments[ "segmentTestSymbol1 = 1\nsegmentTestSymbol2[segmentTestSymbol3_]" ];
    Names[ "*`segmentTestSymbol*" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "InputSegments-NoSymbols"
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
    TestID   -> "InputSegments-Macros"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Repairs*)
VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "Dimensions[{{1,2},{3,4},{5,6}}" ],
    "Dimensions[{{1,2},{3,4},{5,6}}]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-MissingClosers"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "Plot[Sin[x], {x, 0, Pi" ],
    "Plot[Sin[x], {x, 0, Pi}]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-MissingMixedClosers"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "x = {1, 2, 3\nTotal[x]" ],
    "x = {1, 2, 3}\nTotal[x]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-MissingClosersEndOfLine"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "Table[i^2,\n  {i, 10}\nTotal[%]" ],
    "Table[i^2,\n  {i, 10}]\nTotal[%]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-MissingClosersMultiline"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "Module[{a = 1},\n  a + 1" ],
    "Module[{a = 1},\n  a + 1]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-MissingClosersEnd"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "<|\"a\" -> 1" ],
    "<|\"a\" -> 1|>",
    SameTest -> MatchQ,
    TestID   -> "Repairs-MissingAssociationCloser"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "{\"]\", 1" ],
    "{\"]\", 1}",
    SameTest -> MatchQ,
    TestID   -> "Repairs-ClosersInStrings"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "f[{1,2]" ],
    "f[{1,2}]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-MismatchedClosers"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "Print['hi'" ],
    "Print[\"hi\"]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-SingleQuotes"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "// a comment\nx = 1" ],
    "(*a comment*)\nx = 1",
    SameTest -> MatchQ,
    TestID   -> "Repairs-LineComments"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "f[1,]" ],
    "f[1,]",
    SameTest -> MatchQ,
    TestID   -> "Repairs-ImplicitNull"
]

VerificationTest[
    First @ Wolfram`Chatbook`Sandbox`Private`repairSandboxCode[ "1 +" ],
    "1 +",
    SameTest -> MatchQ,
    TestID   -> "Repairs-Unfixable"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Kernel Startup Failures*)

(* A command line for a process that never connects to the link. On Windows, LinkLaunch asks the user to pick a
   program when the executable doesn't exist, so use a command that exits immediately instead: *)
$neverConnectsCommandLine = If[ $OperatingSystem === "Windows", "cmd.exe /c exit", "/nonexistent/WolframKernel -wstp" ];

(* A process that never connects to the link blocks LinkWrite indefinitely: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$sandboxKernelCommandLine = $neverConnectsCommandLine,
            Wolfram`Chatbook`Sandbox`Private`$sandboxPingTimeout = 1
        },
        Quiet @ Wolfram`Chatbook`Sandbox`Private`startSandboxKernel[ ]
    ],
    Failure[ "NoSandboxKernel", _ ],
    SameTest       -> MatchQ,
    TimeConstraint -> 30,
    TestID         -> "StartSandboxKernel-NeverConnects-GH#855"
]

(* A kernel that exits after connecting closes the link, so there's no need to wait for the time limit: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$sandboxKernelCommandLine = StringReplace[
                Wolfram`Chatbook`Common`$sandboxKernelCommandLine,
                "ChatbookSandbox" ~~ DigitCharacter.. -> "\"Quit[]\""
            ],
            Wolfram`Chatbook`Sandbox`Private`$sandboxPingTimeout = 120
        },
        Quiet @ AbsoluteTiming @ Wolfram`Chatbook`Sandbox`Private`startSandboxKernel[ ]
    ],
    { _? (LessThan[ 60 ]), Failure[ "NoSandboxKernel", _ ] },
    SameTest -> MatchQ,
    TestID   -> "StartSandboxKernel-KernelExits-GH#855"
]

(* A kernel that does not respond in time: *)
VerificationTest[
    Block[
        { Wolfram`Chatbook`Sandbox`Private`$sandboxPingTimeout = 0.01 },
        Quiet @ Wolfram`Chatbook`Sandbox`Private`startSandboxKernel[ ]
    ],
    Failure[ "NoSandboxKernel", _ ],
    SameTest -> MatchQ,
    TestID   -> "StartSandboxKernel-TimedOut-GH#855"
]

(* The evaluator reports the failure to the model as its result, instead of throwing an internal failure: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$sandboxKernelCommandLine = $neverConnectsCommandLine,
            Wolfram`Chatbook`Sandbox`Private`$sandboxPingTimeout = 1
        },
        Quiet @ Wolfram`Chatbook`WolframLanguageToolEvaluate[ "1 + 1", All, "Method" -> "Local" ]
    ],
    KeyValuePattern @ {
        "String" -> _String? (StringStartsQ[ "Unable to start a sandbox kernel" ]),
        "Result" -> HoldCompleteForm @ Failure[ "NoSandboxKernel", _ ]
    },
    SameTest       -> MatchQ,
    TimeConstraint -> 30,
    TestID         -> "ToolResult-NoSandboxKernel-GH#855"
]

(* :!CodeAnalysis::EndBlock:: *)
