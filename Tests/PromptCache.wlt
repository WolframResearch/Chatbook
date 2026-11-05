(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/PromptCache.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/PromptCache.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* Evaluates eval with $settings bound to resolved chat settings that use a counting prompt generator: *)
withCacheSettings // Attributes = { HoldRest };
withCacheSettings[ extra_Association, eval_ ] := Wolfram`Chatbook`Common`withChatState @ Module[ { settings },
    $calls     = 0;
    $generator = LLMPromptGenerator[ "Generated prompt " <> ToString[ ++$calls ] &, "Messages" ];
    settings   = Wolfram`Chatbook`Common`resolveAutoSettings @ Wolfram`Chatbook`Common`mergeChatSettings @ {
        Wolfram`Chatbook`Common`$defaultChatSettings,
        <|
            "LLMEvaluator"     -> "PlainChat",
            "Model"            -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>,
            "PromptGenerators" -> { $generator },
            extra
        |>
    };
    Block[ { $CurrentChatSettings = settings, $settings = settings }, eval ]
];

(* Constructs the messages of a request and gives them along with the sown chat data: *)
constructWithData[ settings_, messages_ ] :=
    MapAt[
        Association @* Flatten,
        Reap[ Wolfram`Chatbook`Common`constructMessages[ settings, messages ], Wolfram`Chatbook`Common`$chatDataTag ],
        2
    ];

(* The parts of messages that are sent: *)
sentMessages[ messages_ ] := KeyTake[ messages, { "Role", "Content" } ];

(* Constructs the request that follows a tool call, as toolEvaluation in SendChat.wl does: the messages of the first
   request come back in the settings' "Data" (toolLoopBaseMessages), and are followed by the tool request and the tool
   response (simplified here): *)
toolLoopMessages[ settings_, data_ ] :=
    Wolfram`Chatbook`Common`constructToolResponseMessages[
        <| settings, "Data" -> data |>,
        Join[
            Wolfram`Chatbook`SendChat`Private`toolLoopBaseMessages @ <| settings, "Data" -> data |>,
            {
                <| "Role" -> "Assistant", "Content" -> "/wl\n1 + 1\n/exec", "ToolRequest" -> True |>,
                <| "Role" -> "System", "Content" -> "2", "ToolResponse" -> True |>
            }
        ]
    ];

$firstMessages = {
    <| "Role" -> "System", "Content" -> "System prompt" |>,
    <| "Role" -> "User"  , "Content" -> "Hello"         |>
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Settings*)
VerificationTest[
    withCacheSettings[ <| |>, $settings[ "PromptCacheOptimization" ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "PromptCacheOptimization-Automatic@@Tests/PromptCache.wlt:76,1-81,2"
]

VerificationTest[
    withCacheSettings[ <| "PromptCacheOptimization" -> False |>, $settings[ "PromptCacheOptimization" ] ],
    False,
    SameTest -> MatchQ,
    TestID   -> "PromptCacheOptimization-False@@Tests/PromptCache.wlt:83,1-88,2"
]

(* Turn messages are system messages after the user message, which some services don't handle as needed: *)
VerificationTest[
    withCacheSettings[ <| "Model" -> # |>, $settings[ "PromptCacheOptimization" ] ] & /@ {
        <| "Service" -> "Anthropic", "Name" -> "claude-sonnet-4-5" |>,
        <| "Service" -> "MistralAI", "Name" -> "codestral-latest" |>,
        <| "Service" -> "TogetherAI", "Name" -> "mistralai/Mistral-7B-Instruct-v0.3" |>
    },
    { False, False, False },
    SameTest -> MatchQ,
    TestID   -> "PromptCacheOptimization-ModelDependent@@Tests/PromptCache.wlt:91,1-100,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Turn Messages*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Placement*)

(* Generated prompts are appended after the user message instead of being inserted after the system message: *)
VerificationTest[
    withCacheSettings[ <| |>, sentMessages @ First @ constructWithData[ $settings, $firstMessages ] ],
    {
        <| "Role" -> "System", "Content" -> "System prompt"      |>,
        <| "Role" -> "User"  , "Content" -> "Hello"              |>,
        <| "Role" -> "System", "Content" -> "Generated prompt 1" |>
    },
    SameTest -> MatchQ,
    TestID   -> "TurnMessages-AfterUserMessage@@Tests/PromptCache.wlt:111,1-120,2"
]

VerificationTest[
    withCacheSettings[
        <| "PromptCacheOptimization" -> False |>,
        sentMessages @ First @ constructWithData[ $settings, $firstMessages ]
    ],
    {
        <| "Role" -> "System", "Content" -> "System prompt"      |>,
        <| "Role" -> "System", "Content" -> "Generated prompt 1" |>,
        <| "Role" -> "User"  , "Content" -> "Hello"              |>
    },
    SameTest -> MatchQ,
    TestID   -> "TurnMessages-LegacyPosition@@Tests/PromptCache.wlt:122,1-134,2"
]

(* The ID of the turn's record is sown as chat data, so it can be written to the output cell: *)
VerificationTest[
    withCacheSettings[ <| |>, Last @ constructWithData[ $settings, $firstMessages ] ],
    KeyValuePattern[ "PromptCacheID" -> _String ],
    SameTest -> MatchQ,
    TestID   -> "TurnMessages-RecordID@@Tests/PromptCache.wlt:137,1-142,2"
]

VerificationTest[
    withCacheSettings[
        <| "PromptCacheOptimization" -> False |>,
        KeyExistsQ[ Last @ constructWithData[ $settings, $firstMessages ], "PromptCacheID" ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "TurnMessages-NoRecordIDLegacy@@Tests/PromptCache.wlt:144,1-152,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Loop*)

(* The request after a tool call only appends to the messages of the first request: *)
VerificationTest[
    withCacheSettings[
        <| |>,
        Module[ { first, data, second },
            { first, data } = constructWithData[ $settings, $firstMessages ];
            second = toolLoopMessages[ $settings, data ];
            {
                $calls,
                Take[ sentMessages @ second, Length @ first ] === sentMessages @ first,
                Length @ second - Length @ first
            }
        ]
    ],
    { 1, True, 2 },
    SameTest -> MatchQ,
    TestID   -> "TurnMessages-ToolLoopAppendsOnly@@Tests/PromptCache.wlt:159,1-175,2"
]

(* Prompt generators do not run again after a tool call, even if they did not give anything the first time: *)
VerificationTest[
    withCacheSettings[
        <| "PromptGenerators" -> { LLMPromptGenerator[ (++$emptyCalls; "") &, "Messages" ] } |>,
        Module[ { first, data },
            $emptyCalls = 0;
            { first, data } = constructWithData[ $settings, $firstMessages ];
            toolLoopMessages[ $settings, data ];
            $emptyCalls
        ]
    ],
    1,
    SameTest -> MatchQ,
    TestID   -> "TurnMessages-ToolLoopNoRerun@@Tests/PromptCache.wlt:178,1-191,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*History*)

(* Converts cells to messages for a request, as the history of a chat notebook is converted: *)
turnRequest[ settings_, cells_ ] := constructWithData[ settings, cells ];

(* The output cell of the first turn refers to the record, so its messages are sent again in the second turn and the
   first request is a prefix of the second one: *)
VerificationTest[
    withCacheSettings[
        <| |>,
        Module[ { first, data, output, second },
            { first, data } = turnRequest[ $settings, { Cell[ "Hello", "ChatInput" ] } ];
            output = Cell[ "Hi there", "ChatOutput", TaggingRules -> <| "PromptCacheID" -> data[ "PromptCacheID" ] |> ];
            second = First @ turnRequest[ $settings, { Cell[ "Hello", "ChatInput" ], output, Cell[ "Next", "ChatInput" ] } ];
            {
                Take[ sentMessages @ second, Length @ first ] === sentMessages @ first,
                Cases[ sentMessages @ Drop[ second, Length @ first ], KeyValuePattern[ "Content" -> c_ ] :> c ]
            }
        ]
    ],
    { True, { "Hi there", "Next", "Generated prompt 2" } },
    SameTest -> MatchQ,
    TestID   -> "TurnMessages-HistoryPrefix@@Tests/PromptCache.wlt:202,1-218,2"
]

(* Without a record (e.g. after restarting the kernel), the history is converted from the cells only: *)
VerificationTest[
    withCacheSettings[
        <| |>,
        Cases[
            sentMessages @ First @ turnRequest[
                $settings,
                {
                    Cell[ "Hello", "ChatInput" ],
                    Cell[ "Hi there", "ChatOutput", TaggingRules -> <| "PromptCacheID" -> "not-a-record" |> ],
                    Cell[ "Next", "ChatInput" ]
                }
            ],
            KeyValuePattern[ "Content" -> c_String ] /; StringStartsQ[ c, "Generated prompt" ] :> c
        ]
    ],
    { "Generated prompt 1" },
    SameTest -> MatchQ,
    TestID   -> "TurnMessages-HistoryMissingRecord@@Tests/PromptCache.wlt:221,1-239,2"
]

(* Records are only used with the PromptCacheOptimization setting: *)
VerificationTest[
    Module[ { data },
        data = withCacheSettings[ <| |>, Last @ turnRequest[ $settings, { Cell[ "Hello", "ChatInput" ] } ] ];
        withCacheSettings[
            <| "PromptCacheOptimization" -> False |>,
            Cases[
                sentMessages @ First @ turnRequest[
                    $settings,
                    {
                        Cell[ "Hello", "ChatInput" ],
                        Cell[ "Hi there", "ChatOutput", TaggingRules -> <| "PromptCacheID" -> data[ "PromptCacheID" ] |> ],
                        Cell[ "Next", "ChatInput" ]
                    }
                ],
                KeyValuePattern[ "Content" -> c_String ] /; StringStartsQ[ c, "Generated prompt" ] :> c
            ]
        ]
    ],
    { "Generated prompt 1" },
    SameTest -> MatchQ,
    TestID   -> "TurnMessages-HistoryLegacy@@Tests/PromptCache.wlt:242,1-263,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Token Budget*)

(* Each request of a chat starts with a new chat state: *)
cacheRequest[ extra_, cells_ ] := withCacheSettings[ extra, constructWithData[ $settings, cells ] ];

(* Turn messages in the history that don't fit in the token budget are left out instead of being shortened: *)
VerificationTest[
    Module[ { extra, cells, data, messages },
        extra = <|
            "MaxContextTokens" -> 4000,
            "PromptGenerators" -> { LLMPromptGenerator[ StringRepeat[ "generated ", 300 ] &, "Messages" ] }
        |>;
        cells = { };
        Do[
            AppendTo[ cells, Cell[ "question " <> ToString @ i, "ChatInput" ] ];
            data = Last @ cacheRequest[ extra, cells ];
            AppendTo[
                cells,
                Cell[ "answer " <> ToString @ i, "ChatOutput", TaggingRules -> <| "PromptCacheID" -> data[ "PromptCacheID" ] |> ]
            ],
            { i, 8 }
        ];
        messages = First @ cacheRequest[ extra, Append[ cells, Cell[ "last question", "ChatInput" ] ] ];
        {
            MatchQ[ messages, { __Association } ],
            0 < Count[ messages, KeyValuePattern[ "PromptGenerated" -> True ] ] < 9
        }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "TurnMessages-HistoryOverBudget@@Tests/PromptCache.wlt:273,1-298,2"
]

(* Turns without turn messages don't need a record: *)
VerificationTest[
    Module[ { data },
        data = Last @ cacheRequest[ <| "PromptGenerators" -> { } |>, { Cell[ "Hello", "ChatInput" ] } ];
        { StringQ @ data[ "PromptCacheID" ], Wolfram`Chatbook`PromptCache`Private`promptCacheRecord @ data[ "PromptCacheID" ] }
    ],
    { True, _Missing },
    SameTest -> MatchQ,
    TestID   -> "TurnMessages-NoEmptyRecords@@Tests/PromptCache.wlt:301,1-309,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Base Prompt Hints*)

(* A prompt generator that makes base prompt components needed, like content of the conversation would: *)
needsGenerator[ names_ ] := LLMPromptGenerator[ (Wolfram`Chatbook`Common`needsBasePrompt /@ names; "Generated") &, "Messages" ];

$cellLabelsText = "NEVER include \"In[...]:=\"";
$audioText      = "![label](audio://content-id) represents an interactive audio player";
$firstCells     = { Cell[ "Hello", "ChatInput" ] };

contentString[ message_ ] := StringJoin @ Flatten @ { message[ "Content" ] };
systemContent[ messages_ ] := contentString @ First @ messages;
hintCount[ messages_ ] := Total[ StringCount[ contentString @ #, "<system-hint>" ] & /@ messages ];

(* Components needed because of the content are sent as a hint after the user message instead of in the system prompt: *)
VerificationTest[
    withCacheSettings[
        <| "PromptGenerators" -> { needsGenerator @ { "CellLabels" } } |>,
        Module[ { messages },
            messages = First @ constructWithData[ $settings, $firstCells ];
            {
                StringContainsQ[ systemContent @ messages, $cellLabelsText ],
                Lookup[ messages, "Role" ],
                StringContainsQ[ contentString @ Last @ messages, "<system-hint>" ~~ ___ ~~ $cellLabelsText ]
            }
        ]
    ],
    { False, { "System", "User", "System" }, True },
    SameTest -> MatchQ,
    TestID   -> "BasePromptHints-NotInSystemPrompt@@Tests/PromptCache.wlt:327,1-342,2"
]

VerificationTest[
    withCacheSettings[
        <| "PromptCacheOptimization" -> False, "PromptGenerators" -> { needsGenerator @ { "CellLabels" } } |>,
        Module[ { messages },
            messages = First @ constructWithData[ $settings, $firstCells ];
            { StringContainsQ[ systemContent @ messages, $cellLabelsText ], hintCount @ messages }
        ]
    ],
    { True, 0 },
    SameTest -> MatchQ,
    TestID   -> "BasePromptHints-Legacy@@Tests/PromptCache.wlt:344,1-355,2"
]

(* The system prompt doesn't depend on the content of the conversation: *)
VerificationTest[
    Table[
        SameQ @@ Table[
            withCacheSettings[
                <| "LLMEvaluator" -> persona, "PromptGenerators" -> { needsGenerator @ names } |>,
                systemContent @ First @ constructWithData[ $settings, $firstCells ]
            ],
            { names, { { }, { "CellLabels" }, { "MarkdownImageBox", "Checkboxes" } } }
        ],
        { persona, { "PlainChat", "CodeAssistant" } }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "BasePromptHints-SameSystemPrompt@@Tests/PromptCache.wlt:358,1-372,2"
]

(* A hint is sent once per conversation: *)
VerificationTest[
    Module[ { extra, first, data, second },
        extra = <| "PromptGenerators" -> { needsGenerator @ { "CellLabels" } } |>;
        { first, data } = cacheRequest[ extra, $firstCells ];
        second = First @ cacheRequest[
            extra,
            {
                Cell[ "Hello", "ChatInput" ],
                Cell[ "Hi there", "ChatOutput", TaggingRules -> <| "PromptCacheID" -> data[ "PromptCacheID" ] |> ],
                Cell[ "Next", "ChatInput" ]
            }
        ];
        {
            Take[ sentMessages @ second, Length @ first ] === sentMessages @ first,
            hintCount @ first,
            hintCount @ second
        }
    ],
    { True, 1, 1 },
    SameTest -> MatchQ,
    TestID   -> "BasePromptHints-OncePerConversation@@Tests/PromptCache.wlt:375,1-396,2"
]

(* Components needed after a tool call are sent as a hint with the other turn messages, before the response: *)
VerificationTest[
    withCacheSettings[
        <| |>,
        Module[ { first, data, second, third },
            { first, data } = constructWithData[ $settings, $firstCells ];
            Wolfram`Chatbook`Common`needsBasePrompt[ "SpecialURIAudio" ];
            second = toolLoopMessages[ $settings, data ];
            third  = toolLoopMessages[ $settings, data ];
            {
                systemContent @ second === systemContent @ first,
                Lookup[ second, "Role" ],
                StringContainsQ[ contentString @ second[[ 3 ]], "<system-hint>" ~~ ___ ~~ $audioText ],
                sentMessages @ third === sentMessages @ second,
                Length @ Wolfram`Chatbook`PromptCache`Private`promptCacheRecord[ data[ "PromptCacheID" ] ][ "Messages" ]
            }
        ]
    ],
    { True, { "System", "User", "System", "Assistant", "System" }, True, True, 2 },
    SameTest -> MatchQ,
    TestID   -> "BasePromptHints-ToolLoop@@Tests/PromptCache.wlt:399,1-419,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Disabled Prompts*)

(* Instructions that are removed from the system prompt after a tool call without prompt cache optimization are disabled
   with a hint instead, once per turn: *)
VerificationTest[
    withCacheSettings[
        <| |>,
        Module[ { first, data, second, third },
            Wolfram`Chatbook`Common`needsBasePrompt[ "AutoAssistant" ];
            { first, data } = constructWithData[ $settings, $firstCells ];
            second = toolLoopMessages[ $settings, data ];
            third  = toolLoopMessages[ $settings, data ];
            {
                StringContainsQ[ systemContent @ first, "[INFO]" ],
                StringContainsQ[ contentString @ Last @ first, "[INFO]" ],
                StringCount[ contentString @ second[[ 3 ]], "already started this response" ],
                sentMessages @ third === sentMessages @ second
            }
        ]
    ],
    { False, True, 1, True },
    SameTest -> MatchQ,
    TestID   -> "DisabledPromptHints-AutoAssistant@@Tests/PromptCache.wlt:427,1-446,2"
]

(* Instructions that are meant for one response are scoped to it, and sent again in each turn that needs them: *)
VerificationTest[
    Module[ { cells, data1, data2, second, third },
        data1 = withCacheSettings[
            <| |>,
            Wolfram`Chatbook`Common`needsBasePrompt[ "AutoAssistant" ];
            Last @ constructWithData[ $settings, $firstCells ]
        ];
        cells = {
            Cell[ "Hello", "ChatInput" ],
            Cell[ "[INFO] Hi there", "ChatOutput", TaggingRules -> <| "PromptCacheID" -> data1[ "PromptCacheID" ] |> ],
            Cell[ "Next", "ChatInput" ]
        };
        (* A turn without automatic assistance: *)
        { second, data2 } = withCacheSettings[
            <| |>,
            Module[ { d }, d = Last @ constructWithData[ $settings, cells ]; { toolLoopMessages[ $settings, d ], d } ]
        ];
        (* Another turn with automatic assistance: *)
        third = withCacheSettings[
            <| |>,
            Wolfram`Chatbook`Common`needsBasePrompt[ "AutoAssistant" ];
            First @ constructWithData[
                $settings,
                Join[
                    cells,
                    {
                        Cell[ "Ok", "ChatOutput", TaggingRules -> <| "PromptCacheID" -> data2[ "PromptCacheID" ] |> ],
                        Cell[ "Last", "ChatInput" ]
                    }
                ]
            ]
        ];
        {
            StringCount[ StringJoin[ contentString /@ second ], "already started this response" ],
            StringCount[ contentString @ Last @ third, "instructions for your response to the user's latest message" ],
            StringCount[ StringJoin[ contentString /@ third ], "ALWAYS begin your response" ]
        }
    ],
    { 0, 1, 2 },
    SameTest -> MatchQ,
    TestID   -> "BasePromptHints-PerTurn@@Tests/PromptCache.wlt:449,1-490,2"
]

VerificationTest[
    withCacheSettings[
        <| "ToolCallFrequency" -> 1 |>,
        Module[ { first, data },
            { first, data } = constructWithData[ $settings, $firstCells ];
            {
                StringContainsQ[ systemContent @ first, "User Tool Call Preferences" ],
                StringCount[ contentString @ toolLoopMessages[ $settings, data ][[ 3 ]], "frequency preference" ]
            }
        ]
    ],
    { True, 1 },
    SameTest -> MatchQ,
    TestID   -> "DisabledPromptHints-ToolCallFrequency@@Tests/PromptCache.wlt:492,1-506,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool Call Retry*)

(* The retry instructions are part of the system prompt instead of a temporary message after each tool response: *)
VerificationTest[
    withCacheSettings[
        <| "ToolCallRetryMessage" -> True |>,
        {
            StringContainsQ[ systemContent @ First @ constructWithData[ $settings, $firstCells ], "before retrying" ],
            Length @ Wolfram`Chatbook`SendChat`Private`makeToolResponseMessage[ $settings, "2", None ]
        }
    ],
    { True, 1 },
    SameTest -> MatchQ,
    TestID   -> "ToolCallRetry-SystemPrompt@@Tests/PromptCache.wlt:513,1-524,2"
]

VerificationTest[
    withCacheSettings[
        <| "PromptCacheOptimization" -> False, "ToolCallRetryMessage" -> True |>,
        {
            StringContainsQ[ systemContent @ First @ constructWithData[ $settings, $firstCells ], "before retrying" ],
            Length @ Wolfram`Chatbook`SendChat`Private`makeToolResponseMessage[ $settings, "2", None ]
        }
    ],
    { False, 2 },
    SameTest -> MatchQ,
    TestID   -> "ToolCallRetry-Legacy@@Tests/PromptCache.wlt:526,1-537,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*History*)

(* The requests for a conversation with more and more history (each in its own chat state, like in a chat): *)
historyRequests[ extra_Association ] := Table[
    First @ cacheRequest[
        <| "MaxContextTokens" -> 20000, "MaxCellStringLength" -> 2000, "PromptGenerators" -> { }, extra |>,
        Flatten @ {
            Cell[ StringRepeat[ "first message ", 300 ], "ChatInput" ],
            Table[ { Cell[ StringRepeat[ "answer ", 400 ], "ChatOutput" ], Cell[ "question", "ChatInput" ] }, n ]
        }
    ],
    { n, 3 }
];

(* Each request is a prefix of the next one, since older messages are shortened by the same amount in every request: *)
VerificationTest[
    Table[
        With[ { requests = sentMessages /@ historyRequests @ <| "PromptCacheOptimization" -> cache |> },
            And @@ MapThread[ Take[ #2, Length @ #1 ] === #1 &, { Most @ requests, Rest @ requests } ]
        ],
        { cache, { True, False } }
    ],
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "History-FixedCellStringLength@@Tests/PromptCache.wlt:556,1-566,2"
]

(* A larger part of the token budget is kept free, since the history doesn't count everything that's sent: *)
VerificationTest[
    withCacheSettings[
        <| "MaxContextTokens" -> 8000, "MaxCellStringLength" -> 2000, "PromptGenerators" -> { } |>,
        constructWithData[
            $settings,
            Flatten @ Table[ { Cell[ "question", "ChatInput" ], Cell[ StringRepeat[ "answer ", 400 ], "ChatOutput" ] }, 30 ]
        ];
        Wolfram`Chatbook`Common`$tokenBudget > 0.1 * 8000
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "History-ReservedTokens@@Tests/PromptCache.wlt:569,1-581,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Responses*)
VerificationTest[
    Table[
        Block[ { Wolfram`Chatbook`Common`$toolCallCount = 7 },
            Wolfram`Chatbook`SendChat`Private`sendToolResponseQ[
                <| "MaxToolResponses" -> 5, "PromptCacheOptimization" -> cache |>,
                None
            ]
        ],
        { cache, { True, False } }
    ],
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "ToolResponses-MaxToolResponses@@Tests/PromptCache.wlt:586,1-599,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Records*)

(* The record ID is written to the output cell's tagging rules: *)
VerificationTest[
    Wolfram`Chatbook`SendChat`Private`makeReformattedCellTaggingRules[
        <| "Data" -> <| "Messages" -> { }, "PromptCacheID" -> "abc" |> |>,
        "Hi there",
        Inherited,
        TextData[ "Hi there" ],
        None
    ],
    KeyValuePattern[ "PromptCacheID" -> "abc" ],
    SameTest -> MatchQ,
    TestID   -> "Records-TaggingRules@@Tests/PromptCache.wlt:606,1-617,2"
]

VerificationTest[
    KeyExistsQ[
        Wolfram`Chatbook`SendChat`Private`makeReformattedCellTaggingRules[
            <| "Data" -> <| "Messages" -> { } |> |>,
            "Hi there",
            Inherited,
            TextData[ "Hi there" ],
            None
        ],
        "PromptCacheID"
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "Records-NoTaggingRules@@Tests/PromptCache.wlt:619,1-633,2"
]

(* The number of records kept in memory is bounded: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`PromptCache`Private`$promptCacheRecords    = <| |>,
            Wolfram`Chatbook`PromptCache`Private`$maxPromptCacheRecords = 10
        },
        Do[ Wolfram`Chatbook`PromptCache`Private`setPromptCacheRecord[ CreateUUID[ ], { } ], 25 ];
        Length @ Wolfram`Chatbook`PromptCache`Private`$promptCacheRecords
    ],
    _Integer? (# <= 10 &),
    SameTest -> MatchQ,
    TestID   -> "Records-Bounded@@Tests/PromptCache.wlt:636,1-648,2"
]

(* Regenerated responses have pages, which use the other definition: *)
VerificationTest[
    Wolfram`Chatbook`SendChat`Private`makeReformattedCellTaggingRules[
        <| "Data" -> <| "Messages" -> { <| "Role" -> "User", "Content" -> "Hello" |> }, "PromptCacheID" -> "abc" |> |>,
        "Hi there",
        Inherited,
        TextData[ "Hi there" ],
        <| "Pages" -> <| 1 -> "Previous page" |>, "PageCount" -> 1, "CurrentPage" -> 1 |>
    ],
    KeyValuePattern @ { "PromptCacheID" -> "abc", "PageData" -> KeyValuePattern[ "PageCount" -> 2 ] },
    SameTest -> MatchQ,
    TestID   -> "Records-TaggingRulesPages@@Tests/PromptCache.wlt:651,1-662,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Data*)

(* The chat data that is written to the output cell of the second turn: *)
secondTurnChatData[ ] := withCacheSettings[
    <| |>,
    Module[ { data, output, cells },
        data   = Last @ turnRequest[ $settings, { Cell[ "Hello", "ChatInput" ] } ];
        output = Cell[ "Hi there", "ChatOutput", TaggingRules -> <| "PromptCacheID" -> data[ "PromptCacheID" ] |> ];
        cells  = { Cell[ "Hello", "ChatInput" ], output, Cell[ "Next", "ChatInput" ] };
        BinaryDeserialize @ BaseDecode @ Wolfram`Chatbook`SendChat`Private`makeCompactChatData[
            "Answer",
            Inherited,
            <| $settings, "Data" -> Last @ turnRequest[ $settings, cells ] |>
        ]
    ]
];

(* Only the current turn's turn messages are written to the output cell, since the earlier turns' are in their records: *)
VerificationTest[
    Cases[ secondTurnChatData[ ][ "Data", "Messages" ], KeyValuePattern[ "Content" -> c_String ] :> c ],
    { _String, "Hello", "Hi there", "Next", "Generated prompt 2", "Answer" },
    SameTest -> MatchQ,
    TestID   -> "ChatData-CurrentTurnMessages@@Tests/PromptCache.wlt:684,1-689,2"
]

(* Feedback without the chat history includes the user's message and the response, but not the turn messages: *)
VerificationTest[
    Module[ { feedback },
        feedback = <| "ChatData" -> secondTurnChatData[ ][ "Data" ] |>;
        Lookup[ Wolfram`Chatbook`Feedback`Private`dropChatHistory[ feedback ][ "ChatData", "Messages" ], { "Role", "Content" } ]
    ],
    { { "System", _ }, { "User", "Next" }, { "Assistant", "Answer" } },
    SameTest -> MatchQ,
    TestID   -> "ChatData-FeedbackWithoutHistory@@Tests/PromptCache.wlt:692,1-700,2"
]

(* Turn messages can have the user role, and only the ones before the user's message are left out: *)
VerificationTest[
    Lookup[
        Wolfram`Chatbook`Common`dropReplayedTurnMessages @ {
            <| "Role" -> "System"   , "Content" -> "System prompt" |>,
            <| "Role" -> "User"     , "Content" -> "Hello" |>,
            <| "Role" -> "User"     , "Content" -> "Earlier", "Temporary" -> True, "PromptCache" -> True |>,
            <| "Role" -> "Assistant", "Content" -> "Hi there" |>,
            <| "Role" -> "User"     , "Content" -> "Next" |>,
            <| "Role" -> "User"     , "Content" -> "Current", "Temporary" -> True, "PromptCache" -> True |>
        },
        "Content"
    ],
    { "System prompt", "Hello", "Hi there", "Next", "Current" },
    SameTest -> MatchQ,
    TestID   -> "ChatData-UserRoleTurnMessages@@Tests/PromptCache.wlt:703,1-718,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*System Prompt*)

(* "BasePrompt" -> None removes the base prompt components of the settings, like it does without prompt cache
   optimization: *)
VerificationTest[
    Table[
        withCacheSettings[
            <| "LLMEvaluator" -> "CodeAssistant", "BasePrompt" -> None, "PromptCacheOptimization" -> pco |>,
            systemContent @ First @ constructWithData[ $settings, $firstCells ]
        ],
        { pco, { True, False } }
    ],
    { prompt_, prompt_ },
    SameTest -> MatchQ,
    TestID   -> "SystemPrompt-BasePromptNone@@Tests/PromptCache.wlt:726,1-737,2"
]

(* The system prompt doesn't change after a tool call, also when it has instructions that are disabled with a hint: *)
VerificationTest[
    withCacheSettings[
        <| "ToolCallFrequency" -> 1 |>,
        Module[ { first, data },
            { first, data } = constructWithData[ $settings, $firstCells ];
            systemContent @ toolLoopMessages[ $settings, data ] === systemContent @ first
        ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SystemPrompt-ToolLoop@@Tests/PromptCache.wlt:740,1-751,2"
]

(* The request after a tool call can be made outside the chat state of the first request (e.g. for automatic
   assistance), where other components have been collected. It gets its system prompt from the turn's record: *)
VerificationTest[
    Module[ { first, data, second },
        { first, data } = cacheRequest[ <| "PromptGenerators" -> { needsGenerator @ { "CellLabels" } } |>, $firstCells ];
        second = withCacheSettings[
            <| |>,
            Wolfram`Chatbook`Common`needsBasePrompt[ "SpecialURIAudio" ];
            toolLoopMessages[ $settings, data ]
        ];
        systemContent @ second === systemContent @ first
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SystemPrompt-OtherChatState@@Tests/PromptCache.wlt:755,1-768,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Hint Contents*)

(* Hints include the components they depend on that weren't sent yet: *)
VerificationTest[
    Module[ { messages },
        messages = First @ cacheRequest[
            <| "PromptGenerators" -> { needsGenerator @ { "SpecialURIAudio" } } |>,
            $firstCells
        ];
        Last[ messages ][ "BasePromptComponents" ]
    ],
    _? (SubsetQ[ #, { "SpecialURI", "SpecialURIAudio" } ] &),
    SameTest -> MatchQ,
    TestID   -> "HintContents-Dependencies@@Tests/PromptCache.wlt:775,1-786,2"
]

(* The notebook assistance instructions are sent in each turn that needs them, along with their heading: *)
VerificationTest[
    Module[ { first, data, second },
        { first, data } = cacheRequest[
            <| "PromptGenerators" -> { needsGenerator @ { "NotebookAssistanceGettingStarted" } } |>,
            $firstCells
        ];
        second = First @ cacheRequest[
            <| "PromptGenerators" -> { needsGenerator @ { "NotebookAssistanceErrorMessage" } } |>,
            {
                Cell[ "Hello", "ChatInput" ],
                Cell[ "Hi there", "ChatOutput", TaggingRules -> <| "PromptCacheID" -> data[ "PromptCacheID" ] |> ],
                Cell[ "Next", "ChatInput" ]
            }
        ];
        StringCount[ contentString /@ { Last @ first, Last @ second }, "Special Instructions for Notebook Assistance" ]
    ],
    { 1, 1 },
    SameTest -> MatchQ,
    TestID   -> "HintContents-NotebookAssistanceHeading@@Tests/PromptCache.wlt:789,1-808,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook Context*)

(* When the notebook context of a turn doesn't fit in the token budget, its images are left out with it, so that the
   context is sent again (see notebookContextTurnMessages in ChatModes/Context.wl): *)
VerificationTest[
    Module[ { id, cells },
        id = Wolfram`Chatbook`PromptCache`Private`setPromptCacheRecord[
            CreateUUID[ ],
            {
                <|
                    "Role"                 -> "System",
                    "Content"              -> StringRepeat[ "notebook content ", 5000 ],
                    "Temporary"            -> True,
                    "PromptCache"          -> True,
                    "NotebookContext"      -> True,
                    "NotebookContextState" -> <| |>
                |>,
                <|
                    "Role"            -> "User",
                    "Content"         -> "IMAGES",
                    "Temporary"       -> True,
                    "PromptCache"     -> True,
                    "NotebookContext" -> True
                |>
            }
        ];
        cells = {
            Cell[ "Hello", "ChatInput" ],
            Cell[ "Hi there", "ChatOutput", TaggingRules -> <| "PromptCacheID" -> id |> ],
            Cell[ "Next", "ChatInput" ]
        };
        Cases[
            First @ cacheRequest[ <| "AllowSelectionContext" -> True, "MaxContextTokens" -> 8000, "MergeMessages" -> False |>, cells ],
            KeyValuePattern[ "Content" -> c_String ] :> c
        ]
    ],
    { _, "Hello", "Hi there", "Next", "Generated prompt 1" },
    SameTest -> MatchQ,
    TestID   -> "NotebookContext-OrphanImages@@Tests/PromptCache.wlt:816,1-851,2"
]

(* :!CodeAnalysis::EndBlock:: *)
