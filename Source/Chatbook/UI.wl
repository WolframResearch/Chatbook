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
MakeChatCloudDefaultNotebookDockedCell
MakeChatCloudDockedCellContents

GeneralUtilities`SetUsage[CreatePreferencesContent, "
CreatePreferencesContent[] returns an expression containing the UI shown in the Preferences > AI Settings window.
"]

GeneralUtilities`SetUsage[CreateToolbarContent, "
CreateToolbarContent[] is called by the NotebookToolbar to generate the content of the 'Notebook AI Settings' attached menu.
"]

GeneralUtilities`SetUsage[CreateSideBarContent, "
CreateSideBarContent[ sideBarCell ] is called by the NotebookToolbar to generate the content of the 'Notebook AI Settings' sidebar menu, passing in the CellObject of the side bar.
"]

Begin["`Private`"]

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Actions`"          ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`Errors`"           ];
Needs[ "Wolfram`Chatbook`ErrorUtils`"       ];
Needs[ "Wolfram`Chatbook`Menus`"            ];
Needs[ "Wolfram`Chatbook`Personas`"         ];
Needs[ "Wolfram`Chatbook`PreferencesUtils`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cloud Toolbar*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MakeChatCloudDefaultNotebookDockedCell*)
MakeChatCloudDefaultNotebookDockedCell[] := makeChatCloudDefaultNotebookDockedCell[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MakeChatCloudDockedCellContents*)
MakeChatCloudDockedCellContents[] := makeChatCloudDockedCellContents[ ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Preferences Panel*)
CreatePreferencesContent[ ] := trackedDynamic[ createPreferencesContent[ ], { "Preferences" } ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
CreateSideBarContent[ sideBarCell_CellObject ] := DynamicModule[ {
	nbObj,
	isChatEnabled
},
	(* This menu is kernel-generated, so calculate variables once before the DM displayed content, and pass them on as needed *)
	nbObj = EvaluationNotebook[ ];
	isChatEnabled = TrueQ @ CurrentValue[ nbObj, { StyleDefinitions, "ChatInput", Evaluatable } ];

	mainSideBarMenuContent[ True, sideBarCell, nbObj, isChatEnabled ],

	InheritScope -> True
] /; TrueQ @ alreadyLoadedMenuQ;

(*
	The percolator only appears the first time the menu loads when invoked from the default toolbar.
	Note that it can quickly flash if the LLM models were first loaded elsewhere, like when creating a new ChatInput cell,
	but that's an OK compromise. *)
CreateSideBarContent[ sideBarCell_CellObject ] := DynamicModule[ {
	nbObj,
	isChatEnabled,
	display
},
	(* Show the progress indicator as soon as possible *)
	display =
		Pane[
			Column @ {
				Style[ tr @ "UIInitializeChatbook", "ChatMenuLabel" ],
				ProgressIndicator[ Appearance -> "Percolate" ]
			},
			ImageMargins -> 5,
			ImageSize    -> Scaled[1.]
		];

	Dynamic[ display ],

	Initialization :> (
		nbObj = EvaluationNotebook[ ];
		isChatEnabled = TrueQ @ CurrentValue[ nbObj, { StyleDefinitions, "ChatInput", Evaluatable } ];
		display = mainSideBarMenuContent[ False, sideBarCell, nbObj, isChatEnabled ];
		alreadyLoadedMenuQ = True
	),

	SynchronousInitialization -> False,

	InheritScope -> True
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mainSideBarMenuContent*)

mainSideBarMenuContent // beginDefinition;

Attributes[mainSideBarMenuContent] = {HoldRest};

mainSideBarMenuContent[ alreadyLoadedMenuQ_, sideBarCell_, nbObj_, isChatEnabled_ ] :=
PaneSelector[
	{
		True -> If[ alreadyLoadedMenuQ,
			((* Creating the menu is expensive even if it's already loaded once before.
				The Dynamic means we only create it when it is first displayed.
				So if the False case of this PaneSelector happens first, then createChatNotEnabledToolbar won't take time to load. *)
				Dynamic[ makeSideBarMenuContent[ sideBarCell, nbObj ], SingleEvaluation -> True, DestroyAfterEvaluation -> True ]
			),
			(* If the menu is generating for the first time then we can't have the Dynamic here or else it competes with Dynamic[display] *)
			makeSideBarMenuContent[ sideBarCell, nbObj ]
		],
		False -> createChatNotEnabledToolbar[ nbObj, Dynamic @ isChatEnabled ]
	},
	Dynamic @ isChatEnabled,
	ImageSize -> Automatic
]

mainSideBarMenuContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeSideBarMenuContent*)

makeSideBarMenuContent // beginDefinition;

makeSideBarMenuContent[ sideBarCell_CellObject, nbObj_NotebookObject ] := Enclose[
	Module[ { items, new },

		items = ConfirmBy[ makeChatActionMenu[ "SideBar", nbObj ], ListQ, "Items" ];

		new = Join[ 
			{ <|
				 "Type"           -> "Custom",
				 "Content"        -> Pane[ makeAutomaticResultAnalysisCheckboxSideBar @ nbObj, ImageMargins -> { { 5, 5 }, { 2.5, 2.5 } } ],
				 "ResetAction"    :> (CurrentValue[ nbObj, { TaggingRules, "ChatNotebookSettings", "Assistance" } ] = Inherited),
				 "ResetCondition" :> (AbsoluteCurrentValue[ nbObj, { TaggingRules, "ChatNotebookSettings", "Assistance" } ] =!= Inherited)
			|> },
			items ];

		MakeSideBarMenu[ sideBarCell, new ]
	],
	throwInternalFailure
];

makeSideBarMenuContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*backButtonAppearance*)
backButtonAppearanceBasic // beginDefinition;

backButtonAppearanceBasic[ label_, frameStyle_, frameMargins_, size_ ] :=
Framed[
    label,
    Alignment -> { Center, Center },
    BaselinePosition -> Baseline,
    FrameMargins -> frameMargins,
    FrameStyle -> Directive[ AbsoluteThickness[ 1 ], frameStyle ],
    ImageSize -> size,
    RoundingRadius -> 2 ]

backButtonAppearanceBasic // endDefinition;

backButtonAppearance // beginDefinition;

backButtonAppearance[ label_, frameMargins_, size_ ] :=
NotebookTools`Mousedown[
    backButtonAppearanceBasic[ label, GrayLevel[ 0.785 ], frameMargins, size ],
    backButtonAppearanceBasic[ label, Lighter @ GrayLevel[ 0.785 ], frameMargins, size ],
    backButtonAppearanceBasic[ label, Darker @ GrayLevel[ 0.785 ], frameMargins, size ],
    BaselinePosition -> Baseline ]

backButtonAppearance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Default Notebook Toolbar*)
CreateToolbarContent[ ] := DynamicModule[{
	nbObj,
	menuCell,
	isChatEnabled
},
	(* This menu is kernel-generated, so calculate variables once before the DM displayed content, and pass them on as needed *)
	nbObj = EvaluationNotebook[ ];
	menuCell = EvaluationCell[ ];
	isChatEnabled = TrueQ @ CurrentValue[ nbObj, { StyleDefinitions, "ChatInput", Evaluatable } ];

	mainToolbarMenuContent[ True, nbObj, menuCell, isChatEnabled ]
] /; TrueQ @ alreadyLoadedMenuQ;

(*
	The percolator only appears the first time the menu loads when invoked from the default toolbar.
	Note that it can quickly flash if the LLM models were first loaded elsewhere, like when creating a new ChatInput cell,
	but that's an OK compromise. *)
CreateToolbarContent[ ] := DynamicModule[{
	nbObj,
	menuCell,
	isChatEnabled,
	display
},
	(* Show the progress indicator as soon as possible *)
	display =
		Pane[
			Column @ {
				Style[ tr @ "UIInitializeChatbook", "ChatMenuLabel" ],
				ProgressIndicator[ Appearance -> "Percolate" ]
			},
			ImageMargins -> 5
		];

	Dynamic[ display ],

	Initialization :> (
		nbObj = EvaluationNotebook[ ];
		menuCell = EvaluationCell[ ];
		isChatEnabled = TrueQ @ CurrentValue[ nbObj, { StyleDefinitions, "ChatInput", Evaluatable } ];
		display = mainToolbarMenuContent[ False, nbObj, menuCell, isChatEnabled ];
		alreadyLoadedMenuQ = True
	),

	SynchronousInitialization -> False
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mainToolbarMenuContent*)

mainToolbarMenuContent // beginDefinition;

Attributes[mainToolbarMenuContent] = {HoldRest};

mainToolbarMenuContent[ alreadyLoadedMenuQ_, nbObj_, menuCell_, isChatEnabled_ ] :=
PaneSelector[
	{
		True -> If[ alreadyLoadedMenuQ,
			((* Creating the menu is expensive even if it's already loaded once before.
				The Dynamic means we only create it when it is first displayed.
				So if the False case of this PaneSelector happens first, then createChatNotEnabledToolbar won't take time to load. *)
				Dynamic[ makeToolbarMenuContent[ menuCell, nbObj ], SingleEvaluation -> True, DestroyAfterEvaluation -> True ]
			),
			(* If the menu is generating for the first time then we can't have the Dynamic here or else it competes with Dynamic[display] *)
			makeToolbarMenuContent[ menuCell, nbObj ]
		],
		False -> createChatNotEnabledToolbar[ nbObj, Dynamic @ isChatEnabled ]
	},
	Dynamic @ isChatEnabled,
	ImageSize -> Automatic
]

mainToolbarMenuContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeToolbarMenuContent*)

makeToolbarMenuContent[ menuCell_, nbObj_NotebookObject ] := Enclose[
	Module[ { items, item1, item2, new },

		items = ConfirmBy[ makeChatActionMenu[ "Toolbar", nbObj ], ListQ, "Items" ];

		(* 14.2+ we don't need to show that chat features are enabled anymore as they are on by default *)
		item1 = If[ insufficientVersionQ @ 14.2,
			<|
				"Type"    -> "Custom",
				"Content" ->
					Pane[
						makeEnableAIChatFeaturesLabel @ True,
						ImageMargins -> { { 5, 5 }, { 2.5, 2.5 } }
					]
			|>
			,
			Nothing
		];

		item2 = Pane[
			makeAutomaticResultAnalysisCheckbox @ nbObj,
			ImageMargins -> { { 5, 5 }, { 2.5, 2.5 } }
		];

		new = Join[ { item1, <| "Type" -> "Custom", "Content" -> item2 |> }, items ];

		(* The default toolbar's menu frame is 231 points, but has 1 pt of ImageMargins and 4 total FrameMargins, so use ~226 for a good fit *)
		MakeMenu[ new, ImageSize -> 225, TaggingRules -> <| "IsRoot" -> True |> ]
	],
	throwInternalFailure
];

(*====================================*)

SetFallthroughError[createChatNotEnabledToolbar]

createChatNotEnabledToolbar[
	nbObj_NotebookObject,
	Dynamic[ isChatEnabled_ ]
] :=
	EventHandler[
		makeEnableAIChatFeaturesLabel @ False,
		"MouseClicked" :> (
			tryMakeChatEnabledNotebook[ nbObj, Dynamic @ isChatEnabled ]
		),
		(* Needed so that we can open a ChoiceDialog if required. *)
		Method -> "Queued"
	]

(*====================================*)

SetFallthroughError[tryMakeChatEnabledNotebook]

tryMakeChatEnabledNotebook[
	nbObj_NotebookObject,
	Dynamic[ isChatEnabled_ ]
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
					Item[Magnify["\[WarningSign]", 3], Alignment -> Center],
					"",
					tr[ "UITryEnableChatDialogMainText" ],
					"",
					tr[ "UITryEnableChatDialogConfirm" ]
				}, BaseStyle -> {"DialogTextBasic", FontSize -> 15, LineIndent -> 0}, Spacings -> {0, 0}],
				Background -> color @ "NA_NotebookBackground"
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
	isChatEnabled = True;
]

(*====================================*)

SetFallthroughError[makeEnableAIChatFeaturesLabel]

makeEnableAIChatFeaturesLabel[ enabled_? BooleanQ ] :=
	labeledCheckbox[
		enabled,
		If[ ! enabled,
			Style[
				tr @ "UIEnableChatFeatures",
				FontColor -> (Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[
					color @ "ChatMenuCheckboxLabelFontHover",
					color @ "ChatMenuCheckboxLabelFont"
				])
			]
			,
			Style[ tr @ "UIEnableChatFeatures", FontColor -> color @ "ChatMenuCheckboxLabelFontDisabled" ]
		],
		! enabled,
		195
	];

(*====================================*)

SetFallthroughError[makeAutomaticResultAnalysisCheckbox]

makeAutomaticResultAnalysisCheckbox[
	target : _FrontEndObject | $FrontEndSession | _NotebookObject
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
		autoAssistQ @ target,
		setterFunction,
		(* We can only get the tooltip to glue itself to the text by first literalizing the text resource as a string before typesetting to RowBox. *)
		Style[
			Row[
				{
					FrontEndResource[ "ChatbookStrings", "UIAutomaticAnalysisLabel" ],
					Spacer[ 3 ],
					Tooltip[ chatbookIcon[ "InformationTooltip", False ], FrontEndResource[ "ChatbookStrings", "UIAutomaticAnalysisTooltip" ] ]
				},
				"\[NoBreak]",
				StripOnInput -> True
			],
			FontColor -> (Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[
				color @ "ChatMenuCheckboxLabelFontHover",
				color @ "ChatMenuCheckboxLabelFont"
			])
		],
		True,
		195
	]
]

SetFallthroughError[makeAutomaticResultAnalysisCheckboxSideBar]

(* the side bar changes the notebook-level setting regardless of the $FrontEndSession value *)
makeAutomaticResultAnalysisCheckboxSideBar[ nbo_NotebookObject ] :=
Pane[ #, FrameMargins -> { { 0, 0 }, { 7, 7 } } ]& @
DynamicModule[ { value = TrueQ @ initialValue },
	Row[
		{
			Checkbox[
				Dynamic[ value, Function[ value = #; CurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings", "Assistance" } ] = # ] ],
				{False, True}
			],
			Spacer[3],
			EventHandler[
				Style[
					Row[
						{
							FrontEndResource[ "ChatbookStrings", "UIAutomaticAnalysisLabel" ],
							Spacer[ 3 ],
							Tooltip[ chatbookIcon[ "InformationTooltip", False ], FrontEndResource[ "ChatbookStrings", "UIAutomaticAnalysisTooltip" ] ]
						},
						"\[NoBreak]",
						StripOnInput -> True
					],
					FontColor -> (Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[
						LightDarkSwitched[ RGBColor[ "#2FA7DC" ], RGBColor[ "#87D0F9" ] ],
						LightDarkSwitched[ GrayLevel[ 0.2 ], GrayLevel[ 0.9613 ] ]
					])
				],
				"MouseClicked" :> (CurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings", "Assistance" } ] = value = ! value)
			]
		},
		BaseStyle -> {
			"Text",
			FontFamily         -> "Source Sans Pro",
			FontSize           -> 12,
			FontSlant          -> Plain,
			CheckboxBoxOptions -> { ImageMargins -> 0 },
			LineBreakWithin    -> False
		},
		StripOnInput -> True
	]

]

(*====================================*)

SetFallthroughError[labeledCheckbox]

labeledCheckbox[ value : True | False, label_, enabled_, width_ ] := labeledCheckbox[ value, #&, label, enabled, width ]

labeledCheckbox[initialValue_, update_Function, label_, enabled_, width_ ] :=
DynamicModule[ { value = TrueQ @ initialValue },
	labeledCheckbox0[ Dynamic @ value, update, label, enabled, width ]
]

labeledCheckbox0[ Dynamic @ value_, update_Function, label_, enabled_, width_ ] :=
	Row[
		{
			Checkbox[
				Dynamic[ value, Function[ value = #; update[#] ] ],
				{False, True},
				Enabled -> enabled
			],
			Spacer[3],
			EventHandler[
				lineWrap[ label, width ],
				"MouseClicked" :> If[ TrueQ @ Replace[ enabled, Automatic -> True ], update[ value = ! value ] ]
			]
		},
		BaseStyle -> {
			"Text",
			FontSize -> 14,
			FontSlant -> Plain,
			(* Note: Workaround increased ImageMargins of Checkbox's in
					 Preferences.nb *)
			CheckboxBoxOptions -> { ImageMargins -> 0 },
			LineBreakWithin -> False
		}
	]

(*====================================*)

makeToolCallFrequencySlider[ targetObj_, appContainer_ ] :=
With[
	{
		initFrequency = currentChatSettings[ targetObj, "ToolCallFrequency" ]
	},
	Module[ { checkboxUpdate, checkboxLabel },
		checkboxLabel =
			Style[
				tr @ "UIAdvancedChooseAutomatically",
				"ChatMenuLabel",
				If[ MatchQ[ appContainer, _CellObject ],
					FontColor -> (Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[
						LightDarkSwitched[ RGBColor[ "#2FA7DC" ], RGBColor[ "#87D0F9" ] ],
						LightDarkSwitched[ GrayLevel[ 0.2 ], GrayLevel[ 0.9613 ] ]
					]),
					FontColor -> (Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[
						color @ "ChatMenuCheckboxLabelFontHover",
						color @ "ChatMenuCheckboxLabelFont"
					])
				]
			];

		Pane[
			DynamicModule[ { autoQ, value },
				checkboxUpdate =
					Function[
						If[ TrueQ[ # ],
							CurrentValue[ targetObj, { TaggingRules, "ChatNotebookSettings", "ToolCallFrequency" } ] = Inherited,
							CurrentValue[ targetObj, { TaggingRules, "ChatNotebookSettings", "ToolCallFrequency" } ] = value
						]
					];

				PaneSelector[
					{
						True -> Column[ { labeledCheckbox0[ Dynamic @ autoQ, checkboxUpdate, checkboxLabel, True, 155 ] }, Alignment -> Left ],
						False -> Column[
							{
								Pane[
									Grid[
										{
											{
												Style[ tr[ "Rare" ], "ChatMenuLabel", FontSize -> 12 ],
												Slider[(* let the slider move freely, but only update the TaggingRules on mouse-up *)
													Dynamic[ value, { None, Temporary, (value = CurrentValue[ targetObj, { TaggingRules, "ChatNotebookSettings", "ToolCallFrequency" } ] = #) & } ],
													{ 0, 1, 0.01 },
													ImageSize    -> { 100, Automatic },
													ImageMargins -> { { 0, 0 }, { 5, 5 } }
												],
												Style[ tr[ "Often" ], "ChatMenuLabel", FontSize -> 12 ]
											}
										},
										Spacings -> { { 0, { 0.5 }, 0 }, 0 },
										Alignment -> { { Left, Center, Right }, Baseline }
									],
									ImageMargins -> 0,
									ImageSize    -> { 170, Automatic }
								],
								labeledCheckbox0[ Dynamic @ autoQ, checkboxUpdate, checkboxLabel, True, 155 ]
							},
						Alignment -> Left ]
					},
					Dynamic @ autoQ,
					ImageSize -> Automatic
				],
				Initialization :> (value = Replace[ initFrequency, Except[ _?NumericQ ] -> 0.5 ]; autoQ = initFrequency === Automatic)
			],
			ImageMargins -> { { 5, 0 }, { 5, 5 } }
		]
	]
];

SetFallthroughError[makeTemperatureSlider]

makeTemperatureSlider[ targetObj_, appContainer_ ] :=
With[
	{
		initTemperature = currentChatSettings[ targetObj, "Temperature" ]
	},
	Module[ { checkboxUpdate, checkboxLabel },
		checkboxLabel =
			Style[
				tr @ "UIAdvancedChooseAutomatically",
				"ChatMenuLabel",
				If[ MatchQ[ appContainer, _CellObject ],
					FontColor -> (Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[
						LightDarkSwitched[ RGBColor[ "#2FA7DC" ], RGBColor[ "#87D0F9" ] ],
						LightDarkSwitched[ GrayLevel[ 0.2 ], GrayLevel[ 0.9613 ] ]
					]),
					FontColor -> (Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[
						color @ "ChatMenuCheckboxLabelFontHover",
						color @ "ChatMenuCheckboxLabelFont"
					])
				]
			];

		Pane[
			DynamicModule[ { autoQ, value },
				checkboxUpdate =
					Function[
						If[ TrueQ[ # ],
							CurrentValue[ targetObj, { TaggingRules, "ChatNotebookSettings", "Temperature" } ] = Inherited,
							CurrentValue[ targetObj, { TaggingRules, "ChatNotebookSettings", "Temperature" } ] = value
						]
					];

				PaneSelector[
					{
						True -> Column[ { labeledCheckbox0[ Dynamic @ autoQ, checkboxUpdate, checkboxLabel, True, 155 ] }, Alignment -> Left ],
						False -> Column[
							{
								Pane[
									Slider[(* let the slider move freely, but only update the TaggingRules on mouse-up *)
										Dynamic[ value, {
											None,
											Automatic,
											Function[
												value = #;
												CurrentValue[ targetObj, { TaggingRules, "ChatNotebookSettings", "Temperature" }] = # ] }
										],
										{ 0, 2, 0.01 },
										ImageSize    -> { 130, Automatic },
										ImageMargins -> {{5, 0}, {5, 5}},
										Appearance   -> "Labeled"
									],
									ImageMargins -> 0,
									ImageSize    -> { 170, Automatic }
								],
								labeledCheckbox0[ Dynamic @ autoQ, checkboxUpdate, checkboxLabel, True, 155 ]
							},
							Alignment -> Left
						]
					},
					Dynamic @ autoQ,
					ImageSize -> Automatic
				],
				Initialization :> (value = Replace[ initTemperature, Except[ _?NumericQ ] -> 0.5 ]; autoQ = initTemperature === Automatic)
			],
			ImageMargins -> { { 5, 0 }, { 5, 5 } }
		]
	]
]

(*=========================================*)
(* Common preferences content construction *)
(*=========================================*)

showSnapshotModelsQ[] :=
	TrueQ @ CurrentValue[$FrontEnd, {
		PrivateFrontEndOptions,
		"InterfaceSettings",
		"Chatbook",
		"ShowSnapshotModels"
	}]

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
(*Error Messages*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Common Error Options*)

$commonLabeledButtonOptions = Sequence[
	BaseStyle        -> { FontFamily -> "Source Sans Pro", FontSize -> 12 },
	BaselinePosition -> Baseline,
	FrameMargins     -> { { 7, 7 }, { 4, 4 } },
	RoundingRadius   -> 4
];

$commonErrorFrameOptions = Sequence[
	BaseStyle -> {
		FontFamily           -> "Source Sans Pro",
		FontSize             -> 13,
		LinebreakAdjustments -> { 1.0, 10, 1, 0, 1 },
		LineIndent           -> 0,
		LineSpacing          -> 0.5,
		ShowStringCharacters -> False
	},
	BaselinePosition -> Baseline,
	FrameMargins     -> { { 10, 7 }, { 8, 6 } },
	RoundingRadius   -> 6
];

$commonErrorLinkOptions = Sequence[
	FontFamily           -> "Source Sans Pro",
	FontSize             -> 12,
	LinebreakAdjustments -> { 1.0, 10, 1, 0, 1 },
	LineIndent           -> 0
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*errorMessageBox*)
errorMessageBox // beginDefinition;

Attributes[ errorMessageBox ] = { HoldRest };
Options[ errorMessageBox ] = { Appearance -> "NonFatal", ImageSize -> Automatic };

errorMessageBox[ failure_Failure, opts: OptionsPattern[ ] ] :=
	Which[
		! FreeQ[ failure, "credits-per-month-limit-exceeded" ], errorMessageBox[ "UsageAt100" ],
		! FreeQ[ failure, $$usageLimitCode ], errorMessageBox[ "UsageBlocked" ],
		True, errorMessageBox[ ToString @ failure[ "Message" ], opts, Appearance -> "Fatal" ]
	];

errorMessageBox[ text_, opts: OptionsPattern[ ] ] := errorMessageBox[ { text, None }, None, opts ]

errorMessageBox[ { messageText_, buttonText_ }, action_, opts: OptionsPattern[ ] ] :=
With[
	{
		appearance = Replace[ OptionValue[ Appearance ], Except[ _String ] :> "NonFatal" ],
		reducedOpts = DeleteCases[ Flatten[ { opts } ], _[ ImageSize, _ ]]
	},
	errorMessageFrame[
		appearance,
		Replace[
			OptionValue[ImageSize],
			Automatic :>
				If[ TrueQ @ AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[], { TaggingRules, "ChatNotebookSettings", "WorkspaceChat" } ],
					{ { 296, 366 }, Automatic }, (* messages in the NA window are allowed to be larger *)
					296
				]
		],
		Grid[
			{
				If[ appearance === "Blocked",
					{
						Item[ Pane[ chatbookIcon[ "RateLimit", False ], Alignment -> { Center, Top }, ImageSize -> Scaled[ 1 ]] ],
						Item[ errorMessageCloseButton @ reducedOpts, Alignment -> { Right, Top }, ItemSize -> Fit ]
					},
					Nothing
				],
				If[ appearance === "Blocked",
					{ messageText, SpanFromLeft },
					{ messageText, Item[ errorMessageCloseButton @ reducedOpts, Alignment -> { Right, Baseline }, ItemSize -> Fit ] }
				],
				If[ buttonText ===  None || Unevaluated[ action ] === None,
					{
						errorMessageLink[ tr @ "UIMessageContactUs", SystemOpen @ URL[ "https://www.wolfram.com/support/contact" ], reducedOpts ],
						SpanFromLeft
					},
					{
						Grid[
							{ {
								If[ buttonText ===  None || Unevaluated[ action ] === None,
									Nothing,
									errorMessageLabeledButton[ buttonText, action, reducedOpts ]
								],
								errorMessageLink[ tr @ "UIMessageContactUs", SystemOpen @ URL[ "https://www.wolfram.com/support/contact" ], reducedOpts ]
							} },
							Alignment -> { Left, Baseline },
							BaselinePosition -> { 1, 1 },
							Spacings -> { 1, 0 }
						],
						SpanFromLeft
					}
				]
			},
			Alignment -> { Left, Baseline },
			Spacings -> { 0, 0.8 }
		]
	]
]

errorMessageBox[ "UsageAt80" ] :=
	errorMessageBox[
		{ tr @ "UIMessageUsed80", tr @ "UIMessageManageSubscription" },
		Wolfram`LLMFunctions`Common`OpenLLMKitURL @ "Manage"
	];

errorMessageBox[ "UsageAt100" ] :=
	errorMessageBox[
		{ tr @ "UIMessageUsedAll", tr @ "UIMessageManageSubscription" },
		Wolfram`LLMFunctions`Common`OpenLLMKitURL @ "Manage",
		Appearance -> "Fatal"
	];

errorMessageBox[ "UsageBlocked" ] :=
	errorMessageBox[
		{ tr @ "UIMessageHighUsageRate", tr @ "UIMessageUnblockRequest" },
		SystemOpen @ URL[ "https://www.wolfram.com/support/contact" ], (* TODO: there may be a better URL than this *)
		Appearance -> "Blocked"
	];

errorMessageBox // endDefinition;


$$usageLimitCode = Alternatives[
    "request-per-minute-limit-exceeded",
    "credits-per-minute-limit-exceeded",
    "request-per-hour-limit-exceeded",
    "credits-per-hour-limit-exceeded",
    "request-per-month-limit-exceeded",
    "credits-per-month-limit-exceeded"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*errorMessageFrame*)
errorMessageFrame // beginDefinition;

errorMessageFrame[ "Fatal", size_, content_ ] :=
	Framed[
		Style[ content, FontColor -> color @ "ErrorMessageFatalFont" ],
		$commonErrorFrameOptions, ImageSize -> size,
		Background -> color @ "ErrorMessageFatalBackground",
		FrameStyle -> Directive[ AbsoluteThickness[ 2 ], color @ "ErrorMessageFatalFrame" ] ];

errorMessageFrame[ "NonFatal", size_, content_ ] :=
	Framed[
		Style[ content, FontColor -> color @ "ErrorMessageNonFatalFont" ],
		$commonErrorFrameOptions, ImageSize -> size,
		Background -> color @ "ErrorMessageNonFatalBackground",
		FrameStyle -> Directive[ AbsoluteThickness[ 2 ], color @ "ErrorMessageNonFatalFrame" ] ];

errorMessageFrame[ "Blocked", size_, content_ ] :=
	Framed[
		Style[ content, FontColor -> color @ "ErrorMessageBlockedFont" ],
		$commonErrorFrameOptions, ImageSize -> size,
		Background -> color @ "ErrorMessageBlockedBackground",
		FrameStyle -> Directive[ AbsoluteThickness[ 2 ], color @ "ErrorMessageBlockedFrame" ] ];

errorMessageFrame // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*errorMessageLabeledButton*)
errorMessageLabeledButton // beginDefinition;

Attributes[ errorMessageLabeledButton ] = { HoldRest };
Options[ errorMessageLabeledButton ] = { Appearance -> "NonFatal" };

errorMessageLabeledButton[ text_, action_, OptionsPattern[ ] ] :=
Button[
	errorMessageLabeledButtonAppearance[ OptionValue[ Appearance ], text ],
	action,
	Appearance       -> "Suppressed",
	BaselinePosition -> Baseline,
	ImageSize        -> Automatic
];

errorMessageLabeledButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*errorMessageLabeledButtonAppearance*)
errorMessageLabeledButtonAppearance // beginDefinition;

errorMessageLabeledButtonAppearance[ "Fatal", text_ ] :=
mouseDown[
	Framed[
		Style[ text, FontColor -> color @ "ErrorMessageFatalFont" ],
		$commonLabeledButtonOptions,
		Background -> color @ "ErrorMessageFatalLabelButtonBackground",
		FrameStyle -> color @ "ErrorMessageFatalLabelButtonBackground" ],
	Framed[
		Style[ text, FontColor -> color @ "ErrorMessageFatalFont" ],
		$commonLabeledButtonOptions,
		Background -> color @ "ErrorMessageFatalLabelButtonBackgroundHover",
		FrameStyle -> color @ "ErrorMessageFatalLabelButtonFrameHover" ],
	Framed[
		Style[ text, FontColor -> color @ "ErrorMessageFatalFont" ],
		$commonLabeledButtonOptions,
		Background -> color @ "ErrorMessageFatalLabelButtonBackgroundPressed",
		FrameStyle -> color @ "ErrorMessageFatalLabelButtonBackgroundPressed" ]
]

errorMessageLabeledButtonAppearance[ "NonFatal", text_ ] :=
mouseDown[
	Framed[
		Style[ text, FontColor -> color @ "ErrorMessageNonFatalFont" ],
		$commonLabeledButtonOptions,
		Background -> color @ "ErrorMessageNonFatalLabelButtonBackground",
		FrameStyle -> color @ "ErrorMessageNonFatalLabelButtonBackground" ],
	Framed[
		Style[ text, FontColor -> color @ "ErrorMessageNonFatalFont" ],
		$commonLabeledButtonOptions,
		Background -> color @ "ErrorMessageNonFatalLabelButtonBackgroundHover",
		FrameStyle -> color @ "ErrorMessageNonFatalLabelButtonFrameHover" ],
	Framed[
		Style[ text, FontColor -> color @ "ErrorMessageNonFatalFont" ],
		$commonLabeledButtonOptions,
		Background -> color @ "ErrorMessageNonFatalLabelButtonBackgroundPressed",
		FrameStyle -> color @ "ErrorMessageNonFatalLabelButtonBackgroundPressed" ]
]

errorMessageLabeledButtonAppearance[ "Blocked", text_ ] :=
mouseDown[
	Framed[
		Style[ text, FontColor -> color @ "ErrorMessageBlockedFont" ],
		$commonLabeledButtonOptions,
		Background -> color @ "ErrorMessageBlockedLabelButtonBackground",
		FrameStyle -> color @ "ErrorMessageBlockedLabelButtonBackground" ],
	Framed[
		Style[ text, FontColor -> color @ "ErrorMessageBlockedFont" ],
		$commonLabeledButtonOptions,
		Background -> color @ "ErrorMessageBlockedLabelButtonBackgroundHover",
		FrameStyle -> color @ "ErrorMessageBlockedLabelButtonFrameHover" ],
	Framed[
		Style[ text, FontColor -> color @ "ErrorMessageBlockedFont" ],
		$commonLabeledButtonOptions,
		Background -> color @ "ErrorMessageBlockedLabelButtonBackgroundPressed",
		FrameStyle -> color @ "ErrorMessageBlockedLabelButtonBackgroundPressed" ]
]

errorMessageLabeledButtonAppearance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*errorMessageCloseButton*)
errorMessageCloseButton // beginDefinition;

Options[ errorMessageCloseButton ] = { Appearance -> "NonFatal" };

errorMessageCloseButton[ OptionsPattern[ ] ] :=
Button[
	errorMessageCloseButtonAppearance[ OptionValue[ Appearance ] ],
	(* Cloud-25777:
		We need to coerce the cloud to send the evaluation through the kernel instead of the JS evaluator.
		We accomplish this with a hack: include an unknown symbol with no side effects. *)
	(
		CloudSystem`Private`NoValue`Cloud25777;
		NotebookDelete[ EvaluationCell[ ] ] ),
	Appearance       -> "Suppressed",
	BaselinePosition -> Baseline,
	ImageSize        -> Automatic
];

errorMessageCloseButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*errorMessageCloseButtonAppearance*)
errorMessageCloseButtonAppearance // beginDefinition;

errorMessageCloseButtonAppearance[ "NonFatal" ] :=
mouseDown[
	chatbookIcon[ "Close", False, color @ "ErrorMessageNonFatalCloseButtonFrame",        color @ "ErrorMessageNonFatalCloseButtonBackground",        color @ "ErrorMessageNonFatalFont"],
	chatbookIcon[ "Close", False, color @ "ErrorMessageNonFatalCloseButtonFrameHover",   color @ "ErrorMessageNonFatalCloseButtonBackgroundHover",   color @ "ErrorMessageNonFatalFont"],
	chatbookIcon[ "Close", False, color @ "ErrorMessageNonFatalCloseButtonFramePressed", color @ "ErrorMessageNonFatalCloseButtonBackgroundPressed", color @ "ErrorMessageNonFatalFont"]
]

errorMessageCloseButtonAppearance[ "Fatal" ] :=
mouseDown[
	chatbookIcon[ "Close", False, color @ "ErrorMessageFatalCloseButtonFrame",        color @ "ErrorMessageFatalCloseButtonBackground",        color @ "ErrorMessageFatalFont"],
	chatbookIcon[ "Close", False, color @ "ErrorMessageFatalCloseButtonFrameHover",   color @ "ErrorMessageFatalCloseButtonBackgroundHover",   color @ "ErrorMessageFatalFont"],
	chatbookIcon[ "Close", False, color @ "ErrorMessageFatalCloseButtonFramePressed", color @ "ErrorMessageFatalCloseButtonBackgroundPressed", color @ "ErrorMessageFatalFont"]
]

errorMessageCloseButtonAppearance[ "Blocked" ] :=
mouseDown[
	chatbookIcon[ "Close", False, color @ "ErrorMessageBlockedCloseButtonFrame",        color @ "ErrorMessageBlockedCloseButtonBackground",        color @ "ErrorMessageBlockedFont"],
	chatbookIcon[ "Close", False, color @ "ErrorMessageBlockedCloseButtonFrameHover",   color @ "ErrorMessageBlockedCloseButtonBackgroundHover",   color @ "ErrorMessageBlockedFont"],
	chatbookIcon[ "Close", False, color @ "ErrorMessageBlockedCloseButtonFramePressed", color @ "ErrorMessageBlockedCloseButtonBackgroundPressed", color @ "ErrorMessageBlockedFont"]
]

errorMessageCloseButtonAppearance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*errorMessageLink*)
errorMessageLink // beginDefinition;

Attributes[ errorMessageLink ] = { HoldRest };
Options[ errorMessageLink ] = { Appearance -> "NonFatal" };

errorMessageLink[ text_, action_, OptionsPattern[ ] ] :=
Button[
	errorMessageLinkAppearance[ OptionValue[ Appearance ], text ],
	action,
	Appearance       -> "Suppressed",
	BaselinePosition -> Baseline,
	ImageSize        -> Automatic
];

errorMessageLink // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*errorMessageLinkAppearance*)
errorMessageLinkAppearance // beginDefinition;

errorMessageLinkAppearance[ "Fatal" , text_ ] :=
Mouseover[
	Style[ text, FontColor -> color @ "ErrorMessageFatalFont", $commonErrorLinkOptions ],
	Style[ text, FontColor -> color @ "ErrorMessageFatalLinkFontHover", $commonErrorLinkOptions ],
	BaselinePosition -> Baseline ]

errorMessageLinkAppearance[ "NonFatal", text_ ] :=
Mouseover[
	Style[ text, FontColor -> color @ "ErrorMessageNonFatalFont", $commonErrorLinkOptions ],
	Style[ text, FontColor -> color @ "ErrorMessageNonFatalLinkFontHover", $commonErrorLinkOptions ],
	BaselinePosition -> Baseline ]

errorMessageLinkAppearance[ "Blocked", text_ ] :=
Mouseover[
	Style[ text, FontColor -> color @ "ErrorMessageBlockedFont", $commonErrorLinkOptions ],
	Style[ text, FontColor -> color @ "ErrorMessageBlockedLinkFontHover", $commonErrorLinkOptions ],
	BaselinePosition -> Baseline ]

errorMessageLinkAppearance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cell Dingbats*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MakeChatInputActiveCellDingbat*)
MakeChatInputActiveCellDingbat[ mouseOver_:Automatic ] :=
	DynamicModule[ { cell },
		trackedDynamic[ MakeChatInputActiveCellDingbat[ cell, mouseOver ], { "ChatBlock" } ],
		Initialization :> (cell = EvaluationCell[ ]; Needs[ "Wolfram`Chatbook`" -> None ]),
		UnsavedVariables :> { cell }
	];

MakeChatInputActiveCellDingbat[ dingbatCell_CellObject, mouseOver_ ] := With[{
	targetCell = parentCell @ dingbatCell
},
	Button[
		Framed[
			Pane[
				getPersonaMenuIcon @ currentValueOrigin[ targetCell, { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ][[ 2 ]],
				Alignment -> {Center, Center}, ImageSize -> {25, 25}, ImageSizeAction -> "ShrinkToFit"
			],
			RoundingRadius -> 2,
			FrameStyle ->
				If[ TrueQ @ mouseOver,
					color @ "ChatDingbatFrameHover",
					Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, None ] ]&[ color @ "ChatDingbatFrameHover" ]
				],
			Background ->
				If[ TrueQ @ mouseOver,
					color @ "ChatDingbatBackgroundHover",
					Dynamic[ If[ CurrentValue[ "MouseOver" ], #, None ] ]&[ color @ "ChatDingbatBackgroundHover" ]
				],
			FrameMargins -> 0,
			ImageMargins -> 0,
			ContentPadding -> False
		],
		If[ Cells[ dingbatCell, AttachedCell -> True, CellStyle -> "AttachedChatMenu" ] === { },
			MakeMenu[
				makeChatActionMenu[ "Input", targetCell ],
				TaggingRules -> <|
					"ActionScope" -> targetCell,
					"Anchor"      -> dingbatCell,
					"IsRoot"      -> True
				|>
			]
		],
		Appearance -> $suppressButtonAppearance,
		ImageMargins -> 0,
		FrameMargins -> 0,
		ContentPadding -> False
	]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MakeChatInputCellDingbat*)
MakeChatInputCellDingbat[] :=
	PaneSelector[
		{
			True -> MakeChatInputActiveCellDingbat[ True ],
			False -> Button[(* I hate this: the only reason for this Button wrapper is to prevent jittery redraws due to mismatched sizes on mouse-over *)
				Framed[
					Pane[RawBoxes @ TemplateBox[{}, "ChatIconUser"], Alignment -> {Center, Center}, ImageSize -> {25, 25}, ImageSizeAction -> "ShrinkToFit"],
					Background     -> None,
					ContentPadding -> False,
					FrameMargins   -> 0,
					FrameStyle     -> None,
					ImageMargins   -> 0,
					RoundingRadius -> 2
				],
				Null,
				Appearance -> None,
				ImageMargins -> 0,
				FrameMargins -> 0,
				ContentPadding -> False
			]
		},
		Dynamic[CurrentValue["MouseOver"]],
		ImageSize -> Automatic
	]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MakeChatDelimiterCellDingbat*)
MakeChatDelimiterCellDingbat[ ] :=
	DynamicModule[ { Wolfram`ChatNB`cell },
		trackedDynamic[ MakeChatDelimiterCellDingbat @ Wolfram`ChatNB`cell, { "ChatBlock" } ],
		Initialization :> (
			Wolfram`ChatNB`cell = EvaluationCell[ ];
			Needs[ "Wolfram`Chatbook`" -> None ];
			Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "UpdateDynamics", "ChatBlock" ]
		),
		Deinitialization :> (
			Needs[ "Wolfram`Chatbook`" -> None ];
			Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "UpdateDynamics", "ChatBlock" ]
		),
		UnsavedVariables :> { Wolfram`ChatNB`cell }
	];

MakeChatDelimiterCellDingbat[ frameLabelCell_CellObject ] := With[ {
	targetCell = parentCell @ frameLabelCell
},
	Button[
		Framed[
			Pane[
				getPersonaMenuIcon @ currentValueOrigin[ targetCell, { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ][[ 2 ]],
				Alignment -> { Center, Center }, ImageSize -> { 25, 25 }, ImageSizeAction -> "ShrinkToFit" ],
			RoundingRadius -> 2,
			FrameStyle     -> (Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, None ] ]&[ color @ "ChatDingbatFrameHover" ]),
			Background     -> (Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, None ] ]&[ color @ "ChatDingbatBackgroundHover" ]),
			FrameMargins   -> 0,
			ImageMargins   -> 0,
			ContentPadding -> False
		],
		If[ Cells[ frameLabelCell, AttachedCell -> True, CellStyle -> "AttachedChatMenu" ] === { },
			MakeMenu[
				makeChatActionMenu[ "Delimiter", targetCell ],
				TaggingRules -> <|
					"ActionScope" -> targetCell,
					"Anchor"      -> frameLabelCell,
					"IsRoot"      -> True
				|>
			]
		],
		Appearance     -> $suppressButtonAppearance,
		ImageMargins   -> 0,
		FrameMargins   -> 0,
		ContentPadding -> False
	]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*filterPersonas*)
filterPersonas // beginDefinition;

filterPersonas[ targetObj_ ] :=
Module[ { personas },
	personas = GetPersonasAssociation[ "IncludeHidden" -> False ];

	RaiseConfirmMatch[personas, <| (_String -> _Association)... |>];

	(* initialize PrivateFrontEndOptions if they aren't already present or somehow broke *)
	If[!MatchQ[CurrentChatSettings[$FrontEnd, "VisiblePersonas"], {___String}],
        CurrentChatSettings[$FrontEnd, "VisiblePersonas"] = DeleteCases[
			Keys[personas],
			Alternatives["Birdnardo", "RawModel", "Wolfie"]
		]
	];
	If[!MatchQ[CurrentChatSettings[$FrontEnd, "PersonaFavorites"], {___String}],
        CurrentChatSettings[$FrontEnd, "PersonaFavorites"] = {"CodeAssistant", "CodeWriter", "PlainChat"}
	];

	(* only show visible personas and sort visible personas based on favorites setting *)
	personas = KeyTake[
		personas,
		CurrentChatSettings[$FrontEnd, "VisiblePersonas"]
	];
	personas = With[{
		favorites = CurrentChatSettings[$FrontEnd, "PersonaFavorites"]
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

	personas
];

filterPersonas // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeChatActionMenu*)
SetFallthroughError[makeChatActionMenu]

makeChatActionMenu[
	containerType: "Input" | "Delimiter" | "Toolbar" | "SideBar",
	targetObj : _CellObject | _NotebookObject
] :=
Join[
	{
		<|
			"Type"           -> "Header",
			"Label"          -> tr @ "UIPersonas",
			"ResetAction"    :> (CurrentValue[ targetObj, { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ] = Inherited),
			"ResetCondition" :> (CurrentValue[ targetObj, { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ] =!= Inherited)
		|>
	},
	With[
		{
			personaValue = currentValueOrigin[ targetObj, { TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ]
		} ,
		KeyValueMap[ { persona, personaSettings } |->
			<|
				"Type"   -> "Setter", (* automatically closes the menu in addition to performing the Action *)
				"Label"  -> personaDisplayName[ persona, personaSettings ],
				"Icon"   -> getPersonaMenuIcon @ personaSettings,
				"Check"  -> styleListItem[ persona, personaValue ],
				"Action" :> (
					CurrentValue[ targetObj, {TaggingRules, "ChatNotebookSettings", "LLMEvaluator" } ] = persona;
					updateDynamics[ { "ChatBlock" } ];
					(* If we're changing the persona set on a cell, ensure that we are not showing
						the static "ChatInputCellDingbat" that is set when a ChatInput is evaluated. *)
					If[ Head[ targetObj ] === CellObject, SetOptions[ targetObj, CellDingbat -> Inherited ]; ]
				),
				"Value"    -> persona,
				"Category" -> "Persona"
			|>,
			filterPersonas @ targetObj
		]
	],
	{
		<| "Type" -> "Delimiter" |>,
		<|
			"Type"   -> "Button",
			"Label"  -> tr @ "UIAddAndManagePersonas",
			"Icon"   -> getIcon @ "PersonaOther",
			"Action" :> (
				Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
				Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "PersonaManage", targetObj ];)
		|>,
		<|
			"Type"   -> "Button",
			"Label"  -> tr @ "UIAddAndManageTools",
			"Icon"   -> getIcon @ "ToolManagerRepository",
			"Action" :> (
				Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
				Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ToolManage", targetObj ];)
		|>,
		<| "Type" -> "Delimiter" |>,
		<|
			"Type"    -> "Submenu",
			"Label"   -> tr @ "UIModels",
			"Icon"    -> getIcon @ "ChatBlockSettingsMenuIcon",
			"MenuTag" -> "Services",
			"Menu"    :> createServiceMenu @ targetObj,
			"Width"    -> 150,
			"ResetAction"    :> (CurrentValue[ targetObj, { TaggingRules, "ChatNotebookSettings", "Model" } ] = Inherited),
			"ResetCondition" :> (CurrentValue[ targetObj, { TaggingRules, "ChatNotebookSettings", "Model" } ] =!= Inherited)
		|>,
		<|
			"Type"    -> "Submenu",
			"Label"   -> tr @ "UIAdvancedSettings",
			"Icon"    -> getIcon @ "AdvancedSettings",
			"MenuTag" -> "AdvancedSettings",
			"Menu"    :> createAdvancedSettingsMenu[ targetObj, None ],
			"Width"   -> 200
		|>
	}
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getIcon*)
getIcon[ name_ ] := Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", name ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Advanced settings submenu*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createAdvancedSettingsMenu*)
createAdvancedSettingsMenu // beginDefinition;

createAdvancedSettingsMenu[ targetObj_, appContainer_ ] :=
With[
	{
		roleValue = Replace[ currentValueOrigin[ targetObj, { TaggingRules, "ChatNotebookSettings", "Role" } ], { source_, Inherited } :> { source, "User" } ]
	},
	Join[
		{
			<| "Type" -> "Header", "Label"   -> tr @ "UIAdvancedTemperature" |>,
			<| "Type" -> "Custom", "Content" -> makeTemperatureSlider[ targetObj, appContainer ] |>,
			<| "Type" -> "Header", "Label"   -> tr @ "UIAdvancedToolCallFrequency" |>,
			<| "Type" -> "Custom", "Content" -> makeToolCallFrequencySlider[ targetObj, appContainer ] |>,
			<| "Type" -> "Header", "Label"   -> tr @ "UIAdvancedRoles" |>
		},
		Map[
			entry |-> ConfirmReplace[entry, {
				{role_?StringQ, icon_} :> <|
					"Type"   -> "Setter",
					"Icon"   -> icon,
					"Label"  -> role,
					"Check"  -> styleListItem[ role, roleValue ],
					"Action" :> (CurrentValue[ targetObj, { TaggingRules, "ChatNotebookSettings", "Role" }] = role)
				|>
			}],
			{
				{ "User",   getIcon @ "ChatIconUser" },
				{ "System", getIcon @ "RoleSystem" }
			}
		]
	]
];

createAdvancedSettingsMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Model selection submenu*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*wolframServiceMenuItem*)
wolframServiceMenuItem // beginDefinition;

wolframServiceMenuItem[ targetObj_, model_ ] :=
<|
	"Type"   -> "Setter",
	"Label"  -> "Wolfram",
	"Icon"   -> serviceIcon[ model, "Wolfram" ],
	"Check"  -> serviceIconCheck[ model, "Wolfram" ],
	"Action" :> (setModel[ targetObj, <| "Service" -> "LLMKit", "Name" -> Automatic |> ]),
	"Value"    -> "LLMKit",
	"Category" -> "Service"
|>

wolframServiceMenuItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createServiceMenu*)
createServiceMenu // beginDefinition;

createServiceMenu[ targetObj_ ] :=
With[
	{
		model = currentChatSettings[ targetObj, "Model" ]
	},
	Join[
		{
			<| "Type" -> "Header", "Label" -> tr @ "UIModelsServices" |>,
			wolframServiceMenuItem[ targetObj, model ],
			<| "Type" -> "Delimiter" |>
		},
		Map[
			createServiceItem[ targetObj, model, #1 ] &,
			DeleteCases[ getAvailableServiceNames[ "IncludeHidden" -> False ], "Wolfram" ] ]
	]
] /; AssociationQ @ $serviceCache;

createServiceMenu[ targetObj_ ] := {
With[
	{
		model = currentChatSettings[ targetObj, "Model" ]
	},
	<|
		"Type"        -> "Delayed",
		"InitialMenu" -> {
			<| "Type" -> "Header", "Label" -> tr @ "UIModelsServices" |>,
			wolframServiceMenuItem[ targetObj, model ],
			<| "Type" -> "Delimiter" |>,
			<|
				"Type"    -> "Custom",
				"Content" ->
					Pane[
						Column @ {
							Style[ tr @ "UIModelsServicesGet", "ChatMenuLabel" ],
							ProgressIndicator[ Appearance -> "Percolate" ]
						},
						ImageMargins -> 5
					]
			|>
		},
		"FinalMenu" :>
			Join[
				{
					<| "Type" -> "Header", "Label" -> tr @ "UIModelsServices" |>,
					wolframServiceMenuItem[ targetObj, model ],
					<| "Type" -> "Delimiter" |>
				},
				Map[
					createServiceItem[ targetObj, model, #1 ] &,
					DeleteCases[ getAvailableServiceNames[ "IncludeHidden" -> False ], "Wolfram" ] ]
			]
	|>
]
};

createServiceMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createServiceItem*)
createServiceItem // beginDefinition;

createServiceItem[ obj_, model_, service_String ] := <|
    "Type"    -> "Submenu",
    "Label"   -> service,
    "Icon"    -> serviceIcon[ model, service ],
    "Menu"    :> dynamicModelMenu[ obj, model, service ],
    "MenuTag" -> service,
    "Width"   -> 280,
    "Check"   -> serviceIconCheck[ model, service ],
    "Value"    -> service,
    "Category" -> "Service"
|>;

createServiceItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*serviceIconCheck*)
serviceIconCheck // beginDefinition;

serviceIconCheck[ model_String, "OpenAI" ] := True;

serviceIconCheck[ model: KeyValuePattern[ "Service" -> "LLMKit" ], "Wolfram" ] := True;

serviceIconCheck[ model: KeyValuePattern[ "Service" -> service_String ], service_String ] := True

(* Otherwise hide the checkmark: *)
serviceIconCheck[ model_, service_String ] := False;

serviceIconCheck // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*serviceIcon*)
serviceIcon // beginDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Definitions for the model submenu*)

(* OpenAI is the only service that can have raw strings as a model spec: *)
serviceIcon[ model_String, "OpenAI" ] := serviceIcon @ "OpenAI";

(* LLMKit service is provided by Wolfram *)
serviceIcon[ model: KeyValuePattern[ "Service" -> "LLMKit" ], "Wolfram" ] := serviceIcon @ "Wolfram";

(* Show a checkmark if the currently selected model belongs to this service: *)
serviceIcon[ model: KeyValuePattern[ "Service" -> service_String ], service_String ] := serviceIcon @ service;

(* Otherwise hide the checkmark: *)
serviceIcon[ model_, service_String ] := serviceIcon @ service;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Services specified as associations*)
(* These services have template box definitions for icons built into the chatbook stylesheet: *)
serviceIcon[ KeyValuePattern[ "Service" -> service: "OpenAI"|"Anthropic"|"PaLM" ] ] :=
	serviceIcon @ service;

(* Evaluate delayed icon specs: *)
serviceIcon[ as: KeyValuePattern[ "Icon" :> icon_ ] ] :=
    serviceIcon @ <| as, "Icon" -> icon |>;

(* Use the icon specified in the service specification: *)
serviceIcon[ KeyValuePattern @ { "Service" -> _String, "Icon" -> icon: Except[ ""|$$unspecified ] } ] :=
    icon;

(* Fallback to name-based icon: *)
serviceIcon[ KeyValuePattern[ "Service" -> service_String ] ] :=
    serviceIcon @ service;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Services specified as strings*)

(* Services with icons defined in template boxes: *)
serviceIcon[ "Wolfram"   ] := chatbookIcon[ "llmkit-dialog-sm"    , False ];
serviceIcon[ "OpenAI"    ] := chatbookIcon[ "ServiceIconOpenAI"   , False ];
serviceIcon[ "Anthropic" ] := chatbookIcon[ "ServiceIconAnthropic", False ];
serviceIcon[ "PaLM"      ] := chatbookIcon[ "ServiceIconPaLM"     , False ];

(* Otherwise look in registered service info for an icon: *)
serviceIcon[ service_String ] := Replace[ $availableServices[ service, "Icon" ], $$unspecified -> "" ];

serviceIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dynamicModelMenu*)
dynamicModelMenu // beginDefinition;

dynamicModelMenu[ obj_, model_, service_? modelListCachedQ ] := makeServiceModelMenu[ obj, model, service ];

dynamicModelMenu[ obj_, model_, service_ ] := {
	<|
		"Type"        -> "Delayed",
		"InitialMenu" -> {
			<| "Type" -> "Header", "Label" -> service |>,
			<|
				"Type"    -> "Custom",
				"Content" ->
					Pane[
						Column @ {
							Style[ tr @ "UIModelsGet", "ChatMenuLabel" ],
							ProgressIndicator[ Appearance -> "Percolate" ]
						},
						ImageMargins -> 5
					]
			|>
		},
		"FinalMenu" :> (
			Quiet[
				Needs[ "Wolfram`Chatbook`" -> None ];
				catchAlways @ makeServiceModelMenu[ obj, model, service ]
			]
		)
	|>
};

dynamicModelMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeServiceModelMenu*)
makeServiceModelMenu // beginDefinition;

makeServiceModelMenu[ obj_, currentModel_, service_String ] :=
    makeServiceModelMenu[
        obj,
        currentModel,
        service,
        Block[ { $allowConnectionDialog = False }, getServiceModelList @ service ]
    ];

makeServiceModelMenu[ obj_, currentModel_, service_String, models_List ] :=
Join[
	{ <| "Type" -> "Header", "Label" -> service |> },
	groupMenuModels[ obj, currentModel, models ]
]

makeServiceModelMenu[ obj_, currentModel_, service_String, Missing[ "NotConnected" ] ] :=
{
	<| "Type" -> "Header", "Label" -> service |>,
	<|
		"Type"        -> "Refresh",
		"Label"       -> tr @ "UIModelsNoList",
		"InitialMenu" :> (simpleModelMenuDisplay[ service, ProgressIndicator[ Appearance -> "Percolate" ] ]),
		"FinalMenu"   :> (makeServiceModelMenu[ obj, currentModel, service, getServiceModelList @ service ]),
		"Value"       -> None,
		"Category"    -> "ModelName"
	|>
}

makeServiceModelMenu[ obj_, currentModel_, service_String, Missing[ "NoModelList" ] ] :=
{
	<| "Type" -> "Header", "Label" -> service |>,
	<|
		"Type"   -> "Setter",
		"Label"  -> "Automatic",
		(* TODO: this could probably prompt the user with an InputField to enter a name: *)
		"Action" :> setModel[ obj, <| "Service" -> service, "Name" -> Automatic |> ],
		"Value"  -> None,
		"Category" -> "ModelName"
	|>
}

makeServiceModelMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*simpleModelMenuDisplay*)
simpleModelMenuDisplay // beginDefinition;
simpleModelMenuDisplay[ service_, expr_ ] := { <| "Type" -> "Header", "Label" -> service |>, <| "Type" -> "Custom", "Content" -> expr |> };
simpleModelMenuDisplay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*groupMenuModels*)
groupMenuModels // beginDefinition;

groupMenuModels[ obj_, currentModel_, models_List ] :=
    groupMenuModels[
		obj,
		currentModel,
		Map[
			ReverseSortBy[ { Lookup[ "Family" ], Lookup[ "BaseName" ], Lookup[ "Date" ] } ],
			GroupBy[ models, modelGroupName ]
		]
	];

groupMenuModels[ obj_, currentModel_, models_Association ] /; Length @ models === 1 :=
    modelMenuItem[ obj, currentModel ] /@ First @ models;

groupMenuModels[ obj_, currentModel_, models_Association ] :=
    Flatten[ KeyValueMap[ menuModelGroup[ obj, currentModel ], models ], 1 ];

groupMenuModels // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*menuModelGroup*)
menuModelGroup // beginDefinition;

menuModelGroup[ obj_, currentModel_ ] :=
    menuModelGroup[ obj, currentModel, ## ] &;

menuModelGroup[ obj_, currentModel_, None, models_List ] :=
    modelMenuItem[ obj, currentModel ] /@ models;

menuModelGroup[ obj_, currentModel_, name_String, models_List ] :=
    Join[ { <| "Type" -> "Header", "Label" -> name |> }, modelMenuItem[ obj, currentModel ] /@ models ];

menuModelGroup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*modelGroupName*)
modelGroupName // beginDefinition;
modelGroupName[ KeyValuePattern[ "FineTuned" -> True ] ] := trRaw[ "UIModelsFineTuned" ];
modelGroupName[ KeyValuePattern[ "Preview"   -> True ] ] := trRaw[ "UIModelsPreview"   ];
modelGroupName[ KeyValuePattern[ "Snapshot"  -> True ] ] := trRaw[ "UIModelsSnapshot"  ];
modelGroupName[ _ ] := None;
modelGroupName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*modelMenuItem*)
modelMenuItem // beginDefinition;

modelMenuItem[ obj_, currentModel_ ] := modelMenuItem[ obj, currentModel, #1 ] &;

modelMenuItem[
    obj_,
    currentModel_,
    model: KeyValuePattern @ { "Name" -> name_, "Icon" -> icon_, "DisplayName" -> displayName_ }
] := <|
	"Type"   -> "Setter",
	"Label"  -> displayName,
	"Icon"   -> None,
	"Check"  -> modelSelectionCheckmark[ currentModel, name ],
	"Action" :> (setModel[ obj, model ]),
	"Value"    -> name,
	"Category" -> "ModelName"
|>;

modelMenuItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*modelSelectionCheckmark*)
modelSelectionCheckmark // beginDefinition;
modelSelectionCheckmark[ KeyValuePattern[ "Name" -> model: Automatic ], model: Automatic ] := True; (* LLMKit *)
modelSelectionCheckmark[ KeyValuePattern[ "Name" -> model_String ], model_String ] := True;
modelSelectionCheckmark[ model_String, model_String ] := True;
modelSelectionCheckmark[ _, _ ] := False;
modelSelectionCheckmark // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setModel*)
setModel // beginDefinition;

setModel[ obj_, KeyValuePattern @ { "Service" -> service_String, "Name" -> model: _String|Automatic } ] := (
    CurrentValue[ obj, { TaggingRules, "ChatNotebookSettings", "Model" } ] =
        <| "Service" -> service, "Name" -> model |>
);

setModel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Chat settings lookup helpers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*absoluteCurrentValueOrigin*)
SetFallthroughError[absoluteCurrentValueOrigin]

absoluteCurrentValueOrigin[cell_, {TaggingRules, "ChatNotebookSettings", key_}] := currentChatSettings[cell, key]
absoluteCurrentValueOrigin[cell_, keyPath_] := AbsoluteCurrentValue[cell, keyPath]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*currentValueOrigin*)
currentValueOrigin // beginDefinition;

(*
	Get the current value and origin of a cell option value.

	This function will return {origin, value}, where `origin` will be one of:

	* "Inline"    -- this value is set inline in the specified CellObject
	* "Inherited" -- this value is inherited from a style setting outside of the
		specified CellObject.
*)
currentValueOrigin[
	targetObj : _CellObject,
	keyPath_List
] := Module[{
	value,
	inlineValue
},
	value = absoluteCurrentValueOrigin[targetObj, keyPath];

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

currentValueOrigin[
	nbObj_NotebookObject,
	keyPath: { TaggingRules, "ChatNotebookSettings", key_ }
] := Module[ { value },
	value = CurrentValue[ nbObj, { TaggingRules, "ChatNotebookSettings", key } ];

	If[ value === Inherited,
		{ "Inherited", CurrentChatSettings[ nbObj, key ] },
		{ "Inline", value }
	]
]

currentValueOrigin // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getModelsMenuItems*)
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


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Menu construction helpers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*alignedMenuIcon*)
SetFallthroughError[alignedMenuIcon]

alignedMenuIcon[possible_, current_, icon_] := alignedMenuIcon[styleListItem[possible, current], icon]
alignedMenuIcon[check_, icon_] := Row[{check, " ", resizeMenuIcon[icon]}]
(* If menu item does not utilize a checkmark, use an invisible one to ensure it is left-aligned with others *)
alignedMenuIcon[icon_] := alignedMenuIcon[Style["\[Checkmark]", ShowContents -> False], icon]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resizeMenuIcon*)
resizeMenuIcon[ icon: _Graphics|_Graphics3D ] :=
	Show[ icon, ImageSize -> { 21, 21 } ];

resizeMenuIcon[ icon_ ] := Pane[
	icon,
	ImageSize       -> { 21, 21 },
	ImageSizeAction -> "ShrinkToFit",
	ContentPadding  -> False
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*styleListItem*)
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
		{"Inline", possibleValue} :> True,
		(* This possible value is the inherited selected value. *)
		{"Inherited", possibleValue} :> Inherited,
		(* This possible value is not whatever the currently selected value is. *)
		(* Indicates to typesetting to display a hidden checkmark purely so that this
			is offset by the same amount as list items that
			display a visible checkmark. *)
		_ -> False
	}]
)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Persona property lookup helpers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*personaDisplayName*)
personaDisplayName // beginDefinition;

personaDisplayName[ name_String ] :=
	personaDisplayName[ name, GetCachedPersonaData @ name ];

personaDisplayName[ name_String, data_Association ] :=
	personaDisplayName[ name, data[ "DisplayName" ] ];

personaDisplayName[ name_String, Dynamic @ FEPrivate`FrontEndResource[ "ChatbookStrings", id_ ] ] /; $CloudEvaluation :=
    tr @ id;

personaDisplayName[ name_String, displayName: Except[ $$unspecified ] ] :=
	displayName;

personaDisplayName[ name_String, _ ] :=
	name;

personaDisplayName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getPersonaMenuIcon*)
SetFallthroughError[getPersonaMenuIcon];

getPersonaMenuIcon[ name_String ] := getPersonaMenuIcon @ Lookup[ GetPersonasAssociation[ ], name ];
getPersonaMenuIcon[ KeyValuePattern[ "Icon"|"PersonaIcon" -> icon_ ] ] := getPersonaMenuIcon @ icon;
getPersonaMenuIcon[ KeyValuePattern[ "Default" -> icon_ ] ] := getPersonaMenuIcon @ icon;
getPersonaMenuIcon[ _Missing | _Association | None ] := RawBoxes @ TemplateBox[ { }, "PersonaUnknown" ];
getPersonaMenuIcon[ icon_ ] := inlineChatbookExpressions @ icon;

(* If "Full" is specified, resolve TemplateBox icons into their literal
   icon data, so that they will render correctly in places where the Chatbook.nb
   stylesheet is not available. *)
getPersonaMenuIcon[ expr_, "Full" ] /; $VersionNumber < 14.2 := InlineTemplateBoxes @ getPersonaMenuIcon @ expr;
getPersonaMenuIcon[ expr_, "Full" ] := getPersonaMenuIcon @ expr;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getPersonaIcon*)
getPersonaIcon[ expr_ ] := getPersonaMenuIcon[ expr, "Full" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Model property lookup helpers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getModelMenuIcon*)
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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Generic Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*nestedLookup*)
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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];