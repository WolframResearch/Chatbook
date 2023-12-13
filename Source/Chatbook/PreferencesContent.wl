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
(* Displays all the content found in the "AI Settings" tab in the preferences dialog. *)
createPreferencesContent // beginDefinition;

createPreferencesContent[ ] := Enclose[
    Module[ { notebookSettings, serviceSettings, personaSettings, toolSettings, tabView, reset },

        (* Retrieve the dynamic content for each preferences tab, confirming that it matches the expected types: *)
        notebookSettings = ConfirmMatch[ preferencesContent[ "Notebooks" ], _Dynamic | _DynamicModule, "Notebooks" ];
        serviceSettings  = ConfirmMatch[ preferencesContent[ "Services"  ], _Dynamic | _DynamicModule, "Services"  ];
        personaSettings  = ConfirmMatch[ preferencesContent[ "Personas"  ], _Dynamic | _DynamicModule, "Personas"  ];
        toolSettings     = ConfirmMatch[ preferencesContent[ "Tools"     ], _Dynamic | _DynamicModule, "Tools"     ];

        (* Create a TabView for the preferences content, with the tab state stored in the FE's private options: *)
        tabView = TabView[
            {
                { "Notebooks", "Notebooks" -> notebookSettings },
                { "Services" , "Services"  -> serviceSettings  },
                { "Personas" , "Personas"  -> personaSettings  },
                { "Tools"    , "Tools"     -> toolSettings     }
            },
            Dynamic @ CurrentValue[
                $FrontEnd,
                { PrivateFrontEndOptions, "DialogSettings", "Preferences", "TabSettings", "AI", "Top" },
                "Notebooks"
            ],
            Background   -> None,
            FrameMargins -> { { 2, 2 }, { 2, 3 } },
            ImageMargins -> { { 10, 10 }, { 2, 2 } },
            ImageSize    -> { 640, Automatic },
            LabelStyle   -> "feTabView" (* Defined in the SystemDialog stylesheet: *)
        ];

        (* Create a reset button that will reset preferences to default settings: *)
        reset = Pane[ $resetButton, ImageMargins -> { { 20, 0 }, { 0, 10 } }, ImageSize -> 640 ];

        (* Arrange the TabView and reset button in a Grid layout with vertical spacers: *)
        Grid[
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
            FrameStyle -> { AbsoluteThickness[ 1 ], GrayLevel[ 0.898 ] },
            Dividers   -> { False, { 4 -> True } },
            Spacings   -> { 0, 0.7 }
        ]
    ],
    throwInternalFailure
];

createPreferencesContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*preferencesContent*)
(* Define dynamic content for each of the preferences tabs. *)
preferencesContent // beginDefinition;

(* Content for the "Notebooks" tab: *)
preferencesContent[ "Notebooks" ] := trackedDynamic[ notebookSettingsPanel[ ], { "Models" } ];

(* Content for the "Personas" tab: *)
preferencesContent[ "Personas" ] := trackedDynamic[ personaSettingsPanel[ ], { "Personas" } ];

(* Content for the "Services" tab: *)
preferencesContent[ "Services" ] := trackedDynamic[ servicesSettingsPanel[ ], { "Models", "Services" } ];

(* Content for the "Tools" tab: *)
preferencesContent[ "Tools" ] := toolSettingsPanel[ ];

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
        { display = ProgressIndicator[ Appearance -> "Percolate" ] },
        Dynamic[ display ],
        (* createNotebookSettingsPanel is called to initialize the content of the panel: *)
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
    Module[
        {
            defaultSettingsLabel, defaultSettingsContent,
            interfaceLabel, interfaceContent,
            featuresLabel, featuresContent,
            content
        },

        (* Label for the default settings section using a style from SystemDialog.nb: *)
        defaultSettingsLabel = Style[ "Default Settings", "subsectionText" ];

        (* Retrieve and confirm the content for default settings: *)
        defaultSettingsContent = ConfirmMatch[
            trackedDynamic[ makeDefaultSettingsContent[ ], "Preferences" ],
            _Dynamic,
            "DefaultSettings"
        ];

        (* Label for the interface section using a style from SystemDialog.nb: *)
        interfaceLabel = Style[ "Chat Notebook Interface", "subsectionText" ];

        (* Retrieve and confirm the content for the chat notebook interface,
           ensuring it is not an error from makeInterfaceContent: *)
        interfaceContent = ConfirmMatch[
            makeInterfaceContent[ ],
            Except[ _makeInterfaceContent ],
            "Interface"
        ];

        (* Label for the features section using a style from SystemDialog.nb: *)
        featuresLabel = Style[ "Features", "subsectionText" ];

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
                { defaultSettingsLabel   },
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
            Dividers  -> { False, { 4 -> True, 8 -> True } },
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
    Module[ { assistanceCheckbox, personaSelector, modelSelector, temperatureInput },
        (* Checkbox to enable automatic assistance for normal shift-enter evaluations: *)
        assistanceCheckbox = ConfirmMatch[ makeAssistanceCheckbox[ ], _Style, "AssistanceCheckbox" ];
        (* The personaSelector is a pop-up menu for selecting the default persona: *)
        personaSelector = ConfirmMatch[ makePersonaSelector[ ], _Style, "PersonaSelector" ];
        (* The modelSelector is a dynamic module containing menus to select the service and model separately: *)
        modelSelector = ConfirmMatch[ makeModelSelector[ ], _DynamicModule, "ModelSelector" ];
        (* The temperatureInput is an input field for setting the default 'temperature' for responses: *)
        temperatureInput = ConfirmMatch[ makeTemperatureInput[ ], _Style, "TemperatureInput" ];

        (* Assemble the persona selector, model selector, and temperature slider into a grid layout: *)
        Grid[
            {
                { assistanceCheckbox },
                { personaSelector    },
                { modelSelector      },
                { temperatureInput   }
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

(* Top-level function without arguments, calls the version with personas from GetPersonasAssociation *)
makePersonaSelector[ ] :=
    makePersonaSelector @ GetPersonasAssociation[ ];

(* Overload of makePersonaSelector that takes an Association of personas,
   converts it to a list of labels for PopupMenu *)
makePersonaSelector[ personas_Association? AssociationQ ] :=
    makePersonaSelector @ KeyValueMap[ personaPopupLabel, personas ];

(* Overload of makePersonaSelector that takes a list of rules where each rule is a string to an association,
   creates a PopupMenu with this list *)
makePersonaSelector[ personas: { (_String -> _).. } ] :=
    highlightControl[
        Row @ {
            "Default Persona:",
            Spacer[ 3 ],
            PopupMenu[
                Dynamic[
                    currentChatSettings[ $FrontEnd, "LLMEvaluator" ],
                    (CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ] = #1) &
                ],
                personas
            ]
        },
        "Notebooks",
        "LLMEvaluator"
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
    DynamicModule[ { default, service, model, state, serviceSelector, modelSelector, highlight },

        default = currentChatSettings[ $FrontEnd, "Model" ];
        service = ConfirmBy[ extractServiceName @ default, StringQ, "ServiceName" ];
        model   = ConfirmBy[ extractModelName @ default  , StringQ, "ModelName"   ];
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
            Row @ {
                highlight[ "Default LLM Service:", serviceSelector, "ModelService" ],
                Spacer[ 5 ],
                highlight[
                    "Default Model:",
                        Dynamic[
                        If[ state === "Loading", $loadingPopupMenu, modelSelector ],
                        TrackedSymbols :> { state, modelSelector }
                    ],
                    "ModelName"
                ]
            },
            "Notebooks",
            "Model"
        ],

        Initialization :> (
            modelSelector = catchAlways @ makeModelNameSelector[
                Dynamic @ service,
                Dynamic @ model,
                Dynamic @ modelSelector,
                Dynamic @ state
            ];
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
            modelSelector = makeModelNameSelector[
                Dynamic @ service,
                Dynamic @ model,
                Dynamic @ modelSelector,
                Dynamic @ state
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

        models = ConfirmMatch[
            Block[ { $allowConnectionDialog = False }, getServiceModelList @ service ],
            { __Association } | Missing[ "NotConnected" ] | Missing[ "NoModelList" ],
            "ServiceModelList"
        ];

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
(* ::Subsubsubsection::Closed:: *)
(*modelNameInputField*)
modelNameInputField // beginDefinition;

modelNameInputField[ Dynamic[ service_ ], Dynamic[ model_ ], Dynamic[ modelSelector_ ], Dynamic[ state_ ] ] :=
    prefsInputField[
        "Model:",
        Dynamic[
            Replace[
                extractModelName @ CurrentChatSettings[ $FrontEnd, "Model" ],
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
        "Connect for model list",
        Needs[ "Wolfram`LLMFunctions`" -> None ];
        Replace[
            (* cSpell: ignore genconerr *)
            Quiet[ Wolfram`LLMFunctions`APIs`Common`ConnectToService @ service, { ServiceConnect::genconerr } ],
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
(* ::Subsubsection::Closed:: *)
(*makeAssistanceCheckbox*)
makeAssistanceCheckbox // beginDefinition;

makeAssistanceCheckbox[ ] := highlightControl[
    prefsCheckbox[
        Dynamic[
            TrueQ @ CurrentChatSettings[ $FrontEnd, "Assistance" ],
            (CurrentChatSettings[ $FrontEnd, "Assistance" ] = #1) &
        ],
        infoTooltip[
            "Enable automatic assistance",
            "If enabled, automatic AI provided suggestions will be added following evaluation results."
        ]
    ],
    "Notebooks",
    "Assistance"
];

makeAssistanceCheckbox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeTemperatureInput*)
makeTemperatureInput // beginDefinition;

makeTemperatureInput[ ] := highlightControl[
    prefsInputField[
        "Temperature:",
        Dynamic[
            CurrentChatSettings[ $FrontEnd, "Temperature" ],
            {
                None,
                If[ NumberQ @ #, CurrentChatSettings[ $FrontEnd, "Temperature" ] = # ] &
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
        Dynamic[
            TrueQ @ CurrentChatSettings[ $FrontEnd, "AutoFormat" ],
            (CurrentChatSettings[ $FrontEnd, "AutoFormat" ] = #1) &
        ],
        "Format chat output"
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
        Dynamic[
            MatchQ[ CurrentChatSettings[ $FrontEnd, "IncludeHistory" ], True|Automatic ],
            (CurrentChatSettings[ $FrontEnd, "IncludeHistory" ] = #1) &
        ],
        infoTooltip[
            "Include chat history",
            "If enabled, cells preceding the chat input will be included as additional context for the LLM."
        ]
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
            "Chat history length:",
            Dynamic[
                CurrentChatSettings[ $FrontEnd, "ChatHistoryLength" ],
                {
                    None,
                    If[ NumberQ @ # && NonNegative @ #,
                        CurrentChatSettings[ $FrontEnd, "ChatHistoryLength" ] = Floor[ # ]
                    ] &
                }
            ],
            Number,
            ImageSize -> { 50, Automatic }
        ],
        "Maximum number of cells to include in chat history"
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
        Dynamic[
            MatchQ[ CurrentChatSettings[ $FrontEnd, "MergeMessages" ], True|Automatic ],
            (CurrentChatSettings[ $FrontEnd, "MergeMessages" ] = #1) &
        ],
        infoTooltip[
            "Merge chat messages",
            "If enabled, adjacent cells with the same author will be merged into a single chat message."
        ]
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
                Style[ "Enable multimodal content: ", "leadinText" ],
                PopupMenu[
                    Dynamic @ CurrentChatSettings[ $FrontEnd, "Multimodal" ],
                    {
                        Automatic -> "Automatic by model",
                        True      -> "Always enabled",
                        False     -> "Always disabled"
                    },
                    MenuStyle -> "controlText"
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
                Style[ "Enable tools: ", "leadinText" ],
                PopupMenu[
                    Dynamic @ CurrentChatSettings[ $FrontEnd, "ToolsEnabled" ],
                    {
                        Automatic -> "Automatic by model",
                        True      -> "Always enabled",
                        False     -> "Always disabled"
                    },
                    MenuStyle -> "controlText"
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
                    Style[ "Tool call frequency:", "leadinText" ],
                    PopupMenu[
                        Dynamic[
                            type,
                            Function[
                                If[ # === Automatic
                                    ,
                                    type = Automatic;
                                    CurrentChatSettings[ $FrontEnd, "ToolCallFrequency" ] = Automatic
                                    ,
                                    type = "Custom";
                                    CurrentChatSettings[ $FrontEnd, "ToolCallFrequency" ] = 0.5
                                ]
                            ]
                        ],
                        {
                            Automatic -> "Automatic",
                            "Custom"  -> "Custom"
                        },
                        MenuStyle -> "controlText"
                    ],
                    PaneSelector[
                        {
                            Automatic -> "",
                            "Custom" -> Grid[
                                {
                                    {
                                        Spacer[ 5 ],
                                        Style[ "Rare", "defaultSubtext" ],
                                        Slider[
                                            Dynamic[
                                                frequency,
                                                {
                                                    Function[ frequency = # ],
                                                    Function[
                                                        CurrentChatSettings[ $FrontEnd, "ToolCallFrequency" ] = #;
                                                        frequency = #
                                                    ]
                                                }
                                            ],
                                            ImageSize -> { 100, Automatic }
                                        ],
                                        Style[ "Often", "defaultSubtext" ]
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
        Initialization :> With[ { val = CurrentChatSettings[ $FrontEnd, "ToolCallFrequency" ] },
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

servicesSettingsPanel[ ] := Enclose[
    Module[ { settingsLabel, settings, serviceGrid },

        settingsLabel = Style[ "Registered Services", "subsectionText" ];
        settings      = ConfirmMatch[ makeModelSelector[ ], _DynamicModule, "ServicesSettings" ];
        serviceGrid   = ConfirmMatch[ makeServiceGrid[ ], _Grid, "ServiceGrid" ];

        Pane[
            Grid[
                {
                    { settingsLabel },
                    { settings      },
                    { serviceGrid   }
                },
                Alignment -> { Left, Baseline },
                ItemSize  -> { Fit, Automatic },
                Spacings  -> { 0, 0.7 }
            ],
            ImageMargins -> 8
        ]
    ],
    throwInternalFailure
];

servicesSettingsPanel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeServiceGrid*)
makeServiceGrid // beginDefinition;

makeServiceGrid[ ] := Grid[
    Join[
        { { Spacer[ 1 ], "Service", SpanFromLeft, "Authentication", "", Spacer[ 1 ] } },
        KeyValueMap[ makeServiceGridRow, $availableServices ]
    ],
    Alignment  -> { Left, Baseline },
    Background -> { { }, { GrayLevel[ 0.898 ], { White } } },
    ItemSize   -> { { Automatic, Automatic, Scaled[ .3 ], Fit, Automatic }, Automatic },
    Dividers   -> { True, All },
    FrameStyle -> GrayLevel[ 0.898 ],
    Spacings   -> { Automatic, 0.7 }
];

makeServiceGrid // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeServiceGridRow*)
makeServiceGridRow // beginDefinition;

makeServiceGridRow[ name_String, data_Association ] := {
    Spacer[ 1 ],
    resizeMenuIcon @ inlineTemplateBoxes @ serviceIcon @ data,
    name,
    makeServiceAuthenticationDisplay @ name,
    deleteServiceButton @ name,
    Spacer[ 1 ]
};

makeServiceGridRow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deleteServiceButton*)
deleteServiceButton // beginDefinition;

deleteServiceButton[ "OpenAI" ] := Framed[
    Button[
        Insert[ chatbookIcon[ "ToolManagerBin", False ], GrayLevel[ 0.8 ], { 1, 1, 1 } ],
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
    "Unregister service connection"
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

makeServiceAuthenticationDisplay[ service_String ] :=
    DynamicModule[ { display },
        display = ProgressIndicator[ Appearance -> "Percolate" ];
        Dynamic[ display, TrackedSymbols :> { display } ],
        Initialization :> createServiceAuthenticationDisplay[ service, Dynamic[ display ] ],
        SynchronousInitialization -> False
    ];

makeServiceAuthenticationDisplay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*createServiceAuthenticationDisplay*)
createServiceAuthenticationDisplay // beginDefinition;

createServiceAuthenticationDisplay[ service_, Dynamic[ display_ ] ] := Enclose[
    Module[ { type },
        type = ConfirmBy[ credentialType @ service, StringQ, "CredentialType" ];
        display = Row[
            {
                Pane[ type, ImageSize -> { 120, Automatic } ],
                connectOrDisconnectButton[ service, type, Dynamic @ display ]
            },
            Alignment -> { Left, Baseline }
        ];
    ],
    throwInternalFailure
];

createServiceAuthenticationDisplay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*connectOrDisconnectButton*)
connectOrDisconnectButton // beginDefinition;

connectOrDisconnectButton[ service_String, "None", Dynamic[ display_ ] ] :=
    Button[
        "Connect",
        display = ProgressIndicator[ Appearance -> "Percolate" ];
        clearConnectionCache[ service, False ];
        Quiet[ Wolfram`LLMFunctions`APIs`Common`ConnectToService @ service, { ServiceConnect::genconerr } ];
        createServiceAuthenticationDisplay[ service, Dynamic @ display ],
        Method -> "Queued"
    ];

connectOrDisconnectButton[ service_String, "SystemCredential"|"Environment"|"ServiceConnect", Dynamic[ display_ ] ] :=
    Button[
        "Disconnect",
        display = ProgressIndicator[ Appearance -> "Percolate" ];
        disconnectService @ service;
        createServiceAuthenticationDisplay[ service, Dynamic @ display ],
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
(*prefsInputField*)
prefsInputField // beginDefinition;

(* cSpell: ignore leadin *)
prefsInputField[ label_, value_Dynamic, type_, opts: OptionsPattern[ ] ] := Grid[
    { { label, prefsInputField0[ value, type, opts ] } },
    Alignment -> { Automatic, Baseline },
    BaseStyle -> { "leadinText" },
    Spacings  -> 0.5
];

prefsInputField // endDefinition;


prefsInputField0 // beginDefinition;

prefsInputField0[ value_Dynamic, type_, opts: OptionsPattern[ ] ] := RawBoxes @ StyleBox[
    TemplateBox[
        {
            value,
            type,
            DeleteDuplicatesBy[
                Flatten @ {
                    opts,
                    Alignment        -> { Left, Top },
                    BaseStyle        -> { "controlText" },
                    ContinuousAction -> False,
                    ImageMargins     -> { { Automatic, Automatic }, { Automatic, Automatic } }
                },
                ToString @* First
            ],
            Automatic
        },
        "InputFieldAppearance:RoundedFrame"
    ],
    FrameBoxOptions -> { BaselinePosition -> Top -> Scaled[ 1.3 ] }
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
    BaseStyle        -> { "checkboxText" }
];

clickableCheckboxLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*infoTooltip*)
infoTooltip // beginDefinition;
infoTooltip[ label_, tooltip_ ] := Row @ { label, Spacer[ 3 ], Tooltip[ $infoIcon, tooltip ] };
infoTooltip // endDefinition;

$infoIcon = chatbookIcon[ "InformationTooltip", False ];

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
        If[ extractServiceName @ CurrentChatSettings[ $FrontEnd, "Model" ] === service,
            CurrentChatSettings[ $FrontEnd, "Model" ] = $DefaultModel
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

savedConnectionQ[ service_String ] := (
    Needs[ "OAuth`" -> None ];
    MatchQ[ ServiceConnections`SavedConnections @ service, { __ } ]
);

savedConnectionQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*serviceConnectionQ*)
serviceConnectionQ // beginDefinition;

serviceConnectionQ[ service_String ] := (
    Needs[ "OAuth`" -> None ];
    MatchQ[ ServiceConnections`ServiceConnections @ service, { __ } ]
);

serviceConnectionQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*clearConnectionCache*)
clearConnectionCache // beginDefinition;

clearConnectionCache[ service_String ] :=
    clearConnectionCache[ service, True ];

clearConnectionCache[ service_String, delete: True|False ] := (
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

clearConnectionCache // endDefinition;

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
(*$trashBin*)
$trashBin := Mouseover[
    Insert[ chatbookIcon[ "ToolManagerBin", False ], GrayLevel[ 0.65 ], { 1, 1, 1 } ],
    Insert[ chatbookIcon[ "ToolManagerBin", False ], Hue[ 0.59, 0.9, 0.93 ], { 1, 1, 1 } ]
];

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
                { PrivateFrontEndOptions, "DialogSettings", "Preferences", "TabSettings", "AI", "Top" }
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

resetChatPreferences[ "Notebooks" ] := (
    FrontEndExecute @ FrontEnd`RemoveOptions[
        $FrontEnd,
        { System`LLMEvaluator, { TaggingRules, "ChatNotebookSettings" } }
    ];
    updateDynamics[ "Preferences" ];
);

resetChatPreferences[ "Personas" ] :=
    With[ { path = Sequence[ PrivateFrontEndOptions, "InterfaceSettings", "Chatbook" ] },
        (* TODO: choice dialog to uninstall personas *)
        CurrentValue[ $FrontEnd, { path, "VisiblePersonas"  } ] = $corePersonaNames;
        CurrentValue[ $FrontEnd, { path, "PersonaFavorites" } ] = $corePersonaNames;
        resetChatPreferences[ "Notebooks" ];
    ];

resetChatPreferences[ "Tools" ] := (
    (* TODO: choice dialog to uninstall tools *)
    resetChatPreferences[ "Notebooks" ];
);

resetChatPreferences[ "Services" ] := (
    (* TODO: choice dialog to clear service connections *)
    Needs[ "LLMServices`" -> None ];
    LLMServices`ResetServices[ ];
    InvalidateServiceCache[ ];
    resetChatPreferences[ "Notebooks" ];
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
    openPreferencesPage[ "Notebooks" ];

openPreferencesPage[ page: $$preferencesPage ] :=
    NotebookTools`OpenPreferencesDialog @ { "AI", page };

openPreferencesPage[ page: $$preferencesPage, id_ ] :=
    NotebookTools`OpenPreferencesDialog[ { "AI", page }, { "AI", page, id } ];

openPreferencesPage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*highlightControl*)
highlightControl // beginDefinition;
highlightControl[ expr_, tab_, id_ ] := Style[ expr, Background -> highlightColor[ tab, id ] ];
highlightControl // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*highlightColor*)
highlightColor // beginDefinition;

highlightColor[ tab_, id_ ] :=
    With[
        {
            hid := FrontEnd`AbsoluteCurrentValue[
                $FrontEndSession,
                { PrivateFrontEndOptions, "DialogSettings", "Preferences", "ControlHighlight", "HighlightID" },
                None
            ],
            color := FrontEnd`AbsoluteCurrentValue[ EvaluationNotebook[ ], { TaggingRules, "HighlightColor" }, None ]
        },
        Dynamic @ If[ hid === { "AI", tab, id }, color, None ]
    ];

highlightColor // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

End[ ];
EndPackage[ ];
