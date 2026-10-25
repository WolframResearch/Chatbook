(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/RuntimeCaches.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/RuntimeCaches.wlt:11,1-16,2"
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
    TestID   -> "MXFlag-FalseAtRuntime-GH#1697@@Tests/RuntimeCaches.wlt:27,1-32,2"
]

(* The flag must be read when used, or the value set while loading the package gets saved as True in the MX file: *)
VerificationTest[
    Block[ { Wolfram`ChatbookInternal`$BuildingMX = True }, Wolfram`Chatbook`Common`$mxFlag ],
    True,
    SameTest -> SameQ,
    TestID   -> "MXFlag-TrueWhileBuildingMX-GH#1697@@Tests/RuntimeCaches.wlt:35,1-40,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Runtime Caches*)

(* These values are cached on first use unless $mxFlag is True. The definitions are checked without evaluating them,
   since evaluating an uncached definition would still give the right value. *)
VerificationTest[
    Wolfram`Chatbook`Common`serviceFrameworkAvailable[ ];
    MemberQ[
        DownValues @ Wolfram`Chatbook`Common`serviceFrameworkAvailable,
        HoldPattern[ Verbatim[ HoldPattern ][ Wolfram`Chatbook`Common`serviceFrameworkAvailable[ ] ] :> True|False ]
    ],
    True,
    SameTest -> SameQ,
    TestID   -> "ServiceFrameworkAvailable-Cached-GH#1697@@Tests/RuntimeCaches.wlt:48,1-57,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`Private`$chatbookIcons;
    OwnValues @ Wolfram`Chatbook`Common`Private`$chatbookIcons,
    { _ :> _Association? AssociationQ },
    SameTest -> MatchQ,
    TestID   -> "ChatbookIcons-Cached-GH#1697@@Tests/RuntimeCaches.wlt:59,1-65,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`Private`$templateBoxDisplayFunctions;
    OwnValues @ Wolfram`Chatbook`Common`Private`$templateBoxDisplayFunctions,
    { _ :> _Association? AssociationQ },
    SameTest -> MatchQ,
    TestID   -> "TemplateBoxDisplayFunctions-Cached-GH#1697@@Tests/RuntimeCaches.wlt:67,1-73,2"
]

(* :!CodeAnalysis::EndBlock:: *)
