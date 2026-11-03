(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/FormattingPerformance.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/FormattingPerformance.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Exact Replacements*)
(* Faster definitions in the formatter that give the same results as the ones they replaced. formatTextString evaluates
   the right-hand sides of $stringFormatRules after the split, and drops a "" at either end as StringSplit does: *)
VerificationTest[
    Wolfram`Chatbook`Formatting`Private`formatTextString /@ { "**```**", "**```** a", "a ~~```~~", "a **```** b" },
    { { }, { " a" }, { "a " }, { "a ", "", " b" } },
    TestID -> "DeferredRules-EmptyEnds@@Tests/FormattingPerformance.wlt:26,1-30,2"
]

(* :!CodeAnalysis::EndBlock:: *)
