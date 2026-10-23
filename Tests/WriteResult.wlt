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
    $codeBlockResponse = StringJoin[
        "Define the matrix with `m = {{2, -1}, {-1, 2}}` first:\n\n",
        "```wl\nm = {{2, -1}, {-1, 2}};\nEigenvalues[m]\n```\n\n",
        "This is what an evaluation looks like:\n\n",
        "```wl\nIn[1]:= Eigenvalues[m]\nOut[1]= {3, 1}\n```\n\n",
        "The same thing in Python:\n\n",
        "```python\nimport numpy as np\nprint(np.linalg.eigvals([[2, -1], [-1, 2]]))\n```\n\n",
        "As JSON:\n\n```json\n{\"matrix\": [[2, -1], [-1, 2]]}\n```\n\n",
        "And as plain text:\n\n```\nlambda = 3, 1\n```\n\n",
        "That's all."
    ];

    $formatSettings = <|
        "AutoFormat" -> True,
        "ToolMethod" -> Automatic,
        "Data"       -> <| "Messages" -> { <| "Role" -> "User", "Content" -> "How do I get eigenvalues?" |> } |>
    |>;

    (* Evaluates `eval` without a front end. Notebook writes are collected in $staticWrites, and the front end parses
       of Wolfram Language code (one per code block, plus any inline code) are counted in $reparseCount: *)
    withoutFrontEnd // Attributes = { HoldFirst };
    withoutFrontEnd[ eval_ ] := Block[
        {
            Wolfram`Chatbook`Formatting`Private`reparseBoxStructurePacket = ($reparseCount++; #1) &,
            Wolfram`Chatbook`Common`usingFrontEnd = Identity,
            Wolfram`Chatbook`$ChatHandlerData = <| "ChatNotebookSettings" -> $formatSettings |>,
            NotebookRead  = Null &,
            NotebookWrite = (Internal`StuffBag[ $staticWrites, #2 ]; Null) &,
            $reparseCount = 0,
            $staticWrites = Internal`Bag[ ]
        },
        eval
    ];

    (* Replicates the static writes that are made while a response streams in, giving the static cells that were
       written and the full response string: *)
    streamResponse[ text_String ] := Module[ { dynamic = None, full = None, split },
        Scan[
            Function[
                dynamic = Wolfram`Chatbook`SendChat`Private`appendStringContent[ dynamic, #1 ];
                full    = Wolfram`Chatbook`SendChat`Private`appendStringContent[ full, #1 ];
                split   = DeleteCases[ StringSplit[ dynamic, Wolfram`Chatbook`Common`$dynamicSplitRules ], "" ];
                If[ Length @ split > 1,
                    Wolfram`Chatbook`SendChat`Private`writeDynamicChunkAsStatic[
                        StringJoin @ Most @ split,
                        BoxObject[ FrontEndObject[ ], 1 ]
                    ];
                    dynamic = Last @ split
                ]
            ],
            StringPartition[ text, UpTo[ 5 ] ]
        ];
        { Internal`BagPart[ $staticWrites, All ], StringTrim @ full }
    ];

    (* The final chat output cell: *)
    finalCell[ text_String ] :=
        Wolfram`Chatbook`SendChat`Private`reformatCell[ $formatSettings, text, Inherited, True, None, Inherited, { }, "id" ];

    (* Evaluates `eval` as if there was no static code block cache: *)
    withoutCodeBlockCache // Attributes = { HoldFirst };
    withoutCodeBlockCache[ eval_ ] := Block[
        {
            Wolfram`Chatbook`Formatting`Private`cachedCodeBlockCell = Function[
                Block[ { Wolfram`Chatbook`Common`$useStaticCodeBlockCache = False },
                    Wolfram`Chatbook`Formatting`Private`makeCodeBlockCell[ #1, #2 ]
                ]
            ]
        },
        eval
    ];

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
(*Static Code Block Cache*)

(* Code blocks are formatted when they're written as static content during streaming, and the final cell reuses that
   formatting instead of doing it again: *)
VerificationTest[
    withoutFrontEnd @ Block[ { Wolfram`Chatbook`Common`$staticCodeBlockCache = <| |> },
        streamResponse @ $codeBlockResponse;
        Keys @ Wolfram`Chatbook`Common`$staticCodeBlockCache
    ],
    {
        { "wl", "m = {{2, -1}, {-1, 2}};\nEigenvalues[m]", False, False, False, False },
        { "wl", "In[1]:= Eigenvalues[m]\nOut[1]= {3, 1}", False, False, False, False },
        { "Python", "import numpy as np\nprint(np.linalg.eigvals([[2, -1], [-1, 2]]))", False, False, False, False },
        { "json", "{\"matrix\": [[2, -1], [-1, 2]]}", False, False, False, False },
        { "", "lambda = 3, 1", False, False, False, False }
    },
    SameTest -> MatchQ,
    TestID   -> "StaticCodeBlockCache-Populated-While-Streaming"
]

VerificationTest[
    withoutFrontEnd @ Block[ { Wolfram`Chatbook`Common`$staticCodeBlockCache = <| |> },
        Module[ { writes, full, cached, uncached, cachedParses, uncachedParses, sizes },
            { writes, full } = streamResponse @ $codeBlockResponse;
            sizes = { Length @ Wolfram`Chatbook`Common`$staticCodeBlockCache };
            $reparseCount = 0;
            cached = finalCell @ full;
            cachedParses = $reparseCount;
            AppendTo[ sizes, Length @ Wolfram`Chatbook`Common`$staticCodeBlockCache ];
            $reparseCount = 0;
            uncached = withoutCodeBlockCache @ finalCell @ full;
            uncachedParses = $reparseCount;
            {
                sizes,
                cached === uncached,
                (* The three Wolfram Language code parses are skipped for the final cell: *)
                uncachedParses - cachedParses,
                Count[ cached, Cell[ _, "ChatCodeBlock", ___ ], Infinity ],
                FreeQ[ cached, _Missing | _Failure | $Failed ]
            }
        ]
    ],
    { { 5, 5 }, True, 3, 5, True },
    SameTest -> MatchQ,
    TestID   -> "StaticCodeBlockCache-Final-Cell-Identical"
]

VerificationTest[
    withoutFrontEnd @ Module[ { cachedWrites, uncachedWrites },
        Block[ { Wolfram`Chatbook`Common`$staticCodeBlockCache = <| |> },
            streamResponse @ $codeBlockResponse;
            $staticWrites = Internal`Bag[ ];
            (* All code blocks are now cached: *)
            cachedWrites = First @ streamResponse @ $codeBlockResponse
        ];
        $staticWrites = Internal`Bag[ ];
        uncachedWrites = withoutCodeBlockCache @ First @ streamResponse @ $codeBlockResponse;
        { Length @ cachedWrites, cachedWrites === uncachedWrites }
    ],
    { 5, True },
    SameTest -> MatchQ,
    TestID   -> "StaticCodeBlockCache-Static-Writes-Identical"
]

(* The cache is only used for chat output, so other formatting is unaffected: *)
VerificationTest[
    withoutFrontEnd @ Block[ { Wolfram`Chatbook`Common`$staticCodeBlockCache = <| |> },
        FormatChatOutput @ $codeBlockResponse;
        FormatChatOutput[ $codeBlockResponse, <| "Status" -> "Streaming" |> ];
        Wolfram`Chatbook`Common`$staticCodeBlockCache
    ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "StaticCodeBlockCache-Unused-Elsewhere"
]

VerificationTest[
    withoutFrontEnd @ Block[
        {
            Wolfram`Chatbook`Common`$staticCodeBlockCache    = <| |>,
            Wolfram`Chatbook`Common`$useStaticCodeBlockCache = True
        },
        Module[ { notebook, sidebar },
            notebook = Block[ { $SidebarChat = False }, FormatChatOutput[ "```python\nprint(1)\n```" ] ];
            sidebar  = Block[ { $SidebarChat = True  }, FormatChatOutput[ "```python\nprint(1)\n```" ] ];
            {
                Length @ Wolfram`Chatbook`Common`$staticCodeBlockCache,
                Cases[ notebook, TemplateBox[ _, name_String ] :> name, Infinity ],
                Cases[ sidebar, TemplateBox[ _, name_String ] :> name, Infinity ]
            }
        ]
    ],
    { 2, { "ChatCodeBlockTemplate" }, { "NotebookAssistant`Sidebar`ChatCodeBlockTemplate" } },
    SameTest -> MatchQ,
    TestID   -> "StaticCodeBlockCache-Separate-Chat-Modes"
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
