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
        "abc123" -> <|
            "Signature" -> $signature,
            "CallID"    -> "rs_123",
            "Service"   -> "OpenAI",
            "Model"     -> "gpt-5.4",
            "Duration"  -> 3.2
        |>
    |>;

    (* Evaluates `eval` with an isolated reasoning store and stream state: *)
    withReasoningData // Attributes = { HoldFirst };
    withReasoningData[ eval_, data_: <| |> ] := Block[
        {
            Wolfram`Chatbook`Common`$reasoningData                = data,
            Wolfram`Chatbook`Reasoning`Private`$reasoningStreamID = None,
            Wolfram`Chatbook`Reasoning`Private`$reasoningStart    = None,
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
    TestID   -> "Definitions@@Tests/Reasoning.wlt:25,1-105,2"
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
    TestID   -> "ThinkTagAttributes@@Tests/Reasoning.wlt:110,1-123,2"
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
    TestID   -> "ReasoningIDs@@Tests/Reasoning.wlt:125,1-135,2"
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
            "Model"     -> "gpt-5.4",
            "Duration"  -> 3.2
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "Format-Summary@@Tests/Reasoning.wlt:140,1-164,2"
]

(* Without a summary, only the label is shown (no opener): *)
VerificationTest[
    withReasoningData[
        FirstCase[
            FormatChatOutput[ "<think type='summary' id='abc123'>\n\n</think>\nThe answer is 391." ],
            TemplateBox[ { text_, label_, meta_ }, name_String ] /; StringContainsQ[ name, "Thought" ] :>
                { name, text, label, meta },
            $Failed,
            Infinity
        ],
        $storedReasoning
    ],
    {
        "EmptyThoughts",
        "",
        s_String /; StringContainsQ[ s, " 3 " ],
        KeyValuePattern @ { "Type" -> "Summary", "ID" -> "abc123", "Signature" -> $signature }
    },
    SameTest -> MatchQ,
    TestID   -> "Format-Empty-Summary@@Tests/Reasoning.wlt:167,1-186,2"
]

(* The signature of a reasoning item without a summary still gets sent when the chat output is from a previous kernel
   session: *)
VerificationTest[
    Module[ { cell },
        cell = withReasoningData[
            Cell[ FormatChatOutput[ "<think type='summary' id='abc123'>\n\n</think>\nThe answer is 391." ][[ 1, 1 ]], "ChatOutput" ],
            $storedReasoning
        ];
        withReasoningData @ {
            CellToString @ cell,
            Wolfram`Chatbook`Common`convertReasoningMessages[ $openAISettings, { CellToChatMessage @ cell } ]
        }
    ],
    {
        s_String /; StringMatchQ[ s, "<think type='summary' id='abc123'>\n\n</think>" ~~ WhitespaceCharacter... ~~ "The answer is 391." ],
        {
            <|
                "Role"    -> "Assistant",
                "Content" -> {
                    <| "Type" -> "Reasoning", "Signature" -> $signature, "CallID" -> "rs_123" |>,
                    <| "Type" -> "Text", "Data" -> "The answer is 391." |>
                }
            |>
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Empty-Summary-Cell-Message-Restores-Signature@@Tests/Reasoning.wlt:190,1-215,2"
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
    TestID   -> "Format-Summary-In-Progress@@Tests/Reasoning.wlt:217,1-227,2"
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
    TestID   -> "Format-Summary-Just-Started@@Tests/Reasoning.wlt:229,1-239,2"
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
    TestID   -> "Format-Literal@@Tests/Reasoning.wlt:241,1-251,2"
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
    TestID   -> "Format-Literal-In-Progress@@Tests/Reasoning.wlt:253,1-263,2"
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
    TestID   -> "Format-Multiple-Summaries@@Tests/Reasoning.wlt:265,1-282,2"
]

(* Each summary shows its own duration: *)
VerificationTest[
    withReasoningData[
        Cases[
            FormatChatOutput @ StringJoin[
                "<think type='summary' id='abc'>\nFirst\n</think>\n",
                "<think type='summary' id='def'>\nSecond\n</think>\n",
                "<think type='summary' id='ghi'>\nThird\n</think>\n",
                "Done"
            ],
            TemplateBox[ { _, label_, _ }, "ThoughtsOpener" ] :> label,
            Infinity
        ],
        <| "abc" -> <| "Duration" -> 7.4 |>, "def" -> <| "Duration" -> 0.3 |> |>
    ],
    {
        s1_String /; StringContainsQ[ s1, " 7 " ],
        DynamicBox[ ToBoxes[ FEPrivate`FrontEndResource[ "ChatbookStrings", "FormattingThinkingCompleteSingular" ], ___ ], ___ ],
        (* No duration is available: *)
        DynamicBox[ ToBoxes[ FEPrivate`FrontEndResource[ "ChatbookStrings", "FormattingThinkingCompleteFallback" ], ___ ], ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "Format-Summary-Duration-Labels@@Tests/Reasoning.wlt:285,1-307,2"
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
    TestID   -> "Format-Summary-Markdown@@Tests/Reasoning.wlt:310,1-327,2"
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
    TestID   -> "Format-Summary-Tool-Name@@Tests/Reasoning.wlt:330,1-340,2"
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
    TestID   -> "Format-Summary-No-Tool-Calls@@Tests/Reasoning.wlt:343,1-362,2"
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
    TestID   -> "Serialize-Summary@@Tests/Reasoning.wlt:367,1-381,2"
]

VerificationTest[
    withReasoningData[
        CellToString @ Cell[ FormatChatOutput[ "<think>\nLiteral thoughts\n</think>\nThe answer is 391." ][[ 1, 1 ]], "ChatOutput" ]
    ],
    s_String /; StringMatchQ[ s, "<think>\nLiteral thoughts\n</think>" ~~ WhitespaceCharacter... ~~ "The answer is 391." ],
    SameTest -> MatchQ,
    TestID   -> "Serialize-Literal@@Tests/Reasoning.wlt:383,1-390,2"
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
    TestID   -> "Serialize-Legacy-Two-Argument-Box@@Tests/Reasoning.wlt:392,1-403,2"
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
    TestID   -> "Serialize-Restores-Signature@@Tests/Reasoning.wlt:406,1-417,2"
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
                <| "Type" -> "Reasoning", "Signature" -> $signature, "CallID" -> "rs_123" |>,
                <| "Type" -> "Text", "Data" -> "The answer is 391." |>
            }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ChatOutput-Cell-Message-Restores-Signature@@Tests/Reasoning.wlt:420,1-447,2"
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
        {
            <|
                "Signature" -> $signature,
                "CallID"    -> "rs_123",
                "Service"   -> "OpenAI",
                "Model"     -> "gpt-5.4",
                "Duration"  -> _Real? NonNegative
            |>
        },
        None
    },
    SameTest -> MatchQ,
    TestID   -> "Stream-Summary@@Tests/Reasoning.wlt:452,1-482,2"
]

VerificationTest[
    withReasoningData @ StringMatchQ[
        streamChunks[ $openAISettings, { $streamedChunks } ],
        $summaryPattern ~~ "**Multiplying**\n\nI need to multiply 17 by 23.\n</think>\n391"
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Stream-Summary-Batched@@Tests/Reasoning.wlt:484,1-492,2"
]

VerificationTest[
    withReasoningData @ Module[ { string },
        string = streamChunks[ $llmKitSettings, List /@ $streamedChunks ];
        Lookup[ Values @ Wolfram`Chatbook`Common`$reasoningData, "Service" ]
    ],
    { "LLMKit" },
    SameTest -> MatchQ,
    TestID   -> "Stream-Summary-LLMKit-Service@@Tests/Reasoning.wlt:494,1-502,2"
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
    TestID   -> "Stream-Summary-Leading-Separator@@Tests/Reasoning.wlt:505,1-521,2"
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
    TestID   -> "Stream-Empty-Summary@@Tests/Reasoning.wlt:524,1-541,2"
]

(* If the stream moves on before the reasoning item is complete, the summary is closed without a signature (so it is
   never sent), but its duration is still recorded: *)
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
            Values @ Wolfram`Chatbook`Common`$reasoningData,
            Wolfram`Chatbook`Reasoning`Private`$reasoningStreamID
        }
    ],
    { True, { KeyValuePattern[ "Duration" -> _Real? NonNegative ]? (FreeQ[ #, "Signature" ] &) }, None },
    SameTest -> MatchQ,
    TestID   -> "Stream-Interrupted-Summary@@Tests/Reasoning.wlt:545,1-563,2"
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
    TestID   -> "Stream-Incomplete-Response@@Tests/Reasoning.wlt:565,1-579,2"
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
    TestID   -> "Stream-Empty-Reasoning-Item@@Tests/Reasoning.wlt:582,1-593,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Durations*)

(* The time for the first summary starts with the first chunk of the response, and the time for later summaries starts
   after the output that precedes them. Each ends when some other output arrives: *)
VerificationTest[
    withReasoningData @ Module[ { part, string, durations },
        part = <| "Type" -> "Reasoning", "Signature" -> $signature |>;
        string = StringJoin @ {
            streamChunks[ $openAISettings, { { <| "ResponseID" -> "resp_1", "Model" -> "gpt-5.4" |> } } ],
            Pause[ 0.3 ];
            streamChunks[ $openAISettings, { { <| "ReasoningChunk" -> "First", "Type" -> "Reasoning" |> } } ],
            Pause[ 0.3 ];
            streamChunks[ $openAISettings, { { <| "ResponseContent" -> { part } |> } } ],
            Pause[ 0.3 ];
            streamChunks[ $openAISettings, { { <| "ContentChunk" -> "Let me check." |> } } ],
            Pause[ 0.2 ];
            streamChunks[ $openAISettings, { { <| "ReasoningChunk" -> "Second", "Type" -> "Reasoning" |> } } ],
            Pause[ 0.2 ];
            streamChunks[ $openAISettings, { { <| "ResponseContent" -> { part } |> } } ],
            Pause[ 0.1 ];
            streamChunks[ $openAISettings, { { <| "FinishReason" -> "completed" |> } } ]
        };
        durations = Wolfram`Chatbook`Common`$reasoningData[ #, "Duration" ] & /@
            Wolfram`Chatbook`Common`reasoningIDs @ string;
        { Length @ durations, 0.8 < durations[[ 1 ]] < 1.3, 0.4 < durations[[ 2 ]] < 0.8 }
    ],
    { 2, True, True },
    SameTest -> MatchQ,
    TestID   -> "Stream-Reasoning-Durations@@Tests/Reasoning.wlt:601,1-626,2"
]

(* The timer restarts for each request, e.g. when tool results are sent: *)
VerificationTest[
    withReasoningData @ Module[ { part, string },
        part = <| "Type" -> "Reasoning", "Signature" -> $signature |>;
        streamChunks[ $openAISettings, { { <| "ResponseID" -> "resp_1", "Model" -> "gpt-5.4" |> } } ];
        Pause[ 0.5 ];
        Wolfram`Chatbook`Common`resetReasoningStream[ ];
        Pause[ 0.5 ];
        string = StringJoin @ {
            streamChunks[ $openAISettings, { { <| "ResponseID" -> "resp_2", "Model" -> "gpt-5.4" |> } } ],
            Pause[ 0.2 ];
            streamChunks[ $openAISettings, { { <| "ResponseContent" -> { part } |>, <| "ContentChunk" -> "391" |> } } ]
        };
        Wolfram`Chatbook`Common`$reasoningData[ First @ Wolfram`Chatbook`Common`reasoningIDs @ string, "Duration" ]
    ],
    _Real? (0.1 < # < 0.5 &),
    SameTest -> MatchQ,
    TestID   -> "Stream-Reasoning-Duration-Reset@@Tests/Reasoning.wlt:629,1-646,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Consecutive Reasoning Items*)

(* A response can contain several reasoning items in a row (some without summaries), which are shown as one summary: *)
VerificationTest[
    withReasoningData @ Module[ { sigs, string, ids },
        sigs = ByteArray /@ { { 1 }, { 2 }, { 3 } };
        string = streamChunks[
            $openAISettings,
            {
                { <| "ResponseID" -> "resp_1", "Model" -> "gpt-5.4" |> },
                { <| "ResponseContent" -> { <| "Type" -> "Reasoning", "Signature" -> sigs[[ 1 ]], "CallID" -> "rs_1" |> } |> },
                { <| "ReasoningChunk" -> "\n\n", "Type" -> "Reasoning" |>, <| "ReasoningChunk" -> "Planning", "Type" -> "Reasoning" |> },
                {
                    <|
                        "ResponseContent" -> {
                            <| "Type" -> "Reasoning", "Data" -> "Planning", "Signature" -> sigs[[ 2 ]], "CallID" -> "rs_2" |>
                        }
                    |>
                },
                { <| "ReasoningChunk" -> "\n\n", "Type" -> "Reasoning" |>, <| "ReasoningChunk" -> "Checking", "Type" -> "Reasoning" |> },
                {
                    <|
                        "ResponseContent" -> {
                            <| "Type" -> "Reasoning", "Data" -> "Checking", "Signature" -> sigs[[ 3 ]], "CallID" -> "rs_3" |>
                        }
                    |>
                },
                { <| "ContentChunk" -> "Done" |> }
            }
        ];
        ids = Wolfram`Chatbook`Common`reasoningIDs @ string;
        {
            StringMatchQ[ string, $summaryPattern ~~ WhitespaceCharacter... ~~ "Planning\n\nChecking\n</think>\nDone" ],
            Length @ ids,
            KeyTake[ Wolfram`Chatbook`Common`$reasoningData[ First @ ids ], { "Signature", "CallID" } ],
            Wolfram`Chatbook`Common`convertReasoningMessages[
                $openAISettings,
                { <| "Role" -> "Assistant", "Content" -> string |> }
            ]
        }
    ],
    {
        True,
        1,
        <| "Signature" -> ByteArray /@ { { 1 }, { 2 }, { 3 } }, "CallID" -> { "rs_1", "rs_2", "rs_3" } |>,
        {
            <|
                "Role"    -> "Assistant",
                "Content" -> {
                    <| "Type" -> "Reasoning", "Signature" -> ByteArray @ { 1 }, "CallID" -> "rs_1" |>,
                    <| "Type" -> "Reasoning", "Signature" -> ByteArray @ { 2 }, "CallID" -> "rs_2" |>,
                    <| "Type" -> "Reasoning", "Signature" -> ByteArray @ { 3 }, "CallID" -> "rs_3" |>,
                    <| "Type" -> "Text", "Data" -> "Done" |>
                }
            |>
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Stream-Consecutive-Reasoning-Items@@Tests/Reasoning.wlt:653,1-709,2"
]

(* Consecutive reasoning items without any summaries are also combined: *)
VerificationTest[
    withReasoningData @ Module[ { string },
        string = streamChunks[
            $openAISettings,
            {
                {
                    <| "ResponseContent" -> { <| "Type" -> "Reasoning", "Signature" -> ByteArray @ { 1 } |> } |>,
                    <| "ResponseContent" -> { <| "Type" -> "Reasoning", "Signature" -> ByteArray @ { 2 } |> } |>
                },
                { <| "ToolRequestsChunk" -> { } |> }
            }
        ];
        {
            string,
            Values @ Wolfram`Chatbook`Common`$reasoningData[[ All, "Signature" ]]
        }
    ],
    {
        s_String /; StringMatchQ[ s, $summaryPattern ~~ "\n</think>\n" ],
        { ByteArray /@ { { 1 }, { 2 } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Stream-Consecutive-Reasoning-Items-No-Summaries@@Tests/Reasoning.wlt:712,1-735,2"
]

VerificationTest[
    withReasoningData @ Module[ { content },
        content = Wolfram`Chatbook`Common`convertReasoningContent[
            $openAISettings,
            {
                <| "Type" -> "Reasoning", "Data" -> "First", "Signature" -> ByteArray @ { 1 }, "CallID" -> "rs_1" |>,
                <| "Type" -> "Reasoning", "Signature" -> ByteArray @ { 2 }, "CallID" -> "rs_2" |>,
                <| "Type" -> "Reasoning", "Data" -> "Second", "Signature" -> ByteArray @ { 3 }, "CallID" -> "rs_3" |>,
                <| "Type" -> "Text", "Data" -> "391" |>
            }
        ];
        {
            content,
            Values @ Wolfram`Chatbook`Common`$reasoningData[[ All, { "Signature", "CallID" } ]]
        }
    ],
    {
        {
            <| "Type" -> "Text", "Data" -> s_String /; StringMatchQ[ s, $summaryPattern ~~ "First\n\nSecond\n</think>\n" ] |>,
            <| "Type" -> "Text", "Data" -> "391" |>
        },
        { <| "Signature" -> ByteArray /@ { { 1 }, { 2 }, { 3 } }, "CallID" -> { "rs_1", "rs_2", "rs_3" } |> }
    },
    SameTest -> MatchQ,
    TestID   -> "Synchronous-Response-Consecutive-Reasoning-Items@@Tests/Reasoning.wlt:737,1-762,2"
]

(* Call IDs are only included when there's one for every signature: *)
VerificationTest[
    withReasoningData[
        Wolfram`Chatbook`Common`convertReasoningMessages[
            $openAISettings,
            { <| "Role" -> "Assistant", "Content" -> "<think type='summary' id='abc'>\nThoughts\n</think>\n391" |> }
        ],
        <| "abc" -> <| "Signature" -> ByteArray /@ { { 1 }, { 2 } }, "Service" -> "OpenAI" |> |>
    ],
    {
        <|
            "Role"    -> "Assistant",
            "Content" -> {
                <| "Type" -> "Reasoning", "Signature" -> ByteArray @ { 1 } |>,
                <| "Type" -> "Reasoning", "Signature" -> ByteArray @ { 2 } |>,
                <| "Type" -> "Text", "Data" -> "391" |>
            }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "Messages-Multiple-Signatures-Without-Call-IDs@@Tests/Reasoning.wlt:765,1-785,2"
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
    TestID   -> "Synchronous-Response-Content@@Tests/Reasoning.wlt:787,1-807,2"
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
    TestID   -> "Messages-Definition@@Tests/Reasoning.wlt:812,1-822,2"
]

VerificationTest[
    withReasoningData[ Wolfram`Chatbook`Common`convertReasoningMessages[ $openAISettings, $messages ], $storedReasoning ],
    {
        $messages[[ 1 ]],
        $messages[[ 2 ]],
        <|
            "Role"    -> "Assistant",
            "Content" -> {
                <| "Type" -> "Reasoning", "Signature" -> $signature, "CallID" -> "rs_123" |>,
                <| "Type" -> "Text", "Data" -> "391" |>
            }
        |>,
        $messages[[ 4 ]]
    },
    SameTest -> MatchQ,
    TestID   -> "Messages-Responses-Sends-Signature@@Tests/Reasoning.wlt:824,1-840,2"
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
    TestID   -> "Messages-Responses-No-Summary-Text@@Tests/Reasoning.wlt:842,1-853,2"
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
    TestID   -> "Messages-ChatCompletions-Removes-Summary@@Tests/Reasoning.wlt:855,1-866,2"
]

(* Signatures can only be used with the service that created them: *)
VerificationTest[
    withReasoningData[
        Wolfram`Chatbook`Common`convertReasoningMessages[ $llmKitSettings, $messages ][[ 3 ]],
        $storedReasoning
    ],
    <| "Role" -> "Assistant", "Content" -> "391" |>,
    SameTest -> MatchQ,
    TestID   -> "Messages-Responses-Different-Service@@Tests/Reasoning.wlt:869,1-877,2"
]

VerificationTest[
    withReasoningData[ Wolfram`Chatbook`Common`convertReasoningMessages[ $openAISettings, $messages ][[ 3 ]] ],
    <| "Role" -> "Assistant", "Content" -> "391" |>,
    SameTest -> MatchQ,
    TestID   -> "Messages-Responses-Unknown-ID@@Tests/Reasoning.wlt:879,1-884,2"
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
    TestID   -> "Messages-Other-Content-Unchanged@@Tests/Reasoning.wlt:886,1-903,2"
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
                <| "Type" -> "Reasoning", "Signature" -> $signature, "CallID" -> "rs_123" |>,
                <| "Type" -> "Text", "Data" -> "Let me check." |>,
                <| "Type" -> "Reasoning", "Signature" -> ByteArray @ { 1, 2, 3 } |>,
                <| "Type" -> "Text", "Data" -> "391" |>
            }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "Messages-Multiple-Summaries@@Tests/Reasoning.wlt:905,1-937,2"
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
            "Content"      -> { <| "Type" -> "Reasoning", "Signature" -> $signature, "CallID" -> "rs_123" |> },
            "ToolRequests" -> { "request" }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "Messages-Tool-Request@@Tests/Reasoning.wlt:939,1-962,2"
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
            "Content" -> { <| "Type" -> "Reasoning", "Signature" -> $signature, "CallID" -> "rs_123" |>, <| "Type" -> "Text", "Data" -> "391" |> }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "Messages-List-Content@@Tests/Reasoning.wlt:964,1-988,2"
]

(* Submitted messages are used for estimating token usage: *)
VerificationTest[
    Wolfram`Chatbook`ChatMessages`Private`applyTokenizer[
        StringSplit,
        { <| "Type" -> "Reasoning", "Signature" -> $signature |>, <| "Type" -> "Text", "Data" -> "The answer is 391." |> }
    ],
    { "The", "answer", "is", "391." },
    SameTest -> MatchQ,
    TestID   -> "Tokenizer-Ignores-Reasoning@@Tests/Reasoning.wlt:991,1-999,2"
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
    TestID   -> "RequestMethod@@Tests/Reasoning.wlt:1004,1-1014,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`requestMethod @ <| "RequestMethod" -> "Invalid" |>,
    "ChatCompletions",
    { Chatbook::InvalidRequestMethod },
    SameTest -> MatchQ,
    TestID   -> "RequestMethod-Invalid@@Tests/Reasoning.wlt:1016,1-1022,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = False },
        Wolfram`Chatbook`Common`catchAlways @ Wolfram`Chatbook`Common`requestMethod @ <| "RequestMethod" -> "Responses" |>
    ],
    Failure[ "Chatbook::ResponsesAPIUnavailable", _ ],
    { Chatbook::ResponsesAPIUnavailable },
    SameTest -> MatchQ,
    TestID   -> "RequestMethod-Unavailable@@Tests/Reasoning.wlt:1024,1-1032,2"
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
    TestID   -> "RequestReasoningSummaries@@Tests/Reasoning.wlt:1034,1-1051,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = True },
        Wolfram`Chatbook`Settings`Private`resolveAutoSetting0[ #1, "RequestMethod" ] & /@ {
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-5-responses-test" |> |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.4-responses-test" |> |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.6-responses-test" |> |>,
            (* Older OpenAI models: *)
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1-responses-test" |> |>,
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o-responses-test" |> |>,
            (* LLMKit does not support the responses endpoint yet: *)
            <| "Model" -> <| "Service" -> "LLMKit", "Name" -> "gpt-5.4-responses-test" |> |>,
            <|
                "Model"          -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.4-responses-test" |>,
                "Authentication" -> "LLMKit"
            |>,
            (* Other services: *)
            <| "Model" -> <| "Service" -> "AzureOpenAI", "Name" -> "gpt-5.4-responses-test" |> |>,
            <| "Model" -> <| "Service" -> "Anthropic", "Name" -> "claude-opus-4-7-responses-test" |> |>
        }
    ],
    { "Responses", "Responses", "Responses", Sequence @@ ConstantArray[ "ChatCompletions", 6 ] },
    SameTest -> MatchQ,
    TestID   -> "ResolveAutoSetting-RequestMethod@@Tests/Reasoning.wlt:1053,1-1076,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$responsesAPIAvailable = False },
        Wolfram`Chatbook`Settings`Private`resolveAutoSetting0[
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-5.4-responses-test" |> |>,
            "RequestMethod"
        ]
    ],
    "ChatCompletions",
    SameTest -> MatchQ,
    TestID   -> "ResolveAutoSetting-RequestMethod-Unavailable@@Tests/Reasoning.wlt:1078,1-1088,2"
]

VerificationTest[
    Wolfram`Chatbook`Settings`Private`autoStopTokens @ <| "RequestMethod" -> "Responses", "ToolMethod" -> "Simple" |>,
    Missing[ "NotSupported" ],
    SameTest -> MatchQ,
    TestID   -> "AutoStopTokens-Responses@@Tests/Reasoning.wlt:1090,1-1095,2"
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
    TestID   -> "GetAttachments-Reasoning@@Tests/Reasoning.wlt:1100,1-1108,2"
]

VerificationTest[
    withReasoningData[ KeyTake[ GetAttachments[ $messages ], "Reasoning" ], $storedReasoning ],
    <| "Reasoning" -> $storedReasoning |>,
    SameTest -> MatchQ,
    TestID   -> "GetAttachments-All-Includes-Reasoning@@Tests/Reasoning.wlt:1110,1-1115,2"
]

VerificationTest[
    withReasoningData[ LoadAttachments[ "Reasoning", $storedReasoning ]; Wolfram`Chatbook`Common`$reasoningData ],
    $storedReasoning,
    SameTest -> MatchQ,
    TestID   -> "LoadAttachments-Reasoning@@Tests/Reasoning.wlt:1117,1-1122,2"
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
    TestID   -> "SaveChat-LoadChat-Reasoning@@Tests/Reasoning.wlt:1124,1-1147,2"
]

(* :!CodeAnalysis::EndBlock:: *)
