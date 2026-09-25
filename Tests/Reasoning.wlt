(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Reasoning.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Reasoning.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    $signature = StringToByteArray[ "encrypted-reasoning" ];

    $openAISettings = <|
        "Model"          -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.4" |>,
        "Authentication" -> Automatic,
        "RequestMethod"  -> "Responses"
    |>;

    $llmKitSettings = <|
        "Model"          -> <| "Service" -> "LLMKit", "Name" -> "gpt-5.4" |>,
        "Authentication" -> "LLMKit",
        "RequestMethod"  -> "Responses"
    |>;

    $storedReasoning = <|
        "abc123" -> <| "Signature" -> $signature, "CallID" -> "rs_123", "Service" -> "OpenAI", "Model" -> "gpt-5.4" |>
    |>;

    (* Evaluates `eval` with an isolated reasoning store and stream state: *)
    withReasoningData // Attributes = { HoldFirst };
    withReasoningData[ eval_, data_: <| |> ] := Block[
        {
            Wolfram`Chatbook`Common`$reasoningData                = data,
            Wolfram`Chatbook`Reasoning`Private`$reasoningStreamID = None,
            Wolfram`Chatbook`Common`$responsesAPIAvailable        = True
        },
        eval
    ];

    (* Simulates the chunk processing done in the chat handlers, returning the resulting streamed text: *)
    streamChunks[ settings_, batches_List ] := StringJoin @ Map[
        Function[
            Wolfram`Chatbook`SendChat`Private`addExtractedBodyChunks[
                Wolfram`Chatbook`Common`convertReasoningChunks[ settings, <| "BodyChunkProcessed" -> # |> ]
            ][ "ExtractedBodyChunks" ]
        ],
        batches
    ];

    $streamedChunks = {
        <| "ResponseID" -> "resp_1", "Model" -> "gpt-5.4" |>,
        <| "ResponseID" -> "resp_1", "ReasoningChunk" -> "**Multiplying**\n\nI need", "Type" -> "Reasoning" |>,
        <| "ResponseID" -> "resp_1", "ReasoningChunk" -> " to multiply 17 by 23.", "Type" -> "Reasoning" |>,
        <|
            "ResponseID"      -> "resp_1",
            "ResponseContent" -> {
                <|
                    "Type"      -> "Reasoning",
                    "Data"      -> "**Multiplying**\n\nI need to multiply 17 by 23.",
                    "Signature" -> $signature,
                    "CallID"    -> "rs_123"
                |>
            }
        |>,
        <| "ResponseID" -> "resp_1", "Role" -> "Assistant" |>,
        <| "ResponseID" -> "resp_1", "ContentChunk" -> "391", "Type" -> "Text" |>,
        <|
            "ResponseID"     -> "resp_1",
            "UsageIncrement" -> <| "History" -> Quantity[ 21, "Tokens" ], "Completion" -> Quantity[ 25, "Tokens" ] |>,
            "FinishReason"   -> "completed"
        |>
    };

    $summaryPattern = "<think type='summary' id='" ~~ Repeated[ LetterCharacter|DigitCharacter, 13 ] ~~ "'>\n";

    (* The contents of think boxes are formatted, so this converts them back to text: *)
    thoughtsText[ thoughts_String ] := thoughts;
    thoughtsText[ thoughts_TextData ] := CellToString @ Cell[ thoughts, "Text" ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions@@Tests/Reasoning.wlt:25,1-98,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Think Tags*)
VerificationTest[
    Wolfram`Chatbook`Reasoning`Private`thinkTagAttributes /@ {
        " type='summary' id='abc123'",
        " TYPE=\"Summary\" Id = \"abc123\"",
        " "
    },
    {
        <| "type" -> "summary", "id" -> "abc123" |>,
        <| "type" -> "Summary", "id" -> "abc123" |>,
        <| |>
    },
    SameTest -> MatchQ,
    TestID   -> "ThinkTagAttributes@@Tests/Reasoning.wlt:103,1-116,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`reasoningIDs @ StringJoin[
        "<think type='summary' id='abc'>\nfirst\n</think>\n",
        "<think>\nliteral thoughts\n</think>\n",
        "text <think type='summary' id='def'>\nsecond\n</think>\n",
        "<think type='summary' id='abc'>\nduplicate\n</think>\n"
    ],
    { "abc", "def" },
    SameTest -> MatchQ,
    TestID   -> "ReasoningIDs@@Tests/Reasoning.wlt:118,1-128,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatting*)
VerificationTest[
    withReasoningData[
        FirstCase[
            FormatChatOutput[ "<think type='summary' id='abc123'>\nSome **summary** text\n</think>\n\nThe answer is 391." ],
            TemplateBox[ { text_, _, meta_Association }, "ThoughtsOpener" ] :> { thoughtsText @ text, meta },
            $Failed,
            Infinity
        ],
        $storedReasoning
    ],
    {
        "Some **summary** text",
        <|
            "Type"      -> "Summary",
            "ID"        -> "abc123",
            "Signature" -> $signature,
            "CallID"    -> "rs_123",
            "Service"   -> "OpenAI",
            "Model"     -> "gpt-5.4"
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "Format-Summary@@Tests/Reasoning.wlt:133,1-156,2"
]

VerificationTest[
    withReasoningData[
        FirstCase[
            FormatChatOutput[ "<think type='summary' id='abc123'>\n\n</think>\nThe answer is 391." ],
            TemplateBox[ { text_, _, KeyValuePattern @ { "Type" -> "Summary", "ID" -> "abc123" } }, "ThoughtsOpener" ] :>
                text,
            $Failed,
            Infinity
        ],
        $storedReasoning
    ],
    "",
    SameTest -> MatchQ,
    TestID   -> "Format-Empty-Summary@@Tests/Reasoning.wlt:158,1-172,2"
]

VerificationTest[
    withReasoningData @ FirstCase[
        FormatChatOutput[ "<think type='summary' id='abc123'>\nStill thinking" ],
        TemplateBox[ { text_, _, meta_Association }, "ThinkingOpener" ] :> { thoughtsText @ text, meta },
        $Failed,
        Infinity
    ],
    { "Still thinking", <| "Type" -> "Summary", "ID" -> "abc123" |> },
    SameTest -> MatchQ,
    TestID   -> "Format-Summary-In-Progress@@Tests/Reasoning.wlt:174,1-184,2"
]

VerificationTest[
    withReasoningData @ FirstCase[
        FormatChatOutput[ "<think type='summary' id='abc123'>\n" ],
        TemplateBox[ { text_, _, KeyValuePattern[ "Type" -> "Summary" ] }, "ThinkingOpener" ] :> text,
        $Failed,
        Infinity
    ],
    "",
    SameTest -> MatchQ,
    TestID   -> "Format-Summary-Just-Started@@Tests/Reasoning.wlt:186,1-196,2"
]

VerificationTest[
    FirstCase[
        FormatChatOutput[ "<think>\nLiteral thoughts\n</think>\nThe answer is 391." ],
        TemplateBox[ { text_, _, meta_Association }, "ThoughtsOpener" ] :> { thoughtsText @ text, meta },
        $Failed,
        Infinity
    ],
    { "Literal thoughts", <| "Type" -> "Literal" |> },
    SameTest -> MatchQ,
    TestID   -> "Format-Literal@@Tests/Reasoning.wlt:198,1-208,2"
]

VerificationTest[
    FirstCase[
        FormatChatOutput[ "<think>\nLiteral thoughts" ],
        TemplateBox[ { text_, _, meta_Association }, "ThinkingOpener" ] :> { thoughtsText @ text, meta },
        $Failed,
        Infinity
    ],
    { "Literal thoughts", <| "Type" -> "Literal" |> },
    SameTest -> MatchQ,
    TestID   -> "Format-Literal-In-Progress@@Tests/Reasoning.wlt:210,1-220,2"
]

VerificationTest[
    withReasoningData[
        Cases[
            FormatChatOutput @ StringJoin[
                "<think type='summary' id='abc123'>\nFirst\n</think>\n",
                "Some text\n",
                "<think type='summary' id='def456'>\nSecond\n</think>\n",
                "The answer is 391."
            ],
            TemplateBox[ { text_, _, KeyValuePattern[ "ID" -> id_ ] }, "ThoughtsOpener" ] :> { thoughtsText @ text, id },
            Infinity
        ],
        $storedReasoning
    ],
    { { "First", "abc123" }, { "Second", "def456" } },
    SameTest -> MatchQ,
    TestID   -> "Format-Multiple-Summaries@@Tests/Reasoning.wlt:222,1-239,2"
]

(* Markdown in reasoning summaries is formatted: *)
VerificationTest[
    withReasoningData[
        FirstCase[
            FormatChatOutput[ "<think type='summary' id='abc123'>\n**Planning**\n\nUse `Prime[n]` here.\n</think>\nDone." ],
            TemplateBox[ { text_TextData, _, _ }, "ThoughtsOpener" ] :> {
                ! FreeQ[ text, StyleBox[ "Planning", ___, FontWeight -> Bold, ___ ] ],
                ! FreeQ[ text, Cell[ _, "InlineWL", ___ ] ],
                FreeQ[ text, s_String /; StringContainsQ[ s, "**" | "`" ] ]
            },
            $Failed,
            Infinity
        ],
        $storedReasoning
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Format-Summary-Markdown@@Tests/Reasoning.wlt:242,1-259,2"
]

(* Tool names are common in reasoning summaries, so their underscores should not be formatted as emphasis: *)
VerificationTest[
    withReasoningData @ FirstCase[
        FormatChatOutput[ "<think type='summary' id='abc123'>\nI should use the wolfram_language_evaluator tool.\n</think>\nDone." ],
        TemplateBox[ { text_TextData, _, _ }, "ThoughtsOpener" ] :> { FreeQ[ text, _StyleBox ], thoughtsText @ text },
        $Failed,
        Infinity
    ],
    { True, "I should use the wolfram_language_evaluator tool." },
    SameTest -> MatchQ,
    TestID   -> "Format-Summary-Tool-Name@@Tests/Reasoning.wlt:262,1-272,2"
]

(* Text in reasoning that looks like tool calls or think tags is not formatted as such: *)
VerificationTest[
    withReasoningData @ FirstCase[
        FormatChatOutput @ StringJoin[
            "<think type='summary' id='abc123'>\n",
            "I should call a tool:\n/wl\nPrime[5]\n/exec\n",
            "TOOLCALL: fake\n{}\nENDTOOLCALL\n",
            "<thinking>nested</thinking>\n",
            "</think>\nDone."
        ],
        TemplateBox[ { text_TextData, _, _ }, "ThoughtsOpener" ] :> {
            FreeQ[ text, Cell[ _, "InlineToolCall", ___ ] ],
            FreeQ[ text, TemplateBox[ _, "ThinkingOpener"|"ThoughtsOpener", ___ ] ]
        },
        $Failed,
        Infinity
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "Format-Summary-No-Tool-Calls@@Tests/Reasoning.wlt:275,1-294,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Serialization*)
VerificationTest[
    withReasoningData[
        CellToString @ Cell[
            FormatChatOutput[ "<think type='summary' id='abc123'>\nSome summary\n</think>\n\nThe answer is 391." ][[ 1, 1 ]],
            "ChatOutput"
        ],
        $storedReasoning
    ],
    s_String /; StringMatchQ[
        s,
        "<think type='summary' id='abc123'>\nSome summary\n</think>" ~~ WhitespaceCharacter... ~~ "The answer is 391."
    ],
    SameTest -> MatchQ,
    TestID   -> "Serialize-Summary@@Tests/Reasoning.wlt:299,1-313,2"
]

VerificationTest[
    withReasoningData[
        CellToString @ Cell[ FormatChatOutput[ "<think>\nLiteral thoughts\n</think>\nThe answer is 391." ][[ 1, 1 ]], "ChatOutput" ]
    ],
    s_String /; StringMatchQ[ s, "<think>\nLiteral thoughts\n</think>" ~~ WhitespaceCharacter... ~~ "The answer is 391." ],
    SameTest -> MatchQ,
    TestID   -> "Serialize-Literal@@Tests/Reasoning.wlt:315,1-322,2"
]

VerificationTest[
    CellToString @ Cell[
        TextData @ {
            Cell[ BoxData @ TemplateBox[ { "Old thoughts", "Thought for 3 seconds" }, "ThoughtsOpener" ], "ThoughtsOpener" ],
            "\nThe answer is 391."
        },
        "ChatOutput"
    ],
    s_String /; StringMatchQ[ s, "<think>\nOld thoughts\n</think>" ~~ WhitespaceCharacter... ~~ "The answer is 391." ],
    SameTest -> MatchQ,
    TestID   -> "Serialize-Legacy-Two-Argument-Box@@Tests/Reasoning.wlt:324,1-335,2"
]

(* Signatures stored in template boxes are restored when the boxes are serialized: *)
VerificationTest[
    Module[ { cell },
        cell = withReasoningData[
            Cell[ FormatChatOutput[ "<think type='summary' id='abc123'>\nSome summary\n</think>\nAnswer" ][[ 1, 1 ]], "ChatOutput" ],
            $storedReasoning
        ];
        withReasoningData[ CellToString @ cell; Wolfram`Chatbook`Common`$reasoningData ]
    ],
    $storedReasoning,
    SameTest -> MatchQ,
    TestID   -> "Serialize-Restores-Signature@@Tests/Reasoning.wlt:338,1-349,2"
]

(* A chat output cell from a previous kernel session still produces a message with the signature: *)
VerificationTest[
    Module[ { string, cell },
        string = "<think type='summary' id='abc123'>\nSome summary\n</think>\nThe answer is 391.";
        cell = withReasoningData[
            Cell[
                FormatChatOutput[ string ][[ 1, 1 ]],
                "ChatOutput",
                TaggingRules -> <| "CellToStringData" -> string |>
            ],
            $storedReasoning
        ];
        withReasoningData @ Wolfram`Chatbook`Common`convertReasoningMessages[
            $openAISettings,
            { CellToChatMessage @ cell }
        ]
    ],
    {
        <|
            "Role"    -> "Assistant",
            "Content" -> {
                <| "Type" -> "Reasoning", "Signature" -> $signature |>,
                <| "Type" -> "Text", "Data" -> "The answer is 391." |>
            }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ChatOutput-Cell-Message-Restores-Signature@@Tests/Reasoning.wlt:352,1-379,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Streaming*)
VerificationTest[
    withReasoningData @ Module[ { string, id },
        string = streamChunks[ $openAISettings, List /@ $streamedChunks ];
        id = First @ Wolfram`Chatbook`Common`reasoningIDs @ string;
        {
            StringMatchQ[
                string,
                $summaryPattern ~~ "**Multiplying**\n\nI need to multiply 17 by 23.\n</think>\n391"
            ],
            Keys @ Wolfram`Chatbook`Common`$reasoningData === { id },
            Values @ Wolfram`Chatbook`Common`$reasoningData,
            Wolfram`Chatbook`Reasoning`Private`$reasoningStreamID
        }
    ],
    {
        True,
        True,
        { <| "Signature" -> $signature, "CallID" -> "rs_123", "Service" -> "OpenAI", "Model" -> "gpt-5.4" |> },
        None
    },
    SameTest -> MatchQ,
    TestID   -> "Stream-Summary@@Tests/Reasoning.wlt:384,1-406,2"
]

VerificationTest[
    withReasoningData @ StringMatchQ[
        streamChunks[ $openAISettings, { $streamedChunks } ],
        $summaryPattern ~~ "**Multiplying**\n\nI need to multiply 17 by 23.\n</think>\n391"
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Stream-Summary-Batched@@Tests/Reasoning.wlt:408,1-416,2"
]

VerificationTest[
    withReasoningData @ Module[ { string },
        string = streamChunks[ $llmKitSettings, List /@ $streamedChunks ];
        Lookup[ Values @ Wolfram`Chatbook`Common`$reasoningData, "Service" ]
    ],
    { "LLMKit" },
    SameTest -> MatchQ,
    TestID   -> "Stream-Summary-LLMKit-Service@@Tests/Reasoning.wlt:418,1-426,2"
]

(* A separator chunk can start a summary (e.g. for later reasoning items in a response): *)
VerificationTest[
    withReasoningData @ StringMatchQ[
        streamChunks[
            $openAISettings,
            {
                { <| "ReasoningChunk" -> "\n\n", "Type" -> "Reasoning" |> },
                { <| "ReasoningChunk" -> "Checking", "Type" -> "Reasoning" |> },
                { <| "ResponseContent" -> { <| "Type" -> "Reasoning", "Data" -> "Checking", "Signature" -> $signature |> } |> },
                { <| "ContentChunk" -> "Done" |> }
            }
        ],
        $summaryPattern ~~ "Checking\n</think>\nDone"
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Stream-Summary-Leading-Separator@@Tests/Reasoning.wlt:429,1-445,2"
]

(* The signature can arrive without any streamed summary text: *)
VerificationTest[
    withReasoningData @ Module[ { string },
        string = streamChunks[
            $openAISettings,
            {
                { <| "ResponseContent" -> { <| "Type" -> "Reasoning", "Signature" -> $signature, "CallID" -> "rs_123" |> } |> },
                { <| "ContentChunk" -> "391" |> }
            }
        ];
        {
            StringMatchQ[ string, $summaryPattern ~~ "\n</think>\n391" ],
            Values @ Wolfram`Chatbook`Common`$reasoningData
        }
    ],
    { True, { KeyValuePattern @ { "Signature" -> $signature, "CallID" -> "rs_123" } } },
    SameTest -> MatchQ,
    TestID   -> "Stream-Empty-Summary@@Tests/Reasoning.wlt:448,1-465,2"
]

(* If the stream moves on before the reasoning item is complete, the summary is closed without a signature: *)
VerificationTest[
    withReasoningData @ Module[ { string },
        string = streamChunks[
            $openAISettings,
            {
                { <| "ReasoningChunk" -> "Partial summary", "Type" -> "Reasoning" |> },
                { <| "ContentChunk" -> "391" |> }
            }
        ];
        {
            StringMatchQ[ string, $summaryPattern ~~ "Partial summary\n</think>\n391" ],
            Wolfram`Chatbook`Common`$reasoningData,
            Wolfram`Chatbook`Reasoning`Private`$reasoningStreamID
        }
    ],
    { True, <| |>, None },
    SameTest -> MatchQ,
    TestID   -> "Stream-Interrupted-Summary@@Tests/Reasoning.wlt:468,1-486,2"
]

VerificationTest[
    withReasoningData @ StringMatchQ[
        streamChunks[
            $openAISettings,
            {
                { <| "ReasoningChunk" -> "Partial summary", "Type" -> "Reasoning" |> },
                { <| "UsageIncrement" -> <| |>, "FinishReason" -> "incomplete" |> }
            }
        ],
        $summaryPattern ~~ "Partial summary\n</think>\n"
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Stream-Incomplete-Response@@Tests/Reasoning.wlt:488,1-502,2"
]

(* Reasoning items without a signature or summary produce no output: *)
VerificationTest[
    withReasoningData @ {
        streamChunks[
            $openAISettings,
            { { <| "ResponseContent" -> { <| "Type" -> "Reasoning", "CallID" -> "rs_123" |> } |> } }
        ],
        Wolfram`Chatbook`Common`$reasoningData
    },
    { "", <| |> },
    SameTest -> MatchQ,
    TestID   -> "Stream-Empty-Reasoning-Item@@Tests/Reasoning.wlt:505,1-516,2"
]

VerificationTest[
    withReasoningData @ Module[ { content },
        content = Wolfram`Chatbook`Common`convertReasoningContent[
            $openAISettings,
            {
                <| "Type" -> "Reasoning", "Data" -> "Summary text", "Signature" -> $signature, "CallID" -> "rs_123" |>,
                <| "Type" -> "Text", "Data" -> "391", "CallID" -> "msg_123" |>
            }
        ];
        {
            StringMatchQ[
                StringJoin @ Wolfram`Chatbook`Common`extractBodyChunks @ <| "ContentChunk" -> content |>,
                $summaryPattern ~~ "Summary text\n</think>\n391"
            ],
            Length @ Wolfram`Chatbook`Common`$reasoningData
        }
    ],
    { True, 1 },
    SameTest -> MatchQ,
    TestID   -> "Synchronous-Response-Content@@Tests/Reasoning.wlt:518,1-538,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
VerificationTest[
    $messages = {
        <| "Role" -> "System", "Content" -> "You are a helpful assistant." |>,
        <| "Role" -> "User", "Content" -> "What's 17*23?" |>,
        <| "Role" -> "Assistant", "Content" -> "<think type='summary' id='abc123'>\nI need to multiply.\n</think>\n391" |>,
        <| "Role" -> "User", "Content" -> "Add 9." |>
    },
    { __Association },
    SameTest -> MatchQ,
    TestID   -> "Messages-Definition@@Tests/Reasoning.wlt:543,1-553,2"
]

VerificationTest[
    withReasoningData[ Wolfram`Chatbook`Common`convertReasoningMessages[ $openAISettings, $messages ], $storedReasoning ],
    {
        $messages[[ 1 ]],
        $messages[[ 2 ]],
        <|
            "Role"    -> "Assistant",
            "Content" -> {
                <| "Type" -> "Reasoning", "Signature" -> $signature |>,
                <| "Type" -> "Text", "Data" -> "391" |>
            }
        |>,
        $messages[[ 4 ]]
    },
    SameTest -> MatchQ,
    TestID   -> "Messages-Responses-Sends-Signature@@Tests/Reasoning.wlt:555,1-571,2"
]

VerificationTest[
    withReasoningData[
        FreeQ[
            Wolfram`Chatbook`Common`convertReasoningMessages[ $openAISettings, $messages ],
            s_String /; StringContainsQ[ s, "I need to multiply" | "<think" ]
        ],
        $storedReasoning
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Messages-Responses-No-Summary-Text@@Tests/Reasoning.wlt:573,1-584,2"
]

VerificationTest[
    withReasoningData[
        Wolfram`Chatbook`Common`convertReasoningMessages[
            <| $openAISettings, "RequestMethod" -> "ChatCompletions" |>,
            $messages
        ][[ 3 ]],
        $storedReasoning
    ],
    <| "Role" -> "Assistant", "Content" -> "391" |>,
    SameTest -> MatchQ,
    TestID   -> "Messages-ChatCompletions-Removes-Summary@@Tests/Reasoning.wlt:586,1-597,2"
]

(* Signatures can only be used with the service that created them: *)
VerificationTest[
    withReasoningData[
        Wolfram`Chatbook`Common`convertReasoningMessages[ $llmKitSettings, $messages ][[ 3 ]],
        $storedReasoning
    ],
    <| "Role" -> "Assistant", "Content" -> "391" |>,
    SameTest -> MatchQ,
    TestID   -> "Messages-Responses-Different-Service@@Tests/Reasoning.wlt:600,1-608,2"
]

VerificationTest[
    withReasoningData[ Wolfram`Chatbook`Common`convertReasoningMessages[ $openAISettings, $messages ][[ 3 ]] ],
    <| "Role" -> "Assistant", "Content" -> "391" |>,
    SameTest -> MatchQ,
    TestID   -> "Messages-Responses-Unknown-ID@@Tests/Reasoning.wlt:610,1-615,2"
]

VerificationTest[
    withReasoningData[
        Wolfram`Chatbook`Common`convertReasoningMessages[
            $openAISettings,
            {
                <| "Role" -> "User", "Content" -> "<think type='summary' id='abc123'>\nuser text\n</think>" |>,
                <| "Role" -> "Assistant", "Content" -> "<think>\nLiteral thoughts\n</think>\nAnswer" |>
            }
        ],
        $storedReasoning
    ],
    {
        <| "Role" -> "User", "Content" -> "<think type='summary' id='abc123'>\nuser text\n</think>" |>,
        <| "Role" -> "Assistant", "Content" -> "<think>\nLiteral thoughts\n</think>\nAnswer" |>
    },
    SameTest -> MatchQ,
    TestID   -> "Messages-Other-Content-Unchanged@@Tests/Reasoning.wlt:617,1-634,2"
]

VerificationTest[
    withReasoningData[
        Wolfram`Chatbook`Common`convertReasoningMessages[
            $openAISettings,
            {
                <|
                    "Role"    -> "Assistant",
                    "Content" -> StringJoin[
                        "<think type='summary' id='abc123'>\nFirst\n</think>\n",
                        "Let me check.\n",
                        "<think type='summary' id='def456'>\nSecond\n</think>\n",
                        "<think type='summary' id='unknown'>\nThird\n</think>\n",
                        "391"
                    ]
                |>
            }
        ],
        <| $storedReasoning, "def456" -> <| "Signature" -> ByteArray @ { 1, 2, 3 }, "Service" -> "OpenAI" |> |>
    ],
    {
        <|
            "Role"    -> "Assistant",
            "Content" -> {
                <| "Type" -> "Reasoning", "Signature" -> $signature |>,
                <| "Type" -> "Text", "Data" -> "Let me check." |>,
                <| "Type" -> "Reasoning", "Signature" -> ByteArray @ { 1, 2, 3 } |>,
                <| "Type" -> "Text", "Data" -> "391" |>
            }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "Messages-Multiple-Summaries@@Tests/Reasoning.wlt:636,1-668,2"
]

VerificationTest[
    withReasoningData[
        Wolfram`Chatbook`Common`convertReasoningMessages[
            $openAISettings,
            {
                <|
                    "Role"         -> "Assistant",
                    "Content"      -> "<think type='summary' id='abc123'>\nChecking\n</think>",
                    "ToolRequests" -> { "request" }
                |>
            }
        ],
        $storedReasoning
    ],
    {
        <|
            "Role"         -> "Assistant",
            "Content"      -> { <| "Type" -> "Reasoning", "Signature" -> $signature |> },
            "ToolRequests" -> { "request" }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "Messages-Tool-Request@@Tests/Reasoning.wlt:670,1-693,2"
]

VerificationTest[
    withReasoningData[
        Wolfram`Chatbook`Common`convertReasoningMessages[
            $openAISettings,
            {
                <|
                    "Role"    -> "Assistant",
                    "Content" -> {
                        "<think type='summary' id='abc123'>\nChecking\n</think>\n",
                        <| "Type" -> "Text", "Data" -> "391" |>
                    }
                |>
            }
        ],
        $storedReasoning
    ],
    {
        <|
            "Role"    -> "Assistant",
            "Content" -> { <| "Type" -> "Reasoning", "Signature" -> $signature |>, <| "Type" -> "Text", "Data" -> "391" |> }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "Messages-List-Content@@Tests/Reasoning.wlt:695,1-719,2"
]

(* Submitted messages are used for estimating token usage: *)
VerificationTest[
    Wolfram`Chatbook`ChatMessages`Private`applyTokenizer[
        StringSplit,
        { <| "Type" -> "Reasoning", "Signature" -> $signature |>, <| "Type" -> "Text", "Data" -> "The answer is 391." |> }
    ],
    { "The", "answer", "is", "391." },
    SameTest -> MatchQ,
    TestID   -> "Tokenizer-Ignores-Reasoning@@Tests/Reasoning.wlt:722,1-730,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Settings*)
VerificationTest[
    withReasoningData @ {
        Wolfram`Chatbook`Common`requestMethod @ <| "RequestMethod" -> "Responses" |>,
        Wolfram`Chatbook`Common`requestMethod @ <| "RequestMethod" -> "ChatCompletions" |>,
        Wolfram`Chatbook`Common`requestMethod @ <| "RequestMethod" -> Automatic |>,
        Wolfram`Chatbook`Common`requestMethod @ <| |>
    },
    { "Responses", "ChatCompletions", "ChatCompletions", "ChatCompletions" },
    SameTest -> MatchQ,
    TestID   -> "RequestMethod@@Tests/Reasoning.wlt:735,1-745,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`requestMethod @ <| "RequestMethod" -> "Invalid" |>,
    "ChatCompletions",
    { Chatbook::InvalidRequestMethod },
    SameTest -> MatchQ,
    TestID   -> "RequestMethod-Invalid@@Tests/Reasoning.wlt:747,1-753,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = False },
        Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`Common`requestMethod @ <| "RequestMethod" -> "Responses" |>
    ],
    Failure[ "Chatbook::ResponsesAPIUnavailable", _ ],
    { Chatbook::ResponsesAPIUnavailable },
    SameTest -> MatchQ,
    TestID   -> "RequestMethod-Unavailable@@Tests/Reasoning.wlt:755,1-763,2"
]

VerificationTest[
    Wolfram`Chatbook`SendChat`Private`requestReasoningSummaries /@ {
        <| "RequestMethod" -> "Responses", "Reasoning" -> "High" |>,
        <| "RequestMethod" -> "Responses", "Reasoning" -> "None" |>,
        <| "RequestMethod" -> "Responses", "Reasoning" -> <| "effort" -> "low" |> |>,
        <| "RequestMethod" -> "Responses", "Reasoning" -> Automatic |>,
        <| "RequestMethod" -> "ChatCompletions", "Reasoning" -> "High" |>
    },
    {
        <| "RequestMethod" -> "Responses", "Reasoning" -> <| "effort" -> "high", "summary" -> "auto" |> |>,
        <| "RequestMethod" -> "Responses", "Reasoning" -> "None" |>,
        <| "RequestMethod" -> "Responses", "Reasoning" -> <| "effort" -> "low" |> |>,
        <| "RequestMethod" -> "Responses", "Reasoning" -> Automatic |>,
        <| "RequestMethod" -> "ChatCompletions", "Reasoning" -> "High" |>
    },
    SameTest -> MatchQ,
    TestID   -> "RequestReasoningSummaries@@Tests/Reasoning.wlt:765,1-782,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True },
        Table[
            Wolfram`Chatbook`Settings`Private`$modelAutoSettings[ service, family, "RequestMethod" ],
            { service, { "OpenAI", "LLMKit" } },
            { family, { "GPT5", "GPT51", "GPT52", "GPT53", "GPT53Chat", "GPT54Plus" } }
        ]
    ],
    ConstantArray[ "Responses", { 2, 6 } ],
    SameTest -> MatchQ,
    TestID   -> "ModelAutoSettings-Responses@@Tests/Reasoning.wlt:784,1-795,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = False },
        Wolfram`Chatbook`Settings`Private`$modelAutoSettings[ "OpenAI", "GPT54Plus", "RequestMethod" ]
    ],
    "ChatCompletions",
    SameTest -> MatchQ,
    TestID   -> "ModelAutoSettings-Responses-Unavailable@@Tests/Reasoning.wlt:797,1-804,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True },
        Wolfram`Chatbook`Settings`Private`resolveAutoSetting0[ <| "Model" -> #1 |>, "RequestMethod" ] & /@ {
            <| "Service" -> "OpenAI", "Name" -> "gpt-5.4-responses-test" |>,
            <| "Service" -> "LLMKit", "Name" -> "gpt-5.6-responses-test" |>,
            <| "Service" -> "OpenAI", "Name" -> "gpt-4.1-responses-test" |>,
            <| "Service" -> "AzureOpenAI", "Name" -> "gpt-5.4-responses-test" |>,
            <| "Service" -> "Anthropic", "Name" -> "claude-opus-4-7-responses-test" |>
        }
    ],
    { "Responses", "Responses", "ChatCompletions", "ChatCompletions", "ChatCompletions" },
    SameTest -> MatchQ,
    TestID   -> "ResolveAutoSetting-RequestMethod@@Tests/Reasoning.wlt:806,1-819,2"
]

VerificationTest[
    Wolfram`Chatbook`Settings`Private`autoStopTokens @ <| "RequestMethod" -> "Responses", "ToolMethod" -> "Simple" |>,
    Missing[ "NotSupported" ],
    SameTest -> MatchQ,
    TestID   -> "AutoStopTokens-Responses@@Tests/Reasoning.wlt:821,1-826,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Attachments*)
VerificationTest[
    withReasoningData[
        GetAttachments[ $messages, "Reasoning" ],
        <| $storedReasoning, "unused" -> <| "Signature" -> ByteArray @ { 1 }, "Service" -> "OpenAI" |> |>
    ],
    $storedReasoning,
    SameTest -> MatchQ,
    TestID   -> "GetAttachments-Reasoning@@Tests/Reasoning.wlt:831,1-839,2"
]

VerificationTest[
    withReasoningData[ KeyTake[ GetAttachments[ $messages ], "Reasoning" ], $storedReasoning ],
    <| "Reasoning" -> $storedReasoning |>,
    SameTest -> MatchQ,
    TestID   -> "GetAttachments-All-Includes-Reasoning@@Tests/Reasoning.wlt:841,1-846,2"
]

VerificationTest[
    withReasoningData[ LoadAttachments[ "Reasoning", $storedReasoning ]; Wolfram`Chatbook`Common`$reasoningData ],
    $storedReasoning,
    SameTest -> MatchQ,
    TestID   -> "LoadAttachments-Reasoning@@Tests/Reasoning.wlt:848,1-853,2"
]

VerificationTest[
    Module[ { appName, uuid, saved, loaded, restored },
        appName = "ChatbookReasoningTests";
        uuid    = CreateUUID[ ];
        Block[ { Wolfram`Chatbook`Common`$noSemanticSearch = True },
            withReasoningData[
                saved = SaveChat[
                    $messages,
                    <| "AppName" -> appName, "ConversationUUID" -> uuid, "ConversationTitle" -> "Reasoning Test" |>
                ];
                (* Simulate a new kernel session: *)
                Wolfram`Chatbook`Common`$reasoningData = <| |>;
                loaded = LoadChat[ appName, uuid ];
                restored = Wolfram`Chatbook`Common`$reasoningData,
                $storedReasoning
            ]
        ];
        DeleteChat[ appName, uuid ];
        { saved, loaded[ "Attachments", "Reasoning" ], restored }
    ],
    { _Success, $storedReasoning, $storedReasoning },
    SameTest -> MatchQ,
    TestID   -> "SaveChat-LoadChat-Reasoning@@Tests/Reasoning.wlt:855,1-878,2"
]

(* :!CodeAnalysis::EndBlock:: *)
