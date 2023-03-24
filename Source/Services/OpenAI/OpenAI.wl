BeginPackage["ConnorGray`Chatbook`Services`OpenAI`"]

Begin["`Private`"]

$openaidata=<||>;

$openaidata["Domain"]="api.openai.com";

$openaidata["AuthKeyName"]="OPENAI_API_KEY"

$openaidata["AuthorizationKey"]:=SystemCredential[$openaidata["AuthKeyName"]];

$openaidata["HTTPRequestFunction"]=HTTPRequest[<|
		"Method" -> "POST",
		"Scheme" -> "HTTPS",
		"Domain" -> "api.openai.com",
		"Path" -> {"v1", "chat", "completions"},
		"Body" -> ExportByteArray[
			<|
				"model" -> "gpt-3.5-turbo",
				"max_tokens" -> ToExpression[#TokenLimit],
				"temperature" -> ToExpression[#Temperature],
				"messages" -> #Messages
			|>,
			"JSON"
		],
		"ContentType" -> "application/json",
		"Headers" -> {
			"Authorization" -> "Bearer " <> $openaidata["AuthorizationKey"]
		}
	|>]&

EchoEvaluation@ConnorGray`Chatbook`ServiceUtils`RegisterChatService["OpenAI",
	$openaidata
	]

End[]

EndPackage[]
