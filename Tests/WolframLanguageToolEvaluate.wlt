(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

VerificationTest[
    Context @ WolframLanguageToolEvaluate,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "WolframLanguageToolEvaluateContext"
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
    TestID   -> "BasicEvaluation"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1", "String", Method -> "Session" ],
    _String? (StringMatchQ[ "Out["~~DigitCharacter..~~"]= 2"]),
    SameTest -> MatchQ,
    TestID   -> "StringProperty"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1", "Result", Method -> "Session" ],
    HoldCompleteForm[ 2 ],
    SameTest -> MatchQ,
    TestID   -> "ResultProperty"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1", { "Result", "String" }, Method -> "Session" ],
    KeyValuePattern @ { "Result" -> HoldCompleteForm[ 2 ], "String" -> _String },
    SameTest -> MatchQ,
    TestID   -> "MultipleProperties"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1", All, Method -> "Session" ],
    KeyValuePattern @ { "Result" -> HoldCompleteForm[ 2 ], "String" -> _String },
    SameTest -> MatchQ,
    TestID   -> "AllProperties"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Natural Language Input*)
VerificationTest[
    string = WolframLanguageToolEvaluate[ "\[FreeformPrompt][\"Boston, MA\"]", Method -> "Session" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-1"
]

VerificationTest[
    StringContainsQ[
        string,
        "[INFO] Interpreted \"Boston, MA\" as: Entity[\"City\", {\"Boston\", \"Massachusetts\", \"UnitedStates\"}]"
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-1-InfoMessage"
]

VerificationTest[
    StringEndsQ[
        string,
        "Out[" ~~ DigitCharacter.. ~~ "]= Entity[\"City\", {\"Boston\", \"Massachusetts\", \"UnitedStates\"}]"
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-1-Output"
]

VerificationTest[
    string = WolframLanguageToolEvaluate[ "\[FreeformPrompt][\"Springfield\"]", Method -> "Session" ],
    _String,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-2"
]

VerificationTest[
    StringContainsQ[
        string,
        "[WARNING] Interpreted \"Springfield\" as " ~~ __ ~~ " with other possible interpretations:"
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-2-WarningMessage"
]

VerificationTest[
    StringContainsQ[ string, "Entity[\"City\", {\"Springfield\", \"Illinois\", \"UnitedStates\"}]" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-2-Result"
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
    TestID   -> "NaturalLanguageInput-List"
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
    TestID   -> "NaturalLanguageInput-List-InfoMessages"
]

(* A single-element list interprets to a list, not a bare interpretation. *)
VerificationTest[
    WolframLanguageToolEvaluate[ "\[FreeformPrompt][{\"Boston, MA\"}]", "Result", Method -> "Session" ],
    HoldCompleteForm @ { Entity[ "City", { "Boston", "Massachusetts", "UnitedStates" } ] },
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-SingleElement"
]

(* An empty list has nothing to interpret, so it evaluates to itself. The unquoted-query auto-correct used to
   rewrite it into the query "{}", which reached the right answer only because the interpreter happened to read
   "{}" back as an empty list. *)
VerificationTest[
    as = WolframLanguageToolEvaluate[ "\[FreeformPrompt][{}]", All, Method -> "Session" ],
    KeyValuePattern @ { "Result" -> HoldCompleteForm @ { } },
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-Empty"
]

VerificationTest[
    StringFreeQ[ as[ "String" ], "Interpreted" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-Empty-NotInterpreted"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "\[FreeformPrompt][{ }]", "Result", Method -> "Session" ],
    HoldCompleteForm @ { },
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-Empty-Whitespace"
]

(* The optional type specifier constrains every element of the list. *)
VerificationTest[
    WolframLanguageToolEvaluate[ "\[FreeformPrompt][{\"France\", \"Germany\"}, Entity]", "Result", Method -> "Session" ],
    HoldCompleteForm @ { Entity[ "Country", "France" ], Entity[ "Country", "Germany" ] },
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-TypeSpecifier"
]

VerificationTest[
    WolframLanguageToolEvaluate[
        "EntityValue[\[FreeformPrompt][{\"France\", \"Germany\"}, Entity], \"Population\"]",
        "Result",
        Method -> "Session"
    ],
    HoldCompleteForm @ { _Quantity, _Quantity },
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-InExpression"
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
    TestID   -> "NaturalLanguageInput-List-PartialFailure"
]

(* A list that is not made up entirely of strings is still rejected as invalid arguments. *)
VerificationTest[
    as = WolframLanguageToolEvaluate[ "\[FreeformPrompt][{\"France\", 5}]", All, Method -> "Session" ],
    KeyValuePattern @ { "Result" -> HoldCompleteForm @ $Failed },
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-InvalidElement"
]

VerificationTest[
    StringContainsQ[ as[ "String" ], "[ERROR] invalid arguments in" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "NaturalLanguageInput-List-InvalidElement-Message"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Multimodal Input*)
VerificationTest[
    WolframLanguageToolEvaluate[ { "ImageDimensions[", RandomImage[ ], "]" }, "Result", Method -> "Session" ],
    HoldCompleteForm @ { _Integer, _Integer },
    SameTest -> MatchQ,
    TestID   -> "MultimodalInput-1"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Auto-Correcting Input*)
VerificationTest[
    WolframLanguageToolEvaluate[ "Dimensions[{{1,2},{3,4},{5,6}}", "Result", Method -> "Session" ],
    HoldCompleteForm @ { 3, 2 },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-1"
]

VerificationTest[
    WolframLanguageToolEvaluate[ { "ImageDimensions[", RandomImage[ ] }, "Result", Method -> "Session" ],
    HoldCompleteForm @ { _Integer, _Integer },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-2"
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
    TestID   -> "EdgeCases-SequenceInput"
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
    TestID   -> "EdgeCases-UncaughtThrow"
]

VerificationTest[
    StringContainsQ[ as[ "String" ], "Throw::nocatch: Uncaught Throw[Null] returned to top level." ],
    True,
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-UncaughtThrow-Message"
]

VerificationTest[
    StringContainsQ[ as[ "String" ], "Out[1]= Hold[Throw[Null]]" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-UncaughtThrow-Output"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Throw[Unevaluated[Throw[Null]], \"tag\"]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> _String,
        "Result" -> HoldCompleteForm @ Hold @ Throw[ Throw @ Null, "tag" ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-UncaughtThrow-Tagged"
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
    TestID   -> "EdgeCases-Abort"
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
    TestID   -> "EdgeCases-KernelQuit-Exit-Null"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Exit[1]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "General::quit: The kernel quit unexpectedly during evaluation with exit code 1.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-KernelQuit-Exit-1"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Quit[]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "General::quit: The kernel quit unexpectedly during evaluation with exit code 0.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-KernelQuit-Quit-Null"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Quit[1]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "General::quit: The kernel quit unexpectedly during evaluation with exit code 1.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-KernelQuit-Quit-1"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Exit[1]; Print[\"Hello\"]; Quit[2]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "General::quit: The kernel quit unexpectedly during evaluation with exit code 1.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "EdgeCases-KernelQuit-Exit-Stop"
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
    TestID   -> "MessageFormatting-1"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Message[f::argx, f, Range[1000]]", "String", Method -> "Session" ],
    s_String /; StringLength[ s ] < 500,
    SameTest -> MatchQ,
    TestID   -> "MessageFormatting-2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*PropagateMessages*)
VerificationTest[
    WolframLanguageToolEvaluate[ "1/0", Method -> "Session", "PropagateMessages" -> True ],
    _String? (StringContainsQ[ "Power::infy: Infinite expression 1/0 encountered." ]),
    { Power::infy },
    SameTest -> MatchQ,
    TestID   -> "PropagateMessages"
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
    TestID   -> "PropagateMessages-Session"
]

VerificationTest[
    Block[ { $EvaluationEnvironment = "Script" },
        WolframLanguageToolEvaluate[ "First[]", Method -> "Session", "PropagateMessages" -> Automatic ]
    ],
    _String? (StringContainsQ[ "First::argt: First called with 0 arguments" ]),
    { First::argt }, (* Messages should be issued externally in other environments *)
    SameTest -> MatchQ,
    TestID   -> "PropagateMessages-OtherEnvironment"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Print*)
VerificationTest[
    WolframLanguageToolEvaluate[ "Print[\"a\"]; 1+1", "String", Method -> "Session" ],
    _String? (StringMatchQ[ "During evaluation of In["~~NumberString~~"]:= a\n\nOut["~~NumberString~~"]= 2" ]),
    SameTest -> MatchQ,
    TestID   -> "PrintFormatting-1"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*PrintTemporary*)
VerificationTest[
    WolframLanguageToolEvaluate[ "PrintTemporary[\"a\"]; 1+1", "String", Method -> "Session" ],
    _String? (StringMatchQ[ "During evaluation of In["~~NumberString~~"]:= a\n\nOut["~~NumberString~~"]= 2" ]),
    SameTest -> MatchQ,
    TestID   -> "PrintTemporaryFormatting-1"
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
    TestID   -> "RegressionTests-OverrideTagForcing"
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
    TestID   -> "PropagateMessages-Workaround"
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
    TestID   -> "RegressionTests-FreeformPromptTypeSpecifier"
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
    TestID   -> "MultipleInputs-Outputs"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "multipleInputsX = 1;\nmultipleInputsX + 1", "String", Method -> "Session", Line -> 1 ],
    "Out[2]= 2",
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-Suppressed"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Print[\"a\"]\n1 + 1", "String", Method -> "Session", Line -> 1 ],
    "During evaluation of In[1]:= a\n\nOut[2]= 2",
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-NullResult"
]

(* The last output is shown when there would otherwise be no outputs: *)
VerificationTest[
    WolframLanguageToolEvaluate[ "multipleInputsA = 1;\nmultipleInputsB = 2;", "String", Method -> "Session", Line -> 1 ],
    "Out[2]= Null",
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-AllSuppressed"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "(* nothing to evaluate *)", "String", Method -> "Session", Line -> 1 ],
    "Out[1]= Null",
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-OnlyComments"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "5\n% + 1", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ { "String" -> "Out[1]= 5\n\nOut[2]= 6", "Result" -> HoldCompleteForm[ 6 ] },
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-PreviousOutput"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Print[\"a\"]; 1\nPrint[\"b\"]; 2", "String", Method -> "Session", Line -> 1 ],
    "During evaluation of In[1]:= a\n\nOut[1]= 1\n\nDuring evaluation of In[2]:= b\n\nOut[2]= 2",
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-PrintLabels"
]

VerificationTest[
    string = WolframLanguageToolEvaluate[ "1/0\n1/0", "String", Method -> "Session", Line -> 1 ],
    _String? (StringStartsQ[ "Power::infy: Infinite expression 1/0 encountered.\nGeneral::messages: " ]),
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-Messages"
]

(* The general messages hint is only included once: *)
VerificationTest[
    { StringCount[ string, "Power::infy" ], StringCount[ string, "General::messages" ] },
    { 2, 1 },
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-Messages-GeneralMessage"
]

VerificationTest[
    WolframLanguageToolEvaluate[ HoldComplete[ 1 + 1; 2 + 2 ], "Result", Method -> "Session" ],
    HoldCompleteForm[ 4 ],
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-HeldInput"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Line Numbers*)

(* The "Line" property gives the line number for the next input, including inputs without outputs: *)
VerificationTest[
    WolframLanguageToolEvaluate[ "1\n2;\n3", "Line", Method -> "Session", Line -> 5 ],
    8,
    SameTest -> MatchQ,
    TestID   -> "LineNumbers-Next"
]

VerificationTest[
    line = WolframLanguageToolEvaluate[ "1\n2", "Line", Method -> "Session", Line -> 1 ];
    WolframLanguageToolEvaluate[ "3", "String", Method -> "Session", Line -> line ],
    "Out[3]= 3",
    SameTest -> MatchQ,
    TestID   -> "LineNumbers-Chained"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ { "Line" -> 2 },
    SameTest -> MatchQ,
    TestID   -> "LineNumbers-AllProperties"
]

(* Evaluations can change the line number: *)
VerificationTest[
    WolframLanguageToolEvaluate[ HoldComplete[ $Line-- ], "Line", Method -> "Session", Line -> 5 ],
    5,
    SameTest -> MatchQ,
    TestID   -> "LineNumbers-Modified"
]

(* Held input records its output like any other input: *)
VerificationTest[
    WolframLanguageToolEvaluate[ HoldComplete[ 5 ], "String", Method -> "Session", Line -> 1 ];
    WolframLanguageToolEvaluate[ "% + 1", "Result", Method -> "Session", Line -> 2 ],
    HoldCompleteForm[ 6 ],
    SameTest -> MatchQ,
    TestID   -> "LineNumbers-HeldInput"
]

(* With "Line" -> None, an evaluation does not use a line number or record history: *)
VerificationTest[
    WolframLanguageToolEvaluate[
        HoldComplete[ Print[ "a" ]; 1 + 1 ],
        { "String", "Line" },
        Method -> "Session",
        Line   -> None
    ],
    <| "String" -> "a\n\n2", "Line" -> _Integer |>,
    SameTest -> MatchQ,
    TestID   -> "LineNumbers-None"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "7", "String", Method -> "Session", Line -> 10 ];
    WolframLanguageToolEvaluate[ HoldComplete[ 8 ], "Result", Method -> "Session", Line -> None ];
    WolframLanguageToolEvaluate[ "%", "Result", Method -> "Session", Line -> 11 ],
    HoldCompleteForm[ 7 ],
    SameTest -> MatchQ,
    TestID   -> "LineNumbers-None-NoHistory"
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
    TestID   -> "MultipleInputs-TimeConstraint"
]

VerificationTest[
    StringFreeQ[ as[ "String" ], "Out[3]" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-TimeConstraint-Stopped"
]

VerificationTest[
    as = WolframLanguageToolEvaluate[
        "1 + 1\nLength @ Range[10^6]\n3 + 3",
        All,
        Method             -> "Session",
        Line               -> 1,
        "MemoryConstraint" -> 10^6
    ],
    KeyValuePattern @ {
        "String" -> _String? (StringStartsQ[ "Out[1]= 2\n\nOut[2]= Failure[\"MemoryConstraintExceeded\"" ]),
        "Result" -> HoldCompleteForm @ Failure[
            "MemoryConstraintExceeded",
            KeyValuePattern[ "MessageParameters" -> { 1000000 } ]
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-MemoryConstraint"
]

VerificationTest[
    StringFreeQ[ as[ "String" ], "Out[3]" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-MemoryConstraint-Stopped"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Length @ Range[10^6]", "Result", Method -> "Session", MemoryConstraint -> 10^6 ],
    HoldCompleteForm @ Failure[ "MemoryConstraintExceeded", _ ],
    SameTest -> MatchQ,
    TestID   -> "MemoryConstraint-SystemSymbol"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Length @ Range[10^6]", "Result", Method -> "Session", "MemoryConstraint" -> # ] & /@
        { Automatic, Infinity, 10^8 },
    { HoldCompleteForm[ 1000000 ], HoldCompleteForm[ 1000000 ], HoldCompleteForm[ 1000000 ] },
    SameTest -> MatchQ,
    TestID   -> "MemoryConstraint-NotExceeded"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1", Method -> "Session", "MemoryConstraint" -> -1 ],
    Failure[ "WolframLanguageToolEvaluate::InvalidOptionValue", _ ],
    { WolframLanguageToolEvaluate::InvalidOptionValue },
    SameTest -> MatchQ,
    TestID   -> "MemoryConstraint-InvalidValue"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1\nAbort[]\n3 + 3", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ { "String" -> "Out[1]= 2\n\nOut[2]= $Aborted", "Result" -> HoldCompleteForm @ $Aborted },
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-Abort"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "1 + 1\nQuit[]\n3 + 3", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> "Out[1]= 2\n\nGeneral::quit: The kernel quit unexpectedly during evaluation with exit code 0.",
        "Result" -> Failure[ "KernelQuit", _ ]
    },
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-Quit"
]

(* An uncaught throw only affects its own input: *)
VerificationTest[
    WolframLanguageToolEvaluate[ "Throw[1]\n2 + 2", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> _String? (StringEndsQ[ "Out[1]= Hold[Throw[1]]\n\nOut[2]= 4" ]),
        "Result" -> HoldCompleteForm[ 4 ]
    },
    SameTest -> MatchQ,
    TestID   -> "MultipleInputs-Throw"
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
    TestID   -> "Parsing-Package"
]

VerificationTest[
    { Context @ ChatbookTestPackage1`TestAddOne, Names[ "Global`TestAddOne" ] },
    { "ChatbookTestPackage1`", { } },
    SameTest -> MatchQ,
    TestID   -> "Parsing-Package-Context"
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
    TestID   -> "Parsing-LoadPackage-CreateFile"
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
    TestID   -> "Parsing-LoadPackage"
]

VerificationTest[
    Names[ "Global`TestDouble" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Parsing-LoadPackage-NoGlobalSymbol"
]

VerificationTest[
    DeleteFile @ testPackageFile,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Parsing-LoadPackage-Cleanup"
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
    TestID   -> "Parsing-NaturalLanguageInput"
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
    TestID   -> "Parsing-NaturalLanguageInput-String"
]

(* Interpretations are inserted without being evaluated: *)
VerificationTest[
    WolframLanguageToolEvaluate[ "Hold[\[FreeformPrompt][\"France\", Entity]]", "Result", Method -> "Session" ],
    HoldCompleteForm @ Hold @ Entity[ "Country", "France" ],
    SameTest -> MatchQ,
    TestID   -> "Parsing-NaturalLanguageInput-Held"
]

VerificationTest[
    WolframLanguageToolEvaluate[ { "ImageDimensions[", RandomImage[ ], "]\n1 + 1" }, All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ { "String" -> "Out[1]= {150, 150}\n\nOut[2]= 2", "Result" -> HoldCompleteForm[ 2 ] },
    SameTest -> MatchQ,
    TestID   -> "Parsing-MultimodalInput"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Undefined Symbols*)
VerificationTest[
    WolframLanguageToolEvaluate[ "UndefinedTestFunction1[1]", "String", Method -> "Session", Line -> 1 ],
    _String? (StringStartsQ[ "Symbol::undefined: Warning: Global symbol UndefinedTestFunction1 is undefined." ]),
    SameTest -> MatchQ,
    TestID   -> "Parsing-UndefinedSymbols"
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
    TestID   -> "Parsing-UndefinedSymbols-NoDuplicates"
]

(* Symbols that are defined in the same input are not undefined: *)
VerificationTest[
    WolframLanguageToolEvaluate[ "DefinedTestFunction1[x_] := x + 1; DefinedTestFunction1[1]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ { "String" -> "Out[1]= 2", "Result" -> HoldCompleteForm[ 2 ] },
    SameTest -> MatchQ,
    TestID   -> "Parsing-UndefinedSymbols-DefinedInInput"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Module[{LocalTestSymbol = 1}, LocalTestSymbol + 1]", "String", Method -> "Session", Line -> 1 ],
    "Out[1]= 2",
    SameTest -> MatchQ,
    TestID   -> "Parsing-UndefinedSymbols-Localized"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Auto-Correcting Input*)

(* Missing closers are added at the end of the line when adding them at the end of the input would join lines: *)
VerificationTest[
    WolframLanguageToolEvaluate[ "autoCorrectList = {1, 2, 3\nTotal[autoCorrectList]", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ { "String" -> "Out[1]= {1, 2, 3}\n\nOut[2]= 6", "Result" -> HoldCompleteForm[ 6 ] },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-ClosersEndOfLine"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Total[{1, 2, 3", "Result", Method -> "Session" ],
    HoldCompleteForm[ 6 ],
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-MissingClosers"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "Total[{1, 2, 3]", "Result", Method -> "Session" ],
    HoldCompleteForm[ 6 ],
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-MismatchedBrackets"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "StringLength['hello'", "Result", Method -> "Session" ],
    HoldCompleteForm[ 5 ],
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-SingleQuotes"
]

VerificationTest[
    WolframLanguageToolEvaluate[ "// add the numbers\n1 + 1", "Result", Method -> "Session" ],
    HoldCompleteForm[ 2 ],
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-LineComments"
]

(* Input with a syntax error that can't be fixed is not partially evaluated: *)
VerificationTest[
    as = WolframLanguageToolEvaluate[ "1 + 1\n2 + ", All, Method -> "Session", Line -> 1 ],
    KeyValuePattern @ {
        "String" -> _String? (StringStartsQ[ "ToExpression::sntxi:" ]),
        "Result" -> HoldCompleteForm @ $Failed
    },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-SyntaxError"
]

VerificationTest[
    StringEndsQ[ as[ "String" ], "\n\nOut[1]= $Failed" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "AutoCorrectingInput-SyntaxError-NotEvaluated"
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
    TestID   -> "LocalEvaluator-Available"
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "1 + 1\n2 + 2", "String", Method -> "Local" ],
        _String? (StringMatchQ[ "Out[" ~~ DigitCharacter.. ~~ "]= 2\n\nOut[" ~~ DigitCharacter.. ~~ "]= 4" ]),
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-MultipleInputs"
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
        TestID   -> "LocalEvaluator-PrintsAndMessages"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "5\n% + 1", "Result", Method -> "Local" ],
        HoldCompleteForm[ 6 ],
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-PreviousOutput"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "Length @ Range[10^6]", "Result", Method -> "Local", "MemoryConstraint" -> 10^6 ],
        HoldCompleteForm @ Failure[ "MemoryConstraintExceeded", _ ],
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-MemoryConstraint"
    ]
]

(* The evaluator kernel is still usable after exceeding the memory constraint: *)
If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "Length @ Range[10^6]", "Result", Method -> "Local" ],
        HoldCompleteForm[ 1000000 ],
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-MemoryConstraint-Recovered"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "localHistoryTest = 1\nInString[$Line - 1]", "Result", Method -> "Local" ],
        HoldCompleteForm[ "localHistoryTest = 1" ],
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-InputHistory"
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
        TestID   -> "LocalEvaluator-Package"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        as = WolframLanguageToolEvaluate[ "1\n2", { "String", "Line" }, Method -> "Local" ],
        KeyValuePattern @ { "Line" -> _Integer },
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        StringEndsQ[ as[ "String" ], "Out[" <> ToString[ as[ "Line" ] - 1 ] <> "]= 2" ],
        True,
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers-LastOutput"
    ]
]

(* Evaluations can change the line number: *)
If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ HoldComplete @ WithCleanup[ Null, $Line-- ], "Line", Method -> "Local" ],
        as[ "Line" ],
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers-Modified"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "3", "String", Method -> "Local" ],
        "Out[" <> ToString @ as[ "Line" ] <> "]= 3",
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers-NextOutput"
    ]
]

(* An explicitly given line number is used by the evaluator kernel: *)
If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "1\n2", { "String", "Line" }, Method -> "Local", Line -> 50 ],
        <| "String" -> "Out[50]= 1\n\nOut[51]= 2", "Line" -> 52 |>,
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers-Option"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "3", "String", Method -> "Local" ],
        "Out[52]= 3",
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers-Option-Continued"
    ]
]

(* Held input records its output like any other input: *)
If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ HoldComplete[ 9 ], "Result", Method -> "Local" ];
        WolframLanguageToolEvaluate[ "% + 1", "Result", Method -> "Local" ],
        HoldCompleteForm[ 10 ],
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-HeldInput"
    ]
]

(* With "Line" -> None, an evaluation does not use a line number or record history: *)
If[ $localEvaluatorAvailable,
    VerificationTest[
        line = WolframLanguageToolEvaluate[ "7", "Line", Method -> "Local" ],
        _Integer,
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers-None-Setup"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ HoldComplete[ 8 ], { "String", "Line" }, Method -> "Local", Line -> None ],
        <| "String" -> "8", "Line" -> line |>,
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers-None"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "%", "String", Method -> "Local" ],
        "Out[" <> ToString @ line <> "]= 7",
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-LineNumbers-None-NoHistory"
    ]
]

(* Code is parsed using the evaluator kernel's context state rather than this kernel's (AgentTools#249): *)
If[ $localEvaluatorAvailable,
    VerificationTest[
        contextState = WolframLanguageToolEvaluate[
            HoldComplete @ WithCleanup[
                { $Context, $ContextPath },
                $Context = "ChatbookTestSession`";
                $ContextPath = { "ChatbookTestSession`", "System`" }
            ],
            "Result",
            Method -> "Local",
            Line   -> None
        ],
        HoldCompleteForm @ { _String, { __String } },
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-Context-Set-GH#249"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        WolframLanguageToolEvaluate[ "sessionTestSymbol = 1;\nContext[sessionTestSymbol]", "Result", Method -> "Local" ],
        HoldCompleteForm[ "ChatbookTestSession`" ],
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-Context-GH#249"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        Names[ "Global`sessionTestSymbol" ],
        { },
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-Context-NoLocalSymbol-GH#249"
    ]
]

If[ $localEvaluatorAvailable,
    VerificationTest[
        Replace[
            contextState,
            HoldCompleteForm[ { context_, path_ } ] :> WolframLanguageToolEvaluate[
                HoldComplete[ $Context = context; $ContextPath = path ],
                "Result",
                Method -> "Local",
                Line   -> None
            ]
        ],
        HoldCompleteForm[ { __String } ],
        SameTest -> MatchQ,
        TestID   -> "LocalEvaluator-Context-Restore-GH#249"
    ]
]
