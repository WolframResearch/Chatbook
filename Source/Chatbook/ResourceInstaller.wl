(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ResourceInstaller`" ];

`$ResourceInstallationDirectory;
`GetInstalledResources;
`GetInstalledResourceData;
`ResourceInstall;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

$ContextAliases[ "pi`" ] = "Wolfram`Chatbook`PersonaInstaller`Private`";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$channelPermissions     = "Public";
$keepChannelOpen        = True;
$debug                  = False;
$installableTypes       = { "Prompt", "LLMTool" };
$resourceContexts       = { "PromptRepository`", "LLMToolRepository`" };
$installedResourceCache = <| |>;

$unsavedResourceProperties = {
    "AuthorNotes",
    "DefinitionNotebook",
    "Documentation",
    "ExampleNotebook",
    "HeroImage",
    "Notes",
    "SampleChat",
    "ToolTemplate",
    "Usage"
};

$ResourceInstallationDirectory := GeneralUtilities`EnsureDirectory @ {
    ExpandFileName @ LocalObject @ $LocalBase,
    "Chatbook"
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$$installableType = Alternatives @@ $installableTypes;
$$resourceContext = Alternatives @@ $resourceContexts;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ResourceInstall*)
ResourceInstall // ClearAll;

ResourceInstall[ ro_ResourceObject ] :=
    catchMine @ resourceInstall @ ro;

ResourceInstall[ id_, opts: OptionsPattern[ ] ] :=
    catchMine @ With[ { ro = resourceObject[ id, opts ] },
        If[ MatchQ[ ro, _ResourceObject ],
            ResourceInstall @ ro,
            throwFailure[ "InvalidResourceSpecification", id ]
        ]
    ];

ResourceInstall[ args___ ] :=
    catchMine @ throwFailure[ "InvalidArguments", ResourceInstall, HoldForm @ ResourceInstall @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resourceObject*)
resourceObject // ClearAll;
resourceObject[ args___ ] := Quiet[ ResourceObject @ args, ResourceObject::updav ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resourceInstall*)
resourceInstall // beginDefinition;

resourceInstall[ resource_ResourceObject ] := resourceInstall @ resource[ All ];
resourceInstall[ info_? AssociationQ ] := resourceInstall[ info[ "ResourceType" ], info ];

resourceInstall[ rtype: $$installableType, info_? AssociationQ ] := Enclose[
    Module[ { target, content, installed },

        target    = ConfirmBy[ resourceInstallLocation[ rtype, info ], StringQ, "InstallLocation" ];
        content   = ConfirmBy[ resourceInstalledContent[ rtype, info ], AssociationQ, "InstalledContent" ];
        installed = ConfirmBy[ installResourceContent[ info, content, target ], FileExistsQ, "Install" ];

        If[ TrueQ @ $debug,
            MessageDialog @ Grid[
                {
                    { Style[ "Resource Install Debug Info", "Section" ], SpanFromLeft          },
                    { "ResourceObject:"                                , resourceObject @ info },
                    { "Installed:"                                     , installed             }
                },
                Alignment -> Left,
                Dividers  -> Center
            ]
        ];

        KeyDropFrom[ $installedResourceCache, rtype ];

        installed
    ],
    throwInternalFailure[ resourceInstall[ rtype, info ], ## ] &
];

resourceInstall[ rtype: Except[ $$installableType ], _ ] :=
    throwFailure[ "NotInstallableResourceType", rtype ];

resourceInstall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourceInstallLocation*)
resourceInstallLocation // beginDefinition;

resourceInstallLocation[ rtype_, KeyValuePattern[ "Name" -> name_ ] ] :=
    resourceInstallLocation[ rtype, name ];

resourceInstallLocation[ rtype_String, name0_String ] := Enclose[
    Module[ { name, fileName, directory },
        name      = ConfirmBy[ resourceName[ rtype, name0 ], StringQ, "Name" ];
        fileName  = URLEncode @ name <> ".mx";
        directory = ConfirmBy[ resourceTypeDirectory @ rtype, DirectoryQ, "Directory" ];
        FileNameJoin @ { directory, fileName }
    ],
    throwInternalFailure[ resourceInstallLocation[ rtype, name0 ], ## ] &
];

resourceInstallLocation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourceTypeDirectory*)
resourceTypeDirectory // beginDefinition;

resourceTypeDirectory[ rtype_String ] := Enclose[
    Module[ { root, typeName },
        root     = ConfirmBy[ $ResourceInstallationDirectory, DirectoryQ, "RootDirectory" ];
        typeName = ConfirmBy[ resourceTypeDirectoryName @ rtype, StringQ, "TypeName" ];
        ConfirmBy[ GeneralUtilities`EnsureDirectory @ { root, typeName }, DirectoryQ, "Directory" ]
    ],
    throwInternalFailure[ resourceTypeDirectory @ rtype, ## ] &
];

resourceTypeDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourceTypeDirectoryName*)
resourceTypeDirectoryName // beginDefinition;
resourceTypeDirectoryName[ "Prompt"     ] := "Personas";
resourceTypeDirectoryName[ "LLMTool"    ] := "Tools";
resourceTypeDirectoryName[ rtype_String ] := URLEncode @ rtype;
resourceTypeDirectoryName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourceName*)
resourceName // beginDefinition;

resourceName[ KeyValuePattern @ { "ResourceType" -> rtype_, "Name" -> name_ } ] :=
    resourceName[ rtype, name ];

resourceName[ rtype_String, name_String ] := (
    needsResourceType @ rtype;
    StringDelete[ name, StartOfString ~~ ResourceSystemClient`ResourceType`NamePrefix @ rtype ]
);

resourceName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*needsResourceType*)
needsResourceType // beginDefinition;

needsResourceType[ rtype: $$installableType ] := Enclose[
    Module[ { pacletName, paclet, context },
        pacletName = ConfirmBy[ rtype <> "Resource", StringQ, "PacletName" ];
        paclet = ConfirmBy[ PacletInstall @ pacletName, PacletObjectQ, "PacletInstall" ];
        context = ConfirmBy[ First[ Flatten @ List @ paclet[ "Context" ], $Failed ], StringQ, "Context" ];
        ConfirmMatch[ Needs[ context -> None ], Null, "NeedsContext" ];
        ConfirmAssert[ MemberQ[ $Packages, context ], "Packages" ];
        needsResourceType[ rtype ] = Null
    ],
    throwInternalFailure[ needsResourceType @ rtype, ## ] &
];

needsResourceType // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourceInstalledContent*)
resourceInstalledContent // beginDefinition;

resourceInstalledContent[ "Prompt", info_Association ] := Enclose[
    ConfirmBy[ ResourceObject[ info ][ "PromptConfiguration" ], AssociationQ ],
    throwInternalFailure[ resourceInstalledContent[ "Prompt", info ], ## ] &
];

resourceInstalledContent[ "LLMTool", info_Association ] := Enclose[
    Module[ { resource, defaultTool, template },

        resource    = ConfirmMatch[ resourceObject @ info, _ResourceObject, "ResourceObject" ];
        defaultTool = ConfirmMatch[ resource[ "LLMTool" ], _LLMTool, "LLMTool" ];
        template    = ConfirmMatch[ resource[ "ToolTemplate" ], _TemplateObject, "TemplateObject" ];

        If[ FreeQ[ template, _TemplateSlot|_TemplateExpression, { 2, Infinity } ],
            <| "Tool" -> defaultTool, "Template" -> None    , "Templated" -> False |>,
            <| "Tool" -> defaultTool, "Template" -> template, "Templated" -> True  |>
        ]
    ],
    throwInternalFailure[ resourceInstalledContent[ "LLMTool", info ], ## ] &
];

resourceInstalledContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installResourceContent*)
installResourceContent // beginDefinition;

installResourceContent[ info_, content_, target_ ] :=
    installResourceContent0[
        installedResourceInfo @ info,
        content,
        target,
        resourceName @ info,
        resourceContext @ content
    ];

installResourceContent // endDefinition;


installResourceContent0 // beginDefinition;

installResourceContent0[ info_, config_, target_, name_String, context_ ] :=
    Block[ { pi`$PersonaConfig = <| "Name" -> name, "ResourceInformation" -> info, "Configuration" -> config |> },
        With[ { symbol = ToString @ Unevaluated @ pi`$PersonaConfig },
            DumpSave[ target, Evaluate @ Select[ { symbol, context }, StringQ ], "SymbolAttributes" -> False ];
            target
        ]
    ];

installResourceContent0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installedResourceInfo*)
installedResourceInfo // beginDefinition;
installedResourceInfo[ info_Association? AssociationQ ] := KeyDrop[ info, $unsavedResourceProperties ];
installedResourceInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourceContext*)
resourceContext // beginDefinition;

resourceContext[ config_Association ] := FirstCase[
    ToExpression[ ToString[ config, InputForm ], InputForm, HoldComplete ],
    s_Symbol? dependentResourceSymbolQ :> Context @ Unevaluated @ s,
    None,
    Infinity,
    Heads -> True
];

resourceContext // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dependentResourceSymbolQ*)
dependentResourceSymbolQ // ClearAll;
dependentResourceSymbolQ // Attributes = { HoldAllComplete };

dependentResourceSymbolQ[ sym_Symbol ] := TrueQ @ And[
    AtomQ @ Unevaluated @ sym,
    Unevaluated @ sym =!= Internal`$EFAIL,
    StringStartsQ[ Context @ Unevaluated @ sym, $$resourceContext ]
];

dependentResourceSymbolQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GetInstalledResources*)
getInstalledResources // beginDefinition;
getInstalledResources[ rtype_String ] := getResourceFile /@ FileNames[ "*.mx", resourceTypeDirectory @ rtype ];
getInstalledResources // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getResourceFile*)
getResourceFile // beginDefinition;
getResourceFile[ file_ ] := Block[ { pi`$PersonaConfig = $Failed }, Get @ file; pi`$PersonaConfig ];
getResourceFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GetInstalledResourceData*)
GetInstalledResourceData // ClearAll;
GetInstalledResourceData // Options = { "RegenerateCache" -> False };

GetInstalledResourceData[ opts: OptionsPattern[ ] ] :=
    catchMine @ GetInstalledResourceData[ All, opts ];

GetInstalledResourceData[ All, opts: OptionsPattern[ ] ] :=
    catchMine[
        If[ TrueQ @ OptionValue[ "RegenerateCache" ], $installedResourceCache = <| |> ];
        AssociationMap[ getInstalledResourceData, $installableTypes ]
    ];

GetInstalledResourceData[ rtype: $$installableType, opts: OptionsPattern[ ] ] :=
    catchMine[
        If[ TrueQ @ OptionValue[ "RegenerateCache" ], KeyDropFrom[ $installedResourceCache, rtype ] ];
        getInstalledResourceData @ rtype
    ];

GetInstalledResourceData[ rtype_, opts: OptionsPattern[ ] ] :=
    catchMine @ throwFailure[ "NotInstallableResourceType", rtype ];

GetInstalledResourceData[ a___ ] :=
    catchMine @ throwFailure[ "InvalidArguments", GetInstalledResourceData, HoldForm @ GetInstalledResourceData @ a ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getInstalledResourceData*)
getInstalledResourceData // beginDefinition;

getInstalledResourceData[ rtype_ ] :=
    With[ { cached = $installedResourceCache[ rtype ] },
        cached /; ! MissingQ @ cached
    ];

getInstalledResourceData[ rtype: $$installableType ] := Enclose[
    Module[ { data },
        data = ConfirmMatch[ getInstalledResources @ rtype, { ___Association }, "GetInstalledResources" ];
        Block[ { TemplateObject, CloudObject },
            SetAttributes[ TemplateObject, HoldAllComplete ];
            $installedResourceCache[ rtype ] = KeySort @ Association @ Cases[
                data,
                KeyValuePattern @ {
                    "Name"                -> name_String,
                    "Configuration"       -> config_Association,
                    "ResourceInformation" -> resourceAssoc_Association
                } :>
                    name -> Merge[
                        {
                            config,
                            KeyTake[
                                resourceAssoc,
                                { "Description", "UUID", "Version", "LatestUpdate", "ReleaseDate", "DocumentationLink" }
                            ],
                            <| "Origin" -> rtype<>"Repository" |> (* FIXME: these aren't always from the repository *)
                        },
                        First
                    ]
            ]
        ]
    ],
    throwInternalFailure[ getInstalledResourceData @ rtype, ## ] &
];

getInstalledResourceData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    $debug = False;
];

End[ ];
EndPackage[ ];
