BeginPackage["Wolfram`LLMTools`APIs`Common`"]

APIFailure
ConnectToService
$ConnectionCache
$ValidAuthenticationPattern
ConformAuthentication
TestConnection

Needs["GeneralUtilities`" -> "GU`"]

GU`SetUsage[$APIParameters, "$APIParameters is a variable that contains parameters for each API endpoint.
The format should be:
$APIParameters['name$', 'endpoint$'] = {
	{'requiredkey$i' -> testfunction$i},
	{'optionalkey$j' -> testfunction$j},
}"]

GU`SetUsage[ValidateAPIParams, "ValidateAPIParams[service$, endpoint$, params$]\
 validates the association params$ using the data in $APIParameters[service$, endpoint$]."]

Needs["Wolfram`LLMTools`Common`"]

Begin["`Private`"]

ValidateAPIParams[name_, task_, params_] := 
GU`Scope[Enclose[
	ConfirmAssert[AssociationQ[params]];
	{required, optional} = $APIParameters[name, task];
	With[{
			keys = Keys[params],
			required1 = Keys@required,
			all = Catenate[Keys@{required, optional}]
		},
		(* check required parameters *)
		ConfirmAssert[ContainsAll[keys, required1]];
		(* check optional parameters *)
		ConfirmAssert[ContainsOnly[keys, all]];
	];
	(* check parameters' values *)
	tests = Association[{required, optional}];
	KeyValueMap[
		With[{test = tests[#1]},
			ConfirmAssert[test[#2]]
		]&,
		params
	],
	APIFailure
]];

Clear[APIFailure]
APIFailure[failure_Failure] := 
	Replace[failure["HeldMessageCall"], 
		Hold[Message[MessageName[head_, name_], params___]] :>
			Failure[name, 
				<|
					"MessageTemplate" :> MessageName[head, name],
					"MessageParameters" :> {params}
				|>
			]
	] /; !MissingQ[failure["HeldMessageCall"]]
APIFailure[failure_Failure] :=
	failure["Expression"] /; 
		And[!MissingQ[failure["Expression"]], failure["ConfirmationType"] === "Confirm"]
APIFailure[failure_Failure] := 
	GU`Scope[
		message = Replace[
			HoldForm @@ failure["HeldTest"], 
			s_Symbol :> RuleCondition@errorSymbol[s],
			All
		];
		Failure["APIError", 
			<|
				"MessageTemplate" :> "Assertion failed: ``",
				"MessageParameters" -> {message} 
			|>
		] /; 
		And[!MissingQ[failure["HeldTest"]], failure["ConfirmationType"] === "ConfirmAssert"]
	]
APIFailure[failure_Failure] := failure

SetAttributes[errorSymbol, HoldFirst]
errorSymbol[s_Symbol] := StringForm["`1` (`2`)", SymbolName[Unevaluated[s]], s] /; ValueQ[s]
errorSymbol[s_Symbol] := SymbolName[Unevaluated[s]]

$ValidAuthenticationPattern = "Cached" | "Available" | Environment | SystemCredential |
	"Dialog";

ClearAll["ConnectToService"]
ConnectToService[name_, authentication_] :=
	GU`Scope[Enclose[
		Switch[authentication,
			"Cached",
				so = Confirm @ SelectFirst[
					Lookup[$ConnectionCache, Key@name, <||>],
					(
						DBPrint["ConnectToService: ", StringForm["Testing `` for availability...", Last@#]];
						Not @ FailureQ @ TestConnection[name, #]
					)&,
					$Failed
				];
				hash = None (* already in cache *)
				,
			_Association | Environment | SystemCredential, (* password / apikey ... *)
				(* check the connection cache for existing so *)
				authmod = Confirm @ ConformAuthentication[name, authentication];
				hash = authenticationHash[authmod];
				so = Query[Key@name, Key@hash][$ConnectionCache];
				(* validate connection *)
				If[MissingQ[so] || FailureQ @ TestConnection[name, so],
					DBPrint["ConnectToService: ", StringForm["Creating new connection with provided authentication ``", authentication]];
					so = Confirm @ makeConnection[name, authmod]
				]
				,
			"Available",
				DBPrint["ConnectToService: ", StringForm["Attempting to grab external connection to ``.", name]];
				so = Confirm @ Quiet[ConfirmQuiet[ServiceConnect[name]]];
				Confirm @ TestConnection[name, so];
				hash = Confirm @ authenticationHash[Confirm @ ConformAuthentication[so]];
				,
			"Dialog",
				(* prompt for hash *)
				so = Confirm @ makeConnection[name, "Dialog"];
				hash = Confirm @ authenticationHash[Confirm @ ConformAuthentication[so]];
				,
			_ServiceObject,
				(* test is wasting time - no early failure gain *)
				so = authentication;
				DBPrint["ConnectToService: ", StringForm["Using provided connection w/o validation ``.", Last @ authentication]];
				hash = If[MemberQ[Values@$ConnectionCache[name], so],
					None, (* likely - performances : no cloud lookup on existing object *)
					Confirm @ authenticationHash[Confirm @ ConformAuthentication[so]]
				];
				,
			_,
				(* TODO : service credits via "WolframCloud" *)
				DBPrint["ConnectToService: ", StringForm["Unsupported authentication ``.", authentication]];
				GU`ThrowFailure["bdauth", authentication]
		];
		
		(* cache/overwrite the connection *)
		If[StringQ@hash, saveConnection[name, hash, so]];

		so
		,
		APIFailure
	]];

ConnectToService[name_] := GU`Scope[
	Do[
		DBPrint["ConnectToService: ", StringForm["Looking for any `` connection to ``.", auth, name]];
		so = ConnectToService[name, auth];
		If[!FailureQ[so], Break[]];
		,
		{auth, {"Cached", Environment, SystemCredential, "Available", "Dialog"}}
	];
	so
];

authenticationHash = Hash[#, "SHA512", "Base64Encoding"]&;

$ConnectionCache = <||>;

saveConnection[name_, hash_, so_ServiceObject] := GU`Scope[
	If[
		!KeyExistsQ[$ConnectionCache, name],
		$ConnectionCache[name] = <||>;
	];
	DBPrint["saveConnection: ", StringForm["Connection `` to `` is now cached as ``.", First @ so, name, hash]];
	$ConnectionCache[name][hash] = so
]

makeConnection[name_String, auth_] := GU`Scope[Enclose[
	so = ConfirmQuiet @ Confirm @ Switch[auth,
		"Dialog",
			ServiceConnect[name, "New"]
			,
		_Association | _List /; Not @ FailureQ @ ConformAuthentication[name, auth],
			ServiceConnect[name, "New", Authentication -> ConformAuthentication[name, auth]]
			,
		_,
			Return @ Failure["APIError", <|"Message" -> "Unkown authentication error"|>];
	];
	Confirm @ TestConnection[name, so];
	so
]];

makeConnection[name_String] := GU`Scope[Enclose[
	so = Quiet[ConfirmQuiet @ Confirm @ ServiceConnect[name], ServiceConnect::multser];
	Confirm @ TestConnection[name, so];
	so
]];

makeConnection[a__] := $Failed;

TestConnection[request_HTTPRequest] := GU`Scope[
	{timing, response}= AbsoluteTiming @ URLRead[request, Interactive -> False];
	DBPrint["Connection test result: ", PrettyForm[response]];
	DBPrint["test took: ", timing];

	Switch[response["StatusCode"],
		502,
			Failure["APIError",
				<|
					"MessageTemplate" :> ServiceExecute::apierr,
					"MessageParameters" :> {"502 Bad Gateway"}
				|>
			],
		Except[200],
			message = Developer`ReadRawJSONString[response["Body"]]["error", "message"];
			Failure["APIError",
				<|
					"Message" -> message
				|>
			]
	]

	(* models = Developer`ReadRawJSONString[response["Body"]]; *)
]
TestConnection[arg___] :=
	(
		DBPrint["TestConnection: ", StringForm["Called with ``", {arg}]];
		Failure["APIError", <|"Message" -> "Unkown connection error"|>]
	);

End[] (* End `Private` *)

EndPackage[]
