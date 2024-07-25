(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* TODO:
    * Workspace Chat
        * Get context from multiple notebooks
        * Set up an LLM subtask to choose relevant notebooks for inclusion
    * Fine-grained selection prompts (e.g. specific character ranges, instead of whole cells)
    * Update serialization to include cell identifiers when serializing notebook context
    * Create NotebookEditor tool that utilizes these cell identifiers to allow for editing of notebooks
    * Create test writer tool
    * Define a `$ChatEvaluationMode` that gives "Inline", "Workspace", or None based on the current chat mode
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$WorkspaceChat*)
GeneralUtilities`SetUsage[ "\
$WorkspaceChat gives True when chat is occurring in a separate dedicated chat window and False otherwise." ];

$WorkspaceChat = False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$WorkspaceChat*)
GeneralUtilities`SetUsage[ "\
$InlineChat gives True when chat is occurring in an attached chat cell and False otherwise." ];

$InlineChat = False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Subcontexts*)
$subcontexts = {
    "Wolfram`Chatbook`ChatModes`Common`",
    "Wolfram`Chatbook`ChatModes`Context`",
    "Wolfram`Chatbook`ChatModes`Evaluate`",
    "Wolfram`Chatbook`ChatModes`ShowCodeAssistance`",
    "Wolfram`Chatbook`ChatModes`UI`"
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
