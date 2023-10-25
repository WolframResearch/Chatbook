(* ::Package:: *)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::NoVariables::Module:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

BeginPackage["Wolfram`Chatbook`UI`"]

(* Avoiding context aliasing due to bug 434990: *)
Needs[ "GeneralUtilities`" -> None ];

MakeChatInputActiveCellDingbat
MakeChatInputCellDingbat
MakeChatDelimiterCellDingbat
MakeChatCloudDockedCellContents

GeneralUtilities`SetUsage[CreatePreferencesContent, "
CreatePreferencesContent[] returns an expression containing the UI shown in the Preferences > AI Settings window.
"]

GeneralUtilities`SetUsage[CreateToolbarContent, "
CreateToolbarContent[] is called by the NotebookToolbar to generate the content of the 'Notebook AI Settings' attached menu.
"]

`getPersonaIcon;
`getPersonaMenuIcon;
`personaDisplayName;
`resizeMenuIcon;


Begin["`Private`"]

Needs[ "Wolfram`Chatbook`"                      ];
Needs[ "Wolfram`Chatbook`Actions`"              ];
Needs[ "Wolfram`Chatbook`Common`"               ];
Needs[ "Wolfram`Chatbook`Dynamics`"             ];
Needs[ "Wolfram`Chatbook`Errors`"               ];
Needs[ "Wolfram`Chatbook`ErrorUtils`"           ];
Needs[ "Wolfram`Chatbook`FrontEnd`"             ];
Needs[ "Wolfram`Chatbook`Menus`"                ];
Needs[ "Wolfram`Chatbook`Models`"               ];
Needs[ "Wolfram`Chatbook`Personas`"             ];
Needs[ "Wolfram`Chatbook`PreferencesUtils`"     ];
Needs[ "Wolfram`Chatbook`Serialization`"        ];
Needs[ "Wolfram`Chatbook`Settings`"             ];
Needs[ "Wolfram`Chatbook`Utils`"                ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$chatMenuWidth = 260;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cloud Toolbar*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MakeChatCloudDockedCellContents*)
MakeChatCloudDockedCellContents[] := Grid[
	{{
		Item[$cloudChatBanner, Alignment -> Left],
		Item["", ItemSize -> Fit],
		Row[{"Persona", Spacer[5], trackedDynamic[$cloudPersonaChooser, "Personas"]}],
		Row[{"Model", Spacer[5], trackedDynamic[$cloudModelChooser, "Models"]}]
	}},
	Dividers -> {{False, False, False, True}, False},
	Spacings -> {2, 0},
	BaseStyle -> {"Text", FontSize -> 14, FontColor -> GrayLevel[0.4]},
	FrameStyle -> Directive[Thickness[2], GrayLevel[0.9]]
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$cloudPersonaChooser*)
$cloudPersonaChooser := PopupMenu[
	Dynamic[
		Replace[
			CurrentValue[EvaluationNotebook[], {TaggingRules, "ChatNotebookSettings", "LLMEvaluator"}],
			Inherited :> Lookup[$defaultChatSettings, "LLMEvaluator", "CodeAssistant"]
		],
		Function[CurrentValue[EvaluationNotebook[], {TaggingRules, "ChatNotebookSettings", "LLMEvaluator"}] = #]
	],
	KeyValueMap[
		Function[{key, as}, key -> Grid[{{resizeMenuIcon[getPersonaMenuIcon[as]], personaDisplayName[key, as]}}]],
		GetCachedPersonaData[]
	],
	ImageSize -> {Automatic, 30},
	Alignment -> {Left, Baseline},
	BaseStyle -> {FontSize -> 12}
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$cloudModelChooser*)
$cloudModelChooser := PopupMenu[
	Dynamic[
		Replace[
			CurrentValue[EvaluationNotebook[], {TaggingRules, "ChatNotebookSettings", "Model"}],
			Inherited :> Lookup[$defaultChatSettings, "Model", "gpt-3.5-turbo"]
		],
		Function[CurrentValue[EvaluationNotebook[], {TaggingRules, "ChatNotebookSettings", "Model"}] = #]
	],
	KeyValueMap[
		{modelName, settings} |-> (
			modelName -> Grid[{{getModelMenuIcon[settings], modelDisplayName[modelName]}}]
		),
		getModelsMenuItems[]
	],
	ImageSize -> {Automatic, 30},
	Alignment -> {Left, Baseline},
	BaseStyle -> {FontSize -> 12}
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$cloudChatBanner*)
$cloudChatBanner := PaneSelector[
    {
        True -> Grid[
			{
				{
					"",
					chatbookIcon[ "ChatDrivenNotebookIcon", False ],
					Style[
						"Chat-Driven Notebook",
						FontColor  -> RGBColor[ "#333333" ],
						FontFamily -> "Source Sans Pro",
						FontSize   -> 16,
						FontWeight -> "DemiBold"
					]
				}
			},
			Alignment -> { Automatic, Center },
			Spacings  -> 0.5
		],
        False -> Grid[
			{
				{
					"",
					chatbookIcon[ "ChatEnabledNotebookIcon", False ],
					Style[
						"Chat-Enabled Notebook",
						FontColor  -> RGBColor[ "#333333" ],
						FontFamily -> "Source Sans Pro",
						FontSize   -> 16,
						FontWeight -> "DemiBold"
					]
				}
			},
			Alignment -> { Automatic, Center },
			Spacings  -> 0.5
		]
    },
    Dynamic @ TrueQ @ CurrentValue[
		EvaluationNotebook[ ],
		{ TaggingRules, "ChatNotebookSettings", "ChatDrivenNotebook" }
	],
    ImageSize -> Automatic
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Preferences Panel*)
CreatePreferencesContent[] := Module[{
	personas = GetPersonasAssociation[],
	chatbookSettings,
	llmEvaluatorNamesSettings,
	services,
	grid
},

	llmEvaluatorNamesSettings = Grid[
		Prepend[
			KeyValueMap[
				{persona, personaSettings} |-> {
					resizeMenuIcon @ getPersonaMenuIcon[personaSettings, "Full"],
					personaDisplayName[persona, personaSettings],
					Replace[Lookup[personaSettings, "Description", None], {
						None | _?MissingQ -> "",
						desc_?StringQ :> desc,
						other_ :> (
							ChatbookWarning[
								"Unexpected non-String persona `` description: ``",
								InputForm[persona],
								InputForm[other]
							];
							other
						)
					}]
				},
				personas
			],
			{"", "Name", "Description"}
		],
		Background -> {None, {1 -> GrayLevel[0.95]}},
		Dividers -> {False, {False, {1 -> True, 2 -> True}}},
		Alignment -> {Left, Center}
	];

	chatbookSettings = makeFrontEndAndNotebookSettingsContent[$FrontEnd];

	(* services = Grid[{
			{""									, "Name"	, "State" 						},
			{chatbookIcon["OpenAILogo", False]	, "OpenAI"	, "<Connected>" 				},
			{""									, "Bard"	, Style["Coming soon", Italic]	},
			{""									, "Claude"	, Style["Coming soon", Italic]	}
		},
		Background -> {None, {1 -> GrayLevel[0.95]}},
		Dividers -> {False, {False, {1 -> True, 2 -> True}}},
		Alignment -> {Left, Center}
	]; *)

	(*-----------------------------------------*)
	(* Return the complete settings expression *)
	(*-----------------------------------------*)

	PreferencesPane[
		{
			PreferencesSection[
				Style[tr["Chat Notebook Interface"], "subsectionText"],
				chatbookSettings
			],
			PreferencesSection[
				Style[tr["Installed Personas"], "subsectionText"],
				llmEvaluatorNamesSettings
			]
			(* PreferencesSection[
				Style[tr["LLM Service Providers"], "subsectionText"],
				services
			] *)
		},
		PreferencesResetButton[
			FrontEndExecute @ FrontEnd`RemoveOptions[$FrontEnd, {
				System`LLMEvaluator,
				{TaggingRules, "ChatNotebookSettings"}
			}];

			CurrentValue[
				$FrontEnd,
				{
					PrivateFrontEndOptions,
					"InterfaceSettings",
					"ChatNotebooks"
				}
			] = Inherited;
		]
	]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Default Notebook Toolbar*)
CreateToolbarContent[] := With[{
	nbObj = EvaluationNotebook[],
	menuCell = EvaluationCell[]
},
	CurrentValue[menuCell, {TaggingRules, "IsChatEnabled"}] =
		TrueQ[CurrentValue[nbObj, {StyleDefinitions, "ChatInput", Evaluatable}]];

	PaneSelector[
		{
			True :> (
				Dynamic @ Refresh[
					Column[{
						Pane[
							makeEnableAIChatFeaturesLabel[True],
							ImageMargins -> {{5, 20}, {2.5, 2.5}}
						],

						Pane[
							makeAutomaticResultAnalysisCheckbox[EvaluationNotebook[]],
							ImageMargins -> {{5, 20}, {2.5, 2.5}}
						],

						makeChatActionMenu[
							"Toolbar",
							EvaluationNotebook[],
							Automatic
						]
					}],
					None
				]
			),
			False :> (
				Dynamic @ Refresh[
					createChatNotEnabledToolbar[nbObj, menuCell],
					None
				]
			)
		},
		Dynamic @ CurrentValue[menuCell, {TaggingRules, "IsChatEnabled"}],
		ImageSize -> Automatic
	]
]

(*====================================*)

SetFallthroughError[createChatNotEnabledToolbar]

createChatNotEnabledToolbar[
	nbObj_NotebookObject,
	menuCell_CellObject
] := Module[{
	button
},
	button = EventHandler[
		makeEnableAIChatFeaturesLabel[False],
		"MouseClicked" :> (
			tryMakeChatEnabledNotebook[nbObj, menuCell]
		),
		(* Needed so that we can open a ChoiceDialog if required. *)
		Method -> "Queued"
	];

	Pane[button, {$chatMenuWidth, Automatic}]
]

(*====================================*)

SetFallthroughError[tryMakeChatEnabledNotebook]

tryMakeChatEnabledNotebook[
	nbObj_NotebookObject,
	menuCell_CellObject
] := Module[{
	useChatbookStylesheet
},
	useChatbookStylesheet = ConfirmReplace[CurrentValue[nbObj, StyleDefinitions], {
		"Default.nb" -> True,
		(* TODO: Generate a warning dialog in this case, because Chatbook.nb
			inherits from Default.nb? *)
		_?StringQ | _FrontEnd`FileName -> True,
		_ :> RaiseConfirmMatch[
			ChoiceDialog[
				Column[{
					Item[Magnify["\[WarningSign]", 5], Alignment -> Center],
					"",
					RawBoxes @ Cell[
						"Enabling Chat Notebook functionality will destroy the" <>
						" private styles defined in this notebook, and replace" <>
						" them with the shared Chatbook stylesheet.",
						"Text"
					],
					"",
					RawBoxes @ Cell["Are you sure you wish to continue?", "Text"]
				}],
				Background -> White,
				WindowMargins -> ConfirmReplace[
					MousePosition["ScreenAbsolute"],
					{x_, y_} :> {{x, Automatic}, {Automatic, y}}
				]
			],
			_?BooleanQ
		]
	}];

	RaiseAssert[BooleanQ[useChatbookStylesheet]];

	If[!useChatbookStylesheet,
		Return[Null, Module];
	];

	SetOptions[nbObj, StyleDefinitions -> "Chatbook.nb"];

	(* Cause the PaneSelector to switch to showing all the options allowed
		for Chat-Enabled notebooks. *)
	CurrentValue[menuCell, {TaggingRules, "IsChatEnabled"}] = True;
]

(*====================================*)

SetFallthroughError[makeEnableAIChatFeaturesLabel]

makeEnableAIChatFeaturesLabel[enabled_?BooleanQ] :=
	labeledCheckbox[enabled, "Enable AI Chat Features", !enabled]

(*====================================*)

SetFallthroughError[makeAutomaticResultAnalysisCheckbox]

makeAutomaticResultAnalysisCheckbox[
	target : $FrontEnd | $FrontEndSession | _NotebookObject
] := With[{
	setterFunction = ConfirmReplace[target, {
		$FrontEnd | $FrontEndSession :> (
			Function[{newValue},
				CurrentValue[
					target,
					{TaggingRules, "ChatNotebookSettings", "Assistance"}
				] = newValue;
			]
		),
		nbObj_NotebookObject :> (
			Function[{newValue},
				(* If the new value is the same as the value inherited from the
				   parent scope, then set the value at the current level to
				   inherit from the parent.

				   Otherwise, if the new value differs from what would be
				   inherited from the parent, then override it at the current
				   level.

				   The consequence of this behavior is that the notebook-level
				   setting for Result Analysis will follow the global setting
				   _if_ the local value is clicked to set it equal to the global
				   setting.
				 *)
				If[
					SameQ[
						newValue,
						AbsoluteCurrentValue[
							$FrontEndSession,
							{TaggingRules, "ChatNotebookSettings", "Assistance"}
						]
					]
					,
					CurrentValue[
						nbObj,
						{TaggingRules, "ChatNotebookSettings", "Assistance"}
					] = Inherited
					,
					CurrentValue[
						nbObj,
						{TaggingRules, "ChatNotebookSettings", "Assistance"}
					] = newValue
				]
			]
		)
	}]
},
	labeledCheckbox[
		Dynamic[
			autoAssistQ[target],
			setterFunction
		],
		Row[{
			"Do automatic result analysis",
			Spacer[3],
			Tooltip[
				chatbookIcon["InformationTooltip", False],
				"If enabled, automatic AI provided suggestions will be added following evaluation results."
			]
		}]
	]
]

(*====================================*)

SetFallthroughError[labeledCheckbox]

labeledCheckbox[value_, label_, enabled_ : Automatic] :=
	Row[
		{
			Checkbox[
				value,
				{False, True},
				Enabled -> enabled
			],
			Spacer[3],
			label
		},
		BaseStyle -> {
			"Text",
			FontSize -> 14,
			(* Note: Workaround increased ImageMargins of Checkbox's in
			         Preferences.nb *)
			CheckboxBoxOptions -> { ImageMargins -> 0 }
		}
	]

(*====================================*)

makeTemperatureSlider[
	value_
] :=
	Pane[
		Slider[
			value,
			{ 0, 2, 0.01 },
			ImageSize  -> { 135, Automatic },
			ImageMargins -> {{5, 0}, {5, 5}},
			Appearance -> "Labeled"
		],
		ImageSize -> { 180, Automatic },
		BaseStyle -> { FontSize -> 12 }
	]

(*=========================================*)
(* Common preferences content construction *)
(*=========================================*)

SetFallthroughError[makeFrontEndAndNotebookSettingsContent]

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
			getModelsMenuItems[]
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
]

(*======================================*)

showSnapshotModelsQ[] :=
	TrueQ @ CurrentValue[$FrontEnd, {
		PrivateFrontEndOptions,
		"InterfaceSettings",
		"ChatNotebooks",
		"ShowSnapshotModels"
	}]


(*========================================================*)

(* TODO: Make this look up translations for `name` in text resources data files. *)
tr[name_?StringQ] := name

(*


	Checkbox @ Dynamic[
		CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "ChatNotebooks", "IncludeHistory"}]
	]

		- True -- include any history cells that the persona wants
		- False -- never include any history
		- {"Style1", "Style2", ...}
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cell Dingbats*)
MakeChatInputActiveCellDingbat[ ] :=
	DynamicModule[ { cell },
		trackedDynamic[ MakeChatInputActiveCellDingbat @ cell, { "ChatBlock" } ],
		Initialization :> (cell = EvaluationCell[ ]; Needs[ "Wolfram`Chatbook`" -> None ]),
		UnsavedVariables :> { cell }
	];

MakeChatInputActiveCellDingbat[cell_CellObject] := Module[{
	menuLabel,
	button
},
	(*-----------------------------------------*)
	(* Construct the action menu display label *)
	(*-----------------------------------------*)

	menuLabel = With[{
		personaValue = currentValueOrigin[
			parentCell @ cell,
			{TaggingRules, "ChatNotebookSettings", "LLMEvaluator"}
		]
	},
		getPersonaMenuIcon @ Lookup[
			GetPersonasAssociation[],
			personaValue[[2]]
		]
	];

	button = Button[
		Framed[
			Pane[menuLabel, Alignment -> {Center, Center}, ImageSize -> {25, 25}, ImageSizeAction -> "ShrinkToFit"],
			RoundingRadius -> 2,
			FrameStyle -> Dynamic[
				If[CurrentValue["MouseOver"], GrayLevel[0.74902], None]
			],
			Background -> Dynamic[
				If[CurrentValue["MouseOver"], GrayLevel[0.960784], None]
			],
			FrameMargins -> 0,
			ImageMargins -> 0,
			ContentPadding -> False
		],
		(
			AttachCell[
				EvaluationCell[],
				makeChatActionMenu[
					"Input",
					parentCell[EvaluationCell[]],
					EvaluationCell[]
				],
				{Left, Bottom},
				Offset[{0, 0}, {Left, Top}],
				{Left, Top},
				RemovalConditions -> {"EvaluatorQuit", "MouseClickOutside"}
			];
		),
		Appearance -> $suppressButtonAppearance,
		ImageMargins -> 0,
		FrameMargins -> 0,
		ContentPadding -> False
	];

	button
];

(*====================================*)

MakeChatInputCellDingbat[] :=
	PaneSelector[
		{
			True -> MakeChatInputActiveCellDingbat[],
			False -> Framed[
				RawBoxes @ TemplateBox[{}, "ChatIconUser"],
				RoundingRadius -> 3,
				FrameMargins -> 2,
				ImageMargins -> {{0, 3}, {0, 0}},
				FrameStyle -> Transparent,
				FrameMargins -> 0
			]
		},
		Dynamic[CurrentValue["MouseOver"]],
		ImageSize -> All
	]

(*====================================*)

MakeChatDelimiterCellDingbat[ ] :=
	DynamicModule[ { cell },
		trackedDynamic[ MakeChatDelimiterCellDingbat @ cell, { "ChatBlock" } ],
		Initialization :> (
			cell = EvaluationCell[ ];
			Needs[ "Wolfram`Chatbook`" -> None ];
			updateDynamics[ "ChatBlock" ]
		),
		Deinitialization :> (
			Needs[ "Wolfram`Chatbook`" -> None ];
			updateDynamics[ "ChatBlock" ]
		),
		UnsavedVariables :> { cell }
	];

MakeChatDelimiterCellDingbat[cell_CellObject] := Module[{
	menuLabel,
	button
},
	(*-----------------------------------------*)
	(* Construct the action menu display label *)
	(*-----------------------------------------*)

	menuLabel = With[{
		personaValue = currentValueOrigin[
			parentCell @ cell,
			{TaggingRules, "ChatNotebookSettings", "LLMEvaluator"}
		]
	},
		getPersonaMenuIcon @ Lookup[
			GetPersonasAssociation[],
			personaValue[[2]]
		]
	];

	button = Button[
		Framed[
			Pane[menuLabel, Alignment -> {Center, Center}, ImageSize -> {25, 25}, ImageSizeAction -> "ShrinkToFit"],
			RoundingRadius -> 2,
			FrameStyle -> Dynamic[
				If[CurrentValue["MouseOver"], GrayLevel[0.74902], GrayLevel[0, 0]]
			],
			Background -> Dynamic[
				If[CurrentValue["MouseOver"], GrayLevel[0.960784], GrayLevel[1]]
			],
			FrameMargins -> 0,
			ImageMargins -> 0,
			ContentPadding -> False
		],
		(
			AttachCell[
				EvaluationCell[],
				makeChatActionMenu[
					"Delimiter",
					parentCell[EvaluationCell[]],
					EvaluationCell[]
				],
				{Left, Bottom},
				Offset[{0, 0}, {Left, Top}],
				{Left, Top},
				RemovalConditions -> {"EvaluatorQuit", "MouseClickOutside"}
			];
		),
		Appearance -> $suppressButtonAppearance,
		ImageMargins -> 0,
		FrameMargins -> 0,
		ContentPadding -> False
	];

	button
];

(*====================================*)

SetFallthroughError[makeChatActionMenu]

makeChatActionMenu[
	containerType: "Input" | "Delimiter" | "Toolbar",
	targetObj : _CellObject | _NotebookObject,
	(* The cell that will be the parent of the attached cell that contains this
		chat action menu content. *)
	attachedCellParent : _CellObject | Automatic
] := With[{
	closeMenu = ConfirmReplace[attachedCellParent, {
		parent_CellObject -> Function[
			NotebookDelete[Cells[attachedCellParent, AttachedCell -> True]]
		],
		(* NOTE: Capture the parent EvaluationCell[] immediately instead of
			delaying to do it inside closeMenu because closeMenu may be called
			from an attached sub-menu cell (like Advanced Settings), in which
			case EvaluationCell[] is no longer the top-level attached cell menu.
			We want closeMenu to always close the outermost menu. *)
		Automatic -> With[{parent = EvaluationCell[]},
			Function[
				NotebookDelete @ parent
			]
		]
	}]
}, Module[{
	personas = GetPersonasAssociation[],
	models,
	actionCallback
},
	(*--------------------------------*)
	(* Process personas list          *)
	(*--------------------------------*)

	RaiseConfirmMatch[personas, <| (_String -> _Association)... |>];

	(* initialize PrivateFrontEndOptions if they aren't already present or somehow broke *)
	If[!MatchQ[CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "VisiblePersonas"}], {___String}],
        CurrentValue[
			$FrontEnd,
			{PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "VisiblePersonas"}
		] = DeleteCases[Keys[personas], Alternatives["Birdnardo", "RawModel", "Wolfie"]]
	];
	If[!MatchQ[CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "PersonaFavorites"}], {___String}],
        CurrentValue[
			$FrontEnd,
			{PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "PersonaFavorites"}
		] = {"CodeAssistant", "CodeWriter", "PlainChat"}
	];

	(* only show visible personas and sort visible personas based on favorites setting *)
	personas = KeyTake[
		personas,
		CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "VisiblePersonas"}]
	];
	personas = With[{
		favorites = CurrentValue[
			$FrontEnd,
			{PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "PersonaFavorites"}
		]
	},
		Association[
			(* favorites appear in the exact order provided in the CurrentValue *)
			KeyTake[personas, favorites],
			KeySort @ KeyTake[personas, Complement[Keys[personas], favorites]]
		]
	];

	(*
		If this menu is being rendered into a Chat-Driven notebook, make the
		'Plain Chat' persona come first.
	*)
	If[
		TrueQ @ CurrentValue[
			ConfirmReplace[targetObj, {
				cell_CellObject :> ParentNotebook[cell],
				nb_NotebookObject :> nb
			}],
			{TaggingRules, "ChatNotebookSettings", "ChatDrivenNotebook"}
		],
		personas = Association[
			KeyTake[
				personas,
				{
					"PlainChat",
					"RawModel",
					"CodeWriter",
					"CodeAssistant"
				}
			],
			personas
		];
	];

	(*--------------------------------*)
	(* Process models list            *)
	(*--------------------------------*)

	models = getModelsMenuItems[];

	RaiseConfirmMatch[models, <| (_?StringQ -> _?AssociationQ)... |>];

	(*--------------------------------*)

	actionCallback = Function[{field, value}, Replace[field, {
		"Persona" :> (
			CurrentValue[
				targetObj,
				{TaggingRules, "ChatNotebookSettings", "LLMEvaluator"}
			] = value;

			closeMenu[];

			(* If we're changing the persona set on a cell, ensure that we are
				not showing the static "ChatInputCellDingbat" that is set
				when a ChatInput is evaluated. *)
			If[Head[targetObj] === CellObject,
				SetOptions[targetObj, CellDingbat -> Inherited];
			];
		),
		"Model" :> (
			CurrentValue[
				targetObj,
				{TaggingRules, "ChatNotebookSettings", "Model"}
			] = value;
			closeMenu[];
		),
		"Role" :> (
			CurrentValue[
				targetObj,
				{TaggingRules, "ChatNotebookSettings", "Role"}
			] = value;
			closeMenu[];
		),
		other_ :> (
			ChatbookWarning[
				"Unexpected field set from LLM configuration action menu: `` => ``",
				InputForm[other],
				InputForm[value]
			];
		)
	}]];

	makeChatActionMenuContent[
		containerType,
		personas,
		models,
		"ActionCallback" -> actionCallback,
		"PersonaValue" -> currentValueOrigin[
			targetObj,
			{TaggingRules, "ChatNotebookSettings", "LLMEvaluator"}
		],
		"ModelValue" -> currentValueOrigin[
			targetObj,
			{TaggingRules, "ChatNotebookSettings", "Model"}
		],
		"RoleValue" -> currentValueOrigin[
			targetObj,
			{TaggingRules, "ChatNotebookSettings", "Role"}
		],
		"TemperatureValue" -> Dynamic[
			currentChatSettings[ targetObj, "Temperature" ],
			newValue |-> (
				CurrentValue[
					targetObj,
					{TaggingRules, "ChatNotebookSettings", "Temperature"}
				] = newValue;
			)
		]
	]
]]

(*====================================*)

SetFallthroughError[makeChatActionMenuContent]

Options[makeChatActionMenuContent] = {
	"PersonaValue" -> Automatic,
	"ModelValue" -> Automatic,
	"RoleValue" -> Automatic,
	"TemperatureValue" -> Automatic,
	"ActionCallback" -> (Null &)
}

makeChatActionMenuContent[
	containerType : "Input" | "Delimiter" | "Toolbar",
	personas_?AssociationQ,
	models_?AssociationQ,
	OptionsPattern[]
] := With[{
	callback = OptionValue["ActionCallback"]
}, Module[{
	personaValue = OptionValue["PersonaValue"],
	modelValue = OptionValue["ModelValue"],
	roleValue = OptionValue["RoleValue"],
	tempValue = OptionValue["TemperatureValue"],
	advancedSettingsMenu,
	menuLabel,
	menuItems
},

	(*-------------------------------------------------*)
	(* Construct the Advanced Settings submenu content *)
	(*-------------------------------------------------*)

	advancedSettingsMenu = Join[
		{
			"Temperature",
			{
				None,
				makeTemperatureSlider[tempValue],
				None
			}
		},
		{"Roles"},
		Map[
			entry |-> ConfirmReplace[entry, {
				{role_?StringQ, icon_} :> {
					alignedMenuIcon[role, roleValue, icon],
					role,
					Hold[callback["Role", role]]
				}
			}],
			{
				{"User", getIcon["ChatIconUser"]},
				{"System", getIcon["RoleSystem"]}
			}
		]
	];

	advancedSettingsMenu = MakeMenu[
		advancedSettingsMenu,
		GrayLevel[0.85],
		200
	];

	(*------------------------------------*)
	(* Construct the popup menu item list *)
	(*------------------------------------*)

	menuItems = Join[
		{"Personas"},
		KeyValueMap[
			{persona, personaSettings} |-> With[{
				icon = getPersonaMenuIcon[personaSettings]
			},
				{
					alignedMenuIcon[persona, personaValue, icon],
					personaDisplayName[persona, personaSettings],
					Hold[callback["Persona", persona];updateDynamics[{"ChatBlock"}]]
				}
			],
			personas
		],
		{"Models"},
		KeyValueMap[
			{model, settings} |-> (
				{
					alignedMenuIcon[
						model,
						modelValue,
						getModelMenuIcon[settings]
					],
					modelDisplayName[model],
					Hold[callback["Model", model]]
				}
			),
			models
		],
		{
			ConfirmReplace[containerType, {
				"Input" | "Toolbar" -> Nothing,
				"Delimiter" :> Splice[{
					Delimiter,
					{
						alignedMenuIcon[getIcon["ChatBlockSettingsMenuIcon"]],
						"Chat Block Settings\[Ellipsis]",
						"OpenChatBlockSettings"
					}
				}]
			}],
			Delimiter,
			{alignedMenuIcon[getIcon["PersonaOther"]], "Add & Manage Personas\[Ellipsis]", "PersonaManage"},
			{alignedMenuIcon[getIcon["ToolManagerRepository"]], "Add & Manage Tools\[Ellipsis]", "ToolManage"},
			Delimiter,
			{
				alignedMenuIcon[getIcon["AdvancedSettings"]],
				Grid[
					{{
						Item["Advanced Settings", ItemSize -> Fit, Alignment -> Left],
						RawBoxes[TemplateBox[{}, "Triangle"]]
					}},
					Spacings -> 0
				],
				Hold @ AttachSubmenu[
					EvaluationCell[],
					advancedSettingsMenu
				]
			}
		}
	];

	menu = MakeMenu[
		menuItems,
		GrayLevel[0.85],
		$chatMenuWidth
	];

	menu
]]

(*====================================*)

(* getIcon[filename_?StringQ] := Module[{
	icon
},
	icon = Import @ FileNameJoin @ {
		PacletObject[ "Wolfram/Chatbook" ][ "AssetLocation", "Icons" ],
		filename
	};

	If[!MatchQ[icon, _Graphics],
		Raise[
			ChatbookError,
			"Unexpected result loading icon from from file ``: ``",
			filename,
			InputForm[icon]
		];
	];

	(* NOTE: If the graphic doesn't have an existing BaselinePosition set,
		use a default baseline that looks vertically centered for most visually
		balanced icons. *)
	If[BaselinePosition /. Options[icon, BaselinePosition] === Automatic,
		(* TODO: Force the image size too. *)
		icon = Show[icon, BaselinePosition -> Scaled[0.24]];
	];

	(* Cache the icon so we don't have to load it from disk again. *)
	getIcon[filename] = icon;

	icon
] *)

getIcon[ name_ ] := RawBoxes @ TemplateBox[ { }, name ];



(*========================================================*)
(* Chat settings lookup helpers                           *)
(*========================================================*)

SetFallthroughError[absoluteCurrentValue]

absoluteCurrentValue[cell_, {TaggingRules, "ChatNotebookSettings", key_}] := currentChatSettings[cell, key]
absoluteCurrentValue[cell_, keyPath_] := AbsoluteCurrentValue[cell, keyPath]

(*====================================*)

currentValueOrigin // beginDefinition;

(*
	Get the current value and origin of a cell option value.

	This function will return {origin, value}, where `origin` will be one of:

	* "Inline"    -- this value is set inline in the specified CellObject
	* "Inherited" -- this value is inherited from a style setting outside of the
		specified CellObject.
*)
currentValueOrigin[
	targetObj : _CellObject | _NotebookObject,
	keyPath_List
] := Module[{
	value,
	inlineValue
},
	value = absoluteCurrentValue[targetObj, keyPath];

	(* This was causing dynamics to update on every keystroke, so it's disabled for now: *)
	(* inlineValue = nestedLookup[
		Options[targetObj],
		keyPath,
		None
	]; *)
	inlineValue = value;

	Which[
		inlineValue === None,
			{"Inherited", value},
		True,
			{"Inline", inlineValue}
	]
]

currentValueOrigin // endDefinition;

(*====================================*)

getModelsMenuItems[] := Module[{
	items
},
	items = Select[getModelList[], chatModelQ];

	RaiseAssert[MatchQ[items, {___String}]];

	items = Sort[items];

	If[!TrueQ[showSnapshotModelsQ[]],
		items = Select[ items, Not @* snapshotModelQ ];
	];

	items = AssociationMap[standardizeModelData, items];

	RaiseAssert[MatchQ[items, <| (_?StringQ -> _?AssociationQ)... |>]];

	items
]


(*========================================================*)
(* Menu construction helpers                              *)
(*========================================================*)

SetFallthroughError[alignedMenuIcon]

alignedMenuIcon[possible_, current_, icon_] := alignedMenuIcon[styleListItem[possible, current], icon]
alignedMenuIcon[check_, icon_] := Row[{check, " ", resizeMenuIcon[icon]}]
(* If menu item does not utilize a checkmark, use an invisible one to ensure it is left-aligned with others *)
alignedMenuIcon[icon_] := alignedMenuIcon[Style["\[Checkmark]", ShowContents -> False], icon]

(*====================================*)

resizeMenuIcon[ icon: _Graphics|_Graphics3D ] :=
	Show[ icon, ImageSize -> { 21, 21 } ];

resizeMenuIcon[ icon_ ] := Pane[
	icon,
	ImageSize       -> { 21, 21 },
	ImageSizeAction -> "ShrinkToFit",
	ContentPadding  -> False
];

(*====================================*)

SetFallthroughError[styleListItem]

(*
	Style a list item in the ChatInput option value dropdown based on whether
	its value is set inline in the current cell, inherited from some enclosing
	setting, or not the current value.
*)
styleListItem[
	possibleValue_?StringQ,
	currentValue : {"Inline" | "Inherited", _}
] := (
	Replace[currentValue, {
		(* This possible value is the currently selected value. *)
		{"Inline", possibleValue} :>
			"\[Checkmark]",
		(* This possible value is the inherited selected value. *)
		{"Inherited", possibleValue} :>
			Style["\[Checkmark]", FontColor -> GrayLevel[0.75]],
		(* This possible value is not whatever the currently selected value is. *)
		(* Display a hidden checkmark purely so that this
			is offset by the same amount as list items that
			display a visible checkmark. *)
		_ ->
			Style["\[Checkmark]", ShowContents -> False]
	}]
)

(*========================================================*)
(* Persona property lookup helpers                        *)
(*========================================================*)

SetFallthroughError[personaDisplayName]

personaDisplayName[name_String] := personaDisplayName[name, GetCachedPersonaData[name]]
personaDisplayName[name_String, data_Association] := personaDisplayName[name, data["DisplayName"]]
personaDisplayName[name_String, displayName_String] := displayName
personaDisplayName[name_String, _] := name

(*====================================*)

SetFallthroughError[getPersonaMenuIcon];

getPersonaMenuIcon[ KeyValuePattern[ "Icon"|"PersonaIcon" -> icon_ ] ] := getPersonaMenuIcon @ icon;
getPersonaMenuIcon[ KeyValuePattern[ "Default" -> icon_ ] ] := getPersonaMenuIcon @ icon;
getPersonaMenuIcon[ _Missing | _Association | None ] := RawBoxes @ TemplateBox[ { }, "PersonaUnknown" ];
getPersonaMenuIcon[ icon_ ] := icon;

(* If "Full" is specified, resolve TemplateBox icons into their literal
   icon data, so that they will render correctly in places where the Chatbook.nb
   stylesheet is not available. *)
getPersonaMenuIcon[ expr_, "Full" ] :=
	Replace[getPersonaMenuIcon[expr], {
		RawBoxes[TemplateBox[{}, iconStyle_?StringQ]] :> (
			chatbookIcon[iconStyle, False]
		),
		icon_ :> icon
	}]


getPersonaIcon[ expr_ ] := getPersonaMenuIcon[ expr, "Full" ];


(*========================================================*)
(* Model property lookup helpers                          *)
(*========================================================*)

SetFallthroughError[getModelMenuIcon]

getModelMenuIcon[settings_?AssociationQ] := Module[{},
	Replace[Lookup[settings, "Icon", None], {
		None | _Missing -> Style["", ShowContents -> False],
		icon_ :> icon
	}]
]

(* If "Full" is specified, resolve TemplateBox icons into their literal
   icon data, so that they will render correctly in places where the Chatbook.nb
   stylesheet is not available. *)
getModelMenuIcon[settings_?AssociationQ, "Full"] :=
	Replace[getModelMenuIcon[settings], {
		RawBoxes[TemplateBox[{}, iconStyle_?StringQ]] :> (
			chatbookIcon[iconStyle, False]
		),
		icon_ :> icon
	}]


(*========================================================*)
(* Generic Utilities                                      *)
(*========================================================*)

SetFallthroughError[nestedLookup]
Attributes[nestedLookup] = {HoldRest}

nestedLookup[as:KeyValuePattern[{}], {keys___}, default_] :=
	Replace[
		GeneralUtilities`ToAssociations[as][keys],
		{
			Missing["KeyAbsent", ___] :> default,
			_[keys] :> default
		}
	]

nestedLookup[as_, key:Except[_List], default_] :=
	With[{keys = key},
		If[ ListQ[keys],
			nestedLookup[as, keys, default],
			nestedLookup[as, {keys}, default]
		]
	]

nestedLookup[as_, keys_] := nestedLookup[as, keys, Missing["KeySequenceAbsent", keys]]


(*========================================================*)


End[]

EndPackage[]

(* :!CodeAnalysis::EndBlock:: *)