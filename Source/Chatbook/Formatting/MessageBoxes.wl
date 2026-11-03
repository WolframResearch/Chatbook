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
(*Template Boxes*)
$userMessageBoxTemplate := $userMessageBoxTemplate =
    Function @ Evaluate @ inlineTemplateBox @ TemplateBox[ { # }, "UserMessageBox" ];

$assistantMessageBoxTemplate := $assistantMessageBoxTemplate =
    Function @ Evaluate @ inlineTemplateBox @ TemplateBox[ { # }, "AssistantMessageBox" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*assistantMessageBox*)
assistantMessageBox // beginDefinition;

assistantMessageBox[ box_ ] :=
    assistantMessageBox[ box, $InlineChat ];

assistantMessageBox[ box_, True ] :=
    With[ { template = $assistantMessageBoxTemplate @ box },
        template /; MatchQ[ template, TemplateBox[ __, DisplayFunction -> _, ___ ] ]
    ];

assistantMessageBox[ box_, Except[ True ] ] :=
    TemplateBox[ { box }, "AssistantMessageBox" ];

assistantMessageBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*assistantMessageBoxActive*)
assistantMessageBoxActive // beginDefinition;

assistantMessageBoxActive[ box_ ] :=
    assistantMessageBoxActive[ box, "Inline" ];

assistantMessageBoxActive[ box_, "Inline" ] :=
    With[ { template = $assistantMessageBoxTemplate @ box },
        template /; MatchQ[ template, TemplateBox[ __, DisplayFunction -> _, ___ ] ]
    ];

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
(* ::Subsection::Closed:: *)
(*userMessageBox*)
userMessageBox // beginDefinition;

userMessageBox[ box_ ] :=
    userMessageBox[ box, $InlineChat ];

userMessageBox[ box_, True ] :=
    With[ { template = $userMessageBoxTemplate @ box },
        template /; MatchQ[ template, TemplateBox[ __, DisplayFunction -> _, ___ ] ]
    ];

userMessageBox[ box_, Except[ True ] ] :=
    TemplateBox[ { box }, "UserMessageBox" ];

userMessageBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
