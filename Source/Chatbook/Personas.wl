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
	paclets = PacletFind[All, <| "Extension" -> "LLMConfiguration" |>];

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
	paclets = PacletFind[All, <| "Extension" -> "LLMConfiguration" |>];

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
		Join[KeyTake[personas, $corePersonaNames], personas],
		_Association? AssociationQ
	]
]

$corePersonaNames = {"Helper", "Wolfie"};

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
	extensionDirectory_?StringQ,
	{"LLMConfiguration", options_?AssociationQ}
] := Handle[_Failure] @ Module[{
	personas = Lookup[options, "Personas"]
},
	RaiseConfirmMatch[personas, {___?StringQ}];

	Map[
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
	]
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