(* ::Package:: *)

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

MakeChatInputCellDingbat
MakeChatInputLLMConfigurationActionMenu
GetChatInputLLMConfigurationSelectorMenuData

Begin["`Private`"]

Needs["Wolfram`Chatbook`"]
Needs["Wolfram`Chatbook`ErrorUtils`"]
Needs["Wolfram`Chatbook`Errors`"]
Needs["Wolfram`Chatbook`Debug`"]
Needs["Wolfram`Chatbook`Utils`"]
Needs["Wolfram`Chatbook`Streaming`"]
Needs["Wolfram`Chatbook`Serialization`"]
Needs["Wolfram`Chatbook`Menus`"]
Needs["Wolfram`Chatbook`Personas`"]


Needs["Wolfram`ServerSentEventUtils`" -> None]


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

ChatExplainButtonFunction[cellobj_] := Module[{},
	NotebookDelete[Cells[cellobj, AttachedCell -> True]];
	AttachCell[
		cellobj,
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
										NotebookImport[Notebook[{NotebookRead[cellobj]}], _ -> "InputText"]
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
	cellobj_,
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

EditChatContextSettings[cellobj_] := Module[{
	cell
},
	If[Cells[cellobj, AttachedCell -> True] =!= {},
		NotebookDelete[Cells[cellobj, AttachedCell -> True]];
		Return[]
	];

	cell = Cell[
		BoxData @ DynamicModuleBox[{
			$CellContext`tableContentsPreprompt$$ =
				If[ListQ[CurrentValue[cellobj, {TaggingRules, "ChatContextPreprompt"}]],
					Map[
						{#["role"], #["content"]} &,
						CurrentValue[cellobj, {TaggingRules, "ChatContextPreprompt"}]
					]
					,
					{}
				],
			$CellContext`tableContentsPostprompt$$ =
				If[ListQ[CurrentValue[cellobj, {TaggingRules, "ChatContextPostprompt"}]],
					Map[
						{#["role"], #["content"]} &,
						CurrentValue[cellobj, {TaggingRules, "ChatContextPostprompt"}]
					]
					,
					{}
				],

			$CellContext`tableContentsActAsDelimiter$$ =
				CurrentValue[cellobj, {TaggingRules, "ChatContextDelimiter"}] =!= False,

			$CellContext`tableContentsChatContextCellProcessingFunction$$ =
				(CurrentValue[cellobj, {TaggingRules, "ChatContextCellProcessingFunction"}] /. Inherited -> Automatic),

			$CellContext`tableContentsChatContextPostEvaluationFunction$$ =
				(CurrentValue[cellobj, {TaggingRules, "ChatContextPostEvaluationFunction"}] /. Inherited -> Automatic)
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
									cellobj,
									"ChatContextPreprompt",
									Dynamic[$CellContext`tableContentsPreprompt$$]
								]
							},
							{""},
							{StyleBox["ChatContextPostprompt", FontSize->12]},
							{
								OnePromptTableEditor[
									cellobj,
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
													cellobj,
													{TaggingRules, "ChatContextDelimiter"}
												] = $CellContext`tableContentsActAsDelimiter$$;

												CurrentValue[
													cellobj,
													{"TaggingRules", "ChatContextPreprompt"}
												] = Map[
													<|"role" -> #[[1]], "content" -> #[[2]]|> &,
													$CellContext`tableContentsPreprompt$$
												];

												CurrentValue[
													cellobj,
													{"TaggingRules", "ChatContextPostprompt"}
												] = Map[
													<|"role" -> #[[1]], "content" -> #[[2]]|> &,
													$CellContext`tableContentsPostprompt$$
												];

												CurrentValue[
													cellobj,
													{TaggingRules, "ChatContextCellProcessingFunction"}
												] = $CellContext`tableContentsChatContextCellProcessingFunction$$;

												(* ChatContextPostEvaluationFunction is set twice: once in tagging rules, and then in
												the option that causes it to be used as the CellEpilog of all cells within the group
												this cell is the head of. *)
												CurrentValue[
													cellobj,
													{TaggingRules, "ChatContextPostEvaluationFunction"}
												] = $CellContext`tableContentsChatContextPostEvaluationFunction$$;

												$CellContext`tableContentsChatContextPostEvaluationFunction$$ /. Hold[e_] :>
													SetOptions[
														cellobj,
														PrivateCellOptions->{"CellGroupBaseStyle" -> {
															CellEpilog :> Wolfram`Chatbook`UI`ChatContextEpilogFunction[e]}
														}
													];

												NotebookDelete[Cells[cellobj, AttachedCell -> True]];
											)
										],
										ButtonBox[
											FrameBox["Cancel"],
											Evaluator -> Automatic,
											Appearance -> None,
											ButtonFunction :> (
												NotebookDelete[Cells[cellobj, AttachedCell -> True]]
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

	AttachCell[cellobj, cell, "Inline"];
];

EditChatSettingsForCell[cellobj_] := Module[{
		cell
	},
	If[Cells[cellobj, AttachedCell -> True] =!= {},
		NotebookDelete[Cells[cellobj, AttachedCell -> True]];
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

	AttachCell[cellobj, cell, Top];
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
			"BodyChunkReceived" -> Wolfram`ServerSentEventUtils`ServerSentEventBodyChunkTransformer[
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
					if you use BodyChunkRecieved, you can't access the "Body"
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
	ssevent_?AssociationQ
] := Module[{
	data
},
	data = Replace[ssevent, {
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
			recieve more input.
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
		currCellObj = $state["CurrentCell"]["Object"]
	},
		RaiseConfirmMatch[currCellObj, _CellObject];
		RaiseAssert[Experimental`CellExistsQ[currCellObj]];

		SelectionMove[currCellObj, After, CellContents];

		WithCleanup[
			(* NOTE:
				Temporarily prevent the automatic cell edit duplicate FE
				behavior from occurring during this write. This prevents our
				programmatic edit to the cell from causing it to be
				automatically transformed into an Input cell (which is the
				desired behavior when a user manually edits a code cell
				generated by the AI).
			*)
			SetOptions[currCellObj, CellEditDuplicate -> False]
			,
			NotebookWrite[
				RaiseConfirm @ ParentNotebook[currCellObj],
				content
			];
			,
			SetOptions[currCellObj, CellEditDuplicate -> Inherited]
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

cellIsChatDelimiter[cellobj_CellObject] :=
	TrueQ[FullOptions[cellobj, TaggingRules]["ChatContextDelimiter"]];

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
			Cells[nb, CellStyle -> "ChatContextDivider"]
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

previousOutputs[cellobj_CellObject] :=
	Module[{
		nbobj = ParentNotebook[cellobj],
		cells, objs = {}
	},
		If[Not @ TrueQ @ AbsoluteCurrentValue[nbobj, OutputAutoOverwrite], Return[{}]];
		cells = NextCell[cellobj, All];
		If[!MatchQ[cells, {__CellObject}], Return[{}]];
		Do[
			If[
				TrueQ @ AbsoluteCurrentValue[cell, Deletable] &&
				TrueQ @ AbsoluteCurrentValue[cell, CellAutoOverwrite], AppendTo[objs, cell], Break[]],
			{cell, cells}
		];
		objs
	]


deletePreviousOutputs[cellobj_CellObject] :=
	Replace[previousOutputs[cellobj], {
		cells: {__CellObject} :> NotebookDelete[cells],
		_ :> None
	}]

moveAfterPreviousOutputs[cellobj_CellObject] :=
	Replace[previousOutputs[cellobj], {
		{___, lastcell_CellObject} :> SelectionMove[lastcell, After, Cell],
		_ :> SelectionMove[cellobj, After, Cell]
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
			s_?StringQ
				:> CellPrint @ Cell[StringTrim[s], "ChatAssistantText"],
			Code[s_?StringQ]
				:> CellPrint[makeCodeBlockCell[s, None]],
			Code[s_?StringQ, lang_?StringQ]
				:> CellPrint[makeCodeBlockCell[s, lang]],
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
			StartOfLine ~~ "```" ~~ (lang : LetterCharacter ...) ~~ Shortest[___]
			~~ StartOfLine ~~ "```" ~~ EndOfLine
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

MakeChatInputCellDingbat[] := With[{
	dingbatCellObj = EvaluationCell[],
	chatInputCellObj = ParentCell[EvaluationCell[]]
}, Module[{
	menuData = GetChatInputLLMConfigurationSelectorMenuData[],
	actionCallback,
	actionMenu,
	menu
},
	(* NOTE:
		This is needed here due to its use in TrackedSymbols in the stylesheet.
		Without this, the CellDingbat dynamic will not refresh when changes are
		made to the inherited TaggingRules.
	*)
	Wolfram`Chatbook`UI`$ChatInputMenuDataChanged;

	actionCallback = Function[{field, value}, Replace[field, {
		"Persona" :> (
			CurrentValue[
				chatInputCellObj,
				{TaggingRules, "ChatNotebookSettings", "LLMEvaluator"}
			] = value;
			NotebookDelete[Cells[dingbatCellObj, AttachedCell->True]];
		),
		"Model" :> (
			CurrentValue[
				chatInputCellObj,
				{TaggingRules, "ChatNotebookSettings", "Model"}
			] = value;
			NotebookDelete[Cells[dingbatCellObj, AttachedCell->True]];
		),
		"Role" :> (
			CurrentValue[
				chatInputCellObj,
				{TaggingRules, "ChatNotebookSettings", "Role"}
			] = value;
			NotebookDelete[Cells[dingbatCellObj, AttachedCell->True]];
		),
		other_ :> (
			ChatbookWarning[
				"Unexpected field set from LLM configuration action menu: `` => ``",
				InputForm[other],
				InputForm[value]
			];
		)
	}]];

	actionMenu = MakeChatInputLLMConfigurationActionMenu[
		menuData["Personas"],
		menuData["Models"],
		"ActionCallback" -> actionCallback,
		"PersonaValue" -> currentValueOrigin[
			chatInputCellObj,
			{TaggingRules, "ChatNotebookSettings", "LLMEvaluator"}
		],
		"ModelValue" -> currentValueOrigin[
			chatInputCellObj,
			{TaggingRules, "ChatNotebookSettings", "Model"}
		],
		"RoleValue" -> currentValueOrigin[
			chatInputCellObj,
			{TaggingRules, "ChatNotebookSettings", "Role"}
		]
	];

	(* menu = Tooltip[
		actionMenu,
		CurrentValue[
			ParentCell[EvaluationCell[]],
			valueKeyPath
		]
	]; *)

	menu = actionMenu;

	Row[{
		RawBoxes @ TemplateBox[{}, "ChatCounterLabel"],
		menu
	}]
]]

(*====================================*)

(*
	Get the current value and origin of a cell option value.

	This function will return {origin, value}, where `origin` will be one of:

	* "Inline"    -- this value is set inline in the specified CellObject
	* "Inherited" -- this value is inherited from a style setting outside of the
		specified CellObject.
*)
currentValueOrigin[
	cell_CellObject,
	keyPath_List
] := Module[{
	value,
	inlineValue
},
	value = CurrentValue[cell, keyPath];

	(* FIXME: Don't use a ResourceFunction in this code. *)
	inlineValue = Quiet @ ResourceFunction["NestedLookup"][
		Options[cell],
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

SetFallthroughError[MakeChatInputLLMConfigurationActionMenu]

Options[MakeChatInputLLMConfigurationActionMenu] = {
	"PersonaValue" -> Automatic,
	"ModelValue" -> Automatic,
	"RoleValue" -> Automatic,
	"ActionCallback" -> (Null &)
}

MakeChatInputLLMConfigurationActionMenu[
	(* List of {tagging rule value, icon, list item label} *)
	personas:{___List},
	(* List of {tagging rule value, icon, list item label} *)
	models:{___List},
	OptionsPattern[]
] := With[{
	callback = OptionValue["ActionCallback"]
}, Module[{
	personaValue = OptionValue["PersonaValue"],
	modelValue = OptionValue["ModelValue"],
	roleValue = OptionValue["RoleValue"],
	menuLabel,
	menuItems
},
	(*-----------------------------------------*)
	(* Construct the action menu display label *)
	(*-----------------------------------------*)

	menuLabel = FirstCase[
		personas,
		{personaValue[[2]], icon_, _} :> icon,
		Style["\[LongDash]", GrayLevel[0.5]]
	];

	(*------------------------------------*)
	(* Construct the popup menu item list *)
	(*------------------------------------*)

	menuItems = Join[
		{
			Style["Personas",
				FontSize -> 16,
				FontVariations -> {"CapsType" -> "SmallCaps"},
				GrayLevel[0.5]
			]
		},
		Map[
			entry |-> ConfirmReplace[entry, {
				{persona_?StringQ, icon_, listItemLabel_} :> (
					Row[{
						styleListItem[persona, personaValue],
						" ",
						icon,
						Spacer[7],
						listItemLabel
					}] :> (
						callback["Persona", persona];
					)
				)
			}],
			personas
		],
		{
			Delimiter,
			Row[{getIcon["persona-other.wl"], Spacer[7], "More Personas\[Ellipsis]"}] :> (
				(* FIXME: Implement this. *)
				MessageDialog["Not Implemented: Get More Personas"];
			),
			Row[{getIcon["persona-from-url.wl"], Spacer[7], "Install From URL\[Ellipsis]"}] :> (
				(* FIXME: Implement this. *)
				MessageDialog["Not Implemented: Install From URL"]
			)
		},
		{Delimiter},
		{
			Style["Models",
				FontSize -> 16,
				FontVariations -> {"CapsType" -> "SmallCaps"},
				GrayLevel[0.5]
			]
		},
		Map[
			entry |-> ConfirmReplace[entry, {
				{model_?StringQ, icon_, listItemLabel_} :> (
					Row[{
						styleListItem[model, modelValue],
						" ",
						icon,
						Spacer[7],
						listItemLabel
					}] :> (
						callback["Model", model];
					)
				)
			}],
			models
		],
		{Delimiter},
		{
			Style["Roles",
				FontSize -> 16,
				FontVariations -> {"CapsType" -> "SmallCaps"},
				GrayLevel[0.5]
			]
		},
		Map[
			entry |-> ConfirmReplace[entry, {
				{role_?StringQ, icon_} :> (
					Row[{
						styleListItem[role, roleValue],
						" ",
						icon,
						Spacer[7],
						role
					}] :> (
						callback["Role", role];
					)
				)
			}],
			{
				{"User", getIcon["role-user.wl"]},
				{"System", getIcon["role-system.wl"]}
			}
		]
	];

	menu = MakeMenu[
		menuItems,
		GrayLevel[0.85],
		250
	];

	Button[
		Framed[
			Row[{menuLabel, "\[RightAngleBracket]"}],
			RoundingRadius -> 3,
			FrameMargins -> 2,
			ImageMargins -> {{0, 3}, {0, 0}},
			FrameStyle -> Directive[
				RGBColor[0.8549, 0.83137, 0.72549],
				AbsoluteThickness[1]
			],
			FrameMargins -> 0
		],
		(
			AttachCell[
				EvaluationCell[],
				menu,
				{Left, Bottom},
				Offset[],
				{Left, Top},
				RemovalConditions -> {"EvaluatorQuit", "MouseClickOutside"}
			];
		),
		Appearance -> None
	]
]]

(*------------------------------------*)

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
			Style["\[Checkmark]", GrayLevel[0.75]],
		(* This possible value is not whatever the currently selected value is. *)
		(* Display a hidden checkmark purely so that this
			is offset by the same amount as list items that
			display a visible checkmark. *)
		_ ->
			Style["\[Checkmark]", Transparent]
	}]
)

(*====================================*)

getIcon[filename_?StringQ] := Module[{
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
]

(*------------------------------------*)

GetChatInputLLMConfigurationSelectorMenuData[] := Module[{
	personas,
	models
},
	(* personas = {
		{"Helper", getIcon["persona-helper.wl"], "Helper"},
		{"Code", getIcon["persona-code.wl"], "Code"},
		{"Documentation", getIcon["persona-documentation.wl"], "Documentation"},
		{"Wolfie", getIcon["persona-wolfie.wl"], "Wolfie"},
		{"Birdnardo", getIcon["persona-birdnardo.wl"], "Birdnardo"},
		{
			"ConnorGray/OrganizerAssistant",
			RawBoxes @ TemplateBox[{
				StyleBox["\"ConnorGray:\"", FontSize -> 10, GrayLevel[
				0.5], StripOnInput -> False
				],
				"\" \"",
				"\"Organizer Assistant\""
			}, "RowDefault"],
			""
		}
	}; *)

	personas = KeyValueMap[
		{key, value} |-> {
			key,
			(* FIXME: Better generic fallback icon? *)
			Replace[
				Lookup[First[value], "Icon"],
				_Missing -> ""
			],
			key
		},
		GetPersonasAssociation[]
	];

	models = {
		(* FIXME: Replace with OpenAI logo *)
		{"gpt-3.5-turbo", getIcon["model-gpt3.5.wl"], "GPT-3.5"},
		{"gpt-4", getIcon["model-gpt4.wl"], "GPT-4"}
	};

	<|
		"Personas" -> personas,
		"Models" -> models
	|>
]

End[]

EndPackage[]
