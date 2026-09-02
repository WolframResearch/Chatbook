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
(* ::Subsubsection::Closed:: *)
(*List Input*)
(* A list of queries is interpreted element-wise, splicing a list of interpretations into the surrounding code. *)
VerificationTest[
    as = WolframLanguageToolEvaluate[
        "\[FreeformPrompt][{\"Boston, MA\", \"Chicago, IL\"}]",
        All,
        Method -> "Session"
    ],
    KeyValuePattern @ {
        "Result" -> HoldCompleteForm @ {
            Entity[ "City", { "Boston", "Massachusetts", "UnitedStates" } ],
            Entity[ "City", { "Chicago", "Illinois", "UnitedStates" } ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List@@Tests/WolframLanguageToolEvaluate.wlt:125,1-139,2"
]

VerificationTest[
    StringContainsQ[
        as[ "String" ],
        "[INFO] Interpreted \"Boston, MA\" as: Entity[\"City\", {\"Boston\", \"Massachusetts\", \"UnitedStates\"}]"
    ] && StringContainsQ[
        as[ "String" ],
        "[INFO] Interpreted \"Chicago, IL\" as: Entity[\"City\", {\"Chicago\", \"Illinois\", \"UnitedStates\"}]"
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-InfoMessages@@Tests/WolframLanguageToolEvaluate.wlt:141,1-152,2"
]

(* A single-element list interprets to a list, not a bare interpretation. *)
VerificationTest[
    WolframLanguageToolEvaluate[ "\[FreeformPrompt][{\"Boston, MA\"}]", "Result", Method -> "Session" ],
    HoldCompleteForm @ { Entity[ "City", { "Boston", "Massachusetts", "UnitedStates" } ] },
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-SingleElement@@Tests/WolframLanguageToolEvaluate.wlt:155,1-160,2"
]

(* An empty list has nothing to interpret, so it evaluates to itself. The unquoted-query auto-correct used to
   rewrite it into the query "{}", which reached the right answer only because the interpreter happened to read
   "{}" back as an empty list. *)
VerificationTest[
    as = WolframLanguageToolEvaluate[ "\[FreeformPrompt][{}]", All, Method -> "Session" ],
    KeyValuePattern @ { "Result" -> HoldCompleteForm @ { } },
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-Empty@@Tests/WolframLanguageToolEvaluate.wlt:165,1-170,2"
]

VerificationTest[
    StringFreeQ[ as[ "String" ], "Interpreted" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-Empty-NotInterpreted@@Tests/WolframLanguageToolEvaluate.wlt:172,1-177,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "\[FreeformPrompt][{ }]", "Result", Method -> "Session" ],
    HoldCompleteForm @ { },
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-Empty-Whitespace@@Tests/WolframLanguageToolEvaluate.wlt:179,1-184,2"
]

(* The optional type specifier constrains every element of the list. *)
VerificationTest[
    WolframLanguageToolEvaluate[ "\[FreeformPrompt][{\"France\", \"Germany\"}, Entity]", "Result", Method -> "Session" ],
    HoldCompleteForm @ { Entity[ "Country", "France" ], Entity[ "Country", "Germany" ] },
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-TypeSpecifier@@Tests/WolframLanguageToolEvaluate.wlt:187,1-192,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[
        "EntityValue[\[FreeformPrompt][{\"France\", \"Germany\"}, Entity], \"Population\"]",
        "Result",
        Method -> "Session"
    ],
    HoldCompleteForm @ { _Quantity, _Quantity },
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-InExpression@@Tests/WolframLanguageToolEvaluate.wlt:194,1-203,2"
]

(* An element that cannot be interpreted fails on its own without discarding the others. *)
VerificationTest[
    WolframLanguageToolEvaluate[
        "\[FreeformPrompt][{\"France\", \"three point one four\"}, Entity]",
        "Result",
        Method -> "Session"
    ],
    HoldCompleteForm @ { Entity[ "Country", "France" ], $Failed },
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-PartialFailure@@Tests/WolframLanguageToolEvaluate.wlt:206,1-215,2"
]

(* A list that is not made up entirely of strings is still rejected as invalid arguments. *)
VerificationTest[
    as = WolframLanguageToolEvaluate[ "\[FreeformPrompt][{\"France\", 5}]", All, Method -> "Session" ],
    KeyValuePattern @ { "Result" -> HoldCompleteForm @ $Failed },
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-InvalidElement@@Tests/WolframLanguageToolEvaluate.wlt:218,1-223,2"
]

VerificationTest[
    StringContainsQ[ as[ "String" ], "[ERROR] invalid arguments in" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-InvalidElement-Message@@Tests/WolframLanguageToolEvaluate.wlt:225,1-230,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Multimodal Input*)
VerificationTest[
    WolframLanguageToolEvaluate[ { "ImageDimensions[", RandomImage[ ], "]" }, "Result", Method -> "Session" ],
    HoldCompleteForm @ { _Integer, _Integer },
    SameTest -> MatchQ,
    TestID   -> "MultimodalInput-1@@Tests/WolframLanguageToolEvaluate.wlt:235,1-240,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Auto-Correcting Input*)
VerificationTest[
    WolframLanguageToolEvaluate[ "Dimensions[{{1,2},{3,4},{5,6}}", "Result", Method -> "Session" ],
    HoldCompleteForm @ { 3, 2 },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-1@@Tests/WolframLanguageToolEvaluate.wlt:245,1-250,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ { "ImageDimensions[", RandomImage[ ] }, "Result", Method -> "Session" ],
    HoldCompleteForm @ { _Integer, _Integer },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-2@@Tests/WolframLanguageToolEvaluate.wlt:252,1-257,2"
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
    TestID   -> "EdgeCases-SequenceInput@@Tests/WolframLanguageToolEvaluate.wlt:266,1-274,2"
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
    TestID   -> "EdgeCases-UncaughtThrow@@Tests/WolframLanguageToolEvaluate.wlt:279,1-287,2"
]

VerificationTest[
    StringContainsQ[ as[ "String" ], "Throw::nocatch: Uncaught Throw[Null] returned to top level." ],
    True,
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-UncaughtThrow-Message@@Tests/WolframLanguageToolEvaluate.wlt:289,1-294,2"
]

VerificationTest[
    StringContainsQ[ as[ "String" ], "Out[1]= Hold[Throw[Null]]" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-UncaughtThrow-Output@@Tests/WolframLanguageToolEvaluate.wlt:296,1-301,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Throw[Unevaluated[Throw[Null]], \"tag\"]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> _String,
        "Result" -> HoldCompleteForm @ Hold @ Throw[ Throw @ Null, "tag" ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-UncaughtThrow-Tagged@@Tests/WolframLanguageToolEvaluate.wlt:303,1-311,2"
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
    TestID   -> "EdgeCases-Abort@@Tests/WolframLanguageToolEvaluate.wlt:316,1-324,2"
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
    TestID   -> "EdgeCases-KernelQuit-Exit-Null@@Tests/WolframLanguageToolEvaluate.wlt:329,1-337,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Exit[1]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "General::quit: The kernel quit unexpectedly during evaluation with exit code 1.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-KernelQuit-Exit-1@@Tests/WolframLanguageToolEvaluate.wlt:339,1-347,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Quit[]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "General::quit: The kernel quit unexpectedly during evaluation with exit code 0.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-KernelQuit-Quit-Null@@Tests/WolframLanguageToolEvaluate.wlt:349,1-357,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Quit[1]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "General::quit: The kernel quit unexpectedly during evaluation with exit code 1.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-KernelQuit-Quit-1@@Tests/WolframLanguageToolEvaluate.wlt:359,1-367,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Exit[1]; Print[\"Hello\"]; Quit[2]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "General::quit: The kernel quit unexpectedly during evaluation with exit code 1.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-KernelQuit-Exit-Stop@@Tests/WolframLanguageToolEvaluate.wlt:369,1-377,2"
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
    TestID   -> "MessageFormatting-1@@Tests/WolframLanguageToolEvaluate.wlt:386,1-391,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Message[f::argx, f, Range[1000]]", "String", Method -> "Session" ],
    s_String /; StringLength[ s ] < 500,
    SameTest -> MatchQ,
    TestID   -> "MessageFormatting-2@@Tests/WolframLanguageToolEvaluate.wlt:393,1-398,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*PropagateMessages*)
VerificationTest[
    WolframLanguageToolEvaluate[ "1/0", Method -> "Session", "PropagateMessages" -> True ],
    _String? (StringContainsQ[ "Power::infy: Infinite expression 1/0 encountered." ]),
    { Power::infy },
    SameTest -> MatchQ,
    TestID   -> "PropagateMessages@@Tests/WolframLanguageToolEvaluate.wlt:403,1-409,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Automatic Resolution*)
VerificationTest[
    Block[ { $EvaluationEnvironment = "Session" },
        WolframLanguageToolEvaluate[ "First[]", Method -> "Session","PropagateMessages" -> Automatic ]
    ],
    _String? (StringContainsQ[ "First::argt: First called with 0 arguments" ]),
    { }, (* No messages should be issued externally in a Session by default *)
    SameTest -> MatchQ,
    TestID   -> "PropagateMessages-Session@@Tests/WolframLanguageToolEvaluate.wlt:414,1-422,2"
]

VerificationTest[
    Block[ { $EvaluationEnvironment = "Script" },
        WolframLanguageToolEvaluate[ "First[]", Method -> "Session", "PropagateMessages" -> Automatic ]
    ],
    _String? (StringContainsQ[ "First::argt: First called with 0 arguments" ]),
    { First::argt }, (* Messages should be issued externally in other environments *)
    SameTest -> MatchQ,
    TestID   -> "PropagateMessages-OtherEnvironment@@Tests/WolframLanguageToolEvaluate.wlt:424,1-432,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Print*)
VerificationTest[
    WolframLanguageToolEvaluate[ "Print[\"a\"]; 1+1", "String", Method -> "Session" ],
    _String? (StringMatchQ[ "During evaluation of In["~~NumberString~~"]:= a\n\nOut["~~NumberString~~"]= 2" ]),
    SameTest -> MatchQ,
    TestID   -> "PrintFormatting-1@@Tests/WolframLanguageToolEvaluate.wlt:437,1-442,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*PrintTemporary*)
VerificationTest[
    WolframLanguageToolEvaluate[ "PrintTemporary[\"a\"]; 1+1", "String", Method -> "Session" ],
    _String? (StringMatchQ[ "During evaluation of In["~~NumberString~~"]:= a\n\nOut["~~NumberString~~"]= 2" ]),
    SameTest -> MatchQ,
    TestID   -> "PrintTemporaryFormatting-1@@Tests/WolframLanguageToolEvaluate.wlt:447,1-452,2"
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
    TestID   -> "RegressionTests-OverrideTagForcing@@Tests/WolframLanguageToolEvaluate.wlt:461,1-466,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Using PropagateMessages to prevent collecting suppressed kernel messages*)
VerificationTest[
    WolframLanguageToolEvaluate[
        "FullSimplify[Integrate[a + b Log[c Log[d x^n]^p], x], {d>0, x>0, n!=0}]",
        Method -> "Session",
        "PropagateMessages" -> True
    ],
    _String? (StringFreeQ[ "General::messages" ]),
    SameTest -> MatchQ,
    TestID   -> "PropagateMessages-Workaround@@Tests/WolframLanguageToolEvaluate.wlt:471,1-480,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Auto-Correct Rewriting Valid FreeformPrompt Syntax*)
(* The optional second argument constrains what the query parses to. Auto-correct rules used to treat it as a
   hallucination and strip it, taking the surrounding code with it, leaving something that could not evaluate. *)
VerificationTest[
    WolframLanguageToolEvaluate[
        "QuantityMagnitude[EntityValue[\[FreeformPrompt][\"France\", Entity], \"Population\"]]",
        "Result",
        Method -> "Session"
    ],
    HoldCompleteForm[ _Integer ],
    SameTest -> MatchQ,
    TestID   -> "RegressionTests-FreeformPromptTypeSpecifier@@Tests/WolframLanguageToolEvaluate.wlt:487,1-496,2"
]
