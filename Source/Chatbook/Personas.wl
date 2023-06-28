BeginPackage["Wolfram`Chatbook`Personas`"]

Needs["GeneralUtilities`" -> None]

GeneralUtilities`SetUsage[GetPersonas, "
GetPersonas[] returns a list containing the names of all locally installed personas.
"];

GeneralUtilities`SetUsage[GetPersonasAssociation, "
GetPersonasAssociation[] returns an association describing all locally installed personas.
"];

GeneralUtilities`SetUsage[GetCachedPersonaData, "
GetCachedPersonaData[] gives the same information as GetPersonaData[], but caches the result.
"];

GeneralUtilities`SetUsage[$CachedPersonaData, "
$CachedPersonaData represents the cache used by GetCachedPersonaData. \
Setting $CachedPersonaData to None will force GetCachedPersonaData to regenerate the cache.
"];

GeneralUtilities`SetUsage[GetPersonaData, "
GetPersonaData[] returns information about all locally installed personas, including invalid personas. \
Calling GetPersonaData[] will additionally regenerate the cache used by GetCachedPersonaData.
"];

Begin["`Private`"]

Needs["Wolfram`Chatbook`Errors`"]
Needs["Wolfram`Chatbook`ErrorUtils`"]
Needs["Wolfram`Chatbook`PersonaInstaller`"]

(*========================================================*)

GetPersonas[] := Module[{
	paclets
},
	Needs["PacletTools`" -> None];
	(* Only look at most recent version of compatible paclets *)
	paclets = First /@ SplitBy[PacletFind[All, <| "Extension" -> "LLMConfiguration" |>], #["Name"]&];

	Flatten @ Map[
		paclet |-> Module[{
			extensions
		},
			extensions = RaiseConfirmMatch[
				PacletTools`PacletExtensions[paclet, "LLMConfiguration"],
				{{_String, _Association}...}
			];

			Map[
				extension |-> ConfirmReplace[Lookup[extension[[2]], "Personas"], {
					names:{___String} :> names,
					other_ :> (
						ChatbookWarning[
							"Invalid \"Personas\" field form: ``",
							InputForm[other]
						];
						Nothing
					)
				}],
				extensions
			]
		],
		paclets
	]
]

(*========================================================*)

GetPersonasAssociation[] := Module[{
	personas
},
	personas = RaiseConfirmMatch[
		GetCachedPersonaData[],
		_?AssociationQ
	];

	personas
]

(*========================================================*)

SetFallthroughError[GetCachedPersonaData]

GetCachedPersonaData[] := If[AssociationQ[$CachedPersonaData], $CachedPersonaData, GetPersonaData[]]
GetCachedPersonaData[persona_] := Lookup[GetCachedPersonaData[], persona, GetPersonaData[persona]]

$CachedPersonaData = None

(*========================================================*)

SetFallthroughError[GetPersonaData]

GetPersonaData[] := Module[{
	resourcePersonas,
	paclets,
	pacletPersonas,
	personas
},
	resourcePersonas = RaiseConfirmMatch[GetInstalledResourcePersonaData[], _Association? AssociationQ];

	Needs["PacletTools`" -> None];
	(* Only look at most recent version of compatible paclets *)
	paclets = First /@ SplitBy[PacletFind[All, <| "Extension" -> "LLMConfiguration" |>], #["Name"]&];

	pacletPersonas = KeySort @ Flatten @ Map[
		paclet |-> Handle[_Failure] @ Module[{
			extensions
		},
			extensions = RaiseConfirmMatch[
				PacletTools`PacletExtensions[paclet, "LLMConfiguration"],
				{{_String, _Association}...}
			];

			Map[
				extension |-> loadPersonaFromPacletExtension[
					paclet,
					PacletTools`PacletExtensionDirectory[paclet, extension],
					extension
				],
				extensions
			]
		],
		paclets
	];

	personas = Merge[{resourcePersonas, pacletPersonas}, First];

	$CachedPersonaData = RaiseConfirmMatch[
		(* Show core personas first *)
		Join[KeyTake[personas, $corePersonaNames], KeySort[personas]],
		_Association? AssociationQ
	]
]

$corePersonaNames = {"CodeAssistant", "CodeWriter", "PlainChat", "RawModel"};
$requiredKeys = {"Description", "UUID", "Version", "LatestUpdate", "ReleaseDate", "DocumentationLink"};
$personaBaseURL = "https://resources.wolframcloud.com/PromptRepository/resources";

(*------------------------------------*)

GetPersonaData[persona_?StringQ] := Module[{
	data = GetPersonaData[]
},
	Lookup[
		data,
		persona,
		Missing["NotAvailable", <| "Persona" -> persona |>]
	]
]

(*====================================*)

SetFallthroughError[loadPersonasFromPacletExtension]

loadPersonaFromPacletExtension[
	paclet_?PacletObjectQ,
	extensionDirectory_?StringQ,
	{"LLMConfiguration", options_?AssociationQ}
] := Handle[_Failure] @ Module[{
	personas = Lookup[options, "Personas"], slimData, ro = Quiet[ResourceObject[paclet["Name"]], ResourceObject::notfname]
},
	RaiseConfirmMatch[personas, {___?StringQ}];

	slimData = Map[
		personaName |-> (
			(* Note:
				Stop errors from propagating upwards so that a failure to load
				any one persona doesn't prevent other, valid, personas from
				being loaded and returned. *)
			personaName -> Handle[_Failure] @ loadPersonaFromDirectory[
				FileNameJoin[{extensionDirectory, "Personas", personaName}]
			]
		),
		personas
	];

	Which[
		(* this is the Wolfram/Chatbook paclet *)
		(* FIXME: can we assume parity with the paclet repository version? *)
		(* FIXME: can we assume parity with the individual personas that appear on the persona repository? *)
		paclet["Name"] === "Wolfram/Chatbook",
			Map[
				Function[
					#[[1]] ->
						Merge[
							{
								#[[2]],
								<|
									"PersonaIcon" ->
										Switch[#[[1]],
											"CodeAssistant", Wolfram`Chatbook`Common`chatbookIcon["ChatIconCodeAssistant", False],
											"CodeWriter", Wolfram`Chatbook`Common`chatbookIcon["ChatIconCodeWriter", False],
											"Birdnardo", Wolfram`Chatbook`Common`chatbookIcon["BirdnardoIcon", False],
											"PlainChat", Wolfram`Chatbook`Common`chatbookIcon["ChatIconPlainChat", False],
											"RawModel", Wolfram`Chatbook`Common`chatbookIcon["PersonaRawModel", False],
											"Wolfie", Wolfram`Chatbook`Common`chatbookIcon["WolfieIcon", False]],
									"Description" ->
										Switch[#[[1]],
											"CodeAssistant" | "PlainChat" | "RawModel", Missing["NotAvailable"],
											"Birdnardo", "The one and only Birdnardo",
											"CodeWriter", "AI code generation without the chatter",
											"Wolfie", "Wolfram's friendliest AI guide"],
									"UUID" -> ro["UUID"],
									"Version" -> paclet["Version"],
									"LatestUpdate" -> ro["LatestUpdate"],
									"ReleaseDate" -> ro["ReleaseDate"],
									"DocumentationLink" ->
										Switch[#[[1]],
											"CodeAssistant" | "PlainChat" | "RawModel", Missing["NotAvailable"],
											"Birdnardo" | "CodeWriter" | "Wolfie", URLBuild[{$personaBaseURL, #[[1]]}]],
									"PacletLink" -> ro["DocumentationLink"],
									"InstallationDate" -> FileDate[paclet["Location"], "Creation"],
									"Origin" -> "Wolfram/Chatbook",
									"PacletName" -> paclet["Name"]|>},
							First]],
				slimData],
		(* paclet originates from the paclet repository *)
		!FailureQ[ro] && ro["ResourceType"] === "Paclet",
			Map[
				#[[1]] ->
					Merge[
						{
							#[[2]],
							AssociationMap[ro, $requiredKeys],
							<|"Origin" -> "PacletRepository", "PacletName" -> paclet["Name"], "InstallationDate" -> FileDate[paclet["Location"], "Creation"]|>},
						First]&,
				slimData],
		(* paclet is locally installed *)
		True,
			Map[
				#[[1]] ->
					Merge[
						{
							#[[2]],
							AssociationMap[paclet, $requiredKeys],
							<|"Origin" -> "LocalPaclet", "PacletName" -> paclet["Name"], "InstallationDate" -> FileDate[paclet["Location"], "Creation"]|>},
						First]&,
				slimData]]
]

(*====================================*)

SetFallthroughError[loadPersonaFromDirectory]

loadPersonaFromDirectory[dir_?StringQ] := Module[{
	pre,
	post,
	icon,
	config,
	extra
},
	If[!DirectoryQ[dir],
		Raise[
			ChatbookError,
			<| "PersonaDirectory" -> dir |>,
			"Persona does not exist in expected directory: ``",
			InputForm[dir]
		];
	];

	pre = FileNameJoin[{dir, "Pre.md"}];
	post = FileNameJoin[{dir, "Post.md"}];
	(* TODO: Support .png, .jpg, etc. icons. *)
	icon = FileNameJoin[{dir, "Icon.wl"}];
	config = FileNameJoin[{dir, "LLMConfiguration.wl"}];

	pre = If[FileType[pre] === File,
		readPromptString[pre],
		Missing["NotAvailable", pre]
	];

	post = If[FileType[post] === File,
		readPromptString[post],
		Missing["NotAvailable", post]
	];

	icon = If[FileType[icon] === File,
		Import[icon],
		Missing["NotAvailable", icon]
	];

	config = If[FileType[config] === File,
		Get[config],
		Missing["NotAvailable", config]
	];

	extra = <| "Pre" -> pre, "Post" -> post, "Icon" -> icon |>;

	If[ AssociationQ[config],
		Association[extra, config],
		extra
	]
]

readPromptString[ file_ ] := StringReplace[ ByteArrayToString @ ReadByteArray @ file, "\r\n" -> "\n" ];

End[]
EndPackage[]