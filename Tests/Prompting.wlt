(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Prompting.wlt:7,1-12,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Prompting.wlt:14,1-19,2"
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
    TestID   -> "BasePrompt-Placeholders-WolframLanguageStyle@@Tests/Prompting.wlt:26,1-34,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`withBasePromptBuilder[
        Wolfram`Chatbook`Common`needsBasePrompt[ "WolframLanguage" ];
        Wolfram`Chatbook`Common`$basePrompt
    ],
    _String? (StringContainsQ[ #, "Placeholder[\"description\"]" ] &),
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-Placeholders-WolframLanguageClass@@Tests/Prompting.wlt:36,1-44,2"
]

(* It should not appear when no Wolfram Language prompting was requested: *)
VerificationTest[
    Wolfram`Chatbook`Common`withBasePromptBuilder @ Wolfram`Chatbook`Common`$basePrompt,
    _String? (StringFreeQ[ #, "Placeholder" ] &),
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-Placeholders-NotIncludedByDefault@@Tests/Prompting.wlt:47,1-52,2"
]

(* :!CodeAnalysis::EndBlock:: *)
