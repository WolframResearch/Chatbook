(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Subcontexts*)
$subcontexts = {
    "Wolfram`Chatbook`ACP`Common`",
    "Wolfram`Chatbook`ACP`State`",
    "Wolfram`Chatbook`ACP`Transcript`",
    "Wolfram`Chatbook`ACP`Rendering`",
    "Wolfram`Chatbook`ACP`Agents`",
    "Wolfram`Chatbook`ACP`Connection`",
    "Wolfram`Chatbook`ACP`Git`",
    "Wolfram`Chatbook`ACP`Review`",
    "Wolfram`Chatbook`ACP`UI`"
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
