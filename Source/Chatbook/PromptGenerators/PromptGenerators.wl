(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Subcontexts*)
$subcontexts = {
    "Wolfram`Chatbook`PromptGenerators`Common`",
    "Wolfram`Chatbook`PromptGenerators`DefaultPromptGenerators`",
    "Wolfram`Chatbook`PromptGenerators`EmbeddingContext`",
    "Wolfram`Chatbook`PromptGenerators`NotebookChunking`",
    "Wolfram`Chatbook`PromptGenerators`RelatedDocumentation`",
    "Wolfram`Chatbook`PromptGenerators`RelatedWolframAlphaQueries`",
    "Wolfram`Chatbook`PromptGenerators`VectorDatabases`"
};

Scan[ Needs[ # -> None ] &, $subcontexts ];

$ChatbookContexts = Union[ $ChatbookContexts, $subcontexts ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
