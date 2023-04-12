BeginPackage["Wolfram`LLMTools`OpenAILink`Request`"];

OpenAIRequest
ConformUsage
ConformResponse

Begin["`Private`"];

Needs["Wolfram`LLMTools`OpenAILink`"]
Needs["Wolfram`LLMTools`OpenAILink`Constants`"]



(***********************************************************************************)
(********************************* OpenAIRequest ***********************************)
(***********************************************************************************)

(*
	OpenAIRequest[path, body, opts, head]
		makes a request to the OpenAI API at the specified path and with the specified body.

		path: a list of strings in the format expected by URLRead.

		body: an expression which is automatically converted to JSON. If the body is None, no body will be specified.

		opts: a list containing the options passed to the higher-level request function.

		head: the head of the higher-level request function for use in option resolution and messages.
*)

Options[OpenAIRequest] = {
	OpenAIKey  :> $OpenAIKey,
	OpenAIUser :> $OpenAIUser
};

OpenAIRequest[path_, body:_Association|None:None, opts_List:{}, head_:OpenAIRequest] :=
	Enclose[Module[{apiKey, user, bodyRule, resp, multipartQ = body =!= None && MemberQ[body, _Association]},

		apiKey = OptionValue[head, opts, OpenAIKey];
		user = OptionValue[head, opts, OpenAIUser];

		ConfirmBy[apiKey, StringQ,
			Message[head::invalidOpenAIAPIKey, apiKey];
			Failure["InvalidOpenAIKey", <|
				"MessageTemplate" :> head::invalidOpenAIAPIKey,
				"MessageParameters" -> {apiKey}
			|>]
		];

		bodyRule =
			If[body === None,
				Nothing,
				"Body" -> Confirm[
					If[	multipartQ,
						Identity,
						ExportByteArray[#, "JSON"] &
					] @ If[user =!= None, Append[body, "user" -> user], body],
					$Failed
				]
			];

		resp = URLRead[
			<|
				"Scheme" -> "https",
				"Domain" -> "api.openai.com",
				"Method" -> If[body === None, "GET", "POST"],
				"ContentType" -> If[multipartQ, "multipart/form-data", "application/json"],
				"Path" -> path,
				bodyRule,
				"Headers" -> {
					"Authorization" -> "Bearer " <> apiKey
				}
			|>
		];

		ConformResponse[head, resp]

	], "InheritedFailure"]


(*
	ConformResponse[head, resp]
		takes an HTTPResponse and returns the contained JSON data. Returns a Failure if the request failed.

		head is used for messages.
*)

ConformResponse[head_, resp_] :=
	Catch@Module[{statusCode, body},

		statusCode = resp["StatusCode"];
		body = ImportByteArray[resp["BodyByteArray"], "RawJSON"];

		If[FailureQ[body],
			Throw@responseFailureCode[head, resp, statusCode]
		];

		Which[

			KeyExistsQ[body,"error"],
				If[KeyExistsQ[body["error"],"message"],
					Throw@responseFailureMessage[head, resp, body["error"]["message"]],
					Throw@responseFailureCode[head, resp, statusCode]
				],

			statusCode =!= 200,
				Throw@responseFailureCode[head, resp, statusCode],

			True,
				body

		]
		
	]


responseFailureCode[head_, resp_, code_] :=
	(
		Message[head::openAIResponseFailureCode, code];
		Failure["OpenAIResponseFailure", <|
			"MessageTemplate" :> head::openAIResponseFailureCode,
			"MessageParameters" -> {code},
			"HTTPResponse" -> resp
		|>]
	)


responseFailureMessage[head_, resp_, message_] :=
	(
		Message[head::openAIResponseFailureMessage, message];
		Failure["OpenAIResponseFailure", <|
			"MessageTemplate" :> head::openAIResponseFailureMessage,
			"MessageParameters" -> {message},
			"HTTPResponse" -> resp
		|>]
	)



End[];
EndPackage[];
