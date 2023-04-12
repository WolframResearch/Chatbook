BeginPackage["Wolfram`APIFunctions`TextSynthesize`"]

CallTextAPI

Needs["GeneralUtilities`" -> "GU`"]
Needs["Wolfram`APIFunctions`"]
(* general interfaces DefineFunction, ... *)
Needs["Wolfram`APIFunctions`Common`"]
Needs["Wolfram`APIFunctions`APIs`Common`"]
Needs["Wolfram`APIFunctions`APIs`OpenAI`"]

Begin["`Private`"]

Options[TextSynthesize] = {
	Authentication -> Automatic,
	MaxItems -> All
} // System`Private`SortOptions;

$textSynthesizeHiddenOptions = {
	Method -> Automatic,
	RandomSeeding -> Automatic
} // System`Private`SortOptions;

Clear[TextSynthesize, iTextSynthesize]

DefineFunction[
	TextSynthesize,
	iTextSynthesize,
	{1, 2},
	"ExtraOptions" -> $textSynthesizeHiddenOptions
]

$textSynthesizeMethods = {"OpenAI"};

iTextSynthesize[args_, opts_] := GU`Scope[

	(* default values *)
	prompt = Missing[];
	messages = Missing[];
	number = Automatic;

	(* arguments checks *)
	Switch[args[[1]],
		_?StringQ,
			prompt = args[[1]];
			messages = {
				<|"role" -> "user", "content" -> prompt|>
			};
		,
		_,
			GU`ThrowFailure["bdprompt", args[[1]]]
	];
	(* number of strings to generate *)
	If[Length@args > 1,
		Switch[args[[2]],
			_?Internal`PositiveIntegerQ,
				number = args[[2]];
			,
			_,
				GU`ThrowFailure["bdspec", args[[2]]]
		]
	];

	(* options checks *)

	{method, params} = Replace[
		GetOption[Method],
		{
			s: _String | Automatic :> {s, {}},
			{s: _String | Automatic} :> {s, {}},
			{s: _String | Automatic, o:OptionsPattern[]} :> {s, o},
			o:OptionsPattern[] :> {Automatic, o},
			_ :> GU`ThrowFailure["bdmethod", GetOption[Method]]
		}
	];
	params = KeyTake[Association[params], {
			"Temperature",
			"MaxItems",
			"TotalProbabilityCutoff",
			"Model"
		}];

	Switch[GetOption[MaxItems],
		_?Internal`PositiveIntegerQ,
			params["MaxItems"] = GetOption[MaxItems],
		All,
			Nothing,
		_,
			GU`ThrowFailure["bdmethod", GetOption[MaxItems]]
	];

	Switch[{method, Lookup[params, "Model"]},
		{"OpenAI"|Automatic, _?MissingQ},
			method = "OpenAI";
			task = "Chat";
			params["Model"] = $DefaultOpenAIModel["Chat"];
			params["Messages"] = messages;
		,
		{"OpenAI"|Automatic, Alternatives @@ $OpenAIModels["Chat"]},
			method = "OpenAI";
			task = "Chat";
			params["Messages"] = messages;
		,
		{"OpenAI"|Automatic, Alternatives @@ $OpenAIModels["Completion"]},
			method = "OpenAI";
			task = "Completion";
			params["Text"] = prompt;
		,
		_,
			GU`ThrowFailure["bdmethod", GetOption[Method]];
	];

	(* Not supported yet *)
	(* params["Seed"] = GetOption[RandomSeeding]; *)

	authentication = GetOption[Authentication];
	Switch[authentication,
		Automatic,
			params["Authentication"] = ConnectToService[method]
		,
		a_?AssociationQ /; ContainsOnly[Keys[a], {"ID", "APIKey"}],
			params["Authentication"] = authentication;
			If[KeyExistsQ[authentication, "ID"],
				params["ID"] = authentication["ID"]
			];
		,
		$ValidAuthenticationPattern | (so_ServiceObject /; so["Name"] === method),
			params["Authentication"] = authentication;
		,
		_,
			GU`ThrowFailure["bdauth", authentication]
	];

	params["N"] = conformBatchSize[number, method];

	(* API call *)
	res = DBEchoHold@textSynthesizeAPI[method, task, params];

	(* result formatting *)
	If[number === Automatic && !FailureQ[res],
		First[res]
		,
		$AllowFailure ^= True;
		res
	]

];

textSynthesizeAPI[service_String, task_, params_] :=
GU`Scope[Enclose[Progress`EvaluateWithProgress[

	$textAPIProgressText = "Connecting to the " <> service <> " external service\[Ellipsis]";
	paramsmod = params;
	(* Attempt to establish a connection *)
	authentication = Lookup[paramsmod, "Authentication", Automatic];
	so = Confirm@ConnectToService[service, authentication];

	(* Removed extra keys *)
	paramsmod //= KeyDrop["Authentication"];
	paramsmod //= DeleteCases[Automatic | _?MissingQ];

	(* validate params *)
	$textAPIProgressText = "Valdating request parameters\[Ellipsis]";
	Confirm@ValidateAPIParams[service, task, paramsmod];

	(* call the API *)
	$textAPIProgressText = "Getting data from " <> service <> "\[Ellipsis]";
	text = Confirm@CallTextAPI[so, task, paramsmod];

	(* the result must be a list of strings *)
	Map[s |-> ConfirmBy[s, StringQ], text];

	StringTrim /@ text

	,
	<|"Text" :> $textAPIProgressText, "ElapsedTime" -> Automatic|>
]
	,
	APIFailure
]]

conformBatchSize[Automatic, _] := 1;
conformBatchSize[n_ /; 1 <= n <= 10, "OpenAI"] = n;
conformBatchSize[n_, "OpenAI"] := GU`ThrowFailure["invbatch", n, "1 < n < 10"];

conformLimit[Automatic, _] := Automatic;
conformLimit[n_ /; Internal`PositiveIntegerQ[n] && n < 2048, "OpenAI"] = n;
conformLimit[n_, "OpenAI"] := GU`ThrowFailure["invlim", n];

conformBatchSize[Automatic, _] := Automatic;
conformBatchSize[n_?Internal`PositiveIntegerQ, "OpenAI"] = n;
conformBatchSize[n_, "OpenAI"] := GU`ThrowFailure["invbatch", n];

End[] (* End `Private` *)

EndPackage[]