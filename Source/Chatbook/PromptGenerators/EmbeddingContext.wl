(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`EmbeddingContext`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                         ];
Needs[ "Wolfram`Chatbook`Common`"                  ];
Needs[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$smallContextMessageCount = 10;
$smallContextStringLength = 8000;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Convert Chat Messages to String*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*messageListToString*)
messageListToString // beginDefinition;

messageListToString // Options = { "IncludeSystemMessage" -> False };

messageListToString[ { messages__ }, result_String, opts: OptionsPattern[ ] ] :=
    messageListToString[ { messages, <| "Role" -> "Assistant", "Content" -> result |> }, opts ];

messageListToString[ messages0_List, opts: OptionsPattern[ ] ] := Enclose[
    Catch @ Module[ { messages, reverted, strings },
        messages = ConfirmMatch[ makeChatTranscript[ messages0, opts ], $$chatMessages, "Messages" ];
        reverted = ConfirmMatch[ revertMultimodalContent @ messages, $$chatMessages, "Revert" ];
        If[ Length @ reverted === 1, Throw @ ConfirmBy[ reverted[[ 1, "Content" ]], StringQ, "String" ] ];
        strings = ConfirmMatch[ messageToString /@ reverted, { __String }, "Strings" ];
        StringRiffle[ strings, "\n\n" ]
    ],
    throwInternalFailure
];

messageListToString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*messageToString*)
messageToString // beginDefinition;

messageToString[ KeyValuePattern @ { "Role" -> role_String, "Content" -> content_String } ] :=
    StringJoin[ Capitalize @ role, ": ", content ];

messageToString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getSmallContextString*)
getSmallContextString // beginDefinition;

getSmallContextString // Options = { "IncludeSystemMessage" -> False };

getSmallContextString[ messages0: { ___Association }, opts: OptionsPattern[ ] ] := Enclose[
    Catch @ Module[ { messages, string },
        messages = Reverse @ Take[ Reverse @ messages0, UpTo[ $smallContextMessageCount ] ];
        If[ messages === { }, Throw[ "" ] ];
        string = ConfirmBy[ messageListToString[ messages, opts ], StringQ, "String" ];
        If[ StringLength @ string > $smallContextStringLength,
            StringTake[ string, { -$smallContextStringLength, -1 } ],
            string
        ]
    ],
    throwInternalFailure
];

getSmallContextString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeChatTranscript*)
makeChatTranscript // beginDefinition;
makeChatTranscript // Options = { "IncludeSystemMessage" -> False };

makeChatTranscript[ { messages__ }, result_String, opts: OptionsPattern[ ] ] :=
    makeChatTranscript[ { messages, <| "Role" -> "Assistant", "Content" -> result |> }, opts ];

makeChatTranscript[ { messages__ }, result_String, opts: OptionsPattern[ ] ] :=
    makeChatTranscript[ { messages, <| "Role" -> "Assistant", "Content" -> result |> }, opts ];

makeChatTranscript[ messages_List, opts: OptionsPattern[ ] ] :=
    If[ TrueQ @ OptionValue[ "IncludeSystemMessage" ],
        revertMultimodalContent @ messages,
        revertMultimodalContent @ DeleteCases[ messages, KeyValuePattern[ "Role"|"role" -> "System"|"system" ] ]
    ];

makeChatTranscript // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
