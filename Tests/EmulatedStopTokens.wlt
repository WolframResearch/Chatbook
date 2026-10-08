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
   stop tokens that would otherwise have been used (e.g. "\n/exec" for the "Simple" tool method). These tests simulate
   the per-chunk trimming that occurs in the chat submit handlers. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*emulatedStopTokens*)
VerificationTest[
    Block[ { $AutomaticAssistance = False },
        Table[
            Wolfram`Chatbook`SendChat`Private`emulatedStopTokens @ <| base, settings |>,
            {
                base,
                {
                    <| "ToolsEnabled" -> True, "StopTokens" -> Missing[ "NotSupported" ] |>,
                    (* Resolved settings do not include parameters that are not supported: *)
                    <| "ToolsEnabled" -> True |>
                }
            },
            {
                settings,
                {
                    <| "ToolMethod" -> "Simple" , "EndToken" -> None  , "ToolCallExamplePromptStyle" -> "Basic" |>,
                    <| "ToolMethod" -> "Simple" , "EndToken" -> "/end", "ToolCallExamplePromptStyle" -> "Basic" |>,
                    <| "ToolMethod" -> "Textual", "EndToken" -> None  , "ToolCallExamplePromptStyle" -> "Basic" |>,
                    <| "ToolMethod" -> "JSON"   , "EndToken" -> "/end", "ToolCallExamplePromptStyle" -> "Basic" |>,
                    <| "ToolMethod" -> Automatic, "EndToken" -> None  , "ToolCallExamplePromptStyle" -> "Basic" |>,
                    <| "ToolMethod" -> "Service", "EndToken" -> "/end", "ToolCallExamplePromptStyle" -> "Basic" |>,
                    <| "ToolMethod" -> "Simple" , "EndToken" -> None  , "ToolCallExamplePromptStyle" -> "Llama" |>
                }
            }
        ]
    ],
    ConstantArray[
        {
            { "\n/exec" },
            { "\n/exec", "/end" },
            { "ENDTOOLCALL" },
            { "ENDTOOLCALL", "/end" },
            { "ENDTOOLCALL", "\n/exec" },
            { "/end" },
            { "\n/exec", "<|start_header_id|>" }
        },
        2
    ],
    SameTest -> MatchQ,
    TestID   -> "EmulatedStopTokens-ToolMethods@@Tests/EmulatedStopTokens.wlt:28,1-68,2"
]

VerificationTest[
    Block[ { $AutomaticAssistance = False },
        Wolfram`Chatbook`SendChat`Private`emulatedStopTokens /@ {
            (* Model supports stop tokens, so the server handles them: *)
            <| "ToolMethod" -> "Simple", "ToolsEnabled" -> True, "StopTokens" -> { "\n/exec" } |>,
            (* Stop tokens are supported, but none are needed: *)
            <| "ToolMethod" -> "Simple", "ToolsEnabled" -> False, "StopTokens" -> None |>,
            (* No tools means nothing to detect: *)
            <| "ToolMethod" -> "Simple", "ToolsEnabled" -> False, "StopTokens" -> Missing[ "NotSupported" ] |>,
            (* Service tool calls don't need an end token: *)
            <|
                "ToolMethod"                 -> "Service",
                "ToolsEnabled"               -> True,
                "EndToken"                   -> None,
                "ToolCallExamplePromptStyle" -> "Basic",
                "StopTokens"                 -> Missing[ "NotSupported" ]
            |>
        }
    ],
    { None, None, None, None },
    SameTest -> MatchQ,
    TestID   -> "EmulatedStopTokens-NotApplicable@@Tests/EmulatedStopTokens.wlt:70,1-92,2"
]

VerificationTest[
    Block[ { $AutomaticAssistance = True },
        Wolfram`Chatbook`SendChat`Private`emulatedStopTokens /@ {
            <| "ToolsEnabled" -> False, "StopTokens" -> Missing[ "NotSupported" ] |>,
            <|
                "ToolMethod"                 -> "Simple",
                "ToolsEnabled"               -> True,
                "EndToken"                   -> None,
                "ToolCallExamplePromptStyle" -> "Basic",
                "StopTokens"                 -> Missing[ "NotSupported" ]
            |>
        }
    ],
    { { "[INFO]" }, { "\n/exec", "[INFO]" } },
    SameTest -> MatchQ,
    TestID   -> "EmulatedStopTokens-AutomaticAssistance@@Tests/EmulatedStopTokens.wlt:94,1-110,2"
]

(* The emulated stop tokens for resolved settings should match what the model would get if it supported them: *)
VerificationTest[
    Block[ { $AutomaticAssistance = False },
        Wolfram`Chatbook`SendChat`Private`emulatedStopTokens @ Wolfram`Chatbook`Common`resolveAutoSettings @ <|
            Wolfram`Chatbook`Common`$defaultChatSettings,
            #
        |> & /@ {
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.4" |> |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.4" |>, "ToolMethod" -> "Textual" |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.4" |>, "ToolMethod" -> "JSON" |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.4" |>, "ToolsEnabled" -> False |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |> |>
        }
    ],
    { { "\n/exec" }, { "ENDTOOLCALL" }, { "ENDTOOLCALL" }, None, None },
    SameTest -> MatchQ,
    TestID   -> "EmulatedStopTokens-ResolvedSettings@@Tests/EmulatedStopTokens.wlt:113,1-129,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Explicitly given stop tokens*)
VerificationTest[
    Wolfram`Chatbook`Common`stopTokensSupportedQ /@ {
        <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |> |>,
        <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.4" |> |>,
        <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>, "RequestMethod" -> "Responses" |>,
        <| "StopTokens" -> Missing[ "NotSupported" ] |>,
        <| |>
    },
    { True, False, False, False, True },
    SameTest -> MatchQ,
    TestID   -> "StopTokensSupportedQ@@Tests/EmulatedStopTokens.wlt:134,1-145,2"
]

(* Explicitly given stop tokens should not be replaced by automatic ones: *)
VerificationTest[
    Block[ { $AutomaticAssistance = False },
        Lookup[
            Wolfram`Chatbook`Common`resolveAutoSettings @ <| Wolfram`Chatbook`Common`$defaultChatSettings, # |>,
            "StopTokens"
        ] & /@ {
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>, "StopTokens" -> { "STOP" } |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>, "StopTokens" -> None |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.4" |>, "StopTokens" -> { "STOP" } |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |> |>
        }
    ],
    { { "STOP" }, None, { "STOP" }, { "\n/exec", "/end" } },
    SameTest -> MatchQ,
    TestID   -> "ExplicitStopTokens-Resolved@@Tests/EmulatedStopTokens.wlt:148,1-163,2"
]

(* Explicitly given stop tokens are sent when supported, and emulated otherwise: *)
VerificationTest[
    Block[ { $AutomaticAssistance = False },
        Function[
            settings,
            {
                Wolfram`Chatbook`SendChat`Private`makeStopTokens @ settings,
                Wolfram`Chatbook`SendChat`Private`emulatedStopTokens @ settings
            }
        ] /@ {
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>, "StopTokens" -> { "STOP" } |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.4" |>, "StopTokens" -> { "STOP" } |>,
            <|
                "Model"         -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>,
                "RequestMethod" -> "Responses",
                "StopTokens"    -> { "STOP" }
            |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.4" |>, "StopTokens" -> None |>
        }
    ],
    { { { "STOP" }, None }, { _Missing, { "STOP" } }, { _Missing, { "STOP" } }, { _Missing, None } },
    SameTest -> MatchQ,
    TestID   -> "ExplicitStopTokens-SentOrEmulated@@Tests/EmulatedStopTokens.wlt:166,1-188,2"
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
                                    { "\n/exec" },
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
    TestID   -> "EmulatedStop-CleanStop@@Tests/EmulatedStopTokens.wlt:197,1-241,2"
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
                                    { "\n/exec" },
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
    TestID   -> "EmulatedStop-DiscardsHallucinatedContinuation@@Tests/EmulatedStopTokens.wlt:246,1-290,2"
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
                                    { "\n/exec" },
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
    TestID   -> "EmulatedStop-SplitStopToken@@Tests/EmulatedStopTokens.wlt:295,1-339,2"
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
                                    { "\n/exec" },
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
    TestID   -> "EmulatedStop-NoToolCall@@Tests/EmulatedStopTokens.wlt:344,1-388,2"
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
                                    { "\n/exec" },
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
    TestID   -> "EmulatedStop-MultiRound@@Tests/EmulatedStopTokens.wlt:396,1-446,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Other tool methods*)

(* With the "Textual" tool method, the end token is "ENDTOOLCALL". Here it arrives split across chunks and the model
   continues with a hallucinated result. The remaining content must parse as a tool call with `toolRequestParser`. *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`SendChat`Private`$emulatedStopBuffer    = "",
            Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered = False
        },
        Module[ { container, request },
            container = <| "DynamicContent" -> "", "FullContent" -> "" |>;
            Scan[
                Function[ chunk,
                    If[ ! TrueQ @ Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered,
                        With[
                            {
                                text = StringJoin @@ Wolfram`Chatbook`SendChat`Private`applyEmulatedStopTokens[
                                    container,
                                    { "ENDTOOLCALL" },
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
                {
                    "Let me look that up.\n\nTOOLCALL: documentation_searcher\n",
                    "{\"query\": \"plot a function\"}\nENDARGUMENTS\nENDTOOL",
                    "CALL\nRESULT\nPlot\nENDRESULT\n\nUse Plot."
                }
            ];
            request = Wolfram`Chatbook`Common`toolRequestParser @ container[ "FullContent" ];
            {
                container[ "FullContent" ],
                container[ "DynamicContent" ],
                Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered,
                request[[ 2 ]][ "Name" ],
                Lookup[ Association @ request[[ 2 ]][ "ParameterValues" ], "query" ]
            }
        ]
    ],
    {
        "Let me look that up.\n\nTOOLCALL: documentation_searcher\n{\"query\": \"plot a function\"}\nENDARGUMENTS\n",
        "Let me look that up.\n\nTOOLCALL: documentation_searcher\n{\"query\": \"plot a function\"}\nENDARGUMENTS\n",
        True,
        "documentation_searcher",
        "plot a function"
    },
    SameTest -> MatchQ,
    TestID   -> "EmulatedStop-TextualSplitStopToken@@Tests/EmulatedStopTokens.wlt:454,1-511,2"
]

(* When several stop tokens are emulated, the response is cut at whichever appears first: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`SendChat`Private`$emulatedStopBuffer    = "",
            Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered = False
        },
        Module[ { container },
            container = <| "DynamicContent" -> "", "FullContent" -> "" |>;
            {
                Wolfram`Chatbook`SendChat`Private`emulatedStopTokenTrim[
                    container,
                    "/wl\nPrime[5]\n/exec\nRESULT\n11\nENDRESULT\nENDTOOLCALL",
                    { "ENDTOOLCALL", "\n/exec" }
                ],
                Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered
            }
        ]
    ],
    { "/wl\nPrime[5]", True },
    SameTest -> MatchQ,
    TestID   -> "EmulatedStop-FirstOfSeveralStopTokens@@Tests/EmulatedStopTokens.wlt:514,1-535,2"
]

(* The end turn token is emulated for the "Service" tool method: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`SendChat`Private`$emulatedStopBuffer    = "",
            Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered = False
        },
        Module[ { container },
            container = <| "DynamicContent" -> "", "FullContent" -> "" |>;
            {
                Wolfram`Chatbook`SendChat`Private`emulatedStopTokenTrim[
                    container,
                    "The answer is 42.\n/end\n\nUser: thanks!",
                    { "/end" }
                ],
                Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered
            }
        ]
    ],
    { "The answer is 42.\n", True },
    SameTest -> MatchQ,
    TestID   -> "EmulatedStop-ServiceEndToken@@Tests/EmulatedStopTokens.wlt:538,1-559,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Reasoning*)

(* Stop tokens that appear within reasoning are ignored, since server-side stop tokens wouldn't apply to them: *)
VerificationTest[
    With[
        {
            string = StringJoin[
                "a ENDTOOLCALL <think type='summary' id='x'>\nENDTOOLCALL\n</think>\n",
                "b ENDTOOLCALL <think>ENDTOOLCALL</think> <thinking>ENDTOOLCALL</thinking> <think>\nENDTOOLCALL"
            ]
        },
        StringTake[ string, { #[[ 1 ]] - 2, #[[ 2 ]] } ] & /@ Wolfram`Chatbook`SendChat`Private`dropReasoningPositions[
            string,
            StringPosition[ string, "ENDTOOLCALL" ]
        ]
    ],
    { "a ENDTOOLCALL", "b ENDTOOLCALL" },
    SameTest -> MatchQ,
    TestID   -> "DropReasoningPositions@@Tests/EmulatedStopTokens.wlt:566,1-582,2"
]

(* A reasoning summary (as streamed from the responses endpoint) mentions the end token before the actual tool call,
   and both are split across chunks: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`SendChat`Private`$emulatedStopBuffer    = "",
            Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered = False
        },
        Module[ { container, triggered },
            container = <| "DynamicContent" -> "", "FullContent" -> "" |>;
            triggered = { };
            Scan[
                Function[ chunk,
                    If[ ! TrueQ @ Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered,
                        With[
                            {
                                text = StringJoin @@ Wolfram`Chatbook`SendChat`Private`applyEmulatedStopTokens[
                                    container,
                                    { "\n/exec" },
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
                        ];
                        AppendTo[ triggered, Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered ]
                    ]
                ],
                {
                    "<think type='summary' id='abc123'>\n**Planning**\nI'll write the code, then\n/ex",
                    "ec to run it.\n</think>\n/wl\nPrime[5]\n/ex",
                    "ec\nRESULT\n11\nENDRESULT"
                }
            ];
            {
                container[ "FullContent" ],
                container[ "DynamicContent" ],
                triggered
            }
        ]
    ],
    {
        "<think type='summary' id='abc123'>\n**Planning**\nI'll write the code, then\n/exec to run it.\n</think>\n/wl\nPrime[5]",
        "<think type='summary' id='abc123'>\n**Planning**\nI'll write the code, then\n/exec to run it.\n</think>\n/wl\nPrime[5]",
        { False, False, True }
    },
    SameTest -> MatchQ,
    TestID   -> "EmulatedStop-IgnoresReasoningSummary@@Tests/EmulatedStopTokens.wlt:586,1-640,2"
]

(* Reasoning that's still streaming hasn't been closed yet: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`SendChat`Private`$emulatedStopBuffer    = "",
            Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered = False
        },
        Module[ { container },
            container = <| "DynamicContent" -> "", "FullContent" -> "" |>;
            {
                Wolfram`Chatbook`SendChat`Private`emulatedStopTokenTrim[
                    container,
                    "<think type='summary' id='abc123'>\nThe call should end with ENDTOOLCALL",
                    { "ENDTOOLCALL" }
                ],
                Wolfram`Chatbook`SendChat`Private`$emulatedStopTriggered
            }
        ]
    ],
    { "<think type='summary' id='abc123'>\nThe call should end with ENDTOOLCALL", False },
    SameTest -> MatchQ,
    TestID   -> "EmulatedStop-IgnoresUnclosedReasoning@@Tests/EmulatedStopTokens.wlt:643,1-664,2"
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
                    None,
                    <| "ExtractedBodyChunks" -> { "a\n/exec\nb" } |>
                ],
                Wolfram`Chatbook`SendChat`Private`applyEmulatedStopTokens[
                    container,
                    { "\n/exec" },
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
    TestID   -> "ApplyEmulatedStopTokens-PassThrough@@Tests/EmulatedStopTokens.wlt:671,1-701,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*stopTokenTrim*)

(* llmChat and llmSynthesizeSubmit drop the server-side stop parameter for models that do not support it
   (via dropModelUnsupportedParameters) and instead trim the generated content client-side with stopTokenTrim. *)

VerificationTest[
    Wolfram`Chatbook`LLMUtilities`Private`stopTokenTrim[ "text with [WL] inside", { } ],
    "text with [WL] inside",
    SameTest -> MatchQ,
    TestID   -> "StopTokenTrim-NoStopTokens@@Tests/EmulatedStopTokens.wlt:710,1-715,2"
]

VerificationTest[
    Wolfram`Chatbook`LLMUtilities`Private`stopTokenTrim[
        "query one\nquery two\n[NONE] extra",
        { "[NONE]", "[WL]" }
    ],
    "query one\nquery two\n",
    SameTest -> MatchQ,
    TestID   -> "StopTokenTrim-TrimsToEnd@@Tests/EmulatedStopTokens.wlt:717,1-725,2"
]

VerificationTest[
    Wolfram`Chatbook`LLMUtilities`Private`stopTokenTrim[ "a[WL]b[WL]c", { "[NONE]", "[WL]" } ],
    "a",
    SameTest -> MatchQ,
    TestID   -> "StopTokenTrim-FirstOccurrence@@Tests/EmulatedStopTokens.wlt:727,1-732,2"
]

VerificationTest[
    Wolfram`Chatbook`LLMUtilities`Private`stopTokenTrim[ "[WL] use documentation instead", { "[NONE]", "[WL]" } ],
    "",
    SameTest -> MatchQ,
    TestID   -> "StopTokenTrim-EntireResponse@@Tests/EmulatedStopTokens.wlt:734,1-739,2"
]

VerificationTest[
    Wolfram`Chatbook`LLMUtilities`Private`stopTokenTrim[ "123456789th prime", { "[NONE]", "[WL]" } ],
    "123456789th prime",
    SameTest -> MatchQ,
    TestID   -> "StopTokenTrim-NoMatch@@Tests/EmulatedStopTokens.wlt:741,1-746,2"
]

(* A stop token may arrive split across several streamed chunks: *)
VerificationTest[
    Wolfram`Chatbook`LLMUtilities`Private`stopTokenTrim[ { "queries", "\n[NO", "NE] extra" }, { "[NONE]", "[WL]" } ],
    "queries\n",
    SameTest -> MatchQ,
    TestID   -> "StopTokenTrim-SplitChunks@@Tests/EmulatedStopTokens.wlt:749,1-754,2"
]

VerificationTest[
    Wolfram`Chatbook`LLMUtilities`Private`stopTokenTrim[ { }, { "[NONE]", "[WL]" } ],
    "",
    SameTest -> MatchQ,
    TestID   -> "StopTokenTrim-EmptyChunks@@Tests/EmulatedStopTokens.wlt:756,1-761,2"
]

(* llmChat responses are associations with a "Content" key; other keys pass through unchanged: *)
VerificationTest[
    Wolfram`Chatbook`LLMUtilities`Private`stopTokenTrim[
        <| "Content" -> "q1\n[WL] junk", "ToolRequests" -> { } |>,
        { "[NONE]", "[WL]" }
    ],
    <| "Content" -> "q1\n", "ToolRequests" -> { } |>,
    SameTest -> MatchQ,
    TestID   -> "StopTokenTrim-Association@@Tests/EmulatedStopTokens.wlt:764,1-772,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*dropModelUnsupportedParameters*)

(* gpt-5 does not support stop tokens, so the parameter is dropped before creating the LLMConfiguration: *)
VerificationTest[
    Wolfram`Chatbook`Common`dropModelUnsupportedParameters[
        Automatic,
        <|
            "Model"      -> <| "Service" -> "OpenAI", "Name" -> "gpt-5" |>,
            "StopTokens" -> { "[NONE]" },
            "MaxTokens"  -> 250
        |>
    ],
    <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-5" |>, "MaxTokens" -> 250 |>,
    SameTest -> MatchQ,
    TestID   -> "DropModelUnsupportedParameters-Automatic-Unsupported@@Tests/EmulatedStopTokens.wlt:779,1-791,2"
]

(* gpt-4o supports stop tokens, so the settings are unchanged: *)
VerificationTest[
    Wolfram`Chatbook`Common`dropModelUnsupportedParameters[
        Automatic,
        <|
            "Model"      -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>,
            "StopTokens" -> { "[NONE]" },
            "MaxTokens"  -> 250
        |>
    ],
    <|
        "Model"      -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>,
        "StopTokens" -> { "[NONE]" },
        "MaxTokens"  -> 250
    |>,
    SameTest -> MatchQ,
    TestID   -> "DropModelUnsupportedParameters-Automatic-Supported@@Tests/EmulatedStopTokens.wlt:794,1-810,2"
]

(* Shorthand model specifications are resolved with resolveFullModelSpec: *)
VerificationTest[
    Wolfram`Chatbook`Common`dropModelUnsupportedParameters[
        { "OpenAI", "gpt-5" },
        <| "StopTokens" -> { "[NONE]" }, "MaxTokens" -> 250 |>
    ],
    <| "MaxTokens" -> 250 |>,
    SameTest -> MatchQ,
    TestID   -> "DropModelUnsupportedParameters-ShorthandModelSpec@@Tests/EmulatedStopTokens.wlt:813,1-821,2"
]

(* Automatic also works when the config specifies a GPT-5.6 model in shorthand form: *)
VerificationTest[
    Wolfram`Chatbook`Common`dropModelUnsupportedParameters[
        Automatic,
        <| "Model" -> { "OpenAI", "gpt-5.6-terra" }, "StopTokens" -> { "[NONE]" }, "Temperature" -> 0.7 |>
    ],
    <| "Model" -> { "OpenAI", "gpt-5.6-terra" } |>,
    SameTest -> MatchQ,
    TestID   -> "DropModelUnsupportedParameters-Automatic-ShorthandModelSpec@@Tests/EmulatedStopTokens.wlt:824,1-832,2"
]

(* :!CodeAnalysis::EndBlock:: *)
