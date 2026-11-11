(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ClaudeRefusalFallback.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ClaudeRefusalFallback.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Model Settings*)
VerificationTest[
    Wolfram`Chatbook`Models`Private`chooseModelFamily /@ {
        "claude-opus-4-5",
        "claude-opus-4-8",
        "claude-opus-5",
        "claude-opus-5-5",
        "claude-sonnet-5-5",
        "claude-haiku-5-5",
        "claude-fable-5-1",
        "claude-fable-5-2"
    },
    { "Claude4", "ClaudeOpus47Plus", "Claude5", "Claude5", "Claude5", "Claude5", "Claude5", "Claude5" },
    SameTest -> SameQ,
    TestID   -> "ChooseModelFamily-Claude@@Tests/ClaudeRefusalFallback.wlt:24,1-38,2"
]

VerificationTest[
    Table[
        Wolfram`Chatbook`Common`autoModelSetting[ <| "Service" -> "Anthropic", "Name" -> name |>, # ] & /@ {
            "MaxContextTokens",
            "MaxTokens",
            "Multimodal",
            "Temperature",
            "RefusalFallbackModel"
        },
        { name, { "claude-opus-4-8", "claude-sonnet-5-5", "claude-haiku-5-5", "claude-opus-5-5", "claude-fable-5-1", "claude-fable-5-2" } }
    ],
    Join[
        ConstantArray[ { 1000000, 64000, True, Missing[ "NotSupported" ], Except[ _String ] }, 3 ],
        ConstantArray[ { 1000000, 64000, True, Missing[ "NotSupported" ], "claude-opus-4-8" }, 3 ]
    ],
    SameTest -> MatchQ,
    TestID   -> "AutoModelSettings-Claude@@Tests/ClaudeRefusalFallback.wlt:40,1-57,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Refusals*)

(* These run the real chat handlers on simulated streams, since refusals can't be triggered on demand. The chunks have
   the same form as the streamed "message_delta" events from the Anthropic API. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Definitions*)
VerificationTest[
    textChunk[ text_String ] := <|
        "BodyChunk"          -> "event: content_block_delta\ndata: {\"type\":\"content_block_delta\"}\n\n",
        "BodyChunkProcessed" -> { <| "CallID" -> "msg", "ContentChunk" -> text, "Type" -> "Text" |> }
    |>;

    refusalChunk[ category_String ] := <|
        "BodyChunk" -> StringJoin[
            "event: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"refusal\",",
            "\"stop_sequence\":null,\"stop_details\":{\"type\":\"refusal\",\"category\":\"",
            category,
            "\",\"explanation\":\"It was declined.\"},\"container\":null},\"usage\":{\"output_tokens\":0}}\n\n"
        ],
        "BodyChunkProcessed" -> { <| "CallID" -> "msg", "FinishReason" -> "refusal" |> }
    |>;

    (* Sends a chat where the response from each model is given by the association `script`: *)
    simulateChat[ model_String, script_Association, settings_Association: <| |> ] :=
        Module[ { calls = { }, submit },
            submit[ messages_, config_, opts___ ] :=
                Module[ { handlers, name, chunks },
                    handlers = Lookup[ { opts }, HandlerFunctions ];
                    name = config[ "Model" ][ "Name" ];
                    AppendTo[ calls, <| "Model" -> name, "Messages" -> messages |> ];
                    (* A model's script can be a list of chunks for each request: *)
                    chunks = script[ name ];
                    If[ MatchQ[ chunks, { __List } ], chunks = chunks[[ Count[ Lookup[ calls, "Model" ], name ] ]] ];
                    Scan[ handlers[ "BodyChunkReceived" ], chunks ];
                    handlers[ "TaskFinished" ][ <| "TaskStatus" -> "Finished", "EventName" -> "TaskFinished", "StatusCode" -> 200 |> ];
                    None
                ];
            <|
                "Result" -> Wolfram`Chatbook`AgentEvaluate[
                    "Hello",
                    <|
                        "Model"               -> <| "Service" -> "Anthropic", "Name" -> model |>,
                        "LLMEvaluator"        -> "PlainChat",
                        "ToolsEnabled"        -> False,
                        "ProcessingFunctions" -> <| "ChatSubmit" -> submit |>,
                        settings
                    |>
                ],
                "Models"       -> Lookup[ calls, "Model" ],
                "SameMessages" -> Length @ DeleteDuplicates @ Lookup[ calls, "Messages" ] === 1
            |>
        ];

    toolCallChunk[ name_String, args_List ] := <|
        "BodyChunk"          -> "event: content_block_stop\ndata: {\"type\":\"content_block_stop\"}\n\n",
        "BodyChunkProcessed" -> { <| "CallID" -> "msg", "ToolRequestsChunk" -> { LLMToolRequest[ name, args, "RequestID" -> "call_1" ] } |> }
    |>;

    finishChunk[ ] := <|
        "BodyChunk"          -> "event: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"tool_use\"}}\n\n",
        "BodyChunkProcessed" -> { <| "CallID" -> "msg", "FinishReason" -> "tool_use" |> }
    |>;

    $lookupTool = LLMTool[
        { "lookup_value", "Looks up a value." },
        { "name" -> "String" },
        Function[ "The value is 42." ]
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Refusal-Definitions@@Tests/ClaudeRefusalFallback.wlt:69,1-135,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Fallback*)
VerificationTest[
    simulateChat[
        #,
        <| # -> { refusalChunk[ "cyber" ] }, "claude-opus-4-8" -> { textChunk[ "Answer" ] } |>
    ] & /@ { "claude-opus-5-5", "claude-fable-5-1", "claude-fable-5-2" },
    {
        <| "Result" -> "Answer", "Models" -> { "claude-opus-5-5" , "claude-opus-4-8" }, "SameMessages" -> True |>,
        <| "Result" -> "Answer", "Models" -> { "claude-fable-5-1", "claude-opus-4-8" }, "SameMessages" -> True |>,
        <| "Result" -> "Answer", "Models" -> { "claude-fable-5-2", "claude-opus-4-8" }, "SameMessages" -> True |>
    },
    SameTest -> SameQ,
    TestID   -> "Refusal-Cyber-Fallback@@Tests/ClaudeRefusalFallback.wlt:140,1-152,2"
]

(* Partial output from the refused model is discarded: *)
VerificationTest[
    simulateChat[
        "claude-opus-5-5",
        <|
            "claude-opus-5-5" -> { textChunk[ "Partial " ], refusalChunk[ "cyber" ] },
            "claude-opus-4-8" -> { textChunk[ "Answer" ] }
        |>
    ],
    <| "Result" -> "Answer", "Models" -> { "claude-opus-5-5", "claude-opus-4-8" }, "SameMessages" -> True |>,
    SameTest -> SameQ,
    TestID   -> "Refusal-Discards-Partial-Output@@Tests/ClaudeRefusalFallback.wlt:155,1-166,2"
]

(* A raw chunk can contain several events, or only part of an event: *)
VerificationTest[
    simulateChat[
        "claude-opus-5-5",
        <|
            "claude-opus-5-5" -> {
                <|
                    "BodyChunk"          -> StringJoin[
                        "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{}}\n\n",
                        refusalChunk[ "cyber" ][ "BodyChunk" ],
                        "event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n"
                    ],
                    "BodyChunkProcessed" -> refusalChunk[ "cyber" ][ "BodyChunkProcessed" ]
                |>
            },
            "claude-opus-4-8" -> { textChunk[ "Answer" ] }
        |>
    ],
    <| "Result" -> "Answer", "Models" -> { "claude-opus-5-5", "claude-opus-4-8" }, "SameMessages" -> True |>,
    SameTest -> SameQ,
    TestID   -> "Refusal-Multiple-Events-In-Chunk@@Tests/ClaudeRefusalFallback.wlt:169,1-189,2"
]

VerificationTest[
    With[ { raw = refusalChunk[ "cyber" ][ "BodyChunk" ], n = 40 },
        simulateChat[
            "claude-opus-5-5",
            <|
                "claude-opus-5-5" -> {
                    <| "BodyChunk" -> StringTake[ raw, n ], "BodyChunkProcessed" -> { } |>,
                    <|
                        "BodyChunk"          -> StringDrop[ raw, n ],
                        "BodyChunkProcessed" -> refusalChunk[ "cyber" ][ "BodyChunkProcessed" ]
                    |>
                },
                "claude-opus-4-8" -> { textChunk[ "Answer" ] }
            |>
        ]
    ],
    <| "Result" -> "Answer", "Models" -> { "claude-opus-5-5", "claude-opus-4-8" }, "SameMessages" -> True |>,
    SameTest -> SameQ,
    TestID   -> "Refusal-Event-Split-Across-Chunks@@Tests/ClaudeRefusalFallback.wlt:191,1-210,2"
]

(* A refusal after a tool call only discards the refused round, and the rest of the request stays on the fallback: *)
VerificationTest[
    Module[ { result },
        (* Tool evaluation writes the task to the output cell, which doesn't exist here: *)
        result = Quiet[
            simulateChat[
                "claude-opus-5-5",
                <|
                    "claude-opus-5-5" -> {
                        { toolCallChunk[ "lookup_value", { "name" -> "a" } ], finishChunk[ ] },
                        { textChunk[ "Partial " ], refusalChunk[ "cyber" ] }
                    },
                    "claude-opus-4-8" -> {
                        { toolCallChunk[ "lookup_value", { "name" -> "b" } ], finishChunk[ ] },
                        { textChunk[ "Answer" ] }
                    }
                |>,
                <| "ToolsEnabled" -> True, "Tools" -> { $lookupTool } |>
            ],
            { FrontEndObject::notavail, General::stop }
        ];
        <|
            "Models"       -> result[ "Models" ],
            "ToolCalls"    -> StringCount[ result[ "Result" ], "TOOLCALL: lookup_value" ],
            "PartialKept"  -> StringContainsQ[ result[ "Result" ], "Partial" ],
            "EndsAnswered" -> StringEndsQ[ result[ "Result" ], "Answer" ]
        |>
    ],
    <|
        "Models"       -> { "claude-opus-5-5", "claude-opus-5-5", "claude-opus-4-8", "claude-opus-4-8" },
        "ToolCalls"    -> 2,
        "PartialKept"  -> False,
        "EndsAnswered" -> True
    |>,
    SameTest -> SameQ,
    TestID   -> "Refusal-During-Tool-Loop@@Tests/ClaudeRefusalFallback.wlt:213,1-248,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*No Fallback*)

(* Refusals in other categories have no recommended fallback model: *)
VerificationTest[
    simulateChat[ "claude-opus-5-5", <| "claude-opus-5-5" -> { refusalChunk[ "bio" ] } |> ],
    <|
        "Result"       -> "The model declined to respond to this request: It was declined.",
        "Models"       -> { "claude-opus-5-5" },
        "SameMessages" -> True
    |>,
    SameTest -> SameQ,
    TestID   -> "Refusal-Other-Category@@Tests/ClaudeRefusalFallback.wlt:255,1-264,2"
]

(* There's no fallback for the fallback model: *)
VerificationTest[
    simulateChat[
        "claude-opus-5-5",
        <|
            "claude-opus-5-5" -> { refusalChunk[ "cyber" ] },
            "claude-opus-4-8" -> { textChunk[ "Partial " ], refusalChunk[ "cyber" ] }
        |>
    ],
    <|
        "Result"       -> "The model declined to respond to this request: It was declined.",
        "Models"       -> { "claude-opus-5-5", "claude-opus-4-8" },
        "SameMessages" -> True
    |>,
    SameTest -> SameQ,
    TestID   -> "Refusal-Fallback-Also-Refuses@@Tests/ClaudeRefusalFallback.wlt:267,1-282,2"
]

(* The fallback can be disabled: *)
VerificationTest[
    simulateChat[
        "claude-opus-5-5",
        <| "claude-opus-5-5" -> { refusalChunk[ "cyber" ] } |>,
        <| "RefusalFallbackModel" -> None |>
    ],
    <|
        "Result"       -> "The model declined to respond to this request: It was declined.",
        "Models"       -> { "claude-opus-5-5" },
        "SameMessages" -> True
    |>,
    SameTest -> SameQ,
    TestID   -> "Refusal-Fallback-Disabled@@Tests/ClaudeRefusalFallback.wlt:285,1-298,2"
]

(* Normal responses aren't affected: *)
VerificationTest[
    simulateChat[ "claude-opus-5-5", <| "claude-opus-5-5" -> { textChunk[ "Answer" ] } |> ],
    <| "Result" -> "Answer", "Models" -> { "claude-opus-5-5" }, "SameMessages" -> True |>,
    SameTest -> SameQ,
    TestID   -> "Refusal-Normal-Response@@Tests/ClaudeRefusalFallback.wlt:301,1-306,2"
]

(* :!CodeAnalysis::EndBlock:: *)
