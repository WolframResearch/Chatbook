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
(*Main*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createPreferencesContent*)
(* Displays all the content found in the "AI Settings" tab in the preferences dialog. *)
createPreferencesContent // beginDefinition;

createPreferencesContent[ ] := Enclose[
    Module[ { tabs, tabView, reset },
        (* Retrieve the dynamic content for each preferences tab, confirming that it matches the expected types: *)
        DynamicModule[ { tab, dmPrefCache, default, service, model, state, serviceSelector = $loadingPopupMenu, modelNameSelector = $loadingPopupMenu },
            
            tabs = createTabViewTabs[ $displayedPreferencesPages, dmPrefCache, default, service, model, state, serviceSelector, modelNameSelector ];

            (* Create a TabView for the preferences content, with the tab state stored in the FE's private options: *)
            tabView = TabView[
                tabs,
                Dynamic @ tab,
                Background   -> None,
                FrameMargins -> { { 2, 2 }, { 2, 3 } },
                ImageMargins -> { { 10, 10 }, { 2, 2 } },
                ImageSize    -> { Scaled[ 1 ], Automatic },
                LabelStyle   -> "feTabView" (* Defined in the SystemDialog stylesheet: *)
            ];

            (* Create a reset button that will reset preferences to default settings: *)
            reset = Pane[ resetButton[ Dynamic @ tab, Dynamic @ dmPrefCache ], ImageMargins -> { { 20, 0 }, { 0, 10 } }, ImageSize -> Scaled[ 1 ] ];

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
            ],

            Initialization   :> (
                dmPrefCache = CurrentChatSettings[ $FrontEnd ];
                tab = Lookup[ dmPrefCache, "CurrentPreferencesTab", "Services", Replace[ #, $$unspecified -> "Services" ]& ];
                
                default = Lookup[ dmPrefCache, "Model" ];
                service = ConfirmBy[ extractServiceName @ default, StringQ, "ServiceName" ];
                model   = ConfirmMatch[ extractModelName @ default, _String | Automatic, "ModelName" ];
                state   = If[ modelListCachedQ @ service, "Loaded", "Loading" ];
                
                serviceSelector = makeServiceSelector[
                    <|
                        $availableServices,
                        "LLMKit" -> <| "Service" -> "Wolfram LLM Kit", "Icon" -> chatbookExpression["llmkit-dialog-sm"] |>
                    |>,
                    dmPrefCache, service, model, modelNameSelector, state ];

                modelNameSelector = catchAlways @ makeModelNameSelector[ dmPrefCache, service, model, modelNameSelector, state ];

                state = "Loaded";
            ),
            SynchronousInitialization -> False,
            UnsavedVariables          :> { state },
            Deinitialization          :> (CurrentChatSettings[ $FrontEnd, "CurrentPreferencesTab" ] = tab)

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
          ImageSize  -> { $preferencesWidth, $cloudPreferencesHeight },
          Scrollbars -> { None, True }
    ];

makeScrollableInCloud[ expr_ ] :=
    Pane @ expr;

makeScrollableInCloud // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createTabViewTabs*)
createTabViewTabs // beginDefinition;

Attributes[ createTabViewTabs ] = { HoldRest };

createTabViewTabs[ pages: { __String }, dmPrefCache_, default_, service_, model_, state_, serviceSelector_, modelNameSelector_ ] :=
    createTabViewTab[ #, dmPrefCache, default, service, model, state, serviceSelector, modelNameSelector ]& /@ pages;

createTabViewTabs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createTabViewTab*)
createTabViewTab // beginDefinition;

Attributes[ createTabViewTab ] = { HoldRest };

createTabViewTab[ name_String, dmPrefCache_, default_, service_, model_, state_, serviceSelector_, modelNameSelector_ ] := {
    name,
    tr[ "PreferencesContent" <> name <> "Tab" ] -> preferencesContent[ name, dmPrefCache, default, service, model, state, serviceSelector, modelNameSelector ]
};

createTabViewTab // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*preferencesContent*)
(* Define dynamic content for each of the preferences tabs. *)
preferencesContent // beginDefinition;

Attributes[ preferencesContent ] = { HoldRest };

(* Content for the "Notebooks" tab: *)
preferencesContent[ "Notebooks", dmPrefCache_, default_, service_, model_, state_, serviceSelector_, modelNameSelector_ ] :=
    notebookSettingsPanel[ dmPrefCache, default, service, model, state, serviceSelector, modelNameSelector ];

(* Content for the "Personas" tab: *)
preferencesContent[ "Personas", dmPrefCache_, ___ ] := personaSettingsPanel[ Dynamic @ dmPrefCache ];

(* Content for the "Services" tab: *)
preferencesContent[ "Services", dmPrefCache_, default_, service_, model_, state_, serviceSelector_, modelNameSelector_ ] :=
    servicesSettingsPanel[ dmPrefCache, default, service, model, state, serviceSelector, modelNameSelector ];

(* Content for the "Tools" tab: *)
preferencesContent[ "Tools", dmPrefCache_, ___ ] := toolSettingsPanel[ Dynamic @ dmPrefCache ];

preferencesContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*disabledAIOverlayBanner*)

disabledAIOverlayBanner // beginDefinition;

disabledAIOverlayBanner[ ] :=
Framed[
    Grid[
        { {
            chatbookExpression[ "DisabledByAdmin" ],
            Grid[
                {
                    { tr @ "PreferencesContentAIDisabledByAdmin" },
                    {
                        Button[
                            Style[
                                tr @ "PreferencesContentAIDisabledLearnMore",
                                FontColor ->
                                    Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[
                                        color @ "PreferencesContentLLMSignInButtonFontHover",
                                        color @ "PreferencesContentLLMSignInButtonFont"
                                    ],
                                FontSize  -> 13,
                                FontSlant -> Italic
                            ],
                            Beep[ ], (* FIXME *)
                            Appearance -> "Suppressed",
                            ImageSize  -> Automatic
                        ]
                    }
                },
                Alignment -> { Left, Center },
                BaseStyle -> { FontSize -> 14 },
                Spacings  -> { 0, 0.1 }
            ]
        } },
        Alignment -> { Left, Center },
        Spacings  -> { 1.0, 0 }
    ],
    Alignment      -> { Left, Top },
    Background     -> LightDarkSwitched @ GrayLevel[ 1 ],
    FrameMargins   -> 14,
    FrameStyle     -> LightDarkSwitched @ RGBColor["#EBEBEB"],
    ImageMargins   -> { { 0, 0 }, { 10, 0 } },
    ImageSize      -> Scaled[ 1 ],
    RoundingRadius -> 8
];

disabledAIOverlayBanner // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*disabledAIOverlay*)

disabledAIOverlay // beginDefinition;

(* Option 1: Overlay
    Pros: can more closely match OS TabView background color
    Cons: ImageSize not well determined and can push Preferences reset button fairly low to the bottom of a pane *)
(* disabledAIOverlay[ content_ ] :=
If[ $preferencesContentEnabledQ,
    content
    ,
    DynamicModule[ { imageSize = { Scaled[ 1 ], Scaled[ 1 ] } },
        Grid[
            {
                { disabledAIOverlayBanner[ ] },
                {
                    Overlay[
                        {
                            Pane[ content, Alignment -> { Left, Top }, AppearanceElements -> None, ImageSize -> Dynamic @ imageSize ],
                            Deploy @ Graphics[
                                Background -> Switch[ $OperatingSystem,
                                    "MacOSX", LightDarkSwitched[ GrayLevel[ 0.9745098039215686, 0.5 ], GrayLevel[ 0.15686274509803920, 0.5 ] ],
                                    _,        LightDarkSwitched[ GrayLevel[ 0.9607843137254901, 0.5 ], GrayLevel[ 0.15294117647058822, 0.5 ] ] ],
                                ImageSize  -> Dynamic @ imageSize ]
                        },
                        { 1, 2 },
                        2
                    ]
                }
            },
            Alignment -> { Left, Top },
            Spacings  -> { 0, 0 }
        ]
    ]
]; *)

(* Option 2: ContentsOpacity
    Pros: easier to implement; does not push down reset button
    Cons: Enabled -> False does not disable all mouse-hover elements (e.g. tooltips, also can delete installed personas) *)

disabledAIOverlay[ content_, localAIOnlyQ_ ] :=
If[ TrueQ @ localAIOnlyQ, (* Cloud may not be aware of new licence bit *)
    Grid[
        {
            { disabledAIOverlayBanner[ ] },
            {
                 (* "controlText" isn't a 1-to-1 match with the enabled state, but it's close *)
                RawBoxes @ Cell[ BoxData @ ToBoxes @
                    Style[ content, "controlText", Enabled -> False ],
                    Background -> Switch[ $OperatingSystem,
                        "MacOSX", LightDarkSwitched[ GrayLevel[ 0.9745098039215686, 0.5 ], GrayLevel[ 0.15686274509803920, 0.5 ] ],
                        _,        LightDarkSwitched[ GrayLevel[ 0.9607843137254901, 0.5 ], GrayLevel[ 0.15294117647058822, 0.5 ] ]
                    ],
                    Enabled            -> False,
                    PrivateCellOptions -> { "ContentsOpacity" -> 0.25 }
                ]
            }
        },
        Alignment -> { Left, Top },
        Spacings  -> { 0, 0 }
    ]
    ,
    content
];


disabledAIOverlay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebooks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookSettingsPanel*)
notebookSettingsPanel // beginDefinition;

Attributes[ notebookSettingsPanel ] = { HoldAll };

notebookSettingsPanel[ dmPrefCache_, default_, service_, model_, state_, serviceSelector_, modelNameSelector_ ] :=
    DynamicModule[
        (* Display a progress indicator until content is loaded via initialization: *)
        { display = ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ] },
        Dynamic @ display,
        (* createNotebookSettingsPanel is called to initialize the content of the panel: *)
        Initialization :> (display = disabledAIOverlay[
            createNotebookSettingsPanel[ dmPrefCache, default, service, model, state, serviceSelector, modelNameSelector ],
            FE`Evaluate @ FEPrivate`LocalAIOnlyQ[ ]
        ]),
        SynchronousInitialization -> False
    ];

notebookSettingsPanel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createNotebookSettingsPanel*)
createNotebookSettingsPanel // beginDefinition;

Attributes[ createNotebookSettingsPanel ] = { HoldAll };

(* Cache the content in case panel is redrawn: *)
createNotebookSettingsPanel[ dmPrefCache_, default_, service_, model_, state_, serviceSelector_, modelNameSelector_ ] := Enclose[
    Module[
        {
            defaultSettingsContent,
            instructionsLabel, instructionsContent,
            interfaceLabel, interfaceContent,
            featuresLabel, featuresContent,
            content
        },

        (* Retrieve and confirm the content for default settings: *)
        defaultSettingsContent = ConfirmMatch[
            makeDefaultSettingsContent[ dmPrefCache, default, service, model, state, serviceSelector, modelNameSelector ],
            Except[ _makeDefaultSettingsContent ],
            "DefaultSettings"
        ];

        (* Label for the standing instructions section: *)
        instructionsLabel = subsectionText @ tr[ "PreferencesContentSubsectionInstructions" ];

        (* Retrieve and confirm the content for personalization: *)
        instructionsContent = ConfirmMatch[
            makeInstructionsContent[ Dynamic @ dmPrefCache ],
            Except[ _makeInstructionsContent ],
            "Instructions"
        ];

        (* Label for the interface section using a style from SystemDialog.nb: *)
        interfaceLabel = subsectionText @ tr[ "PreferencesContentSubsectionChat" ];

        (* Retrieve and confirm the content for the chat notebook interface,
           ensuring it is not an error from makeInterfaceContent: *)
        interfaceContent = ConfirmMatch[
            makeInterfaceContent[ Dynamic @ dmPrefCache ],
            Except[ _makeInterfaceContent ],
            "Interface"
        ];

        (* Label for the features section using a style from SystemDialog.nb: *)
        featuresLabel = subsectionText @ tr[ "PreferencesContentSubsectionFeatures" ];

        (* Retrieve and confirm the content for the chat notebook features,
           ensuring it is not an error from makeFeaturesContent: *)
        featuresContent = ConfirmMatch[
            makeFeaturesContent[ Dynamic @ dmPrefCache ],
            Except[ _makeFeaturesContent ],
            "Features"
        ];

        (* Assemble the default settings and interface content into a grid layout: *)
        content = Grid[
            {
                { defaultSettingsContent },
                { Spacer[ 1 ]            },
                { Spacer[ 1 ]            },
                { instructionsLabel      },
                { instructionsContent    },
                { Spacer[ 1 ]            },
                { interfaceLabel         },
                { interfaceContent       },
                { Spacer[ 1 ]            },
                { Spacer[ 1 ]            },
                { featuresLabel          },
                { featuresContent        }
            },
            Alignment -> { Left, Baseline },
            Dividers  -> { False, { 3 -> True, 6 -> True, 10 -> True } },
            ItemSize  -> { Fit, Automatic },
            Spacings  -> { 0, 0.7 }
        ];

        
        Pane[
            content,
            FrameMargins -> { { 8, 8 }, { 13, 13 } },
            Spacings     -> { 0, 1.5 }
        ]
    ],
    throwInternalFailure
];

createNotebookSettingsPanel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeDefaultSettingsContent*)
makeDefaultSettingsContent // beginDefinition;

Attributes[ makeDefaultSettingsContent ] = { HoldAll };

makeDefaultSettingsContent[ dmPrefCache_, default_, service_, model_, state_, serviceSelector_, modelNameSelector_ ] := Enclose[
    Module[ { assistanceCheckbox, personaSelector, modelSelector, temperatureInput, openAICompletionURLInput },
        (* Checkbox to enable automatic assistance for normal shift-enter evaluations: *)
        assistanceCheckbox = ConfirmMatch[ makeAssistanceCheckbox[ Dynamic @ dmPrefCache ], _Style|Nothing, "AssistanceCheckbox" ];
        (* The personaSelector is a pop-up menu for selecting the default persona: *)
        personaSelector = makePersonaSelector[ Dynamic @ dmPrefCache ];
        (* The modelSelector is a dynamic module containing menus to select the service and model separately: *)
        modelSelector = makeModelSelector[ "Notebooks", dmPrefCache, default, service, model, state, serviceSelector, modelNameSelector ];
        (* The temperatureInput is an input field for setting the default 'temperature' for responses: *)
        temperatureInput = ConfirmMatch[ makeTemperatureInput[ Dynamic @ dmPrefCache ], _Style, "TemperatureInput" ];
        (* The openAICompletionURLInput is an input field for setting URL used for API calls to OpenAI: *)
        openAICompletionURLInput = ConfirmMatch[
            makeOpenAICompletionURLInput[ Dynamic @ dmPrefCache ],
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
makePersonaSelector[ Dynamic[ dmPrefCache_ ] ] := makePersonaSelector0[ Dynamic @ dmPrefCache ];
makePersonaSelector // endDefinition;

makePersonaSelector0 // beginDefinition;

(* Top-level function, calls the version with personas from GetPersonasAssociation *)
makePersonaSelector0[ Dynamic[ dmPrefCache_ ] ] :=
    makePersonaSelector0[ Dynamic @ dmPrefCache, GetPersonasAssociation[ "IncludeHidden" -> False ] ];

(* Overload of makePersonaSelector0 that takes an Association of personas,
   converts it to a list of labels for PopupMenu *)
makePersonaSelector0[ Dynamic[ dmPrefCache_ ], personas_Association? AssociationQ ] :=
    makePersonaSelector0[ Dynamic @ dmPrefCache, KeyValueMap[ personaPopupLabel, personas ] ];

(* Overload of makePersonaSelector0 that takes a list of rules where each rule is a string to an association,
   creates a PopupMenu with this list *)
makePersonaSelector0[ Dynamic[ dmPrefCache_ ], personas: { (_String -> _).. } ] :=
    highlightControl[
        Row @ {
            tr[ "PreferencesContentPersonaLabel" ],
            Spacer[ 3 ],
            prefsPopupMenu[
                Function[ dmPrefCache[ "LLMEvaluator" ] = CurrentChatSettings[ $FrontEnd, "LLMEvaluator" ] = # ],
                personas,
                Hold @ Lookup[ dmPrefCache, "LLMEvaluator" ],
                MenuStyle -> { "controlText", FontColor -> color @ "PreferencesContentFont_2" }
            ]
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

Attributes[ makeModelSelector ] = { HoldRest };

makeModelSelector[ type_String, heldRest__ ] := makeModelSelector0[ type, heldRest ];

makeModelSelector // endDefinition;


makeModelSelector0 // beginDefinition;

Attributes[ makeModelSelector0 ] = { HoldRest };

makeModelSelector0[ type_String, dmPrefCache_, default_, service_, model_, state_, serviceSelector_, modelNameSelector_ ] :=
    makeModelSelector0[
        {
            type,
            <|
                $availableServices,
                "LLMKit" -> <| "Service" -> "Wolfram AI Services", "Icon" -> chatbookExpression["llmkit-dialog-sm"] |>
            |>
        },
        dmPrefCache, default, service, model, state, serviceSelector, modelNameSelector
    ]

makeModelSelector0[ { type_String, services_Association? AssociationQ }, dmPrefCache_, default_, service_, model_, state_, serviceSelector_, modelNameSelector_ ] := Enclose[
    With[ { highlight = highlightControl[ Row @ { #1, Spacer[ 1 ], #2 }, "Notebooks", #3 ] & },

        highlightControl[
            Row @
                If[ MatchQ[ type, "Cloud" | "Notebooks" ],
                    {
                        highlight[ tr[ "PreferencesContentLLMServiceLabel" ], Dynamic @ serviceSelector, "ModelService" ],
                        Spacer[ 5 ],
                        highlight[
                            Dynamic[ If[ service === "LLMKit", "", tr[ "PreferencesContentModelLabel" ] ] ],
                            Dynamic[ If[ service === "LLMKit", "",
                                If[ state === "Loading" || MatchQ[ modelNameSelector, _Symbol ], $loadingPopupMenu, modelNameSelector ] ],
                                TrackedSymbols :> { service, state, modelNameSelector }
                            ],
                            "ModelName"
                        ]
                    },
                    {
                        Dynamic[ dmPrefCache[ "Model" ]; serviceSelector ],
                        Spacer[ 24 ],
                        Dynamic[ If[ service === "LLMKit", "", tr[ "PreferencesContentModelLabelAlt" ] ] ],
                        Spacer[ 7 ],
                        Dynamic[
                            If[ state === "Loading" || MatchQ[ modelNameSelector, _Symbol ], $loadingPopupMenu, modelNameSelector ],
                            TrackedSymbols :> { service, state, modelNameSelector }
                        ]
                    }
                ],
            "Notebooks",
            "Model"
        ]

    ],
    throwInternalFailure
];

makeModelSelector0[ failure: HoldPattern @ Failure[ LLMServices`LLMServiceInformation, ___ ] ] :=
    Pane[ failure, ImageSize -> { Scaled[ 0.922 ], Automatic } ];

makeModelSelector0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeServiceSelector*)
makeServiceSelector // beginDefinition;

Attributes[ makeServiceSelector ] = { HoldRest };

makeServiceSelector[ services_, dmPrefCache_, service_, model_, modelNameSelector_, state_ ] :=
    PopupMenu[
        Dynamic[
            extractServiceName @ Lookup[ dmPrefCache, "Model" ],
            Function[ serviceSelectCallback[ #, dmPrefCache, service, model, modelNameSelector, state ] ]
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

Attributes[ serviceSelectCallback ] = { HoldRest };

serviceSelectCallback[
    selected_String, (* The value chosen via PopupMenu *)dmPrefCache_, service_, model_, modelNameSelector_, state_ ] := catchAlways[
    service = selected;

    (* Switch model name selector to loading view: *)
    If[ ! modelListCachedQ @ selected, state = "Loading" ];

    (* Now that a new service has been selected, switch the model name to a previously used value for this service
       if available. If service has not been chosen before, determine the initial model from the registered service. *)
    model = getServiceDefaultModel[ Dynamic @ dmPrefCache, selected ];

    (* Store the service/model in FE settings: *)
    dmPrefCache[ "Model" ] = CurrentChatSettings[ $FrontEnd, "Model" ] = <| "Service" -> service, "Name" -> model |>;

    (* Finish loading the model name selector: *)
    If[ state === "Loading",
            modelNameSelector = makeModelNameSelector[ dmPrefCache, service, model, modelNameSelector, state ];
            state = "Loaded",
        modelNameSelector = makeModelNameSelector[ dmPrefCache, service, model, modelNameSelector, state ]
    ]
];

serviceSelectCallback // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeModelNameSelector*)
makeModelNameSelector // beginDefinition;

Attributes[ makeModelNameSelector ] = { HoldAll };

makeModelNameSelector[ dmPrefCache_, service_, model_, modelNameSelector_, state_ ] := Enclose[
    Catch @ Module[ { models, current, default, fallback },

        ensureServiceName[ service, Dynamic @ dmPrefCache ];
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
                Dynamic @ dmPrefCache,
                Dynamic @ service,
                Dynamic @ model,
                Dynamic @ modelNameSelector,
                Dynamic @ state
            ]
        ];

        If[ models === Missing[ "NoModelList" ],
            Throw @ modelNameInputField[
                Dynamic @ dmPrefCache,
                Dynamic @ service,
                Dynamic @ model,
                Dynamic @ modelNameSelector,
                Dynamic @ state
            ]
        ];

        current  = extractModelName @ CurrentChatSettings[ $FrontEnd, "Model" ];
        default  = ConfirmBy[ getServiceDefaultModel[ Dynamic @ dmPrefCache, service ], StringQ, "DefaultName" ];
        fallback = <| "Service" -> service, "Name" -> default |>;

        If[ ! MemberQ[ models, KeyValuePattern[ "Name" -> current ] ],
            dmPrefCache[ "Model" ] = CurrentChatSettings[ $FrontEnd, "Model" ] = fallback
        ];

        PopupMenu[
            Dynamic[
                extractModelName @ Lookup[ dmPrefCache, "Model" ],
                Function[ modelSelectCallback[ #, dmPrefCache, service, model ] ]
            ],
            Block[ { $noIcons = TrueQ @ $cloudNotebooks },
                Map[ popupValue[ #[ "Name" ], #[ "DisplayName" ], #[ "Icon" ] ] &, models ]
            ],
            ImageSize -> Automatic
        ]
    ],
    throwInternalFailure
];

makeModelNameSelector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*modelNameInputField*)
modelNameInputField // beginDefinition;

modelNameInputField[ Dynamic[ dmPrefCache_ ], Dynamic[ service_ ], Dynamic[ model_ ], Dynamic[ modelNameSelector_ ], Dynamic[ state_ ] ] :=
    prefsInputField[
        None,
        Function[
            dmPrefCache[ "Model" ] = CurrentChatSettings[ $FrontEnd, "Model" ] = #;
            modelSelectCallback[ #, dmPrefCache, service, model ]
        ],
        String,
        Hold @ Replace[ extractModelName @ Lookup[ dmPrefCache, "Model" ], Except[ _String ] :> "" ],
        ImageSize -> { 200, Automatic }
    ];

modelNameInputField // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*serviceConnectButton*)
serviceConnectButton // beginDefinition;

serviceConnectButton[
    Dynamic[ dmPrefCache_ ],
    Dynamic[ service_ ],
    Dynamic[ model_ ],
    Dynamic[ modelNameSelector_ ],
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
                    serviceSelectCallback[ service, dmPrefCache, service, model, modelNameSelector, state ]
                ]
        ],
        Method -> "Queued"
    ];

serviceConnectButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*modelSelectCallback*)
modelSelectCallback // beginDefinition;

Attributes[ modelSelectCallback ] = { HoldRest };

modelSelectCallback[ selected_String(* The value chosen via PopupMenu *), dmPrefCache_, service_, model_ ] := catchAlways @ Enclose[

    ensureServiceName[ service, Dynamic @ dmPrefCache ];
    ConfirmAssert[ StringQ @ service, "ServiceName" ];

    (* LLMKit does not have a model selector, so we always use Automatic for this service: *)
    model = If[ MatchQ[ service, "LLMKit"|"Wolfram"|"Wolfram LLM Kit" ], Automatic, selected ];

    (* Store the service/model in FE settings: *)
    dmPrefCache[ "Model" ] = CurrentChatSettings[ $FrontEnd, "Model" ] = <| "Service" -> service, "Name" -> model |>;

    (* Remember the selected model for the given service, so it will be automatically chosen
       when choosing this service again: *)
    dmPrefCache[ "ServiceDefaultModel" ] = CurrentChatSettings[ $FrontEnd, "ServiceDefaultModel" ] = Append[
        Lookup[ dmPrefCache, "ServiceDefaultModel" ],
        service -> model
    ];
    ,
    throwInternalFailure
];

modelSelectCallback // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeAssistanceCheckbox*)
makeAssistanceCheckbox // beginDefinition;

makeAssistanceCheckbox[ Dynamic[ dmPrefCache_ ] ] :=
    If[ TrueQ @ $cloudNotebooks,
        Nothing,
        highlightControl[
            prefsCheckbox[
                Function[ dmPrefCache[ "Assistance" ] = CurrentChatSettings[ $FrontEnd, "Assistance" ] = # ],
                infoTooltip[
                    tr[ "PreferencesContentEnableAssistanceLabel" ],
                    tr[ "PreferencesContentEnableAssistanceTooltip" ]
                ],
                Hold @ TrueQ @ Lookup[ dmPrefCache, "Assistance" ]
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

makeTemperatureInput[ Dynamic[ dmPrefCache_ ] ] := highlightControl[
    prefsInputField[
        tr[ "PreferencesContentTemperatureLabel" ],
        Function[ dmPrefCache[ "Temperature" ] = CurrentChatSettings[ $FrontEnd, "Temperature" ] = # ],
        Number,
        Hold @ Lookup[ dmPrefCache, "Temperature" ],
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

makeOpenAICompletionURLInput[ Dynamic[ dmPrefCache_ ] ] :=
    makeOpenAICompletionURLInput[ Dynamic @ dmPrefCache, $useLLMServices ];

makeOpenAICompletionURLInput[ _, True ] :=
    Nothing;

makeOpenAICompletionURLInput[ Dynamic[ dmPrefCache_ ], False ] := highlightControl[
    prefsInputField[
        tr[ "PreferencesContentOpenAICompletionURLLabel" ],
        Function[ dmPrefCache[ "OpenAIAPICompletionURL" ] = CurrentChatSettings[ $FrontEnd, "OpenAIAPICompletionURL" ] = # ],
        String,
        Hold @ Lookup[ dmPrefCache, "OpenAIAPICompletionURL" ],
        ImageSize -> { 200, Automatic }
    ],
    "Notebooks",
    "OpenAIAPICompletionURL"
];

makeOpenAICompletionURLInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeInstructionsContent*)
makeInstructionsContent // beginDefinition;

makeInstructionsContent[ Dynamic[ dmPrefCache_ ] ] :=
    DynamicModule[ { initialText, currentText, modified },
        Column[
            {
                tr[ "PreferencesContentInstructionsDescription" ],
                EventHandler[
                    Pane[
                        prefsInputField[
                            None,
                            Function[
                                currentText = If[ # === "", Null, # ];
                                modified = currentText =!= initialText;
                            ],
                            String,
                            Hold[
                                initialText = Replace[
                                    Lookup[ dmPrefCache, "UserInstructions" ],
                                    "" | Except[ _String ] -> Null
                                ];
                                currentText = initialText;
                                modified = False;
                                initialText
                            ],
                            ContinuousAction -> True,
                            FieldHint        -> tr[ "PreferencesContentInstructionsHint" ],
                            ImageSize        -> { Scaled[ 1 ], Automatic },
                            BaseStyle        -> {
                                "controlText",
                                AutoSpacing -> False,
                                FontColor   -> color @ "PreferencesContentFont_2",
                                FontSize    -> 13
                            }
                        ],
                        AppearanceElements -> { },
                        FrameMargins       -> { { 0, 0 }, { 0, 0 } },
                        ImageSize          -> { Scaled[ 1 ], UpTo[ 200 ] },
                        ImageMargins       -> 0,
                        Scrollbars         -> { Automatic, Automatic }
                    ],
                    { "ReturnKeyDown" :> FrontEndExecute @ { NotebookWrite[ InputNotebook[ ], "\n", After ] } }
                ],
                PaneSelector[
                    {
                        True -> ChoiceButtons[
                            {
                                tr[ "SaveChangesButton" ],
                                tr[ "CancelButton" ]
                            },
                            {
                                dmPrefCache[ "UserInstructions" ] = CurrentChatSettings[ $FrontEnd, "UserInstructions" ] =
                                    If[ StringQ @ currentText && StringTrim @ currentText =!= "",
                                        currentText,
                                        Inherited
                                    ];

                                initialText = currentText;
                                modified    = False;
                                ,
                                currentText = initialText;
                                modified    = False;
                            }
                        ],
                        False -> Spacer[ 1 ]
                    },
                    Dynamic @ modified,
                    ImageSize -> Automatic
                ]
            }
        ]
    ];

makeInstructionsContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeInterfaceContent*)
makeInterfaceContent // beginDefinition;

makeInterfaceContent[ Dynamic[ dmPrefCache_ ] ] := Enclose[
    Module[ { formatCheckbox, includeHistory, chatHistoryLength, mergeMessages },

        formatCheckbox    = ConfirmMatch[ makeFormatCheckbox[ Dynamic @ dmPrefCache ]        , _Style, "FormatCheckbox"    ];
        includeHistory    = ConfirmMatch[ makeIncludeHistoryCheckbox[ Dynamic @ dmPrefCache ], _Style, "ChatHistory"       ];
        chatHistoryLength = ConfirmMatch[ makeChatHistoryLengthInput[ Dynamic @ dmPrefCache ], _Style, "ChatHistoryLength" ];
        mergeMessages     = ConfirmMatch[ makeMergeMessagesCheckbox[ Dynamic @ dmPrefCache ] , _Style, "MergeMessages"     ];

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

makeFormatCheckbox[ Dynamic[ dmPrefCache_ ] ] := highlightControl[
    prefsCheckbox[
        Function[ dmPrefCache[ "AutoFormat" ] = CurrentChatSettings[ $FrontEnd, "AutoFormat" ] = # ],
        tr[ "PreferencesContentFormatOutputLabel" ],
        Hold @ TrueQ @ Lookup[ dmPrefCache, "AutoFormat" ]
    ],
    "Notebooks",
    "AutoFormat"
];

makeFormatCheckbox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeIncludeHistoryCheckbox*)
makeIncludeHistoryCheckbox // beginDefinition;

makeIncludeHistoryCheckbox[ Dynamic[ dmPrefCache_ ] ] := highlightControl[
    prefsCheckbox[
        Function[ dmPrefCache[ "IncludeHistory" ] = CurrentChatSettings[ $FrontEnd, "IncludeHistory" ] = # ],
        infoTooltip[ tr[ "PreferencesContentIncludeHistoryLabel" ], tr[ "PreferencesContentIncludeHistoryTooltip" ] ],
        Hold @ MatchQ[ Lookup[ dmPrefCache, "IncludeHistory" ], True|Automatic ]
    ],
    "Notebooks",
    "IncludeHistory"
];

makeIncludeHistoryCheckbox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeChatHistoryLengthInput*)
makeChatHistoryLengthInput // beginDefinition;

makeChatHistoryLengthInput[ Dynamic[ dmPrefCache_ ] ] := highlightControl[
    infoTooltip[
        prefsInputField[
            tr[ "PreferencesContentHistoryLengthLabel" ],
            Function[
                If[ NumberQ @ # && NonNegative @ #,
                    dmPrefCache[ "ChatHistoryLength" ] = CurrentChatSettings[ $FrontEnd, "ChatHistoryLength" ] = Floor[ # ]
                ]
            ],
            Number,
            Hold @ Lookup[ dmPrefCache, "ChatHistoryLength" ], (* initial value *)
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

makeMergeMessagesCheckbox[ Dynamic[ dmPrefCache_ ] ] := highlightControl[
    prefsCheckbox[
        Function[ dmPrefCache[ "MergeMessages" ] = CurrentChatSettings[ $FrontEnd, "MergeMessages" ] = # ],
        infoTooltip[ tr[ "PreferencesContentMergeChatLabel" ], tr[ "PreferencesContentMergeChatTooltip" ] ],
        Hold @ MatchQ[ Lookup[ dmPrefCache, "MergeMessages" ], True|Automatic ]
    ],
    "Notebooks",
    "MergeMessages"
];

makeMergeMessagesCheckbox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeFeaturesContent*)
makeFeaturesContent // beginDefinition;

makeFeaturesContent[ Dynamic[ dmPrefCache_ ] ] := Enclose[
    Module[ { multimodal, toolsEnabled, toolFrequency },

        multimodal    = ConfirmMatch[ makeMultimodalMenu[ Dynamic @ dmPrefCache ]           , _Style, "Multimodal"    ];
        toolsEnabled  = ConfirmMatch[ makeToolsEnabledMenu[ Dynamic @ dmPrefCache ]         , _Style, "ToolsEnabled"  ];
        toolFrequency = ConfirmMatch[ makeToolCallFrequencySelector[ Dynamic @ dmPrefCache ], _Style, "ToolFrequency" ];

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

makeMultimodalMenu[ Dynamic[ dmPrefCache_ ] ] := highlightControl[
    Grid[
        {
            {
                Style[ tr[ "PreferencesContentEnableMultimodalLabel" ], "leadinText", FontColor -> color @ "PreferencesContentFont_2" ],
                prefsPopupMenu[
                    Function[ dmPrefCache[ "Multimodal" ] = CurrentChatSettings[ $FrontEnd, "Multimodal" ] = # ],
                    {
                        Automatic -> tr[ "EnabledByModel" ],
                        True      -> tr[ "EnabledAlways"  ],
                        False     -> tr[ "EnabledNever"   ]
                    },
                    Hold @ Replace[ Lookup[ dmPrefCache, "Multimodal" ], Except[ Automatic|True|False ] -> Automatic ],
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

makeToolsEnabledMenu[ Dynamic[ dmPrefCache_ ] ] := highlightControl[
    Grid[
        {
            {
                Style[ tr[ "PreferencesContentEnableTools" ], "leadinText", FontColor -> color @ "PreferencesContentFont_2" ],
                prefsPopupMenu[
                    Function[ dmPrefCache[ "ToolsEnabled" ] = CurrentChatSettings[ $FrontEnd, "ToolsEnabled" ] = # ],
                    {
                        Automatic -> tr[ "EnabledByModel" ],
                        True      -> tr[ "EnabledAlways"  ],
                        False     -> tr[ "EnabledNever"   ]
                    },
                    Hold @ Replace[ Lookup[ dmPrefCache, "ToolsEnabled" ], Except[ Automatic|True|False ] -> Automatic ],
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

makeToolCallFrequencySelector[ Dynamic[ dmPrefCache_ ] ] := highlightControl[
    DynamicModule[ { type, frequency },
        Grid[
            {
                {
                    Style[ tr[ "PreferencesContentToolCallFrequency" ], "leadinText", FontColor -> color @ "PreferencesContentFont_2" ],
                    PopupMenu[
                        Dynamic[
                            type,
                            Function[
                                If[ # === Automatic
                                    ,
                                    type = Automatic;
                                    dmPrefCache[ "ToolCallFrequency" ] = CurrentChatSettings[ $FrontEnd, "ToolCallFrequency" ] = Automatic
                                    ,
                                    type = "Custom";
                                    dmPrefCache[ "ToolCallFrequency" ] = CurrentChatSettings[ $FrontEnd, "ToolCallFrequency" ] = 0.5
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
                                            Dynamic[
                                                frequency,
                                                {
                                                    Function[ frequency = # ],
                                                    Function[
                                                        dmPrefCache[ "ToolCallFrequency" ] = CurrentChatSettings[ $FrontEnd, "ToolCallFrequency" ] = #;
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
        Initialization :> 
            With[ { val = Lookup[ dmPrefCache, "ToolCallFrequency" ] },
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

Attributes[ servicesSettingsPanel ] = { HoldAll };

servicesSettingsPanel[ dmPrefCache_, default_, service_, model_, state_, serviceSelector_, modelNameSelector_ ] := Catch[
    disabledAIOverlay[
        servicesSettingsPanel0[ dmPrefCache, default, service, model, state, serviceSelector, modelNameSelector ],
        FE`Evaluate @ FEPrivate`LocalAIOnlyQ[ ]
    ]
    ,
    $servicesSettingsTag
];

servicesSettingsPanel // endDefinition;

servicesSettingsPanel0 // beginDefinition;

Attributes[ servicesSettingsPanel0 ] = { HoldAll };

servicesSettingsPanel0[ dmPrefCache_, default_, service_, model_, state_, serviceSelector_, modelNameSelector_ ] := Enclose[
    Module[ { llmIcon, llmHelp, llmLabel, llmPanel, serviceCollapsibleSection, serviceGrid, settingsLabel, settings },

        llmLabel      = subsectionText @ tr[ "PreferencesContentLLMKitTitle" ];
        llmPanel      = LogChatTiming[ makeLLMPanel[ ], "PrefLLMPanel" ];
        serviceGrid   = LogChatTiming[ makeServiceGrid[ Dynamic @ dmPrefCache ], "PrefServiceGrid" ];
        settingsLabel = subsectionText @ tr[ "PreferencesContentDefaultService" ];
        settings      = LogChatTiming[
            (* ConfirmMatch[ *)
                makeModelSelector[ "Services", dmPrefCache, default, service, model, state, serviceSelector, modelNameSelector ](* ,
                _DynamicModule,
                "ServicesSettings"
            ] *),
            "PrefModelSelector"
        ];

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
                    Dynamic @ Typeset`openQ,
                    BaselinePosition -> Baseline,
                    ImageSize        -> Automatic
                ],
                Initialization   :> None, (* needed for Deinitialization to run *)
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

        upgradeToProOrResearchButton =
            Button[
                Style[
                    StringReplace[
                        FrontEndResource[ "ChatbookStrings", "PreferencesContentLLMKitUpgradePro" ],
                        {
                            "`SubscriptionLevelPro`"      :> ToString[ Style[ "Pro",      FontWeight -> "Bold" ], StandardForm ],
                            "`SubscriptionLevelResearch`" :> ToString[ Style[ "Research", FontWeight -> "Bold" ], StandardForm ]
                        }
                    ],
                    FontColor -> (Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[
                        color @ "PreferencesContentFont_1",
                        color @ "PreferencesContentFont_3" ])
                ],
                Wolfram`LLMFunctions`Common`OpenLLMKitURL @ "Manage",
                Appearance -> "Suppressed",
                BaseStyle  -> "DialogTextCommon",
                Method     -> "Queued",
                ImageSize  -> Automatic ];

        upgradeToResearchButton =
            Button[
                Style[
                    StringReplace[
                        FrontEndResource[ "ChatbookStrings", "PreferencesContentLLMKitUpgradeResearch" ],
                        "`SubscriptionLevelResearch`" :> ToString[ Style[ "Research", FontWeight -> "Bold" ], StandardForm ]
                    ],
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
                                            {
                                                chatbookExpression[ "CheckmarkGreen" ],
                                                Style[
                                                    Dynamic @ StringReplace[
                                                        FrontEndResource[ "ChatbookStrings", "PreferencesContentLLMKitEnabledTitle" ],
                                                        "`SubscriptionLevel`" :>
                                                            FrontEndResource[
                                                                "ChatbookStrings",
                                                                Switch[ Wolfram`Chatbook`ChatModes`UI`Private`$assistantTier,
                                                                    "Basic",    "SubscriptionLevelBasic",
                                                                    "Pro",      "SubscriptionLevelPro",
                                                                    "Research", "SubscriptionLevelResearch"
                                                                ]
                                                            ]
                                                    ],
                                                    FontColor -> color @ "PreferencesContentFont_1" ] },
                                            {
                                                "",
                                                PaneSelector[
                                                    {
                                                        "Basic"    -> upgradeToProOrResearchButton,
                                                        "Pro"      -> upgradeToResearchButton,
                                                        "Research" -> manageButton
                                                    },
                                                    Dynamic @ Wolfram`Chatbook`ChatModes`UI`Private`$assistantTier,
                                                    ImageSize -> Automatic
                                                ]
                                            }
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

makeServiceGrid[ Dynamic[ dmPrefCache_ ] ] :=
DynamicModule[ { display = ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ] },
    Framed[
        Pane[
            Dynamic @ display,
            AppearanceElements -> { },
            FrameMargins -> 8,
            Scrollbars -> { False, Automatic },
            ImageSize -> { Scaled[ 1 ], UpTo[ 150 ] }
        ],
        Background -> color @ "PreferencesContentBackground",
        FrameMargins -> 0,
        FrameStyle -> color @ "PreferencesContentFrame",
        ImageSize -> Scaled[ 1 ],
        RoundingRadius -> 3
    ],
    Initialization :> (display =
        Grid[
            KeyValueMap[ makeServiceGridRow[ Dynamic @ dmPrefCache, #1, #2 ]&, DeleteCases[ $availableServices, KeyValuePattern[ "Hidden" -> True ] ] ],
            Alignment  -> { Left, Baseline },
            Background -> { { }, { { color @ "PreferencesContentBackground" } } },
            ItemSize   -> { { Automatic, Automatic, Scaled[ 0.3 ], Fit, Automatic }, Automatic },
            Dividers   -> { { }, { False, { True }, False } },
            FrameStyle -> color @ "PreferencesContentDirectServiceConnectionsDelimiter",
            Spacings   -> { Automatic, 0.7 }
        ]
    ),
    SynchronousInitialization -> False
]

makeServiceGrid // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeServiceGridRow*)
makeServiceGridRow // beginDefinition;

makeServiceGridRow[ Dynamic[ dmPrefCache_ ], name_String, data_Association ] := {
    makeServiceAuthenticationDisplay[ Dynamic @ dmPrefCache, name, resizeMenuIcon @ inlineChatbookExpressions @ serviceIcon @ data ]
};

makeServiceGridRow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deleteServiceButton*)
deleteServiceButton // beginDefinition;

deleteServiceButton[ _, "OpenAI" ] := Framed[
    Button[
        chatbookExpression[ "ToolManagerBin", color @ "PreferencesContentServicesDeleteIconAlt" ],
        Null,
        Enabled -> False,
        $deleteServiceButtonOptions
    ],
    $deleteServiceButtonFrameOptions
];

deleteServiceButton[ Dynamic[ dmPrefCache_ ], service_String ] := Tooltip[
    Framed[
        Button[
            $trashBin,
            Needs[ "LLMServices`" -> None ];
            LLMServices`UnregisterService @ service;
            disconnectService[ Dynamic @ dmPrefCache, service ];
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

makeServiceAuthenticationDisplay[ Dynamic[ dmPrefCache_ ], service_String, icon_ ] :=
    DynamicModule[ { display },
        display = ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ];
        Dynamic[ display, TrackedSymbols :> { display } ],
        Initialization :> createServiceAuthenticationDisplay[ Dynamic @ dmPrefCache, service, icon, Dynamic[ display ] ],
        SynchronousInitialization -> False
    ];

makeServiceAuthenticationDisplay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*createServiceAuthenticationDisplay*)
createServiceAuthenticationDisplay // beginDefinition;

createServiceAuthenticationDisplay[ Dynamic[ dmPrefCache_ ], service_, icon_, Dynamic[ display_ ] ] := Enclose[
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
                    Pane[ "", ImageSize -> Scaled[ 1. ] ],
                    connectOrDisconnectButton[ Dynamic @ dmPrefCache, service, type, icon, Dynamic @ display ]
                }
            },
            Alignment -> { Left, Baseline },
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

connectOrDisconnectButton[ Dynamic[ dmPrefCache_ ], service_String, "None", icon_, Dynamic[ display_ ] ] :=
    Button[
        tr[ "ConnectButton" ],
        display = ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ];
        clearConnectionCache[ service, False ];
        Quiet[
            Wolfram`LLMFunctions`APIs`Common`ConnectToService @ service
        ];
        createServiceAuthenticationDisplay[ Dynamic @ dmPrefCache, service, icon, Dynamic @ display ],
        Method -> "Queued"
    ];

connectOrDisconnectButton[ Dynamic[ dmPrefCache_ ], service_String, "SystemCredential"|"Environment"|"ServiceConnect", icon_, Dynamic[ display_ ] ] :=
    Button[
        tr[ "DisconnectButton" ],
        display = ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ];
        disconnectService[ Dynamic @ dmPrefCache, service ];
        createServiceAuthenticationDisplay[ Dynamic @ dmPrefCache, service, icon, Dynamic @ display ],
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

personaSettingsPanel[ Dynamic[ dmPrefCache_ ] ] :=
    DynamicModule[
        { display = ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ] },
        Dynamic @ display,
        Initialization            :> (display = disabledAIOverlay[ CreatePersonaManagerPanel[ ], FE`Evaluate @ FEPrivate`LocalAIOnlyQ[ ] ]),
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

(* CreateLLMToolManagerPanel manages scope by itself; no need to pass cached global prefs to it *)
toolSettingsPanel[ Dynamic[ dmPrefCache_ ] ] :=
    DynamicModule[
        { display = ProgressIndicator[ Appearance -> { "Percolate", color @ "PreferencesContentProgressIndicator" } ] },
        Dynamic @ display,
        Initialization            :> (display = disabledAIOverlay[ CreateLLMToolManagerPanel[ "GlobalScopeOnly" -> True ], FE`Evaluate @ FEPrivate`LocalAIOnlyQ[ ] ]),
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

prefsInputField[ None, update_Function, type_, Hold[ initialValue_ ], opts: OptionsPattern[ ] ] :=
    prefsInputField0[ update, type, Hold @ initialValue, opts ];

prefsInputField[ label_, update_Function, type_, Hold[ initialValue_ ], opts: OptionsPattern[ ] ] := Grid[
    { { label, prefsInputField0[ update, type, Hold @ initialValue, opts ] } },
    Alignment -> { Automatic, Baseline },
    BaseStyle -> { "leadinText", FontColor -> color @ "PreferencesContentFont_2" },
    Spacings  -> 0.5
];

prefsInputField // endDefinition;


prefsInputField0 // beginDefinition;

(* "InputFieldAppearance:RoundedFrame" TemplateBox definition in Core.nb is not flexible enough, so modify it here *)
prefsInputField0[ Function[ args___ ], type_, Hold[ initialValue_ ], opts: OptionsPattern[ ] ] :=
DynamicModule[ { localValue },
    Framed[
        InputField[ Dynamic[ localValue, Function[ localValue = #; args ] ], type,
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
    ],
    Initialization            :> (localValue = initialValue),
    SynchronousInitialization -> False
];

prefsInputField0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*prefsCheckbox*)
prefsCheckbox // beginDefinition;

prefsCheckbox[ Function[ args___ ], label_, Hold[ initialValue_ ], rest___ ] :=
DynamicModule[ { localValue = None },
    Grid[
        { {
            Checkbox[ Dynamic[ localValue, Function[ localValue = #; args ] ], rest ],
            Toggler[
                Dynamic[ localValue, Function[ localValue = #; args ] ],
                { True -> label, False -> label },
                BaselinePosition -> Scaled[ 0.2 ],
                BaseStyle        -> { "checkboxText", FontColor -> color @ "PreferencesContentFont_2" }
            ]
        } },
        Alignment -> { Left, Center },
        Spacings  -> 0.2
    ],
    Initialization :> (localValue = initialValue)
];

prefsCheckbox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*prefsPopupMenu*)
prefsPopupMenu // beginDefinition;

prefsPopupMenu[ Function[ args___ ], choices_, Hold[ initialValue_ ], rest___ ] :=
DynamicModule[ { localValue = None },
    PopupMenu[
        Dynamic[ localValue, Function[ localValue = #; args ] ],
        choices,
        rest ],
    Initialization :> (localValue = initialValue)
];

prefsPopupMenu // endDefinition;

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

ensureServiceName[ symbol_Symbol, Dynamic[ dmPrefCache_ ] ] :=
    With[ { service = symbol },
        service /; StringQ @ service
    ];

ensureServiceName[ symbol_Symbol, Dynamic[ dmPrefCache_ ] ] :=
    With[ { service = extractServiceName @ Lookup[ dmPrefCache, "Model" ] },
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

getServiceDefaultModel[ Dynamic[ dmPrefCache_ ], "LLMKit"|"Wolfram"|"Wolfram LLM Kit"|"Wolfram AI Services" ] := Automatic;

getServiceDefaultModel[ Dynamic[ dmPrefCache_ ], service_String ] := Enclose[
    Module[ { lastSelected, name },
        (* Get last selected models by service: *)
        lastSelected = Replace[
            Association @ Lookup[ dmPrefCache, "ServiceDefaultModel" ],
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
            dmPrefCache[ "ServiceDefaultModel" ] = CurrentChatSettings[ $FrontEnd, "ServiceDefaultModel" ] = lastSelected;
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

disconnectService[ Dynamic[ dmPrefCache_ ], service_String ] :=
    With[ { key = credentialKey @ service },
        Unset @ SystemCredential @ key;
        SetEnvironment[ key -> None ];
        clearConnectionCache @ service;
        If[ extractServiceName @ Lookup[ dmPrefCache, "Model" ] === service,
            dmPrefCache[ "Model" ] = CurrentChatSettings[ $FrontEnd, "Model" ] = $DefaultModel
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
(*resetButton*)
resetButton[ Dynamic[ tab_ ], Dynamic[ dmPrefCache_ ] ] :=
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

        Button[
            label,

            Needs[ "Wolfram`Chatbook`" -> None ];
            resetChatPreferences[ Dynamic @ dmPrefCache, Replace[ tab, $$unspecified -> "Services" ] ]
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

resetChatPreferences[ Dynamic[ dmPrefCache_ ], "Notebooks" ] := (
    CurrentChatSettings[ $FrontEnd ] = Inherited;
    dmPrefCache = CurrentChatSettings[ $FrontEnd ];
    updateDynamics[ "Preferences" ];
);

resetChatPreferences[ Dynamic[ dmPrefCache_ ], "Personas" ] := (
    (* TODO: choice dialog to uninstall personas *)
    dmPrefCache[ "VisiblePersonas"  ] = CurrentChatSettings[ $FrontEnd, "VisiblePersonas"  ] = $corePersonaNames;
    dmPrefCache[ "PersonaFavorites" ] = CurrentChatSettings[ $FrontEnd, "PersonaFavorites" ] = $corePersonaNames;
    updateDynamics[ "Personas" ];
);

resetChatPreferences[ Dynamic[ dmPrefCache_ ], "Tools" ] := (
    CurrentChatSettings[ $FrontEnd, "ToolSelectionType" ] = Inherited;
    CurrentChatSettings[ $FrontEnd, "ToolSelections"    ] = Inherited;
    dmPrefCache[ "ToolSelectionType" ] = CurrentChatSettings[ $FrontEnd, "ToolSelectionType" ];
    dmPrefCache[ "ToolSelections"    ] = CurrentChatSettings[ $FrontEnd, "ToolSelections"    ];
    (* TODO: choice dialog to uninstall tools *)
    updateDynamics[ "Tools" ];
);

resetChatPreferences[ Dynamic[ dmPrefCache_ ], "Services" ] := (
    (* TODO: choice dialog to clear service connections *)
    CurrentChatSettings[ $FrontEnd, "Model" ] = Inherited;
    CurrentChatSettings[ $FrontEnd, "ServiceDefaultModel" ] = Inherited;
    dmPrefCache[ "Model" ] = CurrentChatSettings[ $FrontEnd, "Model" ];
    dmPrefCache[ "ServiceDefaultModel" ] = CurrentChatSettings[ $FrontEnd, "ServiceDefaultModel" ];
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
