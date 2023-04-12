BeginPackage["Wolfram`OpenAILink`Embedding`"];

Begin["`Private`"];

Needs["Wolfram`OpenAILink`"]
Needs["Wolfram`OpenAILink`Constants`"]
Needs["Wolfram`OpenAILink`Request`"]



(***********************************************************************************)
(********************************* OpenAIEmbedding *********************************)
(***********************************************************************************)

(*
	OpenAIEmbedding[str]
		gets a vector embedding of the text str.
*)

Options[OpenAIEmbedding] = {
	OpenAIKey   :> $OpenAIKey,
	OpenAIUser  :> $OpenAIUser,
	OpenAIModel -> "text-embedding-ada-002"
};

OpenAIEmbedding[str_String, propSpec_, opts:OptionsPattern[]] :=
	conformEmbedding[
		OpenAIRequest[
			{"v1", "embeddings"},
			Select[
				<|
					"input" -> str,
					"model" -> OptionValue[OpenAIModel]
				|>,
				# =!= Automatic&
			],
			{opts},
			OpenAIEmbedding
		],
		propSpec
	]

OpenAIEmbedding[str_String, opts:OptionsPattern[]] :=
	OpenAIEmbedding[str, "Embedding", opts]


conformEmbedding[data_, propSpec_] :=
	Enclose[getResponseDataProperty[Confirm@responseData[data], propSpec], "InheritedFailure"]

conformEmbedding[fail_?FailureQ, propSpec_] :=
	fail


responseData[
	KeyValuePattern[{
			"object" -> "list",
			"data" -> {
					KeyValuePattern[{
						"object" -> "embedding",
						"embedding" -> embedding: {___?NumberQ}
					}]
				},
			"usage" -> usage_
		}]
	] :=
	<|
		"Embedding" -> embedding,
		"ResponseUsage" -> usage
	|>

responseData[data_] :=
	invalidEmbeddingResponse[data]


getResponseDataProperty[respData_, "Embedding"] :=
	respData["Embedding"]

getResponseDataProperty[respData_, "ResponseUsage"] :=
	conformUsage[respData["ResponseUsage"]]

getResponseDataProperty[respData_, props_List] :=
	getResponseDataProperty[respData, #] &/@ props

getResponseDataProperty[respData_, propSpec_] :=
	(
		Message[OpenAIEmbedding::invProp, propSpec];
		Failure["InvalidProperty", <|
			"MessageTemplate" :> OpenAIEmbedding::invProp,
			"MessageParameters" -> {propSpec},
			"Property" -> propSpec,
			"ResponseData" -> respData
		|>]
	)


invalidEmbeddingResponse[data_] :=
	(
		Message[OpenAIEmbedding::invOpenAIEmbeddingResponse, data];
		Failure["InvalidOpenAIEmbeddingResponse", <|
			"MessageTemplate" :> OpenAIEmbedding::invOpenAIEmbeddingResponse,
			"MessageParameters" -> {data},
			"Response" -> data
		|>]
	)


conformUsage[KeyValuePattern[{
		"prompt_tokens" -> pTokens_Integer,
		"total_tokens" -> tTokens_Integer
	}]] :=
	<|
		"PromptTokens" -> pTokens,
		"TotalTokens" -> tTokens
	|>

conformUsage[usage_] :=
	Failure["InvalidUsageResponse", <|
		"MessageTemplate" :> OpenAIEmbedding::invUsageResponse,
		"MessageParameters" -> usage
	|>]


End[];
EndPackage[];
