(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Services`" ];

(* :!CodeAnalysis::BeginBlock:: *)

HoldComplete[
    `$availableServices;
    `$enableLLMServices;
    `$servicesLoaded;
    `$useLLMServices;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];
Needs[ "Wolfram`Chatbook`Models`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$enableLLMServices = Automatic;
$servicesLoaded   := False;
$useLLMServices   := MatchQ[ $enableLLMServices, Automatic|True ] && TrueQ @ $llmServicesAvailable;

$llmServicesAvailable := $llmServicesAvailable = (
    PacletInstall[ "Wolfram/LLMFunctions" ];
    PacletNewerQ[ PacletObject[ "Wolfram/LLMFunctions" ], "1.2.2" ]
);

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Available Services*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$availableServices*)
$availableServices := getAvailableServices[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAvailableServices*)
getAvailableServices // beginDefinition;
getAvailableServices[ ] := getAvailableServices @ $useLLMServices;
getAvailableServices[ False ] := $fallBackServices;
getAvailableServices[ True ] := getAvailableServices0[ ];
getAvailableServices // endDefinition;

getAvailableServices0 // beginDefinition;

getAvailableServices0[ ] := (
    PacletInstall[ "Wolfram/LLMFunctions" ];
    Needs[ "LLMServices`" -> None ];
    getAvailableServices0 @ LLMServices`LLMServiceInformation[ LLMServices`ChatSubmit, "Services" ]
);

getAvailableServices0[ services0_Association? AssociationQ ] := Enclose[
    Catch @ Module[ { services, withServiceName, withModels },

        services = Replace[ services0, <| |> :> $fallBackServices ];
        withServiceName = Association @ KeyValueMap[ #1 -> <| "ServiceName" -> #1, #2 |> &, services ];

        withModels = Replace[
            withServiceName,
            as: KeyValuePattern @ { "ServiceName" -> service_String, "ModelList" -> func_ } :>
                RuleCondition @ With[ { models = func[ ] },
                    If[ ListQ @ models, (* workaround for KeyValuePattern bug *)
                        <| as, "Models" -> standardizeModelData[ service, models ] |>,
                        as
                    ]
                ],
            { 1 }
        ];

        $servicesLoaded = True;

        getAvailableServices0[ services0 ] = withModels
    ],
    throwInternalFailure[ getAvailableServices0[ ], ## ] &
];

getAvailableServices0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$fallBackServices*)
$fallBackServices = <|
    "OpenAI" -> <|
        "ModelList" -> getOpenAIChatModels
    |>
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getOpenAIChatModels*)
getOpenAIChatModels // beginDefinition;
getOpenAIChatModels[ ] := Select[ getModelList[ ], chatModelQ ];
getOpenAIChatModels // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
