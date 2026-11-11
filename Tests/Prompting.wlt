(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Prompting.wlt:7,1-12,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Prompting.wlt:14,1-19,2"
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
    TestID   -> "BasePrompt-Placeholders-WolframLanguageStyle@@Tests/Prompting.wlt:26,1-34,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`withBasePromptBuilder[
        Wolfram`Chatbook`Common`needsBasePrompt[ "WolframLanguage" ];
        Wolfram`Chatbook`Common`$basePrompt
    ],
    _String? (StringContainsQ[ #, "Placeholder[\"description\"]" ] &),
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-Placeholders-WolframLanguageClass@@Tests/Prompting.wlt:36,1-44,2"
]

(* It should not appear when no Wolfram Language prompting was requested: *)
VerificationTest[
    Wolfram`Chatbook`Common`withBasePromptBuilder @ Wolfram`Chatbook`Common`$basePrompt,
    _String? (StringFreeQ[ #, "Placeholder" ] &),
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-Placeholders-NotIncludedByDefault@@Tests/Prompting.wlt:47,1-52,2"
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
    TestID   -> "BasePrompt-CodeFolding-Definitions@@Tests/Prompting.wlt:57,1-83,2"
]

(* The instructions for folding code are part of the Wolfram Language style guidelines: *)
VerificationTest[
    codeFoldingQ @ styleGuidelines @ <| |>,
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-CodeFolding-Included@@Tests/Prompting.wlt:86,1-91,2"
]

(* Folded code needs the formatting of a notebook to be displayed as intended, so it's left out otherwise: *)
VerificationTest[
    codeFoldingQ @ styleGuidelines @ <| "AutoFormat" -> False |>,
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-CodeFolding-AutoFormat@@Tests/Prompting.wlt:94,1-99,2"
]

VerificationTest[
    codeFoldingQ @ GenerateLLMConfiguration[ "CodeAssistant" ][ "Prompts" ][[ 1 ]],
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "BasePrompt-CodeFolding-GenerateLLMConfiguration@@Tests/Prompting.wlt:101,1-106,2"
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
    TestID   -> "BasePrompt-CodeFolding-AgentEvaluate@@Tests/Prompting.wlt:109,1-142,2"
]

(* :!CodeAnalysis::EndBlock:: *)
