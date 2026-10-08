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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Multiple Inputs*)

(* Like an interactive kernel session, each top-level expression is a separate input with its own line number. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Outputs*)
VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1\n2 + 2", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ { "String" -> "Out[1]= 2\n\nOut[2]= 4", "Result" -> HoldCompleteForm[ 4 ] },
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-Outputs@@Tests/WolframLanguageToolEvaluate.wlt:507,1-512,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "multipleInputsX = 1;\nmultipleInputsX + 1", "String", Method -> "Session", Line -> 1 ],
    "Out[2]= 2",
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-Suppressed@@Tests/WolframLanguageToolEvaluate.wlt:514,1-519,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Print[\"a\"]\n1 + 1", "String", Method -> "Session", Line -> 1 ],
    "During evaluation of In[1]:= a\n\nOut[2]= 2",
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-NullResult@@Tests/WolframLanguageToolEvaluate.wlt:521,1-526,2"
]

(* The last output is shown when there would otherwise be no outputs: *)
VerificationTest[
    WolframLanguageToolEvaluate[ "multipleInputsA = 1;\nmultipleInputsB = 2;", "String", Method -> "Session", Line -> 1 ],
    "Out[2]= Null",
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-AllSuppressed@@Tests/WolframLanguageToolEvaluate.wlt:529,1-534,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "(* nothing to evaluate *)", "String", Method -> "Session", Line -> 1 ],
    "Out[1]= Null",
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-OnlyComments@@Tests/WolframLanguageToolEvaluate.wlt:536,1-541,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "5\n% + 1", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ { "String" -> "Out[1]= 5\n\nOut[2]= 6", "Result" -> HoldCompleteForm[ 6 ] },
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-PreviousOutput@@Tests/WolframLanguageToolEvaluate.wlt:543,1-548,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Print[\"a\"]; 1\nPrint[\"b\"]; 2", "String", Method -> "Session", Line -> 1 ],
    "During evaluation of In[1]:= a\n\nOut[1]= 1\n\nDuring evaluation of In[2]:= b\n\nOut[2]= 2",
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-PrintLabels@@Tests/WolframLanguageToolEvaluate.wlt:550,1-555,2"
]

VerificationTest[
    string = WolframLanguageToolEvaluate[ "1/0\n1/0", "String", Method -> "Session", Line -> 1 ],
    _String? (StringStartsQ[ "Power::infy: Infinite expression 1/0 encountered.\nGeneral::messages: " ]),
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-Messages@@Tests/WolframLanguageToolEvaluate.wlt:557,1-562,2"
]

(* The general messages hint is only included once: *)
VerificationTest[
    { StringCount[ string, "Power::infy" ], StringCount[ string, "General::messages" ] },
    { 2, 1 },
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-Messages-GeneralMessage@@Tests/WolframLanguageToolEvaluate.wlt:565,1-570,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ HoldComplete[ 1 + 1; 2 + 2 ], "Result", Method -> "Session" ],
    HoldCompleteForm[ 4 ],
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-HeldInput@@Tests/WolframLanguageToolEvaluate.wlt:572,1-577,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Line Numbers*)

(* The "Line" property gives the line number for the next input, including inputs without outputs: *)
VerificationTest[
    WolframLanguageToolEvaluate[ "1\n2;\n3", "Line", Method -> "Session", Line -> 5 ],
    8,
    SameTest -> MatchQ,
    TestID   -> "LineNumbers-Next@@Tests/WolframLanguageToolEvaluate.wlt:584,1-589,2"
]

VerificationTest[
    line = WolframLanguageToolEvaluate[ "1\n2", "Line", Method -> "Session", Line -> 1 ];
    WolframLanguageToolEvaluate[ "3", "String", Method -> "Session", Line -> line ],
    "Out[3]= 3",
    SameTest -> MatchQ,
    TestID   -> "LineNumbers-Chained@@Tests/WolframLanguageToolEvaluate.wlt:591,1-597,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ { "Line" -> 2 },
    SameTest -> MatchQ,
    TestID   -> "LineNumbers-AllProperties@@Tests/WolframLanguageToolEvaluate.wlt:599,1-604,2"
]

(* Evaluations can change the line number: *)
VerificationTest[
    WolframLanguageToolEvaluate[ HoldComplete[ $Line-- ], "Line", Method -> "Session", Line -> 5 ],
    5,
    SameTest -> MatchQ,
    TestID   -> "LineNumbers-Modified@@Tests/WolframLanguageToolEvaluate.wlt:607,1-612,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Stopping Evaluation*)
VerificationTest[
    as = WolframLanguageToolEvaluate[
        "1 + 1\nPause[5]\n3 + 3",
        All,
        Method           -> "Session",
        Line             -> 1,
        "TimeConstraint" -> 1
    ],
    KeyValuePattern @ {
        "String" -> _String? (StringStartsQ[ "Out[1]= 2\n\nOut[2]= Failure[\"EvaluationTimeExceeded\"" ]),
        "Result" -> HoldCompleteForm @ Failure[ "EvaluationTimeExceeded", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-TimeConstraint@@Tests/WolframLanguageToolEvaluate.wlt:617,1-631,2"
]

VerificationTest[
    StringFreeQ[ as[ "String" ], "Out[3]" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-TimeConstraint-Stopped@@Tests/WolframLanguageToolEvaluate.wlt:633,1-638,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1\nAbort[]\n3 + 3", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ { "String" -> "Out[1]= 2\n\nOut[2]= $Aborted", "Result" -> HoldCompleteForm @ $Aborted },
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-Abort@@Tests/WolframLanguageToolEvaluate.wlt:640,1-645,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1\nQuit[]\n3 + 3", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "Out[1]= 2\n\nGeneral::quit: The kernel quit unexpectedly during evaluation with exit code 0.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-Quit@@Tests/WolframLanguageToolEvaluate.wlt:647,1-655,2"
]

(* An uncaught throw only affects its own input: *)
VerificationTest[
    WolframLanguageToolEvaluate[ "Throw[1]\n2 + 2", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> _String? (StringEndsQ[ "Out[1]= Hold[Throw[1]]\n\nOut[2]= 4" ]),
        "Result" -> HoldCompleteForm[ 4 ]
    },
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-Throw@@Tests/WolframLanguageToolEvaluate.wlt:658,1-666,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Parsing*)

(* Each input is parsed right before it's evaluated, so symbols are created in the context that's current at that
   point, and contexts added to $ContextPath by earlier inputs are used. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Packages*)
VerificationTest[
    WolframLanguageToolEvaluate[
        "\
BeginPackage[\"ChatbookTestPackage1`\"];
TestAddOne::usage = \"TestAddOne[x] adds one to x.\";

TestAddOne[testArg_] :=
    Module[{testLocal},
        testLocal = 1;
        testArg + testLocal
    ]

EndPackage[];

ChatbookTestPackage1`TestAddOne[3]",
        All,
        Method -> "Session",
        Line   -> 1
    ],
    KeyValuePattern @ { "String" -> "Out[5]= 4", "Result" -> HoldCompleteForm[ 4 ] },
    SameTest -> MatchQ,
    TestID   -> "Parsing-Package@@Tests/WolframLanguageToolEvaluate.wlt:678,1-700,2"
]

VerificationTest[
    { Context @ ChatbookTestPackage1`TestAddOne, Names[ "Global`TestAddOne" ] },
    { "ChatbookTestPackage1`", { } },
    SameTest -> MatchQ,
    TestID   -> "Parsing-Package-Context@@Tests/WolframLanguageToolEvaluate.wlt:702,1-707,2"
]

VerificationTest[
    testPackageFile = Export[
        FileNameJoin @ { $TemporaryDirectory, "ChatbookTestPackage2.wl" },
        "\
BeginPackage[\"ChatbookTestPackage2`\"];
TestDouble::usage = \"TestDouble[x] doubles x.\";
Begin[\"`Private`\"];
TestDouble[testArg_] := 2 testArg;
End[];
EndPackage[];
",
        "Text"
    ],
    _String? FileExistsQ,
    SameTest -> MatchQ,
    TestID   -> "Parsing-LoadPackage-CreateFile@@Tests/WolframLanguageToolEvaluate.wlt:709,1-725,2"
]

(* Functions from a package that's loaded by a previous input can be used without their full name: *)
VerificationTest[
    WolframLanguageToolEvaluate[
        "Get[" <> ToString[ testPackageFile, InputForm ] <> "];\nTestDouble[3]",
        All,
        Method -> "Session",
        Line   -> 1
    ],
    KeyValuePattern @ { "String" -> "Out[2]= 6", "Result" -> HoldCompleteForm[ 6 ] },
    SameTest -> MatchQ,
    TestID   -> "Parsing-LoadPackage@@Tests/WolframLanguageToolEvaluate.wlt:728,1-738,2"
]

VerificationTest[
    Names[ "Global`TestDouble" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Parsing-LoadPackage-NoGlobalSymbol@@Tests/WolframLanguageToolEvaluate.wlt:740,1-745,2"
]

VerificationTest[
    DeleteFile @ testPackageFile,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Parsing-LoadPackage-Cleanup@@Tests/WolframLanguageToolEvaluate.wlt:747,1-752,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Natural Language Input*)
VerificationTest[
    as = WolframLanguageToolEvaluate[
        "\[FreeformPrompt][\"France\", Entity]\n\[FreeformPrompt][\"Germany\", Entity]",
        All,
        Method -> "Session",
        Line   -> 1
    ],
    KeyValuePattern @ { "Result" -> HoldCompleteForm @ Entity[ "Country", "Germany" ] },
    SameTest -> MatchQ,
    TestID   -> "Parsing-NaturalLanguageInput@@Tests/WolframLanguageToolEvaluate.wlt:757,1-767,2"
]

VerificationTest[
    StringMatchQ[
        as[ "String" ],
        StringExpression[
            "During evaluation of In[1]:= [INFO] Interpreted \"France\" as: Entity[\"Country\", \"France\"]\n\n",
            "Out[1]= Entity[\"Country\", \"France\"]\n\n",
            "During evaluation of In[2]:= [INFO] Interpreted \"Germany\" as: Entity[\"Country\", \"Germany\"]\n\n",
            "Out[2]= Entity[\"Country\", \"Germany\"]"
        ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Parsing-NaturalLanguageInput-String@@Tests/WolframLanguageToolEvaluate.wlt:769,1-782,2"
]

(* Interpretations are inserted without being evaluated: *)
VerificationTest[
    WolframLanguageToolEvaluate[ "Hold[\[FreeformPrompt][\"France\", Entity]]", "Result", Method -> "Session" ],
    HoldCompleteForm @ Hold @ Entity[ "Country", "France" ],
    SameTest -> MatchQ,
    TestID   -> "Parsing-NaturalLanguageInput-Held@@Tests/WolframLanguageToolEvaluate.wlt:785,1-790,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ { "ImageDimensions[", RandomImage[ ], "]\n1 + 1" }, All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ { "String" -> "Out[1]= {150, 150}\n\nOut[2]= 2", "Result" -> HoldCompleteForm[ 2 ] },
    SameTest -> MatchQ,
    TestID   -> "Parsing-MultimodalInput@@Tests/WolframLanguageToolEvaluate.wlt:792,1-797,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Undefined Symbols*)
VerificationTest[
    WolframLanguageToolEvaluate[ "UndefinedTestFunction1[1]", "String", Method -> "Session", Line -> 1 ],
    _String? (StringStartsQ[ "Symbol::undefined: Warning: Global symbol UndefinedTestFunction1 is undefined." ]),
    SameTest -> MatchQ,
    TestID   -> "Parsing-UndefinedSymbols@@Tests/WolframLanguageToolEvaluate.wlt:802,1-807,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[
        "UndefinedTestFunction2[1] + UndefinedTestFunction2[2] + UndefinedTestFunction3[3]",
        "String",
        Method -> "Session",
        Line   -> 1
    ],
    _String? (StringContainsQ[ "Global symbols {UndefinedTestFunction2, UndefinedTestFunction3} are undefined." ]),
    SameTest -> MatchQ,
    TestID   -> "Parsing-UndefinedSymbols-NoDuplicates@@Tests/WolframLanguageToolEvaluate.wlt:809,1-819,2"
]

(* Symbols that are defined in the same input are not undefined: *)
VerificationTest[
    WolframLanguageToolEvaluate[ "DefinedTestFunction1[x_] := x + 1; DefinedTestFunction1[1]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ { "String" -> "Out[1]= 2", "Result" -> HoldCompleteForm[ 2 ] },
    SameTest -> MatchQ,
    TestID   -> "Parsing-UndefinedSymbols-DefinedInInput@@Tests/WolframLanguageToolEvaluate.wlt:822,1-827,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Module[{LocalTestSymbol = 1}, LocalTestSymbol + 1]", "String", Method -> "Session", Line -> 1 ],
    "Out[1]= 2",
    SameTest -> MatchQ,
    TestID   -> "Parsing-UndefinedSymbols-Localized@@Tests/WolframLanguageToolEvaluate.wlt:829,1-834,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Auto-Correcting Input*)

(* Missing closers are added at the end of the line when adding them at the end of the input would join lines: *)
VerificationTest[
    WolframLanguageToolEvaluate[ "autoCorrectList = {1, 2, 3\nTotal[autoCorrectList]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ { "String" -> "Out[1]= {1, 2, 3}\n\nOut[2]= 6", "Result" -> HoldCompleteForm[ 6 ] },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-ClosersEndOfLine@@Tests/WolframLanguageToolEvaluate.wlt:841,1-846,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Total[{1, 2, 3", "Result", Method -> "Session" ],
    HoldCompleteForm[ 6 ],
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-MissingClosers@@Tests/WolframLanguageToolEvaluate.wlt:848,1-853,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Total[{1, 2, 3]", "Result", Method -> "Session" ],
    HoldCompleteForm[ 6 ],
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-MismatchedBrackets@@Tests/WolframLanguageToolEvaluate.wlt:855,1-860,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "StringLength['hello'", "Result", Method -> "Session" ],
    HoldCompleteForm[ 5 ],
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-SingleQuotes@@Tests/WolframLanguageToolEvaluate.wlt:862,1-867,2"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "// add the numbers\n1 + 1", "Result", Method -> "Session" ],
    HoldCompleteForm[ 2 ],
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-LineComments@@Tests/WolframLanguageToolEvaluate.wlt:869,1-874,2"
]

(* Input with a syntax error that can't be fixed is not partially evaluated: *)
VerificationTest[
    as = WolframLanguageToolEvaluate[ "1 + 1\n2 + ", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> _String? (StringStartsQ[ "ToExpression::sntxi:" ]),
        "Result" -> HoldCompleteForm @ $Failed
    },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-SyntaxError@@Tests/WolframLanguageToolEvaluate.wlt:877,1-885,2"
]

VerificationTest[
    StringEndsQ[ as[ "String" ], "\n\nOut[1]= $Failed" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-SyntaxError-NotEvaluated@@Tests/WolframLanguageToolEvaluate.wlt:887,1-892,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Local Evaluator*)

(* These tests launch a separate sandbox kernel, which isn't possible in every test environment: *)
VerificationTest[
    $localEvaluatorAvailable = MatchQ[
        Quiet @ WolframLanguageToolEvaluate[ "1 + 1", "Result", Method -> "Local" ],
        HoldCompleteForm[ 2 ]
    ],
    True|False,
    SameTest -> MatchQ,
    TestID   -> "LocalEvaluator-Available@@Tests/WolframLanguageToolEvaluate.wlt:899,1-907,2"
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "1 + 1\n2 + 2", "String", Method -> "Local" ],
        _String? (StringMatchQ[ "Out[" ~~ DigitCharacter.. ~~ "]= 2\n\nOut[" ~~ DigitCharacter.. ~~ "]= 4" ]),
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-MultipleInputs@@Tests/WolframLanguageToolEvaluate.wlt:910,5-915,6"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "Print[\"a\"]; 1/0", "String", Method -> "Local" ],
        _String? (StringStartsQ[
            "During evaluation of In[" ~~ DigitCharacter.. ~~ "]:= a\n" ~~
            "Power::infy: Infinite expression 1/0 encountered.\n" ~~
            "General::messages: "
        ]),
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-PrintsAndMessages@@Tests/WolframLanguageToolEvaluate.wlt:919,5-928,6"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "5\n% + 1", "Result", Method -> "Local" ],
        HoldCompleteForm[ 6 ],
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-PreviousOutput@@Tests/WolframLanguageToolEvaluate.wlt:932,5-937,6"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "localHistoryTest = 1\nInString[$Line - 1]", "Result", Method -> "Local" ],
        HoldCompleteForm[ "localHistoryTest = 1" ],
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-InputHistory@@Tests/WolframLanguageToolEvaluate.wlt:941,5-946,6"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[
            "\
BeginPackage[\"ChatbookTestPackage3`\"];
TestAddTwo[testArg_] := testArg + 2;
EndPackage[];
TestAddTwo[3]",
            "Result",
            Method -> "Local"
        ],
        HoldCompleteForm[ 5 ],
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-Package@@Tests/WolframLanguageToolEvaluate.wlt:950,5-963,6"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        as = WolframLanguageToolEvaluate[ "1\n2", { "String", "Line" }, Method -> "Local" ],
        KeyValuePattern @ { "Line" -> _Integer },
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers@@Tests/WolframLanguageToolEvaluate.wlt:967,5-972,6"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        StringEndsQ[ as[ "String" ], "Out[" <> ToString[ as[ "Line" ] - 1 ] <> "]= 2" ],
        True,
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers-LastOutput@@Tests/WolframLanguageToolEvaluate.wlt:976,5-981,6"
    ]
]

(* Evaluations can change the line number: *)
If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ HoldComplete @ WithCleanup[ Null, $Line-- ], "Line", Method -> "Local" ],
        as[ "Line" ],
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers-Modified@@Tests/WolframLanguageToolEvaluate.wlt:986,5-991,6"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "3", "String", Method -> "Local" ],
        "Out[" <> ToString @ as[ "Line" ] <> "]= 3",
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers-NextOutput@@Tests/WolframLanguageToolEvaluate.wlt:995,5-1000,6"
    ]
]

(* An explicitly given line number is used by the evaluator kernel: *)
If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "1\n2", { "String", "Line" }, Method -> "Local", Line -> 50 ],
        <| "String" -> "Out[50]= 1\n\nOut[51]= 2", "Line" -> 52 |>,
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers-Option@@Tests/WolframLanguageToolEvaluate.wlt:1005,5-1010,6"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "3", "String", Method -> "Local" ],
        "Out[52]= 3",
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers-Option-Continued@@Tests/WolframLanguageToolEvaluate.wlt:1014,5-1019,6"
    ]
]

(* Code is parsed using the evaluator kernel's context state rather than this kernel's (AgentTools#249): *)
If[ $localEvaluatorAvailable,
    VerificationTest[
        contextState = WolframLanguageToolEvaluate[
            HoldComplete @ WithCleanup[
                { $Context, $ContextPath },
                $Context = "ChatbookTestSession`";
                $ContextPath = { "ChatbookTestSession`", "System`" };
                $Line--
            ],
            "Result",
            Method -> "Local"
        ],
        HoldCompleteForm @ { _String, { __String } },
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-Context-Set-GH#249@@Tests/WolframLanguageToolEvaluate.wlt:1024,5-1038,6"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "sessionTestSymbol = 1;\nContext[sessionTestSymbol]", "Result", Method -> "Local" ],
        HoldCompleteForm[ "ChatbookTestSession`" ],
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-Context-GH#249@@Tests/WolframLanguageToolEvaluate.wlt:1042,5-1047,6"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        Names[ "Global`sessionTestSymbol" ],
        { },
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-Context-NoLocalSymbol-GH#249@@Tests/WolframLanguageToolEvaluate.wlt:1051,5-1056,6"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        Replace[
            contextState,
            HoldCompleteForm[ { context_, path_ } ] :> WolframLanguageToolEvaluate[
                HoldComplete @ WithCleanup[ $Context = context; $ContextPath = path, $Line-- ],
                "Result",
                Method -> "Local"
            ]
        ],
        HoldCompleteForm[ { __String } ],
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-Context-Restore-GH#249@@Tests/WolframLanguageToolEvaluate.wlt:1060,5-1072,6"
    ]
]
