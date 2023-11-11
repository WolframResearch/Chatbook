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

`$corePersonaNames;

Begin["`Private`"]

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`Errors`"            ];
Needs[ "Wolfram`Chatbook`ErrorUtils`"        ];
Needs[ "Wolfram`Chatbook`ResourceInstaller`" ];
Needs[ "Wolfram`Chatbook`Utils`"             ];

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
	resourcePersonas = RaiseConfirmMatch[
		GetInstalledResourceData["Prompt", "RegenerateCache" -> True],
		_Association? AssociationQ
	];

	(* Only look at most recent version of compatible paclets *)
	paclets = First /@ SplitBy[PacletFind[All, <| "Extension" -> "LLMConfiguration" |>], #["Name"]&];
	pacletPersonas = KeySort @ Flatten @ Map[loadPacletPersonas, paclets];
	personas = Merge[{resourcePersonas, pacletPersonas}, First];

	$CachedPersonaData = RaiseConfirmMatch[
		(* Show core personas first *)
		standardizePersonaData /@ Join[KeyTake[personas, $corePersonaNames], KeySort[personas]],
		_Association? AssociationQ
	]
]

$corePersonaNames = {"CodeAssistant", "CodeWriter", "PlainChat", "RawModel"};


loadPacletPersonas[ paclet_PacletObject ] := loadPacletPersonas[ paclet[ "Name" ], paclet[ "Version" ], paclet ];

loadPacletPersonas[ name_, version_, paclet_ ] := loadPacletPersonas[ name, version, _ ] =
	Handle[_Failure] @ Module[{
		extensions
	},
		Needs["PacletTools`" -> None];

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
	];

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
				paclet,
				personaName,
				FileNameJoin[{extensionDirectory, "Personas", personaName}]
			]
		),
		personas
	]
]

(*====================================*)

SetFallthroughError[loadPersonaFromDirectory]

loadPersonaFromDirectory[paclet_PacletObject, personaName_, dir_?StringQ] := Module[{
	pre,
	post,
	icon,
	config,
	origin,
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
		readString[pre],
		Missing["NotAvailable", pre]
	];

	post = If[FileType[post] === File,
		readString[post],
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

	origin = Replace[ paclet[ "Name" ], Except[ "Wolfram/Chatbook" ] -> "LocalPaclet" ];

	extra = <|
		"Name"        -> personaName,
		"DisplayName" -> personaName,
		"Icon"        -> icon,
		"Origin"      -> origin,
		"PacletName"  -> paclet[ "Name" ],
		"Post"        -> post,
		"Pre"         -> pre,
		"Version"     -> paclet[ "Version" ]
	|>;

	If[ AssociationQ[config],
		Association[extra, config],
		extra
	]
]


standardizePersonaData // beginDefinition;

(* Rename "PersonaIcon" key to "Icon" *)
standardizePersonaData[ persona: KeyValuePattern[ "PersonaIcon" -> icon_ ] ] :=
	standardizePersonaData @ KeyDrop[
		Insert[ Association @ persona, "Icon" -> icon, Key[ "PersonaIcon" ] ],
		"PersonaIcon"
	];

standardizePersonaData[ persona_Association? AssociationQ ] := Association[
	"DisplayName" -> Lookup[ persona, "DisplayName", Lookup[ persona, "Name", Lookup[ persona, "LLMEvaluatorName" ] ] ],
	"Name" -> Lookup[ persona, "Name", Lookup[ persona, "LLMEvaluatorName", Lookup[ persona, "DisplayName" ] ] ],
	persona
];

standardizePersonaData // endDefinition;


If[ Wolfram`ChatbookInternal`$BuildingMX,
    loadPacletPersonas @ PacletObject[ "Wolfram/Chatbook" ];
];

End[]
EndPackage[]