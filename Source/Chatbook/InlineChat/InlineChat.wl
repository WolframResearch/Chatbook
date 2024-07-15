(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`InlineChat`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* FIXME:
    * Only notebook context is used, still need to hook up messages from inline chat window
    * Need to hook up static output replacements (writeInlineChatOutputCell)
    * Hook up proper styling for chat inputs/outputs in inline chat
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$WorkspaceChat*)
GeneralUtilities`SetUsage[ "\
$InlineChat gives True when chat is occurring in an attached chat cell and False otherwise." ];

$InlineChat = False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Subcontexts*)
Get[ "Wolfram`Chatbook`InlineChat`Evaluate`" ];
Get[ "Wolfram`Chatbook`InlineChat`UI`"       ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
