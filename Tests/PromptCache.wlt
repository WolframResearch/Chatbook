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

(* Simulates the request that follows a tool call (see toolEvaluation in SendChat.wl): *)
toolLoopMessages[ settings_, data_ ] :=
    Block[ { Wolfram`Chatbook`Common`$promptCacheTurnID = data[ "PromptCacheID" ] },
        Wolfram`Chatbook`Common`constructMessages[
            <| settings, "Data" -> data |>,
            Join[
                data[ "Messages" ],
                {
                    <| "Role" -> "Assistant", "Content" -> "/wl\n1 + 1\n/exec", "ToolRequest" -> True |>,
                    <| "Role" -> "System", "Content" -> "2", "ToolResponse" -> True |>
                }
            ]
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
        <| "Service" -> "MistralAI", "Name" -> "mistral-large-latest" |>
    },
    { False, False },
    SameTest -> MatchQ,
    TestID   -> "PromptCacheOptimization-ModelDependent@@Tests/PromptCache.wlt:92,1-100,2"
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
    TestID   -> "Records-TaggingRules@@Tests/PromptCache.wlt:316,1-327,2"
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
    TestID   -> "Records-NoTaggingRules@@Tests/PromptCache.wlt:329,1-343,2"
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
    TestID   -> "Records-Bounded@@Tests/PromptCache.wlt:346,1-358,2"
]

(* :!CodeAnalysis::EndBlock:: *)
