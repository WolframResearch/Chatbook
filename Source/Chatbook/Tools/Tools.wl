(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Load Subcontexts*)
Get[ "Wolfram`Chatbook`Tools`Common`"         ];
Get[ "Wolfram`Chatbook`Tools`ToolOptions`"    ];
Get[ "Wolfram`Chatbook`Tools`Examples`"       ];
Get[ "Wolfram`Chatbook`Tools`ExpressionURIs`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Default Tool Definitions*)
Get[ "Wolfram`Chatbook`Tools`ChatPreferences`" ];
Get[ "Wolfram`Chatbook`Tools`NotebookEditor`"  ];
Get[ "Wolfram`Chatbook`Tools`WolframAlpha`"    ];
Get[ "Wolfram`Chatbook`Tools`DefaultTools`"    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
