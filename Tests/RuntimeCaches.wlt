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

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$mxFlag*)

(* The flag is only meant to be True while building the MX file, so it should be False here whether the paclet was
   loaded from source or from an MX file: *)
VerificationTest[
    Wolfram`Chatbook`Common`$mxFlag,
    False,
    SameTest -> SameQ,
    TestID   -> "MXFlag-FalseAtRuntime-GH#1697"
]

(* The flag must be read when used, or the value set while loading the package gets saved as True in the MX file: *)
VerificationTest[
    Block[ { Wolfram`ChatbookInternal`$BuildingMX = True }, Wolfram`Chatbook`Common`$mxFlag ],
    True,
    SameTest -> SameQ,
    TestID   -> "MXFlag-TrueWhileBuildingMX-GH#1697"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Runtime Caches*)

(* These values are cached on first use unless $mxFlag is True. The definitions are checked without evaluating them,
   since evaluating an uncached definition would still give the right value. *)
VerificationTest[
    Wolfram`Chatbook`Common`Private`$templateBoxDisplayFunctions;
    OwnValues @ Wolfram`Chatbook`Common`Private`$templateBoxDisplayFunctions,
    { _ :> _Association? AssociationQ },
    SameTest -> MatchQ,
    TestID   -> "TemplateBoxDisplayFunctions-Cached-GH#1697"
]

(* :!CodeAnalysis::EndBlock:: *)
