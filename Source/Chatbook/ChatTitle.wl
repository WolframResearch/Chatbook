(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatTitle`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$maxTitleLength      = 30;
$hardMaxTitleLength  = 40;
$maxContextLength    = 100000; (* characters *)

$titlePrompt := "\
Please come up with a meaningful window title for the current chat conversation using no more than \
"<>ToString[$maxTitleLength]<>" characters.
The title should be specific to the topics discussed in the chat.
Do not give generic titles such as \"Chat\", \"Transcript\", or \"Chat Transcript\".
Respond only with the title and nothing else.

Here is the chat transcript:
`1`

Remember, respond only with the title and nothing else.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GenerateChatTitle*)
GenerateChatTitle // beginDefinition;

GenerateChatTitle[ messages: $$chatMessages ] := catchMine @ Enclose[
    Module[ { title, callback, task },
        callback = Function[ title = # ];
        task = ConfirmMatch[ generateChatTitle[ messages, callback ], _TaskObject, "Task" ];
        TaskWait @ task;
        ConfirmMatch[ title, Except[ "", _String ], "Title" ]
    ],
    throwInternalFailure
];

GenerateChatTitle // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GenerateChatTitleAsynchronous*)
GenerateChatTitleAsynchronous // beginDefinition;
GenerateChatTitleAsynchronous[ messages: $$chatMessages, f_ ] := catchMine @ generateChatTitle[ messages, f ];
GenerateChatTitleAsynchronous // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateChatTitle*)
generateChatTitle // beginDefinition;

generateChatTitle[ messages_, callback_ ] := Enclose[
    Module[ { string, short, instructions, context },

        string       = ConfirmBy[ messageListToString[ messages, "IncludeSystemMessage" -> False ], StringQ, "String" ];
        short        = ConfirmBy[ StringTake[ string, UpTo[ $maxContextLength ] ], StringQ, "Short" ];
        instructions = ConfirmBy[ TemplateApply[ $titlePrompt, short ], StringQ, "Prompt" ];

        context = ConfirmMatch[
            Block[ { $multimodalMessages = True }, expandMultimodalString @ instructions ],
            _String | { __ },
            "Context"
        ];

        $lastChatTitleContext = context;

        ConfirmMatch[ llmSynthesizeSubmit[ context, callback ], _TaskObject, "Task" ]
    ],
    throwInternalFailure
];

generateChatTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
