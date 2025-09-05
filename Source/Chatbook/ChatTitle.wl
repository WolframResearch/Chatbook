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
$hardMaxTitleLength     = 100;
$maxContextLength       = 100000; (* characters *)
$multimodalTitleContext = False;

$titlePrompt := "\
Please come up with a meaningful window title for the current chat conversation using no more than \
"<>ToString[$maxTitleLength-30]<>" characters.
The title should be specific to the topics discussed in the chat.
Do not give generic titles such as \"Chat\", \"Transcript\", or \"Chat Transcript\".
Respond only with the title and nothing else.

Here is the chat transcript:
`1`

Remember, respond only with the title and nothing else.";

(* TODO:
    Detect when topic has changed and display a message:
        Is this a new topic? You'll get more accurate results with a new chat when you change topics. <Start New Chat>
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GenerateChatTitle*)
GenerateChatTitle // beginDefinition;
GenerateChatTitle // Options = { "Temperature" -> 0.7 };

GenerateChatTitle[ messages: $$chatMessages, opts: OptionsPattern[ ] ] :=
    catchMine @ LogChatTiming @ generateChatTitle[ messages, OptionValue[ "Temperature" ] ];

GenerateChatTitle // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateChatTitle*)
generateChatTitle // beginDefinition;

generateChatTitle[ messages_, temperature_ ] := Enclose[
    Module[ { title, task },

        task = ConfirmMatch[
            LogChatTiming @ generateChatTitleAsync[ messages, Function[ title = # ], temperature ],
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
GenerateChatTitleAsynchronous[ messages: $$chatMessages, f_ ] := catchMine @ generateChatTitleAsync[ messages, f ];
GenerateChatTitleAsynchronous // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateChatTitleAsync*)
generateChatTitleAsync // beginDefinition;

generateChatTitleAsync[ messages: $$chatMessages, callback_, temperature: Automatic | _? NumericQ ] := Enclose[
    Module[ { string, short, instructions, context },

        string       = ConfirmBy[ messagesToString[ messages, "IncludeSystemMessage" -> False ], StringQ, "String" ];
        short        = ConfirmBy[ StringTake[ string, UpTo[ $maxContextLength ] ], StringQ, "Short" ];
        instructions = ConfirmBy[ TemplateApply[ $titlePrompt, short ], StringQ, "Prompt" ];

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
                llmSynthesizeSubmit[ context, <| "Temperature" -> temperature |>, callback @* postProcessChatTitle ],
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

postProcessChatTitle[ title0_String, KeyValuePattern[ "StatusCode" -> 200 ] ] := Enclose[
    Module[ { title },

        title = ConfirmBy[
            StringReplace[
                StringTrim @ title0,
                StartOfString ~~ (("\"" ~~ t___ ~~ "\"") | ("'" ~~ t___ ~~ "'")) ~~ EndOfString :> t
            ],
            StringQ,
            "Title"
        ];

        ConfirmAssert[ StringQ @ title && StringLength @ title > 0, "StringCheck" ];

        Which[
            StringContainsQ[ title, "\n"|"```" ],
            Failure[ "TitleCharacters", <| "MessageTemplate" -> "Unexpected characters in generated title." |> ],

            StringLength @ title > $hardMaxTitleLength,
            Failure[ "TitleLength", <| "MessageTemplate" -> "Generated title exceeds the maximum length." |> ],

            True,
            title
        ]
    ],
    throwInternalFailure
];

postProcessChatTitle[ failure: Failure[ "InvalidResponse", _ ], _ ] :=
    throwTop @ failure;

postProcessChatTitle[ failure: Failure[ "APIError", _ ], _ ] :=
    throwFailureToChatOutput @ failure;

postProcessChatTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
