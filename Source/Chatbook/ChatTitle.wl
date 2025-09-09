(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatTitle`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$maxTitleLength         = 30;
$hardMaxTitleLength     = 45;
$maxContextLength       = 100000; (* characters *)
$multimodalTitleContext = False;
$tokenLengthMultiplier  = 3.0;
$defaultEvaluator       = <| "Model" -> <| "Service" -> Automatic, "Name" -> "gpt-4.1-nano" |> |>;

$titlePrompt := "\
Please come up with a meaningful window title for the current chat conversation using no more than \
`TargetLength` characters.
The title should be specific to the topics discussed in the chat.
Do not give generic titles such as \"Chat\", \"Transcript\", or \"Chat Transcript\".
The title should contain only plain text, no markdown or other formatting.
Respond only with the title and nothing else.

Here is the chat transcript:
<transcript>
`Transcript`
</transcript>

Remember, respond only with the title and nothing else.";

(* TODO:
    Detect when topic has changed and display a message:
        Is this a new topic? You'll get more accurate results with a new chat when you change topics. <Start New Chat>
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GenerateChatTitle*)
GenerateChatTitle // beginDefinition;
GenerateChatTitle // Options = {
    "LLMEvaluator" -> $defaultEvaluator,
    "MaxLength"    -> $hardMaxTitleLength,
    "TargetLength" -> $maxTitleLength,
    "Temperature"  -> 0.7
};

GenerateChatTitle[ messages: $$chatMessages, opts: OptionsPattern[ ] ] :=
    catchMine @ LogChatTiming @ generateChatTitle[
        messages,
        OptionValue[ "LLMEvaluator" ],
        OptionValue[ "Temperature"  ],
        OptionValue[ "TargetLength" ],
        OptionValue[ "MaxLength"    ]
    ];

GenerateChatTitle // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateChatTitle*)
generateChatTitle // beginDefinition;

generateChatTitle[ messages_, evaluator_, temperature_, targetLength_, maxLength_ ] := Enclose[
    Module[ { title, task },

        task = ConfirmMatch[
            LogChatTiming @ generateChatTitleAsync[
                messages,
                Function[ title = # ],
                evaluator,
                temperature,
                targetLength,
                maxLength
            ],
            _TaskObject,
            "Task"
        ];

        LogChatTiming[ TaskWait @ task, "WaitForChatTitleTask" ];

        ConfirmMatch[ title, _String|_Failure, "Result" ]
    ],
    throwInternalFailure
];

generateChatTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GenerateChatTitleAsynchronous*)
GenerateChatTitleAsynchronous // beginDefinition;
GenerateChatTitleAsynchronous // Options = {
    "LLMEvaluator" -> $defaultEvaluator,
    "MaxLength"    -> $hardMaxTitleLength,
    "TargetLength" -> $maxTitleLength,
    "Temperature"  -> 0.7
};

GenerateChatTitleAsynchronous[ messages: $$chatMessages, f_, opts: OptionsPattern[ ] ] :=
    catchMine @ generateChatTitleAsync[
        messages,
        f,
        OptionValue[ "LLMEvaluator" ],
        OptionValue[ "Temperature"  ],
        OptionValue[ "TargetLength" ],
        OptionValue[ "MaxLength"    ]
    ];

GenerateChatTitleAsynchronous // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateChatTitleAsync*)
generateChatTitleAsync // beginDefinition;

generateChatTitleAsync[
    messages: $$chatMessages,
    callback_,
    evaluator_Association? AssociationQ,
    temperature: Automatic | _? NumericQ,
    targetLength_Integer? Positive,
    maxLength_Integer? Positive
] := Enclose[
    Module[ { string, short, instructions, context },

        string = ConfirmBy[ messagesToString[ messages, "IncludeSystemMessage" -> False ], StringQ, "String" ];
        short  = ConfirmBy[ StringTake[ string, UpTo[ $maxContextLength ] ], StringQ, "Short" ];

        instructions = ConfirmBy[
            TemplateApply[
                $titlePrompt,
                <|
                    "TargetLength" -> targetLength,
                    "Transcript"   -> short
                |>
            ],
            StringQ,
            "Prompt"
        ];

        context = ConfirmMatch[
            Block[ { $multimodalMessages = TrueQ @ $multimodalTitleContext },
                expandMultimodalString @ instructions
            ],
            _String | { __ },
            "Context"
        ];

        $lastChatTitleContext = context;

        ConfirmMatch[
            setServiceCaller[
                llmSynthesizeSubmit[
                    context,
                    <| evaluator, "Temperature" -> temperature |>,
                    callback @* postProcessChatTitle[ maxLength ]
                ],
                "GenerateChatTitle"
            ],
            _TaskObject,
            "Task"
        ]
    ],
    throwInternalFailure
];

generateChatTitleAsync // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*postProcessChatTitle*)
postProcessChatTitle // beginDefinition;

postProcessChatTitle[ maxLength_ ] :=
    postProcessChatTitle[ maxLength, ## ] &;

postProcessChatTitle[ maxLength_Integer? Positive, title0_String, KeyValuePattern[ "StatusCode" -> 200 ] ] := Enclose[
    Module[ { title, clean, length },

        title = ConfirmBy[
            StringReplace[
                StringTrim @ title0,
                StartOfString ~~ (("\"" ~~ t___ ~~ "\"") | ("'" ~~ t___ ~~ "'")) ~~ EndOfString :> t
            ],
            StringQ,
            "Title"
        ];

        ConfirmAssert[ StringQ @ title && StringLength @ title > 0, "StringCheck" ];

        (* Remove the redundant substrings like " in Wolfram Language" from the generated title: *)
        clean = ConfirmBy[ removeRedundantSubstrings @ title, StringQ, "Clean" ];

        If[ StringLength @ clean < maxLength / 2, clean = title ];

        length = ConfirmBy[ titleLength @ clean, NumberQ, "Length" ];

        Which[
            StringContainsQ[ clean, "\n"|"```" ],
            Failure[
                "TitleCharacters",
                <| "MessageTemplate" -> "Unexpected characters in generated title.", "Title" -> clean |>
            ],

            length > maxLength,
            Failure[
                "TitleLength",
                <| "MessageTemplate" -> "Generated title exceeds the maximum length.", "Title" -> clean |>
            ],

            True,
            clean
        ]
    ],
    throwInternalFailure
];

postProcessChatTitle[ maxLength_, failure: Failure[ "InvalidResponse", _ ], _ ] :=
    throwTop @ failure;

postProcessChatTitle[ maxLength_, failure: Failure[ "APIError", _ ], _ ] :=
    throwFailureToChatOutput @ failure;

postProcessChatTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeRedundantSubstrings*)
removeRedundantSubstrings // beginDefinition;

removeRedundantSubstrings[ title_String ] := StringReplace[
    title,
    {
        " "~~$$connector~~" "~~$$wolframLanguage~~EndOfString -> "",
        StartOfString ~~ $$wolframLanguage ~~ " " ~~ c_? UpperCaseQ :> c
    },
    IgnoreCase -> True
];

removeRedundantSubstrings // endDefinition;

$$connector = "in"|"with"|"using";
$$wolframLanguage = Longest[ "Mathematica"|"Wolfram Language"|"Wolfram Lang"|"Wolfram"|"WL" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*titleLength*)
(* Measure title length using both character and token counts.
   LLMs can estimate character counts for many words, but not reliably for all,
   so token counts better handle unusually wide or single-token words.
   Combining both reduces errors (e.g., " Histogram" is one token). *)
titleLength // beginDefinition;
titleLength[ title_String ] := (StringLength @ title + tokenLength @ title) / 2.0;
titleLength // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tokenLength*)
tokenLength // beginDefinition;
tokenLength[ title_String ] := Length @ cachedTokenizer[ "gpt-4o" ][ title ] * $tokenLengthMultiplier;
tokenLength // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
