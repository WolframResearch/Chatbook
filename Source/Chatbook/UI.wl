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
(*Configuration*)
$chatMenuWidth = 220;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cloud Toolbar*)

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
(*Default Notebook Toolbar*)
CreateToolbarContent[] := With[{
	nbObj = EvaluationNotebook[],
	menuCell = EvaluationCell[]
},
	CurrentValue[menuCell, {TaggingRules, "IsChatEnabled"}] =
		TrueQ[CurrentValue[nbObj, {StyleDefinitions, "ChatInput", Evaluatable}]];

	CurrentValue[menuCell, {TaggingRules, "MenuData", "Root"}] = menuCell;

	PaneSelector[
		{
			True :> (
				Dynamic[ makeToolbarMenuContent @ menuCell, SingleEvaluation -> True, DestroyAfterEvaluation -> True ]
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
];

makeToolbarMenuContent[ menuCell_ ] := Enclose[
    Module[ { items, item1, item2, new },

        items = ConfirmBy[ makeChatActionMenu[ "Toolbar", EvaluationNotebook[ ], Automatic, "List" ], ListQ, "Items" ];

        item1 = Pane[
            makeEnableAIChatFeaturesLabel @ True,
            ImageMargins -> { { 5, 20 }, { 2.5, 2.5 } }
        ];

        item2 = Pane[
            makeAutomaticResultAnalysisCheckbox @ EvaluationNotebook[ ],
            ImageMargins -> { { 5, 20 }, { 2.5, 2.5 } }
        ];

        new = Join[ { { None, item1, None }, { None, item2, None } }, items ];

        MakeMenu[ new, Transparent, $chatMenuWidth ]
    ],
    throwInternalFailure
];

(*====================================*)

SetFallthroughError[createChatNotEnabledToolbar]

createChatNotEnabledToolbar[
	nbObj_NotebookObject,
	menuCell_CellObject
] :=
	EventHandler[
		makeEnableAIChatFeaturesLabel[False],
		"MouseClicked" :> (
			tryMakeChatEnabledNotebook[nbObj, menuCell]
		),
		(* Needed so that we can open a ChoiceDialog if required. *)
		Method -> "Queued"
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
					Item[Magnify["\[WarningSign]", 3], Alignment -> Center],
					"",
					tr[ "UITryEnableChatDialogMainText" ],
					"",
					tr[ "UITryEnableChatDialogConfirm" ]
				}, BaseStyle -> {"DialogTextBasic", FontSize -> 15, LineIndent -> 0}, Spacings -> {0, 0}],
				Background -> White
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

makeEnableAIChatFeaturesLabel[ enabled_? BooleanQ ] :=
	labeledCheckbox[ enabled, tr[ "UIEnableChatFeatures" ], ! enabled ];

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
		Dynamic[ autoAssistQ @ target, setterFunction ],
		(* We can only get the tooltip to glue itself to the text by first literalizing the text resource as a string before typesetting to RowBox. *)
		Dynamic @ Row[
			{
				FrontEndResource[ "ChatbookStrings", "UIAutomaticAnalysisLabel" ],
				Spacer[ 3 ],
				Tooltip[ chatbookIcon[ "InformationTooltip", False ], FrontEndResource[ "ChatbookStrings", "UIAutomaticAnalysisTooltip" ] ]
			},
			"\[NoBreak]", StripOnInput -> True]
	]
]

(*====================================*)

SetFallthroughError[menuItemLineWrap]

menuItemLineWrap[label_, width_ : 50] :=
Pane[
	label,
	$chatMenuWidth - width,
	BaselinePosition -> Baseline, BaseStyle -> { LineBreakWithin -> Automatic, LineIndent -> -0.05, LinebreakAdjustments -> { 1, 10, 1, 0, 1 } } ]

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
			menuItemLineWrap @ label
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

makeToolCallFrequencySlider[ obj_ ] :=
    Module[ { checkbox, slider },
        checkbox = labeledCheckbox[
            Dynamic[
                currentChatSettings[ obj, "ToolCallFrequency" ] === Automatic,
                Function[
                    If[ TrueQ[ # ],
                        CurrentValue[ obj, { TaggingRules, "ChatNotebookSettings", "ToolCallFrequency" } ] = Inherited,
                        CurrentValue[ obj, { TaggingRules, "ChatNotebookSettings", "ToolCallFrequency" } ] = 0.5
                    ]
                ]
            ],
            Style[ menuItemLineWrap @ tr[ "UIAdvancedChooseAutomatically" ], "ChatMenuLabel" ]
        ];
        slider = Pane[
            Grid[
                {
                    {
                        Style[ tr[ "Rare" ], "ChatMenuLabel", FontSize -> 12 ],
                        Slider[
                            Dynamic[
                                Replace[ currentChatSettings[ obj, "ToolCallFrequency" ], Automatic -> 0.5 ],
                                (CurrentValue[ obj, { TaggingRules, "ChatNotebookSettings", "ToolCallFrequency" } ] = #) &
                            ],
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
        ];
        Pane[
            PaneSelector[
                {
                    True -> Column[ { checkbox }, Alignment -> Left ],
                    False -> Column[ { slider, checkbox }, Alignment -> Left ]
                },
                Dynamic[ currentChatSettings[ obj, "ToolCallFrequency" ] === Automatic ],
                ImageSize -> Automatic
            ],
            ImageMargins -> { { 5, 0 }, { 5, 5 } }
        ]
    ];


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
		FontColor            -> RGBColor[ "#333333" ],
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
				If[ TrueQ @ AbsoluteCurrentValue[ EvaluationNotebook[], { TaggingRules, "ChatNotebookSettings", "WorkspaceChat" } ],
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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*errorMessageFrame*)
errorMessageFrame // beginDefinition;

errorMessageFrame[ "Fatal", size_, content_ ] :=
	Framed[
		content,
		$commonErrorFrameOptions, ImageSize -> size,
		Background -> RGBColor[ "#FFF3F1" ], FrameStyle -> Directive[ AbsoluteThickness[ 2 ], RGBColor[ "#FFC4BA" ]] ];

errorMessageFrame[ "NonFatal", size_, content_ ] :=
	Framed[
		content,
		$commonErrorFrameOptions, ImageSize -> size,
		Background -> RGBColor[ "#FFFAF2" ], FrameStyle -> Directive[ AbsoluteThickness[ 2 ], RGBColor[ "#FFD8AB" ]] ];

errorMessageFrame[ "Blocked", size_, content_ ] :=
	Framed[
		content,
		$commonErrorFrameOptions, ImageSize -> size,
		Background -> RGBColor[ "#F3FBFF" ], FrameStyle -> Directive[ AbsoluteThickness[ 2 ], RGBColor[ "#AADAF4" ]] ];

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
		Style[ text, FontColor -> RGBColor[ "#333333" ] ],
		$commonLabeledButtonOptions, Background -> RGBColor[ "#FF8A7A" ], FrameStyle -> RGBColor[ "#FF8A7A" ] ],
	Framed[
		Style[ text, FontColor -> RGBColor[ "#333333" ] ],
		$commonLabeledButtonOptions, Background -> RGBColor[ "#FFCAC2" ], FrameStyle -> RGBColor[ "#FFA597" ] ],
	Framed[
		Style[ text, FontColor -> RGBColor[ "#FFFFFF" ] ],
		$commonLabeledButtonOptions, Background -> RGBColor[ "#ED6541" ], FrameStyle -> RGBColor[ "#ED6541" ] ]
]

errorMessageLabeledButtonAppearance[ "NonFatal", text_ ] :=
mouseDown[
	Framed[
		Style[ text, FontColor -> RGBColor[ "#333333" ] ],
		$commonLabeledButtonOptions, Background -> RGBColor[ "#FAC14D" ], FrameStyle -> RGBColor[ "#FAC14D" ] ],
	Framed[
		Style[ text, FontColor -> RGBColor[ "#333333" ] ],
		$commonLabeledButtonOptions, Background -> RGBColor[ "#FFE2A7" ], FrameStyle -> RGBColor[ "#FBC24E" ] ],
	Framed[
		Style[ text, FontColor -> RGBColor[ "#FFFFFF" ] ],
		$commonLabeledButtonOptions, Background -> RGBColor[ "#F09215" ], FrameStyle -> RGBColor[ "#F09215" ] ]
]

errorMessageLabeledButtonAppearance[ "Blocked", text_ ] :=
mouseDown[
	Framed[
		Style[ text, FontColor -> RGBColor[ "#333333" ] ],
		$commonLabeledButtonOptions, Background -> RGBColor[ "#7DC7EE" ], FrameStyle -> RGBColor[ "#7DC7EE" ] ],
	Framed[
		Style[ text, FontColor -> RGBColor[ "#333333" ] ],
		$commonLabeledButtonOptions, Background -> RGBColor[ "#C8E9FB" ], FrameStyle -> RGBColor[ "#A3D5F0" ] ],
	Framed[
		Style[ text, FontColor -> RGBColor[ "#FFFFFF" ] ],
		$commonLabeledButtonOptions, Background -> RGBColor[ "#3383AC" ], FrameStyle -> RGBColor[ "#3383AC" ] ]
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
	NotebookDelete[ EvaluationCell[ ] ],
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
	chatbookIcon[ "Close", False, RGBColor[ "#FAC14D" ], RGBColor[ "#FAC14D" ], RGBColor[ "#333333" ]],
	chatbookIcon[ "Close", False, RGBColor[ "#FBC24E" ], RGBColor[ "#FFE2A7" ], RGBColor[ "#333333" ]],
	chatbookIcon[ "Close", False, RGBColor[ "#F09215" ], RGBColor[ "#F09215" ], RGBColor[ "#FFFFFF" ]]
]

errorMessageCloseButtonAppearance[ "Fatal" ] :=
mouseDown[
	chatbookIcon[ "Close", False, RGBColor[ "#FF8A7A" ], RGBColor[ "#FF8A7A" ], RGBColor[ "#333333" ]],
	chatbookIcon[ "Close", False, RGBColor[ "#FFA597" ], RGBColor[ "#FFCAC2" ], RGBColor[ "#333333" ]],
	chatbookIcon[ "Close", False, RGBColor[ "#ED6541" ], RGBColor[ "#ED6541" ], RGBColor[ "#FFFFFF" ]]
]

errorMessageCloseButtonAppearance[ "Blocked" ] :=
mouseDown[
	chatbookIcon[ "Close", False, RGBColor[ "#7DC7EE" ], RGBColor[ "#7DC7EE" ], RGBColor[ "#333333" ]],
	chatbookIcon[ "Close", False, RGBColor[ "#C8E9FB" ], RGBColor[ "#A3D5F0" ], RGBColor[ "#333333" ]],
	chatbookIcon[ "Close", False, RGBColor[ "#3383AC" ], RGBColor[ "#3383AC" ], RGBColor[ "#FFFFFF" ]]
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
	Style[ text, FontColor -> RGBColor[ "#333333" ], $commonErrorLinkOptions ],
	Style[ text, FontColor -> RGBColor[ "#E15438" ], $commonErrorLinkOptions ],
	BaselinePosition -> Baseline ]

errorMessageLinkAppearance[ "NonFatal", text_ ] :=
Mouseover[
	Style[ text, FontColor -> RGBColor[ "#333333" ], $commonErrorLinkOptions ],
	Style[ text, FontColor -> RGBColor[ "#CF8B00" ], $commonErrorLinkOptions ],
	BaselinePosition -> Baseline ]

errorMessageLinkAppearance[ "Blocked", text_ ] :=
Mouseover[
	Style[ text, FontColor -> RGBColor[ "#333333" ], $commonErrorLinkOptions ],
	Style[ text, FontColor -> RGBColor[ "#449DCC" ], $commonErrorLinkOptions ],
	BaselinePosition -> Baseline ]

errorMessageLinkAppearance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cell Dingbats*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MakeChatInputActiveCellDingbat*)
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
		getPersonaMenuIcon @ personaValue[[2]]
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
		With[ { pos = Replace[ MousePosition[ "WindowScaled" ], { { _, y_ } :> y, _ :> 0 } ] },
			attachMenuCell[
				EvaluationCell[],
				makeChatActionMenu[
					"Input",
					parentCell[EvaluationCell[]],
					EvaluationCell[]
				],
				{Left, If[ pos < 0.5, Bottom, Top ]},
				Offset[{0, 0}, {Left, Top}],
				{Left, If[ pos < 0.5, Top, Bottom ]},
				RemovalConditions -> {"EvaluatorQuit", "MouseClickOutside"}
			]
        ],
		Appearance -> $suppressButtonAppearance,
		ImageMargins -> 0,
		FrameMargins -> 0,
		ContentPadding -> False
	];

	button
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MakeChatInputCellDingbat*)
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
		getPersonaMenuIcon @ personaValue[[2]]
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
		With[ { pos = Replace[ MousePosition[ "WindowScaled" ], { { _, y_ } :> y, _ :> 0 } ] },
			attachMenuCell[
				EvaluationCell[],
				makeChatActionMenu[
					"Delimiter",
					parentCell[EvaluationCell[]],
					EvaluationCell[]
				],
				{Left, If[ pos < 0.5, Bottom, Top ]},
				Offset[{0, 0}, {Left, Top}],
				{Left, If[ pos < 0.5, Top, Bottom ]},
				RemovalConditions -> {"EvaluatorQuit", "MouseClickOutside"}
			];
		],
		Appearance -> $suppressButtonAppearance,
		ImageMargins -> 0,
		FrameMargins -> 0,
		ContentPadding -> False
	];

	button
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeChatActionMenu*)
SetFallthroughError[makeChatActionMenu]

makeChatActionMenu[
	containerType: "Input" | "Delimiter" | "Toolbar",
	targetObj : _CellObject | _NotebookObject,
	(* The cell that will be the parent of the attached cell that contains this
		chat action menu content. *)
	attachedCellParent : _CellObject | Automatic,
    format_ : "Cell"
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
	personas = GetPersonasAssociation[ "IncludeHidden" -> False ],
	actionCallback
},
	(*--------------------------------*)
	(* Process personas list          *)
	(*--------------------------------*)

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
        targetObj,
		containerType,
		personas,
        format,
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
		"ToolCallFrequency" -> targetObj,
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

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeChatActionMenuContent*)
SetFallthroughError[makeChatActionMenuContent]

Options[makeChatActionMenuContent] = {
	"PersonaValue" -> Automatic,
	"ModelValue" -> Automatic,
	"RoleValue" -> Automatic,
	"ToolCallFrequency" -> Automatic,
	"TemperatureValue" -> Automatic,
	"ActionCallback" -> (Null &)
}

makeChatActionMenuContent[
    targetObj_,
	containerType : "Input" | "Delimiter" | "Toolbar",
	personas_?AssociationQ,
    format_,
	OptionsPattern[]
] := With[{
	callback = OptionValue["ActionCallback"]
}, Module[{
	personaValue = OptionValue["PersonaValue"],
	modelValue = OptionValue["ModelValue"],
	roleValue = Replace[OptionValue["RoleValue"], {source_, Inherited} :> {source, "User"}],
	toolValue = OptionValue["ToolCallFrequency"],
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
			tr[ "UIAdvancedTemperature" ],
			{
				None,
				makeTemperatureSlider[tempValue],
				None
			}
		},
        {
			menuItemLineWrap @ tr[ "UIAdvancedToolCallFrequency" ],
			{
				None,
				makeToolCallFrequencySlider[toolValue],
				None
			}
		},
		{ tr[ "UIAdvancedRoles" ] },
		Map[
			entry |-> ConfirmReplace[entry, {
				{role_?StringQ, icon_} :> {
					alignedMenuIcon[role, roleValue, icon],
					role,
					Hold[callback["Role", role]]
				}
			}],
			{
				{ "User",  getIcon @ "ChatIconUser" },
				{ "System",  getIcon @ "RoleSystem" }
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
		{ tr[ "UIPersonas" ] },
		KeyValueMap[
			{persona, personaSettings} |-> With[{
				icon = getPersonaMenuIcon[personaSettings]
			},
				{
					alignedMenuIcon[persona, personaValue, icon],
					menuItemLineWrap @ personaDisplayName[persona, personaSettings],
					Hold[callback["Persona", persona];updateDynamics[{"ChatBlock"}]]
				}
			],
			personas
		],
		{
			ConfirmReplace[containerType, {
				"Input" | "Toolbar" -> Nothing,
				"Delimiter" :> Splice[{
					Delimiter,
					{
						alignedMenuIcon[ getIcon @ "ChatBlockSettingsMenuIcon" ],
						tr[ "UIChatBlockSettings" ],
						"OpenChatBlockSettings"
					}
				}]
			}],
			Delimiter,
			{alignedMenuIcon[ getIcon @ "PersonaOther" ], menuItemLineWrap @ tr[ "UIAddAndManagePersonas" ], "PersonaManage"},
			{alignedMenuIcon[ getIcon @ "ToolManagerRepository" ], menuItemLineWrap @ tr[ "UIAddAndManageTools" ], "ToolManage"},
			Delimiter,
            <|
                "Label" -> tr[ "UIModels" ],
                "Type"  -> "Submenu",
                "Icon"  -> alignedMenuIcon @ getIcon @ "ChatBlockSettingsMenuIcon",
                "Data"  :> createServiceMenu[ targetObj, ParentCell @ EvaluationCell[ ] ]
            |>,
            <|
                "Label" -> tr[ "UIAdvancedSettings" ],
                "Type"  -> "Submenu",
                "Icon"  -> alignedMenuIcon @ getIcon @ "AdvancedSettings",
                "Data"  -> advancedSettingsMenu
            |>
        }
    ];

    Replace[
        format,
        {
            "List"       :> menuItems,
            "Expression" :> makeChatMenuExpression @ menuItems,
            "Cell"       :> makeChatMenuCell[ menuItems, menuMagnification @ targetObj ],
            expr_        :> throwInternalFailure[ makeChatActionMenuContent, expr ]
        }
    ]
]];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeChatMenuExpression*)
makeChatMenuExpression // beginDefinition;
makeChatMenuExpression[ menuItems_ ] := MakeMenu[ menuItems, GrayLevel[ 0.85 ], $chatMenuWidth ];
makeChatMenuExpression // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeChatMenuCell*)
makeChatMenuCell // beginDefinition;

makeChatMenuCell[ menuItems_ ] :=
    makeChatMenuCell[ menuItems, CurrentValue[ Magnification ] ];

makeChatMenuCell[ menuItems_, magnification_ ] :=
    Cell[
        BoxData @ ToBoxes @ makeChatMenuExpression @ menuItems,
        "AttachedChatMenu",
        Magnification -> magnification
    ];

makeChatMenuCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getIcon*)
getIcon[ name_ ] := Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", name ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Model selection submenu*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createServiceMenu*)
createServiceMenu // beginDefinition;

createServiceMenu[ obj_, root_ ] :=
    With[ { model = currentChatSettings[ obj, "Model" ] },
        MakeMenu[
            Join[
                { tr[ "UIModelsServices" ] },
                {
                    {
                        serviceIcon[ model, "Wolfram" ],
                        "Wolfram",
                        Hold[ removeChatMenus @ EvaluationCell[ ]; setModel[ obj, <| "Service" -> "LLMKit", "Name" -> Automatic |> ] ]
                    },
                    Delimiter
                },
                Map[
                    createServiceItem[ obj, model, root, #1 ] &,
                    DeleteCases[ getAvailableServiceNames[ "IncludeHidden" -> False ], "Wolfram" ] ]
            ],
            GrayLevel[ 0.85 ],
            140
        ]
    ];

createServiceMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createServiceItem*)
createServiceItem // beginDefinition;

createServiceItem[ obj_, model_, root_, service_String ] := <|
    "Type"  -> "Submenu",
    "Label" -> service,
    "Icon"  -> serviceIcon[ model, service ],
    "Data"  :> dynamicModelMenu[ obj, root, model, service ]
|>;

createServiceItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*serviceIcon*)
serviceIcon // beginDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Definitions for the model submenu*)

(* OpenAI is the only service that can have raw strings as a model spec: *)
serviceIcon[ model_String, "OpenAI" ] :=
    alignedMenuIcon[ $currentSelectionCheck, serviceIcon[ "OpenAI" ] ];

(* LLMKit service is provided by Wolfram *)
serviceIcon[ model: KeyValuePattern[ "Service" -> "LLMKit" ], "Wolfram" ] :=
    alignedMenuIcon[ $currentSelectionCheck, serviceIcon @ "Wolfram" ];

(* Show a checkmark if the currently selected model belongs to this service: *)
serviceIcon[ model: KeyValuePattern[ "Service" -> service_String ], service_String ] :=
    alignedMenuIcon[ $currentSelectionCheck, serviceIcon @ service ];

(* Otherwise hide the checkmark: *)
serviceIcon[ model_, service_String ] :=
    alignedMenuIcon[ Style[ $currentSelectionCheck, ShowContents -> False ], serviceIcon @ service ];

$currentSelectionCheck = Style[ "\[Checkmark]", FontColor -> GrayLevel[ 0.25 ] ];

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

dynamicModelMenu[ obj_, root_, model_, service_? modelListCachedQ ] :=
    Module[ { display },
        makeServiceModelMenu[ Dynamic @ display, obj, root, model, service ];
        display
    ];

dynamicModelMenu[ obj_, root_, model_, service_ ] :=
    DynamicModule[ { display },
        display = MakeMenu[
            {
                { service },
                {
                    None,
                    Pane[
                        Column @ {
                            Style[ tr[ "UIModelsGet" ], "ChatMenuLabel" ],
                            ProgressIndicator[ Appearance -> "Percolate" ]
                        },
                        ImageMargins -> 5
                    ],
                    None
                }
            },
            GrayLevel[ 0.85 ],
            200
        ];

        Dynamic[ display, TrackedSymbols :> { display } ],
        Initialization :> Quiet[
            Needs[ "Wolfram`Chatbook`" -> None ];
            catchAlways @ makeServiceModelMenu[ Dynamic @ display, obj, root, model, service ]
        ],
        SynchronousInitialization -> False
    ];

dynamicModelMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeServiceModelMenu*)
makeServiceModelMenu // beginDefinition;

makeServiceModelMenu[ display_, obj_, root_, currentModel_, service_String ] :=
    makeServiceModelMenu[
        display,
        obj,
        root,
        currentModel,
        service,
        Block[ { $allowConnectionDialog = False }, getServiceModelList @ service ]
    ];

makeServiceModelMenu[ Dynamic[ display_ ], obj_, root_, currentModel_, service_String, models_List ] :=
    display = MakeMenu[
        Join[ { service }, groupMenuModels[ obj, root, currentModel, models ] ],
        GrayLevel[ 0.85 ],
        280
    ];

makeServiceModelMenu[ Dynamic[ display_ ], obj_, root_, currentModel_, service_String, Missing[ "NotConnected" ] ] :=
    display = MakeMenu[
        {
            { service },
            {
                Spacer[ 0 ],
                tr[ "UIModelsNoList" ],
                Hold[
                    display = simpleModelMenuDisplay[ service, ProgressIndicator[ Appearance -> "Percolate" ] ];
                    makeServiceModelMenu[
                        Dynamic @ display,
                        obj,
                        root,
                        currentModel,
                        service,
                        getServiceModelList @ service
                    ]
                ]
            }
        },
        GrayLevel[ 0.85 ],
        200
    ];

makeServiceModelMenu[ Dynamic[ display_ ], obj_, root_, currentModel_, service_String, Missing[ "NoModelList" ] ] :=
	display = MakeMenu[
		{
			{ service },
			{
				Spacer[ 0 ],
				Automatic,
				Hold[
					removeChatMenus @ EvaluationCell[ ];
					(* TODO: this could probably prompt the user with an InputField to enter a name: *)
					setModel[ obj, <| "Service" -> service, "Name" -> Automatic |> ]
				]
			}
		},
		GrayLevel[ 0.85 ],
		200
	];

makeServiceModelMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*simpleModelMenuDisplay*)
simpleModelMenuDisplay // beginDefinition;
simpleModelMenuDisplay[ service_, expr_ ] := MakeMenu[ { { service }, { None, expr, None } }, GrayLevel[ 0.85 ], 200 ];
simpleModelMenuDisplay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*groupMenuModels*)
groupMenuModels // beginDefinition;

groupMenuModels[ obj_, root_, currentModel_, models_List ] :=
    groupMenuModels[ obj, root, currentModel, GroupBy[ models, modelGroupName ] ];

groupMenuModels[ obj_, root_, currentModel_, models_Association ] /; Length @ models === 1 :=
    modelMenuItem[ obj, root, currentModel ] /@ First @ models;

groupMenuModels[ obj_, root_, currentModel_, models_Association ] :=
    Flatten[ KeyValueMap[ menuModelGroup[ obj, root, currentModel ], models ], 1 ];

groupMenuModels // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*menuModelGroup*)
menuModelGroup // beginDefinition;

menuModelGroup[ obj_, root_, currentModel_ ] :=
    menuModelGroup[ obj, root, currentModel, ## ] &;

menuModelGroup[ obj_, root_, currentModel_, None, models_List ] :=
    modelMenuItem[ obj, root, currentModel ] /@ models;

menuModelGroup[ obj_, root_, currentModel_, name_String, models_List ] :=
    Join[ { name }, modelMenuItem[ obj, root, currentModel ] /@ models ];

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

modelMenuItem[ obj_, root_, currentModel_ ] := modelMenuItem[ obj, root, currentModel, #1 ] &;

modelMenuItem[
    obj_,
    root_,
    currentModel_,
    model: KeyValuePattern @ { "Name" -> name_, "Icon" -> icon_, "DisplayName" -> displayName_ }
] := {
    alignedMenuIcon[ modelSelectionCheckmark[ currentModel, name ], icon ],
    displayName,
    Hold[ removeChatMenus @ EvaluationCell[ ]; setModel[ obj, model ] ]
};

modelMenuItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*modelSelectionCheckmark*)
modelSelectionCheckmark // beginDefinition;
modelSelectionCheckmark[ KeyValuePattern[ "Name" -> model: Automatic ], model: Automatic ] := $currentSelectionCheck; (* LLMKit *)
modelSelectionCheckmark[ KeyValuePattern[ "Name" -> model_String ], model_String ] := $currentSelectionCheck;
modelSelectionCheckmark[ model_String, model_String ] := $currentSelectionCheck;
modelSelectionCheckmark[ _, _ ] := Style[ $currentSelectionCheck, ShowContents -> False ];
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
	targetObj : _CellObject | _NotebookObject,
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