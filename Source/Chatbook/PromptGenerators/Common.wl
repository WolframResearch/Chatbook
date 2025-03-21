(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

HoldComplete[
    `$$prompt,
    `$defaultSources,
    `$maxNeighbors,
    `$maxSelectedSources,
    `ensureChatMessages,
    `getSmallContextString,
    `insertContextPrompt,
    `vectorDBSearch
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$$prompt = $$string | { $$string... } | $$chatMessages;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Common Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensureChatMessages*)
ensureChatMessages // beginDefinition;
ensureChatMessages[ prompt_String ] := { <| "Role" -> "User", "Content" -> prompt |> };
ensureChatMessages[ message: KeyValuePattern[ "Role" -> _ ] ] := { message };
ensureChatMessages[ messages: $$chatMessages ] := messages;
ensureChatMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];