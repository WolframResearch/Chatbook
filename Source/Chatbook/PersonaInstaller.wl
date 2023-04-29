(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PersonaInstaller`" ];

`$PersonaInstallationDirectory;
`GetInstalledPersonas;
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
$channelPermissions  = { $resourceSystemAdmin -> All, "Owner" -> All };

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
PersonaInstallFromResourceSystem[ ] := catchMine @ withExternalChannelFunctions @ browseWithChannelCallback[ ];
PersonaInstallFromResourceSystem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*browseWithChannelCallback*)
browseWithChannelCallback // beginDefinition;

browseWithChannelCallback[ ] := Enclose[
    Module[ { perms, channel, data, handler, listener, url, shortURL, parsed, id, browseURL },
        perms     = { ConfirmBy[ $resourceSystemAdmin, StringQ, "ResourceSystemAdmin" ] -> All, "Owner" -> All };
        channel   = ConfirmMatch[ CreateChannel[ Permissions -> perms ], _ChannelObject, "CreateChannel" ];
        data      = <| "Listener" :> listener, "Channel" -> channel |>;
        handler   = ConfirmMatch[ promptResourceInstallHandler @ data, _Function, "Handler" ];
        listener  = ConfirmMatch[ ChannelListen[ channel, handler ], _ChannelListener, "ChannelListen" ];
        url       = ConfirmMatch[ listener[ "URL" ], _String | _URL, "ChannelListenerURL" ];
        shortURL  = ConfirmBy[ makeShortListenerURL[ channel, url ], StringQ, "URLShorten" ];
        parsed    = ConfirmMatch[ DeleteCases[ URLParse[ shortURL, "Path" ], "" ], { __String? StringQ }, "URLParse" ];
        id        = ConfirmBy[ Last @ URLParse[ shortURL, "Path" ], StringQ, "InstallerID" ];
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

makeShortListenerURL[ channel_, url_ ] := URLShorten @ channel;
makeShortListenerURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createBrowseURL*)
createBrowseURL // beginDefinition;
createBrowseURL[ id_String ] := URLBuild[ $personaBrowseURL, { "ChatbookInstallerID" -> id } ];
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
        listener = ConfirmMatch[ listener0, _ChannelListener, "ChannelListener" ];
        Confirm[ RemoveChannelListener @ listener, "RemoveChannelListener" ];
        channel = ConfirmMatch[ data[ "Channel" ], _ChannelObject, "ChannelObject" ];
        Confirm[ DeleteChannel @ channel, "DeleteChannel" ];
        Remove @ listener0;
        promptResourceInstall0[ data, messageData ]
    ],
    throwInternalFailure[ promptResourceInstall[ channelData, messageData ], ## ] &
];

promptResourceInstall // endDefinition;


promptResourceInstall0 // beginDefinition;

promptResourceInstall0[ channelData_, messageData_ ] := Enclose[
    Module[ { message, info, resource, target, config, installed },
        message   = ConfirmBy[ messageData[ "Message" ], ByteArrayQ, "Message" ];
        info      = ConfirmBy[ BinaryDeserialize @ message, AssociationQ, "BinaryDeserialize" ];
        resource  = ConfirmMatch[ ResourceObject @ info, _ResourceObject, "ResourceObject" ];
        target    = ConfirmBy[ personaInstallLocation @ info, StringQ, "InstallLocation" ];
        config    = ConfirmBy[ resource[ "LLMConfiguration" ], AssociationQ, "LLMConfiguration" ];
        installed = ConfirmBy[ installPersonaConfiguration[ info, config, target ], FileExistsQ, "Install" ];
        Print[ Global`$args = <|
            "channelData" -> channelData,
            "messageData" -> messageData,
            "message"     -> message,
            "info"        -> info,
            "resource"    -> resource,
            "target"      -> target,
            "config"      -> config,
            "installed"   -> installed
         |> ] (* TODO: do the thing *)
    ],
    throwInternalFailure[ promptResourceInstall0[ channelData, messageData ], ## ] &
];

promptResourceInstall0 // endDefinition;

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

personaInstallLocation[ info_Association ] := Enclose[
    Module[ { prefix, name, fileName, directory },

        ConfirmBy[ PacletInstall[ "PromptResource" ], PacletObjectQ, "PacletInstall" ];
        ConfirmMatch[ Needs[ "PromptResource`" -> None ], Null, "PromptResource" ];

        prefix    = ConfirmBy[ ResourceSystemClient`ResourceType`NamePrefix[ "Prompt" ], StringQ ];
        name      = StringDelete[ ConfirmBy[ info[ "Name" ], StringQ, "Name" ], StartOfString~~prefix ];
        fileName  = URLEncode @ name <> ".mx";
        directory = ConfirmBy[ $PersonaInstallationDirectory, DirectoryQ, "Directory" ];

        FileNameJoin @ { directory, fileName }
    ],
    throwInternalFailure[ personaInstallLocation @ info, ## ] &
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
(*Package Footer*)
If[ Wolfram`Chatbook`Internal`$BuildingMX,
    Null
];

End[ ];
EndPackage[ ];
