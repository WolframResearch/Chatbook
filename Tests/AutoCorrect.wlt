(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/AutoCorrect.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/AutoCorrect.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*replaceUnicode*)

(* Outgoing content must be pure ASCII, since the models this is enabled for mishandle the private use area *)
VerificationTest[
    Wolfram`Chatbook`SendChat`Private`replaceUnicodeCharacters[ "\[FreeformPrompt][\"France\"]" ],
    "\\[FreeformPrompt][\"France\"]",
    SameTest -> MatchQ,
    TestID   -> "ReplaceUnicode-ASCII@@Tests/AutoCorrect.wlt:26,1-31,2"
]

VerificationTest[
    Wolfram`Chatbook`SendChat`Private`replaceUnicodeCharacters[ "\[FreeformPrompt]" ],
    "\\[FreeformPrompt]",
    SameTest -> MatchQ,
    TestID   -> "ReplaceUnicode-LongName@@Tests/AutoCorrect.wlt:33,1-38,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*autoCorrect*)
(* autoCorrect must restore whatever replaceUnicodeCharacters sent to the model *)
VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect @* Wolfram`Chatbook`SendChat`Private`replaceUnicodeCharacters /@
        { "\[FreeformPrompt]", "\[FreeformPrompt][\"France\"]", "no freeform prompt here" },
    { "\[FreeformPrompt]", "\[FreeformPrompt][\"France\"]", "no freeform prompt here" },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-ReplaceUnicode-RoundTrip@@Tests/AutoCorrect.wlt:44,1-50,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "\\uF351[\"France\", Entity]" ],
    "\[FreeformPrompt][\"France\", Entity]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-ReplaceUnicode-Entity@@Tests/AutoCorrect.wlt:52,1-57,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Regression Tests*)
VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "QuantityMagnitude[EntityValue[\[FreeformPrompt][\"France\", Entity], \"Population\"]]" ],
    "QuantityMagnitude[EntityValue[\[FreeformPrompt][\"France\", Entity], \"Population\"]]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Preserve-Valid@@Tests/AutoCorrect.wlt:62,1-67,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "{\:ff1d[\"a\", Entity], \:ff1d[\"b\", Entity]}" ],
    "{\[FreeformPrompt][\"a\", Entity], \[FreeformPrompt][\"b\", Entity]}",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Preserve-Structure@@Tests/AutoCorrect.wlt:69,1-74,2"
]

(* Models sometimes over-escape the leading backslash, so any number of them must be accepted *)
VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "\\\\[FreeformPrompt][\"France\", Entity]" ],
    "\[FreeformPrompt][\"France\", Entity]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Extra-Backslashes@@Tests/AutoCorrect.wlt:77,1-82,2"
]

VerificationTest[
    (* Concatenated to keep the unrecognized long names out of the source text *)
    Wolfram`Chatbook`Common`autoCorrect /@ {
        "\\" <> "[FreeformInput][\"a\"]",
        "\\\\" <> "[FreeformInput][\"a\"]",
        "\\" <> "[FreeformEntity][\"a\"]",
        "\\\\" <> "[FreeformEntity][\"a\"]"
    },
    ConstantArray[ "\[FreeformPrompt][\"a\"]", 4 ],
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Freeform-Aliases@@Tests/AutoCorrect.wlt:84,1-95,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "\\[RawEscape][FreeformPrompt][\"France\"]" ],
    "\[FreeformPrompt][\"France\"]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-RawEscape@@Tests/AutoCorrect.wlt:97,1-102,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "\\\:ff1d[\"a\", Entity]" ],
    "\[FreeformPrompt][\"a\", Entity]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Backslash-Fullwidth@@Tests/AutoCorrect.wlt:104,1-109,2"
]

(* :!CodeAnalysis::EndBlock:: *)