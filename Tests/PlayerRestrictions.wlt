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
(*$playerFrontEnd*)

(* Without a front end the check makes no front end call and is not cached, so a front end started later is checked: *)
VerificationTest[
    Block[ { $Notebooks = False },
        { Wolfram`Chatbook`Common`$playerFrontEnd, OwnValues @ Wolfram`Chatbook`Common`$playerFrontEnd }
    ],
    { False, { _ :> _If } },
    SameTest -> MatchQ,
    TestID   -> "PlayerFrontEnd-No-Front-End-475940"
]

(* Not Player in the front end that runs the tests, and the answer is cached after the first check: *)
VerificationTest[
    UsingFrontEnd @ {
        Wolfram`Chatbook`Common`$playerFrontEnd,
        OwnValues @ Wolfram`Chatbook`Common`$playerFrontEnd
    },
    { False, { _ :> False } },
    SameTest -> MatchQ,
    TestID   -> "PlayerFrontEnd-Cached-475940"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*EvaluateChatInput*)

(* In Player, evaluating a chat input cell (by Return, the send button, or a menu item) sends no chat: *)
VerificationTest[
    Module[ { sent = False },
        Block[
            {
                Wolfram`Chatbook`Common`$playerFrontEnd = True,
                Wolfram`Chatbook`Common`sendChat        = (sent = True; Null) &
            },
            { Wolfram`Chatbook`ChatbookAction[ "EvaluateChatInput", CellObject[ "TestInputCell" ] ], sent }
        ]
    ],
    { Null, False },
    SameTest -> SameQ,
    TestID   -> "EvaluateChatInput-Player-475940"
]

(* :!CodeAnalysis::EndBlock:: *)
