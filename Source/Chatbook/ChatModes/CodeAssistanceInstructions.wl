(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`CodeAssistanceInstructions`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$codeAssistanceInputKeys = { "GettingStarted", "ErrorMessage" };
$$codeAssistanceInputKey = Alternatives @@ $codeAssistanceInputKeys;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*$CodeAssistanceInputs*)
$CodeAssistanceInputs := loadCodeAssistanceInputs[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadCodeAssistanceInputs*)
loadCodeAssistanceInputs // beginDefinition;

loadCodeAssistanceInputs[ ] := Enclose[
    Module[ { as },
        as = ConfirmBy[ AssociationMap[ loadCodeAssistanceInput, $codeAssistanceInputKeys ], AssociationQ, "Inputs" ];
        WithCleanup[
            Unprotect @ $CodeAssistanceInputs,
            $CodeAssistanceInputs = ConfirmBy[ as, AllTrue @ StringQ, "Result" ],
            Protect @ $CodeAssistanceInputs
        ]
    ],
    throwInternalFailure
];

loadCodeAssistanceInputs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*loadCodeAssistanceInput*)
loadCodeAssistanceInput // beginDefinition;

loadCodeAssistanceInput[ name: $$codeAssistanceInputKey ] := Enclose[
    usingFrontEnd @ ConfirmBy[
        trRaw[ "CodeAssistanceInput"<>name ],
        StringQ,
        "LoadCodeAssistanceInput"
    ],
    throwInternalFailure
];

loadCodeAssistanceInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getCodeAssistanceInput*)
getCodeAssistanceInput // beginDefinition;

getCodeAssistanceInput[ name_String ] := Enclose[
    Module[ { inputs, result },
        inputs = ConfirmBy[ $CodeAssistanceInputs, AssociationQ, "Inputs" ];
        result = ConfirmMatch[ Lookup[ inputs, name ], _Missing | $$string, "Result" ];
        If[ StringQ @ result, needsBasePrompt[ "CodeAssistance"<>name ] ];
        result
    ],
    throwInternalFailure
];

getCodeAssistanceInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
