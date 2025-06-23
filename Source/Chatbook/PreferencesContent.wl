(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PreferencesContent`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`Errors`"           ];
Needs[ "Wolfram`Chatbook`PersonaManager`"   ];
Needs[ "Wolfram`Chatbook`Personas`"         ];
Needs[ "Wolfram`Chatbook`PreferencesUtils`" ];
Needs[ "Wolfram`Chatbook`ToolManager`"      ];
Needs[ "Wolfram`Chatbook`UI`"               ];

(* NOTE: the "controlText", "leadinText", "checkboxText", "subsectionText", styles are defined in the Preferences dialog's stylesheet *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$preferencesWidth        = 640;
$cloudPreferencesHeight  = 415;
$cloudEvaluationNotebook = None;

$preferencesPages = { "Services", "Notebooks", "Personas", "Tools" };
$$preferencesPage = Alternatives @@ $preferencesPages;

$preferencesScope := $FrontEnd;
$inFrontEndScope  := MatchQ[ OwnValues @ $preferencesScope, { _ :> $FrontEnd|_FrontEndObject } ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cloud Overrides*)
$displayedPreferencesPages := $preferencesPages;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Scope Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*expandScope*)
expandScope // beginDefinition;
expandScope // Attributes = { HoldFirst };

expandScope[ expr_ ] := ReleaseHold[
    HoldComplete @ expr /.
        OwnValues @ $preferencesScope /.
            HoldPattern @ $scopePlaceholder :> $preferencesScope
];

expandScope // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*scopeInitialization*)
scopeInitialization // beginDefinition;

scopeInitialization[ Initialization :> init_ ] :=
    expandScope[ Initialization :> Block[ { $scopePlaceholder := $preferencesScope }, init ] ];

scopeInitialization /: RuleDelayed[ Initialization, scopeInitialization[ init_ ] ] :=
    scopeInitialization[ Initialization :> init ];

scopeInitialization // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*scopedDynamic*)
scopedDynamic // beginDefinition;
scopedDynamic // Attributes = { HoldFirst };

scopedDynamic[ expr_, handlers0: Except[ _Rule|_RuleDelayed ], args___ ] :=
    With[ { handlers = handlers0 /. (f_ &) :> (Block[ { $scopePlaceholder = $preferencesScope }, f ] &) },
        expandScope @ Dynamic[ expr, handlers, args ]
    ];

scopedDynamic[ args___ ] :=
    expandScope @ Dynamic @ args;

scopedDynamic // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*scopedTrackedDynamic*)
scopedTrackedDynamic // beginDefinition;
scopedTrackedDynamic // Attributes = { HoldFirst };

scopedTrackedDynamic[ expr_, args___ ] :=
    expandScope @ trackedDynamic[ Block[ { $scopePlaceholder = $preferencesScope }, expr ], args ];

scopedTrackedDynamic // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*currentTabPageDynamic*)
currentTabPageDynamic // beginDefinition;
currentTabPageDynamic // Attributes = { HoldFirst };

currentTabPageDynamic[ scope_ ] := expandScope @ Dynamic[
    Replace[ CurrentChatSettings[ scope, "CurrentPreferencesTab" ], $$unspecified -> "Services" ],
    (CurrentChatSettings[ scope, "CurrentPreferencesTab" ] = #1) &
];

currentTabPageDynamic // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*currentTabPage*)
currentTabPage // beginDefinition;

currentTabPage[ scope_ ] := Replace[
    CurrentChatSettings[ scope, "CurrentPreferencesTab" ],
    $$unspecified -> "Services"
];

currentTabPage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Main*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createPreferencesContent*)
(* Displays all the content found in the "AI Settings" tab in the preferences dialog. *)
createPreferencesContent // beginDefinition;

createPreferencesContent[ ] := Enclose[
    Module[ { tabs, tabView, reset },
        (* Retrieve the dynamic content for each preferences tab, confirming that it matches the expected types: *)
        tabs = ConfirmMatch[
            createTabViewTabs[ ],
            { { _String, _Dynamic|_String -> _Dynamic|_DynamicModule }.. },
            "Tabs"
        ];

        (* Create a TabView for the preferences content, with the tab state stored in the FE's private options: *)
        tabView = TabView[
            tabs,
            currentTabPageDynamic @ $preferencesScope,
            Background   -> None,
            FrameMargins -> { { 2, 2 }, { 2, 3 } },
            ImageMargins -> { { 10, 10 }, { 2, 2 } },
            ImageSize    -> { $preferencesWidth, Automatic },
            LabelStyle   -> "feTabView" (* Defined in the SystemDialog stylesheet: *)
        ];

        (* Create a reset button that will reset preferences to default settings: *)
        reset = Pane[ $resetButton, ImageMargins -> { { 20, 0 }, { 0, 10 } }, ImageSize -> $preferencesWidth ];

        (* Arrange the TabView and reset button in a Grid layout with vertical spacers: *)
        makeScrollableInCloud @ Grid[
            {
                $verticalSpacer,
                { tabView, "" },
                $verticalSpacer,
                { reset, SpanFromLeft },
                $verticalSpacer
            },
            Alignment  -> Left,
            BaseStyle  -> "defaultGrid",  (* Defined in the SystemDialog stylesheet *)
            AutoDelete -> False,
            FrameStyle -> { AbsoluteThickness[ 1 ], color @ "PreferencesContentFrame" },
            Dividers   -> { False, { 4 -> True } },
            Spacings   -> { 0, 0.7 }
        ]
    ],
    throwInternalFailure
];

createPreferencesContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeScrollableInCloud*)
makeScrollableInCloud // beginDefinition;

makeScrollableInCloud[ expr_ ] /; $CloudEvaluation :=
    Pane[ Pane[ expr, ImageMargins -> { { 0, 10 }, { 0, 0 } } ],
          ImageSize  -> { Automatic, $cloudPreferencesHeight },
          Scrollbars -> { None, True }
    ];

makeScrollableInCloud[ expr_ ] :=
    Pane @ expr;

makeScrollableInCloud // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createTabViewTabs*)
createTabViewTabs // beginDefinition;
createTabViewTabs[ ] := createTabViewTabs @ $displayedPreferencesPages;
createTabViewTabs[ pages: { __String } ] := createTabViewTab /@ pages;
createTabViewTabs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createTabViewTab*)
createTabViewTab // beginDefinition;
createTabViewTab[ name_String ] := { name, tr[ "PreferencesContent" <> name <> "Tab" ] -> preferencesContent @ name };
createTabViewTab // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*preferencesContent*)
(* Define dynamic content for each of the preferences tabs. *)
preferencesContent // beginDefinition;

(* Content for the "Notebooks" tab: *)
preferencesContent[ "Notebooks" ] := scopedTrackedDynamic[ notebookSettingsPanel[ ], { "Models" } ];

(* Content for the "Personas" tab: *)
preferencesContent[ "Personas" ] := scopedTrackedDynamic[ personaSettingsPanel[ ], { "Personas" } ];

(* Content for the "Services" tab: *)
preferencesContent[ "Services" ] := scopedTrackedDynamic[ servicesSettingsPanel[ ], { "Models", "Services" } ];

(* Content for the "Tools" tab: *)
preferencesContent[ "Tools" ] := scopedTrackedDynamic[ toolSettingsPanel[ ], { "Personas" } ];

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
        (* Display a progress indicator until content is loaded via initialization: *)
        { display = ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ] },
        Dynamic[ display ],
        (* createNotebookSettingsPanel is called to initialize the content of the panel: *)
        Initialization :> scopeInitialization[ display = createNotebookSettingsPanel[ ] ],
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
    Module[
        {
            defaultSettingsContent,
            interfaceLabel, interfaceContent,
            featuresLabel, featuresContent,
            content
        },

        (* Retrieve and confirm the content for default settings: *)
        defaultSettingsContent = ConfirmMatch[
            scopedTrackedDynamic[ makeDefaultSettingsContent[ ], "Preferences" ],
            _Dynamic,
            "DefaultSettings"
        ];

        (* Label for the interface section using a style from SystemDialog.nb: *)
        interfaceLabel = subsectionText @ tr[ "PreferencesContentSubsectionChat" ];

        (* Retrieve and confirm the content for the chat notebook interface,
           ensuring it is not an error from makeInterfaceContent: *)
        interfaceContent = ConfirmMatch[
            makeInterfaceContent[ ],
            Except[ _makeInterfaceContent ],
            "Interface"
        ];

        (* Label for the features section using a style from SystemDialog.nb: *)
        featuresLabel = subsectionText @ tr[ "PreferencesContentSubsectionFeatures" ];

        (* Retrieve and confirm the content for the chat notebook features,
           ensuring it is not an error from makeFeaturesContent: *)
        featuresContent = ConfirmMatch[
            makeFeaturesContent[ ],
            Except[ _makeFeaturesContent ],
            "Features"
        ];

        (* Assemble the default settings and interface content into a grid layout: *)
        content = Grid[
            {
                { defaultSettingsContent },
                { Spacer[ 1 ]            },
                { Spacer[ 1 ]            },
                { interfaceLabel         },
                { interfaceContent       },
                { Spacer[ 1 ]            },
                { Spacer[ 1 ]            },
                { featuresLabel          },
                { featuresContent        }
            },
            Alignment -> { Left, Baseline },
            Dividers  -> { False, { 3 -> True, 7 -> True } },
            ItemSize  -> { Fit, Automatic },
            Spacings  -> { 0, 0.7 }
        ];

        (* Cache the content in case panel is redrawn: *)
        createNotebookSettingsPanel[ ] = content
    ],
    throwInternalFailure
];

createNotebookSettingsPanel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeDefaultSettingsContent*)
makeDefaultSettingsContent // beginDefinition;

makeDefaultSettingsContent[ ] := Enclose[
    Module[ { assistanceCheckbox, personaSelector, modelSelector, temperatureInput, openAICompletionURLInput },
        (* Checkbox to enable automatic assistance for normal shift-enter evaluations: *)
        assistanceCheckbox = ConfirmMatch[ makeAssistanceCheckbox[ ], _Style|Nothing, "AssistanceCheckbox" ];
        (* The personaSelector is a pop-up menu for selecting the default persona: *)
        personaSelector = ConfirmMatch[ makePersonaSelector[ ], _Dynamic, "PersonaSelector" ];
        (* The modelSelector is a dynamic module containing menus to select the service and model separately: *)
        modelSelector = ConfirmMatch[ makeModelSelector[ "Notebooks" ], _Dynamic, "ModelSelector" ];
        (* The temperatureInput is an input field for setting the default 'temperature' for responses: *)
        temperatureInput = ConfirmMatch[ makeTemperatureInput[ ], _Style, "TemperatureInput" ];
        (* The openAICompletionURLInput is an input field for setting URL used for API calls to OpenAI: *)
        openAICompletionURLInput = ConfirmMatch[
            makeOpenAICompletionURLInput[ ],
            _Style|Nothing, (* Returns Nothing if we're relying on LLMServices for API requests *)
            "OpenAICompletionURLInput"
        ];

        (* Assemble the persona selector, model selector, and temperature slider into a grid layout: *)
        Grid[
            List /@ {
                assistanceCheckbox,
                personaSelector,
                modelSelector,
                temperatureInput,
                openAICompletionURLInput
            },
            Alignment -> { Left, Baseline },
            Spacings  -> { 0, 0.7 }
        ]
    ],
    throwInternalFailure
];

makeDefaultSettingsContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makePersonaSelector*)
makePersonaSelector // beginDefinition;
makePersonaSelector[ ] := scopedTrackedDynamic[ makePersonaSelector0[ ], { "Personas" } ];
makePersonaSelector // endDefinition;

makePersonaSelector0 // beginDefinition;

(* Top-level function without arguments, calls the version with personas from GetPersonasAssociation *)
makePersonaSelector0[ ] :=
    makePersonaSelector0 @ GetPersonasAssociation[ "IncludeHidden" -> False ];

(* Overload of makePersonaSelector0 that takes an Association of personas,
   converts it to a list of labels for PopupMenu *)
makePersonaSelector0[ personas_Association? AssociationQ ] :=
    makePersonaSelector0 @ KeyValueMap[ personaPopupLabel, personas ];

(* Overload of makePersonaSelector0 that takes a list of rules where each rule is a string to an association,
   creates a PopupMenu with this list *)
makePersonaSelector0[ personas: { (_String -> _).. } ] :=
    highlightControl[
        Row @ {
            tr[ "PreferencesContentPersonaLabel" ],
            Spacer[ 3 ],
            PopupMenu[ scopedDynamic @ CurrentChatSettings[ $preferencesScope, "LLMEvaluator" ], personas ]
        },
        "Notebooks",
        "LLMEvaluator"
    ];

makePersonaSelector0 // endDefinition;

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
makeModelSelector[ type_String ] := scopedTrackedDynamic[ makeModelSelector0[ type ], { "Models", "Services" } ];
makeModelSelector // endDefinition;


makeModelSelector0 // beginDefinition;

makeModelSelector0[ type_String ] :=
    makeModelSelector0[
        type,
        If[ KeyExistsQ[ $availableServices, "LLMKit" ],
            $availableServices,
            <| "LLMKit" -> <| "Service" -> "Wolfram", "Icon" -> chatbookExpression["llmkit-dialog-sm"] |>, $availableServices |> ] ]

makeModelSelector0[ type_String, services_Association? AssociationQ ] := Enclose[
    DynamicModule[ { default, service, model, state, serviceSelector, modelSelector, highlight },

        default = CurrentChatSettings[ $preferencesScope, "Model" ];
        service = ConfirmBy[ extractServiceName @ default, StringQ, "ServiceName" ];
        model   = ConfirmMatch[ extractModelName @ default, _String | Automatic, "ModelName" ];
        state   = If[ modelListCachedQ @ service, "Loaded", "Loading" ];

        modelSelector = If[ state === "Loaded",
                            makeModelNameSelector[
                                Dynamic @ service,
                                Dynamic @ model,
                                Dynamic @ modelSelector,
                                Dynamic @ state
                            ],
                            ""
                        ];

        serviceSelector = makeServiceSelector[
            Dynamic @ service,
            Dynamic @ model,
            Dynamic @ modelSelector,
            Dynamic @ state,
            services
        ];

        highlight = highlightControl[ Row @ { #1, Spacer[ 1 ], #2 }, "Notebooks", #3 ] &;

        highlightControl[
            Row @
                If[ MatchQ[ type, "Cloud" | "Notebooks" ],
                    {
                        highlight[ tr[ "PreferencesContentLLMServiceLabel" ], serviceSelector, "ModelService" ],
                        Spacer[ 5 ],
                        highlight[
                            Dynamic[ If[ service === "LLMKit", "", tr[ "PreferencesContentModelLabel" ] ] ],
                            Dynamic[ If[ service === "LLMKit", "",
                                If[ state === "Loading" || MatchQ[ modelSelector, _Symbol ], $loadingPopupMenu, modelSelector ] ],
                                TrackedSymbols :> { state, modelSelector }
                            ],
                            "ModelName"
                        ]
                    },
                    {
                        serviceSelector,
                        Spacer[ 24 ],
                        Dynamic[ If[ service === "LLMKit", "", tr[ "PreferencesContentModelLabelAlt" ] ] ],
                        Spacer[ 7 ],
                        Dynamic[
                            If[ state === "Loading" || MatchQ[ modelSelector, _Symbol ], $loadingPopupMenu, modelSelector ],
                            TrackedSymbols :> { state, modelSelector }
                        ]
                    }
                ],
            "Notebooks",
            "Model"
        ],

        Initialization :> scopeInitialization[
            modelSelector = catchAlways @ makeModelNameSelector[
                Dynamic @ service,
                Dynamic @ model,
                Dynamic @ modelSelector,
                Dynamic @ state
            ];
            state = "Loaded";
        ],
        SynchronousInitialization -> False,
        SynchronousUpdating       -> False,
        UnsavedVariables          :> { state }
    ],
    throwInternalFailure
];

makeModelSelector0[ failure: HoldPattern @ Failure[ LLMServices`LLMServiceInformation, ___ ] ] :=
    Pane[ failure, ImageSize -> { $preferencesWidth-50, Automatic } ];

makeModelSelector0 // endDefinition;

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
        scopedDynamic[
            extractServiceName @ CurrentChatSettings[ $preferencesScope, "Model" ],
            serviceSelectCallback[ Dynamic @ service, Dynamic @ model, Dynamic @ modelSelector, Dynamic @ state ]
        ],
        (* ensure LLMKit is first in the popup followed by a delimiter *)
        Replace[
            KeyValueMap[
                popupValue[ #1, #2[ "Service" ], #2[ "Icon" ] ] &,
                DeleteCases[ services, KeyValuePattern[ "Hidden" -> True ] ]
            ],
            { a___, b:("LLMKit" -> _), c___ } :> { b, Delimiter, a, c } ]
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
    CurrentChatSettings[ $preferencesScope, "Model" ] = <| "Service" -> service, "Name" -> model |>;

    (* Finish loading the model name selector: *)
    If[ state === "Loading",
        expandScope[
            Block[ { $scopePlaceholder := $preferencesScope },
                modelSelector = makeModelNameSelector[
                    Dynamic @ service,
                    Dynamic @ model,
                    Dynamic @ modelSelector,
                    Dynamic @ state
                ]
            ];
            state = "Loaded"
        ],
        modelSelector = makeModelNameSelector[
            Dynamic @ service,
            Dynamic @ model,
            Dynamic @ modelSelector,
            Dynamic @ state
        ]
    ]
];

serviceSelectCallback // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeModelNameSelector*)
makeModelNameSelector // beginDefinition;

makeModelNameSelector[
    Dynamic[ service_ ],
    Dynamic[ model_ ],
    Dynamic[ modelSelector_ ],
    Dynamic[ state_ ]
] := Enclose[
    Catch @ Module[ { models, current, default, fallback },

        ensureServiceName @ service;
        ConfirmAssert[ StringQ @ service, "ServiceName" ];

        If[ service === "LLMKit", Throw @ "" ];

        models = ConfirmMatch[
            Block[ { $allowConnectionDialog = False }, getServiceModelList @ service ],
            { __Association } | Missing[ "NotConnected" ] | Missing[ "NoModelList" ],
            "ServiceModelList"
        ];

        (* TODO:
               If the underlying ServiceExecute in getServiceModelList fails (e.g. due to API issues), it currently
               returns Missing["NoModelList"]. It might be better to have it return an appropriate Failure[...] instead.
               In this case, we would want to indicate to the user that the service is not available, rather than
               falling back to the input field method.
        *)

        If[ models === Missing[ "NotConnected" ],
            Throw @ serviceConnectButton[
                Dynamic @ service,
                Dynamic @ model,
                Dynamic @ modelSelector,
                Dynamic @ state
            ]
        ];

        If[ models === Missing[ "NoModelList" ],
            Throw @ modelNameInputField[
                Dynamic @ service,
                Dynamic @ model,
                Dynamic @ modelSelector,
                Dynamic @ state
            ]
        ];

        current  = extractModelName @ CurrentChatSettings[ $preferencesScope, "Model" ];
        default  = ConfirmBy[ getServiceDefaultModel @ service, StringQ, "DefaultName" ];
        fallback = <| "Service" -> service, "Name" -> default |>;

        If[ ! MemberQ[ models, KeyValuePattern[ "Name" -> current ] ],
            CurrentChatSettings[ $preferencesScope, "Model" ] = fallback
        ];

        With[ { m = fallback },
            PopupMenu[
                scopedDynamic[
                    Replace[
                        extractModelName @ CurrentChatSettings[ $preferencesScope, "Model" ],
                        Except[ _String ] :> (CurrentChatSettings[ $preferencesScope, "Model" ] = m)
                    ],
                    modelSelectCallback[ Dynamic @ service, Dynamic @ model ]
                ],
                Block[ { $noIcons = TrueQ @ $cloudNotebooks },
                    Map[ popupValue[ #[ "Name" ], #[ "DisplayName" ], #[ "Icon" ] ] &, models ]
                ],
                ImageSize -> Automatic
            ]
        ]
    ],
    throwInternalFailure
];

makeModelNameSelector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*modelNameInputField*)
modelNameInputField // beginDefinition;

modelNameInputField[ Dynamic[ service_ ], Dynamic[ model_ ], Dynamic[ modelSelector_ ], Dynamic[ state_ ] ] :=
    prefsInputField[
        None,
        scopedDynamic[
            Replace[
                extractModelName @ CurrentChatSettings[ $preferencesScope, "Model" ],
                Except[ _String ] :> ""
            ],
            { None, modelSelectCallback[ Dynamic @ service, Dynamic @ model ] }
        ],
        String,
        ImageSize -> { 200, Automatic }
    ];

modelNameInputField // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*serviceConnectButton*)
serviceConnectButton // beginDefinition;

serviceConnectButton[
    Dynamic[ service_ ],
    Dynamic[ model_ ],
    Dynamic[ modelSelector_ ],
    Dynamic[ state_ ]
] :=
    Button[
        tr[ "PreferencesContentServiceConnectButton" ],
        Needs[ "Wolfram`LLMFunctions`" -> None ];
        Replace[
            Quiet[
                Wolfram`LLMFunctions`APIs`Common`ConnectToService @ service
            ],
            _ServiceObject :>
                If[ ListQ @ getServiceModelList @ service,
                    serviceSelectCallback[
                        service,
                        Dynamic @ service,
                        Dynamic @ model,
                        Dynamic @ modelSelector,
                        Dynamic @ state
                    ]
                ]
        ],
        Method -> "Queued"
    ];

serviceConnectButton // endDefinition;

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

    (* Store the service/model in FE settings: *)
    CurrentChatSettings[ $preferencesScope, "Model" ] = <| "Service" -> service, "Name" -> model |>;

    (* Remember the selected model for the given service, so it will be automatically chosen
       when choosing this service again: *)
    CurrentChatSettings[ $preferencesScope, "ServiceDefaultModel" ] = Append[
        CurrentChatSettings[ $preferencesScope, "ServiceDefaultModel" ],
        service -> model
    ]
    ,
    throwInternalFailure
];

modelSelectCallback // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeAssistanceCheckbox*)
makeAssistanceCheckbox // beginDefinition;

makeAssistanceCheckbox[ ] :=
    If[ TrueQ @ $cloudNotebooks,
        Nothing,
        highlightControl[
            prefsCheckbox[
                scopedDynamic[
                    TrueQ @ CurrentChatSettings[ $preferencesScope, "Assistance" ],
                    (CurrentChatSettings[ $preferencesScope, "Assistance" ] = #1) &
                ],
                infoTooltip[
                    tr[ "PreferencesContentEnableAssistanceLabel" ],
                    tr[ "PreferencesContentEnableAssistanceTooltip" ]
                ]
            ],
            "Notebooks",
            "Assistance"
        ]
    ];

makeAssistanceCheckbox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeTemperatureInput*)
makeTemperatureInput // beginDefinition;

makeTemperatureInput[ ] := highlightControl[
    prefsInputField[
        tr[ "PreferencesContentTemperatureLabel" ],
        scopedDynamic[
            CurrentChatSettings[ $preferencesScope, "Temperature" ],
            {
                None,
                If[ NumberQ @ #, CurrentChatSettings[ $preferencesScope, "Temperature" ] = # ] &
            }
        ],
        Number,
        ImageSize -> { 50, Automatic }
    ],
    "Notebooks",
    "Temperature"
];

makeTemperatureInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeOpenAICompletionURLInput*)
makeOpenAICompletionURLInput // beginDefinition;

makeOpenAICompletionURLInput[ ] :=
    makeOpenAICompletionURLInput @ $useLLMServices;

makeOpenAICompletionURLInput[ True ] :=
    Nothing;

makeOpenAICompletionURLInput[ False ] := highlightControl[
    prefsInputField[
        tr[ "PreferencesContentOpenAICompletionURLLabel" ],
        scopedDynamic[
            CurrentChatSettings[ $preferencesScope, "OpenAIAPICompletionURL" ],
            {
                None,
                If[ StringQ @ #, CurrentChatSettings[ $preferencesScope, "OpenAIAPICompletionURL" ] = # ] &
            }
        ],
        String,
        ImageSize -> { 200, Automatic }
    ],
    "Notebooks",
    "OpenAIAPICompletionURL"
];

makeOpenAICompletionURLInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeInterfaceContent*)
makeInterfaceContent // beginDefinition;

makeInterfaceContent[ ] := Enclose[
    Module[ { formatCheckbox, includeHistory, chatHistoryLength, mergeMessages },

        formatCheckbox    = ConfirmMatch[ makeFormatCheckbox[ ]        , _Style, "FormatCheckbox"    ];
        includeHistory    = ConfirmMatch[ makeIncludeHistoryCheckbox[ ], _Style, "ChatHistory"       ];
        chatHistoryLength = ConfirmMatch[ makeChatHistoryLengthInput[ ], _Style, "ChatHistoryLength" ];
        mergeMessages     = ConfirmMatch[ makeMergeMessagesCheckbox[ ] , _Style, "MergeMessages"     ];

        Grid[
            {
                { formatCheckbox    },
                { includeHistory    },
                { chatHistoryLength },
                { mergeMessages     }
            },
            Alignment -> { Left, Baseline },
            Spacings  -> { 0, 0.7 }
        ]
    ],
    throwInternalFailure
];

makeInterfaceContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeFormatCheckbox*)
makeFormatCheckbox // beginDefinition;

makeFormatCheckbox[ ] := highlightControl[
    prefsCheckbox[
        scopedDynamic[
            TrueQ @ CurrentChatSettings[ $preferencesScope, "AutoFormat" ],
            (CurrentChatSettings[ $preferencesScope, "AutoFormat" ] = #1) &
        ],
        tr[ "PreferencesContentFormatOutputLabel" ]
    ],
    "Notebooks",
    "AutoFormat"
];

makeFormatCheckbox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeIncludeHistoryCheckbox*)
makeIncludeHistoryCheckbox // beginDefinition;

makeIncludeHistoryCheckbox[ ] := highlightControl[
    prefsCheckbox[
        scopedDynamic[
            MatchQ[ CurrentChatSettings[ $preferencesScope, "IncludeHistory" ], True|Automatic ],
            (CurrentChatSettings[ $preferencesScope, "IncludeHistory" ] = #1) &
        ],
        infoTooltip[ tr[ "PreferencesContentIncludeHistoryLabel" ], tr[ "PreferencesContentIncludeHistoryTooltip" ] ]
    ],
    "Notebooks",
    "IncludeHistory"
];

makeIncludeHistoryCheckbox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeChatHistoryLengthInput*)
makeChatHistoryLengthInput // beginDefinition;

makeChatHistoryLengthInput[ ] := highlightControl[
    infoTooltip[
        prefsInputField[
            tr[ "PreferencesContentHistoryLengthLabel" ],
            scopedDynamic[
                CurrentChatSettings[ $preferencesScope, "ChatHistoryLength" ],
                {
                    None,
                    If[ NumberQ @ # && NonNegative @ #,
                        CurrentChatSettings[ $preferencesScope, "ChatHistoryLength" ] = Floor[ # ]
                    ] &
                }
            ],
            Number,
            ImageSize -> { 50, Automatic }
        ],
        tr[ "PreferencesContentHistoryLengthTooltip" ]
    ],
    "Notebooks",
    "ChatHistoryLength"
];

makeChatHistoryLengthInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeMergeMessagesCheckbox*)
makeMergeMessagesCheckbox // beginDefinition;

makeMergeMessagesCheckbox[ ] := highlightControl[
    prefsCheckbox[
        scopedDynamic[
            MatchQ[ CurrentChatSettings[ $preferencesScope, "MergeMessages" ], True|Automatic ],
            (CurrentChatSettings[ $preferencesScope, "MergeMessages" ] = #1) &
        ],
        infoTooltip[ tr[ "PreferencesContentMergeChatLabel" ], tr[ "PreferencesContentMergeChatTooltip" ] ]
    ],
    "Notebooks",
    "MergeMessages"
];

makeMergeMessagesCheckbox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeFeaturesContent*)
makeFeaturesContent // beginDefinition;

makeFeaturesContent[ ] := Enclose[
    Module[ { multimodal, toolsEnabled, toolFrequency },

        multimodal    = ConfirmMatch[ makeMultimodalMenu[ ]           , _Style, "Multimodal"    ];
        toolsEnabled  = ConfirmMatch[ makeToolsEnabledMenu[ ]         , _Style, "ToolsEnabled"  ];
        toolFrequency = ConfirmMatch[ makeToolCallFrequencySelector[ ], _Style, "ToolFrequency" ];

        Grid[
            {
                { multimodal    },
                { toolsEnabled  },
                { toolFrequency }
            },
            Alignment -> { Left, Baseline },
            Spacings  -> { 0, 0.7 }
        ]
    ],
    throwInternalFailure
];

makeFeaturesContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeMultimodalMenu*)
makeMultimodalMenu // beginDefinition;

makeMultimodalMenu[ ] := highlightControl[
    Grid[
        {
            {
                Style[ tr[ "PreferencesContentEnableMultimodalLabel" ], "leadinText", FontColor -> color @ "PreferencesContentFont_2" ],
                PopupMenu[
                    scopedDynamic @ CurrentChatSettings[ $preferencesScope, "Multimodal" ],
                    {
                        Automatic -> tr[ "EnabledByModel" ],
                        True      -> tr[ "EnabledAlways"  ],
                        False     -> tr[ "EnabledNever"   ]
                    },
                    MenuStyle -> { "controlText", FontColor -> color @ "PreferencesContentFont_2" }
                ]
            }
        },
        Alignment -> { Left, Baseline },
        Spacings  -> 0.5
    ],
    "Notebooks",
    "Multimodal"
];

makeMultimodalMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolsEnabledMenu*)
makeToolsEnabledMenu // beginDefinition;

makeToolsEnabledMenu[ ] := highlightControl[
    Grid[
        {
            {
                Style[ tr[ "PreferencesContentEnableTools" ], "leadinText", FontColor -> color @ "PreferencesContentFont_2" ],
                PopupMenu[
                    scopedDynamic @ CurrentChatSettings[ $preferencesScope, "ToolsEnabled" ],
                    {
                        Automatic -> tr[ "EnabledByModel" ],
                        True      -> tr[ "EnabledAlways"  ],
                        False     -> tr[ "EnabledNever"   ]
                    },
                    MenuStyle -> { "controlText", FontColor -> color @ "PreferencesContentFont_2" }
                ]
            }
        },
        Alignment        -> { Left, Baseline },
        BaselinePosition -> 1,
        Spacings         -> 0.5
    ],
    "Notebooks",
    "ToolsEnabled"
];

makeToolsEnabledMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolCallFrequencySelector*)
makeToolCallFrequencySelector // beginDefinition;

makeToolCallFrequencySelector[ ] := highlightControl[
    DynamicModule[ { type, frequency },
        Grid[
            {
                {
                    Style[ tr[ "PreferencesContentToolCallFrequency" ], "leadinText", FontColor -> color @ "PreferencesContentFont_2" ],
                    PopupMenu[
                        scopedDynamic[
                            type,
                            Function[
                                If[ # === Automatic
                                    ,
                                    type = Automatic;
                                    CurrentChatSettings[ $preferencesScope, "ToolCallFrequency" ] = Automatic
                                    ,
                                    type = "Custom";
                                    CurrentChatSettings[ $preferencesScope, "ToolCallFrequency" ] = 0.5
                                ]
                            ]
                        ],
                        {
                            Automatic -> tr[ "Automatic" ],
                            "Custom"  -> tr[ "Custom"    ]
                        },
                        MenuStyle -> { "controlText", FontColor -> color @ "PreferencesContentFont_2" }
                    ],
                    PaneSelector[
                        {
                            Automatic -> "",
                            "Custom" -> Grid[
                                {
                                    {
                                        Spacer[ 5 ],
                                        Style[ tr[ "Rare" ], "defaultSubtext" ],
                                        Slider[
                                            scopedDynamic[
                                                frequency,
                                                {
                                                    Function[ frequency = # ],
                                                    Function[
                                                        CurrentChatSettings[ $preferencesScope, "ToolCallFrequency" ] = #;
                                                        frequency = #
                                                    ]
                                                }
                                            ],
                                            ImageSize -> { 100, Automatic }
                                        ],
                                        Style[ tr[ "Often" ], "defaultSubtext" ]
                                    }
                                },
                                Spacings -> { 0.4, 0.7 }
                            ]
                        },
                        Dynamic[ type ],
                        ImageSize -> Automatic
                    ]
                }
            },
            Alignment        -> { Left, Baseline },
            BaselinePosition -> 1,
            Spacings         -> 0.5
        ],
        Initialization :> scopeInitialization @
            With[ { val = CurrentChatSettings[ $preferencesScope, "ToolCallFrequency" ] },
                type      = If[ NumberQ @ val, "Custom", Automatic ];
                frequency = If[ NumberQ @ val, val, 0.5 ];
            ]
    ],
    "Notebooks",
    "ToolCallFrequency"
];

makeToolCallFrequencySelector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Services*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*servicesSettingsPanel*)
servicesSettingsPanel // beginDefinition;
servicesSettingsPanel[ ] := Catch[ servicesSettingsPanel0[ ], $servicesSettingsTag ];
servicesSettingsPanel // endDefinition;

servicesSettingsPanel0 // beginDefinition;

servicesSettingsPanel0[ ] := Enclose[
    Module[ { llmIcon, llmHelp, llmLabel, llmPanel, serviceCollapsibleSection, serviceGrid, settingsLabel, settings },

        llmLabel      = subsectionText @ tr[ "PreferencesContentLLMKitTitle" ];
        llmPanel      = makeLLMPanel[ ];
        serviceGrid   = ConfirmMatch[ makeServiceGrid[ ], _Framed, "ServiceGrid" ];
        settingsLabel = subsectionText @ tr[ "PreferencesContentDefaultService" ];
        settings      = ConfirmMatch[ makeModelSelector[ "Services" ], _Dynamic, "ServicesSettings" ];

        serviceCollapsibleSection =
            DynamicModule[ { Typeset`openQ = False },
                PaneSelector[
                    {
                        True ->
                            Grid[
                                {
                                    {
                                        EventHandler[
                                            PaneSelector[
                                                {
                                                    False -> subsectionText @ Grid[ { { tr[ "PreferencesContentService" ], "\:f443" } }, Alignment -> { Left, Baseline }, BaselinePosition -> { 1, 1 } ],
                                                    True -> subsectionText @ Grid[ { { tr[ "PreferencesContentService" ], "\:f449" } }, Alignment -> { Left, Baseline }, BaselinePosition -> { 1, 1 } ]
                                                },
                                                Dynamic[ CurrentValue[ "MouseOver" ] ],
                                                BaselinePosition -> Baseline,
                                                ImageSize -> Automatic ],
                                            "MouseClicked" :> ( Typeset`openQ = !Typeset`openQ ) ] },
                                    { serviceGrid }
                                },
                                Alignment -> { Left, Baseline },
                                BaselinePosition -> { 1, 1 } ],
                        False ->
                            EventHandler[
                                PaneSelector[
                                    {
                                        False -> subsectionText @ Grid[ { { tr[ "PreferencesContentService" ], "\:f442" } }, Alignment -> { Left, Baseline }, BaselinePosition -> { 1, 1 } ],
                                        True -> subsectionText @ Grid[ { { tr[ "PreferencesContentService" ], "\:f43b" } }, Alignment -> { Left, Baseline }, BaselinePosition -> { 1, 1 } ]
                                    },
                                    Dynamic[ CurrentValue[ "MouseOver" ] ],
                                    BaselinePosition -> Baseline,
                                    ImageSize -> Automatic ],
                                "MouseClicked" :> ( Typeset`openQ = !Typeset`openQ ) ] },
                    Dynamic[ Typeset`openQ ],
                    BaselinePosition -> Baseline,
                    ImageSize -> Automatic ],
                Initialization :> None, (* needed for Deinitialization to run *)
                Deinitialization :>
                    If[ TrueQ[ Wolfram`LLMFunctions`Common`Private`$LastLLMKitRequest[ "ConnectionQ" ] ],
                        SessionSubmit @ Wolfram`LLMFunctions`Common`Private`teardownLLMListener[ ]
                    ]
            ];

        llmIcon = chatbookExpression[ "llmkit-dialog-sm" ];
        llmHelp = (* If this tooltip isn't meant to be a button, then use infoTooltip[llmLabel, text] *)
            Button[
                Tooltip[
                    NotebookTools`Mousedown[
                        Dynamic[ RawBoxes[ FEPrivate`FrontEndResource[ "FEBitmaps", "ProductSelectorInfo" ][ #1, 14 ] ] ],
                        Dynamic[ RawBoxes[ FEPrivate`FrontEndResource[ "FEBitmaps", "ProductSelectorInfo" ][ #2, 14 ] ] ],
                        Dynamic[ RawBoxes[ FEPrivate`FrontEndResource[ "FEBitmaps", "ProductSelectorInfo" ][ #3, 14 ] ] ]
                    ]&[
                        color @ "PreferencesContentServicesNAInfoIcon",
                        color @ "PreferencesContentServicesNAInfoIconHover",
                        color @ "PreferencesContentServicesNAInfoIconPressed"
                    ],
                    Pane[ tr[ "PreferencesContentLLMKitLearnMoreTooltip" ], ImageSize -> UpTo[ 274 ] ],
                    TooltipStyle -> {
                        Background       -> color @ "PreferencesContentServicesNAInfoTooltipBackground",
                        CellFrameColor   -> color @ "PreferencesContentServicesNAInfoTooltipFrame",
                        CellFrameMargins -> 5,
                        FontColor        -> color @ "PreferencesContentFont_1",
                        FontFamily       -> "Roboto",
                        FontSize         -> 11 } ],
                Wolfram`LLMFunctions`Common`OpenLLMKitURL @ "Learn",
                Appearance       -> "Suppressed",
                BaselinePosition -> Baseline,
                Method           -> "Queued",
                ImageSize        -> Automatic ];

        Pane[
            Grid[
                {
                    { Grid[ { { llmIcon, llmLabel, llmHelp } }, Alignment -> { Left, Center } ] },
                    { llmPanel },
                    { serviceCollapsibleSection },
                    { settingsLabel },
                    { settings      }
                },
                Alignment -> { Left, Baseline },
                ItemSize  -> { Fit, Automatic },
                Spacings  -> { Automatic, { 0, 0.2, 1.43, 1.43, 0.5, 0 } }
            ],
            ImageMargins -> 8
        ]
    ],
    throwInternalFailure
];

servicesSettingsPanel0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeLLMPanel*)
makeLLMPanel // beginDefinition;

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::NoVariables::DynamicModule:: *)
makeLLMPanel[ ] :=
    Module[ { subscribeButton, username, signInButton, manageButton },
        subscribeButton =
            Button[
                redDialogButtonLabel[ tr[ "PreferencesContentLLMKitSubscribeButton" ], FrameMargins -> { { 17, 17 }, { 7, 7 } } ],
                Wolfram`LLMFunctions`Common`OpenLLMKitURL @ "Buy",
                Appearance       -> "Suppressed",
                BaseStyle        -> "DialogTextCommon",
                BaselinePosition -> Baseline,
                Method           -> "Queued",
                ImageSize        -> Automatic ];

        username =
            PaneSelector[
                {
                    False -> "",
                    True ->
                        Grid[
                            { {
                                RawBoxes[ DynamicBox[ FEPrivate`FrontEndResource[ "FEBitmaps", "GenericUserIcon" ][ # ] ] ]&[
                                    color @ "PreferencesContentFont_1"
                                ],
                                If[ $CloudEvaluation, Dynamic[ $CloudAccountName ], Dynamic[ FrontEnd`CurrentValue["WolframCloudFullUserName"] ] ] } },
                            Alignment -> { Left, Baseline },
                            BaseStyle -> { FontColor -> color @ "PreferencesContentFont_1", FontSize -> 14 },
                            BaselinePosition -> { 1, 2 } ] },
                Dynamic[ Wolfram`LLMFunctions`Common`CloudAuthenticatedQ[ ] ],
                BaselinePosition -> Baseline,
                ImageSize        -> Automatic ];

        signInButton =
            Button[
                Style[
                    tr[ "PreferencesContentLLMKitSignInButton" ],
                    FontColor ->
                        Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[
                            color @ "PreferencesContentLLMSignInButtonFontHover",
                            color @ "PreferencesContentLLMSignInButtonFont"
                        ]
                ],
                CloudConnect[ ];
                If[ Wolfram`LLMFunctions`Common`CloudAuthenticatedQ[ ], Wolfram`LLMFunctions`Common`UpdateLLMKitInfo[ ] ],
                Appearance       -> "Suppressed",
                BaseStyle        -> "DialogTextCommon",
                BaselinePosition -> Baseline,
                ImageSize        -> Automatic,
                Method           -> "Queued" ];

        manageButton =
            Button[
                Style[
                    tr[ "PreferencesContentLLMKitEnabledManage" ],
                    FontColor -> (Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[
                        color @ "PreferencesContentFont_1",
                        color @ "PreferencesContentFont_3" ])
                ],
                Wolfram`LLMFunctions`Common`OpenLLMKitURL @ "Manage",
                Appearance -> "Suppressed",
                BaseStyle  -> "DialogTextCommon",
                Method     -> "Queued",
                ImageSize  -> Automatic ];

        Framed[
            Grid[
                {
                    {
                        PaneSelector[
                            {
                                (* We need to quickly check whether we have a subscription without the need for setting up a channel listener. *)
                                "Loading" ->
                                    DynamicModule[ { },
                                        (* Display a progress indicator until $LLMKitInfo is set via initialization *)
                                        ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ],
                                        Initialization :> ( Wolfram`LLMFunctions`Common`UpdateLLMKitInfo[ ] ),
                                        SynchronousInitialization -> False
                                    ],
                                "NotCloudConnected" ->
                                    Grid[
                                        {
                                            { tr[ "PreferencesContentLLMKitSubscriptionRequired" ], SpanFromLeft, SpanFromLeft },
                                            { subscribeButton, tr[ "PreferencesContentLLMKitSignInOr" ], signInButton }
                                        },
                                        Alignment        -> { Left, Baseline },
                                        BaseStyle        -> { "DialogText", FontColor -> color @ "PreferencesContentFont_3" },
                                        BaselinePosition -> { 1, 1 }
                                    ],
                                "CloudConnectedButNotSubscribed" ->
                                    Grid[
                                        {
                                            { tr[ "PreferencesContentLLMKitNoSubscription" ] },
                                            { subscribeButton }
                                        },
                                        Alignment        -> { Left, Baseline },
                                        BaseStyle        -> { "DialogText", FontColor -> color @ "PreferencesContentFont_3" },
                                        BaselinePosition -> { 1, 1 }
                                    ],
                                "CloudConnectedAndSubscribed" ->
                                    Grid[
                                        {
                                            { chatbookExpression[ "CheckmarkGreen" ], Style[ tr[ "PreferencesContentLLMKitEnabledTitle" ], FontColor -> color @ "PreferencesContentFont_1" ] },
                                            { "", manageButton }
                                        },
                                        Alignment        -> { Left, Baseline },
                                        BaseStyle        -> { "DialogTextCommon", FontColor -> color @ "PreferencesContentFont_3" },
                                        BaselinePosition -> { 1, 2 },
                                        Spacings         -> { 0.25, 0.5 }
                                    ]
                            },
                            Dynamic[
                                Which[
                                    !Wolfram`LLMFunctions`Common`CloudAuthenticatedQ[ ], "NotCloudConnected",
                                    TrueQ[ Wolfram`LLMFunctions`Common`$LLMKitInfo[ "userHasSubscription" ] ], "CloudConnectedAndSubscribed",
                                    !AssociationQ[ Wolfram`LLMFunctions`Common`$LLMKitInfo ], "Loading",
                                    True, "CloudConnectedButNotSubscribed" ] ],
                            BaselinePosition -> Baseline,
                            ImageSize -> Automatic ],
                        "",
                        username
                    }
                },
                Alignment -> { Left, Baseline },
                ItemSize -> { { Automatic, Fit, Automatic } },
                Spacings -> { Automatic, 0.7 } ],
            Background -> color @ "PreferencesContentBackground",
            FrameMargins -> { { 15, 15 }, { 15, 10 } },
            FrameStyle -> color @ "PreferencesContentServicesLLMKitFrame",
            ImageSize -> Scaled[ 1 ],
            RoundingRadius -> 3 ]
    ];
(* :!CodeAnalysis::EndBlock:: *)

makeLLMPanel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeServiceGrid*)
makeServiceGrid // beginDefinition;

makeServiceGrid[ ] :=
    Framed[
        Pane[
            Grid[
                KeyValueMap[ makeServiceGridRow, DeleteCases[ $availableServices, KeyValuePattern[ "Hidden" -> True ] ] ],
                Alignment  -> { Left, Baseline },
                Background -> { { }, { { color @ "PreferencesContentBackground" } } },
                ItemSize   -> { { Automatic, Automatic, Scaled[ 0.3 ], Fit, Automatic }, Automatic },
                Dividers   -> { { }, { False, { True }, False } },
                FrameStyle -> color @ "PreferencesContentDirectServiceConnectionsDelimiter",
                Spacings   -> { Automatic, 0.7 } ],
            AppearanceElements -> { },
            FrameMargins -> 8,
            Scrollbars -> { False, Automatic },
            ImageSize -> { Scaled[ 1 ], UpTo[ 150 ] } ],
        Background -> color @ "PreferencesContentBackground",
        FrameMargins -> 0,
        FrameStyle -> color @ "PreferencesContentFrame",
        ImageSize -> Scaled[ 1 ],
        RoundingRadius -> 3 ];

makeServiceGrid // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeServiceGridRows*)
makeServiceGridRows // beginDefinition;

makeServiceGridRows[ services_Association ] :=
    KeyValueMap[ makeServiceGridRow, DeleteCases[ services, KeyValuePattern[ "Hidden" -> True ] ] ];

makeServiceGridRows[ failure: HoldPattern @ Failure[ LLMServices`LLMServiceInformation, ___ ] ] :=
    Throw[ Pane[ failure, ImageSize -> { $preferencesWidth-50, Automatic } ], $servicesSettingsTag ];

makeServiceGridRows // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeServiceGridRow*)
makeServiceGridRow // beginDefinition;

makeServiceGridRow[ name_String, data_Association ] := {
    makeServiceAuthenticationDisplay[ name, resizeMenuIcon @ inlineChatbookExpressions @ serviceIcon @ data ]
};

makeServiceGridRow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deleteServiceButton*)
deleteServiceButton // beginDefinition;

deleteServiceButton[ "OpenAI" ] := Framed[
    Button[
        chatbookExpression[ "ToolManagerBin", color @ "PreferencesContentServicesDeleteIconAlt" ],
        Null,
        Enabled -> False,
        $deleteServiceButtonOptions
    ],
    $deleteServiceButtonFrameOptions
];

deleteServiceButton[ service_String ] := Tooltip[
    Framed[
        Button[
            $trashBin,
            Needs[ "LLMServices`" -> None ];
            LLMServices`UnregisterService @ service;
            disconnectService @ service;
            updateDynamics[ { "Services", "Preferences" } ],
            $deleteServiceButtonOptions
        ],
        $deleteServiceButtonFrameOptions
    ],
    tr[ "PreferencesContentUnregisterTooltip" ]
];

deleteServiceButton // endDefinition;


$deleteServiceButtonOptions = Sequence[
    Appearance     -> "Suppressed",
    ContentPadding -> False,
    FrameMargins   -> 0,
    ImageMargins   -> 0,
    Method         -> "Queued"
];


$deleteServiceButtonFrameOptions = Sequence[
    ContentPadding -> False,
    FrameMargins   -> 0,
    FrameStyle     -> Transparent,
    ImageMargins   -> 0
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeServiceAuthenticationDisplay*)
makeServiceAuthenticationDisplay // beginDefinition;

makeServiceAuthenticationDisplay[ service_String, icon_ ] :=
    DynamicModule[ { display },
        display = ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ];
        Dynamic[ display, TrackedSymbols :> { display } ],
        Initialization :> scopeInitialization @ createServiceAuthenticationDisplay[ service, icon, Dynamic[ display ] ],
        SynchronousInitialization -> False
    ];

makeServiceAuthenticationDisplay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*createServiceAuthenticationDisplay*)
createServiceAuthenticationDisplay // beginDefinition;

createServiceAuthenticationDisplay[ service_, icon_, Dynamic[ display_ ] ] := Enclose[
    Module[ { type },
        type = ConfirmBy[
            Quiet[
                credentialType @ service,
                { ServiceConnections`SavedConnections::wname, ServiceConnections`ServiceConnections::wname }
            ],
            StringQ,
            "CredentialType"
        ];
        display = Grid[
            {
                {
                    Spacer[ 5 ],
                    If[ type === "None",
                        Overlay[ { icon, Graphics[ Background -> color @ "PreferencesContentServicesIconFade_1", ImageSize -> { 21, 21 } ] } ],
                        icon ],
                    Style[ service, FontColor -> color @ "PreferencesContentServicesIconFade_2", FontOpacity -> If[ type === "None", 0.5, 1 ] ],
                    "",
                    connectOrDisconnectButton[ service, type, icon, Dynamic @ display ]
                }
            },
            Alignment -> { Left, Baseline },
            ItemSize -> { { Automatic, Automatic, Fit, Automatic } },
            Spacings -> { 0, Automatic }
        ];
    ],
    throwInternalFailure
];

createServiceAuthenticationDisplay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*connectOrDisconnectButton*)
connectOrDisconnectButton // beginDefinition;

connectOrDisconnectButton[ service_String, "None", icon_, Dynamic[ display_ ] ] :=
    Button[
        tr[ "ConnectButton" ],
        display = ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ];
        clearConnectionCache[ service, False ];
        Quiet[
            Wolfram`LLMFunctions`APIs`Common`ConnectToService @ service
        ];
        createServiceAuthenticationDisplay[ service, icon, Dynamic @ display ],
        Method -> "Queued"
    ];

connectOrDisconnectButton[ service_String, "SystemCredential"|"Environment"|"ServiceConnect", icon_, Dynamic[ display_ ] ] :=
    Button[
        tr[ "DisconnectButton" ],
        display = ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ];
        disconnectService @ service;
        createServiceAuthenticationDisplay[ service, icon, Dynamic @ display ],
        Method -> "Queued"
    ];

connectOrDisconnectButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Personas*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*personaSettingsPanel*)
personaSettingsPanel // beginDefinition;

personaSettingsPanel[ ] :=
    DynamicModule[
        { display = ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ] },
        Dynamic[ display ],
        Initialization            :> scopeInitialization[ display = CreatePersonaManagerPanel[ ] ],
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
        { display = ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ] },
        Dynamic[ display ],
        Initialization            :> scopeInitialization[ display = CreateLLMToolManagerPanel[ "GlobalScopeOnly" -> True ] ],
        SynchronousInitialization -> False,
        UnsavedVariables          :> { display }
    ];

toolSettingsPanel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Common*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*subsectionText*)
subsectionText // beginDefinition;
subsectionText[ text_ ] /; $CloudEvaluation := Style[ text, "subsectionText", FontColor -> color @ "PreferencesContentFont_1", FontSize -> 16, FontWeight -> "DemiBold" ];
subsectionText[ text_ ] := Style[ text, "subsectionText", FontColor -> color @ "PreferencesContentFont_1" ];
subsectionText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*prefsInputField*)
prefsInputField // beginDefinition;

prefsInputField[ None, value_Dynamic, type_, opts: OptionsPattern[ ] ] :=
    prefsInputField0[ value, type, opts ];

prefsInputField[ label_, value_Dynamic, type_, opts: OptionsPattern[ ] ] := Grid[
    { { label, prefsInputField0[ value, type, opts ] } },
    Alignment -> { Automatic, Baseline },
    BaseStyle -> { "leadinText", FontColor -> color @ "PreferencesContentFont_2" },
    Spacings  -> 0.5
];

prefsInputField // endDefinition;


prefsInputField0 // beginDefinition;

(* "InputFieldAppearance:RoundedFrame" TemplateBox definition in Core.nb is not flexible enough, so modify it here *)
prefsInputField0[ value_Dynamic, type_, opts: OptionsPattern[ ] ] :=
    Framed[
        InputField[ value, type,
            DeleteDuplicatesBy[
                Flatten @ {
                    opts,
                    Alignment        -> { Left, Top },
                    Appearance       -> "Frameless",
                    BaseStyle        -> { "controlText", FontColor -> color @ "PreferencesContentFont_2" },
                    ContinuousAction -> False,
                    Enabled          -> Automatic,
                    FrameMargins     -> { { 6, 6 }, { 4, 4 } },
                    ImageMargins     -> { { Automatic, Automatic }, { Automatic, Automatic } }
                },
                ToString @* First
            ]
        ],
        Alignment        -> { Left, Center },
        Background       -> color @ "PreferencesContentInputFieldBackground",
        BaseStyle        -> color @ "PreferencesContentFont_2",
        (* The following FrameBoxOptions do not work well in cloud, so disable if needed: *)
        BaselinePosition -> If[ TrueQ @ $CloudEvaluation, Automatic, Top -> Scaled[ 1.3 ] ],
        FrameMargins     -> 0,
        FrameStyle       -> { AbsoluteThickness[ 1. ], color @ "PreferencesContentInputFieldFrame" },
        RoundingRadius   -> 3
    ];

prefsInputField0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*prefsCheckbox*)
prefsCheckbox // beginDefinition;

prefsCheckbox[ value_Dynamic, label_, rest___ ] :=
    Grid[
        { { Checkbox[ value, rest ], clickableCheckboxLabel[ value, label ] } },
        Alignment -> { Left, Center },
        Spacings  -> 0.2
    ];

prefsCheckbox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*clickableCheckboxLabel*)
clickableCheckboxLabel // beginDefinition;

clickableCheckboxLabel[ value_Dynamic, label_ ] := Toggler[
    value,
    { True -> label, False -> label },
    BaselinePosition -> Scaled[ 0.2 ],
    BaseStyle        -> { "checkboxText", FontColor -> color @ "PreferencesContentFont_2" }
];

clickableCheckboxLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*infoTooltip*)
infoTooltip // beginDefinition;
infoTooltip[ label_, tooltip_ ] := Row @ { label, Spacer[ 3 ], Tooltip[ $infoIcon, tooltip ] };
infoTooltip // endDefinition;

$infoIcon := $infoIcon = chatbookExpression[ "InformationTooltip" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*popupValue*)
popupValue // beginDefinition;

popupValue[ value_String ] :=
    value -> value;

popupValue[ value_String, label: Except[ $$unspecified ] ] :=
    value -> label;

popupValue[ value_String, label: Except[ $$unspecified ], icon: Except[ $$unspecified ] ] :=
    If[ TrueQ @ $noIcons,
        value -> label,
        value -> Row[ { resizeMenuIcon @ inlineChatbookExpressions @ icon, label }, Spacer[ 1 ] ]
    ];

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
    With[ { service = extractServiceName @ CurrentChatSettings[ $preferencesScope, "Model" ] },
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
extractModelName[ KeyValuePattern[ "Name" -> name: _String|Automatic ] ] := name;
extractModelName[ _ ] := $DefaultModel[ "Name" ];
extractModelName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getServiceDefaultModel*)
getServiceDefaultModel // beginDefinition;

getServiceDefaultModel[ service_String ] := Enclose[
    Module[ { lastSelected, name },
        (* Get last selected models by service: *)
        lastSelected = Replace[
            Association @ CurrentChatSettings[ $preferencesScope, "ServiceDefaultModel" ],
            Except[ _? AssociationQ ] :> <| |>
        ];

        (* The last model name that was selected for this service (if it exists): *)
        name = ConfirmMatch[
            Lookup[ lastSelected, service, Inherited ],
            _String|Automatic|Inherited,
            "Name"
        ];

        (* If the service has not been selected before, choose a default model by service name and save it: *)
        If[ ! StringQ @ name,
            name = ConfirmMatch[ chooseDefaultModelName @ service, _String|Automatic, "DefaultName" ];
            lastSelected[ service ] = name;
            CurrentChatSettings[ $preferencesScope, "ServiceDefaultModel" ] = lastSelected;
        ];

        (* Return the name: *)
        ConfirmMatch[ name, _String|Automatic, "Result" ]
    ],
    throwInternalFailure
];

getServiceDefaultModel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ServiceConnection Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*disconnectService*)
disconnectService // beginDefinition;

disconnectService[ service_String ] :=
    With[ { key = credentialKey @ service },
        Unset @ SystemCredential @ key;
        SetEnvironment[ key -> None ];
        clearConnectionCache @ service;
        If[ extractServiceName @ CurrentChatSettings[ $preferencesScope, "Model" ] === service,
            CurrentChatSettings[ $preferencesScope, "Model" ] = $DefaultModel
        ];
        updateDynamics[ "Services" ]
    ];

disconnectService // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*credentialType*)
credentialType // beginDefinition;
credentialType[ service_String? systemCredentialQ      ] := "SystemCredential";
credentialType[ service_String? environmentCredentialQ ] := "Environment";
credentialType[ service_String? savedConnectionQ       ] := "ServiceConnect";
credentialType[ service_String? serviceConnectionQ     ] := "ServiceConnect";
credentialType[ service_String ] := "None";
credentialType // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*systemCredentialQ*)
systemCredentialQ // beginDefinition;
systemCredentialQ[ service_String ] := StringQ[ SystemCredential @ credentialKey @ service ];
systemCredentialQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*environmentCredentialQ*)
environmentCredentialQ // beginDefinition;
environmentCredentialQ[ service_String ] := StringQ[ Environment @ credentialKey @ service ];
environmentCredentialQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*credentialKey*)
credentialKey // beginDefinition;
credentialKey[ service_String ] := ToUpperCase @ service <> "_API_KEY";
credentialKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*savedConnectionQ*)
savedConnectionQ // beginDefinition;

savedConnectionQ[ service_String ] /; ! serviceFrameworkAvailable[ ] := (
    Needs[ "OAuth`" -> None ];
    MatchQ[ ServiceConnections`SavedConnections @ service, { __ } ]
);

savedConnectionQ[ service_String ] /; serviceFrameworkAvailable[ ] :=
    MatchQ[ serviceObjects @ service, { __ } ];

savedConnectionQ // endDefinition;

serviceObjects := serviceObjects = Symbol[ "System`ServiceObjects" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*serviceConnectionQ*)
serviceConnectionQ // beginDefinition;

serviceConnectionQ[ service_String ] /; ! serviceFrameworkAvailable[ ] := (
    Needs[ "OAuth`" -> None ];
    MatchQ[ ServiceConnections`ServiceConnections @ service, { __ } ]
);

serviceConnectionQ[ service_String ] /; serviceFrameworkAvailable[ ] :=
    savedConnectionQ @ service;

serviceConnectionQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*clearConnectionCache*)
clearConnectionCache // beginDefinition;

clearConnectionCache[ service_String ] :=
    clearConnectionCache[ service, True ];

clearConnectionCache[ service_String, delete: True|False ] /; ! serviceFrameworkAvailable[ ] := (
    Needs[ "Wolfram`LLMFunctions`" -> None ];
    If[ delete,
        Needs[ "OAuth`" -> None ];
        ServiceConnections`DeleteConnection /@ ServiceConnections`SavedConnections @ service;
        ServiceConnections`DeleteConnection /@ ServiceConnections`ServiceConnections @ service;
    ];
    If[ AssociationQ @ Wolfram`LLMFunctions`APIs`Common`$ConnectionCache,
        KeyDropFrom[ Wolfram`LLMFunctions`APIs`Common`$ConnectionCache, service ]
    ];
    InvalidateServiceCache[ ];
);

clearConnectionCache[ service_String, delete: True|False ] /; serviceFrameworkAvailable[ ] := (
    Needs[ "Wolfram`LLMFunctions`" -> None ];
    If[ delete,
        DeleteObject @ serviceObjects @ service;
    ];
    InvalidateServiceCache[ ];
);

clearConnectionCache // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*UI Elements*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$loadingPopupMenu*)
$loadingPopupMenu = PopupMenu[ "x", { "x" -> ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ] }, Enabled -> False ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$verticalSpacer*)
$verticalSpacer = { Pane[ "", ImageSize -> { Automatic, 20 } ], SpanFromLeft };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$trashBin*)
$trashBin := Mouseover[
    chatbookExpression[ "ToolManagerBin", color @ "PreferencesContentServicesDeleteIcon" ],
    chatbookExpression[ "ToolManagerBin", color @ "PreferencesContentServicesDeleteIconHover" ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$resetButton*)
$resetButton :=
    Module[ { icon, label },
        icon = Style[
            Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "FEBitmaps", "SyntaxColorResetIcon" ][ # ] ]&[
                color @ "PreferencesContentResetButtonIcon"
            ],
            GraphicsBoxOptions -> { BaselinePosition -> Scaled[ 0.1 ] }
        ];

        label = Grid[
            { { icon, Dynamic @ FEPrivate`FrontEndResource[ "PreferencesDialog", "ResetAllSettingsText" ] } },
            Alignment -> { Automatic, Baseline },
            BaseStyle -> { FontColor -> color @ "PreferencesContentFont_2" }
        ];

        expandScope @ Button[
            label,

            Needs[ "Wolfram`Chatbook`" -> None ];
            resetChatPreferences @ currentTabPage @ $preferencesScope
            ,
            BaseStyle -> {
                FontFamily -> Dynamic @ FrontEnd`CurrentValue[ "ControlsFontFamily" ],
                FontSize   -> Dynamic @ FrontEnd`CurrentValue[ "ControlsFontSize" ],
                FontColor  -> color @ "PreferencesContentFont_2"
            },
            ImageSize -> Automatic,
            Method    -> "Queued"
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resetChatPreferences*)
resetChatPreferences // beginDefinition;

resetChatPreferences[ "Notebooks" ] := expandScope[
    CurrentChatSettings[ $preferencesScope ] = Inherited;
    updateDynamics[ "Preferences" ];
];

resetChatPreferences[ "Personas" ] := (
    (* TODO: choice dialog to uninstall personas *)
    CurrentChatSettings[ $preferencesScope, "VisiblePersonas"  ] = $corePersonaNames;
    CurrentChatSettings[ $preferencesScope, "PersonaFavorites" ] = $corePersonaNames;
    updateDynamics[ "Personas" ];
);

resetChatPreferences[ "Tools" ] := expandScope[
    CurrentChatSettings[ $preferencesScope, "ToolSelectionType" ] = Inherited;
    CurrentChatSettings[ $preferencesScope, "ToolSelections"    ] = Inherited;
    (* TODO: choice dialog to uninstall tools *)
    updateDynamics[ "Tools" ];
];

resetChatPreferences[ "Services" ] := (
    (* TODO: choice dialog to clear service connections *)
    Needs[ "LLMServices`" -> None ];
    LLMServices`ResetServices[ ];
    InvalidateServiceCache[ ];
);

resetChatPreferences // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Navigation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*openPreferencesPage*)
openPreferencesPage // beginDefinition;

openPreferencesPage[ ] :=
    openPreferencesPage[ "Services" ];

openPreferencesPage[ page: $$preferencesPage ] := (
    CurrentChatSettings[ $FrontEnd, "CurrentPreferencesTab" ] = page;
    NotebookTools`OpenPreferencesDialog @ { "AI", page }
);

openPreferencesPage[ page: $$preferencesPage, id_ ] := (
    CurrentChatSettings[ $FrontEnd, "CurrentPreferencesTab" ] = page;
    NotebookTools`OpenPreferencesDialog[ { "AI", page }, { "AI", page, id } ]
);

openPreferencesPage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*highlightControl*)
highlightControl // beginDefinition;
highlightControl[ expr_, tab_, id_ ] /; $inFrontEndScope := Style[ expr, Background -> highlightColor[ tab, id ] ];
highlightControl[ expr_, tab_, id_ ] := Style @ expr;
highlightControl // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*highlightColor*)
highlightColor // beginDefinition;

highlightColor[ tab_, id_ ] /; $CloudEvaluation := None

highlightColor[ tab_, id_ ] :=
    With[
        {
            hid := FrontEnd`AbsoluteCurrentValue[
                $FrontEndSession,
                { PrivateFrontEndOptions, "DialogSettings", "Preferences", "ControlHighlight", "HighlightID" },
                None
            ],
            color := FrontEnd`AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "HighlightColor" }, None ]
        },
        Dynamic @ If[ hid === { "AI", tab, id }, color, None ]
    ];

highlightColor // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
