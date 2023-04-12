BeginPackage["Wolfram`LLMTools`OpenAILink`TextCompletion`"];

Begin["`Private`"];

Needs["Wolfram`LLMTools`OpenAILink`"]
Needs["Wolfram`LLMTools`OpenAILink`Constants`"]
Needs["Wolfram`LLMTools`OpenAILink`Request`"]



(***********************************************************************************)
(******************************* OpenAITextComplete ********************************)
(***********************************************************************************)

(*
	OpenAITextComplete[prompt]
		completes the string starting with the prompt.

	OpenAITextComplete[{prompt, suffix}]
		generates a completion that can be inserted between prompt and suffix.

	OpenAITextComplete[promptSpec, propSpec]
		returns the property or list of properties specified by propSpec.

	OpenAITextComplete[promptSpec, All]
		returns a OpenAITextCompletionObject containing all results of the completion.

	OpenAITextComplete[promptSpec, propSpec, n]
		generates n completions.
*)

Options[OpenAITextComplete] = {
	OpenAIKey            :> $OpenAIKey,
	OpenAIUser           :> $OpenAIUser,
	OpenAIModel          -> Automatic,
	OpenAITemperature    -> Automatic,
	OpenAITopProbability -> Automatic,
	OpenAITokenLimit     -> Automatic,
	OpenAIStopTokens     -> Automatic
};

OpenAITextComplete[args___] :=
	Enclose[
		iOpenAITextComplete@Confirm@ArgumentsOptions[OpenAITextComplete[args], {1,3}],
		"InheritedFailiure"
	]


(* Completion *)
iOpenAITextComplete[{{{prompt_String, suffix:_String|Automatic}, propSpec_, n_}, opts_}] :=
	Module[{rawResponse},
		rawResponse =
			OpenAIRequest[
				{"v1", "completions"},
				Select[
					<|
						"model" -> Replace[OptionValue[OpenAITextComplete,opts,OpenAIModel], Automatic -> "text-davinci-003"],
						"prompt" -> prompt,
						"suffix" -> suffix,
						"n" -> n,
						"temperature" -> OptionValue[OpenAITextComplete,opts,OpenAITemperature],
						"top_p" -> OptionValue[OpenAITextComplete,opts,OpenAITopProbability],
						"max_tokens" -> OptionValue[OpenAITextComplete,opts,OpenAITokenLimit],
						"stop" -> OptionValue[OpenAITextComplete,opts,OpenAIStopTokens],
						"logprobs" -> 5
					|>,
					# =!= Automatic&
				],
				{opts},
				OpenAITextComplete
			];
		conformCompletion[rawResponse, propSpec, {prompt, suffix}]
	]

iOpenAITextComplete[{{prompt_String, propSpec_, n_}, opts_}] :=
	iOpenAITextComplete[{{{prompt, Automatic}, propSpec, n}, opts}]

iOpenAITextComplete[{{promptSpec_, propSpec_, n_}, opts_}] :=
	(
		Message[OpenAITextComplete::invPromptSpec, promptSpec];
		Failure["InvalidPromptSpecification", <|
			"MessageTemplate" :> OpenAITextComplete::invPromptSpec,
			"MessageParameters" -> {promptSpec},
			"PromptSpecification" -> promptSpec
		|>]
)

iOpenAITextComplete[{{promptSpec_, propSpec_}, opts_}] :=
	Replace[iOpenAITextComplete[{{promptSpec, propSpec, 1}, opts}], {res_} :> res]

iOpenAITextComplete[{{promptSpec_}, opts_}] :=
	iOpenAITextComplete[{{promptSpec, "Completion"}, opts}]


conformCompletion[KeyValuePattern[{
		"model" -> model_,
		"usage" -> rawUsage_,
		"choices" -> choices_List
	}], propSpec_, promptSuffix_] :=
	With[{usage = conformUsage[rawUsage]},
		getChoiceProperty[conformCompletionChoice[#, promptSuffix, model, usage], propSpec] &/@ choices
	]

conformCompletion[fail_?FailureQ, propSpec_, promptSuffix_] :=
	fail

conformCompletion[data_, propSpec_, promptSuffix_] :=
	completionResponseError[data]


getChoiceProperty[choice_OpenAITextCompletionObject, All] :=
	choice

getChoiceProperty[choice_OpenAITextCompletionObject, props_List] :=
	choice/@props

getChoiceProperty[choice_OpenAITextCompletionObject, prop_] :=
	choice[prop]

getChoiceProperty[choice_, propSpec_] :=
	choice


conformCompletionChoice[choice: KeyValuePattern[{
		"text" -> text_,
		"finish_reason" -> finishReason_
	}], {prompt_, suffix_}, model_, usage_] :=
	OpenAITextCompletionObject[<|
		"Prompt" -> prompt,
		"Suffix" -> suffix,
		"Completion" -> text,
		"Model" -> model,
		"FinishReason" -> Replace[finishReason, {"length" -> "Length", "stop" -> "Stop"}],
		"ResponseUsage" -> usage,
		"LogProbabilities" -> conformLogProbabilities[choice]
	|>]

conformCompletionChoice[data_, {prompt_, suffix_}, model_, usage_] :=
	completionResponseError[data]


conformLogProbabilities[KeyValuePattern[{"logprobs" -> KeyValuePattern[{"top_logprobs" -> probs:{___?AssociationQ}}]}]] :=
	KeyMap[Replace["<|endoftext|>" -> EndOfString]] /@ probs

conformLogProbabilities[choice_] :=
	Failure["InvalidProbabilitiesResponse", <|
		"MessageTemplate" :> OpenAITextComplete::invProbResponse,
		"MessageParameters" -> {choice["logprobs"]},
		"Response" -> choice
	|>]


conformUsage[KeyValuePattern[{
		"prompt_tokens" -> pTokens_Integer,
		"completion_tokens" -> cTokens_Integer,
		"total_tokens" -> tTokens_Integer
	}]] :=
	<|
		"PromptTokens" -> pTokens,
		"CompletionTokens" -> cTokens,
		"TotalTokens" -> tTokens
	|>

conformUsage[usage_] :=
	Failure["InvalidUsageResponse", <|
		"MessageTemplate" :> OpenAITextComplete::invUsageResponse,
		"MessageParameters" -> {usage}
	|>]


completionResponseError[data_] :=
	(
		Message[OpenAITextComplete::invOpenAITextCompleteResponse, data];
		Failure["InvalidOpenAITextCompleteResponse", <|
			"MessageTemplate" :> OpenAITextComplete::invOpenAITextCompleteResponse,
			"MessageParameters" -> {data},
			"Response" -> data
		|>]
	)


(***********************************************************************************)
(*************************** OpenAITextCompletionObject ****************************)
(***********************************************************************************)


(***** Verifier *****)

HoldPattern[OpenAITextCompletionObject][data:Except[KeyValuePattern[{
		"Completion" -> _String,
		"Prompt" -> _String,
		"Suffix" -> _String | Automatic,
		"Model" -> _,
		"FinishReason" -> _,
		"ResponseUsage" -> _,
		"LogProbabilities" -> {___?AssociationQ}
	}]]] :=
	(
		Message[OpenAITextCompletionObject::invOpenAITextCompletionObject, data];
		Failure["InvalidOpenAITextCompletionObject", <|
			"MessageTemplate" :> OpenAITextCompletionObject::invOpenAITextCompletionObject,
			"MessageParameters" -> {data},
			"Data" -> data
		|>]
	)


(***** Accessors *****)

HoldPattern[OpenAITextCompletionObject][data_]["Data"] := data
completion_OpenAITextCompletionObject[All] := AssociationMap[completion[#]&, completion["Properties"]]

completion_OpenAITextCompletionObject["Completion"] := completion["Data"]["Completion"]
completion_OpenAITextCompletionObject["Prompt"] := completion["Data"]["Prompt"]
completion_OpenAITextCompletionObject["Suffix"] := completion["Data"]["Suffix"]
completion_OpenAITextCompletionObject["Model"] := completion["Data"]["Model"]
completion_OpenAITextCompletionObject["FinishReason"] := completion["Data"]["FinishReason"]
completion_OpenAITextCompletionObject["ResponseUsage"] := completion["Data"]["ResponseUsage"]
completion_OpenAITextCompletionObject["LogProbabilities"] := completion["Data"]["LogProbabilities"]

completion_OpenAITextCompletionObject["CompletedPrompt"] :=
	completion["Prompt"] <> completion["Completion"] <> Replace[completion["Suffix"], Automatic -> ""]

completion_OpenAITextCompletionObject["Probabilities"] := Exp@completion["LogProbabilities"]


completion_OpenAITextCompletionObject["Properties"] :=
	Sort@{
		"CompletedPrompt",
		"Completion",
		"Prompt",
		"Suffix",
		"Model",
		"FinishReason",
		"ResponseUsage",
		"LogProbabilities",
		"Probabilities"
	}

completion_OpenAITextCompletionObject[prop_] :=
	(
		Message[OpenAITextCompletionObject::invProp, prop];
		Failure["InvalidProperty", <|
			"MessageTemplate" :> OpenAITextCompletionObject::invProp,
			"MessageParameters" -> {prop},
			"Property" -> prop,
			"Completion" -> completion
		|>]
	)


(***** Summary Box *****)

OpenAITextCompletionObject /: MakeBoxes[completion_OpenAITextCompletionObject, form:StandardForm]:=
	BoxForm`ArrangeSummaryBox[
		OpenAITextCompletionObject,
		completion,
		None,
		(*the next argument is the always visisble properties*)
		{
			BoxForm`SummaryItem@{"prompt: ", completion["Prompt"]},
			BoxForm`SummaryItem@{"completion: ", completion["Completion"]},
			If[completion["Suffix"] =!= Automatic,
				BoxForm`SummaryItem@{"suffix: ", completion["Suffix"]},
				Nothing
			],
			BoxForm`SummaryItem@{"finish reason: ", completion["FinishReason"]}
		},
		{
			BoxForm`SummaryItem@{"model: ", completion["Model"]},
			BoxForm`SummaryItem@{"response usage: ", completion["ResponseUsage"]}
		},
		form
	];



End[];
EndPackage[];
