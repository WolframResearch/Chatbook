BeginPackage["ConnorGray`Chatbook`UI`"]

Needs["GeneralUtilities`" -> "GU`"]

GU`SetUsage[ChatInputCellEvaluationFunction, "
ChatInputCellEvaluationFunction[input$, form$] is the CellEvaluationFunction for chat input cells.
"]

Begin["`Private`"]

Needs["ConnorGray`Chatbook`ErrorUtils`"]
Needs["ConnorGray`Chatbook`Errors`"]


SetFallthroughError[ChatInputCellEvaluationFunction]

ChatInputCellEvaluationFunction[
	input_,
	form_
] := Module[{
	req, response, parsed, processed
},
	req = assembleChatGPTPrompt[getEnclosingChatGroup[]];

	response = chatRequest[req];

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

getEnclosingChatGroup[] := Module[{
	return
},
	SelectionMove[EvaluationCell[], All, Cell];
	NotebookFind[EvaluationNotebook[], "Subsubsection", Previous, CellStyle];
	SelectionMove[EvaluationNotebook[], All, CellGroup];
	return = NotebookRead[EvaluationNotebook[]];

	SelectionMove[EvaluationNotebook[], After, CellGroup];

	return
]

(*------------------------------------*)

assembleChatGPTPrompt[evalGroupData_] := Module[{},
	Map[
		promptProcess,
		Cases[evalGroupData, Cell[Except[_CellGroupData], ___], Infinity]]
	]

(*------------------------------------*)

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
					(* FIXME: Handle this better. *)
					Print[
						Style["warning:", Orange],
						" unrecognized language: ``",
						other
					];
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
