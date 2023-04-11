BeginPackage["Wolfram`APIFunctions`Chat`"]
Needs["Wolfram`APIFunctions`"]

Needs["GeneralUtilities`" -> "GU`"]

(* general interfaces DefineFunction, ... *)
Needs["Wolfram`APIFunctions`Common`"]
Needs["Wolfram`APIFunctions`APIs`Common`"]
Needs["Wolfram`APIFunctions`APIs`OpenAI`"]

$DefaultChatPrompt
$ChatConnexionCache
CallChatAPI

Begin["`Private`"]


ClearAll["CreateChat"]
Options[CreateChat] = {
	Authentication -> Automatic
} // System`Private`SortOptions;

$createChatHiddenOptions = {
	Method -> Automatic,
	RandomSeeding -> Automatic,
	ImageSize -> Automatic
} // System`Private`SortOptions;

Clear[CreateChat, iCreateChat]

DefineFunction[
	CreateChat,
	iCreateChat,
	{0, 1},
	"ExtraOptions" -> $createChatHiddenOptions
]

createChatMethods = {"OpenAI"};

$DefaultChatPrompt = "You are a helpful assistant.";

iCreateChat[args_, opts_] := GU`Scope @ Enclose[

	(* default values *)
	$AllowFailure ^= True;
	
	(* arguments checks *)
	messages = Switch[Length@args,
		0,
			{},
		1,
			Switch[args[[1]],
				_String?StringQ,
					{<|"Role" -> "System", "Content" -> args[[1]], "Timestamp" -> Now|>},
				{KeyValuePattern[{"Role" -> _String, "Content" -> _String, "Timestamp" -> _DateObject}]..},
					KeyTake[args[[1]], {"Role", "Content", "Timestamp"}],
				_,
					GU`ThrowFailure["bdprompt", args[[1]]]
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
	If[Not@MemberQ[Append[createChatMethods, Automatic], method],
		GU`ThrowFailure["bdopt", Method, method, createChatMethods]
	];

	(* cooked API params *)
	params = KeyTake[Association[params], {"Model"}];

	Switch[method,
		"OpenAI" | Automatic,
			params["Method"] = "OpenAI";
			params["Messages"] = messages;
			,
		_,
			GU`ThrowFailure["bdmethod", GetOption[Method]];
	];

	(* Not supported yet *)
	(* params["Seed"] = GetOption[RandomSeeding]; *)

	authentication = GetOption[Authentication];
	Switch[authentication,
		Automatic,
			params["Authentication"] = Automatic
			,
		a_?AssociationQ /; ContainsOnly[Keys[a], "APIKey"],
			params["Authentication"] = authentication;
			,
		_,
			GU`ThrowFailure["bdauth", authentication]
	];

	params["ChatID"] = CreateUUID[];
	params["History"] = {};
	params["Usage"] = 0;

	(* set $ChatConnexionCache entry *)
	Confirm @ getServiceObject[params["ChatID"], params["Method"], params["Authentication"]];
	params = KeyDrop[params, "Authentication"];

	(* result formatting *)
	ChatObject[params, FilterRules[opts, Options[Pane]]]
];


(* session pairing between chatobject <-> service object *)
$ChatConnexionCache = <||>;

getServiceObject[chatID_, name_, auth_] := GU`Scope[Enclose[
	Switch[auth,
		Inherited,
			so = Lookup[$ChatConnexionCache, chatID, Missing["NoCachedServiceObject"]];
			If[MissingQ[so], GU`ThrowFailure["deadcon"]];
			DBPrint["Chat/getServiceObject: ", StringForm["Using known inherited connexion ``.", Last @ so]];
			Confirm @ ConnectToService[name, so];
			,
		Automatic,
			DBPrint["Chat/getServiceObject: ", StringForm["Looking for any available connexion to ``.", name]];
			so = ConnectToService[name, "Available"];
			If[FailureQ[so],
				DBPrint["Chat/getServiceObject: ", StringForm["No available connexion to ``. Will use Wolfram.", name]];
				so = Confirm @ ConnectToService[name, "Wolfram"]
			];
			,
		_,
			DBPrint["Chat/getServiceObject: ", StringForm["Custom authentication provided ``.", auth]];
			so = Confirm @ ConnectToService[name, auth]
	];
	DBPrint["Service object will be saved:", so];
	$ChatConnexionCache[chatID] = so;
	so
]];

ChatObjectQ[o : ChatObject[params_Association, opts:OptionsPattern[]]] :=
	And[
		AssociationQ[Unevaluated[params]],
		ContainsAll[Keys[params], {"Messages", "ChatID", "History", "Usage"}],
		VectorQ[params["Messages"], AssociationQ],
		MatchQ[params["Messages"],
			{KeyValuePattern[{"Role" -> _String, "Content" -> _String, "Timestamp" -> _DateObject}]...}
		]
	]


ClearAll["ChatEvaluate"]
Options[ChatEvaluate] = {Authentication -> Inherited};

ChatEvaluate[s_String?StringQ][obj_ChatObject?ChatObjectQ] := 
	ChatEvaluate[obj, s]

ChatEvaluate[obj:ChatObject[params_, opts:OptionsPattern[]]?ChatObjectQ, OptionsPattern[]] := (* side effect ?? *)
GU`Scope @ Enclose[
	so = Confirm @ getServiceObject[params["ChatID"], params["Method"], OptionValue[Authentication]];
	obj
];

ChatEvaluate[obj:ChatObject[params_, opts:OptionsPattern[]]?ChatObjectQ, s_String?StringQ, newopts:OptionsPattern[]] :=
GU`Scope @ Enclose[
	paramsmod = params;
	so = Confirm @ getServiceObject[params["ChatID"], params["Method"], OptionValue[Authentication]];

	paramsmod["Messages"] //= Append[
		<|"Role" -> "User", "Content" -> s, "Timestamp" -> Now|>
	];

	Progress`EvaluateWithProgress[
		res = CallChatAPI[so, "Chat", paramsmod],
		<|
			"Text" -> StringForm["Waiting for `` answer\[Ellipsis]", so["Name"]],
			"ElapsedTime" -> Automatic
		|>
		,
		"Delay" -> 0
	];

	paramsmod["Messages"] = res["Messages"];
	paramsmod["History"] //= Append[res["RawResult"]];
	paramsmod["Usage"] += res["Usage"];

	ChatObject[paramsmod, opts]
]


ClearAll[ChatObject]

(obj:ChatObject[params_, opts:OptionsPattern[]])["Properties"] := 
	{"Messages", "Usage", "ChatID", "Properties"} // Sort
(obj:ChatObject[params_, opts:OptionsPattern[]])["Messages"] := 
	KeyMap[
		Capitalize,
		#
	]& /@ Query["Messages"][params]
(obj:ChatObject[params_, opts:OptionsPattern[]])["ChatID"] := 
	Query["ChatID"][params]
(obj:ChatObject[params_, opts:OptionsPattern[]])["Usage"] := 
	params["Usage"]
(obj:ChatObject[params_, opts:OptionsPattern[]])["FullUsage"] := 
	KeyMap[
		StringJoin@Capitalize@StringSplit[#,"_"]&,
		Total[Query["History", All, "usage"][params]]
	]
(obj:ChatObject[params_, opts:OptionsPattern[]])[prop_] := 
	Missing["InvalidProperty", prop]

(* Typesetting *)

ChatObject /: MakeBoxes[object : ChatObject[data_Association, opts:OptionsPattern[]]?ChatObjectQ, fmt_] := 
	With[
		{boxes = chatObjectPanelBoxes[object, fmt]},
		BoxForm`ArrangeSummaryBox[
			ChatObject,
			object,
			None,
			{{RawBoxes[boxes]}},
			{},
			fmt
		] /; !FailureQ[boxes]
	]


(* Panel *)

$blue = RGBColor[{240, 255, 251}/255];

$logoOpenAI := $logoOpenAI = Show[Import[FileNameJoin[
	{PacletManager`PacletResource["Wolfram`Chatbook", "APIFunctions"], "OpenAILogo.svg"}
], "Graphics"], ImageSize -> 20];

$logoSystem := $logoSystem = Import[FileNameJoin[
	{PacletManager`PacletResource["Wolfram`Chatbook", "APIFunctions"], "chat-system.wl"}
]];

$logoUser := $logoUser = Import[FileNameJoin[
	{PacletManager`PacletResource["Wolfram`Chatbook", "APIFunctions"], "chat-user.wl"}
]];

$logoWolfram = "\[WolframLanguageLogoCircle]";

$copyIcon[color_] = Graphics[
	GeometricTransformation[{
		color,
		Thickness[0.05],
		CapForm["Butt"],
		JoinForm["Bevel"],
		JoinedCurve[{
			{{0, 2, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3},{0, 1, 0}, {1, 3, 3}, {0, 1, 0}},
			{{0, 2, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0},
			{1, 3, 3}}},
			{{{9.`, 15.`}, {5.`, 15.`}, {3.895430088043213`, 15.`},
			{3.`, 14.104599952697754`}, {3.`, 13.`}, {3.`, 5.`}, {3.`, 3.895430088043213`},
			{3.895430088043213`, 3.`}, {5.`, 3.`}, {13.`, 3.`}, {14.104599952697754`, 3.`},
			{15.`, 3.895430088043213`}, {15.`, 5.`}, {15.`, 9.`}},
			{{11.`, 21.`}, {19.`, 21.`}, {20.10460090637207`, 21.`},
			{21.`, 20.10460090637207`}, {21.`, 19.`}, {21.`, 11.`},
			{21.`, 9.895429611206055`}, {20.10460090637207`, 9.`},
			{19.`, 9.`}, {11.`, 9.`}, {9.895429611206055`, 9.`}, {9.`, 9.895429611206055`},
			{9.`, 11.`}, {9.`, 19.`}, {9.`, 20.10460090637207`},
			{9.895429611206055`, 21.`}, {11.`, 21.`}}
			},
			CurveClosed -> {0, 1}]
		},
		{{{1, 0}, {0, -1}}, {0, 0}}],
		ImageSize -> 20
	];

$icons = {"Assistant" :> $logoOpenAI, "System" :> $logoSystem, "User" :> $logoUser};

copyButton = With[
	{opts = {FrameStyle -> Transparent, RoundingRadius -> 5, FrameMargins -> 5}},
	Function[
		expr, 
		myButton[
			CopyToClipboard[expr],
			{
				"Default" -> Framed[$copyIcon[GrayLevel[0.65]], opts, Background -> Transparent],
				"Hover" -> Framed[$copyIcon[GrayLevel[0.286]], opts, Background -> Transparent],
				"Pressed" -> Framed[$copyIcon[GrayLevel[0.286]], opts, Background -> GrayLevel[0.,0.05]]
			}
		],
		HoldFirst
	]
];

fixFrame = Framed[#,
	ImageMargins -> {{0, 0}, {0, 0}},
	FrameMargins -> None,
	FrameStyle -> None,
	Background -> None] &;

Clear[makeChatGrid]

makeChatGrid[{}] := Grid[
	{
		{Pane["", 180]}
	},
	Dividers -> {{Transparent, {None}, Transparent}, {Transparent, {GrayLevel[0,.05]}, Transparent}},
	Alignment -> {{Right, Left}, Automatic},
	Spacings -> {1, 1},
	Background -> {Automatic, {{White, $blue}}},
	BaseStyle -> "Text"
]

makeChatGrid[messages_] := DynamicModule[{over = 0, overhandler},
	overhandler[expr_, i_] := EventHandler[
		Button[expr, FrameMargins -> {{10, 10}, {5, 5}},
			Appearance -> "Suppressed", 
			Active -> False, BaselinePosition -> Baseline, BaseStyle -> {}, DefaultBaseStyle -> {},
			Alignment -> Left
		],
		"MouseEntered" :> FEPrivate`Set[over, i]
	];
	EventHandler[
		Grid[
			MapIndexed[{
				overhandler[fixFrame@Style[Replace[#Role, $icons], "InformationTitleText"],
					#2[[1]]],
				overhandler[fixFrame@Style[BoxForm`Undeploy@StringTrim[#Content], Editable -> False], #2[[1]]], 
				overhandler[fixFrame@PaneSelector[{#2[[1]] -> copyButton[#Content]}, Dynamic[over]], #2[[1]]]
			} &, messages],
			Dividers -> {{Transparent, {None}, Transparent}, {Transparent, {GrayLevel[0,.05]}, Transparent}},
			Alignment -> {{Right, Left}, Automatic},
			Spacings -> {0, 0},
			Background -> {Automatic, {{White, $blue}}},
			BaseStyle -> "Text"
		],
		"MouseExited" :> FEPrivate`Set[over, 0]
	]
]

ClearAll[chatObjectPanelBoxes]
SetAttributes[chatObjectPanelBoxes, HoldAllComplete]
chatObjectPanelBoxes[object : ChatObject[data_Association, opts:OptionsPattern[]]?ChatObjectQ, fmt_] := 
Module[
	{messages},
	messages = object["Messages"];
	ToBoxes[Deploy@Pane[makeChatGrid[messages],
						FilterRules[Flatten[{opts}], Options[Pane]],
						AppearanceElements -> None,
						Scrollbars -> {False, Automatic},
						ImageSize -> {{180, 600}, {20, 400}},
						ContentPadding -> False
					], fmt]
]

SetAttributes[myButton, HoldFirst]
myButton[action_, rules:{__Rule}|Association, opts: OptionsPattern[Button]] := 
Button[
	DynamicModule[
		{mouseDown = False, mouseHover = False},
		EventHandler[
			PaneSelector[{
				"Default" -> Lookup[rules, "Default"],
				"Hover" -> Lookup[rules, "Hover", Lookup[rules, "Default"]],
				"Pressed" -> Lookup[rules, "Pressed", Lookup[rules, "Default"]]
				},
				Dynamic[
					FEPrivate`Which[
						mouseDown, "Pressed",
						mouseHover, "Hover",
						True, "Default"
					]
				]
			],
			{
				"MouseDown" :> FEPrivate`Set[mouseDown, True],
				"MouseUp" :> FEPrivate`Set[mouseDown, False],
				"MouseEntered" :> FEPrivate`Set[mouseHover, True],
				"MouseExited" :> FEPrivate`Set[mouseHover, False]
			},
			PassEventsDown -> True
		]
	],
	action,
	Appearance -> {
		"Default" -> FrontEnd`FileName[{"Misc"}, "TransparentBG.9.png"]
	},
	opts
]

End[] (* End `Private` *)

EndPackage[]