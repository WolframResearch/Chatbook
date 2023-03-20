BeginPackage["ConnorGray`Chatbook`UI`"]

Needs["GeneralUtilities`" -> "GU`"]

GU`SetUsage[ChatInputCellEvaluationFunction, "
ChatInputCellEvaluationFunction[input$, form$] is the CellEvaluationFunction for chat input cells.
"]

Begin["`Private`"]

Needs["ConnorGray`Chatbook`"]
Needs["ConnorGray`Chatbook`ErrorUtils`"]
Needs["ConnorGray`Chatbook`Errors`"]


SetFallthroughError[ChatInputCellEvaluationFunction]

ChatInputCellEvaluationFunction[
	input_,
	form_
] := Module[{
	chatGroupCells,
	req, response, parsed, processed
},
	(*--------------------------------*)
	(* Assemble the ChatGPT prompt    *)
	(*--------------------------------*)

	(*
		Construct a chat prompt list from the current cell and all the cells
		that come before the current cell inside the innermost cell group.
	*)
	chatGroupCells = Append[precedingCellsInGroup[], EvaluationCell[]];
	chatGroupCells = NotebookRead[chatGroupCells];

	req = Map[promptProcess, chatGroupCells];

	RaiseAssert[
		MatchQ[req, {___?AssociationQ}],
		"unexpected form for parsed chat input: ``", InputForm[req]
	];

	If[StringQ[$ChatInputPost],
		AppendTo[req, <| "role" -> "user", "content" -> $ChatInputPost |>];
	];

	ConnorGray`Chatbook`Debug`$LastRequestContent = req;

	(*--------------------------------*)
	(* Perform the API request        *)
	(*--------------------------------*)

	response = chatRequest[req];

	ConnorGray`Chatbook`Debug`$LastResponse = response;

	parsed = ConfirmReplace[response, {
		_HTTPResponse :> ImportString[response["Body"], "JSON"],
		_?FailureQ :> Raise[ChatbookError, "Error performing chat API request: ``", response]
	}];

	processed = StringJoin[
		StringTrim["content" /. ("message" /. ("choices" /. parsed))]
	];

	processResponse[processed];
]

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

	(* Select the cell group we just selected. *)
	SelectionMove[cell, After, Cell];

	(* Take all the cells that come before `cell`, dropping the cells that
	   come after `cell`. *)
	cells = TakeWhile[cells, # =!= cell &];

	(* This does not include `cell` itself. *)
	cells
]

(*====================================*)

SetFallthroughError[promptProcess]

promptProcess[cell0_] := ConfirmReplace[cell0, {
	Cell[CellGroupData[___], ___] :> Nothing,

	Cell[_, "Subsubsection", ___] :> Nothing,

	Cell[_, "Print", ___] :> Nothing,

	(* FIXME: Inlude these *)
	Cell[_, "Program" | "ExternalLanguage", ___] :> Nothing,

	Cell[expr_, "Text", ___]
		:> 	<| "role" -> "user", "content" -> ToString[expr] |>,

	Cell[BoxData[expr_, form_], "Input" | "ChatGPTInput", ___]
		:> <| "role" -> "user", "content" -> ToString[ToExpression[expr, form]] |>,

	Cell[expr_, "Input" | "ChatGPTInput", ___]
		:> <| "role" -> "user", "content" -> ToString[expr]|>,

	Cell[expr_, "Output", ___]
		:> <|
			"role" -> "assistant",
			(* FIXME: Process cell content less hackily *)
			"content" -> ToString[
				expr //. {
					BoxData[e_, ___] :> e,
					FormBox[e_, ___] :> e
				}
			]
		|>,


	(* TODO: Relax this hard error; ignore unrecognized cells. *)
	other_ :> Raise[
		ChatbookError,
		"unexpected cell form in chat group: ``",
		InputForm[other]
	]
}]

(*========================================================*)
(* ChatGPT Response Processing                            *)
(*========================================================*)

processResponse[response_?StringQ] := Module[{
	parsed = parseResponse[response]
},
	Scan[
		Replace[{
			s_?StringQ :> CellPrint @ Cell[StringTrim[s], "Text"],
			Code[s_?StringQ] :> CellPrint @ Cell[s, "Program"],
			Code[s_?StringQ, "Wolfram"] :> CellPrint @ Cell[s, "Input"],
			Code[s_?StringQ, lang : ("Python" | "Shell" | "Bash")]
				:> CellPrint @ Cell[
					s,
					"ExternalLanguage",
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
chatRequest[messages_] := Module[{apiKey},
	apiKey = SystemCredential[$openAICredentialKey];

	RaiseConfirmMatch[messages, {___?AssociationQ}];

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

	URLRead[<|
		"Method" -> "POST",
		"Scheme" -> "HTTPS",
		"Domain" -> "api.openai.com",
		"Path" -> {"v1", "chat", "completions"},
		"Body" -> ExportByteArray[
			<|
				"model" -> "gpt-3.5-turbo",
				"temperature" -> 0.7,
				"messages" -> messages
			|>,
			"JSON"
		],
		"ContentType" -> "application/json",
		"Headers" -> {
			"Authorization" -> "Bearer " <> apiKey
		}
	|>]
]

(*========================================================*)


End[]

EndPackage[]
