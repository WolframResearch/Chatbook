BeginPackage["Wolfram`APIFunctions`ImageSynthesize`"]

CallImageAPI

Needs["GeneralUtilities`" -> "GU`"]
Needs["Wolfram`APIFunctions`"]
(* general interfaces DefineFunction, ... *)
Needs["Wolfram`APIFunctions`Common`"]
Needs["Wolfram`APIFunctions`APIs`Common`"]
Needs["Wolfram`APIFunctions`APIs`OpenAI`"]

Begin["`Private`"]

Options[ImageSynthesize] = {
	Authentication -> Automatic,
	ImageSize -> Small
} // System`Private`SortOptions;

$imageSynthesizeHiddenOptions = {
	Method -> Automatic,
	RandomSeeding -> Automatic
} // System`Private`SortOptions;

Clear[ImageSynthesize, iImageSynthesize]

DefineFunction[
	ImageSynthesize,
	iImageSynthesize,
	{1, 2},
	"ExtraOptions" -> $imageSynthesizeHiddenOptions
]

$imageSynthesizeMethods = {"OpenAI"};

iImageSynthesize[args_, opts_] := GU`Scope[

	(* default values *)
	prompt = Missing[];
	image = Missing[];
	mask = Missing[];
	number = Automatic;

	(* arguments checks *)
	(* TODO: simplify once we settle on a design *)
	Switch[args[[1]],
		_?StringQ,
			prompt = args[[1]];
		,
		_?Image`Image2DQ,
			image = args[[1]];
		,
		{_?StringQ, _?Image`Image2DQ},
			prompt = args[[1, 1]];
			image = args[[1, 2]];
		,
		{_?StringQ, _?Image`Image2DQ, _?Image`Image2DQ},
			prompt = args[[1, 1]];
			image = args[[1, 2]];
			mask = args[[1, 3]];
		,
		_?AssociationQ,
			prompt = Lookup[args[[1]], "Text", Lookup[args[[1]], "Prompt"]];
			image = Lookup[args[[1]], "Image"];
			mask = Lookup[args[[1]], "Mask"];
		,
		_,
			GU`ThrowFailure["bdspec", args[[1]]]
	];
	(* number of images to generate *)
	If[Length@args > 1,
		Switch[args[[2]],
			_?Internal`PositiveIntegerQ,
				number = args[[2]];
			,
			_,
				GU`ThrowFailure["bdspec", args[[2]]]
		]
	];

	(* pick the task according to the specified elements *)
	Switch[
		Not@*MissingQ /@ {prompt, image, mask},
		{True, True, _},
			task = "Inpaint",
		{True, False, False},
			task = "Generate",
		{False, True, False},
			task = "Variation",
		_,
			GU`ThrowFailure["bdspec", args[[1]]]
	];

	(* options checks *)

	params = <||>;

	method = GetOption[Method];
	If[Not@MemberQ[Append[$imageSynthesizeMethods, Automatic], method],
		GU`ThrowFailure["bdopt", Method, method, $imageSynthesizeMethods]
	];
	method = Replace[method,
		{
			Automatic  -> "OpenAI"
		}
	];

	params["ImageSize"] = conformImageSize[GetOption[ImageSize], method];

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
	res = DBEchoHold@imageSynthesizeAPI[
		method, task,
		DeleteMissing[<|
			params,
			"Text" -> prompt,
			"Image" -> image,
			"Mask" -> mask
		|>]
	];

	(* result formatting *)
	If[number === Automatic && !FailureQ[res],
		First[res]
		,
		$AllowFailure ^= True;
		res
	]

];

imageSynthesizeAPI[service_String, task_, params_] :=
GU`Scope[Enclose[Progress`EvaluateWithProgress[

	$imageAPIProgressText = "Connecting to the " <> service <> " external service\[Ellipsis]";
	paramsmod = params;
	(* Attempt to establish a connection *)
	authentication = Lookup[paramsmod, "Authentication", Automatic];
	so = Confirm@ConnectToService[service, authentication];

	(* Removed extra keys *)
	paramsmod //= KeyDrop["Authentication"];
	paramsmod //= DeleteCases[Automatic | _?MissingQ];

	(* validate params *)
	$imageAPIProgressText = "Valdating request parameters\[Ellipsis]";
	Confirm@ValidateAPIParams[service, task, paramsmod];

	(* call the API *)
	$imageAPIProgressText = "Getting data from " <> service <> "\[Ellipsis]";
	imgs = Confirm@CallImageAPI[so, task, paramsmod];

	(* the result must be a list of images *)
	Map[img |-> ConfirmBy[img, ImageQ], imgs];

	imgs

	,
	<|"Text" :> $imageAPIProgressText, "ElapsedTime" -> Automatic|>
]
	,
	APIFailure
]]

conformBatchSize[Automatic, _] := 1;
conformBatchSize[n_ /; 1 <= n <= 10, "OpenAI"] = n;
conformBatchSize[n_, "OpenAI"] := GU`ThrowFailure["invbatch", n, "1 < n < 10"];

conformImageSize[Automatic, "OpenAI"] := Automatic
conformImageSize[Small, "OpenAI"] := conformImageSize[256, "OpenAI"]
conformImageSize[Medium, "OpenAI"] := conformImageSize[512, "OpenAI"]
conformImageSize[Large, "OpenAI"] := conformImageSize[1024, "OpenAI"]
conformImageSize[n_Integer, "OpenAI"] := conformImageSize[{n, n}, "OpenAI"]
conformImageSize[{n_, n_}, "OpenAI"] :=
	StringRiffle[{#, #}, "x"]& @ ToString[n] /; MemberQ[{256, 512, 1024}, n]
conformImageSize[spec_, "OpenAI"] :=
	GU`ThrowFailure["bdopt", ImageSize, GetOption[ImageSize], {Small, Medium, Large}];

End[] (* End `Private` *)

EndPackage[]