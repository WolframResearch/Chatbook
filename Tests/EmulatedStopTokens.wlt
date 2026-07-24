(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/EmulatedStopTokens.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/EmulatedStopTokens.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* Models that do not support server-side stop tokens (e.g. gpt-5 and later) rely on client-side detection of the
   "\n/exec" end token when using the "Simple" tool method. These tests simulate the per-chunk trimming that occurs
   in the chat submit handlers. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*emulateStopTokensQ*)
VerificationTest[
    Wolfram`Chatbook`SendChat`Private`emulateStopTokensQ @ <|
        "ToolMethod"   -> "Simple",
        "ToolsEnabled" -> True,
        "StopTokens"   -> Missing[ "NotSupported" ]
    |>,
    True,
    SameTest -> MatchQ,
    TestID   -> "EmulateStopTokensQ-SimpleNoStopTokens@@Tests/EmulatedStopTokens.wlt:28,1-37,2"
]

VerificationTest[
    Wolfram`Chatbook`SendChat`Private`emulateStopTokensQ /@ {
        (* Model supports stop tokens, so the server handles them: *)
        <| "ToolMethod" -> "Simple", "ToolsEnabled" -> True, "StopTokens" -> { "\n/exec" } |>,
        (* Only the "Simple" tool method is currently emulated: *)
        <| "ToolMethod" -> "Textual", "ToolsEnabled" -> True, "StopTokens" -> Missing[ "NotSupported" ] |>,
        (* No tools means nothing to detect: *)
        <| "ToolMethod" -> "Simple", "ToolsEnabled" -> False, "StopTokens" -> Missing[ "NotSupported" ] |>
    },
    { False, False, False },
    SameTest -> MatchQ,
    TestID   -> "EmulateStopTokensQ-NotApplicable@@Tests/EmulatedStopTokens.wlt:39,1-51,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Streaming simulation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Model ends response after writing /exec*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`SendChat`Private`$emulatedStopBuffer    = "",
            Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered = False
        },
        Module[ { container },
            container = <| "DynamicContent" -> "", "FullContent" -> "" |>;
            Scan[
                Function[ chunk,
                    If[ ! TrueQ @ Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered,
                        With[
                            {
                                text = StringJoin @@ Wolfram`Chatbook`SendChat`Private`applyEmulatedStopTokens[
                                    container,
                                    True,
                                    <| "ExtractedBodyChunks" -> { chunk } |>
                                ][ "ExtractedBodyChunks" ]
                            },
                            container[ "DynamicContent" ] =
                                Wolfram`Chatbook`SendChat`Private`appendStringContent[
                                    container[ "DynamicContent" ],
                                    text
                                ];
                            container[ "FullContent" ] =
                                Wolfram`Chatbook`SendChat`Private`appendStringContent[
                                    container[ "FullContent" ],
                                    text
                                ]
                        ]
                    ]
                ],
                { "Some text\n\n/wl\nPrime[123]", "\n/exec" }
            ];
            {
                container[ "FullContent" ],
                container[ "DynamicContent" ],
                Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered
            }
        ]
    ],
    { "Some text\n\n/wl\nPrime[123]", "Some text\n\n/wl\nPrime[123]", True },
    SameTest -> MatchQ,
    TestID   -> "EmulatedStop-CleanStop@@Tests/EmulatedStopTokens.wlt:60,1-104,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Model continues writing after /exec*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`SendChat`Private`$emulatedStopBuffer    = "",
            Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered = False
        },
        Module[ { container },
            container = <| "DynamicContent" -> "", "FullContent" -> "" |>;
            Scan[
                Function[ chunk,
                    If[ ! TrueQ @ Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered,
                        With[
                            {
                                text = StringJoin @@ Wolfram`Chatbook`SendChat`Private`applyEmulatedStopTokens[
                                    container,
                                    True,
                                    <| "ExtractedBodyChunks" -> { chunk } |>
                                ][ "ExtractedBodyChunks" ]
                            },
                            container[ "DynamicContent" ] =
                                Wolfram`Chatbook`SendChat`Private`appendStringContent[
                                    container[ "DynamicContent" ],
                                    text
                                ];
                            container[ "FullContent" ] =
                                Wolfram`Chatbook`SendChat`Private`appendStringContent[
                                    container[ "FullContent" ],
                                    text
                                ]
                        ]
                    ]
                ],
                { "/wl\nPrime[123]\n", "/exec\nHallucinated **answer** here.", "\n\nMore text." }
            ];
            {
                container[ "FullContent" ],
                container[ "DynamicContent" ],
                Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered
            }
        ]
    ],
    { "/wl\nPrime[123]", "/wl\nPrime[123]", True },
    SameTest -> MatchQ,
    TestID   -> "EmulatedStop-DiscardsHallucinatedContinuation@@Tests/EmulatedStopTokens.wlt:109,1-153,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Stop token split across several chunks*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`SendChat`Private`$emulatedStopBuffer    = "",
            Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered = False
        },
        Module[ { container },
            container = <| "DynamicContent" -> "", "FullContent" -> "" |>;
            Scan[
                Function[ chunk,
                    If[ ! TrueQ @ Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered,
                        With[
                            {
                                text = StringJoin @@ Wolfram`Chatbook`SendChat`Private`applyEmulatedStopTokens[
                                    container,
                                    True,
                                    <| "ExtractedBodyChunks" -> { chunk } |>
                                ][ "ExtractedBodyChunks" ]
                            },
                            container[ "DynamicContent" ] =
                                Wolfram`Chatbook`SendChat`Private`appendStringContent[
                                    container[ "DynamicContent" ],
                                    text
                                ];
                            container[ "FullContent" ] =
                                Wolfram`Chatbook`SendChat`Private`appendStringContent[
                                    container[ "FullContent" ],
                                    text
                                ]
                        ]
                    ]
                ],
                { "/wl\nRandomReal[]", "\n/e", "xec", "\nmore junk" }
            ];
            {
                container[ "FullContent" ],
                container[ "DynamicContent" ],
                Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered
            }
        ]
    ],
    { "/wl\nRandomReal[]", "/wl\nRandomReal[]", True },
    SameTest -> MatchQ,
    TestID   -> "EmulatedStop-SplitStopToken@@Tests/EmulatedStopTokens.wlt:158,1-202,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Response without any tool calls streams normally*)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`SendChat`Private`$emulatedStopBuffer    = "",
            Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered = False
        },
        Module[ { container },
            container = <| "DynamicContent" -> "", "FullContent" -> "" |>;
            Scan[
                Function[ chunk,
                    If[ ! TrueQ @ Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered,
                        With[
                            {
                                text = StringJoin @@ Wolfram`Chatbook`SendChat`Private`applyEmulatedStopTokens[
                                    container,
                                    True,
                                    <| "ExtractedBodyChunks" -> { chunk } |>
                                ][ "ExtractedBodyChunks" ]
                            },
                            container[ "DynamicContent" ] =
                                Wolfram`Chatbook`SendChat`Private`appendStringContent[
                                    container[ "DynamicContent" ],
                                    text
                                ];
                            container[ "FullContent" ] =
                                Wolfram`Chatbook`SendChat`Private`appendStringContent[
                                    container[ "FullContent" ],
                                    text
                                ]
                        ]
                    ]
                ],
                { "Just a normal ", "response with no tools." }
            ];
            {
                container[ "FullContent" ],
                container[ "DynamicContent" ],
                Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered
            }
        ]
    ],
    { "Just a normal response with no tools.", "Just a normal response with no tools.", False },
    SameTest -> MatchQ,
    TestID   -> "EmulatedStop-NoToolCall@@Tests/EmulatedStopTokens.wlt:207,1-251,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Stop tokens from previous rounds are ignored*)

(* The container already holds a completed tool call from an earlier round of the conversation. Only the new
   round's "\n/exec" may trigger, and the resulting content must parse as a tool call for `NextPrime`. *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`SendChat`Private`$emulatedStopBuffer    = "",
            Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered = False
        },
        Module[ { prior, container, request },
            prior = StringJoin[
                "/wl\nPrime[123456789]\n/exec\nRESULT\nOut[1]= 2543568463\nENDRESULT(70ua8j1ev)\n\n",
                "The prime is **2543568463**.\n\n"
            ];
            container = <| "DynamicContent" -> prior, "FullContent" -> prior |>;
            Scan[
                Function[ chunk,
                    If[ ! TrueQ @ Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered,
                        With[
                            {
                                text = StringJoin @@ Wolfram`Chatbook`SendChat`Private`applyEmulatedStopTokens[
                                    container,
                                    True,
                                    <| "ExtractedBodyChunks" -> { chunk } |>
                                ][ "ExtractedBodyChunks" ]
                            },
                            container[ "DynamicContent" ] =
                                Wolfram`Chatbook`SendChat`Private`appendStringContent[
                                    container[ "DynamicContent" ],
                                    text
                                ];
                            container[ "FullContent" ] =
                                Wolfram`Chatbook`SendChat`Private`appendStringContent[
                                    container[ "FullContent" ],
                                    text
                                ]
                        ]
                    ]
                ],
                { "/wl\nNextPrime[2543568463]", "\n/exec\n\nThe next prime is **2543568499**." }
            ];
            request = Wolfram`Chatbook`Common`simpleToolRequestParser @ container[ "FullContent" ];
            {
                StringEndsQ[ container[ "FullContent" ], "/wl\nNextPrime[2543568463]" ],
                StringContainsQ[ container[ "FullContent" ], "ENDRESULT(70ua8j1ev)" ],
                Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered,
                Lookup[ Association @ request[[ 2 ]][ "ParameterValues" ], "code" ]
            }
        ]
    ],
    { True, True, True, "NextPrime[2543568463]" },
    SameTest -> MatchQ,
    TestID   -> "EmulatedStop-MultiRound@@Tests/EmulatedStopTokens.wlt:259,1-309,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*applyEmulatedStopTokens*)

(* Pass-through cases: emulation disabled or no extracted content strings *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`SendChat`Private`$emulatedStopBuffer    = "",
            Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered = False
        },
        Module[ { container },
            container = <| "DynamicContent" -> "", "FullContent" -> "" |>;
            {
                Wolfram`Chatbook`SendChat`Private`applyEmulatedStopTokens[
                    container,
                    False,
                    <| "ExtractedBodyChunks" -> { "a\n/exec\nb" } |>
                ],
                Wolfram`Chatbook`SendChat`Private`applyEmulatedStopTokens[
                    container,
                    True,
                    <| "ExtractedBodyChunks" -> { } |>
                ],
                Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered
            }
        ]
    ],
    {
        <| "ExtractedBodyChunks" -> { "a\n/exec\nb" } |>,
        <| "ExtractedBodyChunks" -> { } |>,
        False
    },
    SameTest -> MatchQ,
    TestID   -> "ApplyEmulatedStopTokens-PassThrough@@Tests/EmulatedStopTokens.wlt:316,1-346,2"
]

(* :!CodeAnalysis::EndBlock:: *)
