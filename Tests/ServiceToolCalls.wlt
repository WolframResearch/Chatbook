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
    TestID   -> "Definitions"
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
    TestID   -> "ServiceToolCalls-InTurn-FirstCall"
]

VerificationTest[
    summarize @ prepareMessages[ "Service", { $userMessage, inTurnMessage[ "", "1+1", "id1111111" ] } ],
    {
        { "User"     , "Hello", { }                       , { } },
        { "Assistant", ""     , { { "id1111111", "1+1" } }, { } }
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-InTurn-FirstCall-NoText"
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
    TestID   -> "ServiceToolCalls-InTurn-SecondCall"
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
    TestID   -> "ServiceToolCalls-InTurn-ThirdCall"
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
    TestID   -> "ServiceToolCalls-History"
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
    TestID   -> "ServiceToolCalls-History-EndsWithResult"
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
    TestID   -> "ServiceToolCalls-History-NoID"
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
    TestID   -> "ServiceToolCalls-History-OldID"
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
        (* Without the objects that the first call kept: *)
        Block[ { Wolfram`Chatbook`SendChat`Private`$toolStringSplitCache = <| |> },
            First @ AbsoluteTiming @ prepareMessages[ "Service", messages ]
        ]
    ],
    _? (LessThan[ 0.25 ]),
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-History-Timing"
]

(* Every request needs the tool calls of all earlier messages, so their objects are kept. A repeated request with 10
   tool calls takes about 4 ms, against about 100 ms for the first one. It would take about 45 ms if special characters
   were replaced after the objects are created (the description of the evaluator tool has one, and each response has
   the tool), and more if the objects were not kept or the unchanged ones were created again: *)
VerificationTest[
    Module[ { settings, messages, prepare, first, repeated },
        settings = <| "ToolMethod" -> "Service", "ReplaceUnicodeCharacters" -> True |>;
        messages = {
            $userMessage,
            <|
                "Role"    -> "Assistant",
                "Content" -> StringJoin[
                    Table[ toolCallWithResult[ ToString @ i, ToString @ i, StringPadLeft[ ToString @ i, 9, "y" ] ], { i, 10 } ],
                    "Done."
                ]
            |>
        };
        prepare[ ] := Block[ { Wolfram`Chatbook`$ChatHandlerData = <| |> },
            Wolfram`Chatbook`SendChat`Private`prepareMessagesForLLM[ settings, messages ]
        ];
        prepare[ ];
        (* The time without the kept objects, and the best of three with them: *)
        first = Block[ { Wolfram`Chatbook`SendChat`Private`$toolStringSplitCache = <| |> },
            First @ AbsoluteTiming @ prepare[ ]
        ];
        repeated = Min @ Table[ First @ AbsoluteTiming @ prepare[ ], 3 ];
        { repeated < first / 5, Count[ prepare[ ], KeyValuePattern[ "ToolResponses" -> { _ } ] ] }
    ],
    { True, 10 },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-History-Timing-Repeated"
]

(* The kept objects are what the next request gets (shown here by replacing them), and only as many are kept as the
   cache allows: *)
VerificationTest[
    Module[ { messages },
        messages = {
            <|
                "Role"    -> "Assistant",
                "Content" -> StringJoin @ Table[
                    toolCallWithResult[ ToString @ i, ToString @ i, StringPadLeft[ ToString @ i, 9, "z" ] ],
                    { i, 5 }
                ]
            |>
        };
        {
            Block[ { Wolfram`Chatbook`SendChat`Private`$toolStringSplitCache = <| |> },
                prepareMessages[ "Service", messages ];
                Wolfram`Chatbook`SendChat`Private`$toolStringSplitCache =
                    { "kept" } & /@ Wolfram`Chatbook`SendChat`Private`$toolStringSplitCache;
                {
                    Length @ Wolfram`Chatbook`SendChat`Private`$toolStringSplitCache,
                    summarize @ prepareMessages[ "Service", messages ]
                }
            ],
            Block[
                {
                    Wolfram`Chatbook`SendChat`Private`$toolStringSplitCache     = <| |>,
                    Wolfram`Chatbook`SendChat`Private`$toolStringSplitCacheSize = 3
                },
                {
                    Length @ Cases[ summarize @ prepareMessages[ "Service", messages ], { "Tool", "", { }, { { _, _ } } } ],
                    Length @ Wolfram`Chatbook`SendChat`Private`$toolStringSplitCache
                }
            ]
        }
    ],
    {
        { 5, { { "Assistant", _String? (StringCount[ #, "kept" ] === 5 &), { }, { } } } },
        { 5, _Integer? (LessEqualThan[ 3 ]) }
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-History-KeptObjects"
]

(* Special characters are replaced when the objects are created, so what is kept depends on that setting. The same
   call must not come back in the form of another setting: *)
VerificationTest[
    Module[ { messages, prepare },
        messages = {
            <|
                "Role"    -> "Assistant",
                "Content" -> StringTrim @ toolCallWithResult[ "\[FreeformPrompt][x]", "Out: \[FreeformPrompt]", "id1111111" ]
            |>
        };
        prepare[ replace_ ] := Block[ { Wolfram`Chatbook`$ChatHandlerData = <| |> },
            Rest /@ summarize @ Wolfram`Chatbook`SendChat`Private`prepareMessagesForLLM[
                <| "ToolMethod" -> "Service", "ReplaceUnicodeCharacters" -> replace |>,
                messages
            ]
        ];
        { prepare @ True, prepare @ False, prepare @ True }
    ],
    {
        { { "", { { "id1111111", "\\[FreeformPrompt][x]" } }, { } }, { "", { }, { { "id1111111", "Out: \\[FreeformPrompt]" } } } },
        { { "", { { "id1111111", "\[FreeformPrompt][x]" } }, { } }, { "", { }, { { "id1111111", "Out: \[FreeformPrompt]" } } } },
        { { "", { { "id1111111", "\\[FreeformPrompt][x]" } }, { } }, { "", { }, { { "id1111111", "Out: \\[FreeformPrompt]" } } } }
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-History-SpecialCharacters"
]

(* The same replacement for the tool call that is being evaluated, which is not read from text: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatHandlerData = <| |> },
        summarize @ Wolfram`Chatbook`SendChat`Private`prepareMessagesForLLM[
            <| "ToolMethod" -> "Service", "ReplaceUnicodeCharacters" -> True |>,
            { inTurnMessage[ "", "\[FreeformPrompt][x]", "id1111111" ], inTurnMessage[ "", "1+1", "id2222222" ] }
        ]
    ],
    {
        { "Assistant", "", { { "id1111111", "\\[FreeformPrompt][x]" } }, { } },
        { "Assistant", "", { { "id2222222", "1+1" } }, { } }
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-InTurn-SpecialCharacters"
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
    TestID   -> "ServiceToolCalls-InTurn-Matches-History"
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
    TestID   -> "ServiceToolCalls-ConstructMessages-KeepsIDs"
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
    TestID   -> "OtherToolMethods-RemoveIDs"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Structured Parameters*)

(* A tool with a parameter that takes a list of objects. Its value is JSON text in the Simple tool method, and a list in
   a native call (e.g. with the hybrid tool method, where native calls are written as Simple tool calls): *)
VerificationTest[
    $structuredTool = LLMTool @ <|
        "Name"        -> "structured_test",
        "Description" -> "Sets the text of cells.",
        "Parameters"  -> {
            "notebook" -> <| "Interpreter" -> "String", "Help" -> "The notebook", "Required" -> True |>,
            "cells"    -> <|
                "Interpreter" -> RepeatingElement @ CompoundElement @ <| "cell" -> "String", "text" -> "String" |>,
                "Help"        -> "The cells",
                "Required"    -> True
            |>
        },
        "Function"    -> Function[ "Done" ]
    |>;

    (* Text with backslashes, quotes, a line break and non-ASCII characters: *)
    $structuredCells = {
        <| "cell" -> "c3", "text" -> "a \\ b \"quoted\" \:3014x\:3015 \[Alpha]\[Beta]\nnext line \\n" |>,
        <| "cell" -> "c4", "text" -> "plain" |>
    };

    SetAttributes[ withStructuredTool, HoldFirst ];
    withStructuredTool[ eval_ ] :=
        Block[ { Wolfram`Chatbook`Common`$selectedTools = <| "StructuredTest" -> $structuredTool |> }, eval ];

    (* The text that a native tool call is written as in the response with the given tool method: *)
    nativeCallText[ method_String, request_ ] := Block[
        {
            Wolfram`Chatbook`$ChatHandlerData         = <| "ChatNotebookSettings" -> <| "ToolMethod" -> method |> |>,
            Wolfram`Chatbook`Common`$receivedToolCall = False
        },
        Wolfram`Chatbook`LLMUtilities`Private`toolRequestToString @ request
    ];

    structuredValues[ request_ ] := Association @ request[ "ParameterValues" ];

    interpretedStructuredValues[ request_ ] := GenerateLLMToolResponse[
        LLMConfiguration @ <| "Tools" -> { $structuredTool } |>,
        request
    ][ "InterpretedParameterValues" ];

    $structuredTool,
    _LLMTool,
    SameTest -> MatchQ,
    TestID   -> "StructuredParameters-Definitions"
]

(* A Simple tool call gives the list as JSON, which is read before the tool's interpreter gets it. The JSON can also
   span several lines: *)
VerificationTest[
    withStructuredTool @ Map[
        Module[ { request = Last @ Wolfram`Chatbook`Common`simpleToolRequestParser @ # },
            { structuredValues @ request, interpretedStructuredValues @ request }
        ] &,
        {
            "Let me change them.\n/structured_test\nnotebook: nb1\ncells: [{\"cell\":\"c3\",\"text\":\"x\"},{\"cell\":\"c4\",\"text\":\"y\"}]",
            "/structured_test\nnotebook: nb1\ncells: [\n  {\"cell\": \"c3\", \"text\": \"x\"},\n  {\"cell\": \"c4\", \"text\": \"y\"}\n]"
        }
    ],
    With[
        {
            values = <|
                "notebook" -> "nb1",
                "cells"    -> { <| "cell" -> "c3", "text" -> "x" |>, <| "cell" -> "c4", "text" -> "y" |> }
            |>
        },
        { { values, values }, { values, values } }
    ],
    SameTest -> MatchQ,
    TestID   -> "StructuredParameters-SimpleToolCall"
]

(* A native call's list is written as JSON on one line, and is read back as the same list, also next to a value with
   line breaks: *)
VerificationTest[
    withStructuredTool @ Map[
        Module[ { native, request },
            native  = LLMToolRequest[ "structured_test", <| "notebook" -> #, "cells" -> $structuredCells |> ];
            request = Last @ Wolfram`Chatbook`Common`simpleToolRequestParser @ nativeCallText[ "Simple", native ];
            { structuredValues @ request, interpretedStructuredValues @ request } === ConstantArray[ structuredValues @ native, 2 ]
        ] &,
        { "nb1", "a notebook\nwith two lines \\ \[Gamma]" }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "StructuredParameters-NativeCall-RoundTrip"
]

(* A native call can leave out optional parameters and give the others in any order, so its values are written with
   their names (a value without a name would go to the parameter in its place in the tool's order). Only the value of a
   tool's only parameter is written without its name: *)
VerificationTest[
    Module[ { stringParameter, insertTool, oneParameterTool, roundTrip },
        stringParameter[ required_ ] := <| "Interpreter" -> "String", "Help" -> "Text", "Required" -> required |>;
        insertTool = LLMTool @ <|
            "Name"        -> "insert_test",
            "Description" -> "Inserts cells.",
            "Parameters"  -> {
                "notebook" -> stringParameter @ True,
                "cells"    -> <|
                    "Interpreter" -> RepeatingElement @ CompoundElement @ <| "cell" -> "String", "text" -> "String" |>,
                    "Help"        -> "The cells",
                    "Required"    -> True
                |>,
                "cell"     -> stringParameter @ False,
                "position" -> stringParameter @ False
            },
            "Function"    -> Function[ "Done" ]
        |>;
        oneParameterTool = LLMTool @ <|
            "Name"        -> "one_parameter_test",
            "Description" -> "Evaluates code.",
            "Parameters"  -> { "code" -> stringParameter @ True },
            "Function"    -> Function[ "Done" ]
        |>;
        roundTrip[ values_ ] := Lookup[
            structuredValues @ Last @ Wolfram`Chatbook`Common`simpleToolRequestParser @ nativeCallText[
                "Simple",
                LLMToolRequest[ "insert_test", values ]
            ],
            { "notebook", "cells", "cell", "position" }
        ];
        Block[
            {
                Wolfram`Chatbook`Common`$selectedTools = <|
                    "InsertTest"       -> insertTool,
                    "OneParameterTest" -> oneParameterTool
                |>
            },
            {
                roundTrip @ <| "position" -> "before", "cells" -> $structuredCells, "notebook" -> "s1" |>,
                roundTrip @ <| "position" -> "before" |>,
                nativeCallText[ "Simple", LLMToolRequest[ "one_parameter_test", <| "code" -> "1 + 1" |> ] ]
            }
        ]
    ],
    {
        { "s1", $structuredCells, "", "before" },
        { "", "", "", "before" },
        "\n/one_parameter_test\n1 + 1"
    },
    SameTest -> MatchQ,
    TestID   -> "StructuredParameters-NativeCall-ParameterOrder"
]

(* A native call can have parameters that the tool does not have. They are left out of the Simple tool call: the parser
   only knows the tool's own names, so "name: value" would be read as more text of the value before it (and, for a
   tool with one parameter, of that parameter's value): *)
VerificationTest[
    Module[ { oneParameterTool, call },
        oneParameterTool = LLMTool @ <|
            "Name"        -> "one_parameter_test",
            "Description" -> "Evaluates code.",
            "Parameters"  -> { "code" -> <| "Interpreter" -> "String", "Help" -> "Code", "Required" -> True |> },
            "Function"    -> Function[ "Done" ]
        |>;
        call[ name_, values_ ] := With[ { text = nativeCallText[ "Simple", LLMToolRequest[ name, values ] ] },
            { text, structuredValues @ Last @ Wolfram`Chatbook`Common`simpleToolRequestParser @ text }
        ];
        Block[
            {
                Wolfram`Chatbook`Common`$selectedTools = <|
                    "StructuredTest"   -> $structuredTool,
                    "OneParameterTest" -> oneParameterTool
                |>
            },
            {
                call[ "structured_test", <| "notebook" -> "nb1", "cells" -> { <| "cell" -> "c3", "text" -> "x" |> }, "after" -> "c26" |> ],
                call[ "structured_test", <| "after" -> "c26", "notebook" -> "two\nlines" |> ],
                call[ "one_parameter_test", <| "code" -> "1 + 1", "timeout" -> 5 |> ],
                call[ "one_parameter_test", <| "timeout" -> 5 |> ]
            }
        ]
    ],
    {
        {
            "\n/structured_test\nnotebook: nb1\ncells: [{\"cell\":\"c3\",\"text\":\"x\"}]",
            <| "notebook" -> "nb1", "cells" -> { <| "cell" -> "c3", "text" -> "x" |> } |>
        },
        { "\n/structured_test\nnotebook: two\nlines", <| "notebook" -> "two\nlines", "cells" -> "" |> },
        { "\n/one_parameter_test\n1 + 1", <| "code" -> "1 + 1" |> },
        { "\n/one_parameter_test\n", <| "code" -> "" |> }
    },
    SameTest -> MatchQ,
    TestID   -> "StructuredParameters-NativeCall-UnknownParameter"
]

(* Only parameters that take structured data are read as JSON. A string parameter keeps text that looks like JSON: *)
VerificationTest[
    withStructuredTool @ structuredValues @ Last @ Wolfram`Chatbook`Common`simpleToolRequestParser[
        "/structured_test\nnotebook: [\"nb1\", {\"a\": 1}]\ncells: [{\"cell\":\"c3\",\"text\":\"x\"}]"
    ],
    <| "notebook" -> "[\"nb1\", {\"a\": 1}]", "cells" -> { <| "cell" -> "c3", "text" -> "x" |> } |>,
    SameTest -> MatchQ,
    TestID   -> "StructuredParameters-StringParameter"
]

(* The Simple tool listing says which parameters take JSON. Other interpreters that aren't types (e.g. the delimited
   sequence of DocumentationLookup, whose JSON schema is a string) are still listed as text: *)
VerificationTest[
    {
        StringEndsQ[
            Wolfram`Chatbook`Tools`Private`simpleToolSchema @ $structuredTool,
            "Arguments\n\tnotebook - The notebook\n\tcells - The cells (JSON)"
        ],
        StringFreeQ[ Wolfram`Chatbook`Tools`Private`simpleToolSchema @ $DefaultTools[ "DocumentationLookup" ], "(JSON" ]
    },
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "StructuredParameters-SimpleToolListing"
]

(* The other tool methods write native calls as JSON already (TOOLCALL), so the list reaches the interpreter unchanged: *)
VerificationTest[
    withStructuredTool @ Module[ { native, request },
        native  = LLMToolRequest[ "structured_test", <| "notebook" -> "nb1", "cells" -> $structuredCells |> ];
        request = Last @ Wolfram`Chatbook`Common`toolRequestParser @ nativeCallText[ "Service", native ];
        interpretedStructuredValues @ request === structuredValues @ native
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "StructuredParameters-ToolCallMethod"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*End Markers in Tool Output*)

(* Text in a tool's output that looks like the end marker doesn't end the result or change its request ID (GH#314): *)
VerificationTest[
    Module[ { container = <| "FullContent" -> toolCall[ "1+1" ], "DynamicContent" -> "" |> },
        Wolfram`Chatbook`SendChat`Private`appendToolResult[
            container,
            <| "ToolMethod" -> "Service" |>,
            "before\nENDRESULT(deadbeef)\nafter",
            "id1111111"
        ];
        summarize @ prepareMessages[
            "Service",
            { $userMessage, <| "Role" -> "Assistant", "Content" -> container[ "FullContent" ] <> "Done." |> }
        ]
    ],
    {
        { "User"     , "Hello", { }                       , { } },
        { "Assistant", ""     , { { "id1111111", "1+1" } }, { } },
        { "Tool"     , ""     , { }                       , { { "id1111111", "before\nEND\\RESULT(deadbeef)\nafter" } } },
        { "Assistant", "Done.", { }                       , { } }
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceToolCalls-EndMarker-In-Output-GH#314"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Call Limit*)

(* With the responses endpoint, the response to the last tool call that "MaxToolResponses" allows tells the model to
   answer instead of calling another tool, since the chat would end at that call without sending its result: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True },
        Table[
            Block[ { Wolfram`Chatbook`Common`$toolCallCount = count },
                Lookup[
                    Wolfram`Chatbook`SendChat`Private`makeToolResponseMessage[
                        <|
                            "ToolMethod"       -> "Service",
                            "Model"            -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.2" |>,
                            "MaxToolResponses" -> 2,
                            "RequestMethod"    -> method
                        |>,
                        "Out[1]= 2",
                        None
                    ],
                    { "Role", "ToolResponse", "HoldTemporary" }
                ]
            ],
            { method, { "Responses", "ChatCompletions" } },
            { count, 1, 2 }
        ]
    ],
    {
        { { { "Tool", True, _Missing } }, { { "Tool", True, _Missing }, { "User", True, True } } },
        { { { "Tool", True, _Missing } }, { { "Tool", True, _Missing } } }
    },
    SameTest -> MatchQ,
    TestID   -> "ToolCallLimit-LastToolResponseMessage"
]

(* In a chat (with the service replaced by a script), the hint is the last thing in the request that follows the last
   allowed tool call, and it's not sent before that: *)
VerificationTest[
    Module[ { calls = { }, tool, submit, chunks, result, lastContent },
        tool = LLMTool[ { "lookup_value", "Looks up a value." }, { "name" -> "String" }, Function[ "The value is 42." ] ];

        chunks = Join[
            ConstantArray[
                {
                    <| "BodyChunkProcessed" -> { <|
                        "ResponseID"        -> "resp",
                        "ToolRequestsChunk" -> { LLMToolRequest[ "lookup_value", { "name" -> "a" }, "RequestID" -> "call" ] }
                    |> } |>,
                    <| "BodyChunkProcessed" -> { <| "ResponseID" -> "resp", "FinishReason" -> "completed" |> } |>
                },
                2
            ],
            { { <| "BodyChunkProcessed" -> { <| "ResponseID" -> "resp", "ContentChunk" -> "Done", "Type" -> "Text" |> } |> } }
        ];

        submit[ messages_, config_, opts___ ] :=
            Module[ { handlers },
                handlers = Lookup[ { opts }, HandlerFunctions ];
                AppendTo[ calls, messages ];
                Scan[ handlers[ "BodyChunkReceived" ], chunks[[ Length @ calls ]] ];
                handlers[ "TaskFinished" ][ <| "TaskStatus" -> "Finished", "EventName" -> "TaskFinished", "StatusCode" -> 200 |> ];
                None
            ];

        (* Tool evaluation writes the task to the output cell, which doesn't exist here. The tool box is restored, since
           a tool that is given in the settings stays in it for the session: *)
        result = Quiet[
            Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True },
                Internal`InheritedBlock[ { Wolfram`Chatbook`Tools`Private`$toolBox },
                    Wolfram`Chatbook`AgentEvaluate[
                        "Hello",
                        <|
                            "Model"               -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.2" |>,
                            "Authentication"      -> Automatic,
                            "LLMEvaluator"        -> "PlainChat",
                            "ToolsEnabled"        -> True,
                            "Tools"               -> { tool },
                            "MaxToolResponses"    -> 2,
                            "ProcessingFunctions" -> <| "ChatSubmit" -> submit |>
                        |>
                    ]
                ]
            ],
            { FrontEndObject::notavail, General::stop }
        ];

        lastContent[ messages_ ] := ToString @ Last[ messages ][ "Content" ];

        {
            Length @ calls,
            StringContainsQ[ lastContent @ #, "last tool call available" ] & /@ calls,
            StringQ @ result && StringEndsQ[ result, "Done" ]
        }
    ],
    { 3, { False, False, True }, True },
    SameTest -> MatchQ,
    TestID   -> "ToolCallLimit-Chat"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Response Images*)

(* Settings of a request with native tool calls for each endpoint: *)
$responsesSettings = <|
    "Model"         -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.2" |>,
    "RequestMethod" -> "Responses",
    "ToolMethod"    -> "Service"
|>;

$completionsSettings = <| $responsesSettings, "RequestMethod" -> "ChatCompletions" |>;

(* The responses endpoint only gets the text of a service tool's output, so its images follow in another message: *)
VerificationTest[
    With[ { image = <| "Type" -> "Image", "Data" -> Image @ { { 0 } } |> },
        Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True },
            {
                Wolfram`Chatbook`SendChat`Private`toolResponseImagesMessage[
                    $responsesSettings,
                    { <| "Type" -> "Text", "Data" -> "Out[1]= " |>, image, <| "Type" -> "Text", "Data" -> "\n" |> }
                ] === <|
                    "Role"          -> "User",
                    "Content"       -> { "<tool_response_images>", image, "</tool_response_images>" },
                    "ToolResponse"  -> True,
                    "HoldTemporary" -> True
                |>,
                (* No images: *)
                { Wolfram`Chatbook`SendChat`Private`toolResponseImagesMessage[ $responsesSettings, "Out[1]= 2" ] },
                (* Tool responses of other tool methods and endpoints keep their images: *)
                { Wolfram`Chatbook`SendChat`Private`toolResponseImagesMessage[ <| $responsesSettings, "ToolMethod" -> "Simple" |>, { image } ] },
                { Wolfram`Chatbook`SendChat`Private`toolResponseImagesMessage[ $completionsSettings, { image } ] }
            }
        ]
    ],
    { True, { }, { }, { } },
    SameTest -> MatchQ,
    TestID   -> "ToolResponseImagesMessage"
]

(* The message with the images comes right after the tool's output. It is not taken for the user's input, and is only
   part of the request that follows the tool call: *)
VerificationTest[
    With[ { image = <| "Type" -> "Image", "Data" -> Image @ { { 0 } } |> },
        Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True, Wolfram`Chatbook`Common`$toolCallCount = 1 },
            {
                Lookup[ #1, "Role" ],
                Wolfram`Chatbook`Common`toolMessageQ /@ #1,
                Lookup[ #1, "HoldTemporary", False ],
                (* The image is only in the message that is sent, so that it's not encoded twice: *)
                Count[ #1, image, Infinity ] & /@ Lookup[ #1, "Content" ]
            } & @ Wolfram`Chatbook`SendChat`Private`makeToolResponseMessage[
                <| $responsesSettings, "MaxToolResponses" -> 5 |>,
                { <| "Type" -> "Text", "Data" -> "Out[1]= " |>, image },
                None
            ]
        ]
    ],
    { { "Tool", "User" }, { True, True }, { False, True }, { 0, 1 } },
    SameTest -> MatchQ,
    TestID   -> "ToolResponseImagesMessage-MakeToolResponseMessage"
]

(* Other endpoints get the images in the tool message, as before: *)
VerificationTest[
    With[ { image = <| "Type" -> "Image", "Data" -> Image @ { { 0 } } |> },
        Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True, Wolfram`Chatbook`Common`$toolCallCount = 1 },
            {
                Lookup[ #1, "Role" ],
                Count[ #1, image, Infinity ] & /@ Lookup[ #1, "Content" ]
            } & @ Wolfram`Chatbook`SendChat`Private`makeToolResponseMessage[
                <| $completionsSettings, "MaxToolResponses" -> 5 |>,
                { <| "Type" -> "Text", "Data" -> "Out[1]= " |>, image },
                None
            ]
        ]
    ],
    { { "Tool" }, { 1 } },
    SameTest -> MatchQ,
    TestID   -> "ToolResponseImagesMessage-OtherEndpoints"
]

(* In a chat (with the service replaced by a script), the image that a tool returns is in a user message of the request
   that follows the tool call, and not in the tool message. This needs toolEvaluation to expand the tool's output into
   images, which allowedMultimodalRoles alone doesn't allow for the endpoint, since it has no "System" role: *)
VerificationTest[
    Module[ { calls = { }, tool, submit, chunks, result, images },
        tool = LLMTool[ { "make_picture", "Makes a picture." }, { "name" -> "String" }, Function[ Graphics @ Disk[ ] ] ];

        chunks = {
            {
                <| "BodyChunkProcessed" -> { <|
                    "ResponseID"        -> "resp",
                    "ToolRequestsChunk" -> { LLMToolRequest[ "make_picture", { "name" -> "a" }, "RequestID" -> "call" ] }
                |> } |>,
                <| "BodyChunkProcessed" -> { <| "ResponseID" -> "resp", "FinishReason" -> "completed" |> } |>
            },
            { <| "BodyChunkProcessed" -> { <| "ResponseID" -> "resp", "ContentChunk" -> "Done", "Type" -> "Text" |> } |> }
        };

        submit[ messages_, config_, opts___ ] :=
            Module[ { handlers },
                handlers = Lookup[ { opts }, HandlerFunctions ];
                AppendTo[ calls, messages ];
                Scan[ handlers[ "BodyChunkReceived" ], chunks[[ Length @ calls ]] ];
                handlers[ "TaskFinished" ][ <| "TaskStatus" -> "Finished", "EventName" -> "TaskFinished", "StatusCode" -> 200 |> ];
                None
            ];

        (* See ToolCallLimit-Chat for the Quiet and the tool box: *)
        result = Quiet[
            Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True },
                Internal`InheritedBlock[ { Wolfram`Chatbook`Tools`Private`$toolBox },
                    Wolfram`Chatbook`AgentEvaluate[
                        "Hello",
                        <|
                            "Model"               -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.2" |>,
                            "Authentication"      -> Automatic,
                            "LLMEvaluator"        -> "PlainChat",
                            "Multimodal"          -> True,
                            "ToolsEnabled"        -> True,
                            "Tools"               -> { tool },
                            "ProcessingFunctions" -> <| "ChatSubmit" -> submit |>
                        |>
                    ]
                ]
            ],
            { FrontEndObject::notavail, General::stop }
        ];

        (* The roles of the messages of the second request that contain images: *)
        images = #[ "Role" ] & /@ Select[ Last @ calls, ! FreeQ[ #[ "Content" ], KeyValuePattern[ "Type" -> "Image" ] ] & ];

        { Length @ calls, images, StringQ @ result && StringEndsQ[ result, "Done" ] }
    ],
    { 2, { "User" }, True },
    SameTest -> MatchQ,
    TestID   -> "ToolResponseImagesMessage-Chat"
]

(* :!CodeAnalysis::EndBlock:: *)
