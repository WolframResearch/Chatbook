BeginPackage["ConnorGray`Chatbook`UI`"]

Needs["GeneralUtilities`" -> "GU`"]

GU`SetUsage[ChatInputCellEvaluationFunction, "
ChatInputCellEvaluationFunction[input$, form$] is the CellEvaluationFunction for chat input cells.
"]

Begin["`Private`"]

Needs["ConnorGray`Chatbook`"]
Needs["ConnorGray`Chatbook`ErrorUtils`"]
Needs["ConnorGray`Chatbook`Errors`"]
Needs["ConnorGray`Chatbook`Debug`"]
Needs["ConnorGray`Chatbook`Utils`"]

Needs["ConnorGray`ServerSentEventUtils`" -> "SSEUtils`"]



SetFallthroughError[ChatInputCellEvaluationFunction]

ChatInputCellEvaluationFunction[
	input_,
	form_
] := Module[{
	chatGroupCells,
	additionalContextStyles,
	tokenLimit,
	temperature,
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
		that come before the current cell inside the innermost cell group.
	*)
	chatGroupCells = Append[precedingCellsInGroup[], EvaluationCell[]];
	chatGroupCells = NotebookRead[chatGroupCells];

	additionalContextStyles = ConfirmReplace[$ChatContextCellStyles, {
		value_?AssociationQ :> value,
		other_ :> (
			ChatbookWarning[
				"$ChatContextCellStyles must be an Association. Got: ``",
				InputForm[other]
			];
			<||>
		)
	}];

	req = Map[
		cell |-> promptProcess[cell, additionalContextStyles],
		chatGroupCells
	];

	If[StringQ[$ChatSystemPre] && $ChatSystemPre =!= "",
		PrependTo[req, <| "role" -> "system", "content" -> $ChatSystemPre |>];
	];

	If[StringQ[$ChatInputPost] && $ChatInputPost =!= "",
		AppendTo[req, <| "role" -> "user", "content" -> $ChatInputPost |>];
	];

	RaiseAssert[
		MatchQ[req, {<| "role" -> _?StringQ, "content" -> _?StringQ |> ...}],
		"unexpected form for parsed chat input: ``", InputForm[req]
	];

	(*----------------------------------------------------------------------*)
	(* Put the insertion point where it belongs after the old output        *)
	(*----------------------------------------------------------------------*)

	moveAfterPreviousOutputs[EvaluationCell[]];

	(*----------------------------------------------------------------------*)
	(* Extract the token limit and temperature from the evaluation cell     *)
	(*----------------------------------------------------------------------*)

	{tokenLimit, temperature} =
		With[{opts = FullOptions[EvaluationCell[], TaggingRules]},
			{Lookup[opts, "TokenLimit", "1000"], Lookup[opts, "Temperature", "0.7"]}
		];

	params = <|
		"TokenLimit" -> ToExpression[tokenLimit],
		"Temperature" -> ToExpression[temperature]
	|>;

	(*--------------------------------*)
	(* Perform the API request        *)
	(*--------------------------------*)

	$LastRequestChatMessages = req;
	$LastRequestParameters = params;


	(* doSyncChatRequest[req, params] *)


	doAsyncChatRequest[EvaluationNotebook[], req, params]
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

	deletePreviousOutputs[EvaluationCell[]];

	processResponse[processed];
]

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

	$state["EvaluationCell"] = EvaluationCell[];
	$state["Buffer"] = "";
	$state["CurrentCell"] = None;

	SelectionMove[cell, After, EvaluationCell[]];

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
			"BodyChunkReceived" -> SSEUtils`ServerSentEventBodyChunkTransformer[
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

	RaiseAssert[
		MatchQ[data, _?AssociationQ],
		"Unexpected chat streaming response JSON parse result: ``",
		InputForm[json]
	];

	data = ConfirmReplace[data, {
		KeyValuePattern[{
			(* TODO: What about other possible choices? *)
			"choices" -> {firstChoice_, ___}
		}] :> firstChoice,
		other_ :> Raise[
			ChatbookError,
			"Unexpected chat streaming response object form: ``",
			InputForm[other]
		]
	}];

	ConfirmReplace[data, {
		KeyValuePattern[{
			"delta" -> KeyValuePattern[{
				"content" -> text_?StringQ
			}]
		}] :> (
			(* Print["Chunk: ", InputForm[text]]; *)
			$state["Buffer"] = StringJoin[$state["Buffer"], text];
		),
		(* FIXME: Handle this change in role by changing cell type if necessary? *)
		KeyValuePattern[{
			"delta" -> KeyValuePattern[{
				"role" -> "assistant"
			}]
		}] :> Null,
		(* FIXME: Handle this streaming end better. *)
		KeyValuePattern[{
			"delta" -> <||>,
			"finish_reason" -> "stop"
		}] :> (
			(*
				If there is any remaining data in the buffer that wasn't
				written out, write it out now. This can happen if the last token
				is a string that is ambiguous to parse (e.g. "`").
			*)
			If[$state["Buffer"] =!= "",
				writeContent[$state, $state["Buffer"]]
			];
		),
		other_ :> Raise[
			ChatbookError,
			"Unexpected chat streaming response object form: ``",
			InputForm[other]
		]
	}];

	(*--------------------------------*)
	(* Process the buffer.            *)
	(*--------------------------------*)

	RaiseAssert[StringQ[$state["Buffer"]]];

	While[$state["Buffer"] =!= "",
		(* Print["Buffer => ", InputForm[$state["Buffer"]]]; *)

		StringReplace[$state["Buffer"], {
			StartOfString ~~ prefix:Repeated[Except["`" | "\n"]] ~~ rest___ ~~ EndOfString :> (
				writeContent[$state, prefix];
				$state["Buffer"] = rest;
			),
			(* Recognize incomplete input that might be a ``` code block start
				or end marker. *)
			StartOfString ~~ RepeatedNull["\n", 1] ~~ Repeated["`", {1, 2}] ~~ EndOfString :> (
				(*
					We don't have enough buffered data to know if we should
					start or end a code block or not. Break out of the buffer
					processing loop until we recieve more input.
				*)
				Break[];
			),
			(*--------------------------------------------------*)
			(* Recognize a ``` that starts or ends a code block *)
			(*--------------------------------------------------*)
			StartOfString
			~~ RepeatedNull["\n", 1] ~~ "```" ~~ spec:RepeatedNull[Except["`" | "\n"]]
			~~ RepeatedNull["\n", 1] ~~ rest___ ~~ EndOfString :> (

				ConfirmReplace[$state["CurrentCell"], {
					(* If we haven't written any cell yet, then this ``` must
						be the first thing sent from the LLM, so make the
						initial cell a code output cell. *)
					None :> startCurrentCell[$state, makeCodeBlockCell["", spec]],
					KeyValuePattern[{ "Style" -> currentStyle_ }] :> Module[{newCell},
						newCell = ConfirmReplace[currentStyle, {
							(* If the current cell is a non-code cell, then this
								"```" must be starting a code block. *)
							"ChatAssistantText"
								:> makeCodeBlockCell["", spec],
							(* If the current cell is a code cell, then this
								"```" must be ending a code block. *)
							"ChatAssistantProgram"
							| "ChatAssistantOutput"
							| "ChatAssistantExternalLanguage"
								:> Cell[TextData[""], "ChatAssistantText"]
						}];

						startCurrentCell[$state, newCell]
					]
				}];

				$state["Buffer"] = rest;
			),
			(* Write any other input out directly. *)
			_ :> (
				writeContent[$state, $state["Buffer"]];
				$state["Buffer"] = "";
			)
		}];
	];
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
	nb
},
	If[StringQ[SystemCredential["OPENAI_API_KEY"]] && !provenBad,
		Return[True]
	];

	nb = Notebook[{
		Cell["ChatGPT API Key Required", "Subsection", TextAlignment -> Center],

		Cell[
			TextData[Flatten[{
				If[provenBad,
					{"The ChatGPT API Key you have installed was not accepted by OpenAI. You can install a different one by pasting it into the field below and clicking ",
						StyleBox["Install API Key.",
						FontFamily -> CurrentValue["ControlsFontFamily"]]},

					"To use ChatGPT features you must have a valid ChatGPT API key installed. "
				],
				"If you don't have one, you can get a free one by following these instructions.\n\n",
				"\t(1) Login or create a free account at ",
				ButtonBox[
					"https://chat.openai.com/auth/login",
					BaseStyle -> "Hyperlink",
					ButtonData -> {URL["https://chat.openai.com/auth/login"], None}
				],
				"\n\t(2) View your API Key at ",
				ButtonBox[
					"https://platform.openai.com/account/api-keys",
					BaseStyle -> "Hyperlink",
					ButtonData -> {URL["https://platform.openai.com/account/api-keys"], None}
				],
				"\n\t(3) Copy/paste the key into the field below, then click ",
				StyleBox["Install API Key.", FontFamily -> CurrentValue["ControlsFontFamily"]]
			}]],
			"Text",
			FontFamily -> CurrentValue["PanelFontFamily"],
			CellMargins -> {{20, 20}, {10, 10}}
		],

		Cell[
			BoxData @ RowBox[{
				StyleBox[
					InputFieldBox[
						"",
						String,
						FieldSize -> 45,
						FieldHint -> "Paste ChaptGPT API Key Here",
						(* Don't show the API key. Useful if the user is
							e.g. screensharing when they paste it in. *)
						FieldMasked -> True
					],
					ShowSelection -> True
				]
			}],
			"Text",
			TextAlignment -> Center,
			CellMargins -> {{20, 20}, {10, 10}},
			FontFamily -> CurrentValue["ControlsFontFamily"]
		],

		Cell[
			TextData["If you need to change your API key in the future, use the non-existant Credentials tab in the Preferences dialog."],
			"Text",
			FontFamily -> CurrentValue["PanelFontFamily"],
			CellMargins -> {{20, 20}, {10, 10}}
		],

		Cell[
			BoxData[RowBox[{

			ButtonBox[
			StyleBox["Install API Key",
				FontFamily -> CurrentValue["ControlsFontFamily"]],
			ButtonFunction :> (

				SystemCredential["OPENAI_API_KEY"] =
				Cases[NotebookGet[EvaluationNotebook[]], _InputFieldBox,
					Infinity][[1, 1]];
				NotebookClose[EvaluationNotebook[]];
				), Evaluator -> Automatic, Method -> "Preemptive"],
			"   ",

			ButtonBox[
			StyleBox["Cancel",
				FontFamily -> CurrentValue["ControlsFontFamily"]],
			ButtonFunction :> NotebookClose[EvaluationNotebook[]]]
			}]],
			"Text",
			TextAlignment -> Center,
			CellMargins -> {{20, 20}, {10, 10}}
		]
	}];

	NotebookPut[
		nb,
		WindowFrame -> "ModelessDialog",
		WindowSize -> {800, FitAll},
		ShowCellBracket -> False,
		ShowSelection -> False,
		Selectable -> False,
		Editable -> False,
		WindowElements -> {},
		WindowTitle -> "ChatGPT API Key"
	];

	False
];


(*========================================================*)
(* Cell Processing                                        *)
(*========================================================*)

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
]

(*====================================*)

SetFallthroughError[promptProcess]

promptProcess[
	cell0_,
	additionalContextStyles_?AssociationQ
] := ConfirmReplace[cell0, {
	Cell[CellGroupData[___], ___] :> Nothing,

	Cell[expr_, "ChatUserInput" |
				(*Deprecated names*) "ChatGPTInput" | "ChatGPTUserInput", ___]
		:> <| "role" -> "user", "content" -> promptCellDataToString[expr] |>,

	Cell[expr_, "ChatAssistantOutput" | "ChatAssistantText" | "ChatAssistantProgram" | "ChatAssistantExternalLanguage", ___]
		:> <| "role" -> "assistant", "content" -> promptCellDataToString[expr] |>,

	Cell[expr_, "ChatSystemInput" | (*Deprecated names*) "ChatGPTSystemInput", ___]
		:> <| "role" -> "system", "content" -> promptCellDataToString[expr] |>,

	(*
		If a Cell isn't one of the built-in recognized styles, check to see if
		there are any additional styles that have been specified to include.
	*)
	Cell[expr_, styles0___?StringQ, ___?OptionQ] :> Module[{
		styles = {styles0}
	},
		(* Only consider styles that are in `includedStyles` *)
		styles = Intersection[styles, Keys[additionalContextStyles]];

		ConfirmReplace[styles, {
			{} :> Nothing,
			{first_, rest___} :> Module[{role},
				(* FIXME: Issue a warning if rest contains cell styles that map
				    to conflicting roles. *)
				(* If[Length[{rest}] > 0,
					ChatWarning
				]; *)

				(* FIXME: Better error if this confirm fails. *)
				role = RaiseConfirmMatch[
					Lookup[additionalContextStyles, first],
					_?StringQ
				];

				<| "role" -> role, "content" -> promptCellDataToString[expr] |>
			]
		}]
	],

	(*-----------------------------------------------*)
	(* Ignore cells of any other unrecognized style. *)
	(*-----------------------------------------------*)

	(* Ignore unrecognized cell types. *)
	(* TODO: Should try to treat every cell type as input to the chat?
		It is currently unintuitive that there isn't any obvious way to know
		whether a cell in a cell group will be sent to the AI or not.

		In addition to being unintuitive, this also makes it difficult for a
		user to reason about what cells are "private" and not sent over the
		internet to the AI.
	*)
	other_ :> Nothing
}]

(*------------------------------------*)

SetFallthroughError[promptCellDataToString]

promptCellDataToString[cdata_] := ConfirmReplace[cdata, {
	s_?StringQ :> s,

	(* TODO: Is this incorrect, or desirable? The string contains "TextData[..]",
		but this makes the example of ChatGPT describing the visual appearance
		of a styled text/box data cell work. *)

	bd:BoxData[_] :> ToString[bd],
	td:TextData[_] :> ToString[td],

	(* "content" -> ToString[
		expr //. {
			BoxData[e_, ___] :> e,
			FormBox[e_, ___] :> e
		}
	] *)

	other_ :> (
		Print["warning: unexpected prompt cell data: ", InputForm[other]];

		(* Hope that ToString is better than nothing. *)
		ToString[other]
	)
}]

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


End[]

EndPackage[]
