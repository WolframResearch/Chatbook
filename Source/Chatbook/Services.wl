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
    `getAvailableServices;
    `getServiceModelList;
    `modelListCachedQ;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];
Needs[ "Wolfram`Chatbook`Models`" ];
Needs[ "Wolfram`Chatbook`UI`"     ];

$ContextAliases[ "llm`" ] = "LLMServices`";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$enableLLMServices = Automatic;
$modelListCache    = <| |>;
$modelSortOrder    = { "Snapshot", "FineTuned", "DisplayName" };
$servicesLoaded    = False;
$useLLMServices   := MatchQ[ $enableLLMServices, Automatic|True ] && TrueQ @ $llmServicesAvailable;
$serviceCache      = None;

$llmServicesAvailable := $llmServicesAvailable = (
    PacletInstall[ "Wolfram/LLMFunctions" ];
    PacletNewerQ[ PacletObject[ "Wolfram/LLMFunctions" ], "1.2.2" ]
);

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*InvalidateServiceCache*)
InvalidateServiceCache // beginDefinition;
InvalidateServiceCache[ ] := ($serviceCache = None; Null);
InvalidateServiceCache // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Available Services*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*modelListCachedQ*)
modelListCachedQ // beginDefinition;
modelListCachedQ[ service_String ] := ListQ @ $serviceCache[ service, "CachedModels" ];
modelListCachedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$availableServiceNames*)
$availableServiceNames := getAvailableServiceNames[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAvailableServiceNames*)
getAvailableServiceNames // beginDefinition;
getAvailableServiceNames[ ] := getAvailableServiceNames @ $availableServices;
getAvailableServiceNames[ services_Association ] := Keys @ services;
getAvailableServiceNames // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getServiceInformation*)
getServiceInformation // beginDefinition;
getServiceInformation[ service_String ] := getServiceInformation[ service, $availableServices ];
getServiceInformation[ service_String, services_Association ] := Lookup[ services, service, Missing[ "NotAvailable" ] ];
getServiceInformation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getServiceModels*)
getServiceModelList // beginDefinition;

getServiceModelList[ KeyValuePattern[ "Service" -> service_String ] ] :=
    getServiceModelList @ service;

getServiceModelList[ service_String ] :=
    With[ { models = $availableServices[ service, "CachedModels" ] },
        If[ ListQ @ models,
            models,
            getServiceModelList[ service, $availableServices[ service ] ]
        ]
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
    Module[ { models },
        models = ConfirmMatch[ preprocessModelList[ service, models0 ], { ___Association }, "Models" ];
        ConfirmAssert[ AssociationQ @ $serviceCache[ service ], "ServiceCache" ];
        $serviceCache[ service, "CachedModels" ] = models
    ],
    throwInternalFailure
];

getServiceModelList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*preprocessModelList*)
preprocessModelList // beginDefinition;

preprocessModelList[ service_, models0_List ] := Enclose[
    Module[ { models, ordering, sorted  },
        models   = ConfirmMatch[ standardizeModelData[ service, models0 ], { ___Association }, "Models" ];
        ordering = Lookup /@ ConfirmMatch[ $modelSortOrder, { __String }, "ModelSortOrder" ];
        sorted   = SortBy[ models, ordering ];
        sorted
    ],
    throwInternalFailure
];

preprocessModelList // endDefinition;

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

getAvailableServices0[ ] :=
    With[ { services = $serviceCache }, services /; AssociationQ @ services ];

getAvailableServices0[ ] := (
    PacletInstall[ "Wolfram/LLMFunctions" ];
    Needs[ "LLMServices`" -> None ];
    getAvailableServices0 @ llm`LLMServiceInformation @ llm`ChatSubmit
);

getAvailableServices0[ services0_Association? AssociationQ ] := Enclose[
    Catch @ Module[ { services, withServiceName, withIcon, preCached },

        services = ConfirmMatch[
            Replace[ services0, <| |> :> $fallBackServices ],
            _Association? (AllTrue[ AssociationQ ]),
            "Services"
        ];

        withServiceName = Association @ KeyValueMap[ #1 -> <| "Service" -> #1, #2 |> &, services ];
        withIcon = Association[ #, "Icon" -> serviceIcon @ # ] & /@ withServiceName;

        preCached = ConfirmMatch[
            checkLiteralModelLists /@ withIcon,
            _Association? (AllTrue[ AssociationQ ]),
            "CacheCheck"
        ];

        $servicesLoaded = True;
        $serviceCache   = preCached
    ],
    throwInternalFailure
];

getAvailableServices0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkLiteralModelLists*)
checkLiteralModelLists // beginDefinition;

checkLiteralModelLists[ service: KeyValuePattern[ "ModelList" -> models_List ] ] :=
    Association[ service, "CachedModels" -> preprocessModelList[ service, models ] ];

checkLiteralModelLists[ service: KeyValuePattern[ "ModelList" :> models: { (_String | KeyValuePattern @ { })... } ] ] :=
    Association[ service, "CachedModels" -> preprocessModelList[ service, models ] ];

checkLiteralModelLists[ service_Association ] :=
    service;

checkLiteralModelLists // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$fallBackServices*)
$fallBackServices = <|
    "OpenAI" -> <|
        "Icon"      -> chatbookIcon[ "ServiceIconOpenAI" ],
        "ModelList" :> getOpenAIChatModels[ ]
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
