(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PersonaInstaller`" ];

`$PersonaInstallationDirectory;
`GetInstalledResourcePersonas;
`PersonaInstallFromResourceSystem;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"         ];
Needs[ "Wolfram`Chatbook`Common`"  ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)

(* FIXME: set values to corresponding PRD resource system *)

$personaBrowseURL    = "https://www.wolframcloud.com/obj/rhennigan/published/PromptRepository/category/persona";
$resourceSystemAdmin = "richardh@wolfram.com";
(* $channelPermissions  = { $resourceSystemAdmin -> All, "Owner" -> All }; *)
$channelPermissions  = "Public";
$keepChannelOpen     = True;
$debug               = False;

(* TODO: need to add a DeleteResource hook for PromptResources that removes corresponding items here *)
$PersonaInstallationDirectory := GeneralUtilities`EnsureDirectory @ {
    $UserBaseDirectory,
    "ApplicationData",
    "Chatbook",
    "Personas"
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*PersonaInstallFromResourceSystem*)
PersonaInstallFromResourceSystem // beginDefinition;

PersonaInstallFromResourceSystem[ ] := catchMine @ Enclose[
    Module[ { data, dialog },
        data = ConfirmMatch[
            withExternalChannelFunctions @ browseWithChannelCallback[ ],
            KeyValuePattern @ { "Listener" -> _ChannelListener, "Channel" -> _ChannelObject },
            "BrowseWithCallback"
        ];
        $installed = ConfirmMatch[
            GetInstalledResourcePersonas[ ],
            { ___Association },
            "GetInstalledResourcePersonas"
        ];

        dialog = createPersonaInstallWaitingDialog @ data;
    ],
    (
        $installed = { };
        throwInternalFailure[ PersonaInstallFromResourceSystem[ ], ## ]
    ) &
];

PersonaInstallFromResourceSystem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createPersonaInstallWaitingDialog*)
createPersonaInstallWaitingDialog // beginDefinition;

createPersonaInstallWaitingDialog[ data_ ] := CreateDialog[
    {
        TextCell[ "If your browser does not open automatically, click here", "Text" ],
        ExpressionCell @ Dynamic[
            If[ $installed === { },
                ProgressIndicator[ Appearance -> "Necklace" ],
                Grid[
                    Prepend[
                        formatInstalledResource /@ $installed,
                        {
                            "",
                            Style[ "Name", FontWeight -> "DemiBold" ],
                            Style[ "Description", FontWeight -> "DemiBold" ],
                            Style[ "Version", FontWeight -> "DemiBold" ],
                            ""
                        }
                    ],
                    Alignment -> Left,
                    BaseStyle -> "Text",
                    Dividers -> { False, Center },
                    FrameStyle -> GrayLevel[ 0.6 ]
                ]
            ],
            TrackedSymbols :> { $installed }
        ],
        DefaultButton[ DialogReturn @ channelCleanup @ data ]
    },
    NotebookEventActions -> {
        "ReturnKeyDown" :> FE`Evaluate @ FEPrivate`FindAndClickDefaultButton[ ],
        { "MenuCommand", "EvaluateCells" } :> FE`Evaluate @ FEPrivate`FindAndClickDefaultButton[ ],
        { "MenuCommand", "HandleShiftReturn" } :> FE`Evaluate @ FEPrivate`FindAndClickDefaultButton[ ],
        { "MenuCommand", "EvaluateNextCell" } :> FE`Evaluate @ FEPrivate`FindAndClickDefaultButton[ ],
        "EscapeKeyDown" :> (
            FE`Evaluate @ FEPrivate`FindAndClickCancelButton[ ];
            channelCleanup @ data;
            DialogReturn @ $Canceled
        ),
        "WindowClose" :> (
            FE`Evaluate @ FEPrivate`FindAndClickCancelButton[ ];
            channelCleanup @ data;
            DialogReturn @ $Canceled
        )
    }
];

createPersonaInstallWaitingDialog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*channelCleanup*)
channelCleanup // beginDefinition;

channelCleanup[ KeyValuePattern @ { "Listener" -> listener_ChannelListener, "Channel" -> channel_ChannelObject } ] := (
    RemoveChannelListener @ listener;
    DeleteChannel @ channel;
);

channelCleanup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatInstalledResource*)
formatInstalledResource // beginDefinition;

formatInstalledResource[ as_ ] :=
    formatInstalledResource[ as[ "ResourceInformation" ], as[ "Configuration" ] ];

formatInstalledResource[ as_, config_ ] :=
    formatInstalledResource[ as[ "Name" ], as[ "Description" ], as[ "Version" ], config[ "PersonaIcon" ] ];

formatInstalledResource[ name_, desc_, version_, KeyValuePattern[ "Default" -> icon_ ] ] :=
    formatInstalledResource[ name, desc, version, icon ];

formatInstalledResource[ name_, desc_, version_, icon_ ] := {
    formatIcon @ icon,
    formatName @ name,
    formatDescription @ desc,
    formatVersion @ version,
    uninstallButton @ name
};

formatInstalledResource // endDefinition;


formatName[ name_String ] := (
    needsPromptResource[ ];
    StringDelete[ name, StartOfString ~~ ResourceSystemClient`ResourceType`NamePrefix[ "Prompt" ] ]
);

formatDescription[ _Missing ] := "";
formatDescription[ desc_String ] := desc;

formatVersion[ _Missing ] := "";
formatVersion[ version_String ] := version;

formatIcon[ _Missing ] := "";
formatIcon[ KeyValuePattern[ "Default" -> icon_ ] ] := formatIcon @ icon;
formatIcon[ icon_ ] := Pane[ icon, ImageSize -> { 30, 30 }, ImageSizeAction -> "ShrinkToFit" ];

uninstallButton[ name_String ] := Button[ "Uninstall", uninstallPersona @ name ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*uninstallPersona*)
uninstallPersona // beginDefinition;

uninstallPersona[ name_String ] := Enclose[
    Module[ { file },
        file = ConfirmBy[ personaInstallLocation @ name, FileExistsQ, "PersonaInstallLocation" ];
        Confirm[ DeleteFile @ file, "DeleteFile" ];
        $installed = ConfirmMatch[ GetInstalledResourcePersonas[ ], { ___Association }, "GetInstalledResourcePersonas" ]
    ],
    throwInternalFailure[ uninstallPersona @ name, ## ] &
];

uninstallPersona // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*browseWithChannelCallback*)
browseWithChannelCallback // beginDefinition;

browseWithChannelCallback[ ] := Enclose[
    Module[ { perms, channel, data, handler, listener, url, shortURL, parsed, id, browseURL },
        perms     = $channelPermissions;
        channel   = ConfirmMatch[ CreateChannel[ Permissions -> perms ], _ChannelObject, "CreateChannel" ];
        data      = <| "Listener" :> listener, "Channel" -> channel |>;
        handler   = ConfirmMatch[ promptResourceInstallHandler @ data, _Function, "Handler" ];
        listener  = ConfirmMatch[ ChannelListen[ channel, handler ], _ChannelListener, "ChannelListen" ];
        url       = ConfirmMatch[ listener[ "URL" ], _String | _URL, "ChannelListenerURL" ];
        shortURL  = ConfirmBy[ makeShortListenerURL[ channel, url ], StringQ, "URLShorten" ];
        parsed    = ConfirmMatch[ DeleteCases[ URLParse[ shortURL, "Path" ], "" ], { __String? StringQ }, "URLParse" ];
        id        = ConfirmBy[ Last @ URLParse[ shortURL, "Path" ], StringQ, "ChannelID" ];
        browseURL = ConfirmBy[ createBrowseURL @ id, StringQ, "BrowseURL" ];
        ConfirmMatch[ SystemOpen @ browseURL, Null, "SystemOpen" ];
        AssociationMap[ Apply @ Rule, Append[ data, "BrowseURL" -> browseURL ] ]
    ],
    throwInternalFailure[ browseWithChannelCallback[ ], ## ] &
];

browseWithChannelCallback // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeShortListenerURL*)
makeShortListenerURL // beginDefinition;

(* makeShortListenerURL[ url_String ] := Enclose[
    Module[ { domain, parse1, parse2 },
        (* cSpell: ignore channelbroker,mqtt *)
        domain = ConfirmBy[
            StringReplace[ URLParse[ url, "Domain" ], "channelbroker-mqtt" -> "channelbroker" ],
            StringQ,
            "Domain"
        ];

        parse1 = ConfirmBy[ URLParse @ url, AssociationQ, "Parse1" ];
        parse2 = ConfirmBy[ Association[ parse1, "Scheme" -> "https", "Domain" -> domain ], AssociationQ, "Parse2" ];

        ConfirmBy[
            ConfirmBy[ URLBuild @ parse2, StringQ, "URLBuild" ],
            StringQ,
            "URLShorten"
        ]
    ],
    throwInternalFailure[ makeShortListenerURL @ url, ## ] &
]; *)

makeShortListenerURL[ channel_, url_ ] := url;
makeShortListenerURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createBrowseURL*)
createBrowseURL // beginDefinition;
createBrowseURL[ id_String ] := URLBuild[ $personaBrowseURL, { "ChannelID" -> id } ];
createBrowseURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*withExternalChannelFunctions*)
withExternalChannelFunctions // beginDefinition;
withExternalChannelFunctions // Attributes = { HoldFirst };
withExternalChannelFunctions[ eval_ ] := Block[ { $AllowExternalChannelFunctions = True }, eval ];
withExternalChannelFunctions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*promptResourceInstallHandler*)
promptResourceInstallHandler // beginDefinition;

promptResourceInstallHandler[ metadata_Association ] := Function @ catchTop[
    Block[ { PrintTemporary }, promptResourceInstall[ metadata, ## ] ],
    PersonaInstallFromResourceSystem
];

promptResourceInstallHandler // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*promptResourceInstall*)
promptResourceInstall // beginDefinition;

promptResourceInstall[ channelData: KeyValuePattern[ "Listener" :> listener0_Symbol ], messageData_ ] := Enclose[
    Module[ { data, listener, channel },
        data = AssociationMap[ Apply @ Rule, channelData ];
        If[ ! TrueQ @ $keepChannelOpen,
            listener = ConfirmMatch[ listener0, _ChannelListener, "ChannelListener" ];
            Confirm[ RemoveChannelListener @ listener, "RemoveChannelListener" ];
            channel = ConfirmMatch[ data[ "Channel" ], _ChannelObject, "ChannelObject" ];
            Confirm[ DeleteChannel @ channel, "DeleteChannel" ];
            Remove @ listener0;
        ];
        promptResourceInstall0[ data, messageData ]
    ],
    throwInternalFailure[ promptResourceInstall[ channelData, messageData ], ## ] &
];

promptResourceInstall // endDefinition;


promptResourceInstall0 // beginDefinition;

promptResourceInstall0[ channelData_, messageData_ ] := Enclose[
    Module[ { message, resource, info, target, config, installed },
        message   = ConfirmBy[ messageData[ "Message" ], AssociationQ, "Message" ];
        resource  = ConfirmMatch[ acquireResource @ message, _ResourceObject, "ResourceObject" ];
        info      = ConfirmBy[ resource[ All ], AssociationQ, "Information" ];
        target    = ConfirmBy[ personaInstallLocation @ info, StringQ, "InstallLocation" ];
        config    = ConfirmBy[ resource[ "PromptConfiguration" ], AssociationQ, "PromptConfiguration" ];
        installed = ConfirmBy[ installPersonaConfiguration[ info, config, target ], FileExistsQ, "Install" ];
        If[ TrueQ @ $debug,
            MessageDialog @ Grid[
                {
                    { Style[ "Persona Install Debug Info", "Section" ], SpanFromLeft },
                    { "ResourceObject:", resource },
                    { "Installed:"     , installed }
                },
                Alignment -> Left,
                Dividers  -> Center
            ]
        ];
        $installed = GetInstalledResourcePersonas[ ];

        installed
    ],
    throwInternalFailure[ promptResourceInstall0[ channelData, messageData ], ## ] &
];

promptResourceInstall0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acquireResource*)
acquireResource // beginDefinition;
acquireResource[ KeyValuePattern[ "UUID" -> uuid_ ] ] := ResourceObject[ uuid, ResourceVersion -> "Latest" ];
acquireResource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installPersonaConfiguration*)
installPersonaConfiguration // beginDefinition;

installPersonaConfiguration[ info_, config_, target_ ] :=
    installPersonaConfiguration[ info, config, target, personaContext @ config ];

installPersonaConfiguration[ info_, config_, target_, None ] :=
    Block[ { $PersonaConfig = <| "ResourceInformation" -> info, "Configuration" -> config |> },
        With[ { name = ToString @ Unevaluated @ $PersonaConfig },
            DumpSave[ target, name, "SymbolAttributes" -> False ];
            target
        ]
    ];

installPersonaConfiguration[ info_, config_, target_, context_String ] :=
    Block[ { $PersonaConfig = <| "ResourceInformation" -> info, "Configuration" -> config |> },
        With[ { name = ToString @ Unevaluated @ $PersonaConfig },
            DumpSave[ target, { name, context }, "SymbolAttributes" -> False ];
            target
        ]
    ];

installPersonaConfiguration // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*personaInstallLocation*)
personaInstallLocation // beginDefinition;

personaInstallLocation[ KeyValuePattern[ "Name" -> name_ ] ] := personaInstallLocation @ name;

personaInstallLocation[ name0_String ] := Enclose[
    Module[ { prefix, name, fileName, directory },
        needsPromptResource[ ];
        prefix    = ConfirmBy[ ResourceSystemClient`ResourceType`NamePrefix[ "Prompt" ], StringQ ];
        name      = StringDelete[ ConfirmBy[ name0, StringQ, "Name" ], StartOfString~~prefix ];
        fileName  = URLEncode @ name <> ".mx";
        directory = ConfirmBy[ $PersonaInstallationDirectory, DirectoryQ, "Directory" ];

        FileNameJoin @ { directory, fileName }
    ],
    throwInternalFailure[ personaInstallLocation @ name0, ## ] &
];

personaInstallLocation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*personaContext*)
personaContext // beginDefinition;

personaContext[ config_Association ] := FirstCase[
    ToExpression[ ToString[ config, InputForm ], InputForm, HoldComplete ],
    s_Symbol? dependentPersonaSymbolQ :> Context @ Unevaluated @ s,
    None,
    Infinity,
    Heads -> True
];

personaContext // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dependentPersonaSymbolQ*)
dependentPersonaSymbolQ // ClearAll;
dependentPersonaSymbolQ // Attributes = { HoldAllComplete };

dependentPersonaSymbolQ[ sym_Symbol ] := TrueQ @ And[
    AtomQ @ Unevaluated @ sym,
    Unevaluated @ sym =!= Internal`$EFAIL,
    StringStartsQ[ Context @ Unevaluated @ sym, "PromptRepository`" ]
];

dependentPersonaSymbolQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GetInstalledResourcePersonas*)
GetInstalledResourcePersonas // beginDefinition;
GetInstalledResourcePersonas[ ] := catchMine @ getInstalledPersonas[ ];
GetInstalledResourcePersonas // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getInstalledPersonas*)
getInstalledPersonas // beginDefinition;
getInstalledPersonas[ ] := getPersonaFile /@ FileNames[ "*.mx", $PersonaInstallationDirectory ];
getInstalledPersonas // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getPersonaFile*)
getPersonaFile // beginDefinition;
getPersonaFile[ file_ ] := Block[ { $PersonaConfig = $Failed }, Get @ file; $PersonaConfig ];
getPersonaFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*needsPromptResource*)
needsPromptResource[ ] := Enclose[
    ConfirmBy[ PacletInstall[ "PromptResource" ], PacletObjectQ, "PacletInstall" ];
    ConfirmMatch[ Needs[ "PromptResource`" -> None ], Null, "PromptResource" ];
    needsPromptResource[ ] = Null
    ,
    throwInternalFailure[ needsPromptResource[ ], ## ] &
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`Chatbook`Internal`$BuildingMX,
    $debug = False;
];

End[ ];
EndPackage[ ];
