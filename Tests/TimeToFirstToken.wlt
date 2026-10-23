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

(* The "TimeToFirstToken" handler argument is the time from the start of the chat action until the first content of
   the response has been written. These tests simulate the body chunks that the chat handlers receive while streaming. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    $ttftSettings = Wolfram`Chatbook`Common`resolveAutoSettings @ <|
        Wolfram`Chatbook`Common`$defaultChatSettings,
        "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>
    |>;

    ttftContentChunk[ text_String ] :=
        <| "BodyChunk" -> "", "BodyChunkProcessed" -> { <| "Type" -> "Text", "Data" -> text |> } |>;

    (* A chunk without any content, e.g. a keep-alive or one that only has metadata: *)
    $ttftEmptyChunk = <| "BodyChunk" -> "", "BodyChunkProcessed" -> { } |>;

    (* Evaluates `eval` with isolated handler data, timing log, and output container: *)
    withTTFTData // Attributes = { HoldFirst };
    withTTFTData[ eval_ ] := Block[
        {
            Wolfram`Chatbook`$ChatHandlerData      = <| |>,
            Wolfram`Chatbook`Common`$chatStartTime = None,
            Wolfram`Chatbook`Common`$timingLog     = Internal`Bag[ ],
            $ttftContainer                         = <| "DynamicContent" -> "", "FullContent" -> "" |>
        },
        eval
    ];

    (* Creates the handlers that are given to ChatSubmit when sending a chat: *)
    ttftHandlers[ ] := Wolfram`Chatbook`SendChat`Private`chatHandlers[ $ttftContainer, None, $ttftSettings ];

    ttftSendChunk[ handlers_, chunk_ ] := handlers[ "BodyChunkReceived" ][ chunk ];

    ttftValue[ ] := Wolfram`Chatbook`$ChatHandlerData[ "TimeToFirstToken" ];

    ttftTimingEntries[ ] := Cases[
        Internal`BagPart[ Wolfram`Chatbook`Common`$timingLog, All ],
        KeyValuePattern[ "Tag" -> "TimeToFirstToken" ],
        Infinity
    ];

    ttftSecondsQ[ min_, max_ ][ q_ ] := MatchQ[ q, Quantity[ _Real? (min <= # < max &), "Seconds" ] ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*timeToFirstTokenHandler*)
VerificationTest[
    withTTFTData @ Module[ { record, results },
        record = Wolfram`Chatbook`SendChat`Private`timeToFirstTokenHandler[ AbsoluteTime[ ] - 1.5 ];
        results = record /@ {
            <| "ExtractedBodyChunks" -> { } |>,
            <| "BodyChunk" -> "" |>
        };
        record @ <| "ExtractedBodyChunks" -> { "Hello" } |>;
        record @ <| "ExtractedBodyChunks" -> { " world" } |>;
        {
            results,
            ttftSecondsQ[ 1.5, 2.0 ] @ ttftValue[ ],
            Length @ ttftTimingEntries[ ]
        }
    ],
    { { Null, Null }, True, 1 },
    SameTest -> MatchQ,
    TestID   -> "TimeToFirstTokenHandler-FirstContent"
]

(* A chat that already has a time to first token (e.g. handlers created for a tool call response) keeps it: *)
VerificationTest[
    withTTFTData[
        Wolfram`Chatbook`$ChatHandlerData = <| "TimeToFirstToken" -> Quantity[ 1.25, "Seconds" ] |>;
        Wolfram`Chatbook`SendChat`Private`timeToFirstTokenHandler[ AbsoluteTime[ ] - 5.0 ][
            <| "ExtractedBodyChunks" -> { "Hello" } |>
        ];
        { ttftValue[ ], ttftTimingEntries[ ] }
    ],
    { Quantity[ 1.25, "Seconds" ], { } },
    SameTest -> MatchQ,
    TestID   -> "TimeToFirstTokenHandler-AlreadyRecorded"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Handlers*)

(* Handlers called while the chat action is still evaluating (e.g. EvaluateChatInput waits for the task): *)
VerificationTest[
    withTTFTData @ Wolfram`Chatbook`Common`catchTop @ Module[ { handlers, values },
        handlers = ttftHandlers[ ];
        Pause[ 0.2 ];
        ttftSendChunk[ handlers, $ttftEmptyChunk ];
        values = { ttftValue[ ] };
        Pause[ 0.3 ];
        ttftSendChunk[ handlers, ttftContentChunk[ "Hello" ] ];
        AppendTo[ values, ttftValue[ ] ];
        Pause[ 0.2 ];
        ttftSendChunk[ handlers, ttftContentChunk[ " world" ] ];
        AppendTo[ values, ttftValue[ ] ];
        {
            values,
            ttftSecondsQ[ 0.45, 0.7 ] @ values[[ 2 ]],
            $ttftContainer[ "FullContent" ],
            Length @ ttftTimingEntries[ ]
        }
    ],
    { { _Missing, ttft_Quantity, ttft_ }, True, "Hello world", 1 },
    SameTest -> MatchQ,
    TestID   -> "ChatHandlers-InsideChatAction"
]

(* Handlers called after the chat action has returned (e.g. SendChat), where each handler call is a new catchTop: *)
VerificationTest[
    withTTFTData @ Module[ { handlers, values, entries },
        handlers = Wolfram`Chatbook`Common`catchTop @ ttftHandlers[ ];
        Pause[ 0.5 ];
        ttftSendChunk[ handlers, ttftContentChunk[ "Hello" ] ];
        values = { ttftValue[ ] };
        Pause[ 0.2 ];
        ttftSendChunk[ handlers, ttftContentChunk[ " world" ] ];
        AppendTo[ values, ttftValue[ ] ];
        entries = ttftTimingEntries[ ];
        {
            values,
            ttftSecondsQ[ 0.45, 0.7 ] @ First @ values,
            Length @ entries,
            (* The timing entry is also relative to the start of the chat action: *)
            Abs[ entries[[ 1, "ChatTime" ]] - QuantityMagnitude @ First @ values ] < 0.01,
            $ttftContainer[ "FullContent" ]
        }
    ],
    { { ttft_Quantity, ttft_ }, True, 1, True, "Hello world" },
    SameTest -> MatchQ,
    TestID   -> "ChatHandlers-AfterChatAction"
]

(* The same, but with the chunks arriving asynchronously, as they do from ChatSubmit: *)
VerificationTest[
    withTTFTData @ Module[ { handlers, values = { }, count = 0 },
        handlers = Wolfram`Chatbook`Common`catchTop @ ttftHandlers[ ];
        TaskWait @ SessionSubmit @ ScheduledTask[
            count++;
            ttftSendChunk[ handlers, If[ count === 1, $ttftEmptyChunk, ttftContentChunk[ "x" ] ] ];
            AppendTo[ values, ttftValue[ ] ];
            If[ count >= 3, TaskRemove @ $CurrentTask ],
            { 0.25, 3 }
        ];
        { values, ttftSecondsQ[ 0.4, 0.75 ] @ values[[ 2 ]], $ttftContainer[ "FullContent" ] }
    ],
    { { _Missing, ttft_Quantity, ttft_ }, True, "xx" },
    SameTest -> MatchQ,
    TestID   -> "ChatHandlers-AfterChatAction-Async"
]

(* Handlers created for tool call responses do not record it again, but the next chat does: *)
VerificationTest[
    withTTFTData @ Module[ { first, toolResponse, nextChat },
        Wolfram`Chatbook`Common`catchTop[
            ttftSendChunk[ ttftHandlers[ ], ttftContentChunk[ "Hello" ] ];
            first = ttftValue[ ];
            Pause[ 0.3 ];
            ttftSendChunk[ ttftHandlers[ ], ttftContentChunk[ " world" ] ];
            toolResponse = ttftValue[ ]
        ];
        (* The handler data is reset for each chat: *)
        Wolfram`Chatbook`$ChatHandlerData = <| |>;
        Wolfram`Chatbook`Common`catchTop @ With[ { handlers = ttftHandlers[ ] },
            Pause[ 0.2 ];
            ttftSendChunk[ handlers, ttftContentChunk[ "Hi" ] ];
            nextChat = ttftValue[ ]
        ];
        {
            ttftSecondsQ[ 0.0, 0.15 ] @ first,
            toolResponse === first,
            ttftSecondsQ[ 0.15, 0.4 ] @ nextChat,
            Length @ ttftTimingEntries[ ]
        }
    ],
    { True, True, True, 2 },
    SameTest -> MatchQ,
    TestID   -> "ChatHandlers-ToolCallResponse"
]

(* :!CodeAnalysis::EndBlock:: *)
