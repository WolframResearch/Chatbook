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
VerificationTest[
    CodeCheckFix[ "f[x,y,]" ],
    KeyValuePattern @ {
        "ErrorsDetected"      -> True,
        "FixedCode"           -> "f[x,y]",
        "LikelyFalsePositive" -> False,
        "OriginalCode"        -> "f[x,y,]",
        "SafeToEvaluate"      -> True,
        "Success"             -> True,
        "CodeInspector"       -> KeyValuePattern @ {
            "InspectionObjects" -> { __CodeInspector`InspectionObject },
            "OverallSeverity"   -> _Integer
        }
    },
    SameTest -> MatchQ,
    TestID   -> "CodeCheckFix-Basic-Example@@Tests/CodeCheck.wlt:28,1-44,2"
]
