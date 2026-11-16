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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*appendCitations*)

(* Regression tests for issue #1393: appendCitations can run after the withChatState Block
   has unwound (e.g. from an async FE task), at which point Wolfram`Chatbook`Common`$sources
   has reverted to its global default of None. It must not fail the AssociationQ confirmation
   in that state, regardless of the "AppendCitations" setting. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$sources is None and citations are disabled*)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$sources = None },
        Module[ { container, result },
            container = <| "FullContent" -> "Hello world.", "DynamicContent" -> "Hello world." |>;
            result = Wolfram`Chatbook`Common`appendCitations[ container, <| "AppendCitations" -> False |> ];
            { FailureQ @ result, container[ "FullContent" ], container[ "DynamicContent" ] }
        ]
    ],
    { False, "Hello world.", "Hello world." },
    TestID -> "appendCitations-NoneSources-Disabled"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$sources is None and citations are enabled*)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$sources = None },
        Module[ { container, result },
            container = <| "FullContent" -> "Hello world.", "DynamicContent" -> "Hello world." |>;
            result = Wolfram`Chatbook`Common`appendCitations[
                container,
                <|
                    "AppendCitations"  -> True,
                    "HandlerFunctions" -> <|
                        "Resolved"             -> True,
                        "AppendCitationsStart" -> (Null &),
                        "AppendCitationsEnd"   -> (Null &)
                    |>
                |>
            ];
            { FailureQ @ result, container[ "FullContent" ], container[ "DynamicContent" ] }
        ]
    ],
    { False, "Hello world.", "Hello world." },
    TestID -> "appendCitations-NoneSources-Enabled"
]
