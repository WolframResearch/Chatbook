(* ::Package:: *)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::NoVariables::Module:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

BeginPackage["Wolfram`Chatbook`UI`"]

(* Avoiding context aliasing due to bug 434990: *)
Needs[ "GeneralUtilities`" -> None ];

GeneralUtilities`SetUsage[ChatInputCellEvaluationFunction, "
ChatInputCellEvaluationFunction[input$, form$] is the CellEvaluationFunction for chat input cells.
"]

EditChatContextSettings
EditChatSettingsForCell
ChatExplainButtonFunction
GetChatEnvironmentValues
GetAllCellsInChatContext
ChatContextEpilogFunction

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


Begin["`Private`"]

Needs["Wolfram`Chatbook`"]
Needs["Wolfram`Chatbook`Common`"]
Needs["Wolfram`Chatbook`ErrorUtils`"]
Needs["Wolfram`Chatbook`Errors`"]
Needs["Wolfram`Chatbook`Debug`"]
Needs["Wolfram`Chatbook`Utils`"]
Needs["Wolfram`Chatbook`Streaming`"]
Needs["Wolfram`Chatbook`Serialization`"]
Needs["Wolfram`Chatbook`Menus`"]
Needs["Wolfram`Chatbook`Personas`"]
Needs["Wolfram`Chatbook`PersonaInstaller`"]
Needs["Wolfram`Chatbook`FrontEnd`"]
Needs["Wolfram`Chatbook`InlineReferences`"]
Needs["Wolfram`Chatbook`Actions`"]

Needs["Wolfram`Chatbook`PreferencesUtils`" -> "PrefUtils`"]


Needs["Wolfram`Chatbook`ServerSentEventUtils`" -> None]

(*========================================================*)

$chatMenuWidth = 225

(*========================================================*)

$ChatOutputTypePrompts = <|
	Automatic -> "",
	"Verbose" -> "Make your response detailed and include all relevant information.",
	"Terse" -> "Make your response tersely worded and compact.",
	"Data" -> "Include in your response only data and plain facts without explanations or additional text.",
	"Code" -> "Include in your response only computer code in the Mathematica language.",
	"Analysis" -> "Analyze the correctness of the following statement or computer code and report any errors and how to fix them."
|>;

$ChatContextCellStyles = <|
	"ChatUserInput" -> "user",
	"ChatSystemInput" -> "system",
	"ChatAssistantOutput" -> "assistant",
	"ChatAssistantText" -> "assistant",
	"ChatAssistantProgram" -> "assistant",
	"ChatAssistantExternalLanguage" -> "assistant"
|>;

GetChatEnvironmentValues[promptCell_, evaluationCell_, chatContextCells_] := With[{
			promptCellContents = NotebookRead[promptCell],
			evaluationCellTaggingRules = FullOptions[evaluationCell, TaggingRules],
			chatContextTaggingRules = FullOptions[First[chatContextCells], TaggingRules]},
	<|
		"Contents" -> promptCellContents,
		"ContentsString" -> CellToString[promptCellContents],
		"PromptCell" -> promptCell,
		"EvaluationCell" -> evaluationCell,
		"ChatContextCells" -> chatContextCells,

		"Model" -> Lookup[evaluationCellTaggingRules, "Model", Automatic],
		"OutputType" -> Lookup[evaluationCellTaggingRules, "OutputType", Automatic],
		"TokenLimit" -> Lookup[evaluationCellTaggingRules, "TokenLimit", "1000"],
		"Temperature" -> Lookup[evaluationCellTaggingRules, "Temperature", "0.7"],
		"ChatContextPreprompt" -> Lookup[chatContextTaggingRules, "ChatContextPreprompt", Null],
		"ChatContextPostprompt" -> Lookup[chatContextTaggingRules, "ChatContextPostprompt", Null],
		"ChatContextCellProcessingFunction" -> Lookup[chatContextTaggingRules, "ChatContextCellProcessingFunction", Automatic],
		"ChatContextPostEvaluationFunction" -> Lookup[chatContextTaggingRules, "ChatContextPostEvaluationFunction", Automatic]
	|>
]

(*====================================*)

MakeChatCloudDockedCellContents[] := Grid[
	{{
		Item[$cloudChatBanner, Alignment -> Left],
		Item["", ItemSize -> Fit],
		Row[{"Persona", Spacer[5], $cloudPersonaChooser}],
		Row[{"Model", Spacer[5], $cloudModelChooser}]
	}},
	Dividers -> {{False, False, False, True}, False},
	Spacings -> {2, 0},
	BaseStyle -> {"Text", FontSize -> 14, FontColor -> GrayLevel[0.4]},
	FrameStyle -> Directive[Thickness[2], GrayLevel[0.9]]
]


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



(*====================================*)

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

	PrefUtils`PreferencesPane[
		{
			PrefUtils`PreferencesSection[
				Style[tr["Chat Notebook Interface"], "subsectionText"],
				chatbookSettings
			],
			PrefUtils`PreferencesSection[
				Style[tr["Installed Personas"], "subsectionText"],
				llmEvaluatorNamesSettings
			]
			(* PrefUtils`PreferencesSection[
				Style[tr["LLM Service Providers"], "subsectionText"],
				services
			] *)
		},
		PrefUtils`PreferencesResetButton[
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

(*====================================*)

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
								settings = getModelSettings[modelName]
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



(*====================================*)

SetFallthroughError[ChatInputCellEvaluationFunction]

ChatInputCellEvaluationFunction[
	input_,
	form_
] := Module[{
	evaluationCell,
	chatContextCells,
	params,
	req
},
	If[!checkAPIKey[False],
		Return[]
	];

	(*--------------------------------*)
	(* Assemble the ChatGPT prompt    *)
	(*--------------------------------*)

	(*
		Construct a chat prompt list from the current cell and all the cells
		that come before it up to the first chat context delimiting cell.
	*)
	evaluationCell = EvaluationCell[];
	chatContextCells = GetAllCellsInChatContext[EvaluationNotebook[], evaluationCell];
	params = GetChatEnvironmentValues[evaluationCell, evaluationCell, chatContextCells];

	req = Flatten @ Map[
		promptCell |-> promptProcess[promptCell, evaluationCell, chatContextCells],
		chatContextCells
	];

	(* TODO(polish): Improve the error checking / reporting here to let
		chat notebook authors know if they've entered an invalid prompt form. *)

	If[MatchQ[params["ChatContextPreprompt"], _?ListQ | _?AssociationQ],
		PrependTo[req, params["ChatContextPreprompt"]]];

	If[MatchQ[params["ChatContextPostprompt"], _?ListQ | _?AssociationQ],
		AppendTo[req, params["ChatContextPostprompt"]]];

	If[StringQ[$ChatSystemPre] && $ChatSystemPre =!= "",
		PrependTo[req, <| "role" -> "system", "content" -> $ChatSystemPre |>];
	];

	If[StringQ[$ChatInputPost] && $ChatInputPost =!= "",
		AppendTo[req, <| "role" -> "user", "content" -> $ChatInputPost |>];
	];

	req = Flatten[req];

	RaiseAssert[
		MatchQ[ req, { KeyValuePattern @ { "role" -> _? StringQ, "content" -> _? StringQ }... } ],
		"unexpected form for parsed chat input: ``", InputForm[req]
	];

	(*----------------------------------------------------------------------*)
	(* Put the insertion point where it belongs after the old output        *)
	(*----------------------------------------------------------------------*)

	moveAfterPreviousOutputs[EvaluationCell[]];

	If[Lookup[params, "OutputType", Automatic] =!= Automatic,
		PrependTo[req, <|
			"role" -> "system",
			(* FIXME: Confirm this output type exists. *)
			"content" -> $ChatOutputTypePrompts[Lookup[params, "OutputType", Automatic]]
		|>]
	];

	runAndDecodeAPIRequest[req, Lookup[params, "TokenLimit", "1000"], Lookup[params, "Temperature", "0.7"], True];
]


Attributes[ChatContextEpilogFunction] = {HoldFirst};
ChatContextEpilogFunction[func_] := Module[{evaluationCell, params},
	evaluationCell = EvaluationCell[];
	chatContextCells = GetAllCellsInChatContext[EvaluationNotebook[], evaluationCell];
	params = GetChatEnvironmentValues[evaluationCell, evaluationCell, chatContextCells];

	func[params];
]

(*------------------------------------*)

SetFallthroughError[runAndDecodeAPIRequest]

runAndDecodeAPIRequest[
	req_,
	tokenLimit_,
	temperature_,
	isAsync_?BooleanQ
] := Module[{
	response, parsed, content, processed
},
	params = <|
		"TokenLimit" -> ToExpression[tokenLimit],
		"Temperature" -> ToExpression[temperature]
	|>;

	(*--------------------------------*)
	(* Perform the API request        *)
	(*--------------------------------*)

	$LastRequestChatMessages = req;
	$LastRequestParameters = params;

	If[isAsync,
		doAsyncChatRequest[EvaluationNotebook[], req, params]
		,
		doSyncChatRequest[req, params]
	]
]

(*====================================*)

SetFallthroughError[doSyncChatRequest]

doSyncChatRequest[
	messages_?ListQ,
	params_?AssociationQ
] := Module[{
	response,
	parsed,
	content,
	processed
},
	response = chatRequest[messages, params];

	$LastResponse = response;

	response = ConfirmReplace[response, {
		_HTTPResponse :> response,
		_?FailureQ :> Raise[
			ChatbookError,
			<| "ResponseResult" -> response |>,
			"Error performing chat API request: ``",
			response
		],
		other_ :> Raise[
			ChatbookError,
			<| "ResponseResult" -> response |>,
			"Unexpected result expression from chatRequest: ``",
			InputForm[other]
		]
	}];

	RaiseAssert[
		MatchQ[response, _HTTPResponse],
		"Unexpected response form: ``", InputForm[response]
	];

	ConfirmReplace[response["StatusCode"], {
		200 :> Null,
		401 :> (
			checkAPIKey[True];
			Return[]
		),
		429 :> (
			(* FIXME: Replace this with better error reporting. *)
			Print["Too Many Requests"];
			Return[];
		)
	}];

	parsed = ConfirmReplace[
		ImportByteArray[response["BodyByteArray"], "RawJSON"],
		{
			result : (_?ListQ | _?AssociationQ) :> result,
			other_ :> Raise[
				ChatbookError,
				<| "ResponseResult" -> response |>,
				"Error parsing API response body: ``: body was: ``",
				InputForm[other],
				InputForm[response["Body"]]
			]
		}
	];

	If[!MatchQ[parsed, {___Rule} | _?AssociationQ],
		Raise[
			ChatbookError,
			<| "ResponseResult" -> response |>,
			"Chat API response did not have the expected format: ``",
			InputForm[parsed]
		];
	];

	content = ConfirmReplace[parsed, {
		KeyValuePattern[{
			"choices" -> {
				KeyValuePattern[{
					"message" -> KeyValuePattern[{
						"content" -> content0_
					}]
				}],
				(* FIXME: What about other potential entries in this "choices" field? *)
				___
			}
		}] :> content0,
		other_ :> Raise[
			ChatbookError,
			<| "ResponseResult" -> response |>,
			"Chat API response did not contain \"content\" at the expected lookup path: ``",
			InputForm[other]
		]
	}];

	processed = StringJoin[StringTrim[content]];

	processed
]

(*====================================*)

(* Called after normal Input cell evaluation to create an attached report of what it did*)

SetFallthroughError[ChatExplainButtonFunction]

ChatExplainButtonFunction[cellObj_] := Module[{},
	NotebookDelete[Cells[cellObj, AttachedCell -> True]];
	AttachCell[
		cellObj,
		Cell[
			BoxData[{
				GridBox[{{
					StyleBox[
						FrameBox[PaneBox[
							runAndDecodeAPIRequest[
							{
								<|"role" -> "system", "content" ->
"Explain what the following Mathematica language code does.
If it contains a syntax error explain where the error is and how to fix it.
If there are no syntax errors do not state that fact."|>,
								<|
									"role" -> "user",
									"content" -> StringJoin[
										NotebookImport[Notebook[{NotebookRead[cellObj]}], _ -> "InputText"]
									]
								|>
							}, 500, 0.7, False]
						],
							FrameStyle -> Darker[Green]
						],
						Background -> Lighter[Green]
					],
					ButtonBox[
						FrameBox["x"],
						Evaluator -> Automatic,
						ButtonFunction :> NotebookDelete[EvaluationCell[]]
					]
				}}]
			}],
			"Text",
			FontWeight -> Plain, FontFamily -> "Ariel", TextAlignment -> Left
		]
  		,
		"Inline"
	];
]

(*====================================*)

SetFallthroughError[OnePromptTableEditor]

OnePromptTableEditor[
	cellObj_,
	tag_,
   Dynamic[tableContents_]
] :=
	GridBox[{{
		DynamicBox[GridBox[
			Join[
				{{
					StyleBox["ROLE", FontSize->10],
					StyleBox["CONTENT", FontSize->10],
					""
				}},
				MapIndexed[
					{
						InputFieldBox[Dynamic[tableContents[[#2[[1]], 1]]]],
						InputFieldBox[Dynamic[tableContents[[#2[[1]], 2]]]],
						ButtonBox[
							FrameBox["\[Times]", RoundingRadius->5, ImageSize->{20,20}, Alignment->{Center,Center}],
							Evaluator -> Automatic,
							Appearance -> None,
							ButtonFunction :> (
								tableContents = Delete[tableContents, {#2[[1]]}]
							)
						]
					} &,
					tableContents
				],
				{{
					ButtonBox[
						FrameBox["+", RoundingRadius->5, ImageSize->{20,20}, Alignment->{Center,Center}],
						Evaluator -> Automatic,
						Appearance -> None,
						ButtonFunction :> (
							AppendTo[tableContents, {"system", ""}]
						)
					],
					"",
					""
				}}
			],
			GridBoxAlignment->{"Columns" -> {{Left}}}
		]]
	}}
];


(*====================================*)

SetFallthroughError[EditChatContextSettings]

EditChatContextSettings[cellObj_] := Module[{
	cell
},
	If[Cells[cellObj, AttachedCell -> True] =!= {},
		NotebookDelete[Cells[cellObj, AttachedCell -> True]];
		Return[]
	];

	cell = Cell[
		BoxData @ DynamicModuleBox[{
			$CellContext`tableContentsPreprompt$$ =
				If[ListQ[CurrentValue[cellObj, {TaggingRules, "ChatContextPreprompt"}]],
					Map[
						{#["role"], #["content"]} &,
						CurrentValue[cellObj, {TaggingRules, "ChatContextPreprompt"}]
					]
					,
					{}
				],
			$CellContext`tableContentsPostprompt$$ =
				If[ListQ[CurrentValue[cellObj, {TaggingRules, "ChatContextPostprompt"}]],
					Map[
						{#["role"], #["content"]} &,
						CurrentValue[cellObj, {TaggingRules, "ChatContextPostprompt"}]
					]
					,
					{}
				],

			$CellContext`tableContentsActAsDelimiter$$ =
				CurrentValue[cellObj, {TaggingRules, "ChatContextDelimiter"}] =!= False,

			$CellContext`tableContentsChatContextCellProcessingFunction$$ =
				(CurrentValue[cellObj, {TaggingRules, "ChatContextCellProcessingFunction"}] /. Inherited -> Automatic),

			$CellContext`tableContentsChatContextPostEvaluationFunction$$ =
				(CurrentValue[cellObj, {TaggingRules, "ChatContextPostEvaluationFunction"}] /. Inherited -> Automatic)
		},
			Evaluate @ StyleBox[
				FrameBox[
					GridBox[
						{
							{
								RowBox[{
									CheckboxBox[Dynamic[$CellContext`tableContentsActAsDelimiter$$]],
									" Act as chat context delimiter"
								}]
							},
							{""},
							{StyleBox["ChatContextPreprompt", FontSize->12]},
							{
								OnePromptTableEditor[
									cellObj,
									"ChatContextPreprompt",
									Dynamic[$CellContext`tableContentsPreprompt$$]
								]
							},
							{""},
							{StyleBox["ChatContextPostprompt", FontSize->12]},
							{
								OnePromptTableEditor[
									cellObj,
									"ChatContextPostprompt",
									Dynamic[$CellContext`tableContentsPostprompt$$]
								]
							},
							{""},
							{StyleBox["ChatContextCellProcessingFunction", FontSize->12]},
							{
								InputFieldBox[Dynamic[$CellContext`tableContentsChatContextCellProcessingFunction$$]]
							},
							{""},
							{StyleBox["ChatContextPostEvaluationFunction", FontSize->12]},
							{
								InputFieldBox[Dynamic[$CellContext`tableContentsChatContextPostEvaluationFunction$$], Hold[Expression]]
							},
							{""},
							{
								ItemBox[
									RowBox[{
										ButtonBox[
											FrameBox["Apply"],
											Evaluator -> Automatic,
											Appearance -> None,
											ButtonFunction :> (
												CurrentValue[
													cellObj,
													{TaggingRules, "ChatContextDelimiter"}
												] = $CellContext`tableContentsActAsDelimiter$$;

												CurrentValue[
													cellObj,
													{"TaggingRules", "ChatContextPreprompt"}
												] = Map[
													<|"role" -> #[[1]], "content" -> #[[2]]|> &,
													$CellContext`tableContentsPreprompt$$
												];

												CurrentValue[
													cellObj,
													{"TaggingRules", "ChatContextPostprompt"}
												] = Map[
													<|"role" -> #[[1]], "content" -> #[[2]]|> &,
													$CellContext`tableContentsPostprompt$$
												];

												CurrentValue[
													cellObj,
													{TaggingRules, "ChatContextCellProcessingFunction"}
												] = $CellContext`tableContentsChatContextCellProcessingFunction$$;

												(* ChatContextPostEvaluationFunction is set twice: once in tagging rules, and then in
												the option that causes it to be used as the CellEpilog of all cells within the group
												this cell is the head of. *)
												CurrentValue[
													cellObj,
													{TaggingRules, "ChatContextPostEvaluationFunction"}
												] = $CellContext`tableContentsChatContextPostEvaluationFunction$$;

												$CellContext`tableContentsChatContextPostEvaluationFunction$$ /. Hold[e_] :>
													SetOptions[
														cellObj,
														PrivateCellOptions->{"CellGroupBaseStyle" -> {
															CellEpilog :> Wolfram`Chatbook`UI`ChatContextEpilogFunction[e]}
														}
													];

												NotebookDelete[Cells[cellObj, AttachedCell -> True]];
											)
										],
										ButtonBox[
											FrameBox["Cancel"],
											Evaluator -> Automatic,
											Appearance -> None,
											ButtonFunction :> (
												NotebookDelete[Cells[cellObj, AttachedCell -> True]]
											)
										]
									}],
									Alignment -> Center
								]
							}
						},
						GridBoxAlignment -> {
							"Columns" -> {{Left}}
						}
					],
					FrameStyle -> GrayLevel[0.774121],
					RoundingRadius -> 5,
					Background -> GrayLevel[0.96]
				],
				FontColor->GrayLevel[0.422675]
			]
		],
		"Text",
		FontWeight -> Plain,
		FontFamily -> "Ariel",
		TextAlignment -> Left
	];

	AttachCell[cellObj, cell, "Inline"];
];

EditChatSettingsForCell[cellObj_] := Module[{
		cell
	},
	If[Cells[cellObj, AttachedCell -> True] =!= {},
		NotebookDelete[Cells[cellObj, AttachedCell -> True]];
		Return[]
	];

	cell = Cell[
		BoxData[RowBox[{
			"Output Type: ",
			PopupMenuBox[
				Dynamic[
					ReplaceAll[
						FullOptions[ParentCell[EvaluationCell[]], TaggingRules]["OutputType"],
						{_Missing -> Automatic}
					],
					(
						CurrentValue[
							ParentCell[EvaluationCell[]],
							{TaggingRules, "OutputType"}
						] = #1;
					) &
				],
				{Automatic, "Verbose", "Terse", "Data", "Code", "Analysis"},
				Appearance -> None,
				BaseStyle -> {FontSize -> 10}
			],
			" Token Limit: ",
			PopupMenuBox[
				Dynamic[
					ReplaceAll[
						FullOptions[ParentCell[EvaluationCell[]], TaggingRules]["TokenLimit"],
						{_Missing -> "1000"}
					],
					(
						CurrentValue[
							ParentCell[EvaluationCell[]],
							{TaggingRules, "TokenLimit"}
						] = #1;
					) &
				],
				{"100", "500", "1000", "2000", "4000"},
				Appearance -> None,
				BaseStyle -> {FontSize -> 10}
			],
			" Temperature: ",
			PopupMenuBox[
				Dynamic[
					ReplaceAll[
						FullOptions[ParentCell[EvaluationCell[]], TaggingRules]["Temperature"],
						{_Missing -> "0.7"}
					],
					(
						CurrentValue[
							ParentCell[EvaluationCell[]],
							{TaggingRules, "Temperature"}
						] = #1;
					) &
				],
				{"0", "0.1", "0.2", "0.3", "0.4", "0.5", "0.6", "0.7", "0.8", "0.9", "1.0"},
				Appearance -> None,
				BaseStyle -> {FontSize -> 10}
			]
		}]],
		Background -> GrayLevel[1],
		FontSize -> 10,
		FontFamily -> FrontEnd`CurrentValue["ControlsFontFamily"],
		TextAlignment -> Center
	];

	AttachCell[cellObj, cell, Top];
];

(*====================================*)

SetFallthroughError[doAsyncChatRequest]

doAsyncChatRequest[
	nbObj_NotebookObject,
	messages_?ListQ,
	params_?AssociationQ
] := Module[{
	apiKey,
	request,
	$state,
	events = {},
	result = Null,
	task
},
	deletePreviousOutputs[EvaluationCell[]];

	(* NOTE:
		This prints an empty mostly-invisible Cell, and immediately deletes
		it. The purpose for doing this is to trigger the FE's automatic logic
		for deleting previous output cells, which happens when a CellPrint
		operation is done. The call to deletePreviousOutputs above has already
		done this for us.

		Additionally, if we don't do this now, it is done automatically after
		the CellEvaluationFunction returns its result, which will delete any
		cells that are written by the asynchronous URLSubmit streaming results
		logic.
	*)
	NotebookDelete @ FrontEndExecute[
		FrontEnd`CellPrintReturnObject[
			Cell["", CellOpen -> False, ShowCellBracket -> False]
		]
	];

	SelectionMove[cell, After, EvaluationCell[]];

	(*-----------------------------------------------*)
	(* Initialize the URLSubmit event handler state. *)
	(*-----------------------------------------------*)

	$state["EvaluationCell"] = EvaluationCell[];
	$state["CurrentCell"] = None;
	$state["OutputEventGenerator"] = CreateChatEventToOutputEventGenerator[];

	$state[args___] := Raise[
		ChatbookError,
		"Invalid chat event to output event $state args: ``",
		{args}
	];

	(*-----------------------------*)
	(* Make the API request object *)
	(*-----------------------------*)

	apiKey = SystemCredential[$openAICredentialKey];

	request = chatHTTPRequest[
		messages,
		params,
		apiKey,
		"Stream" -> True
	];

	(*---------------------------------------------------------*)
	(* Perform the web request and start streaming the results *)
	(*---------------------------------------------------------*)

	task = URLSubmit[
		request,
		HandlerFunctions -> <|
			"BodyChunkReceived" -> Wolfram`Chatbook`ServerSentEventUtils`ServerSentEventBodyChunkTransformer[
				event |-> (
					AppendTo[events, event];
					Handle[
						WrapRaised[ChatbookError, "Error processing AI output."][
							handleStreamEvent[$state, event]
						],
						failure_Failure :> (
							(* If there was a failure processing the last event,
								stop executing this task. Further events are
								only likely to generate more failures. *)
							TaskRemove[task];
							result = failure;
						)
					]
				)
			],
			"TaskFinished" -> Function[args,
				(* FIXME: Store the response body in this error as well.
					This is currently non-trivial due to a bug in URLSubmit:
					if you use BodyChunkReceived, you can't access the "Body"
					field to get the entire response. *)
				ConfirmReplace[args["StatusCode"], {
					200 :> Null,
					other_?IntegerQ :> (
						result = CreateFailure[
							ChatbookError,
							(* <| "ResponseBody" -> args |>, *)
							"Chat request failed."
						];
					)
				}];
			]
			(* TODO: Do some cleanup with the current selection caret? *)
			(* "TaskFinished" -> Function[
				Print["Finished! ", #1]
			] *)
		|>,
		HandlerFunctionsKeys -> {"BodyChunk", "StatusCode"}
	];

	(* TODO: Better default time constraint value?
		Also we should issue a message when this is hit.
		What if the user wants to wait longer than this (i.e. ChatGPT is having
		a slow day?)
	*)
	TaskWait[task, TimeConstraint -> 120];

	$LastResponse = events;

	result
]

(*------------------------------------*)

SetFallthroughError[handleStreamEvent]

handleStreamEvent[
	$state_Symbol,
	ssEvent_?AssociationQ
] := Module[{
	data
},
	data = Replace[ssEvent, {
		<| "Data" -> "[DONE]" |> :> Return[Null, Module],
		<| "Data" -> json_?StringQ |> :> Developer`ReadRawJSONString[json],
		other_ :> Raise[
			ChatbookError,
			"Unexpected form for chat streaming server-sent event object: ``",
			InputForm[other]
		]
	}];

	events = ConfirmReplace[$state["OutputEventGenerator"][data], {
		(*
			We don't have enough buffered data to know if we should
			start or end a code block or not. Do nothing until we
			receive more input.
		*)
		Missing["IncompleteData"] :> Return[Null, Module],
		e_?ListQ :> e
	}];

	Scan[
		event |-> ConfirmReplace[event, {
			"Write"[content_?StringQ] :> (
				writeContent[$state, content];
			),
			"BeginCodeBlock"[spec_?StringQ] :> (
				startCurrentCell[$state, makeCodeBlockCell["", spec]];
			),
			"BeginText" :> (
				startCurrentCell[$state, Cell[TextData[""], "ChatAssistantText"]];
			),
			other_ :> Fail2[
				ChatbookError,
				"Unexpected form for chat streaming output event: ``",
				InputForm[other]
			]
		}],
		events
	];

	(* FIXME: Flush remaining buffered data in the output event generator. *)
]

(*------------------------------------*)

SetFallthroughError[startCurrentCell]

(* Start a new cell and update $state["CurrentCell"]. *)
startCurrentCell[$state_Symbol, cell:Cell[_, style_?StringQ, ___]] := Module[{},
	$state["CurrentCell"] = <|
		"Style" -> style,
		"Object" -> CellPrint2[$state["EvaluationCell"], cell]
	|>;
]

(*------------------------------------*)

SetFallthroughError[writeContent]

writeContent[$state_Symbol, content_?StringQ] := Module[{},
	ConfirmReplace[$state["CurrentCell"], {
		(* If there is no current cell, default to creating a text cell. *)
		None :> startCurrentCell[$state, Cell[TextData[""], "ChatAssistantText"]],
		KeyValuePattern[{"Style" -> _}] :> Null
	}];

	With[{
		currentCellObj = $state["CurrentCell"]["Object"]
	},
		RaiseConfirmMatch[currentCellObj, _CellObject];
		RaiseAssert[Experimental`CellExistsQ[currentCellObj]];

		SelectionMove[currentCellObj, After, CellContents];

		WithCleanup[
			(* NOTE:
				Temporarily prevent the automatic cell edit duplicate FE
				behavior from occurring during this write. This prevents our
				programmatic edit to the cell from causing it to be
				automatically transformed into an Input cell (which is the
				desired behavior when a user manually edits a code cell
				generated by the AI).
			*)
			SetOptions[currentCellObj, CellEditDuplicate -> False]
			,
			NotebookWrite[
				RaiseConfirm @ ParentNotebook[currentCellObj],
				content
			];
			,
			SetOptions[currentCellObj, CellEditDuplicate -> Inherited]
		];
	];
]

(*------------------------------------*)


(*====================================*)

SetFallthroughError[checkAPIKey]

checkAPIKey[provenBad_] := Module[{
	value
},
	If[StringQ[SystemCredential["OPENAI_API_KEY"]] && !provenBad,
		Return[True]
	];
    Needs[ "OAuth`" -> None ];
	value = OAuthDialogDump`Private`MultipleKeyDialog[
		"OpenAILink",
		{"API Key" -> "APIKey"},
		"https://platform.openai.com/account/api-keys",
		"https://openai.com/policies/terms-of-use"];

	If[value =!= $Canceled,
		SystemCredential["OPENAI_API_KEY"] = ("APIKey" /. value)];

	False
];


(*========================================================*)
(* Cell Processing                                        *)
(*========================================================*)

(* TODO: This function is unused? *)
precedingCellsInGroup[] := Module[{
	cell = EvaluationCell[],
	nb = EvaluationNotebook[],
	cells
},
	(* Move the selection just before the current cell. *)
	SelectionMove[cell, Before, Cell];

	(* Get all the cells in the cell group containing `cell`. *)
	cells = ConfirmReplace[SelectionMove[nb, All, CellGroup, AutoScroll -> False], {
		Null :> Cells[NotebookSelection[nb]],
		(* Assume this failed because there was no enclosing cell group. This can
			commonly happen when the current cell is at the top level in the
			notebook, e.g. it's the first cell in a new notebook. *)
		$Failed :> Cells[nb]
	}];

	(* Deselect the cell group we just selected. *)
	SelectionMove[cell, After, Cell];

	(* Take all the cells that come before `cell`, dropping the cells that
	   come after `cell`. *)
	cells = TakeWhile[cells, # =!= cell &];

	(* This does not include `cell` itself. *)
	cells
];

(*====================================*)

SetFallthroughError[cellIsChatDelimiter]

cellIsChatDelimiter[cellObj_CellObject] :=
	TrueQ[FullOptions[cellObj, TaggingRules]["ChatContextDelimiter"]];

(*------------------------------------*)

SetFallthroughError[GetAllCellsInChatContext]

GetAllCellsInChatContext[
	nb_NotebookObject,
	evaluationCell_CellObject
] := Module[{
	allCells,
	currentCellPos,
	dividerCellPos,
	cellsInContext
},
	allCells = Cells[nb];
	currentCellPos = Flatten[Position[allCells, evaluationCell]];

	If[Length[currentCellPos] === 0,
		(* FIXME: Better error reporting. *)
		Print["Evaluation cell not found in Notebook."];
		Return[{}]
	];

	dividerCellPos = Flatten[
		Map[
			Position[allCells, #] &,
			Cells[nb, CellStyle -> "ChatBlockDivider"]
		]
	];

	currentCellPos = First[currentCellPos];
	cellsInContext = If[(Length[dividerCellPos] === 0) || (First[dividerCellPos] >= currentCellPos),
		Take[allCells, currentCellPos]
		,
		Take[
			allCells,
			{
				Max[Select[dividerCellPos, (# < currentCellPos) &]],
				currentCellPos
			}
		]
	];

	cellsInContext = Reverse[cellsInContext];
	cellsInContext = Reverse[
		Take[
			cellsInContext,
			Min[
				Length[cellsInContext],
				1 + LengthWhile[cellsInContext, (! cellIsChatDelimiter[#]) &]
			]
		]
	];

	Wolfram`Chatbook`Debug`$LastContextGroupCells = cellsInContext;

	cellsInContext
];

(*====================================*)

SetFallthroughError[promptProcess]

promptProcess[
	promptCell_CellObject,
	evaluationCell_CellObject,
	chatContextCells_List
] := Module[{
	contextStyles,
	taggingRules,
	defaultRole
},
	contextStyles = ConfirmReplace[$ChatContextCellStyles, {
		value_?AssociationQ :> value,
		other_ :> (
			ChatbookWarning[
				"$ChatContextCellStyles must be an Association. Got: ``",
				InputForm[other]
			];
			<||>
		)
	}];

	params = GetChatEnvironmentValues[promptCell, evaluationCell, chatContextCells];

	defaultRole = ConfirmReplace[params["Contents"], {
		Cell[CellGroupData[___], ___] :> None,

		Cell[expr_, styles0___?StringQ, ___?OptionQ] :> Module[{
			styles = {styles0}, role
		},
			(* Only consider styles that are in `includedStyles` *)
			styles = Intersection[styles, Keys[contextStyles]];

			ConfirmReplace[styles, {
				{} :> "user",
				{first_, rest___} :> Module[{role},
					(* FIXME: Issue a warning if rest contains cell styles that map
						to conflicting roles. *)
					(* If[Length[{rest}] > 0,
						ChatWarning
					]; *)

					(* FIXME: Better error if this confirm fails. *)
					role = RaiseConfirmMatch[
						Lookup[contextStyles, first],
						_?StringQ
					];

					role
				]
			}]
		],

		other_ :> None
	}];

	If[defaultRole === None,
		Return[{}]];

	If[params["ChatContextCellProcessingFunction"] === Automatic,
		<| "role" -> defaultRole, "content" -> params["ContentsString"] |>,
		params["ChatContextCellProcessingFunction"][params]
		(* TODO error checking to ensure function returned an association *)
	]
]


(*========================================================*)
(* Dealing with old output                                *)
(*========================================================*)

(* Copied from WANE *)

(* The procedure for determining previously generated output cells is:

	- If OutputAutoOverwrite is False for the notebook, stop.
	- Otherwise, examine the cell immediately after the input cell.
		- If it's not Deletable, stop.
		- If it's not CellAutoOverwrite, stop.
		- Otherwise, mark it for deletion, and examine the next cell.

This is not quite the same as the Desktop front end's algorithm. The FE checks
for Evaluatable -> False right after Deletable. But we can't do that, because we
have to be able to delete "DeployedWLInput" cells, which can be evaluated.

The FE also does something special if it encounters a cell group. But we're not
going to bother with that for now.
*)

previousOutputs[cellObj_CellObject] :=
	Module[{
		nbObj = ParentNotebook[cellObj],
		cells, objs = {}
	},
		If[Not @ TrueQ @ AbsoluteCurrentValue[nbObj, OutputAutoOverwrite], Return[{}]];
		cells = NextCell[cellObj, All];
		If[!MatchQ[cells, {__CellObject}], Return[{}]];
		Do[
			If[
				TrueQ @ AbsoluteCurrentValue[cell, Deletable] &&
				TrueQ @ AbsoluteCurrentValue[cell, CellAutoOverwrite], AppendTo[objs, cell], Break[]],
			{cell, cells}
		];
		objs
	]


deletePreviousOutputs[cellObj_CellObject] :=
	Replace[previousOutputs[cellObj], {
		cells: {__CellObject} :> NotebookDelete[cells],
		_ :> None
	}]

moveAfterPreviousOutputs[cellObj_CellObject] :=
	Replace[previousOutputs[cellObj], {
		{___, lastCell_CellObject} :> SelectionMove[lastCell, After, Cell],
		_ :> SelectionMove[cellObj, After, Cell]
	}]



(*========================================================*)
(* ChatGPT Response Processing                            *)
(*========================================================*)

SetFallthroughError[processResponse];

processResponse[response_?StringQ] := Module[{
	parsed = parseResponse[response]
},
	Scan[
		Replace[{
			s_?StringQ :> CellPrint @ Cell[StringTrim[s], "ChatAssistantText"],
			Code[s_?StringQ] :> CellPrint[makeCodeBlockCell[s, None]],
			Code[s_?StringQ, lang_?StringQ] :> CellPrint[makeCodeBlockCell[s, lang]],
			other_ :> Throw[{"Unexpected parsed form: ", InputForm[other]}]
		}],
		parsed
	]
]

(*------------------------------------*)

SetFallthroughError[makeCodeBlockCell]

makeCodeBlockCell[content_?StringQ, codeBlockSpec : _?StringQ | None] :=
	ConfirmReplace[Replace[codeBlockSpec, s_String :> Capitalize[s]], {
		None | "" -> Cell[BoxData[content], "ChatAssistantProgram"],
		"Wolfram" | "Mathematica" -> Cell[BoxData[content], "ChatAssistantOutput"],
		lang_?StringQ :> Cell[
			content,
			"ChatAssistantExternalLanguage",
			CellEvaluationLanguage -> Replace[lang, {
				"Bash" -> "Shell"
			}]
		]
	}]

(*------------------------------------*)

parseResponse[response_?StringQ] := Module[{
	parsed
},
	parsed = StringSplit[response, {
		code : (
			StartOfLine ~~ "```" ~~ (lang : LetterCharacter ...) ~~ Shortest[___] ~~ StartOfLine ~~ "```" ~~ EndOfLine
		) :> Replace[lang, {
				"" :> Code[trimCodeBlock[code]],
				other_ :> Code[trimCodeBlock[code], lang]
			}]
	}];

	parsed
]

(*------------------------------------*)

trimCodeBlock[code_?StringQ] :=
	StringTrim @ StringTrim[code, "```" ~~ Shortest[___] ~~ EndOfLine]


(*========================================================*)

(*
	This value is currently the same as that used by functions in
	ChristopherWolfram/OpenAILink
*)
$openAICredentialKey = "OPENAI_API_KEY"

SetFallthroughError[chatRequest]

(* TODO: Replace this with function from ChristopherWolfram/OpenAILink once
	available. *)
chatRequest[
	messages_,
	params_?AssociationQ
] := Module[{
	apiKey,
	request
},
	apiKey = SystemCredential[$openAICredentialKey];

	request = chatHTTPRequest[
		messages,
		params,
		apiKey
	];

	RaiseConfirmMatch[request, _HTTPRequest];

	URLRead[request]
]

(*====================================*)

(* TODO: Replace this boilerplate with ChristopherWolfram/OpenAILink API calls. *)

SetFallthroughError[chatHTTPRequest]

Options[chatHTTPRequest] = {
	"Stream" -> False
}

chatHTTPRequest[
	messages_,
	params_?AssociationQ,
	apiKey_?StringQ,
	OptionsPattern[]
] := Module[{
	tokenLimit,
	temperature,
	request
},
	(* TODO: Better error. *)
	RaiseConfirmMatch[messages, {___?AssociationQ}];

	model = ConfirmReplace[Lookup[params, "Model", Automatic], {
		Automatic -> "gpt-3.5-turbo",
		m_?StringQ :> m,
		other_ :> Raise[
			ChatbookError,
			"Invalid chat model specification: ``",
			InputForm[other]
		]
	}];

	(* TODO: Better error here. *)
	tokenLimit = RaiseConfirmMatch[
		Lookup[params, "TokenLimit", Infinity],
		Infinity | _?IntegerQ
	];
	(* TODO: Better error here. *)
	temperature = RaiseConfirmMatch[
		Lookup[params, "Temperature", 0.70],
		_?IntegerQ | _Real?NumberQ
	];

	(* TODO: Better error here. *)
	stream = RaiseConfirmMatch[OptionValue["Stream"], _?BooleanQ];

	(* FIXME: Produce a better error message if this credential key doesn't
		exist; tell the user that they need to set SystemCredential. *)
	If[!StringQ[apiKey],
		Raise[
			ChatbookError,
			<| "SystemCredentialKey" -> $openAICredentialKey |>,
			"unexpected result getting OpenAI API Key from SystemCredential: ``",
			InputForm[apiKey]
		];
	];

	request = HTTPRequest[<|
		"Method" -> "POST",
		"Scheme" -> "HTTPS",
		"Domain" -> "api.openai.com",
		"Path" -> {"v1", "chat", "completions"},
		"Body" -> ExportByteArray[
			<|
				"model" -> model,
				"messages" -> messages,
				ConfirmReplace[tokenLimit, {
					Infinity -> Nothing,
					maxTokens_?IntegerQ :> (
						"max_tokens" -> maxTokens
					)
				}],
				"temperature" -> temperature,
				"stream" -> stream
			|>,
			"JSON"
		],
		"ContentType" -> "application/json",
		"Headers" -> {
			"Authorization" -> "Bearer " <> apiKey
		}
	|>];

	request
]

(*========================================================*)

$dynamicMenuLabel := DynamicModule[ { cell },
	Dynamic @ Quiet @ catchAlways @ If[ TrueQ @ $cloudNotebooks,
		RawBoxes @ TemplateBox[{}, "ChatIconUser"],
		With[{
			personaValue = currentValueOrigin[cell, {TaggingRules, "ChatNotebookSettings", "LLMEvaluator"}]
		},
			getPersonaMenuIcon @ Lookup[
				GetPersonasAssociation[],
				personaValue[[2]]
			]
		]
	],
	Initialization :> (
		Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
		cell = catchAlways @ parentCell @ EvaluationCell[ ]
	),
	UnsavedVariables :> {cell}
]

MakeChatInputActiveCellDingbat[] := Module[{
	menuLabel,
	button
},
	(*-----------------------------------------*)
	(* Construct the action menu display label *)
	(*-----------------------------------------*)

	menuLabel = $dynamicMenuLabel;

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


MakeChatDelimiterCellDingbat[] := Module[{
	menuLabel,
	button
},
	(*-----------------------------------------*)
	(* Construct the action menu display label *)
	(*-----------------------------------------*)

	menuLabel = $dynamicMenuLabel;

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
		personas = KeySort[
			personas,
			FirstMatchingPositionOrder[{
				"PlainChat",
				"RawModel",
				"CodeWriter",
				"CodeAssistant"
			}]
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
					Hold[callback["Persona", persona]]
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

SetFallthroughError[currentValueOrigin]

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

	inlineValue = nestedLookup[
		Options[targetObj],
		keyPath,
		None
	];

	Which[
		inlineValue === None,
			{"Inherited", value},
		True,
			{"Inline", inlineValue}
	]
]

(*====================================*)

getModelsMenuItems[] := Module[{
	items
},
	items = Select[
		getModelList[],
		StringStartsQ["gpt-"]
	];

	RaiseAssert[MatchQ[items, {___String}]];

	items = Sort[items];

	If[!TrueQ[showSnapshotModelsQ[]],
		items = Select[
			items,
			modelName |-> (
				!StringMatchQ[modelName, RegularExpression["gpt-.*-[0-9]{4}"]]
			)
		];
	];

	items = AssociationMap[getModelSettings, items];

	RaiseAssert[MatchQ[items, <| (_?StringQ -> _?AssociationQ)... |>]];

	items
]

(*====================================*)

SetFallthroughError[getModelSettings]

getModelSettings[modelName_?StringQ] := Module[{
	icon
},
	icon = Which[
		StringStartsQ[modelName, "gpt-3.5"],
			getIcon["ModelGPT35"],
		StringStartsQ[modelName, "gpt-4"],
			getIcon["ModelGPT4"],
		True,
			None
	];

	<| "Icon" -> icon |>
]


(*========================================================*)
(* Menu construction helpers                              *)
(*========================================================*)

SetFallthroughError[alignedMenuIcon]

alignedMenuIcon[possible_, current_, icon_] :=alignedMenuIcon[styleListItem[possible, current], icon]
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

SetFallthroughError[modelDisplayName]

modelDisplayName[{name_?StringQ, settings_?AssociationQ}] :=
	modelDisplayName[name]

modelDisplayName[name_?StringQ] := Replace[name, {
	"gpt-3.5-turbo"           -> "GPT-3.5 Turbo",
	"gpt-3.5-turbo-0301"      -> "GPT-3.5 Turbo (March 01)",
	"gpt-3.5-turbo-0613"      -> "GPT-3.5 Turbo (June 13)",
	"gpt-3.5-turbo-16k"       -> "GPT-3.5 Turbo 16k",
	"gpt-3.5-turbo-16k-0613"  -> "GPT-3.5 Turbo 16k (June 13)",
	"gpt-4"                   -> "GPT-4",
	"gpt-4-0314"              -> "GPT-4 (March 14)",
	"gpt-4-0613"              -> "GPT-4 (June 13)",

	(* Leave unknown models as they are. *)
	unknown_                  :> unknown
}]

(*====================================*)

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