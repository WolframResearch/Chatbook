(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/CodeCheck.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`CodeCheck`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/CodeCheck.wlt:11,1-16,2"
]

VerificationTest[
    Context @ CodeCheckFix,
    "Wolfram`Chatbook`CodeCheck`",
    SameTest -> MatchQ,
    TestID   -> "CodeCheckFix-Context@@Tests/CodeCheck.wlt:18,1-23,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CodeCheckFix*)

(*cSpell: disable*)

VerificationTest[
    CodeCheckFix[ "f1[x,y,(*comment*)]" ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "CodeInspector" -> <|
            "InitialState" -> Inherited,
            "FinalState" -> <|
                "InspectionObjects" -> {
                    CodeInspector`InspectionObject[
                        "Comma",
                        "Extra ``,``.",
                        "Error",
                        <|
                            CodeParser`Source -> { 19, 18 },
                            ConfidenceLevel -> 1.,
                            CodeParser`CodeActions -> {
                                CodeParser`CodeAction[
                                    "Delete ``,``",
                                    CodeParser`DeleteText,
                                    <|
                                        CodeParser`Source ->
                                            CodeInspector`ConcreteRules`Private`prevSrc[ { 19, 18 } ]
                                    |>
                                ]
                            }
                        |>
                    ]
                },
                "OverallSeverity" -> 3
            |>
        |>,
        "OriginalCode" -> "f1[x,y,(*comment*)]",
        "FixedCode" -> Missing[ "Comma: No need to fix" ]
    |>,
    TestID -> "1_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[
        "\n(* Define your function *)\n\tf[k_] := Module[{...}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n"
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "CodeInspector" -> <|
            "InitialState" -> Inherited,
            "FinalState" -> <|
                "InspectionObjects" -> {
                    CodeInspector`InspectionObject[
                        "ExpectedOperand",
                        "Expected an operand.",
                        "Fatal",
                        <|
                            CodeParser`Source -> { 47, 46 },
                            ConfidenceLevel -> 1.
                        |>
                    ],
                    CodeInspector`InspectionObject[
                        "ExpectedOperand",
                        "Expected an operand.",
                        "Fatal",
                        <|
                            CodeParser`Source -> { 53, 52 },
                            ConfidenceLevel -> 1.
                        |>
                    ]
                },
                "OverallSeverity" -> 4
            |>
        |>,
        "OriginalCode" -> "\n(* Define your function *)\n\tf[k_] := Module[{...}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n",
        "FixedCode" -> Missing[ "No fix needed" ]
    |>,
    TestID -> "2_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "k[,(* 111 *)];" ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "CodeInspector" -> <|
            "InitialState" -> <|
                "InspectionObjects" -> {
                    CodeInspector`InspectionObject[
                        "Comma",
                        "Extra ``,``.",
                        "Error",
                        <|
                            CodeParser`Source -> { 3, 2 },
                            ConfidenceLevel -> 1.,
                            CodeParser`CodeActions -> {
                                CodeParser`CodeAction[
                                    "Delete ``,``",
                                    CodeParser`DeleteText,
                                    <|
                                        CodeParser`Source ->
                                            CodeInspector`ConcreteRules`Private`nextSrc[ { 3, 2 } ]
                                    |>
                                ]
                            }
                        |>
                    ],
                    CodeInspector`InspectionObject[
                        "Comma",
                        "Extra ``,``.",
                        "Error",
                        <|
                            CodeParser`Source -> { 13, 12 },
                            ConfidenceLevel -> 1.,
                            CodeParser`CodeActions -> {
                                CodeParser`CodeAction[
                                    "Delete ``,``",
                                    CodeParser`DeleteText,
                                    <|
                                        CodeParser`Source ->
                                            CodeInspector`ConcreteRules`Private`prevSrc[ { 13, 12 } ]
                                    |>
                                ]
                            }
                        |>
                    ]
                },
                "OverallSeverity" -> 3
            |>,
            "FinalState" -> <|
                "InspectionObjects" -> { },
                "OverallSeverity" -> None
            |>
        |>,
        "OriginalCode" -> "k[,(* 111 *)];",
        "FixedCode" -> "k[(* 111 *)];"
    |>,
    TestID -> "3_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "k[,....(* 111 *)];" ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> False,
        "Failure" -> Missing[ "Expected Operand (no place holder(s) detected)" ],
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "CodeInspector" -> <|
            "InitialState" -> <|
                "InspectionObjects" -> {
                    CodeInspector`InspectionObject[
                        "ExpectedOperand",
                        "Expected an operand.",
                        "Fatal",
                        <|
                            CodeParser`Source -> { 4, 3 },
                            ConfidenceLevel -> 1.
                        |>
                    ],
                    CodeInspector`InspectionObject[
                        "ExpectedOperand",
                        "Expected an operand.",
                        "Fatal",
                        <|
                            CodeParser`Source -> { 17, 16 },
                            ConfidenceLevel -> 1.
                        |>
                    ],
                    CodeInspector`InspectionObject[
                        "Comma",
                        "Extra ``,``.",
                        "Error",
                        <|
                            CodeParser`Source -> { 3, 2 },
                            ConfidenceLevel -> 1.,
                            CodeParser`CodeActions -> {
                                CodeParser`CodeAction[
                                    "Delete ``,``",
                                    CodeParser`DeleteText,
                                    <|
                                        CodeParser`Source ->
                                            CodeInspector`ConcreteRules`Private`nextSrc[ { 3, 2 } ]
                                    |>
                                ]
                            }
                        |>
                    ]
                },
                "OverallSeverity" -> 4
            |>,
            "FinalState" -> <|
                "InspectionObjects" -> {
                    CodeInspector`InspectionObject[
                        "ExpectedOperand",
                        "Expected an operand.",
                        "Fatal",
                        <|
                            CodeParser`Source -> { 3, 2 },
                            ConfidenceLevel -> 1.
                        |>
                    ],
                    CodeInspector`InspectionObject[
                        "ExpectedOperand",
                        "Expected an operand.",
                        "Fatal",
                        <|
                            CodeParser`Source -> { 16, 15 },
                            ConfidenceLevel -> 1.
                        |>
                    ]
                },
                "OverallSeverity" -> 4
            |>
        |>,
        "OriginalCode" -> "k[,....(* 111 *)];",
        "FixedCode" -> "k[....(* 111 *)];"
    |>,
    TestID -> "4_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "g[f[{{3,4}}},h[}]" ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 2,
        "LikelyFalsePositive" -> False,
        "CodeInspector" -> <|
            "InitialState" -> <|
                "InspectionObjects" -> {
                    CodeInspector`InspectionObject[
                        "GroupMissingCloser",
                        "Missing closer.",
                        "Fatal",
                        <|
                            CodeParser`Source -> { 2, 2 },
                            ConfidenceLevel -> 1.
                        |>
                    ],
                    CodeInspector`InspectionObject[
                        "UnexpectedCloser",
                        "Unexpected closer.",
                        "Fatal",
                        <|
                            CodeParser`Source -> { 12, 12 },
                            ConfidenceLevel -> 1.
                        |>
                    ],
                    CodeInspector`InspectionObject[
                        "UnexpectedCloser",
                        "Unexpected closer.",
                        "Fatal",
                        <|
                            CodeParser`Source -> { 16, 16 },
                            ConfidenceLevel -> 1.
                        |>
                    ],
                    CodeInspector`InspectionObject[
                        "Comma",
                        "Extra ``,``.",
                        "Error",
                        <|
                            CodeParser`Source -> { 13, 12 },
                            ConfidenceLevel -> 1.,
                            CodeParser`CodeActions -> {
                                CodeParser`CodeAction[
                                    "Delete ``,``",
                                    CodeParser`DeleteText,
                                    <|
                                        CodeParser`Source ->
                                            CodeInspector`ConcreteRules`Private`nextSrc[ { 13, 12 } ]
                                    |>
                                ]
                            }
                        |>
                    ]
                },
                "OverallSeverity" -> 4
            |>,
            "FinalState" -> <|
                "InspectionObjects" -> { },
                "OverallSeverity" -> None
            |>
        |>,
        "OriginalCode" -> "g[f[{{3,4}}},h[}]",
        "FixedCode" -> "g[f[{{3,4}}],h[]]"
    |>,
    TestID -> "5_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "f[{{3}}}}", "Target" -> "Evaluator" ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 2,
        "LikelyFalsePositive" -> False,
        "CodeInspector" -> <|
            "InitialState" -> <|
                "InspectionObjects" -> {
                    CodeInspector`InspectionObject[
                        "GroupMissingCloser",
                        "Missing closer.",
                        "Fatal",
                        <|
                            CodeParser`Source -> { 2, 2 },
                            ConfidenceLevel -> 1.
                        |>
                    ],
                    CodeInspector`InspectionObject[
                        "UnexpectedCloser",
                        "Unexpected closer.",
                        "Fatal",
                        <|
                            CodeParser`Source -> { 8, 8 },
                            ConfidenceLevel -> 1.
                        |>
                    ],
                    CodeInspector`InspectionObject[
                        "UnexpectedCloser",
                        "Unexpected closer.",
                        "Fatal",
                        <|
                            CodeParser`Source -> { 9, 9 },
                            ConfidenceLevel -> 1.
                        |>
                    ]
                },
                "OverallSeverity" -> 4
            |>,
            "FinalState" -> <|
                "InspectionObjects" -> { },
                "OverallSeverity" -> None
            |>
        |>,
        "OriginalCode" -> "f[{{3}}}}",
        "FixedCode" -> "f[{{3}}]"
    |>,
    TestID -> "6_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ #1, "Target" -> "Evaluator" ] &)[
        "Graphics3D[{a,{b},{c,Red},ViewPoint -> {1, -2, 1}]"
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "CodeInspector" -> <|
            "InitialState" -> <|
                "InspectionObjects" -> {
                    CodeInspector`InspectionObject[
                        "GroupMissingCloser",
                        "Missing closer.",
                        "Fatal",
                        <|
                            CodeParser`Source -> { 12, 12 },
                            ConfidenceLevel -> 1.
                        |>
                    ]
                },
                "OverallSeverity" -> 4
            |>,
            "FinalState" -> <|
                "InspectionObjects" -> { },
                "OverallSeverity" -> None
            |>
        |>,
        "OriginalCode" -> "Graphics3D[{a,{b},{c,Red},ViewPoint -> {1, -2, 1}]",
        "FixedCode" -> "Graphics3D[{a,{b},{c,Red}},ViewPoint -> {1, -2, 1}]"
    |>,
    TestID -> "7_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_a=1; y__b_2_d=2;x_a + x_b + x__c_1" ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 3,
        "LikelyFalsePositive" -> False,
        "CodeInspector" -> <|
            "InitialState" -> <|
                "InspectionObjects" -> {
                    CodeInspector`InspectionObject[
                        "BadSingleSnakeUsage",
                        "Bad Snake Usage",
                        "Fatal",
                        <|
                            ConfidenceLevel -> 1,
                            CodeParser`Source -> { 1, 3 }
                        |>
                    ],
                    CodeInspector`InspectionObject[
                        "BadSnakeUsage",
                        "Bad Snake Usage",
                        "Fatal",
                        <|
                            ConfidenceLevel -> 1,
                            CodeParser`Source -> { 8, 15 }
                        |>
                    ],
                    CodeInspector`InspectionObject[
                        "BadSnakeUsage",
                        "Bad Snake Usage",
                        "Fatal",
                        <|
                            ConfidenceLevel -> 1,
                            CodeParser`Source -> { 31, 36 }
                        |>
                    ]
                },
                "OverallSeverity" -> 4
            |>,
            "FinalState" -> <|
                "InspectionObjects" -> { },
                "OverallSeverity" -> None
            |>
        |>,
        "OriginalCode" -> "x_a=1; y__b_2_d=2;x_a + x_b + x__c_1",
        "FixedCode" -> "xA=1; yB2D=2;xA + x_b + xC1"
    |>,
    TestID -> "8_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_1 a9=1" ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> False,
        "Failure" -> Missing[ "No pattern", { { "Error", "ImplicitTimesInSet" } } ],
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "CodeInspector" -> <|
            "InitialState" -> <|
                "InspectionObjects" -> {
                    CodeInspector`InspectionObject[
                        "BadSnakeUsage",
                        "Bad Snake Usage",
                        "Fatal",
                        <|
                            ConfidenceLevel -> 1,
                            CodeParser`Source -> { 1, 6 }
                        |>
                    ]
                },
                "OverallSeverity" -> 4
            |>,
            "FinalState" -> <|
                "InspectionObjects" -> {
                    CodeInspector`InspectionObject[
                        "ImplicitTimesInSet",
                        "Suspicious implicit ``Times`` in ``Set``.",
                        "Error",
                        <|
                            CodeParser`Source -> { 4, 3 },
                            ConfidenceLevel -> 0.95,
                            CodeParser`CodeActions -> {
                                CodeParser`CodeAction[
                                    "Insert ``*``",
                                    CodeParser`InsertNode,
                                    <|
                                        CodeParser`Source -> { 4, 3 },
                                        "InsertionNode" ->
                                            CodeParser`LeafNode[ Token`Star, "*", <| |> ]
                                    |>
                                ],
                                CodeParser`CodeAction[
                                    "Insert ``;``",
                                    CodeParser`InsertNode,
                                    <|
                                        CodeParser`Source -> { 4, 3 },
                                        "InsertionNode" ->
                                            CodeParser`LeafNode[ Token`Semi, ";", <| |> ]
                                    |>
                                ],
                                CodeParser`CodeAction[
                                    "Insert ``,``",
                                    CodeParser`InsertNode,
                                    <|
                                        CodeParser`Source -> { 4, 3 },
                                        "InsertionNode" ->
                                            CodeParser`LeafNode[ Token`Comma, ",", <| |> ]
                                    |>
                                ]
                            }
                        |>
                    ]
                },
                "OverallSeverity" -> 3
            |>
        |>,
        "OriginalCode" -> "x_1 a9=1",
        "FixedCode" -> "x1 a9=1"
    |>,
    TestID -> "9_UnitTests_CCF_Feb2026"
]

VerificationTest[
    $UserDefinedFunctionsQ = <| |>,
    <| |>,
    TestID -> "10_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyFunc[22]" ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "CodeInspector" -> <|
            "InitialState" -> Inherited,
            "FinalState" -> <|
                "InspectionObjects" -> {
                    CodeInspector`InspectionObject[
                        "SuspiciousFunctionSymbol",
                        "Suspicious Function Name: MyFunc",
                        "WarningChatbook",
                        <|
                            ConfidenceLevel -> 2,
                            CodeParser`Source -> { 5, 14 }
                        |>
                    ]
                },
                "OverallSeverity" -> 2
            |>
        |>,
        "OriginalCode" -> "1+1;MyFunc[22]",
        "FixedCode" -> Missing[ "Warning only" ]
    |>,
    TestID -> "11_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "f1[x,y,]" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "f1[x,y]"
    |>,
    TestID -> "12_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "f1[x,y,(*comment*)]" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "Comma: No need to fix" ]
    |>,
    TestID -> "13_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "f1[x,y,(*comment*),z]" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "Comma: No need to fix" ]
    |>,
    TestID -> "14_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "f1[x,y,,(*comment*),]" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 2,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> "f1[x,y,(*comment*)]"
    |>,
    TestID -> "15_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "f1[x,y,(*comment*)];g[x,y,z]" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "Comma: No need to fix" ]
    |>,
    TestID -> "16_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "f1[{x,y,}z]" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "f1[{x,y}z]"
    |>,
    TestID -> "17_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "{f1[x,,y]}" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "{f1[x,y]}"
    |>,
    TestID -> "18_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "{f1[,x]}" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "{f1[x]}"
    |>,
    TestID -> "19_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[ "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n...\n" ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "No fix needed" ]
    |>,
    TestID -> "20_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[ "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n    ...\n" ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "No fix needed" ]
    |>,
    TestID -> "21_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[
            "\nminValue = NMinimize[{f[k], constraint1, constraint2, ...}, {k, kMin, kMax}]\n"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "No fix needed" ]
    |>,
    TestID -> "22_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[
            "\nlist = {a1, a2, a3, ..., an};  (* replace with your list of numbers *)\nmodResults = Mod[Rest[list], Most[list]]\n"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "No fix needed" ]
    |>,
    TestID -> "23_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[
            "\n(* Define your function *)\n\tf[k_] := Module[{...}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "No fix needed" ]
    |>,
    TestID -> "24_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[
            "\nGraphics3D[\n\t  Module[{...}, \n\t    ...\n\t    (*The full base perimeter now in black*)\n\t    {Black, Line[{{-14.5, -14.5, 29}, {14.5, -14.5, 29}, {14.5, 14.5, 29}, {-14.5, 14.5, 29}, {-14.5, -14.5, 29}}]}\n\t    ...\n\t  ], \n\t  ...\n\t]\n"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> False,
        "Failure" -> Missing[ "Expected Operand (no place holder(s) detected)" ],
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> Missing[ "Expected Operand (no place holder(s) detected)" ]
    |>,
    TestID -> "25_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "k->(* 111 *);" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "No fix needed" ]
    |>,
    TestID -> "26_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "k->;" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> False,
        "Failure" -> Missing[ "Expected Operand (no place holder(s) detected)" ],
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> Missing[ "Expected Operand (no place holder(s) detected)" ]
    |>,
    TestID -> "27_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "k:=(* 111 *);" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "No fix needed" ]
    |>,
    TestID -> "28_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "k[a_]:=   (* 111 *)   ;" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "No fix needed" ]
    |>,
    TestID -> "29_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "k[,(* 111 *)];" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "k[(* 111 *)];"
    |>,
    TestID -> "30_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[
            "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] = (* your existing function definition *)\n"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "No fix needed" ]
    |>,
    TestID -> "31_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[
            "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =      (* your existing function definition *)    \n"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "No fix needed" ]
    |>,
    TestID -> "32_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[
            "\nMixtilinearExcircles[triangle_] := Module[\n  {circumcircle, vertices, excircles},\n  vertices = triangle;\n  circumcircle = Circumsphere[Triangle[vertices]];\n  \n  excircles = Table[\n    Module[{vertex, tangentPoint, excircleCenter, excircleRadius},\n      vertex = vertices[[i]];\n      \n      (* Calculate tangent point on the circumcircle *)\n      tangentPoint = (* Obtain the correct tangent point here *);\n      \n      (* Calculate the center of the excircle *)\n      excircleCenter = (* Calculate the center based on tangent properties *);\n      \n      (* Calculate the radius of the excircle *)\n      excircleRadius = Norm[excircleCenter - tangentPoint];\n      \n      {Circle[excircleCenter, excircleRadius]}\n    ],\n    {i, Length[vertices]}\n  ];\n  \n  excircles\n]\n\n(* Example usage *)\ntriangle = {{0, 0}, {4, 3}, {4, 0}};\nMixtilinearExcircles[triangle]\n"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "No fix needed" ]
    |>,
    TestID -> "33_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[
            "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     ... (* your existing function definition *)    \n"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "No fix needed" ]
    |>,
    TestID -> "34_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[
            "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     (* your existing function definition *) ...    \n"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> Missing[ "No fix needed" ]
    |>,
    TestID -> "35_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "f1[x,...,y,]" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> "f1[x,...,y]"
    |>,
    TestID -> "36_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[ "\nranges = Tuples[{{-1, 0, , 1}, Range[-3, 3], Range[-3, 3]}];\n...\n" ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> True,
        "FixedCode" -> "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n...\n"
    |>,
    TestID -> "37_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[ "\nranges = Tuples[{{-1, 0, , 1}, Range[-3, 3], Range[-3, 3]}];\n....\n" ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> False,
        "Failure" -> Missing[ "Expected Operand (no place holder(s) detected)" ],
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n....\n"
    |>,
    TestID -> "38_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "eq= x==y" ] ],
    <|
        "ErrorsDetected" -> False,
        "FixedCode" -> Missing[ "No errors detected" ]
    |>,
    TestID -> "39_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "eq= x<=y" ] ],
    <|
        "ErrorsDetected" -> False,
        "FixedCode" -> Missing[ "No errors detected" ]
    |>,
    TestID -> "40_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "eq= x>=y" ] ],
    <|
        "ErrorsDetected" -> False,
        "FixedCode" -> Missing[ "No errors detected" ]
    |>,
    TestID -> "41_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[ "\n![Image](attachment://content-22840)\n" ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> Missing[ "Not WL code" ]
    |>,
    TestID -> "42_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[ "\n![Comparative Air Speed Velocities](attachment://content-6zubu)\n" ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> Missing[ "Not WL code" ]
    |>,
    TestID -> "43_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[
            "                                                                                                                                                                                                                                 * [FindMinimum](paclet:ref/FindMinimum)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 "
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> Missing[ "Not WL code" ]
    |>,
    TestID -> "44_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[
            "                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         * [Polynomial Factoring & Decomposition](paclet:guide/PolynomialFactoring)\n"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> Missing[ "Not WL code" ]
    |>,
    TestID -> "45_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[
            "\n![Sphere](attachment://content-57d9d4f5-650f-4a8c-a4bc-33b4c3a7ec86.png)\n"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> Missing[ "Not WL code" ]
    |>,
    TestID -> "46_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "f[{{3}}}" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "f[{{3}}]"
    |>,
    TestID -> "47_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "f[{{3,4}}}" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "f[{{3,4}}]"
    |>,
    TestID -> "48_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "f[{{3,4}]}" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 2,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "f[{{3,4}}]"
    |>,
    TestID -> "49_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "g[f[{{3,4}}},\n5]" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "g[f[{{3,4}}],\n5]"
    |>,
    TestID -> "50_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "{g[f[{{3,4}}},5]}" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "{g[f[{{3,4}}],5]}"
    |>,
    TestID -> "51_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "g[f[{{3,4}}},h[}]" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 2,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "g[f[{{3,4}}],h[]]"
    |>,
    TestID -> "52_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "g[(dothis;1},2]" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "g[(dothis;1),2]"
    |>,
    TestID -> "53_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "foo[1,2,g[{3]]]" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "foo[1,2,g[{3}]]"
    |>,
    TestID -> "54_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "(1;2;g[3))" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "(1;2;g[3])"
    |>,
    TestID -> "55_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "(1;2;g[3\n   ))" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "(1;2;g[3\n   ])"
    |>,
    TestID -> "56_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        CodeCheckFix[
            "\nmaxC = 20;\n\tprimTriples = Select[\n\t  With[{m = #1, n = #2}, \n\t    {m ^ 2 - n ^ 2, 2 m n, m ^ 2 + n ^ 2}\n\t  ] & @@@ \n\t  Select[\n\t    Flatten[Table[{m, n}, {n, Floor[Sqrt[maxC / 2]}], {m, n + 1, Floor[Sqrt[maxC]], 2}], 1], \n\t    #[[1]] ^ 2 + #[[2]] ^ 2 <= maxC &\n\t  ], \n\t  Apply[CoprimeQ, #] &\n\t];\n\t\n\tprimTriples\n"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 2,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "\nmaxC = 20;\n\tprimTriples = Select[\n\t  With[{m = #1, n = #2}, \n\t    {m ^ 2 - n ^ 2, 2 m n, m ^ 2 + n ^ 2}\n\t  ] & @@@ \n\t  Select[\n\t    Flatten[Table[{m, n}, {n, Floor[Sqrt[maxC / 2]]}, {m, n + 1, Floor[Sqrt[maxC]], 2}], 1], \n\t    #[[1]] ^ 2 + #[[2]] ^ 2 <= maxC &\n\t  ], \n\t  Apply[CoprimeQ, #] &\n\t];\n\t\n\tprimTriples\n"
    |>,
    TestID -> "57_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "f[{{3}}]]" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> False,
        "Failure" -> Missing[ "No pattern", { { "Fatal", "UnexpectedCloser" } } ],
        "SafeToEvaluate" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> Missing[ "No pattern", { { "Fatal", "UnexpectedCloser" } } ]
    |>,
    TestID -> "58_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "f[{{3}}]]", "Target" -> "Evaluator" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "f[{{3}}]"
    |>,
    TestID -> "59_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "f[{{3}}}}", "Target" -> "Evaluator" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 2,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "f[{{3}}]"
    |>,
    TestID -> "60_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][ CodeCheckFix[ "f[{{3}}}]", "Target" -> "Evaluator" ] ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "f[{{3}}]"
    |>,
    TestID -> "61_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        (CodeCheckFix[ #1, "Target" -> "Evaluator" ] &)[ "f[a,g[h];b[c]" ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "f[a,g[h];b[c]]"
    |>,
    TestID -> "62_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        (CodeCheckFix[ #1, "Target" -> "Evaluator" ] &)[
            "Graphics3D[{a,{b},{c,Red},ViewPoint -> {1, -2, 1}]"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "Graphics3D[{a,{b},{c,Red}},ViewPoint -> {1, -2, 1}]"
    |>,
    TestID -> "63_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        (CodeCheckFix[ #1, "Target" -> "Evaluator" ] &)[
            "Graphics3D[{a,{b},{c,Red},ViewPoint -> Automatic]"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "Graphics3D[{a,{b},{c,Red}},ViewPoint -> Automatic]"
    |>,
    TestID -> "64_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        (CodeCheckFix[ #1, "Target" -> "Evaluator" ] &)[
            "graphics3D[{a,{b},{c,Red},ViewPoint -> Automatic]"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "graphics3D[{a,{b},{c,Red}},ViewPoint -> Automatic]"
    |>,
    TestID -> "65_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        (CodeCheckFix[ #1, "Target" -> "Evaluator" ] &)[
            "Graphics3D[{a,b,{c,Red},viewPoint -> Automatic]"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "Graphics3D[{a,b,{c,Red}},viewPoint -> Automatic]"
    |>,
    TestID -> "66_UnitTests_CCF_Feb2026"
]

VerificationTest[
    KeyDrop[ ({ "CodeInspector", "OriginalCode" }) ][
        (CodeCheckFix[ #1, "Target" -> "Evaluator" ] &)[
            "graphics3D[{a,b,{c,Red},viewPoint -> {1, -2, 1}]"
        ]
    ],
    <|
        "ErrorsDetected" -> True,
        "Success" -> True,
        "SafeToEvaluate" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "FixedCode" -> "graphics3D[{a,b,{c,Red},viewPoint -> {1, -2, 1}}]"
    |>,
    TestID -> "67_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[
        "first_symbol = 1;\nsecond_symbol = 2;\nfirst_symbol + second_symbol"
    ],
    "firstSymbol = 1;\nsecondSymbol = 2;\nfirstSymbol + secondSymbol",
    TestID -> "68_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "x_1 = 1;\nx_2 = 2;\ny_1_2 = f[x_1, x_2]" ],
    "x1 = 1;\nx2 = 2;\ny12 = f[x1, x2]",
    TestID -> "69_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "f[my_symbol] = 123" ],
    Missing[ "No errors detected" ],
    TestID -> "70_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "f[my_cool_symbol] = 123" ],
    "f[myCoolSymbol] = 123",
    TestID -> "71_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "my_cool_symbol[a]" ],
    "myCoolSymbol[a]",
    TestID -> "72_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "my_cool_1[a]" ],
    "myCool1[a]",
    TestID -> "73_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "my_cool[a]" ],
    "myCool[a]",
    TestID -> "74_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "my_1[a]" ],
    "my1[a]",
    TestID -> "75_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "my_symbol := 123" ],
    Missing[ "No errors detected" ],
    TestID -> "76_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "my_cool_symbol := 123" ],
    "myCoolSymbol := 123",
    TestID -> "77_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "f[x_1, x_2]" ],
    "f[x1, x2]",
    TestID -> "78_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "x_1=2" ],
    "x1=2",
    TestID -> "79_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "f[x_ 1, x_ 2]" ],
    Missing[ "No errors detected" ],
    TestID -> "80_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[
        "my_offset = 123;\n(* my_string_length is a really neat function *)\nmy_string_length[test_String] := StringLength[test] + my_offset;\nmy_string_length[\"my_string_length\"]"
    ],
    "myOffset = 123;\n(* my_string_length is a really neat function *)\nmyStringLength[testString] := StringLength[test] + myOffset;\nmyStringLength[\"my_string_length\"]",
    TestID -> "81_UnitTests_CCF_Feb2026"
]

VerificationTest[ CodeCheckFix[ "x_a=1" ][ "FixedCode" ], "xA=1", TestID -> "82_UnitTests_CCF_Feb2026" ]
VerificationTest[
    CodeCheckFix[ "x_a+1" ][ "FixedCode" ],
    Missing[ "No errors detected" ],
    TestID -> "83_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_ a =1" ][ "FixedCode" ],
    Missing[ "No pattern", { { "Error", "ImplicitTimesInSet" } } ],
    TestID -> "84_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_ a +1" ][ "FixedCode" ],
    Missing[ "No errors detected" ],
    TestID -> "85_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_123=1" ][ "FixedCode" ],
    "x123=1",
    TestID -> "86_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_123+1" ][ "FixedCode" ],
    "x123+1",
    TestID -> "87_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_ 123=1" ][ "FixedCode" ],
    Missing[ "No pattern", { { "Error", "ImplicitTimesInSet" } } ],
    TestID -> "88_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_ 123+1" ][ "FixedCode" ],
    Missing[ "No errors detected" ],
    TestID -> "89_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_1a=1" ][ "FixedCode" ],
    "x1a=1",
    TestID -> "90_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_1a+1" ][ "FixedCode" ],
    "x1a+1",
    TestID -> "91_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_1a9=1" ][ "FixedCode" ],
    "x1a9=1",
    TestID -> "92_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_1a9+1" ][ "FixedCode" ],
    "x1a9+1",
    TestID -> "93_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_1 a9=1" ][ "FixedCode" ],
    "x1 a9=1",
    TestID -> "94_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_1 a9+1" ][ "FixedCode" ],
    "x1 a9+1",
    TestID -> "95_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_1a 9+1" ][ "FixedCode" ],
    "x1a 9+1",
    TestID -> "96_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_1_2=1" ][ "FixedCode" ],
    "x12=1",
    TestID -> "97_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_1_2:=1" ][ "FixedCode" ],
    "x12:=1",
    TestID -> "98_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x__1___2:=1" ][ "FixedCode" ],
    "x12:=1",
    TestID -> "99_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x___a_1__2b_CC__2:=1" ][ "FixedCode" ],
    "xA12bCC2:=1",
    TestID -> "100_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "x_a=1; y__b_2_d=2;x_a + x_b + x__c_1" ][ "FixedCode" ],
    "xA=1; yB2D=2;xA + x_b + xC1",
    TestID -> "101_UnitTests_CCF_Feb2026"
]

VerificationTest[
    Function[
        Select[
            #1,
            Function[
                Not[
                    MemberQ[
                        {
                            { "AmpereSquareMeter", "Quantity[1, \"Ampere\"*\"SquareMeters\"]" },
                            { "Attofarad", "Quantity[1, \"Attofarads\"]" },
                            { "AttogramPerCubicMeter", "Quantity[1, \"Attograms\"/\"CubicMeters\"]" },
                            { "Attohenry", Missing[ "Unknown unit", "Attohenry" ] },
                            { "Attolux", Missing[ "No errors detected" ] },
                            { "Attosiemens", Missing[ "No errors detected" ] },
                            { "Attoweber", "Quantity[1, \"Attowebers\"]" },
                            { "BecquerelPerGram", "Quantity[1, \"Becquerel\"/\"Grams\"]" },
                            { "CandelaPerSquareMeter", "Quantity[1, \"Candelas\"/\"SquareMeters\"]" },
                            { "CentigalPerSecond", Missing[ "Unknown unit", "CentigalPerSecond" ] },
                            { "Centilux", Missing[ "No errors detected" ] },
                            { "CentinewtonMeter", "Quantity[1, \"Centinewtons\"*\"Meter\"]" },
                            { "CentinewtonSecond", "Quantity[1, \"Centinewtons\"*\"Second\"]" },
                            { "Centitesla", "Quantity[1, \"Centiteslas\"]" },
                            { "CoulombPerKilogram", "Quantity[1, \"Coulomb\"/\"Kilogram\"]" },
                            { "CubicMetersPerSecond", "Quantity[1, \"CubicMeters\"/\"Second\"]" },
                            { "Decamole", Missing[ "Unknown unit", "Decamole" ] },
                            { "Decibel", Missing[ "Unknown unit", "Decibel" ] },
                            { "DecibelPerMeter", Missing[ "Unknown unit", "DecibelPerMeter" ] },
                            { "DeciliterPerMinute", "Quantity[1, \"Deciliters\"/\"Minute\"]" },
                            { "DecilumenMinute", "Quantity[1, \"Decilumens\"*\"Minute\"]" },
                            { "DeciluxSecond", "Quantity[1, \"Decilux\"*\"Second\"]" },
                            { "Deciparsec", Missing[ "Unknown unit", "Deciparsec" ] },
                            { "Decipascal", "Quantity[1, \"Decipascals\"]" },
                            { "DecipascalSecond", "Quantity[1, \"Decipascals\"*\"Second\"]" },
                            { "DecivoltPerMeter", "Quantity[1, \"Decivolts\"/\"Meter\"]" },
                            { "Degrees", Missing[ "No errors detected" ] },
                            { "ErgPerGram", "Quantity[1, \"Ergs\"/\"Grams\"]" },
                            { "FemtoampereSecond", "Quantity[1, \"Femtoamperes\"*\"Second\"]" },
                            { "FemtocoulombSeconds", "Quantity[1, \"Femtocoulombs\"*\"Seconds\"]" },
                            { "FemtohenryPerMeter", Missing[ "Unknown unit", "FemtohenryPerMeter" ] },
                            { "Femtohertz", Missing[ "No errors detected" ] },
                            { "Femtojoule", "Quantity[1, \"Femtojoules\"]" },
                            { "FemtojoulePerKelvin", "Quantity[1, \"Femtojoules\"/\"Kelvin\"]" },
                            { "FemtolambertSecond", Missing[ "Unknown unit", "FemtolambertSecond" ] },
                            { "Femtoliter", "Quantity[1, \"Femtoliters\"]" },
                            { "FemtomolePerSecond", "Quantity[1, \"Femtomoles\"/\"Second\"]" },
                            { "FemtonewtonMeter", "Quantity[1, \"Femtonewtons\"*\"Meter\"]" },
                            { "Femtosievert", "Quantity[1, \"Femtosieverts\"]" },
                            { "Femtotesla", "Quantity[1, \"Femtoteslas\"]" },
                            { "Gigacurie", "Quantity[1, \"Gigacuries\"]" },
                            { "Gigafurlong", "Quantity[1, \"Gigafurlongs\"]" },
                            { "Gigahertz", Missing[ "No errors detected" ] },
                            { "Gigapascal", "Quantity[1, \"Gigapascals\"]" },
                            { "GigavoltSecond", "Quantity[1, \"Gigavolts\"*\"Second\"]" },
                            { "GramPerCentimeterCubed", "Quantity[1, \"Grams\"/\"Centimeters\"^3]" },
                            { "GrayPerSecond", "Quantity[1, \"Gray\"/\"Second\"]" },
                            { "Hectohertz", Missing[ "No errors detected" ] },
                            { "Hectokatal", "Quantity[1, \"Hectokatals\"]" },
                            { "Hectokelvin", "Quantity[1, \"Hectokelvins\"]" },
                            { "Hectolambert", Missing[ "Unknown unit", "Hectolambert" ] },
                            { "Hectolumen", "Quantity[1, \"Hectolumens\"]" },
                            { "HectoluxSecond", "Quantity[1, \"Hectolux\"*\"Second\"]" },
                            { "HectometerPerSecond", "Quantity[1, \"Hectometers\"/\"Second\"]" },
                            { "HectopascalSecond", "Quantity[1, \"Hectopascals\"*\"Second\"]" },
                            { "Hectowatt", "Quantity[1, \"Hectowatts\"]" },
                            { "HenryPerMeter", "Quantity[1, \"Henry\"/\"Meter\"]" },
                            { "HertzSecond", "Quantity[1, \"Hertz\"*\"Second\"]" },
                            { "JoulePerCoulomb", "Quantity[1, \"Joule\"/\"Coulomb\"]" },
                            { "JoulePerKelvin", "Quantity[1, \"Joule\"/\"Kelvin\"]" },
                            { "Katal", Missing[ "No errors detected" ] },
                            { "KelvinPerWatt", "Quantity[1, \"Kelvin\"/\"Watt\"]" },
                            { "KiloampereHour", "Quantity[1, \"Hour\"*\"Kiloamperes\"]" },
                            { "Kilofurlongs", Missing[ "No errors detected" ] },
                            { "KilogaussSecond", "Quantity[1, \"Kilogauss\"*\"Second\"]" },
                            { "KilogramsPerCubicMeter", Missing[ "No errors detected" ] },
                            { "KilogramsPerMetersCubed", "Quantity[1, \"Kilograms\"/\"Meters\"^3]" },
                            { "KilojoulePerMole", "Quantity[1, \"Kilojoules\"/\"Mole\"]" },
                            { "KiloluxPerSteradian", "Quantity[1, \"Kilolux\"/\"Steradian\"]" },
                            { "Kilomole", "Quantity[1, \"Kilomoles\"]" },
                            { "KilomolePerSecond", "Quantity[1, \"Kilomoles\"/\"Second\"]" },
                            { "Kiloohms", Missing[ "No errors detected" ] },
                            { "KilopascalPerMeter", "Quantity[1, \"Kilopascals\"/\"Meter\"]" },
                            { "KilowattHour", "Quantity[1, \"Hour\"*\"Kilowatts\"]" },
                            { "KilowattHours", "Quantity[1, \"Hours\"*\"Kilowatts\"]" },
                            { "KiloweberPerSecond", "Quantity[1, \"Kilowebers\"/\"Second\"]" },
                            { "LuxSecond", "Quantity[1, \"Lux\"*\"Second\"]" },
                            { "Megabecquerel", "Quantity[1, \"Megabecquerels\"]" },
                            { "MegaergPerKelvin", Missing[ "Unknown unit", "MegaergPerKelvin" ] },
                            { "Megaergs", Missing[ "Unknown unit", "Megaergs" ] },
                            { "Megagauss", Missing[ "No errors detected" ] },
                            { "MegagramPerLiter", "Quantity[1, \"Megagrams\"/\"Liters\"]" },
                            { "MeganewtonMeter", "Quantity[1, \"Meganewtons\"*\"Meter\"]" },
                            { "Megaoersted", Missing[ "Unknown unit", "Megaoersted" ] },
                            { "MegaohmCentimeter", "Quantity[1, \"Centimeters\"*\"Megaohms\"]" },
                            { "Megaparsec", "Quantity[1, \"Megaparsecs\"]" },
                            { "MegatonPerSecond", Missing[ "Unknown unit", "MegatonPerSecond" ] },
                            { "MeterPerSecondSquared", "Quantity[1, \"Meter\"/\"Second\"^2]" },
                            { "Microbarns", Missing[ "No errors detected" ] },
                            { "Microcurie", "Quantity[1, \"Microcuries\"]" },
                            { "Microdarcy", Missing[ "Unknown unit", "Microdarcy" ] },
                            { "Microgray", "Quantity[1, \"Micrograys\"]" },
                            { "MicrograyPerSecond", "Quantity[1, \"Micrograys\"/\"Second\"]" },
                            { "Microkayser", Missing[ "Unknown unit", "Microkayser" ] },
                            { "Microlambert", "Quantity[1, \"Microlamberts\"]" },
                            { "Microlux", Missing[ "No errors detected" ] },
                            { "MilesPerHour", "Quantity[1, \"Miles\"/\"Hour\"]" },
                            {
                                "MillicandelaPerSquareMeter",
                                "Quantity[1, \"Millicandelas\"/\"SquareMeters\"]"
                            },
                            { "Millifarad", "Quantity[1, \"Millifarads\"]" },
                            { "Milligal", "Quantity[1, \"Milligals\"]" },
                            { "Millijanskys", Missing[ "No errors detected" ] },
                            { "MillimolePerGram", "Quantity[1, \"Millimoles\"/\"Grams\"]" },
                            { "MillionShortTons", "Quantity[1, \"Million\"*\"ShortTons\"]" },
                            { "MillipascalSeconds", "Quantity[1, \"Millipascals\"*\"Seconds\"]" },
                            { "Millirad", "Quantity[1, \"Millirads\"]" },
                            { "Millisiemens", Missing[ "No errors detected" ] },
                            { "MilliteslaMeter", "Quantity[1, \"Meter\"*\"Milliteslas\"]" },
                            { "MolePerLiter", "Quantity[1, \"Mole\"/\"Liters\"]" },
                            { "NanobarnSecond", "Quantity[1, \"Nanobarns\"*\"Second\"]" },
                            { "NanofaradSecond", "Quantity[1, \"Nanofarads\"*\"Second\"]" },
                            { "Nanogray", "Quantity[1, \"Nanograys\"]" },
                            {
                                "NanometerPerPicosecond",
                                "Quantity[1, \"Nanometers\"/\"Picoseconds\"]"
                            },
                            { "NanomolePerLiter", "Quantity[1, \"Nanomoles\"/\"Liters\"]" },
                            { "Nanopascal", "Quantity[1, \"Nanopascals\"]" },
                            { "Nanoradian", "Quantity[1, \"Nanoradians\"]" },
                            { "NanosecondPerMeter", "Quantity[1, \"Nanoseconds\"/\"Meter\"]" },
                            { "Nanostoke", Missing[ "Unknown unit", "Nanostoke" ] },
                            { "Nanotesla", "Quantity[1, \"Nanoteslas\"]" },
                            { "NanoteslaSecond", "Quantity[1, \"Nanoteslas\"*\"Second\"]" },
                            { "NewtonMeter", "Quantity[1, \"Meter\"*\"Newton\"]" },
                            { "NewtonSecond", "Quantity[1, \"Newton\"*\"Second\"]" },
                            { "OhmMeter", "Quantity[1, \"Meter\"*\"Ohm\"]" },
                            { "Pascalliters", Missing[ "Unknown unit", "Pascalliters" ] },
                            { "PascalSecond", "Quantity[1, \"Pascal\"*\"Second\"]" },
                            { "Petaampere", "Quantity[1, \"Petaamperes\"]" },
                            { "Petabyte", "Quantity[1, \"Petabytes\"]" },
                            { "Petagram", "Quantity[1, \"Petagrams\"]" },
                            { "Petalux", Missing[ "No errors detected" ] },
                            { "PetameterPerSecond", "Quantity[1, \"Petameters\"/\"Second\"]" },
                            { "Petapascal", "Quantity[1, \"Petapascals\"]" },
                            { "Petasiemens", Missing[ "No errors detected" ] },
                            { "Picoampere", "Quantity[1, \"Picoamperes\"]" },
                            { "PicogramPerMilliliter", "Quantity[1, \"Picograms\"/\"Milliliters\"]" },
                            { "Picogray", "Quantity[1, \"Picograys\"]" },
                            { "PicoohmMeter", "Quantity[1, \"Meter\"*\"Picoohms\"]" },
                            { "Picotorr", Missing[ "Unknown unit", "Picotorr" ] },
                            { "Picowebers", Missing[ "No errors detected" ] },
                            { "RoodPerSecond", "Quantity[1, \"Roods\"/\"Second\"]" },
                            { "SiemensPerMeter", Missing[ "No errors detected" ] },
                            { "SievertPerHour", "Quantity[1, \"Sievert\"/\"Hour\"]" },
                            { "Terabit", "Quantity[1, \"Terabits\"]" },
                            { "TeracandelaHour", "Quantity[1, \"Hour\"*\"Teracandelas\"]" },
                            { "Teragram", "Quantity[1, \"Teragrams\"]" },
                            { "Terajoule", "Quantity[1, \"Terajoules\"]" },
                            { "TeslaSecond", "Quantity[1, \"Second\"*\"Tesla\"]" },
                            { "Tons", Missing[ "Unknown unit", "Tons" ] },
                            { "VoltPerMeter", "Quantity[1, \"Volt\"/\"Meter\"]" },
                            { "WattPerSteradian", "Quantity[1, \"Watt\"/\"Steradian\"]" },
                            { "Year", Missing[ "No errors detected" ] },
                            { "Yoctosecond", "Quantity[1, \"Yoctoseconds\"]" },
                            { "Yoctosiemens", Missing[ "No errors detected" ] },
                            { "Yoctowatt", "Quantity[1, \"Yoctowatts\"]" },
                            { "Yottabyte", "Quantity[1, \"Yottabytes\"]" },
                            { "YottameterCube", "Quantity[1, \"Cubes\"*\"Yottameters\"]" },
                            { "Yottawatt", "Quantity[1, \"Yottawatts\"]" },
                            { "Zeptocoulomb", "Quantity[1, \"Zeptocoulombs\"]" },
                            { "Zeptojoule", "Quantity[1, \"Zeptojoules\"]" },
                            { "Zeptolumen", "Quantity[1, \"Zeptolumens\"]" },
                            { "Zeptonewton", "Quantity[1, \"Zeptonewtons\"]" },
                            { "Zeptosecond", "Quantity[1, \"Zeptoseconds\"]" },
                            { "Zettajoule", "Quantity[1, \"Zettajoules\"]" }
                        },
                        #1
                    ]
                ]
            ]
        ]
    ][
        Map[
            { #1, CodeCheckFix[ (ToString[ Unevaluated[ Quantity[ 1, #1 ] ], InputForm ]) ][ "FixedCode" ] } &,
            {
                "AmpereSquareMeter",
                "Attofarad",
                "AttogramPerCubicMeter",
                "Attohenry",
                "Attolux",
                "Attosiemens",
                "Attoweber",
                "BecquerelPerGram",
                "CandelaPerSquareMeter",
                "CentigalPerSecond",
                "Centilux",
                "CentinewtonMeter",
                "CentinewtonSecond",
                "Centitesla",
                "CoulombPerKilogram",
                "CubicMetersPerSecond",
                "Decamole",
                "Decibel",
                "DecibelPerMeter",
                "DeciliterPerMinute",
                "DecilumenMinute",
                "DeciluxSecond",
                "Deciparsec",
                "Decipascal",
                "DecipascalSecond",
                "DecivoltPerMeter",
                "Degrees",
                "ErgPerGram",
                "FemtoampereSecond",
                "FemtocoulombSeconds",
                "FemtohenryPerMeter",
                "Femtohertz",
                "Femtojoule",
                "FemtojoulePerKelvin",
                "FemtolambertSecond",
                "Femtoliter",
                "FemtomolePerSecond",
                "FemtonewtonMeter",
                "Femtosievert",
                "Femtotesla",
                "Gigacurie",
                "Gigafurlong",
                "Gigahertz",
                "Gigapascal",
                "GigavoltSecond",
                "GramPerCentimeterCubed",
                "GrayPerSecond",
                "Hectohertz",
                "Hectokatal",
                "Hectokelvin",
                "Hectolambert",
                "Hectolumen",
                "HectoluxSecond",
                "HectometerPerSecond",
                "HectopascalSecond",
                "Hectowatt",
                "HenryPerMeter",
                "HertzSecond",
                "JoulePerCoulomb",
                "JoulePerKelvin",
                "Katal",
                "KelvinPerWatt",
                "KiloampereHour",
                "Kilofurlongs",
                "KilogaussSecond",
                "KilogramsPerCubicMeter",
                "KilogramsPerMetersCubed",
                "KilojoulePerMole",
                "KiloluxPerSteradian",
                "Kilomole",
                "KilomolePerSecond",
                "Kiloohms",
                "KilopascalPerMeter",
                "KilowattHour",
                "KilowattHours",
                "KiloweberPerSecond",
                "LuxSecond",
                "Megabecquerel",
                "MegaergPerKelvin",
                "Megaergs",
                "Megagauss",
                "MegagramPerLiter",
                "MeganewtonMeter",
                "Megaoersted",
                "MegaohmCentimeter",
                "Megaparsec",
                "MegatonPerSecond",
                "MeterPerSecondSquared",
                "Microbarns",
                "Microcurie",
                "Microdarcy",
                "Microgray",
                "MicrograyPerSecond",
                "Microkayser",
                "Microlambert",
                "Microlux",
                "MilesPerHour",
                "MillicandelaPerSquareMeter",
                "Millifarad",
                "Milligal",
                "Millijanskys",
                "MillimolePerGram",
                "MillionShortTons",
                "MillipascalSeconds",
                "Millirad",
                "Millisiemens",
                "MilliteslaMeter",
                "MolePerLiter",
                "NanobarnSecond",
                "NanofaradSecond",
                "Nanogray",
                "NanometerPerPicosecond",
                "NanomolePerLiter",
                "Nanopascal",
                "Nanoradian",
                "NanosecondPerMeter",
                "Nanostoke",
                "Nanotesla",
                "NanoteslaSecond",
                "NewtonMeter",
                "NewtonSecond",
                "OhmMeter",
                "Pascalliters",
                "PascalSecond",
                "Petaampere",
                "Petabyte",
                "Petagram",
                "Petalux",
                "PetameterPerSecond",
                "Petapascal",
                "Petasiemens",
                "Picoampere",
                "PicogramPerMilliliter",
                "Picogray",
                "PicoohmMeter",
                "Picotorr",
                "Picowebers",
                "RoodPerSecond",
                "SiemensPerMeter",
                "SievertPerHour",
                "Terabit",
                "TeracandelaHour",
                "Teragram",
                "Terajoule",
                "TeslaSecond",
                "Tons",
                "VoltPerMeter",
                "WattPerSteradian",
                "Year",
                "Yoctosecond",
                "Yoctosiemens",
                "Yoctowatt",
                "Yottabyte",
                "YottameterCube",
                "Yottawatt",
                "Zeptocoulomb",
                "Zeptojoule",
                "Zeptolumen",
                "Zeptonewton",
                "Zeptosecond",
                "Zettajoule"
            }
        ]
    ],
    { },
    TestID -> "102_UnitTests_CCF_Feb2026"
]

VerificationTest[
    SameQ[
        Function[
            {
                Times @@@ #1,
                StringCases[
                    Shortest[ "Quantity[" ~~ t__ ~~ "," ~~ v__ ~~ "]" ] :> ToExpression[ StringTrim[ v ] ]
                ][
                    Map[
                        Function[
                            CodeCheckFix[ (ToString[ Unevaluated[ Quantity[ 1, #1 ] ], InputForm ]) ][
                                "FixedCode"
                            ]
                        ]
                    ][
                        #1
                    ]
                ]
            }
        ][
            (Map[ StringJoin ])[
                {
                    { "PerchesLength", "Kerats", "Femtohertz", "Zm", "IndianMustis", "Pouces" },
                    { "Droits", "BritishThermalUnitsMean", "PiedsDuRoi", "Kilofeet", "Dekayards" },
                    { "MilliVAs", "Tierces" },
                    {
                        "Megabars",
                        "GallonsUK",
                        "GuatemalaCentavos",
                        "RomanScriptula",
                        "JovianMassParameter"
                    },
                    { "Radians", "Xennameters" },
                    { "Hcd", "VDC", "BritishLivestockUnits", "KiB", "Gavyutis" },
                    { "Milligons", "ElectricConstant" },
                    { "Bushels53Pound", "Microlumens" },
                    {
                        "Lactabits",
                        "Megawebers",
                        "ShortQuires",
                        "Spheres",
                        "Tamms",
                        "MinimalPerceptibleErythema"
                    },
                    { "Hartrees", "Vendekoohms", "Tt" }
                }
            ]
        ]
    ],
    True,
    TestID -> "103_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "Quantity[1, \"Meter\"]" ][ "FixedCode" ],
    Missing[ "No errors detected" ],
    TestID -> "104_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "Quantity[1, \"AmpereSquareMeter\"]" ][ "FixedCode" ],
    "Quantity[1, \"Ampere\"*\"SquareMeters\"]",
    TestID -> "105_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "Quantity[1, \"DecibelPerMeter\"]" ][ "FixedCode" ],
    Missing[ "Unknown unit", "DecibelPerMeter" ],
    TestID -> "106_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "Quantity[1, \"Attohenry\"]" ][ "FixedCode" ],
    Missing[ "Unknown unit", "Attohenry" ],
    TestID -> "107_UnitTests_CCF_Feb2026"
]

VerificationTest[
    $UserDefinedFunctionsQ = <| |>,
    <| |>,
    TestID -> "108_UnitTests_CCF_Feb2026"
]

VerificationTest[
    Clear[ MyFunc ];
    "MyFunc: cleared",
    "MyFunc: cleared",
    TestID -> "109_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "1+1;MyFunc[22]" ],
    Missing[ "Warning only" ],
    TestID -> "110_UnitTests_CCF_Feb2026"
]

VerificationTest[
    Clear[ MyContext`Func ];
    "MyContext`Func: cleared",
    "MyContext`Func: cleared",
    TestID -> "111_UnitTests_CCF_Feb2026"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "1+1;MyContext`Func[22]" ],
    Missing[ "Warning only" ],
    TestID -> "112_UnitTests_CCF_Feb2026"
]

VerificationTest[ $UserDefinedFunctionsQ, <| |>, TestID -> "113_UnitTests_CCF_Feb2026" ]
VerificationTest[
    CodeCheckFix[ "1+1;myContext`Func[22]" ],
    <|
        "ErrorsDetected" -> False,
        "OriginalCode" -> "1+1;myContext`Func[22]",
        "FixedCode" -> Missing[ "No errors detected" ]
    |>,
    TestID -> "114_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyContext`func[22]" ],
    <|
        "ErrorsDetected" -> False,
        "OriginalCode" -> "1+1;MyContext`func[22]",
        "FixedCode" -> Missing[ "No errors detected" ]
    |>,
    TestID -> "115_UnitTests_CCF_Feb2026"
]

VerificationTest[
    Clear[ MyFunc ];
    "MyFunc: cleared",
    "MyFunc: cleared",
    TestID -> "116_UnitTests_CCF_Feb2026"
]

VerificationTest[
    MyFunc[ x_ ] := x^2;
    "MyFunc: defined",
    "MyFunc: defined",
    TestID -> "117_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyFunc[22]" ],
    <|
        "ErrorsDetected" -> False,
        "OriginalCode" -> "1+1;MyFunc[22]",
        "FixedCode" -> Missing[ "No errors detected" ]
    |>,
    TestID -> "118_UnitTests_CCF_Feb2026"
]

VerificationTest[ $UserDefinedFunctionsQ, <| |>, TestID -> "119_UnitTests_CCF_Feb2026" ]

VerificationTest[
    Clear[ MyFunc ];
    "MyFunc: cleared",
    "MyFunc: cleared",
    TestID -> "120_UnitTests_CCF_Feb2026"
]

VerificationTest[

    MyFunc /:doIt[ MyFunc[ 1 ] ] := 3;
    "MyFunc: defined",
    "MyFunc: defined",
    TestID -> "121_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyFunc[22]" ],
    <|
        "ErrorsDetected" -> False,
        "OriginalCode" -> "1+1;MyFunc[22]",
        "FixedCode" -> Missing[ "No errors detected" ]
    |>,
    TestID -> "122_UnitTests_CCF_Feb2026"
]

VerificationTest[ $UserDefinedFunctionsQ, <| |>, TestID -> "123_UnitTests_CCF_Feb2026" ]
VerificationTest[
    Clear[ MyFunc ];
    "MyFunc: cleared",
    "MyFunc: cleared",
    TestID -> "124_UnitTests_CCF_Feb2026"
]

VerificationTest[
    MyFunc = 2;
    "MyFunc: defined",
    "MyFunc: defined",
    TestID -> "125_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyFunc[22]" ],
    <|
        "ErrorsDetected" -> False,
        "OriginalCode" -> "1+1;MyFunc[22]",
        "FixedCode" -> Missing[ "No errors detected" ]
    |>,
    TestID -> "126_UnitTests_CCF_Feb2026"
]

VerificationTest[
    Clear[ MyFunc ];
    "MyFunc: cleared",
    "MyFunc: cleared",
    TestID -> "127_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyFunc[22];" ][ "FixedCode" ],
    Missing[ "Warning only" ],
    TestID -> "128_UnitTests_CCF_Feb2026"
]

VerificationTest[
    $UserDefinedFunctionsQ = <| |>,
    <| |>,
    TestID -> "129_UnitTests_CCF_Feb2026"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyFunc[22];MyFunc[x_]:=x+1" ],
    <|
        "ErrorsDetected" -> False,
        "OriginalCode" -> "1+1;MyFunc[22];MyFunc[x_]:=x+1",
        "FixedCode" -> Missing[ "No errors detected" ]
    |>,
    TestID -> "130_UnitTests_CCF_Feb2026"
]

VerificationTest[
    $UserDefinedFunctionsQ,
    <|
        "MyFunc" -> True
    |>,
    TestID -> "131_UnitTests_CCF_Feb2026"
]

VerificationTest[
    Remove[ MyFunc ];
    "MyFunc: removed",
    "MyFunc: removed",
    TestID -> "132_UnitTests_CCF_Feb2026"
]
