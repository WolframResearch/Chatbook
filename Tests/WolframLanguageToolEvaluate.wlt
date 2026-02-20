(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/WolframLanguageToolEvaluate.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/WolframLanguageToolEvaluate.wlt:11,1-16,2"
]

VerificationTest[
    Context @ WolframLanguageToolEvaluate,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageToolEvaluateContext@@Tests/WolframLanguageToolEvaluate.wlt:18,1-23,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*WolframLanguageToolEvaluate*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic Evaluation*)
VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1", Method -> "Session" ],
    _String? (StringMatchQ[ "Out["~~DigitCharacter..~~"]= 2"]),
    SameTest -> MatchQ,
    TestID   -> "BasicEvaluation@@Tests/WolframLanguageToolEvaluate.wlt:32,1-37,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1", "String", Method -> "Session" ],
    _String? (StringMatchQ[ "Out["~~DigitCharacter..~~"]= 2"]),
    SameTest -> MatchQ,
    TestID   -> "StringProperty@@Tests/WolframLanguageToolEvaluate.wlt:39,1-44,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1", "Result", Method -> "Session" ],
    HoldCompleteForm[ 2 ],
    SameTest -> MatchQ,
    TestID   -> "ResultProperty@@Tests/WolframLanguageToolEvaluate.wlt:46,1-51,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1", { "Result", "String" }, Method -> "Session" ],
    KeyValuePattern @ { "Result" -> HoldCompleteForm[ 2 ], "String" -> _String },
    SameTest -> MatchQ,
    TestID   -> "MultipleProperties@@Tests/WolframLanguageToolEvaluate.wlt:53,1-58,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1", All, Method -> "Session" ],
    KeyValuePattern @ { "Result" -> HoldCompleteForm[ 2 ], "String" -> _String },
    SameTest -> MatchQ,
    TestID   -> "AllProperties@@Tests/WolframLanguageToolEvaluate.wlt:60,1-65,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Natural Language Input*)
VerificationTest[
    string = WolframLanguageToolEvaluate[ "\[FreeformPrompt][\"Boston, MA\"]", Method -> "Session" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-1@@Tests/WolframLanguageToolEvaluate.wlt:70,1-75,2"
]

VerificationTest[
    StringContainsQ[
        string,
        "[INFO] Interpreted \"Boston, MA\" as: Entity[\"City\", {\"Boston\", \"Massachusetts\", \"UnitedStates\"}]"
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-1-InfoMessage@@Tests/WolframLanguageToolEvaluate.wlt:77,1-85,2"
]

VerificationTest[
    StringEndsQ[
        string,
        "Out[" ~~ DigitCharacter.. ~~ "]= Entity[\"City\", {\"Boston\", \"Massachusetts\", \"UnitedStates\"}]"
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-1-Output@@Tests/WolframLanguageToolEvaluate.wlt:87,1-95,2"
]

VerificationTest[
    string = WolframLanguageToolEvaluate[ "\[FreeformPrompt][\"Springfield\"]", Method -> "Session" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-2@@Tests/WolframLanguageToolEvaluate.wlt:97,1-102,2"
]

VerificationTest[
    StringContainsQ[
        string,
        "[WARNING] Interpreted \"Springfield\" as " ~~ __ ~~ " with other possible interpretations:"
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-2-WarningMessage@@Tests/WolframLanguageToolEvaluate.wlt:104,1-112,2"
]

VerificationTest[
    StringContainsQ[ string, "Entity[\"City\", {\"Springfield\", \"Illinois\", \"UnitedStates\"}]" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-2-Result@@Tests/WolframLanguageToolEvaluate.wlt:114,1-119,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Multimodal Input*)
VerificationTest[
    WolframLanguageToolEvaluate[ { "ImageDimensions[", RandomImage[ ], "]" }, "Result", Method -> "Session" ],
    HoldCompleteForm @ { _Integer, _Integer },
    SameTest -> MatchQ,
    TestID   -> "MultimodalInput-1@@Tests/WolframLanguageToolEvaluate.wlt:124,1-129,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Auto-Correcting Input*)
VerificationTest[
    WolframLanguageToolEvaluate[ "Dimensions[{{1,2},{3,4},{5,6}}", "Result", Method -> "Session" ],
    HoldCompleteForm @ { 3, 2 },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-1@@Tests/WolframLanguageToolEvaluate.wlt:134,1-139,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ { "ImageDimensions[", RandomImage[ ] }, "Result", Method -> "Session" ],
    HoldCompleteForm @ { _Integer, _Integer },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-2@@Tests/WolframLanguageToolEvaluate.wlt:141,1-146,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Edge Cases*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Empty Sequence*)
VerificationTest[
    WolframLanguageToolEvaluate[ "Sequence[]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "Out[1]= Sequence[]",
        "Result" -> HoldCompleteForm @ Sequence[ ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-SequenceInput@@Tests/WolframLanguageToolEvaluate.wlt:155,1-163,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Sneaky Throw*)
VerificationTest[
    as = WolframLanguageToolEvaluate[ "Throw[Unevaluated[Throw[Null]]]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> _String,
        "Result" -> HoldCompleteForm @ Hold @ Throw @ Null
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-UncaughtThrow@@Tests/WolframLanguageToolEvaluate.wlt:168,1-176,2"
]

VerificationTest[
    StringContainsQ[ as[ "String" ], "Throw::nocatch: Uncaught Throw[Null] returned to top level." ],
    True,
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-UncaughtThrow-Message@@Tests/WolframLanguageToolEvaluate.wlt:178,1-183,2"
]

VerificationTest[
    StringContainsQ[ as[ "String" ], "Out[1]= Hold[Throw[Null]]" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-UncaughtThrow-Output@@Tests/WolframLanguageToolEvaluate.wlt:185,1-190,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Throw[Unevaluated[Throw[Null]], \"tag\"]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> _String,
        "Result" -> HoldCompleteForm @ Hold @ Throw[ Throw @ Null, "tag" ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-UncaughtThrow-Tagged@@Tests/WolframLanguageToolEvaluate.wlt:192,1-200,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Abort*)
VerificationTest[
    WolframLanguageToolEvaluate[ "Abort[]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "Out[1]= $Aborted",
        "Result" -> HoldCompleteForm @ $Aborted
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-Abort@@Tests/WolframLanguageToolEvaluate.wlt:205,1-213,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Kernel Quit*)
VerificationTest[
    WolframLanguageToolEvaluate[ "Exit[]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "General::quit: The kernel quit unexpectedly during evaluation with exit code 0.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-KernelQuit-Exit-Null@@Tests/WolframLanguageToolEvaluate.wlt:218,1-226,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Exit[1]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "General::quit: The kernel quit unexpectedly during evaluation with exit code 1.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-KernelQuit-Exit-1@@Tests/WolframLanguageToolEvaluate.wlt:228,1-236,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Quit[]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "General::quit: The kernel quit unexpectedly during evaluation with exit code 0.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-KernelQuit-Quit-Null@@Tests/WolframLanguageToolEvaluate.wlt:238,1-246,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Quit[1]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "General::quit: The kernel quit unexpectedly during evaluation with exit code 1.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-KernelQuit-Quit-1@@Tests/WolframLanguageToolEvaluate.wlt:248,1-256,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Exit[1]; Print[\"Hello\"]; Quit[2]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "General::quit: The kernel quit unexpectedly during evaluation with exit code 1.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-KernelQuit-Exit-Stop@@Tests/WolframLanguageToolEvaluate.wlt:258,1-266,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Standard Output/Error Handling*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Messages*)
VerificationTest[
    WolframLanguageToolEvaluate[ "1/0", "String", Method -> "Session" ],
    _String? (StringContainsQ[ "Power::infy: Infinite expression 1/0 encountered." ]),
    SameTest -> MatchQ,
    TestID   -> "MessageFormatting-1@@Tests/WolframLanguageToolEvaluate.wlt:275,1-280,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Message[f::argx, f, Range[1000]]", "String", Method -> "Session" ],
    s_String /; StringLength[ s ] < 500,
    SameTest -> MatchQ,
    TestID   -> "MessageFormatting-2@@Tests/WolframLanguageToolEvaluate.wlt:282,1-287,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Print*)
VerificationTest[
    WolframLanguageToolEvaluate[ "Print[\"a\"]; 1+1", "String", Method -> "Session" ],
    _String? (StringMatchQ[ "During evaluation of In["~~NumberString~~"]:= a\n\nOut["~~NumberString~~"]= 2" ]),
    SameTest -> MatchQ,
    TestID   -> "PrintFormatting-1@@Tests/WolframLanguageToolEvaluate.wlt:292,1-297,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*PrintTemporary*)
VerificationTest[
    WolframLanguageToolEvaluate[ "PrintTemporary[\"a\"]; 1+1", "String", Method -> "Session" ],
    _String? (StringMatchQ[ "During evaluation of In["~~NumberString~~"]:= a\n\nOut["~~NumberString~~"]= 2" ]),
    SameTest -> MatchQ,
    TestID   -> "PrintTemporaryFormatting-1@@Tests/WolframLanguageToolEvaluate.wlt:302,1-307,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Regression Tests*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Override Catch/Throw Tag Forcing*)
VerificationTest[
    WolframLanguageToolEvaluate[ "ContinuedFraction[Pi, 5]", "Result", Method -> "Session" ],
    HoldCompleteForm @ { 3, 7, 15, 1, 292 },
    SameTest -> MatchQ,
    TestID   -> "RegressionTests-OverrideTagForcing@@Tests/WolframLanguageToolEvaluate.wlt:316,1-321,2"
]