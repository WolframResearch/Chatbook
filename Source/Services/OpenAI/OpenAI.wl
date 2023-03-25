BeginPackage["ConnorGray`Chatbook`Services`OpenAI`"]

Begin["`Private`"]

Needs["ConnorGray`Chatbook`ServiceUtils`"->"cbs`"];

$openaidata=<||>;

$openaidata["Domain"]="api.openai.com";

$openaidata["AuthKeyName"]="OPENAI_API_KEY"

$openaidata["ServiceName"]="OpenAI";

$openaidata["HTTPRequestFunction"]:=HTTPRequest[<|
		"Method" -> "POST",
		"Scheme" -> "HTTPS",
		"Domain" -> $openaidata["Domain"],
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
			"Authorization" -> "Bearer " <> cbs`ChatServiceData["OpenAI","AuthorizationKey"]
		}
	|>]&

ConnorGray`Chatbook`ServiceUtils`RegisterChatService[
	"OpenAI",
	$openaidata
	]

End[]

EndPackage[]
