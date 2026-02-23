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
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "f1[x,y]",
        "FixedPatterns"       -> { { { "Error", "Comma" } } },
        "OriginalCode"        -> "f1[x,y,]"
    },
    SameTest -> MatchQ,
    TestID   -> "1_CodeCheckFix_UT@@Tests/CodeCheck.wlt:31,1-46,2"
]

VerificationTest[
    CodeCheckFix[ "f1[x,y,]," ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> False,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> Missing[ "Pattern not handled", { { "Error", "Comma" }, { "Error", "Comma" }, { "Fatal", "CommaTopLevel" } } ],
        "FixedPatterns"       -> { { { "Error", "Comma" }, { "Error", "Comma" }, { "Fatal", "CommaTopLevel" } } },
        "OriginalCode"        -> "f1[x,y,],"
    },
    SameTest -> MatchQ,
    TestID   -> "2_CodeCheckFix_UT@@Tests/CodeCheck.wlt:48,1-63,2"
]

VerificationTest[
    CodeCheckFix[ "f1[x,y,(*comment*)]" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "f1[x,y,(*comment*)]",
        "FixedPatterns"       -> { { { "Error", "Comma" } } },
        "OriginalCode"        -> "f1[x,y,(*comment*)]"
    },
    SameTest -> MatchQ,
    TestID   -> "3_CodeCheckFix_UT@@Tests/CodeCheck.wlt:65,1-80,2"
]

VerificationTest[
    CodeCheckFix[ codestring = "f1[x,y,(*comment*),z]" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "f1[x,y,(*comment*),z]",
        "FixedPatterns"       -> { { { "Error", "Comma" } } },
        "OriginalCode"        -> "f1[x,y,(*comment*),z]"
    },
    SameTest -> MatchQ,
    TestID   -> "4_CodeCheckFix_UT@@Tests/CodeCheck.wlt:82,1-97,2"
]

VerificationTest[
    CodeCheckFix[ "f1[x,y,,(*comment*),]" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success"             -> True,
        "TotalFixes"          -> 2,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "f1[x,y,(*comment*)]",
        "FixedPatterns"       -> { { { "Error", "Comma" }, { "Error", "Comma" }, { "Error", "Comma" } } },
        "OriginalCode"        -> "f1[x,y,,(*comment*),]"
    },
    SameTest -> MatchQ,
    TestID   -> "5_CodeCheckFix_UT@@Tests/CodeCheck.wlt:99,1-114,2"
]

VerificationTest[
    CodeCheckFix[ "f1[x,y,(*comment*)];g[x,y,z]" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "f1[x,y,(*comment*)];g[x,y,z]",
        "FixedPatterns"       -> { { { "Error", "Comma" } } },
        "OriginalCode"        -> "f1[x,y,(*comment*)];g[x,y,z]"
    },
    SameTest -> MatchQ,
    TestID   -> "6_CodeCheckFix_UT@@Tests/CodeCheck.wlt:116,1-131,2"
]

VerificationTest[
    CodeCheckFix[ "f1[{x,y,}z]" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "f1[{x,y}z]",
        "FixedPatterns"       -> { { { "Error", "Comma" } } },
        "OriginalCode"        -> "f1[{x,y,}z]"
    },
    SameTest -> MatchQ,
    TestID   -> "7_CodeCheckFix_UT@@Tests/CodeCheck.wlt:133,1-148,2"
]

VerificationTest[
    CodeCheckFix[ "{f1[x,,y]}" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "{f1[x,y]}",
        "FixedPatterns"       -> { { { "Error", "Comma" } } },
        "OriginalCode"        -> "{f1[x,,y]}"
    },
    SameTest -> MatchQ,
    TestID   -> "8_CodeCheckFix_UT@@Tests/CodeCheck.wlt:150,1-165,2"
]

VerificationTest[
    CodeCheckFix[ "{f1[,x]}" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "{f1[x]}",
        "FixedPatterns"       -> { { { "Error", "Comma" } } },
        "OriginalCode"        -> "{f1[,x]}"
    },
    SameTest -> MatchQ,
    TestID   -> "9_CodeCheckFix_UT@@Tests/CodeCheck.wlt:167,1-182,2"
]

VerificationTest[
    CodeCheckFix[ "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n...\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n...\n",
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n...\n"
    },
    SameTest -> MatchQ,
    TestID   -> "10_CodeCheckFix_UT@@Tests/CodeCheck.wlt:184,1-199,2"
]

VerificationTest[
    CodeCheckFix[ "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n    ...\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n    ...\n",
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n    ...\n"
    },
    SameTest -> MatchQ,
    TestID   -> "11_CodeCheckFix_UT@@Tests/CodeCheck.wlt:201,1-216,2"
]

VerificationTest[
    CodeCheckFix[ "\nminValue = NMinimize[{f[k], constraint1, constraint2, ...}, {k, kMin, kMax}]\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "\nminValue = NMinimize[{f[k], constraint1, constraint2, ...}, {k, kMin, kMax}]\n",
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "\nminValue = NMinimize[{f[k], constraint1, constraint2, ...}, {k, kMin, kMax}]\n"
    },
    SameTest -> MatchQ,
    TestID   -> "12_CodeCheckFix_UT@@Tests/CodeCheck.wlt:218,1-233,2"
]

VerificationTest[
    CodeCheckFix[ "\nlist = {a1, a2, a3, ..., an};  (* replace with your list of numbers *)\nmodResults = Mod[Rest[list], Most[list]]\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "\nlist = {a1, a2, a3, ..., an};  (* replace with your list of numbers *)\nmodResults = Mod[Rest[list], Most[list]]\n",
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "\nlist = {a1, a2, a3, ..., an};  (* replace with your list of numbers *)\nmodResults = Mod[Rest[list], Most[list]]\n"
    },
    SameTest -> MatchQ,
    TestID   -> "13_CodeCheckFix_UT@@Tests/CodeCheck.wlt:235,1-250,2"
]

VerificationTest[
    CodeCheckFix[ "\n(* Define your function *)\n\tf[k_] := Module[{...}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "\n(* Define your function *)\n\tf[k_] := Module[{...}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n",
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" }, { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "\n(* Define your function *)\n\tf[k_] := Module[{...}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n"
    },
    SameTest -> MatchQ,
    TestID   -> "14_CodeCheckFix_UT@@Tests/CodeCheck.wlt:252,1-267,2"
]

VerificationTest[
    CodeCheckFix[ "\nGraphics3D[\n\t  Module[{...}, \n\t    ...\n\t    (*The full base perimeter now in black*)\n\t    {Black, Line[{{-14.5, -14.5, 29}, {14.5, -14.5, 29}, {14.5, 14.5, 29}, {-14.5, 14.5, 29}, {-14.5, -14.5, 29}}]}\n\t    ...\n\t  ], \n\t  ...\n\t]\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> False,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> Missing[
            "Pattern not handled",
            {
                { "Error", "ImplicitTimesAcrossLines" },
                { "Fatal", "ExpectedOperand" },
                { "Fatal", "ExpectedOperand" },
                { "Fatal", "ExpectedOperand" }
            }
        ],
        "FixedPatterns"       -> { { { "Error", "ImplicitTimesAcrossLines" }, { "Fatal", "ExpectedOperand" }, { "Fatal", "ExpectedOperand" }, { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "\nGraphics3D[\n\t  Module[{...}, \n\t    ...\n\t    (*The full base perimeter now in black*)\n\t    {Black, Line[{{-14.5, -14.5, 29}, {14.5, -14.5, 29}, {14.5, 14.5, 29}, {-14.5, 14.5, 29}, {-14.5, -14.5, 29}}]}\n\t    ...\n\t  ], \n\t  ...\n\t]\n"
    },
    SameTest -> MatchQ,
    TestID   -> "15_CodeCheckFix_UT@@Tests/CodeCheck.wlt:269,1-292,2"
]

VerificationTest[
    CodeCheckFix[ "k->(* 111 *);" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "k->(* 111 *);",
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "k->(* 111 *);"
    },
    SameTest -> MatchQ,
    TestID   -> "16_CodeCheckFix_UT@@Tests/CodeCheck.wlt:294,1-309,2"
]

VerificationTest[
    CodeCheckFix[ "k->;" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> False,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> Missing[ ],
        "SafeToEvaluate"      -> Missing[ ],
        "FixedCode"           -> Missing[ "Expected Operand (no place holder(s) detected)" ],
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "k->;"
    },
    SameTest -> MatchQ,
    TestID   -> "17_CodeCheckFix_UT@@Tests/CodeCheck.wlt:311,1-326,2"
]

VerificationTest[
    CodeCheckFix[ "k:=(* 111 *);" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "k:=(* 111 *);",
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "k:=(* 111 *);"
    },
    SameTest -> MatchQ,
    TestID   -> "18_CodeCheckFix_UT@@Tests/CodeCheck.wlt:328,1-343,2"
]

VerificationTest[
    CodeCheckFix[ "k[a_]:=   (* 111 *)   ;" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "k[a_]:=   (* 111 *)   ;",
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "k[a_]:=   (* 111 *)   ;"
    },
    SameTest -> MatchQ,
    TestID   -> "19_CodeCheckFix_UT@@Tests/CodeCheck.wlt:345,1-360,2"
]

VerificationTest[
    CodeCheckFix[ "k[,(* 111 *)];" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 3 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "k[(* 111 *)];",
        "FixedPatterns"       -> { { { "Error", "Comma" }, { "Error", "Comma" } } },
        "OriginalCode"        -> "k[,(* 111 *)];"
    },
    SameTest -> MatchQ,
    TestID   -> "20_CodeCheckFix_UT@@Tests/CodeCheck.wlt:362,1-377,2"
]

VerificationTest[
    CodeCheckFix[ "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] = (* your existing function definition *)\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] = (* your existing function definition *)\n",
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] = (* your existing function definition *)\n"
    },
    SameTest -> MatchQ,
    TestID   -> "21_CodeCheckFix_UT@@Tests/CodeCheck.wlt:379,1-394,2"
]

VerificationTest[
    CodeCheckFix[ "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =      (* your existing function definition *)    \n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =      (* your existing function definition *)    \n",
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =      (* your existing function definition *)    \n"
    },
    SameTest -> MatchQ,
    TestID   -> "22_CodeCheckFix_UT@@Tests/CodeCheck.wlt:396,1-411,2"
]

VerificationTest[
    CodeCheckFix[ "\nMixtilinearExcircles[triangle_] := Module[\n  {circumcircle, vertices, excircles},\n  vertices = triangle;\n  circumcircle = Circumsphere[Triangle[vertices]];\n  \n  excircles = Table[\n    Module[{vertex, tangentPoint, excircleCenter, excircleRadius},\n      vertex = vertices[[i]];\n      \n      (* Calculate tangent point on the circumcircle *)\n      tangentPoint = (* Obtain the correct tangent point here *);\n      \n      (* Calculate the center of the excircle *)\n      excircleCenter = (* Calculate the center based on tangent properties *);\n      \n      (* Calculate the radius of the excircle *)\n      excircleRadius = Norm[excircleCenter - tangentPoint];\n      \n      {Circle[excircleCenter, excircleRadius]}\n    ],\n    {i, Length[vertices]}\n  ];\n  \n  excircles\n]\n\n(* Example usage *)\ntriangle = {{0, 0}, {4, 3}, {4, 0}};\nMixtilinearExcircles[triangle]\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "\nMixtilinearExcircles[triangle_] := Module[\n  {circumcircle, vertices, excircles},\n  vertices = triangle;\n  circumcircle = Circumsphere[Triangle[vertices]];\n  \n  excircles = Table[\n    Module[{vertex, tangentPoint, excircleCenter, excircleRadius},\n      vertex = vertices[[i]];\n      \n      (* Calculate tangent point on the circumcircle *)\n      tangentPoint = (* Obtain the correct tangent point here *);\n      \n      (* Calculate the center of the excircle *)\n      excircleCenter = (* Calculate the center based on tangent properties *);\n      \n      (* Calculate the radius of the excircle *)\n      excircleRadius = Norm[excircleCenter - tangentPoint];\n      \n      {Circle[excircleCenter, excircleRadius]}\n    ],\n    {i, Length[vertices]}\n  ];\n  \n  excircles\n]\n\n(* Example usage *)\ntriangle = {{0, 0}, {4, 3}, {4, 0}};\nMixtilinearExcircles[triangle]\n",
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" }, { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "\nMixtilinearExcircles[triangle_] := Module[\n  {circumcircle, vertices, excircles},\n  vertices = triangle;\n  circumcircle = Circumsphere[Triangle[vertices]];\n  \n  excircles = Table[\n    Module[{vertex, tangentPoint, excircleCenter, excircleRadius},\n      vertex = vertices[[i]];\n      \n      (* Calculate tangent point on the circumcircle *)\n      tangentPoint = (* Obtain the correct tangent point here *);\n      \n      (* Calculate the center of the excircle *)\n      excircleCenter = (* Calculate the center based on tangent properties *);\n      \n      (* Calculate the radius of the excircle *)\n      excircleRadius = Norm[excircleCenter - tangentPoint];\n      \n      {Circle[excircleCenter, excircleRadius]}\n    ],\n    {i, Length[vertices]}\n  ];\n  \n  excircles\n]\n\n(* Example usage *)\ntriangle = {{0, 0}, {4, 3}, {4, 0}};\nMixtilinearExcircles[triangle]\n"
    },
    SameTest -> MatchQ,
    TestID   -> "23_CodeCheckFix_UT@@Tests/CodeCheck.wlt:413,1-428,2"
]

VerificationTest[
    CodeCheckFix[ "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     ... (* your existing function definition *)    \n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     ... (* your existing function definition *)    \n",
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     ... (* your existing function definition *)    \n"
    },
    SameTest -> MatchQ,
    TestID   -> "24_CodeCheckFix_UT@@Tests/CodeCheck.wlt:430,1-445,2"
]

VerificationTest[
    CodeCheckFix[ "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     (* your existing function definition *) ...    \n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedCode"           -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     (* your existing function definition *) ...    \n",
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" } } },
        "OriginalCode"        -> "\nf[0] = 2^13 * (2^9 - 1);\nf[k_] := f[k] =     (* your existing function definition *) ...    \n"
    },
    SameTest -> MatchQ,
    TestID   -> "25_CodeCheckFix_UT@@Tests/CodeCheck.wlt:447,1-462,2"
]

VerificationTest[
    CodeCheckFix[ "f1[x,...,y,]" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedPatterns"       -> { { { "Error", "Comma" } }, { { "Fatal", "ExpectedOperand" } } },
        "FixedCode"           -> "f1[x,...,y]",
        "OriginalCode"        -> "f1[x,...,y,]"
    },
    SameTest -> MatchQ,
    TestID   -> "26_CodeCheckFix_UT@@Tests/CodeCheck.wlt:464,1-479,2"
]

VerificationTest[
    CodeCheckFix[ "\nranges = Tuples[{{-1, 0, , 1}, Range[-3, 3], Range[-3, 3]}];\n...\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedPatterns"       -> { { { "Error", "Comma" } }, { { "Fatal", "ExpectedOperand" } } },
        "FixedCode"           -> "\nranges = Tuples[{{-1, 0, 1}, Range[-3, 3], Range[-3, 3]}];\n...\n",
        "OriginalCode"        -> "\nranges = Tuples[{{-1, 0, , 1}, Range[-3, 3], Range[-3, 3]}];\n...\n"
    },
    SameTest -> MatchQ,
    TestID   -> "27_CodeCheckFix_UT@@Tests/CodeCheck.wlt:481,1-496,2"
]

VerificationTest[
    CodeCheckFix[ "\n(* Define your function *)\n\tf[k_] := Module[{...,,,}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 3,
        "LikelyFalsePositive" -> True,
        "SafeToEvaluate"      -> False,
        "FixedPatterns"       -> { { { "Error", "Comma" }, { "Error", "Comma" }, { "Error", "Comma" } }, { { "Fatal", "ExpectedOperand" }, { "Fatal", "ExpectedOperand" } } },
        "FixedCode"           -> "\n(* Define your function *)\n\tf[k_] := Module[{...}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n",
        "OriginalCode"        -> "\n(* Define your function *)\n\tf[k_] := Module[{...,,,}, ...]\n\t\n\t(* Use TraceView to profile the function *)\n\tResourceFunction[\"TraceView\"][f[10]]\n"
    },
    SameTest -> MatchQ,
    TestID   -> "28_CodeCheckFix_UT@@Tests/CodeCheck.wlt:498,1-513,2"
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
    TestID   -> "29_CodeCheckFix_UT@@Tests/CodeCheck.wlt:515,1-525,2"
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
    TestID   -> "30_CodeCheckFix_UT@@Tests/CodeCheck.wlt:527,1-537,2"
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
    TestID   -> "31_CodeCheckFix_UT@@Tests/CodeCheck.wlt:539,1-549,2"
]

VerificationTest[
    CodeCheckFix[ "\n![Image](attachment://content-22840)\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "FixedCode"           -> Missing[ "Not WL code" ],
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> False,
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" }, { "Fatal", "OpenSquare" } } },
        "OriginalCode"        -> "\n![Image](attachment://content-22840)\n"
    },
    SameTest -> MatchQ,
    TestID   -> "32_CodeCheckFix_UT@@Tests/CodeCheck.wlt:551,1-566,2"
]

VerificationTest[
    CodeCheckFix[ "\n![Comparative Air Speed Velocities](attachment://content-6zubu)\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "FixedCode"           -> Missing[ "Not WL code" ],
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> False,
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" }, { "Fatal", "OpenSquare" } } },
        "OriginalCode"        -> "\n![Comparative Air Speed Velocities](attachment://content-6zubu)\n"
    },
    SameTest -> MatchQ,
    TestID   -> "33_CodeCheckFix_UT@@Tests/CodeCheck.wlt:568,1-583,2"
]

VerificationTest[
    CodeCheckFix[ "                                                                                                                                                                                                                                 * [FindMinimum](paclet:ref/FindMinimum)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 " ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "FixedCode"           -> Missing[ "Not WL code" ],
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> False,
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" }, { "Fatal", "OpenSquare" } } },
        "OriginalCode"        -> "                                                                                                                                                                                                                                 * [FindMinimum](paclet:ref/FindMinimum)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 "
    },
    SameTest -> MatchQ,
    TestID   -> "34_CodeCheckFix_UT@@Tests/CodeCheck.wlt:585,1-600,2"
]

VerificationTest[
    CodeCheckFix[ "                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         * [Polynomial Factoring & Decomposition](paclet:guide/PolynomialFactoring)\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "FixedCode"           -> Missing[ "Not WL code" ],
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> False,
        "FixedPatterns"       -> { { { "Error", "ImplicitTimesFunction" }, { "Fatal", "ExpectedOperand" }, { "Fatal", "OpenSquare" } } },
        "OriginalCode"        -> "                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         * [Polynomial Factoring & Decomposition](paclet:guide/PolynomialFactoring)\n"
    },
    SameTest -> MatchQ,
    TestID   -> "35_CodeCheckFix_UT@@Tests/CodeCheck.wlt:602,1-617,2"
]

VerificationTest[
    CodeCheckFix[ "\n![Sphere](attachment://content-57d9d4f5-650f-4a8c-a4bc-33b4c3a7ec86.png)\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "FixedCode"           -> Missing[ "Not WL code" ],
        "Success"             -> True,
        "TotalFixes"          -> 0,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> False,
        "FixedPatterns"       -> { { { "Fatal", "ExpectedOperand" }, { "Fatal", "OpenSquare" } } },
        "OriginalCode"        -> "\n![Sphere](attachment://content-57d9d4f5-650f-4a8c-a4bc-33b4c3a7ec86.png)\n"
    },
    SameTest -> MatchQ,
    TestID   -> "36_CodeCheckFix_UT@@Tests/CodeCheck.wlt:619,1-634,2"
]

VerificationTest[
    CodeCheckFix[ "f[{{3}}}" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "f[{{3}}]",
        "FixedPatterns"       -> { { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } } },
        "OriginalCode"        -> "f[{{3}}}"
    },
    SameTest -> MatchQ,
    TestID   -> "37_CodeCheckFix_UT@@Tests/CodeCheck.wlt:636,1-651,2"
]

VerificationTest[
    CodeCheckFix[ "f[{{3,4}}}" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "f[{{3,4}}]",
        "FixedPatterns"       -> { { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } } },
        "OriginalCode"        -> "f[{{3,4}}}"
    },
    SameTest -> MatchQ,
    TestID   -> "38_CodeCheckFix_UT@@Tests/CodeCheck.wlt:653,1-668,2"
]

VerificationTest[
    CodeCheckFix[ "f[{{3,4}]}" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 2,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedPatterns"       -> {
            { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } },
            { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } }
        },
        "FixedCode"           -> "f[{{3,4}}]",
        "OriginalCode"        -> "f[{{3,4}]}"
    },
    SameTest -> MatchQ,
    TestID   -> "39_CodeCheckFix_UT@@Tests/CodeCheck.wlt:670,1-688,2"
]

VerificationTest[
    CodeCheckFix[ "g[f[{{3,4}}},\n5]" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "g[f[{{3,4}}],\n5]",
        "FixedPatterns"       -> { { { "Error", "Comma" }, { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } } },
        "OriginalCode"        -> "g[f[{{3,4}}},\n5]"
    },
    SameTest -> MatchQ,
    TestID   -> "40_CodeCheckFix_UT@@Tests/CodeCheck.wlt:690,1-705,2"
]

VerificationTest[
    CodeCheckFix[ "{g[f[{{3,4}}},5]}" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "{g[f[{{3,4}}],5]}",
        "FixedPatterns"       -> {
            {
                { "Fatal", "CommaTopLevel" },
                { "Fatal", "GroupMissingCloser" },
                { "Fatal", "GroupMissingCloser" },
                { "Fatal", "UnexpectedCloser" },
                { "Fatal", "UnexpectedCloser" }
            }
        },
        "OriginalCode"        -> "{g[f[{{3,4}}},5]}"
    },
    SameTest -> MatchQ,
    TestID   -> "41_CodeCheckFix_UT@@Tests/CodeCheck.wlt:707,1-730,2"
]

VerificationTest[
    CodeCheckFix[ "g[f[{{3,4}}},h[}]" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 2,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedPatterns"       -> {
            { { "Error", "Comma" }, { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" }, { "Fatal", "UnexpectedCloser" } },
            { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } }
        },
        "FixedCode"           -> "g[f[{{3,4}}],h[]]",
        "OriginalCode"        -> "g[f[{{3,4}}},h[}]"
    },
    SameTest -> MatchQ,
    TestID   -> "42_CodeCheckFix_UT@@Tests/CodeCheck.wlt:732,1-750,2"
]

VerificationTest[
    CodeCheckFix[ "g[(dothis;1},2]" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "g[(dothis;1),2]",
        "FixedPatterns"       -> { { { "Error", "Comma" }, { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } } },
        "OriginalCode"        -> "g[(dothis;1},2]"
    },
    SameTest -> MatchQ,
    TestID   -> "43_CodeCheckFix_UT@@Tests/CodeCheck.wlt:752,1-767,2"
]

VerificationTest[
    CodeCheckFix[ "foo[1,2,g[{3]]]" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "foo[1,2,g[{3}]]",
        "FixedPatterns"       -> { { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } } },
        "OriginalCode"        -> "foo[1,2,g[{3]]]"
    },
    SameTest -> MatchQ,
    TestID   -> "44_CodeCheckFix_UT@@Tests/CodeCheck.wlt:769,1-784,2"
]

VerificationTest[
    CodeCheckFix[ "(1;2;g[3))" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "(1;2;g[3])",
        "FixedPatterns"       -> { { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } } },
        "OriginalCode"        -> "(1;2;g[3))"
    },
    SameTest -> MatchQ,
    TestID   -> "45_CodeCheckFix_UT@@Tests/CodeCheck.wlt:786,1-801,2"
]

VerificationTest[
    CodeCheckFix[ "(1;2;g[3\n   ))" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "(1;2;g[3\n   ])",
        "FixedPatterns"       -> { { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } } },
        "OriginalCode"        -> "(1;2;g[3\n   ))"
    },
    SameTest -> MatchQ,
    TestID   -> "46_CodeCheckFix_UT@@Tests/CodeCheck.wlt:803,1-818,2"
]

VerificationTest[
    CodeCheckFix[ "\nmaxC = 20;\n\tprimTriples = Select[\n\t  With[{m = #1, n = #2}, \n\t    {m ^ 2 - n ^ 2, 2 m n, m ^ 2 + n ^ 2}\n\t  ] & @@@ \n\t  Select[\n\t    Flatten[Table[{m, n}, {n, Floor[Sqrt[maxC / 2]}], {m, n + 1, Floor[Sqrt[maxC]], 2}], 1], \n\t    #[[1]] ^ 2 + #[[2]] ^ 2 <= maxC &\n\t  ], \n\t  Apply[CoprimeQ, #] &\n\t];\n\t\n\tprimTriples\n" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> True,
        "TotalFixes"          -> 2,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedPatterns"       -> {
            { { "Fatal", "CommaTopLevel" }, { "Fatal", "ExpectedOperand" }, { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } },
            { { "Fatal", "CommaTopLevel" }, { "Fatal", "ExpectedOperand" }, { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } }
        },
        "FixedCode"           -> "\nmaxC = 20;\n\tprimTriples = Select[\n\t  With[{m = #1, n = #2}, \n\t    {m ^ 2 - n ^ 2, 2 m n, m ^ 2 + n ^ 2}\n\t  ] & @@@ \n\t  Select[\n\t    Flatten[Table[{m, n}, {n, Floor[Sqrt[maxC / 2]]}, {m, n + 1, Floor[Sqrt[maxC]], 2}], 1], \n\t    #[[1]] ^ 2 + #[[2]] ^ 2 <= maxC &\n\t  ], \n\t  Apply[CoprimeQ, #] &\n\t];\n\t\n\tprimTriples\n",
        "OriginalCode"        -> "\nmaxC = 20;\n\tprimTriples = Select[\n\t  With[{m = #1, n = #2}, \n\t    {m ^ 2 - n ^ 2, 2 m n, m ^ 2 + n ^ 2}\n\t  ] & @@@ \n\t  Select[\n\t    Flatten[Table[{m, n}, {n, Floor[Sqrt[maxC / 2]}], {m, n + 1, Floor[Sqrt[maxC]], 2}], 1], \n\t    #[[1]] ^ 2 + #[[2]] ^ 2 <= maxC &\n\t  ], \n\t  Apply[CoprimeQ, #] &\n\t];\n\t\n\tprimTriples\n"
    },
    SameTest -> MatchQ,
    TestID   -> "47_CodeCheckFix_UT@@Tests/CodeCheck.wlt:820,1-838,2"
]

VerificationTest[
    CodeCheckFix[ "g[{[{a]}]}" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "CodeInspector"       -> KeyValuePattern @ { "InspectionObjects" -> { __CodeInspector`InspectionObject }, "OverallSeverity" -> 4 },
        "Success"             -> False,
        "TotalFixes"          -> 4,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> False,
        "FixedPatterns"       -> {
            { { "Fatal", "GroupMissingCloser" }, { "Fatal", "OpenSquare" }, { "Fatal", "UnexpectedCloser" } },
            { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } },
            { { "Fatal", "GroupMissingCloser" }, { "Fatal", "OpenSquare" }, { "Fatal", "UnexpectedCloser" } },
            { { "Fatal", "GroupMissingCloser" }, { "Fatal", "UnexpectedCloser" } },
            { { "Fatal", "OpenSquare" } }
        },
        "FixedCode"           -> Missing[ "Pattern not handled", { { "Fatal", "OpenSquare" } } ],
        "OriginalCode"        -> "g[{[{a]}]}"
    },
    SameTest -> MatchQ,
    TestID   -> "48_CodeCheckFix_UT@@Tests/CodeCheck.wlt:840,1-861,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Scoring for ambiguous cases - MissingCloser and UnexpectedCloser*)
VerificationTest[
    (CodeCheckFix[ #1, "Target" -> "Evaluator" ] &)[ "f[a,g[h];b[c]" ],
    <|
        "ErrorsDetected" -> True,
        "CodeInspector" -> <|
            "InspectionObjects" -> {
                CodeInspector`InspectionObject[
                    "GroupMissingCloser",
                    "Missing closer.",
                    "Fatal",
                    <| CodeParser`Source -> { 2, 2 }, ConfidenceLevel -> 1. |>
                ]
            },
            "OverallSeverity" -> 4
        |>,
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "f[a,g[h];b[c]]",
        "FixedPatterns"       -> { { { "Fatal", "GroupMissingCloser" } } },
        "OriginalCode"        -> "f[a,g[h];b[c]"
    |>,
    TestID -> "1_scoreAmbiguous_UT@@Tests/CodeCheck.wlt:866,1-890,2"
]

VerificationTest[
    (CodeCheckFix[ #1, "Target" -> "Evaluator" ] &)[ "Graphics3D[{a,{b},{c,Red},ViewPoint -> {1, -2, 1}]" ],
    <|
        "ErrorsDetected" -> True,
        "CodeInspector" -> <|
            "InspectionObjects" -> {
                CodeInspector`InspectionObject[
                    "GroupMissingCloser",
                    "Missing closer.",
                    "Fatal",
                    <| CodeParser`Source -> { 12, 12 }, ConfidenceLevel -> 1. |>
                ]
            },
            "OverallSeverity" -> 4
        |>,
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "Graphics3D[{a,{b},{c,Red}},ViewPoint -> {1, -2, 1}]",
        "FixedPatterns"       -> { { { "Fatal", "GroupMissingCloser" } } },
        "OriginalCode"        -> "Graphics3D[{a,{b},{c,Red},ViewPoint -> {1, -2, 1}]"
    |>,
    TestID -> "2_scoreAmbiguous_UT@@Tests/CodeCheck.wlt:892,1-916,2"
]

VerificationTest[
    (CodeCheckFix[ #1, "Target" -> "Evaluator" ] &)[ "Graphics3D[{a,{b},{c,Red},ViewPoint -> Automatic]" ],
    <|
        "ErrorsDetected" -> True,
        "CodeInspector" -> <|
            "InspectionObjects" -> {
                CodeInspector`InspectionObject[
                    "GroupMissingCloser",
                    "Missing closer.",
                    "Fatal",
                    <| CodeParser`Source -> { 12, 12 }, ConfidenceLevel -> 1. |>
                ]
            },
            "OverallSeverity" -> 4
        |>,
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "Graphics3D[{a,{b},{c,Red}},ViewPoint -> Automatic]",
        "FixedPatterns"       -> { { { "Fatal", "GroupMissingCloser" } } },
        "OriginalCode"        -> "Graphics3D[{a,{b},{c,Red},ViewPoint -> Automatic]"
    |>,
    TestID -> "3_scoreAmbiguous_UT@@Tests/CodeCheck.wlt:918,1-942,2"
]

VerificationTest[
    (CodeCheckFix[ #1, "Target" -> "Evaluator" ] &)[ "graphics3D[{a,{b},{c,Red},ViewPoint -> Automatic]" ],
    <|
        "ErrorsDetected" -> True,
        "CodeInspector" -> <|
            "InspectionObjects" -> {
                CodeInspector`InspectionObject[
                    "GroupMissingCloser",
                    "Missing closer.",
                    "Fatal",
                    <| CodeParser`Source -> { 12, 12 }, ConfidenceLevel -> 1. |>
                ]
            },
            "OverallSeverity" -> 4
        |>,
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "graphics3D[{a,{b},{c,Red}},ViewPoint -> Automatic]",
        "FixedPatterns"       -> { { { "Fatal", "GroupMissingCloser" } } },
        "OriginalCode"        -> "graphics3D[{a,{b},{c,Red},ViewPoint -> Automatic]"
    |>,
    TestID -> "4_scoreAmbiguous_UT@@Tests/CodeCheck.wlt:944,1-968,2"
]

VerificationTest[
    (CodeCheckFix[ #1, "Target" -> "Evaluator" ] &)[ "Graphics3D[{a,b,{c,Red},viewPoint -> Automatic]" ],
    <|
        "ErrorsDetected" -> True,
        "CodeInspector" -> <|
            "InspectionObjects" -> {
                CodeInspector`InspectionObject[
                    "GroupMissingCloser",
                    "Missing closer.",
                    "Fatal",
                    <| CodeParser`Source -> { 12, 12 }, ConfidenceLevel -> 1. |>
                ]
            },
            "OverallSeverity" -> 4
        |>,
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "Graphics3D[{a,b,{c,Red}},viewPoint -> Automatic]",
        "FixedPatterns"       -> { { { "Fatal", "GroupMissingCloser" } } },
        "OriginalCode"        -> "Graphics3D[{a,b,{c,Red},viewPoint -> Automatic]"
    |>,
    TestID -> "5_scoreAmbiguous_UT@@Tests/CodeCheck.wlt:970,1-994,2"
]

VerificationTest[
    (CodeCheckFix[ #1, "Target" -> "Evaluator" ] &)[ "graphics3D[{a,b,{c,Red},viewPoint -> {1, -2, 1}]" ],
    <|
        "ErrorsDetected" -> True,
        "CodeInspector" -> <|
            "InspectionObjects" -> {
                CodeInspector`InspectionObject[
                    "GroupMissingCloser",
                    "Missing closer.",
                    "Fatal",
                    <| CodeParser`Source -> { 12, 12 }, ConfidenceLevel -> 1. |>
                ]
            },
            "OverallSeverity" -> 4
        |>,
        "Success"             -> True,
        "TotalFixes"          -> 1,
        "LikelyFalsePositive" -> False,
        "SafeToEvaluate"      -> True,
        "FixedCode"           -> "graphics3D[{a,b,{c,Red},viewPoint -> {1, -2, 1}}]",
        "FixedPatterns"       -> { { { "Fatal", "GroupMissingCloser" } } },
        "OriginalCode"        -> "graphics3D[{a,b,{c,Red},viewPoint -> {1, -2, 1}]"
    |>,
    TestID -> "6_scoreAmbiguous_UT@@Tests/CodeCheck.wlt:996,1-1020,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Bad snake case usage*)
VerificationTest[
    (CodeCheckFix[ #1 ][ "FixedCode" ] &)[ "first_symbol = 1;\nsecond_symbol = 2;\nfirst_symbol + second_symbol" ],
    "firstSymbol = 1;\nsecondSymbol = 2;\nfirstSymbol + secondSymbol",
    TestID -> "1_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1025,1-1029,2"
]

VerificationTest[
    (CodeCheckFix[ #1 ][ "FixedCode" ] &)[ "x_1 = 1;\nx_2 = 2;\ny_1_2 = f[x_1, x_2]" ],
    "x1 = 1;\nx2 = 2;\ny12 = f[x1, x2]",
    TestID -> "2_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1031,1-1035,2"
]

VerificationTest[
    (CodeCheckFix[ #1 ][ "FixedCode" ] &)[ "f[my_symbol] = 123" ],
    Missing[ "No errors detected" ],
    TestID -> "3_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1037,1-1041,2"
]

VerificationTest[
    (CodeCheckFix[ #1 ][ "FixedCode" ] &)[ "f[my_cool_symbol] = 123" ],
    "f[myCoolSymbol] = 123",
    TestID -> "4_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1043,1-1047,2"
]

VerificationTest[
    (CodeCheckFix[ #1 ][ "FixedCode" ] &)[ "my_cool_symbol[a]" ],
    "myCoolSymbol[a]",
    TestID -> "5_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1049,1-1053,2"
]

VerificationTest[
    (CodeCheckFix[ #1 ][ "FixedCode" ] &)[ "my_cool_1[a]" ],
    "myCool1[a]",
    TestID -> "6_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1055,1-1059,2"
]

VerificationTest[
    (CodeCheckFix[ #1 ][ "FixedCode" ] &)[ "my_cool[a]" ],
    "myCool[a]",
    TestID -> "7_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1061,1-1065,2"
]

VerificationTest[
    (CodeCheckFix[ #1 ][ "FixedCode" ] &)[ "my_1[a]" ],
    "my1[a]",
    TestID -> "8_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1067,1-1071,2"
]

VerificationTest[
    (CodeCheckFix[ #1 ][ "FixedCode" ] &)[ "my_symbol := 123" ],
    Missing[ "No errors detected" ],
    TestID -> "9_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1073,1-1077,2"
]

VerificationTest[
    (CodeCheckFix[ #1 ][ "FixedCode" ] &)[ "my_cool_symbol := 123" ],
    "myCoolSymbol := 123",
    TestID -> "10_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1079,1-1083,2"
]

VerificationTest[
    (CodeCheckFix[ #1 ][ "FixedCode" ] &)[ "f[x_1, x_2]" ],
    "f[x1, x2]",
    TestID -> "11_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1085,1-1089,2"
]

VerificationTest[
    (CodeCheckFix[ #1 ][ "FixedCode" ] &)[ "x_1=2" ],
    "x1=2",
    TestID -> "12_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1091,1-1095,2"
]

VerificationTest[
    (CodeCheckFix[ #1 ][ "FixedCode" ] &)[ "f[x_ 1, x_ 2]" ],
    Missing[ "No errors detected" ],
    TestID -> "13_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1097,1-1101,2"
]

VerificationTest[
    (CodeCheckFix[ #1 ][ "FixedCode" ] &)[
        "my_offset = 123;\n(* my_string_length is a really neat function *)\nmy_string_length[test_String] := StringLength[test] + my_offset;\nmy_string_length[\"my_string_length\"]"
    ],
    "myOffset = 123;\n(* my_string_length is a really neat function *)\nmyStringLength[testString] := StringLength[test] + myOffset;\nmyStringLength[\"my_string_length\"]",
    TestID -> "14_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1103,1-1109,2"
]

VerificationTest[
    CodeCheckFix[ "x_a=1" ][ "FixedCode" ],
    "xA=1",
    TestID -> "15_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1111,1-1115,2"
]

VerificationTest[
    CodeCheckFix[ "x_a+1" ][ "FixedCode" ],
    Missing[ "No errors detected" ],
    TestID -> "16_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1117,1-1121,2"
]

VerificationTest[
    CodeCheckFix[ "x_ a =1" ][ "FixedCode" ],
    Missing[ "Pattern not handled", { { "Error", "ImplicitTimesInSet" } } ],
    TestID -> "17_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1123,1-1127,2"
]

VerificationTest[
    CodeCheckFix[ "x_ a +1" ][ "FixedCode" ],
    Missing[ "No errors detected" ],
    TestID -> "18_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1129,1-1133,2"
]

VerificationTest[
    CodeCheckFix[ "x_123=1" ][ "FixedCode" ],
    "x123=1",
    TestID -> "19_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1135,1-1139,2"
]

VerificationTest[
    CodeCheckFix[ "x_123+1" ][ "FixedCode" ],
    "x123+1",
    TestID -> "20_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1141,1-1145,2"
]

VerificationTest[
    CodeCheckFix[ "x_ 123=1" ][ "FixedCode" ],
    Missing[ "Pattern not handled", { { "Error", "ImplicitTimesInSet" } } ],
    TestID -> "21_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1147,1-1151,2"
]

VerificationTest[
    CodeCheckFix[ "x_ 123+1" ][ "FixedCode" ],
    Missing[ "No errors detected" ],
    TestID -> "22_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1153,1-1157,2"
]

VerificationTest[
    CodeCheckFix[ "x_1a=1" ][ "FixedCode" ],
    "x1a=1",
    TestID -> "23_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1159,1-1163,2"
]

VerificationTest[
    CodeCheckFix[ "x_1a+1" ][ "FixedCode" ],
    "x1a+1",
    TestID -> "24_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1165,1-1169,2"
]

VerificationTest[
    CodeCheckFix[ "x_1a9=1" ][ "FixedCode" ],
    "x1a9=1",
    TestID -> "25_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1171,1-1175,2"
]

VerificationTest[
    CodeCheckFix[ "x_1a9+1" ][ "FixedCode" ],
    "x1a9+1",
    TestID -> "26_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1177,1-1181,2"
]

VerificationTest[
    CodeCheckFix[ "x_1 a9=1" ][ "FixedCode" ],
    Missing[ "Pattern not handled", { { "Error", "ImplicitTimesInSet" } } ],
    TestID -> "27_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1183,1-1187,2"
]

VerificationTest[
    CodeCheckFix[ "x_1 a9+1" ][ "FixedCode" ],
    "x1 a9+1",
    TestID -> "28_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1189,1-1193,2"
]

VerificationTest[
    CodeCheckFix[ "x_1a 9+1" ][ "FixedCode" ],
    "x1a 9+1",
    TestID -> "29_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1195,1-1199,2"
]

VerificationTest[
    CodeCheckFix[ "x_1_2=1" ][ "FixedCode" ],
    "x12=1",
    TestID -> "30_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1201,1-1205,2"
]

VerificationTest[
    CodeCheckFix[ "x_1_2:=1" ][ "FixedCode" ],
    "x12:=1",
    TestID -> "31_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1207,1-1211,2"
]

VerificationTest[
    CodeCheckFix[ "x__1___2:=1" ][ "FixedCode" ],
    "x12:=1",
    TestID -> "32_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1213,1-1217,2"
]

VerificationTest[
    CodeCheckFix[ "x___a_1__2b_CC__2:=1" ][ "FixedCode" ],
    "xA12bCC2:=1",
    TestID -> "33_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1219,1-1223,2"
]

VerificationTest[
    CodeCheckFix[ "x_a=1; y__b_2_d=2;x_a + x_b + x__c_1" ][ "FixedCode" ],
    "xA=1; yB2D=2;xA + x_b + xC1",
    TestID -> "34_badSnakeUsage_UT@@Tests/CodeCheck.wlt:1225,1-1229,2"
]
(* ---- Quantity unit names *)
VerificationTest[
  ({#1, CodeCheckFix[ToString[Unevaluated[Quantity[1, #1]], InputForm]]["FixedCode"]} & ) /@ {"AmpereSquareMeter", "Attofarad", "AttogramPerCubicMeter", "Attohenry", "Attolux", "Attosiemens", "Attoweber", "BecquerelPerGram", "CandelaPerSquareMeter", "CentigalPerSecond", "Centilux", "CentinewtonMeter", "CentinewtonSecond", "Centitesla", "CoulombPerKilogram", "CubicMetersPerSecond", "Decamole", "Decibel", "DecibelPerMeter", "DeciliterPerMinute", "DecilumenMinute", "DeciluxSecond", "Deciparsec", "Decipascal", "DecipascalSecond", "DecivoltPerMeter", "Degrees", "ErgPerGram", "FemtoampereSecond", "FemtocoulombSeconds", "FemtohenryPerMeter", "Femtohertz", "Femtojoule", "FemtojoulePerKelvin", "FemtolambertSecond", "Femtoliter", "FemtomolePerSecond", "FemtonewtonMeter", "Femtosievert", "Femtotesla", "Gigacurie", "Gigafurlong", "Gigahertz", "Gigapascal", "GigavoltSecond", "GramPerCentimeterCubed", "GrayPerSecond", "Hectohertz", "Hectokatal", "Hectokelvin", "Hectolambert", "Hectolumen", "HectoluxSecond", "HectometerPerSecond", "HectopascalSecond", "Hectowatt", "HenryPerMeter", "HertzSecond", "JoulePerCoulomb", "JoulePerKelvin", "Katal", "KelvinPerWatt", "KiloampereHour", "Kilofurlongs", "KilogaussSecond", "KilogramsPerCubicMeter", "KilogramsPerMetersCubed", "KilojoulePerMole", "KiloluxPerSteradian", "Kilomole", "KilomolePerSecond", "Kiloohms", "KilopascalPerMeter", "KilowattHour", "KilowattHours", "KiloweberPerSecond", "LuxSecond", "Megabecquerel", "MegaergPerKelvin", "Megaergs", "Megagauss", "MegagramPerLiter", "MeganewtonMeter", "Megaoersted", "MegaohmCentimeter", "Megaparsec", "MegatonPerSecond", "MeterPerSecondSquared", "Microbarns", "Microcurie", "Microdarcy", "Microgray", "MicrograyPerSecond", "Microkayser", "Microlambert", "Microlux", "MilesPerHour", "MillicandelaPerSquareMeter", "Millifarad", "Milligal", "MillimolePerGram", "MillionShortTons", "MillipascalSeconds", "Millirad", "Millisiemens", "MilliteslaMeter", "MolePerLiter", "NanobarnSecond", "NanofaradSecond", "Nanogray", "NanometerPerPicosecond", "NanomolePerLiter", "Nanopascal", "Nanoradian", "NanosecondPerMeter", "Nanostoke", "Nanotesla", "NanoteslaSecond", "NewtonMeter", "NewtonSecond", "OhmMeter", "Pascalliters", "PascalSecond", "Petaampere", "Petabyte", "Petagram", "Petalux", "PetameterPerSecond", "Petapascal", "Petasiemens", "Picoampere", "PicogramPerMilliliter", "Picogray", "PicoohmMeter", "Picotorr", "Picowebers", "RoodPerSecond", "SiemensPerMeter", "SievertPerHour", "Terabit", "TeracandelaHour", "Teragram", "Terajoule", "TeslaSecond", "Tons", "VoltPerMeter", "WattPerSteradian", "Year", "Yoctosecond", "Yoctosiemens", "Yoctowatt", "Yottabyte", "YottameterCube", "Yottawatt", "Zeptocoulomb", "Zeptojoule", "Zeptolumen", "Zeptonewton", "Zeptosecond", "Zettajoule"},
  {{"AmpereSquareMeter", "Quantity[1, \"Ampere\"*\"SquareMeters\"]"}, {"Attofarad", "Quantity[1, \"Attofarads\"]"}, {"AttogramPerCubicMeter", "Quantity[1, \"Attograms\"/\"CubicMeters\"]"}, {"Attohenry", Missing["Unknown unit", "Attohenry"]}, {"Attolux", Missing["No errors detected"]}, {"Attosiemens", Missing["No errors detected"]}, {"Attoweber", "Quantity[1, \"Attowebers\"]"}, {"BecquerelPerGram", "Quantity[1, \"Becquerel\"/\"Grams\"]"}, {"CandelaPerSquareMeter", "Quantity[1, \"Candelas\"/\"SquareMeters\"]"}, {"CentigalPerSecond", Missing["Unknown unit", "CentigalPerSecond"]}, {"Centilux", Missing["No errors detected"]}, {"CentinewtonMeter", "Quantity[1, \"Centinewtons\"*\"Meter\"]"}, {"CentinewtonSecond", "Quantity[1, \"Centinewtons\"*\"Second\"]"}, {"Centitesla", "Quantity[1, \"Centiteslas\"]"}, {"CoulombPerKilogram", "Quantity[1, \"Coulomb\"/\"Kilogram\"]"}, {"CubicMetersPerSecond", "Quantity[1, \"CubicMeters\"/\"Second\"]"}, {"Decamole", Missing["Unknown unit", "Decamole"]}, {"Decibel", Missing["Unknown unit", "Decibel"]}, {"DecibelPerMeter", Missing["Unknown unit", "DecibelPerMeter"]}, {"DeciliterPerMinute", "Quantity[1, \"Deciliters\"/\"Minute\"]"}, {"DecilumenMinute", "Quantity[1, \"Decilumens\"*\"Minute\"]"}, {"DeciluxSecond", "Quantity[1, \"Decilux\"*\"Second\"]"}, {"Deciparsec", Missing["Unknown unit", "Deciparsec"]}, {"Decipascal", "Quantity[1, \"Decipascals\"]"}, {"DecipascalSecond", "Quantity[1, \"Decipascals\"*\"Second\"]"}, {"DecivoltPerMeter", "Quantity[1, \"Decivolts\"/\"Meter\"]"}, {"Degrees", Missing["No errors detected"]}, {"ErgPerGram", "Quantity[1, \"Ergs\"/\"Grams\"]"}, {"FemtoampereSecond", "Quantity[1, \"Femtoamperes\"*\"Second\"]"}, {"FemtocoulombSeconds", "Quantity[1, \"Femtocoulombs\"*\"Seconds\"]"}, {"FemtohenryPerMeter", Missing["Unknown unit", "FemtohenryPerMeter"]}, {"Femtohertz", Missing["No errors detected"]}, {"Femtojoule", "Quantity[1, \"Femtojoules\"]"}, {"FemtojoulePerKelvin", "Quantity[1, \"Femtojoules\"/\"Kelvin\"]"}, {"FemtolambertSecond", Missing["Unknown unit", "FemtolambertSecond"]}, {"Femtoliter", "Quantity[1, \"Femtoliters\"]"}, {"FemtomolePerSecond", "Quantity[1, \"Femtomoles\"/\"Second\"]"}, {"FemtonewtonMeter", "Quantity[1, \"Femtonewtons\"*\"Meter\"]"}, {"Femtosievert", "Quantity[1, \"Femtosieverts\"]"}, {"Femtotesla", "Quantity[1, \"Femtoteslas\"]"}, {"Gigacurie", "Quantity[1, \"Gigacuries\"]"}, {"Gigafurlong", "Quantity[1, \"Gigafurlongs\"]"}, {"Gigahertz", Missing["No errors detected"]}, {"Gigapascal", "Quantity[1, \"Gigapascals\"]"}, {"GigavoltSecond", "Quantity[1, \"Gigavolts\"*\"Second\"]"}, {"GramPerCentimeterCubed", "Quantity[1, \"Grams\"/\"Centimeters\"^3]"}, {"GrayPerSecond", "Quantity[1, \"Gray\"/\"Second\"]"}, {"Hectohertz", Missing["No errors detected"]}, {"Hectokatal", "Quantity[1, \"Hectokatals\"]"}, {"Hectokelvin", "Quantity[1, \"Hectokelvins\"]"}, {"Hectolambert", Missing["Unknown unit", "Hectolambert"]}, {"Hectolumen", "Quantity[1, \"Hectolumens\"]"}, {"HectoluxSecond", "Quantity[1, \"Hectolux\"*\"Second\"]"}, {"HectometerPerSecond", "Quantity[1, \"Hectometers\"/\"Second\"]"}, {"HectopascalSecond", "Quantity[1, \"Hectopascals\"*\"Second\"]"}, {"Hectowatt", "Quantity[1, \"Hectowatts\"]"}, {"HenryPerMeter", "Quantity[1, \"Henry\"/\"Meter\"]"}, {"HertzSecond", "Quantity[1, \"Hertz\"*\"Second\"]"}, {"JoulePerCoulomb", "Quantity[1, \"Joule\"/\"Coulomb\"]"}, {"JoulePerKelvin", "Quantity[1, \"Joule\"/\"Kelvin\"]"}, {"Katal", Missing["No errors detected"]}, {"KelvinPerWatt", "Quantity[1, \"Kelvin\"/\"Watt\"]"}, {"KiloampereHour", "Quantity[1, \"Hour\"*\"Kiloamperes\"]"}, {"Kilofurlongs", Missing["No errors detected"]}, {"KilogaussSecond", "Quantity[1, \"Kilogauss\"*\"Second\"]"}, {"KilogramsPerCubicMeter", Missing["No errors detected"]}, {"KilogramsPerMetersCubed", "Quantity[1, \"Kilograms\"/\"Meters\"^3]"}, {"KilojoulePerMole", "Quantity[1, \"Kilojoules\"/\"Mole\"]"}, {"KiloluxPerSteradian", "Quantity[1, \"Kilolux\"/\"Steradian\"]"}, {"Kilomole", "Quantity[1, \"Kilomoles\"]"}, {"KilomolePerSecond", "Quantity[1, \"Kilomoles\"/\"Second\"]"}, {"Kiloohms", Missing["No errors detected"]}, {"KilopascalPerMeter", "Quantity[1, \"Kilopascals\"/\"Meter\"]"}, {"KilowattHour", "Quantity[1, \"Hour\"*\"Kilowatts\"]"}, {"KilowattHours", "Quantity[1, \"Hours\"*\"Kilowatts\"]"}, {"KiloweberPerSecond", "Quantity[1, \"Kilowebers\"/\"Second\"]"}, {"LuxSecond", "Quantity[1, \"Lux\"*\"Second\"]"}, {"Megabecquerel", "Quantity[1, \"Megabecquerels\"]"}, {"MegaergPerKelvin", Missing["Unknown unit", "MegaergPerKelvin"]}, {"Megaergs", Missing["Unknown unit", "Megaergs"]}, {"Megagauss", Missing["No errors detected"]}, {"MegagramPerLiter", "Quantity[1, \"Megagrams\"/\"Liters\"]"}, {"MeganewtonMeter", "Quantity[1, \"Meganewtons\"*\"Meter\"]"}, {"Megaoersted", Missing["Unknown unit", "Megaoersted"]}, {"MegaohmCentimeter", "Quantity[1, \"Centimeters\"*\"Megaohms\"]"}, {"Megaparsec", "Quantity[1, \"Megaparsecs\"]"}, {"MegatonPerSecond", Missing["Unknown unit", "MegatonPerSecond"]}, {"MeterPerSecondSquared", "Quantity[1, \"Meter\"/\"Second\"^2]"}, {"Microbarns", Missing["No errors detected"]}, {"Microcurie", "Quantity[1, \"Microcuries\"]"}, {"Microdarcy", Missing["Unknown unit", "Microdarcy"]}, {"Microgray", "Quantity[1, \"Micrograys\"]"}, {"MicrograyPerSecond", "Quantity[1, \"Micrograys\"/\"Second\"]"}, {"Microkayser", Missing["Unknown unit", "Microkayser"]}, {"Microlambert", "Quantity[1, \"Microlamberts\"]"}, {"Microlux", Missing["No errors detected"]}, {"MilesPerHour", "Quantity[1, \"Miles\"/\"Hour\"]"}, {"MillicandelaPerSquareMeter", "Quantity[1, \"Millicandelas\"/\"SquareMeters\"]"}, {"Millifarad", "Quantity[1, \"Millifarads\"]"}, {"Milligal", "Quantity[1, \"Milligals\"]"}, {"MillimolePerGram", "Quantity[1, \"Millimoles\"/\"Grams\"]"}, {"MillionShortTons", "Quantity[1, \"Million\"*\"ShortTons\"]"}, {"MillipascalSeconds", "Quantity[1, \"Millipascals\"*\"Seconds\"]"}, {"Millirad", "Quantity[1, \"Millirads\"]"}, {"Millisiemens", Missing["No errors detected"]}, {"MilliteslaMeter", "Quantity[1, \"Meter\"*\"Milliteslas\"]"}, {"MolePerLiter", "Quantity[1, \"Mole\"/\"Liters\"]"}, {"NanobarnSecond", "Quantity[1, \"Nanobarns\"*\"Second\"]"}, {"NanofaradSecond", "Quantity[1, \"Nanofarads\"*\"Second\"]"}, {"Nanogray", "Quantity[1, \"Nanograys\"]"}, {"NanometerPerPicosecond", "Quantity[1, \"Nanometers\"/\"Picoseconds\"]"}, {"NanomolePerLiter", "Quantity[1, \"Nanomoles\"/\"Liters\"]"}, {"Nanopascal", "Quantity[1, \"Nanopascals\"]"}, {"Nanoradian", "Quantity[1, \"Nanoradians\"]"}, {"NanosecondPerMeter", "Quantity[1, \"Nanoseconds\"/\"Meter\"]"}, {"Nanostoke", Missing["Unknown unit", "Nanostoke"]}, {"Nanotesla", "Quantity[1, \"Nanoteslas\"]"}, {"NanoteslaSecond", "Quantity[1, \"Nanoteslas\"*\"Second\"]"}, {"NewtonMeter", "Quantity[1, \"Meter\"*\"Newton\"]"}, {"NewtonSecond", "Quantity[1, \"Newton\"*\"Second\"]"}, {"OhmMeter", "Quantity[1, \"Meter\"*\"Ohm\"]"}, {"Pascalliters", Missing["Unknown unit", "Pascalliters"]}, {"PascalSecond", "Quantity[1, \"Pascal\"*\"Second\"]"}, {"Petaampere", "Quantity[1, \"Petaamperes\"]"}, {"Petabyte", "Quantity[1, \"Petabytes\"]"}, {"Petagram", "Quantity[1, \"Petagrams\"]"}, {"Petalux", Missing["No errors detected"]}, {"PetameterPerSecond", "Quantity[1, \"Petameters\"/\"Second\"]"}, {"Petapascal", "Quantity[1, \"Petapascals\"]"}, {"Petasiemens", Missing["No errors detected"]}, {"Picoampere", "Quantity[1, \"Picoamperes\"]"}, {"PicogramPerMilliliter", "Quantity[1, \"Picograms\"/\"Milliliters\"]"}, {"Picogray", "Quantity[1, \"Picograys\"]"}, {"PicoohmMeter", "Quantity[1, \"Meter\"*\"Picoohms\"]"}, {"Picotorr", Missing["Unknown unit", "Picotorr"]}, {"Picowebers", Missing["No errors detected"]}, {"RoodPerSecond", "Quantity[1, \"Roods\"/\"Second\"]"}, {"SiemensPerMeter", Missing["No errors detected"]}, {"SievertPerHour", "Quantity[1, \"Sievert\"/\"Hour\"]"}, {"Terabit", "Quantity[1, \"Terabits\"]"}, {"TeracandelaHour", "Quantity[1, \"Hour\"*\"Teracandelas\"]"}, {"Teragram", "Quantity[1, \"Teragrams\"]"}, {"Terajoule", "Quantity[1, \"Terajoules\"]"}, {"TeslaSecond", "Quantity[1, \"Second\"*\"Tesla\"]"}, {"Tons", Missing["Unknown unit", "Tons"]}, {"VoltPerMeter", "Quantity[1, \"Volt\"/\"Meter\"]"}, {"WattPerSteradian", "Quantity[1, \"Watt\"/\"Steradian\"]"}, {"Year", Missing["No errors detected"]}, {"Yoctosecond", "Quantity[1, \"Yoctoseconds\"]"}, {"Yoctosiemens", Missing["No errors detected"]}, {"Yoctowatt", "Quantity[1, \"Yoctowatts\"]"}, {"Yottabyte", "Quantity[1, \"Yottabytes\"]"}, {"YottameterCube", "Quantity[1, \"Cubes\"*\"Yottameters\"]"}, {"Yottawatt", "Quantity[1, \"Yottawatts\"]"}, {"Zeptocoulomb", "Quantity[1, \"Zeptocoulombs\"]"}, {"Zeptojoule", "Quantity[1, \"Zeptojoules\"]"}, {"Zeptolumen", "Quantity[1, \"Zeptolumens\"]"}, {"Zeptonewton", "Quantity[1, \"Zeptonewtons\"]"}, {"Zeptosecond", "Quantity[1, \"Zeptoseconds\"]"}, {"Zettajoule", "Quantity[1, \"Zettajoules\"]"}},
  TestID -> "Untitled-6@@Tests/CodeCheck.wlt:1231,1-1235,2"
]

VerificationTest[
  SameQ[({Times @@@ #1, StringCases[Shortest["Quantity["~~__~~","~~v__~~"]"] :> ToExpression[StringTrim[v]]][(Map[CodeCheckFix[ToString[Unevaluated[Quantity[1, #1]], InputForm]]["FixedCode"] & ])[#1]]} & )[(Map[StringJoin])[{{"PerchesLength", "Kerats", "Femtohertz", "Zm", "IndianMustis", "Pouces"}, {"Droits", "BritishThermalUnitsMean", "PiedsDuRoi", "Kilofeet", "Dekayards"}, {"MilliVAs", "Tierces"}, {"Megabars", "GallonsUK", "GuatemalaCentavos", "RomanScriptula", "JovianMassParameter"}, {"Radians", "Xennameters"}, {"Hcd", "VDC", "BritishLivestockUnits", "KiB", "Gavyutis"}, {"Milligons", "ElectricConstant"}, {"Bushels53Pound", "Microlumens"}, {"Lactabits", "Megawebers", "ShortQuires", "Spheres", "Tamms", "MinimalPerceptibleErythema"}, {"Hartrees", "Vendekoohms", "Tt"}}]]],
  True,
  TestID -> "Untitled-7@@Tests/CodeCheck.wlt:1237,1-1241,2"
]

VerificationTest[
  CodeCheckFix["Quantity[1, \"Meter\"]"],
  Association["ErrorsDetected" -> False, "CodeInspector" -> Association["InspectionObjects" -> {}, "OverallSeverity" -> None], "FixedCode" -> Missing["No errors detected"], "OriginalCode" -> "Quantity[1, \"Meter\"]"],
  TestID -> "Untitled-8@@Tests/CodeCheck.wlt:1243,1-1247,2"
]

 VerificationTest[
  CodeCheckFix["Quantity[1, \"AmpereSquareMeter\"]"],
  Association["ErrorsDetected" -> True, "CodeInspector" -> Association["InspectionObjects" -> {CodeInspector`InspectionObject["SuspiciousQuantityUnitName", "Suspicious Quantity Unit Name", "Fatal", Association[ConfidenceLevel -> 1, CodeParser`Source -> {13, 31}]]}, "OverallSeverity" -> 4], "Success" -> True, "TotalFixes" -> 1, "LikelyFalsePositive" -> False, "SafeToEvaluate" -> True, "FixedCode" -> "Quantity[1, \"Ampere\"*\"SquareMeters\"]", "FixedPatterns" -> {{{"Fatal", "SuspiciousQuantityUnitName"} -> {13, 31}}}, "OriginalCode" -> "Quantity[1, \"AmpereSquareMeter\"]"],
  TestID -> "Untitled-9@@Tests/CodeCheck.wlt:1249,2-1253,2"
]

VerificationTest[
  CodeCheckFix["Quantity[1, \"DecibelPerMeter\"]"],
  Association["ErrorsDetected" -> True, "CodeInspector" -> Association["InspectionObjects" -> {CodeInspector`InspectionObject["SuspiciousQuantityUnitName", "Suspicious Quantity Unit Name", "Fatal", Association[ConfidenceLevel -> 1, CodeParser`Source -> {13, 29}]]}, "OverallSeverity" -> 4], "Success" -> False, "TotalFixes" -> 0, "LikelyFalsePositive" -> False, "SafeToEvaluate" -> True, "FixedCode" -> Missing["Unknown unit", "DecibelPerMeter"], "FixedPatterns" -> {{{"Fatal", "SuspiciousQuantityUnitName"} -> {13, 29}}}, "OriginalCode" -> "Quantity[1, \"DecibelPerMeter\"]"],
  TestID -> "Untitled-10@@Tests/CodeCheck.wlt:1255,1-1259,2"
]