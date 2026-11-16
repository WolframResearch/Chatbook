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

(* :!CodeAnalysis::EndBlock:: *)
