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
    HoldForm[ 2 ],
    SameTest -> MatchQ,
    TestID   -> "ResultProperty@@Tests/WolframLanguageToolEvaluate.wlt:46,1-51,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1", { "Result", "String" }, Method -> "Session" ],
    KeyValuePattern @ { "Result" -> HoldForm[ 2 ], "String" -> _String },
    SameTest -> MatchQ,
    TestID   -> "MultipleProperties@@Tests/WolframLanguageToolEvaluate.wlt:53,1-58,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1", All, Method -> "Session" ],
    KeyValuePattern @ { "Result" -> HoldForm[ 2 ], "String" -> _String },
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
    HoldForm @ { _Integer, _Integer },
    SameTest -> MatchQ,
    TestID   -> "MultimodalInput-1@@Tests/WolframLanguageToolEvaluate.wlt:124,1-129,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Auto-Correcting Input*)
VerificationTest[
    WolframLanguageToolEvaluate[ "Dimensions[{{1,2},{3,4},{5,6}}", "Result", Method -> "Session" ],
    HoldForm @ { 3, 2 },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-1@@Tests/WolframLanguageToolEvaluate.wlt:134,1-139,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ { "ImageDimensions[", RandomImage[ ] }, "Result", Method -> "Session" ],
    HoldForm @ { _Integer, _Integer },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-2@@Tests/WolframLanguageToolEvaluate.wlt:141,1-146,2"
]