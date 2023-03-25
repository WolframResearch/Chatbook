BeginPackage["ConnorGray`Chatbook`Services`OpenAI`"]

Begin["`Private`"]

Needs["ConnorGray`Chatbook`ServiceUtils`"->"cbs`"];

$openaidata=<||>;

$openaidata["Domain"]="api.openai.com";

(*
	This value is currently the same as that used by functions in
	ChristopherWolfram/OpenAILink
*)
$openaidata["AuthKeyName"]="OPENAI_API_KEY"

$openaidata["ServiceName"]="OpenAI";

$openaidata["AuthenticationDialogContentFunction"]=(Cell[
			TextData[Flatten[{
				If[#1,
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
		]&)

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
