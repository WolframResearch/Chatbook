(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    If[ ! TrueQ @ Wolfram`ChatbookTests`$TestDefinitionsLoaded,
        Get @ FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" }
    ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/CodeCheck.wlt:4,1-11,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`CodeCheck`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/CodeCheck.wlt:13,1-18,2"
]

VerificationTest[
    Context @ CodeCheckFix,
    "Wolfram`Chatbook`CodeCheck`",
    SameTest -> MatchQ,
    TestID   -> "CodeCheckFix-Context@@Tests/CodeCheck.wlt:20,1-25,2"
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
    TestID   -> "CodeCheckFix-Basic-Example@@Tests/CodeCheck.wlt:30,1-46,2"
]
