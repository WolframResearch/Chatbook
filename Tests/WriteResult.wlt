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
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    (* Debug log entries as they're received from a server: *)
    contentChunk[ text_String ] := <|
        "BodyChunk"          -> "data: "<>Developer`WriteRawJSONString[ <| "choices" -> { <| "delta" -> <| "content" -> text |> |> } |>, "Compact" -> True ]<>"\n\n",
        "BodyChunkProcessed" -> { <| "ContentChunk" -> text |> },
        "EventName"          -> "BodyChunkReceived"
    |>;

    rawChunk[ body_String ] := <| "BodyChunk" -> body, "BodyChunkProcessed" -> { }, "EventName" -> "BodyChunkReceived" |>;

    $taskFinished = <| "EventName" -> "TaskFinished", "TaskStatus" -> "Finished" |>;

    (* Runs writeResult on a debug log and gives what it wrote to the chat output cell along with the debug data: *)
    responseResult[ log_List, status_ ] := Module[ { container = <| "FullContent" -> "", "DynamicContent" -> "" |>, result },
        Block[
            {
                Wolfram`Chatbook`SendChat`Private`$debugLog              = Internal`Bag @ log,
                Wolfram`Chatbook`SendChat`Private`$lastFullResponseData  = None,
                Wolfram`Chatbook`SendChat`Private`$badResponse           = None,
                Wolfram`Chatbook`SendChat`Private`writeErrorCell         = (result = { "Error", #2 }; Null) &,
                Wolfram`Chatbook`Common`writeReformattedCell             = (result = "Reformatted"; Null) &,
                Wolfram`Chatbook`$AutomaticAssistance                    = False,
                Wolfram`Chatbook`$ChatNotebookEvaluation                 = True
            },
            Wolfram`Chatbook`SendChat`Private`writeResult[
                <| "BypassResponseChecking" -> False |>,
                Unevaluated @ container,
                CellObject[ 1 ],
                <| "StatusCode" -> status |>
            ];
            { result, Wolfram`Chatbook`SendChat`Private`$lastFullResponseData }
        ]
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Response Checking*)
VerificationTest[
    responseResult[ { contentChunk[ "Hello" ], contentChunk[ " world" ], $taskFinished }, 200 ],
    {
        "Reformatted",
        <|
            "Body"      -> StringJoin[
                "data: {\"choices\":[{\"delta\":{\"content\":\"Hello\"}}]}\n\n",
                "data: {\"choices\":[{\"delta\":{\"content\":\" world\"}}]}\n\n"
            ],
            "Processed" -> "Hello world",
            "Data"      -> Missing[ "NotAvailable" ]
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "WriteResult-Normal-Response"
]

VerificationTest[
    responseResult[ { $taskFinished }, 200 ],
    { { "Error", KeyValuePattern @ { "StatusCode" -> 200, "Error" -> "ServerResponseEmpty" } }, _ },
    SameTest -> MatchQ,
    TestID   -> "WriteResult-Empty-Response"
]

VerificationTest[
    responseResult[ { rawChunk[ "{\"error\": {\"message\": \"Invalid API key\"}}" ], $taskFinished }, 200 ],
    {
        {
            "Error",
            KeyValuePattern @ {
                "Body"     -> "{\"error\": {\"message\": \"Invalid API key\"}}",
                "BodyJSON" -> <| "error" -> <| "message" -> "Invalid API key" |> |>
            }
        },
        _
    },
    SameTest -> MatchQ,
    TestID   -> "WriteResult-Error-JSON"
]

VerificationTest[
    responseResult[
        { rawChunk[ "{\"error\": {\"message\": " ], rawChunk[ "\"Invalid API key\"}}" ], $taskFinished },
        200
    ],
    {
        {
            "Error",
            KeyValuePattern @ {
                "Body"     -> "{\"error\": {\"message\": \"Invalid API key\"}}",
                "BodyJSON" -> <| "error" -> <| "message" -> "Invalid API key" |> |>
            }
        },
        _
    },
    SameTest -> MatchQ,
    TestID   -> "WriteResult-Error-JSON-Split-Chunks"
]

VerificationTest[
    responseResult[
        { rawChunk[ "data: {\"error\": {\"message\": \"Rate limit exceeded\"}}\n\n" ], $taskFinished },
        200
    ],
    {
        {
            "Error",
            KeyValuePattern @ {
                "Body"     -> "{\"error\": {\"message\": \"Rate limit exceeded\"}}",
                "BodyJSON" -> <| "error" -> <| "message" -> "Rate limit exceeded" |> |>
            }
        },
        _
    },
    SameTest -> MatchQ,
    TestID   -> "WriteResult-Error-Event-Stream"
]

VerificationTest[
    responseResult[
        {
            rawChunk[ "<html><head><title>502 Bad Gateway</title></head>" ],
            rawChunk[ "<body><h1>502 Bad Gateway</h1></body></html>" ],
            $taskFinished
        },
        502
    ],
    {
        {
            "Error",
            KeyValuePattern @ {
                "StatusCode" -> 502,
                "Body"       -> "<html><head><title>502 Bad Gateway</title></head><body><h1>502 Bad Gateway</h1></body></html>"
            }
        },
        KeyValuePattern[ "Processed" -> "" ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteResult-Error-HTML"
]

VerificationTest[
    responseResult[
        {
            rawChunk[ "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" ],
            rawChunk[ "<Error><Code>AccessDenied</Code><Message>Access Denied</Message></Error>" ],
            $taskFinished
        },
        403
    ],
    {
        {
            "Error",
            KeyValuePattern @ {
                "StatusCode" -> 403,
                "Body"       -> "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<Error><Code>AccessDenied</Code><Message>Access Denied</Message></Error>"
            }
        },
        KeyValuePattern[ "Processed" -> "" ]
    },
    SameTest -> MatchQ,
    TestID   -> "WriteResult-Error-XML"
]

(* A body without content that parses as XML data is an error even if the status code is OK: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`SendChat`Private`parseXMLResponse = <| "message" -> "502 Bad Gateway" |> & },
        responseResult[ { rawChunk[ "<html><body><h1>502 Bad Gateway</h1></body></html>" ], $taskFinished }, 200 ]
    ],
    {
        {
            "Error",
            KeyValuePattern @ {
                "Body"     -> "<html><body><h1>502 Bad Gateway</h1></body></html>",
                "BodyJSON" -> <| "message" -> "502 Bad Gateway" |>
            }
        },
        _
    },
    SameTest -> MatchQ,
    TestID   -> "WriteResult-Error-Parsed-XML"
]

(* A response with content is still an error if the status code is not OK: *)
VerificationTest[
    responseResult[ { contentChunk[ "Partial" ], rawChunk[ "{\"error\": \"Server error\"}" ], $taskFinished }, # ] & /@
        { 401, 500 },
    ConstantArray[
        {
            {
                "Error",
                KeyValuePattern @ {
                    "StatusCode" -> _Integer,
                    "Body"       -> "{\"error\": \"Server error\"}",
                    "BodyJSON"   -> <| "error" -> "Server error" |>
                }
            },
            KeyValuePattern[ "Processed" -> "Partial" ]
        },
        2
    ],
    SameTest -> MatchQ,
    TestID   -> "WriteResult-Error-Status-Code"
]

(* :!CodeAnalysis::EndBlock:: *)
