(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PreferencesContent`" ];

HoldComplete[
    `createPreferencesContent;
    `openPreferencesPage;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`Dynamics`"         ];
Needs[ "Wolfram`Chatbook`Errors`"           ];
Needs[ "Wolfram`Chatbook`Models`"           ];
Needs[ "Wolfram`Chatbook`PersonaManager`"   ];
Needs[ "Wolfram`Chatbook`Personas`"         ];
Needs[ "Wolfram`Chatbook`PreferencesUtils`" ];
Needs[ "Wolfram`Chatbook`Services`"         ];
Needs[ "Wolfram`Chatbook`Settings`"         ];
Needs[ "Wolfram`Chatbook`ToolManager`"      ];
Needs[ "Wolfram`Chatbook`UI`"               ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$preferencesPages = { "Notebooks", "Services", "Personas", "Tools" };
$$preferencesPage = Alternatives @@ $preferencesPages;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Main*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createPreferencesContent*)
createPreferencesContent[ ] := Enclose[
    Module[ { notebookSettings, serviceSettings, personaSettings, toolSettings, tabView, reset },

        notebookSettings = ConfirmMatch[ preferencesContent[ "Notebooks" ], _Dynamic|_DynamicModule, "Notebooks" ];
        serviceSettings  = ConfirmMatch[ preferencesContent[ "Services"  ], _Dynamic|_DynamicModule, "Services"  ];
        personaSettings  = ConfirmMatch[ preferencesContent[ "Personas"  ], _Dynamic|_DynamicModule, "Personas"  ];
        toolSettings     = ConfirmMatch[ preferencesContent[ "Tools"     ], _Dynamic|_DynamicModule, "Tools"     ];

        tabView = TabView[
            {
                { "Notebooks", "Notebooks" -> notebookSettings },
                { "Services" , "Services"  -> serviceSettings  },
                { "Personas" , "Personas"  -> personaSettings  },
                { "Tools"    , "Tools"     -> toolSettings     }
            },
            Dynamic @ CurrentValue[
                $FrontEnd,
                { PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "PreferencesTab" },
                "Notebooks"
            ],
            Background   -> None,
            FrameMargins -> { { 2, 2 }, { 2, 3 } },
            ImageMargins -> { { 10, 10 }, { 2, 2 } },
            ImageSize    -> { 640, Automatic },
            LabelStyle   -> "feTabView"
        ];

        reset = Pane[ $resetButton, ImageMargins -> { { 20, 0 }, { 0, 10 } }, ImageSize -> 640 ];

        Grid[
            {
                $verticalSpacer,
                { tabView, "" },
                $verticalSpacer,
                { reset, SpanFromLeft },
                $verticalSpacer
            },
            Alignment  -> Left,
            BaseStyle  -> "defaultGrid",
            AutoDelete -> False,
            FrameStyle -> { AbsoluteThickness[ 1 ], GrayLevel[ 0.898 ] },
            Dividers   -> { False, { 4 -> True } },
            Spacings   -> { 0, 0.7 }
        ]
    ],
    throwInternalFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*preferencesContent*)
preferencesContent // beginDefinition;
preferencesContent[ "Notebooks" ] := trackedDynamic[ notebookSettingsPanel[ ], { "Models" } ];
preferencesContent[ "Personas"  ] := trackedDynamic[ personaSettingsPanel[ ], { "Personas" } ];
preferencesContent[ "Services"  ] := trackedDynamic[ "Coming soon.", { "Models" } ];
preferencesContent[ "Tools"     ] := toolSettingsPanel[ ];
preferencesContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebooks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookSettingsPanel*)
notebookSettingsPanel // beginDefinition;

notebookSettingsPanel[ ] := Pane[
    DynamicModule[
        { display = ProgressIndicator[ Appearance -> "Percolate" ] },
        Dynamic[ display ],
        Initialization :> (display = createNotebookSettingsPanel[ ]),
        SynchronousInitialization -> False
    ],
    FrameMargins -> { { 8, 8 }, { 13, 13 } },
    Spacings     -> { 0, 1.5 }
];

notebookSettingsPanel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createNotebookSettingsPanel*)
createNotebookSettingsPanel // beginDefinition;

createNotebookSettingsPanel[ ] := Enclose[
    Module[ { defaultSettingsLabel, defaultSettingsContent, interfaceLabel, interfaceContent },

        defaultSettingsLabel = Style[ "Default Settings", "subsectionText" ];

        defaultSettingsContent = ConfirmMatch[
            trackedDynamic[ makeDefaultSettingsContent[ ], "Preferences" ],
            Except[ _makeDefaultSettingsContent ],
            "DefaultSettings"
        ];

        interfaceLabel = Style[ "Chat Notebook Interface", "subsectionText" ];

        interfaceContent = ConfirmMatch[
            makeInterfaceContent[ ],
            Except[ _makeInterfaceContent ],
            "Interface"
        ];

        createNotebookSettingsPanel[ ] = Grid[
            {
                { defaultSettingsLabel   },
                { defaultSettingsContent },
                { Spacer[ 1 ]            },
                { interfaceLabel         },
                { interfaceContent       }
            },
            Alignment -> { Left, Baseline },
            Spacings  -> { 0, 0.7 }
        ]
    ],
    throwInternalFailure
];

createNotebookSettingsPanel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeDefaultSettingsContent*)
makeDefaultSettingsContent // beginDefinition;

makeDefaultSettingsContent[ ] := Enclose[
    Module[ { personaSelector, modelSelector, temperatureSlider, row },

        personaSelector   = ConfirmMatch[ makePersonaSelector[ ], _PopupMenu, "PersonaSelector" ];
        modelSelector     = ConfirmMatch[ makeModelSelector[ ], _DynamicModule, "ModelSelector" ];
        temperatureSlider = ConfirmMatch[ makeTemperatureSlider[ ], _Slider, "TemperatureSlider" ];
        row               = Row[ { ## }, Spacer[ 3 ] ] &;

        Grid[
            {
                { row[ "Default Persona:"    , personaSelector   ] },
                { row[ modelSelector                             ] },
                { row[ "Default Temperature:", temperatureSlider ] }
            },
            Alignment -> { Left, Baseline },
            Spacings  -> { 0, 0.7 }
        ]
    ],
    throwInternalFailure
];

makeDefaultSettingsContent // endDefinition;

(* FIXME: temporary definitions *)
makeSnapshotModelCheckbox[ ] := Checkbox[ ];
makeSnapshotModelHelp[ ] := Tooltip[ "?", "" ];
makeTemperatureSlider[ ] := Slider[ ];
makeInterfaceContent[ ] := "Test content, please ignore.";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePersonaSelector*)
makePersonaSelector // beginDefinition;

makePersonaSelector[ ] :=
    makePersonaSelector @ GetPersonasAssociation[ ];

makePersonaSelector[ personas_Association? AssociationQ ] :=
    makePersonaSelector @ KeyValueMap[ personaPopupLabel, personas ];

makePersonaSelector[ personas: { (_String -> _).. } ] := PopupMenu[
    Dynamic[
        currentChatSettings[ $FrontEnd, "LLMEvaluator" ],
        (CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ] = #1) &
    ],
    personas
];

makePersonaSelector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*personaPopupLabel*)
personaPopupLabel // beginDefinition;

personaPopupLabel[ name_String, persona_Association ] := popupValue[
    name,
    personaDisplayName[ name, persona ],
    getPersonaMenuIcon[ persona, "Full" ]
];

personaPopupLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeModelSelector*)
makeModelSelector // beginDefinition;

makeModelSelector[ ] :=
    makeModelSelector @ $availableServices;

makeModelSelector[ services_Association? AssociationQ ] := Enclose[
    DynamicModule[ { default, service, model, state, serviceSelector, modelSelector },

        default = currentChatSettings[ $FrontEnd, "Model" ];
        service = ConfirmBy[ extractServiceName @ default, StringQ, "ServiceName" ];
        model   = ConfirmBy[ extractModelName @ default  , StringQ, "ModelName"   ];
        state   = If[ modelListCachedQ @ service, "Loaded", "Loading" ];

        modelSelector = If[ state === "Loaded",
                            makeModelNameSelector[ Dynamic @ service, Dynamic @ model ],
                            ""
                        ];

        serviceSelector = makeServiceSelector[
            Dynamic @ service,
            Dynamic @ model,
            Dynamic @ modelSelector,
            Dynamic @ state,
            services
        ];

        Row @ {
            "Default LLM Service:",
            Spacer[ 1 ],
            serviceSelector,
            Spacer[ 5 ],
            "Default Model:",
            Spacer[ 1 ],
            Dynamic[
                If[ state === "Loading", $loadingPopupMenu, modelSelector ],
                TrackedSymbols :> { state, modelSelector }
            ]
        },

        Initialization :> (
            modelSelector = catchAlways @ makeModelNameSelector[ Dynamic @ service, Dynamic @ model ];
            state = "Loaded";
        ),
        SynchronousInitialization -> False,
        SynchronousUpdating       -> False,
        UnsavedVariables          :> { state }
    ],
    throwInternalFailure
];

makeModelSelector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeServiceSelector*)
makeServiceSelector // beginDefinition;

makeServiceSelector[
    Dynamic[ service_ ],
    Dynamic[ model_ ],
    Dynamic[ modelSelector_ ],
    Dynamic[ state_ ],
    services_
] :=
    PopupMenu[
        Dynamic[
            extractServiceName @ CurrentChatSettings[ $FrontEnd, "Model" ],
            serviceSelectCallback[ Dynamic @ service, Dynamic @ model, Dynamic @ modelSelector, Dynamic @ state ]
        ],
        KeyValueMap[ popupValue[ #1, #2[ "Service" ], #2[ "Icon" ] ] &, services ]
    ];

makeServiceSelector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*serviceSelectCallback*)
serviceSelectCallback // beginDefinition;

serviceSelectCallback[ Dynamic[ service_ ], Dynamic[ model_ ], Dynamic[ modelSelector_ ], Dynamic[ state_ ] ] :=
    serviceSelectCallback[ #1, Dynamic @ service, Dynamic @ model, Dynamic @ modelSelector, Dynamic @ state ] &;

serviceSelectCallback[
    selected_String, (* The value chosen via PopupMenu *)
    Dynamic[ service_Symbol ],
    Dynamic[ model_Symbol ],
    Dynamic[ modelSelector_Symbol ],
    Dynamic[ state_Symbol ]
] := catchAlways[
    service = selected;

    (* Switch model name selector to loading view: *)
    If[ ! modelListCachedQ @ selected, state = "Loading" ];

    (* Now that a new service has been selected, switch the model name to a previously used value for this service
       if available. If service has not been chosen before, determine the initial model from the registered service. *)
    model = getServiceDefaultModel @ selected;

    (* Store the service/model in FE settings: *)
    CurrentChatSettings[ $FrontEnd, "Model" ] = <| "Service" -> service, "Name" -> model |>;

    (* Finish loading the model name selector: *)
    If[ state === "Loading",
        SessionSubmit[
            modelSelector = makeModelNameSelector[ Dynamic @ service, Dynamic @ model ];
            state = "Loaded"
        ],
        modelSelector = makeModelNameSelector[ Dynamic @ service, Dynamic @ model ]
    ]
];

serviceSelectCallback // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeModelNameSelector*)
makeModelNameSelector // beginDefinition;

makeModelNameSelector[ Dynamic[ service_ ], Dynamic[ model_ ] ] := Enclose[
    Module[ { models, current, default, fallback },

        ensureServiceName @ service;
        ConfirmAssert[ StringQ @ service, "ServiceName" ];

        models   = ConfirmMatch[ getServiceModelList @ service, { __Association }, "ServiceModelList" ];
        current  = extractModelName @ CurrentChatSettings[ $FrontEnd, "Model" ];
        default  = ConfirmBy[ getServiceDefaultModel @ service, StringQ, "DefaultName" ];
        fallback = <| "Service" -> service, "Name" -> default |>;

        If[ ! MemberQ[ models, KeyValuePattern[ "Name" -> current ] ],
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings", "Model" } ] = fallback
        ];

        With[ { m = fallback },
            PopupMenu[
                Dynamic[
                    Replace[
                        extractModelName @ CurrentChatSettings[ $FrontEnd, "Model" ],
                        {
                            Except[ _String ] :> (
                                CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings", "Model" } ] = m
                            )
                        }
                    ],
                    modelSelectCallback[ Dynamic @ service, Dynamic @ model ]
                ],
                Map[ popupValue[ #[ "Name" ], #[ "DisplayName" ], #[ "Icon" ] ] &, models ],
                ImageSize -> Automatic
            ]
        ]
    ],
    throwInternalFailure
];

makeModelNameSelector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*modelSelectCallback*)
modelSelectCallback // beginDefinition;

modelSelectCallback[ Dynamic[ service_ ], Dynamic[ model_ ] ] :=
    modelSelectCallback[ #1, Dynamic @ service, Dynamic @ model ] &;

modelSelectCallback[
    selected_String, (* The value chosen via PopupMenu *)
    Dynamic[ service_Symbol ],
    Dynamic[ model_Symbol ]
] := catchAlways @ Enclose[
    model = selected;

    ensureServiceName @ service;
    ConfirmAssert[ StringQ @ service, "ServiceName" ];

    (* Remember the selected model for the given service, so it will be automatically chosen
       when choosing this service again: *)
    CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings", "ServiceDefaultModel", service } ] = model;

    (* Store the service/model in FE settings: *)
    CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings", "Model" } ] = <|
        "Service" -> service,
        "Name"    -> model
    |>
    ,
    throwInternalFailure
];

modelSelectCallback // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeTemperatureSlider*)
makeTemperatureSlider // beginDefinition;

makeTemperatureSlider[ ] :=
    Slider[
        Dynamic[ CurrentChatSettings[ $FrontEnd, "Temperature" ] ],
        { 0, 2, 0.01 },
        ImageSize    -> { 135, Automatic },
        ImageMargins -> { { 5, 0 }, { 5, 5 } },
        Appearance   -> "Labeled"
    ];

makeTemperatureSlider // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Services*)
(* TODO *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Personas*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*personaSettingsPanel*)
personaSettingsPanel // beginDefinition;

personaSettingsPanel[ ] :=
    DynamicModule[
        { display = ProgressIndicator[ Appearance -> "Percolate" ] },
        Dynamic[ display ],
        Initialization            :> (display = CreatePersonaManagerPanel[ ]),
        SynchronousInitialization -> False,
        UnsavedVariables          :> { display }
    ];

personaSettingsPanel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tools*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolSettingsPanel*)
toolSettingsPanel // beginDefinition;

toolSettingsPanel[ ] :=
    DynamicModule[
        { display = ProgressIndicator[ Appearance -> "Percolate" ] },
        Dynamic[ display ],
        Initialization            :> (display = CreateLLMToolManagerPanel[ ]),
        SynchronousInitialization -> False,
        UnsavedVariables          :> { display }
    ];

toolSettingsPanel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Common*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*popupValue*)
popupValue // beginDefinition;

popupValue[ value_String ] :=
    value -> value;

popupValue[ value_String, label: Except[ $$unspecified ] ] :=
    value -> label;

popupValue[ value_String, label: Except[ $$unspecified ], icon: Except[ $$unspecified ] ] :=
    value -> Row[ { resizeMenuIcon @ inlineTemplateBoxes @ icon, label }, Spacer[ 1 ] ];

popupValue // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ensureServiceName*)
ensureServiceName // beginDefinition;
ensureServiceName // Attributes = { HoldFirst };

ensureServiceName[ symbol_Symbol ] :=
    With[ { service = symbol },
        service /; StringQ @ service
    ];

ensureServiceName[ symbol_Symbol ] :=
    With[ { service = extractServiceName @ CurrentChatSettings[ $FrontEnd, "Model" ] },
        (symbol = service) /; StringQ @ service
    ];

ensureServiceName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractServiceName*)
extractServiceName // beginDefinition;
extractServiceName[ _String ] := "OpenAI";
extractServiceName[ KeyValuePattern[ "Service" -> service_String ] ] := service;
extractServiceName[ _ ] := $DefaultModel[ "Service" ];
extractServiceName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*extractModelName*)
extractModelName // beginDefinition;
extractModelName[ name_String ] := name;
extractModelName[ KeyValuePattern[ "Name" -> name_String ] ] := name;
extractModelName[ _ ] := $DefaultModel[ "Name" ];
extractModelName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getServiceDefaultModel*)
getServiceDefaultModel // beginDefinition;

getServiceDefaultModel[ selected_String ] := Replace[
    (* Use the last model name that was selected for this service if it exists: *)
    CurrentValue[
        $FrontEnd,
        { TaggingRules, "ChatNotebookSettings", "ServiceDefaultModel", selected }
    ],

    (* Otherwise determine a starting model from the registered service: *)
    $$unspecified :> (
        CurrentValue[
            $FrontEnd,
            { TaggingRules, "ChatNotebookSettings", "ServiceDefaultModel", selected }
        ] = chooseDefaultModelName @ selected
    )
];

getServiceDefaultModel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*chooseDefaultModelName*)
(*
    Choose a default initial model according to the following rules:
        1. If the service name is the same as the one in $DefaultModel, use the model name in $DefaultModel.
        2. If the registered service specifies a "DefaultModel" property, we'll use that.
        3. If the model list is already cached for the service, we'll use the first model in that list.
        4. Otherwise, give Automatic to indicate a model name that must be resolved later.
*)
chooseDefaultModelName // beginDefinition;
chooseDefaultModelName[ service_String ] /; service === $DefaultModel[ "Service" ] := $DefaultModel[ "Name" ];
chooseDefaultModelName[ service_String ] := chooseDefaultModelName @ $availableServices @ service;
chooseDefaultModelName[ KeyValuePattern[ "DefaultModel" -> model_ ] ] := toModelName @ model;
chooseDefaultModelName[ KeyValuePattern[ "CachedModels" -> models_List ] ] := chooseDefaultModelName @ models;
chooseDefaultModelName[ { model_, ___ } ] := toModelName @ model;
chooseDefaultModelName[ service_ ] := Automatic;
chooseDefaultModelName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeFrontEndAndNotebookSettingsContent*)
makeFrontEndAndNotebookSettingsContent // beginDefinition;

makeFrontEndAndNotebookSettingsContent[
    targetObj : _FrontEndObject | $FrontEndSession | _NotebookObject
] := Module[{
    personas = GetPersonasAssociation[],
    defaultPersonaPopupItems,
    setModelPopupItems,
    modelPopupItems
},
    defaultPersonaPopupItems = KeyValueMap[
        {persona, personaSettings} |-> (
            persona -> Row[{
                resizeMenuIcon[
                    getPersonaMenuIcon[personaSettings, "Full"]
                ],
                personaDisplayName[persona, personaSettings]
            }, Spacer[1]]
        ),
        personas
    ];

    (*----------------------------*)
    (* Compute the models to show *)
    (*----------------------------*)

    setModelPopupItems[] := (
        modelPopupItems = KeyValueMap[
            {modelName, settings} |-> (
                modelName -> Row[{
                    getModelMenuIcon[settings, "Full"],
                    modelDisplayName[modelName]
                }, Spacer[1]]
            ),
            Association[#Name -> # & /@ getServiceModelList["OpenAI"]]
        ];
    );

    (* Initial value. Called again if 'show snapshot models' changes. *)
    setModelPopupItems[];

    (*---------------------------------*)
    (* Return the toolbar menu content *)
    (*---------------------------------*)

    Grid[
        {
            {Row[{
                tr["Default Persona:"],
                PopupMenu[
                    Dynamic[
                        currentChatSettings[
                            targetObj,
                            "LLMEvaluator"
                        ],
                        Function[{newValue},
                            CurrentValue[
                                targetObj,
                                {TaggingRules, "ChatNotebookSettings", "LLMEvaluator"}
                            ] = newValue
                        ]
                    ],
                    defaultPersonaPopupItems
                ]
            }, Spacer[3]]},
            {Row[{
                tr["Default Model:"],
                (* Note: Dynamic[PopupMenu[..]] so that changing the
                        'show snapshot models' option updates the popup. *)
                Dynamic @ PopupMenu[
                    Dynamic[
                        currentChatSettings[
                            targetObj,
                            "Model"
                        ],
                        Function[{newValue},
                            CurrentValue[
                                targetObj,
                                {TaggingRules, "ChatNotebookSettings", "Model"}
                            ] = newValue
                        ]
                    ],
                    modelPopupItems,
                    (* This is shown if the user selects a snapshot model,
                    and then unchecks the 'show snapshot models' option. *)
                    Dynamic[
                        Style[
                            With[{
                                modelName = currentChatSettings[targetObj, "Model"]
                            }, {
                                settings = standardizeModelData[modelName]
                            },
                                Row[{
                                    getModelMenuIcon[settings, "Full"],
                                    modelDisplayName[modelName]
                                }, Spacer[1]]
                            ],
                            Italic
                        ]
                    ]
                ]
            }, Spacer[3]]},
            {Row[{
                tr["Default Tool Call Frequency:"],
                makeToolCallFrequencySlider[ targetObj ]
            }, Spacer[3]]},
            {Row[{
                tr["Default Temperature:"],
                makeTemperatureSlider[
                    Dynamic[
                        currentChatSettings[targetObj, "Temperature"],
                        newValue |-> (
                            CurrentValue[
                                targetObj,
                                {TaggingRules, "ChatNotebookSettings", "Temperature"}
                            ] = newValue;
                        )
                    ]
                ]
            }, Spacer[3]]},

            If[ TrueQ @ $useLLMServices,
                Nothing,
                {Row[{
                tr["Chat Completion URL:"],
                makeOpenAIAPICompletionURLForm[
                    Dynamic[
                        currentChatSettings[targetObj, "OpenAIAPICompletionURL"],
                        newValue |-> (
                            CurrentValue[
                                targetObj,
                                {TaggingRules, "ChatNotebookSettings", "OpenAIAPICompletionURL"}
                            ] = newValue;
                        )
                    ]
                ]
            }, Spacer[3]]}],
            {
                labeledCheckbox[
                    Dynamic[
                        showSnapshotModelsQ[],
                        newValue |-> (
                            CurrentValue[$FrontEnd, {
                                PrivateFrontEndOptions,
                                "InterfaceSettings",
                                "Chatbook",
                                "ShowSnapshotModels"
                            }] = newValue;

                            setModelPopupItems[];
                        )
                    ],
                    Row[{
                        "Show temporary snapshot LLM models",
                        Spacer[3],
                        Tooltip[
                            chatbookIcon["InformationTooltip", False],
"If enabled, temporary snapshot models will be included in the model selection menus.
\nSnapshot models are models that are frozen at a particular date, will not be
continuously updated, and have an expected discontinuation date."
                        ]
                    }]
                ]
            },
            {
                makeAutomaticResultAnalysisCheckbox[targetObj]
            }
        },
        Alignment -> {Left, Baseline},
        Spacings -> {0, 0.7}
    ]
];

makeFrontEndAndNotebookSettingsContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeOpenAIAPICompletionURLForm*)
(* cSpell: ignore AIAPI *)
makeOpenAIAPICompletionURLForm // beginDefinition;

makeOpenAIAPICompletionURLForm[ value_ ] := Pane @ InputField[
    value,
    String,
    ImageSize -> { 240, Automatic },
    BaseStyle -> { FontSize -> 12 }
];

makeOpenAIAPICompletionURLForm // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*UI Elements*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$loadingPopupMenu*)
$loadingPopupMenu = PopupMenu[ "x", { "x" -> ProgressIndicator[ Appearance -> "Percolate" ] }, Enabled -> False ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$verticalSpacer*)
$verticalSpacer = { Pane[ "", ImageSize -> { Automatic, 20 } ], SpanFromLeft };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$resetButton*)
$resetButton =
    Module[ { icon, label },
        icon = Style[
            Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "FEBitmaps", "SyntaxColorResetIcon" ][
                RGBColor[ 0.3921, 0.3921, 0.3921 ]
            ],
            GraphicsBoxOptions -> { BaselinePosition -> Scaled[ 0.1 ] }
        ];

        label = Grid[
            { { icon, Dynamic @ FEPrivate`FrontEndResource[ "PreferencesDialog", "ResetAllSettingsText" ] } },
            Alignment -> { Automatic, Baseline }
        ];

        Button[
            label,

            Needs[ "Wolfram`Chatbook`" -> None ];
            resetChatPreferences @ CurrentValue[
                $FrontEnd,
                { PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "PreferencesTab" }
            ]
            ,
            BaseStyle -> {
                FontFamily -> Dynamic @ FrontEnd`CurrentValue[ "ControlsFontFamily" ],
                FontSize   -> Dynamic @ FrontEnd`CurrentValue[ "ControlsFontSize" ],
                FontColor  -> Black
            },
            ImageSize -> Automatic,
            Method    -> "Queued"
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resetChatPreferences*)
resetChatPreferences // beginDefinition;

resetChatPreferences[ "Notebooks" ] :=
    FrontEndExecute @ FrontEnd`RemoveOptions[
        $FrontEnd,
        { System`LLMEvaluator, { TaggingRules, "ChatNotebookSettings" } }
    ];

resetChatPreferences[ "Personas" ] :=
    With[ { path = Sequence[ PrivateFrontEndOptions, "InterfaceSettings", "Chatbook" ] },
        (* TODO: choice dialog to uninstall personas *)
        resetChatPreferences[ "Notebooks" ];
        CurrentValue[ $FrontEnd, { path, "VisiblePersonas"  } ] = $corePersonaNames;
        CurrentValue[ $FrontEnd, { path, "PersonaFavorites" } ] = $corePersonaNames;
        updateDynamics[ "Preferences" ];
    ];

resetChatPreferences[ "Tools" ] := (
    (* TODO: choice dialog to uninstall tools *)
    resetChatPreferences[ "Notebooks" ];
    updateDynamics[ "Preferences" ];
);

resetChatPreferences[ "Services" ] := (
    (* TODO: choice dialog to clear service connections *)
    resetChatPreferences[ "Notebooks" ];
    updateDynamics[ "Preferences" ];
);

resetChatPreferences // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Navigation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*openPreferencesPage*)
openPreferencesPage // beginDefinition;

openPreferencesPage[ page: $$preferencesPage ] := (
    CurrentValue[ $FrontEnd, { "PreferencesSettings", "Page" } ] = "AI";
    CurrentValue[ $FrontEnd, { PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "PreferencesTab" } ] = page;
    FrontEndTokenExecute[ "PreferencesDialog" ]
);

openPreferencesPage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

End[ ];
EndPackage[ ];
