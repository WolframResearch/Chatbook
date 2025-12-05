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

(* -------------------- SCORING for ambiguous cases - MissingCloser and UnexpectedCloser  *)

VerificationTest[(CodeCheckFix[#1, "Target" -> "Evaluator"] & )["f[a,g[h];b[c]"], <|"ErrorsDetected" -> True, "CodeInspector" -> <|"InspectionObjects" -> {CodeInspector`InspectionObject["GroupMissingCloser", "Missing closer.", "Fatal", <|CodeParser`Source -> {2, 2}, ConfidenceLevel -> 1.|>]}, "OverallSeverity" -> 4|>, "Success" -> True, "TotalFixes" -> 1, "LikelyFalsePositive" -> False, "SafeToEvaluate" -> True, "FixedCode" -> "f[a,g[h];b[c]]", "FixedPatterns" -> {{{"Fatal", "GroupMissingCloser"}}}, "OriginalCode" -> "f[a,g[h];b[c]"|>
	,TestID->"1_scoreAmbiguous_UT"]
VerificationTest[(CodeCheckFix[#1, "Target" -> "Evaluator"] & )["Graphics3D[{a,{b},{c,Red},ViewPoint -> {1, -2, 1}]"], <|"ErrorsDetected" -> True, "CodeInspector" -> <|"InspectionObjects" -> {CodeInspector`InspectionObject["GroupMissingCloser", "Missing closer.", "Fatal", <|CodeParser`Source -> {12, 12}, ConfidenceLevel -> 1.|>]}, "OverallSeverity" -> 4|>, "Success" -> True, "TotalFixes" -> 1, "LikelyFalsePositive" -> False, "SafeToEvaluate" -> True, "FixedCode" -> "Graphics3D[{a,{b},{c,Red}},ViewPoint -> {1, -2, 1}]", "FixedPatterns" -> {{{"Fatal", "GroupMissingCloser"}}}, "OriginalCode" -> "Graphics3D[{a,{b},{c,Red},ViewPoint -> {1, -2, 1}]"|>
	,TestID->"2_scoreAmbiguous_UT"]
VerificationTest[(CodeCheckFix[#1, "Target" -> "Evaluator"] & )["Graphics3D[{a,{b},{c,Red},ViewPoint -> Automatic]"], <|"ErrorsDetected" -> True, "CodeInspector" -> <|"InspectionObjects" -> {CodeInspector`InspectionObject["GroupMissingCloser", "Missing closer.", "Fatal", <|CodeParser`Source -> {12, 12}, ConfidenceLevel -> 1.|>]}, "OverallSeverity" -> 4|>, "Success" -> True, "TotalFixes" -> 1, "LikelyFalsePositive" -> False, "SafeToEvaluate" -> True, "FixedCode" -> "Graphics3D[{a,{b},{c,Red}},ViewPoint -> Automatic]", "FixedPatterns" -> {{{"Fatal", "GroupMissingCloser"}}}, "OriginalCode" -> "Graphics3D[{a,{b},{c,Red},ViewPoint -> Automatic]"|>
	,TestID->"3_scoreAmbiguous_UT"]
VerificationTest[(CodeCheckFix[#1, "Target" -> "Evaluator"] & )["graphics3D[{a,{b},{c,Red},ViewPoint -> Automatic]"], <|"ErrorsDetected" -> True, "CodeInspector" -> <|"InspectionObjects" -> {CodeInspector`InspectionObject["GroupMissingCloser", "Missing closer.", "Fatal", <|CodeParser`Source -> {12, 12}, ConfidenceLevel -> 1.|>]}, "OverallSeverity" -> 4|>, "Success" -> True, "TotalFixes" -> 1, "LikelyFalsePositive" -> False, "SafeToEvaluate" -> True, "FixedCode" -> "graphics3D[{a,{b},{c,Red}},ViewPoint -> Automatic]", "FixedPatterns" -> {{{"Fatal", "GroupMissingCloser"}}}, "OriginalCode" -> "graphics3D[{a,{b},{c,Red},ViewPoint -> Automatic]"|>
	,TestID->"4_scoreAmbiguous_UT"]
VerificationTest[(CodeCheckFix[#1, "Target" -> "Evaluator"] & )["Graphics3D[{a,b,{c,Red},viewPoint -> Automatic]"], <|"ErrorsDetected" -> True, "CodeInspector" -> <|"InspectionObjects" -> {CodeInspector`InspectionObject["GroupMissingCloser", "Missing closer.", "Fatal", <|CodeParser`Source -> {12, 12}, ConfidenceLevel -> 1.|>]}, "OverallSeverity" -> 4|>, "Success" -> True, "TotalFixes" -> 1, "LikelyFalsePositive" -> False, "SafeToEvaluate" -> True, "FixedCode" -> "Graphics3D[{a,b,{c,Red}},viewPoint -> Automatic]", "FixedPatterns" -> {{{"Fatal", "GroupMissingCloser"}}}, "OriginalCode" -> "Graphics3D[{a,b,{c,Red},viewPoint -> Automatic]"|>
	,TestID->"5_scoreAmbiguous_UT"]
VerificationTest[(CodeCheckFix[#1, "Target" -> "Evaluator"] & )["graphics3D[{a,b,{c,Red},viewPoint -> {1, -2, 1}]"], <|"ErrorsDetected" -> True, "CodeInspector" -> <|"InspectionObjects" -> {CodeInspector`InspectionObject["GroupMissingCloser", "Missing closer.", "Fatal", <|CodeParser`Source -> {12, 12}, ConfidenceLevel -> 1.|>]}, "OverallSeverity" -> 4|>, "Success" -> True, "TotalFixes" -> 1, "LikelyFalsePositive" -> False, "SafeToEvaluate" -> True, "FixedCode" -> "graphics3D[{a,b,{c,Red},viewPoint -> {1, -2, 1}}]", "FixedPatterns" -> {{{"Fatal", "GroupMissingCloser"}}}, "OriginalCode" -> "graphics3D[{a,b,{c,Red},viewPoint -> {1, -2, 1}]"|>
	,TestID->"6_scoreAmbiguous_UT"]

(* -------------------- BAD SNAKE USAGE *)

VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["first_symbol = 1;\nsecond_symbol = 2;\nfirst_symbol + second_symbol"], "firstSymbol = 1;\nsecondSymbol = 2;\nfirstSymbol + secondSymbol"
	,TestID->"1_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["x_1 = 1;\nx_2 = 2;\ny_1_2 = f[x_1, x_2]"], "x1 = 1;\nx2 = 2;\ny12 = f[x1, x2]"
	,TestID->"2_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["f[my_symbol] = 123"], Missing["No errors detected"]
	,TestID->"3_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["f[my_cool_symbol] = 123"], "f[myCoolSymbol] = 123"
	,TestID->"4_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["my_cool_symbol[a]"], "myCoolSymbol[a]"
	,TestID->"5_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["my_cool_1[a]"], "myCool1[a]"
	,TestID->"6_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["my_cool[a]"], "myCool[a]"
	,TestID->"7_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["my_1[a]"], "my1[a]"
	,TestID->"8_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["my_symbol := 123"], Missing["No errors detected"]
	,TestID->"9_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["my_cool_symbol := 123"], "myCoolSymbol := 123"
	,TestID->"10_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["f[x_1, x_2]"], "f[x1, x2]"
	,TestID->"11_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["x_1=2"], "x1=2"
	,TestID->"12_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["f[x_ 1, x_ 2]"], Missing["No errors detected"]
	,TestID->"13_badSnakeUsage_UT"]
VerificationTest[(CodeCheckFix[#1]["FixedCode"] & )["my_offset = 123;\n(* my_string_length is a really neat function *)\nmy_string_length[test_String] := StringLength[test] + my_offset;\nmy_string_length[\"my_string_length\"]"], "myOffset = 123;\n(* my_string_length is a really neat function *)\nmyStringLength[testString] := StringLength[test] + myOffset;\nmyStringLength[\"my_string_length\"]"
	,TestID->"14_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_a=1"]["FixedCode"], "xA=1"
	,TestID->"15_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_a+1"]["FixedCode"], Missing["No errors detected"]
	,TestID->"16_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_ a =1"]["FixedCode"], Missing["Pattern not handled", {{"Error", "ImplicitTimesInSet"}}]
	,TestID->"17_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_ a +1"]["FixedCode"], Missing["No errors detected"]
	,TestID->"18_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_123=1"]["FixedCode"], "x123=1"
	,TestID->"19_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_123+1"]["FixedCode"], "x123+1"
	,TestID->"20_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_ 123=1"]["FixedCode"], Missing["Pattern not handled", {{"Error", "ImplicitTimesInSet"}}]
	,TestID->"21_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_ 123+1"]["FixedCode"], Missing["No errors detected"]
	,TestID->"22_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1a=1"]["FixedCode"], "x1a=1"
	,TestID->"23_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1a+1"]["FixedCode"], "x1a+1"
	,TestID->"24_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1a9=1"]["FixedCode"], "x1a9=1"
	,TestID->"25_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1a9+1"]["FixedCode"], "x1a9+1"
	,TestID->"26_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1 a9=1"]["FixedCode"], Missing["Pattern not handled", {{"Error", "ImplicitTimesInSet"}}]
	,TestID->"27_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1 a9+1"]["FixedCode"], "x1 a9+1"
	,TestID->"28_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1a 9+1"]["FixedCode"], "x1a 9+1"
	,TestID->"29_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1_2=1"]["FixedCode"], "x12=1"
	,TestID->"30_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_1_2:=1"]["FixedCode"], "x12:=1"
	,TestID->"31_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x__1___2:=1"]["FixedCode"], "x12:=1"
	,TestID->"32_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x___a_1__2b_CC__2:=1"]["FixedCode"], "xA12bCC2:=1"
	,TestID->"33_badSnakeUsage_UT"]
VerificationTest[CodeCheckFix["x_a=1; y__b_2_d=2;x_a + x_b + x__c_1"]["FixedCode"], "xA=1; yB2D=2;xA + x_b + xC1"
	,TestID->"34_badSnakeUsage_UT"]