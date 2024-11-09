(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`NotebookAssistanceInstructions`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$notebookAssistanceInputKeys = { "GettingStarted", "ErrorMessage" };
$$notebookAssistanceInputKey = Alternatives @@ $notebookAssistanceInputKeys;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$NotebookAssistanceInputs*)
$NotebookAssistanceInputs := loadNotebookAssistanceInputs[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadNotebookAssistanceInputs*)
loadNotebookAssistanceInputs // beginDefinition;

loadNotebookAssistanceInputs[ ] := Enclose[
    Module[ { as },
        as = ConfirmBy[ AssociationMap[ loadNotebookAssistanceInput, $notebookAssistanceInputKeys ], AssociationQ, "Inputs" ];
        WithCleanup[
            Unprotect @ $NotebookAssistanceInputs,
            $NotebookAssistanceInputs = ConfirmBy[ as, AllTrue @ StringQ, "Result" ],
            Protect @ $NotebookAssistanceInputs
        ]
    ],
    throwInternalFailure
];

loadNotebookAssistanceInputs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*loadNotebookAssistanceInput*)
loadNotebookAssistanceInput // beginDefinition;

loadNotebookAssistanceInput[ name: $$notebookAssistanceInputKey ] := Enclose[
    usingFrontEnd @ ConfirmBy[
        trRaw[ "NotebookAssistanceInput"<>name ],
        StringQ,
        "LoadNotebookAssistanceInput"
    ],
    throwInternalFailure
];

loadNotebookAssistanceInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getNotebookAssistanceInput*)
getNotebookAssistanceInput // beginDefinition;

getNotebookAssistanceInput[ name_String ] := Enclose[
    Module[ { inputs, result },
        inputs = ConfirmBy[ $NotebookAssistanceInputs, AssociationQ, "Inputs" ];
        result = ConfirmMatch[ Lookup[ inputs, name ], _Missing | $$string, "Result" ];
        If[ StringQ @ result, needsBasePrompt[ "NotebookAssistance"<>name ] ];
        result
    ],
    throwInternalFailure
];

getNotebookAssistanceInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
