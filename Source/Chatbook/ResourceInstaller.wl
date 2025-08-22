(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ResourceInstaller`" ];

`$ResourceInstallationDirectory;
`GetInstalledResourceData;
`ResourceInstall;
`ResourceInstallFromFile;
`ResourceInstallFromRepository;
`ResourceInstallFromURL;
`ResourceInstallLocation;
`ResourceUninstall;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
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

$ResourceInstallationDirectory := $ChatbookFilesDirectory;

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
held // Attributes = { HoldAllComplete };
held[ expr_ ] := HoldPattern[ tempHold @ expr | expr ];

$$cloudObjectH = held[ _CloudObject ];
$$localObjectH = held[ _LocalObject ];
$$urlH         = held[ _URL ];

$$channelObject   = HoldPattern[ _ChannelObject   ];
$$channelListener = HoldPattern[ _ChannelListener ];
$$resourceObject  = HoldPattern[ _ResourceObject  ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ResourceUninstall*)
ResourceUninstall // ClearAll;

ResourceUninstall[ rType: $$installableType, name_String ] :=
    catchMine @ resourceUninstall[ rType, name ];

ResourceUninstall[ ro: $$resourceObject ] :=
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

resourceUninstall[ rType: $$installableType, name_String ] := Enclose[
    Module[ { target },
        target = ConfirmBy[ resourceInstallLocation[ rType, name ], StringQ, "InstallLocation" ];
        If[ ! FileExistsQ @ target, throwFailure[ "ResourceNotInstalled", rType, name ] ];
        ConfirmMatch[ DeleteFile @ target, Null, "DeleteFile" ];
        ConfirmAssert[ ! FileExistsQ @ target, "FileExists" ];
        invalidateCache[ rType ];
        Null
    ],
    throwInternalFailure[ resourceUninstall[ rType, name ], ## ] &
];

resourceUninstall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ResourceInstallFromRepository*)
ResourceInstallFromRepository // beginDefinition;

ResourceInstallFromRepository[ rType: $$installableType ] := catchMine @ Enclose[
    Module[ { data },
        $channelData = None;

        data = ConfirmMatch[
            withExternalChannelFunctions @ browseWithChannelCallback @ rType,
            KeyValuePattern @ { "Listener" -> _ChannelListener, "Channel" -> _ChannelObject },
            "BrowseWithCallback"
        ];

        $channelData = Append[ data, "Dialog" -> EvaluationNotebook[ ] ]
    ],
    throwInternalFailure[ ResourceInstallFromRepository @ rType, ##1 ] &
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

browseWithChannelCallback[ rType: $$installableType ] := Enclose[
    Module[ { perms, channel, data, handler, listener, url, shortURL, parsed, id, browseURL },

        perms = ConfirmMatch[ $channelPermissions, "Public"|"Private", "ChannelPermissions" ];

        channel = ConfirmMatch[
            CreateChannel[ Permissions -> perms ],
            _ChannelObject,
            SystemOpen @ resourceBrowseURL @ rType;
            throwMessageDialog[ "ChannelFrameworkError" ]
        ];

        data    = <| "ResourceType" -> rType, "Listener" :> listener, "Channel" -> channel |>;
        handler = ConfirmMatch[ resourceInstallHandler @ data, _Function, "Handler" ];

        listener = ConfirmMatch[
            ChannelListen[ channel, handler ],
            _ChannelListener,
            SystemOpen @ resourceBrowseURL @ rType;
            throwMessageDialog[ "ChannelFrameworkError" ]
        ];

        url       = ConfirmMatch[ listener[ "URL" ], _String | _URL, "ChannelListenerURL" ];
        shortURL  = ConfirmBy[ makeShortListenerURL[ channel, url ], StringQ, "URLShorten" ];
        parsed    = ConfirmMatch[ DeleteCases[ URLParse[ shortURL, "Path" ], "" ], { __String? StringQ }, "URLParse" ];
        id        = ConfirmBy[ Last @ URLParse[ shortURL, "Path" ], StringQ, "ChannelID" ];
        browseURL = ConfirmBy[ resourceBrowseURL[ rType, id ], StringQ, "BrowseURL" ];

        ConfirmMatch[ SystemOpen @ browseURL, Null, "SystemOpen" ];
        AssociationMap[ Apply @ Rule, Append[ data, "BrowseURL" -> browseURL ] ]
    ],
    throwInternalFailure[ browseWithChannelCallback @ rType, ## ] &
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
resourceBrowseURL[ rType_String, id_String ] := URLBuild[ resourceBrowseURL @ rType, { "ChannelID" -> id } ];
resourceBrowseURL[ rType: $$installableType ] := Lookup[ $resourceBrowseURLs, rType, $Failed ];
resourceBrowseURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*channelCleanup*)
channelCleanup // beginDefinition;

channelCleanup[ ] := channelCleanup @ $channelData;
channelCleanup[ None ] := Null;

channelCleanup[ KeyValuePattern @ {
    "Listener" -> listener: $$channelListener,
    "Channel"  -> channel: $$channelObject
} ] := Quiet[ RemoveChannelListener @ listener; DeleteChannel @ channel ];

channelCleanup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ResourceInstallFromURL*)
ResourceInstallFromURL // beginDefinition;

ResourceInstallFromURL[ ] :=
    catchMine @ ResourceInstallFromURL @ Automatic;

ResourceInstallFromURL[ rType: $$installableType|Automatic ] := catchMine @ Enclose[
    Module[ { url },

        url = ConfirmMatch[
            DialogInput[
                {
                    ExpressionCell[
                        Style[ tr @ "ResourceInstallerFromURLPrompt", "DialogHeader" ],
                        "DialogHeader",
                        CellMargins -> Inherited ],
                    ExpressionCell[ "", "DialogDelimiter", CellMargins -> Inherited],
                    ExpressionCell[
                        InputField[ Dynamic @ CurrentValue[ EvaluationNotebook[ ], { TaggingRules, "URL" } ], String, ImageSize -> Scaled[ 1. ] ],
                        "DialogBody",
                        CellMargins -> Inherited ],
                    ExpressionCell[ "", "DialogDelimiter", CellMargins -> Inherited ],
                    ExpressionCell[
                        Pane[
                            ChoiceButtons[ { DialogReturn @ CurrentValue[ EvaluationNotebook[ ], { TaggingRules, "URL" } ], DialogReturn @ $Canceled } ],
                            FrameMargins -> { { 0, 0 }, { 3, 0 } } ],
                        "DialogFooter",
                        CellMargins -> { { Inherited, Inherited }, { Inherited, 4 } },
                        TextAlignment -> Right ]
                },
                WindowSize -> { 500, All }
            ],
            _String|$Canceled,
            "InputString"
        ];

        If[ url === $Canceled,
            $Canceled,
            ConfirmBy[ ResourceInstallFromURL[ rType, url ], AssociationQ, "Install" ]
        ]
    ],
    throwInternalFailure[ ResourceInstallFromURL @ rType, ## ] &
];

ResourceInstallFromURL[ rType: $$installableType|Automatic, url_String ] := Enclose[
    Module[ { ro, expected, actual, file },

        ro       = ConfirmMatch[ resourceFromURL @ url, _ResourceObject, "ResourceObject" ];
        expected = Replace[ rType, Automatic -> $$installableType ];
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
    throwInternalFailure[ ResourceInstallFromURL[ rType, url ], ## ] &
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
installableResourceQ[ ro: $$resourceObject ] := MatchQ[ ro[ "ResourceType" ], $$installableType ];
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
(*ResourceInstallFromFile*)

ResourceInstallFromFile // ClearAll;

(* Not sure if this syntactic sugar is warranted *)
ResourceInstallFromFile[ ] :=
    catchMine @ ResourceInstallFromFile[ Automatic, Automatic ]

ResourceInstallFromFile[ rType: $$installableType|Automatic ] :=
    catchMine @ ResourceInstallFromFile[ rType, Automatic ];

ResourceInstallFromFile[ File[ path_String ] ] :=
    catchMine @ ResourceInstallFromFile[ Automatic, path ];

(* I expect these next two definitions to be the most used *)
ResourceInstallFromFile[ rType: $$installableType|Automatic, Automatic ] := catchMine @ Enclose[
    Module[ { path },

        path = ConfirmMatch[
            SystemDialogInput[ "FileOpen", ".nb", WindowTitle -> FrontEndResource[ "ChatbookStrings", "ResourceInstallerFromFilePrompt" ] ],
            _String|$Canceled,
            "InputString"
        ];

        If[ path === $Canceled,
            $Canceled,
            ConfirmBy[ ResourceInstallFromFile[ rType, path ], AssociationQ, "Install" ]
        ]
    ],
    throwInternalFailure[ ResourceInstallFromFile @ rType, ## ] &
];

ResourceInstallFromFile[ rType: $$installableType|Automatic, path_String ] := Enclose[
    Module[ { ro, expected, actual, file },

        ro       = ConfirmMatch[ resourceFromFile[ rType, path ], _ResourceObject, "ResourceObject" ];
        expected = Replace[ rType, Automatic -> $$installableType ];
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
    throwInternalFailure[ ResourceInstallFromFile[ rType, path ], ## ] &
];

ResourceInstallFromFile[ args___ ] :=
    catchMine @ throwFailure[ "InvalidArguments", ResourceInstallFromFile, HoldForm @ ResourceInstallFromFile @ args ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resourceFromFile*)
resourceFromFile // beginDefinition;

resourceFromFile[ Automatic, path_String ] := Block[ { PrintTemporary },
    Quiet[ DefinitionNotebookClient`ScrapeResource[ Import[ path ] ] ]
];

resourceFromFile[ rType_, path_String ] := Enclose[
    Block[ { PrintTemporary },
        Quiet @ With[ { nb = Import @ path },
            ConfirmMatch[ DefinitionNotebookClient`NotebookResourceType @ nb, rType, "ResourceType" ];
            DefinitionNotebookClient`ScrapeResource @ nb
        ]
    ],
    throwInternalFailure
];

resourceFromFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ResourceInstallLocation*)
ResourceInstallLocation // ClearAll;

ResourceInstallLocation[ ro: $$resourceObject ] :=
    catchMine @ ResourceInstallLocation[ ro[ "ResourceType" ], ro[ "Name" ] ];

ResourceInstallLocation[ rType: $$installableType, name_String ] :=
    catchMine @ resourceInstallLocation[ rType, name ];

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

ResourceInstall[ ro: $$resourceObject ] :=
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

resourceInstall[ rType: $$installableType, info_? AssociationQ ] := Enclose[
    Module[ { target, content, installed },

        target    = ConfirmBy[ resourceInstallLocation[ rType, info ], StringQ, "InstallLocation" ];
        content   = ConfirmBy[ resourceInstalledContent[ rType, info ], AssociationQ, "InstalledContent" ];
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

        postInstall[ rType, info ];
        invalidateCache[ rType ];

        installed
    ],
    throwInternalFailure[ resourceInstall[ rType, info ], ## ] &
];

resourceInstall[ rType: Except[ $$installableType ], _ ] :=
    throwFailure[ "NotInstallableResourceType", rType, $installableTypes ];

resourceInstall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*postInstall*)
postInstall // beginDefinition;
postInstall[ "Prompt", info_ ] := addToVisiblePersonas @ resourceName @ info;
postInstall[ "LLMTool", info_ ] := enableTool @ resourceName @ info;
postInstall[ rType_, info_ ] := Null;
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

resourceInstallLocation[ rType_, KeyValuePattern[ "Name" -> name_ ] ] :=
    resourceInstallLocation[ rType, name ];

resourceInstallLocation[ rType_String, name0_String ] := Enclose[
    Module[ { name, fileName, directory },
        name      = ConfirmBy[ resourceName[ rType, name0 ], StringQ, "Name" ];
        fileName  = URLEncode @ name <> ".mx";
        directory = ConfirmBy[ resourceTypeDirectory @ rType, DirectoryQ, "Directory" ];
        FileNameJoin @ { directory, fileName }
    ],
    throwInternalFailure[ resourceInstallLocation[ rType, name0 ], ## ] &
];

resourceInstallLocation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourceTypeDirectory*)
resourceTypeDirectory // beginDefinition;

resourceTypeDirectory[ rType_String ] := Enclose[
    Module[ { root, typeName },
        root     = ConfirmBy[ $ResourceInstallationDirectory, StringQ, "RootDirectory" ];
        typeName = ConfirmBy[ resourceTypeDirectoryName @ rType, StringQ, "TypeName" ];
        ConfirmBy[ GeneralUtilities`EnsureDirectory @ { root, typeName }, DirectoryQ, "Directory" ]
    ],
    throwInternalFailure[ resourceTypeDirectory @ rType, ## ] &
];

resourceTypeDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourceTypeDirectoryName*)
resourceTypeDirectoryName // beginDefinition;
resourceTypeDirectoryName[ "Prompt"     ] := "Personas";
resourceTypeDirectoryName[ "LLMTool"    ] := "Tools";
resourceTypeDirectoryName[ rType_String ] := URLEncode @ rType;
resourceTypeDirectoryName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourceName*)
resourceName // beginDefinition;

resourceName[ KeyValuePattern @ { "ResourceType" -> rType_, "Name" -> name_ } ] :=
    resourceName[ rType, name ];

resourceName[ rType_String, name_String ] := (
    needsResourceType @ rType;
    StringDelete[ name, StartOfString ~~ ResourceSystemClient`ResourceType`NamePrefix @ rType ]
);

resourceName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*needsResourceType*)
needsResourceType // beginDefinition;

needsResourceType[ rType: $$installableType ] := Enclose[
    Module[ { pacletName, paclet, context },
        pacletName = ConfirmBy[ rType <> "Resource", StringQ, "PacletName" ];
        paclet = ConfirmBy[ PacletInstall @ pacletName, PacletObjectQ, "PacletInstall" ];
        context = ConfirmBy[ First[ Flatten @ List @ paclet[ "Context" ], $Failed ], StringQ, "Context" ];
        ConfirmMatch[ Needs[ context -> None ], Null, "NeedsContext" ];
        ConfirmAssert[ MemberQ[ $Packages, context ], "Packages" ];
        needsResourceType[ rType ] = Null
    ],
    throwInternalFailure[ needsResourceType @ rType, ## ] &
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

GetInstalledResourceData[ rType: $$installableType, opts: OptionsPattern[ ] ] :=
    catchMine[
        If[ TrueQ @ OptionValue[ "RegenerateCache" ], KeyDropFrom[ $installedResourceCache, rType ] ];
        getInstalledResourceData @ rType
    ];

GetInstalledResourceData[ rType_, opts: OptionsPattern[ ] ] :=
    catchMine @ throwFailure[ "NotInstallableResourceType", rType, $installableTypes ];

GetInstalledResourceData[ a___ ] :=
    catchMine @ throwFailure[ "InvalidArguments", GetInstalledResourceData, HoldForm @ GetInstalledResourceData @ a ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getInstalledResourceData*)
getInstalledResourceData // beginDefinition;

getInstalledResourceData[ rType_ ] :=
    With[ { cached = $installedResourceCache[ rType ] },
        cached /; ! MissingQ @ cached
    ];

getInstalledResourceData[ rType: $$installableType ] := Enclose[
    Module[ { data, held, merged, released },
        data = ConfirmMatch[ getInstalledResources @ rType, { ___Association }, "GetInstalledResources" ];
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
                            "ResourceType" -> rType,
                            "ResourceName" -> Lookup[ resourceAssoc, "Name", name ],
                            "Origin"       -> determineOrigin[ rType, resourceAssoc ]
                        |>
                    },
                    First
                ]
        ];

        released = ConfirmBy[ merged /. tempHold[ expr_ ] :> expr, FreeQ @ tempHold, "Release" ];

        $installedResourceCache[ rType ] = released
    ],
    throwInternalFailure
];

getInstalledResourceData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getInstalledResources*)
getInstalledResources // beginDefinition;
getInstalledResources[ rType_String ] := getResourceFile /@ FileNames[ "*.mx", resourceTypeDirectory @ rType ];
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
determineOrigin[ rType: $$installableType, KeyValuePattern[ "RepositoryLocation" -> $$urlH ] ] := rType<>"Repository";
determineOrigin[ rType_, KeyValuePattern[ "RepositoryLocation" -> $$localObjectH ] ] := "Local";
determineOrigin[ rType_, KeyValuePattern[ "ResourceLocations" -> { $$localObjectH } ] ] := "Local";
determineOrigin[ rType_, KeyValuePattern[ "ResourceLocations" -> { $$cloudObjectH } ] ] := "Cloud";
determineOrigin[ rType_, KeyValuePattern[ "DocumentationLink" -> $$urlH ] ] := "Cloud";
determineOrigin[ rType: $$installableType, _Association ] := "Unknown";
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
addToMXInitialization[
    $debug = False;
];

End[ ];
EndPackage[ ];
