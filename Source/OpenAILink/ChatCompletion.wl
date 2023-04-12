BeginPackage["Wolfram`OpenAILink`ChatCompletion`"];

Begin["`Private`"];

Needs["Wolfram`OpenAILink`"]
Needs["Wolfram`OpenAILink`Constants`"]
Needs["Wolfram`OpenAILink`Request`"]



(***********************************************************************************)
(******************************* OpenAIChatComplete ********************************)
(***********************************************************************************)

(*
	OpenAIChatComplete[message]
		completes a chat starting with a message.

	OpenAIChatComplete[messages]
		completes a chat starting with a list of messages.

	OpenAIChatComplete[promptSpec, propSpec]
		returns the property or list of properties specified by propSpec.

	OpenAIChatComplete[promptSpec, All]
		returns a OpenAIChatCompletionObject containing all results of the completion.

	OpenAIChatComplete[promptSpec, propSpec, n]
		generates n completions.
*)

Options[OpenAIChatComplete] = {
	OpenAIKey            :> $OpenAIKey,
	OpenAIUser           :> $OpenAIUser,
	OpenAIModel          -> Automatic,
	OpenAITemperature    -> Automatic,
	OpenAITopProbability -> Automatic,
	OpenAITokenLimit     -> Automatic,
	OpenAIStopTokens     -> Automatic
};

OpenAIChatComplete[args___] :=
	Enclose[
		iOpenAIChatComplete@Confirm@ArgumentsOptions[OpenAIChatComplete[args], {1,3}],
		"InheritedFailiure"
	]


iOpenAIChatComplete[{{promptMsgs:{__OpenAIChatMessageObject}, propSpec_, n_}, opts_}] :=
	Module[{rawResponse},
		rawResponse =
			OpenAIRequest[
				{"v1", "chat", "completions"},
				Select[
					<|
						"model" -> Replace[OptionValue[OpenAIChatComplete,opts,OpenAIModel], Automatic -> "gpt-3.5-turbo"],
						"messages" -> chatMessageJSON/@promptMsgs,
						"n" -> n,
						"temperature" -> OptionValue[OpenAIChatComplete,opts,OpenAITemperature],
						"top_p" -> OptionValue[OpenAIChatComplete,opts,OpenAITopProbability],
						"max_tokens" -> OptionValue[OpenAIChatComplete,opts,OpenAITokenLimit],
						"stop" -> OptionValue[OpenAIChatComplete,opts,OpenAIStopTokens]
					|>,
					# =!= Automatic&
				],
				{opts},
				OpenAIChatComplete
			];
		conformChat[rawResponse, propSpec, promptMsgs]
	]

iOpenAIChatComplete[{{promptMsg_OpenAIChatMessageObject, propSpec_, n_}, opts_}] :=
	iOpenAIChatComplete[{{{promptMsg}, propSpec, n}, opts}]


iOpenAIChatComplete[{{promptSpec_, propSpec_, n_}, opts_}] :=
	(
		Message[OpenAIChatComplete::invPromptSpec, promptSpec];
		Failure["InvalidPromptSpecification", <|
			"MessageTemplate" :> OpenAIChatComplete::invPromptSpec,
			"MessageParameters" -> {promptSpec},
			"PromptSpecification" -> promptSpec
		|>]
)


iOpenAIChatComplete[{{promptSpec_, propSpec_}, opts_}] :=
	Replace[iOpenAIChatComplete[{{promptSpec, propSpec, 1}, opts}], {res_} :> res]

iOpenAIChatComplete[{{promptSpec_}, opts_}] :=
	iOpenAIChatComplete[{{promptSpec, "Completion"}, opts}]


conformChat[KeyValuePattern[{
		"model" -> model_,
		"usage" -> rawUsage_,
		"choices" -> choices_List
	}], propSpec_, promptMsgs_] :=
	With[{usage = conformUsage[rawUsage]},
		getChoiceProperty[conformChatChoice[#, promptMsgs, model, usage], propSpec] &/@ choices
	]

conformChat[fail_?FailureQ, propSpec_, promptMsgs_] :=
	fail

conformChat[data_, propSpec_, promptMsgs_] :=
	completionResponseError[data]


getChoiceProperty[choice_OpenAIChatCompletionObject, All] :=
	choice

getChoiceProperty[choice_OpenAIChatCompletionObject, props_List] :=
	choice/@props

getChoiceProperty[choice_OpenAIChatCompletionObject, prop_] :=
	choice[prop]

getChoiceProperty[choice_, propSpec_] :=
	choice


conformChatChoice[choice: KeyValuePattern[{
		"message" -> KeyValuePattern[{
				"role" -> role_String,
				"content" -> content_String
			}],
		"finish_reason" -> finishReason_
	}], promptMsgs_, model_, usage_] :=
	OpenAIChatCompletionObject[<|
		"CompletionMessage" -> OpenAIChatMessageObject[<|"Role" -> role, "Text" -> content|>],
		"PromptMessages" -> promptMsgs,
		"Model" -> model,
		"FinishReason" -> Replace[finishReason, {"length" -> "Length", "stop" -> "Stop"}],
		"ResponseUsage" -> usage
	|>]

conformChatChoice[data_, promptMsgs_, model_, usage_] :=
	completionResponseError[data]



(* Utilities *)

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
		"MessageTemplate" :> OpenAIChatComplete::invUsageResponse,
		"MessageParameters" -> {usage}
	|>]


completionResponseError[data_] :=
	(
		Message[OpenAIChatComplete::invOpenAIChatCompleteResponse, data];
		Failure["InvalidOpenAIChatCompleteResponse", <|
			"MessageTemplate" :> OpenAIChatComplete::invOpenAIChatCompleteResponse,
			"MessageParameters" -> {data},
			"Response" -> data
		|>]
	)



(***********************************************************************************)
(**************************** OpenAIChatCompletionObject ****************************)
(***********************************************************************************)


(***** Verifier *****)

HoldPattern[OpenAIChatCompletionObject][data:Except[KeyValuePattern[{
		"CompletionMessage" -> _OpenAIChatMessageObject,
		"PromptMessages" -> {___OpenAIChatMessageObject},
		"Model" -> _,
		"FinishReason" -> _,
		"ResponseUsage" -> _
	}]]] :=
	(
		Message[OpenAIChatCompletionObject::invOpenAIChatCompletionObject, data];
		Failure["InvalidOpenAIChatCompletionObject", <|
			"MessageTemplate" :> OpenAIChatCompletionObject::invOpenAIChatCompletionObject,
			"MessageParameters" -> {data},
			"Data" -> data
		|>]
	)


(***** Accessors *****)

HoldPattern[OpenAIChatCompletionObject][data_]["Data"] := data
chat_OpenAIChatCompletionObject[All] := AssociationMap[chat[#]&, chat["Properties"]]

chat_OpenAIChatCompletionObject["CompletionMessage"] := chat["Data"]["CompletionMessage"]
chat_OpenAIChatCompletionObject["PromptMessages"] := chat["Data"]["PromptMessages"]
chat_OpenAIChatCompletionObject["Model"] := chat["Data"]["Model"]
chat_OpenAIChatCompletionObject["FinishReason"] := chat["Data"]["FinishReason"]
chat_OpenAIChatCompletionObject["ResponseUsage"] := chat["Data"]["ResponseUsage"]

chat_OpenAIChatCompletionObject["Completion"] := chat["CompletionMessage"]
chat_OpenAIChatCompletionObject["Messages"] := Append[chat["PromptMessages"], chat["CompletionMessage"]]

chat_OpenAIChatCompletionObject["Properties"] :=
	Sort@{
		"CompletionMessage",
		"PromptMessages",
		"Messages",
		"Model",
		"FinishReason",
		"ResponseUsage"
	}

chat_OpenAIChatCompletionObject[prop_] :=
	(
		Message[OpenAIChatCompletionObject::invProp, prop];
		Failure["InvalidProperty", <|
			"MessageTemplate" :> OpenAIChatCompletionObject::invProp,
			"MessageParameters" -> {prop},
			"Property" -> prop,
			"Completion" -> chat
		|>]
	)


(***** Summary Box *****)

OpenAIChatCompletionObject /: MakeBoxes[chat_OpenAIChatCompletionObject, form:StandardForm]:=
	BoxForm`ArrangeSummaryBox[
		OpenAIChatCompletionObject,
		chat,
		None,
		(*the next argument is the always visisble properties*)
		{
			BoxForm`SummaryItem@{"prompt: ", chat["PromptMessages"]},
			BoxForm`SummaryItem@{"completion: ", chat["CompletionMessage"]}
		},
		{
			BoxForm`SummaryItem@{"model: ", chat["Model"]},
			BoxForm`SummaryItem@{"finish reason: ", chat["FinishReason"]},
			BoxForm`SummaryItem@{"response usage: ", chat["ResponseUsage"]}
		},
		form
	];



(***********************************************************************************)
(***************************** OpenAIChatMessageObject *****************************)
(***********************************************************************************)


(***** Verifier *****)

HoldPattern[OpenAIChatMessageObject][role_String, text_String] :=
	OpenAIChatMessageObject[<|"Role" -> role, "Text" -> text|>]

HoldPattern[OpenAIChatMessageObject][data:Except[KeyValuePattern[{
		"Role" -> _String,
		"Text" -> _String
	}]]] :=
	(
		Message[OpenAIChatMessageObject::invOpenAIChatMessageObject, data];
		Failure["InvalidOpenAIChatMessageObject", <|
			"MessageTemplate" :> OpenAIChatMessageObject::invOpenAIChatMessageObject,
			"MessageParameters" -> {data},
			"Data" -> data
		|>]
	)


(***** Accessors *****)

HoldPattern[OpenAIChatMessageObject][data_]["Data"] := data
msg_OpenAIChatMessageObject[All] := AssociationMap[msg[#]&, msg["Properties"]]

msg_OpenAIChatMessageObject["Role"] := msg["Data"]["Role"]
msg_OpenAIChatMessageObject["Text"] := msg["Data"]["Text"]

msg_OpenAIChatMessageObject["Properties"] :=
	Sort@{
		"Role",
		"Text"
	}

msg_OpenAIChatMessageObject[prop_] :=
	(
		Message[OpenAIChatMessageObject::invProp, prop];
		Failure["InvalidProperty", <|
			"MessageTemplate" :> OpenAIChatMessageObject::invProp,
			"MessageParameters" -> {prop},
			"Property" -> prop,
			"Completion" -> msg
		|>]
	)


chatMessageJSON[msg_OpenAIChatMessageObject] :=
	<|"role" -> msg["Role"], "content" -> msg["Text"]|>


(***** Summary Box *****)

OpenAIChatMessageObject /: MakeBoxes[msg_OpenAIChatMessageObject, form:StandardForm]:=
	BoxForm`ArrangeSummaryBox[
		OpenAIChatMessageObject,
		msg,
		None,
		(*the next argument is the always visisble properties*)
		{
			BoxForm`SummaryItem@{"role: ", msg["Role"]},
			BoxForm`SummaryItem@{"text: ", msg["Text"]}
		},
		{},
		form
	];



End[];
EndPackage[];
