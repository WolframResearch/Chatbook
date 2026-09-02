(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Sandbox.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Sandbox.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Default Sandbox Paths*)

(* AgentTools persists evaluator session state from the sandbox kernel to this directory: *)
VerificationTest[
    MemberQ[
        Wolfram`Chatbook`Sandbox`Private`$defaultWritePaths,
        FileNameJoin @ { $UserBaseDirectory, "ApplicationData", "Wolfram", "AgentTools" }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "DefaultWritePaths-AgentTools-GH#1595@@Tests/Sandbox.wlt:26,1-34,2"
]

VerificationTest[
    MemberQ[
        Wolfram`Chatbook`Sandbox`Private`makeWritePaths @ Automatic,
        FileNameJoin @ { $UserBaseDirectory, "ApplicationData", "Wolfram", "AgentTools" }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "MakeWritePaths-Automatic-AgentTools-GH#1595@@Tests/Sandbox.wlt:36,1-44,2"
]

(* Session files are read back via Get, which relies on read access to all of ApplicationData. *)
(* Initializing $defaultReadPaths mentions the front end, which is not available when running tests: *)
VerificationTest[
    Quiet[
        MemberQ[
            Wolfram`Chatbook`Sandbox`Private`$defaultReadPaths,
            FileNameJoin @ { $UserBaseDirectory, "ApplicationData" }
        ],
        FrontEndObject::notavail
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "DefaultReadPaths-ApplicationData-GH#1595@@Tests/Sandbox.wlt:48,1-59,2"
]

(* :!CodeAnalysis::EndBlock:: *)
