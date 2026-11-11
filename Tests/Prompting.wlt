(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Placeholders*)

(* The "Placeholders" component is pulled in automatically wherever Wolfram Language style guidelines apply: *)
VerificationTest[
    Wolfram`Chatbook`Common`withBasePromptBuilder[
        Wolfram`Chatbook`Common`needsBasePrompt[ "WolframLanguageStyle" ];
        Wolfram`Chatbook`Common`$basePrompt
    ],
    _String? (StringContainsQ[ #, "Placeholder[\"description\"]" ] &),
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-Placeholders-WolframLanguageStyle"
]

VerificationTest[
    Wolfram`Chatbook`Common`withBasePromptBuilder[
        Wolfram`Chatbook`Common`needsBasePrompt[ "WolframLanguage" ];
        Wolfram`Chatbook`Common`$basePrompt
    ],
    _String? (StringContainsQ[ #, "Placeholder[\"description\"]" ] &),
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-Placeholders-WolframLanguageClass"
]

(* It should not appear when no Wolfram Language prompting was requested: *)
VerificationTest[
    Wolfram`Chatbook`Common`withBasePromptBuilder @ Wolfram`Chatbook`Common`$basePrompt,
    _String? (StringFreeQ[ #, "Placeholder" ] &),
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-Placeholders-NotIncludedByDefault"
]

(* :!CodeAnalysis::EndBlock:: *)
