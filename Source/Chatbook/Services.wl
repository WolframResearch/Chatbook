(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Services`" ];
Begin[ "`Private`" ];

(* :!CodeAnalysis::BeginBlock:: *)

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];
Needs[ "Wolfram`Chatbook`UI`"     ];

$ContextAliases[ "llm`" ] = "LLMServices`";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$allowConnectionDialog = True;
$enableLLMServices     = Automatic;
$modelListCache        = <| |>;
$modelSortOrder        = { "Preview", "Snapshot", "FineTuned", "Date", "DisplayName" };
$servicesLoaded        = False;
$useLLMServices       := MatchQ[ $enableLLMServices, Automatic|True ] && TrueQ @ $llmServicesAvailable;
$serviceCache          = None;

$llmServicesAvailable := $llmServicesAvailable = (
    PacletInstall[ "Wolfram/LLMFunctions" ];
    PacletNewerQ[ PacletObject[ "Wolfram/LLMFunctions" ], "1.2.2" ]
);

$$llmServicesFailure = HoldPattern @ Failure[
    LLMServices`LLMServiceInformation,
    KeyValuePattern[ "MessageTemplate" :> LLMServices`LLMServiceInformation::corrupt ]
];

(* Used to filter out models that are known not to work with chat notebooks: *)
$invalidModelNameParts = <|
    "OpenAI" -> WordBoundary~~("instruct"|"realtime")~~WordBoundary
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*InvalidateServiceCache*)
InvalidateServiceCache // beginDefinition;
InvalidateServiceCache[ ] := catchAlways[ $serviceCache = None; updateDynamics[ { "Models", "Services" } ]; ];
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
getAvailableServiceNames // Options = { "IncludeHidden" -> True };

getAvailableServiceNames[ opts: OptionsPattern[ ] ] :=
    getAvailableServiceNames[ $availableServices, opts ];

getAvailableServiceNames[ services_Association, opts: OptionsPattern[ ] ] :=
    If[ TrueQ @ OptionValue[ "IncludeHidden" ],
        Keys @ services,
        Keys @ DeleteCases[ services, KeyValuePattern[ "Hidden" -> True ] ]
    ];

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
        Replace[
            models,
            {
                {  } | None :> Missing[ "NoModelList" ],
                list_List :> list,
                _ :> getServiceModelList[ service, $availableServices[ service ] ]
            }
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
        $serviceCache[ service, "CachedModels" ] = models;
        updateDynamics[ "Services" ];
        models
    ],
    throwInternalFailure
];

getServiceModelList[ service_String, info_, Missing[ "NoModelList" ] ] :=
    Missing[ "NoModelList" ];

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

getModelListQuietly[ info_Association ] /; ! $allowConnectionDialog :=
    Block[ { $allowConnectionDialog = True, DialogInput = $Failed & },
        getModelListQuietly @ info
    ];

(* cSpell: ignore nprmtv, genconerr, invs, nolink *)
getModelListQuietly[ info_Association ] := Quiet[
    checkModelList[ info, Check[ info[ "ModelList" ], Missing[ "NotConnected" ], DialogInput::nprmtv ] ],
    { DialogInput::nprmtv, ServiceConnect::genconerr, ServiceConnect::invs, ServiceExecute::nolink }
];

getModelListQuietly // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkModelList*)
checkModelList // beginDefinition;

checkModelList[ info_, models_List ] :=
    Select[ models, usableChatModelQ @ info ];

checkModelList[ info_, $Canceled | $Failed | Missing[ "NotConnected" ] ] :=
    Missing[ "NotConnected" ];

checkModelList[ info_, Failure[ "ConfirmationFailed", KeyValuePattern[ "Expression" :> expr_ ] ] ] :=
    checkModelList[ info, expr ];

checkModelList[ info_, _ServiceExecute ] := (
    If[ AssociationQ @ Wolfram`LLMFunctions`APIs`Common`$ConnectionCache,
        KeyDropFrom[ Wolfram`LLMFunctions`APIs`Common`$ConnectionCache, info[ "Service" ] ]
    ];
    Missing[ "NotConnected" ]
);

checkModelList[ info_, other_ ] :=
    Missing[ "NoModelList" ];

checkModelList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*usableChatModelQ*)
usableChatModelQ // beginDefinition;

usableChatModelQ[ KeyValuePattern[ "Service" -> service_ ] ] :=
    usableChatModelQ @ service;

usableChatModelQ[ service_String ] :=
    With[ { patt = $invalidModelNameParts @ service },
        If[ MissingQ @ patt,
            True &,
            usableChatModelQ[ patt, # ] &
        ]
    ];

usableChatModelQ[ patt_, model_ ] := Enclose[
    Module[ { name },
        name = ConfirmBy[ toModelName @ model, StringQ, "Name" ];
        ConfirmMatch[ StringFreeQ[ name, patt, IgnoreCase -> True ], True|False, "Result" ]
    ],
    throwInternalFailure
];

usableChatModelQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$availableServices*)
$availableServices := Block[ { $availableServices = <| |> }, getAvailableServices[ ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getAvailableServices*)
getAvailableServices // beginDefinition;
getAvailableServices[ ] := getAvailableServices @ $useLLMServices;
getAvailableServices[ False ] := getAvailableServices0 @ $fallBackServices;
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

(* If stored service information is corrupt, attempt to reset it and try again: *)
getAvailableServices0[ $$llmServicesFailure ] := Enclose[
    Catch @ Module[ { services },
        ConfirmMatch[ llm`ResetServices[ ], { __Success }, "Reset" ];
        services = llm`LLMServiceInformation @ llm`ChatSubmit;
        (* If it's still failing, return the failure: *)
        If[ MatchQ[ services, $$llmServicesFailure ], Throw @ services ];
        (* Otherwise we can proceed normally: *)
        getAvailableServices0 @ ConfirmBy[ services, AssociationQ, "Services" ]
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
addToMXInitialization[
    Null
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
