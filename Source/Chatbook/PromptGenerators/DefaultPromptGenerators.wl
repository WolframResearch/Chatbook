(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`DefaultPromptGenerators`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                         ];
Needs[ "Wolfram`Chatbook`Common`"                  ];
Needs[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

HoldComplete[
    System`LLMPromptGenerator
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DefaultPromptGenerators*)
$defaultPromptGenerators := $defaultPromptGenerators = <|
    "RelatedDocumentation"       -> LLMPromptGenerator[ RelatedDocumentation[ #, "Prompt", MaxItems -> 20 ] &, "Messages" ],
    "RelatedWolframAlphaQueries" -> LLMPromptGenerator[ RelatedWolframAlphaQueries[ #, "Prompt" ] &, "Messages" ]
|>;

(* TODO: prompt generator selectors that work like tool selections *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*applyPromptGenerators*)
applyPromptGenerators // beginDefinition;

applyPromptGenerators[ settings_Association, messages_ ] :=
    applyPromptGenerators[ settings, settings[ "PromptGenerators" ], messages ];

applyPromptGenerators[ settings_, generators0_, messages: $$chatMessages ] := Enclose[
    Catch @ Module[ { generators, data, prompts },

        generators = ConfirmMatch[
            toPromptGenerator /@ Flatten @ { generators0 },
            { ___LLMPromptGenerator },
            "Generators"
        ];

        If[ generators === { }, Throw @ None ];

        data = ConfirmBy[ makePromptGeneratorData[ settings, messages ], AssociationQ, "Data" ];
        prompts = ConfirmMatch[ applyPromptGenerator[ #, data ] & /@ generators, { $$string... }, "Prompts" ];

        StringRiffle[ DeleteCases[ prompts, "" ], "\n\n" ]
    ],
    throwInternalFailure
];

applyPromptGenerators // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toPromptGenerator*)
toPromptGenerator // beginDefinition;
toPromptGenerator[ ___ ] /; $VersionNumber < 14.1 := Nothing;
toPromptGenerator[ name_String ] := toPromptGenerator @ $defaultPromptGenerators @ name;
toPromptGenerator[ generator_LLMPromptGenerator ] := generator;
toPromptGenerator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePromptGeneratorData*)
makePromptGeneratorData // beginDefinition;

(* TODO: build the full spec supported by LLMPromptGenerator:
    * Input
    * Messages
    * LLMEvaluator
    * ChatObject
    * { spec1, spec2, ... }
*)
makePromptGeneratorData[ settings_, messages: { ___, KeyValuePattern[ "Content" -> input_ ] } ] := <|
    "Input"    -> input,
    "Messages" -> messages
|>;

makePromptGeneratorData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*applyPromptGenerator*)
applyPromptGenerator // beginDefinition;
applyPromptGenerator[ gen_LLMPromptGenerator, data_Association ] := formatGeneratedPrompt @ gen @ data;
applyPromptGenerator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatGeneratedPrompt*)
formatGeneratedPrompt // beginDefinition;
formatGeneratedPrompt[ string_String ] := string;
formatGeneratedPrompt[ content_List ] := StringJoin[ formatGeneratedPrompt /@ content ];
formatGeneratedPrompt[ KeyValuePattern @ { "Type" -> "Text", "Data" -> data_ } ] := TextString @ data;
formatGeneratedPrompt[ KeyValuePattern @ { "Type" -> "Image", "Data" -> image_? image2DQ } ] := image;
formatGeneratedPrompt[ _Missing | None ] := "";
formatGeneratedPrompt[ expr_ ] := FormatToolResponse @ expr;
formatGeneratedPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
