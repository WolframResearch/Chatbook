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
(*Definitions*)
VerificationTest[
    $gpt61Model     = <| "Service" -> "OpenAI", "Name" -> "gpt-6.1-sol" |>;
    $customSettings = <| "Model" -> $gpt61Model, "RequestMethod" -> "Responses", "ToolMethod" -> "Service" |>;
    $chatSettings   = <| $customSettings, "RequestMethod" -> "ChatCompletions" |>;
    $evaluatorTool  = $DefaultTools[ "WolframLanguageEvaluator" ];
    $notebookTool   = $DefaultTools[ "CreateNotebook" ];
    $otherTool      = $DefaultTools[ "WolframAlpha" ];
    $description    = StringTrim @ $evaluatorTool[ "Description" ];
    $evaluatorHelp  = Lookup[ $evaluatorTool[ "Parameters" ], "code" ][ "Help" ];

    (* The released LLMFunctions (2.3) rejects tools and tool requests that take plain text, so the conversions are
       tested on inert expressions, and the results are reduced to their data before leaving the Block: *)
    SetAttributes[ withCustomTools, HoldFirst ];
    withCustomTools[ eval_ ] := Block[
        {
            Wolfram`Chatbook`Common`$responsesAPIAvailable = True,
            Wolfram`Chatbook`Tools`Private`$customToolCache = <| |>,
            LLMTool, LLMToolRequest, LLMToolResponse
        },
        eval //. {
            HoldPattern[ LLMToolResponse ][ as_Association, ___ ] :> "Response"[ as ],
            HoldPattern[ LLMToolRequest  ][ as_Association, ___ ] :> "Request"[ as ],
            HoldPattern[ LLMTool         ][ as_Association, ___ ] :> "Tool"[ KeyTake[ as, { "Name", "Parameters" } ] ]
        }
    ];

    customRequest[ name_String, input_ ] :=
        LLMToolRequest @ <| "Name" -> name, "ParameterValues" -> input, "RequestID" -> "call_1" |>;

    { $evaluatorTool, $notebookTool, $otherTool },
    { _LLMTool, _LLMTool, _LLMTool },
    SameTest -> MatchQ,
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Definitions*)

(* The parameter that gets the input of each custom tool has to be the tool's only parameter: *)
VerificationTest[
    KeyValueMap[
        Keys @ $DefaultTools[ #1 ][ "Parameters" ] === { #2 } &,
        Wolfram`Chatbook`Tools`Private`$customToolParameters
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "CustomToolParameters-MatchToolDefinitions"
]

VerificationTest[
    withCustomTools @ Wolfram`Chatbook`Common`toCustomTools[
        $customSettings,
        { $evaluatorTool, $notebookTool, $otherTool }
    ],
    {
        "Tool"[ <| "Name" -> "wolfram_language_evaluator", "Parameters" -> None |> ],
        "Tool"[ <| "Name" -> "create_notebook", "Parameters" -> None |> ],
        "Tool"[ <| "Name" -> "wolfram_alpha", "Parameters" -> { __Rule } |> ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToCustomTools"
]

(* A custom tool has no parameter schema, so the tool description needs to say what the input is: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$responsesAPIAvailable = True,
            Wolfram`Chatbook`Tools`Private`$customToolCache = <| |>,
            LLMTool
        },
        Replace[
            Wolfram`Chatbook`Common`toCustomTools[ $customSettings, { $evaluatorTool } ],
            { HoldPattern[ LLMTool ][ as_Association, ___ ] } :> {
                StringStartsQ[ as[ "Description" ], $description ],
                StringEndsQ[ as[ "Description" ], $evaluatorHelp ]
            }
        ]
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "ToCustomTools-Description"
]

(* The converted tool is kept for the next request. A tool that has changed (e.g. a persona's version of it) must not
   get the conversion of the previous one, and the kept tools must not pile up: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$responsesAPIAvailable = True,
            Wolfram`Chatbook`Tools`Private`$customToolCache = <| |>,
            LLMTool
        },
        Module[ { tool, description },
            tool[ text_String ] := LLMTool @ <|
                "Name"        -> "wolfram_language_evaluator",
                "Description" -> text,
                "Parameters"  -> { "code" -> <| "Help" -> "Code" |> }
            |>;

            description[ text_String ] := Replace[
                Wolfram`Chatbook`Common`toCustomTools[ $customSettings, { tool @ text } ],
                { HoldPattern[ LLMTool ][ as_Association, ___ ] } :> StringDelete[ as[ "Description" ], "\n" ~~ ___ ]
            ];

            {
                description /@ { "One", "Two", "One", "One" },
                Keys @ Wolfram`Chatbook`Tools`Private`$customToolCache,
                (* The kept tool is what the next request gets (shown here by replacing it), if the tool is the same: *)
                Wolfram`Chatbook`Tools`Private`$customToolCache =
                    { First @ #, "kept" } & /@ Wolfram`Chatbook`Tools`Private`$customToolCache;
                Replace[
                    Wolfram`Chatbook`Common`toCustomTools[ $customSettings, { tool @ "One", tool @ "Two" } ],
                    HoldPattern[ LLMTool ][ as_Association, ___ ] :> StringDelete[ as[ "Description" ], "\n" ~~ ___ ],
                    { 1 }
                ]
            }
        ]
    ],
    {
        { "One", "Two", "One", "One" },
        { "wolfram_language_evaluator" },
        { "kept", "Two" }
    },
    SameTest -> MatchQ,
    TestID   -> "ToCustomTools-Cache"
]

(* The original parameter schema is used when the request doesn't go to the responses endpoint, when the installed
   paclets don't support it (the request method then resolves to chat completions), and for models that don't enable
   custom tools: *)
VerificationTest[
    With[ { tools = { $evaluatorTool, $notebookTool, $otherTool } },
        {
            Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True },
                Wolfram`Chatbook`Common`toCustomTools[ $chatSettings, tools ] === tools
            ],
            Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = False },
                Wolfram`Chatbook`Common`toCustomTools[
                    <|
                        $customSettings,
                        "RequestMethod" -> Wolfram`Chatbook`Settings`Private`resolveAutoSetting0[
                            <| "Model" -> $gpt61Model |>,
                            "RequestMethod"
                        ]
                    |>,
                    tools
                ] === tools
            ],
            Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True },
                Wolfram`Chatbook`Common`toCustomTools[
                    <| $customSettings, "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.4" |> |>,
                    tools
                ] === tools
            ],
            (* Settings that ask for the responses endpoint although the paclets don't support it. That is an error
               when the request is sent, but not here (e.g. for GenerateLLMConfiguration, which sends nothing): *)
            Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = False },
                Wolfram`Chatbook`Common`toCustomTools[ $customSettings, tools ] === tools
            ]
        }
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ToCustomTools-OriginalSchema"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Calls*)

(* A custom tool call gives its input as a string, which becomes the value of the tool's parameter (without the
   newline that the input usually ends with): *)
VerificationTest[
    withCustomTools @ {
        Wolfram`Chatbook`Common`fromCustomToolRequest @ customRequest[ "wolfram_language_evaluator", "Plot[x, {x, 0, 1}]\n" ],
        Wolfram`Chatbook`Common`fromCustomToolRequest @ customRequest[ "create_notebook", "# Title\n\nText" ],
        (* Not custom tools: *)
        Wolfram`Chatbook`Common`fromCustomToolRequest @ customRequest[ "wolfram_alpha", "pi" ],
        Wolfram`Chatbook`Common`fromCustomToolRequest @ customRequest[ "wolfram_language_evaluator", { "code" -> "1 + 1" } ]
    },
    {
        "Request"[ KeyValuePattern[ "ParameterValues" -> { "code" -> "Plot[x, {x, 0, 1}]" } ] ],
        "Request"[ KeyValuePattern[ "ParameterValues" -> { "content" -> "# Title\n\nText" } ] ],
        "Request"[ KeyValuePattern[ "ParameterValues" -> "pi" ] ],
        "Request"[ KeyValuePattern[ "ParameterValues" -> { "code" -> "1 + 1" } ] ]
    },
    SameTest -> MatchQ,
    TestID   -> "FromCustomToolRequest"
]

(* Tool calls in the chat history are sent as custom tool calls, along with the requests of their responses: *)
VerificationTest[
    withCustomTools @ Wolfram`Chatbook`Common`toCustomToolCalls[
        $customSettings,
        {
            <| "Role" -> "Assistant", "Content" -> { }, "ToolRequests" -> {
                customRequest[ "wolfram_language_evaluator", { "code" -> "1 + 1" } ]
            } |>,
            <| "Role" -> "Tool", "Content" -> { }, "ToolResponses" -> {
                LLMToolResponse @ <|
                    "Request" -> customRequest[ "wolfram_language_evaluator", <| "code" -> "1 + 1" |> ],
                    "Output"  -> "2"
                |>
            } |>,
            <| "Role" -> "Assistant", "Content" -> { }, "ToolRequests" -> {
                customRequest[ "wolfram_alpha", { "query" -> "pi" } ]
            } |>
        }
    ],
    {
        KeyValuePattern[ "ToolRequests" -> { "Request"[ KeyValuePattern[ "ParameterValues" -> "1 + 1" ] ] } ],
        KeyValuePattern[ "ToolResponses" -> {
            "Response"[ KeyValuePattern @ {
                "Request" -> "Request"[ KeyValuePattern[ "ParameterValues" -> "1 + 1" ] ],
                "Output"  -> "2"
            } ]
        } ],
        KeyValuePattern[ "ToolRequests" -> { "Request"[ KeyValuePattern[ "ParameterValues" -> { "query" -> "pi" } ] ] } ]
    },
    SameTest -> MatchQ,
    TestID   -> "ToCustomToolCalls"
]

VerificationTest[
    With[
        {
            messages = {
                <|
                    "Role"         -> "Assistant",
                    "Content"      -> { },
                    "ToolRequests" -> { LLMToolRequest[ "wolfram_language_evaluator", { "code" -> "1 + 1" } ] }
                |>
            }
        },
        Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True },
            Wolfram`Chatbook`Common`toCustomToolCalls[ $chatSettings, messages ] === messages
        ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ToCustomToolCalls-OriginalSchema"
]

(* The data of a tool call that is read from the text of an earlier message is converted before its request is
   created: *)
VerificationTest[
    With[
        {
            call = <|
                "Name"            -> "wolfram_language_evaluator",
                "ParameterValues" -> { "code" -> "1 + 1" },
                "RequestID"       -> "id1111111"
            |>
        },
        Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True },
            {
                Wolfram`Chatbook`Common`toCustomToolCallData[ $customSettings, call ],
                (* Not the responses endpoint: *)
                Wolfram`Chatbook`Common`toCustomToolCallData[ $chatSettings, call ] === call,
                (* Not a custom tool: *)
                Wolfram`Chatbook`Common`toCustomToolCallData[
                    $customSettings,
                    <| call, "Name" -> "wolfram_alpha", "ParameterValues" -> { "query" -> "pi" } |>
                ][ "ParameterValues" ]
            }
        ]
    ],
    {
        <| "Name" -> "wolfram_language_evaluator", "ParameterValues" -> "1 + 1", "RequestID" -> "id1111111" |>,
        True,
        { "query" -> "pi" }
    },
    SameTest -> MatchQ,
    TestID   -> "ToCustomToolCallData"
]

(* A tool call in an earlier message, as it is sent with the next request: as a custom tool call to the responses
   endpoint, and in its original form for chat completions (the objects of earlier calls are kept between requests,
   so the second one must not get those of the first). With the released paclets, both requests are for chat
   completions: *)
VerificationTest[
    Module[ { sent },
        sent[ settings_ ] := Module[ { messages },
            messages = Block[ { $ChatHandlerData = <| |> },
                Wolfram`Chatbook`SendChat`Private`prepareMessagesForLLM0[
                    settings,
                    {
                        <| "Role" -> "User", "Content" -> "Hello" |>,
                        <|
                            "Role"    -> "Assistant",
                            "Content" -> StringJoin[
                                "TOOLCALL: wolfram_language_evaluator\n{\"code\":\"1 + 1\"}\nENDARGUMENTS\nENDTOOLCALL\n",
                                "RESULT\nOut[1]= 2\nENDRESULT(id1111111)\n\nDone"
                            ]
                        |>
                    }
                ]
            ];
            {
                Cases[
                    Flatten @ Lookup[ messages, "ToolRequests", { } ],
                    request_LLMToolRequest :> { request[ "RequestID" ], Normal @ request[ "ParameterValues" ] }
                ],
                Cases[
                    Flatten @ Lookup[ messages, "ToolResponses", { } ],
                    response_LLMToolResponse :> {
                        response[ "Request" ][ "RequestID" ],
                        Normal @ response[ "Request" ][ "ParameterValues" ],
                        response[ "InterpretedParameterValues" ],
                        response[ "Output" ]
                    }
                ]
            }
        ];
        {
            sent @ If[ TrueQ @ Wolfram`Chatbook`Common`$responsesAPIAvailable, $customSettings, $chatSettings ],
            sent @ $chatSettings
        }
    ],
    With[
        {
            original = {
                { { "id1111111", { "code" -> "1 + 1" } } },
                { { "id1111111", { "code" -> "1 + 1" }, <| "code" -> "1 + 1" |>, "Out[1]= 2" } }
            }
        },
        If[ TrueQ @ Wolfram`Chatbook`Common`$responsesAPIAvailable,
            { { { { "id1111111", "1 + 1" } }, { { "id1111111", "1 + 1", "1 + 1", "Out[1]= 2" } } }, original },
            { original, original }
        ]
    ],
    SameTest -> MatchQ,
    TestID   -> "CustomToolCall-History"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompts*)

(* Tool call examples in the system prompt show plain text input for custom tools: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True },
        {
            Block[ { $ChatHandlerData = <| "ChatNotebookSettings" -> $customSettings |> },
                Wolfram`Chatbook`Common`formatToolCallExample[ "WolframLanguageEvaluator", <| "code" -> "Plot[x, {x, 0, 1}]" |> ]
            ],
            Block[ { $ChatHandlerData = <| "ChatNotebookSettings" -> $chatSettings |> },
                Wolfram`Chatbook`Common`formatToolCallExample[ "WolframLanguageEvaluator", <| "code" -> "Plot[x, {x, 0, 1}]" |> ]
            ],
            Block[ { $ChatHandlerData = <| "ChatNotebookSettings" -> $customSettings |> },
                Wolfram`Chatbook`Common`formatToolCallExample[ "WolframAlpha", <| "query" -> "pi" |> ]
            ]
        }
    ],
    {
        "TOOLCALL: wolfram_language_evaluator\nPlot[x, {x, 0, 1}]",
        _String? (StringMatchQ[ "TOOLCALL: wolfram_language_evaluator\n{" ~~ ___ ~~ "\"code\":" ~~ ___ ~~ "}" ]),
        _String? (StringMatchQ[ "TOOLCALL: wolfram_alpha\n{" ~~ ___ ~~ "\"query\":" ~~ ___ ~~ "}" ])
    },
    SameTest -> MatchQ,
    TestID   -> "FormatToolCallExample"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat*)

(* A chat with a call of one of the custom tools, with the service replaced by a script. If the installed LLMFunctions
   and LLMConnections have the responses endpoint, the tool is given as a custom tool and its call arrives as plain
   text. Otherwise (e.g. with the released paclets), the request is for chat completions with the original schema: *)
VerificationTest[
    Module[ { custom, calls = { }, tool, request, submit, chunks, result },
        custom = TrueQ @ Wolfram`Chatbook`Common`$responsesAPIAvailable;

        tool = LLMTool[
            <|
                "Name"        -> "wolfram_language_evaluator",
                "Description" -> "Evaluates code.",
                "Parameters"  -> { "code" -> <| "Interpreter" -> "String", "Help" -> "The code", "Required" -> True |> },
                "Function"    -> Function[ "Out[1]= 2" ]
            |>
        ];

        request = LLMToolRequest[
            "wolfram_language_evaluator",
            If[ custom, "1 + 1\n", { "code" -> "1 + 1" } ],
            "RequestID" -> "call_1"
        ];

        chunks = {
            {
                <| "BodyChunkProcessed" -> { <| "ResponseID" -> "resp_1", "ToolRequestsChunk" -> { request } |> } |>,
                <| "BodyChunkProcessed" -> { <| "ResponseID" -> "resp_1", "FinishReason" -> "completed" |> } |>
            },
            {
                <| "BodyChunkProcessed" -> { <| "ResponseID" -> "resp_2", "ContentChunk" -> "Done", "Type" -> "Text" |> } |>,
                <| "BodyChunkProcessed" -> { <| "ResponseID" -> "resp_2", "FinishReason" -> "completed" |> } |>
            }
        };

        submit[ messages_, config_, opts___ ] :=
            Module[ { handlers },
                handlers = Lookup[ { opts }, HandlerFunctions ];
                AppendTo[ calls, <| "Messages" -> messages, "Tools" -> config[ "Tools" ] |> ];
                Scan[ handlers[ "BodyChunkReceived" ], chunks[[ Length @ calls ]] ];
                handlers[ "TaskFinished" ][ <| "TaskStatus" -> "Finished", "EventName" -> "TaskFinished", "StatusCode" -> 200 |> ];
                None
            ];

        (* Tool evaluation writes the task to the output cell, which doesn't exist here. A tool that is given in the
           settings stays in the tool box for the session, where this one would replace the real evaluator for the
           tests that follow: *)
        result = Quiet[
            Internal`InheritedBlock[ { Wolfram`Chatbook`Tools`Private`$toolBox },
                Wolfram`Chatbook`AgentEvaluate[
                    "Hello",
                    <|
                        "Model"               -> $gpt61Model,
                        "Authentication"      -> Automatic,
                        "LLMEvaluator"        -> "PlainChat",
                        "ToolsEnabled"        -> True,
                        "Tools"               -> { tool },
                        "ProcessingFunctions" -> <| "ChatSubmit" -> submit |>
                    |>
                ]
            ],
            { FrontEndObject::notavail, General::stop }
        ];

        <|
            (* How the tool is given to the service: *)
            "Declared" -> SelectFirst[
                First[ calls ][ "Tools" ],
                #[ "Name" ] === "wolfram_language_evaluator" &
            ][ "Parameters" ],
            (* The response has the call in the same form in both cases: *)
            "Result"   -> StringQ @ result && StringContainsQ[
                result,
                "TOOLCALL: wolfram_language_evaluator" ~~ ___ ~~ "\"code\":\"1 + 1\"" ~~ ___ ~~ "Out[1]= 2" ~~ ___ ~~ "Done"
            ],
            (* The call and its output in the request that follows the tool call: *)
            "Sent"     -> With[ { messages = Last[ calls ][ "Messages" ] },
                {
                    Cases[
                        Flatten @ Lookup[ messages, "ToolRequests", { } ],
                        toolRequest_LLMToolRequest :> Normal @ toolRequest[ "ParameterValues" ]
                    ],
                    Cases[
                        Flatten @ Lookup[ messages, "ToolResponses", { } ],
                        toolResponse_LLMToolResponse :> Normal @ toolResponse[ "Request" ][ "ParameterValues" ]
                    ]
                }
            ]
        |>
    ],
    If[ TrueQ @ Wolfram`Chatbook`Common`$responsesAPIAvailable,
        <| "Declared" -> None, "Result" -> True, "Sent" -> { { "1 + 1" }, { "1 + 1" } } |>,
        <|
            "Declared" -> { __Rule },
            "Result"   -> True,
            "Sent"     -> { { { "code" -> "1 + 1" } }, { { "code" -> "1 + 1" } } }
        |>
    ],
    SameTest -> MatchQ,
    TestID   -> "CustomToolCall-Chat"
]

(* :!CodeAnalysis::EndBlock:: *)
