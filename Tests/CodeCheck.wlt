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
    Clear[ mainInfo ];

    mainInfo :=
        RightComposition[
            KeyTake[ { "FixedCode", "SafeToEvaluate" } ],
            Map[
                Replace[
                    {
                        Missing[ __ ] :> Missing[ "..." ],
                        Failure[ __ ] -> Failure[ "...", <| |> ]
                    }
                ]
            ]
        ];

    "Formatting function defined",
    "Formatting function defined",
    TestID -> "1_formatting"
]

VerificationTest[
    Clear[ finalState ];

    finalState[ ccf_Association ] :=
        (Apply[ List ])[
            ccf[[ "CodeInspector", "FinalState", "InspectionObjects", 1 ]]
        ];

    "finalState defined",
    "finalState defined",
    TestID -> "2_formatting"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "f1[x,y,]" ] ],
    <|
        "FixedCode" -> "f1[x,y]",
        "SafeToEvaluate" -> True
    |>,
    TestID -> "1_comma_operand"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "f1[x,y,(*comment*)]" ] ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "2_comma_operand"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "f1[x,y,,(*comment*),]" ] ],
    <|
        "FixedCode" -> "f1[x,y,(*comment*)]",
        "SafeToEvaluate" -> False
    |>,
    TestID -> "3_comma_operand"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "f1[x,y,(*comment*)];g[x,y,z]" ] ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "4_comma_operand"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "f1[{x,y,}z]" ] ],
    <|
        "FixedCode" -> "f1[{x,y}z]",
        "SafeToEvaluate" -> True
    |>,
    TestID -> "5_comma_operand"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "{f1[x,,y]}" ] ],
    <|
        "FixedCode" -> "{f1[x,y]}",
        "SafeToEvaluate" -> True
    |>,
    TestID -> "6_comma_operand"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "{f1[,x]}" ] ],
    <|
        "FixedCode" -> "{f1[x]}",
        "SafeToEvaluate" -> True
    |>,
    TestID -> "7_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n...\n"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "8_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n    ...\n"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "9_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\nminValue = NMinimize[{f[k], constraint1, constraint2, ...}, {k, kMin, kMax}]\n"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "10_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\nlist = {a1, a2, a3, ..., an};  (* replace with your list of numbers *)\nmodResults = Mod[Rest[list], Most[list]]\n"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "11_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\n(* Define your function *)\n\tf[k_] := Module[{...}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "12_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\nGraphics3D[\n\t  Module[{...}, \n\t    ...\n\t    (*The full base perimeter now in black*)\n\t    {Black, Line[{{-14.5, -14.5, 29}, {14.5, -14.5, 29}, {14.5, 14.5, 29}, {-14.5, 14.5, 29}, {-14.5, -14.5, 29}}]}\n\t    ...\n\t  ], \n\t  ...\n\t]\n"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "13_comma_operand"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "k->(* 111 *);" ] ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "14_comma_operand"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "k->;" ] ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> Failure[ "...", <| |> ]
    |>,
    TestID -> "15_comma_operand"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "k:=(* 111 *);" ] ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "16_comma_operand"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "k[a_]:=   (* 111 *)   ;" ] ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "17_comma_operand"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "k[,(* 111 *)];" ] ],
    <|
        "FixedCode" -> "k[(* 111 *)];",
        "SafeToEvaluate" -> True
    |>,
    TestID -> "18_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] = (* your existing function definition *)\n"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "19_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =      (* your existing function definition *)    \n"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "20_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\nMixtilinearExcircles[triangle_] := Module[\n  {circumcircle, vertices, excircles},\n  vertices = triangle;\n  circumcircle = Circumsphere[Triangle[vertices]];\n  \n  excircles = Table[\n    Module[{vertex, tangentPoint, excircleCenter, excircleRadius},\n      vertex = vertices[[i]];\n      \n      (* Calculate tangent point on the circumcircle *)\n      tangentPoint = (* Obtain the correct tangent point here *);\n      \n      (* Calculate the center of the excircle *)\n      excircleCenter = (* Calculate the center based on tangent properties *);\n      \n      (* Calculate the radius of the excircle *)\n      excircleRadius = Norm[excircleCenter - tangentPoint];\n      \n      {Circle[excircleCenter, excircleRadius]}\n    ],\n    {i, Length[vertices]}\n  ];\n  \n  excircles\n]\n\n(* Example usage *)\ntriangle = {{0, 0}, {4, 3}, {4, 0}};\nMixtilinearExcircles[triangle]\n"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "21_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     ... (* your existing function definition *)    \n"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "22_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     (* your existing function definition *) ...    \n"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "23_comma_operand"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "f1[x,...,y,]" ] ],
    <|
        "FixedCode" -> "f1[x,...,y]",
        "SafeToEvaluate" -> False
    |>,
    TestID -> "24_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\nranges = Tuples[{{-1, 0, , 1}, Range[-3, 3], Range[-3, 3]}];\n...\n"
        ]
    ],
    <|
        "FixedCode" -> "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n...\n",
        "SafeToEvaluate" -> False
    |>,
    TestID -> "25_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\nranges = Tuples[{{-1, 0, , 1}, Range[-3, 3], Range[-3, 3]}];\n....\n"
        ]
    ],
    <|
        "FixedCode" -> "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n....\n",
        "SafeToEvaluate" -> Failure[ "...", <| |> ]
    |>,
    TestID -> "26_comma_operand"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "\n![Image](attachment://content-22840)\n" ] ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "27_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\n![Comparative Air Speed Velocities](attachment://content-6zubu)\n"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "28_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "                                                                                                                                                                                                                                 * [FindMinimum](paclet:ref/FindMinimum)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 "
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "29_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         * [Polynomial Factoring & Decomposition](paclet:guide/PolynomialFactoring)\n"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "30_comma_operand"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "\n![Sphere](attachment://content-57d9d4f5-650f-4a8c-a4bc-33b4c3a7ec86.png)\n"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "31_comma_operand"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "eq= x==y" ] ],
    <|
        "FixedCode" -> Missing[ "..." ]
    |>,
    TestID -> "1_misc"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "eq= x<=y" ] ],
    <|
        "FixedCode" -> Missing[ "..." ]
    |>,
    TestID -> "2_misc"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "eq= x>=y" ] ],
    <|
        "FixedCode" -> Missing[ "..." ]
    |>,
    TestID -> "3_misc"
]

VerificationTest[
    CodeCheckFix[ "f[{{3}}}" ][ "FixedCode" ],
    "f[{{3}}]",
    TestID -> "1_brackets"
]

VerificationTest[
    CodeCheckFix[ "f[{{3,4}}}" ][ "FixedCode" ],
    "f[{{3,4}}]",
    TestID -> "2_brackets"
]

VerificationTest[
    CodeCheckFix[ "f[{{3,4}]}" ][ "FixedCode" ],
    "f[{{3,4}}]",
    TestID -> "3_brackets"
]

VerificationTest[
    CodeCheckFix[ "g[f[{{3,4}}},\n5]" ][ "FixedCode" ],
    "g[f[{{3,4}}],\n5]",
    TestID -> "4_brackets"
]

VerificationTest[
    CodeCheckFix[ "{g[f[{{3,4}}},5]}" ][ "FixedCode" ],
    "{g[f[{{3,4}}],5]}",
    TestID -> "5_brackets"
]

VerificationTest[
    CodeCheckFix[ "g[f[{{3,4}}},h[}]" ][ "FixedCode" ],
    "g[f[{{3,4}}],h[]]",
    TestID -> "6_brackets"
]

VerificationTest[
    CodeCheckFix[ "g[(dothis;1},2]" ][ "FixedCode" ],
    "g[(dothis;1),2]",
    TestID -> "7_brackets"
]

VerificationTest[
    CodeCheckFix[ "foo[1,2,g[{3]]]" ][ "FixedCode" ],
    "foo[1,2,g[{3}]]",
    TestID -> "8_brackets"
]

VerificationTest[
    CodeCheckFix[ "(1;2;g[3))" ][ "FixedCode" ],
    "(1;2;g[3])",
    TestID -> "9_brackets"
]

VerificationTest[
    CodeCheckFix[ "(1;2;g[3\n   ))" ][ "FixedCode" ],
    "(1;2;g[3\n   ])",
    TestID -> "10_brackets"
]

VerificationTest[
    CodeCheckFix[
        "\nmaxC = 20;\n\tprimTriples = Select[\n\t  With[{m = #1, n = #2}, \n\t    {m ^ 2 - n ^ 2, 2 m n, m ^ 2 + n ^ 2}\n\t  ] & @@@ \n\t  Select[\n\t    Flatten[Table[{m, n}, {n, Floor[Sqrt[maxC / 2]}], {m, n + 1, Floor[Sqrt[maxC]], 2}], 1], \n\t    #[[1]] ^ 2 + #[[2]] ^ 2 <= maxC &\n\t  ], \n\t  Apply[CoprimeQ, #] &\n\t];\n\t\n\tprimTriples\n"
    ][
        "FixedCode"
    ],
    "\nmaxC = 20;\n\tprimTriples = Select[\n\t  With[{m = #1, n = #2}, \n\t    {m ^ 2 - n ^ 2, 2 m n, m ^ 2 + n ^ 2}\n\t  ] & @@@ \n\t  Select[\n\t    Flatten[Table[{m, n}, {n, Floor[Sqrt[maxC / 2]]}, {m, n + 1, Floor[Sqrt[maxC]], 2}], 1], \n\t    #[[1]] ^ 2 + #[[2]] ^ 2 <= maxC &\n\t  ], \n\t  Apply[CoprimeQ, #] &\n\t];\n\t\n\tprimTriples\n",
    TestID -> "11_brackets"
]

VerificationTest[
    CodeCheckFix[ "f[{{3}}]]" ][ "FixedCode" ],
    "f[{{3}}]",
    TestID -> "12_brackets"
]

VerificationTest[
    CodeCheckFix[ "f[{{3}}]]", ("Target" -> "Evaluator") ][ "FixedCode" ],
    "f[{{3}}]",
    TestID -> "13_brackets"
]

VerificationTest[
    CodeCheckFix[ "f[{{3}}}}", ("Target" -> "Evaluator") ][ "FixedCode" ],
    "f[{{3}}]",
    TestID -> "14_brackets"
]

VerificationTest[
    CodeCheckFix[ "f[{{3}}}]", ("Target" -> "Evaluator") ][ "FixedCode" ],
    "f[{{3}}]",
    TestID -> "15_brackets"
]

VerificationTest[
    (CodeCheckFix[ (#1), ("Target" -> "Evaluator") ][ "FixedCode" ] &)[
        "f[a,g[h];b[c]"
    ],
    "f[a,g[h];b[c]]",
    TestID -> "16_brackets"
]

VerificationTest[
    (CodeCheckFix[ (#1), ("Target" -> "Evaluator") ][ "FixedCode" ] &)[
        "Graphics3D[{a,{b},{c,Red},ViewPoint -> {1, -2, 1}]"
    ],
    "Graphics3D[{a,{b},{c,Red}},ViewPoint -> {1, -2, 1}]",
    TestID -> "17_brackets"
]

VerificationTest[
    (CodeCheckFix[ (#1), ("Target" -> "Evaluator") ][ "FixedCode" ] &)[
        "Graphics3D[{a,{b},{c,Red},ViewPoint -> Automatic]"
    ],
    "Graphics3D[{a,{b},{c,Red}},ViewPoint -> Automatic]",
    TestID -> "18_brackets"
]

VerificationTest[
    (CodeCheckFix[ (#1), ("Target" -> "Evaluator") ][ "FixedCode" ] &)[
        "graphics3D[{a,{b},{c,Red},ViewPoint -> Automatic]"
    ],
    "graphics3D[{a,{b},{c,Red}},ViewPoint -> Automatic]",
    TestID -> "19_brackets"
]

VerificationTest[
    (CodeCheckFix[ (#1), ("Target" -> "Evaluator") ][ "FixedCode" ] &)[
        "Graphics3D[{a,b,{c,Red},viewPoint -> Automatic]"
    ],
    "Graphics3D[{a,b,{c,Red}},viewPoint -> Automatic]",
    TestID -> "20_brackets"
]

VerificationTest[
    (CodeCheckFix[ (#1), ("Target" -> "Evaluator") ][ "FixedCode" ] &)[
        "graphics3D[{a,b,{c,Red},viewPoint -> {1, -2, 1}]"
    ],
    "graphics3D[{a,b,{c,Red},viewPoint -> {1, -2, 1}}]",
    TestID -> "21_brackets"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[
        "first_symbol = 1;\nsecond_symbol = 2;\nfirst_symbol + second_symbol"
    ],
    "firstSymbol = 1;\nsecondSymbol = 2;\nfirstSymbol + secondSymbol",
    TestID -> "1_snake"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[
        "x_1 = 1;\nx_2 = 2;\ny_1_2 = f[x_1, x_2]"
    ],
    "x1 = 1;\nx2 = 2;\ny12 = f[x1, x2]",
    TestID -> "2_snake"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "f[my_symbol] = 123" ],
    Missing[ "No errors detected" ],
    TestID -> "3_snake"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "f[my_cool_symbol] = 123" ],
    "f[myCoolSymbol] = 123",
    TestID -> "4_snake"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "my_cool_symbol[a]" ],
    "myCoolSymbol[a]",
    TestID -> "5_snake"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "my_cool_1[a]" ],
    "myCool1[a]",
    TestID -> "6_snake"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "my_cool[a]" ],
    "myCool[a]",
    TestID -> "7_snake"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "my_1[a]" ],
    "my1[a]",
    TestID -> "8_snake"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "my_symbol := 123" ],
    Missing[ "No errors detected" ],
    TestID -> "9_snake"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "my_cool_symbol := 123" ],
    "myCoolSymbol := 123",
    TestID -> "10_snake"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "f[x_1, x_2]" ],
    "f[x1, x2]",
    TestID -> "11_snake"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "x_1=2" ],
    "x1=2",
    TestID -> "12_snake"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[ "f[x_ 1, x_ 2]" ],
    Missing[ "No errors detected" ],
    TestID -> "13_snake"
]

VerificationTest[
    (CodeCheckFix[ (#1) ][ "FixedCode" ] &)[
        "my_offset = 123;\n(* my_string_length is a really neat function *)\nmy_string_length[test_String] := StringLength[test] + my_offset;\nmy_string_length[\"my_string_length\"]"
    ],
    "myOffset = 123;\n(* my_string_length is a really neat function *)\nmyStringLength[test_String] := StringLength[test] + myOffset;\nmyStringLength[\"my_string_length\"]",
    TestID -> "14_snake"
]

VerificationTest[
    CodeCheckFix[ "x_a=1" ][ "FixedCode" ],
    "xA=1",
    TestID -> "15_snake"
]

VerificationTest[
    CodeCheckFix[ "x_a+1" ][ "FixedCode" ],
    Missing[ "No errors detected" ],
    TestID -> "16_snake"
]

VerificationTest[
    CodeCheckFix[ "x_ a =1" ][ "FixedCode" ],
    Missing[ "No pattern", { { "Error", "ImplicitTimesInSet" } } ],
    TestID -> "17_snake"
]

VerificationTest[
    CodeCheckFix[ "x_ a +1" ][ "FixedCode" ],
    Missing[ "No errors detected" ],
    TestID -> "18_snake"
]

VerificationTest[
    CodeCheckFix[ "x_123=1" ][ "FixedCode" ],
    "x123=1",
    TestID -> "19_snake"
]

VerificationTest[
    CodeCheckFix[ "x_123+1" ][ "FixedCode" ],
    "x123+1",
    TestID -> "20_snake"
]

VerificationTest[
    CodeCheckFix[ "x_ 123=1" ][ "FixedCode" ],
    Missing[ "No pattern", { { "Error", "ImplicitTimesInSet" } } ],
    TestID -> "21_snake"
]

VerificationTest[
    CodeCheckFix[ "x_ 123+1" ][ "FixedCode" ],
    Missing[ "No errors detected" ],
    TestID -> "22_snake"
]

VerificationTest[
    CodeCheckFix[ "x_1a=1" ][ "FixedCode" ],
    "x1a=1",
    TestID -> "23_snake"
]

VerificationTest[
    CodeCheckFix[ "x_1a+1" ][ "FixedCode" ],
    "x1a+1",
    TestID -> "24_snake"
]

VerificationTest[
    CodeCheckFix[ "x_1a9=1" ][ "FixedCode" ],
    "x1a9=1",
    TestID -> "25_snake"
]

VerificationTest[
    CodeCheckFix[ "x_1a9+1" ][ "FixedCode" ],
    "x1a9+1",
    TestID -> "26_snake"
]

VerificationTest[
    CodeCheckFix[ "x_1 a9=1" ][ "FixedCode" ],
    "x1 a9=1",
    TestID -> "27_snake"
]

VerificationTest[
    CodeCheckFix[ "x_1 a9+1" ][ "FixedCode" ],
    "x1 a9+1",
    TestID -> "28_snake"
]

VerificationTest[
    CodeCheckFix[ "x_1a 9+1" ][ "FixedCode" ],
    "x1a 9+1",
    TestID -> "29_snake"
]

VerificationTest[
    CodeCheckFix[ "x_1_2=1" ][ "FixedCode" ],
    "x12=1",
    TestID -> "30_snake"
]

VerificationTest[
    CodeCheckFix[ "x_1_2:=1" ][ "FixedCode" ],
    "x12:=1",
    TestID -> "31_snake"
]

VerificationTest[
    CodeCheckFix[ "x__1___2:=1" ][ "FixedCode" ],
    "x12:=1",
    TestID -> "32_snake"
]

VerificationTest[
    CodeCheckFix[ "x___a_1__2b_CC__2:=1" ][ "FixedCode" ],
    "xA12bCC2:=1",
    TestID -> "33_snake"
]

VerificationTest[
    CodeCheckFix[ "x_a=1; y__b_2_d=2;x_a + x_b + x__c_1" ][ "FixedCode" ],
    "xA=1; yB2D=2;xA + x_b + xC1",
    TestID -> "34_snake"
]

VerificationTest[
    CodeCheckFix[
        "2+3;my_1[x_] = 1*my_code[x_];111111111;my_1a_b____c1_2[x_]:=33, a_b=2; a_b+2; MatchQ[{},y_List]; y_ y_Plus"
    ][
        "FixedCode"
    ],
    "2+3;my1[x_] = 1*myCode[x_];111111111;my1aBC12[x_]:=33, aB=2; aB+2; MatchQ[{},y_List]; y_ y_Plus",
    TestID -> "35_snake"
]

VerificationTest[
    CodeCheckFix[ "I_n_a[n_,x_,b_]:=n+x" ][ "FixedCode" ],
    "INA[n_,x_,b_]:=n+x",
    TestID -> "36_snake"
]

VerificationTest[
    CodeCheckFix[ "I_1[n_,x_,b_]:=n+x" ][ "FixedCode" ],
    "I1[n_,x_,b_]:=n+x",
    TestID -> "37_snake"
]

VerificationTest[
    CodeCheckFix[ "f[x_,x_a_]:=x_a+1 (*x_a_*); x_a_ + x_a" ][ "FixedCode" ],
    "f[x_,xA_]:=xA+1 (*x_a_*); xA + x_a",
    TestID -> "38_snake"
]

VerificationTest[
    Function[
        Select[
            #1,
            Function[
                Not[
                    MemberQ[
                        {
                            {
                                "AmpereSquareMeter",
                                "Quantity[1, \"Ampere\"*\"SquareMeters\"]"
                            },
                            { "Attofarad", "Quantity[1, \"Attofarads\"]" },
                            {
                                "AttogramPerCubicMeter",
                                "Quantity[1, \"Attograms\"/\"CubicMeters\"]"
                            },
                            { "Attohenry", Missing[ "Unknown unit", "Attohenry" ] },
                            { "Attolux", Missing[ "No errors detected" ] },
                            { "Attosiemens", Missing[ "No errors detected" ] },
                            { "Attoweber", "Quantity[1, \"Attowebers\"]" },
                            {
                                "BecquerelPerGram",
                                "Quantity[1, \"Becquerel\"/\"Grams\"]"
                            },
                            {
                                "CandelaPerSquareMeter",
                                "Quantity[1, \"Candelas\"/\"SquareMeters\"]"
                            },
                            {
                                "CentigalPerSecond",
                                Missing[ "Unknown unit", "CentigalPerSecond" ]
                            },
                            { "Centilux", Missing[ "No errors detected" ] },
                            {
                                "CentinewtonMeter",
                                "Quantity[1, \"Centinewtons\"*\"Meter\"]"
                            },
                            {
                                "CentinewtonSecond",
                                "Quantity[1, \"Centinewtons\"*\"Second\"]"
                            },
                            { "Centitesla", "Quantity[1, \"Centiteslas\"]" },
                            {
                                "CoulombPerKilogram",
                                "Quantity[1, \"Coulomb\"/\"Kilogram\"]"
                            },
                            {
                                "CubicMetersPerSecond",
                                "Quantity[1, \"CubicMeters\"/\"Second\"]"
                            },
                            { "Decamole", Missing[ "Unknown unit", "Decamole" ] },
                            { "Decibel", Missing[ "Unknown unit", "Decibel" ] },
                            {
                                "DecibelPerMeter",
                                Missing[ "Unknown unit", "DecibelPerMeter" ]
                            },
                            {
                                "DeciliterPerMinute",
                                "Quantity[1, \"Deciliters\"/\"Minute\"]"
                            },
                            {
                                "DecilumenMinute",
                                "Quantity[1, \"Decilumens\"*\"Minute\"]"
                            },
                            {
                                "DeciluxSecond",
                                "Quantity[1, \"Decilux\"*\"Second\"]"
                            },
                            {
                                "Deciparsec",
                                Missing[ "Unknown unit", "Deciparsec" ]
                            },
                            { "Decipascal", "Quantity[1, \"Decipascals\"]" },
                            {
                                "DecipascalSecond",
                                "Quantity[1, \"Decipascals\"*\"Second\"]"
                            },
                            {
                                "DecivoltPerMeter",
                                "Quantity[1, \"Decivolts\"/\"Meter\"]"
                            },
                            { "Degrees", Missing[ "No errors detected" ] },
                            { "ErgPerGram", "Quantity[1, \"Ergs\"/\"Grams\"]" },
                            {
                                "FemtoampereSecond",
                                "Quantity[1, \"Femtoamperes\"*\"Second\"]"
                            },
                            {
                                "FemtocoulombSeconds",
                                "Quantity[1, \"Femtocoulombs\"*\"Seconds\"]"
                            },
                            {
                                "FemtohenryPerMeter",
                                Missing[ "Unknown unit", "FemtohenryPerMeter" ]
                            },
                            { "Femtohertz", Missing[ "No errors detected" ] },
                            { "Femtojoule", "Quantity[1, \"Femtojoules\"]" },
                            {
                                "FemtojoulePerKelvin",
                                "Quantity[1, \"Femtojoules\"/\"Kelvin\"]"
                            },
                            {
                                "FemtolambertSecond",
                                Missing[ "Unknown unit", "FemtolambertSecond" ]
                            },
                            { "Femtoliter", "Quantity[1, \"Femtoliters\"]" },
                            {
                                "FemtomolePerSecond",
                                "Quantity[1, \"Femtomoles\"/\"Second\"]"
                            },
                            {
                                "FemtonewtonMeter",
                                "Quantity[1, \"Femtonewtons\"*\"Meter\"]"
                            },
                            { "Femtosievert", "Quantity[1, \"Femtosieverts\"]" },
                            { "Femtotesla", "Quantity[1, \"Femtoteslas\"]" },
                            { "Gigacurie", "Quantity[1, \"Gigacuries\"]" },
                            { "Gigafurlong", "Quantity[1, \"Gigafurlongs\"]" },
                            { "Gigahertz", Missing[ "No errors detected" ] },
                            { "Gigapascal", "Quantity[1, \"Gigapascals\"]" },
                            {
                                "GigavoltSecond",
                                "Quantity[1, \"Gigavolts\"*\"Second\"]"
                            },
                            {
                                "GramPerCentimeterCubed",
                                "Quantity[1, \"Grams\"/\"Centimeters\"^3]"
                            },
                            {
                                "GrayPerSecond",
                                "Quantity[1, \"Gray\"/\"Second\"]"
                            },
                            { "Hectohertz", Missing[ "No errors detected" ] },
                            { "Hectokatal", "Quantity[1, \"Hectokatals\"]" },
                            { "Hectokelvin", "Quantity[1, \"Hectokelvins\"]" },
                            {
                                "Hectolambert",
                                Missing[ "Unknown unit", "Hectolambert" ]
                            },
                            { "Hectolumen", "Quantity[1, \"Hectolumens\"]" },
                            {
                                "HectoluxSecond",
                                "Quantity[1, \"Hectolux\"*\"Second\"]"
                            },
                            {
                                "HectometerPerSecond",
                                "Quantity[1, \"Hectometers\"/\"Second\"]"
                            },
                            {
                                "HectopascalSecond",
                                "Quantity[1, \"Hectopascals\"*\"Second\"]"
                            },
                            { "Hectowatt", "Quantity[1, \"Hectowatts\"]" },
                            {
                                "HenryPerMeter",
                                "Quantity[1, \"Henry\"/\"Meter\"]"
                            },
                            {
                                "HertzSecond",
                                "Quantity[1, \"Hertz\"*\"Second\"]"
                            },
                            {
                                "JoulePerCoulomb",
                                "Quantity[1, \"Joule\"/\"Coulomb\"]"
                            },
                            {
                                "JoulePerKelvin",
                                "Quantity[1, \"Joule\"/\"Kelvin\"]"
                            },
                            { "Katal", Missing[ "No errors detected" ] },
                            {
                                "KelvinPerWatt",
                                "Quantity[1, \"Kelvin\"/\"Watt\"]"
                            },
                            {
                                "KiloampereHour",
                                "Quantity[1, \"Hour\"*\"Kiloamperes\"]"
                            },
                            { "Kilofurlongs", Missing[ "No errors detected" ] },
                            {
                                "KilogaussSecond",
                                "Quantity[1, \"Kilogauss\"*\"Second\"]"
                            },
                            {
                                "KilogramsPerCubicMeter",
                                Missing[ "No errors detected" ]
                            },
                            {
                                "KilogramsPerMetersCubed",
                                "Quantity[1, \"Kilograms\"/\"Meters\"^3]"
                            },
                            {
                                "KilojoulePerMole",
                                "Quantity[1, \"Kilojoules\"/\"Mole\"]"
                            },
                            {
                                "KiloluxPerSteradian",
                                "Quantity[1, \"Kilolux\"/\"Steradian\"]"
                            },
                            { "Kilomole", "Quantity[1, \"Kilomoles\"]" },
                            {
                                "KilomolePerSecond",
                                "Quantity[1, \"Kilomoles\"/\"Second\"]"
                            },
                            { "Kiloohms", Missing[ "No errors detected" ] },
                            {
                                "KilopascalPerMeter",
                                "Quantity[1, \"Kilopascals\"/\"Meter\"]"
                            },
                            {
                                "KilowattHour",
                                "Quantity[1, \"Hour\"*\"Kilowatts\"]"
                            },
                            {
                                "KilowattHours",
                                "Quantity[1, \"Hours\"*\"Kilowatts\"]"
                            },
                            {
                                "KiloweberPerSecond",
                                "Quantity[1, \"Kilowebers\"/\"Second\"]"
                            },
                            { "LuxSecond", "Quantity[1, \"Lux\"*\"Second\"]" },
                            {
                                "Megabecquerel",
                                "Quantity[1, \"Megabecquerels\"]"
                            },
                            {
                                "MegaergPerKelvin",
                                Missing[ "Unknown unit", "MegaergPerKelvin" ]
                            },
                            { "Megaergs", Missing[ "Unknown unit", "Megaergs" ] },
                            { "Megagauss", Missing[ "No errors detected" ] },
                            {
                                "MegagramPerLiter",
                                "Quantity[1, \"Megagrams\"/\"Liters\"]"
                            },
                            {
                                "MeganewtonMeter",
                                "Quantity[1, \"Meganewtons\"*\"Meter\"]"
                            },
                            {
                                "Megaoersted",
                                Missing[ "Unknown unit", "Megaoersted" ]
                            },
                            {
                                "MegaohmCentimeter",
                                "Quantity[1, \"Centimeters\"*\"Megaohms\"]"
                            },
                            { "Megaparsec", "Quantity[1, \"Megaparsecs\"]" },
                            {
                                "MegatonPerSecond",
                                Missing[ "Unknown unit", "MegatonPerSecond" ]
                            },
                            {
                                "MeterPerSecondSquared",
                                "Quantity[1, \"Meter\"/\"Second\"^2]"
                            },
                            { "Microbarns", Missing[ "No errors detected" ] },
                            { "Microcurie", "Quantity[1, \"Microcuries\"]" },
                            {
                                "Microdarcy",
                                Missing[ "Unknown unit", "Microdarcy" ]
                            },
                            { "Microgray", "Quantity[1, \"Micrograys\"]" },
                            {
                                "MicrograyPerSecond",
                                "Quantity[1, \"Micrograys\"/\"Second\"]"
                            },
                            {
                                "Microkayser",
                                Missing[ "Unknown unit", "Microkayser" ]
                            },
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
                            {
                                "MillimolePerGram",
                                "Quantity[1, \"Millimoles\"/\"Grams\"]"
                            },
                            {
                                "MillionShortTons",
                                "Quantity[1, \"Million\"*\"ShortTons\"]"
                            },
                            {
                                "MillipascalSeconds",
                                "Quantity[1, \"Millipascals\"*\"Seconds\"]"
                            },
                            { "Millirad", "Quantity[1, \"Millirads\"]" },
                            { "Millisiemens", Missing[ "No errors detected" ] },
                            {
                                "MilliteslaMeter",
                                "Quantity[1, \"Meter\"*\"Milliteslas\"]"
                            },
                            {
                                "MolePerLiter",
                                "Quantity[1, \"Mole\"/\"Liters\"]"
                            },
                            {
                                "NanobarnSecond",
                                "Quantity[1, \"Nanobarns\"*\"Second\"]"
                            },
                            {
                                "NanofaradSecond",
                                "Quantity[1, \"Nanofarads\"*\"Second\"]"
                            },
                            { "Nanogray", "Quantity[1, \"Nanograys\"]" },
                            {
                                "NanometerPerPicosecond",
                                "Quantity[1, \"Nanometers\"/\"Picoseconds\"]"
                            },
                            {
                                "NanomolePerLiter",
                                "Quantity[1, \"Nanomoles\"/\"Liters\"]"
                            },
                            { "Nanopascal", "Quantity[1, \"Nanopascals\"]" },
                            { "Nanoradian", "Quantity[1, \"Nanoradians\"]" },
                            {
                                "NanosecondPerMeter",
                                "Quantity[1, \"Nanoseconds\"/\"Meter\"]"
                            },
                            { "Nanostoke", Missing[ "Unknown unit", "Nanostoke" ] },
                            { "Nanotesla", "Quantity[1, \"Nanoteslas\"]" },
                            {
                                "NanoteslaSecond",
                                "Quantity[1, \"Nanoteslas\"*\"Second\"]"
                            },
                            {
                                "NewtonMeter",
                                "Quantity[1, \"Meter\"*\"Newton\"]"
                            },
                            {
                                "NewtonSecond",
                                "Quantity[1, \"Newton\"*\"Second\"]"
                            },
                            { "OhmMeter", "Quantity[1, \"Meter\"*\"Ohm\"]" },
                            {
                                "Pascalliters",
                                Missing[ "Unknown unit", "Pascalliters" ]
                            },
                            {
                                "PascalSecond",
                                "Quantity[1, \"Pascal\"*\"Second\"]"
                            },
                            { "Petaampere", "Quantity[1, \"Petaamperes\"]" },
                            { "Petabyte", "Quantity[1, \"Petabytes\"]" },
                            { "Petagram", "Quantity[1, \"Petagrams\"]" },
                            { "Petalux", Missing[ "No errors detected" ] },
                            {
                                "PetameterPerSecond",
                                "Quantity[1, \"Petameters\"/\"Second\"]"
                            },
                            { "Petapascal", "Quantity[1, \"Petapascals\"]" },
                            { "Petasiemens", Missing[ "No errors detected" ] },
                            { "Picoampere", "Quantity[1, \"Picoamperes\"]" },
                            {
                                "PicogramPerMilliliter",
                                "Quantity[1, \"Picograms\"/\"Milliliters\"]"
                            },
                            { "Picogray", "Quantity[1, \"Picograys\"]" },
                            {
                                "PicoohmMeter",
                                "Quantity[1, \"Meter\"*\"Picoohms\"]"
                            },
                            { "Picotorr", Missing[ "Unknown unit", "Picotorr" ] },
                            { "Picowebers", Missing[ "No errors detected" ] },
                            {
                                "RoodPerSecond",
                                "Quantity[1, \"Roods\"/\"Second\"]"
                            },
                            { "SiemensPerMeter", Missing[ "No errors detected" ] },
                            {
                                "SievertPerHour",
                                "Quantity[1, \"Sievert\"/\"Hour\"]"
                            },
                            { "Terabit", "Quantity[1, \"Terabits\"]" },
                            {
                                "TeracandelaHour",
                                "Quantity[1, \"Hour\"*\"Teracandelas\"]"
                            },
                            { "Teragram", "Quantity[1, \"Teragrams\"]" },
                            { "Terajoule", "Quantity[1, \"Terajoules\"]" },
                            {
                                "TeslaSecond",
                                "Quantity[1, \"Second\"*\"Tesla\"]"
                            },
                            { "Tons", Missing[ "Unknown unit", "Tons" ] },
                            { "VoltPerMeter", "Quantity[1, \"Volt\"/\"Meter\"]" },
                            {
                                "WattPerSteradian",
                                "Quantity[1, \"Watt\"/\"Steradian\"]"
                            },
                            { "Year", Missing[ "No errors detected" ] },
                            { "Yoctosecond", "Quantity[1, \"Yoctoseconds\"]" },
                            { "Yoctosiemens", Missing[ "No errors detected" ] },
                            { "Yoctowatt", "Quantity[1, \"Yoctowatts\"]" },
                            { "Yottabyte", "Quantity[1, \"Yottabytes\"]" },
                            {
                                "YottameterCube",
                                "Quantity[1, \"Cubes\"*\"Yottameters\"]"
                            },
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
            Function[
                {
                    #1,
                    CodeCheckFix[
                        ToString[ Unevaluated[ Quantity[ 1, #1 ] ], InputForm ]
                    ][
                        "FixedCode"
                    ]
                }
            ],
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
    TestID -> "1_units"
]

VerificationTest[
    SameQ[
        Function[
            {
                Times @@@ #1,
                StringCases[
                    Shortest[ "Quantity[" ~~ t__ ~~ "," ~~ v__ ~~ "]" ] :>
                        ToExpression[ StringTrim[ v ] ]
                ][
                    Map[
                        Function[
                            CodeCheckFix[
                                ToString[
                                    Unevaluated[ Quantity[ 1, #1 ] ],
                                    InputForm
                                ]
                            ][
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
                    {
                        "PerchesLength",
                        "Kerats",
                        "Femtohertz",
                        "Zm",
                        "IndianMustis",
                        "Pouces"
                    },
                    {
                        "Droits",
                        "BritishThermalUnitsMean",
                        "PiedsDuRoi",
                        "Kilofeet",
                        "Dekayards"
                    },
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
    TestID -> "2_units"
]

VerificationTest[
    CodeCheckFix[ "Quantity[1, \"Meter\"]" ][ "FixedCode" ],
    Missing[ "No errors detected" ],
    TestID -> "3_units"
]

VerificationTest[
    CodeCheckFix[ "Quantity[1, \"AmpereSquareMeter\"]" ][ "FixedCode" ],
    "Quantity[1, \"Ampere\"*\"SquareMeters\"]",
    TestID -> "4_units"
]

VerificationTest[
    CodeCheckFix[ "Quantity[1, \"DecibelPerMeter\"]" ][ "FixedCode" ],
    Missing[ "Unknown unit", "DecibelPerMeter" ],
    TestID -> "5_units"
]

VerificationTest[
    CodeCheckFix[ "Quantity[1, \"Attohenry\"]" ][ "FixedCode" ],
    Missing[ "Unknown unit", "Attohenry" ],
    TestID -> "6_units"
]

VerificationTest[
    $UserDefinedFunctionsQ = <| |>,
    <| |>,
    TestID -> "1_suspiciousSymbols"
]

VerificationTest[
    Clear[ MyFunc ];
    "MyFunc: cleared",
    "MyFunc: cleared",
    TestID -> "2_suspiciousSymbols"
]

VerificationTest[
    finalState[ (CodeCheckFix[ #1 ] &)[ "1+1;MyFunc[22]" ] ],
    {
        "SuspiciousFunctionSymbol",
        "Suspicious Function Name: MyFunc",
        "WarningChatbook",
        <|
            ConfidenceLevel -> 2,
            CodeParser`Source -> { 5, 14 }
        |>
    },
    TestID -> "3_suspiciousSymbols"
]

VerificationTest[
    Clear[ MyContext`Func ];
    "MyContext`Func: cleared",
    "MyContext`Func: cleared",
    TestID -> "4_suspiciousSymbols"
]

VerificationTest[
    finalState[ (CodeCheckFix[ #1 ] &)[ "1+1;MyContext`Func[22]" ] ],
    {
        "SuspiciousFunctionSymbol",
        "Suspicious Function Name: MyContext`Func",
        "WarningChatbook",
        <|
            ConfidenceLevel -> 2,
            CodeParser`Source -> { 5, 22 }
        |>
    },
    TestID -> "5_suspiciousSymbols"
]

VerificationTest[
    $UserDefinedFunctionsQ,
    <| |>,
    TestID -> "6_suspiciousSymbols"
]

VerificationTest[
    CodeCheckFix[ "1+1;myContext`Func[22]" ][ "ErrorsDetected" ],
    False,
    TestID -> "7_suspiciousSymbols"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyContext`func[22]" ][ "ErrorsDetected" ],
    False,
    TestID -> "8_suspiciousSymbols"
]

VerificationTest[
    Clear[ MyFunc ];
    "MyFunc: cleared",
    "MyFunc: cleared",
    TestID -> "9_suspiciousSymbols"
]

VerificationTest[
    MyFunc[ x_ ] := x^2;
    "MyFunc: defined",
    "MyFunc: defined",
    TestID -> "10_suspiciousSymbols"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyFunc[22]" ][ "ErrorsDetected" ],
    False,
    TestID -> "11_suspiciousSymbols"
]

VerificationTest[
    $UserDefinedFunctionsQ,
    <| |>,
    TestID -> "12_suspiciousSymbols"
]

VerificationTest[
    Clear[ MyFunc ];
    "MyFunc: cleared",
    "MyFunc: cleared",
    TestID -> "13_suspiciousSymbols"
]

VerificationTest[


    MyFunc /:
        doIt[ MyFunc[ 1 ] ] := 3;

    "MyFunc: defined",
    "MyFunc: defined",
    TestID -> "14_suspiciousSymbols"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyFunc[22]" ][ "ErrorsDetected" ],
    False,
    TestID -> "15_suspiciousSymbols"
]

VerificationTest[
    $UserDefinedFunctionsQ,
    <| |>,
    TestID -> "16_suspiciousSymbols"
]

VerificationTest[
    Clear[ MyFunc ];
    "MyFunc: cleared",
    "MyFunc: cleared",
    TestID -> "17_suspiciousSymbols"
]

VerificationTest[
    MyFunc = 2;
    "MyFunc: defined",
    "MyFunc: defined",
    TestID -> "18_suspiciousSymbols"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyFunc[22]" ][ "ErrorsDetected" ],
    False,
    TestID -> "19_suspiciousSymbols"
]

VerificationTest[
    Clear[ MyFunc ];
    "MyFunc: cleared",
    "MyFunc: cleared",
    TestID -> "20_suspiciousSymbols"
]

VerificationTest[
    finalState[ CodeCheckFix[ "1+1;MyFunc[22];" ] ],
    {
        "SuspiciousFunctionSymbol",
        "Suspicious Function Name: MyFunc",
        "WarningChatbook",
        <|
            ConfidenceLevel -> 2,
            CodeParser`Source -> { 5, 14 }
        |>
    },
    TestID -> "21_suspiciousSymbols"
]

VerificationTest[
    $UserDefinedFunctionsQ,
    <| |>,
    TestID -> "22_suspiciousSymbols"
]

VerificationTest[
    $UserDefinedFunctionsQ = <| |>,
    <| |>,
    TestID -> "23_suspiciousSymbols"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyFunc[22];MyFunc[x_]:=x+1" ][ "ErrorsDetected" ],
    False,
    TestID -> "24_suspiciousSymbols"
]

VerificationTest[
    $UserDefinedFunctionsQ,
    <|
        "MyFunc" -> True
    |>,
    TestID -> "25_suspiciousSymbols"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyFunc[22];" ][ "ErrorsDetected" ],
    False,
    TestID -> "26_suspiciousSymbols"
]

VerificationTest[
    $UserDefinedFunctionsQ = <| |>,
    <| |>,
    TestID -> "27_suspiciousSymbols"
]

VerificationTest[
    Remove[ MyFunc ];
    "MyFunc: removed",
    "MyFunc: removed",
    TestID -> "28_suspiciousSymbols"
]

VerificationTest[
    finalState[ CodeCheckFix[ "1+1;MyFuncSub[22][33];" ] ],
    {
        "SuspiciousFunctionSymbol",
        "Suspicious Function Name: MyFuncSub",
        "WarningChatbook",
        <|
            ConfidenceLevel -> 2,
            CodeParser`Source -> { 5, 17 }
        |>
    },
    TestID -> "29_suspiciousSymbols"
]

VerificationTest[
    $UserDefinedFunctionsQ,
    <| |>,
    TestID -> "30_suspiciousSymbols"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyFuncSub[22][33];MyFuncSub[x_][y_]:=x+y" ][
        "ErrorsDetected"
    ],
    False,
    TestID -> "31_suspiciousSymbols"
]

VerificationTest[
    $UserDefinedFunctionsQ,
    <|
        "MyFuncSub" -> True
    |>,
    TestID -> "32_suspiciousSymbols"
]

VerificationTest[
    CodeCheckFix[ "1+1;MyFuncSet[22];MyFuncSet[x_]=x" ][ "ErrorsDetected" ],
    False,
    TestID -> "33_suspiciousSymbols"
]

VerificationTest[
    $UserDefinedFunctionsQ,
    <|
        "MyFuncSub" -> True,
        "MyFuncSet" -> True
    |>,
    TestID -> "34_suspiciousSymbols"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "aaa+1; (*AAAA exp(2u*) BBB*) 32" ] ],
    <|
        "FixedCode" -> "aaa+1; (*AAAA exp(2u* ) BBB*) 32",
        "SafeToEvaluate" -> True
    |>,
    TestID -> "1_trailingStar"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[ "(*aa+1 AAAA exp(2u*) exp(2u*) - f(k*) BB*) (*32*) 33" ]
    ],
    <|
        "FixedCode" -> "(*aa+1 AAAA exp(2u* ) exp(2u* ) - f(k* ) BB*) (*32*) 33",
        "SafeToEvaluate" -> True
    |>,
    TestID -> "2_trailingStar"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "(*aa+1 (*AAAA exp(2u*) exp(2u*) - f(k*) BB*); (*32*) 33*)"
        ]
    ],
    <|
        "FixedCode" -> "(*aa+1 (*AAAA exp(2u* ) exp(2u* ) - f(k* ) BB*); (*32*) 33*)",
        "SafeToEvaluate" -> True
    |>,
    TestID -> "3_trailingStar"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "(*aa+1*) (*AAAA exp(2u*) exp(a,b,c*,2u*) - f(k*) BB*)1; Print[\"f(K*)\"];(*32*) 33"
        ]
    ],
    <|
        "FixedCode" -> "(*aa+1*) (*AAAA exp(2u* ) exp(a,b,c*,2u* ) - f(k* ) BB*)1; Print[\"f(K*)\"];(*32*) 33",
        "SafeToEvaluate" -> True
    |>,
    TestID -> "4_trailingStar"
]

VerificationTest[
    mainInfo[ CodeCheckFix[ "1+1 (*hello*) f(u*) (*dd*)" ] ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "5_trailingStar"
]

VerificationTest[
    mainInfo[
        CodeCheckFix[
            "(*aa+1 (* AAAA exp(2u*) exp(2u*) - f(k*) BB*); (*32*) 33"
        ]
    ],
    <|
        "FixedCode" -> Missing[ "..." ],
        "SafeToEvaluate" -> False
    |>,
    TestID -> "6_trailingStar"
]

VerificationTest[
    CodeCheckFix[ "1+1 (* (*hello*) f(u*) (*dd*)" ][ "ErrorsDetected" ],
    False,
    TestID -> "7_trailingStar"
]

VerificationTest[
    Clear[ mainInfo, finalState ];
    "clear formatting helpers",
    "clear formatting helpers",
    TestID -> "1_cleaning"
]
