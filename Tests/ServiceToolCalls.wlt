(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ServiceToolCalls.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ServiceToolCalls.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    (* A tool call as it appears in the response text: *)
    toolCall[ code_String ] :=
        "TOOLCALL: wolfram_language_evaluator\n{\"code\":\"" <> code <> "\"}\nENDARGUMENTS";

    (* A tool call with its result, as appendToolResult writes it: *)
    toolCallWithResult[ code_String, output_String, id_String ] :=
        toolCall @ code <> "\nENDTOOLCALL\nRESULT\n" <> output <> "\nENDRESULT(" <> id <> ")\n\n";

    (* The assistant message for the tool call that is being evaluated, as toolEvaluation creates it: *)
    inTurnMessage[ content_String, code_String, id_String ] := <|
        "Role"         -> "Assistant",
        "Content"      -> content <> toolCall @ code <> "\nENDTOOLCALL",
        "ToolRequest"  -> True,
        "ToolRequests" -> {
            Wolfram`Chatbook`SendChat`Private`insertToolID[
                LLMToolRequest[ "wolfram_language_evaluator", { "code" -> code }, toolCall @ code <> "\nENDTOOLCALL" ],
                id
            ]
        }
    |>;

    $userMessage = <| "Role" -> "User", "Content" -> "Hello" |>;

    prepareMessages[ method_String, messages_List ] :=
        Block[ { Wolfram`Chatbook`$ChatHandlerData = <| |> },
            Wolfram`Chatbook`SendChat`Private`prepareMessagesForLLM[ <| "ToolMethod" -> method |>, messages ]
        ];

    (* Gives { role, content, { { request ID, code } ... }, { { request ID, output } ... } } for each message: *)
    summarize[ messages_List ] := summarize /@ messages;
    summarize[ message_Association ] := {
        message[ "Role" ],
        StringJoin @ message[ "Content" ],
        Cases[
            Lookup[ message, "ToolRequests", { } ],
            HoldPattern @ LLMToolRequest[
                KeyValuePattern @ { "RequestID" -> id_, "ParameterValues" -> { "code" -> code_ } },
                ___
            ] :> { id, code }
        ],
        Cases[
            Lookup[ message, "ToolResponses", { } ],
            HoldPattern @ LLMToolResponse[
                KeyValuePattern @ {
                    "Request" -> HoldPattern @ LLMToolRequest[ KeyValuePattern[ "RequestID" -> id_ ], ___ ],
                    "Output"  -> output_
                },
                ___
            ] :> { id, output }
        ]
    },
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions@@Tests/ServiceToolCalls.wlt:24,1-79,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Service Tool Method*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*In-Turn Tool Calls*)
VerificationTest[
    summarize @ prepareMessages[ "Service", { $userMessage, inTurnMessage[ "Let me compute.\n", "1+1", "id1111111" ] } ],
    {
        { "User"     , "Hello"          , { }                       , { } },
        { "Assistant", "Let me compute.", { { "id1111111", "1+1" } }, { } }
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-InTurn-FirstCall@@Tests/ServiceToolCalls.wlt:88,1-96,2"
]

VerificationTest[
    summarize @ prepareMessages[ "Service", { $userMessage, inTurnMessage[ "", "1+1", "id1111111" ] } ],
    {
        { "User"     , "Hello", { }                       , { } },
        { "Assistant", ""     , { { "id1111111", "1+1" } }, { } }
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-InTurn-FirstCall-NoText@@Tests/ServiceToolCalls.wlt:98,1-106,2"
]

(* Earlier tool calls of the same response are kept with their results: *)
VerificationTest[
    summarize @ prepareMessages[
        "Service",
        {
            $userMessage,
            inTurnMessage[
                "Let me compute.\n" <> toolCallWithResult[ "1+1", "2", "id1111111" ] <> "Now the second.\n",
                "2+2",
                "id2222222"
            ]
        }
    ],
    {
        { "User"     , "Hello"          , { }                       , { }                     },
        { "Assistant", "Let me compute.", { { "id1111111", "1+1" } }, { }                     },
        { "Tool"     , ""               , { }                       , { { "id1111111", "2" } } },
        { "Assistant", "Now the second.", { { "id2222222", "2+2" } }, { }                     }
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-InTurn-SecondCall@@Tests/ServiceToolCalls.wlt:109,1-129,2"
]

VerificationTest[
    summarize @ prepareMessages[
        "Service",
        {
            $userMessage,
            inTurnMessage[
                StringJoin[
                    "Start.\n",
                    toolCallWithResult[ "1+1", "2", "id1111111" ],
                    "Middle.\n",
                    toolCallWithResult[ "2+2", "4", "id2222222" ]
                ],
                "3+3",
                "id3333333"
            ]
        }
    ],
    {
        { "User"     , "Hello"  , { }                       , { }                     },
        { "Assistant", "Start." , { { "id1111111", "1+1" } }, { }                     },
        { "Tool"     , ""       , { }                       , { { "id1111111", "2" } } },
        { "Assistant", "Middle.", { { "id2222222", "2+2" } }, { }                     },
        { "Tool"     , ""       , { }                       , { { "id2222222", "4" } } },
        { "Assistant", ""       , { { "id3333333", "3+3" } }, { }                     }
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-InTurn-ThirdCall@@Tests/ServiceToolCalls.wlt:131,1-158,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Chat History*)
VerificationTest[
    summarize @ prepareMessages[
        "Service",
        {
            $userMessage,
            <|
                "Role"    -> "Assistant",
                "Content" -> StringJoin[
                    "Let me compute.\n",
                    toolCallWithResult[ "1+1", "2", "id1111111" ],
                    "Now the second.\n",
                    toolCallWithResult[ "2+2", "4", "id2222222" ],
                    "Done."
                ]
            |>
        }
    ],
    {
        { "User"     , "Hello"          , { }                       , { }                     },
        { "Assistant", "Let me compute.", { { "id1111111", "1+1" } }, { }                     },
        { "Tool"     , ""               , { }                       , { { "id1111111", "2" } } },
        { "Assistant", "Now the second.", { { "id2222222", "2+2" } }, { }                     },
        { "Tool"     , ""               , { }                       , { { "id2222222", "4" } } },
        { "Assistant", "Done."          , { }                       , { }                     }
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-History@@Tests/ServiceToolCalls.wlt:163,1-190,2"
]

(* A result at the end of the message: *)
VerificationTest[
    summarize @ prepareMessages[
        "Service",
        { <| "Role" -> "Assistant", "Content" -> StringTrim @ toolCallWithResult[ "1+1", "2", "id1111111" ] |> }
    ],
    {
        { "Assistant", "", { { "id1111111", "1+1" } }, { }                     },
        { "Tool"     , "", { }                       , { { "id1111111", "2" } } }
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-History-EndsWithResult@@Tests/ServiceToolCalls.wlt:193,1-204,2"
]

(* Results written without an ID get one from the request: *)
VerificationTest[
    summarize @ prepareMessages[
        "Service",
        { <| "Role" -> "Assistant", "Content" -> toolCall[ "1+1" ] <> "\nENDTOOLCALL\nRESULT\n2\nENDRESULT\n\nDone." |> }
    ],
    {
        { "Assistant", "", { { id_String? (StringLength[ # ] === 9 &), "1+1" } }, { } },
        { "Tool"     , "", { }, { { id_, "2" } } },
        { "Assistant", "Done.", { }, { } }
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-History-NoID@@Tests/ServiceToolCalls.wlt:207,1-219,2"
]

(* 5 character IDs from before 3eee65a8 are replaced, since MistralAI only accepts 9 characters: *)
VerificationTest[
    summarize @ prepareMessages[
        "Service",
        { <| "Role" -> "Assistant", "Content" -> toolCallWithResult[ "1+1", "2", "abcde" ] <> "Done." |> }
    ],
    {
        { "Assistant", "", { { id_String? (StringLength[ # ] === 9 &), "1+1" } }, { } },
        { "Tool"     , "", { }, { { id_, "2" } } },
        { "Assistant", "Done.", { }, { } }
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-History-OldID@@Tests/ServiceToolCalls.wlt:222,1-234,2"
]

(* Splitting 10 tool calls takes about 70 ms. It took about 500 ms when each LLMToolResponse went through the
   LLMFunctions legacy updater: *)
VerificationTest[
    Module[ { messages },
        messages = {
            $userMessage,
            <|
                "Role"    -> "Assistant",
                "Content" -> StringJoin[
                    Table[ toolCallWithResult[ ToString @ i, ToString @ i, StringPadLeft[ ToString @ i, 9, "x" ] ], { i, 10 } ],
                    "Done."
                ]
            |>
        };
        prepareMessages[ "Service", messages ];
        First @ AbsoluteTiming @ prepareMessages[ "Service", messages ]
    ],
    _? (LessThan[ 0.25 ]),
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-History-Timing@@Tests/ServiceToolCalls.wlt:238,1-256,2"
]

(* Earlier tool calls are sent the same way during the response and later in the chat history: *)
VerificationTest[
    Module[ { inTurn, history },
        inTurn = prepareMessages[
            "Service",
            {
                $userMessage,
                inTurnMessage[
                    "Let me compute.\n" <> toolCallWithResult[ "1+1", "2", "id1111111" ] <> "Now the second.\n",
                    "2+2",
                    "id2222222"
                ]
            }
        ];
        history = prepareMessages[
            "Service",
            {
                $userMessage,
                <|
                    "Role"    -> "Assistant",
                    "Content" -> StringJoin[
                        "Let me compute.\n",
                        toolCallWithResult[ "1+1", "2", "id1111111" ],
                        "Now the second.\n",
                        toolCallWithResult[ "2+2", "4", "id2222222" ],
                        "Done."
                    ]
                |>
            }
        ];
        Take[ inTurn, 3 ] === Take[ history, 3 ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-InTurn-Matches-History@@Tests/ServiceToolCalls.wlt:259,1-293,2"
]

(* The IDs are kept until the messages are prepared for the LLM: *)
VerificationTest[
    Wolfram`Chatbook`Common`withChatState @ Module[ { settings, messages },
        settings = Wolfram`Chatbook`Common`resolveAutoSettings @ Wolfram`Chatbook`Common`mergeChatSettings @ {
            Wolfram`Chatbook`Common`$defaultChatSettings,
            <|
                "LLMEvaluator"     -> "PlainChat",
                "Model"            -> <| "Service" -> "OpenAI", "Name" -> "gpt-5-mini" |>,
                "PromptGenerators" -> { }
            |>
        };
        messages = Block[ { $CurrentChatSettings = settings },
            Wolfram`Chatbook`Common`constructMessages[
                settings,
                {
                    $userMessage,
                    <|
                        "Role"    -> "Assistant",
                        "Content" -> "Let me compute.\n" <> toolCallWithResult[ "1+1", "2", "id1111111" ] <> "Done."
                    |>
                }
            ]
        ];
        {
            settings[ "ToolMethod" ],
            DeleteCases[ summarize @ prepareMessages[ "Service", messages ], { "System", ___ } ]
        }
    ],
    {
        "Service",
        {
            { "User"     , "Hello"          , { }                       , { }                     },
            { "Assistant", "Let me compute.", { { "id1111111", "1+1" } }, { }                     },
            { "Tool"     , ""               , { }                       , { { "id1111111", "2" } } },
            { "Assistant", "Done."          , { }                       , { }                     }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-ConstructMessages-KeepsIDs@@Tests/ServiceToolCalls.wlt:296,1-334,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Other Tool Methods*)

(* Other tool methods send tool calls as text, without IDs: *)
VerificationTest[
    prepareMessages[
        "Textual",
        {
            $userMessage,
            <|
                "Role"    -> "Assistant",
                "Content" -> "Let me compute.\n" <> toolCallWithResult[ "1+1", "2", "id1111111" ] <> "Done."
            |>,
            inTurnMessage[ toolCallWithResult[ "2+2", "4", "id2222222" ], "3+3", "id3333333" ]
        }
    ],
    {
        <| "Role" -> "User", "Content" -> "Hello" |>,
        <|
            "Role"    -> "Assistant",
            "Content" -> "Let me compute.\n" <> toolCall[ "1+1" ] <> "\nENDTOOLCALL\nRESULT\n2\nENDRESULT\n\nDone."
        |>,
        <|
            "Role"        -> "Assistant",
            "Content"     -> StringJoin[
                toolCall[ "2+2" ],
                "\nENDTOOLCALL\nRESULT\n4\nENDRESULT\n\n",
                toolCall[ "3+3" ],
                "\nENDTOOLCALL"
            ],
            "ToolRequest" -> True
        |>
    },
    SameTest -> SameQ,
    TestID   -> "OtherToolMethods-RemoveIDs@@Tests/ServiceToolCalls.wlt:341,1-372,2"
]

(* :!CodeAnalysis::EndBlock:: *)
