(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`WorkspaceChat`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* TODO:
    * Get context from multiple notebooks
    * Allow exclusion of entire notebooks via the usual chat setting
    * Set up an LLM subtask to choose relevant notebooks for inclusion
    * Update serialization to include cell identifiers when serializing notebook context
    * Create NotebookEditor tool that utilizes these cell identifiers to allow for editing of notebooks
    * Create test writer tool
*)

(* FIXME:
    * Don't attach to left when it would be offscreen (attach to right instead, or just float it)
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$WorkspaceChat*)
GeneralUtilities`SetUsage[ "\
$WorkspaceChat gives True when chat is occurring in a separate dedicated chat window and False otherwise." ];

$WorkspaceChat = False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Subcontexts*)
Get[ "Wolfram`Chatbook`WorkspaceChat`Context`"            ];
Get[ "Wolfram`Chatbook`WorkspaceChat`Evaluate`"           ];
Get[ "Wolfram`Chatbook`WorkspaceChat`ShowCodeAssistance`" ];
Get[ "Wolfram`Chatbook`WorkspaceChat`UI`"                 ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
