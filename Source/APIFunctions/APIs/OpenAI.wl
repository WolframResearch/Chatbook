BeginPackage["Wolfram`APIFunctions`APIs`OpenAI`"]

$OpenAIModels
$DefaultOpenAIModel
$OpenAIMaxImageSize

(* no op in >13.2 - in layout *)
Quiet @ PacletManager`PacletInstall[
	FileNameJoin[{
		PacletManager`PacletResource["Wolfram/LLMTools", "APIFunctions"],
		"ServiceConnection_OpenAI-13.3.6.paclet"
	}]
];

(* connection handling interfaces ConformAuthentication, ... *)
Needs["GeneralUtilities`" -> "GU`"]
Needs["Wolfram`APIFunctions`Common`"]
Needs["Wolfram`APIFunctions`APIs`Common`"]
(* CallxxxAPI interfaces *)
Needs["Wolfram`APIFunctions`ImageSynthesize`"]
Needs["Wolfram`APIFunctions`TextSynthesize`"]
Needs["Wolfram`APIFunctions`Chat`"]

Begin["`Private`"]
(* API parameters *)

$APIParameters["OpenAI", "Generate"] = {
	{
		"Text" -> openAIprompt
	},
	{
		"ImageSize" -> openAIsize,
		"N" -> openAIbatch,
		"ID" -> openAIstring
	}
}
$APIParameters["OpenAI", "Inpaint"] = {
	{
		"Text" -> openAIprompt,
		"Image" -> openAIimage
	},
	{
		"Mask" -> openAIimage,
		"ImageSize" -> openAIsize,
		"N" -> openAIbatch,
		"ID" -> openAIstring
	}
}
$APIParameters["OpenAI", "Variation"] = {
	{"Image" -> openAIimage},
	{
		"ImageSize" -> openAIsize,
		"N" -> openAIbatch,
		"ID" -> openAIstring
	}
}


$APIParameters["OpenAI", "Completion"] = {
	{
		"Model" -> openAIcompletionmodel
	},
	{
		"Text" -> openAIprompt,
		"N" -> openAIbatch,
		"MaxItems" -> openAItokens,
		"Temperature" -> openAInumber,
		"TotalProbabilityCutoff" -> openAInumber,
		"ID" -> openAIstring
	}
}
$APIParameters["OpenAI", "Chat"] = {
	{
		"Model" -> openAIchatmodel,
		"Messages" -> openAIchat
	},
	{
		"N" -> openAIbatch,
		"MaxItems" -> openAItokens,
		"Temperature" -> openAInumber,
		"TotalProbabilityCutoff" -> openAInumber,
		"ID" -> openAIstring
	}
}


(* TODO: see how we can get this from the server *)
$OpenAIModels = Association[
	"Chat"-> {
		"gpt-4", 
		"gpt-4-0314", 
		"gpt-4-32k", 
		"gpt-4-32k-0314", 
		"gpt-3.5-turbo", 
		"gpt-3.5-turbo-0301"
	},
	"Completion" -> {
		"text-davinci-003",
		"text-davinci-002",
		"text-curie-001",
		"text-babbage-001",
		"text-ada-001",
		"davinci",
		"curie",
		"babbage",
		"ada"
	}
];

$DefaultOpenAIModel = Association[
	"Chat"-> "gpt-3.5-turbo",
	"Completion" -> "text-davinci-003"
];

openAIprompt = Function[StringQ[#] && 0 < StringLength[#] <= 1000]
openAIsize = Function[StringQ[#] && StringMatchQ[#, (n : "256" | "512" | "1024") ~~ "x" ~~ n_]]
openAIbatch = Function[Internal`PositiveIntegerQ[#] && 1 <= # <= 10]
openAIimage = Function[Image`Image2DQ[#] && Equal@@ImageDimensions[#]]
openAItokens = Function[Internal`PositiveIntegerQ[#] && # < 4096]
openAIstring = Function[StringQ[#]]
openAInumber = Function[Internal`RealValuedNumericQ[#]]
openAIchat = Function[VectorQ[#, AssociationQ] && 
	MatchQ[#, {KeyValuePattern[{"role" -> "system"|"user"|"assistant", "content" -> _String?StringQ}]..}]]
openAIchatmodel = With[{models = Alternatives @@ $OpenAIModels["Chat"]},
	Function[MatchQ[#, models]]
]
openAIcompletionmodel = With[{models = Alternatives @@ $OpenAIModels["Completion"]},
	Function[MatchQ[#, models]]
]


(* API calls *)
ConformAuthentication["OpenAI", sym:(Environment | SystemCredential)] :=
	Enclose[{"apikey" -> Confirm @ sym["OPENAI_API_KEY"]}];
ConformAuthentication["OpenAI", auth_] /; MatchQ[auth, KeyValuePattern[{"APIKey" -> _String}]] := 
	{"apikey" -> auth["APIKey"]};
ConformAuthentication["OpenAI", auth_] /; MatchQ[auth, {"apikey" -> _String}] := 
	auth;
ConformAuthentication[so:ServiceObject["OpenAI", _]] := GU`Scope @ Enclose[
	token = Confirm @ ServiceConnections`Private`serviceAuthentication[so["ID"]];
	key = Query[2, "apikey"] @ token;
	If[!StringQ @ key,
		Failure["APIError", <|"Message" -> "Missing Authentication informations."|>],
		{"apikey" -> key}
	]
];
ConformAuthentication["OpenAI", auth_] :=
	Failure["APIError",
		<|
			"MessageTemplate" -> "Unsupported authentication parameters `auth`.",
			"MessageParameters" -> <|"auth" -> auth|>
		|>
	];

TestConnection["OpenAI", so:ServiceObject["OpenAI", _]] :=
	TestConnection["OpenAI", ConformAuthentication[so]];
TestConnection["OpenAI", {"apikey" -> key_String}] := TestConnection[
	HTTPRequest[
		"https://api.openai.com/v1/models", 
		<|
			"Headers" -> {"Authorization" -> "Bearer " <> key},
			Method -> "GET"
		|>
	]
]

(* Image *)

CallImageAPI[so_, "Generate", params_] :=
GU`Scope[Enclose[
	rawparams = renameParams[params];
	Confirm@callImageAPI[so, "RawImageCreate", rawparams]
]]

CallImageAPI[so_, "Variation", params_] :=
GU`Scope[Enclose[WithCleanup[
	rawparams = renameParams[params];
	rawparams["image"] = Confirm@exportImage[rawparams["image"]];
	Confirm@callImageAPI[so, "RawImageVariation", rawparams]
	,
	Quiet@DeleteFile[rawparams["image"]]
]]]

CallImageAPI[so_, "Inpaint", params_] :=
GU`Scope[Enclose[WithCleanup[
	rawparams = renameParams[params];
	If[KeyExistsQ[rawparams, "mask"],
		(* Optimize call by sending only one image *)
		(* TODO: check that the result is equivalent *)
		rawparams["image"] = SetAlphaChannel[rawparams["image"], ColorNegate[rawparams["mask"]]];
		KeyDropFrom[rawparams, "mask"];
	];
	rawparams["image"] = Confirm@exportImage[rawparams["image"]];
	callImageAPI[so, "RawImageEdit", rawparams]
	,
	Quiet@DeleteFile[rawparams["image"]]
]]]

callImageAPI[so_ServiceObject, name_, params_] := GU`Scope[Enclose[
	If[TrueQ[$MockAPICalls],
		res = DBEchoHold@fakeRequest[name, params]
		,
		res = ConfirmQuiet[DBEchoHold@ServiceExecute[so, name, params]];
	];
	urls = Query["data", All, "url"][res];
	ConfirmAssert[VectorQ[#, StringQ]]& @ urls;
	Map[url |-> ConfirmBy[Import[url], ImageQ], urls]
]]


(* Text *)

CallTextAPI[so_, "Completion", params_] :=
GU`Scope[Enclose[
	rawparams = renameParams[params];
	Confirm@callTextAPI[so, "RawCompletion", rawparams]
]]

CallTextAPI[so_, "Chat", params_] :=
GU`Scope[Enclose[
	rawparams = renameParams[params];
	Confirm@callTextAPI[so, "RawChat", rawparams]
]]

callTextAPI[so_ServiceObject, name:"RawCompletion", params_] := GU`Scope[Enclose[
	If[TrueQ[$MockAPICalls],
		res = DBEchoHold@fakeRequest[name, params]
		,
		res = ConfirmQuiet[DBEchoHold@ServiceExecute[so, name, params]];
	];
	res = Query["choices", All, "text"][res];
	ConfirmAssert[VectorQ[#, StringQ]]& @ res;
	res
]]

callTextAPI[so_ServiceObject, name:"RawChat", params_] := GU`Scope[Enclose[
	If[TrueQ[$MockAPICalls],
		res = DBEchoHold@fakeRequest[name, params]
		,
		res = ConfirmQuiet[DBEchoHold@ServiceExecute[so, name, params]];
	];
	res = Query["choices", All, "message", "content"][res];
	ConfirmAssert[VectorQ[#, StringQ]]& @ res;
	res
]]

(* Chat *)

CallChatAPI[so_, "Chat", params_] :=
GU`Scope[Enclose[
	rawparams = renameParams[params];

	rawparams["messages"] //= Map[KeyMap[ToLowerCase]];
	rawparams["messages"] //= Map[KeyTake[{"role", "content"}]];
	rawparams["messages"] //= MapAt[ToLowerCase, {All, "role"}];

	rawparams["model"] = "gpt-3.5-turbo";

	rawparams //= KeyTake[{"messages", "model"}];

	res = Confirm@callChatAPI[so, "RawChat", rawparams];

	message = Query["choices", 1, "message"][res];
	message //= MapAt[Capitalize, "role"];
	message //= KeyMap[Capitalize];
	message["Timestamp"] = FromUnixTime[res["created"]];
	messages = Append[params["Messages"], message];

	usage = Query["usage", "total_tokens"][res];

	Association[
		"RawResult" -> res,
		"Messages" -> messages,
		"Usage" -> usage
	]
]]

callChatAPI[so_ServiceObject, name:"RawChat", params_] := GU`Scope[Enclose[
	(* If[TrueQ[$MockAPICalls],
		res = DBEchoHold@fakeRequest[name, params]
		, *)
		res = ConfirmQuiet[DBEchoHold@ServiceExecute[so, name, params]];
	(* ]; *)
	ConfirmAssert[AssociationQ[#]]& @ res;
	res
]]


(* Helpers *)

renameParams[params_] := 
	KeyMap[
		Replace[{
			"Prompt" -> "prompt",
			"Messages" -> "messages",
			"Model" -> "model",
			"Temperature" -> "temperature",
			"TotalProbabilityCutoff" -> "top_p",
			"MaxItems" -> "max_tokens",
			"Text" -> "prompt",
			"Image" -> "image",
			"Mask" -> "mask",
			"ImageSize" -> "size",
			"ID" -> "user",
			"N" -> "n"
		}],
		params
	];

$OpenAIMaxImageSize = Quantity[4, "Megabytes"];

exportImage[img_] := GU`Scope[Enclose[
	ConfirmAssert[Image`Image2DQ[img]];
	uri = Export[CreateFile[], SetAlphaChannel[img, AlphaChannel[img]], "PNG"];
	ConfirmMatch[uri, _?StringQ];
	imagesize = UnitConvert[FileSize[uri], "Megabytes"];
	ConfirmAssert[imagesize < $OpenAIMaxImageSize];
	File[uri]
]]


fakeRequest["RawImageCreate"|"RawImageEdit"|"RawImageVariation", params_] := GU`Scope[
	n = Lookup[params, "n", 1];
	size = Lookup[params, "size", "256x256"];
	size = Interpreter["Number"]@StringSplit[size, "x"];
	files = Table[Export[CreateFile[], RandomImage[1, size, ColorSpace->"RGB"], "PNG"], n];
	Association["data" -> 
		Map[file |-> <|"url" -> file|>, files]
	]
]

fakeRequest["RawCompletion", params_] := GU`Scope[
	n = Lookup[params, "n", 1];
	Association["choices" -> 
		Table[<|"text" -> "this is a fake call result"|>, n]
	]
]

fakeRequest["RawChat", params_] := GU`Scope[
	n = Lookup[params, "n", 1];
	Association["choices" -> 
		Table[
			<|"message" -> 
				<|"role" -> "assistant", "content" -> "this is a fake call result"|>
			|>,
			n
		]
	]
]

End[] (* End `Private` *)

EndPackage[]