(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
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
(*replaceUnicode*)

(* Outgoing content must be pure ASCII, since the models this is enabled for mishandle the private use area *)
VerificationTest[
    Wolfram`Chatbook`SendChat`Private`replaceUnicodeCharacters[ "\[FreeformPrompt][\"France\"]" ],
    "\\[FreeformPrompt][\"France\"]",
    SameTest -> MatchQ,
    TestID   -> "ReplaceUnicode-ASCII"
]

VerificationTest[
    Wolfram`Chatbook`SendChat`Private`replaceUnicodeCharacters[ "\[FreeformPrompt]" ],
    "\\[FreeformPrompt]",
    SameTest -> MatchQ,
    TestID   -> "ReplaceUnicode-LongName"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*autoCorrect*)
(* autoCorrect must restore whatever replaceUnicodeCharacters sent to the model *)
VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect @* Wolfram`Chatbook`SendChat`Private`replaceUnicodeCharacters /@
        { "\[FreeformPrompt]", "\[FreeformPrompt][\"France\"]", "no freeform prompt here" },
    { "\[FreeformPrompt]", "\[FreeformPrompt][\"France\"]", "no freeform prompt here" },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-ReplaceUnicode-RoundTrip"
]

VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "\\uF351[\"France\", Entity]" ],
    "\[FreeformPrompt][\"France\", Entity]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-ReplaceUnicode-Entity"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Regression Tests*)
VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "QuantityMagnitude[EntityValue[\[FreeformPrompt][\"France\", Entity], \"Population\"]]" ],
    "QuantityMagnitude[EntityValue[\[FreeformPrompt][\"France\", Entity], \"Population\"]]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Preserve-Valid"
]

VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "{\:ff1d[\"a\", Entity], \:ff1d[\"b\", Entity]}" ],
    "{\[FreeformPrompt][\"a\", Entity], \[FreeformPrompt][\"b\", Entity]}",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Preserve-Structure"
]

(* Models sometimes over-escape the leading backslash, so any number of them must be accepted *)
VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "\\\\[FreeformPrompt][\"France\", Entity]" ],
    "\[FreeformPrompt][\"France\", Entity]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Extra-Backslashes"
]

VerificationTest[
    (* Concatenated to keep the unrecognized long names out of the source text *)
    Wolfram`Chatbook`Common`autoCorrect /@ {
        "\\" <> "[FreeformInput][\"a\"]",
        "\\\\" <> "[FreeformInput][\"a\"]",
        "\\" <> "[FreeformEntity][\"a\"]",
        "\\\\" <> "[FreeformEntity][\"a\"]"
    },
    ConstantArray[ "\[FreeformPrompt][\"a\"]", 4 ],
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Freeform-Aliases"
]

VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "\\[RawEscape][FreeformPrompt][\"France\"]" ],
    "\[FreeformPrompt][\"France\"]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-RawEscape"
]

VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "\\\:ff1d[\"a\", Entity]" ],
    "\[FreeformPrompt][\"a\", Entity]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Backslash-Fullwidth"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Short Resource URIs*)
(* Documentation catalogs show resource URIs in a short form, which the model may use in links: *)
VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect /@ {
        "See [FITImport](resource:function/FITImport#334957977).",
        "[data](resource:data/Sample-Data-Fishers-Irises) and [net](resource:nn/ResNet-50-Trained-on-ImageNet-Competition-Data)",
        "[root](resource:paclet/RickHennigan/ComputationalFitness) [ref](resource:paclet/RickHennigan/ComputationalFitness/ref/FITImport.html#447361725)"
    },
    {
        "See [FITImport](https://resources.wolframcloud.com/FunctionRepository/resources/FITImport#334957977).",
        "[data](https://datarepository.wolframcloud.com/resources/Sample-Data-Fishers-Irises) and [net](https://resources.wolframcloud.com/NeuralNetRepository/resources/ResNet-50-Trained-on-ImageNet-Competition-Data)",
        "[root](https://paclets.com/RickHennigan/ComputationalFitness) [ref](https://paclets.com/RickHennigan/ComputationalFitness/ref/FITImport.html#447361725)"
    },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-ShortURIs"
]

(* autoCorrect runs on the whole accumulated text for every chunk, so the rules must be idempotent, and a short URI that
   is split between chunks must give the same result: *)
VerificationTest[
    $shortURIText = "Use [FITImport](resource:function/FITImport#334957977) or [x](resource:paclet/A/B).";
    {
        Wolfram`Chatbook`Common`autoCorrect @ Wolfram`Chatbook`Common`autoCorrect @ $shortURIText,
        Fold[
            Wolfram`Chatbook`SendChat`Private`appendStringContent,
            Null,
            StringPartition[ $shortURIText, UpTo[ 7 ] ]
        ]
    },
    ConstantArray[ Wolfram`Chatbook`Common`autoCorrect @ $shortURIText, 2 ],
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-ShortURIs-Idempotent-Streaming"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Moonshot Tool Calls*)
(* autoCorrect only includes the Moonshot tool call rule when the string contains "<|tool_calls_section_begin|>",
   which must give the same results as always using the full list of rules. *)
VerificationTest[
    Most @ Wolfram`Chatbook`SendChat`Private`$llmAutoCorrectRules,
    Wolfram`Chatbook`SendChat`Private`$llmAutoCorrectRulesNoMoonshot,
    SameTest -> SameQ,
    TestID   -> "AutoCorrect-Moonshot-Rules"
]

(* The omitted rule cannot match unless the string contains the literal: *)
VerificationTest[
    First @ Last @ Wolfram`Chatbook`SendChat`Private`$llmAutoCorrectRules,
    Verbatim[ Pattern ][ _, Verbatim[ StringExpression ][ ___, "<|tool_calls_section_begin|>", ___ ] ],
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Moonshot-Rule-Literal"
]

VerificationTest[
    $moonshotToolCallText = StringJoin[
        "<|tool_calls_section_begin|> <|tool_call_begin|> functions.wolfram_language_evaluator:0 ",
        "<|tool_call_argument_begin|> {\"code\": \"1+1\"} <|tool_call_end|> <|tool_calls_section_end|>"
    ];

    $moonshotAutoCorrectFragments = Join[
        { " ", "\n", "  ", "\t", "\n\n", "Hello", "abc", "x", "Plot[Sin[x], {x, 0, 1}]" },
        {
            "/command\ncode:", "/command", "code:", " /wl\n", "  /wl \n", " /notatool\n", "```", "```wl", "``code``",
            "wolfram_language_evaliator", "\\!\\(\\*AudioBox[\"https://a.b/c\"]\\)", "\\!\\(MarkdownImageBox[\"x\"]\\)",
            "\"\\\\!\\\\(\\\\*VideoBox[\\\"y\\\"]\\\\)\"", "\"\\\\!\\\\(AudioBox[\\\"z\\\"]\\\\)\"",
            "<attachment://content-abc12>", "!<expression://content-xyz99!>", "<", ">", "!",
            "\\uF351", "\\uf351", "\\uFF1D", "\\uff1d", "\:ff1d", "\\\:ff1d", "\\" <> "[FreeformInput]",
            "\\\\" <> "[FreeformEntity]", "\\[FreeformPrompt]", "\\[RawEscape][FreeformPrompt]", "\[FreeformPrompt]",
            "\n<|image_sentinel|>\n", "<|image_sentinel|>", "paclet:ref/ResourceFunction/",
            "paclet:ref/resource-function/", "/functions.", "[end]", "resource:function/", "resource:data/",
            "resource:nn/", "resource:paclet/", "resource:"
        },
        Keys @ Wolfram`Chatbook`Common`$longNameCharacters,
        {
            "<|tool_calls_section_begin|>", "<|tool_calls_section_end|>", "<|tool_call_begin|>", "<|tool_call_end|>",
            "<|tool_call_argument_begin|>", "functions.wolfram_language_evaluator:0", "{\"code\": \"2+2\"}",
            $moonshotToolCallText, "<|tool_calls_section_begin", "tool_calls_section_begin|>"
        }
    ];

    withMoonshotTestHandlerData // Attributes = { HoldFirst };
    withMoonshotTestHandlerData[ eval_ ] :=
        Block[
            {
                Wolfram`Chatbook`$ChatHandlerData = <|
                    "ChatNotebookSettings" -> <| "ToolMethod" -> Automatic |>,
                    "ToolShortNames"       -> <| "wl" -> Wolfram`Chatbook`$DefaultTools[ "WolframLanguageEvaluator" ] |>
                |>
            },
            eval
        ];

    (* The original implementation, which always used all of the rules: *)
    referenceAutoCorrect[ s_String ] := StringReplace[ s, Wolfram`Chatbook`SendChat`Private`$llmAutoCorrectRules ];

    $moonshotAutoCorrectStrings = BlockRandom[
        SeedRandom[ 5678 ];
        Table[ StringJoin @ RandomChoice[ $moonshotAutoCorrectFragments, RandomInteger @ { 0, 30 } ], 1500 ]
    ];,
    Null,
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Moonshot-Definitions"
]

VerificationTest[
    withMoonshotTestHandlerData @ Wolfram`Chatbook`Common`autoCorrect[
        "Let me compute.\n\n" <> $moonshotToolCallText <> "\n"
    ],
    _String? (StringStartsQ[ "Let me compute.\nTOOLCALL: wolfram_language_evaluator" ]),
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Moonshot-Rewrite"
]

VerificationTest[
    withMoonshotTestHandlerData @ Select[
        $moonshotAutoCorrectStrings,
        Wolfram`Chatbook`Common`autoCorrect[ # ] =!= referenceAutoCorrect[ # ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Moonshot-Matches-Reference"
]

(* Make sure the generated strings exercise both code paths, including actual tool call rewrites: *)
VerificationTest[
    withMoonshotTestHandlerData @ Counts @ Table[
        {
            StringContainsQ[ s, "<|tool_calls_section_begin|>" ],
            StringContainsQ[ referenceAutoCorrect @ s, "<|tool_calls_section_begin|>" ],
            referenceAutoCorrect @ s === s
        },
        { s, $moonshotAutoCorrectStrings }
    ],
    KeyValuePattern @ {
        { True , False, False } -> _Integer,
        { True , True , _     } -> _Integer,
        { False, False, False } -> _Integer,
        { False, False, True  } -> _Integer
    },
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Moonshot-Coverage"
]

(* :!CodeAnalysis::EndBlock:: *)