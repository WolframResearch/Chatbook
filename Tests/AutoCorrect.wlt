(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/AutoCorrect.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/AutoCorrect.wlt:11,1-16,2"
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
    TestID   -> "ReplaceUnicode-ASCII@@Tests/AutoCorrect.wlt:26,1-31,2"
]

VerificationTest[
    Wolfram`Chatbook`SendChat`Private`replaceUnicodeCharacters[ "\[FreeformPrompt]" ],
    "\\[FreeformPrompt]",
    SameTest -> MatchQ,
    TestID   -> "ReplaceUnicode-LongName@@Tests/AutoCorrect.wlt:33,1-38,2"
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
    TestID   -> "AutoCorrect-ReplaceUnicode-RoundTrip@@Tests/AutoCorrect.wlt:44,1-50,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "\\uF351[\"France\", Entity]" ],
    "\[FreeformPrompt][\"France\", Entity]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-ReplaceUnicode-Entity@@Tests/AutoCorrect.wlt:52,1-57,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Regression Tests*)
VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "QuantityMagnitude[EntityValue[\[FreeformPrompt][\"France\", Entity], \"Population\"]]" ],
    "QuantityMagnitude[EntityValue[\[FreeformPrompt][\"France\", Entity], \"Population\"]]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Preserve-Valid@@Tests/AutoCorrect.wlt:62,1-67,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "{\:ff1d[\"a\", Entity], \:ff1d[\"b\", Entity]}" ],
    "{\[FreeformPrompt][\"a\", Entity], \[FreeformPrompt][\"b\", Entity]}",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Preserve-Structure@@Tests/AutoCorrect.wlt:69,1-74,2"
]

(* Models sometimes over-escape the leading backslash, so any number of them must be accepted *)
VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "\\\\[FreeformPrompt][\"France\", Entity]" ],
    "\[FreeformPrompt][\"France\", Entity]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Extra-Backslashes@@Tests/AutoCorrect.wlt:77,1-82,2"
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
    TestID   -> "AutoCorrect-Freeform-Aliases@@Tests/AutoCorrect.wlt:84,1-95,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "\\[RawEscape][FreeformPrompt][\"France\"]" ],
    "\[FreeformPrompt][\"France\"]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-RawEscape@@Tests/AutoCorrect.wlt:97,1-102,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`autoCorrect[ "\\\:ff1d[\"a\", Entity]" ],
    "\[FreeformPrompt][\"a\", Entity]",
    SameTest -> MatchQ,
    TestID   -> "AutoCorrect-Backslash-Fullwidth@@Tests/AutoCorrect.wlt:104,1-109,2"
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
            "paclet:ref/resource-function/", "/functions.", "[end]"
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