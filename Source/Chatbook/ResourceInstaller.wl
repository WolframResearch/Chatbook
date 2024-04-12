(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ResourceInstaller`" ];

`$ResourceInstallationDirectory;
`GetInstalledResourceData;
`ResourceInstall;
`ResourceInstallFromRepository;
`ResourceInstallFromURL;
`ResourceInstallLocation;
`ResourceUninstall;

`channelCleanup;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`Dynamics`" ];
Needs[ "Wolfram`Chatbook`Personas`" ];

$ContextAliases[ "pi`" ] = "Wolfram`Chatbook`PersonaInstaller`Private`";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$channelData              = None;
$channelPermissions       = "Public";
$debug                    = False;
$installableTypes         = { "Prompt", "LLMTool" };
$installedResourceCache   = <| |>;
$keepChannelOpen          = True;
$resourceContexts         = { "PromptRepository`", "LLMToolRepository`" };

$unsavedResourceProperties = {
    "AuthorNotes",
    "DefinitionNotebook",
    "Documentation",
    "ExampleNotebook",
    "HeroImage",
    "Notes",
    "PageHeaderClickToCopy",
    "PromptConfiguration",
    "SampleChat",
    "ToolTemplate",
    "Usage"
};

$minimalResourceProperties = {
    "Description",
    "DocumentationLink",
    "LatestUpdate",
    "ReleaseDate",
    "RepositoryLocation",
    "UUID",
    "Version"
};

$resourceBrowseURLs = <|
    "Prompt"  -> "https://resources.wolframcloud.com/PromptRepository/category/personas",
    "LLMTool" -> "https://resources.wolframcloud.com/LLMToolRepository"
|>;

$ResourceInstallationDirectory := GeneralUtilities`EnsureDirectory @ {
    ExpandFileName @ LocalObject @ $LocalBase,
    "Chatbook"
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$$installableType = Alternatives @@ $installableTypes;
$$resourceContext = Alternatives @@ $resourceContexts;

$$notHeld = Alternatives[
    _Association, _File, _Function, _List, _Missing, _String, _URL,
    All, Association, Automatic, False, File, Function, List, Missing, None, String, True, URL
];

tempHold // Attributes = { HoldAllComplete };
held[ expr_ ] := HoldPattern[ tempHold @ expr | expr ];

$$cloudObject = held[ _CloudObject ];
$$localObject = held[ _LocalObject ];
$$url         = held[ _URL ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ResourceUninstall*)
ResourceUninstall // ClearAll;

ResourceUninstall[ rtype: $$installableType, name_String ] :=
    catchMine @ resourceUninstall[ rtype, name ];

ResourceUninstall[ ro_ResourceObject ] :=
    catchMine @ ResourceUninstall[ ro[ "ResourceType" ], ro[ "Name" ] ];

ResourceUninstall[ id_, opts: OptionsPattern[ ] ] :=
    catchMine @ With[ { ro = resourceObject[ id, opts ] },
        If[ MatchQ[ ro, _ResourceObject ],
            ResourceUninstall @ ro,
            throwFailure[ "InvalidResourceSpecification", id ]
        ]
    ];

ResourceUninstall[ args___ ] :=
    catchMine @ throwFailure[ "InvalidArguments", ResourceUninstall, HoldForm @ ResourceUninstall @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resourceUninstall*)
resourceUninstall // beginDefinition;

resourceUninstall[ rtype: $$installableType, name_String ] := Enclose[
    Module[ { target },
        target = ConfirmBy[ resourceInstallLocation[ rtype, name ], StringQ, "InstallLocation" ];
        If[ ! FileExistsQ @ target, throwFailure[ "ResourceNotInstalled", rtype, name ] ];
        ConfirmMatch[ DeleteFile @ target, Null, "DeleteFile" ];
        ConfirmAssert[ ! FileExistsQ @ target, "FileExists" ];
        invalidateCache[ rtype ];
        Null
    ],
    throwInternalFailure[ resourceUninstall[ rtype, name ], ## ] &
];

resourceUninstall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ResourceInstallFromRepository*)
ResourceInstallFromRepository // beginDefinition;

ResourceInstallFromRepository[ rtype: $$installableType ] := catchMine @ Enclose[
    Module[ { data },
        $channelData = None;

        data = ConfirmMatch[
            withExternalChannelFunctions @ browseWithChannelCallback @ rtype,
            KeyValuePattern @ { "Listener" -> _ChannelListener, "Channel" -> _ChannelObject },
            "BrowseWithCallback"
        ];

        $channelData = Append[ data, "Dialog" -> EvaluationNotebook[ ] ]
    ],
    throwInternalFailure[ ResourceInstallFromRepository @ rtype, ##1 ] &
];

ResourceInstallFromRepository // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withExternalChannelFunctions*)
withExternalChannelFunctions // beginDefinition;
withExternalChannelFunctions // Attributes = { HoldFirst };
withExternalChannelFunctions[ eval_ ] := Block[ { $AllowExternalChannelFunctions = True }, eval ];
withExternalChannelFunctions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*browseWithChannelCallback*)
browseWithChannelCallback // beginDefinition;

browseWithChannelCallback[ rtype: $$installableType ] := Enclose[
    Module[ { perms, channel, data, handler, listener, url, shortURL, parsed, id, browseURL },

        perms = ConfirmMatch[ $channelPermissions, "Public"|"Private", "ChannelPermissions" ];

        channel = ConfirmMatch[
            CreateChannel[ Permissions -> perms ],
            _ChannelObject,
            SystemOpen @ resourceBrowseURL @ rtype;
            throwMessageDialog[ "ChannelFrameworkError" ]
        ];

        data    = <| "ResourceType" -> rtype, "Listener" :> listener, "Channel" -> channel |>;
        handler = ConfirmMatch[ resourceInstallHandler @ data, _Function, "Handler" ];

        listener = ConfirmMatch[
            ChannelListen[ channel, handler ],
            _ChannelListener,
            SystemOpen @ resourceBrowseURL @ rtype;
            throwMessageDialog[ "ChannelFrameworkError" ]
        ];

        url       = ConfirmMatch[ listener[ "URL" ], _String | _URL, "ChannelListenerURL" ];
        shortURL  = ConfirmBy[ makeShortListenerURL[ channel, url ], StringQ, "URLShorten" ];
        parsed    = ConfirmMatch[ DeleteCases[ URLParse[ shortURL, "Path" ], "" ], { __String? StringQ }, "URLParse" ];
        id        = ConfirmBy[ Last @ URLParse[ shortURL, "Path" ], StringQ, "ChannelID" ];
        browseURL = ConfirmBy[ resourceBrowseURL[ rtype, id ], StringQ, "BrowseURL" ];

        ConfirmMatch[ SystemOpen @ browseURL, Null, "SystemOpen" ];
        AssociationMap[ Apply @ Rule, Append[ data, "BrowseURL" -> browseURL ] ]
    ],
    throwInternalFailure[ browseWithChannelCallback @ rtype, ## ] &
];

browseWithChannelCallback // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourceInstallHandler*)
resourceInstallHandler // beginDefinition;

resourceInstallHandler[ metadata_Association ] := Function[
    Null,
    Replace[
        catchAlways @ Block[ { PrintTemporary }, resourceInstallHandler0[ metadata, ##1 ] ],
        failed_Failure :> MessageDialog @ failed
    ],
    { HoldAllComplete }
];

resourceInstallHandler // endDefinition;


resourceInstallHandler0 // beginDefinition;

resourceInstallHandler0[ channelData: KeyValuePattern[ "Listener" :> listener0_Symbol ], messageData_ ] := Enclose[
    Module[ { data, listener, channel, message, resource, expected, actual },

        data = AssociationMap[ Apply @ Rule, channelData ];

        If[ ! TrueQ @ $keepChannelOpen,
            listener = ConfirmMatch[ listener0, _ChannelListener, "ChannelListener" ];
            Confirm[ RemoveChannelListener @ listener, "RemoveChannelListener" ];
            channel = ConfirmMatch[ data[ "Channel" ], _ChannelObject, "ChannelObject" ];
            Confirm[ DeleteChannel @ channel, "DeleteChannel" ];
            Remove @ listener0;
        ];

        message   = ConfirmBy[ messageData[ "Message" ], AssociationQ, "Message" ];
        resource  = ConfirmMatch[ acquireResource @ message, _ResourceObject, "ResourceObject" ];
        expected  = ConfirmMatch[ channelData[ "ResourceType" ], $$installableType, "ResourceTypeExpected" ];
        actual    = ConfirmBy[ resource[ "ResourceType" ], StringQ, "ResourceTypeActual" ];

        If[ actual =!= expected, throwMessageDialog[ "ExpectedInstallableResourceType", expected, actual ] ];

        ResourceInstall @ resource
    ],
    throwInternalFailure[ resourceInstallHandler0[ channelData, messageData ], ##1 ] &
];

resourceInstallHandler0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acquireResource*)
acquireResource // beginDefinition;
acquireResource[ KeyValuePattern[ "UUID" -> uuid_ ] ] := resourceObject[ uuid, ResourceVersion -> "Latest" ];
acquireResource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeShortListenerURL*)
makeShortListenerURL // beginDefinition;
makeShortListenerURL[ channel_, url_ ] := url;
makeShortListenerURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourceBrowseURL*)
resourceBrowseURL // beginDefinition;
resourceBrowseURL[ rtype_String, id_String ] := URLBuild[ resourceBrowseURL @ rtype, { "ChannelID" -> id } ];
resourceBrowseURL[ rtype: $$installableType ] := Lookup[ $resourceBrowseURLs, rtype, $Failed ];
resourceBrowseURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*channelCleanup*)
channelCleanup // beginDefinition;

channelCleanup[ ] := channelCleanup @ $channelData;
channelCleanup[ None ] := Null;

channelCleanup[ KeyValuePattern @ { "Listener" -> listener_ChannelListener, "Channel" -> channel_ChannelObject } ] :=
    Quiet[ RemoveChannelListener @ listener; DeleteChannel @ channel ];

channelCleanup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ResourceInstallFromURL*)
ResourceInstallFromURL // beginDefinition;

ResourceInstallFromURL[ ] :=
    catchMine @ ResourceInstallFromURL @ Automatic;

ResourceInstallFromURL[ rtype: $$installableType|Automatic ] := catchMine @ Enclose[
    Module[ { url },

        url = ConfirmMatch[
            DefinitionNotebookClient`FancyInputString[ "Prompt", tr[ "ResourceInstallerFromURLPrompt" ] ], (* FIXME: needs custom dialog *)
            _String|$Canceled,
            "InputString"
        ];

        If[ url === $Canceled,
            $Canceled,
            ConfirmBy[ ResourceInstallFromURL[ rtype, url ], AssociationQ, "Install" ]
        ]
    ],
    throwInternalFailure[ ResourceInstallFromURL @ rtype, ## ] &
];

ResourceInstallFromURL[ rtype: $$installableType|Automatic, url_String ] := Enclose[
    Module[ { ro, expected, actual, file },

        ro       = ConfirmMatch[ resourceFromURL @ url, _ResourceObject, "ResourceObject" ];
        expected = Replace[ rtype, Automatic -> $$installableType ];
        actual   = ConfirmBy[ ro[ "ResourceType" ], StringQ, "ResourceType" ];

        If[ ! MatchQ[ actual, expected ],
            If[ StringQ @ expected,
                throwMessageDialog[ "ExpectedInstallableResourceType", expected, actual ],
                throwMessageDialog[ "NotInstallableResourceType", actual, $installableTypes ]
            ]
        ];

        file = ConfirmBy[ ResourceInstall @ ro, FileExistsQ, "ResourceInstall" ];
        ConfirmBy[ getResourceFile @ file, AssociationQ, "GetResourceFile" ]
    ],
    throwInternalFailure[ ResourceInstallFromURL[ rtype, url ], ## ] &
];

ResourceInstallFromURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resourceFromURL*)
resourceFromURL // beginDefinition;

resourceFromURL[ url_String ] := Block[ { PrintTemporary },
    Quiet[ resourceFromURL0 @ url, { CloudObject::cloudnf, Lookup::invrl, ResourceObject::notfname } ]
];

resourceFromURL // endDefinition;

resourceFromURL0 // beginDefinition;
resourceFromURL0[ url_String ] := With[ { ro = resourceObject @ url }, ro /; installableResourceQ @ ro ];
resourceFromURL0[ url_String ] := scrapeResourceFromShingle @ url;
resourceFromURL0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installableResourceQ*)
installableResourceQ[ ro_ResourceObject ] := MatchQ[ ro[ "ResourceType" ], $$installableType ];
installableResourceQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*scrapeResourceFromShingle*)
scrapeResourceFromShingle // beginDefinition;

scrapeResourceFromShingle[ url_String ] /; StringMatchQ[ url, WhitespaceCharacter... ] :=
    throwTop @ Null;

scrapeResourceFromShingle[ url_String ] := Enclose[
    Module[ { returnInvalid, resp, bytes, xml },

        returnInvalid = throwMessageDialog[ "InvalidResourceURL" ] &;

        resp = ConfirmMatch[ URLRead @ url, _HTTPResponse, "URLRead" ];

        If[ resp[ "StatusCode" ] =!= 200, returnInvalid[ ] ];

        bytes = ConfirmBy[ resp[ "BodyByteArray" ], ByteArrayQ, "BodyByteArray" ];

        xml = ConfirmMatch[
            Quiet @ ImportByteArray[ bytes, { "HTML", "XMLObject" } ],
            XMLObject[ ___ ][ ___ ],
            "XML"
        ];

        ConfirmBy[
            FirstCase[
                xml
                ,
                XMLElement[ "div", { ___, "data-resource-uuid" -> uuid_String, ___ }, _ ] :>
                    With[ { ro = Quiet @ resourceObject @ uuid }, ro /; installableResourceQ @ ro ]
                ,
                FirstCase[
                    xml
                    ,
                    XMLElement[ "div", { ___, "data-clipboard-text" -> c2c_String, ___ }, _ ] :>
                        With[ { ro = Quiet @ ToExpression[ c2c, InputForm ] }, ro /; installableResourceQ @ ro ]
                    ,
                    returnInvalid[ ]
                    ,
                    Infinity
                ],
                Infinity
            ],
            installableResourceQ,
            "ResourceObject"
        ]
    ],
    throwInternalFailure[ scrapeResourceFromShingle @ url, ## ] &
];

scrapeResourceFromShingle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ResourceInstallLocation*)
ResourceInstallLocation // ClearAll;

ResourceInstallLocation[ ro_ResourceObject ] :=
    catchMine @ ResourceInstallLocation[ ro[ "ResourceType" ], ro[ "Name" ] ];

ResourceInstallLocation[ rtype: $$installableType, name_String ] :=
    catchMine @ resourceInstallLocation[ rtype, name ];

ResourceInstallLocation[ id_, opts: OptionsPattern[ ] ] :=
    catchMine @ With[ { ro = resourceObject[ id, opts ] },
        If[ MatchQ[ ro, _ResourceObject ],
            ResourceInstallLocation @ ro,
            throwFailure[ "InvalidResourceSpecification", id ]
        ]
    ];

ResourceInstallLocation[ args___ ] :=
    catchMine @ throwFailure[ "InvalidArguments", ResourceInstallLocation, HoldForm @ ResourceInstallLocation @ args ];

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

resourceInstall[ resource: HoldPattern @ ResourceObject[ info_Association, ___ ] ] :=
    resourceInstall @ Association[ info, resource @ All ];

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

        postInstall[ rtype, info ];
        invalidateCache[ rtype ];

        installed
    ],
    throwInternalFailure[ resourceInstall[ rtype, info ], ## ] &
];

resourceInstall[ rtype: Except[ $$installableType ], _ ] :=
    throwFailure[ "NotInstallableResourceType", rtype, $installableTypes ];

resourceInstall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*postInstall*)
postInstall // beginDefinition;
postInstall[ "Prompt", info_ ] := addToVisiblePersonas @ resourceName @ info;
postInstall[ "LLMTool", info_ ] := enableTool @ resourceName @ info;
postInstall[ rtype_, info_ ] := Null;
postInstall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*addToVisiblePersonas*)
addToVisiblePersonas // beginDefinition;

addToVisiblePersonas[ name_String ] := CurrentChatSettings[ $FrontEnd, "VisiblePersonas" ] =
    Union @ Append[
        Replace[
            CurrentChatSettings[ $FrontEnd, "VisiblePersonas" ],
            Except[ _List ] :> { }
        ],
        name
    ];

addToVisiblePersonas // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*enableTool*)
enableTool // beginDefinition;

enableTool[ name_String ] := CurrentChatSettings[ $FrontEnd, "ToolSelectionType" ] =
    Append[
        Replace[
            Association @ CurrentChatSettings[ $FrontEnd, "ToolSelectionType" ],
            Except[ _? AssociationQ ] :> <| |>
        ],
        name -> All
    ];

enableTool // endDefinition;

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
    catchMine @ throwFailure[ "NotInstallableResourceType", rtype, $installableTypes ];

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
    Module[ { data, held, merged, released },
        data = ConfirmMatch[ getInstalledResources @ rtype, { ___Association }, "GetInstalledResources" ];
        held = data /. expr: Except[ $$notHeld ] :> tempHold @ expr;

        merged = KeySort @ Association @ Cases[
            held,
            KeyValuePattern @ {
                "Name"                -> name_String,
                "Configuration"       -> config_Association,
                "ResourceInformation" -> resourceAssoc_Association
            } :>
                name -> Merge[
                    {
                        config,
                        KeyDrop[ resourceAssoc, "Name" ],
                        <|
                            "Name"         -> name,
                            "ResourceType" -> rtype,
                            "ResourceName" -> Lookup[ resourceAssoc, "Name", name ],
                            "Origin"       -> determineOrigin[ rtype, resourceAssoc ]
                        |>
                    },
                    First
                ]
        ];

        released = ConfirmBy[ merged /. tempHold[ expr_ ] :> expr, FreeQ @ tempHold, "Release" ];

        $installedResourceCache[ rtype ] = released
    ],
    throwInternalFailure
];

getInstalledResourceData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getInstalledResources*)
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
(* ::Subsubsection::Closed:: *)
(*determineOrigin*)
determineOrigin // beginDefinition;
determineOrigin[ rtype: $$installableType, KeyValuePattern[ "RepositoryLocation" -> $$url ] ] := rtype<>"Repository";
determineOrigin[ rtype_, KeyValuePattern[ "RepositoryLocation" -> $$localObject ] ] := "Local";
determineOrigin[ rtype_, KeyValuePattern[ "ResourceLocations" -> { $$localObject } ] ] := "Local";
determineOrigin[ rtype_, KeyValuePattern[ "ResourceLocations" -> { $$cloudObject } ] ] := "Cloud";
determineOrigin[ rtype_, KeyValuePattern[ "DocumentationLink" -> $$url ] ] := "Cloud";
determineOrigin[ rtype: $$installableType, _Association ] := "Unknown";
determineOrigin // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cache*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*invalidateCache*)
invalidateCache // beginDefinition;

invalidateCache[ ] :=
    invalidateCache[ All ];

invalidateCache[ All ] := (
    $installedResourceCache = <| |>;
    updateDynamics @ { "Tools", "Personas" }
);

invalidateCache[ "Prompt" ] := (
    KeyDropFrom[ $installedResourceCache, "Prompt" ];
    GetPersonaData[ ];
    updateDynamics[ "Personas" ]
);

invalidateCache[ "LLMTool" ] := (
    KeyDropFrom[ $installedResourceCache, "LLMTool" ];
    updateDynamics[ "Tools" ]
);

invalidateCache // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    $debug = False;
];

End[ ];
EndPackage[ ];
