BeginPackage["Wolfram`Chatbook`Personas`"]

Needs["GeneralUtilities`" -> None]

GeneralUtilities`SetUsage[GetPersonas, "
GetPersonas[] returns a list containing the names of all locally installed personas.
"];

GeneralUtilities`SetUsage[GetPersonasAssociation, "
GetPersonasAssociation[] returns an association describing all locally installed personas.
"];

GeneralUtilities`SetUsage[GetPersonaData, "
GetPersonasData[] returns information about all locally installed personas, including invalid personas.
"];

Begin["`Private`"]

Needs["Wolfram`Chatbook`Errors`"]
Needs["Wolfram`Chatbook`ErrorUtils`"]

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
		GetPersonaData[],
		_?ListQ
	];

	personas = Cases[personas, HoldPattern[_?StringQ -> _?AssociationQ]];

	Merge[personas, Join]
]

(*========================================================*)

SetFallthroughError[GetPersonaData]

GetPersonaData[] := Module[{
	paclets
},
	Needs["PacletTools`" -> None];
	paclets = PacletFind[All, <| "Extension" -> "LLMConfiguration" |>];

	Flatten @ Map[
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
	]
]

(*------------------------------------*)

GetPersonaData[persona_?StringQ] := Module[{
	data = GetPersonaData[]
},
	FirstCase[
		data,
		HoldPattern[persona -> pData_?AssociationQ] :> pData,
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
	icon
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

	pre = If[FileType[pre] === File,
		ReadString[pre],
		Missing["NotAvailable", pre]
	];

	post = If[FileType[post] === File,
		ReadString[post],
		Missing["NotAvailable", post]
	];

	icon = If[FileType[icon] === File,
		Import[icon],
		Missing["NotAvailable", icon]
	];

	<| "Pre" -> pre, "Post" -> post, "Icon" -> icon |>
]

End[]
EndPackage[]