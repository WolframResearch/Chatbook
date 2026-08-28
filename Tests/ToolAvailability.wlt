(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ToolAvailability.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ToolAvailability.wlt:11,1-16,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`Tools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadToolsContext@@Tests/ToolAvailability.wlt:18,1-23,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FileReader Version Gating*)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
VerificationTest[
    KeyExistsQ[ Wolfram`Chatbook`$DefaultTools, "FileReader" ],
    TrueQ @ ( $VersionNumber >= 15.1 ),
    SameTest -> SameQ,
    TestID   -> "FileReader-DefaultToolDefinition@@Tests/ToolAvailability.wlt:28,1-33,2"
]

VerificationTest[
    KeyExistsQ[ Wolfram`Chatbook`$ToolFunctions, "FileReader" ],
    TrueQ @ ( $VersionNumber >= 15.1 ),
    SameTest -> SameQ,
    TestID   -> "FileReader-ToolFunctionMap@@Tests/ToolAvailability.wlt:35,1-40,2"
]

VerificationTest[
    KeyExistsQ[ Wolfram`Chatbook`$DefaultToolOptions, "FileReader" ],
    TrueQ @ ( $VersionNumber >= 15.1 ),
    SameTest -> SameQ,
    TestID   -> "FileReader-DefaultOptions@@Tests/ToolAvailability.wlt:42,1-47,2"
]

VerificationTest[
    KeyExistsQ[ Wolfram`Chatbook`Tools`Private`$toolNameAliases, "ReadFile" ],
    TrueQ @ ( $VersionNumber >= 15.1 ),
    SameTest -> SameQ,
    TestID   -> "FileReader-Alias@@Tests/ToolAvailability.wlt:49,1-54,2"
]
(* :!CodeAnalysis::EndBlock:: *)