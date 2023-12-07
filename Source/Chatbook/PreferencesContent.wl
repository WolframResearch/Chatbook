(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PreferencesContent`" ];

HoldComplete[
    `createPreferencesContent;
    `openPreferencesPage;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`Personas`" ];
Needs[ "Wolfram`Chatbook`UI`" ];
Needs[ "Wolfram`Chatbook`Errors`" ];
Needs[ "Wolfram`Chatbook`PreferencesUtils`" ];
Needs[ "Wolfram`Chatbook`Settings`" ];
Needs[ "Wolfram`Chatbook`Models`" ];
Needs[ "Wolfram`Chatbook`Services`" ];
Needs[ "Wolfram`Chatbook`Dynamics`" ];
Needs[ "Wolfram`Chatbook`ToolManager`" ];
Needs[ "Wolfram`Chatbook`PersonaManager`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$verticalSpacer   = { Pane[ "", ImageSize -> { Automatic, 20 } ], SpanFromLeft };
$preferencesPages = { "Notebooks", "Services", "Personas", "Tools" };
$$preferencesPage = Alternatives @@ $preferencesPages;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Content*)

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
(* ::Subsubsection::Closed:: *)
(*preferencesContent*)
preferencesContent // beginDefinition;
preferencesContent[ "Notebooks" ] := trackedDynamic[ notebookSettingsPanel[ ], { "Models" } ];
preferencesContent[ "Personas"  ] := trackedDynamic[ personaSettingsPanel[ ], { "Personas" } ];
preferencesContent[ "Services"  ] := trackedDynamic[ "Coming soon.", { "Models" } ];
preferencesContent[ "Tools"     ] := toolSettingsPanel[ ];
preferencesContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookSettingsPanel*)
notebookSettingsPanel // beginDefinition;

notebookSettingsPanel[ ] := Pane[
    DynamicModule[
        { display = ProgressIndicator[ Appearance -> "Percolate" ] },
        Dynamic[ display ],
        Initialization :> (display = makeFrontEndAndNotebookSettingsContent @ $FrontEnd),
        SynchronousInitialization -> False
    ],
    FrameMargins -> { { 8, 8 }, { 13, 13 } },
    Spacings     -> { 0, 1.5 }
];

notebookSettingsPanel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
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
(* ::Subsubsection::Closed:: *)
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
                                "ChatNotebooks",
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

            FrontEndExecute @ FrontEnd`RemoveOptions[
                $FrontEnd,
                { System`LLMEvaluator, { TaggingRules, "ChatNotebookSettings" } }
            ];

            CurrentValue[ $FrontEnd, { PrivateFrontEndOptions, "InterfaceSettings", "ChatNotebooks" } ] = Inherited
            ,
            BaseStyle -> {
                FontFamily -> Dynamic @ FrontEnd`CurrentValue[ "ControlsFontFamily" ],
                FontSize   -> Dynamic @ FrontEnd`CurrentValue[ "ControlsFontSize" ],
                FontColor  -> Black
            },
            ImageSize -> Automatic
        ]
    ];

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
