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
    CodeCheckFix[ "f1[x,y,]" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedCode" -> "f1[x,y]",
        "FixedPatterns" -> { { { "Error", "Comma" } } },
        "OriginalCode" -> "f1[x,y,]"
    },
    SameTest -> MatchQ,
    TestID   -> "1_CodeCheckFix_UT@@Tests/CodeCheck.wlt:31,1-46,2"
]

VerificationTest[
    CodeCheckFix[ "f1[x,y,]," ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> False,
        "FixedCode" -> Missing[ "Pattern not handled", { { "Error", "Comma" }, { "Error", "Comma" }, { "Fatal", "CommaTopLevel" } } ],
        "FixedPatterns" -> { { { "Error", "Comma" }, { "Error", "Comma" }, { "Fatal", "CommaTopLevel" } } },
        "OriginalCode" -> "f1[x,y,],"
    },
    SameTest -> MatchQ,
    TestID   -> "2_CodeCheckFix_UT@@Tests/CodeCheck.wlt:48,1-63,2"
]

VerificationTest[
    CodeCheckFix[ "f1[x,y,(*comment*)]" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "f1[x,y,(*comment*)]",
        "FixedPatterns" -> { { { "Error", "Comma" } } },
        "OriginalCode" -> "f1[x,y,(*comment*)]"
    },
    SameTest -> MatchQ,
    TestID   -> "3_CodeCheckFix_UT@@Tests/CodeCheck.wlt:65,1-80,2"
]

VerificationTest[
    CodeCheckFix[ codestring = "f1[x,y,(*comment*),z]" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "f1[x,y,(*comment*),z]",
        "FixedPatterns" -> { { { "Error", "Comma" } } },
        "OriginalCode" -> "f1[x,y,(*comment*),z]"
    },
    SameTest -> MatchQ,
    TestID   -> "4_CodeCheckFix_UT@@Tests/CodeCheck.wlt:82,1-97,2"
]

VerificationTest[
    CodeCheckFix[ "f1[x,y,,(*comment*),]" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success" -> True,
        "TotalFixes" -> 2,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "f1[x,y,(*comment*)]",
        "FixedPatterns" -> { { { "Error", "Comma" }, { "Error", "Comma" }, { "Error", "Comma" } } },
        "OriginalCode" -> "f1[x,y,,(*comment*),]"
    },
    SameTest -> MatchQ,
    TestID   -> "5_CodeCheckFix_UT@@Tests/CodeCheck.wlt:99,1-114,2"
]

VerificationTest[
    CodeCheckFix[ "f1[x,y,(*comment*)];g[x,y,z]" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "f1[x,y,(*comment*)];g[x,y,z]",
        "FixedPatterns" -> { { { "Error", "Comma" } } },
        "OriginalCode" -> "f1[x,y,(*comment*)];g[x,y,z]"
    },
    SameTest -> MatchQ,
    TestID   -> "6_CodeCheckFix_UT@@Tests/CodeCheck.wlt:116,1-131,2"
]

VerificationTest[
    CodeCheckFix[ "f1[{x,y,}z]" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedCode" -> "f1[{x,y}z]",
        "FixedPatterns" -> { { { "Error", "Comma" } } },
        "OriginalCode" -> "f1[{x,y,}z]"
    },
    SameTest -> MatchQ,
    TestID   -> "7_CodeCheckFix_UT@@Tests/CodeCheck.wlt:133,1-148,2"
]

VerificationTest[
    CodeCheckFix[ "{f1[x,,y]}" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedCode" -> "{f1[x,y]}",
        "FixedPatterns" -> { { { "Error", "Comma" } } },
        "OriginalCode" -> "{f1[x,,y]}"
    },
    SameTest -> MatchQ,
    TestID   -> "8_CodeCheckFix_UT@@Tests/CodeCheck.wlt:150,1-165,2"
]

VerificationTest[
    CodeCheckFix[ "{f1[,x]}" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedCode" -> "{f1[x]}",
        "FixedPatterns" -> { { { "Error", "Comma" } } },
        "OriginalCode" -> "{f1[,x]}"
    },
    SameTest -> MatchQ,
    TestID   -> "9_CodeCheckFix_UT@@Tests/CodeCheck.wlt:167,1-182,2"
]

VerificationTest[
    CodeCheckFix[ "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n...\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n...\n",
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n...\n"
    },
    SameTest -> MatchQ,
    TestID   -> "10_CodeCheckFix_UT@@Tests/CodeCheck.wlt:184,1-199,2"
]

VerificationTest[
    CodeCheckFix[ "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n    ...\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n    ...\n",
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n    ...\n"
    },
    SameTest -> MatchQ,
    TestID   -> "11_CodeCheckFix_UT@@Tests/CodeCheck.wlt:201,1-216,2"
]

VerificationTest[
    CodeCheckFix[ "\nminValue = NMinimize[{f[k], constraint1, constraint2, ...}, {k, kMin, kMax}]\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "\nminValue = NMinimize[{f[k], constraint1, constraint2, ...}, {k, kMin, kMax}]\n",
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "\nminValue = NMinimize[{f[k], constraint1, constraint2, ...}, {k, kMin, kMax}]\n"
    },
    SameTest -> MatchQ,
    TestID   -> "12_CodeCheckFix_UT@@Tests/CodeCheck.wlt:218,1-233,2"
]

VerificationTest[
    CodeCheckFix[ "\nlist = {a1, a2, a3, ..., an};  (* replace with your list of numbers *)\nmodResults = Mod[Rest[list], Most[list]]\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "\nlist = {a1, a2, a3, ..., an};  (* replace with your list of numbers *)\nmodResults = Mod[Rest[list], Most[list]]\n",
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "\nlist = {a1, a2, a3, ..., an};  (* replace with your list of numbers *)\nmodResults = Mod[Rest[list], Most[list]]\n"
    },
    SameTest -> MatchQ,
    TestID   -> "13_CodeCheckFix_UT@@Tests/CodeCheck.wlt:235,1-250,2"
]

VerificationTest[
    CodeCheckFix[ "\n(* Define your function *)\n\tf[k_] := Module[{...}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "\n(* Define your function *)\n\tf[k_] := Module[{...}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n",
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" }, { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "\n(* Define your function *)\n\tf[k_] := Module[{...}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n"
    },
    SameTest -> MatchQ,
    TestID   -> "14_CodeCheckFix_UT@@Tests/CodeCheck.wlt:252,1-267,2"
]

VerificationTest[
    CodeCheckFix[ "\nGraphics3D[\n\t  Module[{...}, \n\t    ...\n\t    (*The full base perimeter now in black*)\n\t    {Black, Line[{{-14.5, -14.5, 29}, {14.5, -14.5, 29}, {14.5, 14.5, 29}, {-14.5, 14.5, 29}, {-14.5, -14.5, 29}}]}\n\t    ...\n\t  ], \n\t  ...\n\t]\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> False,
        "FixedCode" ->
            Missing[
                "Pattern not handled",
                {
                    { "Error", "ImplicitTimesAcrossLines" },
                    { "Fatal", "ExpectedOperand" },
                    { "Fatal", "ExpectedOperand" },
                    { "Fatal", "ExpectedOperand" }
                }
            ],
        "FixedPatterns" -> { { { "Error", "ImplicitTimesAcrossLines" }, { "Fatal", "ExpectedOperand" }, { "Fatal", "ExpectedOperand" }, { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "\nGraphics3D[\n\t  Module[{...}, \n\t    ...\n\t    (*The full base perimeter now in black*)\n\t    {Black, Line[{{-14.5, -14.5, 29}, {14.5, -14.5, 29}, {14.5, 14.5, 29}, {-14.5, 14.5, 29}, {-14.5, -14.5, 29}}]}\n\t    ...\n\t  ], \n\t  ...\n\t]\n"
    },
    SameTest -> MatchQ,
    TestID   -> "15_CodeCheckFix_UT@@Tests/CodeCheck.wlt:269,1-293,2"
]

VerificationTest[
    CodeCheckFix[ "k->(* 111 *);" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "k->(* 111 *);",
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "k->(* 111 *);"
    },
    SameTest -> MatchQ,
    TestID   -> "16_CodeCheckFix_UT@@Tests/CodeCheck.wlt:295,1-310,2"
]

VerificationTest[
    CodeCheckFix[ "k->;" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> False,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> Missing[ ],
        "SafeToEvaluate" -> Missing[ ],
        "FixedCode" -> Missing[ "Expected Operand (no place holder(s) detected)" ],
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "k->;"
    },
    SameTest -> MatchQ,
    TestID   -> "17_CodeCheckFix_UT@@Tests/CodeCheck.wlt:312,1-327,2"
]

VerificationTest[
    CodeCheckFix[ "k:=(* 111 *);" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "k:=(* 111 *);",
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "k:=(* 111 *);"
    },
    SameTest -> MatchQ,
    TestID   -> "18_CodeCheckFix_UT@@Tests/CodeCheck.wlt:329,1-344,2"
]

VerificationTest[
    CodeCheckFix[ "k[a_]:=   (* 111 *)   ;" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "k[a_]:=   (* 111 *)   ;",
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "k[a_]:=   (* 111 *)   ;"
    },
    SameTest -> MatchQ,
    TestID   -> "19_CodeCheckFix_UT@@Tests/CodeCheck.wlt:346,1-361,2"
]

VerificationTest[
    CodeCheckFix[ "k[,(* 111 *)];" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedCode" -> "k[(* 111 *)];",
        "FixedPatterns" -> { { { "Error", "Comma" }, { "Error", "Comma" } } },
        "OriginalCode" -> "k[,(* 111 *)];"
    },
    SameTest -> MatchQ,
    TestID   -> "20_CodeCheckFix_UT@@Tests/CodeCheck.wlt:363,1-378,2"
]

VerificationTest[
    CodeCheckFix[ "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] = (* your existing function definition *)\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] = (* your existing function definition *)\n",
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] = (* your existing function definition *)\n"
    },
    SameTest -> MatchQ,
    TestID   -> "21_CodeCheckFix_UT@@Tests/CodeCheck.wlt:380,1-395,2"
]

VerificationTest[
    CodeCheckFix[ "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =      (* your existing function definition *)    \n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =      (* your existing function definition *)    \n",
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =      (* your existing function definition *)    \n"
    },
    SameTest -> MatchQ,
    TestID   -> "22_CodeCheckFix_UT@@Tests/CodeCheck.wlt:397,1-412,2"
]

VerificationTest[
    CodeCheckFix[ "\nMixtilinearExcircles[triangle_] := Module[\n  {circumcircle, vertices, excircles},\n  vertices = triangle;\n  circumcircle = Circumsphere[Triangle[vertices]];\n  \n  excircles = Table[\n    Module[{vertex, tangentPoint, excircleCenter, excircleRadius},\n      vertex = vertices[[i]];\n      \n      (* Calculate tangent point on the circumcircle *)\n      tangentPoint = (* Obtain the correct tangent point here *);\n      \n      (* Calculate the center of the excircle *)\n      excircleCenter = (* Calculate the center based on tangent properties *);\n      \n      (* Calculate the radius of the excircle *)\n      excircleRadius = Norm[excircleCenter - tangentPoint];\n      \n      {Circle[excircleCenter, excircleRadius]}\n    ],\n    {i, Length[vertices]}\n  ];\n  \n  excircles\n]\n\n(* Example usage *)\ntriangle = {{0, 0}, {4, 3}, {4, 0}};\nMixtilinearExcircles[triangle]\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "\nMixtilinearExcircles[triangle_] := Module[\n  {circumcircle, vertices, excircles},\n  vertices = triangle;\n  circumcircle = Circumsphere[Triangle[vertices]];\n  \n  excircles = Table[\n    Module[{vertex, tangentPoint, excircleCenter, excircleRadius},\n      vertex = vertices[[i]];\n      \n      (* Calculate tangent point on the circumcircle *)\n      tangentPoint = (* Obtain the correct tangent point here *);\n      \n      (* Calculate the center of the excircle *)\n      excircleCenter = (* Calculate the center based on tangent properties *);\n      \n      (* Calculate the radius of the excircle *)\n      excircleRadius = Norm[excircleCenter - tangentPoint];\n      \n      {Circle[excircleCenter, excircleRadius]}\n    ],\n    {i, Length[vertices]}\n  ];\n  \n  excircles\n]\n\n(* Example usage *)\ntriangle = {{0, 0}, {4, 3}, {4, 0}};\nMixtilinearExcircles[triangle]\n",
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" }, { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "\nMixtilinearExcircles[triangle_] := Module[\n  {circumcircle, vertices, excircles},\n  vertices = triangle;\n  circumcircle = Circumsphere[Triangle[vertices]];\n  \n  excircles = Table[\n    Module[{vertex, tangentPoint, excircleCenter, excircleRadius},\n      vertex = vertices[[i]];\n      \n      (* Calculate tangent point on the circumcircle *)\n      tangentPoint = (* Obtain the correct tangent point here *);\n      \n      (* Calculate the center of the excircle *)\n      excircleCenter = (* Calculate the center based on tangent properties *);\n      \n      (* Calculate the radius of the excircle *)\n      excircleRadius = Norm[excircleCenter - tangentPoint];\n      \n      {Circle[excircleCenter, excircleRadius]}\n    ],\n    {i, Length[vertices]}\n  ];\n  \n  excircles\n]\n\n(* Example usage *)\ntriangle = {{0, 0}, {4, 3}, {4, 0}};\nMixtilinearExcircles[triangle]\n"
    },
    SameTest -> MatchQ,
    TestID   -> "23_CodeCheckFix_UT@@Tests/CodeCheck.wlt:414,1-429,2"
]

VerificationTest[
    CodeCheckFix[ "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     ... (* your existing function definition *)    \n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     ... (* your existing function definition *)    \n",
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     ... (* your existing function definition *)    \n"
    },
    SameTest -> MatchQ,
    TestID   -> "24_CodeCheckFix_UT@@Tests/CodeCheck.wlt:431,1-446,2"
]

VerificationTest[
    CodeCheckFix[ "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     (* your existing function definition *) ...    \n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedCode" -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     (* your existing function definition *) ...    \n",
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode" -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     (* your existing function definition *) ...    \n"
    },
    SameTest -> MatchQ,
    TestID   -> "25_CodeCheckFix_UT@@Tests/CodeCheck.wlt:448,1-463,2"
]

VerificationTest[
    CodeCheckFix[ "f1[x,...,y,]" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedPatterns" -> { { { "Error", "Comma" } }, { { "Fatal", "ExpectedOperand" } } },
        "FixedCode" -> "f1[x,...,y]",
        "OriginalCode" -> "f1[x,...,y,]"
    },
    SameTest -> MatchQ,
    TestID   -> "26_CodeCheckFix_UT@@Tests/CodeCheck.wlt:465,1-480,2"
]

VerificationTest[
    CodeCheckFix[ "\nranges = Tuples[{{-1, 0, , 1}, Range[-3, 3], Range[-3, 3]}];\n...\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedPatterns" -> { { { "Error", "Comma" } }, { { "Fatal", "ExpectedOperand" } } },
        "FixedCode" -> "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n...\n",
        "OriginalCode" -> "\nranges = Tuples[{{-1, 0, , 1}, Range[-3, 3], Range[-3, 3]}];\n...\n"
    },
    SameTest -> MatchQ,
    TestID   -> "27_CodeCheckFix_UT@@Tests/CodeCheck.wlt:482,1-497,2"
]

VerificationTest[
    CodeCheckFix[ "\n(* Define your function *)\n\tf[k_] := Module[{...,,,}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 3,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate" -> False,
        "FixedPatterns" -> { { { "Error", "Comma" }, { "Error", "Comma" }, { "Error", "Comma" } }, { { "Fatal", "ExpectedOperand" }, { "Fatal", "ExpectedOperand" } } },
        "FixedCode" -> "\n(* Define your function *)\n\tf[k_] := Module[{...}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n",
        "OriginalCode" -> "\n(* Define your function *)\n\tf[k_] := Module[{...,,,}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n"
    },
    SameTest -> MatchQ,
    TestID   -> "28_CodeCheckFix_UT@@Tests/CodeCheck.wlt:499,1-514,2"
]

VerificationTest[
    CodeCheckFix[ "eq= x==y" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> False,
        "CodeInspector"  -> KeyValuePattern @ { "InspectionObjects" -> { }, "OverallSeverity" -> None },
        "FixedCode"      -> Missing[ "No errors detected" ],
        "OriginalCode"   -> "eq= x==y"
    },
    SameTest -> MatchQ,
    TestID   -> "29_CodeCheckFix_UT@@Tests/CodeCheck.wlt:516,1-526,2"
]

VerificationTest[
    CodeCheckFix[ "eq= x<=y" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> False,
        "CodeInspector"  -> KeyValuePattern @ { "InspectionObjects" -> { }, "OverallSeverity" -> None },
        "FixedCode"      -> Missing[ "No errors detected" ],
        "OriginalCode"   -> "eq= x<=y"
    },
    SameTest -> MatchQ,
    TestID   -> "30_CodeCheckFix_UT@@Tests/CodeCheck.wlt:528,1-538,2"
]

VerificationTest[
    CodeCheckFix[ "eq= x>=y" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> False,
        "CodeInspector"  -> KeyValuePattern @ { "InspectionObjects" -> { }, "OverallSeverity" -> None },
        "FixedCode"      -> Missing[ "No errors detected" ],
        "OriginalCode"   -> "eq= x>=y"
    },
    SameTest -> MatchQ,
    TestID   -> "31_CodeCheckFix_UT@@Tests/CodeCheck.wlt:540,1-550,2"
]

VerificationTest[
    CodeCheckFix[ "\n![Image](attachment://content-22840)\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "FixedCode" -> Missing[ "Not WL code" ],
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> False,
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" }, { "Fatal", "OpenSquare" } } },
        "OriginalCode" -> "\n![Image](attachment://content-22840)\n"
    },
    SameTest -> MatchQ,
    TestID   -> "32_CodeCheckFix_UT@@Tests/CodeCheck.wlt:552,1-567,2"
]

VerificationTest[
    CodeCheckFix[ "\n![Comparative Air Speed Velocities](attachment://content-6zubu)\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "FixedCode" -> Missing[ "Not WL code" ],
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> False,
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" }, { "Fatal", "OpenSquare" } } },
        "OriginalCode" -> "\n![Comparative Air Speed Velocities](attachment://content-6zubu)\n"
    },
    SameTest -> MatchQ,
    TestID   -> "33_CodeCheckFix_UT@@Tests/CodeCheck.wlt:569,1-584,2"
]

VerificationTest[
    CodeCheckFix[ "                                                                                                                                                                                                                                 * [FindMinimum](paclet:ref/FindMinimum)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 " ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "FixedCode" -> Missing[ "Not WL code" ],
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> False,
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" }, { "Fatal", "OpenSquare" } } },
        "OriginalCode" -> "                                                                                                                                                                                                                                 * [FindMinimum](paclet:ref/FindMinimum)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 "
    },
    SameTest -> MatchQ,
    TestID   -> "34_CodeCheckFix_UT@@Tests/CodeCheck.wlt:586,1-601,2"
]

VerificationTest[
    CodeCheckFix[ "                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         * [Polynomial Factoring & Decomposition](paclet:guide/PolynomialFactoring)\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "FixedCode" -> Missing[ "Not WL code" ],
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> False,
        "FixedPatterns" -> { { { "Error", "ImplicitTimesFunction" }, { "Fatal", "ExpectedOperand" }, { "Fatal", "OpenSquare" } } },
        "OriginalCode" -> "                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         * [Polynomial Factoring & Decomposition](paclet:guide/PolynomialFactoring)\n"
    },
    SameTest -> MatchQ,
    TestID   -> "35_CodeCheckFix_UT@@Tests/CodeCheck.wlt:603,1-618,2"
]

VerificationTest[
    CodeCheckFix[ "\n![Sphere](attachment://content-57d9d4f5-650f-4a8c-a4bc-33b4c3a7ec86.png)\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "FixedCode" -> Missing[ "Not WL code" ],
        "Success" -> True,
        "TotalFixes" -> 0,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> False,
        "FixedPatterns" -> { { { "Fatal", "ExpectedOperand" }, { "Fatal", "OpenSquare" } } },
        "OriginalCode" -> "\n![Sphere](attachment://content-57d9d4f5-650f-4a8c-a4bc-33b4c3a7ec86.png)\n"
    },
    SameTest -> MatchQ,
    TestID   -> "36_CodeCheckFix_UT@@Tests/CodeCheck.wlt:620,1-635,2"
]

VerificationTest[
    CodeCheckFix[ "f[{{3}}}" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedCode" -> "f[{{3}}]",
        "FixedPatterns" -> { { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } } },
        "OriginalCode" -> "f[{{3}}}"
    },
    SameTest -> MatchQ,
    TestID   -> "37_CodeCheckFix_UT@@Tests/CodeCheck.wlt:637,1-652,2"
]

VerificationTest[
    CodeCheckFix[ "f[{{3,4}}}" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedCode" -> "f[{{3,4}}]",
        "FixedPatterns" -> { { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } } },
        "OriginalCode" -> "f[{{3,4}}}"
    },
    SameTest -> MatchQ,
    TestID   -> "38_CodeCheckFix_UT@@Tests/CodeCheck.wlt:654,1-669,2"
]

VerificationTest[
    CodeCheckFix[ "f[{{3,4}]}" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 2,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedPatterns" -> {
            { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } },
            { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } }
        },
        "FixedCode" -> "f[{{3,4}}]",
        "OriginalCode" -> "f[{{3,4}]}"
    },
    SameTest -> MatchQ,
    TestID   -> "39_CodeCheckFix_UT@@Tests/CodeCheck.wlt:671,1-689,2"
]

VerificationTest[
    CodeCheckFix[ "g[f[{{3,4}}},\n5]" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedCode" -> "g[f[{{3,4}}],\n5]",
        "FixedPatterns" -> { { { "Error", "Comma" }, { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } } },
        "OriginalCode" -> "g[f[{{3,4}}},\n5]"
    },
    SameTest -> MatchQ,
    TestID   -> "40_CodeCheckFix_UT@@Tests/CodeCheck.wlt:691,1-706,2"
]

VerificationTest[
    CodeCheckFix[ "{g[f[{{3,4}}},5]}" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedCode" -> "{g[f[{{3,4}}],5]}",
        "FixedPatterns" -> {
            {
                { "Fatal", "CommaTopLevel" },
                { "Fatal", "GroupMissingCloser" },
                { "Fatal", "GroupMissingCloser" },
                { "Fatal", "UnexpectedCloser" },
                { "Fatal", "UnexpectedCloser" }
            }
        },
        "OriginalCode" -> "{g[f[{{3,4}}},5]}"
    },
    SameTest -> MatchQ,
    TestID   -> "41_CodeCheckFix_UT@@Tests/CodeCheck.wlt:708,1-731,2"
]

VerificationTest[
    CodeCheckFix[ "g[f[{{3,4}}},h[}]" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 2,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedPatterns" -> {
            { { "Error", "Comma" }, { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" }, { "Fatal", "UnexpectedCloser" } },
            { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } }
        },
        "FixedCode" -> "g[f[{{3,4}}],h[]]",
        "OriginalCode" -> "g[f[{{3,4}}},h[}]"
    },
    SameTest -> MatchQ,
    TestID   -> "42_CodeCheckFix_UT@@Tests/CodeCheck.wlt:733,1-751,2"
]

VerificationTest[
    CodeCheckFix[ "g[(dothis;1},2]" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedCode" -> "g[(dothis;1),2]",
        "FixedPatterns" -> { { { "Error", "Comma" }, { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } } },
        "OriginalCode" -> "g[(dothis;1},2]"
    },
    SameTest -> MatchQ,
    TestID   -> "43_CodeCheckFix_UT@@Tests/CodeCheck.wlt:753,1-768,2"
]

VerificationTest[
    CodeCheckFix[ "foo[1,2,g[{3]]]" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedCode" -> "foo[1,2,g[{3}]]",
        "FixedPatterns" -> { { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } } },
        "OriginalCode" -> "foo[1,2,g[{3]]]"
    },
    SameTest -> MatchQ,
    TestID   -> "44_CodeCheckFix_UT@@Tests/CodeCheck.wlt:770,1-785,2"
]

VerificationTest[
    CodeCheckFix[ "(1;2;g[3))" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedCode" -> "(1;2;g[3])",
        "FixedPatterns" -> { { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } } },
        "OriginalCode" -> "(1;2;g[3))"
    },
    SameTest -> MatchQ,
    TestID   -> "45_CodeCheckFix_UT@@Tests/CodeCheck.wlt:787,1-802,2"
]

VerificationTest[
    CodeCheckFix[ "(1;2;g[3\n   ))" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedCode" -> "(1;2;g[3\n   ])",
        "FixedPatterns" -> { { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } } },
        "OriginalCode" -> "(1;2;g[3\n   ))"
    },
    SameTest -> MatchQ,
    TestID   -> "46_CodeCheckFix_UT@@Tests/CodeCheck.wlt:804,1-819,2"
]

VerificationTest[
    CodeCheckFix[ "\nmaxC = 20;\n\tprimTriples = Select[\n\t  With[{m = #1, n = #2}, \n\t    {m ^ 2 - n ^ 2, 2 m n, m ^ 2 + n ^ 2}\n\t  ] & @@@ \n\t  Select[\n\t    Flatten[Table[{m, n}, {n, Floor[Sqrt[maxC / 2]}], {m, n + 1, Floor[Sqrt[maxC]], 2}], 1], \n\t    #[[1]] ^ 2 + #[[2]] ^ 2 <= maxC &\n\t  ], \n\t  Apply[CoprimeQ, #] &\n\t];\n\t\n\tprimTriples\n" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> True,
        "TotalFixes" -> 2,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> True,
        "FixedPatterns" -> {
            { { "Fatal", "CommaTopLevel" }, { "Fatal", "ExpectedOperand" }, { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } },
            { { "Fatal", "CommaTopLevel" }, { "Fatal", "ExpectedOperand" }, { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } }
        },
        "FixedCode" -> "\nmaxC = 20;\n\tprimTriples = Select[\n\t  With[{m = #1, n = #2}, \n\t    {m ^ 2 - n ^ 2, 2 m n, m ^ 2 + n ^ 2}\n\t  ] & @@@ \n\t  Select[\n\t    Flatten[Table[{m, n}, {n, Floor[Sqrt[maxC / 2]]}, {m, n + 1, Floor[Sqrt[maxC]], 2}], 1], \n\t    #[[1]] ^ 2 + #[[2]] ^ 2 <= maxC &\n\t  ], \n\t  Apply[CoprimeQ, #] &\n\t];\n\t\n\tprimTriples\n",
        "OriginalCode" -> "\nmaxC = 20;\n\tprimTriples = Select[\n\t  With[{m = #1, n = #2}, \n\t    {m ^ 2 - n ^ 2, 2 m n, m ^ 2 + n ^ 2}\n\t  ] & @@@ \n\t  Select[\n\t    Flatten[Table[{m, n}, {n, Floor[Sqrt[maxC / 2]}], {m, n + 1, Floor[Sqrt[maxC]], 2}], 1], \n\t    #[[1]] ^ 2 + #[[2]] ^ 2 <= maxC &\n\t  ], \n\t  Apply[CoprimeQ, #] &\n\t];\n\t\n\tprimTriples\n"
    },
    SameTest -> MatchQ,
    TestID   -> "47_CodeCheckFix_UT@@Tests/CodeCheck.wlt:821,1-839,2"
]

VerificationTest[
    CodeCheckFix[ "g[{[{a]}]}" ],
    KeyValuePattern @ {
        "ErrorsDetected" -> True,
        "CodeInspector" -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success" -> False,
        "TotalFixes" -> 4,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate" -> False,
        "FixedPatterns" -> {
            { { "Fatal", "GroupMissingCloser" }, { "Fatal", "OpenSquare" }, { "Fatal", "UnexpectedCloser" } },
            { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } },
            { { "Fatal", "GroupMissingCloser" }, { "Fatal", "OpenSquare" }, { "Fatal", "UnexpectedCloser" } },
            { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } },
            { { "Fatal", "OpenSquare" } }
        },
        "FixedCode" -> Missing[ "Pattern not handled", { { "Fatal", "OpenSquare" } } ],
        "OriginalCode" -> "g[{[{a]}]}"
    },
    SameTest -> MatchQ,
    TestID   -> "48_CodeCheckFix_UT@@Tests/CodeCheck.wlt:841,1-862,2"
]