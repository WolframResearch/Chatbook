(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Formatting`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"           ];
Needs[ "Wolfram`Chatbook`Common`"    ];
Needs[ "Wolfram`Chatbook`CodeCheck`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Alternate Chat Mode Styles*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*assistantMessageBoxActive*)
assistantMessageBoxActive // beginDefinition;

assistantMessageBoxActive[ box_, "Workspace" ] :=
    TemplateBox[
        { Cell[ BoxData @ StyleBox[ box, "Text" ], Editable -> True ] },
        "AssistantMessageBoxActive"
    ];

assistantMessageBoxActive[ box_, "Sidebar" ] :=
    TemplateBox[
        { Cell[ BoxData @ StyleBox[ box, "Text" ], Editable -> True ] },
        "NotebookAssistant`Sidebar`AssistantMessageBoxActive"
    ];

assistantMessageBoxActive // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
