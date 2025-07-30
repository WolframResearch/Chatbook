(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

HoldComplete[
    `$$prompt,
    `$defaultSources,
    `$maxNeighbors,
    `$maxSelectedSources,
    `$versionString,
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
(*Messages*)
Chatbook::InvalidPrompt = "\
Expected a string or a list of chat messages instead of `1`.";

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
ensureChatMessages[ other_ ] /; ! TrueQ @ $chatState := throwFailure[ "InvalidPrompt", other ];
ensureChatMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resolvePromptGenerators*)
resolvePromptGenerators // beginDefinition;

resolvePromptGenerators[ settings0_ ] := Enclose[
    Module[ { settings, generators, resolved },

        settings   = ConfirmBy[ settings0, AssociationQ, "Settings" ];
        generators = ConfirmBy[ settings[ "PromptGenerators" ], ListQ, "Generators" ];

        If[ featureEnabledQ[ "RelatedWolframAlphaResults", settings ],
            AppendTo[ generators, "RelatedWolframAlphaResults" ]
        ];

        If[ featureEnabledQ[ "RelatedWebSearchResults", settings ],
            AppendTo[ generators, "WebSearch" ]
        ];

        resolved = ConfirmMatch[
            DeleteDuplicates[ resolvePromptGenerator /@ Flatten[ generators ] ],
            { ___LLMPromptGenerator },
            "Resolved"
        ];

        settings[ "PromptGenerators" ] = resolved;

        settings
    ],
    throwInternalFailure
];

resolvePromptGenerators // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolvePromptGenerator*)
resolvePromptGenerator // beginDefinition;

resolvePromptGenerator[ gen: HoldPattern[ _LLMPromptGenerator ] ] :=
    gen;

resolvePromptGenerator[ name_String ] := Enclose[
    Lookup[
        ConfirmBy[ $defaultPromptGenerators, AssociationQ, "DefaultPromptGenerators" ],
        name,
        throwFailure[ "InvalidPromptGenerator", name ]
    ],
    throwInternalFailure
];

resolvePromptGenerator[ ParentList|$$unspecified ] := Nothing;

resolvePromptGenerator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];