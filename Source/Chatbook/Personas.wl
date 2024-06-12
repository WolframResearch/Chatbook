(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Personas`" ];

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

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`Common`"            ];
Needs[ "Wolfram`Chatbook`Errors`"            ];
Needs[ "Wolfram`Chatbook`ErrorUtils`"        ];
Needs[ "Wolfram`Chatbook`ResourceInstaller`" ];
Needs[ "Wolfram`Chatbook`Utils`"             ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$CachedPersonaData = None;
$corePersonaNames  = { "CodeAssistant", "CodeWriter", "PlainChat", "RawModel" };

$promptFileBaseNames  = { "Pre", "Post", "ToolExamplePrompt", "ToolPostPrompt", "ToolPrePrompt" };
$$promptFileBaseName  = Alternatives @@ $promptFileBaseNames;
$$promptFileExtension = "md"|"txt"|"wl"|"m"|"wxf";
$$promptFileName      = $$promptFileBaseName ~~ "." ~~ $$promptFileExtension;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Get Personas*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*GetPersonas*)
GetPersonas // beginDefinition;

GetPersonas[] := Module[{
	paclets
},
	(* TODO: avoid this to reduce load time: *)
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
];

GetPersonas // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*GetPersonasAssociation*)
GetPersonasAssociation // beginDefinition;
GetPersonasAssociation // Options = { "IncludeHidden" -> True };

GetPersonasAssociation[ opts: OptionsPattern[ ] ] := Enclose[
	ConfirmBy[ GetCachedPersonaData @ opts, AssociationQ ],
	throwInternalFailure
];

GetPersonasAssociation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*GetCachedPersonaData*)
GetCachedPersonaData // beginDefinition;
GetCachedPersonaData // Options = { "IncludeHidden" -> True };

GetCachedPersonaData[ opts: OptionsPattern[ ] ] := Enclose[
	Module[ { data },
		data = ConfirmBy[
			If[ AssociationQ @ $CachedPersonaData, $CachedPersonaData, GetPersonaData[ ] ],
			AssociationQ,
			"PersonaData"
		];

		If[ TrueQ @ OptionValue[ "IncludeHidden" ],
			data,
			DeleteCases[ data, KeyValuePattern[ "Hidden" -> True ] ]
		]
	],
	throwInternalFailure
];

GetCachedPersonaData[ persona_String ] := Lookup[
	GetCachedPersonaData[ "IncludeHidden" -> True ],
	persona,
	GetPersonaData @ persona
];

GetCachedPersonaData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*GetPersonaData*)
GetPersonaData // beginDefinition;

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

	$CachedPersonaData = fixFEResourceBoxes @ RaiseConfirmMatch[
		(* Show core personas first *)
		standardizePersonaData /@ Join[KeyTake[personas, $corePersonaNames], KeySort[personas]],
		_Association? AssociationQ
	]
]

GetPersonaData[persona_?StringQ] := Module[{
	data = GetPersonaData[]
},
	Lookup[
		data,
		persona,
		Missing["NotAvailable", <| "Persona" -> persona |>]
	]
]

GetPersonaData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fixFEResourceBoxes*)
fixFEResourceBoxes // beginDefinition;
fixFEResourceBoxes[ expr_ ] := expr /. Dynamic[ res_FEPrivate`FrontEndResource ] :> RawBoxes @ DynamicBox @ res;
fixFEResourceBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*loadPacletPersonas*)
loadPacletPersonas // beginDefinition;

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

loadPacletPersonas // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*loadPersonaFromPacletExtension*)
loadPersonaFromPacletExtension // beginDefinition;

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
];

loadPersonaFromPacletExtension // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*loadPersonaFromDirectory*)
loadPersonaFromDirectory // beginDefinition;

loadPersonaFromDirectory[ paclet_PacletObject, personaName_, dir_? StringQ ] := Enclose[
	Module[ { icon, config, origin, prompts, extra },

		If[ ! DirectoryQ @ dir,
			Raise[
				ChatbookError,
				<| "PersonaDirectory" -> dir |>,
				"Persona does not exist in expected directory: ``",
				InputForm @ dir
			];
		];

		icon = FileNameJoin @ { dir, "Icon.wl" };
		config = FileNameJoin @ { dir, "LLMConfiguration.wl" };
		icon = If[ FileType @ icon === File, Import @ icon, Missing[ "NotAvailable", icon ] ];
		config = If[ FileType @ config === File, Get @ config, Missing[ "NotAvailable", config ] ];
		origin = Replace[ paclet[ "Name" ], Except[ "Wolfram/Chatbook" ] -> "LocalPaclet" ];

		prompts = ConfirmBy[ getPromptFiles @ dir, AssociationQ, "GetPromptFiles" ];
		ConfirmAssert[ AllTrue[ prompts, MatchQ[ $$template ] ], "Templates" ];

		extra = DeleteMissing @ <|
			"Name"        -> personaName,
			"DisplayName" -> personaName,
			"Hidden"      -> False,
			"Icon"        -> icon,
			"Origin"      -> origin,
			"PacletName"  -> paclet[ "Name" ],
			"Version"     -> paclet[ "Version" ]
		|>;

		If[ AssociationQ @ config,
			<| extra, prompts, DeleteMissing @ config |>,
			<| extra, prompts |>
		]
	],
	throwInternalFailure
];

loadPersonaFromDirectory // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getPromptFiles*)
getPromptFiles // beginDefinition;
getPromptFiles[ dir_? DirectoryQ ] := getPromptFiles @ FileNames[ $$promptFileName, dir, IgnoreCase -> True ];
getPromptFiles[ files_List ] := Association[ getPromptFile /@ files ];
getPromptFiles // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*getPromptFile*)
getPromptFile // beginDefinition;

getPromptFile[ file_ ] := getPromptFile[ FileBaseName @ file, ToLowerCase @ FileExtension @ file, file ];

getPromptFile[ base: $$promptFileBaseName, "md"|"txt", file_ ] := base -> readString @ file;
getPromptFile[ base: $$promptFileBaseName, "wl"|"m"  , file_ ] := base -> Get @ file;
getPromptFile[ base: $$promptFileBaseName, "wxf"     , file_ ] := base -> Developer`ReadWXFFile @ file;

getPromptFile[ base0_String, ext_String, file_ ] :=
	Module[ { base },
		base = AssociationThread[ ToLowerCase @ $promptFileBaseNames, $promptFileBaseNames ][ ToLowerCase @ base0 ];
		getPromptFile[ base, ext, file ] /; MatchQ[ base, $$promptFileBaseName ]
	];

getPromptFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*standardizePersonaData*)
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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    loadPacletPersonas @ PacletObject[ "Wolfram/Chatbook" ];
];

End[ ];
EndPackage[ ];