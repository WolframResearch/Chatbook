(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Services`" ];

(* :!CodeAnalysis::BeginBlock:: *)

HoldComplete[
    `$availableServices;
    `$enableLLMServices;
    `$servicesLoaded;
    `$useLLMServices;
    `getAvailableServiceNames;
    `getServiceModelList;
    `modelListCachedQ;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];
Needs[ "Wolfram`Chatbook`Models`" ];

$ContextAliases[ "llm`" ] = "LLMServices`";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$enableLLMServices = Automatic;
$modelListCache    = <| |>;
$modelSortOrder    = { "Snapshot", "FineTuned", "DisplayName" };
$servicesLoaded    = False;
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
(*modelListCachedQ*)
modelListCachedQ // beginDefinition;
modelListCachedQ[ service_String ] := ListQ @ Lookup[ $modelListCache, service ];
modelListCachedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$availableServiceNames*)
$availableServiceNames := getAvailableServiceNames[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAvailableServiceNames*)
getAvailableServiceNames // beginDefinition;
getAvailableServiceNames[ ] := getAvailableServiceNames @ $useLLMServices;
getAvailableServiceNames[ False ] := Keys @ $fallBackServices;
getAvailableServiceNames[ True ] := getAvailableServiceNames0[ ];
getAvailableServiceNames // endDefinition;


getAvailableServiceNames0 // beginDefinition;

getAvailableServiceNames0[ ] := (
    PacletInstall[ "Wolfram/LLMFunctions" ];
    Needs[ "LLMServices`" -> None ];
    getAvailableServiceNames0 @ llm`LLMServiceInformation @ llm`ChatSubmit
);

getAvailableServiceNames0[ services_Association ] :=
    Keys @ services;

getAvailableServiceNames0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getServiceModels*)
getServiceModelList // beginDefinition;

getServiceModelList[ service_String ] :=
    Lookup[
        $modelListCache,
        service,
        getServiceModelList[ service, llm`LLMServiceInformation[ llm`ChatSubmit, service ] ]
    ];

getServiceModelList[ service_String, info_Association ] :=
    getServiceModelList[ service, info, getModelListQuietly @ info ];

getServiceModelList[ service_, info_, Missing[ "NotConnected" ] ] :=
    Missing[ "NotConnected" ];

getServiceModelList[ "OpenAI", info_, models: { "gpt-4", "gpt-3.5-turbo-0613" } ] :=
    With[ { full = getOpenAIChatModels[ ] },
        getServiceModelList[ "OpenAI", info, full ] /; MatchQ[ full, Except[ models, { __String } ] ]
    ];

getServiceModelList[ service_String, info_, models0_List ] := Enclose[
    Module[ { models, ordering, sorted },
        models   = ConfirmMatch[ standardizeModelData[ service, models0 ], { ___Association }, "Models" ];
        ordering = Lookup /@ ConfirmMatch[ $modelSortOrder, { __String }, "ModelSortOrder" ];
        sorted   = SortBy[ models, ordering ];
        $modelListCache[ service ] = sorted
    ],
    throwInternalFailure
];

getServiceModelList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getModelListQuietly*)
getModelListQuietly // beginDefinition;

(* cSpell: ignore nprmtv, genconerr, invs, nolink *)
getModelListQuietly[ info_Association ] := Quiet[
    Check[ info[ "ModelList" ], Missing[ "NotConnected" ], DialogInput::nprmtv ],
    { DialogInput::nprmtv, ServiceConnect::genconerr, ServiceConnect::invs, ServiceExecute::nolink }
];

getModelListQuietly // endDefinition;

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
    getAvailableServices0 @ llm`LLMServiceInformation @ llm`ChatSubmit
);

getAvailableServices0[ services0_Association? AssociationQ ] := Enclose[
    Catch @ Module[ { services, withServiceName, withModels },

        services        = Replace[ services0, <| |> :> $fallBackServices ];
        withServiceName = Association @ KeyValueMap[ #1 -> <| "Service" -> #1, #2 |> &, services ];

        withModels = Replace[
            withServiceName,
            as: KeyValuePattern @ { "Service" -> service_String } :>
                RuleCondition @ With[ { models = getServiceModelList @ service },
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
