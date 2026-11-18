(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Placeholders*)

(* The "Placeholders" component is pulled in automatically wherever Wolfram Language style guidelines apply: *)
VerificationTest[
    Wolfram`Chatbook`Common`withBasePromptBuilder[
        Wolfram`Chatbook`Common`needsBasePrompt[ "WolframLanguageStyle" ];
        Wolfram`Chatbook`Common`$basePrompt
    ],
    _String? (StringContainsQ[ #, "Placeholder[\"description\"]" ] &),
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-Placeholders-WolframLanguageStyle"
]

VerificationTest[
    Wolfram`Chatbook`Common`withBasePromptBuilder[
        Wolfram`Chatbook`Common`needsBasePrompt[ "WolframLanguage" ];
        Wolfram`Chatbook`Common`$basePrompt
    ],
    _String? (StringContainsQ[ #, "Placeholder[\"description\"]" ] &),
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-Placeholders-WolframLanguageClass"
]

(* It should not appear when no Wolfram Language prompting was requested: *)
VerificationTest[
    Wolfram`Chatbook`Common`withBasePromptBuilder @ Wolfram`Chatbook`Common`$basePrompt,
    _String? (StringFreeQ[ #, "Placeholder" ] &),
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-Placeholders-NotIncludedByDefault"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Code Folding*)
VerificationTest[
    (* The system prompt of a chat that has the Wolfram Language style guidelines: *)
    styleGuidelines[ settings_Association ] := Wolfram`Chatbook`Common`withChatState @ Module[ { resolved },
        resolved = Wolfram`Chatbook`Common`resolveAutoSettings @ Wolfram`Chatbook`Common`mergeChatSettings @ {
            Wolfram`Chatbook`Common`$defaultChatSettings,
            <|
                "LLMEvaluator"     -> "CodeAssistant",
                "Model"            -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>,
                "PromptGenerators" -> { },
                settings
            |>
        };
        Block[ { $CurrentChatSettings = resolved },
            First[ Wolfram`Chatbook`Common`constructMessages[ resolved, { Cell[ "Hello", "ChatInput" ] } ] ][ "Content" ]
        ]
    ];

    (* Whether the prompt has the style guidelines, and whether these include the instructions for folding code: *)
    codeFoldingQ[ prompt_String ] := {
        StringContainsQ[ prompt, "Wolfram Language Style Guidelines" ],
        StringContainsQ[ prompt, "IconizedObject" ]
    };
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-CodeFolding-Definitions"
]

(* The instructions for folding code are part of the Wolfram Language style guidelines: *)
VerificationTest[
    codeFoldingQ @ styleGuidelines @ <| |>,
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-CodeFolding-Included"
]

(* Folded code needs the formatting of a notebook to be displayed as intended, so it's left out otherwise: *)
VerificationTest[
    codeFoldingQ @ styleGuidelines @ <| "AutoFormat" -> False |>,
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-CodeFolding-AutoFormat"
]

VerificationTest[
    codeFoldingQ @ GenerateLLMConfiguration[ "CodeAssistant" ][ "Prompts" ][[ 1 ]],
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-CodeFolding-GenerateLLMConfiguration"
]

(* AgentEvaluate gives its result as a string: *)
VerificationTest[
    Module[ { sent, submit },
        submit[ messages_, _, opts___ ] :=
            With[ { handlers = Lookup[ { opts }, HandlerFunctions ] },
                sent = messages;
                handlers[ "BodyChunkReceived" ][ <|
                    "BodyChunk"          -> "data: {}\n\n",
                    "BodyChunkProcessed" -> { <| "CallID" -> "msg", "ContentChunk" -> "Hi", "Type" -> "Text" |> }
                |> ];
                handlers[ "TaskFinished" ][ <|
                    "TaskStatus" -> "Finished",
                    "EventName"  -> "TaskFinished",
                    "StatusCode" -> 200
                |> ];
                None
            ];
        {
            AgentEvaluate[
                "Hello",
                <|
                    "BasePrompt"          -> { "WolframLanguageStyle" },
                    "LLMEvaluator"        -> "PlainChat",
                    "Model"               -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>,
                    "ProcessingFunctions" -> <| "ChatSubmit" -> submit |>,
                    "ToolsEnabled"        -> False
                |>
            ],
            codeFoldingQ @ First[ sent ][ "Content" ]
        }
    ],
    { "Hi", { True, False } },
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-CodeFolding-AgentEvaluate"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Components Enabled for a Model*)

(* A component that is disabled by default stays enabled for the rest of the session once settings that enable it are
   resolved in a chat state that is not scoped, which some tests do. So the tests of these components start with them
   disabled: *)
withDisabledBasePrompts // Attributes = { HoldFirst };
withDisabledBasePrompts[ eval_ ] := Block[
    {
        Wolfram`Chatbook`Common`$disabledBasePrompts = Union[
            Wolfram`Chatbook`Common`$disabledBasePrompts,
            {
                "FunctionRepositoryIntegration",
                "FunctionRepositoryPreference",
                "ReasonableAssumptions",
                "WolframLanguageEvaluatorToolCode"
            }
        ]
    },
    eval
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Evaluator Tool Code*)

(* gpt-6.1-sol tends to only show the result of code it evaluated, so it's told to include the code. This is only
   enabled for the "GPT6Plus" family: *)
VerificationTest[
    withDisabledBasePrompts[
        StringContainsQ[
            styleGuidelines @ <| "Model" -> <| "Service" -> "OpenAI", "Name" -> #1 |> |>,
            "also give the code that produced it in a code block"
        ] & /@ { "gpt-6.1-sol", "gpt-6.2-sol", "gpt-6.1-terra", "gpt-5.4", "gpt-4o" }
    ],
    { True, True, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-EvaluatorToolCode"
]

(* Exported configurations are not used in a chat with collapsed tool calls: *)
VerificationTest[
    StringContainsQ[
        GenerateLLMConfiguration[
            "CodeAssistant",
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-6.1-sol" |> |>
        ][ "Prompts" ][[ 1 ]],
        "also give the code that produced it in a code block"
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-EvaluatorToolCode-GenerateLLMConfiguration"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Reasonable Assumptions*)

(* Asked for something that leaves a detail open ("Compute the weight of a dinosaur"), gpt-6.1-sol only asks which one is
   meant, so it's told to pick a reasonable one and answer. This is a general instruction that is only enabled for the
   "GPT6Plus" family: *)
VerificationTest[
    withDisabledBasePrompts[
        StringContainsQ[
            styleGuidelines @ <| "Model" -> <| "Service" -> "OpenAI", "Name" -> #1 |> |>,
            "Only ask first when there is nothing reasonable to assume"
        ] & /@ { "gpt-6.1-sol", "gpt-6.2-sol", "gpt-6.1-terra", "gpt-5.4", "gpt-4o" }
    ],
    { True, True, False, False, False },
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-ReasonableAssumptions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Function Repository Preference*)

(* When documentation for resource functions is found, gpt-6.1-sol is also told to use a function that does what the
   user asks for, since it otherwise works out the answer itself: *)
VerificationTest[
    withDisabledBasePrompts[
        Function[ name,
            Wolfram`Chatbook`Common`withChatState[
                Wolfram`Chatbook`Common`resolveAutoSettings @ Wolfram`Chatbook`Common`mergeChatSettings @ {
                    Wolfram`Chatbook`Common`$defaultChatSettings,
                    <| "Model" -> <| "Service" -> "OpenAI", "Name" -> name |>, "PromptGenerators" -> { } |>
                };
                Wolfram`Chatbook`Common`withBasePromptBuilder[
                    Wolfram`Chatbook`Common`needsBasePrompt[ "FunctionRepositoryIntegration" ];
                    {
                        StringContainsQ[ Wolfram`Chatbook`Common`$basePrompt, "first-class citizens" ],
                        StringContainsQ[
                            Wolfram`Chatbook`Common`$basePrompt,
                            "instead of working out the answer another way"
                        ]
                    }
                ]
            ]
        ] /@ { "gpt-6.1-sol", "gpt-6.2-sol", "gpt-5.4", "gpt-4o" }
    ],
    { { True, True }, { True, True }, { True, False }, { False, False } },
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-FunctionRepositoryPreference"
]

(* :!CodeAnalysis::EndBlock:: *)
