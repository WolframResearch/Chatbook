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

	moveAfterPreviousOutputs[EvaluationCell[], EvaluationNotebook[]];

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

	doSyncChatRequest[req, params]
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

	deletePreviousOutputs[EvaluationCell[], EvaluationNotebook[]];

	processResponse[processed];
]

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

previousOutputs[cellobj_, nbobj_] :=
	Module[{cells, objs = {}},
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


deletePreviousOutputs[cellobj_, nbobj_] :=
	Replace[previousOutputs[cellobj, nbobj], {
		cells: {__CellObject} :> NotebookDelete[cells],
		_ :> None
	}]

moveAfterPreviousOutputs[cellobj_, nbobj_] :=
	Replace[previousOutputs[cellobj, nbobj], {
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
			s_?StringQ :> CellPrint @ Cell[StringTrim[s], "ChatAssistantText"],
			Code[s_?StringQ] :> CellPrint @ Cell[s, "ChatAssistantProgram"],
			Code[s_?StringQ, "Wolfram" | "Mathematica"] :> CellPrint @ Cell[BoxData[s], "ChatAssistantOutput"],
			Code[s_?StringQ, lang_?StringQ]
				:> CellPrint @ Cell[
					s,
					"ChatAssistantExternalLanguage",
					CellEvaluationLanguage -> Replace[lang, {
						"Bash" -> "Shell"
					}]
				],
			other_ :> Throw[{"Unexpected parsed form: ", InputForm[other]}]
		}],
		parsed
	]
]

(*------------------------------------*)

parseResponse[response_?StringQ] := Module[{
	parsed
},
	parsed = StringSplit[response, {
		code : (
			StartOfLine ~~ "```" ~~ (lang : LetterCharacter ...) ~~ Shortest[___]
			~~ StartOfLine ~~ "```" ~~ EndOfLine
		) :> Replace[lang, {
				"mathematica" :> Code[trimCodeBlock[code], "Wolfram"],
				"" :> Code[trimCodeBlock[code]],
				other_ :> (
					(* Print[
						Style["warning:", Orange],
						" unrecognized language: ",
						other
					]; *)
					Code[trimCodeBlock[code], Capitalize[lang]]
				)
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

chatHTTPRequest[
	messages_,
	params_?AssociationQ,
	apiKey_?StringQ
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
				"temperature" -> temperature
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
